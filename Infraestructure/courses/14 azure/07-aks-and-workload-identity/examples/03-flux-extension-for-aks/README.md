# Example 03 — Flux v2 vía `az k8s-extension` (GitOps nativo en AKS)

> **Lectura y análisis.** Secuencia CLI anotada; no se ejecuta aquí (requeriría un cluster real).

## Objetivo

Entender por qué GitOps en AKS **no** suele instalarse "a mano" con Helm charts: Microsoft ofrece Flux v2 como **extensión gestionada** (`microsoft.flux`) que se habilita por CLI o Terraform y se upgradea con el cluster.

## Patrón

Dos recursos conceptuales:

1. **Extension** (`microsoft.flux`): instala en el cluster los controladores (source, kustomize, helm, notification). Equivalente a `flux install` pero gestionado.
2. **Flux configuration** (`az k8s-configuration flux ...`): declara **de qué repo** se sincroniza qué path, con qué intervalo y qué tipo de kustomization aplicar.

## CLI (secuencia)

```bash
# 0. Variables (todos los IDs son placeholders — adapta a tu entorno).
RG=rg-az07-demo
CLUSTER=aks-az07-demo
GIT_URL=https://github.com/example-org/az07-gitops.git

# 1. Habilitar el provider si no lo esta (una vez por subscription).
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ContainerService

# 2. Instalar la extension microsoft.flux en el cluster.
az k8s-extension create \
  --resource-group "$RG" \
  --cluster-name "$CLUSTER" \
  --cluster-type managedClusters \
  --name flux \
  --extension-type microsoft.flux \
  --auto-upgrade-minor-version true

# 3. Crear una Flux configuration apuntando al repo.
az k8s-configuration flux create \
  --resource-group "$RG" \
  --cluster-name "$CLUSTER" \
  --cluster-type managedClusters \
  --name apps \
  --namespace flux-system \
  --scope cluster \
  --url "$GIT_URL" \
  --branch main \
  --interval 1m \
  --kustomization name=root path=./clusters/aks-az07-demo prune=true

# 4. Verificar.
kubectl get pods -n flux-system
kubectl get gitrepository,kustomization -A
```

## Terraform equivalente (extracto)

```hcl
resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.this.id
  extension_type = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "apps" {
  name       = "apps"
  cluster_id = azurerm_kubernetes_cluster.this.id
  namespace  = "flux-system"

  git_repository {
    url             = "https://github.com/example-org/az07-gitops.git"
    reference_type  = "branch"
    reference_value = "main"
  }

  kustomizations {
    name                       = "root"
    path                       = "./clusters/aks-az07-demo"
    garbage_collection_enabled = true
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}
```

## Diferencias vs instalar Flux "a mano"

| Dimensión | `microsoft.flux` (extensión) | `flux install` (OSS directo) |
|-----------|-----------------------------|------------------------------|
| Upgrades de los controladores | Automáticos (`auto-upgrade-minor-version`) | Tú corres `flux install` con la versión nueva |
| Soporte Microsoft | Sí (ticket al cluster incluye Flux) | No (ticket upstream) |
| Multi-cluster via Azure Arc | Mismo flujo funciona en clusters on-prem con Arc | Sí, pero sin unificar con Azure control plane |
| Configuración | `az k8s-configuration flux` | `flux create source git ...` |
| Debug | `kubectl -n flux-system logs ...` + `az k8s-extension show` | `kubectl -n flux-system logs ...` + `flux reconcile ...` |

Recomendación: **extensión** en greenfield. Instalar Flux a mano solo si hay un requisito muy concreto (p. ej. una versión más nueva que la que la extensión ofrece).

## Lo que esta extensión NO hace

- No decide la **estructura del repo** por ti (sigue siendo tu problema: `./clusters/<name>/`, `./base/`, overlays, etc.).
- No valida tus manifests: si tu `Kustomization` referencia un path que no existe, el reconcile falla silenciosamente hasta que miras `kubectl describe kustomization`.
- No reemplaza un buen flujo de PR + review en el repo Git — es la **entrega** al cluster, no la **gobernanza** del cambio.
