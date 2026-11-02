# Ejemplo 02 — Funciones y arrays

## Qué muestra

Un script autocontenido que demuestra, con prints etiquetados:

1. **Scope global por defecto** vs. `local` dentro de una función.
2. **Captura de salida** con `$(func)` como mecanismo real de "return".
3. **`return` solo acepta 0–255** (overflow visible).
4. **Arrays indexados**: creación, longitud, iteración por valor y por índice, slicing, append.
5. **Arrays asociativos**: `declare -A`, iteración de claves, `${!map[@]}`.
6. **Paso de array a función por nameref** (`declare -n`) — modificando la original.

## Cómo ejecutar

```bash
cd files
chmod +x demo.sh
./demo.sh
```

## Qué observar

- La sección `scope` muestra cómo `local` evita que una iteración `for i in ...` dentro de una función pise la `i` global del script.
- La sección `return` imprime `44` cuando intentas devolver `300` — el valor se trunca módulo 256.
- La sección `nameref` arranca con un array `[alpha beta]` y lo deja como `[alpha beta gamma]` después de llamar a `push_unique` dos veces (`gamma` nuevo, `beta` duplicado ignorado).
- El orden de iteración del array asociativo **puede diferir** entre invocaciones y entre versiones de Bash — es un hash table, no una lista ordenada.

## Lectura

- `theory/lesson.md` §6 (funciones), §7 (indexados), §8 (asociativos), §9 (nameref).
