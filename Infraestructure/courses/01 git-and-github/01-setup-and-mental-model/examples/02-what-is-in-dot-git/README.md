# Ejemplo 02 — Anatomía anotada de `.git/`

## Concepto que demuestra

Qué contiene cada entrada de `.git/` y para qué sirve. Material de **referencia** para consultar; úsalo junto con la actividad `03-explore-dot-git`.

## Mapa anotado

A continuación, la estructura típica de `.git/` tras algunos commits y una rama creada, con una línea por entrada.

```
.git/
├── HEAD                    # Ref simbólico: a qué rama apuntas ahora.
│                           # Ej: "ref: refs/heads/main" (texto plano).
│
├── config                  # Config del REPO (sobreescribe la global ~/.gitconfig).
│                           # Ej: remote.origin.url, branch.main.merge, core.*
│
├── description             # Solo lo usa gitweb; irrelevante en uso normal.
│
├── index                   # Binario. Es el STAGING AREA.
│                           # Serializado como un árbol: nombre + modo + hash + metadata.
│                           # No es "una lista de files marcados" — es un tree.
│
├── packed-refs             # Refs comprimidas (aparece tras `git gc`).
│                           # Ventaja: menos inodos; igual de válido que refs/*.
│
├── hooks/                  # Scripts opcionales que corren en eventos del lado cliente.
│   ├── applypatch-msg.sample
│   ├── commit-msg.sample   # Validar mensajes de commit (p. ej. conventional-commits).
│   ├── fsmonitor-watchman.sample
│   ├── post-update.sample
│   ├── pre-applypatch.sample
│   ├── pre-commit.sample   # Lint, format, tests antes de commit.
│   ├── pre-merge-commit.sample
│   ├── pre-push.sample     # Validar antes de push (secrets scan, etc.).
│   ├── pre-rebase.sample
│   ├── pre-receive.sample
│   ├── prepare-commit-msg.sample
│   ├── push-to-checkout.sample
│   └── update.sample
│
├── info/
│   └── exclude             # Como .gitignore pero LOCAL (no se versiona).
│                           # Útil para ignorar basura de TU editor sin tocar el .gitignore del repo.
│
├── logs/                   # Historial de MOVIMIENTOS de refs y HEAD. Base del `reflog`.
│   ├── HEAD                # Cada vez que HEAD se mueve: commit, checkout, reset, merge...
│   └── refs/
│       └── heads/
│           ├── main        # Cada vez que la ref main se mueve.
│           └── feature     # Idem por rama.
│
├── objects/                # ★ BASE DE DATOS DE OBJETOS. Core de Git.
│   ├── ab/                 # Primeros 2 chars del hash.
│   │   └── cdef0123...     # Los otros 38 chars. Es un blob/tree/commit/tag.
│   ├── pack/               # Objetos empaquetados (comprimidos con deltas internos).
│   │   ├── pack-xxxx.pack  # Datos.
│   │   ├── pack-xxxx.idx   # Índice del pack.
│   │   └── pack-xxxx.rev   # (Git ≥ 2.31) índice reverso.
│   └── info/
│       ├── packs           # Lista de packs.
│       └── alternates      # (opcional) rutas a otras bases de objetos a reutilizar.
│
└── refs/                   # Refs humanas (nombre → hash).
    ├── heads/              # Tus ramas locales.
    │   ├── main
    │   └── feature
    ├── tags/               # Tus tags.
    │   └── v1.0
    ├── remotes/            # Caché local del estado de remotes (tras cada `fetch`).
    │   └── origin/
    │       ├── main
    │       └── HEAD        # Simbólico: a qué rama apunta origin/HEAD.
    └── stash               # (opcional) ref del stash.
```

## Lo esencial a recordar

- **`.git/HEAD`** y **`.git/refs/heads/*`** son **archivos de texto con un hash dentro**. Nada mágico.
- **`.git/objects/`** es toda la historia. Perder esto es perder el repo.
- **`.git/index`** es el staging. Es un *árbol serializado*, no una lista.
- **`.git/logs/`** es el "diario" de movimientos — base del `reflog` (recuperación).
- **`.git/hooks/`** por default solo tiene `.sample` — para activar, quitas la extensión y haces ejecutable. **No se versionan** por default (ver `pre-commit` framework en `gh-11`).
- **`.git/config`** es config del repo; **`~/.gitconfig`** es config global; `/etc/gitconfig` es system.

## Comandos útiles sobre `.git/`

```bash
# Qué apunta HEAD
cat .git/HEAD
git symbolic-ref HEAD

# Hash de la rama actual
git rev-parse HEAD
cat .git/refs/heads/main

# Listar todas las refs
git for-each-ref

# Listar todos los objetos sueltos
find .git/objects -type f | grep -v pack

# Ver qué hay en un objeto por hash
git cat-file -t <hash>   # tipo
git cat-file -p <hash>   # contenido

# Verificar integridad
git fsck

# Compactar (empaqueta objetos sueltos en packfile)
git gc

# Mostrar el reflog de HEAD (basado en logs/HEAD)
git reflog
```

## Qué pasa en cada operación

| Operación | Cambia |
|-----------|--------|
| `git add file` | Crea blob en `objects/`, actualiza `index` |
| `git commit` | Crea tree(s) + commit en `objects/`, mueve `refs/heads/<branch>`, actualiza `HEAD`, append `logs/HEAD` y `logs/refs/heads/<branch>` |
| `git branch feature` | Crea archivo `refs/heads/feature` con el hash actual |
| `git switch feature` | Actualiza `HEAD` (`ref: refs/heads/feature`), actualiza `index` + working tree |
| `git fetch` | Crea objetos en `objects/`, actualiza `refs/remotes/origin/*`, append `logs/refs/remotes/origin/*` |
| `git pull` | `fetch` + `merge/rebase` |
| `git tag v1.0` | Crea `refs/tags/v1.0` (lightweight) o un objeto tag + ref (annotated) |

## Interpretación

Este mapa es tu "diccionario" para los módulos siguientes. Cuando en `gh-10 Recovery and forensics` leas "el reflog está en `logs/HEAD`", sabrás a qué archivo exactamente se refiere.

## Relación con escenarios reales

- Un repo "corrupto" se diagnostica con `git fsck` → te dice qué objeto falta.
- `git gc` ejecuta cuando `objects/` tiene miles de archivos sueltos y buscas aliviar presión en el filesystem.
- `.git/info/exclude` es la vía correcta de ignorar basura **personal** (p. ej. backups del editor) sin tocar el `.gitignore` compartido.
