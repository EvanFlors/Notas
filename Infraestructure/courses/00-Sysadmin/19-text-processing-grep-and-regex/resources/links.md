# Recursos — sys-19

## Páginas de manual (lectura obligatoria)

- `man 1 grep` — y especialmente la sección sobre **matching control** y los flags `-E`/`-F`/`-P`.
- `man 1 sed` — presta atención a la diferencia GNU vs BSD en `-i`.
- `man 1 awk` o `man 1 gawk` — `gawk` tiene features (coprocesos, sort del lado del lenguaje) que `mawk`/BSD no.
- `man 7 regex` — teoría POSIX de BRE/ERE.
- `man 3 pcre2pattern` — la referencia canónica de sintaxis PCRE2 (lo que usa `grep -P` modernamente).
- `man 1 cut`, `man 1 tr`, `man 1 sort`, `man 1 uniq`, `man 1 wc`, `man 1 paste`, `man 1 comm`.

## Documentación oficial

- **GNU grep manual** — <https://www.gnu.org/software/grep/manual/grep.html>
- **GNU sed manual** — <https://www.gnu.org/software/sed/manual/sed.html>
- **GNU awk (`gawk`) manual** — <https://www.gnu.org/software/gawk/manual/gawk.html>
- **PCRE2 pattern reference** — <https://www.pcre.org/current/doc/html/pcre2pattern.html>
- **POSIX regular expressions** (The Open Group) — <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html>

## Fundamentos y profundidad

- **Russ Cox — Regular Expression Matching Can Be Simple And Fast** — <https://swtch.com/~rsc/regexp/regexp1.html>
  (serie imprescindible para entender por qué el motor de GNU grep gana a Perl en patrones peligrosos).
- **Russ Cox — Regular Expression Matching: The Virtual Machine Approach** — <https://swtch.com/~rsc/regexp/regexp2.html>
- **Russ Cox — Regular Expression Matching in the Wild** — <https://swtch.com/~rsc/regexp/regexp3.html>
- **ReDoS (Regular Expression Denial of Service)** (OWASP) — <https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS>

## Herramientas modernas complementarias

- **ripgrep** (`rg`) — <https://github.com/BurntSushi/ripgrep>. Alternativa recursiva, por defecto respeta `.gitignore`.
- **The Silver Searcher** (`ag`) — <https://geoff.greer.fm/ag/>. Precursor de `rg`.
- **regex101** — <https://regex101.com/>. Playground con breakdown; útil para explicar un patrón a un compañero.
- **debuggex** — <https://www.debuggex.com/>. Visualiza el NFA/railroad de una regex.

## Lectura larga (opcional)

- **"The AWK Programming Language"**, Aho/Weinberger/Kernighan, 2.ª ed. 2024 — el libro canónico.
- **"Mastering Regular Expressions"**, Jeffrey E. F. Friedl, 3.ª ed. — pesada pero exhaustiva sobre PCRE y motores con backtracking.

## Nota de verificación

Última verificación de enlaces: pendiente de validar en fase de ejecución del curso. Todos los enlaces apuntan a dominios oficiales (`gnu.org`, `pcre.org`, `opengroup.org`, `swtch.com`, `owasp.org`, `github.com`); si alguno cambia, buscar por título.
