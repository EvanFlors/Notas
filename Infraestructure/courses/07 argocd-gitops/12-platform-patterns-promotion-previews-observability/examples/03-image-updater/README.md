# Ejemplo 03 — argocd-image-updater con write-back a Git

## Concepto que demuestra

`argocd-image-updater` observa un registry, detecta tags nuevos que cumplen una regla (`semver`), y **escribe un commit** en el repo de infra actualizando el tag. Argo CD ve el commit y reconcilia.

## Contexto

Elimina el paso manual "editar `values.yaml` con el nuevo tag" para ambientes de desarrollo. Es la pieza que convierte un pipeline "build + push" en despliegue automático sin pipeline externo con acceso al cluster.

## Objetivo

- Instalar `argocd-image-updater` con `write-back-method: git`.
- Anotar una Application con `image-list` y `write-back` reglas.
- Observar un commit del bot en el repo de infra tras publicar una imagen nueva.

## Prerrequisitos

- Argo CD operativo.
- Una Application Helm en Argo CD (p. ej. la de `examples/02`).
- Credencial Git con write al repo de infra (SSH key o GitHub App token).
- Registry público o con credenciales (`ghcr.io`, Docker Hub).

## Instalación

```bash
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-image-updater --timeout=180s
```

Credenciales Git para write-back (SSH):

```bash
# Supón que ya tienes un deploy key con write en el repo de infra.
kubectl -n argocd create secret generic git-creds \
  --from-file=sshPrivateKey=$HOME/.ssh/infra_deploy_key
```

Config del repo en Argo CD (requerido para que image updater pueda commitear):

```yaml
# argocd-cm patch
apiVersion: v1
kind: ConfigMap
metadata: { name: argocd-cm, namespace: argocd }
data:
  repositories: |
    - url: git@github.com:org/platform-manifests.git
      sshPrivateKeySecret:
        name: git-creds
        key: sshPrivateKey
```

## Application anotada

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo-dev
  namespace: argocd
  annotations:
    # qué imagen vigilar
    argocd-image-updater.argoproj.io/image-list: foo=ghcr.io/org/foo
    # regla: semver estricto, major 1
    argocd-image-updater.argoproj.io/foo.update-strategy: semver
    argocd-image-updater.argoproj.io/foo.allow-tags: 'regexp:^v1\.\d+\.\d+$'
    # dónde escribir
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: 'helmvalues:/envs/dev/values.yaml'
    argocd-image-updater.argoproj.io/git-branch: dev
spec:
  project: default
  source:
    repoURL: git@github.com:org/platform-manifests.git
    targetRevision: dev
    path: charts/foo
    helm:
      valueFiles: [ '../../envs/dev/values.yaml' ]
  destination: { server: https://kubernetes.default.svc, namespace: foo-dev }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
```

## Simular una nueva imagen

Si usas `ghcr.io/org/foo`, publica un tag nuevo (`v1.3.0`). Para la demo rápida:

```bash
# Logs del controller
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-image-updater -f
```

Al detectar `v1.3.0`, el controller:

1. Hace clone del repo.
2. Edita `envs/dev/values.yaml` (`image.tag: v1.3.0`).
3. `git commit -m "build: automatic update of foo"`.
4. `git push origin dev`.

Argo CD ve el commit y sincroniza `foo-dev`.

## Verificación

```bash
# En el repo de infra:
git log origin/dev --oneline --author='argocd-image-updater' | head
cat envs/dev/values.yaml

# En Argo CD:
argocd app get foo-dev | grep -E 'Target|Sync|Health'
```

## Buenas prácticas

- **Semver estricto** (`allow-tags: 'regexp:^v\d+\.\d+\.\d+$'`), nunca `latest`.
- **Branch de dev** únicamente. Para stg/prod, el patrón es: el bot abre **PR** (write-back-method = `git` + `git-write-back-target` apuntando a un branch efímero + GitHub action que abre PR). Nunca push directo a prod.
- **Author identity distinto** (`[bot]`) para que `CODEOWNERS` y auditoría los distingan.
- **Rate limit**: `argocd-image-updater.argoproj.io/pull-secret` y `interval: 2m` por default; subir si el registry te limita.
- Combinar con firma: Kyverno rechaza imágenes no firmadas → el bot puede escribir el tag, pero el pod no arranca si el firma falla. Doble barrera.

## Limpieza

```bash
kubectl -n argocd delete deploy argocd-image-updater --ignore-not-found
kubectl -n argocd delete secret git-creds --ignore-not-found
```

## Qué aprender

- El bot no reemplaza GitOps: *lo complementa*. El estado deseado sigue en Git.
- "Promoción automática" solo para dev; stg/prod exigen humano/PR.
- `latest` es antipatrón; semver + regex es el default seguro.
- El bot necesita credencial write al repo de infra: trátala como un secret de alto blast radius.
