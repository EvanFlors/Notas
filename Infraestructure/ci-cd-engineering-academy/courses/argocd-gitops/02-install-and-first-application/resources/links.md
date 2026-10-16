# argo-02 — Recursos

## Documentación oficial

- Argo CD — [Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/) (instalación, port-forward, primera app).
- Argo CD — [Installation manifests](https://github.com/argoproj/argo-cd/tree/master/manifests) (`install.yaml`, `ha/install.yaml`, `core-install.yaml`, `namespace-install.yaml`).
- Argo CD — [Core Concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/) (Application, Project, Sync, Health).
- Argo CD — [Architecture overview](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/) (componentes y comunicación).
- Argo CD — [CLI reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/) (`argocd login`, `argocd app`, `argocd cluster`, `argocd repo`).
- Argo CD — [`argocd admin`](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_admin/) incluye `initial-password`.
- Argo CD — [Application health and resource customizations](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/).

## Repos de ejemplo usados

- [`argoproj/argocd-example-apps`](https://github.com/argoproj/argocd-example-apps) — repo didáctico oficial. `guestbook/` (plain YAML), `helm-guestbook/`, `kustomize-guestbook/`, `jsonnet-guestbook/`.

## Herramientas complementarias

- [`argocd` CLI releases](https://github.com/argoproj/argo-cd/releases) — binarios oficiales para Linux/macOS/Windows.
- [kind](https://kind.sigs.k8s.io/) — Kubernetes in Docker, cluster local.
- [k9s](https://k9scli.io/) — TUI para navegar el cluster; útil para inspeccionar los pods de `argocd` sin perder foco.
- [argocd-autopilot](https://github.com/argoproj-labs/argocd-autopilot) — bootstrap opinado de Argo CD (lo ves en `argo-08`).

## Lecturas complementarias

- Jesse Suen (co-creador de Argo CD) — [How we built the GitOps engine at Intuit](https://blog.argoproj.io/).
- Codefresh / Akuity blog — comparativas Argo CD vs Flux, patrones de bootstrap, hardening (fundadores/mantenedores).
- *OpenGitOps principles* — [https://opengitops.dev](https://opengitops.dev) (fundamento conceptual que estamos implementando aquí).

## Para los curiosos

- Lee `install.yaml` enterito (`curl -s https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.1/manifests/install.yaml | wc -l` → ~22k líneas). Identifica cada CRD, ServiceAccount, Role, ClusterRole, Deployment y StatefulSet. Es un buen ejercicio de "qué es realmente un operador".
- Inspecciona los logs del `application-controller` en el arranque: busca el mensaje `appController started processing` y la línea de sharding (`shard N of M`).
- Decodifica un Secret de repo registrado: `kubectl -n argocd get secret <name> -o jsonpath='{.data.url}' | base64 -d`. Ahí vive el URL del repo que Argo CD conoce.
