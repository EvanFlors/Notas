# Example 01 — slim vs alpine vs distroless

Misma app Python mínima construida sobre tres bases distintas. Objetivo: ver con números la diferencia.

## Qué hay aquí

- `app.py` — "hello, world" que imprime la versión de Python y la libc detectada.
- `requirements.txt` — una dependencia con extensión C (`cryptography`) para que la trade-off musl/glibc sea observable.
- `Dockerfile.slim` — `python:3.12-slim` (debian-slim, glibc).
- `Dockerfile.alpine` — `python:3.12-alpine` (musl); construye `cryptography` desde fuente.
- `Dockerfile.distroless` — multi-stage, runtime `gcr.io/distroless/python3-debian12`.
- `build.sh` — construye las tres, mide tamaños, corre las tres, limpia.

## Cómo correr

```
cd examples/01-slim-vs-alpine-vs-distroless
bash build.sh
```

Requiere `docker`. Si no está, el script sale con código 0 e imprime SKIP.

Salida esperada (tamaños y tiempos varían según red):

```
== build.sh ==
building app:slim .......... OK
building app:alpine ........ OK (slower; building from source)
building app:distroless .... OK

TAG                  SIZE
app:slim             ~190 MB
app:alpine           ~130 MB
app:distroless       ~85 MB

runtime check:
  app:slim        -> OK, python 3.12.x on glibc
  app:alpine      -> OK, python 3.12.x on musl
  app:distroless  -> OK, python 3.12.x on glibc

cleanup: docker rmi app:slim app:alpine app:distroless
```

## Qué observar

- `alpine` suele tardar **minutos** en construir la primera vez por compilar `cryptography` (Rust + C).
- `distroless` **sin shell**: `docker run --rm app:distroless sh` falla con `exec: sh: not found`. Es correcto.
- La diferencia de tamaño entre `alpine` y `distroless` es menor de lo que la gente supone — y distroless gana en superficie de ataque.

## Preguntas

1. ¿Qué pasa si cambias `Dockerfile.alpine` para que **no** instale `musl-dev gcc libffi-dev openssl-dev`? (Pista: `cryptography` deja de compilar.)
2. ¿Por qué `Dockerfile.distroless` necesita un stage builder y los otros dos no?
3. Mide con `docker image inspect --format '{{.Size}}' app:X` y compara con `docker images` — ¿coincide?

## Limpieza

```
docker rmi app:slim app:alpine app:distroless 2>/dev/null || true
```
