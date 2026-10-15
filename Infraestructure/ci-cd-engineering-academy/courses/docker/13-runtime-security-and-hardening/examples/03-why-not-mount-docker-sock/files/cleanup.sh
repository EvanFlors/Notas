#!/usr/bin/env bash
set -u
docker rm -f dkr13-ex03-victim dkr13-ex03-escape 2>/dev/null || true
rm -f /tmp/dkr13-ex03-PWNED
rm -rf /tmp/dkr13-ex03
echo "Cleaned."
