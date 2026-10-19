# gl-06 — Lección: runners en profundidad, Fleeting y OIDC

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `gl-02`, `gl-03`.

---

## 1. El runner, revisitado

Un **GitLab Runner** es un *agente* instalado en una máquina (bare metal, VM, pod, contenedor) que **recoge jobs** de GitLab (SaaS o self-managed) y los ejecuta. El runner no sabe de pipelines: solo sabe de **jobs**. Toma uno, prepara el *entorno de ejecución* según el **executor** configurado y corre `script:` dentro de ese entorno.

Cuatro cosas que suelen confundirse:

1. El runner es **un proceso**; el executor es **cómo** ese proceso ejecuta el job (lanza un contenedor, un pod, un shell local…).
2. El runner **tira (long-poll)** jobs de GitLab, no al revés. Por eso un runner detrás de NAT funciona: nunca aceptamos conexiones entrantes.
3. Un runner puede tener **múltiples executors en el mismo binario**, pero un `config.toml` concreto configura **uno por `[[runners]]`**. Hay un `[[runners]]` por "configuración" (puedes tener dos registros al mismo GitLab con tags distintos).
4. **Scope**: *Shared* (toda la instance), *Group* (todo el group y subgroups), *Project* (solo ese project). El scope lo define el token con el que registras, no el executor.

> **Idea clave que repetiremos**: el `tags:` del job + el `[[runners]].tags` del runner son el **contrato de scheduling**. Sin tags coincidentes, el job queda `pending` para siempre.

---

## 2. Ejecutores: catálogo y trade-offs

GitLab Runner soporta estos ejecutores "de caja":

| Executor | Qué hace | Pro | Contra |
|---|---|---|---|
| `shell` | Corre `script:` en el shell del host | Simple, sin aislamiento | **No aislado**: dos jobs pisan `/tmp`, `node_modules`, `~/.aws`. Riesgo altísimo en runners compartidos. |
| `docker` | Lanza un contenedor por job con la `image:` del job | Aislado por job, caché por imagen | Requiere Docker en el host. Para construir imágenes dentro, necesitas DinD o Kaniko. |
| `docker-machine` | Autoscala VMs con Docker instalado | Elástico | **Deprecado** desde 2023; sucesor = **Fleeting**. |
| `kubernetes` | Lanza un **pod por job** en un cluster | Elasticidad real, aislamiento por pod, uso de HPA/cluster-autoscaler | Overhead de scheduling (segundos), necesitas un cluster que mantener. |
| `virtualbox`, `parallels` | VMs locales | Útil para probar instaladores macOS/Windows en un Mac | Operación manual, no escala. |
| `ssh` | Ejecuta en una máquina remota por SSH | Trivial de montar | Sin aislamiento, credenciales de larga vida. |
| `custom` | Hooks `prepare`, `run`, `cleanup` que lanzas tú | Lo que quieras: Firecracker, Nomad, lambdas… | Lo escribes tú. |

Reglas de pulgar:

- Equipo pequeño, un proyecto, un servidor → **`docker`** en una VM dedicada. Mínimo rozamiento.
- Elasticidad y multi-tenant → **`kubernetes`** con el chart oficial.
- Build de imágenes como el 80% del CI → **`kubernetes` + Kaniko/BuildKit** (sin DinD).
- Workloads con VMs enteras (Windows build, test con GUI, firmware) → **Fleeting** con AWS/GCP ASG.
- Pipelines que necesitan un sandbox exótico (microVM, FaaS, isolate-forks) → **`custom`**.

---

## 3. El ejecutor `docker` y por qué DinD duele

Cuando el job necesita *construir* una imagen Docker (muy habitual), el executor `docker` ya está en el host, pero el **job corre dentro de un contenedor** sin acceso al socket del host. Dos opciones históricas:

### 3.1 Montar el socket del host (`-v /var/run/docker.sock`)

Rápido. Y es **el peor patrón**: el job puede `docker run --privileged ...` en el host, es decir, puede escapar y comprometer la máquina del runner. **No lo hagas en runners compartidos.**

### 3.2 Docker-in-Docker (DinD)

Lanzar un segundo demonio dentro del job como *service*:

```yaml
build:
  image: docker:24
  services:
    - name: docker:24-dind
      alias: docker
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: "/certs"
    DOCKER_TLS_VERIFY: "1"
    DOCKER_CERT_PATH: "/certs/client"
  script:
    - docker build -t myapp:$CI_COMMIT_SHA .
```

Pros: aislado al pod del job (si el runner es K8s), el daemon muere con el job.
Contras:

- Requiere `privileged: true` en el contenedor del service → **el pod puede hacer casi cualquier cosa** en el nodo si escapa.
- Sin cache compartida entre jobs (cada daemon arranca vacío).
- `DOCKER_TLS_CERTDIR` + `DOCKER_TLS_VERIFY` son obligatorios: sin TLS, cualquier otro pod del nodo podría hablar con tu daemon y robar la imagen o inyectar builds.

### 3.3 Alternativas sin daemon (recomendadas en K8s)

- **Kaniko** (`gcr.io/kaniko-project/executor:latest`): construye imágenes dentro de un contenedor **no privilegiado**. No hay daemon. Ideal para pipelines rootless.
- **BuildKit** (`moby/buildkit:rootless`): también rootless, con cache remoto a S3/Registry.

```yaml
build:
  image:
    name: gcr.io/kaniko-project/executor:v1.23.0-debug
    entrypoint: [""]
  script:
    - /kaniko/executor
        --context "$CI_PROJECT_DIR"
        --dockerfile "$CI_PROJECT_DIR/Dockerfile"
        --destination "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
```

> **Trampa habitual**: creer que "DinD con TLS" basta. Mientras `privileged: true` esté, un escape del daemon compromete el nodo. En entornos regulados, prefiere Kaniko/BuildKit.

---

## 4. El ejecutor `kubernetes` y el chart oficial

El patrón moderno en orgs medianas: desplegar GitLab Runner como un **Deployment** en un cluster K8s usando el chart `gitlab/gitlab-runner`. El runner (un pod) actúa como *controller* que, por cada job, crea un **pod efímero** de ejecución y lo destruye al terminar.

Esqueleto mínimo de `values.yaml`:

```yaml
# values.yaml para gitlab/gitlab-runner
gitlabUrl: "https://gitlab.com/"
runnerRegistrationToken: ""  # legacy, dejar vacio en 2026
runnerToken: "glrt-xxxxxxxxxxxx"  # authentication token moderno

rbac:
  create: true

concurrent: 20
checkInterval: 5
logLevel: info

runners:
  config: |
    [[runners]]
      name = "k8s-shared"
      executor = "kubernetes"
      [runners.kubernetes]
        namespace = "{{ .Release.Namespace }}"
        image = "alpine:3.20"
        privileged = false
        cpu_request = "200m"
        memory_request = "256Mi"
        service_cpu_request = "100m"
        service_memory_request = "128Mi"
        helper_cpu_request = "50m"
        helper_memory_request = "64Mi"
      [runners.cache]
        Type = "s3"
        Shared = true
        [runners.cache.s3]
          ServerAddress = "s3.eu-west-1.amazonaws.com"
          BucketName = "gitlab-runner-cache"
          BucketLocation = "eu-west-1"
          AuthenticationType = "iam"
  tags: "k8s,shared"
```

Puntos clave:

1. **`runnerToken` vs `runnerRegistrationToken`**: desde 2023 GitLab deprecó los *registration tokens*. El modelo moderno es:
   - En la UI (`Group > CI/CD > Runners > New group runner`) o vía `glab`/API, se **crea** el runner y GitLab devuelve un **authentication token** (`glrt-...`).
   - Pasas ese token al chart. El runner **no se registra en el momento del `helm install`**; ya está "pre-registrado" en GitLab.
2. **`privileged = false`** por defecto. Si quieres DinD, lo habilitas por el job con un `[[runners]]` separado y tags distintos; nunca de forma global.
3. **`[runners.cache]`** con S3 compartido evita que cada job descargue `node_modules` desde cero. `AuthenticationType = "iam"` deja que el pod use el role del nodo (IRSA en EKS) sin credenciales en el `values.yaml`.
4. **`concurrent`**: cuántos jobs puede orquestar este pod runner a la vez. Si pones 100, se crearán hasta 100 pods de ejecución (y el cluster-autoscaler ampliará nodos).

---

## 5. Fleeting: el sucesor de `docker-machine`

Hasta 2023, el patrón "autoscaler" de GitLab era `docker-machine` (una herramienta de Docker Inc. ya descontinuada) montando VMs en AWS/GCP. Deprecado. El sucesor es **Fleeting**, un *framework* oficial de GitLab con plugins por nube:

- `fleeting-plugin-aws` (AWS Auto Scaling Groups)
- `fleeting-plugin-googlecloud`
- `fleeting-plugin-azure`

El patrón:

```toml
# config.toml fragmento
[[runners]]
  name = "fleeting-aws"
  url = "https://gitlab.com/"
  token = "glrt-xxxxxxxxxxxx"
  executor = "docker-autoscaler"
  [runners.autoscaler]
    plugin = "aws"
    capacity_per_instance = 2
    max_use_count = 20
    max_instances = 10
    [runners.autoscaler.plugin_config]
      name             = "runners-asg"
      profile          = "default"
      region           = "eu-west-1"
    [[runners.autoscaler.policy]]
      idle_count = 1
      idle_time  = "20m0s"
  [runners.docker]
    image = "alpine:3.20"
```

Ideas:

- **`capacity_per_instance`** = cuántos jobs corren en paralelo en la misma VM. Más es más barato pero menos aislado.
- **`max_use_count`** = tras N jobs, la VM se recicla (defensa contra fugas de estado).
- **`idle_count`** = cuántas VMs mantener calientes aun sin trabajo (reduce latencia de arranque).
- El runner principal (el que corre `gitlab-runner` con este `config.toml`) necesita permisos IAM para `autoscaling:*` sobre el ASG objetivo y `ec2:DescribeInstances`.

Fleeting cubre el caso que `kubernetes` **no** cubre bien: cargas que requieren **VM entera** (test de drivers, firmware, Windows). Para la mayoría de pipelines, K8s sigue siendo más simple.

---

## 6. Registro moderno: *authentication tokens*

Resumen operativo del cambio:

| Era | Comando | Token | Estado |
|---|---|---|---|
| Legacy | `gitlab-runner register --registration-token xxx` | Único por scope (reutilizable) | **Deprecado** desde 15.6; eliminación programada. |
| Moderno | 1) Crear runner en UI/API → recibir `glrt-...` 2) `gitlab-runner register --token glrt-...` | Único por runner | Recomendado desde 15.10. |

Ventajas del modelo moderno:

- **Revocación granular**: un token comprometido afecta a un runner, no a todo el group.
- **Trazabilidad**: cada runner tiene un ID y aparece como entidad propia en la UI.
- **Pre-configuración**: tags, protected-only, run-untagged se definen al crear el runner, no en el `register` del cliente — menos drift.

> **Trampa**: scripts de Terraform heredados que usan `gitlab_runner` resource con el modelo viejo. Hay que migrarlos a `gitlab_user_runner` / `gitlab_group_runner` (según scope) que devuelven el `glrt-...`.

---

## 7. ID Tokens: OIDC desde GitLab a la nube

Un **ID Token** en GitLab es un **JWT** firmado por GitLab que el runner inyecta en el job como variable. Es el equivalente a `ACTIONS_ID_TOKEN_REQUEST_TOKEN` de GitHub Actions. Permite al pipeline **asumir un rol en AWS/GCP/Azure/Vault** sin credenciales de larga vida.

Declaración en el `.gitlab-ci.yml`:

```yaml
deploy-to-aws:
  stage: deploy
  image: amazon/aws-cli:2.17.0
  id_tokens:
    AWS_ID_TOKEN:
      aud: "https://gitlab.com"
  variables:
    AWS_ROLE_ARN: "arn:aws:iam::111122223333:role/gitlab-deployer-prod"
  script:
    - >
      aws sts assume-role-with-web-identity
      --role-arn "$AWS_ROLE_ARN"
      --role-session-name "gitlab-${CI_PIPELINE_ID}"
      --web-identity-token "$AWS_ID_TOKEN"
      --duration-seconds 3600 > /tmp/creds.json
    - export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId /tmp/creds.json)
    - export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey /tmp/creds.json)
    - export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken /tmp/creds.json)
    - aws sts get-caller-identity
```

Claims relevantes del JWT (los que importan para la *trust policy*):

| Claim | Ejemplo | Para qué sirve |
|---|---|---|
| `iss` | `https://gitlab.com` | El provider OIDC a crear en AWS. |
| `aud` | `https://gitlab.com` (configurable) | Debe coincidir con el `aud` del `id_token`. |
| `sub` | `project_path:acme/web:ref_type:branch:ref:main` | **La clave del pinning**: identifica proyecto + tipo de ref + ref. |
| `project_path` | `acme/web` | Útil con `StringLike`. |
| `ref` | `main` | Rama/tag concreto. |
| `environment` | `production` | Si el job declara `environment:`. |
| `namespace_path` | `acme` | Group raíz. |

---

## 8. Trust policy en AWS: el pinning correcto

Para que el `aws sts assume-role-with-web-identity` funcione hace falta:

1. **OIDC provider** en IAM apuntando a `https://gitlab.com` (o a tu self-managed), con el *thumbprint* del certificado.
2. **IAM role** con una *trust policy* que confíe en ese provider **y** restrinja por `sub`/`aud`.

Ejemplo bien pinado:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitLabOIDCAssumeFromMainOnly",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/gitlab.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "gitlab.com:aud": "https://gitlab.com"
        },
        "StringLike": {
          "gitlab.com:sub": "project_path:acme/web:ref_type:branch:ref:main"
        }
      }
    }
  ]
}
```

**Qué evalúa cada condición**:

- `StringEquals` sobre `aud`: evita que un token emitido para otro público (p. ej. Vault) sea aceptado.
- `StringLike` sobre `sub`: aquí está el 90% del valor. Si pones `"project_path:acme/*"` cualquier proyecto del group `acme` asume el rol. Si pones el `sub` completo (incluyendo `ref:main`), **solo** la rama `main` del proyecto `acme/web` lo asume.

**Anti-patrones a detectar**:

1. `"gitlab.com:sub": "*"` → cualquier job de cualquier proyecto de GitLab.com puede asumir el rol. Catástrofe.
2. `"gitlab.com:sub": "project_path:acme/*"` → cualquier proyecto del group. Útil solo para roles muy restrictivos (ReadOnly).
3. Olvidar `aud` → el role aceptará cualquier audience; token de Vault puede re-usarse en AWS.
4. Usar `StringEquals` sobre `sub` en vez de `StringLike` cuando quieres match por prefijo con wildcard — `StringEquals` **no** interpreta `*`.

> **Idea clave**: la trust policy es la **frontera** entre la identidad del pipeline y los permisos en la nube. Más estricta = menos radio de impacto si un atacante consigue correr un job.

---

## 9. Pinning por `environment` y defensa en profundidad

Si el job declara `environment: production`, GitLab incluye `environment:production` en el `sub`. Puedes exigirlo en la trust policy:

```json
"StringLike": {
  "gitlab.com:sub": "project_path:acme/web:ref_type:branch:ref:main:environment:production"
}
```

Esto implica dos capas:

1. Solo pipelines corriendo **en** `environment: production` (job con `environment:` declarado) pueden asumir el role.
2. GitLab tiene **protected environments** con **approval rules**: si `production` está protegido y pide 2 approvers, nadie accede al role de prod sin la aprobación.

Capas que **combinas**:

| Capa | Qué controla |
|---|---|
| Protected branch | Qué refs pueden correr pipelines contra prod. |
| Protected environment | Quién puede desplegar a prod (approvals). |
| `rules:` del job | Que el job solo exista en pipelines "legítimos" (p. ej. en MR a main). |
| Trust policy (`sub`) | Que incluso si el job existe, solo asuma el role bajo las condiciones esperadas. |
| Permisos del role | Qué puede hacer una vez asumido (least-privilege). |

---

## 10. Elección de ejecutor por workload

Tres escenarios de examen:

### 10.1 Build de imagen Docker rootless, 50 veces al día

- **Elección**: `kubernetes` executor + **Kaniko** (`gcr.io/kaniko-project/executor`).
- **Por qué no DinD**: `privileged: true` en nodos compartidos es incompatible con una política razonable de seguridad.
- **Por qué no `docker`**: necesitarías un host privilegiado por runner. K8s escala mejor.

### 10.2 Matriz `pytest` 3 Python × 3 OS

- **Elección**: `kubernetes` executor con `parallel: matrix:` y una `image:` distinta por combinación.
- **Nota**: para "3 OS" en GitLab la realidad es 3 **imágenes base** (`python:3.11-bookworm`, `python:3.11-alpine`, `python:3.11-ubi`). Para Windows/macOS reales, usas Fleeting con un ASG o GitLab-hosted SaaS runners por tag.

### 10.3 Test de firmware que requiere acceso a `/dev/kvm` y VM entera

- **Elección**: **Fleeting** con AWS ASG de instancias `m5.metal` o `c5.metal`.
- **Por qué no K8s**: KubeVirt sería posible pero añade complejidad grande; para una carga aislada, un pool pequeño con Fleeting es más barato operar.

> **Idea clave**: la mayoría de orgs vive con un mix de **K8s executor (default)** + **Fleeting pool pequeño** para los casos exóticos. Shell y SSH deberían ser excepcionales.

---

## 11. Fundamentos internos (lo que suele doler en producción)

Cinco cosas que no se intuyen:

1. **El job corre con el `/etc/hosts` y DNS del pod/contenedor del ejecutor, no del runner.** Si tu runner pod tiene acceso a `kubernetes.default.svc` pero el pod del job no (NetworkPolicy), el pipeline falla con mensajes confusos. Depura con `kubectl get pod -n <runner-ns>` durante la ejecución.
2. **Los *ID Tokens* son JWTs cortos (típicamente 1h).** Si tu `aws sts assume-role-with-web-identity` pide `--duration-seconds 7200`, falla: la duración máxima está limitada por la del token y por la `MaxSessionDuration` del role. Pide duraciones menores o iguales a 3600.
3. **El `sub` del token depende de si el job declara `environment:`.** Si tu trust policy exige `:environment:production` y olvidas poner `environment:` en el job, falla con `AccessDenied`. Es una fuente clásica de "ayer funcionaba".
4. **DinD en Kubernetes necesita que el runner haya habilitado `[runners.kubernetes]` con `privileged = true`.** No basta con poner `services: docker:dind` en el `.gitlab-ci.yml`: si el runner está en modo no-privilegiado, el service pod arranca y crashea con "cannot start Docker daemon".
5. **Fleeting plugin no es un servicio aparte: es un binario que el runner invoca.** Hay que descargarlo e instalarlo en el host del runner (`/usr/local/bin/fleeting-plugin-aws`). Si falta, el `[runners.autoscaler]` se queja con "plugin not found" y el runner no toma jobs.

---

## 12. Alternativas y qué llevarse

### Alternativas al stack "K8s executor + Fleeting + OIDC"

- **GitLab SaaS runners únicamente**: útil para equipos muy pequeños. Pagas minutos; no gestionas infra. Techo de personalización y de minutos mensuales.
- **`docker-autoscaler` en bare metal con `nomad-plugin`**: existe para shops con Nomad en lugar de K8s.
- **Credenciales de larga vida (IAM user con access keys)**: lo que OIDC vino a reemplazar. Si lo mantienes, al menos **rota con Secrets Manager** (ver `aws-16` para el patrón de rotación).

### Qué llevarse en una frase

> Un **runner** ejecuta jobs; un **executor** decide **cómo**. `kubernetes` + chart oficial es el default moderno para la mayoría; **Fleeting** cubre el caso "VM entera"; **ID Tokens** eliminan credenciales estáticas al desplegar a AWS/GCP/Azure/Vault. El **pinning del `sub` claim** en la *trust policy* es la frontera principal: cuanto más estricto, menor radio de impacto.

### Qué sigue

- `gl-07` — Environments y Review Apps sobre esta base.
- `gl-08` — Scanners nativos y Container Registry (consumen minutos de estos runners).
- `gl-10` — Migración GHA↔GitLab y el catálogo CI/CD como plataforma.
