# gl-01 — Modelo mental de GitLab y mapping a GitHub Actions

## Identificación

- **ID:** `gl-01-model-and-mapping-to-gha`
- **Curso:** `gitlab-cicd`
- **Nivel:** fundamentos (beginner)
- **Duración estimada:** 2 h
- **Prerrequisitos:** curso **github-actions** completo (al menos hasta `gha-05` o equivalente).

## Objetivo

Interiorizar la **jerarquía de GitLab** (`Instance → Group → Subgroup → Project`), las **modalidades de despliegue** (SaaS `gitlab.com`, Self-Managed CE/EE, Dedicated), el **gating por plan** (Free/Premium/Ultimate) y el **modelo de pipeline** (pipeline → stages → jobs, con DAG opcional vía `needs:`). Al terminar deberías poder **traducir conceptos GHA ↔ GitLab sin tabla a la vista** y defender una primera decisión arquitectónica (seguir en GHA, migrar a GitLab, o convivir) por escrito como un ADR.

## Alcance

Este módulo cubre:

- **Jerarquía**: Instance, Group, Subgroup (anidables), Project. Diferencias con GitHub (Org, Repo, Team).
- **Modalidades**: SaaS (`gitlab.com`), **Self-Managed** (CE/EE) y **Dedicated** (SaaS tenant aislado operado por GitLab).
- **Planes**: Free, Premium, Ultimate. Qué features clave quedan **gated** (muchas de seguridad/compliance) y cómo esto condiciona cualquier decisión seria. Comparación con GHAS (GitHub Advanced Security) en GitHub.
- **Modelo de pipeline**: pipeline → stages → jobs, visualización por stage y DAG opcional.
- **Mapping sistemático GHA ↔ GitLab**: workflow ≈ pipeline, job ≈ job, action/composite ≈ `extends`/`include`/CI/CD Component, PR ≈ MR, org runners ≈ Group Runners, branch protection ≈ Protected Branches/Tags/Environments.
- **Terminología**: MR (Merge Request) = PR, Group Runner ≈ org-level runner, Protected Environment ≈ environment protection rule.

Lo que **no** cubre (se verá después):

- Escribir `.gitlab-ci.yml`, pipeline runnable, runners reales → `gl-02`.
- Variables, secretos, ID Tokens / OIDC → `gl-03`.
- `rules:`, `workflow:`, `needs:`, matrices → `gl-04`.
- `include:`, `extends:`, CI/CD Components → `gl-05`.
- Executors, DinD, Fleeting, Kubernetes → `gl-06`.
- Environments, Review Apps, Agent for Kubernetes → `gl-07`.
- Scanners nativos y supply chain → `gl-08`.
- Compliance y governance → `gl-09`.
- Migración detallada y platform patterns → `gl-10`.

Este módulo es **mayoritariamente conceptual + ADR**. **No** se provisiona nada en una cuenta real ni se ejecuta ningún pipeline. Las dos actividades son análisis escritos y un ADR estructural; el único *tooling* es `bash`, `grep` y un editor Markdown. **No se necesita un proyecto real en GitLab** — basta con haber visto `gitlab.com` como visitante.

## Materiales

- **`theory/lesson.md`** — lección profunda con secciones: jerarquía, modalidades, planes, modelo de pipeline, mapping GHA↔GitLab, terminología, trade-offs iniciales, criterios de elección plataforma.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-group-subgroup-structure/` — árbol ASCII anotado de una org típica con subgroups anidables y por qué eso cambia el diseño frente a GitHub.
  - `02-plan-gating-matrix/` — matriz Free/Premium/Ultimate con las features más decisivas para una decisión de plataforma; qué equivale a GHAS en GitHub.
  - `03-translate-gha-concepts/` — tabla y ejercicio resuelto de traducción GHA → GitLab para 10+ conceptos clave.
- **`activities/`** — dos actividades **independientes**:
  - `01-explore-gitlab-com/` — recorrido guiado (sin ejecutar nada) por `gitlab.com`: localiza Groups, Subgroups, Projects, Settings; produce un **cheatsheet personal** `CHEATSHEET.md` con el mapping y la ubicación de 10 pantallas clave.
  - `02-adr-gitlab-vs-github-first-pass/` — un **ADR** `ADR-GITLAB-VS-GITHUB.md` que decide, para un escenario dado, si una org empieza en GHA o en GitLab (o convive) y por qué.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Dibujar la jerarquía `Instance → Group → Subgroup → Project` y explicar por qué Group ≈ Org con subgroups anidables. Nombrar las 3 modalidades (SaaS, Self-Managed, Dedicated) y en qué contexto cada una. |
| Operativa (sin infra) | Traducir 10 conceptos GHA ↔ GitLab sin tabla. Identificar qué features son Premium/Ultimate y por qué eso puede cambiar la decisión. |
| Arquitectónica | Defender por escrito la elección GHA vs GitLab (o convivencia) para un contexto dado, con trade-offs explícitos y alternativas descartadas. |

## Criterios de evaluación

- Dado un diagrama `Group / Subgroup / Project`, explicas qué permisos y recursos (runners, variables, templates) se comparten en cada nivel.
- Mapeas correctamente 10 features GHA a su equivalente GitLab (workflow, job, action, composite, reusable workflow, environment, OIDC, PR, org runner, required workflow).
- Explicas por qué una feature de **seguridad** gated a Ultimate puede inclinar la decisión de plataforma incluso si lo demás es equivalente.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Cheatsheet** `CHEATSHEET.md` con el mapping GHA ↔ GitLab y la ubicación de 10 pantallas clave en `gitlab.com` (sale de la actividad `01`).
- **ADR** `ADR-GITLAB-VS-GITHUB.md` con la decisión plataforma inicial justificada (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto Markdown. No se requiere cuenta GitLab paga ni proyecto real. Para la actividad `01` basta con `gitlab.com` como visitante (opcionalmente una cuenta Free gratuita). Si en un módulo posterior decides crear un Group real:

- **GitLab SaaS Free**: gratis con límites (minutos de runner compartidos, almacenamiento, features).
- **Premium / Ultimate**: de pago por usuario/mes — no se necesita en este módulo.
- **Self-Managed CE**: gratis como software, pero cuesta operarlo (infra + personas).

## Siguiente módulo

→ `gl-02-gitlab-ci-yml-pipelines-runners` — primer `.gitlab-ci.yml` runnable, anatomía del archivo, tipos de runner.
