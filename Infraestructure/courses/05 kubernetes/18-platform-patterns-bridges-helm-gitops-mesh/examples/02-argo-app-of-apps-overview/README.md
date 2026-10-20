# Ejemplo 02 — Argo CD "app-of-apps" overview

> Puente al curso **argocd-gitops**. Aquí instalamos Argo CD en un cluster local y creamos **un** `Application` que apunta a un repo público para ver el loop GitOps. Para profundizar (projects, SSO, sync waves, hooks, ApplicationSet avanzado, Argo Rollouts, Argo Workflows), ver el **curso argocd-gitops** (`courses/argocd-gitops/`).

## Qué vamos a hacer

1. Cluster `kind`.
2. Instalar Argo CD con el manifest oficial.
3. Crear un `Application` apuntando a `argoproj/argocd-example-apps` (`guestbook`).
4. Ver cómo Argo CD sincroniza y reconcilia.
5. Mostrar la idea del patrón **app-of-apps**.
6. Limpiar.

## Prerrequisitos

- `kind`, `kubectl` (como en el ejemplo 01).
- Red hacia GitHub (los manifests y la app de ejemplo vienen de ahí).

## Pasos

### 1. Cluster local

```bash
mkdir -p /tmp/k8s-18-argo && cd /tmp/k8s-18-argo
kind create cluster --name k8s18-argo
```

### 2. Instalar Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que el server esté listo
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m
```

Password inicial de `admin`:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Port-forward de la UI (opcional):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
# UI en https://localhost:8080  (usuario: admin, password: la de arriba)
```

### 3. Crear un `Application`

```bash
cat > guestbook-app.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

kubectl apply -f guestbook-app.yaml
```

Ver estado:

```bash
kubectl -n argocd get applications
kubectl -n guestbook get all
```

Al cabo de pocos segundos, `guestbook-ui` y `redis` deberían estar `Running`.

### 4. Probar el loop GitOps (drift)

Borra "manualmente" el deployment y mira cómo Argo CD lo repone (gracias a `selfHeal`):

```bash
kubectl -n guestbook delete deploy guestbook-ui
# espera ~10-30s
kubectl -n guestbook get deploy guestbook-ui
```

Vuelve, porque el **estado deseado** (en el repo) manda.

### 5. Patrón app-of-apps (idea)

Un `Application` "raíz" apunta a un path con manifests de **otros** `Application`. Argo CD aplica los hijos, y los hijos despliegan sus workloads.

```
       root-app  (apunta a path "/apps" en un repo)
          |
    +-----+------+------+
    |     |      |      |
  app-a app-b  app-c  ...   (cada uno = un Application CR)
    |
  workloads reales
```

Esto permite **bootstrap** del cluster entero con un único `kubectl apply` del root. No lo instalamos aquí (es tema del curso argocd-gitops), pero el concepto queda ilustrado.

Un `ApplicationSet` con el `git` generator (directories) es el sucesor "escalable" del app-of-apps.

### 6. Lectura mental

- Argo CD = otro controller en el cluster que *pulls* el estado deseado desde Git.
- `Application` es la unidad declarativa; se puede componer con app-of-apps o generar con `ApplicationSet`.
- `syncPolicy.automated` + `selfHeal` = reconciliación continua.
- Credenciales del cluster **nunca** salen del cluster.

## Puente al curso argocd-gitops

Lo que **no** cubre este ejemplo (y sí cubre `courses/argocd-gitops/`):

- `AppProject` (multi-tenant, scoping, denies).
- `ApplicationSet` con generators (list, cluster, git, matrix, pull-request).
- Sync waves, hooks (`PreSync`, `PostSync`, `SyncFail`).
- Argo CD CLI (`argocd app sync`, `argocd app diff`, `argocd login`).
- SSO (OIDC/Dex), RBAC fino.
- Imagen updater (`argocd-image-updater`) y promoción entre entornos.
- Argo Rollouts (canary/blue-green) y Argo Workflows (CI nativo).
- Flux side-by-side comparison.

## Limpieza

```bash
# matar el port-forward si está activo
pkill -f "port-forward svc/argocd-server" || true

kubectl delete -f guestbook-app.yaml --ignore-not-found
kubectl delete ns guestbook --ignore-not-found
kubectl delete ns argocd --ignore-not-found
kind delete cluster --name k8s18-argo
rm -rf /tmp/k8s-18-argo
```
