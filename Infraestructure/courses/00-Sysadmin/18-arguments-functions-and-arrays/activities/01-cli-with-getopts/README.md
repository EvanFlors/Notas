# Actividad 01 — CLI con `getopts`

**Tipo:** guided-lab  ·  **Duración:** 75 min  ·  **Nivel:** intermedio

## Contexto

Vas a convertir un stub en `starter/mytool.sh` en una CLI completa que respete convenciones POSIX. El tema real: aprender a decir "esta herramienta se usa así" con flags, exit codes y mensajes a stream correcto.

## Especificación

El tool debe aceptar:

```
mytool.sh [-v] [-o FILE] [-n COUNT] [-h] [--] ARG
```

- `-h` → imprime ayuda a **stdout**, exit `0`.
- `-v` → activa modo verbose (log a **stderr** con el estado parseado).
- `-o FILE` → **obligatorio**; archivo de salida.
- `-n COUNT` → entero > 0; default `1`.
- `--` → marca fin de opciones (lo que viene después es posicional).
- `ARG` → posicional obligatorio.

### Exit codes

| Código | Cuándo |
|--------|--------|
| `0` | Ejecución correcta, o `-h` pedido. |
| `1` | Error de ejecución (reservado — no lo vas a disparar en este lab). |
| `2` | Error de uso: flag desconocido, falta argumento, `-o` ausente, `COUNT` no entero positivo, ARG faltante. |

### Streams

- Ayuda → **stdout**.
- Mensajes de error y log verbose → **stderr**.
- Salida normal del "trabajo" → **stdout**.

## Pasos

1. Abre `starter/mytool.sh`. Lee los comentarios `TODO`.
2. Completa `usage()` con el formato de ayuda.
3. Implementa el bucle `getopts ":ho:vn:"` con silent mode. Maneja `\?` y `:`.
4. Después del bucle: `shift $((OPTIND - 1))`.
5. Valida que `-o` se haya pasado, que `COUNT` sea entero > 0, que haya al menos un posicional.
6. En modo verbose, loguea el estado parseado a stderr.
7. "Trabajo" simulado: imprime `COUNT` líneas con `ARG` → `FILE` a stdout.
8. Ejecuta los casos de prueba manuales (abajo).
9. Corre `bash tests/validate.sh`. Debe terminar con `OK`.

### Casos de prueba manuales

```bash
chmod +x starter/mytool.sh

./starter/mytool.sh -h                              # exit 0, ayuda a stdout
./starter/mytool.sh -o out.txt -v hola              # exit 0, 1 iteración, verbose
./starter/mytool.sh -o out.txt -n 3 hola            # exit 0, 3 iteraciones
./starter/mytool.sh -x                              # exit 2, "opción desconocida"
./starter/mytool.sh -o                              # exit 2, "requiere argumento"
./starter/mytool.sh hola                            # exit 2, "-o es obligatoria"
./starter/mytool.sh -o out.txt -n cero hola         # exit 2, "COUNT entero"
./starter/mytool.sh -o out.txt                      # exit 2, "falta ARG"
./starter/mytool.sh -o out.txt -- -arg-con-guion    # exit 0, ARG="-arg-con-guion"
```

## Pistas

- El **primer `:`** en `":ho:vn:"` activa silent mode: tú manejas `\?` y `:` en el `case`, no Bash.
- Para validar entero: `[[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 ))`.
- `cat <<EOF ... EOF` es la forma más legible para `usage()`.
- Redirige `usage` a stderr cuando lo imprimes **junto a** un error: `usage >&2`.

## Entregable

- `starter/mytool.sh` modificado, pasa `tests/validate.sh`.
- Opcional: compara tu versión con `solution/mytool.sh` después (no antes).

## Validación

```bash
bash tests/validate.sh
```

Debe imprimir `OK` y salir con `0`.
