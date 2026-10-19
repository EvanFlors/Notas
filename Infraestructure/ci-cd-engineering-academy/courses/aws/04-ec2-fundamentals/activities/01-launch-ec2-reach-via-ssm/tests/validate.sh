#!/usr/bin/env bash
# Structural validation for aws-04-01-launch-ec2-reach-via-ssm.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
# This convention follows the git-and-github course validators.
#
# We DO use `set -eu` to catch unset variables and failed commands early.
# Each check is wrapped in `if ...; then OK; else FAIL; fi` so controlled
# non-zero exits do not kill the whole script.

set -eu

BASE="${1:-/tmp/aws-04-01}"
passed=0
failed=0
skipped=0

ok()   { echo "  OK   $1"; passed=$((passed+1)); }
bad()  { echo "  FAIL $1"; failed=$((failed+1)); }
skip() { echo "  SKIP $1"; skipped=$((skipped+1)); }

echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  bad "no existe $BASE (crea el directorio y copia starter/)"
  echo "RESULT: FAIL"
  exit 1
fi

# --- 1. Required files -------------------------------------------------------
for f in main.tf variables.tf outputs.tf user-data.sh EBS-choices.md; do
  if [ -f "$BASE/$f" ]; then
    ok "existe $f"
  else
    bad "falta $f"
  fi
done

MAIN="$BASE/main.tf"
UD="$BASE/user-data.sh"
EBS="$BASE/EBS-choices.md"

# --- 2. main.tf — recursos obligatorios --------------------------------------
if [ -f "$MAIN" ]; then
  for pattern in \
    'data +"aws_ssm_parameter" +"al2023"' \
    'resource +"aws_iam_role" +"ec2_ssm"' \
    'resource +"aws_iam_role_policy_attachment" +"ssm_core"' \
    'resource +"aws_iam_instance_profile" +"ec2_ssm"' \
    'resource +"aws_security_group" +"ec2_private"' \
    'resource +"aws_instance" +"app"'
  do
    if grep -qE "$pattern" "$MAIN"; then
      ok "main.tf declara $pattern"
    else
      bad "main.tf no declara $pattern"
    fi
  done

  # AMI SSM parameter path presente (ami-amazon-linux-latest).
  if grep -q 'ami-amazon-linux-latest' "$MAIN"; then
    ok "main.tf resuelve AMI via SSM Parameter Store (no hardcodeado)"
  else
    bad "main.tf no referencia '/aws/service/ami-amazon-linux-latest/...'"
  fi

  # IAM policy correcta.
  if grep -q 'AmazonSSMManagedInstanceCore' "$MAIN"; then
    ok "main.tf adjunta AmazonSSMManagedInstanceCore"
  else
    bad "main.tf no adjunta AmazonSSMManagedInstanceCore"
  fi

  # Trust policy EC2.
  if grep -q 'ec2.amazonaws.com' "$MAIN"; then
    ok "main.tf define trust policy para ec2.amazonaws.com"
  else
    bad "main.tf no define principal ec2.amazonaws.com"
  fi

  # IMDSv2 obligatorio.
  if grep -qE 'http_tokens[[:space:]]*=[[:space:]]*"required"' "$MAIN"; then
    ok "main.tf fuerza IMDSv2 (http_tokens = \"required\")"
  else
    bad "main.tf no fuerza IMDSv2 (falta http_tokens = \"required\")"
  fi

  if grep -qE 'http_put_response_hop_limit[[:space:]]*=[[:space:]]*1' "$MAIN"; then
    ok "main.tf fija http_put_response_hop_limit = 1"
  else
    bad "main.tf no fija http_put_response_hop_limit = 1"
  fi

  # NO SSH: no debe aparecer un bloque ingress con puerto 22.
  if grep -qE 'from_port[[:space:]]*=[[:space:]]*22' "$MAIN"; then
    bad "main.tf abre puerto 22 (SSH). Debe quedar cerrado — usa SSM."
  else
    ok "main.tf no abre puerto 22"
  fi

  # NO key_name.
  if grep -qE '^[[:space:]]*key_name[[:space:]]*=' "$MAIN"; then
    bad "main.tf declara key_name (no debe: no se usa SSH)"
  else
    ok "main.tf no declara key_name"
  fi

  # associate_public_ip_address = false
  if grep -qE 'associate_public_ip_address[[:space:]]*=[[:space:]]*false' "$MAIN"; then
    ok "main.tf fuerza associate_public_ip_address = false"
  else
    bad "main.tf no fija associate_public_ip_address = false"
  fi

  # user_data referenciado.
  if grep -q 'user-data.sh' "$MAIN"; then
    ok "main.tf referencia user-data.sh"
  else
    bad "main.tf no referencia user-data.sh"
  fi
fi

# --- 3. user-data.sh — forma y sintaxis --------------------------------------
if [ -f "$UD" ]; then
  if head -1 "$UD" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash'; then
    ok "user-data.sh tiene shebang bash"
  else
    bad "user-data.sh no tiene shebang bash"
  fi

  if grep -qE 'set -euo pipefail|set -eu +-o pipefail|set -o pipefail' "$UD"; then
    ok "user-data.sh declara set -euo pipefail (fallo duro en bootstrap)"
  else
    bad "user-data.sh no declara set -euo pipefail"
  fi

  if grep -q '/var/log/user-data.log' "$UD"; then
    ok "user-data.sh loguea a /var/log/user-data.log"
  else
    bad "user-data.sh no redirige logs a /var/log/user-data.log"
  fi

  if grep -q 'healthz' "$UD"; then
    ok "user-data.sh menciona health check (healthz)"
  else
    bad "user-data.sh no incluye health check (healthz)"
  fi

  # Sintaxis bash (siempre disponible).
  if bash -n "$UD" 2>/dev/null; then
    ok "user-data.sh pasa bash -n"
  else
    bad "user-data.sh falla bash -n (error de sintaxis)"
  fi

  # shellcheck si existe.
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$UD" >/dev/null 2>&1; then
      ok "user-data.sh pasa shellcheck (nivel warning)"
    else
      bad "user-data.sh no pasa shellcheck (nivel warning)"
    fi
  else
    skip "shellcheck no instalado — omitido"
  fi
fi

# --- 4. EBS-choices.md — contenido ------------------------------------------
if [ -f "$EBS" ]; then
  pieces=0
  for p in gp3 io2 st1 sc1; do
    if grep -qi "$p" "$EBS"; then
      pieces=$((pieces+1))
    fi
  done
  if [ "$pieces" -ge 4 ]; then
    ok "EBS-choices.md menciona los 4 tipos (gp3, io2, st1, sc1)"
  else
    bad "EBS-choices.md menciona solo $pieces de 4 tipos EBS"
  fi

  # Debe haber tabla (al menos 5 filas pipe-separated: header+sep+4 datos).
  rows=$(grep -cE '^\|' "$EBS" || true)
  if [ "$rows" -ge 5 ]; then
    ok "EBS-choices.md tiene tabla (>=5 lineas pipe)"
  else
    bad "EBS-choices.md no tiene tabla legible ($rows lineas pipe)"
  fi

  if grep -qi 'snapshot' "$EBS"; then
    ok "EBS-choices.md menciona snapshots"
  else
    bad "EBS-choices.md no menciona snapshots"
  fi

  # No deben quedar TODOs sin resolver.
  todos=$(grep -c 'TODO' "$EBS" || true)
  if [ "$todos" -eq 0 ]; then
    ok "EBS-choices.md no tiene TODOs pendientes"
  else
    bad "EBS-choices.md tiene $todos TODOs sin resolver"
  fi
fi

# --- 5. Terraform fmt + validate (opcional) ---------------------------------
if command -v terraform >/dev/null 2>&1; then
  if ( cd "$BASE" && terraform fmt -check -diff ) >/dev/null 2>&1; then
    ok "terraform fmt limpio"
  else
    bad "terraform fmt detecta diferencias (corre: terraform fmt)"
  fi

  if ( cd "$BASE" && terraform init -backend=false -input=false ) >/dev/null 2>&1; then
    if ( cd "$BASE" && terraform validate ) >/dev/null 2>&1; then
      ok "terraform validate pasa"
    else
      bad "terraform validate falla (revisa HCL)"
    fi
  else
    skip "terraform init -backend=false fallo (puede ser red / registry)"
  fi
else
  skip "terraform no instalado — fmt/validate omitidos"
fi

# --- Fin ---------------------------------------------------------------------
echo
echo "----"
echo "PASS: $passed   FAIL: $failed   SKIP: $skipped"
if [ "$failed" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
fi
echo "RESULT: FAIL"
exit 1
