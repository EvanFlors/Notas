#!/usr/bin/env bash
# Validate gh-05-02-publish-first-release in MODE=local (default) or MODE=live.
#
# NOTE: deliberately no `set -o pipefail` because `git ... | grep -q ...`
# triggers SIGPIPE (exit 141) on git side when grep exits early.

BASE="${1:-${BASE_DIR:-/tmp/publish-first-release}}"
MODE="${MODE:-local}"
TAG="${TAG:-v0.1.0}"

LOCAL="$BASE/local"
passed=0
failed=0
report=""

note_ok()   { report+="  OK   — $1\n"; passed=$((passed+1)); }
note_fail() { report+="  FAIL — $1\n"; failed=$((failed+1)); }

echo "== Validating ($MODE) under $BASE (tag=$TAG) =="

if [ ! -d "$LOCAL/.git" ]; then
  echo "FAIL: $LOCAL is not a git repo. Run starter/bootstrap.sh first." >&2
  exit 1
fi

cd "$LOCAL"

# ---- Check 1: annotated tag exists locally ----
tag_type="$(git cat-file -t "$TAG" 2>/dev/null || echo missing)"
if [ "$tag_type" = "tag" ]; then
  note_ok "tag $TAG existe y es ANOTADO (git cat-file -t -> tag)"
elif [ "$tag_type" = "commit" ]; then
  note_fail "tag $TAG existe pero es LIGERO; se requiere anotado (usa 'git tag -a')"
else
  note_fail "tag $TAG no existe localmente"
fi

# ---- Check 2: tag has a non-empty message ----
tag_msg="$(git tag -l --format='%(contents:subject)' "$TAG" 2>/dev/null || true)"
if [ -n "$tag_msg" ]; then
  note_ok "tag $TAG tiene mensaje: '$tag_msg'"
else
  note_fail "tag $TAG no tiene mensaje (requiere -m al crearlo con -a)"
fi

# ---- Check 3: tag present on origin ----
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$origin_url" ]; then
  note_fail "remote 'origin' no configurado"
else
  if git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "refs/tags/$TAG"; then
    note_ok "tag $TAG presente en origin"
  else
    note_fail "tag $TAG no está en origin (haz 'git push origin $TAG')"
  fi
fi

# ---- Check 4: asset .tar.gz exists somewhere obvious ----
ASSET=""
for candidate in \
    "$BASE/$TAG.tar.gz" \
    "$BASE/releases/$TAG/"*.tar.gz \
    "$LOCAL/../$TAG.tar.gz" ; do
  if [ -f "$candidate" ]; then
    ASSET="$candidate"
    break
  fi
done
if [ -n "$ASSET" ]; then
  note_ok "asset encontrado: $ASSET"
  # ---- Check 5: tar.gz is valid and does NOT contain .git/ ----
  if tar -tzf "$ASSET" >/dev/null 2>&1; then
    if tar -tzf "$ASSET" 2>/dev/null | grep -q '\.git/' ; then
      note_fail "asset $ASSET contiene '.git/' (debe excluirse)"
    else
      note_ok "asset $ASSET es válido y NO contiene .git/"
    fi
  else
    note_fail "asset $ASSET no es un tar.gz válido"
  fi
else
  note_fail "no se encontró asset .tar.gz (esperado en $BASE/$TAG.tar.gz o $BASE/releases/$TAG/)"
fi

# ---- Check 6: working tree clean ----
if [ -z "$(git status --porcelain)" ]; then
  note_ok "working tree limpio"
else
  note_fail "working tree sucio"
fi

# ---- Check 7: release-level checks (mode-specific) ----
if [ "$MODE" = "local" ]; then
  NOTES="$BASE/releases/$TAG/NOTES.md"
  if [ -f "$NOTES" ] && [ -s "$NOTES" ]; then
    note_ok "notas simuladas presentes: $NOTES"
  else
    note_fail "faltan notas simuladas en $NOTES"
  fi
  # Also: at least one asset under releases/<tag>/
  release_assets=$(ls -1 "$BASE/releases/$TAG/"*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
  if [ "${release_assets:-0}" -ge 1 ]; then
    note_ok "al menos 1 asset bajo releases/$TAG/"
  else
    note_fail "no hay assets bajo $BASE/releases/$TAG/"
  fi
elif [ "$MODE" = "live" ]; then
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    note_fail "gh CLI faltante o no autenticado"
  else
    # Deduce repo slug from origin URL
    repo_slug=""
    case "$origin_url" in
      git@github.com:*)       repo_slug="${origin_url#git@github.com:}";;
      https://github.com/*)   repo_slug="${origin_url#https://github.com/}";;
      ssh://git@github.com/*) repo_slug="${origin_url#ssh://git@github.com/}";;
    esac
    repo_slug="${repo_slug%.git}"
    if [ -z "$repo_slug" ]; then
      note_fail "no se pudo deducir owner/repo de origin"
    else
      if gh release view "$TAG" --repo "$repo_slug" >/dev/null 2>&1; then
        note_ok "GitHub release $TAG existe en $repo_slug"
        asset_count="$(gh release view "$TAG" --repo "$repo_slug" --json assets --jq '.assets | length' 2>/dev/null || echo 0)"
        if [ "${asset_count:-0}" -ge 1 ]; then
          note_ok "release $TAG tiene $asset_count asset(s)"
        else
          note_fail "release $TAG no tiene assets"
        fi
      else
        note_fail "no existe release $TAG en $repo_slug"
      fi
    fi
  fi
else
  note_fail "MODE desconocido: '$MODE'"
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
