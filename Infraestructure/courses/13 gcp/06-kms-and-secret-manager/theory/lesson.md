# Lección — Cloud KMS y Secret Manager en GCP

> **Prerequisito mental**: haber visto `aws-09` (KMS, Secrets Manager, Parameter Store). Esta lección se apoya en ese modelo y marca las diferencias.

## 1. Encriptación por default en GCP

Todo dato en reposo en GCP está cifrado por default con claves **Google-managed**:

- Cloud Storage, BigQuery, Cloud SQL, Persistent Disks, Spanner, Firestore — todos encriptan automáticamente, sin coste adicional, sin configuración.
- Internamente Google ya usa envelope encryption: cada *chunk* lleva una **DEK** (data encryption key) y la DEK se envuelve con una **KEK** del root KMS interno.
- Como cliente **no gestionas nada**: no hay keyring que crear, no hay rotación que configurar, no hay bindings IAM que escribir.

Esto es materialmente distinto a AWS: en AWS casi todos los servicios *también* cifran por default, pero muchas plantillas y auditorías esperan ver una **AWS KMS CMK** gestionada explícitamente. En GCP la pregunta correcta es: **¿necesito realmente CMEK?**

CMEK es necesario cuando:

- Un marco regulatorio exige que la clave sea gestionable por el cliente (poder rotarla, auditarla, desactivarla independientemente de Google).
- Quieres **revocar acceso inmediato** a los datos cifrados desactivando una key version (sin esperar a Google).
- Necesitas controlar la **región** física donde reside el material criptográfico (compliance de residencia).
- Quieres un **split-brain** operacional: el equipo de seguridad gestiona la clave, el equipo de datos gestiona el bucket; sin la clave el bucket es inútil.

Para los demás casos, la encriptación por default **ya es suficiente** y gratuita.

## 2. Cloud KMS — el modelo de recursos

Jerarquía:

```
Project
└── location (region | multi-region | global)
    └── KeyRing
        └── CryptoKey (purpose, rotation_period, protection_level)
            └── CryptoKeyVersion (ENABLED | DISABLED | DESTROY_SCHEDULED | DESTROYED)
```

- Un **KeyRing** es un contenedor lógico; no se puede borrar nunca una vez creado (histórico; evita que una política mal escrita rompa referencias).
- Un **CryptoKey** tiene un `purpose` (`ENCRYPT_DECRYPT`, `ASYMMETRIC_SIGN`, `ASYMMETRIC_DECRYPT`, `MAC`). Para CMEK sobre GCS/SQL/Disks usas `ENCRYPT_DECRYPT`.
- Un **CryptoKeyVersion** es el material real. Encriptar siempre usa la *primary version*; decriptar funciona con cualquier versión que no esté `DESTROYED`.
- **Rotation period** (p. ej. `7776000s` = 90 días) crea automáticamente una nueva versión primary. Las versiones viejas pasan a estar `ENABLED` para *decrypt* pero ya no se usan para *encrypt*. **Los datos cifrados antiguos no se re-cifran**: siguen apuntando a su versión original y Cloud KMS la usa transparentemente para descifrar.
- **Protection level**:
  - `SOFTWARE` — barato, Google maneja el material.
  - `HSM` — Cloud HSM (FIPS 140-2 Level 3), ~10x más caro.
  - `EXTERNAL` / `EXTERNAL_VPC` — EKM, la clave vive fuera de Google (en Thales, Fortanix, etc.).

Para la gran mayoría de workloads, `SOFTWARE` es la opción correcta.

## 3. Envelope encryption — por qué importa

El patrón:

1. Generas o te dan una clave de datos **DEK** (p. ej. AES-256).
2. Encriptas el payload con la DEK (AES-GCM).
3. Envías la DEK a KMS, que te la devuelve envuelta en una **KEK** (la CryptoKey).
4. Almacenas junto al ciphertext la DEK envuelta (*wrapped DEK*).
5. Para descifrar: pides a KMS que *unwrap* la DEK (una llamada), y descifras el payload localmente con la DEK (0 llamadas).

Ventajas:

- Payloads grandes no cruzan KMS (coste y latencia controlados).
- Puedes **rotar la KEK** sin tocar los payloads: solo re-envuelves la DEK con la nueva versión. Si no re-envuelves, la versión antigua (`ENABLED` para decrypt) sigue sirviendo.
- Puedes **destruir una DEK** (olvidando la envuelta) para hacer *crypto-shred*: los datos siguen cifrados pero ya nadie puede recuperarlos.

Cuando usas CMEK sobre GCS, GCP hace exactamente esto por ti: cada chunk tiene su DEK, envuelta por tu CryptoKey. **Rotar la CryptoKey no re-cifra el bucket**: solo garantiza que los chunks *nuevos* usan la nueva versión primary.

> La actividad `01` incluye un demo local en Python que ejecuta este flujo con `cryptography`, sin KMS. Tras rotar la KEK, el ciphertext viejo se descifra con la KEK vieja (versión `ENABLED` para decrypt) y los nuevos ciphertexts usan la KEK nueva. Es exactamente el modelo mental correcto.

## 4. Service agents y CMEK — la trampa que todos pisan

Cuando un servicio (GCS, Cloud SQL, Compute, BigQuery…) debe cifrar/descifrar con una clave tuya, **el servicio** actúa como un principal propio: el **service agent**. Direcciones típicas:

- GCS: `service-<PROJECT_NUMBER>@gs-project-accounts.iam.gserviceaccount.com`
- Compute: `service-<PROJECT_NUMBER>@compute-system.iam.gserviceaccount.com`
- Cloud SQL: `service-<PROJECT_NUMBER>@gcp-sa-cloud-sql.iam.gserviceaccount.com`
- BigQuery: `bq-<PROJECT_NUMBER>@bigquery-encryption.iam.gserviceaccount.com`

Para que GCS pueda crear un bucket con CMEK necesitas:

```
IAM binding sobre la CryptoKey:
  role: roles/cloudkms.cryptoKeyEncrypterDecrypter
  member: serviceAccount:service-<PROJECT_NUMBER>@gs-project-accounts.iam.gserviceaccount.com
```

Si falta este binding, `terraform apply` del bucket **falla** con un error del estilo `the Cloud KMS key cannot be used to encrypt this bucket because the service account does not have permission`. Es la causa #1 de tickets abiertos la primera vez que alguien hace CMEK en GCP.

## 5. Secret Manager — el modelo

Jerarquía:

```
Project
└── Secret (replication: automatic | user-managed)
    └── SecretVersion (ENABLED | DISABLED | DESTROYED)   # numeradas 1, 2, 3, ...
```

Decisiones clave:

- **Replicación `automatic`**: GCP decide dónde replicar. Simple y barato. Preferido para la mayoría.
- **Replicación `user-managed`**: lista explícita de regiones. Necesario para compliance de residencia (p. ej. "este secreto solo puede vivir en `europe-west1` y `europe-west4`"). También te deja usar CMEK por región.
- **Versiones** son inmutables: para "cambiar" un secreto se crea una versión nueva. Un consumidor puede pedir `projects/.../secrets/foo/versions/latest` (siempre la última `ENABLED`) o una versión fija (`.../versions/3`) para builds reproducibles.
- **IAM**: `roles/secretmanager.secretAccessor` es el rol de lectura por versión; `roles/secretmanager.admin` para crear/rotar.

Nota de modelo mental: en AWS tienes **Secrets Manager** (con rotación nativa via Lambda) y **SSM Parameter Store** (más barato, sin rotación nativa). En GCP **solo hay Secret Manager**: una superficie, menos decisiones; para configuración no sensible usas repo + build vars o un bucket GCS versionado.

## 6. Montar un secret en Cloud Run

Las dos formas:

```bash
# A) Como variable de entorno (resuelve en tiempo de arranque de la revisión).
gcloud run deploy app \
  --set-secrets=DB_PASSWORD=my-secret:latest

# B) Como fichero en un volumen (el proceso lee /etc/secrets/db_password).
gcloud run deploy app \
  --set-secrets=/etc/secrets/db_password=my-secret:latest
```

Ambas son estrictamente superiores a `--set-env-vars DB_PASSWORD=xxxx`:

- El valor **no aparece** en `gcloud run services describe` ni en la Console.
- No queda en logs de deploy ni en historial de shell.
- Al crear una nueva revisión, la referencia se resuelve en caliente contra la versión indicada.
- Puedes pin'ear a versión fija (`:3`) para rollbacks reproducibles o a `:latest` para refrescar al redeployar.

La variante B (volumen) es preferible cuando el valor es grande (p. ej. una clave privada PEM) o cuando el framework ya sabe leer de disco (`secret_key_file=/etc/secrets/sk`). La variante A es más ergonómica para strings cortos.

El **principal** del servicio Cloud Run (una service account dedicada) necesita `roles/secretmanager.secretAccessor` sobre el secret concreto — nunca sobre `projects/<id>` entero.

## 7. Rotación de secretos

El patrón recomendado:

1. El secret tiene configurado `rotation_period` (p. ej. `2592000s` = 30 días) y una `topic` de Pub/Sub como destino.
2. Cuando se cumple el periodo, Secret Manager publica un mensaje de rotación al topic.
3. Un consumidor (Cloud Function, Cloud Run job, etc.) suscrito al topic genera un nuevo valor (ej. una nueva API key en el proveedor externo) y publica una **nueva versión** del secret.
4. La versión anterior **permanece `ENABLED`** durante una ventana de solape para dar tiempo a cachés y conexiones vivas.
5. Pasada la ventana se marca `DISABLED`, luego `DESTROYED`.

Comparado con AWS Secrets Manager:

- AWS tiene **rotation nativa** con Lambda (plantillas para RDS/DocDB/Redshift). GCP te obliga a escribir el rotator, lo que es más trabajo pero más honesto: *tú* decides qué significa "rotar" para tu proveedor externo.
- GCP no tiene equivalente directo a "scheduled rotation con 4 pasos (createSecret / setSecret / testSecret / finishSecret)". En su lugar, el rotator es un pipeline tuyo con las etapas que necesites.

En la actividad `02` escribes un `rotator.py` **local** que simula los pasos usando valores ficticios (`fake-sk-...`). No se habla nunca con la API de Secret Manager ni se publica a Pub/Sub real.

## 8. Decisiones típicas

| Pregunta | Respuesta corta |
|---|---|
| ¿Necesito CMEK en este bucket? | Solo si lo exige el framework de compliance o si quieres poder *crypto-shred* independiente de Google. |
| ¿Secret Manager o variable de entorno? | Siempre Secret Manager para datos sensibles. Variables son aceptables para flags no sensibles. |
| ¿Replicación `automatic` o `user-managed`? | `automatic` por default; `user-managed` solo con requisito de residencia. |
| ¿Protection level `SOFTWARE` o `HSM`? | `SOFTWARE` salvo FIPS 140-2 Level 3 explícito. |
| ¿Rotación de clave cada 30d o 90d? | 90d es el default sensato; 30d solo si lo exige el framework. Afecta coste operativo (más versions activas). |
| ¿Rotación de secreto cada cuánto? | Depende del secreto. API keys de terceros: 30–90d. Credenciales de BD: idealmente *continuous* vía IAM auth (sin secret). |
| ¿`latest` o versión fija al consumir? | `latest` para apps que toleran refresco en caliente al redeployar; versión fija para builds reproducibles o cuando necesitas rollback atómico. |

## 9. Antipatrones

- **CMEK por default en todo** sin justificación → coste y complejidad operativa sin beneficio real; cada bucket requiere binding al service agent correcto.
- **`--set-env-vars` para un secreto** → aparece en `describe`, logs y shell history. Nunca.
- **Service account con `roles/secretmanager.admin`** cuando solo necesita leer → principio de menor privilegio roto; usa `secretAccessor` sobre el secret concreto.
- **Rotar la CryptoKey esperando que re-cifre los datos** → no re-cifra; solo cifra los nuevos. Si necesitas re-cifrado total, debes reescribir los objetos (p. ej. `gsutil rewrite -k` para GCS).
- **Guardar valores reales en `terraform.tfvars`** cometeado al repo → el estado de Terraform y el fichero `tfvars` acaban en Git. Siempre pasa el valor por `-var`, por env var `TF_VAR_...`, o deja que el rotator cree la versión fuera de Terraform.
- **Un keyring global para toda la org** → mezcla scopes y multiplica blast radius. Un keyring por project (o por environment × project) es lo saludable.

## 10. Mapping AWS → GCP (síntesis)

| AWS | GCP | Notas |
|---|---|---|
| KMS CMK | Cloud KMS CryptoKey | GCP separa KeyRing (contenedor) de CryptoKey. |
| Automatic key rotation (yearly) | `rotation_period` configurable (p. ej. 90d) | GCP es más granular y lo expones en TF. |
| Encryption context | `additional_authenticated_data` (AAD) | Mismo concepto, nombre distinto. |
| Service-linked role para KMS | **Service agent** | El servicio tiene un SA dedicado; tú le das acceso a la clave. |
| Secrets Manager | Secret Manager | Casi 1:1. GCP no tiene rotation nativa. |
| SSM Parameter Store (SecureString) | — (usa Secret Manager) | GCP no distingue; menos ceremonia. |
| Lambda rotation | Cloud Function/Run suscrito al topic Pub/Sub de rotación | Más explícito en GCP. |

## 11. Checklist operativo

- [ ] Las apps consumen secretos vía `--set-secrets` (nunca `--set-env-vars` para datos sensibles).
- [ ] Las service accounts tienen `secretAccessor` sobre secretos concretos, no sobre el project.
- [ ] CMEK solo donde lo exige compliance; en el resto, encriptación por default.
- [ ] Los buckets con CMEK tienen el binding al service agent de GCS verificado antes del primer `apply`.
- [ ] `rotation_period` configurado para toda CryptoKey y para todo Secret que lo requiera.
- [ ] Replicación `user-managed` solo donde hay requisito de residencia.
- [ ] El rotator de un secret externo tiene *solape* de validez antes de destruir la versión vieja.
- [ ] Ningún valor de secreto se commetea al repo ni aparece en logs de CI.

## 12. Para la próxima lección

En `gcp-07-gke-and-autopilot` verás **Workload Identity**: cómo un pod de GKE puede impersonar una service account de GCP sin claves estáticas. Combinado con lo de este módulo, la receta es:

1. El pod corre con una Kubernetes SA ligada a una GCP SA (Workload Identity).
2. La GCP SA tiene `secretAccessor` sobre el secret.
3. El pod lee el secret via `Secret Manager API` sin ningún material de autenticación local.

Es el final del camino: cero secretos estáticos en el workload, cero bindings de más, auditoría clara.
