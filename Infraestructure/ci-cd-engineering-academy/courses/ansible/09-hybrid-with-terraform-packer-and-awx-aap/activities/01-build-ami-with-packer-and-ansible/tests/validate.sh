#!/usr/bin/env bash
# Structural + local-tooling validation for
# ans-09-01-build-ami-with-packer-and-ansible.
#
# Checks that webapp.pkr.hcl, playbook.yml and README-INTENT.md exist,
# contain the required blocks/fields, and (when the tooling is installed)
# pass `packer fmt -check`, `packer validate`, and
# `ansible-playbook --syntax-check`. If a tool is missing, prints SKIP
# and continues — the lab is about writing the files, not about having
# every tool installed on the grader's machine.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT build a real AMI (no AWS credentials required / used).

set -eu

BASE="${1:-/tmp/ans-09-01}"
HCL="$BASE/webapp.pkr.hcl"
PLAY="$BASE/playbook.yml"
DOC="$BASE/README-INTENT.md"
fail=0

echo "== Structural validation for $BASE =="

# --- Required files -------------------------------------------------------
for f in "$HCL" "$PLAY" "$DOC"; do
  if [ -f "$f" ]; then
    echo "  OK   $f exists"
  else
    echo "  FAIL $f does not exist"
    fail=$((fail+1))
  fi
done

# If critical files are missing, keep going but many checks will fail.
# --- webapp.pkr.hcl -------------------------------------------------------
if [ -f "$HCL" ]; then
  # required_plugins amazon + ansible
  if grep -qE 'required_plugins' "$HCL" \
     && grep -qE 'github\.com/hashicorp/amazon' "$HCL" \
     && grep -qE 'github\.com/hashicorp/ansible' "$HCL"; then
    echo "  OK   webapp.pkr.hcl declares required_plugins for amazon and ansible"
  else
    echo "  FAIL webapp.pkr.hcl must declare required_plugins for amazon and ansible"
    fail=$((fail+1))
  fi

  # variable region + app_version
  if grep -qE 'variable[[:space:]]+"region"' "$HCL"; then
    echo "  OK   webapp.pkr.hcl declares variable 'region'"
  else
    echo "  FAIL webapp.pkr.hcl missing variable 'region'"
    fail=$((fail+1))
  fi
  if grep -qE 'variable[[:space:]]+"app_version"' "$HCL"; then
    echo "  OK   webapp.pkr.hcl declares variable 'app_version'"
  else
    echo "  FAIL webapp.pkr.hcl missing variable 'app_version'"
    fail=$((fail+1))
  fi

  # source amazon-ebs with ssh_username and source_ami_filter
  if grep -qE 'source[[:space:]]+"amazon-ebs"' "$HCL"; then
    echo "  OK   webapp.pkr.hcl has a source 'amazon-ebs' block"
  else
    echo "  FAIL webapp.pkr.hcl missing source 'amazon-ebs' block"
    fail=$((fail+1))
  fi
  if grep -qE 'source_ami_filter' "$HCL"; then
    echo "  OK   webapp.pkr.hcl uses source_ami_filter"
  else
    echo "  FAIL webapp.pkr.hcl missing source_ami_filter"
    fail=$((fail+1))
  fi
  if grep -qE 'ssh_username[[:space:]]*=[[:space:]]*"ec2-user"' "$HCL"; then
    echo "  OK   webapp.pkr.hcl sets ssh_username = \"ec2-user\""
  else
    echo "  FAIL webapp.pkr.hcl must set ssh_username = \"ec2-user\""
    fail=$((fail+1))
  fi

  # build block with provisioner ansible and required fields
  if grep -qE 'build[[:space:]]*{' "$HCL"; then
    echo "  OK   webapp.pkr.hcl has a build block"
  else
    echo "  FAIL webapp.pkr.hcl missing build block"
    fail=$((fail+1))
  fi
  if grep -qE 'provisioner[[:space:]]+"ansible"' "$HCL"; then
    echo "  OK   webapp.pkr.hcl has a provisioner \"ansible\""
  else
    echo "  FAIL webapp.pkr.hcl missing provisioner \"ansible\""
    fail=$((fail+1))
  fi
  if grep -qE 'playbook_file[[:space:]]*=[[:space:]]*"\./playbook\.yml"' "$HCL"; then
    echo "  OK   provisioner points playbook_file to ./playbook.yml"
  else
    echo "  FAIL provisioner must set playbook_file = \"./playbook.yml\""
    fail=$((fail+1))
  fi
  if grep -qE 'use_proxy[[:space:]]*=[[:space:]]*false' "$HCL"; then
    echo "  OK   provisioner sets use_proxy = false"
  else
    echo "  FAIL provisioner must set use_proxy = false"
    fail=$((fail+1))
  fi
  if grep -qE 'extra_arguments' "$HCL" && grep -q 'app_version' "$HCL"; then
    echo "  OK   provisioner declares extra_arguments mentioning app_version"
  else
    echo "  FAIL provisioner must declare extra_arguments referencing app_version"
    fail=$((fail+1))
  fi
fi

# --- playbook.yml ---------------------------------------------------------
if [ -f "$PLAY" ]; then
  if grep -qE '^-[[:space:]]+name:' "$PLAY" && grep -qE 'hosts:[[:space:]]*all' "$PLAY"; then
    echo "  OK   playbook.yml has a play targeting hosts: all"
  else
    echo "  FAIL playbook.yml must have a play with hosts: all"
    fail=$((fail+1))
  fi
  if grep -qE 'become:[[:space:]]*true' "$PLAY"; then
    echo "  OK   playbook.yml uses become: true"
  else
    echo "  FAIL playbook.yml must use become: true"
    fail=$((fail+1))
  fi
  if grep -q 'nginx' "$PLAY"; then
    echo "  OK   playbook.yml mentions nginx"
  else
    echo "  FAIL playbook.yml does not mention nginx"
    fail=$((fail+1))
  fi
  if grep -qE 'ansible\.builtin\.user|^[[:space:]]+user:' "$PLAY"; then
    echo "  OK   playbook.yml uses the user module (service user)"
  else
    echo "  FAIL playbook.yml must create a service user with the user module"
    fail=$((fail+1))
  fi
  if grep -qE 'enabled:[[:space:]]*true' "$PLAY"; then
    echo "  OK   playbook.yml enables a service (enabled: true)"
  else
    echo "  FAIL playbook.yml must enable a service with enabled: true"
    fail=$((fail+1))
  fi
  # Discourage non-idempotent shell/command modules without creates:/changed_when:.
  # We only flag true module invocations: `ansible.builtin.shell:` / `.command:`,
  # or a top-level `shell:` / `command:` at the task level (two indent levels
  # under a `- name:` entry — grep for leading 6 spaces to avoid matching
  # `shell: /sbin/nologin` nested inside the `user:` module.
  if grep -qE '^[[:space:]]+(ansible\.builtin\.)?(shell|command):[[:space:]]*($|[|>])' "$PLAY" \
     && ! grep -qE 'creates:|changed_when:' "$PLAY"; then
    echo "  FAIL playbook.yml uses shell/command module without creates:/changed_when: (not idempotent)"
    fail=$((fail+1))
  else
    echo "  OK   playbook.yml avoids non-idempotent shell/command"
  fi
fi

# --- README-INTENT.md -----------------------------------------------------
if [ -f "$DOC" ]; then
  for section in "Que se hornea" "Que NO se hornea" \
                 "Provisioner ansible vs ansible-local" \
                 "Como consume Terraform"; do
    if grep -qiE "^#+ .*${section}" "$DOC"; then
      echo "  OK   README-INTENT.md has section '${section}'"
    else
      echo "  FAIL README-INTENT.md missing section '${section}'"
      fail=$((fail+1))
    fi
  done
  if grep -qi 'cloudwatch' "$DOC"; then
    echo "  OK   README-INTENT.md mentions cloudwatch"
  else
    echo "  FAIL README-INTENT.md does not mention cloudwatch"
    fail=$((fail+1))
  fi
  if grep -qiE 'secrets +manager|parameter +store|user-?data' "$DOC"; then
    echo "  OK   README-INTENT.md mentions where secrets go (Secrets Manager / Parameter Store / user-data)"
  else
    echo "  FAIL README-INTENT.md must mention Secrets Manager, Parameter Store or user-data for secrets"
    fail=$((fail+1))
  fi
  if grep -qiE 'packer-manifest|artifact_id' "$DOC"; then
    echo "  OK   README-INTENT.md explains how Terraform consumes the ami_id (manifest/artifact_id)"
  else
    echo "  FAIL README-INTENT.md must mention packer-manifest.json or artifact_id"
    fail=$((fail+1))
  fi
fi

# --- Local tooling (SKIP if missing) --------------------------------------
echo
echo "== Local tooling checks (SKIP if not installed) =="

if command -v packer >/dev/null 2>&1; then
  echo "  packer: $(packer --version 2>&1 | head -1)"
  if [ -f "$HCL" ]; then
    if (cd "$BASE" && packer fmt -check webapp.pkr.hcl >/dev/null 2>&1); then
      echo "  OK   packer fmt -check webapp.pkr.hcl"
    else
      echo "  FAIL packer fmt -check webapp.pkr.hcl (run: packer fmt webapp.pkr.hcl)"
      fail=$((fail+1))
    fi
    # packer init may need network to pull plugins; attempt but tolerate failure
    (cd "$BASE" && packer init . >/dev/null 2>&1) || \
      echo "  SKIP packer init (likely no network to download plugins)"
    if (cd "$BASE" && packer validate . >/dev/null 2>&1); then
      echo "  OK   packer validate ."
    else
      # packer validate requires plugins to be initialized; if init failed, skip
      if (cd "$BASE" && packer validate . 2>&1 | grep -qiE 'plugin|init'); then
        echo "  SKIP packer validate (plugins not initialized; needs network)"
      else
        echo "  FAIL packer validate ."
        fail=$((fail+1))
      fi
    fi
  fi
else
  echo "  SKIP packer not installed (install from https://developer.hashicorp.com/packer)"
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  echo "  ansible: $(ansible --version 2>&1 | head -1)"
  if [ -f "$PLAY" ]; then
    if ansible-playbook --syntax-check "$PLAY" >/dev/null 2>&1; then
      echo "  OK   ansible-playbook --syntax-check playbook.yml"
    else
      echo "  FAIL ansible-playbook --syntax-check playbook.yml"
      fail=$((fail+1))
    fi
  fi
else
  echo "  SKIP ansible-playbook not installed (install ansible-core)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  echo "        (Compare your files with solution/ for a semantic self-review.)"
  exit 1
fi
echo "OK: webapp.pkr.hcl + playbook.yml + README-INTENT.md pasan validacion estructural."
echo "    Compara con solution/ para autoevaluacion semantica."
exit 0
