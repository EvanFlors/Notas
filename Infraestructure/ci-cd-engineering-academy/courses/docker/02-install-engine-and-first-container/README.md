# dkr-02 — Instalación del engine y primer contenedor

## Identificación

- **ID:** `dkr-02-install-engine-and-first-container`
- **Curso:** `docker`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `dkr-01-mental-model-and-oci`. Línea de comandos básica.

## Objetivo

Instalar Docker (o una alternativa compatible), **entender la arquitectura cliente/daemon** (CLI → `dockerd` → `containerd` → `runc`), y operar con precisión el **ciclo de vida de un contenedor**: `run`, `ps`, `logs`, `exec`, `stop`, `kill`, `rm`. Al terminar deberías poder leer una salida de `docker inspect` sobre un contenedor en vivo y explicar línea por línea qué significa.

## Alcance

Este módulo cubre:

- Instalación en Linux (Docker Engine nativo), macOS y Windows (Docker Desktop) y la diferencia operacional entre ambas rutas.
- Alternativas compatibles OCI: **Podman**, **colima**, **Rancher Desktop**, **OrbStack**, **nerdctl**.
- Arquitectura: `docker` CLI, `dockerd`, socket Unix `/var/run/docker.sock`, grupo `docker` y por qué equivale a root.
- Comandos de ciclo de vida: `run`, `ps`, `logs`, `exec`, `stop`, `kill`, `rm`, `inspect`.
- Flags clave de `run`: `-d`, `-it`, `--rm`, `--name`, `--restart`, `-p`, `-v`, `-e`.
- **PID 1 y la trampa del "zombie reaping"**: por qué `--init` existe, qué pasa con señales si tu app no las maneja (10 s de grace → SIGKILL).

Lo que **no** cubre (se verá después):

- Construcción de imágenes y `Dockerfile` → `dkr-03`.
- Volúmenes nombrados vs bind mounts a fondo → `dkr-04`.
- Networking de contenedores a fondo → `dkr-05`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-run-nginx-and-inspect/` — ciclo completo `run → ps → logs → inspect → stop → rm` sobre nginx.
  - `02-pid1-signals/` — cómo llega `SIGTERM` a PID 1 y por qué `--init` resuelve el problema de los zombies y las señales.
- **`activities/`**:
  - `01-container-lifecycle/` (guided-lab) — operar un contenedor Redis con todos los comandos del ciclo de vida.
  - `02-why-is-my-container-exiting/` (debug guiado) — diagnosticar tres contenedores que no permanecen vivos.
- **`resources/links.md`** — documentación oficial y lecturas complementarias.

## Temas y subtemas

1. Instalación por SO
   - Linux: Docker Engine (paquete oficial o convenience script).
   - macOS: Docker Desktop vs colima vs OrbStack.
   - Windows: Docker Desktop + WSL2.
   - Alternativas compatibles: Podman, Rancher Desktop, nerdctl.
2. Arquitectura operacional
   - `docker` CLI (binario cliente).
   - `dockerd` (daemon de alto nivel).
   - Socket Unix `/var/run/docker.sock`.
   - `containerd` + `runc` (runtime).
   - El grupo `docker` como superficie de ataque.
3. Ciclo de vida de un contenedor
   - `docker run` paso a paso.
   - Estados: `created`, `running`, `paused`, `restarting`, `exited`, `dead`.
   - `ps`, `ps -a`, `logs`, `logs -f`, `exec`, `inspect`, `stop`, `kill`, `rm`.
4. Flags clave de `run`
   - Modo: `-d`, `-it`, `--rm`.
   - Identidad: `--name`, `--hostname`.
   - Reinicio: `--restart`.
   - Red: `-p host:container`.
   - Volúmenes: `-v`.
   - Entorno: `-e`, `--env-file`.
5. PID 1 y señales
   - Qué es PID 1 en Linux y qué responsabilidades tiene.
   - Cómo `docker stop` manda `SIGTERM`, espera `--time` (10 s) y luego `SIGKILL`.
   - Qué pasa si tu proceso ignora `SIGTERM` (y por qué `/bin/sh -c` lo hace sin querer).
   - `--init` (y `tini`) como solución.

## Conceptos internos (fundamentos)

- `docker ps` consulta al daemon; **lo que ves es el estado del daemon**, no del kernel directamente. Si el daemon está caído, no "ves" tus contenedores aunque sigan corriendo (no lo hacen, pero el modelo mental importa).
- `docker exec` no es `ssh`: no abre un canal remoto, le pide al daemon que haga `setns` sobre los namespaces del contenedor y lance un proceso adicional dentro. Si el contenedor muere, el `exec` muere.
- El socket `/var/run/docker.sock` es la API entera del daemon. Quien pueda escribir en él puede pedirle al daemon que monte `/` del host en un contenedor y escriba archivos como root. **Grupo `docker` = root.**
- Las señales se entregan a **PID 1 dentro del PID namespace del contenedor**. Si PID 1 es `/bin/sh -c "mi-app"`, es `sh` quien recibe `SIGTERM` — y `sh` no lo reenvía a hijos por default. Resultado: tu app nunca ve la señal; a los 10 s el daemon manda SIGKILL. Datos sin flush, conexiones colgadas.
- Los procesos huérfanos dentro del contenedor son reparentados a PID 1. Si PID 1 no hace `wait()`, se acumulan zombies. En un contenedor pequeño rara vez importa; en uno de larga vida con subprocesos, sí. `--init` lanza `tini` como PID 1 para reparar ambas cosas.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la cadena CLI → daemon → containerd → runc. Explicar por qué `exec` no es `ssh`. Explicar la trampa del PID 1 y por qué `--init` existe. |
| Operativa | Ejecutar el ciclo de vida completo de un contenedor con los flags correctos; leer `docker inspect` y extraer campos específicos con `--format`. |
| Arquitectónica | Justificar por qué el grupo `docker` equivale a root, y elegir conscientemente entre Docker Desktop, Docker Engine, Podman, colima, Rancher Desktop. |

## Entregables

- Un documento personal (`notas-inspect.md` en tu carpeta de trabajo) con la salida comentada de `docker inspect` sobre un contenedor en vivo, explicando al menos: `State`, `Config.Cmd`, `Config.Entrypoint`, `HostConfig.RestartPolicy`, `NetworkSettings.Ports`, `GraphDriver`, `Mounts`.
- Los dos `tests/validate.sh` de las actividades deben pasar.

## Criterios de evaluación

- Capacidad de **explicar por qué agregar un usuario al grupo `docker` es equivalente a hacerle root** (demostrarlo con un ejemplo usando el socket).
- Capacidad de arrancar, listar, inspeccionar, enviar señales y limpiar un contenedor sin recurrir a `docker rm -f` como herramienta por default.
- Capacidad de diagnosticar un contenedor que "sale inmediatamente" y clasificar la causa (comando inexistente, exit 0 esperado, falta de TTY, señal no manejada).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Instala Docker (sección 2 de la lección) y verifica con `docker version`.
3. Reproduce `examples/01-run-nginx-and-inspect/`.
4. Haz `activities/01-container-lifecycle/`.
5. Lee `examples/02-pid1-signals/` y reproduce las dos demos.
6. Haz `activities/02-why-is-my-container-exiting/`.
7. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `dkr-03-images-dockerfile-basics`: dejamos de usar imágenes ajenas y empezamos a construir las nuestras.
