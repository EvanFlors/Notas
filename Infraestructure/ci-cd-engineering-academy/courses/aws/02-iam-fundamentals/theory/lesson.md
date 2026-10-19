# Lección — IAM Fundamentals

IAM (Identity and Access Management) es el **sistema de permisos global** de AWS. No es "login y passwords"; es un motor que, en cada llamada API, decide **sí** o **no** a partir de un conjunto de políticas JSON y una identidad firmante. Entender IAM mal es la causa #1 de dos cosas: *filtraciones de credenciales con blast radius enorme* y *facturas sorpresa por recursos que no deberían haber podido crearse*.

## 1. ¿Qué es un *principal*?

Un **principal** es "quien hace la llamada API". AWS distingue cuatro tipos:

| Tipo | Ejemplo | Credencial que lleva |
|------|---------|----------------------|
| **IAM user** | `arn:aws:iam::123456789012:user/alice` | access key (long-lived) o password + MFA (consola) |
| **IAM role** | `arn:aws:iam::123456789012:role/DeployBot` | credenciales **temporales** emitidas por STS tras `AssumeRole` |
| **AWS service** | `ec2.amazonaws.com`, `lambda.amazonaws.com` | el servicio asume un rol en tu cuenta ("service role") |
| **Federated** | usuario que vino de Google / Okta / GitHub Actions / un OIDC provider | STS cambia su token por credenciales AWS temporales |

Memoriza esto: **el único principal que mantiene credenciales de larga duración es `IAM user`**. Los otros tres usan STS. Esta es la razón por la que, en diseños modernos, los `IAM user` casi desaparecen: queda uno o ninguno (opcionalmente, un *break-glass* con MFA fuerte, nunca usado en el día a día).

## 2. Policies: JSON, elementos y gramática

Una **policy** es un documento JSON con esta forma:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::acme-reports",
        "arn:aws:s3:::acme-reports/*"
      ],
      "Condition": {
        "StringEquals": { "aws:PrincipalTag/team": "data" }
      }
    }
  ]
}
```

Elementos clave:

- **`Version`**: siempre `"2012-10-17"`. No es la "versión de tu política"; es la versión de la gramática. Usar `"2008-10-17"` deshabilita variables y condiciones modernas.
- **`Statement`**: lista de reglas. Cada statement se evalúa de forma independiente.
- **`Effect`**: `Allow` o `Deny`.
- **`Action`**: una o varias acciones (`s3:GetObject`, `ec2:RunInstances`, `*`). Puedes usar wildcards (`s3:Get*`).
- **`Resource`**: ARN(s) sobre los que aplica. Puedes usar `*`, pero *esa es la contraseña a muchas incidencias*.
- **`Condition`**: refinamiento opcional (horario, IP de origen, tag del principal, presencia de MFA, etc.).
- **`Principal`** / **`NotPrincipal`**: **solo** aparece en políticas *resource-based* y en *trust policies*. En políticas identity-based, el principal es implícito (quien tiene la policy adjunta).

### 2.1 `NotAction`, `NotResource`, `NotPrincipal`

Son el complemento lógico. Útiles para expresar "cualquier acción **excepto** estas" o "cualquier recurso **excepto** este bucket". Peligrosos: `"NotAction": ["iam:*"]` en un `Allow` concede **todo lo demás**, que es casi todo AWS. Úsalos solo cuando sepas exactamente qué estás descartando.

## 3. Identity-based vs resource-based

Hay **dos sitios** donde pegar una policy, y la diferencia importa:

- **Identity-based**: adjuntada a un `user`, `group` o `role`. Dice *"esta identidad puede hacer X sobre Y"*.
- **Resource-based**: adjuntada al recurso (bucket S3, cola SQS, KMS key, Lambda function, repo ECR). Dice *"estos principals pueden hacer X sobre mí"*. Requiere `Principal`.

¿Para qué sirve la distinción? Para **cross-account**. Si la cuenta A quiere leer un bucket de la cuenta B, hacen falta **las dos**: la identity policy en A que permite `s3:GetObject` sobre `arn:aws:s3:::bucket-de-B/*` **y** la bucket policy en B que menciona explícitamente al principal de A. Una sola no basta: ambas tienen que decir sí.

Dentro de la misma cuenta, con que **una** de las dos lo permita suele ser suficiente — pero depende del servicio y, para KMS, siempre las dos. En este módulo nos quedamos en la misma cuenta; el álgebra cross-account completa es `aws-06`.

## 4. Groups, managed vs inline

Los **groups** son contenedores de `IAM users` para asignarles las mismas políticas. **Un grupo no es un principal** — no puedes dar permisos a un grupo "y que un servicio los asuma". Para servicios, siempre `role`.

Las **managed policies** son políticas con nombre y versionado:

- **AWS managed** (`AmazonS3ReadOnlyAccess`, `AdministratorAccess`, …): mantenidas por AWS. Útiles para empezar, peligrosas para quedarse.
- **Customer managed**: tuyas, con nombre y versiones. Reusables.

Las **inline policies** están pegadas directamente al user/role/group, sin nombre independiente. Útiles para permisos *únicos de ese principal* que no quieres reutilizar; evitan la contaminación de "esta managed policy la tiene no sé quién más".

Regla práctica: *managed* cuando compartes, *inline* cuando es específico. Nunca `AdministratorAccess` a un service role.

## 5. Roles y STS: la mecánica profunda

Un **role** no tiene credenciales permanentes. Para "ponerse" el rol, un principal llama a **STS** (`sts:AssumeRole`) y STS devuelve un triplete temporal: `AccessKeyId`, `SecretAccessKey`, `SessionToken`. Expira (por defecto 1 h; configurable hasta 12 h).

La magia está en que, mientras el principal firma con esas credenciales temporales, **AWS lo trata como si fuera el rol**, no como el principal original. Esto permite:

- **Separación de privilegios**: tu usuario puede *no tener* permiso para borrar DynamoDB, pero el rol `DBAdmin` sí; para borrar, asumes el rol a propósito.
- **Credenciales de corta vida**: si se filtran, caducan en minutos.
- **Audit limpia**: CloudTrail registra "`alice assumed role DBAdmin`, luego `DBAdmin.DeleteTable`". Trazable.
- **Cross-account** sin compartir access keys: la cuenta B expone un rol asumible; la cuenta A asume y actúa.

### 5.1 Trust policy vs permission policy

Cada role tiene **dos políticas**:

- **Trust policy** (una, embebida): dice *quién puede asumir este rol*. Sintaxis idéntica a una policy, pero la acción canónica es `sts:AssumeRole` y lleva `Principal`.
- **Permission policies** (una o varias, managed o inline): dicen *qué puede hacer este rol una vez asumido*.

Ejemplo de trust policy que acepta a Alice:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::123456789012:user/alice" },
    "Action": "sts:AssumeRole"
  }]
}
```

Confusión frecuente: *"ya puse `AdministratorAccess` en el rol, ¿por qué no puedo asumirlo?"*. Porque la **permission policy** no decide quién puede asumir — eso es la **trust policy**. Son dos preguntas distintas: "¿me dejan ponerme el disfraz?" (trust) vs "¿qué puedo hacer con el disfraz puesto?" (permission).

### 5.2 `sts:AssumeRoleWithWebIdentity` y OIDC

Es la variante para principals federados por OIDC. Un workflow de GitHub Actions presenta un JWT firmado por `token.actions.githubusercontent.com`; AWS lo verifica contra el OIDC provider que diste de alta y, si el trust policy del rol lo acepta, STS devuelve credenciales. **Sin access keys en el repo.** Es la forma correcta de dar a CI acceso a AWS en 2026.

El trust policy típico incluye un `Condition` que ata el rol a *un repo concreto y una rama concreta*:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:acme/web:ref:refs/heads/main" }
  }
}
```

Si olvidas el `Condition`, **cualquier repo público de GitHub** podría asumir tu rol. Es un error histórico y bien documentado.

## 6. Variables de policy

Puedes referenciar atributos del principal en la policy:

- `${aws:username}` — nombre del user actual.
- `${aws:PrincipalTag/team}` — valor del tag `team` del principal.
- `${aws:SourceIp}` — IP de la llamada.

Permiten políticas genéricas: *"cada user puede escribir en `s3://home/${aws:username}/*`"*. Más mantenible que una policy por usuario.

## 7. Access keys vs SSO vs OIDC

| Opción | Vida | Dónde vive | Cuándo elegirla |
|--------|------|------------|-----------------|
| Access key de IAM user | **permanente** hasta rotación | archivo, variable de entorno, repo (horror) | casi nunca |
| **IAM Identity Center (SSO)** | temporal (hasta 12 h) | `~/.aws/config` con `sso_start_url`, cache local | humanos en su laptop |
| **OIDC federation** | temporal (minutos) | token del provider → STS | CI (GitHub, GitLab), Kubernetes (IRSA) |
| **Instance / task role** | temporal (rotada por AWS) | metadata service de la EC2/ECS/Lambda | cualquier compute dentro de AWS |

La regla: **si puedes usar un rol, usa un rol**. Access keys solo cuando *no hay* alternativa (y planifica retirarlas).

## 8. Lógica de evaluación (una sola cuenta)

Cuando llega una llamada API, el motor evalúa, en orden:

1. **Default deny**. Si nadie dice nada, es `Deny`.
2. **¿Hay un `Deny` explícito** en alguna policy aplicable (identity, resource, boundary, SCP)? Si sí → **Deny**. Fin.
3. **¿Hay un `Allow` explícito** en alguna policy aplicable? Si sí → **Allow**.
4. Si no → **Deny**.

Dos reglas que no se negocian:

- **Explicit deny gana siempre.** Un `Deny` en cualquier policy aplicable mata la operación, por mucho `Allow` que haya en otras.
- **No existe "merge" de permisos entre `Allow`s contradictorios.** `Allow` + `Allow` = `Allow`. `Allow` + `Deny` = `Deny`. `Deny` + `Deny` = `Deny`.

Cuando intervienen **SCPs** (Service Control Policies) o **permission boundaries**, se añaden como *filtros techo*: aunque identity y resource digan `Allow`, si la SCP no permite esa acción, es `Deny`. Eso es `aws-06`; aquí basta con la versión de una sola cuenta.

## 9. Mínimo privilegio: cómo se escribe realmente

El patrón que funciona:

1. Arranca con la política que *crees* mínima.
2. Ejécutala. Lee CloudTrail (o IAM Access Analyzer "policy generation") para ver qué acciones **de verdad** se llamaron.
3. Reescribe la policy con solo esas acciones y recursos.
4. Repite.

Herramientas:

- **`aws iam simulate-principal-policy`**: dado un principal y una acción, simula la decisión del motor. No cobra. **Lo usamos en las actividades.**
- **IAM Access Analyzer**: encuentra accesos externos no deseados y, en modo "policy generation", te propone una policy a partir de CloudTrail.

Antipatrón: pegar `AdministratorAccess` "porque es más rápido" y "luego la refino". Nunca se refina.

## 10. Pitfalls y heurísticas

- **`"Resource": "*"`** con `s3:GetObject` significa *todos los objetos de todos los buckets de la cuenta*. Nunca lo quieres salvo para `s3:ListAllMyBuckets` o acciones no-recurso.
- **Un rol asumido no "hereda" los permisos del principal original.** Si asumes un rol con `AdministratorAccess`, tienes `AdministratorAccess` aunque tu usuario base no tuviera nada.
- **Trust policy demasiado permisiva** (`"Principal": "*"` + sin `Condition`) con `sts:AssumeRole` convierte el rol en "asumible por cualquiera" — incluyendo cuentas AWS ajenas.
- **MFA en consola ≠ MFA en API.** Para forzar MFA en llamadas API, condición `"Bool": { "aws:MultiFactorAuthPresent": "true" }`.
- **Las variables de policy requieren `"Version": "2012-10-17"`.** Con la versión vieja fallan silenciosamente (se interpretan literales).
- **STS endpoints**: por defecto `sts.amazonaws.com` (global, legacy); se recomienda el regional (`sts.us-east-1.amazonaws.com`, …) por latencia y menor blast radius si hay un incidente regional.

## 11. Antipatrones recurrentes

Estos tres aparecen una y otra vez en revisiones de IAM:

- **`AdministratorAccess` adjunta a un service role "temporalmente"**: luego nadie refina. Si la Lambda solo necesita `dynamodb:PutItem` sobre una tabla, dale exactamente eso. Lo contrario es un rol que, comprometido, borra la cuenta entera.
- **Managed policies de AWS pegadas sin leerlas**: `AmazonS3FullAccess` suena acotada, pero concede `s3:*` sobre todos los buckets, incluidas las operaciones de bucket (`s3:PutBucketPolicy`, `s3:DeleteBucket`). Léelas antes de adjuntarlas; prefiere *customer-managed* con las acciones estrictas.
- **Trust policy con `"Principal": {"AWS": "*"}` + "ya pondremos un `Condition` fuerte luego"**: nunca se pone. Y si se pone y es laxo (`StringLike` con `*`), el rol termina siendo asumible desde fuera de la cuenta. Diseña la trust policy con el principal más estricto posible desde el primer commit.

Un patrón adyacente: usar la misma policy para varios roles distintos porque "comparten acciones". Al principio ahorra tiempo; a los seis meses, cambiar un permiso para un rol lo cambia para todos y nadie se acuerda. Prefiere **policies por responsabilidad**, aunque haya duplicación controlada.

## 12. Herramientas que no cuestan nada

Antes de cerrar, tres utilidades que puedes aprovechar sin provisionar nada:

- **`aws iam simulate-principal-policy`** y **`aws iam simulate-custom-policy`**: evalúan una policy contra una acción y recurso concretos. Devuelven `allowed`, `implicitDeny` o `explicitDeny`, y, para cada decisión, qué statement la generó. Es la forma más rápida de probar hipótesis sin tocar nada real. Ambos son gratis.
- **IAM Access Analyzer "policy generation"**: a partir de CloudTrail, propone una policy mínima para un rol existente. No es perfecta (requiere revisar), pero evita escribir la primera versión a ciegas.
- **IAM Access Analyzer "external access"**: analiza tus resource policies (buckets, KMS keys, Lambda, SNS, SQS, roles) y señala las que permiten acceso **desde fuera** de la cuenta o la organización. Correrlo una vez descubre, en la mayoría de cuentas antiguas, al menos un bucket público olvidado.

Estas tres herramientas, usadas cada vez que escribes o revisas una policy, convierten IAM de "lo que recuerdes" a "lo que la plataforma te confirma".

## Síntesis

IAM es un **motor de evaluación** sobre un **grafo de identidades y recursos**. Lo que entra: una llamada firmada. Lo que sale: `Allow` o `Deny`. Casi todo lo que hace falta sabe se reduce a tres frases:

1. Usa **roles**, no users. Access keys solo si no queda remedio.
2. **Trust policy** = quién puede asumir el rol. **Permission policy** = qué puede hacer una vez asumido. Son políticas distintas.
3. **Default deny → explicit allow → explicit deny gana.** Y mínimo privilegio es un *proceso*, no un *estado*.

Con esto, `aws-02` está listo. Lo siguiente es la red (`aws-03`), que es donde IAM empieza a jugar en equipo con security groups, endpoints y, más tarde, instance profiles.
