# Ejercicio operativo — Examen de certificación Helm

**Duración orientativa:** 45–60 min dentro de los 90–120 min totales del examen.
**Dimensión:** operativa (con solape conceptual).
**Prerrequisito:** `helm` v3.14+ instalado localmente. **No requiere cluster.**

> **SKIP:** Si el binario `helm` no está disponible en el entorno del
> estudiante y no se puede instalar en los próximos ~10 min, el instructor
> debe marcar el ejercicio operativo como **SKIP** y rebalancear el puntaje
> a conceptual (50%) + arquitectónica (50%). Documentar el motivo en la
> hoja de corrección. **No** se compensa con "pseudo-ejecución mental" —
> rompe la objetividad de la rúbrica.

## Materiales

Se entrega un chart `fastapi-app` **deliberadamente roto/incompleto** en
`starter/fastapi-app/`. Es el chart canónico del curso (ver
`courses/helm/ROADMAP.md`, sección "Chart canónico").

## Tareas

Trabajar **solo con `helm template`, `helm lint` y `helm show values`**.
No se requiere cluster. Entregar al final el chart corregido como `.tgz`
(`helm package`) más las salidas pedidas en cada tarea.

### OP-task-1 — Arreglar `_helpers.tpl` (C2, C3)

Completar los helpers que faltan en `templates/_helpers.tpl`
(`fastapi-app.selectorLabels`, `fastapi-app.labels`) con las labels estándar
de Kubernetes (`app.kubernetes.io/name`, `/instance`, `/managed-by`,
`/version`). Explicar en 2–3 líneas por qué `selectorLabels` **no** debe
incluir la versión.

### OP-task-2 — `template` vs `include` (C3)

En `templates/deployment.yaml` hay un uso de `template "fastapi-app.labels"
. | nindent 4` que **no compila**. Corregirlo. Justificar en 1 línea por qué
`include` es la forma correcta.

### OP-task-3 — Diagnosticar y corregir el render (C4)

Correr `helm template fastapi ./starter/fastapi-app -f
./starter/fastapi-app/values-dev.yaml --debug` y:

1. Capturar el error (o YAML inválido) inicial.
2. Enumerar los bugs encontrados en `deployment.yaml` (al menos: whitespace
   en `env`, `image.tag` vacío, host null del ingress).
3. Corregirlos usando `default .Chart.AppVersion .Values.image.tag`,
   el guion `-` para absorber whitespace, y `required`/`if` para
   `ingress.host`.
4. Entregar diff del template y output final renderizado con
   `values-dev.yaml` **y** con `values-prod.yaml`.

### OP-task-4 — `values.schema.json` y precedencia multi-entorno (C5, C12)

Añadir `values.schema.json` en la raíz del chart que exija como mínimo:

- `image.repository` string requerido.
- `replicaCount` integer mínimo 1.
- `service.port` integer entre 1 y 65535.
- `ingress.host` string **o** null (nullable explícito), pero si `enabled`
  (lo definas o no en el schema) requiere `host` no vacío.

Demostrar que falla con un `values` inválido mediante:

```bash
helm lint ./starter/fastapi-app -f ./starter/fastapi-app/values-dev.yaml
helm template fastapi ./starter/fastapi-app --set replicaCount=0  # debe fallar
```

Luego predecir **sin ejecutar** el valor final de `replicaCount` para:

```bash
helm template fastapi ./starter/fastapi-app \
  -f values-dev.yaml -f values-prod.yaml --set replicaCount=7
```

Explicar la regla de precedencia aplicada.

### OP-task-5 — Hook `pre-upgrade` de migración (C7)

Añadir `templates/migration-job.yaml` que:

- Sea un `Job` con `annotations: "helm.sh/hook": pre-upgrade`,
  `"helm.sh/hook-weight": "-5"`,
  `"helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded`.
- Se renderice **solo** si `.Values.migrations.enabled` es true.
- Use la imagen `migrations.image.repository:tag` (fallback a `AppVersion`).
- Tenga `restartPolicy: Never` y `backoffLimit: 1`.

Justificar en 2 líneas por qué `--atomic --wait` es el default correcto
para el `helm upgrade --install` que dispara este hook en CD, y qué
problema evita.

### OP-task-6 — Pipeline local de validación (C9)

Entregar un script `validate.sh` que ejecute en orden y devuelva código
distinto de cero al primer fallo:

```bash
helm lint ./starter/fastapi-app -f ./starter/fastapi-app/values-dev.yaml
helm lint ./starter/fastapi-app -f ./starter/fastapi-app/values-prod.yaml
helm template fastapi ./starter/fastapi-app \
    -f ./starter/fastapi-app/values-dev.yaml > /tmp/render-dev.yaml
helm template fastapi ./starter/fastapi-app \
    -f ./starter/fastapi-app/values-prod.yaml > /tmp/render-prod.yaml
grep -q 'kind: Job'      /tmp/render-prod.yaml   # hook presente en prod
! grep -q 'kind: Job'    /tmp/render-dev.yaml    # hook ausente en dev
grep -q 'tag: ""'        /tmp/render-dev.yaml && exit 1 || true  # no quedó vacío
```

Describir, además, qué **dos capas más** completarían el pipeline fuera del
examen (`helm-unittest`, `ct install` sobre `kind`) y por qué cada capa
atrapa bugs que la anterior no atrapa.

## Entregables

1. Chart corregido empaquetado (`fastapi-app-0.2.0.tgz` vía `helm package`,
   bump de versión obligatorio — explica por qué).
2. `render-dev.yaml` y `render-prod.yaml` renderizados.
3. `values.schema.json`.
4. `validate.sh` que termina con `exit 0`.
5. Notas de ≤ 1 página con las justificaciones pedidas en cada tarea.

## Validación automática del instructor

```bash
helm lint ./entrega/fastapi-app -f ./entrega/fastapi-app/values-dev.yaml
helm lint ./entrega/fastapi-app -f ./entrega/fastapi-app/values-prod.yaml
helm template fastapi ./entrega/fastapi-app \
  -f ./entrega/fastapi-app/values-prod.yaml \
  | yq '[.] | map(select(.kind == "Job")) | length' | grep -q '^1$'
helm template fastapi ./entrega/fastapi-app \
  -f ./entrega/fastapi-app/values-dev.yaml \
  | grep -q 'app.kubernetes.io/version'
```

Ver `../EXAM.md` sección 5 para la rúbrica y sección 6 para la guía de
corrección (red flags, errores comunes, preguntas de seguimiento).
