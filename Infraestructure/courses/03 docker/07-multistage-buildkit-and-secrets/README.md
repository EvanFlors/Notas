# dkr-07 — Multi-stage, BuildKit y secrets

## Identificacion

- **ID:** `dkr-07-multistage-buildkit-and-secrets`
- **Curso:** `docker`
- **Nivel:** intermedio
- **Duracion estimada:** 4 h
- **Prerrequisitos:** `dkr-06-dockerfile-idiomatic-and-caching`. Docker Engine ≥ 23 con BuildKit habilitado por default (en Docker Desktop lo esta; en Linux moderno tambien).

## Objetivo

Dominar builds **multi-stage** con BuildKit, **secrets de build** y **cache mounts**. Al terminar, debes poder tomar un Dockerfile monolitico que arrastra todo el toolchain de compilacion dentro de la imagen final (y a veces un token en `docker history`) y transformarlo en una imagen productiva de **< 150 MB sin toolchain**, construida con cache compartido entre builds y sin filtrar ni un byte de secreto.

El modulo cierra la rama "builder" del curso (`dkr-03` → `dkr-06` → `dkr-07`) y abre la puerta a `dkr-11` (distroless/chainguard) y `dkr-12` (multi-arch con `buildx`).

## Alcance

Este modulo cubre:

- La directiva `# syntax=docker/dockerfile:1` y por que importa habilitar el frontend moderno.
- `FROM ... AS <stage>` para declarar stages nombrados; `COPY --from=<stage>` para traer solo lo necesario a la imagen final.
- Por que BuildKit construye un **DAG** y como paraleliza stages independientes.
- `--mount=type=cache,target=/root/.cache/pip` para reutilizar el cache de `pip` (o `apt`, `npm`, `go mod`) entre builds *sin* enterrarlo en una capa.
- `--mount=type=secret,id=<name>` para montar un secreto en `/run/secrets/<name>` durante un `RUN` sin que quede en ninguna capa.
- Por que `ARG` con un secreto es **anti-patron**: queda en `docker history` para siempre.
- `docker buildx` basico y la diferencia con `docker build` clasico.
- `--progress=plain` como herramienta de debug cuando el output "oculto" esconde el motivo real de un fallo o un cache miss.

Lo que **no** cubre (viene despues):

- Imagenes distroless, scratch, chainguard y la ADR de base image → `dkr-11`.
- Multi-arch (`--platform linux/amd64,linux/arm64`), manifest index, QEMU → `dkr-12`.
- Firma, SBOM, attestations, verificacion keyless → `dkr-14`.
- Supply chain de los secrets en CI (OIDC, `${{ secrets.X }}`) → `gha-05`.

## Materiales

- **`theory/lesson.md`** — 12 secciones: por que multi-stage, el DAG de BuildKit, sintaxis de stages, `COPY --from`, cache mounts, secret mounts, `ARG` como anti-patron, `buildx` vs `build`, `--progress=plain`, anti-patrones comunes, auditoria con `docker history`, preguntas de evaluacion.
- **`examples/`**:
  - `01-multistage-python-wheels/` — un stage `builder` compila wheels (pueden requerir `gcc`), un stage `runtime` slim solo los instala. Mide reduccion de tamano.
  - `02-buildkit-cache-mount/` — `--mount=type=cache,target=/root/.cache/pip` para reutilizar wheels descargados entre builds consecutivos despues de un `docker builder prune` parcial.
  - `03-secret-mount-git-token/` — `--mount=type=secret,id=github_token` para `git clone` de un repo privado durante el build, demostrando que el token NO aparece en `docker history`.
- **`activities/`**:
  - `01-rewrite-to-multistage/` — **guided-lab**. Recibes un Dockerfile monolitico (~400 MB con `gcc`, headers, dev libs) y lo reescribes a multi-stage para bajar de 150 MB.
  - `02-remove-leaked-secret-from-image/` — **independent, forensic**. Recibes un Dockerfile donde el autor paso un token con `ARG`/`ENV` y el token aparece en `docker history`. Debes migrar a `--mount=type=secret` y demostrar con el validador que ya no filtra.
- **`resources/links.md`** — docs oficiales, BuildKit, cache mounts, secret mounts, buildx.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar sin consultar por que BuildKit paraleliza stages independientes, que entra y que no en una capa cuando usas `--mount=type=secret`, y por que `ARG MY_TOKEN=...` siempre filtra. |
| Operativa | Reescribir un Dockerfile a multi-stage; agregar `--mount=type=cache` y `--mount=type=secret` correctamente; depurar con `--progress=plain` cuando algo no cachea; auditar con `docker history --no-trunc`. |
| Arquitectonica | Decidir que debe vivir en `builder` y que en `runtime` para una app Python con extensiones C. Justificar por que un pipeline que pasa secretos como `--build-arg` tiene un bug de seguridad, aunque "funcione". |

## Criterios de evaluacion

- **Entregable:** imagen final de `activities/01-rewrite-to-multistage/` con tamano **< 150 MB** y **sin** `gcc` ni headers de dev en la imagen final (verificable con `docker run --rm imagen which gcc`).
- `docker history` de la imagen de `activities/02-remove-leaked-secret-from-image/` **no** contiene el string del token (verificado por el validador).
- Ambos `tests/validate.sh` pasan en una maquina con Docker + BuildKit. Si Docker no esta instalado, el validador imprime `SKIP` y sale 0 (no bloquea CI del curso).

## Secuencia recomendada

1. Lee `theory/lesson.md` entero antes de tocar la CLI.
2. Reproduce `examples/01-multistage-python-wheels/` y mira la diferencia de tamano entre `builder` y `runtime` (`docker images`).
3. Reproduce `examples/02-buildkit-cache-mount/` haciendo dos builds consecutivos; verifica que el segundo pull de wheels es casi instantaneo.
4. Reproduce `examples/03-secret-mount-git-token/` con el `FAKE_TOKEN_xxxx` dummy; corre `docker history --no-trunc` y confirma que el token no esta.
5. Resuelve `activities/01-rewrite-to-multistage/` sin mirar la solucion.
6. Resuelve `activities/02-remove-leaked-secret-from-image/` como ejercicio **forense**: primero reproduce el leak, luego fix.

## Diagrama mental: BuildKit DAG

```
       ┌────────────────────┐
       │ FROM python:3.12   │  <── base (compartido)
       │  AS builder        │
       └─────────┬──────────┘
                 │ COPY requirements.txt
                 │ RUN pip wheel …     (produce /wheels)
                 ▼
       ┌────────────────────┐          ┌────────────────────┐
       │   stage: builder   │          │   stage: linter    │   (opcional,
       │   (toolchain, gcc) │          │   corre en paralelo)│    independiente)
       └─────────┬──────────┘          └────────────────────┘
                 │
                 │  COPY --from=builder /wheels /wheels
                 ▼
       ┌────────────────────┐
       │ FROM python:3.12-  │  <── runtime: slim, SIN gcc
       │   slim AS runtime  │
       │   pip install …    │
       └─────────┬──────────┘
                 ▼
          imagen final (< 150 MB)
```

## Siguiente

→ `dkr-08-compose-for-development`: pasa del *una imagen* a *stack local reproducible* con Compose v2 (app + Postgres + reverse proxy).
