# Starter — ans-08-02-ci-publish-on-tag

Esta actividad es **independiente**: produces un workflow YAML y un README de diseño.

## Pasos

1. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-08-02/.github/workflows
   cd /tmp/ans-08-02
   ```
2. Crea `.github/workflows/role-ci.yml` con los tres jobs: `lint`, `molecule`, `publish`.
3. Crea `CI-DESIGN.md` con las 4 secciones requeridas: `Matriz`, `Gate de publicación`, `Secretos`, `Caché`.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/08-testing-molecule-lint-and-ci/activities/02-ci-publish-on-tag/tests/validate.sh /tmp/ans-08-02
   ```

Usa `../../examples/03-gha-matrix-role-ci/README.md` como referencia; **no copies literal**: la validación comprueba la presencia de las claves, no que sea idéntico.

## Esqueleto mínimo

```yaml
---
name: role-ci
on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    branches: [main]
jobs:
  lint: {...}
  molecule:
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        distro: [..., ..., ...]
        ansible-core: ['...', '...']
    steps: [...]
  publish:
    needs: molecule
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - run: |
          ansible-galaxy role import \
            --api-key "${{ secrets.GALAXY_API_KEY }}" \
            "${{ github.repository_owner }}" \
            "${{ github.event.repository.name }}"
```
