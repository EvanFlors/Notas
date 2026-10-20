# Actividad 01 — VNet + NSG + ASG + Private Endpoints (Terraform)

## 1. Identificación

- **ID:** `az-03-01-vnet-plus-private-endpoints`
- **Tecnología:** `azure`
- **Módulo:** `az-03-vnet-nsg-asg-private-link-hub-spoke`
- **Dificultad:** intermediate
- **Duración estimada:** 90–110 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

El equipo de la startup del escenario de `az-02` ha decidido empezar a mover `checkout-dev` a Azure. El workload tiene dos componentes de datos:

- **Blob Storage** (`stcheckoutdev000X`) para artefactos de build y volcados temporales.
- **Key Vault** (`kv-checkout-dev`) para los secretos (connection string de Postgres, API keys de pasarelas).

Requisitos del equipo de Platform y Security:

- **Residencia** en `westeurope`.
- Cualquier VM / Container App que suba luego **no debe salir a internet** para leer Storage o Key Vault — debe usar la red privada.
- La red debe ser **extensible**: en 6 meses se añadirá `checkout-prod` como un segundo entorno; el plan CIDR de hoy debe dejar espacio.
- **Guardrails de red**: debe existir un patrón NSG+ASG, no reglas por IP.

Tu encargo: **escribir el Terraform** que modela esta red (VNet + 2 subnets + NSG con 2 ASG + Private Endpoints a Storage y Key Vault con sus Private DNS Zones) y producir un **ADR** justificando las decisiones.

**Importante**: no hay suscripción Azure real. No se ejecuta `terraform apply`. El entregable son los archivos HCL + el ADR, validados estructuralmente.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar un plan CIDR mínimo con espacio reservado para crecimiento.
- Escribir una VNet con subnets segregadas por rol (`snet-app`, `snet-pe`).
- Modelar una NSG apoyada en ASG (`asg-app`, `asg-pe`) con prioridades justificadas.
- Crear Private Endpoints a dos servicios PaaS distintos (Storage blob, Key Vault) con sus Private DNS Zones y los links a la VNet.
- Explicar por qué Private Endpoint > Service Endpoint para este workload.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (secciones 1–8 son críticas).
- Haber recorrido los 3 ejemplos del módulo (en especial `01-vnet-with-nat-and-pe` y `02-nsg-with-asg`).
- Haber completado `az-01` y `az-02`.
- Herramientas: `bash`, `terraform` ≥ 1.5 (opcional pero recomendado para validar HCL), un editor Markdown.

**Costos**: ninguno. `terraform init -backend=false` descarga el provider `azurerm` pero no autentica contra Azure. `terraform validate` y `terraform fmt -check` corren offline. **No ejecutes `terraform apply`**.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-03-01-vnet-pe
cd /tmp/az-03-01-vnet-pe
```

Puedes usar otro directorio pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe el Terraform

Produce **tres archivos** HCL en el directorio raíz:

- `main.tf` — RG + VNet + subnets + NSG + reglas + ASG + Storage + Key Vault + Private Endpoints + Private DNS Zones + links.
- `variables.tf` — al menos `location`, `address_space`, `resource_group_name`.
- `outputs.tf` — al menos `vnet_id`, `private_endpoint_storage_ip`.

Requisitos de contenido (el validador los exige):

1. **Provider** `azurerm` declarado en `terraform { required_providers { azurerm = { source = "hashicorp/azurerm" } } }` y bloque `provider "azurerm" { features {} }`.
2. **Un `azurerm_virtual_network`** con `address_space` que sea un prefijo RFC1918 (no `10.0.0.0/16` por default — justifica tu CIDR en el ADR).
3. **Dos `azurerm_subnet`**: al menos uno llamado con prefijo `snet-app` y otro con prefijo `snet-pe` (o `snet-privatelink` / `snet-privateendpoints`).
4. **Un `azurerm_network_security_group`** y al menos **tres `azurerm_network_security_rule`** (una `Deny`, dos `Allow`).
5. **Al menos dos `azurerm_application_security_group`**.
6. **Al menos una regla NSG** que referencie `source_application_security_group_ids` o `destination_application_security_group_ids`.
7. **Un `azurerm_storage_account`** con `public_network_access_enabled = false`.
8. **Un `azurerm_key_vault`** (nombre único; cualquier SKU) con `public_network_access_enabled = false` **o** con `network_acls` cerrando el default.
9. **Dos `azurerm_private_endpoint`**: uno para `blob` del Storage, otro para `vault` del Key Vault.
10. **Dos `azurerm_private_dns_zone`**:
    - `privatelink.blob.core.windows.net`.
    - `privatelink.vaultcore.azure.net`.
11. **Dos `azurerm_private_dns_zone_virtual_network_link`** (uno por zona, cada uno linkeado a tu VNet).
12. **Ningún `subscription_id` ni `tenant_id` real** en los archivos. Si necesitas placeholders usa `00000000-0000-0000-0000-000000000000`.

### 5.3 Escribe `ADR-VNET-DESIGN.md`

Formato ADR estándar (6 secciones obligatorias):

```
# ADR 002 — Diseno de VNet para checkout en Azure

## Estado
Propuesto | Aceptado

## Contexto
<por que, constraints: westeurope, PCI-light, extensibilidad>

## Decision
### 1. Plan CIDR
<rango elegido y por que, espacio para checkout-prod y shared services>

### 2. Subnets
<snet-app, snet-pe, tamanos y por que>

### 3. NSG + ASG
<reglas minimas, prioridades, por que ASG en vez de CIDR>

### 4. Private Endpoints
<por que Private Endpoint y no Service Endpoint>

### 5. Private DNS Zones
<por que viven en el mismo RG hoy y mencion a futura centralizacion en hub>

(Incluye un diagrama ASCII dentro de un code fence)

## Consecuencias
### Positivas
### Negativas

## Alternativas descartadas
### Alt A: Service Endpoints en vez de Private Endpoints
### Alt B: Una sola subnet para todo
```

Contenido mínimo que el validador busca:

- Encabezado con `ADR`.
- Secciones `Estado`/`Status`, `Contexto`/`Context`, `Decisi[oó]n`/`Decision`, `Consecuencias`/`Consequences`, `Alternativas`/`Alternatives`.
- Al menos un **diagrama ASCII** dentro de un code fence.
- Mención explícita de `westeurope` o similar `eu-*`.
- Mención de `Private Endpoint` y `Private DNS Zone`.
- Mención de `NSG` y `ASG`.
- Mención del plan CIDR con un prefijo tipo `10.X.0.0/16`.
- Al menos **2 alternativas descartadas**.

### 5.4 Entregables

```
/tmp/az-03-01-vnet-pe/
├── main.tf
├── variables.tf
├── outputs.tf
└── ADR-VNET-DESIGN.md
```

## 6. Resultado esperado

- Los 4 archivos existen y son coherentes.
- El validador pasa en verde.
- (Opcional) `terraform init -backend=false && terraform validate` corre sin errores sintácticos. El validador lo intenta y, si `terraform` no está instalado, lo omite con un aviso.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: ADR justifica cada decisión (no solo lista piezas).
- **Reproducibilidad**: alguien externo puede leer el HCL + ADR y entender el workload sin ambigüedades.
- **Compliance**: no hay IDs reales de tenant/subscription.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-03-01-vnet-pe
```

El validador comprueba **estructura** (presencia de recursos y de secciones), no la semántica fina de la red. Compara tu solución con `solution/REFERENCE-NOTES.md` después de haberla hecho.

## 9. Preguntas de reflexión

1. ¿Por qué elegiste tu CIDR (`10.X.0.0/16`)? ¿Qué dejas libre para `checkout-prod` y `shared-services`?
2. ¿Qué pasaría si usaras **una sola subnet** compartida para la app y los Private Endpoints?
3. ¿Qué sucede si borras el `azurerm_private_dns_zone_virtual_network_link`?
4. ¿Qué cambia si cambias `public_network_access_enabled = false` por `true` en Storage? ¿El PE sigue funcionando?
5. ¿Cuándo preferirías Service Endpoint sobre Private Endpoint?

## 10. Extensiones

- Añade un `azurerm_nat_gateway` para egress de `snet-app` y justifica en el ADR cuándo lo necesitas.
- Añade un **tercer Private Endpoint** a un Container Registry (`privatelink.azurecr.io`) para preparar el `az-10`.
- Añade un **tag** `env=dev` a todos los recursos con `tags = { env = "dev" }` y comenta en el ADR por qué los tags en Azure son por recurso Y por RG.

## 11. Limpieza

```bash
rm -rf /tmp/az-03-01-vnet-pe
```

No hay procesos ni infraestructura Azure que detener (no se provisionó nada).
