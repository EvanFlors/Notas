# Actividad 02 — Resolver un conflicto no trivial con 3 ramas

## 1. Identificación

- **ID:** `gh-03-02-resolve-nontrivial-conflict`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-03-branching-and-merging-basics`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

En la actividad anterior resolviste **un** conflicto en una línea. En la vida real los conflictos vienen de a varios y mezclan dos tipos:

- **Conflicto de contenido** (el clásico, mismas líneas editadas distinto).
- **Conflicto en archivos distintos** del mismo merge (muchas banderitas rojas al mismo tiempo).

Esta actividad construye un repo con **tres ramas** que divergen desde un commit base, dos de ellas pensadas para mergearse a `main` en sucesión. El primer merge pasa limpio; el segundo detona conflictos en **dos archivos distintos** que tienes que resolver razonando con `diff3` (base / ours / theirs).

Al terminar, además de los conflictos resueltos, el repo debe producir un **DAG con 3+ ramas** visible en `git log --graph` — el entregable del módulo.

## 3. Objetivos

- Mergear secuencialmente dos ramas con el mismo destino (`main`).
- Resolver conflictos **en más de un archivo** en un mismo merge.
- Leer la zona de **base común** (`merge.conflictStyle = diff3`) para decidir resolución con criterio.
- Producir un DAG final con tres ramas visibles.
- Validar automáticamente que la resolución es coherente.

## 4. Prerrequisitos

- `gh-03-01-branch-and-merge` completada.
- Haber leído `theory/lesson.md` secciones 4 y 7.
- Git ≥ 2.30.

**Costos:** ninguno (local, `/tmp/`).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/nontrivial
cd /tmp/nontrivial
git log --graph --oneline --all --decorate
```

Verás **tres ramas** divergiendo desde un commit base común:

```
* <h1> (main) chore: baseline
| * <h2> (feature/caching) feat: enable caching in config and app
|/
| * <h3> (feature/retries) feat: enable retries in config and app
|/
* <base> init: project skeleton
```

(Es decir, `main` tiene un commit por encima de la base, y `feature/caching` y `feature/retries` cada una un commit por encima de la base también. Las tres divergen.)

El contenido relevante:

- `config.yaml`: define varias claves (`timeout`, `retries`, `cache`, `log_level`).
- `app.py`: función `make_client(cfg)` que lee la config y construye un cliente.
- `README.md`: resumen del proyecto.

Las dos ramas de feature **editan los mismos archivos** (`config.yaml` y `app.py`) pero cada una activa una feature distinta (caching vs retries). Ambas también actualizan el `README.md` para listar su feature.

### 5.2 Primer merge — `feature/caching` → `main`

Mergea `feature/caching` dentro de `main`:

```bash
git switch main
git merge --no-ff -m "Merge branch 'feature/caching'" feature/caching
```

Debería pasar limpio (sin conflictos). Verifica:

```bash
git log --graph --oneline --all --decorate
```

### 5.3 Segundo merge — `feature/retries` → `main` (con conflictos)

Ahora mergea `feature/retries` dentro de `main`:

```bash
git merge --no-ff -m "Merge branch 'feature/retries'" feature/retries
```

Debería **fallar** con conflictos en al menos dos archivos (`config.yaml`, `app.py`, y potencialmente `README.md`). Lee el output y después:

```bash
git status           # te lista los archivos "unmerged"
cat config.yaml      # verás los marcadores diff3
cat app.py
```

### 5.4 Resolución requerida

Resuelve de la siguiente manera (**es la combinación correcta**, no una elección arbitraria: deben quedar las dos features activas y coherentes).

#### `config.yaml` — resolución esperada

El archivo debe terminar con **exactamente** estas claves y valores (ordenadas como estaban, con `cache` y `retries` activadas):

```yaml
timeout: 30
retries: 3
cache: true
log_level: info
```

#### `app.py` — resolución esperada

La función `make_client(cfg)` debe aplicar **ambas** features: cachear según `cfg["cache"]` **y** reintentar según `cfg["retries"]`. El archivo final:

```python
def make_client(cfg):
    client = Client(timeout=cfg["timeout"])
    if cfg.get("cache"):
        client = CachingClient(client)
    if cfg.get("retries", 0) > 0:
        client = RetryingClient(client, attempts=cfg["retries"])
    return client
```

#### `README.md` — resolución esperada

El bullet list de features debe incluir **ambas** líneas (orden alfabético por consistencia):

```
- Caching: in-memory response cache
- Retries: automatic retry on transient failures
```

### 5.5 Cerrar el merge

```bash
git add config.yaml app.py README.md
git status           # "All conflicts fixed but you are still merging"
git commit           # el editor abre con "Merge branch 'feature/retries'" prellenado
                     # consérvalo o edítalo; el validador no comprueba el mensaje
```

### 5.6 Entregable: el DAG

Produce el grafo final y pégalo como entregable (o guárdalo con `tee docs/graph.txt`):

```bash
mkdir -p docs
git log --graph --oneline --all --decorate | tee docs/graph.txt
```

Debes ver tres ramas visibles y los dos merge commits a `main`.

### 5.7 Validar

```bash
bash tests/validate.sh /tmp/nontrivial
```

## 6. Resultado esperado

- Dos merge commits en `main` (uno por rama de feature).
- `config.yaml`, `app.py`, `README.md` en el estado especificado arriba.
- Sin marcadores de conflicto en ningún archivo.
- `docs/graph.txt` existe con el output de `git log --graph`.
- Ramas `feature/caching` y `feature/retries` siguen existiendo.
- Working tree limpio.

## 7. Criterios de aceptación

- [ ] Primer merge (caching) mergeado en main.
- [ ] Segundo merge (retries) mergeado en main con resolución coherente de los 3 archivos.
- [ ] Las dos features son funcionalmente coexistentes en el código final.
- [ ] `docs/graph.txt` producido.
- [ ] Ramas feature preservadas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/nontrivial
```

Verifica:
- Working tree limpio.
- Contenido exacto de `config.yaml` (clave `cache: true` **y** `retries: 3` presentes).
- `app.py` contiene las dos aplicaciones de wrapper (`CachingClient` y `RetryingClient`).
- `README.md` lista las dos features.
- Dos merge commits reachables desde main.
- Sin marcadores de conflicto.
- `docs/graph.txt` existe.
- Branches de feature existen.

## 9. Preguntas de reflexión

1. **La base común importa.** Para `config.yaml`, mira el stage 1 (`git show :1:config.yaml`) *antes de resolver*. ¿Qué información te dio la base que no habrías obtenido mirando solo ours+theirs?
2. En `app.py`, la resolución pide **composición** (ambos wrappers aplicados en orden). ¿Qué habría pasado si hubieras elegido "ours" (solo caching) sin pensar? ¿Y si fuese un merge inverso de otra persona?
3. ¿Qué cambia si inviertes el orden de los merges (primero `feature/retries`, luego `feature/caching`)? Predice qué conflictos aparecerían y en qué archivos — si quieres, repite el experimento en otro directorio.
4. Imagina que `feature/retries` fuera una rama de 50 commits en vez de 1. ¿Por qué los conflictos serían los mismos? (Pista: lo que importa es el **tree final** vs la base común, no cuántos pasos intermedios hubo.)
5. ¿Qué política de equipo evitaría este conflicto antes del merge final? (Pista: integrar `main` **hacia** cada feature regularmente.)

## 10. Extensiones (opcional)

- **E1** — Añade una tercera feature `feature/metrics` que también toque `config.yaml` + `app.py`, con una métrica (`metrics: true`) y un `MetricsClient` wrapper, y mergeala. Observa el orden de los wrappers resultantes.
- **E2** — Configura un `.gitattributes` con `README.md merge=union` para que los conflictos en bulletlists se auto-combinen. Deshaz y rehaz el merge y compara.
- **E3** — Investiga `git rerere` (reuse recorded resolution). Actívalo (`git config rerere.enabled true`), aborta el merge, hazlo de nuevo y observa que Git recuerda tu resolución anterior.

## 11. Limpieza

```bash
rm -rf /tmp/nontrivial
```
