# Solucion de referencia (clave corta) — dkr-13-02

Esta actividad es **independent**: el entregable es la escritura del estudiante.
Esta clave resume los puntos tecnicos que un `ANALYSIS.md` correcto debe cubrir
para cada vector, para auto-corregirse tras entregar.

## V1 — docker.sock

- Mecanismo: socket = API REST del daemon root; sin auth propia; permite crear
  nuevos contenedores con `-v /:/host`.
- Deteccion: `docker inspect` -> Mounts contiene `/var/run/docker.sock`.
- Impacto: root al host (o al usuario del daemon en rootless).
- Mitigacion: kaniko/BuildKit para build; socket-proxy read-only con allow-list;
  DinD rootless efimero en runners dedicados.

## V2 — --privileged

- Mecanismo: todas las capabilities + seccomp off + /dev del host + /sys /proc sin mask.
- Deteccion: `HostConfig.Privileged: true`.
- Impacto: root al host de facto.
- Mitigacion: `--cap-drop=ALL --cap-add=<minimal>`; `--device` especifico para GPU.

## V3 — CAP_SYS_ADMIN

- Mecanismo: capability mas amplia (mount, bpf, namespace ops). CVE-2022-0492
  (cgroups release_agent) y familia.
- Deteccion: `HostConfig.CapAdd` contiene `SYS_ADMIN`.
- Impacto: escape via mount manipulation o cgroup release_agent.
- Mitigacion: nunca `--cap-add=SYS_ADMIN`; usar FUSE/user namespaces para el use case.

## V4 — Bind mount amplio del host

- Mecanismo: `-v /:/host` expone FS completo; lectura de secretos + persistencia.
- Deteccion: Mounts con rutas `/`, `/etc`, `/root`, `/var/run`, `/proc`, `/sys`.
- Impacto: compromiso del host (lectura o escritura).
- Mitigacion: bind mount minimo necesario con `:ro`; secrets manager; en K8s evitar hostPath.

## V5 — --network host

- Mecanismo: elimina net namespace -> acceso directo a stack del host y a IMDS cloud.
- Deteccion: `HostConfig.NetworkMode: host` (Compose `network_mode: host`, K8s `hostNetwork: true`).
- Impacto: lateral movement a servicios de admin (SSH, kubelet, API, etcd); IMDS credential theft.
- Mitigacion: bridge con `-p 127.0.0.1:...`; IMDSv2 con hop limit 1 en cloud.

## V6 — seccomp unconfined

- Mecanismo: apaga el filtro de ~44 syscalls peligrosos; amplifica kernel bugs
  (Dirty Pipe, io_uring, bpf).
- Deteccion: `HostConfig.SecurityOpt` contiene `seccomp=unconfined` o `--privileged` lo implica.
- Impacto: variable; con exploit disponible, root al host.
- Mitigacion: nunca unconfined en prod; perfil custom partiendo del default de moby.

## Patron comun

Todos los vectores: (1) reducen aislamiento por default, (2) son detectables en
`docker inspect`/`docker run` sin forensic, (3) tienen una alternativa concreta
que resuelve el use case legitimo sin ampliar privilegios.
