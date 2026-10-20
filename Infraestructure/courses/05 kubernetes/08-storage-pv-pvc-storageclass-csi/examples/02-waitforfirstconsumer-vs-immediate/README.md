# Ejemplo 02 — `WaitForFirstConsumer` vs `Immediate` lado a lado

## Concepto que demuestra

Las dos StorageClass de este ejemplo son *idénticas* salvo por `volumeBindingMode`. En kind (un solo nodo, una sola zona) **ambas** funcionan y la diferencia es invisible. Lo que vas a observar es el **momento** del binding:

- `sc-immediate`: el PV se crea tan pronto se crea el PVC.
- `sc-wait`: el PVC queda `Pending` hasta que un Pod lo monte; entonces se crea el PV.

En multi-AZ (EKS, GKE, AKS con varios nodos en zonas distintas) ese "momento" determina en qué AZ cae el disco. Con `Immediate` el provisioner elige a ciegas; con `WaitForFirstConsumer` el scheduler decide primero el nodo, respetando `nodeSelector`/`affinity`/`taints`, y luego el disco se crea en la AZ correcta.

## Prerrequisitos

- `kind` + un cluster corriendo.
- `kubectl` ≥ 1.28.

> local-path-provisioner (default en kind) acepta ambos `volumeBindingMode`. Para fines didácticos lo usamos como base; cambia el `provisioner` por `ebs.csi.aws.com` si quisieras llevar esto a EKS.

## Ejecución

```bash
# 1. Crea ambas StorageClass
kubectl apply -f storageclass-immediate.yaml
kubectl apply -f storageclass-wait.yaml

kubectl get storageclass sc-immediate sc-wait

# 2. Crea el PVC "immediate": observa que se liga YA
kubectl apply -f pvc-immediate.yaml
sleep 3
kubectl get pvc pvc-immediate      # STATUS: Bound (o Pending brevemente y luego Bound)

# 3. Crea el PVC "wait": observa que queda Pending
kubectl apply -f pvc-wait.yaml
sleep 3
kubectl get pvc pvc-wait           # STATUS: Pending
kubectl describe pvc pvc-wait      # mensaje: "waiting for first consumer to be created before binding"

# 4. Crea el Pod que consume el PVC "wait": ahora se liga
kubectl apply -f pod-wait.yaml
sleep 5
kubectl get pvc pvc-wait           # STATUS: Bound

# 5. Comparación directa
kubectl get pvc
kubectl get pv
```

## Qué deberías ver

- `pvc-immediate`: pasa a `Bound` sin esperar a ningún Pod. Hay un PV creado.
- `pvc-wait`: `Pending` con el mensaje *waiting for first consumer*. Solo al crear `pod-wait` se liga.

## Por qué importa fuera de kind

En un cluster EKS con nodos en `us-east-1a`, `us-east-1b` y `us-east-1c`:

- Con `Immediate`, si el provisioner elige `1a` y tu Pod tiene `nodeSelector: topology.kubernetes.io/zone=us-east-1c`, el Pod queda `Pending` con el error `node(s) had volume node affinity conflict`.
- Con `WaitForFirstConsumer`, el scheduler elige primero un nodo en `1c`, y luego el disco se crea en `1c`. Sin conflicto.

En kind no puedes reproducir el conflicto porque hay una sola zona (por default, los nodos de kind no tienen la label `topology.kubernetes.io/zone`). Puedes ejecutar la actividad 02 para razonar sobre el fix sin necesidad de un cluster multi-AZ real.

## Limpieza

```bash
kubectl delete -f pod-wait.yaml --ignore-not-found
kubectl delete -f pvc-immediate.yaml --ignore-not-found
kubectl delete -f pvc-wait.yaml --ignore-not-found
kubectl delete -f storageclass-immediate.yaml --ignore-not-found
kubectl delete -f storageclass-wait.yaml --ignore-not-found
```
