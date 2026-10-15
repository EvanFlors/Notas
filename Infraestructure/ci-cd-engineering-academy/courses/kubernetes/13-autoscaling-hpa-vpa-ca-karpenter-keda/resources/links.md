# Recursos — k8s-13

## Documentación oficial

- **HPA (Horizontal Pod Autoscaler)** — <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/>
- **HPA walkthrough** — <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/>
- **HPA behavior (v2)** — <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior>
- **metrics-server** — <https://github.com/kubernetes-sigs/metrics-server>
- **Resource metrics API** — <https://kubernetes.io/docs/reference/instrumentation/metrics-api/>
- **Custom metrics API** — <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#support-for-metrics-apis>
- **VerticalPodAutoscaler** — <https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler>
- **Cluster Autoscaler** — <https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler>
- **Cluster Autoscaler on AWS** — <https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md>

## Karpenter

- **Docs (home)** — <https://karpenter.sh/docs/>
- **Concepts** — <https://karpenter.sh/docs/concepts/>
- **NodePool reference** — <https://karpenter.sh/docs/concepts/nodepools/>
- **EC2NodeClass reference** — <https://karpenter.sh/docs/concepts/nodeclasses/>
- **Disruption / consolidation** — <https://karpenter.sh/docs/concepts/disruption/>
- **Getting started on EKS** — <https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/>
- **Azure Karpenter Provider** (contexto multi-cloud) — <https://github.com/Azure/karpenter-provider-azure>

## KEDA

- **Docs (home)** — <https://keda.sh/docs/>
- **ScaledObject reference** — <https://keda.sh/docs/latest/concepts/scaling-deployments/>
- **Scalers catalog** — <https://keda.sh/docs/latest/scalers/>
- **AWS SQS scaler** — <https://keda.sh/docs/latest/scalers/aws-sqs/>
- **Prometheus scaler** — <https://keda.sh/docs/latest/scalers/prometheus/>
- **Cron scaler** — <https://keda.sh/docs/latest/scalers/cron/>

## Prometheus Adapter

- **Repo** — <https://github.com/kubernetes-sigs/prometheus-adapter>
- **Configuration walkthrough** — <https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config-walkthrough.md>

## Lecturas y comparativas

- **AWS blog**: "Introducing Karpenter — an open-source high-performance Kubernetes cluster autoscaler" — <https://aws.amazon.com/blogs/aws/introducing-karpenter-an-open-source-high-performance-kubernetes-cluster-autoscaler/>
- **CNCF blog**: adoption and case studies of KEDA/Karpenter (search by year).
- **SIG Autoscaling** — <https://github.com/kubernetes/community/tree/master/sig-autoscaling>

## Herramientas útiles

- `kube-ops-view` — vista topológica live del cluster (buena para explicar consolidación de Karpenter).
- `k9s` — TUI; `:hpa` muestra HPAs y su estado en una pantalla.
- `goldilocks` (Fairwinds) — UI sobre VPA recommender, útil para enseñar.

## Pro Git-style reads en autoscaling

- Lecturas públicas reutilizables (buscar por título y año):
  - "Scaling Kubernetes with Karpenter" — AWS re:Invent talks.
  - "KEDA deep dive" — KubeCon talks de 2023–2024.
  - "The HPA v2 behavior field explained" — blog posts de 2022+.
