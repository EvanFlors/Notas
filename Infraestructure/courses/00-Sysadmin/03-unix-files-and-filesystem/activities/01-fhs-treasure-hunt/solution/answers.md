# FHS treasure hunt — soluciones de referencia

> No consultar hasta tener respuestas propias. Las rutas pueden variar ligeramente por distro.

---

## Bloque A — FHS básico

### 1. Config de SSH servidor

- Comando: `ls -l /etc/ssh/sshd_config`
- Ruta: `/etc/ssh/sshd_config`
- Interpretación: `/etc` es config del sistema, texto plano. `ssh/` agrupa cliente (`ssh_config`) y servidor (`sshd_config`).

### 2. Logs del sistema

- Comando: `ls -lh /var/log/ | head`
- Ruta típica: `/var/log/syslog` (Debian/Ubuntu), `/var/log/messages` (RHEL), `/var/log/auth.log`.
- Interpretación: `/var` guarda estado variable; `log/` crece con el tiempo y suele rotarse.

### 3. Logs binarios de systemd

- Comando: `ls /var/log/journal/`
- Ruta: `/var/log/journal/<machine-id>/*.journal` (si está persistido) o `/run/log/journal/` (volátil).
- Interpretación: binario, se consulta con `journalctl`. Volátil en `/run` → desaparece al reiniciar si no se habilita persistencia.

### 4. Binario del shell

- Comando: `which bash && ls -l $(which bash)`
- Ruta: `/bin/bash` o `/usr/bin/bash` (según distro).
- Tipo: regular en distros con `usrmerge`; `/bin` puede ser symlink a `/usr/bin`.
- Interpretación: distros modernas (Fedora, Arch, Debian ≥12) hicieron `/bin → /usr/bin` para unificar.

### 5. Instalación local de un binario propio

- Ruta elegida: `/usr/local/bin/holamundo`
- Justificación: `/usr/local/` está reservado por FHS para software instalado por el admin; `apt`/`dnf` no lo tocan. Alternativa solo-usuario: `~/.local/bin/`.

### 6. Software de terceros embotellado

- Ruta: `/opt/google/chrome/`
- Interpretación: `/opt/<vendor>/<producto>/` para árboles auto-contenidos (binarios, libs, assets) que no se mezclan con `/usr`.

### 7. Estado persistente de servicios

- Ruta `dpkg`: `/var/lib/dpkg/` (status, info/, ...).
- Ruta PostgreSQL: `/var/lib/postgresql/<version>/main/` (Debian) o `/var/lib/pgsql/` (RHEL).
- Interpretación: `/var/lib/<servicio>/` es la convención FHS para estado persistente mutable.

### 8. Volátil en memoria

- Comando: `findmnt /run` o `mount | grep ' /run '`
- Tipo FS: `tmpfs` (RAM).
- Interpretación: `/run` se recrea en cada boot. Ideal para PID files, sockets de servicios, estado efímero (`/run/user/<uid>/` por usuario logueado).

---

## Bloque B — Pseudo-filesystems

### 9. CPU

- Comando: `grep 'model name' /proc/cpuinfo | head -1`
- Interpretación: `/proc/cpuinfo` lo sintetiza el kernel al leer; `ls -l` muestra 0 bytes aunque `cat` imprima texto.

### 10. `/proc/self`

- Comando: `readlink /proc/self`
- Observación: cada ejecución da un PID distinto.
- Interpretación: `self` resuelve al PID del proceso que hace la lectura. Cada `readlink` es un proceso nuevo (hijo del shell) con su propio PID.

### 11. Descriptores abiertos

- PID: ej. 12345
- `fd/0` → `/dev/pts/<N>` (stdin)
- `fd/1` → `/dev/pts/<N>` (stdout)
- `fd/2` → `/dev/pts/<N>` (stderr)
- Interpretación: cada FD abierto se expone como symlink al target real (file, pipe, socket, device).

### 12. MAC y MTU vía `/sys`

- Comando:
  ```bash
  IF=$(ip route show default | awk '{print $5; exit}')
  cat /sys/class/net/"$IF"/address
  cat /sys/class/net/"$IF"/mtu
  ```
- Interpretación: `/sys/class/net/<iface>/` publica el modelo de dispositivo del kernel; `ip` lee de ahí por debajo.

---

## Bloque C — Mounts

### 13. Montajes

- Comando: `findmnt` o `df -hT`
- FS raíz: `/`
- Tipo: típicamente `ext4` (Debian/Ubuntu), `xfs` (RHEL), `btrfs` (Fedora/openSUSE).

### 14. Hardlink entre mounts

- Comando: `ln /tmp/X /home/<user>/X`
- Error: `ln: failed to create hard link ...: Invalid cross-device link`
- Explicación: los números de inodo son únicos por filesystem; una dentry en el FS A no puede apuntar al inodo del FS B. Un symlink sí (porque guarda ruta, no inodo).

---

## Bloque D — find seguro

### 15. Top 5 archivos más grandes bajo HOME

Comando:

```bash
find "$HOME" -xdev -type f -print0 \
  | xargs -0 stat --printf='%s\t%n\n' 2>/dev/null \
  | sort -rn \
  | head -5
```

Alternativa con `-printf` (si tienes GNU find):

```bash
find "$HOME" -xdev -type f -printf '%s\t%p\n' 2>/dev/null \
  | sort -rn | head -5
```

Interpretación:
- `-xdev`: no cruza mounts (p. ej. no entra en `/home/<user>/.gvfs`).
- `-type f`: solo regulares.
- `-print0` + `xargs -0`: separador NUL, soporta espacios y saltos de línea.
- `stat --printf='%s\t%n\n'`: tamaño y nombre, tab como separador.
- `sort -rn | head -5`: ordenado por tamaño descendente.
