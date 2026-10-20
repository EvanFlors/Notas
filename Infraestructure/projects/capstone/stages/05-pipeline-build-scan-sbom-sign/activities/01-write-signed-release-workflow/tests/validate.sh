#!/usr/bin/env bash
# Validator for cap-05-01-write-signed-release-workflow.
# Uses `set -eu` only. Deliberately NOT `set -o pipefail`:
#   pipefail turns SIGPIPE (exit 141) from short-circuiting readers like
#   `grep -q ... | head` into spurious failures, and the workflow/JSON
#   parsing below pipes freely into grep/python. The reference pattern
#   (git-and-github module 13) documents this same choice.
set -eu

BASE="${1:-${BASE_DIR:-/tmp/cap-05}}"
MODE="${MODE:-local}"
PROJECT="$BASE/project"

pass=0
fail=0
report=""

ok()  { report+="  OK   — $1\n"; pass=$((pass+1)); }
bad() { report+="  FAIL — $1\n"; fail=$((fail+1)); }

echo "== Validating capstone stage 5 artifacts (MODE=$MODE) under $PROJECT =="

if [ ! -d "$PROJECT" ]; then
  bad "project missing at $PROJECT (run starter/bootstrap.sh first)"
  echo
  printf "%b" "$report"
  echo
  echo "RESULT: $pass OK / $fail FAIL  →  FAIL"
  exit 1
fi

TRIVY="$PROJECT/trivy.yaml"
REL="$PROJECT/.github/workflows/release.yml"
VER="$PROJECT/.github/workflows/verify.yml"

# ---------- trivy.yaml ----------
if [ ! -f "$TRIVY" ]; then
  bad "trivy.yaml missing"
else
  ok "trivy.yaml exists"
  verdict="$(python3 - "$TRIVY" <<'PY' 2>&1
import sys, yaml
try:
    doc = yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)
issues = []
if not isinstance(doc, dict):
    issues.append("trivy.yaml root is not a mapping")
else:
    sev = doc.get("severity") or []
    if isinstance(sev, str):
        sev = [s.strip() for s in sev.split(",")]
    sev_up = [str(s).upper() for s in sev]
    if "HIGH" not in sev_up or "CRITICAL" not in sev_up:
        issues.append(f"severity must include HIGH and CRITICAL (got {sev!r})")
    ec = doc.get("exit-code")
    if ec not in (1, "1"):
        issues.append(f"exit-code must be 1 (got {ec!r})")
    vuln = doc.get("vulnerability") or {}
    if not isinstance(vuln, dict) or vuln.get("ignore-unfixed") is not True:
        issues.append("vulnerability.ignore-unfixed must be true")
for i in issues:
    print("ISSUE:", i)
if not issues:
    print("OK")
PY
)"
  if printf '%s' "$verdict" | grep -q '^PARSE_ERROR'; then
    bad "trivy.yaml invalid YAML: $(printf '%s' "$verdict")"
  elif printf '%s' "$verdict" | grep -q '^OK$'; then
    ok "trivy.yaml has HIGH+CRITICAL, exit-code=1, ignore-unfixed=true"
  else
    bad "trivy.yaml issues: $(printf '%s' "$verdict" | tr '\n' '|')"
  fi
fi

# ---------- release.yml ----------
if [ ! -f "$REL" ]; then
  bad "release.yml missing"
else
  ok "release.yml exists"
  rel_verdict="$(python3 - "$REL" <<'PY' 2>&1
import sys, re, yaml
path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)

issues = []
if not isinstance(doc, dict):
    issues.append("release.yml root is not a mapping")

# PyYAML parses `on:` as the boolean True (YAML 1.1 "y/n/on/off" quirk).
on = doc.get("on") if "on" in doc else doc.get(True)
tags_ok = False
if isinstance(on, dict):
    push = on.get("push") or {}
    if isinstance(push, dict):
        tags = push.get("tags") or []
        if isinstance(tags, list) and any("v" in str(t) for t in tags):
            tags_ok = True
if not tags_ok:
    issues.append("trigger must be push.tags including a 'v*' pattern")

jobs = (doc or {}).get("jobs") or {}
if not jobs:
    issues.append("no jobs defined")

job_perms_ok = False
build_step_id = None
digest_consumers = 0
has_trivy = False
has_syft = False
has_cosign_installer = False
has_cosign_sign = False
has_cosign_attest = False
has_slsa_attest = False
non_sha_uses = []

SHA40 = re.compile(r"^[A-Za-z0-9._/\-]+@[0-9a-f]{40}(\s|$|#)")

# Forbidden long-lived credential refs.
forbidden = [
    r"AKIA[0-9A-Z]{10,}",
    r"\$\{\{\s*secrets\.AWS_ACCESS_KEY_ID\s*\}\}",
    r"\$\{\{\s*secrets\.AWS_SECRET_ACCESS_KEY\s*\}\}",
    r"\$\{\{\s*secrets\.DOCKERHUB_[A-Z_]+\s*\}\}",
]
for pat in forbidden:
    if re.search(pat, raw):
        issues.append(f"release.yml contains forbidden long-lived credential: /{pat}/")

for jname, jbody in jobs.items():
    if not isinstance(jbody, dict):
        continue
    perms = jbody.get("permissions") or {}
    if isinstance(perms, dict):
        want = {"id-token": "write", "attestations": "write",
                "packages": "write", "contents": "read"}
        if all(str(perms.get(k, "")).lower() == v for k, v in want.items()):
            job_perms_ok = True

    for step in (jbody.get("steps") or []):
        if not isinstance(step, dict):
            continue
        u = str(step.get("uses") or "")
        run = str(step.get("run") or "")

        if u:
            # Pin-by-SHA check (ignore local/composite actions beginning with "./").
            if not u.startswith("./") and not SHA40.match(u + " "):
                non_sha_uses.append(u)

        if u.startswith("docker/build-push-action"):
            build_step_id = step.get("id") or build_step_id
        if u.startswith("aquasecurity/trivy-action"):
            has_trivy = True
            with_ = step.get("with") or {}
            if str(with_.get("trivy-config", "")) != "trivy.yaml":
                issues.append("trivy step must set with.trivy-config: trivy.yaml")
        if u.startswith("anchore/sbom-action"):
            has_syft = True
            with_ = step.get("with") or {}
            if "spdx" not in str(with_.get("format", "")).lower():
                issues.append("syft step must set with.format to an SPDX variant")
        if u.startswith("sigstore/cosign-installer"):
            has_cosign_installer = True
        if u.startswith("actions/attest-build-provenance"):
            has_slsa_attest = True
            with_ = step.get("with") or {}
            if not with_.get("subject-digest"):
                issues.append("attest-build-provenance missing with.subject-digest")

        if "cosign sign" in run:
            has_cosign_sign = True
        if re.search(r"cosign\s+attest\b", run) and "spdxjson" in run:
            has_cosign_attest = True

        # Consumption-by-digest check.
        blob = (run or "") + " " + " ".join(
            f"{k}={v}" for k, v in (step.get("with") or {}).items()
        )
        if re.search(r"@\$\{\{\s*steps\.[A-Za-z0-9_\-]+\.outputs\.digest\s*\}\}", blob):
            digest_consumers += 1

if not job_perms_ok:
    issues.append("no job has permissions id-token:write + attestations:write + packages:write + contents:read")
if build_step_id is None:
    issues.append("docker/build-push-action step must have an `id:` to expose outputs.digest")
if digest_consumers < 3:
    issues.append(f"expected at least 3 steps consuming image@${{steps.*.outputs.digest}} (got {digest_consumers})")
if not has_trivy:
    issues.append("missing aquasecurity/trivy-action step")
if not has_syft:
    issues.append("missing anchore/sbom-action step")
if not has_cosign_installer:
    issues.append("missing sigstore/cosign-installer step")
if not has_cosign_sign:
    issues.append("missing `cosign sign` run step")
if not has_cosign_attest:
    issues.append("missing `cosign attest ... spdxjson` run step")
if not has_slsa_attest:
    issues.append("missing actions/attest-build-provenance step")
if non_sha_uses:
    issues.append(f"Actions not pinned by SHA40: {non_sha_uses}")

for i in issues:
    print("ISSUE:", i)
if not issues:
    print("OK")
PY
)"
  if printf '%s' "$rel_verdict" | grep -q '^PARSE_ERROR'; then
    bad "release.yml invalid YAML: $(printf '%s' "$rel_verdict")"
  elif printf '%s' "$rel_verdict" | grep -q '^OK$'; then
    ok "release.yml has correct permissions, build+trivy+syft+cosign+SLSA, digest-pinned, SHA-pinned Actions, no long-lived secrets"
  else
    bad "release.yml issues: $(printf '%s' "$rel_verdict" | tr '\n' '|')"
  fi
fi

# ---------- verify.yml ----------
if [ ! -f "$VER" ]; then
  bad "verify.yml missing"
else
  ok "verify.yml exists"
  ver_verdict="$(python3 - "$VER" <<'PY' 2>&1
import sys, re, yaml
path = sys.argv[1]
raw = open(path).read()
try:
    doc = yaml.safe_load(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}"); sys.exit(0)

issues = []
on = doc.get("on") if "on" in doc else doc.get(True)
wc = None
if isinstance(on, dict):
    wc = on.get("workflow_call")
if not isinstance(wc, dict):
    issues.append("verify.yml must trigger on workflow_call")
else:
    inputs = wc.get("inputs") or {}
    for k in ("image", "digest"):
        if k not in inputs:
            issues.append(f"workflow_call missing input `{k}`")

if "cosign verify" not in raw:
    issues.append("verify.yml must call `cosign verify`")
if "--certificate-identity-regexp" not in raw:
    issues.append("verify.yml must pass --certificate-identity-regexp")
if "--certificate-oidc-issuer" not in raw:
    issues.append("verify.yml must pass --certificate-oidc-issuer")

for i in issues:
    print("ISSUE:", i)
if not issues:
    print("OK")
PY
)"
  if printf '%s' "$ver_verdict" | grep -q '^PARSE_ERROR'; then
    bad "verify.yml invalid YAML: $(printf '%s' "$ver_verdict")"
  elif printf '%s' "$ver_verdict" | grep -q '^OK$'; then
    ok "verify.yml is workflow_call with cosign verify + identity + issuer flags"
  else
    bad "verify.yml issues: $(printf '%s' "$ver_verdict" | tr '\n' '|')"
  fi
fi

# ---------- MODE=live extra ----------
if [ "$MODE" = "live" ]; then
  if command -v cosign >/dev/null 2>&1; then
    ok "cosign CLI installed: $(cosign version 2>&1 | head -1)"
  else
    bad "cosign not installed (required for MODE=live)"
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
