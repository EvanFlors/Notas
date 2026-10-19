# gcp-04 — Compute Engine, Cloud Run y Cloud Functions

## Identificacion

- **ID:** `gcp-04-compute-engine-cloud-run-cloud-functions`
- **Curso:** `gcp`
- **Nivel:** intermedio
- **Duracion estimada:** 5 h
- **Prerrequisitos:** `gcp-01-model-projects-billing-and-cli`, `gcp-02-iam-bindings-deny-policies-and-service-accounts`, `gcp-03-vpc-global-and-networking`, curso AWS `aws-04`, `aws-10`, `aws-14`, curso docker.

## Objetivo

Elegir el compute correcto en GCP para un workload dado y, en particular, aprovechar **Cloud Run** como plano gestionado scale-to-zero que absorbe gran parte de lo que en AWS serian ECS/Fargate, App Runner y una porcion importante de Lambda. Al terminar deberias poder justificar — para tres workloads distintos — por que uno va a **Compute Engine (GCE)**, otro a **Cloud Run** y otro a **Cloud Functions gen 2**, y producir los artefactos Terraform + Docker necesarios para desplegarlos **sin tocar ningun proyecto GCP real**.

## Alcance

Este modulo cubre:

- **Compute Engine (GCE):** instance templates, Managed Instance Groups (MIGs), autoscaling, Spot/preemptible, Shielded VM, OS Login.
- **Cloud Run (fully managed, gen 2):** scale-to-zero, concurrencia por instancia, revisiones, traffic splitting, min-instances, modos de asignacion de CPU, Cloud Run jobs.
- **Cloud Functions gen 2:** son Cloud Run con triggers encima — mismo plano de datos; handler Python ejecutable localmente.
- **Mapeo desde AWS:** EC2 ↔ GCE; ECS/Fargate ↔ Cloud Run; Lambda ↔ Cloud Functions gen 2 o Cloud Run directo.
- **Fundamentos internos:** sandbox gVisor en Cloud Run, concurrencia por request, CPU "only during request" vs "always allocated" y su impacto en background work y cold starts.
- **Terraform + Docker en local:** `terraform plan`, `docker build` y `docker run` **locales**; nunca `terraform apply` ni `gcloud run deploy` reales.

Lo que **no** cubre (otros modulos):

- GKE y Autopilot → `gcp-07`.
- Observabilidad de Cloud Run (SLOs, OTel) → `gcp-08`.
- Pipelines con Workload Identity Federation sin keys → `gcp-10`.
- Datos (Cloud SQL, Firestore, etc.) → `gcp-05`.

Este modulo es **artefactos locales**. **No** se provisiona nada en un proyecto GCP real; **no** hay costo. El unico tooling son `bash`, `jq`, `terraform` (>= 1.3), `docker` y `python3`.

## Materiales

- **`theory/lesson.md`** — leccion profunda sobre los tres planos de compute y su eleccion razonada.
- **`examples/`** — ejemplos de lectura (y, cuando aplica, de `docker build` local):
  - `01-fastapi-on-cloud-run/` — FastAPI empaquetada en Dockerfile + Terraform `google_cloud_run_v2_service`. Imagen construible y ejecutable localmente con `docker run`.
  - `02-cloud-run-traffic-splitting-canary/` — una service con 2 revisiones y `traffic { percent = 95|5 }` para canary.
  - `03-cloud-run-jobs/` — `google_cloud_run_v2_job` para batch de corta duracion (vs. service HTTP).
  - `04-cloud-functions-gen2-python/` — handler Python de Cloud Functions gen 2 que ademas corre como funcion local via `functions-framework` sin necesidad de desplegar.
- **`activities/`** — dos actividades **independientes**:
  - `01-deploy-same-app-run-and-gce-compare/` — misma app FastAPI, dos despliegues en Terraform (Cloud Run v2 y un GCE instance template + MIG) + ADR corto comparandolos.
  - `02-canary-5pct-rollout/` — producir el Terraform de un canary 95/5 en Cloud Run con dos revisiones nombradas y un `README-INTENT.md` justificando la estrategia de rollback.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar por que Cloud Run gen 2 y Cloud Functions gen 2 son el mismo plano; cuando CPU "always allocated" paga la pena; que gana `target_type=ip` en ALB vs lo que gana Cloud Run al no tener que elegirlo. |
| Operativa (local) | Construir una imagen Docker, correrla local y escribir Terraform de Cloud Run + GCE sin aplicar nada. |
| Arquitectonica | Elegir — con criterio escrito — Cloud Run vs GKE vs GCE para 3 workloads concretos; disenar un canary 95/5 con rollback de un comando. |

## Criterios de evaluacion

- Dado un workload, elige Cloud Run / GCE / Functions y defiende la eleccion en 3 lineas.
- Lee un `google_cloud_run_v2_service` con dos bloques `traffic` y explica el reparto resultante.
- Construye la imagen de `examples/01-fastapi-on-cloud-run` y la corre con `docker run -p 8080:8080 ...` **sin tocar GCP**.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Artefactos de la actividad `01`: `Dockerfile`, `main.py`, `requirements.txt`, `cloud-run.tf`, `gce.tf` y `DECISION.md`.
- Artefactos de la actividad `02`: `cloud-run.tf` con dos revisiones + `traffic` 95/5 y `README-INTENT.md` con la estrategia de rollback.

## Costos

**Ninguno.** Todo el modulo se desarrolla localmente. **No se requiere proyecto GCP activo ni Billing Account enlazada.** Si en una fase posterior desplegaras realmente los artefactos:

- **Cloud Run:** scale-to-zero → coste cercano a cero cuando no hay trafico; se paga por vCPU-s y memoria-s por request.
- **Cloud Functions gen 2:** mismo modelo (es Cloud Run por debajo).
- **GCE:** se paga por hora de la VM corra o no haya trafico; usar Spot/preemptible y schedules para bajar costo.
- **Egress de red:** gratuito dentro de la misma region hacia servicios Google; con cuidado para egress a Internet.

## Siguiente modulo

→ `gcp-05-data-cloud-sql-firestore-bigtable-spanner` — como conectar la app desde Cloud Run a bases de datos administradas con IAM y Auth Proxy.
