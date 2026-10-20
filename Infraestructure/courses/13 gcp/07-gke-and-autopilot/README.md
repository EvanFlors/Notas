# gcp-07 — GKE Standard, Autopilot y Workload Identity

## Identificación

- **ID:** `gcp-07-gke-and-autopilot`
- **Curso:** `gcp`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `gcp-02` (IAM), `gcp-03` (VPC global), `gcp-04` (Compute/Run), curso **kubernetes** Nivel 1–2, `aws-11` (EKS) para contraste.

## Objetivo

Operar **GKE Standard** y **GKE Autopilot** con criterio, dar IAM a workloads vía **Workload Identity Federation for GKE** (sin service account keys), y poder justificar por escrito la elección GKE Autopilot vs Standard vs EKS para una organización dada.

## Alcance

Este módulo cubre:

- **GKE Standard**: control plane managed, node pools, release channels (Rapid/Regular/Stable), auto-upgrade, auto-repair.
- **GKE Autopilot**: sin node management, pricing per-pod, restricciones de seguridad por default (sin `hostNetwork`, sin `hostPath`, sin privilegios root arbitrarios).
- **Workload Identity Federation for GKE**: equivalente de IRSA en AWS, pero con menos piezas. Un K8s ServiceAccount anotado se mapea a un Service Account de GCP; el pod obtiene credenciales federadas por el GKE metadata server.
- **GKE Ingress** y **Gateway API** con Google Cloud Load Balancers (managed certs, global HTTP(S) LB).
- Diferencia operativa vs **EKS**: menos pegamento (no instalas CNI de VPC ni AWS Load Balancer Controller como add-ons separados).
- **Release channels** como mecanismo de upgrade continuo (vs upgrade manual explícito en EKS).

Lo que **no** cubre (se verá después):

- Admisión por firma de imágenes y pipeline sin keys (**Binary Authorization**, **WIF desde GitHub Actions**) → `gcp-10`.
- Observabilidad GKE → **Cloud Logging/Monitoring** nativos y OTel → `gcp-08`.
- Jerarquía Org/Folders y bindings de grupo → `gcp-09`.

Este módulo es **mayoritariamente diseño + Terraform estático + manifiestos K8s locales**. **No se provisiona nada en un project GCP real**, no se genera coste. La validación de manifiestos K8s se hace con **kind** (opcional) o con `kubectl --dry-run=client` sobre YAML estáticos. La validación de Terraform usa `terraform validate` sin backend remoto.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-gke-autopilot-vs-standard/` — tabla comparativa anotada: pricing, control, restricciones, operaciones.
  - `02-workload-identity-walkthrough/` — recorrido conceptual de WIF for GKE: pool/provider, binding `roles/iam.workloadIdentityUser`, anotación en el K8s SA, flujo de obtención de token.
  - `03-gke-ingress-and-gateway/` — Ingress clásico vs Gateway API con `GatewayClass` de Google, managed certificates y FrontendConfig.
- **`activities/`** — dos actividades **independientes**:
  - `01-gke-standard-vs-autopilot-tf-plan-and-adr/` — escribir Terraform para dos clusters (Standard y Autopilot) y un **ADR** justificando la elección para dos workloads.
  - `02-workload-identity-federation-walkthrough/` — producir el **manifiesto K8s** anotado, el **script `gcloud`** del binding (sin ejecutar contra GCP), y un **ADR comparando IRSA vs Workload Identity**.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una frase cuándo Autopilot gana a Standard y cuándo no; por qué WIF for GKE es más ergonómico que IRSA; qué garantiza un release channel. |
| Operativa (sin infra) | Escribir Terraform `google_container_cluster` para Standard y para Autopilot; anotar un K8s ServiceAccount para WIF; escribir el comando `gcloud iam service-accounts add-iam-policy-binding` que concede `roles/iam.workloadIdentityUser`. |
| Arquitectónica | Elegir Standard vs Autopilot vs EKS para una org dada; identificar qué cargas **no** encajan en Autopilot y por qué. |

## Criterios de evaluación

- Dado un workload (p. ej. un StatefulSet con `hostPath`), identifica si cabe en Autopilot y explica por qué sí o no.
- Lee un manifiesto K8s con `iam.gke.io/gcp-service-account` y predice qué permisos efectivos tendrá el pod.
- Nombra 3 restricciones de Autopilot que **no** aplican en Standard.
- Justifica el *release channel* elegido (Rapid/Regular/Stable) para dev vs prod.
- Entrega las dos actividades con sus validadores en verde.

## Entregables

- `main.tf` para GKE **Standard** (`standard/`) y GKE **Autopilot** (`autopilot/`), más `ADR-GKE-MODE.md` (sale de la actividad `01`).
- `k8s/serviceaccount-and-deployment.yaml`, `scripts/provision-wif.sh` y `WORKLOAD-IDENTITY-ADR.md` (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, Terraform (sin `apply`) y, opcionalmente, un cluster **kind** local. No se requiere project GCP activo. Si en una fase posterior decides provisionar lo diseñado:

- **GKE Standard**: control plane 0,10 USD/hora/cluster desde el segundo cluster por región + coste de nodes (`e2-medium` ≈ 25 USD/mes).
- **GKE Autopilot**: facturado por **pod/segundo** con sobrecargo de ~15 % sobre el precio de los recursos requested; sin coste de nodes "idle".
- **Workload Identity Federation for GKE**: gratis.
- **GKE Ingress + Managed Cert**: coste del Load Balancer global (~18 USD/mes mínimo) + egress.

## Siguiente módulo

→ `gcp-08-observability-cloud-ops-audit-logs` — instrumentar la app con OpenTelemetry hacia Cloud Operations y auditar con Audit Logs.
