# Actividad 01 — Branch, merge, resuelve un conflicto simple

## 1. Identificación

- **ID:** `gh-03-01-branch-and-merge`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-03-branching-and-merging-basics`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a reproducir, en un único repo controlado, los tres sabores de merge que esta lección aborda:

1. **Fast-forward** — `main` no avanzó desde el branch-off.
2. **3-way merge** sin conflicto — ambas ramas avanzaron en archivos/líneas distintas.
3. **3-way merge con conflicto** — ambas ramas tocaron la misma línea.

Al terminar deberías saber predecir qué pasa con `HEAD` tras cada operación, leer el DAG con `--graph`, y resolver un conflicto simple sin pánico.

## 3. Objetivos

- Crear ramas con `git switch -c`.
- Mergear con fast-forward real y entender por qué no se crea commit.
- Mergear 3-way sin conflicto.
- Resolver un conflicto de una línea con los marcadores estándar.
- Dejar el DAG legible y validable automáticamente.

## 4. Prerrequisitos

- `gh-02-02-recover-from-mistakes` completada.
- Haber leído `theory/lesson.md` y reproducido los dos ejemplos del módulo.
- Git ≥ 2.30 con identidad global configurada.

**Costos:** ninguno (local, `/tmp/`).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/branch-merge
cd /tmp/branch-merge
git log --oneline
# init: notes
# docs: add outline
git status
# clean working tree
cat notes.md
```

El repo tiene `notes.md` con una sección de outline. Tienes un typo intencional en la primera línea (`# Nootes` en lugar de `# Notes`) que arreglarás en la tarea 1.

### 5.2 Tarea 1 — Fast-forward merge

Crea una rama `feature/typo-fix` desde `main`, arregla el typo en la **primera línea** de `notes.md` (debe quedar `# Notes`), commitea con mensaje:

```
fix: correct Notes title typo
```

Vuelve a `main` y mergea. Como `main` **no** ha avanzado desde el branch-off, debe ser **fast-forward**.

```bash
# Verifica:
git log --oneline main
# Debes ver "fix: correct Notes title typo" en la punta.
# NO debe aparecer ningún "Merge branch" (es FF, no hay merge commit).
```

### 5.3 Tarea 2 — 3-way merge sin conflicto

Crea una rama `feature/usage` desde el `main` actual. Añade **al final** de `notes.md`:

```
## Usage

Run with `./notes.sh`.
```

Commitea con:

```
docs: add Usage section
```

Vuelve a `main`. **Crea un archivo nuevo** `INSTALL.md` con este contenido:

```
# Install

Clone and run `./setup.sh`.
```

Commitea con:

```
docs: add INSTALL.md
```

> Deliberadamente las dos ramas tocan **archivos distintos** para que el 3-way merge sea limpio (sin conflictos). En la Tarea 3 forzaremos un conflicto real.

Ahora, desde `main`, mergea `feature/usage` **forzando merge commit** con `--no-ff`:

```bash
git merge --no-ff -m "Merge branch 'feature/usage'" feature/usage
```

El `--no-ff` fuerza que se cree un **merge commit** aunque fuera FF. Esto nos deja un DAG rico para la Tarea 3.

Verifica:

```bash
git log --graph --oneline --all --decorate
# Debes ver el merge commit "Merge branch 'feature/usage'" con dos padres.
```

### 5.4 Tarea 3 — 3-way merge con conflicto, resuelve

Crea una rama `feature/subtitle` desde el `main` actual. Cambia la línea `# Notes` a:

```
# Notes — personal
```

Commitea con `docs: subtitle 'personal'`.

Vuelve a `main`. Cambia la **misma línea** `# Notes` a:

```
# Notes — project
```

Commitea con `docs: subtitle 'project'`.

Mergea `feature/subtitle` en `main`:

```bash
git merge feature/subtitle
```

Debe aparecer un **conflicto** en `notes.md`. Resuélvelo dejando la primera línea exactamente así (combinación de los dos subtítulos):

```
# Notes — personal project
```

Elimina **todos** los marcadores (`<<<<<<<`, `=======`, `>>>>>>>`, y la zona de base común si usas `diff3`). Luego:

```bash
git add notes.md
git commit         # el editor abrirá el mensaje "Merge branch 'feature/subtitle'" prellenado
                   # puedes conservarlo o editarlo; el validador no comprueba su contenido
```

### 5.5 Entregable (DAG)

Dibuja o imprime el grafo final:

```bash
git log --graph --oneline --all --decorate
```

Debes ver 3+ ramas (`main`, `feature/usage`, `feature/subtitle`; `feature/typo-fix` puede o no seguir existiendo, da igual), dos merge commits, y la fast-forward incorporada linealmente antes del primer merge.

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/branch-merge
```

## 6. Resultado esperado

- `main` incluye todos los cambios: typo arreglado, sección `## Usage` en `notes.md`, archivo `INSTALL.md`, subtítulo `# Notes — personal project`.
- Working tree limpio.
- En `main` existe al menos **1 merge commit** (dos padres).
- No hay marcadores de conflicto en ningún archivo.
- Las ramas `feature/usage` y `feature/subtitle` siguen existiendo.

## 7. Criterios de aceptación

- [ ] Tarea 1 (FF) completada: título correcto en `notes.md`, commit `fix: correct Notes title typo` reachable desde `main`.
- [ ] Tarea 2 (3-way sin conflicto) completada: merge commit con mensaje `Merge branch 'feature/usage'` reachable desde `main`.
- [ ] Tarea 3 (3-way con conflicto) completada: primera línea de `notes.md` es `# Notes — personal project`, sin marcadores.
- [ ] `git status` → clean.
- [ ] Ramas `feature/usage` y `feature/subtitle` existen.

## 8. Validación

```bash
bash tests/validate.sh /tmp/branch-merge
```

Un report por criterio. Si falla, dice exactamente qué falta.

## 9. Preguntas de reflexión

1. En la Tarea 1 **no** se creó un commit nuevo al mergear. ¿Qué cambió entonces en `.git/`? ¿Qué comando lo demuestra?
2. En la Tarea 2 forzamos `--no-ff`. Si no hubiéramos forzado, ¿habría sido FF o 3-way? Responde mirando el estado de `main` relativo al branch-off.
3. En la Tarea 3, con `diff3` activo, ¿qué contenía la zona `||||||| merged common ancestors`? ¿Por qué esa información es útil para resolver el conflicto bien?
4. Si en lugar de resolver hubieras hecho `git merge --abort`, ¿qué habrías obtenido? ¿Y si hubieras hecho `git reset --hard HEAD`?
5. Dibuja (o imprime y anota) el DAG final e identifica: la merge base de `feature/subtitle` con `main`, los dos padres del merge commit de la Tarea 2, y qué commits son alcanzables desde `feature/usage` pero no desde `main`.

## 10. Extensiones (opcional)

- **E1** — Repite todo el flujo con `merge.conflictStyle = merge` (sin la zona de base) y compara. ¿Cuándo preferirías cada estilo?
- **E2** — Haz una Tarea 4 en la que mergeas `main` **hacia** `feature/subtitle` (en vez de al revés), observa cómo cambia el nombre de la rama en el commit de merge y qué queda como "ours" / "theirs".
- **E3** — Añade un pre-commit hook (archivo `.git/hooks/pre-commit`, ejecutable) que rechace commits con `<<<<<<<` dentro. Pruébalo intentando commitear un archivo con marcadores a propósito.

## 11. Limpieza

```bash
rm -rf /tmp/branch-merge
```
