#!/usr/bin/env bash
# Validator for argo-13-01-port-capstone-from-argocd-to-flux.
#
# Checks the *current cluster context* for evidence that the student has:
#  1) installed Flux
#  2) applied a custom HelmRelease or Kustomization (not the flux-system bootstrap)
#  3) created a namespace 'capstone' with >= 1 Available Deployment
#  4) reached Ready=True on the custom CR(s)
#  5) written solution/README-port.md with a non-trivial decision log
#
# SKIPs cleanly when kind/kubectl/flux missing or no cluster is active.
#
# Note: we intentionally do NOT enable `set -o pipefail`. Several checks use
# `cmd | grep -q ...`; grep closes early on match and the upstream command may
# receive SIGPIPE (exit 141). pipefail would mark those as failure spuriously.

set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SOLUTION_DIR="$HERE/solution"

pass=0; fail=0; report=""

ok()   { report+="PASS: $1"$'\n'; pass=$((pass+1)); }
bad()  { report+="FAIL: $1"$'\n'; fail=$((fail+1)); }
skip() { echo "SKIP: $1" >&2; exit 0; }

command -v kubectl >/dev/null || skip "kubectl not installed"
command -v flux    >/dev/null || skip "flux CLI not installed"

if ! kubectl cluster-info >/dev/null 2>&1; then
  skip "no active kubectl cluster"
fi

# 1) Flux installed?
if kubectl get ns flux-system >/dev/null 2>&1 \
   && kubectl -n flux-system get deploy source-controller >/dev/null 2>&1; then
  ok "Flux is installed (flux-system namespace + source-controller present)"
else
  bad "Flux is not installed (missing namespace 'flux-system' or source-controller)"
fi

# 2) At least one HelmRelease OR Kustomization that is NOT the flux-system boot one.
hr_count="$(kubectl get helmreleases.helm.toolkit.fluxcd.io -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
# Count custom kustomizations: exclude 'flux-system' which is created by `flux install`/`bootstrap`.
ku_custom="$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A --no-headers 2>/dev/null \
             | awk '{print $1"/"$2}' | grep -v '^flux-system/flux-system$' | wc -l | tr -d ' ')"

if [ "${hr_count:-0}" -ge 1 ] || [ "${ku_custom:-0}" -ge 1 ]; then
  ok "Found custom Flux CR(s): HelmReleases=$hr_count, custom Kustomizations=$ku_custom"
else
  bad "No custom HelmRelease or Kustomization found (only flux-system bootstrap)"
fi

# 3) Namespace 'capstone' with >= 1 Deployment having AVAILABLE >= 1.
if kubectl get ns capstone >/dev/null 2>&1; then
  avail="$(kubectl -n capstone get deploy -o jsonpath='{range .items[*]}{.status.availableReplicas}{"\n"}{end}' 2>/dev/null \
          | awk 'NF && $1+0 >= 1' | wc -l | tr -d ' ')"
  if [ "${avail:-0}" -ge 1 ]; then
    ok "Namespace 'capstone' has $avail Deployment(s) with available replicas"
  else
    bad "Namespace 'capstone' exists but no Deployment has availableReplicas >= 1"
  fi
else
  bad "Namespace 'capstone' not found"
fi

# 4) Ready=True on all custom CRs we found.
not_ready=""
# HelmReleases
while IFS= read -r line; do
  [ -z "$line" ] && continue
  ns="$(echo "$line" | awk '{print $1}')"
  name="$(echo "$line" | awk '{print $2}')"
  cond="$(kubectl -n "$ns" get helmrelease "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo '')"
  if [ "$cond" != "True" ]; then
    not_ready+=" helmrelease/$ns/$name(=$cond);"
  fi
done <<< "$(kubectl get helmreleases.helm.toolkit.fluxcd.io -A --no-headers 2>/dev/null)"

# Custom Kustomizations
while IFS= read -r line; do
  [ -z "$line" ] && continue
  ns="$(echo "$line" | awk '{print $1}')"
  name="$(echo "$line" | awk '{print $2}')"
  # skip the bootstrap
  if [ "$ns/$name" = "flux-system/flux-system" ]; then continue; fi
  cond="$(kubectl -n "$ns" get kustomization "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo '')"
  if [ "$cond" != "True" ]; then
    not_ready+=" kustomization/$ns/$name(=$cond);"
  fi
done <<< "$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A --no-headers 2>/dev/null)"

if [ -z "$not_ready" ]; then
  ok "All custom Flux CRs report Ready=True"
else
  bad "Some Flux CRs are not Ready=True:$not_ready"
fi

# 5) README-port.md exists and is non-trivial.
if [ -f "$SOLUTION_DIR/README-port.md" ]; then
  lines="$(wc -l < "$SOLUTION_DIR/README-port.md" | tr -d ' ')"
  if [ "${lines:-0}" -ge 10 ]; then
    ok "solution/README-port.md exists with $lines line(s)"
  else
    bad "solution/README-port.md exists but is too short ($lines lines; expected >= 10)"
  fi
else
  bad "solution/README-port.md not found — document your porting decision"
fi

echo
printf "%s" "$report"
echo
echo "RESULT: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
