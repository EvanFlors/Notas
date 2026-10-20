# Ejemplo 02 — ARC mínimo en kind

> Walkthrough reproducible. Levantamos un cluster `kind`, instalamos el **operator** de ARC y un **scale set** con credenciales dummy, verificamos los CRDs y revisamos los pods. **No** conectamos a GitHub real — la actividad `02` cubre eso en modo local-only.

## Qué queda al final

- Un cluster `kind` llamado `arc-demo`.
- Dos namespaces: `arc-systems` (operator) y `arc-runners` (scale set).
- CRDs instaladas de `actions.github.com`.
- Un `Secret` con un PAT **dummy** (`ghp_dummy...`) — no conectará, pero el schema del scale set es válido.
- Un release de Helm `arc-controller` (operator).
- Un release de Helm `my-runners` (scale set) — el listener fallará auth (es lo esperado) pero el CR existirá.

Esto demuestra: **sabemos operar la pieza**. Que el listener no auth-ee contra GitHub real es intencional (sin cuenta no se puede).

## Requisitos

- `docker` corriendo.
- `kind` ≥ 0.20.
- `kubectl` ≥ 1.28.
- `helm` ≥ 3.12.
- ~2 GB de RAM libres.

Si falta algo, el script del ejemplo imprime qué instalar y sale limpio.

## Comandos (resumen; ver `examples/02-arc-in-kind/README.md` como referencia)

```bash
# 1. Cluster kind
cat <<'EOF' > /tmp/kind-arc.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: arc-demo
nodes:
  - role: control-plane
EOF
kind create cluster --config /tmp/kind-arc.yaml

# 2. Namespaces
kubectl create namespace arc-systems
kubectl create namespace arc-runners

# 3. Operator
helm install arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3

# 4. Secret dummy
kubectl create secret generic github-dummy \
  --namespace arc-runners \
  --from-literal=github_token='ghp_dummyDUMMYdummyDUMMYdummyDUMMYdummy0'

# 5. Scale set apuntando a un repo ficticio
helm install my-runners \
  --namespace arc-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.9.3 \
  --set githubConfigUrl="https://github.com/example-org/example-repo" \
  --set githubConfigSecret=github-dummy \
  --set minRunners=0 \
  --set maxRunners=1
```

## Qué verificar

```bash
# CRDs instaladas por el operator
kubectl get crd | grep actions.github.com
# autoscalinglisteners.actions.github.com
# autoscalingrunnersets.actions.github.com
# ephemeralrunners.actions.github.com
# ephemeralrunnersets.actions.github.com

# Operator corriendo
kubectl get deploy -n arc-systems
# NAME                               READY  UP-TO-DATE  AVAILABLE
# arc-gha-rs-controller              1/1    1           1

# Scale set CR creado
kubectl get autoscalingrunnerset -n arc-runners
# NAME         MINIMUM RUNNERS   MAXIMUM RUNNERS   ...
# my-runners   0                 1

# Listener creado por el operator (crashea por auth, es esperado)
kubectl get pods -n arc-runners
# NAME                        READY  STATUS           RESTARTS
# my-runners-xxxx-listener    0/1    CrashLoopBackOff  N
```

El `CrashLoopBackOff` del listener con un token dummy **es la señal correcta**:

```bash
kubectl logs -n arc-runners deploy/my-runners-xxxx-listener | tail -5
# ...
# Error: HTTP 401 Unauthorized
```

Esto prueba:

- Los CRDs están instaladas.
- El operator aceptó el CR (schema válido).
- El operator creó el listener Deployment correctamente.
- Falla solo porque el PAT no autentica — es exactamente lo esperado sin GitHub real.

## Qué cambia en modo "live"

Con un PAT real (fine-grained, `Administration: R/W` sobre `example-org/example-repo`) o una GitHub App:

```bash
kubectl create secret generic github-live \
  --namespace arc-runners \
  --from-literal=github_token='ghp_REAL...'

helm upgrade my-runners \
  --namespace arc-runners \
  oci://.../gha-runner-scale-set \
  --set githubConfigUrl="https://github.com/<org>/<repo>" \
  --set githubConfigSecret=github-live \
  --set minRunners=0 \
  --set maxRunners=3
```

Y en `<org>/<repo>/.github/workflows/`:

```yaml
jobs:
  test:
    runs-on: my-runners   # ¡mismo nombre del release!
    steps: ...
```

Un `gh workflow run` dispara el job → el listener recibe `JobAssignment` → el operator crea un pod runner → el runner se auto-registra con un reg-token efímero → ejecuta → muere.

## Limpieza

```bash
helm uninstall my-runners -n arc-runners || true
helm uninstall arc        -n arc-systems || true
kubectl delete ns arc-runners arc-systems --ignore-not-found
kind delete cluster --name arc-demo
```

## Qué quiero que leas con lupa

- **Dos charts, no uno.** El operator es cluster-wide (`arc-systems`); los scale sets son per-target (`arc-runners/*`).
- **El CRD `AutoscalingRunnerSet` es tu interfaz declarativa.** Todo lo demás lo gestiona el operator.
- **El listener es un pod separado**, uno por scale set. Hace el long-polling. Si auth falla, nada downstream funciona.
- **El label del workflow (`runs-on`) es el nombre del release de Helm**, no una label como `self-hosted`.
- **Con `minRunners: 0`, cero pods runner corren** cuando no hay jobs. Pagas solo el operator + listener (~muy poco).

La actividad `02` te hace reproducir esto end-to-end y añade el ADR con el razonamiento.
