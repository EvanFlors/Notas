# Ejemplo 02 — ADC vs user auth

> Lectura y analisis. **Sin ejecucion contra GCP real.** Objetivo: entender por que `gcloud` autentica a una identidad y las libraries cliente autentican a **otra** en la misma maquina, y como alinearlo con **impersonation**.

## 1. El problema

Un dia haces:

```bash
gcloud auth login                              # entras con alice@acme.io
gcloud compute instances list --project=my-project-123
# funciona
```

Y a continuacion escribes un script Python:

```python
from google.cloud import storage
client = storage.Client(project="my-project-123")
list(client.list_buckets())
# google.auth.exceptions.DefaultCredentialsError:
#   Your default credentials were not found. ...
```

¿Como que **not found**, si acabas de hacer login? Porque **las libraries cliente no leen las credenciales de `gcloud`**. Leen una cadena distinta: **ADC** (Application Default Credentials).

## 2. Los dos sistemas de credenciales

```
┌──────────────────────────────────┐    ┌─────────────────────────────────────────┐
│  gcloud CLI (herramienta)        │    │  Libraries cliente (Python/Node/Go/...) │
│                                  │    │                                         │
│  Lee: credentials.db             │    │  Lee en orden (cadena ADC):             │
│                                  │    │   1. $GOOGLE_APPLICATION_CREDENTIALS    │
│  Se escribe con:                 │    │   2. ~/.config/gcloud/                  │
│   gcloud auth login              │    │        application_default_credentials  │
│                                  │    │        .json                            │
│  Identidad: alice@acme.io        │    │   3. metadata server (en GCE/GKE/Run/   │
│  (OAuth2 refresh token)          │    │        Functions)                       │
│                                  │    │                                         │
│                                  │    │  Se escribe con:                        │
│                                  │    │   gcloud auth application-default login │
└──────────────────────────────────┘    └─────────────────────────────────────────┘
```

Son **dos stores de credenciales independientes** en la misma carpeta `~/.config/gcloud/`.

## 3. Autenticar las libraries en local

Dos opciones serias (y una antipatron):

### 3.1 ADC con la identidad del usuario (basico)

```bash
gcloud auth application-default login
# Abre browser, Google SSO. Guarda:
#   ~/.config/gcloud/application_default_credentials.json
```

A partir de ahora, el script Python funciona: la library busca ADC, encuentra el JSON, usa el refresh token.

**Scope por default**: `https://www.googleapis.com/auth/cloud-platform` (todo). Util en local; **mal** si pierdes la laptop.

### 3.2 ADC con impersonation (**patron recomendado 2026**)

```bash
gcloud auth application-default login \
  --impersonate-service-account=app-local-dev@my-project-123.iam.gserviceaccount.com
```

Que hace: **tu usuario** sigue siendo el principal (lo que `gcloud auth list` muestra), pero las libraries, al pedir un token, pasan por `iamcredentials.generateAccessToken` y obtienen un token **de la SA**. Beneficio: el radio de accion en tu laptop es el de la SA (minimo, scoped a `my-project-123`), no el de tu usuario corporativo (que tiene permisos sobre toda la Org).

Requisito previo: tu usuario necesita `roles/iam.serviceAccountTokenCreator` **sobre esa SA**. Se gestiona en `gcp-02`.

El `application_default_credentials.json` queda asi (resumen):

```json
{
  "type": "impersonated_service_account",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/app-local-dev@my-project-123.iam.gserviceaccount.com:generateAccessToken",
  "source_credentials": {
    "type": "authorized_user",
    "client_id": "...",
    "client_secret": "...",
    "refresh_token": "..."
  }
}
```

**Nota**: no hay `private_key`. **No existe un archivo de key**. Si la laptop se compromete, el atacante tiene el refresh token del usuario (que ya tenia); pero no una key de la SA que pueda copiar a otra maquina y usar en silencio.

### 3.3 Service Account Key (**antipatron**)

```bash
# NO HAGAS ESTO en 2026
gcloud iam service-accounts keys create key.json \
  --iam-account=app-local-dev@my-project-123.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

Por que es malo:

- La key es un archivo plano con una `private_key` que no expira ni rota.
- Si la commiteas a Git (clasico), es un leak permanente (ningun `git filter-branch` lo arregla; hay que rotar la key).
- Secret scanners de GitHub, Trufflehog, etc. buscan `-----BEGIN PRIVATE KEY-----` con "private_key_id": y disparan alertas.
- La Org Policy `iam.disableServiceAccountKeyCreation` (ver `gcp-02`) lo prohibe en orgs serias.

Si **ya tienes** una key en una pipeline o maquina heredada: planifica migrarla a **WIF** (CI/CD) o **impersonation** (local).

## 4. Verificar que ADC esta configurada

```bash
# Mostrar que archivo esta usando
gcloud auth application-default print-access-token
# Devuelve un access token efimero (1h). Si tira "not found", ADC no esta.

# Que principal esta detras del token
gcloud auth application-default print-access-token \
  --format='value()' \
  | xargs -I{} curl -s "https://oauth2.googleapis.com/tokeninfo?access_token={}"
# JSON con "email" y "scope".
```

En Python, el equivalente:

```python
import google.auth
credentials, project = google.auth.default()
print(f"Principal: {credentials.service_account_email if hasattr(credentials, 'service_account_email') else 'user'}")
print(f"Project: {project}")
```

## 5. ADC en entornos **no** locales

En GCE/GKE/Cloud Run/Functions/App Engine, **no** se corre `gcloud auth application-default login`. La cadena ADC resuelve en el **metadata server** y obtiene credenciales de la **SA attached** al recurso:

- GCE VM: SA attached en el `--service-account=` al crearla.
- Cloud Run: SA attached con `--service-account=` en `gcloud run deploy`.
- GKE: via **Workload Identity** — un KSA (K8s SA) mapea a una GSA (Google SA) y los pods obtienen el token del metadata server (ver `gcp-07`).

Esto significa que **el mismo codigo**:

```python
from google.cloud import storage
storage.Client().list_buckets()
```

Funciona:

- En tu laptop con `gcloud auth application-default login` o impersonation.
- En CI/CD con `GOOGLE_APPLICATION_CREDENTIALS` apuntando a un token de WIF (sin key).
- En Cloud Run con la SA attached y permisos adecuados.

**No cambia el codigo. Cambia solo ADC.**

## 6. Trampas que suelen morderte

1. **"`gcloud auth login` deberia bastar"**. No. Las libraries no lo leen. Siempre haz **tambien** `gcloud auth application-default login` (o impersonation).
2. **Scope `cloud-platform` en local es demasiado**. Un ADC con tu usuario corporativo da acceso a **todo** lo que puedes tocar en toda la Org. Impersonation lo acota.
3. **`GOOGLE_APPLICATION_CREDENTIALS` apunta a un path invalido**. La variable gana sobre el archivo de ADC. Si tienes `export GOOGLE_APPLICATION_CREDENTIALS=~/old-key.json` en un `.zshrc` olvidado, tu nuevo `application-default login` no se usa.
4. **ADC en Cloud Shell no es la misma que local**. Cloud Shell tiene su propio `application-default` basado en la identidad de Cloud Shell; si cambias el project activo, ADC puede quedarse apuntando al anterior. `gcloud auth application-default revoke` + `login` lo arregla.
5. **Si usas `--impersonate-service-account` en ADC, la quota se descuenta de un project**. Por default, el project de la SA. Si quieres que se descuente de otro, define `billing/quota_project` o `--billing-project=...` en los clients que lo soporten.

## 7. Preguntas de autocomprobacion

1. ¿Que archivo escribe `gcloud auth login` y que archivo escribe `gcloud auth application-default login`? ¿Son el mismo?
2. ¿Por que `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` **gana** sobre el `application_default_credentials.json`? ¿Donde esta documentado el orden?
3. En Cloud Run, el codigo Python no corre `gcloud auth application-default login` nunca. ¿De donde saca las credenciales?
4. ¿Que **principal** termina haciendo la llamada a GCP si tienes `gcloud auth login = alice@acme.io` y `gcloud auth application-default login --impersonate-service-account=sa@...`?
5. Un pipeline en GitHub Actions tiene `GOOGLE_APPLICATION_CREDENTIALS=/tmp/wif-token.json`. ¿Que tipo de archivo es, y por que **no** es una SA key?
