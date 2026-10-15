#!/usr/bin/env bash
# Simulates "another system already produced an identifier that we now want to
# adopt into Terraform state". For the activity to be reproducible, the id is
# fixed; in real life it would be an ARN, bucket name, resource GUID, etc.

set -eu

ID="AAAAAA"

echo "Pre-existing random_id (base64url, 4 bytes): ${ID}"
echo "Use this exact id in your import block:"
echo
echo "  import {"
echo "    to = random_id.adopted"
echo "    id = \"${ID}\""
echo "  }"
