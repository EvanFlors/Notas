# Curso: GitLab CI/CD

Roadmap especializado #15. Alternativa a **GitHub Actions**. Framing explícito: **curso comparativo / diferencial**, no reimplementación completa. Asume competencias del curso **github-actions** (modelo mental de CI/CD, pipeline as code, runners, OIDC, secrets, environments, supply chain). El objetivo es *transferir* y marcar las divergencias conceptuales, de UX y de ecosistema que importan.

## 1. Introducción

### Qué es

**GitLab** es una **plataforma única** que combina:

- **SCM** (Git hosting, equivalente a GitHub).
- **Issue tracking** y **project management**.
- **CI/CD** integrado (equivalente a GitHub Actions, con otra sintaxis y modelo de runners).
- **Container Registry** y **Package Registry** (OCI + npm/PyPI/Maven/Composer/…).
- **Pages** (sitios estáticos).
- **Security scanners nativos** (SAST, DAST, SCA, Secret Detection, Container Scanning, IaC Scanning, Fuzz) sin acción separada del marketplace.
- **Compliance pipelines** y **approval rules** nativos.
- **Observability** (metrics, logs, tracing — en progreso) y **AI-assisted** (Duo).

Contrasta con el ecosistema **GitHub + GitHub Actions + GitHub Advanced Security + GHCR + Packages**: funcionalmente similar, pero GitLab lo integra en un solo producto SaaS **y** uno self-hosted ("GitLab Self-Managed" / "GitLab Dedicated"), lo que lo convierte en opción frecuente en orgs regulated/air-gapped.

### Historia (síntesis)

- **2011** — GitLab se lanza como clon self-hosted de GitHub (Ruby on Rails).
- **2014** — Oferta hosted (`gitlab.com`).
- **2015** — **GitLab CI** se integra (anteriormente proyecto separado); `.gitlab-ci.yml` nace como convención.
- **2017+** — Auto DevOps, Kubernetes integration, Container Registry.
- **2019+** — Security scanners nativos; **GitOps** (Agent for Kubernetes).
- **2021+** — Workflow rules, DAG pipelines con `needs:`, OIDC a clouds.
- **2023+** — **CI/CD Components** (reemplazo moderno de templates `include:remote:` para reuso), **Fleeting** autoscaler para runners (sucesor del `docker-machine` executor), observabilidad GitLab.
- **2024+** — Soporte más fuerte a **SLSA attestations**, mejor integración de secrets con cloud providers vía OIDC, **GitLab Duo** (AI).

### Problemas que resuelve

- Mismo problema que GHA: pipeline as code, triggers por evento, runners, artifact management, deployments gates.
- **Monolítica integrada**: no se necesitan integrar GitHub + CI vendor + Registry vendor + Security vendor — todo en uno.
- **Self-hosted real**: muchas orgs regulated requieren CI *dentro* de la red (GitLab Self-Managed cumple; GitHub Enterprise Server existe pero con ecosistema Actions más limitado).
- **Observabilidad y Security** integradas en el mismo portal — buena DX para orgs grandes con compliance.

### Casos de uso

- Mismos que GHA (CI, CD, releases, scheduled, event-driven), con integración más densa dentro del portal.
- **Compliance pipelines obligatorios** aplicados por policy a muchos repos.
- **Review Apps** (preview environments por MR) — concepto nativo.
- GitOps a Kubernetes vía **GitLab Agent for Kubernetes** (alternativa integrada a Argo CD/Flux desde la perspectiva GitLab, aunque Argo CD sigue siendo más adoptado como estándar).

### Arquitectura general y mapping a GitHub Actions

```
GitLab                              GitHub + GHA
──────                              ─────────────
Group / Subgroup / Project       ≈  Organization / Repository
.gitlab-ci.yml                   ≈  .github/workflows/*.yml
pipeline                         ≈  workflow run
job                              ≈  job (step individual del flow)
stage                            ≈  (sin análogo directo; se simula con needs)
runner (shared/group/project)    ≈  runner (hosted / self-hosted / larger)
include: + extends:              ≈  reusable workflows / composite actions
CI/CD Components                 ≈  reusable workflows publicados como Actions
rules: / workflow:               ≈  on:, if:
needs:                           ≈  needs:
parallel: + matrix               ≈  strategy.matrix
variables (project/group/inst.)  ≈  secrets/vars (repo/env/org)
Environments + Deployments       ≈  Environments + Deployments
Review Apps (nativo)             ≈  PR previews (via patron, no nativo)
Protected branches + Approval    ≈  Branch protection rules + rulesets
Container Registry (OCI)         ≈  GHCR
Package Registry                 ≈  GitHub Packages
Security Dashboard               ≈  Code Scanning + Dependabot (via GHAS)
Compliance Pipelines             ≈  Required workflows / repository rules
GitLab Runner Operator (K8s)     ≈  ARC (Actions Runner Controller)
```

### Alternativas

- **GitHub Actions** (`courses/github-actions/`) — el "principal" del programa.
- **Jenkins** — motor universal, más viejo.
- **CircleCI, Buildkite, Drone, Tekton, Argo Workflows** — alternativas con enfoques distintos.
- Para orgs que ya tienen Jira/Bitbucket Cloud: **Bitbucket Pipelines**.
- Para orgs **Azure**: **Azure DevOps Pipelines**.

### Ventajas / limitaciones

**Ventajas**: integración todo-en-uno, UI consistente, security scanners sin ensamblaje, self-managed real para orgs regulated, GitLab Pages/Container Registry/Package Registry maduros.

**Limitaciones / riesgos**:
- **Ecosistema de "Actions"** más chico que el marketplace de GitHub — hay más librerías de la propia GitLab y menos de terceros.
- **Costos del plan** (Premium/Ultimate) incluyen features de seguridad y compliance que en GitHub están distribuidos (GHAS, Enterprise). Comparación de precio total requiere análisis real.
- **Documentación** amplia pero menos "googleable" que la de GHA.
- **Self-managed** añade operación: actualizaciones mensuales, backups, scaling.
- **Runners docker-in-docker** complican la vida (uso común, hay patrones de hardening).

### Relación con el programa

- **Curso diferencial**: asume el modelo mental del curso **github-actions**.
- Útil cuando la organización ya está en GitLab, cuando se requiere self-hosted por compliance, o cuando se quiere consolidar en una sola plataforma.
- Las piezas DevSecOps del programa (Trivy, cosign, Kyverno, OPA, SBOM, SLSA) son **portables** — se integran igual en GitLab CI que en GHA. El curso muestra el *cómo* por GitLab.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | **Curso `github-actions` completo o conocimiento equivalente de CI/CD moderno.** Curso **docker**. |
| Recomendados | Curso **kubernetes** ≥ Nivel 2 (para runners K8s y Review Apps). Curso **devsecops** ≥ Nivel 2 (para los scanners nativos). |
| Complementarios | Curso **argocd-gitops** (para contrastar con GitLab Agent for Kubernetes). |

## 3. Organización (4 niveles)

El curso tiene **10 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos diferenciales** (3): modelo GitLab + mapping a GHA, `.gitlab-ci.yml` + pipelines + runners, variables + secrets + protected contexts.
- **Nivel 2 — Intermedio** (3): rules/workflow/needs/DAG/parallel/matrix, reuso (`include` + `extends` + **CI/CD Components**), runners deep (shell/docker/k8s executor, Fleeting autoscaler, OIDC).
- **Nivel 3 — Avanzado** (2): environments + deployments + Review Apps + protected environments, security scanners nativos + Container/Package Registry + supply chain (SBOM/SLSA en GitLab).
- **Nivel 4 — Producción empresarial** (2): compliance pipelines + approval rules + governance a escala, migration patterns GHA↔GitLab + platform patterns (CI/CD Components catalog, inner-source).

## 4. Entregables del curso

- Repo GitLab del capstone con `.gitlab-ci.yml` equivalente al workflow GHA del curso previo.
- CI/CD Component propio publicado al **CI/CD Catalog** interno + consumido desde al menos 2 repos.
- Review Apps automáticas por MR + prod detrás de approval rule.
- Pipeline con Security Scanners habilitados y findings subiendo al Security Dashboard.
- Imagen OCI publicada a Container Registry con **SLSA attestation**.
- Pipeline GitLab CI → AWS vía OIDC sin credenciales de larga vida.
- ADR: cuándo elegir GitLab vs GitHub+GHA para una org dada.

## 5. Evaluación

- **Conceptual**: traducir fluidamente GHA ↔ GitLab; explicar stages vs needs vs DAG; cuándo usar CI/CD Component vs include vs extends; qué garantiza OIDC desde GitLab a cloud.
- **Operativa**: convertir un workflow GHA a `.gitlab-ci.yml`; levantar un runner K8s; configurar Review Apps + protected environment; habilitar y leer el Security Dashboard.
- **Arquitectónica**: ADR plataforma única (GitLab) vs ensamblaje (GitHub + marketplace + registry + vendors); política de self-hosted vs SaaS; estrategia de compliance pipelines.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial GitLab (`docs.gitlab.com`).
- Catálogo oficial de **CI/CD Components** (`gitlab.com/explore/catalog`).
- Documentación de **GitLab Runner** y **Fleeting** autoscaler.
- GitLab Agent for Kubernetes docs.
- Comparativa oficial GitLab vs GitHub (sesgada, útil para leer con reservas).
- Documentación DevSecOps GitLab (SAST/DAST/SCA/Fuzz/IaC/Container Scanning).
- GitLab release notes mensuales (releases cada mes 22).
