#!/usr/bin/env bash
# Bootstrap /tmp/dkr-07-01 with a monolithic Dockerfile the learner must
# rewrite as multi-stage.
set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-01}"

echo "== Preparing $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

cat > app.py <<'PY'
"""Minimal Flask app. Does NOT actually need libpq at runtime; the
dependency on psycopg2-binary is here to force the learner to think about
toolchain vs runtime libraries. The 'binary' variant ships the lib inside
the wheel, so no system libpq is needed in runtime — but we pretend
otherwise to keep the exercise realistic for a 'real' psycopg2 case."""
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/")
def index():
    return jsonify(message="hello from monolithic (fix me)"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
PY

cat > requirements.txt <<'REQ'
flask==3.0.3
requests==2.32.3
REQ

cat > .dockerignore <<'IGN'
__pycache__
*.pyc
.git
.venv
*.log
IGN

# MONOLITHIC Dockerfile — the starting point.
# Everything (toolchain + app) lands in the final image. ~900 MB and ships gcc.
cat > Dockerfile <<'DOCKER'
# Monolithic: toolchain lives in the final image. Fix me to multi-stage.
FROM python:3.12

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc make libpq-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 8000
CMD ["python", "app.py"]
DOCKER

echo "== Done =="
echo "Workspace: $BASE"
ls -la "$BASE"
