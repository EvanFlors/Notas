#!/usr/bin/env bash
# Reference solution for tf-13-01-full-cicd-tf.
# NOTE: do NOT enable `set -o pipefail` — downstream `grep -q` producers can
# produce SIGPIPE that pipefail would flag as a failure.
set -eu

BASE="${1:-/tmp/tf-cicd}"
P="$BASE/project"
if [ ! -d "$P" ]; then
  echo "FAIL: $P not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

# --- terraform/versions.tf ---
cat > "$P/terraform/versions.tf" <<'HCL'
terraform {
  required_version = "~> 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
HCL

# --- terraform/.terraform.lock.hcl (stub committed by TF after init) ---
cat > "$P/terraform/.terraform.lock.hcl" <<'HCL'
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.60.0"
  constraints = "~> 5.60"
  hashes = [
    "h1:0000000000000000000000000000000000000000000=",
  ]
}
HCL

# --- .github/workflows/tf-plan.yml ---
cat > "$P/.github/workflows/tf-plan.yml" <<'YAML'
name: terraform-plan
on:
  pull_request:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/tf-plan.yml"

permissions: {}

concurrency:
  group: tf-plan-${{ github.ref }}
  cancel-in-progress: true

jobs:
  plan:
    name: fmt + validate + plan (read-only)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd  # v3.1.2
        with:
          terraform_version: 1.9.5
          terraform_wrapper: false
      - run: terraform fmt -check -recursive
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/terraform-plan-ro
          role-session-name: tf-plan-${{ github.run_id }}
          aws-region: eu-west-1
      - run: terraform init -input=false -lockfile=readonly
      - run: terraform validate -no-color
      - name: plan
        id: plan
        run: terraform plan -input=false -no-color -out=plan.tfplan
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874  # v4.4.0
        with:
          name: tfplan-${{ github.event.pull_request.number }}
          path: terraform/plan.tfplan
          retention-days: 5
          if-no-files-found: error
      - uses: marocchino/sticky-pull-request-comment@331f8f5b4215f0445d3c07b4967662a32a2d3e31  # v2.9.0
        with:
          header: terraform-plan
          message: |
            Plan uploaded as artifact `tfplan-${{ github.event.pull_request.number }}`.
YAML

# --- .github/workflows/tf-apply.yml ---
cat > "$P/.github/workflows/tf-apply.yml" <<'YAML'
name: terraform-apply
on:
  push:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/tf-apply.yml"

permissions: {}

concurrency:
  group: tf-apply-main
  cancel-in-progress: false

jobs:
  apply:
    name: Apply saved plan
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    environment:
      name: production
    permissions:
      id-token: write
      contents: read
      actions: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd  # v3.1.2
        with:
          terraform_version: 1.9.5
          terraform_wrapper: false
      - uses: dawidd6/action-download-artifact@bf251b5aa9c2f7eeb574a96ee720e24f801b7c11  # v6
        with:
          workflow: tf-plan.yml
          name_is_regexp: true
          name: ^tfplan-.*$
          path: terraform/
          if_no_artifact_found: fail
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/terraform-apply-prod
          role-session-name: tf-apply-${{ github.run_id }}
          aws-region: eu-west-1
      - run: terraform init -input=false -lockfile=readonly
      # NOTE: no -auto-approve; we apply the EXACT plan reviewed on the PR.
      - run: terraform apply -input=false plan.tfplan
YAML

# --- .github/workflows/tf-drift.yml ---
cat > "$P/.github/workflows/tf-drift.yml" <<'YAML'
name: terraform-drift
on:
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch: {}

permissions: {}

jobs:
  drift:
    name: Scheduled drift (refresh-only)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    permissions:
      id-token: write
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          ref: main
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd  # v3.1.2
        with:
          terraform_version: 1.9.5
          terraform_wrapper: false
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/terraform-plan-ro
          role-session-name: tf-drift-${{ github.run_id }}
          aws-region: eu-west-1
      - run: terraform init -input=false -lockfile=readonly
      - id: drift
        run: |
          set +e
          terraform plan -refresh-only -detailed-exitcode -no-color -out=drift.tfplan
          echo "exitcode=$?" >> "$GITHUB_OUTPUT"
      - if: steps.drift.outputs.exitcode == '2'
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner, repo: context.repo.repo,
              title: "Drift detected on prod",
              body: "Scheduled refresh-only plan returned exit=2. Run: " + context.runId,
              labels: ["drift", "infra"],
            });
YAML

# --- trust-policies/plan.json ---
cat > "$P/trust-policies/plan.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsPlanFromPRs",
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
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:pull_request"
        }
      }
    }
  ]
}
JSON

# --- trust-policies/apply.json ---
cat > "$P/trust-policies/apply.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsApplyFromProdEnv",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:production"
        }
      }
    }
  ]
}
JSON

# --- docs/pipeline.md ---
cat > "$P/docs/pipeline.md" <<'MD'
# Pipeline Terraform CI/CD

## Flujo

El pipeline tiene tres workflows. El de PR corre `fmt`, `validate` y
`terraform plan -out=plan.tfplan`, sube el `plan.tfplan` como artefacto y
publica el plan como comentario sticky. El de merge a `main` descarga ese
artefacto y ejecuta `terraform apply plan.tfplan` **sin recalcular el plan**;
el job está gated por un `environment: production` con required reviewers.
El de `schedule` corre `terraform plan -refresh-only -detailed-exitcode`
contra `main` y abre un issue si el exit code es 2 (drift detectado).

## Por qué el plan guardado se aplica tal cual

Entre `plan` y `apply` existe una ventana en la que el cloud puede cambiar.
Si el apply recalcula el plan antes de aplicar, puede ver un estado real
distinto al que vio el PR y aplicar un cambio diferente al revisado por el
humano. Es la clase **TOCTOU** (time-of-check vs time-of-use). Pasar el
`plan.tfplan` tal cual al `apply` elimina esa ventana: si el estado
divergió, `apply` falla ruidosamente en vez de inventar un cambio nuevo.

## Por qué dos roles OIDC

El job de plan asume `terraform-plan-ro`, un rol de solo lectura cuya trust
policy pinnea `sub` a `:pull_request`. El job de apply asume
`terraform-apply-prod`, un rol con permisos de mutación cuya trust pinnea
`sub` a `:environment:production`. Esta separación garantiza que un PR
malicioso no puede ejecutar `terraform apply` ni usar `local-exec` para
mutar nada en prod: aunque intente asumir el rol de apply, el `sub` del
JWT emitido por GitHub no incluirá `environment:production` sin el gate del
environment, y AWS rechaza el assume. Combinado con required reviewers del
environment, prod queda detrás de dos barreras independientes.

## Coherencia de versión

`required_version = "~> 1.9.0"` en `versions.tf`, lockfile
`.terraform.lock.hcl` versionado, y `setup-terraform` con
`terraform_version: 1.9.5` en los tres workflows. Las tres barreras evitan
que el `.tfplan` lo escriba una versión y lo lea otra incompatible.
MD

echo "Solution applied under $P/"
find "$P" -type f | sort
