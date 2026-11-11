# Lección: Anatomía de un comando de shell

> **ID:** `sys-02-shell-command-anatomy` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `sys-01-bash-cli-foundations`.

---

## 1. Introducción intuitiva

Mira esta línea:

```bash
sudo tar --exclude='*.log' -xzvf backup.tgz -C /var/restore -- extra-arg
```

Si no la has analizado nunca, parece un conjuro. Y sin embargo cada símbolo cumple un papel exacto: `sudo` es un comando, `tar` es su primer argumento (que a su vez es *otro* comando), `--exclude='*.log'` es una opción larga con valor, `-xzvf` son cuatro flags cortos agrupados, `backup.tgz` es el valor que acompaña a `-f`, `-C /var/restore` es otra opción corta con valor, `--` cierra el procesamiento de flags y `extra-arg` se interpreta como argumento posicional aunque empezara con `-`.

Este módulo te enseña a **leer** cualquier línea igual que un carpintero mira una viga: sin dudar sobre qué pieza es qué. Y, lo más importante, a **buscar tú** la respuesta en la documentación en vez de pedírsela a nadie.

---

## 2. Fundamentos

### 2.1 La forma canónica

Casi cualquier CLI moderna sigue una forma común:

```
cmd [GLOBAL_OPTS] [subcmd [OPTS] [ARGS...]]
```

- **`cmd`** — el programa a ejecutar (`git`, `kubectl`, `apt`, `tar`).
- **`GLOBAL_OPTS`** — opciones que afectan a todo (`git --no-pager …`, `kubectl --context=prod …`).
- **`subcmd`** — subcomando opcional (`git commit`, `kubectl get`, `apt install`).
- **`OPTS`** — opciones específicas del subcomando.
- **`ARGS`** — argumentos posicionales (archivos, nombres, URLs).

No todos los comandos tienen subcomandos (`ls`, `grep`, `rm` no), pero cuando los tienen la posición importa: `git --no-pager log` ≠ `git log --no-pager` sólo en los casos donde la opción es "global" versus "del subcomando".

### 2.2 Convenciones de opciones

| Forma | Ejemplo | Origen | Notas |
|-------|---------|--------|-------|
| Corta | `-l` | POSIX | Una sola letra tras `-`. |
| Agrupada | `-la` ≡ `-l -a` | POSIX | Sólo si **todas** son booleanas excepto como mucho la última. |
| Corta con valor | `-oValue` o `-o Value` | POSIX / GNU | Sin espacio o con espacio; depende del parser. |
| Larga | `--long` | GNU | Dos guiones, palabra completa. |
| Larga con valor | `--opt=value` o `--opt value` | GNU | `=` es más portable en scripts. |
| Separador | `--` | POSIX | Fin del procesamiento de opciones. Todo lo siguiente es posicional. |
| Negación | `--no-color` | GNU | Convención, no obligación. |

**Flags booleanos**: sólo encienden algo (`-v`, `--verbose`). No llevan valor.

**El separador `--`** es crítico: te permite pasar nombres de archivo que empiezan por `-` sin que el parser los tome como opciones.

```bash
# ¿Cómo borro un archivo llamado "-rf"?
rm -- -rf
# Sin el --, rm interpretaría -rf como la opción destructiva.
```

### 2.3 Separadores y operadores

| Símbolo | Significado |
|---------|-------------|
| `;` | Ejecuta en secuencia. El exit code de los anteriores no importa. |
| `&&` | Ejecuta el siguiente **sólo si** el anterior salió con éxito (exit 0). |
| `\|\|` | Ejecuta el siguiente **sólo si** el anterior falló (exit ≠ 0). |
| `&` | Lanza en segundo plano. Devuelve control inmediato; el PID queda en `$!`. |
| `\|` | Pipe: conecta stdout del izquierdo al stdin del derecho. |
| `( … )` | Subshell: ejecuta en un proceso hijo con su propio entorno/`cd`. |
| `{ …; }` | Group command: mismo shell, requiere espacios y `;` final. |

Ejemplos cotidianos:

```bash
make build && make test                  # test sólo si build pasó
grep -q error log.txt || echo "limpio"   # mensaje sólo si NO hay error
cd /tmp && work.sh                       # trabaja aquí si cd funcionó
( cd /tmp && work.sh )                   # igual pero NO cambia tu cwd
{ echo a; echo b; } > out.txt            # ambos stdouts a un único archivo
```

### 2.4 Fuentes de documentación

| Herramienta | Para qué | Formato |
|-------------|----------|---------|
| `cmd --help` o `cmd -h` | Resumen rápido escrito por el autor. | Texto a stdout. |
| `man cmd` | Página de manual canónica. | Formato groff; se lee con pager. |
| `info cmd` | Manuales largos tipo libro (muy GNU). | Hipertexto Texinfo. |
| `tldr cmd` | Ejemplos "a mano", mantenidos por comunidad. | Markdown, muy breve. |
| `apropos palabra` | Busca en los *títulos* de todos los `man`. | Lista de hits + sección. |
| `whatis cmd` | Línea única de descripción (sección NAME). | Una línea por sección. |
| `help cmd` | Sólo para **builtins** de Bash (`cd`, `echo`, `read`). | Impreso por Bash. |
| `type -a cmd`, `command -V cmd` | Qué *es* ese nombre (builtin/alias/función/binario). | Línea de diagnóstico. |

### 2.5 Secciones de manpages

`man` no es un libro, son 8+ libros con el mismo índice. Cada tema vive en una sección numerada:

| Sección | Contenido | Ejemplo |
|---------|-----------|---------|
| 1 | Comandos de usuario. | `man 1 printf`, `man 1 ls`. |
| 2 | Llamadas al sistema (kernel). | `man 2 open`, `man 2 fork`. |
| 3 | Funciones de bibliotecas (libc, …). | `man 3 printf`, `man 3 malloc`. |
| 4 | Dispositivos y archivos especiales (`/dev/*`). | `man 4 tty`. |
| 5 | Formatos de archivo y convenciones. | `man 5 passwd`, `man 5 fstab`, `man 5 crontab`. |
| 6 | Juegos. | `man 6 fortune`. |
| 7 | Miscelánea: protocolos, convenciones, estándares. | `man 7 signal`, `man 7 regex`, `man 7 hier`. |
| 8 | Comandos de administración. | `man 8 mount`, `man 8 iptables`. |

Para ver todas las secciones donde aparece un nombre:

```bash
man -k ^printf$       # lista todos los "printf" (-k = apropos)
man -f printf         # idéntico a whatis
man 3 printf          # fija la sección 3 explícitamente
```

Dentro del pager (`less`), teclas útiles: `/pat` buscar, `n` siguiente, `N` anterior, `g` arriba, `G` abajo, `q` salir, `h` ayuda.

---

## 3. Contexto histórico

- Las opciones **cortas** nacen con los Unix originales de los 70. POSIX `getopt(3)` las formaliza en los 80.
- Las opciones **largas** son invento del proyecto GNU (años 80-90) para que `--help` sea legible y los scripts auto-documentados. GNU `getopt` (coreutils) soporta ambas y la biblioteca `argp` las estandariza para proyectos GNU.
- El estilo de **subcomandos** (`git commit`, `svn update`) se popularizó con Subversion y Git. Hoy la biblioteca Go `spf13/cobra` lo trae por default a cualquier CLI moderna (`kubectl`, `helm`, `gh`, `docker`).
- `man` nació en 1971 (Research Unix v2). La división en secciones existe desde entonces: era literalmente *dónde estaba* ese capítulo del libro de manuales en papel.
- `info` es el intento del proyecto GNU de reemplazar `man` por algo más expresivo; nunca ganó porque "`man foo`" ya es muscle-memory universal. Aun así, para herramientas GNU grandes (`info coreutils`, `info bash`) el `info` es más completo.
- `tldr-pages` (2013) y `cheat.sh` surgen como reacción a que las páginas `man` modernas se volvieron de referencia y poco didácticas.

---

## 4. Funcionamiento interno

### 4.1 Qué hace Bash entre Enter y la ejecución

Cada vez que pulsas Enter, Bash realiza un pipeline fijo:

```
┌───────────────┐
│ 1. Lectura    │  readline captura la línea con historial y edición.
└───────┬───────┘
        ▼
┌───────────────┐
│ 2. Tokenizado │  Divide la línea en palabras y operadores respetando
│   (lexer)     │  comillas simples/dobles, backslashes y here-docs.
└───────┬───────┘
        ▼
┌───────────────┐
│ 3. Parsing    │  Construye un árbol: pipelines, listas, condicionales,
│   gramatical  │  comandos simples/compuestos.
└───────┬───────┘
        ▼
┌───────────────────────────────────────────────────────────────────┐
│ 4. Expansiones (ORDEN FIJO, aprende este orden):                  │
│   a. Brace     ─  {a,b,c}, {1..9}                                 │
│   b. Tilde     ─  ~, ~user                                        │
│   c. Parameter ─  $var, ${var:-x}, ${var/pat/rep}                 │
│   d. Arithmetic─  $(( 1+2 ))                                      │
│   e. Command   ─  $(cmd), `cmd`                                   │
│   f. Word split─  divide por IFS (default: espacio/tab/newline)   │
│   g. Pathname  ─  *, ?, [a-z] contra el filesystem                │
└───────┬───────────────────────────────────────────────────────────┘
        ▼
┌───────────────┐
│ 5. Resolución │  ¿Qué es la primera palabra?
│   del comando │   alias → función → builtin → hash → PATH → "command not found"
└───────┬───────┘
        ▼
┌───────────────┐
│ 6. Redirección│  Aplica <, >, 2>&1, &>, here-docs al fd correcto.
└───────┬───────┘
        ▼
┌───────────────┐
│ 7. Ejecución  │  Builtin → se corre en el mismo proceso.
│               │  Externo → fork() + execve() al binario.
└───────────────┘
```

Dos consecuencias importantes:

- **El orden de expansión es fijo.** Por eso `echo *.txt` *sí* se expande (pathname pasa después), pero `echo '*.txt'` no (las comillas simples bloquean antes). Y por eso `rm $file` cuando `file="a b"` ejecuta `rm a b` (word splitting en 4.f), lo cual es un bug clásico — fíjalo con `rm "$file"`.
- **Los alias y funciones se resuelven primero.** Por eso un `alias ls='ls --color=auto'` cambia la realidad; para saltar temporalmente al binario puro usa `\ls` o `command ls`.

### 4.2 Dónde se buscan los comandos: `PATH` y la `hash` table

Cuando ejecutas `git`, Bash *no* escanea tu disco cada vez. El algoritmo es:

1. ¿Es un **alias**? Si sí, sustitúyelo.
2. ¿Es una **función** de shell? Si sí, invócala.
3. ¿Es un **builtin** (`cd`, `echo`, `read`, `[`, `type`, …)? Si sí, ejecútalo en el mismo proceso.
4. ¿Está en la **hash table** interna (`hash -l`)? Si sí, usa esa ruta cacheada.
5. Si no, recorre cada entrada de `$PATH` en orden y usa el **primer** binario ejecutable que encuentre. Añade esa ruta a la hash table.
6. Si tras recorrer `$PATH` no hay match: `command not found` (en algunas distros con un hook amigable que sugiere paquetes).

Ver y manipular:

```bash
echo "$PATH"           # el orden importa: izquierda > derecha
type -a ls             # muestra TODAS las resoluciones (alias, builtin, binario)
command -V python      # igual pero más determinista para scripts
hash -l                # qué rutas tiene Bash cacheadas
hash -r                # limpia la cache (tras instalar algo nuevo en $PATH)
which -a python        # qué hay en $PATH con ese nombre
```

> **Nota útil**: cuando instalas un binario en `/usr/local/bin/foo` pero la shell actual sigue encontrando el viejo en `/usr/bin/foo`, casi siempre es la hash table. `hash -r` lo resuelve sin reiniciar la sesión.

### 4.3 Builtin vs externo (y por qué importa)

| Tipo | Ejemplos | Dónde vive |
|------|----------|------------|
| Builtin | `cd`, `echo`, `pwd`, `read`, `[`, `test`, `export`, `set` | Dentro de Bash. No hace `fork`. |
| Función | las tuyas de `.bashrc` | Dentro de Bash. |
| Alias | las tuyas de `.bashrc` | Puro texto sustituido antes del parsing. |
| Externo | `ls`, `grep`, `tar`, `git` | Binario en `$PATH`. Hace `fork` + `execve`. |

`cd` **debe** ser builtin: cambiar el `cwd` de un proceso hijo (si fuera externo) no afectaría al padre. Lo mismo `export`, `read`, `set`.

```bash
type -a echo
# echo is a shell builtin
# echo is /usr/bin/echo        <- este existe también, pero el builtin gana
```

---

## 5. Ejemplo mínimo

Vamos a destripar la línea del principio:

```bash
sudo tar --exclude='*.log' -xzvf backup.tgz -C /var/restore -- extra-arg
```

| Pieza | Papel |
|-------|-------|
| `sudo` | Comando externo (`/usr/bin/sudo`). |
| `tar` | **Primer argumento de sudo**, interpretado como comando a ejecutar como root. |
| `--exclude='*.log'` | Opción larga con valor. Comillas simples impiden que la shell expanda `*.log` *antes* de pasarla a tar; es tar quien hace el matching. |
| `-xzvf` | Cuatro flags cortos agrupados: `-x` extract, `-z` gzip, `-v` verbose, `-f` file (con valor). |
| `backup.tgz` | Valor que acompaña a `-f` (por ser el último flag del grupo). |
| `-C /var/restore` | Opción corta con valor (`cd` a este directorio antes de extraer). |
| `--` | Fin del procesamiento de opciones. |
| `extra-arg` | Argumento posicional, aunque empezara con `-`. |

Y la forma larga 100% equivalente para el núcleo tar:

```bash
sudo tar --extract --gzip --verbose --file=backup.tgz \
         --directory=/var/restore --exclude='*.log' -- extra-arg
```

Fíjate: la segunda es más larga, pero autoexplicativa. En scripts y en código versionado, prefiere formas largas. En la terminal interactiva, las cortas.

---

## 6. Categorización canónica de comandos

El sistema de archivos de `/bin`, `/usr/bin`, `/sbin` contiene miles de ejecutables. En la práctica, cada uno encaja en una de ~14 categorías. Memorizar las **categorías** (no los flags) te permite buscar el comando correcto cuando lo necesites.

| Categoría | Qué resuelve | Comandos típicos |
|-----------|--------------|------------------|
| **Navegación / FS** | Moverte y describir el árbol de archivos. | `cd`, `pwd`, `ls`, `tree`, `stat`, `file`, `find`, `pushd`, `popd` |
| **Manipulación de archivos** | Crear, copiar, mover, borrar, enlazar. | `cp`, `mv`, `rm`, `mkdir`, `rmdir`, `touch`, `ln`, `install`, `rsync` |
| **Lectura / vista** | Leer contenido completo o paginado. | `cat`, `less`, `more`, `head`, `tail`, `nl`, `od`, `xxd`, `hexdump` |
| **Edición en flujo** | Transformar texto en pipeline (sin editor interactivo). | `sed`, `awk`, `tr`, `cut`, `paste`, `sort`, `uniq`, `wc`, `fold`, `column` |
| **Búsqueda** | Encontrar archivos o patrones. | `grep`, `egrep`, `fgrep`, `rg`, `find`, `locate`, `which`, `fd`, `whereis` |
| **Procesos** | Inspeccionar y controlar procesos y jobs. | `ps`, `top`, `htop`, `btop`, `kill`, `pkill`, `killall`, `jobs`, `nice`, `renice`, `nohup`, `pgrep` |
| **Red** | Interfaces, rutas, DNS, conectividad, captura. | `ip`, `ss`, `ping`, `traceroute`, `mtr`, `dig`, `host`, `curl`, `wget`, `nc`, `tcpdump` |
| **Usuarios / permisos** | Quién, a qué grupos, con qué derechos. | `id`, `whoami`, `who`, `w`, `last`, `su`, `sudo`, `chmod`, `chown`, `chgrp`, `umask`, `passwd` |
| **Paquetes** | Instalar, actualizar, remover software del distro. | `apt`, `apt-get`, `dpkg`, `dnf`, `yum`, `rpm`, `pacman`, `apk`, `zypper`, `brew` |
| **Servicios / init** | Daemons y logging del sistema. | `systemctl`, `journalctl`, `service` (legacy), `rc-service` (OpenRC) |
| **Disco** | Discos, particiones, filesystems, mounts, uso. | `df`, `du`, `lsblk`, `blkid`, `mount`, `umount`, `fdisk`, `parted`, `mkfs`, `fsck`, `findmnt` |
| **Archivadores / compresión** | Empaquetar y comprimir. | `tar`, `gzip`, `gunzip`, `xz`, `zstd`, `bzip2`, `zip`, `unzip`, `cpio`, `ar` |
| **Checksums / firma** | Verificar integridad y autenticidad. | `md5sum`, `sha1sum`, `sha256sum`, `sha512sum`, `b2sum`, `gpg`, `openssl dgst`, `cksum` |
| **Shell meta / introspección** | Preguntarle a la shell qué es qué. | `type`, `command`, `builtin`, `alias`, `unalias`, `help`, `which`, `hash`, `set`, `shopt`, `declare` |

**Cómo usar esta tabla**: cuando te enfrentes a una tarea, nómbrala en una de esas categorías ("necesito **buscar** un patrón en logs" → categoría Búsqueda → probablemente `grep` o `rg`). La categoría acota el espacio de posibles comandos a <10.

---

## 7. Lectura guiada de un manpage

Toma uno nuevo, p. ej. `man 1 find`. La estructura es siempre la misma:

| Sección | Qué buscar aquí |
|---------|-----------------|
| **NAME** | Línea única: `find — search for files in a directory hierarchy`. Perfecta para `whatis`. |
| **SYNOPSIS** | La "firma" del comando: qué opciones y en qué orden. `[ ]` opcional, `...` repetible, `\|` alternativa. |
| **DESCRIPTION** | Explicación larga del modelo de ejecución. En comandos grandes (`find`, `awk`, `bash`), vale la pena leer esto una vez. |
| **OPTIONS** | Lista exhaustiva de flags, con descripción y ejemplos cortos. Es donde buscas con `/`. |
| **EXAMPLES** | Casi todos los `man` modernos los tienen. Léelos antes de inventar la rueda. |
| **EXIT STATUS** | Códigos de salida con significado. Imprescindible si llamas al comando desde un script. |
| **ENVIRONMENT** | Variables que modifican el comportamiento (`LANG`, `GREP_COLOR`, `LESS`). |
| **FILES** | Rutas que el comando lee/escribe por default. |
| **SEE ALSO** | Links a páginas relacionadas, con su sección. |
| **BUGS / STANDARDS / HISTORY** | Contexto. A veces explica rarezas (`echo -n` vs `printf`). |

Técnica de 30 segundos:

```bash
man find                 # abre el pager
/-mtime                  # busca el flag; n para el siguiente, N anterior
# leído lo esencial:
q                        # sale
```

Si no sabes el nombre: `apropos "search file"`, `apropos regex`. Si lo tienes, pero no sabes la sección: `whatis crontab` → verás `crontab (1), crontab (5)` y eliges.

---

## 8. Trade-offs y variantes de parser

Hay cuatro familias de parsers de CLI en el mundo Unix:

| Parser | Dónde | Comportamiento típico |
|--------|-------|------------------------|
| POSIX `getopt(3)` | C clásico; `/bin/sh` scripts. | Sólo cortas, `-oValue` o `-o Value`, agrupables. |
| GNU `getopt_long` / `argp` | Casi todo coreutils, GNU `tar`, `grep`. | Cortas + largas, `--opt=value` o `--opt value`, `--` como terminador, acepta flags **después** de posicionales. |
| BSD-style | macOS originales, `ps`, `tar` BSD. | A veces sin guion (`ps aux`, `tar xzf`). Convive mal con GNU en scripts cross-plataforma. |
| Modern subcommand (cobra/clap/argparse) | `git`, `kubectl`, `gh`, `docker`, `cargo`. | Subcomandos jerárquicos, autocompletado, `--help` por nivel. |

Tres consecuencias prácticas:

- **BSD vs GNU `tar`**: `tar xzf` (sin guion) funciona en ambos por compatibilidad histórica, pero sólo en los flags "pre-opción". Para scripts portables, usa la forma GNU estándar `tar -xzf`.
- **`ls` de GNU** acepta flags después del path (`ls /tmp -la`); el `ls` BSD/macOS **no**. En scripts, mete siempre los flags antes.
- **Las subcomando-based** (cobra, click) son las más previsibles. Si estás diseñando una CLI propia, imítalas.

### 8.1 `getopts` vs `getopt`

Dentro de tus propios scripts tendrás que elegir (profundizamos en `sys-18`):

- **`getopts`** (builtin de Bash) — sólo cortas, portable, suficiente para scripts cortos.
- **`getopt`** (externo, versión GNU) — cortas + largas, pero su sintaxis es más dolorosa.

---

## 9. Errores frecuentes

### 9.1 Confundir separadores con flags

```bash
rm *.log                  # borra todos los .log en el cwd (expansión de shell)
rm -- *.log               # idéntico pero defensivo si algún archivo empieza por "-"
rm "*.log"                # NO expande: busca un archivo llamado literalmente *.log
```

### 9.2 Pensar que `|` encadena procesos "en serie"

Un pipe lanza **todos** los procesos a la vez; stdout del uno va al stdin del otro vía kernel. Por eso `cmd1 | cmd2` termina cuando el más lento termina, y por eso `set -o pipefail` existe (sin él, `cmd1 | cmd2` sólo reporta el exit de `cmd2`).

### 9.3 Suponer que `which` es autoritativo

`which` es un binario externo que lee *su propio* `PATH`. Puede diferir del que tu shell actual tiene cacheado o del que la nueva función `cmd()` definió. Para scripts, usa **`command -V`** (POSIX, consulta a la shell actual) o `type -a`.

### 9.4 Mezclar `--opt value` cuando el parser quiere `--opt=value`

La mayoría de GNU acepta ambos. Algunos parsers artesanales **no**. Si tu CLI falla con "unknown option --opt", prueba `=`:

```bash
./my-cli --name juan        # falla "requires value"
./my-cli --name=juan        # funciona
```

### 9.5 Olvidar `--` ante entradas controladas por el usuario

```bash
# Script que borra lo que le pasen:
rm "$1"                 # si $1="-rf /", desastre
rm -- "$1"              # defensivo
```

### 9.6 Buscar en la sección equivocada de `man`

`man passwd` abre `man 1 passwd` (el comando) por default. Pero quien escribe en `/etc/passwd` normalmente quiere **`man 5 passwd`** (formato del archivo). Especifica siempre la sección cuando sepas que hay ambigüedad.

### 9.7 Encadenar con `;` cuando quieres `&&`

```bash
cd /tmp/nope; rm -rf *       # ¡rm corre en tu HOME si el cd falla!
cd /tmp/nope && rm -rf *     # rm sólo corre si cd tuvo éxito
```

Es el bug clásico que destruye datos.

---

## 10. Buenas prácticas

- **En scripts**: formas largas (`--extract --gzip --file=…`). Son auto-documentadas y resisten cambios de alias.
- **En terminal**: formas cortas (`-xzf`). Son rápidas y memorables.
- **Siempre `--` antes de un path que viene de variable** si no estás seguro.
- **`man -k` y `apropos` antes de Googlear**. Normalmente ganan.
- **Aprende las teclas de `less`**: `/`, `n`, `N`, `g`, `G`, `q`, `h`. Son también el pager del `git`, `systemctl`, `journalctl`.
- **`type -a` en vez de `which`** para preguntarle a tu shell actual.
- **`tldr cmd`** para la primera impresión de un comando nuevo. `man cmd` para profundizar.
- **No uses `.` como ejecutable "por ahorro"**: `./script` es claro, `. script` es `source` (otra cosa).
- **Si un comando parece inconsistente entre máquinas, chequea `type -a` y `command -V`**: casi siempre es un alias en `.bashrc` o un binario distinto en `$PATH`.
- **Lee `SEE ALSO`** al final de cada manpage. Es tu plan de lectura siguiente.

---

## 11. Ejercicios recomendados

1. **`examples/01-same-tar-many-ways/`** — tres formas equivalentes de extraer un `.tar.gz`. Objetivo: convencerte de que corta y larga son el mismo comando.
2. **`examples/02-man-section-tour/`** — mismo nombre (`printf`, `passwd`) en varias secciones de `man`. Objetivo: internalizar la numeración.
3. **`activities/01-categorize-the-coreutils/`** — clasificar 40 comandos. **Independent** — es la que valida tu modelo mental de categorías.
4. **`activities/02-manpage-scavenger-hunt/`** — 10 preguntas que te obligan a navegar manpages reales. **Challenge** — gimnasio puro de lectura de docs.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Dada la línea `grep -rni "error" -- -log/ 2>/dev/null | head -20`, identifica: (a) el comando, (b) cada flag y qué significa, (c) qué rol juega `--`, (d) qué rol juega `2>/dev/null`, (e) qué significa `|`.

**P2.** Verdadero / falso:
   - [ ] `-la` es exactamente equivalente a `-l -a`.
   - [ ] `--foo=bar` y `--foo bar` siempre son equivalentes.
   - [ ] `which foo` consulta tu shell actual.
   - [ ] `type -a cd` imprime la ruta de un binario llamado `cd`.
   - [ ] Un alias se resuelve antes que un builtin.

**P3.** ¿En qué sección de `man` buscarías: (a) el **formato** del archivo `/etc/crontab`, (b) la **llamada al kernel** `open`, (c) la **función de biblioteca** `strcmp`, (d) el **comando de administración** `mount`?

**P4.** Da **tres** formas equivalentes de extraer `foo.tar.gz` con `tar`. Explica por qué las tres funcionan.

**P5.** Explica, paso por paso, qué hace Bash entre que pulsas Enter sobre `echo *.txt > out.txt` y la escritura real al archivo. Nombra las fases.

**P6.** `cd /tmp/foo; rm -rf *` es peligroso. Explica por qué y cómo lo arreglarías.

**P7.** Clasifica cada uno de estos comandos en su categoría canónica (una línea cada uno): `rsync`, `journalctl`, `b2sum`, `pstree`, `fd`, `nftables`, `blkid`, `xxd`, `zstd`, `tldr`.

**P8.** Diseño: estás escribiendo un script `backup.sh` que acepta `--source`, `--dest`, `--exclude` y `--dry-run`. Decide si usarías `getopts`, `getopt` GNU o parseo manual, y por qué. (No hace falta escribirlo, sólo justificarlo.)

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- **man-pages project** (Linux manpages canónicas) — <https://man7.org/linux/man-pages/>
- **GNU coreutils manual** (comandos clásicos: `ls`, `cp`, `rm`, …) — <https://www.gnu.org/software/coreutils/manual/coreutils.html>
- **Bash reference manual**, sección "Shell Expansions" — <https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html>
- **POSIX Utilities Volume (The Open Group)** — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html>
- **tldr-pages** (ejemplos comunitarios) — <https://tldr.sh/>

Lectura complementaria:

- *The Linux Command Line*, William Shotts — capítulos 1-6.
- `info coreutils` — leer "Common options" y "Operating on characters".
- Bash `help` para cada builtin: `help cd`, `help type`, `help command`, `help trap`.
