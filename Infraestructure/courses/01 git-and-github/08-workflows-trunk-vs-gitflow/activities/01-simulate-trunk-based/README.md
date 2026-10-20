# Actividad 01 — Simular trunk-based development

## 1. Identificación

- **ID:** `gh-08-01-simulate-trunk-based`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-08-workflows-trunk-vs-gitflow`
- **Dificultad:** intermediate
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a vivir un "día de trabajo" en trunk-based: dos features cortas, cada una en una rama efímera, cada una detrás de un flag apagado, ambas integradas a `main` el mismo día. `main` tiene que quedar **deployable en todo momento**.

## 3. Objetivos

Al terminar:

- Reproduces trunk-based en Git real.
- Mantienes `main` deployable.
- Mergeas 2 ramas efímeras **el mismo día** y las eliminas.
- Dejas flags apagados por default: *deploy ≠ release*.
- Validas con el script.

## 4. Prerrequisitos

- `gh-07` completado.
- Git ≥ 2.30 con identidad global configurada.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/tbd-sim
cd /tmp/tbd-sim
git log --oneline
```

Verás 1 commit `init: scaffold trunk-based repo` y un `flags.py` vacío (`FLAGS = {}`), un `app.py` *legacy* y un `tests/smoke.sh` que debe pasar siempre.

### 5.2 Feature 1 — `feat/new-checkout` (debe vivir < 10 min aquí)

```bash
git switch -c feat/new-checkout

# 1. Añade flag entry en flags.py apagado:
#    FLAGS = {"new_checkout": False}

# 2. Modifica app.py: ruta nueva de checkout detrás del flag.
#    def checkout():
#        if FLAGS.get("new_checkout"):
#            return "new-checkout"
#        return "legacy-checkout"

# 3. Smoke test debe seguir pasando:
bash tests/smoke.sh

# 4. Commit ("feat(checkout): new flow behind flag (off)")
git add flags.py app.py
git commit -m "feat(checkout): new flow behind flag (off)"

# 5. Merge back a main CON --no-ff y mensaje "merge: feat/new-checkout" y elimina la rama
git switch main
git merge --no-ff feat/new-checkout -m "merge: feat/new-checkout"
git branch -d feat/new-checkout
```

### 5.3 Feature 2 — `feat/dark-mode` (misma receta, pocos minutos después)

```bash
git switch -c feat/dark-mode

# 1. Añade "dark_mode": False al dict FLAGS en flags.py.
# 2. Añade función render() en app.py gated por FLAGS["dark_mode"].
#    def render():
#        if FLAGS.get("dark_mode"):
#            return "ui-dark"
#        return "ui-light"
# 3. Smoke test pasa:
bash tests/smoke.sh
# 4. Commit ("feat(ui): dark mode behind flag (off)")
git add flags.py app.py
git commit -m "feat(ui): dark mode behind flag (off)"

# 5. Merge a main con --no-ff y mensaje "merge: feat/dark-mode", elimina la rama
git switch main
git merge --no-ff feat/dark-mode -m "merge: feat/dark-mode"
git branch -d feat/dark-mode
```

### 5.4 Verificar

```bash
git log --oneline --graph --all
git branch -a       # solo main
bash tests/smoke.sh # debe pasar
```

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/tbd-sim
```

Debe terminar con `OK: actividad completada correctamente`.

## 6. Resultado esperado

- Rama única viva: `main`.
- Historial contiene (en orden lógico desde el init):
  - `feat(checkout): new flow behind flag (off)` (en un merge commit `merge: feat/new-checkout`).
  - `feat(ui): dark mode behind flag (off)` (en un merge commit `merge: feat/dark-mode`).
- `flags.py` contiene `"new_checkout": False` y `"dark_mode": False`.
- `tests/smoke.sh` pasa.
- Las ramas `feat/*` ya no existen.

## 7. Criterios de aceptación

- [ ] Topología correcta (ver §6).
- [ ] Flags apagados por default.
- [ ] `main` deployable (smoke pasa).
- [ ] Ramas feature eliminadas.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tbd-sim
```

Verifica:
- `HEAD` en `main`.
- Working tree limpio.
- Dos merge commits con los subjects esperados.
- Dos commits de feature con los subjects esperados y gated por sus flags.
- `flags.py` con ambos flags en `False`.
- Smoke test pasa.
- No quedan branches `feat/*`.

## 9. Preguntas de reflexión

1. ¿Qué cambiaría si el flag estuviera encendido por default? ¿Por qué apagado es el estándar?
2. ¿Qué pasaría si una de las features tomara 3 días en vez de 10 min? Describe el escenario probable al mergear.
3. En trunk-based "escalado" (20 devs commiteando a `main` a diario), ¿qué piezas adicionales necesitas? Lista 3.
4. ¿Cómo se *retira* un feature flag una vez consolidado el feature? ¿Qué pasa si no se retira?

## 10. Extensiones

- **E1** — Repite con **squash & merge** (`git merge --squash feat/x && git commit`) para producir historia lineal. Compara el DAG.
- **E2** — Añade un tercer feature `feat/analytics` en paralelo al segundo (misma `main` base) para experimentar un merge con conflicto trivial.
- **E3** — Escribe un *post-merge hook* local que falle si hay más de 3 ramas vivas (fuerza la higiene).

## 11. Limpieza

```bash
rm -rf /tmp/tbd-sim
```
