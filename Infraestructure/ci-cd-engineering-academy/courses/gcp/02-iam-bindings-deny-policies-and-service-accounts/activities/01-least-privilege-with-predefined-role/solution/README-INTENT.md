# REFERENCE — gcp-02-01-least-privilege-with-predefined-role

Esta es la **solución de referencia**. Compara con tu entrega — pueden existir
soluciones igualmente válidas con roles ligeramente distintos. El criterio
cualitativo es: **minimo privilegio con roles predefinidos**.

## iam-bindings — justificación

### 1. `roles/storage.objectViewer` sobre `gs://acme-prod-receipts-raw`

- **Permisos atómicos relevantes incluidos**: `storage.objects.get`, `storage.objects.list`.
- **Por qué no `roles/storage.objectUser`**: `objectUser` incluye `storage.objects.create`, `.delete`, `.update`. El workload **no** necesita escribir en el bucket raw, así que concederlo es un vector de abuso si la SA se compromete.
- **Por qué no `roles/storage.admin`**: adicionalmente incluye `buckets.*` — borrar el bucket, cambiar su IAM, etc. Enorme.
- **Por qué no `roles/viewer` (basic)**: `roles/viewer` concede lectura en **todos** los servicios habilitados en el project (BigQuery, Compute, Secret Manager — todo). El workload no necesita leer nada fuera de ese bucket.

### 2. `roles/storage.objectCreator` sobre `gs://acme-prod-receipts-processed`

- **Permisos atómicos relevantes**: `storage.objects.create`.
- **Por qué no `roles/storage.objectUser`**: `objectUser` **sí** cubriría el caso, pero incluye `objects.delete` y `objects.update`. Si el pipeline debe ser *append-only* (y por diseño del escenario lo es — procesamos y guardamos, no re-escribimos), `objectCreator` es más estricto.
- **Trade-off real**: si el pipeline necesita **sobrescribir** la versión antigua con la nueva, usar `objectCreator` **falla** (no permite overwrite). En ese caso, `objectUser` es correcto. Documenta explícitamente la elección.
- **Por qué no `roles/editor` (basic)**: concedería permisos en todos los servicios del project. Grotesco.

### 3. `roles/pubsub.publisher` sobre `projects/acme-prod/topics/receipts-events`

- **Permiso atómico**: `pubsub.topics.publish`.
- **Por qué no `roles/pubsub.editor`**: `editor` permite crear/borrar topics y subscriptions, cambiar IAM del topic, etc. El workload solo publica.
- **Por qué no en el project entero sino en el topic concreto**: dar el binding en el project daría publisher a **todos** los topics, incluidos ones nuevos creados en el futuro. Nivel más bajo = scope más estrecho.

### Por qué **ningún** basic role

Los basic roles (`roles/owner`, `roles/editor`, `roles/viewer`) conceden entre cientos y miles de permisos atómicos cruzando todos los servicios habilitados en el project. En producción, no hay escenario donde un workload necesite todos esos permisos. En auditoría, no se puede justificar "mi app necesita `editor`" — siempre hay un conjunto de predefineds más estrecho.

## deny-policy — intención

### Qué veta

- `storage.googleapis.com/buckets.delete` — borrar un bucket.
- `storage.googleapis.com/buckets.setIamPolicy` — reemplazar la allow policy del bucket (vector de escalada: si puedes cambiar la IAM, te concedes `storage.admin`).

### A quién

- **Deniega**: `principalSet://goog/public:all` → **todos** los principals.
- **Excepción**: `principalSet://goog/group/break-glass-storage@acme.io` → el grupo de emergencia (2–3 personas, con MFA fresca, con alerta en Slack cada vez que lo usan).

### Por qué `principalSet://goog/public:all`

Es el idiom estándar para "todos" en deny policies. Si solo denegamos a un grupo concreto, cualquiera **fuera** de ese grupo (incluyendo nuevas SAs o nuevos humanos) puede borrar. Negar universalmente + exceptuar es el patrón defensivo correcto.

### Por qué break-glass

- Un error humano puede requerir legítimamente borrar un bucket (p. ej., bucket mal nombrado creado por accidente). Si el break-glass no existe, hay que **desactivar la policy** → cambio versionado, lento, con riesgo. Mejor: 2 personas acceden con fricción + log.
- El grupo break-glass **no** es "los admins". Es un grupo pequeño separado, con uso monitorizado. Si un admin lo necesita ocasionalmente, se le añade temporalmente y se saca.

### Por qué `denialCondition: "true"`

Simple y explícito. Variantes posibles:

- `request.time.getHours("Europe/Madrid") < 8 || ...` — solo denegar fuera de horario laboral.
- `!(resource.name.startsWith(...))` — denegar excepto para un prefijo concreto.

Para este escenario, "siempre" es lo correcto — borrar un bucket de recibos de producción no debería ser una operación de business-as-usual en ningún horario.

## Qué queda fuera (futuro)

- **Workload Identity Federation** para que esta SA sea invocada desde GitHub Actions sin keys → `gcp-10`.
- **Org policy `iam.disableServiceAccountKeyCreation`** sobre el folder prod → `gcp-02` ejemplo 04 (concepto) y `gcp-09` (automatización).
- **Condition CEL en el binding** para scopear por prefijo de object dentro del bucket (`resource.name.startsWith("projects/_/buckets/acme-prod-receipts-raw/objects/2026/")` para limitar a objetos del año actual). No pedido por el escenario pero refinamiento válido.
