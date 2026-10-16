# Ejemplo 03 — Semconv deprecation handling (dual-emit)

Patrón para manejar deprecations de SemConv sin romper dashboards. Caso: HTTP `http.method` → `http.request.method`.

## Ventana de dual-emit

- Semana 0: anuncio + Collector empieza a dual-emitir (ambas keys llevan el mismo valor).
- Semanas 1-7: equipos migran dashboards/alertas al nombre nuevo.
- Semana 8: cutover. El Collector deja de rellenar la key vieja; dashboards legacy rompen a propósito.

## Archivos

- `collector.yaml` — Collector con OTTL `transform` que rellena la key que falte en cada dirección.
- `cutover-collector.yaml` — versión post-cutover (sólo acepta la key nueva).
- `DEPRECATIONS.md` — tabla de deprecaciones vivas con fecha de inicio y cutover.
