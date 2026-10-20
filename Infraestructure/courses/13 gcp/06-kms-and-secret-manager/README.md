# gcp-06 — Cloud KMS y Secret Manager

## Identificación

- **ID:** `gcp-06-kms-and-secret-manager`
- **Curso:** `gcp`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `gcp-02` (IAM, service accounts, impersonation), curso AWS ≥ `aws-09` (KMS, Secrets Manager, Parameter Store).

## Objetivo

Gestionar **claves criptográficas** y **secretos** en GCP con el mismo rigor que en AWS, entendiendo las diferencias materiales: encriptación por default *gratuita* y transparente, **CMEK** (customer-managed encryption keys) solo cuando el cumplimiento lo requiere, y **Secret Manager** como superficie única (GCP no distingue secretos vs parameter store).

Al terminar deberías poder decidir cuándo activar CMEK, planificar la **rotación** de una clave sin romper los datos cifrados, consumir un secreto desde Cloud Run **sin manejar credenciales** y escribir una **política de acceso IAM** mínima para una clave y un secreto. Todo esto **sin tocar una cuenta GCP real** y sin dejar un dólar de factura.

## Alcance

Este módulo cubre:

- **Cloud KMS**: keyrings (regionales o globales), key versions, estados de versión (`ENABLED`, `DISABLED`, `DESTROY_SCHEDULED`), **rotation period** automático, protection level **SOFTWARE** vs **HSM** vs **EXTERNAL**.
- **CMEK (Customer-Managed Encryption Keys)**: aplicadas a GCS (bucket `encryption.default_kms_key_name`), Cloud SQL, discos de GCE, BigQuery. Rol **service agent** por servicio (`service-<project-number>@gs-project-accounts.iam.gserviceaccount.com` para GCS, p. ej.) que debe tener `roles/cloudkms.cryptoKeyEncrypterDecrypter` sobre la clave.
- **Envelope encryption**: el patrón real detrás de KMS (DEK + KEK). Se demuestra **localmente en Python** con `cryptography` — sin cloud — para que quede claro **qué hace KMS** y **qué pasa cuando rotas la KEK**.
- **Secret Manager**: secret como contenedor lógico, **versions** inmutables numeradas, replicación `automatic` (multi-región gestionada) o `user-managed` (lista explícita de regiones), acceso por IAM (`roles/secretmanager.secretAccessor`).
- **Patrón de consumo**: montar un secret en Cloud Run como variable de entorno o como fichero en un volumen (`--set-secrets`), sin pasar nunca el valor por `--set-env-vars`.
- **Rotación de secretos**: alias por versión (`latest` vs versión fija), ventanas de validez solapadas, `rotation_period` + Pub/Sub notification; comparación con rotación Lambda-driven de AWS Secrets Manager.

Lo que **no** cubre:

- Deploy real de Cloud Run con un secret montado — se describe pero no se ejecuta contra GCP. Volverá como parte del capstone.
- CMEK sobre Spanner, BigQuery con **CMEK-protected columns**, o claves externas (EKM) — se mencionan pero no se profundizan.
- Rotación con **Cloud Functions** disparadas por Pub/Sub — se diseña el flujo pero no se desplega.

Este módulo es **mayoritariamente conceptual + Terraform plan + validación de JSON/Python**. El único *tooling* es `bash`, `jq`, `python3` con `cryptography`, y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda: encriptación por default en GCP, envelope encryption, CMEK y service agents, Secret Manager vs variables, patrón de rotación.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución contra GCP):
  - `01-gcs-with-cmek/` — anatomía de un bucket con CMEK: keyring, key, binding del service agent, bucket referenciando la clave. Explica por qué el bucket **falla al crearse** si el binding al service agent falta.
  - `02-secret-manager-mount-in-cloud-run/` — ciclo de vida de un secret y las dos formas de montarlo en Cloud Run (env var vs volumen de ficheros). Discute por qué `--set-secrets` es **estrictamente mejor** que `--set-env-vars` para datos sensibles.
- **`activities/`** — dos actividades **independientes**:
  - `01-cmek-rotation-impact/` — escribir el Terraform *plan* para un keyring + clave CMEK aplicada a un bucket, la política IAM del service agent, y un **demo local en Python** de envelope encryption que muestra por qué la rotación de la KEK **no re-cifra** los datos.
  - `02-secret-rotation-pattern/` — escribir el Terraform *plan* de un secret con rotación activada, la política IAM del principal consumidor y un **rotador en Python** que publica una nueva versión usando valores **ficticios** (`fake-sk-...`), nunca secretos reales.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar envelope encryption; diferenciar KEK y DEK; justificar cuándo activar CMEK; contrastar Secret Manager vs variables de entorno en Cloud Run. |
| Operativa (sin infra) | Escribir un `main.tf` para keyring + key con rotación y para un secret con rotación; escribir una binding JSON mínima para el service agent de GCS. |
| Arquitectónica | Diseñar el flujo de rotación de un secret sin downtime; decidir replicación `automatic` vs `user-managed`; mapear quién debe tener `cryptoKeyEncrypterDecrypter` y quién `secretAccessor`. |

## Criterios de evaluación

- Dado un bucket que falla al crearse con CMEK, identifica que falta el binding al service agent GCS sobre la clave.
- Dado un fragmento de `main.tf`, explica qué pasa si bajas `rotation_period` de 90d a 30d (nueva *key version* automática, versiones antiguas pasan a `DISABLED` para encrypt pero siguen vigentes para decrypt).
- Justifica por qué montar un secret como `--set-secrets` es mejor que `--set-env-vars` (el valor no aparece en `gcloud run services describe`, no entra en logs de deploy, se refresca al crear nueva revisión).
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Actividad 01**: `main.tf` del keyring + key + bucket con CMEK; `iam-binding-gcs-service-agent.json`; `envelope-demo.py` ejecutable y `README-IMPACT.md`.
- **Actividad 02**: `main.tf` del secret con `rotation_period`; `iam-binding-secret-accessor.json`; `rotator.py` ejecutable con valores ficticios; `README-ROTATION.md`.

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, JSON, Terraform (sin `apply`) y Python. No se requiere project GCP activo. Si en una fase posterior decides provisionar lo diseñado:

- **Cloud KMS**: ~0.06 USD por *key version* activa al mes + 0.03 USD por cada 10.000 operaciones. Un keyring con 1 key rotando a 90 días cuesta < 1 USD/mes en pruebas.
- **Secret Manager**: 0.06 USD por secret-version-mes activa (los primeros 6 secret-version-meses son gratis) + 0.03 USD por 10.000 accesos.
- **HSM protection level** y **EKM** son materialmente más caros (orden de magnitud 5–10x) — reservados para compliance.

## Siguiente módulo

→ `gcp-07-gke-and-autopilot` — GKE Standard, Autopilot y Workload Identity (equivalente a IRSA). Las claves y secretos de este módulo se usarán allí para proteger workloads en Kubernetes.
