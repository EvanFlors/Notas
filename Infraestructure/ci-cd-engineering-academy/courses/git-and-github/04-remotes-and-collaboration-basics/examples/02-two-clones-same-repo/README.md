# Ejemplo 02 — Dos clones contra el mismo bare remote

## Concepto que demuestra

Cómo **dos usuarios distintos** (Alice y Bob, simulados) colaboran mediante un **único bare repo** como punto de encuentro. Verás:

- Un push de Alice que Bob no ve hasta fetchear.
- Un push rechazado (`non-fast-forward`) cuando Bob intenta pushear sin haberse puesto al día.
- La ruta correcta de recuperación: `fetch` → `rebase` → `push`.

## Contexto

Esto es, en esencia, el modelo de un equipo en GitHub pero sin GitHub. Entender la mecánica con un bare local hace que, cuando llegues a `gh-05`, GitHub sea solo "el mismo bare pero bonito y con auth".

## Objetivo

- Operar dos clones del mismo repo en paralelo.
- Reproducir y leer el error `(non-fast-forward)`.
- Recuperarse de él de la forma correcta (sin `--force`).
- Observar las posiciones de `main` y `origin/main` en cada clon tras cada paso.

## Prerrequisitos

- Git ≥ 2.30.
- Haber reproducido `examples/01-fetch-vs-pull/`.

## Ejecución

```bash
rm -rf /tmp/two-clones && mkdir /tmp/two-clones && cd /tmp/two-clones

# Server
git init --bare -q origin.git

# Alice
git clone -q ./origin.git alice
(
  cd alice
  git config user.name  "Alice"; git config user.email "alice@example.com"
  echo "# Project" > README.md
  git add README.md && git commit -q -m "init: readme"
  git push -qu origin main
)

# Bob clona DESPUÉS del commit inicial
git clone -q ./origin.git bob
(
  cd bob
  git config user.name  "Bob"; git config user.email "bob@example.com"
)
```

### Round 1 — Alice pushea, Bob se entera

```bash
# Alice añade un commit
cd /tmp/two-clones/alice
echo "First feature." >> README.md
git commit -am "feat: first feature"
git push

# Bob todavía no sabe
cd /tmp/two-clones/bob
git log --oneline               # solo tiene el init
git ls-remote origin main       # consulta el server sin fetchear: muestra el nuevo hash
git fetch origin
git log --oneline origin/main   # ya ve el commit de alice
git merge --ff-only origin/main # su main avanza, sin merge commit
```

### Round 2 — Ambos trabajan a la vez; Bob se topa con `non-fast-forward`

```bash
# Alice añade otro commit
cd /tmp/two-clones/alice
echo "Second feature." >> README.md
git commit -am "feat: second feature"
git push

# Mientras tanto, Bob también trabaja (sin fetchear)
cd /tmp/two-clones/bob
echo "Bob's note." >> notes.md
git add notes.md
git commit -q -m "docs: bob's note"
git push
# ! [rejected]        main -> main (fetch first)
# error: failed to push some refs to '.../origin.git'
# hint: Updates were rejected because the remote contains work that you do
# hint: not have locally. ... You may want to first integrate the remote changes
# hint: (e.g., 'git pull ...') before pushing again.
```

**Esto es lo que vas a ver en producción todo el tiempo.** Fix correcto:

```bash
git fetch origin
git log --oneline --all --graph
# * <alice-2>  (origin/main)  feat: second feature
# | * <bob>    (HEAD -> main) docs: bob's note
# |/
# * <alice-1>                 feat: first feature
# * <init>                    init: readme

git rebase origin/main
# Reaplica docs:bob's note sobre feat:second feature

git log --oneline
# * <bob'>    (HEAD -> main) docs: bob's note
# * <alice-2> (origin/main)  feat: second feature
# * <alice-1>                feat: first feature
# * <init>                   init: readme

git push
# OK, fast-forward
```

Fíjate que **el hash de bob cambió** (`<bob>` → `<bob'>`): rebase reescribe.

### Round 3 — Alice se pone al día

```bash
cd /tmp/two-clones/alice
git fetch origin
git status
# "Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded."
git merge --ff-only origin/main
git log --oneline
# * <bob'>    feat: docs: bob's note
# * <alice-2> feat: second feature
# * <alice-1> feat: first feature
# * <init>    init: readme
```

Historia lineal. Nadie forzó nada. Nadie perdió trabajo.

## Resultado esperado

Cuando termines:
- Tres commits "lineales" después del `init`: dos de Alice, uno de Bob, en orden `alice-1 → alice-2 → bob`.
- Ambos clones y el bare apuntan al **mismo hash** en `main`.
- Entiendes **por qué** se rechazó el primer push de Bob y cómo se arregló sin force.

## Interpretación

- El server no "sabe" quién está pusheando — solo verifica fast-forward.
- Rebase sobre `origin/main` **antes** de pushear es la forma más común de evitar rechazos.
- Si Bob y Alice hubieran editado la misma línea, Bob habría tenido conflicto durante el rebase. Eso es colaboración real.

## Errores frecuentes

- **Pushear sin fetchear antes** cuando ya pasó rato → rechazo garantizado. Hábito: `fetch` antes de `push` en una rama compartida.
- **Usar `git push --force` ante el primer rechazo** → machacas el commit de Alice y lo pierdes para siempre si no está en otro clon. **No lo hagas.**
- **Olvidar que rebase cambia hashes**: si tu commit ya estaba en otro lugar (otra rama tuya), ten en cuenta que el nuevo hash es *otro commit*.

## Variación opcional

Simula el `--force-with-lease` útil: Bob trabaja en una rama `feature/x`, no en `main`:

```bash
cd /tmp/two-clones/bob
git switch -c feature/x
# ... commits ...
git push -u origin feature/x
# rebase su rama tras cambios en main:
git fetch origin
git rebase origin/main
git push --force-with-lease     # OK: solo Bob usa feature/x
```

## Limpieza

```bash
rm -rf /tmp/two-clones
```
