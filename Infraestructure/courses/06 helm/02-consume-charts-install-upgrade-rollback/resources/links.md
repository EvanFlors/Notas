# helm-02 — Recursos

## Documentación oficial

- Helm — [Using Helm](https://helm.sh/docs/intro/using_helm/) (install, upgrade, rollback).
- Helm — [Helm commands reference](https://helm.sh/docs/helm/) — `helm install`, `helm upgrade`, `helm rollback`, `helm history`, `helm uninstall`, `helm get`, `helm status`, `helm list`.
- Helm — [Chart Repositories](https://helm.sh/docs/topics/chart_repository/) y [OCI registries](https://helm.sh/docs/topics/registries/).
- Helm — [Storage backends](https://helm.sh/docs/topics/advanced/#storage-backends) (Secret, ConfigMap, SQL).
- Helm — [Permission denied / Release lookups](https://helm.sh/docs/faq/troubleshooting/).

## Charts usados en este módulo

- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) — repo oficial, `helm search repo ingress-nginx/ingress-nginx --versions`.
- [cert-manager](https://cert-manager.io/docs/installation/helm/) — guía oficial de instalación con Helm.
- [Bitnami charts](https://github.com/bitnami/charts) — índice `https://charts.bitnami.com/bitnami` (útil para experimentar con un nginx liviano).

## Herramientas complementarias

- [helm-diff](https://github.com/databus23/helm-diff) — plugin que muestra el diff entre lo instalado y lo que un upgrade/rollback va a aplicar.
- [helmfile](https://github.com/helmfile/helmfile) — declarar múltiples releases como código.
- [k9s](https://k9scli.io/) — TUI para navegar el cluster; muestra releases de Helm cuando se añade el filtro adecuado.

## Lecturas complementarias

- Matt Butcher et al. — *Learning Helm* (O'Reilly, 2nd ed.), caps. 3 y 4.
- Helm Blog — [Helm 3.0 and the removal of Tiller](https://helm.sh/blog/helm-3-released/).
- Artifact Hub — [https://artifacthub.io/](https://artifacthub.io/) — índice de charts públicos; usar para `helm search hub`.

## Para los curiosos

- Payload de un Secret de release, decodificado:
  ```bash
  kubectl get secret -n <ns> sh.helm.release.v1.<release>.v<N> \
    -o jsonpath='{.data.release}' | base64 -d | base64 -d | gzip -d | jq .
  ```
  Verás un JSON con el chart embebido, los valores efectivos y el manifest completo.

- `HELM_DRIVER=sql` + un postgres pequeño: `helm` registra releases en una tabla SQL. Útil para operadores que gestionan cientos de releases y quieren un solo backend central (poco común en equipos de app).

- `helm --debug` imprime los HTTP requests a los repositorios y la ruta exacta del index.yaml que descarga — equivalente al `kubectl --v=8` del curso de kubernetes.
