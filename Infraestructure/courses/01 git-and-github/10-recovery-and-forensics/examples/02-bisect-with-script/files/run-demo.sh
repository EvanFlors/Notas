#!/usr/bin/env bash
# Reproduces the automated-bisect walkthrough end to end.
set -euo pipefail

BASE="${1:-/tmp/bisect-demo}"
rm -rf "$BASE" && mkdir -p "$BASE" && cd "$BASE"

git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

cat > app.sh <<'EOF'
#!/usr/bin/env bash
a="${1:-0}"; b="${2:-0}"
echo $((a + b))
EOF
chmod +x app.sh
git add . && git commit -q -m "feat: add app.sh (sum)"

for i in $(seq 1 9); do
  echo "# refactor pass $i" >> app.sh
  git add . && git commit -q -m "chore: refactor pass $i"
done

# Regresión.
sed -i.bak 's/a + b/a - b/' app.sh && rm app.sh.bak
git add . && git commit -q -m "refactor: operator rewrite"
BAD_SUBJ="refactor: operator rewrite"

for i in $(seq 1 8); do
  echo "# more cleanup $i" >> app.sh
  git add . && git commit -q -m "chore: more cleanup $i"
done

cat > /tmp/probe.sh <<'EOF'
#!/usr/bin/env bash
set -u
if [ ! -x ./app.sh ]; then exit 125; fi
got="$(./app.sh 2 3 2>/dev/null || true)"
if [ "$got" = "5" ]; then exit 0; fi
exit 1
EOF
chmod +x /tmp/probe.sh

echo "---- Starting automated bisect ----"
git bisect start
git bisect bad HEAD
git bisect good HEAD~18
git bisect run bash /tmp/probe.sh | tee /tmp/bisect-out.txt

FIRST_BAD="$(grep -oE '[0-9a-f]{40} is the first bad commit' /tmp/bisect-out.txt | awk '{print $1}' || true)"
echo
if [ -n "$FIRST_BAD" ]; then
  SUBJ="$(git show -s --format='%s' "$FIRST_BAD")"
  echo "First bad commit: $FIRST_BAD"
  echo "Subject:          $SUBJ"
  if [ "$SUBJ" = "$BAD_SUBJ" ]; then
    echo "OK: bisect identified the planted regression."
  else
    echo "WARN: bisect found a commit but subject does not match expected '$BAD_SUBJ'."
  fi
fi

git bisect reset
echo "Limpieza: rm -rf $BASE /tmp/probe.sh /tmp/bisect-out.txt"
