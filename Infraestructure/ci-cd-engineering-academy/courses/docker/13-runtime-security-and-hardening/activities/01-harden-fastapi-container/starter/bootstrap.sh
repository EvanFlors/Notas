#!/usr/bin/env bash
# Bootstrap for dkr-13-01-harden-fastapi-container.
#
# Creates /tmp/.../work with a FastAPI app and PLACEHOLDER Dockerfile + run.sh
# that are deliberately INSECURE. The student hardens both until validate.sh
# reports 6/6 OK.
set -euo pipefail

BASE="${1:-/tmp/dkr13-01}"

if [ -e "$BASE" ]; then
  echo "Removing previous $BASE"
  rm -rf "$BASE"
fi

WORK="$BASE/work"
mkdir -p "$WORK/app"

cat > "$WORK/app/main.py" <<'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    return {"message": "hello from hardened fastapi"}


@app.get("/health")
def health():
    return {"status": "ok"}
EOF

cat > "$WORK/app/requirements.txt" <<'EOF'
fastapi==0.115.6
uvicorn[standard]==0.32.1
EOF

cat > "$WORK/Dockerfile" <<'EOF'
# PLACEHOLDER — INSEGURO. Debes reescribirlo para cumplir los criterios.
#
# Requisitos:
#   - FROM con tag pinned (no :latest).
#   - RUN que crea user/group 'app' con UID/GID 10001.
#   - WORKDIR, COPY --chown=app:app.
#   - pip install --no-cache-dir -r requirements.txt
#   - USER 10001:10001
#   - EXPOSE 8000
#   - ENTRYPOINT que arranque uvicorn en 0.0.0.0:8000
#
# Mientras exista este placeholder la imagen correra como root y validate.sh fallara.
FROM python:latest

WORKDIR /app
COPY app/ /app/
RUN pip install -r requirements.txt

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > "$WORK/run.sh" <<'EOF'
#!/usr/bin/env bash
# PLACEHOLDER — INSEGURO. Debes reescribirlo con los controles de hardening.
#
# Flags minimas requeridas:
#   --name dkr13-01-app
#   --user 10001:10001
#   --read-only
#   --tmpfs /tmp:rw,noexec,nosuid,size=16m
#   --cap-drop=ALL
#   --security-opt no-new-privileges:true
#   --memory=256m   --memory-swap=256m
#   --pids-limit=100
#   -p 127.0.0.1:8000:8000
#   dkr13-01:v1
set -eu

docker rm -f dkr13-01-app >/dev/null 2>&1 || true

# INSECURE DEFAULTS:
docker run -d \
  --name dkr13-01-app \
  -p 0.0.0.0:8000:8000 \
  dkr13-01:v1

echo "Started (INSECURE). Rewrite this file."
EOF
chmod +x "$WORK/run.sh"

echo "== Bootstrap OK =="
echo "Work dir:   $WORK"
echo "Next:"
echo "  1) Edit $WORK/Dockerfile  (quitar PLACEHOLDER, poner USER no-root, etc.)"
echo "  2) Edit $WORK/run.sh      (añadir --read-only, --cap-drop=ALL, ...)"
echo "  3) cd $WORK && docker build -t dkr13-01:v1 . && bash run.sh"
echo "  4) bash .../tests/validate.sh $BASE"
