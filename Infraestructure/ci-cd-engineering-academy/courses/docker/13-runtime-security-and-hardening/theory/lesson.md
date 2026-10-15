# Lección: Runtime security y hardening de contenedores

> **ID:** `dkr-13-runtime-security-and-hardening` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `dkr-10` (namespaces, cgroups, capabilities), `dkr-11` (base images), nociones de Linux (procesos, uid/gid, permisos).

---

## 1. Introducción intuitiva

Un contenedor **no es una sandbox**. Es un proceso Linux normal con una serie de restricciones añadidas por el kernel: namespaces para que no vea procesos ajenos, cgroups para limitar recursos, capabilities para recortar lo que puede hacer el root interno, seccomp para filtrar syscalls peligrosos. Si quitas esas restricciones una por una, no te queda un contenedor "más libre": te queda un proceso con acceso total al host.

Esto importa porque los defaults de Docker son razonables, pero **no son máximos**. El default:

- Deja al proceso correr como `root` (UID 0) dentro del contenedor si tu `Dockerfile` no dice lo contrario.
- Deja casi 40 capabilities habilitadas (de ~41 posibles).
- Deja el root filesystem **escribible**.
- Deja la bandera "no-new-privileges" en `false`.
- Deja sin límite de memoria, de CPUs y de PIDs.
- Habilita el perfil seccomp por default (bueno), pero no AppArmor/SELinux salvo que lo configures.

Cada una de esas elecciones es un trade-off entre comodidad para empezar y seguridad en producción. El modo producción exige **invertir el default**: todo prohibido, se añade sólo lo mínimo necesario. Eso es *principio de mínimo privilegio*; combinado con capas superpuestas (image hardening + runtime hardening + MAC + límites + auditoría) se llama *defensa en profundidad*.

El coste de hacerlo mal es alto. Un contenedor rooteado con `CAP_SYS_ADMIN` o con `/var/run/docker.sock` montado adentro es, para fines prácticos, **root en el host**. Si tu CI corre tests dentro de un contenedor así y alguien compromete una dependencia, el atacante no se queda en el contenedor: sale al host.

En esta lección construyes la práctica de hardening que un contenedor productivo debe cumplir **antes** de llegar al orquestador. Lo que vemos aquí es independiente de Kubernetes: aplica igual a `docker run` directo, a Compose, a ECS, a Nomad. Kubernetes añade capas propias (`PodSecurityStandards`, admission controllers) que verás en D8/D9, pero no sustituyen esta base.

---

## 2. Fundamentos: cuatro capas de hardening

Un contenedor en producción se endurece en cuatro capas superpuestas. Fallar en una se mitiga con las otras; eso es defensa en profundidad.

### 2.1 Capa 1 — Imagen (build-time)

Lo que fijas en el `Dockerfile`:

- `USER nonroot:nonroot` (o `USER 10001:10001`).
- Base image mínima (distroless, chainguard, scratch).
- Sin paquetes de desarrollo, sin shells innecesarios, sin curl/wget.
- Binarios de la app con permisos razonables, nada de `chmod 777`.
- Sin secretos en capas (ver `dkr-07`).

### 2.2 Capa 2 — Runtime (invocación)

Lo que fijas en el `docker run` (o en el `compose.yaml`, o en el PodSpec):

- `--read-only` root FS, `--tmpfs` para rutas escribibles acotadas.
- `--cap-drop=ALL`, `--cap-add=<mínimo>`.
- `--security-opt no-new-privileges:true`.
- `--security-opt seccomp=<profile.json>` si personalizas.
- Límites: `--memory`, `--memory-swap`, `--cpus`, `--pids-limit`, `--ulimit nofile`.
- Red: evitar `--network host`, no mapear `-p 0.0.0.0:...` cuando no sea necesario.
- `--restart` sensato (no `always` sin backoff en recovery scenarios).

### 2.3 Capa 3 — Mandatory Access Control (host)

- AppArmor (Debian/Ubuntu) o SELinux (RHEL/Fedora) activo en el host.
- Perfil `docker-default` (AppArmor) o `container_t` (SELinux) aplicado automáticamente.
- Perfiles custom para apps críticas.

### 2.4 Capa 4 — Supervisión y auditoría

- Escaneo de imagen con Trivy / grype en el pipeline.
- CIS Docker Benchmark auditado periódicamente (`docker-bench-security`).
- Logs del daemon y de los contenedores centralizados.
- Runtime detection (Falco, Tracee) para anomalías en producción.

```
+----------------------------------------------------------+
|   Capa 4: Supervisión (Trivy, Falco, CIS Benchmark)      |
+----------------------------------------------------------+
|   Capa 3: MAC del host (AppArmor / SELinux)              |
+----------------------------------------------------------+
|   Capa 2: Runtime hardening (--cap-drop, --read-only...) |
+----------------------------------------------------------+
|   Capa 1: Imagen hardened (USER no-root, distroless...)  |
+----------------------------------------------------------+
|                 Kernel Linux (namespaces, cgroups)       |
+----------------------------------------------------------+
```

El resto de la lección recorre cada palanca concreta.

---

## 3. `USER` no-root: la primera y más barata palanca

Por default, si tu `Dockerfile` no declara `USER`, el proceso del contenedor corre como **UID 0 (root)**. Esto NO es "root virtual inofensivo". Es root real **dentro de los namespaces del contenedor**. Combinado con un bug en el kernel, un volumen mal montado, una capability extra o un escape, es root en el host.

### 3.1 Patrón canónico

```dockerfile
# Dockerfile — stage runtime
FROM python:3.12-slim AS runtime

# Crear usuario sin shell interactivo, sin home escribible,
# con UID/GID altos y estables (evita colisión con UIDs del host).
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin app

WORKDIR /app
COPY --chown=app:app app/ /app/

USER 10001:10001
EXPOSE 8000
ENTRYPOINT ["python", "-m", "app"]
```

Puntos clave:

- `--system` crea usuario con UID bajo o alto según la distro; usa `--uid 10001` para fijarlo. UID alto evita colisión con usuarios del host en caso de bind mounts.
- `USER 10001:10001` (numérico, no `app:app`): Kubernetes `runAsNonRoot: true` sólo acepta imágenes cuyo `USER` sea numérico y > 0.
- `--chown=app:app` en el `COPY` evita un `chown -R` extra que añade otra capa.

### 3.2 Trampas comunes

- **Puertos privilegiados**: un proceso no-root no puede abrir puertos < 1024. Si tu app servía en `:80`, cámbiala a `:8080` o mapea externamente `-p 80:8080`.
- **Archivos escribibles**: la app no puede escribir a rutas owned por root. Marca los directorios necesarios con `--chown=app:app` en build-time; mejor aún, no escribas al FS (ver §4).
- **`docker exec --user root`** sigue siendo posible como root del daemon. Esto no es un escape — es el operador del daemon haciendo lo que quiere con su propio recurso. Pero no uses `--user root` como workaround para que la app arranque.

### 3.3 Verificación

```bash
docker inspect <container> --format '{{.Config.User}}'   # debe ser "10001:10001" o similar
docker exec <container> id                              # uid=10001 gid=10001
docker top <container>                                  # columna USER del proceso
```

---

## 4. `--read-only` filesystem: el root FS es inmutable

El sistema de archivos de un contenedor normal es **escribible** por default (la capa superior del overlay). Un atacante que logre ejecución puede modificar binarios en `/usr/bin/`, dejar persistencia en `/etc/`, descargar un payload a `/tmp/` y ejecutarlo.

`--read-only` monta el root overlay como `ro`. Toda escritura al FS raíz falla con `EROFS`. Esto:

- Impide persistencia del atacante.
- Fuerza a declarar explícitamente qué rutas la app necesita escribir.
- Hace triviales los diffs de FS: no hay diff.

### 4.1 Añadir `--tmpfs` para lo que sí hay que escribir

Muchas apps escriben a `/tmp/`, a un directorio de cache, a un socket Unix. Con `--read-only` esas escrituras fallan. Solución: montar `tmpfs` (memoria) en esas rutas, no reactivar la escritura global.

```bash
docker run --rm \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --tmpfs /run:rw,noexec,nosuid,size=16m \
  myapp:prod
```

- `noexec` evita ejecutar binarios desde el tmpfs (defensa extra).
- `nosuid` ignora el bit setuid en archivos del tmpfs.
- `size=` limita cuánta memoria puede ocupar.

### 4.2 Datos persistentes

Si la app realmente necesita persistir, usa **un volumen explícito**, no un write al FS raíz:

```bash
docker run --rm --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  -v mydata:/var/lib/myapp \
  myapp:prod
```

El volumen es escribible (es lo que `-v` hace), pero sólo en esa ruta. El resto del FS sigue inmutable.

### 4.3 Diagnóstico cuando falla

Si tu app crashea con `EROFS` o "Read-only file system":

1. `docker logs <c>` muestra la ruta exacta.
2. Decide: ¿necesita persistir? → volumen. ¿Es cache efímero? → tmpfs. ¿Es un side-effect inútil? → quitar del código.
3. Nunca "arregles" quitando `--read-only`. Es casi siempre señal de que la app está escribiendo donde no debería.

---

## 5. Capabilities: el modelo de permisos finos de root

Linux divide los privilegios tradicionales de root en ~41 **capabilities** independientes. Cada una habilita un conjunto de operaciones. Docker, por default, **concede** un subconjunto conservador a cada contenedor (incluso los que corren como UID 0 interno).

### 5.1 Capabilities por default

Las que Docker concede por default (parcial):

```
CAP_CHOWN           CAP_DAC_OVERRIDE    CAP_FOWNER
CAP_FSETID          CAP_KILL            CAP_SETGID
CAP_SETUID          CAP_SETPCAP         CAP_NET_BIND_SERVICE
CAP_NET_RAW         CAP_SYS_CHROOT      CAP_MKNOD
CAP_AUDIT_WRITE     CAP_SETFCAP
```

Las que **no** concede por default (y por buenas razones):

```
CAP_SYS_ADMIN       (equivalente a "root" por amplitud)
CAP_SYS_MODULE      (cargar módulos del kernel)
CAP_SYS_PTRACE      (hacer ptrace a procesos del host si escapas)
CAP_NET_ADMIN       (modificar interfaces de red del host)
CAP_SYS_BOOT        (reboot)
CAP_SYS_TIME        (cambiar el reloj del host)
...
```

### 5.2 El patrón productivo: drop ALL, add minimal

Casi ninguna app de usuario (web, servicio HTTP, worker) necesita ninguna de las capabilities por default. El patrón correcto es **arrancar sin ninguna** y añadir sólo lo imprescindible:

```bash
docker run --rm \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \   # sólo si bindeas puerto < 1024
  myapp:prod
```

Si tu app corre como no-root en un puerto >= 1024, no necesitas ni siquiera `NET_BIND_SERVICE`. El drop puro es la configuración objetivo.

### 5.3 Cómo saber qué capability hace falta

- Lee la doc de la app (bases de datos, servidores DNS a veces requieren `CAP_NET_BIND_SERVICE` o `CAP_IPC_LOCK`).
- Ejecuta con `--cap-drop=ALL` y mira el error. "Permission denied" en una operación de red → candidato `CAP_NET_*`. En una operación de ownership → `CAP_CHOWN`. En setcap/getcap de archivos → `CAP_SETFCAP`.
- Usa `strace` o `getpcaps` dentro del contenedor para auditar.

### 5.4 `--privileged` es casi siempre un bug

`--privileged`:

- Concede **todas** las capabilities.
- Desactiva el filtro seccomp.
- Permite ver todos los devices del host (`/dev/*`).
- Monta `cgroupfs` escribible.

Un contenedor `--privileged` **es root en el host** salvo por el PID y mount namespace, que son trivialmente escapables con la combinación correcta. Las únicas razones legítimas: *Docker-in-Docker* en builders aislados y descartables, drivers de GPU/storage. Nunca para aplicaciones.

---

## 6. `no-new-privileges`: cerrar la vía setuid

Linux soporta binarios **setuid** y **setgid**: cuando los ejecutas, el proceso resultante corre con el UID/GID del *dueño del archivo*, no del invocador. `/usr/bin/sudo`, `/usr/bin/passwd`, `ping` (en algunas distros) son clásicos.

Dentro de un contenedor, si tu imagen tiene un binario setuid-root (muchas base images lo tienen) y un atacante logra ejecución como no-root, puede **ganar UID 0 interno** ejecutando ese binario. Combinado con la capability correcta, UID 0 interno es un escape potencial.

### 6.1 La bandera

```bash
docker run --rm --security-opt no-new-privileges:true myapp:prod
```

Esto activa el flag `PR_SET_NO_NEW_PRIVS` en el proceso. Una vez puesto, `exec` **nunca** puede ganar privilegios por setuid/setgid/capabilities del binario. El bit setuid se ignora silenciosamente.

### 6.2 Combinado con `USER` no-root

El patrón productivo completo:

```bash
docker run --rm \
  --user 10001:10001 \
  --read-only \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  myapp:prod
```

Con los cuatro juntos: un atacante que gana ejecución es un UID no-root sin capabilities, con un FS inmutable, y sin la ruta setuid para escalar.

### 6.3 Verificación

```bash
docker inspect <c> --format '{{.HostConfig.SecurityOpt}}'
# Debe incluir "no-new-privileges:true"
```

O desde dentro del contenedor:

```bash
docker exec <c> grep NoNewPrivs /proc/self/status
# NoNewPrivs: 1
```

---

## 7. Seccomp: filtro de syscalls

**seccomp-bpf** permite filtrar qué syscalls puede ejecutar un proceso. Docker aplica un **perfil por default** que bloquea ~44 syscalls peligrosos (keyctl, add_key, finit_module, kcmp, ptrace según política, etc.) y permite el resto. Este perfil cubre la mayoría de los escapes conocidos vía syscalls raros.

### 7.1 Qué pasa si lo desactivas

`--security-opt seccomp=unconfined` lo apaga. **Nunca** hagas esto en producción salvo que estés depurando y sepas qué buscas. Hay ejemplos públicos de escapes que requieren syscalls bloqueados por el perfil default.

### 7.2 Verificar que está activo

```bash
docker inspect <c> --format '{{.HostConfig.SecurityOpt}}'
# si está vacío o no incluye seccomp=unconfined → default aplicado
```

Dentro:

```bash
docker exec <c> grep Seccomp /proc/self/status
# Seccomp: 2  (0=disabled, 1=strict, 2=filter)
```

### 7.3 Perfil custom

Para apps muy acotadas puedes partir del perfil default (`default.json` del repo `moby/moby`), eliminar syscalls que la app no usa, y aplicarlo:

```bash
docker run --rm --security-opt seccomp=/path/to/myapp-seccomp.json myapp:prod
```

Herramientas como `oci-seccomp-bpf-hook` (Podman) o `bane` ayudan a generar perfiles por observación. Es trabajo artesanal: raramente justifica el esfuerzo salvo en apps críticas.

---

## 8. AppArmor y SELinux: MAC del host

Las capabilities y seccomp viven **dentro** del contenedor (son filtros del proceso). AppArmor (Debian/Ubuntu) y SELinux (RHEL/Fedora/CentOS) son **Mandatory Access Control** del kernel aplicados a procesos del host: dicen qué archivos puede abrir, qué sockets, qué capabilities finales puede usar, independientemente del UID.

### 8.1 AppArmor

Docker instala y carga por default el perfil `docker-default` cuando AppArmor está activo en el host. Está en modo *enforce* y restringe operaciones de montaje, acceso a `/sys` y `/proc` sensibles, etc.

```bash
aa-status                        # perfiles cargados y modo
docker info | grep -i apparmor   # debe decir "Default AppArmor profile: docker-default"
```

Para una app crítica, puedes escribir un perfil custom (`/etc/apparmor.d/myapp-profile`) y aplicarlo:

```bash
docker run --rm --security-opt apparmor=myapp-profile myapp:prod
```

### 8.2 SELinux

En RHEL/Fedora, los contenedores corren etiquetados como `container_t` y sólo pueden acceder a archivos etiquetados `container_file_t`. Esto rompe muchos bind mounts hasta que etiquetas:

```bash
docker run --rm -v /host/data:/data:Z myapp:prod   # :Z relabel privado
docker run --rm -v /host/data:/data:z myapp:prod   # :z relabel compartido
```

### 8.3 Qué cubren que capabilities no cubre

- Operaciones por *ruta* (p.ej., prohibir escritura a `/etc` incluso con `CAP_DAC_OVERRIDE`).
- Mounts específicos.
- Transiciones de dominio: aunque el proceso escale UID, sigue atado al dominio AppArmor/SELinux.

Son defensa en profundidad real. Verifica que estén activos en el host; es trabajo del operador, no de la imagen.

---

## 9. Rootless: dockerd y Podman sin privilegios en el host

Hasta aquí hemos endurecido el **contenedor**. Pero el **daemon** (`dockerd`) sigue siendo root en el host. Un bug en `dockerd` o en una API que expone es un escape automático.

### 9.1 Rootless Docker

Desde Docker 20.10+, `dockerd` puede correr como usuario normal usando user namespaces, slirp4netns (networking) y fuse-overlayfs (storage driver sin privilegios).

Instalación (como usuario normal):

```bash
dockerd-rootless-setuptool.sh install
systemctl --user start docker
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
```

Lo que resuelve:

- El daemon ya no es root. Un bug en `dockerd` es compromiso del usuario, no del host.
- UIDs internos del contenedor se mapean a un rango no privilegiado del host (`/etc/subuid`, `/etc/subgid`).

Lo que **no** resuelve:

- Bind a puertos < 1024 sin trucos extra (`sysctl net.ipv4.ip_unprivileged_port_start=0` o `setcap cap_net_bind_service=+ep` en el binario de slirp4netns).
- Overlay en kernels viejos (requiere fuse-overlayfs — más lento).
- Algunos drivers de storage/network.
- cgroups v1 (requiere v2 unificado para `--memory`, `--cpus`).

### 9.2 Podman rootless

Podman fue diseñado rootless-first:

- **Daemonless**: no hay servicio con estado; cada `podman run` es un proceso del usuario.
- CLI casi idéntica a Docker (`alias docker=podman` funciona para el 90% de los casos).
- Compatible con systemd user units y con Kubernetes YAML (`podman play kube`).

Cuándo preferir Podman:

- Entornos multiusuario donde no quieres un daemon global root.
- RHEL/Fedora (soporte nativo).
- CI self-hosted donde quieres builds aislados sin daemon compartido.

### 9.3 Cuándo rootless **no** es suficiente

- Workloads que necesitan configurar red del host (VPNs, overlays propios).
- Montar devices del host.
- Compartir sockets de kernel.

Para estos, usa Docker rootful con hardening estricto (todo lo visto en §§3-8) y vigila el daemon. O mueve el workload a Kubernetes y usa un PodSecurityStandard que lo contemple.

---

## 10. Límites de recursos: `--memory`, `--cpus`, `--pids-limit`

Un contenedor sin límites puede, por un bug o malicia, consumir toda la memoria, CPU o PIDs del host — y DoS-ear a los vecinos. Los límites son parte de la seguridad: previenen *denial of service*.

### 10.1 Memoria

```bash
docker run --rm --memory=512m --memory-swap=512m myapp:prod
```

- `--memory=512m` → el kernel OOM-killea el proceso si pasa 512 MB.
- `--memory-swap=512m` igual al `--memory` → sin swap. Si no lo igualas, docker permite usar swap del host (indeseable).
- Dentro del contenedor, `cat /sys/fs/cgroup/memory.max` muestra el límite.

### 10.2 CPU

```bash
docker run --rm --cpus=1.5 myapp:prod
```

- `--cpus=1.5` → se traduce a `cpu.cfs_quota_us` y `cpu.cfs_period_us` (cgroups v1) o `cpu.max` (cgroups v2). El contenedor obtiene como máximo 1.5 CPUs de tiempo.
- Para pinning específico: `--cpuset-cpus="0,1"`.

### 10.3 PIDs

Esta es la menos conocida y más crítica contra **fork bombs**:

```bash
docker run --rm --pids-limit=100 myapp:prod
```

Sin `--pids-limit`, un `:(){ :|:& };:` (o un bug) agota los PIDs del host y lo deja inoperable. 100 es cómodo para una app Python con un worker pool pequeño; ajusta según perfil.

### 10.4 Ulimits

```bash
docker run --rm --ulimit nofile=1024:1024 --ulimit nproc=64:64 myapp:prod
```

Útil para apps que leakean file descriptors o abren muchos procesos.

### 10.5 Verificación

```bash
docker inspect <c> --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.PidsLimit}}'
```

- `Memory` en bytes (`536870912` = 512 MiB).
- `NanoCpus` en nano-CPUs (`1500000000` = 1.5 CPU).
- `PidsLimit` entero.

---

## 11. `docker.sock` dentro del contenedor y por qué NO

El socket Unix `/var/run/docker.sock` es la API del daemon. Cualquier proceso con acceso al socket puede pedirle al daemon lo que quiera: ejecutar nuevos contenedores, montar `/` del host en uno nuevo, etc.

### 11.1 El antipatrón

```bash
# NO HAGAS ESTO
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock myimage
```

Dentro del contenedor:

```bash
docker run --rm -v /:/host --privileged alpine chroot /host sh
# Ahora tienes shell como root en el HOST.
```

El mecanismo:

1. El socket es un API endpoint que acepta cualquier petición autenticada.
2. El contenedor interno pide "arranca otro contenedor con `/` del host montado y privileged".
3. El daemon obedece (es su trabajo).
4. Ese segundo contenedor es root en el host.

### 11.2 Casos donde la gente lo monta (y qué hacer en su lugar)

- **CI runners que necesitan construir imágenes**: usa **BuildKit** standalone, `kaniko`, `buildah`, o un *sidecar* Docker-in-Docker rootless aislado. Nunca el socket del daemon host.
- **Jenkins / GitLab runners**: ejecutores dedicados en VMs efímeras, no containers con socket.
- **Monitoreo / herramientas que necesitan listar containers (cAdvisor, Portainer)**: montar socket **read-only** (`:ro`) **y** usar un socket proxy (p. ej., `tecnativa/docker-socket-proxy`) que exponga sólo los endpoints necesarios.
- **Docker Compose dentro de un stack**: generalmente no debería; refactoriza.

### 11.3 Equivalente moderno: Kubernetes DinD

En K8s, montar `/var/run/docker.sock` del nodo en un pod es también root al nodo. Lo correcto es `kaniko` o BuildKit con rootless, o un operador que gestione builders aislados.

### 11.4 Cómo detectarlo

```bash
docker inspect <c> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
# Si aparece /var/run/docker.sock → red flag inmediato.
```

El Ejemplo `03-why-not-mount-docker-sock/` reproduce esto de forma segura en `/tmp/` con un contenedor etiquetado que luego eliminas.

---

## 12. Auditoría y referencia: Trivy, grype, CIS Benchmark, y lectura de `docker run`

### 12.1 De `docker scan` deprecado a Trivy / grype

`docker scan` (basado en Snyk) fue el escáner integrado hasta ~2023 y está **deprecado**. Los sustitutos son:

- **Trivy** (Aqua Security) — scanner multi-propósito: vulnerabilidades de paquetes del sistema y de lenguajes, misconfig de Dockerfiles/Kubernetes/Terraform, secretos.
- **grype** (Anchore) — foco en CVEs; muy rápido; buena integración con SBOMs de `syft`.

Comandos canónicos (Trivy):

```bash
trivy image myimage:prod                                # vulns por default
trivy image --severity HIGH,CRITICAL myimage:prod       # filtro de severidad
trivy image --exit-code 1 --severity CRITICAL myimage:prod   # gate de CI
trivy config ./                                         # misconfig del Dockerfile
```

### 12.2 CIS Docker Benchmark

Checklist operativo mantenido por el Center for Internet Security. Cubre host, daemon, imágenes, runtime, Docker Swarm. Herramienta de referencia para auditar: **`docker-bench-security`** (bash script publicado por Docker Inc.):

```bash
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro -v /lib/systemd:/lib/systemd:ro \
  -v /var/lib:/var/lib:ro -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label docker_bench_security docker/docker-bench-security
```

Produce un reporte PASS/WARN/INFO/FAIL por punto. Útil como baseline inicial y como regresión.

### 12.3 Cómo auditar un `docker run` ajeno

Dado un comando como:

```bash
docker run -d --name proc --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /:/host \
  --network host \
  -p 0.0.0.0:8080:8080 \
  acme/scraper:latest
```

Produce una auditoría estructurada:

| Flag | Riesgo | Severidad | Mitigación |
|------|--------|-----------|------------|
| `--privileged` | Concede todas las capabilities, desactiva seccomp, expone devices. Equivalente a root en host. | CRÍTICA | Eliminar. Usar `--cap-drop=ALL --cap-add=<lo mínimo>`. |
| `-v /var/run/docker.sock:/var/run/docker.sock` | Root al host vía API del daemon. | CRÍTICA | Eliminar. Usar socket proxy read-only si realmente se requiere introspección. |
| `-v /:/host` | FS raíz del host accesible. Modificable (no :ro). | CRÍTICA | Eliminar. Si necesita datos del host, bind mount específico `:ro`. |
| `--network host` | Elimina net namespace. Acceso directo a interfaces del host, puede escuchar/sniffear. | ALTA | Usar bridge o user-defined network con `-p` acotado. |
| `-p 0.0.0.0:8080:8080` | Puerto expuesto a todas las interfaces del host. | MEDIA (depende del entorno) | `-p 127.0.0.1:8080:8080` si sólo necesita acceso local; firewall explícito si pública. |
| `acme/scraper:latest` | Tag mutable, imagen sin pin, sin escaneo. | MEDIA | Pin por digest (`@sha256:...`), escanear con Trivy antes de desplegar. |
| (ausencia) `--user` | Corre como root interno. | ALTA | `USER` no-root en Dockerfile + `--user 10001:10001` en runtime como refuerzo. |
| (ausencia) `--read-only` | FS escribible, posible persistencia. | MEDIA | Añadir `--read-only --tmpfs /tmp:rw,noexec,nosuid`. |
| (ausencia) `--security-opt no-new-privileges` | Vía setuid abierta. | MEDIA | Añadir. |
| (ausencia) `--memory`, `--pids-limit` | DoS por consumo de recursos. | MEDIA | Fijar `--memory`, `--pids-limit`. |

Ese es el formato que la Actividad 02 te pide producir — con tus propias palabras — para un conjunto de escenarios distintos.

### 12.4 Receta final (copiable)

Para la app FastAPI de la Actividad 01, el `docker run` productivo objetivo es:

```bash
docker run -d \
  --name fastapi-prod \
  --user 10001:10001 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --memory=256m \
  --memory-swap=256m \
  --pids-limit=100 \
  --cpus=0.5 \
  --restart=on-failure:3 \
  -p 127.0.0.1:8000:8000 \
  fastapi-hardened:v1
```

Diez flags, cada una justificada en una sección de esta lección. Esa es la línea base. En Kubernetes se traduce 1:1 a `securityContext` + `resources.limits` + `restartPolicy`; en Compose a los campos equivalentes de `services.<svc>.deploy.resources` y `services.<svc>.security_opt`.

---

## Preguntas de evaluación

Responde sin consultar el texto. Si fallas más de dos, re-lee la sección correspondiente.

1. ¿Por qué `USER` no-root en el Dockerfile es más robusto que `--user` sólo en runtime?
2. Un contenedor con `--read-only` crashea al escribir en `/var/run/foo.pid`. Da dos soluciones correctas y una incorrecta común.
3. ¿Qué diferencia operacional hay entre quitar `CAP_SYS_ADMIN` y activar `no-new-privileges`?
4. ¿Qué cubre AppArmor que capabilities no cubre? Da un ejemplo concreto.
5. En rootless Docker, ¿por qué un `-p 80:8080` falla por default y qué dos opciones tienes para resolverlo?
6. ¿Por qué `--pids-limit` es una medida de seguridad y no sólo de rendimiento?
7. Explica el mecanismo exacto (en tres pasos) por el que `-v /var/run/docker.sock:/var/run/docker.sock` concede root al host.
8. ¿Qué hace `trivy image --exit-code 1 --severity CRITICAL` en un pipeline de CI y qué política implica?
9. Diferencia entre el perfil seccomp default de Docker y `--security-opt seccomp=unconfined`. ¿Cuándo lo segundo es defendible?
10. Audita este `docker run` en una línea: `docker run --rm --privileged -v /:/host alpine sh`. ¿Qué puede hacer el proceso?
