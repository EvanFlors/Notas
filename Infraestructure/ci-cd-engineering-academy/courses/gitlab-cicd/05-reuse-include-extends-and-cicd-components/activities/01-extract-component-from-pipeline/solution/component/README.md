# node-test

Componente CI/CD que corre lint, tests unitarios y build de un proyecto Node.js sobre runners GitLab SaaS. Reemplaza el pipeline duplicado que corría en 7 proyectos del grupo `apps/`.

## Uso

```yaml
include:
  - component: 'gitlab.example.com/platform/ci-components/node-test@v1.0.0'
    inputs:
      node_version: '22'
      coverage: true
      stage: 'test'
```

## Inputs

| Nombre | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| `node_version` | string | `'20'` | Major de Node (`options:` 18, 20, 22). |
| `coverage` | boolean | `false` | Si `true`, corre `npm test -- --coverage` y expone `coverage/` como artifact. |
| `stage` | string | `'test'` | Stage del pipeline en el que correr los jobs. |
| `runner_tag` | string | `'saas-linux-small-amd64'` | Tag del runner. `options:` small-amd64, medium-amd64. |

## Jobs expuestos

- `node-lint:<version>`
- `node-unit:<version>`
- `node-build:<version>`

El `build` deja los artefactos en `dist/`. Úsalos desde tu pipeline con `needs:`.

## Compatibilidad

- GitLab >= 16.6.
- Node 18, 20, 22.

## Changelog

- `v1.0.0` — primera versión GA.
