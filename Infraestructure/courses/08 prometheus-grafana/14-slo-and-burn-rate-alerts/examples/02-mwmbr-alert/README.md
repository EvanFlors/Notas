# Example 02 — Multi-window multi-burn-rate alerts

Alertas de burn-rate siguiendo la receta del SRE Workbook.
Severidad `page` (fast burn) y severidad `ticket` (slow burn), cada una con
dos ventanas (`long AND short`) para filtrar falsos positivos sin perder reactividad.

| Severidad | Burn-rate | Ventana larga | Ventana corta |
|-----------|-----------|---------------|---------------|
| page      | 14.4      | 1h            | 5m            |
| page      | 6         | 6h            | 30m           |
| ticket    | 3         | 24h           | 2h            |
| ticket    | 1         | 72h / 3d      | 6h            |

La condición es `(1 - sli_long) > burn_rate * error_budget AND (1 - sli_short) > burn_rate * error_budget`.

## Archivos
- `rules.yaml` — grupo con ingredientes mínimos + 4 alertas MWMBR.
- `test.yaml` — fixtures `promtool test rules` para 3 escenarios: calma, fast burn, slow burn.
- `run.sh` — ejecuta `promtool check rules` + `promtool test rules` vía Docker.

## Ejecutar

```bash
bash run.sh
```

SKIP si Docker no está disponible.
