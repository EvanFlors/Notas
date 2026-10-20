#!/usr/bin/env bash
# Demo automatizado de rebase -i: 5 commits sucios -> 2 commits limpios.
# Usa GIT_SEQUENCE_EDITOR para editar el todo file sin abrir editor.
set -euo pipefail

REPO="${1:-/tmp/rebase-interactive-demo-auto}"
rm -rf "$REPO"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# -------- Commit base --------
echo "# Payments module" > README.md
git add README.md
git commit -q -m "init: payments module scaffold"

# -------- 5 commits sucios --------
cat > payments.py <<'EOF'
def refnd(amount):
    return {"status": "pending", "amount": amount}
EOF
git add payments.py
git commit -q -m "wip"

# Reescribir in-place para evitar diferencias sed BSD/GNU: usamos python
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("refnd", "refund"))
PY
git commit -q -am "typo"

mkdir -p tests
cat > tests/test_payments.py <<'EOF'
from payments import refund


def test_refund_pending():
    assert refund(10)["status"] == "accepted"
EOF
git add tests/test_payments.py
git commit -q -m "add tests"

python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
header = "# Copyright 2026 Acme Inc. SPDX-License-Identifier: Apache-2.0\n"
p.write_text(header + p.read_text())
PY
git commit -q -am "oops forgot header"

python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.py")
p.write_text(p.read_text().replace("pending", "accepted"))
PY
git commit -q -am "fix typo again"

echo
echo "===== Historia ANTES del rebase ====="
git log --oneline
echo

# -------- Plan del rebase -------- #
# Objetivo:
#   commit 1 "feat(payments): add refund processor"  <- wip + 3 fixups
#   commit 2 "test(payments): cover refund processor" <- del 'add tests'
#
# Todo file resultante (contenido textual exacto):
#
#   pick <h1> wip
#   fixup <h2> typo
#   pick <h3> add tests
#   fixup <h4> oops forgot header
#   fixup <h5> fix typo again
#
# El "add tests" queda en posición 3 porque corresponde al commit "add tests"
# original; los dos fixups posteriores son del scaffold y pertenecen al pick 1
# — pero el plan de rebase los lee en orden; para que apliquen al commit de
# scaffold necesitamos reordenar. La forma más clara: reorganizar así:
#
#   pick <h1> wip
#   fixup <h2> typo
#   fixup <h4> oops forgot header
#   fixup <h5> fix typo again
#   pick <h3> add tests
#
# Luego reword de ambos picks (dos pases) para fijar los mensajes finales.

PLAN_SCRIPT=$(cat <<'SH'
#!/usr/bin/env bash
set -euo pipefail
todo="$1"
# Extraer solo las lineas de accion (no comentarios)
mapfile -t lines < <(grep -E '^(pick|p) ' "$todo")

# Buscar por subject para reordenar
line_wip=""
line_typo=""
line_tests=""
line_header=""
line_typo2=""
for l in "${lines[@]}"; do
  case "$l" in
    *" wip") line_wip="$l" ;;
    *" typo") line_typo="$l" ;;
    *" add tests") line_tests="$l" ;;
    *" oops forgot header") line_header="$l" ;;
    *" fix typo again") line_typo2="$l" ;;
  esac
done

{
  echo "pick ${line_wip#pick }"
  echo "fixup ${line_typo#pick }"
  echo "fixup ${line_header#pick }"
  echo "fixup ${line_typo2#pick }"
  echo "pick ${line_tests#pick }"
} > "$todo"
SH
)

PLAN_FILE="$(mktemp)"
printf "%s" "$PLAN_SCRIPT" > "$PLAN_FILE"
chmod +x "$PLAN_FILE"

# Primer rebase: colapsar y reordenar.
GIT_SEQUENCE_EDITOR="$PLAN_FILE" git rebase -i HEAD~5
rm -f "$PLAN_FILE"

echo
echo "===== Historia tras colapsar/reordenar ====="
git log --oneline
echo

# Segundo rebase: reword de ambos commits (actualmente llevan subjects
# "wip" y "add tests") para dejarlos como feat(...) y test(...).
REWORD_PLAN=$(cat <<'SH'
#!/usr/bin/env bash
set -euo pipefail
todo="$1"
sed -i.bak 's/^pick/reword/' "$todo"
rm -f "${todo}.bak"
SH
)
REWORD_PLAN_FILE="$(mktemp)"
printf "%s" "$REWORD_PLAN" > "$REWORD_PLAN_FILE"
chmod +x "$REWORD_PLAN_FILE"

# Editor que decide el nuevo mensaje segun el actual: lee la primera linea
# del archivo de commit message y, si contiene "wip", lo reemplaza por feat;
# si contiene "add tests", por test(...).
MSG_EDITOR=$(cat <<'SH'
#!/usr/bin/env bash
set -euo pipefail
msgfile="$1"
first=$(head -n1 "$msgfile")
case "$first" in
  wip) new="feat(payments): add refund processor" ;;
  "add tests") new="test(payments): cover refund processor" ;;
  *) new="$first" ;;
esac
# Reemplazar primera linea manteniendo el resto (comentarios).
printf "%s\n" "$new" > "${msgfile}.tmp"
tail -n +2 "$msgfile" >> "${msgfile}.tmp"
mv "${msgfile}.tmp" "$msgfile"
SH
)
MSG_EDITOR_FILE="$(mktemp)"
printf "%s" "$MSG_EDITOR" > "$MSG_EDITOR_FILE"
chmod +x "$MSG_EDITOR_FILE"

GIT_SEQUENCE_EDITOR="$REWORD_PLAN_FILE" \
GIT_EDITOR="$MSG_EDITOR_FILE" \
  git rebase -i HEAD~2

rm -f "$REWORD_PLAN_FILE" "$MSG_EDITOR_FILE"

echo
echo "===== Historia FINAL ====="
git log --oneline
echo
echo "Esperado: 2 commits sobre 'init: payments module scaffold'."
echo "  - feat(payments): add refund processor"
echo "  - test(payments): cover refund processor"
