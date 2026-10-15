# Actividad 01 — Construye un mini-contenedor con `unshare`

## 1. Identificación

- **ID:** `dkr-10-01-build-container-with-unshare`
- **Tecnología:** `docker`
- **Módulo:** `dkr-10-internals-namespaces-cgroups-overlayfs`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Construir, con herramientas del kernel y sin `docker run`, un "mini-contenedor" funcional: rootfs chroot, namespaces nuevos, cgroup v2 con límite de memoria. Al terminar vas a entender qué hace `runc` cuando el daemon le pasa un `config.json`.

## 3. Objetivos

Al terminar deberías poder:

- Exportar un rootfs mínimo desde una imagen de Docker.
- Crear un cgroup v2 `mini` con `memory.max=64M` y `pids.max=50`.
- Entrar en namespaces nuevos (`mnt, uts, ipc, net, pid, user`) con `unshare`.
- Chroot al rootfs y correr un `/bin/sh` dentro.
- Verificar aislamiento: `ps aux` solo muestra procesos del mini-contenedor, `ip link` solo `lo`, `hostname` cambia sin afectar al host.
- Disparar un OOM-kill desde dentro y verlo contabilizado en `/sys/fs/cgroup/mini/memory.events`.

## 4. Prerrequisitos

### Conocimientos

- `dkr-01` (modelo mental), `dkr-02` (CLI), T-2 (Linux básico).

### Software

- Kernel Linux ≥ 5.2 con **cgroups v2 unificados** (`stat -fc %T /sys/fs/cgroup` → `cgroup2fs`).
- `util-linux` (`unshare`, `nsenter`, `lsns`) — presente por default en toda distro moderna.
- `cgroup-tools` opcional (`sudo apt-get install -y cgroup-tools`).
- `docker` para exportar un busybox rootfs.
- Permisos `sudo`.

### Plataforma

- **Linux obligatorio.** En macOS/Windows, lanza una VM:

  ```bash
  # Opción A: multipass
  multipass launch --name dkr10 --cpus 2 --memory 2G --disk 10G 22.04
  multipass shell dkr10

  # Opción B: Vagrant
  mkdir -p ~/dkr10 && cd ~/dkr10
  vagrant init ubuntu/jammy64
  vagrant up && vagrant ssh
  ```

  Luego instala Docker en la VM y ejecuta esta actividad allí.

### Costos

Ninguno.

## 5. Instrucciones

### 5.1 Preparar área de trabajo

```bash
sudo rm -rf /tmp/mini-rootfs
mkdir -p /tmp/mini-rootfs
```

### 5.2 Exportar un rootfs busybox

```bash
CID=$(docker create busybox:latest)
docker export "$CID" | sudo tar -C /tmp/mini-rootfs -xf -
docker rm "$CID"
ls /tmp/mini-rootfs
# bin dev etc home proc root sys tmp usr var
```

### 5.3 Crear un cgroup v2 con límites

```bash
sudo mkdir -p /sys/fs/cgroup/mini
# Habilita controladores en el padre
echo "+memory +pids +cpu" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
# Límite: 64 MiB
echo $((64*1024*1024)) | sudo tee /sys/fs/cgroup/mini/memory.max
# Límite: 50 PIDs
echo 50                | sudo tee /sys/fs/cgroup/mini/pids.max
# Verificar
cat /sys/fs/cgroup/mini/memory.max
cat /sys/fs/cgroup/mini/pids.max
```

### 5.4 Lanzar el shell en namespaces nuevos

En **terminal A** (del host):

```bash
sudo unshare --user --map-root-user \
             --mount --uts --ipc --net --pid --fork \
             --mount-proc=/tmp/mini-rootfs/proc \
             chroot /tmp/mini-rootfs /bin/sh
```

Dentro del shell interno:

```
/ # hostname mini && hostname
/ # ps aux               # Debe mostrar solo PID 1 (sh) y el ps
/ # ip link              # solo lo
/ # ls /                 # es /tmp/mini-rootfs del host
/ # cat /proc/self/status | grep -E 'Pid|Uid'
```

### 5.5 Meter el shell en el cgroup

En **terminal B** (del host, otro shell):

```bash
# Encontrar el PID del sh del mini-contenedor
PID=$(ps -ef | awk '/chroot \/tmp\/mini-rootfs/ {print $2; exit}')
echo "Shell interno PID (host-side): $PID"
echo "$PID" | sudo tee /sys/fs/cgroup/mini/cgroup.procs
cat /sys/fs/cgroup/mini/cgroup.procs
```

### 5.6 Comparar namespaces host vs. mini

```bash
# Namespaces del shell interno visto desde el host
sudo readlink /proc/$PID/ns/{pid,net,mnt,uts,user,ipc,cgroup}
# Comparar con los del propio shell del host
readlink /proc/$$/ns/{pid,net,mnt,uts,user,ipc,cgroup}
# lsns compacto
sudo lsns -p "$PID"
```

Los inodes **deben ser distintos** en pid, net, mnt, uts, user, ipc (`cgroup` depende de si `--cgroup` se pasó; en este lab no se pasa).

### 5.7 Disparar un OOM

Dentro del shell interno:

```
/ # dd if=/dev/zero of=/dev/shm/x bs=1M count=200 2>&1 || echo "KILLED"
```

Desde el host:

```bash
cat /sys/fs/cgroup/mini/memory.events
# low 0
# high 0
# max N
# oom N
# oom_kill 1       <-- esto es lo que buscamos
```

### 5.8 Dejar evidencia para el validator

El validator espera estos marcadores (los crea el proceso de setup):

```bash
mkdir -p /tmp/mini-notes
sudo cat /sys/fs/cgroup/mini/memory.max   > /tmp/mini-notes/memory.max
sudo cat /sys/fs/cgroup/mini/pids.max     > /tmp/mini-notes/pids.max
sudo cat /sys/fs/cgroup/mini/memory.events > /tmp/mini-notes/memory.events
sudo lsns -p "$PID" > /tmp/mini-notes/lsns.txt
```

### 5.9 Validar

```bash
bash tests/validate.sh
```

En **macOS/Windows** el validator imprime `SKIP: Linux required` y sale con 0.

## 6. Resultado esperado

- `/tmp/mini-rootfs/` contiene un rootfs busybox exportado.
- `/sys/fs/cgroup/mini/` existe con `memory.max = 67108864` y `pids.max = 50`.
- El shell interno ve solo sus propios procesos y una interfaz `lo` sin red.
- Al reventar la memoria, `memory.events` muestra `oom_kill >= 1`.
- `/tmp/mini-notes/` tiene las 4 evidencias.
- `bash tests/validate.sh` → `OK`.

## 7. Criterios de aceptación

- [ ] El cgroup `mini` existe y tiene `memory.max=67108864`.
- [ ] El cgroup `mini` tiene `pids.max=50`.
- [ ] `/tmp/mini-notes/memory.events` muestra `oom_kill` ≥ 1.
- [ ] `/tmp/mini-notes/lsns.txt` muestra ≥ 5 namespaces distintos para el PID.
- [ ] `/tmp/mini-rootfs/bin/busybox` existe.
- [ ] Validator pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

El validator detecta Linux con `uname -s`. En Darwin/MINGW* imprime `SKIP` con instrucciones de VM y exit code 0 (no falla el pipeline, pero no acredita completitud).

## 9. Preguntas de reflexión

1. Comparando `readlink /proc/<pid>/ns/pid` del shell interno y del host, ¿por qué el inode difiere? ¿Qué pasa si olvidas `--mount-proc`?
2. ¿Por qué sin `--fork` el `unshare` del `pid` namespace no funciona como esperas?
3. ¿Qué le pasaría a tu mini-contenedor si *otro* usuario del host hace `kill -9` al PID visto desde el host?
4. En este lab el `net` namespace solo tiene `lo`. ¿Qué comandos ejecutarías en el host para darle una interfaz `veth` conectada a un bridge? (no hace falta implementarlo).
5. Enumera cinco cosas que `runc` hace y este lab **no**.

## 10. Extensiones (opcional)

- **E1** — Añade un `veth` par y conéctalo a un bridge Linux (`ip link add veth0 type veth peer name veth1`, `ip link set veth1 netns <mini-pid-net-ns>`), dale IP, prueba `ping` desde dentro.
- **E2** — Monta un `overlayfs` real como rootfs (ver `examples/02`) en vez de `chroot` plano.
- **E3** — Lee `/proc/self/status` dentro del mini-contenedor y compara `CapEff` con el de `docker run --rm alpine`. ¿Son iguales? ¿Por qué?
- **E4** — Escribe un wrapper Bash `./mini-run <image> <cmd>` que automatice los pasos 5.2–5.5.

## 11. Limpieza

```bash
# Salir del shell interno (Ctrl+D o `exit`)
sudo rmdir /sys/fs/cgroup/mini 2>/dev/null || true
sudo rm -rf /tmp/mini-rootfs /tmp/mini-notes
```
