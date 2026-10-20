#!/usr/bin/env bash
# Structural validation for dkr-01-02-oci-manifest-reading.
# Checks that manifest.json AND WRITEUP.md exist, and that WRITEUP.md
# references the right fields, cites at least one sha256 hash and answers
# the 4 reflection questions.
#
# Note: we deliberately do NOT enable `set -o pipefail` because some checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/WRITEUP-reference.md.

BASE="${1:-/tmp/dkr-01-manifest}"
MANIFEST="$BASE/manifest.json"
WRITEUP="$BASE/WRITEUP.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: $MANIFEST does not exist. Copy starter/sample-manifest.json or run docker manifest inspect first."
  exit 1
fi

# manifest.json must be valid JSON.
if python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
  echo "  OK   manifest.json is valid JSON"
else
  echo "  FAIL manifest.json is not valid JSON"
  fail=$((fail+1))
fi

if [ ! -f "$WRITEUP" ]; then
  echo "FAIL: $WRITEUP does not exist. Student must produce it."
  exit 1
fi

# Required keywords in the WRITEUP.
required_terms=(
  "schemaVersion"
  "mediaType"
  "digest"
  "size"
  "layers"
)
for t in "${required_terms[@]}"; do
  if grep -qi "$t" "$WRITEUP"; then
    echo "  OK   WRITEUP.md mentions '$t'"
  else
    echo "  FAIL WRITEUP.md does not mention '$t'"
    fail=$((fail+1))
  fi
done

# Must mention manifest type (either "manifest" or "index").
if grep -qiE 'manifest|index' "$WRITEUP"; then
  echo "  OK   WRITEUP.md identifies the manifest/index type"
else
  echo "  FAIL WRITEUP.md does not say whether it is a manifest or an index"
  fail=$((fail+1))
fi

# Must contain at least one sha256 hash reference.
if grep -Eq 'sha256:[0-9a-f]{8,}' "$WRITEUP"; then
  echo "  OK   WRITEUP.md cites at least one sha256 digest"
else
  echo "  FAIL WRITEUP.md does not cite any sha256:<hex> digest"
  fail=$((fail+1))
fi

# Must mention diff_ids or distinguish compressed vs uncompressed.
if grep -qiE 'diff_ids|descomprim|uncompressed|comprimid' "$WRITEUP"; then
  echo "  OK   WRITEUP.md distinguishes compressed vs uncompressed (diff_ids)"
else
  echo "  FAIL WRITEUP.md does not distinguish compressed layer digest vs diff_ids"
  fail=$((fail+1))
fi

# 4 numbered answers in section D.
answers_found=0
for n in 1 2 3 4; do
  if grep -Eq "^(##? )?${n}\\." "$WRITEUP"; then
    answers_found=$((answers_found+1))
  fi
done
if [ "$answers_found" -ge 4 ]; then
  echo "  OK   WRITEUP.md answers at least 4 numbered questions"
else
  echo "  FAIL WRITEUP.md has $answers_found numbered answers (expected >=4)"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/WRITEUP-reference.md.)"
  exit 1
fi
echo "OK: estructura válida. Compara WRITEUP.md con solution/WRITEUP-reference.md para autoevaluarte."
exit 0
