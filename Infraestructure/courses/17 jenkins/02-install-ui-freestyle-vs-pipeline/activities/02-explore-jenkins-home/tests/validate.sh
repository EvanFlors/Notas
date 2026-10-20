#!/usr/bin/env bash
# Structural validation for jk-02-02-explore-jenkins-home.
#
# Checks that INVENTORY.md exists, has the five required sections, mentions
# the key tokens (config.xml, Jenkinsfile, Git/SCM, secrets/credentials)
# and lists at least three layout entries inside the layout section. If
# docker is available and a container named "jenkins" is running, performs
# a sanity probe of /var/jenkins_home inside it; otherwise marks that
# check as SKIP.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.

set -eu

BASE="${1:-/tmp/jk-02-home}"
fail=0
skip=0

echo "== Structural validation for $BASE =="

DOC="$BASE/INVENTORY.md"
if [ ! -f "$DOC" ]; then
  echo "  FAIL $DOC does not exist"
  echo
  echo "RESULT: 1 issue(s), 0 skipped."
  exit 1
fi
echo "  OK   $DOC exists"

# --- Required sections ---------------------------------------------------
for section in \
  "JENKINS_HOME layout" \
  "Freestyle" \
  "Pipeline inline vs from SCM" \
  "Growth without retention" \
  "Risks"; do
  if grep -qE "^#+\s+${section}\s*$" "$DOC"; then
    echo "  OK   INVENTORY.md has section '${section}'"
  else
    echo "  FAIL INVENTORY.md missing section '${section}'"
    fail=$((fail+1))
  fi
done

# --- Required literal mentions -------------------------------------------
if grep -q 'config\.xml' "$DOC"; then
  echo "  OK   INVENTORY.md mentions 'config.xml'"
else
  echo "  FAIL INVENTORY.md does not mention 'config.xml'"
  fail=$((fail+1))
fi

if grep -q 'Jenkinsfile' "$DOC"; then
  echo "  OK   INVENTORY.md mentions 'Jenkinsfile'"
else
  echo "  FAIL INVENTORY.md does not mention 'Jenkinsfile'"
  fail=$((fail+1))
fi

if grep -qE '\bGit\b|\bSCM\b' "$DOC"; then
  echo "  OK   INVENTORY.md mentions Git or SCM"
else
  echo "  FAIL INVENTORY.md does not mention Git or SCM"
  fail=$((fail+1))
fi

if grep -qiE 'secrets|credentials' "$DOC"; then
  echo "  OK   INVENTORY.md mentions secrets or credentials"
else
  echo "  FAIL INVENTORY.md does not mention secrets or credentials"
  fail=$((fail+1))
fi

# --- Layout section must enumerate >=3 of the known entries --------------
# Extract the layout section (from the heading until the next heading).
layout_body=$(awk '
  /^#+[[:space:]]+JENKINS_HOME layout[[:space:]]*$/ { capture=1; next }
  /^#+[[:space:]]+/ { if (capture) { capture=0 } }
  { if (capture) print }
' "$DOC")

layout_count=0
for entry in "jobs/" "workspace/" "plugins/" "users/" "secrets/" "nodes/" "config\.xml"; do
  if printf '%s' "$layout_body" | grep -qE "$entry"; then
    layout_count=$((layout_count+1))
  fi
done
if [ "$layout_count" -ge 3 ]; then
  echo "  OK   layout section enumerates at least 3 known entries (${layout_count} matched)"
else
  echo "  FAIL layout section enumerates only ${layout_count} known entries (expected >=3)"
  fail=$((fail+1))
fi

# --- Growth-without-retention section must list >=3 bullets --------------
growth_body=$(awk '
  /^#+[[:space:]]+Growth without retention[[:space:]]*$/ { capture=1; next }
  /^#+[[:space:]]+/ { if (capture) { capture=0 } }
  { if (capture) print }
' "$DOC")

growth_bullets=$(printf '%s\n' "$growth_body" | grep -cE '^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+' || true)
if [ "$growth_bullets" -ge 3 ]; then
  echo "  OK   'Growth without retention' lists at least 3 items (${growth_bullets} found)"
else
  echo "  FAIL 'Growth without retention' lists only ${growth_bullets} items (expected >=3)"
  fail=$((fail+1))
fi

# --- Risks section must list >=3 bullets ---------------------------------
risks_body=$(awk '
  /^#+[[:space:]]+Risks[[:space:]]*$/ { capture=1; next }
  /^#+[[:space:]]+/ { if (capture) { capture=0 } }
  { if (capture) print }
' "$DOC")

risks_bullets=$(printf '%s\n' "$risks_body" | grep -cE '^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+' || true)
if [ "$risks_bullets" -ge 3 ]; then
  echo "  OK   'Risks' lists at least 3 items (${risks_bullets} found)"
else
  echo "  FAIL 'Risks' lists only ${risks_bullets} items (expected >=3)"
  fail=$((fail+1))
fi

# --- Docker + Jenkins container (optional sanity probe) ------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' | grep -qx 'jenkins'; then
    if docker exec jenkins test -d /var/jenkins_home >/dev/null 2>&1; then
      echo "  OK   /var/jenkins_home exists in container 'jenkins'"
    else
      echo "  FAIL /var/jenkins_home missing in container 'jenkins'"
      fail=$((fail+1))
    fi
  else
    echo "  SKIP no running container named 'jenkins' — sanity probe skipped"
    skip=$((skip+1))
  fi
else
  echo "  SKIP docker not available — sanity probe skipped"
  skip=$((skip+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail issue(s), $skip skipped."
  exit 1
fi
echo "RESULT: 0 issue(s), $skip skipped."
exit 0
