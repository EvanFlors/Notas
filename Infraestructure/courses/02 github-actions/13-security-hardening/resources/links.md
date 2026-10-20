# Recursos — gha-13 Security hardening

## Guías oficiales de GitHub

- **Security hardening for GitHub Actions** (la guía canónica). <https://docs.github.com/actions/security-guides/security-hardening-for-github-actions>
- **Security hardening with OpenID Connect**. <https://docs.github.com/actions/deployment/security-hardening-your-deployments>
- **Automatic token authentication (`GITHUB_TOKEN`)**. <https://docs.github.com/actions/security-guides/automatic-token-authentication>
- **Assigning permissions to jobs**. <https://docs.github.com/actions/using-jobs/assigning-permissions-to-jobs>
- **Events that trigger workflows → `pull_request_target`**. <https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#pull_request_target>
- **Approving workflow runs from public forks**. <https://docs.github.com/actions/managing-workflow-runs/approving-workflow-runs-from-public-forks>
- **Choosing when a workflow runs for forked PRs (settings)**. <https://docs.github.com/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization>

## Dependabot para actions

- **Configuring Dependabot** (overview). <https://docs.github.com/code-security/dependabot>
- **`dependabot.yml` reference** (incluye `package-ecosystem: github-actions`). <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file>
- **Grouping Dependabot updates**. <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file#groups>

## GitHub Security Lab — research y post-mortems

- **Keeping your GitHub Actions and workflows secure (untrusted input)**. <https://securitylab.github.com/research/github-actions-untrusted-input/>
- **Preventing pwn requests**. <https://securitylab.github.com/research/github-actions-preventing-pwn-requests/>
- **How to review a GitHub Actions workflow (threat model)**. <https://securitylab.github.com/research/github-actions-building-blocks/>

## Incidentes públicos (lectura obligatoria antes de auditar)

- **`tj-actions/changed-files` compromise (marzo 2025)** — advisory + post-mortems de StepSecurity y Semgrep. Buscar: `tj-actions changed-files CVE 2025`.
- **Codecov bash uploader (abril 2021)** — post-mortem Codecov. <https://about.codecov.io/security-update/>
- **Dependabot token leak (septiembre 2023)** — GitHub security advisory.
- **"Pwnrequest" series** por Teddy Katz (GitHub Security Lab). Varios reportes afectando Microsoft, GitHub, grandes OSS.

## Herramientas

- **StepSecurity `harden-runner`** — egress control runtime en runners. <https://github.com/step-security/harden-runner>
- **StepSecurity Secure Workflows** — scanner estático de workflows. <https://github.com/step-security/secure-workflows>
- **`actionlint`** — linter sintáctico de workflows (detecta algunos anti-patrones). <https://github.com/rhysd/actionlint>
- **`zizmor`** — security linter específico para GHA (detecta script injection, pin issues, `pull_request_target` risks). <https://github.com/woodruffw/zizmor>
- **`pinact`** — convierte `uses: owner/repo@vX` a `uses: owner/repo@<SHA>` masivamente. <https://github.com/suzuki-shunsuke/pinact>
- **CodeQL action** — hay queries específicas para GHA (`actions/pull-request-target-script-injection`). <https://github.com/github/codeql-action>

## Especificaciones y estándares

- **OWASP CICD-SEC-05: Insufficient PBAC** (Pipeline-Based Access Controls). <https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC>
- **OWASP CICD-SEC-04: Poisoned Pipeline Execution** (el patrón `pull_request_target` encaja aquí). <https://owasp.org/www-project-top-10-ci-cd-security-risks/>
- **SLSA v1.0** (relacionado, se cubre en `gha-14`). <https://slsa.dev/spec/v1.0/>

## Lecturas de referencia

- *GitHub Actions Security Best Practices* — compendio de StepSecurity. <https://www.stepsecurity.io/blog>
- *Supply Chain Security for GitHub Actions* — presentaciones de GitHub Universe (buscar año en curso).
- *Common CI/CD Pipeline Attacks* — Palo Alto Unit 42 / otros vendors.

## Para auditar workflows ajenos

```bash
# Ver todos los workflows del repo
gh api /repos/OWNER/REPO/actions/workflows --jq '.workflows[] | {name, path, state}'

# Ver el bloque permissions efectivo a nivel repo
gh api /repos/OWNER/REPO/actions/permissions/workflow

# Listar secrets definidos (nombres, no valores)
gh api /repos/OWNER/REPO/actions/secrets

# ¿Hay dependabot.yml?
gh api /repos/OWNER/REPO/contents/.github/dependabot.yml --jq .content | base64 -d
```

Checklist rápida (grep sobre los workflows checkouteados localmente):

```bash
# Actions sin pin a SHA
grep -rnE 'uses: [^@]+@(v[0-9]+(\.[0-9]+)*|main|master|HEAD)$' .github/workflows/

# Script injection candidates
grep -rnE 'run:.*\$\{\{ *github\.event' .github/workflows/

# pull_request_target usage
grep -rln 'pull_request_target' .github/workflows/

# permissions: write-all
grep -rln 'permissions: write-all\|permissions: *write-all' .github/workflows/
```
