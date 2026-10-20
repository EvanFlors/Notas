# plat-05 — Software Catalog en profundidad

## Identificación

- **ID:** `plat-05-software-catalog-deep`
- **Curso:** `platform-engineering`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `plat-04-backstage-architecture-and-setup`. Haber levantado un Backstage local al menos una vez; conocer qué es un plugin de Backstage; haber usado YAML y pre-commit en algún curso previo.

## Objetivo

Modelar el software de una organización con el **catálogo de Backstage** como fuente de verdad del inventario — no como un wiki tipado — y entender por qué sin disciplina de `annotations` y relaciones el catálogo degrada hasta volverse ruido. Al terminar deberías poder diseñar `catalog-info.yaml` para servicios reales, elegir el `kind` correcto, nombrar al `owner`, declarar relaciones (`providesApi`, `consumesApi`, `dependsOn`, `partOf`, `memberOf`) y proteger el catálogo con un hook `pre-commit` que valide la estructura antes de que el repo se la coma.

## Alcance

Este módulo cubre:

- El **entity model** de Backstage (`apiVersion: backstage.io/v1alpha1`) y los *kinds* más usados: **Component**, **API**, **Resource**, **System**, **Domain**, **User**, **Group**, **Location**.
- `catalog-info.yaml` por servicio: metadata obligatoria, metadata recomendada, convenciones de naming.
- **Relaciones** entre entidades: `providesApi`, `consumesApi`, `dependsOn`, `partOf`, `memberOf`, y cómo habilitan vistas de impacto reales.
- **Processors** y **providers** del catalog: cómo entra la data (manual via `Location`, descubrimiento desde GitHub orgs, descubrimiento recursivo).
- **Annotations** vinculadas a plugins (`github.com/project-slug`, `backstage.io/kubernetes-id`, `pagerduty.com/integration-key`, `backstage.io/techdocs-ref`, etc.) y por qué sin ellas los plugins no muestran nada.
- El modelo mental "**el catálogo es la fuente de verdad del inventario**" y qué significa en la práctica (no es un wiki, no es un mapa estático).
- Cómo evitar que se vuelva stale: validadores en CI y hooks pre-commit que verifican `catalog-info.yaml` antes del push.
- Estrategia de **importación gradual** de un parque existente sin provocar un *big bang*.

Lo que **no** cubre (se verá después):

- Templates / Scaffolder → `plat-06`.
- TechDocs → `plat-07`.
- Plugins instalados / custom plugin → `plat-08`.
- Scorecards de madurez → `plat-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-catalog-info-skeleton/` — anatomía anotada de un `catalog-info.yaml` mínimo, uno completo, y los errores habituales en producción.
  - `02-github-provider-ingest/` — cómo configurar el `GithubEntityProvider` para descubrir `catalog-info.yaml` en una org entera.
  - `03-relations-impact-view/` — un sistema de 3 Components + 2 APIs + 1 Resource; cómo las relaciones habilitan la pregunta "si tiro este API, ¿quién se rompe?".
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-model-capstone-in-catalog/` — modelar un sistema capstone (3+ Components, 2+ APIs, 1 Resource, 1 System, 1 Domain, Groups con owners) en un árbol de `catalog-info.yaml`.
  - `02-pre-commit-validate-catalog-info/` — escribir un hook de pre-commit en Bash que valide estructuralmente los `catalog-info.yaml` del repo y rechace commits con metadata rota.
- **`resources/links.md`** — referencias oficiales (docs de Backstage, kinds, annotations).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el catálogo es *fuente de verdad del inventario* y no un wiki. Enumerar los 8 kinds principales con un caso de uso para cada uno. Diferenciar `Location` de `Entity`. |
| Operativa (sin cluster) | Diseñar `catalog-info.yaml` para un servicio real con owner, system, annotations relevantes y relaciones a APIs / Resources. Validar la estructura localmente con `python3`. |
| Arquitectónica | Decidir cuándo usar `GithubEntityProvider` vs declarar `Location` manual. Diseñar el modelo mínimo (Domains / Systems / Components) para una organización dada. Diagnosticar un catálogo "ruidoso" por relaciones incorrectas. |

## Criterios de evaluación

- Explica, con palabras propias, la diferencia entre `Component`, `API`, `Resource` y `System`.
- Dado un servicio inventado, produce un `catalog-info.yaml` válido con owner, relaciones y al menos 2 annotations útiles.
- Protege un repo con un hook pre-commit que impide commits con `catalog-info.yaml` mal formado.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Árbol de `catalog-info.yaml` modelando el capstone (sale de la actividad `01-model-capstone-in-catalog`).
- Hook de pre-commit funcional + fixtures de prueba (sale de la actividad `02-pre-commit-validate-catalog-info`).

## Siguiente módulo

→ `plat-06-templates-and-scaffolder` — convertir el modelo del catálogo en un *golden path* ejecutable: templates que crean repo + CI + chart + Argo Application + entrada en el catálogo en minutos.
