# Actividad 01 — Abrir, revisar y mergear un Pull Request

## 1. Identificación

- **ID:** `gh-07-01-open-review-merge-pr`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-07-collaboration-prs-and-review`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a vivir el ciclo completo de un PR: rama feature con commits atómicos, descripción conforme a un template, aprobación de un reviewer, y merge con una **estrategia justificada**. Lo harás en **MODE=local** (sin GitHub, con un bare repo como "remoto") para que el ejercicio corra en CI y sin credenciales. Opcionalmente lo repites en **MODE=live** usando `gh`.

## 3. Objetivos

Al terminar:
- Simulas (o abres) un PR con rama feature y descripción conforme al template.
- Aplicas una review: comment, *suggestion*, approve/request changes.
- Mergeas con una estrategia (merge commit / squash / rebase) **justificada** en la descripción.
- Verificas con el validador.

## 4. Prerrequisitos

- Git ≥ 2.30, identidad global configurada.
- `bash`, `awk`, `grep`, `sed` (POSIX).
- Para `MODE=live`: `gh` autenticado (`gh auth login`) y un repo propio donde abrir PRs.

**Costos**: ninguno en `MODE=local`. En `MODE=live`, el repo puede ser privado y gratuito.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-base-repo.sh /tmp/pr-review
cd /tmp/pr-review/work
git log --oneline
# Verás 2 commits iniciales y la rama main con un remoto local.
ls -la .github/
# .github/PULL_REQUEST_TEMPLATE.md ya existe
```

El starter crea:

```
/tmp/pr-review/
├── remote.git/          # bare repo local — hace de "GitHub"
└── work/                # clon del contribuidor
    ├── README.md
    ├── greet.py
    └── .github/PULL_REQUEST_TEMPLATE.md
```

### 5.2 Objetivo del PR

Añade una función `shout(name)` en `greet.py` que devuelva `f"HELLO, {name.upper()}!"`, con su test. Esta es tu feature.

Issue simulado: en el repo hay un fichero `.pr/issues/1.md` que describe el requisito. Tu PR debe cerrarlo con `Fixes #1`.

### 5.3 Flujo (MODE=local, default)

1. **Crea la rama feature** y haz 2 commits atómicos:
   ```bash
   cd /tmp/pr-review/work
   git switch -c feat/shout
   # Edita greet.py: añade shout(name)
   git add greet.py
   git commit -m "feat: add shout helper"
   # Edita tests/test_greet.py: añade un test para shout
   git add tests/test_greet.py
   git commit -m "test: cover shout helper"
   git push -u origin feat/shout
   ```

2. **"Abre el PR" localmente** creando el documento de PR en `.pr/PR-1.md`. Usa `cp` sobre el template:
   ```bash
   mkdir -p .pr
   cp .github/PULL_REQUEST_TEMPLATE.md .pr/PR-1.md
   $EDITOR .pr/PR-1.md
   ```

   El cuerpo debe incluir **al menos**:
   - Sección `## Summary` no vacía.
   - Sección `## Changes` con bullets.
   - Línea `Fixes #1` (closing keyword).
   - Sección `## Test plan` con items marcados.
   - Sección `## Merge strategy` **con una de**: `squash`, `rebase`, `merge-commit`, y 1–2 frases justificando la elección.

3. **Simula la review**. Un segundo clon aprueba. El starter ya creó este clon en `/tmp/pr-review/reviewer`:
   ```bash
   cd /tmp/pr-review/reviewer
   git fetch origin feat/shout:feat/shout
   git switch feat/shout
   # Lee el código
   cat greet.py
   # Deja la aprobación como archivo
   mkdir -p .pr
   printf "approved-by: @reviewer\nreview: Looks good; nit: docstring opcional.\n" > .pr/PR-1.approvals
   git add .pr/PR-1.approvals
   git commit -m "chore(pr): approve PR-1"
   git push
   ```

4. **Trae la aprobación y mergea** con la estrategia que declaraste. Ejemplos para **squash**:
   ```bash
   cd /tmp/pr-review/work
   git fetch
   git switch main
   git merge --squash feat/shout
   git commit -m "feat: add shout helper (#1)

   Fixes #1

   Squashed from feat/shout (2 commits)."
   git push
   ```

   Para **merge commit** (`--no-ff`):
   ```bash
   git merge --no-ff feat/shout -m "Merge PR #1: feat: add shout helper

   Fixes #1"
   ```

   Para **rebase and merge** (lineal, conserva commits):
   ```bash
   git switch feat/shout
   git rebase origin/main
   git switch main
   git merge --ff-only feat/shout
   # Añade un commit chore que registre el cierre:
   git commit --allow-empty -m "chore(pr): close PR-1

   Fixes #1"
   ```

5. **Valida**:
   ```bash
   bash tests/validate.sh /tmp/pr-review
   ```

   Debe terminar con `OK: actividad completada correctamente.`

### 5.4 Flujo (MODE=live, opcional)

Requiere `gh auth status` OK y un repo tuyo (vacío) en GitHub.

```bash
export MODE=live
export GH_REPO="<tu-user>/<repo-vacio>"
bash starter/build-base-repo.sh /tmp/pr-review
cd /tmp/pr-review/work
gh repo set-default "$GH_REPO"
git remote set-url origin "git@github.com:${GH_REPO}.git"
git push -u origin main

# ... (haz la rama y commits como arriba) ...

gh pr create --fill --draft
# ... (editas descripción con tu Fixes #1 y Merge strategy) ...
gh pr ready
gh pr review --approve  # (en la práctica lo haría otra persona)
gh pr merge --squash --delete-branch
MODE=live bash tests/validate.sh /tmp/pr-review
```

El validador en `MODE=live` llamará a `gh pr view --json ...` para verificar: PR mergeado, estrategia aplicada, closing keyword presente.

## 6. Resultado esperado

- Rama `feat/shout` existe en `remote.git`.
- `main` contiene el cambio de `shout()` y el test.
- `.pr/PR-1.md` cumple la estructura requerida.
- `.pr/PR-1.approvals` contiene al menos una línea `approved-by:`.
- El commit de merge (o los commits mergeados) en `main` contiene `Fixes #1` o `(#1)` en el mensaje.
- Working tree limpio.

## 7. Criterios de aceptación

- [ ] Rama feature con ≥ 2 commits atómicos.
- [ ] `.pr/PR-1.md` con las 5 secciones requeridas (Summary / Changes / Fixes #1 / Test plan / Merge strategy).
- [ ] Aprobación registrada en `.pr/PR-1.approvals`.
- [ ] Merge aplicado en `main` según estrategia declarada.
- [ ] `tests/validate.sh` pasa en `MODE=local`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/pr-review
# o:
MODE=live bash tests/validate.sh /tmp/pr-review
```

El validador detecta `$MODE` (default `local`) y aplica los checks apropiados.

## 9. Preguntas de reflexión

1. En `MODE=local` el "PR" es un fichero y las "aprobaciones" son otro fichero. ¿Qué ganas y qué pierdes respecto al PR de GitHub?
2. Elegiste `squash`, `merge-commit` o `rebase`. ¿Por qué? ¿Qué cambia en `git log --oneline --graph` entre las tres?
3. Si el PR hubiera tenido 10 commits de los cuales 3 son "fix typo" y "wip", ¿cambiaría tu elección de estrategia? ¿Por qué?
4. ¿Qué pasaría si no incluyes `Fixes #1`? ¿Qué perdería un maintainer que entra al repo 6 meses después?

## 10. Extensiones (opcional)

- **E1** — Repite la actividad en `MODE=live` con un repo real en GitHub. Observa cómo `gh pr view --json mergeCommit,mergeStateStatus` cambia tras `gh pr merge`.
- **E2** — Añade un check de CI simulado: un script `tests/ci.sh` que debe pasar antes de que el validador lo acepte como "merge-ready".
- **E3** — Añade un segundo reviewer y modifica la política a "requiere 2 aprobaciones". Modifica el validador correspondientemente.

## 11. Limpieza

```bash
rm -rf /tmp/pr-review
```
