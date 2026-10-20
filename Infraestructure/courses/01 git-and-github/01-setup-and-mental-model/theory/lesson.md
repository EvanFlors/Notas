# Lección: Setup y modelo mental de Git

> **ID:** `gh-01-setup-and-mental-model` · **Nivel:** fundamentos · **Duración:** 3–4 h
> **Prerrequisitos:** línea de comandos.

---

## 1. Introducción intuitiva

Imagina trabajar en un documento importante. Al principio llamas al archivo `informe.md`. Cambias cosas. Te asusta perder lo anterior y copias el archivo a `informe-v2.md`. Más cambios: `informe-v3-final.md`. Un cambio más: `informe-v3-final-FINAL.md`. Tu compañera manda cambios por email: `informe-anita.md`. Alguien pide volver "al estado de antes del gráfico": nadie sabe cuál era.

Este es el problema que resuelve el **control de versiones**: un sistema que recuerda *todos* los estados del proyecto, atribuye cada cambio a alguien, y permite moverse entre ellos sin perder nada. No para texto plano solo — para código, infraestructura, configuración, documentación, cualquier cosa escrita.

Hay dos familias históricas:

- **Centralizados (CVS, Subversion):** hay *un* servidor que guarda la historia; los clientes "piden permiso" para hacer cambios.
- **Distribuidos (DVCS):** cada clon tiene la historia *completa*. No hay un "servidor privilegiado" técnicamente; hay convenciones (p. ej. "este clon en GitHub es el oficial").

**Git** es el DVCS que ganó. En este módulo construyes su modelo mental correcto: no es "SVN con nombres distintos", es un sistema que piensa diferente.

---

## 2. Fundamentos

Antes de instalarlo, tres ideas que necesitas tener claras:

### 2.1 Hashing de contenido

Un **hash criptográfico** toma datos de tamaño arbitrario y produce una cadena fija (en Git clásico, 40 caracteres hex: SHA-1). Dos propiedades clave:

- **Determinista**: el mismo contenido produce siempre el mismo hash.
- **Resistente a colisiones**: en la práctica, dos contenidos distintos no comparten hash.

Entonces: si identificas tu archivo *por el hash de su contenido*, el nombre "`informe.md`" se vuelve irrelevante — lo que importa es el *contenido*. Si cambia una coma, el hash cambia; si no cambia, el hash es idéntico aunque pasen años.

Esto se llama **content-addressable storage** y es la base de Git.

> Nota: SHA-1 criptográficamente está roto para ataques intencionados; Git mitiga con detección anti-colisión (`sha1dc`) y soporta SHA-256 experimental desde 2020. Para operación normal, no te afecta hoy.

### 2.2 Snapshots vs deltas

Un CVS tradicional guarda **diferencias** (deltas) entre versiones: "en v3, línea 42 cambió de X a Y". Reconstruir una versión requiere aplicar la cadena.

Git guarda **snapshots completos**. Cuando haces un commit, Git conceptualmente guarda una foto del árbol entero. Si un archivo no cambió desde el commit anterior, Git simplemente *reutiliza el hash* del snapshot anterior — no hay delta, hay referencia.

Esto hace que operaciones como "muéstrame el estado de hace 50 commits" sean *una lectura*, no una reconstrucción.

(Para eficiencia en disco, Git luego comprime objetos duplicados y usa **packfiles** con deltas internos. Pero el modelo *lógico* son snapshots.)

### 2.3 Grafo acíclico dirigido (DAG)

Cada commit apunta a su **padre** (o padres, si es un merge). Los commits forman un **DAG**: una línea cuando el trabajo es lineal, un grafo cuando hay ramas y merges.

```
A ─── B ─── C ─── D
             \
              E ─── F
```

No es una "lista" ni un "árbol" — es un grafo. "Historia" significa "recorrer el DAG hacia atrás desde un commit".

Memoriza estas tres ideas: **hash de contenido**, **snapshots**, **DAG de commits**. Son toda la ingeniería de Git.

---

## 3. Contexto histórico

Hasta 2005 el kernel de Linux se desarrollaba con **BitKeeper**, un DVCS propietario que la empresa dueña ofrecía gratis a open source bajo ciertas condiciones. En abril de 2005 esas condiciones se retiraron. Linus Torvalds tenía dos opciones: aceptar un VCS centralizado (lento, inviable para ~1000 colaboradores distribuidos) o escribir uno nuevo. Escribió uno nuevo en diez días. Lo llamó **Git**.

Los objetivos de diseño declarados por Linus fueron:

1. **Rápido** (no "quizás rápido" — rápido).
2. **Distribuido** (operar sin red; cada clon es un repositorio completo).
3. **Integridad criptográfica** (poder detectar corrupción o manipulación).
4. **Soporte nativo para desarrollo no-lineal** (muchas ramas en paralelo).

El resto es consecuencia: hash de contenido viene de (3); operación offline viene de (2); DAG viene de (4). "Fácil de usar" **no** era un objetivo — y se nota hasta hoy, por eso existen frontends como Jujutsu (`jj`).

GitHub (2008) no inventó Git; lo *hospedó* y le añadió una capa social (Pull Requests, issues, discussions). Ambos son cosas distintas, aprendidas distintas, elegidas distintas.

---

## 4. Funcionamiento interno

Cuando ejecutas `git init`, Git crea un directorio oculto `.git/` que **es** el repositorio. El resto de archivos del proyecto son el **working tree** (los archivos que ves y editas).

### 4.1 Las tres áreas

Siempre que trabajas con Git hay tres áreas lógicas:

```
┌──────────────┐   git add    ┌─────────────┐   git commit   ┌──────────────┐
│ working tree │ ───────────> │   index     │ ─────────────> │ repository   │
│ (lo que ves) │              │ (staging)   │                │ (.git/)      │
└──────────────┘              └─────────────┘                └──────────────┘
          ^                                                           │
          │                       git checkout / restore              │
          └───────────────────────────────────────────────────────────┘
```

- **Working tree**: archivos que puedes editar normalmente.
- **Index (staging area)**: una zona intermedia donde preparas el *próximo* commit. Es técnicamente un árbol serializado — no un simple "lista de archivos marcados".
- **Repository**: la base de datos de objetos en `.git/`.

`git add` mueve contenido del working tree al index. `git commit` toma lo que está en el index y crea un objeto commit en el repository.

### 4.2 Los cuatro objetos

Dentro de `.git/objects/` Git guarda cuatro tipos de objeto, cada uno identificado por el hash de su contenido:

- **`blob`** — el contenido de un archivo. Solo bytes; no tiene nombre.
- **`tree`** — un directorio. Contiene una lista `(modo, nombre, hash)` que apunta a `blob`s (archivos) y a otros `tree`s (subdirectorios).
- **`commit`** — un snapshot con metadata. Contiene: hash del `tree` raíz, hash(es) del commit padre(s), autor, committer, mensaje.
- **`tag`** — una referencia nombrada con metadata (anotada).

Un commit **no** contiene archivos directamente. Contiene **un hash de tree**, que contiene hashes de blobs y de subtrees. Es un grafo tipado.

```
commit (abcd...)
  tree: 1234...
  parent: 9999...
  author: ...
  message: "..."
       │
       ▼
tree (1234...)
  100644 blob 5678... README.md
  040000 tree 7890... src/
       │                 │
       ▼                 ▼
   blob (5678...)   tree (7890...)
   "contenido         100644 blob def0... main.py
    del README"
```

### 4.3 Las referencias (refs)

Un hash de 40 caracteres no se memoriza. Las **refs** son nombres humanos que apuntan a un commit:

- **`refs/heads/<branch>`** — una rama (ej. `refs/heads/main`).
- **`refs/tags/<name>`** — un tag.
- **`refs/remotes/<remote>/<branch>`** — qué sabemos del remoto (caché local).
- **`HEAD`** — "dónde estás ahora". Casi siempre apunta a una rama (symbolic ref), no a un commit directo.

Mover una rama es **cambiar el valor de un archivo** en `refs/heads/`. Nada mágico.

### 4.4 Qué hay en `.git/` tras `init`

```
.git/
├── HEAD                  # ref simbólico (ej. "ref: refs/heads/main")
├── config                # config local del repo
├── description           # descripción (solo usada por gitweb)
├── hooks/                # scripts opcionales que corren en eventos
│   └── *.sample
├── info/
│   └── exclude           # ignores locales no versionados
├── objects/              # la base de datos de objetos
│   ├── info/
│   └── pack/
└── refs/
    ├── heads/            # tus ramas
    └── tags/             # tus tags
```

Al principio `objects/` está casi vacío. A medida que trabajas, aparecen directorios de dos letras (los primeros dos del hash) que contienen los objetos restantes.

### 4.5 Packfiles

Si guardaras un objeto por archivo para cada commit, un repo grande sería un desastre de I/O. Git periódicamente ejecuta **`git gc`** (garbage collection) que empaqueta objetos sueltos en **packfiles** comprimidos con deltas internos. Es optimización de almacenamiento — el modelo lógico no cambia.

---

## 5. Ejemplo mínimo

Vamos a crear un repo y observar objetos aparecer. Reproducible en cualquier Linux/macOS con Git.

```bash
# 1. Preparar
mkdir /tmp/git-demo && cd /tmp/git-demo
git init
# -> Initialized empty Git repository in /tmp/git-demo/.git/

# 2. Mirar .git/
ls .git/
# HEAD, config, description, hooks, info, objects, refs

cat .git/HEAD
# ref: refs/heads/main    (o 'master' en versiones viejas)

ls .git/objects/
# info  pack        (vacío, todavía no hay objetos)

# 3. Crear un archivo
echo "Hola, Git" > saludo.txt
git status
# Untracked files:  saludo.txt

# 4. Añadir al index
git add saludo.txt

ls .git/objects/
# aparece un directorio nuevo de 2 letras
# -> ese es el blob del contenido de saludo.txt

# 5. Ver qué objeto se creó
git hash-object saludo.txt
# imprime el hash (p. ej. 1b5f...)

git cat-file -t 1b5f    # con los primeros caracteres basta
# blob

git cat-file -p 1b5f
# Hola, Git
```

Hasta aquí: **tienes un blob en la base de objetos**, pero *no* un commit. El contenido existe; nadie dice "este contenido pertenece a *saludo.txt*" ni "en este momento". Eso lo hace el commit.

```bash
# 6. Primer commit
git -c user.name=Demo -c user.email=demo@example.com commit -m "primer commit"
# [main (root-commit) <hash>] primer commit

git log --oneline
# <hash> primer commit
```

Ahora `.git/objects/` tiene **tres** objetos: el blob (saludo), un tree (que dice "`saludo.txt` → blob 1b5f"), y un commit (que apunta al tree, metadata).

```bash
# 7. Explorar lo que se creó
git log --format='%H' -n1
# <commit-hash>

git cat-file -p <commit-hash>
# tree <tree-hash>
# author Demo <demo@example.com> ...
# committer Demo <demo@example.com> ...
#
# primer commit

git cat-file -p <tree-hash>
# 100644 blob <blob-hash>    saludo.txt

cat .git/refs/heads/main
# <commit-hash>  <-- la rama "main" es LITERALMENTE un archivo con un hash dentro
```

Léelo despacio. Es todo lo que es un repositorio Git: una base de datos de objetos content-addressable, con refs que son archivos con hashes dentro.

---

## 6. Implementación progresiva

Añadamos un segundo commit y veamos qué cambia.

```bash
echo "Segunda línea" >> saludo.txt
git add saludo.txt
git -c user.name=Demo -c user.email=demo@example.com commit -m "añade segunda línea"

git log --oneline
# <hash2> añade segunda línea
# <hash1> primer commit

cat .git/refs/heads/main
# <hash2>  <-- cambió al nuevo commit
```

`.git/refs/heads/main` ahora apunta al commit 2. El commit 2 tiene `parent: hash1`. Si recorres hacia atrás, llegas al commit 1. Eso es "la historia".

Añadamos un segundo archivo y veamos el tree.

```bash
mkdir docs
echo "notas" > docs/notas.txt
git add docs/notas.txt
git -c user.name=Demo -c user.email=demo@example.com commit -m "agrega docs/notas.txt"

# Ver el tree del último commit
git cat-file -p HEAD^{tree}
# 040000 tree <hash-subtree-docs>    docs
# 100644 blob <hash-saludo>          saludo.txt

# Y el subtree
git cat-file -p <hash-subtree-docs>
# 100644 blob <hash-notas>    notas.txt
```

El árbol es recursivo: trees anidados que terminan en blobs. Exactamente como un filesystem.

Ahora `git log --graph --oneline`:

```
* <hash3> agrega docs/notas.txt
* <hash2> añade segunda línea
* <hash1> primer commit
```

Lineal — porque no has creado ramas. Más adelante (`gh-03`) verás este grafo bifurcarse.

---

## 7. Aplicación profesional

En el día a día no haces `cat-file`. Haces `git status`, `git add`, `git commit`, `git log`, `git diff`. Pero *saber* que debajo hay blobs, trees, commits y refs te permite:

- **Diagnosticar** cualquier error (`fatal: not a git repository`, "detached HEAD", "ambiguous ref").
- **Recuperar** trabajo "perdido" (los commits viven en `.git/objects/` aunque la ref ya no los apunte — `reflog` existe gracias a esto; se cubre en `gh-10`).
- **Operar** correctamente con remotes: entender que `origin/main` es *tu caché local* del remoto, no "el remoto".
- **No tenerle miedo** a `.git/`. Es tu amigo, no magia.

### 7.1 Configuración global sana (2026)

Antes de hacer cualquier otra cosa en una máquina nueva, configura Git globalmente. Esto es "**una vez por laptop**", no por repo.

```bash
# Identidad — obligatorio
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"

# Default branch moderno
git config --global init.defaultBranch main

# Pull sin sorpresas (rebase, no merge; evita merge commits ruidosos)
git config --global pull.rebase true

# Push de la rama actual (no "matching", no sorpresas)
git config --global push.default simple
git config --global push.autoSetupRemote true

# Line endings (importante en equipos mixtos Linux/Mac/Windows)
#   Linux/Mac:
git config --global core.autocrlf input
#   Windows:
# git config --global core.autocrlf true

# Editor (ejemplos)
git config --global core.editor "nano"
# o:  "code --wait", "vim", "emacs"

# Mejor UI de diff y color
git config --global color.ui auto

# Rebase + stash autom. al pull con cambios locales
git config --global rebase.autoStash true

# Credential helper
#   macOS:    git config --global credential.helper osxkeychain
#   Linux:    git config --global credential.helper libsecret   # o cache
#   Windows:  git config --global credential.helper manager
```

Verificar:
```bash
git config --global --list
# o leer el archivo:
cat ~/.gitconfig
```

### 7.2 Flujo diario (vista aérea)

En equipo profesional, el flujo típico será (lo cubriremos en módulos siguientes):

1. `git pull --rebase` → trae cambios y rebasa los tuyos encima.
2. Editas, pruebas localmente.
3. `git add -p` → añades por hunks, no masivo.
4. `git commit -m "fix: ..."` → commits atómicos con mensaje significativo.
5. `git push` → envías tu rama.
6. Abres Pull Request.

Nada de esto tiene magia: cada paso toca objects/, refs/, index como se explicó arriba.

---

## 8. Trade-offs

### 8.1 Git vs centralizados (SVN, CVS, Perforce)

| Dimensión | Git | SVN / centralizados |
|-----------|-----|----------------------|
| Historia offline | Sí (clon completo) | No (necesitas servidor) |
| Branching barato | Sí (crear rama = 40 bytes) | Caro operacionalmente |
| Blobs binarios enormes | Mal (sin LFS) | A veces mejor (Perforce excelente aquí) |
| Permisos granulares | Débil (todo-o-nada por repo) | Fuerte (por path) |
| Curva de aprendizaje | Dura | Más suave |
| Mercado 2026 | Universal | Residual |

Si no estás en un contexto *extremo* (binarios muy grandes, compliance de permisos por path), Git es la elección por default. Perforce sigue vivo en gaming y hardware; SVN en código mayormente legacy.

### 8.2 Git vs otros DVCS

- **Mercurial (`hg`)**: diseño más limpio, UX más coherente, en declive por adopción de Git. Si entras a un proyecto `hg` existente, aprenderás; para nuevo, Git.
- **Fossil**: todo-en-uno (SCM + wiki + tickets + forum). Nicho, SQLite backend.
- **Jujutsu (`jj`)**: *frontend* moderno sobre repos Git. Modelo mental más limpio ("undo" como primera clase). Comparte base de datos con Git — puedes migrar sin perder nada. Muy prometedor, aún no mainstream.

### 8.3 Decisiones de configuración frecuentes

- `pull.rebase=true` vs `false`: casi siempre `true` para evitar merge commits ruidosos. En algunos equipos se prefiere merge por trazabilidad; es una decisión *de equipo*, no personal.
- `init.defaultBranch=main` vs `master`: `main` es el default moderno. Repos nuevos deben usar `main`; repos legacy pueden quedarse en `master`.
- `core.autocrlf`: Linux/macOS `input`, Windows `true`. Equivocarse genera diffs enormes de líneas vacías. Un `.gitattributes` del repo suele ser mejor que configuración por usuario.

---

## 9. Errores frecuentes

### 9.1 "Please tell me who you are"

```
*** Please tell me who you are.
Run
  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"
```

Olvidaste configurar identidad global. Resolución: ejecuta los comandos.

### 9.2 Commits con autor "root@hostname"

Resultado del mismo olvido en entornos de CI o VMs. En producción, el commit queda con un autor sin sentido. Verifica siempre `git log --format='%an <%ae>' -n1` al configurar un entorno nuevo.

### 9.3 Mensajes vacíos / "update"

Un commit es un mensaje para tu yo-del-futuro y para colegas. "update" no comunica nada. Para este módulo basta "primer commit" (es literalmente eso); en módulos siguientes verás *Conventional Commits* y por qué.

### 9.4 Pull con merge inesperado

Si no fijas `pull.rebase=true`, un `git pull` cuando hay cambios locales **y** remotos crea un merge commit automático. Rápidamente la historia se vuelve un espagueti de "Merge branch 'main' of ...". Se corrige al principio y evitas años de ruido.

### 9.5 Credenciales que piden contraseña en cada push

Si no configuras un credential helper, cada push HTTPS pedirá usuario+token. Con credential helper del SO, se guarda una vez. (Alternativa superior: SSH key.)

### 9.6 Confundir "no hay nada en `.git/objects/`" con "repo roto"

Un repo recién inicializado tiene `.git/objects/{info,pack}` vacíos. Es correcto. Los objetos aparecen con el primer `git add`.

---

## 10. Buenas prácticas

- **Configura `git config --global` el primer día de cada máquina nueva.** Es una decisión que repercute por años.
- **Un commit = una idea.** Si el mensaje tiene un "y" ("añade X **y** arregla Y"), probablemente son dos commits.
- **Mensajes en imperativo, presente, 50 caracteres línea 1.** `add logging to parser` → sí. `added logging stuff` → no.
- **Lee `.git/HEAD` y `.git/refs/heads/main` al principio.** Son dos `cat`s. Internalizarán el modelo mental.
- **Experimenta en `/tmp/`** — un repo de juguete no cuesta nada y acelera el aprendizaje.
- **No tengas miedo de `cat-file`.** Es el `strace` de Git.
- **Un credential helper correcto**: nunca copies/pegues tokens repetidamente.
- **SSH key o `gh auth login`** desde el día uno (se cubre en `gh-05`), para evitar fricción.
- **No alias cuando no entiendes el comando original.** `git co` para `checkout` *después* de entender `checkout`.

---

## 11. Ejercicios recomendados

1. **`activities/01-config-personal/`** — deja tu Git configurado profesionalmente. Guided-lab.
2. **`activities/02-first-commits/`** — ciclo completo observando objetos. Guided-lab.
3. **`activities/03-explore-dot-git/`** — mapear `.git/` y explicar cada entrada. **Independent** — necesaria para validar comprensión.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Un commit, en Git, contiene (marca todo lo que aplique):
   - [ ] Los archivos del snapshot, bytes a bytes.
   - [ ] Un hash de un `tree`.
   - [ ] Uno o más hashes de commits padre.
   - [ ] Metadatos de autor y committer.
   - [ ] El mensaje.
   - [ ] Un diff respecto al commit anterior.

**P2.** Explica en 2–3 frases por qué `git add` crea un objeto en `.git/objects/` pero `git commit` crea *más de uno*. (Pista: piensa qué tipos de objeto.)

**P3.** `.git/refs/heads/main` es:
   - [ ] Un directorio con todos los commits de la rama.
   - [ ] Un archivo que contiene un hash.
   - [ ] Una base de datos SQLite.
   - [ ] Una symlink a HEAD.

**P4.** Verdadero / falso:
   - [ ] Un commit en Git siempre tiene exactamente un padre.
   - [ ] Dos ramas pueden apuntar al mismo commit.
   - [ ] `HEAD` normalmente apunta directamente a un commit.
   - [ ] Dos archivos con el mismo contenido producen dos blobs distintos.

**P5.** Un compañero dice "cada commit guarda solo las diferencias desde el commit anterior, por eso Git es tan compacto". ¿Qué le respondes, con precisión?

**P6.** Explica el ciclo `editar → add → commit` en términos de **las tres áreas** y **los objetos** que se crean en cada paso.

**P7.** Diseño: en una máquina nueva de un developer que trabajará en Linux y hará commits a repos compartidos con Windows, ¿qué 5 configuraciones globales de Git priorizarías y por qué?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Pro Git book*, 2nd ed., cap. 1 y 2 (Scott Chacon, Ben Straub). <https://git-scm.com/book/en/v2>
- *Pro Git book*, cap. 10 "Git Internals". <https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain>
- Referencia de `git config`. <https://git-scm.com/docs/git-config>
- Referencia de `git init`, `git add`, `git commit`, `git log`. <https://git-scm.com/docs>
- Git Hashes (SHA-1 → SHA-256 transition). <https://git-scm.com/docs/hash-function-transition>

Lectura complementaria:

- Chacon/Straub, *Pro Git* cap. 10.2 "Git Objects" — leer entera.
- Repositorio `git/git` en GitHub, `Documentation/technical/` para quien quiera ir más adentro.
