#!/usr/bin/env bash
# Smoke test for cap-02-01: cheap sanity check that the release pipeline
# files are present and parse. Designed to be idempotent — validate.sh
# runs it twice.
#
# Note: we deliberately do NOT enable `set -o pipefail`. A few checks use
# patterns like `grep -q` on JSON output; if grep matches early, the upstream
# command may receive SIGPIPE (exit 141) and pipefail would turn that into a
# false negative.
set -eu

WORK="${1:-${WORK_DIR:-/tmp/cap-02-01}}"

[ -d "$WORK" ] || { echo "SKIP: $WORK does not exist (run the activity first)"; exit 0; }
cd "$WORK"

# All required files exist.
for f in \
    release-please-config.json \
    .release-please-manifest.json \
    commitlint.config.js \
    .gitmessage \
    CHANGELOG.md \
    .github/workflows/release-please.yml \
    .husky/commit-msg
do
  [ -e "$f" ] || { echo "FAIL smoke: missing $f"; exit 1; }
done

# JSON files parse.
python3 -c "import json,sys; json.load(open('release-please-config.json'))"
python3 -c "import json,sys; json.load(open('.release-please-manifest.json'))"

echo "smoke OK"
