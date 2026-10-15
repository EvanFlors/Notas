# Ejemplo 03 — Por qué NO montar `docker.sock` dentro del contenedor

## Concepto que demuestra

Montar `/var/run/docker.sock` dentro de un contenedor equivale a **conceder root en el host**. Este ejemplo lo demuestra de forma controlada en `/tmp/`: desde dentro del contenedor "víctima", escribimos a un archivo del host usando únicamente el socket.

> **Lee todo el ejemplo antes de ejecutarlo.** Está diseñado para ser inofensivo (escribe un marcador en `/tmp/`), pero el patrón que ilustra es destructivo si se cambia la ruta.

## Contexto

El antipatrón "móntame el socket" aparece en:

- CI runners que necesitan `docker build` dentro del job.
- Herramientas de monitoreo (cAdvisor, Portainer) que listan contenedores.
- Compose stacks donde un service "orquesta" a otros.

Es cómodo. También es **crítico**: el socket es un API REST sin autenticación propia (confía en el filesystem permission). Dentro del contenedor eres `root` del socket → eres `root` del daemon → el daemon te obedece.

## Objetivo

Al terminar, podrás:

- Explicar el **mecanismo exacto** en tres pasos (ver §11.1 de la lección).
- Reconocer el antipatrón en un `docker inspect`.
- Proponer alternativas concretas (socket proxy, kaniko/buildah, DinD rootless aislado).

## Prerrequisitos

- Docker funcional en modo **rootful** (el que viene por default). Rootless Docker atenúa el riesgo porque el daemon ya no es root (ver lección §9).
- Linux o macOS con Docker Desktop. En macOS/Windows, el "host" es la VM de Docker Desktop; el patrón sigue siendo el mismo.

## Archivos del ejemplo

En `files/`:

- `files/escape-demo.sh` — script del "ataque" ejecutado DESDE DENTRO del contenedor víctima.
- `files/run-demo.sh` — levanta el contenedor víctima con el socket montado y ejecuta la demo.
- `files/cleanup.sh` — limpia contenedores, volumen, archivo marcador.

## Walkthrough: el ataque en tres pasos

```
+--------------------------------+
| Container "victim"             |
|   - mounts /var/run/docker.sock|
|   - runs escape-demo.sh        |
+----------------+---------------+
                 |
       (talks to the Docker API via the socket)
                 |
                 v
+--------------------------------+
| dockerd on the host (root)     |
|   - obeys authenticated calls  |
|   - creates "escape" container |
|   - mounts HOST / into it      |
+----------------+---------------+
                 |
                 v
+--------------------------------+
| Container "escape"             |
|   - / of HOST at /host         |
|   - runs: touch /host/tmp/pwn  |
+--------------------------------+
```

1. El contenedor "victim" tiene `/var/run/docker.sock` montado. Dentro, el CLI `docker` o un curl al socket Unix es equivalente a hablar con el daemon root del host.
2. El payload pide crear un segundo contenedor "escape" con **`-v /:/host`**. El daemon obedece.
3. El contenedor "escape" ejecuta `touch /host/tmp/dkr13-ex03-PWNED` — es decir, toca `/tmp/dkr13-ex03-PWNED` del **host**. En un ataque real sería `/etc/cron.d/`, `/root/.ssh/authorized_keys`, o cualquier archivo del host.

## Ejecución

```bash
mkdir -p /tmp/dkr13-ex03
cp courses/docker/13-runtime-security-and-hardening/examples/03-why-not-mount-docker-sock/files/* /tmp/dkr13-ex03/
cd /tmp/dkr13-ex03

# Elimina el marcador previo si existe
rm -f /tmp/dkr13-ex03-PWNED

# Correr la demo
bash run-demo.sh
```

## Resultado esperado

```
== Starting victim container (mounts docker.sock) ==
<id>
== Running escape-demo.sh inside victim ==
[+] Writing /host/tmp/dkr13-ex03-PWNED from a NEW container with HOST / mounted
[+] Done. Check /tmp/dkr13-ex03-PWNED on the HOST.
== Checking from the host ==
-rw-r--r-- 1 root root 42 ... /tmp/dkr13-ex03-PWNED
   HOST file created by: UID=0 inside escape container, written to host / mount
== PWNED (as expected). This is why you NEVER mount docker.sock. ==
```

El archivo `/tmp/dkr13-ex03-PWNED` existe **en tu host**, aunque la operación partió desde dentro de un contenedor sin privilegios aparentes.

## Interpretación

- No hace falta `--privileged` en el contenedor víctima. Sólo el socket.
- El contenedor víctima puede ser el proceso más humilde del mundo (una app web). Si está comprometida, el escape es automático.
- Rootless Docker atenúa el blast radius (el "root al host" es "root al usuario que corre dockerd", no root absoluto).
- SELinux con etiquetado estricto (`:z/:Z`) también atenúa en RHEL/Fedora.

## Alternativas correctas

| Caso | Alternativa |
|------|-------------|
| Build de imágenes en CI | **kaniko** o **BuildKit standalone**; DinD rootless efímero en runners dedicados. |
| Monitoreo (cAdvisor, Portainer) | Montar socket **:ro** detrás de un socket-proxy (`tecnativa/docker-socket-proxy`) con allow-list por endpoint. |
| Orquestación interna | Usar un orquestador de verdad (Compose como launcher, no como control plane). |
| "Mi app necesita listar containers" | Replantea. ¿Por qué una app necesita leer la plataforma? Normalmente es signo de arquitectura invertida. |

## Errores frecuentes

- "El socket es sólo para leer" → NO. El socket es full-API. `:ro` del bind mount no restringe los endpoints.
- "Pongo `--read-only` al contenedor víctima y listo" → NO. El ataque no escribe al FS del contenedor, usa la API para crear otro contenedor.
- "Lo monto en `/tmp/sock/docker.sock`" → ruta diferente, mismo socket.

## Limpieza

```bash
bash cleanup.sh
```

o manualmente:

```bash
docker rm -f dkr13-ex03-victim dkr13-ex03-escape 2>/dev/null || true
rm -f /tmp/dkr13-ex03-PWNED
rm -rf /tmp/dkr13-ex03
```
