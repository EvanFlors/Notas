# Example 01 — Instalar Flux y primera `Kustomization`

Instala Flux en un cluster `kind` local, apunta a un repo público, aplica una `Kustomization` y verifica reconciliación.

## Qué demuestra

- `flux install` (equivalente de `argocd install`).
- `GitRepository` + `Kustomization` como mínima unidad reconciliada.
- Observación con `flux get` y `kubectl` sin UI.
- Comparación conceptual con la primera Application de Argo CD.

## Requisitos

- `kind`, `kubectl`
- CLI `flux` (`brew install fluxcd/tap/flux`)

Si falta `flux` o `kind`, el script **saldrá limpiamente** con un mensaje "SKIP" y código 0 (para que el estudiante pueda leer el ejemplo sin ejecutarlo).

## Ejecutar

```bash
bash run.sh
```

El script:

1. Verifica dependencias; si faltan, SKIP.
2. Crea un cluster `kind` nombrado `flux-ex01` (si no existe).
3. Hace `flux check --pre` y luego `flux install`.
4. Crea un `GitRepository` apuntando al repo público `stefanprodan/podinfo` (branch `master`).
5. Crea una `Kustomization` que aplica `kustomize/base` de ese repo en el namespace `podinfo`.
6. Espera `Ready=True` y lista pods.
7. Imprime equivalencias con Argo CD.

## Limpieza

```bash
bash cleanup.sh
```

Borra el cluster `kind` y el scratch `/tmp/flux-ex01`.

## Equivalencias Argo CD → Flux

| Argo CD | Flux |
|---|---|
| `argocd app create podinfo --repo https://… --path kustomize/base --dest-namespace podinfo` | `GitRepository` (repo) + `Kustomization` (path + target namespace) |
| `argocd app sync podinfo` | `flux reconcile kustomization podinfo` |
| UI → árbol de recursos | `kubectl -n podinfo get all` + `flux tree kustomization podinfo` |
| `argocd app get podinfo` | `flux get kustomization podinfo` |
