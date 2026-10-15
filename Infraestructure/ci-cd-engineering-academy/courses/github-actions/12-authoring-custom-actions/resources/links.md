# Recursos — gha-12

## Documentación oficial

- **Metadata syntax para `action.yml`**. <https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions>
- **Creating a composite action**. <https://docs.github.com/en/actions/creating-actions/creating-a-composite-action>
- **Creating a JavaScript action**. <https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action>
- **Creating a Docker container action**. <https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action>
- **Publishing actions in the Marketplace**. <https://docs.github.com/en/actions/creating-actions/publishing-actions-in-github-marketplace>
- **Setting exit codes para actions**. <https://docs.github.com/en/actions/creating-actions/setting-exit-codes-for-actions>
- **Dockerfile support para GHA**. <https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions>

## Toolkit `actions/toolkit`

- **Repo del toolkit**. <https://github.com/actions/toolkit>
- **`@actions/core`** — I/O con el runner. <https://github.com/actions/toolkit/tree/main/packages/core>
- **`@actions/github`** — cliente REST/GraphQL autenticado + contexto. <https://github.com/actions/toolkit/tree/main/packages/github>
- **`@actions/exec`** — ejecutar comandos capturando stdout/stderr. <https://github.com/actions/toolkit/tree/main/packages/exec>
- **`@actions/io`** — operaciones de filesystem portables. <https://github.com/actions/toolkit/tree/main/packages/io>
- **`@actions/http-client`**. <https://github.com/actions/toolkit/tree/main/packages/http-client>
- **`@actions/cache`** — API de caché programática. <https://github.com/actions/toolkit/tree/main/packages/cache>

## Compilación y bundling

- **`@vercel/ncc`** — bundle Node a single-file. <https://github.com/vercel/ncc>
- **TypeScript action template oficial**. <https://github.com/actions/typescript-action>
- **JavaScript action template oficial**. <https://github.com/actions/javascript-action>
- **Container action template oficial**. <https://github.com/actions/container-action>

## Patrones de reference

- **`actions/checkout`** — JS action canónica (lee cómo organizan `src/`, `dist/`, tests). <https://github.com/actions/checkout>
- **`actions/setup-node`** — JS action que mezcla toolkit + caching. <https://github.com/actions/setup-node>
- **`docker/build-push-action`** — Node action compleja con muchos inputs. <https://github.com/docker/build-push-action>

## Versionado y Marketplace

- **About actions versioning** (GitHub docs). <https://docs.github.com/en/actions/sharing-automations/creating-actions/about-custom-actions#using-release-management-for-actions>
- **Actions-related CVEs** — buscar "tj-actions/changed-files" (incidente marzo 2025). <https://github.com/advisories>
- **Dependabot — github-actions ecosystem**. <https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#package-ecosystem>

## Testing

- **`nektos/act`** — correr workflows localmente (útil para pruebas full-integration). <https://github.com/nektos/act>
- **`node --test`** — runner integrado desde Node 18. <https://nodejs.org/api/test.html>

## Herramientas complementarias

- **`actionlint`** — linter de workflows y actions. <https://github.com/rhysd/actionlint>
- **StepSecurity Harden-Runner** — defensa en profundidad para actions ajenas. <https://github.com/step-security/harden-runner>
