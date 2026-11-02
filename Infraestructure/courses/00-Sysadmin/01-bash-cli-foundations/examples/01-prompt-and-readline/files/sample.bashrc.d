#!/usr/bin/env bash
# sample.bashrc.d — fragmento de referencia para incluir en ~/.bashrc
# NO se ejecuta directamente; es material para copiar.
# shellcheck shell=bash

# ---------- Prompt ----------
_prompt_status() {
  local ec=$?
  if [ "$ec" -ne 0 ]; then
    printf '\001\e[31m\002(exit=%d)\001\e[0m\002 ' "$ec"
  fi
}

_prompt_git_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) || return 0
  printf '\001\e[33m\002(%s)\001\e[0m\002 ' "$b"
}

PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\] $(_prompt_git_branch)$(_prompt_status)\$ '

# ---------- Historial ----------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
HISTTIMEFORMAT='%F %T '
HISTIGNORE='ls:ll:pwd:cd:history:clear'
shopt -s histappend
shopt -s cmdhist

# ---------- Aliases útiles ----------
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -I'

# ---------- Readline ----------
# Tecla Ctrl-S deja de congelar la terminal.
stty -ixon 2>/dev/null || true
