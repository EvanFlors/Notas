# Ejemplo 02 — XRD + Composition para "NamespaceProduct"

## Objetivo

Mostrar el **par mínimo** XRD + Composition que publica un *producto de plataforma* real: un `NamespaceProduct` que, dado 3 inputs (`name`, `tier`, `env`), materializa tres recursos K8s nativos:

- Un `Namespace` con labels de FinOps.
- Un `ResourceQuota` cuyos valores dependen de `tier`.
- Una `NetworkPolicy` default-deny.

## Prerrequisito

Haber corrido `examples/01-crossplane-install-in-kind/run.sh` con éxito. Si usas `kubectl config current-context`, debe ser `kind-plat-09-ex01`.

## Archivos

- `xrd.yaml` — el **contrato** del producto. Define el claim `NamespaceProductClaim` (namespaced) y el composite `XNamespaceProduct` (cluster-scoped).
- `composition.yaml` — la **receta** que convierte 1 composite en 3 `Object` MRs.
- `claim.yaml` — el **ejemplo** que un developer crearía.
- `run.sh` — aplica XRD + Composition + Claim y valida que materializa.
- `cleanup.sh` — borra el claim, la composition, el xrd y el namespace del claim.

## Flujo

```
claim.yaml  (NamespaceProductClaim, namespaced)
   │
   ▼
Crossplane crea XR  (XNamespaceProduct, cluster-scoped)
   │
   ▼
Composition produce 3 Object MRs
   │
   ├─> Namespace "<name>"
   ├─> ResourceQuota "<name>-quota"   (requests.cpu/memory por tier)
   └─> NetworkPolicy "<name>-deny-all" (default-deny)
```

## Qué chequea `run.sh`

1. XRD aplicado y `Established=True`.
2. Composition aplicada.
3. Claim aplicado en el namespace del team (`team-foo`).
4. Después del reconcile, el namespace `demo-ns` existe con labels esperados.
5. El `ResourceQuota demo-ns-quota` existe con `requests.cpu=2` (porque `tier=small`).
6. La `NetworkPolicy demo-ns-deny-all` existe y es default-deny.

## Ejecutar

```bash
bash run.sh
```

## Limpiar

```bash
bash cleanup.sh
```
