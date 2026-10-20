#!/usr/bin/env bash
# Validador estructural para cap-12-01-eso-vault-wiring.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which exits early on match and emits SIGPIPE (exit 141) in
# the upstream command; pipefail would flag those as spurious failures.
set -eu

BASE="${1:-/tmp/cap-12-01}"
CSS="$BASE/clustersecretstore.yaml"
ES="$BASE/externalsecret.yaml"
fail=0

echo "== Validando cap-12-01 en $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE no existe. Copia starter/ ahi primero (cp -R starter/ $BASE)." >&2
  exit 1
fi

for f in "$CSS" "$ES"; do
  if [ ! -f "$f" ]; then
    echo "  FAIL $f no existe"
    fail=$((fail+1))
  fi
done
[ "$fail" -gt 0 ] && { echo "RESULT: $fail falla(s)."; exit 1; }

# YAML parse (best effort).
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$CSS')); yaml.safe_load(open('$ES'))" >/dev/null 2>&1; then
    echo "  OK   YAMLs parsean"
  else
    echo "  FAIL algun YAML no parsea"
    fail=$((fail+1))
  fi
else
  echo "  WARN python3 ausente; skip YAML parse"
fi

# ClusterSecretStore kind + vault + kubernetes auth.
if grep -q 'kind:[[:space:]]*ClusterSecretStore' "$CSS"; then
  echo "  OK   kind=ClusterSecretStore"
else
  echo "  FAIL kind no es ClusterSecretStore"
  fail=$((fail+1))
fi
if grep -q 'vault:' "$CSS"; then
  echo "  OK   provider.vault presente"
else
  echo "  FAIL provider.vault ausente"
  fail=$((fail+1))
fi
if grep -qE 'auth:[[:space:]]*$' "$CSS" && grep -q 'kubernetes:' "$CSS"; then
  echo "  OK   auth.kubernetes presente"
else
  echo "  FAIL auth.kubernetes ausente"
  fail=$((fail+1))
fi
if grep -q 'TODO' "$CSS"; then
  echo "  FAIL ClusterSecretStore aun tiene TODOs sin rellenar"
  fail=$((fail+1))
else
  echo "  OK   sin TODOs en ClusterSecretStore"
fi

# ExternalSecret kind + secretStoreRef + data no vacio.
if grep -q 'kind:[[:space:]]*ExternalSecret' "$ES"; then
  echo "  OK   kind=ExternalSecret"
else
  echo "  FAIL kind no es ExternalSecret"
  fail=$((fail+1))
fi
if grep -q 'kind:[[:space:]]*ClusterSecretStore' "$ES"; then
  echo "  OK   secretStoreRef.kind=ClusterSecretStore"
else
  echo "  FAIL secretStoreRef.kind != ClusterSecretStore"
  fail=$((fail+1))
fi
if grep -qE 'remoteRef:' "$ES"; then
  echo "  OK   al menos un remoteRef"
else
  echo "  FAIL no hay data[].remoteRef"
  fail=$((fail+1))
fi
if grep -q 'TODO' "$ES"; then
  echo "  FAIL ExternalSecret aun tiene TODOs"
  fail=$((fail+1))
else
  echo "  OK   sin TODOs en ExternalSecret"
fi

# Nadie debe meter kind: Secret con 'data:' plano en el working dir.
if grep -rE '^kind:[[:space:]]*Secret[[:space:]]*$' "$BASE" >/dev/null 2>&1; then
  if grep -rE '^data:' "$BASE" >/dev/null 2>&1; then
    echo "  FAIL hay un kind: Secret con bloque data: en $BASE (debe venir de ESO)"
    fail=$((fail+1))
  else
    echo "  OK   kind: Secret sin data: inline"
  fi
else
  echo "  OK   ningun kind: Secret directo en $BASE"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) fallaron."
  exit 1
fi
echo "OK: estructura valida."
exit 0
