# Actividad 02 — Refactorizar un monolito

**Tipo:** independent  ·  **Duración:** 75 min  ·  **Nivel:** intermedio

## Contexto

`starter/monolith.sh` es un script de ~150 líneas que publica un "release" simulado hacia uno de tres entornos (`dev`, `stage`, `prod`). Funciona, pero:

- Toda la lógica está en flujo lineal, sin funciones.
- La configuración por entorno está codificada con `if/elif/else`.
- Variables globales se reutilizan y mutan en todo el script.
- Añadir un nuevo entorno obliga a tocar 4 lugares distintos.
- Un bug en el bloque de `prod` romperá los otros entornos porque comparten estado.

Tu trabajo: **refactorizar sin cambiar la salida observable**. Las pruebas automatizadas verifican que el script refactorizado produce exactamente lo mismo que el monolito para los mismos inputs.

## Requisitos de la refactorización

El resultado (`starter/monolith.sh` modificado, o un `refactored.sh` que lo sustituya) debe cumplir:

1. **Un array asociativo** `CONFIG` que contenga la configuración por entorno, con claves tipo `dev.host`, `dev.port`, `prod.host`, etc. Los bloques `if/elif` sobre `$env` desaparecen y se convierten en lookups `${CONFIG[$env.host]}`.
2. **Al menos 5 funciones nombradas** con una sola responsabilidad cada una. Sugerencias:
   - `usage` / `die` (utilidades)
   - `parse_args` (parsing CLI)
   - `load_config` (poblado del array asociativo)
   - `validate_env` (comprueba que el entorno pedido existe)
   - `build_artifact` (empaquetado simulado)
   - `publish` (subida simulada)
   - `main` (orquestador)
3. **Variables locales** (`local`) en toda función que las use. Las únicas variables globales permitidas son: `CONFIG` (array asociativo), `PROG`, `VERSION`.
4. **Un `main "$@"`** como última línea del script. Todo lo demás son definiciones.
5. **Misma CLI y mismos exit codes** que el monolito:
   - `-h` → ayuda, exit 0.
   - `-e ENV` → entorno (`dev`, `stage`, `prod`); default `dev`.
   - `-a ARTIFACT` → artefacto (obligatorio).
   - `-d` → dry-run (imprime "DRY RUN" en vez de "PUBLICANDO").
   - Flag desconocido / arg faltante → exit 2.
   - Entorno inválido → exit 2.
6. **Soporta un entorno adicional** `qa` añadido en el array asociativo sin tocar el flujo de código. El test lo verifica.

## Cómo entregarlo

Edita `starter/monolith.sh` en el sitio, o crea `starter/refactored.sh` (el test busca el primero que exista, en ese orden). Tu versión debe:

- Pasar `bash tests/validate.sh`.
- Pasar `shellcheck -S warning starter/monolith.sh` sin findings (si tienes shellcheck instalado).
- Comentar brevemente, al tope del script, qué cambió respecto al monolito.

## Validación

```bash
bash tests/validate.sh
```

Imprime `OK` y sale `0` cuando todo pasa.

Los tests comparan la salida del refactor con la del monolito original para:

- `-e dev -a app-1.0`
- `-e stage -a app-1.0`
- `-e prod -a app-1.0 -d` (dry-run)
- `-e qa -a app-1.0` (requiere que añadas `qa` al `CONFIG`)
- `-h` (ayuda a stdout, exit 0)
- `-e marte -a x` (entorno inválido, exit 2)

Y verifican estructuralmente que:

- `declare -A CONFIG` aparece en el script.
- Hay ≥ 5 definiciones de funciones (`^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)`).
- Aparece `main "$@"` como línea final no vacía.
- Hay al menos 5 usos de `local`.

## Pistas

- Lee `theory/lesson.md` §8 (asociativos) y §10 (esqueleto completo).
- Empieza por `main` arriba (vacío), luego ve bajando a implementar cada función.
- `CONFIG` lo pueblas en `load_config`, no en el top-level, para dejarlo testeable.
- Para `qa`, basta con añadir:
  ```bash
  CONFIG[qa.host]="qa.example.com"
  CONFIG[qa.port]="8443"
  CONFIG[qa.user]="deploy"
  ```
- Si usas `set -euo pipefail` y lees `${CONFIG[$env.host]:-}`, puedes detectar entornos inexistentes limpiamente.
