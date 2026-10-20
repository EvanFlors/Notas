# Ejemplo 03 — Dashboard de vuln management

> Lectura y análisis. Sin ejecución (no se levanta Grafana).

El dashboard es el **output del lifecycle**. Si no se mide, la plataforma es una lista de intenciones.

Este ejemplo define:

- Las **7 métricas base** y sus fórmulas.
- Los **SLOs** sugeridos y qué conversación disparan al incumplirse.
- Un **layout ASCII** del dashboard con las 7 widgets.
- Los **joins** típicos entre el SBOM store y el issue tracker para calcularlas.

Ver `REFERENCE.md`.

## Dónde se calcula cada métrica

| Métrica                        | Fuente                                 |
|--------------------------------|----------------------------------------|
| MTTR por tier                  | Issue tracker (findings con `fixed_at`)|
| % imágenes firmadas            | SBOM store (`image_build.signed_identity`) |
| % builds green                 | CI (status de pipelines)               |
| % cobertura SBOM               | SBOM store (`image_build` sin SBOM)    |
| Backlog Critical abierto       | Issue tracker (tier=Critical, state=open) |
| Pipeline p95                   | CI telemetría (histograma de duración) |
| Excepciones expiradas sin revisar | Repo `exceptions/*.yaml` (`expires_at < now`) |

## Lo que el dashboard **no** debe mostrar

- "Total CVEs scanned": vanity.
- "Total secrets found en la historia": no accionable (ya pasaron).
- Lista infinita de todas las findings sin agrupar: ruido.
