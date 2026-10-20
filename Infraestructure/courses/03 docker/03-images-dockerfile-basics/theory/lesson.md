# Lección: Imágenes y Dockerfile — fundamentos

> **ID:** `dkr-03-images-dockerfile-basics` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `dkr-02-install-engine-and-first-container`.

---

## 1. Introducción intuitiva

En `dkr-02` corriste contenedores a partir de imágenes **ajenas**: `nginx`, `python:3.12-slim`, `postgres`. Ahora el objetivo cambia: vas a **construir las tuyas**. Pasas de ser *consumidor* de imágenes a ser *autor*.

Una **imagen** no es "un snapshot de una máquina virtual". Es un **objeto de datos** con una estructura muy específica: un **manifest** (JSON) que enumera un conjunto de **capas** (tarballs comprimidos) y una **config** (JSON) que describe cómo ejecutar la imagen (comando por default, usuario, puertos, variables de entorno, labels). Todo esto está versionado por **digests SHA-256** inmutables y referenciado por **tags** mutables (`:latest`, `:3.12-slim`).

Para construirla, Docker interpreta un archivo de texto llamado `Dockerfile`: una receta imperativa donde cada instrucción produce una **capa** nueva encima de la anterior. El resultado final es un grafo de capas con su manifest, listo para correr o publicar.

Dominar este módulo es dominar tres habilidades:

1. **Escribir** un Dockerfile que haga lo que quieres.
2. **Leer** un Dockerfile ajeno y predecir qué imagen produce.
3. **Auditar** una imagen (tuya o ajena) con `docker history`, `docker inspect`, `docker image ls`.

Lo que **no** verás todavía: optimización de caché (viene en `dkr-06`), multi-stage builds (`dkr-07`), publicación a registries (`dkr-09`), hardening de runtime (`dkr-13`). Aquí construyes el esqueleto correcto. Lo demás son refinamientos sobre esta base.

---

## 2. Fundamentos

Siete conceptos a interiorizar antes de abrir un editor.

### 2.1 Imagen vs contenedor vs capa

- **Capa (layer):** un tarball comprimido con un diff del filesystem respecto a la capa anterior. Identificada por un digest SHA-256 del tar sin comprimir (`diffID`) y uno del tar comprimido (`digest`).
- **Imagen:** un *manifest* que enumera un conjunto ordenado de capas + un objeto *config* (JSON) con el comando por default, env, labels, usuario, etc. También identificada por digest (del manifest).
- **Contenedor:** un proceso Linux lanzado a partir de una imagen, con una capa escribible encima del grafo de capas de la imagen (vía overlayfs).

Un diagrama:

```
          Imagen (manifest)
          ┌─────────────────────────────┐
          │ config.json                 │  ← CMD, ENV, USER, WorkingDir...
          │ layers:                     │
          │   sha256:aaa…  (FROM base)  │
          │   sha256:bbb…  (COPY)       │
          │   sha256:ccc…  (RUN pip)    │
          │   sha256:ddd…  (COPY app)   │
          └─────────────────────────────┘
                  ↑
                  │ docker run
                  │
          Contenedor (proceso + overlay)
          ┌─────────────────────────────┐
          │ capa escribible (upperdir)  │  ← cambios en runtime
          │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
          │ capas read-only (lowerdir)  │
          └─────────────────────────────┘
```

Al eliminar el contenedor, la capa escribible se descarta. Las capas read-only pertenecen a la imagen y se comparten entre contenedores que la usan.

### 2.2 Tags vs digests

- **Tag:** alias humano, **mutable**. `python:3.12-slim` apunta a un digest; mañana ese tag puede apuntar a otro digest (patch del upstream). Dos `docker pull python:3.12-slim` en momentos distintos pueden traer bytes diferentes.
- **Digest:** `python@sha256:ac1b2c…`. **Inmutable** por definición (SHA del manifest). Dos pulls del mismo digest traen exactamente los mismos bytes, para siempre.

En producción se referencia por digest. En desarrollo se tolera referenciar por tag. Se profundiza en `dkr-09`.

### 2.3 El build context

Cuando corres `docker build -t myimg .`, el `.` es el **build context**: el directorio que el CLI empaqueta y envía al daemon/BuildKit. Dentro del Dockerfile, `COPY src dst` **solo puede ver** archivos dentro de ese contexto.

Dos consecuencias:

1. **El contexto se transfiere entero** (modulo `.dockerignore`). Un `node_modules/` o un `.git/` enorme es tiempo perdido y bytes que no vas a usar.
2. **`COPY ../otro-dir`** no funciona. El contexto es el límite.

### 2.4 El `.dockerignore`

Un archivo con patrones (sintaxis estilo `.gitignore`) que indica qué **excluir del contexto antes de enviarlo**. No es solo cosmético:

- Reduce el tiempo de transferencia del contexto.
- Reduce la posibilidad de meter secretos sin querer (`.env`, `.aws/`).
- Mejora el hit-rate de caché: cambios en archivos ignorados no invalidan la caché de instrucciones `COPY`.

### 2.5 Caché de capas

Cada instrucción es cacheable (con excepciones como `RUN` con comandos no deterministas). BuildKit calcula una clave de caché a partir de:

- La instrucción textual.
- Para `COPY`/`ADD`: un hash de los archivos copiados.
- Para `FROM`: el digest de la base.
- Para `RUN`: el comando.
- La capa anterior (padre).

Si la clave coincide con una capa ya existente, **se reusa**. Si no coincide, se construye nueva y **toda la cadena de instrucciones subsiguientes se invalida también**. Por eso el orden importa (tema de `dkr-06`): instalar dependencias ANTES de copiar el código permite reusar la capa de deps cuando solo cambia el código.

### 2.6 Shell form vs exec form

Las instrucciones `RUN`, `CMD`, `ENTRYPOINT` aceptan dos sintaxis:

- **Shell form:** `CMD python app.py`. Docker lo ejecuta como `/bin/sh -c "python app.py"`. Hay un shell intermedio.
- **Exec form:** `CMD ["python", "app.py"]`. Docker llama directamente `execve("python", ["python", "app.py"], env)`. No hay shell.

La diferencia parece cosmética pero no lo es. En el modo exec:

- Tu proceso es **PID 1**. Recibe `SIGTERM` directamente cuando se hace `docker stop`.
- No hay sustitución de variables (`$HOME` queda literal).
- No hay operadores de shell (`&&`, `|`, redirecciones).

En el modo shell:

- `/bin/sh` es PID 1. Tu proceso es un hijo. `/bin/sh` **no reenvía señales** por default a sus hijos. El `docker stop` manda `SIGTERM` a PID 1 (el shell), que lo ignora o lo consume; tu app nunca lo ve, no corre su `shutdown` hook, y después de 10 segundos de grace, Docker manda `SIGKILL`. Pérdida de datos en vuelo, conexiones no cerradas, locks sin liberar.

Regla práctica: para `CMD`/`ENTRYPOINT` **siempre exec form** salvo que haya una razón explícita.

### 2.7 `CMD` vs `ENTRYPOINT`

Ambos definen qué corre el contenedor al iniciarse, pero cumplen roles distintos:

- **`ENTRYPOINT`:** el binario/comando "fijo" del contenedor. Difícil de sobreescribir (`docker run --entrypoint ...` lo hace, pero es un flag explícito).
- **`CMD`:** los **argumentos por default** que se pasan a `ENTRYPOINT`. Fácil de sobreescribir desde la CLI: `docker run <image> <nuevos-args>`.

Patrones:

| Patrón | `ENTRYPOINT` | `CMD` | Uso |
|--------|--------------|-------|-----|
| "Contenedor como binario" | `["python", "app.py"]` | `[]` o args default | Imagen hace una cosa; `docker run img --flag` pasa flags. |
| "Contenedor como entorno" | *(no definido)* | `["bash"]` | Dejas que el usuario elija qué correr: `docker run -it img python`. |
| "Binario + args default" | `["gunicorn"]` | `["app:app", "--bind", "0.0.0.0:8000"]` | Default razonable, overrideable. |

El reglamento oficial:

- Si solo `CMD` está definido, se ejecuta.
- Si solo `ENTRYPOINT` está definido, se ejecuta.
- Si ambos están definidos, se ejecuta `ENTRYPOINT CMD` concatenados.
- Un `docker run <image> <args>` reemplaza `CMD`, nunca `ENTRYPOINT` (salvo `--entrypoint`).

---

## 3. Contexto histórico

- **2013** — Docker introduce `Dockerfile` como DSL imperativa. Formato simple heredado de scripts shell.
- **2014** — Aparece `ONBUILD`, `ENTRYPOINT` en forma exec, `USER`.
- **2015** — Se publica el OCI image-spec; el formato de imagen Docker converge con OCI.
- **2016** — Multi-stage builds (`FROM … AS builder`). Cambio fundamental; se cubre en `dkr-07`.
- **2017** — `HEALTHCHECK` como instrucción.
- **2018+** — **BuildKit** llega como builder opcional. Introduce DAG paralelo, cache mounts, secret mounts, remote cache.
- **2019** — BuildKit por default (con flag en versiones de transición).
- **2021–2023** — Immutable actions, provenance, SBOM integrados al build.
- **2024+** — El `Dockerfile` sigue siendo el estándar de facto; alternativas como *Containerfile* (Podman) son nombres distintos del mismo formato. Nixpacks, Buildpacks (CNCF), ko (para Go) son alternativas de más alto nivel.

El `Dockerfile` sobrevivió a múltiples intentos de reemplazarlo por sintaxis declarativa (YAML, JSON) porque su naturaleza imperativa + cacheable encaja bien con el modelo mental de los desarrolladores.

---

## 4. Funcionamiento interno

### 4.1 Qué hace `docker build`

```
┌──────────────────────────────────────────────────────────┐
│  docker build -t myapp:v1 .                              │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
   1) CLI empaqueta el contexto (modulo .dockerignore)
                        │
                        ▼
   2) Lo envia a dockerd (o directo a BuildKit)
                        │
                        ▼
   3) BuildKit parsea el Dockerfile → DAG de operaciones
                        │
                        ▼
   4) Resuelve FROM (pull de la base si no esta local)
                        │
                        ▼
   5) Por cada instrucción:
         - calcula cache key
         - si hit: reusa capa
         - si miss: ejecuta en un contenedor temporal,
                    captura diff del filesystem, crea layer
                        │
                        ▼
   6) Combina capas + config → manifest
                        │
                        ▼
   7) Tag local: myapp:v1 → sha256:abc...
```

Cada instrucción que modifica el filesystem (`RUN`, `COPY`, `ADD`) produce una capa. Instrucciones de metadata (`ENV`, `EXPOSE`, `LABEL`, `USER`, `WORKDIR`, `CMD`, `ENTRYPOINT`) solo modifican el **config**, no crean capa nueva (en BuildKit moderno). En el builder legacy sí creaban capas vacías; `docker history` las sigue mostrando como `0B`.

### 4.2 Cómo se guarda la imagen

En `/var/lib/docker/` (Linux nativo) o dentro de la VM de Docker Desktop (macOS/Windows). Estructura simplificada:

```
/var/lib/docker/
├── overlay2/           ← cada capa como un diff
│   ├── <hash>/diff/
│   └── <hash>/link
├── image/overlay2/
│   ├── layerdb/        ← metadata de capas
│   ├── imagedb/content/sha256/<image_digest>  ← config.json
│   └── repositories.json  ← mapa tag → digest
```

No es necesario memorizarlo, pero cuando `docker system df` dice "layers: 12 GB" sabes dónde mirar.

### 4.3 Qué hace cada instrucción

- **`FROM <image>[:tag|@digest] [AS stage]`**  
  Base del build. Primera instrucción obligatoria (o `ARG` + `FROM`). Con digest es reproducible; con tag es cómodo pero mutable.

- **`WORKDIR /path`**  
  Cambia el `cwd` para instrucciones siguientes. Crea el directorio si no existe. Preferible a `RUN cd /path && ...` porque persiste.

- **`COPY <src> <dst>`**  
  Copia del contexto a la imagen. Respeta `.dockerignore`. Sin flags adicionales, los archivos quedan con `uid:gid=0:0`.
  - `COPY --chown=user:group src dst` — cambia ownership al copiar.
  - `COPY --from=<stage|image> src dst` — copia desde otro stage o imagen (multi-stage, `dkr-07`).

- **`ADD <src> <dst>`**  
  Como `COPY`, pero también:
  - Extrae tarballs locales automáticamente.
  - Puede descargar URLs.
  
  **Anti-patrón** fuera de casos muy específicos: menos predecible que `COPY`. Regla: usa `COPY` salvo que necesites extracción de tar.

- **`RUN <cmd>`**  
  Ejecuta un comando en una capa nueva encima de la actual. Lo que persiste es el diff del filesystem al terminar.
  - Shell form: `RUN apt-get update && apt-get install -y curl`
  - Exec form: `RUN ["apt-get", "install", "-y", "curl"]`
  
  Para builds, shell form es común porque permite `&&`, `|`, redirecciones.

- **`ENV KEY=value`**  
  Variable de entorno **persistente**: existe durante el build (para instrucciones siguientes) **y en runtime** (procesos del contenedor la ven).

- **`ARG name[=default]`**  
  Variable **solo de build-time**. Se pasa con `--build-arg name=val`. No existe en runtime. Útil para parametrizar builds (versiones, URLs). **No usar para secretos** — queda en `docker history` si se usa dentro de un `RUN`.

- **`EXPOSE 8000[/tcp|/udp]`**  
  **Metadata documental.** No abre puertos. No publica nada. Solo declara "esta imagen espera que el puerto 8000 esté en uso". Para publicarlo necesitas `docker run -p 8000:8000` o `-P` (publica todos los expuestos a puertos aleatorios).

- **`USER <user[:group]|uid[:gid]>`**  
  Cambia el usuario para instrucciones siguientes y para el runtime. Default: `root` (UID 0). Correr como root dentro del contenedor **no es equivalente** a root en el host (hay user namespaces, dropped capabilities), pero es un escalón menos de defensa en profundidad. **Siempre crear y usar un usuario no-root.**

- **`CMD`** y **`ENTRYPOINT`** — ya cubiertos en §2.6 y §2.7.

- **`LABEL key=value`**  
  Metadata estática (versión, mantenedor, licencia). Usar las convenciones OCI (`org.opencontainers.image.*`) — se detalla en `dkr-06`.

- **`HEALTHCHECK CMD <cmd>`**  
  Comando que Docker ejecuta periódicamente para marcar el estado del contenedor (`healthy` / `unhealthy`). Útil pero con sutilezas; se profundiza en `dkr-08`.

### 4.4 El filesystem overlay y las capas durante el build

Cuando BuildKit ejecuta un `RUN apt-get install ...`:

1. Crea un contenedor temporal con las capas acumuladas como `lowerdir`.
2. Añade una `upperdir` vacía.
3. Corre el comando dentro.
4. Captura el `upperdir` resultante → ese es el tarball de la nueva capa.
5. Elimina el contenedor temporal.

Consecuencia importante: **borrar un archivo en una instrucción posterior no reduce el tamaño total de la imagen**. El archivo sigue viviendo en la capa donde se creó; la capa posterior solo tiene un *whiteout* indicando "oculta este path". Para no inflar la imagen con basura, borra en el mismo `RUN` donde la creaste:

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

Si lo partes en dos `RUN`, el `rm` solo añade un whiteout; los índices de apt siguen pesando en la capa anterior.

### 4.5 `docker history`

Muestra las capas de una imagen con tamaño, comando y edad:

```
IMAGE          CREATED        CREATED BY                                      SIZE
sha256:abc…    5 seconds ago  CMD ["python" "app.py"]                         0B
<missing>      5 seconds ago  COPY . /app # buildkit                          12.3kB
<missing>      30 seconds ago RUN pip install -r requirements.txt # buildkit  48.7MB
<missing>      30 seconds ago COPY requirements.txt /app/requirements.txt     68B
<missing>      30 seconds ago WORKDIR /app                                    0B
<missing>      2 weeks ago    /bin/sh -c #(nop)  CMD ["python3"]              0B
<missing>      2 weeks ago    /bin/sh -c set -eux; ...                        9.3MB
<missing>      2 weeks ago    /bin/sh -c #(nop)  ENV PYTHON_VERSION=3.12.4    0B
```

Léelo de abajo hacia arriba: las capas del base image (`python:3.12-slim`) marcadas `<missing>` (sus IDs no están local porque solo tienes el manifest + content layers, no los build steps intermedios del upstream), seguidas de tus capas con sus comandos.

Con `--no-trunc` ves el comando completo. Es la primera herramienta para detectar:
- Instrucciones mal ordenadas (deps pesadas invalidadas por cambio de código).
- Secretos filtrados (`ARG DB_PASS=…`).
- `apt-get update` sin cleanup.
- Comandos no deterministas que rompen caché.

---

## 5. Ejemplo mínimo

El Dockerfile más corto *útil* para una app Python/FastAPI (lo encontrarás en `examples/01-dockerfile-python-app/`):

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN useradd --system --uid 10001 --no-create-home appuser
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Léelo de arriba abajo:

- **`# syntax=docker/dockerfile:1`** — directiva al parser; habilita features modernos de BuildKit (cache mounts, secret mounts, mejoras de hashing). Siempre ponla en la primera línea.
- **`FROM python:3.12-slim`** — base. `-slim` es Debian con lo mínimo. Trae CPython 3.12 y pip. En producción prefieres pinnear por digest (`python:3.12-slim@sha256:...`), tema de `dkr-09`.
- **`WORKDIR /app`** — todo lo que siga corre con `cwd=/app`. Crea el directorio.
- **`COPY requirements.txt .`** — copia **solo** el `requirements.txt` (no todo el contexto) para que la capa de pip install solo se invalide cuando cambien las dependencias, no cada vez que cambie el código.
- **`RUN pip install --no-cache-dir -r requirements.txt`** — instala deps. `--no-cache-dir` evita que pip deje una caché que infla la imagen sin ser reutilizable.
- **`COPY app ./app`** — ahora sí copia el código. Si solo cambia el código, la capa de pip install se reusa.
- **`RUN useradd ... && USER appuser`** — crea un usuario sistema no-root y cambia a él. A partir de aquí, todo corre como UID 10001.
- **`EXPOSE 8000`** — documental.
- **`CMD [... exec form ...]`** — exec form: `uvicorn` será PID 1 y recibirá `SIGTERM` directamente.

Build y run:

```bash
docker build -t fastapi-mini:v1 .
docker run --rm -p 8000:8000 fastapi-mini:v1
curl -s http://localhost:8000/healthz
```

`Ctrl-C` termina en < 1 s porque `uvicorn` recibe `SIGINT` y hace shutdown ordenado.

---

## 6. Implementación progresiva

Añadamos tres mejoras incrementales. Cada una resuelve un problema específico.

### 6.1 `.dockerignore`

Añade al contexto un archivo `.dockerignore`:

```
.git/
__pycache__/
*.pyc
.pytest_cache/
.venv/
venv/
.env
.env.*
.vscode/
.idea/
tests/
docs/
```

Resultado inmediato (ejemplo típico): el `Sending build context to Docker daemon` pasa de 150 MB a 50 KB. Y, crucialmente, `COPY . .` deja de invalidar la caché cada vez que corres los tests localmente (porque `.pytest_cache/` no cambia la imagen pero cambia el hash del contexto).

### 6.2 `ARG` para parametrizar la versión de Python

```dockerfile
# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim
```

Build:

```bash
docker build --build-arg PYTHON_VERSION=3.11 -t fastapi-mini:py311 .
```

Importante: el `ARG` definido **antes** de `FROM` solo es visible en el `FROM`. Para usarlo en instrucciones posteriores, redeclaralo después del `FROM`:

```dockerfile
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim
ARG PYTHON_VERSION
RUN echo "Built on Python ${PYTHON_VERSION}"
```

### 6.3 `HEALTHCHECK`

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://localhost:8000/healthz').status==200 else sys.exit(1)"
```

El contenedor pasa a estado `healthy` cuando el chequeo tiene éxito tres veces seguidas. `docker ps` muestra `(healthy)`. Útil para `depends_on: service_healthy` en Compose (`dkr-08`).

Un patrón alternativo mejor es tener un binario `curl` o `wget` en la imagen; en `slim` no vienen, así que `python -c` evita añadir una dependencia solo para el healthcheck.

---

## 7. Aplicación profesional

En un proyecto real, el Dockerfile mínimo "serio" (sin multi-stage todavía — eso es `dkr-07`) se ve así:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim@sha256:ac1b2c...  # pin por digest, no por tag mutable

ARG APP_UID=10001
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# 1) Deps primero (capa estable)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2) Codigo después
COPY --chown=${APP_UID}:${APP_UID} app ./app

# 3) Usuario no-root
RUN groupadd --system --gid ${APP_UID} appuser \
 && useradd --system --uid ${APP_UID} --gid ${APP_UID} --no-create-home appuser
USER ${APP_UID}:${APP_UID}

# 4) Metadata OCI
LABEL org.opencontainers.image.title="fastapi-mini" \
      org.opencontainers.image.source="https://github.com/.../.." \
      org.opencontainers.image.licenses="MIT"

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://localhost:8000/healthz').status==200 else sys.exit(1)"

ENTRYPOINT ["uvicorn"]
CMD ["app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Qué se puede leer sin saber todavía `dkr-04` a `dkr-14`:

- `PYTHONDONTWRITEBYTECODE=1` evita que la app genere `.pyc` en runtime (reduce IO en filesystem efímero).
- `PYTHONUNBUFFERED=1` fuerza stdout/stderr no bufferados; logs llegan al momento (crítico para contenedores — ver §9.3).
- `ENTRYPOINT ["uvicorn"]` + `CMD ["app.main:app", ...]` es el patrón "binario + args default": `docker run image --port 9000` cambia solo los args, no el binario.

### 7.1 Qué revisar al llegar a un Dockerfile ajeno

Reflejo cuando entras a un repo con `Dockerfile`:

1. `head -1 Dockerfile` → ¿tiene `# syntax=docker/dockerfile:1`?
2. `grep ^FROM` → ¿tag mutable, digest, scratch, distroless? ¿Alpine o Debian-slim?
3. `grep -E '^(COPY|ADD)' Dockerfile` → ¿`ADD` injustificado? ¿Orden `deps-primero`?
4. `grep ^USER Dockerfile` → ¿corre como root?
5. `grep -E '^(CMD|ENTRYPOINT)' Dockerfile` → ¿exec form (JSON array) o shell form?
6. `grep -i -E '(SECRET|TOKEN|PASS|KEY)' Dockerfile` → ¿hay ARGs/ENVs con nombres sospechosos?
7. Luego `docker build . && docker history --no-trunc <img>` para ver qué capas y tamaños salen.

Con este módulo puedes contestar las 7. El resto (optimización fina, multi-stage, scanner) llega después.

---

## 8. Trade-offs

### 8.1 `CMD` vs `ENTRYPOINT`

| Elección | Ventaja | Costo |
|----------|---------|-------|
| Solo `CMD` | Fácil override: `docker run img <cualquier-cmd>`. | El contenedor "no se defiende" — cualquiera puede cambiar qué corre con un run. Útil cuando la imagen es un entorno (`python:3.12`), no un servicio. |
| Solo `ENTRYPOINT` (exec) | Imagen = binario. Args del run se concatenan. | Para debug (`docker run -it img bash`) necesitas `--entrypoint bash`. |
| Ambos | Default razonable, overrideable. | Más piezas. Confusión si no se documenta. |

Regla práctica: para **servicios** (daemon, API) usa `ENTRYPOINT [...] + CMD [...]`. Para **imágenes de desarrollo / entornos** usa solo `CMD`.

### 8.2 Shell form vs exec form (señales)

| Forma | PID 1 | Señales | Expansión de vars | Operadores shell |
|-------|-------|---------|-------------------|------------------|
| Exec `["bin", "arg"]` | tu binario | directo | no | no |
| Shell `bin arg` | `/bin/sh -c` | se pierden salvo config | sí (`$VAR`) | sí (`&&`, `|`) |

Regla: `CMD` / `ENTRYPOINT` en **exec form** por default. Si necesitas expansión de variables en runtime, usa `exec` dentro de un entrypoint script:

```sh
#!/bin/sh
exec python -u app.py --listen "${LISTEN_ADDR:-0.0.0.0:8000}"
```

El `exec` reemplaza al shell: tu Python toma PID 1 y recibe señales directamente.

Alternativa: `docker run --init <image>` inyecta `tini` como PID 1, que reenvía señales y hace *zombie reaping* (visto en `dkr-02`).

### 8.3 Base image: `python:3.12`, `python:3.12-slim`, `python:3.12-alpine`

| Variante | Tamaño aprox | Pros | Contras |
|----------|--------------|------|---------|
| `python:3.12` | ~900 MB | Debian completo con muchos compiladores y libs. | Enorme, mucha superficie. |
| `python:3.12-slim` | ~130 MB | Debian minimal. Compatible con wheels precompiladas (glibc). | Falta `gcc` para builds de C extensions sin wheel. |
| `python:3.12-alpine` | ~55 MB | Minúsculo. | **musl != glibc** → muchas wheels de PyPI no cargan; builds largos; CVEs distintas. **Evitar para apps Python** con extensiones C. |
| `distroless/python3-debian12` | ~50 MB | Sin shell, sin gestor de paquetes, mínima superficie. | Difícil de debuggear (sin `sh`). Se cubre en `dkr-11`. |

Default razonable: `python:3.12-slim`. Decisión profunda en `dkr-11`.

### 8.4 Tag mutable vs digest inmutable

| | Tag (`:3.12-slim`) | Digest (`@sha256:…`) |
|---|-----|-----|
| Legibilidad | alta | ninguna |
| Reproducibilidad | baja (upstream puede moverlo) | total |
| Updates automáticos de patches | sí | nunca (manual) |
| Uso recomendado | dev, local | prod, CI gated |

En `dkr-09` se detalla el workflow de "pin por digest + bot que abre PRs cuando hay nuevo digest".

---

## 9. Errores frecuentes

### 9.1 `COPY . .` como primera cosa

```dockerfile
WORKDIR /app
COPY . .                                 # ← mata la caché
RUN pip install -r requirements.txt
```

Cada cambio de código invalida `COPY .` y, por cascada, el `pip install`. Minutos perdidos por commit. Fix: copia `requirements.txt` primero, instala, y después copia el código.

### 9.2 Shell form en `CMD`/`ENTRYPOINT`

```dockerfile
CMD python app.py       # ← shell form
```

Esto corre como `/bin/sh -c "python app.py"`. `docker stop` manda `SIGTERM` al shell, no a Python. Tras 10 s de grace, `SIGKILL`. Fix: exec form.

```dockerfile
CMD ["python", "app.py"]
```

Lo verás en vivo en `examples/02-entrypoint-vs-cmd/`.

### 9.3 Logs que no aparecen

```dockerfile
CMD ["python", "app.py"]
```

Si la app escribe a `print()` sin flush, el buffer de stdout queda retenido. Fix:

```dockerfile
ENV PYTHONUNBUFFERED=1
```

O `python -u app.py`. Mismo problema en Node (menos severo), Java (buffer propio), etc. Es la causa #1 de "mi contenedor no muestra logs".

### 9.4 Correr como root

```dockerfile
FROM python:3.12-slim
# ...
CMD ["python", "app.py"]      # ← PID 1 es root
```

Un `RCE` dentro de la app corre como UID 0 dentro del contenedor. Si el runtime no droppea capabilities o si hay `--privileged`, el daño se amplifica. Fix: `useradd` + `USER` no-root.

### 9.5 `apt-get update` sin `apt-get install` en el mismo `RUN`

```dockerfile
RUN apt-get update
RUN apt-get install -y curl                 # ← caché traicionera
```

La capa del `apt-get update` queda cacheada. Semanas después, un build re-usa esa capa con índices viejos; el `install -y curl` falla porque el índice referencia versiones ya purgadas. Fix: siempre en el mismo `RUN`, con cleanup.

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

### 9.6 Secretos vía `ARG`

```dockerfile
ARG GITHUB_TOKEN
RUN curl -H "Authorization: token $GITHUB_TOKEN" ...
```

El token queda en `docker history` (en el comando del RUN). Fix: `--mount=type=secret` de BuildKit, cubierto en `dkr-07`.

### 9.7 `EXPOSE` sin `-p` esperando que publique

`EXPOSE 8000` es solo documentación. Para publicar el puerto necesitas `docker run -p 8000:8000`. El error típico es `curl localhost:8000` sin `-p` y confusión.

### 9.8 Falta de `.dockerignore` → contexto gigante

Un `.git/` de 500 MB o un `node_modules/` o un `venv/` que viajan al daemon en cada build. Tiempo y RAM perdidos, y riesgo de meter secretos (`.env`) o archivos privados a la imagen vía un `COPY .` descuidado.

### 9.9 Pensar que `docker rm` elimina la imagen

`docker rm` quita contenedores. `docker rmi` quita imágenes. `docker system prune` limpia ambos (con `--volumes` también volúmenes). Olvidarlo infla disco rápido.

### 9.10 Confiar en que `latest` es "lo último estable"

`latest` es solo un tag mutable que el autor eligió apuntar donde quiso. En algunos repos apunta a nightly, en otros a última estable, en otros está abandonado. Nunca asumir semántica. Preferir un tag versionado (`:v1.2`) o un digest.

---

## 10. Buenas prácticas

- **Siempre `# syntax=docker/dockerfile:1` como primera línea.** Habilita features modernos de BuildKit.
- **Orden de instrucciones: lo estable arriba, lo volátil abajo.** `FROM` → system deps → app deps → código.
- **`.dockerignore` desde el commit 1.** Incluye `.git/`, caches, venvs, `.env*`, tests que no entran a la imagen.
- **`COPY` sobre `ADD`.** Solo usar `ADD` si realmente necesitas extracción de tar.
- **Exec form (`[...]`) en `CMD`/`ENTRYPOINT`.** Siempre.
- **`USER` no-root** antes del `CMD`/`ENTRYPOINT`. Crear el usuario con UID > 10000 (menos colisiones con usuarios del host).
- **`ENV PYTHONUNBUFFERED=1`** en apps Python (y equivalentes en otros lenguajes) para logs en vivo.
- **Instala y limpia en el mismo `RUN`.** No partas en dos.
- **No uses `ARG` para secretos.** Usa `--mount=type=secret` (`dkr-07`).
- **`EXPOSE` es documental.** Lo real es `docker run -p`.
- **Pin de base por digest en producción.** Tag mutable solo en dev.
- **`docker history --no-trunc <img>` al terminar cada cambio.** Si ves algo raro, lo arreglas antes de publicar.
- **Un `Dockerfile` por propósito.** No reutilices el mismo para "dev y prod" sin multi-stage.

---

## 11. Ejercicios recomendados

1. **`examples/01-dockerfile-python-app/`** — construye y corre la imagen; corre `docker history --no-trunc` y comenta cada capa.
2. **`examples/02-entrypoint-vs-cmd/`** — reproduce las 4 variantes; para cada una, haz `docker stop` y mide con `time` cuánto tarda en terminar.
3. **`examples/03-dockerignore-impact/`** — build con y sin `.dockerignore`; compara el output `Sending build context` y los tiempos.
4. **`activities/01-build-your-first-image/`** — construye tu propia imagen de FastAPI que cumpla todos los criterios (guided-lab).
5. **`activities/02-fix-signal-handling/`** — un contenedor que no muere; encuentra la causa y aplica la mínima corrección (independent).

---

## 12. Evaluación

Responde sin consultar. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Diferencia conceptual (una frase cada uno):
   - [ ] imagen
   - [ ] capa
   - [ ] contenedor
   - [ ] tag
   - [ ] digest

**P2.** Dado este Dockerfile:
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD python app.py
```
Lista **tres** problemas (uno por línea afectada) y propón el fix.

**P3.** Explica qué pasa cuando ejecutas `docker stop <ct>` en un contenedor que corre `CMD python app.py` (shell form) vs `CMD ["python", "app.py"]` (exec form). Mide en segundos.

**P4.** `ENTRYPOINT ["gunicorn"]` + `CMD ["app:app", "--bind", "0.0.0.0:8000"]`. Para cada `docker run`, di qué se ejecuta:
   - `docker run myimg`
   - `docker run myimg --workers 4`
   - `docker run --entrypoint sh myimg`
   - `docker run --entrypoint sh myimg -c "ls /app"`

**P5.** ¿Por qué `ARG` **no** es apropiado para pasar un `GITHUB_TOKEN` en un `RUN git clone ...`? ¿Dónde queda y cómo lo sabrías?

**P6.** `USER appuser` dentro del Dockerfile — ¿qué protege y qué **no** protege respecto a un atacante que logra RCE en el proceso?

**P7.** Dos pulls del mismo tag `redis:7-alpine` en semanas distintas pueden traer bytes diferentes. ¿Por qué, y qué cambiarías para garantizar reproducibilidad?

**P8.** Mira esta línea en `docker history --no-trunc`:
   ```
   RUN /bin/sh -c apt-get update  (0B)
   ```
   El tamaño es 0B. ¿Es bueno o malo, y por qué? ¿Qué podría estar pasando?

**P9.** Diseño: te piden empaquetar una CLI escrita en Python (un comando `mytool`) que la gente debería poder invocar como `docker run myorg/mytool --help`. Diseña el `CMD`/`ENTRYPOINT`. Justifica.

**P10.** Un compañero añade `.env` al repo y hace `COPY . .` en el Dockerfile. Pushea la imagen a un registry público. ¿Qué pasó y cuál es el plan de respuesta mínimo? (Nota: la limpieza *real* del secreto filtrado es tema de `dkr-07`; aquí solo la detección y el principio.)

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Dockerfile reference*. <https://docs.docker.com/reference/dockerfile/>
- *Best practices for writing Dockerfiles*. <https://docs.docker.com/develop/develop-images/dockerfile_best-practices/>
- *About images, containers, and storage drivers*. <https://docs.docker.com/storage/storagedriver/>
- *Build context*. <https://docs.docker.com/build/building/context/>
- `.dockerignore` reference. <https://docs.docker.com/engine/reference/builder/#dockerignore-file>
- *OCI image-spec*. <https://github.com/opencontainers/image-spec>
- *BuildKit* repo. <https://github.com/moby/buildkit>

Lectura complementaria:

- *Dive* (explorador de capas). <https://github.com/wagoodman/dive>
- *Docker Captains blog — Dockerfile deep dives*. <https://www.docker.com/blog/>
- *12-Factor App — logs as streams* (justifica `PYTHONUNBUFFERED=1`). <https://12factor.net/logs>
