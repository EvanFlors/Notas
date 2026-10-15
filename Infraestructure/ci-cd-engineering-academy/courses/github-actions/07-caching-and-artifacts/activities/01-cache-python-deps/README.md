# Actividad 01 — Añadir caché de dependencias Python a un workflow sin caché

## 1. Identificación

- **ID:** `gha-07-01-cache-python-deps`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-07-caching-and-artifacts`
- **Dificultad:** intermediate
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregan un repo con un workflow de CI mínimo que **instala dependencias Python en cada run sin cachear nada**. En el pipeline real estarías pagando ~90 s de red por job. Tu tarea es añadirle una estrategia de caché correcta.

Hay dos caminos válidos; cualquiera de los dos aprueba la actividad:

- **A — Caché integrada**: usar `actions/setup-python@v5` con `cache: 'pip'` y `cache-dependency-path`.
- **B — Caché manual**: usar `actions/cache@v4` con `path: ~/.cache/pip`, una `key` basada en `hashFiles` del lockfile, y `restore-keys`.

El objetivo es **que entiendas los dos**, elijas uno con criterio, y lo escribas correctamente.

## 3. Objetivos

Al terminar:
- Añades una capa de caché que haría hit en la segunda run (sin cambios al lockfile).
- Tu clave incluye `hashFiles(...)` sobre un archivo que **sí existe** (no un path fantasma).
- Tienes `restore-keys` como fallback por prefijo (si eliges la variante B).
- Validas con el test automatizado.

## 4. Prerrequisitos

- `python3` con PyYAML (`pip install pyyaml`).
- Haber leído `theory/lesson.md` secciones 2, 4 y 5.
- Haber reproducido `examples/01-pip-cache/`.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/cache-python-deps
cd /tmp/cache-python-deps
ls -la
cat .github/workflows/ci.yml
```

Verás un workflow que **no cachea nada**. Hay un `requirements.txt` en la raíz.

### 5.2 Objetivo

Edita `/tmp/cache-python-deps/.github/workflows/ci.yml` para añadir caché de pip. Elige **A** o **B**:

#### Variante A — integrada

Modifica el step de `actions/setup-python@v5` para que incluya:

```yaml
with:
  python-version: '3.12'
  cache: 'pip'
  cache-dependency-path: 'requirements*.txt'
```

#### Variante B — manual

Añade (antes del `pip install`) un step:

```yaml
- name: Cache pip wheels
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-py3.12-pip-${{ hashFiles('**/requirements*.txt') }}
    restore-keys: |
      ${{ runner.os }}-py3.12-pip-
```

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/cache-python-deps
```

Debe terminar con `OK: actividad completada correctamente.`.

### 5.4 (Opcional) Comprobar en vivo

Si tienes GitHub, haz `git init && git add . && git commit -m 'add cache'`, pushea a un repo tuyo y corre el workflow dos veces: la segunda deberías ver `Cache restored from key: ...` en los logs.

## 6. Resultado esperado

- `/tmp/cache-python-deps/.github/workflows/ci.yml` es YAML válido.
- Hay **al menos uno** de estos dos patrones:
  - `actions/setup-python@v5` con `cache: 'pip'` y `cache-dependency-path` presente.
  - `actions/cache@v4` con `key` que contenga `hashFiles(` y bloque `restore-keys:` presente.
- La clave hashea un archivo que **existe** en el repo (`requirements.txt`).
- `pip install -r requirements.txt` sigue siendo el comando de instalación (no la has roto).

## 7. Criterios de aceptación

- [ ] Funcionalidad: `validate.sh` pasa.
- [ ] Calidad: la clave incluye `runner.os` (si usas la variante B).
- [ ] Comprensión: puedes explicar por qué `restore-keys` es importante aunque hoy no haga falta.
- [ ] Reproducibilidad: borrar `/tmp/cache-python-deps` y rehacer la actividad produce el mismo resultado.

## 8. Validación

El script `tests/validate.sh`:

1. Confirma que existe `.github/workflows/ci.yml` y es YAML válido.
2. Confirma que hay un lockfile (`requirements.txt`) para que `hashFiles` tenga sentido.
3. Busca uno de los dos patrones (A o B) con `python3 + PyYAML`.
4. Para la variante B, exige `restore-keys` y `hashFiles(` en la clave.
5. Confirma que no borraste el `pip install`.

```bash
bash tests/validate.sh /tmp/cache-python-deps
```

## 9. Preguntas de reflexión

1. ¿Qué devuelve `hashFiles('**/does-not-exist.lock')`? ¿Qué efecto tendría en tu caché?
2. ¿Por qué un workflow con solo `key: pip` (sin hash) **sí hace hit** siempre pero es un error?
3. ¿Qué pasa si una PR cambia una línea de `requirements.txt`? Trazá el flujo: miss exacto, restore-key de fallback, qué se descarga, qué se guarda al final.
4. ¿En qué caso **concreto** elegirías la variante B sobre la A?
5. Si tu matriz corre `python-version: [3.11, 3.12]`, ¿tu clave distingue las dos? ¿Qué ocurriría si no?

## 10. Extensiones (opcional)

- **E1** — Pasa el workflow a matriz `python-version: [3.11, 3.12]` y ajusta la clave para que no colisionen.
- **E2** — Añade también caché del venv completo (`.venv/`) y mide (mentalmente) el trade-off tamaño vs rapidez.
- **E3** — Introduce adrede el bug "`hashFiles` sobre path fantasma" y confirma que `validate.sh` lo detectaría si lo chequeara (hoy no — ¿cómo lo extenderías?).

## 11. Limpieza

```bash
rm -rf /tmp/cache-python-deps
```
