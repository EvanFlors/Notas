# Ejemplo 02 — Firestore Native CRUD (emulador oficial)

## Que demuestra

- Levantar el **Firestore emulator oficial** en Docker, sin tocar GCP y sin cuenta.
- Un cliente Python que crea una coleccion `users`, inserta documentos con subcoleccion `orders` y hace:
  - un read por `document()`,
  - una query con filtro (`where`),
  - una transaccion ACID cross-document,
  - un batched write.

## Archivos

- `docker-compose.yml` — levanta el emulador en `localhost:8080` usando `google/cloud-sdk`.
- `client.py` — ejercita todas las operaciones listadas arriba.
- `requirements.txt`.

## Correr localmente

```bash
cd examples/02-firestore-native-crud

docker compose up -d
# espera 5-10s a que el emulador arranque

python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export FIRESTORE_EMULATOR_HOST=localhost:8080
export GOOGLE_CLOUD_PROJECT=example-project-id
python client.py

docker compose down
```

## Delta frente al servicio real

- El emulador **no valida indices compuestos**: queries que en prod fallarian por `FAILED_PRECONDITION` aqui pasan. Antes de ir a prod declara los indices con `google_firestore_index` en Terraform.
- No hay IAM real: cualquier cliente conectado al emulador tiene acceso total.
- No hay snapshots realtime remotos (si local).
