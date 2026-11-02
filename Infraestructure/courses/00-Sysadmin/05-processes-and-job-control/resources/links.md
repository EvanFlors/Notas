# Recursos — sys-05

## Man pages esenciales (fuente autoritativa)

- **`signal(7)`** — tabla completa de señales POSIX en Linux, defaults y restricciones. <https://man7.org/linux/man-pages/man7/signal.7.html>
- **`credentials(7)`** — identidades (UID, EUID, PGID, SID) y herencia a través de `fork`/`exec`. <https://man7.org/linux/man-pages/man7/credentials.7.html>
- **`proc(5)`** — layout de `/proc`, incluidos `/proc/[pid]/status`, `stat`, `cmdline`, `fd`. <https://man7.org/linux/man-pages/man5/proc.5.html>
- **`sched(7)`** — políticas de scheduling y relación con `nice`/`renice`. <https://man7.org/linux/man-pages/man7/sched.7.html>
- **`fork(2)`**, **`execve(2)`**, **`wait(2)`** — el modelo UNIX de creación de procesos. <https://man7.org/linux/man-pages/man2/fork.2.html>
- **`kill(1)`** y **`kill(2)`** — comando y syscall. <https://man7.org/linux/man-pages/man1/kill.1.html>
- **`setsid(1)`**, **`nohup(1)`** — desacople del terminal. <https://man7.org/linux/man-pages/man1/setsid.1.html>

## Diseño de systemd y supervisión

- **systemd service documentation** — <https://www.freedesktop.org/software/systemd/man/systemd.service.html>
- **systemd kill directives** (`KillSignal=`, `TimeoutStopSec=`, `SendSIGKILL=`) — <https://www.freedesktop.org/software/systemd/man/systemd.kill.html>
- **Rethinking PID 1 (Lennart Poettering)** — motivación de supervisor moderno vs sysvinit. <https://0pointer.de/blog/projects/systemd.html>
- **"The TTY demystified" (Linus Åkesson)** — grupos, sesiones y terminal controladora explicados visualmente. <https://www.linusakesson.net/programming/tty/>

## Lectura complementaria

- **Advanced Programming in the UNIX Environment** (Stevens & Rago), caps. 8 (Process Control), 9 (Process Relationships), 10 (Signals).
- **The Linux Programming Interface** (Michael Kerrisk), caps. 20–27.
- **"Graceful shutdowns in distributed systems"** — artículos de los equipos de infra de Shopify, Cloudflare y GitHub (buscar título, hay varias versiones mantenidas).

## Herramientas

- **`htop`** — <https://htop.dev/>
- **`procs`** — reemplazo moderno de `ps` en Rust. <https://github.com/dalance/procs>
- **`bpftrace`** — para trazar `exec`, `signal` a nivel kernel. <https://bpftrace.org/>

## Nota de verificación

Última verificación de enlaces: pendiente de validar al desplegar el curso. Todos los enlaces apuntan a dominios oficiales (`man7.org`, `freedesktop.org`, `0pointer.de`, `linusakesson.net`, `htop.dev`, `bpftrace.org`, `github.com`); revisar disponibilidad al momento de ejecución.
