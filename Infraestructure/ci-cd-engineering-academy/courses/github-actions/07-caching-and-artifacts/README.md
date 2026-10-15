# gha-07 — Caching y artefactos

## Identificación

- **ID:** `gha-07-caching-and-artifacts`
- **Curso:** `github-actions`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gha-06-matrix-dependencies-outputs` (jobs, `needs`, outputs). Se asume `gha-02` (expresiones, `hashFiles`) y `gha-04` (actions oficiales).

## Objetivo

Dejar de pagar el "arranque frío" en cada run y dejar de perder el output de un job cuando otro job lo necesita. Al terminar sabrás **diseñar claves de caché que acierten de verdad**, decidir cuándo usar la caché integrada de `setup-*` vs `actions/cache@v4` a mano, y mover archivos entre jobs (y entre runs) con `upload-artifact` / `download-artifact` **v4**, cuya API es incompatible con v3 — ese cambio es una de las fuentes más comunes de pipelines rotos hoy.

El mensaje de fondo: **caché ≠ artefacto**. La caché es reutilización oportunista para acelerar algo que se puede reconstruir; el artefacto es un contrato explícito entre jobs. Confundirlos lleva a pipelines frágiles.

## Alcance

- **`actions/cache@v4`**: `path`, `key`, `restore-keys`, scoping por branch con fallback a default branch.
- **Caché integrada de `setup-*`**: `setup-python` con `cache: 'pip'` y `cache-dependency-path`; equivalentes en `setup-node`, `setup-java`, `setup-go`.
- **Invalidación por hash del lockfile**: `${{ hashFiles('**/requirements*.txt') }}`, `**/poetry.lock`, `**/package-lock.json`.
- **`actions/upload-artifact@v4` / `actions/download-artifact@v4`**: nombre único por run, API de descarga por nombre o por patrón, `retention-days`, `if-no-files-found`.
- **Breakage v3 → v4**: artefactos subidos con v4 **no son descargables por v3**, y viceversa; mezclar versiones es un error silencioso común.
- **Límites y trampas**: tamaño total del store de caché (10 GB por repo con eviction LRU), scope por branch, cross-OS pitfalls, retención por defecto, costo de storage.
- Diferencia conceptual **caché vs artefacto**: oportunista vs contrato, retención, visibilidad.

Lo que **no** cubre (va después):
- Reusable workflows que compartan caches/artifacts → `gha-08`.
- Cache poisoning y hardening de restore → `gha-13`.
- Build cache de Docker (`type=gha`) → `gha-12` + Docker (D6).
- Attestations sobre artefactos → `gha-14`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones: modelo de caché, hashFiles, scope, v3→v4, patrones de artefactos, diagnóstico.
- **`examples/`**:
  - `01-pip-cache/` — dos variantes del mismo workflow: con `setup-python cache: 'pip'` y con `actions/cache@v4` a mano, comparando llaves y hits.
  - `02-artifact-between-jobs/` — pipeline `build → test → deploy` donde `build` sube un artefacto y los otros dos lo descargan (v4).
- **`activities/`**:
  - `01-cache-python-deps/` — guided-lab: tomar un workflow sin caché y añadirle una estrategia correcta (clave con `hashFiles` + `restore-keys`).
  - `02-share-build-output-via-artifact/` — guided-lab: refactorizar un workflow monolítico en `build → test → deploy` compartiendo `dist/` por artefacto.
- **`resources/links.md`** — docs oficiales de `actions/cache`, `upload-artifact` v4, migración v3→v4.

## Modo de ejecución de las actividades

Los validadores de este módulo son **100% locales**: inspeccionan el YAML del workflow (estructura, keys, paths, versiones de acciones) con `python3 + PyYAML`. No necesitas cuenta de GitHub ni ejecutar el workflow en runners reales para completar el módulo — lo que se evalúa es el **diseño del pipeline**, no el log de un run.

Si quieres ver el cache hit real en la UI de Actions, el `README` de cada actividad incluye instrucciones opcionales de "cómo probarlo en vivo".

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar caché y artefacto. Explicar por qué una caché "no hace hit" (clave, scope, hash). Explicar el breakage v3→v4 de `upload-artifact`. |
| Operativa | Diseñar `key` + `restore-keys` para pip/poetry/node. Decidir entre `setup-python cache:` y `actions/cache@v4` a mano. Dividir un workflow en `build → test → deploy` con artefactos. |
| Arquitectónica | Elegir estrategia de caché según coste de rehidratación y volatilidad del lockfile. Elegir retención y naming de artefactos según política de releases. |

## Entregables

- Workflow con **cache hit demostrable** por clave estable, con `restore-keys` como fallback.
- Pipeline con **3 jobs** donde `build` produce `dist/`, `test` lo descarga y corre pruebas sobre él, `deploy` lo descarga y simula un deploy — todo con `*-artifact@v4`.

## Criterios de evaluación

- **Conceptual**: dado un workflow donde la caché nunca hace hit, el estudiante señala si la causa es (a) `hashFiles` apuntando a un path inexistente, (b) ausencia de `restore-keys`, (c) scope de branch (feature branch sin fallback), o (d) cambio del runner image.
- **Operativa**: `validate.sh` de ambas actividades pasa.
- **Arquitectónica**: justifica por qué la clave es `pip-${{ hashFiles('requirements*.txt') }}` y no `pip-${{ github.sha }}` (nunca haría hit) ni `pip` sin hash (siempre haría hit obsoleto).

## Secuencia recomendada

1. Lee `theory/lesson.md` entero.
2. Reproduce `examples/01-pip-cache/` (compara las dos variantes).
3. Haz `activities/01-cache-python-deps/`.
4. Lee `examples/02-artifact-between-jobs/`.
5. Haz `activities/02-share-build-output-via-artifact/`.
6. Responde las preguntas de reflexión de ambas actividades sin consultar.

## Siguiente

→ `gha-08-reusable-workflows-and-composite-actions` (reutilización de la lógica que ya sabes orquestar).
