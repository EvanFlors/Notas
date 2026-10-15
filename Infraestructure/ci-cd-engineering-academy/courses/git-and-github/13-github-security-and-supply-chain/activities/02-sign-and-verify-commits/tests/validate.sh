#!/usr/bin/env bash
# Validator for gh-13-02-sign-and-verify-commits.
#
# NOTE: deliberately NOT using `set -o pipefail` because many checks pipe
# long-producing git commands into grep, which can emit SIGPIPE (exit 141)
# and would be flagged spuriously.

BASE="${1:-${BASE_DIR:-/tmp/sign-and-verify}}"
REPO="$BASE/repo"
KEY="$BASE/keys/signing_ed25519"
ALLOWED="$BASE/config/allowed_signers"

pass=0
fail=0
report=""

ok()   { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad()  { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating SSH-signed commits under $BASE =="

# Check 1: Signing key present
if [ -f "$KEY" ] && [ -f "${KEY}.pub" ]; then
  ok "signing key present ($KEY + .pub)"
else
  bad "missing signing key at $KEY (and/or .pub). Generate with: ssh-keygen -t ed25519 -N '' -f $KEY"
fi

# Check 2: Key is ed25519
if [ -f "${KEY}.pub" ]; then
  if head -c 11 "${KEY}.pub" | grep -q '^ssh-ed25519'; then
    ok "signing key is ssh-ed25519"
  else
    bad "signing key at ${KEY}.pub is not ssh-ed25519"
  fi
fi

# Check 3: repo exists
if [ ! -d "$REPO/.git" ]; then
  bad "repo missing at $REPO (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
else
  ok "repo exists at $REPO"
fi

cd "$REPO"

# Check 4: gpg.format = ssh
fmt="$(git config --get gpg.format 2>/dev/null || true)"
if [ "$fmt" = "ssh" ]; then
  ok "git config gpg.format = ssh"
else
  bad "git config gpg.format should be 'ssh' (got '$fmt')"
fi

# Check 5: commit.gpgsign = true
gpgsign="$(git config --get commit.gpgsign 2>/dev/null || true)"
if [ "$gpgsign" = "true" ]; then
  ok "git config commit.gpgsign = true"
else
  bad "git config commit.gpgsign should be 'true' (got '$gpgsign')"
fi

# Check 6: user.signingkey points to the pub key
sk="$(git config --get user.signingkey 2>/dev/null || true)"
if [ "$sk" = "${KEY}.pub" ] || [ "$sk" = "$KEY.pub" ]; then
  ok "git config user.signingkey = ${KEY}.pub"
else
  bad "git config user.signingkey should be '${KEY}.pub' (got '$sk')"
fi

# Check 7: gpg.ssh.allowedSignersFile is set
asf="$(git config --get gpg.ssh.allowedSignersFile 2>/dev/null || true)"
if [ "$asf" = "$ALLOWED" ]; then
  ok "git config gpg.ssh.allowedSignersFile = $ALLOWED"
else
  bad "git config gpg.ssh.allowedSignersFile should be '$ALLOWED' (got '$asf')"
fi

# Check 8: allowed_signers exists and has the pub key for the configured email
email="$(git config --get user.email 2>/dev/null || true)"
if [ -z "$email" ]; then
  bad "git config user.email not set"
elif [ ! -f "$ALLOWED" ]; then
  bad "allowed_signers file missing at $ALLOWED"
else
  if [ -f "${KEY}.pub" ]; then
    # Expected line format: '<email> ssh-ed25519 AAAA... comment'
    pub_key_body="$(awk '{print $2}' "${KEY}.pub")"
    if grep -qF "$email" "$ALLOWED" && grep -qF "$pub_key_body" "$ALLOWED"; then
      ok "allowed_signers has $email mapped to the signing key"
    else
      bad "allowed_signers must contain a line with '$email' and the pubkey body"
    fi
  fi
fi

# Check 9: at least 2 commits signed and verifiable
# We rely on `git verify-commit`, which uses allowedSignersFile.
signed_count=0
total=0
# Iterate commits on main, newest first; cap at 10.
while IFS= read -r h; do
  [ -z "$h" ] && continue
  total=$((total+1))
  if git verify-commit "$h" >/dev/null 2>&1; then
    signed_count=$((signed_count+1))
  fi
  [ $total -ge 10 ] && break
done < <(git log main --format='%H' 2>/dev/null || true)

if [ "$signed_count" -ge 2 ]; then
  ok "at least 2 commits in main pass git verify-commit (found $signed_count of $total examined)"
else
  bad "fewer than 2 verifiable signed commits in main (verified $signed_count / examined $total). Ensure commit.gpgsign=true and recreate commits."
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
