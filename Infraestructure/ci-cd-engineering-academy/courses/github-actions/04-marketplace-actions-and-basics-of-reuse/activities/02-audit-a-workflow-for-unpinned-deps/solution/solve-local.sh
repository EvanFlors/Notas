#!/usr/bin/env bash
# Reference solution for gha-04-02-audit-a-workflow-for-unpinned-deps.
# Runs bootstrap, writes AUDIT.md, then rewrites both workflows to be fully pinned.
set -euo pipefail

BASE="${1:-/tmp/gha-04-02-audit-a-workflow-for-unpinned-deps}"
HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/../starter/bootstrap.sh" "$BASE"

# ---------- AUDIT.md ----------
cat > "$BASE/repo/AUDIT.md" <<'EOF'
# Auditoría de workflows

Hallazgos de `.github/workflows/` antes del fix.

| archivo      | línea | owner/repo             | ref actual         | tipo             | riesgo                                                    | acción                                 |
|--------------|-------|------------------------|--------------------|------------------|-----------------------------------------------------------|----------------------------------------|
| ci.yml       | ~11   | actions/checkout       | @main              | branch pin       | HIGH — HEAD mutable, cambia sin aviso                     | pin a SHA, versión v4.2.2              |
| ci.yml       | ~15   | actions/setup-python   | @v5                | major tag        | MED — tag reescribible por el maintainer                  | pin a SHA, versión v5.3.0              |
| ci.yml       | ~26   | actions/checkout       | @master            | branch pin       | HIGH — HEAD mutable                                       | pin a SHA, versión v4.2.2              |
| ci.yml       | ~29   | actions/setup-node     | @v4.1.0            | exact tag (no SHA) | MED — tag exacto todavía mutable                        | pin a SHA, versión v4.1.0              |
| ci.yml       | ~35   | actions/cache          | @6849a64... (SHA)  | SHA sin comentario | LOW — seguro, pero inmantenible (Dependabot no sabe)    | añadir comentario `# v4.1.2`           |
| release.yml  | ~12   | actions/checkout       | @main              | branch pin       | HIGH                                                      | pin a SHA, versión v4.2.2              |
| release.yml  | ~15   | actions/upload-artifact| @v4                | major tag        | MED                                                       | pin a SHA, versión v4.4.3              |

## Resumen

- 7 hallazgos totales en 2 archivos.
- 3 HIGH (branch pins), 3 MED (tag pins), 1 LOW (SHA sin comentario).
- Ninguna de las actions es de un tercero desconocido: todas son `actions/*` oficiales.
  Aun así, la política de la org exige pin a SHA + comentario.

## Ejemplo del riesgo del tag mutable

En marzo de 2025 la action `tj-actions/changed-files` fue comprometida: alguien
reescribió sus tags para apuntar a un commit malicioso que exfiltraba
`GITHUB_TOKEN` por los logs. Los pipelines que la usaban como `@v45` ejecutaron
el payload sin cambiar una sola línea propia. Los que la usaban con pin a SHA
no se vieron afectados. La corrección post-incidente para esta auditoría es
idéntica: todo pin a SHA + Dependabot con revisión manual de PRs.
EOF

# ---------- ci.yml (fixed) ----------
cat > "$BASE/repo/.github/workflows/ci.yml" <<'EOF'
name: CI (fixed)

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0
        with:
          python-version: '3.12'

      - run: echo "lint..."

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af  # v4.1.0
        with:
          node-version: '20'

      - uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2
        with:
          path: ~/.cache/pip
          key: pip-${{ hashFiles('**/requirements*.txt') }}

      - run: echo "test..."
EOF

# ---------- release.yml (fixed) ----------
cat > "$BASE/repo/.github/workflows/release.yml" <<'EOF'
name: Release (fixed)

on:
  push:
    tags: ['v*']

permissions:
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882  # v4.4.3
        with:
          name: dist
          path: dist/
EOF

echo
echo "== Solution written =="
echo "  $BASE/repo/AUDIT.md"
echo "  $BASE/repo/.github/workflows/ci.yml"
echo "  $BASE/repo/.github/workflows/release.yml"
