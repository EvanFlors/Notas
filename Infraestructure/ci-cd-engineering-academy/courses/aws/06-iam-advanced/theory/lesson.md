# Lección — IAM avanzado: SCPs, boundaries, cross-account y OIDC

> Supuesto: ya sabes qué es un principal, una identity policy, una resource policy y un `Deny` vs `Allow`. Aquí subimos un nivel: **múltiples techos**, **confianza entre cuentas** y **confianza federada**.

## 1. El modelo mental: cinco techos

Cuando un request llega a AWS, el motor de autorización no evalúa "una política". Evalúa, en orden, hasta **cinco capas**. Para que el request pase, **todas** tienen que decir `Allow` (o al menos no decir `Deny`). Para que el request falle, **basta una** que diga `Deny` explícito o un `Allow` ausente en la capa que lo exige.

```
┌─────────────────────────────────────────────────────────────────┐
│  Orden conceptual de evaluación                                 │
├─────────────────────────────────────────────────────────────────┤
│  1. ¿Hay un Deny explícito en CUALQUIER capa?  → DENY, fin.     │
│  2. SCP (en Organizations)             → permite el action?     │
│  3. Resource-based policy              → ¿otorga directamente?  │
│  4. Identity policy del principal      → ¿Allow?                │
│  5. Permission boundary (si aplica)    → ¿permite el action?    │
│  6. Session policy (si AssumeRole)     → ¿permite el action?    │
│                                                                 │
│  Si en 2..6 todo dice Allow (o la capa 3 lo otorga sola),       │
│  el request pasa. Si falta un Allow donde se requiere → DENY.   │
└─────────────────────────────────────────────────────────────────┘
```

Dos ideas que la gente confunde:

- Un `Allow` en identity **no** compensa un `Deny` en SCP. El SCP es techo: lo que no deja pasar, no pasa.
- Un `Allow` en SCP **no** otorga permiso. SCPs solo *restringen*; nunca *otorgan*. Siempre necesitas un `Allow` en identity o resource.

## 2. Service Control Policies (SCPs)

### 2.1 Qué son

SCPs son **políticas de techo** que se aplican a cuentas AWS enteras (vía Organizations), normalmente agrupadas por **OU** (Organizational Unit). No se aplican a principals sueltos — se aplican a *todas las identidades* de la cuenta, incluido el root user de esa cuenta (con muy pocas excepciones).

### 2.2 Para qué sirven

- Prohibir regiones no autorizadas (compliance): "en esta OU no se crea nada fuera de `us-east-1` y `eu-west-1`".
- Prohibir apagar servicios de auditoría: `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, `config:DeleteConfigurationRecorder`.
- Prohibir dejar la organización: `organizations:LeaveOrganization`.
- Forzar MFA para operaciones destructivas.
- Prohibir el root user: condición `aws:PrincipalArn` contra `arn:aws:iam::*:root`.

### 2.3 Qué no son

- No son identity policies — nunca van a *otorgar* permisos.
- No validan sintaxis de recursos finos que no existen todavía.
- No sustituyen al diseño de roles — son el *backstop*.

### 2.4 Patrón canónico: deny-regions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideAllowedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "cloudfront:*",
        "route53:*",
        "support:*",
        "sts:*",
        "waf:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
        }
      }
    }
  ]
}
```

Puntos sutiles:

- `NotAction` excluye **servicios globales** (IAM, CloudFront, Route53, STS, soporte): no viven en una región, bloquearlos rompe la cuenta.
- `StringNotEquals` sobre `aws:RequestedRegion`: cuando AWS evalúa, inyecta esa clave en el *context*.
- Es `Deny`, no `Allow`. SCPs **no otorgan**.

## 3. Permission Boundaries

### 3.1 Qué son

Son un **techo** aplicado a un principal (IAM User o IAM Role) concreto. El principal **no puede ejecutar nada que no esté permitido tanto por su identity policy como por su boundary**. Es una **AND** sobre dos listas de permisos.

### 3.2 Caso de uso canónico: delegación

Patrón "developer-self-service":

- El admin de cuenta no quiere ser el cuello de botella para crear roles de aplicación.
- Pero no quiere que un developer se cree un rol `AdministratorAccess` para sí mismo.
- Solución: delega `iam:CreateRole`, `iam:AttachRolePolicy` al developer, **pero** obliga a que todo rol que cree tenga un `PermissionsBoundary` concreto.
- Resultado: el developer crea roles como quiera, pero ninguno excede el techo.

Condición clave en la identity policy del developer:

```json
{
  "Effect": "Allow",
  "Action": ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy"],
  "Resource": "arn:aws:iam::*:role/app-*",
  "Condition": {
    "StringEquals": {
      "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/dev-app-boundary"
    }
  }
}
```

Sin esa condición, el developer podría crear un rol sin boundary y usarlo para escalar.

### 3.3 Trampa habitual

El developer **no debe poder borrar su propio boundary** (`iam:DeleteUserPermissionsBoundary`, `iam:DeleteRolePermissionsBoundary`). Si lo puede, el techo desaparece y escaló. Siempre niega esa acción explícitamente sobre el principal del developer.

## 4. Session policies

Cuando un principal hace `sts:AssumeRole`, puede pasar una `--policy` ad-hoc. Esa es la **session policy**: otro `AND` por encima de las políticas del rol. Útil para delegación acotada: "te presto el rol, pero solo para leer este bucket, no todo lo que el rol puede".

Rara vez se usa a mano; aparece sobre todo en integraciones (AWS SSO, SDKs que acotan sesiones).

## 5. Cross-account trust

### 5.1 Flujo

- Cuenta A tiene a Alice.
- Cuenta B tiene un rol `role/CrossAccountRead` cuya *trust policy* confía en Alice.
- Alice ejecuta `sts:AssumeRole --role-arn arn:aws:iam::<B>:role/CrossAccountRead`.
- STS emite credenciales temporales **de la cuenta B**.
- Alice actúa en cuenta B con los permisos de ese rol (acotados por su identity policy también).

### 5.2 Trust policy mínima

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111111111111:root"},
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Esto confía en **cualquiera** de la cuenta A que *además* tenga `sts:AssumeRole` en su identity. Mínimo viable, pero no suficiente para producción.

### 5.3 El *confused deputy*

Si tu rol en cuenta B es asumido por un servicio en nombre de un cliente (por ejemplo AWS Config, un vendor SaaS, otro servicio AWS), un atacante que logre que *tu* servicio actúe por *él* puede abusar del rol. Condition keys defensivas:

- `aws:PrincipalOrgID` — "solo si el principal viene de MI organización AWS":
  ```json
  "Condition": {"StringEquals": {"aws:PrincipalOrgID": "o-exampleorgid"}}
  ```
- `aws:SourceAccount` — "solo si el request viene en nombre de ESTA cuenta cliente".
- `sts:ExternalId` — "solo si el que asume presenta este secreto compartido" (para vendors externos tipo Datadog, PagerDuty).
- `aws:SourceArn` — en resource-based policies invocadas por servicio AWS (ej. S3 → Lambda).

### 5.4 Patrón robusto

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111111111111:root"},
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-exampleorgid",
          "sts:ExternalId": "<secreto-compartido-con-A>"
        },
        "Bool": {"aws:MultiFactorAuthPresent": "true"}
      }
    }
  ]
}
```

## 6. OIDC federado: GitHub Actions sin IAM User

### 6.1 El problema

Un IAM User con access keys para que GitHub Actions despliegue en tu cuenta es **la peor opción**:

- Clave de larga vida en GitHub Secrets.
- Si se filtra, hay que rotar.
- No hay forma de atar la clave a un repo/branch/workflow concreto.

### 6.2 La solución OIDC

GitHub Actions emite, por cada job, un **OIDC token** firmado. AWS puede confiar en el emisor (`token.actions.githubusercontent.com`) como **IdP**, y crear un rol cuya trust policy requiera que ese token tenga `sub` y `aud` concretos.

Flujo:

```
┌──────────────────────────┐           ┌──────────────────────────┐
│  GitHub Actions job      │           │  AWS                     │
│                          │           │                          │
│  1. pide OIDC token      │ ────────► │  (no interviene aún)     │
│                          │           │                          │
│  2. recibe token JWT     │ ◄──────── │                          │
│     (iss, sub, aud, exp) │           │                          │
│                          │           │                          │
│  3. AssumeRoleWithWeb    │           │  4. valida firma vs IdP  │
│     Identity(token)      │ ────────► │     mira trust policy    │
│                          │           │     emite credenciales   │
│  5. aws s3 cp ...        │ ◄──────── │                          │
└──────────────────────────┘           └──────────────────────────┘
```

### 6.3 Trust policy para GitHub Actions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub":
            "repo:my-org/my-repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Lo importante:

- `aud` fija al público del token (siempre `sts.amazonaws.com` para este uso).
- `sub` es la pieza defensiva **crítica**: ata el rol a un repo y a una branch concretos. Sin esto, cualquier workflow en GitHub podría asumir el rol.
- Alternativas al `sub`:
  - `repo:my-org/my-repo:ref:refs/heads/main` — solo main branch.
  - `repo:my-org/my-repo:environment:production` — solo jobs atados al environment `production`.
  - `repo:my-org/*` — toda la org (**no recomendado**).

### 6.4 Por qué solo walkthrough + `terraform plan`

En este módulo veremos el Terraform que crea el IdP y el rol en `examples/04-...`, y haremos `terraform plan` localmente. **No** se aplica en AWS: el objetivo es leer el plan y entender qué recursos se crearían, no provisionarlos.

## 7. Lógica de evaluación completa — ejercicio mental

Escenario: Alice en cuenta A asume `role/Deploy` en cuenta B para hacer `s3:PutObject` en bucket `arn:aws:s3:::reports-b`.

Para que el PutObject pase:

1. **SCP de la OU que contiene cuenta B** debe permitir `s3:PutObject`. Si hay un `Deny` sobre S3 en esa OU, se cae.
2. **Trust policy del rol** debe aceptar a Alice (ya lo hizo al asumirlo).
3. **Identity policy del rol** (lo que puede hacer el rol asumido) debe incluir `s3:PutObject` sobre `reports-b`.
4. **Permission boundary del rol** (si tiene) debe incluir ese action.
5. **Resource policy del bucket** no debe tener un `Deny` para la cuenta B / el rol / la acción.
6. **Session policy** (si la hubo al asumir) debe permitirlo.
7. **Identity policy de Alice en A** debe permitir el `sts:AssumeRole` inicial.

Faltar en cualquiera de 1, 3, 5, 6 o 7 → DENY. Un `Deny` explícito en 1 o 5 → DENY aunque todo lo demás sea Allow.

## 8. Validación estructural de policies — por qué `jq`

Antes de aplicar una policy en AWS, la cadena de **errores baratos** se detectan en seco:

- JSON malformado.
- `Version` ausente o mal (debe ser `"2012-10-17"`).
- `Statement` no es array.
- `Effect` ausente o distinto a `Allow`/`Deny`.
- `Action` ausente (o `NotAction` ausente).
- `Resource`/`NotResource` ausente (salvo `sts:AssumeRole` en trust).
- `Condition` con tipo de operador inexistente.

Esto se puede verificar con `jq` sin tocar AWS. Es lo que hacen los validadores de este módulo. Herramientas más potentes (`policy_sentry`, `iam-policy-json-to-terraform`, `cfn-policy-validator`, `aws accessanalyzer validate-policy`) existen y están en `resources/links.md`, pero añaden instalaciones Python/Node o requieren una cuenta AWS. **En este módulo se saltan**: la lógica se entiende perfectamente con `jq`.

## 9. Resumen operativo

- SCP = techo de cuenta/OU. **No otorga**, solo niega. Es tu *backstop*.
- Boundary = techo de principal. **No otorga**, solo niega. Es tu red para delegación.
- Session policy = techo efímero al asumir. Útil para acotar sesiones.
- Trust policy cross-account = "quién puede asumirme". Usa `aws:PrincipalOrgID`, `sts:ExternalId`, `aws:SourceAccount` según el caso.
- OIDC = la respuesta correcta para CI/CD externo. Nunca uses IAM User con access keys para GitHub Actions.
- `jq` + un validador estructural ahorran el 80% de los errores que se detectan de otra forma solo en runtime AWS.

## 10. Siguiente paso

Pasa a `examples/` y lee los cuatro casos antes de abrir las actividades. Las actividades no te darán todas las piezas — tendrás que decidir tú qué `Condition` incluir y defender la decisión.
