# Recursos — dkr-01

## Specs OCI (fuente primaria)

- **OCI image-spec** — <https://github.com/opencontainers/image-spec>
- **OCI runtime-spec** — <https://github.com/opencontainers/runtime-spec>
- **OCI distribution-spec** — <https://github.com/opencontainers/distribution-spec>
- **OCI landing page** — <https://opencontainers.org/>

## Runtimes

- **runc** (runtime de bajo nivel OCI de referencia) — <https://github.com/opencontainers/runc>
- **crun** (runtime de bajo nivel en C, drop-in replacement) — <https://github.com/containers/crun>
- **containerd** (runtime de alto nivel, CNCF) — <https://containerd.io/>
- **CRI-O** (runtime específico para Kubernetes) — <https://cri-o.io/>

## Documentación Docker

- **Docker overview** — <https://docs.docker.com/get-started/overview/>
- **Docker architecture** — <https://docs.docker.com/get-started/overview/#docker-architecture>
- **Docker storage drivers (overlay2)** — <https://docs.docker.com/storage/storagedriver/overlayfs-driver/>

## Kernel Linux (primitivas)

- **`man 7 namespaces`** — <https://man7.org/linux/man-pages/man7/namespaces.7.html>
- **`man 7 pid_namespaces`** — <https://man7.org/linux/man-pages/man7/pid_namespaces.7.html>
- **`man 7 user_namespaces`** — <https://man7.org/linux/man-pages/man7/user_namespaces.7.html>
- **cgroups v2** (admin guide del kernel) — <https://docs.kernel.org/admin-guide/cgroup-v2.html>
- **overlayfs** — <https://docs.kernel.org/filesystems/overlayfs.html>
- **seccomp** — <https://man7.org/linux/man-pages/man2/seccomp.2.html>
- **capabilities** — <https://man7.org/linux/man-pages/man7/capabilities.7.html>

## Lecturas conceptuales (verificar al desarrollar el curso)

- Liz Rice — **"Container Security"** (O'Reilly). Capítulos 1–4 cubren exactamente este modelo mental.
- Jess Frazelle — artículos clásicos sobre contenedores "a mano" con `unshare` + `nsenter`.
- Julia Evans — zines y posts sobre `/proc`, namespaces, cgroups. <https://jvns.ca/>
- Jérôme Petazzoni — *"Anatomy of a Container"* (charla clásica; sigue siendo correcta en lo esencial).

## Herramientas adyacentes (contexto futuro de la carrera)

- **Podman** (alternativa daemonless, rootless-first) — <https://podman.io/>
- **nerdctl** (CLI estilo Docker sobre containerd) — <https://github.com/containerd/nerdctl>
- **skopeo** (inspeccionar y mover imágenes OCI sin daemon) — <https://github.com/containers/skopeo>
- **dive** (explorar capas de una imagen) — <https://github.com/wagoodman/dive>

## Supply chain (adelanto de `dkr-14`)

- **cosign** — <https://docs.sigstore.dev/cosign/overview/>
- **syft** (SBOM) — <https://github.com/anchore/syft>
- **Trivy** (vuln scanner) — <https://trivy.dev/>
- **SLSA framework** — <https://slsa.dev/>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces son dominios canónicos del ecosistema (`opencontainers.org`, `docs.kernel.org`, `man7.org`, `docs.docker.com`, repos oficiales en `github.com/opencontainers`, `github.com/containerd`, `github.com/containers`); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
