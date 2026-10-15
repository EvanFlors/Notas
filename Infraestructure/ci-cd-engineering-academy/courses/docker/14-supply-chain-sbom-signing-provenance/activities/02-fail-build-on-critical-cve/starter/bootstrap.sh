#!/usr/bin/env bash
# Scaffolding for dkr-14-02 — fail build on CRITICAL CVE.
set -euo pipefail

BASE="${1:-/tmp/dkr-14-02}"
echo "== bootstrap dkr-14-02 at $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE"

# Deliberately old base to force CRITICAL findings without network scaffolding.
cat > "$BASE/Dockerfile" <<'EOF'
# NOT FOR PRODUCTION — this image is intentionally vulnerable.
FROM alpine:3.14
RUN apk add --no-cache curl openssl
CMD ["sh", "-c", "echo 'vulnerable demo'"]
EOF

cat > "$BASE/scan.sh" <<'EOF'
#!/usr/bin/env bash
# scan.sh — STUB. Implement the trivy gate.
# Note: do NOT add `set -o pipefail` if you pipe to grep -q (SIGPIPE 141).
set -eu

IMAGE="dkr-14-02-vuln:v1"
BASE="$(cd "$(dirname "$0")" && pwd)"

# Build if not present
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build -t "$IMAGE" "$BASE"
fi

# TODO: run trivy with --severity CRITICAL and --exit-code 1 so the script
#       exits non-zero when any CRITICAL is found.
#
# TODO: capture the exit code and print "GATE: OK" or "GATE: FAIL ..."
#       Then exit with the captured code.

echo "scan.sh is a STUB — implement the trivy gate."
exit 1
EOF
chmod +x "$BASE/scan.sh"

cat > "$BASE/NOTES.md" <<'EOF'
# dkr-14-02 — scaffolding ready

Goal: complete scan.sh so it:
  - runs `trivy image --severity CRITICAL --exit-code 1 dkr-14-02-vuln:v1`
  - exits with the trivy exit code (0 = clean, 1 = CRITICAL found)
  - prints a clear "GATE: OK" / "GATE: FAIL" message

Then verify:
  bash scan.sh
  echo $?           # should be 1 (the base image is deliberately old)

  bash <activity>/tests/validate.sh /tmp/dkr-14-02

Install trivy if missing:
  brew install trivy
    or
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin
EOF

echo "Scaffolding ready at $BASE"
echo "Next: cd $BASE && cat NOTES.md"
