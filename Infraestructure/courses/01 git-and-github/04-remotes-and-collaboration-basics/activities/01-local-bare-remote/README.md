# Actividad 01 — Local bare remote end-to-end

## 1. Identificación

- **ID:** `gh-04-01-local-bare-remote`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-04-remotes-and-collaboration-basics`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a montar, **sin GitHub**, un setup completo cliente + servidor Git:
- Un **bare repo local** que hace de "servidor".
- Un **clon de trabajo** que pushea, fetchea, y configura tracking.

Entender que un "servidor Git" no es más que un bare repo accesible por filesystem (o SSH) desmitifica GitHub y cualquier otro provider. GitHub es un bare repo en sus datacenters + UI + auth. Ni más ni menos.

## 3. Objetivos

Al terminar deberías poder:

- Crear un bare repo con `git init --bare` y describir qué contiene.
- Configurar un remote con `git remote add` y verificarlo con `git remote -v` y `git remote show`.
- Pushear una rama con `git push -u` y entender qué hace `-u`.
- Fetchear y leer `refs/remotes/origin/*` como caché local.
- Verificar tracking con `git branch -vv`.
- Interpretar los mensajes "ahead/behind" de `git status`.

## 4. Prerrequisitos

- `gh-03-branching-and-merging-basics` completado.
- Haber leído `theory/lesson.md` secciones 1–6.
- Git ≥ 2.30.
- Permisos de escritura en `/tmp`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

El starter solo limpia la carpeta de trabajo. No crea el bare ni el clon: **lo haces tú**.

```bash
bash starter/prepare.sh /tmp/gh-04-bare
```

Resultado: existe `/tmp/gh-04-bare/` vacío.

### 5.2 Pasos guiados

Haz todo bajo `/tmp/gh-04-bare/`.

**Paso 1 — Crear el bare "server"**

```bash
cd /tmp/gh-04-bare
git init --bare origin.git
```

Explora qué hay dentro:

```bash
ls origin.git/
# HEAD  branches/  config  description  hooks/  info/  objects/  refs/
cat origin.git/HEAD
# ref: refs/heads/main    (o 'master' según tu init.defaultBranch)
cat origin.git/config
# bare = true
```

Si tu `HEAD` dice `master`, puedes forzar `main`:

```bash
rm -rf origin.git
git init --bare -b main origin.git
```

**Paso 2 — Crear un repo de trabajo y conectarlo al bare**

```bash
cd /tmp/gh-04-bare
mkdir local && cd local
git init -b main
git config user.name  "Student"
git config user.email "student@example.com"

echo "# gh-04 lab" > README.md
git add README.md
git commit -m "init: project"
```

Añade el remote:

```bash
git remote add origin /tmp/gh-04-bare/origin.git
git remote -v
# origin    /tmp/gh-04-bare/origin.git (fetch)
# origin    /tmp/gh-04-bare/origin.git (push)
```

**Paso 3 — Primer push con tracking**

```bash
git push -u origin main
# * [new branch]      main -> main
# branch 'main' set up to track 'origin/main'.
```

Verifica tracking:

```bash
git branch -vv
# * main 8c3f2a1 [origin/main] init: project
```

`-u` (`--set-upstream`) hizo dos cosas: creó la rama en el server y configuró `main` para que **"sepa"** que su upstream es `origin/main`.

**Paso 4 — Inspeccionar el server**

```bash
cd /tmp/gh-04-bare/origin.git
cat HEAD
# ref: refs/heads/main
cat refs/heads/main
# <el mismo hash que local/main>
git log --oneline main
# init: project
```

El bare no tiene working tree pero sí historia. Es un repo real.

**Paso 5 — Hacer un segundo commit y pushear sin flags**

```bash
cd /tmp/gh-04-bare/local
echo "Second line." >> README.md
git commit -am "feat: second line"
git push
#   gracias al upstream de step 3, no necesitas argumentos
```

**Paso 6 — Simular que "alguien" pusheó, usando un segundo clon**

Esto prepara el escenario para la Actividad 02.

```bash
cd /tmp/gh-04-bare
git clone origin.git other
cd other
git config user.name  "Other"
git config user.email "other@example.com"

echo "Third line (other)." >> README.md
git commit -am "feat: third line"
git push
```

**Paso 7 — Volver al clon original y leer `fetch` sin `pull`**

```bash
cd /tmp/gh-04-bare/local
git fetch origin
git status
# "Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded."

git log --oneline
# tu main NO ha cambiado

git log --oneline origin/main
# origin/main SÍ muestra el commit nuevo
```

Explora dónde vive esa caché:

```bash
ls .git/refs/remotes/origin/
# HEAD  main
cat .git/refs/remotes/origin/main
# <el hash del commit de 'other', traído en el fetch>
```

**Paso 8 — Fast-forward intencional**

```bash
git merge --ff-only origin/main
# Updating ...
# Fast-forward
git log --oneline
# ahora main == origin/main
```

**Paso 9 — Inspeccionar el estado completo**

```bash
git remote show origin
# * remote origin
#   Fetch URL: /tmp/gh-04-bare/origin.git
#   Push  URL: /tmp/gh-04-bare/origin.git
#   HEAD branch: main
#   Remote branches:
#     main tracked
#   Local branch configured for 'git pull':
#     main merges with remote main
#   Local ref configured for 'git push':
#     main pushes to main (up to date)
```

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/gh-04-bare
```

Debería terminar en `RESULT: 7/7 checks OK.`

## 6. Resultado esperado

- `/tmp/gh-04-bare/origin.git/` existe y es bare (sin working tree, `config.bare = true`).
- `/tmp/gh-04-bare/local/` es un clon de trabajo con remote `origin` apuntando al bare.
- `main` local tiene upstream `origin/main`.
- Hay **al menos 3 commits** en `origin.git` main (`init: project`, `feat: second line`, `feat: third line`).
- `local/main` y `origin.git`'s `main` apuntan al mismo hash.

## 7. Criterios de aceptación

- [ ] Bare repo creado con `git init --bare` (no cualquier dir con nombre `.git`).
- [ ] Remote `origin` configurado en `local` y apunta a la ruta del bare.
- [ ] `main` local tiene upstream `origin/main`.
- [ ] Historia en `origin.git` tiene al menos 3 commits en `main`.
- [ ] `local/main` == `origin.git/refs/heads/main` (mismo hash).

## 8. Validación

```bash
bash tests/validate.sh /tmp/gh-04-bare
```

El script revisa 7 condiciones y reporta OK/FAIL por cada una.

## 9. Preguntas de reflexión

1. ¿Qué diferencia a `/tmp/gh-04-bare/origin.git/` de un repo "normal" clonado con `git clone`? Da **dos** diferencias concretas en el filesystem y **una** en comportamiento.
2. ¿Qué pasa exactamente en el server cuando ejecutas `git push -u origin main` por primera vez? ¿Y qué cambia en tu `.git/config` local?
3. Si borras el directorio `.git/refs/remotes/origin/` en `local` y haces `git status`, ¿qué debería pasar? ¿Y después de un `git fetch`?
4. ¿Por qué el bare rechazaría un push si lo hicieras a una rama que coincide con su HEAD si **no fuera** bare? ¿Cómo lo evita el flag `--bare`?
5. ¿En qué cambia esta actividad si en lugar de `/tmp/gh-04-bare/origin.git` el remote fuera `ssh://user@host/path/origin.git`? ¿Qué pasos extra tendrías?

## 10. Extensiones (opcional)

- **E1** — Añade un segundo remote `backup` apuntando a otro bare y pushea a ambos. Verifica que puedes `git push backup main` sin cambiar `origin`.
- **E2** — Experimenta con `git ls-remote origin` sin hacer `fetch`. ¿Qué información te da? ¿Cuesta objetos?
- **E3** — Haz un `git clone --depth=1 /tmp/gh-04-bare/origin.git shallow` y mira la diferencia en `.git/` size y en `git log`.
- **E4** — Rompe un fast-forward intencionalmente: en `local`, haz `git commit --amend` (cambia hash) sobre el último commit, luego `git push`. Observa el mensaje `(non-fast-forward)` y la vía correcta de arreglarlo (sin `--force` para esta rama compartida).

## 11. Limpieza

```bash
rm -rf /tmp/gh-04-bare
```
