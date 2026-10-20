# Ejemplo 02 — Anatomía de un conflicto

## Concepto que demuestra

Qué hace Git exactamente cuando dos ramas tocan **la misma línea** del mismo archivo, cómo lee uno los marcadores, y qué pasos resuelven el conflicto correctamente.

## Contexto

Un conflicto no es un error: es una **pregunta** que Git te hace porque no puede decidir solo. Esta demo construye un conflicto mínimo pero realista (dos valores distintos para la misma clave de config) y te muestra:

- El output de `git merge` cuando falla el auto-merge.
- El contenido del archivo con los marcadores (`<<<<<<<`, `=======`, `>>>>>>>`) **y con la base común** si activas `merge.conflictStyle = diff3`.
- El output de `git status` durante el merge pendiente.
- Cómo abortar (`git merge --abort`) y cómo continuar (`git add` + `git commit`).

## Objetivo

Al terminar:
- Sabes leer los **tres bloques** de un conflicto en modo `diff3` (ours, base, theirs).
- Puedes decidir conscientemente qué resolver y por qué.
- Diferencias "resolver" (editar + `git add` + `git commit`) de "abortar" (`git merge --abort`).

## Prerrequisitos

- Git ≥ 2.30.
- `merge.conflictStyle = diff3` recomendado (el script lo activa).

## Ejecución

Ejecuta `bash files/run-example.sh`. Deja el repo en estado de conflicto activo para que lo explores a mano.

### Lectura del output

Tras el script verás algo similar a:

```
$ git merge feature/greeting
Auto-merging config.txt
CONFLICT (content): Merge conflict in config.txt
Automatic merge failed; fix conflicts and then commit the result.
```

Y `config.txt` con:

```
<<<<<<< HEAD
greeting = hola
||||||| merged common ancestors
greeting = hello
=======
greeting = hi
>>>>>>> feature/greeting
```

Interpretación línea por línea:

- Entre `<<<<<<< HEAD` y `|||||||` → **ours** (lo que tienes en la rama actual).
- Entre `|||||||` y `=======` → **base** (el ancestro común, antes de que divergieran).
- Entre `=======` y `>>>>>>>` → **theirs** (lo que trae la rama que estás mergeando).

**El valor diagnóstico** de la base es enorme: con solo ver `ours` y `theirs` no sabes *de qué cambió cada quién*. Con la base ves que *ambos* cambiaron el mismo valor en direcciones distintas (no es que uno "no haya hecho nada").

### Explorar en vivo

```bash
cd /tmp/conflict-demo
git status                  # mapa de lo que falta por resolver
cat config.txt              # ver los marcadores
git diff                    # vista unificada
git ls-files -u             # las 3 versiones del archivo en el index (stages 1,2,3)
git show :1:config.txt      # base
git show :2:config.txt      # ours
git show :3:config.txt      # theirs
```

### Opción A — resolver

```bash
# Decide la combinación. Por ejemplo: "hola, hi"
printf 'greeting = hola, hi\n' > config.txt
git add config.txt
git status                  # ya no hay unmerged paths; "All conflicts fixed"
git commit                  # editor abre con "Merge branch 'feature/greeting'" prellenado
```

### Opción B — abortar

```bash
git merge --abort
git status                  # vuelve al estado exacto antes del merge
```

## Interpretación

- Git usa **tres snapshots** para resolver: la **merge base** (ancestro común), **ours** (HEAD) y **theirs** (la rama que trae el merge). Esta es la razón por la que se llama **3-way merge**.
- Cuando los tres difieren en las **mismas líneas**, Git no inventa: pone los marcadores y espera.
- Los stages 1, 2, 3 del index (visibles con `git ls-files -u`) **persisten** mientras el merge esté pendiente. Son la forma formal de ver "base/ours/theirs" sin tener que leer el archivo con marcadores.
- Al hacer `git add <archivo>` tras editarlo, los stages 1/2/3 colapsan al stage 0 (normal). Al estar todos en stage 0, `git status` dice "All conflicts fixed".

## Errores frecuentes

- **Resolver sin leer la base**: aceptas una de las dos versiones sin saber si la otra persona *añadió* o *cambió* algo. Con `diff3` lo ves de un vistazo.
- **Committear con marcadores adentro**: pre-commit hook `grep -R '<<<<<<<' .` lo detecta antes de que entre al repo.
- **Hacer `git reset --hard` para "salir" del merge**: funciona pero es violento. `git merge --abort` es la primitiva correcta y preserva cambios locales no relacionados.
- **Olvidar `git add` tras editar**: Git sigue viendo el archivo como "unmerged" hasta que lo stagear.

## Relación con escenarios reales

- Dos devs cambian el mismo valor en `config.yaml` en features paralelos → conflicto esperable.
- Formatters automáticos (prettier, black, gofmt) reformatean archivos enteros → conflictos masivos por cambios de whitespace. Mitigación: `git merge -X ignore-all-space` o `.gitattributes merge=union` para archivos específicos (ambos casos avanzados — se cubren en `gh-11`).
- Renames en una rama + edits en la otra → Git **detecta el rename** automáticamente (`-M` por default); los conflictos aparecen sobre el archivo renombrado.

## Limpieza

```bash
rm -rf /tmp/conflict-demo
```
