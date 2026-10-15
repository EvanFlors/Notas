# gha-10 — Self-hosted runners y ARC

## Identificación

- **ID:** `gha-10-self-hosted-runners-and-arc`
- **Curso:** `github-actions`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `gha-01-model-and-first-workflow`, `gha-05-secrets-variables-and-environments-basics`, nociones básicas de Kubernetes (puede ir después del nivel 1 de D8).

## Objetivo

**Operar runners propios y escalarlos en Kubernetes.** Al terminar deberías poder registrar manualmente un runner self-hosted, levantar **ARC** (Actions Runner Controller) en un cluster local (`kind`/`k3d`), razonar los riesgos de seguridad del modelo self-hosted y decidir con criterio **hosted vs self-hosted vs ARC** para un caso dado.

## Alcance

- **Runners self-hosted**: registro manual, labels, runner groups, actualización, logs.
- **Modelo de ejecución**: long-polling runner → GitHub, por qué los runners deben ser **efímeros**.
- **Seguridad**: regla dura **"no self-hosted en repos públicos sin aislamiento"**; contaminación entre jobs; escapes del workspace; fork PRs y approvals.
- **ARC** (`actions/actions-runner-controller`, oficial de GitHub): arquitectura basada en GitHub App, CRDs `AutoscalingRunnerSet` y `AutoscalingListener`, scale-from-zero, ephemeral runners en pods.
- **Comparativa**: hosted (incluye larger runners), self-hosted VMs, ARC en K8s.
- **Trade-offs**: coste, operación, seguridad, latencia de arranque, imagen base.

Lo que **no** cubre:
- OIDC a cloud providers → `gha-11`.
- Hardening general del workflow → `gha-13`.
- Operación productiva de K8s (networking, HPA avanzado, storage) → cursos específicos.

## Materiales

- **`theory/lesson.md`** — lección en 12 secciones.
- **`examples/`**:
  - `01-register-self-hosted-runner/` — walkthrough del registro manual (comandos y qué pasa debajo).
  - `02-arc-in-kind/` — instalación mínima reproducible de ARC en `kind`.
- **`activities/`**:
  - `01-run-job-on-self-hosted/` — **guided-lab**: ejecutar un job real contra un runner self-hosted local.
  - `02-arc-minimal-install/` — **mini-project independiente**: levantar ARC en `kind` + CR mínimo validado + ADR de trade-offs.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar el long-polling del runner. Argumentar por qué los runners **deben ser efímeros**. Diferenciar hosted / self-hosted / larger / ARC. Enumerar los riesgos específicos de usar self-hosted en repos públicos. |
| Operativa | Registrar un runner con labels; usarlo desde un workflow con `runs-on: [self-hosted, <label>]`. Instalar el chart de ARC en `kind` con credenciales dummy; verificar CRDs y crear un `AutoscalingRunnerSet` válido. Diagnosticar un pod runner que no arranca. |
| Arquitectónica | Decidir hosted vs self-hosted vs ARC para 3 escenarios distintos (repo público OSS, monorepo privado con builds pesados, equipo regulado con red privada). Escribir un ADR corto justificando la elección. Diseñar runner groups por team/repo. |

## Criterios de evaluación

- **Conceptual** — Responder correctamente: "¿cuándo es incorrecto usar self-hosted y por qué?" y "¿qué tres medidas tomarías si *tuvieras* que correr workflows de un repo público en self-hosted?".
- **Operativa** — `activities/01` pasa el validador; `activities/02` instala ARC en `kind` y el CR dummy pasa validación de schema del operator.
- **Arquitectónica** — ADR entregado en `activities/02` compara hosted, larger runners, self-hosted VMs y ARC con criterios de coste, seguridad, operación y latencia.

## Secuencia recomendada

1. Lee `theory/lesson.md` completa (en especial las secciones 5 y 6: seguridad y ARC).
2. Reproduce `examples/01-register-self-hosted-runner/` leyéndolo con atención — **no** necesitas registrar un runner real para entenderlo.
3. Haz `activities/01-run-job-on-self-hosted/` (guided).
4. Lee `examples/02-arc-in-kind/`.
5. Haz `activities/02-arc-minimal-install/` (independent, mini-proyecto, la que te evalúa).
6. Responde las preguntas de reflexión sin consultar.

## Herramientas requeridas

Este módulo exige:

- `docker` corriendo localmente.
- `kind` ≥ 0.20 (o `k3d` ≥ 5.x; los scripts usan `kind`).
- `kubectl` ≥ 1.28.
- `helm` ≥ 3.12.
- Opcional (modo `live`): el binario `actions-runner` descargado de GitHub + un repo real + un **PAT fine-grained** con permiso `administration: read/write` sobre ese repo.

Si no tienes alguna, los validadores **saltan limpiamente** (no fallan espuriamente) explicando qué instalar.

## Siguiente

→ `gha-11-oidc-and-cloud-federation`.
