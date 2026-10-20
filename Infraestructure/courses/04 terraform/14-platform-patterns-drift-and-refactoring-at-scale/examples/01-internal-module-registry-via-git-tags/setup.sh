#!/usr/bin/env bash
# Publish the golden module into a local bare git repo that acts as the
# "internal registry", and prepare a consumer workdir.
#
# Usage:
#   bash setup.sh                  # full bootstrap: create registry + v1.0.0 + consumer
#   TAG=v1.1.0 bash setup.sh --release-only   # publish a new tag only (no consumer touch)
#
# Deliberately NO `set -o pipefail` combined with `grep -q`.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_DIR="/tmp/registry"
MODULE_NAME="local-greeter"
BARE_REPO="$REGISTRY_DIR/${MODULE_NAME}.git"
CONSUMER_DIR="/tmp/consumer-tf14-01"
TAG="${TAG:-v1.0.0}"
RELEASE_ONLY="no"

for arg in "$@"; do
  case "$arg" in
    --release-only) RELEASE_ONLY="yes" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$REGISTRY_DIR"

if [ ! -d "$BARE_REPO" ]; then
  echo ">> creating bare registry repo at $BARE_REPO"
  git init --bare --initial-branch=main "$BARE_REPO" >/dev/null
fi

WORKTREE="$(mktemp -d)"
trap 'rm -rf "$WORKTREE"' EXIT

echo ">> publishing tag $TAG from module-source/"
cp -R "$HERE/module-source/." "$WORKTREE/"
cd "$WORKTREE"
git init --initial-branch=main >/dev/null
git config user.email "platform@example.local"
git config user.name  "Platform Bot"
git add .
git commit -m "release $TAG" >/dev/null

# If the tag already exists in the bare repo, refuse to re-publish (immutability).
if git ls-remote --tags "$BARE_REPO" "refs/tags/$TAG" | grep -q "refs/tags/$TAG"; then
  echo "!! tag $TAG already exists in registry — refusing to re-publish (immutability rule)." >&2
  echo "   bump the version and re-run with TAG=vX.Y.Z" >&2
  exit 1
fi

git tag -a "$TAG" -m "release $TAG"
git remote add origin "$BARE_REPO"
git push origin main --tags >/dev/null 2>&1

echo "   published $MODULE_NAME@$TAG"

if [ "$RELEASE_ONLY" = "yes" ]; then
  echo ">> --release-only: skipping consumer prep"
  exit 0
fi

echo ">> preparing consumer workdir at $CONSUMER_DIR"
rm -rf "$CONSUMER_DIR"
mkdir -p "$CONSUMER_DIR"
cp -R "$HERE/consumer/." "$CONSUMER_DIR/"

echo
echo "DONE. Next:"
echo "  cd $CONSUMER_DIR && terraform init && terraform apply -auto-approve"
