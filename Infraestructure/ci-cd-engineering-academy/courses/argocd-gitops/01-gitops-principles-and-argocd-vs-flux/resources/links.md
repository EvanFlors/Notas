# Recursos — argo-01

Enlaces a verificar fecha de consulta.

## OpenGitOps (definición formal)

- **Sitio oficial** — <https://opengitops.dev/>
- **PRINCIPLES.md v1.0.0** (texto formal) — <https://github.com/open-gitops/documents/blob/main/PRINCIPLES.md>
- **GitOps WG** (CNCF) — <https://github.com/open-gitops>
- **GitOps glossary** — <https://github.com/open-gitops/documents/blob/main/GLOSSARY.md>

## Argo CD

- **Documentación oficial** — <https://argo-cd.readthedocs.io/>
- **Architecture overview** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/>
- **Core concepts** — <https://argo-cd.readthedocs.io/en/stable/core_concepts/>
- **CNCF project page** — <https://www.cncf.io/projects/argo/>
- **Adopters** — <https://github.com/argoproj/argo-cd/blob/master/USERS.md>
- **Argo Rollouts** (progressive delivery sobre GitOps) — <https://argo-rollouts.readthedocs.io/>
- **argocd-image-updater** — <https://argocd-image-updater.readthedocs.io/>

## Flux

- **Documentación oficial** — <https://fluxcd.io/flux/>
- **Core concepts** — <https://fluxcd.io/flux/concepts/>
- **CNCF project page** — <https://www.cncf.io/projects/flux/>
- **Adopters** — <https://fluxcd.io/adopters/>
- **Image automation** — <https://fluxcd.io/flux/guides/image-update/>

## Comparativas (verificar fecha)

- **Argo vs Flux (CNCF community comparison)** — buscar comparativas CNCF recientes; nota que las features convergen y las comparativas envejecen rápido.

## Origen del término GitOps

- **Weaveworks (2017) — GitOps: Operations by Pull Request** — <https://www.weave.works/blog/gitops-operations-by-pull-request> (post original).
- **Weaveworks (2018) — The History of GitOps** — contexto histórico.

## Lectura complementaria

- Humble, Farley — *Continuous Delivery* (Addison-Wesley). Fundamento de "artefactos inmutables + pipelines" sobre el que GitOps construye.
- Beyer, Jones, Petoff — *Site Reliability Engineering* (O'Reilly). Capítulos de release engineering.
- Burns, Beda, Hightower, Villalba — *Kubernetes Up & Running* (3ª ed.), caps. sobre deployment patterns.
- Codefresh / Akuity blogs (mantenedores Argo CD) — patrones avanzados.

## Herramientas relacionadas (contexto)

- **Crossplane** (gestión de recursos cloud por GitOps) — <https://crossplane.io/>
- **Kyverno** (admission policies, exigir imagen firmada) — <https://kyverno.io/>
- **OPA / Gatekeeper** — <https://open-policy-agent.github.io/gatekeeper/>
- **cosign / sigstore** (firma de imágenes OCI) — <https://docs.sigstore.dev/>
- **External Secrets Operator (ESO)** — <https://external-secrets.io/>
- **SOPS** — <https://github.com/getsops/sops>
- **Sealed Secrets** — <https://github.com/bitnami-labs/sealed-secrets>

## Patrones y repos de referencia

- **Argo CD autopilot** (bootstrap opinated) — <https://github.com/argoproj-labs/argocd-autopilot>
- **Flux example repos** — <https://fluxcd.io/flux/guides/>
- **ArgoCD example apps** — <https://github.com/argoproj/argocd-example-apps>
