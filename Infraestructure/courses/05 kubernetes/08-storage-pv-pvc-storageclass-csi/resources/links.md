# Recursos — k8s-08 Storage

## Documentación oficial Kubernetes

- Persistent Volumes — https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- Storage Classes — https://kubernetes.io/docs/concepts/storage/storage-classes/
- Volume Snapshots — https://kubernetes.io/docs/concepts/storage/volume-snapshots/
- CSI Volume Cloning — https://kubernetes.io/docs/concepts/storage/volume-pvc-datasource/
- Dynamic Volume Provisioning — https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/

## CSI y drivers

- CSI spec — https://github.com/container-storage-interface/spec
- Kubernetes CSI docs — https://kubernetes-csi.github.io/docs/
- Lista oficial de drivers — https://kubernetes-csi.github.io/docs/drivers.html
- AWS EBS CSI — https://github.com/kubernetes-sigs/aws-ebs-csi-driver
- AWS EFS CSI — https://github.com/kubernetes-sigs/aws-efs-csi-driver
- GCP PD CSI — https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver
- Azure Disk CSI — https://github.com/kubernetes-sigs/azuredisk-csi-driver
- Longhorn — https://longhorn.io/
- Rancher local-path-provisioner — https://github.com/rancher/local-path-provisioner

## Snapshots

- external-snapshotter (CRDs y controller) — https://github.com/kubernetes-csi/external-snapshotter
- VolumeSnapshotContent reference — https://kubernetes.io/docs/concepts/storage/volume-snapshots/#volumesnapshotcontents

## Operadores que gestionan storage por ti

- CloudNativePG (Postgres) — https://cloudnative-pg.io/
- Strimzi (Kafka) — https://strimzi.io/
- Velero (backup/restore) — https://velero.io/

## Lecturas recomendadas

- "Storage Fundamentals" en *Kubernetes Up & Running* (Burns/Beda/Hightower/Villalba).
- KEP-1495 — Generic data populators (dataSourceRef).
- KEP-1472 — Storage capacity tracking.
- Blog: "The hidden cost of volumeBindingMode: Immediate" — buscar por el término exacto; es un patrón de incidentes recurrente en EKS.
