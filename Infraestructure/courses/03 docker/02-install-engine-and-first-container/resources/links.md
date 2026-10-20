# Recursos — dkr-02

## Documentación oficial

- **Instalación de Docker Engine** — <https://docs.docker.com/engine/install/>
- **Docker Desktop** — <https://docs.docker.com/desktop/>
- **Post-install Linux (grupo docker, rootless)** — <https://docs.docker.com/engine/install/linux-postinstall/>
- **Rootless mode** — <https://docs.docker.com/engine/security/rootless/>
- **`docker run` reference** — <https://docs.docker.com/reference/cli/docker/container/run/>
- **`docker ps`** — <https://docs.docker.com/reference/cli/docker/container/ls/>
- **`docker logs`** — <https://docs.docker.com/reference/cli/docker/container/logs/>
- **`docker exec`** — <https://docs.docker.com/reference/cli/docker/container/exec/>
- **`docker stop` / `kill`** — <https://docs.docker.com/reference/cli/docker/container/stop/>
- **`docker inspect`** — <https://docs.docker.com/reference/cli/docker/inspect/>
- **Formatting output (Go templates)** — <https://docs.docker.com/engine/cli/formatting/>
- **Logging drivers** — <https://docs.docker.com/engine/logging/>
- **Restart policies** — <https://docs.docker.com/engine/containers/start-containers-automatically/>

## PID 1, señales y `tini`

- **`tini` (upstream)** — <https://github.com/krallin/tini>
- **Why your Dockerized app isn't receiving signals (background)** — buscar "docker init process pid 1" en la documentación oficial.
- **`--init` flag** — <https://docs.docker.com/reference/cli/docker/container/run/#init>

## Arquitectura

- **containerd** — <https://containerd.io/>
- **runc** — <https://github.com/opencontainers/runc>
- **OCI runtime-spec** — <https://github.com/opencontainers/runtime-spec>
- **Diagrama Docker → containerd → runc (post comunidad)** — <https://www.docker.com/blog/containerd-vs-docker/>

## Alternativas compatibles

- **Podman** — <https://podman.io/>
- **colima** (macOS, open-source) — <https://github.com/abiosoft/colima>
- **Rancher Desktop** — <https://rancherdesktop.io/>
- **OrbStack** (macOS, propietario) — <https://orbstack.dev/>
- **nerdctl** (CLI estilo Docker sobre containerd) — <https://github.com/containerd/nerdctl>

## Lecturas complementarias

- **Docker Security — rootless, user namespaces** — <https://docs.docker.com/engine/security/>
- **The hidden danger of the docker group** (background sobre por qué equivale a root) — buscar por el título; hay varias versiones mantenidas por la comunidad.
- **Pro Docker Practices** (referencias cortas en docs.docker.com/develop/).

## Herramientas útiles

- **`ctop`** (htop-like para contenedores) — <https://github.com/bcicen/ctop>
- **`lazydocker`** (TUI) — <https://github.com/jesseduffield/lazydocker>
- **`dive`** (inspeccionar capas) — <https://github.com/wagoodman/dive> (lo usaremos en `dkr-03`).
