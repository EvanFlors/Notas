# Recursos — Flux v2 como alternativa a Argo CD

## Documentación oficial

- Flux docs — https://fluxcd.io/flux/
- Flux controllers reference — https://fluxcd.io/flux/components/
- `source-controller` CRs — https://fluxcd.io/flux/components/source/
- `kustomize-controller` CRs — https://fluxcd.io/flux/components/kustomize/
- `helm-controller` CRs — https://fluxcd.io/flux/components/helm/
- `notification-controller` CRs — https://fluxcd.io/flux/components/notification/
- Image update automation — https://fluxcd.io/flux/guides/image-update/
- `flux` CLI reference — https://fluxcd.io/flux/cmd/
- Flux multi-tenancy guide — https://fluxcd.io/flux/installation/configuration/multitenancy/
- Flux security docs — https://fluxcd.io/flux/security/

## Bootstrap y patterns

- `flux bootstrap github` — https://fluxcd.io/flux/installation/bootstrap/github/
- `flux bootstrap gitlab` — https://fluxcd.io/flux/installation/bootstrap/gitlab/
- Repository structure for monorepo / multi-tenant — https://fluxcd.io/flux/guides/repository-structure/
- OCI sources — https://fluxcd.io/flux/cheatsheets/oci-artifacts/

## Comparación y migración

- "Argo CD vs Flux" (CNCF blog comparativas; verificar frescura antes de citar) — buscar en https://www.cncf.io/blog/
- Flagger (progressive delivery para Flux, análogo a Argo Rollouts) — https://fluxcd.io/flagger/

## OpenGitOps

- OpenGitOps principles — https://opengitops.dev/

## Herramientas de observación (sin write — alineadas con la filosofía Flux)

- Weave GitOps OSS — https://github.com/weaveworks/weave-gitops
- Capacitor (dashboard para Flux) — https://github.com/gimlet-io/capacitor
- `flux` CLI (`flux get all -A`, `flux tree`, `flux stats`) — ver docs CLI arriba

## Lecturas recomendadas

- "GitOps: What You Need to Know" — Weaveworks whitepaper original (contexto histórico; buscar la última versión en weaveworks docs).
- "GitOps Working Group" — definición formal de los 4 principios.
- Michael Nygard — "Documenting Architecture Decisions" (formato ADR usado en `activities/02-choice-adr-final`).
