# sys-16 — Loops e iteración

> Lección profunda. Recorrer datos parece trivial hasta que un archivo se llama `foo bar.txt` o `rm -rf *.jpg`. Este módulo trata la iteración como una **decisión de diseño**: qué separador usas, qué pasa en un subshell, cuántos procesos lanzas por iteración.

---

## 1. Por qué un capítulo entero sobre loops

En Bash hay cuatro constructores de bucle (`for … in`, `for ((;;))`, `while`, `until`) y una docena de maneras de *alimentarlos* (variables, globs, subst. de comando, pipes, redirecciones, process substitution, FDs). La combinación equivocada corrompe datos silenciosamente.

Un script de administración típico itera sobre **tres clases de secuencias**:

1. **Enumeraciones fijas o aritméticas** — "para `i` entre 1 y 10", "para cada entorno en `dev staging prod`".
2. **Entidades del filesystem** — "para cada archivo `.log` bajo `/var/log`".
3. **Registros de un stream** — líneas de un archivo, de un pipe, de una API.

Cada clase tiene un patrón canónico. Mezclarlos genera bugs reproducibles pero no obvios: el script "funciona" en tu `/tmp` con tres archivos y falla en producción con 40k.

---

## 2. Los cuatro constructores

### 2.1 `for VAR in LISTA`

```bash
for env in dev staging prod; do
  echo "deploying to $env"
done
```

Itera sobre **palabras** separadas por `$IFS` (por defecto `space tab newline`). La "lista" se construye *antes* de empezar el bucle: expansión de brace, tilde, parámetro, aritmética, substitución de comando, splitting y pathname (globbing). El bucle no ve nombres; ve el resultado final de todas esas expansiones.

Esto es la causa raíz del famoso **`for f in $(ls)` está mal**: `$(ls)` devuelve texto, Bash lo *parte por `$IFS`* y luego aplica globbing. Un archivo llamado `foo bar.txt` aparece como dos iteraciones (`foo` y `bar.txt`), y un archivo llamado `*.sh` se expande contra tu directorio actual.

**Patrón correcto para iterar sobre archivos:** usa un glob directo.

```bash
for f in *.log; do
  [[ -e $f ]] || continue   # proteger contra "sin matches"
  process "$f"
done
```

El glob devuelve un array de nombres *sin partir por `$IFS`*. La única verificación es que si no hay matches, el patrón literal (`*.log`) queda tal cual y hay que descartarlo con `[[ -e ]]` o con `shopt -s nullglob`.

### 2.2 `for ((init; cond; step))`

Sintaxis estilo C. Trabaja sobre aritmética entera.

```bash
for ((i=0; i<10; i++)); do
  echo "iteración $i"
done
```

Útil cuando necesitas el índice (para arrays paralelos, por ejemplo) o cuando quieres control fino del paso. **No** uses `seq 1 10` en un `for` si puedes usar `for ((;;))` o brace expansion (`for i in {1..10}`): `seq` lanza un proceso.

### 2.3 `while CONDICION`

Itera mientras la condición es exitosa (exit code 0). La condición puede ser cualquier comando.

```bash
i=0
while ((i < 5)); do
  echo "$i"
  ((i++))
done
```

El uso **crítico** de `while` es leer registros de un stream:

```bash
while IFS= read -r line; do
  printf '%s\n' "$line"
done < archivo.txt
```

Esto lo detallamos en §4.

### 2.4 `until CONDICION`

Simétrico a `while`: itera mientras la condición *falla*.

```bash
until curl -fsS http://api/health >/dev/null; do
  sleep 2
done
```

Idiomático para esperas de health checks. En la práctica se usa menos que `while`, pero cuando lo necesitas evita la doble negación mental de `while ! …`.

---

## 3. Tabla de patrones: bueno vs. malo

| Objetivo | Mal patrón | Por qué está mal | Patrón correcto |
|----------|------------|------------------|-----------------|
| Iterar archivos del CWD | `for f in $(ls)` | `ls` devuelve texto; se parte por `$IFS`, se expande con globbing. Pierde nombres con espacios/newlines y ejecuta glob malicioso. | `for f in *; do [[ -e $f ]] || continue; …; done` |
| Iterar archivos de un árbol | `for f in $(find . -name '*.log')` | Mismo problema; además `find` devuelve rutas con `/` que no distinguen separadores. | `while IFS= read -r -d '' f; do …; done < <(find . -name '*.log' -print0)` |
| Leer líneas de un archivo | `for line in $(cat f.txt)` | `$(cat f.txt)` colapsa newlines a `$IFS`, parte por palabras. Pierde líneas vacías y la estructura. | `while IFS= read -r line; do …; done < f.txt` |
| Procesar salida de un comando | `cmd \| while read x; do COUNT=$((COUNT+1)); done; echo $COUNT` | El `while` corre en un **subshell**; `COUNT` modificado dentro se pierde al salir. | `while read x; do …; done < <(cmd)` **o** `shopt -s lastpipe` (bash 4.2+, solo no-interactivo) |
| Iterar sobre números | `for i in $(seq 1 1000)` | Lanza un proceso y construye un string de 1000 tokens antes de empezar. | `for ((i=1; i<=1000; i++)); do …; done` |
| Iterar sobre claves de array asociativo | `for k in ${!map}` | Error de sintaxis sutil, no itera. | `for k in "${!map[@]}"; do …; done` |
| Iterar sobre argumentos del script | `for a in $*` | Join por `$IFS[0]` y luego re-split; pierde cuoting original. | `for a in "$@"; do …; done` |
| Encontrar archivos y borrarlos | `for f in $(find . -name '*.tmp'); do rm $f; done` | Suma todos los problemas anteriores + `rm` sin comillas. | `find . -name '*.tmp' -delete` (si basta) o `find … -print0 \| xargs -0 rm --` |

La regla de oro: **si tu input puede contener bytes arbitrarios (nombres de archivo, líneas de usuarios, campos de un CSV mal formado), no partas por `$IFS`; usa `read` con un separador que *no puede aparecer en los datos*.**

Para líneas: `\n` (`read` por defecto). Para nombres de archivo: `\0` (null-terminated, es el único byte que POSIX garantiza que no puede aparecer en un path).

---

## 4. El patrón canónico: `while IFS= read -r line`

```bash
while IFS= read -r line; do
  printf '%s\n' "$line"
done < archivo.txt
```

Tres piezas, cada una tiene una razón:

- **`IFS=`** (vacío, local a esta sola invocación de `read`). Evita que `read` recorte espacios y tabs al inicio y al final de la línea. Sin esto, `"  foo  "` llega como `"foo"`.
- **`-r`** (raw). Evita que `read` interprete `\` como escape. Sin esto, una línea terminada en `\` se concatena con la siguiente.
- **`line`** (nombre de la variable). Si pones varios nombres, `read` divide por `$IFS` entre ellos, lo cual rara vez es lo que quieres cuando el objetivo es "una línea entera".

Variante para leer múltiples campos de un CSV simple (separador coma):

```bash
while IFS=, read -r user uid shell; do
  echo "$user tiene uid $uid y shell $shell"
done < passwd.csv
```

Aquí `IFS=,` sí tiene sentido porque *estás* parseando campos.

### 4.1 Terminación: con y sin newline final

`read` devuelve exit code **no-cero** cuando llega a EOF *sin* leer nada. Si el archivo no termina en `\n`, la última línea se asigna a `line` pero `read` sale con 1. Los `while read` idiomáticos manejan esto así:

```bash
while IFS= read -r line || [[ -n $line ]]; do
  printf '%s\n' "$line"
done < archivo.txt
```

El `|| [[ -n $line ]]` captura el caso "última línea sin newline final".

---

## 5. El gotcha del subshell del pipe

```bash
count=0
grep -c error log | while read -r n; do
  count=$((count + n))
done
echo "count=$count"      # imprime 0, no la suma
```

Cada etapa de un pipe corre en un **subshell**: una copia del shell con sus propias variables. El `while` ve y modifica *su* `count`, pero al terminar el subshell esa copia se destruye y el `count` del padre sigue siendo 0.

Soluciones, en orden de preferencia:

1. **Process substitution** — pone el productor en subshell pero deja el consumidor en el padre:

   ```bash
   count=0
   while read -r n; do
     count=$((count + n))
   done < <(grep -c error log)
   echo "count=$count"      # funciona
   ```

2. **Redirección de archivo** — si el productor es un archivo o se puede materializar como tal.

3. **`shopt -s lastpipe`** — hace que la última etapa del pipe corra en el shell actual. Solo funciona en scripts no-interactivos y con job control deshabilitado (`set +m`). Útil pero menos portable:

   ```bash
   set +m
   shopt -s lastpipe
   count=0
   grep -c error log | while read -r n; do
     count=$((count + n))
   done
   echo "count=$count"
   ```

4. **Devolver el valor por stdout** del while y capturarlo con `$(...)` — invierte el problema: el while vive en subshell y el padre recibe su salida.

### 5.1 ¿Qué variables sí sobreviven?

Ninguna variable modificada en un subshell vuelve al padre. Lo que *sí* puede volver es:

- **exit code** del subshell (vía `$?` o `||` / `&&`).
- **salida estándar** del subshell (vía `$(...)`).
- **efectos externos**: archivos creados, procesos lanzados, variables de entorno de procesos hijos (no retornan al padre, pero afectan al sistema).

---

## 6. Null-terminated: cuando los nombres son hostiles

Para nombres de archivo *nada* es seguro excepto `\0`. Un nombre puede contener espacios, tabs, newlines, `*`, `?`, `[`, bytes no-UTF-8, y en algunos filesystems también `\r`.

El patrón canónico:

```bash
while IFS= read -r -d '' f; do
  procesar "$f"
done < <(find . -type f -print0)
```

- **`find … -print0`** emite cada nombre seguido de un byte NUL (en lugar de newline).
- **`read -d ''`** en Bash significa "separador = byte NUL" (una cadena vacía como argumento de `-d` se interpreta como el byte NUL, no como "sin separador").
- **`-r`** sigue siendo necesario (el nombre puede contener `\`).
- **`IFS=`** sigue siendo necesario (puede haber espacios iniciales/finales).

Si prefieres cargar todo a un array (útil cuando quieres contar primero o indexar), hay una forma más corta con `mapfile`:

```bash
mapfile -d '' files < <(find . -type f -print0)
for f in "${files[@]}"; do
  procesar "$f"
done
```

**Advertencia:** `mapfile -d ''` requiere Bash 4.4+. En macOS por defecto hay Bash 3.2 (licencia); instala Bash moderno con Homebrew (`brew install bash`) o reescribe con el loop `while read`.

### 6.1 Por qué no basta con `-print` + `-exec`

`find … -exec cmd {} \;` resuelve el 80% de los casos y es la primera opción si tu objetivo es "ejecutar `cmd` por cada archivo". Pero si tu operación es compleja (variables acumuladas, condiciones, llamadas a funciones de shell), necesitas el loop. Y para pasar listas a `xargs`, `xargs -0` es el **único** modo seguro.

---

## 7. `continue`, `break`, bucles anidados

- **`continue`** salta a la siguiente iteración del bucle actual.
- **`break`** sale del bucle actual.
- **`continue N`** / **`break N`** actúan sobre el N-ésimo bucle enclosing. Útil para salir de un bucle anidado sin usar flags:

```bash
for host in "${hosts[@]}"; do
  for port in 22 80 443; do
    if ! nc -z "$host" "$port"; then
      echo "$host:$port cerrado — salto al siguiente host"
      continue 2   # saltar al siguiente host, no al siguiente puerto
    fi
  done
done
```

Úsalo con cuidado: en bucles profundos pierde legibilidad; es preferible refactorizar a una función que devuelva temprano.

---

## 8. Rendimiento: builtin vs proceso externo por iteración

El coste dominante de un bucle en Bash **no** es el bucle en sí; es cada *proceso externo* que lanzas dentro. Un `fork`+`exec` cuesta del orden de 1–3 ms. En un bucle de 10.000 iteraciones, lanzar un `cut` por iteración añade ~15–30 segundos frente a usar parameter expansion.

Comparativa (en orden de preferencia dentro del bucle):

| Operación | Builtin / parameter expansion | Proceso externo (lento) |
|-----------|-------------------------------|-------------------------|
| Quitar prefijo | `"${s#pat}"` | `echo "$s" \| sed "s/^pat//"` |
| Quitar sufijo | `"${s%pat}"` | `echo "$s" \| sed "s/pat$//"` |
| Mayúsculas | `"${s^^}"` (bash 4+) | `echo "$s" \| tr a-z A-Z` |
| Longitud | `"${#s}"` | `echo -n "$s" \| wc -c` |
| Comparación | `[[ $a == $b ]]` | `[ "$(echo "$a")" = "$b" ]` |
| Aritmética | `((x = a + b))` | `x=$(expr "$a" + "$b")` |

Regla práctica: si una operación aparece dentro de un bucle con N > 1000, verifica que no estás lanzando un proceso evitable. Para N > 100.000, considera `awk` o Python en lugar del bucle en Bash: ambos leen el stream una sola vez y operan en memoria con costes amortizados mucho mejores.

---

## 9. Datos externos: `curl`/`wget` + `jq` mínimo

### 9.1 `curl` vs `wget` (toque, se profundiza en `sys-20`)

Para scripts, `curl` es más idiomático: flexible, buena integración con APIs, respuestas estructuradas.

```bash
curl -fsS "https://api.github.com/repos/torvalds/linux/tags" > tags.json
```

Flags clave para scripts:

- `-f` — falla con exit code no-cero en HTTP ≥ 400 (sin esto, `curl` descarga la página de error como si fuera éxito).
- `-s` — silent (sin barra de progreso).
- `-S` — show errors cuando falla (combina bien con `-s`).
- `-L` — sigue redirects.
- `-o file` — guarda a archivo.

### 9.2 Iterar JSON con `jq`

`jq` es un parser/transformador de JSON en línea de comandos. Para iterar sobre una lista:

```bash
curl -fsS "https://api.github.com/repos/torvalds/linux/tags" |
  jq -r '.[].name' |
  while IFS= read -r tag; do
    echo "tag: $tag"
  done
```

- **`-r`** (raw) en `jq`: emite strings sin comillas JSON.
- **`.[]`** itera sobre los elementos del array raíz.
- **`.name`** extrae el campo `name` de cada elemento.

Para múltiples campos por elemento, un patrón limpio es emitir TSV y leer con `IFS=$'\t'`:

```bash
curl -fsS "$URL" |
  jq -r '.[] | [.name, .commit.sha] | @tsv' |
  while IFS=$'\t' read -r name sha; do
    printf 'tag %s -> %s\n' "$name" "$sha"
  done
```

`@tsv` escapa correctamente tabs y newlines dentro de los campos (reemplaza por `\t` y `\n`).

Para payloads enormes, considera `jq --stream` o reescribir el consumidor en un lenguaje con parser DOM (Python, Go) — Bash no es la herramienta para procesar GB de JSON.

---

## 10. Checklist mental antes de escribir un bucle

Antes de teclear `for … do`:

1. **¿Qué estoy iterando?** ¿Palabras, archivos, líneas, registros estructurados?
2. **¿El input puede contener bytes raros?** Si viene del filesystem o de un usuario: sí.
3. **¿Qué separador uso?** Palabras → `for … in`. Líneas → `while read`. Archivos hostiles → `while read -d ''`.
4. **¿Mi loop vive en un subshell?** Si está detrás de `|`, sí; usa `< <(…)` o `shopt -s lastpipe`.
5. **¿Estoy lanzando un proceso por iteración?** Mide (`time`) si N > 1000; cambia a builtin si procede.
6. **¿El loop es idempotente?** Si modifica el filesystem, ¿qué pasa si lo ejecuto dos veces? Si no es seguro, añade `--dry-run` como default.
7. **¿Qué pasa si hay cero elementos?** Protégete con `[[ -e $f ]] || continue` o `shopt -s nullglob`.

---

## 11. Antipatrones recurrentes

- **Parsear `ls`.** Nunca. Usa globbing o `find -print0`.
- **`for i in $(cat file)`.** Usa `while read`.
- **`cmd | while read; … $var …`.** El `$var` del padre no se actualiza. Usa process substitution.
- **`seq` dentro de `for`.** Usa brace expansion o `for ((;;))`.
- **Comillas olvidadas en `"$f"` dentro del cuerpo.** Rompe en el momento peor, con un nombre que lleva ahí años.
- **Asumir que el array tiene elementos.** Si viene de un glob, puede estar vacío (o contener el patrón literal, si no activaste `nullglob`).
- **Usar `eval` para construir el loop dinámicamente.** Casi siempre hay un array o un `case` que lo hace sin inyección.

---

## 12. Preguntas de evaluación

Responde sin consultar. Si dudas, construye el experimento en tu shell y verifica.

1. Dado un directorio con los archivos `a.sh`, `b b.sh`, `*.sh` (literal), y `evil$(touch /tmp/pwn).sh`, ¿cuántas iteraciones hace `for f in $(ls); do echo "$f"; done` y qué efectos secundarios tiene? ¿Y `for f in *.sh; do echo "$f"; done`?
2. Explica, línea a línea, por qué el patrón `while IFS= read -r line` necesita las tres piezas (`IFS=`, `-r`, un solo nombre de variable).
3. Dado el pipeline `cmd | while read x; do c=$((c+1)); done; echo "$c"`, ¿por qué `$c` es siempre vacío al salir? Da **dos** reescrituras que lo arreglen y explica el trade-off entre ambas.
4. ¿Qué significa `read -d ''` en Bash y por qué `find -print0` es su compañero natural?
5. ¿Qué diferencia hay entre `continue` y `continue 2` en un bucle doblemente anidado? Da un caso real donde `continue 2` es más legible que una variable `skip=1`.
6. Mide (`time`) la diferencia entre un loop que hace `s=$(echo "$x" | tr a-z A-Z)` y uno que hace `s=${x^^}` para 10.000 strings. ¿Cuál es el coste dominante?
7. Diseña un script que lea un endpoint JSON (array de objetos con `name` y `url`) con `curl -fsS` + `jq`, y procese cada elemento sin perder datos si `name` contiene espacios o tabs. Explica por qué tu diseño es seguro.
