# Ejemplo 01 — Matriz de operadores de test

## Concepto que demuestra

Qué devuelve **realmente** cada operador de `[[ ]]` (archivo, string, numérico) sobre entradas controladas. En vez de memorizar la tabla, lees el resultado.

## Contexto

Es fácil confundir `-f` con `-e`, `-eq` con `=`, o `-z` con `-n`. Este script fija valores conocidos y evalúa todos los operadores relevantes, imprimiendo `V` / `F` junto a la expresión.

## Objetivo

Al terminar podrás responder:

- ¿Qué distingue `-e`, `-f` y `-d` sobre el mismo path?
- ¿Qué pasa si comparas `"007"` con `7` usando `=` vs `-eq`?
- ¿Por qué `-z ""` es verdadero y `-n ""` es falso?

## Prerrequisitos

- Bash 5+ (`bash --version`).
- `shellcheck` para validar estilo.
- Permiso de escritura en `/tmp`.

## Ejecución

```bash
cd 15-arithmetic-tests-and-conditionals/examples/01-test-operator-matrix
bash files/demo.sh
```

El script crea artefactos temporales en `/tmp/sys15-matrix-$$/`, imprime resultados y limpia al salir.

## Resultado esperado

- Bloque **archivo**: `-e`, `-f`, `-d`, `-r`, `-w`, `-x`, `-s`, `-h` sobre regular, directorio, symlink y archivo vacío.
- Bloque **string**: `-z`, `-n`, `=`, `!=`, `==` con glob y `=~` con regex.
- Bloque **numérico**: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`, además de la contraparte `(( ))`.

## Interpretación

- `-f` requiere **archivo regular** (no dir, no symlink no-resuelto); `-e` sólo requiere que exista algo.
- `=` compara **strings**: `"007" = "7"` es falso. `-eq` compara **enteros**: `"007" -eq 7` es verdadero.
- `[[ "$f" == *.log ]]` evalúa el RHS como **glob**; `[[ "$f" =~ \.log$ ]]` como **regex ERE**.

## Errores frecuentes

- Esperar que `-f` sea cierto para un symlink roto: `-f` lo niega; `-h` lo detecta.
- Entrecomillar la regex del `=~`: pasa a ser literal.
- Usar `-eq` con strings no numéricos: Bash aborta con `integer expression expected`.

## Limpieza

El script elimina su propio directorio temporal mediante `trap`.
