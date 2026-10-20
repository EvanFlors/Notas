# aws-13 — Edge: DNS, CDN y ACM

## Identificación

- **ID:** `aws-13-edge-dns-cdn-acm`
- **Curso:** `aws`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `aws-05` (S3), `aws-07` (networking avanzado). Conocer DNS básico y TLS a nivel práctico.

## Objetivo

Publicar workloads al mundo con **TLS correcto, CDN y DNS** usando **Route 53 + ACM + CloudFront**. Al terminar deberías poder:

- Diseñar una zona Route 53 (hosted zone pública o privada) y entender su **modelo de costos** y de **delegación**.
- Emitir un certificado **ACM** público con **validación DNS automática** y saber **por qué debe estar en us-east-1** cuando lo usa CloudFront.
- Montar una distribución **CloudFront** con un origen S3 protegido por **OAC** (Origin Access Control) y un segundo origen "API dinámica" sobre ALB, con **ordering** correcto de cache behaviors.
- Decidir **cache policy** y **origin request policy** por ruta (estática vs API) y justificar la elección.
- Firmar URLs/cookies, saber cuándo usar cada una, y entender el límite entre CloudFront Functions y Lambda@Edge.

> **Importante — presupuesto de laboratorio:** este módulo **no provisiona recursos reales** en AWS. Todo se demuestra con `terraform plan` (sin apply), con validación estructural de JSON de distribución CloudFront, y con un *walkthrough* escrito de la validación DNS de ACM. Lo único que tendría costo si lo levantaras es la **hosted zone pública de Route 53 (0.50 USD/mes por zona)** y las consultas DNS; CloudFront y ACM público son gratuitos a nivel de recurso y solo cobran por **transferencia/requests**. Ver §4.

## Alcance

Este módulo cubre:

- **Route 53** avanzado: hosted zones públicas y privadas, delegación entre cuentas (NS records en la zona padre), **routing policies** (simple, weighted, latency, failover, geolocation, geoproximity), **Resolver endpoints** inbound/outbound para DNS híbrido.
- **ACM** (AWS Certificate Manager): certificados públicos gratuitos con validación DNS automática, renovación automática, **requisito regional** (us-east-1 para CloudFront, región del ALB para ALB), **Private CA** como opción pagada separada.
- **CloudFront**: distribuciones, orígenes, **cache behaviors ordenados**, cache policies vs origin request policies vs response headers policies, **OAC** vs **OAI** (legacy), **CloudFront Functions** vs **Lambda@Edge**, **signed URLs** y **signed cookies**, invalidaciones, **HTTP/2 y HTTP/3 (QUIC)**.
- **WAF** en CloudFront (web ACL asociada), **geo restriction** nativa del distribution.
- **Modelo de costos** real a nivel de edge: por qué 0.50 USD/zona/mes es un *gotcha* típico, por qué el borrado de una hosted zone olvidada ahorra dinero, por qué CloudFront puede abaratar S3 si el egreso domina.

Lo que **no** cubre (otros módulos):

- Políticas IAM de ACM/CloudFront a nivel fino (ver `aws-02`, `aws-06`).
- VPC lattice / PrivateLink / Transit Gateway (ver `aws-07`).
- Hosting del backend ALB/ECS/EKS (ver `aws-10`, `aws-11`).
- Firma automática de URLs desde una Lambda (ver `aws-14`).

## Materiales

- **`theory/lesson.md`** — lección profunda (10 secciones) sobre DNS → TLS → CDN desde fundamentos.
- **`examples/`** — tres ejemplos **demostrativos** (sin ejecución real contra AWS):
  - `01-static-site-s3-cloudfront-oac/` — distribución CloudFront para un sitio estático en S3 con OAC. Terraform `plan` + JSON de distribución comentado.
  - `02-api-on-alb-via-cloudfront/` — distribución con dos orígenes (S3 estático + ALB dinámico) y **cache behaviors ordenados**. Explica el *ordering gotcha*.
  - `03-signed-urls-s3/` — firma de URL hacia un objeto privado de S3 vía CloudFront, con un **key group** y una clave pública. Walkthrough + snippet Python.
- **`activities/`** — dos actividades **independientes** (no dependen entre sí):
  - `01-publish-site-with-cf-acm-route53/` — construir la plantilla Terraform de un sitio con CF+ACM+Route 53 y validar su `plan` + un JSON de distribución exportado + un documento `ACM_DNS_WALKTHROUGH.md` + un **ADR de cache behavior ordering**.
  - `02-add-waf-and-geo-restriction/` — análisis escrito: diseñar WAF web ACL con 3 reglas razonadas, decidir geo restriction en CloudFront vs WAF geo match rule, documentar trade-offs.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la cadena DNS → TLS handshake → edge cache → origin fetch, y dónde cae cada responsabilidad entre Route 53, ACM, CloudFront y el origen. |
| Operativa | Escribir un `terraform plan` legible para CF+ACM+Route 53. Validar un JSON de distribución CloudFront con `jq`/esquema. Interpretar los registros de validación DNS que emite ACM. |
| Arquitectónica | Diseñar `cache behaviors` ordenados por especificidad para una mezcla estática+API. Decidir OAC vs origin público, signed URL vs signed cookie, CloudFront Functions vs Lambda@Edge. Dimensionar costo mensual (hosted zone, CloudFront requests, egreso). |

## Criterios de evaluación

- Justifica por qué un **cert ACM para CloudFront debe estar en us-east-1** y qué pasa si no.
- Diseña `cache behaviors` para una mezcla `/` estática + `/api/*` dinámica + `/private/*` firmada, con el ordering correcto.
- Enumera los **gotchas** de borrar una hosted zone (NS en la zona padre, delegación huérfana).
- Dado un escenario (sitio estático; sitio + API dinámica; descarga privada), elige entre OAC/signed URL/signed cookie y lo defiende.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Plantilla Terraform + JSON de distribución CloudFront validados estructuralmente (actividad 01).
- `ACM_DNS_WALKTHROUGH.md` describiendo el flujo de validación DNS (actividad 01).
- `CACHE_ORDER_ADR.md` justificando el orden de behaviors (actividad 01).
- `WAF_DESIGN.md` con 3 reglas WAF + decisión geo + trade-offs (actividad 02).

## Siguiente módulo

→ `aws-14-serverless-integration-essentials` — Lambda, API Gateway, EventBridge, SQS/SNS para integraciones y automatización.
