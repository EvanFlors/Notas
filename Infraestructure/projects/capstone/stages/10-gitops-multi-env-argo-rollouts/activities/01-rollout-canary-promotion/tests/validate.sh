#!/usr/bin/env bash
# Validate manifests of capstone stage 10 (GitOps multi-env + Argo Rollouts).
#
# Usage: bash tests/validate.sh [STAGE_ROOT]
# Default STAGE_ROOT: dos niveles arriba de este script.
#
# Note: deliberately NO `set -o pipefail`. Several checks pipe into `grep -q`
# or `head`, which exit as soon as they find a match and raise SIGPIPE
# (exit 141) in the upstream command. pipefail would flag those as failures.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

passed=0
failed=0
report=""

ok()  { report+="OK   — $1"$'\n'; passed=$((passed+1)); }
bad() { report+="FAIL — $1 — $2"$'\n'; failed=$((failed+1)); }

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 not in PATH (needed for yaml.safe_load checks)." >&2
  exit 1
fi

APPSET="$STAGE_ROOT/argocd/applicationsets/fastapi-app.yaml"
ANALYSIS="$STAGE_ROOT/argocd/analysis-templates/success-rate.yaml"
ROLLOUT="$STAGE_ROOT/rollouts/fastapi-rollout.yaml"
UPDATER="$STAGE_ROOT/argocd/image-updater-config.yaml"

echo "== Validating stage 10 manifests under $STAGE_ROOT =="

# ----- Check 1: all four files exist
missing=""
for f in "$APPSET" "$ANALYSIS" "$ROLLOUT" "$UPDATER"; do
  [ -f "$f" ] || missing+=" ${f#$STAGE_ROOT/}"
done
if [ -z "$missing" ]; then
  ok "all four manifests exist"
else
  bad "manifests missing" "$missing"
fi

# ----- Check 2: every manifest parses cleanly with yaml.safe_load_all
if python3 - "$APPSET" "$ANALYSIS" "$ROLLOUT" "$UPDATER" <<'PY' 2>/tmp/cap10-yaml.err
import sys, yaml
for p in sys.argv[1:]:
    with open(p) as fh:
        list(yaml.safe_load_all(fh))
PY
then
  ok "yaml.safe_load_all parses all four manifests"
else
  bad "yaml parse error" "$(cat /tmp/cap10-yaml.err)"
fi

# ----- Check 3: ApplicationSet lists dev, staging, prod
if python3 - "$APPSET" <<'PY' 2>/dev/null
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert doc["kind"] == "ApplicationSet", doc.get("kind")
elems = doc["spec"]["generators"][0]["list"]["elements"]
envs = sorted(e["env"] for e in elems)
assert envs == ["dev", "prod", "staging"], envs
PY
then
  ok "ApplicationSet generates dev, staging, prod"
else
  bad "ApplicationSet envs wrong" "expected dev/staging/prod in generators[0].list"
fi

# ----- Check 4: Rollout has canary steps 5/25/50/100 + at least one pause{}
if python3 - "$ROLLOUT" <<'PY' 2>/dev/null
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert doc["kind"] == "Rollout", doc.get("kind")
steps = doc["spec"]["strategy"]["canary"]["steps"]
weights = [s["setWeight"] for s in steps if "setWeight" in s]
assert weights == [5, 25, 50, 100], weights
pauses = [s["pause"] for s in steps if "pause" in s]
assert any(p == {} or p is None for p in pauses), "no indefinite pause{}"
PY
then
  ok "Rollout canary steps are 5/25/50/100 with indefinite pause{}"
else
  bad "Rollout canary steps wrong" "expected setWeight 5,25,50,100 + pause{}"
fi

# ----- Check 5: AnalysisTemplate requires success-rate >= 0.95
if python3 - "$ANALYSIS" <<'PY' 2>/dev/null
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert doc["kind"] == "AnalysisTemplate", doc.get("kind")
cond = doc["spec"]["metrics"][0]["successCondition"]
assert ">= 0.95" in cond or ">=0.95" in cond, cond
PY
then
  ok "AnalysisTemplate successCondition demands >= 0.95"
else
  bad "AnalysisTemplate threshold wrong" "successCondition must include '>= 0.95'"
fi

# ----- Check 6: Image Updater config present and references ghcr.io
if python3 - "$UPDATER" <<'PY' 2>/dev/null
import sys, yaml
kinds = [d["kind"] for d in yaml.safe_load_all(open(sys.argv[1])) if d]
assert "ConfigMap" in kinds and "Secret" in kinds, kinds
# ghcr.io must appear somewhere in the raw text (registries.conf block)
raw = open(sys.argv[1]).read()
assert "ghcr.io" in raw
PY
then
  ok "image-updater-config has ConfigMap + Secret and references ghcr.io"
else
  bad "image-updater config incomplete" "needs ConfigMap, Secret, and ghcr.io reference"
fi

# ----- Check 7: no obvious real secrets committed (dummy marker present)
if grep -q "REPLACE_ME_DUMMY" "$UPDATER"; then
  ok "image-updater credentials are marked DUMMY (no real secrets)"
else
  bad "credentials not marked DUMMY" "add REPLACE_ME_DUMMY to credential stringData"
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
