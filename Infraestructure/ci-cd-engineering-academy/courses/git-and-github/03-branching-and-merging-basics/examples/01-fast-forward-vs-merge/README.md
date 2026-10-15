# Ejemplo 01 — Fast-forward vs 3-way merge vs `--no-ff`

## Concepto que demuestra

Ejecuta **la misma secuencia de commits** en tres repos distintos para ver, con `git log --graph`, cómo cada estrategia de merge produce un DAG radicalmente diferente.

## Contexto

Mergear "funciona" casi siempre. Pero el DAG que resulta depende del **estado relativo** de las dos ramas y del flag que uses:

| Caso | Estado | Flag | Resultado |
|------|--------|------|-----------|
| A | `main` no ha avanzado desde el branch-off | sin flag | **fast-forward** (ref avanza, cero commits nuevos) |
| B | `main` no ha avanzado desde el branch-off | `--no-ff` | **merge commit** con dos padres (forzado) |
| C | `main` avanzó también desde el branch-off | sin flag | **3-way merge** (merge commit real) |

Este ejemplo construye los 3 escenarios y los compara.

## Objetivo

Al terminar:
- Reconoces visualmente un FF vs un merge commit en `git log --graph`.
- Entiendes por qué `--no-ff` existe y cuándo tiene sentido.
- Sabes qué hashes se crean en cada caso (y qué hashes **no**).

## Prerrequisitos

- Git ≥ 2.30.

## Ejecución

Ejecuta `bash files/run-example.sh`. Produce tres repos bajo `/tmp/ff-vs-merge/` (`case-a`, `case-b`, `case-c`) e imprime el `--graph` de cada uno.

### Lectura rápida de los grafos

**Caso A — fast-forward**:

```
* f1c2a3b (HEAD -> main, feature/x) feat: F1
* 7a8b9c0 init: README
```

Observa: `main` y `feature/x` apuntan **al mismo commit**. No hubo merge commit.

**Caso B — `--no-ff` forzando merge commit**:

```
*   d4e5f67 (HEAD -> main) Merge branch 'feature/x'
|\
| * f1c2a3b (feature/x) feat: F1
|/
* 7a8b9c0 init: README
```

Aunque FF era posible, hay un commit M con dos padres: uno es el commit base, otro es `feature/x`. Esto preserva visualmente "entró la feature X".

**Caso C — 3-way merge real**:

```
*   9b8c7d6 (HEAD -> main) Merge branch 'feature/x'
|\
| * f1c2a3b (feature/x) feat: F1
* | 2d3e4f5 docs: C1 in main
|/
* 7a8b9c0 init: README
```

Aquí el merge era **obligatorio** (3-way) porque `main` también avanzó.

## Interpretación

- En A, mergear es gratis: solo se mueve una ref. **Cero commits nuevos**. El hash de la rama destino no existía antes del merge solo porque "pertenecía a la otra rama"; ahora pertenece a ambas.
- En B, el commit nuevo es puro **metadata estructural**: no cambia nada del tree (el tree es el mismo que `feature/x`), pero tiene dos padres. Útil para contar "¿cuántas features entraron a `main`?" como `git log --merges`.
- En C, el commit nuevo tiene un **tree combinado** real (merge-base + ours + theirs resuelto automáticamente porque no hubo conflicto en este ejemplo).

Verifica tú mismo:

```bash
cd /tmp/ff-vs-merge/case-b
git log --oneline --merges     # 1 merge commit
git cat-file -p HEAD           # verás parent dos veces
git diff HEAD^ HEAD            # ¡vacío! El tree es idéntico al parent de la feature
```

## Errores frecuentes

- **"No veo diferencia entre case-a y case-b hasta que miro `--graph`"**: correcto. En `--oneline` plano, `case-b` muestra 1 commit más, pero sin ver el grafo no sabes que es un merge estructural.
- **Esperar un conflicto cuando no toca el mismo archivo**: 3-way merge sin conflicto es lo normal. Los conflictos aparecen cuando las dos ramas tocan **las mismas líneas**. Lo verás en el ejemplo 02.
- **Usar `--squash` por accidente**: `git merge --squash` produce un commit "aplanado" sin registrar el merge en el DAG — es una operación distinta y la cubrimos en `gh-07`.

## Relación con escenarios reales

- Equipos que mergean PRs grandes y quieren saber *cuándo* entró cada feature: política `--no-ff`.
- Equipos trunk-based con commits chicos y `git bisect` nocturno: política `--ff` (default) o rebase previo.
- La configuración `git config --global merge.ff only` fuerza FF siempre (y falla si no se puede, obligando a rebase manual).

## Limpieza

```bash
rm -rf /tmp/ff-vs-merge
```
