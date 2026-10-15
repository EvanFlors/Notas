# dkr-01 — Modelo mental y OCI

## Identificación

- **ID:** `dkr-01-mental-model-and-oci`
- **Curso:** `docker`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** nociones básicas de procesos y filesystem en Linux (T-2.1, T-2.2, T-2.4).

## Objetivo

Construir el **modelo mental correcto** de contenedores *antes* de tocar la CLI de Docker: qué es realmente un contenedor, qué **no** es, por qué OCI (Open Container Initiative) importa, y cómo encaja la pila `Docker → containerd → runc` sobre las primitivas del kernel de Linux.

Al terminar este módulo deberías poder, sin consultar docs:

- Explicar la diferencia entre una **VM** y un **contenedor** en términos del kernel.
- Enumerar los namespaces que aisla un contenedor estándar (PID, mount, net, user, uts, ipc, cgroup) y qué hace cada uno.
- Explicar qué es un **cgroup** y para qué sirve.
- Diferenciar **imagen OCI** (datos) de **runtime OCI** (quien ejecuta).
- Diferenciar un **runtime de alto nivel** (`containerd`) de uno **de bajo nivel** (`runc`).
- Describir qué contiene un **manifest OCI** (schemaVersion, mediaType, config, layers[], digests).

Este módulo es deliberadamente **"antes de instalar nada"**: casi todo el contenido se puede completar sin Docker. Instalación y primer contenedor se cubren en `dkr-02`.

## Alcance

Este módulo cubre:

- VMs vs contenedores: hypervisor vs kernel compartido.
- Intuición de **namespaces** (PID, mount, net, user, uts, ipc, cgroup) con analogías.
- **cgroups** v2 como mecanismo de límites (CPU, memoria, pids, io).
- **overlayfs** como filesystem copy-on-write para capas.
- **OCI image-spec** (manifest, config, layers), **runtime-spec**, **distribution-spec**.
- Relación conceptual **Docker CLI → dockerd → containerd → runc**.
- Un contenedor como "proceso Linux normal con restricciones adicionales".

Lo que **no** cubre (vendrá después):

- Instalación de Docker Engine / Desktop, ciclo de vida (`run`, `ps`, `logs`, ...) → `dkr-02`.
- Escribir Dockerfiles → `dkr-03`.
- Internals ejecutables (`unshare`, `nsenter`, inspección manual de cgroups) → `dkr-10`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (≈ 2 h de lectura reflexiva).
- **`examples/`** — ejemplos conceptuales (no requieren Docker):
  - `01-processes-vs-containers/` — diagramas ASCII comparando un proceso Linux normal, un contenedor y una VM.
  - `02-oci-manifest-walkthrough/` — recorrido comentado por un manifest OCI real (ejemplo capturado).
- **`activities/`** — dos actividades:
  - `01-draw-namespaces-and-cgroups/` — **independent, conceptual**. Produce un `MAP.md` que describe cada namespace, cada controlador de cgroup, y la pila `Docker → containerd → runc`.
  - `02-oci-manifest-reading/` — **guided-lab**. Inspeccionar un manifest OCI real (muestra enviada en `starter/`, o uno pulled con Docker si está disponible) y producir un `WRITEUP.md` identificando los campos clave.
- **`resources/links.md`** — specs OCI, Pro Git-style readings, blog posts verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar la diferencia VM / contenedor, qué namespaces usa un contenedor estándar, qué resuelve cgroups, y qué tres specs forman OCI. |
| Operativa | Leer un manifest OCI y señalar `schemaVersion`, `mediaType`, `config`, `layers[]`, cada `digest`. Identificar en `/proc/<pid>/ns/` qué namespaces están aislados (requiere Linux; opcional). |
| Arquitectónica | Dado un stack de ejecución (Docker/containerd/runc, Podman/crun, nerdctl/containerd/runc), ubicar quién hace cada paso. Justificar por qué el estándar OCI permite intercambiar piezas. |

## Criterios de evaluación

- Lección leída y preguntas de evaluación respondidas (`theory/lesson.md` §12).
- Actividad 01 entregada: `MAP.md` describe los 7 namespaces, 4 controladores de cgroup y la pila Docker→runc.
- Actividad 02 entregada: `WRITEUP.md` identifica los campos clave de un manifest OCI real.
- `tests/validate.sh` de cada actividad pasa.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Reproduce mentalmente `examples/01-processes-vs-containers/` — contrasta los diagramas con lo leído.
3. Recorre `examples/02-oci-manifest-walkthrough/` — mapa de cada campo del manifest.
4. Haz la actividad `01-draw-namespaces-and-cgroups/` — es la que valida comprensión conceptual.
5. Haz la actividad `02-oci-manifest-reading/` — practica leer un artefacto real.
6. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `dkr-02-install-engine-and-first-container`: instalar Docker (o alternativa compatible), entender arquitectura cliente/daemon, operar el ciclo de vida de un contenedor desde la CLI.
