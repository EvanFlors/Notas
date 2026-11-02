# Recursos — sys-04

## Man pages canónicas (man7.org)

- **`credentials(7)`** — identidades de proceso (UID real/efectivo/guardado, GID, grupos suplementarios): <https://man7.org/linux/man-pages/man7/credentials.7.html>
- **`capabilities(7)`** — lista y semántica de las capabilities de Linux: <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- **`sudoers(5)`** — gramática completa de `/etc/sudoers` y de los archivos en `/etc/sudoers.d/`: <https://man7.org/linux/man-pages/man5/sudoers.5.html>
- **`acl(5)`** — Access Control Lists POSIX en Linux (mask, default ACL, interacción con `chmod`): <https://man7.org/linux/man-pages/man5/acl.5.html>

## Man pages de herramientas

- `useradd(8)` — <https://man7.org/linux/man-pages/man8/useradd.8.html>
- `usermod(8)` — <https://man7.org/linux/man-pages/man8/usermod.8.html>
- `userdel(8)` — <https://man7.org/linux/man-pages/man8/userdel.8.html>
- `groupadd(8)` — <https://man7.org/linux/man-pages/man8/groupadd.8.html>
- `passwd(1)` — <https://man7.org/linux/man-pages/man1/passwd.1.html>
- `chage(1)` — <https://man7.org/linux/man-pages/man1/chage.1.html>
- `chmod(1)` — <https://man7.org/linux/man-pages/man1/chmod.1.html>
- `chown(1)` — <https://man7.org/linux/man-pages/man1/chown.1.html>
- `umask(1p)` — <https://man7.org/linux/man-pages/man1/umask.1p.html>
- `getfacl(1)` — <https://man7.org/linux/man-pages/man1/getfacl.1.html>
- `setfacl(1)` — <https://man7.org/linux/man-pages/man1/setfacl.1.html>
- `sudo(8)` — <https://man7.org/linux/man-pages/man8/sudo.8.html>
- `visudo(8)` — <https://man7.org/linux/man-pages/man8/visudo.8.html>
- `setcap(8)` — <https://man7.org/linux/man-pages/man8/setcap.8.html>
- `getcap(8)` — <https://man7.org/linux/man-pages/man8/getcap.8.html>
- `capsh(1)` — <https://man7.org/linux/man-pages/man1/capsh.1.html>

## Archivos de configuración

- `passwd(5)` — formato de `/etc/passwd`: <https://man7.org/linux/man-pages/man5/passwd.5.html>
- `shadow(5)` — formato de `/etc/shadow`: <https://man7.org/linux/man-pages/man5/shadow.5.html>
- `group(5)` — formato de `/etc/group`: <https://man7.org/linux/man-pages/man5/group.5.html>
- `login.defs(5)` — defaults de `useradd`, umask del sistema, política de UID: <https://man7.org/linux/man-pages/man5/login.defs.5.html>

## Lectura complementaria

- **"Setuid demystified"** (Chen, Wagner, Dean; USENIX 2002) — por qué setuid es un campo de minas y por qué existen capabilities. Papel clásico y aún vigente.
- **systemd security directives** — `AmbientCapabilities=`, `CapabilityBoundingSet=`, `NoNewPrivileges=`, `User=`: <https://www.freedesktop.org/software/systemd/man/systemd.exec.html>
- **Pro Linux System Administration** (Turnbull, Matotek, Lieverdink) — capítulo de usuarios y permisos, buena referencia operativa.

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4. Todos los enlaces son dominios oficiales (`man7.org`, `freedesktop.org`); verificar disponibilidad al momento de producción.
