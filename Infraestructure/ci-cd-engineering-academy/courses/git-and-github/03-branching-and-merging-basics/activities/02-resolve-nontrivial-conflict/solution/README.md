# Solution — gh-03-02-resolve-nontrivial-conflict

**No ejecutes esto hasta haber intentado la actividad.** Resumen del flujo:

1. `git switch main` + `git merge --no-ff feature/caching` → merge limpio (los dos lados tocan archivos distintos; `main` solo trajo `CHANGELOG.md`).
2. `git merge --no-ff feature/retries` → **conflictos** en `config.yaml`, `app.py` y `README.md`.
3. **Resolución**:
   - `config.yaml`: ambas features activas (`cache: true`, `retries: 3`), timeout y log_level intactos.
   - `app.py`: composición en orden (caching wrapper **sobre** el cliente base, retrying wrapper **sobre** el caching).
   - `README.md`: ambos bullets, orden alfabético.
4. `git add` + `git commit` para cerrar el merge.
5. Entregable: `git log --graph --oneline --all --decorate > docs/graph.txt`.

Uso:

```bash
bash starter/build-starter.sh /tmp/nontrivial
bash solution/solve.sh         /tmp/nontrivial
bash tests/validate.sh         /tmp/nontrivial
```

### Por qué esta resolución es la correcta

- **config.yaml**: cada rama cambió una clave distinta a un valor "activo"; ninguna invalida la otra. Combinarlas respeta la **intención** registrada en cada commit.
- **app.py**: ambas features envuelven el cliente. El orden `cache → retry` significa "primero intenta cache, luego retry al cliente envuelto". El orden inverso también es defendible — lo importante es que **ambos** wrappers queden aplicados, no que descartes uno por descuido.
- **README.md**: documentación debe reflejar el estado real; dejar solo una feature contradice el código.
