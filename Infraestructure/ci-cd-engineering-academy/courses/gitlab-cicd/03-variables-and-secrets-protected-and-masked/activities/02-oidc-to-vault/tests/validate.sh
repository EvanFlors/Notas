#!/usr/bin/env bash
# Structural validation for gl-03-02-oidc-to-vault.
# Checks that .gitlab-ci.yml exists, parses as YAML, declares id_tokens +
# secrets correctly, has no long-lived Vault credentials, and that
# README-INTENT.md has the required sections and mentions.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness against a real Vault — compare
# manually with solution/.

set -eu

BASE="${1:-/tmp/gl-03-02}"
CI="$BASE/.gitlab-ci.yml"
DOC="$BASE/README-INTENT.md"
fail=0

echo "== Structural validation for $BASE =="

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: 'python3' is required but not installed."
  exit 2
fi

check_file_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
    return 0
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
    return 1
  fi
}

check_yaml_valid() {
  local f="$1"
  if python3 -c "import sys,yaml; yaml.safe_load(open('$f'))" >/dev/null 2>&1; then
    echo "  OK   $f is valid YAML"
    return 0
  else
    echo "  FAIL $f is not valid YAML"
    fail=$((fail+1))
    return 1
  fi
}

# --- .gitlab-ci.yml ------------------------------------------------------
if check_file_exists "$CI"; then
  check_yaml_valid "$CI" || true

  python3 - "$CI" <<'PY' > /tmp/gl-03-02-report.txt 2>&1 || true
import sys, yaml
try:
    doc = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print("PYERR", e); sys.exit(0)

if not isinstance(doc, dict):
    print("STRUCT_FAIL not a mapping"); sys.exit(0)

# Find a job named deploy-prod OR any job that satisfies the shape.
candidate = None
if "deploy-prod" in doc and isinstance(doc["deploy-prod"], dict):
    candidate = doc["deploy-prod"]
else:
    for k, v in doc.items():
        if k.startswith("."):  # hidden job
            continue
        if isinstance(v, dict) and "id_tokens" in v and "secrets" in v:
            candidate = v
            break

if candidate is None:
    print("NO_DEPLOY_PROD")
    sys.exit(0)

print("OK deploy-prod job present")

# environment: name: production
env = candidate.get("environment")
env_name = env.get("name") if isinstance(env, dict) else (env if isinstance(env, str) else None)
if env_name != "production":
    print(f"ENV_MISMATCH expected=production got={env_name!r}")
else:
    print("OK environment=production")

# rules referencing main
rules = candidate.get("rules") or []
rules_text = yaml.safe_dump(rules)
if 'main' not in rules_text:
    print("NO_MAIN_RULE")
else:
    print("OK rule mentions main")

# id_tokens block
idt = candidate.get("id_tokens")
if not isinstance(idt, dict) or not idt:
    print("NO_ID_TOKENS")
else:
    print(f"OK id_tokens entries: {list(idt.keys())}")
    good_aud = False
    for name, cfg in idt.items():
        if isinstance(cfg, dict):
            aud = cfg.get("aud", "")
            if isinstance(aud, list):
                aud_s = ",".join(str(a) for a in aud)
            else:
                aud_s = str(aud)
            if aud_s.startswith("https://vault") or "vault" in aud_s.lower():
                good_aud = True
    if good_aud:
        print("OK id_tokens aud points at vault")
    else:
        print("NO_VAULT_AUD")

# secrets block
sec = candidate.get("secrets")
if not isinstance(sec, dict) or not sec:
    print("NO_SECRETS")
else:
    print(f"OK secrets entries: {list(sec.keys())}")
    file_true = 0
    file_false = 0
    vault_count = 0
    for name, cfg in sec.items():
        if not isinstance(cfg, dict):
            continue
        if "vault" in cfg:
            vault_count += 1
        f = cfg.get("file")
        if f is True:
            file_true += 1
        elif f is False:
            file_false += 1
    if vault_count >= 2:
        print(f"OK secrets with vault: {vault_count}")
    else:
        print(f"FEW_VAULT_SECRETS {vault_count}")
    if file_true >= 1:
        print("OK at least one secret with file: true")
    else:
        print("NO_FILE_TRUE")
    if file_false >= 1:
        print("OK at least one secret with file: false")
    else:
        print("NO_FILE_FALSE")

# Forbid long-lived Vault credentials in the YAML.
raw = open(sys.argv[1]).read()
forbidden = ["VAULT_TOKEN", "VAULT_ROLE_ID", "VAULT_SECRET_ID"]
hits = [f for f in forbidden if f in raw]
if hits:
    print(f"FORBIDDEN {hits}")
else:
    print("OK no long-lived Vault credentials in YAML")
PY

  while IFS= read -r line; do
    case "$line" in
      "OK "*) echo "  OK   .gitlab-ci.yml: ${line#OK }" ;;
      "NO_DEPLOY_PROD") echo "  FAIL .gitlab-ci.yml missing 'deploy-prod' job (or any job with id_tokens+secrets)"; fail=$((fail+1)) ;;
      "ENV_MISMATCH "*) echo "  FAIL .gitlab-ci.yml environment: ${line#ENV_MISMATCH }"; fail=$((fail+1)) ;;
      "NO_MAIN_RULE") echo "  FAIL .gitlab-ci.yml rules do not reference 'main'"; fail=$((fail+1)) ;;
      "NO_ID_TOKENS") echo "  FAIL .gitlab-ci.yml job missing id_tokens block"; fail=$((fail+1)) ;;
      "NO_VAULT_AUD") echo "  FAIL .gitlab-ci.yml id_tokens aud does not point at vault"; fail=$((fail+1)) ;;
      "NO_SECRETS") echo "  FAIL .gitlab-ci.yml job missing secrets block"; fail=$((fail+1)) ;;
      "FEW_VAULT_SECRETS "*) echo "  FAIL .gitlab-ci.yml needs >=2 vault secrets (found ${line#FEW_VAULT_SECRETS })"; fail=$((fail+1)) ;;
      "NO_FILE_TRUE") echo "  FAIL .gitlab-ci.yml needs at least one secret with file: true"; fail=$((fail+1)) ;;
      "NO_FILE_FALSE") echo "  FAIL .gitlab-ci.yml needs at least one secret with file: false"; fail=$((fail+1)) ;;
      "FORBIDDEN "*) echo "  FAIL .gitlab-ci.yml contains long-lived Vault credentials: ${line#FORBIDDEN }"; fail=$((fail+1)) ;;
      "STRUCT_FAIL"*) echo "  FAIL .gitlab-ci.yml structural: $line"; fail=$((fail+1)) ;;
      "PYERR"*) echo "  FAIL .gitlab-ci.yml parser error: $line"; fail=$((fail+1)) ;;
    esac
  done < /tmp/gl-03-02-report.txt
fi

# --- README-INTENT.md ----------------------------------------------------
if check_file_exists "$DOC"; then
  # Title mentions OIDC or ID Token
  if grep -qiE 'OIDC|ID +Token' "$DOC"; then
    echo "  OK   README-INTENT.md title/body mentions OIDC or ID Token"
  else
    echo "  FAIL README-INTENT.md does not mention OIDC / ID Token"
    fail=$((fail+1))
  fi

  for section in "Antes" "Despues|Después" "Pinning|Claims|claims"; do
    label="${section%%|*}"
    if grep -qiE "^#+ +(${section})" "$DOC"; then
      echo "  OK   README-INTENT.md has '${label}' section"
    else
      echo "  FAIL README-INTENT.md missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  for term in "project_path" "ref_protected" "HashiCorp Vault" "GitLab"; do
    if grep -q "$term" "$DOC"; then
      echo "  OK   README-INTENT.md mentions '$term'"
    else
      echo "  FAIL README-INTENT.md does not mention '$term'"
      fail=$((fail+1))
    fi
  done

  # Must contain a 'ref' claim mention (standalone 'ref' between word boundaries).
  if grep -qE '(^|[^a-zA-Z_])ref($|[^a-zA-Z_0-9])' "$DOC"; then
    echo "  OK   README-INTENT.md mentions 'ref' claim"
  else
    echo "  FAIL README-INTENT.md does not mention 'ref' claim"
    fail=$((fail+1))
  fi

  # Must contain a dummy / no-real-secrets disclaimer.
  if grep -qiE 'dummy|no +hay +(credenciales|secretos) +reales|no +real +secrets|placeholder' "$DOC"; then
    echo "  OK   README-INTENT.md declares no-real-secrets (dummy)"
  else
    echo "  FAIL README-INTENT.md missing no-real-secrets disclaimer"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) found."
  echo "        (Semantic correctness against a real Vault is NOT verified here.)"
  exit 1
fi
echo "RESULT: 0 issue(s). Estructura valida. Compara con solution/ para autoevaluacion."
exit 0
