# Actividad 01 — El oráculo de la expansión

**Tipo:** independent · **Duración:** 60 min

## Objetivo

**Predecir** el output exacto de 15 snippets de Bash **sin ejecutarlos**, usando sólo el modelo mental del orden de expansión y la tabla de parameter expansion. Luego `tests/validate.sh` ejecuta cada snippet y compara con tus respuestas.

## Dinámica

1. Abre `starter/questions.md`. Verás 15 snippets numerados.
2. **Antes de ejecutar nada**, escribe tu predicción al lado de cada uno (output exacto, línea por línea, o `ERROR` si crees que falla).
3. Guarda tus respuestas copiando `starter/questions.md` a `answers.md` **al lado** y edítalas allí (manteniendo el formato `=== N ===` + bloque de respuesta).
4. Corre `bash tests/validate.sh answers.md`. Te marcará aciertos y fallos sin revelar la respuesta correcta.
5. Vuelve, corrige y repite. Solo cuando pases los 15 mira `solution/answers.md`.

## Reglas

- No ejecutes los snippets manualmente antes de predecir. El punto es entrenar el modelo mental.
- Si usas `shellcheck` o cualquier herramienta externa, está bien: eso **no** da la respuesta, sólo marca errores sintácticos.
- `ERROR` cuenta como respuesta válida si el snippet realmente falla; mejor aún, indica el tipo de error esperado como comentario.

## Criterios de aceptación

- `bash tests/validate.sh answers.md` imprime `OK (15/15)` y exit 0.
- No modificaste `starter/questions.md`.

## Pista general

Para cada snippet pregúntate, en este orden:

1. ¿Hay brace expansion? ¿Qué produce?
2. ¿Hay tilde?
3. ¿Hay `$var`, `$(…)`, `$((…))`? ¿Qué devuelven?
4. ¿Los resultados están entre comillas? Si no, ¿qué hace word splitting?
5. ¿Hay globs? ¿Qué matchean en el `workdir`?
6. ¿Qué `argv` recibe finalmente el comando?
