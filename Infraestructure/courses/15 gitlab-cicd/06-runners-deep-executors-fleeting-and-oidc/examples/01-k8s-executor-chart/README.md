# Ejemplo 01 — Runner en Kubernetes con el chart oficial

Este ejemplo **no se ejecuta**: muestra el `values.yaml` del chart `gitlab/gitlab-runner` que recomendamos como baseline y el fragmento equivalente de `config.toml` que el chart renderiza. Léelo prestando atención a los tres puntos marcados con `>>>`.

## `values.yaml` anotado

```yaml
# Chart: https://charts.gitlab.io/
# Repo: gitlab/gitlab-runner
# Valores pensados para un cluster EKS en eu-west-1 con IRSA habilitado.

gitlabUrl: "https://gitlab.com/"

# >>> (1) En 2026 el flujo moderno NO usa registration token.
# Crea el runner en la UI (Group > CI/CD > Runners > New group runner)
# o via API y copia el 'glrt-...' aqui.
runnerToken: "glrt-REEMPLAZA_ESTO"

rbac:
  create: true          # crea el ServiceAccount y el Role minimo para listar/crear pods
  clusterWideAccess: false

# ServiceAccount con IRSA para que el runner (y los jobs) pueda hablar con S3 cache
# usando el role del nodo o uno dedicado.
serviceAccount:
  create: true
  name: gitlab-runner
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::111122223333:role/gitlab-runner-irsa"

concurrent: 20          # cuantos jobs orquesta este pod runner en paralelo
checkInterval: 5
logLevel: info

# >>> (2) 'runners.config' es un bloque TOML inyectado en /etc/gitlab-runner/config.toml.
# Es donde vive la configuracion que al cliente clasico 'gitlab-runner register' le pedirias.
runners:
  config: |
    [[runners]]
      name = "k8s-shared"
      executor = "kubernetes"
      environment = ["FF_USE_FASTZIP=true"]
      [runners.kubernetes]
        namespace = "{{ .Release.Namespace }}"
        image = "alpine:3.20"
        privileged = false          # DinD requiere true; aqui NO lo queremos
        cpu_request = "200m"
        memory_request = "256Mi"
        service_cpu_request = "100m"
        service_memory_request = "128Mi"
        helper_cpu_request = "50m"
        helper_memory_request = "64Mi"
        poll_timeout = 180
        pod_labels_overwrite_allowed = ".*"
        [runners.kubernetes.node_selector]
          "workload" = "ci"
        [[runners.kubernetes.pod_spec]]
          name = "non-root"
          patch_type = "merge"
          patch = '''
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          '''
      [runners.cache]
        Type = "s3"
        Shared = true
        [runners.cache.s3]
          ServerAddress = "s3.eu-west-1.amazonaws.com"
          BucketName = "gitlab-runner-cache-prod"
          BucketLocation = "eu-west-1"
          AuthenticationType = "iam"   # usa IRSA, sin keys estaticas
  tags: "k8s,shared,eu-west-1"
  runUntagged: false   # obliga a los jobs a declarar al menos un tag coincidente
  locked: false
```

## Fragmento equivalente de `config.toml`

El chart lo renderiza (de ahí sale el `[[runners]]` que ya ves arriba). Si estuvieses operando el runner con `systemd` + binario en una VM, tu `/etc/gitlab-runner/config.toml` tendría exactamente ese contenido más una cabecera corta:

```toml
concurrent = 20
check_interval = 5
log_level = "info"

[[runners]]
  name = "k8s-shared"
  url = "https://gitlab.com/"
  token = "glrt-REEMPLAZA_ESTO"
  executor = "kubernetes"
  # ... (el mismo [runners.kubernetes] + [runners.cache] de arriba)
```

## Lo que debes retener

1. **`runnerToken`** (el `glrt-...`), no `runnerRegistrationToken`.
2. **`privileged = false`** por defecto; levanta un `[[runners]]` aparte si realmente necesitas DinD, con tags distintos (`tags: "dind"`).
3. **Cache S3** con `AuthenticationType = "iam"` evita credenciales de larga vida en el `values.yaml`.
4. **`runUntagged: false`** obliga a que cada job declare `tags:`, evitando que un runner shared recoja jobs no previstos.

## Siguiente

- `02-fleeting-aws-asg/` — el ASG para los casos donde K8s no basta.
- `03-oidc-id-token-to-aws/` — cómo cualquiera de estos runners (K8s o Fleeting) obtiene credenciales AWS sin keys.
