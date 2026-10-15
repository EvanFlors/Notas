# Lección: Internals — namespaces, cgroups, overlayfs

> **ID:** `dkr-10-internals-namespaces-cgroups-overlayfs` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `dkr-01`, `dkr-02`, T-2 Linux.
> **Plataforma:** Linux. En macOS/Windows reproducir dentro de una VM (`multipass`, `vagrant`).

---

## 1. Introducción intuitiva

Lo que llamamos "contenedor" no es una entidad de primera clase en el kernel. **No hay** un syscall `create_container()`. Lo que hay es una colección de primitivas — `clone` con flags, `mount` con tipo `overlay`, archivos en `/sys/fs/cgroup/`, bits en `/proc/self/status` — que al combinarse dan la ilusión de "un proceso que vive en su propio mundo".

Un contenedor es, literalmente:

```
+--------------------- proceso Linux normal ---------------------+
| con namespaces propios (ve su propia tabla de PIDs, su propio  |
| hostname, su propia red, su propio filesystem root)            |
| con un cgroup v2 que le limita CPU, memoria, pids, io          |
| con capabilities reducidas (no todas las de root)              |
| con seccomp filtrando syscalls peligrosos                      |
| con un rootfs que es un overlayfs (capas de imagen + layer rw) |
+----------------------------------------------------------------+
```

Si entiendes **cada una** de esas restricciones, entiendes qué es un contenedor. Entenderás por qué `--privileged` no es "root al host" (aunque está muy cerca), por qué un contenedor "rooteado" no puede `tcpdump`, y por qué tu app se muere con `OOMKilled` aunque el host tenga 64 GB libres.

En este módulo bajamos del `docker run` al kernel y volvemos a subir.

---

## 2. Fundamentos: namespaces

Un **namespace** es una vista parcial de un recurso global del kernel. Si estás en el `pid` namespace A, el `ps` muestra solo los procesos del namespace A. El PID 42 en A no es el mismo que el PID 42 en B.

Linux define siete clases (más `time`, raramente usada):

| Namespace | Qué aisla | Flag `clone()` |
|-----------|-----------|----------------|
| `mnt`     | Puntos de montaje | `CLONE_NEWNS` |
| `pid`     | Tabla de PIDs | `CLONE_NEWPID` |
| `net`     | Interfaces, iptables, rutas, puertos | `CLONE_NEWNET` |
| `ipc`     | SysV IPC, POSIX message queues | `CLONE_NEWIPC` |
| `uts`     | Hostname, domainname | `CLONE_NEWUTS` |
| `user`    | Mapeo UID/GID | `CLONE_NEWUSER` |
| `cgroup`  | Vista de la jerarquía cgroup | `CLONE_NEWCGROUP` |

Cada proceso tiene un enlace simbólico por namespace en `/proc/<pid>/ns/`:

```
$ ls -l /proc/$$/ns/
lrwxrwxrwx 1 u u 0 ... cgroup -> 'cgroup:[4026531835]'
lrwxrwxrwx 1 u u 0 ... ipc    -> 'ipc:[4026531839]'
lrwxrwxrwx 1 u u 0 ... mnt    -> 'mnt:[4026531841]'
lrwxrwxrwx 1 u u 0 ... net    -> 'net:[4026531992]'
lrwxrwxrwx 1 u u 0 ... pid    -> 'pid:[4026531836]'
lrwxrwxrwx 1 u u 0 ... user   -> 'user:[4026531837]'
lrwxrwxrwx 1 u u 0 ... uts    -> 'uts:[4026531838]'
```

El número entre corchetes es el **inode** del namespace. Dos procesos con el mismo inode en `/proc/<pid>/ns/pid` están en el mismo pid namespace.

Tres herramientas de userland lo manipulan:

- **`unshare`** — ejecuta un comando en namespaces nuevos (equivale a `unshare(2)`).
- **`nsenter`** — entra en namespaces existentes (equivale a `setns(2)`).
- **`lsns`** — lista namespaces activos y qué procesos los habitan.

> **Default en Docker Engine:** `docker run` crea namespaces nuevos para `mnt, pid, net, ipc, uts, cgroup`. **No** crea un `user` namespace nuevo salvo que configures `userns-remap` en el daemon. Esto significa que root dentro del contenedor **es** uid 0 del host — las capabilities reducidas y seccomp son lo que impide que ese root haga daño, no un uid namespace. En Podman rootless, en cambio, `user` namespace es default.

---

## 3. Fundamentos: cgroups v2

Los **cgroups** (control groups) limitan y contabilizan el uso de recursos de un grupo de procesos. v2 unifica la jerarquía (en v1 había una por controlador, con bugs de consistencia célebres).

El filesystem `/sys/fs/cgroup/` es un árbol. Cada subdirectorio es un cgroup. Para crear uno:

```bash
sudo mkdir /sys/fs/cgroup/demo
```

Para mover un proceso ahí: escribir su PID a `cgroup.procs`:

```bash
echo $$ | sudo tee /sys/fs/cgroup/demo/cgroup.procs
```

Para habilitar un controlador en los hijos: escribir `+cpu +memory +pids` a `cgroup.subtree_control` del padre.

### 3.1 Traducción Docker → cgroup

| Flag Docker | Archivo cgroup v2 | Semántica |
|-------------|-------------------|-----------|
| `--memory=64m` | `memory.max` = `67108864` | hard limit; superar dispara OOM-killer en el cgroup |
| `--memory-swap=64m` | `memory.swap.max` = `0` (si = memory) | sin swap |
| `--cpus=1.5` | `cpu.max` = `150000 100000` | cuota/periodo (150 ms cada 100 ms) |
| `--cpu-shares=512` | `cpu.weight` = `20` (aprox) | peso relativo (default 100) |
| `--pids-limit=100` | `pids.max` = `100` | nº máximo de PIDs en el cgroup |
| `--blkio-weight` | `io.weight` | peso de I/O |

El cgroup de un contenedor Docker vive, típicamente, en:

```
/sys/fs/cgroup/system.slice/docker-<CONTAINER_ID>.scope/
```

(con systemd + cgroup driver `systemd`, el default moderno).

### 3.2 El OOM-killer de cgroup

Cuando los procesos de un cgroup intentan asignar memoria por encima de `memory.max`, el kernel invoca el OOM-killer **restringido a ese cgroup** — no mata procesos de otros cgroups. El proceso elegido recibe `SIGKILL`.

Esto se contabiliza en:

```
/sys/fs/cgroup/<path>/memory.events
# oom 3
# oom_kill 2
```

Y en Docker:

```json
"State": {
  "ExitCode": 137,
  "OOMKilled": true
}
```

137 = 128 + 9. Es un `SIGKILL` disfrazado de exit code (convención POSIX de shells).

---

## 4. Fundamentos: overlayfs

**overlayfs** es un filesystem de unión: toma varios directorios "lower" (de solo lectura), un "upper" (de lectura-escritura) y los presenta como un único directorio "merged".

```
      merged/          <-- lo que ves (y lo que es el rootfs del contenedor)
       /  \
      /    \   lookup
     /      \
  upper/   lower1/ : lower2/ : lower3/     (los ":" los separa; L1 gana si colisión)
   (RW)        (RO)    (RO)     (RO)

  workdir/   (auxiliar interno; mismo filesystem que upper; usado para atomicidad)
```

Reglas:

- **Lectura**: busca en `upper` primero; si no está, baja por los `lower` en orden.
- **Escritura de archivo nuevo**: va al `upper`.
- **Modificación de archivo que vive en un `lower`**: se hace **copy-up** completo al `upper`, luego se modifica allí. El `lower` nunca se toca (es RO).
- **Borrado**: se crea un *whiteout* (dispositivo char 0:0) en el `upper` que oculta el `lower`.

### 4.1 Cómo se mapea a Docker

Cada instrucción cacheable de un `Dockerfile` crea una **capa** (`tar` + metadata). Al correr `docker run image`, el engine:

1. Extrae cada capa a un directorio bajo `/var/lib/docker/overlay2/<layer-id>/diff/`.
2. Monta un overlayfs con esos diffs como `lowerdir` (en orden; capa inferior del Dockerfile al final de la cadena).
3. Crea un `upperdir` y `workdir` nuevos para el contenedor.
4. El `merged` resultante es el rootfs del contenedor.
5. Al eliminar el contenedor, `upperdir` y `workdir` se descartan: todo lo escrito se pierde. Esto es la razón de ser de los volúmenes.

Ver en vivo:

```bash
docker run -d --name demo nginx:alpine
docker inspect demo --format '{{json .GraphDriver}}' | jq
# {
#   "Data": {
#     "LowerDir": "/var/lib/docker/overlay2/XXX/diff:/var/lib/docker/overlay2/YYY/diff:...",
#     "MergedDir": "/var/lib/docker/overlay2/ZZZ/merged",
#     "UpperDir":  "/var/lib/docker/overlay2/ZZZ/diff",
#     "WorkDir":   "/var/lib/docker/overlay2/ZZZ/work"
#   },
#   "Name": "overlay2"
# }
```

---

## 5. Fundamentos: capabilities

**Capabilities** descomponen los poderes "de root" en ~40 permisos independientes. Un proceso puede tener `CAP_NET_RAW` pero no `CAP_SYS_ADMIN`.

Docker **mantiene por default** un subset mínimo (~14):

```
CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FSETID, CAP_FOWNER, CAP_MKNOD,
CAP_NET_RAW, CAP_SETGID, CAP_SETUID, CAP_SETFCAP, CAP_SETPCAP,
CAP_NET_BIND_SERVICE, CAP_SYS_CHROOT, CAP_KILL, CAP_AUDIT_WRITE
```

Deja caer todo lo demás. Entre lo que **no** tienes aunque seas uid 0 dentro del contenedor:

- `CAP_SYS_ADMIN` — montar filesystems, operar sobre namespaces, etc. (es "la nueva root" en muchos contextos).
- `CAP_SYS_MODULE` — cargar módulos del kernel.
- `CAP_SYS_PTRACE` — adjuntar a procesos arbitrarios.
- `CAP_NET_ADMIN` — modificar iptables, interfaces.
- `CAP_SYS_TIME` — cambiar el reloj.

Esto es la razón por la que `apt-get install tcpdump && tcpdump` *puede* fallar incluso siendo root dentro: necesita `CAP_NET_RAW` (que sí está por default) **y** acceso a la interfaz (que puede requerir `CAP_NET_ADMIN`, no está).

Flags:

- `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` → principio de mínimo privilegio.
- `--privileged` → todas las caps + sin seccomp + sin AppArmor + acceso a todos los devices del host. **No es "root": es más**. Un `--privileged` que puede escribir a `/dev/sda` puede destruir el host.

Inspeccionar:

```bash
docker run --rm alpine sh -c 'apk add -q libcap-ng-utils && pscap'
# o:
docker run --rm alpine grep CapEff /proc/self/status
# CapEff:  00000000a80425fb   (hex bitmask; decodificar con capsh --decode=0x...)
```

---

## 6. Implementación progresiva — un mini-contenedor a mano

Vamos a construir, syscall-equivalente, lo que hace `runc` por ti. Linux-only.

### 6.1 Preparar un rootfs

```bash
mkdir -p /tmp/mini-rootfs
# Export un rootfs de busybox desde Docker
CID=$(docker create busybox:latest)
docker export "$CID" | tar -C /tmp/mini-rootfs -xf -
docker rm "$CID"
ls /tmp/mini-rootfs
# bin  dev  etc  home  proc  root  sys  tmp  usr  var
```

### 6.2 Crear un cgroup con límite

```bash
sudo mkdir -p /sys/fs/cgroup/mini
# Habilitar controladores en el root
echo "+memory +pids +cpu" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
# Límite 64 MiB
echo $((64*1024*1024)) | sudo tee /sys/fs/cgroup/mini/memory.max
# Máximo 50 PIDs
echo 50 | sudo tee /sys/fs/cgroup/mini/pids.max
```

### 6.3 Entrar en namespaces nuevos y chroot

```bash
sudo unshare --user --map-root-user --mount --uts --ipc --net --pid --fork \
             --mount-proc=/tmp/mini-rootfs/proc \
             chroot /tmp/mini-rootfs /bin/sh
```

Dentro del shell:

```
# hostname
# ps aux        # ← solo ves PID 1 (sh) y el ps
# ls /          # ← este / es /tmp/mini-rootfs del host
# ip link       # ← solo lo    (ningún interfaz heredado)
```

### 6.4 Meter ese shell en el cgroup

Desde **otro** terminal del host, mientras el shell vive:

```bash
PID=$(pgrep -n -f 'unshare')   # o el pid real del sh dentro
echo "$PID" | sudo tee /sys/fs/cgroup/mini/cgroup.procs
```

Ahora el shell y sus hijos están limitados a 64 MiB. Prueba a reventarlo:

```
# dd if=/dev/zero of=/dev/shm/x bs=1M count=200
```

Terminará con `Killed` (SIGKILL del OOM-killer del cgroup).

### 6.5 Qué te falta para ser "docker"

Comparado con `docker run` te falta:

- **overlayfs** real (aquí usamos `chroot` plano; no hay capas inmutables).
- **capabilities** reducidas (`unshare --map-root-user` te da root en el user ns, pero fuera no).
- **seccomp** (ningún filtro).
- **cgroup driver systemd** y limpieza automática al salir.
- **networking** útil (ningún `veth` ni bridge; necesitas `ip link add veth…` manualmente).

Todo eso es, exactamente, lo que `runc` hace a partir de un `config.json` OCI runtime-spec.

---

## 7. Casos reales

### 7.1 "Mi app ve 64 CPUs y spawnea 64 workers"

Un contenedor con `--cpus=2` ve, al leer `/proc/cpuinfo`, **todas** las CPUs del host — porque `/proc/cpuinfo` no está "namespaced". Librerías como `os.cpu_count()` (Python), `runtime.NumCPU()` (Go) o `nproc` las ven todas. Resultado: el app arranca 32 workers y pierde todo el tiempo en context switches contra la cuota de cgroup.

Soluciones:

- Leer `cpu.max` del cgroup y calcular (`sched_getaffinity` también suele reflejar la realidad en algunos runtimes).
- Librerías modernas (OpenJDK 10+, Go 1.19+) leen cgroups directamente.
- Fijar el nº de workers por env (`WEB_CONCURRENCY`).

### 7.2 "OOMKilled a pesar de usar menos memoria"

El kernel contabiliza **RSS + page cache** contra `memory.max`. Un script que lee archivos grandes puede llenar el page cache y disparar OOM "sin tener nada en memoria".

- `cat /sys/fs/cgroup/<path>/memory.stat` muestra `anon`, `file`, `kernel`.
- Setear `--memory` y `--memory-swap` iguales elimina ambigüedad de swap.

### 7.3 "No puedo hacer tcpdump dentro del contenedor"

Falta `CAP_NET_RAW` o la interfaz es `eth0` virtual sin promiscuous. Workaround correcto: `docker run --cap-add=NET_RAW --cap-add=NET_ADMIN`. **Mal** workaround: `--privileged`.

### 7.4 "`chown` falla con `Operation not permitted` dentro del contenedor"

Si corres con `userns-remap`, el uid 0 del contenedor es, en el host, un uid alto (ej. 165536). Ese uid no es owner de los bind-mounts del host. `chown` del root interno falla porque no tiene `CAP_CHOWN` *efectivo contra ficheros del host*. Esto es feature, no bug.

---

## 8. Errores frecuentes

- **"privileged = root"**. No. Es root + todas las caps + sin seccomp + sin apparmor + acceso a devices. En muchos aspectos es peor que root del host, porque suele venir con un filesystem más laxo.
- **Confundir "no veo el proceso" con "el proceso no existe"**. Desde el host, los PIDs del contenedor existen con otro número (`docker inspect --format '{{.State.Pid}}'`).
- **Esperar que `--memory` limite swap**. No. Hay que setear `--memory-swap` también (= al `--memory` lo deshabilita).
- **Esperar reproducibilidad entre `overlay2` y `fuse-overlayfs`** (rootless). Los metadata (timestamps, inodes) difieren.
- **Montar `/var/run/docker.sock`** dentro de un contenedor pensando que es "poder". Es acceso al daemon = root del host. Nunca.

---

## 9. Mejores prácticas

- **Mínimo privilegio por default**: `--cap-drop=ALL --cap-add=<lo-que-necesites>`.
- **`--read-only` + `--tmpfs /tmp`** cuando sea posible: inmutabilidad del rootfs del contenedor.
- **Explicitar límites**: `--memory`, `--cpus`, `--pids-limit`. Un contenedor sin límites es un bomba lógica.
- **No `--privileged`**. Si crees que lo necesitas, enumera qué cap/device concreto y añade solo eso.
- **No montar `docker.sock`**. Usa un socket proxy (`tecnativa/docker-socket-proxy`) con whitelisting de endpoints si es inevitable.
- **Para debug profundo**: `nsenter --target <pid> --mount --uts --ipc --net --pid` sobre un `--pid=container:<id>` suele ser más limpio que `docker exec` + instalar herramientas.

---

## 10. Comparación de alternativas

| Opción | Namespaces por default | User ns | Seccomp | Caps |
|--------|-----------------------|---------|---------|------|
| **Docker Engine (rootful)** | mnt, pid, net, ipc, uts, cgroup | opt-in (`userns-remap`) | sí, perfil default ~44 syscalls bloqueados | subset de 14 |
| **Docker rootless** | todo lo anterior + `user` | **sí**, obligatorio | sí | subset |
| **Podman (rootless)** | todo + `user` | **sí**, obligatorio | sí | subset |
| **runc crudo** | lo que diga el `config.json` | lo que diga | sí si configurado | lo que diga |
| **`unshare` a mano** | lo que pidas | con `--user` | **no** | del proceso padre |
| **`--privileged`** | mnt, pid, net, ipc, uts, cgroup | no | **unconfined** | **todas** |

El punto importante: "contenedor" no es un nivel de seguridad fijo — es una tupla de restricciones. `--privileged` y `rootless Podman` son extremos opuestos del mismo espectro.

---

## 11. Experimentos reproducibles

Checklist de experimentos que deberías ejecutar en una VM Linux (ver `activities/01` para versión guiada con validator):

1. `lsns -p $(docker inspect -f '{{.State.Pid}}' <ctr>)` — listar namespaces del contenedor.
2. `readlink /proc/<host-pid>/ns/pid` vs. `readlink /proc/1/ns/pid` desde dentro → el inode es el mismo si estás en el mismo pid ns.
3. `docker run --rm --memory=64m polinux/stress stress --vm 1 --vm-bytes 128M --vm-hang 0` → disparar OOMKill a propósito.
4. `docker inspect --format '{{.State.OOMKilled}}' <ctr>` → `true`.
5. `cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.events` → ver `oom_kill N`.
6. `docker run --rm --cap-drop=ALL alpine ping -c1 1.1.1.1` → "Operation not permitted" (falta `CAP_NET_RAW`).
7. `docker run --rm --cap-drop=ALL --cap-add=NET_RAW alpine ping -c1 1.1.1.1` → funciona.
8. `docker run --rm --security-opt seccomp=unconfined --cap-add=SYS_ADMIN alpine sh -c 'mount -t tmpfs none /mnt && echo ok'` → ver qué cambia.

Documenta la salida de cada uno en tus notas; es el entregable principal del módulo.

---

## 12. Preguntas de evaluación (sin consultar docs)

Responde por escrito. Son la evaluación del módulo.

1. Enumera los 7 namespaces de Linux y qué recurso aisla cada uno.
2. Un `docker run alpine` default **¿en cuáles namespaces entra**, y en cuáles **no**? ¿Por qué el `user` namespace típicamente no, en Docker Engine rootful?
3. Describe el camino de un `OOMKilled`: desde la asignación de memoria del proceso hasta el `ExitCode=137` que ves en `docker inspect`.
4. Dado `lowerdir=A:B:C,upperdir=U,workdir=W`, ¿qué pasa cuando el contenedor modifica un archivo que vive en `B` pero no en `A` ni en `U`? Describe los archivos resultantes en `U`.
5. ¿Por qué `--privileged` no es equivalente a ser root del host? ¿Es más, menos, o incomparable?
6. Un contenedor estándar con uid=0 interno **¿puede** hacer `tcpdump`? ¿Puede modificar la tabla de rutas? Justifica por capability.
7. Explica cómo traducir `--cpus=1.5 --memory=512m --pids-limit=100` a archivos concretos bajo `/sys/fs/cgroup/`.
8. ¿Qué hace exactamente `unshare -Umnpf --mount-proc chroot <rootfs> /bin/sh` y qué le falta para ser un contenedor Docker "de verdad"?
9. ¿Por qué `/proc/cpuinfo` dentro de un contenedor con `--cpus=2` muestra todas las CPUs del host, y qué implicación tiene para tu app?
10. Si el contenedor es `userns-remapped` y uid 0 interno = uid 165536 externo, ¿qué pasa si intentas `chown 0:0` sobre un bind-mount `/host/data` propiedad de uid 1000 del host?
