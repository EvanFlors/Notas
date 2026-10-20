# Ejemplo 03 — VolumeSnapshot y restore

## Concepto que demuestra

Un `VolumeSnapshot` captura un disco en un punto en el tiempo. Un PVC posterior puede nacer *clonando* ese snapshot vía `dataSource`. Es la primitiva base para backup/restore y para "dame una copia de prod para debugging".

Los manifests de este directorio son correctos y portables (`snapshot.storage.k8s.io/v1`). Lo que no es portable es *el driver*: solo CSIs que implementen la capability `CREATE_DELETE_SNAPSHOT` producen snapshots reales.

## Dónde se ejecuta

- **EKS/GKE/AKS con CSI driver** (`aws-ebs-csi-driver`, `pd.csi.storage.gke.io`, `disk.csi.azure.com`) con el add-on del snapshotter: **se ejecuta tal cual**. Cambia el nombre del `storageClassName` y del `driver` al que use tu cluster.
- **kind con `local-path-provisioner` (default)**: **no se ejecuta en runtime**. local-path no soporta snapshots. Para probarlo localmente hay que reemplazar el provisioner por uno que sí los soporte (Longhorn, por ejemplo, es la opción típica), lo que excede el alcance de este módulo.

En kind puedes aún así hacer `kubectl apply -f manifests/` *después* de instalar los CRDs del external-snapshotter (ver más abajo). El snapshot se quedará `ReadyToUse: false` para siempre, pero el objeto K8s es válido y aprenderás a leer su `status`.

## Walkthrough en EKS (comandos reales)

```bash
# 0. Preparación
#    - EKS con aws-ebs-csi-driver y aws-ebs-csi-driver snapshot controller (add-on EKS)
#    - CRDs del external-snapshotter aplicados en el cluster
kubectl get crd volumesnapshots.snapshot.storage.k8s.io
kubectl get crd volumesnapshotclasses.snapshot.storage.k8s.io
kubectl get crd volumesnapshotcontents.snapshot.storage.k8s.io

# 1. Aplica StorageClass + PVC + Pod inicial
kubectl apply -f manifests/storageclass.yaml
kubectl apply -f manifests/pvc-source.yaml
kubectl apply -f manifests/pod-source.yaml

# 2. Escribe algo dentro del volumen
kubectl exec demo-source -- sh -c "echo 'snapshot-me' > /data/marker.txt"

# 3. Aplica la VolumeSnapshotClass y pide un snapshot
kubectl apply -f manifests/volumesnapshotclass.yaml
kubectl apply -f manifests/volumesnapshot.yaml

# 4. Espera a que ReadyToUse=true
kubectl get volumesnapshot demo-snap -w

# 5. Restaura: crea un PVC NUEVO con dataSource apuntando al snapshot
kubectl apply -f manifests/pvc-restored.yaml

# 6. Monta el PVC restaurado en un Pod y verifica el marker.txt
kubectl apply -f manifests/pod-restored.yaml
kubectl exec demo-restored -- cat /data/marker.txt
# -> "snapshot-me"
```

## Walkthrough en kind (lectura, sin runtime)

```bash
# Instala los CRDs del external-snapshotter
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

# Aplica el manifest (el snapshot nunca estará ReadyToUse=true porque local-path no lo soporta)
kubectl apply -f manifests/volumesnapshotclass.yaml
# El Pod y el PVC source sí funcionan en kind si cambias storageClassName a 'standard' (local-path).
```

## Nota importante

El tamaño del PVC restaurado debe ser **mayor o igual** al del snapshot. Puedes aprovechar la restauración para expandir, no para reducir.
