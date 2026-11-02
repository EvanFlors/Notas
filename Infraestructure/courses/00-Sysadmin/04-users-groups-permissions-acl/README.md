# sys-04 — Usuarios, grupos, permisos y ACL

## Identificación

- **ID:** `sys-04-users-groups-permissions-acl`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-03` (sistema de archivos y procesos). Línea de comandos cómoda, acceso `sudo` a una VM Linux descartable.

## Objetivo

Modelar **quién puede hacer qué** en un sistema Linux combinando los tres mecanismos que coexisten: **DAC** (Discretionary Access Control) clásico POSIX, **POSIX ACL** cuando el modelo `user/group/other` no alcanza, y **sudoers** para elevar privilegios de forma mínima. Al terminar deberías poder diseñar la política de acceso de un equipo real (varios usuarios, un directorio compartido, un servicio con permisos acotados) y defenderla frente a alternativas inseguras (p. ej. `chmod 777`, `sudo ALL=ALL`, binarios setuid genéricos).

## Alcance

Este módulo cubre:

- Identidad en Linux: `/etc/passwd`, `/etc/shadow`, `/etc/group`, UID/GID, usuarios de sistema vs humanos, cuentas de servicio.
- Gestión de cuentas: `useradd` / `usermod` / `userdel` / `groupadd` / `gpasswd`, `passwd`, política de expiración con `chage`.
- Permisos POSIX: `rwx` sobre archivos y directorios (ojo con el bit `x` en directorios), bits especiales **setuid**, **setgid**, **sticky**; `chmod` numérico y simbólico, `umask`, `chown`, `chgrp`.
- POSIX ACL: `getfacl`, `setfacl`, entradas `default:`, el papel de la **mask**, interacción con `chmod`.
- Elevación de privilegios: `sudo`, `/etc/sudoers`, `visudo`, el patrón `sudoers.d/`, `NOPASSWD`, `Cmnd_Alias`, logging a `auth.log` / `journalctl _COMM=sudo`.
- **Linux capabilities** (`setcap`, `getcap`, `capsh`) como alternativa moderna a `setuid root`.
- Camino de resolución en el kernel: **DAC → ACL → MAC** (SELinux/AppArmor como veremos en `sys-06`), y por qué un `root` no siempre lo puede todo.

Lo que **no** cubre (se verá después):

- SELinux / AppArmor en profundidad → `sys-06`.
- PAM (autenticación pluggable), LDAP, SSSD → `sys-07`.
- Autenticación SSH y hardening → `sys-08`.

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones) con ejemplos trabajados: grupo `developers` con directorio compartido vía setgid, regla sudoers para un único `systemctl`, capability `cap_net_bind_service` reemplazando setuid.
- **`examples/`** — ejemplos reproducibles:
  - `01-setgid-shared-dir/` — crear `/srv/team` con setgid + ACL default para que todo lo nuevo herede grupo y permisos correctos.
  - `02-sudoers-least-privilege/` — fragmento `sudoers.d` que concede sólo `systemctl restart nginx` a un grupo.
- **`activities/`** — dos actividades:
  - `01-user-model-for-a-team/` (arquitectura, 60 min) — a partir de una spec de equipo, diseñar y aplicar grupos, usuarios y permisos.
  - `02-sudoers-least-privilege/` (debug, 45 min) — arreglar un `sudoers.d` roto que `visudo -cf` rechaza y además viola el principio de mínimo privilegio.
- **`resources/links.md`** — man pages canónicas en man7.org.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia UID real / efectivo / guardado. Decir qué pasa cuando DAC y ACL contradicen al `other`. Justificar por qué `setuid` sobre un script shell es un bug de seguridad y no una característica. |
| Operativa | Crear usuarios con shell y home controlados; construir un directorio compartido que mantiene permisos al crear archivos; escribir una regla sudoers que `visudo -cf` acepta; sustituir un `setuid` por una capability. |
| Arquitectónica | Diseñar el modelo de acceso de un equipo con separación de funciones (devs, ops, auditores) sin recurrir a `chmod 777` ni a `sudo ALL=(ALL) NOPASSWD: ALL`. |

## Criterios de evaluación

- Actividad 1 pasa: el script de validación verifica que los usuarios, grupos y permisos quedaron como la spec pide (incluyendo setgid y ACL default heredada).
- Actividad 2 pasa: el fragmento sudoers corregido pasa `visudo -cf` **y** restringe al comando mínimo necesario.
- Respuesta razonada a: *"¿por qué `chmod -R 777 /srv/team` 'funciona' pero es siempre la respuesta equivocada?"* y *"¿cuándo elegirías una capability frente a `sudo`?"*.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar).
2. Reproduce `examples/01-setgid-shared-dir/` en una VM: observa qué pasa con y sin el bit setgid.
3. Reproduce `examples/02-sudoers-least-privilege/` y confirma con `sudo -l` como usuario destinatario.
4. Haz `activities/01-user-model-for-a-team/` (es la que valida que entendiste el modelo).
5. Haz `activities/02-sudoers-least-privilege/` (debug + least privilege).
6. Vuelve a la lección y responde las preguntas de evaluación finales sin consultar.

## Siguiente

→ `sys-05-package-management-and-services`: gestión de paquetes, unidades systemd y arranque de servicios con el usuario de sistema correcto.
