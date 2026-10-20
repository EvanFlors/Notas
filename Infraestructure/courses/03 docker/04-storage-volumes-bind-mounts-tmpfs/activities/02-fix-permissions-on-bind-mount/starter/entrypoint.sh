#!/bin/sh
set -eu
# Strict ownership check: the directory mounted at /output must be owned by
# UID 1000 (the user this container runs as). This is intentional — many
# real services behave the same way (postgres, mysql, nats, etc).
owner_uid="$(stat -c %u /output)"
if [ "$owner_uid" != "1000" ]; then
  echo "ERROR: /output is owned by UID=$owner_uid, this container runs as UID=1000."
  echo "       Fix the host-side ownership and re-run."
  exit 1
fi
# Also verify we can actually write (defense in depth).
if ! : > /output/.write-probe 2>/dev/null; then
  echo "ERROR: cannot write to /output even though uid is $owner_uid."
  exit 1
fi
rm -f /output/.write-probe
echo "wrote-from-uid-1000" > /output/report.txt
cat /output/report.txt
