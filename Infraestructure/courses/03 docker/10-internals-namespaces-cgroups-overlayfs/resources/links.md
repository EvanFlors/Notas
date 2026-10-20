# Recursos — dkr-10

## Documentación del kernel

- **Namespaces (overview)** — <https://man7.org/linux/man-pages/man7/namespaces.7.html>
- **`unshare(2)`** — <https://man7.org/linux/man-pages/man2/unshare.2.html>
- **`setns(2)`** — <https://man7.org/linux/man-pages/man2/setns.2.html>
- **`clone(2)`** — <https://man7.org/linux/man-pages/man2/clone.2.html>
- **`user_namespaces(7)`** — <https://man7.org/linux/man-pages/man7/user_namespaces.7.html>
- **`capabilities(7)`** — <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- **`seccomp(2)` + BPF** — <https://man7.org/linux/man-pages/man2/seccomp.2.html>
- **cgroups v2** — <https://docs.kernel.org/admin-guide/cgroup-v2.html>
- **overlayfs** — <https://docs.kernel.org/filesystems/overlayfs.html>

## Herramientas

- **`unshare(1)`** — <https://man7.org/linux/man-pages/man1/unshare.1.html>
- **`nsenter(1)`** — <https://man7.org/linux/man-pages/man1/nsenter.1.html>
- **`lsns(1)`** — <https://man7.org/linux/man-pages/man1/lsns.1.html>
- **`capsh(1)`** — <https://man7.org/linux/man-pages/man1/capsh.1.html>
- **`pscap(1)`** (libcap-ng) — <https://people.redhat.com/sgrubb/libcap-ng/>

## Runtimes / especificaciones

- **OCI runtime-spec** — <https://github.com/opencontainers/runtime-spec>
- **runc** — <https://github.com/opencontainers/runc>
- **containerd** — <https://github.com/containerd/containerd>
- **crun** (runtime C ligero) — <https://github.com/containers/crun>

## Docker específicos

- **Runtime options (`docker run` memory, cpu, etc.)** — <https://docs.docker.com/engine/containers/resource_constraints/>
- **`--cap-add` / `--cap-drop`** — <https://docs.docker.com/reference/cli/docker/container/run/#cap-add>
- **Default seccomp profile** — <https://docs.docker.com/engine/security/seccomp/>
- **User namespaces (`userns-remap`)** — <https://docs.docker.com/engine/security/userns-remap/>
- **Storage driver overlay2** — <https://docs.docker.com/engine/storage/drivers/overlayfs-driver/>

## Lecturas complementarias

- **Jérôme Petazzoni — "Containers from scratch"** (video + repo clásico).
- **Liz Rice — "Container Security"** (O'Reilly, 2020): capítulos sobre namespaces y capabilities.
- **Michael Kerrisk — "The Linux Programming Interface"**: capítulos de namespaces/cgroups son referencia.
- **Julia Evans — "What even is a container?"** (post explicativo, mental model).

## Entornos de laboratorio para no-Linux

- **multipass** — <https://multipass.run/> (`multipass launch --name dkr10 22.04`).
- **Vagrant + VirtualBox/libvirt** — <https://www.vagrantup.com/> (`vagrant init ubuntu/jammy64`).
- **GitHub Codespaces** — kernel Linux listo, pero sin `--privileged`.

## Nota de verificación

Última verificación: pendiente de validar en Fase 4. Todos los enlaces apuntan a dominios oficiales (`kernel.org`, `man7.org`, `docker.com`, `github.com/opencontainers`).
