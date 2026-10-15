# Lección: Registries, tags y digests

> **ID:** `dkr-09-registries-tags-and-digests` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `dkr-03-images-dockerfile-basics`.

---

## 1. Introducción intuitiva

Construir una imagen en tu laptop es la mitad del trabajo. La otra mitad es **moverla a donde se necesita** — un servidor, un cluster de Kubernetes, el laptop de otro desarrollador — de forma que lo que arrancan *allá* sean exactamente los mismos bytes que probaste *aquí*.

El vehículo para eso es un **registry**: un servicio HTTP que almacena imágenes OCI y las sirve bajo demanda. `docker push` sube la imagen; `docker pull` la baja. Entre medio pasan cosas que si no entiendes te van a morder: cómo se nombran las imágenes, qué garantiza (y qué no) un tag, qué pasa cuando dos personas pushean `latest` el mismo día, y por qué `FROM python:3-slim` es cómodo pero peligroso.

El concepto central es incómodo pero liberador: **un tag es un alias mutable**. `nginx:1.25` hoy puede apuntar a un digest; mañana al mismo o a otro completamente distinto. Lo único verdaderamente inmutable es el **digest** — el hash criptográfico (`sha256:...`) del manifest de la imagen. Si en tu `Dockerfile` o en tu `deployment.yaml` escribes `nginx@sha256:<64 hex>`, estás pidiendo exactamente *esos* bytes, y ningún empujón externo puede cambiarlo.

Esta lección te enseña a *vivir con esa distinción*: cuándo usar tags (desarrollo, legibilidad), cuándo exigir digests (producción, reproducibilidad), y cómo diseñar una política que combine ambos sin volverte loco.

---

## 2. Fundamentos

### 2.1 Qué es un registry

Un **registry** es la implementación de referencia del **OCI distribution-spec**: una API HTTP para subir, bajar, listar y borrar artefactos OCI. Sus endpoints clave son:

```
GET  /v2/                                     ping / version
GET  /v2/<name>/manifests/<reference>         bajar manifest por tag o digest
PUT  /v2/<name>/manifests/<reference>         publicar manifest
GET  /v2/<name>/blobs/<digest>                bajar un layer o config blob
POST /v2/<name>/blobs/uploads/                iniciar upload
HEAD /v2/<name>/manifests/<reference>         ver digest sin descargar manifest
```

"Reference" en la URL puede ser un **tag** (`v1.2.3`) o un **digest** (`sha256:abc...`).

Un registry **no sabe de Docker**. Habla OCI. Por eso la misma imagen la pueden empujar y bajar `podman`, `nerdctl`, `buildah`, `skopeo`, `crane`, Kubernetes (vía containerd), etc.

### 2.2 Imagen = manifest + config + layers

Cuando pusheas una imagen, el registry recibe tres tipos de blobs:

- **Layers** (tarballs comprimidos de cambios al filesystem) — uno por capa.
- **Config** (JSON pequeño con metadata: `env`, `cmd`, `entrypoint`, labels, timestamps, orden de capas).
- **Manifest** (JSON pequeño que enumera: digest y tamaño de la config, y digest+tamaño de cada layer).

El **digest de la imagen** (lo que ves como `sha256:...`) es el **hash SHA-256 del manifest**. Cambia un byte en una layer, cambia el digest de esa layer, cambia el manifest, cambia el digest de la imagen. Es una cadena Merkle de integridad.

```
┌──────────────────────────────┐
│ Manifest  (sha256:abc...)    │  ← el "digest" de la imagen
│  ├─ config digest + size     │
│  └─ layers:                  │
│     - sha256:111... size     │
│     - sha256:222... size     │
│     - sha256:333... size     │
└──────────────────────────────┘
             │ apunta a
             ▼
┌──────────────────────────────┐
│ Config JSON (sha256:ccc...)  │
│  env, cmd, entrypoint, ...   │
└──────────────────────────────┘
```

### 2.3 Qué es un tag

Un **tag** es simplemente **una etiqueta humana ligada a un digest**. En el registry, `nginx:1.25` y `nginx@sha256:abc...` apuntan al mismo objeto *en este momento*. El registry mantiene un mapping `nombre:tag → digest`.

El punto clave: **un tag se puede re-apuntar**. Si mañana el equipo de nginx hace `docker push nginx:1.25` con una build más nueva, el mapping se actualiza y `nginx:1.25` ya no significa los mismos bytes. El digest viejo *puede* seguir en el registry (si no fue garbage-collected), pero el tag ya no lo señala.

### 2.4 Qué es un digest

Un **digest** es `sha256:<64 caracteres hex>`. Es el hash del manifest. Es **inmutable por construcción**: pedir `image@sha256:abc...` siempre devuelve los mismos bytes, o un 404 si fueron borrados. No existe el "re-apuntar un digest".

El digest tiene dos sabores que a veces confunden:
- **Manifest digest** — el que ves en `RepoDigests` y en `image@sha256:...`. Es el que cuenta para reproducibilidad.
- **Layer digest** — el hash de cada layer individual. Útil para debugging, no para referenciar la imagen.

### 2.5 Namespace y nombre completo

Un nombre de imagen completo tiene esta forma:

```
<registry-host>[:<port>]/<namespace>/<repo>[:<tag>|@<digest>]
```

Ejemplos:

| Nombre | Registry | Namespace | Repo | Ref |
|--------|----------|-----------|------|-----|
| `nginx:1.25` | `docker.io` (default) | `library` (default) | `nginx` | `:1.25` |
| `python:3.12-slim` | `docker.io` | `library` | `python` | `:3.12-slim` |
| `myuser/webapp:v1` | `docker.io` | `myuser` | `webapp` | `:v1` |
| `ghcr.io/myorg/api:sha-abc1234` | `ghcr.io` | `myorg` | `api` | `:sha-abc1234` |
| `123.dkr.ecr.us-east-1.amazonaws.com/svc:v2` | `ECR` | (cuenta) | `svc` | `:v2` |
| `us-docker.pkg.dev/proj/repo/app@sha256:abc...` | Artifact Registry | `proj/repo` | `app` | `@sha256:...` |

Docker CLI expande los nombres cortos: `nginx` → `docker.io/library/nginx:latest`. Fuera de Docker Hub, **siempre** se escribe el nombre completo. En producción, no usar nombres cortos ayuda a dejar explícito de dónde viene cada bit.

### 2.6 El rol del `latest`

`latest` es solo un **tag con un nombre convencional**. No tiene magia. Si nadie pusheó `foo:latest`, no existe. Si varios equipos pushean `foo:latest` en orden, el último gana. Convertirlo en "la última versión estable" es una decisión *del publisher*. Como consumidor, confiar en `latest` significa aceptar que mañana puede ser otro código.

---

## 3. Contexto histórico

- **~2013** — Docker Hub nace como el único registry; el modelo `pull/push` por tag define la ergonomía que todos copiarían.
- **2015** — OCI publica `image-spec` y `distribution-spec`; el formato y la API se estandarizan. Deja de ser "lo que haga Docker".
- **2016** — Aparecen GCR (Google Container Registry) y ECR (Elastic Container Registry) ofreciendo registries manejados.
- **2017** — Harbor (CNCF) sale como registry self-hosted con RBAC, replicación y vulnerability scanning integrado.
- **2018–2020** — Multi-arch via **manifest list** (fat manifest / OCI image index): un `nginx:1.25` apunta en realidad a un *índice* con una entrada por plataforma. Transparente para el consumidor.
- **2020** — Docker Hub introduce **rate limits**: 100 pulls / 6 h anónimos, 200 autenticados, repos free. El ecosistema reacciona moviendo bases a GHCR, ECR Public, Quay, etc.
- **2020** — GitHub Container Registry (GHCR) GA. Namespaces atados a usuarios/orgs de GitHub, visibility heredada o explícita, integración con `GITHUB_TOKEN`.
- **2021–2023** — Sigstore / cosign publica firmas y attestations *como artefactos OCI* adosadas al mismo repo del registry, usando el mismo `/v2/` protocol.
- **2024–2026** — Immutable tags opt-in en varios registries (GHCR, ECR, Harbor); replicación cross-registry madura; soporte para artefactos no-imagen (Helm charts, policies, SBOMs) sobre el mismo spec.

---

## 4. Funcionamiento interno

### 4.1 Qué pasa en un `docker push`

Supongamos `docker push ghcr.io/myorg/app:v1.2.3`. El cliente:

1. **Resuelve credenciales** desde `~/.docker/config.json` (o un credential helper como `docker-credential-osxkeychain`).
2. **Pide a cada layer local**: ¿tu digest existe ya en `ghcr.io/myorg/app`? (`HEAD /v2/myorg/app/blobs/sha256:...`). Si existe (**cross-repo mount** o layer compartido), *no* re-sube.
3. **Sube los layers faltantes** por chunked upload (`POST /v2/.../blobs/uploads/`).
4. **Sube el config blob** si falta.
5. **Publica el manifest** apuntando a esos digests (`PUT /v2/myorg/app/manifests/v1.2.3`).
6. El registry calcula y devuelve el **digest del manifest** en el header `Docker-Content-Digest: sha256:...`. Ese es el digest canónico de la imagen.

Si pusheaste con un tag, el registry *también* mapea `v1.2.3 → sha256:...`. Si ya existía `v1.2.3` apuntando a otro digest, se re-apunta (salvo que el registry tenga *immutable tags* activo).

### 4.2 Qué pasa en un `docker pull`

Supongamos `docker pull ghcr.io/myorg/app:v1.2.3`:

1. **Resuelve credenciales** y hace `GET /v2/myorg/app/manifests/v1.2.3`.
2. El registry responde con el manifest JSON y el header `Docker-Content-Digest: sha256:abc...`.
3. El cliente **recuerda ese digest** (lo verás en `docker inspect` → `RepoDigests`).
4. Para cada layer en el manifest: si no está localmente, `GET /v2/myorg/app/blobs/<layer-digest>` y lo descarga.
5. Si pediste por **digest** (`@sha256:...`), el paso 1 es `GET /v2/.../manifests/sha256:...` y el registry devuelve exactamente esos bytes (o 404).

Dos consecuencias clave:

- **Pullear por tag**: hoy traes X; mañana el mismo comando puede traer Y. Aún así `docker inspect` te dice el digest *que trajiste*, por eso es útil para reconstruir qué corre un host.
- **Pullear por digest**: idempotente para siempre (mientras el blob exista en el registry).

### 4.3 Multi-arch con manifest list

Cuando bajas `nginx:1.25` en una Mac M-series y en una laptop x86, Docker pide `nginx:1.25` y recibe un **manifest list / OCI image index**: un JSON pequeño con una entrada por plataforma (amd64, arm64, arm/v7, …). El cliente elige la que corresponde a su arquitectura y pide *ese* manifest y sus layers.

El digest del manifest list y el digest del manifest por-arch **son distintos**. Si pines `nginx@sha256:<digest-del-index>`, estás pineando el *índice* (y por tanto todas las arquitecturas). Si pines el digest de un manifest por-arch, pines solo una arquitectura. Para producción multi-arch suele ser el índice. Detalle completo en `dkr-12`.

### 4.4 Rate limits de Docker Hub

Docker Hub impone límites a `pull` por IP (anónimo) o por cuenta (autenticado):

- **Anónimo**: ~100 pulls / 6 h por IP (en NAT corporativo, se agota rápido).
- **Autenticado free**: ~200 pulls / 6 h.
- **Pro/Team/Business**: más altos o ilimitados.

Síntomas: `TOOMANYREQUESTS` o `pull access denied`. Mitigaciones:
- Autenticar incluso contra pulls públicos (`docker login`).
- **Mirror / pull-through cache** (p. ej., Harbor en modo proxy, ECR Pull Through Cache, Artifact Registry remote repo). Pulleas una vez por IP egress, los runners del cluster pullean del mirror interno.
- Mover **imágenes base** fuera de Docker Hub: `cgr.dev/chainguard/python`, `gcr.io/distroless/python3-debian12`, etc.

### 4.5 Autenticación: `docker login`

`docker login <registry>` pide usuario y password/token y los guarda (idealmente en el keychain del SO) referenciando el host en `~/.docker/config.json`. A partir de ahí, cualquier `pull/push` contra ese host usa esas credenciales.

En CI:

- **GHCR desde GitHub Actions**: `echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin`. Requiere `permissions: packages: write` a nivel workflow o job.
- **ECR**: `aws ecr get-login-password | docker login --username AWS --password-stdin <acct>.dkr.ecr.<region>.amazonaws.com` (el password es efímero, 12 h).
- **Artifact Registry**: `gcloud auth configure-docker` configura un credential helper que inyecta tokens OAuth automáticamente.
- **Harbor / Nexus / autogestionado**: `docker login <host>` con usuario y password del registry.

### 4.6 Pull secrets en orquestadores

Un cluster de Kubernetes que necesita pullear de un registry privado no tiene `~/.docker/config.json`. Se le pasa un **imagePullSecret**: un `Secret` de tipo `kubernetes.io/dockerconfigjson` con las credenciales, referenciado desde el `ServiceAccount` o directamente desde el `Pod`.

```yaml
apiVersion: v1
kind: Secret
metadata: { name: ghcr-pull }
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64 de ~/.docker/config.json>
---
apiVersion: v1
kind: Pod
spec:
  imagePullSecrets:
    - name: ghcr-pull
  containers:
    - name: app
      image: ghcr.io/myorg/app@sha256:abc...   # ← pin por digest
```

### 4.7 Housekeeping local

Un desarrollador que construye imágenes acumula gigas en días. Comandos clave:

- `docker system df` — resumen de uso (imágenes, contenedores, volúmenes, build cache).
- `docker image ls [--digests]` — listar; `--digests` muestra el digest asociado al tag.
- `docker image prune` — elimina *dangling* (imágenes sin tag). `--all` elimina todas las no usadas por contenedores vivos; **ten cuidado**.
- `docker builder prune` — libera el build cache de BuildKit.
- `docker image rm <id|name>` — borra una imagen específica.

En CI con runners estáticos, un `docker system prune -af --volumes` nocturno evita que el disco se llene.

---

## 5. Ejemplo mínimo

Supongamos que ya tienes una imagen local llamada `app:dev` construida con `docker build -t app:dev .`. El flujo mínimo contra un registry en `localhost:5000` (que es lo que el `example/01` monta por ti):

```bash
# 1) Levantar un registry efímero (una sola vez; igual que `nginx` como servicio)
docker run -d --rm --name local-registry -p 5000:5000 registry:2

# 2) Taggear la imagen con el nombre completo del registry destino
docker tag app:dev localhost:5000/evan/app:v1.0.0

# 3) Push
docker push localhost:5000/evan/app:v1.0.0

# 4) Resolver su digest canonico (RepoDigests contiene registry/name@sha256:...)
docker inspect --format '{{index .RepoDigests 0}}' localhost:5000/evan/app:v1.0.0
# → localhost:5000/evan/app@sha256:<64 hex>

# 5) Pullear por digest (demuestra que es independiente del tag)
docker pull localhost:5000/evan/app@sha256:<64 hex>

# 6) Limpieza
docker stop local-registry
docker rmi localhost:5000/evan/app:v1.0.0 || true
```

El resultado útil es el **digest** (`sha256:<64 hex>`). Ese string es lo que pegarías en un `deployment.yaml` o en un `FROM` de otro Dockerfile si quisieras garantizar reproducibilidad binaria.

---

## 6. Implementación progresiva

Ahora sumemos una **estrategia de tagging**. Un build de CI produce *varios tags* para la misma imagen — unos inmutables, otros mutables. Esto permite servir a dos audiencias:

- A **humanos** (devs leyendo logs, reviewers): tags legibles (`v1.2.3`, `latest`).
- A **máquinas** (deploys, otros Dockerfiles): digests o tags inmutables (`sha-abc1234`).

```bash
# Supongamos: git commit 7f3a1b2c en rama main, versión semver v1.2.3
IMAGE=ghcr.io/myorg/app
GIT_SHA=$(git rev-parse --short HEAD)     # 7f3a1b2
VERSION=v1.2.3

docker build -t "$IMAGE:$VERSION" -t "$IMAGE:v1.2" -t "$IMAGE:v1" \
             -t "$IMAGE:latest" -t "$IMAGE:sha-$GIT_SHA" .

# Push de todos los tags
docker push "$IMAGE" --all-tags
# o uno a uno si prefieres control explicito
```

Resultado conceptual en el registry:

```
sha256:abc...      ← mismo manifest, cinco alias
  ├─ v1.2.3    (inmutable: nunca se re-apunta)
  ├─ sha-7f3a1b2    (inmutable: 1:1 con un commit)
  ├─ v1.2      (mutable: se mueve con cada 1.2.x)
  ├─ v1        (mutable: se mueve con cada 1.x)
  └─ latest    (mutable: puntero al "actual")
```

En producción pintes **por digest** (resuelto de `docker inspect` o del output del build). En staging o dev puedes pintar por `v1.2` o `latest` y aceptar la mutabilidad.

### 6.1 La misma idea en GitHub Actions

Un workflow idiomático en el ecosistema moderno usa `docker/metadata-action` para generar la matriz de tags automáticamente y `docker/build-push-action` para construir y pushear:

```yaml
name: publish
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha,prefix=sha-
            type=raw,value=latest,enable={{is_default_branch}}

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

El output de `docker/build-push-action` incluye el **digest** publicado, que puedes propagar al step de deploy para pinnear por digest sin tocar un tag.

---

## 7. Aplicación profesional

### 7.1 Elección de registry

| Registry | Cuándo tiene sentido |
|----------|----------------------|
| **Docker Hub** | Imágenes públicas de proyectos open source; comunidad lo busca ahí. Para privado: rate limits y costo lo hacen menos atractivo. |
| **GHCR** (`ghcr.io`) | Si el código vive en GitHub. Namespacing por usuario/org, visibility heredada, auth nativa desde Actions con `GITHUB_TOKEN`. Default natural del ecosistema moderno. |
| **ECR** | Workloads en AWS. IAM nativo, encryption at rest, replicación cross-region, Pull Through Cache para proxiear Docker Hub/GHCR/Quay. ECR Public para open source sin rate limits. |
| **Artifact Registry** (GCP) | Workloads en GCP. OAuth, Workload Identity Federation, remote repos (equivalente a pull-through). |
| **Harbor** | Self-hosted (compliance, air-gap, control total). RBAC fino, replicación, Trivy integrado, retention policies. CNCF. |
| **Quay** / **Nexus** / **JFrog** | Entornos corporativos ya invertidos en el proveedor. |

Reglas prácticas:
- Repo en GitHub, equipo pequeño → **GHCR**.
- Deploy en AWS → **ECR** (y mirror a GHCR si quieres artefactos públicos).
- Air-gap, compliance regulado → **Harbor**.
- Imágenes públicas de un proyecto open source → **Docker Hub** + mirror a GHCR/Quay.

### 7.2 Política de tagging recomendada

Para servicios versionados semver:

| Tag | Mutabilidad | Para qué sirve |
|-----|-------------|----------------|
| `vX.Y.Z` | **Inmutable** (política + idealmente *immutable tags* del registry) | Release reproducible. Lo que firma un release. |
| `sha-<git-sha>` | **Inmutable** (1:1 con un commit) | Trazabilidad commit↔imagen. Útil en deploys por GitOps. |
| `vX.Y` | Mutable (se mueve con cada 1.2.x) | Pin "parche menor" para equipos consumidores. |
| `vX` | Mutable (se mueve con cada 1.x) | Pin "major" para libraries base. |
| `latest` | Mutable (puntero al actual estable de `main`) | Legibilidad en demos; **nunca** en producción. |
| `edge` / `main` | Mutable (último de la rama principal) | Entornos de integración. |
| `pr-<n>` | Mutable (último build de ese PR) | Preview environments. |

En producción, el deploy referencia **por digest**, resuelto en el momento del push y propagado al deploy. Los tags son para humanos.

### 7.3 Por qué `FROM python:3-slim` es un riesgo

`python:3-slim` es un tag *doblemente mutable*:
- `3` sigue el major; mañana puede ser 3.12 → 3.13 (cambio potencialmente breaking en libs con extensiones C, deprecaciones, nuevo `sys.path`).
- `-slim` sigue el canal "slim" (Debian base reducido); una rebuild cambia versiones de glibc, OpenSSL, zlib.

Consecuencias en producción:
- Dos builds consecutivos del *mismo* `Dockerfile`, *mismo* código, pueden producir **digests distintos** porque la base cambió entre pulls. Reproducibilidad binaria rota.
- Un CVE parchado "automáticamente" también es un cambio no auditado. En ciertos marcos de compliance (SOC 2, FedRAMP), un cambio en el runtime binario debe trazarse: `3-slim` lo oculta.
- Un build que funcionaba el martes puede fallar el jueves porque un paquete transitivo asume glibc 2.36 y la base rebuildeó a 2.37 con un symbol que removieron.

Mitigación: pinnear la base **por digest** (`FROM python@sha256:...`) y rotarlo *conscientemente* vía PR, idealmente con un bot (Dependabot / Renovate) que abre PRs con el nuevo digest y dispara CI/scan antes de merger.

---

## 8. Trade-offs

### 8.1 Tags vs digests

| | Tag (`:v1.2`) | Digest (`@sha256:...`) |
|---|---------------|------------------------|
| Legibilidad | Alta | Nula |
| Mutabilidad | Sí (riesgo) | No |
| Útil en logs humanos | Sí | Mucho menos |
| Útil en manifiestos de deploy | No (en prod) | Sí |
| Útil en `FROM` del Dockerfile base | Para dev | Para prod |
| Actualización | Automática (puede sorprender) | Explícita (PR + review) |

Regla: *todo lo que sirve para humanos en tag; todo lo que corre en producción, en digest*.

### 8.2 Immutable tags (feature de registry)

Varios registries (GHCR, ECR, Harbor) permiten activar **immutable tags**: una vez pusheado, el tag no se puede re-apuntar ni borrar. Útil si quieres que `vX.Y.Z` *imponga* su inmutabilidad y no dependa solo de la disciplina. Trade-off: no puedes "rollback" un tag; necesitas un tag nuevo. Es sano.

### 8.3 Público vs privado

| | Público | Privado |
|---|---------|---------|
| Rate limits en Docker Hub | Peor (anónimos) | Mejor (autenticado forzado) |
| Costo | Suele ser gratis | Pay-per-GB-mes (ECR, GHCR >1 GB) |
| Auditoría de consumo | Nula | Logs de pull por identidad |
| Discoverability | Alta (bueno OSS, malo producto) | Nula |

### 8.4 Un registry vs muchos

Varias orgs mantienen **mirrors** en más de un registry (p. ej., publican a GHCR y a Docker Hub). Pros: resiliencia (si uno cae, el otro sirve), rate-limit relief, geo-latencia. Contras: duplicación de pipeline, drift entre mirrors si el push es desincronizado, costo doble.

En producción, un patrón común es: **publicar a 1 registry autoritativo** (GHCR, ECR) y **replicar automáticamente** a mirrors via feature del registry (Harbor replication, ECR cross-region replication, Artifact Registry remote repos).

---

## 9. Errores frecuentes

### 9.1 Usar `latest` en producción

`latest` es un tag mutable como cualquier otro, con un nombre engañoso. Dos deploys consecutivos de "la misma imagen" pueden traer bytes distintos. En Kubernetes además hay interacciones feas con `imagePullPolicy: Always` vs `IfNotPresent`. Pin por digest o por tag inmutable (`vX.Y.Z`).

### 9.2 `FROM lenguaje:canal-slim` sin digest

Variante del anterior. Cada rebuild puede traer una base distinta y romper reproducibilidad. Pin a `FROM lenguaje@sha256:...`.

### 9.3 Olvidar que un `docker push` sin tag empuja `latest`

`docker tag miapp registry/user/miapp` (sin `:tag`) crea `registry/user/miapp:latest`. Si pretendías publicar `v1.2.3` pero olvidaste el tag, acabas de reescribir el `latest` de alguien.

### 9.4 Confiar en que el registry conservará el digest antiguo

Un `docker push` que re-apunta `v1.2.3` **no** garantiza que el digest antiguo persista. Depende de la retention policy del registry y de si otro tag o referencia lo mantiene vivo. Si necesitas el bit exacto para siempre, **no reescribas tags inmutables**.

### 9.5 Pushear credenciales dentro de la imagen

`COPY .npmrc ./` con un token adentro queda **en una capa**, y la capa queda en el registry. Aunque borres la capa en un stage posterior, el stage del builder *también* se publica si no usas multi-stage correctamente, o si no limpias cache. Para secrets de build usa `--mount=type=secret` (ver `dkr-07`).

### 9.6 Confundir "image ID" local con digest del registry

`docker images` muestra una columna *IMAGE ID* — es el SHA256 de la **config local**, calculado localmente. **No es** el digest del manifest en el registry. Para el digest real: `docker inspect --format '{{index .RepoDigests 0}}' <ref>` *después de un pull/push*.

### 9.7 Rate-limit sorpresa en CI

Un pipeline que corre matriz `python:3.11, 3.12, 3.13` × 10 PRs × 20 pushes/día = cientos de pulls a Docker Hub por IP egress del runner. En GitHub-hosted runners se agotan los 100/6h anónimos rápido. Autenticar o migrar a GHCR/ECR Public resuelve.

### 9.8 Borrar un tag en Docker Hub pensando que "libera" el bit

Borrar un tag solo quita el alias. Los blobs quedan hasta que un *garbage collect* corra. Si tu modelo mental es "borrar = desaparece", te equivocas en términos de supply chain.

### 9.9 `imagePullPolicy: Always` + tag mutable + rolling update

En Kubernetes, con `Always` + `nginx:1.25`, cada reinicio de pod puede traer un digest distinto a mitad de un rollout. Resultado: dos pods del mismo deployment corriendo versiones distintas durante minutos. Pin por digest **o** `imagePullPolicy: IfNotPresent` + tag inmutable.

---

## 10. Buenas prácticas

- **Pin de producción por digest, siempre**. Resuelve el digest tras el push, propágalo al deploy.
- **Al menos un tag inmutable por release** (`vX.Y.Z`), activando *immutable tags* en el registry si el proveedor lo soporta.
- **Un tag `sha-<git>` 1:1 con el commit** para trazabilidad.
- **`latest` solo como puntero convencional**, nunca referenciado por producción.
- **Autenticar incluso para pulls públicos** si tu CI va contra Docker Hub (ahorra rate-limits).
- **Mirror / pull-through cache** para bases muy usadas en clusters grandes.
- **Base images también por digest** y rotación por PR (Renovate / Dependabot).
- **Limpieza periódica** en runners (`docker system prune -af --volumes` nocturno).
- **Metadata OCI estándar** (`org.opencontainers.image.*` labels: source, revision, created, licenses) para que las herramientas de supply chain reconozcan la imagen (ver `dkr-14`).
- **Nunca metas secrets en la imagen**. Para secrets de build, `--mount=type=secret`; para secrets de runtime, el orquestador los inyecta.

---

## 11. Ejercicios recomendados

1. **`examples/01-push-to-ghcr/`** — login + tag + push, dual-mode. En `MODE=local` monta un `registry:2` propio en `localhost:5000` y hace el ciclo completo; en `MODE=live` empuja a GHCR.
2. **`examples/02-pin-by-digest/`** — pullea una imagen por tag, resuelve su digest, re-pullea por `@sha256:...`, compara, y limpia.
3. **`activities/01-publish-and-consume-your-image/`** — **guided-lab, dual-mode**. Construyes una imagen pequeña, la publicas, resuelves el digest, la consumes por digest. El validador verifica el ciclo contra `localhost:5000`.
4. **`activities/02-tag-strategy-design/`** — **independent**. Escribes un ADR (`tag-strategy.md`) para un escenario dado, justificando qué tags inmutables, cuáles mutables, qué pin de producción, y qué rotación de bases.

---

## 12. Evaluación

Responde sin consultar la lección.

**P1.** Explica en tus palabras la diferencia entre un tag y un digest. ¿Por qué un tag es un "alias mutable" y por qué eso puede romper reproducibilidad?

**P2.** Un compañero dice: "ya tengo `nginx:1.25` en el deploy, está pinneado a la versión". ¿Qué le respondes y qué le propones cambiar?

**P3.** Un `docker pull python:3-slim` el martes y otro el jueves pueden traer bytes distintos. Da **dos razones** concretas por las que esto puede pasar.

**P4.** Describe el ciclo completo de un `docker push ghcr.io/me/app:v1`:
   - qué pasa con los layers que ya existen en el registry,
   - cómo se calcula el digest final,
   - qué pasa con el tag si ya existía apuntando a otro digest.

**P5.** Diseña una política de tags (mínimo cuatro tags) para un servicio HTTP interno versionado semver, publicado a GHCR, consumido por un cluster Kubernetes. Justifica cada tag con una frase.

**P6.** Un pod en Kubernetes tiene `image: ghcr.io/me/api:v2` e `imagePullPolicy: Always`. Durante un rolling update observas pods del mismo deployment respondiendo *diferente*. Enuncia la causa más probable y la solución mínima.

**P7.** Rate limits de Docker Hub: enumera dos estrategias para que un cluster de 50 nodos consumiendo `nginx:1.25` no agote el límite anónimo.

**P8.** Explica por qué `FROM python:3-slim` en una imagen de producción es un riesgo. Da al menos tres razones específicas (reproducibilidad, auditoría, breakage).

**P9.** Un atacante pushea una imagen distinta al tag `latest` de un repo privado al que tuvo acceso temporal. ¿Qué mitigaciones defensivas (en el registry y en el deploy) habrían evitado que esa imagen llegara a producción?

**P10.** `docker inspect <ref>` muestra `Id: sha256:aaa...` y `RepoDigests: [registry/x/y@sha256:bbb...]`. ¿Son el mismo digest? ¿Por qué? ¿Cuál usarías para pinnear producción?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *OCI distribution-spec*. <https://github.com/opencontainers/distribution-spec>
- *OCI image-spec*. <https://github.com/opencontainers/image-spec>
- *Docker Hub rate limits*. <https://docs.docker.com/docker-hub/download-rate-limit/>
- *Working with the Container registry (GHCR)*. <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- *Amazon ECR private registry*. <https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html>
- *Artifact Registry overview (GCP)*. <https://cloud.google.com/artifact-registry/docs/overview>
- *Harbor documentation*. <https://goharbor.io/docs/>
- *registry:2 image (reference distribution)*. <https://hub.docker.com/_/registry>
- *docker/metadata-action*. <https://github.com/docker/metadata-action>
- *docker/build-push-action*. <https://github.com/docker/build-push-action>

Lectura complementaria:

- *The OCI image specification, explained*. <https://docs.docker.com/registry/spec/manifest-v2-2/>
- Chainguard Images — bases pinnables por digest con rebuild diario. <https://images.chainguard.dev/>
- Renovate — automatiza rotación de digests en Dockerfiles. <https://docs.renovatebot.com/docker/>
