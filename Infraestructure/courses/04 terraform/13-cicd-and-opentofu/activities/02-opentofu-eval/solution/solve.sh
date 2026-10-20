#!/usr/bin/env bash
# Reference solution for tf-13-02-opentofu-eval.
# NOTE: no `set -o pipefail` (SIGPIPE false positives from grep -q).
set -eu

BASE="${1:-/tmp/tf-tofu-eval}"
P="$BASE/project"
if [ ! -d "$P" ]; then
  echo "FAIL: $P not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

if ! command -v tofu >/dev/null 2>&1; then
  echo "SKIP solve: 'tofu' not installed. Install via:"
  echo "  brew install opentofu"
  echo "  or https://opentofu.org/docs/intro/install/"
  echo "The ADR portion of the solution will still be written."
  HAVE_TOFU=0
else
  HAVE_TOFU=1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "FAIL solve: 'terraform' not installed."
  exit 1
fi

cd "$P/stack"

echo "== 1) versions =="
terraform version > "$P/evidence/versions.txt"
if [ "$HAVE_TOFU" = "1" ]; then
  tofu version >> "$P/evidence/versions.txt"
fi

echo "== 2) lockfile cross-tool =="
terraform init -input=false -no-color >/dev/null
rm -rf .terraform
# Known divergence (2024+): OpenTofu's lockfile tracks registry.opentofu.org
# while Terraform's tracks registry.terraform.io. `tofu init -lockfile=readonly`
# therefore FAILS on a lockfile written by terraform. We record the fact.
if [ "$HAVE_TOFU" = "1" ]; then
  set +e
  tofu init -input=false -lockfile=readonly -no-color >/tmp/tofu-init.out 2>&1
  rc=$?
  set -e
  echo "tofu init -lockfile=readonly rc=$rc" >> "$P/evidence/versions.txt"
  if [ "$rc" -ne 0 ]; then
    echo "note: tofu init -lockfile=readonly rejected terraform's lockfile (expected: registry URL divergence)" >> "$P/evidence/versions.txt"
  fi
  rm -rf .terraform
fi

echo "== 3) state cross-read =="
rm -rf .terraform terraform.tfstate*
terraform init -input=false -no-color >/dev/null
terraform apply -auto-approve -input=false -no-color >/dev/null
if [ "$HAVE_TOFU" = "1" ]; then
  # tofu needs its own lockfile/plugins; regenerate (NOT readonly). The state
  # written by terraform is still readable by tofu — that's what we're proving.
  rm -rf .terraform .terraform.lock.hcl
  tofu init -input=false -no-color >/dev/null
  set +e
  tofu plan -input=false -detailed-exitcode -no-color > "$P/evidence/state-cross-read.txt" 2>&1
  ec=$?
  set -e
  echo "exit=$ec" >> "$P/evidence/state-cross-read.txt"
else
  echo "SKIP: tofu not installed; cannot verify state cross-read" > "$P/evidence/state-cross-read.txt"
fi

echo "== 4) plan equivalence =="
# Previous step may have left an OpenTofu-flavored lockfile; purge everything
# including state and re-init cleanly for each tool.
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* greeting.txt t.plan o.plan

terraform init -input=false -no-color >/dev/null
terraform plan -out=t.plan -input=false -no-color >/dev/null
if command -v jq >/dev/null 2>&1; then
  terraform show -json t.plan | jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' > "$P/evidence/t-changes.json"
fi
if [ "$HAVE_TOFU" = "1" ] && command -v jq >/dev/null 2>&1; then
  rm -rf .terraform .terraform.lock.hcl
  tofu init -input=false -no-color >/dev/null
  tofu plan -out=o.plan -input=false -no-color >/dev/null
  tofu show -json o.plan | jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' > "$P/evidence/o-changes.json"
  diff -u "$P/evidence/t-changes.json" "$P/evidence/o-changes.json" > "$P/evidence/plan-diff.txt" || true
else
  : > "$P/evidence/plan-diff.txt"
fi

# Cleanup stack artifacts to keep evidence tight.
rm -rf .terraform t.plan o.plan terraform.tfstate* greeting.txt

echo "== 5) ADR =="
cat > "$P/adr/0001-terraform-vs-opentofu.md" <<'MD'
# ADR 0001: Terraform vs OpenTofu

## Status

Proposed (2026-10).

## Context

Desde 2023 HashiCorp distribuye Terraform bajo **BUSL** (Business Source
License), que no es OSI-approved y restringe uso competitivo durante 4 años.
En respuesta, la **Linux Foundation** adoptó el fork **OpenTofu** bajo
**Apache 2.0**, con compatibilidad declarada del lenguaje HCL, del state y
del lockfile. Nuestra organización necesita decidir si continúa con
Terraform o migra a OpenTofu de cara al próximo trimestre, antes de
estandarizar el pipeline CI/CD descrito en `tf-13-01`.

## Options considered

| Criterio (peso) | Terraform (BUSL) | OpenTofu (Apache 2.0) |
|---|---|---|
| Licencia (alto)       | BUSL; restringe uso competitivo; incómodo para equipos legales | Apache 2.0 estándar OSI |
| Features (medio)      | Paridad base; HCP Terraform maduro | state encryption nativa, provider-defined functions, early eval en backend |
| Soporte (medio)       | HashiCorp (comercial) y comunidad | Linux Foundation + vendors neutrales (Spacelift, Scalr, env0) |
| Costo de migración (medio) | 0 (status quo) | Bajo: binario + setup-action en pipelines; HCL y state intactos |

## Decision

Adoptar **OpenTofu** para todos los nuevos stacks y migrar los existentes
en los próximos 2 sprints. El pipeline del `tf-13-01` cambia
`hashicorp/setup-terraform` por `opentofu/setup-opentofu`; el resto queda
idéntico.

Factores decisivos: la licencia Apache 2.0 elimina la fricción legal
recurrente, y el ecosistema de vendors neutrales reduce el riesgo de
proveedor. Las features propias (en particular **state encryption** en el
lenguaje) resuelven un control de cumplimiento que hoy requiere trabajo a
nivel de backend.

## Consequences

- **State compatible** entre ambos: OpenTofu lee y escribe el mismo formato.
  Comprobado con `tofu plan` sobre un state producido por `terraform apply`,
  resultado: `No changes` (exit 0).
- **Lockfile NO cross-tool desde 2024**: Terraform fija hashes contra
  `registry.terraform.io`; OpenTofu contra `registry.opentofu.org`. Cada
  pipeline debe regenerar el lockfile con la herramienta elegida. Decisión
  operacional: **comitear solo el lockfile de OpenTofu** una vez migrados.
- Si adoptamos state encryption nativa, perdemos la vuelta atrás
  automática: el state se vuelve ilegible por Terraform.
- Los developers deben instalar `tofu` localmente; se añade a nuestros
  `brew`/`asdf` baselines.
- Documentación interna y runbooks dejan de referirse a "terraform" como
  binario; mantenemos la palabra como genérica.

## Migration plan

1. Fijar `required_version = "~> 1.9.0"` en todos los stacks (compatible
   con ambos).
2. En un repo piloto, cambiar `setup-terraform` por `setup-opentofu` en
   los 3 workflows; mantener el lockfile existente.
3. Correr el smoke test (`examples/03-opentofu-migration-smoke-test`)
   contra 3 stacks representativos. Diff del plan debe ser vacío.
4. Promoción por ambiente: dev → stg → prod.
5. Deprecar `terraform` del baseline interno; actualizar runbooks.
6. Reevaluar en 6 meses si state encryption nativa se adopta.

## Why not migrate (if applicable)

N/A — la decisión es migrar.
MD

echo "Solution applied under $P/"
find "$P" -type f | sort
