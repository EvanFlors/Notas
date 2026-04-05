# Docker Images — Guía Completa: Capas, Builds y Dockerfiles

> **Idea central:** Una imagen Docker es un paquete inmutable que contiene exactamente
> lo que tu aplicación necesita para ejecutarse — ni más, ni menos. No es un OS
> completo: no tiene kernel, no tiene drivers, no tiene servicios innecesarios.
> Es un filesystem compuesto por capas de solo lectura, apiladas con precisión
> quirúrgica para que cada cambio sea incremental, cacheable y compartible.
> Dominar imágenes y Dockerfiles es dominar la eficiencia, la seguridad y la
> reproducibilidad del despliegue moderno.

---

## Tabla de Contenidos

**Parte I — Fundamentos de Imágenes**
1. [¿Qué es una Imagen Docker?](#1-qué-es-una-imagen-docker)
2. [Image vs Container](#2-image-vs-container)
3. [Union Filesystem y Capas](#3-union-filesystem-y-capas)
4. [Copy-on-Write (COW)](#4-copy-on-write-cow)

**Parte II — Comandos de Imágenes**
5. [Gestión de Imágenes (CLI)](#5-gestión-de-imágenes-cli)
6. [Inspección de Imágenes](#6-inspección-de-imágenes)
7. [Limpieza y Espacio en Disco](#7-limpieza-y-espacio-en-disco)

**Parte III — Tags y Docker Hub**
8. [Image Tags](#8-image-tags)
9. [Naming Convention y Registries](#9-naming-convention-y-registries)
10. [Push y Pull](#10-push-y-pull)

**Parte IV — Dockerfile: Construir Imágenes**
11. [¿Qué es un Dockerfile?](#11-qué-es-un-dockerfile)
12. [Instrucciones del Dockerfile](#12-instrucciones-del-dockerfile)
13. [FROM — La Base Image](#13-from--la-base-image)
14. [RUN — Ejecutar Comandos](#14-run--ejecutar-comandos)
15. [COPY y ADD — Agregar Archivos](#15-copy-y-add--agregar-archivos)
16. [WORKDIR — Directorio de Trabajo](#16-workdir--directorio-de-trabajo)
17. [ENV y ARG — Variables](#17-env-y-arg--variables)
18. [EXPOSE — Documentar Puertos](#18-expose--documentar-puertos)
19. [CMD y ENTRYPOINT — Proceso Principal](#19-cmd-y-entrypoint--proceso-principal)
20. [USER — Seguridad](#20-user--seguridad)
21. [VOLUME — Declarar Puntos de Montaje](#21-volume--declarar-puntos-de-montaje)
22. [HEALTHCHECK — Verificar Salud](#22-healthcheck--verificar-salud)
23. [LABEL, STOPSIGNAL, SHELL, ONBUILD](#23-label-stopsignal-shell-onbuild)

**Parte V — Build Avanzado**
24. [Build Context y .dockerignore](#24-build-context-y-dockerignore)
25. [Build Cache — Cómo Funciona](#25-build-cache--cómo-funciona)
26. [Multi-Stage Builds](#26-multi-stage-builds)
27. [Elegir Base Image](#27-elegir-base-image)

**Parte VI — Buenas Prácticas y Producción**
28. [Optimización de Imágenes](#28-optimización-de-imágenes)
29. [Seguridad de Imágenes](#29-seguridad-de-imágenes)
30. [Anti-Patrones y Errores Comunes](#30-anti-patrones-y-errores-comunes)

**Parte VII — Ejemplos y Ejercicios**
31. [Ejemplo 1 — Nginx Custom](#31-ejemplo-1--nginx-custom)
32. [Ejemplo 2 — Node.js App](#32-ejemplo-2--nodejs-app)
33. [Ejemplo 3 — Python App Multi-Stage](#33-ejemplo-3--python-app-multi-stage)
34. [Ejemplo 4 — CMD vs ENTRYPOINT](#34-ejemplo-4--cmd-vs-entrypoint)
35. [Ejemplo 5 — Entrypoint Script Pattern](#35-ejemplo-5--entrypoint-script-pattern)

---

# PARTE I — FUNDAMENTOS DE IMÁGENES

---

# 1. ¿Qué es una Imagen Docker?

## 1.1 Definición

```text
Una imagen Docker es un paquete inmutable, de solo lectura, que contiene
todo lo necesario para ejecutar una aplicación:

  → Binarios de la aplicación (tu código compilado o interpretado)
  → Runtime (Node.js, Python, Java JRE, etc.)
  → Librerías y dependencias del sistema
  → Variables de entorno
  → Metadatos (CMD, EXPOSE, WORKDIR, etc.)
  → Archivos de configuración

Lo que una imagen NO es:
  → NO es un sistema operativo completo
  → NO tiene kernel (comparte el del host)
  → NO tiene kernel modules (drivers)
  → NO tiene systemd ni servicios en background
  → NO tiene SSH server (no se accede por SSH)

Una imagen puede ser tan pequeña como un solo binario estático
(~1 MB para un binario Go compilado en scratch) o tan grande
como un entorno completo con compilador, librerías y tools (~1 GB
para una imagen con gcc + headers de desarrollo).
```

## 1.2 Definición formal (OCI)

```text
Según la especificación OCI (Open Container Initiative):

  "Una imagen es una colección ORDENADA de cambios al root filesystem
   y los parámetros de ejecución correspondientes para su uso dentro
   de un container runtime."

Desglosado:
  → "colección ordenada de cambios" = capas apiladas (layers)
  → "root filesystem" = el / del contenedor
  → "parámetros de ejecución" = CMD, ENV, USER, WORKDIR, etc.
  → "container runtime" = runc, containerd, etc.
```

---

# 2. Image vs Container

## 2.1 La relación

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   IMAGE (plantilla inmutable)                                │
│   ┌────────────────────────┐                                 │
│   │  Layer 4: COPY app     │  ← Código de la app             │
│   │  Layer 3: RUN npm      │  ← Dependencias                │
│   │  Layer 2: RUN apt      │  ← Paquetes del sistema        │
│   │  Layer 1: FROM ubuntu  │  ← Base image                  │
│   └────────────────────────┘                                 │
│              │                                               │
│              │  docker container run                         │
│              ▼                                               │
│   CONTAINER A        CONTAINER B        CONTAINER C          │
│   ┌──────────┐       ┌──────────┐       ┌──────────┐        │
│   │ R/W Layer│       │ R/W Layer│       │ R/W Layer│        │
│   ├──────────┤       ├──────────┤       ├──────────┤        │
│   │          │       │          │       │          │        │
│   │  IMAGE   │       │  IMAGE   │       │  IMAGE   │        │
│   │  LAYERS  │       │  LAYERS  │       │  LAYERS  │        │
│   │ (shared) │       │ (shared) │       │ (shared) │        │
│   └──────────┘       └──────────┘       └──────────┘        │
│                                                              │
│   Cada contenedor tiene su propia capa de escritura (R/W),   │
│   pero COMPARTEN las mismas capas de la imagen (read-only).  │
│   Esto es extremadamente eficiente en disco y memoria.       │
└──────────────────────────────────────────────────────────────┘

Analogía:
  Imagen     = Clase (definición, plantilla)
  Contenedor = Instancia (objeto creado a partir de la clase)

  Puedes crear múltiples instancias de la misma clase.
  Cada instancia tiene su propio estado, pero comparte la definición.
```

---

# 3. Union Filesystem y Capas

## 3.1 ¿Qué es un Union Filesystem?

```text
Un Union Filesystem (UnionFS) permite combinar múltiples directorios
(llamados "branches" o "layers") en un solo filesystem unificado.

Docker usa OverlayFS (overlay2) como storage driver por defecto.

Cada instrucción en un Dockerfile que modifica el filesystem crea una
nueva capa. Las capas se apilan unas sobre otras:

  ┌──────────────────────────────────────────────────┐
  │  Layer 5: COPY . /app            (tu código)     │  ← Más reciente
  │  Layer 4: RUN npm install        (node_modules)  │
  │  Layer 3: COPY package.json      (package.json)  │
  │  Layer 2: RUN apt-get install    (curl, vim)     │
  │  Layer 1: FROM node:20-slim      (base image)    │  ← Más antigua
  └──────────────────────────────────────────────────┘
  ▲                                                  ▲
  │  Cada capa es INMUTABLE                          │
  │  Una vez creada, NUNCA se modifica               │
  │  Identificada por un SHA256 hash único           │
  └──────────────────────────────────────────────────┘
```

## 3.2 Propiedades clave de las capas

```text
1. INMUTABILIDAD
   → Una capa, una vez creada, nunca cambia.
   → Si actualizas un paquete, se crea una NUEVA capa con el cambio.
   → La capa anterior sigue existiendo (a menos que se limpie).

2. COMPARTICIÓN
   → Si 10 contenedores usan la misma imagen, las capas de la imagen
     se almacenan UNA sola vez en disco.
   → Si 5 imágenes comparten la misma base (node:20), esa base se
     descarga y almacena una sola vez.

3. CACHE
   → Docker cachea cada capa por su hash SHA256.
   → Si una instrucción del Dockerfile y su contexto no cambiaron,
     Docker reutiliza la capa cacheada en lugar de reconstruirla.
   → Esto hace que los builds sean mucho más rápidos.

4. INCREMENTAL PUSH/PULL
   → Al hacer push o pull, solo se transfieren las capas que faltan.
   → Si el registry ya tiene las capas de la base image, solo sube
     las capas nuevas (tu código + dependencias).
```

## 3.3 Ver las capas de una imagen

```bash
# Mostrar el historial de capas:
docker image history nginx

# IMAGE       CREATED       CREATED BY                                    SIZE
# 2d389...    2 weeks ago   CMD ["nginx" "-g" "daemon off;"]              0B
# <missing>   2 weeks ago   STOPSIGNAL SIGQUIT                            0B
# <missing>   2 weeks ago   EXPOSE map[80/tcp:{}]                         0B
# <missing>   2 weeks ago   ENTRYPOINT ["/docker-entrypoint.sh"]          0B
# <missing>   2 weeks ago   COPY file:xxx in /docker-entrypoint.d/...     4.62kB
# <missing>   2 weeks ago   RUN /bin/sh -c set -x && apt-get update...   61.2MB
# <missing>   2 weeks ago   ENV NGINX_VERSION=1.25.3                      0B
# <missing>   5 weeks ago   /bin/sh -c #(nop)  CMD ["bash"]              0B
# <missing>   5 weeks ago   ADD file:xxx in /                            77.8MB

# Notas:
# → SIZE = 0B para instrucciones de metadata (CMD, ENV, EXPOSE, etc.)
# → SIZE > 0 para instrucciones que modifican el filesystem (RUN, COPY, ADD)
# → <missing> en IMAGE es normal — solo la capa superior tiene ID visible

# Con formato detallado:
docker image history --no-trunc nginx
```

---

# 4. Copy-on-Write (COW)

## 4.1 ¿Cómo funciona?

```text
Cuando un contenedor necesita MODIFICAR un archivo que existe en una
capa de solo lectura de la imagen, Docker usa Copy-on-Write:

  1. El contenedor lee el archivo de la capa de la imagen (normal, sin copia)
  2. El contenedor quiere ESCRIBIR en el archivo
  3. Docker COPIA el archivo desde la capa de la imagen a la capa R/W
     del contenedor
  4. La escritura se aplica a la copia en la capa R/W
  5. Las lecturas posteriores ven la versión modificada (la copia)
  6. El archivo original en la capa de la imagen NO se toca

  ┌──────────────────────────────────────────────────────┐
  │  Container R/W Layer                                  │
  │  ┌───────────────────┐                               │
  │  │ nginx.conf (mod)  │  ← Copia modificada           │
  │  └───────────────────┘                               │
  ├──────────────────────────────────────────────────────┤
  │  Image Layer (read-only)                              │
  │  ┌───────────────────┐                               │
  │  │ nginx.conf (orig) │  ← Original intacto           │
  │  └───────────────────┘                               │
  └──────────────────────────────────────────────────────┘

Consecuencias:
  → La primera escritura a un archivo grande es lenta (hay que copiarlo)
  → Las lecturas son rápidas (directo de la capa de imagen)
  → Al eliminar un contenedor, su capa R/W se borra. Los datos se pierden.
  → Por eso los datos que deben persistir van en VOLÚMENES (ver Volumes.md)
```

---

# PARTE II — COMANDOS DE IMÁGENES

---

# 5. Gestión de Imágenes (CLI)

## 5.1 Comandos principales

```text
┌──────────────────────────────────────────┬───────────────────────────────────────────┐
│  Comando                                 │  Descripción                              │
├──────────────────────────────────────────┼───────────────────────────────────────────┤
│  docker image ls                         │  Listar imágenes locales.                 │
│    -a                                    │  Incluir imágenes intermedias (capas).    │
│    -q                                    │  Solo IDs.                                │
│    --filter dangling=true                │  Solo imágenes sin tag (dangling).        │
│    --format "table {{.Repository}}       │  Formato personalizado.                   │
│       \t{{.Tag}}\t{{.Size}}"             │                                           │
│                                          │                                           │
│  docker image pull NAME[:TAG]            │  Descargar imagen del registry.           │
│    NAME:TAG                              │  Con tag específico: nginx:1.25           │
│    NAME@sha256:DIGEST                    │  Con digest exacto (inmutable).           │
│                                          │                                           │
│  docker image push NAME[:TAG]            │  Subir imagen al registry.                │
│                                          │  Solo sube las capas que faltan.          │
│                                          │                                           │
│  docker image build -t NAME:TAG PATH     │  Construir imagen desde Dockerfile.       │
│    -f Dockerfile.dev                     │  Dockerfile específico.                   │
│    --no-cache                            │  Sin cache (reconstruir todo).            │
│    --build-arg KEY=VAL                   │  Pasar ARG al build.                      │
│    --target STAGE                        │  Construir hasta un stage específico.     │
│    --platform linux/amd64                │  Arquitectura destino.                    │
│                                          │                                           │
│  docker image rm IMAGE [IMAGE...]        │  Eliminar imagen(es).                     │
│    -f                                    │  Forzar (incluso si hay contenedores).    │
│                                          │                                           │
│  docker image tag SRC:TAG DST:TAG        │  Crear un nuevo tag para una imagen.      │
│                                          │  No crea copia — ambos tags apuntan al   │
│                                          │  mismo Image ID.                          │
│                                          │                                           │
│  docker image save -o FILE IMAGE         │  Exportar imagen a archivo .tar.          │
│  docker image load -i FILE               │  Importar imagen desde archivo .tar.      │
└──────────────────────────────────────────┴───────────────────────────────────────────┘
```

## 5.2 Aliases comunes

```bash
docker images           # = docker image ls
docker pull nginx       # = docker image pull nginx
docker build .          # = docker image build .
docker rmi nginx        # = docker image rm nginx
docker tag a:1 b:2      # = docker image tag a:1 b:2
```

---

# 6. Inspección de Imágenes

## 6.1 docker image inspect

```bash
docker image inspect nginx

# Devuelve JSON completo con:
#   → Id (SHA256 completo)
#   → RepoTags (tags asociados)
#   → Created (fecha de creación)
#   → Config: Cmd, Entrypoint, Env, ExposedPorts, WorkingDir, User, Volumes
#   → RootFS: capas (array de SHA256)
#   → Architecture, Os

# Extraer campos específicos:
docker image inspect nginx --format '{{.Config.Cmd}}'
# [nginx -g daemon off;]

docker image inspect nginx --format '{{.Config.ExposedPorts}}'
# map[80/tcp:{}]

docker image inspect nginx --format '{{json .Config.Env}}' | jq
# ["PATH=/usr/local/sbin:...", "NGINX_VERSION=1.25.3"]

docker image inspect nginx --format '{{.RootFS.Layers}}'
# Muestra los SHA256 de cada capa

docker image inspect nginx --format '{{.Architecture}}'
# amd64
```

## 6.2 docker image history

```bash
docker image history nginx
docker image history --no-trunc nginx   # Sin truncar comandos

# Cada línea muestra:
#   IMAGE    = ID de la capa (o <missing> para capas intermedias)
#   CREATED  = Cuándo se creó la capa
#   CREATED BY = La instrucción del Dockerfile que la generó
#   SIZE     = Tamaño que agrega esta capa
#   COMMENT  = Notas adicionales

# Útil para:
# → Entender cómo se construyó una imagen
# → Identificar capas grandes que se pueden optimizar
# → Verificar que no hay secrets embebidos en capas
```

---

# 7. Limpieza y Espacio en Disco

## 7.1 Verificar uso de disco

```bash
docker system df
# TYPE          TOTAL   ACTIVE   SIZE      RECLAIMABLE
# Images        15      3        4.2GB     3.1GB (73%)
# Containers    5       2        150MB     50MB  (33%)
# Local Volumes 8       3        2.1GB     800MB (38%)
# Build Cache   25      0        1.5GB     1.5GB (100%)

docker system df -v    # Detallado, por imagen/contenedor/volumen
```

## 7.2 Limpieza

```bash
# Imágenes dangling (sin tag, residuos de builds):
docker image prune
# ¿Las capas intermedias de un build fallido? → dangling images

# TODAS las imágenes no usadas por ningún contenedor:
docker image prune -a
# ⚠️ Elimina imágenes que no tienen ningún contenedor (ni running ni stopped)

# Con filtro de antigüedad:
docker image prune -a --filter "until=168h"   # Más de 7 días

# Limpieza total del sistema:
docker system prune         # containers stopped + networks unused + dangling images + build cache
docker system prune -a      # + todas las imágenes no usadas
docker system prune -a --volumes   # + volúmenes sin montar (⚠️ destructivo)
```

## 7.3 ¿Qué es una dangling image?

```text
Una dangling image es una imagen sin tag (aparece como <none>:<none>).

¿Cómo se crean?
  1. Reconstruyes una imagen con el mismo tag:
     docker build -t myapp:latest .   ← la imagen vieja pierde el tag
  2. Pulls de una versión actualizada con el mismo tag:
     docker pull nginx:latest         ← la versión vieja pierde el tag

Las dangling images ocupan espacio pero no se usan.
docker image prune las elimina.

Ver dangling images:
  docker image ls --filter dangling=true
  docker image ls -f "dangling=true" -q
```

---

# PARTE III — TAGS Y DOCKER HUB

---

# 8. Image Tags

## 8.1 ¿Qué es un tag?

```text
Un tag es una ETIQUETA que apunta a un Image ID específico (SHA256).
No es una copia de la imagen — es un puntero, como un alias.

  myapp:v1.0.0  ──┐
  myapp:v1.0    ──┤──▶  Image ID: sha256:a3b2c1d4e5f6...
  myapp:v1      ──┤
  myapp:latest  ──┘

Todos estos tags apuntan a la MISMA imagen. Cero duplicación en disco.

Conceptos clave:
  → Un tag NO es un ID. El ID es inmutable (SHA256 del contenido).
    El tag es mutable (puede apuntar a otro ID en cualquier momento).
  → "latest" NO significa "la más reciente". Es simplemente el tag
    por defecto si no especificas uno. Puede apuntar a cualquier versión.
  → Múltiples tags pueden apuntar al mismo Image ID.
  → Un Image ID puede tener cero tags (dangling image).
```

## 8.2 Convenciones de versionado (Semantic Versioning)

```text
Formato: MAJOR.MINOR.PATCH

  nginx:1.25.3   → versión exacta (MAJOR.MINOR.PATCH)
  nginx:1.25     → latest patch de 1.25.x
  nginx:1        → latest minor+patch de 1.x.x
  nginx:latest   → la que el mantenedor decidió (no necesariamente la más nueva)

  node:20.10.0           → versión exacta
  node:20.10.0-alpine    → versión exacta + variante (Alpine)
  node:20.10.0-slim      → versión exacta + variante (Debian slim)
  node:20-alpine         → latest 20.x en Alpine
  node:lts               → versión LTS actual
  node:current           → versión current

Reglas para producción:
  ❌ FROM node:latest       ← puede cambiar en cualquier momento
  ❌ FROM node              ← igual que :latest
  ⚠️ FROM node:20           ← puede cambiar el minor/patch
  ✅ FROM node:20.10.0      ← exacta, reproducible
  ✅ FROM node:20.10.0-slim ← exacta + mínima
```

## 8.3 Crear tags

```bash
# Tag una imagen existente con un nuevo nombre/tag:
docker image tag nginx:latest myuser/nginx-custom:v1.0

# Esto NO crea una copia. Ambos tags apuntan al mismo Image ID.
docker image ls
# REPOSITORY              TAG      IMAGE ID       SIZE
# nginx                   latest   2d389...       187MB
# myuser/nginx-custom     v1.0     2d389...       187MB  ← mismo ID

# Múltiples tags para deployment:
docker image tag myapp:latest myapp:v2.1.0
docker image tag myapp:latest myapp:v2.1
docker image tag myapp:latest myapp:v2

# Ahora push los 4 tags (solo sube capas una vez):
docker image push myapp:latest
docker image push myapp:v2.1.0
docker image push myapp:v2.1
docker image push myapp:v2
```

---

# 9. Naming Convention y Registries

## 9.1 Formato de nombres

```text
[REGISTRY/][USER/]REPOSITORY[:TAG|@DIGEST]

Ejemplos:

  nginx
  │
  └── Imagen oficial de Docker Hub.
      Nombre completo: docker.io/library/nginx:latest

  myuser/myapp:v2.1
  │       │      │
  │       │      └── Tag
  │       └── Repositorio
  └── Usuario/organización en Docker Hub

  ghcr.io/myorg/myapp:v2.1
  │        │      │     │
  │        │      │     └── Tag
  │        │      └── Repositorio
  │        └── Organización
  └── Registry (GitHub Container Registry)

  123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v2.1
  │                                           │     │
  │                                           │     └── Tag
  │                                           └── Repositorio
  └── Registry (AWS ECR)

Imágenes oficiales:
  → Viven en el namespace "library/" de Docker Hub
  → No necesitan prefijo de usuario: nginx, postgres, node
  → Son curadas, revisadas y mantenidas
  → Documentación oficial en hub.docker.com/_/nginx
```

## 9.2 Digest (SHA256) — Referencia inmutable

```bash
# Un tag puede cambiar (apuntar a otra imagen).
# Un digest NUNCA cambia — es el SHA256 del contenido.

docker image pull nginx@sha256:abc123def456...

# Ver el digest de una imagen:
docker image inspect nginx --format '{{.RepoDigests}}'
# [nginx@sha256:abc123def456...]

# En producción ultra-segura, usar digest en lugar de tag:
# FROM nginx@sha256:abc123def456...
# Garantiza que SIEMPRE usas exactamente esa imagen.
```

---

# 10. Push y Pull

## 10.1 Pull

```bash
docker image pull nginx              # :latest implícito
docker image pull nginx:1.25.3       # Tag específico
docker image pull nginx@sha256:...   # Digest específico

# Pull solo descarga las capas que NO tienes localmente.
# Si ya tienes la base image (debian:bookworm-slim), no la re-descarga.

# Pull de múltiples plataformas:
docker image pull --platform linux/arm64 nginx:1.25.3
```

## 10.2 Push

```bash
# 1. Tag tu imagen con el formato del registry:
docker image tag myapp:latest myuser/myapp:v1.0

# 2. Login al registry:
docker login                               # Docker Hub
docker login ghcr.io                       # GitHub
echo "$TOKEN" | docker login --password-stdin ghcr.io  # CI/CD

# 3. Push:
docker image push myuser/myapp:v1.0

# Solo sube las capas que el registry NO tiene.
# Si tu imagen está basada en node:20-slim y esas capas ya están
# en el registry, solo sube tus capas personalizadas.

# Push all tags:
docker image push myuser/myapp --all-tags
```

---

# PARTE IV — DOCKERFILE: CONSTRUIR IMÁGENES

---

# 11. ¿Qué es un Dockerfile?

## 11.1 Definición

```text
Un Dockerfile es un archivo de texto con instrucciones ordenadas que
Docker ejecuta secuencialmente para construir una imagen.

Cada instrucción crea una capa (o metadato) en la imagen resultante.
El resultado es una imagen reproducible: dado el mismo Dockerfile y
contexto, obtienes la misma imagen.

Nombre por defecto: Dockerfile (sin extensión)
Alternativas: Dockerfile.dev, Dockerfile.prod, build.Dockerfile
Usar con: docker build -f Dockerfile.dev .
```

## 11.2 Anatomía de un build

```text
docker image build -t myapp:v1 .
                              │
                              └── Build context (directorio actual)

  1. Docker envía el build context al daemon
     (todo el directorio, excepto lo que está en .dockerignore)

  2. Docker lee el Dockerfile línea por línea

  3. Por cada instrucción:
     a. ¿Hay cache de esta capa? → Sí: reusar. No: ejecutar.
     b. Crear una capa temporal (container intermedio)
     c. Ejecutar la instrucción dentro del container
     d. Commit del filesystem como nueva capa
     e. Eliminar el container intermedio

  4. Resultado: imagen final con todas las capas apiladas

  Build context → Dockerfile → Layer 1 → Layer 2 → ... → Image
```

---

# 12. Instrucciones del Dockerfile

## 12.1 Tabla de referencia completa

```text
┌───────────────┬──────────────────────────────────────────────────────────┐
│  Instrucción  │  Descripción                                             │
├───────────────┼──────────────────────────────────────────────────────────┤
│  FROM         │  Base image. Primera instrucción obligatoria.            │
│  RUN          │  Ejecutar comando durante el build. Crea capa.          │
│  COPY         │  Copiar archivos del build context al filesystem.       │
│  ADD          │  Como COPY + descomprime .tar + acepta URLs.            │
│  WORKDIR      │  Establecer directorio de trabajo. Crea si no existe.   │
│  ENV          │  Definir variable de entorno (persiste en runtime).      │
│  ARG          │  Variable de build-time (solo durante el build).         │
│  EXPOSE       │  Documentar puertos. NO abre puertos.                   │
│  CMD          │  Comando por defecto al iniciar el contenedor.          │
│  ENTRYPOINT   │  Ejecutable principal. CMD se pasa como argumentos.     │
│  USER         │  Usuario con el que se ejecutan las instrucciones.      │
│  VOLUME       │  Declarar punto de montaje para datos persistentes.     │
│  HEALTHCHECK  │  Comando para verificar salud del contenedor.           │
│  LABEL        │  Metadatos key=value (autor, versión, licencia).        │
│  STOPSIGNAL   │  Señal para detener el contenedor (default: SIGTERM).   │
│  SHELL        │  Shell por defecto para instrucciones de forma shell.   │
│  ONBUILD      │  Instrucción diferida: se ejecuta cuando otra imagen    │
│               │  usa esta como base (FROM).                             │
├───────────────┼──────────────────────────────────────────────────────────┤
│  Crean capa:  │  FROM, RUN, COPY, ADD                                   │
│  Solo metadata│  CMD, ENTRYPOINT, ENV, ARG, EXPOSE, WORKDIR, USER,     │
│               │  VOLUME, HEALTHCHECK, LABEL, STOPSIGNAL, SHELL, ONBUILD│
└───────────────┴──────────────────────────────────────────────────────────┘
```

---

# 13. FROM — La Base Image

## 13.1 Uso

```dockerfile
FROM ubuntu:22.04
# Base image de Ubuntu 22.04 LTS

FROM node:20-slim
# Node.js 20.x sobre Debian slim

FROM python:3.12-alpine
# Python 3.12 sobre Alpine Linux (mínimo)

FROM scratch
# Imagen completamente vacía — para binarios estáticos (Go, Rust)
```

## 13.2 Herencia

```text
Cuando usas FROM, heredas TODO de la imagen base:
  → Filesystem (todos los archivos y directorios)
  → ENV (variables de entorno)
  → WORKDIR
  → CMD / ENTRYPOINT
  → EXPOSE
  → USER
  → VOLUME

Puedes SOBREESCRIBIR cualquier cosa heredada con tu propia instrucción.
No necesitas re-declarar lo que ya está en la base.

Ejemplo:
  FROM nginx:latest
  COPY index.html /usr/share/nginx/html/
  # No necesitas CMD ni EXPOSE — nginx los define en su Dockerfile
```

## 13.3 Multi-FROM (Multi-Stage)

```dockerfile
# Stage 1: build
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: production (imagen final)
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# La imagen final solo tiene nginx + los archivos compilados
# NO tiene node, npm, ni node_modules → mucho más pequeña y segura
```

---

# 14. RUN — Ejecutar Comandos

## 14.1 Dos formas

```dockerfile
# Shell form (ejecuta en /bin/sh -c):
RUN apt-get update && apt-get install -y curl

# Exec form (ejecuta directamente, sin shell):
RUN ["apt-get", "update"]
```

## 14.2 Buenas prácticas para RUN

```dockerfile
# ❌ MAL — cada RUN crea una capa:
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN rm -rf /var/lib/apt/lists/*

# ✅ BIEN — combinar con && y limpiar en la misma capa:
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       vim \
    && rm -rf /var/lib/apt/lists/*

# ¿Por qué?
# → Menos capas = imagen más pequeña y eficiente
# → La limpieza en la MISMA capa elimina realmente los archivos
# → Si limpias en otra capa, los archivos siguen en la capa anterior
#   (las capas son inmutables, eliminar en otra capa solo "oculta")

# --no-install-recommends evita paquetes sugeridos innecesarios
# rm -rf /var/lib/apt/lists/* elimina el cache de APT
```

## 14.3 RUN con cache mounts (BuildKit)

```dockerfile
# syntax=docker/dockerfile:1
# BuildKit cache mount — el cache persiste entre builds:
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y curl
```

---

# 15. COPY y ADD — Agregar Archivos

## 15.1 COPY

```dockerfile
COPY archivo.txt /app/archivo.txt          # Archivo específico
COPY . /app/                               # Todo el build context
COPY package.json package-lock.json /app/  # Múltiples archivos
COPY --chown=node:node . /app/             # Con permisos
COPY --from=builder /app/dist /usr/share/nginx/html  # Desde otro stage
```

## 15.2 ADD

```dockerfile
ADD archivo.tar.gz /app/      # Auto-descomprime archivos .tar, .gz, .bz2
ADD https://example.com/f /app/  # Descarga desde URL (no recomendado)
```

## 15.3 COPY vs ADD

```text
┌─────────────────────────┬──────────────────────────────────────────────┐
│  COPY                   │  ADD                                         │
├─────────────────────────┼──────────────────────────────────────────────┤
│  Copia archivos del     │  Lo mismo que COPY, MÁS:                    │
│  build context al       │  → Auto-descomprime .tar/.gz/.bz2/.xz      │
│  filesystem de la       │  → Acepta URLs como fuente                  │
│  imagen.                │                                              │
├─────────────────────────┼──────────────────────────────────────────────┤
│  ✅ RECOMENDADO         │  ⚠️ Solo usar cuando necesitas auto-extract  │
│  Comportamiento claro   │  El auto-extract puede ser confuso          │
│  y predecible.          │  Las URLs no usan cache y no se limpian     │
└─────────────────────────┴──────────────────────────────────────────────┘

Regla: usar COPY siempre, a menos que necesites la auto-descompresión de ADD.
Para descargar archivos, usar RUN curl/wget (más controlado).
```

---

# 16. WORKDIR — Directorio de Trabajo

## 16.1 Uso

```dockerfile
WORKDIR /app
# Establece /app como directorio de trabajo para todas las instrucciones
# que siguen: RUN, CMD, ENTRYPOINT, COPY, ADD.
# Si /app no existe, Docker lo CREA automáticamente.

WORKDIR /app/src
# Se puede usar múltiples veces. Soporta rutas relativas:
# Si WORKDIR actual es /app, entonces WORKDIR src → /app/src

# ❌ MAL — usar RUN cd:
RUN cd /app && npm install
# "cd" solo afecta ESE RUN. El siguiente RUN vuelve a /.

# ✅ BIEN — usar WORKDIR:
WORKDIR /app
RUN npm install
# npm install se ejecuta en /app. Todas las instrucciones siguientes también.
```

---

# 17. ENV y ARG — Variables

## 17.1 ENV — Variables de entorno (runtime)

```dockerfile
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_HOME=/opt/app

# Se pueden usar en instrucciones posteriores:
WORKDIR $APP_HOME
RUN echo "Running in $NODE_ENV mode"

# ENV persiste en el contenedor final:
# docker exec container env → muestra NODE_ENV=production

# Overriding en runtime:
# docker run -e NODE_ENV=development myapp
# docker run --env-file .env myapp
```

## 17.2 ARG — Variables de build-time

```dockerfile
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-slim

ARG BUILD_DATE
ARG GIT_COMMIT
LABEL build-date=$BUILD_DATE
LABEL git-commit=$GIT_COMMIT

# ARG solo existe durante el build, NO en el contenedor final.
# Pasar valores en build:
# docker build --build-arg NODE_VERSION=18 --build-arg GIT_COMMIT=$(git rev-parse HEAD) .
```

## 17.3 ENV vs ARG

```text
┌────────────────────────────┬──────────────────────┬──────────────────────┐
│  Característica            │  ENV                 │  ARG                 │
├────────────────────────────┼──────────────────────┼──────────────────────┤
│  Disponible en build       │  ✅ Sí               │  ✅ Sí               │
│  Disponible en runtime     │  ✅ Sí (persiste)    │  ❌ No               │
│  Override en runtime       │  docker run -e       │  N/A                 │
│  Override en build         │  No directamente     │  --build-arg         │
│  Antes de FROM             │  ❌ No               │  ✅ Sí (solo para    │
│                            │                      │  FROM)               │
│  Crea capa                 │  Solo metadata       │  Solo metadata       │
│  Caso de uso               │  Config de la app    │  Versiones, flags    │
│                            │  en runtime          │  de compilación      │
└────────────────────────────┴──────────────────────┴──────────────────────┘

⚠️ NUNCA usar ENV ni ARG para secrets (passwords, API keys).
   → Los ARG aparecen en docker image history
   → Los ENV son visibles con docker inspect
   → Para secrets: usar BuildKit secret mounts o Docker secrets
```

---

# 18. EXPOSE — Documentar Puertos

## 18.1 Uso

```dockerfile
EXPOSE 80
EXPOSE 443
EXPOSE 3000/tcp
EXPOSE 5000/udp
```

## 18.2 Lo que EXPOSE hace y NO hace

```text
✅ EXPOSE hace:
  → Documenta qué puertos usa la aplicación dentro del contenedor
  → Sirve como metadato para otros developers y herramientas
  → docker container inspect muestra los puertos expuestos
  → docker run -P (mayúscula) mapea TODOS los EXPOSE a puertos aleatorios del host

❌ EXPOSE NO hace:
  → NO abre puertos en el host
  → NO permite acceso externo
  → NO reemplaza -p en docker run
  → Es SOLO documentación — como un comentario ejecutable

Para acceso externo, SIEMPRE necesitas -p en docker run:
  docker run -p 8080:80 myapp     ← Esto sí abre el puerto
```

---

# 19. CMD y ENTRYPOINT — Proceso Principal

## 19.1 CMD — Comando por defecto

```dockerfile
# Exec form (RECOMENDADO — no invoca shell):
CMD ["node", "server.js"]
CMD ["nginx", "-g", "daemon off;"]
CMD ["python", "app.py"]

# Shell form (invoca /bin/sh -c):
CMD node server.js
CMD nginx -g "daemon off;"

# CMD define el comando que se ejecuta cuando el contenedor inicia.
# Puede ser OVERRIDDEN completamente por docker run:
#   docker run myapp node test.js   ← reemplaza el CMD completo
```

## 19.2 ENTRYPOINT — Ejecutable fijo

```dockerfile
# Exec form:
ENTRYPOINT ["node"]
# Ahora CMD se pasa como ARGUMENTOS a ENTRYPOINT:
CMD ["server.js"]

# Al ejecutar:
#   docker run myapp              → node server.js
#   docker run myapp test.js      → node test.js (CMD override)
#   docker run myapp --version    → node --version

# ENTRYPOINT NO se reemplaza fácilmente con docker run.
# Para override: docker run --entrypoint /bin/bash myapp
```

## 19.3 CMD + ENTRYPOINT juntos

```text
La combinación ENTRYPOINT + CMD es un patrón poderoso:

  ENTRYPOINT = el ejecutable fijo (el "verbo")
  CMD        = los argumentos por defecto (el "complemento")

  ┌─────────────────────────────┬──────────────────────────────┐
  │  Dockerfile                 │  docker run                  │
  ├─────────────────────────────┼──────────────────────────────┤
  │  ENTRYPOINT ["sleep"]       │                              │
  │  CMD ["10"]                 │                              │
  │                             │  docker run myapp            │
  │                             │  → sleep 10                  │
  │                             │                              │
  │                             │  docker run myapp 60         │
  │                             │  → sleep 60  (CMD override)  │
  │                             │                              │
  │                             │  docker run myapp --help     │
  │                             │  → sleep --help              │
  └─────────────────────────────┴──────────────────────────────┘
```

## 19.4 Shell form vs Exec form

```text
┌──────────────────────────────┬───────────────────────────────────────┐
│  Shell form                  │  Exec form                            │
│  CMD command arg1 arg2       │  CMD ["command", "arg1", "arg2"]      │
├──────────────────────────────┼───────────────────────────────────────┤
│  Se ejecuta en /bin/sh -c    │  Se ejecuta DIRECTAMENTE (no shell)   │
│  El proceso es PID 1: sh     │  El proceso es PID 1: tu app         │
│  Tu app es un hijo de sh     │  Tu app recibe señales directamente  │
│  Variable expansion ($VAR)   │  Sin variable expansion              │
│                              │  (usar ENV para variables)           │
├──────────────────────────────┼───────────────────────────────────────┤
│  ⚠️ Problemas con señales:   │  ✅ Recibe SIGTERM correctamente     │
│  sh no reenvía SIGTERM       │  Graceful shutdown funciona          │
│  docker stop puede tardar    │                                       │
│  10s y hacer SIGKILL         │                                       │
└──────────────────────────────┴───────────────────────────────────────┘

⚡ REGLA: SIEMPRE usar exec form para CMD y ENTRYPOINT.
   Shell form solo si necesitas variable expansion o pipes.
```

---

# 20. USER — Seguridad

## 20.1 Uso

```dockerfile
# Crear usuario sin privilegios:
RUN groupadd -r appuser && useradd -r -g appuser appuser

# O en Alpine:
RUN addgroup -S appuser && adduser -S -G appuser appuser

# Cambiar al usuario para las instrucciones que siguen:
USER appuser

# Todo lo que sigue (RUN, CMD, ENTRYPOINT, COPY con --chown)
# se ejecuta como appuser, NO como root.

WORKDIR /home/appuser/app
COPY --chown=appuser:appuser . .
CMD ["node", "server.js"]
```

## 20.2 Por qué importa

```text
Por defecto, los contenedores se ejecutan como root.
Esto es un riesgo de seguridad:

  → Si un atacante explota una vulnerabilidad en tu app,
    tiene acceso root dentro del contenedor.
  → Con ciertos misconfigs (--privileged, no user namespaces),
    root en el contenedor = root en el host.

Buenas prácticas:
  1. SIEMPRE definir USER en el Dockerfile
  2. Ejecutar como non-root (UID > 999)
  3. Para imágenes que necesitan root al inicio (nginx, postgres):
     → El entrypoint arranca como root, configura, y luego drop privileges
     → El proceso principal corre como non-root (www-data, postgres, etc.)
  4. En Kubernetes: securityContext.runAsNonRoot: true
```

---

# 21. VOLUME — Declarar Puntos de Montaje

## 21.1 Uso

```dockerfile
VOLUME /var/lib/mysql
VOLUME ["/data", "/config"]
```

## 21.2 ¿Qué hace VOLUME en el Dockerfile?

```text
VOLUME declara que un directorio contiene datos que deben sobrevivir
al ciclo de vida del contenedor.

Efecto:
  → Cuando se crea un contenedor SIN -v explícito, Docker crea
    automáticamente un volumen anónimo para cada VOLUME declarado.
  → Los datos en ese directorio se almacenan en el volumen, NO en
    la capa R/W del contenedor.
  → Los datos persisten incluso si el contenedor es eliminado
    (el volumen anónimo queda hasta que hagas docker volume prune).

⚠️ Limitaciones de VOLUME en Dockerfile:
  → No puedes especificar el path del host (solo el container path)
  → No puedes usar bind mounts desde el Dockerfile
  → Los cambios al directorio en instrucciones POSTERIORES del
    Dockerfile se IGNORAN (porque ya es un mount point)

Para control completo, usar -v en docker run:
  docker run -v mydata:/var/lib/mysql mysql
  docker run -v $(pwd)/data:/var/lib/mysql mysql

(Ver Volumes.md para más detalle)
```

---

# 22. HEALTHCHECK — Verificar Salud

## 22.1 Uso

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Opciones:
#   --interval=30s    → Cada cuánto verificar (default: 30s)
#   --timeout=10s     → Timeout para el check (default: 30s)
#   --start-period=5s → Gracia al inicio para que la app arranque (default: 0)
#   --retries=3       → Cuántos fallos consecutivos = unhealthy (default: 3)

# Exit codes:
#   0 = healthy
#   1 = unhealthy

# Deshabilitar health check heredado:
HEALTHCHECK NONE
```

## 22.2 Ejemplos por tipo de app

```dockerfile
# Web server:
HEALTHCHECK CMD curl -f http://localhost:80/ || exit 1

# API con endpoint de health:
HEALTHCHECK --interval=15s --timeout=5s \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

# Base de datos PostgreSQL:
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD pg_isready -U postgres || exit 1

# Sin curl ni wget (usa solo /dev/tcp de bash):
HEALTHCHECK --interval=30s --timeout=5s \
  CMD bash -c 'echo > /dev/tcp/localhost/8080' || exit 1
```

## 22.3 Ver el estado de salud

```bash
docker container ls
# CONTAINER ID   IMAGE   STATUS                    NAMES
# a3b2c1...      myapp   Up 5 min (healthy)        web
# d4e5f6...      myapp   Up 3 min (unhealthy)      api

docker container inspect web --format '{{.State.Health.Status}}'
# healthy

docker container inspect web --format '{{json .State.Health}}' | jq
# Muestra historial de checks con timestamps y outputs
```

---

# 23. LABEL, STOPSIGNAL, SHELL, ONBUILD

## 23.1 LABEL — Metadatos

```dockerfile
LABEL maintainer="dev@example.com"
LABEL version="2.1.0"
LABEL description="API server for production"
LABEL org.opencontainers.image.source="https://github.com/user/repo"
LABEL org.opencontainers.image.licenses="MIT"

# Ver labels:
docker image inspect myapp --format '{{json .Config.Labels}}' | jq
```

## 23.2 STOPSIGNAL

```dockerfile
STOPSIGNAL SIGQUIT
# Señal que Docker envía al proceso al hacer `docker stop`.
# Default: SIGTERM
# Nginx usa SIGQUIT para graceful shutdown.
```

## 23.3 SHELL

```dockerfile
SHELL ["/bin/bash", "-c"]
# Cambia el shell por defecto para instrucciones en "shell form".
# Default: ["/bin/sh", "-c"]
# Útil si necesitas features de bash (arrays, etc.) en RUN.
```

## 23.4 ONBUILD

```dockerfile
# En una imagen base (shared-base:latest):
ONBUILD COPY . /app
ONBUILD RUN npm install

# Estas instrucciones NO se ejecutan al construir shared-base.
# Se ejecutan cuando OTRA imagen usa shared-base como FROM:
#   FROM shared-base:latest
#   # → automáticamente: COPY . /app
#   # → automáticamente: RUN npm install

# Útil para crear imágenes "template" para equipos.
# ⚠️ Puede ser confuso — preferir documentar en lugar de usar ONBUILD.
```

---

# PARTE V — BUILD AVANZADO

---

# 24. Build Context y .dockerignore

## 24.1 ¿Qué es el build context?

```text
Cuando ejecutas docker build ., el "." es el build context.
Docker envía TODO el contenido de ese directorio al daemon.

  docker build -t myapp .
                        │
                        └── build context = directorio actual completo

Si tu directorio tiene 2 GB de node_modules, Docker envía 2 GB
al daemon ANTES de empezar a construir. Extremadamente lento.
```

## 24.2 .dockerignore

```text
El archivo .dockerignore funciona igual que .gitignore:
excluye archivos del build context.

Debe estar en la RAÍZ del build context (junto al Dockerfile).
```

```bash
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
*.md
!README.md
Dockerfile
docker-compose*.yml
.dockerignore
.vscode
.idea
coverage
dist
build
*.log
tmp
```

```text
¿Por qué es importante?

  1. VELOCIDAD: menos archivos enviados al daemon = build más rápido
  2. SEGURIDAD: evitar enviar .env, .git, secrets al build
  3. CACHE: los archivos excluidos no invalidan la cache de COPY
  4. TAMAÑO: node_modules no se envía (se instala con RUN npm install)

⚡ TODO proyecto Docker debe tener un .dockerignore.
```

---

# 25. Build Cache — Cómo Funciona

## 25.1 Mecánica del cache

```text
Docker cachea cada capa por su instrucción + contexto.

Para cada instrucción del Dockerfile, Docker pregunta:
  "¿Tengo una capa cacheada que coincida?"

  → FROM: ¿la imagen base ya existe localmente?
  → RUN:  ¿el string del comando es IDÉNTICO al de la cache?
          (Docker NO ejecuta el comando para verificar — solo compara strings)
  → COPY/ADD: ¿los archivos fuente tienen el mismo checksum?
              (Docker SÍ verifica el contenido de los archivos)

Si SÍ → usar cache (instantáneo, sin re-ejecutar)
Si NO → invalidar cache para esta capa Y TODAS LAS QUE SIGUEN

                     ┌───────────────┐
   Layer 1: FROM     │  ✅ Cache hit  │
                     ├───────────────┤
   Layer 2: RUN apt  │  ✅ Cache hit  │
                     ├───────────────┤
   Layer 3: COPY pkg │  ❌ Cache MISS │  ← archivo cambió
                     ├───────────────┤
   Layer 4: RUN npm  │  ❌ Rebuild    │  ← invalidado por L3
                     ├───────────────┤
   Layer 5: COPY .   │  ❌ Rebuild    │  ← invalidado por L3
                     └───────────────┘
```

## 25.2 Optimizar para cache

```dockerfile
# ❌ MAL — COPY . invalida TODO el cache cuando cualquier archivo cambia:
FROM node:20-slim
WORKDIR /app
COPY . .                    # ← Si index.js cambió, npm install se re-ejecuta
RUN npm install
CMD ["node", "server.js"]

# ✅ BIEN — Separar dependencias del código:
FROM node:20-slim
WORKDIR /app
COPY package.json package-lock.json ./   # ← Solo archivos de deps
RUN npm ci                               # ← Se cachea si package.json no cambió
COPY . .                                 # ← Código de la app (cambia frecuente)
CMD ["node", "server.js"]

# REGLA DE ORO:
#   Lo que cambia MENOS frecuentemente → ARRIBA del Dockerfile
#   Lo que cambia MÁS frecuentemente  → ABAJO del Dockerfile
#
#   FROM         ← casi nunca cambia
#   RUN apt      ← raramente cambia
#   COPY deps    ← cambia al agregar dependencias
#   RUN install  ← se re-ejecuta si deps cambian
#   COPY .       ← cambia en cada commit
#   CMD          ← nunca cambia
```

---

# 26. Multi-Stage Builds

## 26.1 El problema

```text
Para compilar una app necesitas: compilador, headers, devDependencies.
Para EJECUTAR la app solo necesitas: el binario/bundle + runtime.

Si construyes todo en un solo stage, la imagen final incluye
TODO: compilador + código fuente + devDependencies + build output.
Resultado: imagen innecesariamente grande y con superficie de ataque mayor.
```

## 26.2 La solución: multi-stage

```dockerfile
# ══════════════════════════════════════════
#  Stage 1: BUILD (imagen temporal, descartada)
# ══════════════════════════════════════════
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# Resultado: /app/dist/ contiene los archivos compilados

# ══════════════════════════════════════════
#  Stage 2: PRODUCTION (imagen final)
# ══════════════════════════════════════════
FROM node:20-slim AS production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 3000
USER node
CMD ["node", "dist/server.js"]

# Resultado final:
#   → NO tiene el código fuente
#   → NO tiene devDependencies (webpack, typescript, etc.)
#   → NO tiene el build toolchain
#   → Solo tiene: Node runtime + production deps + dist/
#   → Imagen mucho más pequeña y segura
```

## 26.3 Ejemplo: Go binary (imagen mínima)

```dockerfile
# Build stage
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

# Production: scratch = imagen VACÍA (0 bytes)
FROM scratch
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]

# Resultado: imagen de ~10 MB (solo el binario estático)
# Sin shell, sin package manager, sin NADA más → superficie de ataque mínima
```

## 26.4 Build un stage específico

```bash
# Solo construir hasta el stage "builder":
docker build --target builder -t myapp:build .

# Útil para:
# → Ejecutar tests en el stage de build
# → Extraer artefactos del stage de build
# → Debug del proceso de build
```

---

# 27. Elegir Base Image

## 27.1 Comparación de base images

```text
┌──────────────────┬────────────┬───────────────────────────────────────────┐
│  Base Image      │  Tamaño    │  Cuándo usar                             │
├──────────────────┼────────────┼───────────────────────────────────────────┤
│  ubuntu:22.04    │  ~77 MB    │  Necesitas apt + ecosistema Debian       │
│                  │            │  completo. Desarrollo, testing.          │
│                  │            │                                           │
│  debian:bookworm │  ~120 MB   │  Base estable. Muchas imágenes           │
│  -slim           │  ~80 MB    │  oficiales la usan internamente.         │
│                  │            │                                           │
│  alpine:3.19     │  ~7 MB     │  Mínima. Usa musl libc + busybox.       │
│                  │            │  Ideal para producción si la app         │
│                  │            │  es compatible.                          │
│                  │            │  ⚠️ Algunas apps C tienen issues con musl │
│                  │            │                                           │
│  node:20-slim    │  ~200 MB   │  Node.js sobre Debian slim. Balance     │
│  node:20-alpine  │  ~130 MB   │  entre tamaño y compatibilidad.         │
│                  │            │                                           │
│  python:3.12-slim│  ~150 MB   │  Python sobre Debian slim.              │
│  python:3.12-    │  ~60 MB    │  Alpine + Python puede ser lento de     │
│  alpine          │            │  construir (compilar C extensions).      │
│                  │            │                                           │
│  scratch         │  0 MB      │  Imagen vacía. Para binarios estáticos  │
│                  │            │  (Go, Rust). Sin shell, sin nada.       │
│                  │            │                                           │
│  distroless      │  ~20 MB    │  Google: runtime mínimo sin shell ni    │
│  (gcr.io/dist...)│            │  package manager. Más seguro que Alpine.│
│                  │            │  Variantes: java, python, nodejs, static│
│                  │            │  ⚠️ No se puede debug con exec (no shell)│
└──────────────────┴────────────┴───────────────────────────────────────────┘
```

## 27.2 ¿Por qué importa la base image?

```text
1. TAMAÑO → imagen más pequeña = pull más rápido, deploy más rápido
2. SEGURIDAD → menos paquetes = menos vulnerabilidades potenciales
3. COMPATIBILIDAD → musl (Alpine) vs glibc (Debian) puede causar issues
4. PACKAGE MANAGER → apt (Debian), apk (Alpine), yum/dnf (RHEL)
   → Si necesitas compilar paquetes C/C++ nativos, Debian es más confiable
   → Si solo necesitas runtime, Alpine o distroless es mejor

Regla de decisión:
  ¿Binario estático?           → scratch
  ¿Solo runtime, max seguridad? → distroless
  ¿Ligero y compatible?        → alpine
  ¿Compatibilidad máxima?      → debian-slim
  ¿Desarrollo/debug?           → ubuntu o debian full
```

---

# PARTE VI — BUENAS PRÁCTICAS Y PRODUCCIÓN

---

# 28. Optimización de Imágenes

## 28.1 Reducir tamaño

```text
1. Elegir base image mínima (Alpine, slim, distroless, scratch)

2. Multi-stage builds: separar build de runtime

3. Combinar RUN commands y limpiar en la misma capa:
   RUN apt-get update \
       && apt-get install -y --no-install-recommends pkg \
       && rm -rf /var/lib/apt/lists/*

4. Usar --no-install-recommends con apt

5. Limpiar caches de package managers:
   → apt:   rm -rf /var/lib/apt/lists/*
   → apk:   apk add --no-cache pkg
   → pip:   pip install --no-cache-dir -r requirements.txt
   → npm:   npm ci --omit=dev (en el stage final)
   → yarn:  yarn install --production && yarn cache clean

6. No incluir archivos innecesarios (.dockerignore)

7. Usar COPY selectivo en lugar de COPY . .
```

## 28.2 Reducir tiempo de build

```text
1. Optimizar orden del Dockerfile para máximo cache
   (menos frecuente arriba, más frecuente abajo)

2. Separar COPY de dependencias del COPY del código:
   COPY package.json → RUN npm install → COPY .

3. Usar .dockerignore para reducir build context

4. Usar BuildKit (DOCKER_BUILDKIT=1):
   → Paraleliza stages independientes
   → Cache mounts para package managers
   → Mejor manejo de secrets

5. Cache de layers entre CI runs:
   docker build --cache-from=myapp:latest .
```

---

# 29. Seguridad de Imágenes

## 29.1 Checklist de seguridad

```text
┌──────────────────────────────────────────────────────────────────┐
│  □  USER non-root en el Dockerfile                               │
│  □  Base image oficial y actualizada                             │
│  □  Tags fijos (nunca :latest en producción)                    │
│  □  Escanear vulnerabilidades antes de deploy:                  │
│     → docker scout cves myapp:latest                            │
│     → trivy image myapp:latest                                  │
│     → snyk container test myapp:latest                          │
│  □  No incluir secrets en la imagen (ni en ENV, ni en ARG):     │
│     → Usar BuildKit secret mounts: RUN --mount=type=secret,...  │
│     → Usar Docker secrets en runtime                            │
│  □  Minimizar paquetes instalados (reducir superficie de ataque)│
│  □  Read-only filesystem cuando sea posible:                    │
│     → docker run --read-only myapp                              │
│  □  No incluir .git, .env, credentials en la imagen             │
│  □  Actualizar base images regularmente                         │
│  □  Firmar imágenes (Docker Content Trust)                      │
│  □  Usar digest en lugar de tags para máxima inmutabilidad      │
└──────────────────────────────────────────────────────────────────┘
```

## 29.2 Secret mounts (BuildKit)

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .

# El secret NO se queda en ninguna capa:
RUN --mount=type=secret,id=pip_conf,target=/etc/pip.conf \
    pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["python", "app.py"]

# Build con secret:
# docker build --secret id=pip_conf,src=./pip.conf -t myapp .
```

---

# 30. Anti-Patrones y Errores Comunes

## 30.1 Tabla de anti-patrones

```text
┌──────────────────────────────────────┬───────────────────────────────────────┐
│  ❌ Anti-patrón                       │  ✅ Correcto                          │
├──────────────────────────────────────┼───────────────────────────────────────┤
│  FROM ubuntu:latest                  │  FROM ubuntu:22.04 (tag fijo)        │
│                                      │                                       │
│  COPY . . antes de RUN npm install   │  COPY package.json → RUN install →   │
│  (invalida cache en cada cambio)     │  COPY . . (máximo cache)             │
│                                      │                                       │
│  RUN apt update (en capa separada    │  RUN apt update && apt install &&    │
│  de RUN apt install)                 │  rm cache (todo en una capa)         │
│                                      │                                       │
│  Ejecutar como root                  │  USER non-root                       │
│                                      │                                       │
│  Secrets en ENV/ARG                  │  BuildKit secret mounts              │
│                                      │                                       │
│  Sin .dockerignore                   │  .dockerignore con node_modules,     │
│                                      │  .git, .env, etc.                    │
│                                      │                                       │
│  Un solo stage con compilador + app  │  Multi-stage build                   │
│                                      │                                       │
│  ADD para copiar archivos locales    │  COPY (ADD solo para auto-extract)   │
│                                      │                                       │
│  RUN cd /dir && cmd                  │  WORKDIR /dir + RUN cmd              │
│                                      │                                       │
│  CMD en shell form                   │  CMD en exec form ["cmd", "arg"]     │
│                                      │                                       │
│  apt install sin versión fija        │  apt install pkg=version (cuando     │
│                                      │  la reproducibilidad es crítica)     │
│                                      │                                       │
│  Muchos RUN separados               │  Combinar con && en un solo RUN      │
│                                      │  (para comandos relacionados)        │
└──────────────────────────────────────┴───────────────────────────────────────┘
```

## 30.2 Errores comunes de build

```text
1. "COPY failed: file not found"
   → El archivo no está en el build context.
   → Verificar que no esté en .dockerignore.
   → Las rutas de COPY son relativas al build context, no al Dockerfile.

2. "returned a non-zero code: 1" en RUN
   → El comando falló. Leer el output completo.
   → Causa común: paquete no encontrado (apt update no ejecutado).

3. Build extremadamente lento
   → Revisar .dockerignore — probablemente envías node_modules o .git.
   → Revisar el orden del Dockerfile — el cache se invalida temprano.

4. Imagen muy grande
   → Usar multi-stage build.
   → Combinar y limpiar en los RUN.
   → Usar base image más pequeña.

5. "no space left on device"
   → docker system prune -a --volumes
   → docker builder prune (limpiar build cache)

6. RUN apt-get update no se actualiza (usa cache viejo)
   → docker build --no-cache .
   → O invalidar cache cambiando la línea (agregar comentario con fecha).
```

---

# PARTE VII — EJEMPLOS Y EJERCICIOS

---

# 31. Ejemplo 1 — Nginx Custom

```dockerfile
# Extender la imagen oficial de Nginx con un HTML personalizado
FROM nginx:latest
# Recomendación: en producción usar tag fijo (nginx:1.25.3)

WORKDIR /usr/share/nginx/html
# El root directory de nginx por defecto

COPY index.html index.html
# Sobreescribir el index.html default

# No necesitamos CMD ni EXPOSE:
# → nginx:latest ya define CMD ["nginx", "-g", "daemon off;"]
# → nginx:latest ya define EXPOSE 80
# Los heredamos automáticamente via FROM.
```

```bash
# Build y ejecutar:
docker build -t my-nginx .
docker run -d -p 8080:80 --name web my-nginx
curl localhost:8080
# → Tu HTML personalizado
```

---

# 32. Ejemplo 2 — Node.js App

```dockerfile
FROM node:20-slim

# Instalar tini como init process (maneja señales correctamente)
RUN apt-get update \
    && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de la app
WORKDIR /usr/src/app

# Instalar dependencias PRIMERO (máximo cache):
COPY package.json package-lock.json ./
RUN npm ci --omit=dev \
    && npm cache clean --force

# Copiar código de la app DESPUÉS:
COPY . .

EXPOSE 3000

# tini como PID 1 → reenvía señales correctamente al proceso hijo
ENTRYPOINT ["tini", "--"]
CMD ["node", "server.js"]
```

```text
¿Por qué tini?
  Node.js no es un buen PID 1:
  → No reenvía señales a procesos hijos
  → No reaping de zombie processes
  → docker stop puede tardar 10s y hacer SIGKILL

  tini es un init minimalista (~20 KB) que:
  → Reenvía señales (SIGTERM → graceful shutdown)
  → Reaping de zombies
  → Es el PID 1 correcto

  Alternativa: docker run --init myapp (agrega tini automáticamente)
```

---

# 33. Ejemplo 3 — Python App Multi-Stage

```dockerfile
# ══════════════════════════════════════════
#  Stage 1: Instalar dependencias
# ══════════════════════════════════════════
FROM python:3.12-slim AS builder

WORKDIR /app

# Virtual environment para aislar deps:
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ══════════════════════════════════════════
#  Stage 2: Runtime mínimo
# ══════════════════════════════════════════
FROM python:3.12-slim AS production

# Copiar el venv completo del builder:
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY . .

# Non-root user:
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:create_app()"]
```

---

# 34. Ejemplo 4 — CMD vs ENTRYPOINT

## 34.1 Solo CMD (shell form vs exec form)

```dockerfile
# ─── Shell form ───
FROM alpine
CMD sleep 10000
# Ejecuta: /bin/sh -c "sleep 10000"
# PID 1 = sh (no sleep)
# docker stop → SIGTERM a sh → sh no reenvía → 10s timeout → SIGKILL

# ─── Exec form ───
FROM alpine
CMD ["sleep", "10000"]
# Ejecuta: sleep 10000 directamente
# PID 1 = sleep
# docker stop → SIGTERM a sleep → sleep termina inmediatamente
```

## 34.2 ENTRYPOINT + CMD

```dockerfile
FROM alpine
ENTRYPOINT ["sleep"]
CMD ["10000"]
# → docker run myapp         → sleep 10000
# → docker run myapp 60      → sleep 60 (CMD override)
# → docker run myapp --help  → sleep --help
```

---

# 35. Ejemplo 5 — Entrypoint Script Pattern

## 35.1 El patrón

```text
Muchas imágenes oficiales (postgres, mysql, redis) usan un entrypoint
script que:
  1. Ejecuta setup/configuración inicial
  2. Procesa variables de entorno
  3. Hace exec "$@" para reemplazarse con el CMD final

El exec es crucial: reemplaza el shell con el proceso de la app,
haciendo que la app sea PID 1 y reciba señales correctamente.
```

## 35.2 Ejemplo: con exec (correcto)

```bash
#!/bin/sh
set -e

# Setup:
echo "Running pre-flight checks..."
cat /etc/hosts
echo "Setup complete."

# exec "$@" reemplaza este script con el CMD del Dockerfile.
# Resultado: el CMD (ping 8.8.8.8) es PID 1.
exec "$@"
```

```dockerfile
FROM alpine
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["ping", "8.8.8.8"]
```

```text
Flujo de ejecución:
  1. Docker inicia /docker-entrypoint.sh como PID 1
  2. El script ejecuta el setup (echo, cat /etc/hosts)
  3. exec "$@" → exec "ping" "8.8.8.8"
  4. exec REEMPLAZA el shell con ping
  5. Ahora ping ES PID 1 → recibe SIGTERM directamente
  6. docker stop → SIGTERM → ping termina gracefully
```

## 35.3 Ejemplo: sin exec (anti-patrón)

```bash
#!/bin/sh
# ❌ SIN exec:
cat /etc/hosts
echo "Setup done."
ping 8.8.8.8
# ping es un HIJO de sh, no PID 1.
# sh es PID 1 pero no reenvía SIGTERM a ping.
# docker stop → SIGTERM a sh → sh lo ignora → 10s → SIGKILL
```

```dockerfile
FROM alpine
COPY ./do-stuff-then-ping.sh /
CMD ["/do-stuff-then-ping.sh"]
```

```text
Problema:
  1. Docker inicia /do-stuff-then-ping.sh como PID 1 (en sh)
  2. El script ejecuta setup y luego ping
  3. ping es un proceso HIJO de sh (PID != 1)
  4. docker stop → SIGTERM a sh (PID 1)
  5. sh ignora SIGTERM → Docker espera 10 segundos → SIGKILL
  6. Shutdown forzado. No graceful. Datos pueden perderse.

⚡ SIEMPRE usar exec "$@" en entrypoint scripts.
```

## 35.4 Resumen visual

```text
┌──────────────────────────────────────────────────────────────────┐
│  CON exec "$@"                │  SIN exec                        │
├───────────────────────────────┼──────────────────────────────────┤
│  PID 1 = tu aplicación       │  PID 1 = shell (sh)              │
│  SIGTERM llega a tu app      │  SIGTERM llega a sh (lo ignora)  │
│  Graceful shutdown ✅         │  10s timeout → SIGKILL ❌         │
│  Entrypoint se reemplaza     │  Shell queda como proceso padre  │
│  Patrón de imágenes oficiales│  Anti-patrón                     │
└───────────────────────────────┴──────────────────────────────────┘
```