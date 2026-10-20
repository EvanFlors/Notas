#!/usr/bin/env bash
# Structural validation for sec-08-01-publish-sbom-and-provenance-for-capstone.
# Checks that the expected files exist in the scratch dir, are JSON-ish or
# YAML-ish, and contain the key markers of the exercise.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which produces SIGPIPE (exit 141) when grep finds
# a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.
set -eu

BASE="${1:-/tmp/sec-08-capstone}"
fail=0

echo "== Structural validation for ${BASE} =="

if [ ! -d "${BASE}" ]; then
  echo "FAIL: ${BASE} does not exist. Did you run the activity?"
  exit 1
fi

# --- SBOM files -----------------------------------------------------------
if [ -f "${BASE}/sbom.cdx.json" ]; then
  if grep -qi 'cyclonedx\|"bomFormat"\|"components"' "${BASE}/sbom.cdx.json"; then
    echo "  OK   sbom.cdx.json exists and looks like CycloneDX"
  else
    echo "  FAIL sbom.cdx.json exists but no CycloneDX markers found"
    fail=$((fail+1))
  fi
else
  echo "  FAIL sbom.cdx.json missing (syft dir:. -o cyclonedx-json=sbom.cdx.json)"
  fail=$((fail+1))
fi

if [ -f "${BASE}/sbom.spdx.json" ]; then
  if grep -qi 'spdx\|SPDXID\|spdxVersion' "${BASE}/sbom.spdx.json"; then
    echo "  OK   sbom.spdx.json exists and looks like SPDX"
  else
    echo "  FAIL sbom.spdx.json exists but no SPDX markers found"
    fail=$((fail+1))
  fi
else
  echo "  FAIL sbom.spdx.json missing (syft dir:. -o spdx-json=sbom.spdx.json)"
  fail=$((fail+1))
fi

# --- vulns.json (grype) — tolerated as warning if grype absent -----------
if [ -f "${BASE}/vulns.json" ]; then
  if grep -qi 'matches\|vulnerability\|"id":' "${BASE}/vulns.json"; then
    echo "  OK   vulns.json exists and looks like grype output"
  else
    echo "  WARN vulns.json exists but no grype markers found (lenient — not counted as fail)"
  fi
else
  if command -v grype >/dev/null 2>&1; then
    echo "  FAIL vulns.json missing (grype sbom:sbom.cdx.json -o json > vulns.json)"
    fail=$((fail+1))
  else
    echo "  SKIP vulns.json not produced; grype not installed (not counted as fail)"
  fi
fi

# --- provenance.json ------------------------------------------------------
if [ -f "${BASE}/provenance.json" ]; then
  checks=0
  grep -q 'in-toto.io/Statement/v1' "${BASE}/provenance.json" && checks=$((checks+1))
  grep -q 'slsa.dev/provenance/v1' "${BASE}/provenance.json" && checks=$((checks+1))
  grep -q '"subject"' "${BASE}/provenance.json" && checks=$((checks+1))
  grep -q '"predicate"' "${BASE}/provenance.json" && checks=$((checks+1))
  if [ "${checks}" -ge 4 ]; then
    echo "  OK   provenance.json has in-toto Statement v1 + SLSA v1 markers (${checks}/4)"
  else
    echo "  FAIL provenance.json missing required markers (${checks}/4 found)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL provenance.json missing (copy starter/provenance.template.json)"
  fail=$((fail+1))
fi

# --- release.yml ----------------------------------------------------------
if [ -f "${BASE}/release.yml" ]; then
  checks=0
  grep -q 'attest-build-provenance' "${BASE}/release.yml" && checks=$((checks+1))
  grep -q 'id-token:[[:space:]]*write' "${BASE}/release.yml" && checks=$((checks+1))
  grep -q 'attestations:[[:space:]]*write' "${BASE}/release.yml" && checks=$((checks+1))
  grep -q 'steps.push.outputs.digest\|subject-digest' "${BASE}/release.yml" && checks=$((checks+1))
  if [ "${checks}" -ge 4 ]; then
    echo "  OK   release.yml has required GHA markers (${checks}/4)"
  else
    echo "  FAIL release.yml missing required markers (${checks}/4 found)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL release.yml missing (copy starter/release.yml.template)"
  fail=$((fail+1))
fi

echo
if [ "${fail}" -gt 0 ]; then
  echo "RESULT: ${fail} structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
