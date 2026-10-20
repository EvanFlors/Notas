# Actividad 01 — Atomic commits a partir de un diff sucio

## 1. Identificación

- **ID:** `gh-02-01-atomic-commits`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-02-recording-changes`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregan un repo con un working tree sucio: 3 archivos modificados, con **cambios no relacionados** mezclados. Tu tarea es producir una **historia limpia** de 4+ commits atómicos usando `git add -p` y mensajes convencionales.

## 3. Objetivos

Al terminar:
- Divides un diff ancho en commits atómicos.
- Usas `git add -p` + `s`/`y`/`n`/`e` con criterio.
- Verificas con `git diff --staged` antes de cada commit.
- Escribes mensajes siguiendo *Conventional Commits*.
- Validas con el test automatizado.

## 4. Prerrequisitos

- Actividades de `gh-01` completadas.
- Git ≥ 2.30 con tu identidad global configurada.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-dirty-repo.sh /tmp/atomic-commits
cd /tmp/atomic-commits
git log --oneline
# Verás 1 commit "init: base state"
git status
# Verás 3 archivos modificados
```

### 5.2 Explorar

```bash
git diff          # revisa los cambios no staged
```

Observa que en los archivos hay **al menos 5 cambios lógicos distintos** mezclados:

- (1) Refactor con type hints en `app/calculator.py`.
- (2) Nueva función en `app/calculator.py`.
- (3) Fix de typo en el mensaje de error de `app/calculator.py`.
- (4) Añadir un test nuevo en `tests/test_calculator.py`.
- (5) Cambiar config de logging en `app/config.py`.

### 5.3 Objetivo

Produce **al menos 4 commits** (idealmente 5), cada uno **con una sola intención**, siguiendo *Conventional Commits* (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`, etc.).

### 5.4 Técnica recomendada

Para cada intención:

1. `git add -p <archivo>` → responde `y`/`n`/`s`/`e` para stagear **solo** los hunks de esa intención.
2. `git diff --staged` → verifica que lo staged es exactamente lo que quieres.
3. `git commit -m "<tipo>: <mensaje imperativo>"`.
4. Repite hasta `git status` limpio.

Si un hunk no se deja partir con `s`, usa `e` para editar el diff manualmente.

### 5.5 Mensajes de commit requeridos (formato)

```
<tipo>: <subject en imperativo, ≤72 chars>
```

Tipos aceptados: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`.

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/atomic-commits
```

Debe pasar con `OK`.

## 6. Resultado esperado

- Working tree limpio (`git status` → `nothing to commit`).
- **≥ 4 commits nuevos** en `main` sobre el commit base.
- Todos los mensajes nuevos cumplen `^(feat|fix|refactor|test|docs|chore|style)(\(.+\))?: .+`.
- Al menos un `fix:` (del typo), un `refactor:` (del type-hints) y un `feat:` o `test:` (de la nueva función/test).
- Ningún commit toca más de 1 "intención" lógica (verificado por líneas por commit — soft check).
- Contenido final del working tree **idéntico** al del script de solución.

## 7. Criterios de aceptación

- [ ] Funcionalidad: 4+ commits atómicos, contenido final correcto.
- [ ] Calidad: mensajes convencionales, imperativos.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes explicar por qué dividiste así (no al azar).

## 8. Validación

```bash
bash tests/validate.sh /tmp/atomic-commits
```

Chequea:
- Base: repo existe, HEAD en main.
- ≥4 commits sobre `init: base state`.
- Working tree limpio.
- Todos los mensajes de los nuevos commits cumplen *Conventional Commits*.
- Contenido final de los 3 archivos modificados coincide con la solución (hash).

## 9. Preguntas de reflexión

1. ¿Qué tamaño/granularidad eliges para "atómico"? ¿Cuándo un commit es "muy chico" y cuándo "muy grande"?
2. ¿En qué orden committeaste? ¿Hubieras elegido el mismo orden si el PR cerraba un issue específico?
3. ¿Qué pasó cuando intentaste `s` (split) en un hunk que no se dejaba partir? ¿Qué alternativa usaste?
4. ¿Puedes imaginar un reviewer agradeciéndote esta separación meses después? ¿En qué escenario?

## 10. Extensiones (opcional)

- **E1** — Usa `git commit --fixup=<hash>` para marcar un commit como "fix de este otro". Investiga `git rebase -i --autosquash` (se cubre en `gh-06`).
- **E2** — Instala el framework `pre-commit` y añade un hook `conventional-pre-commit` que rechace mensajes mal formateados.
- **E3** — Repite la actividad con `--amend` sobre tu último commit (añade un cambio relacionado olvidado).

## 11. Limpieza

```bash
rm -rf /tmp/atomic-commits
```
