# Recursos — k8s-03-pods-deployments-replicasets

## Documentación oficial

- Pods: <https://kubernetes.io/docs/concepts/workloads/pods/>
- Pod lifecycle: <https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/>
- Init containers: <https://kubernetes.io/docs/concepts/workloads/pods/init-containers/>
- **Sidecar containers nativos**: <https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/>
- ReplicaSet: <https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/>
- Deployment: <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/>
- Labels y selectors: <https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/>

## `kubectl`

- `kubectl rollout`: <https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout>
- `kubectl set image`: <https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-em-image-em->
- `kubectl explain deployment.spec.strategy`: ejecuta en tu cluster para ver el schema vivo.
- `kubectl annotate` y la anotación `kubernetes.io/change-cause`: <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#checking-rollout-history-of-a-deployment>

## KEPs y background

- KEP-753 — Sidecar containers (status: Beta/GA según versión): <https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers>
- KEP sobre Deployment semantics: <https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps>

## Libros y referencias

- *Kubernetes Up & Running*, 3rd ed. — Burns, Beda, Hightower, Villalba. Capítulos: Pods, ReplicaSets, Deployments.
- *Programming Kubernetes* — Hausenblas, Schimanski. Para entender el reconciliation loop desde la óptica de los controllers.

## Para experimentar

- `nginxdemos/hello`: imagen de demostración con varias tags que devuelven HTML distinguible, útil para "ver" los rollouts. Repo: <https://hub.docker.com/r/nginxdemos/hello>.
- `nginx:1.25-alpine`, `1.26-alpine`, `1.27-alpine`: tags inmutables, pequeñas, ideales para encadenar revisiones.

## Herramientas adyacentes (fuera de este módulo)

- **Argo Rollouts** y **Flagger**: controllers avanzados de rollout (canary, blue/green, análisis de métricas). Se tratan en el curso de Argo CD.
- **k9s**: TUI para `kubectl`; útil para observar rollouts en tiempo real.
- **stern**: `kubectl logs` multi-pod, útil durante un rollout para seguir todos los Pods a la vez.
