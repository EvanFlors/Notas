# Ejemplo 03 — AKS con Secrets Store CSI Driver (Azure Key Vault provider)

> Walkthrough conceptual. **No** se provisiona AKS en este módulo (eso es `az-07`). Objetivo: entender cómo cambia el patrón de consumo de secretos cuando el workload corre en AKS.

## 1. Por qué AKS no puede usar `@Microsoft.KeyVault(...)`

La sintaxis `@Microsoft.KeyVault(SecretUri=...)` es un *runtime extension* de App Service y Container Apps. En Kubernetes no hay un runtime equivalente — K8s solo entiende `Secret` objects nativos, `ConfigMap`s o volúmenes.

Para traer un secret de Key Vault a un pod AKS, la receta Azure-nativa es el **Secrets Store CSI Driver** con el **Azure Key Vault provider**, habilitado como add-on gestionado del clúster.

## 2. Las 4 piezas

```
┌──────────────────────────────────────────────────────────────────┐
│                            AKS cluster                            │
│                                                                   │
│  ┌─────────────────┐    ┌────────────────────────────────┐       │
│  │ ServiceAccount  │    │ SecretProviderClass            │       │
│  │ capstone-sa     │    │ azure-kv-capstone              │       │
│  │ (K8s identity)  │    │ (CRD del CSI driver, apunta a  │       │
│  │                 │    │  qué secrets traer y de qué KV)│       │
│  └────────┬────────┘    └──────────────┬─────────────────┘       │
│           │ federated OIDC             │                          │
│           │ (az-07)                    │ CSI volume mount         │
│           ▼                            ▼                          │
│  ┌─────────────────┐    ┌────────────────────────────────┐       │
│  │ User-Assigned   │    │ Pod                            │       │
│  │ Managed Identity│    │  /mnt/secrets/db-connection-...│       │
│  │ id-capstone-aks │    │  (archivo tmpfs read-only)     │       │
│  └────────┬────────┘    └────────────────────────────────┘       │
│           │                                                       │
│           │  Key Vault Secrets User sobre scope del vault         │
│           ▼                                                       │
│   ┌─────────────────────────────────┐                             │
│   │     Azure Key Vault             │                             │
│   │     kv-capstone-dev             │                             │
│   └─────────────────────────────────┘                             │
└──────────────────────────────────────────────────────────────────┘
```

## 3. SecretProviderClass (CRD del CSI driver)

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-capstone
  namespace: capstone
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    # Dummy GUIDs — en un cluster real serían los IDs de tu tenant / MI.
    clientID: "00000000-0000-0000-0000-000000000000"
    tenantId: "00000000-0000-0000-0000-000000000000"
    keyvaultName: "kv-capstone-dev"
    objects: |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
```

## 4. Pod que monta el secret como archivo

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capstone-api
  namespace: capstone
spec:
  serviceAccountName: capstone-sa
  containers:
    - name: api
      image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
      volumeMounts:
        - name: kv-secrets
          mountPath: /mnt/secrets
          readOnly: true
      env:
        - name: DB_CONN_FILE
          value: /mnt/secrets/db-connection-string
  volumes:
    - name: kv-secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: azure-kv-capstone
```

El código lee `open(os.environ["DB_CONN_FILE"]).read().strip()`. **Nunca** aparece el valor en manifests, Helm values ni variables de entorno literales.

## 5. ¿Dónde está la autenticación?

La MI `id-capstone-aks` se enlaza al `ServiceAccount capstone-sa` vía **Workload Identity** (federated credential OIDC). El pod recibe un token proyectado como volumen (`/var/run/secrets/azure/tokens/azure-identity-token`), y el CSI driver lo usa para autenticar contra Entra ID y luego contra Key Vault.

Setup del federated credential (conceptual, cubierto en `az-07`):

```hcl
resource "azurerm_federated_identity_credential" "capstone" {
  name                = "fed-capstone-sa"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.aks_app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:capstone:capstone-sa"
}
```

## 6. Qué comparte con Container Apps y qué cambia

| Aspecto | Container Apps | AKS + CSI driver |
|---------|----------------|-------------------|
| Autenticación a Entra | MI User-Assigned adjunta al recurso | MI User-Assigned + Workload Identity federada al SA |
| Mecanismo de entrega | `env` var inyectada por runtime | archivo montado en volumen tmpfs |
| Pinnear versión | `.id` vs `.versionless_id` | `objectVersion:` en el SPC |
| Rotación en caliente | restart revisión | `--rotation-poll-interval` del CSI driver |
| Audit en vault | `SecretGet` por MI | `SecretGet` por MI (idéntico) |

## 7. Pitfalls

- **No habilitar el add-on**: `az aks enable-addons --addons azure-keyvault-secrets-provider ...` es obligatorio. Sin él, el CRD no existe.
- **`useVMManagedIdentity: "true"` por costumbre**: eso usa la MI del nodo (todos los pods comparten). Para granularidad por workload, `false` + Workload Identity.
- **No crear el ServiceAccount con la anotación `azure.workload.identity/client-id`**: la federation no activa.
- **No crear el `federated_identity_credential` con el `subject` correcto**: `system:serviceaccount:<ns>:<sa>` es sensible a mayúsculas y typos — el token se emite pero el vault rechaza.

## 8. Preguntas de autocomprobación

1. ¿Qué cambia si en el SPC pones `objectVersion: "abc123..."` en vez de omitirlo?
2. ¿Por qué el pod recibe un archivo y no una env var? ¿Puedes convertirlo en env var? (pista: `syncSecret` + K8s `Secret`).
3. Si cambias `useVMManagedIdentity: "false"` por `"true"`, ¿qué principal aparece en el Activity Log del vault?
4. ¿Cómo rotarías un secret y harías que los pods lo relean sin restart?
5. ¿En qué se parece Workload Identity de AKS a IRSA de EKS?
