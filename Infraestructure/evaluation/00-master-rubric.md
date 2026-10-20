# Rúbrica maestra — matriz de competencias (17 cursos)

Esta matriz **no define** las competencias desde cero: las agrega. Cada competencia es la forma observable de algo que ya está en el `ROADMAP.md` del curso. Si una fila contradice al roadmap, el roadmap gana — abrir issue para reconciliar.

## Convenciones

- **Verbo + resultado observable**: "levantar", "justificar", "detectar y revertir", "producir". Nunca "entender" o "conocer".
- **Dimensión**: `conceptual` (explica el porqué), `operativa` (lo hace), `arquitectónica` (decide y justifica).
- **Peso**: suma 100 por curso. Las competencias con peso alto son **bloqueantes**: si quedan en 0, el curso no aprueba aunque el resto esté en 3.
- **Evidencia**: el artefacto o conducta que la defensa / portafolio / dashboard debe mostrar para dar la competencia por demostrada.

Niveles de la rúbrica: ver `README.md` de esta carpeta.

---

## 1. `git-and-github`

Referencia: `courses/git-and-github/ROADMAP.md`.

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| gh-c1 | Explicar el modelo de objetos de Git (blob/tree/commit/tag) frente a snapshots vs diffs | conceptual | 10 | Pregunta oral + diagrama |
| gh-c2 | Resolver un rebase conflictivo preservando historia revisable | operativa | 15 | Captura de `git log --oneline --graph` antes/después |
| gh-c3 | Diseñar branching + protección de rama alineado a trunk-based | arquitectónica | 15 | ADR en portafolio |
| gh-c4 | Firmar commits y tags, verificar firma en CI | operativa | 10 | Workflow + output de verificación |
| gh-c5 | Reescribir historia local sin romper historia compartida (`rebase -i`, `filter-repo`) | operativa | 10 | Repro + explicación del "cuándo no" |
| gh-c6 | Diseñar PR workflow con CODEOWNERS, required checks, merge queue | arquitectónica | 15 | Config repo + ADR |
| gh-c7 | Recuperar trabajo con `reflog` tras un `reset --hard` accidental | operativa | 10 | Demo en vivo |
| gh-c8 | Justificar monorepo vs polyrepo para un escenario dado | arquitectónica | 15 | ADR corto |

## 2. `github-actions`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| gha-c1 | Diferenciar runner hosted vs self-hosted y sus implicaciones de seguridad | conceptual | 10 | Pregunta oral |
| gha-c2 | Diseñar workflows con matriz, reusables (`workflow_call`) y composite actions | arquitectónica | 15 | Repo con 3 workflows |
| gha-c3 | Pin de actions por SHA + revisión de permisos del `GITHUB_TOKEN` | operativa | 15 | Diff mostrando pin + `permissions:` |
| gha-c4 | Usar OIDC a AWS/GCP/Azure sin secretos long-lived | operativa | 15 | Workflow + trust policy |
| gha-c5 | Cache y artifacts correctamente invalidados | operativa | 10 | Workflow + explicación de clave |
| gha-c6 | Environments con required reviewers y wait timer | operativa | 10 | Config environment |
| gha-c7 | Debuggear un workflow fallido con `ACTIONS_STEP_DEBUG` y re-run selectivo | operativa | 10 | Reproducir fallo + fix |
| gha-c8 | Justificar GitHub Actions vs Jenkins vs GitLab CI | arquitectónica | 15 | ADR |

## 3. `gitlab-cicd`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| gl-c1 | Explicar stages, jobs, needs y DAG pipelines | conceptual | 10 | Diagrama |
| gl-c2 | Diseñar pipeline parent/child y multi-project | arquitectónica | 15 | `.gitlab-ci.yml` modular |
| gl-c3 | Runners: elegir shell/docker/kubernetes y aislar | operativa | 15 | Config runner + ADR |
| gl-c4 | Variables protegidas, masked, environments y file vars | operativa | 10 | Pipeline + screenshot |
| gl-c5 | OIDC/JWT a cloud sin secretos permanentes | operativa | 15 | Pipeline + trust |
| gl-c6 | Review apps + environments dinámicos | operativa | 10 | URL por MR |
| gl-c7 | Cache vs artifacts, dependencies, needs:artifacts | operativa | 10 | Pipeline optimizado |
| gl-c8 | Compliance pipelines y pipeline policies | arquitectónica | 15 | Config central |

## 4. `jenkins`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| jk-c1 | Diferenciar Freestyle vs declarative vs scripted; cuándo cada uno | conceptual | 10 | Oral |
| jk-c2 | Escribir Jenkinsfile declarative con stages, parallel y post | operativa | 15 | Jenkinsfile en portafolio |
| jk-c3 | Shared libraries para desduplicar pipelines | arquitectónica | 15 | Lib + repo consumidor |
| jk-c4 | Credentials provider + Vault, nunca credenciales en texto | operativa | 15 | Config + Jenkinsfile |
| jk-c5 | Agents con labels, cloud agents (K8s/EC2), isolation | operativa | 10 | Cloud config |
| jk-c6 | Blue/green upgrade del controller y backup/restore | operativa | 15 | Runbook |
| jk-c7 | Justificar mantener Jenkins vs migrar a GHA/GitLab | arquitectónica | 20 | ADR |

## 5. `docker`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| dk-c1 | Explicar namespaces/cgroups/layers y qué NO aísla | conceptual | 10 | Oral + ejemplo |
| dk-c2 | Dockerfiles multi-stage, non-root, distroless cuando aplica | operativa | 15 | Dockerfile + `docker scout` |
| dk-c3 | Minimizar superficie: layers, cache, `.dockerignore` | operativa | 10 | Diff tamaños |
| dk-c4 | Compose para dev loop reproducible | operativa | 10 | `compose.yaml` |
| dk-c5 | Build con BuildKit, cache remoto, multi-arch | operativa | 15 | Script + manifests |
| dk-c6 | Imagen firmada (cosign) + SBOM adjunto | operativa | 15 | Attestations verificadas |
| dk-c7 | Registry: elegir, tag strategy, retention, immutable tags | arquitectónica | 15 | ADR + config |
| dk-c8 | Debuggear un container en producción sin shell | operativa | 10 | Procedure doc |

## 6. `kubernetes`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| k8-c1 | Explicar el loop controller/reconciliation y "desired vs actual" | conceptual | 10 | Oral |
| k8-c2 | Desplegar Deployment+Service+Ingress con probes y resources | operativa | 10 | Manifiesto en portafolio |
| k8-c3 | RBAC: diseñar Role/ClusterRole mínimos para una app | arquitectónica | 15 | YAML + justificación |
| k8-c4 | NetworkPolicies default-deny + reglas explícitas | operativa | 10 | YAML + test de bloqueo |
| k8-c5 | PodSecurity (restricted) y SecurityContext correcto | operativa | 10 | Manifest + violación esperada |
| k8-c6 | StatefulSets, PVC, StorageClass; cuándo evitarlos | arquitectónica | 10 | ADR |
| k8-c7 | Autoscaling: HPA + VPA + Cluster Autoscaler y sus límites | operativa | 10 | Config + métrica |
| k8-c8 | Debuggear un Pod `CrashLoopBackOff` metódicamente | operativa | 15 | Transcripción |
| k8-c9 | Diseñar multi-tenancy: namespaces, quotas, LimitRange | arquitectónica | 10 | ADR |

## 7. `helm`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| hl-c1 | Explicar release, revision, hooks, templating pipeline | conceptual | 10 | Oral |
| hl-c2 | Autoría de chart idiomático con `_helpers.tpl` y values schema | operativa | 20 | Chart en portafolio |
| hl-c3 | Umbrella charts vs subcharts; cuándo cada uno | arquitectónica | 15 | ADR |
| hl-c4 | `helm diff` + release strategy en CI | operativa | 15 | Pipeline |
| hl-c5 | Dependencias con `requirements`/`Chart.yaml`, lock y repos | operativa | 10 | Chart.lock |
| hl-c6 | Rollback seguro y post-render patches | operativa | 10 | Demo |
| hl-c7 | Helm vs Kustomize vs plain YAML — justificar elección | arquitectónica | 20 | ADR |

## 8. `argocd-gitops`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| ag-c1 | Explicar los 4 principios de OpenGitOps y detectar "GitOps-washing" | conceptual | 10 | Oral + ejemplo |
| ag-c2 | Diseñar separación repo de código vs repo de manifests | arquitectónica | 15 | ADR + 2 repos |
| ag-c3 | Application + Project + RBAC con blast radius acotado | operativa | 15 | Manifests |
| ag-c4 | ApplicationSets con generators para N clusters/envs | operativa | 10 | AppSet |
| ag-c5 | Sync waves, hooks y healthchecks custom | operativa | 10 | App + hooks |
| ag-c6 | Secrets en GitOps (SOPS/ESO/Sealed) — elegir y justificar | arquitectónica | 15 | ADR |
| ag-c7 | Progressive delivery con Argo Rollouts (canary/blue-green) con análisis | operativa | 15 | Rollout + AnalysisTemplate |
| ag-c8 | Multi-cluster bootstrap pattern (app-of-apps vs AppSet) | arquitectónica | 10 | ADR |

## 9. `terraform`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| tf-c1 | Modelo mental: desired state, dependency graph, state file | conceptual | 10 | Oral |
| tf-c2 | Autoría de módulo reutilizable con inputs/outputs/versions | operativa | 15 | Módulo publicado |
| tf-c3 | Remote backend con locking + state separation por env | arquitectónica | 15 | ADR + backend config |
| tf-c4 | Recuperar un state lock bloqueado sin corromper state | operativa | 10 | Runbook |
| tf-c5 | Workspaces vs directorios por env — justificar | arquitectónica | 15 | ADR |
| tf-c6 | Importar recursos existentes sin drift | operativa | 10 | Demo |
| tf-c7 | Policy-as-code (OPA/Sentinel/tfsec) en el pipeline | operativa | 10 | Pipeline + policy |
| tf-c8 | Refactor seguro con `moved {}` y plan revisable | operativa | 15 | Plan diff |

## 10. `ansible`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| an-c1 | Idempotencia: qué garantiza y qué no | conceptual | 15 | Oral + ejemplo roto |
| an-c2 | Roles + collections estructurados | operativa | 15 | Role en portafolio |
| an-c3 | Inventario dinámico (cloud) + grupos y host_vars | operativa | 10 | Inventory + playbook |
| an-c4 | Vault para secretos; rotación | operativa | 15 | Vault + rotación |
| an-c5 | Molecule tests para roles | operativa | 15 | CI con molecule |
| an-c6 | Ansible vs Terraform: cuándo cada uno (config vs provisioning) | arquitectónica | 15 | ADR |
| an-c7 | Debug: `-vvv`, check mode, step mode, start-at-task | operativa | 15 | Transcripción |

## 11. `aws`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| aw-c1 | IAM: identidad vs recurso, políticas, boundaries, SCPs | conceptual | 15 | Oral + policy |
| aw-c2 | VPC: subnets, routing, NAT, endpoints, flow logs | operativa | 10 | Diagrama + TF |
| aw-c3 | ECS/Fargate o EKS para una app contenerizada; justificar | arquitectónica | 15 | ADR |
| aw-c4 | ALB + WAF + ACM; headers y TLS | operativa | 10 | Config |
| aw-c5 | RDS con secrets rotation (Secrets Manager) | operativa | 10 | Setup + rotación demostrada |
| aw-c6 | Logs + métricas: CloudWatch + ADOT a observabilidad propia | operativa | 10 | Pipeline telemetría |
| aw-c7 | Multi-account landing zone (Control Tower / Organizations) | arquitectónica | 15 | ADR |
| aw-c8 | Rotar credenciales expuestas: runbook con tiempo | operativa | 15 | Runbook |

## 12. `gcp`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| gc-c1 | Jerarquía Organization / Folder / Project / Resource e IAM | conceptual | 15 | Oral |
| gc-c2 | Shared VPC vs peering vs PSC; cuándo cada uno | arquitectónica | 15 | ADR |
| gc-c3 | GKE Autopilot vs Standard; justificar | arquitectónica | 15 | ADR |
| gc-c4 | Cloud Run para servicio stateless; límites conocidos | operativa | 10 | Deploy + ADR |
| gc-c5 | Workload Identity Federation (sin service account keys) | operativa | 15 | Config + verificación |
| gc-c6 | Cloud SQL privado + IAM auth | operativa | 10 | Setup |
| gc-c7 | Logging/Monitoring/Trace integrados con OTel | operativa | 10 | Dashboard |
| gc-c8 | Organization Policies + VPC-SC | arquitectónica | 10 | Policies aplicadas |

## 13. `azure`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| az-c1 | Management Groups / Subscriptions / RGs y RBAC Entra ID | conceptual | 15 | Oral |
| az-c2 | AKS vs ACA (Container Apps) vs App Service | arquitectónica | 15 | ADR |
| az-c3 | VNet + NSG + Private Endpoints | operativa | 10 | Diagrama + TF |
| az-c4 | Managed Identities (system/user) sin secretos | operativa | 15 | Config |
| az-c5 | Key Vault + rotación + Pod Identity / Workload Identity | operativa | 15 | Rotación demostrada |
| az-c6 | Monitor + Log Analytics + Application Insights | operativa | 10 | Dashboard |
| az-c7 | Azure Policy + Landing Zone (ALZ) | arquitectónica | 10 | Policies |
| az-c8 | Hub-and-spoke vs vWAN; justificar | arquitectónica | 10 | ADR |

## 14. `prometheus-grafana`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| pg-c1 | Modelo de datos pull, labels, cardinalidad y sus límites | conceptual | 15 | Oral |
| pg-c2 | PromQL: rate, histogram_quantile, aggregations correctas | operativa | 15 | Set de queries |
| pg-c3 | Diseñar SLIs/SLOs + burn-rate alerts multi-window | arquitectónica | 20 | SLO doc + reglas |
| pg-c4 | Grafana: dashboards legibles, variables, annotations | operativa | 10 | Dashboard JSON |
| pg-c5 | Alertmanager: routing, inhibition, silences; evitar fatiga | operativa | 15 | Config |
| pg-c6 | Recording rules para queries caras / dashboards | operativa | 10 | Rules |
| pg-c7 | Alta disponibilidad: Thanos/Mimir/Cortex — cuándo y por qué | arquitectónica | 15 | ADR |

## 15. `opentelemetry`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| ot-c1 | Distinguir trazas, métricas, logs y su correlación | conceptual | 10 | Oral |
| ot-c2 | Instrumentar app con SDK (auto + manual) | operativa | 15 | App + spans en backend |
| ot-c3 | Collector: pipelines, procesadores, exporters | arquitectónica | 15 | Config + ADR |
| ot-c4 | Context propagation entre servicios | operativa | 10 | Trace cross-service |
| ot-c5 | Sampling: head vs tail; trade-offs | arquitectónica | 15 | ADR |
| ot-c6 | Semantic conventions y evitar explosión de atributos | operativa | 10 | Review de spans |
| ot-c7 | Backend-agnostic: cambiar backend sin tocar la app | arquitectónica | 15 | Demo con 2 backends |
| ot-c8 | Debug: por qué un span no llega al backend | operativa | 10 | Troubleshooting |

## 16. `devsecops`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| ds-c1 | Modelo de amenazas de supply chain (SLSA niveles) | conceptual | 15 | Oral |
| ds-c2 | SAST + SCA + secret scan en PR, con gates calibrados | operativa | 15 | Pipeline |
| ds-c3 | SBOM (CycloneDX/SPDX) generado y publicado | operativa | 10 | SBOM en release |
| ds-c4 | Firmar imágenes/artefactos (cosign) y verificar en admisión | operativa | 15 | Policy + rechazo demo |
| ds-c5 | Policy-as-code en cluster (Kyverno/OPA) | operativa | 15 | Policies + violación |
| ds-c6 | Runtime security (Falco u otro) con reglas útiles | operativa | 10 | Reglas + alerta |
| ds-c7 | External Secrets Operator + proveedor cloud | operativa | 10 | ESO + rotación |
| ds-c8 | Runbook de incidente de seguridad (clave expuesta, imagen comprometida) | arquitectónica | 10 | Runbook |

## 17. `platform-engineering`

| ID | Competencia | Dimensión | Peso | Evidencia |
|----|-------------|-----------|-----:|-----------|
| pe-c1 | Team Topologies: stream-aligned/platform/enabling/complicated-subsystem | conceptual | 15 | Oral |
| pe-c2 | Golden path: definir, documentar, medir adopción | arquitectónica | 15 | Doc + métrica |
| pe-c3 | Backstage: catalog + scaffolder + TechDocs | operativa | 15 | Catalog con N entidades |
| pe-c4 | Scorecards: definir checks y hacerlos visibles | operativa | 10 | Scorecard config |
| pe-c5 | DORA metrics: medir las 4, no vanity | operativa | 15 | Dashboard DORA |
| pe-c6 | SPACE / developer experience: encuesta + señal | operativa | 10 | Encuesta + resultado |
| pe-c7 | Treat platform as product: roadmap, intake, SLAs | arquitectónica | 20 | Roadmap + intake proc |

---

## Dimensiones agregadas

Resumen de pesos por dimensión (orientativo, para calibrar la defensa):

| Dimensión | Peso agregado aproximado | Comentario |
|-----------|-------------------------:|------------|
| Conceptual | ~15 % | Suficiente para evitar que "sabe la receta sin saber por qué". |
| Operativa | ~55 % | El bulto: hacer que funcione correctamente. |
| Arquitectónica | ~30 % | Lo que separa senior de mid: decidir y justificar. |

La defensa de capstone y la entrevista mock deben respetar aproximadamente estas proporciones.
