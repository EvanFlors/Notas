#!/usr/bin/env bash
# Create three "legacy" config files that pretend to be pre-existing infra.
set -eu

DIR="/tmp/tf14-ex02-legacy"
mkdir -p "$DIR"

cat > "$DIR/alpha.conf" <<'EOF'
service=alpha
port=8081
EOF

cat > "$DIR/beta.conf" <<'EOF'
service=beta
port=8082
EOF

cat > "$DIR/gamma.conf" <<'EOF'
service=gamma
port=8083
EOF

chmod 0644 "$DIR"/*.conf

echo "created legacy files at $DIR:"
ls -1 "$DIR"
