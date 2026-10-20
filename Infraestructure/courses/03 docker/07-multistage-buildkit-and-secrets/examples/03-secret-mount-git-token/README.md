# Ejemplo 03 — `--mount=type=secret` para un token

Demuestra el **unico patron correcto** para pasar un secreto a `RUN`: montarlo como `type=secret`. Al terminar, el token no aparece en `docker history` ni en ninguna capa del filesystem de la imagen.

## Requisitos

- Docker Engine con BuildKit (default en ≥ 23) o `DOCKER_BUILDKIT=1`.
- `bash`.

Si no tienes Docker, `build.sh` imprime `SKIP` y sale 0.

## Que hay

```
.
├── Dockerfile          # usa --mount=type=secret,id=github_token
├── .dockerignore
└── build.sh            # construye con --secret y audita docker history
```

El token usado es un **dummy** (`FAKE_TOKEN_xxxx0123456789`) escrito a `/tmp/dkr-07-ex03.token` por el script y borrado al salir con `trap`.

## Correr

```bash
cd examples/03-secret-mount-git-token
./build.sh
```

Output esperado (resumido):

```
== Building with --secret id=github_token ==
#8 [2/2] RUN --mount=type=secret,id=github_token ...
#8 0.123 (token nunca aparece aqui, BuildKit lo redacta)
...
== Receipt stored in the image (length + last 4 chars only) ==
token-length-at-build-time:24
last4:6789

== Auditing docker history for the token ==
OK: token NOT present in docker history.

== Auditing final image filesystem for the token ==
OK: /run/secrets is absent from the final image.
```

## Lo que esta ensenando

1. `--secret id=github_token,src=/path/file` monta el archivo en `/run/secrets/github_token` **solo durante** ese `RUN`.
2. Al terminar el `RUN`, el mount desaparece. La capa resultante NO contiene `/run/secrets/github_token`.
3. `docker history --no-trunc` NO muestra el token (comparalo con el anti-patron `ARG`/`--build-arg`, cubierto en la actividad 02).
4. La "receipt" que si queda en la imagen contiene solo metadatos no sensibles (longitud + ultimos 4 chars).

## Contraste con el anti-patron

Para ver el anti-patron en vivo:

```bash
docker build --build-arg API_TOKEN=FAKE_TOKEN_xxxx0123456789 -t leaky-demo:latest - <<'DOCKER'
FROM alpine:3.20
ARG API_TOKEN
RUN echo "using token: $API_TOKEN" > /tmp/trace && rm /tmp/trace
DOCKER
docker history --no-trunc leaky-demo:latest | grep -i token
```

Veras el token completo en el output: la capa quedo horneada **con el valor literal del `ARG` sustituido**. Esto es exactamente lo que `--mount=type=secret` evita.

## Limpieza

```bash
docker rmi secret-mount-demo:latest leaky-demo:latest 2>/dev/null || true
rm -f /tmp/dkr-07-ex03.token
```
