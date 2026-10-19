# Ejemplo 02 — IRSA: pod en EKS que accede a S3 sin keys

> Lectura y análisis. **Sin ejecución contra AWS.** Objetivo: ver todas las piezas de IRSA en un solo lugar, con comentarios en cada bloque.

## 1. El flujo, visto de alto

```
   ┌────────────────────────────────────────────────────────────────┐
   │                        EKS cluster                             │
   │                                                                │
   │   ┌──────────────┐    1. Pod monta token proyectado           │
   │   │ Deployment   │       en /var/run/secrets/eks.amazonaws... │
   │   │   SA: s3-rw  │                                             │
   │   └──────┬───────┘                                             │
   │          │ 2. SDK AWS lee AWS_ROLE_ARN + AWS_WEB_IDENTITY_...  │
   │          │                                                      │
   └──────────┼──────────────────────────────────────────────────────┘
              │ 3. STS AssumeRoleWithWebIdentity(token)
              ▼
   ┌────────────────────────────┐
   │  AWS STS (público)         │
   │  valida el token contra    │
   │  OIDC provider del cluster │
   └──────────┬─────────────────┘
              │ 4. credenciales temporales (~1 h)
              ▼
   ┌────────────────────────────┐
   │  S3: GetObject / PutObject │
   └────────────────────────────┘
```

## 2. Las 4 piezas

### 2.1 OIDC provider del cluster (una vez por cluster)

Terraform (fragmento):

```hcl
# El módulo oficial lo hace si enable_irsa = true. Expuesto aquí para claridad.
data "aws_eks_cluster" "this" { name = "eks-demo" }

data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}
```

La URL típica es `https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDXXXXXXXXXXXXXXXXX`.

### 2.2 Rol IAM con trust policy limitada a un SA concreto

```hcl
locals {
  oidc_url  = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  namespace = "default"
  sa_name   = "s3-rw"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    # restringe por `sub` al ServiceAccount concreto
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.sa_name}"]
    }

    # restringe también por `aud` para evitar confused deputy
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_rw" {
  name               = "eks-demo-s3-rw"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Política mínima: solo un bucket, solo dos acciones.
data "aws_iam_policy_document" "s3_rw_policy" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::my-demo-bucket/*"]
  }
}

resource "aws_iam_role_policy" "s3_rw" {
  role   = aws_iam_role.s3_rw.id
  policy = data.aws_iam_policy_document.s3_rw_policy.json
}
```

**Lo crítico:** las dos `condition` (`sub` y `aud`). Sin la de `sub` el rol es asumible por **cualquier** SA del cluster.

### 2.3 ServiceAccount con la anotación

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-rw
  namespace: default
  annotations:
    # Esto es lo que convierte un SA normal en "SA con rol IRSA".
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/eks-demo-s3-rw
```

### 2.4 Deployment que usa el SA

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-uploader
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels: { app: s3-uploader }
  template:
    metadata:
      labels: { app: s3-uploader }
    spec:
      serviceAccountName: s3-rw   # el SA con la anotación IRSA
      containers:
        - name: app
          image: public.ecr.aws/aws-cli/aws-cli:latest
          # Al correr el pod, el webhook inyecta automáticamente:
          #   env:
          #     - name: AWS_ROLE_ARN
          #       value: arn:aws:iam::123456789012:role/eks-demo-s3-rw
          #     - name: AWS_WEB_IDENTITY_TOKEN_FILE
          #       value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
          #   volumeMounts:
          #     - name: aws-iam-token
          #       mountPath: /var/run/secrets/eks.amazonaws.com/serviceaccount
          #       readOnly: true
          # y un volume projected con el token.
          command: ["/bin/sh", "-c"]
          args:
            - |
              # El SDK (aws-cli v2) detecta las variables y hace AssumeRoleWithWebIdentity
              aws sts get-caller-identity
              aws s3 cp /etc/hostname s3://my-demo-bucket/hostname-$(hostname).txt
              sleep 3600
```

Nota: la **cuenta ficticia** `123456789012` es la que AWS usa en toda su documentación de ejemplo. **No** poner cuentas reales en commits.

## 3. Cómo verificarlo (mentalmente, sin cluster)

Si todo está bien, al ejecutar `aws sts get-caller-identity` dentro del pod verías:

```json
{
  "UserId": "AROAEXAMPLEEXAMPLE:botocore-session-...",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/eks-demo-s3-rw/botocore-session-..."
}
```

Nota el `assumed-role` — no es el rol tal cual, es una sesión temporal con el nombre de botocore (SDK Python) o `aws-sdk` (otros). Esto confirma que **no hay keys**: hay un `AssumeRoleWithWebIdentity` detrás.

## 4. Trampas comunes

- Olvidar la condición `sub` → cualquier SA del cluster puede asumir el rol.
- SA en namespace equivocado → `sub` no matchea, `AccessDenied`.
- SDK AWS **muy viejo** que no entiende `AWS_WEB_IDENTITY_TOKEN_FILE` → upgradea el SDK.
- Pod corriendo con un **viejo set de credenciales** cacheado por `~/.aws/credentials` montado por error → el SDK prefiere esas antes que IRSA. **Nunca** montar `~/.aws` en pods IRSA.
- Trust policy que confía en el OIDC provider pero sin condición `aud` → riesgo de **confused deputy**.
- IAM role con `MaxSessionDuration` default (1 h) y job batch de 3 h → el SDK debe refrescar; versiones recientes lo hacen solas.

## 5. Qué cambia con Pod Identity (preview)

Con Pod Identity (ver §7 de la lección y actividad 02), el ServiceAccount **no** necesita la anotación, el rol **no** necesita trust policy OIDC compleja (basta `pods.eks.amazonaws.com`), y en vez del anotation hay una **Pod Identity Association** gestionada por EKS. El flujo entre pod y rol es el mismo, pero el "cableado" se simplifica.

## 6. Preguntas de autocomprobación

1. Si borras la anotación del SA, ¿qué sucede en el próximo `kubectl rollout restart`?
2. ¿Qué política IAM te daría acceso de solo-lectura al bucket y a sus objetos (dos recursos, no uno)?
3. ¿Por qué la condición `aud` evita *confused deputy*?
4. Si el mismo workload corre también en **ECS**, ¿qué patrón IAM usarías allí y por qué IRSA no es portable?
