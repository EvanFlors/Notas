# Recursos — `dkr-13-runtime-security-and-hardening`

> Verificar fecha de consulta. URLs y herramientas de seguridad evolucionan rapido.

## Documentacion oficial de Docker

- **Docker security** — overview oficial de los mecanismos del daemon. <https://docs.docker.com/engine/security/>
- **Seccomp security profiles for Docker** — default profile explicado y como personalizar. <https://docs.docker.com/engine/security/seccomp/>
- **AppArmor security profiles for Docker** — perfil `docker-default`, perfiles custom. <https://docs.docker.com/engine/security/apparmor/>
- **Runtime privilege and Linux capabilities** — tabla completa de capabilities por default y como añadir/quitar. <https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities>
- **Rootless mode** — instalacion y limitaciones oficiales. <https://docs.docker.com/engine/security/rootless/>
- **Protect the Docker daemon socket** — TLS para el socket TCP; nota sobre el socket Unix. <https://docs.docker.com/engine/security/protect-access/>

## Capabilities del kernel

- **man 7 capabilities** — referencia canonica. <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- **CAP_SYS_ADMIN: the new root** — articulo clasico de LWN. <https://lwn.net/Articles/486306/>

## CIS Benchmarks y auditoria

- **CIS Docker Benchmark** — PDF (requiere registro gratuito). <https://www.cisecurity.org/benchmark/docker>
- **docker-bench-security** — script oficial de Docker Inc. para auditar un host. <https://github.com/docker/docker-bench-security>

## Escaneo de imagenes y supply chain

- **Trivy** (Aqua Security) — scanner multi-proposito (vulns + misconfig + secrets + licencias). <https://github.com/aquasecurity/trivy>
- **grype** (Anchore) — scanner de CVEs rapido; integra con syft para SBOM. <https://github.com/anchore/grype>
- **syft** — generador de SBOM (CycloneDX / SPDX). <https://github.com/anchore/syft>
- **Docker Scout** — successor comercial de `docker scan`. <https://docs.docker.com/scout/>

## Alternativas rootless y daemonless

- **Podman** — compat CLI, rootless-first, daemonless. <https://podman.io/>
- **nerdctl** — CLI estilo Docker directo sobre containerd (soporta rootless). <https://github.com/containerd/nerdctl>
- **kaniko** (Google) — build de imagenes OCI dentro de un contenedor sin daemon ni privilegios. <https://github.com/GoogleContainerTools/kaniko>
- **buildah** (Red Hat) — build sin daemon, buena integracion con Podman. <https://buildah.io/>

## Runtime detection y observabilidad

- **Falco** — runtime security detection via eBPF. <https://falco.org/>
- **Tracee** (Aqua) — tracing y detection via eBPF. <https://github.com/aquasecurity/tracee>

## Lecturas clave sobre escapes

- **Docker socket mount = root** — ejemplo didactico en el blog de Trail of Bits. <https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/>
- **CVE-2022-0492: cgroups release_agent escape** — explicacion por Palo Alto Unit 42. <https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/>
- **Dirty Pipe (CVE-2022-0847)** — kernel bug con impacto en escapes. <https://dirtypipe.cm4all.com/>

## Kubernetes (puente a cursos D8 / D9)

- **Pod Security Standards** — baseline / restricted; traduce el hardening de este modulo a K8s. <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
- **Kyverno** — policy engine. <https://kyverno.io/>
- **OPA/Gatekeeper** — admission control via Rego. <https://open-policy-agent.github.io/gatekeeper/>
- **sigstore policy-controller** — verificacion de firmas/attestations en admision. <https://docs.sigstore.dev/policy-controller/overview/>

## En este curso

- Modulo anterior: `dkr-12-multiarch-and-reproducibility` — base image, pins por digest.
- Siguiente modulo: `dkr-14-supply-chain-sbom-signing-provenance` — SBOM, cosign, SLSA attestations, verificacion.
- Puente con: `gha-14` (gating en CI de GitHub Actions), curso D9 (DevSecOps).
