# REFERENCE — gcp-07-02-workload-identity-federation-walkthrough

> Una **referencia** razonada. No es la única respuesta correcta.

---

## Manifiesto K8s de referencia (`k8s/serviceaccount-and-deployment.yaml`)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: checkout-app
  namespace: checkout
  annotations:
    iam.gke.io/gcp-service-account: checkout-app@my-project-123.iam.gserviceaccount.com

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-app
  namespace: checkout
  labels:
    app: checkout-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: checkout-app
  template:
    metadata:
      labels:
        app: checkout-app
    spec:
      serviceAccountName: checkout-app
      # NO env GOOGLE_APPLICATION_CREDENTIALS; NO secret-of-key mount.
      containers:
        - name: app
          image: europe-west1-docker.pkg.dev/my-project-123/apps/checkout:v1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: BUCKET
              value: checkout-assets-prod
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
```

## Script de referencia (`scripts/provision-wif.sh`)

Ver `starter/scripts/provision-wif.sh` — la versión del starter ya está completa y es la de referencia. Lo esencial:

- `set -eu` (sin `pipefail`, por la nota al pie: evita SIGPIPE en pipelines con `grep -q`).
- Variables al inicio (`PROJECT_ID`, `GSA_NAME`, `GSA_EMAIL`, `KSA_NAMESPACE`, `KSA_NAME`, `BUCKET`).
- 4 comandos (comentados / dry-run):
  1. `gcloud iam service-accounts create ${GSA_NAME} --project=${PROJECT_ID}`
  2. `gcloud storage buckets add-iam-policy-binding gs://${BUCKET} --member=serviceAccount:${GSA_EMAIL} --role=roles/storage.objectViewer`
  3. `gcloud iam service-accounts add-iam-policy-binding ${GSA_EMAIL} --role=roles/iam.workloadIdentityUser --member=serviceAccount:${PROJECT_ID}.svc.id.goog[${KSA_NAMESPACE}/${KSA_NAME}]`
  4. `kubectl apply -f ../k8s/serviceaccount-and-deployment.yaml`
- Marca clara `DRY-RUN REFERENCE — do NOT execute`.
- `chmod +x` para que sea ejecutable.

---

# ADR 001 — Workload Identity Federation for GKE para `checkout-app`

## Estado

Aceptado (Fase 3). Materializado en Fase 4 cuando el cluster GKE esté provisionado.

## Contexto

El equipo de `checkout-app` lleva 6 meses operando el Deployment con una **service account key JSON** montada como `Secret` K8s. La key se rota manualmente cada 90 días. Security pide eliminar esta práctica porque:

1. La org tiene una org policy `iam.disableServiceAccountKeyCreation` planeada para Fase 4 — las nuevas keys dejarán de poder crearse.
2. La key filtra fácil: cualquier `kubectl get secret -o yaml` con los permisos adecuados la expone.
3. La rotación manual implica downtime o un ventana con dos keys válidas simultáneamente.
4. El audit trail del acceso al bucket aparece bajo el GSA sin forma trivial de atribuirlo a *qué pod* lo hizo (el pod se puede identificar por *principal*, pero la key no distingue).

Alternativa evaluada: **Workload Identity Federation for GKE** (lo que se decide aquí) y **IRSA** (si se migra a EKS). La org está en GCP; EKS está descartado.

## Decisión

Adoptar **Workload Identity Federation for GKE** para `checkout-app`:

1. Habilitar `workload_identity_config.workload_pool = "my-project-123.svc.id.goog"` en el cluster GKE (ya cubierto por la actividad 01).
2. Crear un **Google Service Account** dedicado por aplicación (`checkout-app@my-project-123.iam.gserviceaccount.com`). **Un GSA por app**; no reutilizar entre apps.
3. Conceder al GSA solo los roles IAM necesarios sobre los recursos destino (`roles/storage.objectViewer` sobre el bucket específico, no project-wide).
4. Conceder `roles/iam.workloadIdentityUser` al principal especial `serviceAccount:my-project-123.svc.id.goog[checkout/checkout-app]` sobre el GSA. Este binding es lo que **autoriza al pod** a impersonar al GSA.
5. Anotar el K8s ServiceAccount con `iam.gke.io/gcp-service-account: checkout-app@my-project-123.iam.gserviceaccount.com`.
6. Usar `spec.template.spec.serviceAccountName: checkout-app` en el Deployment.
7. **Eliminar** del repo y del cluster: el `Secret` con la key JSON, la variable `GOOGLE_APPLICATION_CREDENTIALS`, y la rotación manual programada.

### Comparación IRSA (EKS) vs WIF for GKE

| Dimensión | IRSA (EKS) | WIF for GKE |
|-----------|------------|-------------|
| Piezas que crear | OIDC Provider del cluster, IAM Role con trust policy OIDC específica, K8s SA anotado | GSA, binding `workloadIdentityUser` sobre el GSA, K8s SA anotado |
| Trust policy | **Explícita en JSON** por cada role, apunta al OIDC provider del cluster y al `sub` esperado | **Implícita** vía el rol `roles/iam.workloadIdentityUser` sobre el principal `svc.id.goog[ns/ksa]` |
| Rotación | Automática (tokens STS de corta vida) | Automática (tokens federados de corta vida) |
| Nombre del principal | ARN del IAM Role en la anotación | Email del GSA en la anotación |
| Vulnerable a confused-deputy entre clusters | Posible si el trust policy no restringe `sub` por cluster + SA | Posible si el binding se abre a `[*/\*]` en lugar de `[<ns>/<ksa>]` concreto |
| Cambiar cluster | Hay que re-emitir el OIDC provider y re-escribir trust policies | Nuevo workload pool, re-binding |
| Error silencioso típico | Olvidar `eks:aud` en el trust policy → `AssumeRoleWithWebIdentity` falla ruidoso | Olvidar `workload_pool` en el cluster → anotación ignorada, pod usa credenciales **del node** (silencioso) |

En conjunto, **WIF for GKE** tiene **menos piezas de JSON** (no hay trust policy explícito) y es más ergonómico. A cambio, el error silencioso del punto final es más peligroso que su equivalente IRSA: si olvidas `workload_pool`, los pods siguen funcionando pero con el service account **del node** (que normalmente tiene permisos de logging/monitoring, no acceso al bucket).

## Consecuencias

### Positivas

- Fin de las service account keys. Compatible con la org policy futura.
- Rotación automática: tokens federados de minutos de vida.
- Audit trail más limpio: cada acceso al bucket queda registrado bajo el GSA + principal pod identificable.
- Compatible con GitOps: toda la configuración vive en YAML + Terraform.
- Prepara el terreno para `gcp-10` (Binary Authorization, WIF para pipelines de CI/CD).

### Negativas

- Error silencioso si `workload_pool` no está habilitado en el cluster. **Mitigación**: validar en Fase 4 con un `kubectl exec` + `curl` al metadata server para confirmar que el token devuelto es del GSA esperado.
- Un principal más que entender para el equipo (`svc.id.goog[ns/ksa]`). **Mitigación**: documentar en el runbook; añadir ejemplo en el onboarding.
- Un GSA por app aumenta el inventario de identidades IAM. **Mitigación**: Terraform-genera-GSA junto al Deployment, versionado. Lifecycle gestionado.

## Alternativas descartadas

### Alternativa A: Mantener la service account key JSON

- Status quo. **Por qué no**: incompatible con la org policy futura; filtra fácil; rotación manual; audit trail pobre. Era la práctica legacy, no una decisión.

### Alternativa B: Dar permisos al node service account

- "Que el node tenga `roles/storage.objectViewer` y todo pod en el node hereda".
- **Por qué no**: viola *least privilege*. Un pod comprometido de **otra** app en el mismo node obtendría los mismos permisos. Pierde trazabilidad por app.

### Alternativa C: Montar un token OIDC propio y hacer `AssumeRoleWithWebIdentity` manualmente

- Posible en teoría si no estuviéramos en GKE. **Por qué no**: GKE ya tiene WIF integrado via metadata server; replicarlo a mano es trabajo innecesario y propenso a errores.

### Alternativa D: Migrar a Cloud Run (sin pods)

- Cloud Run tiene un modelo similar: una Service Account GCP se asigna al servicio y las librerías cliente la usan automáticamente, sin anotación K8s.
- **Por qué no (ahora)**: `checkout-app` tiene requisitos K8s (StatefulSet planeado para una fase futura, afinidad por nodo para co-tenencia). Si estos no se materializan, migrar a Cloud Run quedaría abierto como opción.

---

## Checklist de verificación en Fase 4

- [ ] Cluster GKE con `workload_identity_config.workload_pool` configurado y verificado (`gcloud container clusters describe ... --format='value(workloadIdentityConfig.workloadPool)'`).
- [ ] GSA `checkout-app@...` creado con solo los roles mínimos.
- [ ] Binding `roles/iam.workloadIdentityUser` con el principal exacto `svc.id.goog[checkout/checkout-app]`.
- [ ] K8s SA aplicado con la anotación correcta.
- [ ] Deployment usando `serviceAccountName: checkout-app`.
- [ ] Validación en runtime: `kubectl exec` + curl al metadata server devuelve el email del GSA.
- [ ] Service account key JSON **eliminada** del repo (y del cluster como Secret).
- [ ] Alerta configurada: si alguien crea una nueva key del GSA, dispara pager (org policy futura lo bloqueará, pero defensa en profundidad).
