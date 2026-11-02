# Ejemplo 01 — Misma intención en BRE, ERE y PCRE

## Concepto que demuestra

Las tres familias de regex de `grep` expresan **lo mismo** con sintaxis distinta. Ver los tres patrones lado a lado sobre el mismo input quita el misterio.

## Objetivo

Al terminar podrás:

- Reconocer cuándo un metacaracter necesita `\` (BRE) y cuándo no (ERE/PCRE).
- Decidir qué flag pasar a `grep` según el patrón.
- Entender qué features **solo** existen en PCRE.

## Prerrequisitos

- Bash y GNU `grep` ≥ 3.0.
- `grep -P` requiere que tu `grep` esté compilado con libpcre. Si falla, el script lo detecta y lo salta.

## Ejecución

```bash
cd examples/01-regex-family-differences
bash files/demo.sh
```

## Qué hace el script

Sobre `files/sample.txt` (una mezcla de líneas con palabras, números, emails, UUIDs y URLs), aplica tres patrones equivalentes expresados en BRE, ERE y PCRE para:

1. **"palabras de 3 o más vocales"** — muestra la diferencia en el cuantificador `+`.
2. **"líneas con un par de palabras idénticas separadas por espacio"** — muestra backreferences, iguales en las tres familias.
3. **"email con dominio `.com`"** — muestra escapes de `.` y agrupación.
4. **"número precedido por `$` pero sin consumirlo"** — solo PCRE (lookbehind).

## Resultado esperado

El script imprime cada patrón, lo ejecuta y muestra los matches, de forma que puedas ver que BRE y ERE producen el mismo resultado y PCRE añade una capacidad extra.

## Interpretación

- BRE requiere `\+`, `\?`, `\{n,m\}`, `\(...\)` para los cuantificadores "modernos" y grupos — es el default por razones históricas.
- ERE libera esos metacaracteres: `+`, `?`, `{n,m}`, `(...)` sin `\`.
- PCRE añade lookaround, grupos no capturantes, perezosos, `\d/\w/\s`, al coste de permitir backtracking exponencial en patrones mal diseñados.

## Errores frecuentes

- "`grep -P` no está disponible": en macOS, el `grep` de BSD no soporta `-P`. Instala GNU grep (`brew install grep`, usar como `ggrep`) o salta la sección PCRE.
- Olvidar `-E` y escribir `(foo|bar)`: en BRE se interpretan literalmente los paréntesis, el resultado es vacío.

## Limpieza

No deja estado persistente.
