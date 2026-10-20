# Solución de referencia — gh-08-02-simulate-gitflow

> No lo ejecutes antes de intentarlo tú.

```bash
bash starter/build-starter.sh /tmp/gitflow-sim
bash solution/solve.sh /tmp/gitflow-sim
bash tests/validate.sh /tmp/gitflow-sim
```

## Observaciones

- Son **~15 operaciones Git** vs ~6 de la Actividad 01.
- Cada release y cada hotfix exige **dos merges**. En producción se pierde uno al menos cada varios meses, por eso existe `git-flow` CLI y por eso GitFlow puro requiere disciplina/tooling o se degrada.
- `develop` es la fuente de "lo que va a la siguiente release". `main` es "lo que está en producción". El modelo exige mantener ambas sincronizadas; cualquier olvido reaparece como bug.
