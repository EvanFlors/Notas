# Ejemplo 02 — Artefacto entre jobs (`upload`/`download-artifact@v4`)

## Concepto que demuestra

Un pipeline `build → test → deploy` donde `build` produce un `dist/` y los otros dos jobs **lo consumen** vía `actions/upload-artifact@v4` + `actions/download-artifact@v4`.

Objetivo didáctico adicional: dejar claro **qué cambió en v4** respecto a v3 y por qué mezclar versiones falla.

## Contexto

Si cada job rebuildea el proyecto, pagas CPU N veces y, peor, **podrías deployar algo distinto de lo testeado** (otra toolchain, otra timestamp, otro flag). El patrón correcto es: `build` **una vez**, los demás **descargan** el mismo bundle.

## Objetivo

Leer el workflow y entender:

- Cómo se nombra y se sube un artifact.
- Cómo se declara `needs:` para que `download-artifact` lo encuentre.
- Qué significa `retention-days` y `if-no-files-found: error`.
- Por qué v4 **requiere** que el `name` sea único por run.

## Prerrequisitos

- Haber leído `theory/lesson.md` secciones 2.4, 4.5 y 5.3.
- `python3` para validar sintaxis YAML.

## Ejecución

```bash
mkdir -p /tmp/artifact-between-jobs
cp -r "$(pwd)/files/." /tmp/artifact-between-jobs/
cd /tmp/artifact-between-jobs
cat .github/workflows/pipeline.yml
```

El workflow completo (resumido):

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          mkdir -p dist
          echo "version=$(git rev-parse --short HEAD)" > dist/VERSION
          echo "built at $(date -u +%FT%TZ)" > dist/app.txt
      - uses: actions/upload-artifact@v4
        with:
          name: app-dist
          path: dist/
          retention-days: 7
          if-no-files-found: error

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with: { name: app-dist, path: dist/ }
      - run: test -s dist/app.txt && test -s dist/VERSION

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with: { name: app-dist, path: dist/ }
      - run: echo "Deploying $(cat dist/VERSION)"
```

### Validar sintaxis localmente

```bash
python3 - <<'PY'
import yaml
y = yaml.safe_load(open(".github/workflows/pipeline.yml"))
jobs = y["jobs"]
assert set(jobs) == {"build", "test", "deploy"}
assert jobs["test"]["needs"] == "build"
assert jobs["deploy"]["needs"] == "test"
print("OK — 3 jobs, needs chain correcto")
PY
```

## Resultado esperado

- Workflow con 3 jobs encadenados por `needs:`.
- Un único artifact `app-dist`, subido una vez y descargado dos veces (una por job consumidor).
- `test` falla ruidosamente si el artifact no existe (`download-artifact@v4` *errora* por default si no encuentra `name:` exacto).
- `deploy` deploya **el mismo bundle** que `test` validó — garantía de reproducibilidad.

## Interpretación

- **Un nombre, dos descargas**: en v4 un artifact es un recurso del run; cualquier job con `needs:` sobre `build` puede descargarlo. No hay límite de descargas.
- **`if-no-files-found: error`**: convierte un build vacío en un fallo visible. Default es `warn`, que esconde bugs ("deployaste nada y nadie se enteró").
- **`retention-days: 7`**: para builds de PR; para `main` subirías a 14–30 o promocionarías a Release.

### Qué pasaría si mezcláramos v3 y v4

Si `build` usara `actions/upload-artifact@v4` y `test` usara `actions/download-artifact@v3`, el `download` **no** vería el artifact (están en backends distintos) y fallaría con *"artifact not found"*. Es el error #1 al migrar workflows antiguos. Siempre **misma major** en upload y download.

### Qué pasaría con nombres duplicados

Si en matriz hicieras `upload-artifact@v4` con `name: dist` desde dos variantes (p. ej. `os=ubuntu` y `os=macos`) **sin diferenciar el nombre**, el segundo `upload` **falla** con *"an artifact with this name already exists"*. En v4 se resuelve con:

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: dist-${{ matrix.os }}
    path: dist/

# y en el consumidor:
- uses: actions/download-artifact@v4
  with:
    pattern: dist-*
    merge-multiple: true
    path: ./dist
```

## Errores frecuentes

- **Falta `needs:`** → el job consumidor corre en paralelo al `build` y no encuentra el artifact.
- **`name` mal escrito** (case-sensitive).
- **Mezcla v3/v4** entre upload y download.
- **`path` del upload incluye `.git/`** → artifact de 300 MB en vez de 300 KB.

## Relación con escenarios reales

- Es exactamente el patrón de un pipeline moderno: `build` genera `dist/` (wheel, binario, SPA bundle), `test` corre contra ese bundle, `deploy` sube ese mismo bundle a S3 / GHCR / Vercel.
- La misma receta se extiende a `coverage/`, `sbom.spdx.json`, `attestations.jsonl`.

## Limpieza

```bash
rm -rf /tmp/artifact-between-jobs
```
