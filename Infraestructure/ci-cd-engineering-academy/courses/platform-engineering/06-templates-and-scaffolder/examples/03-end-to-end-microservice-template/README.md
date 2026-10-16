# Ejemplo 03 — Template end-to-end "nuevo microservicio Python"

> Lectura. Composición completa: `parameters` ricos, `steps` encadenados, `output.links` útiles. **No se ejecuta aquí** — se construye en la actividad `01-build-microservice-template`.

## `template.yaml` (completo)

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: python-microservice
  title: New Python Microservice (FastAPI)
  description: FastAPI + GHA + Helm chart + Argo Application + TechDocs
  tags: [python, fastapi, golden-path]
spec:
  owner: group:platform-team
  type: service

  parameters:
    - title: Service identity
      required: [name, description, owner]
      properties:
        name:
          title: Service name
          type: string
          pattern: '^[a-z][a-z0-9-]{2,30}$'
        description:
          title: What does it do?
          type: string
          maxLength: 120
        owner:
          title: Owning team
          type: string
          ui:field: OwnerPicker
          ui:options:
            allowedKinds: [Group]

    - title: Deployment target
      required: [environment, replicas]
      properties:
        environment:
          title: Environment
          type: string
          enum: [dev, staging, prod]
          default: dev
        replicas:
          title: Replicas
          type: integer
          minimum: 1
          maximum: 10
          default: 2

    - title: Options
      properties:
        enableTechDocs:
          title: Include TechDocs?
          type: boolean
          default: true

  steps:
    - id: fetch
      name: Fetch skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          environment: ${{ parameters.environment }}
          replicas: ${{ parameters.replicas }}

    - id: dropTechDocs
      name: Drop TechDocs if not wanted
      if: ${{ parameters.enableTechDocs == false }}
      action: fs:delete
      input:
        files: [docs, mkdocs.yml]

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        repoUrl: github.com?repo=${{ parameters.name }}&owner=my-org
        description: ${{ parameters.description }}
        defaultBranch: main

    - id: register
      name: Register in catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
      - title: TechDocs
        url: ${{ steps.publish.output.remoteUrl }}/tree/main/docs
```

## Skeleton (listado)

```
skeleton/
├── catalog-info.yaml
├── README.md
├── pyproject.toml
├── Dockerfile
├── mkdocs.yml                 (eliminado si enableTechDocs=false)
├── docs/                      (eliminado si enableTechDocs=false)
│   └── index.md
├── src/
│   └── {{ values.name | replace('-', '_') }}/
│       └── app.py
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml            (replicas: ${{ values.replicas }})
│   └── templates/
│       └── deployment.yaml
├── argo/
│   └── application.yaml       (destination.namespace según env)
└── .github/
    └── workflows/
        └── ci.yaml
```

## Observa

- **Pasos condicionales** (`if: ${{ parameters.enableTechDocs == false }}`) para opt-outs limpios.
- **`output.links`** para que al terminar el usuario tenga 3 clics directos: ir al repo, ir al catálogo, ir a los docs.
- **`register` referencia un path (`catalog-info.yaml`)** que **existe en el skeleton** — por eso el nuevo servicio aparece instantáneamente en el catálogo.
- Ningún step corre tests ni valida — eso lo hace la **CI del template** (ver actividad 02).

## Qué faltaría en producción real

- Un step que abra un PR al repo `argo-apps/` para registrar la nueva Argo Application.
- Un step que registre dashboards/alertas en Grafana via `publish:github:pull-request` al repo de observabilidad.
- Un `catalog-info.yaml` para el **repo del propio template** (meta: templates también son componentes).

Estas extensiones son triviales una vez entendida la base.
