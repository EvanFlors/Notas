# Actividad 01 — Construir el template "nuevo microservicio Python"

## 1. Identificación

- **ID:** `plat-06-01-build-microservice-template`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-06-templates-and-scaffolder`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** mini-project (independiente de la actividad 02)

## 2. Contexto

Vas a construir el template "nuevo microservicio Python" que, en teoría, un desarrollador abrirá desde Backstage, rellenará un formulario de 3 campos y obtendrá un repo con FastAPI, GHA, Helm chart, `catalog-info.yaml` y TechDocs skeleton.

Esta actividad **no requiere Backstage corriendo**: se valida la **estructura** del `template.yaml` (schema de parámetros, steps canónicos, output.links) y la del skeleton (archivos esperados, placeholders nunjucks presentes). Si tienes `cookiecutter` instalado, el validador además renderiza el skeleton localmente con una `cookiecutter.json` análoga que tú también produces, para probar que los placeholders son coherentes.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar un `parameters` con JSON Schema estricto: `required`, `pattern`, `enum`, `minimum/maximum`.
- Encadenar `fetch:template → publish:github → catalog:register`.
- Añadir un step condicional (`if: ${{ parameters.X == false }}`).
- Modelar un skeleton con placeholders nunjucks que renderice correctamente.
- Entregar un paquete reproducible y verificable.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` y los tres `examples/`.
- Herramientas: `bash`, `python3`, un editor. Opcional (recomendado): `pip install cookiecutter`.
- Costos: ninguno. No se crean repos remotos ni se consumen credenciales.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-06-build
cp -r <ruta-repo>/courses/platform-engineering/06-templates-and-scaffolder/activities/01-build-microservice-template/starter/* /tmp/plat-06-build/
cd /tmp/plat-06-build
```

Puedes trabajar en otra ruta, pero pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Completa `template.yaml`

El starter trae un esqueleto con TODOs. Debes:

1. **`metadata.name`**: `python-microservice`.
2. **`parameters`**: al menos tres grupos (`title`), y al menos cinco propiedades totales, incluyendo:
   - `name` con `pattern: '^[a-z][a-z0-9-]{2,30}$'`.
   - `description` con `maxLength`.
   - `owner` (tipo string).
   - `environment` con `enum: [dev, staging, prod]`.
   - `replicas` tipo `integer` con `minimum: 1` y `maximum`.
   - `enableTechDocs` tipo `boolean` con `default: true`.
3. **`steps`**: al menos cuatro:
   - `fetch:template` con `url: ./skeleton` y los `values` relevantes.
   - `fs:delete` con `if:` para dropear TechDocs si `enableTechDocs == false`.
   - `publish:github` (puede tener `repoUrl` ficticio tipo `github.com?repo=...&owner=my-org`).
   - `catalog:register` referenciando `/catalog-info.yaml`.
4. **`output.links`**: al menos dos.

### 5.3 Completa `skeleton/`

El starter trae `skeleton/` con placeholders a rellenar. Debes dejar:

- `skeleton/catalog-info.yaml` con `${{ values.name }}`, `${{ values.description }}` y `${{ values.owner }}`.
- `skeleton/README.md` con `${{ values.name }}` en el título.
- `skeleton/pyproject.toml` con `name = "${{ values.name }}"`.
- `skeleton/src/{{ values.name | replace('-', '_') }}/app.py` con el `${{ values.name }}` en el título del FastAPI.
- `skeleton/chart/values.yaml` con `replicas: ${{ values.replicas }}` y `environment: ${{ values.environment }}`.
- `skeleton/docs/index.md` (contenido mínimo con `${{ values.name }}`).
- `skeleton/mkdocs.yml` (site_name: `${{ values.name }}`).

### 5.4 (Opcional) Prueba local con cookiecutter

Crea `cookiecutter.json` en la raíz de tu paquete:

```json
{
  "name": "orders-api",
  "description": "Sample",
  "owner": "group:platform-team",
  "environment": "dev",
  "replicas": 2
}
```

Y un dir `cookiecutter-skeleton/{{cookiecutter.name}}/` con los **mismos** archivos del skeleton pero usando sintaxis Jinja2 (`{{ cookiecutter.name }}` en vez de `${{ values.name }}`). El validador, si detecta `cookiecutter` instalado, ejecutará el render y verificará que el output se produce sin error.

Si no quieres hacer la parte cookiecutter, basta: el validador lo marcará como `SKIP` y seguirá verde.

### 5.5 Entregable

```
/tmp/plat-06-build/
├── template.yaml
├── skeleton/
│   ├── catalog-info.yaml
│   ├── README.md
│   ├── pyproject.toml
│   ├── src/{{ values.name | replace('-', '_') }}/app.py
│   ├── chart/values.yaml
│   ├── docs/index.md
│   └── mkdocs.yml
└── (opcional) cookiecutter.json + cookiecutter-skeleton/
```

## 6. Resultado esperado

- `template.yaml` cumple la estructura mínima (schema parameters, steps canónicos, output.links).
- Skeleton presenta todos los archivos esperados y usa placeholders `${{ values.* }}`.
- `bash tests/validate.sh /tmp/plat-06-build` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada parámetro tiene schema estricto (no `type: string` solo).
- **Reproducibilidad**: alguien que lea tu paquete puede regenerarlo (actividad 02).
- **Mantenibilidad**: YAML válido, placeholders coherentes entre template y skeleton.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-06-build
```

El validador comprueba estructura, no semántica. Compara con `solution/TEMPLATE.md` para auto-evaluar las decisiones de diseño.

## 9. Preguntas de reflexión

1. ¿Por qué un `pattern` en el schema del parámetro `name` es más barato que una custom action que valide el nombre?
2. ¿Cuándo tendría sentido tener dos templates (`python-rest`, `python-grpc`) en lugar de uno con `if`?
3. ¿Qué pasa si olvidas el step `catalog:register`? ¿Cuándo se nota el problema?
4. ¿Qué información **falta** en tu `output.links` que haría la UX perfecta?
5. Imagina que al upgrade de Backstage, `publish:github` cambia el nombre del output `remoteUrl` a `repositoryUrl`. ¿Cómo lo descubrirías antes de que un developer se queje?

## 10. Extensiones

- Añade un segundo skeleton `skeleton-grpc/` y un step `fetch:template` que elija según un parámetro `transport`.
- Añade un step `publish:github:pull-request` que, además de crear el repo, abra un PR a un repo `argo-apps` con la nueva Application.
- Añade un `catalog-info.yaml` para el **propio template** (kind `Template`).

## 11. Limpieza

```bash
rm -rf /tmp/plat-06-build
```
