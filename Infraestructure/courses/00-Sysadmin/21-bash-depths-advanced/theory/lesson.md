# sys-21 — Bash en profundidad: internals para los casos difíciles

> **Para quién es esta lección.** Para quien ya escribe scripts correctos con `set -euo pipefail`, usa funciones, redirecciona bien, y aun así tropieza con bugs donde "no entiendo por qué Bash hace eso". La respuesta casi siempre está en el **orden de expansión** y en qué operadores existen. Esta lección es la que convierte a un usuario de bash en alguien que lee el manual de Bash sin perderse.

---

## 1. Mapa mental: Bash como motor de transformaciones de texto

Bash **no** ejecuta la línea que escribes. Ejecuta la línea **después de aplicarle una pipeline de transformaciones**. Casi todos los bugs "raros" aparecen porque imaginaste el estado post-transformación equivocado.

El contrato es:

1. Lees la línea como **texto**.
2. Bash la tokeniza y aplica, en un **orden fijo**, varias etapas de expansión.
3. El resultado final (una lista de palabras) se ejecuta como `argv` del comando.

Si entiendes el orden, cualquier comportamiento "mágico" se vuelve mecánico.

---

## 2. El orden de expansión (el diagrama)

El manual de Bash lo define así (resumido y en el orden en que aplica):

```
                     ┌─────────────────────────┐
texto crudo ───────▶ │ 1. Brace expansion      │   {a,b,c}  →  a b c
                     │    (puramente léxica)    │   file{1..3}.log
                     └────────────┬────────────┘
                                  ▼
                     ┌─────────────────────────┐
                     │ 2. Tilde expansion      │   ~  →  $HOME
                     │                          │   ~user  →  /home/user
                     └────────────┬────────────┘
                                  ▼
                     ┌─────────────────────────┐
                     │ 3a. Parameter / variable│   $var, ${var}, ${var:-x}
                     │ 3b. Aritmética          │   $((2+3))
                     │ 3c. Sustitución comando │   $(cmd), `cmd`
                     │     (se evalúan izq.→der;│
                     │      todas forman "la    │
                     │      tercera etapa")     │
                     └────────────┬────────────┘
                                  ▼
                     ┌─────────────────────────┐
                     │ 4. Word splitting        │   usa $IFS; sólo se
                     │                          │   aplica a resultados
                     │                          │   sin comillas de la 3.
                     └────────────┬────────────┘
                                  ▼
                     ┌─────────────────────────┐
                     │ 5. Pathname (globbing)   │   *, ?, [abc], **
                     │                          │   modificado por shopt
                     └────────────┬────────────┘
                                  ▼
                     ┌─────────────────────────┐
                     │ 6. Quote removal         │   quita comillas
                     │                          │   que sobrevivieron
                     └────────────┬────────────┘
                                  ▼
                            argv final → execve()
```

### Reglas que caen de este orden

- **Las comillas se evalúan al final** (etapa 6). Hasta entonces están ahí para **inhibir** las etapas que siguen. Por eso `"$var"` evita el word splitting (etapa 4) y el globbing (etapa 5).
- **Brace expansion es puramente léxica**: `{a,b}` se expande antes incluso de saber si hay variables. Por eso `{1..$N}` **no funciona** (en el momento de brace, `$N` aún no se expandió).
- **Word splitting sólo actúa sobre resultados de la etapa 3 que no estén entre comillas**. Las comillas dobles alrededor de `$var` son la defensa canónica.
- **Globbing es la última etapa que puede multiplicar palabras**. Si no hay match y no activaste `nullglob`, el glob se queda **literal** (ésta es la fuente de bugs más citada en toda la historia de bash).

### Ejemplo trazado paso a paso

Tomamos la línea:

```bash
echo {a,b}/*.txt > >(tee out) 2>&1
```

Suponemos que `a/one.txt` y `b/two.txt` existen; `a/*.txt` matchea; `b/*.txt` matchea.

| Etapa | Lo que ocurre | Resultado parcial |
|------:|---------------|-------------------|
| 0 | Tokenización | `echo`, `{a,b}/*.txt`, `>`, `>(tee out)`, `2>&1` |
| 1. Brace | `{a,b}/*.txt` → `a/*.txt b/*.txt` | `echo a/*.txt b/*.txt > >(tee out) 2>&1` |
| 2. Tilde | nada que expandir | igual |
| 3. Param/arith/cmd subst | nada en la lista; `>(tee out)` es **process substitution**, se evalúa aquí: Bash crea el FIFO (p.ej. `/dev/fd/63`) y arranca `tee out` leyendo de ahí | `echo a/*.txt b/*.txt > /dev/fd/63 2>&1` |
| 4. Word splitting | nada que splittear (no hay resultados sin comillas de la etapa 3 con espacios) | igual |
| 5. Pathname | `a/*.txt` → `a/one.txt`; `b/*.txt` → `b/two.txt` | `echo a/one.txt b/two.txt > /dev/fd/63 2>&1` |
| 6. Quote removal | nada | igual |
| 7. Ejecución | `argv = ["echo", "a/one.txt", "b/two.txt"]`, stdout redirigido al FD 63 (que es el pipe hacia `tee out`), stderr duplicado sobre stdout | se ejecuta |

**Observa**: la process substitution se materializa en la etapa 3; eso es lo que hace que `<(cmd)` y `>(cmd)` sean sustituibles por una ruta en el `argv`.

---

## 3. Globbing avanzado y `shopt`

Globbing opera después del word splitting. Su comportamiento se afina con `shopt`:

| Opción | Qué hace | Cuándo activar |
|--------|----------|----------------|
| `shopt -s nullglob` | Si un glob no matchea, se expande a **nada** (lista vacía) en vez de quedar literal. | Loops `for f in *.log; do ...`; evita procesar un archivo llamado literalmente `*.log`. |
| `shopt -s failglob` | Si un glob no matchea, Bash **falla** con error. | Scripts donde "no match" es un bug duro. **Mutuamente excluyente** en espíritu con `nullglob`: si pones ambas, `failglob` gana. |
| `shopt -s globstar` | Habilita `**` para matching recursivo (`**/*.log` baja a cualquier profundidad). | Scripts de recorrido de árbol. Sin esto, `**` se comporta como `*`. |
| `shopt -s extglob` | Habilita patrones extendidos: `?(p)`, `*(p)`, `+(p)`, `@(p)`, `!(p)`. | Cuando necesitas "todo lo que **no** matchea p" (`!(*.bak)`) o "uno o más de p". |
| `shopt -s dotglob` | Globbing matchea también archivos ocultos (`.foo`). | Scripts de backup/archivado donde ignorar dotfiles sería pérdida de datos. |
| `shopt -s nocaseglob` | Globbing case-insensitive. | Interacción con filesystems case-insensitive (macOS por defecto, Windows). |

### Ejemplos útiles

```bash
# Loop seguro aunque no haya .log
shopt -s nullglob
for f in /var/log/myapp/*.log; do
  gzip "$f"
done
shopt -u nullglob

# Copiar todo menos backups
shopt -s extglob
cp -- !(*.bak) /dest/

# Recursivo real
shopt -s globstar
grep -l 'TODO' -- **/*.py
```

### Trampa clásica de `nullglob`

Sin `nullglob`, esto corre `wc -l '*.log'` cuando no hay logs y falla "misteriosamente":

```bash
for f in *.log; do
  wc -l "$f"
done
# Si no hay matches: $f == '*.log' literal → wc -l '*.log' → "no such file"
```

Con `nullglob`, el loop simplemente no se ejecuta ninguna iteración.

---

## 4. Parameter expansion avanzado

Bash tiene **mucho más** que `$var`. Dominar esta tabla te ahorra `sed`/`awk` en casi todos los casos sencillos.

### Tabla de operadores

| Expresión | Qué hace | Ejemplo |
|-----------|----------|---------|
| `${var}` | Valor de `var`. | — |
| `${var:-default}` | `var` si está no-vacía, si no `default`. | `${PORT:-8080}` |
| `${var:=default}` | Igual, pero **asigna** `default` a `var`. | — |
| `${var:?msg}` | Falla con `msg` si `var` está vacía/no-definida. | `${CONFIG:?falta ruta}` |
| `${var:+alt}` | `alt` si `var` está no-vacía; si no, vacío. | `${DEBUG:+--verbose}` |
| `${#var}` | Longitud en caracteres. | `${#file}` |
| `${var:offset}` | Substring desde `offset`. | `${s:3}` |
| `${var:offset:length}` | Substring con longitud. | `${s:3:5}` |
| `${var#pat}` | Quita **el prefijo más corto** que matchea `pat`. | `${path#/}` quita slash inicial |
| `${var##pat}` | Quita **el prefijo más largo**. | `${path##*/}` → basename |
| `${var%pat}` | Quita **el sufijo más corto**. | `${name%.*}` quita extensión |
| `${var%%pat}` | Quita **el sufijo más largo**. | `${host%%.*}` quita todo tras primer `.` |
| `${var/pat/rep}` | Reemplaza **primera** aparición de `pat` por `rep`. | `${s/foo/bar}` |
| `${var//pat/rep}` | Reemplaza **todas** las apariciones. | `${s//,/ }` |
| `${var/#pat/rep}` | Reemplaza sólo si matchea al **inicio**. | — |
| `${var/%pat/rep}` | Reemplaza sólo si matchea al **final**. | — |
| `${var^}` | Primera letra a mayúsculas. | — |
| `${var^^}` | Todo a mayúsculas. | `${name^^}` |
| `${var,}` | Primera letra a minúsculas. | — |
| `${var,,}` | Todo a minúsculas. | `${env,,}` |
| `${!prefix*}` / `${!prefix@}` | Nombres de variables que empiezan por `prefix`. | — |
| `${!ref}` | Indirección: usa el valor de `ref` como nombre. | — |

### Idiomas que reemplazan `basename`/`dirname`

```bash
path="/var/log/myapp/app.log"
echo "${path##*/}"   # app.log       (basename)
echo "${path%/*}"    # /var/log/myapp (dirname)
echo "${path##*.}"   # log            (extensión)
echo "${path%.*}"    # /var/log/myapp/app (sin extensión)
```

Son **más rápidos** que forkear `basename`/`dirname` y evitan dependencias.

### Diferencia crítica `*` vs `@` en arrays

```bash
arr=(a b "c d")
printf '%s\n' "${arr[@]}"   # 3 líneas: a / b / c d
printf '%s\n' "${arr[*]}"   # 1 línea: "a b c d" (join por primer char de IFS)
```

`"${arr[@]}"` es casi siempre lo que quieres: preserva cada elemento como argumento separado.

---

## 5. Process substitution: `<(cmd)` y `>(cmd)`

**Qué es.** Bash crea un FIFO (en Linux normalmente a través de `/dev/fd/N`), arranca `cmd` conectado a ese FIFO, y sustituye la expresión por **la ruta** del FIFO. El comando "exterior" recibe una ruta que puede abrir como un archivo normal.

**Por qué importa.** Reemplaza patrones donde harías:

```bash
tmp1=$(mktemp); tmp2=$(mktemp)
trap 'rm -f "$tmp1" "$tmp2"' EXIT
sort a > "$tmp1"
sort b > "$tmp2"
diff "$tmp1" "$tmp2"
```

por un one-liner **sin temporales y sin `trap`**:

```bash
diff <(sort a) <(sort b)
```

### Patrones canónicos

```bash
# Comparar dos salidas
diff <(cmd1) <(cmd2)

# Dar input por un FD al comando (comandos que no leen de stdin)
some_tool --config <(generate_config_live)

# Tee a múltiples sinks procesadores
echo "payload" | tee >(gzip > out.gz) >(sha256sum > out.sha) > /dev/null
```

### Cuándo **no** usar process substitution

- Si el consumidor hace `lseek` (acceso aleatorio) sobre el archivo. Un FIFO sólo soporta lectura secuencial. Herramientas como `tar -tf` o `file` sobre ciertos formatos pueden fallar.
- Si necesitas conocer el exit code del productor. En `diff <(cmd1) <(cmd2)`, `$?` es de `diff`, **no** de `cmd1`/`cmd2`. Para capturar su status, usa `wait` sobre PIDs explícitos o convierte a pipe (`cmd1 | diff - <(cmd2)` + `${PIPESTATUS[@]}`).
- Si el comando bloquea esperando EOF antes de empezar a emitir, puedes caer en deadlock con `>(cmd)` combinado con pipes que llenan buffers.

---

## 6. Coprocesses (`coproc`)

Un **coproceso** es un proceso background cuyos FDs stdin/stdout quedan expuestos en un array (`${COPROC[0]}` lectura, `${COPROC[1]}` escritura) para que el shell dialogue con él.

```bash
coproc BC { bc -l; }
echo "scale=4; 1/7" >&"${BC[1]}"
read -r result <&"${BC[0]}"
echo "1/7 = $result"
exec {BC[1]}>&-        # cerrar stdin del coproc
wait "$BC_PID"
```

**Cuándo usarlo.** Cuando process substitution se queda corto porque necesitas **diálogo** (write / read / write / read) con un filtro de larga vida (una REPL, un pager, un `openssl s_client`).

**Limitación.** Sólo un coproc "sin nombre" (`coproc { ... }`) a la vez; con nombre (`coproc NAME { ... }`) puedes tener varios.

---

## 7. File descriptors explícitos con `exec`

Hasta ahora usabas `>`, `>>`, `<`, `2>&1`. Con `exec` puedes **abrir** un FD arbitrario a nivel de **shell**, no de un comando individual:

```bash
# Abrir FD 3 para escritura hacia un log
exec 3> >(tee /var/log/app.log)

# Escribir al FD 3
echo "evento" >&3

# Cerrarlo
exec 3>&-
```

### Asignación dinámica de FDs (Bash ≥ 4.1)

```bash
exec {logfd}> /tmp/app.log
echo "linea" >&"$logfd"
exec {logfd}>&-
```

Dejas que Bash elija un FD libre y te lo guarda en `$logfd`. Evita colisionar con FDs que otro proceso o librería espera reservados.

### Patrones

- **Dup stderr para debug sin perder stdout**: `exec 2> >(tee -a debug.log >&2)`.
- **Lock sostenido**: abrir un FD sobre un lockfile y usar `flock -n "$FD"`. Mientras ese FD esté abierto, el lock vive.
- **Reemplazar stdin/stdout del propio script**: `exec > out.log 2>&1` al inicio hace que **todo** lo que escriba el script vaya ahí sin tener que redirigir en cada comando.

---

## 8. Named pipes (FIFOs)

`mkfifo` crea un **archivo especial** en el filesystem que se comporta como un pipe. Dos procesos **no emparentados** pueden sincronizarse por él.

```bash
mkfifo /tmp/myfifo
# Terminal A:
cat /tmp/myfifo
# Terminal B:
echo "hola" > /tmp/myfifo
# Terminal A imprime "hola"
```

**Cuándo usarlo.** Cuando necesitas que un demonio independiente lea de "algo que parece un archivo" y escribirle desde cualquier parte. O cuando quieres encadenar procesos sin tener un ancestro común que los pipeline.

**Trampas**. `open` sobre una FIFO para lectura **bloquea** hasta que alguien la abra para escritura (y viceversa). Hay que diseñar quién abre primero.

---

## 9. `IFS`: lo bueno, lo malo y lo peligroso

`IFS` (Internal Field Separator) controla **word splitting** y **cómo join `"${arr[*]}"`**.

Por defecto: `IFS=$' \t\n'` (espacio, tab, newline).

**Patrón defensivo**: al inicio de un script serio, `IFS=$'\n\t'`. Eliminas el espacio como separador, lo que:

- Impide que `for f in $(ls)` rompa archivos "con espacios en el nombre" (aun así `for f in *` es mejor).
- Hace que `read -ra arr <<< "$csv"` sin reasignar IFS no splittee por espacios inesperados.

**Peligros**:

- Si cambias `IFS` localmente, **restáuralo** o `local IFS` en funciones.
- Herramientas que esperan parseo whitespace-aware pueden romperse. `read` sin `-r` y con `IFS` modificado es territorio de bugs sutiles.

---

## 10. `trap … DEBUG` y `trap … RETURN`

Además de `EXIT`, `ERR`, `INT`, `TERM`, Bash expone dos señales **sintéticas**:

- `trap 'cmd' DEBUG` — ejecuta `cmd` **antes de cada comando simple**. Potente para tracing selectivo (más fino que `set -x`).
- `trap 'cmd' RETURN` — ejecuta `cmd` cuando una función retorna o cuando un archivo sourceado termina.

```bash
trap 'echo "[DEBUG] línea=$LINENO cmd=$BASH_COMMAND" >&2' DEBUG
mi_funcion
trap - DEBUG  # desactivar
```

**Cuándo usarlo**. Debug de scripts complejos donde `set -x` es demasiado ruidoso o donde quieres loggear sólo ciertas funciones.

---

## 11. Introspección: `BASH_SOURCE`, `BASH_LINENO`, `FUNCNAME`

Tres arrays paralelos que describen el **call stack**:

- `${FUNCNAME[0]}` — función actual (o `main` / `source`).
- `${BASH_SOURCE[0]}` — archivo que define la función actual.
- `${BASH_LINENO[0]}` — línea del **llamador** desde donde se invocó la función actual.

### Stack trace mínimo

```bash
stacktrace() {
  local i
  for ((i=1; i<${#FUNCNAME[@]}; i++)); do
    printf '  at %s (%s:%s)\n' \
      "${FUNCNAME[i]}" "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}"
  done
}

on_err() {
  echo "ERROR en línea ${BASH_LINENO[0]} (cmd: $BASH_COMMAND)" >&2
  stacktrace >&2
}
trap on_err ERR
```

Con esto, cuando un comando falla bajo `set -e`, obtienes un trace estilo lenguajes "serios".

### Idioma portable: ruta absoluta del script

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Preferido sobre `$0` porque sobrevive a `source`.

---

## 12. Atributos de variables: `declare`

| Flag | Qué hace | Ejemplo |
|------|----------|---------|
| `-r` | Readonly: no se puede reasignar. | `declare -r CONFIG=/etc/app.conf` |
| `-x` | Exportada al entorno de procesos hijos. | `declare -x PATH="$PATH:/opt/bin"` |
| `-i` | Entera: asignaciones se evalúan como aritmética. | `declare -i n=0; n=1+2` → `3` |
| `-a` | Array indexado. | `declare -a xs=(a b c)` |
| `-A` | Array **asociativo** (clave→valor). Requiere Bash ≥ 4. | `declare -A m=([k1]=v1 [k2]=v2)` |
| `-l` / `-u` | Fuerza minúsculas / mayúsculas al asignar. | — |
| `-n` | Nameref: variable que es **referencia** a otra. Útil para pasar arrays a funciones. | `declare -n ref=target` |

### Nameref: pasar un array a una función

```bash
sum() {
  local -n _arr=$1
  local total=0
  local x
  for x in "${_arr[@]}"; do (( total += x )); done
  printf '%d\n' "$total"
}

nums=(1 2 3 4)
sum nums
```

Sin nameref tendrías que serializar/deserializar o usar variables globales. Con nameref la función opera sobre el array del llamador.

---

## 13. Portabilidad: `#!/bin/sh` vs `#!/usr/bin/env bash`

### Matriz de qué pierdes al pasar de bash a sh (dash o busybox ash)

| Feature | bash | dash | busybox ash |
|---------|------|------|-------------|
| `[[ … ]]` | sí | no | no |
| `(( … ))` aritmética | sí | no (usar `$(( ))`) | no |
| Arrays indexados `arr=(…)` | sí | no | no |
| Arrays asociativos `declare -A` | sí (≥4) | no | no |
| Brace expansion `{a,b}` | sí | no | no |
| `{1..10}` | sí | no | no |
| Process substitution `<()` | sí | no | no |
| Coprocess `coproc` | sí | no | no |
| `${var^^}` / `${var,,}` | sí | no | no |
| `${var//pat/rep}` | sí | sí (POSIX) | sí |
| `${var#pat}` / `${var%pat}` | sí | sí (POSIX) | sí |
| `read -r -a` | sí | no (sin `-a`) | no |
| `local` dentro de funciones | sí | sí (dash sí, ash sí) | sí |
| `trap … DEBUG` / `RETURN` | sí | no | no |
| `BASH_SOURCE`/`FUNCNAME` | sí | no | no |
| `set -o pipefail` | sí | **no** (dash) | sí |
| `$'…'` ANSI-C quoting | sí | no | sí |

### Regla práctica

- **`#!/usr/bin/env bash`** si usas cualquier feature de la columna "sí/no": arrays, `[[ ]]`, process substitution, parameter expansion avanzado, pipefail.
- **`#!/bin/sh`** sólo si el script tiene que correr en entornos minimalistas (contenedores Alpine donde `sh` es busybox ash, imágenes Debian donde `sh` es dash, hooks de Docker, scripts de init, Alpine en Kubernetes).
- Si eliges `sh`, corre `shellcheck -s sh script.sh` para que te marque las extensiones de bash que coló tu memoria muscular.

**Ejemplos de contexto por elección**:

- Script interno de un servidor Linux → `bash`.
- Hook de un paquete `.deb` → **`sh`** (dash).
- Entrypoint de contenedor Alpine → **`sh`** (ash) o `#!/usr/bin/env bash` sólo si instalaste `bash` deliberadamente.
- `.bashrc`/`.profile` → `sh` para `.profile`, bash para `.bashrc`.

---

## 14. Puesta en común: anatomía de un bug "raro"

Un script hace:

```bash
files=$(find . -name "*.log")
for f in $files; do
  wc -l "$f"
done
```

¿Qué puede salir mal? Varios bugs encapsulados por **mal uso del orden de expansión**:

1. `$(find …)` captura stdout con **newlines**. Al no citar, en la etapa 4 (word splitting) **separa por `$IFS`** que incluye espacio: cualquier archivo con espacio en el nombre se parte en dos.
2. Como el loop itera sobre palabras splitteadas, el resultado se **re-expande** en la etapa 5 (globbing): si un path contiene `*` literal, se expande.
3. Si no hay matches, `files` queda vacío y el loop no itera.

**Reescritura correcta** con lo aprendido:

```bash
shopt -s globstar nullglob
for f in **/*.log; do
  wc -l "$f"
done
```

Sin forks a `find`, sin word splitting, sin re-globbing. El patrón entero vive en la etapa 5.

Si **sí** necesitas `find` (por filtros que globbing no cubre):

```bash
while IFS= read -r -d '' f; do
  wc -l "$f"
done < <(find . -name '*.log' -print0)
```

- `-print0`: separador NUL, inmune a espacios/newlines.
- `read -d ''`: lee hasta NUL.
- `< <(…)`: process substitution para no spawnar subshell en el loop (lo que te permite `set` variables desde dentro del loop y verlas fuera).

---

## 15. Preguntas de reflexión (resuélvelas sin consultar)

1. ¿En qué etapa de expansión se materializa `<(cmd)`? ¿Por qué eso explica que puedas pasarlo como argumento a cualquier herramienta que acepte un path?
2. ¿Qué diferencia hay entre `${var:-x}` y `${var:=x}`? ¿Y entre `${var:?msg}` y `${var:+alt}`?
3. ¿Qué pasa con `for f in *.log` si no hay matches, con y sin `shopt -s nullglob`? ¿Y con `failglob`?
4. ¿Por qué `"${arr[@]}"` preserva argumentos y `${arr[*]}` sin comillas los aplana? ¿Qué hace `"${arr[*]}"` entrecomillado?
5. Dado `path="/a/b/c.tar.gz"`, ¿cuáles son los resultados de `${path##*/}`, `${path%.*}`, `${path%%.*}`?
6. ¿Qué recoges capturando el status de `diff <(cmd1) <(cmd2)` si `cmd1` falla? ¿Cómo lo arreglas?
7. ¿Por qué `exec 3> file; cmd >&3; exec 3>&-` puede ser preferible a redirigir en cada `cmd`?
8. ¿Qué hace `trap … DEBUG` que `set -x` no hace? Da un caso donde preferirías DEBUG.
9. ¿Qué pierdes al cambiar el shebang de `bash` a `sh` sobre un sistema Alpine? Cita al menos cinco features de la matriz.
10. ¿Cuál es el peor caso de `IFS=,` sin restaurar al salir de una función?

Si puedes responder las diez con precisión, estás listo para el nivel de scripting donde "no se cambia a Python por reflejo", sino porque realmente lo amerita.
