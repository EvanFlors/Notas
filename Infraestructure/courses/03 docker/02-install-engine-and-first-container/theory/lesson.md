# Lección: Instalación del engine y primer contenedor

> **ID:** `dkr-02-install-engine-and-first-container` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `dkr-01-mental-model-and-oci`.

---

## 1. Introducción intuitiva

Terminaste `dkr-01` con un modelo mental claro: un contenedor es un proceso Linux normal con restricciones adicionales (namespaces, cgroups), y una imagen es un paquete de capas tar con metadatos. Nada de eso lo hace Docker directamente. Docker es **la ergonomía**: una CLI que habla con un daemon que habla con `containerd` que llama a `runc` que llama al kernel.

En este módulo te sientas frente a esa pila. No vas a construir nada (eso es `dkr-03`); vas a **operar**. Vas a instalar el engine, descubrir que la CLI y el daemon son dos programas distintos conectados por un socket, y aprender a arrancar, inspeccionar, parar y limpiar contenedores con precisión. Hay una recompensa: si entiendes bien los cinco o seis comandos del ciclo de vida y la trampa de PID 1, tu "60 % de los problemas con Docker en producción" ya está cubierto.

El hilo conductor del módulo es "qué pasa cuando escribes `docker run nginx`". A la vuelta de esa pregunta aparecen el socket, los permisos, el modelo cliente/servidor, el PID 1, las señales, y la razón por la que `docker exec` no es `ssh`.

---

## 2. Fundamentos

Antes de instalar nada:

### 2.1 La CLI y el daemon son procesos distintos

En Linux clásico, `docker` (el binario que escribes en la terminal) es un **cliente HTTP** que habla con `dockerd` (el daemon) a través de un socket Unix (`/var/run/docker.sock`) o TCP. El daemon es quien de verdad maneja imágenes, redes, volúmenes y contenedores.

```
┌────────────┐   HTTP sobre socket   ┌─────────────┐   gRPC   ┌──────────────┐
│   docker   │ ────────────────────> │   dockerd   │ ───────> │  containerd  │
│  (cliente) │                       │  (daemon)   │          │              │
└────────────┘                       └─────────────┘          └──────────────┘
                                                                       │
                                                                       ▼
                                                              ┌──────────────┐
                                                              │     runc     │
                                                              │ (OCI runtime)│
                                                              └──────────────┘
```

Consecuencia operacional: si el daemon está detenido, `docker ps` falla con "Cannot connect to the Docker daemon". No es un bug: no hay con quién hablar.

### 2.2 Docker Desktop no es "Docker en macOS", es una VM

macOS y Windows no tienen el kernel Linux que necesitan los contenedores. **Docker Desktop** (y colima, Rancher Desktop, OrbStack) resuelven esto corriendo una **VM Linux ligera** por debajo. Tu `docker` CLI nativo se comunica con el `dockerd` que vive dentro de esa VM.

Esto importa cuando:

- Haces un bind mount: el filesystem del host se tiene que exponer a la VM (hay un capa de traducción, con costo de rendimiento).
- Mides memoria/CPU: los límites son de la VM, no del Mac/Windows real.
- Expones puertos: el "localhost" del host y el "localhost" de la VM son distintos (Desktop hace un reenvío que lo oculta).

### 2.3 El grupo `docker` es equivalente a root

El socket `/var/run/docker.sock` pertenece a `root:docker`. Cualquiera en el grupo `docker` puede llamarlo. Y la API del daemon permite, entre otras cosas: montar `/` del host dentro de un contenedor como `rw`, y escribir cualquier archivo con permisos del daemon (root). Por tanto:

```
usuario ∈ grupo docker ⇒ usuario puede ser root en el host
```

No es un bug, es diseño. Las mitigaciones son: **rootless Docker**, Podman, o aceptar explícitamente este trade-off en una máquina de desarrollo.

---

## 3. Contexto histórico

- **2013** — Docker 0.x: CLI monolítica que hablaba directo a LXC.
- **2015** — Se crea la **OCI**; Docker extrae `runc` como runtime de referencia.
- **2016** — Se extrae `containerd` como runtime de alto nivel y se dona a la CNCF (2017).
- **2017** — La CLI se parte formalmente del daemon; aparece "Docker CE" (Community Edition).
- **2020** — Kubernetes anuncia la deprecación de "dockershim" (K8s hablaba a `dockerd` mediante un shim; ahora habla directo a `containerd`/CRI-O).
- **2021** — Docker Desktop se vuelve de pago para empresas grandes; aparecen alternativas (colima, Rancher Desktop, OrbStack).
- **2022** — Docker Engine 20.10+ estabiliza **rootless**; `docker compose` v2 (plugin Go) reemplaza al viejo `docker-compose` (Python).
- **2024+** — Soporte estable multi-arch con `buildx`; `containerd` como runtime default en muchas distros.

Nombre de las cosas que la gente confunde:

- **Docker** = la plataforma (CLI + daemon + builder).
- **Moby** = el proyecto upstream open-source del que Docker Inc. construye el producto.
- **containerd** = runtime de alto nivel, hoy en la CNCF, usado por Docker y por Kubernetes.
- **runc** = runtime de bajo nivel OCI; el que hace los `clone`/`unshare`.

---

## 4. Funcionamiento interno

### 4.1 Qué pasa cuando ejecutas `docker run -d --name web nginx:alpine`

1. **CLI** parsea argumentos y hace `POST /containers/create` al socket.
2. **daemon** valida; si la imagen no está localmente, hace `pull` (otro flujo entero: resolver tag → traer manifest → traer capas).
3. daemon arma la **config OCI runtime-spec**: cmd, env, mounts, cgroups, namespaces, capabilities, seccomp.
4. daemon llama a **containerd** con esa config.
5. containerd llama a **runc create** con la config.
6. **runc** hace `clone()` con las flags de namespace (`CLONE_NEWPID`, `CLONE_NEWNS`, ...), monta el rootfs (overlayfs de las capas de la imagen), aplica cgroups, drop de capabilities, carga seccomp, hace `pivot_root`, y queda listo con el proceso congelado en el entrypoint.
7. CLI hace `POST /containers/<id>/start` → daemon → containerd → `runc start` → el proceso arranca.
8. Si pasaste `-d`, la CLI retorna el ID. Si no, se queda stream-eando stdout.

Todo esto son syscalls al kernel. Docker no "ejecuta" nada; coordina.

### 4.2 Estados de un contenedor

```
                 docker run / start
                        │
created ────────────────┼─────────────────> running
                                              │
                                              │  docker pause
                                              ▼
                                           paused
                                              │  docker unpause
                                              ▼
                                           running
                                              │  SIGTERM/SIGKILL o exit del proceso
                                              ▼
                                           exited
                                              │  --restart policy
                                              ▼
                                         restarting ──> running
```

El estado vive en el daemon y se expone con `docker inspect .State`. `dead` es un estado raro (daemon no pudo limpiar; típicamente filesystem issues).

### 4.3 `docker exec` no es `ssh`

`ssh` abre una sesión en un sistema remoto que ya tiene usuarios, PAM, autenticación, shell. `exec` no hace nada de eso. Lo que hace es, resumido:

1. Toma el PID 1 del contenedor y lee `/proc/<pid>/ns/*` para encontrar sus namespaces.
2. Hace `setns()` para entrar en esos namespaces.
3. Lanza el proceso que pediste (`sh`, `cat`, lo que sea) **dentro de esos namespaces**.

Consecuencias:

- No hay autenticación: el daemon ya decidió por ti (si pudiste llamar al socket, puedes exec).
- Si el contenedor muere, tu `exec` muere.
- Lo que lanzas con `exec` **no es un hijo** de PID 1 dentro del contenedor; es un proceso adicional que comparte sus namespaces. Esto importa para señales, para reaping y para variables de entorno (el `exec` no hereda las variables de PID 1 por default; usa las del `ENV` de la imagen).

---

## 5. Ejemplo mínimo

Instala Docker (sección 10 de "buenas prácticas" tiene el detalle por SO) y verifica:

```bash
docker version
# Client y Server deben aparecer. Si solo aparece Client, el daemon no está hablando.

docker info | head -20
# Muestra qué storage driver, qué runtime, qué cgroup version, cuántos CPUs, etc.
```

Primer contenedor, comentado:

```bash
# Arrancamos nginx en background, con nombre y auto-remove al parar.
docker run -d --rm --name web -p 8080:80 nginx:alpine

# ¿Está vivo?
docker ps
#   CONTAINER ID   IMAGE          COMMAND                  STATUS         PORTS                  NAMES
#   abcd1234...    nginx:alpine   "/docker-entrypoint.…"   Up 2 seconds   0.0.0.0:8080->80/tcp   web

# Pedimos la home page.
curl -s http://localhost:8080 | head -5

# Logs (stdout/stderr del PID 1 del contenedor).
docker logs web | tail -5

# Un proceso ADICIONAL dentro del contenedor.
docker exec web nginx -v
docker exec -it web sh    # interactivo
# dentro:  ps -ef   (verás nginx como PID 1; tu sh es otro proceso)
# exit

# Parar: SIGTERM, 10s de grace, luego SIGKILL.
docker stop web

# Con --rm, el contenedor se eliminó al parar. Confirma:
docker ps -a | grep web || echo "ya no está"
```

Cinco minutos de prueba. Si todo esto corrió, el daemon está sano.

---

## 6. Implementación progresiva

### 6.1 Instalación

**Linux (Debian/Ubuntu, resumen)**:

```bash
# Según instrucciones oficiales (docs.docker.com/engine/install/).
curl -fsSL https://get.docker.com | sh      # convenience script, OK para dev
sudo usermod -aG docker "$USER"             # te hace "root equivalente" (ver §9)
newgrp docker                               # recarga grupos en la sesión actual
docker run --rm hello-world
```

**macOS**: Docker Desktop (`brew install --cask docker`), colima (`brew install colima && colima start`), u OrbStack.

**Windows**: Docker Desktop con backend WSL2 (requerido en Windows 10/11).

**Verificación universal**:

```bash
docker version       # cliente y servidor
docker info          # entorno del daemon
docker run --rm hello-world
```

### 6.2 Primer ciclo de vida completo

```bash
docker run -d --name db -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:16-alpine
docker ps                    # running
docker logs db | tail        # ver bootstrap
docker exec -it db psql -U postgres -c '\l'
docker stop db               # SIGTERM, luego KILL si no sale
docker ps -a | grep db       # exited
docker rm db                 # elimina el contenedor del daemon
```

### 6.3 Añadir flags conscientemente

| Flag | Qué hace | Cuándo |
|------|----------|--------|
| `-d` | detached (background) | servicios de larga vida |
| `-it` | TTY interactivo | shells, REPLs |
| `--rm` | borra el contenedor al salir | pruebas, scripts |
| `--name` | nombre humano | para `exec`, `logs`, `stop` |
| `--restart` | `no` / `on-failure` / `always` / `unless-stopped` | servicios locales |
| `-p HOST:CONT` | publica puerto | HTTP, DB |
| `-v HOST:CONT[:ro]` | bind mount | código montado para dev |
| `-v nombre:/path` | volumen nombrado | datos persistentes |
| `-e KEY=VAL` | variable de entorno | config |
| `--env-file` | varias variables | config desde archivo |
| `--init` | lanza `tini` como PID 1 | ver §7.4 |

### 6.4 Inspección a profundidad

```bash
docker inspect web
docker inspect --format '{{.State.Status}}' web
docker inspect --format '{{.NetworkSettings.IPAddress}}' web
docker inspect --format '{{json .Config.Env}}' web | jq .
```

`--format` usa Go templates; aprende tres o cuatro consultas y evitas scrollear 300 líneas de JSON.

---

## 7. Aplicación profesional

### 7.1 Clean lifecycle en scripts

Patrón para pruebas:

```bash
cid=$(docker run -d --rm nginx:alpine)
trap "docker rm -f '$cid' >/dev/null 2>&1 || true" EXIT
# ... usar $cid ...
```

El `trap` garantiza limpieza aunque el script falle. `--rm` cubre el caso de salida normal; `rm -f` el caso de kill del script.

### 7.2 `--restart` y qué eligen los sysadmins

- `no` (default): el daemon no reinicia si el contenedor sale.
- `on-failure[:n]`: reinicia solo si exit != 0, opcionalmente limitado a `n` intentos.
- `always`: reinicia siempre (incluso si lo paras tú — hay que `rm`).
- `unless-stopped`: como `always` pero respeta `docker stop` entre reinicios del daemon.

Para servicios de dev en una laptop: `unless-stopped` es casi siempre lo que quieres. En producción, no uses `--restart`; usa un orquestador (systemd, Kubernetes).

### 7.3 Logs no son storage

`docker logs` lee los archivos del **logging driver** (por default `json-file`, en `/var/lib/docker/containers/<id>/<id>-json.log`). Sin rotación, crecen sin límite y llenan el disco. Configura `log-opts` en `daemon.json` (`max-size`, `max-file`) o usa `local` driver (más compacto). En producción, suele mandarse a un colector (Fluent Bit, journald, Loki).

### 7.4 La trampa de PID 1 (sección crítica)

PID 1 en Linux es especial:

1. **No tiene handlers de señales por default**. `SIGTERM` y `SIGINT` enviados a PID 1 se **ignoran** salvo que el programa instale un handler explícito.
2. **Reparenta procesos huérfanos**. Si un proceso cuyo padre murió sigue vivo, el kernel se lo asigna a PID 1. Si PID 1 no hace `wait()` sobre ellos cuando terminan, se vuelven **zombies** (entries en la tabla de procesos sin consumir CPU/memoria pero contando contra límites de PIDs).

Dentro de un contenedor, PID 1 es el entrypoint. Si tu entrypoint es `/bin/sh -c "python app.py"`:

- `sh` es PID 1. `python` es hijo de `sh`.
- `docker stop` manda `SIGTERM` a PID 1 (`sh`). `sh` no reenvía señales a hijos. `python` no se entera.
- 10 segundos después, el daemon manda `SIGKILL` al PID 1 (que mata todo el PID namespace). Tu app no pudo cerrar conexiones ni flush de buffers.

Soluciones, de más a menos recomendada:

1. Usar la **forma exec** (`CMD ["python", "app.py"]`) para que tu app sea PID 1 directamente **y** manejar `SIGTERM` en código.
2. Usar `--init` (lanza `tini`, que reenvía señales y reap zombies).
3. Instalar `tini` como entrypoint en la imagen.

En este módulo lo verás reproducible en `examples/02-pid1-signals/`.

### 7.5 Elección de distribución del engine

| Entorno | Recomendación |
|---------|---------------|
| Dev personal en Linux | Docker Engine nativo (sin Desktop) |
| Dev personal en macOS | OrbStack (rápido) o colima (open-source) |
| Dev personal en Windows | Docker Desktop + WSL2 |
| CI runners | Docker Engine, Podman o nerdctl según política |
| Servidor para una app sola | **Docker no** — systemd + podman o systemd + containerd |
| Workstation con política sin daemon root | Podman o Docker rootless |

---

## 8. Trade-offs

**Daemon vs daemonless**:
- Docker (con daemon root): ergonomía, ecosistema, pero superficie de ataque amplia.
- Podman (daemonless, rootless-first): mejor seguridad por default, menor ergonomía en edge cases, compatible al 95 % con CLI de Docker.

**`--rm` vs persistir contenedores exited**:
- `--rm`: entorno limpio, no debuggeable post-mortem (los logs se pierden).
- Persistir: puedes hacer `docker logs` y `docker commit` de un contenedor muerto, pero acumulan basura.

**`-it` siempre vs cuando se necesita**:
- `-it` sin que haya una TTY real (CI, scripts) rompe la salida.
- Omitirlo cuando necesitas input (REPL) bloquea.

**`--restart always` en servicios locales**:
- Útil para servicios que quieres "siempre arriba".
- Peligroso para contenedores que fallan en bucle rápido (loop de restart satura CPU y logs).

**Docker Desktop vs alternativa**:
- Desktop: UI gráfica, soporte oficial, licencia.
- colima/OrbStack: open-source, más ligero, menos "producto".

**Logs en stdout vs archivo**:
- stdout → `docker logs` → logging driver. Idiomático en contenedores.
- Archivo dentro del contenedor → se pierde al eliminar; necesita volumen.

---

## 9. Errores frecuentes

- **"Cannot connect to the Docker daemon"**: el daemon no está arriba (`systemctl status docker`) o tu usuario no está en el grupo `docker` y falta `sudo`.
- **"Got permission denied while trying to connect to the Docker daemon socket"**: mismo problema, mismo arreglo. **Avisar en voz alta** que meter al usuario al grupo `docker` lo hace root.
- **`docker run busybox` "sale inmediatamente"**: busybox sin comando se vuelve `sh` sin TTY → EOF inmediato → exit 0. No es un error; es correcto.
- **`exec`-ing en un contenedor exited**: imposible; el PID namespace ya no existe.
- **"Port already in use"**: `-p 8080:80` falla si algo del host ya escucha en 8080. Verifica con `lsof -iTCP:8080 -sTCP:LISTEN`.
- **`docker stop` tarda 10 s siempre**: tu PID 1 no maneja SIGTERM. Arregla el entrypoint o usa `--init`.
- **`docker logs` vacío cuando tu app sí imprime**: la app imprime a un archivo o a `stderr` con buffer; configura la app para loggear a stdout sin buffer (en Python: `PYTHONUNBUFFERED=1`).
- **`docker rm -f` como herramienta por default**: funciona pero esconde problemas de PID 1 (siempre matas con SIGKILL). Usa `stop` primero.
- **Dejar contenedores exited y volúmenes danglers**: `docker system df` muestra cuánto; `docker system prune` limpia (lee antes qué borra).
- **Bind mount con ruta relativa**: Docker exige absoluta. `-v ./data:/data` falla; usa `-v "$PWD/data:/data"`.

---

## 10. Buenas prácticas

- Nómbralos (`--name`). "`silly_einstein`" no sirve en un script.
- Para pruebas efímeras, siempre `--rm`.
- Verifica siempre con `docker ps -a` tras `stop`: el contenedor sigue existiendo si no usaste `--rm`.
- Prefiere `docker stop` sobre `docker kill`. Si tarda, arregla la causa.
- Nunca uses `--privileged` por rutina. Si lo necesitas, documenta por qué.
- Mantén tu usuario fuera del grupo `docker` si la máquina es sensible; usa `sudo docker` o rootless.
- Para scripts, captura el ID (`cid=$(docker run -d ...)`) y limpia con `trap`.
- `--format` + `jq` convierten `docker inspect` en algo humano.
- No uses `latest` ni en imágenes de dev si quieres builds reproducibles; prefiere tags fijos (`nginx:1.27-alpine`).
- Si tu PID 1 no es "tu app", piensa dos veces. Si no puedes evitarlo, usa `--init`.

---

## 11. Ejercicios recomendados

1. Ejecuta `docker run -d --name web -p 8080:80 nginx:alpine` y, usando `--format`, extrae a una sola línea: `State.Pid`, `State.Status`, `Config.Entrypoint`, `HostConfig.PortBindings`.
2. Arranca `redis:alpine` detached, haz `exec` para abrir `redis-cli`, inserta un key, haz `docker restart` del contenedor, vuelve a entrar y comprueba si el key sigue (no debería; aún no vimos volúmenes).
3. Mide la diferencia de latencia de `docker stop` cuando el PID 1 es `sh -c "sleep 1000"` vs cuando es `sleep 1000` (forma exec). Debería ser ~10 s vs ~0.
4. Reproduce "el grupo docker es root": crea un contenedor con `-v /:/host` y lee `/host/etc/shadow`. **No hagas esto en tu máquina principal si no sabes qué estás haciendo.**
5. Ejecuta un contenedor sin TTY (`docker run alpine echo hola`) y uno con TTY (`docker run -it alpine echo hola`). Observa `docker ps -a --format '{{.Status}} {{.Command}}'` para los dos.

---

## 12. Evaluación

Responde sin consultar.

1. Dibuja la cadena completa desde que escribes `docker run` hasta que el kernel crea el proceso del contenedor. Nombra cada componente.
2. ¿Qué diferencia hay entre `docker kill` y `docker stop`? ¿En qué caso usarías cada uno?
3. Explica, con un ejemplo concreto que incluya un comando `docker run`, por qué agregar un usuario al grupo `docker` es equivalente a darle root en el host.
4. Tu contenedor tarda **exactamente 10 segundos** en responder a `docker stop`. ¿Qué está pasando? Da dos arreglos distintos.
5. ¿Por qué `docker exec -it mi-cont bash` falla con "executable file not found in $PATH" en una imagen `alpine` pero funciona en `debian`?
6. ¿Qué información obtiene `docker ps` y de dónde la obtiene? ¿Puede un contenedor estar corriendo y no aparecer en `docker ps`?
7. Dado `docker inspect` de un contenedor, ¿qué campos consultas primero para saber (a) si está vivo, (b) qué puertos expone, (c) qué variables de entorno tiene, (d) qué comando corre?
8. ¿Qué pasa si tu `CMD` en Dockerfile es `CMD python app.py` (forma shell) en términos de PID 1 y señales?

---

## Referencias

- `README.md` de este módulo y `resources/links.md`.
- Siguiente módulo: `dkr-03-images-dockerfile-basics`.
