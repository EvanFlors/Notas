#!/usr/bin/env bash
# Validate structural presence of the deliverables for dkr-11-02-base-image-adr.
# This is a MIXED validation: structure is automated, content quality is manual.
#
# NOTE: deliberately NO `set -o pipefail`. Several checks pipe file contents
# into `grep -q`; pipefail would misreport SIGPIPE as failure.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/dkr-11-adr}}"

passed=0
failed=0
report=""

note_ok()   { report+="  OK   -- $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL -- $1\n"; failed=$((failed+1)); }

echo "== Validating dkr-11-02-base-image-adr =="
echo "   BASE=$BASE"

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Run starter/bootstrap.sh first." >&2
  exit 1
fi

ADR="$BASE/ADR-0001-base-image.md"
MEAS="$BASE/measurements.md"

if [ -f "$ADR" ]; then
  note_ok "ADR file exists at $ADR"
  for section in "## Status" "## Context" "## Decision" "## Options considered" "## Consequences"; do
    if grep -qF "$section" "$ADR"; then
      note_ok "ADR has section '$section'"
    else
      note_fail "ADR missing section '$section'"
    fi
  done
else
  note_fail "ADR file missing at $ADR"
fi

if [ -f "$MEAS" ]; then
  note_ok "measurements.md exists"
  # Expect a markdown table with at least a header row and 3 data rows.
  rows="$(grep -cE '^\|' "$MEAS" || true)"
  if [ "${rows:-0}" -ge 5 ]; then
    note_ok "measurements.md has >= 5 table lines (header + separator + 3 rows)"
  else
    note_fail "measurements.md has only ${rows:-0} table lines (need header + sep + >=3 rows)"
  fi
  # Expect the three base families to appear by name.
  for kw in slim alpine distroless; do
    if grep -qi "$kw" "$MEAS"; then
      note_ok "measurements.md mentions '$kw'"
    else
      note_fail "measurements.md does not mention '$kw'"
    fi
  done
else
  note_fail "measurements.md missing at $MEAS"
fi

printf "\n%b\n" "$report"
echo "RESULT: $passed passed, $failed failed."
echo "NOTE: quality of the ADR argument requires human review."
[ "$failed" -eq 0 ]
