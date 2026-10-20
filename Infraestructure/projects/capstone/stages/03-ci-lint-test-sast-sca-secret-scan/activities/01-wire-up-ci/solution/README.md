# Solucion — `cap-03-01-wire-up-ci`

La solucion materializada son los archivos de la propia etapa:

- `.github/workflows/ci.yml`
- `.github/workflows/pr.yml`
- `pyproject.toml`
- `.gitleaks.toml`

El fix esperado del hallazgo bandit es reemplazar:

```python
subprocess.run(cmd, shell=True, check=False)
```

por una variante segura, pasando la lista de argumentos:

```python
import shlex
subprocess.run(shlex.split(cmd), check=False)
```

o idealmente aceptar `cmd: list[str]` directamente en la firma.
