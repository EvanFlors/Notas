# Example 01 — MkDocs site skeleton con `techdocs-core`

Este ejemplo es el **esqueleto mínimo ejecutable** de un sitio TechDocs: un `mkdocs.yml`, cuatro páginas Markdown, y un `catalog-info.yaml` que lo apunta.

## Qué demuestra

- Estructura canónica de un repo con TechDocs: `/docs/*.md` + `mkdocs.yml` + `catalog-info.yaml`.
- La anotación `backstage.io/techdocs-ref: dir:.` que conecta el entity con el sitio.
- Uso del bundle oficial `mkdocs-techdocs-core` (plugins y extensiones ya configurados).
- Un `nav` explícito, admonitions, un diagrama Mermaid y un bloque de código resaltado.

## Archivos

```
.
├── README.md            (este archivo)
├── mkdocs.yml           (config del sitio)
├── catalog-info.yaml    (entity Backstage que apunta al sitio)
└── docs/
    ├── index.md
    ├── adr/0001-use-techdocs.md
    ├── runbook/incident-500s.md
    └── api/overview.md
```

## `mkdocs.yml`

```yaml
site_name: Example Service
docs_dir: docs

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
  - pymdownx.highlight
  - pymdownx.inlinehilite
  - toc:
      permalink: true

nav:
  - Home: index.md
  - ADRs:
      - "0001 — Use TechDocs": adr/0001-use-techdocs.md
  - Runbooks:
      - "Incident — 5xx surge": runbook/incident-500s.md
  - API:
      - Overview: api/overview.md
```

## `catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: example-service
  description: Minimal TechDocs skeleton (demo).
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: example-org/example-service
spec:
  type: service
  lifecycle: experimental
  owner: team-platform
  system: example-system
```

El valor **`dir:.`** significa "el `mkdocs.yml` está en la raíz de este repo". Alternativas:

- `dir:docs-site` — subcarpeta.
- `url:https://github.com/other-org/docs-repo/tree/main` — repo externo (útil para docs "de equipo" fuera del repo del servicio; en general evitarlo salvo que haya justificación clara).

## Cómo ejecutar localmente

Requiere Python 3.9+ y `pip`. No requiere Docker ni Backstage.

```bash
pip install mkdocs mkdocs-techdocs-core
cd <ruta-al-example>
mkdocs build --strict        # falla si hay links rotos
mkdocs serve                  # http://127.0.0.1:8000
```

El flag `--strict` es el que debe correrse en CI: convierte warnings (link roto a página inexistente, nav apuntando a archivo que no existe) en errores.

## Qué observar

- Las admonitions (`!!! note`, `!!! warning`) renderizan como bloques coloreados — vienen de `pymdownx` incluido en `techdocs-core`.
- El bloque ` ```mermaid` del `index.md` se renderiza como diagrama vectorial — viene de `mermaid2` incluido en `techdocs-core`.
- Enlaces internos `[foo](adr/0001-use-techdocs.md)` resuelven en `--strict` solo si el archivo existe.
- El sidebar refleja el `nav:` del `mkdocs.yml` 1:1.

## Siguiente

Compara con `02-techdocs-centralized-s3/` (el mismo sitio, pero publicado a S3 vía pipeline CI).
