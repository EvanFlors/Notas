# tf-10 — Internals: grafo y algoritmo del plan

## Identificación

- **ID:** `tf-10-internals-graph-and-plan-algorithm`
- **Curso:** `terraform`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `tf-05-state-basics`, `tf-09-providers-deep-and-lifecycle`.

## Objetivo

Entender **qué hace Terraform por dentro** cuando corres `plan` o `apply`, para poder razonar sobre plans "sorprendentes" (recursos que se destruyen sin motivo aparente, drift que aparece y desaparece, cambios encadenados que no esperabas). Al terminar deberías poder abrir un `plan.out`, convertirlo a JSON, interpretar su contenido y explicarle a otro ingeniero por qué Terraform propone lo que propone, sin recurrir al "no sé, lo marcó así".

## Alcance

Este módulo cubre:

- `terraform graph` y lectura de **DAGs** (grafos dirigidos acíclicos).
- Las **tres fases** reales del `plan`: build-the-graph, refresh y diff.
- El **algoritmo del plan** como comparación atributo por atributo.
- `-refresh-only` como herramienta de reconciliación de drift sin cambios.
- `-target` como *escape hatch* (y por qué no es una práctica).
- `terraform show -json` para análisis programático con `jq`.
- Visión general del **plugin protocol gRPC** entre core y providers.

Lo que **no** cubre (ya visto o se verá después):

- Lifecycle meta-arguments (`ignore_changes`, `create_before_destroy`, `replace_triggered_by`) → `tf-09`.
- Backends remotos y locking → `tf-11`.
- `policy-as-code` sobre `plan.json` (Rego/Conftest/Sentinel) → `tf-12`.
- Drift detection scheduled en CI/CD → `tf-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-graph-visualization/` — generar el DAG con `terraform graph` y renderizarlo con `dot` (opcional).
  - `02-plan-json-analysis/` — producir un `plan.out`, convertirlo a JSON y analizarlo con `jq`.
  - `03-refresh-only-to-reconcile/` — detectar drift sin aplicar cambios reales.
- **`activities/`**:
  - `01-why-is-this-being-replaced/` (independent/debug) — un `null_resource` que se recrea en cada `plan`; averiguar por qué sin que te lo digan.
  - `02-reconcile-drift-safely/` (independent) — modificar un `local_file` fuera de Terraform y decidir con `-refresh-only` si aceptar o revertir.
- **`resources/links.md`** — docs oficiales y lecturas.

## Temas y subtemas

1. El grafo
   - DAG: nodos (resources, data, providers, modules) y aristas (dependencias).
   - Referencias implícitas (`a.id` en `b`) vs `depends_on` explícito.
   - `terraform graph` y los distintos tipos (`plan`, `apply`, `plan-refresh-only`).
2. Las fases del plan
   - Build graph.
   - **Refresh**: para cada `resource` en state, el core pide al provider `ReadResource` y actualiza el state en memoria.
   - **Diff**: para cada recurso en la config, compara estado deseado vs estado post-refresh, atributo por atributo.
3. El algoritmo del diff
   - Acciones: `no-op`, `create`, `read` (para data), `update`, `destroy`, `delete-then-create` (replace), `create-then-delete` (replace con `create_before_destroy`).
   - **ForceNew**: schema del provider marca atributos cuya mutación obliga a recrear.
   - `(known after apply)` y por qué aparece.
4. `-refresh-only` y `-refresh=false`
   - `-refresh-only`: solo actualiza el state; no propone cambios de infra.
   - `-refresh=false`: no consulta providers; **acelera pero oculta drift** — útil solo en runs cortos y controlados.
5. `-target`
   - Fragmenta el plan: construye un subgrafo con solo los nodos pedidos y sus dependencias.
   - Peligroso en producción: el state resultante puede quedar inconsistente con el modelo global.
   - Es un *escape hatch* para desbloquear situaciones puntuales (p. ej. un plan roto por un provider), no una práctica recurrente.
6. `terraform show -json`
   - Formato estable (versionado por `format_version`).
   - Secciones: `configuration`, `planned_values`, `resource_changes`, `prior_state`, `output_changes`.
   - Base de policy-as-code (OPA/Conftest/Sentinel) y de drift reporting.
7. Plugin protocol gRPC
   - Core y provider son procesos distintos; se comunican por gRPC local.
   - El schema del provider se declara al core en `GetProviderSchema`.
   - Operaciones del protocolo: `ValidateResourceConfig`, `ReadResource`, `PlanResourceChange`, `ApplyResourceChange`, `ImportResourceState`.
   - Por qué esto desacopla el ciclo de releases de Terraform core del de los providers.

## Conceptos internos (fundamentos)

- **Refresh no es cosmético.** Es la fase que convierte "lo que el state dice que había" en "lo que de verdad hay ahora mismo". Si la desactivas, trabajas con un snapshot potencialmente obsoleto; el plan será más rápido pero puede proponer cambios equivocados (p. ej. recrear algo que ya existe pero el state no ve).
- **El diff es sintáctico, pero informado por el schema.** Terraform core no "sabe" que un EBS `size` puede subir pero no bajar sin recrear: el provider se lo dice marcando el atributo con `ForceNew` en el schema. Por eso dos providers pueden tratar el mismo campo con reglas distintas.
- **`-target` fragmenta la verdad.** El grafo global representa una realidad coherente ("todos estos recursos se reconcilian entre sí"). Pedir un subgrafo rompe esa coherencia: el state actualizado parcialmente puede sorprenderte en el siguiente plan completo. HashiCorp documenta `-target` como herramienta de emergencia precisamente por esto.
- **`known after apply` no es un bug.** Aparece cuando el valor depende de algo que la API solo devuelve tras crear/mutar el recurso (p. ej. un ARN generado). Sintetiza una limitación real: Terraform no puede "predecir" lo que el cloud te dará.
- **El plan JSON es la interfaz pública estable.** Es lo que debes atacar con herramientas automatizadas (policies, dashboards, drift reports). Nunca parsees texto del `plan` humano: cambia entre versiones.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar paso a paso las fases del `plan` (build-graph → refresh → diff) sin consultar docs. Explicar por qué `ForceNew` lo decide el provider y no el core. |
| Operativa | Depurar un plan "raro": generar el grafo, exportar `plan.json`, atacarlo con `jq` y aislar la causa. Usar `-refresh-only` para reconciliar drift. |
| Arquitectónica | Decidir cuándo (y cuándo no) usar `-target` o `-refresh=false`. Diseñar un drift report sobre `plan.json`. |

## Entregables

- Writeup (`writeup.md` en tu carpeta de trabajo) con la interpretación de un plan complejo: qué acciones propone, por qué, y qué atributos las disparan.
- Los dos `tests/validate.sh` de las actividades deben pasar.
- Para la actividad 02, un `decision.md` razonando si aceptas el drift o lo revertís.

## Criterios de evaluación

- Explicar sin apuntes las fases del `plan` y qué hace cada una.
- Dado un `plan.json`, aislar qué recurso cambia y por qué, usando solo `jq`.
- Justificar por qué `-target` no es sustituto de ordenar bien el refactor de un stack.
- Diagnosticar correctamente un `null_resource` que se recrea en cada run por un `triggers` no determinista.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-graph-visualization/`.
3. Reproduce `examples/02-plan-json-analysis/`.
4. Haz `activities/01-why-is-this-being-replaced/`.
5. Reproduce `examples/03-refresh-only-to-reconcile/`.
6. Haz `activities/02-reconcile-drift-safely/`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `tf-11-remote-backends-and-locking`: ya entiendes qué hace el plan por dentro; ahora el state deja de vivir en tu disco y empieza a vivir en un backend compartido con locking.
