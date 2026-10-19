# gcp-03 — VPC global y networking en GCP

## Identificación

- **ID:** `gcp-03-vpc-global-and-networking`
- **Curso:** `gcp`
- **Nivel:** fundamentos (diferencial contra AWS)
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gcp-01` (projects y billing), `gcp-02` (IAM, service accounts), curso `aws` ≥ `aws-03` y `aws-07` (VPC regional y ALB).

## Objetivo

Interiorizar la decisión arquitectónica más característica de GCP: la **VPC es global**, con subnets regionales que se comunican sin peering, firewall rules que pueden filtrar por **service account** (identidad, no sólo IP), y un **Load Balancer HTTP(S) global con IP anycast**. Al terminar deberías poder diseñar — en papel y con Terraform validado — una red **Shared VPC** multi-región y publicar una app detrás de un **LB global** con certificado gestionado por Google, sin confundir el modelo con el de AWS.

## Alcance

Este módulo cubre:

- **VPC global** con subnets regionales; modos `auto` vs `custom`; CIDR planning sin solapes.
- **Firewall rules globales** (allow/deny por *tags*, por *service account*, por rangos); por qué filtrar por SA es más fuerte que por SG.
- **Cloud NAT regional** (egress IPv4 para instancias sin IP pública) y **Private Google Access** (acceso a APIs de Google sin salir a internet).
- **Shared VPC**: host project ↔ service projects; roles necesarios (`roles/compute.networkUser`, `roles/compute.networkAdmin`).
- **Peering**, **Network Connectivity Center**, **Interconnect/VPN**: cuándo usar cada uno (sin provisionar nada).
- **Cloud Load Balancing**: *global external HTTPS LB* con IP anycast, *global managed SSL cert*, backend services, URL maps.
- **Cloud Armor** (WAF) y **Cloud CDN** sobre LB — introducción.
- **Diferencias clave con AWS**: una VPC global vs una VPC por región, firewall por identidad vs SG por ENI, LB con IP anycast única vs ALB regional + Route 53 latency.

Lo que **no** cubre (ver después):

- GKE y su integración de red (`gcp-07`).
- Observabilidad de red (`gcp-08`).
- Interconnect/VPN con un ISP real — se referencia conceptualmente, no se laboratoriza.

Este módulo es **mayoritariamente conceptual + ADR + validación de HCL/JSON**. **No** se provisiona nada en una cuenta real: los ejercicios de VPC usan Terraform `plan` (sin `apply`), y las reglas de firewall se escriben como JSON/HCL + diagramas ASCII. **No hay costo** en GCP.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-vpc-custom-with-cloud-nat/` — VPC custom con subnets en 2 regiones europeas, Cloud NAT y Private Google Access habilitados.
  - `02-firewall-by-service-account/` — anatomía de una firewall rule filtrada por `sourceServiceAccounts` / `targetServiceAccounts`, contrastada con la variante por `targetTags`.
  - `03-global-https-lb-with-managed-cert/` — LB HTTP(S) global con backend service, URL map, `google_compute_managed_ssl_certificate` y notas sobre Cloud Armor + CDN.
- **`activities/`** — dos actividades **independientes**:
  - `01-shared-vpc-host-and-service/` — diseñar una Shared VPC (host + 2 service projects) con firewall por service account, y escribir el ADR + reglas de firewall en JSON.
  - `02-publish-app-global-lb/` — producir el HCL de un LB global con managed cert, URL map, backend, Cloud Armor y diagrama ASCII; validar con `terraform validate` (sin `apply`).
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué la VPC es global en GCP y qué cambia respecto a AWS; por qué una firewall rule por SA es más fuerte que un SG por ENI; por qué el LB global usa IP anycast. |
| Operativa (sin infra) | Diseñar una Shared VPC con 2 regiones y 2 service projects; escribir firewall rules por SA en JSON; declarar un LB global en HCL que pase `terraform validate`. |
| Arquitectónica | Decidir Shared VPC vs peering vs NCC; decidir LB global vs regional; integrar Cloud Armor y managed cert sin bloquear el pipeline. |

## Criterios de evaluación

- Dado un diagrama de dos VPCs, identifica si deben ir en Shared VPC, peering, NCC o seguir separadas, justificando trade-offs.
- Lee una firewall rule y explica correctamente a qué tráfico aplica (incluyendo `sourceServiceAccounts` vs `sourceRanges`).
- Justifica por qué una app con usuarios en 3 continentes se publica mejor con LB global que con un ALB por región.
- Nombra las piezas mínimas de un LB global HTTP(S): forwarding rule, target proxy, URL map, backend service, health check.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **ADR** `ADR-SHARED-VPC.md` con decisión de host project, subnets, firewall por SA y mapping con AWS (sale de la actividad `01`).
- **`firewall-rules.json`** con al menos 3 reglas (allow-health-checks, allow-internal-by-sa, deny-egress-default) sintácticamente válidas (sale de la actividad `01`).
- **`lb.tf`** con un LB global declarado, `terraform validate` en verde, y `ARCHITECTURE.md` con diagrama ASCII del flujo de request (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, JSON y HCL. No se requiere project GCP activo. Si en una fase posterior decides provisionar lo diseñado:

- **VPC, subnets, firewall rules**: gratis como recursos; el egress sí cobra.
- **Cloud NAT**: cobra por hora y por GB procesado — presupuestar.
- **Global HTTP(S) LB**: cobra por regla de forwarding + por GB procesado; sumar Cloud Armor y Cloud CDN si se habilitan.
- **Managed SSL certificates** (Google-managed): gratis.
- **Shared VPC**: gratis como feature; sólo cobran los recursos que coloques dentro.

## Siguiente módulo

→ `gcp-04-compute-engine-cloud-run-cloud-functions` — elegir el compute correcto; publicar la app detrás del LB global diseñado aquí.
