# Actividad 02 — Recover from mistakes

## 1. Identificación

- **ID:** `gh-02-02-recover-from-mistakes`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-02-recording-changes`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Esta actividad invierte el rol. Se te entregan **cuatro escenarios rotos** reales que ocurren todo el tiempo en el trabajo. Tu tarea es **recuperarte** usando `restore`, `reset`, `revert`, `reflog`, etc. Cada escenario tiene un criterio objetivo de éxito que el validador comprueba.

**No consultes `solution/` hasta terminar.**

## 3. Objetivos

Al terminar deberías poder:

- Elegir entre `restore` / `reset` / `revert` / `reflog` según la situación.
- Rescatar trabajo "perdido" tras un `reset --hard`.
- Desacercar un commit que no debió hacerse, sin reescribir historia compartida.
- Eliminar un secreto accidentalmente committed del último commit (local, no pusheado).
- Separar un commit que mezcló dos intenciones usando `reset --mixed` + re-stage.

## 4. Prerrequisitos

- `gh-02-01-atomic-commits` completada.
- Haber leído la lección completa.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-broken-repos.sh /tmp/recover
```

Esto crea **4 repos** en `/tmp/recover/scenario-{1,2,3,4}/`, cada uno con un README específico del escenario.

### 5.2 Los 4 escenarios

Para cada uno, lee el `README.md` del escenario y resuelve. Cuando creas haber terminado, corre `bash tests/validate.sh /tmp/recover` para verificar los 4.

#### Escenario 1 — "Reset --hard me borró 2 horas de trabajo"

- **Repo:** `/tmp/recover/scenario-1`
- **Síntoma:** Hiciste cambios, los committeaste (commit `WIP: experimentos`), luego ejecutaste `git reset --hard HEAD~1` por error. El commit WIP ya no está en `git log`. Las ediciones del working tree también desaparecieron.
- **Objetivo:** Recuperar el commit WIP y re-aplicarlo en `main`.
- **Criterio de éxito:** El commit cuyo subject es `WIP: experimentos` vuelve a ser alcanzable desde `main` (puede ser `HEAD`, puede estar en el medio).

#### Escenario 2 — "Hice un commit en la rama equivocada"

- **Repo:** `/tmp/recover/scenario-2`
- **Síntoma:** Estabas en `main` y committed `feat: add dark mode` ahí, pero debía ir a una rama `feature/dark-mode` nueva. Nada se ha pusheado.
- **Objetivo:** El commit debe quedar en `feature/dark-mode` (crearla si no existe) y `main` debe volver al estado anterior.
- **Criterio de éxito:**
  - `main` apunta al commit cuyo subject es `init: base` (NO al `feat: add dark mode`).
  - Existe rama `feature/dark-mode` que contiene el commit `feat: add dark mode`.
  - No se perdió ningún archivo.

#### Escenario 3 — "Committed un secreto en el último commit (no pusheado)"

- **Repo:** `/tmp/recover/scenario-3`
- **Síntoma:** El último commit (`feat: add deploy script`) incluye por error un archivo `secrets.env` con lo que parece una API key. Nada se ha pusheado. También debes añadir una regla `.gitignore` para evitar reincidir.
- **Objetivo:** Reemplaza el último commit por una versión **sin** el archivo de secretos, y añade `secrets.env` al `.gitignore`. (En vida real: **rota también la credencial** — aquí no hay nada real que rotar.)
- **Criterio de éxito:**
  - El archivo `secrets.env` **ya no existe** en ningún commit alcanzable desde `main`.
  - `.gitignore` contiene una línea que ignora `secrets.env`.
  - Un commit nuevo (puede llamarse como quieras) reemplaza al anterior; sigue existiendo el commit `feat: add deploy script` o uno equivalente que añade `deploy.sh`.
  - Working tree limpio.

#### Escenario 4 — "Mi último commit mezcló dos intenciones"

- **Repo:** `/tmp/recover/scenario-4`
- **Síntoma:** El último commit (`chore: cleanup`) hizo **dos cosas** a la vez: eliminar un `TODO` en `app.py` **y** actualizar la versión en `VERSION` de `0.1.0` a `0.2.0`. Quieres que sean dos commits distintos. Nada se ha pusheado.
- **Objetivo:** Reemplazar ese único commit por **dos** commits atómicos:
  - Uno `chore: remove done TODO`.
  - Otro `chore: bump version to 0.2.0`.
- **Criterio de éxito:**
  - El commit `chore: cleanup` **ya no está** en el log.
  - Existen (en cualquier orden) los commits `chore: remove done TODO` y `chore: bump version to 0.2.0`, cada uno tocando **solo** `app.py` o **solo** `VERSION`, no ambos.
  - Working tree limpio.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/recover
```

Verifica los 4 escenarios por separado y reporta por nombre.

### 5.4 Pistas (en orden de "escalada")

Si te atascas en algún escenario, lee las pistas una por una, no todas de una vez.

**Escenario 1**:
- Pista 1: ¿Dónde queda registro de los movimientos de HEAD?
- Pista 2: `git reflog`.
- Pista 3: Una vez tienes el hash del commit perdido, `git reset --hard <hash>` o `git cherry-pick <hash>`.

**Escenario 2**:
- Pista 1: Puedes crear una rama en el commit actual *antes* de retroceder main.
- Pista 2: `git branch feature/dark-mode` + `git reset --hard HEAD~1` sobre main.
- Pista 3: Verifica con `git log --oneline --all --graph`.

**Escenario 3**:
- Pista 1: El commit incluye un archivo que no debe estar. ¿Cómo reemplazas el último commit?
- Pista 2: `git reset --soft HEAD~1` deja los cambios en el index; de ahí puedes unstage el secreto, borrarlo, agregar `.gitignore`, y commitear.
- Pista 3: Como alternativa: `git rm --cached secrets.env` + `rm secrets.env` + modificar `.gitignore` + `git commit --amend`.

**Escenario 4**:
- Pista 1: `git reset --mixed HEAD~1` revierte el commit pero deja los cambios en el working tree.
- Pista 2: Ahora `git add <solo-un-archivo>` → commit → `git add <el-otro>` → commit.
- Pista 3: Si prefieres fijar el orden: primero el TODO, luego la versión.

## 6. Resultado esperado

- Los 4 escenarios resueltos.
- `tests/validate.sh` termina con `RESULT: 4/4 scenarios OK`.

## 7. Criterios de aceptación

- [ ] Escenario 1 OK (reflog + reset/cherry-pick).
- [ ] Escenario 2 OK (nueva rama + reset main).
- [ ] Escenario 3 OK (reset --soft o --amend + rm --cached + gitignore).
- [ ] Escenario 4 OK (reset --mixed + staging selectivo + 2 commits).

## 8. Validación

```bash
bash tests/validate.sh /tmp/recover
```

Un report por escenario con `OK`/`FAIL`. Si uno falla, dice qué falta.

## 9. Preguntas de reflexión

1. ¿En qué momento `--hard` fue la operación correcta y en qué momento habría sido catastrófica?
2. En el Escenario 3, ¿por qué `git reset --soft HEAD~1` + unstage + commit es diferente de `git commit --amend` + unstage? ¿Hay alguna diferencia práctica entre ambas vías?
3. Después del Escenario 3, el archivo `secrets.env` **sigue existiendo** en `.git/objects/`. ¿Por qué? ¿Qué consecuencias tiene? ¿Qué harías diferente si ya hubieras pusheado?
4. ¿Por qué `revert` no fue la respuesta correcta en ninguno de estos escenarios? ¿En qué escenario *sí* sería?
5. Diseña una **check-list personal** de 5 cosas a hacer antes de ejecutar `git reset --hard`.

## 10. Extensiones (opcional)

- **E1** — Escenario 5 inventado por ti: simula un bug introducido por un merge y usa `git revert -m 1 <merge-hash>`.
- **E2** — Investiga `git stash` y resuelve un pequeño escenario con él (sin usarlo como "guardo esto para después y nunca vuelvo").
- **E3** — Simula el Escenario 3 **sobre una rama ya pusheada** y describe (sin ejecutar) el proceso de limpieza y comunicación necesario. Vas a ampliarlo en `gh-13`.

## 11. Limpieza

```bash
rm -rf /tmp/recover
```
