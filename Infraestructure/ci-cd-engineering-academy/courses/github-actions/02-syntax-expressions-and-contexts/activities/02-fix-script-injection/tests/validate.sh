#!/usr/bin/env bash
# Validate gha-02-02-fix-script-injection in MODE=local.
#
# NOTE: deliberately no `set -o pipefail` because many checks use
# `... | grep -q ...` on long-producing commands which can produce SIGPIPE
# (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/gha-02-02}}"
MODE="${MODE:-local}"

WF="$BASE/local/.github/workflows/greet.yml"
EXP="$BASE/local/EXPLANATION.md"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating gha-02-02 ($MODE) under $BASE =="

if [ ! -f "$WF" ]; then
  echo "FAIL: workflow not found at $WF. Run starter/bootstrap.sh first." >&2
  exit 1
fi

# ---- Check 1: YAML valid ----
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$WF" 2>/dev/null; then
    note_ok "greet.yml es YAML válido"
  else
    note_fail "greet.yml no es YAML válido"
  fi
fi

# ---- Check 2: detector grep — no unsafe interpolation inside any `run:` block ----
# Extract run: blocks and search for unsafe context expansions.
# We flag these token patterns: title|body|head\.ref|head\.label|comment\.body|message|author\.(name|email)|description|head_branch
unsafe_hits="$(python3 - "$WF" <<'PY'
import sys, re, yaml
path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f)

bad_pattern = re.compile(
    r"\$\{\{\s*github\.event\.[^}]*?"
    r"(title|body|head\.ref|head\.label|comment\.body|message|author\.name|author\.email|description|head_branch)"
    r"[^}]*\}\}"
)

hits = []

def walk(node, path_desc=""):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "run" and isinstance(v, str):
                for m in bad_pattern.finditer(v):
                    hits.append(f"{path_desc}: {m.group(0)}")
            else:
                walk(v, f"{path_desc}.{k}")
    elif isinstance(node, list):
        for i, item in enumerate(node):
            walk(item, f"{path_desc}[{i}]")

walk(data)
for h in hits:
    print(h)
PY
)"

if [ -z "$unsafe_hits" ]; then
  note_ok "detector: no quedan interpolaciones peligrosas dentro de 'run:'"
else
  note_fail "detector: aún hay interpolaciones peligrosas dentro de 'run:':"
  while IFS= read -r line; do
    report+="         · $line\n"
  done <<< "$unsafe_hits"
fi

# ---- Check 3: at least one env: with an untrusted github.event source ----
if grep -Pzoq '(?s)env:\s*[^\n]*\n\s*[A-Z_]+:\s*\$\{\{\s*github\.event\.pull_request' "$WF" 2>/dev/null \
   || python3 - "$WF" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
hits = 0
def walk(n):
    global hits
    if isinstance(n, dict):
        env = n.get("env") if "env" in n else None
        if isinstance(env, dict):
            for k, v in env.items():
                if isinstance(v, str) and "github.event.pull_request" in v:
                    hits += 1
        for v in n.values():
            walk(v)
    elif isinstance(n, list):
        for i in n: walk(i)
walk(data)
sys.exit(0 if hits >= 1 else 1)
PY
then
  note_ok "al menos un env: deriva de github.event.pull_request.*"
else
  note_fail "ningún env: deriva de github.event.pull_request.* (¿moviste los valores?)"
fi

# ---- Check 4: preserved structure — step ids still present ----
missing=""
for id in hello show_branch body meta; do
  if ! grep -q "id: $id" "$WF"; then
    missing="$missing $id"
  fi
done
if [ -z "$missing" ]; then
  note_ok "los 4 ids de step originales se preservaron (hello, show_branch, body, meta)"
else
  note_fail "faltan step ids originales:$missing"
fi

# ---- Check 5: EXPLANATION.md present and non-trivial ----
if [ -f "$EXP" ]; then
  nonblank="$(grep -cvE '^[[:space:]]*$' "$EXP" || true)"
  if [ "${nonblank:-0}" -ge 20 ]; then
    note_ok "EXPLANATION.md presente con $nonblank líneas no vacías (>=20)"
  else
    note_fail "EXPLANATION.md tiene solo ${nonblank:-0} líneas no vacías (<20)"
  fi
else
  note_fail "EXPLANATION.md no existe en $EXP"
fi

# ---- Check 6: actionlint if available ----
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" >/tmp/actionlint-02.out 2>&1; then
    note_ok "actionlint sin errores"
  else
    note_fail "actionlint reportó errores (ver /tmp/actionlint-02.out)"
  fi
else
  note_ok "actionlint no instalado — skip (opcional)"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT ($MODE): $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
