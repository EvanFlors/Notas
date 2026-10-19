# Solución de referencia — ans-08-02

Esta solución cubre todos los checks del validador. Compárala con tu entrega.

## Archivos entregados

```
.github/workflows/role-ci.yml
CI-DESIGN.md
```

## Decisiones clave

- **3 jobs encadenados** con `needs:` — `lint` → `molecule` → `publish`.
- **Matriz 3×2** con `fail-fast: false`.
- **`concurrency`** cancela runs anteriores en la misma ref.
- **Gate `publish`** condicional al tag SemVer.
- **Secreto** consumido solo en el `run:` del paso de import.
- **Caché** de pip (via `setup-python`) y de collections (via `actions/cache@v4`).

## Antipatterns evitados

- No usar `main` como trigger de `publish` → publicarías pre-releases.
- No poner `GALAXY_API_KEY` en `env:` global → fuga en logs de cualquier paso.
- No omitir `fail-fast: false` → perderías señal de 5 celdas por el fallo de 1.
- No pedir Python 3.11 en todos los jobs → coherencia de entorno.
