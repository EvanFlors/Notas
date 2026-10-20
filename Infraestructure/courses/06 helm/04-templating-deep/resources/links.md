# Recursos — helm-04 Templating en profundidad

## Documentación oficial de Helm

- **Chart Template Guide (hub)** — <https://helm.sh/docs/chart_template_guide/>
- **Built-in Objects** — <https://helm.sh/docs/chart_template_guide/builtin_objects/>
- **Values Files** — <https://helm.sh/docs/chart_template_guide/values_files/>
- **Functions and Pipelines** — <https://helm.sh/docs/chart_template_guide/functions_and_pipelines/>
- **Flow Control** (`if`/`with`/`range`) — <https://helm.sh/docs/chart_template_guide/control_structures/>
- **Variables** (y scoping con `$`) — <https://helm.sh/docs/chart_template_guide/variables/>
- **Named Templates** (`define`/`template`/`include`) — <https://helm.sh/docs/chart_template_guide/named_templates/>
- **Accessing Files Inside Templates** — <https://helm.sh/docs/chart_template_guide/accessing_files/>
- **Debugging Templates** (`helm template`, `--debug`) — <https://helm.sh/docs/chart_template_guide/debugging/>

## Sprig: la librería de funciones

- **Sprig docs (todas las funciones disponibles en Helm)** — <https://masterminds.github.io/sprig/>
- **Default functions** — <https://masterminds.github.io/sprig/defaults.html>
- **String functions** — <https://masterminds.github.io/sprig/strings.html>
- **Encoding (`b64enc`, `sha256sum`)** — <https://masterminds.github.io/sprig/encoding.html> y <https://masterminds.github.io/sprig/crypto.html>
- **Dictionary/List** — <https://masterminds.github.io/sprig/dicts.html>, <https://masterminds.github.io/sprig/lists.html>

## Best practices

- **Chart Best Practices Guide (oficial)** — <https://helm.sh/docs/chart_best_practices/>
- **Labels and Annotations** — <https://helm.sh/docs/chart_best_practices/labels/>
- **Templates (nombres, estructura)** — <https://helm.sh/docs/chart_best_practices/templates/>
- **Pods and Pod Templates** — <https://helm.sh/docs/chart_best_practices/pods/>

## Debugging y validación

- **`helm template` (reference)** — <https://helm.sh/docs/helm/helm_template/>
- **`helm lint`** — <https://helm.sh/docs/helm/helm_lint/>
- **kubeconform** (validar YAML renderizado contra schemas de K8s) — <https://github.com/yannh/kubeconform>
- **helm-docs** (generar README desde `values.yaml` + comentarios) — <https://github.com/norwoodj/helm-docs>

## Lectura larga

- *The Chart Author's Guide* (secciones avanzadas de `_helpers.tpl`) — <https://helm.sh/docs/topics/charts/>
- **Go `text/template` package** — <https://pkg.go.dev/text/template> (referencia del motor subyacente).

## Charts canónicos como referencia

Charts bien escritos para leer y copiar patrones de `_helpers.tpl`:

- **bitnami/common** — <https://github.com/bitnami/charts/tree/main/bitnami/common> (library chart de referencia).
- **ingress-nginx** — <https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx>.
- **cert-manager** — <https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager>.
- **argo-cd** — <https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd>.

## Vídeos y charlas

- *Helm Chart Templating Deep Dive* (KubeCon) — buscar en YouTube "KubeCon Helm templating deep dive".
- *You Don't Know Helm* — buscar la charla por título.

## Herramientas complementarias

- **helmfile** — orquestar múltiples releases <https://github.com/helmfile/helmfile>.
- **chart-testing (`ct`)** — <https://github.com/helm/chart-testing> (se cubre en `helm-09`).
- **`helm diff` plugin** — <https://github.com/databus23/helm-diff> (indispensable para prod).
