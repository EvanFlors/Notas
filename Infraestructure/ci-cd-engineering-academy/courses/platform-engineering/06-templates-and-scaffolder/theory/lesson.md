# plat-06 — Lección: Templates y Scaffolder

> 10 secciones. El objetivo no es memorizar la sintaxis — es interiorizar que un template es un **producto de plataforma** con contrato, versión y tests.

---

## 1. Por qué templates: la última milla del golden path

Un *golden path* bien definido (`plat-02`) elimina decisiones triviales. Pero mientras ese golden path viva en un documento Confluence, cada nuevo microservicio se seguirá copiando a mano desde "el servicio parecido" — con la deriva habitual: unos tienen Dockerfile v3, otros v5; unos tienen workflow de GHA con cache, otros no; nadie recuerda qué anotación de `catalog-info.yaml` debía ir.

Un **template de Backstage** es el *golden path* **ejecutable**. En vez de "copia el servicio parecido y adáptalo", el desarrollador abre el IDP, rellena un formulario, y sale un repo con:

- Código inicial del servicio (según el stack elegido).
- CI/CD cableado (GHA, Argo CD Application, etc.).
- Chart Helm o manifiesto K8s.
- `catalog-info.yaml` con owner, system, API provista.
- TechDocs skeleton (`/docs` + `mkdocs.yml`).
- Dashboards y alertas opcionales.

El contrato es: **"si usas este template, obtienes todo lo que tiene un servicio de nivel plata del scorecard"** (ver `plat-10`).

---

## 2. Anatomía de un `template.yaml`

Toda plantilla v1beta3 tiene tres bloques claramente separados:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: python-microservice
  title: New Python Microservice
  description: Scaffolds a FastAPI service with CI, chart and TechDocs
  tags: [python, fastapi, golden-path]
spec:
  owner: group:platform-team
  type: service

  parameters:    # (1) JSON Schema → formulario del wizard
    - title: Service identity
      required: [name, owner]
      properties:
        name:
          type: string
          pattern: '^[a-z][a-z0-9-]{2,30}$'
        owner:
          type: string
          ui:field: OwnerPicker

  steps:         # (2) acciones secuenciales
    - id: fetch
      name: Fetch skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          owner: ${{ parameters.owner }}
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

  output:        # (3) qué devuelve al usuario al terminar
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
```

Puntos a interiorizar:

- `parameters` es **JSON Schema** puro con extensiones `ui:*` para widgets de MUI. Un `pattern` o `enum` en el schema es **gratis** y evita bugs; no renunciar a él.
- `steps` se ejecutan **en orden** y comparten contexto via `${{ steps.<id>.output.<key> }}`.
- `output` es sólo UI (links y entity refs); no afecta a lo creado.

---

## 3. Scaffolder actions built-in — las que vas a usar siempre

| Acción | Qué hace | Cuándo |
|--------|----------|--------|
| `fetch:template` | Descarga un skeleton (local o git), renderiza nunjucks, lo deja en el workspace. | Siempre. Primer step casi obligado. |
| `fetch:plain` | Descarga sin interpolar. | Para traer binarios o configs que no son plantillas. |
| `fs:rename` | Renombra archivos del workspace. | Cuando el nombre depende de un parámetro (p. ej. `app-{{ name }}.py`). |
| `fs:delete` | Borra archivos del workspace. | Para variantes condicionales ("si no eliges K8s, borra el chart"). |
| `publish:github` | Crea el repo en GitHub y hace push. | Para equipos en GitHub. Existe también `publish:gitlab`, `publish:bitbucket`. |
| `publish:github:pull-request` | Abre un PR en lugar de crear repo. | Útil para templates que **modifican** un repo existente. |
| `catalog:register` | Registra la `Location` del nuevo repo para que el catalog lo ingiera. | Siempre tras `publish:*`. |
| `debug:log` | Imprime datos en la UI del scaffolder. | Para debug durante desarrollo del template. |

> **Regla de oro:** una custom action en TypeScript sólo se escribe cuando necesitas hablar con un sistema que **ninguna** built-in cubre (p. ej. un Jira interno, un ServiceNow). Para "renombrar un archivo" o "borrar un dir", **nunca** una custom action.

---

## 4. El skeleton y nunjucks

El skeleton es un directorio de archivos **que pueden** contener expresiones nunjucks:

```
skeleton/
├── catalog-info.yaml
├── pyproject.toml
├── README.md
├── src/
│   └── {{ values.name }}/
│       └── app.py
└── .github/
    └── workflows/
        └── ci.yaml
```

Dentro de los archivos, los placeholders usan `${{ values.name }}`:

```yaml
# skeleton/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description }}
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
```

Filtros útiles (los que vas a tocar el primer día):

- `${{ values.name | lower }}` — normalización.
- `${{ values.name | replace('-', '_') }}` — snake_case para paquetes Python.
- `${{ values.repoUrl | parseRepoUrl | pick('host') }}` — descomponer la URL.

**Trampa clásica:** si el archivo del skeleton tiene extensión que algún procesador trata (p. ej. un `.yaml` del propio Backstage), hay que renombrar la fuente a `.yaml.njk` o similar para evitar colisiones. En este curso usamos la convención simple de que **todo** el skeleton es interpretado como nunjucks (el default).

---

## 5. Patrones de composición

Un template puede quedarse "mega" rápidamente: parámetros infinitos, 20 steps, tres condicionales anidados. Antipatron.

Patrones mejores:

1. **Un template por golden path**. "Microservicio Python" y "Librería Python" son dos templates, no uno con `if`.
2. **Skeleton por variante**. Dentro de un template, si hay dos variantes pequeñas (p. ej. REST vs gRPC), dos subdirectorios `skeleton-rest/` y `skeleton-grpc/` y un step `fetch:template` que elige en base a un parámetro.
3. **Composición por chained templates**. Un template "nuevo servicio" puede invocar implícitamente otro template "DB para servicio" (`plat-09`) a través de un paso que llama a un workflow de Argo o abre un PR al repo de infra.
4. **Opt-outs explícitos**. Mejor "¿quieres TechDocs? (sí/no)" por default `sí`, y `fs:delete` del dir si eligen `no`, que mantener dos skeletons.

---

## 6. Templates como producto — versionado, tests y update

Un template es código. Código sin tests se pudre:

- **Versionado**. `metadata.name` + un tag git. El `catalog-info.yaml` generado puede inscribir `backstage.io/template-ref: python-microservice@v3`.
- **Fixture de referencia**. En el repo del template, un dir `fixture/` con el output de referencia (resultado de ejecutar el template con valores canónicos). CI regenera y hace `git diff` — si cambia, el PR del template debe revisarlo.
- **CI del template**. Un workflow que: (a) ejecuta el scaffolder en modo "dry-run" o invoca localmente la render de nunjucks + checks estructurales; (b) regenera la fixture y falla si diverge; (c) corre `yamllint`/`shellcheck`/`hadolint` sobre el output.
- **`update-from-template`**. Comando (en el propio repo generado) que re-descarga el template y abre un PR con los diffs. Alternativa comunitaria: [`backstage-cli template:lint`], o scripts hechos a medida.

Este módulo entrena directamente los puntos **fixture + CI** en la actividad `02-test-template-in-ci`.

---

## 7. Cookiecutter como análogo local

Si no tienes Backstage corriendo (habitual en un entorno de curso), **cookiecutter** cumple un rol equivalente a `fetch:template` + nunjucks: toma un skeleton, pregunta valores y renderiza. La sintaxis es Jinja2, no nunjucks, pero las propiedades son isomorfas:

| Backstage scaffolder | Cookiecutter |
|----------------------|--------------|
| `template.yaml → parameters` | `cookiecutter.json` |
| `skeleton/` | `{{cookiecutter.project_slug}}/` |
| `${{ values.name }}` | `{{ cookiecutter.name }}` |
| `fetch:template` | `cookiecutter` CLI |

Usamos cookiecutter en los validadores de este curso como **smoke test ejecutable** cuando está disponible; si no, los validadores se limitan a chequear estructura del `template.yaml` + skeleton (y lo dicen explícitamente con un `SKIP`).

---

## 8. Antipatterns

- **Parámetros sin schema.** `type: string` sin `pattern`, sin `enum`, sin `maxLength`. El usuario mete lo que quiere y el template explota en el step 4.
- **Template que depende de 7 custom actions internas.** El coste de mantenimiento se dispara en cada upgrade de Backstage.
- **No tests.** El template se escribió en 2023 y nadie se ha atrevido a actualizarlo desde entonces.
- **Hardcode de owner/system/cluster.** El template es útil sólo para ese un equipo que lo escribió.
- **Repos "huérfanos".** El template crea el repo pero olvida `catalog:register`; a los seis meses hay 40 servicios sin owner en el catálogo.
- **No `output.links`.** El usuario rellena el form, ve "OK" y no sabe adónde ir. UX pésima.

---

## 9. Checklist mínimo del template productivo

Antes de publicar un template nuevo:

- [ ] `parameters` con JSON Schema estricto (required, pattern, enum donde aplique).
- [ ] Al menos un step `fetch:template`, uno `publish:*` y uno `catalog:register`.
- [ ] `output.links` con el repo y el entity del catalog.
- [ ] Fixture de referencia regenerable.
- [ ] CI del template verde: regenerate + diff clean, yamllint output.
- [ ] README en el repo del template con: inputs, output esperado, qué hacer para actualizarlo.
- [ ] Un `catalog-info.yaml` propio para el **repo del template** (sí, los templates también son componentes de catálogo, kind `Template`).
- [ ] Un owner responsable.

---

## 10. Hilo con el resto del curso

- **`plat-02`** definió el *golden path*; este módulo lo **cristaliza** en un artefacto ejecutable.
- **`plat-05`** modeló el catálogo; el template **puebla** ese catálogo automáticamente.
- **`plat-07`** añade TechDocs al template.
- **`plat-09`** usa templates para exponer self-service de infra (via Crossplane claims o PRs a repos TF).
- **`plat-10`** mide **cuántos** servicios usan el template y qué nivel de scorecard tienen — ahí es donde se nota si el template cumplió su promesa o no.

> **Idea para llevarse a casa.** Un template no es "un generador". Es el **contrato de inicio** del golden path. Después del scaffolding el repo evoluciona independiente — pero empezó con todo lo que tu plataforma considera "nivel mínimo", y existe un camino para re-bajar mejoras del template original. Esa es la diferencia entre un IDP real y una colección de scripts.
