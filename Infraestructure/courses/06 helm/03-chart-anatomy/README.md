# helm-03 — Anatomía de un chart

## Identificación

- **ID:** `helm-03-chart-anatomy`
- **Curso:** `helm`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `helm-02-consume-charts-install-upgrade-rollback`.

## Objetivo

Crear un chart propio bien estructurado **desde cero**, entendiendo cada archivo
del scaffold, el rol de `Chart.yaml` como metadatos, el de `values.yaml` como
*contrato de inputs*, y el de **`values.schema.json`** como validador de ese
contrato. Al terminar, deberías poder generar un chart funcional para la app del
capstone y defender decisiones estructurales (incluyendo *por qué los CRDs no se
actualizan en upgrade*).

## Alcance

Este módulo cubre:

- `helm create <name>` y qué recorta de ese scaffold "demo".
- `Chart.yaml` v2: campos obligatorios y semántica de `type: application|library`.
- Convenciones de `templates/`: `deployment.yaml`, `service.yaml`,
  `_helpers.tpl`, `NOTES.txt`, `tests/`.
- `values.yaml` como **API pública** del chart y cómo documentarla.
- `.helmignore` y por qué importa en charts empaquetados.
- `values.schema.json` como contrato validable con **JSON Schema**.
- `files/` para `.Files.Get` y recursos de solo lectura.
- `crds/`: por qué Helm los instala pero *no* los actualiza.

Lo que **no** cubre (otros módulos):

- Sintaxis profunda de Go templates y Sprig → `helm-04`.
- Precedencia y overrides por entorno → `helm-05`.
- Dependencias y umbrella charts → `helm-06`.
- Hooks y `helm test` → `helm-07`.

## Materiales

- **`theory/lesson.md`** — lección profunda con **12 secciones**.
- **`examples/`**:
  - `01-helm-create-scaffold/` — qué genera `helm create` y qué eliminar.
  - `02-minimal-chart-from-scratch/` — chart mínimo con solo Deployment + Service.
  - `03-values-schema-json/` — validación de `values` con JSON Schema.
- **`activities/`**:
  - `01-chart-for-fastapi/` — construir el chart base del capstone (guided-lab).
  - `02-add-values-schema/` — añadir `values.schema.json` y defender el contrato (independent).
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `type: application` y `type: library`. Articular por qué CRDs en `crds/` **no** se actualizan en `upgrade`. Decir qué pasa si `apiVersion` es `v1`. |
| Operativa | Generar un scaffold limpio, borrar los knobs innecesarios, escribir `values.schema.json` que valide `required` y `enum`. Correr `helm lint` + `helm template` + `helm install --dry-run`. |
| Arquitectónica | Decidir qué va en `values` y qué queda hard-codeado en templates. Elegir si una CRD debe vivir en `crds/`, como chart separado, o fuera de Helm. |

## Criterios de evaluación

- Chart generado desde cero (no copiado de `helm create` sin podar).
- `Chart.yaml` válido con `apiVersion: v2` y los campos obligatorios.
- `values.schema.json` que rechaza inputs inválidos con `helm install --dry-run`.
- Respuesta argumentada: *"¿por qué CRDs no se upgradean y qué estrategia aplicar?"*.

## Secuencia recomendada

1. Lee `theory/lesson.md` completa.
2. Reproduce `examples/01-helm-create-scaffold/` (observa qué se genera).
3. Reproduce `examples/02-minimal-chart-from-scratch/` (minimalismo deliberado).
4. Reproduce `examples/03-values-schema-json/` (contrato validable).
5. Haz `activities/01-chart-for-fastapi/` (chart propio del capstone).
6. Haz `activities/02-add-values-schema/` (schema que endurece el contrato).
7. Responde la pregunta de evaluación sobre CRDs.

## Siguiente

→ `helm-04-templating-deep`: Go templates, Sprig, `include` vs `template`,
`required`, `nindent`, y debugging de render.
