#!/usr/bin/env bash
# Builds the two-clones demo scratch repos.
set -euo pipefail

DEMO="${1:-/tmp/two-clones}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init --bare -q origin.git

git clone -q ./origin.git alice
(
  cd alice
  git config user.name  "Alice"
  git config user.email "alice@example.com"
  echo "# Project" > README.md
  git add README.md
  git commit -q -m "init: readme"
  git push -qu origin main
)

git clone -q ./origin.git bob
(
  cd bob
  git config user.name  "Bob"
  git config user.email "bob@example.com"
)

cat <<EOF

Demo listo en: $DEMO
  bare:  $DEMO/origin.git/
  alice: $DEMO/alice
  bob:   $DEMO/bob

Reproduce los 3 rounds del README manualmente. Cuando termines:
  rm -rf $DEMO
EOF
