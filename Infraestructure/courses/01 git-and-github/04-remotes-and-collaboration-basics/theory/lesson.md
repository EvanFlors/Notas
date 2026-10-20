# Lección: Remotes and collaboration basics

> **ID:** `gh-04-remotes-and-collaboration-basics` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `gh-03-branching-and-merging-basics`.

---

## 1. Introducción intuitiva

Hasta aquí Git ha vivido dentro de **un único repo local**: commits, ramas, merges, todo en `.git/`. Pero el mundo real es colaborativo. Dos personas trabajan sobre el mismo código y necesitan intercambiar historia sin pisarse. ¿Cómo lo hace Git?

Si vienes de SVN o CVS esperarías un **servidor central** que es "la verdad" y clientes que lo consultan. Git no funciona así.

En Git **cada clon es un repo completo**, con toda la historia, todas las ramas, todos los objetos. No hay cliente ni servidor en el sentido tradicional: hay repos que se **sincronizan entre sí**. Lo que llamamos "GitHub" o "tu servidor interno" es, para Git, simplemente *otro repo* al que te conectas por red. Esa simetría es el superpoder de Git.

De ahí la palabra: **D**istributed **V**ersion **C**ontrol **S**ystem. Y de ahí la clave operativa que vas a aprender: antes de que *tu* trabajo llegue al repo compartido o viceversa, **tú controlas cuándo moverlo** con `fetch`, `pull` y `push`. Nunca pasa "automágicamente".

El mal hábito más común — `git pull` ciego cada mañana — lo vas a abandonar aquí.

---

## 2. Fundamentos

### 2.1 Un "remote" es un **alias con URL**

Un **remote** en Git no es un servidor, no es una conexión abierta, no es nada "vivo". Es:

```
nombre → URL
```

Que se guarda en `.git/config`:

```ini
[remote "origin"]
    url = /tmp/gh-04-bare/origin.git
    fetch = +refs/heads/*:refs/remotes/origin/*
```

Dos campos:
- **`url`** — dónde está el otro repo (ruta de filesystem, `ssh://`, `https://`, `git://`).
- **`fetch`** — **refspec** que dice qué refs traer y bajo qué prefijo guardarlas localmente.

Puedes tener múltiples remotes:

```bash
git remote -v
# origin    git@github.com:you/project.git (fetch)
# origin    git@github.com:you/project.git (push)
# upstream  git@github.com:original-org/project.git (fetch)
# upstream  git@github.com:original-org/project.git (push)
```

Convención universal:
- **`origin`** = tu copia principal (típicamente tu fork, o el repo del equipo).
- **`upstream`** = el repo "superior" cuando trabajas sobre un fork.

### 2.2 `refs/remotes/<remote>/<branch>` es **tu caché local** del remote

Dentro de tu `.git/`:

```
refs/heads/       ← ramas locales (editables por commits, merges, resets)
refs/remotes/     ← lo que viste del remote la última vez que fetcheaste
refs/tags/        ← tags
```

Cuando haces `git fetch origin`, Git:
1. Se conecta al remote (red o filesystem).
2. Trae objetos nuevos a `.git/objects/`.
3. Actualiza `refs/remotes/origin/*` para que coincidan con las refs del remote.
4. **No toca tus ramas locales**.

Esto es crucial: `origin/main` **no es** "la rama main del servidor en vivo". Es "la posición que main tenía en el server la última vez que ejecutaste `git fetch`". Puede estar desactualizada ahora mismo. Si alguien pusheó algo hace 10 segundos y tú no has fetcheado, tu `origin/main` miente.

Esa es la razón por la que:
- `git log origin/main` es una consulta **100% local** (no hay red).
- `git fetch && git log origin/main` sí refleja el estado actual.

### 2.3 Tracking branches (upstream)

Una **rama local** puede estar *linked* a una **rama remota**: eso se llama **upstream**. Cuando una rama tiene upstream:
- `git status` te dice "ahead/behind N" respecto a ese upstream.
- `git pull` sabe de qué remote traer y qué rama mergear.
- `git push` (sin argumentos) sabe adónde empujar.

Se configura con:

```bash
git push -u origin main              # push + set upstream
git branch --set-upstream-to=origin/main main
```

Y se inspecciona con:

```bash
git branch -vv
# * main 8c3f2a1 [origin/main: ahead 2] feat: add logging
#   dev  1a2b3c4 [origin/dev: behind 5]
```

`[origin/main]` → upstream.
`ahead 2` → tienes 2 commits que `origin/main` no tiene.
`behind 5` → `origin/main` tiene 5 commits que tú no tienes.

### 2.4 Fast-forward: la condición que un push "normal" exige

Cuando pusheas `main` a `origin/main`, Git le pide al remote: "mueve tu `main` del commit X al commit Y". El remote **solo acepta** si X es **ancestro** de Y en el DAG. Es decir: si moverse de X a Y es un **fast-forward** (ningún commit del server se descartaría).

```
Antes (en server):  A ─ B ─ C                (main)
Tú envías:          A ─ B ─ C ─ D ─ E        (main local)
                                 ↑
                     fast-forward: OK
```

Pero:

```
En server:   A ─ B ─ C ─ X        (otro empujó X)
Tú envías:   A ─ B ─ C ─ D        (sin saber de X)
                      ↑
             non-fast-forward: RECHAZADO
```

Mensaje típico:

```
! [rejected]        main -> main (non-fast-forward)
error: failed to push some refs to 'origin'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. Integrate the remote changes (e.g.,
hint: 'git pull ...') before pushing again.
```

Esta protección existe para que **nadie te sobrescriba trabajo** por accidente. Para forzar (destruyendo trabajo del server) existe `--force` y su variante segura `--force-with-lease` (volvemos en §9.5).

---

## 3. Contexto histórico

**BitKeeper (2002–2005).** El kernel de Linux usaba BitKeeper, un DVCS comercial. Cuando BitMover revocó el uso gratuito en 2005, Linus Torvalds escribió Git en pocas semanas con tres objetivos: velocidad, integridad criptográfica y **distribución**. "No central server" era el requisito uno. En ese mundo, cada hacker del kernel pulleaba y empujaba parches directamente entre repos de otros hackers, por correo o por protocolo Git.

**El modelo "fork + pull request" (GitHub, 2008).** GitHub popularizó un patrón sobre Git: tener un repo "central" convencional (el del proyecto) donde todos *leen*, y forks personales donde cada contribuidor *escribe*, con una UI para pedir "integra mi fork al tuyo". Git mismo no tiene concepto de "pull request"; es una construcción social encima del modelo distribuido.

**El servidor como "cualquier repo accesible".** Técnicamente nunca hubo un "Git server" especial. Un bare repo + SSH es un server. GitHub, Gitea, GitLab, Bitbucket, son **mejoras de UX** sobre esa primitiva. Esta lección se queda deliberadamente en la primitiva: entenderla hace que entiendas todos los productos arriba.

---

## 4. Funcionamiento interno

### 4.1 ¿Qué es un **bare** repo?

Un repo normal tiene dos cosas:
- Un **working tree** (los archivos que editas).
- Un directorio `.git/` dentro, con todo el metadato.

Un **bare repo** tiene *solo* el metadato, al nivel de la raíz, sin working tree. Se llama `nombre.git/` por convención:

```
origin.git/
├── HEAD
├── config
├── description
├── hooks/
├── info/
├── objects/
└── refs/
```

Un bare repo es el formato correcto para servidores porque:
- **No puedes commitear en él** (no hay working tree). Solo recibe pushes.
- Es seguro recibir pushes a su rama "actual" (HEAD) sin romper nada: nadie está editando archivos ahí.

En un repo normal, si pusheas a la rama que está checked-out en el remote, Git se queja (porque podrías confundir al dueño del working tree). Por eso los servers usan bare.

Se crea con:

```bash
git init --bare origin.git
```

Y se usa igual que cualquier remote URL (filesystem, SSH, HTTPS).

### 4.2 Protocolos

Un remote URL puede empezar con:

| Prefijo | Protocolo | Uso típico |
|---------|-----------|------------|
| `/ruta/a/repo.git` o `file:///…` | **file** | Local, labs, test, backups rápidos |
| `ssh://user@host/path` o `user@host:path` | **SSH** | Estándar profesional. Autenticación por clave. |
| `https://host/path.git` | **HTTPS** | Firewalls friendly. Auth por token (PAT) o helper. |
| `git://host/path.git` | **git protocol** | Rápido, **sin autenticación ni cifrado**. Solo para espejos públicos. Casi obsoleto. |

**Por qué SSH es el estándar práctico:**
- Autenticación por clave pública (sin contraseña después del setup).
- Cifrado end-to-end.
- Compatible con `git-shell` para limitar a los usuarios a solo operaciones Git en el servidor.
- La máquina server no necesita HTTPS ni certificados web.

HTTPS gana cuando: hay firewalls estrictos que solo dejan pasar 443, o para CI que inyecta un token efímero.

GitHub recomienda **SSH o `gh auth`** para interactivo y **GitHub App installation tokens** para CI (lo verás en `gh-05` y `gh-12`).

### 4.3 Qué viaja en un `fetch` / `push`

En ambos casos, los dos extremos **negocian**:
1. Mi lado dice: "tengo estas refs y estos commits (lista de hashes `want/have`)".
2. El otro lado calcula el **conjunto mínimo de objetos** (commits, trees, blobs) que falta.
3. Los envía como un **packfile** (ya comprimido).

En `fetch` **recibes** objetos y Git actualiza `refs/remotes/<remote>/*`.
En `push` **envías** objetos y, si el server acepta, mueve sus refs.

Nunca viajan "parches de texto": viajan objetos binarios Git. Un repo recibido por fetch es idéntico, byte-por-byte en `.git/objects`, al repo del server.

### 4.4 Refspecs

Un **refspec** le dice a Git "mapea estas refs *del lado remoto* a estas refs *de mi lado*". Formato general:

```
<src>:<dst>
+<src>:<dst>       # el '+' permite non-fast-forward (sobrescribir)
```

Al configurar un remote con `git remote add origin <url>`, Git añade por default:

```
fetch = +refs/heads/*:refs/remotes/origin/*
```

Que lee: "trae todas las ramas del remote (`refs/heads/*`), guárdalas localmente bajo `refs/remotes/origin/*`, y acepta sobrescribir la caché local si cambió" (de ahí el `+`: la **caché** puede saltar hacia atrás si alguien hizo force-push arriba — perfecta refleja el server).

Esto explica también por qué `git push` necesita que digas rama local y rama remota: internamente es un refspec `main:main` ("empuja mi `main` a `main` del remote").

### 4.5 `fetch` vs `pull`

```
fetch = red + actualizar refs/remotes/   (no toca ramas locales)
pull  = fetch + merge  (o rebase, si --rebase o config pull.rebase=true)
```

`pull` es exactamente:

```bash
git fetch origin
git merge origin/<rama-tracking>     # o: git rebase origin/<rama-tracking>
```

El problema del `pull` sin pensar: **cambia tu rama** (puede meter un merge commit, puede crear conflictos, puede rebasar sobre un base inesperado). Fetch nunca te sorprende: te da información y tú decides qué hacer con ella.

**Recomendación general:**
- `git fetch` por default (seguro, siempre informa).
- `git pull --rebase` cuando quieres sincronizar `main` sin crear merge commits.
- `git config --global pull.rebase true` + `git config --global pull.ff only` para que `git pull` falle si no es fast-forward (en vez de hacer algo raro).

### 4.6 `git ls-remote`

Consulta **las refs** de un remote sin fetchear objetos. Útil para scripts y para debug:

```bash
git ls-remote origin
# 8c3f2a1...  HEAD
# 8c3f2a1...  refs/heads/main
# 4f17a0c...  refs/heads/dev
# 2b1a8e3...  refs/tags/v1.0

git ls-remote --heads origin
git ls-remote origin main          # ver solo main
```

Es la operación de red más barata que existe en Git.

---

## 5. Ejemplo mínimo

Setup completo bare + clone + push + fetch, en 60 segundos, sin GitHub.

```bash
# 0. Limpieza
rm -rf /tmp/minimal-remote && mkdir -p /tmp/minimal-remote && cd /tmp/minimal-remote

# 1. Crear el "server": bare repo
git init --bare origin.git
#   origin.git/ es tu "servidor"

# 2. Clonarlo (está vacío, pero es un remote válido)
git clone ./origin.git local
cd local
git -c user.name=Demo -c user.email=demo@example.com commit \
    -q --allow-empty -m "init: empty"

# 3. Pushear (y setear upstream de main a origin/main)
git push -u origin main
#   → crea refs/heads/main en el bare, y refs/remotes/origin/main local

# 4. Simular que "otro" pusheó algo: desde otro clon
cd ..
git clone ./origin.git alice
cd alice
git -c user.name=Alice -c user.email=alice@example.com commit \
    -q --allow-empty -m "feat: alice feature"
git push

# 5. Volver al primer clon y hacer fetch (NO pull)
cd ../local
git fetch origin
#   trae el commit de alice, actualiza refs/remotes/origin/main
#   pero NO toca local/main (sigue en el commit "init")

git status
#   "Your branch is behind 'origin/main' by 1 commit"

git log --oneline --all --graph
#   * <alice-hash> (origin/main) feat: alice feature
#   * <init-hash>  (HEAD -> main) init: empty

# 6. Decidir qué hacer: en este caso, fast-forward es seguro
git merge --ff-only origin/main
#   main avanza al commit de alice; sin merge commit nuevo
```

Dos observaciones clave:
- Antes de `fetch`: tu `origin/main` no sabía nada de Alice.
- Después de `fetch` (sin `pull`): tu rama local sigue intacta, pero *sabes* que estás behind.

Eso es lo que te enseña a confiar en `fetch` como paso 1 siempre.

Limpieza:

```bash
rm -rf /tmp/minimal-remote
```

---

## 6. Implementación progresiva

### 6.1 Crear y gestionar remotes

```bash
# Añadir
git remote add origin ssh://git@server/path/repo.git
git remote add upstream https://github.com/orig/repo.git

# Listar
git remote -v

# Renombrar
git remote rename origin main-remote

# Cambiar URL (p.ej. migrar de HTTPS a SSH)
git remote set-url origin git@github.com:you/repo.git

# Remover
git remote remove upstream

# Inspeccionar
git remote show origin         # URLs, HEAD remota, ramas tracked, estado
```

### 6.2 `git clone` — qué hace realmente

```bash
git clone <url> [<dir>]
```

Internamente:
1. `git init` (crea `.git/`).
2. `git remote add origin <url>`.
3. `git fetch origin` (trae todos los objetos + refs).
4. Checkout de la rama remota default (típicamente `main`).
5. Setea upstream de la rama checked-out a `origin/<esa rama>`.

Opciones útiles:
- `--depth=N` → **shallow clone**, trae solo los últimos N commits (menos espacio; algunas operaciones restringidas).
- `--bare` → clona como bare (sin working tree).
- `--mirror` → como `--bare` pero clona *todas* las refs incluidos remotes y hooks; para espejos exactos.
- `--filter=blob:none` → **partial clone**: trae commits y trees pero sin blobs; los descarga on-demand. Útil para repos enormes (ver `gh-11`).
- `-b <branch>` o `--branch=<tag>` → empieza en una rama/tag específico.

### 6.3 `git fetch` — las variantes útiles

```bash
git fetch                   # fetch del remote del upstream de la rama actual
git fetch origin            # explícito
git fetch --all             # todos los remotes
git fetch --prune           # borrar refs/remotes/origin/<X> si <X> ya no existe en el server
git fetch --tags            # trae también tags que apunten a commits que ya tengas
git fetch origin main:main  # fetch + fast-forward de main local (si está detrás) sin checkout
```

**`--prune` es imprescindible.** Sin él, si borras una rama en el server, tu `.git/refs/remotes/origin/<rama>` persiste como caché zombie para siempre. Puedes dejarlo on por default:

```bash
git config --global fetch.prune true
```

### 6.4 `git pull` — qué pasa exactamente

```bash
git pull                    # = git fetch + git merge <upstream>
git pull --rebase           # = git fetch + git rebase <upstream>
git pull --ff-only          # merge solo si es fast-forward; falla si diverge
```

Configuración recomendada:

```bash
git config --global pull.rebase true    # usar rebase por default
git config --global pull.ff only        # exigir ff si no se rebasa
```

Con eso, `git pull` nunca te sorprende con merges inesperados.

### 6.5 `git push` — las variantes

```bash
git push                                  # push al upstream de la rama actual
git push -u origin main                   # primera vez: setea upstream
git push origin main                      # explícito
git push origin HEAD                      # push de la rama actual al mismo nombre
git push origin feature-x:refs/heads/feat-x   # rename en el push
git push --tags                           # push de tags
git push --delete origin feature-x        # borrar rama remota
git push --force-with-lease               # force seguro (ver §9.5)
```

Config útil:

```bash
git config --global push.default simple   # (default moderno) push solo la rama actual a su upstream del mismo nombre
git config --global push.autoSetupRemote true  # 'git push' nueva rama → crea upstream automáticamente
```

### 6.6 Interpretar `git status` tras `fetch`

Después de `git fetch`, `git status` dirá una de:

- **"Your branch is up to date with 'origin/main'."** → nada que hacer.
- **"Your branch is ahead of 'origin/main' by N commits."** → tienes trabajo local no pusheado. `git push` lo manda.
- **"Your branch is behind 'origin/main' by N commits, and can be fast-forwarded."** → el server avanzó. `git merge --ff-only origin/main` (o `git pull --ff-only`) te pone al día sin merge commit.
- **"Your branch and 'origin/main' have diverged, and have N and M different commits each, respectively."** → ambos avanzaron. Hay que **integrar**: `git rebase origin/main` o `git merge origin/main`. Decisión política del equipo.

Memoriza estos cuatro mensajes y qué acción pide cada uno.

---

## 7. Aplicación profesional

### 7.1 El workflow diario (sin PRs todavía)

```bash
# Mañana: antes de empezar
git fetch --all --prune
git status                      # ¿cómo estoy respecto a origin/main?

# Si estoy limpio y behind: ponerme al día sin merge commit
git pull --rebase
# o: git merge --ff-only origin/main

# Trabajar en una rama de feature
git switch -c feat/widget
# ... commits ...

# Antes de pushear: refrescar origin
git fetch origin
# Rebasar sobre main actualizado para evitar rechazo al pushear
git rebase origin/main
# Primera vez: setear upstream
git push -u origin feat/widget
```

### 7.2 Fork workflow (preview de `gh-07`)

Cuando no tienes write access al repo del proyecto, el patrón es:

```
origin    = tu fork        (push)
upstream  = repo oficial   (fetch; no push)
```

```bash
git clone git@github.com:tu-user/project.git     # te clonas TU fork → origin
cd project
git remote add upstream git@github.com:orig/project.git

# Para sincronizar con upstream:
git fetch upstream
git switch main
git rebase upstream/main
git push origin main            # tu fork avanza
```

### 7.3 Qué va a producción: convenciones

- **Siempre `--prune` en fetch**: ramas borradas en el server deben desaparecer localmente.
- **`pull.rebase=true` + `pull.ff=only`**: nunca `pull` ciego.
- **`--force-with-lease`, nunca `--force`**: evita machacar trabajo ajeno.
- **SSH por default**: menos fricción, más seguro, no revienta con rotación de passwords.
- **Un remote por entorno** cuando los artefactos vivan en otro lado (p.ej. un remote `heroku` para deploy legacy): posible pero poco común con pipelines modernos.
- **Branch protection + required status checks** en el server (lo verás en `gh-12`): la primera línea de defensa real contra pushes malos a `main`.

---

## 8. Trade-offs

### 8.1 `fetch` + `merge`/`rebase` manual vs `pull`

**`pull`**:
- Un comando, menos tipeo.
- Peligroso sin `pull.rebase=true` + `pull.ff=only`: crea merge commits en ramas que querías lineales, o te mete en medio de un merge inesperado.

**`fetch` manual**:
- Dos comandos pero tú ves el estado antes de actuar.
- Enseña a leer "ahead/behind/diverged".
- Práctica recomendada para principiantes de verdad; con config correcta `pull` también sirve.

### 8.2 SSH vs HTTPS

**SSH**:
- Setup inicial (generar clave, subirla al provider).
- Sin passwords después.
- Mejor UX en terminal interactiva.
- Problema: redes con firewalls estrictos pueden bloquear puerto 22.

**HTTPS + token (PAT o `gh auth`)**:
- Funciona en cualquier red (443).
- Tokens expiran — rotación periódica.
- Para CI: ideal (los runners usan tokens efímeros, incluso OIDC).

### 8.3 `--force` vs `--force-with-lease` vs no force

**`--force`**: machaca lo que haya en el server, aunque alguien pusheó entre tu último fetch y tu push → **pierdes trabajo ajeno** sin aviso.

**`--force-with-lease`**: machaca solo si lo que hay en el server es *lo que tú viste* la última vez. Si cambió, falla y te hace fetchear primero.

**No force**: imposible reescribir historia pusheada; obliga a usar `revert` para "deshacer" post-push.

Para ramas de feature propias: `--force-with-lease` tras un rebase está bien.
Para `main`: **no force nunca** (branch protection debe prohibirlo).

### 8.4 `rebase` vs `merge` en `pull`

**`merge` (default histórico)**:
- Historia completa, todos los merges visibles.
- Merge commits "ruidosos" si cada pull crea uno.

**`rebase`**:
- Historia lineal.
- No deja constancia de "aquí sincronicé con el server".
- Reescribe tus commits locales (nuevos hashes). Si no habían salido de tu máquina, inofensivo.

Lo profundizarás en `gh-06`.

### 8.5 Bare vs non-bare como "server"

**Bare**: estándar. Sin working tree, acepta pushes a cualquier rama.
**Non-bare**: funciona como remote pero rechaza push a la rama checked-out por default. No usar como server compartido.

---

## 9. Errores frecuentes

### 9.1 "`git pull` me metió un merge commit raro"

Síntoma: después de `git pull` aparece "Merge branch 'main' of ..." aunque tú no quisiste mergear.

Causa: estabas ahead y behind (diverged) y `pull` hizo merge (default histórico).

Fix inmediato: `git reset --hard ORIG_HEAD` (deshace el merge). Luego:

```bash
git fetch
git rebase origin/main   # (o pull --rebase)
```

Fix permanente: `git config --global pull.rebase true` y `pull.ff only`.

### 9.2 "`git push` fallo con `(non-fast-forward)`"

Significa que el server avanzó desde tu último fetch. Correcto:

```bash
git fetch origin
git rebase origin/main        # o git merge origin/main
git push
```

**No** `git push --force`. Nunca sin leer §8.3.

### 9.3 "`origin/main` dice X pero el server dice Y"

Causa: no has fetcheado desde que alguien pusheó. `origin/main` es caché local.

Fix:

```bash
git fetch origin
```

O más explícito:

```bash
git ls-remote origin main
```

### 9.4 "Borré una rama en el server pero `git branch -r` la sigue mostrando"

Causa: tu caché `refs/remotes/origin/<rama>` sigue existiendo. Fetch normal no la borra.

Fix:

```bash
git fetch --prune
# o: git remote prune origin
```

Permanente: `git config --global fetch.prune true`.

### 9.5 "Hice `rebase` y ahora `git push` me dice non-ff — ¿puedo forzar?"

Caso típico: rebase de **tu rama de feature** sobre un `main` actualizado. Los hashes cambiaron. Para pushearla:

```bash
git push --force-with-lease
```

**Antes verifica**:
- La rama es tuya o nadie más la usa.
- Fetcheaste reciente para que `--force-with-lease` tenga la "lease" correcta.

Nunca hagas esto sobre `main`.

### 9.6 "`git clone` tardó una eternidad y pesa gigas"

Causa: repo con mucha historia + binarios grandes.

Fixes según necesidad:
- `--depth=50` → shallow clone, solo últimos 50 commits.
- `--filter=blob:none` → partial clone (necesita Git ≥ 2.22 y server compatible, p.ej. GitHub).
- Para `main` solamente: `--single-branch --branch main`.

### 9.7 "Pusheé una rama al remote por error"

```bash
git push --delete origin feature/experimento
```

(La rama local sigue intacta.)

### 9.8 "`git fetch` no trae un tag nuevo"

Por default, `git fetch` solo trae tags que apunten a commits que ya estás trayendo. Para traer *todos* los tags del remote:

```bash
git fetch --tags
```

---

## 10. Buenas prácticas

- **Fetch antes de actuar.** `git fetch` + `git status` como primer paso de cada sesión.
- **`pull.rebase=true` + `pull.ff=only`** en tu `~/.gitconfig`.
- **`fetch.prune=true`** siempre.
- **SSH por default** (vas a configurarlo en `gh-05`).
- **`--force-with-lease`, nunca `--force`.**
- **Branch protection sobre `main`** en el server (lo configuras en `gh-12`).
- **Convención `origin`/`upstream`** si trabajas con forks.
- **`git branch -vv`** regularmente, para ver upstreams y drift.
- **Trata `origin/<rama>` como "lo que vi la última vez"**, no como "estado actual del server".
- **Antes de pushear una feature:** `git fetch && git rebase origin/main` para evitar rechazos.
- **Un bare remote local** es excelente para experimentar sin GitHub (y así nunca contaminas repos reales con tests).

---

## 11. Ejercicios recomendados

1. **`activities/01-local-bare-remote/`** — guided-lab: crear un bare remote desde cero, clonar, pushear, fetchear, y leer la caché `refs/remotes/`.
2. **`activities/02-collab-simulation-two-clones/`** — **independent**: simular colaboración Alice/Bob contra un mismo bare remote; interpretar ahead/behind; manejar un push rechazado.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Explica en una frase qué es un **remote** en Git. ¿Es una conexión, un servidor, un proceso, o algo más simple?

**P2.** ¿Qué guarda exactamente `refs/remotes/origin/main` y cuándo se actualiza? ¿Por qué `git log origin/main` no requiere red?

**P3.** Explica, con tus palabras, por qué `git fetch` es **seguro** y `git pull` puede sorprender. Da un ejemplo concreto de sorpresa.

**P4.** Verdadero / falso:
- [ ] Un bare repo tiene working tree pero no `.git/`.
- [ ] `git pull` equivale exactamente a `git fetch` + `git merge`.
- [ ] `origin/main` siempre refleja el estado actual del server.
- [ ] `git push` sin flags empuja todas las ramas.
- [ ] Un push non-fast-forward es rechazado por default.

**P5.** `git status` dice "Your branch and 'origin/main' have diverged, and have 2 and 3 different commits each". ¿Qué significa gráficamente? ¿Qué dos opciones tienes para resolverlo y qué cambia cada una en la historia?

**P6.** Diseña la configuración `~/.gitconfig` que recomendarías por default a un developer júnior para evitar los errores más comunes del módulo. Incluye al menos 4 settings con justificación.

**P7.** Dado el workflow "fork + PR", explica qué deben contener `origin` y `upstream` en el repo local, y la secuencia para traer cambios del repo oficial a tu fork sin crear merge commits.

**P8.** ¿Por qué un push a `main` compartido con `--force` es casi siempre un error? Describe la vía correcta para "deshacer" un commit **ya pusheado** a `main` sin reescribir historia.

---

## Referencias

- *Pro Git* cap. 2.5 "Working with Remotes" y 3.5 "Remote Branches". <https://git-scm.com/book/en/v2>
- `git-remote(1)`, `git-clone(1)`, `git-fetch(1)`, `git-pull(1)`, `git-push(1)`, `git-ls-remote(1)`. <https://git-scm.com/docs>
- `gitprotocol-pack(5)` — protocolo real por detrás del fetch/push. <https://git-scm.com/docs/gitprotocol-pack>
- `gitrevisions(7)` y `gitrefspec` section de `git-fetch(1)`.
- Documentación de bare repositories: `git-init(1)` sección `--bare`.
- GitHub docs — Using Git on the command line (SSH vs HTTPS). <https://docs.github.com/en/get-started/git-basics>
