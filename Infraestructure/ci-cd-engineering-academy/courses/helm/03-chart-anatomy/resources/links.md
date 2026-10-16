# Recursos — helm-03

## Documentación oficial

- **Charts (overview)** — <https://helm.sh/docs/topics/charts/>
- **`Chart.yaml` file** — <https://helm.sh/docs/topics/charts/#the-chartyaml-file>
- **`values.yaml` and templates** — <https://helm.sh/docs/chart_template_guide/values_files/>
- **`values.schema.json`** — <https://helm.sh/docs/topics/charts/#schema-files>
- **Chart Best Practices Guide** — <https://helm.sh/docs/chart_best_practices/>
- **Custom Resource Definitions** (política de `crds/`) — <https://helm.sh/docs/chart_best_practices/custom_resource_definitions/>
- **`helm create`** — <https://helm.sh/docs/helm/helm_create/>
- **`helm lint`** — <https://helm.sh/docs/helm/helm_lint/>
- **`helm template`** — <https://helm.sh/docs/helm/helm_template/>
- **`helm install --dry-run`** — <https://helm.sh/docs/helm/helm_install/>
- **Accessing Files Inside Templates** (`.Files.Get`) — <https://helm.sh/docs/chart_template_guide/accessing_files/>

## JSON Schema

- **JSON Schema draft-07** (specification) — <https://json-schema.org/specification-links.html#draft-7>
- **Understanding JSON Schema** — <https://json-schema.org/understanding-json-schema/>

## Convenciones Kubernetes

- **Recommended Labels** (`app.kubernetes.io/*`) — <https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/>
- **Resource naming limits (63 chars)** — <https://kubernetes.io/docs/concepts/overview/working-with-objects/names/>

## Charts de referencia (lectura recomendada)

- `ingress-nginx` — <https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx>
- `cert-manager` — <https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager>
- `kube-prometheus-stack` (umbrella grande) — <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>

Leer sus `Chart.yaml`, `values.yaml`, `values.schema.json` (cuando existe) y
estructura de `templates/` es la mejor forma de ver convenciones vivas.

## Nota de verificación

Última verificación de enlaces: pendiente de Fase 4. Todos los dominios son
oficiales (`helm.sh`, `kubernetes.io`, `json-schema.org`, `github.com`).
