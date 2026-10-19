# Ejemplo 02 — Workload Identity Federation for GKE — recorrido

> Lectura y análisis. Sin ejecución contra GCP. Objetivo: ser capaz de **recitar** las 5 piezas y el flujo.

## 1. Caso de ejemplo

Un Deployment `checkout-app` en el namespace `checkout` necesita leer objetos de un bucket GCS `gs://checkout-assets-prod`. Sin WIF for GKE, tendrías que montar una **service account key**. Con WIF, no.

## 2. Las 5 piezas y en qué orden se crean

```
1. Cluster GKE con workload_pool habilitado
   ───────────────────────────────────────
   workload_identity_config {
     workload_pool = "proj-platform.svc.id.goog"
   }

2. Google Service Account (GSA)
   ─────────────────────────────
   name:  checkout-app
   email: checkout-app@proj-platform.iam.gserviceaccount.com

3. Rol IAM sobre el bucket (lo que la app PUEDE hacer)
   ──────────────────────────────────────────────────
   gcloud storage buckets add-iam-policy-binding \
     gs://checkout-assets-prod \
     --member="serviceAccount:checkout-app@proj-platform.iam.gserviceaccount.com" \
     --role="roles/storage.objectViewer"

4. Binding del principal especial sobre el GSA
   ────────────────────────────────────────────
   gcloud iam service-accounts add-iam-policy-binding \
     checkout-app@proj-platform.iam.gserviceaccount.com \
     --role="roles/iam.workloadIdentityUser" \
     --member="serviceAccount:proj-platform.svc.id.goog[checkout/checkout-app]"
                                                   ────────  ──────────────
                                                   namespace  k8s SA name

5. Kubernetes ServiceAccount anotado
   ──────────────────────────────────
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: checkout-app
     namespace: checkout
     annotations:
       iam.gke.io/gcp-service-account: checkout-app@proj-platform.iam.gserviceaccount.com
```

Y en el Deployment:

```yaml
spec:
  template:
    spec:
      serviceAccountName: checkout-app   # ← apunta al K8s SA anotado
      containers:
        - name: app
          image: europe-west1-docker.pkg.dev/proj-platform/app/checkout:v1.2.3
          # ninguna variable GOOGLE_APPLICATION_CREDENTIALS; ningún secret montado
```

## 3. Flujo en tiempo de ejecución

```
pod inicia en node
       │
       │ app llama a storage.Client() (SDK Google Cloud)
       ▼
SDK pide token a http://metadata.google.internal/computeMetadata/v1/.../token
       │
       │ interceptado por gke-metadata-server (sidecar por node)
       ▼
gke-metadata-server:
  1) identifica el pod por su ServiceAccount (checkout/checkout-app)
  2) resuelve el principal svc.id.goog[checkout/checkout-app]
  3) ese principal tiene roles/iam.workloadIdentityUser sobre el GSA checkout-app
  4) solicita a IAM un access token federado para el GSA
       │
       ▼
devuelve al pod un access token con los permisos del GSA (storage.objectViewer)
       │
       ▼
pod llama a GCS; GCS resuelve autorización contra el binding del bucket
```

Sin credenciales de larga duración. Sin secret montado. Sin variable de entorno. El token tiene vida corta (minutos) y se renueva transparentemente.

## 4. Qué pasa si falta una pieza

| Falta | Síntoma |
|-------|---------|
| 1. `workload_pool` en el cluster | La anotación se ignora. El pod obtiene credenciales **del node service account**. Falla silencioso: la app parece funcionar pero con permisos equivocados. |
| 2. GSA no existe | La impersonación falla con `PERMISSION_DENIED` al pedir token. |
| 3. Rol IAM sobre el bucket | El pod obtiene token válido del GSA, pero cualquier operación sobre el bucket da `403`. |
| 4. Binding `workloadIdentityUser` sobre el GSA | El pod no puede obtener token: `PERMISSION_DENIED` sobre `iam.serviceAccounts.getAccessToken`. |
| 5. Anotación en el K8s SA | Mismo caso que la pieza 1: credenciales del node. |

## 5. Anti-patrones

- **Montar una service account key** como `Secret` K8s. Rota manualmente, filtra fácil, viola el principio.
- **Dar al node service account** todos los permisos y confiar en que "todo pod en ese node hereda". No distingue entre workloads; viola *least privilege*.
- **Un solo GSA para N apps.** Hace imposible auditar qué app hizo qué: todos los eventos de CloudTrail/Audit Log aparecen con el mismo principal.
- **Olvidar la anotación en el K8s SA.** El pod corre con credenciales del node (ver tabla arriba). Es el error más común.

## 6. Comparación con IRSA (AWS)

| Paso | IRSA (EKS) | WIF for GKE |
|------|------------|-------------|
| 1 | Crear IAM OIDC Provider del cluster | Habilitar `workload_pool` en el cluster |
| 2 | Crear IAM Role con trust policy OIDC específica al cluster | Crear GSA |
| 3 | Dar permisos al IAM Role | Dar permisos al GSA |
| 4 | — (implícito en la trust policy) | Dar `roles/iam.workloadIdentityUser` al principal `svc.id.goog[ns/ksa]` |
| 5 | Anotar K8s SA con `eks.amazonaws.com/role-arn: arn:aws:iam::...` | Anotar K8s SA con `iam.gke.io/gcp-service-account: ...@...iam.gserviceaccount.com` |

WIF for GKE tiene **una pieza más** (el binding en el paso 4), pero elimina el **trust policy JSON** del IRSA (una fuente clásica de errores de typo). En conjunto, WIF for GKE es ligeramente más ergonómico.

## 7. Preguntas de autocomprobación

1. ¿Qué pasa si creas la anotación en el K8s SA pero no has habilitado `workload_pool` en el cluster?
2. Un auditor pregunta: "¿quién puede impersonar al GSA `checkout-app`?". ¿Dónde miras?
3. ¿Por qué el principal se escribe `[namespace/ksa]` y no simplemente `ksa`?
4. Si borras y recreas el cluster con el mismo `workload_pool`, ¿el binding del paso 4 sigue siendo válido? ¿Y si cambias el `workload_pool`?
5. ¿Por qué montar una service account key JSON en un pod es un anti-patrón incluso si rotas la key cada 30 días?
