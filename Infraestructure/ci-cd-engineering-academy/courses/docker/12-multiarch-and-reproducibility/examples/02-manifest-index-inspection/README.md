# Ejemplo 02 — Inspeccionar el manifest index

## Concepto que demuestra

Qué hay *realmente* detrás de un tag multi-arch: un **OCI image index** cuyo JSON lista entradas `{digest, platform}`. Cada entrada es, a su vez, un manifest mono-arch con su propio digest.

## Contexto

Después de publicar una imagen multi-arch (p. ej. con el Ejemplo 01), queremos *verla*. Dos herramientas sirven:

- `docker buildx imagetools inspect` — moderna, cómoda.
- `docker manifest inspect` — clásica; a veces requiere `DOCKER_CLI_EXPERIMENTAL=enabled`.

## Objetivo

Al terminar, podrás responder:

- ¿Qué `mediaType` identifica a un image index?
- ¿Cómo se obtiene el JSON crudo del índice?
- ¿Cómo se obtiene el manifest de **una** variante (p. ej. solo `linux/arm64`)?

## Prerrequisitos

- Haber corrido el Ejemplo 01 (o cualquier otro build multi-arch), con el registry local y la imagen `127.0.0.1:5000/hello:v1` disponible.
- Alternativa pública: cualquier imagen oficial con multi-arch (ej. `alpine:3.20`, `python:3.12-slim`).

## Archivos del ejemplo

- `files/inspect.sh` — ejecuta los tres comandos en orden y comenta la salida esperada.

## Comandos canónicos

```bash
REF="alpine:3.20"     # o 127.0.0.1:5000/hello:v1 si ya corriste el ejemplo 01

# A) Índice de forma humana
docker buildx imagetools inspect "$REF"

# B) Índice en JSON crudo
docker buildx imagetools inspect "$REF" --raw | jq .

# C) Manifest de UNA variante por digest
#    (toma uno de los digests que la salida anterior listó bajo Manifests)
docker buildx imagetools inspect "$REF@sha256:<digest-de-arm64>" --raw | jq .
```

## Qué deberías observar

El JSON del índice tiene esta forma (recortado):

```
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    { "digest": "sha256:aaa...", "platform": {"architecture":"amd64","os":"linux"} },
    { "digest": "sha256:bbb...", "platform": {"architecture":"arm64","os":"linux"} },
    ...
  ]
}
```

Y el "manifest por variante" ya tiene `config` + `layers` (una imagen mono-arch real).

## Preguntas de reflexión

- ¿Qué pasa si pides `--raw` sobre un tag mono-arch? ¿Qué `mediaType` tiene su respuesta?
- Si cambia **solo** el `config` de una variante (p. ej. un `ENV` nuevo), ¿cambia el digest del índice? ¿Por qué?
- ¿Por qué un `docker pull` sabe *qué* `manifests[]` elegir sin preguntarte?
