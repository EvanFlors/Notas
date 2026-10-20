# Ejemplo 01 — Crear un cluster kind y leer su kubeconfig

## Concepto que demuestra

Qué pasa cuando creas un cluster con `kind create cluster`: qué contenedores se levantan, qué contexto aparece en tu kubeconfig, y cómo verificar que el apiserver efectivamente responde.

## Contexto

Primer cluster "real". No instalamos nada dentro aún — solo lo levantamos, miramos su anatomía y lo destruimos. Trabajamos en `/tmp/k8s-02-ex01/`.

## Objetivo

Al terminar sabrás:

- Qué entrada añade `kind` a tu kubeconfig.
- Qué es físicamente un "nodo" en kind (un contenedor).
- Cómo `kubectl` sabe contra qué cluster hablar sin que le pases nada.
- Cómo destruir el cluster sin dejar basura.

## Prerrequisitos

- Docker corriendo (`docker info` responde).
- `kind` y `kubectl` instalados (`kind version`, `kubectl version --client`).
- Puerto efímero libre (kind elige uno automáticamente, no colisiona).

## Ejecución

Copia-pega bloque a bloque. **Lee la salida antes de pasar al siguiente.**

```bash
# 0. Entorno limpio.
mkdir -p /tmp/k8s-02-ex01 && cd /tmp/k8s-02-ex01
kind delete cluster --name ex01 >/dev/null 2>&1 || true

# 1. CREAR el cluster (nombre explícito).
kind create cluster --name ex01
#   Lo que pasó por debajo:
#     - kind levantó UN contenedor Docker (nodo "control-plane") con la imagen
#       kindest/node:<version>. Dentro corre containerd + kubelet + los
#       componentes del control plane (apiserver, scheduler, controller-manager, etcd).
#     - kind generó certs, un kubeconfig, y lo FUSIONÓ en ~/.kube/config.
#     - Añadió el contexto "kind-ex01" y lo dejó como current-context.

# 2. Ver el contenedor-nodo.
docker ps --filter name=ex01 --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
#   Debe aparecer "ex01-control-plane" con una imagen kindest/node:v1.XX.X.

# 3. Ver el contexto que kind agregó.
kubectl config get-contexts
#   Marca con "*" el actual. Debe estar en "kind-ex01".

# 4. El cluster responde.
kubectl cluster-info
#   Imprime URL del apiserver (https://127.0.0.1:<puerto-random>)
#   y la de CoreDNS.

kubectl get nodes -o wide
#   Un nodo "ex01-control-plane" en Ready, con su versión de K8s.

# 5. Mirar el kubeconfig que kind inyectó.
kubectl config view --minify
#   --minify solo muestra el contexto actual. Fíjate en:
#     - server: https://127.0.0.1:<puerto>
#     - certificate-authority-data y client-certificate-data (base64, redacted
#       por default con --minify salvo --raw).

# 6. "¿Qué namespaces trajo de fábrica?"
kubectl get namespaces
#   default, kube-system, kube-public, kube-node-lease, local-path-storage.
#   kind trae un StorageClass "standard" (local-path) para PVCs educativos.

# 7. Pods del control plane corriendo DENTRO del contenedor-nodo.
kubectl get pods -n kube-system
#   coredns-*, etcd-*, kube-apiserver-*, kube-controller-manager-*,
#   kube-proxy-*, kube-scheduler-*, kindnet-* (CNI por default).

# 8. Confirmación visual: el "nodo" es un contenedor Docker.
docker exec ex01-control-plane crictl ps | head -5
#   crictl es el cliente CRI. Verás los contenedores REALES que corren
#   los Pods del control plane dentro del "nodo".
```

## Resultado esperado

- `kind create cluster --name ex01` termina sin error en < 60 s.
- `docker ps` muestra `ex01-control-plane`.
- `kubectl config get-contexts` lista `kind-ex01` con `*`.
- `kubectl get nodes` lo muestra `Ready`.
- `kubectl get pods -n kube-system` lista los 6-7 Pods del control plane en `Running`.

## Limpieza

```bash
kind delete cluster --name ex01
rm -rf /tmp/k8s-02-ex01
# Verifica que no quedó el contenedor:
docker ps -a --filter name=ex01 --format '{{.Names}}'   # debe salir vacío
# Verifica que no quedó el contexto:
kubectl config get-contexts | grep ex01 || echo "contexto limpio"
```

## Preguntas de reflexión

1. `kind create cluster` sin `--name` crea uno llamado "kind" (contexto `kind-kind`). ¿Qué pasa si lo corres dos veces sin `--name`?
2. ¿Por qué `kubectl` apunta al cluster recién creado sin que tú se lo digas? ¿Qué cambió en `~/.kube/config`?
3. Si matas Docker (`docker stop ex01-control-plane`), ¿qué devuelve `kubectl get nodes` y por qué?
4. En un kind multi-nodo (`--config` con 1 control-plane + 2 workers), ¿cuántos contenedores Docker aparecen?
