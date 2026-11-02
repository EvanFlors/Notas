# Ejemplo 02 — Lectura null-terminated

Demuestra el patrón canónico para leer salida de `find -print0` en un **array** de Bash, usando `mapfile -d ''`.

## Objetivo didáctico

Entender que `-d ''` significa "el separador es el byte NUL", y que esta combinación (`find -print0` + `mapfile -d ''` o `read -d ''`) es la única segura para nombres de archivo arbitrarios.

## Ejecución

```bash
cd files/
bash demo.sh
```

El script:

1. Crea `./tmp-nullterm/` con archivos cuyos nombres incluyen espacios, newlines y `*`.
2. Los lee con `find … -print0 | mapfile -d ''`.
3. Itera el array e imprime cada nombre delimitado por `[...]`.
4. Verifica que el conteo coincide con el número real de archivos.
5. Limpia.

## Qué observar

- El conteo del array coincide exactamente con los archivos creados.
- Cada nombre aparece una sola vez, con sus espacios/newlines/asteriscos intactos.
- No se expande ningún glob.

## Requisito

- Bash 4.4+ (para `mapfile -d`). En macOS: `brew install bash`.
- Si no tienes `mapfile`, el patrón equivalente es `while IFS= read -r -d '' f; do …; done < <(find … -print0)`.
