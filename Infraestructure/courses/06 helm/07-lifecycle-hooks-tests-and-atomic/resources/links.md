# Recursos — helm-07

## Documentación oficial

- Hooks — https://helm.sh/docs/topics/charts_hooks/
- Chart tests — https://helm.sh/docs/topics/chart_tests/
- `helm install` flags (incluye `--atomic`, `--wait`, `--timeout`, `--cleanup-on-fail`) — https://helm.sh/docs/helm/helm_install/
- `helm upgrade` — https://helm.sh/docs/helm/helm_upgrade/
- `helm test` — https://helm.sh/docs/helm/helm_test/
- `helm rollback` — https://helm.sh/docs/helm/helm_rollback/

## Decisión hook vs initContainer vs operator

- Kubernetes init containers — https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
- Operator pattern — https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
- Discusión del equipo Helm sobre `--atomic` en CI — https://helm.sh/docs/chart_best_practices/

## Interacciones con GitOps

- Argo CD + hooks de Helm — https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Flux `HelmRelease` — https://fluxcd.io/flux/components/helm/helmreleases/

## Lectura complementaria

- "Why your init container is not the right place for schema migrations" — buscar discusión en la lista de helm-dev.
- Chart Best Practices (sección "The /tests directory") — https://helm.sh/docs/chart_best_practices/
