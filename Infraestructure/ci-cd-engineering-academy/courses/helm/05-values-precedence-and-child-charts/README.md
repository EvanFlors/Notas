# helm-05-values-precedence-and-child-charts

## Identificación
- **ID:** `helm-05-values-precedence-and-child-charts`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `helm-03-chart-anatomy`, `helm-04-templating-deep`

## Objetivo
Manejar valores de Helm con **precedencia predecible** y diseñar un contrato de `values` consistente que funcione tanto en el chart raíz como en sus **subcharts**.

## Temas y subtemas
- Precedencia de valores (de menor a mayor):
  1. `values.yaml` del chart (defaults).
  2. `values.yaml` de un chart padre que sobreescribe un subchart (via `charts/<sub>/values` o la clave con el nombre del subchart).
  3. `--values` / `-f` en el orden en que se pasan (último gana).
  4. `--set`, `--set-string`, `--set-file`, `--set-json` (último gana entre los `--set`).
- `-f` múltiples y por qué el **orden importa**.
- Overrides por entorno: `values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml`.
- Scoping en subcharts: cada subchart tiene su propio namespace de `.Values`.
- `global:` como única zona compartida entre padre y subcharts.
- `import-values` y `exports` para "elevar" valores de un subchart al padre sin replicar su estructura.
- Coexistencia con `values.schema.json` para evitar duplicación.

## Conceptos internos (fundamentos)
- Al renderizar, Helm **merge-ea** varias fuentes en un árbol único `.Values` por chart. El merge es *deep merge* para mapas y *reemplazo* para listas (una lista en un override reemplaza a la lista default completa).
- Un chart padre puede sobreescribir valores del subchart `foo` usando una clave `foo:` en su `values.yaml`. Si el padre no la define, el subchart ve sus propios defaults.
- `global:` es un *sub-árbol especial* que Helm propaga a todos los subcharts bajo `.Values.global`. Es la única frontera "compartida".
- `import-values` (en `Chart.yaml` del padre) copia claves del subchart hacia `.Values` del padre, por lo que el padre no necesita conocer la estructura interna del hijo.
- `exports` (en el `values.yaml` del subchart) declara qué parte del subchart está disponible para imports *implícitos*.

## Competencias
- **Conceptual:** predecir el valor efectivo de cualquier clave dado un conjunto de `-f` y `--set`.
- **Operativa:** separar un chart multi-entorno en `values-<env>.yaml` consistentes y sin duplicación.
- **Arquitectónica:** diseñar el "contrato de values" (qué es un flag del operador, qué va en `global`, qué se expone vía `import-values`).

## Ejemplos
- `examples/01-precedence-walkthrough/` — cadena completa defaults → `-f` → `--set`.
- `examples/02-global-values-across-subcharts/` — un `global.imageRegistry` visible desde padre y subchart.
- `examples/03-import-values/` — padre consume `backend.exports.service.port` como `.Values.servicePort`.

## Actividades
- `activities/01-env-overrides-dev-stg-prod/` (guided-lab) — chart con `values-{dev,stg,prod}.yaml` consistentes.
- `activities/02-share-image-registry-via-global/` (independent) — padre + 2 subcharts que consumen `global.imageRegistry`.

## Entregables
- Chart con `values.yaml` por default y tres overrides de entorno (`values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml`) que renderizan sin errores.
- Chart padre con subcharts que consumen un valor `global`.
- Capacidad demostrada de predecir el valor final de una clave dado una combinación de `-f` y `--set`.

## Criterios de evaluación
- **Conceptual:** explicar por qué `--set` siempre gana al último `-f` y qué pasa si se mezclan en orden distinto en la CLI.
- **Operativa:** auditar un `helm template --debug` y señalar la fuente de cada valor renderizado.
- **Arquitectónica:** decidir si un valor compartido debe vivir en `global`, en `import-values` o duplicarse (y defender la decisión).

## Recursos
Ver `resources/links.md`.
