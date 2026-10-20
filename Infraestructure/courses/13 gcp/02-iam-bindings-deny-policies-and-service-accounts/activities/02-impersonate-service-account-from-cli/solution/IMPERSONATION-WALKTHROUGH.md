# REFERENCE — gcp-02-02-impersonate-service-account-from-cli

> Walkthrough de referencia. **No se ejecuta** contra GCP real. Documenta el
> patrón correcto para el día que la organización lo opere.

## Precondiciones (asumidas, no implementadas aquí)

- Project `acme-prod` existe y tiene habilitada la API `iamcredentials.googleapis.com`.
- La SA `deployer@acme-prod.iam.gserviceaccount.com` existe en `acme-prod` y tiene los roles de deployment necesarios (p. ej. `roles/run.admin` + `roles/iam.serviceAccountUser` sobre la runtime SA del Cloud Run service).
- Google Group `platform-eng@acme.io` existe en Cloud Identity / Google Workspace y Alice es miembro.
- El binding `token-creator-binding.yaml` (ver fichero hermano) está aplicado **sobre la SA destino**, no sobre el project.
- Org policy `constraints/iam.disableServiceAccountKeyCreation` está `enforced` sobre el folder prod.

## Flujo de impersonation (walkthrough paso a paso)

### Paso 1 — Alice se autentica como humana

```
gcloud auth login
# Abre el navegador, Alice se autentica contra el IdP corporativo con MFA.
# Al final, gcloud guarda credenciales OAuth2 de alice@acme.io en
# ~/.config/gcloud/credentials.db.
```

Comprobación rápida:

```
gcloud auth list
# * alice@acme.io    (activo)
```

### Paso 2 — Alice despliega impersonando a la SA de deployment

Opción A — flag por invocación:

```
gcloud run deploy receipts-processor \
  --project=acme-prod \
  --region=europe-west1 \
  --image=europe-west1-docker.pkg.dev/acme-prod/apps/receipts-processor:v42 \
  --impersonate-service-account=deployer@acme-prod.iam.gserviceaccount.com
```

Opción B — persistente para la configuración gcloud activa:

```
gcloud config set auth/impersonate_service_account \
  deployer@acme-prod.iam.gserviceaccount.com

gcloud run deploy receipts-processor \
  --project=acme-prod \
  --region=europe-west1 \
  --image=europe-west1-docker.pkg.dev/acme-prod/apps/receipts-processor:v42
```

Qué ocurre bajo el capó:

1. `gcloud` detecta la flag `--impersonate-service-account` (o la config persistente).
2. Hace una llamada a `iamcredentials.googleapis.com:generateAccessToken` con:
   - Credenciales de Alice (OAuth2 de `user:alice@acme.io`).
   - `name = projects/-/serviceAccounts/deployer@acme-prod.iam.gserviceaccount.com`.
3. GCP valida que Alice tiene **`roles/iam.serviceAccountTokenCreator`** sobre la SA destino (via membresía en `platform-eng@acme.io`).
4. `iamcredentials` devuelve un **access token efímero** para `deployer@...` (vida por defecto 1 h, configurable hasta 12 h con `lifetime`).
5. `gcloud` usa ese token para llamar a `run.googleapis.com:services.replaceService`.
6. Cloud Run API procesa el deploy con la identidad efectiva `deployer@acme-prod.iam.gserviceaccount.com`.

Alice **nunca** ha tenido una credencial de larga duración de la SA destino. Solo un token OAuth efímero generado dinámicamente.

### Paso 3 — Desactivar la impersonation al terminar (si fue persistente)

```
gcloud config unset auth/impersonate_service_account
```

Buena higiene: desactiva la impersonation persistente cuando terminas, para evitar que el próximo comando (p. ej. un `gcloud compute instances list` casual) viaje con esa identidad.

## Por qué NO SA key

Si Alice (o un pipeline) hubiera recibido una SA key de `deployer@...`, estarías operando con un **anti-patrón** con tres problemas materiales:

### 1. Expiración

- SA key: credenciales de **larga duración** sin fecha de expiración. Si el JSON se filtra en un repo público o en un backup olvidado, sigue siendo válido años después.
- Impersonation: token OAuth2 **efímero** (1 h por defecto, máximo 12 h). Un leak solo compromete esa ventana.

### 2. Rotación

- SA key: hay que rotar manualmente (crear key nueva, redistribuir a todos los consumidores, revocar la vieja). Casi nadie lo hace bien. En la práctica, keys viven años.
- Impersonation: no hay nada que rotar. El binding `roles/iam.serviceAccountTokenCreator` se concede o se revoca; el token se regenera dinámicamente en cada operación.

### 3. Auditabilidad e incident response

- SA key: audit logs ven la SA, no la persona física. "Un alguien con la key `abc123` hizo X" — ¿quién tenía esa key? Hay que correlacionarlo a mano con registros de distribución (si existen).
- Impersonation: audit logs ven **cadena completa** humano + SA (ver sección "Auditoría" abajo). Incident response trivial: "fue Alice impersonando deployer, a las 14:32".

### Qué refuerza el patrón: la org policy

```
constraints/iam.disableServiceAccountKeyCreation
  enforce: true
```

Aplicada al folder prod, hace que cualquier intento de emitir una SA key (via `gcloud` o API `serviceAccounts.keys.create`) **falle** con `FAILED_PRECONDITION`. No es un recordatorio: es un control técnico que **impide** la emisión de keys en primer lugar.

### Alternativas correctas (ninguna usa keys)

- **Humanos / pipelines dentro de GCP**: **impersonation** (lo que esta actividad documenta).
- **Pipelines fuera de GCP** (GitHub Actions, GitLab CI, AWS, on-prem): **Workload Identity Federation (WIF)**. Mapea claims OIDC del IdP externo a una SA de GCP sin keys. Cubierto en `gcp-10`.
- **Workloads en Cloud Run / GCE / GKE**: **attached SA** (el workload corre "como" la SA; GCP inyecta tokens dinámicamente via metadata server). También sin keys.

## Auditoría

### Qué queda registrado

Cada operación que `deployer@...` hace en `acme-prod` genera una entrada en Cloud Audit Logs con, al menos, estos campos clave:

```json
{
  "protoPayload": {
    "@type": "type.googleapis.com/google.cloud.audit.AuditLog",
    "authenticationInfo": {
      "principalEmail": "deployer@acme-prod.iam.gserviceaccount.com",
      "serviceAccountDelegationInfo": [
        {
          "firstPartyPrincipal": {
            "principalEmail": "alice@acme.io"
          }
        }
      ]
    },
    "methodName": "google.cloud.run.v1.Services.ReplaceService",
    "resourceName": "projects/acme-prod/locations/europe-west1/services/receipts-processor"
  }
}
```

Lectura:

- **`principalEmail`** del `authenticationInfo` = **identidad efectiva** = la SA destino (`deployer@...`).
- **`serviceAccountDelegationInfo[0].firstPartyPrincipal.principalEmail`** = **el humano que estaba detrás** (`alice@acme.io`).
- Para cadenas más largas (SA → SA → SA), hay múltiples entradas en `serviceAccountDelegationInfo`, en orden.

### Consultas útiles (conceptuales, no ejecutadas aquí)

```
# Todas las operaciones hechas via impersonation en el project
gcloud logging read '
  protoPayload.authenticationInfo.serviceAccountDelegationInfo:*
' --project=acme-prod --limit=100

# Operaciones donde Alice impersono alguna SA
gcloud logging read '
  protoPayload.authenticationInfo.serviceAccountDelegationInfo.firstPartyPrincipal.principalEmail="alice@acme.io"
' --project=acme-prod --limit=100
```

### Patrón de alerta recomendado

Log-based metric sobre `serviceAccountDelegationInfo.firstPartyPrincipal.principalEmail` **cuando** `methodName` empieza por `.*Delete.*` o similar, con alerting policy que notifica a Slack. Así, cada vez que alguien impersona una SA para una operación destructiva en prod, hay un rastro visible en tiempo cuasi-real.

## Resumen operativo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Qué role habilita impersonation? | `roles/iam.serviceAccountTokenCreator` **sobre la SA destino**. |
| ¿Qué API materializa el token? | `iamcredentials.googleapis.com`. |
| ¿Cuánto vive el token? | 1 h por defecto, hasta 12 h con `lifetime` explícito. |
| ¿Dónde va el binding? | En la SA destino, no en el project. |
| ¿Cómo se audita quién impersonó? | `serviceAccountDelegationInfo[].firstPartyPrincipal.principalEmail`. |
| ¿Qué pasa si Alice sale de la empresa? | HR la saca del grupo → al siguiente token-refresh, no puede impersonar. |
| ¿Y las SA keys? | No se emiten. `iam.disableServiceAccountKeyCreation` lo bloquea técnicamente. |
