# az-03 — VNet, NSG, ASG, Private Link y Hub-Spoke

## Identificación

- **ID:** `az-03-vnet-nsg-asg-private-link-hub-spoke`
- **Curso:** `azure`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `az-01` (modelo/subs/RGs/CLI), `az-02` (Entra ID/RBAC/MI), curso **aws** ≥ `aws-03`, `aws-07`.

## Objetivo

Construir una **red regional segura en Azure** y aprender el patrón **Hub-Spoke** sin provisionar nada en una suscripción real. Al terminar deberías poder diseñar — en papel y en Terraform — una VNet con subnets `public`/`private`, aplicar **NSG** apoyadas en **ASG** por rol lógico, eliminar el egress a internet a servicios PaaS con **Private Endpoints** (Private Link), y conectar dos VNets de workload a una VNet central (hub) usando **VNet Peering**.

El módulo es **mayoritariamente conceptual + Terraform como plantilla + ADR**. Las dos actividades son independientes y **no requieren una suscripción Azure activa**: todo el flujo es `terraform init -backend=false` + `terraform validate` + `terraform fmt -check` + validadores estructurales sobre HCL y Markdown. **Cero coste real**.

## Alcance

Este módulo cubre:

- **VNet regional** con subnets, address space CIDR, delegaciones y service endpoints vs private endpoints.
- **Network Security Group (NSG)** stateful: reglas allow/deny de ingress/egress, prioridad numérica, application a subnet o NIC, cálculo de la *effective rule* por NIC.
- **Application Security Group (ASG)**: agrupar NICs por rol lógico (`asg-web`, `asg-app`, `asg-db`) y referenciarlas desde reglas NSG — patrón escalable, menos listas de IPs.
- **Service Endpoints** vs **Private Endpoints / Private Link**: por qué el Private Endpoint es el camino moderno para servicios PaaS (Storage, Key Vault, SQL) — da IP privada dentro de tu VNet y elimina ruta a internet.
- **VNet Peering** y **topología Hub-Spoke**: hub con firewall / VPN gateway, spokes por workload; cuándo escalar a **Azure Virtual WAN**.
- **Private DNS Zones** y su rol en Private Endpoints (resolución de nombres `*.privatelink.<servicio>.windows.net`).
- Mapping conceptual **AWS → Azure** (VPC↔VNet, Security Group stateful↔NSG + ASG, VPC Endpoint Interface↔Private Endpoint, Transit Gateway↔VWAN/Hub-Spoke).

Lo que **no** cubre (se verá después):

- **Azure Firewall**, **Application Gateway (WAF)** y **Front Door** como piezas L4/L7/global — se nombran pero no se laboran aquí.
- **NAT Gateway** regional en profundidad (se usa un ejemplo mínimo).
- **AKS networking** (Azure CNI vs Overlay) — se cubre en `az-07`.
- **DevSecOps de red** y **Azure Policy** sobre red — se cubre en `az-09` y `az-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución contra Azure real):
  - `01-vnet-with-nat-and-pe/` — VNet con subnet `app`, NAT Gateway para egress controlado y Private Endpoint a Storage.
  - `02-nsg-with-asg/` — NSG que referencia ASGs (`asg-web` y `asg-app`) en vez de prefijos IP.
  - `03-hub-spoke-skeleton/` — esqueleto Terraform de un hub + 2 spokes con peering bidireccional.
- **`activities/`** — dos actividades **independientes**:
  - `01-vnet-plus-private-endpoints/` — escribir Terraform para VNet + NSG + ASG + Private Endpoint a Storage y Key Vault, validarlo estructuralmente y producir un **ADR** justificando CIDRs, subnets y Private Endpoints.
  - `02-hub-spoke-tf/` — escribir Terraform de un hub-spoke mínimo (1 hub + 2 spokes) con peering y Private DNS zone compartida, validar y entregar un diagrama ASCII explicando el flujo de tráfico.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué NSG es stateful; por qué ASG escala mejor que listas de IP; por qué Private Endpoint elimina egress por internet a PaaS; qué resuelve el patrón Hub-Spoke y cuándo subir a Virtual WAN. |
| Operativa (sin infra real) | Escribir HCL `azurerm` para VNet + subnets + NSG + ASG + Private Endpoint; validarlo con `terraform validate` sin credenciales; justificar un CIDR plan sin solapamientos. |
| Arquitectónica | Decidir topología hub-spoke vs flat para N workloads; mapear una VPC AWS equivalente a VNet Azure para un workload dado; decidir Service Endpoint vs Private Endpoint. |

## Criterios de evaluación

- Dado un escenario con 2 workloads y 1 cuenta de shared services, propones una topología (hub-spoke o flat) justificada.
- Lees una NSG rule con `source_application_security_group_ids` y explicas qué permite/deniega.
- Justificas por qué Private Endpoint es preferible a Service Endpoint para `checkout-prod` en PCI-light.
- Diseñas un plan CIDR para 1 hub + 3 spokes sin solapamientos y lo defiendes.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Terraform** (`main.tf`, `variables.tf`, `outputs.tf`) de la actividad 01 con VNet + NSG + ASG + Private Endpoint a Storage y Key Vault + Private DNS zones.
- **ADR** `ADR-VNET-DESIGN.md` justificando CIDRs, subnets y uso de Private Link (sale de la actividad 01).
- **Terraform** del hub-spoke (`hub.tf`, `spoke-a.tf`, `spoke-b.tf`, `peering.tf`) y **diagrama ASCII** del flujo de tráfico (sale de la actividad 02).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos HCL y Markdown. No se requiere suscripción Azure activa. El workflow es `terraform init -backend=false` (descarga el provider `azurerm` pero no autentica) + `terraform validate` + `terraform fmt -check`. **No se ejecuta `terraform apply`** y los validadores no requieren credenciales.

Si en una fase posterior decides provisionar lo diseñado en una suscripción real:

- **VNet, subnets, NSG, ASG, VNet Peering**: gratis como recursos; el peering factura por GB transferido.
- **Private Endpoint**: tiene coste por hora (unos pocos USD/mes por endpoint) + coste por GB procesado.
- **Private DNS Zone**: coste por zona por mes y por query (muy barato en escalas pequeñas).
- **NAT Gateway**: factura por hora + por GB procesado (puede subir en workloads con egress alto).
- **Azure Firewall / Virtual WAN**: factura mucho más (Firewall por hora + datos; VWAN por hub por hora). En este módulo **no** se tocan.

## Siguiente módulo

→ `az-04-compute-vm-vmss-container-apps-functions-app-service` — compute Azure con énfasis en Container Apps; usará la VNet y Private Endpoints de este módulo para despliegues con integración VNet.
