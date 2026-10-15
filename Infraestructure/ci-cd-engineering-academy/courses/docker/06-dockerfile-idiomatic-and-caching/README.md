# dkr-06 — Dockerfile idiomatico y cache

## Identificacion

- **ID:** `dkr-06-dockerfile-idiomatic-and-caching`
- **Curso:** `docker`
- **Nivel:** intermedio
- **Duracion estimada:** 3 h
- **Prerrequisitos:** `dkr-03-images-dockerfile-basics`. Docker Engine ≥ 23 con BuildKit habilitado por default.

## Objetivo

Escribir Dockerfiles **rapidos, pequenos y mantenibles** aprovechando la cache de BuildKit. Al terminar debes poder tomar un Dockerfile que tarda minutos en reconstruir y, con una reordenacion minima, llevar el *rebuild caliente* (cambiar una linea de codigo) a menos de 5 segundos.

El modulo no busca que domines multi-stage (eso es `dkr-07`), sino la base: **la cache compara contexto + instruccion + hash de inputs, y cualquier cambio en una linea invalida todo lo que viene abajo**. Esa frase, bien entendida, decide la diferencia entre un pipeline de CI que corre en 20 segundos y uno que corre en 10 minutos.

## Alcance

Este modulo cubre:

- Como funciona exactamente la cache de capas en BuildKit.
- Orden canonico de instrucciones para apps interpretadas (Python/Node): base → system deps → lockfile → `pip/npm install` → codigo.
- Diferencia operativa entre `COPY` y `ADD` y por que la guia oficial recomienda `COPY`.
- Cuando combinar `RUN` con `&&` y cuando NO (BuildKit cambia los trade-offs clasicos).
- `--mount=type=cache` para persistir el cache de `pip`/`apt` entre builds.
- `ARG` (build-time, visible en `history`) vs `ENV` (runtime, persiste en la imagen).
- `HEALTHCHECK` para que el orquestador sepa cuando tu app esta *lista* y no solo *arrancada*.
- `LABEL` siguiendo los **OCI standard annotations** (`org.opencontainers.image.*`).
- Imagen funcional y **no interactiva** (`DEBIAN_FRONTEND=noninteractive`, `PYTHONUNBUFFERED=1`, `TZ`).

Lo que **no** cubre (viene despues):

- Multi-stage builds, cache mounts avanzados y secret mounts → `dkr-07`.
- Distroless, scratch, estrategia de base image → `dkr-11`.
- Multi-arch con `buildx` → `dkr-12`.

## Materiales

- **`theory/lesson.md`** — 12 secciones: modelo mental de la cache, orden canonico, `COPY` vs `ADD`, capas y `RUN`, cache mounts, `ARG` vs `ENV`, healthchecks, LABEL OCI, imagen no interactiva, anti-patrones, diagnostico con `docker history`, y preguntas de evaluacion.
- **`examples/`**:
  - `01-cache-friendly-python/` — app Python minima con el orden canonico. Incluye script para medir rebuild frio vs caliente.
  - `02-labels-oci-standard/` — Dockerfile con el set completo de labels OCI y verificacion con `docker inspect`.
- **`activities/`** (ambas guided-lab):
  - `01-measure-and-optimize-cache/` — recibes un Dockerfile mal ordenado, mides el rebuild, reordenas y demuestras la mejora.
  - `02-add-vs-copy/` — exploras los tres comportamientos de `ADD` (tar auto-extract, URL fetch, copia simple) y decides cuando cada uno es correcto.
- **`resources/links.md`** — docs oficiales, best practices, OCI annotations.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar sin consultar que entra en el hash de cache de una instruccion. Diferenciar `COPY` de `ADD` con los tres casos. Diferenciar `ARG` de `ENV` incluyendo que `ARG` queda en `history`. |
| Operativa | Reordenar un Dockerfile para que el rebuild caliente baje de minutos a segundos. Agregar un `HEALTHCHECK` correcto. Agregar los `LABEL` OCI estandar. Diagnosticar un Dockerfile ajeno con `docker history` y senalar el reorden minimo necesario. |
| Arquitectonica | Justificar por que `COPY . .` temprano es anti-patron. Decidir cuando usar `--mount=type=cache` y entender su impacto en reproducibilidad. |

## Criterios de evaluacion

- El Dockerfile final de `activities/01-measure-and-optimize-cache/` logra rebuild caliente (cambio en el codigo) en menos de 5 segundos y **no** reejecuta `pip install` (verificable con `docker history` + validador).
- La imagen de `activities/02-add-vs-copy/` justifica por escrito en cada caso por que uso `COPY` o `ADD`.
- Los validadores `tests/validate.sh` de ambas actividades pasan en una maquina con Docker instalado.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero antes de tocar la CLI.
2. Reproduce `examples/01-cache-friendly-python/` y mide los dos builds.
3. Reproduce `examples/02-labels-oci-standard/` e inspecciona los labels con `docker inspect`.
4. Resuelve `activities/01-measure-and-optimize-cache/` sin mirar la solucion.
5. Resuelve `activities/02-add-vs-copy/` y escribe la justificacion de cada decision.

## Siguiente

→ `dkr-07-multistage-buildkit-and-secrets`: separar build-time de runtime con stages, montar secrets sin filtrarlos a la imagen final, cache mounts avanzados.
