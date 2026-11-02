# sys-19 — Lección: `grep`, regex y las herramientas de texto Unix

> "El 80 % del trabajo de un sysadmin es filtrar texto. El 20 % restante es decidir *qué* filtrar."

## 0. Mapa de la lección

1. Por qué el modelo "todo es texto" sigue vigente.
2. Qué es una regex (NFA/DFA, en 3 minutos).
3. Las tres familias POSIX/PCRE: BRE, ERE, PCRE. Tabla comparativa.
4. `grep` a fondo: flags, exit codes, rendimiento.
5. Anclas, clases POSIX, cuantificadores, grupos, backreferences, lookaround.
6. `sed`: sustituciones y el peligro de `-i`.
7. `awk`: columnas y agregaciones.
8. Utilidades compañeras: `cut`, `tr`, `sort`, `uniq -c`, `wc`, `paste`, `comm`.
9. Worked walkthrough: triage de un `access.log`.
10. Árbol de decisión: `grep` vs `sed` vs `awk` vs Python.
11. Rendimiento y antipatrones (backtracking catastrófico, `cat | grep`, UUOC).
12. Preguntas de evaluación.

---

## 1. Por qué "todo es texto" sigue vigente

Unix hizo una apuesta temprana: la **interoperabilidad entre programas se logra con texto plano estructurado por líneas y campos**, no con APIs binarias ni con ORBs. Cincuenta años después:

- Los logs del kernel (`dmesg`), de `systemd` (`journalctl -o cat`), de nginx, Apache, Postgres, Kubernetes (en modo `-o wide`), de contenedores (`docker logs`) — **todos** terminan siendo líneas con campos separados por espacio, tab, coma, o un formato semi-estructurado (JSON por línea, "JSONL").
- Los formatos de configuración de la mayoría del stack (`/etc/*`, `sshd_config`, `nginx.conf`, `.env`, `Dockerfile`, `Makefile`) son texto.
- Incluso lo estructurado modernamente (YAML, JSON, Prometheus `/metrics`) se consume frecuentemente con herramientas de línea.

El resultado práctico: **saber filtrar texto es saber operar sistemas Unix**. Y la herramienta más antigua y aún más usada para ese trabajo se llama `grep` — abreviatura de `g/re/p`, el comando del editor `ed` que significaba "global, regex, print".

---

## 2. Qué es una regex, en 3 minutos

Una **expresión regular** es un lenguaje para describir conjuntos de strings. Formalmente equivale a un **autómata finito** (NFA no determinista o DFA determinista). Dos consecuencias prácticas:

- **Un motor regex "verdadero"** (lo que hace GNU `grep` por defecto) construye un DFA/NFA y evalúa en **tiempo lineal** respecto al input, independiente de la complejidad del patrón.
- **Un motor con backtracking** (PCRE, Perl, Python `re`, JavaScript) añade features no regulares (backreferences, lookaround), pero paga el precio: ciertos patrones + ciertos inputs disparan **backtracking catastrófico** y el matching puede volverse exponencial.

Mitos a desterrar desde ya:

- "Las regex son lentas". **Falso** en motores DFA (grep, ripgrep). Son casi siempre O(n) sobre el input.
- "Siempre es mejor PCRE porque tiene más features". **Falso**: paga complejidad y riesgo de ReDoS por features que casi nunca necesitas.
- "Las regex pueden parsear HTML". **Falso**, HTML no es regular. Para parsear estructuras anidadas usa un parser real.

Lectura obligatoria (ligera): los dos primeros artículos de Russ Cox en `swtch.com/~rsc/regexp/` (ver `resources/links.md`). Explican por qué grep de GNU es rápido y Perl no.

---

## 3. BRE, ERE, PCRE: la tabla que te ahorra una hora de confusión

Hay **tres familias** de regex que verás en Unix. Son distintas en metacaracteres, no en poder expresivo (BRE y ERE son equivalentes; PCRE es un superconjunto). Elegir una u otra se reduce casi siempre a **qué flag pasar a `grep`**.

| Feature                          | BRE (`grep`)   | ERE (`grep -E`, `egrep`) | PCRE (`grep -P`) |
|----------------------------------|----------------|--------------------------|------------------|
| `.`, `*`, `[...]`, `^`, `$`      | sí             | sí                       | sí               |
| Alternancia                      | `\|`           | `\|`                     | `\|`             |
| Grupo capturante                 | `\(...\)`      | `(...)`                  | `(...)`          |
| Grupo no capturante              | no soportado   | no soportado             | `(?:...)`        |
| Cuantificador 1+                 | `\{1,\}` o `\+` (GNU ext.) | `+`         | `+`              |
| Cuantificador 0..1               | `\?` (GNU ext.) | `?`                     | `?`              |
| Cuantificador acotado            | `\{n,m\}`      | `{n,m}`                  | `{n,m}`          |
| Backreference en patrón          | `\1`           | `\1`                     | `\1`             |
| Lookahead `(?=...)` / behind     | no             | no                       | sí               |
| Perezoso `?`                     | no             | no                       | sí (`*?`, `+?`)  |
| `\d`, `\w`, `\s`                 | no             | no (sí con GNU ext.)     | sí               |
| Clases POSIX `[[:alpha:]]`       | sí             | sí                       | sí               |
| Riesgo de backtracking catast.   | muy bajo       | muy bajo                 | **alto**         |

**Regla práctica**:

1. **Empieza en ERE** (`grep -E`): metacaracteres sin escapes torturados, suficiente para el 95 % de los filtrados reales.
2. **Baja a BRE** solo si el entorno lo exige (scripts portables, `sed` básico, grep muy viejo).
3. **Sube a PCRE** solo si necesitas lookaround, grupos no capturantes, perezosos, o `\d/\w/\s`.
4. **Si solo buscas strings literales**, usa `grep -F` (fijo). Es más rápido y evita escapar metacaracteres.

> `egrep` y `fgrep` existen como aliases de `grep -E` y `grep -F`. Están **oficialmente deprecados** en GNU grep ≥ 3.8 pero siguen funcionando. Usa las formas con flag.

---

## 4. `grep` a fondo

### 4.1 Flags que debes conocer de memoria

| Flag          | Significado                                                                 |
|---------------|-----------------------------------------------------------------------------|
| `-i`          | Ignore case. Costoso en entradas multibyte si tu `LANG` es UTF-8.           |
| `-v`          | Invertir match: imprime líneas que NO coinciden.                            |
| `-n`          | Prefija cada línea con su número.                                           |
| `-r` / `-R`   | Recursivo. `-R` sigue symlinks; `-r` no.                                    |
| `-l`          | Imprime solo los **nombres de archivo** con al menos un match.              |
| `-L`          | Lo contrario: nombres de archivo **sin** matches.                           |
| `-c`          | Imprime el **conteo** de líneas que coinciden por archivo.                  |
| `-o`          | Imprime solo la **parte** de la línea que coincide (una por línea).         |
| `-A N`        | Imprime N líneas **después** del match (After).                             |
| `-B N`        | Imprime N líneas **antes** (Before).                                        |
| `-C N`        | Contexto: N líneas antes y después.                                         |
| `-f FILE`     | Patrones (uno por línea) leídos de FILE. Combina con `-F` para IOCs/blacklists. |
| `-F`          | Patrones **fijos** (literales). Más rápido; no interpreta metacaracteres.   |
| `-E`          | ERE. Equivalente a `egrep`.                                                 |
| `-P`          | PCRE (requiere compilación con libpcre, no siempre presente).               |
| `-w`          | Match de palabra entera (equivale a envolver en `\b...\b`).                 |
| `-x`          | Match de **línea entera**.                                                  |
| `--include=`  | Al recursar, limita por glob (`--include='*.log'`).                         |
| `--exclude=`  | Excluye por glob. Combinable con `--exclude-dir`.                           |
| `--color=auto`| Resalta la coincidencia; auto detecta si stdout es TTY.                     |
| `-m N`        | Para después de N matches (útil con pipes gigantes).                        |
| `-z`          | Trata la entrada separada por `\0` en lugar de `\n` (útil con `find -print0`). |

### 4.2 Exit codes de `grep`

| Code | Significado                              |
|------|------------------------------------------|
| 0    | Al menos una línea coincidió.            |
| 1    | **Ninguna** línea coincidió.             |
| 2    | Error (archivo no encontrado, regex inválida...). |

Esto te permite usarlo como **predicado** en scripts:

```bash
if grep -q "^Status: 200" response.txt; then
  echo "ok"
fi
```

`grep -q` (quiet) suprime la salida y es el idiomatismo correcto para "¿existe esta línea?".

### 4.3 Rendimiento: por qué `-F` importa

`grep -F "ERROR"` sobre un `access.log` de 1 GB puede ir **5–10× más rápido** que `grep "ERROR"` sin flags (BRE), porque:

- `-F` usa **Aho–Corasick** para múltiples strings y Boyer-Moore para uno solo: salta bytes en lugar de leerlos.
- La regex engine debe construir un DFA y evaluar carácter por carácter.

Regla operativa: **si tu patrón no tiene metacaracteres, pon `-F`**.

### 4.4 Antipatrones comunes

- **UUOC** ("Useless Use of Cat"): `cat file | grep X` ⟶ `grep X file`. `grep` ya lee archivos.
- **`grep | grep | grep`**: típicamente colapsable en una regex con alternancia o en un `awk` que filtra con condiciones.
- **`grep -r` en todo `/`** sin `--include`: lento y ruidoso.
- **`ls | grep X`**: usa `find`, maneja espacios y newlines en nombres correctamente.

---

## 5. Anclas, clases, cuantificadores, grupos, backreferences

### 5.1 Anclas

| Ancla | Significado                                 |
|-------|---------------------------------------------|
| `^`   | Inicio de línea                             |
| `$`   | Fin de línea                                |
| `\b`  | Frontera de palabra (BRE/ERE con GNU ext.; PCRE sí). |
| `\<`  | Inicio de palabra (GNU)                     |
| `\>`  | Fin de palabra (GNU)                        |
| `\A`  | Inicio del **buffer** (PCRE)                |
| `\z`  | Fin del buffer (PCRE)                       |

`^` y `$` operan por **línea**, no por archivo completo. Es por diseño: `grep` procesa línea a línea.

### 5.2 Clases POSIX (portables)

Dentro de `[...]`:

| Clase          | Equivale aprox. a       |
|----------------|-------------------------|
| `[:alpha:]`    | `[A-Za-z]`              |
| `[:alnum:]`    | `[A-Za-z0-9]`           |
| `[:digit:]`    | `[0-9]`                 |
| `[:space:]`    | whitespace incl. tab/nl |
| `[:upper:]`    | `[A-Z]`                 |
| `[:lower:]`    | `[a-z]`                 |
| `[:xdigit:]`   | `[0-9A-Fa-f]`           |
| `[:punct:]`    | puntuación              |

Uso: `grep -E '^[[:alpha:]]+$'` (dentro de `[]`, note los **dobles corchetes**).

Las abreviaturas Perl (`\d`, `\w`, `\s`) **solo son estándar en PCRE**. GNU las acepta como extensión en BRE/ERE, pero tu script dejará de ser portable.

### 5.3 Cuantificadores

| Cuantificador | ERE / PCRE | BRE          | Significa                              |
|---------------|------------|--------------|----------------------------------------|
| `?`           | 0 o 1      | `\?` (GNU)   | opcional                               |
| `*`           | 0 o más    | `*`          | cero o más                             |
| `+`           | 1 o más    | `\+` (GNU)   | uno o más                              |
| `{n}`         | exactamente n | `\{n\}`   | exactamente n                          |
| `{n,m}`       | entre n y m | `\{n,m\}`   | entre n y m                            |
| `*?` `+?` `??`| perezoso (PCRE) | n/a    | match mínimo en lugar de máximo        |

### 5.4 Grupos y backreferences

- **Capturantes**: `(abc)` (ERE/PCRE) o `\(abc\)` (BRE). Se referencian como `\1`, `\2`...
- **No capturantes** (PCRE): `(?:abc)`. Útiles para agrupar sin consumir slot de captura.
- **Backreferences en patrón**: `\(a*\)\1` matchea cualquier string de forma `aaa aaa`. Útil para detectar duplicados.
- **Backreferences en reemplazo** (sed/awk `gsub`): `sed -E 's/(foo)(bar)/\2\1/'`.

> Las backreferences convierten una regex en **no regular** (en el sentido formal). Es la razón de que los motores con backreferences deban hacer backtracking.

### 5.5 Lookaround (solo PCRE)

- Lookahead positivo: `foo(?=bar)` — matchea `foo` solo si va seguido de `bar` (sin consumir `bar`).
- Lookahead negativo: `foo(?!bar)`.
- Lookbehind positivo: `(?<=foo)bar`.
- Lookbehind negativo: `(?<!foo)bar`.

Útiles para extraer sin consumir el contexto. Si tu problema requiere lookaround complicado, considera que probablemente **ya no es un problema de grep** y debería ir a Python.

---

## 6. `sed`: sustituir texto

`sed` es un **stream editor**. Lee línea a línea, aplica comandos, imprime.

### 6.1 La sustitución, 90 % del uso real

```
s/PATRÓN/REEMPLAZO/FLAGS
```

- Flag `g`: todas las ocurrencias en la línea (no solo la primera).
- Flag `I`: case-insensitive (GNU).
- Flag `N` (número): solo la N-ésima ocurrencia.
- Delimitador alternativo: `s|/etc/foo|/opt/foo|g` para evitar escapar barras.

Ejemplos:

```bash
sed 's/ERROR/WARN/g' file.log           # imprime a stdout
sed -E 's/\s+/ /g' file.txt             # colapsa whitespace (ERE con -E)
sed -n '/^Date:/p' email.txt            # -n suprime default; p imprime
sed '10,20d' file.txt                   # borra líneas 10 a 20
sed -E 's/(foo)(bar)/\2\1/' x.txt       # swap de grupos
```

### 6.2 `-i` in-place: por qué es peligroso

`sed -i 's/old/new/g' file.txt` **sobrescribe el archivo**. Si tu patrón está mal, no hay deshacer.

Protecciones mínimas:

1. **Siempre haz un dry-run primero** (`sed 'PATRÓN' file | diff - file`).
2. **Siempre pasa un sufijo de backup**: GNU acepta `sed -i.bak`; macOS/BSD **exige** el sufijo (`sed -i '' ...` para no backup; `sed -i.bak ...` para backup). Esta diferencia rompe scripts "portables" todo el tiempo.
3. **Nunca uses `sed -i` sobre archivos en `/etc/` sin snapshot/VCS**.

Forma portable (GNU + BSD):

```bash
# Crea un backup .bak y modifica in-place
sed -i.bak -E 's/old/new/g' config.conf
```

### 6.3 Direcciones

- Por número: `sed '5s/foo/bar/'` solo línea 5.
- Por rango: `sed '10,20d'`.
- Por regex: `sed '/^#/d'` borra comentarios.
- Última línea: `$`. Rango `/A/,/B/`: desde la línea que matchea A hasta la que matchea B.

---

## 7. `awk`: cuando necesitas columnas y agregaciones

`awk` es un lenguaje completo pensado para texto tabular. Para sysadmins, el 95 % del uso cae en patrones breves.

### 7.1 Básicos

- `$0` es la línea entera; `$1`, `$2`... los campos. `NF` = número de campos; `$NF` = último.
- `-F` fija el separador (`-F:` para `/etc/passwd`; `-F','` para CSV simple; `-F'\t'` para TSV).
- Estructura: `PATRÓN { ACCIÓN }`. Si el patrón se omite, actúa en todas las líneas.

```bash
awk '{print $1, $NF}' access.log            # primer y último campo
awk -F: '{print $1}' /etc/passwd            # usuarios
awk 'NR==1 || /ERROR/' app.log              # cabecera + líneas con ERROR
awk 'length($0) > 100' huge.log             # líneas largas
```

### 7.2 Group-by y suma

Esto es lo que hace a `awk` imprescindible. Un arreglo asociativo acumula resultados y `END` los imprime:

```bash
# Contar peticiones por código HTTP (campo 9 en log de nginx estándar)
awk '{count[$9]++} END {for (k in count) print k, count[k]}' access.log

# Sumar bytes servidos por URL (campo 7, bytes campo 10)
awk '{sum[$7]+=$10} END {for (u in sum) printf "%-40s %d\n", u, sum[u]}' access.log
```

### 7.3 BEGIN y END

```bash
awk 'BEGIN {FS=","; OFS="\t"} {print $2, $5} END {print "total:", NR}' data.csv
```

### 7.4 Cuándo `awk` deja de valer la pena

- Si necesitas joins reales entre dos tablas: considera `join`, `sqlite3`, o Python/pandas.
- Si tienes decimales con locale conflictivo: `awk` depende del locale. Fija `LC_ALL=C`.
- Si el "CSV" tiene comillas y comas internas: usa un parser de verdad (`python -c "import csv"` o `csvkit`), no `awk -F,`.

---

## 8. Las utilidades compañeras

| Utilidad   | Para qué                                                         |
|------------|------------------------------------------------------------------|
| `cut`      | Cortar por posición de carácter (`-c`) o por campo (`-f`, con `-d`). Rápido pero inflexible. |
| `tr`       | Traducir/borrar caracteres (sin regex). `tr -s ' '` colapsa espacios. `tr -d '\r'` quita CR. |
| `sort`     | Ordenar. Flags clave: `-u` únicos, `-n` numérico, `-k 2` por columna 2, `-t,` separador. |
| `uniq -c`  | Cuenta repeticiones. Solo detecta **adyacentes**: casi siempre va después de `sort`. |
| `wc`       | `-l` líneas, `-w` palabras, `-c` bytes.                          |
| `paste`    | Pega archivos lado a lado (une por línea).                       |
| `comm`     | Compara dos archivos **ordenados**: columnas "solo en A", "solo en B", "en ambos". |
| `head`/`tail` | Primeras/últimas N líneas. `tail -F` sigue un log aunque rote. |

Idiomatismo clásico — "top 10 strings más repetidos":

```bash
sort file | uniq -c | sort -rn | head -10
```

---

## 9. Worked walkthrough: triage de un `access.log`

Supón un `access.log` de nginx con formato estándar:

```
203.0.113.5 - - [12/May/2026:14:03:11 +0000] "GET /api/v1/users HTTP/1.1" 200 1532 "-" "curl/8.1"
```

Las preguntas típicas de una llamada de incidente a las 3am:

### Q1 — ¿Cuántas peticiones hubo en total?

```bash
wc -l access.log
```

### Q2 — ¿Cuántos 5xx?

```bash
awk '$9 ~ /^5/' access.log | wc -l
# o equivalente:
grep -E ' "[A-Z]+ [^"]+ HTTP/[0-9.]+" 5[0-9]{2} ' access.log | wc -l
```

### Q3 — Top 10 IPs por volumen

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10
```

### Q4 — Top 10 URLs 5xx

```bash
awk '$9 ~ /^5/ {print $7}' access.log | sort | uniq -c | sort -rn | head -10
```

### Q5 — ¿Qué user-agents hacen scraping (más de 1000 req)?

```bash
awk -F'"' '{print $6}' access.log | sort | uniq -c | awk '$1 > 1000' | sort -rn
```

### Q6 — Peticiones por minuto

```bash
awk '{print substr($4, 2, 17)}' access.log | sort | uniq -c
# $4 es "[12/May/2026:14:03:11", recortamos los segundos
```

### Q7 — IPs que recibieron solo 403

```bash
awk '{print $1, $9}' access.log \
  | sort -u \
  | awk '{seen[$1]++; code[$1]=$2} END {for (ip in seen) if (seen[ip]==1 && code[ip]=="403") print ip}'
```

### Q8 — Encontrar las trazas de un request-id

Si el log tiene `request_id=XYZ`, contexto de 2 líneas antes y 5 después:

```bash
grep -n -B 2 -A 5 "request_id=abcd1234" app.log
```

### Q9 — Rebuild de rutas: ¿cuántas variantes de `/api/v1/users/*` hay?

```bash
grep -oE '/api/v1/users/[^ ?"]*' access.log | sort -u
```

### Q10 — Error rate por hora

```bash
awk '
  {
    hour = substr($4, 2, 14)           # [12/May/2026:14
    total[hour]++
    if ($9 ~ /^5/) err[hour]++
  }
  END {
    for (h in total) printf "%s  total=%d  5xx=%d  rate=%.2f%%\n", h, total[h], err[h]+0, (err[h]+0)/total[h]*100
  }
' access.log | sort
```

Si en algún momento sientes que estás construyendo un AST sobre `awk`: **detente y escribe Python**.

---

## 10. Árbol de decisión: `grep` vs `sed` vs `awk` vs Python

```
¿Qué quieres hacer?
│
├── Filtrar líneas por un patrón
│   └── grep (-F si literal, -E si metacaracteres, -P si lookaround)
│
├── Reemplazar strings dentro de líneas
│   └── sed  (-i con backup; dry-run antes)
│
├── Trabajar con columnas / separadores
│   ├── Extraer una columna fija → cut
│   └── Transformar o agregar → awk
│
├── Agrupar + contar + sumar
│   └── awk  (asociativos)  ó  sort | uniq -c | sort -rn
│
├── Joins entre dos tablas, parsing JSON/CSV con comillas,
│   lookaround complejo, output a múltiples archivos
│   └── Python  (csv, json, pandas)
│
└── Buscar en >10 GB de código recursivo
    └── ripgrep (rg)  — mantiene semántica tipo PCRE, pero multi-thread
```

### 10.1 La frontera `awk` → Python

**Pasa a Python cuando**:

- Necesitas estructura: diccionarios anidados, no asociativos simples.
- Debes correlacionar **dos** fuentes de datos.
- El formato tiene **escape rules** (CSV con comillas, JSON, YAML).
- Vas a reusar la lógica en >1 lugar → merece un módulo, no una pipe.
- Quieres **tests** sobre el resultado.

**Quédate en `awk`/`grep` cuando**:

- Es un one-off en una terminal.
- La corrección se valida visualmente (`| head`).
- La fuente es homogénea (todas las líneas tienen la misma forma).
- Lo pondrás en un `runbook.md`, no en producción.

---

## 11. Rendimiento y antipatrones

### 11.1 Backtracking catastrófico

```
# Patrón: (a+)+b   Input: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"  (sin 'b')
grep -P '(a+)+b' <<<"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
```

En PCRE puede tardar **minutos** sobre un input de 30 chars. GNU grep en BRE/ERE, por usar DFA, lo resuelve en microsegundos.

Mitigaciones:

- Usar BRE/ERE si no necesitas features de PCRE.
- Reescribir el patrón sin anidamientos ambiguos: `a+b` ya es equivalente a `(a+)+b` sin la trampa.
- Si estás obligado a usar PCRE con input no confiable, considera `grep -P` con límites del sistema (`ulimit -t`).

### 11.2 `cat | grep`

```bash
cat file.log | grep ERROR         # UUOC
grep ERROR file.log               # correcto
```

`grep` ya lee archivos; añadir `cat` consume un proceso y hace la línea más larga sin beneficio. Único caso válido: cuando usas varios archivos y necesitas una pipe de verdad por un filtro previo (`zcat`, `nc`, etc.).

### 11.3 `ls | grep`

```bash
ls | grep '.log$'                 # mal: rompe con espacios/newlines
find . -maxdepth 1 -name '*.log'  # bien
```

### 11.4 Locale

`sort`, `grep -i`, clases `[:alpha:]`, dependen del `LC_ALL`. Para scripts reproducibles:

```bash
export LC_ALL=C
```

Esto hace que `[A-Z]` signifique exactamente `[ABCDEFGHIJKLMNOPQRSTUVWXYZ]`, el orden sea bytewise, y `sort` sea 2–3× más rápido.

### 11.5 Terminadores raros: `\0` y `\r`

- `find -print0 | xargs -0`: usa `\0` como separador para sobrevivir a nombres con espacios.
- Archivos Windows traen CRLF. `tr -d '\r' < win.txt > unix.txt` o `dos2unix`.

### 11.6 grep vs ripgrep

`ripgrep` (`rg`) es un reemplazo moderno escrito en Rust. Por defecto:

- Recursivo (no necesitas `-r`).
- Respeta `.gitignore`.
- Multi-threaded.
- Usa regex syntax tipo PCRE2 (sin lookaround por defecto, activable con `--pcre2`).

Para **codebases** es casi siempre mejor que `grep`. Para **logs** y pipelines Unix clásicos, `grep` sigue siendo el estándar (está instalado en todas partes, interopera con todo).

---

## 12. Preguntas de evaluación

Responde sin consultar. Si fallas más de dos, re-lee las secciones indicadas.

1. (§3) Diferencia entre `+` en BRE, ERE y PCRE.
2. (§4.2) ¿Qué devuelve `grep -q "foo" vacio.txt; echo $?` si el archivo existe pero está vacío?
3. (§4.3) ¿Por qué `grep -F` es más rápido que `grep` o `grep -E` cuando el patrón no tiene metacaracteres? Nombra el algoritmo.
4. (§5.2) ¿Es portable `grep '\d'` entre GNU y BSD grep? Alternativa POSIX.
5. (§6.2) Da un comando `sed -i` que funcione **igual** en macOS y en Linux. ¿Qué sufijo necesitas?
6. (§7.2) Escribe un one-liner `awk` que agrupe `/var/log/syslog` por "programa" (campo 5) y cuente ocurrencias.
7. (§8) Explica por qué `uniq -c` sin `sort` previo es (casi) siempre un bug.
8. (§9) ¿Cómo extraes el request-id de un log con grep -o si tiene formato `request_id=UUID`?
9. (§10) Da **dos** señales objetivas para pasar de `awk` a Python.
10. (§11.1) Da un ejemplo de regex vulnerable a backtracking catastrófico y explica por qué.
11. (§11.4) ¿Por qué `LC_ALL=C` acelera `sort`?
12. (§11.6) Nombra dos razones concretas por las que `rg` suele ser mejor que `grep -r` en una codebase.

---

## Resumen de 1 página

- Elige **ERE por defecto** (`grep -E`); **F** si literal, **P** si lookaround.
- `grep` es un **predicado**: `-q`, exit code 0/1/2, úsalo en condicionales.
- Para columnas, **`awk`**; para sustitución, **`sed`**; para joins, **Python**.
- Escribe `set -euo pipefail` en tus scripts (ver `sys-14`).
- `-i` de `sed` es un cuchillo sin funda: dry-run + backup.
- Backtracking catastrófico vive en PCRE; BRE/ERE de GNU no lo sufren.
- Fija `LC_ALL=C` en pipelines reproducibles.
- Si llevas 3 pipes y sigues sin la respuesta: considera subir el problema de nivel.

Siguiente módulo: `sys-20-structured-text-jq-and-yq`, cuando el input ya no es "líneas con campos" sino un árbol.
