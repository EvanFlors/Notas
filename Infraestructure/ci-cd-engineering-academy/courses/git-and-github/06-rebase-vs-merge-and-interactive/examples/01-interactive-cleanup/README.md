# Ejemplo 01 — Rebase interactivo: `pick` / `reword` / `squash` / `fixup` / `drop`

## Concepto que demuestra

Cómo usar `git rebase -i` para **limpiar una rama** convirtiendo 5 commits sucios (`wip`, `typo`, `oops`) en 2 commits bien definidos, usando cada una de las acciones principales del todo file.

## Contexto

Trabajaste 2 h en una rama `feature/payments`. Fuiste commiteando todo lo que pasaba sin pensar en la narrativa final:

```
wip                   <-- scaffold inicial
typo                  <-- typo del scaffold
add tests             <-- tests mezclados con un fix
oops forgot header    <-- header de licencia que faltaba
fix typo again        <-- otro typo
```

Antes del PR quieres entregar algo revisable: **1 commit `feat:` con todo el código + 1 commit `test:` con los tests**.

## Objetivo

Al terminar:
- Entiendes cada acción del todo file: `pick`, `reword`, `squash`, `fixup`, `drop`, `edit`.
- Sabes **automatizar** `rebase -i` con `GIT_SEQUENCE_EDITOR` para scripts reproducibles.
- Reconoces cuándo elegir `squash` vs `fixup`.

## Prerrequisitos

- Git ≥ 2.30.
- Haber completado `gh-03`.
- Bash + `sed` (incluidos en macOS y en cualquier Linux).

## Ejecución

Opción A — guiada paso a paso (editor interactivo):

```bash
mkdir -p /tmp/rebase-interactive-demo && cd /tmp/rebase-interactive-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# Commit base
echo "# Payments module" > README.md
git add README.md && git commit -q -m "init: payments module scaffold"

# ------- 5 commits sucios -------
cat > payments.py <<'EOF'
def refnd(amount):
    return {"status": "pending", "amount": amount}
EOF
git add payments.py && git commit -q -m "wip"

# fix typo
sed -i.bak 's/refnd/refund/' payments.py && rm -f payments.py.bak
git commit -q -am "typo"

# add tests + oculto un fix al mensaje de error
mkdir -p tests
cat > tests/test_payments.py <<'EOF'
from payments import refund


def test_refund_pending():
    assert refund(10)["status"] == "pending"
EOF
git add tests/test_payments.py && git commit -q -m "add tests"

# oops: license header
sed -i.bak '1i\
# Copyright 2026 Acme Inc. SPDX-License-Identifier: Apache-2.0
' payments.py && rm -f payments.py.bak
git commit -q -am "oops forgot header"

# un typo más
sed -i.bak 's/pending/accepted/' payments.py && rm -f payments.py.bak
git commit -q -am "fix typo again"

git log --oneline
```

Verás algo como:
```
e5f fix typo again
d4e oops forgot header
c3d add tests
b2c typo
a1b wip
000 init: payments module scaffold
```

Ahora:

```bash
git rebase -i HEAD~5
```

Se abre tu editor con el **todo file**. Edítalo así:

```
pick a1b wip
fixup b2c typo
fixup d4e oops forgot header
fixup e5f fix typo again
reword c3d add tests
```

Notas:
- Reordenamos: `add tests` queda **al final** (lo quieres como commit 2).
- Los otros 3 fixes se marcan como `fixup` (combinan con el `pick` anterior y descartan su mensaje).
- `reword` del commit de tests te pedirá un mensaje nuevo.

Guarda y cierra. Luego Git abre un segundo editor para el `reword`; escribes:

```
test(payments): cover refund processor
```

Guardas. Resultado:

```bash
git log --oneline
# <new-h2> test(payments): cover refund processor
# <new-h1> wip                         <-- hereda mensaje del pick; vamos a corregirlo
```

Oops, el mensaje "wip" quedó. Normalmente usarías `reword` también en ese commit, o editas el plan con 2 `reword`. Hagámoslo bien con otro rebase:

```bash
git rebase -i HEAD~2
```

Cambia:
```
reword <h1> wip
pick <h2> test(payments): cover refund processor
```

Guarda; en el segundo editor:
```
feat(payments): add refund processor
```

Guarda. Listo:

```bash
git log --oneline
# <final-h2> test(payments): cover refund processor
# <final-h1> feat(payments): add refund processor
# 000       init: payments module scaffold
```

Opción B — totalmente automatizada (**la que usan las actividades**):

Mira `files/run-demo.sh`. Usa `GIT_SEQUENCE_EDITOR` para escribir el todo file sin abrir editor y `GIT_EDITOR` para los mensajes.

```bash
bash files/run-demo.sh /tmp/rebase-interactive-demo-auto
```

## Resultado esperado

- 2 commits sobre el commit base (en lugar de 5).
- Mensajes: `feat(payments): add refund processor` y `test(payments): cover refund processor`.
- Contenido final idéntico al de la versión original ("sin perder código").
- Working tree limpio.

## Interpretación

- **`pick`** — "usa este commit tal cual, aplícalo sobre el anterior en el plan".
- **`reword`** — igual que `pick`, pero abre editor para cambiar mensaje.
- **`edit`** — igual que `pick`, pero **pausa** tras aplicarlo; tú modificas lo que quieras (`git add`, edit files) y continúas con `git rebase --continue`.
- **`squash`** — combina con el anterior y abre editor para fusionar ambos mensajes.
- **`fixup`** — combina con el anterior y **descarta** este mensaje.
- **`drop`** — descarta el commit (equivale a borrar la línea, pero explícito).
- **`exec cmd`** — ejecuta `cmd` tras aplicar el commit anterior; si falla, pausa el rebase.
- **`break`** — pausa en este punto; continúas cuando quieras.

### Reglas prácticas de uso

- Usa `fixup` para `typo`, `wip`, `oops` — nunca aportan mensaje.
- Usa `squash` cuando dos commits son semánticamente distintos y el mensaje final debe reflejar ambos.
- Usa `reword` para pulir mensajes sin cambiar nada más.
- Usa `edit` cuando quieres partir un commit grande en dos: tras pausar, haces `git reset HEAD^`, re-stageas por partes y commiteas varias veces.
- Usa `exec make test` para asegurar que **cada** commit intermedio sigue compilando (bisect-friendly).

## Errores frecuentes

- **Borraste una línea sin querer** → el commit se dropeó. Recupera con `git reflog` + `git cherry-pick <hash>`.
- **El `squash` abrió editor que no esperabas** → es normal; combina mensajes.
- **Conflicto durante el rebase** → `git status` dice cómo. Resuelves, `git add`, `git rebase --continue`. Si te pierdes: `git rebase --abort`.
- **Mensaje `wip` quedó porque el `fixup` iba al commit anterior correcto pero el `pick` seguía siendo "wip"** → necesitas `reword` en el commit base o reencadenar en dos pasos (como arriba).

## Relación con escenarios reales

- Antes de abrir PR: siempre pasa el rebase de cleanup.
- `--fixup` + `--autosquash` elimina la necesidad de editar el todo file a mano (ver sección 6.3 de la lección).
- En release scripts: `GIT_SEQUENCE_EDITOR` permite scriptear reescrituras.

## Limpieza

```bash
rm -rf /tmp/rebase-interactive-demo /tmp/rebase-interactive-demo-auto
```
