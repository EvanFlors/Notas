# sys-06 — Gestión de paquetes y upgrades

## Identificación

- **ID:** `sys-06-package-management-upgrades`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-04-users-groups-permissions-acl` (uso correcto de `sudo`, propietarios de archivos del sistema).

## Objetivo

Instalar, actualizar y **pinnear** software en las tres familias dominantes de distribuciones Linux —Debian/Ubuntu, RHEL-family (Fedora/RHEL/Rocky/Alma) y Alpine— con la **mínima rotura posible**, verificando siempre la autenticidad del origen (firmas GPG) y teniendo un camino de **rollback** listo antes de pulsar Enter.

Al terminar deberías poder añadir un repositorio de terceros firmado, instalar un paquete, dejarlo pinneado a una versión concreta, aplicar un upgrade de seguridad y revertirlo si rompe el servicio.

## Alcance

Este módulo cubre:

- Modelo **deb**: `apt` (frontend de alto nivel) vs. `dpkg` (herramienta de bajo nivel), repositorios `.list`/`.sources`, PPAs, firma GPG con el patrón moderno `signed-by=` en `/etc/apt/keyrings/`.
- Modelo **rpm**: `dnf` (y `dnf5` en Fedora ≥ 41), `rpm`, `.repo` files, módulos (`dnf module`), `dnf history` y `dnf history undo`.
- Modelo **apk** de Alpine: `apk add`, `--no-cache`, `/etc/apk/repositories`, `/etc/apk/keys/`.
- **Firmas GPG** de repositorios: por qué, cómo verificar el *fingerprint* antes de confiar, dónde se guardan las claves.
- **Pinning / hold**: `apt-mark hold`, `/etc/apt/preferences.d/`, `dnf versionlock`.
- **Upgrades**: diferencia entre `apt upgrade` y `apt full-upgrade` (antes `dist-upgrade`), `dnf upgrade --security`, `unattended-upgrades`.
- **Rollback**: `dnf history undo <id>`, limitaciones en apt, snapshots de FS como red de seguridad (btrfs/LVM — mencionado, se profundiza en `sys-08`).
- **Supply-chain**: por qué `curl … | sudo bash` es un anti-patrón y qué hacer en su lugar.

Lo que **no** cubre (se verá después):

- Compilar desde fuentes y empaquetar (`.deb`/`.rpm`/`APKBUILD`) → fuera del scope del curso.
- Snapshots de filesystem para rollback atómico → `sys-08-storage-volumes-and-lvm`.
- `unattended-upgrades` orquestado a escala → `sys-17-config-management`.

## Materiales

- **`theory/lesson.md`** — lección completa (~500 líneas) con tabla comparativa apt/dnf/apk, procedimiento de alta de repo firmado en Debian y RHEL, demo de rollback.
- **`examples/`**
  - `01-add-signed-repo/` — alta de un repositorio Debian con el patrón `/etc/apt/keyrings/` + `signed-by=`.
  - `02-dnf-history-rollback/` — ver el historial, deshacer una transacción.
- **`activities/`**
  - `01-add-third-party-repo-safely/` — guided-lab, 50 min. Añadir un repo de terceros verificando el *fingerprint* GPG antes de confiar.
  - `02-rollback-a-bad-upgrade/` — debug, 45 min. Simular una regresión tras upgrade y revertir con `dnf history undo`.
- **`resources/links.md`** — Debian wiki SecureApt, dnf docs, Alpine wiki, Reproducible Builds.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `apt upgrade` y `apt full-upgrade`, qué garantiza la firma GPG de un repo (y qué no), y por qué `curl \| sudo bash` es inseguro aunque la URL sea HTTPS. |
| Operativa | Añadir un repo de terceros con clave en `/etc/apt/keyrings/`, pinnear un paquete, aplicar únicamente parches de seguridad y revertir una transacción con `dnf history undo`. |
| Arquitectónica | Diseñar una ventana de upgrade con snapshot previo, criterio de rollback y lista de servicios a validar después. |

## Criterios de evaluación

- Repo de terceros añadido con clave propia en `/etc/apt/keyrings/` (no en `/etc/apt/trusted.gpg.d/` legacy), *fingerprint* verificado manualmente contra la fuente oficial.
- Al menos un paquete pinneado (`apt-mark hold` o `dnf versionlock`).
- Transacción revertida con `dnf history undo` y servicio verificado funcionando.
- Respuesta argumentada: ¿por qué `apt upgrade` nunca eliminaría un paquete y `apt full-upgrade` sí puede hacerlo?

## Entorno recomendado

Las actividades requieren una **VM o contenedor desechable** (no tu máquina principal). Opciones:

- VM: Debian 12, Ubuntu 24.04, Rocky/Alma 9 o Fedora 41 en VirtualBox/UTM/libvirt.
- Contenedor: `docker run --rm -it debian:12` / `rockylinux:9` / `alpine:3.20` (suficiente para los ejemplos, limitado para `systemctl` — se marca cuando aplica).

> **No ejecutes nada del módulo en producción sin leer la actividad entera antes.**

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-add-signed-repo/` en una VM Debian/Ubuntu.
3. Reproduce `examples/02-dnf-history-rollback/` en una VM/contenedor RHEL-family.
4. Haz la actividad `activities/01-add-third-party-repo-safely/`.
5. Haz la actividad `activities/02-rollback-a-bad-upgrade/`.
6. Responde las preguntas finales de la lección.

## Siguiente

→ `sys-07-boot-process-and-systemd`: boot moderno y gestión de servicios con systemd (necesario para verificar que los paquetes que acabas de instalar realmente arrancan).
