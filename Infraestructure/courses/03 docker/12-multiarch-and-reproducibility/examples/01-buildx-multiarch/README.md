# Ejemplo 01 — Build multi-arch con `docker buildx`

## Concepto que demuestra

Cómo crear un builder `docker-container`, instalar QEMU para emulación, y construir una imagen para `linux/amd64` **y** `linux/arm64` en una sola invocación de `buildx build`, publicándola como un *manifest index* en un registry local `registry:2`.

## Contexto

El driver `docker` por default **no** puede empujar un índice multi-arch. Necesitas un builder con driver `docker-container` (BuildKit corre en un contenedor efímero). Para emular `arm64` desde un host `amd64` (o viceversa) necesitas QEMU vía `binfmt_misc`.

## Objetivo

Al terminar, podrás responder:

- ¿Qué hace `docker buildx create --driver docker-container`?
- ¿Por qué necesitamos un registry (aunque sea local) para `--push` multi-arch?
- ¿Qué muestra `docker buildx inspect --bootstrap` sobre las plataformas soportadas?

## Prerrequisitos

- Docker Engine ≥ 24 o Docker Desktop reciente (incluye `buildx`).
- En Linux puro, `docker run --privileged --rm tonistiigi/binfmt --install all` una vez (Docker Desktop ya lo trae).

## Archivos del ejemplo

- `files/Dockerfile` — una imagen trivial basada en Alpine (muy pequeña, construye rápido en cualquier arch).
- `files/run.sh` — script completo con los comandos. Léelo línea por línea.

## Comandos canónicos

```bash
# 1) Builder dedicado (una vez)
docker buildx create --name multi --driver docker-container --use
docker buildx inspect --bootstrap   # arranca y lista plataformas

# 2) Registry local (necesario para --push sin GHCR/Hub)
docker run -d --rm --name registry -p 127.0.0.1:5000:5000 registry:2

# 3) Build multi-arch y push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t 127.0.0.1:5000/hello:v1 \
  --push \
  files/

# 4) Verificar
docker buildx imagetools inspect 127.0.0.1:5000/hello:v1
```

## Qué deberías observar

El `imagetools inspect` imprime un bloque `Manifests` con **dos entradas**: `linux/amd64` y `linux/arm64`, cada una con su propio digest, bajo un `MediaType: application/vnd.oci.image.index.v1+json`.

## Limpieza

```bash
docker rm -f registry
docker buildx rm multi
```

## Preguntas de reflexión

- ¿Qué pasaría si intentas `docker pull 127.0.0.1:5000/hello:v1` desde este host? ¿Cuál variante baja?
- ¿Por qué no se puede `--load` un multi-arch al daemon local?
- Si tu CI tuviera `ubuntu-latest` (amd64) y `ubuntu-24.04-arm`, ¿cómo cambiaría el flujo?
