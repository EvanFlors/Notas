#!/usr/bin/env bash
# Bootstrap for gh-05-02-publish-first-release.
#
# MODE=local (default): working repo + bare origin, both wired.
# MODE=live: working repo only; student runs `gh repo create` or re-uses an
# existing repo (and sets 'origin' accordingly).
set -euo pipefail

BASE="${1:-/tmp/publish-first-release}"
MODE="${MODE:-local}"

rm -rf "$BASE"
mkdir -p "$BASE"

LOCAL="$BASE/local"
mkdir -p "$LOCAL"
cd "$LOCAL"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > README.md <<'EOF'
# release-ready-demo

Trivial package to practice the release workflow.

## Instalación

Descarga el `.tar.gz` del release `v0.1.0`.

## Uso

```bash
./hello.sh
```

## Licencia

MIT (ver `LICENSE`).
EOF

cat > hello.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from release-ready-demo"
EOF
chmod +x hello.sh

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
.venv/
.DS_Store
EOF

cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Student

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
EOF

git add .
git commit -q -m "feat: initial release-ready-demo"

if [ "$MODE" = "local" ]; then
  echo "== MODE=local: creating bare origin and wiring remote =="
  git init -q --bare "$BASE/origin.git"
  git remote add origin "$BASE/origin.git"
  git push -q -u origin main
  echo
  echo "Working repo: $LOCAL"
  echo "Bare origin:  $BASE/origin.git"
  echo
  echo "Now follow the README to create tag v0.1.0, push it, build asset,"
  echo "and simulate the release under $BASE/releases/v0.1.0/"
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh CLI missing or not authenticated." >&2
    exit 2
  fi
  echo "== MODE=live =="
  echo "Working repo: $LOCAL"
  echo
  echo "Next:"
  echo "  cd $LOCAL"
  echo "  gh repo create release-ready-demo-\$RANDOM --public --source=. --remote=origin --push"
  echo "  git tag -a v0.1.0 -m '...'"
  echo "  git push origin v0.1.0"
  echo "  tar -czf ../v0.1.0.tar.gz --exclude='.git' -C .. local"
  echo "  gh release create v0.1.0 --title '...' --notes '...' ../v0.1.0.tar.gz"
else
  echo "ERROR: unknown MODE='$MODE'" >&2
  exit 2
fi
