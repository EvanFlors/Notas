# Acme Platform — Roadmap Q4 2026

> **Audiencia:** todos los stream-aligned teams de Acme. **Cadencia de revisión:** mensual. **Owner:** platform PM.

## NOW (comprometido Q4 2026)

| Epic | Criterio de aceptación | Métrica objetivo | Owner |
|------|------------------------|------------------|-------|
| Postgres self-service v2 (Crossplane claims con backups configurables) | Dev crea DB en Backstage en <5 min, backup diario on por default | % DBs via self-service: 40 → 70 | @alice |
| Template microservicio Go | Igual al Python, con GHA + chart + Argo app + TechDocs | templates/semana: +10 | @bob |
| Scorecard "image signed" habilitado por default | 100 % de servicios nuevos tienen check; aviso en PR si falla | % silver+: 42 → 60 | @carla |
| Deprecation del template "legacy-flask" | Warn en create, remove el 2027-02-01 | servicios con legacy-flask: 23 → 0 | @alice |

## NEXT (candidato Q1 2027)

- **FinOps dashboard por Component** — hipótesis: visibilidad de costo mueve a los equipos a right-size sin que platform tenga que pedirlo. Pedido por: finance, 3 stream-aligned teams.
- **Blackbox probe self-service** (crear probe desde Backstage sin tocar YAML). Pedido por: SRE enabling team.
- **Argo CD multi-cluster**: habilitar deploy a us-east-2 además de us-east-1. Pedido por: equipo pagos.

## LATER (señal pero sin capacidad)

- **Soporte Kotlin** en templates. Pedido por: 1 equipo (Android services), aún no es volumen.
- **Portal interno de APIs** (API catalog + sandbox tipo Readme.io). Pedido por: equipo integraciones.
- **Platform CLI** (`acme-plat`) para operaciones comunes offline. Pedido por: on-call engineers.

## Release notes últimos 30 días

- **2026-10-02** — Template Python v1.4 añadido: incluye OTel SDK por default (traces + metrics). **No breaking**. Upgrade: `acme-plat update-from-template`.
- **2026-10-09** — Scorecard: nuevo check `has_oncall_rotation`. **No breaking**, aparece como *bronze → silver*.
- **2026-09-20** — Crossplane upgrade a v1.17. **No user-visible**.
- **2026-09-14** — Backstage upgrade a release 1.33. **Potencialmente breaking** para plugins custom; ver `#platform-changelog`.

## Deprecaciones anunciadas

| Feature | Anunciada | Warn desde | Remove | Alternativa |
|---------|-----------|------------|--------|-------------|
| Template `legacy-flask` | 2026-09-01 | 2026-10-15 | 2027-02-01 | Template `python-fastapi` v1.4 |
| `pg-provisioner.sh` (legacy script) | 2026-08-10 | 2026-09-01 | 2026-12-01 | Postgres self-service v2 (ver NOW) |
| Plugin `acme-metrics-legacy` para Backstage | 2026-07-20 | 2026-09-01 | 2026-12-15 | Plugin oficial Prometheus + widget DORA |

## Métricas de este trimestre (snapshot inicial)

- DORA DF: 0.8 deploys/día (bucket HIGH)
- DORA LTC: 6 h (bucket HIGH)
- DORA CFR: 11 % (bucket HIGH)
- DORA FDRT: 55 min (bucket HIGH)
- Platform NPS: +18 (vs +12 trimestre anterior)
- % servicios con scorecard ≥ silver: 42 %
- Time to first prod deploy (p50, nuevo servicio): 1.3 días

## Comentarios y feedback

- Office hours: jueves 15:00–16:00, `#platform-office-hours`.
- Design partners para Q4: pagos, checkout, data-ingest.
- Encuesta SPACE Q4 se envía el 2026-11-15; resultados agregados publicados el 2026-12-05.
