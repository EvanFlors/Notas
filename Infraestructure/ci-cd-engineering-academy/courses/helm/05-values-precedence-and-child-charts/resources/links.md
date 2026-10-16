# Recursos — helm-05

## Documentación oficial
- [Helm — Values files](https://helm.sh/docs/chart_template_guide/values_files/) — fuentes y precedencia.
- [Helm — Subcharts and Global Values](https://helm.sh/docs/chart_template_guide/subcharts_and_globals/) — scoping y `global`.
- [Helm — Dependencies](https://helm.sh/docs/topics/charts/#chart-dependencies) — `dependencies:`, `import-values`, `exports`.
- [Helm — Schema Files](https://helm.sh/docs/topics/charts/#schema-files) — `values.schema.json`.
- [Chart Best Practices — Values](https://helm.sh/docs/chart_best_practices/values/) — convenciones de nombres y tipos.

## Lecturas complementarias
- [Helm — The Chart Template Developer's Guide (full)](https://helm.sh/docs/chart_template_guide/) — fundamentos de templating.
- [Artifact Hub — Charts populares](https://artifacthub.io/) — buena fuente de ejemplos reales de `values.yaml` multi-entorno.
- [Bitnami Common Chart](https://github.com/bitnami/charts/tree/main/bitnami/common) — patrón `global.imageRegistry` adoptado en toda su biblioteca.

## Comandos clave
- `helm template <release> <chart> -f values.yaml -f values-prod.yaml --set image.tag=1.0 --debug`
- `helm get values <release>` (sobre un release instalado) — valores *efectivos* vs defaults.
- `helm show values <chart>` — defaults del chart.
