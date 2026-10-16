# Ejemplo 01 — Anatomía mínima de un `template.yaml`

> Lectura y análisis. Sin ejecución. Objetivo: fijar la estructura de un template v1beta3 antes de escribir uno.

## El template más corto que es útil

El siguiente `template.yaml` crea un repo con sólo un `README.md` y lo registra en el catálogo. No sirve en producción, pero es la **célula mínima** sobre la que crecen los demás.

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: hello-service
  title: Hello Service
  description: Minimal template — one README, one repo, one catalog entry
  tags: [example]
spec:
  owner: group:platform-team
  type: service

  parameters:
    - title: Service identity
      required: [name]
      properties:
        name:
          title: Service name
          type: string
          pattern: '^[a-z][a-z0-9-]{2,30}$'
          description: lowercase, kebab-case, 3-31 chars

  steps:
    - id: fetch
      name: Fetch skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        repoUrl: github.com?repo=${{ parameters.name }}&owner=my-org
        description: ${{ parameters.name }}

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
```

## Lectura clave

1. **Tres bloques, nunca mezclados**: `parameters` (schema), `steps` (ejecución), `output` (UI final).
2. **`metadata.name`** es el identificador estable; es lo que el usuario ve en la URL del scaffolder.
3. **El schema de `parameters`** es puro JSON Schema. Si lo cumples, el frontend del scaffolder lo pinta automáticamente. Nunca escribes HTML.
4. Cada `step` tiene `id`, `name` (lo que ve el usuario) y `action` (el nombre registrado en el backend). Si el `action` no existe en tu Backstage, el task falla al arrancar.
5. **Flujo de datos**: `${{ parameters.<x> }}` lee del form; `${{ steps.<id>.output.<k> }}` lee del output de un step previo. Nada más — ni variables globales, ni funciones.

## Qué NO está aquí (porque este ejemplo es intencionalmente mínimo)

- No hay chart, ni CI, ni TechDocs. Ver `03-end-to-end-microservice-template/`.
- No hay condicionales ni opt-outs. Ver §5 de `theory/lesson.md`.
- No hay custom actions. Ver `theory/lesson.md` §3.
