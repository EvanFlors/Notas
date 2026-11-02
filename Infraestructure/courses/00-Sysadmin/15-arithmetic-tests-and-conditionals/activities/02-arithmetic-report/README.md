# Actividad 02 — Reporte aritmético desde CSV

## Objetivo

Escribir un script Bash que lea un CSV con mediciones numéricas y produzca:

- `sum`, `avg`, `min`, `max` sobre la columna numérica.
- Una clasificación de cada fila con `case`.

Combinas aritmética (`(( ))`, `bc` para `avg`), tests (`[[ ]]`) y `case` con alternación `|`.

## Entrada

`starter/data.csv` con cabecera y filas `host,load`:

```
host,load
web-01,12
web-02,35
db-01,78
db-02,91
cache-01,8
cache-02,55
batch-01,99
```

- `host`: nombre.
- `load`: entero entre 0 y 100.

## Qué debe hacer tu script

1. Aceptar la ruta del CSV como `$1`; por defecto `starter/data.csv` relativo al propio script.
2. Validar que el archivo existe y es legible (`-r`).
3. Saltar la cabecera.
4. Para cada fila:
   - Validar que `load` es un entero entre 0 y 100 (regex `^[0-9]+$` y rango con `(( ))`).
   - Clasificarlo con `case`:
     - `0..19` → `idle`
     - `20..59` → `normal`
     - `60..84` → `busy`
     - `85..100` → `critical`
   - Imprimir `host  load  clasificacion` alineado.
5. Al final, imprimir una línea con `sum`, `avg` (2 decimales, `bc -l`), `min`, `max`.

## Formato de salida esperado

```
host        load  class
web-01       12   idle
web-02       35   normal
db-01        78   busy
db-02        91   critical
cache-01      8   idle
cache-02     55   normal
batch-01     99   critical

sum=378  avg=54.00  min=8  max=99
```

(El alineamiento exacto puede variar; los **números y clasificaciones** deben coincidir.)

## Entrega

Tu script en la raíz de la actividad como `report.sh`. Ejecutable, con `#!/usr/bin/env bash` y `set -euo pipefail`.

## Validación

```bash
bash tests/validate.sh ./report.sh
```

El validador ejecuta tu script contra `starter/data.csv` y verifica:

- Hay 7 filas clasificadas.
- `sum=378`, `min=8`, `max=99`, `avg=54.00` aparecen literalmente.
- Cada clasificación esperada por host está presente.
- `shellcheck` limpio (si está instalado).

## Tiempo estimado

60 minutos.
