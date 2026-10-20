#!/usr/bin/env bash
# Scaffolding for gha-11-02-review-vulnerable-trust-policy.
# NOTE: no `set -o pipefail` with grep -q producers (SIGPIPE false positives).
set -eu

BASE="${1:-/tmp/gha-oidc-audit}"
rm -rf "$BASE"
mkdir -p "$BASE/project/vulnerable" "$BASE/project/fixes"

# --- Vulnerable 1: pin solo al owner (StringLike con wildcard al repo) ---
cat > "$BASE/project/vulnerable/trust-policy-1.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AdminProdFromAnyRepoOfOrg",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/*"
        }
      }
    }
  ]
}
JSON

# --- Vulnerable 2: StringLike con wildcard al final del sub ---
cat > "$BASE/project/vulnerable/trust-policy-2.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReleaseTaggerTooBroad",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:*"
        }
      }
    }
  ]
}
JSON

# --- Vulnerable 3: solo verifica aud (cross-tenant) ---
cat > "$BASE/project/vulnerable/trust-policy-3.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CIReadAudOnly",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
JSON

# --- Vulnerable 4: SAFE_BUT_WEAK — pin a ref:refs/heads/main cuando el equipo
# usa environments con approvals; además wildcard sutil en el environment. ---
cat > "$BASE/project/vulnerable/trust-policy-4.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StagingLooseEnvironment",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:*"
        }
      }
    }
  ]
}
JSON

cat > "$BASE/project/README.md" <<'EOF'
# Audit vulnerable trust policies — starter (gha-11-02)

Entrada: `vulnerable/trust-policy-{1,2,3,4}.json`.
Salida esperada: `fixes/trust-policy-{1,2,3,4}.json` + `audit.md`.

Ver instrucciones completas en el README de la actividad.

Validar:
  bash tests/validate.sh /tmp/gha-oidc-audit
EOF

echo "Scaffolding listo en $BASE/project/"
ls -R "$BASE/project"
