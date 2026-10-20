# Ejercicio operativo — Kubernetes exam

> Entorno obligatorio: cluster local **kind**. Si no tienes kind instalado, SKIP este ejercicio y notifícalo al instructor; perderás los 40 pts de la sección.

## 0. Prerrequisitos

- `kind` >= 0.20
- `kubectl` compatible con la versión del cluster (ver `kind-config.yaml`)
- `jq` (lo usa `validate.sh`)
- Puerto libre: ninguno en host (todo intra-cluster)

## 1. Crear el cluster

```bash
kind create cluster --name k8s-exam --config kind-config.yaml
kubectl cluster-info --context kind-k8s-exam
kubectl create namespace exam
kubectl config set-context --current --namespace exam
```

El `kind-config.yaml` provisto define 1 control-plane + 2 workers, suficiente para `PodDisruptionBudget` con `minAvailable: 2` y antiAffinity opcional.

## 2. Tarea

Entrega en este directorio los siguientes archivos (nombres libres, pero deben aplicarse con `kubectl apply -f .`):

1. `deployment.yaml` — `Deployment/http-echo` en namespace `exam`:
   - Imagen pineada: `hashicorp/http-echo:0.2.3` (no `latest`).
   - 3 réplicas, label `app=http-echo`.
   - Container args: `-text=hello-v1`, puerto `5678`.
   - `resources.requests`: `cpu: 10m`, `memory: 16Mi`. `limits`: `cpu: 100m`, `memory: 64Mi`.
   - `securityContext`: `runAsNonRoot: true`, `runAsUser: 1001`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true`.
   - `startupProbe`, `readinessProbe`, `livenessProbe` con **tres rutas o semánticas distintas** y timings justificables (la imagen responde en `/` siempre con 200; eso es suficiente — lo evaluado es que las tres existan con parámetros distintos y coherentes).
   - `strategy.rollingUpdate`: `maxUnavailable: 0`, `maxSurge: 1`.
2. `service.yaml` — `Service/http-echo` ClusterIP puerto 80 → 5678.
3. `pdb.yaml` — `PodDisruptionBudget` con `minAvailable: 2` que seleccione `app=http-echo`.
4. `netpol.yaml` — dos `NetworkPolicy`:
   - `default-deny-all` en el namespace `exam` (`policyTypes: [Ingress, Egress]`, `podSelector: {}`, sin rules).
   - `allow-client-to-echo` que permita ingress al `app=http-echo` **solo** desde pods con label `role=client` en el mismo namespace, puerto 5678. Debe permitir también egress DNS (UDP/TCP 53 a `kube-system`) para los pods afectados si bloqueas egress — ajusta como consideres.
5. `clients.yaml` — dos pods de prueba (image `curlimages/curl:8.9.1`, comando `sleep 3600`):
   - `curl-client` con label `role=client`.
   - `curl-unauth` sin label (o `role=unauth`).

## 3. Rolling update sin downtime

Mientras el cliente autorizado hace peticiones continuas:

```bash
kubectl exec -n exam curl-client -- sh -c \
  'i=0; while [ $i -lt 300 ]; do curl -s -o /dev/null -w "%{http_code}\n" http://http-echo.exam.svc.cluster.local/ || echo FAIL; i=$((i+1)); sleep 0.2; done' | tee rollout.log
```

En otra terminal:

```bash
kubectl set image deploy/http-echo http-echo=hashicorp/http-echo:0.2.3 -n exam \
  && kubectl patch deploy http-echo -n exam --type=json \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["-text=hello-v2","-listen=:5678"]}]'
kubectl rollout status deploy/http-echo -n exam
```

El archivo `rollout.log` debe contener **únicamente** `200` (0 `FAIL`, 0 `5xx`). Adjúntalo.

## 4. Validación

```bash
bash validate.sh
echo "exit=$?"
```

Debe terminar con `exit=0`. El script revisa deployment, probes diferenciadas, PDB, NetworkPolicies, bloqueo del pod no autorizado y acceso del autorizado.

## 5. Limpieza

```bash
kind delete cluster --name k8s-exam
```

## 6. Entregables

En este directorio, al terminar:

- `deployment.yaml`, `service.yaml`, `pdb.yaml`, `netpol.yaml`, `clients.yaml`
- `rollout.log` (output del loop del cliente durante el rollout)
- `validate.out` (`bash validate.sh > validate.out 2>&1`)

No incluyas secretos ni kubeconfigs.
