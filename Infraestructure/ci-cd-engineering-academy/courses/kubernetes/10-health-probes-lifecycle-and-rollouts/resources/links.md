# Recursos — k8s-10

## Documentación oficial

- Pod Lifecycle — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- Configure Liveness, Readiness and Startup Probes — https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Termination of Pods — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination
- Container Lifecycle Hooks (`postStart`, `preStop`) — https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/
- Deployment — https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- `kubectl rollout` reference — https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout
- PodDisruptionBudget — https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
- Specifying a Disruption Budget — https://kubernetes.io/docs/tasks/run-application/configure-pdb/
- Readiness Gates — https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-readiness-gate
- gRPC health probes — https://kubernetes.io/blog/2022/05/13/grpc-probes-now-in-beta/

## KEPs

- KEP-950 — gRPC probes (GA en 1.27).
- KEP-950 announcement — https://kubernetes.io/blog/2023/08/15/kubernetes-1-28-release/
- KEP-277 — Container Startup Probe (añadida en 1.16).
- KEP-85 — Readiness Gates.

## Progressive delivery (fuera del alcance, referencia)

- Argo Rollouts — https://argoproj.github.io/argo-rollouts/
- Flagger — https://flagger.app/
- Las dos se cubren en el curso **argo-cd** del programa.

## Lecturas recomendadas

- "Kubernetes Patterns" (Ibryam, Huß) — capítulos sobre Health Probe y Managed Lifecycle.
- "Kubernetes Up & Running" — capítulo de Deployments.
- Google Cloud blog: "Kubernetes best practices: Setting up health checks with readiness and liveness probes" — https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-setting-up-health-checks-with-readiness-and-liveness-probes
- Learnk8s: "Graceful shutdown with Kubernetes" — https://learnk8s.io/graceful-shutdown
- "Zero-downtime Rolling Updates with Kubernetes" (Ambassador blog, Marko Luksa pieces).

## Herramientas útiles para experimentar

- **kind** — https://kind.sigs.k8s.io/ (cluster local recomendado por este curso).
- **k3d** — https://k3d.io/
- **stern** — https://github.com/stern/stern (logs multi-Pod).
- **vegeta** / **hey** — generadores de carga HTTP sencillos para medir downtime real.
- **grpcurl** / **ghz** — equivalentes para gRPC.
