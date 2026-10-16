# Recursos — helm-09

## Documentación oficial

- Helm — `helm lint`: https://helm.sh/docs/helm/helm_lint/
- Helm — `helm template`: https://helm.sh/docs/helm/helm_template/
- Helm — guía de chart tests (`helm test`): https://helm.sh/docs/topics/chart_tests/
- Chart Best Practices: https://helm.sh/docs/chart_best_practices/

## Plugin `helm-unittest`

- Repositorio: https://github.com/helm-unittest/helm-unittest
- Documentación de asserts: https://github.com/helm-unittest/helm-unittest/blob/main/DOCUMENT.md
- Snapshot testing: https://github.com/helm-unittest/helm-unittest#snapshot-testing

## `chart-testing` (`ct`)

- Repositorio: https://github.com/helm/chart-testing
- Documentación de configuración: https://github.com/helm/chart-testing/blob/main/doc/ct.md
- Action para GitHub Actions: https://github.com/helm/chart-testing-action

## `kind`

- Repositorio: https://github.com/kubernetes-sigs/kind
- Node images (versiones disponibles): https://github.com/kubernetes-sigs/kind/releases
- Action: https://github.com/helm/kind-action

## Kubernetes support policy

- Version skew policy: https://kubernetes.io/releases/version-skew-policy/
- Release calendar: https://kubernetes.io/releases/

## Lecturas recomendadas

- "Testing Helm Charts" — artículo de referencia de la comunidad CNCF.
- Repos de referencia donde ver pipelines maduros:
  - `bitnami/charts`
  - `prometheus-community/helm-charts`
  - `jetstack/cert-manager` (chart dir dentro del repo).
