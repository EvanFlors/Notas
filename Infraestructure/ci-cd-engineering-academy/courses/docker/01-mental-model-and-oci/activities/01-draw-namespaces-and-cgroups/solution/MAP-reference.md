# MAP (reference) — dkr-01: Namespaces, cgroups y pila Docker→runc

> Autoevaluación. **No** es una respuesta única — es *una* respuesta correcta y profesional.

## A. Namespaces de Linux

| Namespace | Qué aisla | Antes vs después |
|-----------|-----------|------------------|
| **pid**     | Tabla de PIDs. | Antes: `ps` ve todos los procesos del host. Después: solo ve a sí mismo (PID 1) y a sus hijos. |
| **mnt**     | Tabla de mounts. | Antes: comparte `/`, `/proc`, mounts del host. Después: `/` es un overlayfs propio; monta/desmonta sin afectar al host. |
| **net**     | Interfaces de red, tabla de rutas, iptables, sockets. | Antes: ve `eth0` real. Después: solo ve su `lo` y, si tiene veth-pair, su `eth0` virtual conectado al bridge `docker0`. |
| **user**    | Mapeo UID/GID. | Antes: UID 0 dentro == UID 0 fuera (peligroso). Después: UID 0 dentro mapea a UID 100000 (p. ej.) fuera; "root" dentro es usuario normal fuera. |
| **uts**     | Hostname y domainname. | Antes: `hostname` muestra el del host. Después: muestra el propio del contenedor; cambiarlo no afecta al host. |
| **ipc**     | SysV IPC, POSIX message queues. | Antes: comparte colas y shm con el host. Después: colas y shm propios; aislamiento IPC. |
| **cgroup**  | Vista de la jerarquía de cgroups. | Antes: ve toda la jerarquía global en `/sys/fs/cgroup/`. Después: solo ve su propio sub-árbol (no sabe cómo lo limitan "desde fuera"). |

**Nota sobre user namespace en Docker:** disponible pero **no activado por default** por razones históricas (compatibilidad con `-v`, `--pid=host`, imágenes que asumen UID 0 real, etc.). Hay que habilitarlo explícitamente con `userns-remap` en `dockerd`. **Podman** sí lo habilita por default — por eso es "rootless-first".

## B. Controladores de cgroups v2

- **cpu** — archivo clave `cpu.max` (formato `"<max> <period>"`, ej. `"50000 100000"` = 50% de CPU). Un proceso que supera el límite es **throttled** (ralentizado, no muerto).
- **memory** — archivo `memory.max` (bytes). Si un proceso supera, el **OOM killer del cgroup** lo mata (sin afectar al host). También existe `memory.swap.max`.
- **pids** — archivo `pids.max`. Si se supera, `fork()` falla con `EAGAIN`. Mitiga **fork-bombs** y runaway thread creation.
- **io** — archivos `io.max`, `io.weight`. Limita ancho de banda o prioridad de lectura/escritura en bloques por device.
- (Otros habituales: `cpuset` para pin a CPUs específicas, `hugetlb` para huge pages, `rdma`, etc.)

## C. Pila Docker → runc

```
┌──────────────────────────────────────────────────────────┐
│  docker (CLI)                                            │
│  Parsea args, llama a dockerd por su socket Unix.        │
└───────────────────────────┬──────────────────────────────┘
                            │ REST over /var/run/docker.sock
                            ▼
┌──────────────────────────────────────────────────────────┐
│  dockerd (daemon, root por default)                      │
│  - Image store, networks, volumes, API.                  │
│  - Delega build a BuildKit.                              │
│  - Delega runtime a containerd vía gRPC.                 │
└───────────────────────────┬──────────────────────────────┘
                            │ gRPC
                            ▼
┌──────────────────────────────────────────────────────────┐
│  containerd (runtime de ALTO nivel, CNCF)                │
│  - Pull desde registry (distribution-spec).              │
│  - Snapshots (overlayfs).                                │
│  - Lifecycle del contenedor.                             │
│  - Spawn-ea un containerd-shim por contenedor.           │
└───────────────────────────┬──────────────────────────────┘
                            │ exec
                            ▼
┌──────────────────────────────────────────────────────────┐
│  containerd-shim-runc-v2 (uno por contenedor)            │
│  - "Padre adoptivo" del PID 1 del contenedor.            │
│  - Sobrevive a restarts de containerd.                   │
│  - Llama a runc create/start.                            │
└───────────────────────────┬──────────────────────────────┘
                            │ exec
                            ▼
┌──────────────────────────────────────────────────────────┐
│  runc (runtime de BAJO nivel, OCI runtime-spec)          │
│  - Lee config.json (OCI runtime-spec).                   │
│  - clone/unshare/setns con flags de namespaces.          │
│  - mount overlayfs; mount /proc, /sys, /dev.             │
│  - pivot_root al nuevo rootfs.                           │
│  - Escribe en /sys/fs/cgroup/... (cgroups v2).           │
│  - capset(), prctl(PR_SET_NO_NEW_PRIVS), carga seccomp.  │
│  - execve() al proceso del contenedor.                   │
└───────────────────────────┬──────────────────────────────┘
                            │ syscalls
                            ▼
┌──────────────────────────────────────────────────────────┐
│  Kernel Linux (namespaces, cgroups, overlayfs, seccomp)  │
└──────────────────────────────────────────────────────────┘
```

**Syscalls `clone`/`unshare`/`setns`/`pivot_root`/`mount`/`capset`:** las ejecuta **`runc`** (el runtime de bajo nivel). Nadie más en la pila toca esas syscalls directamente.

## D. Por qué OCI permite intercambiar runtimes

Una imagen construida por `docker build` cumple **OCI image-spec**: manifest + config + layers, todos content-addressable. Cualquier herramienta compatible (Podman, nerdctl, Kubernetes vía CRI) sabe leer ese formato porque está estandarizado. Al ejecutar, el runtime de bajo nivel (`runc`, `crun`, `youki`) consume un `config.json` que cumple **OCI runtime-spec**; es intercambiable. Para transportar la imagen entre máquinas, cualquier registry que implemente **OCI distribution-spec** (Docker Hub, GHCR, ECR, Harbor, Zot) funciona. Las tres specs juntas desacoplan **quién empaqueta, quién transporta y quién ejecuta**.

## Preguntas

1. Un contenedor "estándar" aísla **pid, mnt, net, uts, ipc, cgroup** (6 de 7). **NO aísla `user` por default** en Docker — por razones históricas de compatibilidad (bind mounts, `-v`, imágenes que asumen UID 0 real); hay que habilitarlo con `userns-remap`. Podman sí lo aísla por default.

2. Sin cgroups: una app con fuga de memoria consume toda la RAM del host; el OOM killer global empieza a matar procesos **del host**, no solo del contenedor. Una fork-bomb hace `fork()` ilimitado y colapsa la tabla de procesos del kernel. Resultado: un contenedor mal portado puede tirar al host entero.

3. Son **el mismo proceso**. Un proceso en Linux puede estar en varios namespaces simultáneamente; el PID *depende del namespace desde el que mires*. Desde el host, el PID namespace ancestral asigna 2340. Desde el PID namespace creado para el contenedor, el mismo proceso recibe el PID 1 porque es el init de ese namespace. Un solo `task_struct` en el kernel, varias vistas.

4. **`runc`** es el runtime de bajo nivel que hace las syscalls (clone/unshare/setns, mounts, cgroups, caps, seccomp) a partir de un `config.json`. **`containerd`** es el runtime de alto nivel que gestiona el ciclo completo (pull, snapshots, API, lifecycle) y **delega** en `runc` para la creación real. Reemplazar `runc` por `crun` es **trivial** (binario drop-in, misma OCI spec); reemplazar `containerd` es más grande porque es toda la lógica de gestión y hay que reconfigurar quién se conecta a él (dockerd, Kubernetes CRI, etc.).

5. Las syscalls `clone`/`unshare`/`setns`/`pivot_root` las hace **`runc`**. Las syscalls `mount` para el overlayfs las coordinan `containerd` (snapshots) + `runc` (mount dentro del contenedor): `containerd` prepara el `lowerdir`/`upperdir`/`workdir`, y `runc` ejecuta el `mount -t overlay` dentro del mount namespace del contenedor antes del `pivot_root`.

6. Con `--privileged` + `/var/run/docker.sock` montado: desde dentro puede invocar al daemon Docker del host y pedirle que arranque otro contenedor con `-v /:/host --privileged`. Eso lo deja escribiendo en `/` del host como root. Equivalente a root en el host **sin ninguna barrera**. Nunca se monta `docker.sock` sin entender esto (ver `dkr-13`).

7. En Linux con Docker esperarías ver que `dockerd` corre como demonio sistema (padre `systemd`), que `containerd` también es demonio sistema (independiente), y que por cada contenedor hay un `containerd-shim-runc-v2 → <proceso del contenedor>`. **El PID 1 del contenedor cuelga del shim, no de dockerd.** Esto permite reiniciar `containerd` o `dockerd` sin matar los contenedores. Si no tienes acceso: la jerarquía *esperada* es `systemd → containerd` y `systemd → dockerd`, con `containerd → containerd-shim-* → PID1-del-contenedor` como subárbol separado.
