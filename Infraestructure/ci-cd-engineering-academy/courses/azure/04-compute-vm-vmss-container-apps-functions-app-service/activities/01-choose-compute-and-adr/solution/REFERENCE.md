# REFERENCE — az-04-01-choose-compute-and-adr

> Una referencia razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Eleccion de compute Azure para checkout-api, etl-nightly y billing-worker

## Estado

Propuesto (Fase 3). Objetivo: Aceptado tras revision de Platform + Security y materializado con Terraform en Fase 4.

## Contexto

El equipo plataforma del capstone evalua tres workloads nuevos en Azure:

- **`checkout-api`**: API HTTP sincronica de pagos (PCI-light). SLA p99 < 300 ms. 20 rps constantes, 150 rps en picos.
- **`etl-nightly`**: job batch Python de 15-25 min a las 02:00 UTC cada dia.
- **`billing-worker`**: worker a Service Bus Queue, 500k msg/dia, 200 ms CPU por mensaje.

Constraints transversales:

- **Region**: `westeurope` o `northeurope` (compliance GDPR).
- **Identidad**: todas las apps leen secretos de Key Vault mediante **Managed Identity**; prohibido `AZURE_CLIENT_SECRET` en env vars.
- **Coste**: Finance exige propuesta con coste estimado y maximiza "pay-per-use" donde sea posible.
- **Operabilidad**: la org ya tiene AKS para otras cargas, pero no quiere seguir anadiendo cosas al cluster.

## Decision

### Tabla comparativa de familias de compute

| Opcion | Cold start | Portabilidad | Coste tipico (orden) | Operabilidad |
|--------|------------|--------------|------------------------|---------------|
| **VM** (`azurerm_linux_virtual_machine`) | N/A (siempre on) | Baja (ligada a Azure) | Fijo por hora (~8-200 USD/mes/VM) | Alta carga: parches, SSH, imagen |
| **VMSS** (`azurerm_linux_virtual_machine_scale_set`) | N/A | Baja | Fijo por hora x N | Rolling upgrades automaticos |
| **App Service** (`azurerm_linux_web_app`) | <1s | Media (PaaS) | Fijo por plan (B1 ~13 USD/mes; P1v3 ~70 USD/mes) | Baja; runtime gestionado |
| **Container Apps** (`azurerm_container_app`) | 1-5s warm / 10-30s cold | **Alta** (contenedor + Dapr) | **Pay-per-request + GB-s** | Muy baja; serverless K8s abstracto |
| **ACI** (`azurerm_container_group`) | 5-30s | Alta | Por segundo | Baja; sin autoscaling |
| **Functions** (`azurerm_linux_function_app`) | 50 ms-2 s | Media (bindings propietarios) | Pay-per-invocacion + GB-s | Muy baja |

### checkout-api -> **Container Apps**

- `revision_mode = "Multiple"` para canary nativo 90/10.
- `min_replicas = 2` (NO zero): el SLA p99 < 300 ms no tolera cold start.
- `max_replicas = 10` con `http_scale_rule.concurrent_requests = 50`.
- Managed Identity (SystemAssigned) con rol `AcrPull` sobre el ACR y `Key Vault Secrets User` sobre el Key Vault.
- Region `westeurope`.

```hcl
resource "azurerm_container_app" "checkout" {
  revision_mode = "Multiple"
  template {
    min_replicas = 2
    max_replicas = 10
    http_scale_rule {
      name                = "http"
      concurrent_requests = 50
    }
  }
  identity { type = "SystemAssigned" }
}
```

### etl-nightly -> **Container Apps Jobs** (`azurerm_container_app_job`)

- Trigger `type = "Schedule"`, cron `0 2 * * *`.
- `replica_timeout_in_seconds = 1800` (30 min).
- `parallelism = 1`, `replica_retry_limit = 2`.
- Scale-to-zero por defecto (coste 0 USD/mes fuera del slot nocturno).
- Portabilidad: mismo Dockerfile que un K8s CronJob si hay migracion a AKS.

### billing-worker -> **Container Apps + KEDA Service Bus scaler**

- `custom_scale_rule` apuntando al scaler `azure-servicebus`.
- `queueLength = 50` (una replica por cada 50 msgs en cola).
- `min_replicas = 0`, `max_replicas = 20`.
- 500k msg/dia a 200 ms CPU = ~28 min CPU/dia distribuidos; con scale-to-zero el gasto es minimo.
- Managed Identity con `Azure Service Bus Data Receiver` sobre la queue y `Cosmos DB Built-in Data Contributor` sobre el account.

## Consecuencias

### Ganancias

- **Un solo stack mental** para los 3 workloads (Container Apps y Container Apps Jobs). Operabilidad maxima.
- **Portabilidad**: los 3 son contenedores con posible migracion a AKS/EKS/GKE con cambios minimos (y usando Dapr si se amplia la abstraccion).
- **Pay-per-use** real para `etl-nightly` y `billing-worker`; coste constante solo para las 2 replicas calientes de `checkout-api`.
- **Managed Identity** uniforme en los 3.

### Perdidas

- Container Apps **no es AKS**: no hay `kubectl`, no hay operators, no hay CRDs. Si manana aparece una necesidad K8s-nativa, hay que migrar.
- Cold start de `billing-worker` cuando sale de zero: el primer msg tras un idle tarda ~10-20s. Aceptable para facturacion asincrona; **inaceptable** para `checkout-api` (razon de `min_replicas = 2`).
- Dapr no se adopta en este paso (overhead ~50 MB RAM/sidecar y una capa mas a debuggear); si en 12 meses hay 5+ microservicios con pub/sub cruzado, se reevalua.
- El equipo que no haya tocado Container Apps debe aprender `revision_suffix`, `traffic_weight` y los scalers KEDA.

### Coste estimado (orden de magnitud)

| Workload | Compute | Estimado/mes |
|----------|---------|---------------|
| `checkout-api` | 2 replicas 0.5 vCPU + 1 GiB | ~30-50 USD |
| `etl-nightly` | 20 min/dia, 1 vCPU + 2 GiB | ~2-5 USD |
| `billing-worker` | ~28 min CPU/dia distribuidos | ~5-15 USD |
| **Total** | | **~40-70 USD** |

Equivalente en App Service (3 planes P1v3 constantes) seria ~210 USD/mes solo en compute. Equivalente en 3 VMs B2s constantes ~90 USD + operabilidad.

## Alternativas descartadas

### 1. `checkout-api` en App Service (P1v3)

- **Pros**: zero-config HTTPS gestionado, slots con swap atomico, equipo familiar con PaaS.
- **Contras**: coste constante ~70 USD/mes incluso en noche vacia; **slot swap no es traffic split granular** — no permite 90/10 con observacion en caliente. Si rompes, es swap-back entero.
- Decidimos NO. Container Apps gana en coste + en canary nativo.

### 2. `etl-nightly` en **Azure Functions Timer trigger** (Flex Consumption)

- **Pros**: 1 archivo de codigo, binding Timer trivial, cold start aceptable para batch nocturno.
- **Contras**: limite de 10 min por invocacion en Consumption clasico; Flex Consumption lo sube pero el runtime queda ligado a Functions host. **Menor portabilidad** si manana se migra a K8s. Para 15-25 min, Container Apps Jobs es el fit mas limpio.
- Decidimos NO. Si la duracion bajara a <5 min, Functions seria la opcion correcta.

### 3. `billing-worker` en **AKS con pod + KEDA deployment**

- **Pros**: control total, costo marginal cero si ya hay cluster.
- **Contras**: hay que operar AKS (nodo pools, upgrades, networking, security). La org quiere **evitar meter mas en AKS** salvo necesidad. Container Apps da el mismo scaler KEDA sin exponer el cluster.
- Decidimos NO. Container Apps gana en operabilidad.

### 4. `billing-worker` en **Functions Service Bus trigger**

- **Pros**: binding declarativo, scaling automatico sin KEDA explicito.
- **Contras**: 500k msg/dia distribuidos pueden disparar `OutOfOrder` entre instancias Functions; el modelo de concurrencia (`maxConcurrentCalls`) es menos fino que un scale rule KEDA. Sigue siendo defendible — es un cercano segundo.

## Mapping AWS <-> Azure usado

- **ECS/Fargate HTTP service** <-> **Container Apps** con `ingress + revisions`.
- **ECS/Fargate scheduled task** o **Lambda Timer** <-> **Container Apps Jobs** con cron.
- **Lambda event-driven (SQS)** <-> **Container Apps con KEDA Service Bus scaler** o **Functions Service Bus trigger**.
- **EC2 Instance Connect + SSM** <-> **Bastion + AAD login for VMs** (para los casos VM que no cubrimos aqui).

## Preguntas abiertas para Fase 2

- Si Dapr entra, mover los 3 a `dapr { app_id = ... }` y los backing stores a `azurerm_container_app_environment_dapr_component`.
- Si llegamos a 10+ microservicios, reevaluar `AKS + Workload Identity` como plataforma unica.
- Instrumentar los 3 con Application Insights (`az-08`) y definir metricas custom para autoscale fino.
