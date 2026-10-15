# Actividad 01 — Commit desde cero con plumbing

## 1. Identificación

- **ID:** `gh-09-01-commit-from-scratch-plumbing`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-09-git-internals`
- **Dificultad:** advanced
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Tu colega te explica orgullosa que acaba de "crear commits sin usar `git commit` ni una sola vez". Suena a flexing innecesario, pero cuando le dices "¿y para qué?" responde: *"para entender qué hace realmente `git commit`, porque la semana pasada un hook del servidor estaba creando commits sintéticos y nadie en el equipo sabía por qué los hashes 'nunca cuadraban'"*.

En esta actividad vas a hacer lo mismo. Al terminar sabrás exactamente qué pasa debajo del porcelain.

## 3. Objetivos

Al terminar deberías poder:

- Crear un **blob** desde contenido literal con `git hash-object -w`.
- Construir un **tree** con `git mktree` que referencie uno o más blobs.
- Construir un **commit** con `git commit-tree`, tanto sin padre (initial) como con padre.
- **Mover una ref** manualmente con `git update-ref`.
- Verificar la cadena resultante con `git cat-file -p` y `git rev-parse`.

## 4. Prerrequisitos

- Git ≥ 2.30 con identidad local configurable (`user.name`, `user.email`).
- Haber reproducido `examples/01-build-commit-by-hand/`.
- Haber leído secciones 1–5 de `theory/lesson.md`.

**Costos:** ninguno (todo local en `/tmp`).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/setup-lab.sh /tmp/plumbing-lab
cd /tmp/plumbing-lab
```

El script crea un **repo vacío** (`git init -b main`) con identidad configurada (`Lab Student`) y nada más. No hay commits, no hay archivos, no hay refs.

Lo que tienes:

```
/tmp/plumbing-lab/
└── .git/
    ├── HEAD         → "ref: refs/heads/main"
    ├── config       → identidad + init.defaultBranch=main
    ├── objects/     → vacío
    └── refs/        → vacío
```

### 5.2 Objetivo final

Construir **dos commits encadenados** sobre `refs/heads/main`:

- **Commit 1** (initial, sin padre):
  - mensaje: `init: hello`
  - contenido: un solo archivo `hello.txt` con el texto `"hello\n"`.
- **Commit 2** (padre = Commit 1):
  - mensaje: `feat: add greeter`
  - contenido: `hello.txt` **igual que antes** + un archivo nuevo `greeter.sh` con contenido `"#!/bin/sh\necho hello\n"` y modo `100755` (ejecutable).

Al terminar:

- `git log --oneline` debe mostrar 2 líneas, Commit 2 arriba.
- `git cat-file -p HEAD` debe mostrar el tree del Commit 2 y `parent <hash-de-Commit-1>`.
- `git ls-tree HEAD` debe listar `hello.txt` (100644) y `greeter.sh` (100755).

### 5.3 Reglas del juego

- **PROHIBIDO** usar `git add`.
- **PROHIBIDO** usar `git commit` (ni amend, ni cualquier variante).
- **PERMITIDO** usar: `git hash-object`, `git mktree`, `git write-tree` (si decides pasar por index), `git commit-tree`, `git update-ref`, `git cat-file`, `git ls-tree`, `git rev-parse`, `git log`, `git checkout -- .` (al final, si quieres materializar).

### 5.4 Pasos sugeridos (sin dar la solución)

**Para el Commit 1:**

1. Convierte el contenido `"hello\n"` en un blob con `git hash-object --stdin -w`. Guarda el hash en una variable (p. ej. `BLOB1`).
2. Construye un tree con una sola entrada `100644 blob <BLOB1>\thello.txt` usando `git mktree`. Guarda el hash en `TREE1`.
3. Construye el commit con `git commit-tree "$TREE1"` pasando el mensaje por stdin. Guarda en `COMMIT1`.
4. Apunta `refs/heads/main` al commit con `git update-ref refs/heads/main "$COMMIT1"`.

**Para el Commit 2:**

5. Crea el blob del script con `printf '#!/bin/sh\necho hello\n' | git hash-object --stdin -w`. Guarda en `BLOB2`.
6. Construye un tree con **dos** entradas: `100644 blob <BLOB1>\thello.txt` y `100755 blob <BLOB2>\tgreeter.sh`. Guarda en `TREE2`.
7. Construye el commit con padre = `COMMIT1`: `git commit-tree "$TREE2" -p "$COMMIT1"`. Guarda en `COMMIT2`.
8. Mueve `refs/heads/main` a `COMMIT2`.

**Verifica:**

```bash
git log --oneline
git cat-file -p HEAD           # debe tener 'parent <COMMIT1>'
git ls-tree HEAD               # debe listar los 2 archivos
```

### 5.5 Pistas

Entre más tardes en mirarlas, mejor aprendes.

- **Pista 1.** El input de `git mktree` espera **TAB** entre el hash y el nombre, no espacios. Usa `printf '%s %s %s\t%s\n' <mode> <type> <hash> <name>`.
- **Pista 2.** `git mktree` acepta **múltiples líneas por stdin**: una entrada por línea. Puedes concatenar con `printf '...\n...\n'`.
- **Pista 3.** `git commit-tree` toma el mensaje por stdin: `echo "mensaje" | git commit-tree <tree>` (sin padre) o `echo "mensaje" | git commit-tree <tree> -p <parent>`.
- **Pista 4.** El modo `100755` es para blobs **ejecutables** (bit `x`). `100644` para blobs normales. Trees usan `040000`.
- **Pista 5.** Para verificar un hash sobre la marcha: `git cat-file -t <hash>` te dice el tipo (`blob` / `tree` / `commit`).

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/plumbing-lab
```

Debe terminar con `RESULT: OK`.

## 6. Resultado esperado

- `main` apunta a un commit cuyo mensaje empieza por `feat: add greeter`.
- Ese commit tiene **un** parent cuyo mensaje empieza por `init: hello`.
- El tree de HEAD contiene exactamente dos entradas:
  - `100644 blob <X> hello.txt` donde `<X>` es el hash de `"hello\n"` (`ce013625030ba8dba906f756967f9e9ca394464a`).
  - `100755 blob <Y> greeter.sh` donde `<Y>` es el hash de `"#!/bin/sh\necho hello\n"`.
- El tree del commit inicial contiene **solo** `hello.txt` con el mismo hash `<X>`.
- `.git/objects/` contiene al menos los 4 objetos (2 blobs únicos, 2 trees, 2 commits).

## 7. Criterios de aceptación

- [ ] No se usó `git add` ni `git commit` (verificado por disciplina — el validador no lo detecta, pero el reflog sí: no habrá entradas tipo `commit:`, solo `update-ref`).
- [ ] `tests/validate.sh` pasa.
- [ ] Puedes explicar, apuntando a los hashes, por qué cambiar el contenido de `hello.txt` en el Commit 2 habría cambiado el hash del tree del Commit 2 **y** del commit mismo.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plumbing-lab
```

El validador chequea:

- `refs/heads/main` existe.
- HEAD apunta a un commit con mensaje que empieza por `feat: add greeter`.
- Ese commit tiene exactamente **un** parent.
- El parent tiene mensaje que empieza por `init: hello`.
- El tree de HEAD contiene exactamente `hello.txt` (modo `100644`) + `greeter.sh` (modo `100755`).
- El contenido del blob `hello.txt` es exactamente `hello\n`.
- El contenido del blob `greeter.sh` es exactamente `#!/bin/sh\necho hello\n`.
- El tree del parent contiene solo `hello.txt` con el mismo hash de blob que HEAD.

## 9. Preguntas de reflexión

1. **¿Qué pasaría con el hash del Commit 2 si cambiaras una línea en el mensaje del Commit 1?** (Pista: el parent del Commit 2 ya no existiría con el mismo hash → tendrías que reconstruir Commit 2.)
2. ¿Por qué el blob de `hello.txt` **no cambia** entre Commit 1 y Commit 2, pero el **tree** sí?
3. Si eliminas `.git/refs/heads/main` **sin tocar `.git/objects/`**, ¿se pierde la historia? ¿Cómo la recuperarías?
4. ¿Qué ventaja operativa concreta tiene `git update-ref` sobre editar el archivo `.git/refs/heads/main` con un `echo`?
5. Describe en términos de este flujo (`hash-object` → `mktree` → `commit-tree` → `update-ref`) qué hace exactamente `git commit --amend`. ¿Cuál de los pasos **no** se repite?

## 10. Extensiones (opcional)

- **E1** — Haz un **tercer commit** que *elimine* `greeter.sh` (es decir, el tree debe tener solo `hello.txt` de nuevo). Pista: construye un tree que no incluya la entrada; el blob antiguo seguirá existiendo pero dangling.
- **E2** — Crea un **tag anotado** con solo plumbing: `echo "mensaje" | git mktag` (ver `git-mktag(1)`) a partir de un objeto `tag` armado a mano, y apunta `refs/tags/v1.0` con `update-ref`.
- **E3** — Crea un **merge commit sintético**: un commit con dos parents. Verifica con `git log --graph`.
- **E4** — Ahora que entiendes el flujo, repite todo pasando por el **index**: `git update-index --add --cacheinfo <mode>,<hash>,<path>` + `git write-tree` + `git commit-tree`. Compara.

## 11. Limpieza

```bash
rm -rf /tmp/plumbing-lab
```
