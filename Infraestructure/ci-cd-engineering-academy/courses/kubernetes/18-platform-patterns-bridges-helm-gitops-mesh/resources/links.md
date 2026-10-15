# Recursos — k8s-18 Platform Patterns

## Oficiales

### Helm
- Helm docs: https://helm.sh/docs/
- Helm charts best practices: https://helm.sh/docs/chart_best_practices/
- OCI registries para charts: https://helm.sh/docs/topics/registries/

### Kustomize
- Kustomize docs: https://kubectl.docs.kubernetes.io/references/kustomize/
- Kustomize GitHub: https://github.com/kubernetes-sigs/kustomize

### Argo CD / Flux / GitOps
- Argo CD docs: https://argo-cd.readthedocs.io/
- Argo CD ApplicationSet: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
- Argo Rollouts: https://argo-rollouts.readthedocs.io/
- Flux docs: https://fluxcd.io/flux/
- CNCF OpenGitOps principles: https://opengitops.dev/
- `argoproj/argocd-example-apps`: https://github.com/argoproj/argocd-example-apps

### Service mesh
- Istio docs: https://istio.io/latest/docs/
- Istio ambient mode: https://istio.io/latest/docs/ambient/
- Linkerd docs: https://linkerd.io/2/overview/
- Cilium Service Mesh: https://docs.cilium.io/en/stable/network/servicemesh/
- SPIFFE / SPIRE: https://spiffe.io/

### Cost management
- OpenCost: https://www.opencost.io/
- OpenCost Helm chart: https://github.com/opencost/opencost-helm-chart
- Kubecost: https://docs.kubecost.com/

### IDP (Internal Developer Platforms)
- Backstage: https://backstage.io/
- Backstage Software Templates: https://backstage.io/docs/features/software-templates/
- Crossplane: https://docs.crossplane.io/
- CNCF Platforms White Paper: https://tag-app-delivery.cncf.io/whitepapers/platforms/

### Observabilidad y policy (contexto)
- Prometheus Operator: https://prometheus-operator.dev/
- Kyverno: https://kyverno.io/docs/
- OPA / Gatekeeper: https://open-policy-agent.github.io/gatekeeper/

## Lecturas recomendadas

- *Platform Engineering on Kubernetes* — Mauricio Salatino (Manning).
- *GitOps and Kubernetes* — Yuen, Matyushentsev, Nguyen, Suen (Manning).
- *Kubernetes Patterns* — Ibryam & Huß (O'Reilly), capítulos finales de patrones avanzados.
- *Service Mesh Patterns* — Lee Calcote et al.
- Charity Majors y Liz Fong-Jones sobre "observability vs mesh" (varios blog posts).

## Cursos cruzados del programa

- `courses/helm/` — curso dedicado de Helm (chart authoring, OCI, hooks, umbrella).
- `courses/argocd-gitops/` — curso dedicado de Argo CD + GitOps (AppProject, ApplicationSet, Rollouts, Workflows, Flux comparison).
- `courses/platform-engineering/` — curso de platform engineering (IDPs, Backstage, Crossplane, golden paths).
- `courses/prometheus-grafana/` y `courses/opentelemetry/` — base de observabilidad.
- `courses/devsecops/` — supply chain (cosign), policy as code.

## A verificar en Fase 4 (notes)

- Versiones estables de Argo CD, Flux, OpenCost, Istio, Linkerd.
- Estado del "ambient mode" de Istio (GA por versión).
- Compatibilidad de Cilium Service Mesh con mTLS.
- Chart oficial de OpenCost: flags recientes para conectar a un Prometheus externo.
- Versiones de Backstage y Crossplane y su política de breaking changes.
