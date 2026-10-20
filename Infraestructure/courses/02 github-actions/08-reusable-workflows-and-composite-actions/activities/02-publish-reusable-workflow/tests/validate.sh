#!/usr/bin/env bash
# Validate gha-08-02-publish-reusable-workflow: inspect both repos' YAMLs
# and the git tags of the shared repo.
#
# NOTE: deliberately no `set -o pipefail` because many checks use
# `... | grep -q ...` on long-producing commands (git log, git tag) which
# can produce SIGPIPE (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/publish-reusable}}"

SHARED="$BASE/shared"
CLIENT="$BASE/client"
REUSABLE="$SHARED/.github/workflows/build-and-publish.yml"
CALLER="$CLIENT/.github/workflows/ci.yml"

passed=0
failed=0
report=""
note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating gha-08-02 under $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

for d in "$SHARED" "$CLIENT"; do
  if [ -d "$d/.git" ]; then
    note_ok "repo git existe: $(basename "$d")"
  else
    note_fail "no es un repo git: $d"
  fi
done

if [ ! -f "$REUSABLE" ]; then
  note_fail "no existe $REUSABLE — crea el reusable workflow"
fi
if [ ! -f "$CALLER" ]; then
  note_fail "no existe $CALLER — crea el caller workflow"
fi

if [ ! -f "$REUSABLE" ] || [ ! -f "$CALLER" ]; then
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed/$((passed+failed)) checks OK."
  exit 1
fi

# ---- Check: shared repo has v1 tag ----
v1_tag="$(git --git-dir="$SHARED/.git" tag -l v1 2>/dev/null)"
if [ "$v1_tag" = "v1" ]; then
  note_ok "shared repo tiene tag 'v1'"
else
  note_fail "shared repo NO tiene tag 'v1' (ejecuta: git -C $SHARED tag -a v1 -m 'latest v1')"
fi

# ---- Check: PyYAML available ----
if ! python3 -c 'import yaml' 2>/dev/null; then
  note_fail "python3 con PyYAML requerido. Instala: pip install pyyaml"
  echo; printf "%b" "$report"; echo
  echo "RESULT: $passed/$((passed+failed)) checks OK."
  exit 1
fi

# ---- Structural YAML checks via python ----
py_result="$(python3 - "$REUSABLE" "$CALLER" <<'PY'
import sys, yaml, re

reusable_path, caller_path = sys.argv[1], sys.argv[2]

def load(p):
    with open(p) as f:
        return yaml.safe_load(f)

try:
    r = load(reusable_path)
except Exception as e:
    print(f"FAIL|reusable no parsea como YAML: {e}"); sys.exit(0)
print("OK|reusable workflow parsea como YAML")

try:
    c = load(caller_path)
except Exception as e:
    print(f"FAIL|caller no parsea como YAML: {e}"); sys.exit(0)
print("OK|caller workflow parsea como YAML")

# ---- reusable checks ----
# YAML parses `on` as True (boolean) in some docs; try both keys.
on = r.get("on") if "on" in r else r.get(True)
if isinstance(on, dict) and "workflow_call" in on:
    print("OK|reusable declara on.workflow_call")
    wc = on["workflow_call"] or {}
else:
    print(f"FAIL|reusable no declara on.workflow_call (on = {on!r})")
    wc = {}

inputs = (wc.get("inputs") or {}) if isinstance(wc, dict) else {}
typed = [(n, (v or {}).get("type")) for n, v in inputs.items()]
if len(typed) >= 2:
    print(f"OK|reusable declara {len(typed)} inputs (>=2)")
else:
    print(f"FAIL|reusable debe declarar >=2 inputs tipados (tiene {len(typed)})")

types_present = {t for _, t in typed}
if "string" in types_present:
    print("OK|al menos un input es type: string")
else:
    print(f"FAIL|al menos un input debe ser type: string (tipos vistos: {types_present})")
if "boolean" in types_present:
    print("OK|al menos un input es type: boolean")
else:
    print(f"FAIL|al menos un input debe ser type: boolean (tipos vistos: {types_present})")

secrets = (wc.get("secrets") or {}) if isinstance(wc, dict) else {}
rt = secrets.get("REGISTRY_TOKEN") or {}
if rt and rt.get("required") is True:
    print("OK|reusable declara secret REGISTRY_TOKEN con required: true")
else:
    print(f"FAIL|reusable debe declarar secret REGISTRY_TOKEN con required: true (visto: {rt!r})")

outputs = (wc.get("outputs") or {}) if isinstance(wc, dict) else {}
digest = outputs.get("digest") or {}
dval = str(digest.get("value", ""))
if re.search(r"\$\{\{\s*jobs\.\w+\.outputs\.\w+\s*\}\}", dval):
    print("OK|reusable propaga output digest desde jobs.<j>.outputs.*")
else:
    print(f"FAIL|output digest.value debe referenciar '${{{{ jobs.<j>.outputs.<k> }}}}' (visto: {dval!r})")

# Verify the referenced job has that output and comes from a step
m = re.search(r"jobs\.(\w+)\.outputs\.(\w+)", dval)
if m:
    jname, okey = m.group(1), m.group(2)
    jobs = r.get("jobs") or {}
    j = jobs.get(jname) or {}
    jouts = j.get("outputs") or {}
    jval = str(jouts.get(okey, ""))
    if re.search(r"\$\{\{\s*steps\.\w+\.outputs\.\w+\s*\}\}", jval):
        print(f"OK|jobs.{jname}.outputs.{okey} propaga desde steps.<s>.outputs.*")
    else:
        print(f"FAIL|jobs.{jname}.outputs.{okey} debe propagar desde steps.<s>.outputs.* (visto: {jval!r})")

# ---- caller checks ----
cjobs = c.get("jobs") or {}
call_job = None
for jn, jv in cjobs.items():
    if not isinstance(jv, dict):
        continue
    u = str(jv.get("uses", ""))
    if re.match(r"^[\w.-]+/[\w.-]+/\.github/workflows/[\w.-]+\.yml@[\w.-]+$", u):
        call_job = (jn, jv, u)
        break

if call_job:
    jn, jv, u = call_job
    print(f"OK|caller tiene job '{jn}' con uses: {u}")
    if u.endswith("/.github/workflows/build-and-publish.yml@v1"):
        print("OK|uses: apunta a build-and-publish.yml@v1")
    else:
        print(f"FAIL|uses: debe terminar en '/.github/workflows/build-and-publish.yml@v1' (visto: {u})")

    secs = jv.get("secrets")
    if isinstance(secs, dict) and "REGISTRY_TOKEN" in secs:
        print("OK|caller pasa REGISTRY_TOKEN explicitamente")
        val = str(secs["REGISTRY_TOKEN"])
        if "secrets." in val:
            print("OK|REGISTRY_TOKEN se asigna desde ${{ secrets.* }}")
        else:
            print(f"FAIL|REGISTRY_TOKEN debe venir de ${{{{ secrets.* }}}} (visto: {val!r})")
    elif secs == "inherit":
        print("FAIL|caller usa secrets: inherit — esta actividad requiere paso explicito")
    else:
        print(f"FAIL|caller no pasa secret REGISTRY_TOKEN (visto: {secs!r})")

    # downstream job with needs: and reads outputs.digest
    found_announce = False
    for jn2, jv2 in cjobs.items():
        if not isinstance(jv2, dict):
            continue
        needs = jv2.get("needs")
        if needs == jn or (isinstance(needs, list) and jn in needs):
            # look for ${{ needs.<jn>.outputs.digest }} inside its steps
            steps = jv2.get("steps") or []
            blob = yaml.safe_dump(steps)
            if re.search(rf"needs\.{jn}\.outputs\.digest", blob):
                found_announce = True
                print(f"OK|job '{jn2}' hace needs: {jn} y lee outputs.digest")
                break
    if not found_announce:
        print(f"FAIL|falta un job con 'needs: {jn}' que lea needs.{jn}.outputs.digest")
else:
    print("FAIL|caller no tiene ningun job con uses: owner/repo/.github/workflows/*.yml@ref")
PY
)"

while IFS= read -r line; do
  case "$line" in
    OK\|*)   note_ok   "${line#OK|}" ;;
    FAIL\|*) note_fail "${line#FAIL|}" ;;
  esac
done <<< "$py_result"

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT: $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
