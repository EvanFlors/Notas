#!/usr/bin/env bash
# Validator for gha-13-01-harden-an-existing-workflow.
# NOT using `set -o pipefail` — grep -q after long producers can SIGPIPE
# and give false negatives.

BASE="${1:-${BASE_DIR:-/tmp/harden-workflow}}"
PROJECT="$BASE/project"
WF_DIR="$PROJECT/.github/workflows"
ADR="$PROJECT/docs/adr/0001-ci-security-hardening.md"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating hardened workflow + ADR under $PROJECT =="

if [ ! -d "$PROJECT" ]; then
  bad "project missing at $PROJECT (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

if [ ! -d "$WF_DIR" ]; then
  bad "$WF_DIR missing"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

# Find all .yml / .yaml workflows (student may have one or several)
WORKFLOWS=()
while IFS= read -r f; do WORKFLOWS+=("$f"); done < <(find "$WF_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
  bad "no workflow files found in $WF_DIR"
else
  ok "found ${#WORKFLOWS[@]} workflow file(s)"
fi

# ---------- Per-workflow structural check ----------
for WF in "${WORKFLOWS[@]}"; do
  rel="${WF#$PROJECT/}"
  verdict="$(python3 - "$WF" <<'PY' 2>&1
import re, sys, yaml

path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(0)

if not isinstance(doc, dict):
    print("PARSE_ERROR: root is not a mapping")
    sys.exit(0)

issues = []

# ---- (A) permissions present and not write-all ----
perms = doc.get("permissions", "__MISSING__")
if perms == "__MISSING__":
    issues.append("top-level `permissions:` is missing (set to {} or contents: read)")
elif isinstance(perms, str) and perms.strip().lower() in ("write-all", "write_all"):
    issues.append("top-level `permissions: write-all` is forbidden")
elif isinstance(perms, dict):
    for k, v in perms.items():
        if isinstance(v, str) and v.strip().lower() == "write":
            # 'write' on a specific scope at top-level is a yellow flag but
            # not inherently insecure; we only hard-fail blanket write-all.
            pass

# Also disallow job-level permissions: write-all
jobs = doc.get("jobs") or {}
for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    jp = jbody.get("permissions")
    if isinstance(jp, str) and jp.strip().lower() in ("write-all", "write_all"):
        issues.append(f"job '{jname}' uses forbidden `permissions: write-all`")

# ---- (B) all `uses:` pinned to 40-hex SHA ----
# Grab every `uses:` line via regex over the raw YAML (works regardless of
# anchors, flow style, etc.). Ignore local actions (./, .github/) and docker://.
uses_lines = re.findall(r"(?m)^\s*(?:-\s*)?uses:\s*([^\s#]+)", raw)
sha_re = re.compile(r"^[a-f0-9]{40}$")
unpinned = []
for u in uses_lines:
    if u.startswith("./") or u.startswith(".github/") or u.startswith("docker://"):
        continue
    if "@" not in u:
        unpinned.append(u + " (no ref)")
        continue
    _, ref = u.rsplit("@", 1)
    if not sha_re.match(ref):
        unpinned.append(u)
if unpinned:
    issues.append("actions not pinned to 40-hex SHA: " + ", ".join(unpinned))

# ---- (C) no dangerous ${{ github.* }} inside any run: ----
DANGEROUS = re.compile(
    r"\$\{\{\s*github\.(event\.(issue|pull_request|comment|head_commit|workflow_run)"
    r"|actor|head_ref|triggering_actor)"
)
for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    for i, step in enumerate(jbody.get("steps") or []):
        if not isinstance(step, dict):
            continue
        run = step.get("run")
        if not isinstance(run, str):
            continue
        lines = [ln for ln in run.splitlines() if not ln.lstrip().startswith("#")]
        script = "\n".join(lines)
        m = DANGEROUS.search(script)
        if m:
            issues.append(
                f"job '{jname}' step #{i}: dangerous interpolation inside run: {m.group(0)}"
            )

# ---- (D) pull_request_target with checkout of head.sha ----
on = doc.get("on") or doc.get(True) or {}
# `on` can be a string, list, or mapping; detect pull_request_target in any shape
on_str = str(on)
if "pull_request_target" in on_str:
    # If we see it, scan for the dangerous checkout pattern.
    pat = re.compile(
        r"uses:\s*actions/checkout@[^\s]+\s*\n\s*with:\s*\n(?:\s*\w[^\n]*\n)*?\s*ref:\s*\$\{\{\s*github\.event\.pull_request\.head\.sha\s*\}\}"
    )
    if pat.search(raw):
        issues.append(
            "workflow uses `pull_request_target` AND checks out `head.sha` of the PR "
            "(classic pwnrequest pattern)"
        )

# ---- (E) forbidden long-lived AWS secrets ----
if re.search(r"AKIA[0-9A-Z]{10,}", raw):
    issues.append("workflow contains an AKIA... access key literal")
if re.search(r"secrets\.AWS_ACCESS_KEY_ID", raw):
    issues.append("workflow references secrets.AWS_ACCESS_KEY_ID (use OIDC)")
if re.search(r"secrets\.AWS_SECRET_ACCESS_KEY", raw):
    issues.append("workflow references secrets.AWS_SECRET_ACCESS_KEY (use OIDC)")

if issues:
    for i in issues:
        print(f"ISSUE: {i}")
else:
    print("OK")
PY
)"

  if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
    bad "$rel: invalid YAML: $(printf '%s' "$verdict")"
  elif printf '%s' "$verdict" | grep -q '^OK$'; then
    ok "$rel: all workflow-level checks pass (perms, SHA pins, no injection, no AKIA, safe PRT)"
  else
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      bad "$rel: ${line#ISSUE: }"
    done <<< "$verdict"
  fi
done

# ---------- ADR ----------
if [ ! -f "$ADR" ]; then
  bad "ADR missing at docs/adr/0001-ci-security-hardening.md"
else
  ok "ADR file exists"
  missing_sections=""
  for section in '## Status' '## Context' '## Decision' '## Consequences'; do
    if ! grep -qF "$section" "$ADR"; then
      missing_sections+=" '$section'"
    fi
  done
  if [ -z "$missing_sections" ]; then
    ok "ADR has required top-level sections (Status, Context, Decision, Consequences)"
  else
    bad "ADR missing sections:$missing_sections"
  fi

  # Count decision subsections "### D<n>" or "### D<n> —"
  n_decisions="$(grep -cE '^### D[0-9]+' "$ADR" || true)"
  if [ "${n_decisions:-0}" -ge 5 ]; then
    ok "ADR has $n_decisions decision subsections (>= 5 required)"
  else
    bad "ADR has only ${n_decisions:-0} '### D<n>' decision subsections (need >= 5)"
  fi
fi

echo
printf "%b" "$report"
echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASS ($pass/$pass)"
  exit 0
else
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi
