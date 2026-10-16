# Example 01 — SLO ingredients (recording rules)

Precomputa los ingredientes de un SLO de availability para el servicio `payments`:
una `sli:...:ratio_rate{W}` por ventana (`5m`, `30m`, `1h`, `2h`, `6h`, `1d`, `3d`),
que las alertas MWMBR (ejemplo 02) consumen por nombre.

## Archivos
- `rules.yaml` — grupo con las recording rules.
- `test.yaml` — fixtures `promtool test rules` que verifican una ventana.
- `run.sh` — ejecuta `promtool check rules` + `promtool test rules` vía `docker run`.

## Ejecutar

```bash
bash run.sh
```

Requiere Docker. No requiere `promtool` instalado — se usa la imagen oficial `prom/prometheus`.
Si Docker no está disponible, el script sale 0 con un mensaje SKIP.

## Lectura clave
- Las ventanas largas (`1d`, `3d`) son caras: por eso se precalculan y no se escriben inline.
- El denominador excluye `4xx` pero mantiene `429` (rate-limiting lo paga el servicio).
- `interval: 30s` da suficiente resolución para alertas de 5 min.
