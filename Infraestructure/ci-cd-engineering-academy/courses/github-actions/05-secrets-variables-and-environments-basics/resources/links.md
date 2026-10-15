# Recursos — gha-05

## Documentación oficial (GitHub)

- **Secrets en Actions (encrypted secrets)** — <https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions>
- **Variables en Actions** — <https://docs.github.com/en/actions/learn-github-actions/variables>
- **`GITHUB_TOKEN` (overview)** — <https://docs.github.com/en/actions/security-guides/automatic-token-authentication>
- **Permissions for the `GITHUB_TOKEN`** (lista completa de keys y qué permite cada una) — <https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs>
- **Environments en Actions** — <https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment>
- **Required reviewers, wait timers, deployment branches** — <https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment>
- **Reusable workflows — pasar secretos** — <https://docs.github.com/en/actions/using-workflows/reusing-workflows#passing-inputs-and-secrets-to-a-reusable-workflow>
- **Security hardening for GitHub Actions** (lectura obligada aunque se profundice en `gha-13`) — <https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions>

## Fundamento interno

- **GitHub Apps installation tokens** (lo que es el `GITHUB_TOKEN` por debajo) — <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app>
- **OIDC overview** (siguiente paso natural: eliminar secretos de larga vida; se profundiza en `gha-11`) — <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>

## Complementario

- **StepSecurity Harden-Runner** (defensa en profundidad, usada en `gha-13`) — <https://github.com/step-security/harden-runner>
- **Awesome Actions security** (listas curadas con incidentes y patrones) — buscar por título; verificar mantenimiento.

## Referencias históricas de incidentes (contexto para la lección 9)

- **`tj-actions/changed-files` (2025)** — ejemplo público de credential leak en cadena de supply chain de actions. Buscar postmortem y advisories oficiales.
- **GitHub blog "Changes to the default permissions of the `GITHUB_TOKEN`"** — artículo donde GitHub anuncia el cambio del default a `restricted` para orgs nuevas.

## Nota de verificación

Última verificación de enlaces: pendiente para Fase 4. Todos los enlaces son dominios oficiales (`docs.github.com`, `github.com`). Confirmar sintaxis vigente de `permissions:` y defaults organizacionales cuando se desarrolle el curso en producción (ver checklist Fase 4 del `ROADMAP.md` global).
