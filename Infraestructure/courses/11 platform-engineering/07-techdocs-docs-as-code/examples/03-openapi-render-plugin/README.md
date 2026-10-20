# Example 03 — Autogen de API docs desde OpenAPI (walkthrough)

Este ejemplo muestra cómo renderizar un `openapi.yaml` **dentro** del sitio TechDocs, de forma que la referencia de API viva en el mismo repo que el servicio y se publique con el mismo pipeline.

Es **walkthrough + lectura**. La configuración es ejecutable localmente si tienes `pip` disponible — ver sección "Cómo ejecutar" al final.

## Problema

Las API refs tienen una paradoja: deben ser **autogeneradas** desde el contract (sino divergen del código), pero deben ser **navegables** desde el mismo sitio TechDocs donde está el runbook. Dos opciones mediocres habituales:

1. **Hostear Swagger UI aparte.** Rompe el "one portal" — el dev tiene que saber otra URL.
2. **Pegar el YAML en Markdown.** Se renderiza como texto plano, no como UI interactiva.

La opción buena es un plugin MkDocs que embebe Swagger UI leyendo el `openapi.yaml` del propio repo.

## Solución — `mkdocs-render-swagger-plugin`

### `mkdocs.yml` (fragmento relevante)

```yaml
plugins:
  - techdocs-core
  - render_swagger       # 👈 añadido

nav:
  - Home: index.md
  - API:
      - Reference: api/reference.md
```

### `docs/api/reference.md`

```markdown
# API reference

Esta referencia se genera desde el contract OpenAPI del servicio
(`docs/api/openapi.yaml`). Si editas el contract, re-genera y hace commit;
el pipeline TechDocs la republicará.

!!swagger openapi.yaml!!
```

El shortcode `!!swagger openapi.yaml!!` es resuelto por el plugin: busca `openapi.yaml` **relativo a la página Markdown** (es decir, `docs/api/openapi.yaml`) y embebe Swagger UI apuntándolo.

### `docs/api/openapi.yaml` — ejemplo mínimo

```yaml
openapi: 3.0.3
info:
  title: Example Service API
  version: 0.1.0
  description: |
    API pública del example-service. Esta referencia se auto-publica
    desde el repo del servicio como parte del sitio TechDocs.
servers:
  - url: https://api.example.com
paths:
  /health:
    get:
      summary: Health check
      responses:
        '200':
          description: OK
  /orders/{id}:
    get:
      summary: Get order by id
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        '200':
          description: Found
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Order' }
        '404':
          description: Not found
components:
  schemas:
    Order:
      type: object
      required: [id, total_cents]
      properties:
        id: { type: string }
        total_cents: { type: integer, minimum: 0 }
```

### `requirements.txt` del sitio (si usas uno)

```
mkdocs
mkdocs-techdocs-core
mkdocs-render-swagger-plugin
```

En el CI del pipeline TechDocs, instalar también `mkdocs-render-swagger-plugin`:

```yaml
- run: pip install mkdocs mkdocs-techdocs-core mkdocs-render-swagger-plugin
```

## Variantes

### AsyncAPI

No hay un plugin MkDocs tan maduro como el de OpenAPI. Dos caminos:

- **Pre-render estático:** correr `asyncapi generate fromTemplate openapi.yaml @asyncapi/html-template -o docs/api/async-html` en CI y linkar desde `docs/api/async.md` con un iframe o un `<a>`.
- **Embed por iframe desde AsyncAPI Studio.** Rápido pero depende de servicio externo.

### Backstage API Docs plugin

Alternativa complementaria: declarar `kind: API` en `catalog-info.yaml` con un `spec.definition` que contenga el `openapi.yaml`. Backstage ofrece una pestaña **API** separada de TechDocs que renderiza la ref. Las dos opciones pueden coexistir:

- **TechDocs** → ref embebida dentro del "libro" de docs del servicio (orientada a lectura humana).
- **API entity** → ref expuesta en el catálogo (orientada a *discovery* y relaciones `providesApi`/`consumesApi`).

El estándar razonable para servicios públicos es **ambas**: un `kind: API` para el catálogo y un embed en el TechDocs del Component que lo provee.

## Antipatterns

- **Checkear Swagger UI compilado en el repo** (los `.js`/`.css` servidos directamente). El plugin ya los sirve; añadir estáticos propios duplica mantenimiento.
- **`openapi.yaml` generado por un script en el server y no commiteado.** Entonces no se puede renderizar en TechDocs (CI no tiene cómo generarlo sin levantar el servicio). Preferir generación en CI con el servicio parado (si el framework lo permite) o adoptar **spec-first** y commitear el `.yaml` escrito a mano.

## Cómo ejecutar localmente

Si quieres ver el render del shortcode:

```bash
mkdir -p /tmp/plat-07-example-03/docs/api
cd /tmp/plat-07-example-03

cat > requirements.txt <<'EOF'
mkdocs
mkdocs-techdocs-core
mkdocs-render-swagger-plugin
EOF

pip install -r requirements.txt

cat > mkdocs.yml <<'EOF'
site_name: Example API
plugins:
  - techdocs-core
  - render_swagger
nav:
  - Home: index.md
  - API: api/reference.md
EOF

echo "# Home" > docs/index.md
# Copia el reference.md y openapi.yaml del snippet de arriba
mkdocs serve
# abre http://127.0.0.1:8000/api/reference/
```

Si no tienes `pip`/MkDocs instalado, lee el walkthrough y ya está: el patrón es minúsculo.
