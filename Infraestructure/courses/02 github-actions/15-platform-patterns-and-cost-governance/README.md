# gha-15 — Platform patterns y gobierno de costo

## Identificación

- **ID:** `gha-15-platform-patterns-and-cost-governance`
- **Curso:** `github-actions`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `gha-08` (reusables), `gha-09` (environments/approvals), `gha-13` (hardening).

## Objetivo

Operar GitHub Actions **como plataforma a escala de organización**: definir el "platform contract" (qué checks son obligatorios, qué reusables son golden path, qué políticas de concurrencia aplican), presupuestar el costo (minutos, storage, larger runners), medir el pipeline (p50/p95, tasa de éxito) y responder preguntas de disaster-recovery.

Al terminar deberías poder **defender** por qué tu org exige un reusable workflow concreto, cuánto cuesta tu CI/CD por mes y qué métrica dispararía una revisión del contrato.

## Alcance

Este módulo cubre:

- **Required workflows via rulesets** a nivel org/enterprise (sucesor de las "required workflows" classic y de la *branch protection* clásica).
- **Starter workflows vs. reusable workflows** como estrategia golden-path y cómo versionarlos (`v1` que apunta al último SHA de la major; patrón mutable-major, immutable-SHA).
- **Concurrency policies** a nivel org para evitar deploys solapados o runs duplicados.
- **Billing**: unidad base = **runner-minute** con multiplicadores por SO (Linux ×1, Windows ×2, macOS ×10) y por tier de larger runners; GHCR storage; Actions cache storage (**límite 10 GB/repo**); artefactos.
- **Métricas del pipeline**: lead time, duración p50/p95 por workflow, tasa de éxito, flakiness.
- **Observabilidad**: webhook `workflow_run`/`workflow_job` → sink (Datadog, Grafana, BigQuery) y uso de la REST API `/repos/{o}/{r}/actions/runs`.
- **Self-hosted vs. hosted** desde la óptica de **costo total de propiedad** (TCO), no solo tarifa.
- **Disaster recovery**: qué pasa cuando GitHub está caído (y qué puedes hacer *antes* para que la caída no te mate).

Lo que **no** cubre (se vio o se verá):
- Hardening de seguridad (`gha-13`).
- Supply chain / attestations (`gha-14`).
- ARC detallado (`gha-10`).

## Materiales

- **`theory/lesson.md`** — lección de 12 secciones.
- **`examples/`**:
  - `01-required-reusable-workflow-via-ruleset/` — ruleset JSON de org que exige un reusable workflow concreto como check obligatorio en `main`.
  - `02-cost-dashboard-metrics/` — script Python que consume la REST API de Actions y calcula duración p50/p95, tasa de éxito y runner-minutes por workflow.
- **`activities/`**:
  - `01-define-org-level-ci-contract/` — independiente, tipo *architecture*: produces un ADR + reusable template + ruleset JSON ("platform contract") para una org dada.
  - `02-cost-exercise/` — guided-lab: calcular factura mensual de una org a partir de un perfil de uso dado.
- **`resources/links.md`** — enlaces a documentación oficial (rulesets, billing, API de Actions, SLO/SLI).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar required workflows (ruleset) de branch protection classic. Explicar por qué un reusable `v1` debe apuntar a SHA inmutable. Describir el multiplicador de minutos por SO. |
| Operativa | Escribir un ruleset JSON que exige un workflow concreto. Extraer p50/p95 por workflow desde la API. Calcular una factura mensual plausible. |
| Arquitectónica | Diseñar el platform contract de una org: qué es *obligatorio*, qué es *recomendado*, qué métricas y SLOs lo gobiernan, y cuáles son los *review triggers* para cambiarlo. |

## Criterios de evaluación

- Entregas los 3 artefactos de Activity 01 (ADR, reusable template, ruleset JSON) con las secciones mínimas requeridas por el validador.
- El validador estructural de Activity 01 pasa; la revisión semántica (defensa oral) es manual contra `solution/ADR-reference.md`.
- Entregas `cost-estimate.yaml` de Activity 02 que el validador reproduce dentro de ±5% con la fórmula oficial.
- Puedes responder las preguntas de evaluación de `theory/lesson.md` sin consultar.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-required-reusable-workflow-via-ruleset/` (lee el JSON, aplícalo mentalmente con `gh api`).
3. Reproduce `examples/02-cost-dashboard-metrics/` sobre un repo propio.
4. Haz `activities/02-cost-exercise/` (es *mecánica*, calienta para la 01).
5. Haz `activities/01-define-org-level-ci-contract/` (es *arquitectura*; donde se evalúa).
6. Prepara la defensa oral: ¿developer experience vs. seguridad vs. costo? ¿Qué cederías primero?

## Siguiente

Fin del curso **github-actions**. Lo que sigue en el programa es el curso **Docker** (D6) y luego **Terraform/AWS** (D7), donde el pipeline que diseñaste aquí ejecuta releases reales.
