# sys-03 — Archivos Unix y filesystem

## Identificación

- **ID:** `sys-03-unix-files-and-filesystem`
- **Curso:** `00-Sysadmin`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-01` (introducción al shell), `sys-02` (comandos básicos y permisos).

## Objetivo

Interiorizar la idea Unix de que **"todo es un archivo"** —regulares, directorios, enlaces simbólicos, dispositivos de bloque y carácter, FIFOs y sockets— y navegar con criterio el layout del **Filesystem Hierarchy Standard (FHS 3.0)**. Al terminar deberías poder mirar la salida de `ls -l` o `stat` y explicar cada campo, y saber *dónde* vive cada tipo de cosa en el sistema.

## Alcance

Este módulo cubre:

- Los 7 tipos de archivo Unix y cómo distinguirlos (`-`, `d`, `l`, `b`, `c`, `p`, `s`).
- Inodos y dentries: qué es "nombre de archivo" vs "archivo".
- Hardlinks vs symlinks: cuándo usar cuál, qué pasa al borrar el original.
- `stat`, `ln`, `readlink`, `file`, `lsattr`.
- FHS 3.0: `/`, `/etc`, `/var`, `/usr`, `/opt`, `/home`, `/run`, `/tmp`, `/proc`, `/sys`, `/dev`.
- Pseudo-filesystems: `procfs` y `sysfs`.
- `find` con `-type`, `-name`, `-mtime`, `-size`, `-exec`, `-print0`.
- Idioma seguro `find … -print0 | xargs -0 …` frente a nombres con espacios, saltos de línea o unicode.
- `locate` / `mlocate` como índice complementario.
- VFS, mount points, superblock, y panorama de ext4 / xfs / btrfs.

Lo que **no** cubre (se verá después):

- Permisos avanzados, ACLs y capabilities → `sys-04`.
- Procesos y `/proc/<pid>` en profundidad → `sys-05`.
- Montaje de dispositivos y LVM → `sys-07`.

## Materiales

- **`theory/lesson.md`** — lección profunda en 11 secciones con tabla FHS, diagrama inodo/hardlink, recetas de `find` y tour de `/proc`.
- **`examples/`** — ejemplos demostrativos:
  - `01-inodes-and-links/` — observar inodos compartidos por hardlinks y rutas resueltas por symlinks.
  - `02-proc-tour/` — recorrer `/proc/self`, `/proc/cpuinfo` y los descriptores de un proceso.
- **`activities/`** — dos actividades:
  - `01-fhs-treasure-hunt/` — búsqueda guiada por el FHS (guided-lab, 60 min).
  - `02-safe-find-xargs/` — construir un `find-biggest.sh` robusto frente a nombres hostiles (independent, 45 min).
- **`resources/links.md`** — referencias oficiales (FHS, man7, kernel docs).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre inodo, dentry y nombre. Decir qué sobrevive al borrado del "original" en hardlinks vs symlinks. Justificar por qué `/proc` no gasta disco. |
| Operativa | Usar `stat` y `ls -li` para diagnosticar enlaces. Escribir un `find` que no se rompa con nombres raros. Localizar la configuración de un servicio sin consultar documentación interna. |
| Arquitectónica | Elegir dónde colocar un binario propio (`/usr/local/bin` vs `/opt/<producto>/bin` vs `~/.local/bin`) con criterio FHS. |

## Criterios de evaluación

- Capacidad de identificar los 7 tipos de archivo en una salida real de `ls -l`.
- Hardlink creado a mano, verificado por número de inodo compartido.
- Symlink creado y resuelto con `readlink -f`.
- Comando `find` con `-print0 | xargs -0` demostrado sobre un directorio con nombres hostiles.
- Respuestas argumentadas a las preguntas del final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Reproduce `examples/01-inodes-and-links/` paso a paso.
3. Haz la actividad `activities/01-fhs-treasure-hunt/`.
4. Lee y reproduce `examples/02-proc-tour/`.
5. Haz la actividad `activities/02-safe-find-xargs/` (es la que valida comprensión real).
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-04-users-groups-permissions`: usuarios, grupos, umask, setuid/setgid/sticky, ACLs y capabilities.
