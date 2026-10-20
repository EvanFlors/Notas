# Ejemplo 02 — `git rebase --onto`: mover una rama de base equivocada

## Concepto que demuestra

Cómo usar `git rebase --onto <newbase> <upstream> [<branch>]` para **mover un conjunto de commits** de una base a otra. Es la operación quirúrgica cuando creaste una rama desde el commit equivocado.

## Contexto

Caso real: tu equipo tiene `main` y `release/1.0`. Un dev abre `feature/dashboard` **por accidente** desde `release/1.0` (en lugar de `main`). Hace 3 commits. Al abrir el PR a `main` descubre que incluye commits de `release/1.0` que no deberían ir.

El fix: `git rebase --onto main release/1.0 feature/dashboard`.

## Objetivo

Al terminar:
- Entiendes la **tripleta** `(newbase, upstream, branch)`.
- Puedes dibujar el DAG antes/después mentalmente.
- Sabes recuperarte si pones mal los argumentos.

## Prerrequisitos

- Git ≥ 2.30.
- Haber completado `gh-03`.

## Ejecución

Reproduce manualmente o con `files/run-demo.sh`.

### Setup

```bash
rm -rf /tmp/onto-demo && mkdir -p /tmp/onto-demo && cd /tmp/onto-demo
git init -q -b main
git config user.name  "Demo"
git config user.email "demo@example.com"

# Commit base compartido
echo "v0.1" > VERSION
git add VERSION && git commit -q -m "chore: initial"

# release/1.0 avanza con cosas propias de la release
git switch -c release/1.0
echo "release notes 1.0" > RELEASE_NOTES.md
git add RELEASE_NOTES.md && git commit -q -m "docs: release notes 1.0"
echo "v1.0" > VERSION
git commit -q -am "chore: bump to 1.0"

# el dev crea feature/dashboard por error DESDE release/1.0
git switch -c feature/dashboard
mkdir -p dashboard
cat > dashboard/index.html <<'EOF'
<h1>Dashboard</h1>
EOF
git add dashboard/index.html && git commit -q -m "feat(dashboard): scaffold"

cat > dashboard/app.js <<'EOF'
console.log("dashboard");
EOF
git add dashboard/app.js && git commit -q -m "feat(dashboard): add app.js"

cat > dashboard/styles.css <<'EOF'
body { font: sans-serif; }
EOF
git add dashboard/styles.css && git commit -q -m "feat(dashboard): add styles"

# Mientras tanto main avanza independiente
git switch main
echo "v0.2" > VERSION
git commit -q -am "chore: bump to 0.2 (unreleased)"

git log --all --graph --oneline --decorate
```

Verás algo así:

```
* a5b (main) chore: bump to 0.2 (unreleased)
| * d9e (feature/dashboard) feat(dashboard): add styles
| * c7d feat(dashboard): add app.js
| * b1a feat(dashboard): scaffold
| * f3c (release/1.0) chore: bump to 1.0
| * e2b docs: release notes 1.0
|/
* 456 (HEAD) chore: initial
```

Observa que **feature/dashboard** cuelga de **release/1.0**, no de main.

### El rebase

```bash
git switch feature/dashboard
git rebase --onto main release/1.0
```

Significa literalmente:
> "Toma los commits de la rama actual (`feature/dashboard`) que **no** están en `release/1.0`, y aplícalos sobre `main`".

Es decir: cherry-pick de `(release/1.0..feature/dashboard]` sobre `main`.

Resultado:

```
* d9e' (feature/dashboard) feat(dashboard): add styles
* c7d' feat(dashboard): add app.js
* b1a' feat(dashboard): scaffold
* a5b (main) chore: bump to 0.2 (unreleased)
| * f3c (release/1.0) chore: bump to 1.0
| * e2b docs: release notes 1.0
|/
* 456 chore: initial
```

Verifica:
```bash
git log --all --graph --oneline --decorate
```

`feature/dashboard` ahora cuelga de `main` con sus 3 commits propios reaplicados; `release/1.0` sigue intacta.

## Resultado esperado

- `feature/dashboard` tiene exactamente 3 commits sobre `main`.
- Ninguno de esos 3 toca `RELEASE_NOTES.md` ni `VERSION` del lado release.
- `release/1.0` no cambió.
- `main` no cambió.
- Los commits viejos (b1a, c7d, d9e) existen todavía en `.git/objects/` pero no son alcanzables desde ninguna ref.

## Interpretación

Firma general:

```
git rebase --onto <newbase> <upstream> [<branch>]
```

- `<newbase>` — a dónde pegas los commits (nueva base).
- `<upstream>` — qué considerar "ya hecho" (todos los commits en `<upstream>` se excluyen del rango a mover).
- `<branch>` — qué rama reescribir (opcional; si lo omites, usa HEAD).

**Regla mnemotécnica**: "toma lo que **sobra** de `<upstream>` en la rama, y pégalo en `<newbase>`".

### Variantes útiles

**Dropear los últimos N commits de otra rama al pegar:**

```bash
# feature/x = main + 5 commits, pero los últimos 2 son WIP que no quieres
git rebase --onto main feature/x~2 feature/x
# equivalente a "rebasa los 2 ultimos commits a nada" => se dropean
# en realidad: toma lo que no esta en feature/x~2, es decir, los ultimos 2,
# y los pega en main. Para DROPEAR los ultimos 2 haces:
git rebase --onto feature/x~2 feature/x~0 feature/x
# o mas simple: git reset --hard feature/x~2 (si no te importa el reflog)
```

**Partir un PR grande en dos**:

```bash
# feature/big tiene 10 commits. Quieres partirlo en feature/part1 (5) + feature/part2 (otros 5).
git switch -c feature/part1 feature/big~5
# ahora part1 tiene los primeros 5
git switch feature/big
git rebase --onto feature/part1 feature/big~5 feature/big
git branch -m feature/big feature/part2
# feature/part2 tiene los ultimos 5, basada en feature/part1
```

## Errores frecuentes

- **"Pasé mal el `<upstream>`"** → el rebase incluye commits que no querías. Fix: `git rebase --abort`, vuelve a calcular `git merge-base feature/x <base-original>`.
- **"Conflictos durante el rebase"** → normal si `main` y `release/1.0` divergieron. Resuelves, `git add`, `git rebase --continue`.
- **"Rebase onto borró mi rama"** → no, nunca. El reflog tiene el estado anterior: `git reflog && git reset --hard HEAD@{N}`.

## Relación con escenarios reales

- Rama creada desde base equivocada (clásico en equipos grandes).
- Backports: `git rebase --onto release/1.2 main hotfix/foo` para llevar un hotfix de `main` a una rama release.
- Partir PRs demasiado grandes en PRs chicos encadenados (stacking manual).

## Limpieza

```bash
rm -rf /tmp/onto-demo
```
