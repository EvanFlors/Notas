# Plan — ADC via impersonation para desarrollo local (my-project-123)

## Problema

`gcloud auth login` no autentica a las libraries cliente — su codigo falla con `DefaultCredentialsError`. Las dos vias naive (ADC de usuario con scope cloud-platform, o SA key JSON) tienen contrapartidas serias; el patron correcto en 2026 es **ADC via impersonation**.

## Mecanismos

- `gcloud auth login` guarda credenciales de usuario en `~/.config/gcloud/credentials.db` (lo usa la CLI `gcloud`).
- `gcloud auth application-default login` guarda credenciales ADC en `~/.config/gcloud/application_default_credentials.json` (lo usan **las libraries cliente**).
- **Cadena ADC** (orden): `GOOGLE_APPLICATION_CREDENTIALS` -> `application_default_credentials.json` -> **metadata server** (`metadata.google.internal` en GCE/GKE/Cloud Run/Functions).
- **Impersonation**: `--impersonate-service-account=app-local-dev@my-project-123.iam.gserviceaccount.com`. El JSON de ADC pasa a tener `type: impersonated_service_account` y referencia a `iamcredentials.googleapis.com:generateAccessToken`. **Sin `private_key` en el disco**.
- Requisitos de impersonation:
  - API `iamcredentials.googleapis.com` habilitada en el project.
  - Usuario con `roles/iam.serviceAccountTokenCreator` sobre la SA.
  - SA con los roles minimos que la app necesita (p. ej. `roles/storage.objectViewer`).

## Flujo recomendado

1. **Setup de project (Platform, una vez)**: crear SA `app-local-dev@my-project-123.iam.gserviceaccount.com`, dar roles minimos; conceder `roles/iam.serviceAccountTokenCreator` al grupo `developers@acme.io`.
2. **Setup por laptop (developer, una vez)**:
   ```bash
   gcloud auth login
   gcloud config set project my-project-123
   gcloud auth application-default login \
     --impersonate-service-account=app-local-dev@my-project-123.iam.gserviceaccount.com
   ```
3. **Verificar** con `./verify-adc.sh`.
4. **Correr la app**. El codigo cliente no cambia.

## Chequeos

`verify-adc.sh` corre **solo comandos de lectura**:

- `gcloud auth list` — cuentas conocidas.
- `gcloud config list` — project/account/region activos.
- `gcloud auth application-default print-access-token` — devuelve un token efimero si ADC esta OK.

Ningun comando crea, borra ni modifica recursos.

## Riesgos

1. **ADC de usuario = scope `cloud-platform`** sobre toda la Org -> impersonation lo acota.
2. **Refresh token de larga duracion**. Si pierdes la laptop, el atacante tiene credenciales validas durante semanas. Mitigar con `gcloud auth application-default revoke` + revocar OAuth grants + rotar password + MFA en Cloud Identity.
3. **`GOOGLE_APPLICATION_CREDENTIALS`** apuntando a un path olvidado **gana** sobre ADC; revisar `.zshrc`/`.bashrc`.

## Antipatron

**Nunca** crear ni descargar una **service account key** (`private_key` JSON) para desarrollo local en 2026. No rotan, se filtran a Git, los secret scanners las detectan, y la Org Policy `constraints/iam.disableServiceAccountKeyCreation` las bloquea en orgs serias. Si existe una key heredada, planificar migrarla a impersonation (local) o Workload Identity Federation (CI/CD, ver `gcp-10`).
