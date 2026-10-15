# Lección: Hooks, submódulos, subtrees y LFS

> **ID:** `gh-11-hooks-submodules-subtrees-lfs` · **Nivel:** avanzado · **Duración:** 4 h
> **Prerrequisitos:** `gh-09-git-internals`.

---

## 1. Introducción intuitiva

Hasta ahora Git fue autocontenido: un repo, archivos de texto moderadamente pequeños, operaciones puramente locales. En la realidad producción pincha en tres puntos:

1. **"El CI me dice en 8 minutos que olvidé un `print()`"**. Querrías que te lo diga en 1 segundo, **antes del commit**. Para eso existen los **hooks**.
2. **"Dependemos de una librería interna de otro repo"**. ¿Clonar los dos? ¿Copiar el código? ¿Fundirlos en uno? Hay tres estrategias con trade-offs duros: **submodule**, **subtree**, **monorepo**.
3. **"Nuestro repo pesa 2 GB porque alguien committed un `.psd` de 400 MB en 2019"**. Git clona *toda la historia*; los blobs grandes son veneno. Para eso existe **Git LFS** (y, para repos ya enormes, **partial clone** y **sparse-checkout**).

Este módulo trata los tres problemas. Son avanzados pero recurrentes: aparecen en todo repo serio tarde o temprano.

---

## 2. Fundamentos

### 2.1 Los hooks viven en `.git/hooks/`

Un hook es un **script ejecutable** con un nombre específico (`pre-commit`, `commit-msg`, `pre-push`, `post-checkout`...) en `.git/hooks/`. Git lo invoca en los momentos definidos. Si el script sale con código `!= 0`, Git **aborta** la operación.

```
.git/hooks/
├── pre-commit.sample
├── commit-msg.sample
├── pre-push.sample
├── pre-receive.sample           (solo lado servidor)
├── update.sample                (solo lado servidor)
├── post-receive.sample          (solo lado servidor)
└── ...
```

Los `.sample` vienen con `git init`. Para activar un hook: quitas `.sample`, lo haces ejecutable (`chmod +x`), y listo.

**Problema #1**: `.git/` **no se versiona**. Si tu equipo necesita el mismo hook, cada dev debe instalarlo a mano. Pasa a estar actualizado "casi siempre".

**Problema #2**: hook escrito en bash puro no escala si quieres 10 chequeos (lint, format, trufflehog, ruff, mypy...). Necesitas gestionar versiones de herramientas, caching, orquestación.

**Solución**: el framework `pre-commit` (Python package, `pre-commit.com`). Veremos en §4.

### 2.2 Qué guarda un submódulo: el **gitlink**

Un submódulo no es una carpeta "copiada". En el tree del super-repo, la entrada del submódulo tiene **mode `160000`** (gitlink) y, en lugar de un hash de blob o tree, apunta a un **commit SHA del otro repo**.

```
$ git ls-tree HEAD
040000 tree 2b3c...  app/
160000 commit a9f0...  vendor/libfoo       ← gitlink, no tree
100644 blob abcd...  README.md
```

El super-repo registra:
- La **ruta** donde se monta el submódulo (`vendor/libfoo`).
- La **URL** del otro repo (en `.gitmodules`, archivo tracked).
- El **commit SHA exacto** del submódulo que corresponde a este commit del super (en el tree, mode 160000).

Al clonar: `git clone --recurse-submodules <url>` o, tras un `clone` normal, `git submodule update --init --recursive`. Si olvidas el flag, los directorios del submódulo quedan **vacíos**.

### 2.3 Qué es un subtree

Un subtree **copia el contenido** del otro repo a un subdirectorio del tuyo y (opcionalmente) **reescribe su historia** para que aparezca como commits de tu repo. No hay gitlink. No hay `.gitmodules`.

Diferencia práctica:
- **Submodule**: tu repo guarda *una referencia* al otro. Clonar el tuyo no trae el contenido del submódulo salvo que uses `--recurse-submodules`.
- **Subtree**: tu repo guarda *el contenido*. Clonar el tuyo lo trae automáticamente. El "precio" es que la historia del subtree se mezcla con la tuya (o la escondes con `--squash`).

### 2.4 Qué hace Git LFS: filtros smudge/clean

Git LFS (Large File Storage) intercepta vía los **filtros de atributos** `clean` (al añadir al index) y `smudge` (al materializar en working tree):

```
         .gitattributes dice: *.bin filter=lfs

                 (al add/commit)
   working      ──── clean ────▶  "oid sha256:<hash>\nsize:<N>"   (puntero)
   tree bytes                     ↑ ESTO es lo que entra al blob
                                  ↑ ESTO va a .git/objects/
                                  ↓ el binario real sube a LFS server

                 (al checkout)
   working      ◀──── smudge ───  puntero
   tree bytes                     ↑ descarga el binario real desde LFS
```

Resultado: el repo Git contiene **punteros de texto plano de ~130 bytes**, no blobs gigantes. El contenido real vive en un **servidor LFS** (incluido en GitHub, con cuotas aparte). Clonar es ligero por default; `git lfs pull` trae los binarios cuando los necesitas.

**Trade-off clave**: LFS es un sistema paralelo con su propia storage y bandwidth billing. No es gratis para repos activos.

### 2.5 Partial clone y sparse-checkout

Para repos **enormes** (Linux kernel, Chromium, monorepos corporativos):

- **Partial clone** (`git clone --filter=blob:none`): clona la historia (commits + trees) sin bajar blobs. Los blobs se descargan **a demanda** cuando los lees (`git log -p`, `git blame`, checkout). Requiere servidor que lo soporte (GitHub, GitLab, Gitea modernos sí).
- **Sparse-checkout** (`git sparse-checkout set <paths>`): materializa en working tree **solo ciertos paths** del repo. Todo lo demás existe en `.git/` pero no se escribe en disco.

Combinados = puedes trabajar en un monorepo de 50 GB sin tener los 50 GB en disco.

---

## 3. Contexto histórico

**Hooks** existen desde Git 1.x. El framework `pre-commit` apareció en 2014 (Yelp open-sourced it) y resolvió el "¿cómo versionamos los hooks?". Hoy es estándar de facto en Python/multi-lenguaje; otros ecosistemas tienen equivalentes (Husky en JS, lefthook, …).

**Submódulos** son casi tan viejos como Git (introducidos ~2007). Su UX fue tan dolorosa durante años que generó una industria de alternativas. **`git subtree`** entró a Git contrib en 2012 como una respuesta: "lo mismo, con menos fricción para el consumidor". Ninguno gana del todo; ambos siguen en uso.

**Git LFS** fue anunciado por GitHub en abril 2015 como respuesta al problema de binarios en Git. Antes existían alternativas (`git-annex`, `git-fat`), pero LFS ganó por integración con GitHub/GitLab/Bitbucket. Es **una extensión**, no parte core de Git; requiere instalar `git-lfs` aparte.

**Partial clone y sparse-checkout** son relativamente recientes como features estables: partial clone (`--filter`) ~Git 2.19 (2018), sparse-checkout v2 reescrito ~Git 2.25 (2020), `git sparse-checkout` (comando dedicado) ~2.25. **Scalar** (Microsoft, originalmente para Windows source) se integró en Git core en 2.38 (2022). Antes Microsoft usaba su propio fork (VFS for Git).

---

## 4. Funcionamiento interno

### 4.1 Hooks nativos — anatomía

Un hook es cualquier ejecutable con el nombre correcto. Bash es común; Python/Node/Rust funcionan igual.

```bash
# .git/hooks/pre-commit
#!/usr/bin/env bash
# Rechaza commits con TODO sin owner "(TODO(foo): ...)"
set -e

bad=$(git diff --cached --name-only --diff-filter=ACM | \
      xargs grep -nE 'TODO([^(]|$)' 2>/dev/null || true)

if [ -n "$bad" ]; then
  echo "ERROR: TODOs sin owner detectados:"
  echo "$bad"
  echo "Usa 'TODO(nombre): texto' o remueve el TODO."
  exit 1
fi
```

- **`pre-commit`**: antes de que Git cree el commit. Si sale `!=0`, no hay commit. Recibe nada en stdin, puede leer el index (`git diff --cached`).
- **`commit-msg`**: recibe la ruta al archivo con el mensaje como `$1`. Útil para validar formato (p.ej. Conventional Commits).
- **`pre-push`**: antes de que Git envíe refs al remoto. Recibe líneas por stdin con `<local_ref> <local_sha> <remote_ref> <remote_sha>`.
- **`post-commit`**, **`post-merge`**, **`post-checkout`**, **`post-rewrite`**: informativos, no pueden abortar.

Lado servidor:
- **`pre-receive`**: recibe refs vía stdin, puede rechazar todo el push.
- **`update`**: una vez **por ref**; puede rechazar refs individuales.
- **`post-receive`**: informativo, útil para disparar deployments o notificaciones.

En GitHub SaaS **no puedes instalar hooks de servidor** (es gestionado); su equivalente son **Rulesets**, **required status checks** y **GitHub Actions** (`gh-12`). En GitHub Enterprise Server y en remotos propios (Gitea, GitLab self-hosted, bare repos tuyos) sí puedes.

### 4.2 El framework `pre-commit`

Problema: `.git/hooks/` no se versiona y mantener 10 hooks a mano no escala.

Solución: `pre-commit` (el framework) genera **un único shim** en `.git/hooks/pre-commit` que delega a lo definido en `.pre-commit-config.yaml` (archivo versionado):

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
        args: ['--maxkb=500']

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: ['--fix']
      - id: ruff-format
```

Flujo:

```
git commit
    │
    ▼
.git/hooks/pre-commit  (instalado por `pre-commit install`)
    │
    ▼
pre-commit framework reads .pre-commit-config.yaml
    │
    ├─▶ for each repo listed: clones to ~/.cache/pre-commit/, pins to `rev`
    ├─▶ creates isolated venv/env per hook
    ├─▶ runs each `id` on the staged files
    │
    ▼
exit 0 → commit proceeds | exit !=0 → commit aborted
```

Características clave:
- **`rev`** (SHA o tag) pinnea versiones → **reproducible**.
- **`.pre-commit-config.yaml`** versionado → **todo el equipo** tiene los mismos hooks.
- **`pre-commit install`** (una vez por clon) crea el shim.
- **`pre-commit run --all-files`** ejecuta todo contra el repo completo (útil para primera corrida y para CI).
- **`pre-commit autoupdate`** sube los `rev` a sus últimas versiones.

### 4.3 Submódulos — comandos esenciales

```bash
# Añadir
git submodule add https://github.com/foo/libfoo vendor/libfoo
# Esto crea: .gitmodules (tracked) + vendor/libfoo (clon dentro) + gitlink en el tree

git commit -m "chore: add libfoo as submodule"

# Clonar un repo con submódulos
git clone --recurse-submodules <url>
# o, si olvidaste:
git submodule update --init --recursive

# Actualizar el submódulo a su últimas commit en su rama remota
cd vendor/libfoo
git fetch && git checkout origin/main
cd ../..
git add vendor/libfoo
git commit -m "chore: bump libfoo to latest main"

# Trabajar en el submódulo
cd vendor/libfoo
git checkout -b fix/bug
# ... edita ...
git commit -am "fix bug"
git push                      # va al repo del submódulo
cd ../..
git add vendor/libfoo
git commit -m "chore: pin libfoo to fixed bug"
```

**Puntos duros**:
- Olvidar `--recurse-submodules` → carpetas vacías.
- Olvidar actualizar el gitlink después de modificar el submódulo → el super dice "modified content".
- Branching en el submódulo es independiente del branching del super.
- `git pull` en el super no actualiza submódulos por default (usa `git pull --recurse-submodules` o `git submodule update --remote`).

### 4.4 Subtrees — comandos esenciales

```bash
# Añadir un subtree
git subtree add --prefix=vendor/libfoo https://github.com/foo/libfoo main --squash
# --squash = colapsa la historia del upstream en 1 commit (menos ruido)

# Pull de actualizaciones
git subtree pull --prefix=vendor/libfoo https://github.com/foo/libfoo main --squash

# Push de cambios de vuelta (sofisticado)
git subtree push --prefix=vendor/libfoo <remote> main
```

Lo clave:
- No hay `.gitmodules`.
- Un clon normal trae **todo**.
- La historia del subtree aparece mezclada en tu `git log` (salvo `--squash`).
- No es compatible con "pin a un SHA exacto" tan limpio como submodule (lo haces a mano manteniendo refs).

### 4.5 Git LFS — flujo end-to-end

```bash
# 1. Una vez por máquina:
brew install git-lfs            # o apt install git-lfs, choco install git-lfs
git lfs install                 # instala los filter smudge/clean globalmente

# 2. En el repo, declara qué patrón va a LFS:
git lfs track "*.bin"
git lfs track "*.psd"
# Esto edita .gitattributes:
#   *.bin filter=lfs diff=lfs merge=lfs -text
#   *.psd filter=lfs diff=lfs merge=lfs -text
git add .gitattributes
git commit -m "chore: track binaries in LFS"

# 3. Añade el binario como de costumbre
dd if=/dev/urandom of=assets/data.bin bs=1M count=5
git add assets/data.bin
git commit -m "feat: add binary data"
git push

# 4. En otro clon:
git clone <url>                 # trae punteros + descarga blobs LFS necesarios
# o para forzar: git lfs pull
```

Verificar que lo que committed es un puntero, no bytes:

```bash
git cat-file -p HEAD:assets/data.bin
# → version https://git-lfs.github.com/spec/v1
#   oid sha256:...
#   size 5242880
```

Mitos vs realidad:
- **No** es gratis: GitHub cobra storage/bandwidth LFS por encima de cuotas.
- **No** encripta los blobs.
- **No** reduce clone time *totalmente*: aún descargas los blobs necesarios para el checkout actual.
- **Sí** mejora drásticamente clones históricos y el peso de los packfiles.
- **No puedes "desLFSear"** sin reescribir historia; decisión temprana.

### 4.6 Partial clone y sparse-checkout en acción

```bash
# Partial clone: sin blobs
git clone --filter=blob:none https://github.com/foo/giant giant
cd giant
# commits y trees presentes; blobs se bajan on-demand

# Sparse-checkout: solo materializar ciertos directorios
git sparse-checkout init --cone
git sparse-checkout set apps/backend libs/core
# tu working tree solo contiene apps/backend/ y libs/core/
# el resto existe en .git/ pero no en disco
```

`--cone` restringe los patrones a prefijos de directorio (más rápido que patrones arbitrarios).

---

## 5. Ejemplo mínimo

Un hook nativo que valida formato de mensaje de commit:

```bash
mkdir -p /tmp/hook-demo && cd /tmp/hook-demo
git init -q -b main
git config user.name "Demo" && git config user.email "demo@example.com"

cat > .git/hooks/commit-msg <<'EOF'
#!/usr/bin/env bash
# Rechaza mensajes que no cumplen Conventional Commits
msg_file="$1"
first_line=$(head -n1 "$msg_file")
if ! [[ "$first_line" =~ ^(feat|fix|docs|chore|refactor|test|style|ci|build|perf|revert)(\(.+\))?!?:\ .+ ]]; then
  echo "ERROR: mensaje no cumple Conventional Commits:" >&2
  echo "  '$first_line'" >&2
  exit 1
fi
EOF
chmod +x .git/hooks/commit-msg

echo "hi" > a.txt && git add a.txt
git commit -m "stuff"          # ← ABORTED
git commit -m "feat: add a"    # ← OK
```

El hook se ejecuta aun si usas `git commit -m` (no requiere editor).

Limpieza:
```bash
rm -rf /tmp/hook-demo
```

---

## 6. Implementación progresiva

### 6.1 Hook local → framework `pre-commit`

Empiezas con un hook bash en `.git/hooks/pre-commit`. Funciona pero no se comparte. Migras a `.pre-commit-config.yaml` + `pre-commit install`. Ahora todo el equipo con un `git clone && pre-commit install` tiene exactamente los mismos chequeos.

### 6.2 Añadir chequeos útiles al framework

Catálogo típico de hooks "no te arrepientes":

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: check-merge-conflict
      - id: check-yaml
      - id: check-json
      - id: detect-private-key

  # Formatter / linter (Python)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: ['--fix']
      - id: ruff-format

  # Detector de secretos
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.82.3
    hooks:
      - id: trufflehog
        args: ['git', 'file://.', '--only-verified', '--fail']

  # Validación de mensajes
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.4.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
```

Dos reglas de higiene:
1. **Nunca** uses `rev: HEAD`. Pinnea tags/SHAs → reproducibilidad.
2. **Corre `pre-commit run --all-files`** en CI (job rápido) para no depender de que cada dev tenga el hook instalado.

### 6.3 Decisión: submodule vs subtree vs monorepo

Matriz rápida (expandida en §8):

```
┌─────────────────────────────────────────────────────────────────┐
│                 Submodule       Subtree         Monorepo         │
├─────────────────────────────────────────────────────────────────┤
│ Pin exacto        ✅ (SHA)      ⚠️ manual       ❌ (no aplica)   │
│ Clone size        🟢 pequeño    🟡 incluye       🔴 todo         │
│ UX consumidor     🔴 duro       🟢 transparente  🟢 transparente │
│ Historia atómica  ❌            ⚠️ parcial       🟢              │
│ Herramientas CI   ⚠️ cuidado    🟢              🟢              │
│ Equipos indep.    🟢            🟡              🔴              │
└─────────────────────────────────────────────────────────────────┘
```

### 6.4 LFS: cuándo sí, cuándo artifact store aparte

**LFS si**:
- Binarios versionados que forman parte del repo (assets de juego, modelos ML, PSDs de diseño "fuente de verdad").
- Equipos acostumbrados a Git puro para todo.

**Artifact store (S3, GCS, Artifactory) si**:
- El binario es un **output de build**, no una fuente.
- Tamaños muy grandes (> GB) o churn alto (nuevos cada día).
- Necesitas versioning/retention policies independientes.

Regla práctica: **si lo puedes regenerar deterministaically desde fuentes, no va a LFS; va a un artifact store** cacheado por hash de inputs.

### 6.5 Repos grandes: Scalar y amigos

Para monorepos corporativos:
- `git maintenance start` → activa tareas periódicas en background (gc, prefetch, commit-graph).
- `scalar clone <url>` → clon optimizado para repos enormes (partial clone + sparse + maintenance).
- `commit-graph` y `multi-pack-index` → aceleran operaciones de log/traversal.

---

## 7. Aplicación profesional

### 7.1 `pre-commit` + CI = defensa en profundidad

Patrón:
1. **Localmente**: `pre-commit install` → feedback en ~1 segundo.
2. **En CI**: `pre-commit run --all-files` como primer job → bloquea PRs si alguien no corrió los hooks.
3. **Rulesets** (`gh-12`) → required status check en GitHub.

Resultado: feedback rápido para quien lo quiere, barrera dura para quien no.

### 7.2 Submódulos en producción

Cuándo sí tienen sentido:
- Vendor code firmado por otro equipo con release cadence propio (p.ej., SDK oficial de un vendor).
- Repos **public mirrors** que no debes modificar en tu side (open-source upstreams).
- Separación de concerns por **compliance** (código auditado separado).

Cuándo evitarlos:
- Equipos pequeños que iteran rápido sobre el "submódulo".
- Dependencias que ya tienes como paquetes publicados (usa el package manager, no vendoring).

### 7.3 LFS en producción

- Define cuotas y monitorea bandwidth (GitHub bills por **transfer**, no solo storage).
- `git lfs migrate import --include="*.psd"` reescribe historia para mover blobs ya commiteados a LFS. **Cuidado**: reescribe hashes → coordina con todo el equipo.
- Para CI: `git lfs pull --exclude="*"` + `git lfs pull --include="path/needed"` reduce download por job.

### 7.4 Repos muy grandes

- Chromium, Linux kernel, repos corporativos: usa partial clone + sparse-checkout + `git maintenance`.
- Protocolo moderno **wire protocol v2** (default desde Git 2.26) acelera `fetch` sobre repos con miles de refs.
- Si tu repo crece sin control y nunca pensaste en LFS: audita con `git-sizer` (<https://github.com/github/git-sizer>) y decide.

---

## 8. Trade-offs

### 8.1 Hook nativo vs framework `pre-commit`

**Hook nativo (`.git/hooks/<name>`)**:
- Cero dependencias extra; bash puro, portable.
- No se versiona → cada dev lo instala a mano (o un `make install-hooks`).
- Difícil orquestar múltiples checkers con sus versiones.

**Framework `pre-commit`**:
- `.pre-commit-config.yaml` versionado → consistencia equipo.
- Caching, aislamiento, pins por versión.
- Añade dependencia (Python + `pre-commit`).

Decisión: **framework por default** en equipos; hook nativo solo para scripts triviales de un solo repo personal.

### 8.2 Submodule vs Subtree vs Monorepo

**Submodule**:
- ✅ Pin exacto a un SHA del dependency.
- ✅ Clones pequeños si el consumidor no necesita el dependency.
- ❌ UX dura: cada operación nueva requiere recordar `--recurse-submodules`.
- ❌ Reviewers del super no ven el diff real del submódulo en el PR del super (solo el gitlink cambiando).

**Subtree**:
- ✅ Consumidor no hace nada especial.
- ✅ Code review del super muestra el diff real.
- ⚠️ Pin menos limpio; necesitas tooling o disciplina.
- ⚠️ Historia inflada si no usas `--squash`.

**Monorepo**:
- ✅ Historia atómica (un commit puede tocar múltiples "proyectos" coherentemente).
- ✅ Refactors cross-cutting son triviales.
- ✅ Tooling moderno (Bazel, Nx, Turborepo, Pants) hace build-affected eficiente.
- ❌ Requiere invertir en tooling de build selectivo.
- ❌ Permisos finos son más difíciles (CODEOWNERS mitiga).
- ❌ Repos muy grandes necesitan sparse/partial clone.

Decisión real:
- **Mini-equipo + un vendor "sagrado"** → submodule.
- **Vendor que modificas y re-upstreameas ocasionalmente** → subtree.
- **Equipo ≥ 10, varios servicios interrelacionados** → monorepo con tooling.
- **Hundreds de devs, miles de servicios** → monorepo + Scalar + Bazel/similar.

### 8.3 LFS vs artifact store externo

**LFS**:
- ✅ `git clone` sigue siendo *la* operación.
- ✅ Versioning atado al commit.
- ❌ Billing extra.
- ❌ Vendor lock-in (migración entre proveedores LFS es dolorosa).

**Artifact store (S3, Artifactory, GCS)**:
- ✅ Billing/retention policy independientes.
- ✅ No ensucia el repo con punteros.
- ❌ Fuente de verdad fuera de Git → coordinación extra.
- ❌ Tooling custom para checkout automático.

Regla: **fuente** → repo o LFS. **Output** → artifact store.

### 8.4 Partial clone vs full clone

**Full clone**:
- ✅ Autosuficiente offline.
- ❌ Pesado para repos enormes.

**Partial clone** (`--filter=blob:none`):
- ✅ Rápido inicial.
- ⚠️ Operaciones que necesitan blobs antiguos (ej. `git log -p`, `git blame`) descargan on-demand → requiere conexión.
- ⚠️ No todos los servidores lo soportan.

---

## 9. Errores frecuentes

### 9.1 "`pre-commit install` pero no corre"

Causas y arreglos:
- No instalado en el PATH: `pip install pre-commit` / `pipx install pre-commit` / `brew install pre-commit`.
- Nunca ejecutaste `pre-commit install` después del clon: hazlo (cada clon).
- `core.hooksPath` apunta a otro lado: `git config --get core.hooksPath`. Resetea o apunta ahí.
- Hook en `.git/hooks/pre-commit` fue reescrito por otra herramienta (Husky, lefthook): escoge una.

### 9.2 "Mi hook pasa local pero el CI falla"

- Versiones de las herramientas difieren → pinnea en `.pre-commit-config.yaml` (siempre).
- Alguien committed sin instalar el hook → corre `pre-commit run --all-files` en CI como gate.

### 9.3 "Clone con submódulos: carpetas vacías"

Olvidaste `--recurse-submodules`. Fix post-hoc:
```bash
git submodule update --init --recursive
```

### 9.4 "`git status` dice `modified content` dentro del submódulo"

Modificaste archivos *dentro* del submódulo pero no committed allí. Entra al submódulo, haz tu commit, luego actualiza el gitlink en el super:
```bash
cd vendor/libfoo
git add . && git commit -m "..."
git push                           # al repo del submódulo
cd ../..
git add vendor/libfoo              # actualiza el gitlink
git commit -m "chore: bump libfoo"
```

### 9.5 "Committed un binario de 500 MB sin LFS"

Si no está pusheado:
```bash
git rm --cached huge.bin
echo "huge.bin" >> .gitignore
git commit --amend --no-edit       # si fue el último commit
```

Si ya está en historia pública: `git lfs migrate import --include="*.bin"` (reescribe historia; coordina) o `git filter-repo --path huge.bin --invert-paths` (destruye el archivo de la historia).

### 9.6 "`git lfs` no está instalado al clonar"

Los archivos LFS aparecen como punteros (texto plano con `oid sha256:...`), no como su contenido real. Fix: instala `git-lfs` (`brew install git-lfs`, `apt install git-lfs`), luego `git lfs install` (una vez por máquina) y `git lfs pull` en el repo.

### 9.7 "`.gitattributes` con `filter=lfs` pero no funciona"

Causas:
- No corriste `git lfs install` nunca → los filtros no están registrados.
- Añadiste el patrón **después** de committear el archivo → el archivo ya está como blob regular. Fix: `git lfs migrate import`.
- Patrón `*.bin` no matchea tu archivo (p.ej. `*.BIN` mayúsculas). Case-sensitive.

### 9.8 "`pre-commit` falla con `An error has occurred: InvalidConfigError`"

El YAML está mal. Valida con `pre-commit validate-config`. Error común: indentación.

---

## 10. Buenas prácticas

- **Versiona tu `.pre-commit-config.yaml`** y haz `pre-commit install` el primer día del clon.
- **Pinnea versiones** (`rev: v4.6.0`, no `HEAD`).
- **Corre `pre-commit run --all-files` en CI**.
- **No pongas hooks que tomen > 2 s** en `pre-commit` (frustra). Movilos a `pre-push` o CI.
- **Hooks de servidor** (si tienes acceso): úsalos como última barrera, no la única.
- **Decide submodule/subtree/monorepo** al principio del proyecto, no "cuando duela".
- **Documenta en el README** cómo clonar: `git clone --recurse-submodules ...`.
- **LFS desde el commit 1** si prevés binarios; migrar después duele.
- **Nunca** commits binarios > 10 MB sin pensar; o LFS o artifact store.
- **Audita el peso** del repo periódicamente con `git-sizer`.
- **No actives `--recurse-submodules` automático** en `git pull` sin tener el flujo claro; sorprende.

---

## 11. Ejercicios recomendados

1. **`activities/01-pre-commit-framework/`** — guided-lab: instalar el framework y configurar 3 hooks útiles (verificado con `pre-commit run --all-files`).
2. **`activities/02-submodule-vs-subtree-tradeoffs/`** — independent (architecture): construir ambos y escribir un ADR comparando.
3. **`activities/03-lfs-setup/`** — guided-lab: configurar LFS para `*.bin` y verificar que el objeto committed es un puntero.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Explica en una frase cada uno:
- `pre-commit` nativo vs framework `pre-commit`
- `pre-receive` vs `post-receive` (lado servidor)
- Submodule vs subtree
- LFS puntero vs blob regular
- Partial clone vs sparse-checkout

**P2.** ¿Por qué `.git/hooks/` **no** se versiona por default? Explica cómo el framework `pre-commit` lo soluciona sin que Git versione `.git/hooks/`.

**P3.** Verdadero / falso:
- [ ] `git clone <url>` trae automáticamente los submódulos.
- [ ] Un subtree aparece en `git ls-tree` como mode `160000`.
- [ ] `git lfs track "*.bin"` después de haber commiteado `foo.bin` convierte retroactivamente el blob en puntero.
- [ ] Los hooks de servidor funcionan en GitHub SaaS.
- [ ] `--filter=blob:none` sin conexión a internet aún funciona para operaciones que ya tienen los blobs necesarios en cache local.

**P4.** Un equipo de 6 personas desarrolla una aplicación web (frontend React + backend Python). Comparten una librería interna `shared-utils` (TypeScript + Python). Diseña y justifica la estrategia: submodule, subtree, monorepo, o paquetes publicados.

**P5.** Tu repo tiene 200 MB porque alguien committed `assets/mascot.psd` (90 MB) y `training-data.npz` (80 MB) hace 2 años. Diseña el plan de remediación: ¿LFS? ¿artifact store? ¿`filter-repo`? Describe pasos y coordinación con el equipo.

**P6.** Escribe un hook `commit-msg` nativo (bash) que rechace mensajes que no empiecen con un tipo Conventional Commits válido. Explica dónde lo pondrías y cómo lo distribuirías al equipo.

**P7.** Dado este `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: HEAD
    hooks:
      - id: ruff
```
Enumera **tres problemas** y arréglalos.

---

## Referencias

- *Pro Git* cap. 7.4 "Git Hooks". <https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks>
- *Pro Git* cap. 7.11 "Submodules". <https://git-scm.com/book/en/v2/Git-Tools-Submodules>
- `githooks(5)`. <https://git-scm.com/docs/githooks>
- `pre-commit` framework. <https://pre-commit.com/>
- `git-submodule(1)`. <https://git-scm.com/docs/git-submodule>
- `git-subtree(1)`. <https://git-scm.com/docs/git-subtree>
- Git LFS. <https://git-lfs.com/> y spec: <https://github.com/git-lfs/git-lfs/tree/main/docs>
- `git-sparse-checkout(1)`. <https://git-scm.com/docs/git-sparse-checkout>
- Partial clone design doc. <https://git-scm.com/docs/partial-clone>
- `git-bundle(1)`. <https://git-scm.com/docs/git-bundle>
- Scalar. <https://git-scm.com/docs/scalar>
- `git-sizer`. <https://github.com/github/git-sizer>
