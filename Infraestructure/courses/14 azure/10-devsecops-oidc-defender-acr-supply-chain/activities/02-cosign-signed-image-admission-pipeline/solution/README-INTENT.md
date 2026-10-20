# Intent — supply chain pipeline para checkout

> Documento de intencion: que firma la CI, que verifica el cluster, donde se adjunta y que excepciones existen.

## Resumen

| Pieza | Donde | Que hace |
|-------|-------|----------|
| Workflow `build-sign-push.yml` | GitHub Actions (repo `acme/checkout`) | Build + push a `acrcheckoutprod.azurecr.io/checkout:<sha>` + `cosign sign` keyless con el OIDC del runner. |
| Kyverno `ClusterPolicy` | AKS `aks-checkout-prod`, namespace `checkout-prod` | Rechaza pods cuya imagen `acrcheckoutprod.azurecr.io/checkout*` no tenga firma cosign valida. |

---

## Pipeline de firma

### Como firma sin ningun secret

El runner de GitHub Actions pide un **OIDC id_token** (con `permissions: id-token: write`) para dos destinos distintos:

1. **Azure (Entra ID)**: para autenticarse al tenant y hacer `az acr login`.
2. **Fulcio (sigstore)**: para que Fulcio emita un cert X.509 efimero (10 min) cuyo SAN contiene la identidad del workflow: `https://github.com/acme/checkout/.github/workflows/build-sign-push.yml@refs/heads/main`.

`cosign sign` firma el **digest** de la imagen con la clave privada temporal asociada al cert y publica la firma como OCI artifact adyacente a la imagen en ACR. Ademas registra la transparencia en **Rekor** (log append-only publico de sigstore).

### Por que **keyless** y no una clave propia en Key Vault

Keyless elimina la custody de una priv key. No hay clave que rotar, custodiar ni leakear. El trade-off es que los metadatos de la firma quedan publicos en Rekor; aceptable para este repo (los digests no revelan secretos y el repo es privado — su nombre no es sensible).

### Por que el `environment: prod`

El job declara `environment: prod` en GHA. Esto habilita el **required reviewers** del environment, forzando que un segundo humano apruebe cada deploy a prod. Combinado con un federated credential pinneado a `repo:acme/checkout:environment:prod`, un push a main **no** basta por si solo para desplegar prod.

---

## Policy de admission

### Donde se adjunta

Kyverno instalado cluster-wide; la `ClusterPolicy` filtra por `namespaces: [checkout-prod]`. No tocamos otros namespaces para no romper tooling (ingress controller, dapr, etc.) que corre bajo otras identidades.

### Que verifica

- Que la imagen venga de `acrcheckoutprod.azurecr.io/checkout*`.
- Que haya una firma cosign asociada.
- Que la firma la haya producido el workflow concreto `.github/workflows/build-sign-push.yml` en `refs/heads/main`.
- Que el issuer sea `https://token.actions.githubusercontent.com` (nadie fuera de GHA puede falsificar).
- Que la transparencia este en Rekor (`https://rekor.sigstore.dev`).

### Enforce, no Audit

`validationFailureAction: Enforce` desde el dia uno. En Audit la policy **registra** pero **no bloquea** — util en rollout de 1–2 semanas para ver quien tiene imagenes historicas sin firma, pero **inseguro como estado final**. Para `checkout-prod` arrancamos en Enforce porque las imagenes existentes ya se re-firmaron.

`failurePolicy: Fail`: si el webhook esta caido, los pods **no** se admiten. Trade-off: downtime del webhook == downtime de deploys nuevos. Mitigacion: Kyverno con 2 replicas HA + PDB.

### Pin al workflow concreto (no al repo)

Si pinneamos solo `repo:acme/checkout` sin workflow, cualquier otro workflow en el repo que configure OIDC podria firmar imagenes y pasar la verificacion. Pinnear a `/.github/workflows/build-sign-push.yml@refs/heads/main` restringe quien puede producir una firma aceptable.

---

## Excepciones y rollout

### Rollout

1. **Semana 0**: policy en modo `Audit` en `checkout-stg`. Se identifican imagenes historicas sin firma. Se re-build + re-push + re-sign con el workflow nuevo.
2. **Semana 1**: policy en `Audit` en `checkout-prod`. Se corren varios deploys para confirmar que no hay falsos negativos.
3. **Semana 2**: switch a `Enforce` en `checkout-prod` (ya con todas las imagenes activas firmadas).
4. **Semana 2+**: `Enforce` por defecto en nuevos namespaces de workloads sensibles.

### Excepciones

- **Imagenes de infra** (nginx-ingress, cert-manager, dapr): no estan firmadas por nosotros. Viven en namespaces separados (`ingress-system`, `cert-manager`, `dapr-system`) **excluidos** del match de la ClusterPolicy. Para su seguridad confiamos en Defender for Containers vuln scanning + imagen pinneada por digest.
- **BreakGlass**: si Rekor publico esta caido, documentamos como relajar temporalmente la policy (parchear `rekor:` o pasar a `Audit`) **solo** con approval de Security + registro en el runbook. **No** se deja relajada mas de 60 min.

### Que no cubre esta policy

- No valida **SBOM** adjunto a la imagen. Extension: segunda rule con `verifyImages.attestations` apuntando a `type: https://spdx.dev/Document`.
- No valida **vuln severity**. Para eso usamos Defender for Containers + un gate en el pipeline (trivy fail on CRITICAL).
- No cubre **DaemonSets** del propio Kyverno o del Defender sensor; esos corren fuera del namespace matched.
