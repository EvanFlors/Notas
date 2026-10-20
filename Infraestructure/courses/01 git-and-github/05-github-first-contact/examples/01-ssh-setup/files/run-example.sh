#!/usr/bin/env bash
# Generate a demo ed25519 key pair in /tmp/ssh-demo/ and inspect it.
# Does NOT upload anything to GitHub. Does NOT touch ~/.ssh/.
set -euo pipefail

DIR="${1:-/tmp/ssh-demo}"
rm -rf "$DIR"
mkdir -p "$DIR"
chmod 700 "$DIR"

KEY="$DIR/id_ed25519_demo"

echo "== 1. Generate ed25519 key pair (no passphrase, for demo only) =="
ssh-keygen -t ed25519 -C "demo-key for gh-05" -f "$KEY" -N "" >/dev/null

echo
echo "== 2. Files produced =="
ls -l "$KEY" "$KEY.pub"

echo
echo "== 3. Permissions (private MUST be 600) =="
stat -f '%A %N' "$KEY" "$KEY.pub" 2>/dev/null || stat -c '%a %n' "$KEY" "$KEY.pub"

echo
echo "== 4. Public key (this is what you'd paste at https://github.com/settings/keys) =="
cat "$KEY.pub"

echo
echo "== 5. Private key fingerprint (do NOT share the private file itself) =="
ssh-keygen -lf "$KEY"

echo
echo "== 6. Would-be test (commented, needs real GitHub + uploaded pub) =="
echo "    ssh -i $KEY -T git@github.com"
echo
echo "Done. Clean up with:  rm -rf $DIR"
