# Ejemplo 01 — Caché de pip (dos variantes)

## Concepto que demuestra

Dos formas correctas de cachear dependencias de pip en GitHub Actions, y la diferencia operativa entre ellas:

1. **Caché integrada** vía `actions/setup-python@v5` con `cache: 'pip'`.
2. **Caché manual** vía `actions/cache@v4`.

Ambas usan `hashFiles` del lockfile como clave y `restore-keys` para fallback.

## Contexto

Ejecutar `pip install -r requirements.txt` baja wheels de PyPI (10–200 MB). En un pipeline que corre decenas de veces al día, cachear `~/.cache/pip` recorta minutos de red por run.

## Objetivo

Que leas los dos workflows y entiendas:

- Qué `path` se cachea en cada caso (y por qué).
- Qué clave calcula cada variante.
- Cuándo elegir una vs la otra.

## Prerrequisitos

- Haber leído `theory/lesson.md` secciones 2, 4 y 5.
- `python3` instalado localmente (para validar sintaxis YAML).

## Ejecución

Los dos workflows están en `files/`. **No** necesitas una cuenta de GitHub para este ejemplo; vamos a inspeccionarlos localmente.

```bash
mkdir -p /tmp/pip-cache-example
cp -r "$(pwd)/files/." /tmp/pip-cache-example/
cd /tmp/pip-cache-example
ls -la
```

### Variante A — `setup-python` con `cache: 'pip'`

Archivo: `.github/workflows/ci-setup-cache.yml`.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
          cache-dependency-path: 'requirements*.txt'
      - run: pip install -r requirements.txt
      - run: python -m pytest -q || true
```

Qué pasa internamente:

- `setup-python` instala Python 3.12.
- Luego, por `cache: 'pip'`, invoca `actions/cache` con:
  - `path: ~/.cache/pip`
  - `key: setup-python-${{ runner.os }}-...-python-3.12-pip-${{ hashFiles(cache-dependency-path) }}`
  - `restore-keys`: prefijos equivalentes sin el hash.

Ventaja: **cero decisiones**. Correcto por default.

### Variante B — `actions/cache@v4` a mano

Archivo: `.github/workflows/ci-manual-cache.yml`.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Cache pip wheels
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-py3.12-pip-${{ hashFiles('**/requirements*.txt') }}
          restore-keys: |
            ${{ runner.os }}-py3.12-pip-
      - run: pip install -r requirements.txt
      - run: python -m pytest -q || true
```

Idéntico resultado pero **tú** controlas la clave. Útil cuando además quieres cachear otros paths (por ejemplo `.venv/` entero, o un cache de `mypy`).

### Validar sintaxis localmente

```bash
python3 - <<'PY'
import yaml, sys
for f in [
    ".github/workflows/ci-setup-cache.yml",
    ".github/workflows/ci-manual-cache.yml",
]:
    with open(f) as fp:
        y = yaml.safe_load(fp)
    assert "jobs" in y, f
    print(f, "OK")
PY
```

## Resultado esperado

- Ambos workflows son YAML válidos.
- En la primera run hipotética: `Cache not found`, se instala, al final se sube el cache.
- En la segunda run (sin cambios al lockfile): `Cache restored from key: ...` y `pip install` es casi instantáneo porque todas las wheels están ya en `~/.cache/pip`.
- Si cambias `requirements.txt` y añades un paquete: la `key` cambia (porque cambió el hash), hay **miss**, pero `restore-keys` da un **hit parcial** y solo descarga lo nuevo.

## Interpretación

- La **variante A** gana en legibilidad y es el default razonable.
- La **variante B** gana cuando necesitas:
  - Combinar varios paths (`~/.cache/pip`, `~/.local/share/pypoetry`, `.venv/`).
  - Participar la clave en algo que `setup-python` no conoce (p. ej. una variable de entorno que cambia build flags).
- La clave en ambos casos cumple la receta: `{os}-{tool}-{version}-{hashFiles(lockfile)}`. Si te sales de esa receta, verifica dos veces por qué.

## Errores frecuentes

- **Olvidar `cache-dependency-path`** en la variante A — `setup-python` adivina (busca `requirements.txt` en root) y puede no encontrar nada en monorepos. Siempre explícito.
- **Olvidar `restore-keys`** en la variante B — primera run en cada branch nueva no cachea.
- **Clave manual sin `runner.os`** cuando el workflow es matricial multi-OS — corrupción cross-plataforma.

## Relación con escenarios reales

- Toda base monorepo Python con CI corre esto para no pagar 2 minutos de pip install × N jobs.
- La variante B es la que acabas usando en cuanto incorporas Poetry/UV/Hatch con sus propios caches.
- Cachear el `venv` completo (no cubierto aquí) es el siguiente paso cuando quieres ahorrar incluso el "pip resuelve e instala desde wheels locales" (~5–10 s).

## Limpieza

```bash
rm -rf /tmp/pip-cache-example
```
