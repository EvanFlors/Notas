# dkr-03 — Images y Dockerfile: fundamentos

## Identificación

- **ID:** `dkr-03-images-dockerfile-basics`
- **Curso:** `docker`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `dkr-02-install-engine-and-first-container`.

## Objetivo

Construir imágenes propias y leer imágenes ajenas. Al terminar debes poder escribir
un `Dockerfile` correcto para una app Python/FastAPI mínima, interpretar la salida
de `docker history`, y defender decisiones sobre `CMD` vs `ENTRYPOINT`, forma
shell vs exec, y `USER` no-root.

## Alcance

Este módulo cubre:

- Operaciones sobre imágenes: `docker pull`, `push`, `images`, `inspect`, `history`.
- El modelo de **capas** (layers) y de **digests** inmutables.
- Anatomía del `Dockerfile`: `FROM`, `WORKDIR`, `COPY`, `RUN`, `CMD`, `ENTRYPOINT`,
  `EXPOSE`, `USER`, `ENV`, `ARG`.
- La diferencia **shell form vs exec form** y por qué importa para señales (PID 1).
- `CMD` como **argumentos por default** de `ENTRYPOINT`.
- `.dockerignore` y su impacto en tamaño de contexto y caché.
- `docker build -t`, `tags` vs `digests`.
- Por qué correr como no-root (`USER appuser`).

Lo que **no** cubre (viene después):

- Técnicas de caché avanzadas y orden de instrucciones → `dkr-06`.
- Builds multi-stage y BuildKit (cache mounts, secret mounts) → `dkr-07`.
- Publicación a registries, política de tagging profesional → `dkr-09`.
- Hardening de runtime (capabilities, seccomp, read-only FS) → `dkr-13`.
- SBOM, firma, provenance → `dkr-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (3 h de lectura + exploración).
- **`examples/`**:
  - `01-dockerfile-python-app/` — Dockerfile mínimo para una app FastAPI; walkthrough instrucción por instrucción.
  - `02-entrypoint-vs-cmd/` — cuatro variantes del mismo contenedor demostrando shell vs exec y la interacción `ENTRYPOINT`/`CMD`.
  - `03-dockerignore-impact/` — mismo build con y sin `.dockerignore`; muestra el impacto en el tamaño del contexto y en la caché.
- **`activities/`**:
  - `01-build-your-first-image/` — **guided-lab**. Construye tu propia imagen de FastAPI que arranca, responde `/healthz`, corre como no-root y pasa `docker run --rm <image> echo ok`.
  - `02-fix-signal-handling/` — **independent / debug**. Un contenedor con `ENTRYPOINT` en forma shell no termina ante `SIGTERM`; identifica la causa, aplica la mínima corrección (exec form o `--init`), y demuestra que ahora termina en < 2 s.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es una capa y qué la invalida en la caché. Diferenciar `CMD` de `ENTRYPOINT` y shell form de exec form. Decir qué hace `/bin/sh -c` con las señales de PID 1. Diferenciar `ARG` (build-time) de `ENV` (runtime). Explicar la diferencia entre un tag mutable (`:3.12`) y un digest inmutable (`@sha256:…`). |
| Operativa | Escribir un `Dockerfile` correcto para una app Python/FastAPI. Interpretar `docker history --no-trunc`. Depurar un contenedor que no responde a `docker stop`. Usar `.dockerignore` para reducir el contexto de build. |
| Arquitectónica | Justificar por qué `USER <nonroot>` es un control de defensa en profundidad. Elegir entre `CMD` solo, `ENTRYPOINT` solo, o la combinación según el patrón "contenedor como binario" vs "contenedor como entorno". |

## Criterios de evaluación

- Diferenciar `CMD` vs `ENTRYPOINT`, shell vs exec form, con un ejemplo correcto de cada combinación.
- Justificar por escrito el uso de `USER` no-root (y qué controla y qué no).
- Imagen de FastAPI construye, arranca, responde HTTP 200 en `/healthz`, corre como UID distinto de 0, y responde a `docker stop` en < 2 s.
- `docker history` de la imagen es legible y sin capas sorpresa (sin `apt-get` olvidado, sin secretos filtrados).
- `tests/validate.sh` de cada actividad pasa.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo, sin consultar nada externo.
2. Reproduce los tres `examples/` en orden; para cada uno, ejecuta `docker history` y `docker inspect` y predice las diferencias antes de verlas.
3. Haz la actividad `01-build-your-first-image/`. Compara tu Dockerfile con `solution/` solo al final.
4. Haz la actividad `02-fix-signal-handling/` **sin leer la solución**. Es la que valida comprensión real de PID 1 + señales + shell form.
5. Responde las preguntas de evaluación del final de la lección.

## Entregables

- Imagen funcional de una app FastAPI mínima (`docker run -p 8000:8000 <image>` responde HTTP 200 en `/healthz`), bajo cualquier tag local.
- Notas con la salida comentada de `docker history --no-trunc <image>` y de `docker image inspect <image>`.

## Siguiente

→ `dkr-04-storage-volumes-bind-mounts-tmpfs`: persistir estado correctamente (volúmenes nombrados vs bind mounts vs tmpfs).
