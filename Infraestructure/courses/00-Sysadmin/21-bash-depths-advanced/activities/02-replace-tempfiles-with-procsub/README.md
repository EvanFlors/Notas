# Actividad 02 — Reemplazar temporales por process substitution

**Tipo:** debug · **Duración:** 60 min

## Objetivo

Transformar un script "legacy" que usa archivos temporales en `/tmp` por una versión equivalente basada en **process substitution** (`<(cmd)`, `>(cmd)`), demostrando que:

1. El output es **idéntico** al original.
2. El script **no deja nada en `/tmp`** al terminar (ni en condiciones normales ni si lo cancelas con Ctrl-C — bonus).

## Contexto

`starter/old.sh` hace lo siguiente:

1. Produce dos listados (archivos actuales vs archivos esperados).
2. Los escribe a **dos archivos temporales** en `/tmp`.
3. Los compara con `diff`.
4. También calcula sha256 y gzip de un payload, escribiendo **tres archivos intermedios** más.
5. Al final hace `rm` manual de los temporales (y a veces se olvida alguno).

Tu misión: reescribirlo como `starter/new.sh` (o editar in-place) usando process substitution, de modo que no exista ningún `mktemp`/`rm /tmp/...` en el camino crítico.

## Instrucciones

1. Lee `starter/old.sh` entero. Entiende qué produce.
2. Corre `bash starter/old.sh` y guarda su stdout: `bash starter/old.sh > /tmp/expected_old.out` (sí, este `/tmp` es sólo para capturar la referencia; lo borras después).
3. Escribe tu versión en `starter/new.sh` (puedes partir de una copia).
4. Corre `bash tests/validate.sh`. El validador:
   - Ejecuta ambos scripts, compara outputs.
   - Hace un snapshot de `/tmp` antes y después para verificar que `new.sh` no deja ni un archivo.
   - Falla si `new.sh` todavía contiene `mktemp` o abre archivos en `/tmp`.

## Reglas

- No puedes llamar a `mktemp` ni crear nada bajo `/tmp` en `new.sh`.
- Los outputs finales (`payload.gz` y `payload.sha` en el workdir del script) siguen siendo archivos reales, eso está bien.
- `shellcheck -S warning starter/new.sh` debe pasar con 0 findings.
- Mantén el shebang canónico, `set -euo pipefail`, `IFS=$'\n\t'`.

## Criterios de aceptación

- `bash tests/validate.sh` imprime `OK` y sale 0.
- `grep -c mktemp starter/new.sh` → 0.
- `shellcheck -S warning starter/new.sh` → 0 findings (si tienes shellcheck instalado; el validador lo ejecuta si lo encuentra).

## Pista

- `diff <(cmd1) <(cmd2)` reemplaza "escribo dos tmp y los comparo".
- `tee >(sink1) >(sink2) > /dev/null` reemplaza "escribo un intermedio y lo paso a dos herramientas distintas".
- No necesitas `trap EXIT` para limpiar lo que nunca creaste.
