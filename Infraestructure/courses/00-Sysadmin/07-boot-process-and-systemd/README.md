# sys-07 — Proceso de arranque y systemd

## Identificación

- **ID:** `sys-07-boot-process-and-systemd`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-05` (procesos, señales, control de trabajos).

## Objetivo

Entender el camino moderno de arranque de Linux (BIOS/UEFI → bootloader → kernel → initramfs → `init` → targets) y **operar systemd** como administrador: escribir unidades, resolver dependencias, diagnosticar regresiones de boot, endurecer servicios y leer el journal.

Al terminar deberías ser capaz de abrir un sistema que no bootea, aislar la unidad culpable con `systemd-analyze` + `journalctl -b`, y entregar un fix mínimo auditable.

## Alcance

Este módulo cubre:

- Secuencia de arranque: firmware (BIOS vs UEFI, variables EFI), bootloader (GRUB2, `grub.cfg`), kernel (parámetros, `cmdline`), initramfs (por qué existe, qué contiene), handoff a `init` (PID 1 = systemd).
- Modelo de systemd: unidades `.service`, `.socket`, `.timer`, `.mount`, `.target`, `.path`, `.slice`.
- Dependencias: `Requires`, `Wants`, `Requisite`, `BindsTo`, `After`, `Before`, `Conflicts`.
- Herramientas: `systemctl`, `journalctl -u`, `systemd-analyze blame`, `systemd-analyze critical-chain`, `systemd-analyze verify`.
- Jerarquía de rutas: `/etc/systemd/system` (admin) vs `/lib/systemd/system` o `/usr/lib/systemd/system` (distro). Drop-ins `foo.service.d/*.conf`.
- Unidades de usuario (`systemctl --user`, `~/.config/systemd/user`).
- Supervisión: `Restart=`, `RestartSec=`, `WatchdogSec=`, códigos de salida.
- Endurecimiento: `PrivateTmp`, `ProtectSystem`, `ProtectHome`, `NoNewPrivileges`, `User=`.
- Internals: PID 1 y por qué importa, cgroups v2 como mecanismo nativo de systemd, delegación a runtimes (containers).

Lo que **no** cubre (se verá después):

- Networking vía `systemd-networkd` → `sys-08`.
- `systemd-resolved`, `systemd-nspawn`, portable services → módulos avanzados.
- Reglas de udev más allá de lo imprescindible.

## Materiales

- **`theory/lesson.md`** — lección profunda (~550 líneas) con diagrama ASCII de la secuencia de boot, anatomía de un unit file, tabla de semántica de dependencias, lista de opciones de hardening, fundamentos de journald.
- **`examples/`**
  - `01-minimal-service-unit/` — unidad mínima funcional (`hello.service`) + script de instalación.
  - `02-drop-in-override/` — cómo sobre-escribir una opción sin tocar la unidad original.
- **`activities/`**
  - `01-write-a-service-unit/` — guided-lab (60 min). Escribir y validar un `.service` con `Restart=on-failure`, logs al journal y sección `[Install]` correcta.
  - `02-debug-boot-regression/` — debug (45 min). Diagnosticar una unidad rota usando `systemd-analyze verify`, `journalctl -b`, `systemctl status`.
- **`resources/links.md`** — man pages y documentación freedesktop.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar docs qué hace el firmware vs el bootloader vs el kernel vs initramfs. Diferenciar `Requires` de `Wants` y de `BindsTo`. Decir qué significa `After=` cuando no hay `Requires=`. |
| Operativa | Escribir una `.service` desde cero con `[Unit]`, `[Service]`, `[Install]`. Habilitar vía `systemctl enable`. Leer logs con `journalctl -u`, `-b`, `-f`, `-p`. Overridear vía drop-in sin editar el archivo original. |
| Arquitectónica | Decidir entre `.service` solo, `.socket` + `.service` (activación por socket), o `.timer` + `.service` (cron reemplazado). Aplicar `PrivateTmp` y `ProtectSystem` con criterio, no por copia-pega. |

## Criterios de evaluación

- Unidad `app.service` escrita, instalada en `/etc/systemd/system/`, habilitada y arrancada; logs visibles en `journalctl -u app`.
- Drop-in aplicado y verificado con `systemctl cat app.service` (muestra la unidad base + overrides).
- Diagnóstico correcto de la regresión del laboratorio 02: identifica la línea defectuosa, explica el error del verifier, propone fix mínimo.
- Respuesta argumentada a las preguntas de reflexión al final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin ejecutar nada).
2. Reproduce `examples/01-minimal-service-unit/` paso a paso.
3. Haz la actividad `activities/01-write-a-service-unit/`.
4. Lee `examples/02-drop-in-override/` y aplícalo a tu `app.service`.
5. Haz la actividad `activities/02-debug-boot-regression/` sin mirar la solución.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `sys-08`: networking de bajo nivel y `systemd-networkd`.
