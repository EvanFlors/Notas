# REFERENCE — aws-06-01-write-scp-baseline

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Resumen (modelo)

Este baseline protege la OU `prod` de la organización. Principio: **deny-by-default sobre operaciones peligrosas**; las identity policies siguen siendo las que *otorgan*. Las SCPs son el *backstop* que ni un admin de cuenta puede saltar: un `Deny` arriba gana sobre cualquier `Allow` abajo.

Se eligen SCPs (y no identity policies) porque:

- Aplican a **todos los principals** de la cuenta — incluido el root.
- Están fuera del scope administrativo del admin de cuenta: el admin no puede desactivarlas, solo el admin de la organización.
- Protegen *frente a cambios futuros*: cuando el admin de cuenta cree un nuevo rol permisivo, el techo SCP sigue ahí.

## Sección B — Una subsección por SCP

### B.1 `policies/01-deny-regions.json`

- **Deniega**: todo (`NotAction` cubre todo lo demás) cuando `aws:RequestedRegion` no está en `["us-east-1", "eu-west-1"]`.
- **No deniega**: servicios globales — IAM, Organizations, CloudFront, Route53, STS, soporte, WAF, aws-portal. Si los bloqueas, rompes la cuenta (no puedes listar usuarios, no puedes asumir roles, no puedes resolver DNS).
- **Ataque prevenido**: un atacante con credenciales válidas que intente provisionar recursos (ej. minería crypto) en una región que no monitorizas. Clásico ataque *crypto mining en ap-south-1* porque "nadie mira allí".

### B.2 `policies/02-deny-audit-tamper.json`

- **Deniega**: operaciones destructivas sobre CloudTrail (`StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors`) y Config (`DeleteConfigurationRecorder`, `StopConfigurationRecorder`, `DeleteDeliveryChannel`, `DeleteConfigRule`).
- **No deniega**: operaciones de lectura (`DescribeTrails`, `GetTrailStatus`); un admin tiene que poder ver que CloudTrail está activo.
- **Ataque prevenido**: *log evasion*. El patrón canónico: atacante compromete credenciales de admin → primero apaga CloudTrail → luego actúa impunemente. Con esta SCP el primer paso falla; la actividad queda registrada.

### B.3 `policies/03-require-mfa-destructive.json`

- **Deniega**: operaciones de borrado destructivo sobre S3 y IAM users **cuando `aws:MultiFactorAuthPresent` no es `true`**.
- **No deniega**: operaciones no-destructivas (`GetObject`, `GetUser`); no deniega destructivas si la sesión *sí* tiene MFA.
- **Ataque prevenido**: una access key filtrada (sin MFA asociada) no puede borrar buckets ni usuarios. El atacante que se cuela con solo la key no puede hacer el daño máximo.
- **Nota sobre `BoolIfExists`**: `BoolIfExists` dispara el `Deny` **también** cuando la clave `aws:MultiFactorAuthPresent` **no está presente** (ej: credenciales federadas que no incluyen la clave). Con `Bool` plano, "clave ausente" se trata como "no se cumple la condition" → el `Deny` **no** se dispara → hueco. Siempre `BoolIfExists` para MFA sobre destructivas.

## Sección C — Interacción con identity policies

**P1**: Si una identity policy permite `cloudtrail:DeleteTrail`, ¿qué pasa con esta SCP activa?

- Pasa que el request **se deniega**. El SCP evalúa primero: hay un `Deny` explícito sobre esa action → fin. La identity policy no se "compensa" con el `Deny` de la SCP. SCPs son techo; `Deny` siempre gana.

**P2**: ¿Podría un admin de cuenta saltar la SCP editando su propia identity policy?

- **No.** El admin de cuenta no tiene acceso a Organizations (eso vive en la cuenta management, no en su cuenta). Y aunque se autoasigne `AdministratorAccess` en su cuenta, la SCP sigue siendo el techo. SCPs operan **antes** de la identity policy en la lógica de evaluación. La única forma de saltarlas es que el admin **de la organización** las modifique.

## Sección D — Tres SCPs que añadirías mañana

1. **`04-deny-leave-organization.json`** — `Deny` sobre `organizations:LeaveOrganization`. Previene que un admin de cuenta saque la cuenta de la org (y con ello saque los SCPs).
2. **`05-deny-root-user.json`** — `Deny` cuando `aws:PrincipalArn` coincide con `arn:aws:iam::*:root`. El root user solo debe usarse para los pocos casos documentados (recuperar la cuenta); operaciones normales con root son señal de alarma.
3. **`06-require-ec2-tags.json`** — `Deny` sobre `ec2:RunInstances` si no se incluye tag `Owner` y `CostCenter`. Guardrail de FinOps: sin tags, no hay instancia.

## Notas finales

Este baseline no es "completo" — es el **mínimo defensivo**. Un baseline maduro añade:

- Deny de hacerse pública la configuración de S3 (`s3:PutBucketPolicy` con `aws:ResourceAccount` != cuenta propia).
- Deny de borrar llaves KMS marcadas con tag `critical=true`.
- Deny de modificar la configuración de GuardDuty.

Y, sobre todo, un pipeline que mantenga las SCPs en Terraform/CloudFormation y las aplique a través del *management account*.
