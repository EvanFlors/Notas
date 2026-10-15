#!/usr/bin/env bash
# Copy the reference fixed Dockerfile and a FORENSIC.md stub into the
# learner workspace. Useful to smoke-test the validator end-to-end.
set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-02}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$BASE" ]; then
  echo "ERROR: $BASE no existe. Corre starter/bootstrap.sh primero." >&2
  exit 1
fi

cp "$HERE/Dockerfile" "$BASE/Dockerfile"

cat > "$BASE/FORENSIC.md" <<'MD'
# Nota forense — dkr-07-02

## Reproduccion

Construimos la imagen con el Dockerfile original pasando el token:

```
docker build --build-arg API_TOKEN=FAKE_TOKEN_abcdef0123456789 -t leaky:bad .
docker history --no-trunc leaky:bad | grep FAKE_TOKEN
```

El `grep` imprime la linea del `RUN` con el valor sustituido.

## Causa

`ARG API_TOKEN`, al ser usado en `RUN`, deja el valor literal en el campo
`created_by` del config JSON de la capa. `docker history` lee ese campo
directamente. Ademas, cualquier archivo creado en la primera fase del `RUN`
queda en el tar de la capa; el `rm` posterior solo agrega una capa que lo
tapa — el blob original sigue siendo distribuible.

## Fix

Migrar a `--mount=type=secret,id=github_token`. BuildKit monta el archivo
del secret en `/run/secrets/github_token` solo durante ese `RUN`; la capa
resultante no contiene el archivo ni el valor, y `docker history` no ve
nada porque no hay ARG sustituido.

## Verificacion

```
printf '%s' "FAKE_TOKEN_abcdef0123456789" > /tmp/dkr-07-02-secret
DOCKER_BUILDKIT=1 docker build \
  --secret id=github_token,src=/tmp/dkr-07-02-secret \
  -t leaky:fixed .
docker history --no-trunc leaky:fixed | grep FAKE_TOKEN || echo "no leak"
```

Imprime `no leak`.
MD

echo "Reference solution Dockerfile and FORENSIC.md applied to $BASE"
