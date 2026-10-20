# REFERENCE — gl-01-01-explore-gitlab-com

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte. Las rutas UI pueden cambiar entre releases mensuales; valida contra la UI vigente.

---

# Cheatsheet personal — GHA ↔ GitLab (gl-01)

## 1. Mapping GHA ↔ GitLab

| GitHub Actions | GitLab | Nota |
|----------------|--------|------|
| **workflow** (`.github/workflows/*.yml`) | **pipeline** (un `.gitlab-ci.yml` por project; divisible con `include:`) | GitLab tiene un archivo canónico. Un pipeline por commit; stages → jobs. |
| **job** | **job** | Mismo concepto. GitLab exige `stage:` o `needs:`. |
| `strategy.matrix` | `parallel: matrix:` | Variables inyectadas; `CI_NODE_INDEX` / `CI_NODE_TOTAL`. |
| `needs: [other]` | `needs: [other]` | Convierte el pipeline en DAG. |
| `secrets.FOO` / `vars.FOO` | `$FOO` con flags `protected`/`masked` | Niveles: Instance / Group / Project / Environment / Pipeline. |
| OIDC `id-token: write` | `id_tokens:` por job | Claims distintas: `project_path`, `namespace_path`, `ref_type`, `ref`, `environment`. |
| pull request (PR) | **merge request (MR)** | `CI_MERGE_REQUEST_IID`, `$CI_PIPELINE_SOURCE == "merge_request_event"`. |
| organization | **Group** | Subgroups anidables, no existentes en GitHub. |
| reusable workflow / composite action | **CI/CD Component** (`include: - component: ...`) o `extends:` | Components son el patrón moderno con `spec:inputs:`. |
| environment | `environment:` por job (`name`, `url`, `action`, `auto_stop_in`) | Review Apps nativas por MR. |
| required workflow (Enterprise) | **Compliance Pipeline** (Ultimate) | Mismo propósito, otro producto. |
| GitHub-hosted runners | **Shared / Instance Runners** | GitLab también tiene Group Runners y Project Runners. |
| GHAS | **Ultimate** (scanners nativos, dashboard) | Comparación realista en seguridad. |

## 2. Jerarquía y ubicación en gitlab.com

```
Instance (gitlab.com | Self-Managed CE/EE | Dedicated)
└── Group (p. ej. "acme")
    ├── Subgroup (p. ej. "acme/platform")
    │   └── Project
    └── Project
```

- **Group** es la unidad de reuso: variables, runners, templates (`include:project:`), Catalog, permisos.
- **Subgroup** hereda y puede añadir. Se anida en varios niveles.
- **Project** = repo en GitHub.
- Permisos heredan hacia abajo; un Project puede *añadir* permiso (ampliar) pero no *reducir* el heredado para principales que ya lo tienen.

## 3. Pantallas clave

| Qué | Dónde (ruta UI, puede variar entre releases) |
|-----|---------------------------------------------|
| Group — General Settings | Group → Settings → General |
| **Group Variables** | Group → Settings → CI/CD → Variables (expand) |
| **Group Runners** | Group → Build → Runners (en Group); alt: Group → Settings → CI/CD → Runners |
| Group — Compliance Framework | Group → Settings → General → Compliance frameworks (Ultimate) |
| Project — General | Project → Settings → General |
| **Project Variables** | Project → Settings → CI/CD → Variables (expand) |
| Project — Pipelines config file | Project → Settings → CI/CD → General pipelines → Pipeline configuration file |
| **Protected Branches / Tags** | Project → Settings → Repository → Protected branches / Protected tags |
| **Pipelines** | Project → Build → Pipelines |
| **Jobs** | Project → Build → Jobs |
| Artifacts | Project → Build → Artifacts |
| **Environments** | Project → Deploy → Environments |
| Releases | Project → Deploy → Releases |
| Container Registry | Project → Deploy → Container Registry |
| Package Registry | Project → Deploy → Package Registry |
| Members (permisos) | Project → Manage → Members (o Group → Manage → Members) |
| Access Tokens | Project → Settings → Access Tokens |
| **CI/CD Catalog** público | `https://gitlab.com/explore/catalog` |

## 4. Variables predefinidas útiles (extra)

| Variable | Qué es |
|----------|--------|
| `CI_PIPELINE_SOURCE` | `push`, `merge_request_event`, `schedule`, `web`, ... |
| `CI_COMMIT_BRANCH` | Nombre de rama si existe (no en MR events). |
| `CI_MERGE_REQUEST_IID` | ID interno de la MR. |
| `CI_PROJECT_PATH` | `group/subgroup/project`. |
| `CI_COMMIT_SHA` | SHA del commit. |
| `CI_JOB_TOKEN` | Token para API scoped al job. |
| `CI_SERVER_FQDN` | `gitlab.com` en SaaS. |
| `CI_REGISTRY` / `CI_REGISTRY_IMAGE` | URL del Container Registry del Project. |

## 5. Dónde se verá cada tema en los próximos módulos

| Pantalla / concepto | Módulo |
|---------------------|--------|
| `.gitlab-ci.yml`, Runners | `gl-02` |
| Variables, Secrets, ID Tokens | `gl-03` |
| `rules:`, `workflow:`, DAG, matrix | `gl-04` |
| `include:`, `extends:`, Components | `gl-05` |
| Executors, DinD, Fleeting, K8s | `gl-06` |
| Environments, Review Apps, Agent K8s | `gl-07` |
| Scanners, Registry, Supply chain | `gl-08` |
| Compliance, Governance, Audit | `gl-09` |
| Migración, Platform patterns | `gl-10` |
