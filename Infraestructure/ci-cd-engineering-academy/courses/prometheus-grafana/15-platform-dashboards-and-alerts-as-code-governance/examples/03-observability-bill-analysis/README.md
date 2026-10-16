# Ejemplo 03 — Observability bill: cálculo desde un perfil

## Qué muestra
Un script Python que lee un `profile.yaml` (servicios, series/servicio, logs GB/día, retención, tier) y produce la factura mensual estimada: métricas, logs, trazas, egress, total. Imprime también el top-3 de contribuyentes y recomendaciones.

Pensado como *base* para que el estudiante lo use y extienda en la actividad 02.

## Archivos
- `bill.py` — calculadora.
- `profile.yaml` — perfil de ejemplo (10 servicios, 2 tiers).
- `prices.yaml` — tarifas asumidas (editable).
- `run.sh` — orquestador.

## Requisitos
- `python3` con `pyyaml` (`pip install pyyaml`).

## Correr

```bash
bash run.sh
```

Salida esperada: tabla por tier/servicio con `active_series`, `log_gb_day`, costo mensual estimado, y un total. Termina con `OK — bill computed`.

## Notas
- Los precios son referenciales (basados en pricing público 2026 de Grafana Cloud, Loki self-hosted y AWS egress). Edita `prices.yaml` para tu contexto.
- La fórmula es intencionadamente simple (ver `theory/lesson.md` §8). Para el capstone real conviene añadir ingest-rate pricing (Mimir) y egress inter-AZ cuando aplique.
- El script valida que todo servicio tenga `tier`, `team`, `env` (gobernanza en acción) y falla si falta alguno.
