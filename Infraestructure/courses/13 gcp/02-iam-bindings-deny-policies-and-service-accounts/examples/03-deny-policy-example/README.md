# Ejemplo 03 — Anatomía de una Deny Policy

> Lectura y análisis. Sin ejecución. Objetivo: ser capaz de **leer una deny policy** y predecir qué veta y a quién.

## 1. Esqueleto comentado

```yaml
# Deny policy adjuntada al folder "prod"
# Attachment point: policies/cloudresourcemanager.googleapis.com%2Ffolders%2F123456789012/denypolicies/no-bucket-delete
name: policies/cloudresourcemanager.googleapis.com%2Ffolders%2F123456789012/denypolicies/no-bucket-delete
displayName: Prohibir borrar buckets en prod salvo break-glass
etag: ABC123=
rules:
  - description: Veto storage.buckets.delete para todos excepto el grupo break-glass
    denyRule:
      deniedPrincipals:
        - principalSet://goog/public:all
      exceptionPrincipals:
        - principalSet://goog/group/break-glass-storage@acme.io
      deniedPermissions:
        - storage.googleapis.com/buckets.delete
      denialCondition:
        title: always
        description: Siempre denegar (no hay condición de bypass)
        expression: "true"
```

Elementos:

- **`name`** / **`attachment point`**: dónde se cuelga. En GCP, las deny policies se adjuntan a **recursos de Resource Manager** (organization, folder, project). El URL-encoding (`%2F` por `/`) es parte del nombre literal del recurso.
- **`displayName`**: nombre legible, obligatorio.
- **`rules`**: lista. Puede haber hasta 500 reglas por policy.
- **`denyRule`**: el núcleo.
  - **`deniedPrincipals`**: a quién veta. `principalSet://goog/public:all` = todos.
  - **`exceptionPrincipals`**: quiénes se escapan del veto. Patrón break-glass.
  - **`deniedPermissions`**: lista de permisos atómicos **con nombre cualificado** (`<servicio>.googleapis.com/<permiso>`). **No** nombres cortos.
  - **`denialCondition`**: expresión CEL. `"true"` = siempre; puedes meter lógica de tiempo, de tipo de recurso, etc.
  - **`exceptionPermissions`** (no mostrado): opuesto a `deniedPermissions` — permite denegar "todo lo del servicio menos esto".

## 2. Patrón: veto universal con excepción break-glass

El ejemplo arriba. Lectura:

- "Nadie" (`principalSet://goog/public:all`) puede ejecutar `storage.googleapis.com/buckets.delete`...
- ...excepto los miembros de `break-glass-storage@acme.io`.
- La condición es `"true"` (siempre activa).

Resultado neto: aunque un principal tenga `roles/storage.admin` (que incluye `storage.buckets.delete`) por un binding en el project o en la organización, **no puede borrar buckets** en los projects bajo este folder. Solo el grupo break-glass puede.

Operacionalmente, el grupo break-glass tiene 2 personas, cada acceso dispara una alerta a Slack vía log-based metric, y las credenciales exigen MFA fresca.

## 3. Patrón: deny con condición temporal

```yaml
rules:
  - description: Veto borrado de SAs fuera de horario laboral europeo
    denyRule:
      deniedPrincipals:
        - principalSet://goog/public:all
      exceptionPrincipals:
        - principalSet://goog/group/break-glass-iam@acme.io
      deniedPermissions:
        - iam.googleapis.com/serviceAccounts.delete
      denialCondition:
        title: outside-business-hours
        description: Solo denegar fuera del horario laboral
        expression: |
          request.time.getHours("Europe/Madrid") < 8 ||
          request.time.getHours("Europe/Madrid") >= 20
```

Qué hace: durante horario laboral (8–20 CET), un principal con `roles/iam.serviceAccountAdmin` **puede** borrar SAs normalmente. Fuera de ese horario, el borrado está vetado (salvo break-glass). Razón: borrados de SAs a las 03:00 son casi siempre un incidente — exigir la ruta break-glass fuerza una alerta.

## 4. Patrón: deny de un servicio completo

```yaml
rules:
  - description: Prohibir uso de Cloud Functions gen1 en prod (migrados a gen2)
    denyRule:
      deniedPrincipals:
        - principalSet://goog/public:all
      exceptionPrincipals: []
      deniedPermissions:
        - cloudfunctions.googleapis.com/functions.create
        - cloudfunctions.googleapis.com/functions.update
      denialCondition:
        title: always
        expression: "true"
```

Qué hace: nadie puede crear ni actualizar Cloud Functions. Si alguien lo intenta por accidente (p. ej. un Terraform legacy), falla con un error claro. Para habilitarlo de vuelta, hay que borrar la policy — un cambio **versionado y revisable**.

## 5. Dos sutilezas que suelen morderte

### 5.1 Nombres de permisos cualificados

**Mal**: `deniedPermissions: ["storage.buckets.delete"]` → el permiso no se reconoce, la policy no veta nada.

**Bien**: `deniedPermissions: ["storage.googleapis.com/buckets.delete"]`.

El prefijo `<servicio>.googleapis.com/` es obligatorio. Es un error silencioso **común** — la policy se crea, se aplica, y no hace nada.

### 5.2 Las deny policies solo aplican a algunos servicios

Google va añadiendo servicios al modelo deny policies. En GA: Storage, Compute, IAM, Resource Manager, Cloud Functions, Cloud Run, Secret Manager, varios más. **No** todos. Antes de confiar un veto crítico a una deny policy, confirma que el permiso en cuestión está soportado en la [matriz de permisos](https://cloud.google.com/iam/docs/deny-permissions-support).

## 6. Flujo mental para leer una deny policy cualquiera

1. ¿Dónde está **adjuntada** (`name` → organization/folder/project)? Esto define el blast radius descendente.
2. ¿`deniedPrincipals` es `public:all` o un conjunto concreto? (La mayoría son `public:all` + excepciones.)
3. ¿Qué `exceptionPrincipals` escapan? ¿Son grupos break-glass o SAs operacionales?
4. ¿`deniedPermissions` son nombres cualificados? ¿Qué servicio tocan?
5. ¿`denialCondition` es `"true"` o condicional? Si condicional, lee el CEL con cuidado.
6. ¿Qué roles concedidos arriba en la jerarquía quedan **efectivamente** reducidos por esta policy?

## 7. Preguntas de autocomprobación

1. Un developer tiene `roles/owner` en un project. Una deny policy en el folder padre veta `storage.googleapis.com/buckets.delete`. ¿Puede el developer borrar buckets?
2. En el ejemplo del break-glass, si quitas a Carol del grupo `break-glass-storage@acme.io` mientras tiene una sesión activa, ¿puede todavía borrar un bucket? ¿Hasta cuándo?
3. ¿Qué pasa si pones `deniedPermissions: ["storage.buckets.*"]`? ¿Soporta wildcards?
4. Un auditor pregunta "¿qué deny policies protegen el project `checkout-prod`?". ¿Qué recursos tienes que inspeccionar?
5. Comparando con una SCP AWS "deny `s3:DeleteBucket`": ¿cuál es más expresiva para un escenario break-glass con 2 excepciones humanas? ¿Y cuál es más fácil de auditar operacionalmente?
