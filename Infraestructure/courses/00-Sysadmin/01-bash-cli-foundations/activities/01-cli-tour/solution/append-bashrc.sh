#!/usr/bin/env bash
# Imprime o aplica el fragmento sugerido para ~/.bashrc.
set -euo pipefail
IFS=$'\n\t'

MODE="${1:---preview}"
BASHRC="${BASHRC:-$HOME/.bashrc}"
MARK_BEGIN='# >>> sys-01-01-cli-tour >>>'
MARK_END='# <<< sys-01-01-cli-tour <<<'

read -r -d '' FRAGMENT <<'EOF' || true
# >>> sys-01-01-cli-tour >>>
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend

_prompt_status() {
  local ec=$?
  [ "$ec" -ne 0 ] && printf '\001\e[31m\002(exit=%d)\001\e[0m\002 ' "$ec"
}
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\] $(_prompt_status)\$ '

alias ll='ls -lAh'
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'
# <<< sys-01-01-cli-tour <<<
EOF

case "$MODE" in
  --preview)
    printf '%s\n' "$FRAGMENT"
    ;;
  --apply)
    if grep -qF "$MARK_BEGIN" "$BASHRC" 2>/dev/null; then
      echo "Ya aplicado (marker encontrado en $BASHRC). No se duplica."
      exit 0
    fi
    cp -a "$BASHRC" "${BASHRC}.bak.$(date +%s)" 2>/dev/null || true
    printf '\n%s\n' "$FRAGMENT" >> "$BASHRC"
    echo "Aplicado a $BASHRC. Ejecuta: source $BASHRC"
    ;;
  *)
    echo "Uso: $0 [--preview|--apply]" >&2
    exit 2
    ;;
esac
