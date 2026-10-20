# Recursos — helm-10

## Oficiales

- Helm — Library Charts: https://helm.sh/docs/topics/library_charts/
- Helm — Chart Types: https://helm.sh/docs/topics/charts/#chart-types
- Helm — Post Rendering: https://helm.sh/docs/topics/advanced/#post-rendering
- Helm — Charts Hooks: https://helm.sh/docs/topics/charts_hooks/
- Argo CD — Helm Charts: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Argo CD — Resource Hooks: https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/
- Argo CD — ApplicationSet with Helm: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
- Flux — HelmRelease API: https://fluxcd.io/flux/components/helm/helmreleases/
- Flux — Managing Helm Releases: https://fluxcd.io/flux/guides/helmreleases/
- Kustomize — Overview: https://kubectl.docs.kubernetes.io/references/kustomize/

## Lecturas recomendadas

- "Helm vs Kustomize" (Argo blog, varias ediciones): https://blog.argoproj.io/
- CNCF — Platform Engineering whitepapers: https://tag-app-delivery.cncf.io/
- Keep a Changelog: https://keepachangelog.com/en/1.1.0/
- SemVer 2.0: https://semver.org/

## Operadores (para la decisión Helm vs operador)

- CloudNativePG (Postgres): https://cloudnative-pg.io/
- Strimzi (Kafka): https://strimzi.io/
- Prometheus Operator: https://prometheus-operator.dev/
- Operator Framework: https://operatorframework.io/

## Tooling complementario

- `helm diff` plugin: https://github.com/databus23/helm-diff
- `helm-unittest`: https://github.com/helm-unittest/helm-unittest
- `chart-testing` (`ct`): https://github.com/helm/chart-testing

## Puentes con otros cursos del programa

- Curso **kubernetes**, módulo `k8s-18-platform-patterns-bridges-helm-gitops-mesh/` — mismo horizonte desde el lado K8s.
- Curso **argocd** (completo) — Application, ApplicationSet, app-of-apps.
- Curso **docker** — OCI registries para publicar charts.
