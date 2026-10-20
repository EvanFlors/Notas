# ADR 0006 — Elección de cloud para la etapa 6 del capstone

> *Architecture Decision Record* ligera. El cloud elegido se vuelve el **default demo** del capstone de aquí en adelante. Cambiarlo más tarde es posible pero caro: implica reescribir módulos y re-provisionar.

Estado: **accepted** (default del capstone; cambiar a `superseded` si el equipo elige otro cloud en la actividad `cap-06-01-choose-cloud-adr`).

Fecha: 2026-10-20.

Autores: Capstone maintainers.

---

## Contexto

Al cierre de la etapa 5 tenemos una imagen firmada publicada en un registro accesible y toda la infraestructura previa es local (Docker Compose, GitHub Actions). La etapa 6 introduce IaC con Terraform para describir los *cimientos* de la nube — backend remoto del state, red mínima y registro de contenedores — y la etapa 7 va a desplegar la app sobre un servicio administrado de contenedores (ECS/Fargate, Cloud Run o Container Apps).

Necesitamos elegir **un cloud default** para que las etapas 7-14 tengan un camino *reproducible*. Los otros dos clouds quedan como módulos *paralelos* para quien quiera clonar el ejercicio.

## Opciones consideradas

### A. AWS (ECR + VPC + S3/DynamoDB backend + ECS/Fargate luego)

**Pros**
- Mercado laboral: la mayoría del material y de las ofertas en LATAM asumen AWS.
- OIDC con GitHub Actions es *stock* y bien documentado (`aws-actions/configure-aws-credentials`).
- LocalStack permite ejercitar S3 + DynamoDB sin cuenta real.
- ECS/Fargate (etapa 7) es el servicio managed más común para contenedores en AWS sin K8s.

**Contras**
- NAT Gateway es caro (~$32/mes) — único vector real de costo del lab.
- IAM tiene curva más pronunciada que GCP/Azure.

### B. GCP (Artifact Registry + VPC + GCS backend + Cloud Run luego)

**Pros**
- Cloud Run (etapa 7) es *serverless* real: baja a cero, muy barato de laboratorio.
- Workload Identity Federation es excelente; OIDC con GitHub Actions es nativo.
- VPC más simple que AWS.

**Contras**
- Menos presencia en empresas LATAM que AWS.
- Egress de Container Registry un poco más caro que ECR en regiones chicas.

### C. Azure (ACR + VNet + Blob Storage backend + Container Apps luego)

**Pros**
- Container Apps es managed sobre KEDA — buen puente conceptual a la etapa 8 (Kubernetes).
- Integración fuerte con Entra ID / Microsoft 365 para empresas corporativas.

**Contras**
- CLI/providers menos "limpios" (más campos obligatorios, nombres largos).
- Comunidad / docs más dispersa que AWS/GCP para labs educativos.

## Criterios de decisión

| criterio                                  | peso | AWS | GCP | Azure |
|-------------------------------------------|------|-----|-----|-------|
| Costo del lab (NAT, egress, registry)     | 2    | 2   | 3   | 2     |
| Documentación / comunidad educativa       | 3    | 3   | 2   | 2     |
| Familiaridad previa del equipo            | 2    | 3   | 2   | 2     |
| Servicio runtime en etapa 7               | 2    | 2   | 3   | 2     |
| OIDC con GitHub Actions                   | 1    | 3   | 3   | 2     |
| **Score (suma ponderada)**                |      | **22** | **21** | **18** |

> Cada equipo del programa **debe recalcular esta tabla con sus propios pesos** en la actividad `cap-06-01-choose-cloud-adr`. La tabla de arriba es el *starter*.

## Decisión

Default demo del capstone: **AWS**.

Razones principales:

1. Mayor familiaridad general del equipo con IAM/VPC/ECR/ECS.
2. Documentación más densa para labs educativos.
3. OIDC bien bruñido, mínimo riesgo en la etapa 7.

GCP y Azure quedan como *módulos paralelos* bajo `terraform/gcp/` y `terraform/azure/` — se validan sintácticamente en CI pero no se aplican en el flujo principal.

## Consecuencias

- Las etapas 7-14 asumen AWS (ECS/Fargate → EKS → etc.). Si en el futuro el default cambia, hay que reescribir el runtime de la etapa 7.
- El cliente de CI debe asumir OIDC con AWS (`aws-actions/configure-aws-credentials@vN`).
- El `backend "s3" {}` queda *parcial* en todos los stacks; se completa con `-backend-config` para no comitear nombres de bucket reales.
- Se asume región default `us-east-1` para costos y disponibilidad de servicios.

## OIDC — resumen por cloud

| cloud | provider recurso                                        | action en CI                                     |
|-------|---------------------------------------------------------|--------------------------------------------------|
| AWS   | `aws_iam_openid_connect_provider` + `aws_iam_role`      | `aws-actions/configure-aws-credentials@vN`       |
| GCP   | `google_iam_workload_identity_pool` + `_provider`       | `google-github-actions/auth@vN`                  |
| Azure | *federated credential* en `azuread_application`         | `azure/login@vN` (`client-id` + `tenant-id`)     |

Ninguna de las tres opciones usa claves largas comiteadas o guardadas en secrets.

## Rollback

Si tras aplicar en AWS detectamos un bloqueador (p. ej. presupuesto excedido), el plan es:

1. `terraform destroy` en `terraform/aws/`.
2. Repetir el ejercicio en `terraform/gcp/` (ya validado sintácticamente).
3. Reabrir esta ADR como `superseded`.

No hay dato persistente perdido porque hasta la etapa 7 no hay base de datos cloud.
