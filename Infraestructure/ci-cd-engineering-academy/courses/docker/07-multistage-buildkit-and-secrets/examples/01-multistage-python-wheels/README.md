# Ejemplo 01 — Multi-stage con wheels de Python

Demuestra el patron canonico de multi-stage para apps Python:

- **Stage `builder`** sobre `python:3.12` (full) con `gcc` instalado. Produce wheels en `/wheels`.
- **Stage `runtime`** sobre `python:3.12-slim`, sin `gcc`. Instala solo los wheels, luego los borra.

## Requisitos

- Docker Engine ≥ 20.10 (BuildKit habilitado por default en ≥ 23).
- `bash`.

Si no tienes Docker el script `measure.sh` imprime `SKIP` y sale 0.

## Que hay

```
.
├── Dockerfile          # multi-stage: builder + runtime
├── app.py              # Flask minima, una ruta /health
├── requirements.txt    # flask
├── .dockerignore
└── measure.sh          # construye multi + un baseline monolitico y compara tamanos
```

## Correr

```bash
cd examples/01-multistage-python-wheels
./measure.sh
```

Output esperado (ordenes de magnitud en una laptop decente):

```
REPOSITORY:TAG            SIZE
multistage-demo:multi     ~135MB
multistage-demo:mono      ~1.08GB
OK: no gcc in the multi-stage runtime image.
```

El ratio tipico es **8–10x mas pequeno** solo por separar los stages.

## Lo que esta ensenando

1. `COPY --from=builder /wheels /wheels` es el **unico** camino por el que algo cruza del builder al runtime.
2. El runtime no incluye `gcc` (verificable con `docker run --rm multistage-demo:multi sh -c 'command -v gcc'`).
3. BuildKit paraleliza los stages independientes; aqui `runtime` depende de `builder`, por eso van en serie.

## Limpieza

```bash
docker rmi multistage-demo:multi multistage-demo:mono 2>/dev/null || true
```
