# Ejemplo 02 — PR preview para dashboards + lint + `promtool test rules`

## Qué muestra
Un workflow de GitHub Actions que, ante un PR que toca `dashboards/*.jsonnet` o `rules/*.yaml`:

1. **Compila** jsonnet → JSON.
2. **Linta** los dashboards con `grafana/dashboard-linter`.
3. **Testea** las reglas Prometheus con `promtool test rules`.
4. **Publica** los dashboards generados en un folder efímero `pr-<n>` de una Grafana de preview (via `grizzly apply`).
5. **Comenta** en el PR con la URL del preview.

Al merge a `main`, el mismo workflow despliega al Grafana productivo (folder `main`).

## Archivos
- `.github/workflows/dashboards.yml` — pipeline CI.
- `rules/checkout.yaml` — ejemplo de `PrometheusRule` plano.
- `tests/checkout_tests.yaml` — unit tests `promtool`.
- `dry-run.sh` — simulador local que corre lo que haría el workflow (sin Grafana).

## Requisitos
Para la *simulación local*:
- `promtool` (viene con la distribución Prometheus; `brew install prometheus` o descarga de prometheus.io/download).
- `python3` para parsear YAML con `pyyaml`.

Para el workflow real:
- Secret `GRAFANA_PREVIEW_URL` y `GRAFANA_PREVIEW_TOKEN` en el repo.
- Secret `GRAFANA_PROD_URL` y `GRAFANA_PROD_TOKEN`.
- `grafana/grizzly` disponible (lo descarga el workflow).

## Correr localmente

```bash
bash dry-run.sh
```

Verás: `promtool check rules` sobre `rules/`, luego `promtool test rules` sobre `tests/`, y un YAML-parse de `dashboards.yml`. Debe terminar con `OK — local dry-run complete`.

## Notas
- El preview por PR requiere **una instancia Grafana adicional** (dev/preview). Alternativas: `kind` + grafana efímero levantado por el workflow, o Grafana Cloud free tier.
- `grizzly` sabe aplicar JSON directamente; no necesitas convertir dashboards a su format intermedio.
- La convención `pr-<n>` facilita limpiar: un `grr delete --folder pr-<n>` cuando el PR se cierra.
