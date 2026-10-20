# Recursos — gha-07

## Documentación oficial de GitHub

- **Caching dependencies to speed up workflows**. <https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows>
- **Storing and sharing data from a workflow**. <https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow>
- **Workflow syntax — `jobs.<id>.needs`**. <https://docs.github.com/actions/writing-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds>
- **Expressions — `hashFiles`**. <https://docs.github.com/actions/learn-github-actions/expressions#hashfiles>
- **Contexts — `runner`**. <https://docs.github.com/actions/learn-github-actions/contexts#runner-context>

## Actions oficiales (código y README)

- **`actions/cache`** — <https://github.com/actions/cache>
  - Advanced usage and examples por ecosistema: <https://github.com/actions/cache/blob/main/examples.md>
  - Restore-only action: <https://github.com/actions/cache/tree/main/restore>
- **`actions/upload-artifact`** v4 — <https://github.com/actions/upload-artifact>
  - **Migration guide v3 → v4**: <https://github.com/actions/upload-artifact/blob/main/docs/MIGRATION.md>
- **`actions/download-artifact`** v4 — <https://github.com/actions/download-artifact>
- **`actions/setup-python`** (sección *Caching packages dependencies*) — <https://github.com/actions/setup-python#caching-packages-dependencies>
- **`actions/setup-node`** (`cache:` integrada) — <https://github.com/actions/setup-node#caching-global-packages-data>

## Anuncios y notas de release relevantes

- Anuncio v4 de artifact actions (febrero 2024). <https://github.blog/changelog/2024-02-12-get-started-with-v4-of-github-actions-artifacts/>
- Deprecación de v1/v2/v3 (sunset junio 2024). <https://github.blog/changelog/2024-04-16-deprecation-notice-v1-and-v2-of-the-artifact-actions/>

## Operación / observabilidad

- **GitHub CLI `gh cache`** (`list`, `delete`). <https://cli.github.com/manual/gh_cache>
- UI de cachés por repo: `https://github.com/<owner>/<repo>/actions/caches`.

## Lecturas complementarias

- "GitHub Actions cache hit/miss debugging" — explicación de scoping por branch y restore-keys. <https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows#matching-a-cache-key>
- "Reducing GitHub Actions bill" — patrones comunes de optimización de caché. (Blog de GitHub) <https://github.blog/>
- `pip` caching layout. <https://pip.pypa.io/en/stable/topics/caching/>

## Herramientas complementarias

- **`actionlint`** — linter de workflows (detecta errores de sintaxis y expresiones). <https://github.com/rhysd/actionlint>
- **`act`** — ejecutor local de workflows (útil para iterar sin pushear). <https://github.com/nektos/act>
