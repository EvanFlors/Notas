# Lección — TechDocs & docs-as-code

> *"La documentación que no vive en el mismo repo que el código ya está desactualizada; solo que nadie lo ha medido todavía."*

## 1. Por qué docs-as-code

En la mayoría de organizaciones las docs viven en **Confluence**, **Notion**, **Google Docs** o un **SharePoint**. Esa separación produce tres patologías predecibles:

1. **Drift.** El código cambia en un PR; la doc vive en otro sistema; nadie la toca; la doc miente. A las 6 semanas, la página de "cómo desplegar foo" explica cómo se desplegaba foo hace tres sprints.
2. **Descubribilidad.** Cada equipo tiene su propio espacio Confluence con su propia jerarquía. Buscar "runbook de checkout" devuelve 14 páginas con títulos parecidos, 11 obsoletas.
3. **Ownership difuso.** Sin CODEOWNERS, la doc es "de todos y de nadie". No hay review obligatorio; no hay deprecations; no hay changelog.

**Docs-as-code** aplica a la documentación la misma disciplina que al código: vive en el **mismo repo** que el servicio, se escribe en **Markdown**, se somete a **PR + review** (los mismos reviewers que el código), pasa por **CI** (linter, build strict, link checker), y se **despliega** como artefacto estático.

**TechDocs** (parte de Backstage) es el motor de render + navegación: toma el `mkdocs.yml` de cada repo, lo renderiza con MkDocs y lo expone dentro del **portal interno** indexado por el catálogo. El efecto neto es que un developer busca "checkout" en Backstage y obtiene en la misma vista: el Component, su owner, sus APIs, sus deployments… y sus docs al día.

## 2. Arquitectura TechDocs: las tres piezas

TechDocs se apoya en tres piezas discretas, cada una con su rol:

| Pieza | Vive en | Rol |
|-------|---------|-----|
| `mkdocs.yml` | Repo del servicio | Config del sitio: `site_name`, `nav`, `plugins`, `markdown_extensions`. |
| `docs/*.md` | Repo del servicio | Contenido en Markdown (una página por `.md`, imágenes en `docs/img/`). |
| `catalog-info.yaml` → `metadata.annotations["backstage.io/techdocs-ref"]` | Repo del servicio | Puntero que le dice a Backstage **dónde** encontrar el `mkdocs.yml`. Valores típicos: `dir:.` (mismo repo), `url:https://github.com/org/repo/tree/main` (repo externo), `dir:docs-site` (subcarpeta). |

Flujo:

```
   catalog-info.yaml          mkdocs.yml  +  docs/*.md
          |                              |
          v                              v
    Backstage catalog <--- resuelve ---> TechDocs backend
          |                              |
          |                              v
          +---> EntityPage/TechDocs <-- HTML renderizado
```

El punto no-obvio: `catalog-info.yaml` **no incluye** las docs; solo las **apunta**. Si cambias un `.md`, el commit es sobre el repo del servicio; Backstage las re-ingesta en el próximo refresh (periódico o por webhook).

## 3. In-situ vs centralized: el único trade-off que importa

TechDocs tiene **dos modos de operación**. Entenderlos es el 80 % del módulo.

### 3.1 In-situ (a.k.a. "basic" / "docker generator")

Backstage, en tiempo de request, **clona** el repo (o lee el working tree) y **ejecuta `mkdocs build`** (dentro de un contenedor Docker o en el host) para servir el HTML.

- **Pros:** sin pipeline. Un dev edita `docs/foo.md`, hace commit, y en el próximo refresh ya se ve.
- **Contras devastadores a escala:** cada visita al tab TechDocs puede provocar un build (hay caché, pero se invalida); 500 Components × varios devs = Backstage ahogado; además, instalar Docker en el pod de Backstage o shellarte a `mkdocs` genera superficie de ataque y variabilidad de entorno (plugins MkDocs instalados ad-hoc).

**Verdicto:** usar **solo** en entornos de desarrollo o POCs. Documentado en la propia docs oficial como "no recomendado para prod".

### 3.2 Centralized (a.k.a. "recommended" / "external storage")

Un **builder job** (GitHub Actions, GitLab CI, Argo Workflows, Jenkins…) corre en el pipeline del repo del servicio:

```
techdocs-cli generate              # mkdocs build dentro de un contenedor pinned
techdocs-cli publish \
    --publisher-type awsS3 \
    --storage-name my-techdocs-bucket \
    --entity default/component/<name>
```

El resultado (HTML + JSON de metadata) va a un **bucket externo** (S3 / GCS / Azure Blob). Backstage, en modo `techdocs.builder: external`, **no genera nada**: solo **lee** el bucket y lo sirve.

- **Pros:** Backstage se vuelve stateless-ish respecto a docs; el bucket es la fuente de verdad; el pipeline es auditable (artefacto por commit); se puede firmar/cachear/scoutear como cualquier otro artefacto.
- **Contras:** cada repo necesita pipeline (plantilla); hay un lag entre merge y publish (minutos); hay que gestionar credenciales al bucket.

**Verdicto:** modo por defecto en producción. El coste de pipeline se amortiza con una **template Backstage** (ver `plat-06`) que lo scaffolds por ti.

### 3.3 Resumen operativo

| | in-situ | centralized |
|---|---------|-------------|
| Quién corre `mkdocs build` | Backstage (en request) | CI del repo (en push) |
| Latencia doc→view | Segundos | Minutos (CI pipeline) |
| Carga sobre Backstage | Alta | Mínima |
| Escala a 500+ repos | No | Sí |
| Gestión de credenciales cloud | No | Sí (OIDC preferido) |
| Modo recomendado para | Dev / POC | Prod |

## 4. Pipeline CI de publicación

Un pipeline mínimo (pseudo-GitHub Actions):

```yaml
name: techdocs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'
      - 'catalog-info.yaml'

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write       # OIDC federado hacia AWS
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/techdocs-publisher
          aws-region: us-east-1
      - name: Install techdocs-cli + MkDocs
        run: |
          npm install -g @techdocs/cli
          pip install mkdocs mkdocs-techdocs-core
      - name: Generate
        run: techdocs-cli generate --no-docker --verbose
      - name: Publish
        run: |
          techdocs-cli publish \
            --publisher-type awsS3 \
            --storage-name "$TECHDOCS_BUCKET" \
            --entity "default/component/${{ github.event.repository.name }}"
        env:
          TECHDOCS_BUCKET: platform-techdocs-prod
```

Puntos no-obvios:

- **`--no-docker`**: dentro de Actions ya estás en un runner Linux con Python; invocar Docker-in-Docker añade complejidad.
- **OIDC federado > access keys**: siguiendo lo aprendido en el curso de GitHub Actions, el rol se asume por federación (`id-token: write`), no se maneja ningún secret rotable.
- **`paths:` filter**: solo re-publica si cambiaron docs o config; no vale la pena re-generar por un cambio de código.
- **Lifecycle del bucket**: `s3:PutObject` con `--acl bucket-owner-full-control` + versioning encendido; sin lifecycle rule a glaciar (las docs se consultan todo el tiempo).

## 5. app-config.yaml de Backstage

Para activar modo centralized:

```yaml
techdocs:
  builder: external
  generator:
    runIn: local            # irrelevante en external, pero debe estar
  publisher:
    type: awsS3
    awsS3:
      bucketName: platform-techdocs-prod
      region: us-east-1
      # Credenciales por IRSA en EKS, por workload identity en GKE,
      # o por chain default (SDK) si corres el backend en EC2 con instance profile.
```

Para GCS: `publisher.type: googleGcs`. Para Azure: `publisher.type: azureBlobStorage`. La API es consistente — misma `techdocs-cli`, mismo `app-config` structure.

## 6. Plugins MkDocs útiles (y los que no)

El bundle oficial **`mkdocs-techdocs-core`** ya incluye:

- `pymdown-extensions` (admonitions, tabs, superfences, task lists, codehilite).
- `mkdocs-mermaid2-plugin` (diagramas Mermaid inline con triple-backtick ` ```mermaid`).
- Material theme pre-configurado con el *look* Backstage.

Plugins puntuales que vale la pena añadir:

- **`mkdocs-render-swagger-plugin`** — renderiza un `openapi.yaml` como Swagger UI dentro de la página.
- **`mkdocs-git-revision-date-localized-plugin`** — pie de página "última modificación: hace 3 días" sacado del commit log.
- **`mkdocs-awesome-pages-plugin`** — permite controlar `nav` con archivos `.pages` por carpeta (útil si `nav` se vuelve enorme).

**Lo que no vale la pena** (y aparece siempre en PRs iniciales):

- Theme personalizado distinto de Material. Rompe la coherencia visual con el resto de TechDocs del portal; además el bundle oficial pinnéa versiones compatibles.
- Plugins que requieren invocar binarios externos (p. ej. Graphviz) sin containerizar el builder. Explotan diferente en local vs CI.

## 7. UX dentro de Backstage

Una vez publicadas, las docs aparecen:

- **Como pestaña del EntityPage** del Component: `/catalog/default/component/<name>/docs`.
- **En la sección global TechDocs** (`/docs`), navegable como un portal entero.
- **Búsqueda full-text** si el plugin `@backstage/plugin-techdocs-backend` tiene configurado un search collator (indexa HTML renderizado). Clave para que las docs sean *descubribles* sin saber el nombre del Component.

Versioning: por default se publica una sola versión (main). Para publicar "latest" + "v1.2", se puede usar un path prefix por version en el bucket y navegar explícitamente — Backstage no gestiona versioning out-of-the-box, hay que decidir una convención del equipo plataforma.

## 8. Estándar mínimo de docs por servicio

Un estándar que funciona empíricamente para servicios de dominio típico:

| Artefacto | Ubicación | Rol |
|-----------|-----------|-----|
| **README / index** | `docs/index.md` | Qué hace, para quién, link al runbook y al oncall. |
| **ADRs** | `docs/adr/NNNN-titulo.md` | Decisiones arquitectónicas con fecha y status. |
| **Runbook** | `docs/runbook/*.md` | Procedimientos operativos: deploy, rollback, incident response. |
| **API ref** | `docs/api/*.md` (+ `openapi.yaml`) | Autogen desde el contract. |
| **Contactos** | `docs/contact.md` | Owner team, canal Slack, oncall, PagerDuty. |
| **SLOs** | `docs/slo.md` | SLIs + objetivos + ventana. |

El estándar debe venir en forma de **ADR del equipo plataforma** (ver actividad 02): define *qué* se exige, *desde cuándo*, *cómo* se mide la adopción (scorecard — ver `plat-10`), y *qué* pasa si un servicio no cumple (soft fail en PR, warning en catálogo, pero no bloqueo salvo para servicios "gold").

## 9. Autogen de API docs

Para APIs REST con OpenAPI:

```yaml
# mkdocs.yml
plugins:
  - techdocs-core
  - render_swagger

nav:
  - Home: index.md
  - API: api/openapi.md
```

```markdown
<!-- docs/api/openapi.md -->
# API reference

!!swagger openapi.yaml!!
```

El plugin `mkdocs-render-swagger-plugin` resuelve ese shortcode y embebe Swagger UI apuntando al `openapi.yaml` que vive en `docs/api/`. Mismo patrón para AsyncAPI (plugin equivalente, o render estático a HTML y embed por iframe).

## 10. Antipatterns

- **Wiki paralelo "oficial".** Confluence como "fuente de verdad" + docs-as-code "opcional". Resultado: tres fuentes contradictorias. Decide **una** y migra o retira las demás. Dejar Confluence solo para notas de reunión, no documentación técnica.
- **README monolítico de 2000 líneas.** Es 10 docs mal cosidas. Partir en `docs/{index,setup,architecture,runbook,contributing}.md`.
- **Docs sin owner.** Si CODEOWNERS no incluye `docs/`, cualquiera mergea; nadie es responsable. Fix: `/docs @org/team-foo` en CODEOWNERS del repo.
- **Docs que no se publican en CI.** Build local funciona, build en CI (strict mode, link check) descubre `index.md` que linka a `setup.md` que no existe. Añadir `mkdocs build --strict` como job obligatorio.
- **Docs en un repo central "`/platform-docs`".** Al principio parece ordenado, luego nadie del equipo producto tiene incentivo a abrir PR al repo plataforma para documentar algo "suyo". El modelo "owned by service" gana en el 90 % de los casos.

## Resumen

TechDocs convierte Markdown en el repo del servicio en un portal navegable, buscable y confiable. El modo centralized (CI publica a bucket, Backstage solo lee) es el único que escala. El trabajo real no es el tooling — es el **ownership** y el **estándar mínimo**. Un repo con `docs/{index,adr,runbook,api}.md` actualizados en cada PR es mejor que un Confluence con 400 páginas que nadie lee.
