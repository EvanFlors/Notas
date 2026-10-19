# gcp-10 — DevSecOps y FinOps en GCP: WIF, Binary Authorization, Artifact Registry y unit economics

## Identificación

- **ID:** `gcp-10-devsecops-platform-wif-binauthz-finops`
- **Curso:** `gcp`
- **Nivel:** producción (capstone)
- **Duración estimada:** 6 h
- **Prerrequisitos:** `gcp-02` (IAM, service accounts, impersonation), `gcp-07` (GKE Autopilot y Workload Identity), `gcp-09` (org / folders / cloud identity), cursos **github-actions** y **docker** nivel 4.

## Objetivo

Aterrizar en GCP los controles DevSecOps y FinOps del programa: pipelines CI/CD sin keys estáticas (Workload Identity Federation), publicación de imágenes firmadas a Artifact Registry, admisión por firma en GKE Autopilot con Binary Authorization, y análisis de **unit economics** a partir del export de Billing a BigQuery. El módulo es un **capstone** del track GCP: integra todo lo visto (IAM, GKE, org) en un pipeline end-to-end verificable sin provisionar nada caro.

## Alcance

Este módulo cubre:

- **Workload Identity Federation (WIF)**: pool, provider OIDC desde GitHub Actions, attribute mapping (`google.subject`, `attribute.repository`, `attribute.ref`), `attribute.condition` para pinnear a un repo/ref concreto, binding `roles/iam.workloadIdentityUser` a un service account GCP, impersonation.
- **Artifact Registry**: repositorios Docker/Python/Maven, cleanup policies, **vulnerability scanning** nativo (Container Analysis).
- **Binary Authorization**: policy YAML (`defaultAdmissionRule`, `clusterAdmissionRules`, `admissionWhitelistPatterns`), **attestors** y **notes** de Container Analysis, integración con **Sigstore cosign** (attestor con `pkixPublicKey` o KMS-backed), modos `ENFORCED_BLOCK_AND_AUDIT_LOG` vs `DRYRUN_AUDIT_LOG_ONLY`.
- **Security Command Center (SCC)**: Standard vs Premium vs Enterprise; hallazgos relevantes para una org pequeña (keys estáticas detectadas, SA con roles excesivos).
- **FinOps**: labels obligatorios en recursos, **export de Billing a BigQuery**, dashboards por project/label/sku, **CUDs vs SUDs**, **Recommender** (rightsizing), **unit economics** (coste por request, coste por customer activo) a partir de un CSV sintético que simula el export de Billing.

Lo que **no** cubre:

- Montar la org desde cero (lo cubre `gcp-09`).
- Operar GKE a nivel red/CNI (lo cubre `gcp-07`).
- Code scanning / SAST en el pipeline (eso vive en el track **devsecops** del programa; aquí asumimos que GHA ya corre SAST en pasos previos).

Este módulo es **mayoritariamente TF plan + ADR + validación estructural de YAML/Python**. **No** se provisiona nada en una org GCP real; **no se incurre en coste GCP**. El único tooling es `bash`, `jq`, `python3`, `yq` (opcional) y `terraform` (solo `fmt`/`validate`, nunca `apply`).

## Materiales

- **`theory/lesson.md`** — lección profunda del capstone (WIF, Binauthz, FinOps y SCC).
- **`examples/`**:
  - `01-wif-github-to-gcp/` — anatomía de un workflow GHA que impersona un SA GCP vía WIF (sin keys).
  - `02-cosign-and-binary-authorization/` — flujo `cosign sign` → attestor → policy GKE.
  - `03-billing-export-dashboard/` — qué contiene el export de Billing en BigQuery y queries base.
- **`activities/`** (tres actividades, cada una **independiente**):
  - `01-wif-pipeline-no-keys-adr/` — diseñar y escribir el pipeline WIF (TF plan + GHA workflow YAML + ADR).
  - `02-enforce-binauthz-on-gke-autopilot/` — escribir la policy Binauthz + attestor YAML + ADR del rollout.
  - `03-finops-unit-economics/` — calcular coste por request y por customer activo sobre un CSV sintético que imita el export de Billing.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué WIF elimina keys estáticas; cómo Binauthz usa attestations (y el papel de cosign); qué habilita el export de Billing a BigQuery. |
| Operativa (sin infra) | Escribir TF para pool + provider + binding WIF; escribir GHA que impersona un SA; escribir policy Binauthz con whitelist + attestor; parsear export de Billing con Python. |
| Arquitectónica | Decidir modo `ENFORCED` vs `DRYRUN` para rollout de Binauthz; justificar el `attribute.condition` que pinnea el provider al repo+ref; definir KPIs de unit economics (coste por request, por customer activo). |

## Criterios de evaluación

- Dado un ADR WIF, identifica si el provider está pinneado correctamente (si no, un fork malicioso podría impersonar).
- Lee una policy Binauthz y explica qué pasa con una imagen sin attestation en modo `ENFORCED` vs `DRYRUN`.
- Enumera 3 attestors típicos (build, vulnerability-scan, qa-signoff) y qué firma cada uno.
- Explica por qué el export de Billing a BigQuery es superior a mirar la UI de billing para unit economics.
- Entrega las 3 actividades con sus validadores en verde.

## Entregables

- Actividad 01: `terraform/wif.tf`, `.github/workflows/publish.yml`, `ADR-WIF-PIPELINE.md`.
- Actividad 02: `binauthz-policy.yaml`, `attestor.yaml`, `terraform/binauthz.tf`, `ADR-BINAUTHZ-ROLLOUT.md`.
- Actividad 03: `cost_per_request.py`, `cost_per_customer.py`, `REFERENCE-UNIT-ECONOMICS.md`.

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, YAML, TF (nunca `apply`) y Python contra un CSV sintético. **No se requiere project GCP activo.** Los IDs usados son placeholders ficticios (`my-project-123`, `my-org-id`). Si en una fase posterior aplicas lo diseñado:

- **WIF**: gratis (es parte de IAM).
- **Artifact Registry**: ~0,10 USD/GB-mes almacenamiento + egress.
- **Binary Authorization**: gratis el servicio; Container Analysis vulnerability scanning tiene coste por imagen escaneada (~0,26 USD/imagen).
- **Billing export a BigQuery**: el export es gratis; querys consumen slot de BigQuery (gratis bajo 1 TiB/mes).
- **GKE Autopilot**: pricing per-pod (fuera de scope aquí).

## Siguiente paso

Este módulo cierra el track GCP del programa. El siguiente paso es el **capstone cross-cloud** (track `projects/`): el mismo workload desplegado y gobernado en AWS y GCP, con un ADR comparativo.
