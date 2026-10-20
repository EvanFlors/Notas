# Ejemplo 01 — Promoción por branches en el repo de infra

## Concepto que demuestra

Promover un cambio `dev → stg → prod` **mergeando branches** en un único repo de infra, con tres Applications que apuntan al mismo `path` pero distinto `targetRevision`.

## Contexto

Es el patrón más simple y suficiente cuando los ambientes son copias del mismo stack con, principalmente, `image.tag` distinto. El DAG de Git es el pipeline de promoción.

## Objetivo

Al terminar, podrás responder:

- ¿Qué cambia físicamente al "promover"?
- ¿Cómo verifica Argo CD qué commit está desplegado por ambiente?
- ¿Por qué este modelo degrada cuando los ambientes divergen de verdad?

## Prerrequisitos

- `kind` + `kubectl` + Argo CD CLI instalados.
- Argo CD operativo en el cluster (ver `argo-02`).
- Un repo Git local (lo creamos en `/tmp/`).

## Ejecución

Scratch limpio y repo local simulando el "repo de infra":

```bash
# Preparar scratch
BASE=/tmp/argo-12-ex01
rm -rf "$BASE" && mkdir -p "$BASE" && cd "$BASE"

# Repo de infra local (bare + working copy)
git init --bare infra.git
git clone infra.git infra && cd infra
git config user.email demo@example.com
git config user.name  Demo
mkdir -p platform/foo

cat > platform/foo/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: foo }
spec:
  replicas: 1
  selector: { matchLabels: { app: foo } }
  template:
    metadata: { labels: { app: foo } }
    spec:
      containers:
        - name: foo
          image: nginx:1.25.0
EOF

git add . && git commit -m "init: foo at nginx:1.25.0"
git branch dev
git branch stg
git push origin main dev stg
```

Tres Applications, una por ambiente. Mismo `path`, distinta `targetRevision`:

```bash
cat > /tmp/argo-12-ex01/apps.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: foo-dev, namespace: argocd }
spec:
  project: default
  source:
    repoURL: file:///tmp/argo-12-ex01/infra.git
    path: platform/foo
    targetRevision: dev
  destination: { server: https://kubernetes.default.svc, namespace: foo-dev }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: foo-stg, namespace: argocd }
spec:
  project: default
  source:
    repoURL: file:///tmp/argo-12-ex01/infra.git
    path: platform/foo
    targetRevision: stg
  destination: { server: https://kubernetes.default.svc, namespace: foo-stg }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: foo-prod, namespace: argocd }
spec:
  project: default
  source:
    repoURL: file:///tmp/argo-12-ex01/infra.git
    path: platform/foo
    targetRevision: main
  destination: { server: https://kubernetes.default.svc, namespace: foo-prod }
  syncPolicy:
    automated: { prune: false, selfHeal: false }   # prod: sync manual
    syncOptions: [ CreateNamespace=true ]
EOF

kubectl apply -f /tmp/argo-12-ex01/apps.yaml
```

> Nota: `file:///` solo funciona si el `repo-server` tiene acceso al path. En `kind` real, montarías el repo o usarías un git-server pod. Para la demo, el objetivo es *entender el modelo*, no reproducir cada byte.

Promover `dev → stg`:

```bash
cd /tmp/argo-12-ex01/infra
git checkout dev
sed -i.bak 's/nginx:1.25.0/nginx:1.25.3/' platform/foo/deployment.yaml && rm platform/foo/deployment.yaml.bak
git add -A && git commit -m "feat: bump nginx to 1.25.3"
git push origin dev

# Argo CD ve el nuevo commit en 'dev' y sincroniza foo-dev.
argocd app wait foo-dev --health --timeout 120

# Promover a stg: merge dev → stg
git checkout stg
git merge --no-ff dev -m "promote: dev → stg (nginx 1.25.3)"
git push origin stg
argocd app wait foo-stg --health --timeout 120

# Promover a prod: merge stg → main, luego sync manual (prod es manual)
git checkout main
git merge --no-ff stg -m "promote: stg → main (nginx 1.25.3)"
git push origin main
argocd app sync foo-prod
argocd app wait foo-prod --health --timeout 120
```

Verificar qué ref tiene cada ambiente:

```bash
for env in dev stg prod; do
  echo "== foo-$env =="
  argocd app get foo-$env -o json | jq -r '.status.sync | "revision=\(.revision) status=\(.status)"'
done
```

Ver qué falta por promover:

```bash
cd /tmp/argo-12-ex01/infra
git log --oneline stg..dev        # cambios en dev no promovidos a stg
git log --oneline main..stg       # cambios en stg no promovidos a prod
```

## Limpieza

```bash
kubectl delete -f /tmp/argo-12-ex01/apps.yaml --ignore-not-found
kubectl delete ns foo-dev foo-stg foo-prod --ignore-not-found
rm -rf /tmp/argo-12-ex01
```

## Qué aprender

- "Promover" es *mover una ref*: `git merge --no-ff dev` en el branch destino.
- `git log A..B` responde "qué falta por promover" sin salir de Git.
- La divergencia entre ambientes (replicas distintas, flags) produce **conflictos de merge** permanentes. Esa es la señal clara para migrar a folder/overlay (`examples/02`).
- Prod con `automated: {}` y sync manual (o behind `CODEOWNERS` + PR a `main`) es una práctica razonable aquí: el merge llega sin desplegar hasta que un humano hace `argocd app sync`.
