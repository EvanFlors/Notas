# Ejemplo 02 — Nunjucks sobre el skeleton

> Lectura. Objetivo: ver cómo los placeholders del skeleton se renderizan en el output final.

## Esquema

```
template.yaml           # usa 'fetch:template' con url: ./skeleton
skeleton/
├── catalog-info.yaml
├── README.md
├── pyproject.toml
└── src/
    └── {{ values.name | replace('-', '_') }}/
        └── app.py
```

El step relevante del `template.yaml`:

```yaml
- id: fetch
  name: Fetch skeleton
  action: fetch:template
  input:
    url: ./skeleton
    values:
      name: ${{ parameters.name }}
      description: ${{ parameters.description }}
      owner: ${{ parameters.owner }}
```

## Archivos del skeleton (anotados)

### `skeleton/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description }}
  annotations:
    github.com/project-slug: my-org/${{ values.name }}
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
```

### `skeleton/pyproject.toml`

```toml
[project]
name = "${{ values.name }}"
version = "0.1.0"
description = "${{ values.description }}"
```

### `skeleton/README.md`

````markdown
# ${{ values.name }}

${{ values.description }}

**Owner:** ${{ values.owner }}

Generated from `python-microservice@v1`. To update, run:

```
./scripts/update-from-template.sh
```
````

### `skeleton/src/{{ values.name | replace('-', '_') }}/app.py`

```python
"""Entry point for ${{ values.name }}."""
from fastapi import FastAPI

app = FastAPI(title="${{ values.name }}")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
```

## Filtros usados

- `${{ values.name }}` — kebab-case para el directorio raíz y campos "nombre humano".
- `${{ values.name | replace('-', '_') }}` — snake_case para el **nombre de paquete Python** (los guiones no son válidos en identifiers de Python).
- `${{ values.name | lower }}` — defensa de normalización por si el usuario escapa del `pattern`.

## Después del render (ejemplo con `name=orders-api`)

```
output/
├── catalog-info.yaml        # Component orders-api
├── pyproject.toml           # name = "orders-api"
├── README.md                # título "# orders-api"
└── src/
    └── orders_api/          # paquete Python válido
        └── app.py
```

## Trampa a recordar

Si el skeleton contiene archivos binarios o YAMLs que **no** quieres renderizar (p. ej. un `kustomization.yaml` que ya tiene llaves `${}` propias), `fetch:template` acepta un `copyWithoutRender: [list, de, globs]` que los copia tal cual. No todos los archivos tienen por qué pasar por el motor.
