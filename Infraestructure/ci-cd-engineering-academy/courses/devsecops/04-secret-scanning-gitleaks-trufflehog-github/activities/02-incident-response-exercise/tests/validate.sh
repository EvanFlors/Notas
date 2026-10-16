#!/usr/bin/env bash
# Structural validation for sec-04-02-incident-response-exercise.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/sec-04-incident}}"
DOC="$BASE/RESPONSE.md"
fail=0

echo "== Validating sec-04-02 incident response under $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Produce it following README.md."
  exit 1
fi

# ---------- Six sections A..F ----------
for sec in "A" "B" "C" "D" "E" "F"; do
  if grep -qiE "^#+ *(Secci[oó]n +${sec}\b|${sec}[\.\)] )" "$DOC"; then
    echo "  OK   RESPONSE.md has Section ${sec}"
  else
    echo "  FAIL RESPONSE.md missing Section ${sec}"
    fail=$((fail+1))
  fi
done

# ---------- Mandatory keywords ----------
for kw in "rotar" "post-mortem" "blast radius"; do
  if grep -qi "$kw" "$DOC"; then
    echo "  OK   mentions '$kw'"
  else
    echo "  FAIL does not mention '$kw'"
    fail=$((fail+1))
  fi
done

if grep -qiE "filter-repo|bfg" "$DOC"; then
  echo "  OK   mentions filter-repo or BFG"
else
  echo "  FAIL does not mention filter-repo nor BFG"
  fail=$((fail+1))
fi

if grep -qiE "force[- ]push" "$DOC"; then
  echo "  OK   mentions force-push"
else
  echo "  FAIL does not mention force-push"
  fail=$((fail+1))
fi

# ---------- Preventive controls: at least one of a known list ----------
preventive=0
for p in "push protection" "pre-commit" "trufflehog" "vault" "sops" "external secrets" "secret manager"; do
  if grep -qi "$p" "$DOC"; then
    preventive=$((preventive+1))
  fi
done
if [ "$preventive" -ge 2 ]; then
  echo "  OK   RESPONSE.md names at least 2 preventive controls ($preventive found)"
else
  echo "  FAIL RESPONSE.md names only $preventive preventive controls (expected >=2)"
  fail=$((fail+1))
fi

# ---------- Anti-patterns: must call out at least two ----------
antip=0
for a in "git rm" "amend" "borrar el repo"; do
  if grep -qi "$a" "$DOC"; then
    antip=$((antip+1))
  fi
done
if [ "$antip" -ge 2 ]; then
  echo "  OK   RESPONSE.md calls out at least 2 anti-patterns ($antip found)"
else
  echo "  FAIL RESPONSE.md calls out only $antip anti-patterns (expected >=2)"
  fail=$((fail+1))
fi

# ---------- Order check: 'rotar' before 'filter-repo'/'bfg' ----------
rotate_line=$(grep -niE "rotar" "$DOC" | head -n1 | cut -d: -f1 || true)
rewrite_line=$(grep -niE "filter-repo|bfg" "$DOC" | head -n1 | cut -d: -f1 || true)
if [ -n "$rotate_line" ] && [ -n "$rewrite_line" ] && [ "$rotate_line" -lt "$rewrite_line" ]; then
  echo "  OK   'rotar' appears BEFORE 'filter-repo'/'bfg' (correct order)"
else
  echo "  FAIL order wrong: 'rotar' must appear before 'filter-repo'/'bfg'"
  fail=$((fail+1))
fi

# ---------- Must NOT contain anything that looks like a real credential ----------
# Safety net: this exercise is pure prose; students should NOT paste real values.
# We flag strings that match canonical real-key prefixes without 'fake'/'FAKE'/'demo'.
if grep -nE "sk_live_[A-Za-z0-9]{20,}" "$DOC" | grep -viE "fake|demo|example|placeholder" >/dev/null 2>&1; then
  echo "  FAIL RESPONSE.md may contain a value matching sk_live_* without fake/demo markers — review"
  fail=$((fail+1))
else
  echo "  OK   no suspicious real-looking credentials detected"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
