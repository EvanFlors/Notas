# gh-08 — Workflows: trunk-based vs GitFlow (y los demás)

## Identificación

- **ID:** `gh-08-workflows-trunk-vs-gitflow`
- **Curso:** `git-and-github`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gh-07-collaboration-prs-and-review`.

## Objetivo

Comparar los modelos de ramificación más usados (**trunk-based development**, **GitHub Flow**, **GitLab Flow**, **GitFlow**, **release branches**, **environment branches**), entender el *por qué* mecánico detrás de cada uno (velocidad de integración, duración de ramas, costo de merge) y **seleccionar uno fundamentado** para un equipo concreto. Al terminar deberías poder defender tu elección frente a un comité de arquitectura.

## Alcance

- **Trunk-based development**: ramas efímeras (<1 día), *continuous integration* real, *feature flags* como habilitador.
- **GitHub Flow**: variante minimalista (una sola rama larga, `main`), despliegue continuo.
- **GitLab Flow**: añade *environment branches* (pre-production → production) con la promesa de "flujo controlado".
- **GitFlow**: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`. Por qué fue útil en 2010 y por qué suele ser *overkill* en 2026.
- **Release branches** y **hotfix** como primitivas independientes del modelo elegido.
- **Environment branches como anti-patrón** (`main` → `staging` → `production` por *cherry-pick*): por qué casi siempre falla.
- **Feature flags** como palanca mecánica: desacoplan *deploy* de *release*.
- **Correlación entre longitud de rama y dolor de merge** ("merge hell").

Lo que **no** cubre (va después):
- Branch protection, rulesets, merge queues → `gh-12`.
- Firma de commits y supply chain → `gh-13`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-trunk-based-timeline/` — DAG de un día típico de trunk-based con feature flag.
  - `02-gitflow-timeline/` — DAG de un ciclo completo de GitFlow (develop + release + hotfix).
- **`activities/`**:
  - `01-simulate-trunk-based/` — guided-lab: dos features cortas detrás de flags, integradas a `main` el mismo día.
  - `02-simulate-gitflow/` — guided-lab: vivir en carne propia la fricción de `develop`/`release`/`hotfix`.
  - `03-architecture-decision/` — **independent**: escribir un ADR eligiendo workflow para un escenario dado.
- **`resources/links.md`** — referencias canónicas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué ramas largas → merge hell; definir trunk-based en términos de *lead time to integration*; distinguir *deploy* de *release* y el rol de feature flags. |
| Operativa | Reproducir en Git las topologías de trunk-based y GitFlow completas (feature → develop → release → main + hotfix); leer un DAG y nombrar el modelo que lo produjo. |
| Arquitectónica | Elegir y defender un workflow para un contexto dado (equipo, producto, release cadence, regulación), identificando en qué escenarios cada modelo falla y qué prácticas lo compensan. |

## Criterios de evaluación

- Dos simulaciones Git con topologías correctas (verificadas por script).
- Un **ADR** con decisión, criterios aplicados, alternativas descartadas y riesgos — rubro `arquitectura/`.
- Capacidad de contestar las preguntas de evaluación de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-trunk-based-timeline/` y luego `examples/02-gitflow-timeline/`.
3. Haz `activities/01-simulate-trunk-based/`.
4. Haz `activities/02-simulate-gitflow/` — presta atención a la fricción (número de merges, orden obligatorio, ramas vivas simultáneas).
5. Haz `activities/03-architecture-decision/` escribiendo el ADR.
6. Responde las 8 preguntas de evaluación sin consultar.

## Siguiente

→ `gh-09-git-internals` (nivel 3, avanzado) y, en producción, → `gh-12-github-governance-and-automation` donde el workflow elegido aquí se materializa en políticas de branch protection y rulesets.
