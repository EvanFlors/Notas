# Ejemplo 03 — Docker executor con `image:` y `services:`

## Qué muestra

Un pipeline que usa `image: python:3.12-slim` para correr `pytest` y levanta `postgres:16` como **servicio sidecar** accesible por hostname `postgres`. Ilustra cómo `image:` y `services:` colaboran bajo el executor `docker`.

## Archivo

Ver [`.gitlab-ci.yml`](./.gitlab-ci.yml).

## Lectura clave

```yaml
pytest:
  image: python:3.12-slim        # <- contenedor principal del job
  services:
    - name: postgres:16
      alias: postgres            # <- hostname para conectar
  variables:
    POSTGRES_PASSWORD: test
    POSTGRES_DB: app
    DATABASE_URL: postgres://postgres:test@postgres:5432/app
  script:
    - pip install -r requirements.txt
    - pytest -q
```

- El runner lanza **dos contenedores**: `python:3.12-slim` (donde corre `script:`) y `postgres:16` (como sidecar).
- Ambos comparten red: el job accede a Postgres por `postgres:5432`.
- `POSTGRES_PASSWORD` / `POSTGRES_DB` son leídas por la imagen oficial de Postgres (convención del upstream, no de GitLab).
- `DATABASE_URL` la lee tu código.

## Cuándo **no** usar `services:`

- Si el servicio necesita volúmenes persistentes entre jobs — `services:` arranca y muere con el job.
- Si tu stack real usa 5+ servicios — considera un `docker-compose` dentro del job (con DinD, tema de `gl-06`).
- Si el runner es `shell` executor → `image:` y `services:` se ignoran. Verifica el executor del runner que recogerá el job.

## Validación local

```bash
python3 -c "
import yaml
d = yaml.safe_load(open('.gitlab-ci.yml'))
assert 'pytest' in d
assert d['pytest']['image'].startswith('python:')
assert any('postgres' in str(s) for s in d['pytest']['services'])
print('image + services OK')
"
```
