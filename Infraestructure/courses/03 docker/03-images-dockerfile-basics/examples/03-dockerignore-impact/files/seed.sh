#!/usr/bin/env bash
# Puebla el directorio actual con "basura" realista para que la diferencia
# con/sin .dockerignore sea visible: un .git/ con historial, un .venv/ con
# binarios ficticios, un node_modules/ y logs grandes.
set -euo pipefail

mkdir -p .venv/lib node_modules/junk logs

# 20 MB de "binarios" ficticios en .venv
dd if=/dev/urandom of=.venv/lib/libfake.so bs=1024 count=20480 status=none

# 20 MB de "node_modules" ficticios
dd if=/dev/urandom of=node_modules/junk/bundle.js bs=1024 count=20480 status=none

# 10 MB de logs
dd if=/dev/urandom of=logs/app.log bs=1024 count=10240 status=none

# Un .git/ con un poco de historial
if [ ! -d .git ]; then
  git init -q -b main
  git config user.name "seed"
  git config user.email "seed@example.com"
  echo "noise" > .seed-noise
  git add -A
  git commit -q -m "seed commit 1"
  for i in 1 2 3; do
    date >> .seed-noise
    git add -A
    git commit -q -m "seed commit $((i+1))"
  done
fi

echo "Seed OK. Tamano total:"
du -sh .
