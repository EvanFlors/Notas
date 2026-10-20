# Ejemplo 01 — Instalar Argo CD en un cluster kind

## Concepto que demuestra

Qué objetos aparecen en el cluster al aplicar `install.yaml` oficial de Argo CD, dónde vive la contraseña inicial del admin, y cómo acceder a la UI por `port-forward`.

## Contexto

Partimos de un cluster vacío (kind). Instalamos Argo CD con el manifest oficial pinneado a un tag estable, listamos los Deployments y StatefulSets que aparecen, extraemos la contraseña inicial, y abrimos la UI. Todo en `/tmp/argo-02-ex01/`.

## Prerrequisitos

- Docker corriendo, `kind` ≥ 0.20, `kubectl` ≥ 1.28.
- Acceso a internet (para descargar el manifest y las imágenes de Argo CD).
- `argocd` CLI opcional en este ejemplo (se usa en los dos siguientes).

## Ejecución

Copia-pega bloque a bloque. Lee la salida antes de pasar al siguiente.

```bash
# 0. Entorno limpio.
mkdir -p /tmp/argo-02-ex01 && cd /tmp/argo-02-ex01

# 1. Cluster kind.
kind create cluster --name argo-02
kubectl config use-context kind-argo-02
kubectl get nodes
#   Debe haber al menos un nodo Ready.

# 2. Namespace para Argo CD.
kubectl create namespace argocd

# 3. Instalar Argo CD con tag pinneado.
#    (Siempre pinnea el tag; 'stable' se mueve.)
ARGO_VERSION=v2.13.1
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_VERSION}/manifests/install.yaml"
#   Lo que pasó:
#     - Se crearon CRDs: Application, AppProject, ApplicationSet.
#     - Se crearon ServiceAccounts, ClusterRoles, Roles.
#     - Se crearon 6 Deployments y 1 StatefulSet.

# 4. Esperar a que todo arranque.
kubectl -n argocd wait --for=condition=Available deploy --all --timeout=5m
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=5m

# 5. Inventario de lo que quedó.
kubectl -n argocd get deploy
#   argocd-applicationset-controller
#   argocd-dex-server
#   argocd-notifications-controller
#   argocd-redis
#   argocd-repo-server
#   argocd-server

kubectl -n argocd get sts
#   argocd-application-controller

kubectl -n argocd get svc
#   argocd-server (ClusterIP, 80/443)

kubectl -n argocd get crd | grep argoproj
#   applications.argoproj.io
#   applicationsets.argoproj.io
#   appprojects.argoproj.io

# 6. Contraseña inicial del admin.
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
#   Guarda la salida. Es la password inicial. Secreto por 1 uso.

# 7. Port-forward para la UI (en background).
kubectl -n argocd port-forward svc/argocd-server 8080:443 >/tmp/argo-02-ex01/pf.log 2>&1 &
PF_PID=$!
sleep 2

# 8. Abre la UI.
#    macOS: open https://localhost:8080
#    Linux: xdg-open https://localhost:8080
#    Login:  usuario 'admin', password del paso 6.
#    Acepta el certificado autofirmado.

# 9. Explora: Settings → Repositories (vacío), Applications (vacío).
#    En el próximo ejemplo creamos la primera Application.
```

## Observaciones clave

1. **Por qué `application-controller` es StatefulSet** y los demás Deployment: la asignación de shards se hace por ordinal (`-0`, `-1`...). Un Deployment no da identidad estable.
2. **Por qué port-forward al puerto 443 del Service**: `argocd-server` sirve gRPC + HTTP sobre TLS en 443. En labs se usa `port-forward 8080:443`. En producción se expone con Ingress + cert real.
3. **El Secret `argocd-initial-admin-secret`** se queda en el namespace. En prod se borra tras cambiar la password (`kubectl -n argocd delete secret argocd-initial-admin-secret`).

## Limpieza

```bash
# Mata el port-forward.
kill "$PF_PID" 2>/dev/null || true

# Opción A — borra solo Argo CD.
kubectl delete namespace argocd

# Opción B — borra el cluster entero (recomendado si era solo para este lab).
kind delete cluster --name argo-02

rm -rf /tmp/argo-02-ex01
```
