# Deprecations vivas — SemConv platform

| Deprecated key | New key | Phase | Start | Cutover | Owner |
| --- | --- | --- | --- | --- | --- |
| `http.method` | `http.request.method` | dual-emit | 2026-10-16 | 2026-12-11 | obs-guild |
| `http.status_code` | `http.response.status_code` | dual-emit | 2026-10-16 | 2026-12-11 | obs-guild |
| `net.peer.name` | `server.address` | dual-emit | 2026-10-16 | 2026-12-11 | obs-guild |

## Proceso

1. Nueva deprecation upstream aparece → se añade entrada aquí, phase = `announced`.
2. PR al Collector añade bloque OTTL de dual-emit → phase = `dual-emit`.
3. Comms a `#observability-announce` + banner en Backstage.
4. 8 semanas de ventana. Equipos migran sus dashboards/alertas.
5. PR de cutover: Collector pasa a `cutover-collector.yaml` → phase = `retired`.
6. Entrada se mueve a `DEPRECATIONS_HISTORY.md`.
