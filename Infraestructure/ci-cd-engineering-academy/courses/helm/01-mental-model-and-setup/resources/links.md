# Recursos — helm-01

## Docs oficiales (fuente primaria)

- **Helm Docs** — <https://helm.sh/docs/>
- **Installing Helm** — <https://helm.sh/docs/intro/install/>
- **Quickstart** — <https://helm.sh/docs/intro/quickstart/>
- **Using Helm** — <https://helm.sh/docs/intro/using_helm/>
- **Charts** — <https://helm.sh/docs/topics/charts/>
- **Chart Repositories** — <https://helm.sh/docs/topics/chart_repository/>
- **OCI-based Registries** — <https://helm.sh/docs/topics/registries/>
- **Values Files** — <https://helm.sh/docs/chart_template_guide/values_files/>
- **Chart Best Practices** — <https://helm.sh/docs/chart_best_practices/>

## Migración Helm 2 → Helm 3 (contexto histórico)

- **Migration guide v2 → v3** — <https://helm.sh/docs/topics/v2_v3_migration/>
- **Changes since Helm 2** — <https://helm.sh/docs/faq/changes_since_helm2/>
- **`helm-2to3` plugin** — <https://github.com/helm/helm-2to3>

## Comunidad / índices

- **Artifact Hub** (índice público de charts) — <https://artifacthub.io/>
- **CNCF Helm Project** — <https://www.cncf.io/projects/helm/>
- **Helm Blog** (anuncios, release notes) — <https://helm.sh/blog/>
- **Helm GitHub** — <https://github.com/helm/helm>

## Charts populares usados en las actividades

- **ingress-nginx** — <https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx>
- **cert-manager** (jetstack) — <https://cert-manager.io/docs/installation/helm/>
- **kube-prometheus-stack** — <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
- **bitnami/postgresql** — <https://github.com/bitnami/charts/tree/main/bitnami/postgresql>
- **argo-cd** — <https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd>

## Lecturas de referencia

- Masse, Butcher — *Learning Helm* (O'Reilly, 2021). Introducción canónica a Helm 3.
- Butcher et al. — *Go in Action* / *The Chart Template Developer's Guide* (dentro de los docs oficiales).
- Posts sobre la depreciación de Tiller (Helm blog, 2019) — buscables en el histórico del blog.

## Integración con GitOps (adelanto, para `helm-10`)

- **Argo CD — Helm source** — <https://argo-cd.readthedocs.io/en/stable/user-guide/helm/>
- **Flux — HelmRelease (v2)** — <https://fluxcd.io/flux/components/helm/helmreleases/>

## Herramientas complementarias (adelanto)

- **helm-diff** (plugin) — <https://github.com/databus23/helm-diff>
- **helm-unittest** (plugin) — <https://github.com/helm-unittest/helm-unittest>
- **chart-testing (`ct`)** — <https://github.com/helm/chart-testing>
- **cosign** (firma OCI) — <https://docs.sigstore.dev/cosign/>
