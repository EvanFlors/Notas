# Ejemplo 02 — CODEOWNERS con tres niveles de granularidad

## Concepto que demuestra

Un archivo `CODEOWNERS` real suele tener **tres niveles** de reglas, en orden de más general a más específica:

1. **Default owner** (`*`) — fallback cuando ninguna otra regla matchea.
2. **Owners por path** (directorios, `/path/`) — un equipo dueño de un subsistema.
3. **Owners por glob** (`*.ext`, patrones por tipo de archivo) — expertos transversales.

La regla crítica: **la última regla que matchea gana**. Si un archivo matchea 3 reglas, el owner efectivo lo dicta la última en el archivo.

## Estructura

```
examples/02-codeowners/
├── README.md               # este archivo
└── .github/
    └── CODEOWNERS          # el archivo real
```

Rutas aceptadas por GitHub (busca en orden; usa la primera encontrada):

```
.github/CODEOWNERS          ← ubicación preferida
CODEOWNERS                  ← raíz
docs/CODEOWNERS             ← si vive la doc en /docs
```

## Lectura del archivo

Abre `.github/CODEOWNERS` y observa:

- Cada regla es `<pattern> <owner1> [owner2]...`.
- `@user` o `@org/team`. Prefijo `@` **obligatorio**.
- `#` inicia comentario; líneas vacías permitidas.
- Patrones siguen la sintaxis de `.gitignore` **con limitaciones** (no se soportan negaciones `!` ni `[char-class]`).
- Un directorio sin `/` final matchea archivo *o* directorio con ese nombre; con `/` final matchea cualquier cosa debajo.

## Simular quién sería reviewer

Para cada archivo listado abajo, responde a qué owners se asignaría (ejercicio mental, luego verifica contra el archivo):

```
README.md
docs/architecture.md
src/api/handlers.py
src/web/app.js
.github/workflows/ci.yml
tests/test_handlers.py
```

(Respuestas al final de este README.)

## Validación de sintaxis (en GitHub real)

GitHub expone un endpoint que lista errores de parsing/owners inválidos:

```bash
gh api repos/<owner>/<repo>/codeowners/errors
```

Útil tras cualquier cambio al archivo.

## Puntos clave

- **CODEOWNERS no obliga por sí solo.** Hay que activar "Require review from Code Owners" en branch protection / Ruleset para que bloquee el merge.
- **Teams, no personas.** Un `@org/team` sobrevive a rotación; `@persona` se queda huérfano cuando se va.
- **Audita trimestralmente.** Equipos renombrados o eliminados generan owners inválidos silenciosos.
- **Específico gana a general.** Pon lo específico **abajo**.

---

### Respuestas al ejercicio

Dado el `CODEOWNERS` incluido:

- `README.md` → `@acme/maintainers` (default).
- `docs/architecture.md` → `@acme/docs-team` (regla `/docs/`).
- `src/api/handlers.py` → `@acme/api-team` (regla `/src/api/`, más específica que `*.py`).
- `src/web/app.js` → `@acme/frontend-team` (regla `/src/web/`).
- `.github/workflows/ci.yml` → `@acme/devops @alice` (regla `/.github/workflows/`).
- `tests/test_handlers.py` → `@acme/python-maintainers` (regla `*.py` — no hay regla más específica para `/tests/`).
