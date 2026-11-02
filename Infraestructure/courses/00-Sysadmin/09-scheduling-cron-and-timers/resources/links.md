# Recursos — sys-09

## Manpages primarias

- **`crontab(5)`** — formato del crontab, variables, operadores, shortcuts. `man 5 crontab`.
- **`crontab(1)`** — comando de usuario (`-e`, `-l`, `-r`). `man 1 crontab`.
- **`cron(8)`** — el daemon y su comportamiento. `man 8 cron`.
- **`anacron(8)` + `anacrontab(5)`** — scheduling para hosts no siempre encendidos.
- **`at(1)` + `atd(8)`** — ejecución diferida de un tiro.
- **`systemd.timer(5)`** — unidades timer, directivas (`OnCalendar=`, `Persistent=`, `RandomizedDelaySec=`, etc.). `man 5 systemd.timer`.
- **`systemd.time(7)`** — formato de expresiones de calendario y de duraciones. `man 7 systemd.time`.
- **`systemd.service(5)`** — unidades service, tipos (`oneshot`, `simple`, ...), `Environment=`, `ExecStart=`.
- **`systemd-analyze(1)`** — subcomandos `calendar` y `verify`.
- **`journalctl(1)`** — inspección del journal (`-u`, `--since`, `-f`).
- **`flock(1)`** — locks de archivo para evitar solapes.
- **`run-parts(8)`** — cómo se procesan `/etc/cron.{hourly,daily,...}`.

## Documentación oficial en web

- Pages de systemd (fuente oficial): <https://www.freedesktop.org/software/systemd/man/>
  - `systemd.timer`: <https://www.freedesktop.org/software/systemd/man/systemd.timer.html>
  - `systemd.time`: <https://www.freedesktop.org/software/systemd/man/systemd.time.html>
  - `systemd.service`: <https://www.freedesktop.org/software/systemd/man/systemd.service.html>
  - `systemd-analyze`: <https://www.freedesktop.org/software/systemd/man/systemd-analyze.html>
- `cronie` (implementación cron de Red Hat/Fedora): <https://github.com/cronie-crond/cronie>
- `vixie-cron` / `cron` (implementación Debian): <https://salsa.debian.org/debian/cron>

## Complementario

- **Arch Wiki — systemd/Timers**: <https://wiki.archlinux.org/title/Systemd/Timers> (ejemplos muy claros, independientes de distro).
- **Red Hat sysadmin — "Use systemd timers instead of cronjobs"**: <https://www.redhat.com/sysadmin/systemd-timers>
- **Lennart Poettering — "Transient Units"**: <https://0pointer.net/blog/dynamic-users-with-systemd.html> (contexto moderno; ver también `systemd-run --on-calendar`).
- **"Why you shouldn't use cron"** (varios posts; búsqueda recomendada): discusión honesta de cuándo cron sigue siendo la opción correcta.

## Herramientas de verificación

- `systemd-analyze calendar "<expr>"` — valida una `OnCalendar=` e imprime próximas N ejecuciones (`--iterations=N`).
- `systemd-analyze verify unit.timer unit.service` — comprueba sintaxis de las units.
- `systemctl list-timers [--all]` — próximos disparos y última ejecución de cada timer activo.
- `shellcheck` (<https://www.shellcheck.net/>) — análisis estático para scripts Bash.

## Nota de verificación

Última verificación de enlaces: pendiente de validar en fase de ejecución del curso. Todas las URLs apuntan a dominios oficiales (`freedesktop.org`, `redhat.com`, `archlinux.org`, `github.com`, `salsa.debian.org`); re-verificar disponibilidad y versión al momento del despliegue en producción.
