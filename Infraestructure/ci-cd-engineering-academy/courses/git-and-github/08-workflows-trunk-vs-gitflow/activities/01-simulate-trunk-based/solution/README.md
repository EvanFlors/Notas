# Solución de referencia — gh-08-01-simulate-trunk-based

> **No ejecutes esto antes de intentarlo tú.** Comprender el *por qué* de cada paso vale más que el `git log` final.

## Uso

```bash
bash starter/build-starter.sh /tmp/tbd-sim
bash solution/solve.sh /tmp/tbd-sim
bash tests/validate.sh /tmp/tbd-sim
```

## Lo que hace

1. Crea `feat/new-checkout`, añade el flag en `False`, añade la rama de código gated, hace smoke test, commitea y mergea con `--no-ff` a `main`. Elimina la rama.
2. Igual con `feat/dark-mode`.

## Observaciones

- Un **único** canal de integración: `main`.
- Las ramas efímeras no sobreviven al merge.
- Los flags *entran en `main` apagados por default* — podemos activar en runtime cuando queramos (deploy ≠ release).
- La historia es trivial de leer con `git log --oneline --graph`.
