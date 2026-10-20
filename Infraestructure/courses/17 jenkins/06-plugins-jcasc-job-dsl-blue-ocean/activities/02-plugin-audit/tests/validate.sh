#!/usr/bin/env bash
# Structural validation for jk-06-02-plugin-audit.
# Checks that plugins-current.txt and plugins-target.txt exist, that target
# is strictly pinned, is smaller than current, contains required plugins,
# and that plugin-audit.md has the required sections and mentions.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT verify CVE claims against real feeds — manual compare against
# solution/plugin-audit.md.

set -eu

BASE="${1:-/tmp/jk-06-02}"
CUR="$BASE/plugins-current.txt"
TGT="$BASE/plugins-target.txt"
DOC="$BASE/plugin-audit.md"
fail=0

echo "== Structural validation for $BASE =="

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

# ---- plugins-current.txt ----
cur_count=0
if check_file_exists "$CUR"; then
  cur_count=$(grep -cvE '^[[:space:]]*(#|$)' "$CUR" || true)
  if [ "${cur_count:-0}" -ge 1 ]; then
    echo "  OK   plugins-current.txt has ${cur_count} plugin lines"
  else
    echo "  FAIL plugins-current.txt has no plugin lines"
    fail=$((fail+1))
  fi
fi

# ---- plugins-target.txt ----
tgt_count=0
if check_file_exists "$TGT"; then
  tgt_count=$(grep -cvE '^[[:space:]]*(#|$)' "$TGT" || true)
  if [ "${tgt_count:-0}" -ge 5 ]; then
    echo "  OK   plugins-target.txt has ${tgt_count} plugin lines (>=5)"
  else
    echo "  FAIL plugins-target.txt has only ${tgt_count} plugin lines (expected >=5)"
    fail=$((fail+1))
  fi

  # Strict pinning: every line must match name:version, no :latest.
  bad_lines=$(grep -vE '^[[:space:]]*(#|$)' "$TGT" \
              | grep -vE '^[A-Za-z0-9][A-Za-z0-9._-]*:[A-Za-z0-9][A-Za-z0-9._+-]*$' || true)
  latest_lines=$(grep -vE '^[[:space:]]*(#|$)' "$TGT" | grep -E ':latest$' || true)
  if [ -z "$bad_lines" ] && [ -z "$latest_lines" ]; then
    echo "  OK   plugins-target.txt: every line pinned"
  else
    echo "  FAIL plugins-target.txt has unpinned or malformed lines:"
    [ -n "$bad_lines" ]    && printf '       bad: %s\n' $bad_lines
    [ -n "$latest_lines" ] && printf '       latest: %s\n' $latest_lines
    fail=$((fail+1))
  fi

  for req in "configuration-as-code" "job-dsl"; do
    if grep -qE "^${req}:" "$TGT"; then
      echo "  OK   plugins-target.txt includes required '$req'"
    else
      echo "  FAIL plugins-target.txt missing required '$req'"
      fail=$((fail+1))
    fi
  done
fi

# ---- reduction check ----
if [ "${cur_count:-0}" -gt 0 ] && [ "${tgt_count:-0}" -gt 0 ]; then
  if [ "$tgt_count" -lt "$cur_count" ]; then
    echo "  OK   plugins-target.txt (${tgt_count}) < plugins-current.txt (${cur_count}) — audit reduces"
  else
    echo "  FAIL plugins-target.txt (${tgt_count}) is not strictly smaller than plugins-current.txt (${cur_count})"
    fail=$((fail+1))
  fi
fi

# ---- plugin-audit.md ----
if check_file_exists "$DOC"; then
  for section in "Inventario" "Clasificaci[oó]n" "Plan" "Blue Ocean" "CVE"; do
    if grep -qiE "^#+ .*${section}" "$DOC"; then
      echo "  OK   plugin-audit.md has section matching '${section}'"
    else
      echo "  FAIL plugin-audit.md missing section matching '${section}'"
      fail=$((fail+1))
    fi
  done
  if grep -qiE 'pinning|version|pinned' "$DOC"; then
    echo "  OK   plugin-audit.md mentions pinning/version"
  else
    echo "  FAIL plugin-audit.md does not mention pinning/version"
    fail=$((fail+1))
  fi
  if grep -qiE 'cadencia|cadence' "$DOC"; then
    echo "  OK   plugin-audit.md mentions cadencia/cadence"
  else
    echo "  FAIL plugin-audit.md does not mention cadencia/cadence"
    fail=$((fail+1))
  fi
  if grep -qiE 'CloudBees|advisory|security' "$DOC"; then
    echo "  OK   plugin-audit.md mentions CVE source (CloudBees/advisory/security)"
  else
    echo "  FAIL plugin-audit.md does not mention CloudBees/advisory/security"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: plugins-current.txt, plugins-target.txt y plugin-audit.md pasan validacion estructural."
echo "    Compara con solution/ para autoevaluacion semantica."
exit 0
