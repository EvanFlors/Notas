# Solución — k8s-08-01

Esta actividad es **guided**: los manifests "solución" son los mismos que entrega el starter. El contenido pedagógico es la ejecución y la lectura de los eventos.

Lo que debe quedar claro:

1. El PVC se liga a un PV dinámico creado por el provisioner `local-path` de kind. `kubectl describe pv <pv-name>` muestra que el disco físico es un directorio dentro del nodo kind (algo como `/var/local-path-provisioner/...`).
2. Al borrar el Pod, el PVC sobrevive, y por lo tanto el PV y el disco. Al recrear el Pod, el mismo volumen se monta y los datos están ahí.
3. Los manifests de snapshot son sintácticamente correctos. `local-path` no implementa snapshot, pero en un cluster con `aws-ebs-csi-driver` + snapshotter, los mismos manifests (cambiando `driver` y `storageClassName`) crean un snapshot real.
4. El PVC restaurado nace con los datos ya adentro gracias a `dataSource`.

Comandos de referencia:

```bash
kubectl -n k8s08-pg describe pvc pg-data
kubectl get pv
kubectl -n k8s08-pg logs pg --tail=20
```

Para una traza de eventos del PVC:

```bash
kubectl -n k8s08-pg get events --sort-by=.lastTimestamp | grep pg-data
```
