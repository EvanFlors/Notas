#!/usr/bin/env bash
# Copy the starter into /tmp/dkr-11-shrink/ so the student can iterate.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
BASE="${1:-/tmp/dkr-11-shrink}"
mkdir -p "$BASE"
cp -R "$HERE"/{app.py,requirements.txt,Dockerfile} "$BASE/"
echo "Starter copied to $BASE"
echo "Now: cd $BASE && docker build -t app:fat . (then rewrite the Dockerfile for app:slim)"
