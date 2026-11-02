# 00-Sysadmin — Bash, Shell y Administración de Sistemas Linux

> Curso completo de **línea de comandos, administración de sistemas Linux y scripting en Bash** para ingenieros de infraestructura, SRE, platform engineers y backend/DevOps intermedios que quieren dejar de "copiar comandos" y empezar a **operar sistemas Unix con criterio y automatizar con scripts robustos**.

Este curso es la **base transversal T-0** del programa: todos los cursos posteriores (Docker, Kubernetes, Terraform, Ansible, Argo CD, CI/CD, Observabilidad, AWS/GCP/Azure, SecOps) asumen que el estudiante maneja con fluidez lo que aquí se cubre.

---

## 1. Introducción

### Qué es

Una "stack" de tres capas inseparables en Unix/Linux:

1. **La shell** (específicamente **Bash**, Bourne-Again SHell): intérprete de comandos interactivo y lenguaje de scripting.
2. **El entorno Linux**: filesystem, procesos, usuarios, permisos, red, boot, servicios, almacenamiento.
3. **Las utilidades POSIX/GNU**: `grep`, `sed`, `awk`, `find`, `coreutils`, `util-linux`, `systemd`, `iproute2`, `openssh`, `cron`, `wget`/`curl`, etc.

Ninguna de las tres capas tiene sentido sin las otras. Un script Bash sin entender el filesystem Linux produce bugs no reproducibles; conocer `systemd` sin dominar la shell lleva a copiar runbooks sin saber lo que ejecutan.

### Historia síntesis

- **1971** — primer `sh` (Thompson shell) en UNIX V1.
- **1977** — Bourne shell (`sh`) en UNIX V7, modelo de "comandos externos + redirección + pipes".
- **1989** — Brian Fox libera **Bash 1.0** para GNU, superconjunto POSIX de `sh` con historial, aliases, arrays, aritmética.
- **1991** — Linus Torvalds libera Linux; Bash se convierte en shell por defecto de GNU/Linux.
- **2010** — **systemd** reemplaza SysV init en la mayoría de distros, redefine el modelo de boot y servicios.
- **2019** — Bash 5.0: `EPOCHREALTIME`, `BASH_ARGV0`, mejoras en readline.
- **2026** — Bash 5.2+ en Debian 12/13, Ubuntu 24.04 LTS, RHEL 9/10, Alpine, Arch.

### Problemas que resuelve

- Operar y automatizar máquinas Unix sin UI gráfica (servidores, contenedores, VMs cloud, CI runners).
- Encadenar herramientas pequeñas (filosofía Unix) en lugar de escribir aplicaciones monolíticas.
- Scripts de infraestructura: boot, provisioning, health checks, backups, migraciones, pipelines locales.
- Depurar sistemas en producción cuando la observabilidad gráfica falla (logs, procesos, red, disco).
- Reproducibilidad: código vs. "pasos manuales" perdidos en un wiki.

### Casos de uso típicos

- Script de deploy que valida precondiciones, invoca `terraform`/`kubectl`/`docker` y limpia en caso de fallo.
- Hook de pre-commit en Git o entrypoint de contenedor en Docker.
- Cron / systemd timer que rota logs, hace backups, renueva certificados o reporta métricas.
- Runbook interactivo con `dialog`/`zenity` para operaciones puntuales de ops.
- Instalador reproducible que descarga artefactos con `wget`, verifica checksum y GPG, y los instala.
- Diagnóstico en vivo: `ps`, `ss`, `journalctl`, `strace`, `lsof`, `tcpdump`, `iostat`.

### Arquitectura general

```
┌─────────────────────────────────────────────────────────────┐
│                       USUARIO                               │
└──────────────┬──────────────────────────────────────────────┘
               │ teclado / stdin
               ▼
┌─────────────────────────────────────────────────────────────┐
│  BASH (shell)                                               │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌───────────┐   │
│  │ parser   │→ │ expansion │→ │ builtins │  │ job ctrl  │   │
│  └──────────┘  └───────────┘  └────┬─────┘  └───────────┘   │
│                                     │ fork+execve           │
└─────────────────────────────────────┼───────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│  USERLAND (GNU coreutils, util-linux, grep/sed/awk, ssh…)   │
└─────────────────────────────┬───────────────────────────────┘
                              │ syscalls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  KERNEL LINUX                                               │
│  procesos │ VFS │ network stack │ cgroups │ namespaces      │
└─────────────────────────────┬───────────────────────────────┘
                              ▼
                       HARDWARE / HYPERVISOR
```

El estudiante aprende cada capa **desde arriba hacia abajo**: primero vivir en la shell, después entender qué hace el kernel debajo.

### Alternativas

| Alternativa | Cuándo tiene sentido | Trade-off |
|-------------|---------------------|-----------|
| **Zsh / Fish** | shell interactiva personal | para scripting portable sigue siendo Bash/`sh` |
| **PowerShell** | ecosistema Windows / Azure | semántica distinta (objetos vs. texto), no estándar en Linux |
| **Python / Go para scripts** | lógica > 200 líneas, estructuras complejas | overhead de runtime, dependencias; para pegamento Bash gana |
| **Ansible / Salt / Chef** | gestión de parque > 10 nodos declarativa | se cubren en cursos aparte; dependen de SSH + Bash en el fondo |
| **Nix / NixOS** | reproducibilidad extrema | curva de aprendizaje; convive con lo que aquí se enseña |

El criterio del curso: **Bash para pegamento de ≤ 200 líneas; Python/Go para lógica compleja; herramientas declarativas para gestión de flotas**. Saber dónde está la frontera es parte del aprendizaje.

### Ventajas y limitaciones

**Ventajas**
- Universal: presente en toda distro Linux, macOS, WSL, contenedores base.
- Zero-dependency: `#!/usr/bin/env bash` basta.
- Compone utilidades externas con poco código.
- Mismo lenguaje interactivo y de script.

**Limitaciones**
- Tipado débil, errores silenciosos sin `set -euo pipefail`.
- Arrays limitados; no hay estructuras complejas idiomáticas.
- Portabilidad `bash` ↔ `sh` (dash, busybox ash) requiere disciplina.
- Testing y refactor son incómodos comparados con lenguajes de aplicación.

### Relación con otros cursos del programa

| Curso | Qué asume de este curso |
|-------|-------------------------|
| `01 git-and-github` | shell, filesystem, procesos |
| `03 docker` | `PID 1`, procesos, señales, usuarios, filesystem, red |
| `04 terraform` / `16 ansible` | SSH, variables de entorno, exit codes, scripts de wrapper |
| `05 kubernetes` | `kubectl` como CLI, logs, procesos, red, volumes |
| `17 jenkins` / `15 gitlab-cicd` / `02 github-actions` | runners Linux, scripts de pipeline |
| `11 platform-engineering` | runbooks, operators, cron, systemd |
| `12/13/14 cloud` | boot, cloud-init, systemd, SSH, usuarios IAM ↔ Linux |

---

## 2. Prerrequisitos

### Obligatorios
- Acceso a una máquina Linux: VM local (Multipass, Vagrant, UTM), WSL2, contenedor (`docker run -it debian:12`) o VPS.
  - **No se recomienda macOS como entorno principal** porque las utilidades BSD divergen de GNU en flags clave; sí como shell desde la que te conectas por SSH.
- Editor de texto en terminal: `nano` basta para empezar; `vim` o `micro` recomendados.
- Capacidad de leer inglés técnico (manpages, docs oficiales).

### Recomendados
- Haber usado alguna vez `cd`, `ls`, `cat`.
- Nociones mínimas de redes TCP/IP (IP, puerto, DNS) — se refuerza en Nivel 3.

### Complementarios
- Curso `01 git-and-github` en paralelo (los scripts se versionarán).

### Software y versiones target

| Herramienta | Versión mínima | Verificación |
|-------------|---------------|--------------|
| `bash` | 5.0+ | `bash --version` |
| `coreutils` | 9.x (GNU) | `ls --version` |
| `systemd` | 249+ | `systemctl --version` |
| Distros validadas | Debian 12/13, Ubuntu 22.04/24.04 LTS, RHEL/Alma/Rocky 9/10, Alpine 3.19+ | — |

---

## 3. Organización

El curso tiene **21 módulos agrupados en 4 niveles**, con un DAG de dependencias explícito en `ROADMAP.md`.

### Nivel 1 — Fundamentos de línea de comandos (≈ 12 h)
Vivir en la shell: filesystem, I/O, comandos, lectura de documentación. Sin esto, nada más tiene sentido.

- `sys-01-bash-cli-foundations`
- `sys-02-shell-command-anatomy`
- `sys-03-unix-files-and-filesystem`

### Nivel 2 — Administración de sistemas Linux (≈ 20 h)
Operar la máquina: quién puede hacer qué, qué está corriendo, cómo se instala software, cómo arranca el sistema, cómo se almacena y cuándo se ejecuta.

- `sys-04-users-groups-permissions-acl`
- `sys-05-processes-and-job-control`
- `sys-06-package-management-upgrades`
- `sys-07-boot-process-and-systemd`
- `sys-08-storage-volumes-and-lvm`
- `sys-09-scheduling-cron-and-timers`

### Nivel 3 — Red, acceso remoto y seguridad base (≈ 12 h)
Linux conectado: interfaces, SSH, firewall, SELinux. Puerta de entrada a cualquier curso cloud.

- `sys-10-linux-networking`
- `sys-11-ssh-and-remote-access`
- `sys-12-firewall-and-selinux`

### Nivel 2–3 paralelo — Bash scripting (≈ 24 h)
Automatización: pasar de "comandos sueltos" a scripts reproducibles, robustos e interactivos.

- `sys-13-bash-scripting-fundamentals`
- `sys-14-robust-scripts-and-error-handling`
- `sys-15-arithmetic-tests-and-conditionals`
- `sys-16-loops-and-iteration`
- `sys-17-interactive-scripts-select-dialog-zenity`
- `sys-18-arguments-functions-and-arrays`

### Nivel 4 — Producción y profundidad (≈ 12 h)
Procesamiento de texto a escala, descargas verificables, internals de Bash para scripts de producción.

- `sys-19-text-processing-grep-and-regex`
- `sys-20-fetching-wget-and-checksum-integrity`
- `sys-21-bash-depths-advanced`

**Total orientativo:** ~80 h de dedicación.

Ver `ROADMAP.md` para IDs, prerrequisitos, objetivos operacionales y DAG completo.

---

## 4. Entregables del curso

Al terminar el curso el estudiante produce:

1. **Dotfiles personales** versionados en Git: `.bashrc`, `.inputrc`, `.profile`, `.ssh/config`, aliases, funciones.
2. **Biblioteca `syslab/` de scripts reutilizables**: logging, locking, retry, check-port, backup rotativo, limpieza por edad, etc. — todos con `set -euo pipefail`, trap de limpieza y tests.
3. **Playbook de operación de una VM**: desde boot limpio → usuarios → red → firewall → servicio systemd propio → cron de backup → actualización controlada → recuperación.
4. **Mini-herramienta CLI en Bash**: parsea argumentos con `getopts`, usa funciones, maneja errores, imprime ayuda, retorna exit codes semánticos.
5. **Pipeline de ingesta de texto**: `wget` + checksum + `gpg --verify` + `grep`/`sed`/`awk` + reporte.
6. **Runbook interactivo** con `dialog` o `zenity` para una operación recurrente.
7. **Capstone (opcional, enlazado al curso 10)**: provisioning idempotente de una VM desde cero con un único script `bootstrap.sh`.

---

## 5. Evaluación

Tres dimensiones por módulo (ver `ROADMAP.md` para criterios por módulo):

### Conceptual
- Explica el porqué: diferencia entre proceso y comando, entre `[` y `[[`, entre `cron` y `systemd timer`, entre `wheel` y `sudoers`, entre `wget --continue` y reintento idempotente.
- Lee una manpage y extrae lo esencial sin googlear.

### Operativa
- Resuelve una tarea en < X minutos sin consultar notas: crear un usuario con grupo y shell, abrir un puerto en el firewall, montar una partición, programar un timer.
- Diagnostica un fallo real: servicio que no arranca, disco lleno, permiso denegado, conexión SSH rechazada.

### Arquitectónica
- Decide: ¿cron o systemd timer? ¿sudo o setuid? ¿systemd unit o script en `rc.local`? ¿SELinux enforcing o permissive para un POC? Justifica el trade-off.
- Diseña: layout de usuarios/grupos para un equipo, estructura de un script de ≥ 300 líneas, estrategia de rotación de logs.

**Rúbrica base por actividad** (ver `templates/activity-template.md`): funcionalidad, calidad del código Bash (shellcheck limpio), seguridad (secretos, permisos), reproducibilidad, mantenibilidad.

---

## 6. Recursos

Fuentes autoritativas que el curso consume y referencia. Verificadas en Fase 4 antes de cada release del curso.

### Documentación oficial
- GNU Bash Reference Manual — https://www.gnu.org/software/bash/manual/
- POSIX.1-2024 shell & utilities — https://pubs.opengroup.org/onlinepubs/9799919799/
- `man-pages` del proyecto Linux — https://man7.org/linux/man-pages/
- systemd upstream docs — https://www.freedesktop.org/wiki/Software/systemd/
- OpenSSH — https://www.openssh.com/manual.html
- SELinux Project — https://github.com/SELinuxProject/selinux-notebook

### Libros
- *The Linux Command Line*, William Shotts (5.ª ed., 2024) — base de Nivel 1.
- *Classic Shell Scripting*, Arnold Robbins & Nelson Beebe — bash profundo.
- *How Linux Works*, Brian Ward (3.ª ed., 2021) — Nivel 2–3.
- *UNIX and Linux System Administration Handbook*, Nemeth et al. (5.ª ed.) — referencia.
- *The AWK Programming Language*, Aho/Weinberger/Kernighan (2.ª ed., 2024).

### Especificaciones
- Filesystem Hierarchy Standard 3.0 — https://refspecs.linuxfoundation.org/FHS_3.0/fhs/
- XDG Base Directory Specification — https://specifications.freedesktop.org/basedir-spec/latest/

### Linters / tooling
- `shellcheck` — https://www.shellcheck.net
- `shfmt` — https://github.com/mvdan/sh
- `bats-core` (testing bash) — https://github.com/bats-core/bats-core

---

## 7. Convenciones del curso

- **Shebang canónico**: `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'` cuando aplique.
- Todo script debe pasar `shellcheck` sin warnings de severidad `error` o `warning` (no `style`).
- Variables en `UPPER_SNAKE` para constantes de script, `lower_snake` para locales.
- `activity.yaml` describe prereqs, duración, tipo, costo (si aplica), limpieza.
- Costos: ningún recurso cloud real en el core del curso; todo lo que necesite nube se marca y lleva estimación + `teardown.sh`.
- Secretos: nunca credenciales reales ni plausibles; usar placeholders tipo `AKIAEXAMPLE…`.

---

## 8. Siguiente paso

👉 `ROADMAP.md` — módulos uno a uno, con prerrequisitos, competencias por dimensión, actividades previstas, duración y DAG Mermaid.
