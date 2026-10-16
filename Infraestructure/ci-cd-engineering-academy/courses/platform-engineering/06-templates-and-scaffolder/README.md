# plat-06 — Templates y Scaffolder

## Identificación

- **ID:** `plat-06-templates-and-scaffolder`
- **Curso:** `platform-engineering`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `plat-05-software-catalog-deep` (modelo de catálogo), haber recorrido `plat-04` (Backstage levantado o entendido estructuralmente). No se requiere un Backstage corriendo: todos los ejercicios validan **estructura** del template y, cuando interesa ejecutar el scaffolder, se usa **cookiecutter** como herramienta local análoga.

## Objetivo

Entender que un **template de Backstage** no es un simple generador de código: es el **contrato de inicio** de un *golden path*. Al terminar deberías poder (a) diseñar la anatomía de un `template.yaml` (parámetros, pasos, output), (b) descomponer un template "mega" en templates compuestos, y (c) tratar el template como **producto** — con versión, tests en CI y un camino para re-bajar mejoras (`update-from-template`).

## Alcance

Este módulo cubre:

- **Anatomía** de un template Backstage (`apiVersion: scaffolder.backstage.io/v1beta3`): `parameters` (JSON Schema que pinta el form), `steps` (acciones secuenciales con `id`, `name`, `action`, `input`), `output` (links y entityRef).
- **Scaffolder actions built-in**: `fetch:template`, `fs:rename`, `fs:delete`, `publish:github`, `catalog:register`, `debug:log`. Cuándo escribir una **custom action** en TypeScript (y cuándo no).
- **Nunjucks templating** sobre el skeleton: sintaxis `${{ values.name }}`, filtros útiles (`lower`, `replace`, `parseRepoUrl`), y por qué los archivos del skeleton suelen llevar sufijo `.njk` o se renombran dinámicamente con `fs:rename`.
- **Patrones end-to-end**: template "nuevo microservicio Python" que crea repo + GHA + Helm chart + Argo Application + TechDocs + catalog entry y abre PR a un bootstrap repo.
- **Template como producto**: versionado (`metadata.name` + tag), fixture de referencia que se regenera en CI y se compara con `git diff`, estrategia `update-from-template`.
- **Antipatrones**: templates "mega" acoplados, parámetros sin JSON Schema, templates sin tests que caen la primera vez que alguien actualiza una acción.

Lo que **no** cubre:

- Instalar o parchear Backstage (`plat-04`).
- Modelado profundo del catálogo (`plat-05`).
- Self-service de infra via Crossplane (`plat-09`).

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones.
- **`examples/`** — demos de lectura (no requieren Backstage corriendo):
  - `01-template-skeleton/` — anatomía mínima de un `template.yaml` comentado línea por línea.
  - `02-nunjucks-templating/` — ejemplos de interpolación, filtros y archivos del skeleton.
  - `03-end-to-end-microservice-template/` — template compuesto que combina `fetch:template`, `publish:github`, `catalog:register`.
- **`activities/`** — dos actividades independientes:
  - `01-build-microservice-template/` — construir un `template.yaml` + skeleton para un microservicio Python; validación estructural + prueba local con cookiecutter si está disponible.
  - `02-test-template-in-ci/` — escribir el workflow de CI que regenera la fixture y falla si diverge; el validador comprueba estructura del workflow y ejecuta el script localmente.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un template es un **contrato de inicio** y no un generador de código. Distinguir `parameters` (schema) de `steps` (acciones) y por qué el orden importa. |
| Operativa | Escribir un `template.yaml` v1beta3 válido con 3+ parámetros, 3+ steps y output. Añadir el skeleton con nunjucks e invocar `fetch:template` para renderizarlo. |
| Arquitectónica | Descomponer un template "mega" en componentes reutilizables; definir un pipeline de CI que trata el template como producto. |

## Criterios de evaluación

- Diseña un `template.yaml` con `parameters` que validen vía JSON Schema (required, enum, pattern).
- Explica qué hace cada built-in action utilizada y por qué no se reemplaza por una custom action.
- Entrega las dos actividades con sus validadores estructurales en verde.
- Puede justificar la elección de **cookiecutter** como análogo local cuando no hay Backstage corriendo.

## Entregables

- `template.yaml` + skeleton del "nuevo microservicio Python" (sale de la actividad `01-build-microservice-template`).
- Workflow de CI + script `regenerate-fixture.sh` que trata el template como producto (sale de la actividad `02-test-template-in-ci`).

## Siguiente módulo

→ `plat-07-techdocs-docs-as-code` — docs owned by services, publicación centralizada y estándar mínimo por servicio.
