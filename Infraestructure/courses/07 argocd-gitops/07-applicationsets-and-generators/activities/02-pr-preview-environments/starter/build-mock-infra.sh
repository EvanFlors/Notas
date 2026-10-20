#!/usr/bin/env bash
# Build the mock PR infra for argo-07-02. Idempotent.
# Creates /tmp/argo-07-02/mock-repo/pulls/{101,102,103}.yaml.

set -e

BASE="${BASE:-/tmp/argo-07-02}"
REPO="$BASE/mock-repo"

rm -rf "$BASE"
mkdir -p "$REPO/pulls"
cd "$REPO"

git init -q -b main
git config user.email "dev@example.com"
git config user.name "Dev"

cat > pulls/101.yaml <<'EOF'
number: 101
branch: feat/add-login
head_sha: 1111111111111111111111111111111111111111
EOF

cat > pulls/102.yaml <<'EOF'
number: 102
branch: fix/null-check
head_sha: 2222222222222222222222222222222222222222
EOF

cat > pulls/103.yaml <<'EOF'
number: 103
branch: chore/bump-deps
head_sha: 3333333333333333333333333333333333333333
EOF

git add .
git commit -q -m "init: 3 mock PRs"

echo "OK: mock repo built at $REPO"
echo "Now write $BASE/appset-mock.yaml and $BASE/appset-github.yaml."
