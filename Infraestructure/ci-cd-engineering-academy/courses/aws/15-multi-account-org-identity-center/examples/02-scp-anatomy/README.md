# Ejemplo 02 — Anatomía de una SCP

> Lectura y análisis. Sin ejecución. Objetivo: ser capaz de **leer una SCP** y predecir qué permite y qué no.

## 1. Esqueleto comentado

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeaveOrg",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    }
  ]
}
```

- **`Version`**: literal `"2012-10-17"`. **No** es la fecha de hoy; es el nombre de la versión del *policy language* de IAM. Si cambias esta string, la SCP falla al aplicar.
- **`Statement`**: lista de reglas. Puede tener 1 o N.
- **`Sid`**: identificador legible, opcional pero recomendado. Útil en diffs y en logs de denegación.
- **`Effect`**: `"Deny"` o `"Allow"`. En SCPs *deny-list* casi siempre `"Deny"`.
- **`Action`**: `"servicio:Operacion"`. Soporta `*`. En este ejemplo, deniega una sola acción.
- **`Resource`**: casi siempre `"*"`. Las SCPs razonan sobre **principals**, no sobre recursos.

## 2. Patrón: `deny-leave-organization`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PreventLeavingOrganization",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    }
  ]
}
```

**Qué hace**: impide que un principal de la cuenta ejecute `aws organizations leave-organization`. Sin esto, un admin de una member account podría sacarla de la organización y escapar del gobierno (incluidas las SCPs y la facturación consolidada).

**Qué NO hace**: no impide que el **management account** disuelva la org entera — eso lo controla la propia management.

## 3. Patrón: `deny-regions` (whitelist)

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
        "waf:*",
        "waf-regional:*",
        "wafv2:*",
        "support:*",
        "sts:GetCallerIdentity",
        "sts:AssumeRole",
        "sts:AssumeRoleWithSAML",
        "sts:AssumeRoleWithWebIdentity"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "eu-west-1",
            "eu-central-1"
          ]
        }
      }
    }
  ]
}
```

**Qué hace**: deniega **toda acción** (`"Resource": "*"`) **salvo** las listadas en `NotAction`, **cuando** la región no es `eu-west-1` ni `eu-central-1`.

**Por qué `NotAction` con servicios globales**: IAM, Organizations, CloudFront, Route 53, WAF (global), STS y Support son **servicios sin región** (o con endpoint único). Si no los excluyes, el `Condition` `aws:RequestedRegion` evalúa como "sin región ≠ eu-west-1" y los bloquea — rompiendo la cuenta.

**Trampa clásica**: olvidar `sts:AssumeRole` en el `NotAction`. Si lo olvidas, los roles cross-account dejan de funcionar.

## 4. Patrón: `deny-disable-logging`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtectCloudTrail",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ProtectConfig",
      "Effect": "Deny",
      "Action": [
        "config:StopConfigurationRecorder",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "config:DeleteConfigRule"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ProtectCentralLogsBucket",
      "Effect": "Deny",
      "Action": [
        "s3:DeleteBucket",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketLogging"
      ],
      "Resource": "arn:aws:s3:::org-cloudtrail-logs-*"
    }
  ]
}
```

**Qué hace**:

- **Statement 1**: nadie puede parar, borrar ni modificar un CloudTrail trail.
- **Statement 2**: nadie puede parar ni borrar la grabación de Config.
- **Statement 3**: en el bucket central de logs (ARN con wildcard), nadie puede borrar el bucket ni cambiar su policy ni su logging config.

**Por qué 3 statements**: para que la razón de la denegación sea legible en CloudTrail cuando ocurra. Un único statement con 20 acciones genera mensajes de denegación opacos.

## 5. Dos sutilezas que suelen morderte

### 5.1 `Allow` en SCP vs implícito

Por defecto, una cuenta en una org hereda una SCP implícita `FullAWSAccess` desde Root. Si la **detaches**, la cuenta pierde **todo** permiso (deniega por defecto). Nunca se recomienda operar en modo *allow-list* salvo que sepas exactamente qué estás permitiendo.

### 5.2 Las SCPs no aplican al management

Repítelo: **la management account no está sujeta a sus propias SCPs**. Si pones un `Deny s3:*` en la Root y ejecutas una llamada S3 desde el management, **funciona**. Por eso el management no hospeda workloads.

## 6. Flujo mental para leer una SCP cualquiera

1. ¿`Effect` es `Deny` o `Allow`? (Casi siempre `Deny`.)
2. ¿`Action` o `NotAction`? (`NotAction` = "todo **menos** esto".)
3. ¿`Resource` es `*` o un ARN concreto? (ARN concreto = la SCP solo pega sobre ese recurso.)
4. ¿Hay `Condition`? Si sí, el deny solo aplica cuando la condición se cumple.
5. ¿Esta SCP está adjuntada a qué OU? ¿Qué cuentas descienden de ahí?
6. ¿Hay otras SCPs encima (en OUs ancestras) o debajo (en OUs descendientes)? La efectiva es la intersección.

Con ese flujo puedes auditar cualquier SCP en 30 segundos.

## 7. Preguntas de autocomprobación

1. En el `deny-regions`, si quitas `sts:AssumeRole` del `NotAction`, ¿qué cosa deja de funcionar y cuándo lo notarías?
2. En el `deny-disable-logging`, el Statement 3 usa `arn:aws:s3:::org-cloudtrail-logs-*`. ¿Por qué wildcard al final?
3. Si un developer te dice "mi `aws ec2 describe-instances --region us-east-1` falla con AccessDenied", ¿cómo diagnosticas si es la SCP de regiones o su identity policy?
4. ¿Qué pasa si aplicas estas tres SCPs a la management account? ¿Y a una member account?
5. ¿Cómo escribirías una SCP que permita acciones en `us-east-1` **solo** para un rol concreto (`arn:aws:iam::*:role/GlobalOpsBreakGlass`)?
