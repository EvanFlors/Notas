#!/usr/bin/env bash
# Validate activity 02: 5 empty queries diagnosed and fixed.
#
# Note: we deliberately do NOT enable `set -o pipefail` because several checks
# use `... | grep -q ...` which can SIGPIPE the upstream and look like a failure.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
FILE="$HERE/../starter/broken-queries.promql"
SCRATCH="$(mktemp -d /tmp/promql-02-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE not found" >&2
  exit 1
fi

passed=0
failed=0
report=""

# Count Query sections.
nsections=$(grep -cE '^# === Query [0-9]+ ===' "$FILE" || true)
if [ "$nsections" -eq 5 ]; then
  report+="Check: 5 secciones Query: OK\n"; passed=$((passed+1))
else
  report+="Check: 5 secciones Query: FAIL (encontradas: $nsections)\n"; failed=$((failed+1))
fi

# Count non-empty Hipótesis lines (not the bare template `# Hipótesis:` with nothing after).
nhip=$(grep -cE '^# Hipótesis:[[:space:]]*\S' "$FILE" || true)
if [ "$nhip" -ge 5 ]; then
  report+="Check: 5 hipótesis llenadas: OK\n"; passed=$((passed+1))
else
  report+="Check: 5 hipótesis llenadas: FAIL (encontradas: $nhip)\n"; failed=$((failed+1))
fi

# Count Fix blocks that have at least one non-comment, non-empty line after `# Fix:`.
nfix=$(python3 - "$FILE" <<'PY'
import sys, pathlib, re
text = pathlib.Path(sys.argv[1]).read_text().splitlines()
count = 0
i = 0
while i < len(text):
    if text[i].strip() == "# Fix:" or text[i].rstrip() == "# Fix:":
        # Look ahead until next '# ===' or EOF for a non-empty, non-comment line.
        j = i + 1
        found = False
        while j < len(text) and not text[j].startswith("# ==="):
            s = text[j].strip()
            if s and not s.startswith("#"):
                found = True
                break
            j += 1
        if found:
            count += 1
    i += 1
print(count)
PY
)
if [ "$nfix" -ge 5 ]; then
  report+="Check: 5 Fix con query: OK\n"; passed=$((passed+1))
else
  report+="Check: 5 Fix con query: FAIL (encontradas: $nfix)\n"; failed=$((failed+1))
fi

# promtool syntax check on just the Fix queries.
if command -v promtool >/dev/null 2>&1; then
  python3 - "$FILE" > "$SCRATCH/rules.yaml" <<'PY'
import sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text().splitlines()
queries = []
i = 0
while i < len(text):
    if text[i].rstrip() == "# Fix:":
        j = i + 1
        buf = []
        while j < len(text) and not text[j].startswith("# ==="):
            s = text[j].rstrip()
            if s and not s.lstrip().startswith("#"):
                buf.append(s)
            elif buf:
                break
            j += 1
        if buf:
            queries.append(" ".join(x.strip() for x in buf))
        i = j
    else:
        i += 1
print("groups:")
print("  - name: fixes")
print("    rules:")
for i, q in enumerate(queries, 1):
    print(f"      - record: fix:q{i}")
    print(f"        expr: {q}")
PY
  if promtool check rules "$SCRATCH/rules.yaml" >"$SCRATCH/pt.log" 2>&1; then
    report+="Check: promtool syntax de los Fix: OK\n"; passed=$((passed+1))
  else
    report+="Check: promtool syntax de los Fix: FAIL\n"
    report+="$(cat "$SCRATCH/pt.log")\n"
    failed=$((failed+1))
  fi
else
  report+="Check: promtool syntax: SKIP (promtool no instalado)\n"
fi

echo
printf "%b" "$report"
echo
echo "RESULT: $passed check(s) OK, $failed FAIL."
[ "$failed" -eq 0 ] || exit 1
exit 0
