#!/usr/bin/env bash
# Builds the fetch-vs-pull demo scratch repos.
# Does NOT reproduce the pull-with-conflict interactively — that is for YOU to do by hand.
set -euo pipefail

DEMO="${1:-/tmp/fetch-vs-pull}"
rm -rf "$DEMO"
mkdir -p "$DEMO"
cd "$DEMO"

git init --bare -q origin.git

# Alice
git clone -q ./origin.git alice
(
  cd alice
  git config user.name  "Alice"
  git config user.email "alice@example.com"
  echo "line 1" > notes.txt
  git add notes.txt
  git commit -q -m "init: first line"
  git push -qu origin main
)

# Bob (clone before Alice's 2nd commit)
git clone -q ./origin.git bob
(
  cd bob
  git config user.name  "Bob"
  git config user.email "bob@example.com"
)

# Alice adds a second commit on top of main and pushes
(
  cd alice
  echo "line 2 (alice)" >> notes.txt
  git add notes.txt
  git commit -q -m "feat: alice line 2"
  git push -q
)

cat <<EOF

Demo listo en: $DEMO
  $DEMO/origin.git/   bare "server"
  $DEMO/alice/        clon de Alice (ya pusheó un commit extra)
  $DEMO/bob/          clon de Bob  (todavía no sabe nada)

Ahora, A MANO, entra a bob y ejecuta:

  cd $DEMO/bob
  git log --oneline            # 1 commit (bob no ha hecho fetch)
  git fetch origin
  git log --oneline            # SIGUE siendo 1 commit (fetch no mueve main)
  git log --oneline origin/main
  git status                   # "behind by 1 commit"

Luego fuerza divergencia y prueba 'pull' default (sorprende) vs 'pull --ff-only':

  echo "line 2 (bob)" >> notes.txt && git add notes.txt
  git commit -m "feat: bob line 2"
  git pull --no-rebase --no-ff      # te mete merge commit (conflicto que debes resolver)
  git reset --hard HEAD~1           # deshacer el merge
  git pull --ff-only                # falla: te protege
  git pull --rebase                 # tu commit queda sobre el de alice; sin merge commit

Limpieza:
  rm -rf $DEMO
EOF
