# Lección: Caching y artefactos en GitHub Actions

> **ID:** `gha-07-caching-and-artifacts` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `gha-06-matrix-dependencies-outputs`.

---

## 1. Introducción intuitiva

Imagina este pipeline:

```
┌──────────┐   ┌──────────┐   ┌──────────┐
│  lint    │   │  test    │   │  build   │
│ (3 min)  │   │ (5 min)  │   │ (4 min)  │
└──────────┘   └──────────┘   └──────────┘
     │              │              │
     └── pip install (90 s cada uno) ──┘
```

Los tres jobs corren en runners **efímeros**: cada uno es una VM recién creada que no sabe nada del anterior. Si en cada job hay que bajar 200 MB de wheels de PyPI, estás pagando 4 minutos y 30 segundos de red solo para instalar lo mismo tres veces. Y en un repo mediano eso se multiplica por cada push y cada PR.

La **caché** resuelve esto: la primera vez que corre, los wheels se guardan en un store de GitHub asociado al repo; las siguientes, se restauran en ~5 s. Es *reutilización oportunista*: puede hacer hit o no, y el pipeline debe ser correcto en ambos casos.

Problema distinto: ahora quieres que `build` **compile** el proyecto en un `dist/`, y que `test` y `deploy` corran sobre **ese mismo** `dist/`. Esto **no** es caché: es un **contrato** entre jobs. Si no está, el pipeline debe fallar, no "reconstruirlo oportunistamente". Para eso están los **artefactos**: `build` sube `dist/` con `upload-artifact`, los otros lo descargan con `download-artifact`.

```
┌──────────┐  upload-artifact  ╔════════════╗
│  build   │ ─────────────────>║  dist/     ║
└──────────┘                   ║ (del run)  ║
                               ╚════════════╝
                                 │        │
                 download-artifact│        │download-artifact
                                 ▼        ▼
                           ┌──────────┐ ┌──────────┐
                           │   test   │ │  deploy  │
                           └──────────┘ └──────────┘
```

El mensaje importante: **caché** y **artefacto** se parecen (ambos mueven archivos fuera del runner) pero resuelven cosas distintas. Confundirlos lleva a pipelines que "a veces funcionan".

---

## 2. Fundamentos

### 2.1 Caché

Una caché en GHA tiene tres piezas:

- **`path`** — qué directorios guardas (`~/.cache/pip`, `node_modules`, `~/.m2`, `dist/.next/cache`...).
- **`key`** — identificador único de ese contenido. Si matchea exacto, hay **hit** y el `path` se restaura. Si no, hay **miss** y el step continúa (sin fallar).
- **`restore-keys`** — lista de prefijos de fallback. Si `key` no matchea, GHA busca el prefijo más largo que sí matchee, restaura ese contenido, y al final del job sube **una entrada nueva con la `key`** (parcial hit + repopulate).

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

Lectura: "si el `requirements.txt` no cambió desde la última vez, hit exacto; si cambió, parto del cache de la última build para esta OS y solo descargo lo nuevo".

### 2.2 `hashFiles`

Función integrada que calcula un SHA-256 del contenido de los archivos matcheados por un glob (relativos a `$GITHUB_WORKSPACE`). Es la pieza que hace la clave **determinista a partir del contenido** del lockfile.

- `hashFiles('**/requirements.txt')` — hash de todos los `requirements.txt` del repo.
- `hashFiles('**/poetry.lock')` — ídem para Poetry.
- `hashFiles('**/package-lock.json', '**/yarn.lock')` — múltiples archivos ordenados.

Si el glob **no matchea nada**, devuelve el hash del vacío (`e3b0c442...`) — todos tus runs comparten esa clave y la caché queda inútil. Es un bug clásico.

### 2.3 Scope de la caché

GHA cachea *por repositorio* y *por branch*, con una regla importante:

- Un job en branch `feature/x` **puede leer** cachés de su propia branch **o** del *default branch* (típicamente `main`).
- Un job en branch `feature/x` **no puede leer** cachés de la branch `feature/y`.
- Las cachés creadas en un PR viven dentro del scope del merge ref del PR; se borran al cerrar/mergear.

Esto hace que la **primera vez** que una branch nueva ejecuta el workflow, generalmente **sí** encuentra la caché de `main` como fallback (vía `restore-keys`) y repopulate. Es la razón por la que mantener `main` "siempre con caché fresca" acelera todas las PRs.

### 2.4 Artefactos

Un artefacto es un conjunto de archivos **asociado a un workflow run**, con un **nombre** único dentro de ese run, retención configurable (1–90 días, default 90 en repos públicos / 1 en private sin plan) y un **tamaño** limitado por tu plan.

- Se **suben** con `actions/upload-artifact@v4`.
- Se **descargan** con `actions/download-artifact@v4` desde otros jobs del *mismo* run (vía `needs:`) o desde la API/CLI de GitHub (incluso en otro workflow).

A diferencia de la caché, el artefacto es un **contrato**: si no existe, el `download-artifact` **falla**. No es oportunista.

---

## 3. Contexto histórico

- **2019** — GHA lanza GA con `actions/cache@v1` y `actions/upload-artifact@v1`. Modelo clásico tipo CircleCI.
- **2020–2022** — Mejoras incrementales. `cache` v2 y v3 introducen compresión mejor, `restore` separado de `save`, y en `v4` del cache se añade comportamiento más estricto para evitar race conditions al guardar.
- **Febrero 2024** — Lanzamiento de **`upload-artifact@v4` / `download-artifact@v4`**, reescrito sobre un nuevo backend. Rompe la compatibilidad con v3 por un diseño distinto: cada artefacto se identifica de forma única por run (**no se puede** subir dos artefactos con el mismo nombre en un run), la descarga es inmediata (ya no hay propagación), y los artefactos **no** son cross-versionables (un `download-artifact@v3` **no ve** uno subido con v4).
- **Junio 2024** — GitHub anuncia **sunset de v1–v3** de `upload-artifact` / `download-artifact`. Workflows antiguos que no migren **se rompen** en runs nuevos.
- **2024–2025** — `setup-*` oficiales integran `cache:` como parámetro conveniencia que, internamente, usa `actions/cache` con heurísticas correctas por ecosistema.

Punto a interiorizar: **si leíste un tutorial de GHA de antes de 2024, probablemente usa `@v3` en artifacts; eso ya no funciona**.

---

## 4. Funcionamiento interno

### 4.1 El ciclo de la caché

```
┌──────────────────────────────────────────────────────────┐
│ Step: actions/cache@v4                                   │
│                                                          │
│  1. restore: busca por `key` exacto.                     │
│     hit?  ──> extrae a `path`, exporta cache-hit=true    │
│     miss? ──> intenta restore-keys (prefijo más largo)   │
│                                                          │
│  2. [step del usuario: pip install / npm ci / ...]       │
│                                                          │
│  3. save (post-step, al final del job):                  │
│     - si hubo hit exacto por `key`: NO sube (idempotente)│
│     - si no: sube `path` como nueva entrada con `key`    │
└──────────────────────────────────────────────────────────┘
```

El `save` ocurre como un **post-step implícito** al terminar el job con éxito. Si el job falla antes, no hay save — por eso un error de instalación **no** envenena la caché.

### 4.2 Por qué `cache-hit` existe

```yaml
- uses: actions/cache@v4
  id: pip-cache
  with: { path: ~/.cache/pip, key: ... }

- run: pip install -r requirements.txt
  if: steps.pip-cache.outputs.cache-hit != 'true'
```

Útil cuando el step que *produce* el contenido es caro **incluso si** el pip ya está cacheado. Para pip puro, suele no valer la pena (pip resuelve el satisfied set rápido). Para `node_modules` de 1 GB, sí.

### 4.3 Scoping por branch

Internamente GHA guarda cachés indexadas por `(repo_id, branch_ref, key)`. La lookup al principio del step busca:

1. `(repo, branch_actual, key)` exacto.
2. `(repo, branch_actual, restore-keys[0]*)`, `(..., [1]*)` ...
3. `(repo, default_branch, key)` y luego `restore-keys` sobre default.

Esto implica dos corolarios:

- Una caché "nueva" generada en una feature branch **no la ve** otra feature branch hermana. Solo la ven ella misma y los descendientes que mergearon su rama. Por eso una PR grande que acumula caché útil "pierde" esa caché al mergear si la rama se borra.
- Si borras `main` o cambias el default branch, las cachés viejas quedan huérfanas (eviction por LRU y por 7 días sin acceso).

### 4.4 Eviction y límite

El store de caché por repo tiene un **límite agregado** (~10 GB para repos típicos; mayor en algunos planes). Al excederse, GHA aplica **LRU**: elimina las entradas con `last_accessed_at` más antiguo. También hay un **TTL** por entrada: 7 días sin acceso = evict.

Consecuencias prácticas:

- No sirve mantener 50 cachés "por si acaso": las que no se usan se evaporan.
- Cachés enormes (varios GB) desplazan a las chiquitas. Compriman o excluyan `node_modules/*/.cache` o similares.

### 4.5 El cambio v3 → v4 de artifacts

Diseño clave de v4:

- **Un artefacto por nombre por run.** Si en el run intentas `upload-artifact` dos veces con `name: dist`, el segundo **falla**. En v3 se *mergeaban*. En v4, para subir desde dos jobs, usa nombres distintos (`dist-linux`, `dist-mac`) y los descargas por **patrón**.
- **Descarga inmediata.** En v3 había que esperar propagación. En v4 el artifact está disponible al instante.
- **Sin cross-version.** Un `upload-artifact@v4` **no es descargable** por `download-artifact@v3` y viceversa. El servicio es un backend distinto. Mezclar versiones es un error silencioso frecuente al migrar.
- **Compresión Zstd** y descarga por rangos — ~10× más rápido para archivos grandes.
- **Descarga con `pattern:` y `merge-multiple:`**:

```yaml
- uses: actions/download-artifact@v4
  with:
    pattern: dist-*
    merge-multiple: true
    path: ./all-dist
```

---

## 5. Ejemplo mínimo

### 5.1 Caché de pip con `setup-python` (recomendado)

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
      - run: pytest
```

Internamente `setup-python` ya hace `actions/cache` con una `key` que incluye la versión de Python, el OS, y el hash de los archivos matcheados por `cache-dependency-path`.

### 5.2 Caché manual (`actions/cache@v4`)

Útil si quieres control total (p. ej. cachear además `~/.local/share/pypoetry`):

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - name: Cache pip wheels
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-py3.12-pip-${{ hashFiles('**/requirements*.txt') }}
          restore-keys: |
            ${{ runner.os }}-py3.12-pip-
      - run: pip install -r requirements.txt
      - run: pytest
```

### 5.3 Artefacto entre jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: mkdir -p dist && echo "built @ $(date -u +%FT%TZ)" > dist/app.txt
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
        with:
          name: app-dist
          path: dist/
      - run: cat dist/app.txt

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - run: echo "deploying $(cat dist/app.txt)"
```

---

## 6. Implementación progresiva

Un patrón razonable al diseñar la caché desde cero:

1. **Empieza con `setup-*` + `cache:`**. Es correcto por default y cubre 80% de los casos.
2. **Observa el log**: la primera run guarda; la segunda debe decir `Cache hit`. Si no lo dice, lee la clave que calculó y compárala con la esperada.
3. Si necesitas cachear más (p. ej. venv entero, no solo wheels), pasa a `actions/cache@v4` **sumando** cosas, pero mantén la clave basada en el **lockfile**.
4. Añade `restore-keys` como *fallback* por prefijo. Nunca uses solo `restore-keys` sin `key` (no sabrías qué guardar).
5. Para matrices multi-OS/multi-versión: incluye `${{ runner.os }}` y `${{ matrix.python-version }}` en la clave. Si no, hay colisión cross-OS que corrompe la caché.

Para artefactos, el flujo progresivo:

1. Produce el output en `build` dentro de una carpeta clara (`dist/`, `out/`, `coverage/`).
2. Sube con un nombre explícito (`app-dist`, nunca `artifact1`).
3. Declara retención corta por defecto (`retention-days: 7`). Un release los promociona a release assets.
4. `if-no-files-found: error` para fallar ruidosamente si el build no produjo nada (default es `warn`, que esconde bugs).
5. Descarga en jobs downstream vía `needs:` + mismo `name`.

---

## 7. Aplicación profesional

### 7.1 Pipeline estándar `build → test → deploy`

```
         ┌──────────┐
         │  build   │  ──> upload-artifact: app-dist, sbom, coverage
         └────┬─────┘
              │ needs
      ┌───────┼─────────┐
      ▼       ▼         ▼
  ┌───────┐ ┌───────┐ ┌─────────┐
  │ test  │ │ lint  │ │ scan    │  <-- download-artifact: app-dist (si aplica)
  └───┬───┘ └───┬───┘ └────┬────┘
      └─────────┼──────────┘
                ▼
            ┌────────┐
            │ deploy │  <-- download-artifact: app-dist
            └────────┘
```

Beneficios:
- `build` corre **una vez**, no una por job hermano.
- `deploy` deploya **exactamente lo testeado** (no re-builda).
- Rastreabilidad: el artifact está asociado al run (y por tanto al commit).

### 7.2 Políticas de retención

- Builds de PR: `retention-days: 7` o menos.
- Builds de `main`: 14–30 días (para debugging y rollback).
- Release artifacts: subir al **GitHub Release** (via `gh release upload`), no al store de artifacts; retención ilimitada.

### 7.3 Observabilidad del cache

- Ve a *Actions → Caches* en la UI del repo: lista entradas, tamaño total, última vez accedidas. Puedes borrarlas manualmente.
- Vía CLI: `gh cache list` y `gh cache delete <id>`. Útil para forzar invalidación cuando sospechas corrupción.

---

## 8. Trade-offs

| Decisión | Pros | Contras |
|----------|------|---------|
| `setup-*` con `cache:` | Simple, correcto por default | Menos control (clave y path fijos) |
| `actions/cache@v4` a mano | Control total | Más líneas, es posible equivocar la clave |
| Caché del `venv` completo | Un solo restore, cero `pip install` | Grande (puede exceder 500 MB), colisión cross-OS si olvidas `runner.os` |
| Caché solo de `~/.cache/pip` | Pequeña, segura | Igual hay que correr `pip install` (resuelve y linkea rápido con wheels locales) |
| Artefactos para todo | Rastreable, explícito | Lento para datasets grandes; cuesta almacenamiento |
| Caché para todo | Rápido | Pipeline falla silenciosamente si el consumidor asume la caché |
| Retención larga (90 d) | Debugging a posteriori | Factura mayor; posible leak de datos sensibles |
| Retención corta (1–7 d) | Barato | No puedes reproducir runs viejos |

Regla práctica:
- **Caché** para *dependencies* y *compiler caches* (ccache, sccache).
- **Artefactos** para *build outputs* y *reports* (coverage HTML, SBOMs, wheels publicables).

---

## 9. Errores frecuentes

### 9.1 "La caché nunca hace hit"

Causas más comunes, en orden:

1. **`hashFiles('**/no-existe.lock')`** — devuelve hash del vacío, siempre igual. Verifica el glob con `find . -name 'poetry.lock'` localmente.
2. **Branch nueva sin `restore-keys`** — primera run de la branch no encuentra exacto; sin fallback hace miss. Añade `restore-keys` con prefijo estable.
3. **Clave con `${{ github.sha }}`** — único por commit; **nunca** hace hit en el commit siguiente. Error clásico de copy-paste.
4. **Clave sin `runner.os`** en matriz multi-OS — colisión: Linux pisa macOS y luego "no funciona en macOS".
5. **Default branch vacío** — si tu `main` nunca ejecutó el workflow, no hay cache para fallback.

### 9.2 "Mi `upload-artifact` falla con 'already exists'"

En v4 **no puedes** subir dos artefactos con el mismo nombre en un run. Si vienes de una matriz, usa `name: dist-${{ matrix.os }}-${{ matrix.python-version }}` y en el consumer usa `pattern:`.

### 9.3 "`download-artifact` no encuentra nada"

- Olvidaste `needs: build` → el job corrió en paralelo con `build` y aún no existía el artifact.
- Mezclaste `upload-artifact@v4` con `download-artifact@v3` (o viceversa) — son backends incompatibles. Pin a la misma major.
- Nombre mal escrito. Es case-sensitive.
- Retención expiró y lo estás descargando desde otro workflow mucho después.

### 9.4 "Mi caché tiene algo corrupto"

- Las claves son **inmutables**: una entrada con `key: X` nunca se sobreescribe. Si quedó mal, cambia la `key` (bumpea un salt: `pip-v2-${{ hashFiles(...) }}`) o bórrala por UI.

### 9.5 "El artifact pesa gigabytes y es lento"

- Subes carpetas con `.git/`, `node_modules/`, caches de IDE. Añade `exclude:` en el `upload-artifact`, o filtra antes con `tar --exclude`.
- Para builds muy grandes, considera subir a tu propio S3/GCS vía OIDC (va en `gha-11`) en vez del store de GitHub.

### 9.6 "Mi caché cross-OS no funciona"

Las wheels de Python son platform-specific. Una caché compartida entre Linux y macOS **corrompe** ambas. Siempre `runner.os` en la clave.

### 9.7 Confundir caché con artefacto

Síntoma: "el deploy a veces falla porque no encuentra `dist/app.txt`". Causa: usaste caché en lugar de artifact. La caché *puede* no estar; el artifact *debe* estar. Si el pipeline **depende** del archivo, es artefacto.

---

## 10. Buenas prácticas

- **Siempre `restore-keys`** como fallback por prefijo, con el campo más volátil (hash) al final.
- **`runner.os`** siempre en la clave de caché.
- **`cache-dependency-path`** siempre explícito cuando uses `setup-*` con `cache:`.
- **`if-no-files-found: error`** siempre en `upload-artifact` para builds.
- **Mismo major** en `upload-artifact` y `download-artifact`.
- **Un nombre por propósito** (`app-dist`, `coverage-html`, `sbom`), no genéricos (`output`, `artifact`).
- **`retention-days`** explícito; nunca confiar en el default (varía).
- **No cachees secretos** ni tokens — los paths cacheados viajan al store compartido.
- **Monitorea tamaño** del store (`gh cache list`) una vez al mes; evita acumular 10 GB de basura.
- **Promociona** artifacts estables a GitHub Releases para retención larga; no uses el store como almacén permanente.

---

## 11. Ejercicios recomendados

1. En un repo tuyo con tests Python, añade `setup-python` con `cache: 'pip'` y confirma el segundo run con cache hit.
2. Reescribe lo anterior con `actions/cache@v4` manual, cacheando `~/.cache/pip` y el `venv`. Compara tiempos.
3. Rompe adrede la caché con `hashFiles('**/non-existing.lock')` y observa que todas las runs comparten la clave vacía.
4. Haz una matriz `os × python-version`. Olvida `runner.os` en la clave; observa el comportamiento. Arréglalo.
5. Separa un workflow monolítico en `build → test → deploy` con `upload/download-artifact@v4`.
6. Fuerza el error de la mezcla v3 ↔ v4 y lee el mensaje real para reconocerlo en el futuro.

---

## 12. Evaluación

Responde sin consultar:

1. ¿Cuál es la diferencia esencial entre una caché y un artefacto? Da un ejemplo de cada uno donde el otro sería incorrecto.
2. ¿Qué devuelve `hashFiles('**/pyproject.toml')` si no hay ningún `pyproject.toml` en el repo? ¿Qué consecuencia tiene?
3. Un workflow en branch `feature/x` corre por primera vez. ¿De dónde puede venir un cache hit?
4. Un compañero migró `upload-artifact` a v4 pero los consumidores siguen en v3. ¿Qué va a pasar y cuál es el fix mínimo?
5. ¿Por qué `key: ${{ github.sha }}` como única clave de caché es un bug?
6. En una matriz `{os: [ubuntu, macos], python: [3.11, 3.12]}`, escribe la clave de caché correcta para pip. Justifica cada componente.
7. Tu `upload-artifact@v4` falla con *"an artifact with this name already exists"*. ¿Qué cambió respecto a v3 y cómo lo resuelves?
8. ¿Por qué `if-no-files-found: warn` (default) puede ocultar bugs en producción? ¿Qué valor eliges para un build y por qué?

---

## Referencias

- `actions/cache` — <https://github.com/actions/cache>
- `actions/upload-artifact` v4 — <https://github.com/actions/upload-artifact>
- `actions/download-artifact` v4 — <https://github.com/actions/download-artifact>
- Migration guide v3 → v4 — <https://github.com/actions/upload-artifact/blob/main/docs/MIGRATION.md>
- `setup-python` caching — <https://github.com/actions/setup-python#caching-packages-dependencies>
- GitHub Docs — Caching dependencies to speed up workflows — <https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows>
- GitHub Docs — Storing and sharing data from a workflow — <https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow>
- `hashFiles` expression — <https://docs.github.com/actions/learn-github-actions/expressions#hashfiles>
