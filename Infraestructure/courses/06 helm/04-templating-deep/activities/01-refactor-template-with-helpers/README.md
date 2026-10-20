# helm-04-01 — Refactor: extraer labels y nombres a `_helpers.tpl`

## 1. Identificación
- **ID:** `helm-04-01-refactor-template-with-helpers`
- **Tecnología:** helm
- **Módulo:** 04-templating-deep
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Un chart funcional pero duplicado: `Deployment`, `Service` y `ServiceAccount` repiten literalmente el mismo bloque de labels y el mismo patrón de nombre. Es el estado típico en el que queda un chart después de un `helm create` sin limpieza o después de que varias personas lo editan sin convención compartida.

Tu trabajo: refactorizar a los helpers estándar de Helm sin cambiar el output (semánticamente equivalente).

## 3. Objetivos

- Definir en `templates/_helpers.tpl` los helpers canonicos: `fastapi-app.name`, `fastapi-app.fullname`, `fastapi-app.chart`, `fastapi-app.labels`, `fastapi-app.selectorLabels`, `fastapi-app.serviceAccountName`.
- Reemplazar en los tres recursos la duplicación por `include ... | nindent N`.
- Mantener `spec.selector.matchLabels` acotado al **subset** de `selectorLabels` (immutable).
- Verificar con `helm template` que el output renderiza las labels correctamente en los tres recursos.

## 4. Prerrequisitos

- Helm 3+ instalado (`helm version`).
- Haber leído `theory/lesson.md` §6 y §7.
- Sin cluster: todo se valida con `helm template`.
- Sin costos.

## 5. Instrucciones

1. Copia el starter a `/tmp/`:
   ```bash
   cp -r starter /tmp/refactor-helpers
   cd /tmp/refactor-helpers
   ```
2. Observa el estado inicial: `helm template demo .` ya renderiza; el problema es la **duplicación**, no un error funcional.
3. Crea `templates/_helpers.tpl` definiendo los seis helpers.
4. En `templates/deployment.yaml`, `templates/service.yaml`, `templates/serviceaccount.yaml` reemplaza los bloques literales por `include ... | nindent N`. Mantén las labels completas en `metadata.labels` y el subset selector en `spec.selector.matchLabels` / `spec.template.metadata.labels` (deployment) y `spec.selector` (service).
5. Verifica:
   ```bash
   helm lint .
   helm template demo .
   bash <ruta-al-repo>/activities/01-refactor-template-with-helpers/tests/validate.sh /tmp/refactor-helpers
   ```

## 6. Resultado esperado

- `_helpers.tpl` existe y define los seis helpers.
- `helm lint` pasa.
- `helm template demo .` emite 3 recursos (`Deployment`, `Service`, `ServiceAccount`) con la label `app.kubernetes.io/managed-by: Helm` en todos.
- `spec.selector.matchLabels` del Deployment contiene SOLO `app.kubernetes.io/name` y `app.kubernetes.io/instance` (no versión, no chart).
- El validador imprime `RESULT: 5/5 checks OK`.

## 7. Criterios de aceptación

- **Funcional.** `helm template` renderiza sin error con los valores por default y con `--set replicaCount=3`.
- **Calidad.** `_helpers.tpl` define cada helper una sola vez; los recursos no duplican estructura.
- **Correctitud.** `selectorLabels` es un subset de `labels` y es inmutable (no incluye versión).
- **Reproducibilidad.** El validador pasa 2 ejecuciones consecutivas sobre `/tmp/refactor-helpers`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/refactor-helpers
```

El script hace `helm template demo <dir>` y luego varios `grep` sobre el output y sobre `_helpers.tpl`:

- `_helpers.tpl` define los seis templates.
- `Deployment`, `Service`, `ServiceAccount` presentes en el render.
- Las labels comunes aparecen en los tres recursos.
- `selector.matchLabels` del Deployment NO contiene `app.kubernetes.io/version`.

## 9. Preguntas de reflexión

- ¿Por qué `selectorLabels` NO puede incluir `app.kubernetes.io/version`?
- ¿Qué pasa con los `include ... | nindent N` si cambias `nindent 4` por `nindent 2` por error?
- ¿Qué cambia si usas `template` en vez de `include` sin pipeline?
- Si mañana añades un `HorizontalPodAutoscaler`, ¿cuántas líneas de template nuevas necesitas gracias a `_helpers.tpl`?

## 10. Extensiones

- Añade un helper `fastapi-app.commonAnnotations` que inyecte una `checksum/config` referenciando un `ConfigMap` definido en el chart.
- Añade un helper `fastapi-app.image` que compone `repository:tag` con `required` sobre `.Values.image.repository`.
- Añade `values.schema.json` que marque `image.repository` como `required` (preview del módulo `helm-05`).

## 11. Limpieza

```bash
rm -rf /tmp/refactor-helpers
```
