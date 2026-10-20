# TEMPLATE — plat-06-01-build-microservice-template

> Una **referencia** razonada: una forma válida de resolver la actividad. No es la única.

## Decisiones de diseño

### `template.yaml`

- **Tres grupos de `parameters`**: *identidad* (lo que define el servicio), *deployment target* (dónde corre) y *options* (toggles). Agrupar reduce la carga cognitiva del formulario.
- **`pattern` en `name`**: `^[a-z][a-z0-9-]{2,30}$`. Longitud 3–31, kebab-case puro. Barato, imposible meter espacios o mayúsculas.
- **`enum` en `environment`**: `[dev, staging, prod]`. Elimina clases enteras de bugs ("prd" vs "prod").
- **`minimum/maximum` en `replicas`**: evita que un developer meta `replicas: 500` sin querer.
- **`OwnerPicker`** en `owner`: UI widget nativo de Backstage que lee del catálogo.
- **Step condicional** `dropTechDocs` con `if: ${{ parameters.enableTechDocs == false }}`: patrón limpio de opt-out sin duplicar skeleton.
- **`publish:github`** con `repoUrl` sintético — `my-org` es placeholder (en real sería el org real).
- **`catalog:register`** siempre al final: sin él, el repo creado no aparece en el catálogo y el servicio es "huérfano" desde el día uno.
- **`output.links` con dos entradas**: el repo (para seguir trabajando) y el catálogo (para ver la ficha oficial).

### Skeleton

- **Directorio del paquete Python** usa `{{ values.name | replace('-', '_') }}` para convertir kebab-case a snake_case (los guiones son inválidos en identificadores de Python).
- **`catalog-info.yaml`** incluye `backstage.io/techdocs-ref: dir:.` para que TechDocs encuentre el `mkdocs.yml` sin configuración extra.
- **`chart/values.yaml`** parametriza `replicaCount` y `environment` — todo lo demás es fijo porque es parte del *contrato de inicio*.
- **`docs/index.md` + `mkdocs.yml`** mínimos para que TechDocs no se queje; el usuario los enriquece después.

## Qué dejé fuera a propósito

- `Dockerfile` — para esta actividad no suma y alarga el starter. En producción, obligatorio.
- Argo Application YAML — también para evitar inflar; mencionado en el ejemplo 03.
- Custom actions — innecesario a este nivel; sólo introducirían deuda de mantenimiento.

## Autoevaluación

Compara tu solución con esta referencia respondiendo:

1. ¿Tu schema de `name` es tan estricto como el mío (pattern + maxLength implícito)? Si no, ¿por qué?
2. ¿Tu `publish:github` referencia variables (`${{ parameters.name }}`) o tiene hardcode? Si hardcode, ¿con qué justificación?
3. ¿Tus `output.links` dan al usuario *dónde seguir*? Alguien que termina el wizard, ¿sabe en 1 clic adónde ir?
4. ¿Agrupaste los `parameters` en secciones o pusiste todo en una? ¿Por qué?

## Fuentes

- `theory/lesson.md` §2 y §3.
- `examples/01-template-skeleton/` y `examples/03-end-to-end-microservice-template/`.
