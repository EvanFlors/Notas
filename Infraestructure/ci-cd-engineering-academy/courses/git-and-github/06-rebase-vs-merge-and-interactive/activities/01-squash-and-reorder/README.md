# Actividad 01 — Squash y reorder con rebase interactivo

## 1. Identificación

- **ID:** `gh-06-01-squash-and-reorder`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-06-rebase-vs-merge-and-interactive`
- **Dificultad:** intermediate
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregan un repo con una rama `feature/payments` que tiene **1 commit base** + **5 commits sucios** encima (`wip`, `typo`, `add tests`, `oops forgot header`, `fix typo again`). Antes del PR debes dejar **exactamente 2 commits** sobre la base:

1. `feat(payments): add refund processor` — todo el código del módulo (scaffold + fixes + header de licencia).
2. `test(payments): cover refund processor` — solo los tests.

## 3. Objetivos

- Usas `git rebase -i` para reordenar, combinar (`fixup`) y renombrar (`reword`).
- Entiendes la diferencia entre `fixup` y `squash`.
- Opcionalmente, automatizas el rebase con `GIT_SEQUENCE_EDITOR` para que sea reproducible.
- Validas con el test automatizado.

## 4. Prerrequisitos

- Git ≥ 2.30 con identidad configurada.
- Haber completado `gh-03`.
- Haber leído `examples/01-interactive-cleanup/`.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-messy-branch.sh /tmp/squash-and-reorder
cd /tmp/squash-and-reorder
git log --oneline
```

Verás 6 commits:
```
e5f fix typo again
d4e oops forgot header
c3d add tests
b2c typo
a1b wip
000 init: payments module scaffold
```

HEAD está en la rama `feature/payments`.

### 5.2 Analizar el objetivo

Quieres acabar con:

```
<new-h2> test(payments): cover refund processor
<new-h1> feat(payments): add refund processor
000      init: payments module scaffold
```

Mapeo de commits sucios → acciones:

| Commit sucio | Acción |
|--------------|--------|
| `wip` | `pick` (base del feat), **reword** después a `feat(payments): add refund processor` |
| `typo` | `fixup` (combina con el `wip` sin aportar mensaje) |
| `oops forgot header` | `fixup` (igual) |
| `fix typo again` | `fixup` (igual) |
| `add tests` | `pick` + `reword` a `test(payments): cover refund processor` |

**Problema de orden**: en el log actual, `add tests` está **en medio** (posición 3). Los dos fixups de scaffolding están **después** (posiciones 4 y 5). Si solo cambias `pick→fixup`, los fixups aplican al commit anterior en el plan (que sería `add tests`) y acabas con el header de licencia dentro del commit de tests. **Mal**.

Solución: **reordenar las líneas** del todo file para que los tres fixups queden **justo debajo del `wip`**:

```
pick a1b wip
fixup b2c typo
fixup d4e oops forgot header
fixup e5f fix typo again
pick c3d add tests
```

Luego aplicas `reword` a los dos `pick` para los mensajes finales (puedes hacerlo todo en un solo `rebase -i` cambiando `pick`→`reword` en vez de `pick`, o en un segundo pase).

### 5.3 Ejecutar el rebase (dos opciones)

**Opción A — manual, con tu editor**:

```bash
git rebase -i HEAD~5
```

En el editor que se abra, deja el contenido así (reordenado + fixups + rewords):

```
reword a1b wip
fixup b2c typo
fixup d4e oops forgot header
fixup e5f fix typo again
reword c3d add tests
```

Guarda y cierra. Git te pedirá dos mensajes:
- Para el primer `reword`: escribe `feat(payments): add refund processor`.
- Para el segundo `reword`: escribe `test(payments): cover refund processor`.

**Opción B — automatizada (reproducible, como la del `solution/`)**:

Mira `solution/solve.sh`. Usa `GIT_SEQUENCE_EDITOR` y `GIT_EDITOR` para no abrir editor interactivo. Útil cuando quieres documentar el rebase, aplicarlo en CI, o repetirlo en demos.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/squash-and-reorder
```

Debe terminar en `OK`.

## 6. Resultado esperado

- Working tree limpio (`git status` → `nothing to commit`).
- En `feature/payments`: exactamente **2 commits** sobre `init: payments module scaffold`.
- Subjects **exactos**:
  - `feat(payments): add refund processor`
  - `test(payments): cover refund processor`
- Contenido final idéntico al que se produce con el solve: `payments.py` con header de licencia + función `refund` correcta, `tests/test_payments.py` con el test en verde.
- El commit `feat(...)` no toca `tests/`; el commit `test(...)` solo toca `tests/`.

## 7. Criterios de aceptación

- [ ] Funcionalidad: 2 commits, mensajes exactos, contenido correcto.
- [ ] Separación: cada commit toca el scope esperado y nada más.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes explicar por qué los `fixup` **tienen que ir inmediatamente debajo** de su `pick` target.

## 8. Validación

```bash
bash tests/validate.sh /tmp/squash-and-reorder
```

Chequea:
- HEAD en `feature/payments`.
- Base `init: payments module scaffold` presente.
- Exactamente 2 commits sobre la base.
- Subjects exactos (`feat(payments): add refund processor`, `test(payments): cover refund processor`).
- El commit `feat(...)` modifica `payments.py` y **no** toca `tests/`.
- El commit `test(...)` crea/modifica `tests/test_payments.py` y **nada** más.
- Contenido final de `payments.py` incluye `# Copyright` en línea 1 y `def refund(` (ya corregido el typo).
- Working tree limpio.

## 9. Preguntas de reflexión

1. ¿Por qué `fixup` elimina el mensaje del commit absorbido y `squash` abre editor? ¿Cuándo elegirías uno u otro?
2. Si durante el rebase hubiera habido un conflicto, ¿qué pasos tomarías? ¿Y para abortar?
3. ¿Por qué el orden de las líneas en el todo file importa tanto? Explica con tus palabras qué pasa si pones `fixup` antes de su `pick` target.
4. ¿Qué pasa si tras completar el rebase haces `git push`? ¿Y si la rama ya estaba pusheada antes?

## 10. Extensiones (opcional)

- **E1** — Repite usando `git commit --fixup=<hash>` desde el inicio (al crear los commits sucios) y luego `git rebase -i --autosquash HEAD~5`. Compara el todo file resultante.
- **E2** — Añade un `exec python3 -m pytest tests/` entre tus commits en el todo file para que el rebase falle si algún commit intermedio rompe los tests (bisect-friendly).
- **E3** — Pushea la rama rebasada a un remoto bare local y practica `git push --force-with-lease`.

## 11. Limpieza

```bash
rm -rf /tmp/squash-and-reorder
```
