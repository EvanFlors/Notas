# Ejemplo 01 — PVC dinámico (EBS en EKS; `local-path` en kind)

## Concepto que demuestra

Pedir almacenamiento es escribir **un** manifest: un `PersistentVolumeClaim`. La `StorageClass` + el CSI driver se encargan de materializar el `PersistentVolume` por detrás. El flujo es idéntico en EKS, GKE, AKS o kind — cambia solo la `StorageClass`.

Este ejemplo tiene dos variantes:

- **Variante EKS (referencia)** — manifests en `eks/` usando el EBS CSI driver (`ebs.csi.aws.com`). No se ejecuta en el laptop; es el patrón real que verás en producción.
- **Variante kind (runnable)** — manifests en `kind/` usando `local-path` (default del cluster `kind`). Se puede aplicar y verificar end-to-end localmente.

## Prerrequisitos

- `kubectl` ≥ 1.28.
- Para la variante kind: tener `kind` instalado y un cluster corriendo (`kind create cluster`).
- Para la variante EKS: cluster EKS con `aws-ebs-csi-driver` instalado como add-on.

## Variante kind: ejecución

```bash
# 0. Verifica que estás contra un kind cluster
kubectl config current-context

# 1. local-path ya viene como default en kind; confírmalo
kubectl get storageclass

# 2. Crea el PVC
kubectl apply -f kind/pvc.yaml

# 3. Mira el estado: debe estar Pending (volumeBindingMode=WaitForFirstConsumer)
kubectl get pvc demo-pvc

# 4. Crea el Pod que lo monta
kubectl apply -f kind/pod.yaml

# 5. Ahora el PVC se liga; verifica
kubectl get pvc demo-pvc
kubectl get pv

# 6. Escribe un archivo dentro del volumen
kubectl exec demo-pod -- sh -c "echo 'persisted via local-path' > /data/marker.txt"
kubectl exec demo-pod -- cat /data/marker.txt

# 7. Borra el Pod y recrea; el archivo sigue ahí
kubectl delete pod demo-pod
kubectl apply -f kind/pod.yaml
kubectl exec demo-pod -- cat /data/marker.txt
```

Limpieza:

```bash
kubectl delete -f kind/pod.yaml
kubectl delete -f kind/pvc.yaml
```

## Variante EKS: lectura

Mira `eks/storageclass.yaml` y `eks/pvc.yaml`. Diferencias esenciales respecto a kind:

- La `StorageClass` lleva `provisioner: ebs.csi.aws.com` y `parameters.type: gp3`.
- El `reclaimPolicy` que elegirías en producción es `Retain`.
- El binding es siempre `WaitForFirstConsumer`: si tu EKS tiene nodos en varias AZ (lo típico), es la única opción sensata.

## Qué observar

- `kubectl describe pvc` muestra los eventos de provisioning: *Provisioning*, *ExternalProvisioning*, *ProvisioningSucceeded*.
- `kubectl describe pv` muestra el `claimRef` apuntando al PVC y el `nodeAffinity` (en EBS: a la AZ; en local-path: al nodo).
- El PV se crea con nombre `pvc-<uuid>` cuando es dinámico.
