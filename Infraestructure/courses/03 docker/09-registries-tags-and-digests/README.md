# dkr-09 — Registries, tags y digests

## Identificación

- **ID:** `dkr-09-registries-tags-and-digests`
- **Curso:** `docker`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `dkr-03-images-dockerfile-basics` (saber construir una imagen propia y leer `docker history`/`docker inspect`). Idealmente también `dkr-02` (ciclo de vida) y nociones de Git.

## Objetivo

Publicar y consumir imágenes de forma **responsable y reproducible**. Al terminar sabrás diferenciar un **tag mutable** de un **digest inmutable**, diseñar una política de tagging defendible (`latest`, `v1`, `v1.2`, `v1.2.3`, `sha-<git>`), elegir el registry adecuado (Docker Hub, GHCR, ECR, Artifact Registry, Harbor), autenticarte, publicar a GHCR desde GitHub Actions, y justificar por qué `FROM python:3-slim` en producción es un riesgo.

## Alcance

Este módulo cubre:

- `docker login` y los distintos registries (Docker Hub, GHCR, ECR, Artifact Registry, Harbor).
- Namespaces y visibilidad (público vs privado; `library/`, `<user>/`, `<org>/`, `ghcr.io/<owner>/`).
- **Tags vs digests**: por qué un tag es un alias mutable y un digest es inmutable (`image@sha256:...`).
- Estrategia de tagging: `latest`, `v1`, `v1.2`, `v1.2.3`, `sha-<git>`, `edge`, `pr-<n>`, `nightly`.
- Rate limits de Docker Hub (anónimo vs autenticado).
- Housekeeping: `docker image prune`, `docker system df`, `docker image rm`.
- Pull secrets (Kubernetes `imagePullSecrets`, `docker login` en CI).
- Publicar a GHCR desde Actions (con `GITHUB_TOKEN` / `permissions: packages: write`).

Lo que **no** cubre (vendrá después):
- Multi-arch y manifest lists → `dkr-12`.
- Firma, SBOM, attestations, provenance → `dkr-14`.
- Hardening de runtime → `dkr-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (3 h de lectura + exploración).
- **`examples/`** — ejemplos reproducibles (dual-mode `local` | `live`):
  - `01-push-to-ghcr/` — login, tag, push. En `MODE=local` usa un `registry:2` propio en `localhost:5000`; en `MODE=live` publica a GHCR.
  - `02-pin-by-digest/` — pullear por `image@sha256:...` en vez de por tag, y por qué eso vuelve el deploy reproducible.
- **`activities/`** — dos actividades:
  - `01-publish-and-consume-your-image/` — **guided-lab**, dual-mode. Construyes una imagen, la publicas, resuelves su digest, y la consumes por digest. En `MODE=local` todo pasa contra `localhost:5000`.
  - `02-tag-strategy-design/` — **independent**. Produces un ADR (`tag-strategy.md`) justificando política de tags para un escenario dado.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar qué es un digest, por qué un tag es mutable, y por qué dos `docker pull` del mismo tag en momentos distintos pueden traer bytes distintos. Describir los namespaces de GHCR, Docker Hub, ECR, Artifact Registry y Harbor. |
| Operativa | `docker login` a un registry; `docker tag` y `docker push`; resolver el digest con `docker inspect --format '{{index .RepoDigests 0}}'`; pullear por `@sha256:...`; limpiar con `docker image prune`. |
| Arquitectónica | Diseñar una política de tagging para un equipo (qué tags inmutables, qué tags móviles, qué pin usa producción, cuándo rota `latest`). Justificar la elección de registry por costo, latencia, control y auditoría. Justificar por qué `FROM python:3-slim` sin pin a digest es un riesgo. |

## Criterios de evaluación

- Imagen publicada (a GHCR en modo `live`, o a `localhost:5000` en modo `local`) con una política de tags explícita.
- `tests/validate.sh` de cada actividad pasa en `MODE=local`.
- Documento `tag-strategy.md` con decisiones (tags inmutables, mutables, pin de producción) y rationale.
- Explicación escrita de por qué `FROM python:3-slim` en producción es un riesgo (criterio de la lección).

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada, sin consultar).
2. Reproduce `examples/01-push-to-ghcr/` en `MODE=local`. Si tienes `gh auth`, repite en `MODE=live`.
3. Reproduce `examples/02-pin-by-digest/` en `MODE=local`.
4. Haz `activities/01-publish-and-consume-your-image/` en `MODE=local`.
5. Haz `activities/02-tag-strategy-design/` (ADR). No hay solución oculta: la calidad del rationale es lo que cuenta.
6. Responde la evaluación de la lección sin re-leer.

## Siguiente

→ `dkr-10-internals-namespaces-cgroups-overlayfs` para ver el contenedor desde el kernel.
→ `dkr-12-multiarch-and-reproducibility` cuando quieras publicar `linux/amd64 + linux/arm64` con manifest lists.
→ `dkr-14-supply-chain-sbom-signing-provenance` para firmar y verificar lo que publicaste.
