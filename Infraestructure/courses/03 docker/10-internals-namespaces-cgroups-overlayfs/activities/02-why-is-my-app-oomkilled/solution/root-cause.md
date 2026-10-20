# Root cause — oom-victim (reference)

- El contenedor `oom-victim` arrancó con `--memory=64m`, lo que fija `memory.max = 67108864` en su cgroup v2 bajo `/sys/fs/cgroup/system.slice/docker-<ID>.scope/`.
- El proceso intentó asignar ~128 MiB (`stress --vm-bytes 128M`), excediendo `memory.max`.
- El **OOM-killer del cgroup** (no el del host) seleccionó al proceso y le envió `SIGKILL` (señal 9).
- Docker reportó `State.ExitCode = 137` (convención `128 + 9` = `SIGKILL`) y `State.OOMKilled = true`.
- En `memory.events` del cgroup se incrementó `oom_kill` en 1.

**Fix:** subir el límite si la app lo requiere (`--memory=256m`), o rediseñar la app para no cargar todo en memoria. Añadir `--memory-swap` **igual** a `--memory` para desactivar swap de forma explícita.
