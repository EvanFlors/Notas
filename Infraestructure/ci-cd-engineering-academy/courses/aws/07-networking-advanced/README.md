# aws-07 — Networking avanzado: ALB, NLB, PrivateLink, Route 53, Transit Gateway

## Identificación

- **ID:** `aws-07-networking-advanced`
- **Curso:** `aws`
- **Nivel:** intermedio
- **Duración estimada:** 6 h
- **Prerrequisitos:** `aws-03-vpc-basics` (VPC, subnets, NAT, endpoints), `aws-06-iam-advanced` recomendado.

## Objetivo

Elegir y provisionar el **balanceador correcto** (ALB vs NLB vs GWLB), publicar aplicaciones con **TLS + DNS** (ACM + Route 53) y conectar VPCs/cuentas con el criterio adecuado de **coste y seguridad**: VPC peering, **Transit Gateway**, **PrivateLink** y **egress controlado**. Terminado el módulo deberías justificar por qué TGW escala sobre peering en topologías N:N, por qué PrivateLink evita exponer servicios a internet y evita egress por NAT, y por qué un *Interface Endpoint* puede salir más barato que mantener un NAT Gateway cuando hay volumen de tráfico a servicios AWS.

## Alcance

Este módulo cubre:

- **Elastic Load Balancing**: diferencias reales entre **ALB** (L7, host/path routing, OIDC, WAF, HTTPS/HTTP2), **NLB** (L4, static IP, PrivateLink, TLS passthrough o TLS termination, UDP) y **GWLB** (L3 bump-in-the-wire para appliances tipo firewall).
- **Target groups**: tipos `instance`, `ip`, `lambda`, `alb` (ALB como target de NLB); **health checks**; **sticky sessions**; **deregistration delay**.
- **TLS**: terminación con **ACM** (certificado gratis con validación DNS); por qué para ALB vive en la misma región y para CloudFront debe estar en `us-east-1` (se profundiza en `aws-13`).
- **Route 53**: hosted zones públicas y privadas, **alias records**, routing policies (simple, weighted, latency, geolocation, failover, geoproximity, multivalue).
- **Conectividad multi-VPC/multi-cuenta**: VPC peering (1:1), **Transit Gateway** (hub-and-spoke N:N), nociones de **Cloud WAN**.
- **PrivateLink**: exponer un servicio interno como **Interface Endpoint** consumible desde otras VPCs o cuentas sin pasar por internet ni NAT.
- **Egress controlado**: combinación NAT + endpoints + opcional **Network Firewall**; análisis de coste de NAT vs Interface Endpoint cuando el egreso principal es a servicios AWS.

Lo que **no** cubre (se verá después):

- Edge global (CloudFront, Lambda@Edge, signed URLs) → `aws-13`.
- Observabilidad del plano de red (VPC Flow Logs, CloudTrail de red) → `aws-12`.
- EKS Load Balancer Controller y External DNS → `aws-11`.
- CloudFront + WAF + geo restriction → `aws-13`.

### Importante: sin coste AWS real

Este módulo es **100 % diseño + Terraform `plan`/`validate` + ADR**. No se aplica infraestructura. Las razones:

- Un **NAT Gateway** cuesta ~$0.045 USD/h + egress; dejado olvidado un fin de semana son dolares reales que no corresponde cargar al estudiante.
- **Transit Gateway** cobra por *attachment-hour* y por GB procesado.
- **PrivateLink** cobra por *VPCE-hour* y por GB.
- **ALB** cobra por hora + LCU.

Todo lo que haremos será generar `terraform plan` sobre una configuración con `provider "aws"` *stub* (`skip_credentials_validation = true`, `skip_requesting_account_id = true`, etc.), ejecutar `terraform validate`, y redactar **ADRs** y análisis de coste en CSV/MD. Los validadores comprueban **estructura** (archivos, recursos esperados, encabezados ADR, filas CSV), no estado remoto.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones (criterios de elección de LB, ACM/Route 53, peering vs TGW, PrivateLink end-to-end, cálculo de coste NAT vs Interface Endpoint, egress patterns, trampas comunes).
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-alb-with-acm-and-route53/` — diagrama + fragmentos Terraform anotados para publicar una app con ALB + ACM + alias record en Route 53.
  - `02-nlb-with-privatelink/` — productor (NLB + VPC Endpoint Service) y consumidor (Interface Endpoint) con `allowed_principals` entre cuentas.
  - `03-tgw-hub-and-spoke/` — topología hub (TGW + attachments + route tables de propagación/asociación) comparada con la variante peering 1:1.
- **`activities/`** — dos actividades (sin dependencia entre sí):
  - `01-publish-app-with-alb-tls-dns/` — **guiada**. Escribes Terraform para VPC + ALB + ACM + Route 53, generas `terraform plan` offline y entregas `DECISIONS.md` con 3 ADRs (ALB vs NLB, DNS validation vs email, alias vs CNAME).
  - `02-expose-internal-service-via-privatelink/` — **independiente**. Escribes Terraform (NLB + Endpoint Service en el productor; Interface Endpoint en el consumidor), entregas `DECISIONS.md` con 2 ADRs y un `cost-tradeoff.csv` + `cost-tradeoff.md` que compara NAT Gateway vs Interface Endpoint para 1, 5 y 10 servicios AWS consumidos.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar ALB vs NLB vs GWLB en una frase cada uno. Enumerar las 7 routing policies de Route 53. Distinguir peering, TGW, Cloud WAN y PrivateLink por caso de uso. |
| Operativa (sin apply) | Escribir Terraform válido (`terraform validate` en verde) para ALB+ACM+R53 y para PrivateLink productor/consumidor; generar `terraform plan` offline. |
| Arquitectónica | Justificar NLB vs ALB con criterios concretos (L4 vs L7, static IP, PrivateLink). Decidir TGW vs peering vía número de VPCs. Decidir Interface Endpoint vs NAT con un cálculo de coste explícito. |

## Criterios de evaluación

- Para 3 escenarios (API HTTPS pública, servicio TCP interno con IP fija, inspección con appliances), elige LB y lo justifica.
- Dado un stack con 5 VPCs, elige TGW y justifica contra peering 1:1.
- Dado un workload que consume S3 + DynamoDB + Secrets Manager + Kinesis desde subnet privada, calcula coste mensual de NAT vs Gateway Endpoint + 2 Interface Endpoints y recomienda el ganador con cifras.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Config Terraform (`main.tf` + `variables.tf`) de la actividad 01 que pasa `terraform validate` y genera un `plan` offline, más `DECISIONS.md` con 3 ADRs.
- Config Terraform del productor y del consumidor PrivateLink de la actividad 02, más `DECISIONS.md` con 2 ADRs, `cost-tradeoff.csv` y `cost-tradeoff.md`.

## Siguiente módulo

→ `aws-08-managed-data-rds-aurora-dynamodb` — bases de datos administradas, con la red que acabas de dominar como sustrato.
