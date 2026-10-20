# Lección: Rebase vs merge e interactivo

> **ID:** `gh-06-rebase-vs-merge-and-interactive` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `gh-03-branching-and-merging-basics`.

---

## 1. Introducción intuitiva

Llevas tres días en una rama `feature/payments`. Hiciste 8 commits: `wip`, `fix`, `another fix`, `oops`, `trying again`, `works now`, `cleanup`, `wip again`. Abres PR. El reviewer te pide: "¿Puedes dejar 1 o 2 commits limpios? Esto no se puede revisar".

Tienes dos caminos:
1. **Mantener la historia tal cual** y pedir que la revisen como está. GitHub la mergeará con un merge commit o la aplastará ("squash and merge") a tu nombre.
2. **Reescribirla antes del merge** para que *tú* decidas la narrativa: 2 commits bien definidos, con mensajes útiles para alguien que haga `git bisect` en 6 meses.

Este módulo trata del segundo camino: **`git rebase`**. Pero también trata del juicio: *cuándo* reescribir (tu rama privada antes del PR, siempre) y *cuándo no* (ramas compartidas, `main`, cualquier cosa que otra persona haya fetchado — nunca).

La otra cara: **`git merge`** no reescribe nada. Cada merge deja constancia explícita ("estas dos líneas de trabajo se juntaron aquí"). Es honesto, pero produce DAGs ruidosos cuando se abusa. La discusión "rebase vs merge" es la más religiosa del mundo Git, y la respuesta real es: **depende del equipo, de la rama, y de lo que quieras que diga tu `git log --graph` en 2 años**.

Entender bien ambas operaciones te permite tomar esa decisión con criterio, no por imitación.

---

## 2. Fundamentos

### 2.1 Repaso: qué es un commit, qué es una rama

De `gh-01` y `gh-03`:

- Un **commit** es un objeto inmutable `(tree, parent(s), author, committer, message)` identificado por el hash SHA-1 de su contenido serializado.
- Una **rama** es una ref: un puntero móvil (`refs/heads/<nombre>`) a un commit.
- `HEAD` apunta a una rama (modo normal) o directamente a un commit (modo "detached").

**Corolario clave para esta lección:** si cambias cualquier byte de un commit —incluido su padre— **cambia su hash**. Por eso rebase "reescribe historia": copia cada commit con un parent distinto, generando commits *nuevos* con hashes distintos. Los viejos quedan unreachable (pero vivos en `.git/objects/` hasta que `git gc` los recoja, y durante ~90 días están en `reflog`).

### 2.2 Merge vs rebase: dos modelos distintos

Imagina este estado:

```
          A---B---C   feature
         /
    D---E---F---G    main
```

Trabajaste en `feature` (A, B, C) desde el commit E. Mientras tanto, `main` avanzó con F y G. Quieres integrar `feature` en `main`.

**Opción 1: merge** (`git switch main && git merge feature`):

```
          A---B---C
         /         \
    D---E---F---G---M    main
```

M es un **merge commit**: tiene **dos padres** (G y C). La historia queda ramificada visualmente, pero preservada: puedes ver que A, B, C son una línea de trabajo distinta de F y G.

**Opción 2: rebase** (`git switch feature && git rebase main`):

```
                      A'--B'--C'   feature
                     /
    D---E---F---G                  main
```

A, B, C se **reaplican** uno a uno sobre G, produciendo commits nuevos A', B', C' con mismos cambios pero padres distintos (A'→G, B'→A', C'→B'). La rama feature ahora es *lineal* respecto a main. Si después haces `git switch main && git merge feature`, es un **fast-forward**: main simplemente avanza hasta C'.

Resultado final tras `rebase + ff-merge`:

```
    D---E---F---G---A'---B'---C'   main (= feature)
```

**La diferencia esencial:**
- `merge` **añade** un commit (M) y preserva la topología.
- `rebase` **reescribe** commits (A→A', B→B', C→C') y linealiza.

### 2.3 Por qué cambian los hashes

El parent es parte del contenido hasheado del commit. En `rebase`:
- A tenía `parent = E`. El nuevo A' tiene `parent = G`. Mismo tree, mismo mensaje, mismo autor — pero distinto parent → distinto hash.
- B tenía `parent = A`. El nuevo B' tiene `parent = A'`. Mismo tree, mismo mensaje — distinto parent → distinto hash. Y así en cascada.

**"Perder información"** en rebase significa: los padres originales (A→E, B→A, C→B) ya no son recuperables desde la rama rebasada. Si alguien había basado trabajo sobre A, su commit sigue apuntando a A (que está en `.git/objects/` pero unreachable desde ninguna rama). Esa es la raíz de los dolores de cabeza cuando rebasas historia compartida.

### 2.4 La red de seguridad: reflog

`git reflog` guarda cada movimiento de `HEAD` y de cada rama local durante ~90 días por default (`gc.reflogExpire`). Tras un rebase catastrófico:

```bash
git reflog                                   # busca el estado anterior al rebase
# ejemplo: a1b2c3d HEAD@{5}: rebase (start): checkout main
# el commit justo antes está en HEAD@{6}
git reset --hard HEAD@{6}                    # restauras la rama a su estado pre-rebase
```

Esto se cubre en profundidad en `gh-10`, pero importa aquí: **ningún rebase es irreversible** mientras tengas el reflog local. El problema real son los **colegas** que fetchearon tus commits viejos y ahora tienen una historia divergente con los nuevos.

---

## 3. Contexto histórico

- **2005** — Linus Torvalds crea Git. `rebase` existe desde las primeras versiones; `rebase -i` llega poco después.
- **2007** — `git rebase -i` (interactive) se consolida con las acciones `pick`/`squash`/`edit`.
- **2010s** — adopción masiva de GitHub normaliza el PR workflow; nace la guerra "merge vs rebase" en blogs y en Reddit.
- **~2015** — `fixup!` y `--autosquash` facilitan el workflow "fix commits + rebase final" sin editar el todo file a mano.
- **2018+** — GitHub añade "Squash and merge" y "Rebase and merge" como botones del PR; muchos equipos dejan de rebasar a mano y delegan en el UI.
- **2022** — Git 2.38 introduce `git rebase --update-refs`: cuando una rama intermedia de una stack se rebasa, las refs intermedias se mueven también. Resuelve un problema clásico de las "stacked PRs".
- **2023+** — herramientas de "stacked diff" (Graphite, Sapling, Jujutsu) empiezan a popularizar flujos donde rebase es la operación por default y merge commits son la excepción.

El debate "merge vs rebase" **nunca se cerró** porque no tiene respuesta universal. La respuesta correcta depende del equipo, el tamaño del repo, el modelo de release y la cultura de code review.

---

## 4. Funcionamiento interno

### 4.1 Qué hace `git rebase <base>` paso a paso

```bash
git switch feature
git rebase main
```

Pseudocódigo del algoritmo:

```
1. Calcular ancestro común: merge_base = $(git merge-base feature main)
2. Listar commits de feature que no están en main:
     commits = git log --reverse ${merge_base}..feature
3. Checkout a main (estado detached).
4. Para cada commit C en commits:
     a. Aplicar su diff al working tree (como un cherry-pick).
     b. Si hay conflicto: parar, el usuario resuelve y hace `git rebase --continue`.
     c. Crear un commit nuevo C' con mismo mensaje/autor pero parent = HEAD actual.
     d. Mover HEAD al nuevo C'.
5. Mover la ref `feature` al último C' creado.
```

Los commits viejos (C, C', C'') quedan unreachable; los nuevos (C_new, C'_new, C''_new) forman la rama rebasada.

### 4.2 Qué hace `git rebase -i <base>`

Idéntico a `rebase <base>` pero **antes de empezar** abre tu editor con el **todo file**:

```
pick a1b2c3d feat: add refund endpoint
pick e4f5g6h fix: handle null payment_id
pick i7j8k9l wip: refactor processor
pick m0n1o2p oops forgot test
pick q3r4s5t test: cover refund processor

# Rebase 7891011..q3r4s5t onto 7891011 (5 commands)
#
# Commands:
# p, pick <commit>   = use commit
# r, reword <commit> = use commit, but edit the commit message
# e, edit <commit>   = use commit, but stop for amending
# s, squash <commit> = use commit, but meld into previous commit
# f, fixup <commit>  = like "squash", but discard this commit's log message
# x, exec <command>  = run command (the rest of the line) using shell
# b, break           = stop here (continue rebase later with 'git rebase --continue')
# d, drop <commit>   = remove commit
# l, label <label>   = label current HEAD with a name
# ...
```

Tú editas este archivo. Cuando lo guardas y cierras el editor, Git ejecuta el plan. Reglas:

- El **orden** de las líneas es el orden de aplicación (los commits abajo son los más recientes).
- `pick` → aplica el commit tal cual.
- `reword` → aplica el commit, luego abre editor para cambiar el mensaje.
- `edit` → aplica el commit, luego pausa en modo "amend"; tú modificas lo que quieras y `git rebase --continue`.
- `squash` → aplica el commit y lo fusiona con el anterior; abre editor para combinar los dos mensajes.
- `fixup` → como `squash`, pero descarta el mensaje de este commit (usa el del anterior).
- `drop` o borrar la línea → el commit no se incluye.
- `exec cmd` → ejecuta `cmd` tras el commit anterior. Útil para `exec make test` entre commits.
- `break` → pausa; tú continúas con `git rebase --continue` cuando quieras.

### 4.3 El truco de `GIT_SEQUENCE_EDITOR` para automatizar

`rebase -i` necesita que un editor abra el todo file. En scripts, CI, o actividades reproducibles no queremos abrir Vim. Git tiene **dos** variables de editor:

- `GIT_EDITOR` (o `core.editor`) — editor para mensajes de commit, merge messages, etc.
- `GIT_SEQUENCE_EDITOR` — editor **solo** para el todo file de `rebase -i`.

Si asignas `GIT_SEQUENCE_EDITOR` a cualquier comando que **modifique in-place** el archivo que recibe como argumento, Git lo usa en lugar de abrir un editor interactivo. Ejemplos:

```bash
# Marcar todos los commits salvo el primero como `squash`:
GIT_SEQUENCE_EDITOR='sed -i -e "2,\$s/^pick/squash/"' \
  git rebase -i HEAD~5

# Marcar el segundo commit como `fixup`:
GIT_SEQUENCE_EDITOR='sed -i -e "2s/^pick/fixup/"' \
  git rebase -i HEAD~3

# Reemplazar todo el todo file por uno escrito a mano:
GIT_SEQUENCE_EDITOR='cp /tmp/my-plan.txt' \
  git rebase -i HEAD~5
```

En macOS BSD `sed` requiere `sed -i ''` (comilla vacía) en lugar de `sed -i`. En Linux es `sed -i` sin argumento. En este curso usamos `sed -i.bak` que funciona en ambos y deja un `.bak` que podemos ignorar o borrar.

Para los mensajes que `reword` y `squash` solicitan, también se necesita evitar el editor:

```bash
GIT_SEQUENCE_EDITOR='sed -i.bak "2s/^pick/reword/"' \
GIT_EDITOR='sed -i.bak "1c\\
feat(payments): new refund processor"' \
  git rebase -i HEAD~3
```

Esta técnica se usa en las actividades para que `validate.sh` sea reproducible. **Memorízala**: también sirve para instrumentar `rebase -i` desde pre-commit hooks, scripts de release, o para enseñar.

### 4.4 `--autosquash` + `--fixup`

Workflow típico mientras trabajas en una rama:

```bash
# commit normal
git commit -m "feat(payments): add refund endpoint"

# luego descubres un bug en ese commit
# en lugar de "fix: typo" como commit nuevo, haces fixup:
git commit --fixup=HEAD                    # el mensaje queda: "fixup! feat(payments): add refund endpoint"

# otro fixup contra un commit más viejo:
git commit --fixup=a1b2c3d                 # "fixup! <subject de a1b2c3d>"
```

Al final, un solo rebase los acomoda:

```bash
git rebase -i --autosquash main
```

El todo file ya viene **con los fixup! reordenados** debajo de sus targets y marcados como `fixup`. Solo tienes que confirmar.

Para hacerlo *totalmente* automático:

```bash
git -c sequence.editor=true rebase -i --autosquash main
```

`sequence.editor=true` usa `/bin/true` como editor — no cambia nada, acepta el plan generado.

### 4.5 `--onto`: mover commits entre bases

Firma: `git rebase --onto <newbase> <upstream> [<branch>]`.

Caso de uso: creaste `feature/new-widget` **desde la rama equivocada** (`release/1.0` en lugar de `main`). Tiene 3 commits que **no** quieres descartar; los quieres sobre `main`.

```
                       X---Y---Z    feature/new-widget
                      /
    A---B---C---D---E              release/1.0
             \
              F---G                main
```

Comando:

```bash
git rebase --onto main release/1.0 feature/new-widget
```

Significado literal: "toma los commits de `feature/new-widget` que **no** están en `release/1.0` (es decir, X, Y, Z), y reaplícalos sobre `main`".

Resultado:

```
                       X---Y---Z    (viejos, unreachable)
                      /
    A---B---C---D---E              release/1.0

              F---G---X'---Y'---Z'    main / feature/new-widget
```

Sin `--onto`, un `git rebase main feature/new-widget` tomaría los commits desde el merge-base (B o A) e incluiría C, D, E — que *no* queremos.

Regla mnemónica:
- `<upstream>` = la base **vieja** (de donde salen los commits a extraer).
- `<newbase>` = la base **nueva** (donde los pegamos).
- `[<branch>]` = la rama a reescribir (opcional; si lo omites, usa HEAD).

### 4.6 `git cherry-pick`

Toma un commit cualquiera y lo aplica sobre `HEAD` como un commit nuevo.

```bash
git switch main
git cherry-pick a1b2c3d           # el commit a1b2c3d se replica como un commit nuevo sobre main
```

Relación con rebase: `rebase` es internamente una secuencia de cherry-picks ordenados. `cherry-pick` solo es útil para 1-N commits sueltos. Para rangos grandes o cambios de base, usa `rebase`.

Útil para:
- Backport de un fix de `main` a `release/1.2`.
- Rescatar un commit de una rama abandonada.
- Aplicar un parche de otra persona cuyo PR no se mergeará.

### 4.7 `git rerere` (reuse recorded resolution)

Si rebasas la misma rama varias veces contra una `main` que avanza, probablemente resolverás **el mismo conflicto** dos o tres veces. `rerere` memoriza tu resolución y la aplica automáticamente la próxima vez:

```bash
git config --global rerere.enabled true
```

A partir de ahí, cada vez que resuelves un conflicto, Git guarda `(diff del conflicto) → (tu resolución)` en `.git/rr-cache/`. En la próxima aparición idéntica, Git aplica la resolución automáticamente (todavía tienes que `git add` y `git rebase --continue`, pero el merge en sí ya está hecho).

Barato, útil, infrautilizado.

### 4.8 `--update-refs` (Git ≥ 2.38)

Si tienes una **stack** de ramas:

```
    A---B---C---D---E    featureA
                 \
                  F---G    featureB  (basada en D de featureA)
```

Y rebasas `featureA` contra `main`, los commits A, B, C, D, E se vuelven A', B', C', D', E'. **La ref `featureB` todavía apunta al D viejo**, que ya no es alcanzable desde `featureA'`. Resultado: tu stack se rompe.

Con `--update-refs`:

```bash
git rebase --update-refs main featureA
```

Git detecta que `featureB` apunta a un commit *dentro* del rango rebasado (D) y mueve `featureB` a D' automáticamente. Tu stack queda consistente.

Puede activarse como default:

```bash
git config --global rebase.updateRefs true
```

**Recomendado si trabajas con stacks de PRs**. Sin esto, mantener stacks a mano es doloroso.

---

## 5. Ejemplo mínimo

```bash
# Setup
mkdir -p /tmp/rebase-mini && cd /tmp/rebase-mini
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

echo "line 1" > file.txt
git add file.txt && git commit -q -m "init"

# Simulamos una rama feature con 3 commits WIP
git switch -c feature
echo "wip 1" >> file.txt && git commit -q -am "wip"
echo "wip 2" >> file.txt && git commit -q -am "wip 2"
echo "wip 3" >> file.txt && git commit -q -am "actually works"

# Historia actual:
git log --oneline
# <h3> actually works
# <h2> wip 2
# <h1> wip
# <h0> init

# Objetivo: colapsar los 3 WIP en 1 commit "feat: add lines".
# Usamos rebase -i con GIT_SEQUENCE_EDITOR para no abrir editor:
GIT_SEQUENCE_EDITOR='sed -i.bak -e "2,3s/^pick/fixup/"' \
GIT_EDITOR='sed -i.bak "1c\\
feat: add lines"' \
  git rebase -i HEAD~3

git log --oneline
# <h4> feat: add lines
# <h0> init
```

Resultado: 3 commits → 1 commit, mensaje nuevo, contenido final idéntico. Los 3 viejos siguen en `git reflog` por 90 días.

---

## 6. Implementación progresiva

### 6.1 Rebase lineal (no interactivo) tras `pull`

Workflow diario clásico en un equipo con rebase default:

```bash
# Config global una sola vez:
git config --global pull.rebase true          # pull hace fetch + rebase (no merge)
git config --global rebase.autoStash true     # stash automático si tienes cambios locales

# Día a día:
git switch feature
# trabajas, commiteas localmente
git fetch origin                              # trae lo nuevo de main sin tocar tus refs locales
git rebase origin/main                        # reaplica tus commits sobre main actualizado

# Si hay conflicto:
# ... editas los archivos ...
git add <archivos-resueltos>
git rebase --continue

# Si quieres abortar:
git rebase --abort                            # vuelve al estado pre-rebase
```

### 6.2 Rebase interactivo: cleanup antes de PR

```bash
# Supón 5 commits en tu rama:
#   e4f5g6h test: add tests for refund
#   c3d4e5f fix: typo in error message
#   a1b2c3d wip: refactor
#   9f0g1h2 fix: add missing newline
#   7891011 feat: refund endpoint

# Plan: colapsar los dos "fix" y el "wip" dentro del "feat", mantener los tests
# en un commit propio con mejor nombre.

git rebase -i HEAD~5
```

En el editor cambias a:

```
pick 7891011 feat: refund endpoint
fixup 9f0g1h2 fix: add missing newline
fixup a1b2c3d wip: refactor
fixup c3d4e5f fix: typo in error message
reword e4f5g6h test: add tests for refund
```

Guardas y cierras. El `reword` abre un segundo editor; escribes:

```
test(payments): cover refund processor
```

Resultado:
```
<new-h2> test(payments): cover refund processor
<new-h1> feat: refund endpoint         (ya contiene todos los fixes)
<base>   ...
```

### 6.3 Workflow con `--fixup` + `--autosquash`

Mientras trabajas:

```bash
git commit -m "feat(payments): refund endpoint"
# ... pruebas, falla ...
git add -p
git commit --fixup=HEAD                       # subject: "fixup! feat(payments): refund endpoint"

# más código, más fixes contra commits viejos:
git log --oneline
git commit --fixup=a1b2c3d                    # fixup contra commit a1b2c3d

# cuando terminas la feature:
git rebase -i --autosquash main
```

El todo file viene pre-ordenado:

```
pick a1b2c3d feat: X
fixup j7k8l9m fixup! feat: X
pick b2c3d4e feat(payments): refund endpoint
fixup h4i5j6k fixup! feat(payments): refund endpoint
```

Solo confirmas (o automatizas con `sequence.editor=true`).

### 6.4 `--onto` paso a paso

Partida: rama creada desde `release/1.0` (equivocado) con 3 commits de feature. Mientras tanto `main` tiene commits propios.

```bash
git log --oneline --all --graph
# * 9f0 (feature/new-widget) widget: finish
# * 7e8 widget: wire backend
# * 5d6 widget: scaffold
# | * c3d (main) feat: billing
# | * b2c unrelated change
# |/
# * a1b (release/1.0) release 1.0
# * ...

# Objetivo: feature/new-widget debería colgar de main, no de release/1.0.
git switch feature/new-widget
git rebase --onto main release/1.0

git log --oneline --all --graph
# * 9f0' (feature/new-widget) widget: finish
# * 7e8' widget: wire backend
# * 5d6' widget: scaffold
# * c3d (main) feat: billing
# * b2c unrelated change
# * a1b (release/1.0) release 1.0
```

### 6.5 Push tras rebase

Si la rama estaba en remoto y la rebasaste:

```bash
# NUNCA:
git push --force                              # sobrescribe sin preguntar

# SÍ:
git push --force-with-lease                   # solo sobrescribe si el remoto está en el commit que esperas
```

`--force-with-lease` compara el estado remoto con el que *tú* fetchaste la última vez. Si alguien pusheó algo nuevo mientras tanto, el push falla y tienes la oportunidad de reconciliar. Es la versión civilizada del force push.

Aún mejor:

```bash
git push --force-with-lease --force-if-includes
```

`--force-if-includes` requiere que los commits del remoto estén *incluidos* en lo que vas a pushear. Protege contra el escenario "fetcheé hace 2 h, otro dev pusheó hace 1 h, --force-with-lease pasa pero igual pierdo su trabajo".

---

## 7. Aplicación profesional

### 7.1 La regla de oro: no rebases historia pública

**Pública = ya fetchada por alguien más.** Formalmente:
- Cualquier commit en `main`, `master`, `release/*`, `develop` → público.
- Cualquier commit en una rama compartida en remoto (incluso una `feature/*` si otro dev la fetcheó) → público.
- Commits en tu rama local que **nadie** ha fetchado → privados.

Rebasar commits privados → libre. Rebasar públicos → prohibido salvo coordinación explícita.

**Por qué**: si Alice tenía `feature/x` basado en commits viejos A, B, C y tú rebasas y pusheas A', B', C' con force, el próximo `git pull` de Alice verá dos historias divergentes y producirá un merge horrible (o duplicará los commits en su copia local). Rompes a tu colega.

### 7.2 Políticas de equipo (cuatro arquetipos)

**A. "Trunk-based + rebase-only"** (startups rápidas, infra como código).
- `main` es la única rama protegida.
- Ramas feature son cortas (horas o pocos días).
- Rebase local antes del PR es obligatorio ("deja la historia limpia").
- GitHub: "Rebase and merge" o "Squash and merge" como únicos botones.
- `git log --graph` es lineal, legible.

**B. "GitHub Flow + merge commits"** (equipos medianos, SaaS).
- `main` + ramas feature.
- PRs se cierran con merge commit (`git merge --no-ff`).
- Rebase se usa solo dentro de la rama feature para limpiar antes del PR, no después.
- GitHub: "Create a merge commit" como default.
- `git log --graph` muestra claramente qué PR introdujo qué.

**C. "GitFlow"** (equipos grandes con releases planeados, software empaquetado).
- `main`, `develop`, `release/*`, `hotfix/*`, feature branches.
- **Merge en todas partes** (preserva la trazabilidad entre ramas).
- Rebase se limita a feature privadas antes del PR a `develop`.
- `git log --graph` es denso pero rico en información.

**D. "Rebase everything, incluso main"** (teams con stacked diff tooling, Jujutsu, Sapling).
- Reescritura constante, red de seguridad en el servidor (no se borran commits unreachable), tooling cuida la consistencia.
- Fuera del scope de este curso; mencionar como existente.

### 7.3 Checklist antes de rebasar

Antes de ejecutar `git rebase`:

1. ¿Estoy en mi rama local privada? ¿O comparto esta rama?
2. ¿Hay commits ajenos (otros autores) en el rango que voy a reescribir? Si sí, pausa.
3. ¿Tengo backup? (El reflog cuenta, pero mentalmente ten claro cómo volver).
4. ¿Entiendo qué commits van a cambiar de hash?
5. ¿Qué `--force` necesitaré? Si `main` → **no rebases main**.

### 7.4 "Rebase and merge" en GitHub: cuándo y cuándo no

Cuando ves los tres botones de merge en GitHub:

- **Create a merge commit** — produce un merge commit M con dos padres. Historia honesta, DAG ancho.
- **Squash and merge** — toma todos los commits del PR, los aplasta en 1 commit, usa el título del PR como mensaje. Historia *extremadamente* lineal, se pierde el detalle del commit-by-commit.
- **Rebase and merge** — rebasea los commits del PR sobre `main` y hace fast-forward. Historia lineal con commits individuales preservados.

Decisión:
- PR con 1 commit decente → "Rebase and merge" o "Squash and merge" (equivalentes).
- PR con N commits bien curados que *cada uno* tiene sentido → "Rebase and merge".
- PR con N commits WIP sin curar → "Squash and merge" (si no vas a limpiar) o rebase-interactivo local + "Rebase and merge" (si sí vas a limpiar).
- PR grande donde la historia importa (migración, refactor masivo) → "Create a merge commit" para preservar el contexto.

Esto se profundiza en `gh-07`.

---

## 8. Trade-offs

### 8.1 Merge vs rebase (resumen operativo)

| Dimensión | `merge` | `rebase` |
|-----------|---------|----------|
| Reescribe hashes | No | Sí |
| Preserva topología | Sí (merge commit) | No (lineal) |
| Seguro con historia pública | Sí | No |
| Produce `git log` lineal | No | Sí |
| Conflictos | 1 vez, en el merge commit | N veces, uno por cada commit reaplicado |
| Útil tras `pull` | Default clásico | `pull --rebase` moderno |
| Útil pre-PR cleanup | No | Esencial |
| Puede dañar colegas | No | Sí si pusheas |

### 8.2 `squash` vs `fixup`

- **`squash`** combina y **abre editor** para fusionar los dos mensajes. Útil cuando ambos mensajes aportan contexto.
- **`fixup`** combina y **descarta** el mensaje del commit absorbido. Útil cuando el mensaje era "typo" o "wip" y no agrega nada.

Regla práctica: casi siempre `fixup`. `squash` cuando combinas dos commits semánticamente distintos y el mensaje nuevo debe reflejar ambos.

### 8.3 `pull.rebase=true` global: pros/contras

**Pros**:
- Historia local más lineal, menos merge commits de ruido en `git log`.
- Resuelves conflictos antes de pushear, no durante el merge.

**Contras**:
- Si tienes commits que son merges intencionales, `pull --rebase` los convierte en lineales (perdiendo info).
- Puede sorprender a devs acostumbrados a `pull` clásico.

Recomendación: `pull.rebase=true` para la mayoría; `pull.ff=only` como alternativa más conservadora (requiere decisión explícita en divergencias).

### 8.4 `--force-with-lease` vs `--force`

- `--force` — sobrescribe la ref remota pase lo que pase. **Antipatrón.** Nunca debería estar en tu memoria muscular.
- `--force-with-lease` — compara contra lo que fetchaste; si cambió, aborta. Casi tan seguro como posible.
- `--force-with-lease --force-if-includes` — además verifica que los commits ajenos están incluidos en el push. Lo más seguro.

**Alias recomendado:**
```bash
git config --global alias.fpush 'push --force-with-lease --force-if-includes'
```

### 8.5 Rebase interactivo manual vs `--autosquash`

- **Manual** — editar el todo file da control total pero cuesta tiempo y es error-prone.
- **`--autosquash` con `--fixup`** — baratísimo durante el trabajo (`git commit --fixup`) y automático al final. Preferir siempre que el flujo lo permita.

---

## 9. Errores frecuentes

### 9.1 "Rebasé main y ahora todo el equipo tiene conflictos"

Síntoma: pusheaste con `--force` a `main`. Los colegas en su siguiente `pull` ven decenas de commits duplicados.

Fix:
- Avisa inmediatamente.
- La única forma limpia es que **todos** reseteen su `main` local al nuevo:
  ```bash
  git fetch origin
  git reset --hard origin/main
  ```
- Trabajo no commiteado se stashea antes.

Prevención: branch protection en `main` que **rechaza force pushes** (nativo en GitHub Rulesets, ver `gh-12`).

### 9.2 "Hice `git rebase -i`, borré una línea sin querer, perdí un commit"

Si borras una línea del todo file, ese commit se **drop**ea. Si guardas y cierras, está "perdido".

Recuperación:
```bash
git reflog                                   # busca el hash del commit perdido
git cherry-pick <hash>                       # lo trae de vuelta
```

Prevención: **no borres líneas** en el todo file. Usa `drop` explícito o `fixup` si quieres combinarlo.

### 9.3 "Conflicto durante rebase, lo resolví mal y ahora no sé cómo abortar"

```bash
git rebase --abort                           # vuelve al estado pre-rebase
```

Si ya hiciste `git rebase --continue` con una resolución mala, el commit resultante tiene el error. Puedes `git reset --hard HEAD@{N}` desde reflog, o repetir el rebase.

### 9.4 "`git pull` me creó un merge commit raro"

Causa: `pull.rebase` no está activo y tenías commits locales + commits remotos → merge automático.

Fix:
```bash
git reset --hard HEAD@{1}                    # deshaz el pull
git fetch origin
git rebase origin/main                       # rebase explícito
```

Prevención: `git config --global pull.rebase true`.

### 9.5 "Rebaseé y los commits aparecen duplicados en el PR"

Causa: pusheaste sin `--force-with-lease`. Git hace fast-forward imposible, falla, y haces... ¿qué? Si hiciste `git pull` para "arreglarlo", mergeas la historia vieja con la nueva → duplicados.

Fix:
```bash
git log --oneline                            # verifica que localmente la historia está bien
git push --force-with-lease                  # ahora sí
```

Prevención: aprende que rebase + push = `--force-with-lease`, siempre.

### 9.6 "`--autosquash` no reordena nada"

Causas comunes:
- No usaste `--fixup=<hash>` al commitear; usaste `fix: ...` como mensaje normal → Git no reconoce el prefijo "fixup!".
- Usaste `git commit -m "fixup: ..."` (con dos puntos y espacio) en lugar de `--fixup=<hash>` → mal formato.

Fix: siempre `git commit --fixup=<hash>` (o `--fixup=HEAD`).

### 9.7 "`git rebase --onto` tomó commits que no quería"

Síntoma: después del rebase hay commits raros que no son de tu feature.

Causa: calculaste mal `<upstream>`. `<upstream>` debe ser la **base original** de la rama. Si pones la `main` nueva como `<upstream>`, Git toma commits incorrectos.

Fix: `git rebase --abort`. Vuelve a calcular `git merge-base feature <base-correcta>` y usa esa base como `<upstream>`.

### 9.8 "Reescribí commits firmados y perdí la firma"

Rebase genera commits nuevos. Si el original estaba firmado (SSH/GPG) y tu config no tiene auto-sign, los nuevos **no estarán firmados**.

Fix:
```bash
git config --global commit.gpgsign true      # o commit.gpgsign + gpg.format=ssh
git rebase --exec 'git commit --amend --no-edit -S' ...
```

Alternativa limpia: `git rebase -i --signoff` (añade trailer) o configurar `rebase.gpgSign=true`.

---

## 10. Buenas prácticas

- **Nunca rebases ramas compartidas.** Si en duda, haz `merge`.
- **Rebase local antes del PR.** Deja 1-5 commits bien definidos; no abras un PR con "wip wip wip actually works".
- **Usa `--fixup` durante el trabajo.** `--autosquash` al final cuesta cero.
- **`pull.rebase=true` por default**, salvo que tu equipo haya decidido otra cosa.
- **Siempre `--force-with-lease`**, nunca `--force`. Idealmente alias que incluya `--force-if-includes`.
- **Branch protection en `main`** rechaza force pushes; actívalo desde el día 1.
- **`rerere.enabled=true`** si rebaseas una rama varias veces durante su vida.
- **`rebase.updateRefs=true`** si usas stacks de PRs.
- **Reflog es tu red de seguridad.** 90 días default. No desactives `gc.reflogExpire` sin motivo.
- **No borres líneas del todo file.** Usa `drop` explícito.
- **Automatiza en scripts con `GIT_SEQUENCE_EDITOR`.** Útil en pre-commit hooks, release scripts y actividades reproducibles.
- **Documenta en el repo** qué política de merge siguen (CONTRIBUTING.md), así nadie improvisa.

---

## 11. Ejercicios recomendados

1. **`activities/01-squash-and-reorder/`** — guided-lab: parte de una rama con 5 commits WIP y produce 2 commits limpios con `rebase -i` + `squash`/`fixup`/`reword`. Usa `GIT_SEQUENCE_EDITOR` para automatizar.
2. **`activities/02-rebase-onto-wrong-base/`** — **independent**: mueve una rama de 3 commits de una base equivocada (`release/1.0`) a `main` sin perder commits ni duplicar.

Entregable adicional sugerido: en un repo propio, abre dos PRs sobre la misma feature. Uno con `git merge`, otro con `git rebase`. Compara `git log --graph --oneline --all` de los dos resultados y escribe en 3 párrafos qué estrategia prefieres y por qué.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Explica en 2-3 frases **por qué `rebase` reescribe hashes** aunque el contenido (tree) de los commits no cambie.

**P2.** Dibuja (ASCII) el DAG antes y después de ejecutar `git rebase main` sobre esta situación:
```
      A---B---C   feature
     /
D---E---F---G    main
```

**P3.** Diferencia **en una frase cada una**:
- `squash` vs `fixup` en `rebase -i`.
- `rebase` vs `cherry-pick`.
- `--force` vs `--force-with-lease`.
- `merge --no-ff` vs `rebase` + fast-forward merge.

**P4.** Tu rama `feature/foo` fue creada desde `release/1.2` por error. Debería estar basada en `main`. Tiene 4 commits propios. ¿Qué comando ejecutas (uno solo) para moverla a `main` sin perder commits? Escríbelo exacto.

**P5.** Tienes 7 commits en una rama local:
```
abc001 feat: endpoint X
def002 wip
ghi003 fix typo
jkl004 wip again
mno005 fix tests
pqr006 cleanup
stu007 feat: endpoint Y
```
Quieres entregar al PR **2 commits**: uno con todo lo de endpoint X y sus fixes; otro con endpoint Y. Escribe el todo file resultante tras `git rebase -i HEAD~7` listo para guardar.

**P6.** Tu colega te pide que rebases `main` para "limpiarla". Da **tres razones concretas** por las que te niegas (o aceptas) y qué alternativa propones.

**P7.** Diseña una **política de merge** para un equipo de 20 devs trabajando en un SaaS en producción con releases semanales. Especifica:
- Qué botón de GitHub usan para los PRs.
- Qué pueden rebasar y qué no.
- Cómo manejan hotfixes.
Justifica cada decisión en una frase.

**P8.** Verdadero/falso:
- [ ] `git rebase --abort` sirve en cualquier momento tras `git rebase --continue`.
- [ ] `--autosquash` requiere que los commits "fixup" se hayan creado con `--fixup=<hash>`.
- [ ] `cherry-pick` crea un commit con el mismo hash que el original.
- [ ] `rebase --update-refs` mueve ramas intermedias dentro del rango rebasado.
- [ ] Un merge commit siempre tiene exactamente dos padres.
- [ ] `GIT_SEQUENCE_EDITOR` solo se usa en `rebase -i`, no en commits normales.

---

## Referencias

- *Pro Git* cap. 3.6 ("Rebasing") y cap. 7.6 ("Rewriting history"). <https://git-scm.com/book/en/v2>
- `git-rebase(1)`. <https://git-scm.com/docs/git-rebase>
- `git-cherry-pick(1)`. <https://git-scm.com/docs/git-cherry-pick>
- `git-rerere(1)`. <https://git-scm.com/docs/git-rerere>
- Git 2.38 release notes (`--update-refs`). <https://github.com/git/git/blob/master/Documentation/RelNotes/2.38.0.txt>
- Linus Torvalds — "On rebase and merge" (post histórico en lista del kernel). <https://lkml.org/lkml/2009/3/27/383>
- Atlassian — *Merging vs Rebasing*. <https://www.atlassian.com/git/tutorials/merging-vs-rebasing>
- GitHub Docs — *About merge methods on GitHub*. <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-merge-methods-on-github>
