#!/usr/bin/env bash
# Builds the base state for gh-04-02-collab-simulation-two-clones:
#   bare origin.git with ONE commit, plus two clones (alice, bob) ready to work.
set -euo pipefail

BASE="${1:-/tmp/gh-04-collab}"
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 1) The bare "server"
git init --bare -q -b main origin.git

# 2) Seed it via a throwaway clone (so the bare has an initial commit on main)
git clone -q ./origin.git _seed
(
  cd _seed
  git config user.name  "Seed"
  git config user.email "seed@example.com"
  echo "# collab lab" > README.md
  git add README.md
  git commit -q -m "init: project"
  git push -qu origin main
)
rm -rf _seed

# 3) Alice clone
git clone -q ./origin.git alice
(
  cd alice
  git config user.name  "Alice"
  git config user.email "alice@example.com"
)

# 4) Bob clone
git clone -q ./origin.git bob
(
  cd bob
  git config user.name  "Bob"
  git config user.email "bob@example.com"
)

cat <<EOF
Base listo en: $BASE
  bare:  $BASE/origin.git/   (main con 1 commit 'init: project')
  alice: $BASE/alice/        (clone de Alice, main tracking origin/main)
  bob:   $BASE/bob/          (clone de Bob,   main tracking origin/main)

Objetivo: dejar main con 3 features más, lineal, sincronizado en los 3 lados.
Lee README.md § "La misión".

Validar al final:
  bash ../tests/validate.sh $BASE
EOF
