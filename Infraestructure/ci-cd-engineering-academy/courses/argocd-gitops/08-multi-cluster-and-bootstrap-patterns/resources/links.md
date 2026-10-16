# Recursos — argo-08 Multi-cluster y bootstrap

## Oficial

- [Argo CD — Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/) — formato del Secret `cluster-type`, AppProject, Application.
- [Argo CD — Cluster Bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) — app-of-apps, directory recursion.
- [Argo CD — Self-Managing](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/#self-management) — upgrade seguro de una instalación auto-gestionada.
- [ApplicationSet — Cluster generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/).
- [ApplicationSet — Git generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/).
- [ApplicationSet — Matrix generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Matrix/).
- [ApplicationSet — Progressive Syncs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/).
- [Argo CD Autopilot](https://argocd-autopilot.readthedocs.io/) — CLI opinada que genera un bootstrap repo.
- [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/).
- [Server-Side Apply en Argo CD](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#server-side-apply).

## Herramientas de bootstrap y fleet

- [kind — Multi-cluster patterns](https://kind.sigs.k8s.io/docs/user/quick-start/).
- [Cluster API](https://cluster-api.sigs.k8s.io/) — fleet provisioning declarativo.
- [Akuity Platform](https://akuity.io/akuity-platform/) — Argo CD como SaaS hub-and-spoke gestionado.
- [Velero](https://velero.io/) — backup/restore del namespace argocd.

## Lecturas de diseño

- Codefresh — ["GitOps at Scale with Argo CD"](https://codefresh.io/learn/argo-cd/) — serie con los trade-offs multi-cluster.
- Akuity blog — ["Hub-and-spoke vs standalone"](https://akuity.io/blog/) — artículos sobre topologías.
- Christian Hernandez — ["Argo CD Bootstrap Pattern"](https://blog.christianposta.com/) — walkthrough del patrón app-of-apps.
- [OpenGitOps Principles](https://opengitops.dev/) — el marco al que estos patrones responden.

## Casos de referencia (public bootstrap repos)

- [`argoproj/argocd-example-apps`](https://github.com/argoproj/argocd-example-apps) — ejemplos oficiales (incluye `apps/` para app-of-apps).
- [`gnunn-gitops/standard-cluster-config`](https://github.com/gnunn-gitops/standard-cluster-config) — bootstrap repo "productivo" documentado.
- [`akuity/awesome-argo`](https://github.com/akuity/awesome-argo) — curated list, incluye bootstrap repos de la comunidad.

## Para profundizar al final

- Flux Comparable: [Flux — Multi-tenant repositories](https://fluxcd.io/flux/guides/repository-structure/).
- GitOps Working Group — [Multi-cluster patterns](https://github.com/open-gitops/documents).
- Discurso de KubeCon — buscar "Argo CD at scale" o "GitOps fleet management" en YouTube de la CNCF.
