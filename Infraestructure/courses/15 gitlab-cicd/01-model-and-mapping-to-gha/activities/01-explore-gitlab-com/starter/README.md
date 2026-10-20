# Starter — gl-01-01-explore-gitlab-com

Esta actividad es **independiente** y de **lectura/anotación**: no hay código, ni pipeline, ni Project real que crear. Tu entregable es un cheatsheet Markdown.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-01-01
   cd /tmp/gl-01-01
   ```
3. Abre `gitlab.com` en el navegador y recorre, como visitante (sin login si prefieres):
   - Un Group público (`gitlab-org` o `gitlab-com`).
   - Un Subgroup del Group.
   - Un Project del Group.
   - Settings → CI/CD, Settings → Repository, Build → Pipelines, Deploy → Environments.
   - `https://gitlab.com/explore/catalog`.
4. Crea `CHEATSHEET.md` con tres secciones (ver §5.3 del README):
   - **1. Mapping GHA ↔ GitLab** (≥10 filas; nombra los 10 términos mínimos de §5.4).
   - **2. Jerarquía y ubicación**.
   - **3. Pantallas clave** (≥10 filas; incluye las 10 rutas mínimas de §5.4).
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/01-model-and-mapping-to-gha/activities/01-explore-gitlab-com/tests/validate.sh /tmp/gl-01-01
   ```
6. Compara tu cheatsheet con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura y presencia de términos, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

Puedes arrancar con esto y rellenar:

```markdown
# Cheatsheet personal — GHA ↔ GitLab (gl-01)

## 1. Mapping GHA ↔ GitLab

| GitHub Actions | GitLab | Nota |
|----------------|--------|------|
| workflow | pipeline | GitLab tiene un archivo canónico `.gitlab-ci.yml` |
| job | job | Idéntico |
| matrix | parallel: matrix: | Sintaxis distinta |
| needs | needs | Idéntico |
| secrets.X / vars.X | $X con flags protected/masked | Niveles Instance/Group/Project/Env/Pipeline |
| OIDC id-token | id_tokens: | Claims distintas |
| pull request | merge request (MR) | CI_MERGE_REQUEST_IID |
| organization | Group | Subgroups anidables |
| reusable workflow / composite | CI/CD Component o extends | |
| environment | environment: | Review Apps nativas |

## 2. Jerarquía y ubicación

- Instance (gitlab.com o Self-Managed) → Group → Subgroup → Project.
- Settings heredan hacia abajo; Group Variables/Runners visibles desde Projects descendientes.

## 3. Pantallas clave

| Qué | Dónde (ruta UI) |
|-----|-----------------|
| Group Variables | Group → Settings → CI/CD → Variables |
| Group Runners | Group → Settings → CI/CD → Runners |
| Project Variables | Project → Settings → CI/CD → Variables |
| Protected Branches | Project → Settings → Repository → Protected branches |
| Environments | Project → Deploy → Environments |
| Pipelines | Project → Build → Pipelines |
| Jobs | Project → Build → Jobs |
| CI/CD Catalog | https://gitlab.com/explore/catalog |
| Repository (code) | Project → Code |
| Settings generales | Project → Settings → General |
```
