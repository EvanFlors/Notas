#!/usr/bin/env bash
# Bootstrap the activity: create 3 legacy files + a clean workdir with starter files.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
LEGACY="/tmp/tf14-act01-legacy"
WORKDIR="/tmp/tf14-act01"

rm -rf "$LEGACY" "$WORKDIR"
mkdir -p "$LEGACY" "$WORKDIR"

# Three "legacy" files pretending to be pre-existing production config.
cat > "$LEGACY/app-alpha.conf" <<'EOF'
app=alpha
tier=web
port=9091
EOF

cat > "$LEGACY/app-beta.conf" <<'EOF'
app=beta
tier=api
port=9092
EOF

cat > "$LEGACY/app-gamma.conf" <<'EOF'
app=gamma
tier=worker
port=9093
EOF

chmod 0644 "$LEGACY"/*.conf

# Copy starter files (minus bootstrap.sh itself) to the workdir.
cp "$HERE/versions.tf"       "$WORKDIR/"
cp "$HERE/imports.tf"        "$WORKDIR/"
cp "$HERE/starter-notes.md"  "$WORKDIR/"

echo "legacy infra at:  $LEGACY"
ls -1 "$LEGACY"
echo "workdir at:       $WORKDIR"
echo "next:             cd $WORKDIR && \$EDITOR imports.tf"
