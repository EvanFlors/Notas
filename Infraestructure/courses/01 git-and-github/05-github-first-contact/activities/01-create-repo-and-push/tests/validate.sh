#!/usr/bin/env bash
# Validate gh-05-01-create-repo-and-push in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail` because many checks use
# `... | grep -q ...` on long-producing commands (git log) which can
# produce SIGPIPE (exit 141) and would be mis-reported as failures.

BASE="${1:-${BASE_DIR:-/tmp/create-repo-and-push}}"
MODE="${MODE:-local}"

LOCAL="$BASE/local"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE =="

if [ ! -d "$LOCAL/.git" ]; then
  echo "FAIL: $LOCAL is not a git repo. Run starter/bootstrap.sh first." >&2
  exit 1
fi

cd "$LOCAL"

# ---- Check 1: README with required headings ----
if [ -f README.md ]; then
  if head -1 README.md | grep -Eq '^# .+' \
     && grep -q '^## Instalación' README.md \
     && grep -q '^## Uso' README.md \
     && grep -q '^## Licencia' README.md; then
    note_ok "README.md tiene '# <titulo>', '## Instalación', '## Uso' y '## Licencia'"
  else
    note_fail "README.md no tiene las 4 secciones requeridas (# titulo / ## Instalación / ## Uso / ## Licencia)"
  fi
else
  note_fail "README.md no existe"
fi

# ---- Check 2: LICENSE present and MIT-ish ----
if [ -f LICENSE ]; then
  if grep -q 'MIT License' LICENSE || grep -q 'Permission is hereby granted' LICENSE; then
    note_ok "LICENSE contiene texto MIT reconocible"
  else
    note_fail "LICENSE no contiene 'MIT License' ni 'Permission is hereby granted'"
  fi
else
  note_fail "LICENSE no existe"
fi

# ---- Check 3: .gitignore present and non-empty ----
if [ -s .gitignore ]; then
  if grep -q 'PLACEHOLDER' .gitignore; then
    note_fail ".gitignore todavía contiene PLACEHOLDER (reemplázalo)"
  else
    note_ok ".gitignore existe y no es placeholder"
  fi
else
  note_fail ".gitignore no existe o está vacío"
fi

# ---- Check 4: at least one commit beyond the base commit ----
commit_count="$(git rev-list --count main 2>/dev/null || echo 0)"
if [ "$commit_count" -ge 2 ]; then
  note_ok "main tiene $commit_count commits (>=2: base + al menos uno nuevo)"
else
  note_fail "main solo tiene $commit_count commit(s); se esperan >=2"
fi

# ---- Check 5: working tree clean ----
if [ -z "$(git status --porcelain)" ]; then
  note_ok "working tree limpio"
else
  note_fail "working tree sucio (hay cambios no commiteados)"
fi

# ---- Check 6: origin remote configured ----
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ -n "$origin_url" ]; then
  note_ok "remote 'origin' configurado ($origin_url)"
else
  note_fail "remote 'origin' no configurado"
fi

# ---- Check 7: push happened (mode-specific) ----
local_head="$(git rev-parse main 2>/dev/null || echo '')"

if [ "$MODE" = "local" ]; then
  BARE="$BASE/origin.git"
  if [ ! -d "$BARE" ]; then
    note_fail "no existe bare remote en $BARE (bootstrap no se ejecutó en MODE=local)"
  else
    remote_head="$(git --git-dir="$BARE" rev-parse refs/heads/main 2>/dev/null || echo '')"
    if [ -n "$remote_head" ] && [ "$remote_head" = "$local_head" ]; then
      note_ok "bare origin tiene main apuntando al mismo commit que local ($local_head)"
    else
      note_fail "bare origin no tiene main en el mismo commit (local=$local_head, remote=$remote_head). ¿Hiciste 'git push -u origin main'?"
    fi
  fi
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    note_fail "gh CLI no instalado"
  elif ! gh auth status >/dev/null 2>&1; then
    note_fail "gh no autenticado"
  else
    # Extract owner/repo from origin URL. Support both forms.
    repo_slug=""
    case "$origin_url" in
      git@github.com:*)       repo_slug="${origin_url#git@github.com:}";;
      https://github.com/*)   repo_slug="${origin_url#https://github.com/}";;
      ssh://git@github.com/*) repo_slug="${origin_url#ssh://git@github.com/}";;
    esac
    repo_slug="${repo_slug%.git}"
    if [ -z "$repo_slug" ]; then
      note_fail "no se pudo deducir owner/repo de origin ('$origin_url')"
    else
      remote_sha="$(gh api "repos/$repo_slug/git/refs/heads/main" --jq '.object.sha' 2>/dev/null || echo '')"
      if [ -n "$remote_sha" ] && [ "$remote_sha" = "$local_head" ]; then
        note_ok "GitHub repos/$repo_slug main=$remote_sha coincide con local"
      else
        note_fail "GitHub repos/$repo_slug main no coincide o no accesible (local=$local_head, remote=$remote_sha)"
      fi
    fi
  fi
else
  note_fail "MODE desconocido: '$MODE' (use 'local' o 'live')"
fi

echo
printf "%b" "$report"
echo
total=$((passed + failed))
echo "RESULT ($MODE): $passed/$total checks OK."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
