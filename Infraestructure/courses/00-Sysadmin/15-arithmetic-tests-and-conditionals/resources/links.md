# Recursos — sys-15

## Documentación oficial de Bash

- **Bash Reference Manual (root)** — <https://www.gnu.org/software/bash/manual/bash.html>
- **Conditional Expressions** (operadores de `[` y `[[ ]]`) — <https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html>
- **Conditional Constructs** (`if`, `case`, `[[ ]]`) — <https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html>
- **Arithmetic Expansion** (`$(( ))`) — <https://www.gnu.org/software/bash/manual/html_node/Arithmetic-Expansion.html>
- **Shell Arithmetic** (operadores y precedencia) — <https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html>
- **Pattern Matching** (globs usados en `case`) — <https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html>

## Páginas de manual

- **`test(1)`** — operadores portables POSIX.
- **`bash(1)`** — sección `CONDITIONAL EXPRESSIONS` y `COMPOUND COMMANDS`.
- **`bc(1)`** — calculadora de precisión arbitraria.

## Greg's Wiki (bash-hackers de referencia)

- **BashFAQ/031** — "What is the difference between `[`, `[[`, and `(( ))`?" — <https://mywiki.wooledge.org/BashFAQ/031>
- **BashFAQ/028** — "Why doesn't my expression `(( "$foo" > 7 ))` work?" — <https://mywiki.wooledge.org/BashFAQ/028>
- **BashPitfalls** — <https://mywiki.wooledge.org/BashPitfalls> (lecturas obligadas: #4, #6, #11, #35).
- **BashGuide/TestsAndConditionals** — <https://mywiki.wooledge.org/BashGuide/TestsAndConditionals>

## Especificación POSIX

- **`test` utility** — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/test.html>
- **Shell Command Language — Compound Commands** — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_09>

## Herramientas de calidad

- **ShellCheck** — <https://www.shellcheck.net/> y <https://github.com/koalaman/shellcheck>
  - Reglas clave para este módulo: `SC2086` (word splitting), `SC2170` (compare `-eq` con string), `SC2053` (quoting en `=~`), `SC2004` (`$` innecesario dentro de `(( ))`).
- **Google Shell Style Guide** — <https://google.github.io/styleguide/shellguide.html>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4. Todos los dominios son oficiales (`gnu.org`, `mywiki.wooledge.org`, `pubs.opengroup.org`, `shellcheck.net`, `github.com`, `google.github.io`); re-verificar al congelar el curso.
