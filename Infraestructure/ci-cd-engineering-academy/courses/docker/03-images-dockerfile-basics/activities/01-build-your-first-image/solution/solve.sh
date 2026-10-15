#!/usr/bin/env bash
# Reference solution for dkr-03-01-build-your-first-image.
# Reusa el bootstrap y luego reemplaza Dockerfile + .dockerignore por versiones
# que cumplen los criterios.
set -euo pipefail

BASE="${1:-/tmp/dkr-03-01}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bash "$SCRIPT_DIR/starter/bootstrap.sh" "$BASE" >/dev/null

PROJECT="$BASE/project"
cd "$PROJECT"

cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Deps primero para cachear
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Codigo despues
COPY app ./app

# Usuario no-root
RUN groupadd --system --gid 10001 appuser \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home appuser
USER 10001:10001

EXPOSE 8000

# Exec form: uvicorn es PID 1 y recibe SIGTERM directamente
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > .dockerignore <<'EOF'
.git/
__pycache__/
*.pyc
.pytest_cache/
.venv/
venv/
.env
.env.*
.vscode/
.idea/
tests/
EOF

echo "Solution written at: $PROJECT"
echo "Ahora corre:"
echo "  bash $SCRIPT_DIR/tests/validate.sh $BASE"
