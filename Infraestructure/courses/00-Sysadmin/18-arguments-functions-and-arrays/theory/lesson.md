# sys-18 — Teoría: Argumentos, funciones y arrays

> Objetivo: dejar de escribir scripts "al correr" y empezar a escribirlos como pequeños programas: con interfaz pública (flags), separación de responsabilidades (funciones) y estructuras de datos reales (arrays). Al terminar, deberías ser capaz de abrir un script tuyo de 300 líneas seis meses después y entenderlo sin leer de arriba hacia abajo.

---

## 1. Posicionales: cómo entra el mundo al script

Cuando ejecutas `./deploy.sh prod -v config.yaml`, Bash expone esos tokens vía variables especiales:

| Variable | Qué contiene |
|----------|--------------|
| `$0` | Nombre del script (`./deploy.sh`). En funciones **sigue siendo el script**, no la función. |
| `$1`, `$2`, …, `$9` | Argumentos posicionales. `$1 == "prod"`. |
| `${10}`, `${11}`, … | A partir del décimo **obligan a llaves**: `$10` se parsea como `$1` seguido de `0`. |
| `$#` | Número de argumentos. `$# == 3` en el ejemplo. |
| `$@` | Lista de argumentos. Comportamiento depende de comillas (ver §2). |
| `$*` | Lista de argumentos como una sola cadena cuando se comilla (ver §2). |
| `$$` | PID del script. |
| `$?` | Exit code del último comando. |
| `$!` | PID del último proceso en background. |
| `$-` | Opciones activas de la shell (`e`, `u`, `x`, …). |

### 1.1 `shift` consume el frente de la lista

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "antes: \$1=$1  \$#=$#"
shift                 # descarta $1; $2 pasa a ser $1
echo "después: \$1=$1  \$#=$#"
shift 2               # descarta dos más
```

`shift N` sin N descarta uno. Si N > `$#`, es error y el script sigue (con `set -e` aborta).

### 1.2 El separador `--`

Convención universal: `--` marca el **fin de opciones**. Lo que viene después son posicionales aunque empiece con `-`.

```bash
rm -- -archivo-con-guion
grep -- -v archivo         # busca literal "-v", no activa la opción
```

Tu CLI debe respetarlo: `getopts` ya lo entiende, `getopt` también.

---

## 2. `"$@"` vs `"$*"` — la tabla que debes memorizar

Supón que llamas al script así (nota los espacios internos del segundo argumento):

```bash
./s.sh  alpha  "beta  gamma"  delta
```

Entonces:

| Expresión | Resultado | Palabras producidas |
|-----------|-----------|---------------------|
| `$@` (sin comillas) | `alpha beta gamma delta` | **4** — `"beta  gamma"` se parte por `IFS` |
| `$*` (sin comillas) | `alpha beta gamma delta` | **4** — idéntico al anterior |
| `"$@"` | `"alpha"` `"beta  gamma"` `"delta"` | **3** — una palabra por argumento, espacios internos preservados |
| `"$*"` | `"alpha beta  gamma delta"` | **1** — todo concatenado con el **primer carácter de `IFS`** |

**Reglas prácticas:**

- Para **reenviar argumentos** a otro comando: siempre `"$@"`.
  ```bash
  mycmd() { ssh host -- /opt/tool "$@"; }   # correcto
  mycmd() { ssh host -- /opt/tool $@; }     # roto si hay espacios
  ```
- Para **loggear argumentos** como una línea: `"$*"` con un `IFS` controlado.
  ```bash
  local IFS=' '; echo "args: $*"
  ```
- Nunca uses `$@` o `$*` sin comillas en código nuevo. Es un bug esperando.

### 2.1 Por qué `IFS=$'\n\t'` como baseline

El `IFS` por defecto es `$' \t\n'` (espacio, tab, newline). Un argumento con espacios se parte al desreferenciar sin comillas. Restringir `IFS` a `\n\t` reduce la superficie: espacios literales dentro de variables dejan de romper loops como `for f in $(ls)`. No elimina el problema (sigue siendo mejor comillar), pero evita algunas sorpresas y es un idiom reconocible.

---

## 3. `getopts` — el parser de opciones cortas POSIX

`getopts` es **builtin** (no un ejecutable externo). Parsea una opción por iteración y actualiza:

- `OPTARG` → argumento de la opción actual (si la tiene).
- `OPTIND` → índice del próximo argumento a procesar (empieza en 1).
- `opt` (la variable que tú nombras) → la letra de la opción, o `?` en error.

### 3.1 Plantilla canónica

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<EOF
Uso: ${0##*/} [-v] [-o FILE] [-n COUNT] [-h] ARG

Opciones:
  -v         Modo verbose
  -o FILE    Archivo de salida (requerido)
  -n COUNT   Número de iteraciones (entero positivo)
  -h         Muestra esta ayuda y sale
EOF
}

verbose=0
output=""
count=1

while getopts ":ho:vn:" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    v) verbose=1 ;;
    o) output="$OPTARG" ;;
    n) count="$OPTARG" ;;
    \?) echo "Error: opción desconocida -$OPTARG" >&2; usage >&2; exit 2 ;;
    :)  echo "Error: la opción -$OPTARG requiere argumento" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  echo "Error: falta ARG posicional" >&2
  usage >&2
  exit 2
fi

arg="$1"
```

**Detalles importantes:**

- El **primer carácter `:`** en `":ho:vn:"` activa el *silent mode*: tú manejas los errores (`\?` y `:`), no Bash. Sin ese `:` inicial, Bash imprime sus propios mensajes y nunca cae en el caso `:`.
- Los **dos puntos tras una letra** (`o:`) significan "esta opción requiere argumento".
- `shift $((OPTIND - 1))` deja los **posicionales listos** a partir de `$1`.
- Convención de exit codes:
  - `0` → éxito o `--help`.
  - `1` → error de ejecución (archivo no existe, red cayó, etc.).
  - `2` → error de uso (flag desconocido, falta argumento).

### 3.2 Reset de `OPTIND` dentro de funciones

Si usas `getopts` dentro de una función (ej. un parser reutilizable), **debes resetear `OPTIND` localmente**:

```bash
parse_args() {
  local OPTIND=1 opt      # local protege; =1 arranca el parser
  while getopts ":ho:" opt; do ...; done
}
```

Sin eso, la segunda invocación empieza donde quedó la primera y "no ve" argumentos.

### 3.3 Limitaciones de `getopts`

- **Solo opciones cortas de una letra.** No soporta `--output`.
- No reordena argumentos. Si mezclas `-v foo -o bar`, se detiene en `foo` (porque no empieza con `-`), dejándote `-o bar` sin parsear.
- Si necesitas opciones largas, saltas a `getopt` GNU (§4) o parseas a mano con `case`.

---

## 4. `getopt` GNU — opciones largas y reordenamiento

`getopt` (sin `s`) es un **ejecutable externo** de util-linux. Soporta `--output=FILE`, reordena posicionales y maneja `--` correctamente. **Solo la versión GNU** sirve; la BSD/macOS por defecto no soporta `-l` (en macOS instala `gnu-getopt` con brew y usa `/opt/homebrew/opt/gnu-getopt/bin/getopt`).

### 4.1 Plantilla canónica

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -o: opciones cortas; -l: largas; -n: nombre para errores
parsed=$(getopt \
  -o "ho:vn:" \
  -l "help,output:,verbose,count:" \
  -n "${0##*/}" \
  -- "$@") || { echo "Uso inválido" >&2; exit 2; }

# Reasigna los posicionales a la versión reordenada
eval set -- "$parsed"

verbose=0; output=""; count=1
while true; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    -v|--verbose) verbose=1; shift ;;
    -o|--output)  output="$2"; shift 2 ;;
    -n|--count)   count="$2"; shift 2 ;;
    --)           shift; break ;;
    *)            echo "Error interno" >&2; exit 2 ;;
  esac
done
# $@ ahora contiene solo los posicionales
```

**Por qué `eval set --`:** `getopt` imprime una cadena ya quoteada con comillas simples. `eval set --` reconstruye los argumentos preservando espacios internos. Es el único uso defensivo de `eval` en Bash moderno — no lo copies para otras cosas.

### 4.2 Cuándo usar cuál

| Situación | Recomendación |
|-----------|---------------|
| Script interno, Linux o cualquier POSIX | `getopts` |
| Flags largos requeridos por UX | `getopt` GNU |
| Script tiene que correr en macOS por defecto | `getopts` + aceptas vivir sin largos |
| CLI para humanos externos | `getopt` largos + manpage |

---

## 5. Convenciones `--help` y `--version`

Esperado por quien lea tu CLI:

- `-h` / `--help` → stdout, exit 0, incluye nombre del programa, uso, opciones, exit codes.
- `--version` → stdout, formato `programa 1.2.3`, exit 0.
- Uso erróneo → mensaje corto a stderr, `usage` a stderr, exit 2.
- Mensajes de progreso → stderr (así stdout queda limpio para pipes).
- Resultado real (datos) → stdout.

Un `--help` bien construido es documentación ejecutable. Hazlo primero, no al final.

---

## 6. Funciones: la unidad de reutilización

### 6.1 Dos sintaxis

```bash
# Forma POSIX (preferida, portable)
greet() {
  echo "hola $1"
}

# Forma Bash (equivalente)
function greet { echo "hola $1"; }
```

Dentro de la función, `$1 $2 … $@ $#` se refieren a **sus propios argumentos**, no a los del script. `$0` **sigue siendo el nombre del script**.

```bash
greet() { echo "argumentos: $#  primero: $1"; }
greet alice bob
# → argumentos: 2  primero: alice
```

### 6.2 `return` solo acepta 0–255

`return` establece `$?` del caller. Pero el valor **debe ser un entero sin signo de 8 bits** (0–255). Si quieres devolver una cadena o número grande, usa `echo` + captura:

```bash
sum() {
  local a=$1 b=$2
  echo $((a + b))
}

result=$(sum 3 4)   # result == "7"
echo "$result"
```

Convención: `return 0` → éxito, `return 1..255` → variantes de error.

### 6.3 Scope por defecto es **global**

```bash
counter=0
tick() { counter=$((counter + 1)); }
tick; tick; tick
echo "$counter"   # → 3
```

Esto es una fuente de bugs grandes. La mitigación es `local`:

```bash
counter=0
bad() { counter=99; }         # pisa el global
good() { local counter=99; }  # crea uno propio
```

### 6.4 Demo: por qué `local` importa

```bash
#!/usr/bin/env bash
set -euo pipefail

i="externa"

no_local() {
  for i in a b c; do :; done   # pisa la global
}

con_local() {
  local i
  for i in a b c; do :; done   # scope aislado
}

no_local;  echo "sin local: i=$i"    # → sin local: i=c
i="externa"
con_local; echo "con local: i=$i"    # → con local: i=externa
```

Regla: **toda variable creada dentro de una función debe ser `local`**, excepto cuando el propósito explícito es tocar el global (y debería estar comentado).

### 6.5 Variantes de `local` / `declare`

| Declaración | Significado |
|-------------|-------------|
| `local x` | Scope de función, string. |
| `local -r x=1` | Read-only. |
| `local -i x=1` | Entero (contexto aritmético automático). |
| `local -a arr` | Array indexado. |
| `local -A map` | Array asociativo. |
| `local -n ref=$1` | Nameref (ver §8.3). |

`declare` fuera de una función crea una variable global con las mismas banderas.

### 6.6 Dynamic scoping, no lexical

Si `foo` llama a `bar`, las `local` de `foo` **son visibles dentro de `bar`**. Esto es distinto de C/Python. Útil para nameref, peligroso para colisiones de nombres. Convención defensiva: prefija variables de funciones genéricas con `_` o el nombre de la función (`_tmp`, `_log_level`).

---

## 7. Arrays indexados

### 7.1 Creación y acceso

```bash
arr=(uno dos "tres cuatro" cinco)
echo "${arr[0]}"       # uno
echo "${arr[2]}"       # tres cuatro
echo "${#arr[@]}"      # 4  (número de elementos)
echo "${#arr[2]}"      # 11 (longitud del elemento 2)
```

### 7.2 `${arr[@]}` vs `${arr[*]}` — misma lógica que `$@`/`$*`

```bash
for x in "${arr[@]}"; do printf '[%s]\n' "$x"; done
# [uno]
# [dos]
# [tres cuatro]
# [cinco]

for x in "${arr[*]}"; do printf '[%s]\n' "$x"; done
# [uno dos tres cuatro cinco]   ← todo pegado por IFS
```

### 7.3 Slicing, append, delete

```bash
sub=("${arr[@]:1:2}")      # elementos 1 y 2 → ("dos" "tres cuatro")
arr+=("seis")              # append
unset 'arr[0]'             # borra índice 0, deja hueco (no reindexa)
arr=("${arr[@]}")          # truco: reindexa compactando
```

### 7.4 Iterar con índice

```bash
for i in "${!arr[@]}"; do
  printf '%d → %s\n' "$i" "${arr[i]}"
done
```

`"${!arr[@]}"` devuelve los **índices**; `"${arr[@]}"` los **valores**.

---

## 8. Arrays asociativos

Bash 4.0+ (macOS por defecto trae 3.2; instala Bash moderno vía brew o usa Linux).

### 8.1 Creación

```bash
declare -A env=(
  [HOST]="api.example.com"
  [PORT]="443"
  [SCHEME]="https"
)

env[TIMEOUT]="30"            # añadir después
echo "${env[HOST]}"          # api.example.com
echo "${#env[@]}"            # 4
```

### 8.2 Iterar sobre claves

```bash
for k in "${!env[@]}"; do
  printf '%-10s = %s\n' "$k" "${env[$k]}"
done
```

**El orden no está garantizado** (es un hash table). Si necesitas orden estable, mantén un array indexado paralelo con las claves ordenadas.

### 8.3 Patrón: configuración por entorno

```bash
declare -A config=(
  [dev.host]=localhost        [dev.port]=8080
  [prod.host]=api.example.com [prod.port]=443
)

env=${1:-dev}
host="${config[$env.host]}"
port="${config[$env.port]}"
```

Simula un namespace con prefijos. Para configs grandes, mejor leer de un archivo (próximos módulos).

---

## 9. Pasar arrays a funciones

### 9.1 El problema

```bash
show() { echo "recibí: $@"; }
arr=(a b "c d")
show "${arr[@]}"   # funciona para leer; dentro, $@ son los elementos
```

Esto **pasa una copia expandida**. La función no puede modificar el array original ni distingue si recibió un array o cinco strings sueltas.

### 9.2 Solución: nameref (`declare -n`), Bash 4.3+

```bash
#!/usr/bin/env bash
set -euo pipefail

push_unique() {
  local -n _arr=$1    # alias por nombre al array del caller
  local value=$2
  local item
  for item in "${_arr[@]}"; do
    [[ "$item" == "$value" ]] && return 0
  done
  _arr+=("$value")
}

lista=(alpha beta)
push_unique lista gamma
push_unique lista beta       # no-op, ya existe
printf '%s\n' "${lista[@]}"
# alpha
# beta
# gamma
```

**Importante:** por el dynamic scoping (§6.6), evita que el nombre del nameref choque con el del array del caller. Convención: prefija con `_` (ej. `local -n _arr=$1`). Si llamas `push_unique arr X` **y dentro la función hace `local -n arr=$1`**, Bash avisa con *circular name reference*.

### 9.3 Alternativa pre-4.3: pasar por nombre y usar indirección

```bash
copy_array() {
  local src=$1 dst=$2
  eval "$dst=(\"\${$src[@]}\")"
}
```

Funciona, pero `eval` es frágil. Usa nameref salvo que necesites Bash 3.

---

## 10. Juntando todo — esqueleto de un script serio

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly VERSION="1.0.0"
readonly PROG="${0##*/}"

# ---- utilidades ----
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
usage() { cat <<EOF
Uso: $PROG [-v] [-o FILE] [-n COUNT] [-h] ARG
...
EOF
}

# ---- parsing ----
parse_cli() {
  verbose=0; output=""; count=1
  local OPTIND=1 opt
  while getopts ":ho:vn:" opt; do
    case "$opt" in
      h) usage; exit 0 ;;
      v) verbose=1 ;;
      o) output="$OPTARG" ;;
      n) count="$OPTARG" ;;
      \?) die "opción desconocida -$OPTARG" ;;
      :)  die "la opción -$OPTARG requiere argumento" ;;
    esac
  done
  shift $((OPTIND - 1))
  (( $# >= 1 )) || die "falta ARG posicional"
  arg="$1"
}

# ---- lógica ----
process() {
  local item=$1 n=$2
  for ((i=0; i<n; i++)); do
    echo "procesando $item iteración $i"
  done
}

# ---- entrada ----
main() {
  parse_cli "$@"
  (( verbose )) && log "arg=$arg output=$output count=$count"
  process "$arg" "$count"
}

main "$@"
```

Nota: `parse_cli "$@"` recibe los posicionales originales, pero `shift` **dentro** de `parse_cli` solo mueve los locales. Para que el `arg` llegue a `main`, aquí lo asignamos a una variable global desde dentro — alternativa limpia: usar nameref para "devolver" el array residual.

---

## 11. Errores recurrentes y cómo evitarlos

| Síntoma | Causa raíz | Fix |
|---------|-----------|-----|
| El loop ignora elementos con espacios | Usaste `for x in $arr` sin `[@]` | `for x in "${arr[@]}"` |
| `getopts` dentro de función solo funciona la primera vez | No reseteaste `OPTIND` | `local OPTIND=1` |
| `return 300` devuelve `44` | 300 mod 256 = 44 | Usa `echo` + `$(func)` |
| Variable "desaparece" al salir de función | Olvidaste que era `local` en otra función que la pisó | Audita con `declare -p` o renombra |
| `-o archivo.txt` da "requiere argumento" | Falta `:` tras la letra en la cadena de `getopts` | `":ho:v"` con `o:` |
| `$10` no funciona | Falta llaves | `${10}` |
| Array no exporta a subshell | Diseño de Bash: no se exportan | Serializa con `declare -p arr > file`; `source file` del otro lado |
| macOS: `getopt -l` no funciona | Es BSD getopt | Instala `gnu-getopt`, usa ruta absoluta |

---

## 12. Lectura obligatoria del manual

Antes de la actividad 2, lee estas secciones del `man bash`:

- `Positional Parameters`
- `Arrays`
- `Shell Functions`
- `SHELL BUILTIN COMMANDS` → `getopts`, `local`, `declare`, `shift`, `return`

No tienes que memorizar; necesitas saber **que existen y qué buscar**.

---

## Preguntas de evaluación

Responde por escrito **sin consultar**. Si dudas en alguna, vuelve a la sección correspondiente.

1. Dado `./s.sh a "b c" d`, ¿cuántas palabras produce `"$*"` y cuántas `"$@"`? ¿Por qué?
2. ¿Qué pasa si llamas una función con `getopts` dos veces y no reseteas `OPTIND`?
3. ¿Puede `return` devolver `1000`? ¿Qué ocurre si lo intentas?
4. ¿Qué devuelve este script?
   ```bash
   x=1
   f() { x=2; }
   g() { local x=3; }
   f; echo "$x"
   g; echo "$x"
   ```
5. ¿Cuál es la diferencia entre `${arr[@]}` y `${!arr[@]}`?
6. ¿Por qué se usa `eval set -- "$parsed"` con `getopt` GNU y no sería aceptable con input arbitrario?
7. ¿En qué caso elegirías `getopt` sobre `getopts`?
8. ¿Cómo pasarías un array asociativo a una función para que la función pueda modificarlo?
9. ¿Qué exit code debe retornar un script cuando el usuario pasa un flag desconocido? ¿Y cuando pide `--help`?
10. Explica por qué `export arr` donde `arr` es un array no funciona como esperarías.
