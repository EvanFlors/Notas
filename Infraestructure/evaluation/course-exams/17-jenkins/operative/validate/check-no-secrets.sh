#!/usr/bin/env bash
# check-no-secrets.sh — detector heurístico de secretos literales en el entregable.
# Falla si encuentra patrones típicos: AKIA..., ghp_..., private keys inline,
# password/token = "..." con un literal razonable (no placeholder).
#
# Uso:  bash check-no-secrets.sh submission/

set -u
DIR="${1:-.}"
if [[ ! -d "$DIR" ]]; then
  echo "ERROR: pasa un directorio como primer argumento." >&2
  exit 2
fi

PATTERNS=(
  'AKIA[0-9A-Z]{16}'                            # AWS access key id
  'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{20,}' # AWS secret
  'ghp_[A-Za-z0-9]{30,}'                        # GitHub PAT classic
  'github_pat_[A-Za-z0-9_]{30,}'                # GitHub fine-grained
  'xox[baprs]-[A-Za-z0-9-]{10,}'                # Slack
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  '(password|passwd|secret|token|api[_-]?key)\s*[:=]\s*["\x27][^"\x27$]{8,}["\x27]'
)

FOUND=0
while IFS= read -r -d '' f; do
  for pat in "${PATTERNS[@]}"; do
    if grep -EnI "$pat" "$f" >/dev/null 2>&1; then
      echo "FAIL  posible secreto en $f (patrón: $pat)"
      grep -EnI --color=never "$pat" "$f" | sed 's/^/      /'
      FOUND=1
    fi
  done
done < <(find "$DIR" -type f \( -name '*.yaml' -o -name '*.yml' -o -name 'Jenkinsfile*' -o -name '*.groovy' -o -name '*.sh' -o -name '*.md' \) -print0)

if [[ "$FOUND" -eq 0 ]]; then
  echo "PASS  no se detectaron secretos literales (heurística)."
  exit 0
fi
exit 1
