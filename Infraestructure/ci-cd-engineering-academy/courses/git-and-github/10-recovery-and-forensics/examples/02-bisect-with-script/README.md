# Ejemplo 02 — Bisect automatizado con `--run`

## Concepto que demuestra

Cómo `git bisect run <script>` encuentra automáticamente el commit que introduce una regresión, usando un script-probe con los códigos de salida convenidos (`0`=good, `1`=bad, `125`=skip).

## Contexto

Caso real: una suite CI empieza a fallar hoy, ayer pasaba. Entre medias hay 30 commits. Hacer `bisect` manual son 5 rondas de "checkout → run → responder". Con `--run` es *un* comando.

## Objetivo

Al terminar:
- Entiendes el ciclo `bisect start / good / bad / run / reset`.
- Diseñas un script-probe correcto (rápido, determinista, con códigos de salida bien definidos).
- Sabes qué significa "first bad commit is <hash>" y qué hacer después.

## Prerrequisitos

- Git ≥ 2.30.
- `bash`.

## Ejecución

Usa `files/run-demo.sh` o reproduce manualmente:

```bash
rm -rf /tmp/bisect-demo && mkdir /tmp/bisect-demo && cd /tmp/bisect-demo
git init -q -b main
git config user.name  "Demo" && git config user.email "demo@example.com"

# Crea una app trivial que suma dos números.
cat > app.sh <<'EOF'
#!/usr/bin/env bash
a="${1:-0}"; b="${2:-0}"
echo $((a + b))
EOF
chmod +x app.sh
git add . && git commit -q -m "feat: add app.sh (sum)"

# 9 commits inocuos (refactors, comentarios).
for i in $(seq 1 9); do
  echo "# refactor pass $i" >> app.sh
  git add . && git commit -q -m "chore: refactor pass $i"
done

# Commit 11 introduce la regresión: suma mal (a - b en vez de a + b).
sed -i.bak 's/a + b/a - b/' app.sh && rm app.sh.bak
git add . && git commit -q -m "refactor: operator rewrite"

# 8 commits más inocuos.
for i in $(seq 1 8); do
  echo "# more cleanup $i" >> app.sh
  git add . && git commit -q -m "chore: more cleanup $i"
done

git log --oneline | wc -l       # ≈ 19
```

Hoy en HEAD: `./app.sh 2 3` → `-1` (mal). Hace 15+ commits atrás: `5` (bien).

Script-probe:

```bash
cat > probe.sh <<'EOF'
#!/usr/bin/env bash
# 0 = good, 1 = bad, 125 = skip
set -u
if [ ! -x ./app.sh ]; then exit 125; fi
got="$(./app.sh 2 3 2>/dev/null || true)"
if [ "$got" = "5" ]; then exit 0; fi
exit 1
EOF
chmod +x probe.sh

# IMPORTANTE: probe.sh es untracked. En cada checkout de bisect sobrevive
# porque no está en ningún commit (sería removido si fuera tracked y
# un commit viejo no lo tuviera). Mantenlo fuera de git o cópialo a /tmp.
cp probe.sh /tmp/probe.sh

git bisect start
git bisect bad HEAD
git bisect good HEAD~18
git bisect run bash /tmp/probe.sh
# ... Git recorre log₂(18) ≈ 5 commits y reporta:
# "<hash> is the first bad commit"

git bisect reset
```

## Resultado esperado

- `bisect run` imprime el hash del commit `refactor: operator rewrite`.
- Verifica con `git show <hash>` que el diff muestra `a + b` → `a - b`.

## Interpretación

- `bisect run` paralela la *decisión* (que hace el script) de la *estrategia* (que hace Git).
- El script debe ser:
  - **Rápido**: cada iteración lo corre.
  - **Determinista**: si el bug es intermitente, bisect confunde el rango.
  - **Correcto en los códigos**: `125` para "no evaluable", nunca `0` o `1` por error.
- Si tu suite es lenta, extrae **solo** el test que detecta la regresión.

## Observación: por qué `probe.sh` va fuera del repo

Si lo commiteas, los commits viejos no lo tienen → no existe en el checkout → `bash probe.sh` falla con `No such file`. Mantenlo fuera (en `/tmp` o pásalo como argumento inline). Alternativa limpia: `git bisect run bash -c '…script inline…'`.

## Errores frecuentes

- **Probe que devuelve `1` en todos los commits** → bisect dice "the first bad commit is <el inicial>". Verifica tu probe en good y bad **a mano** antes de `run`.
- **Olvidar `git bisect reset`** → te quedas en detached HEAD.
- **Probe lento** → bisectar lleva horas. Reduce al mínimo.

## Relación con escenarios reales

- "Un test que pasaba falla hoy": siempre candidato ideal.
- Regresiones de rendimiento: probe que mide tiempo y compara umbral.
- Bugs reportados por usuario: convierte el reporte en test → `bisect run`.

## Limpieza

```bash
rm -rf /tmp/bisect-demo /tmp/probe.sh
```
