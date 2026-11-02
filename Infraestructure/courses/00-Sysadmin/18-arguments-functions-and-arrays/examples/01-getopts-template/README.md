# Ejemplo 01 — Plantilla canónica de `getopts`

## Qué muestra

Una CLI mínima con `getopts` en silent mode, que implementa:

- `-h` → muestra ayuda y sale `0`.
- `-v` → flag booleano sin argumento.
- `-o FILE` → opción con argumento obligatorio.
- `-n COUNT` → opción con argumento obligatorio.
- Flag desconocido → error a `stderr` + `usage` + exit `2`.
- Argumento faltante → error a `stderr` + `usage` + exit `2`.
- Soporte de `--` como fin-de-opciones.

## Cómo ejecutar

```bash
cd files
chmod +x template.sh

./template.sh -h
./template.sh -v -o out.txt -n 3 ARG1
./template.sh -o out.txt ARG1          # count por defecto = 1
./template.sh -x                        # flag desconocido → exit 2
./template.sh -o                        # falta argumento → exit 2
./template.sh -- -arg-con-guion        # posicional empezando por -
echo $?
```

## Qué observar

- La **primera `:`** en `":ho:vn:"` activa el silent mode. Cambia por `"ho:vn:"` y vuelve a correr: Bash imprime sus propios mensajes y nunca cae en el caso `:` del `case`.
- `OPTIND` después del bucle vale "número de opciones consumidas + 1". `shift $((OPTIND - 1))` deja los posicionales listos.
- `verbose`, `output`, `count` tienen **valores por defecto** antes del bucle; cuando una opción no se pasa, mantiene su default.
- Validación mínima post-parse: `output` requerido, `count` entero positivo.

## Lectura

- `theory/lesson.md` §3 (getopts).
