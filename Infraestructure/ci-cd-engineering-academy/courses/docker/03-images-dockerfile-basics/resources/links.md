# Recursos — `dkr-03-images-dockerfile-basics`

> Verificar fecha de consulta. La doc de Docker reestructura URLs ocasionalmente.

## Documentación oficial

- **Dockerfile reference** — referencia exhaustiva de cada instrucción. <https://docs.docker.com/reference/dockerfile/>
- **Best practices for writing Dockerfiles** — guía oficial de prácticas. <https://docs.docker.com/develop/develop-images/dockerfile_best-practices/>
- **About images, containers, and storage drivers** — modelo de capas y overlayfs. <https://docs.docker.com/storage/storagedriver/>
- **Build context** — qué es, cómo se transfiere, cómo recortarlo. <https://docs.docker.com/build/building/context/>
- **`.dockerignore` reference** — sintaxis y semántica. <https://docs.docker.com/engine/reference/builder/#dockerignore-file>
- **`docker build` CLI reference**. <https://docs.docker.com/reference/cli/docker/buildx/build/>
- **`docker image` CLI** (`inspect`, `history`, `ls`, `prune`). <https://docs.docker.com/reference/cli/docker/image/>

## OCI y especificaciones

- **OCI image-spec** — manifest, config, layers. <https://github.com/opencontainers/image-spec>
- **OCI runtime-spec** — cómo el runtime (runc) interpreta la config. <https://github.com/opencontainers/runtime-spec>
- **BuildKit** — builder de nueva generación; features modernos (cache mounts, secret mounts). <https://github.com/moby/buildkit>

## Herramientas de inspección y mejora

- **dive** — explorador interactivo de capas (ver qué se añade por capa, qué se desperdicia). <https://github.com/wagoodman/dive>
- **hadolint** — linter de Dockerfiles con reglas pedagógicas. <https://github.com/hadolint/hadolint>
- **container-structure-test** — tests declarativos sobre una imagen construida. <https://github.com/GoogleContainerTools/container-structure-test>
- **tini** — mini-init para contenedores (lo que inyecta `docker run --init`). <https://github.com/krallin/tini>

## Imágenes base relevantes

- **python Docker Official Image** — variantes `slim`, `alpine`, `windowsservercore`. <https://hub.docker.com/_/python>
- **Debian Docker Official Image** — base de `python:*-slim`. <https://hub.docker.com/_/debian>
- **Distroless** — imágenes mínimas sin shell/paquete manager (se cubre en `dkr-11`). <https://github.com/GoogleContainerTools/distroless>
- **Chainguard images** — alternativa commercial con updates agresivos (se cubre en `dkr-11`). <https://images.chainguard.dev/>

## Lectura complementaria

- *12-Factor App — Logs as streams* — justifica `PYTHONUNBUFFERED=1`. <https://12factor.net/logs>
- *12-Factor App — Processes* — por qué un proceso por contenedor. <https://12factor.net/processes>
- *Docker Blog — Dockerfile deep dives* — artículos oficiales. <https://www.docker.com/blog/tag/dockerfile/>
- *Phusion blog — Docker and the PID 1 zombie reaping problem* — origen del problema de señales. <https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/>

## En este curso

- Siguiente módulo: `dkr-04-storage-volumes-bind-mounts-tmpfs`.
- Optimización fina de caché y orden de instrucciones: `dkr-06`.
- Multi-stage builds + BuildKit (cache mounts, secret mounts): `dkr-07`.
- Publicación a registries y política de tagging: `dkr-09`.
- Elección de base image (slim vs alpine vs distroless): `dkr-11`.
- Hardening de runtime (capabilities, seccomp, read-only FS): `dkr-13`.
- SBOM, firma y provenance: `dkr-14`.
