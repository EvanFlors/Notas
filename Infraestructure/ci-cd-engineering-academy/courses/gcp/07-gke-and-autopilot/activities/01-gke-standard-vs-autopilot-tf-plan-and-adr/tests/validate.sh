#!/usr/bin/env bash
# Structural validation for gcp-07-01-gke-standard-vs-autopilot-tf-plan-and-adr.
# Checks:
#  - terraform/standard/main.tf and terraform/autopilot/main.tf exist with minimal blocks.
#  - If `terraform` CLI is installed, runs `init -backend=false` + `validate` in each module.
#  - ADR-GKE-MODE.md exists with the required ADR sections and content.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks use
# `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep finds a
# match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/gcp-07-01-gke-tf-adr}"
STD="$BASE/terraform/standard"
AP="$BASE/terraform/autopilot"
ADR="$BASE/ADR-GKE-MODE.md"
fail=0

echo "== Structural validation for $BASE =="

check_file() {
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

grep_in() {
  local f="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  OK   $f: $label"
  else
    echo "  FAIL $f: $label (regex: $pattern)"
    fail=$((fail+1))
  fi
}

no_grep_in() {
  local f="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "$f"; then
    echo "  FAIL $f: $label (regex: $pattern)"
    fail=$((fail+1))
  else
    echo "  OK   $f: $label"
  fi
}

# ---- Terraform Standard --------------------------------------------------
if check_file "$STD/main.tf"; then
  grep_in "$STD/main.tf" 'resource[[:space:]]+"google_container_cluster"' 'declares google_container_cluster'
  grep_in "$STD/main.tf" 'resource[[:space:]]+"google_container_node_pool"' 'declares google_container_node_pool (Standard requires it)'
  grep_in "$STD/main.tf" 'remove_default_node_pool[[:space:]]*=[[:space:]]*true' 'remove_default_node_pool = true'
  grep_in "$STD/main.tf" 'workload_identity_config' 'has workload_identity_config block'
  grep_in "$STD/main.tf" '\.svc\.id\.goog' 'workload_pool uses <project>.svc.id.goog'
  grep_in "$STD/main.tf" 'release_channel' 'has release_channel block'
  grep_in "$STD/main.tf" 'channel[[:space:]]*=[[:space:]]*"(RAPID|REGULAR|STABLE)"' 'release_channel.channel is RAPID|REGULAR|STABLE'
  grep_in "$STD/main.tf" 'private_cluster_config' 'has private_cluster_config block'
  grep_in "$STD/main.tf" 'enable_private_nodes[[:space:]]*=[[:space:]]*true' 'enable_private_nodes = true'
  grep_in "$STD/main.tf" '(datapath_provider[[:space:]]*=[[:space:]]*"ADVANCED_DATAPATH"|network_policy)' 'uses Dataplane V2 or network_policy'
  grep_in "$STD/main.tf" 'shielded_instance_config' 'declares shielded_instance_config in node_config'
  no_grep_in "$STD/main.tf" 'enable_autopilot[[:space:]]*=[[:space:]]*true' 'does NOT set enable_autopilot=true (that would be Autopilot)'
  # Placeholders only — no real-looking project IDs.
  no_grep_in "$STD/main.tf" '"[a-z][a-z0-9-]{30,}-[0-9a-f]{6,}"' 'no suspicious real-looking project IDs'
fi

# ---- Terraform Autopilot -------------------------------------------------
if check_file "$AP/main.tf"; then
  grep_in "$AP/main.tf" 'resource[[:space:]]+"google_container_cluster"' 'declares google_container_cluster'
  grep_in "$AP/main.tf" 'enable_autopilot[[:space:]]*=[[:space:]]*true' 'enable_autopilot = true'
  no_grep_in "$AP/main.tf" 'resource[[:space:]]+"google_container_node_pool"' 'does NOT declare google_container_node_pool (illegal in Autopilot)'
  grep_in "$AP/main.tf" 'workload_identity_config' 'has workload_identity_config block'
  grep_in "$AP/main.tf" '\.svc\.id\.goog' 'workload_pool uses <project>.svc.id.goog'
  grep_in "$AP/main.tf" 'release_channel' 'has release_channel block'
  grep_in "$AP/main.tf" 'channel[[:space:]]*=[[:space:]]*"(RAPID|REGULAR|STABLE)"' 'release_channel.channel is RAPID|REGULAR|STABLE'
  grep_in "$AP/main.tf" 'private_cluster_config' 'has private_cluster_config block'
  grep_in "$AP/main.tf" 'enable_private_nodes[[:space:]]*=[[:space:]]*true' 'enable_private_nodes = true'
fi

# ---- Optional: terraform validate ---------------------------------------
if command -v terraform >/dev/null 2>&1; then
  echo "  INFO terraform CLI detected — running init -backend=false + validate"
  # Share a plugin cache across both modules so we don't re-download the Google provider twice.
  export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
  mkdir -p "$TF_PLUGIN_CACHE_DIR"
  for mod in "$STD" "$AP"; do
    if [ -f "$mod/main.tf" ]; then
      (
        cd "$mod"
        if terraform init -backend=false -input=false -no-color >/dev/null 2>&1; then
          if terraform validate -no-color >/dev/null 2>&1; then
            echo "  OK   $mod: terraform validate passed"
          else
            echo "  FAIL $mod: terraform validate failed"
            # Re-run to show the error.
            terraform validate -no-color 2>&1 | sed 's/^/       /'
            exit 1
          fi
        else
          echo "  FAIL $mod: terraform init -backend=false failed"
          terraform init -backend=false -input=false -no-color 2>&1 | tail -20 | sed 's/^/       /'
          exit 1
        fi
      ) || fail=$((fail+1))
    fi
  done
else
  echo "  INFO terraform CLI not installed — skipping validate (content checks above still enforced)"
fi

# ---- ADR -----------------------------------------------------------------
if check_file "$ADR"; then
  if grep -qiE '^#+ *ADR' "$ADR"; then
    echo "  OK   ADR-GKE-MODE.md has an 'ADR' heading"
  else
    echo "  FAIL ADR-GKE-MODE.md missing an 'ADR' heading"
    fail=$((fail+1))
  fi

  for section in "Estado|Status" "Contexto|Context" "Decisi[oó]n|Decision" \
                 "Consecuencias|Consequences" "Alternativas|Alternatives"; do
    label="${section%%|*}"
    if grep -qiE "^#+ *(${section})\\b" "$ADR"; then
      echo "  OK   ADR has '${label}' section"
    else
      echo "  FAIL ADR missing '${label}' section"
      fail=$((fail+1))
    fi
  done

  # Content checks.
  if grep -qi 'checkout-api' "$ADR" && grep -qi 'training-jobs' "$ADR"; then
    echo "  OK   ADR names both workloads (checkout-api, training-jobs)"
  else
    echo "  FAIL ADR must name both workloads 'checkout-api' and 'training-jobs'"
    fail=$((fail+1))
  fi

  if grep -qiE 'autopilot' "$ADR" && grep -qiE 'standard' "$ADR" && grep -qiE 'EKS' "$ADR"; then
    echo "  OK   ADR compares Standard, Autopilot and EKS"
  else
    echo "  FAIL ADR must compare GKE Standard, Autopilot and EKS"
    fail=$((fail+1))
  fi

  if grep -qiE '(RAPID|REGULAR|STABLE)' "$ADR" && grep -qi 'release channel' "$ADR"; then
    echo "  OK   ADR mentions release channel (RAPID/REGULAR/STABLE)"
  else
    echo "  FAIL ADR must mention a release channel (RAPID/REGULAR/STABLE) explicitly"
    fail=$((fail+1))
  fi

  if grep -qiE 'Workload +Identity' "$ADR"; then
    echo "  OK   ADR mentions Workload Identity (Federation for GKE)"
  else
    echo "  FAIL ADR must mention Workload Identity (Federation for GKE)"
    fail=$((fail+1))
  fi

  if grep -qiE 'europ|europe-west|europe-central' "$ADR"; then
    echo "  OK   ADR mentions Europe / europe-* region"
  else
    echo "  FAIL ADR must mention Europe / europe-* region"
    fail=$((fail+1))
  fi

  # At least 2 alternatives subheadings.
  alt_items=$(grep -cEi '^#+ +(Alt|Opci[oó]n|Alternativa)' "$ADR" || true)
  if [ "$alt_items" -ge 2 ]; then
    echo "  OK   ADR has at least 2 alternatives listed ($alt_items found)"
  else
    echo "  FAIL ADR has fewer than 2 alternatives (expected >=2 sub-headings)"
    fail=$((fail+1))
  fi

  # Must mention at least 2 Autopilot restrictions (hostPath, hostNetwork, DaemonSet, privileged, kube-system).
  restr_count=0
  for r in "hostPath" "hostNetwork" "hostPID" "DaemonSet" "privileged" "kube-system"; do
    if grep -qi "$r" "$ADR"; then
      restr_count=$((restr_count+1))
    fi
  done
  if [ "$restr_count" -ge 2 ]; then
    echo "  OK   ADR mentions at least 2 Autopilot restrictions ($restr_count found)"
  else
    echo "  FAIL ADR must mention at least 2 Autopilot restrictions (found $restr_count)"
    fail=$((fail+1))
  fi

  # No real-looking project IDs in the ADR either.
  if grep -qE '[a-z][a-z0-9-]{20,}-[0-9]{6,}' "$ADR"; then
    echo "  WARN ADR may contain a real-looking project ID — review manually"
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
