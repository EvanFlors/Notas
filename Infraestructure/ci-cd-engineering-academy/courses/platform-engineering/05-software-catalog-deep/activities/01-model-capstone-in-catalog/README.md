# Actividad 01 — Modelar el capstone en el Software Catalog

## 1. Identificación

- **ID:** `plat-05-01-model-capstone-in-catalog`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-05-software-catalog-deep`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Diseñaste tu capstone en `plat-02` (golden path) y levantaste Backstage en `plat-04`. Ahora toca lo que diferencia un Backstage **útil** de un Backstage **vacío**: poblar el catálogo con entidades reales, modeladas con relaciones correctas, owners existentes y annotations que no están ahí "para rellenar".

Esta actividad **no** requiere Backstage corriendo. Produces un árbol de `catalog-info.yaml` que valida estructuralmente con `python3` + `pyyaml`. La validación semántica (que las relaciones sean coherentes y las annotations útiles) la haces comparando contra `solution/REFERENCE.md`.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Decidir cuántos y cuáles `Component`, `API`, `Resource`, `System`, `Domain`, `Group` modelas para un sistema de tamaño medio.
- Escribir `catalog-info.yaml` con la metadata obligatoria + 2 annotations útiles por Component.
- Declarar relaciones `providesApis`, `consumesApis`, `dependsOn`, `partOf` sin "relaciones muertas" (apuntando a entidades que no existen).
- Explicar por qué cada relación que declaraste tiene sentido.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2, §3, §4, §6).
- Haber recorrido los 3 `examples/` del módulo.
- Herramientas: `python3` ≥ 3.9 con `pyyaml` instalado (`python3 -c "import yaml"` debe funcionar).

**Costos**: ninguno (todo local, nada de cloud).

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-05-catalog
cd /tmp/plat-05-catalog
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Elegir un capstone (si no tienes uno)

Si ya definiste capstone en `plat-02`, úsalo. Si no, usa este stub para la actividad:

> **`orders` — sistema de órdenes de una tienda online.**
> Componentes previstos: una API HTTP de órdenes (`orders-api`), un worker async que procesa pagos (`payments-worker`), y un servicio de notificaciones por email (`notifications-sender`). Dependen de una base de datos Postgres (`orders-db`) y un bucket S3 (`orders-receipts-bucket`). El sistema `orders` pertenece al domain `commerce`. Equipos: `orders-team` (dueño de orders-api, payments-worker, orders-db) y `comms-team` (dueño de notifications-sender).

### 5.3 Mínimos requeridos

El validador exige, en el árbol que generes:

- **≥ 3 Components** (`kind: Component`).
- **≥ 2 APIs** (`kind: API`).
- **≥ 1 Resource** (`kind: Resource`).
- **≥ 1 System** (`kind: System`).
- **≥ 1 Domain** (`kind: Domain`).
- **≥ 2 Groups** (`kind: Group`).
- Cada Component debe tener `spec.owner` apuntando a un `group:...` que **también** esté declarado como `kind: Group` en algún `catalog-info.yaml` de tu árbol.
- Cada Component debe tener `metadata.annotations` con **≥ 2** claves (sugeridas: `github.com/project-slug`, `backstage.io/techdocs-ref`, `backstage.io/kubernetes-id`).
- Al menos **una** entidad `Component` debe declarar `providesApis` apuntando a un API que **también** exista como `kind: API` en tu árbol.
- Al menos **una** entidad `Component` debe declarar `consumesApis` o `dependsOn` apuntando a algo existente.

### 5.4 Estructura sugerida del árbol

```
/tmp/plat-05-catalog/
├── orders-api/
│   └── catalog-info.yaml      # Component + API (openapi)
├── payments-worker/
│   └── catalog-info.yaml      # Component + API (asyncapi)
├── notifications-sender/
│   └── catalog-info.yaml      # Component
└── platform-catalog/
    └── catalog-info.yaml      # System + Domain + Resources + Groups
```

Puedes usar otra estructura (p. ej. un solo archivo mono) mientras cumplas los mínimos y el YAML sea válido.

### 5.5 Esqueleto para `orders-api/catalog-info.yaml`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  description: HTTP API that creates and queries orders.
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
  system: orders
  providesApis:
    - orders-api-v1
  dependsOn:
    - resource:orders-db
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-api-v1
spec:
  type: openapi
  lifecycle: production
  owner: group:orders-team
  system: orders
  definition: |
    openapi: 3.0.0
    info: { title: Orders API, version: 1.0.0 }
    paths: {}
```

Replica el patrón para los demás servicios. Los `Group`, `Domain`, `System` y `Resource` quedan mejor en `platform-catalog/catalog-info.yaml` (uno solo con separadores `---`).

### 5.6 Entregable

Un árbol de `catalog-info.yaml` bajo `/tmp/plat-05-catalog/` que:

- Satisface los mínimos de §5.3.
- Es YAML sintácticamente válido.
- Pasa `bash tests/validate.sh /tmp/plat-05-catalog`.

## 6. Resultado esperado

- Al menos 4 archivos `catalog-info.yaml` bajo el árbol.
- `python3 -c "import yaml; [list(yaml.safe_load_all(open(p))) for p in __import__('glob').glob('/tmp/plat-05-catalog/**/catalog-info.yaml', recursive=True)]"` no lanza excepción.
- `bash tests/validate.sh /tmp/plat-05-catalog` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa; recuentos por kind cumplen mínimos.
- **Calidad**: cada relación declarada apunta a una entidad existente en el árbol (sin "relaciones muertas").
- **Reproducibilidad**: alguien que lea tus YAMLs puede dibujar el grafo del sistema sin ambigüedad.
- **Mantenibilidad**: YAML válido, convenciones kebab-case, descripciones cortas y humanas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-05-catalog
```

El validador comprueba **estructura** (counts por kind, owners existentes, relaciones a entidades existentes, annotations mínimas), **no** semántica. Compara tu árbol con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué conviene declarar el `System` y el `Domain` en un repo central y no en cada `catalog-info.yaml` de los Components?
2. Si un Component depende de 5 Resources distintos, ¿los declaras todos en `dependsOn` o modelas un "super-resource" agregado? Argumenta.
3. ¿Qué annotation añadirías si quisieras que el plugin de PagerDuty funcione para `orders-api`?
4. Si `notifications-sender` consume un API provisto por `payments-worker`, ¿dónde declararías esa relación?
5. Si tu capstone tiene 10 Components, ¿qué `tags` consistentes definirías para hacer el filtrado útil en la UI?

## 10. Extensiones

- Añade un `User` propio como `memberOf` uno de los Groups.
- Modela un API con `spec.definition: $text: ./openapi.yaml` en vez de inline.
- Marca uno de los Components como `lifecycle: deprecated` y añade un comentario sobre quién lo consume aún.
- Añade un segundo `System` al mismo `Domain` para probar la agregación.
- Dibuja (ASCII, en un `IMPACT.md` opcional) el grafo que tu árbol genera.

## 11. Limpieza

Para empezar de cero:

```bash
rm -rf /tmp/plat-05-catalog
```

No hay procesos ni contenedores que detener.
