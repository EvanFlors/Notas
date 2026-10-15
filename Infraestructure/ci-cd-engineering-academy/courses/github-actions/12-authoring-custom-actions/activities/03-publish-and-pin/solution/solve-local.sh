#!/usr/bin/env bash
# Reference solution for gha-12-03-publish-and-pin, MODE=local.
set -euo pipefail

BASE="${1:-/tmp/publish-and-pin}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

# Publisher: tag v1.0.0 + v1 and push
cd "$BASE/publisher"
git tag -a v1.0.0 -m "v1.0.0 - initial release"
git tag -f v1 v1.0.0
git push -q origin main
git push -q origin v1.0.0
git push -q origin v1 --force

SHA="$(git rev-parse v1.0.0)"
echo "Publisher v1.0.0 SHA: $SHA"

# Consumer: edit workflow to pin to SHA with version comment
cd "$BASE/consumer"
python3 - "$SHA" <<'PY'
import pathlib, sys
sha = sys.argv[1]
wf = pathlib.Path(".github/workflows/ci.yml")
text = wf.read_text().replace(
    "uses: demo-owner/greet-action@PLACEHOLDER_GREET_SHA",
    f"uses: demo-owner/greet-action@{sha}  # v1.0.0",
)
wf.write_text(text)
PY

git add .github/workflows/ci.yml
git commit -q -m "ci: pin greet-action to v1.0.0 SHA"
git push -q -u origin main

echo
echo "== Done. State: =="
echo "-- publisher tags --"
(cd "$BASE/publisher" && git tag -l)
echo "-- publisher.git refs --"
(cd "$BASE/publisher" && git --git-dir="$BASE/publisher.git" show-ref | sort)
echo "-- consumer workflow (greet step) --"
grep -A2 "greet-action@" "$BASE/consumer/.github/workflows/ci.yml"
