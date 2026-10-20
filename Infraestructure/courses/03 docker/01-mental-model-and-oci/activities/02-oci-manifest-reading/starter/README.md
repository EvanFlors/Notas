# Starter — dkr-01-02-oci-manifest-reading

Esta actividad soporta dos modos de obtener el manifest:

## Modo OFFLINE (default — sin Docker)

Copia la muestra provista:

```bash
mkdir -p /tmp/dkr-01-manifest
cp sample-manifest.json /tmp/dkr-01-manifest/manifest.json
```

El archivo `sample-manifest.json` es un manifest OCI de ejemplo (image-spec v1,
mono-arquitectura, 3 capas). Es sintáctica y estructuralmente válido; los hashes
son placeholders deterministas (no corresponden a blobs reales en ningún registry).

## Modo DOCKER (si tienes Docker instalado)

```bash
mkdir -p /tmp/dkr-01-manifest
docker pull alpine:3.19
docker manifest inspect alpine:3.19 > /tmp/dkr-01-manifest/manifest.json
```

En Docker moderno (≥ 20.10) `docker manifest inspect` funciona sin flag experimental.
Si recibes un **manifest index** (multi-arch), tu `WRITEUP.md` lo documentará como tal
en la sección C, en vez de layers.

## Siguiente

Ve a `../README.md` §5.3 para empezar la inspección y producir `WRITEUP.md`.
