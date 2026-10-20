# sec-11 — Admission control en Kubernetes: Kyverno y policy-controller

## Identificación

- **ID:** `sec-11-k8s-admission-kyverno-and-policy-controller`
- **Curso:** `devsecops`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `sec-09` (cosign/sigstore), `sec-10` (OPA/Rego/Conftest), curso **kubernetes** ≥ `k8s-12`.

## Objetivo

Aplicar políticas en el **punto de admisión** del cluster: decidir, *antes* de que un recurso se persista en etcd, si cumple las reglas (firma de imágenes, labels obligatorios, PSA restricted, resources, tags, hostPath, etc.). Al terminar deberías poder (a) escribir y testear policies Kyverno — tanto `validate` como `verifyImages` — (b) elegir entre **Kyverno**, **OPA/Gatekeeper**, **sigstore policy-controller** y **ValidatingAdmissionPolicy (VAP)** con criterio, y (c) diseñar un **workflow de excepciones** con TTL y approver.

## Alcance

Este módulo cubre:

- **Admission controllers** en K8s: mutating vs validating, webhooks externos vs policy nativo in-tree.
- **Kyverno**: CRs `ClusterPolicy` / `Policy`, modos `validate` / `mutate` / `generate` / `verifyImages`, PolicyException, audit vs enforce, `kyverno-cli` (`kyverno test`, `kyverno apply`) para testing *offline* (sin cluster).
- **OPA/Gatekeeper**: `ConstraintTemplate` + `Constraint`, Rego-first, cuándo elegirlo.
- **sigstore policy-controller**: `ClusterImagePolicy`, verificación de firma cosign keyless en admisión.
- **ValidatingAdmissionPolicy (VAP)**: CEL nativo en el API server, sin webhook externo (GA en 1.30).
- Patrones típicos: require signed images, PSA restricted, require labels, require resources, forbid `latest`, forbid hostPath.
- Workflow de **excepciones**: `PolicyException`, labels de bypass con TTL, approver, auditoría.
- Impacto en **performance**: timeouts, `failurePolicy`, `matchConditions`, exclusión de namespaces del plano de control.

Lo que **no** cubre:

- Runtime security (Falco / Tetragon) → `sec-12`.
- Secret management en cluster (Vault / ESO) → `sec-13`.
- Capstone end-to-end y plataforma → `sec-14`.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`** — tres ejemplos narrados (lectura; algunos ejecutables si tienes `kind` + `kyverno-cli`):
  - `01-kyverno-verify-images/` — `ClusterPolicy` con `verifyImages` cosign keyless; `kyverno apply` *offline* sobre un manifest de prueba.
  - `02-gatekeeper-constraint/` — `ConstraintTemplate` + `Constraint` Rego-first que exige labels obligatorios.
  - `03-vap-cel-example/` — `ValidatingAdmissionPolicy` + `ValidatingAdmissionPolicyBinding` CEL que prohíbe el tag `:latest`.
- **`activities/`** — dos actividades **independientes**:
  - `01-admission-policy-set-for-capstone/` — construir un *set* de 3 policies Kyverno (PSA, require-labels, disallow-latest) + manifests buenos/malos y validarlos con `kyverno apply` *offline*.
  - `02-exception-workflow/` — diseñar y documentar un workflow de excepciones (`PolicyException` + ADR) con TTL, approver y auditoría.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre validating y mutating webhooks; distinguir Kyverno / Gatekeeper / policy-controller / VAP por caso de uso. |
| Operativa | Escribir una `ClusterPolicy` de Kyverno y testearla *offline* con `kyverno apply` sin cluster. Si hay `kind`, desplegarla y verificar que un recurso malo es rechazado. |
| Arquitectónica | Diseñar el conjunto mínimo de policies de admisión para una plataforma y un proceso de excepción con TTL + approver que no se convierta en "regla implícita". |

## Criterios de evaluación

- Justifica Kyverno vs OPA vs VAP para un escenario dado.
- Produce `ClusterPolicy` válidas y manifests que las violan / cumplen.
- Diseña el workflow de excepción (quién pide, quién aprueba, cuándo expira, cómo se audita).
- Ambas actividades pasan sus validadores estructurales.

## Entregables

- Set de policies Kyverno del capstone (actividad `01`).
- ADR + plantilla `PolicyException` del workflow de excepciones (actividad `02`).

## Siguiente módulo

→ `sec-12-runtime-security-falco-and-tetragon` — qué pasa *después* de la admisión: detectar comportamiento sospechoso en runtime.
