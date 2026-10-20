#!/usr/bin/env bash
# Bootstrap /tmp/dkr-06-02 with three source materials (code, tar, "remote" sample).
set -eu

BASE="${BASE_DIR:-/tmp/dkr-06-02}"

echo "== Preparing $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/src" "$BASE/dist" "$BASE/assets" "$BASE/tar-src"
cd "$BASE"

# --- Scenario A: plain source code ---
cat > src/main.py <<'PY'
def main():
    print("hello from main")


if __name__ == "__main__":
    main()
PY
cat > src/helper.py <<'PY'
def add(a, b):
    return a + b
PY
cat > src/__init__.py <<'PY'
PY

# --- Scenario B: a tar.gz with prebuilt assets ---
mkdir -p tar-src
cat > tar-src/README.txt <<'TXT'
Prebuilt assets v1.0
These files represent a dist artifact (think: a prebuilt frontend bundle).
TXT
cat > tar-src/index.html <<'HTML'
<html><body>demo</body></html>
HTML
tar -czf dist/app-dist.tar.gz -C tar-src .
rm -rf tar-src

# --- Scenario C: simulate a "remote" artifact we must verify by checksum ---
cat > assets/remote-sample.txt <<'TXT'
This payload simulates a remote artifact fetched from a release URL.
In a real Dockerfile you would use RUN curl -fsSL <url> -o /opt/payload
and then verify the sha256 against a trusted value.
TXT

# Compute the sha256 of the sample.
if command -v sha256sum >/dev/null 2>&1; then
  SHA="$(sha256sum assets/remote-sample.txt | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  SHA="$(shasum -a 256 assets/remote-sample.txt | awk '{print $1}')"
else
  echo "ERROR: need sha256sum or shasum to bootstrap." >&2
  exit 1
fi
printf '%s  /opt/payload\n' "$SHA" > assets/checksum.txt

# Empty Dockerfile for the learner to fill in.
cat > Dockerfile <<'DOCKER'
# TODO: build an image per the activity README.
# Base must be alpine:3.20.
# Scenario A: copy src/ to /app/        (COPY vs ADD?)
# Scenario B: extract dist/app-dist.tar.gz into /opt/assets/   (COPY vs ADD?)
# Scenario C: place assets/remote-sample.txt at /opt/payload and verify sha256
#            against assets/checksum.txt. Use COPY + RUN sha256sum -c.
#
# Comment EACH decision with a short justification (one line is enough).

FROM alpine:3.20

# <scenario A here>

# <scenario B here>

# <scenario C here>

CMD ["cat", "/opt/payload"]
DOCKER

echo "== Done =="
echo "Workspace at: $BASE"
echo "sha256 recorded in assets/checksum.txt: $SHA"
ls -la "$BASE"
