# Solution — gh-03-01-branch-and-merge

**No ejecutes esto hasta haber intentado la actividad.** La solución resuelve las 3 tareas usando un flujo canónico:

- Tarea 1: `switch -c feature/typo-fix` → fix → `switch main` → `merge --ff-only`.
- Tarea 2: `switch -c feature/usage` → edit → commit → `switch main` → edit distinto → commit → `merge --no-ff feature/usage`.
- Tarea 3: `switch -c feature/subtitle` → edit título → commit → `switch main` → edit **mismo** título distinto → commit → `merge feature/subtitle` → **conflicto** → editar primera línea a `# Notes — personal project` → `add` + `commit`.

Uso:

```bash
bash starter/build-starter.sh /tmp/branch-merge
bash solution/solve.sh         /tmp/branch-merge
bash tests/validate.sh         /tmp/branch-merge
```

Notas:

- La resolución del conflicto se hace con un pequeño script Python para que sea reproducible y determinista. En vida real editas con tu editor habitual y borras los marcadores a mano.
- La solución usa `--ff-only` en Tarea 1 para enforzar que el entorno realmente permite FF (si no, hay algo mal en el starter).
- La solución fuerza `--no-ff` en Tarea 2 porque el enunciado lo pide; sin `--no-ff` el merge seguiría siendo 3-way (main avanzó), pero el commit tendría el mensaje por default igualmente — el `-m` explícito garantiza el subject exacto que valida el test.
