# Lección: Git internals

> **ID:** `gh-09-git-internals` · **Nivel:** avanzado · **Duración:** 5–6 h
> **Prerrequisitos:** `gh-02-recording-changes`, `gh-06-rebase-vs-merge-and-interactive`.

---

## 1. Introducción intuitiva

Hasta aquí trataste Git como una **caja negra razonable**: `add`, `commit`, `rebase`, `cherry-pick`. Funciona. Pero cuando algo se rompe de verdad —un objeto corrupto, un `rebase` que dejó commits huérfanos, un `push --force` sobre `main`, un repo que crece sin control— los comandos "porcelain" (porcelain = los que usas día a día) te quedan cortos. Entonces aparecen los **plumbing** (plumbing = la "fontanería"): `hash-object`, `cat-file`, `write-tree`, `commit-tree`, `update-ref`, `fsck`, `rev-parse`.

La idea central de este módulo: **un repositorio Git es, por debajo, un almacén key-value de objetos inmutables más un puñado de refs mutables apuntando al grafo**. No hay magia, hay un sistema de archivos con una convención muy estricta. Si entiendes esa convención, puedes:

- Construir un commit sin usar `git commit` ni una sola vez.
- Diagnosticar por qué un `rebase` creó commits distintos aunque "el cambio sea el mismo".
- Recuperar objetos tras una corrupción, un `gc` agresivo, o un `rm -rf` parcial de `.git/`.
- Explicar sin dudar qué hace `commit --amend`, `cherry-pick`, o un `merge --squash` en términos de objetos.

Este módulo es el **cambio de nivel**: después de él Git deja de sorprenderte.

---

## 2. Fundamentos

### 2.1 El object store

Todo lo que Git versiona se guarda como un **objeto** en `.git/objects/`. Hay cuatro tipos:

| Tipo | Contenido lógico | Rol |
|------|------------------|-----|
| `blob` | bytes de un archivo (sin nombre, sin modo) | contenido crudo |
| `tree` | lista ordenada de `(modo, nombre, hash)` | un "directorio" |
| `commit` | `(tree, parent(s), author, committer, mensaje)` | snapshot con metadata |
| `tag`  | ref anotada: `(object, type, tag, tagger, mensaje)` | tag firmado/anotado |

Cada objeto se identifica por el **SHA-1 (hoy con detección anti-colisión `sha1dc`) de su contenido serializado** (`<tipo> <longitud>\0<payload>`). Esto es *content addressing*: dos objetos idénticos ⇒ mismo hash ⇒ se almacenan **una sola vez**.

```
┌──────────────────────────────────────────────────────────────┐
│                       repository (.git/)                     │
│                                                              │
│   objects/        refs/            HEAD                      │
│   ├─ ab/          ├─ heads/        └── "ref: refs/heads/main"│
│   │  └─ cdef..    │  └─ main         (symbolic ref)          │
│   ├─ 12/          └─ tags/                                   │
│   │  └─ 3456..    └─ remotes/                                │
│   ├─ pack/                                                   │
│   │  ├─ pack-xxx.pack                                        │
│   │  └─ pack-xxx.idx                                         │
│   └─ info/                                                   │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Formato on-disk de un objeto suelto (*loose object*)

```
header:  "<type> <size>\0"         # p. ej. "blob 12\0"
payload: <contenido>               # p. ej. "hello world\n"
```

El par header+payload se **zlib-deflatea** y se guarda en:

```
.git/objects/<primeros-2-chars-del-hash>/<resto-del-hash>
```

Ejemplo real: un blob `"hello\n"` tiene hash `ce013625030ba8dba906f756967f9e9ca394464a` → se guarda como `.git/objects/ce/013625030ba8dba906f756967f9e9ca394464a`.

### 2.3 Grafo de referencia entre objetos

Los objetos **se apuntan por hash**, nunca por nombre:

```
commit  ──→  tree  ──→  blob
   │         │
   │         └──→ tree(subdir) ──→ blob, blob...
   ▼
 parent(s) (0, 1 o 2+ para merges)
```

Cambiar **cualquier** byte en un blob cambia el hash del blob → cambia el hash del tree que lo contiene → cambia el hash del commit → cambia el hash de todos sus descendientes. Esta propagación garantiza que la **historia completa esté hasheada**: no puedes editar un commit viejo sin que todos los posteriores también cambien de hash. Esta es la **integridad criptográfica** de Git.

### 2.4 Refs: punteros mutables al grafo

Los objetos son inmutables; las **refs** son archivos de texto que apuntan a un objeto:

```
.git/refs/heads/main           → <hash de un commit>
.git/refs/tags/v1.0            → <hash de un commit o de un tag object>
.git/refs/remotes/origin/main  → <hash del commit cacheado del último fetch>
```

`HEAD` suele ser una **symbolic ref**: en vez de un hash, contiene `ref: refs/heads/main`. Al cambiar de rama (`git switch dev`) solo cambia esta symbolic ref.

Refs se mueven: `git commit` escribe un nuevo commit y actualiza `refs/heads/<rama-actual>` para apuntar a él.

### 2.5 `packfile`: compresión y deltas

Los *loose objects* ocupan mucho (un blob por versión de archivo). `git gc` (o `git repack`) empaqueta objetos relacionados en un **packfile** (`.git/objects/pack/pack-<sha>.pack`) con dos técnicas:

1. **zlib** sobre cada objeto.
2. **Delta compression**: si dos objetos son parecidos (p. ej. dos versiones de un archivo grande), se guarda uno completo y el otro como *delta* contra el primero.

Cada `.pack` se acompaña de un `.idx` (índice) que permite "¿dónde está el objeto `<hash>` dentro del packfile?" en tiempo logarítmico, sin descomprimir todo el pack.

Ventajas: tamaño mucho menor, I/O menor, clone/fetch más baratos. Precio: para leer un objeto delta hay que reconstruirlo desde su base.

### 2.6 `fsck` y la integridad

`git fsck` recorre el grafo desde todas las refs, verifica hashes y conectividad, y reporta:

- Objetos **corruptos** (bytes alterados, hash no coincide).
- Objetos **missing** (referidos por otro objeto pero no presentes).
- Objetos **dangling** (presentes pero no alcanzables desde ninguna ref — candidatos para `gc`).
- Refs **unreachable** desde HEAD.

Es tu herramienta base para diagnosticar "repo roto".

---

## 3. Contexto histórico

- **2005** — Linus Torvalds diseña Git. La decisión temprana: *content addressing* con SHA-1 (en ese momento, SHA-1 era el estándar práctico y rápido). Toda la data model inicial —blobs, trees, commits— es inmutable y hasheada.
- **2005–2008** — Se añade `packfile` cuando queda claro que el repo del kernel con *loose objects* era inviable. El algoritmo de "delta chain" se refina.
- **2017** — Google y CWI publican *SHAttered*: primera colisión práctica para SHA-1 con dos PDFs. Git no se rompe porque el formato de un objeto Git incluye un header `<tipo> <size>\0` que haría que una colisión real con dos payloads de Git distintos sea aún más difícil, pero la alarma suena.
- **2017–2020** — Git implementa `sha1dc` (SHA-1 Detection of Collisions) de Marc Stevens: una variante de SHA-1 que detecta patrones de ataques tipo SHAttered y aborta en vez de producir el hash. Es el default desde entonces.
- **2020** — Git 2.29 introduce **soporte experimental para SHA-256** (`git init --object-format=sha256`). No es default. Interoperabilidad con repos SHA-1 todavía requiere herramientas separadas.
- **2020+** — `git maintenance` (Git 2.29+) ofrece una tarea unificada que agenda `gc`, `commit-graph`, `prefetch`, etc. en background. Reemplaza al clásico `gc.auto`.

Lo relevante hoy:
- **SHA-1 sigue siendo default**. El riesgo criptográfico real para un repo típico es bajo gracias a `sha1dc` y al formato con header.
- **SHA-256 existe pero no es ubicuo**. Interoperabilidad limitada. Útil en nuevos proyectos sensibles a cumplimiento; no para migrar historia existente a la ligera.
- **`git maintenance` es la forma moderna** de mantener un repo saludable sin pensar en `gc` manualmente.

---

## 4. Funcionamiento interno

### 4.1 Construcción de un commit, de abajo hacia arriba

Vamos por los tres plumbing que lo cubren todo:

#### `git hash-object`

Calcula el hash de un contenido tratado como blob. Con `-w` lo **escribe** al object store.

```bash
echo "hello" | git hash-object --stdin -w
# → ce013625030ba8dba906f756967f9e9ca394464a
```

El contenido real pasa por el header convencional: `blob 6\0hello\n`, zlib-deflate, guardado en `.git/objects/ce/01362...`.

#### `git update-index` + `git write-tree`

Para hacer un tree hay dos vías:

**Vía A (realista, usando el index):**
```bash
git update-index --add --cacheinfo 100644,<blob-hash>,<path>
git write-tree
# → imprime el hash del tree construido con las entradas del index
```

**Vía B (más plumbing-puro, sin index):**
```bash
# Formato de mktree: un objeto por línea
#   <mode> SP <type> SP <hash> TAB <name>
printf '%s %s %s\t%s\n' 100644 blob <blob-hash> hello.txt | git mktree
# → imprime el hash del tree
```

#### `git commit-tree`

Dado un tree y 0+ parents, crea un commit:

```bash
echo "initial commit" | git commit-tree <tree-hash>
# → imprime el hash del commit
```

Con parent(s):
```bash
echo "second commit" | git commit-tree <tree-hash> -p <parent-hash>
```

#### `git update-ref`

Mueve una ref para que apunte al commit nuevo:

```bash
git update-ref refs/heads/main <commit-hash>
```

En este punto `git log` ya muestra tu commit. **No se usó `git commit` ni una sola vez.**

### 4.2 Inspección: `cat-file`, `ls-tree`, `rev-parse`

```bash
git cat-file -t <hash>     # tipo del objeto (blob/tree/commit/tag)
git cat-file -s <hash>     # tamaño
git cat-file -p <hash>     # pretty-print del contenido (según tipo)

git ls-tree <tree-hash>    # listar entradas de un tree
git ls-tree -r <tree-hash> # recursivo

git rev-parse HEAD         # resolver una ref a hash
git rev-parse HEAD^{tree}  # el tree del commit en HEAD
git rev-parse HEAD:path/to/file   # el hash del blob de ese archivo en HEAD
```

### 4.3 Qué hace realmente `commit --amend`, `rebase`, `cherry-pick`

Con el modelo de objetos claro, podemos describir cada operación:

**`commit --amend`:**
1. Toma el tree del commit en HEAD (o lo recalcula si hay nuevos cambios staged).
2. Construye un **commit nuevo** `C'` con `(tree', parent = parent(HEAD), author original, committer actual, nuevo mensaje)`.
3. Mueve la ref actual (p. ej. `refs/heads/main`) a `C'`.
4. El commit viejo `C` queda **dangling** (sin ref que lo alcance). Vive hasta que `gc` lo recoja.

**`rebase <base>`:**
1. Para cada commit `C_i` de la rama actual que no esté en `<base>`, Git calcula el *patch* (diff respecto a su parent).
2. Aplica cada patch en orden sobre `<base>`, generando commits nuevos `C_i'`.
3. Cada `C_i'` tiene **tree nuevo** (si hay conflictos o cambios en la base, el tree difiere), **parent nuevo**, **committer nuevo** (timestamp distinto) → **hash distinto**.
4. La ref de la rama se mueve al último commit nuevo. Los commits originales quedan dangling.

Por eso "mismo cambio, hash distinto": author y mensaje pueden ser los mismos, pero `(tree, parent, committer-timestamp)` cambió.

**`cherry-pick <X>`:**
1. Calcula el patch de `X` (diff `X` vs `parent(X)`).
2. Aplica ese patch sobre HEAD.
3. Crea un commit nuevo `X'` con `(tree', parent = HEAD, author del original, committer actual, mensaje del original)`.
4. Mueve la rama actual a `X'`.

El commit original `X` no se toca. Lo que se replica es el **patch**, no el objeto.

### 4.4 Packfiles por dentro

Un packfile es un stream binario:

```
Header: "PACK" + version (4 bytes) + num_objects (4 bytes)
Objetos consecutivos:
  - header con tipo (3 bits) + tamaño (variable-length)
  - payload zlib-deflated
  - si es OFS_DELTA o REF_DELTA: offset o hash del objeto base + delta
Trailer: SHA-1 del packfile
```

El `.idx` paralelo contiene un *fanout* por byte inicial + lista ordenada de hashes + offsets → busca binaria O(log n).

Ver objetos en un pack:
```bash
git verify-pack -v .git/objects/pack/pack-<sha>.idx
```
Imprime cada objeto con tipo, tamaño, offset, tamaño de delta chain, y hash base si es delta.

### 4.5 `fsck`, `gc`, `maintenance`, `prune`

- `git fsck` — verifica integridad; no modifica nada.
- `git gc` — ejecuta `repack` (empaqueta), `prune` (borra loose unreachable con cierta edad), `expire-reflog`, actualiza `commit-graph`. Default: automático según `gc.auto`.
- `git maintenance start` — registra una tarea de systemd/launchd/cron que corre un `gc` incremental periódico sin bloquear.
- `git prune --expire=now` — borra loose objects dangling **ya mismo**. Peligroso: puedes perder trabajo recuperable vía reflog. Normalmente no lo invocas tú.

### 4.6 Alternates: compartir un object store

`.git/objects/info/alternates` es un archivo con rutas a **otros** `objects/` que Git consultará también al buscar un objeto. Casos:

- **Clone shared** (`git clone --shared`): no copia objects, los lee del origen. Ultra rápido, pero si borras el origen pierdes todo.
- **Clone --reference**: mezcla; copia solo lo necesario, lee el resto del repo de referencia.
- **Monorepos con herramientas tipo Scalar/VFS**: usan alternates para capas de caché.

Riesgo: si el object store "padre" desaparece, el repo "hijo" queda **roto para los objetos faltantes**. `git fsck` lo detectará.

---

## 5. Ejemplo mínimo

Construir un commit a mano, sin `git add` ni `git commit`:

```bash
mkdir -p /tmp/plumbing-demo && cd /tmp/plumbing-demo
git init -q -b main
git config user.name  "Plumber"
git config user.email "plumber@example.com"

# 1) Crear un blob a partir de contenido
BLOB=$(echo "hello world" | git hash-object --stdin -w)
echo "blob: $BLOB"

# 2) Construir un tree que contenga ese blob como 'hello.txt'
TREE=$(printf '%s %s %s\t%s\n' 100644 blob "$BLOB" hello.txt | git mktree)
echo "tree: $TREE"

# 3) Construir el commit
COMMIT=$(echo "initial commit (built by plumbing)" | git commit-tree "$TREE")
echo "commit: $COMMIT"

# 4) Mover main a ese commit
git update-ref refs/heads/main "$COMMIT"

# 5) Verificar
git log --oneline
# → <commit> initial commit (built by plumbing)
git cat-file -p "$COMMIT"
# tree <TREE>
# author Plumber <plumber@example.com> ...
# committer Plumber <plumber@example.com> ...
#
# initial commit (built by plumbing)

git ls-tree "$TREE"
# 100644 blob <BLOB>  hello.txt

git cat-file -p "$BLOB"
# hello world
```

Observa que la workspace está **vacía** (`ls` no muestra `hello.txt`). El commit existe en el object store y en la ref, pero el working tree está desactualizado. `git reset --hard HEAD` materializaría el archivo (sincroniza index + working tree desde el tree de HEAD).

Limpieza:
```bash
rm -rf /tmp/plumbing-demo
```

---

## 6. Implementación progresiva

### 6.1 De plumbing a `cat-file -p` como "navegador"

Dado cualquier hash, puedes caminar el grafo:

```bash
# Suponiendo HEAD es el commit del ejemplo anterior
C=$(git rev-parse HEAD)
git cat-file -p "$C"           # ve el commit → extrae el tree
T=$(git rev-parse HEAD^{tree})
git cat-file -p "$T"           # ve el tree → extrae blobs
B=$(git rev-parse HEAD:hello.txt)
git cat-file -p "$B"           # ve el blob (contenido)
```

Este patrón de **"resolver → inspeccionar → extraer siguiente hash"** es *el* skill del módulo.

### 6.2 Reflog como diario de refs

`.git/logs/HEAD` y `.git/logs/refs/heads/<rama>` son archivos de texto append-only. Cada línea:

```
<hash_antes> <hash_despues> <author> <timestamp> <timezone>	<descripcion>
```

Visible con `git reflog`. Es la **red de seguridad** más importante de Git: todo movimiento de HEAD o de una rama local queda registrado durante `gc.reflogExpire` (default 90 días para alcanzables, 30 para unreachable).

### 6.3 Packfiles: ciclo típico

```bash
# Estado 'loose'
find .git/objects -type f | head
.git/objects/ab/cdef...
.git/objects/12/3456...

# Empaquetar
git gc
# Después:
find .git/objects/pack -type f
.git/objects/pack/pack-<sha>.pack
.git/objects/pack/pack-<sha>.idx

# Inspección
git verify-pack -v .git/objects/pack/pack-*.idx | head -20

# Para un repo con mucho churn, mantener saludable:
git maintenance start   # agenda background maintenance
# o manual:
git repack -ad          # repack agresivo
git prune               # con mucha precaución, idealmente a través de gc
```

### 6.4 Diagnóstico con `fsck`

```bash
git fsck --full --unreachable --dangling
```

Reporta:
- `missing <type> <hash>` → un objeto está siendo referido pero no existe. Repo roto.
- `dangling <type> <hash>` → objeto presente, sin ref. Recuperable con `git show <hash>` o `git update-ref` para re-anclarlo.
- `broken link from <A> to <B>` → `A` referencia a `B` y `B` no está.

### 6.5 Recuperación con alternates como fallback

Si tienes **otro clone** del mismo repo (p. ej. un backup, otro dev), puedes añadirlo como alternate temporal para completar objetos faltantes:

```bash
echo "/path/to/backup-clone/.git/objects" > .git/objects/info/alternates
git fsck            # debería dejar de ver missing si el backup los tiene
# cuando termines, borra el archivo:
rm .git/objects/info/alternates
# y copia los objetos permanentemente:
git repack -ad
```

### 6.6 SHA-256 experimental

```bash
git init --object-format=sha256 /tmp/sha256-repo
cd /tmp/sha256-repo
echo "foo" > x && git add x && git commit -m init
git log --format=%H
# → hash de 64 chars (SHA-256) en vez de 40 (SHA-1)
```

Limitaciones (al día de hoy): no interopera trivialmente con repos SHA-1; herramientas, hosts (GitHub, GitLab), hooks y CI pueden no soportarlo plenamente.

---

## 7. Aplicación profesional

### 7.1 Depurar "¿por qué cambió el hash?"

Siempre que una operación "parece benigna" (amend, rebase, cherry-pick, re-aplicar un patch) y el equipo pregunta "¿por qué GitHub muestra un commit nuevo?", la respuesta es la misma: **al menos uno de `(tree, parent, author, committer, mensaje)` cambió**. Mostrar `git cat-file -p <viejo>` vs `git cat-file -p <nuevo>` lado a lado zanja la discusión.

### 7.2 Repo saludable en producción

- **`git maintenance start`** en workstations de developers y en runners de CI con repos grandes.
- **Cron de `git gc --auto`** en servidores Git self-hosted (si no usan maintenance).
- **`git fsck`** como paso diario/semanal en jobs de salud. Un `missing` → alarma inmediata.
- **Backups**: no solo del object store, también de `refs/` y `packed-refs`. Un backup incompleto es tan peligroso como no tener backup.

### 7.3 Repos muy grandes

- **Partial clone** (`--filter=blob:none`): clona commits+trees, descarga blobs on-demand. Mejora clone time 10x+.
- **Sparse checkout**: en el working tree solo materializa un subset de paths. Útil en monorepos.
- **Scalar** (`git-scalar`): bundle de Microsoft con partial clone + sparse + maintenance + fsmonitor preconfigurados.
- **Git LFS**: para blobs grandes (binarios), reemplaza el blob por un puntero y mueve el contenido real a un storage externo. (Se cubre en `gh-11`.)

### 7.4 Supply chain y firma

- La integridad **de contenido** (hashes) la da Git. La integridad **de autoría** la da firmar commits/tags (SSH keys, GPG, Sigstore `gitsign` — `gh-13`).
- `verify-pack` detecta corrupción accidental. **No** sustituye a firma: un atacante que escribe commits válidos puede hacerlos consistentes.
- SHA-256 futuro-proof vs ataques de colisión criptográfica; `sha1dc` mitiga hoy.

---

## 8. Trade-offs

### 8.1 Loose objects vs packfiles

**Loose**:
- Lectura simple (abre un archivo).
- Escritura simple (crea un archivo).
- Mal uso de disco con repos grandes (sin dedup entre versiones similares).

**Packed**:
- Mucho más eficiente (delta chains).
- Lectura más compleja (reconstruir delta).
- Escrituras nuevas van a loose; `gc` las empaqueta después.

Decisión default: Git lo gestiona automáticamente. No intervengas salvo que midas problemas.

### 8.2 `gc.auto` vs `git maintenance`

**`gc.auto`**:
- Clásico. Se dispara durante operaciones (`add`, `commit`, `fetch`) si pasas el umbral.
- Bloquea la operación mientras corre.

**`git maintenance`**:
- Agenda background (systemd/launchd/cron).
- No bloquea comandos interactivos.
- Permite tareas separadas (`gc`, `commit-graph`, `prefetch`).
- Preferido desde Git 2.30+.

### 8.3 SHA-1 vs SHA-256

**SHA-1 (default)**:
- Ubicuo. Herramientas, hosts, hooks lo asumen.
- Riesgo criptográfico mitigado por `sha1dc` + header de objeto.
- No cambia pronto por costes de migración de ecosistema.

**SHA-256 (experimental)**:
- Más seguro.
- Requiere `--object-format=sha256` en `init`. **No migrable in-place** desde SHA-1.
- Interoperabilidad limitada todavía (GitHub tiene soporte parcial).

Decisión: para proyectos existentes, SHA-1. Para proyectos nuevos sensibles (gobierno, finanzas con auditoría criptográfica estricta), evaluar SHA-256 si el ecosistema del equipo lo soporta.

### 8.4 Alternates vs clones completos

**Alternates / `--shared`**:
- Clone instantáneo, cero duplicación de bytes.
- Fragilidad: si el origin se mueve o se borra, hijo se rompe.
- Útil en CI con cache de referencia.

**Clone completo**:
- Independiente, seguro.
- Más disco, más tiempo de clone.
- Default para humanos.

### 8.5 `git prune` manual vs esperar a `gc`

**Manual (`git prune --expire=now`)**:
- Libera disco inmediato.
- **Destruye objetos recuperables por reflog** si tocas también `--expire-reflog-all`.
- Rara vez justificado.

**Confiar en `gc`**:
- Respeta `gc.pruneExpire` y `gc.reflogExpire` (defaults saludables).
- Da red de seguridad por meses.

---

## 9. Errores frecuentes

### 9.1 "`git fsck` reporta `dangling commit`"

No es un error. Son commits sin ref (resultado típico de `--amend`, `rebase`, `reset`). Están ahí **a propósito** por si quieres recuperarlos. Se eliminarán con `gc` cuando pase el tiempo de expiración.

### 9.2 "`git fsck` reporta `missing blob/tree/commit`"

Esto **sí** es grave: la historia está rota. Causas:

- `.git/objects/` fue parcialmente borrado.
- Un disco con sector dañado.
- Alternate roto (el `info/alternates` apunta a un path que ya no existe).
- Clone con `--shared` y luego el origin se movió/borró.

Recuperación:
1. Si tienes otro clone con los objetos: añadir como alternate temporal, hacer `git repack -ad`, borrar alternate.
2. Si es un repo pequeño: `git fetch --all` desde el remoto si lo tienes.
3. Si no hay backup: los objetos están perdidos. Puedes reconstruir la historia desde donde todavía sea alcanzable.

### 9.3 "Hice `rm -rf .git/objects/pack/` para liberar espacio"

Si tenías *loose* duplicados → bien, puedes `fsck` y seguir. Si **no**, acabas de borrar historia. Los objetos solo existían en el pack.

Regla: **nunca** toques `.git/objects/` a mano salvo que entiendas qué estás haciendo.

### 9.4 "El `commit-graph` está corrupto, Git da errores"

```bash
rm .git/objects/info/commit-graph
rm -rf .git/objects/info/commit-graphs/
git commit-graph write --reachable
```

`commit-graph` es una caché; borrarla no destruye nada.

### 9.5 "Un `git commit --amend` cambió el hash y rompió los links de un PR"

Comportamiento esperado: amend = commit nuevo (sección 4.3). Si trabajas con PRs ya revisados, usa commits "fixup" + rebase final o acepta la nueva historia + `--force-with-lease`.

### 9.6 "Confundí `git prune` con `git prune-packed`"

- `git prune` → **borra loose unreachable** (destructivo si no cuidas reflog).
- `git prune-packed` → borra loose que ya están **también** en un pack (completamente seguro).

### 9.7 "Reporto SHA-1 colisión con dos archivos"

Si Git fue compilado con `sha1dc` (default moderno) e intenta hashear uno de los patrones conocidos de ataque, aborta con un error claro. Si tu Git es antiguo, actualiza.

### 9.8 "`git cat-file -p` sobre un tag anotado me da el commit"

Para un tag **anotado** (objeto tipo `tag`), hay dos capas:
- El objeto `tag` (apunta a un commit).
- El commit en sí.

Usa:
```bash
git cat-file -t v1.0   # tag
git cat-file -p v1.0   # pretty-print del tag (muestra tagger, mensaje, object)
git rev-parse v1.0^{commit}   # fuerza a resolver al commit
```

Tags **ligeros** (lightweight) no son objetos: son simples refs apuntando directo al commit.

---

## 10. Buenas prácticas

- **Memoriza los 4 tipos de objeto** y la relación entre ellos. Es la base de todo.
- **`git cat-file -p` es tu microscopio.** Úsalo cada vez que algo "parece raro".
- **Antes de ejecutar `git prune`, piensa dos veces.** El `gc` default basta.
- **`git fsck --full` periódicamente** en repos críticos.
- **`git maintenance start`** en workstations con repos grandes.
- **No toques `.git/objects/` a mano**, salvo copias de seguridad.
- **Hash corto (7–8 chars) para humanos, hash largo para scripts.** `git rev-parse --short` controla el prefix si usas corto en pipelines.
- **Siempre que una operación cambie un hash y te sorprenda**, pregúntate cuál de `(tree, parent, author, committer, mensaje)` cambió. La respuesta siempre está ahí.
- **Backups del repo = backup del `objects/` + `refs/` + `packed-refs` + `HEAD`.** Preferible: `git clone --mirror`.

---

## 11. Ejercicios recomendados

1. **`activities/01-commit-from-scratch-plumbing/`** — guided-lab: construye un commit (y uno encima) usando únicamente `hash-object`, `mktree`, `commit-tree`, `update-ref`. Verificable automáticamente.
2. **`activities/02-fsck-a-broken-repo/`** — **independent**: te entregan un repo con un objeto faltante. Diagnostica con `fsck` y recupera usando alternates/reflog/cherry-pick.

Antes, reproduce ambos **examples**:

- `examples/01-build-commit-by-hand/` — recorrido completo del plumbing.
- `examples/02-inspect-packfile/` — `verify-pack` + lectura del packfile de un repo real.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Describe los **4 tipos de objeto** en Git. Para cada uno: qué contiene y cómo apunta a los otros.

**P2.** Un commit tiene 5 "campos" que determinan su hash. Enuméralos. Ahora explica, para cada operación, cuál(es) cambia(n) respecto al commit "original":

- `git commit --amend --no-edit`.
- `git commit --amend` (nuevo mensaje).
- `git rebase <base>` moviendo un commit a una nueva base.
- `git cherry-pick <X>` en otra rama.

**P3.** Verdadero / falso:
- [ ] Dos blobs con contenido idéntico pero nombres distintos tienen hash distinto.
- [ ] Un tree conoce los nombres de los archivos que contiene.
- [ ] `git prune-packed` puede destruir trabajo recuperable del reflog.
- [ ] `git fsck` modifica el repo.
- [ ] `HEAD` es siempre una symbolic ref.
- [ ] Los commits en un packfile son más compactos por delta compression.

**P4.** Dado este tree:
```
100644 blob abcdef1  README.md
100755 blob 1234567  deploy.sh
040000 tree 7777777  src
```
Explica qué significa cada entrada (modo + tipo + hash + nombre) y por qué el modo del `.sh` es distinto al del `.md`.

**P5.** Construye mentalmente los comandos de plumbing para crear un commit con un solo archivo `greeting.txt` cuyo contenido sea `"hola\n"`, con mensaje "init". Lista los pasos y los comandos (`hash-object`, `mktree`, `commit-tree`, `update-ref`).

**P6.** `git fsck` reporta:
```
missing blob 1234abcd...
broken link from commit 5678ef... to blob 1234abcd...
```
Hay otro desarrollador en el equipo con un clone sano. Describe la estrategia de recuperación (sin consultar la lección), incluyendo el uso de `alternates`.

**P7.** Un colega ejecutó `git maintenance start` en su laptop y pregunta "¿qué hace esto exactamente?". Responde en 3 frases distinguiéndolo de `gc.auto`.

**P8.** Explica por qué, aunque SHA-1 ya tiene colisiones conocidas, Git sigue siendo *razonablemente* seguro para integridad en 2026. Menciona `sha1dc` y el header de objeto.

---

## Referencias

- *Pro Git* cap. 10 "Git Internals". <https://git-scm.com/book/en/v2>
- `git-hash-object(1)`, `git-cat-file(1)`, `git-mktree(1)`, `git-commit-tree(1)`, `git-update-ref(1)`, `git-ls-tree(1)`, `git-rev-parse(1)`. <https://git-scm.com/docs>
- `git-fsck(1)`, `git-gc(1)`, `git-prune(1)`, `git-maintenance(1)`, `git-verify-pack(1)`. <https://git-scm.com/docs>
- `gitrepository-layout(5)`. <https://git-scm.com/docs/gitrepository-layout>
- Marc Stevens et al. *SHAttered* (2017). <https://shattered.io/>
- `sha1dc` upstream. <https://github.com/cr-marcstevens/sha1collisiondetection>
- Git SHA-256 object format transition plan. <https://git-scm.com/docs/hash-function-transition>
- Scalar (microsoft). <https://github.com/microsoft/scalar>
