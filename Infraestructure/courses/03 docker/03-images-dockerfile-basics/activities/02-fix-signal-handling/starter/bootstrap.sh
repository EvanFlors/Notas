#!/usr/bin/env bash
# Bootstrap for dkr-03-02-fix-signal-handling.
# Crea un proyecto con un Dockerfile roto (shell-form CMD).
set -euo pipefail

BASE="${1:-/tmp/dkr-03-02}"
PROJECT="$BASE/project"

rm -rf "$BASE"
mkdir -p "$PROJECT"
cd "$PROJECT"

# App que loguea senales. NO la toques.
cat > app.py <<'EOF'
import signal
import sys
import time
import os


def handler(signum, frame):
    name = signal.Signals(signum).name
    print(f"[{os.getpid()}] recibi {name}; shutdown ordenado.", flush=True)
    sys.exit(0)


signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)

print(f"[{os.getpid()}] PID {os.getpid()}; esperando senales...", flush=True)
while True:
    time.sleep(1)
EOF

# Dockerfile ROTO: CMD en shell form -> /bin/sh es PID 1 y no reenvia SIGTERM.
cat > Dockerfile <<'EOF'
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
COPY app.py /app.py
# BUG: shell form. /bin/sh -c "python /app.py" => /bin/sh es PID 1,
# no reenvia SIGTERM, docker stop tarda 10s hasta el SIGKILL.
CMD python /app.py
EOF

echo "== Bootstrap OK =="
echo "Proyecto: $PROJECT"
echo
echo "Reproduce el sintoma:"
echo "  cd $PROJECT"
echo "  docker build -t signal-broken:v1 ."
echo "  docker run -d --name sb signal-broken:v1"
echo "  sleep 1 && time docker stop sb   # ~10s"
echo "  docker logs sb                   # SIN 'recibi SIGTERM'"
echo "  docker rm sb"
echo
echo "Luego: edita Dockerfile para corregir y re-ejecuta."
