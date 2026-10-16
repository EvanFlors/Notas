# argo-02 — Instalar Argo CD y primera Application

## Identificación

- **ID:** `argo-02-install-and-first-application`
- **Curso:** `argocd-gitops`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `argo-01-gitops-principles-and-argocd-vs-flux`. Cluster local funcional (kind o k3d). `kubectl` apuntando a él. `argocd` CLI instalada (`brew install argocd` o binario oficial).

## Objetivo

Instalar Argo CD en un cluster local, acceder por **UI** y por **CLI**, y gestionar la **primera Application** desde el repositorio público `argoproj/argocd-example-apps`. Al terminar deberías entender la diferencia entre **sync status** y **health status**, saber dónde vive la contraseña inicial, y poder hacer `app sync`, `app diff`, `app history` y `app rollback` sin consultar la documentación.

## Alcance

Este módulo cubre:

- Instalación de Argo CD con **manifests oficiales** (`install.yaml`) y mención del chart Helm.
- Componentes del sistema: `argocd-server`, `application-controller`, `repo-server`, `redis`, `applicationset-controller`, `notifications-controller`, `dex` (opcional).
- Acceso inicial: `kubectl port-forward`, `argocd admin initial-password`, login por CLI.
- Comandos esenciales: `argocd login`, `app create`, `app list`, `app get`, `app sync`, `app diff`, `app history`, `app rollback`.
- Conectar un repositorio público y crear una Application que apunta a plain YAML.
- Interpretación correcta de **sync** (desired vs live) vs **health** (readiness de los recursos).

Lo que **no** cubre (viene después):

- Anatomía profunda del CR Application → `argo-03`.
- Helm/Kustomize como source → `argo-04`.
- Políticas de sync (auto, prune, self-heal, waves) → `argo-05`.
- Projects, RBAC, SSO → `argo-06`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-install-argocd-in-kind/` — instalar Argo CD paso a paso en un cluster kind.
  - `02-first-plain-yaml-app/` — crear la primera Application contra el repo `argocd-example-apps`.
  - `03-cli-essentials/` — tour de `argocd` CLI: login, app CRUD, sync, diff, history, rollback.
- **`activities/`**:
  - `01-bootstrap-argocd/` (guided-lab) — levantar Argo CD en kind, extraer la contraseña inicial, validar los 6 Deployments y el 1 StatefulSet esperados.
  - `02-connect-repo-and-sync/` (guided-lab) — crear la Application `guestbook` desde la CLI, sincronizar y verificar sync=Synced + health=Healthy.
- **`resources/links.md`** — documentación oficial y lecturas.

## Temas y subtemas

1. Instalación
   - Manifests oficiales (`install.yaml`, `ha/install.yaml`, `core-install.yaml`, `namespace-install.yaml`).
   - Chart oficial `argo/argo-cd` (menciones y cuándo preferirlo).
   - Versionado (pinnear tag Git del manifest).
2. Componentes
   - `argocd-server` (UI + API gRPC/HTTP).
   - `argocd-application-controller` (StatefulSet; reconciliation loop; sharding).
   - `argocd-repo-server` (clona repos y renderiza manifests).
   - `argocd-redis` (caché de rendering y de estado).
   - `argocd-applicationset-controller` (ApplicationSet CR → N Applications).
   - `argocd-notifications-controller` (triggers → Slack/webhook).
   - `argocd-dex-server` (opcional, OIDC federation).
3. Acceso inicial
   - `kubectl -n argocd port-forward svc/argocd-server 8080:443`.
   - `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`.
   - `argocd login localhost:8080 --insecure --username admin --password <...>`.
4. CLI esenciales
   - `argocd cluster list`, `argocd repo list/add`.
   - `argocd app create <name> --repo <url> --path <dir> --dest-server <...> --dest-namespace <...>`.
   - `argocd app sync <name>`, `argocd app diff <name>`, `argocd app get <name>`.
   - `argocd app history <name>`, `argocd app rollback <name> <ID>`.
5. Sync vs Health
   - **Sync** compara desired manifests vs live state en el API server.
   - **Health** evalúa readiness/condition de cada recurso con hooks por kind.
   - Un recurso puede estar `Synced` y `Degraded`, o `OutOfSync` y `Healthy`.

## Conceptos internos

- El `application-controller` es un **sharded controller**: cada shard reconcilia un subconjunto de Applications. El reconciliation loop es la implementación directa del principio GitOps "pulled automatically + continuously reconciled".
- El `repo-server` es el único que toca el filesystem con el checkout de los repos. Soporta Helm (`helm template`), Kustomize (`kustomize build`), Jsonnet, y plugins (CMP). No ejecuta `helm install` ni `kubectl apply` — solo **renderiza**.
- Argo CD guarda la contraseña inicial del admin como Secret `argocd-initial-admin-secret` en el namespace `argocd`. Al cambiarla por UI/CLI el Secret se vuelve informativo; se recomienda eliminarlo tras el primer login.
- Casi todo el estado de Argo CD vive como **CRs** (`Application`, `AppProject`, `ApplicationSet`) y ConfigMaps (`argocd-cm`, `argocd-rbac-cm`). Backup = backup del namespace.

## Competencias

- **Conceptual:** explicar los 7 componentes y qué hace cada uno; diferenciar `sync` de `health`.
- **Operativa:** levantar Argo CD en kind; crear la primera Application desde CLI y UI; recuperar la password inicial.
- **Arquitectónica:** elegir entre manifests y Helm chart; decidir en qué namespace vive Argo CD y qué namespace es su primer target.

## Ejemplos

- [`examples/01-install-argocd-in-kind/`](examples/01-install-argocd-in-kind/)
- [`examples/02-first-plain-yaml-app/`](examples/02-first-plain-yaml-app/)
- [`examples/03-cli-essentials/`](examples/03-cli-essentials/)

## Actividades

- [`activities/01-bootstrap-argocd/`](activities/01-bootstrap-argocd/) — guided-lab
- [`activities/02-connect-repo-and-sync/`](activities/02-connect-repo-and-sync/) — guided-lab

## Entregables

- Cluster local kind con Argo CD **operativo** (todos los pods del namespace `argocd` en Ready).
- Primera Application `guestbook` **Synced + Healthy** apuntando a `https://github.com/argoproj/argocd-example-apps`.
- Snapshot con la salida de `argocd app get guestbook` demostrando sync/health y revisión.

## Criterios de evaluación

- **Conceptual:** diferenciar correctamente `sync status` de `health status` con un ejemplo real (p. ej. recurso `Synced` pero `Progressing`).
- **Operativa:** cada actividad imprime `RESULT: PASS` en su validador.
- **Arquitectónica:** justificar por qué el `application-controller` es StatefulSet y los demás Deployment; por qué el `repo-server` es el único que necesita filesystem.

## Recursos

Ver [`resources/links.md`](resources/links.md).
