#!/usr/bin/env bash
# Reference solution for gh-01-01-config-personal.
# Applies a minimal sane global Git configuration.
#
# Usage:
#   ./apply-config.sh "Your Name" "you@example.com"
#
# The script detects OS and picks sensible defaults for core.autocrlf and credential.helper.
# Edit the EDITOR variable below if you prefer vim/vscode/emacs over nano.

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 \"Your Name\" \"you@example.com\""
  exit 2
fi

NAME="$1"
EMAIL="$2"
EDITOR_CMD="${EDITOR_CMD:-nano}"

OS="$(uname -s)"
case "$OS" in
  Darwin)
    AUTOCRLF="input"
    HELPER="osxkeychain"
    ;;
  Linux)
    AUTOCRLF="input"
    if command -v secret-tool >/dev/null 2>&1; then
      HELPER="libsecret"
    else
      HELPER="cache --timeout=3600"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    AUTOCRLF="true"
    HELPER="manager"
    ;;
  *)
    AUTOCRLF="input"
    HELPER="cache --timeout=3600"
    ;;
esac

echo "Detected OS: $OS → core.autocrlf=$AUTOCRLF  credential.helper=$HELPER"

# Backup if existing
if [ -f "$HOME/.gitconfig" ]; then
  cp "$HOME/.gitconfig" "$HOME/.gitconfig.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backup saved."
fi

# Identity
git config --global user.name  "$NAME"
git config --global user.email "$EMAIL"

# Defaults
git config --global init.defaultBranch   "main"
git config --global pull.rebase          "true"
git config --global push.default         "simple"
git config --global push.autoSetupRemote "true"
git config --global rebase.autoStash     "true"
git config --global color.ui             "auto"
git config --global core.editor          "$EDITOR_CMD"
git config --global core.autocrlf        "$AUTOCRLF"
git config --global credential.helper    "$HELPER"

# A couple of alias niceties (optional)
git config --global alias.co checkout
git config --global alias.st status
git config --global alias.lg "log --graph --oneline --all --decorate"

echo "Applied. Verify:"
echo "  git config --global --list"
