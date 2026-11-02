# Recursos — sys-16-loops-and-iteration

Fuentes autoritativas. Verificadas en 2026-11.

## Lectura obligatoria

- **BashFAQ 1 — "How can I read a file line-by-line (or field-by-field)?"**
  https://mywiki.wooledge.org/BashFAQ/001
  La referencia canónica del patrón `while IFS= read -r line`. Explica también `read -d ''`, el gotcha del subshell del pipe, y por qué `for line in $(cat file)` es incorrecto. Léelo entero.

- **BashPitfalls — "Parsing ls"** (Pitfall #1)
  https://mywiki.wooledge.org/ParsingLs
  Detalla, con ejemplos reales, por qué `for f in $(ls)` corrompe nombres con espacios/newlines/globs. Alternativas correctas con `*` o `find -print0`.

- **BashPitfalls — "for i in $(seq 1 10)"** (Pitfall #33 y relacionados)
  https://mywiki.wooledge.org/BashPitfalls
  Catálogo general. Enfócate en los pitfalls numerados 1, 3, 24 y 33 para este módulo.

## Herramientas

- **`jq` — tutorial oficial corto**
  https://jqlang.github.io/jq/tutorial/
  10 minutos. Cubre selección (`.[]`, `.field`), filtros, `-r` (raw output) y `@tsv`. Suficiente para iterar sobre JSON desde Bash.

- **`jq` — manual (referencia)**
  https://jqlang.github.io/jq/manual/
  Para consultar; no leer entero.

## Complementarios

- **Greg's Wiki — "Why you shouldn't parse the output of ls(1)"**
  https://mywiki.wooledge.org/ParsingLs
  (Mismo contenido que arriba; ambos links apuntan al wiki autoritativo.)

- **GNU Bash Reference Manual — "Looping Constructs"**
  https://www.gnu.org/software/bash/manual/html_node/Looping-Constructs.html
  Especificación formal de `for`, `while`, `until`, `select`.

- **`man 1 find`** — sección sobre `-print0`, `-exec … \;` vs `-exec … +`.
