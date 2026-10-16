# sec-10 — Policy as Code: OPA, Rego y Conftest

## Identificación

- **ID:** `sec-10-policy-as-code-opa-rego-conftest`
- **Curso:** `devsecops`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-07` (supply chain / provenance). Se asumen nociones de IaC (Terraform) y manifests de Kubernetes.

## Objetivo

Interiorizar **Policy as Code**: por qué las políticas de seguridad y cumplimiento deben vivir en un **lenguaje ejecutable y testeable** en vez de en PDFs. Al terminar deberías poder escribir reglas **Rego**, ejecutarlas con **OPA** (`opa eval`, `opa test`) y con **Conftest** (sobre YAML / JSON / HCL), decidir cuándo cada una encaja, y mover un repo de "revisamos a ojo" a "la build falla si una política se incumple".

## Alcance

Este módulo cubre:

- **OPA** (Open Policy Agent): engine declarativo embebible; modos `eval`, `test`, `run` (server).
- **Rego**: sintaxis mínima suficiente — `package`, `import`, reglas `deny` / `allow` / `violation`, iteración con `some` / `every`, built-ins (`startswith`, `contains`, `regex.match`, `object.get`).
- **Conftest**: CLI que ejecuta Rego sobre **YAML**, **JSON** y **HCL** sin servidor; convención `deny[msg]` / `warn[msg]`.
- **Patrones de política**: deny-list, allow-list, severidad (`warn` vs `deny`), excepciones con TTL justificado.
- **Testing de policies** (`opa test`, `conftest verify`): fixtures `_test.rego`, aserciones sobre `data`.
- **Casos reales**: validar un manifest de Kubernetes (sin `runAsNonRoot`, con `latest` tag, sin resources), validar un **Terraform plan JSON** (bucket S3 público, SG `0.0.0.0/0`), validar un Dockerfile.

Lo que **no** cubre (se verá en `sec-11`):

- **Admission control** en Kubernetes (Kyverno, Gatekeeper, ValidatingAdmissionPolicy) — ejecución de policies en el momento de admisión del cluster.
- OPA como servidor HTTP consumido por otros servicios (`opa run`), más allá de mencionarlo.

Este módulo es **100% local**: no se levanta cluster, no se habla con cloud real. Toda la evaluación se hace con `opa` / `conftest` sobre fixtures JSON/YAML/HCL en disco. Los validadores **saltan con gracia** si `opa` o `conftest` no están instalados, de modo que la estructura del entregable se puede verificar incluso sin binarios.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — tres ejemplos ejecutables localmente:
  - `01-rego-first-rule/` — una política mínima en Rego evaluada con `opa eval` sobre un manifest K8s.
  - `02-conftest-on-terraform-plan/` — Conftest sobre un **Terraform plan JSON** sintético con 3 recursos (bucket S3, SG, instancia EC2).
  - `03-opa-test-suite/` — suite de tests Rego (`opa test`) con fixtures positivos y negativos.
- **`activities/`** — dos actividades **independientes**:
  - `01-write-no-public-s3-policy/` — escribir una política Rego "no public S3 bucket" y testearla con `opa test`.
  - `02-conftest-in-ci/` — organizar un paquete de policies Conftest y un script wrapper tipo CI que falla con `exit 1` si hay `deny`.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué una política escrita en Rego es más robusta que una checklist en Confluence. Diferenciar `warn` de `deny`. Diferenciar OPA (engine) de Conftest (CLI). |
| Operativa | Ejecutar `opa eval`, `opa test` y `conftest test` sobre fixtures locales. Escribir una regla `deny[msg]` con iteración `some` / `every`. |
| Arquitectónica | Decidir **dónde** poner una política: pre-commit, CI, admission. Diseñar un paquete Rego organizado por dominio (`k8s`, `terraform`, `docker`). |

## Criterios de evaluación

- Convierte una política escrita en prosa ("ningún bucket S3 público") en Rego verificable con tests.
- Explica por qué Conftest **no** reemplaza a OPA server, solo lo hace más accesible para IaC.
- Entrega las dos actividades con sus validadores estructurales en verde.
- Es capaz de añadir una excepción (`allow_list`) justificada con TTL y motivo.

## Entregables

- Política Rego "no public S3 bucket" con tests (`activities/01`).
- Paquete de policies Conftest + wrapper `run-conftest.sh` tipo CI (`activities/02`).

## Siguiente módulo

→ `sec-11-k8s-admission-kyverno-and-policy-controller` — llevar las policies al momento de admisión del cluster.
