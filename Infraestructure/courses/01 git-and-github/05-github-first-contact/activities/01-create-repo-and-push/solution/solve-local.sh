#!/usr/bin/env bash
# Reference solution for gh-05-01-create-repo-and-push in MODE=local.
# Runs the full happy path: bootstrap -> edit files -> commit -> push to bare origin.
set -euo pipefail

BASE="${1:-/tmp/create-repo-and-push}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

cd "$BASE/local"

cat > README.md <<'EOF'
# mi-primer-repo

A tiny demo project used to practice the "first contact with GitHub" workflow.

## Instalación

```bash
git clone <this-repo>
cd mi-primer-repo
```

## Uso

```bash
python -m mipaquete --help
```

## Licencia

MIT (ver `LICENSE`).
EOF

cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Student

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
.venv/
.pytest_cache/
.coverage
.DS_Store
dist/
build/
EOF

git add README.md LICENSE .gitignore
git commit -q -m "chore: initial public skeleton (README, LICENSE, .gitignore)"
git push -u origin main

echo
echo "== Done. State: =="
git log --oneline
echo
echo "Bare origin refs:"
git --git-dir="$BASE/origin.git" show-ref
