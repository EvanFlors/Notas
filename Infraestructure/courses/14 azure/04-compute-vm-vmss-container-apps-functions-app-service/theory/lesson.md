# Leccion — Compute en Azure: VM, VMSS, App Service, Container Apps y Functions

> Modulo intermedio. Asume `az-01`/`az-02`/`az-03` y familiaridad con EC2/ECS/Lambda del lado AWS.

## Tabla de contenidos

1. El catalogo de compute en Azure, de un vistazo
2. Virtual Machines (VM) y como se diferencian de EC2
3. Virtual Machine Scale Sets (VMSS) y el patron "autoscaling por metrica"
4. Acceso sin claves locales: Azure Bastion y Azure AD login for VMs
5. App Service: el PaaS clasico que no ha muerto
6. Container Instances (ACI): el contenedor unico de "corta vida"
7. Azure Container Apps: serverless K8s abstracto
8. Revisions, traffic split y el canary nativo
9. Dapr integrado y por que importa
10. Azure Functions y el plan Flex Consumption
11. Mapping AWS -> Azure, workload por workload
12. Fundamentos internos y errores comunes

---

## 1. El catalogo de compute en Azure, de un vistazo

Azure ofrece **cinco** familias de compute que se solapan de forma deliberada. Elegir la correcta no es dogmatico — es una funcion de cuatro variables:

- **cold-start tolerado** (ms a segundos),
- **control del runtime** (OS completo vs runtime fijo),
- **portabilidad** (si manana migras a GKE / EKS, cuanto cuesta),
- **modelo de precio** (constante vs pay-per-request).

| Familia | Granularidad | Cold start | Portabilidad | Modelo de precio |
|---------|--------------|------------|--------------|-------------------|
| VM | OS completo | N/A (siempre on) | Baja (ligada a azurerm_virtual_machine) | Por hora, siempre |
| VMSS | OS completo x N | N/A (siempre on) | Baja | Por hora x N |
| App Service | Codigo o contenedor | <1s | Media (PaaS) | Por plan (constante) |
| ACI | Contenedor unico | 5-30s | Alta (contenedor) | Por segundo |
| Container Apps | Contenedor, scale-to-zero | 1-5s warm, 10-30s cold | Alta (contenedor) | Por request + duracion |
| Functions | Funcion | 50ms-2s | Media (bindings) | Por invocacion + GB-s |

**Regla heuristica**: si no sabes cual elegir y la carga es HTTP sincronica, empieza por **Container Apps**. Solo bajas a VM/VMSS si hay un requisito legacy (SMB, driver kernel, licencia por core) o requisito regulatorio que exija OS entero bajo tu control.

---

## 2. Virtual Machines (VM) y como se diferencian de EC2

Una `azurerm_linux_virtual_machine` es, conceptualmente, equivalente a una EC2 instance. Diferencias practicas que te muerden si vienes de AWS:

- **Managed disk** en lugar de EBS. El disco OS es gestionado (Azure almacena los metadatos de replicas por ti) y existe independientemente de la VM — borrar la VM **no** borra el disco por defecto; hay que configurar `delete_os_disk_on_deletion = true`.
- **NIC** es un recurso explicito (`azurerm_network_interface`) que precede a la VM, no un atributo. Esto permite reutilizar NICs con IPs reservadas al recrear VMs.
- **Trusted Launch** (equivalente a Nitro Enclaves + Secure Boot combinados): habilitado por default en SKUs recientes; da Secure Boot + vTPM + attestation.
- **Spot VMs**: hasta -90% de descuento, con `eviction_policy = Deallocate` o `Delete`. Equivalente a Spot EC2 pero con **politicas de eviccion mas predecibles** (max price + eviction event via metadata endpoint).
- **Imagenes**: `Canonical/0001-com-ubuntu-server-jammy/22_04-lts` sigue un esquema `publisher/offer/sku`. No hay AMI IDs regionales — las imagenes son globales por publisher.

### Receta minima (Terraform, pseudocodigo)

```hcl
resource "azurerm_linux_virtual_machine" "demo" {
  name                            = "vm-demo"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  network_interface_ids           = [azurerm_network_interface.nic.id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity { type = "SystemAssigned" }
}
```

---

## 3. Virtual Machine Scale Sets (VMSS) y el patron "autoscaling por metrica"

VMSS es **el AutoScaling Group de Azure**. Agrupa N VMs identicas (misma imagen, mismo tamano, misma config) y les aplica autoscaling por **metricas** de Azure Monitor:

- metrica standard: `Percentage CPU`, `Network In`, `Available Memory`.
- metrica custom: cualquier metrica publicada en Application Insights (p. ej. `requests_per_second`).

### Diferencias con AWS ASG

- **Rolling upgrades nativos**: `upgrade_policy = Automatic | Manual | Rolling`. En `Rolling`, VMSS actualiza en batches respetando `max_batch_instance_percent` y `max_unhealthy_instance_percent`.
- **Flexible orchestration mode** (recomendado hoy, no el legacy "Uniform"): te deja mezclar tamanos y zonas en el mismo scale set.
- **Spot mixing**: tipico patron de ahorro — 20% baseline on-demand + 80% Spot (`priority_mix`). AWS lo hace en el ASG; Azure en el VMSS.

### Cuando VMSS y no Container Apps

- Software **que no cabe en un contenedor** (driver kernel, licencia por core de un ISV, agente que requiere acceso a `/dev`).
- Carga **constante y predecible** donde el delta de coste entre "N VMs 24/7" y "scale-to-zero" no compensa el overhead operativo del contenedor.

---

## 4. Acceso sin claves locales: Azure Bastion y Azure AD login for VMs

Dos tecnologias ortogonales que resuelven **el mismo** problema (no distribuir SSH keys locales) desde angulos distintos:

- **Azure Bastion**: servicio PaaS que da acceso HTML5 a la VM via portal. No requiere IP publica en la VM, no abre 22 al mundo, auditoria centralizada en Activity Log. Coste: ~140 USD/mes (SKU Basic) — justificable solo si hay varias VMs.
- **Azure AD login for Linux VMs** (extension `AADSSHLoginForLinux`): el usuario autentica con su identidad de Entra ID; la VM delega la autorizacion a RBAC (`Virtual Machine Administrator Login` o `Virtual Machine User Login`). No hay `authorized_keys` locales. Hace falta la CLI `az ssh vm` que negocia el token.

### Patron recomendado

- Bastion si tienes >=3 VMs y necesitas acceso humano frecuente auditable.
- AAD login en todas las VMs — es gratis y elimina la gestion de claves.

AMBOS son **mejores que** `0.0.0.0/0 : 22` + llave compartida en el laptop.

---

## 5. App Service: el PaaS clasico que no ha muerto

**App Service** es el PaaS "clasico" de Azure para web/API. Despliegas codigo (`.NET`, `Node`, `Python`, `Java`, `PHP`, `Ruby`) **o** un contenedor, y Azure gestiona el runtime, el ingress HTTPS con cert gestionado, el autoscaling y los deployment slots.

### Planes

| Plan | Caso | Precio tipico |
|------|------|----------------|
| `F1` Free | Pruebas, limites duros | 0 USD |
| `B1` Basic | Dev / interno | ~13 USD/mes |
| `P1v3` Premium v3 | Prod HTTP standard | ~70 USD/mes |
| `I1v2` Isolated | VNet injection, dedicado | 400+ USD/mes |

### Deployment slots

Un slot es un **ambiente paralelo** del mismo App Service (`staging`, `canary`, `prod`). Operaciones clave:

- `az webapp deployment slot swap` — intercambia slots atomicamente (zero-downtime).
- Trafico por porcentaje via `routing-rule` (envia X% a `staging` para A/B testing).

### Cuando App Service y no Container Apps

- App **monolitica** con configuracion compleja ya en `web.config` o `appsettings.json`.
- Equipo que no quiere escribir Dockerfiles.
- Necesidad de **slots con swap atomico** (Container Apps hace canary distinto, con revisions — distinto feature, no equivalente 1:1).

---

## 6. Container Instances (ACI): el contenedor unico de "corta vida"

ACI corre **un contenedor** (o un grupo pequeno) por un tiempo definido. No tiene autoscaling, no tiene ingress elaborado. Casos:

- **Batch jobs** disparados por un trigger (p. ej. "ETL nocturno de 20 min").
- **Burst desde AKS**: AKS puede usar `virtual-node` (Virtual Kubelet backed by ACI) para desbordar pods a ACI cuando el cluster no tiene nodos libres.
- **Build runners efimeros** (aunque hoy Container Apps Jobs cubre esto mejor).

Precio: por segundo de vCPU + GB. No hay reserva.

---

## 7. Azure Container Apps: serverless K8s abstracto

**Container Apps** es la respuesta de Azure a Cloud Run (GCP) y a Fargate for ECS (AWS). La diferencia estructural: por debajo corre **AKS gestionado por Azure** (no por ti), pero toda la complejidad K8s esta **oculta**. No ves pods, no ves deployments, no ves services — ves `revisions` y `scale rules`.

### Primitivas

- **Environment** (`azurerm_container_app_environment`): la "frontera" compartida. Equivale al cluster. Contiene N apps.
- **Container App** (`azurerm_container_app`): la unidad desplegable. Contiene 1..N `template.container` + `revisions` + `ingress` + `scale rules`.
- **Revision**: un snapshot inmutable del template. Cada cambio al template crea una revision nueva.
- **Ingress**: config HTTP/TCP, externo/interno, puerto target, `transport` (http/http2/tcp/auto).
- **Scale rules**: `http_scale_rule` (concurrency), `custom_scale_rule` (cualquier KEDA scaler: Service Bus, Event Hub, Postgres queue, Prometheus...).

### Modos de revision

- `single_revision_mode = "Single"` (default): solo la ultima revision recibe trafico; las anteriores quedan deactivated.
- `revision_mode = "Multiple"`: multiples revisions activas simultaneamente, cada una con su `traffic_weight`. **Este es el modo para canary.**

### Scale-to-zero y cold start

Con `min_replicas = 0` el app se escala a 0 cuando no hay trafico. El primer request paga **cold start** (~1-5s warm, 10-30s si el contenedor es grande y la imagen no esta cacheada). Para workloads latency-sensitive: `min_replicas = 1` (o mayor si quieres warmup).

### Precio

Dos componentes:

- **Request-based**: por millon de requests + por vCPU-s y GB-s **durante** el request.
- **Idle**: si `min_replicas > 0`, pagas por mantener replicas tibias (precio reducido vs activo).

Comparado con App Service P1v3 (~70 USD/mes constantes), un Container App con trafico esporadico puede estar en 2-10 USD/mes.

---

## 8. Revisions, traffic split y el canary nativo

Para hacer canary nativo con Container Apps:

```hcl
resource "azurerm_container_app" "api" {
  name                         = "ca-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"   # <-- clave

  template {
    container {
      name   = "api"
      image  = "ghcr.io/example/api:v2"
      cpu    = 0.5
      memory = "1Gi"
    }
    min_replicas = 1
    max_replicas = 10
    revision_suffix = "v2"
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      revision_suffix = "v1"
      percentage      = 90
    }
    traffic_weight {
      revision_suffix = "v2"
      percentage      = 10
    }
  }
}
```

### Promocion y rollback

- **Promover a 100%**: cambiar los `traffic_weight` a `v2 = 100`, `v1 = 0`, aplicar y verificar.
- **Rollback inmediato**: volver a `v1 = 100`, aplicar. Las revisions anteriores siguen vivas (en estado deactivated pero recreables en segundos) y el DNS no cambia.

### Diferencia con AWS

- **ECS/Fargate** hace canary via **CodeDeploy BlueGreen** o **AppMesh traffic shifting** — mas complejo, orquesta ALB target groups.
- **App Runner** solo hace rolling, no canary granular.
- **Container Apps** lo hace **declarativo en el recurso mismo**. Es la razon principal por la que el capstone del programa Azure vive aqui.

---

## 9. Dapr integrado y por que importa

**Dapr** (Distributed Application Runtime) es un proyecto CNCF que da *building blocks* portables para microservicios: `state`, `pub/sub`, `secrets`, `bindings`, `service invocation`. Corre como **sidecar** en el pod.

Container Apps lo integra como feature nativo:

```hcl
dapr {
  app_id       = "api"
  app_port     = 8000
  app_protocol = "http"
}
```

y en el environment configuras **components** (`azurerm_container_app_environment_dapr_component`) que apuntan a Service Bus, Cosmos DB, Key Vault, etc. Tu codigo llama `http://localhost:3500/v1.0/state/mystore` y Dapr enruta.

### Valor

- **Portabilidad**: el mismo codigo corre en K8s con Dapr sin cambios.
- **No vendor lock-in a nivel de SDK**: no usas `azure-storage-queue` en tu codigo; usas la abstraccion Dapr.

### Cuando no

- App pequena, un solo backing store. El sidecar anade overhead (~50MB RAM) y una capa mas que debuggear.

---

## 10. Azure Functions y el plan Flex Consumption

**Azure Functions** es FaaS: codigo + trigger, pagas por invocacion. Triggers soportados (incompleto):

- `HTTP` — webhook o API ligera.
- `Timer` — cron.
- `Queue` (Storage), `Service Bus Queue/Topic`, `Event Hub`, `Event Grid`.
- `Blob` (creado/modificado).
- `Cosmos DB` change feed.

### Planes

| Plan | Caracteristica | Cuando |
|------|----------------|--------|
| Consumption (clasico) | Scale-to-zero, cold start grande, 1.5GB RAM max por instancia | Jobs puntuales |
| Premium (EP1/EP2/EP3) | VNet integration, pre-warmed instances, sin cold start | Prod HTTP latency-sensitive |
| **Flex Consumption** | VNet integration + scale-to-zero + concurrency control | Nuevo default moderno |
| Dedicated (App Service plan) | Comparte compute con un App Service existente | Reuso de capacidad |

**Flex Consumption** es el plan actual recomendado para muchos casos: combina scale-to-zero (como Consumption) con VNet y pre-warming configurable. Reemplaza a Consumption clasico en nuevos disenos.

### Cuando Functions y no Container Apps

- **Trigger no-HTTP** (queue, timer, blob): Functions lo hace trivial, Container Apps requiere scaler KEDA custom.
- **Codigo muy pequeno** (una funcion de 50 lineas). Container Apps obliga a envolver en Docker + ingress.
- **Equipo que ya tiene stack serverless** (host.json, bindings) desde Lambda — mapping mental identico.

---

## 11. Mapping AWS -> Azure, workload por workload

| Workload AWS | Azure equivalente | Nota |
|--------------|--------------------|------|
| EC2 single VM | `azurerm_linux_virtual_machine` | Spot soportado en ambos. |
| EC2 Auto Scaling Group | `azurerm_linux_virtual_machine_scale_set` | VMSS Flexible orchestration es el modo moderno. |
| ECS/Fargate HTTP service | **Container Apps** | ingress + revisions + scale rules. |
| ECS/Fargate scheduled task | **Container Apps Jobs** o ACI | Jobs es la nueva primitiva para batch en Container Apps. |
| Lambda HTTP (API Gateway) | **Functions HTTP** o Container Apps | Functions si es codigo puro; Container Apps si quieres control del contenedor. |
| Lambda event-driven (SQS/EventBridge) | **Functions con binding** | Mapping 1:1. |
| App Runner | **App Service** o Container Apps | Container Apps gana en traffic split; App Service gana en slot-swap. |
| Elastic Beanstalk | **App Service** | No hay equivalente mas cercano. |

---

## 12. Fundamentos internos y errores comunes

### Container Apps corre sobre AKS, pero no es AKS

Azure opera un AKS gestionado por detras — tu no lo ves. Implicaciones:

- No tienes `kubectl` acceso. Toda la operacion es via `azurerm_container_app` o `az containerapp`.
- No puedes instalar operators, CRDs, ni tocar la red del cluster.
- Si necesitas eso, usa AKS (`az-07`).

### `min_replicas = 0` **no** aplica a latency-sensitive

Un API de pagos con SLA de p99 < 200ms no puede permitirse 10s de cold start en el primer request del dia. Si usas Container Apps en ese caso: `min_replicas = 2` (dos para resiliencia AZ) y, si el gasto escala, movete a `azurerm_container_app` + App Service equivalente o AKS con nodos reservados.

### Revisions **inmutables**: cualquier cambio al template crea una nueva

Si cambias una env var y no incrementas `revision_suffix`, el provider la crea igualmente (sufijo auto si no lo das). Esto es correcto, pero significa que **el estado real tiene N revisions** aunque en tu `.tf` veas solo una definicion. Usa `revision_suffix = "vX"` explicito para auditoria.

### Managed Identity es la unica forma correcta de leer secretos

Nunca pongas `AZURE_CLIENT_SECRET` en env vars de un Container App. Habilita MI (`identity { type = "SystemAssigned" }`), concede `Key Vault Secrets User` role sobre el Key Vault, y referencia el secreto via `secretRef` apuntando a un `secret` del Container App poblado por Key Vault (`key_vault_secret_id`).

### Autoscaling por metrica custom requiere Application Insights

VMSS escala por metricas de Azure Monitor. Si quieres escalar por `requests_per_second` reales de tu app, debes:

1. Instrumentar la app con Application Insights (`az-08`).
2. Publicar la metrica custom.
3. Referenciarla en el `autoscale_setting` del VMSS.

Sin esto, estas escalando por CPU, que es una proxy ruidosa.

### Costos: lee el pricing calculator antes de recomendar

- "App Service P1v3" suena pequeno pero son 70 USD/mes constantes **por app**. 10 apps = 700 USD solo en compute.
- "Container Apps con scale-to-zero" suena gratis, pero si tu app arranca por salud-check cada 30s nunca se duerme — paga como si estuviera activa.
- "VMSS con 2 instancias B2s" cuesta ~60 USD/mes y, si el workload es de 2 req/s de media, Container Apps saldria por <5 USD. Elegir compute mal cuesta dinero real.

---

## Referencias

Ver `../resources/links.md`.
