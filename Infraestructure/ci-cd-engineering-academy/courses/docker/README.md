# Curso: Docker

Roadmap especializado #3. Containerización como base del empaquetado, el CI/CD moderno y la orquestación.

## 1. Introducción

### Qué es

**Docker** es una plataforma para construir, distribuir y ejecutar aplicaciones en **contenedores**: procesos aislados por primitivas del kernel de Linux (namespaces, cgroups, capabilities, seccomp, overlay filesystems) que empaquetan la aplicación junto con su userland (binarios, librerías, config) en una **imagen** reproducible y versionable.

Es importante separar tres cosas que suelen confundirse:

- **Imagen OCI**: artefacto inmutable (grafo de capas tar + manifest + config).
- **Contenedor**: proceso Linux aislado creado a partir de una imagen; estado efímero sobre un filesystem copy-on-write.
- **Docker**: una *implementación* específica de un motor de contenedores (CLI + daemon + builder). Hay otras: Podman, nerdctl, containerd+runc directamente.

### Historia (síntesis)

- **Pre-2013** — LXC, Solaris Zones, FreeBSD jails. Las primitivas (namespaces, cgroups) ya existían en Linux.
- **2013** — Docker lanza como wrapper ergonómico sobre LXC. Populariza el modelo *build-ship-run*.
- **2015** — Se crea la **Open Container Initiative (OCI)**: estandariza `image-spec`, `runtime-spec` y `distribution-spec`. Docker deja de ser monolítico; aparece **runc** (runtime de referencia) y después **containerd** (runtime de alto nivel, hoy en la CNCF).
- **2016** — Multi-stage builds; aparece Docker Compose.
- **2018+** — **BuildKit** como builder de nueva generación; luego habilitado por default.
- **2020–2022** — Kubernetes deprecia dockershim (usa containerd/CRI-O directamente); Docker Desktop se vuelve de pago para orgs grandes.
- **2023+** — Rootless, Wasm/WASI runtimes, firmas Sigstore nativas en el toolkit.

### Problemas que resuelve

- **"Funciona en mi máquina"**: el contenedor incluye todo el userland.
- **Densidad y arranque rápido**: a diferencia de VMs, no hay segundo kernel.
- **Portabilidad**: una imagen OCI corre en cualquier runtime compatible.
- **Reproducibilidad del build** (con disciplina: lockfiles, pins, SBOM, provenance).
- **Fundamento operacional de la orquestación** (K8s habla OCI, no "Docker").

### Casos de uso

- Empaquetado de servicios para CI/CD.
- Entornos de desarrollo locales reproducibles (Compose, devcontainers).
- Build hermético (toolchains como contenedores).
- Unidad desplegable en Kubernetes, ECS, Cloud Run, Nomad, etc.

### Arquitectura general

```
┌──────────────────────────────────────────────┐
│ CLI (docker)                                 │
└──────────────────────────────────────────────┘
                  │ REST (socket)
                  ▼
┌──────────────────────────────────────────────┐
│ dockerd (daemon)                             │
│   - API, image store, networks, volumes      │
│   - delega build a BuildKit                  │
└──────────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────┐
│ containerd (runtime de alto nivel)           │
│   - lifecycle, snapshots, pull/push          │
└──────────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────┐
│ runc / crun (runtime OCI)                    │
│   - crea el contenedor usando primitivas     │
│     del kernel: namespaces, cgroups, mount,  │
│     seccomp, capabilities                    │
└──────────────────────────────────────────────┘
```

El build moderno es responsabilidad de **BuildKit**, que mantiene su propio grafo DAG de operaciones, hace *remote cache*, *cache mounts*, *secret mounts*, soporta multi-plataforma (`buildx` + QEMU) y produce imágenes OCI con provenance opcional.

### Alternativas

- **Podman** — compatible CLI, daemonless, rootless-first.
- **nerdctl** — CLI estilo Docker directo sobre containerd.
- **Buildah** / **kaniko** / **BuildKit standalone** — solo build (útiles en CI sin daemon).
- **containerd + runc** sin Docker — opción cuando lo único que importa es ejecutar.
- **Chainguard images** / **distroless** — distribuciones de imágenes mínimas, no runtimes.

### Ventajas / limitaciones

**Ventajas**: ergonomía, ecosistema, *de facto* en CI/CD, documentación masiva, portable.

**Limitaciones / riesgos**:
- El daemon de Docker requiere root por default; una regresión en el daemon es una elevación de privilegio.
- Las imágenes "latest" o sin lockfiles rompen la reproducibilidad.
- Imágenes "base + apt-get update" rápidamente acumulan CVEs si no se reconstruyen.
- Hay fricción real con **GPUs**, **Wasm**, **macOS/Windows** (requieren VM intermedia).
- Compose en producción no sustituye un orquestador.

### Relación con el programa

- Base de **CI/CD** (D5) para builds reproducibles y publicación de artefactos a registries.
- Base de **Kubernetes** (D8): K8s solo entiende imágenes OCI.
- Base de **DevSecOps** (D9): escaneo, SBOM, firma, provenance se aplican sobre imágenes.
- Herramienta de desarrollo local para el **capstone** (Compose).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | T-2.1, T-2.2, T-2.4 (procesos, filesystem, permisos). Nociones básicas de Linux. |
| Recomendados | T-3.1, T-3.2 (networking básico). Un lenguaje para ejemplos (Python). |
| Complementarios | Curso **git-and-github** (para publicar imágenes a GHCR en Nivel 4). |

## 3. Organización (4 niveles)

El curso tiene **14 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5): modelo mental y OCI, primer contenedor, imágenes y Dockerfile básico, volúmenes, networking básico.
- **Nivel 2 — Intermedio** (4): Dockerfile idiomático y caché, multi-stage + BuildKit, Compose para desarrollo, registries y tags vs digests.
- **Nivel 3 — Avanzado** (3): internals (namespaces/cgroups/overlayfs), optimización (distroless, scratch, startup), multi-arch y reproducibilidad.
- **Nivel 4 — Producción empresarial** (2): hardening de runtime y seguridad; supply chain (escaneo, SBOM, firma, provenance).

## 4. Entregables del curso

- Imagen multi-stage de una app Python/FastAPI que arranca en < 500 ms y pesa menos de ~100 MB.
- Entorno de desarrollo local completo con Compose (app + Postgres + reverse proxy).
- Imagen multi-arch (amd64 + arm64) publicada a GHCR.
- Pipeline (en el curso **github-actions**) que construye, escanea con Trivy, firma con cosign, emite SBOM y attestation.
- Documento de decisión base image (debian-slim vs alpine vs distroless vs chainguard) con trade-offs justificados.

## 5. Evaluación

- **Conceptual**: diferenciar imagen vs contenedor vs capa; explicar qué hace `docker run` paso a paso en términos de syscalls y namespaces; distinguir volumen vs bind mount vs tmpfs.
- **Operativa**: escribir un Dockerfile multi-stage correcto que aproveche caché; depurar un contenedor que no arranca; mover una imagen entre dos hosts sin registry (`save`/`load`).
- **Arquitectónica**: justificar elección de base image, estrategia de tagging/digests, uso o no de Compose en prod, hosted builder vs self-hosted.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial: `docs.docker.com`.
- OCI specs: `image-spec`, `runtime-spec`, `distribution-spec` (github.com/opencontainers).
- BuildKit (`github.com/moby/buildkit`).
- Guía oficial *Dockerfile best practices*.
- Chainguard / distroless (`github.com/GoogleContainerTools/distroless`, `images.chainguard.dev`).
- Sigstore / cosign para firma y verificación.
