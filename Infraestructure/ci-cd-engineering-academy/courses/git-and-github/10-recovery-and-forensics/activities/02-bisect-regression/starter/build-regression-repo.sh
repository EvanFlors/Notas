#!/usr/bin/env bash
# Builds a ~20-commit repo with a single planted regression on calc.sh.
# Also writes the probe script and a scenario brief under $BASE/.
set -euo pipefail

BASE="${1:-/tmp/bisect-lab}"
rm -rf "$BASE"
mkdir -p "$BASE"

REPO="$BASE/repo"
mkdir -p "$REPO"
cd "$REPO"

git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
git config gc.auto 0

# Initial good commit.
cat > calc.sh <<'EOF'
#!/usr/bin/env bash
a="${1:-0}"; b="${2:-0}"
echo $((a + b))
EOF
chmod +x calc.sh

cat > README.md <<'EOF'
# calc demo repo

Script `calc.sh` suma dos enteros. Hoy devuelve un valor incorrecto
para `./calc.sh 2 3`. Encuentra el commit culpable con `git bisect`.
EOF

git add . && git commit -q -m "feat: add calc.sh (sum)"

# Innocent commits before the regression: 10 refactor/doc passes.
for i in $(seq 1 10); do
  echo "# refactor pass $i" >> calc.sh
  git add . && git commit -q -m "chore: refactor pass $i"
done

# Plant the regression at commit #12 (index 11 from init).
# The subject must match EXACTLY what the solution/validator reference.
sed -i.bak 's/a + b/a - b/' calc.sh && rm calc.sh.bak
git add . && git commit -q -m "refactor: swap operator (regression)"

# 9 more innocent commits after the regression (total = 1 initial + 10 pre + 1 regression + 9 post = 21).
for i in $(seq 1 9); do
  echo "# more cleanup $i" >> calc.sh
  git add . && git commit -q -m "chore: more cleanup $i"
done

# Sanity: total ~20 commits
TOTAL="$(git log --oneline | wc -l | tr -d ' ')"
echo "Total commits in $REPO: $TOTAL"

# Probe script (outside the repo so it survives every checkout).
cat > "$BASE/probe.sh" <<'EOF'
#!/usr/bin/env bash
# 0 = good, 1 = bad, 125 = skip (untestable)
set -u
if [ ! -x ./calc.sh ]; then exit 125; fi
got="$(./calc.sh 2 3 2>/dev/null || true)"
if [ "$got" = "5" ]; then exit 0; fi
exit 1
EOF
chmod +x "$BASE/probe.sh"

# Scenario brief for the student.
cat > "$BASE/README.md" <<'EOF'
# Bisect lab — scenario

El repo en `./repo/` contiene ~20 commits sobre `calc.sh`.
- `./calc.sh 2 3` en HEAD → valor incorrecto.
- `./calc.sh 2 3` en HEAD~20 → `5` (correcto).

Un (único) commit intermedio introdujo la regresión.
Usa `git bisect start/run` con el probe `./probe.sh` para localizarlo.

Para registrar tu respuesta antes del validador, puedes:
  echo "<sha-del-commit-malo>" > answer.txt
EOF

echo "Repo ready in $REPO ($TOTAL commits)."
echo "Probe:  $BASE/probe.sh"
echo "Brief:  $BASE/README.md"
