# Ejemplo 03 — Build reproducible: base por digest + lockfile + `SOURCE_DATE_EPOCH`

## Concepto que demuestra

Que un Dockerfile con **base pineada por digest**, **sin pasos no deterministas** y construido con `SOURCE_DATE_EPOCH` + `rewrite-timestamp=true` + `--provenance=false --sbom=false` produce **el mismo `sha256sum` del tar OCI** en dos corridas consecutivas.

## Contexto

Reproducibilidad práctica (nivel 1–2 de la lección §8): dos builds consecutivos en la misma máquina → bytes idénticos. Es el fundamento para firmas estables, cachés verificables, y auditoría.

## Objetivo

Al terminar, podrás responder:

- ¿Qué papel juega `SOURCE_DATE_EPOCH` y qué parte del build *no* arregla?
- ¿Por qué `--provenance=false --sbom=false` suele ser necesario para igualar digests?
- ¿Por qué fijamos la base por `@sha256:…` en lugar de por tag?

## Prerrequisitos

- `docker buildx` ≥ 0.11 (soporte de `rewrite-timestamp`).
- Conexión para `pull` de la base `alpine:3.20`.

## Archivos del ejemplo

- `files/Dockerfile` — minimal, determinista, base por digest.
- `files/build-twice.sh` — construye dos veces y compara `sha256sum` del tar.

## Flujo

```bash
cd files/
./build-twice.sh
# Expect: "REPRODUCIBLE: sha256sum coincide."
```

## Qué deberías observar

Dos corridas → dos tarballs en `/tmp/dkr-12-ex03-{a,b}.tar` → el mismo `sha256sum`. Si cambias **cualquier cosa** en el Dockerfile (añade un `RUN date > /x`, cambia el pin de digest, etc.) el segundo `sha256sum` difiere.

## Preguntas de reflexión

- ¿Por qué comparamos `sha256sum` del *tar OCI* y no `docker image inspect --format '{{.Id}}'`?
- Si corremos `./build-twice.sh` sin `SOURCE_DATE_EPOCH`, ¿qué pasa?
- ¿Qué habría que cambiar para que dos máquinas distintas produzcan también el mismo digest?
