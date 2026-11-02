# Lección: Fundamentos de Bash scripting

> **ID:** `sys-13-bash-scripting-fundamentals` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `sys-01-bash-cli-foundations`, `sys-02-shell-command-anatomy`.

---

## 1. Introducción intuitiva

Hasta ahora, cuando necesitas hacer "una cosa con la shell" la tecleas directamente: `ls -la | grep ssh`, `tar -czf backup.tgz /etc`, `curl -s https://api.example.com | jq .status`. Funciona. Es inmediato. Y es **frágil**: mañana no recuerdas la receta exacta, un compañero no la encuentra, y cuando la pegas en un chat alguien la ejecuta con un parámetro distinto porque "esta vez el servidor es otro".

Un **script** resuelve ese problema. Un script es, en su mínima expresión, un archivo de texto con comandos de shell y un indicador al principio (el *shebang*) que le dice al kernel qué intérprete usarlos. Pero esa definición mínima es trampa: *cualquier* bloque de comandos pegado dentro de un archivo "funciona" la primera vez; el reto es que **siga funcionando** cuando el entorno cambia: cuando el usuario pasa un nombre con un espacio, cuando una variable no está definida, cuando el filesystem está lleno, cuando el pipe de un comando intermedio falla.

Este módulo cubre la mitad **estática** del scripting: cómo convertir una línea de comandos en un script parametrizado y seguro. La mitad **dinámica** (ramas, bucles, funciones, señales) viene en los módulos siguientes. La separación es deliberada: la mayoría de scripts rotos en producción fallan por mal quoting o parámetros ausentes, no por falta de bucles.

---

## 2. Fundamentos

Tres piezas que un script Bash siempre tiene — explícitas o implícitas:

### 2.1 El shebang

La primera línea de un script ejecutable, cuando empieza por `#!`, es interpretada por el kernel Linux (concretamente por `execve(2)`). El kernel lee hasta un máximo (típicamente 256 bytes), extrae la ruta al intérprete, y le pasa el script como argumento.

```bash
#!/usr/bin/env bash
```

Dos opciones comunes:

- **`#!/bin/bash`** — directa, rápida. Funciona *si* Bash está en `/bin/bash`. En macOS moderno Bash está en `/opt/homebrew/bin/bash` (Apple Silicon) o `/usr/local/bin/bash` (Intel) porque la licencia GPLv3 lo mantuvo fuera del sistema base; `/bin/bash` existe pero es Bash 3.2 de 2007.
- **`#!/usr/bin/env bash`** — pide al comando `env` que busque `bash` en el `PATH`. Portable entre Linux, macOS, BSD. Es la **recomendación de la Google Shell Style Guide** y la que usaremos.

Sin shebang, un script sigue "funcionando" si lo invocas con `bash script.sh` — pero no si lo ejecutas directamente (`./script.sh`): el kernel no sabe qué intérprete usar y suele caer al shell del padre, lo que convierte el script en una ruleta rusa de portabilidad.

### 2.2 Permisos de ejecución

Un archivo de texto, por sí mismo, no es ejecutable. El bit `x` del modo del archivo (en el sistema de permisos POSIX) es lo que lo convierte en candidato a `execve`. Se añade con:

```bash
chmod +x script.sh
```

El flag `+x` da permiso de ejecución a *todos* los conjuntos relevantes (owner, group, others, filtrado por `umask`). Para ser más explícito:

```bash
chmod 755 script.sh   # rwxr-xr-x
chmod 700 script.sh   # rwx------  (solo owner, útil si contiene secretos)
```

Después, `./script.sh` lanza el shebang. Sin el bit `x`, obtienes `Permission denied` — error frecuente al clonar un repo donde los permisos no se preservaron (ej. a través de un zip).

### 2.3 Modos estrictos (`set -euo pipefail`)

Por defecto, Bash es **permisivo**: si un comando falla, el script continúa; si una variable no existe, se expande a vacío; si el primer comando de un pipe falla, el pipe reporta éxito mientras el último sea OK. Para scripts serios esto es un desastre silencioso.

Los *strict modes* que debes añadir en toda `#!` nueva:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- **`-e` (errexit)**: aborta el script si cualquier comando sale con código distinto de 0 (con algunas excepciones: condiciones de `if`, operandos de `&&`/`||`, lado izquierdo de pipes).
- **`-u` (nounset)**: tratar variable no definida como error y abortar. Fuerza a declarar o usar defaults explícitos.
- **`-o pipefail`**: el código de salida de un pipe es el del *primer* comando que falla (de izquierda a derecha), no solo el del último.

Con estos tres, un script falla *ruidosamente* cuando algo va mal, en vez de seguir ciego. Esto no sustituye manejo de errores (ver `sys-14`), pero evita el 80% de los fallos silenciosos.

---

## 3. Contexto histórico

El shell Bourne original (`sh`, 1977, Stephen Bourne) ya era *scriptable*: cualquier secuencia de comandos interactivos podía guardarse en archivo e invocarse. No había shebang todavía: el shell detectaba archivos de texto y los interpretaba.

El **shebang** nació en 1980, inventado por Dennis Ritchie para la versión 8 de Research Unix: una línea mágica que indica al kernel qué intérprete usar. Permitió coexistencia de `sh`, `csh`, `perl`, `python`, `awk`, etc. en el mismo sistema sin convenciones implícitas.

**Bash** (Bourne-Again SHell, Brian Fox, 1989) nació como reemplazo libre del `sh` de AT&T para el proyecto GNU. Es superconjunto POSIX: todo script POSIX válido corre en Bash, pero no al revés — Bash añade arrays, `[[ ]]`, aritmética `(( ))`, expansión de parámetros extendida, procesos sustituidos `<(cmd)`, etc.

En producción moderna conviven tres variantes:

- **`sh` POSIX** — el mínimo común denominador. Scripts de init, `/etc/profile`, hooks de paquetes.
- **`bash`** — el estándar de facto en Linux y la mayoría de contenedores.
- **`zsh`, `fish`, `dash`** — shells interactivas o POSIX minimalistas (Debian apunta `/bin/sh` a `dash` por velocidad; Alpine usa `ash` de BusyBox).

Un script `#!/usr/bin/env bash` asume Bash disponible. Si necesitas portabilidad total (Alpine mínima, routers), escribe POSIX puro y usa `#!/bin/sh`.

---

## 4. Parámetros posicionales

Un script recibe argumentos como variables numeradas:

| Variable | Significado |
|----------|-------------|
| `$0` | Nombre del script (como fue invocado: `./script.sh`, `/usr/local/bin/script.sh`). Útil para mensajes de uso. |
| `$1`..`$9` | Primer a noveno argumento posicional. |
| `${10}`, `${11}`, ... | Décimo en adelante. **Obligatorias las llaves** — `$10` se expande como `${1}0` (primer argumento concatenado con "0"). |
| `$#` | Número de argumentos pasados. |
| `$@` | Todos los argumentos, cada uno un elemento separado (si se usa entre comillas: `"$@"`). |
| `$*` | Todos los argumentos como una sola cadena, separados por el primer carácter de `IFS` (por defecto espacio). |
| `$$` | PID del script actual. |
| `$?` | Código de salida del último comando ejecutado. |

**Regla práctica**: para iterar argumentos preservando espacios y entidades, usa siempre `"$@"` (entre comillas, con `@`). Nunca `$*` ni `$@` sin comillas.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Script: $0"
echo "Argumentos: $#"
echo "Primero: $1"
echo "Décimo: ${10}"

for arg in "$@"; do
  echo "  - $arg"
done
```

Ejecución:

```bash
./demo.sh a b c d e f g h i j
# Script: ./demo.sh
# Argumentos: 10
# Primero: a
# Décimo: j
#   - a
#   - b
#   ... (uno por línea)
```

---

## 5. Variables de shell

Asignación:

```bash
name="Ana"           # OK — sin espacios alrededor de '='
name = "Ana"         # ERROR — Bash interpreta `name` como comando
```

Lectura: `$name` o — preferido en scripts — `"${name}"`. Las llaves hacen el límite de la variable inequívoco:

```bash
echo "$namefile"     # Bash busca variable 'namefile' — probablemente vacía
echo "${name}file"   # expande 'name' y concatena 'file'
```

### Scope

Por defecto, variables son **globales al script** (y a las funciones). Para variables locales a una función se usa `local`:

```bash
greet() {
  local who="$1"
  echo "Hola, $who"
}
```

### `export`

`export VAR` marca la variable para que se herede en **subprocesos**. Sin `export`, variables son invisibles para comandos externos:

```bash
API_KEY="xxx"
printenv API_KEY        # vacío — printenv es un proceso hijo

export API_KEY="xxx"
printenv API_KEY        # xxx
```

En scripts, exporta solo lo que un hijo necesita leer; mantener el resto sin exportar reduce leaks accidentales (p. ej. secretos en subshells o pipes a herramientas externas).

---

## 6. Quoting — el 80% de los bugs de scripts

La shell hace varias transformaciones *antes* de ejecutar un comando: expansión de variables, expansión de brace, globbing, word splitting, expansión de comandos (`$(...)`), expansión aritmética (`$((...))`). El quoting es cómo controlas cuáles ocurren.

### 6.1 Cheatsheet

| Forma | Expande variables | Expande comandos | Globbing | Word split | Uso típico |
|-------|:----------------:|:---------------:|:--------:|:----------:|------------|
| `foo` (sin comillas) | Sí | Sí | **Sí** | **Sí** | Nunca con datos de usuario. Solo con literales seguros o nombres construidos por ti. |
| `'foo'` (simples) | **No** | **No** | No | No | Strings literales, patrones regex, código a eval posterior, mensajes exactos. |
| `"foo"` (dobles) | Sí | Sí | No | No | **Default sano** para interpolación. Siempre que incluyas `$var`, entre dobles. |
| `` `foo` `` o `$(foo)` | — | Sí | — | — | Captura la salida de un comando. Prefiere `$(...)` — anida bien y es legible. |

**Regla operativa**: `"${var}"` en toda interpolación. Comillas simples para strings sin variables. Sin comillas, solo en casos *conscientes* (p. ej. cuando quieres que un `$list` se separe en palabras — raro, probablemente ya quieras un array).

### 6.2 Casos canónicos

**Nombres con espacios**:

```bash
file="mi archivo.txt"
rm $file         # ERROR — rm recibe DOS argumentos: 'mi' y 'archivo.txt'
rm "$file"       # OK — rm recibe UN argumento: 'mi archivo.txt'
```

**Globs no deseados**:

```bash
pattern="*.log"
echo $pattern      # expande el glob en el CWD si hay .log
echo "$pattern"    # imprime literalmente *.log
```

**Newlines en nombres de archivo** (sí, es legal en POSIX):

```bash
find . -type f -print          # frágil, se rompe con newlines
find . -type f -print0 | xargs -0 ...   # robusto
```

**Expresiones a `eval` o `ssh`**: siempre comillas simples para no interpolar en el shell local.

```bash
ssh host "echo $HOME"      # expande $HOME LOCAL, no remoto
ssh host 'echo $HOME'      # expande $HOME REMOTO (lo que normalmente quieres)
```

### 6.3 Error favorito: `$(cmd)` sin comillas

```bash
cp $(find /tmp -name "*.txt") /backup/   # roto si algún nombre tiene espacio
```

La salida de `find` se divide por word splitting. Para esto existen patrones robustos (`-exec`, `-print0 | xargs -0`, loops `while read`) que verás en `sys-14`.

---

## 7. Expansión de parámetros

Bash tiene una familia de expansiones que combinan "leer una variable" con "hacer algo si no existe". Son más expresivas que un `if` equivalente.

### 7.1 Tabla principal

Sea `var` una variable que puede estar: definida con valor, definida vacía (`var=""`), o no definida.

| Forma | Si `var` definida y no vacía | Si `var` vacía o no definida |
|-------|-------------------------------|-------------------------------|
| `${var:-default}` | Usa `$var` | Expande a `default`. **No asigna.** |
| `${var-default}` | Usa `$var` | Si no definida: `default`. Si vacía: `""`. |
| `${var:=default}` | Usa `$var` | **Asigna** `default` a `var` y lo usa. No sirve con `$1..$9` (no son asignables). |
| `${var:?error msg}` | Usa `$var` | **Aborta** el script e imprime `error msg` por stderr. |
| `${var:+alt}` | Expande a `alt` | Expande a `""`. Útil para "añadir sufijo solo si la variable existe". |

Variante sin `:` ignora el caso vacío (solo trata "no definida").

### 7.2 Ejemplos

```bash
# Default si falta el argumento
name="${1:-mundo}"
echo "Hola, $name"
# ./demo.sh          -> Hola, mundo
# ./demo.sh Ana      -> Hola, Ana
```

```bash
# Fallar si falta argumento, con mensaje claro
host="${1:?Uso: $0 <host> [port]}"
port="${2:-22}"
ssh -p "$port" "$host"
```

```bash
# Definir una variable solo si está vacía
: "${TMPDIR:=/tmp}"       # 'ensure TMPDIR has a value'
# El ':' inicial es el comando no-op; usamos la expansión por su efecto lateral (asigna).
```

```bash
# Añadir un flag condicional
VERBOSE="${VERBOSE:+-v}"
rsync $VERBOSE src/ dst/     # expande a '-v' si VERBOSE está definida, '' si no
```

### 7.3 Otras expansiones útiles (vistazo)

Las verás con detalle en `sys-15`, pero conviene saber que existen:

- `${#var}` — longitud en caracteres.
- `${var#pattern}` / `${var##pattern}` — recorte por el principio (corto / largo).
- `${var%pattern}` / `${var%%pattern}` — recorte por el final.
- `${var/old/new}` / `${var//old/new}` — reemplazo (primero / todos).
- `${var:offset:length}` — substring.

```bash
file="/etc/nginx/nginx.conf"
echo "${file##*/}"     # nginx.conf   (nombre base)
echo "${file%/*}"      # /etc/nginx   (directorio)
echo "${file%.conf}"   # /etc/nginx/nginx  (quita sufijo)
```

Son más rápidas que llamar `basename`/`dirname`/`sed` porque evitan procesos externos.

---

## 8. Interpolación segura

Regla de oro, repetida porque es la causa #1 de bugs de shell:

> **Siempre entrecomilla variables cuando pueden contener espacios, globs o input de usuario.**

```bash
# MAL
rm $filename
cp $src $dst
if [ $USER = root ]; then ...

# BIEN
rm -- "$filename"
cp -- "$src" "$dst"
if [ "$USER" = "root" ]; then ...
```

El `--` separa flags de operandos, protegiendo contra nombres que empiezan con `-` (p. ej. un archivo llamado `-rf`).

Con `set -u`, usar una variable no definida aborta el script — útil para detectar typos:

```bash
set -u
name=Ana
echo "$nam"      # aborta: nam: unbound variable
```

Combinado con la expansión `${var:?msg}`, puedes exigir explícitamente que ciertas variables estén definidas:

```bash
: "${DATABASE_URL:?DATABASE_URL es obligatoria}"
```

---

## 9. `printf` vs `echo` — por qué `printf` gana

`echo` parece simple pero su comportamiento varía entre shells y plataformas:

- `echo -n` suprime newline en Bash y zsh — pero algunos `/bin/sh` lo interpretan literalmente.
- `echo -e` activa escapes (`\n`, `\t`) en Bash — pero no en POSIX puro.
- `echo "-n"` como contenido real: imposible en algunos shells.

```bash
echo "primer\nsegundo"      # imprime 'primer\nsegundo' literalmente (sin -e)
echo -e "primer\nsegundo"   # dos líneas (en Bash)
```

**`printf`** es portable, siempre interpreta escapes, y toma un *format string* al estilo C:

```bash
printf 'Hola, %s. Tienes %d años.\n' "Ana" 30
# Hola, Ana. Tienes 30 años.

printf '%-10s %5d\n' "cpu" 12 "mem" 1024 "disk" 54
# cpu            12
# mem          1024
# disk           54
```

Nota: `printf` **reutiliza** el format string si hay más argumentos — por eso el ejemplo anterior imprime tres líneas con un único formato de dos columnas.

Para formato estructurado, logs legibles, columnas alineadas, o cualquier cosa con `\n`/`\t`: **usa `printf`**. Reserva `echo` para mensajes triviales de una línea sin interpretación.

### 9.1 Trampas específicas de `printf`

- `printf "$msg"` interpreta `$msg` como format string: si contiene `%`, truena. Correcto: `printf '%s\n' "$msg"`.
- Para booleanos o enums, los especificadores `%b` (con escapes) y `%q` (shell-quoted, útil para debugging) ayudan.

---

## 10. Conversión paso a paso: de one-liner a script parametrizado

Partamos de este one-liner que un sysadmin pega en el chat:

```bash
tar -czf /tmp/backup-$(date +%F).tgz /etc/nginx
```

Funciona hoy. Problemas al convertirlo a algo reutilizable: directorio origen hardcoded, destino hardcoded, nombre del backup hardcoded, sin validación, sin errores.

### Paso 1 — Encapsular en un script con shebang y modo estricto

```bash
#!/usr/bin/env bash
set -euo pipefail

tar -czf /tmp/backup-$(date +%F).tgz /etc/nginx
```

Guardar como `backup.sh`, `chmod +x backup.sh`. Ya es ejecutable, pero sigue siendo rígido.

### Paso 2 — Parametrizar la fuente

```bash
#!/usr/bin/env bash
set -euo pipefail

src="${1:?Uso: $0 <directorio-origen> [destino]}"
tar -czf "/tmp/backup-$(date +%F).tgz" "$src"
```

Ahora `./backup.sh /etc/nginx` funciona, y `./backup.sh` sin argumentos imprime un error de uso claro.

### Paso 3 — Default sensato para destino

```bash
#!/usr/bin/env bash
set -euo pipefail

src="${1:?Uso: $0 <directorio-origen> [destino-dir]}"
dst_dir="${2:-/tmp}"
timestamp="$(date +%F)"
name="$(basename -- "$src")"
dst="${dst_dir}/${name}-${timestamp}.tgz"

tar -czf "$dst" "$src"
printf 'Backup creado: %s\n' "$dst"
```

Cambios clave:
- `${2:-/tmp}` — default si no se pasa.
- `basename "$src"` para nombrar según el origen, no hardcoded a "backup".
- Toda interpolación entre comillas dobles.
- `--` en `basename` evita que `src` empezando por `-` se interprete como flag.
- `printf` para el mensaje final (sabe exactamente qué formato tendrá).

### Paso 4 — Validación mínima

```bash
#!/usr/bin/env bash
set -euo pipefail

src="${1:?Uso: $0 <directorio-origen> [destino-dir]}"
dst_dir="${2:-/tmp}"

[[ -d "$src" ]] || { printf 'Error: %s no es un directorio\n' "$src" >&2; exit 2; }
[[ -d "$dst_dir" && -w "$dst_dir" ]] || { printf 'Error: %s no es un directorio escribible\n' "$dst_dir" >&2; exit 2; }

timestamp="$(date +%F)"
name="$(basename -- "$src")"
dst="${dst_dir}/${name}-${timestamp}.tgz"

tar -czf "$dst" "$src"
printf 'Backup creado: %s\n' "$dst"
```

Falla rápido con stderr claro si la entrada es inválida. (Las condiciones `[[ ]]` y `if` las profundizamos en `sys-14`; aquí basta saber que validan.)

Este es el patrón: **shebang + modo estricto + parámetros nombrados por `${:-}`/`${:?}` + interpolación segura + `printf` para output + validación básica**. Todo lo demás son extensiones.

---

## 11. Estilo y comentarios (Google Shell Style Guide)

La [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) es el estándar informal del ecosistema. Reglas que importan para este módulo:

- **Shebang**: `#!/usr/bin/env bash`. Para `sh` POSIX: `#!/bin/sh`.
- **Modo estricto**: `set -euo pipefail` justo después del shebang.
- **Indentación**: 2 espacios, nunca tabs.
- **Nombres de variables**: `snake_case` para locales, `UPPER_CASE` para constantes y exportadas.
- **Comillas**: siempre dobles para interpolación. Simples cuando no haya expansión.
- **Comentarios de archivo**: bloque al principio con propósito, uso, dependencias.
- **`shellcheck`**: obligatorio en CI, no debe quedar warning sin justificar (`# shellcheck disable=SCxxxx` con razón).

Ejemplo de cabecera:

```bash
#!/usr/bin/env bash
#
# backup.sh — crea un tarball con timestamp de un directorio dado.
#
# Uso:
#   backup.sh <directorio-origen> [destino-dir]
#
# Dependencias: tar, date, basename.

set -euo pipefail
```

Comentarios *dentro* del código: explica el **porqué**, no el **qué**. Si el código ya dice qué hace (`tar -czf ...`), no agregues `# ejecuta tar`. Pero si usas una expansión críptica (`${file##*/}`) añade `# nombre base del archivo`.

---

## 12. Preguntas de reflexión

1. ¿Por qué `#!/usr/bin/env bash` es preferible a `#!/bin/bash` cuando el script debe correr tanto en Linux como en macOS?
2. Explica la diferencia operativa entre `${var:-x}` y `${var:=x}`. ¿Por qué el segundo no funciona con `$1`?
3. Tienes un archivo llamado `informe final.pdf` (con espacio). Escribe la forma correcta e incorrecta de pasarlo a `cp` dentro de un script. ¿Qué pasa en cada caso?
4. ¿Qué devuelve `$10` dentro de un script y por qué? ¿Cómo accedes al décimo argumento correctamente?
5. ¿En qué caso elegirías `echo` sobre `printf`? Justifica con un ejemplo donde `echo` sea defendible y uno donde `printf` sea obligatorio.
6. Un script tiene `set -euo pipefail`. En `curl -s https://api.example.com | jq .data` el `curl` falla pero `jq` recibe entrada vacía y sale OK. ¿El script aborta? ¿Por qué?
7. ¿Cuál es la diferencia entre `"$@"` y `"$*"` al pasar los argumentos del script a otro comando? Da un ejemplo donde la elección cambie el resultado.
8. Añade una línea al inicio de un script que exija que `DATABASE_URL` esté definida y aborte con un mensaje si no lo está. (Pista: `${var:?msg}`.)

---

## 13. Resumen operativo

Toda plantilla de script nueva en este curso parte de:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Parámetros
arg1="${1:?Uso: $0 <arg1> [arg2]}"
arg2="${2:-default_value}"

# Lógica
printf 'Procesando %s con opción %s\n' "$arg1" "$arg2"
```

Si recuerdas solo cinco cosas de esta lección:

1. `#!/usr/bin/env bash` + `set -euo pipefail` + `chmod +x`.
2. Siempre `"${var}"` en interpolación.
3. `${var:-default}` para default, `${var:?msg}` para abortar.
4. `printf '%s\n' "$msg"` para output; `echo` solo para mensajes triviales.
5. Pasa el script por `shellcheck` antes de dar por "terminado".

El resto es construir encima.
