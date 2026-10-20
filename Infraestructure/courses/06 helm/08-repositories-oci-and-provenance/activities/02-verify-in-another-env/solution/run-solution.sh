#!/usr/bin/env bash
# Reference solution for helm-08-02 — consumer side, MODE=local.
# Assumes activities/01 publisher has already run (chart at localhost:5000,
# cosign.pub at /tmp/helm-08-act01/keys/cosign.pub).
#
# Note: NO `set -o pipefail` — pipes to grep -q may yield SIGPIPE.
set -eu

BASE="${BASE:-/tmp/helm-08-act02}"
PUB_BASE="${PUB_BASE:-/tmp/helm-08-act01}"
CHART_NAME="${CHART_NAME:-mi-app}"
CHART_VER="${CHART_VER:-0.1.0}"
REG_HOST="${REG_HOST:-localhost:5000}"

for b in helm cosign curl; do
  command -v "$b" >/dev/null 2>&1 || { echo "SKIP: $b not installed."; exit 0; }
done

echo "== helm-08-02 solution (consumer) at $BASE =="

rm -rf "$BASE"
mkdir -p "$BASE/pulled"

echo "-- pull chart to local workspace ..."
helm pull "oci://${REG_HOST}/charts/${CHART_NAME}" --version "$CHART_VER" \
  --plain-http --destination "$BASE/pulled" >/dev/null
TGZ=$(ls "$BASE/pulled/"*.tgz | head -1)
echo "   got $TGZ"

echo "-- resolve digest ..."
DIGEST=$(curl -sfI -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  "http://${REG_HOST}/v2/charts/${CHART_NAME}/manifests/${CHART_VER}" \
  | awk 'tolower($1)=="docker-content-digest:" {print $2}' | tr -d '\r')
IMG="${REG_HOST}/charts/${CHART_NAME}@${DIGEST}"
echo "   $IMG"

echo "-- cosign verify (positive, publisher's cosign.pub) ..."
cosign verify --key "$PUB_BASE/keys/cosign.pub" \
  --insecure-ignore-tlog --allow-insecure-registry "$IMG" >/dev/null 2>&1 \
  && echo "   OK" || { echo "   FAIL"; exit 1; }

echo "-- cosign verify (negative, fresh key) ..."
TMP=$(mktemp -d /tmp/h08-02-neg.XXXX)
(cd "$TMP" && COSIGN_PASSWORD='' cosign generate-key-pair >/dev/null 2>&1)
if cosign verify --key "$TMP/cosign.pub" --insecure-ignore-tlog \
                 --allow-insecure-registry "$IMG" >/dev/null 2>&1; then
  echo "   UNEXPECTED PASS"; rm -rf "$TMP"; exit 1
else
  echo "   OK — rejected"
fi
rm -rf "$TMP"

echo "-- helm template from local .tgz (air-gap) ..."
helm template my-release "$TGZ" > "$BASE/rendered.yaml"
echo "   wrote $BASE/rendered.yaml ($(wc -l < "$BASE/rendered.yaml") lines)"

cat > "$BASE/REPORT.md" <<'EOF'
# REPORT — helm-08-02 (reference)

- Chart pulled from `oci://localhost:5000/charts/mi-app:0.1.0` into
  `pulled/`. The .tgz is now independent of the registry.
- Verified cosign signature against the publisher's `cosign.pub`:
  signature matches the chart digest, so no in-flight tampering, and
  the signer *held* the private key paired to that public key.
- Negative test with an unrelated fresh keypair failed, as expected:
  arbitrary attackers cannot forge a signature that matches `cosign.pub`.
- Rendered via `helm template` offline from the local .tgz; no further
  calls to the registry — this is the air-gap property.

## Valid vs. legitimate

"Valid" signature = cryptographic check passes against the given public
key. "Legitimate" = the public key *itself* is the one we should trust.
In key-based cosign the whole security of the chain hinges on the channel
through which we obtained `cosign.pub`. If the attacker gave us *their*
`cosign.pub` and signed with *their* `cosign.key`, verify also passes —
and we deploy their chart.

In keyless cosign Fulcio binds the signature to an OIDC identity (the
workflow URL, the user's email, etc.) and Rekor logs it immutably. We
no longer trust a key file; we trust an identity ("only the workflow
`main.yml@refs/tags/*` in `myorg/myrepo` can sign") plus the OIDC issuer.
That shifts the question from "do I have the right file" to "is this
identity allowed to publish" — a question with a scalable answer in a
large org.
EOF
echo "   wrote REPORT.md"

echo
echo "DONE. tests/validate.sh should now pass."
