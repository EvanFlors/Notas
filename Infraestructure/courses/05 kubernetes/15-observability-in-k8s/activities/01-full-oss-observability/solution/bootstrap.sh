#!/usr/bin/env bash
# solution: identical to starter/bootstrap.sh — the starter already contains the
# "solved" shape (all TODOs filled). The exercise value is in RUNNING it and
# understanding each step, not in filling blanks. Kept here for parity with
# other activities that have divergent starter vs solution.
set -u
exec bash "$(cd "$(dirname "$0")/../starter" && pwd)/bootstrap.sh" "$@"
