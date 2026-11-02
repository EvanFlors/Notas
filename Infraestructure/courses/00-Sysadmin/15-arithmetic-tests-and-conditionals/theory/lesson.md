# Lección: Aritmética, tests y condicionales en Bash

> **ID:** `sys-15-arithmetic-tests-and-conditionals` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `sys-13-bash-scripting-fundamentals`.

---

## 1. Introducción intuitiva

Un script sin condicionales es una lista de órdenes que se ejecutan hoy igual que mañana. Útil, pero limitado: no reacciona al estado del sistema. En cuanto quieres decir *"si el archivo existe, respáldalo; si no, créalo"* o *"si el disco está por encima del 90 %, alerta"*, necesitas dos cosas:

1. **Hacer cuentas** sobre valores que lees del sistema (porcentajes, tamaños, contadores).
2. **Decidir** basándote en el resultado.

Bash separa estas dos tareas en dos sintaxis distintas que a los principiantes se les mezclan: aritmética va dentro de `(( ))` o `$(( ))`, y las decisiones booleanas van dentro de `[[ ]]` o `[ ]`. Confundirlas es la fuente #1 de scripts que *parecen* funcionar y fallan sutilmente en producción.

En esta lección aprendes a tener **el instinto correcto** sobre qué sintaxis toca en cada caso, y por qué.

---

## 2. Variables numéricas

### 2.1 Todo es string, pero depende del contexto

En Bash, **todas** las variables son, en el modelo mental, cadenas de texto. No hay tipo entero genuino. La variable `n=42` guarda los dos caracteres `'4'` y `'2'`. Lo que cambia es el **contexto** en el que se evalúan: dentro de `(( ))` esos caracteres se interpretan como el entero 42; fuera, siguen siendo texto.

```bash
n=42
echo "$n"           # 42  (texto)
echo "$((n + 1))"   # 43  (contexto aritmético: '42' → 42)
echo "$n + 1"       # 42 + 1  (sin contexto aritmético, es texto)
```

### 2.2 `declare -i`: declarar intención aritmética

`declare -i var` marca `var` como "atributo entero". Dos efectos:

- Asignar `var=…` evalúa el lado derecho como expresión aritmética automáticamente.
- Si el resultado no es un entero, se interpreta como `0`.

```bash
declare -i n
n="3 + 4"
echo "$n"          # 7
n="hola"
echo "$n"          # 0
```

Usar `declare -i` es cosmético: no cambia lo que puedes hacer, sólo ahorra el `$(( ))` al asignar. En scripts legibles suele preferirse el `$(( ))` explícito, que *marca* para el lector humano que ahí hay aritmética.

### 2.3 Bases numéricas

Bash entiende varias bases dentro de contextos aritméticos:

| Notación | Significado | Ejemplo |
|---|---|---|
| `0NNN` | Octal | `0755` = 493 |
| `0xNNN` | Hexadecimal | `0xff` = 255 |
| `BASE#VAL` | Base arbitraria (2–64) | `2#1010` = 10 |

Esto se usa mucho con permisos y máscaras de bits. Cuidado con escribir `08` o `09` en un script: parecen decimales pero Bash los interpreta como octales inválidos y falla.

---

## 3. Aritmética: cuatro formas, dos vigentes

Bash tiene cuatro formas históricas de hacer aritmética entera. Dos las usas, dos las lees en código legacy.

### 3.1 `$(( expr ))` — expansión aritmética

Es una **expansión**: produce un string con el resultado. Se usa donde esperas un valor.

```bash
total=$((precio * cantidad))
echo "Subtotal: $((base + base * 16 / 100))"
```

Reglas útiles:

- Dentro de `(( ))` **no** se requiere `$` en los nombres de variable: `$((n + 1))` y `$(( $n + 1 ))` son equivalentes; preferimos la primera.
- Un valor booleano se mapea a `1` (verdadero) / `0` (falso).

### 3.2 `(( expr ))` — comando aritmético

Es un **comando**: no produce output, pero sí un **exit code**. Convención invertida respecto a C: la expresión *no-cero* produce exit `0` (éxito), y la expresión que vale `0` produce exit `1` (fallo). Esto lo hace natural para `if`:

```bash
if (( n > 10 )); then
  echo "n es grande"
fi

(( counter++ ))        # efecto lateral habitual
(( flag = x > 3 ))     # asigna 1 o 0
```

Preferimos `(( ))` sobre `[[ ]]` cuando la comparación es **numérica**, porque usa los operadores de C clásicos (`<`, `>`, `==`), más legibles que `-lt`/`-gt`/`-eq`.

### 3.3 `let` — equivalente a `(( ))`, obsoleto en código nuevo

```bash
let n=n+1              # funciona
let "n = n + 1"        # funciona con comillas por el espacio
```

`let` existe desde ksh. No aporta nada sobre `(( ))` y tiene parsing menos predecible con espacios. No lo uses en código nuevo; reconócelo en código ajeno.

### 3.4 `expr` — legacy POSIX, externo

`expr` es un **binario externo** (`/usr/bin/expr`), no un builtin. Hace aritmética entera con sintaxis incómoda:

```bash
n=$(expr 3 + 4)        # requiere espacios alrededor del operador
n=$(expr "$a" \* "$b") # '*' hay que escaparlo (es glob del shell)
```

Era obligatorio cuando sólo existía `/bin/sh` sin `$(( ))`. Hoy sólo lo usas si:

- Escribes POSIX puro (`#!/bin/sh`) sin Bash disponible.
- Mantienes scripts antiguos.

Dentro de Bash moderno, prefiere siempre `(( ))` o `$(( ))`: son builtins, más rápidos y menos accidentados.

### 3.5 `bc` — para floats y precisión arbitraria

Bash **no hace aritmética de punto flotante**. `$((10 / 3))` devuelve `3`, no `3.33`. Si necesitas decimales, delegas en `bc`:

```bash
promedio=$(echo "scale=2; $total / $n" | bc -l)
```

Puntos clave:

- `bc -l` carga la biblioteca matemática y pone precisión por defecto.
- `scale=N` fija los decimales a mostrar (en Bash no hay forma de hacer esto nativamente).
- `bc` lee de stdin y escribe a stdout; por eso el patrón `echo "…" | bc -l`.

Para una sola operación puntual, también sirve `awk 'BEGIN{printf "%.2f\n", 10/3}'`.

---

## 4. Operadores aritméticos

Dentro de `(( ))` y `$(( ))`, Bash soporta los operadores clásicos de C:

| Categoría | Operadores | Notas |
|---|---|---|
| Aritméticos | `+`  `-`  `*`  `/`  `%`  `**` | `**` es potencia; `/` es división entera. |
| Prefijo / sufijo | `++var`  `--var`  `var++`  `var--` | Igual que C. |
| Comparación | `<`  `<=`  `>`  `>=`  `==`  `!=` | Devuelven 1/0. |
| Lógicos | `&&`  `||`  `!` | Cortocircuito. |
| Bit a bit | `&`  `|`  `^`  `~`  `<<`  `>>` | Útil para flags y máscaras. |
| Ternario | `cond ? a : b` | Igual que C. |
| Asignación | `=`  `+=`  `-=`  `*=`  `/=`  `%=`  `<<=`  `>>=`  `&=`  `|=`  `^=` | Compuestas. |

Pitfall importante: estos operadores de **comparación** sólo son válidos dentro de contexto aritmético. Fuera (`[[ ]]`, `[ ]`), `<` significa **redirección**.

```bash
if (( a < b )); then …   # correcto: comparación numérica
if [ $a < $b ]; then …   # ¡MAL! '<' intenta redirigir desde el archivo "$b"
if [[ $a < $b ]]; then … # legal: comparación lexicográfica de strings
```

---

## 5. Tests: `[`, `[[ ]]` y `test`

Tres formas de evaluar condiciones booleanas. Las tres devuelven exit code `0` (verdadero) o `1` (falso); `if` lee ese exit code.

### 5.1 `test` y `[` — el builtin POSIX

`[` es un **builtin con nombre exótico**: es idéntico a `test`, excepto que exige `]` como último argumento. Son estrictamente equivalentes:

```bash
if test -f /etc/passwd; then …
if [ -f /etc/passwd ]; then …
```

Como es un comando normal, sus argumentos se **expanden y se splittean** como en cualquier otro comando. Esto es la causa de la mayoría de bugs.

### 5.2 `[[ ]]` — keyword de Bash

`[[ ]]` **no** es un comando: es una palabra reservada parseada aparte. Dentro de ella Bash **no hace word splitting ni glob expansion** sobre las variables. Esto cambia el modelo mental por completo: lo que escribes es lo que compara.

```bash
if [[ -f /etc/passwd ]]; then …
if [[ "$archivo" == *.log ]]; then …   # glob a la derecha
if [[ "$linea" =~ ^error ]]; then …    # regex ERE
```

### 5.3 Tabla comparativa `[` vs `[[`

| Aspecto | `[ … ]` (POSIX) | `[[ … ]]` (Bash) |
|---|---|---|
| Tipo | Comando (builtin) | Keyword del parser |
| Portabilidad | Toda `/bin/sh` | Bash, ksh, zsh |
| Word splitting en vars | **Sí** → requiere comillas | **No** → variables seguras sin comillas |
| Glob expansion de vars | **Sí** | **No** |
| Comparación de string | `=`, `!=` | `=`, `==`, `!=` |
| Comparación con glob | **No** | **Sí** (`[[ $f == *.log ]]`) |
| Regex | **No** | **Sí** (`=~`, resultado en `BASH_REMATCH`) |
| Operador `<` / `>` sobre strings | Hay que escapar: `\<`, `\>` | Directo: `<`, `>` |
| Lógicos | `-a`, `-o` (desaconsejados) | `&&`, `||` dentro del `[[ ]]` |
| Agrupar | `\(` `\)` | `(` `)` directo |
| Null en var | Explota si no citas | Tratado como string vacío |

**Regla de oro en Bash:** usa `[[ ]]` por defecto. Reserva `[ ]` para scripts `#!/bin/sh` donde la portabilidad POSIX importa.

### 5.4 Internals: por qué `[[ ]]` no splittea y `[ ]` sí

Bash procesa cada comando en fases: tokenización → expansión de alias → expansiones (brace, tilde, parámetros, aritmética, substitución de comandos, process substitution) → **word splitting** → **globbing** → eliminación de comillas → ejecución.

Cuando escribes `[ $x = $y ]`, Bash ve seis tokens: `[`, `$x`, `=`, `$y`, `]`, y el comando `[`. Las variables se expanden; sobre esas expansiones aplica word splitting (basado en `IFS`) y glob expansion. Luego el builtin `[` recibe los argumentos ya procesados y evalúa.

Cuando escribes `[[ $x = $y ]]`, Bash reconoce `[[` como keyword en la fase de tokenización. El contenido se parsea con **reglas propias** del condicional: las variables se expanden pero no se splittean ni se globbean. `[[ ]]` *no* ve argumentos POSIX; ve una expresión condicional.

Esta es también la razón de que `[[ ]]` pueda aceptar operadores con significado sintáctico raro (`<`, `>`, `=~`): no están pasando como argumentos a un binario, están siendo parseados por el keyword.

---

## 6. Tres familias de operadores

Los operadores internos de `[ ]` y `[[ ]]` se agrupan en tres familias.

### 6.1 Operadores de archivo

| Operador | Verdadero si… |
|---|---|
| `-e PATH` | PATH existe (cualquier tipo). |
| `-f PATH` | PATH existe y es archivo regular. |
| `-d PATH` | PATH existe y es directorio. |
| `-h PATH` / `-L PATH` | PATH es un symlink. |
| `-r PATH` | PATH es legible por el proceso. |
| `-w PATH` | PATH es escribible por el proceso. |
| `-x PATH` | PATH es ejecutable (o atravesable si es dir). |
| `-s PATH` | PATH existe y su tamaño es > 0. |
| `-p PATH` | PATH es un FIFO. |
| `-S PATH` | PATH es un socket. |
| `-u PATH` | PATH tiene bit `setuid`. |
| `-g PATH` | PATH tiene bit `setgid`. |
| `-k PATH` | PATH tiene bit `sticky`. |
| `-N PATH` | PATH modificado desde la última lectura. |
| `A -nt B` | A más nuevo que B (mtime). |
| `A -ot B` | A más viejo que B. |
| `A -ef B` | A y B son el mismo inodo. |

Pitfall: `-r` / `-w` / `-x` responden desde el punto de vista del **UID efectivo** del proceso. Un `root` siempre tendrá `-r` sobre cualquier archivo legible por el sistema, aunque sus bits sean `000`.

### 6.2 Operadores de string

| Operador | Verdadero si… |
|---|---|
| `-z STR` | STR tiene longitud 0. |
| `-n STR` | STR tiene longitud > 0. |
| `STR = STR` | Iguales (POSIX). |
| `STR == STR` | Iguales (Bash). En `[[ ]]`, el RHS es **patrón glob**. |
| `STR != STR` | Distintos. |
| `STR < STR` | STR1 ordena antes de STR2 (locale). |
| `STR > STR` | STR1 ordena después. |
| `STR =~ REGEX` | STR hace match con la regex ERE (sólo `[[ ]]`). |

El `=~` deposita en el array `BASH_REMATCH` el match completo y los grupos capturados:

```bash
if [[ "$linea" =~ ^([0-9]+)[[:space:]]+(.*)$ ]]; then
  id="${BASH_REMATCH[1]}"
  resto="${BASH_REMATCH[2]}"
fi
```

Tip: no entrecomilles el **lado derecho** del `=~` si contiene regex, o pasa a ser literal. Guarda la regex en una variable intermedia si es compleja: `re='^foo'; [[ $x =~ $re ]]`.

### 6.3 Operadores numéricos

| Operador | Verdadero si… |
|---|---|
| `N -eq M` | N igual a M. |
| `N -ne M` | N distinto de M. |
| `N -lt M` | N menor que M. |
| `N -le M` | N menor o igual que M. |
| `N -gt M` | N mayor que M. |
| `N -ge M` | N mayor o igual que M. |

Importante: **son enteros**. Si pasas `3.14` fallan. Para flotantes, pre-procesa con `bc` o `awk`.

Diferencia con `(( ))`: `[[ -eq ]]` compara **enteros contenidos en strings**; `(( == ))` compara en contexto aritmético puro. En la práctica para números pelados:

```bash
if [[ $n -gt 10 ]]; then …   # legal
if (( n > 10 )); then …       # idiomático
```

Elige `(( ))` para numérico puro; `[[ ]]` cuando mezclas con strings o archivos.

---

## 7. `if` / `elif` / `else` / `fi`

La sintaxis canónica:

```bash
if comando-o-test; then
  …
elif otro-test; then
  …
else
  …
fi
```

Puntos finos:

- `if` evalúa el **exit code** del comando que le sigue, no una "expresión". `[[ ]]` y `(( ))` son comandos cuyo exit code **es** la respuesta booleana.
- Se puede usar cualquier comando: `if grep -q error log.txt; then …`.
- `then` puede ir en línea aparte o en la misma línea tras `;` (preferimos `;` por compacidad).
- No hay `then`/`fi` opcionales. Olvidar el `fi` genera errores lejanos del origen.

### 7.1 Pitfall: `[ $x = $y ]` sin comillas

```bash
x=""
y="algo"
[ $x = $y ]
```

Tras expansión: `[ = algo ]`. El builtin `[` recibe sólo 3 argumentos (sin el `[`, sin el `]`), y rechaza con `[: =: unary operator expected`. Peor aún:

```bash
x="hola mundo"
y="hola"
[ $x = $y ]
```

Tras expansión: `[ hola mundo = hola ]`. `[` lo ve como `hola`, `mundo`, `=`, `hola`: error de sintaxis incoherente. **Nunca** uses `[ ]` sin entrecomillar.

Mitigaciones por orden de preferencia:

1. Usa `[[ ]]`: no splittea, no glob-ea. `[[ $x = $y ]]` funciona aunque `x` esté vacío o tenga espacios.
2. Si debes usar `[ ]` (POSIX), **cita todo**: `[ "$x" = "$y" ]`.
3. Truco histórico `[ "x$x" = "x$y" ]`: evitaba que `-z` / `-n` interpretaran mal variables que empezaran con `-`. Reconócelo; no lo imites.

---

## 8. `case ... esac`

Cuando tu `if`/`elif`/`else` compara **una** variable contra varios patrones, `case` es más limpio.

### 8.1 Sintaxis

```bash
case "$var" in
  patron1)
    comandos
    ;;
  patron2|patron3)
    comandos
    ;;
  *)
    comandos-por-defecto
    ;;
esac
```

- Los patrones son **globs**, no regex: `*`, `?`, `[abc]`, `[!abc]`, `[a-z]`.
- `|` combina alternativas.
- `*)` al final sirve de catch-all; buena práctica para errores explícitos.
- Terminadores: `;;` evalúa esa rama y sale; `;&` cae en la siguiente sin test; `;;&` continúa evaluando patrones restantes.

### 8.2 Ejemplo trabajado

Clasificar archivos por extensión y acción:

```bash
clasificar() {
  local f="$1"
  case "$f" in
    *.log|*.LOG)
      echo "log: $f"
      ;;
    *.tar.gz|*.tgz)
      echo "tarball: $f"
      ;;
    *.gz|*.bz2|*.xz|*.zst)
      echo "comprimido: $f"
      ;;
    README|README.md|readme.txt)
      echo "readme: $f"
      ;;
    .*)
      echo "oculto: $f"
      ;;
    *)
      echo "otro: $f"
      ;;
  esac
}

clasificar app.log       # log: app.log
clasificar backup.tar.gz # tarball: backup.tar.gz
clasificar notes.md      # otro: notes.md
```

Observa que `README.md` matchea en dos ramas (`README.md` y el glob implícito `*.md` si lo hubiera). `case` evalúa **de arriba a abajo** y **para en la primera coincidencia**: el orden importa.

### 8.3 Cuándo `case` y cuándo `if`

| Usa `case` cuando… | Usa `if` cuando… |
|---|---|
| Comparas una variable contra varios valores literales o globs. | Combinas condiciones heterogéneas (archivo + número + string). |
| Hay más de 3 ramas sobre la misma variable. | Hay 1 o 2 condiciones compuestas. |
| Las ramas se expresan como patrones. | Las ramas dependen de operaciones aritméticas o de archivo. |

---

## 9. Aritmética en punto flotante con `bc`

Caso típico: reportar un porcentaje con 2 decimales.

```bash
usado=37
total=120
porcentaje=$(echo "scale=2; $usado * 100 / $total" | bc -l)
echo "Uso: ${porcentaje}%"
# Uso: 30.83%
```

Lo que hay que recordar:

- `scale` controla **decimales de salida**; sin `scale`, resultados enteros.
- `-l` carga `mathlib` y pone `scale=20` por defecto; útil pero verboso. Combinar `scale` tras `-l` fija el valor final.
- `bc` entiende expresiones compuestas con `;` y variables propias.

Comparar floats:

```bash
umbral=0.90
valor=0.87
if (( $(echo "$valor > $umbral" | bc -l) )); then
  echo "sobre umbral"
else
  echo "bajo umbral"
fi
```

`bc` imprime `1` o `0`; `(( ))` lo interpreta como true/false. Patrón idiomático.

Alternativas:

- `awk 'BEGIN{if (0.87 > 0.90) exit 0; else exit 1}'`.
- Reescribir en Python si la lógica flotante crece.

---

## 10. Ejemplos integradores

### 10.1 Chequeo de disco y alerta

```bash
#!/usr/bin/env bash
set -euo pipefail

PART="${1:-/}"
UMBRAL=90

uso=$(df --output=pcent "$PART" | tail -n1 | tr -dc '0-9')

if (( uso >= UMBRAL )); then
  echo "ALERTA: $PART al ${uso}% (umbral ${UMBRAL}%)"
  exit 2
elif (( uso >= UMBRAL - 10 )); then
  echo "WARN: $PART al ${uso}%"
  exit 1
else
  echo "OK: $PART al ${uso}%"
fi
```

### 10.2 Promover un archivo si existe y es ejecutable

```bash
candidato="/tmp/release.sh"

if [[ -f "$candidato" && -x "$candidato" && -s "$candidato" ]]; then
  install -m 0755 "$candidato" /usr/local/bin/release
  echo "Instalado."
else
  echo "Candidato ausente, vacío o no ejecutable; abortando." >&2
  exit 1
fi
```

### 10.3 Router por extensión con `case`

```bash
procesar() {
  local f="$1"
  [[ -f "$f" ]] || { echo "no es archivo: $f" >&2; return 1; }
  case "$f" in
    *.gz)  gunzip -k "$f" ;;
    *.xz)  xz -dk "$f" ;;
    *.zst) zstd -dk "$f" ;;
    *)     echo "formato no soportado: $f" >&2; return 2 ;;
  esac
}
```

---

## 11. Pitfalls recurrentes

1. **`[ $x = $y ]` sin comillas** — ya cubierto; principal causa de bugs intermitentes.
2. **`-eq` sobre strings no numéricos** — `[[ "abc" -eq "abd" ]]` falla con `integer expression expected`. Para strings, usa `=`.
3. **Comparar floats con `(( ))`** — `(( 0.5 > 0.3 ))` falla: `(( ))` sólo acepta enteros. Usa `bc`.
4. **Olvidar `;;` en `case`** — produce "syntax error near unexpected token".
5. **Globs sin entrecomillar en `case`** — en `case "$var"`, el *valor* se entrecomilla pero los **patrones** no. `case "$f" in "*.log")` sería literal, no glob.
6. **Regex entre comillas en `=~`** — `[[ "$x" =~ "^foo" ]]` compara contra el string literal `^foo`, no contra una regex. Deja la regex sin comillas o en variable.
7. **Expresión aritmética con string vacío** — `n=""; (( n + 1 ))` → `n + 1: syntax error: operand expected`. Usa `(( ${n:-0} + 1 ))`.
8. **`[` encadenado con `-a` / `-o`** — `[ -f x -a -r x ]` tiene parsing frágil con nombres raros; prefiere `[[ -f x && -r x ]]` o dos `[ ]` con `&&` entre ellos.

---

## 12. Preguntas de evaluación

Responde sin ejecutar. Luego verifica.

1. ¿Qué imprime `echo $((10/3))` y por qué? ¿Y `echo "scale=2; 10/3" | bc -l`?
2. Explica, línea por línea, qué ocurre al ejecutar `x=""; y="x"; [ $x = $y ]`. ¿Qué cambia con `[[ $x = $y ]]`?
3. ¿Cuándo preferirías `(( ))` sobre `[[ ]]` para comparar dos variables? Da un criterio operativo, no estético.
4. En `[[ "$archivo" == *.log ]]`, ¿por qué el `*.log` **no** se expande como glob a archivos del directorio actual?
5. Diseña un `case` que distinga `*.tar.gz`, `*.gz` sólo, y `*.bz2`. ¿Qué orden de ramas garantiza que un `.tar.gz` no caiga en el patrón `*.gz`?
6. ¿Qué estructura usarías para validar que un argumento `$1` representa un entero entre 1 y 65535 (puerto): `[[ … =~ … ]]`, `(( … ))`, o una combinación? Justifica.
7. ¿Por qué `declare -i n; n="hola"` no da error en Bash y qué consecuencia tiene en un script que lee entrada del usuario?
8. ¿Qué muestra `BASH_REMATCH` tras `[[ "user=42" =~ ^([a-z]+)=([0-9]+)$ ]]`?
9. Un script antiguo usa `expr "$a" \* "$b"`. ¿Qué dos razones concretas justifican reescribirlo con `$((a * b))`?
10. Enumera los operadores que **no existen** en `[ ]` pero sí en `[[ ]]` y da un caso de uso real para cada uno.

---

## 13. Checklist de dominio

- [ ] Puedo elegir sin pensar entre `[[ ]]`, `[ ]`, `(( ))` y `$(( ))` para una condición dada.
- [ ] Puedo justificar por qué `[[ ]]` no requiere entrecomillar las variables y `[ ]` sí.
- [ ] Puedo escribir un `case` con `|` y globs, decidiendo correctamente el orden de las ramas.
- [ ] Puedo computar un porcentaje con 2 decimales en Bash sin recurrir a Python.
- [ ] Puedo leer código ajeno con `expr` o `let` y migrarlo a sintaxis moderna.
- [ ] Mis scripts pasan `shellcheck` sin warnings sobre tests/aritmética.
