# Ejemplo 02 — `awk`: columnas, group-by y suma sobre un CSV

## Concepto que demuestra

Cómo `awk` convierte dos ideas simples (campos `$1..$NF` y arreglos asociativos) en una herramienta de agregación. Lo mismo que harías en SQL con `SELECT col, SUM(x) GROUP BY col`.

## Contexto

Un pequeño CSV de ventas por región y producto (`files/sales.csv`). Queremos:

1. Total facturado por región.
2. Top producto por unidades vendidas.
3. Ticket medio por región.

Todo esto **sin cargar nada en memoria más que lo necesario**, en una pasada.

## Objetivo

Al terminar podrás:

- Fijar separador con `-F`.
- Acumular con `sum[clave] += valor`.
- Imprimir desde `END { for (k in sum) ... }`.
- Formatear salida tabular con `printf`.

## Prerrequisitos

- Bash y `awk` (cualquier variante: GNU `gawk`, BSD `awk`, `mawk`).

## Ejecución

```bash
cd examples/02-awk-columns
bash files/demo.sh
```

## Resultado esperado

Tres bloques impresos:

- Total por región (importes ordenados descendentes).
- Producto más vendido por unidades (ordenado desc).
- Ticket medio por región (importe / número de líneas).

## Interpretación

- `awk -F,` corta por coma. Es "CSV ingenuo"; funciona porque este CSV no tiene comas dentro de campos. Si las tuviera, usa un parser real (ver `theory/lesson.md` §7.4).
- El patrón `NR>1` salta la cabecera.
- `END` se ejecuta una sola vez, tras procesar todas las líneas: ideal para "imprimir el resumen".

## Errores frecuentes

- Olvidar `NR>1` y mezclar la cabecera en los acumuladores.
- Confundir `NF` (número de campos) con `$NF` (último campo).
- `awk` interpreta números con **punto decimal** siempre; si tu dataset usa coma, convierte antes con `tr ',' '.'` **solo en la columna numérica**, no globalmente.

## Limpieza

No deja estado.
