# Lección: Modelo mental y OCI

> **ID:** `dkr-01-mental-model-and-oci` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** procesos y filesystem en Linux (T-2.1, T-2.2, T-2.4).

---

## 1. Introducción intuitiva

Imagina que un compañero te manda su aplicación por chat: tres archivos de Python, un `requirements.txt`, instrucciones. La bajas, intentas correrla, y:

- Él tenía Python 3.11; tú tienes 3.9.
- Él tenía `libpq-dev` instalada; tú no.
- Él tenía una variable de entorno `DATABASE_URL` que nunca te dijo.
- Él tenía `ulimit -n 65536`; tu laptop tiene `1024` y la app se queja a los 500 sockets.
- Su laptop es Linux; la tuya macOS.

Esto es "funciona en mi máquina", y el culpable no es Python ni macOS: es que el **entorno de ejecución** es un objeto implícito, invisible, sin forma. Puedes pasar el código, pero no puedes pasar la *máquina*.

Hay dos familias históricas de respuesta:

- **Virtualización completa (VMs):** empaquetar *la máquina entera*, con su kernel. Portable, pero pesada (gigabytes), lenta de arrancar (segundos a minutos), redundante (cada VM corre su propio kernel sobre el tuyo).
- **Contenerización:** empaquetar *solo el userland* — binarios, librerías, config, filesystem — y usar primitivas del kernel del host para aislar un **proceso** como si tuviera su propia máquina. Ligera (decenas de MB), arranca en milisegundos, un solo kernel para todos.

Un **contenedor** no es "una mini-VM". Es *un proceso Linux normal* al que el kernel le dice "tu PID 1 es tú mismo, tu `/` es ese otro directorio, tu red es esta otra, tu nombre de host es ése, y por cierto no puedes usar más de 512 MB de RAM". Toda esta gimnasia la hace el kernel con mecanismos que llevan años en Linux: **namespaces**, **cgroups**, **capabilities**, **seccomp**, **overlayfs**.

**Docker** es un conjunto de herramientas que hace esta gimnasia ergonómica, y define un formato de empaquetado reproducible: la **imagen**. OCI (Open Container Initiative) estandariza ese formato y el runtime para que no quedes amarrado a Docker.

---

## 2. Fundamentos

Tres ideas que necesitas tener claras antes de instalar nada.

### 2.1 Un contenedor es un proceso

Si entras por SSH al host y ejecutas `ps aux`, vas a ver el proceso del contenedor como un proceso cualquiera, con su PID "normal" en el host. Lo único raro es que **ese proceso cree** que su PID es 1 y que su filesystem es otro. El kernel miente consistentemente para ese proceso (y su árbol de hijos). Eso es un contenedor.

### 2.2 Una imagen es datos

Una imagen OCI no "contiene un proceso corriendo". Es un **artefacto inmutable** en disco: un manifest JSON + un config JSON + varias capas tar comprimidas (`.tar.gz` o `.tar.zstd`), todas identificadas por `sha256:...`. Igual que un commit de Git es datos content-addressable.

Un contenedor **nace** cuando un runtime toma esa imagen, la monta como filesystem, y arranca un proceso con la configuración que dice el config. Imagen = datos, contenedor = ejecución.

### 2.3 El runtime es quien hace las syscalls

Nadie "mete" el proceso en un contenedor por magia. Alguien ejecuta las syscalls:

- `clone(... CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWNET | ...)` para crear el proceso con namespaces nuevos.
- `unshare(...)` para separar namespaces del padre.
- `setns(...)` para unirse a namespaces existentes.
- `mount(...)` para montar el overlayfs y los filesystems virtuales (`/proc`, `/sys`, `/dev`).
- `pivot_root(...)` o `chroot(...)` para cambiar el filesystem root.
- Escribir en `/sys/fs/cgroup/...` para aplicar límites.
- `capset()` para dropear capabilities.
- `prctl(PR_SET_NO_NEW_PRIVS, ...)` y cargar un filtro seccomp.

El runtime que hace todo esto, en el stack típico de Docker, se llama **`runc`**. Es un binario Go minimalista que implementa la **runtime-spec** de OCI.

Memoriza estas tres ideas: **contenedor = proceso**, **imagen = datos**, **runtime = quien ejecuta las syscalls**. Todo lo demás es ergonomía encima.

---

## 3. Contexto histórico

Las primitivas que hacen posible contenerización en Linux llevan **décadas** apareciendo poco a poco:

- **2002** — Linux 2.4.19 introduce **mount namespaces**.
- **2006–2008** — Google (sí, Google) empuja **cgroups** al kernel para su propio uso interno (todos sus servicios corren en contenedores desde mucho antes que Docker existiera; se llamaban *Borg containers*).
- **2008** — **LXC** (Linux Containers) empaqueta estas primitivas en una herramienta usable.
- **2013** — **Docker** aparece como un wrapper ergonómico sobre LXC. Popularizó el modelo *build → ship → run* y el formato de imagen con capas. Explota.
- **2015** — Se funda la **Open Container Initiative (OCI)** en la Linux Foundation. Docker dona el runtime (`runc`) y el formato de imagen; otras empresas (Red Hat, Google, IBM, CoreOS) aportan. Nacen tres specs: **image-spec**, **runtime-spec**, **distribution-spec**.
- **2016** — **containerd** se extrae de Docker como componente independiente. Se dona a la CNCF.
- **2017–2020** — Kubernetes migra de `dockershim` a hablar directamente con containerd o CRI-O. El mundo descubre que *no necesita Docker* para correr contenedores — solo necesita un runtime OCI.
- **2020+** — Rootless containers, Podman, nerdctl, BuildKit, Wasm/WASI runtimes experimentales. Imágenes firmadas (Sigstore), SBOMs, provenance (SLSA).

Hoy "Docker" sigue siendo la herramienta más popular pero *técnicamente* es solo una implementación de las specs OCI. **Kubernetes, Cloud Run, ECS, Fly.io, GitHub Codespaces, Fly Machines** — ninguno "necesita Docker"; todos necesitan **imágenes OCI** y **un runtime OCI**.

### 3.1 Por qué OCI importa

Antes de OCI, "una imagen Docker" era un formato propietario de Docker Inc. Si quería mover una imagen a otro ecosistema (Rocket, LXD...), había fricciones. Con OCI:

- Cualquier registry compatible (**distribution-spec**) hospeda cualquier imagen (**image-spec**).
- Cualquier runtime compatible (**runtime-spec**) ejecuta cualquier imagen.
- Herramientas de la supply chain (cosign para firmas, syft para SBOM, Trivy para escaneo) hablan OCI, no "Docker".

OCI es a los contenedores lo que **HTTP** es a la web: un estándar aburrido que permite que todo lo demás se construya encima.

---

## 4. Funcionamiento interno

### 4.1 VMs vs contenedores

```
         VM (virtualización completa)                       Contenedor
┌────────────────────────────────────┐          ┌────────────────────────────────────┐
│  App 1   App 2   App 3             │          │  App 1   App 2   App 3             │
├────────────────────────────────────┤          ├────────────────────────────────────┤
│  libc + userland (invitado)        │          │  libc + userland (en imagen OCI)   │
├────────────────────────────────────┤          │                                    │
│  Kernel invitado (Linux/Windows)   │          │                                    │
├────────────────────────────────────┤          ├────────────────────────────────────┤
│  Hypervisor (KVM / Hyper-V / ESXi) │          │  Kernel del host (ÚNICO)           │
├────────────────────────────────────┤          ├────────────────────────────────────┤
│  Hardware                          │          │  Hardware                          │
└────────────────────────────────────┘          └────────────────────────────────────┘
         GB, segundos de arranque                     MB, milisegundos de arranque
```

Diferencia clave: la **VM** corre **un kernel invitado completo** encima del hypervisor. El **contenedor** reutiliza el kernel del host — no hay un segundo kernel. Por eso un contenedor es más ligero *y* por eso **un contenedor Linux no puede correr sobre un kernel Windows nativo** (Docker Desktop para Windows/macOS corre una VM Linux pequeña por debajo).

### 4.2 Namespaces: la ilusión de "mi propia máquina"

Un namespace es una partición del kernel que hace que un proceso vea una **vista** aislada de un recurso global. Linux hoy expone siete tipos de namespace:

| Namespace | Qué aisla | Analogía |
|-----------|-----------|----------|
| **`pid`**     | Tabla de procesos. Dentro del namespace, PID 1 es *tu* proceso. | "Yo soy el init de mi mundo." |
| **`mount`** (`mnt`) | Tabla de mounts. Puedes montar/desmontar sin afectar al host. | "Mi `/` es diferente al tuyo." |
| **`net`**     | Interfaces de red, tabla de rutas, iptables, sockets. | "Yo tengo `eth0`, tú tienes `eth0`, no son el mismo." |
| **`user`**    | Mapeo UID/GID. Puedes ser `root` *dentro* y usuario normal *fuera*. | "Soy rey en mi país; en el tuyo soy turista." |
| **`uts`**     | Hostname y domainname. | "Me llamo `foo`." |
| **`ipc`**     | SysV IPC, POSIX message queues. | "Mis colas no son tus colas." |
| **`cgroup`**  | Vista de la jerarquía de cgroups (ver §4.3). | "No veo cómo me limitan desde fuera." |

Un contenedor Docker estándar aísla **todos menos user** por default (user namespace existe pero no está activado por default por fricción histórica). Un contenedor **"privileged"** rompe muchos de estos aislamientos — es prácticamente ejecutar como root en el host.

Puedes **inspeccionar** los namespaces de un proceso real en Linux (requiere Linux, no macOS):

```bash
ls -l /proc/$$/ns/
# lrwxrwxrwx 1 user user 0 ... cgroup -> 'cgroup:[4026531835]'
# lrwxrwxrwx 1 user user 0 ... ipc    -> 'ipc:[4026531839]'
# lrwxrwxrwx 1 user user 0 ... mnt    -> 'mnt:[4026531840]'
# lrwxrwxrwx 1 user user 0 ... net    -> 'net:[4026531992]'
# lrwxrwxrwx 1 user user 0 ... pid    -> 'pid:[4026531836]'
# lrwxrwxrwx 1 user user 0 ... user   -> 'user:[4026531837]'
# lrwxrwxrwx 1 user user 0 ... uts    -> 'uts:[4026531838]'
```

Dos procesos con los mismos inodos (los números entre corchetes) comparten namespace. Dos procesos con inodos distintos están aislados en ese namespace. Un contenedor es un proceso con **la mayoría de inodos distintos** al host.

### 4.3 cgroups: la factura de recursos

Los namespaces **ocultan**. Los **cgroups** (control groups) **limitan y miden**. Un cgroup es un grupo de procesos al que el kernel aplica cuotas y del que lleva contabilidad:

- **CPU** — "no uses más de 0.5 CPU en promedio" (`cpu.max`).
- **Memoria** — "si pasas de 512 MB, mueres por OOM" (`memory.max`).
- **PIDs** — "no crees más de 100 procesos" (`pids.max`, mitiga fork-bombs).
- **I/O** — "no leas más de 10 MB/s del disco X" (`io.max`).
- **Red** — con `net_cls`/`net_prio` (menos usado; tc + eBPF es más moderno).

En **cgroups v2** (default en kernels modernos) la jerarquía es única y se expone en `/sys/fs/cgroup/`:

```
/sys/fs/cgroup/
├── cpu.max              # "max period" o "100000 100000"
├── memory.max           # "max" o "536870912"
├── pids.max             # "max" o "100"
└── docker/
    └── <container-id>/
        ├── cpu.max
        ├── memory.max
        └── pids.max
```

Cuando Docker crea un contenedor, el runtime (`runc`) crea un cgroup dedicado y escribe los límites configurados. El kernel aplica. Si tu proceso intenta superar `memory.max`, el **OOM killer** del cgroup lo mata (no al host entero).

### 4.4 overlayfs: capas copy-on-write

Una imagen OCI son **capas** (layers). Cada capa es un tarball de cambios respecto a la anterior. Cuando arrancas un contenedor, el storage driver (hoy casi siempre **`overlay2`**) combina las capas usando **overlayfs**:

```
contenedor ve: /         (merged view)
                ├── bin/
                ├── etc/
                ├── usr/
                └── app/

overlayfs internamente:
  lowerdir  = capa-base + capa-2 + capa-3 + ...    (read-only, de la imagen)
  upperdir  = /var/lib/docker/overlay2/<id>/diff   (read-write, SOLO del contenedor)
  workdir   = /var/lib/docker/overlay2/<id>/work   (uso interno del kernel)
  merged    = lo que ve el proceso
```

Reglas clave:

- Las capas inferiores son **read-only** y **compartidas** entre todos los contenedores que las usen (ahorro masivo de disco).
- Cualquier escritura va al **upperdir** del contenedor. Si editas un archivo que viene de una capa inferior, overlayfs lo *copia* al upper primero (copy-on-write), y luego escribes.
- Cuando **borras el contenedor**, el upperdir se destruye. Por eso los datos escritos en el filesystem del contenedor son **efímeros** (y por eso existen los volúmenes, cubiertos en `dkr-04`).

### 4.5 Las tres specs OCI

OCI publica tres specs, cada una resolviendo una pregunta distinta:

#### **image-spec** — "¿Qué es una imagen?"

Define el **manifest** JSON (schemaVersion, mediaType, config, layers[]), el **config** JSON (env, cmd, entrypoint, workingdir, user, labels, rootfs, history), y el formato de las **capas** (tarballs con un formato específico). Todo identificado por `sha256:...`.

Ejemplo abreviado de manifest:

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:a1b2c3...",
    "size": 7023
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:4e5f6g...",
      "size": 32654
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:7h8i9j...",
      "size": 162
    }
  ]
}
```

Esto es *todo* lo que es una imagen OCI: un JSON con hashes de otros blobs. Content-addressable, como Git.

#### **runtime-spec** — "¿Cómo se arranca?"

Define el **`config.json`** que describe un contenedor listo para ejecutar: comando, env, capabilities, namespaces, mounts, cgroup limits, seccomp profile. `runc` lee este archivo y hace las syscalls. Es la "receta de ejecución".

#### **distribution-spec** — "¿Cómo se transporta?"

Define la **API HTTP de registries**: cómo un cliente (`docker push`, `docker pull`, `cosign`, `syft`) sube y baja manifests y blobs a un registry (Docker Hub, GHCR, ECR, Harbor...). Endpoints como `GET /v2/<name>/manifests/<reference>` y `PUT /v2/<name>/blobs/uploads/...`.

### 4.6 La pila Docker → containerd → runc

Cuando ejecutas `docker run nginx`, pasan muchas cosas en varias capas:

```
┌────────────────────────────────────────────────────┐
│  docker (CLI)                                      │
│  Parsea args, llama a dockerd por su socket.       │
└──────────────────┬─────────────────────────────────┘
                   │ REST sobre /var/run/docker.sock
                   ▼
┌────────────────────────────────────────────────────┐
│  dockerd (daemon, por default corre como root)     │
│  - Pulls, image store, networks, volumes.          │
│  - Delega el build a BuildKit.                     │
│  - Delega el runtime a containerd.                 │
└──────────────────┬─────────────────────────────────┘
                   │ gRPC
                   ▼
┌────────────────────────────────────────────────────┐
│  containerd (runtime de ALTO nivel)                │
│  - Pull desde el registry, snapshots, lifecycle.   │
│  - Para cada contenedor spawn-ea un containerd-shim│
│  - Shim llama al runtime de BAJO nivel.            │
└──────────────────┬─────────────────────────────────┘
                   │ exec
                   ▼
┌────────────────────────────────────────────────────┐
│  runc (runtime de BAJO nivel, OCI-spec)            │
│  - Lee config.json del contenedor.                 │
│  - Hace clone/unshare/setns, mount, pivot_root,    │
│    capset, prctl, carga seccomp, escribe cgroups.  │
│  - Exec al proceso del contenedor.                 │
└──────────────────┬─────────────────────────────────┘
                   │
                   ▼
         Proceso Linux "normal" aislado
```

Puntos importantes:

- **Separación de responsabilidades**: `dockerd` entiende de "imágenes y proyecto", `containerd` entiende de "ciclo de vida y snapshots", `runc` entiende de "syscalls del kernel". Puedes cambiar `runc` por `crun` (implementación en C, más rápida) sin que Docker se entere.
- **Alternativas sin Docker**: **Podman** no tiene daemon y usa `crun` + `conmon`. **nerdctl** es una CLI estilo Docker directa sobre containerd. **Kubernetes** habla CRI con containerd o CRI-O, saltándose Docker completamente.
- **El socket de Docker es root-equivalente**: si tienes acceso a `/var/run/docker.sock` tienes root al host (puedes `docker run --privileged -v /:/host ...`). Lo veremos en `dkr-13`.

---

## 5. Ejemplo mínimo

Vamos a *leer* el manifest de una imagen OCI real, sin instalar Docker. Un manifest es solo JSON — se puede fetchear directo de un registry público con `curl`.

```bash
# Pedir el manifest de alpine:3.19 a Docker Hub.
# Primero necesitamos un token anónimo (Docker Hub lo entrega gratis para pulls públicos):
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull" | \
        python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

# Ahora el manifest. El Accept header dice qué formato queremos.
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.oci.image.manifest.v1+json" \
     "https://registry-1.docker.io/v2/library/alpine/manifests/3.19" | python3 -m json.tool
```

Verás algo como:

```json
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "manifests": [
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": "sha256:abc...",
            "size": 528,
            "platform": {"architecture": "amd64", "os": "linux"}
        },
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": "sha256:def...",
            "size": 528,
            "platform": {"architecture": "arm64", "os": "linux", "variant": "v8"}
        }
    ]
}
```

Esto es un **manifest index** (una imagen multi-arch). Para una plataforma concreta pides *ese* digest con el `Accept` adecuado y obtendrás el manifest de verdad: `config` + `layers[]`.

**No tenías Docker instalado** y leíste la estructura entera de una imagen pública con `curl` y `python -m json.tool`. Esa es la gracia de OCI: todo es JSON y hashes.

En `examples/02-oci-manifest-walkthrough/` tienes un manifest capturado y comentado línea a línea, por si no tienes red o quieres leerlo offline.

---

## 6. Implementación progresiva

Para ver el modelo en acción sin Docker, un *contenedor hecho a mano* en Linux (si estás en macOS, lee y entiende; en `dkr-10` lo haces en una VM). El objetivo es ver que un contenedor es solo syscalls:

```bash
# 1. Mount namespace nuevo + propagación privada.
sudo unshare --mount --uts --ipc --net --pid --fork /bin/sh

# Dentro del nuevo "contenedor":
hostname mini-container          # uts namespace: hostname propio
mount -t proc proc /proc         # mount namespace: /proc nuevo
ps auxf                          # pid namespace: solo veo mi árbol
ip link                          # net namespace: solo lo (loopback), sin eth0
```

Observa:

- `ps` solo muestra el shell y sus hijos — porque PID namespace nuevo.
- `ip link` muestra solo loopback — porque net namespace nuevo (y sin virtual ethernet pair conectado).
- `hostname` dentro no afecta al host — porque uts namespace nuevo.

Si ahora añades un `chroot` a un directorio con un `/bin/sh` estático (o un *rootfs* desempaquetado de alpine), tienes el filesystem también aislado. Añade `cgcreate` + escrituras en `/sys/fs/cgroup/...` y tienes los límites. Lo que te falta para "parecerte a Docker" es: cargar un seccomp profile, dropear capabilities, y automatizar todo esto desde un `config.json`.

Esto es *literalmente* lo que `runc` hace cuando llamas `docker run`. En `dkr-10` lo reproduces completo.

---

## 7. Aplicación profesional

### 7.1 Por qué este modelo mental vale dinero

Cuando entres a un equipo real, nadie te preguntará "¿qué namespaces aisla un contenedor?" en una entrevista — te lo pedirá *implícitamente* cuando:

- Tu app no vea el loopback del host → "ah, net namespace separado, obvio".
- Tu contenedor OOM-killed con 400 MB usados → "ah, `memory.max` del cgroup está en 384 MB".
- Un contenedor "ve" procesos del host → "ah, está `--pid=host`, eso es peligroso".
- `docker ps` muestra PIDs raros → "ah, son los PIDs del *host*; dentro del contenedor son otros".
- Un pull de 1.2 GB tarda segundos en el segundo nodo → "ah, capas compartidas vía overlayfs".
- La imagen `latest` cambia bytes entre dos pulls → "ah, tag mutable; debería referenciarse por digest".

Entender el modelo evita que debuguees "síntomas de Docker" durante horas cuando el problema está dos capas más abajo.

### 7.2 OCI en la práctica diaria

- Cuando ves `cosign sign ghcr.io/org/app@sha256:abc...`, cosign publica un objeto extra en el registry asociado a ese digest. Es posible por **distribution-spec**.
- Cuando `syft` genera un SBOM, lee las capas de la imagen por su spec (**image-spec**).
- Cuando Kubernetes "corre" tu imagen, Kubelet le pasa al **CRI** la referencia OCI; CRI delega en containerd; containerd en `runc`. Docker *no está en ningún lado*.
- Cuando GitHub Container Registry (GHCR) hospeda tu imagen, es un servidor que implementa **distribution-spec** encima de GitHub.

### 7.3 Mapa mental mínimo que debes poder dibujar

Deberías poder, con papel y lápiz y sin ayuda, dibujar:

1. **La pila**: `docker CLI → dockerd → containerd → containerd-shim → runc → kernel`.
2. **Las tres specs OCI** y qué resuelve cada una.
3. **Un namespace** (ej. PID): dos círculos, procesos distintos, PID 1 dentro = PID 4523 fuera.
4. **Un cgroup**: una caja con `memory.max=512M` conteniendo procesos.
5. **Overlayfs**: `lowerdir` (capas RO) + `upperdir` (RW del contenedor) → `merged`.

Si lo logras, el modelo mental está interiorizado. Lo demás es sintaxis.

---

## 8. Trade-offs

### 8.1 Contenedores vs VMs

| Dimensión | Contenedores | VMs |
|-----------|--------------|-----|
| Peso | MB | GB |
| Arranque | ms | segundos–minutos |
| Densidad por host | 100–1000s | 10s–100s |
| Aislamiento | **del kernel compartido** (más débil) | fuerte (hypervisor) |
| Kernel distinto al host | NO (Linux sobre Linux solo) | Sí |
| Casos límite | GPU, kernel modules, drivers | ideal cuando necesitas aislar al nivel de kernel |

Elección: contenedores por default; VMs cuando el aislamiento débil del kernel compartido es inaceptable (multi-tenant hostil, compliance que lo exige, workload que tira al kernel).

### 8.2 Docker vs alternativas

- **Podman**: compatible CLI, daemonless, rootless-first. Mejor postura de seguridad; menos ecosistema de tooling peripheral.
- **nerdctl**: CLI estilo Docker directa sobre containerd. Ideal si ya corres containerd en producción.
- **containerd + runc solo**: cuando lo único que importa es ejecutar, y la ergonomía la das con otra herramienta (Kubernetes, un script).
- **crun** en lugar de `runc`: implementación en C, menor memoria y arranque más rápido. OCI-compatible, drop-in.

Ninguna de estas elecciones cambia **el formato de imagen** (es OCI); solo cambia *quién ejecuta*.

### 8.3 Alta vs baja ergonomía

Docker es la opción "ergonómica". Ejecutar manualmente `runc` requiere escribir un `config.json` de ~200 líneas. En producción casi nadie habla con `runc` directamente — habla con un orquestador (Kubernetes), que habla con `containerd`, que habla con `runc`. El valor de entender la pila **no es operarla a mano** sino poder debuggear cualquier capa.

---

## 9. Errores frecuentes

### 9.1 "Un contenedor es como una VM pero más pequeña"

No. Una VM virtualiza **hardware** y corre **otro kernel**. Un contenedor **comparte el kernel del host** y es **un proceso**. Son categorías distintas, no una más chica de la otra.

Consecuencia práctica: contenedores Linux no corren sobre un kernel Windows nativo. Docker Desktop en macOS/Windows **tiene una VM Linux pequeña por debajo** (LinuxKit o WSL2) donde viven tus contenedores. "Nativo" es Linux-sobre-Linux.

### 9.2 "Imagen y contenedor son lo mismo"

No. **Imagen = datos inmutables en disco**. **Contenedor = proceso corriendo creado a partir de una imagen**. Puedes crear 100 contenedores desde la misma imagen; solo hay una imagen en disco.

### 9.3 "Docker crea los contenedores"

Técnicamente no. **Docker (dockerd) delega en containerd, que delega en runc**. runc es quien hace las syscalls. Importa porque si entiendes que el runtime es intercambiable, dejas de pensar en "Docker" como monolítico.

### 9.4 "Un contenedor privileged es solo un poco más libre"

Un contenedor con `--privileged` tiene todas las capabilities del kernel, acceso completo a `/dev`, y la mayoría de aislamientos relajados. Prácticamente es **root en el host con pasos extra**. Nunca lo uses salvo que entiendas y aceptes esto.

### 9.5 "El tag `:latest` es la última versión"

**Es un tag mutable**. Hoy apunta a `sha256:abc...`; mañana puede apuntar a `sha256:def...` sin que cambie el nombre. En producción se referencia por digest (`image@sha256:...`), que es inmutable. Lo veremos a fondo en `dkr-09`.

### 9.6 "Si cambio de Docker a Podman tengo que reconstruir todas mis imágenes"

No. **El formato OCI es el mismo**. Un `podman pull` de una imagen construida por Docker funciona. Un `nerdctl run` de una imagen pullada por `skopeo` funciona. Es la gracia de la estandarización.

### 9.7 "Montar `/var/run/docker.sock` dentro de un contenedor es un patrón común"

Es común; también es equivalente a **dar root al host al proceso del contenedor**. Con acceso al socket puedes crear un contenedor nuevo con `--privileged -v /:/host` y ya estás fuera. Lo veremos en `dkr-13`.

---

## 10. Buenas prácticas (todavía conceptuales)

- **Antes de instalar Docker, lee este módulo entero.** Instalar sin modelo mental es garantía de confusión.
- **Habla con precisión**: "imagen", "contenedor", "runtime" no son sinónimos.
- **Separa "qué es" de "cómo se usa"**: `docker run` es ergonomía; namespaces/cgroups/overlayfs es realidad.
- **Cuando leas un manifest, mira primero `mediaType`**: te dice si estás viendo un manifest, un index multi-arch, o un config.
- **Memoriza los nombres de las tres specs OCI**: image-spec, runtime-spec, distribution-spec. Vas a oírlos todos los días.
- **Reconoce las piezas intercambiables**: `runc` ↔ `crun`, `containerd` ↔ `CRI-O`, `docker` ↔ `podman`/`nerdctl`. La imagen OCI no cambia.
- **No le tengas miedo a `curl` contra un registry**: es solo HTTP con JSON.
- **Cuando dudes, pregúntate: "¿qué syscall hace esto en el kernel?"**. Si no sabes la respuesta, lo que estás leyendo todavía es magia para ti.

---

## 11. Ejercicios recomendados

1. **`activities/01-draw-namespaces-and-cgroups/`** — **independent, conceptual**. Produce un `MAP.md` que describe cada namespace, cada controlador clave de cgroup, y la pila `Docker → containerd → runc`. Es la actividad que valida comprensión real del modelo.
2. **`activities/02-oci-manifest-reading/`** — **guided-lab**. Inspeccionar un manifest OCI real (muestra provista en `starter/`, u obtenida con `docker manifest inspect` si Docker está disponible) y producir un `WRITEUP.md` identificando los campos clave.

Al terminar, releer el ejemplo de §5 (manifest con `curl`) y asegurarse de poder repetirlo sin consultar.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Explica en 2–3 frases **la diferencia fundamental entre una VM y un contenedor**, mencionando explícitamente el kernel.

**P2.** Marca todo lo que aplique. En un contenedor Docker **estándar** (sin flags especiales), están aislados por default:
   - [ ] Tabla de procesos (PID namespace)
   - [ ] Tabla de mounts (mount namespace)
   - [ ] Red (net namespace)
   - [ ] Hostname (uts namespace)
   - [ ] Mapeo UID/GID (user namespace)
   - [ ] IPC (ipc namespace)
   - [ ] Reloj del sistema

**P3.** Un cgroup es (marca una):
   - [ ] Un namespace del kernel para procesos.
   - [ ] Un grupo de procesos al que el kernel aplica cuotas y mide uso de recursos.
   - [ ] Un filesystem copy-on-write.
   - [ ] Una API de Docker para agrupar contenedores.

**P4.** Enumera las **tres specs** de OCI y explica, en una frase cada una, qué resuelve.

**P5.** Dibuja (texto plano o ASCII) la pila completa desde `docker run` hasta el proceso del contenedor, nombrando cada componente intermedio.

**P6.** Un compañero dice: "Para pasarme de Docker a Podman tengo que reconstruir todas mis imágenes." ¿Cierto o falso, y por qué?

**P7.** Explica, con precisión técnica, por qué un contenedor Linux **no puede** correr sobre un kernel Windows nativo, y cómo Docker Desktop para Windows resuelve esto.

**P8.** Describe qué es **overlayfs** en el contexto de un contenedor en ejecución: qué son `lowerdir`, `upperdir`, `merged`, y qué pasa con `upperdir` cuando el contenedor se elimina.

---

## Referencias

Documentación oficial (verificar fecha de consulta en Fase 4):

- **OCI image-spec** — <https://github.com/opencontainers/image-spec>
- **OCI runtime-spec** — <https://github.com/opencontainers/runtime-spec>
- **OCI distribution-spec** — <https://github.com/opencontainers/distribution-spec>
- **runc** — <https://github.com/opencontainers/runc>
- **containerd** — <https://containerd.io/>
- **Docker overview** — <https://docs.docker.com/get-started/overview/>
- **Linux namespaces(7)** — `man 7 namespaces` o <https://man7.org/linux/man-pages/man7/namespaces.7.html>
- **Linux cgroups v2** — <https://docs.kernel.org/admin-guide/cgroup-v2.html>
- **overlayfs** — <https://docs.kernel.org/filesystems/overlayfs.html>

Lectura complementaria:

- Jérôme Petazzoni, *"Anatomy of a container"* (charla clásica de la era pre-CNCF; sigue siendo correcta en lo esencial).
- Liz Rice, *Container Security* (O'Reilly) — cap. 1–4 cubren a profundidad este modelo mental.
- CNCF Landscape, sección Container Runtime — para ver quién implementa qué parte de OCI.
