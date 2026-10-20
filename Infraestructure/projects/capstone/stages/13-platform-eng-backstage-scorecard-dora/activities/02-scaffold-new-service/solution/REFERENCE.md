# REFERENCE — cap-13-02-scaffold-new-service

## Que debe quedar en el nuevo servicio

`/tmp/cap-13-02/svc-reports/` con, como minimo:

- `catalog-info.yaml` renderizado, sin ningun `${{ ... }}` sin resolver,
  con `metadata.name: svc-reports`, `spec.owner: team-capstone`,
  `spec.tier: tier-2`.
- `app/main.py` con la FastAPI referenciando `svc-reports` en el titulo.
- `pyproject.toml` con `name = "svc-reports"`.

## Scorecard esperado

Al correr `evaluate.py` apuntandole a este `catalog-info.yaml`:

- `svc-reports` queda en nivel **bronze**: tiene owner (unica regla bronze)
  pero las tres reglas silver (`slo_url`, `runbook_url`, `oncall_rotation`)
  nacen vacias y las cuatro gold tambien.

Esto es lo deseado: un servicio recien nacido **no deberia** estar en gold.
El scorecard mide la **realidad operacional**, no la buena intencion.

## Por que esto es *paved road*

- El `catalog-info.yaml` nace **con** el servicio, no se agrega despues.
- Las annotations nacen con stubs explicitos (`slo_url: ""`), no implicitas:
  cuando llegue el momento de SLOs, el equipo ve el campo y lo rellena, no
  tiene que recordar que exista.
- El owner es obligatorio en el `parameters` del template; no se puede crear
  un servicio huerfano.
