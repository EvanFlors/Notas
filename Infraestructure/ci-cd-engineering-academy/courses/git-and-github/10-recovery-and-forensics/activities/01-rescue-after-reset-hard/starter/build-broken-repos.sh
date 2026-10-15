#!/usr/bin/env bash
# Builds 3 chained broken-state repos for gh-10-01-rescue-after-reset-hard.
# Each lives under $BASE/scenario-N/
set -euo pipefail

BASE="${1:-/tmp/recover-adv}"
rm -rf "$BASE"
mkdir -p "$BASE"

make_identity() {
  git config user.name  "Student"
  git config user.email "student@example.com"
  # Prevent auto-gc from quietly destroying our dangling objects in scenario 3.
  git config gc.auto 0
}

############################################################
# Scenario 1 — Reset --hard HEAD~3 and then branched elsewhere
############################################################
S1="$BASE/scenario-1"
mkdir -p "$S1" && cd "$S1"
git init -q -b main
make_identity

echo "base" > work.txt
git add . && git commit -q -m "init: base"

for n in 1 2 3; do
  echo "step $n" >> work.txt
  git add . && git commit -q -m "feat: step $n"
done

# User "accidentally" resets main to before any of the 3 steps.
git reset --hard HEAD~3 >/dev/null

# User creates a different branch and commits noise.
git switch -c other >/dev/null 2>&1
echo "other work" >> work.txt
git add . && git commit -q -m "chore: other-branch noise"
git switch main >/dev/null 2>&1

cat > README.md <<'EOF'
# Scenario 1 — Perdí 3 commits tras reset --hard

Hiciste tres commits sobre `main` (`feat: step 1/2/3`), después ejecutaste
`git reset --hard HEAD~3`, y después creaste otra rama (`other`) con otro
commit.

**Tarea**: Restaurar `main` para que su HEAD apunte al commit `feat: step 3`
(y por lo tanto incluya step 1 y step 2 en su historia). Debes terminar
*en la rama main*, no en detached HEAD ni en other.

Hint inicial: `git reflog`.
EOF
# Note: this doc commit lands on main AFTER the reset, which is fine for the
# scenario — the student needs to overwrite main's tip anyway. We commit it on
# a dedicated branch to avoid polluting main's reflog interpretation.
git switch -c scenario-doc >/dev/null 2>&1
git add README.md && git commit -q -m "docs: scenario brief"
git switch main >/dev/null 2>&1

############################################################
# Scenario 2 — Deleted branch; only HEAD reflog knows the tip
############################################################
S2="$BASE/scenario-2"
mkdir -p "$S2" && cd "$S2"
git init -q -b main
make_identity

echo "base" > app.py
git add . && git commit -q -m "init: base"

git switch -c feature/payments >/dev/null 2>&1
echo "def charge(): pass" >> app.py
git add . && git commit -q -m "feat: add payments module"
echo "# tests/test_charge.py" > tests.py
git add . && git commit -q -m "test: payments happy path"
echo "def charge(amount):" >> app.py
echo "    if amount <= 0: raise ValueError" >> app.py
git add . && git commit -q -m "fix: payments edge case"

git switch main >/dev/null 2>&1
# The accident: force-delete the branch while off of it.
git branch -D feature/payments >/dev/null

# Doc for the scenario, on a side branch so main stays minimal.
git switch -c scenario-doc >/dev/null 2>&1
cat > README.md <<'EOF'
# Scenario 2 — Borré la rama en la que trabajaba

Tenías la rama `feature/payments` con 3 commits:
  - `feat: add payments module`
  - `test: payments happy path`
  - `fix: payments edge case`   ← este era el tip

Hiciste `git switch main` y luego `git branch -D feature/payments`.
La rama ya no existe. Pero NO borraste nada en `.git/objects/`
y el reflog de HEAD sigue intacto (puedes verlo con `git reflog`).

**Tarea**: Recrear la rama `feature/payments` apuntando al tip original
(`fix: payments edge case`). No necesitas estar *en* la rama; basta con
que la rama exista y apunte al commit correcto.
EOF
git add README.md && git commit -q -m "docs: scenario brief"
git switch main >/dev/null 2>&1

############################################################
# Scenario 3 — Stash dropped + reflog purged (but no gc)
############################################################
S3="$BASE/scenario-3"
mkdir -p "$S3" && cd "$S3"
git init -q -b main
make_identity

cat > app.py <<'EOF'
def main():
    print("hello")

if __name__ == "__main__":
    main()
EOF
git add . && git commit -q -m "init: app"

# Simulate the user starting a "critical fix" and stashing it.
cat > app.py <<'EOF'
def main():
    # CRITICAL_FIX_MARKER: do not remove, prevents data corruption
    print("hello")

if __name__ == "__main__":
    main()
EOF
git stash push -m "wip: critical fix" >/dev/null

# The accident chain:
# 1. drop the stash (removes refs/stash tip, but the commit remains in refs/stash's reflog)
git stash drop >/dev/null 2>&1 || true

# 2. purge all reflogs so the stash commit is no longer reachable by any ref/reflog.
#    (We don't run `git gc --prune=now` — the dangling commit must survive for the student.)
git reflog expire --expire=now --expire-unreachable=now --all

# Doc on a side branch — don't touch main or create new reflog entries on main
# that would introduce confusion.
git switch -c scenario-doc >/dev/null 2>&1
cat > README.md <<'EOF'
# Scenario 3 — Perdí un stash y el reflog está vacío

Guardaste trabajo con `git stash push -m "wip: critical fix"` que añadía
una línea con la cadena `CRITICAL_FIX_MARKER` al archivo `app.py`.

Luego hiciste `git stash drop` sin querer.

Después, "para limpiar", ejecutaste:

    git reflog expire --expire=now --expire-unreachable=now --all

Afortunadamente NO corriste `git gc --prune=now`: los objetos siguen en
`.git/objects/`.

**Tarea**:
1. Encuentra el commit *dangling* del stash.
2. Recupera el cambio y aplícalo a `app.py` en la rama `main`.
3. Haz un commit en `main` con subject EXACTAMENTE:
       rescue: apply recovered CRITICAL_FIX_MARKER

El `app.py` final en HEAD de `main` debe contener la cadena
`CRITICAL_FIX_MARKER`.

Pistas (si te atascas, en orden):
  P1: ¿Qué comando lista objetos sin referencias?
  P2: `git fsck --lost-found`
  P3: `git stash apply <sha-del-dangling-commit>` acepta cualquier sha
      con forma de stash.
EOF
git add README.md && git commit -q -m "docs: scenario brief"
# Also purge the reflog created by scenario-doc branch to keep the scenario
# as hostile as advertised. Keep refs/heads/main's reflog empty.
git reflog expire --expire=now --expire-unreachable=now --all
git switch main >/dev/null 2>&1
# Final reflog purge on main side too (switch created an entry).
git reflog expire --expire=now --expire-unreachable=now --all

############################################################
echo "3 broken repos created under $BASE/"
ls -1 "$BASE"
