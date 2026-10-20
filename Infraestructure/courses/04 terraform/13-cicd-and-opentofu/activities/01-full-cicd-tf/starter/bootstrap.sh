#!/usr/bin/env bash
# Scaffolding for tf-13-01-full-cicd-tf.
# NOTE: avoid `set -o pipefail` globally — downstream `grep -q` producers can
# raise SIGPIPE and would be misreported. We check exit codes explicitly.
set -eu

BASE="${1:-/tmp/tf-cicd}"
rm -rf "$BASE"
mkdir -p \
  "$BASE/project/.github/workflows" \
  "$BASE/project/terraform" \
  "$BASE/project/trust-policies" \
  "$BASE/project/docs"

cat > "$BASE/project/README.md" <<'EOF'
# Full Terraform CI/CD pipeline — starter (tf-13-01)

Tareas:
1. Rellenar `terraform/versions.tf` y `terraform/.terraform.lock.hcl`.
2. Rellenar `.github/workflows/tf-plan.yml`, `tf-apply.yml`, `tf-drift.yml`.
3. Rellenar `trust-policies/plan.json` y `trust-policies/apply.json`.
4. Rellenar `docs/pipeline.md`.

Validar:
  bash tests/validate.sh /tmp/tf-cicd
EOF

# Empty stubs so the student sees the expected shape.
: > "$BASE/project/terraform/versions.tf"
: > "$BASE/project/terraform/.terraform.lock.hcl"
: > "$BASE/project/.github/workflows/tf-plan.yml"
: > "$BASE/project/.github/workflows/tf-apply.yml"
: > "$BASE/project/.github/workflows/tf-drift.yml"
: > "$BASE/project/trust-policies/plan.json"
: > "$BASE/project/trust-policies/apply.json"
: > "$BASE/project/docs/pipeline.md"

echo "Scaffolding ready at $BASE/project/"
find "$BASE/project" -type f | sort
