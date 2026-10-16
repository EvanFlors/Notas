#!/usr/bin/env bash
# Structural validation for argo-06-02.
# Checks that the student produced AUDIT.md, proposed/*.yaml and the ADR with
# all required sections. Does NOT grade semantic correctness.
#
# pipefail intentionally OFF — many checks use `grep -q` on piped output.
set -eu

BASE="${1:-/tmp/argo-06-02}"
AUDIT="$BASE/AUDIT.md"
ADR="$BASE/ADR-001-least-privilege-projects.md"
PROPOSED="$BASE/proposed"
fail=0

ok()  { echo "  OK   $*"; }
bad() { echo "  FAIL $*"; fail=$((fail+1)); }

echo "== Structural validation for $BASE =="

[ -d "$BASE" ] || { echo "FAIL: working dir $BASE does not exist. Copy starter/ first."; exit 1; }

# 1. AUDIT.md
if [ -f "$AUDIT" ]; then
  ok "AUDIT.md present"
  for section in "platform-monitoring" "payments-api" "payments-worker" "checkout-ui"; do
    if grep -q "$section" "$AUDIT"; then
      ok "AUDIT.md mentions '$section'"
    else
      bad "AUDIT.md does not mention '$section'"
    fi
  done
else
  bad "AUDIT.md missing at $AUDIT"
fi

# 2. proposed/
if [ -d "$PROPOSED" ]; then
  ok "proposed/ directory exists"
  count=$(find "$PROPOSED" -maxdepth 1 -name '*.yaml' -type f | wc -l | tr -d ' ')
  if [ "$count" -ge 2 ]; then
    ok "proposed/ has $count YAML file(s) (>=2)"
  else
    bad "proposed/ has only $count YAML file(s); need at least 2 AppProjects (or justify a single-project proposal in the ADR)"
  fi

  # No wildcards in sourceRepos or destinations. We intentionally allow
  # 'kind: '*'' inside *ResourceWhitelist — that's a legitimate per-group
  # wildcard, not a tenancy boundary breach.
  wildcard_hits=""
  for f in "$PROPOSED"/*.yaml; do
    [ -f "$f" ] || continue
    # State machine: enter block on sourceRepos:/destinations:, leave on next
    # same-or-outer-indent key. Flag any '*' inside list items / scalar values.
    if awk '
      function key_indent(line,   i) {
        for (i=1; i<=length(line); i++) if (substr(line,i,1) != " ") return i-1
        return -1
      }
      {
        line = $0
        sub(/#.*$/, "", line)                   # strip comments
      }
      /^[[:space:]]*sourceRepos:[[:space:]]*$/ { block="sr"; indent=key_indent($0); next }
      /^[[:space:]]*destinations:[[:space:]]*$/ { block="de"; indent=key_indent($0); next }
      # Leave block when a new sibling-or-outer key appears
      block != "" && line ~ /^[[:space:]]*[A-Za-z][A-Za-z0-9_]*:/ {
        if (key_indent(line) <= indent) { block=""; next }
      }
      # Flag ONLY a bare "*" as a whole value (optionally quoted). Allows
      # legitimate globs like "payments-*" or "checkout-*".
      block != "" && line ~ /:[[:space:]]*["\x27]?\*["\x27]?[[:space:]]*$/ {
        found=1; exit
      }
      block != "" && line ~ /^[[:space:]]*-[[:space:]]+["\x27]?\*["\x27]?[[:space:]]*$/ {
        found=1; exit
      }
      END { exit(found ? 1 : 0) }
    ' "$f"; then
      :
    else
      wildcard_hits="$wildcard_hits $f"
    fi
  done
  if [ -n "$wildcard_hits" ]; then
    bad "proposed/ files have wildcards in sourceRepos/destinations:$wildcard_hits"
  else
    ok "proposed/ files have no wildcards in sourceRepos/destinations"
  fi

  # Each proposed file must be an AppProject.
  for f in "$PROPOSED"/*.yaml; do
    [ -f "$f" ] || continue
    if grep -q 'kind: AppProject' "$f"; then
      ok "$(basename "$f"): kind: AppProject"
    else
      bad "$(basename "$f"): missing 'kind: AppProject'"
    fi
  done
else
  bad "proposed/ directory missing at $PROPOSED"
fi

# 3. ADR
if [ -f "$ADR" ]; then
  ok "ADR file present"
  for section in "Status" "Context" "Decision" "Consequences" "Alternatives" "Migration"; do
    if grep -qi "^#.*${section}" "$ADR"; then
      ok "ADR contains section: $section"
    else
      bad "ADR missing section: $section"
    fi
  done

  # Migration plan must address token revocation (English 'revoke' or Spanish 'revocar').
  if grep -qiE "revok|revoc" "$ADR"; then
    ok "ADR mentions token revocation"
  else
    bad "ADR does not mention 'revoke'/'revocar' — migration plan must address the legacy JWT"
  fi
else
  bad "ADR missing at $ADR"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/ADR-reference.md.)"
  exit 1
fi
echo "OK: structural validation passed. Self-grade against solution/ADR-reference.md."
exit 0
