# Ejemplo 01 — Jenkins vs GitHub Actions vs GitLab CI vs Argo Workflows

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria **las dimensiones** por las que se comparan plataformas CI/CD en 2026 y por qué cada una gana o pierde en cada eje.

## 1. Marco de comparación

Comparar herramientas CI/CD "en general" no sirve. Hay que fijar **dimensiones** y evaluar por dimensión. Las que importan a nivel empresa:

1. **Modelo de ejecución** (dónde corre el código del pipeline).
2. **Pipeline-as-code** (dónde y cómo se define).
3. **Reutilización** (cómo se evita duplicación).
4. **Ecosistema** (plugins, actions, componentes, templates).
5. **Seguridad** (CVEs, credenciales, OIDC).
6. **Operación** (quién mantiene qué, backup, upgrade).
7. **DX** (editor, autocomplete, previsualización, PR status).
8. **Costo total** (software + personas + infra).
9. **Encaje organizacional** (brownfield vs greenfield, cloud vs on-prem).

## 2. Tabla ampliada

| # | Dimensión | Jenkins (moderno) | GitHub Actions | GitLab CI | Argo Workflows |
|---|-----------|-------------------|----------------|-----------|----------------|
| 1 | Modelo | Controller central + agents (SSH, Docker, K8s). | Runner-centric (hosted o self-hosted, ARC en K8s). | Runner-centric (shared o self-managed). | Workflow como CRD; ejecuta en pods del cluster. |
| 2 | Pipeline-as-code | `Jenkinsfile` en repo (Declarative o Scripted, Groovy). | `.github/workflows/*.yml` (YAML + expressions). | `.gitlab-ci.yml` (YAML + `include`). | Workflow CRDs en YAML; parámetros, DAG, steps. |
| 3 | Reutilización | **Shared Libraries** (Groovy en repo central, versionadas por tag). | **Reusable workflows + composite actions**. | **CI/CD Components + `include` por URL/ref**. | **WorkflowTemplate / ClusterWorkflowTemplate**. |
| 4 | Ecosistema | ~1800 plugins (potente y arriesgado). | Marketplace amplio (algunas acciones oficiales, muchas comunidad). | Catálogo oficial de componentes + ecosistema propio. | Nativo K8s (recursos K8s como "integraciones"). |
| 5 | Seguridad: CVEs | Feed activo; mayoría en plugins; requiere disciplina. | OIDC federation nativo; dependabot; permisos granulares. | OIDC a clouds; protected branches integradas. | RBAC K8s nativo; service accounts por workflow. |
| 6 | Seguridad: credenciales | Credentials store + Vault/AWS SM/AKV plugin. | OIDC a AWS/GCP/Azure (sin keys). | OIDC a clouds; variables protegidas. | External Secrets o K8s secrets. |
| 7 | Operación: controller | SPOF por diseño; HA solo con CloudBees o diseño activo-pasivo manual. | SaaS (0 operación) o GHES on-prem (operación GHES). | SaaS o self-managed (operación GitLab). | Operar Argo controllers + cluster K8s. |
| 8 | Operación: agents | Permanentes/efímeros; K8s plugin recomendado. | Hosted (SaaS) o self-hosted via ARC. | Shared runners o self-managed. | Pods en K8s. |
| 9 | Operación: upgrade | LTS cada ~12 semanas; plugins asincrónicos. | SaaS: continuo. GHES: trimestral. | SaaS continuo; self-managed trimestral. | Chart Helm; cadencia según equipo. |
| 10 | DX: editor | Groovy en IDE; `jenkins-cli declarative-linter` para lint. | Editor web, autocomplete, VS Code extension oficial. | Editor web, lint integrado en MR. | YAML + argo CLI; sin editor web nativo. |
| 11 | DX: feedback en PR | Via plugin (GitHub, GitLab, Bitbucket); funciona pero tosco. | Nativo (status checks, annotations). | Nativo (pipeline en MR). | Via plugin de SCM; menos pulido. |
| 12 | Costo software | Gratis (OSS); CloudBees paga. | Minutos gratis + pay-per-minute. | Minutos gratis por tier. | Gratis (OSS). |
| 13 | Costo operación | Alto. | Bajo (SaaS) / medio (self-hosted). | Bajo (SaaS) / medio (self-managed). | Medio-alto (requiere K8s expertise). |
| 14 | Encaje: brownfield | Perfecto. | Posible con migración. | Posible con migración. | Rara vez (nicho K8s puro). |
| 15 | Encaje: greenfield GH | Innecesario. | **Default**. | - | Para workloads K8s complementarios. |
| 16 | Encaje: greenfield GL | Innecesario. | - | **Default**. | Complementario. |
| 17 | Encaje: on-prem / air-gapped | **Fuerte**. | GHES posible. | Self-managed posible. | Posible si el cluster está on-prem. |
| 18 | Encaje: ML / data / batch K8s | Posible, no idiomático. | Posible via runners self-hosted. | Posible. | **Idiomático**. |

## 3. Lectura por escenario

### Escenario A — Startup 15 personas, repos en GitHub, cero legacy

- **Ganador**: GitHub Actions. Sin discusión.
- **Jenkins**: no justificable.
- **Argo**: solo si aparecen workloads K8s de ML/data.

### Escenario B — Banco con 2000 jobs Jenkins y datacenter on-prem

- **Ganador a corto plazo**: Jenkins (bien operado, moderno).
- **Ganador a 3 años**: migración por olas a GitLab self-managed o GHES, dependiendo de dónde esté el SCM.
- Nunca "fuera Jenkins mañana".

### Escenario C — Plataforma ML interna sobre K8s multi-tenant

- **Ganador**: Argo Workflows (orquestar training/inference es su caso de uso).
- **CI de las apps que corren encima**: puede ser GHA.
- **Jenkins**: no encaja.

### Escenario D — Empresa de 300 personas con GitLab self-managed desde 2018

- **Ganador**: GitLab CI. Está integrado con el SCM que ya se usa y mantiene.
- **Jenkins paralelo**: solo si hay pipelines que **no** pueden expresarse en GitLab CI.

## 4. Qué llevarte

- La herramienta "correcta" depende de **dimensiones medibles**, no de preferencia.
- **Nunca** se compara "en abstracto". Siempre contra un contexto (SCM, equipo, legacy, compliance, workloads).
- La misma empresa puede acabar con **más de una** herramienta (Jenkins para legacy + GHA para greenfield + Argo para K8s), y eso **no es un fracaso**.
