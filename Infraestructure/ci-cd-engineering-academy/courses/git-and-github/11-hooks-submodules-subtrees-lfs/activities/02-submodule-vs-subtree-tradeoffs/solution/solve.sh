#!/usr/bin/env bash
# Reference solution for gh-11-02-submodule-vs-subtree-tradeoffs.
# Builds both super-repos and writes a non-trivial ADR.md recommending subtree
# for the described scenario (small team, actively modifies the dependency).
set -euo pipefail

BASE="${1:-/tmp/adr-sub-vs-tree}"

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/../starter/build-scenario.sh" "$BASE"

gc() { git -c user.name=You -c user.email=you@example.com "$@"; }

# ---------- super-sub (SUBMODULE) ----------
mkdir "$BASE/scratch/super-sub"
cd "$BASE/scratch/super-sub"
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
gc add .
gc commit -q -m "init: super"
gc -c protocol.file.allow=always submodule add -q "$BASE/upstream" vendor/libgreet
gc commit -q -m "chore: add libgreet as submodule"

# ---------- super-tree (SUBTREE) ----------
mkdir "$BASE/scratch/super-tree"
cd "$BASE/scratch/super-tree"
git init -q -b main
cat > app.py <<'EOF'
from vendor.libgreet.greet import greet
print(greet("world"))
EOF
gc add .
gc commit -q -m "init: super"
gc subtree add --prefix=vendor/libgreet "$BASE/upstream" main --squash -q

# ---------- ADR ----------
cat > "$BASE/ADR.md" <<'EOF'
# ADR-001: Submodule vs Subtree para libgreet

## Status
Accepted

## Context
`super-app` depende de `libgreet`, una librería interna mantenida por el mismo equipo
de 6 personas. El equipo modifica `libgreet` con frecuencia (varias veces por sprint)
y suele querer que los cambios lleguen al super-app en el mismo PR que los consume.
Los reviewers quieren ver el diff real del código de `libgreet` cuando se actualiza,
no sólo un gitlink cambiando. El upstream vive en el mismo GitHub org y nunca se
clona por consumidores externos.

Experimentos realizados:
- A1: clone `super-sub` sin `--recurse-submodules` → `vendor/libgreet/` queda vacío.
  Pérdida de tiempo recurrente para nuevos devs y para scripts de CI que olvidan el flag.
- A2: bump del submódulo tras cambio en upstream → requiere entrar al submódulo,
  checkout del nuevo HEAD, salir, `git add vendor/libgreet`, commit en el super.
  El diff del commit del super sólo muestra el gitlink cambiando de SHA → opaco en
  code review sin abrir el otro repo.
- B1: clone `super-tree` sin flags → `vendor/libgreet/` tiene todos los archivos.
  Un paso menos; CI simple.
- B2: `git subtree pull --prefix=vendor/libgreet <url> main --squash` propaga cambios
  del upstream en un merge commit; el diff es *el código real*, revisable en el PR
  del super.

## Decision
Use subtree.

## Rationale
- La UX de los consumidores (incluidos CI y nuevos devs) importa más que el pin
  exacto por SHA, porque el equipo es el mismo que mantiene `libgreet`.
- Los code reviews del super muestran el diff real tras `subtree pull`, lo cual
  acelera reviews cross-cutting (bugfix en `libgreet` + consumer en el mismo PR).
- `--squash` evita inflar el log con cada commit del upstream.
- La ausencia de `.gitmodules` elimina la carga mental de "¿tengo todos los
  submódulos checked out?" en cada operación.

## Consequences
### Positive
- Clones triviales, CI simple, un solo `git clone`.
- Reviewers ven el diff real del vendor code.
- No hay "carpeta vacía" por olvidar un flag.

### Negative
- Pin exacto a un SHA del upstream requiere disciplina (anotar el SHA en el commit
  message del subtree pull); no hay archivo de metadatos que lo registre.
- `git subtree push` para re-upstreamear cambios es más tosco que trabajar directo
  en el repo del submódulo.
- El repo del super crece con cada versión del vendor (acotado por `--squash`).

## Alternatives considered
### Submodule
Descartado para este escenario: la UX dura (olvidar `--recurse-submodules`, diffs
opacos en PRs, trabajar "en dos repos" para un cambio simple) supera el beneficio
del pin por SHA, que no es crítico cuando el mismo equipo mantiene ambos.

### Subtree
Elegido (ver Decision y Rationale).

### Monorepo
Candidato razonable y potencialmente mejor a largo plazo. Lo evitamos ahora porque
`libgreet` ya tiene su propio repo con historia, issues y permisos; migrar implica
reescribir historia y romper enlaces a issues. Reconsiderar si el número de libs
internas crece a >3.

## References
- Experimentos A1, A2, B1, B2 descritos en Context.
- `theory/lesson.md` §2.2 (gitlink), §4.3 (submodule commands), §4.4 (subtree commands),
  §8.2 (trade-offs matrix).
- `git-submodule(1)` y `git-subtree(1)`.
EOF

echo
echo "Solution built at $BASE:"
echo "  - scratch/super-sub   (submodule)"
echo "  - scratch/super-tree  (subtree)"
echo "  - ADR.md              ($(wc -c < "$BASE/ADR.md") bytes, decision: Use subtree)"
