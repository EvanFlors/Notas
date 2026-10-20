# Root cause — pending-mystery (reference)

- **Sintoma**: el Pod `pending-mystery` lleva en `Pending` desde su creacion. `kubectl get pod` nunca lo pasa a `Running`.
- **Evento**: `kubectl describe pod pending-mystery` termina con un `Warning  FailedScheduling` del `default-scheduler`: `0/N nodes are available: N node(s) didn't match Pod's node affinity/selector`.
- **Componente responsable**: `kube-scheduler`. En `kind` corre como static Pod en `kube-system` (`kubectl -n kube-system get pods -l component=kube-scheduler`).
- **Plugin del scheduling framework**: `NodeAffinity` (extension points `Filter` y `Score`). Evalua `spec.nodeSelector` y `spec.affinity.nodeAffinity`; descarta cualquier nodo que no case y, si no queda ninguno, emite el `FailedScheduling`.
- **Causa raiz en el YAML**: `spec.nodeSelector.disktype: unobtanium-xyz`. Ningun nodo del cluster tiene esa label, asi que el filtro deja la lista de candidatos vacia.
- **Cadena end-to-end**:
  1. `kubectl apply` -> `kube-apiserver` autentica, autoriza, pasa admission, valida, persiste el Pod en `etcd` con `spec.nodeName=""`.
  2. `kube-scheduler` lo ve por su WATCH, corre `PreFilter -> Filter`.
  3. En `Filter`, el plugin `NodeAffinity` descarta cada nodo porque no tiene la label `disktype=unobtanium-xyz`.
  4. Como ningun nodo pasa, `PostFilter` ejecuta `DefaultPreemption` -- tampoco ayuda.
  5. El scheduler emite el Event `FailedScheduling` y re-encola el Pod con backoff.
- **Fix minimo sin tocar el workload**: etiquetar un nodo existente con `kubectl label node <node> disktype=unobtanium-xyz`. En segundos el scheduler re-evalua y bindea.
- **Fix preferible a largo plazo**: eliminar el `nodeSelector` del Pod o migrarlo a `preferredDuringSchedulingIgnoredDuringExecution`.

Frases clave requeridas por el validator: Pending, FailedScheduling, nodeSelector, NodeAffinity, kube-scheduler.
