# Ejemplo 01 — `fetch` vs `pull`: por qué uno es seguro y el otro puede sorprender

## Concepto que demuestra

Que `git fetch` **nunca** modifica tus ramas locales ni tu working tree; solo actualiza la caché `refs/remotes/<remote>/*`. En cambio `git pull` **sí** cambia tu rama (merge o rebase), y por eso puede meterte un merge commit sin pedir permiso.

## Contexto

El estudiante típico aprende `git pull` el día 1 y lo ejecuta ciegamente cada mañana. Un día su rama diverge del server, `pull` crea un merge commit extraño, y no entiende qué pasó. Esta demo lo reproduce controladamente.

## Objetivo

- Ver con tus ojos que `fetch` deja `main` intacta y `origin/main` adelantada.
- Reproducir el escenario donde `pull` default inyecta un merge commit.
- Confirmar que `pull --ff-only` protege contra esa sorpresa.

## Prerrequisitos

- Git ≥ 2.30.
- Haber leído la lección hasta §5.

## Ejecución

Puedes ejecutar `files/run-example.sh` (automatizado) o seguir manualmente:

```bash
rm -rf /tmp/fetch-vs-pull && mkdir /tmp/fetch-vs-pull && cd /tmp/fetch-vs-pull

# "Server" bare
git init --bare origin.git

# "Alice" clona y mete el commit inicial
git clone -q ./origin.git alice
cd alice
git config user.name  "Alice" && git config user.email "alice@example.com"
echo "line 1" > notes.txt && git add notes.txt
git commit -q -m "init: first line"
git push -qu origin main
cd ..

# "Bob" clona
git clone -q ./origin.git bob
cd bob
git config user.name  "Bob" && git config user.email "bob@example.com"
cd ..

# Alice añade un commit y pushea
cd alice
echo "line 2 (alice)" >> notes.txt && git add notes.txt
git commit -q -m "feat: alice line 2"
git push -q
cd ..
```

### Parte A — `fetch` no toca tu rama

```bash
cd bob

# Antes de fetch
echo "== Antes de fetch =="
git log --oneline
# Un solo commit: 'init: first line'
echo "origin/main (local cache):"
git rev-parse origin/main
echo "main (local branch):"
git rev-parse main
# Ambos apuntan al mismo hash

# Fetch
git fetch origin
echo "== Después de fetch =="
git log --oneline
# SIGUE habiendo un solo commit; main NO se movió
git log --oneline origin/main
# AHORA origin/main tiene 2 commits
git status
# "Your branch is behind 'origin/main' by 1 commit"
```

**Observación**: `fetch` trajo el commit a `.git/objects/` y movió `origin/main`, pero `main` **no se movió**. Decidir qué hacer sigue siendo tuyo.

### Parte B — `pull` default puede meter un merge commit

Vamos a provocarlo. Hacemos que Bob también haga un commit local **antes** de pullear:

```bash
# Bob crea un commit local divergente
echo "line 2 (bob)" >> notes.txt
git add notes.txt
git commit -q -m "feat: bob line 2"

echo "== Antes de pull =="
git log --oneline --all --graph
# * <bob>    (HEAD -> main)   feat: bob line 2
# | * <alice> (origin/main)   feat: alice line 2
# |/
# * <init>                     init: first line
```

Las ramas divergieron. Ahora el pull default (merge):

```bash
git pull --no-rebase --no-ff
# Mergea origin/main dentro de main. Si hay conflicto en notes.txt, lo verás.
# En este caso ambas añadieron la línea 2 → conflicto.
```

Si hay conflicto (muy probable), resuélvelo:

```bash
# Edita notes.txt a mano, luego:
git add notes.txt
git commit --no-edit
```

Resultado:

```bash
git log --oneline --graph
# *   <merge>  Merge branch 'main' of ./../origin
# |\
# | * <alice>  feat: alice line 2
# * | <bob>    feat: bob line 2
# |/
# * <init>     init: first line
```

**Un merge commit apareció sin que lo pidieras explícitamente**. Si tu política de rama es "historia lineal", acabas de ensuciar la historia.

### Parte C — `pull --ff-only` protege

Resetea bob a antes del merge y repite con `--ff-only`:

```bash
git reset --hard HEAD~1    # deshacer el merge commit (vuelve al commit de bob)
git pull --ff-only
# fatal: Not possible to fast-forward, aborting.
```

**Perfecto**: Git **se niega** a mergear o rebasar automáticamente. Tú decides:

```bash
# Opción 1: rebasar los commits locales sobre lo nuevo del server
git pull --rebase
# (vas a tener que resolver el conflicto de notes.txt otra vez;
#  esta vez sin merge commit)

# Opción 2: hacer el merge intencionalmente
git merge origin/main
```

Elección consciente, no accidental.

## Resultado esperado

- Confirmas que **fetch no muta ramas locales**.
- Confirmas que **pull sin flags puede mergear por su cuenta**.
- Confirmas que **`pull --ff-only` falla antes de sorprenderte**.

## Interpretación

- `origin/main` es, siempre, **la posición del server tal como la viste en el último fetch**. No es "live".
- `fetch` → "actualiza información".
- `pull` → "actualiza información **y toma una decisión por mí**".
- `pull --ff-only` → "actualiza información, y si la decisión no es trivial, para y pregúntame".

## Configuración recomendada después de esta demo

```bash
git config --global pull.rebase true
git config --global pull.ff only
git config --global fetch.prune true
```

## Errores frecuentes

- **"`git pull` nunca me ha fallado"** — porque siempre has sido afortunado con repos sin divergencia. Un día tocará.
- **Confundir "origin/main" con "la rama remota"** — es una **caché**, no un cable abierto al server.
- **Reset `--hard` tras un pull inesperado** sin saber el commit anterior — usa `ORIG_HEAD`, que Git deja apuntando al estado previo a merges/rebases.

## Limpieza

```bash
rm -rf /tmp/fetch-vs-pull
```
