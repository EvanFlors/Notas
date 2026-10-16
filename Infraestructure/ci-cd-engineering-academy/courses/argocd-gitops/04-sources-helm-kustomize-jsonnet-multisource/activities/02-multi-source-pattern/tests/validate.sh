#!/usr/bin/env bash
# Validate argo-04-02-multi-source-pattern — structural checks only.
#
# Note: we deliberately do NOT enable `set -o pipefail`. Several checks pipe
# into `grep -q`, which SIGPIPEs the producer on first match. pipefail would
# wrongly flag those as failures.
set -u

STARTER="$(cd "$(dirname "$0")/../starter" && pwd)"

passed=0
failed=0
skipped=0
report=""

note_pass() { report+="OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="FAIL — $1\n"; failed=$((failed+1)); }
note_skip() { report+="SKIP — $1 ($2)\n"; skipped=$((skipped+1)); }

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not installed."
  exit 0
fi

# Need PyYAML.
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "SKIP: PyYAML not installed. pip install pyyaml"
  exit 0
fi

# All structural checks are implemented in Python for robust YAML handling.
python3 - "$STARTER" <<'PY'
import sys, pathlib, yaml

starter = pathlib.Path(sys.argv[1])
app_path = starter / "application.yaml"
values_path = starter / "values.yaml"

errors = []
oks = []

# 1. application.yaml parses
try:
    docs = list(yaml.safe_load_all(app_path.read_text()))
except Exception as e:
    print(f"FAIL — application.yaml invalid YAML: {e}")
    sys.exit(2)

if len(docs) != 1 or not isinstance(docs[0], dict):
    print("FAIL — application.yaml should contain a single mapping document")
    sys.exit(2)

app = docs[0]
oks.append("application.yaml parses as YAML")

# 2. spec.sources is a list with >= 2 items
sources = app.get("spec", {}).get("sources")
if not isinstance(sources, list):
    errors.append("spec.sources missing or not a list (did you use `source:` singular? multi-source requires `sources:` plural)")
    sources = []
elif len(sources) < 2:
    errors.append(f"spec.sources must have >= 2 entries, found {len(sources)}")
else:
    oks.append(f"spec.sources has {len(sources)} entries")

# 3. exactly one source carries `ref:`
refs = [s for s in sources if isinstance(s, dict) and s.get("ref")]
if len(refs) == 1:
    ref_name = refs[0]["ref"]
    oks.append(f"exactly one source has ref: {ref_name}")
elif len(refs) == 0:
    errors.append("no source has `ref:` — the values repo entry needs ref so other sources can address it")
    ref_name = None
else:
    errors.append(f"more than one source has `ref:` ({len(refs)}) — only one needed as values container")
    ref_name = refs[0].get("ref")

# 4. a valueFiles entry references $<ref_name>/
if ref_name:
    marker = f"${ref_name}/"
    found = False
    for s in sources:
        helm = (s or {}).get("helm") or {}
        for vf in helm.get("valueFiles", []) or []:
            if isinstance(vf, str) and vf.startswith(marker):
                found = True
                break
    if found:
        oks.append(f"valueFiles references the ref ({marker}...)")
    else:
        errors.append(f"no valueFiles entry starts with {marker!r} — the chart source must reference values from the ref'd source")

# 5. targetRevision pinned (not HEAD) for the chart source
for s in sources:
    if isinstance(s, dict) and s.get("chart"):
        rev = str(s.get("targetRevision", "")).strip()
        if not rev or rev.upper() == "HEAD":
            errors.append(f"chart source has non-pinned targetRevision ({rev!r}); use SemVer")
        else:
            oks.append(f"chart targetRevision pinned to {rev}")
        break
else:
    # no chart source at all — fine for Kustomize cases, but this activity requires one
    errors.append("no source with `chart:` found — this activity requires a chart source")

# 6. values.yaml structure
try:
    v = yaml.safe_load(values_path.read_text()) or {}
    if not isinstance(v, dict):
        errors.append("values.yaml must contain a mapping")
    else:
        if "replicaCount" not in v:
            errors.append("values.yaml missing replicaCount")
        else:
            oks.append(f"values.yaml has replicaCount={v['replicaCount']}")
        if "hpa" not in v:
            errors.append("values.yaml missing hpa.enabled")
        else:
            oks.append("values.yaml has hpa section")
except Exception as e:
    errors.append(f"values.yaml invalid: {e}")

for o in oks:
    print(f"OK   — {o}")
for e in errors:
    print(f"FAIL — {e}")

print()
print(f"Summary: {len(oks)} passed, {len(errors)} failed.")
sys.exit(1 if errors else 0)
PY
status=$?

# Preserve exit code; the Python block prints its own summary.
exit $status
