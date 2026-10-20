# Actividad 02 — Workload Identity Federation for GKE: walkthrough

## 1. Identificación

- **ID:** `gcp-07-02-workload-identity-federation-walkthrough`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-07-gke-and-autopilot`
- **Dificultad:** advanced
- **Duración estimada:** 70–90 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un Deployment `checkout-app` en el namespace `checkout` del cluster GKE necesita leer el bucket `gs://checkout-assets-prod`. Hoy, el equipo lo tiene montado con una **service account key** JSON en un Secret K8s. Security pide eliminar la key.

Tu encargo:

1. Reescribir los manifiestos K8s para usar **Workload Identity Federation for GKE** (sin keys, sin secrets).
2. Documentar la secuencia **`gcloud`** que la plataforma ejecutará para crear el GSA y el binding `roles/iam.workloadIdentityUser` (en un script `scripts/provision-wif.sh` que **no se ejecuta** contra GCP).
3. Escribir un **ADR** comparando esta solución con IRSA (EKS) y justificando por qué el equipo prefiere WIF for GKE.

**Importante**: no hay project GCP real. Usa `my-project-123` como placeholder; **no incluyas IDs reales**. El script `provision-wif.sh` **no se ejecuta** contra GCP — se valida solo con `bash -n` (syntax check) y con `grep` sobre los comandos esperados.

Opcionalmente, puedes cargar los manifiestos K8s en un **cluster `kind` local** para validar que son K8s válidos (la anotación de WIF no "hace nada" en kind — es un identificador de texto —, pero el YAML sí se admite y los objetos se crean).

## 3. Objetivos

Al terminar deberías poder:

- Anotar un K8s ServiceAccount con `iam.gke.io/gcp-service-account: <email>` correctamente.
- Montar ese SA en un Deployment vía `spec.template.spec.serviceAccountName`.
- Escribir el comando `gcloud iam service-accounts add-iam-policy-binding` que concede `roles/iam.workloadIdentityUser` al principal especial `serviceAccount:<project>.svc.id.goog[<ns>/<ksa>]`.
- Explicar por qué montar una service account key JSON es un anti-patrón incluso con rotación.
- Comparar IRSA vs WIF for GKE en al menos 3 dimensiones.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §4 completo y recorrido `../../examples/02-workload-identity-walkthrough/`.
- Herramientas: `bash`, `kubectl` (opcional pero recomendado para `--dry-run=client`), `python3` (opcional, para parseo YAML), `yamllint` (opcional). Un editor de texto.
- Opcional: `kind` instalado para probar manifiestos en un cluster local.

**Costos**: ninguno. No hay cluster GKE real; no hay billing.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-07-02-wif/k8s
mkdir -p /tmp/gcp-07-02-wif/scripts
cd /tmp/gcp-07-02-wif
```

### 5.2 Escribe `k8s/serviceaccount-and-deployment.yaml`

Un único archivo YAML multi-documento con:

**Documento 1 — ServiceAccount anotado**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: checkout-app
  namespace: checkout
  annotations:
    iam.gke.io/gcp-service-account: checkout-app@my-project-123.iam.gserviceaccount.com
```

**Documento 2 — Deployment** que usa el SA, con imagen tipo:

```
europe-west1-docker.pkg.dev/my-project-123/apps/checkout:v1.0.0
```

y con `spec.template.spec.serviceAccountName: checkout-app`. No debe haber:

- Ningún `env` con `GOOGLE_APPLICATION_CREDENTIALS`.
- Ningún `volume` con `secret:` que monte una key JSON.
- Ningún `envFrom.secretRef` apuntando a una SA key.

Requisitos mínimos que el validador comprueba:

- `kind: ServiceAccount` y `kind: Deployment` presentes.
- Anotación `iam.gke.io/gcp-service-account:` con un email `*@*.iam.gserviceaccount.com`.
- Email de GSA en formato `<name>@<project>.iam.gserviceaccount.com` con `<project>` idéntico al que usarás en el principal del script.
- `serviceAccountName: checkout-app` en el Deployment.
- Ausencia de `GOOGLE_APPLICATION_CREDENTIALS` y de secrets de key JSON (grep negativo).

### 5.3 Escribe `scripts/provision-wif.sh`

Un script **bash** que **no se ejecuta** contra GCP (se valida con `bash -n`). Debe:

- Empezar con `#!/usr/bin/env bash` y `set -eu` (sin `pipefail`, por la nota al pie: muchos pipelines con `grep -q` producen SIGPIPE).
- Definir variables arriba: `PROJECT_ID`, `GSA_NAME`, `KSA_NAME`, `KSA_NAMESPACE`, `BUCKET` (todas con placeholders).
- Incluir, al menos, estos comandos (que **no se ejecutan** aquí, se documentan como referencia para Fase 4):
  1. `gcloud iam service-accounts create ...` para el GSA.
  2. `gcloud projects add-iam-policy-binding` **o** `gcloud storage buckets add-iam-policy-binding` para dar un rol como `roles/storage.objectViewer` al GSA.
  3. `gcloud iam service-accounts add-iam-policy-binding ... --role="roles/iam.workloadIdentityUser" --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${KSA_NAMESPACE}/${KSA_NAME}]"`.
  4. `kubectl annotate serviceaccount ... iam.gke.io/gcp-service-account=...` (o aplicar el YAML — la anotación debe quedar presente en el cluster).
- Un comentario al inicio aclarando: **"dry-run reference — do NOT execute against a real GCP project"**.

El validador comprueba que el script:

- Pasa `bash -n`.
- Es ejecutable (`chmod +x`).
- Contiene las strings `workloadIdentityUser`, `svc.id.goog[`, `add-iam-policy-binding`, `iam.gke.io/gcp-service-account`.
- Marca claramente "dry-run" o "do NOT execute" en un comentario.

Haz `chmod +x scripts/provision-wif.sh`.

### 5.4 (Opcional) Valida los manifiestos K8s con kind

Si tienes `kind` y `kubectl`:

```bash
# Crea un cluster kind efímero (si no tienes uno).
kind create cluster --name wif-test

# El namespace tiene que existir antes.
kubectl create namespace checkout

# Dry-run cliente (parsea el YAML sin aplicar).
kubectl apply --dry-run=client -f /tmp/gcp-07-02-wif/k8s/serviceaccount-and-deployment.yaml

# O dry-run servidor (requiere el cluster activo).
kubectl apply --dry-run=server -f /tmp/gcp-07-02-wif/k8s/serviceaccount-and-deployment.yaml

# Si quieres, aplicalo de verdad en kind (no hace nada contra GCP, es un cluster local):
kubectl apply -f /tmp/gcp-07-02-wif/k8s/serviceaccount-and-deployment.yaml

# Limpia.
kind delete cluster --name wif-test
```

**Importante**: `kind` es un cluster K8s local; **no se conecta a GCP**. La anotación `iam.gke.io/gcp-service-account` queda guardada como texto, nada más. El valor real de WIF se obtiene solo en un cluster GKE con `workload_pool` habilitado — lo que no hacemos aquí.

### 5.5 Escribe `WORKLOAD-IDENTITY-ADR.md`

Formato ADR estándar. Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio:

- Mención explícita de **IRSA** (IAM Roles for Service Accounts, AWS/EKS) y de **WIF** (Workload Identity Federation for GKE), comparados en al menos 3 dimensiones (piezas, trust policy, rotación, principal, ...).
- Mención del **principal especial `svc.id.goog[<ns>/<ksa>]`**.
- Mención del rol `roles/iam.workloadIdentityUser`.
- Mención del **anti-patrón** de montar service account keys JSON como Secret K8s.
- Mención del **error silencioso**: si el cluster no tiene `workload_pool` habilitado, la anotación se ignora y el pod obtiene credenciales del node service account.

### 5.6 Entregables

```
/tmp/gcp-07-02-wif/
├── k8s/
│   └── serviceaccount-and-deployment.yaml
├── scripts/
│   └── provision-wif.sh          (chmod +x; dry-run reference)
└── WORKLOAD-IDENTITY-ADR.md
```

## 6. Resultado esperado

- Los 3 archivos existen.
- YAML parsea.
- Script pasa `bash -n` y es ejecutable.
- ADR tiene las 6 secciones y el contenido mínimo.
- Validador en verde: `0 issue(s)`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Correctitud K8s**: `kubectl apply --dry-run=client` del YAML pasa (si tienes kubectl).
- **Correctitud bash**: `bash -n provision-wif.sh` pasa; el script no corre nada contra GCP.
- **Calidad del ADR**: justificación de cada decisión; comparación IRSA vs WIF concreta.
- **Mantenibilidad**: YAML indentado consistente; script con variables al inicio; ADR legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-07-02-wif
```

El validador comprueba:

1. Existencia de los 3 archivos.
2. `k8s/serviceaccount-and-deployment.yaml` parsea como YAML (via `python3 -c "import yaml; ..."` si está disponible; si no, con parseo laxo).
3. YAML contiene `kind: ServiceAccount`, `kind: Deployment`, anotación WIF correcta, `serviceAccountName`, y **no** contiene `GOOGLE_APPLICATION_CREDENTIALS` ni secret-of-key patterns.
4. `scripts/provision-wif.sh` pasa `bash -n`, es ejecutable, contiene las strings esperadas y marca "dry-run / do NOT execute".
5. `WORKLOAD-IDENTITY-ADR.md` tiene las 6 secciones y el contenido mínimo.

**No** se ejecuta el script contra GCP. **No** se requiere un cluster GKE real.

## 9. Preguntas de reflexión

1. Si olvidas la anotación en el K8s SA pero haces el binding `workloadIdentityUser`, ¿qué credenciales usa el pod?
2. Si el binding tiene un typo (`[checkout/checkout-ap]` en vez de `[checkout/checkout-app]`), ¿cómo diagnosticas el error desde el pod?
3. ¿Por qué el principal es `[<ns>/<ksa>]` y no `[<cluster>/<ns>/<ksa>]`? ¿Cómo evita colisión entre clusters distintos del mismo project?
4. ¿Qué pasa si usas el **mismo GSA** para dos K8s SAs en namespaces distintos? ¿Es un anti-patrón?
5. Un auditor pregunta: "¿quién puede impersonar `checkout-app@my-project-123.iam.gserviceaccount.com`?". ¿Qué comando `gcloud` corres?

## 10. Extensiones

- Añade un `k8s/network-policy.yaml` que restrinja la salida del namespace `checkout` solo a Google APIs (necesario para que el metadata server funcione).
- Añade al script `provision-wif.sh` una sección "verify" que (opcional, si hubiera cluster) comprobara con `kubectl exec` que el pod recibe un token válido vía `gcloud auth print-access-token`.
- Añade un segundo workload (`training-app` en namespace `training`) con su propio GSA y binding, y actualiza el ADR explicando por qué **no** reutilizas el GSA de `checkout-app`.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-07-02-wif
# Si creaste un cluster kind:
kind delete cluster --name wif-test 2>/dev/null || true
```

No hay infraestructura GCP que detener (nunca se ejecutó nada contra GCP).
