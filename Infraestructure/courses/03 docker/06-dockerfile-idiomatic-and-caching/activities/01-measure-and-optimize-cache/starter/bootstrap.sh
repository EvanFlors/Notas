#!/usr/bin/env bash
# Bootstrap /tmp/dkr-06-01 with a BAD Dockerfile the learner must fix.
set -eu

BASE="${BASE_DIR:-/tmp/dkr-06-01}"

echo "== Preparing $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

cat > app.py <<'PY'
from flask import Flask

app = Flask(__name__)


@app.get("/health")
def health():
    return {"status": "ok"}, 200


@app.get("/")
def index():
    return {"message": "hello"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
PY

cat > requirements.txt <<'REQ'
flask==3.0.3
REQ

cat > .dockerignore <<'IGN'
__pycache__
*.pyc
.git
.venv
IGN

# BAD Dockerfile — this is the starting point. COPY . . before pip install
# invalidates the install cache on every code edit.
cat > Dockerfile <<'DOCKER'
FROM python:3.12-slim

WORKDIR /app

# ANTI-PATTERN: copying everything before installing dependencies.
# Any edit to app.py will invalidate the pip install cache below.
COPY . .

RUN pip install -r requirements.txt

EXPOSE 8000
CMD ["python", "app.py"]
DOCKER

echo "== Done =="
echo "Workspace at: $BASE"
echo "Next: cd $BASE && docker build ..."
ls -la "$BASE"
