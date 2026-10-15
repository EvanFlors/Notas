#!/usr/bin/env bash
# Bootstrap /tmp/dkr-07-02 with a Dockerfile that LEAKS a token via ARG.
# The learner must reproduce the leak and migrate to --mount=type=secret.
set -eu

BASE="${BASE_DIR:-/tmp/dkr-07-02}"

echo "== Preparing $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# The dummy token the learner will "leak" and then protect.
# IMPORTANT: this is a FAKE value for pedagogy. Do not use real tokens.
cat > TOKEN_FOR_REPRO <<'TXT'
FAKE_TOKEN_abcdef0123456789
TXT

# A trivial payload that pretends to need a token at build time
# (e.g., downloading a private artifact). We just write a receipt.
cat > fetch.sh <<'SH'
#!/bin/sh
# Pretend to use $1 as an auth token to fetch a private artifact.
# We only emit a receipt (length of the token) to prove it was used.
TOKEN="$1"
if [ -z "$TOKEN" ]; then
  echo "no token"; exit 1
fi
echo "fetched ok (token length=${#TOKEN})"
SH
chmod +x fetch.sh

# BUGGY Dockerfile: ARG + usage inside RUN + a cosmetic rm. Leaks via history.
cat > Dockerfile <<'DOCKER'
# BUG: this Dockerfile leaks API_TOKEN into docker history.
FROM alpine:3.20

WORKDIR /app

COPY fetch.sh ./

# ARG makes the value visible in `docker history --no-trunc` once used in RUN.
ARG API_TOKEN

# "Use" the token and then "clean up". The rm does NOT remove the token from
# the layer because the RUN itself is one layer, and the ARG substitution is
# baked into the created_by field of that layer.
RUN echo "$API_TOKEN" > /app/.secret \
 && ./fetch.sh "$(cat /app/.secret)" \
 && rm /app/.secret

CMD ["sh", "-c", "echo app running"]
DOCKER

cat > .dockerignore <<'IGN'
TOKEN_FOR_REPRO
*.token
IGN

echo "== Done =="
echo "Workspace: $BASE"
echo "Dummy token for the exercise: $(cat TOKEN_FOR_REPRO)"
ls -la "$BASE"
