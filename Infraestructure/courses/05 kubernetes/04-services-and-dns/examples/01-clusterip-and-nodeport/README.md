# Ejemplo 01 — ClusterIP y NodePort sobre el mismo Deployment

## Concepto que demuestra

- Un mismo `Deployment` puede ser expuesto por **varios Services** con tipos distintos.
- `ClusterIP` da un VIP solo accesible dentro del cluster.
- `NodePort` publica un puerto `30000–32767` en **todos** los nodos (y, en kind, lo mapeamos al host).
- `kubectl get endpoints` muestra que ambos Services apuntan a los **mismos** Pods: lo que cambia es cómo se accede, no quién recibe.

## Contexto

En un cluster real nunca pondrías NodePort directo en producción, pero es el modo más visual de ver "qué significa un Service" sin salir a un cloud. Levantamos un cluster `kind` con un **port-mapping** del nodo al host para poder hacer `curl` desde tu máquina.

## Objetivo

Al terminar sabrás:

- Diferenciar `port`, `targetPort` y `nodePort`.
- Leer `kubectl get svc` y entender la columna `CLUSTER-IP` vs `EXTERNAL-IP` vs `PORT(S)`.
- Ver con tus ojos que ClusterIP y NodePort comparten endpoints.

## Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, Docker daemon arriba.
- Puertos 30080 del host libres.
- Sin costo (todo local).

## Ejecución

Trabaja en `/tmp/k8s-04-ex01/`. Copia-pega bloque a bloque y lee la salida.

```bash
mkdir -p /tmp/k8s-04-ex01 && cd /tmp/k8s-04-ex01

# 0. Cluster limpio con un port-mapping del nodo al host (NodePort 30080 → host 30080).
cat > kind.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
YAML

kind delete cluster --name k8s04-ex1 >/dev/null 2>&1 || true
kind create cluster --name k8s04-ex1 --config kind.yaml --wait 90s
kubectl config use-context kind-k8s04-ex1
kubectl get nodes
```

Ahora el workload y los dos Services:

```bash
cat > web.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-clusterip
spec:
  type: ClusterIP     # (default; lo escribimos para enfatizar)
  selector:
    app: web
  ports:
    - port: 80        # puerto del VIP
      targetPort: 80  # puerto del Pod
---
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080 # fijo para poder mapearlo desde kind
YAML

kubectl apply -f web.yaml
kubectl rollout status deploy/web --timeout=60s
```

Mira ambos Services y sus endpoints:

```bash
kubectl get svc
#   CLUSTER-IP distinto cada uno; web-nodeport muestra "80:30080/TCP".

kubectl get endpoints web-clusterip web-nodeport
#   Ambos listan las MISMAS 3 IPs:puerto. Es la clave del ejemplo.

kubectl get endpointslices -l 'kubernetes.io/service-name in (web-clusterip,web-nodeport)'
#   EndpointSlices es la primitiva moderna; cada Service tiene al menos una.
```

Prueba desde dentro del cluster (ClusterIP) y desde fuera (NodePort → host):

```bash
# Pod cliente efímero para probar el ClusterIP.
kubectl run tmp --image=curlimages/curl:8.9.1 --rm -it --restart=Never -- \
  curl -sS -o /dev/null -w "ClusterIP HTTP %{http_code}\n" http://web-clusterip
# Esperado: "ClusterIP HTTP 200".

# Desde tu máquina (host), a través del port-mapping del nodo kind.
curl -sS -o /dev/null -w "NodePort  HTTP %{http_code}\n" http://localhost:30080
# Esperado: "NodePort  HTTP 200".
```

Bonus — ver qué Pod atendió:

```bash
for i in 1 2 3 4; do
  kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
    sh -c 'curl -sS http://web-clusterip/ -o /dev/null -w "pod=%{remote_ip}\n"'
done
# Las IPs van rotando entre los 3 Pods (balanceo iptables).
```

## Resultado esperado

- `kubectl get svc` lista `web-clusterip` (ClusterIP) y `web-nodeport` (NodePort 80:30080/TCP).
- `kubectl get endpoints` muestra las **mismas** 3 IPs para ambos Services.
- `curl http://web-clusterip` desde un Pod → `HTTP 200`.
- `curl http://localhost:30080` desde el host → `HTTP 200`.

## Preguntas de reflexión

1. ¿Por qué un `NodePort` también tiene `CLUSTER-IP`? (Pista: NodePort es *superconjunto* de ClusterIP.)
2. ¿Qué pasaría si cambiaras `targetPort: 80` a `targetPort: 8080` en `web-clusterip`? ¿`kubectl get endpoints` cambiaría? ¿`curl` cambiaría?
3. ¿Por qué `kind` necesita `extraPortMappings` para que llegue el `curl` del host? ¿Dónde "vive" el nodo del cluster?

## Limpieza

```bash
kind delete cluster --name k8s04-ex1
rm -rf /tmp/k8s-04-ex01
```
