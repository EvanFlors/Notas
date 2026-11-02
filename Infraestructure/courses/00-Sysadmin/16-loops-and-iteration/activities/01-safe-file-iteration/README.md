# Actividad 01 — Iteración segura sobre archivos

- **ID:** `sys-16-01-safe-file-iteration`
- **Tipo:** guided-lab
- **Duración:** 60 min
- **Nivel:** intermedio

## Contexto

Un operador externo te manda un directorio con "unos cuantos archivos de log". Al abrirlo descubres que los nombres son hostiles: espacios, newlines, asteriscos, caracteres unicode. Tu script debe:

1. Contar los archivos.
2. Para cada archivo, calcular su tamaño en bytes y escribir una línea `TAM<TAB>RUTA` en un archivo de reporte.
3. **No perder ningún archivo**, incluso si su nombre contiene espacios, newlines o `*`.
4. **No ejecutar código** si un nombre contiene algo como `evil$(touch /tmp/pwn).log`.
5. Ser **idempotente**: ejecutarlo dos veces produce el mismo reporte.

## Setup

```bash
bash starter/make-tricky-files.sh /tmp/sys16-tricky
ls -1b /tmp/sys16-tricky   # inspecciona los nombres
```

Esto crea un directorio con ~10 archivos de nombres deliberadamente hostiles.

## Tu tarea

Crea `process.sh` que:

- Reciba como primer argumento el directorio a procesar.
- Reciba como segundo argumento la ruta del reporte (ejemplo: `/tmp/sys16-tricky/report.tsv`).
- Itere sobre todos los archivos regulares del directorio (no recursivo basta).
- Escriba al reporte una línea `<tamaño en bytes><TAB><ruta absoluta>` por archivo.
- Imprima a stdout `OK: procesados N archivos` al terminar.
- Use `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`.
- Pase `shellcheck` sin warnings.

Puedes basar tu diseño en el patrón `find -print0` + `while read -d ''` o `mapfile -d ''`.

## Validación

```bash
# Primera ejecución
bash process.sh /tmp/sys16-tricky /tmp/sys16-tricky/report.tsv

# Segunda ejecución (debe reproducir el mismo reporte)
bash process.sh /tmp/sys16-tricky /tmp/sys16-tricky/report.tsv

# Validador automático
bash tests/validate.sh /tmp/sys16-tricky
```

El validador verifica:

- El reporte existe y tiene **tantas líneas como archivos regulares** haya en el directorio (excluyendo el propio `report.tsv`).
- La segunda ejecución produce el **mismo** reporte (idempotencia).
- Ningún archivo con nombre hostil fue "perdido" (comparación con `find -type f -print0 | wc`).
- Ningún archivo lateral `/tmp/pwn*` fue creado (prueba de que no hubo ejecución de código).

## Criterios de evaluación

- Pasa `tests/validate.sh` sin errores.
- `shellcheck process.sh` sin warnings.
- El script maneja correctamente ≥ 1 archivo con espacio, ≥ 1 con newline, ≥ 1 con `*`, ≥ 1 con pretensión de inyección.

## Solución de referencia

En `solution/process.sh`. Léela sólo después de intentarlo.
