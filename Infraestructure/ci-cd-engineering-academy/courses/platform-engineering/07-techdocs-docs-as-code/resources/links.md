# Recursos — plat-07-techdocs-docs-as-code

## Oficial

- [Backstage TechDocs — documentación oficial](https://backstage.io/docs/features/techdocs/)
- [TechDocs architecture (basic vs recommended)](https://backstage.io/docs/features/techdocs/architecture)
- [`@techdocs/cli` — CLI oficial](https://github.com/backstage/techdocs-cli)
- [`mkdocs-techdocs-core` — bundle de plugins MkDocs](https://github.com/backstage/mkdocs-techdocs-core)
- [TechDocs — publishing to AWS S3 / GCS / Azure](https://backstage.io/docs/features/techdocs/configuration)
- [`app-config.yaml` — sección `techdocs`](https://backstage.io/docs/features/techdocs/configuration)
- [MkDocs — core docs](https://www.mkdocs.org/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)

## Plugins MkDocs útiles

- [`mkdocs-render-swagger-plugin`](https://pypi.org/project/mkdocs-render-swagger-plugin/) — embebe Swagger UI dentro del sitio.
- [`mkdocs-mermaid2-plugin`](https://github.com/fralau/mkdocs-mermaid2-plugin) — diagramas Mermaid.
- [`mkdocs-git-revision-date-localized-plugin`](https://github.com/timvink/mkdocs-git-revision-date-localized-plugin) — "última modificación" por commit.
- [`mkdocs-awesome-pages-plugin`](https://github.com/lukasgeiter/mkdocs-awesome-pages-plugin) — nav flexible.

## Lecturas

- Spotify engineering blog — artículos originales sobre Backstage y por qué nació TechDocs.
- "Docs-like-code" — Anne Gentle (libro, concepto previo a TechDocs pero influencia directa).
- ThoughtWorks Tech Radar — entradas sobre "docs as code" y TechDocs.

## Referencia a módulos del programa

- `plat-04` — Backstage architecture y `app-config.yaml`.
- `plat-05` — software catalog y annotations.
- `plat-06` — templates: scaffolder puede sembrar `mkdocs.yml` + `docs/` automáticamente.
- Curso `github-actions` — pipeline CI con OIDC federado para `techdocs-cli publish`.
- Curso `aws` / `gcp` — IAM / Workload Identity para los buckets de TechDocs.
