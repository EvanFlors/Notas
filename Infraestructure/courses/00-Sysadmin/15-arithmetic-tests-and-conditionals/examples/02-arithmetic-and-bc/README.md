# Ejemplo 02 — Aritmética entera y `bc` para floats

## Concepto que demuestra

Qué puede hacer Bash **sin** `bc` (enteros, bases, bits) y qué necesita delegar en `bc -l` (decimales, precisión arbitraria, funciones trigonométricas y logarítmicas).

## Contexto

Un script típico de sysadmin computa porcentajes de uso, promedios de métricas y conversiones de unidades. Entenderlo requiere separar lo que Bash hace nativo de lo que requiere herramienta externa.

## Objetivo

Al terminar podrás responder:

- ¿Por qué `$((10/3))` imprime `3` y no `3.33`?
- ¿Cómo obtengo `3.33` con 2 decimales desde Bash?
- ¿Qué notación le indico a `(( ))` para interpretar un valor en octal o hexadecimal?

## Prerrequisitos

- Bash 5+.
- `bc` instalado (`which bc`).

## Ejecución

```bash
cd 15-arithmetic-tests-and-conditionals/examples/02-arithmetic-and-bc
bash files/demo.sh
```

## Resultado esperado

- Bloque **entera**: suma, resta, producto, cociente, resto, potencia, incremento.
- Bloque **bases**: octal `0755` y hex `0xff` en decimal.
- Bloque **bits**: `|`, `&`, `^`, `<<`.
- Bloque **floats con bc**: división con 2 y 6 decimales, comparación de floats a través de `(( $(…) ))`.

## Interpretación

- `$(( ))` sólo trabaja en enteros; cualquier división redondea hacia 0.
- `bc` lee stdin y produce stdout; integrarlo con Bash es un `echo | bc -l`.
- `scale=N` ante `bc` controla los decimales mostrados.
- `(( $(echo "a>b" | bc -l) ))` es el patrón para encadenar comparaciones de float en un `if`.

## Errores frecuentes

- Esperar `0.5` de `$((1/2))`.
- Olvidar `-l` en `bc` y perder precisión por defecto.
- Pasar `3.14` a `[[ -gt ]]`: error de "integer expression".
