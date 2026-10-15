# Lección: Recording changes

> **ID:** `gh-02-recording-changes` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `gh-01-setup-and-mental-model`.

---

## 1. Introducción intuitiva

Imagina este escenario real. Trabajas durante dos horas: arreglas un bug, formatéas un archivo, cambias un valor de config, añades un test, añades un log para depurar. Haces `git add .` y `git commit -m "fixes"`. Mandas PR. Code review: "¿puedes separar el fix del formato?". Y tú: *¿cómo?*

El problema es que colapsaste **cinco intenciones distintas en un commit**. Cuando años después alguien ejecuta `git bisect` para encontrar el commit que introdujo un bug, aterriza en tu commit "fixes" que toca 11 archivos y nada tiene sentido.

Este módulo te enseña el **ciclo diario correcto**: dividir cambios en commits que cada uno dice *una sola cosa* y los dice bien. Y, cuando metes la pata (porque la vas a meter), te enseña a **deshacer con precisión**: hay cuatro operaciones distintas (`restore`, `reset`, `revert`, `checkout`) y confundirlas cuesta trabajo real.

---

## 2. Fundamentos

### 2.1 Recordatorio de las tres áreas

Repasamos lo esencial de `gh-01`:

```
┌──────────────┐   add    ┌─────────────┐   commit    ┌──────────────┐
│ working tree │ ───────> │   index     │ ──────────> │ repository   │
│ (editas)     │          │ (staging)   │             │ (.git/)      │
└──────────────┘          └─────────────┘             └──────────────┘
       ^                        ^                            │
       │                        │                            │
       │   restore              │   restore --staged         │  checkout <ref>
       │                        │                            │
       └────────────────────────┴────────────────────────────┘
```

Cada operación mueve o copia contenido entre áreas. **Hacer esto consciente** es el salto de "copio-pego comandos" a "sé lo que hago".

### 2.2 El index no es "una lista de archivos marcados"

Es un **árbol serializado binario** (`.git/index`) que contiene, por cada archivo tracked: path, modo (100644, 100755, 120000, 160000), hash del blob, metadata (ctime, mtime, size, stage number).

Implicaciones:
- Cuando haces `git add file`, Git crea el blob del contenido *actual* y actualiza la entrada en el index.
- Si editas el archivo *después* de `add` y haces `commit`, se commitea **lo que estaba en el index**, no el working tree. El archivo editado queda modificado respecto a HEAD de nuevo.
- `git diff` compara **working tree vs index** por default. `git diff --staged` (o `--cached`) compara **index vs HEAD**.

Esta es la base de **staging selectivo**: puedes añadir cambios al index incrementalmente, por hunks (`add -p`), hasta tener exactamente el commit que quieres.

### 2.3 Hash de contenido ⇒ hash del commit depende de todo

Un commit es `(tree, parent(s), author, committer, message)` serializado y hasheado. Cambiar cualquier byte cambia el hash:

- `--amend` toma el commit actual, cambia alguno de los 5 campos (típicamente mensaje o tree), **crea un commit nuevo** con hash distinto, y mueve la ref a ese nuevo commit. El viejo queda unreachable → eventualmente removido por `git gc`.
- Un rebase re-escribe commits similarmente: nuevos hashes, aunque "el cambio" sea el mismo semánticamente.

Este punto es la fuente #1 de confusión: "amendé y GitHub muestra un commit distinto" — sí, es un commit distinto, aunque parezca "el mismo con un mensaje corregido".

---

## 3. Contexto histórico

Hasta Git 2.23 (2019), hacer "deshacer un archivo" significaba lidiar con la zoología:

- `git checkout -- file` → descartar cambios del working tree.
- `git checkout <branch>` → cambiar de rama.
- `git checkout <commit> file` → traer un archivo de otro commit.
- `git reset HEAD file` → unstage.
- `git reset --hard` → aniquilar cambios.
- `git reset --soft HEAD~` → "deshacer el último commit pero conservar cambios en index".

**Un mismo verbo (`checkout`, `reset`) hace cosas totalmente distintas según flags.** Es confuso y peligroso.

Git 2.23 introdujo:
- **`git restore`** → *restaurar* contenido en working tree y/o index.
- **`git switch`** → *cambiar* de rama o crear ramas.

Estos nuevos verbos **no reemplazan oficialmente** a los viejos (siguen funcionando) pero son el camino recomendado desde ~2020. Este curso los usa.

---

## 4. Funcionamiento interno

### 4.1 Qué hace `git add -p`

`git add -p` (o `--patch`) te muestra los **hunks** del diff entre working tree e index para cada archivo y pregunta qué hacer con cada uno:

```
Stage this hunk [y,n,q,a,d,j,J,g,/,s,e,?]?
```

Las opciones más usadas:
- **y** — stage este hunk.
- **n** — no stagear.
- **s** — **split**: partir en hunks más chicos (si el diff es contiguo pero contiene cambios no relacionados).
- **e** — **edit**: editar el diff a mano (quitar líneas que no quieres).
- **q** — quit (dejar lo decidido hasta ahora).
- **?** — ayuda.

Internamente Git crea blobs intermedios para representar "el archivo con *estos* hunks aplicados" y los pone en el index. El working tree no cambia.

### 4.2 Qué hace `git restore`

Semántica: "restaura contenido *desde* una fuente *hacia* un destino".

- `git restore <path>` → copia contenido de **index** al **working tree** (descarta cambios locales).
- `git restore --staged <path>` → copia contenido de **HEAD** al **index** (unstage).
- `git restore --source=HEAD~1 <path>` → copia contenido de **commit especificado** al working tree.
- `git restore --staged --worktree <path>` → ambos, equivalente a `reset --hard` sobre ese path.

Más consistente que `checkout`/`reset`.

### 4.3 Qué hace `git commit --amend`

Toma el commit en HEAD, descarta su hash, construye un commit *nuevo* con:
- El mismo tree (si no cambió el index) o uno nuevo (si hiciste `git add` antes de amend).
- El mismo parent.
- Mismo author (por default; puedes cambiar con `--author=`).
- Nuevo committer timestamp.
- Nuevo mensaje (o el anterior si usas `--no-edit`).

Luego mueve la ref actual al nuevo commit. **El commit viejo queda unreachable**. Vive en `.git/objects/` hasta que `git gc` lo recoja (default: 2 semanas si no está en reflog).

Si el commit viejo ya fue pusheado, **no debes amendar** sin coordinación — reescribir historia compartida rompe a tus colegas (lo retomamos en `gh-06`).

### 4.4 `git reset` en una línea

`git reset [modo] <ref>` mueve HEAD a `<ref>` y, según el modo, modifica index y working tree:

| Modo | HEAD | Index | Working tree |
|------|------|-------|--------------|
| `--soft` | mueve | sin tocar | sin tocar |
| `--mixed` (default) | mueve | reset a `<ref>` | sin tocar |
| `--hard` | mueve | reset a `<ref>` | reset a `<ref>` |

`--soft`: útil para "colapsar últimos N commits en el próximo commit" (los cambios quedan staged).
`--mixed`: unstage general ("`git reset HEAD`" sin `--`, de hecho, es esto).
`--hard`: **destruye cambios no commiteados**. Peligroso.

### 4.5 `git revert`

A diferencia de `reset`, `revert` **no reescribe historia**. Crea un commit *nuevo* cuyo contenido es "deshacer el commit `<X>`". Es la operación segura para deshacer algo ya pusheado.

```bash
git revert <commit>
# → crea un commit "Revert '<mensaje de <commit>>'" con el diff inverso
```

Compatible con PR workflow; nunca requiere force-push.

---

## 5. Ejemplo mínimo

Vamos a dividir un cambio sucio en dos commits atómicos.

```bash
# Preparar
mkdir -p /tmp/record-demo && cd /tmp/record-demo
git init -q -b main

cat > app.py <<'EOF'
def greet(name):
    return "Hello, " + name
EOF
git add app.py
git -c user.name=Demo -c user.email=demo@example.com commit -q -m "initial app"

# Cambios sucios: dos cosas en el mismo archivo
cat > app.py <<'EOF'
def greet(name: str) -> str:
    # Formatted + typed
    return f"Hello, {name}!"


def shout(text: str) -> str:
    # New unrelated feature
    return text.upper()
EOF

# Opción simple pero mala: git add . + commit
# Opción buena: stage por hunks
git diff app.py
# Verás 2 bloques: (1) refactor de greet, (2) nueva función shout

git add -p app.py
# → responde 'y' al hunk del refactor, 'n' al nuevo feature
git diff --staged     # solo el refactor
git diff              # solo el feature pendiente

git -c user.name=Demo -c user.email=demo@example.com commit -q -m "refactor: type-annotate greet()"

# Ahora el otro
git add app.py
git -c user.name=Demo -c user.email=demo@example.com commit -q -m "feat: add shout() helper"

git log --oneline
# 2 commits atómicos, cada uno con una intención
```

Observa: en `git log` cada commit comunica una idea. Si meses después aparece un bug en `shout()`, `git bisect` aterriza en el commit *exacto* que lo introdujo, sin colateral.

---

## 6. Implementación progresiva

### 6.1 `.gitignore`

Lo primero que crea un repo serio. Patrones:

```gitignore
# Comentarios con '#'

# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
.pytest_cache/
.coverage

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Secrets (defensa en profundidad; no basta — ver gh-13)
*.pem
*.key
.env
!.env.example                 # negación: no ignorar .env.example

# Build
dist/
build/
```

Reglas que confunden:
- **Un archivo ya tracked no se desya** por ponerlo en `.gitignore`. Necesitas `git rm --cached <file>` + commit.
- **Patrones son relativos al archivo `.gitignore`**. Un `.gitignore` dentro de `src/` solo aplica a `src/`.
- **La negación** (`!pattern`) solo funciona si el ancestro directorio *no* está ignorado.

Para patrones que **cualquier clon** necesita, va al `.gitignore` del repo. Para ignores **tuyos personales** sin tocar el repo compartido, usa `.git/info/exclude`.

### 6.2 `.gitattributes`

Controla el comportamiento *por path* para operaciones de Git. Casos típicos:

```gitattributes
# Normalización de line endings:
#   todos los archivos de texto se guardan como LF en objetos
#   en checkout, cada SO los adapta según core.autocrlf
* text=auto

# Forzar LF para shell scripts
*.sh text eol=lf

# Forzar CRLF para scripts PowerShell
*.ps1 text eol=crlf

# Binarios: no intentar hacer diff/merge de texto
*.png binary
*.jpg binary
*.pdf binary

# Diff "inteligente" para formatos específicos
*.ipynb diff=jupyternotebook       # requiere config del driver localmente

# Git LFS (si usas): patrones de archivos a mover a LFS
*.zip filter=lfs diff=lfs merge=lfs -text

# Exportar a archive sin ciertos archivos (para `git archive`)
.github/      export-ignore
tests/        export-ignore
.gitattributes export-ignore
```

`.gitattributes` es más robusto que depender del `core.autocrlf` *local* de cada dev. **Equipos multi-OS deberían usarlo siempre.**

### 6.3 Mensajes de commit

Convención sana base (puedes adoptarla sin ir a *Conventional Commits*):

```
<tipo>: <resumen imperativo, <= 72 chars>

<cuerpo opcional, por qué y qué, no cómo
en 72 chars por línea>

<trailers opcionales>
Co-authored-by: Name <email>
Fixes: #123
```

**Conventional Commits** (opcional pero útil para automatizar releases):

```
<type>(<scope>)?: <subject>

<body>

<footer>
```

Tipos comunes: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
Breaking change: `feat!:` o footer `BREAKING CHANGE: ...`.

Ejemplo:
```
feat(auth): require MFA for admin tokens

Admin tokens now require TOTP verification before issuance.
This closes the gap flagged in SEC-452.

BREAKING CHANGE: existing admin tokens are revoked on first
auth attempt and must be re-issued.
```

### 6.4 `git diff` en sus variantes

| Comando | Compara |
|---------|---------|
| `git diff` | working tree vs index |
| `git diff --staged` (o `--cached`) | index vs HEAD |
| `git diff HEAD` | working tree vs HEAD (ambos combinados) |
| `git diff <refA> <refB>` | dos commits/refs |
| `git diff <refA> <refB> -- <path>` | solo un path |
| `git diff --stat` | resumen (archivos + líneas) |
| `git diff --name-only` | solo nombres |
| `git diff -w` | ignorar whitespace |

Memorizar los **primeros tres** acelera 80% del trabajo diario.

---

## 7. Aplicación profesional

### 7.1 El commit atómico como contrato social

En equipos profesionales:
- **Un commit = una idea revisable**. Si un reviewer no puede entender el commit en 1 min, es demasiado grande.
- **PRs chicas, commits chicos**. Un PR de 5 commits de 100 líneas se revisa; uno de 1 commit de 500 líneas, no.
- **Mensaje en imperativo + cuerpo con "por qué"**. "Added logging" dice qué. "Add logging to parser so we can diagnose the DOCS-422 regression" dice *por qué* — mucho más valioso meses después.
- **`.gitignore` desde el primer commit**. Añadir `.gitignore` tras ya haber committed `node_modules/` deja basura permanente en la historia.
- **Nunca committed secretos**. Si pasa: **rotar primero, limpiar historia después** (`gh-13`). Si está en remoto, asumir **leaked**.

### 7.2 Workflow diario típico

```bash
# 1. Antes de empezar: pull con rebase
git pull --rebase

# 2. Trabajar. Al estar listo:
git status
git diff                       # revisar unstaged
git add -p                     # stage por hunks, con intención
git diff --staged              # revisar lo que vas a commitear
git commit                     # abre editor para mensaje largo

# 3. Si olvidaste un cambio relacionado al último commit:
#    (solo si NO lo pusheaste todavía)
git add -p
git commit --amend --no-edit   # mantiene mensaje; cambia hash

# 4. Si descartar cambios en un archivo:
git restore path/to/file                 # descarta en worktree
git restore --staged path/to/file        # unstage

# 5. Si quieres revertir un commit ya pusheado:
git revert <hash>              # crea commit nuevo que lo deshace
```

### 7.3 Hooks locales

Para enforzar reglas localmente (lint, format, no commits de secretos) se usa el framework **`pre-commit`** (lo verás en `gh-11`). Para esta lección basta con saber que existe y por qué (sanity antes de que el pipeline te lo diga por el camino largo).

---

## 8. Trade-offs

### 8.1 `--amend` vs **nuevo commit "fix"**

**Amend**:
- Historia limpia (un solo commit).
- Reescribe hash — no usar si ya está en remoto compartido.
- Preferido para **fixes muy inmediatos** antes de pushear.

**Nuevo commit "fix: ..."**:
- Historia honesta ("hubo un error, se arregló").
- Compatible con PRs ya abiertos.
- Puede combinarse después con `git rebase -i` + `squash`/`fixup` (`gh-06`).
- Preferido en equipos que valoran historia completa.

Decisión: pre-push → `--amend`. Post-push → nuevo commit.

### 8.2 `reset` vs `revert`

**`reset`**:
- Mueve la ref atrás.
- Reescribe historia local.
- `--hard` destruye trabajo no commiteado — peligroso.
- Usar solo si **no has pusheado**.

**`revert`**:
- Crea commit nuevo con el diff inverso.
- No reescribe nada.
- Seguro con remotos.
- Preferido en producción.

Si alguien te dice "reset the main branch to deploy an older version" en una org seria, probablemente quieren **revert**, no reset.

### 8.3 `restore` moderno vs `checkout`/`reset` legacy

**Nuevos (`restore`, `switch`)**:
- Semántica clara (restore contenido / switch rama).
- Verbo = una idea.
- Recomendación oficial desde 2.23.

**Legacy (`checkout`, `reset`)**:
- Omnipresentes en documentación histórica, blogs, Stack Overflow.
- Más corto en algunos casos.
- Sigues necesitando leerlos.

Escribe `restore`/`switch`. Lee ambos.

### 8.4 Convenciones de commit: ¿Conventional Commits sí o no?

**Sí si**: automatizas releases con `semantic-release` / `release-please`; generas CHANGELOG; equipo grande con disciplina.
**No necesariamente si**: equipo pequeño, releases manuales, convención propia ya establecida y clara.

Lo importante: **tener una convención y aplicarla**. "Fixed stuff" y "update" son el enemigo real, no la elección de formato.

---

## 9. Errores frecuentes

### 9.1 "Olvidé un cambio y amendé un commit ya pusheado"

Síntoma: `git push` falla con `(non-fast-forward)`.

Causas:
- Amend sobre commit pusheado → el hash cambió → tu rama local y la remota divergen.

Resoluciones (en orden de preferencia):
1. Si nadie más usa la rama: `git push --force-with-lease` (no `--force` a secas).
2. Si otros usan la rama: **no amendes** — haz commit nuevo "fix: ...".
3. Si no te importa, revierte el amend con `git reflog` + `git reset --hard <hash-anterior>` (local) y vuelve a push (sin force).

Lección: **no amendes commits pusheados a ramas compartidas.**

### 9.2 "`git reset --hard` me borró mi trabajo"

Si no habías committed, está perdido (bueno — está perdido *del working tree*; si tocaste solo tracked files, no hay rastro).

Si *sí* habías committed al menos una vez con eso, está en `reflog`:
```bash
git reflog              # busca el estado anterior
git reset --hard <hash>
```

Lección: **nunca `--hard` sin `git stash` o un commit WIP intermedio**.

### 9.3 "Committed un secreto"

```bash
# El commit ya es parte del repo, aunque no hayas pusheado.
# Paso 1 OBLIGATORIO: rotar el secreto (asume leaked).
# Paso 2: limpiar la historia local
git reset --soft HEAD~1   # si fue el último commit
git restore --staged <archivo-con-secreto>
# edita archivo
git commit -c ORIG_HEAD    # re-commit sin el secreto

# Si ya está pusheado: ver gh-13.
```

### 9.4 "Puse archivo en `.gitignore` pero sigue apareciendo"

Causa: el archivo ya estaba tracked antes del ignore.

Fix:
```bash
git rm --cached <archivo>
git commit -m "chore: stop tracking <archivo>"
```

### 9.5 "Line endings infernales entre Mac y Windows"

Síntoma: diffs enormes con "cambio de todas las líneas", mensajes `CRLF would be replaced by LF`.

Fix: usa `.gitattributes` con `* text=auto` + patrones específicos como se mostró. No dependas solo de `core.autocrlf` por dev.

### 9.6 "Hice `git add .` y staged un archivo que no quería"

```bash
git restore --staged <archivo>
# o para todo:
git restore --staged .
```

### 9.7 "Mi commit tiene autor `root@debian`"

Olvidaste configurar identidad en esa máquina (CI, VM, container).

Fix futuro: `git config --global user.*` (o para repo específico: `git config user.*`).
Fix retroactivo: ver `gh-10` (reescribir autor con `git commit --amend --author=` o `git filter-repo`).

---

## 10. Buenas prácticas

- **Un commit = una intención.** Si tu mensaje tiene "y", piénsalo dos veces.
- **`add -p` como default.** Rompe el hábito de `add .`.
- **Mensaje imperativo en línea 1, ≤ 72 chars.** `add logging to parser`, no `added logging stuff`.
- **Cuerpo opcional explica el *por qué*.** El *qué* ya está en el diff.
- **`.gitignore` desde el commit 1.** Más fácil añadir patrones que limpiar basura.
- **`.gitattributes` para equipos multi-OS.** `core.autocrlf` local no basta.
- **`git diff --staged` antes del commit.** Siempre. Es tu último filtro antes de que un hash viva para siempre.
- **`--amend` solo pre-push.** Nunca sobre ramas compartidas.
- **`revert`, no `reset`, en producción.**
- **Nunca commitees secretos.** Si pasa: rotar primero, limpiar después.
- **Mensajes en inglés** si el proyecto es público o internacional; español si es interno y el equipo lo prefiere. **Consistente**: no mezcles.

---

## 11. Ejercicios recomendados

1. **`activities/01-atomic-commits/`** — guided-lab: dividir un diff sucio en commits atómicos usando `add -p`.
2. **`activities/02-recover-from-mistakes/`** — **independent**: cuatro escenarios de recovery con `restore` / `reset` / `revert` / `reflog`.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Diferencia **en una frase cada una** entre:
- `git restore <path>`
- `git restore --staged <path>`
- `git reset --mixed HEAD~1`
- `git reset --hard HEAD~1`
- `git revert <commit>`
- `git checkout <commit> -- <path>`

**P2.** Explica por qué `git commit --amend` **crea un commit nuevo** en lugar de modificar el existente. Qué pasa con el commit viejo.

**P3.** Verdadero / falso:
- [ ] `git diff` por default compara working tree con HEAD.
- [ ] `git add -p` modifica el working tree.
- [ ] El index es "un archivo de texto con una lista de rutas marcadas".
- [ ] `--amend` sobre un commit ya pusheado a `main` compartido es seguro.
- [ ] `git restore --staged file` descarta cambios del working tree.

**P4.** Tienes 3 cambios no relacionados en el mismo archivo. ¿Cómo los committeas por separado? Describe los comandos exactos.

**P5.** Un archivo `secrets.env` fue commiteado por error en el último commit, aún no pusheado. Describe la secuencia de comandos para arreglar.

**P6.** Diseña un `.gitattributes` mínimo para un equipo con devs Linux, macOS y Windows trabajando en un repo con Python, Shell scripts, archivos PNG y un `.ipynb`.

**P7.** Un desarrollador en tu equipo ejecutó `git reset --hard` por error perdiendo 2 horas de trabajo. ¿Qué hace ahora? Secuencia de comandos.

---

## Referencias

- *Pro Git* cap. 2 y 7. <https://git-scm.com/book/en/v2>
- `git-add(1)`, `git-restore(1)`, `git-reset(1)`, `git-revert(1)`, `git-commit(1)`. <https://git-scm.com/docs>
- `gitignore(5)`, `gitattributes(5)`. <https://git-scm.com/docs/gitignore>
- *Conventional Commits* spec. <https://www.conventionalcommits.org/>
- *Chris Beams — "How to write a Git commit message"*. <https://cbea.ms/git-commit/>
- Git 2.23 release notes (introducción de `restore`/`switch`). <https://github.com/git/git/blob/master/Documentation/RelNotes/2.23.0.txt>
