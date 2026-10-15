# Resources — dkr-11

## Oficial

- Docker — multi-stage builds: https://docs.docker.com/build/building/multi-stage/
- Docker — BuildKit: https://docs.docker.com/build/buildkit/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- OCI image spec: https://github.com/opencontainers/image-spec

## Base images

- Distroless (Google): https://github.com/GoogleContainerTools/distroless
- Chainguard images: https://images.chainguard.dev
- Wolfi (base under Chainguard): https://wolfi.dev
- Alpine Linux: https://alpinelinux.org
- Debian slim variants: https://hub.docker.com/_/debian

## Python específico

- PEP 513 manylinux (why alpine breaks wheels): https://peps.python.org/pep-0513/
- PEP 656 musllinux (alpine-compatible wheels): https://peps.python.org/pep-0656/
- pip `--no-cache-dir`: https://pip.pypa.io/en/stable/cli/pip/#cmdoption-no-cache-dir
- uv (fast resolver / installer): https://docs.astral.sh/uv/

## Herramientas de inspección

- dive: https://github.com/wagoodman/dive
- trivy: https://aquasecurity.github.io/trivy/
- grype: https://github.com/anchore/grype
- syft (SBOM): https://github.com/anchore/syft

## Lecturas recomendadas

- "Why your Docker images are so big" — múltiples posts; buscar por "docker image size whiteout anti-pattern".
- Chainguard — "Minimal container images, why and how": https://www.chainguard.dev/unchained/minimal-container-images-why-and-how
- Google — "Distroless containers" talk notes: enlace oficial en el README del repo distroless.
- CNCF — SLSA framework (contexto de supply chain): https://slsa.dev
