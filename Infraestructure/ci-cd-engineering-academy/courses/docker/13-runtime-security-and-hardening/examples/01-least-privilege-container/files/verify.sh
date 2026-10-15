#!/usr/bin/env bash
# Verify the six hardening controls on a running container.
# NOTE: no `set -o pipefail` because downstream `grep -q` can SIGPIPE producers.
set -u

NAME="${1:-dkr13-ex01-hardened}"

if ! docker inspect "$NAME" >/dev/null 2>&1; then
  echo "ERROR: container '$NAME' not found." >&2
  exit 1
fi

echo "== Config del contenedor $NAME =="
printf "  Config.User:               %s\n" "$(docker inspect "$NAME" --format '{{.Config.User}}')"
printf "  HostConfig.ReadonlyRootfs: %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.ReadonlyRootfs}}')"
printf "  HostConfig.CapDrop:        %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.CapDrop}}')"
printf "  HostConfig.CapAdd:         %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.CapAdd}}')"
printf "  HostConfig.SecurityOpt:    %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.SecurityOpt}}')"
printf "  HostConfig.Memory (bytes): %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.Memory}}')"
printf "  HostConfig.PidsLimit:      %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.PidsLimit}}')"
printf "  HostConfig.NanoCpus:       %s\n" "$(docker inspect "$NAME" --format '{{.HostConfig.NanoCpus}}')"

echo
echo "== Chequeos desde adentro =="
echo "  id:        $(docker exec "$NAME" id 2>&1 || echo 'exec failed')"
echo "  NoNewPrivs:$(docker exec "$NAME" sh -c "grep NoNewPrivs /proc/self/status | awk '{print \$2}'" 2>&1)"
echo "  Seccomp:   $(docker exec "$NAME" sh -c "grep Seccomp /proc/self/status | head -1 | awk '{print \$2}'" 2>&1)"

echo
echo "== Test de que read-only funciona =="
out="$(docker exec "$NAME" sh -c 'touch /etc/foo 2>&1 || true')"
if printf '%s' "$out" | grep -q -i "read-only"; then
  echo "  touch /etc/foo -> OK: 'Read-only file system' (EROFS) tal como esperado"
else
  echo "  touch /etc/foo -> UNEXPECTED: $out  (es read-only el FS?)"
fi
