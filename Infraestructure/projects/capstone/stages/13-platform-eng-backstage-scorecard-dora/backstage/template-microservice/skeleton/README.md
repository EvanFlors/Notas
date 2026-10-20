# ${{ values.name }}

${{ values.description }}

Owner: `${{ values.owner }}` · Tier: `${{ values.tier }}`

Scaffolded by the capstone `fastapi-microservice` Backstage template.

## Run

```bash
pip install -e '.[dev]'
uvicorn app.main:app --port 8000
curl -s localhost:8000/healthz
```

## Tests

```bash
pytest -q
```

## Catalog registration

`catalog-info.yaml` is already present. Rellena las annotations `slo_url`,
`runbook_url`, `oncall_rotation`, `image_signed`, etc. a medida que el servicio
avance en madurez; el Scorecard las lee para calcular bronze / silver / gold.
