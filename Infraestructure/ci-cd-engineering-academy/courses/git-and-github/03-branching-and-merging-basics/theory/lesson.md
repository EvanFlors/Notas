# Lección: Branching and merging basics

> **ID:** `gh-03-branching-and-merging-basics` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** `gh-02-recording-changes`.

---

## 1. Introducción intuitiva

Hasta aquí trabajamos sobre una sola línea de commits en `main`. Es cómodo porque todo es lineal, pero no refleja cómo se trabaja en la práctica: dos personas (o tú mismo en dos tareas) necesitan avanzar en paralelo sin pisarse. En otros sistemas de control de versiones esto se resolvía con *locks* ("yo tengo el archivo, nadie más puede tocarlo") o con `branch`es carísimas (cada rama era una copia física del repo, se creaban raras veces y se merecía una ceremonia).

En Git **una rama es casi nada**: un archivo de texto con un hash dentro. Costar nada tiene una consecuencia enorme: se te invita a crear ramas con frecuencia, cerrarlas rápido y vivir en un **grafo** en lugar de una línea.

Esta lección te enseña dos cosas que parecen una pero son dos:

1. **Modelar el trabajo con ramas efímeras**: crear, moverte, borrar.
2. **Reconciliar historia divergente**: `merge` (y, cuando hay conflictos reales entre dos ediciones, resolverlos razonando sobre las tres versiones involucradas).

El resto del curso descansa sobre esto. Si entiendes la mecánica del DAG aquí, `rebase`, `cherry-pick`, `revert -m`, pull requests y `bisect` dejan de ser magia.

---

## 2. Fundamentos

### 2.1 Una rama es un puntero móvil

Literalmente, el archivo `.git/refs/heads/main` contiene **un hash** y nada más:

```
$ cat .git/refs/heads/main
7a3f1c0b9e4a2d5f8c1b6e9a2d7c8b4e3f0a1d2b
```

Ese hash es el commit más reciente de `main`. Cuando haces un commit nuevo, Git:

1. Crea el commit con `parent = (hash actual de la rama)`.
2. **Reescribe** el archivo `refs/heads/main` para apuntar al nuevo commit.

Eso es todo. "La rama avanza" significa literalmente "cambié 40 bytes de texto". Por eso crear una rama es `O(1)` en tamaño del repo: solo escribir un archivo nuevo con un hash.

### 2.2 `HEAD` es una ref a una ref

`HEAD` es *tu posición actual* en el DAG. Normalmente es un **symbolic ref**:

```
$ cat .git/HEAD
ref: refs/heads/main
```

Es decir, "estoy en la rama `main`" significa que `HEAD` apunta al archivo `refs/heads/main`, que a su vez apunta al commit. Dos niveles de indirección.

Cuando haces `git switch feature/x`, Git reescribe `.git/HEAD` a `ref: refs/heads/feature/x` y actualiza working tree + index al tree de ese commit. Cuando commiteas, Git mueve `refs/heads/feature/x` (la ref apuntada por `HEAD`), nunca `HEAD` directamente.

Esta indirección es por qué puedes compartir ramas, renombrarlas, borrarlas y el modelo mental es consistente.

### 2.3 Detached HEAD

Si `HEAD` apunta **directamente a un commit** en lugar de a una rama, estás en **detached HEAD**:

```
$ git switch --detach <commit>
$ cat .git/HEAD
<hash-directo-sin-"ref:">
```

Esto no es un error. Es un estado perfectamente válido: puedes inspeccionar, incluso commitear. Pero los commits que hagas **no están en ninguna rama** — solo son alcanzables desde `HEAD`. Si te mueves (otro `switch`), esos commits quedan huérfanos y eventualmente los recoge `git gc`.

Para salir de detached HEAD de manera segura:

- `git switch -c nueva-rama` → crea una rama en el commit actual y se queda allí (rescata tu trabajo).
- `git switch main` → vuelve a `main` (si no commiteaste nada, no pierdes nada; si sí, lee la advertencia que Git imprime).

### 2.4 Qué es un **merge commit**

Un commit "normal" tiene **un padre**. Un **merge commit** tiene **≥ 2 padres**:

```
commit  7a3f1...
tree    bea12... ← snapshot resultado de combinar las dos ramas
parent  3c5a0... ← HEAD antes del merge (nuestra rama)
parent  9f8d2... ← otra rama que se mergeó
author  ...
```

El `tree` del merge commit es el resultado combinado. Los dos `parent` registran **de dónde vino cada ancestro**, lo que permite:

- Dibujar el DAG correctamente (`git log --graph`).
- Hacer `git revert -m 1 <merge>` ("deshaz el merge indicando cuál padre era el mainline").
- Encontrar la **merge base** (el ancestro común) de futuros merges entre esas ramas.

### 2.5 Fast-forward vs 3-way merge: cuándo pasa cada uno

Dadas dos ramas `A` y `B`:

- **Fast-forward**: `B` es un **ancestro directo** de `A` (no divergieron). Mergear `A` dentro de `B` equivale a mover la ref `B` hacia adelante hasta `A`. **No se crea commit nuevo.** Historia queda lineal.
- **3-way merge**: `A` y `B` divergieron (ambas avanzaron desde su ancestro común). Git construye un **tree combinando tres snapshots**: la **merge base** (ancestro común), **ours** (`B`, la rama en la que estamos) y **theirs** (`A`, la rama que estamos mergeando). Si no hay cambios conflictivos, lo hace automáticamente y produce un **merge commit** con dos padres.

```
Antes de FF:                    Antes de 3-way:
                                                  C ← main
A o---o---o              B      B o---o---o
         \                               \
          o---o B                         o---o A
                                              ↑ feature

Después de FF (git merge A):    Después de 3-way (git merge A):
A o---o---o---o---o B                  o---o---o---M ← main (merge commit)
                                         \       /
                                          o-----o
```

Puedes **forzar** cada caso con flags:

- `git merge --ff-only <ref>` → falla si no es FF (la rama tiene que estar al día o adelantada). Útil para enforzar historia lineal.
- `git merge --no-ff <ref>` → crea merge commit **aunque** fuese posible FF. Útil para que la historia muestre siempre "aquí entró la feature X".

---

## 3. Contexto histórico

Antes de Git, crear una rama era caro. En CVS significaba copiar literalmente el repo; en Subversion era mejor (un "cheap copy" como entrada de metadata) pero mergear era doloroso (SVN no registraba el ancestro común hasta la versión 1.5, 2008).

Git nació (2005) con la premisa opuesta: **branching barato** debía ser el default. Linus Torvalds necesitaba que el kernel pudiera tener literalmente miles de ramas de desarrollo en paralelo. La consecuencia fue inmediata: aparecieron workflows que antes eran impensables (**topic branches**, trunk-based, GitHub Flow, GitFlow, release branches).

En paralelo, la UX de la CLI arrastraba el problema de que `git checkout` hacía demasiadas cosas distintas (cambiar de rama, restaurar archivos, hacer detached HEAD). Git **2.23 (2019)** introdujo dos verbos nuevos:

- **`git switch`** → cambiar de rama (y solo eso).
- **`git restore`** → restaurar archivos (visto en `gh-02`).

El viejo `git checkout` sigue funcionando pero esta lección usa `switch` por claridad.

Otro cambio relevante: **`git mergetool`** (herramienta externa de 3-way merge en GUI) sigue existiendo desde los primeros años de Git, pero cada vez más gente resuelve conflictos directamente en el editor (VS Code, Neovim con plugins, etc.) porque los marcadores de conflicto estándar son suficientemente claros.

---

## 4. Funcionamiento interno

### 4.1 `git branch` y `git switch` paso a paso

```bash
git branch feature/x        # crea refs/heads/feature/x apuntando al commit actual (HEAD)
                            # NO cambia HEAD; sigues donde estabas
git switch feature/x        # reescribe .git/HEAD → "ref: refs/heads/feature/x"
                            # actualiza working tree + index al tree de ese commit
git switch -c feature/y     # combina ambos: crea rama Y cambia HEAD
```

Observa:

- `git branch X` **sin más argumentos** crea `X` en `HEAD` actual. Si pasas un segundo argumento (`git branch X <ref>`), la crea apuntando a `<ref>`.
- `git switch X` **falla** si tienes cambios locales que entrarían en conflicto con el checkout del nuevo tree. Puedes forzar con `--discard-changes` (destruye los cambios) o guardar con `git stash` antes.
- Borrar una rama (`git branch -d feature/x`) **falla** si la rama tiene commits que no están mergeados en ningún otro lugar (seguridad). `-D` fuerza; úsalo con conciencia.

### 4.2 Qué hace Git durante un 3-way merge

Dado `git merge feature` estando en `main`:

1. Encuentra la **merge base**: el commit común más reciente entre `main` y `feature`. Técnicamente `git merge-base main feature`.
2. Para cada archivo, compara tres versiones: `BASE`, `OURS` (main), `THEIRS` (feature).
3. **Decisiones automáticas por archivo**:
   - Si solo cambió en una rama → toma la versión cambiada.
   - Si cambió igual en ambas → toma esa versión (una vez).
   - Si cambió diferente en ambas en **líneas distintas** → combina los dos cambios.
   - Si cambió diferente en ambas en **las mismas líneas** → **conflicto**. Escribe el archivo con los marcadores `<<<<<<< ======= >>>>>>>` y deja el merge **inconcluso**.
4. Si **no** hubo conflictos, construye un nuevo tree combinado y crea el merge commit con dos padres. Abre el editor para el mensaje por defecto (`Merge branch 'feature'`).
5. Si **hubo** conflictos, Git **se detiene** sin crear commit. `git status` lista los archivos "unmerged". Tú editas, haces `git add`, y luego `git commit` para completar.

### 4.3 Anatomía de un marcador de conflicto

```
<<<<<<< HEAD                 ← inicio de "ours" (lo que había en tu rama)
hello from main
=======                       ← separador
hello from feature            ← "theirs" (lo que trae la rama que estás mergeando)
>>>>>>> feature               ← fin del bloque
```

Con `git config merge.conflictStyle diff3` se añade una tercera zona con la **base común**, muy útil para razonar:

```
<<<<<<< HEAD
hello from main
||||||| merged common ancestors
hello
=======
hello from feature
>>>>>>> feature
```

Resolver un conflicto es:

1. Decidir qué quieres (puede ser *ours*, *theirs*, una mezcla, o algo completamente nuevo).
2. **Borrar los marcadores** y dejar el archivo con el contenido final.
3. `git add <archivo>`.
4. Cuando todos estén resueltos, `git commit` (Git ya tiene el mensaje prellenado).

Puedes **abortar** y volver al estado pre-merge con `git merge --abort` en cualquier momento antes del commit final.

### 4.4 `git log --graph --oneline --all --decorate`

El comando que convierte el DAG abstracto en algo que puedes **ver**:

```
*   7a3f1c0 (HEAD -> main) Merge branch 'feature/greeting'
|\
| * 9f8d2a1 (feature/greeting) feat: add greeting
* | 3c5a0b2 docs: update README
|/
* 1a2b3c4 init: project
```

- `*` es un commit.
- `|` es la línea de una rama.
- `/` y `\` conectan merges y bifurcaciones.
- Lo que está entre paréntesis son las **refs** que apuntan a ese commit (`HEAD`, nombres de ramas, tags).

Alias útil (opcional, en tu `~/.gitconfig`):

```ini
[alias]
    lg = log --graph --oneline --all --decorate
```

---

## 5. Ejemplo mínimo

El ciclo entero en < 20 comandos:

```bash
mkdir -p /tmp/branch-demo && cd /tmp/branch-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "# Project" > README.md
git add README.md
git commit -q -m "init: README"

# Crear rama y moverse en una sola operación
git switch -c feature/greeting
echo "Hello from feature!" >> README.md
git add README.md
git commit -q -m "feat: add greeting"

# Volver a main
git switch main

# Caso 1: fast-forward (main no ha avanzado desde el branch-off)
git merge feature/greeting
# → "Fast-forward"; main ahora == feature/greeting

git log --graph --oneline --all --decorate
# Historia lineal, un solo rastro.
```

Ahora el **mismo escenario pero con 3-way**:

```bash
rm -rf /tmp/branch-demo && mkdir /tmp/branch-demo && cd /tmp/branch-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "# Project" > README.md
git add README.md
git commit -q -m "init: README"

git switch -c feature/greeting
echo "Hello from feature!" >> README.md
git add README.md
git commit -q -m "feat: add greeting"

git switch main
echo "## CI status" >> README.md       # cambio distinto en main
git add README.md
git commit -q -m "docs: add CI section"

git merge feature/greeting              # ahora NO puede FF: main avanzó
# → abre editor para el mensaje "Merge branch 'feature/greeting'"
# → crea merge commit con dos padres

git log --graph --oneline --all --decorate
# Verás una "M" con dos padres y dos ramas visibles.
```

Y un **conflicto real**:

```bash
rm -rf /tmp/branch-demo && mkdir /tmp/branch-demo && cd /tmp/branch-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"
git config merge.conflictStyle diff3

echo "greeting = hello" > config.txt
git add config.txt
git commit -q -m "init: config"

git switch -c feature/greeting
echo "greeting = hi" > config.txt       # misma línea, valor distinto
git add config.txt
git commit -q -m "feat: use 'hi'"

git switch main
echo "greeting = hola" > config.txt     # misma línea, valor distinto
git add config.txt
git commit -q -m "feat: use 'hola'"

git merge feature/greeting
# → CONFLICT (content): Merge conflict in config.txt
# → Automatic merge failed; fix conflicts and then commit the result.

cat config.txt
# <<<<<<< HEAD
# greeting = hola
# ||||||| merged common ancestors
# greeting = hello
# =======
# greeting = hi
# >>>>>>> feature/greeting

# Resuelve editando: por ejemplo, elegimos "hola, hi" como combinación.
printf 'greeting = hola, hi\n' > config.txt
git add config.txt
git commit -q -m "merge: combine greetings from both branches"

git log --graph --oneline --all --decorate
```

Observa: el merge commit **registra el conflicto resuelto como un commit normal** con dos padres. Nadie puede saber *desde el repo* qué estrategia usaste; por eso el mensaje importa.

---

## 6. Implementación progresiva

### 6.1 Convenciones de naming de ramas

Hay dos escuelas y las dos funcionan:

**Jerárquico con `/`**:

```
feature/add-auth
feature/jwt-refresh
bugfix/panic-on-nil
hotfix/csrf-token
release/1.4
chore/upgrade-deps
```

Ventaja: muchas herramientas (GitHub, GitLab, IDEs) agrupan por prefijo. `/` no es un separador especial de Git — es solo parte del nombre de la ref (`refs/heads/feature/add-auth`).

**Plano con `-`**:

```
add-auth
fix-nil-panic
upgrade-deps
```

Más simple en equipos chicos.

Lo importante:

- **Nombres cortos pero descriptivos**. "`fix`" no comunica nada; "`fix-login-timeout`" sí.
- **ASCII, minúsculas, sin espacios**. Git tolera más pero los pipelines no.
- Si usas issue tracker, puedes incluir el ID: `feature/PROJ-123-add-auth`.
- **Efímeras**: una rama de feature debe morir **el día** que se mergea. No las dejes como museo.

### 6.2 Workflow diario con ramas

```bash
# 1. Partir siempre de main actualizado
git switch main
git pull --ff-only          # si hay remoto; lo veremos en gh-04

# 2. Crear la rama del día
git switch -c feature/add-logout

# 3. Trabajar, committear atómico (como gh-02 enseñó)
#    ... edit ... git add -p ... git commit ...

# 4. Antes de mergear a main: asegurarte de que no divergió demasiado
git switch main
git pull --ff-only
git switch feature/add-logout
git merge main              # OR: git rebase main (gh-06). Decisión de equipo.
#   → si hay conflictos aquí, los resuelves en TU rama de feature,
#     no en main. Mucho más seguro.

# 5. Mergear a main
git switch main
git merge --no-ff feature/add-logout      # o --ff según convención
# → push (gh-04)

# 6. Borrar la rama local
git branch -d feature/add-logout
```

**El punto crítico es el paso 4**: tirar `main` **hacia** tu rama de feature antes del merge final te permite resolver conflictos en un lugar seguro (si tu rama se rompe, nadie se entera; si rompes `main`, se enteran todos).

### 6.3 Fast-forward vs `--no-ff`: cómo elegir

| Caso | Elección típica | Por qué |
|------|-----------------|---------|
| Rama efímera de 1–3 commits mergeando a `main` en un equipo pequeño | `--ff` (default) | Historia lineal, fácil de bisectar. |
| Rama de feature con 5+ commits en un equipo mediano | `--no-ff` | El merge commit documenta "aquí entró la feature X". Útil en reviews post-mortem. |
| Rama de hotfix a `release/X.Y` | `--no-ff` | Trazabilidad explícita del hotfix. |
| Historia de `main` como feed cronológico | `--no-ff` | Cada merge commit = una PR. |
| Historia de `main` como secuencia atómica | `--ff` + rebase antes del merge | Para `bisect` perfecto. |

La **política correcta** no existe en el vacío: depende del contrato que tenga el equipo con `main`. Si vuestras PRs se mergean con "squash and merge" en GitHub, estás en el modelo `--ff` lineal (lo veremos en `gh-07`).

### 6.4 `switch` vs `checkout`: equivalencias

| Antes (`checkout`) | Hoy (`switch` / `restore`) |
|--------------------|-----------------------------|
| `git checkout <branch>` | `git switch <branch>` |
| `git checkout -b <branch>` | `git switch -c <branch>` |
| `git checkout <commit>` (detached) | `git switch --detach <commit>` |
| `git checkout -- <file>` | `git restore <file>` |
| `git checkout <branch> -- <file>` | `git restore --source=<branch> <file>` |

`switch` **solo** cambia de rama/estado del HEAD. No lo verás restaurar archivos ni hacer cosas raras.

---

## 7. Aplicación profesional

### 7.1 Ramas efímeras como contrato de equipo

En equipos sanos:

- **Vida máxima de una rama de feature: días, no semanas.** Ramas largas → merge hell garantizado. Si una feature es grande, se parte en incrementos mergeables detrás de **feature flags**.
- **Un responsable por rama.** Varias personas en la misma rama simultáneamente es un patrón `gh-04` (lo veremos cuando llegue el momento), nunca un patrón de rama local.
- **Nombre que relate con un ticket o un objetivo.** Nadie debería tener que preguntar "¿qué hacía `rama-de-juan`?".
- **Borrar al mergear.** `git branch -d` local y, en el remoto, con GitHub automatizando `delete head branches` por default (lo configuraremos en `gh-07`).

### 7.2 Resolución de conflictos: la postura mental

El error más común es **entrar en pánico** y resolver sin leer. Un conflicto es una pregunta precisa de Git: *"estas dos ramas tocaron esta línea; dime cuál quieres"*. Para responder bien:

1. **Lee `git status` primero.** Te dice exactamente qué archivos están en conflicto.
2. **Para cada archivo, considera las tres versiones**: `BASE` (el ancestro común), `OURS` (tu lado), `THEIRS` (el lado que viene). Con `merge.conflictStyle=diff3` las ves todas.
3. **Pregúntate: ¿los dos cambios buscan el mismo objetivo o cosas distintas?**
   - Mismo objetivo (dos personas renombraron una variable con nombres distintos) → elige uno, coordina.
   - Objetivos distintos (uno añadió logging, otro cambió el valor por default) → mantén los dos cambios, combínalos.
4. **No committees archivos con marcadores dentro.** Es la basura #1 que se filtra en PRs. Un pre-commit hook simple (`git grep '<<<<<<<'`) lo evita (lo veremos en `gh-11`).
5. **Si no entiendes**, `git merge --abort` y pide ayuda. No hay orgullo en destruir el working tree por insistir.

### 7.3 `git mergetool`

Para conflictos complejos (muchos archivos, hunks grandes), lanzar `git mergetool` abre una herramienta de 3-way merge (**vimdiff**, **meld**, **kdiff3**, **p4merge**, VS Code con `code --wait --merge`, etc.) con las tres versiones lado a lado. Configuración:

```bash
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait --merge $REMOTE $LOCAL $BASE $MERGED'
git config --global mergetool.keepBackup false
```

Luego, durante un conflicto:

```bash
git mergetool
# Se abre la GUI por cada archivo en conflicto.
```

Útil, pero no esencial — con `diff3` + un buen editor, muchos devs resuelven sin herramientas.

---

## 8. Trade-offs

### 8.1 Merge vs rebase (preview)

El merge **preserva historia**: tu rama se añade con dos padres y el DAG muestra claramente que hubo paralelismo. El `rebase` (que verás en `gh-06`) **reescribe historia**: tus commits se "replantan" sobre la base más nueva, produciendo una línea limpia pero perdiendo el registro de que hubo divergencia.

| Dimensión | `merge` | `rebase` |
|-----------|---------|----------|
| Historia | Fiel a lo que pasó | "Como si siempre hubiera sido lineal" |
| Hashes | Preserva los originales | Reescribe (hashes nuevos) |
| Legibilidad del `log` | Más densa | Más limpia |
| Compatibilidad con PRs ya pusheados | Perfecta | Requiere `push --force-with-lease` y coordinación |
| Red de seguridad post-conflicto | Un solo punto de resolución | Un conflicto *por commit* potencialmente |

No elijas en el vacío: elige por el **contrato de historia** del equipo. Volveremos en `gh-06` y `gh-08`.

### 8.2 `--no-ff` vs `--ff`

**`--no-ff`** siempre crea un merge commit, incluso si fast-forward era posible. Pros: historia explícita, cada merge marca "aquí entró X". Contras: `main` se vuelve una sucesión de merges y bisect ve commits que no son "cambios reales" sino merges.

**`--ff`** (default) prefiere avanzar la ref sin merge commit cuando puede. Pros: historia lineal, bisect trivial. Contras: pierdes el agrupamiento visual de "esta tanda de commits era una feature".

Equipos con PRs grandes tienden a `--no-ff`; equipos trunk-based con PRs chicas tienden a `--ff` + rebase.

### 8.3 Resolución manual vs `git mergetool`

**Manual (editor + marcadores)**: cero setup, portable, suficiente en 95% de los casos.
**`mergetool`**: la curva vale la pena cuando resuelves conflictos a diario en archivos de 500 líneas con 10 hunks cada uno.

### 8.4 Ramas largas vs feature flags

Mantener una rama viva 3 semanas con un cambio grande es técnicamente posible y arquitectónicamente malo. **Feature flags** (encender/apagar código no terminado desde config) permiten mergear incrementos tempranos a `main` sin exponer la feature. Es el modelo trunk-based (lo abordamos en `gh-08`).

---

## 9. Errores frecuentes

### 9.1 "Hice `git switch --detach` y ahora `git log` no muestra mis commits"

**Síntoma**: committeaste en detached HEAD, hiciste `git switch main`, y tus commits "desaparecieron".

**Causa**: no estaban en ninguna rama. Al mover `HEAD`, se volvieron inaccesibles por nombre.

**Fix**: `git reflog` muestra todos los movimientos de `HEAD`; busca el hash y haz `git branch rescue <hash>`. Lección: **antes de salir de detached HEAD, crea una rama** (`git switch -c salvar`).

### 9.2 "Mergée y ahora tengo marcadores `<<<<<<<` committed"

**Síntoma**: `git grep '<<<<<<<'` encuentra basura dentro de archivos ya commiteados.

**Causa**: hiciste `git add` + `git commit` sin editar los archivos en conflicto.

**Fix inmediato (local, no pusheado)**: `git reset --soft HEAD~1`, edita los archivos para eliminar marcadores, `git add`, `git commit`. Si ya pusheaste a una rama compartida, mejor un commit nuevo "fix: resolve leftover merge markers" y nota mental: pre-commit hook en el futuro.

### 9.3 "Borré una rama y perdí el trabajo"

**Síntoma**: `git branch -D feature/x` y los commits parecen idos.

**Causa**: si los commits **no** estaban mergeados en ningún otro lugar, nada los retiene como alcanzables (excepto `reflog`, por un rato).

**Fix**: `git reflog` + `git branch feature/x <hash>` para resucitar la rama. Si pasaron semanas y corrió `gc`, es tarde. Lección: `-d` (minúscula) rechaza borrar ramas no-mergeadas; usa `-D` solo con conciencia.

### 9.4 "`git merge` dejó el repo en un estado raro y no sé cómo salir"

**Síntoma**: `git status` dice "You have unmerged paths" y no sabes qué hacer.

**Fix 1 — abortar**: `git merge --abort`. Vuelves al estado exacto pre-merge.
**Fix 2 — continuar**: resuelve los conflictos, `git add` cada archivo, `git commit` (Git ya tiene el mensaje de merge prellenado).

**Nunca** uses `git reset --hard` para "salir" de un merge si tienes trabajo local sin commitear — vas a destruirlo. `--abort` existe exactamente para esto.

### 9.5 "`git merge --ff-only` falla con 'Not possible to fast-forward, aborting'"

**Síntoma**: tu política es FF-only y Git dice que no se puede.

**Causa**: la rama destino **también** avanzó desde el branch-off; no es un FF.

**Fix**: necesitas un merge real (`git merge` sin `--ff-only`) o un `rebase` previo (`gh-06`) para linealizar.

### 9.6 "El merge commit lo creó Git automáticamente y el mensaje es horrible"

Por default `git merge` abre el editor con `Merge branch 'X'` como mensaje. En algunos sistemas (según `core.mergeAutoEdit`, GUIs, scripts), lo acepta sin preguntar. Resultado: muros de "Merge branch 'main' into feature/x" cada vez que alguien tira cambios hacia su rama.

**Fix**: edita el mensaje cuando se abra el editor para explicar *qué entra* ("Merge feature/add-logout: new /logout endpoint and tests"). Y en equipos: evitar los merges "upstream → downstream" repetidos (es síntoma de rama larga, ver 7.1).

### 9.7 "`git branch -d feature/x` dice 'not fully merged'"

**Síntoma**: Git rechaza borrar la rama.

**Causa correcta**: tiene commits que no están en `HEAD` ni en ninguna otra ref — perderías trabajo.

**Diagnóstico antes de forzar**:

```bash
git log <otra-rama>..feature/x    # qué commits de feature/x NO están en <otra-rama>
```

Si realmente son commits que no quieres, `git branch -D feature/x`. Si descubres que sí querías mergearlos, no fuerces.

---

## 10. Buenas prácticas

- **`git switch -c` para empezar, `git switch main` para volver.** Nunca te quedes en una rama por accidente.
- **Nombres descriptivos y efímeros.** `feature/add-oauth-login` > `work`.
- **`git log --graph --oneline --all --decorate` como reflejo**, antes y después de cualquier merge no trivial.
- **`merge.conflictStyle = diff3`** desde el día uno. La base común te salva horas.
- **Pull `main` *hacia* tu feature antes del merge final**, no al revés.
- **`--abort` sin miedo.** Es la red de seguridad del `merge`.
- **No committees marcadores `<<<<<<<`.** Un pre-commit hook simple lo evita.
- **`--no-ff` cuando quieras preservar el agrupamiento de la feature; `--ff` cuando priorices historia lineal.** Elige con el equipo, documenta en el README del repo.
- **Borra ramas mergeadas.** Un `git branch | wc -l > 20` es síntoma de higiene pobre.
- **Antes de `git branch -D`, piensa dos veces.** `git log <otra-ref>..<rama-a-borrar>` para ver qué perderías.
- **En detached HEAD, crea una rama antes de salir** si commiteaste algo.
- **El mensaje del merge commit es documentación.** No lo dejes en el default si entró una feature nombrable.

---

## 11. Ejercicios recomendados

1. **`activities/01-branch-and-merge/`** — guided-lab: ciclo completo (branch → FF merge → 3-way merge → resolver un conflicto simple sobre una línea).
2. **`activities/02-resolve-nontrivial-conflict/`** — guided-lab: tres ramas, dos merges, conflictos en archivos distintos que requieren razonamiento con `diff3`.

Entregable del módulo: salida de `git log --graph --oneline --all --decorate` de tu repo final de la actividad 02, pegada en tus notas o copiada a un `docs/graph.txt`.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Define en una frase cada uno de los siguientes conceptos y explica cómo se relacionan:
- rama
- `HEAD`
- commit
- merge base
- merge commit

**P2.** Verdadero / falso. Justifica cada respuesta con una línea.

- [ ] `git branch feature/x` cambia la rama actual a `feature/x`.
- [ ] `git switch --detach <commit>` crea una rama nueva.
- [ ] Un fast-forward crea un commit con dos padres.
- [ ] `git merge --abort` solo funciona si todavía no has hecho `git add` de los archivos resueltos.
- [ ] Un merge commit tiene siempre exactamente 2 padres.
- [ ] Al hacer `git switch other-branch`, `.git/HEAD` sigue siendo el mismo archivo pero cambia su contenido.

**P3.** Dado el siguiente DAG antes del merge:

```
*  C3  (main)
|
| *  F2  (feature/x)
| |
| *  F1
|/
*  C2
|
*  C1
```

Predice **sin ejecutar**:
- ¿`git merge feature/x` desde `main` es FF o 3-way? ¿Por qué?
- ¿Qué contendrá el nuevo HEAD de `main` tras el merge (en términos del DAG)?
- ¿Cuál es la merge base?

**P4.** Describes paso a paso qué ejecuta Git internamente cuando resuelves un conflicto en un único archivo `app.py`:
1. Qué hace al detectar el conflicto.
2. Qué hay en el working tree después del `merge` que falla.
3. Qué hace `git add app.py` tras editarlo.
4. Qué hace `git commit` final.
5. Qué quedó registrado en el DAG.

**P5.** Explica, con un dibujo del DAG antes y después, la **diferencia** entre:
- `git merge feature` (default)
- `git merge --ff-only feature`
- `git merge --no-ff feature`

cuando `feature` está adelante de `main` pero `main` **no** ha avanzado desde el branch-off.

**P6.** Diseña una convención de naming de ramas efímeras para un equipo de 6 devs que usa GitHub Flow y linkea cada PR a un issue. Justifica cada regla en una línea.

**P7.** Un colega hizo `git branch -D feature/payment` por accidente y había commits que no estaban en ninguna otra rama. ¿Qué comandos ejecutas para rescatarlos y qué garantías ofreces (hasta cuándo puede recuperarlos)?

**P8.** Para cada escenario, elige entre **`--ff`**, **`--no-ff`** o **rebase previo + `--ff-only`**, y explica por qué:
- (a) Un hotfix de 1 commit a `release/2.4`.
- (b) Una feature de 12 commits a `main` en un equipo que valora cada feature como unidad.
- (c) `main` en un repo donde `git bisect` corre nightly y necesita commits atómicos.
- (d) Mergeando `main` **hacia** tu rama de feature para actualizarla antes del PR final.

---

## Referencias

- *Pro Git* cap. 3 "Git Branching". <https://git-scm.com/book/en/v2>
- `git-branch(1)`. <https://git-scm.com/docs/git-branch>
- `git-switch(1)`. <https://git-scm.com/docs/git-switch>
- `git-merge(1)`. <https://git-scm.com/docs/git-merge>
- `git-mergetool(1)`. <https://git-scm.com/docs/git-mergetool>
- `git-log(1)` (sección `--graph`). <https://git-scm.com/docs/git-log>
- Git 2.23 Release Notes (introducción de `switch` y `restore`). <https://github.com/git/git/blob/master/Documentation/RelNotes/2.23.0.txt>
