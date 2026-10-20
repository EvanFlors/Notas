# Lección: Multi-arch y reproducibilidad

> **ID:** `dkr-12-multiarch-and-reproducibility` · **Nivel:** avanzado · **Duración:** 4 h
> **Prerrequisitos:** `dkr-07`, `dkr-09`.

---

## 1. Introducción intuitiva

Hasta aquí tus imágenes han sido *mono-arquitectura*. Construyes en tu laptop y, si tu laptop es un MacBook con chip Apple Silicon, la imagen que produces es `linux/arm64`. Si tu servidor de producción es un `t3.large` de AWS (Intel), le harás `docker pull` a esa imagen y Docker rechazará el contenedor con un `exec format error` — o peor, emulará silenciosamente y rendirá a un décimo de la velocidad.

El problema real: tus consumidores no corren todos en la misma arquitectura.

- Los runners de GitHub Actions `ubuntu-latest` son `linux/amd64`.
- Un cluster de EKS puede mezclar `t3` (amd64) con `t4g` (arm64/Graviton), más barato un ~20 %.
- Tus desarrolladores llevan MacBooks M1/M2/M3 (arm64) y PCs Linux (amd64).
- Un Raspberry Pi es `linux/arm/v7` o `linux/arm64`.

Lo que quieres es publicar **un solo tag** (`ghcr.io/me/app:v1`) y que `docker pull` desde cualquiera de esos entornos reciba la variante correcta, sin que el desarrollador tenga que recordar sufijos ni etiquetas.

Esto se llama **imagen multi-arch**, y lo que *realmente* existe en el registry no es "una imagen que corre en varios lados": es un **manifest index** (también llamado *manifest list*), un pequeño JSON que apunta a varias imágenes mono-arch distintas. El cliente, al hacer `pull`, lee el índice, mira su propia `GOOS/GOARCH`, y baja solo la variante que le toca.

El segundo gran tema del módulo es la **reproducibilidad**. "Mismo Dockerfile, mismo contexto → mismo digest". Suena obvio, pero por default Docker produce un digest *distinto cada vez*: timestamps embebidos, orden de archivos no determinista, metadatos de red (fecha del `apt-get update`), versiones flotantes del base image, etc. Hacer el build *bit-a-bit reproducible* es una práctica que acerca a SLSA 3+ y que vamos a desmontar aquí.

---

## 2. Fundamentos: imagen OCI mono-arch

Repaso rápido (viene de `dkr-01` y `dkr-09`).

Una imagen OCI *mono-arch* es, en el registry, tres cosas:

1. Un **manifest** (`application/vnd.oci.image.manifest.v1+json` o la variante Docker legacy): lista las capas y el config.
2. Un **config** (`application/vnd.oci.image.config.v1+json`): metadata (env, cmd, labels, **architecture**, **os**, historia de build).
3. **Capas** (`.tar.gz`), referenciadas por `sha256:…`.

El `digest` de una imagen es `sha256(manifest)`. **El digest cambia** si cambia cualquier capa, el config, o el orden de referencias dentro del manifest. Es un hash determinista — si todas las entradas son iguales, el digest es idéntico.

```
image-ref  ──►  manifest (sha256:aaa…)
                 ├── config  (sha256:bbb…)   { arch: amd64, os: linux, ...}
                 ├── layer   (sha256:ccc…)
                 └── layer   (sha256:ddd…)
```

Nada en esta estructura permite "funcionar en dos arquitecturas". El `config` dice **una** arquitectura. Si quieres `arm64`, necesitas *otra* imagen, con *otro* `config`, con *otro* digest.

---

## 3. El manifest index (lo que la gente llama "imagen multi-arch")

El truco: hay un *cuarto* tipo de objeto, el **image index** (`application/vnd.oci.image.index.v1+json`, antes "manifest list" en el formato Docker). Es un JSON con un array de referencias a manifests, cada uno anotado con su plataforma:

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest":    "sha256:aaa…",
      "size":      1234,
      "platform":  { "architecture": "amd64", "os": "linux" }
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest":    "sha256:bbb…",
      "size":      1234,
      "platform":  { "architecture": "arm64", "os": "linux" }
    }
  ]
}
```

Lo que vive bajo el tag `app:v1` cuando "es multi-arch" es **este índice**. El digest del índice es `sha256(index.json)`.

```
tag: app:v1
       │
       ▼
   ┌────────────────────────────┐
   │  image index (sha256:xxx)  │
   │  platforms[]:              │
   │   • linux/amd64 → sha:aaa  │
   │   • linux/arm64 → sha:bbb  │
   └────────────────────────────┘
         │              │
         ▼              ▼
  manifest amd64   manifest arm64
   │                │
   ├─ config amd64  ├─ config arm64
   ├─ layer         ├─ layer
   └─ layer         └─ layer
```

Cuando haces `docker pull app:v1` en un host `linux/arm64`, el cliente:

1. Pide el blob del tag → recibe el índice.
2. Busca en `manifests[]` la entrada cuya `platform` matchea su `runtime.GOOS` + `GOARCH` + opcionalmente `variant` (`v7`, `v8`).
3. Baja **solo esa** cadena de manifest → config → capas.

Las capas del amd64 **no** se descargan al host arm64. No pagas por lo que no vas a correr.

---

## 4. Por qué el `docker` driver no basta: `buildx` y los drivers

El builder clásico de Docker (`dockerd` + BuildKit embebido, driver `docker`) **no puede** producir ni empujar un índice multi-arch en una sola invocación. Técnicamente lo que faltaba era el *exporter* OCI multi-plataforma, que vive en BuildKit pero el driver `docker` no lo expone.

`docker buildx` resuelve esto exponiendo varios **drivers**:

| Driver              | Dónde corre BuildKit                                   | Soporta multi-arch push | Cuándo usarlo |
|---------------------|--------------------------------------------------------|-------------------------|---------------|
| `docker`            | BuildKit embebido en `dockerd`                         | NO                      | Builds locales mono-arch. Es el default. |
| `docker-container`  | BuildKit en un contenedor efímero (`moby/buildkit`)    | **SÍ**                  | Default recomendado para multi-arch. |
| `kubernetes`        | BuildKit como `Deployment` en un cluster K8s           | SÍ                      | CI corporativo que ya corre en K8s. |
| `remote`            | BuildKit sobre un endpoint TCP/socket arbitrario       | SÍ                      | Flotas de builders dedicados (p. ej. uno por arch). |

Crear un builder `docker-container` es una vez:

```bash
docker buildx create --name multi --driver docker-container --use
docker buildx inspect --bootstrap     # arranca el contenedor y lista plataformas
```

Después, tus `docker buildx build …` usan ese builder por default.

---

## 5. QEMU vs cross-compilation nativa vs native runners

Para construir `linux/arm64` **desde un host `linux/amd64`** necesitas que *algo* ejecute las instrucciones ARM. Hay tres estrategias:

### 5.1 Emulación con QEMU (user-mode)

El kernel de Linux soporta **binfmt_misc**: puedes registrar un *intérprete* para binarios de otra arquitectura. QEMU en modo *user* es ese intérprete: traduce instrucciones ARM a amd64 en user-space.

El paquete `tonistiigi/binfmt` instala estos hooks de forma portátil:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

En Docker Desktop (macOS/Windows) QEMU ya viene instalado dentro de la VM Linux. En Linux puro necesitas correr el comando anterior una vez por boot (o persistir).

**Trade-off**: QEMU es *lento*. Puede ser 5–20× más lento que nativo para builds que compilan C/Rust/Go pesado. Para builds que solo *copian* archivos (p. ej. Python puro, Node, static sites) la penalización es menor pero existe.

### 5.2 Cross-compilation nativa

Para lenguajes que compilan a múltiples objetivos (Go, Rust, Zig, C con cross-toolchain), construyes en el host nativo (`amd64`) y produces binarios para `arm64` sin emular. Luego copias el binario al stage final.

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22 AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY . .
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /out/app ./cmd/app

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

Las ARGs mágicas (`BUILDPLATFORM`, `TARGETPLATFORM`, `TARGETARCH`, `TARGETOS`, `TARGETVARIANT`) las inyecta BuildKit automáticamente. `--platform=$BUILDPLATFORM` fuerza al stage `build` a correr en la arch del host (sin QEMU), y el compilador *cross-compila* al target.

**Ventaja**: build 5–20× más rápido. **Costo**: solo aplica a lenguajes con cross-compilation sana (no bien para Python con wheels compiladas por target).

### 5.3 Native runners por arch

El patrón de CI más rápido: tener **un runner por arquitectura** (p. ej. `ubuntu-latest` + `ubuntu-24.04-arm`). Cada runner construye su variante nativa, y un paso final combina los manifests con `docker buildx imagetools create` o `docker manifest create` apuntando a los digests de cada arch.

```
┌───────────┐   build amd64   ┌─────────────────┐
│ amd64 run │ ─────────────► │ ghcr.io/me/app  │
└───────────┘                  │ @sha256:aaa…    │
                               └─────────────────┘
┌───────────┐   build arm64              │
│ arm64 run │ ──────────────┐            │
└───────────┘               ▼            │
                     ┌─────────────────┐ │
                     │ ghcr.io/me/app  │ │
                     │ @sha256:bbb…    │ │
                     └─────────────────┘ │
                             │           │
                             └────┬──────┘
                                  ▼
                     docker buildx imagetools create \
                       -t ghcr.io/me/app:v1          \
                       ghcr.io/me/app@sha256:aaa… \
                       ghcr.io/me/app@sha256:bbb…
```

**Ventaja**: nativo en todas las arches. **Costo**: dos jobs de CI por release; la coordinación.

**Guía**: para aprender y para builds pequeños, QEMU. Para producción con builds costosos (C/Rust/Go grande), native runners o cross-compilation.

---

## 6. Flujo mínimo multi-arch con buildx (`--push`)

Un build multi-arch *solo* puede dirigirse a:

- Un registry (`--push`): el índice y los manifests se construyen y empujan.
- Un tarball OCI (`--output type=oci,dest=…`): guarda el índice en disco.

**No** se puede "cargar" un multi-arch al daemon local (`--load`) porque el daemon no sabe representar un índice como "una imagen local" (solo la variante del host, con `docker-container` driver + `--load --platform=…` individual).

Flujo canónico contra un registry (puede ser `registry:2` local, GHCR, Docker Hub…):

```bash
docker buildx create --name multi --driver docker-container --use --bootstrap
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5000/app:v1 \
  --push .
docker buildx imagetools inspect localhost:5000/app:v1
```

El inspect debe mostrar algo como:

```
Name:      localhost:5000/app:v1
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:xxxx…

Manifests:
  Name:        localhost:5000/app:v1@sha256:aaaa…
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64

  Name:        localhost:5000/app:v1@sha256:bbbb…
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
```

Dos manifests, dos plataformas, un tag. Lo esperado.

---

## 7. Inspección: `imagetools` vs `manifest inspect`

Dos herramientas, dos casos de uso.

- **`docker buildx imagetools inspect <ref>`** — la moderna. Muestra el índice, lista de plataformas, y acepta `--raw` para el JSON crudo. Funciona con registries OCI estándar y entiende índices.
- **`docker manifest inspect <ref>`** — la clásica. Requiere `experimental` habilitado en algunos entornos (`DOCKER_CLI_EXPERIMENTAL=enabled`). Útil cuando `imagetools` no está disponible.

Para ver un *manifest individual* (una variante mono-arch) a partir del índice:

```bash
docker buildx imagetools inspect localhost:5000/app:v1@sha256:aaaa… --raw
# JSON del manifest de esa plataforma: config + layers
```

Y para ver el *config* (donde vive `architecture`, `os`, env, cmd, labels y la historia del build) necesitas descargar el blob del config que figura en el manifest.

---

## 8. ¿Qué es "reproducibilidad" en builds de contenedor?

Un build es **reproducible** cuando, dados **los mismos inputs** (Dockerfile, contexto, versiones de base image, env relevantes), produce **bytes idénticos** → **digest idéntico** en cualquier máquina, cualquier día, cualquier builder.

Es un espectro, no un binario:

| Nivel        | Qué garantiza                                           | Técnicas                                             |
|--------------|---------------------------------------------------------|------------------------------------------------------|
| 0: default   | Digest cambia cada build.                              | Nada.                                                |
| 1: *stable*  | Dos builds consecutivos en la misma máquina → mismo digest. | Pin de base, `--provenance=false`.             |
| 2: *portable*| Dos builds en máquinas distintas → mismo digest.       | + `SOURCE_DATE_EPOCH`, `rewrite-timestamp=true`.     |
| 3: *bootstrap*| Reproducible desde cero sin tu caché.                 | + lockfiles de deps, mirrors inmutables, red offline.|

SLSA 3+ y Nix/Guix están arriba del nivel 3. Para la mayoría de proyectos CI/CD, llegar al **nivel 1–2** ya es un enorme salto y es el objetivo de este módulo.

---

## 9. Fuentes típicas de no-reproducibilidad

Cuando un build "no sale igual dos veces", el culpable es casi siempre una de estas:

1. **Base image flotante.** `FROM python:3.12-slim` apunta a un tag mutable: hoy baja el sha `aaa`, mañana `bbb` (una recompilación oficial). → **Fix**: `FROM python:3.12-slim@sha256:…`.

2. **`apt-get update` + `apt-get install` sin pin de versión.** El metadato de Debian se refresca; mañana `curl` es `7.88.1-10+deb12u5` en vez de `-u4`. → **Fix**: `apt-get install -y curl=7.88.1-10+deb12u4` o usar snapshot.debian.org.

3. **`pip install foo` sin lockfile.** Hoy `foo==1.2.3`, mañana `1.2.4`. → **Fix**: `requirements.txt` con hashes (`pip install --require-hashes -r …`), o `pip-tools`, `uv lock`, `poetry.lock`.

4. **Timestamps embebidos.** Capas de BuildKit llevan `created_at`; muchos tools (gzip, tar) escriben mtimes. → **Fix**: `SOURCE_DATE_EPOCH=<unix-ts>` + `--output type=…,rewrite-timestamp=true`.

5. **Comandos no deterministas en `RUN`.** `RUN date > /build-time`, `RUN uuidgen > /id`, `RUN pip install --upgrade pip` (sin pin). → **Fix**: eliminar o reemplazar por valor fijo derivado de `SOURCE_DATE_EPOCH`.

6. **Orden de `COPY` sobre un glob.** `COPY . .` depende del orden en que el filesystem entrega entradas de un `readdir()`. BuildKit normaliza esto, pero algunos `ADD` con `.tar.gz` extraen con orden del archivo. → **Fix**: `.dockerignore` estricto, builds desde `git archive` (orden canónico).

7. **Provenance y SBOM auto-adjuntos.** Buildx moderno (`buildkit ≥ 0.11`) adjunta por default una attestation de SLSA Provenance que incluye el timestamp del build. Esto *cambia* el índice. → **Fix para builds reproducibles**: `--provenance=false --sbom=false` (y generar provenance aparte en CI con un ts fijo si se necesita).

8. **Red durante el build.** Cualquier `RUN wget https://…` sin pin + checksum trae lo que esté *en ese momento*. → **Fix**: pins + `sha256sum -c`.

9. **Zona horaria / locale.** Programas que embeben `LC_TIME` o `TZ`. → **Fix**: `ENV TZ=UTC LC_ALL=C.UTF-8`.

10. **`COPY --chown` sobre uids que varían.** El uid numérico en el filesystem queda en los metadatos de capa. → **Fix**: usar uids fijos (`--chown=1000:1000`).

---

## 10. Herramientas para reproducibilidad

- **`SOURCE_DATE_EPOCH`** — convención [reproducible-builds.org](https://reproducible-builds.org): un entero Unix que *muchas* herramientas honran (gzip, tar, `strip --preserve-dates`, compiladores). BuildKit la usa para los timestamps de `created` en imágenes.

  ```bash
  export SOURCE_DATE_EPOCH=1700000000
  docker buildx build --build-arg SOURCE_DATE_EPOCH -t app:v1 .
  ```

- **`--output type=oci,…,rewrite-timestamp=true`** — en BuildKit ≥ 0.11, reescribe los timestamps dentro de las capas al valor de `SOURCE_DATE_EPOCH`, eliminando la última fuente de drift. Combinado con `--provenance=false --sbom=false`, es la receta estándar para "digest estable".

- **`--provenance=false --sbom=false`** — apaga las attestations auto-adjuntas que mutan el índice entre builds.

- **Pin de base por digest** — `FROM debian:bookworm-slim@sha256:…`. El digest se obtiene con `docker buildx imagetools inspect debian:bookworm-slim --format '{{ json .Manifest }}'` o `docker pull debian:bookworm-slim && docker inspect --format '{{index .RepoDigests 0}}' debian:bookworm-slim`.

- **Lockfiles de deps**:
  - Python: `pip-compile` → `requirements.txt` con hashes.
  - Node: `package-lock.json`, `pnpm-lock.yaml`.
  - Rust: `Cargo.lock`.
  - Go: `go.sum`.
  - OS: Debian/Ubuntu snapshot archives; Alpine `/etc/apk/world` + `apk fetch` cache.

- **`diffoci`** (opcional) — compara dos imágenes OCI capa por capa y señala exactamente qué difiere. Útil para auditar.

- **Builds reproducibles de Nix / Chainguard apko** — ya nacen reproducibles; el precio es un lenguaje de descripción distinto.

---

## 11. Receta reproducible (nivel 1–2)

Receta mínima que funciona en el 90 % de los proyectos:

```dockerfile
# syntax=docker/dockerfile:1.7

FROM python:3.12-slim@sha256:<pinned>

ARG SOURCE_DATE_EPOCH
ENV TZ=UTC LC_ALL=C.UTF-8 PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

COPY --chown=1000:1000 src/ ./src/
USER 1000:1000
CMD ["python", "-m", "src"]
```

Build:

```bash
export SOURCE_DATE_EPOCH=1700000000
docker buildx build \
  --provenance=false --sbom=false \
  --build-arg SOURCE_DATE_EPOCH \
  --output type=oci,dest=/tmp/out.tar,rewrite-timestamp=true \
  .
sha256sum /tmp/out.tar       # igual en dos corridas consecutivas
```

Si los dos `sha256sum` no coinciden, revisa la checklist de la §9.

---

## 12. Preguntas de evaluación

1. ¿Qué objeto OCI vive en el registry cuando publicas una imagen "multi-arch", y qué contiene exactamente?
2. ¿Por qué el driver `docker` por default no puede empujar un índice multi-plataforma, y qué driver sí puede?
3. Explica, paso a paso, qué pasa cuando un host `linux/arm64` ejecuta `docker pull app:v1` donde `app:v1` es un índice multi-arch.
4. Compara QEMU, cross-compilation nativa y native runners por arch. ¿Cuándo elegirías cada uno?
5. Enumera cinco fuentes de no-reproducibilidad en un build Docker típico. Para cada una, la corrección mínima.
6. ¿Qué hace exactamente `SOURCE_DATE_EPOCH` y por qué no basta por sí solo?
7. ¿Por qué `--provenance=false --sbom=false` suele ser necesario para que dos builds den el mismo digest? ¿Qué pierdes al desactivarlos?
8. Dado un Dockerfile con `FROM python:3-slim` y `RUN pip install flask`, lista todos los cambios que harías para que dos builds consecutivos produzcan el mismo digest.
