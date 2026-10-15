# Actividad 02 — Rebase `--onto` para mover una rama a la base correcta

## 1. Identificación

- **ID:** `gh-06-02-rebase-onto-wrong-base`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-06-rebase-vs-merge-and-interactive`
- **Dificultad:** intermediate
- **Duración estimada:** 20–30 min
- **Tipo:** independent

> **Independent**: no te damos el comando exacto. Diagnosticas tú y aplicas el fix. La solución existe en `solution/` pero **no la mires** antes de intentarlo.

## 2. Contexto

Un dev creó la rama `feature/dashboard` **desde `release/1.0`** por error. Debería colgar de `main`. La rama tiene 3 commits propios de la feature, cada uno tocando un archivo distinto dentro de `dashboard/`. Mientras tanto `main` avanzó con otro commit.

Si abres el PR a `main` tal cual, incluirás commits que son parte de la release (bump de versión, release notes) que **no** deberían ir en `main` por este PR.

Tu tarea: mover `feature/dashboard` para que cuelgue de `main`, preservando los 3 commits de feature y nada más.

## 3. Objetivos

- Diagnosticar el DAG con `git log --all --graph --oneline --decorate`.
- Calcular los argumentos correctos para `git rebase --onto`.
- Aplicarlo y verificar que la topología es la esperada.

## 4. Prerrequisitos

- Haber completado la actividad 01 de este módulo.
- Haber leído `examples/02-rebase-onto/`.
- Git ≥ 2.30.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-wrong-base.sh /tmp/rebase-onto-wrong-base
cd /tmp/rebase-onto-wrong-base
git log --all --graph --oneline --decorate
```

Observa:
- Hay 3 ramas: `main`, `release/1.0`, `feature/dashboard`.
- `feature/dashboard` tiene **3 commits propios** (`feat(dashboard): scaffold`, `... add app.js`, `... add styles`) encima de `release/1.0`.
- `release/1.0` tiene 2 commits propios (`docs: release notes 1.0`, `chore: bump to 1.0`) después del commit base `chore: initial`.
- `main` tiene 1 commit propio (`chore: bump to 0.2 (unreleased)`) después del commit base.

### 5.2 Objetivo

Dejar `feature/dashboard` colgando **de `main`**, con sus 3 commits propios reaplicados encima, sin commits de la release.

Topología deseada (approx):

```
* <nuevo> (feature/dashboard) feat(dashboard): add styles
* <nuevo> feat(dashboard): add app.js
* <nuevo> feat(dashboard): scaffold
* a5b     (main) chore: bump to 0.2 (unreleased)
| * f3c   (release/1.0) chore: bump to 1.0
| * e2b   docs: release notes 1.0
|/
* 456     chore: initial
```

### 5.3 Pistas (no la solución)

- La operación es `git rebase --onto <newbase> <upstream> [<branch>]`.
- `<newbase>` = a dónde queremos pegar los commits.
- `<upstream>` = la base **de donde salen** los commits que queremos mover. Pista: ¿qué rama es la base "equivocada" que la feature tiene como ancestro?
- `[<branch>]` = qué rama reescribir. Si estás en ella, puedes omitirlo.
- Si te equivocas: `git rebase --abort` o `git reflog` + `git reset --hard HEAD@{N}` te sacan.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/rebase-onto-wrong-base
```

Debe terminar en `OK`.

## 6. Resultado esperado

- `feature/dashboard` tiene exactamente 3 commits sobre `main`.
- Los 3 commits son los de feature (subjects `feat(dashboard): scaffold`, `feat(dashboard): add app.js`, `feat(dashboard): add styles`).
- Ninguno de esos 3 commits toca `RELEASE_NOTES.md` ni `VERSION`.
- `main` no cambió.
- `release/1.0` no cambió.
- Working tree limpio.

## 7. Criterios de aceptación

- [ ] Funcionalidad: `feature/dashboard` cuelga de `main` con 3 commits propios.
- [ ] Intacto: `main` y `release/1.0` no se modificaron.
- [ ] Scope: cada commit de feature toca solo archivos dentro de `dashboard/`.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/rebase-onto-wrong-base
```

Chequea:
- Las 3 ramas existen.
- `feature/dashboard` tiene exactamente 3 commits sobre `main`.
- Los subjects son los esperados.
- Ningún commit de feature toca `RELEASE_NOTES.md` ni `VERSION`.
- `main` y `release/1.0` no se movieron de donde estaban al preparar el starter.
- Working tree limpio.

## 9. Preguntas de reflexión

1. ¿Qué habría pasado si hubieras hecho `git rebase main` (sin `--onto`) desde `feature/dashboard`?
2. ¿Cómo lo resolverías con `cherry-pick` en lugar de `rebase --onto`? ¿Qué trade-offs tiene cada camino?
3. Si la rama ya estuviera pusheada a un remoto y otro dev la estuviera siguiendo, ¿cómo coordinas el fix para no romper a tu colega?
4. ¿Qué pasa con los commits viejos (los de `feature/dashboard` antes del rebase)? ¿Dónde quedan? ¿Durante cuánto tiempo?

## 10. Extensiones (opcional)

- **E1** — Repite el ejercicio pero esta vez **sin** usar `--onto`: logra el mismo resultado con una secuencia de `git cherry-pick`.
- **E2** — Prepara un remoto bare local (`git clone --bare` o `git init --bare`), pushea `feature/dashboard` antes del rebase, haz el rebase, y pushea con `--force-with-lease`.
- **E3** — Investiga `git rebase --update-refs`. ¿Qué pasaría si `feature/dashboard` tuviera a su vez una rama derivada `feature/dashboard-ux`? Simula el escenario.

## 11. Limpieza

```bash
rm -rf /tmp/rebase-onto-wrong-base
```
