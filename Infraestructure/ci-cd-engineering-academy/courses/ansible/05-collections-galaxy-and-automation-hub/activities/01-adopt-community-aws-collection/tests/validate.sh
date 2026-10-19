#!/usr/bin/env bash
# Structural validation for ans-05-01-adopt-community-aws-collection.
#
# Checks:
#   - directory layout of the lab,
#   - collections/requirements.yml is valid YAML and declares >=3 external
#     collections with name+version+source,
#   - mycorp/platform/galaxy.yml is valid YAML and has the mandatory fields
#     Galaxy / Automation Hub require,
#   - meta/runtime.yml declares requires_ansible,
#   - repo README.md has the 3 sections documented in instructions,
#   - OPTIONAL: if ansible-galaxy is available AND network reachable, run
#     `ansible-galaxy collection install -r ...` and list the installed set.
#     Skipped (not failed) when offline or when ansible-galaxy is absent.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness (e.g. that the pins are "wise") —
# compare manually with solution/.

set -eu

BASE="${1:-/tmp/ans-05-01}"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_dir_exists() {
  local d="$1"
  if [ -d "$d" ]; then
    echo "  OK   $d/ exists"
    return 0
  else
    echo "  FAIL $d/ does not exist"
    fail=$((fail+1))
    return 1
  fi
}

yaml_load() {
  local f="$1"
  python3 - "$f" <<'PY'
import sys, json
try:
    import yaml  # type: ignore
except ImportError:
    # Fallback: minimal JSON-compatible load not possible; print marker.
    print("__NO_YAML__")
    sys.exit(0)
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
print(json.dumps(data, default=str))
PY
}

py_check() {
  # Takes a python expression that must print "OK <label>" or "FAIL <label>".
  python3 - "$@"
}

# --- Layout -------------------------------------------------------------
check_dir_exists "$BASE/collections" || true
check_dir_exists "$BASE/mycorp/platform" || true
check_dir_exists "$BASE/mycorp/platform/plugins/modules" || true
check_dir_exists "$BASE/mycorp/platform/meta" || true
check_dir_exists "$BASE/mycorp/platform/roles" || true
check_dir_exists "$BASE/mycorp/platform/playbooks" || true

# --- collections/requirements.yml --------------------------------------
REQ="$BASE/collections/requirements.yml"
if check_file_exists "$REQ"; then
  parsed=$(yaml_load "$REQ" 2>/dev/null || echo "")
  if [ "$parsed" = "__NO_YAML__" ]; then
    echo "  WARN python3 lacks PyYAML; falling back to grep-based checks for $REQ"
    if grep -qE '^\s*-\s+name:\s*amazon\.aws' "$REQ"; then
      echo "  OK   $REQ declares amazon.aws"
    else
      echo "  FAIL $REQ does not declare amazon.aws"
      fail=$((fail+1))
    fi
    coll_count=$(grep -cE '^\s*-\s+name:\s+' "$REQ" || true)
    if [ "$coll_count" -ge 3 ]; then
      echo "  OK   $REQ declares >=3 collections ($coll_count found)"
    else
      echo "  FAIL $REQ declares only $coll_count collections (expected >=3)"
      fail=$((fail+1))
    fi
  elif [ -z "$parsed" ]; then
    echo "  FAIL $REQ is not valid YAML"
    fail=$((fail+1))
  else
    result=$(python3 - "$parsed" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
errs = []
if not isinstance(data, dict) or "collections" not in data:
    print("FAIL requirements.yml must be a mapping with 'collections' key")
    sys.exit(0)
colls = data["collections"]
if not isinstance(colls, list):
    print("FAIL requirements.yml 'collections' must be a list")
    sys.exit(0)
if len(colls) < 3:
    errs.append(f"FAIL requirements.yml declares only {len(colls)} collections (expected >=3)")
names = []
for i, c in enumerate(colls):
    if not isinstance(c, dict):
        errs.append(f"FAIL collection #{i} is not a mapping")
        continue
    for k in ("name", "version", "source"):
        if k not in c or not str(c.get(k, "")).strip():
            errs.append(f"FAIL collection #{i} (name={c.get('name','?')}) missing or empty '{k}'")
    names.append(str(c.get("name", "")))
if errs:
    for e in errs:
        print(e)
else:
    print(f"OK   requirements.yml valid YAML, {len(colls)} collections with name+version+source")
    print(f"OK   collections present: {', '.join(names)}")
PY
)
    while IFS= read -r line; do
      echo "  $line"
      if printf '%s' "$line" | grep -q '^FAIL'; then
        fail=$((fail+1))
      fi
    done <<<"$result"
  fi
fi

# --- mycorp/platform/galaxy.yml ----------------------------------------
GAL="$BASE/mycorp/platform/galaxy.yml"
if check_file_exists "$GAL"; then
  parsed=$(yaml_load "$GAL" 2>/dev/null || echo "")
  if [ "$parsed" = "__NO_YAML__" ]; then
    echo "  WARN python3 lacks PyYAML; falling back to grep-based checks for $GAL"
    for k in namespace name version readme authors description license tags dependencies repository issues; do
      if grep -qE "^${k}:" "$GAL"; then
        echo "  OK   $GAL has '${k}'"
      else
        echo "  FAIL $GAL missing '${k}'"
        fail=$((fail+1))
      fi
    done
  elif [ -z "$parsed" ]; then
    echo "  FAIL $GAL is not valid YAML"
    fail=$((fail+1))
  else
    result=$(python3 - "$parsed" <<'PY'
import json, sys, re
data = json.loads(sys.argv[1])
if not isinstance(data, dict):
    print("FAIL galaxy.yml must be a top-level mapping")
    sys.exit(0)
required = {
    "namespace": lambda v: isinstance(v, str) and bool(v.strip()),
    "name": lambda v: isinstance(v, str) and bool(v.strip()),
    "version": lambda v: isinstance(v, str) and bool(re.match(r"^\d+\.\d+\.\d+", v.strip())),
    "readme": lambda v: isinstance(v, str) and bool(v.strip()),
    "authors": lambda v: isinstance(v, list) and len(v) >= 1,
    "description": lambda v: isinstance(v, str) and bool(v.strip()),
    "license": lambda v: isinstance(v, list) and len(v) >= 1,
    "tags": lambda v: isinstance(v, list) and len(v) >= 2,
    "dependencies": lambda v: isinstance(v, dict),
    "repository": lambda v: isinstance(v, str) and v.strip().startswith(("http://", "https://")),
    "issues": lambda v: isinstance(v, str) and v.strip().startswith(("http://", "https://")),
}
for k, pred in required.items():
    if k not in data:
        print(f"FAIL galaxy.yml missing field '{k}'")
    elif not pred(data[k]):
        print(f"FAIL galaxy.yml field '{k}' invalid value: {data[k]!r}")
    else:
        print(f"OK   galaxy.yml field '{k}' present and valid")
PY
)
    while IFS= read -r line; do
      echo "  $line"
      if printf '%s' "$line" | grep -q '^FAIL'; then
        fail=$((fail+1))
      fi
    done <<<"$result"
  fi
fi

# --- mycorp/platform/meta/runtime.yml ----------------------------------
RT="$BASE/mycorp/platform/meta/runtime.yml"
if check_file_exists "$RT"; then
  if grep -qE '^requires_ansible:' "$RT"; then
    echo "  OK   runtime.yml declares requires_ansible"
  else
    echo "  FAIL runtime.yml missing requires_ansible"
    fail=$((fail+1))
  fi
fi

# --- repo README.md ----------------------------------------------------
DOC="$BASE/README.md"
if check_file_exists "$DOC"; then
  for section in "Collections externas" "Collection propia mycorp.platform" "Instalaci"; do
    if grep -qE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README.md has section '${section}'"
    else
      echo "  FAIL README.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
fi

# --- optional: ansible-galaxy install -----------------------------------
echo
echo "== Optional: ansible-galaxy install (only if tool + network available) =="
if ! command -v ansible-galaxy >/dev/null 2>&1; then
  echo "  SKIP ansible-galaxy not installed"
elif ! curl -sfI --max-time 3 https://galaxy.ansible.com/ >/dev/null 2>&1; then
  echo "  SKIP galaxy.ansible.com unreachable (offline mode)"
else
  tmpdir=$(mktemp -d)
  if ansible-galaxy collection install -r "$REQ" -p "$tmpdir" --force >/dev/null 2>&1; then
    echo "  OK   ansible-galaxy collection install succeeded"
    list_out=$(ansible-galaxy collection list -p "$tmpdir" 2>/dev/null || true)
    for coll in amazon.aws community.general ansible.posix; do
      if printf '%s\n' "$list_out" | grep -q "$coll"; then
        echo "  OK   installed $coll"
      else
        echo "  WARN $coll not found in installed set"
      fi
    done
  else
    echo "  WARN ansible-galaxy install failed (network? bad pin?). Not failing the structural validator."
  fi
  rm -rf "$tmpdir"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/.)"
  exit 1
fi
echo "OK: estructura y manifiestos pasan validacion."
echo "    Compara con solution/ para autoevaluacion."
exit 0
