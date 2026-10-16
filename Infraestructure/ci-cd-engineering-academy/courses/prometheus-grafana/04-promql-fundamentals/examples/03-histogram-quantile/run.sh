#!/usr/bin/env bash
# Validate histogram_quantile queries. Same tri-mode strategy.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
QUERIES="$HERE/queries.promql"
PROM_URL="${PROM_URL:-http://localhost:9090}"

if command -v curl >/dev/null 2>&1 \
   && curl -sS -m 2 "$PROM_URL/-/ready" >/dev/null 2>&1; then
  echo "== Querying $PROM_URL =="
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue;; esac
    printf -- '--- %s\n' "$line"
    curl -sS -G --data-urlencode "query=$line" "$PROM_URL/api/v1/query" | head -c 400
    echo
  done < "$QUERIES"
  exit 0
fi

if command -v promtool >/dev/null 2>&1; then
  echo "== promtool syntax check =="
  TMP="$(mktemp -d /tmp/promql-ex03.XXXXXX)"
  trap 'rm -rf "$TMP"' EXIT
  # queries here may be multi-line (histogram_quantile(...)); emit each non-comment
  # non-blank line as part of the current record's expr. We simplify by joining
  # physical lines until the next blank line.
  python3 - "$QUERIES" > "$TMP/rules.yaml" <<'PY'
import sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text().splitlines()
groups = []
buf = []
for ln in text + [""]:
    s = ln.rstrip()
    if not s or s.lstrip().startswith("#"):
        if buf:
            groups.append(" ".join(x.strip() for x in buf))
            buf = []
        continue
    buf.append(s)
print("groups:")
print("  - name: demo")
print("    rules:")
for i, q in enumerate(groups, 1):
    print(f"      - record: demo:q{i}")
    print(f"        expr: {q}")
PY
  promtool check rules "$TMP/rules.yaml"
  exit 0
fi

echo "SKIP: no Prometheus server at $PROM_URL and no promtool available."
exit 0
