# Docker — Guía Completa: Contenedores, Redes y Orquestación

> **Idea central:** Docker no es una máquina virtual. Es un sistema que empaqueta
> una aplicación con todas sus dependencias en un **contenedor** — un proceso aislado
> que comparte el kernel del host. Esa idea simple cambia radicalmente cómo se
> construye, distribuye y ejecuta software: el mismo artefacto que funciona en tu
> laptop funciona en producción, sin sorpresas. Dominar Docker es dominar la unidad
> atómica del despliegue moderno.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [¿Qué es Docker?](#1-qué-es-docker)
2. [Contenedores vs Máquinas Virtuales](#2-contenedores-vs-máquinas-virtuales)
3. [Arquitectura de Docker](#3-arquitectura-de-docker)
4. [Instalación y Verificación](#4-instalación-y-verificación)

**Parte II — Ciclo de Vida de Contenedores**
5. [docker container run — El Comando Fundamental](#5-docker-container-run--el-comando-fundamental)
6. [Gestión del Ciclo de Vida](#6-gestión-del-ciclo-de-vida)
7. [Inspección y Monitoreo](#7-inspección-y-monitoreo)
8. [Shell Interactivo dentro de Contenedores](#8-shell-interactivo-dentro-de-contenedores)

**Parte III — Redes en Docker**
9. [Modelo de Red de Docker](#9-modelo-de-red-de-docker)
10. [Network Drivers](#10-network-drivers)
11. [Gestión de Redes (CLI)](#11-gestión-de-redes-cli)
12. [Port Mapping y Firewalls](#12-port-mapping-y-firewalls)

**Parte IV — DNS y Descubrimiento de Servicios**
13. [DNS Interno de Docker](#13-dns-interno-de-docker)
14. [Round-Robin DNS y Load Balancing](#14-round-robin-dns-y-load-balancing)

**Parte V — Docker Hub y Registries**
15. [Docker Hub y Registros](#15-docker-hub-y-registros)
16. [Autenticación y Seguridad](#16-autenticación-y-seguridad)

**Parte VI — Buenas Prácticas y Producción**
17. [Anti-Patrones y Errores Comunes](#17-anti-patrones-y-errores-comunes)
18. [Buenas Prácticas para Producción](#18-buenas-prácticas-para-producción)

**Parte VII — Ejercicios Prácticos**
19. [Ejercicio 1 — Gestión Básica de Contenedores](#19-ejercicio-1--gestión-básica-de-contenedores)
20. [Ejercicio 2 — Redes y DNS](#20-ejercicio-2--redes-y-dns)
21. [Ejercicio 3 — Round-Robin DNS](#21-ejercicio-3--round-robin-dns)
22. [Ejercicio 4 — CLI App Testing](#22-ejercicio-4--cli-app-testing)

---

# PARTE I — FUNDAMENTOS

---

# 1. ¿Qué es Docker?

## 1.1 Definición

```text
Docker es una plataforma de contenedores que permite empaquetar, distribuir
y ejecutar aplicaciones en entornos aislados y reproducibles.

Tres conceptos nucleares:

  Image      → Plantilla de solo lectura. Contiene el código de la app,
                sus dependencias, librerías y la configuración necesaria
                para ejecutarla. Es inmutable — una vez construida, no cambia.

  Container  → Instancia en ejecución de una imagen. Es un proceso aislado
                con su propio filesystem (capa de escritura), red y espacio
                de procesos. Puede haber múltiples contenedores de la misma
                imagen, cada uno con estado independiente.

  Registry   → Repositorio centralizado de imágenes (Docker Hub, ECR, GCR,
                ACR, registros privados). Es el "npm / pip de imágenes Docker".

Flujo básico:
  Build (imagen) → Push (registry) → Pull (servidor) → Run (contenedor)
```

## 1.2 ¿Por qué Docker?

```text
┌─────────────────────────────────┬──────────────────────────────────────┐
│  Sin Docker                     │  Con Docker                          │
├─────────────────────────────────┼──────────────────────────────────────┤
│  "Funciona en mi máquina"       │  Mismo artefacto en dev y prod       │
│  Instalar dependencias manual   │  Todo empaquetado en la imagen       │
│  Conflictos de versiones        │  Cada app tiene su propio entorno    │
│  Servidores configurados a mano │  Infraestructura declarativa         │
│  Despliegue lento y frágil      │  Despliegue en segundos, repetible   │
│  Difícil escalar                │  Escalar = levantar más contenedores │
└─────────────────────────────────┴──────────────────────────────────────┘
```

---

# 2. Contenedores vs Máquinas Virtuales

## 2.1 Diferencias fundamentales

```text
┌────────────────────────────────────────────────────────────────────┐
│            MÁQUINA VIRTUAL                 CONTENEDOR              │
│  ┌──────────────────────────┐  ┌──────────────────────────┐       │
│  │  App A     │   App B     │  │  App A  │  App B  │ App C│       │
│  ├────────────┼─────────────┤  ├─────────┼─────────┼──────┤       │
│  │ Bins/Libs  │  Bins/Libs  │  │Bins/Libs│Bins/Libs│B/Libs│       │
│  ├────────────┼─────────────┤  ├─────────┴─────────┴──────┤       │
│  │  Guest OS  │  Guest OS   │  │     Docker Engine         │       │
│  ├────────────┴─────────────┤  ├───────────────────────────┤       │
│  │      Hypervisor          │  │       Host OS (kernel)    │       │
│  ├──────────────────────────┤  ├───────────────────────────┤       │
│  │      Infrastructure      │  │       Infrastructure      │       │
│  └──────────────────────────┘  └───────────────────────────┘       │
└────────────────────────────────────────────────────────────────────┘
```

## 2.2 Comparación detallada

```text
┌─────────────────────┬──────────────────────┬──────────────────────┐
│  Característica      │  Máquina Virtual     │  Contenedor          │
├─────────────────────┼──────────────────────┼──────────────────────┤
│  Aislamiento        │  Fuerte (kernel      │  A nivel de proceso  │
│                     │  propio por VM)      │  (comparte kernel)   │
│  Tamaño             │  GBs (OS completo)   │  MBs (solo la app)   │
│  Tiempo de arranque │  Minutos             │  Milisegundos        │
│  Overhead           │  Alto (hypervisor +  │  Mínimo (solo el     │
│                     │  kernel completo)    │  proceso)            │
│  Densidad           │  ~10-20 VMs / host   │  ~100-1000 / host    │
│  Portabilidad       │  Formato de VM       │  OCI image estándar  │
│  Casos de uso       │  Multi-tenant, OS    │  Microservicios,     │
│                     │  distintos, legacy   │  CI/CD, cloud-native │
└─────────────────────┴──────────────────────┴──────────────────────┘

Contenedores NO son VMs:
  → No tienen su propio kernel — comparten el del host
  → No virtualizan hardware — son procesos aislados
  → No necesitan un OS completo — solo los binarios de la app
  → Son efímeros por diseño — se crean y destruyen rápidamente
```

## 2.3 ¿Cuándo elegir uno u otro?

```text
Usar VM cuando:
  → Necesitas ejecutar un OS diferente (Windows en Linux, etc.)
  → Requieres aislamiento fuerte (multi-tenant con desconfianza)
  → La aplicación necesita un kernel específico o módulos del kernel
  → Compliance requiere aislamiento a nivel de hardware

Usar contenedores cuando:
  → Microservicios y aplicaciones cloud-native
  → CI/CD pipelines (builds reproducibles)
  → Necesitas escalar rápidamente
  → El equipo necesita entornos de desarrollo consistentes
  → Despliegue inmutable (mismo artefacto dev → staging → prod)

En producción, es común combinar ambos:
  VMs como hosts → contenedores dentro de cada VM
  (Así obtienes aislamiento fuerte entre tenants + eficiencia de contenedores)
```

---

# 3. Arquitectura de Docker

## 3.1 Componentes

```text
┌─────────────────────────────────────────────────────────────────┐
│  Docker CLI (docker)          │  La interfaz de línea de        │
│                               │  comandos. Envía instrucciones  │
│                               │  al daemon via REST API.        │
├───────────────────────────────┼─────────────────────────────────┤
│  Docker Daemon (dockerd)      │  Servicio en background que     │
│                               │  gestiona imágenes, contenedores│
│                               │  redes y volúmenes. Escucha en  │
│                               │  un socket Unix o TCP.          │
├───────────────────────────────┼─────────────────────────────────┤
│  containerd                   │  Runtime de contenedores de     │
│                               │  alto nivel. Gestiona el ciclo  │
│                               │  de vida completo del container.│
├───────────────────────────────┼─────────────────────────────────┤
│  runc                         │  Runtime de bajo nivel. Crea y  │
│                               │  ejecuta contenedores según el  │
│                               │  estándar OCI.                  │
├───────────────────────────────┼─────────────────────────────────┤
│  Registry (Docker Hub, etc.)  │  Almacén de imágenes. Push/pull │
│                               │  vía HTTPS.                     │
└───────────────────────────────┴─────────────────────────────────┘

Flujo de un `docker container run nginx`:

  CLI → (REST API) → dockerd → containerd → runc
                                              │
                                              ├─ Crea namespaces (aislamiento)
                                              ├─ Configura cgroups (límites)
                                              ├─ Monta filesystem (image layers + RW layer)
                                              └─ Ejecuta el proceso (CMD del Dockerfile)
```

## 3.2 ¿De qué están hechos los contenedores?

```text
Un contenedor es un proceso normal del sistema operativo, aislado mediante
dos mecanismos del kernel de Linux:

1. Namespaces — Aislamiento (qué puede VER el proceso)
   ┌──────────────┬──────────────────────────────────────────────┐
   │  Namespace   │  Qué aísla                                   │
   ├──────────────┼──────────────────────────────────────────────┤
   │  pid         │  Procesos (el contenedor ve su propio PID 1) │
   │  net         │  Interfaces de red, IPs, puertos, rutas      │
   │  mnt         │  Filesystem (sus propios archivos)           │
   │  uts         │  Hostname y domain name                      │
   │  ipc         │  Memoria compartida, semáforos               │
   │  user        │  UIDs/GIDs (root dentro ≠ root fuera)        │
   │  cgroup      │  Vista de los cgroups                        │
   └──────────────┴──────────────────────────────────────────────┘

2. Cgroups (Control Groups) — Límites (cuánto puede USAR el proceso)
   ┌──────────────┬──────────────────────────────────────────────┐
   │  Recurso     │  Qué limita                                  │
   ├──────────────┼──────────────────────────────────────────────┤
   │  cpu         │  Tiempo de CPU disponible                    │
   │  memory      │  RAM máxima (si excede → OOM kill)           │
   │  blkio       │  I/O de disco (lectura/escritura)            │
   │  pids        │  Número máximo de procesos                   │
   │  net_cls     │  Clasificación de tráfico de red             │
   └──────────────┴──────────────────────────────────────────────┘

3. Union Filesystem (OverlayFS)
   Las capas de la imagen son de solo lectura. Docker agrega una capa
   de escritura (thin layer) encima. Cualquier cambio va a esa capa.
   Es Copy-on-Write (COW): solo se copia un archivo al escribirlo.

Resultado: el contenedor CREE que tiene su propio OS, pero es solo
un proceso aislado usando el kernel del host.
```

---

# 4. Instalación y Verificación

## 4.1 Instalar Docker

```bash
# ─── Ubuntu/Debian ───
# Método oficial (script de conveniencia):
curl -fsSL https://get.docker.com | sh

# Agregar tu usuario al grupo docker (evitar sudo):
sudo usermod -aG docker $USER
newgrp docker    # O logout/login para aplicar

# ─── macOS ───
# Instalar Docker Desktop desde https://docker.com/products/docker-desktop
# O con Homebrew:
brew install --cask docker

# ─── RHEL/CentOS/Fedora ───
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
```

## 4.2 Verificar instalación

```bash
docker version          # Versión del client y server (daemon)
docker info             # Info detallada: containers, images, storage driver, etc.
docker run hello-world  # Test: descarga imagen y ejecuta contenedor de prueba

# Si ves "Hello from Docker!" → Docker está correctamente instalado.
```

---

# PARTE II — CICLO DE VIDA DE CONTENEDORES

---

# 5. docker container run — El Comando Fundamental

## 5.1 Qué sucede cuando ejecutas `docker container run`

```text
docker container run -d -p 80:80 --name web nginx

El comando ejecuta la siguiente secuencia:

  1. BUSCAR la imagen localmente
     ¿Existe "nginx:latest" en el cache local?

  2. PULL (si no existe localmente)
     Descargar desde el registry (Docker Hub por defecto).
     Solo descarga las capas que no tiene — incremental.

  3. CREAR el contenedor
     → Asignar un ID único (SHA256, se muestra truncado: a3b2c1...)
     → Crear una capa de escritura (read-write layer) sobre la imagen
     → Asignar un nombre (--name web, o uno aleatorio: angry_tesla)

  4. CONFIGURAR la red
     → Crear una interfaz de red virtual (veth pair)
     → Conectar al network bridge por defecto
     → Asignar una IP privada desde la subred del bridge (172.17.0.x)
     → Configurar port mapping: host:80 → container:80 (iptables/NAT)

  5. INICIAR el proceso
     → Ejecutar el CMD definido en el Dockerfile de la imagen
     → Para nginx: "nginx -g 'daemon off;'"
     → El proceso es PID 1 dentro del contenedor

  6. MODO DETACHED (-d)
     → El contenedor corre en background
     → La terminal queda libre
     → Sin -d, stdout/stderr del proceso se muestran en tu terminal
```

## 5.2 Sintaxis completa

```bash
docker container run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

## 5.3 Opciones esenciales

```text
┌───────────────────────┬──────────────────────────────────────────────────┐
│  Opción               │  Descripción                                     │
├───────────────────────┼──────────────────────────────────────────────────┤
│  -d, --detach         │  Ejecutar en background (devuelve el ID).       │
│                       │  Sin -d, te adjuntas al stdout del proceso.     │
│                       │                                                  │
│  --name NAME          │  Asignar nombre al contenedor. Sin esto, Docker │
│                       │  genera uno aleatorio (serene_turing, etc.).    │
│                       │  El nombre debe ser único entre contenedores.   │
│                       │                                                  │
│  -p, --publish        │  Mapear puerto HOST:CONTAINER.                  │
│  HOST:CONTAINER       │  -p 8080:80 → localhost:8080 llega al :80 del  │
│                       │  contenedor. Sin -p, NO hay acceso externo.    │
│                       │                                                  │
│  -e, --env KEY=VAL    │  Definir variable de entorno dentro del         │
│                       │  contenedor. Usado para passwords, configs.     │
│                       │  -e MYSQL_ROOT_PASSWORD=secret                  │
│                       │                                                  │
│  --env-file FILE      │  Cargar variables desde archivo .env            │
│                       │                                                  │
│  -v, --volume         │  Montar volumen HOST_PATH:CONTAINER_PATH.       │
│  HOST:CONTAINER       │  -v $(pwd)/data:/var/lib/mysql                  │
│                       │  Persiste datos más allá del ciclo del          │
│                       │  contenedor.                                    │
│                       │                                                  │
│  --network NET        │  Conectar a una red específica (en lugar del    │
│                       │  bridge por defecto).                           │
│                       │                                                  │
│  -it                  │  -i (interactive: mantener STDIN abierto)       │
│                       │  -t (tty: asignar pseudo-terminal)              │
│                       │  Juntos: shell interactivo dentro del           │
│                       │  contenedor.                                    │
│                       │                                                  │
│  --rm                 │  Eliminar automáticamente el contenedor al      │
│                       │  detenerse. Ideal para tareas puntuales.        │
│                       │                                                  │
│  --restart POLICY     │  Política de reinicio:                          │
│                       │    no (default), always, unless-stopped,        │
│                       │    on-failure[:max-retries]                     │
│                       │                                                  │
│  -m, --memory         │  Límite de memoria: -m 512m, -m 1g             │
│                       │                                                  │
│  --cpus               │  Límite de CPU: --cpus 1.5 (1.5 cores)         │
│                       │                                                  │
│  --hostname           │  Establecer hostname del contenedor              │
│                       │                                                  │
│  -w, --workdir        │  Directorio de trabajo dentro del contenedor    │
└───────────────────────┴──────────────────────────────────────────────────┘
```

## 5.4 Ejemplos prácticos

```bash
# ─── Servidor web básico ───
docker container run -d -p 80:80 --name nginx-web nginx

# ─── Base de datos con password y volumen ───
docker container run -d \
  --name postgres-db \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# ─── Contenedor temporal para depuración ───
docker container run --rm -it ubuntu:22.04 bash
# → Abre shell, al salir con `exit` se elimina automáticamente

# ─── Contenedor con límites de recursos ───
docker container run -d \
  --name api \
  -m 256m \
  --cpus 0.5 \
  -p 3000:3000 \
  my-api:latest

# ─── Overriding del CMD de la imagen ───
docker container run --rm nginx cat /etc/nginx/nginx.conf
# → En lugar de arrancar nginx, ejecuta `cat` y muestra el config

# ─── Con variables desde archivo .env ───
docker container run -d --env-file .env --name app my-app:latest
```

---

# 6. Gestión del Ciclo de Vida

## 6.1 Estados de un contenedor

```text
                    docker run
                        │
                        ▼
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ CREATED  │───▶│ RUNNING  │───▶│ STOPPED  │
  └──────────┘    └────┬─────┘    └────┬─────┘
                       │               │
                       │  docker stop  │  docker start
                       │◀──────────────│◀─────────────
                       │               │
                       │  docker rm    │  docker rm
                       │──────────────▶│──────────────▶ REMOVED
                       │               │
                       ▼               │
                  ┌──────────┐         │
                  │ PAUSED   │         │
                  └──────────┘         │
                  docker pause         │
                  docker unpause       │

  Nota: un contenedor STOPPED mantiene su filesystem (capa de escritura)
  y su configuración. Puede reiniciarse con `docker start`.
  Solo `docker rm` lo elimina definitivamente.
```

## 6.2 Comandos del ciclo de vida

```text
┌──────────────────────────────────┬───────────────────────────────────────────┐
│  Comando                         │  Descripción                              │
├──────────────────────────────────┼───────────────────────────────────────────┤
│  docker container run            │  Crear + iniciar contenedor (ver §5)      │
│                                  │                                           │
│  docker container start CONT     │  Iniciar contenedor detenido.            │
│    -a                            │  Attach (ver stdout)                     │
│    -i                            │  Interactive (mantener stdin abierto)    │
│                                  │                                           │
│  docker container stop CONT      │  Enviar SIGTERM, esperar 10s, SIGKILL.   │
│    -t N                          │  Cambiar timeout a N segundos.           │
│                                  │                                           │
│  docker container restart CONT   │  stop + start.                           │
│                                  │                                           │
│  docker container kill CONT      │  Enviar SIGKILL inmediatamente (forzar). │
│    -s SIGNAL                     │  Enviar señal específica.                │
│                                  │                                           │
│  docker container pause CONT     │  Congelar todos los procesos (SIGSTOP).  │
│  docker container unpause CONT   │  Descongelar.                            │
│                                  │                                           │
│  docker container rm CONT        │  Eliminar contenedor detenido.           │
│    -f                            │  Forzar (detener y eliminar).            │
│    -v                            │  También eliminar volúmenes anónimos.    │
│                                  │                                           │
│  docker container prune          │  Eliminar TODOS los contenedores         │
│                                  │  detenidos. Pide confirmación.           │
│    -f                            │  Sin confirmación.                       │
│                                  │                                           │
│  docker container rename OLD NEW │  Renombrar un contenedor.                │
│                                  │                                           │
│  docker container update CONT    │  Actualizar config sin recrear:          │
│    --memory 512m                 │  cambiar límites de memoria, CPU,        │
│    --cpus 1                      │  restart policy, etc.                    │
└──────────────────────────────────┴───────────────────────────────────────────┘
```

## 6.3 Listar contenedores

```bash
docker container ls                 # Solo contenedores RUNNING
docker container ls -a              # TODOS (incluyendo detenidos)
docker container ls -aq             # Solo IDs de todos
docker container ls -s              # Con tamaño de la capa de escritura
docker container ls --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                                    # Formato personalizado

# Alias clásico:
docker ps                           # = docker container ls
docker ps -a                        # = docker container ls -a
```

## 6.4 Detener y limpiar

```bash
# Detener todos los contenedores running:
docker container stop $(docker container ls -q)

# Eliminar todos los contenedores detenidos:
docker container prune -f

# Detener y eliminar TODO (running + stopped):
docker container rm -f $(docker container ls -aq)

# Nuclear: limpiar todo (containers, images sin usar, networks, cache):
docker system prune -a --volumes
# ⚠️ CUIDADO: elimina TODO lo que no esté en uso
```

---

# 7. Inspección y Monitoreo

## 7.1 docker container logs

```bash
docker container logs CONTAINER           # Ver todos los logs
docker container logs -f CONTAINER        # Follow (como tail -f)
docker container logs --tail 50 CONTAINER # Últimas 50 líneas
docker container logs --since 1h CONTAINER # Última hora
docker container logs --until 2024-01-01T12:00:00 CONTAINER
docker container logs -t CONTAINER        # Con timestamps

# Combinaciones útiles:
docker container logs -f --tail 100 my-app    # Seguir desde últimas 100 líneas
docker container logs my-app 2>&1 | grep ERROR # Filtrar errores
```

```text
¿De dónde vienen los logs?
  Docker captura stdout y stderr del proceso PID 1 del contenedor.
  Por eso las apps en Docker deben loguear a stdout, NO a archivos.

  El logging driver por defecto es "json-file", que guarda los logs en:
  /var/lib/docker/containers/<id>/<id>-json.log

  En producción, usa un logging driver externo:
    --log-driver=syslog
    --log-driver=fluentd
    --log-driver=awslogs     ← para AWS CloudWatch
    --log-driver=gelf        ← para Graylog/ELK
```

## 7.2 docker container top

```bash
docker container top CONTAINER            # Procesos dentro del contenedor
docker container top CONTAINER aux        # Formato ps aux

# Desde el host, los procesos del contenedor son procesos normales:
ps aux | grep nginx
# El PID dentro del container ≠ PID en el host (namespace PID)
```

## 7.3 docker container inspect

```bash
docker container inspect CONTAINER        # JSON completo de la configuración

# Extraer campos específicos con --format (Go templates):
docker container inspect --format '{{.NetworkSettings.IPAddress}}' CONTAINER
docker container inspect --format '{{.State.Status}}' CONTAINER
docker container inspect --format '{{.HostConfig.Memory}}' CONTAINER
docker container inspect --format '{{json .NetworkSettings.Ports}}' CONTAINER | jq

# Información que incluye:
#   → ID completo, nombre, imagen
#   → Estado (running, exited, código de salida)
#   → Configuración de red (IP, gateway, puertos)
#   → Volúmenes montados
#   → Variables de entorno
#   → Configuración de recursos (memoria, CPU)
#   → Timestamps (created, started, finished)
```

## 7.4 docker container stats

```bash
docker container stats                    # Stats de TODOS los containers (live)
docker container stats CONTAINER          # Stats de uno específico
docker container stats --no-stream        # Snapshot (una sola lectura)
docker container stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Salida:
# CONTAINER   CPU %   MEM USAGE / LIMIT    MEM %   NET I/O          BLOCK I/O
# nginx-web   0.07%   3.5MiB / 7.7GiB     0.04%   1.2kB / 648B     0B / 0B
```

## 7.5 docker container diff

```bash
docker container diff CONTAINER
# Muestra qué archivos cambiaron respecto a la imagen:
#   A = added (archivo nuevo)
#   C = changed (archivo modificado)
#   D = deleted (archivo eliminado)
```

## 7.6 Acceder al host desde Docker (avanzado)

```bash
# Para depuración del Docker Host (VM de Docker Desktop en macOS/Windows):
docker run -it --rm --privileged --pid=host justincormack/nsenter1

# Alternativa con Debian:
docker run -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i sh
# nsenter entra al namespace del PID 1 del host → acceso al filesystem del host

# ⚠️ Solo para depuración. NUNCA en producción.
```

---

# 8. Shell Interactivo dentro de Contenedores

## 8.1 docker container exec — Ejecutar comandos en contenedor running

```bash
# Abrir shell interactivo:
docker container exec -it CONTAINER bash      # Bash
docker container exec -it CONTAINER sh        # sh (Alpine, imágenes mínimas)
docker container exec -it CONTAINER /bin/zsh  # zsh si está instalado

# Ejecutar un comando puntual:
docker container exec CONTAINER cat /etc/hostname
docker container exec CONTAINER env           # Ver variables de entorno
docker container exec CONTAINER ps aux        # Procesos dentro

# Con usuario específico:
docker container exec -u root CONTAINER whoami
docker container exec -u 1000 CONTAINER id

# Con directorio de trabajo:
docker container exec -w /var/log CONTAINER ls -la
```

```text
exec vs run:

  exec  → Ejecuta un NUEVO proceso dentro de un contenedor YA corriendo.
          No crea un contenedor nuevo. El contenedor ya debe estar running.

  run   → CREA un nuevo contenedor desde una imagen y ejecuta un proceso.
          Es un contenedor completamente nuevo.

¿Cuándo usar exec?
  → Depurar un contenedor en producción
  → Verificar archivos de configuración
  → Ejecutar migrations de base de datos
  → Inspeccionar estado interno
```

## 8.2 docker container run -it — Shell al crear

```bash
# Crear contenedor interactivo (shell temporal):
docker container run -it --rm ubuntu:22.04 bash
# → Inicia un contenedor Ubuntu, abre bash
# → Al escribir `exit`, el contenedor se detiene y --rm lo elimina

docker container run -it --rm alpine sh
# → Alpine no tiene bash por defecto, usa sh

docker container run -it --rm python:3.12 python
# → Abre el REPL de Python

docker container run -it --rm node:20 node
# → Abre el REPL de Node.js
```

## 8.3 Reconectar a un contenedor detenido

```bash
# Si un contenedor se detuvo (exit), puedes reiniciarlo y adjuntarte:
docker container start -ai CONTAINER
# -a = attach (stdout/stderr)
# -i = interactive (stdin)

# Esto es diferente a exec: start reanuda el proceso original (PID 1),
# no crea un proceso nuevo.
```

## 8.4 ¿Qué shell tiene cada imagen?

```text
┌─────────────────────┬──────────────────────┬────────────────────────┐
│  Imagen             │  Shell disponible     │  Comando               │
├─────────────────────┼──────────────────────┼────────────────────────┤
│  ubuntu, debian     │  bash                │  docker exec -it C bash│
│  alpine             │  sh (ash/BusyBox)    │  docker exec -it C sh  │
│  centos, rocky      │  bash                │  docker exec -it C bash│
│  nginx              │  bash (Debian-based) │  docker exec -it C bash│
│  postgres           │  bash                │  docker exec -it C bash│
│  mysql/mariadb      │  bash                │  docker exec -it C bash│
│  node               │  bash                │  docker exec -it C bash│
│  python             │  bash                │  docker exec -it C bash│
│  busybox            │  sh                  │  docker exec -it C sh  │
│  distroless         │  ❌ (sin shell)       │  No se puede exec      │
└─────────────────────┴──────────────────────┴────────────────────────┘

Nota: las imágenes "distroless" de Google no tienen shell ni package
manager — solo el binario de la aplicación. Son más seguras pero no
se pueden depurar con exec.
```

---

# PARTE III — REDES EN DOCKER

---

# 9. Modelo de Red de Docker

## 9.1 Conceptos fundamentales

```text
Cada contenedor vive en su propio network namespace:
  → Tiene su propia interfaz de red (eth0)
  → Tiene su propia dirección IP
  → Tiene su propia tabla de rutas
  → Tiene su propio stack TCP/IP completo

Los contenedores se conectan entre sí y con el mundo exterior a través
de redes virtuales gestionadas por Docker.

Principio clave: "Batteries included, but removable"
  → Los defaults funcionan para la mayoría de casos
  → Pero puedes personalizar todo si lo necesitas
```

## 9.2 Cómo funciona la red por defecto

```text
┌─────────────────────────────────────────────────────────────────┐
│  HOST                                                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Docker Bridge Network (docker0) — 172.17.0.0/16       │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ Container A │  │ Container B │  │ Container C │    │   │
│  │  │ 172.17.0.2  │  │ 172.17.0.3  │  │ 172.17.0.4  │    │   │
│  │  │   eth0      │  │   eth0      │  │   eth0      │    │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │   │
│  │         │                │                │            │   │
│  │  ═══════╧════════════════╧════════════════╧═══════     │   │
│  │                    docker0 bridge                      │   │
│  └──────────────────────┬──────────────────────────────────┘   │
│                         │                                       │
│                    ┌────┴────┐                                  │
│                    │   NAT   │  (iptables / nftables)           │
│                    └────┬────┘                                  │
│                         │                                       │
│  ═══════════════════════╧═══════════════════                   │
│              eth0 (host) — IP pública                           │
│                         │                                       │
└─────────────────────────┼───────────────────────────────────────┘
                          │
                     ─────┴───── Internet

Reglas clave:
  1. Los contenedores en la MISMA red pueden comunicarse entre sí
     directamente (sin -p), usando sus IPs internas.

  2. Para acceso EXTERNO (desde el host o internet), necesitas
     port mapping con -p HOST:CONTAINER.

  3. El tráfico de salida (container → internet) pasa por NAT:
     la IP del contenedor se traduce a la IP del host.

  4. Todos los puertos de un contenedor están CERRADOS por defecto.
     Solo -p los abre. Esto es seguridad by default.
```

---

# 10. Network Drivers

## 10.1 Drivers disponibles

```text
┌──────────────┬───────────────────────────────────────────────────────────┐
│  Driver      │  Descripción                                             │
├──────────────┼───────────────────────────────────────────────────────────┤
│  bridge      │  DEFAULT. Red privada virtual en el host.                │
│  (default)   │  Los contenedores obtienen IP en una subred interna      │
│              │  (172.17.0.0/16 para el bridge default).                │
│              │  Se comunican entre sí via bridge virtual (docker0).     │
│              │  Acceso externo solo via port mapping (-p).              │
│              │  ✅ Uso: contenedores en un solo host.                   │
│              │                                                          │
│  host        │  El contenedor comparte el network stack del HOST.       │
│              │  No hay aislamiento de red — el contenedor usa la IP     │
│              │  y puertos del host directamente. No necesita -p.        │
│              │  ✅ Uso: máximo rendimiento de red, benchmarks.          │
│              │  ⚠️ Sacrifica aislamiento y seguridad.                   │
│              │  ⚠️ No disponible en Docker Desktop (macOS/Windows).     │
│              │                                                          │
│  none        │  Sin red. El contenedor solo tiene la interfaz           │
│              │  loopback (localhost). Completamente aislado.            │
│              │  ✅ Uso: procesos batch sin necesidad de red,            │
│              │  contenedores de seguridad alta.                        │
│              │                                                          │
│  overlay     │  Red que abarca MÚLTIPLES hosts Docker.                  │
│              │  Usa VXLAN para encapsular tráfico entre nodos.         │
│              │  ✅ Uso: Docker Swarm, Kubernetes (comunicación          │
│              │  entre contenedores en diferentes máquinas).            │
│              │                                                          │
│  macvlan     │  Asigna una MAC address real al contenedor.             │
│              │  El contenedor aparece como un dispositivo físico       │
│              │  en la red local.                                       │
│              │  ✅ Uso: aplicaciones legacy que necesitan estar         │
│              │  en la misma red L2 que otros dispositivos.             │
│              │                                                          │
│  ipvlan      │  Similar a macvlan pero comparte la MAC del host.       │
│              │  ✅ Uso: cuando el switch limita MACs por puerto.        │
└──────────────┴───────────────────────────────────────────────────────────┘
```

## 10.2 Bridge default vs Bridge custom (user-defined)

```text
┌──────────────────────────┬───────────────────────────────────────┐
│  Bridge Default          │  Bridge Custom (user-defined)         │
│  (docker0)               │  (docker network create)              │
├──────────────────────────┼───────────────────────────────────────┤
│  ❌ Sin DNS automático    │  ✅ DNS automático (nombre →  IP)     │
│  (solo acceso por IP)    │  (contenedores se resuelven por      │
│                          │  nombre)                              │
│                          │                                       │
│  Todos los contenedores  │  Solo contenedores en la misma       │
│  comparten la misma red  │  red se ven entre sí (aislamiento)  │
│                          │                                       │
│  Configuración limitada  │  Configurable: subred, gateway,      │
│                          │  rango de IPs, MTU, etc.             │
│                          │                                       │
│  Usar --link (deprecated)│  DNS nativo — sin --link              │
│  para resolución por     │                                       │
│  nombre                  │                                       │
└──────────────────────────┴───────────────────────────────────────┘

⚡ REGLA: SIEMPRE crear redes custom para tus aplicaciones.
   El bridge default es para pruebas rápidas, no para producción.
```

---

# 11. Gestión de Redes (CLI)

## 11.1 Comandos de red

```text
┌───────────────────────────────────────┬──────────────────────────────────────┐
│  Comando                              │  Descripción                         │
├───────────────────────────────────────┼──────────────────────────────────────┤
│  docker network ls                    │  Listar todas las redes.            │
│                                       │                                      │
│  docker network create NAME           │  Crear red (bridge por defecto).    │
│    --driver DRIVER                    │  Especificar driver.                │
│    --subnet 10.0.0.0/24              │  Subred personalizada.              │
│    --gateway 10.0.0.1                │  Gateway personalizado.             │
│    --ip-range 10.0.0.128/25          │  Rango de IPs asignables.           │
│                                       │                                      │
│  docker network inspect NAME          │  JSON detallado: config, containers │
│                                       │  conectados, IPs, opciones.         │
│                                       │                                      │
│  docker network connect NET CONT      │  Conectar contenedor running a una  │
│                                       │  red adicional. El contenedor       │
│                                       │  obtiene una nueva interfaz (eth1)  │
│                                       │  con IP de la nueva red.            │
│                                       │                                      │
│  docker network disconnect NET CONT   │  Desconectar contenedor de una red. │
│                                       │  Elimina la interfaz virtual.       │
│                                       │                                      │
│  docker network rm NAME               │  Eliminar red (debe estar vacía).   │
│                                       │                                      │
│  docker network prune                 │  Eliminar redes no utilizadas.      │
└───────────────────────────────────────┴──────────────────────────────────────┘
```

## 11.2 Ejemplos prácticos

```bash
# ─── Crear redes para una aplicación ───
docker network create frontend
docker network create backend

# ─── Ejecutar contenedores en sus redes ───
docker container run -d --name web --network frontend -p 80:80 nginx
docker container run -d --name api --network backend -p 3000:3000 node:20
docker container run -d --name db --network backend \
  -e POSTGRES_PASSWORD=secret postgres:16

# ─── Conectar api a ambas redes ───
# El API necesita hablar con el frontend Y con la base de datos
docker network connect frontend api

# Ahora "api" tiene dos interfaces:
#   eth0 → backend  (puede ver "db")
#   eth1 → frontend (puede ser visto por "web")

# ─── Verificar ───
docker network inspect frontend --format '{{range .Containers}}{{.Name}} {{end}}'
# web api

docker network inspect backend --format '{{range .Containers}}{{.Name}} {{end}}'
# api db

# ─── El contenedor "web" NO puede ver "db" ───
# Están en redes diferentes → aislamiento por diseño

# ─── Inspeccionar IP de un contenedor ───
docker container inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' api
```

## 11.3 Patrón de arquitectura: redes por servicio

```text
Buena práctica: crear una red por "frontera" de la aplicación:

  ┌─────────────────────────────────────────────────┐
  │  Red: frontend                                   │
  │  ┌─────────┐         ┌──────────┐               │
  │  │ nginx   │────────▶│  api     │               │
  │  │ (proxy) │  :80    │  (node)  │               │
  │  └─────────┘         └────┬─────┘               │
  └───────────────────────────┼─────────────────────┘
                              │
  ┌───────────────────────────┼─────────────────────┐
  │  Red: backend             │                      │
  │                      ┌────┴─────┐               │
  │                      │  api     │               │
  │                      │  (node)  │               │
  │                      └────┬─────┘               │
  │                           │                      │
  │                      ┌────┴─────┐               │
  │                      │ postgres │               │
  │                      │  (db)    │               │
  │                      └──────────┘               │
  └──────────────────────────────────────────────────┘

  → nginx solo ve el api (red frontend)
  → postgres solo es accesible desde api (red backend)
  → api está en ambas redes (docker network connect)
  → Base de datos NUNCA expuesta directamente al exterior
```

---

# 12. Port Mapping y Firewalls

## 12.1 Cómo funciona el port mapping

```text
-p HOST_PORT:CONTAINER_PORT

docker container run -d -p 8080:80 nginx

  Mundo exterior
       │
       ▼
  Host:8080  ──(NAT/iptables)──▶  Container:80  (nginx)

  El host escucha en el puerto 8080.
  Docker configura reglas de iptables/nftables para redirigir
  el tráfico al puerto 80 dentro del contenedor.
```

## 12.2 Variantes de -p

```bash
-p 8080:80              # Host 8080 → Container 80 (en todas las interfaces)
-p 127.0.0.1:8080:80   # Solo localhost del host → Container 80
-p 8080:80/udp          # UDP en lugar de TCP
-p 8080:80/tcp -p 8080:80/udp  # Ambos protocolos
-p 8080-8090:80-90      # Rango de puertos

# Sin especificar puerto del host (Docker asigna uno aleatorio):
-p 80                   # Host ??? → Container 80
docker port CONTAINER   # Ver qué puerto asignó
```

## 12.3 docker port

```bash
docker port CONTAINER
# 80/tcp -> 0.0.0.0:8080
# 80/tcp -> [::]:8080

docker port CONTAINER 80
# 0.0.0.0:8080
```

## 12.4 Seguridad de puertos

```text
⚠️  Reglas de seguridad de puertos:

  1. Por defecto, NINGÚN puerto del contenedor es accesible desde fuera.
     Solo -p los abre. Esta es la seguridad por defecto de Docker.

  2. -p 8080:80 escucha en 0.0.0.0 (TODAS las interfaces del host).
     Esto significa que el puerto es accesible desde internet si el
     host tiene IP pública.

  3. Para limitar acceso solo desde localhost:
     -p 127.0.0.1:8080:80

  4. EXPOSE en el Dockerfile NO abre puertos. Solo documenta qué
     puertos usa la aplicación. Es metadata, no configuración.

  5. Docker modifica iptables directamente, lo que puede BYPASS
     reglas de UFW/firewalld. Esto es un error común de seguridad:
       → Crees que UFW bloquea el puerto 3306
       → Pero Docker lo abre via iptables
       → Tu base de datos queda expuesta a internet

     Solución:
       a) Usar -p 127.0.0.1:3306:3306 para bases de datos
       b) Configurar DOCKER-USER chain en iptables
       c) Usar redes internas sin -p para servicios internos
```

---

# PARTE IV — DNS Y DESCUBRIMIENTO DE SERVICIOS

---

# 13. DNS Interno de Docker

## 13.1 El problema que resuelve DNS

```text
Los contenedores reciben IPs dinámicas. Cada vez que recreas un
contenedor, puede obtener una IP diferente. Por lo tanto:

  ❌ ANTI-PATRÓN: hardcodear IPs de contenedores
     DB_HOST=172.17.0.3   ← se rompe al recrear el contenedor

  ✅ CORRECTO: usar nombres de contenedor como hostnames
     DB_HOST=postgres-db   ← Docker resuelve el nombre a la IP actual

Esto es posible gracias al DNS server interno de Docker.
```

## 13.2 Cómo funciona

```text
Docker ejecuta un servidor DNS embebido (127.0.0.11) dentro de cada
contenedor conectado a una red user-defined (custom bridge).

Cuando un contenedor hace una petición DNS:
  1. El resolver del contenedor pregunta a 127.0.0.11
  2. Docker busca el nombre en sus registros internos
  3. Si es un nombre de contenedor → devuelve la IP interna
  4. Si no lo encuentra → reenvía al DNS del host (/etc/resolv.conf)

┌──────────────────────────────────────────────────────────────┐
│  Container A quiere hablar con "db"                          │
│                                                              │
│  app → DNS query "db" → 127.0.0.11 (Docker DNS)            │
│                              │                               │
│                   ¿"db" es un contenedor en mi red?          │
│                              │                               │
│                     SÍ → devolver 172.18.0.3                 │
│                     NO → preguntar al DNS del host           │
│                              │                               │
│  app → conectar a 172.18.0.3:5432                            │
└──────────────────────────────────────────────────────────────┘

IMPORTANTE:
  → El DNS automático SOLO funciona en redes custom (user-defined).
  → En el bridge default (docker0), NO hay DNS automático.
  → Por eso SIEMPRE debes crear redes custom.
```

## 13.3 Nombres y aliases

```bash
# El nombre DNS por defecto es el --name del contenedor:
docker container run -d --name my-db --network app-net postgres:16
# Otros contenedores en app-net pueden resolver "my-db"

# Aliases permiten nombres adicionales:
docker container run -d --name postgres-primary \
  --network app-net \
  --network-alias db \
  --network-alias database \
  postgres:16
# Ahora "postgres-primary", "db", y "database" resuelven al mismo container

# El hostname interno (por defecto = container ID truncado) se cambia con:
docker container run -d --hostname my-custom-hostname --name web nginx
```

## 13.4 --link está deprecated

```text
❌ docker run --link container_name:alias  ← DEPRECATED desde Docker 1.9

El flag --link fue la forma original de conectar contenedores,
pero tiene problemas:
  → Solo funciona en una dirección
  → No se integra con redes custom
  → No escala
  → No soporta desconexión dinámica

✅ La forma correcta: crear una red custom y usar --network
   Docker DNS se encarga de todo automáticamente.
```

## 13.5 Ejemplo completo: aplicación multi-contenedor

```bash
# Crear la red:
docker network create my_app_net

# Base de datos:
docker container run -d \
  --name my-db \
  --network my_app_net \
  --network-alias db \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# API (se conecta a la DB usando el nombre "db"):
docker container run -d \
  --name my-api \
  --network my_app_net \
  -e DATABASE_URL=postgres://postgres:secret@db:5432/postgres \
  -p 3000:3000 \
  my-api-image:latest

# Proxy (se conecta al API usando el nombre "my-api"):
docker container run -d \
  --name my-proxy \
  --network my_app_net \
  -p 80:80 \
  nginx

# Verificar resolución DNS:
docker container exec my-api ping -c 2 db
# PING db (172.18.0.2) 56(84) bytes of data.
# 64 bytes from my-db.my_app_net (172.18.0.2): ...

docker container exec my-api nslookup db
# Server:    127.0.0.11
# Address:   127.0.0.11#53
# Non-authoritative answer:
# Name:  db
# Address: 172.18.0.2
```

---

# 14. Round-Robin DNS y Load Balancing

## 14.1 ¿Qué es Round-Robin DNS?

```text
Cuando múltiples contenedores comparten el MISMO alias DNS (--net-alias),
Docker devuelve TODAS las IPs asociadas a ese alias, rotando el orden.

Esto proporciona un load balancing básico a nivel DNS:
  → Cada query DNS devuelve las mismas IPs en orden diferente
  → El cliente se conecta a la primera IP de la lista
  → Las peticiones se distribuyen entre todos los contenedores

                    DNS query "search"
                          │
                          ▼
                  Docker DNS Server
                    (127.0.0.11)
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        Container 1  Container 2  Container 3
        172.18.0.2   172.18.0.3   172.18.0.4
        (search)     (search)     (search)

  Primera query  → [172.18.0.2, 172.18.0.3, 172.18.0.4]
  Segunda query  → [172.18.0.3, 172.18.0.4, 172.18.0.2]
  Tercera query  → [172.18.0.4, 172.18.0.2, 172.18.0.3]

Limitaciones:
  → No es un load balancer real (no verifica health)
  → El DNS se cachea — no distribuye perfectamente
  → Para producción: usar un reverse proxy (nginx, HAProxy, Traefik)
    o un orquestador (Docker Swarm, Kubernetes)
```

## 14.2 Ejemplo práctico

```bash
# Crear red:
docker network create search-net

# Crear 3 contenedores con el mismo alias "search":
docker container run -d --network search-net --net-alias search \
  bretfisher/httpenv
docker container run -d --network search-net --net-alias search \
  bretfisher/httpenv
docker container run -d --network search-net --net-alias search \
  bretfisher/httpenv
# httpenv es una imagen que devuelve sus variables de entorno como JSON
# (incluyendo HOSTNAME = container ID)

# Consultar el alias — observa cómo cambia el HOSTNAME en cada respuesta:
docker container run --rm --network search-net curlimages/curl \
  curl -s search:8888 | jq .HOSTNAME
# "a3b2c1d4e5f6"

docker container run --rm --network search-net curlimages/curl \
  curl -s search:8888 | jq .HOSTNAME
# "f6e5d4c3b2a1"

docker container run --rm --network search-net curlimages/curl \
  curl -s search:8888 | jq .HOSTNAME
# "1a2b3c4d5e6f"

# ¡Cada petición llega a un contenedor diferente!

# Verificar con nslookup — muestra todas las IPs:
docker container run --rm --network search-net busybox nslookup search
# Name:      search
# Address 1: 172.19.0.2
# Address 2: 172.19.0.3
# Address 3: 172.19.0.4
```

---

# PARTE V — DOCKER HUB Y REGISTRIES

---

# 15. Docker Hub y Registros

## 15.1 ¿Qué es un Registry?

```text
Un registry es un servicio que almacena y distribuye imágenes Docker.

  Docker Hub     → Registry público por defecto (hub.docker.com)
  Amazon ECR     → Registry privado de AWS
  Google GCR/AR  → Registry de Google Cloud
  Azure ACR      → Registry de Azure
  GitHub GHCR    → Registry de GitHub (ghcr.io)
  Self-hosted    → Harbor, Nexus, GitLab Registry

Formato de nombres de imágenes:
  nginx                        → Docker Hub oficial (library/nginx)
  myuser/myapp                 → Docker Hub, cuenta personal
  myuser/myapp:v2.1            → Con tag específico
  ghcr.io/owner/repo:latest    → GitHub Container Registry
  123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1  → AWS ECR
```

## 15.2 Docker Hub: imágenes oficiales vs comunitarias

```text
Imágenes oficiales (library/):
  → Mantenidas por Docker y los autores del software
  → Revisadas y actualizadas regularmente
  → No necesitan prefijo de usuario: nginx, postgres, node
  → Documentación detallada en Docker Hub

Imágenes comunitarias:
  → Creadas por usuarios: bretfisher/httpenv, bitnami/redis
  → Calidad variable — verificar estrellas, pulls, última actualización
  → Siempre llevan prefijo: usuario/imagen

⚠️ NUNCA usar imágenes de fuentes no confiables en producción.
   → Verificar que sea una imagen oficial o de un publisher verificado
   → Revisar el Dockerfile si está disponible
   → Escanear vulnerabilidades con: docker scout cves IMAGE
```

---

# 16. Autenticación y Seguridad

## 16.1 docker login / logout

```bash
# Login a Docker Hub:
docker login
# Pide usuario y password interactivamente

docker login -u myuser
# Solo pide password

# Login con password desde stdin (para CI/CD):
echo "$DOCKER_TOKEN" | docker login -u myuser --password-stdin

# Login a otro registry:
docker login ghcr.io
docker login 123456789.dkr.ecr.us-east-1.amazonaws.com

# Logout:
docker logout
docker logout ghcr.io

# ¿Dónde se guarda la credencial?
# ~/.docker/config.json
# ⚠️ Por defecto se guarda en texto plano (base64).
# Usar un credential helper para seguridad:
#   → docker-credential-osxkeychain (macOS)
#   → docker-credential-pass (Linux)
#   → docker-credential-ecr-login (AWS)
```

## 16.2 Buenas prácticas de seguridad con registries

```text
1. Usar tokens de acceso en lugar de passwords
   → Docker Hub: Account Settings → Security → Access Tokens
   → Scope: read-only para CI/CD que solo hace pull

2. En CI/CD, NUNCA hardcodear credenciales en el código
   → Usar secrets del CI system (GitHub Actions secrets, etc.)
   → echo "$DOCKER_TOKEN" | docker login --password-stdin

3. Firmar imágenes con Docker Content Trust:
   export DOCKER_CONTENT_TRUST=1
   docker push myimage:latest   # Firma automáticamente

4. Escanear imágenes antes de usarlas:
   docker scout cves nginx:latest
   docker scout recommendations nginx:latest
```

---

# PARTE VI — BUENAS PRÁCTICAS Y PRODUCCIÓN

---

# 17. Anti-Patrones y Errores Comunes

## 17.1 Anti-patrones

```text
┌──────────────────────────────────────┬───────────────────────────────────────┐
│  ❌ Anti-patrón                       │  ✅ Correcto                          │
├──────────────────────────────────────┼───────────────────────────────────────┤
│  Usar IPs para conectar containers   │  Usar nombres DNS (container names   │
│                                      │  o aliases en redes custom)          │
│                                      │                                       │
│  Usar el bridge default para todo    │  Crear redes custom por aplicación   │
│                                      │                                       │
│  --link para conectar containers     │  --network con redes custom          │
│                                      │                                       │
│  Ejecutar como root dentro del       │  USER en Dockerfile, o --user al     │
│  contenedor                          │  ejecutar                            │
│                                      │                                       │
│  Guardar datos en la capa de         │  Usar volúmenes (-v) para datos      │
│  escritura del contenedor            │  que deben persistir                 │
│                                      │                                       │
│  Usar :latest en producción          │  Usar tags específicos: nginx:1.25   │
│                                      │                                       │
│  Un contenedor = múltiples procesos  │  Un contenedor = un proceso          │
│                                      │  (single responsibility)             │
│                                      │                                       │
│  Imágenes enormes (1GB+)            │  Multi-stage builds, Alpine base     │
│                                      │                                       │
│  docker run en producción           │  Docker Compose, Swarm, o K8s        │
│                                      │                                       │
│  Logs a archivos dentro del         │  Logs a stdout/stderr (Docker los    │
│  contenedor                          │  captura automáticamente)            │
│                                      │                                       │
│  -p 0.0.0.0:3306:3306 para la DB    │  -p 127.0.0.1:3306:3306 o sin -p    │
│  (expuesta a internet)               │  (solo accesible via red interna)    │
│                                      │                                       │
│  docker exec para modificar          │  Reconstruir la imagen y recrear     │
│  archivos en producción              │  el contenedor (immutable infra)     │
└──────────────────────────────────────┴───────────────────────────────────────┘
```

## 17.2 Errores comunes

```text
1. "Bind for 0.0.0.0:80 failed: port is already allocated"
   → Otro contenedor (o proceso) ya usa el puerto 80 del host.
   → Solución: ss -tlnp | grep :80  (ver quién lo usa)
   → Cambiar el puerto del host: -p 8080:80

2. "OCI runtime create failed: container_linux.go: starting container
    process caused: exec: 'bash': executable file not found"
   → La imagen no tiene bash (Alpine, distroless).
   → Solución: usar sh en lugar de bash.

3. Contenedor se detiene inmediatamente
   → El proceso PID 1 terminó. Contenedor = proceso.
   → docker container logs CONTAINER para ver el error.
   → Causa común: el CMD del Dockerfile es incorrecto.

4. "Cannot connect to the Docker daemon"
   → dockerd no está corriendo.
   → Solución: sudo systemctl start docker

5. "Permission denied while trying to connect to Docker daemon socket"
   → Tu usuario no está en el grupo docker.
   → sudo usermod -aG docker $USER → logout/login

6. Contenedor no puede resolver DNS de otros contenedores
   → Probablemente están en el bridge default (sin DNS auto).
   → Solución: crear red custom con docker network create.
```

---

# 18. Buenas Prácticas para Producción

## 18.1 Checklist de producción

```text
┌──────────────────────────────────────────────────────────────────┐
│  CONTENEDORES                                                    │
│  □  Un proceso por contenedor                                    │
│  □  Logs a stdout/stderr                                         │
│  □  --restart unless-stopped o on-failure                        │
│  □  Límites de recursos: --memory, --cpus                       │
│  □  Health checks definidos (HEALTHCHECK en Dockerfile)          │
│  □  NO ejecutar como root (USER en Dockerfile)                  │
│  □  Read-only filesystem cuando sea posible (--read-only)       │
│                                                                  │
│  IMÁGENES                                                        │
│  □  Tags específicos (nunca :latest en prod)                    │
│  □  Multi-stage builds para reducir tamaño                      │
│  □  Escanear vulnerabilidades antes de deploy                   │
│  □  Base images oficiales y actualizadas                        │
│  □  .dockerignore para excluir archivos innecesarios            │
│                                                                  │
│  REDES                                                           │
│  □  Redes custom por aplicación/servicio                        │
│  □  Bases de datos sin -p (solo accesibles internamente)        │
│  □  -p 127.0.0.1:PORT si necesitas acceso local                │
│  □  TLS para comunicación entre servicios (mTLS en prod)        │
│                                                                  │
│  DATOS                                                           │
│  □  Volúmenes para datos persistentes                           │
│  □  Backups automatizados de volúmenes                          │
│  □  No guardar estado en contenedores (efímeros)                │
│                                                                  │
│  ORQUESTACIÓN                                                    │
│  □  Docker Compose para desarrollo local                        │
│  □  Docker Swarm o Kubernetes para producción                   │
│  □  CI/CD pipeline: build → test → scan → push → deploy        │
│  □  Logging centralizado (ELK, CloudWatch, Datadog)             │
│  □  Monitoreo (Prometheus + Grafana, Datadog)                   │
└──────────────────────────────────────────────────────────────────┘
```

## 18.2 Limpieza y mantenimiento

```bash
# Ver uso de disco de Docker:
docker system df
docker system df -v         # Detallado

# Limpiar recursos no utilizados:
docker container prune      # Contenedores detenidos
docker image prune          # Imágenes dangling (sin tag)
docker image prune -a       # Imágenes no usadas por ningún contenedor
docker volume prune         # Volúmenes no montados
docker network prune        # Redes sin contenedores

# Nuclear (todo lo anterior de una vez):
docker system prune         # Sin volúmenes
docker system prune -a --volumes  # TODO (⚠️ destructivo)

# Cron job de limpieza (producción):
# 0 3 * * 0 docker system prune -f --filter "until=168h"
# Cada domingo a las 3AM, eliminar recursos de más de 7 días
```

---

# PARTE VII — EJERCICIOS PRÁCTICOS

---

# 19. Ejercicio 1 — Gestión Básica de Contenedores

## Objetivo

Desplegar tres contenedores (nginx, mysql, httpd) en modo detached,
verificar logs/procesos/estado, detenerlos y limpiar.

## Paso a paso

```bash
# ─── 1. Crear los contenedores ───

# MySQL con password aleatorio generado automáticamente:
docker container run -d \
  -p 3306:3306 \
  --name my-mysql \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  mysql

# Apache HTTPd:
docker container run -d \
  --name my-httpd \
  -p 8080:80 \
  httpd

# Nginx:
docker container run -d \
  --name my-nginx \
  -p 80:80 \
  nginx

# ─── 2. Verificar que están corriendo ───
docker container ls
# CONTAINER ID   IMAGE   STATUS         PORTS                  NAMES
# a1b2c3...      mysql   Up 2 minutes   0.0.0.0:3306->3306    my-mysql
# d4e5f6...      httpd   Up 2 minutes   0.0.0.0:8080->80      my-httpd
# g7h8i9...      nginx   Up 2 minutes   0.0.0.0:80->80        my-nginx

# ─── 3. Obtener el password generado de MySQL ───
docker container logs my-mysql 2>&1 | grep "GENERATED ROOT PASSWORD"
# GENERATED ROOT PASSWORD: aHf8kL2mNp...

# ─── 4. Verificar que los servidores responden ───
curl -s localhost:80 | head -5      # Nginx
curl -s localhost:8080 | head -5    # HTTPd

# ─── 5. Ver procesos dentro de cada contenedor ───
docker container top my-nginx
docker container top my-mysql
docker container top my-httpd

# ─── 6. Ver estadísticas en tiempo real ───
docker container stats --no-stream

# ─── 7. Detener todos ───
docker container stop my-mysql my-httpd my-nginx

# ─── 8. Verificar que están detenidos ───
docker container ls -a
# STATUS: Exited (0)

# ─── 9. Eliminar ───
docker container rm my-mysql my-httpd my-nginx

# ─── 10. Verificar limpieza ───
docker container ls -a
# (vacío)
```

---

# 20. Ejercicio 2 — Redes y DNS

## Objetivo

Crear una red custom, desplegar dos contenedores nginx y verificar que
se resuelven por nombre vía DNS.

## Paso a paso

```bash
# ─── 1. Crear red ───
docker network create my_app_net

# ─── 2. Crear contenedores en la red ───
docker container run -d --name my_nginx --network my_app_net nginx:alpine
docker container run -d --name new_nginx --network my_app_net nginx:alpine

# ─── 3. Verificar resolución DNS ───
docker container exec -it new_nginx ping -c 3 my_nginx
# PING my_nginx (172.19.0.2) 56 data bytes
# 64 bytes from 172.19.0.2: icmp_seq=1 ttl=64 time=0.085 ms

docker container exec -it my_nginx ping -c 3 new_nginx
# PING new_nginx (172.19.0.3) 56 data bytes
# 64 bytes from 172.19.0.3: icmp_seq=1 ttl=64 time=0.072 ms

# ─── 4. Inspeccionar la red ───
docker network inspect my_app_net --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
# my_nginx: 172.19.0.2/16
# new_nginx: 172.19.0.3/16

# ─── 5. Limpiar ───
docker container rm -f my_nginx new_nginx
docker network rm my_app_net
```

---

# 21. Ejercicio 3 — Round-Robin DNS

## Objetivo

Demostrar el load balancing por DNS con múltiples contenedores
compartiendo el mismo alias.

## Paso a paso

```bash
# ─── 1. Crear red ───
docker network create dude-net

# ─── 2. Crear 3 contenedores con el mismo alias "search" ───
docker container run -d --network dude-net --net-alias search bretfisher/httpenv
docker container run -d --network dude-net --net-alias search bretfisher/httpenv
docker container run -d --network dude-net --net-alias search bretfisher/httpenv

# ─── 3. Verificar resolución DNS (múltiples IPs) ───
docker container run --rm --network dude-net busybox nslookup search
# Address 1: 172.20.0.2
# Address 2: 172.20.0.3
# Address 3: 172.20.0.4

# ─── 4. Curl al alias — cada petición puede ir a un contenedor diferente ───
# Observa el HOSTNAME diferente en cada respuesta:
docker container run --rm --network dude-net curlimages/curl \
  curl -s search:8888 | grep HOSTNAME
# "HOSTNAME": "a3b2c1d4e5f6"

docker container run --rm --network dude-net curlimages/curl \
  curl -s search:8888 | grep HOSTNAME
# "HOSTNAME": "f6e5d4c3b2a1"

docker container run --rm --network dude-net curlimages/curl \
  curl -s search:8888 | grep HOSTNAME
# "HOSTNAME": "1a2b3c4d5e6f"

# ─── 5. Limpiar ───
docker container rm -f $(docker container ls -q --filter network=dude-net)
docker network rm dude-net
```

---

# 22. Ejercicio 4 — CLI App Testing

## Objetivo

Usar contenedores temporales para probar herramientas de línea de comandos
en entornos limpios y reproducibles.

## Paso a paso

```bash
# ─── Probar una versión específica de Node.js ───
docker container run --rm -it node:18 node -e "console.log(process.version)"
# v18.20.4

docker container run --rm -it node:20 node -e "console.log(process.version)"
# v20.17.0

# ─── Probar Python con dependencias ───
docker container run --rm -it python:3.12 bash -c \
  "pip install requests && python -c 'import requests; print(requests.get(\"https://httpbin.org/ip\").json())'"

# ─── Usar herramientas de red en un contenedor limpio ───
docker container run --rm -it --network host nicolaka/netshoot
# netshoot incluye: curl, ping, dig, nslookup, tcpdump, iperf3, etc.
# Ideal para depurar networking de contenedores

# ─── Ejecutar un script local dentro de un contenedor ───
docker container run --rm -v $(pwd):/app -w /app python:3.12 python script.py

# ─── Compilar código C sin instalar gcc en tu máquina ───
docker container run --rm -v $(pwd):/src -w /src gcc:13 gcc -o main main.c
docker container run --rm -v $(pwd):/src -w /src gcc:13 ./main
```