# REFERENCE — precommit-debug

Versiones limpias.

### broken-config.yaml

```yaml
---
service:
  name: capstone
  port: 8000
  features:
    - healthz
    - tasks
```

### bad_code.py

```python
def add(a: int, b: int) -> int:
    return a + b
```

### trailing.txt

Mismo contenido pero sin espacios al final:

```
line one has trailing spaces
line two is clean
line three also has them
```

### Cierre

```bash
echo precommit-ok > /tmp/cap-01-03/DONE
```

Punto pedagógico: aunque el validator no corre `pre-commit` (evita red), los
chequeos sintéticos (`grep -P '\t'`, `grep '^import os'`, `grep ' $'`,
`grep '-> int'`) actúan como un *shadow* de los hooks reales — mismo
veredicto en segundos y sin dependencias.
