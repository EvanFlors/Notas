# REFERENCE — gcp-01-02-adc-from-local-dev

> Una **referencia** razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

# Plan — ADC via impersonation para desarrollo local (`my-project-123`)

## Problema

Un developer corre codigo Python en su laptop que usa `google-cloud-storage`. Esperaba que `gcloud auth login` bastara. Falla:

```
google.auth.exceptions.DefaultCredentialsError:
    Your default credentials were not found.
```

Causa: las libraries cliente **no leen** las credenciales de `gcloud`. Leen **ADC** (Application Default Credentials). Opciones conocidas:

1. **ADC con la identidad del usuario** (`gcloud auth application-default login`). Resuelve el error pero da **scope `cloud-platform`** sobre toda la Org — demasiado para una laptop.
2. **SA key JSON** (`gcloud iam service-accounts keys create key.json`). Resuelve y acota, pero introduce un **secret permanente** que no rota. **Antipatron 2026**.
3. **ADC via impersonation** (`gcloud auth application-default login --impersonate-service-account=...`). Resuelve, acota al scope de la SA, **sin crear keys**. Patron recomendado.

## Mecanismos

Dos stores de credenciales independientes en `~/.config/gcloud/`:

| Mecanismo | Para que | Archivo |
|-----------|----------|---------|
| `gcloud auth login` | la CLI `gcloud` del usuario | `credentials.db` |
| `gcloud auth application-default login` | las **libraries cliente** (ADC) | `application_default_credentials.json` |

**Cadena ADC** (orden en que las libraries buscan credenciales):

1. Variable `GOOGLE_APPLICATION_CREDENTIALS` apuntando a un archivo JSON.
2. `~/.config/gcloud/application_default_credentials.json`.
3. **Metadata server** (`http://metadata.google.internal/computeMetadata/v1/`) — disponible solo en GCE, GKE, Cloud Run, Cloud Functions, App Engine. Devuelve credenciales de la **SA attached** al recurso.
4. Falla con `DefaultCredentialsError`.

**Impersonation** sin keys:

- El flag `--impersonate-service-account=sa@project.iam.gserviceaccount.com` modifica el JSON de ADC a:
  ```json
  {
    "type": "impersonated_service_account",
    "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/sa@...:generateAccessToken",
    "source_credentials": { "type": "authorized_user", "refresh_token": "..." }
  }
  ```
- No contiene `private_key`. **No existe archivo de key**.
- Requisitos:
  - Project `my-project-123` tiene `iamcredentials.googleapis.com` habilitada.
  - La SA `app-local-dev@my-project-123.iam.gserviceaccount.com` existe y tiene los roles minimos sobre el project.
  - El usuario tiene `roles/iam.serviceAccountTokenCreator` **sobre esa SA** (no sobre el project).

## Flujo recomendado

1. **One-time setup del project** (hecho por Platform, no por el developer):
   - Crear SA `app-local-dev@my-project-123.iam.gserviceaccount.com`.
   - Bindings minimos en el project: `roles/storage.objectViewer`, `roles/logging.viewer`, etc. (los que necesite la app).
   - Dar `roles/iam.serviceAccountTokenCreator` sobre esa SA al grupo `developers@acme.io`.
2. **Setup por developer** (una vez por laptop):
   ```bash
   gcloud auth login                 # user auth para la CLI
   gcloud config set project my-project-123
   gcloud auth application-default login \
     --impersonate-service-account=app-local-dev@my-project-123.iam.gserviceaccount.com
   ```
3. **Verificacion** (correr `verify-adc.sh`):
   ```bash
   gcloud auth list                              # ve al usuario
   gcloud config list                            # project my-project-123 activo
   gcloud auth application-default print-access-token   # token efimero devuelto
   ```
4. **Correr la app**. El codigo Python ni se entera; `storage.Client().list_buckets()` funciona.

## Chequeos

El script `verify-adc.sh` adjunto corre **solo comandos de lectura**:

- `gcloud auth list` — enumerar cuentas conocidas.
- `gcloud config list` — mostrar el config activo (project, account, region).
- `gcloud auth application-default print-access-token` — devuelve un access token efimero; si falla, ADC no esta.

**Ningun comando crea, borra o modifica recursos.** Si el developer no esta autenticado, los comandos fallan localmente sin impacto en GCP.

## Riesgos

Tres riesgos a mitigar al operar en local:

1. **Scope demasiado grande** si usas ADC con usuario corporativo. Mitigacion: impersonation.
2. **Refresh token de larga duracion** (semanas-meses). Si la laptop se pierde, el atacante tiene credenciales validas. Mitigacion:
   - `gcloud auth application-default revoke` + `gcloud auth revoke --all`.
   - Revocar OAuth grants desde `https://myaccount.google.com/permissions`.
   - Rotar password + reclaim MFA en Cloud Identity.
3. **`GOOGLE_APPLICATION_CREDENTIALS` olvidada apuntando a `~/old-key.json`** gana sobre ADC. Mitigacion: `unset GOOGLE_APPLICATION_CREDENTIALS` tras migrar; borrar la key del disco; `grep -r 'GOOGLE_APPLICATION_CREDENTIALS' ~/.{bash,zsh}rc`.

## Antipatron

**Nunca** crear ni descargar un service account key JSON para desarrollo local en 2026. Razones:

- La key contiene un `private_key` RSA en texto plano.
- No expira ni rota automaticamente.
- Si se commitea a Git (clasico), es un leak permanente — `git filter-branch` no lo arregla; hay que **rotar la key** en GCP.
- Secret scanners detectan `-----BEGIN PRIVATE KEY-----` + `"private_key_id":`.
- La Org Policy `constraints/iam.disableServiceAccountKeyCreation` (ver `gcp-02`, `gcp-09`) **prohibe** crearlas en una org bien gobernada.

Si ya existe una key heredada en una laptop o pipeline:

1. Rotarla primero (`gcloud iam service-accounts keys create` + migrar + `keys delete` la vieja).
2. Migrar a impersonation (local) o Workload Identity Federation (CI/CD, ver `gcp-10`).
3. Habilitar la Org Policy para prevenir recurrencia.

---

## Notas sobre placeholders

- `my-project-123` es un placeholder; no existe. Nunca ejecutar comandos de este plan contra un project real sin governance.
- `app-local-dev@my-project-123.iam.gserviceaccount.com` es un placeholder de SA. En Fase 4, el nombre real surge del modulo Terraform.
