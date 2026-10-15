#!/usr/bin/env bash
# Validate: student completed dkr-10-01-build-container-with-unshare.
# Linux-only. On non-Linux, prints SKIP + VM instructions and exits 0.
#
# Note: no `set -o pipefail`; we deliberately use `grep -q` with pipes and
# pipefail would mark SIGPIPE (141) from early grep matches as a failure.

set -eu

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  cat <<EOF
SKIP: dkr-10 is a Linux-only module (uname -s = $OS).

To run this activity on macOS/Windows, launch a Linux VM and run inside it:

  # Option A: multipass (recommended on macOS)
  multipass launch --name dkr10 --cpus 2 --memory 2G --disk 10G 22.04
  multipass shell dkr10

  # Option B: Vagrant
  mkdir -p ~/dkr10 && cd ~/dkr10
  vagrant init ubuntu/jammy64 && vagrant up && vagrant ssh

Then install docker + util-linux in the VM, re-run the activity and re-run this
validator. Exit code 0 here means "skipped", not "passed".
EOF
  exit 0
fi

ROOTFS="/tmp/mini-rootfs"
NOTES="/tmp/mini-notes"
CG="/sys/fs/cgroup/mini"
fail=0

echo "== Validating dkr-10-01-build-container-with-unshare =="

# cgroup v2 unified
CG_TYPE="$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo unknown)"
if [ "$CG_TYPE" = "cgroup2fs" ]; then
  echo "  OK   cgroup v2 unified hierarchy"
else
  echo "  FAIL /sys/fs/cgroup type is '$CG_TYPE' (expected cgroup2fs)"
  fail=$((fail+1))
fi

# rootfs present
if [ -x "$ROOTFS/bin/busybox" ] || [ -x "$ROOTFS/bin/sh" ]; then
  echo "  OK   rootfs exported at $ROOTFS"
else
  echo "  FAIL rootfs not present at $ROOTFS (did you export busybox?)"
  fail=$((fail+1))
fi

# cgroup present with correct limits
if [ -d "$CG" ]; then
  echo "  OK   cgroup exists: $CG"
  mem_max="$(cat "$CG/memory.max" 2>/dev/null || echo missing)"
  if [ "$mem_max" = "67108864" ]; then
    echo "  OK   memory.max = 67108864 (64 MiB)"
  else
    echo "  FAIL memory.max = '$mem_max' (expected 67108864)"
    fail=$((fail+1))
  fi
  pids_max="$(cat "$CG/pids.max" 2>/dev/null || echo missing)"
  if [ "$pids_max" = "50" ]; then
    echo "  OK   pids.max = 50"
  else
    echo "  FAIL pids.max = '$pids_max' (expected 50)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL cgroup $CG does not exist"
  fail=$((fail+1))
fi

# Evidence directory
if [ -d "$NOTES" ]; then
  echo "  OK   notes dir exists: $NOTES"
else
  echo "  FAIL $NOTES missing"
  fail=$((fail+1))
fi

# memory.events shows oom_kill >= 1
if [ -f "$NOTES/memory.events" ]; then
  oom_kill_line="$(grep '^oom_kill ' "$NOTES/memory.events" || true)"
  oom_kill_count="$(echo "$oom_kill_line" | awk '{print $2}')"
  if [ -n "$oom_kill_count" ] && [ "$oom_kill_count" -ge 1 ] 2>/dev/null; then
    echo "  OK   memory.events: oom_kill=$oom_kill_count (>=1)"
  else
    echo "  FAIL memory.events has no oom_kill>=1 (got: '$oom_kill_line')"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $NOTES/memory.events missing — did you capture evidence?"
  fail=$((fail+1))
fi

# lsns shows at least 5 distinct namespaces for the pid
if [ -f "$NOTES/lsns.txt" ]; then
  ns_count="$(awk 'NR>1 {print $2}' "$NOTES/lsns.txt" | sort -u | wc -l)"
  if [ "$ns_count" -ge 5 ]; then
    echo "  OK   lsns.txt lists $ns_count distinct namespace types"
  else
    echo "  FAIL lsns.txt lists only $ns_count namespace types (expected >=5)"
    fail=$((fail+1))
  fi
else
  echo "  FAIL $NOTES/lsns.txt missing"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail check(s) failed."
  exit 1
fi
echo "OK: dkr-10-01 completed."
exit 0
