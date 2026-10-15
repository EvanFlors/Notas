# Recursos — gha-10-self-hosted-runners-and-arc

## Documentación oficial de GitHub

- [About self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) — overview, requisitos de hardware, soportado vs no soportado, nota de seguridad para repos públicos.
- [Communication between self-hosted runners and GitHub](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github) — endpoints exactos que deben estar permitidos en el firewall de salida.
- [Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners) — comandos y flags de `config.sh`.
- [Managing access to self-hosted runners using groups](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/managing-access-to-self-hosted-runners-using-groups) — runner groups y allow-lists.
- [Using labels with self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners).
- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions) — guía de hardening (base de `gha-13` también).
- [Autoscaling with self-hosted runners (concepto)](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/autoscaling-with-self-hosted-runners).

## ARC (Actions Runner Controller) oficial

- [Quickstart for Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller).
- [Deploying runner scale sets with ARC](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/deploying-runner-scale-sets-with-actions-runner-controller).
- [About ARC](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller) — modelo, CRDs, GitHub App vs PAT.
- Repo oficial: [actions/actions-runner-controller](https://github.com/actions/actions-runner-controller).
- Charts: `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller` y `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set`.
- [Troubleshooting ARC errors](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/troubleshooting-actions-runner-controller-errors).

## Runner binario

- [actions/runner](https://github.com/actions/runner) — código open source del runner.
- [Releases](https://github.com/actions/runner/releases) — tarballs por SO/arquitectura + hashes.

## Larger runners (hosted)

- [About larger runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/about-larger-runners).
- [Managing larger runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/managing-larger-runners).

## Herramientas de cluster local

- [kind](https://kind.sigs.k8s.io/) — Kubernetes in Docker.
- [k3d](https://k3d.io/) — alternativa (k3s en Docker).
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl).
- [Helm](https://helm.sh/).

## Lecturas opcionales

- GitHub Blog: anuncios del ARC oficial (2023), comparativas de rendimiento y coste.
- Charlas: *"Scaling GitHub Actions with ARC"* (varias en YouTube / KubeCon).
- Post-mortems públicos sobre runners self-hosted comprometidos — útiles para calibrar el threat model (ver también lesson §5).
