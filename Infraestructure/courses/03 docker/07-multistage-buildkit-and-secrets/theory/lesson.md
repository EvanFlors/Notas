# Teoria — Multi-stage, BuildKit y secrets

> Leccion profunda, pensada para 4 horas incluyendo exploracion en consola. Lenguaje: prosa en espanol, codigo y comandos en ingles.

---

## 1. Por que existe multi-stage: separar build-time de runtime

Cuando compilas una app en Python con extensiones C (p. ej. `psycopg2`, `cryptography`, `lxml`, `numpy`) necesitas, **durante el build**, un toolchain completo: `gcc`, `g++`, `make`, headers de `libpq`, `libssl`, `libxml2`, etc. Nada de eso hace falta **en runtime**: una vez compilado el wheel, la app solo necesita la libreria dinamica final (`libpq5`, `libssl3`...) y el interprete.

Un Dockerfile monolitico mete todo en la imagen final:

```dockerfile
# ANTI-PATRON: toolchain enterrado en la imagen productiva
FROM python:3.12
RUN apt-get update && apt-get install -y gcc libpq-dev
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

Resultado tipico: **400–900 MB**. Problemas:

1. **Superficie de ataque gigante.** Cada binario del toolchain es codigo que podria tener CVEs.
2. **Pull lento en Kubernetes.** Cold-start de pods se degrada.
3. **Confusion operacional.** Un operador que entra con `docker exec` encuentra `gcc` y asume que puede compilar en produccion. No deberia poder.

**Multi-stage** resuelve esto con una idea simple: **declaras varios `FROM` en el mismo Dockerfile; solo el ultimo (o el que indiques con `--target`) produce la imagen final.** Los stages intermedios son *scratch pads* que puedes usar para compilar, generar artefactos, correr linters, y luego descartar.

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12 AS builder
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev
COPY requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/*.whl && rm -rf /wheels
COPY app.py /app/app.py
WORKDIR /app
CMD ["python", "app.py"]
```

Resultado: la imagen final no incluye `gcc` ni headers. Baja a **< 150 MB** sin perder funcionalidad.

La frase para memorizar:

> **El stage builder es efimero. Solo cruza la frontera lo que copias explicitamente con `COPY --from=`.**

---

## 2. El DAG de BuildKit

Antes de BuildKit, el builder clasico de Docker procesaba el Dockerfile de forma **lineal**: una instruccion detras de otra, en orden. Si tenias tres stages, el tercero esperaba al segundo, que esperaba al primero.

**BuildKit** cambia el modelo. En vez de leer el Dockerfile como una lista, construye un **DAG (grafo dirigido aciclico) de operaciones**. Cada nodo es una instruccion; las aristas son dependencias (output de uno es input de otro). Dos consecuencias practicas:

1. **Paralelizacion de stages independientes.** Si `stage A` y `stage B` no se referencian entre si, BuildKit los corre en paralelo (siempre que haya suficientes workers).
2. **Pruning del grafo.** Si pides `docker build --target runtime`, BuildKit calcula que stages NO son alcanzables desde `runtime` y los omite. Un stage `test` que corre `pytest` solo se ejecuta si lo apuntas explicitamente.

```
         ┌──────────────┐
         │  base/python │
         └──────┬───────┘
                │ depende
       ┌────────┼────────┐
       ▼        ▼        ▼
   ┌───────┐┌───────┐┌───────┐
   │builder││ test  ││ lint  │   <── paralelos (si hay workers)
   └───┬───┘└───────┘└───────┘
       │
       │ COPY --from=builder
       ▼
   ┌────────┐
   │runtime │   <── stage final por default
   └────────┘
```

Esto cambia la forma de disenar Dockerfiles grandes: en vez de una secuencia pensada "en orden", piensas en **productores y consumidores**.

Para habilitar BuildKit:

- Docker Desktop moderno: default.
- Docker Engine en Linux: default a partir de la version 23. En versiones anteriores: `DOCKER_BUILDKIT=1 docker build …` o configurar `/etc/docker/daemon.json` con `"features": {"buildkit": true}`.
- Alternativa explicita: `docker buildx build …` (siempre usa BuildKit, incluso en versiones viejas).

Debe aparecer la directiva de frontend al tope del Dockerfile:

```dockerfile
# syntax=docker/dockerfile:1
```

Esta linea le dice a BuildKit que use el **frontend Dockerfile v1**, la version mas reciente (soporta `--mount`, heredocs, etc.). Sin ella, usa un frontend viejo y pierdes features. **Siempre ponla.**

---

## 3. Sintaxis de stages: `FROM ... AS <name>` y `COPY --from=<name>`

Un stage es "todo lo que esta entre un `FROM` y el siguiente `FROM` (o el final del archivo)". Nombrarlo con `AS <name>` te permite referenciarlo despues:

```dockerfile
FROM golang:1.22 AS builder          # stage "builder"
WORKDIR /src
COPY . .
RUN go build -o /bin/app ./cmd/app

FROM gcr.io/distroless/static AS runtime   # stage "runtime", la imagen final
COPY --from=builder /bin/app /app
ENTRYPOINT ["/app"]
```

`COPY --from=` tambien acepta imagenes externas:

```dockerfile
# Trae mkcert desde una imagen publica, sin agregarlo a tu runtime.
COPY --from=hairyhenderson/gomplate:latest /gomplate /usr/local/bin/gomplate
```

Dos reglas que confunden al principio:

- **Un stage sin nombre tambien existe**; se referencia por indice (`--from=0`, `--from=1`). Nombrar siempre es mejor para legibilidad.
- **El stage final por default es el ultimo `FROM` del archivo.** Puedes overridear con `docker build --target builder .` para hornear la imagen hasta el builder (util para debug).

---

## 4. Cache mounts: `--mount=type=cache`

BuildKit introduce una idea nueva: montar un **volumen persistente** durante la ejecucion de un `RUN`, que NO queda horneado en la capa resultante. Ejemplo canonico para Python:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

Que hace exactamente `--mount=type=cache,target=/root/.cache/pip`:

- **Durante** la ejecucion del `RUN`, el directorio `/root/.cache/pip` es un volumen gestionado por BuildKit, persistente entre builds.
- Si pip descargo `flask-3.0.3-py3-none-any.whl` en un build previo, lo reutiliza sin bajarlo de PyPI.
- Al terminar el `RUN`, el volumen se **desmonta**. La capa resultante *no* contiene `.cache/pip`.

Contrastalo con `pip install --cache-dir=/wheels` sin mount:

- La cache queda **en la capa**, inflando el tamano.
- Y aun asi solo persiste si no invalidas la cache de esa linea.

Reglas practicas:

- El target debe ser un directorio **unico por tool**: `/root/.cache/pip`, `/root/.npm`, `/go/pkg/mod`, `/var/cache/apt`.
- Para `apt` necesitas desactivar la limpieza automatica. Patron tipico:
  ```dockerfile
  RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      rm -f /etc/apt/apt.conf.d/docker-clean \
   && apt-get update \
   && apt-get install -y --no-install-recommends gcc
  ```
- `sharing=locked` evita que dos builds concurrentes se pisen (`sharing=shared` lo permite si el tool tolera concurrencia).

Impacto en reproducibilidad: una build con cache mount **podria** diferir bit-a-bit de otra sin cache si el mirror upstream cambia. Para builds totalmente reproducibles (ver `dkr-12`) querras pinnear versiones por digest ademas de usar el mount.

---

## 5. Secret mounts: `--mount=type=secret`

Este es el patron **unico correcto** para pasar un secreto a `RUN`:

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine:3.20
RUN apk add --no-cache git
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN="$(cat /run/secrets/github_token)" \
 && git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/org/private-repo.git" /src
```

Y lo construyes:

```bash
echo "ghp_FAKE_TOKEN_xxxx" > /tmp/token.txt
DOCKER_BUILDKIT=1 docker build \
  --secret id=github_token,src=/tmp/token.txt \
  -t my-app .
rm /tmp/token.txt
```

Que garantiza esto:

- El archivo `/tmp/token.txt` se monta como `/run/secrets/github_token` **solo durante** ese `RUN`.
- La capa resultante NO contiene el archivo. **Verificable** con `docker history --no-trunc` (no aparece el token) y con `docker run --rm my-app ls /run/secrets` (no existe).
- No queda en el log del build (BuildKit lo redacta automaticamente en `--progress=plain` si usas la convencion `GITHUB_TOKEN=$(cat ...)`).

Fuente del secret:

- `src=/path/to/file` (file)
- `env=VAR_NAME` (variable de entorno del cliente docker)

**Nunca** uses alternativas tentadoras pero rotas:

| Anti-patron | Por que filtra |
|-------------|----------------|
| `ARG MY_TOKEN` + `--build-arg MY_TOKEN=...` | Queda en `docker history` (`CMD /bin/sh -c ... ARG MY_TOKEN=ghp_xxx`). |
| `ENV MY_TOKEN=...` | Queda en una capa Y en el env del contenedor en runtime. |
| `COPY secret.txt /secret && RUN use /secret && rm /secret` | La capa del `COPY` persiste; el `rm` solo agrega otra capa encima. El secreto sigue en el tar de la capa anterior. |
| `curl -H "Authorization: Bearer $TOKEN"` con token en `RUN` sin mount | Si vino de `--build-arg`, mismo problema. Si vino de un `ENV`, mismo problema. |

**La regla:** un secreto que viaja por `ARG`, `ENV` o `COPY` es un secreto filtrado. Punto.

---

## 6. `ARG` vs secreto: por que `ARG` siempre filtra

`ARG` es por diseno **publico**:

- Vive en el **config JSON** de la imagen (que `docker history --no-trunc` muestra entero).
- Si el `RUN` referencia el `ARG`, el valor sustituido aparece en el campo `created_by` de la capa.
- Aunque "borres" la linea con otro `RUN`, la capa anterior sigue en el tar de la imagen (el filesystem overlay es *aditivo*, no destructivo).

Demostracion que haras en `activities/02-remove-leaked-secret-from-image/`:

```bash
docker build --build-arg API_TOKEN=FAKE_TOKEN_abc123 -t leaky .
docker history --no-trunc leaky | grep FAKE_TOKEN_abc123
# imprime la linea con el token, para siempre
```

El token no desaparece aunque hagas `docker image prune`, aunque re-tagges, aunque pushes y pulles. Si publicaste esa imagen a un registry publico, el token esta **comprometido** y debes rotarlo. Las defensas en depth (escaneo de imagenes, policies de registry) ayudan pero no son el fix. El fix es **no filtrarlo**.

---

## 7. `docker build` vs `docker buildx`

- `docker build` — el comando clasico. En Docker moderno delega a BuildKit automaticamente.
- `docker buildx build` — el **plugin de BuildKit**. Expone features avanzadas: multi-arch (`--platform`), builders dedicados (`docker-container`, `kubernetes`), export de cache a OCI registries, bake files.

Para el 90% de casos locales, `docker build` basta. Para CI, `buildx` suele dar mas control. En este modulo usamos `docker build` (con BuildKit implicito); en `dkr-12` daremos el salto a `buildx` por el soporte multi-arch.

Para forzar BuildKit en una version antigua:

```bash
DOCKER_BUILDKIT=1 docker build .
```

En Docker Desktop y en Docker Engine ≥ 23, es el default.

---

## 8. Debug con `--progress=plain`

Por default, Docker muestra un progreso TUI "bonito" que resume y oculta mucho:

```
#5 [internal] load build definition from Dockerfile
#5 DONE 0.0s
#6 [stage-0 1/4] FROM python:3.12-slim
#6 DONE 0.1s
#7 [stage-0 2/4] COPY requirements.txt .
#7 DONE 0.0s
#8 [stage-0 3/4] RUN pip install -r requirements.txt
#8 CACHED
```

Util para builds exitosos. Inservible cuando algo falla y necesitas ver *exactamente* que output produjo un `RUN`. Para eso:

```bash
docker build --progress=plain -t img . 2>&1 | less
```

Con `plain`:

- Ves cada linea de stdout/stderr del `RUN`.
- Ves `CACHED` o la ejecucion real por paso.
- Puedes `grep CACHED` para auditar que esta tomando cache.
- Puedes `grep -i warning` para detectar `apt-get install` sin `--no-install-recommends`, etc.

Combinado con cache y secret mounts, es tu herramienta #1 de diagnostico:

```bash
docker build --progress=plain --no-cache -t img . 2>&1 | tee /tmp/build.log
grep -E "ERROR|Fatal|Traceback" /tmp/build.log
```

---

## 9. `docker history` como auditoria

`docker history` muestra la lista de capas de una imagen, con el comando que las creo y su tamano. Es tu **auditoria** final:

```bash
docker history --no-trunc my-app:latest
```

- Para detectar bloat: cualquier capa de > 50 MB que no sea el base image es sospechosa.
- Para detectar secretos filtrados: `docker history --no-trunc my-app:latest | grep -i -E "token|secret|password|api[_-]?key"`.
- Para auditar un multi-stage: solo ves las capas del stage final. Los stages intermedios no estan en la imagen (bien).

Herramienta mas completa: **`dive`** (`github.com/wagoodman/dive`), que te muestra el filesystem efectivo por capa. Lo cubrimos en `dkr-11`.

---

## 10. Anti-patrones comunes en multi-stage

### 10.1 Copiar `/root/.cache/pip` al runtime

```dockerfile
FROM python:3.12 AS builder
COPY requirements.txt .
RUN pip install -r requirements.txt   # instala en /usr/local/lib/python...

FROM python:3.12-slim AS runtime
COPY --from=builder /usr/local /usr/local   # <── copia TODO, incluido pip cache
```

Mejor: en el builder genera `wheels` separados (`pip wheel --wheel-dir /wheels`), copia solo `/wheels` al runtime y haz `pip install --no-index --find-links=/wheels` + `rm -rf /wheels`.

### 10.2 Usar `python:3.12` (no slim) en el runtime

El runtime debe ser el mas pequeno posible. `python:3.12` pesa ~1 GB; `python:3.12-slim` ~130 MB. Si puedes usar `distroless` (ver `dkr-11`), aun menos.

### 10.3 `ARG` para secretos

Ya cubierto en §6. **Siempre** es un filtro. Siempre.

### 10.4 Olvidar el `# syntax=docker/dockerfile:1`

Sin la directiva, `--mount` no esta disponible y silenciosamente lo pierdes. Siempre ponla.

### 10.5 Olvidar `--no-install-recommends`

Instala paquetes "recomendados" que no necesitas y suma MBs. En el builder puede importar menos; en el runtime es critico.

### 10.6 No limpiar `apt` lists

```dockerfile
RUN apt-get update && apt-get install -y libpq5 \
 && rm -rf /var/lib/apt/lists/*
```

Sin el `rm -rf`, agregas ~30 MB de indices que no sirven en runtime.

### 10.7 Correr el runtime como root

Fuera de scope aqui (lo cubre `dkr-13`), pero: siempre `USER app` no-root en el runtime.

---

## 11. Patron de referencia para una app Python

Resumen de todo lo anterior en un unico archivo:

```dockerfile
# syntax=docker/dockerfile:1

###############################################################################
# Stage 1: builder — compila wheels con toolchain.
###############################################################################
FROM python:3.12 AS builder

ENV PIP_NO_CACHE_DIR=0 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc \
      libpq-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt

###############################################################################
# Stage 2: runtime — solo lo necesario para ejecutar.
###############################################################################
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq5 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 1001 app

WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/*.whl \
 && rm -rf /wheels

COPY --chown=app:app app.py ./

USER app
EXPOSE 8000
CMD ["python", "app.py"]
```

Y para construir con secret (si la app accede a un repo privado):

```bash
echo "ghp_FAKE_TOKEN_xxxx" > /tmp/gh.txt
docker build \
  --secret id=github_token,src=/tmp/gh.txt \
  --progress=plain \
  -t my-app:latest .
rm /tmp/gh.txt
```

---

## 12. Preguntas de autoevaluacion

Responde sin consultar la leccion:

1. ¿Que significa `# syntax=docker/dockerfile:1` y que pasa si lo omites?
2. BuildKit construye un DAG. Da un caso concreto donde dos stages se ejecutarian en paralelo y uno donde no.
3. Explica en una frase por que `ARG API_TOKEN=xxx` filtra el token aunque el `RUN` que lo usa termine con un `rm`.
4. ¿Que diferencia hay entre `--mount=type=cache,target=/root/.cache/pip` y hacer `pip install --cache-dir=/wheels` sin mount?
5. Dado un `RUN --mount=type=secret,id=foo cat /run/secrets/foo > /app/x`, ¿donde falla la seguridad? (truco: la pregunta importa.)
6. ¿Como pides a BuildKit que construya solo hasta el stage `builder` para debuggear?
7. ¿Como auditas, sin herramientas externas, que un token no esta en una imagen `my-app:latest`?
8. ¿Cuales son los dos efectos de usar `--progress=plain`?
9. ¿Por que la imagen final usa `python:3.12-slim` en vez de `python:3.12`? Da un ejemplo de problema real.
10. ¿Como pasarias un token desde una variable de entorno del cliente docker (no un archivo) a un build?

---

### Lecturas recomendadas antes de las actividades

- `examples/01-multistage-python-wheels/README.md`.
- `examples/02-buildkit-cache-mount/README.md`.
- `examples/03-secret-mount-git-token/README.md`.
- Dockerfile best practices (docs.docker.com) — especialmente la seccion de multi-stage.
- `docs.docker.com/build/buildkit/` — frontend y features modernas.

Con esto cerramos la fase "builder" del curso. En `dkr-11` reemplazaremos `python:3.12-slim` por **distroless** y veremos imagenes de < 70 MB; en `dkr-12` publicaremos la misma imagen para `amd64` y `arm64`.
