#!/usr/bin/env bash
# Bootstrap de la actividad 02: layout de scratch + stubs del ADR y manifiestos.
# NOTE: no usamos `set -o pipefail` globalmente (SIGPIPE con grep -q).
set -eu

DEST="${1:-/tmp/arc-mini}"

echo "[info] bootstrap DEST=$DEST"

rm -rf "$DEST"
mkdir -p "$DEST/docs" "$DEST/manifests" "$DEST/bin"

# ---- Escenario para el ADR ----
cat > "$DEST/docs/SCENARIO.md" <<'EOF'
# Escenario para el ADR

Eres el platform engineer de una empresa SaaS mediana ("Acme Logistics").

Contexto:

- Repo **privado** `acme/platform` (monorepo).
- ~1.800 workflow runs/mes.
- Builds de contenedores pesados (~12 min, 8 GB RAM) y tests de integración
  con Postgres y Redis en servicios de sidecar.
- Deploys requieren acceso a RDS en una **VPC privada** (sin IP pública).
- Equipo plataforma de 4 personas; ya opera un cluster EKS para la app.
- Compliance: SOC2; auditoría exige evidencia de "nadie más corre código en
  nuestra infra sin aprobación".
- Factura actual de Actions hosted: ~USD 1.100/mes y creciendo linealmente.

Tu tarea: elegir **GitHub-hosted estándar**, **larger runners**, **self-hosted VMs**
o **ARC en K8s**, y justificar en ADR-001.
EOF

# ---- Stub del ADR ----
cat > "$DEST/docs/ADR-001-runner-choice.md" <<'EOF'
# ADR-001 — Elección de infraestructura de runners para Acme Logistics

Status: Proposed
Date: 2025-01-01
Author: <tu nombre>

## Contexto

<Resume el escenario de SCENARIO.md: visibilidad del repo, volumen, requisitos
de red, equipo, compliance, coste actual. Al menos 4-6 líneas.>

## Opciones evaluadas

1. **GitHub-hosted** estándar — <pros/cons breves>
2. **Larger runners** hosted — <pros/cons breves>
3. **Self-hosted VMs** administradas — <pros/cons breves>
4. **ARC en Kubernetes** (sobre el EKS existente) — <pros/cons breves>

## Decisión

<Una línea con la decisión y 1-2 líneas de rationale.>

## Consecuencias

- **Operación**: <...>
- **Coste estimado**: <...>
- **Seguridad / compliance**: <...>
- **Plan si crece 10x**: <...>
EOF

# ---- Manifest: kind config ----
cat > "$DEST/manifests/kind-config.yaml" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: arc-mini
nodes:
  - role: control-plane
EOF

# ---- Manifest: values del scale set ----
cat > "$DEST/manifests/values.yaml" <<'EOF'
# Minimal values para gha-runner-scale-set.
# NOTA: githubConfigUrl apunta a un repo FICTICIO; el PAT es dummy; el listener
# va a fallar auth y eso es ESPERADO. Lo que validamos es que el CR es válido.
githubConfigUrl: "https://github.com/example-org/example-repo"
githubConfigSecret: "github-dummy"
minRunners: 0
maxRunners: 1
runnerGroup: "default"
EOF

# ---- Script helper opcional (atajo para aplicar la infra) ----
cat > "$DEST/bin/apply-infra.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"

for tool in docker kind kubectl helm; do
  command -v "$tool" >/dev/null 2>&1 || { echo "[fail] $tool no está instalado"; exit 2; }
done

kind create cluster --name arc-mini --config "$HERE/manifests/kind-config.yaml" || true
kubectl create namespace arc-systems --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -

helm install arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3 || helm upgrade arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3

kubectl -n arc-runners create secret generic github-dummy \
  --from-literal=github_token='ghp_dummyDUMMYdummyDUMMYdummyDUMMYdummy0' \
  --dry-run=client -o yaml | kubectl apply -f -

helm install my-runners \
  --namespace arc-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.9.3 \
  -f "$HERE/manifests/values.yaml" || true

echo "[ok] infra aplicada. Verifica con:"
echo "     kubectl get crd | grep actions.github.com"
echo "     kubectl get autoscalingrunnerset -n arc-runners"
EOF
chmod +x "$DEST/bin/apply-infra.sh"

echo "[ok] bootstrap listo en $DEST"
echo "siguiente:"
echo "  1) edita $DEST/docs/ADR-001-runner-choice.md"
echo "  2) (opcional, si tienes kind+kubectl+helm) bash $DEST/bin/apply-infra.sh"
echo "  3) bash tests/validate.sh $DEST"
