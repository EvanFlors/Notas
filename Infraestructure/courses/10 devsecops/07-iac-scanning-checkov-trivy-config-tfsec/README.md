# sec-07 — IaC scanning (Checkov, Trivy config, tfsec)

## Identificación

- **ID:** `sec-07-iac-scanning-checkov-trivy-config-tfsec`
- **Curso:** `devsecops`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-03`, curso **terraform** (al menos hasta `tf-04`).

## Objetivo

Detectar **misconfigs** en Terraform/Kubernetes/Dockerfile **antes** de aplicar. Al terminar deberías poder: elegir entre **Checkov**, **Trivy config** y **tfsec** con criterio; escanear tanto **HCL crudo** como un **plan JSON**; escribir una **policy custom** (Python para Checkov); y entender por qué el plan es más preciso que el HCL para IaC scanning.

## Alcance

- **Checkov**: scanner multi-formato (TF, CloudFormation, K8s, Dockerfile, ARM, Helm, Serverless). Políticas built-in + custom en **Python** o **Rego**.
- **Trivy config**: comando `trivy config` — muy rápido, solapa parcialmente con Checkov. Usa la misma base de reglas que **tfsec** (fusionado con Trivy; tfsec está en modo mantenimiento).
- **tfsec**: aún útil como CLI directo si no quieres el resto de Trivy; pero el camino oficial es Trivy.
- **Otras alternativas** (menciones): **Terrascan**, **KICS**.
- **HCL vs plan JSON**: por qué `terraform show -json tfplan` da señal **mucho más precisa** (resuelve variables, data sources, locals) y detecta regresiones por cambios en data sources.
- **Mapping a benchmarks**: CIS, PCI-DSS, HIPAA — cómo Checkov lo etiqueta y cómo filtrar.
- **Policies custom**:
  - **Python** (Checkov) — rápido para reglas simples.
  - **Rego** (OPA) — vía Checkov `--external-checks-dir` o directamente con `conftest` (se profundiza en `sec-10`).
- **Integración CI**: fallar en severidad, excepciones con **`skip-check`** / `.checkov.yaml` + justificación + expiración, output SARIF a GitHub Code Scanning.

Lo que **no** cubre (se verá después):

- Rego con OPA/Conftest en profundidad → `sec-10`.
- Admisión en el cluster (Kyverno, policy-controller) → `sec-11`.
- Firmas y attestations (cosign) → `sec-09`.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`**:
  - `01-checkov-tf-folder/` — recorrido de `checkov -d .` sobre una carpeta Terraform con misconfigs clásicos (S3 público, IAM `*`, SG abierto).
  - `02-trivy-config-k8s-manifests/` — `trivy config` sobre manifests K8s con `runAsRoot`, `privileged: true`, sin `resources`.
  - `03-checkov-on-plan-json/` — por qué escanear el plan es más preciso que el HCL (variables + data sources resueltos).
- **`activities/`**:
  - `01-add-iac-scan-to-tf-pipeline/` — **guided-lab**: construir un `scan.sh` que corra Checkov sobre HCL + plan JSON y Trivy config sobre K8s. Produce un `REPORT.md`.
  - `02-custom-checkov-policy/` — **independent**: escribir una policy custom en Python que detecte un patrón organizacional (p. ej. "todo bucket S3 debe tener tag `data_classification`").
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué escanear el **plan** es más preciso que escanear HCL. Distinguir Checkov vs Trivy config vs tfsec vs Terrascan vs KICS. |
| Operativa | Ejecutar Checkov + Trivy config en CI con política de severidad y excepciones justificadas. Interpretar y suprimir findings con `skip-check` + razón + expiración. |
| Arquitectónica | Diseñar la política mínima de IaC para una organización pequeña (qué reglas obligatorias, cuáles warn, qué benchmark base). |

## Criterios de evaluación

- Ejecuta Checkov sobre una carpeta Terraform y clasifica los findings (fix / suprimir con razón / FP).
- Ejecuta Trivy config sobre manifests K8s y explica los hallazgos.
- Escanea un **plan JSON** y detecta al menos una regresión que el HCL puro no vería (p. ej. una variable con default inseguro).
- Escribe una policy custom en Python que se dispare contra un fixture controlado.
- Las dos actividades pasan sus validadores estructurales.

## Entregables

- Un `REPORT.md` producido por el script del lab (actividad 01).
- Una policy Checkov custom (actividad 02) + fixture bueno y malo.

## Siguiente módulo

→ `sec-08-sbom-and-slsa-in-practice` — SBOM (CycloneDX/SPDX) y SLSA en práctica.
