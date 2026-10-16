# Ejemplo 02 — Promoción por folders/overlays con ApplicationSet

## Concepto que demuestra

Un **único branch** y tres carpetas (`envs/dev`, `envs/stg`, `envs/prod`) con valores distintos; un `ApplicationSet` con Git generator que descubre las carpetas y crea una Application por cada una. Promover = PR que edita `envs/<env>/values.yaml`.

## Contexto

Patrón recomendado cuando los ambientes difieren legítimamente (resources, replicas, feature flags). Un solo repo, un solo branch, diffs claros en PR.

## Objetivo

Al terminar sabrás:

- Cómo el **Git generator** (modo `directories`) descubre folders.
- Cómo se parametriza el `template` con `{{path.basename}}`.
- Cómo `CODEOWNERS` sobre `envs/prod/*` fuerza approval SRE.

## Prerrequisitos

- Argo CD con `applicationset-controller` instalado (viene en el bundle oficial).
- `kubectl` y `yq`.
- Un repo (local o GitHub) con el skeleton descrito abajo.

## Ejecución

Skeleton del repo de infra:

```bash
BASE=/tmp/argo-12-ex02
rm -rf "$BASE" && mkdir -p "$BASE" && cd "$BASE"

mkdir -p infra/charts/foo infra/envs/{dev,stg,prod}

# Chart mínimo (Helm)
cat > infra/charts/foo/Chart.yaml <<'EOF'
apiVersion: v2
name: foo
version: 0.1.0
EOF

cat > infra/charts/foo/values.yaml <<'EOF'
image:
  repository: nginx
  tag: 1.25.0
replicas: 1
resources:
  requests: { cpu: 10m, memory: 32Mi }
EOF

mkdir -p infra/charts/foo/templates
cat > infra/charts/foo/templates/deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: foo
spec:
  replicas: {{ .Values.replicas }}
  selector: { matchLabels: { app: foo } }
  template:
    metadata: { labels: { app: foo } }
    spec:
      containers:
        - name: foo
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          resources: {{- toYaml .Values.resources | nindent 12 }}
EOF

# Overlays por ambiente
cat > infra/envs/dev/values.yaml  <<'EOF'
image: { tag: "1.25.0" }
replicas: 1
EOF
cat > infra/envs/stg/values.yaml  <<'EOF'
image: { tag: "1.25.0" }
replicas: 2
EOF
cat > infra/envs/prod/values.yaml <<'EOF'
image: { tag: "1.25.0" }
replicas: 3
resources: { requests: { cpu: 100m, memory: 128Mi } }
EOF
```

ApplicationSet:

```bash
cat > /tmp/argo-12-ex02/appset.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: { name: foo-envs, namespace: argocd }
spec:
  goTemplate: true
  goTemplateOptions: [ missingkey=error ]
  generators:
    - git:
        repoURL: https://github.com/YOUR_ORG/platform-manifests
        revision: HEAD
        directories:
          - path: envs/*
  template:
    metadata:
      name: 'foo-{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_ORG/platform-manifests
        targetRevision: HEAD
        path: charts/foo
        helm:
          valueFiles:
            - '../../{{.path.path}}/values.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'foo-{{.path.basename}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ CreateNamespace=true ]
EOF
```

Promoción (ejemplo): bumpear `image.tag` en `dev` y luego PR a `stg`:

```bash
# dev
yq -i '.image.tag = "1.25.3"' infra/envs/dev/values.yaml
# PR → merge → ApplicationSet re-renderiza foo-dev con tag 1.25.3

# stg (otro PR, otro revisor según CODEOWNERS)
yq -i '.image.tag = "1.25.3"' infra/envs/stg/values.yaml
```

`CODEOWNERS` sugerido en el repo de infra:

```
# .github/CODEOWNERS
envs/dev/**     @team-foo
envs/stg/**     @team-foo @release-managers
envs/prod/**    @sre @release-managers
charts/**       @platform
```

## Verificación

```bash
kubectl -n argocd get applications
# Esperado: foo-dev, foo-stg, foo-prod generadas por el ApplicationSet.

argocd appset get foo-envs
argocd app diff foo-prod
```

## Limpieza

```bash
kubectl -n argocd delete applicationset foo-envs --ignore-not-found
kubectl delete ns foo-dev foo-stg foo-prod --ignore-not-found
rm -rf /tmp/argo-12-ex02
```

## Qué aprender

- La "promoción" es ahora *un PR que edita exactamente una ruta*. Diff limpio, review preciso.
- `CODEOWNERS` + branch protection es la pieza que convierte el repo en un **contrato de ownership**.
- `goTemplate: true` da expresividad sin templates frágiles (`.path.basename`).
- Añadir un ambiente nuevo = crear `envs/pre/` con un PR. El ApplicationSet lo descubre sin tocar nada más.
