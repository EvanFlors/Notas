# Actividad 02 — ADC via impersonation desde el entorno local

## 1. Identificacion

- **ID:** `gcp-01-02-adc-from-local-dev`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-01-model-projects-billing-and-cli`
- **Dificultad:** beginner
- **Duracion estimada:** 60-80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un developer nuevo del equipo `checkout` quiere correr una app Python en su laptop que consulta un bucket GCS en `my-project-123`. El codigo usa `google-cloud-storage`. En AWS esta persona habria creado un `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` o configurado SSO. En GCP, cualquiera de las dos opciones **naive** es mala:

- **`gcloud auth login`** no autentica a las libraries cliente — su codigo seguira fallando con `DefaultCredentialsError`.
- **Crear una SA key** (`gcloud iam service-accounts keys create key.json`) resuelve el problema pero introduce un **secret permanente** en la laptop, que si se filtra no rota.

El patron correcto en 2026 es **ADC via impersonation**: el developer autentica como usuario (igual que para `gcloud`), y las libraries, cuando piden token, pasan por `iamcredentials.generateAccessToken` para obtener un token de **una service account** acotada al project. **Sin keys**, con auditoria limpia (CloudTrail/CloudAudit muestra `impersonate` events).

Tu encargo: producir un **plan Markdown** que explique el flujo + un **script shell de verificacion** que un developer pueda correr en su laptop para asegurarse de que todo esta bien configurado antes de correr su app.

**Importante**: no se toca GCP real. El script invoca comandos `gcloud` **de lectura** (`list`, `print-access-token`, `config list`) que, si el developer no esta autenticado, simplemente fallan localmente sin crear nada en GCP.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Distinguir user auth vs ADC y donde se guarda cada credencial.
- Explicar por que las SA keys son antipatron en 2026.
- Diseñar un flujo de ADC via impersonation (3-5 pasos).
- Escribir un script de verificacion que no destruya nada.
- Identificar 3 riesgos del ADC con identidad de usuario (sin impersonation).

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (en particular §8 auth y ADC, §12 fundamentos internos).
- Haber recorrido `../../examples/02-adc-vs-user-auth/`.
- Herramientas: `bash`, editor Markdown. `gcloud` **opcional** — si esta instalado, el script correra; si no, el validador solo chequea estructura/sintaxis.

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-01-adc
cd /tmp/gcp-01-adc
```

Puedes usar otro directorio; entonces pasalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `adc-plan.md`

Un documento con las siguientes **secciones obligatorias** (el validador las busca por encabezado):

- `## Problema`
- `## Mecanismos`
- `## Flujo recomendado`
- `## Chequeos`
- `## Riesgos`
- `## Antipatron`

Contenido minimo que el validador busca:

- Mencion a **`gcloud auth login`** y a **`gcloud auth application-default login`** (los dos comandos, con sus nombres literales).
- Mencion a **`~/.config/gcloud/application_default_credentials.json`** (donde vive ADC).
- Mencion a **`--impersonate-service-account`** (flag clave).
- Mencion a **`roles/iam.serviceAccountTokenCreator`** (el rol necesario para impersonar).
- Mencion a **`iamcredentials`** o `iamcredentials.googleapis.com` (API habilitada).
- Mencion a **metadata server** o `metadata.google.internal` (cadena ADC en entornos GCP).
- Mencion al **antipatron de SA keys** (`private_key` o `service-account key`) y por que evitarlo.
- Uso del placeholder `my-project-123` (**no** un project real).
- Mencion a `app-local-dev@my-project-123.iam.gserviceaccount.com` o similar (SA placeholder para impersonar).

### 5.3 Escribe `verify-adc.sh`

Script shell que un developer puede correr en su laptop para verificar que su ADC esta bien. Requisitos:

- Shebang `#!/usr/bin/env bash`.
- `set -eu` (sin `pipefail` para evitar SIGPIPE con `grep -q`).
- Comentario explicando el motivo de no activar pipefail (SIGPIPE con `grep -q`).
- Debe invocar al menos estos **comandos de lectura** (literales, el validador los busca):
  - `gcloud auth list`
  - `gcloud config list`
  - `gcloud auth application-default print-access-token`
- Debe tolerar que `gcloud` no este instalado (`command -v gcloud` + mensaje claro).
- **No** debe invocar comandos destructivos (`create`, `delete`, `enable`, `set-iam-policy`, `add-iam-policy-binding`, `revoke`).
- Debe mencionar `--impersonate-service-account` en texto (comentario o echo).
- Debe estar `chmod +x` (ejecutable).
- Debe pasar `bash -n verify-adc.sh`.
- Placeholder consistente: usar `my-project-123` si se referencia un project.

### 5.4 Entregables

```
/tmp/gcp-01-adc/
├── adc-plan.md
└── verify-adc.sh      (chmod +x)
```

## 6. Resultado esperado

- Los 2 archivos existen con el contenido pedido.
- El validador pasa en verde.
- Un developer puede leer `adc-plan.md`, seguir los 3-5 pasos del "Flujo recomendado", y correr `./verify-adc.sh` sin romper nada.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural + semantico pasa.
- **Correctitud**: distincion user auth vs ADC clara, impersonation explicada, antipatron de keys documentado.
- **Seguridad**: ningun comando destructivo en el script; nunca una SA key creada ni descargada.
- **Mantenibilidad**: Markdown valido; script con `set -eu` y comentario de pipefail/SIGPIPE.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/gcp-01-adc
```

El validador comprueba **estructura + presencia de comandos/strings clave + ausencia de comandos destructivos**. No se conecta a GCP ni requiere `gcloud` instalado. Compara tu entregable con `solution/REFERENCE.md` para autoevaluacion semantica.

## 9. Preguntas de reflexion

1. ¿Que pasa si un developer corre `gcloud auth login` pero no `gcloud auth application-default login`? ¿Donde se nota primero?
2. ¿Por que `--impersonate-service-account` **no** requiere crear un archivo de key?
3. Si un developer deja la laptop en un cafe, ¿cual es el blast radius con ADC de usuario? ¿Y con ADC via impersonation?
4. ¿Donde cae la cadena ADC en Cloud Run cuando no has corrido `gcloud auth application-default login` nunca?
5. ¿Como revocarias ADC de forma defintiva si pierdes la laptop?

## 10. Extensiones

- Añade al plan una seccion "WIF" (Workload Identity Federation) explicando como el mismo codigo correra en GitHub Actions sin keys (preview de `gcp-10`).
- Añade al script un check de que la Org Policy `iam.disableServiceAccountKeyCreation` esta activa en el project (comando `gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --project=...` — solo lectura).
- Añade un ejemplo Python de 5 lineas que use ADC (`from google.cloud import storage; storage.Client().list_buckets()`) y comentalo.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-01-adc
```

No hay infraestructura que detener (nunca se creo nada en GCP).
