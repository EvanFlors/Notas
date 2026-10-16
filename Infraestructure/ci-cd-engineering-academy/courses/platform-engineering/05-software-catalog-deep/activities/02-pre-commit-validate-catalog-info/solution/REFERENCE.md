# REFERENCE — plat-05-02-pre-commit-validate-catalog-info

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `validate-catalog-info.sh` (modelo)

```bash
#!/usr/bin/env bash
# validate-catalog-info.sh — rechaza catalog-info.yaml rotos antes del push.
# Uso: validate-catalog-info.sh <path.yaml> [path.yaml ...]
# Exit 0 si todos pasan, 1 si al menos uno falla.

set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <path.yaml> [path.yaml ...]" >&2
  exit 2
fi

python3 - "$@" <<'PY'
import re
import sys
import yaml

NAME_RE = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$")
OWNERED = {"Component", "API", "Resource", "System"}

failures = 0

for path in sys.argv[1:]:
    try:
        with open(path, "r") as fh:
            docs = list(yaml.safe_load_all(fh))
    except yaml.YAMLError as exc:
        print(f"FAIL {path}: invalid YAML ({exc.__class__.__name__})")
        failures += 1
        continue
    except OSError as exc:
        print(f"FAIL {path}: {exc}")
        failures += 1
        continue

    file_errors = []
    for i, doc in enumerate(docs):
        if doc is None:
            continue
        if not isinstance(doc, dict):
            file_errors.append(f"doc {i}: top-level must be a mapping")
            continue
        kind = doc.get("kind")
        meta = doc.get("metadata") or {}
        spec = doc.get("spec") or {}
        name = meta.get("name")

        if not doc.get("apiVersion"):
            file_errors.append(f"doc {i}: missing apiVersion")
        if not kind:
            file_errors.append(f"doc {i}: missing kind")
        if not name:
            file_errors.append(f"doc {i}: missing metadata.name")
        elif not NAME_RE.match(str(name)):
            file_errors.append(f"doc {i}: metadata.name '{name}' violates kebab-case regex")

        if not spec:
            file_errors.append(f"doc {i}: missing spec")

        if kind in OWNERED:
            owner = (spec or {}).get("owner") or ""
            if not (isinstance(owner, str)
                    and (owner.startswith("group:") or owner.startswith("user:"))):
                file_errors.append(f"doc {i} ({kind} '{name}'): spec.owner must be 'group:X' or 'user:X'")

        if kind == "Component":
            annotations = meta.get("annotations") or {}
            if not isinstance(annotations, dict) or len(annotations) < 2:
                n = len(annotations) if isinstance(annotations, dict) else 0
                file_errors.append(f"doc {i} (Component '{name}'): need >=2 annotations (got {n})")

    if file_errors:
        for err in file_errors:
            print(f"FAIL {path}: {err}")
        failures += 1
    else:
        print(f"OK   {path}")

sys.exit(1 if failures else 0)
PY
```

Puntos clave:

- `set -eu` sin `pipefail`: evita falsos positivos con `grep -q` interrumpido por SIGPIPE.
- Heredoc Python inline: hace el hook portable (un solo archivo, sin dependencias de scripts externos).
- Mensajes de error nombran **qué** falla y **dónde** (archivo + documento + razón).
- Devuelve exit code adecuado para que `git commit` o `pre-commit` lo detecten.

## Fixtures (modelo)

### `fixtures/good-component.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
```

### `fixtures/bad-missing-owner.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
```

### `fixtures/bad-too-few-annotations.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug: acme/orders-api
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
```

### `fixtures/bad-broken-yaml.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug acme/orders-api   # falta ':'
spec:
  owner: group:orders-team
```

### `fixtures/bad-missing-name.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
```

## `install.md` (modelo)

```markdown
# Instalar el hook validate-catalog-info

## Opción A — hook nativo de git (un solo repo)

```bash
# desde la raiz del repo:
cp validate-catalog-info.sh .git/hooks/pre-commit-validate
chmod +x .git/hooks/pre-commit-validate

cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
# Ejecuta validate-catalog-info sobre los catalog-info.yaml modificados.
changed=$(git diff --cached --name-only --diff-filter=ACM | grep 'catalog-info\.yaml$' || true)
if [ -z "$changed" ]; then
  exit 0
fi
bash .git/hooks/pre-commit-validate $changed
HOOK
chmod +x .git/hooks/pre-commit
```

## Opción B — framework `pre-commit` (recomendado para equipos)

Añade a `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: validate-catalog-info
        name: Validate catalog-info.yaml
        entry: bash validate-catalog-info.sh
        language: system
        files: 'catalog-info\.yaml$'
```

Después:

```bash
pre-commit install
```

El hook corre automáticamente antes de cada commit; también se puede ejecutar sobre todos los archivos del repo con `pre-commit run --all-files`.
```

## Punto a repetir hasta que suene aburrido

> El hook pre-commit es la **primera** defensa, no la única. El provider de Backstage es la **última** línea; en medio van CI jobs y scorecards. **Sin la primera, las otras llegan tarde: el YAML roto ya es parte de `main`**.
