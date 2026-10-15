# Ejemplo 01 — Mini-contenedor hecho a mano

## Concepto que demuestra

Replicar manualmente, con `unshare` + `chroot` + `cgcreate`, lo que `runc` hace por ti al correr `docker run`. Si entiendes este ejemplo, entiendes qué es un contenedor.

## Plataforma

**Linux-only.** En macOS/Windows: lanza una VM Ubuntu (`multipass launch --name dkr10 22.04 && multipass shell dkr10`) y ejecuta esto dentro.

## Prerrequisitos

- Linux kernel ≥ 5.2 con cgroups v2 unificado (verifica con `stat -fc %T /sys/fs/cgroup` → `cgroup2fs`).
- `sudo`, `unshare`, `chroot` (parte de `util-linux`).
- `cgroup-tools` (opcional, para `cgcreate`/`cgexec`). También funciona sin él escribiendo directamente al sysfs.
- `docker` disponible para exportar un rootfs base.

## Ejecución

```bash
# 1. Exportar un rootfs minimal
sudo rm -rf /tmp/mini-rootfs
mkdir -p /tmp/mini-rootfs
CID=$(docker create busybox:latest)
docker export "$CID" | sudo tar -C /tmp/mini-rootfs -xf -
docker rm "$CID"
ls /tmp/mini-rootfs
# bin dev etc home proc root sys tmp usr var

# 2. Crear un cgroup v2 "mini" con límites
sudo mkdir -p /sys/fs/cgroup/mini
# Habilitar controladores que vamos a usar en los hijos del root
echo "+memory +pids +cpu" | sudo tee /sys/fs/cgroup/cgroup.subtree_control

# Límite: 64 MiB de memoria, 50 PIDs, 50% de 1 CPU
echo $((64*1024*1024))       | sudo tee /sys/fs/cgroup/mini/memory.max
echo 50                      | sudo tee /sys/fs/cgroup/mini/pids.max
echo "50000 100000"          | sudo tee /sys/fs/cgroup/mini/cpu.max

# 3. Lanzar un shell en namespaces nuevos y chroot al rootfs
sudo unshare --user --map-root-user \
             --mount --uts --ipc --net --pid --fork \
             --mount-proc=/tmp/mini-rootfs/proc \
             chroot /tmp/mini-rootfs /bin/sh
```

Dentro del shell nuevo:

```
# hostname mini && hostname
# ps aux        # ← solo PID 1 (sh) y el ps
# ip link       # ← solo lo
# ls /          # ← es /tmp/mini-rootfs del host
# echo "contenido" > /hola.txt    # se crea en /tmp/mini-rootfs/hola.txt
```

Desde **otro terminal del host**, mete el shell en el cgroup:

```bash
# Encontrar el pid del sh dentro del mini-contenedor
PID=$(ps -ef | awk '/chroot \/tmp\/mini-rootfs/ {print $2; exit}')
echo "$PID" | sudo tee /sys/fs/cgroup/mini/cgroup.procs
cat /sys/fs/cgroup/mini/cgroup.procs
```

Prueba el límite de memoria dentro del shell:

```
# dd if=/dev/zero of=/dev/shm/x bs=1M count=200 2>&1 || echo "killed"
# cat /sys/fs/cgroup/mini/memory.events   # (no existe dentro; lee desde host)
```

Desde el host:

```bash
cat /sys/fs/cgroup/mini/memory.events
# ...
# oom_kill 1
```

## Resultado esperado

- El shell interno ve solo sus propios procesos (PID 1 = sh).
- Al pasar el PID al cgroup, al intentar asignar > 64 MiB el kernel mata el proceso.
- Al salir del shell, el namespace se destruye; el cgroup queda — hay que borrarlo.

## Interpretación

- `--user --map-root-user` crea un user namespace y mapea tu uid real al uid 0 interno.
- `--mount` da un mount namespace propio (requisito para `chroot` sin ensuciar el host).
- `--uts` permite cambiar `hostname` sin afectar al host.
- `--ipc` aísla SysV IPC.
- `--net` deja al contenedor sin red (solo `lo`); un contenedor Docker añade un `veth` conectado a `docker0`.
- `--pid --fork --mount-proc` crea un pid namespace **y** monta un `/proc` nuevo que refleja ese ns (sin `--mount-proc` seguirías viendo los procesos del host).

## Errores frecuentes

- **"unshare: write /proc/self/uid_map: Operation not permitted"** → kernel con user ns deshabilitado. Verifica `sysctl kernel.unprivileged_userns_clone`.
- **"mkdir: cannot create ... /sys/fs/cgroup/mini: Permission denied"** → necesitas `sudo` **y** cgroup v2 (no v1).
- **`ps` muestra procesos del host dentro del mini-contenedor** → olvidaste `--mount-proc`.
- **El cgroup no mata el proceso** → faltó habilitar `+memory` en `cgroup.subtree_control`.

## Limpieza

```bash
# Salir del shell interno. Luego:
sudo rmdir /sys/fs/cgroup/mini
sudo rm -rf /tmp/mini-rootfs
```
