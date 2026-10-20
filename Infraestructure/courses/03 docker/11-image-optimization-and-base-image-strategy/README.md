# dkr-11 — Image optimization and base image strategy

## Identificación

- **ID:** `dkr-11-image-optimization-and-base-image-strategy`
- **Curso:** `docker`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `dkr-07-multistage-buildkit-and-secrets` (y por transitividad `dkr-06`, `dkr-03`). Docker Engine >= 24 con BuildKit habilitado por default. `dive` opcional.

## Objetivo

Reducir **tamaño**, **superficie de ataque** y **tiempo de arranque** de una imagen de aplicación eligiendo con criterio su **base image**, y defender esa elección por escrito en una ADR.

Al terminar deberías poder entregar una imagen de app Python < 100 MB sobre **distroless** o **Chainguard**, funcional, y explicar en qué contexto no la usarías.

## Alcance

Este módulo cubre:

- La trade-off real entre bases: `debian:*-slim` vs `alpine` (musl vs glibc) vs **distroless** (Google) vs **Chainguard** vs `scratch`.
- Por qué `alpine` rompe librerías Python con extensiones C (musl ABI, ausencia de manylinux wheels).
- Por qué `distroless` no tiene shell — y por qué eso es *feature*, no *bug*.
- Medir tamaño **real por capa** con `docker history` y con `dive` (opcional).
- Técnicas de reducción: `--no-cache-dir`, wheels precompiladas, `strip`, separar binarios de deps en multi-stage, copiar sólo lo necesario, limpiar caches en la misma capa que las crea.
- Impacto del tamaño en **cold-start** y en el tiempo de **pull** en clusters (K8s, autoscaling).
- `scratch` + binario estático (Go) como caso límite.

Lo que **no** cubre (vendrá después):
- Hardening de runtime (`USER`, caps, read-only, seccomp) → `dkr-13`.
- Multi-arch y reproducibilidad bit-a-bit → `dkr-12`.
- SBOM, firma, provenance → `dkr-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda en 12 secciones.
- **`examples/`** — reproducibles:
  - `01-slim-vs-alpine-vs-distroless/` — misma app Python en tres bases; mide tamaño.
  - `02-dive-walkthrough/` — inspección capa a capa (requiere `dive`, SKIP graceful).
  - `03-scratch-with-static-binary/` — Go hello-world sobre `scratch`.
- **`activities/`**:
  - `01-shrink-the-image/` — **guided-lab**. Objetivo: < 100 MB sobre distroless, funcional.
  - `02-base-image-adr/` — **independent**. ADR escrita comparando bases.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia práctica entre `slim`, `alpine`, `distroless`, `chainguard`, `scratch`. Saber qué significa "la imagen no tiene shell" y qué implica para debug. Entender por qué pequeño no es sinónimo de seguro ni al revés. |
| Operativa | Construir imagen Python < 100 MB sobre distroless; medir tamaño y capas; comparar CVEs; copiar sólo lo necesario desde el builder stage. |
| Arquitectónica | Escribir una ADR que justifique la base elegida con trade-offs cuantificados (tamaño, cold-start, CVEs, dificultad de debug, compatibilidad con libs C). |

## Entregables

- Imagen `app:distroless` < 100 MB que corre `python -c 'print("ok")'` sin shell.
- ADR en Markdown (actividad 02) con benchmark de al menos 3 bases.

## Criterios de evaluación

- `tests/validate.sh` de la actividad 01 pasa: imagen final < 100 MB **y** sigue ejecutando la app.
- ADR cubre: contexto, opciones consideradas, decisión, consecuencias (positivas y negativas), métricas.
- Preguntas de reflexión respondidas (por qué distroless no tiene shell; por qué `alpine` rompe `cryptography`; cuándo elegirías `scratch`).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-slim-vs-alpine-vs-distroless/` y copia la tabla de tamaños.
3. Si tienes `dive`, haz `examples/02-dive-walkthrough/`; si no, lee el README (explica qué verías).
4. Reproduce `examples/03-scratch-with-static-binary/` (requiere `go` **o** usar la imagen `golang:alpine` como builder — el ejemplo usa la segunda vía para no depender del host).
5. Haz la actividad `01-shrink-the-image/`.
6. Haz la actividad `02-base-image-adr/` **sin consultar** el `solution/`.

## Siguiente

→ `dkr-12-multiarch-and-reproducibility`: construir estas imágenes para `amd64` + `arm64` y acercarse a builds reproducibles.
