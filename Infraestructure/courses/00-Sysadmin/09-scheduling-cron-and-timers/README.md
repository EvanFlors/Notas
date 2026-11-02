# sys-09 — Scheduling: cron y systemd timers

## Identificación

- **ID:** `sys-09-scheduling-cron-and-timers`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 2 h
- **Prerrequisitos:** `sys-07-boot-process-and-systemd` (saber qué es una unit, cómo leer `systemctl status` y `journalctl -u`).

## Objetivo

Programar trabajos recurrentes de forma **reproducible** (el mismo código corre igual en dev, staging y prod) y **observable** (sabes si corrió, cuándo, con qué salida, y cómo falló). Al terminar deberías poder elegir entre `cron` y un `.timer` con criterio, portar uno al otro, y evitar el bug más común: *"funciona en mi shell pero no en el scheduler"*.

## Alcance

Este módulo cubre:

- Cron clásico: `crontab -e`, `/etc/crontab`, `/etc/cron.{hourly,daily,weekly,monthly}`, `/etc/cron.d/`.
- Sintaxis de 5 campos y shortcuts (`@daily`, `@reboot`).
- Variables de entorno en crontab: `SHELL`, `PATH`, `MAILTO`, `TZ`.
- `anacron` para hosts que no están siempre encendidos.
- `at` para one-shots (`at now + 5 minutes`, `atq`, `atrm`).
- systemd timers: pareja `.timer` + `.service`, `OnCalendar=`, `OnBootSec=`, `OnUnitActiveSec=`, `Persistent=`, `RandomizedDelaySec=`.
- Comparativa cron vs timer: logging, dependencias, drift, exactitud, debugging.
- Internals: **qué usuario corre el job, con qué `PATH`, con qué `cwd`, con qué TTY**.

Lo que **no** cubre (se verá después):

- Orquestadores de workloads (Airflow, Nomad, Kubernetes CronJob) → cursos de orquestación.
- Programación de eventos a nivel de kernel (`timerfd`, `itimer`) → fuera de alcance.

## Materiales

- **`theory/lesson.md`** — lección profunda (~400 líneas): historia de cron, sintaxis, timers, debugging walkthrough del entorno roto.
- **`examples/`**:
  - `01-cron-syntax-matrix/` — 10 patrones de 5 campos con lo que realmente significan.
  - `02-timer-vs-cron-equivalence/` — el mismo job expresado en cron y en `.timer` + `.service`.
- **`activities/`**:
  - `01-cron-to-timer-migration/` — guided-lab (45 min): porta un cron existente a timer y valida la equivalencia.
  - `02-make-a-scheduled-backup/` — mini-project (60 min): backup idempotente con rotación, logs al journal, timer `Persistent=true`.
- **`resources/links.md`** — manpages y documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué un cron falla aunque el mismo comando funcione en tu shell interactiva. Enumerar diferencias semánticas cron vs timer. Decir qué hace `Persistent=true` en un timer y por qué `anacron` existe. |
| Operativa | Escribir un crontab válido con `PATH`/`MAILTO` correctos. Escribir una pareja `.timer`+`.service`, instalarla, habilitarla, ver sus próximos disparos con `systemctl list-timers`, y leer sus logs con `journalctl -u`. |
| Arquitectónica | Elegir cron, timer, `at`, o un scheduler de aplicación según restricciones (observabilidad, dependencias entre jobs, exactitud temporal, si el host apaga). |

## Criterios de evaluación

- Las dos actividades pasan `tests/validate.sh`.
- Los archivos `.timer`/`.service` entregados cargan sin errores (`systemd-analyze verify`).
- El script de backup es idempotente (reejecutarlo no corrompe nada), escribe al journal (`logger` o `systemd-cat` o simplemente stdout), y rota copias antiguas.
- Puedes responder sin consultar: ¿con qué `PATH` corre un cron de root por defecto en tu distro? ¿cómo lo inspeccionas?

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Revisa `examples/01-cron-syntax-matrix/` y escribe en papel qué significan 3 patrones adicionales.
3. Revisa `examples/02-timer-vs-cron-equivalence/` comparando los dos archivos lado a lado.
4. Haz `activities/01-cron-to-timer-migration/` (guided, 45 min).
5. Haz `activities/02-make-a-scheduled-backup/` (mini-project, 60 min). No mires la solución hasta tener algo que te pase los tests o te ancles.
6. Responde las preguntas de evaluación al final de la lección.

## Siguiente

→ `sys-10-linux-networking`.
