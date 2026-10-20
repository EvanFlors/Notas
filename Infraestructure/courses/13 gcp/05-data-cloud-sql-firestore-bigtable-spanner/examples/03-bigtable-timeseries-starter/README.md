# Ejemplo 03 — Bigtable para series temporales (emulador oficial)

## Que demuestra

- Levantar el **Bigtable emulator oficial** en Docker.
- Un script Python que crea una tabla `metrics` con column family `v`, escribe 60 puntos de telemetria por device con **row key `metric#device#<reverse_ts>`** (anti-hotspot) y lee los ultimos 10 puntos de un device.

## Row key: por que `reverse_ts`

```
row key:  cpu#device-01#9223372036828854775
                                 ^^^^^^^^^^^ MAX_INT64 - unix_ts_micros
```

Al invertir el timestamp, las lecturas de "ultimos N puntos" son un scan **ascendente** del prefijo `cpu#device-01#` que trae los puntos mas nuevos primero. Al mismo tiempo, las escrituras de distintos devices se reparten entre tablets (el prefijo cambia por device).

Antipattern a evitar: `cpu#20261019T121500#device-01` -> todas las escrituras del minuto caen en el mismo tablet.

## Archivos

- `docker-compose.yml`
- `client.py`
- `requirements.txt`

## Correr localmente

```bash
cd examples/03-bigtable-timeseries-starter

docker compose up -d

python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export BIGTABLE_EMULATOR_HOST=localhost:8086
export GOOGLE_CLOUD_PROJECT=example-project-id
python client.py

docker compose down
```

## Delta frente al servicio real

- El emulador es single-node, in-memory: no hay garbage collection de column family, no hay replicacion, no hay app profiles.
- No puedes benchmarkear latencia realista aqui.
