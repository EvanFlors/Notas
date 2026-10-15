# Solución — k8s-08-02

## Diagnóstico

- La StorageClass `zonal-ssd` está en `volumeBindingMode: Immediate`.
- El Deployment pinnea el Pod a una AZ con `nodeSelector: topology.kubernetes.io/zone=us-east-1c`.
- Al crear el PVC, el provisioner EBS CSI crea el PV *antes* de que el scheduler mire al Pod. Elige una AZ (digamos `us-east-1a`).
- Cuando el scheduler intenta ubicar al Pod, no encuentra ningún nodo con la label `us-east-1c` **y** con un PV en esa AZ → `node(s) had volume node affinity conflict`.

## Fix

Cambiar la StorageClass a `volumeBindingMode: WaitForFirstConsumer`:

```yaml
volumeBindingMode: WaitForFirstConsumer
```

Con esto, el PVC queda `Pending` hasta que un Pod lo referencia. El scheduler decide primero el nodo (respetando `nodeSelector`); luego el CSI provisioner crea el PV en la misma AZ del nodo elegido. Imposible conflicto.

## Nota

No hay que borrar `nodeSelector`: la aplicación legítimamente necesita esa AZ. El error de diseño está en la StorageClass. Fijate que `Immediate` solo es tolerable cuando no hay restricciones zonales en el Pod *y* no hay multi-AZ, lo que en producción es casi nunca.

## Comando de aplicación (en EKS real)

```bash
kubectl apply -f solution/storageclass-bad.yaml   # reemplaza la vieja
kubectl delete pvc app-data -n k8s08-az          # borra el PVC viejo (ligado en AZ equivocada)
kubectl apply -f ../starter/pvc.yaml             # recrea
kubectl apply -f ../starter/deployment.yaml      # el Pod ahora puede programarse
```

En kind: aplicar es inofensivo pero no demuestra nada, porque hay un solo nodo y una sola "zona".
