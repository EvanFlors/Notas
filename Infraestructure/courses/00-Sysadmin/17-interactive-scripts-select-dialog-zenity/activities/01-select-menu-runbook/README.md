# Actividad 01 — Runbook con `select`

**Tipo:** guided-lab · **Duración:** 60 min · **Prereq:** haber leído `theory/lesson.md` secciones 2 y 3.

## Objetivo

Completar un runbook interactivo que, usando el builtin `select` y **sin dependencias externas**, ofrezca 4 operaciones sobre un servicio ficticio `demo-app`:

1. **Mostrar estado** — imprime estado simulado.
2. **Tail de logs** — muestra las últimas N líneas simuladas.
3. **Reiniciar servicio** — pide confirmación `y/N` (default **no**) y simula reinicio.
4. **Salir** — rompe el loop y termina con exit code 0.

## Pre-condiciones

- Bash 4+ (`bash --version`).
- Un TTY (ejecutar desde terminal interactivo).

## Pasos

1. Abre `starter/runbook.sh` y lee los `TODO`s.
2. Implementa las 4 funciones (`do_status`, `do_logs`, `do_restart`, `do_exit`) y el bloque `select` que las despacha según `$REPLY`.
3. En `do_restart`, pide confirmación con `read -r -n 1 -p "¿Confirmas reinicio (y/N)? "` y aborta la acción si el usuario no teclea `y`/`Y`.
4. Tras cualquier acción (excepto Salir), el menú debe **re-dibujarse** automáticamente (es el comportamiento por defecto de `select`; no imprimas el menú tú).
5. En la opción Salir, usa `break` (no `exit`): el script debe terminar limpiamente tras el loop.
6. Valida con los tests:

   ```bash
   bash tests/validate.sh starter/runbook.sh    # debe FALLAR al principio
   bash tests/validate.sh solution/runbook.sh   # debe PASAR
   ```

## Pistas

- `$REPLY` tiene el número tecleado; `$opt` el string correspondiente al índice elegido.
- Si el usuario pulsa Enter en vacío, `select` repinta el menú — no entres en el `case` con `""`.
- Para la confirmación, acepta solo `y` o `Y`; cualquier otra cosa (incluido Enter vacío) significa "no".

## Validación

El test ejecuta el script con stdin predefinido y comprueba:

- Que la opción 1 produce una línea que contiene `status`.
- Que la opción 2 produce al menos 3 líneas (los logs simulados).
- Que la opción 3 con respuesta `n` **no** imprime "OK" de reinicio.
- Que la opción 3 con respuesta `y` sí imprime "OK".
- Que la opción 4 termina el script con exit code 0.

## Entregable

`starter/runbook.sh` modificado hasta pasar `bash tests/validate.sh starter/runbook.sh`.
