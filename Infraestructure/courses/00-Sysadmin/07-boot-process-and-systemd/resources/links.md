# Recursos — sys-07 Proceso de arranque y systemd

## Man pages canónicas (freedesktop)

- `systemd.service(5)` — opciones de unidades `.service`: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html
- `systemd.unit(5)` — opciones comunes `[Unit]`/`[Install]`, dependencias: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
- `systemd.exec(5)` — todas las opciones de ejecución/sandbox/hardening: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html
- `systemd.resource-control(5)` — límites via cgroups v2: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- `systemd.socket(5)` — activación por socket: https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html
- `systemd.timer(5)` — timers (reemplazo de cron): https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
- `systemd.target(5)` — targets y runlevels: https://www.freedesktop.org/software/systemd/man/latest/systemd.target.html
- `systemctl(1)` — control CLI: https://www.freedesktop.org/software/systemd/man/latest/systemctl.html
- `journalctl(1)` — consulta de logs: https://www.freedesktop.org/software/systemd/man/latest/journalctl.html
- `systemd-analyze(1)` — introspección de boot y unidades: https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html
- `journald.conf(5)` — persistencia y rotación: https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html

## Documentación oficial systemd

- Página principal: https://systemd.io/
- Developer docs (índice): https://www.freedesktop.org/wiki/Software/systemd/
- Daemon writer's guide: https://www.freedesktop.org/software/systemd/man/latest/daemon.html

## Boot y bootloaders

- GRUB2 manual: https://www.gnu.org/software/grub/manual/grub/grub.html
- UEFI specifications: https://uefi.org/specifications
- `efibootmgr(8)`: https://man.archlinux.org/man/efibootmgr.8
- Arch Wiki — `Arch boot process` (una de las mejores referencias prácticas): https://wiki.archlinux.org/title/Arch_boot_process
- Arch Wiki — `systemd`: https://wiki.archlinux.org/title/Systemd

## cgroups v2

- Kernel docs: https://docs.kernel.org/admin-guide/cgroup-v2.html
- systemd y cgroups: https://systemd.io/CGROUP_DELEGATION/

## Hardening

- `systemd-analyze security`: https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html#systemd-analyze%20security
- Guía de endurecimiento (freedesktop): https://systemd.io/CREDENTIALS/ y https://0pointer.net/blog/dynamic-users-with-systemd.html

## Lectura adicional recomendada

- Lennart Poettering — serie "systemd for Administrators" (archivada): https://0pointer.de/blog/projects/systemd-for-admins-1.html
- `man:bootup(7)` — overview del proceso de arranque desde la perspectiva systemd.
