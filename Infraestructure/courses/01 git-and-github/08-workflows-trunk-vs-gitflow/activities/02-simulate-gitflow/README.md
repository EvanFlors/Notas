# Actividad 02 — Simular GitFlow completo

## 1. Identificación

- **ID:** `gh-08-02-simulate-gitflow`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-08-workflows-trunk-vs-gitflow`
- **Dificultad:** intermediate
- **Duración estimada:** 40–60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a vivir en carne propia un ciclo GitFlow: ramas largas (`main` y `develop`), features sobre `develop`, una release congelada que se mergea *dos veces* (a `main` y a `develop`), y un hotfix sobre `main` que también se mergea *dos veces*. Cuenta los pasos y compara con el flujo del ejercicio 01.

## 3. Objetivos

Al terminar:

- Dejas una topología GitFlow verificable:
  - Ramas `main` y `develop` vivas.
  - Tags `v1.0.0` y `v1.0.1` sobre `main`.
  - Dos features consolidadas en `develop` **y** en `main`.
  - Hotfix presente en `main` **y** en `develop`.
- Reconoces en qué pasos es fácil olvidar el "segundo merge".
- Puedes defender (o rebatir) GitFlow con argumentos.

## 4. Prerrequisitos

- Actividad 01 completada.
- Git ≥ 2.30.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/gitflow-sim
cd /tmp/gitflow-sim
git log --oneline --all
git branch -a
```

Verás `main` con 1 commit base y tag `v0.1.0`. **Aún no existe `develop`**.

### 5.2 Crear `develop`

```bash
git switch -c develop
```

### 5.3 Feature 1 — `feature/greet-name`

```bash
git switch -c feature/greet-name
# Modifica app.py: en greet(), añade parámetro opcional `name`:
#   def greet(name=None):
#       return f"Hello, {name}" if name else "Hello from app"
git add app.py
git commit -m "feat(greet): accept optional name"

git switch develop
git merge --no-ff feature/greet-name -m "merge: feature/greet-name into develop"
git branch -d feature/greet-name
```

### 5.4 Feature 2 — `feature/farewell`

```bash
git switch -c feature/farewell
# Añade a app.py:
#   def farewell():
#       return "Bye"
git add app.py
git commit -m "feat(farewell): add farewell()"

git switch develop
git merge --no-ff feature/farewell -m "merge: feature/farewell into develop"
git branch -d feature/farewell
```

### 5.5 Cortar release `release/1.0.0`

```bash
git switch -c release/1.0.0 develop

# Bump de VERSION en app.py: VERSION = "1.0.0"
git add app.py
git commit -m "chore(release): bump version to 1.0.0"

# QA detecta un edge case; se arregla EN la release:
# Añade a app.py:
#   def _qa_check():
#       return "ok"
git add app.py
git commit -m "fix(release-1.0.0): QA edge case"
```

### 5.6 Doble merge: `release/1.0.0` → `main` (con tag) y → `develop`

```bash
# 1) merge a main con tag
git switch main
git merge --no-ff release/1.0.0 -m "merge: release/1.0.0 into main"
git tag -a v1.0.0 -m "Release 1.0.0"

# 2) merge BACK a develop (el típico olvido)
git switch develop
git merge --no-ff release/1.0.0 -m "merge: release/1.0.0 back into develop"

# 3) eliminar la rama de release
git branch -d release/1.0.0
```

### 5.7 Hotfix sobre `main` — `hotfix/typo`

```bash
git switch -c hotfix/typo main
# Arregla un typo en app.py: cambia "Hello from app" por "Hello from the app"
# y bump VERSION a 1.0.1
git add app.py
git commit -m "fix(greet): fix typo in default greeting (v1.0.1)"

# 1) merge a main con tag
git switch main
git merge --no-ff hotfix/typo -m "merge: hotfix/typo into main"
git tag -a v1.0.1 -m "Hotfix 1.0.1"

# 2) merge BACK a develop
git switch develop
git merge --no-ff hotfix/typo -m "merge: hotfix/typo back into develop"

# 3) eliminar la rama de hotfix
git branch -d hotfix/typo
```

### 5.8 Verificar

```bash
git log --oneline --graph --all --decorate
git branch -a
git tag -l
```

### 5.9 Validar

```bash
bash tests/validate.sh /tmp/gitflow-sim
```

## 6. Resultado esperado

- Ramas vivas: `main`, `develop`.
- Tags: `v0.1.0` (inicial), `v1.0.0`, `v1.0.1`.
- Las dos features (`feature/greet-name`, `feature/farewell`) están en `develop` **y** en `main` (vía la release).
- El hotfix está en `main` **y** en `develop`.
- `main` tiene exactamente 3 tags y un historial consistente.
- No quedan ramas `feature/*`, `release/*`, `hotfix/*`.

## 7. Criterios de aceptación

- [ ] Topología GitFlow correcta (ramas, tags, merges).
- [ ] Doble merge aplicado para release y para hotfix.
- [ ] `main` y `develop` ambas contienen los commits de las features y del hotfix.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gitflow-sim
```

Chequea cada rama, cada tag, cada merge y la propagación cruzada feature/hotfix.

## 9. Preguntas de reflexión

1. ¿Cuántos merges hiciste en total? ¿Cuántos en la Actividad 01?
2. ¿Qué pasa si olvidas el `merge back into develop` del hotfix? Describe el bug que reaparece.
3. ¿Cómo se simplificaría este flujo si usaras `git-flow` CLI? ¿Qué cambia en el DAG?
4. Para un SaaS multi-tenant con deploy diario, ¿cambiarías algo? Si sí, ¿qué y por qué?
5. Para un vendor de SDK on-premise con soporte simultáneo de 3 versiones mayores, ¿qué piezas de GitFlow tienen sentido y cuáles sobran?

## 10. Extensiones

- **E1** — Añade un segundo hotfix (`hotfix/exception-handling`) y repite el doble merge.
- **E2** — Simula el olvido del `merge back into develop` y luego **recupéralo** con `git cherry-pick -x <hotfix-hash>` desde `develop`. Compara DAG.
- **E3** — Reproduce lo mismo con la herramienta `git-flow` CLI (si la tienes) y observa cuántos comandos ahorra.

## 11. Limpieza

```bash
rm -rf /tmp/gitflow-sim
```
