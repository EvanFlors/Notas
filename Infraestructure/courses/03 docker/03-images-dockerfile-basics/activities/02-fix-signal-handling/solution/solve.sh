#!/usr/bin/env bash
# Reference solution: convertir el CMD a exec form.
set -euo pipefail

BASE="${1:-/tmp/dkr-03-02}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bash "$SCRIPT_DIR/starter/bootstrap.sh" "$BASE" >/dev/null

PROJECT="$BASE/project"
cd "$PROJECT"

cat > Dockerfile <<'EOF'
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
COPY app.py /app.py
# FIX: exec form. python toma PID 1 y recibe SIGTERM directamente.
CMD ["python", "/app.py"]
EOF

echo "Solution written at: $PROJECT (CMD convertido a exec form)."
echo "Ahora corre:"
echo "  bash $SCRIPT_DIR/tests/validate.sh $BASE"
