#!/usr/bin/env bash
# Reference solution for dkr-12-02-make-build-reproducible.
# Replaces the starter Dockerfile with a reproducible one.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:-/tmp/dkr-12-repro}"
APP="$BASE/app"

bash "$HERE/starter/bootstrap.sh" "$BASE" >/dev/null

cat > "$APP/Dockerfile" <<'EOF'
# syntax=docker/dockerfile:1.7
# Base pinned by index digest (alpine:3.20).
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

# Deterministic env.
ENV TZ=UTC LC_ALL=C.UTF-8

# No 'RUN date'. No 'apk add' sin pin. Payload literal.
RUN echo "reproducible" > /build-time
CMD ["cat", "/build-time"]
EOF

echo "Solution written to $APP/Dockerfile."
echo "Validate with: bash $HERE/tests/validate.sh $BASE"
