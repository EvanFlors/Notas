# Recursos — k8s-17 Cluster lifecycle, upgrades, backup y multi-cluster

> Enlaces verificados en Fase 4 contra la última minor estable de Kubernetes. Si un enlace cambia, actualiza este archivo.

## Versionado y skew policy

- Policy de soporte y release cycle: https://kubernetes.io/releases/
- Versioning y skew policy: https://kubernetes.io/releases/version-skew-policy/
- Deprecation guide (APIs removidas por versión): https://kubernetes.io/docs/reference/using-api/deprecation-guide/
- Release notes (changelog por minor): https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG

## Upgrades

- **kubeadm upgrade** paso a paso: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- EKS cluster upgrade: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
- EKS managed node group update: https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html
- GKE cluster upgrades y release channels: https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades
- AKS upgrade: https://learn.microsoft.com/azure/aks/upgrade-cluster
- Repos nuevos `pkgs.k8s.io` (reemplazan a `apt.kubernetes.io`): https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction/

## Deprecation checkers

- **Pluto** (FairwindsOps): https://github.com/FairwindsOps/pluto
- **kubent** (kube-no-trouble): https://github.com/doitintl/kube-no-trouble

## Drain, PDB

- `kubectl drain` reference: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- PodDisruptionBudget: https://kubernetes.io/docs/tasks/run-application/configure-pdb/

## Velero

- Documentación oficial: https://velero.io/docs/
- Plugin AWS (y S3-compatible): https://github.com/vmware-tanzu/velero-plugin-for-aws
- File-system backup (kopia / restic, ex-"restic integration"): https://velero.io/docs/main/file-system-backup/
- CSI snapshot integration: https://velero.io/docs/main/csi/
- Schedules y retention: https://velero.io/docs/main/backup-reference/
- Backup hooks (pre/post exec): https://velero.io/docs/main/backup-hooks/

## etcd backup

- Backing up an etcd cluster: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster
- `etcdctl` docs: https://etcd.io/docs/latest/op-guide/recovery/

## Multi-cluster / fleet

- Cluster API: https://cluster-api.sigs.k8s.io/
- Rancher Fleet: https://fleet.rancher.io/
- Argo CD ApplicationSet (multi-cluster): https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
- Submariner (cross-cluster networking): https://submariner.io/
- Istio multi-cluster: https://istio.io/latest/docs/setup/install/multicluster/
- Linkerd multi-cluster: https://linkerd.io/2/features/multicluster/
- Cilium Cluster Mesh: https://docs.cilium.io/en/stable/network/clustermesh/

## FinOps cluster-side

- **OpenCost** (CNCF): https://www.opencost.io/
- OpenCost docs: https://www.opencost.io/docs/
- Kubecost: https://www.kubecost.com/
- AWS Cost and Usage Report (CUR): https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html
- GCP Billing Export to BigQuery: https://cloud.google.com/billing/docs/how-to/export-data-bigquery

## DR / continuidad del negocio

- Kubernetes "backup your cluster" (overview): https://kubernetes.io/docs/tasks/administer-cluster/
- AWS Backup for EKS: https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-eks.html
- GCP Backup for GKE: https://cloud.google.com/kubernetes-engine/docs/add-on/backup-for-gke

## Herramientas de apoyo mencionadas en los ejemplos

- kind: https://kind.sigs.k8s.io/
- MinIO: https://min.io/docs/minio/kubernetes/upstream/
- Helm: https://helm.sh/docs/

## Lecturas conceptuales recomendadas

- "Rethinking Kubernetes Upgrades at Datadog" (post de ingeniería, buscar por título — ejemplo de blue/green a escala).
- "SRE Book" §3 (Service Level Objectives) — para calibrar RPO/RTO en términos de error budget.
- CNCF Multi-cluster SIG archive — minutas con decisiones de patterns.
