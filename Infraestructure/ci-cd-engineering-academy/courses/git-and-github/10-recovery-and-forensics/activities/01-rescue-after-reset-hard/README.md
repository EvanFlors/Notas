# Actividad 01 — Rescue after reset --hard (and worse)

## 1. Identificación

- **ID:** `gh-10-01-rescue-after-reset-hard`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-10-recovery-and-forensics`
- **Dificultad:** advanced
- **Duración estimada:** 60–75 min
- **Tipo:** independent

## 2. Contexto

En `gh-02` ya recuperaste un commit tras `reset --hard` usando `reflog`. Esta actividad va **más lejos**: tres escenarios encadenados de dificultad creciente, cada uno con un vector distinto de pérdida y una técnica distinta de rescate.

**No consultes `solution/` hasta terminar.**

## 3. Objetivos

Al terminar deberías poder:

- Recuperar un commit tras `reset --hard` sin ayudas visuales (`reflog` seco).
- Recuperar una rama **borrada** cuyo tip solo vive en el reflog de HEAD.
- Recuperar un `stash` cuya entrada fue descartada *y* cuyo reflog fue purgado, usando `fsck --lost-found`.
- Distinguir qué queda recuperable y qué no, según el estado del `.git/`.

## 4. Prerrequisitos

- `gh-09-git-internals` completado.
- Lectura de `theory/lesson.md`.
- Git ≥ 2.30, `bash`, `grep`, `awk`.

**Costos**: ninguno. Todo en `/tmp/recover-adv`.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-broken-repos.sh /tmp/recover-adv
```

Esto crea **3 escenarios** en `/tmp/recover-adv/scenario-{1,2,3}/`. Cada repo tiene un `README.md` interno con el síntoma.

### 5.2 Los 3 escenarios

Resuélvelos en orden. Cuando creas haber terminado, corre:

```bash
bash tests/validate.sh /tmp/recover-adv
```

#### Escenario 1 — "Reset --hard + checkout en otra rama"

- **Repo:** `/tmp/recover-adv/scenario-1`
- **Síntoma:** Hiciste tres commits sobre `main` (`feat: step 1`, `feat: step 2`, `feat: step 3`). Luego, "para limpiar", ejecutaste `git reset --hard HEAD~3`. Después hiciste `git checkout -b other` y commiteaste algo distinto. En `git log main` ya no están los tres commits.
- **Objetivo:** Restaurar `main` para que su HEAD apunte al commit `feat: step 3` (y por lo tanto incluya step 1 y step 2 como padres).
- **Criterio de éxito:**
  - `git log main --format=%s` incluye `feat: step 3`, `feat: step 2`, `feat: step 1`.
  - El HEAD actual es `main` (no estás en detached HEAD ni en `other`).

#### Escenario 2 — "Borré la rama en la que trabajaba"

- **Repo:** `/tmp/recover-adv/scenario-2`
- **Síntoma:** Tenías una rama `feature/payments` con tres commits (`feat: add payments module`, `test: payments happy path`, `fix: payments edge case`). Hiciste `git switch main` y luego `git branch -D feature/payments` por error. La rama ya no existe. `git log main` solo tiene commits anteriores. **Pero** no borraste nada en `.git/objects/` y el reflog de HEAD sigue intacto.
- **Objetivo:** Recrear la rama `feature/payments` apuntando al tip original (el commit `fix: payments edge case`).
- **Criterio de éxito:**
  - Existe `refs/heads/feature/payments`.
  - Su tip tiene subject `fix: payments edge case`.
  - Alcanzando desde su tip aparecen también `test: payments happy path` y `feat: add payments module`.

**Pista inicial**: `git reflog` muestra solo movimientos de HEAD, pero cuando *estuviste* en esa rama HEAD apuntó a sus commits — están ahí.

#### Escenario 3 — "Perdí un stash y el reflog está vacío"

- **Repo:** `/tmp/recover-adv/scenario-3`
- **Síntoma:** Guardaste trabajo con `git stash push -m "wip: critical fix"`. Luego hiciste `git stash drop` sin querer. Luego, para "limpiar" el repo, ejecutaste `git reflog expire --expire=now --all` (purga de reflogs). **Pero** no corriste `git gc --prune=now`: los objetos siguen en `.git/objects/`.

  El stash contenía un cambio en `app.py` que añade una línea con la cadena `CRITICAL_FIX_MARKER`.
- **Objetivo:** Encontrar el commit *dangling* del stash y recuperar el archivo con el cambio en el working tree de `main`. Finalmente, haz un commit en `main` con subject exactamente `rescue: apply recovered CRITICAL_FIX_MARKER` que aplique ese cambio.
- **Criterio de éxito:**
  - En `main` existe un commit con subject `rescue: apply recovered CRITICAL_FIX_MARKER`.
  - El archivo `app.py` en HEAD de `main` contiene la cadena `CRITICAL_FIX_MARKER`.
  - Working tree limpio.

**Pistas en orden** (si te atascas):
- *P1*: ¿Qué comando lista objetos sin referencias en `.git/objects/`?
- *P2*: `git fsck --lost-found` imprime `dangling commit <sha>` y `dangling blob <sha>`. Un stash es un *commit* (con padres: el commit base y el estado del index).
- *P3*: Puedes inspeccionar un commit dangling con `git show <sha>` o `git stash apply <sha>` (sí, `stash apply` acepta un sha de commit arbitrario con forma de stash).

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/recover-adv
```

Un report por escenario con `OK`/`FAIL`.

## 6. Resultado esperado

- Los 3 escenarios resueltos.
- `tests/validate.sh` termina con `RESULT: 3/3 scenarios OK`.

## 7. Criterios de aceptación

- [ ] Escenario 1 OK (reflog + reset/branch).
- [ ] Escenario 2 OK (reflog de HEAD + `git branch <name> <sha>`).
- [ ] Escenario 3 OK (`fsck --lost-found` + `stash apply <sha>` o checkout del blob + commit).

## 8. Validación

```bash
bash tests/validate.sh /tmp/recover-adv
```

Reporte por escenario con detalle de qué falta cuando falla.

## 9. Preguntas de reflexión

1. En Escenario 1, ¿por qué `HEAD@{N}` (sintaxis de reflog) funciona aunque `HEAD~N` (sintaxis de DAG) ya no apunte a los commits perdidos?
2. En Escenario 2, ¿por qué `git branch -D` **sí** borra el reflog de esa rama, y aun así podemos recuperar su tip?
3. En Escenario 3, si además de `reflog expire` hubieras corrido `git gc --prune=now`, ¿qué habrías perdido? ¿Qué comando habría sido tu *última* esperanza (y por qué probablemente no hubiera funcionado)?
4. Diseña una política de `gc.reflogExpire` para un repo personal donde no quieres perder nada por 6 meses. ¿Qué cambia respecto al default?
5. ¿Por qué el stash aparece como *dangling commit* en `fsck` y no como *dangling blob*?

## 10. Extensiones (opcional)

- **E1** — Antes de resolver el Escenario 3, inspecciona `.git/objects/` y cuenta los objetos: cuántos quedan antes y después de `fsck`.
- **E2** — Repite Escenario 3 pero esta vez corriendo también `git gc --prune=now` tras `reflog expire`. Verifica con `fsck` que ya no hay dangling, y documenta por qué el rescate ya no es posible.
- **E3** — Investiga `git maintenance` (Git 2.29+): ¿qué tareas automatiza y cómo afectan tu "red de seguridad"?

## 11. Limpieza

```bash
rm -rf /tmp/recover-adv
```
