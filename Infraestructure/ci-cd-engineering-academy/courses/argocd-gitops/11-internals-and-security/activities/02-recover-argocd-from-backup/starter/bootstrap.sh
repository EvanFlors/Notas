#!/usr/bin/env bash
# Bootstrap for argo-11-02-recover-argocd-from-backup.
# Takes a pre-disaster snapshot of the Applications so validate.sh can compare.
set -euo pipefail

BASE="${1:-/tmp/argo-11-02}"
if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi
mkdir -p "$BASE/work"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "SKIP: kubectl not installed" >&2; exit 0
fi
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  echo "SKIP: no active kube context" >&2; exit 0
fi
if ! kubectl get ns argocd >/dev/null 2>&1; then
  echo "SKIP: namespace 'argocd' not found. Install Argo CD first." >&2; exit 0
fi

count="$(kubectl -n argocd get applications --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -lt 2 ]; then
  echo "WARN: fewer than 2 Applications found ($count). Create at least 2 before continuing."
  echo "Example:"
  echo "  argocd app create guestbook-a --project default \\"
  echo "    --repo https://github.com/argoproj/argocd-example-apps \\"
  echo "    --path guestbook --dest-server https://kubernetes.default.svc \\"
  echo "    --dest-namespace demo-a --sync-option CreateNamespace=true"
fi

echo "== Snapshotting pre-disaster Applications =="
kubectl -n argocd get applications -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  > "$BASE/pre-disaster.apps"
echo "Snapshot:"
cat "$BASE/pre-disaster.apps"

cat > "$BASE/work/RUNBOOK.md" <<'EOF'
# Mi runbook de DR para Argo CD

> Rellénalo ANTES de ejecutar el desastre.

## Estrategia
A / B / C — justifica.

## Backup
Comandos exactos:

```

```

## Desastre
Comando exacto:

```

```

## Restore
Pasos:

```

```

## Verificación
Qué compruebas y con qué:

```

```

## RTO medido
tiempo total: _____ min
EOF

echo
echo "Bootstrap OK. Pre-disaster snapshot in $BASE/pre-disaster.apps"
echo "Edit your runbook at $BASE/work/RUNBOOK.md"
