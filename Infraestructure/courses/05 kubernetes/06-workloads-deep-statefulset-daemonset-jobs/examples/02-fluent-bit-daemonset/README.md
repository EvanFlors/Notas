# Ejemplo 02 — fluent-bit como `DaemonSet`

## Concepto que demuestra

- `DaemonSet` → **un Pod por nodo**.
- Patrón canónico de *log forwarder* leyendo `/var/log/containers/*` del host.
- `tolerations: Exists` para que el DS corra incluso en nodos con taints (control plane).

## Contexto

En producción nunca hagas `tail -f` de logs manualmente: cada nodo tiene un *agent* (fluent-bit, Vector, promtail) que lee los logs de todos los contenedores y los envía a un backend (Loki/ES/CloudWatch). El patrón "un agent por nodo" es exactamente el que un `DaemonSet` modela.

## Objetivo

Al terminar sabrás:

- Cómo luce un DS típico (volúmenes `hostPath`, tolerations amplias).
- Cómo verificar que *efectivamente* hay un Pod por nodo.
- Qué pasa cuando añades (o quitas) un nodo.

## Prerrequisitos

- `kind` con **al menos 2 nodos** para que el "uno por nodo" sea observable. Crea uno si no:

  ```bash
  cat <<EOF > /tmp/kind-k8s06.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
    - role: control-plane
    - role: worker
    - role: worker
  EOF
  kind create cluster --name k8s-06 --config /tmp/kind-k8s06.yaml
  ```

## Ejecución

```bash
kubectl apply -f manifests/fluent-bit.yaml

# Un Pod por nodo
kubectl -n logging get ds fluent-bit
kubectl -n logging get pods -o wide -l app=fluent-bit

# Debe mostrar DESIRED == CURRENT == READY == (nº de nodos)
kubectl get nodes
```

Verifica que los logs llegan:

```bash
POD=$(kubectl -n logging get pods -l app=fluent-bit -o jsonpath='{.items[0].metadata.name}')
kubectl -n logging logs "$POD" --tail=20
```

Añade un nodo (si tu cluster lo permite) y vuelve a mirar: el DS se escala automáticamente.

## Resultado esperado

- `kubectl -n logging get ds fluent-bit` muestra `DESIRED == CURRENT == READY == <nº de nodos>`.
- `kubectl -n logging get pods -o wide` muestra un Pod distinto por nodo (`NODE` columna).
- `kubectl -n logging logs <pod>` muestra líneas de logs reenviadas.

## Preguntas de reflexión

1. ¿Por qué `hostPath` y no un `PVC`? ¿Qué pasaría con un PVC `ReadWriteOnce` en un DS de 3 Pods?
2. ¿Qué pasaría si quitas la `toleration: Exists`? ¿En qué nodos no correría?
3. Si quieres que el DS **solo** corra en nodos con GPUs, ¿qué añades?
4. ¿Por qué un DS no tiene `replicas`?

## Limpieza

```bash
kubectl delete -f manifests/fluent-bit.yaml --ignore-not-found
```
