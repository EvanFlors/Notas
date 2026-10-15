# Recursos — dkr-04

## Documentación oficial

- **Manage data in Docker** (overview) — <https://docs.docker.com/storage/>
- **Volumes** — <https://docs.docker.com/storage/volumes/>
- **Bind mounts** — <https://docs.docker.com/storage/bind-mounts/>
- **tmpfs mounts** — <https://docs.docker.com/storage/tmpfs/>
- **`docker volume` reference** — <https://docs.docker.com/engine/reference/commandline/volume/>
- **`--mount` vs `-v`** — <https://docs.docker.com/storage/bind-mounts/#choose-the--v-or---mount-flag>
- **Volume drivers** — <https://docs.docker.com/engine/extend/plugins_volume/>
- **`VOLUME` Dockerfile instruction** — <https://docs.docker.com/reference/dockerfile/#volume>

## Imágenes usadas

- **postgres (official)** — <https://hub.docker.com/_/postgres>
- **busybox (official)** — <https://hub.docker.com/_/busybox>
- **alpine (official)** — <https://hub.docker.com/_/alpine>
- **python (official)** — <https://hub.docker.com/_/python>

## Permisos y UID/GID

- **Understand permission requirements for the host-mounted volume**
  (post del equipo de Docker, muy claro) — <https://docs.docker.com/engine/security/userns-remap/>
- **User namespaces en Docker** — <https://docs.docker.com/engine/security/userns-remap/>
- **SELinux `:z` / `:Z`** — <https://docs.docker.com/storage/bind-mounts/#configure-the-selinux-label>

## Lecturas complementarias

- Jérôme Petazzoni, *Container storage from the trenches* (busca charla en YouTube).
- Julia Evans, *What's in /var/lib/docker?* — <https://jvns.ca/blog/2016/08/10/a-few-things-i-learned-about-containers/>
- Pro Git-style, *Postgres official image internals* — leer el README del repo oficial: <https://github.com/docker-library/postgres>

## Herramientas útiles

- `docker system df` — para ver cuánto ocupan volúmenes huérfanos.
- `docker volume prune` — con cuidado; borra lo no usado.
- `dive` — <https://github.com/wagoodman/dive>, se usa a fondo en `dkr-11` pero sirve también para ver dónde escribe la imagen.

## A verificar en Fase 4

- Comportamiento actual de `userns-remap` con bind mounts.
- Rendimiento comparado de bind vs volume en Docker Desktop con **VirtioFS** vs **gRPC-FUSE**.
- Estado de volume plugins mantenidos para CSI equivalentes en Docker standalone.
