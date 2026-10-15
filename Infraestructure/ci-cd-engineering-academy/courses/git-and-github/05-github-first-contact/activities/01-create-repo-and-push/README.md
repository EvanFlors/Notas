# Actividad 01 — Crear repo en GitHub y publicar README + LICENSE

## 1. Identificación

- **ID:** `gh-05-01-create-repo-and-push`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-05-github-first-contact`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Primer repo "serio" publicado. Vas a crear uno con lo mínimo que un repo público debería tener desde el commit 1: README útil, LICENSE reconocible y `.gitignore` correcto. Como el módulo requiere GitHub, soportamos **dos modos**:

- **`MODE=live`** (default): usa `gh repo create` contra GitHub real.
- **`MODE=local`**: usa un remote `--bare` local; sirve para CI sin cuenta GitHub y para ensayar sin ensuciar.

Ambos modos validan **lo mismo en el repo local**: contenido correcto, al menos un commit sobre `main`, remoto configurado y push realizado.

## 3. Objetivos

Al terminar:
- Autenticas tu CLI contra GitHub (SSH, PAT fine-grained o `gh auth`) **o** entiendes la simulación local equivalente.
- Creas un repo con visibilidad explícita (public o private).
- Produces un `README.md` con secciones mínimas, un `LICENSE` (MIT), y un `.gitignore` razonable para Python.
- Haces `push -u origin main` y verificas con `git ls-remote origin`.
- Validas con `tests/validate.sh`.

## 4. Prerrequisitos

- `gh-04` completado (modelo de remoto, `fetch` vs `pull`, `--bare`).
- Git ≥ 2.30.
- **Modo `live`**: cuenta en GitHub + `gh` instalado y autenticado (`gh auth status` OK). Costo: $0 (repos free).
- **Modo `local`**: nada extra.

## 5. Instrucciones

### 5.1 Preparar

El `starter/` solo contiene un script de ayuda que inicializa el **remote simulado** (modo `local`) o verifica tu auth (modo `live`). No crea aún el repo del alumno — eso lo haces tú.

```bash
# Modo local (default aquí para que corra sin cuenta GitHub):
MODE=local bash starter/bootstrap.sh /tmp/create-repo-and-push

# Modo live (si tienes gh auth):
MODE=live bash starter/bootstrap.sh /tmp/create-repo-and-push
```

### 5.2 Elegir modo y seguir

#### Modo `live`

1. Elige nombre: `mi-primer-repo-<tuusuario>-<fecha>` (único).
2. Crea el repo y empújalo:

   ```bash
   cd /tmp/create-repo-and-push/local
   # ... edita README.md, LICENSE, .gitignore (ver 5.3) ...
   git add .
   git commit -m "chore: initial public skeleton"

   gh repo create mi-primer-repo-demo \
     --public \
     --source=. \
     --remote=origin \
     --push
   ```

3. Verifica en navegador: `gh repo view --web`.

#### Modo `local`

1. El script del starter ya creó `/tmp/create-repo-and-push/origin.git` (bare).
2. Ve al working repo:

   ```bash
   cd /tmp/create-repo-and-push/local
   # ... edita README.md, LICENSE, .gitignore (ver 5.3) ...
   git add .
   git commit -m "chore: initial public skeleton"

   # El starter ya configuró origin apuntando al bare. Pushea:
   git push -u origin main
   ```

### 5.3 Contenido mínimo requerido

Crea **estos tres archivos** en `/tmp/create-repo-and-push/local/` (sustituye el placeholder del starter si lo hay):

**`README.md`** — con al menos estas secciones (headings `##` exactos):

```markdown
# mi-primer-repo

Oración única que explica qué hace el proyecto.

## Instalación

Comandos copy-pasteable.

## Uso

Un ejemplo mínimo.

## Licencia

MIT (ver `LICENSE`).
```

**`LICENSE`** — Texto MIT reconocible. Debe empezar con `MIT License` en la primera línea. Puedes copiarlo de <https://choosealicense.com/licenses/mit/> o usar `gh repo view --license mit` tras crearlo. El validador acepta cualquier LICENSE que contenga la cadena `MIT License` o `Permission is hereby granted`.

**`.gitignore`** — mínimo para Python:

```gitignore
__pycache__/
*.pyc
.venv/
.pytest_cache/
.coverage
.DS_Store
```

### 5.4 Validar

```bash
# Modo local (lo que correrá el CI):
MODE=local bash tests/validate.sh /tmp/create-repo-and-push

# Modo live (verifica además que el repo exista en GitHub):
MODE=live bash tests/validate.sh /tmp/create-repo-and-push
```

Debe pasar con `OK`.

## 6. Resultado esperado

- Directorio `/tmp/create-repo-and-push/local/` con `README.md`, `LICENSE`, `.gitignore` correctos.
- Rama `main` con al menos 1 commit sobre un commit base (el que viene del starter o el inicial que creaste).
- Remote `origin` configurado y la rama `main` empujada:
  - En `MODE=local`: `origin.git/refs/heads/main` existe y apunta al mismo hash que `local/.git/refs/heads/main`.
  - En `MODE=live`: `gh repo view <nombre>` muestra el repo y `gh api repos/<user>/<name>/git/refs/heads/main` resuelve.
- Working tree limpio.

## 7. Criterios de aceptación

- [ ] README con **las 4 secciones requeridas**: título `#`, `## Instalación`, `## Uso`, `## Licencia`.
- [ ] LICENSE con texto MIT reconocible.
- [ ] `.gitignore` presente y no vacío.
- [ ] Al menos 1 commit nuevo sobre el commit base.
- [ ] Working tree limpio.
- [ ] `main` empujada al remoto (`origin`).

## 8. Validación

El validador acepta ambos modos vía la env var `MODE`:

```bash
MODE=local bash tests/validate.sh /tmp/create-repo-and-push
MODE=live  bash tests/validate.sh /tmp/create-repo-and-push
```

Lee `tests/validate.sh` para ver qué checa cada modo.

## 9. Preguntas de reflexión

1. ¿Qué método de auth usaste y por qué? ¿Qué habrías cambiado en otro contexto (CI, bot, workstation compartida)?
2. ¿Por qué el `.gitignore` va desde el commit 1 y no "más tarde"? ¿Qué pasa si lo añades después de haber commiteado `__pycache__/`?
3. ¿Elegirías MIT, Apache-2.0 o GPL para este repo? Justifica.
4. ¿Qué topics añadirías para que te encuentren? (Puedes añadirlos con `gh repo edit --add-topic ...`.)
5. En el `MODE=local`, ¿qué parte **sí** es Git puro y qué parte es simulación de GitHub?

## 10. Extensiones (opcional)

- **E1** — Añade topics con `gh repo edit --add-topic python --add-topic cli` (modo live).
- **E2** — Pon una descripción corta: `gh repo edit --description "..."`.
- **E3** — Cambia la visibilidad de public a private y de vuelta: `gh repo edit --visibility private`.
- **E4** — Añade un `.gitattributes` con `linguist-documentation` para `docs/`.

## 11. Limpieza

```bash
# Local
rm -rf /tmp/create-repo-and-push

# Live (si creaste repo en GitHub):
gh repo delete mi-primer-repo-demo --yes
```
