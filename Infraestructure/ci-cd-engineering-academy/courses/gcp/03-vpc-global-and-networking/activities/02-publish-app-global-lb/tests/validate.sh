#!/usr/bin/env bash
# Structural validation for gcp-03-02-publish-app-global-lb.
# Checks that variables.tf, lb.tf and ARCHITECTURE.md exist, and that lb.tf
# declares the 6 (+1 backend) obligatory pieces of a Global External HTTPS LB.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# This validator does NOT invoke terraform; it works offline.

set -eu

BASE="${1:-/tmp/gcp-03-global-lb}"
VARS="$BASE/variables.tf"
LB="$BASE/lb.tf"
ARCH="$BASE/ARCHITECTURE.md"
fail=0

echo "== Structural validation for $BASE =="

# --- variables.tf --------------------------------------------------------
if [ ! -f "$VARS" ]; then
  echo "FAIL: $VARS does not exist."
  fail=$((fail+1))
else
  echo "  OK   $VARS exists"
  if grep -qE '^[[:space:]]*variable[[:space:]]+"project_id"' "$VARS"; then
    echo "  OK   variables.tf declares 'project_id'"
  else
    echo "  FAIL variables.tf does not declare 'project_id'"
    fail=$((fail+1))
  fi
  # Must NOT contain a real-looking project ID; must contain a placeholder.
  if grep -qiE 'example-project|placeholder|REPLACE|CHANGE_ME' "$VARS"; then
    echo "  OK   variables.tf uses a placeholder for project_id"
  else
    echo "  FAIL variables.tf default for project_id does not look like a placeholder"
    fail=$((fail+1))
  fi
fi

# --- lb.tf: 6 pieces required ------------------------------------------
if [ ! -f "$LB" ]; then
  echo "FAIL: $LB does not exist."
  fail=$((fail+1))
else
  echo "  OK   $LB exists"

  check_resource() {
    local kind="$1"
    local label="$2"
    if grep -qE "^[[:space:]]*resource[[:space:]]+\"${kind}\"" "$LB"; then
      echo "  OK   lb.tf declares ${label} (${kind})"
    else
      echo "  FAIL lb.tf missing ${label} (${kind})"
      fail=$((fail+1))
    fi
  }

  check_resource "google_compute_global_address"           "IP anycast"
  check_resource "google_compute_managed_ssl_certificate"  "managed TLS cert"
  check_resource "google_compute_backend_service"          "backend service"
  check_resource "google_compute_url_map"                  "URL map"
  check_resource "google_compute_target_https_proxy"       "target HTTPS proxy"
  check_resource "google_compute_global_forwarding_rule"   "global forwarding rule"

  # Backend: either serverless NEG or instance_group.
  if grep -qE '^[[:space:]]*resource[[:space:]]+"google_compute_region_network_endpoint_group"' "$LB" \
     || grep -qE '^[[:space:]]*resource[[:space:]]+"google_compute_instance_group"' "$LB" \
     || grep -qE '^[[:space:]]*resource[[:space:]]+"google_compute_instance_group_manager"' "$LB"; then
    echo "  OK   lb.tf declares a backend group (NEG or instance group)"
  else
    echo "  FAIL lb.tf declares no backend group (NEG or instance group)"
    fail=$((fail+1))
  fi

  # managed { domains = [...] } block inside the cert.
  if grep -qE 'managed[[:space:]]*\{' "$LB" && grep -qE 'domains[[:space:]]*=' "$LB"; then
    echo "  OK   managed cert has 'managed { domains = ... }' block"
  else
    echo "  FAIL managed cert missing 'managed { domains = ... }' block"
    fail=$((fail+1))
  fi

  # port_range = "443" on forwarding rule.
  if grep -qE 'port_range[[:space:]]*=[[:space:]]*"443"' "$LB"; then
    echo "  OK   forwarding rule listens on 443"
  else
    echo "  FAIL forwarding rule does not list port_range = \"443\""
    fail=$((fail+1))
  fi

  # load_balancing_scheme EXTERNAL_MANAGED on at least one resource.
  if grep -qE 'load_balancing_scheme[[:space:]]*=[[:space:]]*"EXTERNAL_MANAGED"' "$LB"; then
    echo "  OK   uses load_balancing_scheme = EXTERNAL_MANAGED"
  else
    echo "  FAIL does not set load_balancing_scheme = EXTERNAL_MANAGED"
    fail=$((fail+1))
  fi

  # Chaining: proxy references url_map; forwarding rule references proxy.
  if grep -qE 'url_map[[:space:]]*=[[:space:]]*google_compute_url_map\.' "$LB"; then
    echo "  OK   target proxy references the url_map"
  else
    echo "  FAIL target proxy does not reference google_compute_url_map.<x>"
    fail=$((fail+1))
  fi

  if grep -qE 'target[[:space:]]*=[[:space:]]*google_compute_target_https_proxy\.' "$LB"; then
    echo "  OK   forwarding rule references the target_https_proxy"
  else
    echo "  FAIL forwarding rule does not reference google_compute_target_https_proxy.<x>"
    fail=$((fail+1))
  fi
fi

# --- ARCHITECTURE.md -----------------------------------------------------
if [ ! -f "$ARCH" ]; then
  echo "FAIL: $ARCH does not exist."
  fail=$((fail+1))
else
  echo "  OK   $ARCH exists"

  fences=$(grep -cE '^```' "$ARCH")
  if [ "$fences" -ge 2 ]; then
    echo "  OK   ARCHITECTURE.md has at least one fenced code block (${fences} fence lines)"
  else
    echo "  FAIL ARCHITECTURE.md has only ${fences} code-fence lines (expected >=2)"
    fail=$((fail+1))
  fi

  # Must mention the main LB pieces in prose or the diagram.
  pieces_hit=0
  for p in "forwarding" "url map|url_map" "backend" "target.*proxy|target_https_proxy" "managed.*cert|managed_ssl_certificate" "anycast|global_address"; do
    if grep -qiE "$p" "$ARCH"; then
      pieces_hit=$((pieces_hit+1))
    fi
  done
  if [ "$pieces_hit" -ge 5 ]; then
    echo "  OK   ARCHITECTURE.md mentions >=5 LB pieces (${pieces_hit}/6)"
  else
    echo "  FAIL ARCHITECTURE.md mentions only ${pieces_hit} LB pieces (expected >=5)"
    fail=$((fail+1))
  fi

  # Must justify global vs regional (ALB / Route 53 / regional / anycast).
  if grep -qiE 'ALB|Route 53|regional|anycast|global vs|frente a +ALB|vs +ALB' "$ARCH"; then
    echo "  OK   ARCHITECTURE.md justifies global LB vs regional / ALB"
  else
    echo "  FAIL ARCHITECTURE.md does not justify global LB vs regional / ALB"
    fail=$((fail+1))
  fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: 0 issue(s). Estructura valida. Compara con solution/REFERENCE.md para autoevaluarte."
exit 0
