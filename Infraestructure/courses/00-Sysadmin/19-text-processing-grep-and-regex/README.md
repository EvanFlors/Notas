# sys-19 — Procesamiento de texto: `grep` y expresiones regulares

## Identificación

- **ID:** `sys-19-text-processing-grep-and-regex`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:**
  - `sys-02-shell-command-anatomy` (tuberías, redirecciones, `stdin`/`stdout`/`stderr`, exit codes).
  - `sys-16-logs-journald-rsyslog` (ubicación y formato de logs del sistema; necesario para que los ejemplos de "triage" tengan sentido).

## Objetivo

Filtrar datos de texto **a escala** desde la línea de comandos. Al terminar deberías poder: elegir la familia de regex correcta (BRE, ERE, PCRE), construir patrones robustos (anclas, clases, cuantificadores, grupos, backreferences), combinar `grep` con `sed`, `awk`, `cut`, `tr`, `sort`, `uniq -c`, `wc` y `paste` para responder preguntas sobre un log de 1 M líneas en segundos, y decidir con criterio cuándo escalar a Python en vez de encadenar más tuberías.

## Alcance

Este módulo cubre:

- Teoría mínima de **regex**: autómatas (NFA/DFA), por qué `grep -F` es orden de magnitud más rápido, por qué `.*` greedy puede explotar en PCRE (catastrophic backtracking).
- Las tres familias: **BRE** (POSIX basic, `grep` por defecto), **ERE** (`grep -E` / `egrep`), **PCRE** (`grep -P`). Diferencias prácticas en metacaracteres, grupos y escapes.
- `grep` **a fondo**: flags `-i -v -n -r -l -L -c -o -A/-B/-C -f -F -E -P -w -x --include --exclude`, exit codes (0/1/2), uso con `xargs`, interacción con `--color=auto`.
- Anclas (`^ $ \b \<\>`), clases POSIX (`[:alpha:]`, `[:digit:]`...), cuantificadores (`? * + {n,m}` + perezosos `?` en PCRE), grupos capturantes/no-capturantes, backreferences (`\1`), lookaround (solo PCRE).
- `sed`: sustituciones `s/a/b/g`, direcciones de línea, `-i` **in-place** y por qué es peligroso sin backup (y diferencias macOS vs GNU).
- `awk`: `{print $2, $NF}`, `-F`, `BEGIN`/`END`, acumuladores asociativos (`sum[key]++`) para group-by al vuelo.
- Utilidades complementarias: `cut`, `tr`, `sort`, `uniq -c`, `wc -l`, `paste`, `comm`.
- **Árbol de decisión**: grep (filtrar) → sed (sustituir) → awk (columnas y agregación) → python/pandas (joins complejos, formatos binarios, tests).

Lo que **no** cubre:

- Scripts bash robustos → `sys-13` / `sys-14`.
- Parsing de JSON/YAML con `jq`/`yq` → `sys-20`.
- Procesamiento en Python/pandas → curso de Python.

## Materiales

- **`theory/lesson.md`** — lección profunda (~600 líneas), con tabla comparativa BRE/ERE/PCRE, cheatsheet de flags de `grep`, un *worked walkthrough* de triage de un `access.log`, y árbol de decisión `grep`/`sed`/`awk`/`python`.
- **`examples/`** — ejemplos ejecutables:
  - `01-regex-family-differences/` — misma intención expresada en BRE, ERE y PCRE sobre el mismo input.
  - `02-awk-columns/` — group-by y suma de una columna de un CSV.
- **`activities/`**:
  - `01-log-triage-with-grep/` — *guided lab* (75 min). Diez preguntas sobre un `access.log` sintético.
  - `02-regex-pattern-dojo/` — *independent* (60 min). Escribir regexes para IPv4, email, ISO date, UUID, variable bash, URL, etc.
- **`resources/links.md`** — man pages, GNU grep manual, `pcre2pattern(3)`, artículos de Russ Cox.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `grep -F` es sublineal frente a `grep -E`. Diferenciar BRE/ERE/PCRE sin consultar. Reconocer un patrón vulnerable a backtracking catastrófico. |
| Operativa | Responder 10 preguntas sobre un `access.log` de >100 k líneas en <5 min usando solo CLI. Construir un `sed -i` seguro (con backup y dry-run). Hacer un group-by de errores por hora con `awk`. |
| Arquitectónica | Decidir cuándo detener la tubería y escribir Python. Elegir `grep` vs `rg` vs `ag` con criterio. Diseñar un pipeline de triage reproducible en un `runbook.md`. |

## Criterios de evaluación

- Las dos actividades pasan sus `tests/validate.sh`.
- Puedes escribir desde cero una regex ERE para email, IPv4 e ISO-8601 sin consultar.
- Explicas por qué `grep 'a.*b'` sobre `a` repetido 30 veces + sin `b` final es lento en PCRE y rápido en BRE/ERE de GNU.
- Produces un one-liner `awk` que agrupa `access.log` por código de respuesta y lo ordena por volumen.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo, deteniéndote en el walkthrough de log-triage.
2. Reproduce `examples/01-regex-family-differences/` ejecutando `demo.sh` paso a paso.
3. Reproduce `examples/02-awk-columns/`.
4. Haz `activities/01-log-triage-with-grep/` (guided; apóyate en la lección si te atascas).
5. Haz `activities/02-regex-pattern-dojo/` **sin** consultar (es evaluación real).
6. Vuelve a `theory/lesson.md` §árbol de decisión y marca cuándo habrías elegido Python.

## Siguiente

→ `sys-20-structured-text-jq-and-yq`: parsing de JSON/YAML, cuando `grep` deja de ser la herramienta correcta.
