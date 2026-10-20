# REFERENCE — aws-06-02-cross-account-and-boundary

> Una **referencia** razonada. No es la única respuesta correcta — compara, no copies.

## Sección A — Resumen

Dos problemas distintos resueltos con dos herramientas distintas:

- **Delegación segura** dentro de una cuenta → `permission boundary` + identity policy que fuerza el boundary.
- **Confianza entre cuentas** → `trust policy` (dos variantes, intra-org vs vendor externo).

Permission boundaries y trust policies son **mecanismos defensivos**: ninguno otorga por sí mismo; definen el techo o la precondición de un `AssumeRole`.

## Sección B — Boundary de developers (`boundary-dev.json`)

- **Permite**: operación runtime de apps bajo el prefijo `app-*` (S3, SNS, SQS, logs, DynamoDB).
- **Deniega explícitamente**:
  - `iam:CreateUser`, `iam:AttachUserPolicy`, `iam:PutUserPolicy`, `iam:CreateAccessKey` → **previene escalada vía user**: el developer no puede crear un IAM User con `AdministratorAccess` y usar su access key para saltarse el boundary.
  - `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`, `iam:PutRolePermissionsBoundary`, `iam:PutUserPermissionsBoundary` → **previene remover o cambiar el propio techo**. Sin esto, el rol creado por el developer podría borrar su boundary y escalar.
  - `organizations:*`, `account:*` → **previene salir de la org o modificar cuentas**.

Combinado con la identity policy del developer, el conjunto efectivo es: "crear roles `app-*` con este boundary, operar en recursos `app-*`, nada más".

## Sección C — Identity policy del developer (`developer-identity.json`)

- La condition `iam:PermissionsBoundary = arn:...:policy/dev-app-boundary` es **imprescindible**. Sin ella, el developer puede crear un rol **sin** boundary y adjuntarle `AdministratorAccess`. Resultado: escaló.
- El developer **no puede** crear `admin-of-me` porque:
  - `Resource` en el `Allow` es `arn:aws:iam::*:role/app-*` → el nombre no empieza por `app-`, falla.
  - Aunque intentara crear `app-admin-of-me`, el boundary lo acota: ese rol solo podría leer/escribir sobre `app-*/*`, no sobre recursos arbitrarios ni IAM.
- El `DenyModifyingOwnBoundary` sobre `arn:aws:iam::*:user/${aws:username}` cierra la última puerta: el developer no puede automodificarse ni borrar su propio boundary (si lo tuviera).

## Sección D — Trust policy intra-org (`trust-intra-org.json`)

- `aws:PrincipalOrgID = o-exampleorgid` — **solo** principals de MI organización pueden asumir. Defiende contra: alguien que logre crear una cuenta A' con el mismo numero de cuenta en otra org (teóricamente no colisionan en AWS real, pero el principio es que el ARN no es prueba de org membership — la condition sí lo es).
- `aws:MultiFactorAuthPresent = true` — defiende contra access keys filtradas. Una sesión sin MFA no puede asumir.
- **Si quitas `aws:PrincipalOrgID`**: el principal `arn:aws:iam::111111111111:root` sigue siendo necesario, pero perderías la defensa adicional. En práctica para intra-org es cinturón-y-tirantes; en vendor externo (siguiente sección) `aws:PrincipalOrgID` ni siquiera tendría sentido.

## Sección E — Trust policy vendor externo (`trust-vendor-external.json`)

- `sts:ExternalId` — un secreto compartido entre tú y el vendor. El vendor lo almacena y lo pasa en cada `AssumeRole`. Si no se pasa (o se pasa mal) → `AccessDenied`.
- `aws:PrincipalOrgID` **no** aplica — el vendor está en SU organización, no en la tuya. La condition fallaría siempre.
- **Ataque *confused deputy* que previene**: imagina que el vendor acepta "configúrame otra cuenta cliente con el ARN que me digas". Un atacante le dice al vendor "mi ARN es `arn:aws:iam::222222222222:role/VendorMetricsIngest`" (que es tu rol real). Sin `ExternalId`, el vendor haría `AssumeRole` sobre tu rol en nombre del atacante — y tu rol confía en el vendor. El vendor es el *diputado confundido*. Con `ExternalId`, el atacante no puede proveerlo (es un secreto que vive solo entre tú y el vendor), así que el `AssumeRole` falla.

## Notas finales

- El patrón `permission boundary` solo tiene sentido con una identity policy que *obligue* a adjuntarlo. Sin esa condition en la identity del delegado, el boundary es una pieza suelta.
- `sts:ExternalId` **debe** ser impredecible y largo. Si usas el nombre de tu cuenta o algo público, no defiende de nada.
- Para servicios AWS (ej. Lambda invocada por S3), el patrón defensivo usa `aws:SourceAccount` y `aws:SourceArn` en resource-based policies, no `ExternalId`.
- Nunca `Principal: {"AWS": "*"}` en una trust real, ni siquiera con conditions estrictas: si olvidas una `Condition` por error, el rol queda abierto.
