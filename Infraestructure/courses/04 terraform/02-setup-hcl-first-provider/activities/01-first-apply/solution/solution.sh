#!/usr/bin/env bash
# Solucion de referencia para tf-02-01-first-apply.
# Monta /tmp/tf-02-01 con los .tf de solution/ y corre el ciclo entero.
# NO enables pipefail: usamos grep -q en pipes y pipefail provoca falsos negativos.

set -eu

WORK="${WORK_DIR:-/tmp/tf-02-01}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v terraform >/dev/null 2>&1; then
  cat <<EOF
SKIP: 'terraform' no esta instalado. Instala con uno de:
  - brew install terraform                         (macOS)
  - tfenv install latest && tfenv use latest       (tfenv)
  - asdf plugin add terraform && asdf install terraform latest   (asdf)
Verifica: terraform version    (requiere >= 1.5)
EOF
  exit 0
fi

rm -rf "$WORK"
mkdir -p "$WORK"
cp "$HERE/versions.tf" "$HERE/main.tf" "$WORK/"

cd "$WORK"
terraform init -input=false
terraform fmt -check
terraform validate
terraform plan -input=false -out=tfplan
terraform apply -input=false -auto-approve tfplan

cat > "$WORK/notas-lockfile.md" <<'EOF'
# Notas sobre el lockfile

El lockfile `.terraform.lock.hcl` fija la version exacta de cada provider y los
hashes del zip descargado. En este stack aparecen null, random y local.

- Los hashes `h1:` son el formato nuevo (SHA256 por plataforma del zip).
- Los hashes `zh:` son el formato legacy; hay varios porque hay uno por plataforma.
- Si borro el lockfile y corro `init -upgrade`, Terraform resuelve las nuevas
  versions mas altas que mis constraints permitan y escribe hashes nuevos.
  Pierdo reproducibilidad historica.

Mi lockfile actual tiene version y hashes para random, local y null.
EOF

terraform output

echo "----"
echo "Aplicado. Para destruir y limpiar:"
echo "  terraform -chdir=$WORK destroy -auto-approve"
echo "  rm -rf $WORK /tmp/tf-02-01-out"
