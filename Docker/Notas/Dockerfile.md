# Dockerfile: Referencia Completa de Instrucciones

> *"A Dockerfile is a recipe. Each instruction adds a layer of intent — some shape the image, others define its runtime behavior."*
> — Docker Documentation

---

## Tabla de Contenidos

### Parte I — Fundamentos del Dockerfile
- [1. ¿Qué es un Dockerfile?](#1-qué-es-un-dockerfile)
- [2. Formato y sintaxis](#2-formato-y-sintaxis)
- [3. Buildtime vs Runtime](#3-buildtime-vs-runtime)
  - [3.1 Clasificación de instrucciones](#31-clasificación-de-instrucciones)
  - [3.2 Additive vs Overwrite](#32-additive-vs-overwrite)
  - [3.3 Tabla maestra de clasificación](#33-tabla-maestra-de-clasificación)
- [4. Parser directives](#4-parser-directives)
- [5. Variables de entorno en Dockerfiles](#5-variables-de-entorno-en-dockerfiles)
- [6. .dockerignore](#6-dockerignore)

### Parte II — Instrucciones de Build
- [7. FROM](#7-from)
  - [7.1 Sintaxis](#71-sintaxis)
  - [7.2 Multi-stage builds](#72-multi-stage-builds)
  - [7.3 ARG y FROM](#73-arg-y-from)
- [8. RUN](#8-run)
  - [8.1 Sintaxis y formas](#81-sintaxis-y-formas)
  - [8.2 Cache de RUN](#82-cache-de-run)
  - [8.3 RUN --mount](#83-run---mount)
  - [8.4 RUN --network](#84-run---network)
- [9. COPY](#9-copy)
  - [9.1 Sintaxis y opciones](#91-sintaxis-y-opciones)
  - [9.2 COPY --from (multi-stage)](#92-copy---from-multi-stage)
  - [9.3 COPY --chmod y --chown](#93-copy---chmod-y---chown)
  - [9.4 COPY --link](#94-copy---link)
- [10. ADD](#10-add)
  - [10.1 ADD vs COPY](#101-add-vs-copy)
  - [10.2 Fuentes soportadas](#102-fuentes-soportadas)

### Parte III — Instrucciones de Configuración
- [11. ENV](#11-env)
- [12. ARG](#12-arg)
  - [12.1 ENV vs ARG](#121-env-vs-arg)
  - [12.2 Scope y build cache](#122-scope-y-build-cache)
  - [12.3 ARGs predefinidos y de plataforma](#123-args-predefinidos-y-de-plataforma)
- [13. WORKDIR](#13-workdir)
- [14. USER](#14-user)
- [15. LABEL](#15-label)
- [16. SHELL](#16-shell)

### Parte IV — Instrucciones de Runtime
- [17. EXPOSE](#17-expose)
- [18. VOLUME](#18-volume)
- [19. STOPSIGNAL](#19-stopsignal)
- [20. HEALTHCHECK](#20-healthcheck)

### Parte V — Instrucciones Especiales
- [21. ONBUILD](#21-onbuild)
- [22. Here-documents](#22-here-documents)
- [23. Buenas prácticas generales](#23-buenas-prácticas-generales)

---

# Parte I — Fundamentos del Dockerfile

---

# 1. ¿Qué es un Dockerfile?

Un Dockerfile es un documento de texto que contiene todas las instrucciones necesarias para construir una imagen Docker. Docker lee estas instrucciones secuencialmente y genera una imagen con capas (layers).

```
Dockerfile  →  docker build  →  Image (capas inmutables)  →  docker run  →  Container
```

---

# 2. Formato y sintaxis

```dockerfile
# Comentario
INSTRUCTION arguments
```

- Las instrucciones **no son case-sensitive**, pero la convención es escribirlas en MAYÚSCULAS.
- Docker ejecuta las instrucciones **en orden**.
- Un Dockerfile **debe comenzar con `FROM`** (excepto por `ARG` y parser directives antes de `FROM`).
- Los comentarios (`#`) se eliminan antes de la ejecución.

```dockerfile
# Esto es un comentario
RUN echo 'we are running some # of cool things'  # El # aquí es parte del argumento
```

### Continuación de líneas

```dockerfile
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*
```

---

# 3. Buildtime vs Runtime

Para entender cómo un Dockerfile afecta una imagen y su contenedor, hay que distinguir dos dimensiones:

1. **Cuándo se ejecuta** la instrucción (buildtime, runtime, o ambos)
2. **Cómo se comporta** al repetirse (additive o overwrite)

---

## 3.1 Clasificación de instrucciones

```
BUILDTIME (docker build)          RUNTIME (docker run)
Afectan la imagen                 Afectan el contenedor
Crean capas                       Se almacenan como metadata
┌──────────────────┐              ┌──────────────────┐
│ FROM             │              │ EXPOSE           │
│ ADD              │              │ VOLUME           │
│ COPY             │              │ STOPSIGNAL       │
│ RUN              │              │ CMD              │
│ ARG              │              │ ENTRYPOINT       │
│ ONBUILD          │              │ HEALTHCHECK      │
└──────────────────┘              └──────────────────┘

        AMBOS (Build + Runtime)
        Afectan imagen Y contenedor
        ┌──────────────────┐
        │ ENV              │
        │ LABEL            │
        │ USER             │
        │ WORKDIR          │
        │ SHELL            │
        └──────────────────┘
```

---

## 3.2 Additive vs Overwrite

| Comportamiento | Descripción                                | Ejemplo                          |
|---------------|--------------------------------------------|----------------------------------|
| **Additive**  | Cada uso acumula, no reemplaza             | `RUN`, `COPY`, `EXPOSE`, `VOLUME` |
| **Overwrite** | Solo la última declaración tiene efecto    | `CMD`, `ENTRYPOINT`, `ARG`, `ENV`  |

---

## 3.3 Tabla maestra de clasificación

| Instrucción   | Fase       | Comportamiento | Descripción                          |
|--------------|------------|----------------|--------------------------------------|
| `FROM`       | Build      | Additive       | Define imagen base, inicia stage     |
| `RUN`        | Build      | Additive       | Ejecuta comando, crea capa           |
| `COPY`       | Build      | Additive       | Copia archivos del contexto          |
| `ADD`        | Build      | Additive       | Copia + extrae tar + soporta URLs    |
| `ONBUILD`    | Build      | Additive       | Trigger para builds descendientes    |
| `ARG`        | Build      | Overwrite      | Variable solo en build               |
| `ENV`        | Ambos      | Overwrite      | Variable de entorno persistente      |
| `LABEL`      | Ambos      | Overwrite      | Metadata clave-valor                 |
| `USER`       | Ambos      | Overwrite      | Usuario para RUN/CMD/ENTRYPOINT      |
| `WORKDIR`    | Ambos      | Overwrite      | Directorio de trabajo                |
| `SHELL`      | Ambos      | Overwrite      | Shell por defecto                    |
| `EXPOSE`     | Runtime    | Additive       | Documenta puertos                    |
| `VOLUME`     | Runtime    | Additive       | Punto de montaje                     |
| `STOPSIGNAL` | Runtime    | Overwrite      | Señal de parada                      |
| `CMD`        | Runtime    | Overwrite      | Comando por defecto                  |
| `ENTRYPOINT` | Runtime    | Overwrite      | Ejecutable principal                 |
| `HEALTHCHECK`| Runtime    | Overwrite      | Verificación de salud                |

> **Las instrucciones buildtime crean capas en la imagen. Las instrucciones runtime se almacenan como metadata y definen el comportamiento del contenedor.**

---

# 4. Parser directives

Directivas opcionales al inicio del Dockerfile que afectan cómo se procesan las líneas siguientes. No crean capas.

```dockerfile
# syntax=docker/dockerfile:1      ← Versión de sintaxis
# escape=`                         ← Carácter de escape (útil en Windows)
# check=error=true                 ← Build checks estrictos
```

### Reglas

- Deben estar al **inicio del archivo**, antes de cualquier instrucción o comentario.
- Cada directiva solo puede usarse **una vez**.
- No soportan continuación de línea.

### `syntax`

Declara la versión de sintaxis del Dockerfile:

```dockerfile
# syntax=docker/dockerfile:1
```

Permite usar features nuevas sin actualizar Docker Engine.

### `escape`

Cambia el carácter de escape (por defecto `\`). Útil en Windows donde `\` es separador de ruta:

```dockerfile
# escape=`

FROM microsoft/nanoserver
COPY testfile.txt c:\
RUN dir c:\
```

### `check`

Configura build checks:

```dockerfile
# check=skip=JSONArgsRecommended;error=true
```

---

# 5. Variables de entorno en Dockerfiles

Las variables definidas con `ENV` pueden usarse en muchas instrucciones:

```dockerfile
FROM busybox
ENV FOO=/bar
WORKDIR ${FOO}       # WORKDIR /bar
ADD . $FOO           # ADD . /bar
COPY \$FOO /quux     # COPY $FOO /quux (literal, escapado)
```

### Instrucciones que soportan variables de entorno

`ADD`, `COPY`, `ENV`, `EXPOSE`, `FROM`, `LABEL`, `STOPSIGNAL`, `USER`, `VOLUME`, `WORKDIR`, `ONBUILD`

### Modificadores bash soportados

| Sintaxis              | Comportamiento                                    |
|----------------------|---------------------------------------------------|
| `${var:-word}`       | Si `var` vacía → usa `word`                       |
| `${var:+word}`       | Si `var` no vacía → usa `word`                    |
| `${var#pattern}`     | Elimina match más corto desde inicio              |
| `${var%%pattern}`    | Elimina match más largo desde final               |

### Orden de evaluación

```dockerfile
ENV abc=hello
ENV abc=bye def=$abc   # def = "hello" (se evalúa antes de cambiar abc)
ENV ghi=$abc           # ghi = "bye"
```

---

# 6. .dockerignore

Excluye archivos y directorios del build context:

```
# .dockerignore
node_modules
.git
*.log
Dockerfile
.dockerignore
```

---

# Parte II — Instrucciones de Build

---

# 7. FROM

Inicializa un nuevo build stage y establece la imagen base.

---

## 7.1 Sintaxis

```dockerfile
FROM [--platform=<platform>] <image>[:<tag>] [AS <name>]
```

- `FROM` debe ser la primera instrucción (excepto `ARG`).
- Puede aparecer múltiples veces (multi-stage builds).
- Si se omite `tag`, se asume `latest`.
- `--platform` especifica arquitectura: `linux/amd64`, `linux/arm64`, etc.

```dockerfile
FROM ubuntu:22.04 AS builder
FROM node:20-alpine AS runtime
```

---

## 7.2 Multi-stage builds

Permiten crear stages intermedios y copiar solo los artefactos necesarios al stage final:

```dockerfile
FROM golang:1.21 AS build
WORKDIR /app
COPY . .
RUN go build -o /myapp

FROM alpine:3.19
COPY --from=build /myapp /usr/bin/myapp
CMD ["myapp"]
```

Cada `FROM` limpia el estado de instrucciones anteriores. Solo el stage final produce la imagen resultante.

---

## 7.3 ARG y FROM

`ARG` declarado antes de `FROM` está fuera de cualquier stage:

```dockerfile
ARG VERSION=latest
FROM busybox:$VERSION
ARG VERSION                    # Re-declarar para usarlo dentro del stage
RUN echo $VERSION > /version
```

---

# 8. RUN

Ejecuta comandos durante el build, creando una nueva capa.

---

## 8.1 Sintaxis y formas

```dockerfile
# Shell form (recomendada para RUN):
RUN apt-get update && apt-get install -y curl

# Exec form:
RUN ["apt-get", "update"]

# Heredoc:
RUN <<EOF
apt-get update
apt-get install -y curl vim
rm -rf /var/lib/apt/lists/*
EOF
```

> **Shell form es la opción por defecto para RUN.** Permite encadenar comandos (`&&`), pipes (`|`), redirección (`>`), y sustitución de variables.

---

## 8.2 Cache de RUN

- El cache de `RUN` **no se invalida automáticamente** entre builds.
- Se invalida con `--no-cache` o cuando un `ADD`/`COPY` anterior cambia.
- Combinar comandos relacionados en un solo `RUN` reduce capas:

```dockerfile
# ✓ Bueno: una sola capa
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# ✗ Malo: tres capas separadas
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

---

## 8.3 RUN --mount

Permite montar sistemas de archivos durante el build:

| Tipo     | Descripción                                | Ejemplo                              |
|---------|--------------------------------------------|--------------------------------------|
| `bind`  | Montar directorio del contexto (read-only) | Acceso a archivos del host           |
| `cache` | Cache persistente entre builds             | `/root/.cache/go-build`, `/var/cache/apt` |
| `tmpfs` | Sistema de archivos temporal               | Datos temporales del build           |
| `secret`| Acceso a secretos sin persistir en imagen  | Credenciales, API keys               |
| `ssh`   | Acceso a SSH agent                         | Clonar repos privados                |

```dockerfile
# Cache de paquetes apt (persistente entre builds):
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y gcc

# Acceso a secretos sin persistir en la imagen:
RUN --mount=type=secret,id=aws,target=/root/.aws/credentials \
    aws s3 cp s3://bucket/file .

# Secreto como variable de entorno:
RUN --mount=type=secret,id=API_KEY,env=API_KEY \
    some-command --token $API_KEY

# SSH para repos privados:
RUN --mount=type=ssh \
    git clone git@github.com:private/repo.git
```

```shell
# Build con secretos:
docker buildx build --secret id=aws,src=$HOME/.aws/credentials .

# Build con SSH:
docker buildx build --ssh default=$SSH_AUTH_SOCK .
```

---

## 8.4 RUN --network

Controla el entorno de red durante la ejecución:

| Tipo      | Descripción                          |
|----------|--------------------------------------|
| `default`| Red por defecto del build            |
| `none`   | Sin acceso a red (aislamiento)       |
| `host`   | Red del host                         |

```dockerfile
# Instalar solo paquetes locales (sin red):
RUN --network=none pip install --find-links wheels mypackage
```

---

# 9. COPY

Copia archivos y directorios desde el build context a la imagen.

---

## 9.1 Sintaxis y opciones

```dockerfile
COPY [OPTIONS] <src> ... <dest>
COPY [OPTIONS] ["<src>", ... "<dest>"]    # Para rutas con espacios
```

```dockerfile
COPY package.json .
COPY src/ /app/src/
COPY file1.txt file2.txt /usr/src/
COPY *.json /config/
```

### Reglas de destino

- Ruta absoluta (`/app/`) → relativa al root del container.
- Ruta relativa (`rel/`) → relativa al `WORKDIR`.
- Si no existe, se crea automáticamente.
- Trailing slash importa: `COPY file /dir` crea archivo `/dir`, `COPY file /dir/` crea `/dir/file`.

---

## 9.2 COPY --from (multi-stage)

Copia archivos desde otro stage, imagen, o contexto:

```dockerfile
# Desde un stage:
COPY --from=build /app/dist /usr/share/nginx/html

# Desde una imagen externa:
COPY --from=nginx:latest /etc/nginx/nginx.conf /nginx.conf
```

---

## 9.3 COPY --chmod y --chown

```dockerfile
# Establecer permisos:
COPY --chmod=755 entrypoint.sh /app/
COPY --chmod=644 config.yml /etc/app/

# Establecer propietario:
COPY --chown=node:node package*.json /app/
```

---

## 9.4 COPY --link

Crea capas independientes que no se invalidan cuando capas anteriores cambian:

```dockerfile
COPY --link /static /usr/share/nginx/html
```

> **Recomendado siempre que sea posible.** Mejora el cache en multi-stage builds y permite rebase de imágenes sin re-ejecutar todo el build.

---

# 10. ADD

Similar a `COPY` pero con funcionalidades adicionales.

---

## 10.1 ADD vs COPY

| Característica          | COPY               | ADD                    |
|------------------------|---------------------|------------------------|
| Copiar archivos locales| ✅                   | ✅                      |
| Extraer tar automáticos| ❌                   | ✅ (local)              |
| Descargar desde URL    | ❌                   | ✅                      |
| Clonar repos Git       | ❌                   | ✅                      |
| Predecibilidad         | Mayor               | Menor                  |

> **Preferir `COPY` sobre `ADD`** salvo que necesites extracción de tar o descarga de URLs.

---

## 10.2 Fuentes soportadas

```dockerfile
# Archivo local:
ADD app.tar.gz /app/                    # Se extrae automáticamente

# URL remota:
ADD https://example.com/file.zip /tmp/  # NO se extrae por defecto
ADD --unpack=true https://example.com/archive.tar.gz /data/

# Repositorio Git:
ADD https://github.com/user/repo.git /src/
ADD --keep-git-dir=true https://github.com/user/repo.git#v1.0 /src/

# Checksum para verificación:
ADD --checksum=sha256:abc123... https://example.com/file /app/
```

---

# Parte III — Instrucciones de Configuración

---

# 11. ENV

Establece variables de entorno que persisten en la imagen y en contenedores.

```dockerfile
ENV NODE_ENV=production
ENV APP_HOME=/app
ENV MY_NAME="John Doe" MY_DOG=Rex\ The\ Dog
```

- Persisten en la imagen → disponibles en `docker run`.
- Se heredan en stages basados en el mismo stage padre.
- Se pueden sobreescribir en runtime: `docker run --env NODE_ENV=development`.

> **Para variables que solo necesitas en build, usa `ARG` o define la variable inline en `RUN`:**

```dockerfile
# Inline (no persiste):
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# ARG (no persiste en imagen final):
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y nginx
```

---

# 12. ARG

Define variables disponibles durante el build.

```dockerfile
ARG VERSION=1.0
ARG BASE_IMAGE=node:20-alpine

FROM ${BASE_IMAGE}
ARG VERSION                        # Re-declarar dentro del stage
RUN echo "Building version: $VERSION"
```

---

## 12.1 ENV vs ARG

| Característica           | ARG                          | ENV                          |
|-------------------------|------------------------------|------------------------------|
| Disponible en build     | ✅                            | ✅                            |
| Disponible en runtime   | ❌                            | ✅                            |
| Persiste en imagen      | ❌                            | ✅                            |
| Visible en `docker history` | ⚠️ Sí                    | ✅                            |
| Se pasa con             | `--build-arg`                | `--env` en runtime           |

> **No uses `ARG` para secretos.** Son visibles en `docker history`. Usa `RUN --mount=type=secret`.

---

## 12.2 Scope y build cache

- `ARG` entra en efecto desde la línea donde se declara.
- Cambiar el valor de un `ARG` invalida el cache de todas las instrucciones `RUN` posteriores.
- `ENV` del mismo nombre sobreescribe a `ARG`:

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
ENV CONT_IMG_VER=${CONT_IMG_VER:-v1.0.0}   # ARG como default, ENV persiste
RUN echo $CONT_IMG_VER
```

---

## 12.3 ARGs predefinidos y de plataforma

### Proxy (excluidos de docker history por seguridad)

`HTTP_PROXY`, `HTTPS_PROXY`, `FTP_PROXY`, `NO_PROXY` (y sus versiones lowercase)

### Plataforma (BuildKit)

| Variable          | Descripción                        |
|------------------|------------------------------------|
| `TARGETPLATFORM` | Plataforma de la imagen resultado  |
| `TARGETOS`       | SO de la plataforma target         |
| `TARGETARCH`     | Arquitectura target                |
| `BUILDPLATFORM`  | Plataforma del nodo que construye  |

```dockerfile
FROM alpine
ARG TARGETPLATFORM
RUN echo "Building for $TARGETPLATFORM"
```

---

# 13. WORKDIR

Establece el directorio de trabajo para `RUN`, `CMD`, `ENTRYPOINT`, `COPY`, `ADD`.

```dockerfile
WORKDIR /app
COPY . .
RUN npm install
```

- Si no existe, se crea automáticamente.
- Rutas relativas son relativas al `WORKDIR` anterior:

```dockerfile
WORKDIR /a
WORKDIR b
WORKDIR c
RUN pwd         # Output: /a/b/c
```

- Soporta variables de entorno: `WORKDIR $APP_HOME`

---

# 14. USER

Establece el usuario (y opcionalmente grupo) para `RUN`, `CMD`, `ENTRYPOINT`.

```dockerfile
USER node:node
```

- Por defecto es `root` (UID 0).
- El usuario debe existir en la imagen.
- Afecta tanto al build como al runtime.

---

# 15. LABEL

Añade metadata a la imagen como pares clave-valor:

```dockerfile
LABEL version="1.0"
LABEL maintainer="dev@example.com"
LABEL org.opencontainers.image.title="My App" \
      org.opencontainers.image.version="1.0.0"
```

- Se heredan de la imagen base.
- Si la misma clave se repite, el último valor gana.
- Se inspeccionan con `docker image inspect --format='{{json .Config.Labels}}'`.

---

# 16. SHELL

Cambia el shell por defecto usado en shell form de `RUN`, `CMD`, y `ENTRYPOINT`.

```dockerfile
SHELL ["executable", "parameters"]
```

| SO      | Shell por defecto         |
|---------|--------------------------|
| Linux   | `["/bin/sh", "-c"]`      |
| Windows | `["cmd", "/S", "/C"]`    |

```dockerfile
# Cambiar a bash:
SHELL ["/bin/bash", "-c"]
RUN echo "Using bash now"

# Cambiar a PowerShell (Windows):
SHELL ["powershell", "-command"]
RUN Write-Host "Hello from PowerShell"
```

- Cada `SHELL` sobreescribe los anteriores.
- Debe escribirse siempre en exec form.

---

# Parte IV — Instrucciones de Runtime

---

# 17. EXPOSE

Documenta los puertos en los que el contenedor escucha. **No publica el puerto.**

```dockerfile
EXPOSE 80
EXPOSE 443
EXPOSE 80/tcp
EXPOSE 53/udp
```

- Es informativa — requiere `-p` o `-P` en `docker run` para publicar realmente.
- Es **additive**: cada `EXPOSE` se acumula.

```shell
docker run -p 8080:80 myapp     # Publica puerto 80 del contenedor en 8080 del host
docker run -P myapp             # Publica todos los EXPOSE en puertos aleatorios del host
```

---

# 18. VOLUME

Crea un punto de montaje para persistencia de datos:

```dockerfile
VOLUME ["/data"]
VOLUME /var/log /var/data
```

- El directorio se inicializa con el contenido existente en la imagen.
- El directorio del host se define en `docker run`, no en el Dockerfile.
- Es **additive**: cada `VOLUME` se acumula.

> **Limitación:** Cambios en el volumen después de su declaración se descartan en el build.

---

# 19. STOPSIGNAL

Define la señal de sistema para detener el contenedor:

```dockerfile
STOPSIGNAL SIGTERM    # Default
STOPSIGNAL SIGQUIT
STOPSIGNAL 9          # SIGKILL (no permite graceful shutdown)
```

Se puede sobreescribir con `docker run --stop-signal`.

---

# 20. HEALTHCHECK

Verifica que el contenedor funciona correctamente:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
```

### Opciones

| Opción             | Default | Descripción                          |
|-------------------|---------|--------------------------------------|
| `--interval`      | 30s     | Tiempo entre checks                  |
| `--timeout`       | 30s     | Timeout por check                    |
| `--start-period`  | 0s      | Tiempo de gracia inicial             |
| `--start-interval`| 5s      | Intervalo durante start period       |
| `--retries`       | 3       | Fallos consecutivos para `unhealthy` |

### Estados de salud

| Exit code | Estado      | Significado                |
|-----------|-------------|----------------------------|
| 0         | healthy     | Contenedor funcionando     |
| 1         | unhealthy   | Contenedor con problemas   |

```dockerfile
# Deshabilitar healthcheck heredado:
HEALTHCHECK NONE
```

---

# Parte V — Instrucciones Especiales

---

# 21. ONBUILD

Registra instrucciones que se ejecutarán cuando la imagen se use como base en otro build:

```dockerfile
# En imagen base:
FROM node:20
ONBUILD COPY package*.json ./
ONBUILD RUN npm install
ONBUILD COPY . .
```

```dockerfile
# En imagen derivada (las instrucciones ONBUILD se ejecutan automáticamente):
FROM my-node-base
CMD ["node", "server.js"]
```

### Reglas

- Los triggers se ejecutan después de `FROM` en el build descendiente.
- Se limpian después de ejecutarse (no se heredan a "nietos").
- No se puede encadenar: `ONBUILD ONBUILD ...` no es válido.
- `ONBUILD` no puede disparar `FROM` ni `MAINTAINER`.

---

# 22. Here-documents

Permiten escribir contenido inline en `RUN` y `COPY`:

```dockerfile
# Script multi-línea:
RUN <<EOF
apt-get update
apt-get install -y vim curl
rm -rf /var/lib/apt/lists/*
EOF

# Con intérprete específico:
RUN <<EOF
#!/usr/bin/env python3
print("Hello from Python")
EOF

# Crear archivos inline:
COPY <<EOF /app/config.yml
database:
  host: localhost
  port: 5432
EOF

# Múltiples here-docs:
RUN <<FILE1 cat > file1.txt && <<FILE2 cat > file2.txt
Content of file 1
FILE1
Content of file 2
FILE2
```

### Variables en here-docs

```dockerfile
ARG FOO=bar
# Sin comillas en delimitador → variable se expande en build:
COPY <<-EOT /script.sh
  echo "hello ${FOO}"
EOT

# Con comillas en delimitador → variable se expande en runtime:
COPY <<-"EOT" /script.sh
  echo "hello ${FOO}"
EOT
```

---

# 23. Buenas prácticas generales

| Práctica                                     | Razón                                        |
|---------------------------------------------|----------------------------------------------|
| Minimizar capas (`RUN` combinado)            | Menor tamaño de imagen                       |
| Usar `COPY` en lugar de `ADD`               | Más predecible, comportamiento explícito     |
| Usar `.dockerignore`                         | Reduce build context                         |
| Ordenar instrucciones por frecuencia de cambio | Maximizar cache de capas                  |
| No instalar paquetes innecesarios            | Menor superficie de ataque                   |
| Usar multi-stage builds                      | Imagen final más pequeña                     |
| No usar `ARG` para secretos                  | Visible en `docker history`                  |
| Usar `RUN --mount=type=secret` para secretos | No persisten en la imagen                    |
| Usar `RUN --mount=type=cache` para cache     | Builds más rápidos                           |
| Establecer `WORKDIR` explícitamente          | Evitar operaciones en directorio desconocido |
| Ejecutar como non-root (`USER`)              | Seguridad                                    |

### Orden recomendado de instrucciones

```dockerfile
# 1. Parser directives
# syntax=docker/dockerfile:1

# 2. Base image
FROM node:20-alpine AS builder

# 3. Metadata
LABEL maintainer="dev@example.com"

# 4. Build arguments
ARG NODE_ENV=production

# 5. Environment variables
ENV NODE_ENV=$NODE_ENV

# 6. Working directory
WORKDIR /app

# 7. Dependencies (cambian menos → mejor cache)
COPY package*.json ./
RUN npm ci --only=production

# 8. Application code (cambia más frecuentemente)
COPY . .
RUN npm run build

# 9. Runtime stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

# 10. Runtime config
USER node
EXPOSE 3000
HEALTHCHECK CMD curl -f http://localhost:3000/health || exit 1

# 11. Start command
CMD ["node", "dist/server.js"]
```

---

> *"The best Dockerfile is the one you understand completely — every instruction, every layer, every trade-off."*
> — Docker Community
