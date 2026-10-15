# Recursos — gha-04

## Documentación oficial de GitHub Actions

- **Using workflows — `uses` syntax**. <https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsuses>
- **Finding and customizing actions**. <https://docs.github.com/en/actions/learn-github-actions/finding-and-customizing-actions>
- **About custom actions** (JS / Docker / composite). <https://docs.github.com/en/actions/creating-actions/about-custom-actions>
- **Metadata syntax `action.yml`**. <https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions>
- **Security hardening for GitHub Actions**. <https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions>
- **Using third-party actions securely**. <https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions>
- **GitHub Marketplace**. <https://github.com/marketplace?type=actions>

## Actions oficiales mencionadas

- `actions/checkout` — <https://github.com/actions/checkout>
- `actions/setup-python` — <https://github.com/actions/setup-python>
- `actions/setup-node` — <https://github.com/actions/setup-node>
- `actions/setup-go` — <https://github.com/actions/setup-go>
- `actions/upload-artifact` — <https://github.com/actions/upload-artifact>
- `actions/download-artifact` — <https://github.com/actions/download-artifact>
- `actions/cache` — <https://github.com/actions/cache>

## Dependabot

- **Configuration options for the `dependabot.yml` file**. <https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file>
- **Keeping your actions up to date with Dependabot**. <https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot>
- `package-ecosystem: github-actions` ejemplos. <https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#package-ecosystem>

## Herramientas de pinning / audit

- **actionlint** — linter oficial de workflows. <https://github.com/rhysd/actionlint>
- **pinact** — reescribe `@tag` → `@SHA + # vX.Y.Z`. <https://github.com/suzuki-shunsuke/pinact>
- **ratchet** — pin + rotate SHAs automáticamente. <https://github.com/sethvargo/ratchet>
- **frizbee** — resuelve y pin a SHAs (de Stacklok). <https://github.com/stacklok/frizbee>
- **zizmor** — static-analysis de workflows GHA (encuentra "unpinned", `pull_request_target` peligroso, etc). <https://github.com/woodruffw/zizmor>
- **StepSecurity Harden Runner** — runtime security. <https://github.com/step-security/harden-runner>

## Incidentes y lecturas

- **tj-actions/changed-files — compromiso de marzo 2025**: resumen en GHSA. <https://github.com/advisories> (buscar `tj-actions/changed-files`).
- **GitHub Security Lab blog**. <https://securitylab.github.com/>
- **OpenSSF — Scorecard** (incluye `Pinned-Dependencies`). <https://github.com/ossf/scorecard>
- **"Keeping your GitHub Actions and workflows secure" (serie Palo Alto Unit42 / Legit Security)**. Buscar los posts recientes del año en curso.

## Comandos de referencia

```bash
# Resolver tag → SHA sin auth
git ls-remote https://github.com/<owner>/<repo>.git refs/tags/<tag>
git ls-remote https://github.com/<owner>/<repo>.git 'refs/tags/<tag>^{}'   # dereferencia

# Con gh
gh api repos/<owner>/<repo>/git/refs/tags/<tag> --jq '.object.sha'

# Lint
actionlint .github/workflows/*.yml

# Encontrar `uses:` no pinneadas (regex rápida)
grep -rhnE '^\s*-?\s*uses:\s+[^@]+@[^0-9a-f]' .github/workflows/
grep -rhnE '^\s*-?\s*uses:\s+[^@]+@[0-9a-f]{1,39}([^0-9a-f]|$)' .github/workflows/
```

## Alternativas

- **GitLab CI/CD** — `include:` también permite pin a SHA. <https://docs.gitlab.com/ee/ci/yaml/includes.html>
- **CircleCI orbs** — versionado semver, pinneable. <https://circleci.com/docs/orb-concepts/>
- **Buildkite plugins** — también se pueden pin a SHA. <https://buildkite.com/docs/plugins>

## Convenciones

- **Semantic Versioning 2.0.0**. <https://semver.org/>
- **OpenSSF Scorecard — Pinned-Dependencies check**. <https://github.com/ossf/scorecard/blob/main/docs/checks.md#pinned-dependencies>
