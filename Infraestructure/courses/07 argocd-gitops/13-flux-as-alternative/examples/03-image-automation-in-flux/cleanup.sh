#!/usr/bin/env bash
set -eu
CLUSTER="flux-ex03"
PIDFILE="/tmp/flux-ex03-daemon.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")" || true
fi
rm -f "$PIDFILE"
if command -v kind >/dev/null && kind get clusters | grep -qx "$CLUSTER"; then
  kind delete cluster --name "$CLUSTER"
fi
rm -rf /tmp/flux-ex03-repo /tmp/flux-ex03-serve
echo "[ex03] cleaned up."
