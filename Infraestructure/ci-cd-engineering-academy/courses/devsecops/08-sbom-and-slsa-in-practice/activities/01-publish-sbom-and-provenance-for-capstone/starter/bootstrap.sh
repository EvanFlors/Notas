#!/usr/bin/env bash
# Optional helper: creates the scratch dir and copies templates in place.
#
# Note: no `set -o pipefail` on purpose — we use grep -q downstream and
# pipefail would mark SIGPIPE (141) as a failure.
set -eu

BASE="${1:-/tmp/sec-08-capstone}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${BASE}"
cp "${HERE}/provenance.template.json" "${BASE}/provenance.json"
cp "${HERE}/release.yml.template" "${BASE}/release.yml"

cat <<EOF
[OK] scratch dir ready at ${BASE}
     - provenance.json (edit it)
     - release.yml     (adapt <org>/<repo> to your repo)
Next:
  cd ${BASE}
  # (then run syft + grype commands per README)
EOF
