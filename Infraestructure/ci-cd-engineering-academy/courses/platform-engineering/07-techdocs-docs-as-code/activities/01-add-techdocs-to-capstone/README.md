# Actividad 01 — Añadir TechDocs al capstone

## 1. Identificación

- **ID:** `plat-07-01-add-techdocs-to-capstone`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-07-techdocs-docs-as-code`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a añadir el sitio TechDocs del capstone (un microservicio Python ficticio llamado `checkout-service`). Al final tendrás:

- Un **sitio MkDocs** con 4 páginas obligatorias (`index`, un ADR, un runbook, una API ref).
- Un **`catalog-info.yaml`** con la anotación `backstage.io/techdocs-ref` que conecta el entity con el sitio.
- Un **`mkdocs.yml`** usando el bundle `mkdocs-techdocs-core`.
- Un **pipeline CI** (`.github/workflows/techdocs.yml`) que publica a S3 en modo centralized (walkthrough — no se ejecuta).

El validador comprueba la **estructura**: existencia de archivos, anotación presente, bundle `techdocs-core` referenciado, pipeline con las piezas clave. Si tienes `mkdocs` instalado, además intenta `mkdocs build --strict`. Si no está, lo omite con un SKIP explícito.

## 3. Objetivos

- Crear el esqueleto MkDocs mínimo defendible para un servicio.
- Entender qué anotación conecta `catalog-info.yaml` con el sitio y qué valores admite.
- Diseñar el pipeline CI que publica a S3 con OIDC federado (walkthrough).
- Distinguir in-situ (dev) vs centralized (prod).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md`.
- Haber recorrido los 3 `examples/` del módulo.
- Haber completado `plat-04` y `plat-05`.
- Herramientas: `bash`, editor Markdown. **Opcional:** `pip install mkdocs mkdocs-techdocs-core` para probar `mkdocs build --strict` localmente.

**Costos:** 0. No se publica a ningún bucket real.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/plat-07-techdocs
cd /tmp/plat-07-techdocs
```

Puedes usar otro directorio pero debes pasarlo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Estructura esperada

```
/tmp/plat-07-techdocs/
├── mkdocs.yml
├── catalog-info.yaml
├── docs/
│   ├── index.md
│   ├── adr/0001-adopt-techdocs.md
│   ├── runbook/deploy-and-rollback.md
│   └── api/reference.md
└── .github/
    └── workflows/
        └── techdocs.yml
```

Hay un **starter** en `starter/` con una plantilla mínima que puedes copiar como punto de partida. Comparte con `solution/` la **estructura** pero no el contenido completo.

### 5.3 Requisitos del `mkdocs.yml`

- Debe tener `site_name` (cualquier string no vacío).
- Debe listar `techdocs-core` en `plugins`.
- Debe declarar un `nav` con al menos las 4 páginas (index, un ADR, un runbook, una API ref).

### 5.4 Requisitos del `catalog-info.yaml`

- `apiVersion: backstage.io/v1alpha1`.
- `kind: Component`.
- `metadata.name: checkout-service` (o similar; obligatorio tener alguno).
- `metadata.annotations.backstage.io/techdocs-ref` presente con valor `dir:.` o `dir:<subcarpeta>`.
- `spec.owner`, `spec.lifecycle` presentes.

### 5.5 Requisitos de los `.md` dentro de `docs/`

Cada uno debe:

- Tener un `# Título` nivel 1.
- Tener al menos 3 líneas de contenido más allá del título (no un stub vacío).

El ADR además debe contener las palabras clave **Context**, **Decision** y **Consequences** (en inglés o español — ver regex del validador).

El runbook debe contener alguna de: **Diagnóstico**, **Mitigación**, **Escalación**, **Rollback** o sus equivalentes en inglés.

### 5.6 Requisitos del pipeline `.github/workflows/techdocs.yml`

- Debe mencionar `techdocs-cli` (el publicador oficial).
- Debe mencionar `publish` (el subcomando).
- Debe mencionar `awsS3` o `googleGcs` o `azureBlobStorage` (el publisher-type).
- Debe mencionar `id-token: write` o `OIDC` (preferencia por federación sobre long-lived keys).
- Debe tener un trigger `on: push` o `workflow_dispatch`.

### 5.7 Validación

```bash
bash <ruta-repo>/courses/platform-engineering/07-techdocs-docs-as-code/activities/01-add-techdocs-to-capstone/tests/validate.sh /tmp/plat-07-techdocs
```

Si `mkdocs` está instalado, el validador además intenta `mkdocs build --strict` y falla si hay links rotos. Si no, salta ese check con un SKIP visible.

## 6. Resultado esperado

- Validador estructural en verde.
- (Opcional) `mkdocs build --strict` también en verde si `mkdocs` está disponible.
- Puedes articular, de memoria, qué hace la anotación `backstage.io/techdocs-ref` y por qué `builder: external` escala y `basic` no.

## 7. Criterios de aceptación

- **Funcionalidad:** validador estructural pasa; opcional strict build pasa.
- **Calidad:** cada doc tiene contenido mínimo defendible; el ADR respeta el formato context/decision/consequences.
- **Reproducibilidad:** otra persona puede clonar `/tmp/plat-07-techdocs` y correr `mkdocs serve` sin tocar nada más.
- **Mantenibilidad:** `nav` del `mkdocs.yml` refleja la estructura del `docs/` sin huérfanos ni links rotos.

## 8. Preguntas de reflexión

1. ¿Por qué el pipeline CI filtra por `paths: ['docs/**', 'mkdocs.yml', 'catalog-info.yaml']`? ¿Qué consecuencia tendría quitar el filter?
2. Si cambias `backstage.io/techdocs-ref` de `dir:.` a `dir:docs-site`, ¿qué más tienes que mover?
3. ¿Qué pasa si tu `nav` del `mkdocs.yml` apunta a un `.md` que no existe y haces `mkdocs build` **sin** `--strict`?
4. ¿Qué ventaja da OIDC federado sobre `AWS_ACCESS_KEY_ID` en el pipeline?
5. ¿Por qué el modo in-situ no escala a 500 Components aunque la máquina de Backstage sea grande?

## 9. Extensiones

- Añade un `openapi.yaml` real en `docs/api/` y el shortcode `!!swagger openapi.yaml!!` (requiere `mkdocs-render-swagger-plugin`).
- Añade `mkdocs-git-revision-date-localized-plugin` para mostrar "última modificación" por página.
- Escribe un segundo ADR (0002) decidiendo el publisher cloud (AWS S3 vs GCS vs Azure) con justificación por tu organización ficticia.

## 10. Limpieza

```bash
rm -rf /tmp/plat-07-techdocs
```

No hay procesos ni contenedores que detener.
