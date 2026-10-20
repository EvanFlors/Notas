#!/bin/sh
# Trivial payload: identifies the image at runtime.
echo "dkr-09 demo image"
echo "hostname: $(hostname)"
echo "date:     $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "args:     $*"
