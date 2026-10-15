# Ejemplo 02 — Cost + metrics dashboard desde la REST API

Este ejemplo extrae métricas básicas de pipeline (**duración p50/p95**, **tasa de éxito**, **runner-minutes cobrables**) para un repo o conjunto de repos, consumiendo la REST API `actions/workflow-runs`.

## Qué hay aquí

```
.
├── README.md             ← este archivo
├── pipeline_metrics.py   ← script Python 3 (solo stdlib, requiere `gh` CLI)
└── sample_runs.json      ← fixture para probar sin pegarle a la API
```

Diseñado para funcionar con `gh api` como transporte (ya autenticado) y así no incluir credenciales en el script.

## Fórmulas

- **Duración por run (min)** = `(updated_at - run_started_at)` convertido a minutos. Es *wall-clock* del run; para cost real preferimos `/actions/runs/{id}/timing` (que separa billable_ms por SKU), pero para un dashboard de alto nivel bastan los campos del listing.
- **p50 / p95**: percentiles clásicos sobre la lista de duraciones ordenadas.
- **Runner-minutes cobrables** (aproximación):
  - Para cada run, suma `ceil(duration_min_del_job) * multiplier_por_SKU`.
  - Multiplicadores por defecto: `ubuntu=1`, `windows=2`, `macos=10`. Larger runners: trátalos como SKU aparte (fuera de alcance del ejemplo).

## Uso

### Con la API real (requiere `gh auth login`)

```bash
gh api -X GET /repos/OWNER/REPO/actions/runs \
  -f per_page=100 \
  --paginate > runs.json

python3 pipeline_metrics.py --runs runs.json
```

### Con el fixture incluido (reproducible sin red)

```bash
python3 pipeline_metrics.py --runs sample_runs.json
```

Salida esperada (sobre el fixture):

```
== Pipeline metrics ==
runs analyzed:    8
success rate:     75.00%
duration p50:     3.9 min
duration p95:     9.3 min
runner-minutes:   41   (approx)

== Per workflow ==
ci.yml                   runs=5 success=80% p50=3.5 p95=7.1 minutes=22
release.yml              runs=3 success=67% p50=5.0 p95=9.5 minutes=19
```

## Advertencias de precisión

- Los campos `run_started_at` y `updated_at` del listing no son exactamente *billable minutes*. Para facturación precisa, iterar `/actions/runs/{id}/timing` que trae `billable: { UBUNTU, WINDOWS, MACOS: { total_ms, jobs } }`. Está documentado en los recursos (`resources/links.md`).
- El multiplicador que aplica el billing oficial se redondea **al minuto por job** (no por run). Este script redondea por run → tiende a *subestimar* por una fracción pequeña. Para gobierno es aceptable; para presupuesto no.
- Larger runners se cobran por tier, no por multiplier. El script los marca como `?` si aparecen.
