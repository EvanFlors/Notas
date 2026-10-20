# Ejemplo 04 — Spanner con emulador oficial (SQL + interleaved tables)

## Que demuestra

- Levantar el **Spanner emulator oficial** (imagen `gcr.io/cloud-spanner-emulator/emulator`).
- Un script Python que:
  - crea `instance` + `database`,
  - define esquema con **tabla hija interleaved** (`Orders INTERLEAVE IN PARENT Users ON DELETE CASCADE`),
  - inserta usuarios y ordenes,
  - corre una **transaccion read-write** que lee saldo y escribe una orden si pasa un check.

## Archivos

- `docker-compose.yml`
- `client.py`
- `requirements.txt`

## Correr localmente

```bash
cd examples/04-spanner-emulator-sql

docker compose up -d
# el emulador escucha gRPC en 9010 y REST en 9020

python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export SPANNER_EMULATOR_HOST=localhost:9010
export GOOGLE_CLOUD_PROJECT=example-project-id
python client.py

docker compose down
```

## Delta frente al servicio real

- El emulador es single-region, no hay TrueTime real: no puedes benchmarkear external consistency ni failover regional.
- No hay IAM, no hay backups, no hay encryption-at-rest con CMEK.
- Util para probar esquema y queries, no SLOs.
