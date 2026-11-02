# Lección: Proceso de arranque de Linux y systemd

> Un sistema que no bootea es un sistema que no te deja depurar nada. Entender *cómo* arranca es la diferencia entre adivinar y diagnosticar. Esta lección te lleva desde el momento en que presionas el botón de encendido hasta que tu `app.service` recibe la señal `SIGTERM` durante un shutdown limpio.

## 1. Mapa del territorio

```
+----------------+     +----------+     +----------+     +------------+     +---------+     +-----------+
|  Firmware      | --> | Boot-    | --> |  Kernel  | --> | initramfs  | --> |  init   | --> | targets   |
|  (BIOS/UEFI)   |     | loader   |     |  (vmlinuz|     | (initrd)   |     | (PID 1  |     | (multi-   |
|                |     | (GRUB2)  |     |   + cmd) |     |            |     | systemd)|     | user, gfx)|
+----------------+     +----------+     +----------+     +------------+     +---------+     +-----------+
       |                   |                 |                 |                 |                |
       | POST, selecciona  | lee /boot,      | monta root RO,  | provee drivers, | monta FS reales,|
       | disco EFI/MBR     | menú, params,   | descomprime,    | LVM/cryptsetup/ | activa targets, |
       |                   | carga kernel+   | ejecuta init    | pivot_root      | spawnea daemons |
       |                   | initramfs       |                 |                 |                |
```

Nada mágico. Cada flecha es un *handoff* en el que un proceso cede control al siguiente, dejando estado explícito (variables EFI, kernel cmdline, `/proc/cmdline`, journal del boot anterior).

## 2. Firmware: BIOS vs UEFI

**BIOS** (legacy): ejecuta el **MBR** (Master Boot Record) — 512 bytes al inicio del disco. 440 bytes de código ejecutable. GRUB-stage1 vive aquí, carga el resto desde una ubicación conocida en disco. Direccionamiento CHS/LBA, límite de 2 TiB para discos booteables en MBR puro.

**UEFI**: ejecuta ejecutables PE en la **ESP** (EFI System Partition, FAT32, usualmente `/boot/efi`). Variables EFI (`efibootmgr -v`) definen el orden y las entradas. Soporta **Secure Boot** (firma de bootloaders con claves de la plataforma). No hay límite de 2 TiB. GPT en lugar de MBR.

Diferencia que importa en operación:

- En UEFI, instalar un kernel es copiar un `.efi` + actualizar entrada en `efibootmgr`. GRUB sigue siendo útil para menú y múltiples kernels, pero no es obligatorio (`systemd-boot`, `rEFInd`).
- En BIOS, cualquier error en el MBR o en los *stages* intermedios de GRUB deja el sistema sin bootear sin forma trivial de recuperar sin medio externo.

Verifica tu modo:

```bash
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS"
```

## 3. Bootloader: GRUB2

GRUB2 lee `grub.cfg` (NO lo edites a mano; es generado por `grub-mkconfig`). Las plantillas viven en `/etc/grub.d/` y los parámetros en `/etc/default/grub`.

El bootloader hace tres cosas:

1. Presenta el menú (si `GRUB_TIMEOUT` > 0).
2. Carga `vmlinuz-<version>` y `initrd.img-<version>` en memoria.
3. Pasa control al kernel con el **cmdline** (`GRUB_CMDLINE_LINUX`), que incluye `root=UUID=...`, `ro`, `quiet`, etc.

**Debug típico**:

- En el menú, presiona `e` para editar la entrada antes de bootear. Quita `quiet splash`, agrega `systemd.log_level=debug` o `init=/bin/bash` como último recurso.
- Si GRUB no aparece, el problema está en firmware ↔ bootloader, no en el kernel.

## 4. Kernel + initramfs

El kernel se descomprime, inicializa drivers *built-in*, monta el **initramfs** como `rootfs` temporal y ejecuta `/init` (en el initramfs, no el del disco real).

**¿Por qué initramfs existe?** El kernel tiene drivers built-in limitados. Si tu root FS está en LVM encriptado sobre RAID sobre NVMe, necesitas módulos (`dm-crypt`, `md`, `nvme`) que no están en `vmlinuz`. Initramfs los provee, monta el root real, y hace `pivot_root` cediéndole el control al `/sbin/init` del disco.

Herramientas:

- `lsinitramfs /boot/initrd.img-$(uname -r) | less` — ver contenido.
- `dracut` (Fedora/RHEL) o `update-initramfs -u` (Debian/Ubuntu) — regenerar.
- Si cambiaste el UUID del root o el esquema de cifrado y no regeneraste el initramfs: no boot.

El kernel cmdline final (lo que realmente se usó) está en `/proc/cmdline`:

```bash
cat /proc/cmdline
```

## 5. PID 1: systemd

El initramfs ejecuta `/sbin/init`, que en distros modernas es un symlink a `systemd`. Este proceso **nunca** muere mientras el sistema está vivo. Si PID 1 crashea, el kernel entra en pánico.

Responsabilidades de PID 1:

- Montar los filesystems definidos en `/etc/fstab` (en paralelo, respetando dependencias).
- Activar los **targets** por defecto (`default.target` → usualmente `graphical.target` o `multi-user.target`).
- Spawnear los daemons declarados.
- Reap de huérfanos (todo proceso cuyo padre muere queda bajo PID 1).
- Supervisar unidades (`Restart=`, watchdogs).
- Gestionar logging vía `systemd-journald`.
- Gestionar cgroups v2 como mecanismo de agrupación/aislamiento.

## 6. Unidades: el átomo de systemd

Una **unidad** es un recurso administrado por systemd. Tipos relevantes:

| Tipo | Qué modela | Ejemplo |
|------|------------|---------|
| `.service` | Proceso (daemon) supervisado | `nginx.service` |
| `.socket` | Socket IPC/TCP/UDP que activa un servicio por demanda | `docker.socket` |
| `.timer` | Disparador temporal (reemplaza cron) | `logrotate.timer` |
| `.mount` | Punto de montaje (generado desde `/etc/fstab` o manual) | `home.mount` |
| `.automount` | Montaje perezoso al primer acceso | `proc-sys-fs-binfmt_misc.automount` |
| `.target` | Agrupación lógica (no es un proceso) | `multi-user.target` |
| `.path` | Dispara un servicio cuando un path cambia | `cups.path` |
| `.slice` | Grupo de cgroup (jerarquía de recursos) | `user.slice` |
| `.swap` | Partición/archivo de swap | `dev-sda2.swap` |
| `.device` | Dispositivo (poblado por udev) | implícito |
| `.scope` | Procesos externos agrupados por systemd (p.ej. sesión de usuario) | implícito |

### 6.1 Anatomía de un `.service`

```ini
[Unit]
Description=My Hello Service
Documentation=https://example.org/docs
After=network-online.target
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=simple
User=hello
Group=hello
ExecStart=/usr/local/bin/hello --listen 127.0.0.1:8080
Restart=on-failure
RestartSec=5s
WatchdogSec=30s
Environment=HELLO_ENV=prod
EnvironmentFile=-/etc/default/hello
WorkingDirectory=/var/lib/hello
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
ReadWritePaths=/var/lib/hello

[Install]
WantedBy=multi-user.target
```

Tres secciones. `[Unit]` describe la unidad y declara dependencias. `[Service]` dice *cómo* se ejecuta el proceso. `[Install]` dice qué hacer cuando se **habilita** (`systemctl enable`) — crea un symlink desde el `WantedBy` hacia esta unidad.

Sin `[Install]`, `enable` falla con `no [Install] section`. El servicio puede arrancarse manualmente con `start`, pero no al boot.

### 6.2 `Type=` del servicio

| Valor | Semántica |
|-------|-----------|
| `simple` | El proceso de `ExecStart` ES el servicio. systemd lo considera *ready* al forkearlo. Default. |
| `exec` | Como `simple`, pero *ready* cuando el `execve` tuvo éxito (más estricto). |
| `forking` | El proceso hace `fork()` y el padre sale. systemd rastrea el hijo. Daemons tradicionales. |
| `oneshot` | Script que corre y termina. Útil para setup. Combinar con `RemainAfterExit=true` si debe considerarse "activo" tras salir. |
| `notify` | El servicio envía `sd_notify(READY=1)` cuando está listo. Más preciso que `simple`. |
| `dbus` | *Ready* cuando el servicio aparece en el bus con el `BusName=` dado. |
| `idle` | Como `simple`, pero espera a que el resto de trabajos activos terminen. Reduce ruido en logs de boot. |

## 7. Dependencias: semántica exacta

Confundir estas directivas es la fuente #1 de bugs al escribir unidades.

| Directiva | Significado |
|-----------|-------------|
| `Requires=B` | Si inicio A, también inicio B. Si B falla al arrancar, A se aborta. Si B se detiene o reinicia, A se detiene también. **No** implica orden. |
| `Wants=B` | Si inicio A, intento iniciar B, pero si B falla A sigue. Dependencia *suave*. **No** implica orden. |
| `Requisite=B` | Si inicio A y B no está ya activo, A falla inmediatamente. No arranca B. |
| `BindsTo=B` | Como `Requires=`, pero *más fuerte*: si B deja de estar activo por **cualquier** razón, A se detiene también. |
| `PartOf=B` | Si B se detiene o reinicia, A también. Pero NO al revés. Útil para bundles. |
| `Conflicts=B` | Iniciar A detiene B (y viceversa). |
| `Before=B` | A debe terminar de arrancar antes que B comience. Es solo orden, no dependencia. |
| `After=B` | A arranca después que B. Igual: solo orden. |

**Patrón canónico**: para "necesito la red antes de arrancar":

```ini
Wants=network-online.target
After=network-online.target
```

`Wants=` pide que se active, `After=` ordena.

## 8. Jerarquía de rutas

Tres ubicaciones, con precedencia:

1. `/etc/systemd/system/` — **admin local**. Lo que tú escribes. Gana sobre todo lo demás.
2. `/run/systemd/system/` — runtime, generado dinámicamente. Se pierde al reboot.
3. `/lib/systemd/system/` o `/usr/lib/systemd/system/` — provisto por paquetes de la distro. **No editar directamente** (el próximo update del paquete sobre-escribe).

**Drop-ins**: para modificar una unidad del sistema sin tocar el archivo original, crea un directorio con el nombre de la unidad seguido de `.d/` y pon dentro archivos `.conf`:

```
/etc/systemd/system/nginx.service.d/override.conf
```

Con contenido como:

```ini
[Service]
Environment=NGINX_WORKERS=8
LimitNOFILE=65536
```

Verifica con:

```bash
systemctl cat nginx.service   # muestra archivo base + drop-ins concatenados
systemctl show nginx.service  # muestra TODAS las propiedades efectivas
```

Shortcut:

```bash
systemctl edit nginx.service          # abre editor para drop-in
systemctl edit --full nginx.service   # edita copia en /etc/systemd/system/
```

Tras cualquier cambio:

```bash
sudo systemctl daemon-reload
```

## 9. Unidades de usuario

systemd corre una instancia por usuario (`systemd --user`), independiente de la del sistema. Las unidades viven en:

- `~/.config/systemd/user/` — del usuario.
- `/etc/systemd/user/` — admin, aplica a todos los usuarios.
- `/usr/lib/systemd/user/` — distro.

Comandos:

```bash
systemctl --user status
systemctl --user enable --now my-sync.timer
journalctl --user -u my-sync -f
```

Para que una unidad de usuario sobreviva al logout, habilita *lingering*:

```bash
sudo loginctl enable-linger $USER
```

## 10. Supervisión: Restart, backoff, watchdog

Directivas clave en `[Service]`:

| Directiva | Semántica |
|-----------|-----------|
| `Restart=no` | Nunca reiniciar. Default. |
| `Restart=on-failure` | Reinicia si sale con código ≠ 0, por señal no limpia, o watchdog. **Recomendado por default**. |
| `Restart=on-abnormal` | Solo señal/watchdog, no exit codes. |
| `Restart=always` | Reinicia pase lo que pase (incluso tras `systemctl stop`? → no, los stops explícitos no cuentan). |
| `RestartSec=5s` | Espera antes de reiniciar. Default `100ms`. |
| `StartLimitIntervalSec=60` + `StartLimitBurst=5` | Si crashea 5 veces en 60s, deja de reintentar. Previene loops. |
| `WatchdogSec=30s` | El servicio debe llamar `sd_notify(WATCHDOG=1)` cada menos de 30s o se mata y reinicia. Requiere `Type=notify`. |

Códigos de salida que importan: `0` éxito, cualquier otro = fallo (a ojos de `Restart=on-failure`).

## 11. Hardening: lo mínimo civilizado

Agrega estas opciones a toda `.service` que escribas en producción. Son opciones del kernel/systemd que aíslan el proceso.

| Opción | Qué hace |
|--------|----------|
| `User=hello` + `Group=hello` | NO corras como root si no es imprescindible. |
| `PrivateTmp=true` | `/tmp` propio por servicio, aislado del resto. |
| `ProtectSystem=strict` | `/usr`, `/boot`, `/etc` montados read-only para este proceso. `full` = `/usr` y `/boot` RO. `true` = sólo `/usr` y `/boot`. |
| `ProtectHome=true` | `/home`, `/root`, `/run/user` inaccesibles. |
| `NoNewPrivileges=true` | El proceso y sus hijos no pueden ganar privilegios vía setuid/setgid/capabilities. |
| `ReadWritePaths=/var/lib/hello` | Lista blanca de paths escribibles cuando `ProtectSystem=strict`. |
| `ProtectKernelTunables=true` | `/proc/sys`, `/sys` read-only. |
| `ProtectKernelModules=true` | Prohíbe cargar/descargar módulos. |
| `ProtectControlGroups=true` | `/sys/fs/cgroup` read-only. |
| `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` | Blanca de familias de sockets permitidas. |
| `CapabilityBoundingSet=` | Lista blanca de capabilities. Vacío = ninguna. |
| `SystemCallFilter=@system-service` | Seccomp allowlist. |

Audita cualquier unidad con:

```bash
systemd-analyze security nginx.service
```

Devuelve un score 0–10 y señala exactamente qué falta. Usar como checklist, no como meta de "sacar 10".

## 12. cgroups v2 y PID 1

systemd usa **cgroups v2** como su mecanismo nativo de agrupación. Cada unidad vive en su propia hoja del árbol de cgroups:

```
/sys/fs/cgroup/
  system.slice/
    nginx.service/
      cgroup.procs      # PIDs
      memory.current    # bytes usados
      cpu.stat          # tiempo CPU
  user.slice/
    user-1000.slice/
      session-3.scope/
```

Esto permite declarar límites en el unit file:

```ini
[Service]
MemoryMax=512M
CPUQuota=50%
TasksMax=200
IOWeight=500
```

Verificar runtime:

```bash
systemd-cgls           # árbol de cgroups
systemd-cgtop          # top por cgroup
```

**Delegación**: runtimes como Docker/Podman piden a systemd un cgroup propio donde ellos crearán sub-cgroups por contenedor. Se habilita con `Delegate=yes` en el `.service` del runtime.

## 13. journald: logging unificado

Todo lo que un servicio imprime a stdout/stderr va al journal. Nada de pelearse con rotación de logs ni `logrotate` para cada daemon.

Comandos esenciales:

```bash
journalctl -u nginx.service          # logs de una unidad
journalctl -u nginx.service -f       # follow (como tail -f)
journalctl -u nginx.service -n 100   # últimas 100 líneas
journalctl -u nginx.service -p err   # solo errores (0=emerg ... 7=debug)
journalctl -u nginx.service --since "1 hour ago"
journalctl -b                         # logs del boot actual
journalctl -b -1                      # boot anterior (-N para N atrás)
journalctl --list-boots               # IDs de boots guardados
journalctl -k                         # solo kernel (dmesg equivalente)
journalctl --disk-usage               # cuánto ocupa en disco
```

Persistencia: para que el journal sobreviva reboots, crea `/var/log/journal/`:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
```

Configura retención en `/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=1G
MaxRetentionSec=1month
```

## 14. Diagnóstico de boot

Herramientas en orden de utilidad:

```bash
systemd-analyze                        # tiempo total de boot
systemd-analyze blame                  # unidades ordenadas por tiempo
systemd-analyze critical-chain         # cadena crítica (ruta más larga)
systemd-analyze critical-chain nginx.service
systemd-analyze verify ./my.service    # valida syntax SIN activarla
systemd-analyze plot > boot.svg        # diagrama Gantt del boot
systemctl list-units --failed          # unidades que fallaron
systemctl status app.service           # estado actual + últimas líneas log
systemctl is-enabled app.service       # ¿está habilitada?
systemctl list-dependencies app.service
```

Receta para una regresión de boot:

1. `systemctl list-units --failed` — ¿quién falló?
2. `systemctl status <unit>` — mensaje de error + exit code + últimas líneas de log.
3. `journalctl -u <unit> -b` — todos los logs de esa unidad en el boot actual.
4. `systemd-analyze verify /etc/systemd/system/<unit>` — ¿syntax válida?
5. Si todo lo anterior es verde: `systemctl cat <unit>` para ver drop-ins. Un override puede estar introduciendo el problema.

## 15. Targets: lo que reemplazó a runlevels

| Target | Equivalente runlevel |
|--------|----------------------|
| `poweroff.target` | 0 |
| `rescue.target` | 1 (single user) |
| `multi-user.target` | 3 (sin GUI) |
| `graphical.target` | 5 (con GUI) |
| `reboot.target` | 6 |
| `emergency.target` | shell mínima, root FS read-only |

Cambiar runtime:

```bash
sudo systemctl isolate multi-user.target     # cambia a modo texto AHORA
sudo systemctl set-default multi-user.target # al próximo boot
systemctl get-default
```

`emergency.target` y `rescue.target` son los que te salvan cuando algo esencial se rompe. Para entrar en ellos desde GRUB, agrega al cmdline del kernel:

```
systemd.unit=rescue.target
```

o directamente:

```
init=/bin/bash
```

(último recurso, no monta nada).

## 16. Preguntas de reflexión

Responde sin consultar. Si no puedes, vuelve a la sección correspondiente.

1. ¿Qué pasa exactamente entre que el firmware termina su POST y el kernel empieza a correr? Describe las responsabilidades del bootloader en tres puntos.
2. ¿Por qué el initramfs existe aun en sistemas donde el root FS es un ext4 simple en un disco físico sin cifrado? ¿En qué caso podrías técnicamente prescindir de él?
3. Dadas dos unidades A y B, si pongo `Requires=B` en A pero NO pongo `After=B`, ¿qué puede ir mal al arrancar A?
4. Explica la diferencia práctica entre `Wants=` y `Requires=` desde la perspectiva de operaciones (qué sucede cuando B cae estando A activo, y qué sucede cuando B falla al arrancar).
5. Un paquete viene con `/lib/systemd/system/foo.service` y necesitas cambiar `MemoryMax=`. ¿Cuáles son las dos formas correctas de hacerlo y cuál prefieres y por qué?
6. ¿Qué hace `ProtectSystem=strict` y qué directiva usas si tu servicio necesita escribir en `/var/lib/foo/`?
7. ¿Por qué `Restart=always` puede ser peligroso sin `StartLimitIntervalSec`/`StartLimitBurst`?
8. Diferencia entre `systemctl cat`, `systemctl show`, y `systemctl status`. ¿Cuándo usas cada uno?
9. Un servicio de usuario (`systemctl --user`) no sigue corriendo después de hacer logout. ¿Qué comando habilita que persista?
10. Durante un boot roto, no puedes llegar a login. Describe la secuencia exacta de teclas y comandos (desde GRUB) para entrar en una shell que te permita editar `/etc/systemd/system/`.

---

> Si respondiste las 10 sin dudar, pasa a los laboratorios. Si dudaste en más de 3, relee las secciones correspondientes antes de tocar un `systemctl enable`.
