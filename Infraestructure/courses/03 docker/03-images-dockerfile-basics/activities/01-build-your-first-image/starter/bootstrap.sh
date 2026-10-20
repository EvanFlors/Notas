#!/usr/bin/env bash
# Bootstrap for dkr-03-01-build-your-first-image.
# Crea /tmp/.../project con un Dockerfile PLACEHOLDER que no cumple los
# criterios; el estudiante lo reemplaza.
set -euo pipefail

BASE="${1:-/tmp/dkr-03-01}"
PROJECT="$BASE/project"

rm -rf "$BASE"
mkdir -p "$PROJECT/app"
cd "$PROJECT"

cat > requirements.txt <<'EOF'
fastapi==0.115.0
uvicorn[standard]==0.30.6
EOF

cat > app/__init__.py <<'EOF'
EOF

cat > app/main.py <<'EOF'
from fastapi import FastAPI
import os

app = FastAPI(title="dkr-03-01")


@app.get("/")
def root():
    return {"service": "dkr-03-01", "pid": os.getpid(), "uid": os.getuid()}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
EOF

# Placeholder Dockerfile que NO cumple los criterios:
#   - Sin USER (corre como root)
#   - CMD en shell form
#   - COPY . . antes de pip install (invalida cache en cada cambio)
cat > Dockerfile <<'EOF'
# PLACEHOLDER Dockerfile. Reemplazalo para que cumpla:
#   - Base python:3.12-slim (o similar)
#   - WORKDIR /app
#   - COPY requirements.txt ANTES que COPY del codigo
#   - RUN pip install --no-cache-dir -r requirements.txt
#   - COPY app ./app
#   - USER no-root (UID >= 1000)
#   - EXPOSE 8000
#   - CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
#     (exec form, JSON array)
#
# Mientras exista este placeholder, el validador fallara.
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD uvicorn app.main:app --host 0.0.0.0 --port 8000
EOF

# .dockerignore placeholder vacio
cat > .dockerignore <<'EOF'
# TODO: completa con al menos: .git/, __pycache__/, .venv/, .env*
EOF

echo "== Bootstrap OK =="
echo "Proyecto: $PROJECT"
echo
echo "Next:"
echo "  1) Edita $PROJECT/Dockerfile para cumplir los criterios."
echo "  2) Edita $PROJECT/.dockerignore."
echo "  3) bash .../tests/validate.sh $BASE"
