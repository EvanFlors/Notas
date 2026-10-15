# Ejemplo 03 — Docker container action

## Concepto que demuestra

Una **Docker action** con `Dockerfile` + `entrypoint.sh`, inputs vía `args:` y vía `INPUT_*` env vars, output a `$GITHUB_OUTPUT`.

## Contexto

Las Docker actions son la elección correcta cuando necesitas **empaquetar un binario o toolchain** (p. ej. un `shellcheck` versión fijada, un `terraform` custom, un linter con un parser nativo). A cambio pagas:

- Solo corren en **runners Linux**.
- Cold start de 10–60 s si construye el `Dockerfile` por run (mitigable publicando la imagen y usando `image: docker://...`).

## Objetivo

Al terminar:
- Entiendes el shape de un `action.yml` con `runs.using: docker`.
- Sabes cómo llegan los inputs al contenedor (dos vías: `args:` y `INPUT_*`).
- Reproduces el ciclo `docker build` + `docker run` que ejecuta el runner.

## Prerrequisitos

- **Docker** instalado y daemon corriendo (`docker ps`).

Si no hay Docker, el `run-example.sh` **se salta la ejecución** con un mensaje claro.

## Ejecución

```bash
bash files/run-example.sh /tmp/docker-action-demo
```

Esto crea:

```
/tmp/docker-action-demo/greet-docker/
├── action.yml
├── Dockerfile
└── entrypoint.sh
```

El `action.yml`:

```yaml
name: "Greet (Docker)"
description: "Prints a greeting from an Alpine container"
inputs:
  who:
    description: "Target name"
    required: false
    default: "world"
runs:
  using: docker
  image: Dockerfile
  args:
    - ${{ inputs.who }}
```

El `Dockerfile`:

```dockerfile
FROM alpine:3.20
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

El `entrypoint.sh`:

```bash
#!/bin/sh
set -eu

# Inputs come in TWO ways:
#   (1) positional args:   $1 = inputs.who (from action.yml args)
#   (2) env vars INPUT_*:  $INPUT_WHO (always available for every input)
WHO="${1:-${INPUT_WHO:-world}}"

GREETING="Hello, ${WHO}, from a container"
echo "$GREETING"

# Emit output
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "greeting=${GREETING}" >> "$GITHUB_OUTPUT"
fi
```

Simular al runner localmente:

```bash
cd /tmp/docker-action-demo/greet-docker

docker build -t greet-docker:local .

# Prepare a scratch $GITHUB_OUTPUT that we can mount in
touch /tmp/docker-action-demo/github_output
docker run --rm \
  -e INPUT_WHO="mundo" \
  -e GITHUB_OUTPUT=/github/file_commands/output \
  -v /tmp/docker-action-demo/github_output:/github/file_commands/output \
  greet-docker:local mundo

echo "--- outputs ---"
cat /tmp/docker-action-demo/github_output
# greeting=Hello, mundo, from a container
```

## Resultado esperado

- `docker build` finaliza con una imagen `greet-docker:local`.
- `docker run` imprime `Hello, mundo, from a container`.
- `/tmp/docker-action-demo/github_output` contiene `greeting=Hello, mundo, from a container`.

## Interpretación

- GHA, al correr una Docker action, hace exactamente lo que replicamos: `docker build` del `Dockerfile` del repo (o `docker pull` si `image: docker://...@sha`), luego `docker run --rm -e INPUT_* -e GITHUB_* -v /github:/github ... <args>`.
- Los `args:` del `action.yml` se pasan **al CMD del contenedor**. Son el equivalente a los argumentos de `ENTRYPOINT`.
- `$GITHUB_OUTPUT` dentro del contenedor apunta a un archivo que GHA tiene bind-mounted desde el host; cuando el proceso termina GHA lee ese archivo para emitir los outputs.
- Dentro del contenedor estarás como `root` por default. Si tu entrypoint hace `chown`, lo hace sobre volúmenes montados — con cuidado.

## Errores frecuentes

- **Correr en `windows-latest` o `macos-latest`** → `This action is only supported on Linux` y falla.
- **`image: Dockerfile`** pero sin `Dockerfile` en el root del repo (o en el path indicado) → build error.
- **Olvidar `chmod +x entrypoint.sh`** → `exec format error` o `permission denied`.
- **Interpolar `${{ inputs.x }}` dentro del `args:`** y luego usar `$1` sin quoting → script injection si el input viene de datos no confiables. Prefiere `${INPUT_X}` dentro del entrypoint, siempre entre comillas.
- **Reconstruir el `Dockerfile` cada run** → latencia. En producción publica la imagen a GHCR y usa `runs.image: docker://ghcr.io/owner/img@sha256:...`.

## Limpieza

```bash
docker rmi greet-docker:local 2>/dev/null || true
rm -rf /tmp/docker-action-demo
```
