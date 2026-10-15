# Ejemplo 01 — Helm Release Walkthrough

> Puente al curso **helm**. Aquí solo instalamos un chart mínimo (`ingress-nginx`) y observamos cómo Helm materializa el *release lifecycle*. Para profundizar en chart authoring, `values`, dependencies, OCI, hooks, library charts, ver el **curso helm** (`courses/helm/`).

## Qué vamos a hacer

1. Crear un cluster local `kind`.
2. Instalar `ingress-nginx` con Helm.
3. Inspeccionar el **Release** (Secret, revisión, manifest renderizado).
4. Hacer un `upgrade` cambiando un `value`.
5. Hacer un `rollback`.
6. Limpiar.

## Prerrequisitos

- `kind` ≥ 0.20
- `kubectl` ≥ 1.28
- `helm` ≥ 3.13

Verifica:

```bash
kind --version && kubectl version --client=true -o yaml | grep gitVersion && helm version --short
```

## Pasos

### 1. Cluster local

```bash
mkdir -p /tmp/k8s-18-helm && cd /tmp/k8s-18-helm
cat > kind.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP
EOF
kind create cluster --name k8s18-helm --config kind.yaml
kubectl cluster-info --context kind-k8s18-helm
```

### 2. Instalar `ingress-nginx`

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install my-ing ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --wait --timeout 5m
```

### 3. Inspeccionar el Release

Helm guarda el estado del release como un Secret en el namespace:

```bash
# metadata del release
helm list -n ingress-nginx
helm status my-ing -n ingress-nginx

# el Secret donde vive la revisión 1
kubectl get secret -n ingress-nginx -l owner=helm,name=my-ing

# qué quedó realmente aplicado en el cluster para esta revisión
helm get manifest my-ing -n ingress-nginx | head -40

# los values efectivos (merge de default + overrides)
helm get values my-ing -n ingress-nginx --all | head -30
```

### 4. Upgrade (cambia un value)

```bash
helm upgrade my-ing ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --reuse-values \
  --set controller.replicaCount=2 \
  --wait

helm history my-ing -n ingress-nginx
kubectl -n ingress-nginx get deploy my-ing-ingress-nginx-controller
```

Verás la **revisión 2** en `helm history`.

### 5. Rollback

```bash
helm rollback my-ing 1 -n ingress-nginx --wait
helm history my-ing -n ingress-nginx
kubectl -n ingress-nginx get deploy my-ing-ingress-nginx-controller
```

Vuelve a `replicaCount: 1`.

### 6. Lectura mental

- Un `Release` = `name` + `namespace` + histórico de revisiones (Secrets).
- `helm install/upgrade` renderiza plantillas + aplica + guarda revisión.
- `helm rollback` reaplica una revisión anterior (no es magia: es "apply del YAML guardado").
- `helm uninstall` borra los recursos **y** las revisiones (salvo `--keep-history`).

## Puente al curso Helm

Lo que **no** cubre este ejemplo (y sí cubre `courses/helm/`):

- Escribir un chart desde cero (`Chart.yaml`, `templates/`, `_helpers.tpl`, `values.schema.json`).
- Library charts y `helpers` reutilizables.
- Dependencies (`Chart.yaml:dependencies:`) y `helm dep update`.
- OCI registries (`helm push oci://ghcr.io/...`, firma con cosign).
- Hooks (`pre-install`, `post-upgrade`, `test`).
- Patrón `umbrella chart` para apps multi-componente.
- Debug (`helm template`, `helm diff`, `--dry-run=server`).

## Limpieza

```bash
helm uninstall my-ing -n ingress-nginx
kubectl delete ns ingress-nginx
kind delete cluster --name k8s18-helm
rm -rf /tmp/k8s-18-helm
```
