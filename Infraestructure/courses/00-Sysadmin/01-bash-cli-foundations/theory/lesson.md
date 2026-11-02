# Lección: Bash & CLI foundations

> **ID:** `sys-01-bash-cli-foundations` · **Nivel:** fundamentos · **Duración:** 4 h
> **Prerrequisitos:** acceso a una terminal Linux, macOS o WSL.

---

## 1. Introducción intuitiva

Abres una terminal. Ves un *prompt* que te invita a escribir. Tecleas `ls` y pulsas Enter. Aparece la lista de archivos. ¿Qué acaba de pasar? La respuesta corta: un programa llamado **shell** leyó tu línea, la descompuso, buscó un binario llamado `ls`, lo lanzó como proceso hijo heredando una tabla de *file descriptors*, esperó a que terminara, imprimió lo que el hijo escribió en el descriptor 1 (stdout) y volvió a imprimir el prompt para esperar la siguiente línea.

Este módulo te enseña a **ver** ese proceso, no a memorizar comandos. Cada operador (`>`, `|`, `2>&1`, `<<<`) es una manipulación concreta de esa tabla de descriptores. Cada `export` es un cambio al bloque de *environment* que el próximo hijo heredará. Si entiendes el modelo, los comandos se deducen.

El plan:
1. Entender qué es una shell y por qué Bash gana.
2. Dominar prompt, historial y readline — tu interfaz principal.
3. Moverte y gestionar archivos sin accidentes.
4. Entender fd 0/1/2 y redirigir con precisión quirúrgica.
5. Encadenar con pipes de forma robusta (`pipefail`).
6. Controlar el entorno sin romper `PATH`.

---

## 2. Fundamentos

### 2.1 Shell, Bash, sh — qué es qué

Una **shell** es un programa que lee líneas de texto y las convierte en invocaciones de otros programas. Es un *lenguaje de pegamento* entre humano y kernel. Hay muchas:

| Nombre | Binario típico | Rasgo |
|--------|----------------|-------|
| Bourne shell | `/bin/sh` original | Antigua, mínima. |
| Bash (Bourne Again Shell) | `/bin/bash` | GNU, dominante en Linux. Superset de `sh`. |
| Dash | `/bin/dash` | POSIX mínimo; en Debian/Ubuntu `/bin/sh` es un symlink a Dash. |
| Zsh | `/bin/zsh` | Default en macOS desde Catalina. Features extra. |
| Fish | `/usr/bin/fish` | Sintaxis distinta, no es POSIX. |

**`sh` no es "una shell":** es un contrato POSIX. Según el sistema, `/bin/sh` resuelve a dash, bash en modo POSIX, ksh, etc. Un script con `#!/bin/sh` **debe limitarse a POSIX**; uno con `#!/usr/bin/env bash` puede usar features Bash (`[[ ]]`, arrays, `local`, process substitution).

**Modos de Bash:**
- *Interactivo* vs *no interactivo* (script).
- *Login* vs *non-login*: afecta qué archivos se cargan (`/etc/profile`, `~/.bash_profile` para login; `~/.bashrc` para non-login interactivo).

### 2.2 Qué pasa cuando pulsas Enter

Simplificado, Bash hace esto en orden:

```
1. readline lee la línea editable (soporte emacs/vi, autocompletado, historial).
2. Tokeniza (separa por whitespace/metacaracteres respetando quotes).
3. Expande: brace -> tilde -> parameter -> command substitution -> arithmetic -> word splitting -> glob.
4. Interpreta operadores de control (;, &&, ||, |, &).
5. Interpreta redirecciones (reescribe la tabla de fds del hijo antes del exec).
6. Si el comando es alias/función/builtin -> ejecuta en el proceso actual.
   Si es externo -> fork() y en el hijo execve(). El padre espera (wait).
7. Captura exit status en $? y continúa.
```

Si cualquier paso falla, el error se enruta por stderr (fd 2) y `$?` queda != 0.

### 2.3 fork + execve: el modelo UNIX de ejecución

```
                       Bash (PID 1234)
                             │
                      ls -l /tmp
                             │
                       fork()
                       /    \
                      /      \
                  PID 1234    PID 5678  <- clon exacto del padre
                 (padre)      (hijo)
                   │             │
                 wait()        execve("/bin/ls", ["ls","-l","/tmp"], environ)
                   │             │
                   │          /bin/ls reemplaza la imagen de memoria del hijo
                   │             │
                   │          escribe en fd 1 -> "..."
                   │             │
                   │          exit(0)
                   │             │
                   └── reap ────┘
```

El hijo **hereda**: directorio de trabajo, umask, tabla de file descriptors (incluidas redirecciones que Bash preparó) y bloque `environ`. **No hereda:** variables de shell no exportadas.

Un **builtin** (`cd`, `export`, `pwd`, `read`, `echo`) no hace `fork` — se ejecuta en el mismo proceso Bash. Por eso `cd` *tiene* que ser builtin: si fuera externo, cambiaría el cwd de un proceso hijo que luego muere y Bash volvería al cwd anterior.

### 2.4 Tipos de "comando"

Al teclear `ls`, Bash resuelve en este orden:

1. **Alias** (`alias ls='ls --color=auto'`).
2. **Función** definida en la shell actual.
3. **Builtin** (`type`, `cd`, `echo`...).
4. **Hash** (tabla de rutas cacheadas).
5. **`$PATH`**: primera coincidencia ejecutable.

Para inspeccionar:

```
$ type -a echo
echo is a shell builtin
echo is /bin/echo

$ command -V ls
ls is aliased to `ls --color=auto'

$ which -a python3
/usr/local/bin/python3
/usr/bin/python3
```

> **Gotcha:** `which` es un ejecutable externo que no sabe de aliases ni builtins. **Prefiere `type -a` / `command -V`**.

---

## 3. Prompt, historial y readline

### 3.1 El prompt (`PS1`)

`PS1` es la variable que Bash expande para dibujar tu prompt. Soporta *escape sequences* (`\u`, `\h`, `\w`, `\$`, etc.) y colores ANSI.

```
# Minimal
PS1='\u@\h:\w\$ '
# -> evan@laptop:~/code$

# Con color, exit code del último comando y rama Git
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\] $(_prompt_status)\$ '
```

Secuencias útiles:

| Escape | Significa |
|--------|-----------|
| `\u` | usuario |
| `\h` / `\H` | host corto / FQDN |
| `\w` / `\W` | cwd completo / basename |
| `\$` | `$` para usuario normal, `#` para root |
| `\t` / `\d` | hora / fecha |
| `\[` ... `\]` | marca secuencias no imprimibles (crítico para que readline cuente bien el ancho de línea) |

> **Gotcha:** si olvidas `\[` y `\]` alrededor de los códigos ANSI, readline cuenta los bytes de color como caracteres visibles y rompe el *word wrap* al editar.

**`PS2`** es el prompt de continuación (`>` por default) cuando una línea sigue (quote abierto, pipe colgando).

### 3.2 Historial

Bash guarda cada línea ejecutada en memoria y, al salir, la escribe en `~/.bash_history`. Variables relevantes:

| Variable | Efecto |
|----------|--------|
| `HISTSIZE` | líneas en memoria (default 500; sube a 10000+) |
| `HISTFILESIZE` | líneas en archivo |
| `HISTCONTROL` | `ignoredups`, `ignorespace`, `erasedups` |
| `HISTIGNORE` | patrones a excluir (`ls:cd:pwd:history`) |
| `HISTTIMEFORMAT` | prefijo de timestamp (`'%F %T '`) |

Shortcuts de historial:

```
!!            # última línea
!$            # último argumento de la línea anterior
!^            # primer argumento de la línea anterior
!42           # línea número 42 del history
!cmd          # última línea que empieza por 'cmd'
^old^new^     # repite última línea sustituyendo 'old' por 'new'
Ctrl-R        # búsqueda incremental hacia atrás
Alt-.         # inserta el último argumento (ciclable)
```

### 3.3 Readline (edición de línea)

Readline es la librería GNU que Bash usa para editar lo que escribes. Modo *emacs* por default; `set -o vi` cambia a modo vi.

Bindings esenciales (modo emacs):

| Combinación | Acción |
|-------------|--------|
| `Ctrl-A` / `Ctrl-E` | inicio / fin de línea |
| `Ctrl-U` / `Ctrl-K` | borrar hasta inicio / hasta fin |
| `Ctrl-W` | borrar palabra hacia atrás |
| `Alt-F` / `Alt-B` | avanzar / retroceder palabra |
| `Ctrl-L` | limpia pantalla (equiv. `clear`) |
| `Ctrl-R` | búsqueda incremental en historial |
| `Ctrl-C` | cancelar línea actual (no mata procesos pendientes) |
| `Ctrl-D` | EOF (sale si la línea está vacía) |
| `Tab` | autocompletado |

Configuración personal: `~/.inputrc` (p. ej. `set completion-ignore-case on`, `set show-all-if-ambiguous on`).

---

## 4. Navegación y gestión de archivos

### 4.1 Navegar

```
pwd           # print working directory
pwd -P        # resolviendo symlinks a path físico
pwd -L        # lógico (como lo ves con cd) [default]
cd            # va a $HOME
cd -          # vuelve al directorio anterior ($OLDPWD)
cd ~user      # home de otro usuario
pushd /tmp    # apila el cwd actual y cambia a /tmp
popd          # desapila (vuelve al anterior)
dirs -v       # lista la pila
```

> **Gotcha:** `cd` nunca falla silenciosamente — siempre comprueba `$?` en scripts, o combina con `&&`: `cd /opt/app && make`.

### 4.2 Listar

```
ls -l          # formato largo
ls -lh         # tamaños humanos (K, M, G)
ls -la         # incluye ocultos (.algo)
ls -lAh        # como -la pero sin . y ..
ls -i          # muestra inodo
ls -lt         # orden por mtime (más reciente primero)
ls -lS         # orden por tamaño
ls --color=auto
```

### 4.3 Copiar, mover, borrar

```
cp src dst                    # copia
cp -a src/ dst/               # archive: preserva permisos, timestamps, symlinks (equiv. -dR --preserve=all)
cp -r src/ dst/               # recursivo (menos cuidado que -a)
cp -i src dst                 # pregunta antes de sobrescribir
cp -n src dst                 # no sobrescribe (no-clobber)

mv old new                    # renombrar o mover
mv -i / -n                    # igual que cp

rm file                       # borra
rm -i file                    # pregunta por cada uno
rm -I file1 file2 file3       # pregunta UNA vez si son >3 archivos [MÁS SEGURO]
rm -r dir/                    # recursivo
rm -rf dir/                   # recursivo + sin preguntas  [PELIGRO]
```

> **Gotcha letal:** `rm -rf $DIR/` con `$DIR` vacío expande a `rm -rf /`. Siempre:
> - usa `set -u` para que una variable sin definir sea error;
> - prefiere `rm -rf -- "${DIR:?missing}"/` (el `:?` aborta si está vacía);
> - nunca uses `rm -rf` sin ruta absoluta explícita en scripts.

### 4.4 Crear

```
mkdir foo              # crea foo
mkdir -p a/b/c         # crea toda la cadena, no falla si existe
touch file.txt         # crea vacío si no existe; actualiza mtime si existe
touch -r ref.txt f     # copia mtime de ref.txt a f
touch -d '2020-01-01' f  # setea mtime arbitrario
```

### 4.5 Enlaces (symlink vs hardlink)

```
ln     target name     # hardlink: dos nombres mismo inodo
ln -s  target name     # symlink: archivo pequeño con la ruta a target
```

| Rasgo | Hardlink | Symlink |
|-------|----------|---------|
| Puede cruzar filesystems | No | Sí |
| Puede apuntar a directorios | No (solo root y limitado) | Sí |
| Si borras el target | el otro nombre sigue válido | queda roto (*dangling*) |
| `ls -l` lo muestra como | archivo normal | `l` + `->` destino |
| `stat` muestra | mismo inodo que target | inodo propio distinto |

### 4.6 `stat` — metadata completa

```
$ stat README.md
  File: README.md
  Size: 1234      Blocks: 8    IO Block: 4096  regular file
Device: 802h/2050d  Inode: 1572864  Links: 1
Access: (0644/-rw-r--r--)  Uid: (1000/evan)  Gid: (1000/evan)
Access: 2026-11-02 10:12:03.000000000 -0600
Modify: 2026-11-01 18:04:21.000000000 -0600
Change: 2026-11-01 18:04:21.000000000 -0600
```

Útil con formato: `stat -c '%s %n' *.log` imprime tamaño y nombre.

---

## 5. Standard I/O y file descriptors

### 5.1 El modelo

Todo proceso UNIX al nacer tiene **tres file descriptors** abiertos:

```
┌─────┬────────┬──────────────────────────────┐
│  fd │ nombre │ destino típico               │
├─────┼────────┼──────────────────────────────┤
│  0  │ stdin  │ teclado (terminal)           │
│  1  │ stdout │ pantalla (terminal)          │
│  2  │ stderr │ pantalla (terminal, no buf.) │
└─────┴────────┴──────────────────────────────┘
```

**La redirección no es "guardar en archivo":** es **reasignar un fd** antes de que el programa arranque. El programa escribe en fd 1 como siempre; Bash hizo que fd 1 apuntara a `out.txt` en vez de a la terminal.

### 5.2 Buffering (importante)

- `stdout` conectado a terminal: *line-buffered* (flush en `\n`).
- `stdout` conectado a archivo o pipe: *block-buffered* (flush cada 4-8 KiB).
- `stderr`: *unbuffered* siempre.

Esto explica por qué `cmd | less` a veces "no muestra nada hasta el final": el pipe cambia el buffering. Workarounds: `stdbuf -oL cmd | less` o `script -q`.

---

## 6. Redirección — matriz completa

| Operador | Qué hace |
|----------|----------|
| `> file` | redirige fd 1 a `file`, **trunca** |
| `>> file` | redirige fd 1 a `file`, **append** |
| `< file` | redirige fd 0 desde `file` |
| `2> file` | redirige fd 2 a `file`, trunca |
| `2>> file` | redirige fd 2 a `file`, append |
| `2>&1` | fd 2 pasa a apuntar al mismo destino que fd 1 **actualmente** |
| `&> file` | redirige fd 1 y fd 2 a `file` (Bash extension; no POSIX) |
| `&>> file` | ídem, append (Bash ≥ 4) |
| `>&-` | cierra fd 1 |
| `n> file` | redirige fd `n` (p. ej. `3> log`) |
| `<<< "text"` | *here-string*: pasa la cadena como stdin |
| `<<EOF ... EOF` | *here-doc*: pasa el bloque como stdin (con expansión) |
| `<<'EOF' ... EOF` | here-doc **sin** expansión de variables |
| `<<-EOF ... EOF` | here-doc que elimina tabs iniciales (indentación) |

### 6.1 El orden importa (`2>&1` sutileza)

```
cmd > out.txt 2>&1
# 1) fd 1 pasa a out.txt
# 2) fd 2 copia donde "está ahora fd 1" -> out.txt
# Resultado: ambos a out.txt. CORRECTO.

cmd 2>&1 > out.txt
# 1) fd 2 copia donde "está fd 1 ahora" -> terminal
# 2) fd 1 pasa a out.txt
# Resultado: stdout en out.txt, stderr sigue en terminal. BUG común.
```

Regla: **primero rediriges fd 1, luego duplicas fd 2**.

### 6.2 `&>` vs `> ... 2>&1`

```
cmd &> out.txt           # Bash-only, legible
cmd > out.txt 2>&1       # POSIX, portable
```

En scripts para distribuir públicamente prefiere la forma POSIX. En uso interactivo, `&>` es más corta.

### 6.3 Here-doc y here-string

```
cat <<EOF
HOME es $HOME
EOF
# -> expande variables

cat <<'EOF'
HOME es $HOME
EOF
# -> literal, imprime "$HOME"

cat <<-EOF
    indentado con TABS; los tabs iniciales se quitan
    EOF
# -> útil dentro de funciones indentadas (OJO: tabs, no espacios)

grep foo <<< "foo bar baz"
# -> here-string: equivalente a `echo "foo bar baz" | grep foo` pero sin fork extra
```

---

## 7. Pipes y pipelines

### 7.1 `|` — conectar procesos

```
cmd1 | cmd2
```

Semánticamente: Bash crea un *pipe* (buffer en kernel), hace fork de ambos, redirige fd 1 de `cmd1` al extremo write del pipe y fd 0 de `cmd2` al extremo read. Corren **en paralelo**; `cmd2` lee a medida que `cmd1` escribe. Si `cmd2` termina antes, `cmd1` recibe `SIGPIPE` al próximo write.

### 7.2 `|&` — pipe de stdout+stderr

```
cmd1 |& cmd2
# equivalente a:
cmd1 2>&1 | cmd2
```

Útil para capturar ambos streams en el siguiente comando (`cmd |& tee log.txt`).

### 7.3 Exit status y `pipefail`

Por default, el exit status de una pipeline es el del **último** comando. Esto oculta fallos intermedios:

```
$ false | true
$ echo $?
0           # ¡El 'false' falló pero no te enteras!
```

Solución:

```
$ set -o pipefail
$ false | true
$ echo $?
1
```

Con `pipefail`, el exit code es el del **último comando que falló** (o 0 si todos pasaron). El array `PIPESTATUS` tiene los códigos individuales:

```
$ false | true | true
$ echo "${PIPESTATUS[@]}"
1 0 0
```

**Baseline recomendado al tope de todo script:**

```
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

- `-e`: aborta al primer comando con exit ≠ 0.
- `-u`: variable sin definir es error.
- `-o pipefail`: pipelines propagan fallos.
- `IFS=$'\n\t'`: evita *word splitting* por espacios inesperados.

### 7.4 `tee` — bifurcar un stream

```
cmd | tee log.txt            # imprime en pantalla Y guarda en log.txt
cmd | tee -a log.txt         # append
cmd | tee log1 log2 >/dev/null  # múltiples destinos, sin pantalla
cmd 2>&1 | tee log.txt       # combina stderr+stdout y logea
cmd | tee >(grep ERROR > errors.log) | less   # process substitution
```

Usos típicos: auditoría de instalaciones (`./configure 2>&1 | tee build.log`), guardar logs sin perder la vista en vivo.

---

## 8. Variables: shell vs entorno

### 8.1 Dos espacios distintos

```
$ FOO=hello           # variable de SHELL (no exportada)
$ echo $FOO
hello
$ bash -c 'echo "en el hijo: $FOO"'
en el hijo:            # vacío: el hijo NO la ve

$ export FOO           # ahora entra al environ
$ bash -c 'echo "en el hijo: $FOO"'
en el hijo: hello

$ export BAR=world     # declara y exporta a la vez
$ FOO=temp bash -c 'echo $FOO'   # asignación "inline" solo para ese cmd
temp
$ echo $FOO
hello                  # la shell actual no cambió
```

### 8.2 Herramientas de inspección

| Comando | Qué muestra |
|---------|-------------|
| `env` | solo variables exportadas (del `environ` actual) |
| `printenv` | ídem; `printenv FOO` imprime una sola |
| `set` | shell + env + funciones; muy ruidoso |
| `declare -p` | formato declarativo; `declare -p FOO` muestra atributos |
| `declare -x` | solo exportadas (equiv. a `export -p`) |
| `export -p` | lista exports con sintaxis reutilizable |
| `unset FOO` | borra la variable |
| `unset -f fn` | borra una función |

### 8.3 Variables canónicas

| Variable | Qué contiene |
|----------|--------------|
| `PATH` | lista de directorios separados por `:` donde Bash busca ejecutables |
| `HOME` | directorio home del usuario |
| `PWD` / `OLDPWD` | cwd actual / anterior |
| `SHELL` | shell de login configurada (no necesariamente la que corres ahora) |
| `USER` / `LOGNAME` | usuario |
| `LANG` / `LC_ALL` / `LC_*` | locale (idioma, codificación, formatos) |
| `TERM` | tipo de terminal (para `ncurses`, colores) |
| `EDITOR` / `VISUAL` | editor preferido |
| `TMPDIR` | directorio para archivos temporales |
| `IFS` | *internal field separator* para word splitting |

### 8.4 `PATH` sin romperlo

```
# Mal: machaca PATH y pierdes acceso a /usr/bin, /bin
PATH=/opt/mytool/bin

# Bien: prepend
PATH="/opt/mytool/bin:$PATH"

# Bien: append (menor prioridad)
PATH="$PATH:/opt/mytool/bin"

# Comprobar
echo "$PATH" | tr ':' '\n'
```

> **Gotcha:** nunca pongas `.` en `PATH`. Un atacante que logre dejar un ejecutable `ls` en `/tmp` puede engañarte si estás en `/tmp` y tecleas `ls`.

### 8.5 Locale: por qué importa

```
$ LC_ALL=C sort nombres.txt   # orden byte-a-byte, estable
$ LC_ALL=es_ES.UTF-8 sort nombres.txt   # orden lingüístico (ñ, acentos)
```

Scripts para pipeline reproducibles: `export LC_ALL=C` al principio evita que diferencias de locale cambien el output de `sort`, `date`, `grep`, etc.

---

## 9. Trade-offs

### 9.1 `&>` vs `> file 2>&1`

**`&>`:**
- Más corto, legible.
- Bash-only — no funciona en `/bin/sh` POSIX, no en dash.
- OK en scripts con `#!/usr/bin/env bash`.

**`> file 2>&1`:**
- POSIX portable (sh, dash, ash, busybox).
- Expresa explícitamente el orden.
- Preferir en scripts que puedan correr con `sh`.

### 9.2 `set -e` sí/no

**Sí:** scripts cortos, pipelines de automatización, CI. Previene seguir ejecutando con estado corrupto.

**Cuidado:** `set -e` tiene *gotchas* reales — no aborta dentro de `if`, no aborta si el comando falla en `cmd || true`, interactúa raro con subshells. Para scripts complejos, hay quien prefiere manejo explícito de errores con `||` + `return`. La regla pragmática: **úsalo por default, aprende sus excepciones**.

### 9.3 Alias vs función vs script

| Opción | Cuándo |
|--------|--------|
| Alias | atajo de 1 línea sin argumentos complejos (`alias ll='ls -lah'`). |
| Función | lógica con argumentos, condicional (`gco() { git checkout "$@"; }`). |
| Script en `$PATH` | reutilizable fuera de esta shell, llamable desde otros scripts. |

Los aliases **no se expanden** en scripts no interactivos. Los scripts se ejecutan en una **subshell nueva** — no heredan tus funciones a menos que las `export -f`.

### 9.4 `.bashrc` vs `.bash_profile`

- **Login shells** (SSH, `su - user`): leen `/etc/profile` → `~/.bash_profile` (o `.bash_login`, o `.profile`).
- **Non-login interactive** (abrir terminal en escritorio): leen `~/.bashrc`.

Patrón común: `~/.bash_profile` carga `~/.bashrc` para no duplicar.

```
# ~/.bash_profile
[ -r ~/.bashrc ] && . ~/.bashrc
```

---

## 10. Errores frecuentes

### 10.1 `cmd > out 2>&1` vs `cmd 2>&1 > out`

Ya cubierto en §6.1 — es el bug #1 de principiantes. Memoriza el orden.

### 10.2 "Mi variable no llega al script hijo"

Síntoma: `FOO=bar; ./script.sh` y dentro `echo "$FOO"` imprime vacío.

Causa: no exportaste. Fix: `export FOO=bar` o `FOO=bar ./script.sh` (asignación inline).

### 10.3 "Edito `.bashrc` pero no se aplica"

El `.bashrc` se lee al abrir shell. Para aplicar cambios: `source ~/.bashrc` (o `. ~/.bashrc`). Para que las shells nuevas lo tengan: ya está — abres una nueva.

### 10.4 "`rm *` me borró archivos ocultos / no me borró archivos ocultos"

Default: `*` no matchea archivos que empiezan con `.`. Si quieres incluirlos: `shopt -s dotglob` o explicita `rm .* *` (**peligroso**: `.*` matchea `.` y `..` en Bash viejas; usa `rm -rf -- .[!.]* ..?* *` con cuidado o mejor `find`).

### 10.5 "`PATH` roto, no funciona ni `ls`"

Si asignaste `PATH=/opt/mytool/bin` sin incluir el PATH anterior, perdiste acceso a los coreutils. Fix en la shell actual:

```
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Y revisa qué archivo lo rompe (`.bashrc`, `.profile`).

### 10.6 "El pipeline reporta éxito pero el primer paso falló"

Falta `set -o pipefail`. Añádelo. Para debugging puntual: `echo "${PIPESTATUS[@]}"`.

### 10.7 "`cd` en un script no cambia mi directorio"

Un script corre en un **proceso hijo**. El `cd` del hijo no afecta al padre. Si lo que quieres es cambiar el cwd de la shell actual, usa una **función** (que corre en la shell actual) o `source script.sh` (el script se evalúa en la shell actual, no en un hijo).

### 10.8 "`echo $VAR` imprime lo que no esperaba por el glob"

Si `VAR='foo *.txt'`, un `echo $VAR` expande el `*` contra el cwd. Siempre **quotea**: `echo "$VAR"`.

---

## 11. Buenas prácticas

- **Scripts siempre empiezan con:**
  ```
  #!/usr/bin/env bash
  set -euo pipefail
  IFS=$'\n\t'
  ```
- **Quotea variables.** `"$var"`, no `$var`. Siempre.
- **`[[ ... ]]` en Bash, `[ ... ]` solo si necesitas POSIX.** `[[` no hace word-splitting, soporta `=~`, `&&`, `||`.
- **Prefiere `$()` a `` ` ` ``.** Anidable, legible.
- **Nunca `curl ... | bash` sin leer antes.**
- **`set -o noclobber`** si editas interactivamente mucho — evita que `>` sobrescriba por accidente (puedes forzar con `>|`).
- **`HISTCONTROL=ignoredups:erasedups`** y `shopt -s histappend` para historial sano entre múltiples terminales.
- **Timestamps en history** (`HISTTIMEFORMAT='%F %T '`) — luego lo agradeces en incidentes.
- **`shellcheck` sobre cada script.** Es el `pylint` de Bash.
- **Loguea pipelines críticos** con `tee`: `./deploy.sh 2>&1 | tee -a /var/log/deploy.log`.
- **Nunca mezcles tabs y espacios** en here-docs `<<-`.

---

## 12. Mental model (resumen)

Si vas a quedarte con tres ideas:

1. **Todo es un proceso con una tabla de fds.** La redirección reasigna los fds antes del `exec`. El pipe conecta el fd 1 de uno al fd 0 del siguiente.
2. **Shell variable ≠ environment variable.** Solo lo *exportado* viaja a los hijos.
3. **Builtin vs externo cambia qué `fork()` ocurre.** `cd`, `export`, `read` modifican la shell actual; `ls`, `grep`, `awk` corren en hijos. `type -a` te dice qué es qué.

Con esos tres pilares, cualquier operador se deduce. No memorizas: razonas.

---

## Ejercicios recomendados

1. **`activities/01-cli-tour/`** — guided-lab: tour por navegación, archivos e historial. Construyes tu `PS1` y tu `.bashrc` útil.
2. **`activities/02-io-redirection-dojo/`** — independent: ocho ejercicios de redirección, pipes, `tee`, `pipefail` y variables de entorno. Validados por script.

---

## Evaluación

Responde sin consultar.

**P1.** Explica **paso a paso** qué hace Bash al ejecutar:
```
ls -l /tmp | grep foo > out.txt 2>&1
```
Menciona fork, exec, pipes y fd dup.

**P2.** Diferencia **en una frase cada una**:
- `FOO=bar cmd`
- `export FOO=bar; cmd`
- `FOO=bar; cmd`
- `FOO=bar; export FOO; cmd`

**P3.** ¿Por qué `cd` **tiene que ser** un builtin y no un ejecutable externo?

**P4.** Verdadero / falso:
- [ ] `cmd &> out.txt` es equivalente POSIX a `cmd > out.txt 2>&1`.
- [ ] `cmd 2>&1 > out.txt` manda stderr a `out.txt`.
- [ ] `which ls` ve los aliases.
- [ ] `set -e` aborta el script si `grep foo file` no encuentra nada.
- [ ] Un script lanzado con `./s.sh` hereda las variables **no** exportadas de la shell que lo llamó.

**P5.** Tienes un pipeline `A | B | C` y necesitas saber si `A` falló (aunque `C` haya terminado bien). ¿Cómo lo averiguas?

**P6.** Diseña un one-liner que corra `make build`, capture tanto stdout como stderr en `build.log` **y** siga viendo la salida en vivo en la terminal, abortando si `make` falla.

**P7.** Explica por qué este script es peligroso y propón 3 defensas:
```
#!/bin/bash
DIR=$1
rm -rf $DIR/*
```

**P8.** `type -a echo` reporta dos resultados. ¿Cuál se ejecuta cuando tecleas `echo hola` y por qué?

---

## Referencias

- *GNU Bash Reference Manual*. <https://www.gnu.org/software/bash/manual/>
- POSIX Shell Command Language. <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html>
- `bash(1)`, `builtins(7)`, `readline(3)` manpages.
- *Bash Hackers Wiki*. <https://wiki.bash-hackers.org/>
- *Greg's Wiki (BashGuide, BashFAQ, BashPitfalls)*. <https://mywiki.wooledge.org/>
- *Google Shell Style Guide*. <https://google.github.io/styleguide/shellguide.html>
- `shellcheck`. <https://www.shellcheck.net/>
