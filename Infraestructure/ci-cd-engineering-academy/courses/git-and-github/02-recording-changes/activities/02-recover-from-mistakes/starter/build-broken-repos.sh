#!/usr/bin/env bash
# Builds 4 broken-state repos for gh-02-02-recover-from-mistakes.
# Each lives under $BASE/scenario-N/
set -euo pipefail

BASE="${1:-/tmp/recover}"
rm -rf "$BASE"
mkdir -p "$BASE"

make_identity() {
  git config user.name  "Student"
  git config user.email "student@example.com"
}

############################################################
# Scenario 1 — Lost WIP commit after `reset --hard HEAD~1`
############################################################
S1="$BASE/scenario-1"
mkdir -p "$S1" && cd "$S1"
git init -q -b main
make_identity

echo "line1" > notes.txt
git add notes.txt
git commit -q -m "init: notes"

echo "line2" >> notes.txt
git add notes.txt
git commit -q -m "WIP: experimentos"

# User "accidentally" ran reset --hard HEAD~1
git reset --hard HEAD~1 >/dev/null

cat > README.md <<'EOF'
# Scenario 1 — Reset --hard me borró el commit WIP

Hiciste un commit `WIP: experimentos` sobre `main` y luego ejecutaste
`git reset --hard HEAD~1` por error. El commit ya no aparece en `git log`.

**Tarea**: Recupera el commit `WIP: experimentos` y haz que vuelva a ser
alcanzable desde `main`.

Hint: `git reflog`.
EOF
git add README.md
git commit -q -m "docs: scenario brief" # noise, pero no afecta el objetivo

############################################################
# Scenario 2 — Commit on the wrong branch
############################################################
S2="$BASE/scenario-2"
mkdir -p "$S2" && cd "$S2"
git init -q -b main
make_identity

echo "<base>" > app.txt
git add app.txt
git commit -q -m "init: base"

# User "accidentally" committed dark-mode feature on main
cat > app.txt <<'EOF'
<base>

# Dark mode
background: #000
foreground: #fff
EOF
git add app.txt
git commit -q -m "feat: add dark mode"

cat > README.md <<'EOF'
# Scenario 2 — Commit en la rama equivocada

El commit `feat: add dark mode` fue hecho en `main` por error. Debe estar
en una rama `feature/dark-mode`. Nada se ha pusheado.

**Tarea**:
1. Mueve el commit `feat: add dark mode` a una rama nueva `feature/dark-mode`.
2. `main` debe volver al commit `init: base` (sin el `feat`).
3. No pierdas ningún archivo.
EOF
git add README.md
git commit -q -m "docs: scenario brief"

############################################################
# Scenario 3 — Secret committed in last commit (not pushed)
############################################################
S3="$BASE/scenario-3"
mkdir -p "$S3" && cd "$S3"
git init -q -b main
make_identity

cat > README.md <<'EOF'
# Scenario 3 — Secreto committed por error

El último commit (`feat: add deploy script`) incluyó un archivo `secrets.env`
con una API key. Nada se ha pusheado.

**Tarea**:
- Reemplaza el último commit por uno sin el archivo `secrets.env`.
- Añade `secrets.env` al `.gitignore`.
- (En vida real: ROTAR LA CREDENCIAL — aquí la "key" es dummy.)

El `deploy.sh` SÍ debe permanecer en la historia.
EOF
git add README.md
git commit -q -m "init: project"

cat > deploy.sh <<'EOF'
#!/usr/bin/env bash
echo "Deploying..."
EOF
chmod +x deploy.sh
cat > secrets.env <<'EOF'
API_KEY=sk_live_FAKE_abcdef1234567890
EOF
git add deploy.sh secrets.env
git commit -q -m "feat: add deploy script"

############################################################
# Scenario 4 — Last commit mixes two intents
############################################################
S4="$BASE/scenario-4"
mkdir -p "$S4" && cd "$S4"
git init -q -b main
make_identity

cat > app.py <<'EOF'
# TODO: implement greet
def greet(name):
    return f"Hello {name}"
EOF
cat > VERSION <<'EOF'
0.1.0
EOF
git add app.py VERSION
git commit -q -m "init: project"

# Now the "bad" commit: two intents mixed
cat > app.py <<'EOF'
def greet(name):
    return f"Hello {name}"
EOF
cat > VERSION <<'EOF'
0.2.0
EOF
git add app.py VERSION
git commit -q -m "chore: cleanup"

cat > README.md <<'EOF'
# Scenario 4 — Un commit mezcló dos intenciones

El último commit `chore: cleanup` hizo dos cosas distintas:
1. Eliminó un `TODO` en `app.py`.
2. Bumped la versión en `VERSION` de 0.1.0 a 0.2.0.

**Tarea**: Reemplaza ese commit por **dos** commits:
- `chore: remove done TODO` (solo toca `app.py`).
- `chore: bump version to 0.2.0` (solo toca `VERSION`).

El commit `chore: cleanup` ya no debe aparecer en el log.
EOF
git add README.md
git commit -q -m "docs: scenario brief"

############################################################
echo "4 broken repos created under $BASE/"
ls -1 "$BASE"
