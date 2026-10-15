# dkr-10 — Internals: namespaces, cgroups, overlayfs

## Identificación

- **ID:** `dkr-10-internals-namespaces-cgroups-overlayfs`
- **Curso:** `docker`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `dkr-01-mental-model-and-oci`, `dkr-02-install-engine-and-first-container`, T-2 Linux (procesos, filesystem, permisos).

> **Linux-only.** Las primitivas (`unshare`, `nsenter`, `/proc/<pid>/ns/*`, `/sys/fs/cgroup/`, `overlayfs`) viven en el kernel de Linux. En **macOS** y **Windows** Docker Desktop ejecuta estos labs *dentro* de una VM Linux; para los ejercicios de este módulo necesitas **shell dentro de esa VM** o una VM propia (`multipass launch --name dkr10 22.04` o `vagrant up ubuntu/jammy64`). Los validators detectan el SO con `uname -s` y hacen `SKIP` grácil en Darwin/Windows con instrucciones.

## Objetivo

Ver el contenedor **desde el kernel**, no desde la CLI. Al terminar deberías poder explicar sin consultar docs qué namespaces aisla un contenedor estándar, cuáles no, y por qué un contenedor "rooteado" sigue sin ser root del host.

## Alcance

Este módulo cubre:

- Las 7 clases de namespaces Linux (`mnt`, `pid`, `net`, `ipc`, `uts`, `user`, `cgroup`) y cómo se inspeccionan vía `/proc/<pid>/ns/*`, `lsns` y `nsenter`.
- `cgroups v2`: jerarquía unificada en `/sys/fs/cgroup/`, controladores (`cpu`, `memory`, `pids`, `io`) y la traducción directa de `--cpus` y `--memory` a `cpu.max` / `memory.max`.
- **overlayfs**: `lowerdir`, `upperdir`, `merged`, `workdir`; cómo cada `RUN` del Dockerfile corresponde a un lower, y por qué el upper es efímero.
- **Capabilities**: qué deja caer Docker por default y por qué `root` dentro de un contenedor estándar no puede hacer `tcpdump` sin `--cap-add=NET_RAW`.
- **Seccomp**: el perfil default bloquea ~44 syscalls peligrosos; `--security-opt seccomp=unconfined` los re-habilita (y por qué eso duele).
- **User namespaces**: mapeo `uid_map`/`gid_map`; qué resuelve y qué no.
- Replicar manualmente un "mini-contenedor" con `unshare -Umnpf` + `chroot` + `cgcreate` para destripar qué hace `runc`.

Lo que **no** cubre (va en módulos posteriores):

- Hardening operativo completo (perfiles seccomp custom, AppArmor, rootless) → `dkr-13`.
- Supply chain (SBOM, firma, provenance) → `dkr-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-manual-mini-container/` — construir un mini-contenedor a mano con `unshare` + `chroot` + `cgcreate`.
  - `02-inspect-overlay-layers/` — recorrido guiado por `lowerdir`/`upperdir`/`merged`/`workdir`.
  - `03-capabilities-dropped/` — mismo binario, un contenedor sin `NET_RAW` y otro `--privileged`.
- **`activities/`**:
  - `01-build-container-with-unshare/` — guiada, Linux-only; macOS → VM.
  - `02-why-is-my-app-oomkilled/` — debug independiente de un contenedor con `--memory=64m`.
- **`resources/links.md`** — docs del kernel y runc.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar los 7 namespaces, decir cuáles aisla `docker run` default (todos menos `user` por default en Docker Engine) y cuáles no. Explicar la diferencia entre capability y syscall. |
| Operativa | Inspeccionar namespaces y cgroups de un contenedor en vivo. Diagnosticar `OOMKilled` leyendo `State.ExitCode=137`, `OOMKilled=true` y `memory.events`. Montar un overlay a mano. |
| Arquitectónica | Justificar por qué `--privileged` **no** es "root": enumera literalmente qué habilita (todas las caps + sin seccomp + sin AppArmor + acceso a devices). Diseñar la lista mínima de caps para una app. |

## Criterios de evaluación

- Puedes **replicar un mini-contenedor** con `unshare -Umnpf --mount-proc` + `chroot` + un cgroup v2 con límite de memoria aplicado.
- Explicas la ruta `OOMKilled` end-to-end: límite en `memory.max`, el kernel OOM-killer dispara, `runc` reporta `ExitCode=137` (128 + 9/SIGKILL).
- Explicas qué significa `lowerdir=L1:L2:L3,upperdir=U,workdir=W,merged=M` y qué pasa al escribir un archivo que ya existe en `L2` (copy-up al `U`).
- Enumeras los namespaces aislados por un `docker run` default y los que **no** (`user` por default en Docker Engine salvo configurar `userns-remap`; `time` namespace tampoco se usa).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-manual-mini-container/` dentro de una VM Linux. Lee cada comando.
3. Reproduce `examples/02-inspect-overlay-layers/` sobre una imagen real.
4. Reproduce `examples/03-capabilities-dropped/`.
5. Haz la actividad `activities/01-build-container-with-unshare/` (guiada, con validator).
6. Haz `activities/02-why-is-my-app-oomkilled/` **sin leer la solución** (es independiente).
7. Responde las preguntas de evaluación del final de la lección sin consultar.

## Siguiente

→ `dkr-11-image-optimization-and-base-image-strategy`: elegir base image con criterio (slim / alpine / distroless / chainguard / scratch).
