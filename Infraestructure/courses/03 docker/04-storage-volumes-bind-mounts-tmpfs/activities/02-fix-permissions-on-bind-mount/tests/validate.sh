#!/usr/bin/env bash
# dkr-04-02 — validator for the permission fix.
# Pass criteria:
#   - /tmp/dkr04-02-output/report.txt exists.
#   - Its content equals exactly 'wrote-from-uid-1000'.
#   - The host dir is NOT 0777 (we reject the chmod-777 cheat).
#   - The writer image is still present (student did not rebuild to a different user).
#
# NOTE: deliberately no `set -o pipefail` so grep -q short-circuits don't
# propagate SIGPIPE as a validator failure.

set -eu

HOST_DIR="/tmp/dkr04-02-output"
FILE="$HOST_DIR/report.txt"
IMAGE="dkr04-02-writer:latest"
EXPECTED="wrote-from-uid-1000"

passed=0
failed=0
report=""

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker CLI not installed."
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon not reachable."
  exit 0
fi

# 1. report.txt exists.
if [ -f "$FILE" ]; then
  report+="report.txt exists: OK\n"; passed=$((passed+1))
else
  report+="report.txt exists: FAIL (run bash starter/run-broken.sh after your fix)\n"
  failed=$((failed+1))
fi

# 2. content matches.
if [ -f "$FILE" ] && [ "$(cat "$FILE")" = "$EXPECTED" ]; then
  report+="report.txt content == '$EXPECTED': OK\n"; passed=$((passed+1))
else
  report+="report.txt content == '$EXPECTED': FAIL\n"; failed=$((failed+1))
fi

# 3. host dir is not world-writable 0777.
if [ -d "$HOST_DIR" ]; then
  perms_octal="$(stat -f '%Lp' "$HOST_DIR" 2>/dev/null || stat -c '%a' "$HOST_DIR" 2>/dev/null || echo "")"
  if [ "$perms_octal" = "777" ]; then
    report+="Host dir perms != 0777: FAIL (chmod 777 is the forbidden cheat)\n"
    failed=$((failed+1))
  else
    report+="Host dir perms != 0777 (got $perms_octal): OK\n"; passed=$((passed+1))
  fi
else
  report+="Host dir perms check: FAIL (dir missing)\n"; failed=$((failed+1))
fi

# 4. The original image is still present (student didn't change it).
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  # Also verify USER layer is still 1000 — reject rebuilds that softened the image.
  user_cfg="$(docker image inspect "$IMAGE" --format '{{.Config.User}}')"
  if [ "$user_cfg" = "1000" ]; then
    report+="Image $IMAGE still runs as USER=1000: OK\n"; passed=$((passed+1))
  else
    report+="Image $IMAGE USER changed (got '$user_cfg', expected '1000'): FAIL\n"
    failed=$((failed+1))
  fi
else
  report+="Image $IMAGE present: FAIL\n"; failed=$((failed+1))
fi

echo
printf "%b" "$report"
echo
total=$((passed+failed))
echo "RESULT: $passed/$total checks OK."
[ "$failed" -eq 0 ] || exit 1
exit 0
