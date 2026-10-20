# dkr-04 — Storage: volúmenes, bind mounts y tmpfs

## Identificación

- **ID:** `dkr-04-storage-volumes-bind-mounts-tmpfs`
- **Curso:** `docker`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `dkr-02-install-engine-and-first-container`.

## Objetivo

Persistir y compartir estado desde contenedores de forma correcta, reproducible y segura: elegir entre **volumen nombrado**, **bind mount** y **tmpfs** con criterio, entender el modelo de permisos (UID/GID host vs contenedor) y nunca escribir datos de aplicación en el filesystem *de la imagen*.

## Alcance

Este módulo cubre:

- Por qué el filesystem del contenedor es **efímero** (overlayfs upperdir se descarta con el contenedor).
- Las tres primitivas de mount que ofrece Docker: `volume` | `bind` | `tmpfs`.
- CLI de volúmenes: `docker volume create|ls|inspect|rm|prune`.
- Flags de `-v` / `--mount` y diferencias de sintaxis.
- Modificadores: `:ro` (read-only), `:z` / `:Z` (etiquetado SELinux).
- Permisos: UID/GID *dentro* del contenedor vs UID/GID del host sobre bind mounts.
- Drivers de volumen (local, nfs, cifs, csi en orquestadores).
- Backups con `docker run --rm -v vol:/data busybox tar ...`.
- Anti-patrones: datos en la imagen, bind mount a `/etc`, `docker.sock` en contenedores no confiables.

Lo que **no** cubre (viene luego):

- Compose + volúmenes declarativos → `dkr-08`.
- Overlayfs al detalle (`lowerdir` / `upperdir` / `merged` / `workdir`) → `dkr-10`.
- Volumes como CSI de Kubernetes → curso **kubernetes**.

## Materiales

- **`theory/lesson.md`** — 12 secciones.
- **`examples/`**:
  - `01-named-volume-postgres/` — Postgres con volumen nombrado; datos sobreviven a `docker rm`.
  - `02-bind-mount-dev-code/` — código Python bind-mounted en el contenedor para iterar sin rebuild.
- **`activities/`**:
  - `01-persist-postgres-data/` — guided lab. Crea Postgres con volumen, inserta datos, destruye el contenedor, recrea y verifica persistencia.
  - `02-fix-permissions-on-bind-mount/` — independent debug. El contenedor corre fijo como UID 1000; el host monta un directorio del que ese UID no puede escribir. Diagnosticar y arreglar.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué los datos en el filesystem de la imagen se pierden al borrar el contenedor. Diferenciar volume / bind / tmpfs y cuándo usar cada uno. Entender que el UID *dentro* del contenedor es un número literal mapeado al mismo UID del host. |
| Operativa | Crear, inspeccionar y borrar volúmenes. Montar directorios del host como bind. Hacer backup y restore de un volumen con `tar`. Diagnosticar un `Permission denied` sobre un bind mount. |
| Arquitectónica | Diseñar el storage de un servicio stateful (DB, cola, cache) decidiendo cada mount con justificación de rendimiento, portabilidad y seguridad. |

## Entregables

- Postgres con datos persistidos entre `docker rm` y `docker run` del contenedor, demostrado con una tabla propia.
- Script de backup y restore de un volumen vía `tar`.
- Reporte breve de la actividad 2: qué pasó, por qué, cuál fue el fix y qué alternativas había.

## Criterios de evaluación

- **Conceptual**: dado un escenario (DB en prod, hot-reload en dev, caché temporal), proponer el mount correcto y justificar.
- **Operativa**: `scripts/validate-activities.py` pasa; validadores de ambas actividades OK.
- **Arquitectónica**: identificar al menos tres riesgos de bind mounts en producción.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-named-volume-postgres/` paso a paso.
3. Reproduce `examples/02-bind-mount-dev-code/`.
4. Haz `activities/01-persist-postgres-data/` (guided).
5. Haz `activities/02-fix-permissions-on-bind-mount/` (debug, sin ver la solución primero).
6. Responde las preguntas de evaluación de la lección.

## Siguiente

→ `dkr-05-networking-basics`.
