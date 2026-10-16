# plat-07 — TechDocs & docs-as-code

## Identificación

- **ID:** `plat-07-techdocs-docs-as-code`
- **Curso:** `platform-engineering`
- **Nivel:** avanzado
- **Duración estimada:** 3 h
- **Prerrequisitos:** `plat-04-backstage-architecture-and-setup`, `plat-05-software-catalog-deep`.

## Objetivo

Integrar la documentación de servicio como **código versionado**: cada repo lleva su propio `/docs` + `mkdocs.yml`, Backstage los renderiza vía **TechDocs**, y el ciclo de vida de las docs se somete al mismo rigor que el código (PR, review, CI, deploy). Al terminar deberías poder decidir entre render **in-situ** (dev) y **centralized** (prod), diseñar el pipeline que empuja HTML a S3/GCS/Azure Blob y definir un **estándar mínimo de docs** que no se vuelva un wiki paralelo que nadie actualiza.

## Alcance

Este módulo cubre:

- **Arquitectura TechDocs:** per-repo `/docs/*.md` + `mkdocs.yml`, anotación `backstage.io/techdocs-ref` en `catalog-info.yaml`, y cómo Backstage descubre, renderiza y sirve el sitio.
- **Dos modelos operativos:** render **in-situ** (Backstage ejecuta `mkdocs build` cada vez — útil en dev, inviable a escala) vs **centralized** (un builder job en CI empuja HTML a un bucket; Backstage solo sirve lo que ya está hecho).
- **Pipeline CI de publicación:** `techdocs-cli generate` + `techdocs-cli publish --publisher-type awsS3|googleGcs|azureBlobStorage`, con credenciales mínimas (OIDC federado preferido sobre long-lived keys) y lifecycle rules del bucket.
- **UX dentro de Backstage:** navegación por entity, búsqueda full-text (si está habilitada), versioning por rama o por commit SHA, y la pestaña TechDocs del `EntityPage`.
- **Plugins MkDocs útiles:** `mkdocs-techdocs-core` (bundle oficial que ya incluye `pymdownx`, `admonition`, `codehilite`, `mermaid2`), más plugins puntuales: `mkdocs-mermaid2-plugin`, `mkdocs-render-swagger-plugin` para OpenAPI, `mkdocs-git-revision-date-localized-plugin`.
- **Modelo "docs owned by services":** cada equipo dueño de sus docs, revisadas en el mismo PR que el código, con CODEOWNERS que forzan review del equipo responsable.
- **Checklist de qué documentar** por servicio: README (puerta de entrada), ADRs (`docs/adr/*`), runbooks (`docs/runbook/*`), API refs (autogen desde OpenAPI/AsyncAPI), contactos y SLOs.
- **Autogen de API docs:** cómo renderizar un `openapi.yaml` dentro del sitio TechDocs con `mkdocs-render-swagger-plugin` o incrustando ReDoc/Swagger UI estático.
- **Antipatterns:** wiki paralelo (Confluence) que se desactualiza, docs en Google Docs que nadie encuentra, READMEs de 2000 líneas que son en realidad 10 docs mezcladas.

Lo que **no** cubre (se verá después):

- Plugins Backstage que *consumen* contexto operativo (K8s, Argo CD, GitHub Actions) → `plat-08`.
- Self-service de infra → `plat-09`.
- Scorecards que miden "¿tiene docs?" como fact/check → `plat-10`.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones: arquitectura, in-situ vs centralized, pipeline CI, plugins MkDocs, UX, API autogen, estándar mínimo, antipatterns.
- **`examples/`** — tres ejemplos:
  - `01-mkdocs-site-skeleton/` — esqueleto mínimo de un sitio MkDocs con `techdocs-core`. **Ejecutable localmente** si tienes `pip install mkdocs mkdocs-techdocs-core` (`mkdocs serve`, `mkdocs build --strict`).
  - `02-techdocs-centralized-s3/` — walkthrough del pipeline CI que empuja HTML a S3 con `techdocs-cli publish`. Lectura y análisis, **no** se ejecuta (requiere cuenta cloud).
  - `03-openapi-render-plugin/` — walkthrough de cómo renderizar un `openapi.yaml` dentro del sitio TechDocs.
- **`activities/`** — dos actividades independientes:
  - `01-add-techdocs-to-capstone/` — crear el sitio TechDocs del capstone (mkdocs.yml + docs/{index,adr,runbook,api}.md + catalog-info.yaml anotado). Validador estructural + build local opcional si `mkdocs` está disponible.
  - `02-docs-minimum-standard-adr/` — redactar el ADR que define el estándar mínimo de docs por servicio para la organización. (independiente)
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el modelo centralized escala y el in-situ no. Distinguir `mkdocs.yml` (configuración del sitio) de `catalog-info.yaml` (metadata del entity) y la anotación que los une. |
| Operativa | Crear un sitio MkDocs con `techdocs-core`, buildearlo localmente con `--strict`, y declararlo en Backstage vía `backstage.io/techdocs-ref: dir:.`. |
| Arquitectónica | Diseñar el pipeline CI de publicación (builder job → S3/GCS) con credenciales OIDC. Justificar un estándar mínimo de docs defendible para una organización. |

## Criterios de evaluación

- Puedes explicar `in-situ` vs `centralized` sin confundir "render" con "serve".
- Puedes nombrar al menos 3 archivos obligatorios en el sitio TechDocs del capstone (README/index, ADR, runbook, API ref).
- Puedes decir qué anotación conecta `catalog-info.yaml` con el sitio MkDocs y qué valores admite.
- Entregas las dos actividades con sus validadores estructurales en verde.

## Entregables

- Capstone con sitio TechDocs publicable (sale de `01-add-techdocs-to-capstone`).
- ADR del estándar mínimo de documentación (sale de `02-docs-minimum-standard-adr`).

## Siguiente módulo

→ `plat-08-plugins-ecosystem-and-custom-plugin` — plugins Backstage para capturar contexto operativo (K8s, Argo CD, GH Actions) y escribir uno propio.
