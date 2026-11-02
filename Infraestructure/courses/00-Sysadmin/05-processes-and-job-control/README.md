# sys-05 — Procesos y control de trabajos

## Identificación

- **ID:** `sys-05-processes-and-job-control`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-01` (línea de comandos, estructura de `/proc`, redirección, pipes).

## Objetivo

Orquestar operaciones del sistema mediante **procesos**, **señales** y **control de trabajos**. Al terminar deberías poder inspeccionar el árbol de procesos, enviar la señal correcta en el escenario correcto, manejar jobs en primer y segundo plano, y entender por qué una `SIGTERM` ignorada no es un bug sino una decisión arquitectónica.

## Alcance

Este módulo cubre:

- Proceso vs programa; identidades `PID`, `PPID`, `PGID`, `SID`, `UID/EUID`.
- `ps -ef`, `ps auxf`, `pstree`, `top`, `htop`.
- Estados R / S / D / Z / T y qué significa cada letra en `/proc/[pid]/status`.
- Señales POSIX: `SIGTERM`, `SIGKILL`, `SIGHUP`, `SIGINT`, `SIGSTOP`, `SIGCONT`, `SIGPIPE`.
- Entrega: `kill`, `kill -0`, `pkill`, `killall`, `kill -<signame> -- -PGID`.
- Control de trabajos del shell: `&`, `jobs`, `fg`, `bg`, `Ctrl-Z`, `disown`, `nohup`.
- Prioridad y recursos: `nice`, `renice`, `ionice`, `ulimit`.
- Demonización: `nohup` vs `setsid` vs servicio `systemd` — cuándo elegir cada uno.

**Internals** (parte conceptual de la lección):

- `fork` / `exec` / `wait` y qué sobrevive al `exec`.
- Zombies y huérfanos: por qué existen, cómo se cosechan, quién adopta.
- Grupos de procesos, sesiones y terminal controladora.

Lo que **no** cubre (se verá después):

- Unidades `systemd` completas (timers, slices, cgroups v2) → `sys-07`.
- `cgroups`, `namespaces` y aislamiento → `sys-08`.
- Programación en C de `fork(2)` / `signal(2)` → fuera del curso.

## Materiales

- **`theory/lesson.md`** — lección profunda con diagrama de ciclo de vida, tabla completa de señales, demo de zombie y patrón de *graceful shutdown*.
- **`examples/`**:
  - `01-fork-exec-wait/` — un script que lanza un hijo en background, instala `trap` y demuestra `wait`.
  - `02-signal-matrix/` — matriz de qué señales pueden atraparse, ignorarse o nunca.
- **`activities/`**:
  - `01-signals-dojo/` — guided-lab, 45 min: instalar `trap`s correctos.
  - `02-tame-runaway-process/` — debug, 45 min: domar un proceso que ignora `TERM`.
- **`resources/links.md`** — man pages esenciales (`signal(7)`, `credentials(7)`, `proc(5)`) y referencias a diseño de systemd.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué sobrevive a `exec`, por qué `SIGKILL` no puede atraparse y qué hace un zombie en la tabla de procesos. |
| Operativa | Encontrar un proceso por nombre/patrón, enviarle la señal mínima suficiente, mover trabajos entre foreground y background, y limitar su CPU/IO con `nice`/`ionice`. |
| Arquitectónica | Decidir entre `nohup`, `setsid` y una unit de `systemd` para desacoplar un proceso del terminal, con un criterio justificable (supervisión, logs, restart). |

## Criterios de evaluación

- Reproduces un zombie, lo identificas con `ps` y explicas cómo cosecharlo.
- Escribes un `trap` que atrapa `TERM`/`INT`/`HUP` y hace *graceful shutdown* con *grace period* antes de un `KILL` escalado.
- Diferencias un proceso en estado `D` (uninterruptible sleep) de uno en `S` y sabes por qué `kill -9` no siempre lo arranca.
- Resuelves la actividad `02-tame-runaway-process` sin usar `kill -9` como primer recurso.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada).
2. Reproduce `examples/01-fork-exec-wait/`.
3. Lee `examples/02-signal-matrix/` como referencia.
4. Haz la actividad `activities/01-signals-dojo/`.
5. Haz la actividad `activities/02-tame-runaway-process/`.
6. Responde las preguntas de evaluación al final de la lección sin consultar.

## Siguiente

→ `sys-06-text-processing-and-pipelines`: *streams* de texto, `awk`, `sed`, `jq`, construcción de pipelines robustos.
