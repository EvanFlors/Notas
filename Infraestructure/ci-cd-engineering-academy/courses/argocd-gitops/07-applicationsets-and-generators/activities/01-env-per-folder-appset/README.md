# Actividad 01 — ApplicationSet con Git generator (env per folder)

## 1. Identificación

- **ID:** `argo-07-01-env-per-folder-appset`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `07-applicationsets-and-generators`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Llevas un `app-of-apps` con tres `Application` casi idénticas: `myapp-dev`, `myapp-stg`, `myapp-prod`. Cada vez que cambias algo compartido lo editas en tres sitios. En esta actividad **colapsas** las tres a un sólo `ApplicationSet` con generator `git.directories` sobre un repo local.

El patrón que practicas aquí es el que usarás en el capstone y en cualquier plataforma Argo CD moderna.

## 3. Objetivos

Al terminar deberías poder:

- Construir, con tus manos, un repo con la estructura `envs/{dev,stg,prod}/`.
- Escribir un `ApplicationSet` con `git.directories` que lo descubra.
- Explicar qué significan `goTemplate: true`, `missingkey=error` y `{{.path.basename}}`.
- Observar el comportamiento al **añadir** y **borrar** carpetas.
- Entender el flag de preservación (`preserveResourcesOnDeletion`).

## 4. Prerrequisitos

- `kubectl` ≥ 1.28.
- `git` ≥ 2.30.
- **Opcional** para la parte "end-to-end": `kind` ≥ 0.22 y Argo CD instalado en un cluster kind con `applicationset-controller`. Si no están presentes el script valida **sólo** la parte estática (manifests y layout del repo).
- `yq` ≥ 4 (sólo para validación avanzada, opcional).

**Costos:** ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
BASE=/tmp/argo-07-01
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"
```

### 5.2 Crear el "repo de infra" local

Simula un repo git con la estructura env-per-folder:

```bash
mkdir -p "$BASE/infra-repo"
cd "$BASE/infra-repo"
git init -b main
git config user.email "dev@example.com"
git config user.name "Dev"

for env in dev stg prod; do
  mkdir -p "envs/$env"
  cat > "envs/$env/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels: { app: myapp, env: $env }
spec:
  replicas: 1
  selector: { matchLabels: { app: myapp } }
  template:
    metadata: { labels: { app: myapp, env: $env } }
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
EOF
done

# Carpeta compartida que NO queremos como App
mkdir -p envs/_shared
echo "# shared manifests, not an env" > envs/_shared/README.md

git add .
git commit -q -m "init: envs/{dev,stg,prod} + _shared"
```

Deberías tener:

```
infra-repo/envs/
├── dev/deployment.yaml
├── stg/deployment.yaml
├── prod/deployment.yaml
└── _shared/README.md
```

### 5.3 Escribir el `ApplicationSet`

Crea el archivo `$BASE/appset.yaml`:

```bash
cat > "$BASE/appset.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-envs
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: file:///tmp/argo-07-01/infra-repo
        revision: HEAD
        directories:
          - path: envs/*
          - path: envs/_shared
            exclude: true
  template:
    metadata:
      name: 'myapp-{{.path.basename}}'
      labels:
        generated-by: git-envs
        env: '{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: file:///tmp/argo-07-01/infra-repo
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'myapp-{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
YAML
```

**Observaciones**:

- `goTemplate: true` activa sintaxis `{{.var}}`; `missingkey=error` convierte typos en fallos de render.
- `exclude: true` sobre `envs/_shared` lo deja fuera.
- `destination.namespace` y `metadata.name` llevan el mismo sufijo → fáciles de rastrear.

### 5.4 Validar sintaxis sin cluster

Con `kubectl --dry-run=client` basta para asegurar que la OpenAPI del CRD acepta el manifest (requiere que el CRD esté instalado en algún cluster accesible; si no, usa `yq` para parsear):

```bash
# Opción A (si tienes un cluster con el CRD):
# kubectl apply --dry-run=client -f "$BASE/appset.yaml"

# Opción B (sin cluster): parsea YAML válido
python3 -c "import yaml,sys; yaml.safe_load_all(open('$BASE/appset.yaml'))" && echo OK
```

### 5.5 (Opcional) Aplicar en kind + argocd

Si tienes un cluster kind con Argo CD:

```bash
kubectl apply -f "$BASE/appset.yaml"
sleep 10
kubectl -n argocd get applicationset myapp-envs
kubectl -n argocd get applications -l generated-by=git-envs
```

Esperado: 3 Applications `myapp-dev`, `myapp-stg`, `myapp-prod`.

### 5.6 Observar el comportamiento al añadir una carpeta

```bash
cd "$BASE/infra-repo"
mkdir -p envs/qa
cp envs/dev/deployment.yaml envs/qa/deployment.yaml
sed -i.bak 's/env: dev/env: qa/g' envs/qa/deployment.yaml && rm envs/qa/deployment.yaml.bak
git add envs/qa
git commit -q -m "feat: add qa env"
```

Si estás en modo end-to-end, en el próximo poll aparece `myapp-qa` **sin editar** el ApplicationSet.

### 5.7 Validar

```bash
bash /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/argocd-gitops/07-applicationsets-and-generators/activities/01-env-per-folder-appset/tests/validate.sh
```

El script detecta si hay kind+argocd y verifica tanto el modo offline como el end-to-end.

## 6. Resultado esperado

- `/tmp/argo-07-01/infra-repo/.git` existe con al menos un commit.
- `envs/dev`, `envs/stg`, `envs/prod` contienen `deployment.yaml`.
- `envs/_shared` existe pero no es un env.
- `/tmp/argo-07-01/appset.yaml` es un `ApplicationSet` válido con `goTemplate: true` y generator `git.directories`.
- Si argocd está disponible: 3 Applications aparecen con label `generated-by=git-envs`.

## 7. Criterios de aceptación

- [ ] Repo local creado con 4 carpetas en `envs/`.
- [ ] ApplicationSet referencia `envs/*` y excluye `_shared`.
- [ ] Usa `goTemplate: true` y `missingkey=error`.
- [ ] `tests/validate.sh` pasa (modo offline o end-to-end).

## 8. Validación

```bash
bash tests/validate.sh
```

El script es idempotente y hace **SKIP graceful** si `kind`/`argocd` no están.

## 9. Preguntas de reflexión

1. ¿Por qué `missingkey=error` es defensivo? Prueba a cambiar `{{.path.basename}}` por `{{.path.basenam}}` (typo) y re-aplica — ¿qué pasa?
2. Si borras `envs/dev/` y haces push, ¿qué pasa con `myapp-dev` y sus recursos? ¿Cómo lo evitarías sin dejar de usar ApplicationSet?
3. ¿Qué cambia si usas `revision: main` en lugar de `revision: HEAD`? ¿Y `revision: v1.2.3`?
4. Imagina 30 microservicios × 3 ambientes. ¿Montarías un `matrix` o un `git.files` catalogando los servicios? Discute pros y contras.
5. ¿Por qué este patrón hace trivial un rollback de un ambiente concreto?

## 10. Extensiones (opcional)

- **E1** — Añade `strategy: RollingSync` con waves dev→stg→prod y observa el orden.
- **E2** — Sustituye el `git.directories` por un `git.files` donde cada env es un archivo YAML con parámetros Helm.
- **E3** — Añade `templatePatch` que ponga `automated: null` en el ambiente `prod` (manual approval sólo ahí).

## 11. Limpieza

```bash
# Si aplicaste en argocd:
kubectl -n argocd delete applicationset myapp-envs --ignore-not-found
kubectl delete ns myapp-dev myapp-stg myapp-prod myapp-qa --ignore-not-found

rm -rf /tmp/argo-07-01
```
