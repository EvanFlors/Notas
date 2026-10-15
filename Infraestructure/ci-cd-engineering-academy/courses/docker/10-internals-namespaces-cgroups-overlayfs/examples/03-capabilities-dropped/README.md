# Ejemplo 03 — Capabilities: default, dropped, privileged

## Concepto que demuestra

Que un contenedor "root" **no** es root del host: Docker le quita capabilities. Demostramos con `ping` (necesita `CAP_NET_RAW`) y con `mount` (necesita `CAP_SYS_ADMIN`).

## Plataforma

**Linux-only.** En macOS/Windows: VM Linux (`multipass`, `vagrant`).

## Prerrequisitos

- Docker Engine.
- `libcap-ng-utils` opcional dentro de la imagen (para `pscap`); también sirve leer `/proc/self/status`.

## Ejecución

### 1. Capabilities efectivas por default

```bash
docker run --rm alpine grep ^Cap /proc/self/status
```

Salida típica:

```
CapInh: 0000000000000000
CapPrm: 00000000a80425fb
CapEff: 00000000a80425fb
CapBnd: 00000000a80425fb
CapAmb: 0000000000000000
```

Decodificar:

```bash
docker run --rm alpine sh -c 'apk add -q libcap >/dev/null && capsh --decode=00000000a80425fb'
# cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,
# cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
```

Son 14. Observa qué **no** está: `cap_sys_admin`, `cap_sys_module`, `cap_sys_ptrace`, `cap_net_admin`, `cap_sys_time`, etc.

### 2. `--cap-drop=ALL`: ping falla

```bash
docker run --rm --cap-drop=ALL alpine ping -c1 1.1.1.1
# PING 1.1.1.1 ...  ping: permission denied (are you root?)
echo "exit=$?"   # 2
```

Hemos quitado todas las caps. Aunque uid=0, `ping` no puede abrir un raw socket.

### 3. Volver a añadir solo `NET_RAW`

```bash
docker run --rm --cap-drop=ALL --cap-add=NET_RAW alpine ping -c1 1.1.1.1
# 64 bytes from 1.1.1.1: seq=0 ttl=... time=...
```

Funciona. Este es el patrón de **mínimo privilegio**.

### 4. Default no basta para `mount`

```bash
docker run --rm alpine sh -c 'mkdir /mnt/x && mount -t tmpfs none /mnt/x'
# mount: permission denied (are you root?)
```

`mount` necesita `CAP_SYS_ADMIN`, que **no** está en el default.

### 5. `--privileged` lo habilita todo

```bash
docker run --rm --privileged alpine sh -c 'mkdir /mnt/x && mount -t tmpfs none /mnt/x && echo ok && mount | tail -1'
# ok
# none on /mnt/x type tmpfs (rw,relatime,inode64)
```

Y además:

```bash
docker run --rm --privileged alpine grep ^Cap /proc/self/status
# CapEff: 000001ffffffffff   <-- todas las capabilities
```

También verás que **el seccomp profile está unconfined** y que el contenedor tiene acceso a devices del host (`ls /dev` muestra sda, nvme0n1…). Por eso `--privileged` es, en la práctica, "root del host" (y a veces peor, porque viene con una imagen laxa).

### 6. Comparación tabular

```
                              NET_RAW   SYS_ADMIN  seccomp  /dev host
docker run <img>               YES       no         default  no
docker run --cap-drop=ALL      no        no         default  no
docker run --cap-add=NET_RAW   YES       no         default  no
docker run --privileged        YES       YES        unconf   YES
```

## Resultado esperado

- `ping` falla con `--cap-drop=ALL` y pasa cuando añades `NET_RAW`.
- `mount` falla por default y pasa con `--privileged`.
- `CapEff` del contenedor privileged es `0x1ffffffffff`.

## Interpretación

- Capabilities = subset de poderes de root. Docker aplica un subset "seguro" por default.
- Añade solo lo que necesitas. Nunca uses `--privileged` para "arreglarlo".
- `--privileged` no es un switch de debug; es un switch de riesgo.

## Errores frecuentes

- **"Why `ping` works as a non-root alpine user?"** → Alpine instala `ping` como `cap_net_raw+ep` setcap. Aun así necesita que el proceso tenga `CAP_NET_RAW` en su bounding set.
- **Esperar que `--security-opt no-new-privileges`** reemplace a dropear caps. Son controles complementarios.

## Limpieza

Ninguna. Los contenedores son `--rm`.
