#!/usr/bin/env bash
# Validate: student investigated the OOMKilled container.
# Linux-only. Prints SKIP on non-Linux and exits 0.
#
# No `set -o pipefail` — grep -q with pipes may cause SIGPIPE (141).

set -eu

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  cat <<EOF
SKIP: dkr-10 is Linux-only (uname -s = $OS).

Launch a Linux VM and re-run inside it:
  multipass launch --name dkr10 --cpus 2 --memory 2G --disk 10G 22.04
  multipass shell dkr10

Exit 0 here means skipped, not passed.
EOF
  exit 0
fi

OUT="/tmp/oom-investigation"
fail=0
echo "== Validating dkr-10-02-why-is-my-app-oomkilled =="

# Container must exist and be exited with 137 + OOMKilled
if ! docker inspect oom-victim >/dev/null 2>&1; then
  echo "  FAIL container 'oom-victim' does not exist. Did you run starter/run-broken.sh?"
  exit 1
fi

state_exit="$(docker inspect oom-victim --format '{{.State.ExitCode}}' 2>/dev/null)"
state_oom="$(docker inspect oom-victim --format '{{.State.OOMKilled}}' 2>/dev/null)"
if [ "$state_exit" = "137" ]; then
  echo "  OK   container ExitCode = 137"
else
  echo "  FAIL container ExitCode = '$state_exit' (expected 137)"
  fail=$((fail+1))
fi
if [ "$state_oom" = "true" ]; then
  echo "  OK   container OOMKilled = true"
else
  echo "  FAIL container OOMKilled = '$state_oom' (expected true)"
  fail=$((fail+1))
fi

# Investigation artifacts
if [ -f "$OUT/inspect.json" ]; then
  echo "  OK   $OUT/inspect.json present"
else
  echo "  FAIL $OUT/inspect.json missing"
  fail=$((fail+1))
fi

if [ -f "$OUT/root-cause.md" ]; then
  echo "  OK   $OUT/root-cause.md present"
  rc="$OUT/root-cause.md"
  missing=""
  for phrase in "ExitCode 137" "SIGKILL" "OOMKilled" "memory.max" "oom_kill"; do
    if grep -qiF "$phrase" "$rc"; then
      echo "       - mentions: $phrase"
    else
      missing="$missing \"$phrase\""
    fi
  done
  if [ -n "$missing" ]; then
    echo "  FAIL root-cause.md missing required phrases:$missing"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $OUT/root-cause.md missing — write the root cause analysis"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: dkr-10-02 completed."
exit 0
