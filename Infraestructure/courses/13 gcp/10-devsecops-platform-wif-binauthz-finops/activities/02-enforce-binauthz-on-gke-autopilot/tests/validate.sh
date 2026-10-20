#!/usr/bin/env bash
# Structural validation for gcp-10-02-enforce-binauthz-on-gke-autopilot.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/gcp-10-02-binauthz}"
POLICY="$BASE/binauthz-policy.yaml"
ATTESTOR="$BASE/attestor.yaml"
TF="$BASE/terraform/binauthz.tf"
ADR="$BASE/ADR-BINAUTHZ-ROLLOUT.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required"
  exit 2
fi

run_yaml_check() {
  local file="$1"
  local expr="$2"
  local label="$3"
  if python3 - "$file" "$expr" "$label" <<'PY'
import sys, yaml
path, expr, label = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    docs = list(yaml.safe_load_all(open(path)))
except Exception as e:
    print(f"  FAIL {path}: YAML parse error: {e}")
    sys.exit(1)
docs = [x for x in docs if x is not None]
if not docs:
    print(f"  FAIL {path}: empty / no YAML docs")
    sys.exit(1)
d = docs[0]
try:
    val = eval(expr, {"d": d, "docs": docs, "any": any, "all": all, "len": len, "isinstance": isinstance, "dict": dict, "list": list})
except Exception as e:
    print(f"  FAIL {path}: expression error ({label}): {e}")
    sys.exit(1)
if val:
    print(f"  OK   {path}: {label}")
    sys.exit(0)
else:
    print(f"  FAIL {path}: {label}")
    sys.exit(1)
PY
  then
    :
  else
    fail=$((fail+1))
  fi
}

# --- binauthz-policy.yaml ------------------------------------------------
if [ ! -f "$POLICY" ]; then
  echo "  FAIL $POLICY does not exist"
  fail=$((fail+1))
else
  echo "  OK   $POLICY exists"

  run_yaml_check "$POLICY" "'defaultAdmissionRule' in d" "has defaultAdmissionRule"
  run_yaml_check "$POLICY" "d.get('defaultAdmissionRule',{}).get('evaluationMode') == 'ALWAYS_DENY'" "defaultAdmissionRule.evaluationMode == ALWAYS_DENY"
  run_yaml_check "$POLICY" "d.get('defaultAdmissionRule',{}).get('enforcementMode') in ('ENFORCED_BLOCK_AND_AUDIT_LOG','DRYRUN_AUDIT_LOG_ONLY')" "defaultAdmissionRule.enforcementMode is ENFORCED or DRYRUN"
  run_yaml_check "$POLICY" "isinstance(d.get('clusterAdmissionRules'), dict) and len(d['clusterAdmissionRules']) >= 1" "has >=1 clusterAdmissionRules"
  run_yaml_check "$POLICY" "any(r.get('evaluationMode') == 'REQUIRE_ATTESTATION' for r in d.get('clusterAdmissionRules',{}).values())" "at least one clusterAdmissionRule REQUIRE_ATTESTATION"
  run_yaml_check "$POLICY" "any(len(r.get('requireAttestationsBy',[])) >= 1 for r in d.get('clusterAdmissionRules',{}).values())" "clusterAdmissionRule references >=1 attestor in requireAttestationsBy"
  run_yaml_check "$POLICY" "isinstance(d.get('admissionWhitelistPatterns'), list) and len(d['admissionWhitelistPatterns']) >= 2" "has >=2 admissionWhitelistPatterns"
  run_yaml_check "$POLICY" "any('gke-release' in p.get('namePattern','') for p in d.get('admissionWhitelistPatterns',[]))" "whitelist includes gke-release pattern"
fi

# --- attestor.yaml -------------------------------------------------------
if [ ! -f "$ATTESTOR" ]; then
  echo "  FAIL $ATTESTOR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $ATTESTOR exists"

  python3 - "$ATTESTOR" <<'PY' || fail=$((fail+1))
import sys, yaml
path = sys.argv[1]
try:
    docs = [d for d in yaml.safe_load_all(open(path)) if d is not None]
except Exception as e:
    print(f"  FAIL attestor YAML parse error: {e}")
    sys.exit(1)

def flatten(obj):
    """Yield all dicts seen under obj (recursively)."""
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from flatten(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from flatten(v)

all_dicts = []
for d in docs:
    all_dicts.extend(flatten(d))

# Find a dict with attestationAuthorityNote (either direct or nested).
has_auth_note = any('attestationAuthorityNote' in d for d in all_dicts)
if not has_auth_note:
    print("  FAIL attestor missing attestationAuthorityNote")
    sys.exit(1)
print("  OK   attestor has attestationAuthorityNote")

note_refs = [d['attestationAuthorityNote'].get('noteReference')
             for d in all_dicts if 'attestationAuthorityNote' in d]
if any(nr for nr in note_refs):
    print("  OK   attestor has noteReference")
else:
    print("  FAIL attestor missing noteReference")
    sys.exit(1)

# Must have a publicKeys entry with pkixPublicKey.publicKeyPem.
found_pem = False
for d in all_dicts:
    pks = d.get('publicKeys') if isinstance(d.get('publicKeys'), list) else None
    if pks:
        for pk in pks:
            pkix = pk.get('pkixPublicKey', {}) if isinstance(pk, dict) else {}
            pem = pkix.get('publicKeyPem', '')
            if pem and 'BEGIN PUBLIC KEY' in pem:
                found_pem = True
                break
if found_pem:
    print("  OK   attestor has pkixPublicKey.publicKeyPem (PEM-shaped)")
else:
    print("  FAIL attestor missing pkixPublicKey.publicKeyPem with a PEM-shaped value")
    sys.exit(1)

# signatureAlgorithm present somewhere
found_sig = any(
    isinstance(pk, dict) and pk.get('pkixPublicKey', {}).get('signatureAlgorithm')
    for d in all_dicts
    for pk in (d.get('publicKeys') or [])
    if isinstance(d.get('publicKeys'), list)
)
if found_sig:
    print("  OK   attestor declares signatureAlgorithm")
else:
    print("  FAIL attestor does not declare signatureAlgorithm")
    sys.exit(1)
PY
fi

# --- terraform/binauthz.tf ----------------------------------------------
if [ ! -f "$TF" ]; then
  echo "  FAIL $TF does not exist"
  fail=$((fail+1))
else
  echo "  OK   $TF exists"
  for res in \
      "google_binary_authorization_policy" \
      "google_binary_authorization_attestor" \
      "google_container_analysis_note"; do
    if grep -qE "resource +\"${res}\"" "$TF"; then
      echo "  OK   TF declares resource ${res}"
    else
      echo "  FAIL TF missing resource ${res}"
      fail=$((fail+1))
    fi
  done

  if grep -qE 'enable_binary_authorization|binary_authorization[[:space:]]*{' "$TF"; then
    echo "  OK   TF references cluster-level binary_authorization setting"
  else
    echo "  FAIL TF does not reference cluster-level binary_authorization setting"
    fail=$((fail+1))
  fi
fi

# --- ADR -----------------------------------------------------------------
if [ ! -f "$ADR" ]; then
  echo "  FAIL $ADR does not exist"
  fail=$((fail+1))
else
  echo "  OK   $ADR exists"

  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR has 'ADR' heading"
  else
    echo "  FAIL ADR missing 'ADR' heading"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  if grep -qiE 'Binary +Authorization|Binauthz' "$ADR"; then
    echo "  OK   ADR mentions Binary Authorization / Binauthz"
  else
    echo "  FAIL ADR missing Binary Authorization / Binauthz"
    fail=$((fail+1))
  fi

  if grep -qiE 'GKE +Autopilot' "$ADR"; then
    echo "  OK   ADR mentions GKE Autopilot"
  else
    echo "  FAIL ADR missing GKE Autopilot"
    fail=$((fail+1))
  fi

  if grep -qiE 'cosign|Sigstore' "$ADR"; then
    echo "  OK   ADR mentions cosign / Sigstore"
  else
    echo "  FAIL ADR missing cosign / Sigstore"
    fail=$((fail+1))
  fi

  if grep -qi 'DRYRUN' "$ADR" && grep -qi 'ENFORCED' "$ADR"; then
    echo "  OK   ADR mentions DRYRUN and ENFORCED rollout"
  else
    echo "  FAIL ADR must mention both DRYRUN and ENFORCED (rollout plan)"
    fail=$((fail+1))
  fi

  if grep -qi 'admissionWhitelistPatterns' "$ADR"; then
    echo "  OK   ADR mentions admissionWhitelistPatterns"
  else
    echo "  FAIL ADR missing admissionWhitelistPatterns justification"
    fail=$((fail+1))
  fi

  if grep -qiE 'continuousValidation|continuous +validation' "$ADR"; then
    echo "  OK   ADR mentions continuous validation"
  else
    echo "  FAIL ADR missing continuous validation"
    fail=$((fail+1))
  fi

  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  alt_num=$(grep -cE '^[[:space:]]*[12]\. ' "$ADR" || true)
  if [ "$alt_items" -ge 2 ] || [ "$alt_num" -ge 2 ]; then
    echo "  OK   ADR lists >= 2 alternatives"
  else
    echo "  FAIL ADR lists < 2 alternatives"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Not verified against a real GKE cluster.)"
  exit 1
fi
echo "OK: estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
