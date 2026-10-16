#!/usr/bin/env bash
# sec-08 example 01 — syft CycloneDX & SPDX + grype scan over SBOM.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` or `jq ... | wc -l` which can produce SIGPIPE (141)
# when a consumer closes the pipe early. pipefail would mark those spuriously
# as failures.
set -eu

SCRATCH="/tmp/sec-08-syft-demo"
cleanup() {
  echo "[DONE] cleaning up ${SCRATCH}"
  rm -rf "${SCRATCH}"
}
trap cleanup EXIT INT TERM

echo "== sec-08 example 01: syft CycloneDX & SPDX =="

if ! command -v syft >/dev/null 2>&1; then
  echo "[SKIP] syft not found. Install: https://github.com/anchore/syft#installation"
  echo "[SKIP] example cannot run; exiting 0."
  exit 0
fi
echo "[OK] syft found ($(syft version 2>/dev/null | head -n1 || echo 'version?'))"

if ! command -v grype >/dev/null 2>&1; then
  echo "[SKIP] grype not found. Install: https://github.com/anchore/grype#installation"
  echo "[SKIP] continuing without vulnerability scan."
  HAS_GRYPE=0
else
  echo "[OK] grype found ($(grype version 2>/dev/null | head -n1 || echo 'version?'))"
  HAS_GRYPE=1
fi

mkdir -p "${SCRATCH}"
echo "[INFO] scratch: ${SCRATCH}"

cat > "${SCRATCH}/requirements.txt" <<'EOF'
# Pinned old versions on purpose — this is a learning sample.
# Do NOT copy to a real project.
requests==2.25.1
urllib3==1.26.5
jinja2==2.11.3
EOF

cat > "${SCRATCH}/app.py" <<'EOF'
"""Minimal app used only as SBOM input — never executed."""
import requests  # noqa: F401
EOF

echo "[INFO] generating source SBOM (CycloneDX)..."
syft "dir:${SCRATCH}" -o "cyclonedx-json=${SCRATCH}/sbom-source.cdx.json" >/dev/null
CDX_COUNT=$(grep -o '"bom-ref"' "${SCRATCH}/sbom-source.cdx.json" | wc -l | tr -d ' ')
echo "[OK] sbom-source.cdx.json written (${CDX_COUNT} component refs)"

echo "[INFO] generating source SBOM (SPDX)..."
syft "dir:${SCRATCH}" -o "spdx-json=${SCRATCH}/sbom-source.spdx.json" >/dev/null
SPDX_COUNT=$(grep -o '"SPDXID"' "${SCRATCH}/sbom-source.spdx.json" | wc -l | tr -d ' ')
echo "[OK] sbom-source.spdx.json written (${SPDX_COUNT} SPDX IDs)"

echo "[INFO] both formats generated — compare field names:"
echo "       CycloneDX uses: components[].purl"
echo "       SPDX uses:      packages[].externalRefs[].referenceLocator"

if [ "${HAS_GRYPE}" -eq 1 ]; then
  echo "[INFO] scanning SBOM with grype..."
  # grype prints a lot to stderr about DB updates — redirect for clean output.
  if grype "sbom:${SCRATCH}/sbom-source.cdx.json" -o json \
       > "${SCRATCH}/vulns.json" 2>/dev/null; then
    TOTAL=$(grep -o '"id":' "${SCRATCH}/vulns.json" | wc -l | tr -d ' ')
    echo "[OK] vulns.json written (~${TOTAL} id references — may include dupes)"
  else
    echo "[WARN] grype scan failed (DB fetch issue?). SBOM still valid."
  fi
fi

echo "[OK] example finished successfully."
