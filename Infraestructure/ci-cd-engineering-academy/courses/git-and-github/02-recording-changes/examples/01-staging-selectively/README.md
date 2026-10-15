# Ejemplo 01 — Staging selectivo con `git add -p`

## Concepto que demuestra

Cómo tomar un diff con **múltiples cambios no relacionados** en un mismo archivo y dividirlos en commits atómicos usando `git add --patch`.

## Contexto

Caso real: estás trabajando y haces (sin pensarlo) tres cosas a la vez en el mismo archivo: refactor + typo fix + nueva función. Si haces `git add .` todo colapsa. `git add -p` te deja elegir **hunk por hunk**.

## Objetivo

Al terminar:
- Entiendes qué es un **hunk** y cómo Git los calcula.
- Usas las opciones principales de `add -p`: `y`, `n`, `s`, `e`, `q`.
- Verificas con `git diff --staged` **antes** de commitear.

## Prerrequisitos

- Git ≥ 2.30.
- Haber completado `gh-01`.

## Ejecución

Usa el script `files/run-example.sh` o reproduce manualmente:

```bash
rm -rf /tmp/stage-demo && mkdir /tmp/stage-demo && cd /tmp/stage-demo
git init -q -b main
git config user.name  "Demo" && git config user.email "demo@example.com"

# Commit base
cat > calc.py <<'EOF'
def add(a, b):
    return a + b


def multyply(a, b):     # typo intencional
    return a * b
EOF
git add calc.py
git commit -q -m "init: calc module"

# Hacemos 3 cambios no relacionados en el mismo archivo:
cat > calc.py <<'EOF'
def add(a: int, b: int) -> int:
    """Return the sum of two ints."""
    return a + b


def multiply(a: int, b: int) -> int:
    """Return the product of two ints."""
    return a * b


def subtract(a: int, b: int) -> int:
    """Return a - b."""
    return a - b
EOF

git diff calc.py
# Deberías ver UN diff con 3 cambios lógicos:
#   1. type hints + docstring en add()
#   2. corregir typo multyply → multiply + type hints + docstring
#   3. nueva función subtract()
```

Ahora el `add -p`:

```bash
git add -p calc.py
```

Al principio Git te mostrará **un único hunk gigante** que contiene las 3 cosas (porque están muy cerca en el archivo). Responde `s` para **split**:

```
Split into 3 hunks.
@@ -1,2 +1,3 @@
-def add(a, b):
+def add(a: int, b: int) -> int:
+    """Return the sum of two ints."""
     return a + b

Stage this hunk [y,n,q,a,d,j,J,g,/,s,e,?]?
```

Responde:
- Hunk 1 (refactor de `add`): `y`.
- Hunk 2 (fix typo + refactor de `multiply`): `n` (lo dejamos para otro commit).
- Hunk 3 (nueva `subtract`): `n`.

Verifica:
```bash
git diff --staged     # solo el hunk 1
git diff              # los otros 2 pendientes
```

Primer commit:
```bash
git commit -m "refactor: type-annotate and document add()"
```

Segundo:
```bash
git add -p calc.py
# ahora los hunks son los de multiply y subtract
# Stage el de multiply (y), skip subtract (n)
git commit -m "fix: correct multyply typo and annotate"
```

Tercero:
```bash
git add calc.py       # staging normal del resto
git commit -m "feat: add subtract()"
```

Resultado:
```bash
git log --oneline
# <h3> feat: add subtract()
# <h2> fix: correct multyply typo and annotate
# <h1> refactor: type-annotate and document add()
# <h0> init: calc module
```

## Resultado esperado

- Tres commits atómicos sobre el mismo archivo.
- Cada commit comunica *una* intención.
- `git log --oneline` legible y navegable.

## Interpretación

- **Hunk** = bloque contiguo de líneas cambiadas con contexto (default: 3 líneas). Dos cambios cercanos pueden formar un solo hunk; Git los une si no hay espacio.
- **`s` (split)** solo funciona cuando el hunk tiene líneas de contexto *dentro* que permiten partir. Si no, usa **`e` (edit)** para editar el diff a mano.
- **`e` (edit)** abre un editor con el hunk. Puedes borrar líneas que no quieras stagear. Reglas:
  - Líneas que empiezan con `-` (eliminación): borra para *no* eliminar en el stage.
  - Líneas que empiezan con `+` (adición): borra para *no* añadir en el stage.
  - **No borres** líneas de contexto (sin signo) salvo que entiendas qué haces.

## Errores frecuentes

- **"Olvidé verificar `git diff --staged` antes de commit"**: resultado = commit con hunks no deseados. Siempre revisar.
- **`add -p` sobre un archivo sin cambios tracked**: Git responderá "No changes." → debes modificar el archivo primero.
- **`add -p` sobre un archivo untracked**: no funciona — necesitas al menos un `git add` previo para que haya baseline, o usar `git add -N <file>` (intent-to-add) para marcar.

## Relación con escenarios reales

- Antes de abrir un PR: siempre revisar el diff staged con disciplina.
- En hotfixes: separar el fix del PR grande en commits distintos para poder cherry-pickear.
- Code review: PRs con 1 commit "update" son el peor feedback que puedes recibir.

## Limpieza

```bash
rm -rf /tmp/stage-demo
```
