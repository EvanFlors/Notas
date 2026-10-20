# REFERENCE — SCP baseline (intent)

> Documento de intención: qué deniega cada SCP, dónde se adjunta y por qué. El JSON está en los archivos adyacentes.

## Resumen

Tres SCPs forman el **baseline** del tenant: toda la organización (salvo el management account, que las SCPs no pueden tocar) hereda estos guardrails.

| SCP | Adjunta a | Protege |
|-----|-----------|---------|
| `scp-deny-regions` | Root (hereda a toda la org) | Residencia de datos en Europa; superficie reducida. |
| `scp-deny-leave-org` | Root | Nadie saca una cuenta de la org (y escapa de SCPs y billing consolidado). |
| `scp-deny-disable-logging` | Root (con énfasis en Security y Workloads/Prod) | La auditoría no puede ser desactivada ni borrada. |

---

## scp-deny-regions

### Qué deniega

**Todas las acciones** en cualquier región **salvo** `eu-west-1` y `eu-central-1`.

### Dónde se adjunta

A **Root**. Eso aplica a todas las OUs operativas. El management está exento por diseño (las SCPs no le afectan).

### Por qué `NotAction` para servicios globales

Varios servicios AWS son **globales**, no regionales: IAM, Organizations, CloudFront (edge), Route 53 (DNS), WAF global, STS (algunas acciones), Support. Llamadas a estos servicios **no llevan** una región asociada, de modo que la condición `aws:RequestedRegion` para ellos evalúa como "no es eu-west-1 ni eu-central-1" y los bloquearía — rompiendo cosas como IAM, asumir roles, invalidar cache de CloudFront, etc.

El patrón correcto es `Deny` con `NotAction` que **excluye** esos servicios globales. En particular, `sts:AssumeRole` **debe** quedar excluido o el acceso cross-account vía IdC deja de funcionar.

### Excepciones

Ninguna por `aws:PrincipalArn`. Si en el futuro un rol de BreakGlass necesita operar fuera de Europa, se añadirá un `Condition` adicional con `ArnNotLike` apuntando a ese rol concreto.

---

## scp-deny-leave-org

### Qué deniega

La acción `organizations:LeaveOrganization`.

### Dónde se adjunta

A **Root**. Hereda a toda la org.

### Por qué

Sin esto, un administrador de una member account podría llamar `aws organizations leave-organization` y **escapar** de toda la gobernanza central: SCPs, billing consolidado, Permission Sets de IdC, agregadores de GuardDuty/Config. La cuenta quedaría "libre" y la factura iría a cero para la org (pero el daño estaría hecho).

### Qué NO deniega

- Que el **management** disuelva la org entera (ese caso se controla con MFA fuerte y acceso restringido al management).
- Que una member account sea **cerrada** (ese flujo tiene su propia protección vía Suspended OU).

### Excepciones

Ninguna. Nunca ha habido un caso legítimo donde una cuenta necesite salirse de su propia organización en caliente.

---

## scp-deny-disable-logging

### Qué deniega

Acciones destructivas sobre la **auditoría** de la organización:

- **CloudTrail**: `StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors`.
- **AWS Config**: `StopConfigurationRecorder`, `DeleteConfigurationRecorder`, `DeleteDeliveryChannel`, `DeleteConfigRule`.
- **S3** sobre el bucket central de logs (`arn:aws:s3:::org-cloudtrail-logs-*`): `DeleteBucket`, `PutBucketPolicy`, `DeleteBucketPolicy`, `PutBucketLogging`.

### Dónde se adjunta

A **Root** (para que ninguna cuenta pueda romper su propio logging) **y** reforzada en **Security OU** y **Workloads/Prod** (donde se adjuntan políticas adicionales equivalentes como defensa en profundidad).

### Por qué los 3 bloques

- **CloudTrail**: sin logs, un atacante no deja rastro. El trail de la organización vive en el management y envía al bucket central; parar o editar un trail **local** oculta actividad en esa cuenta.
- **Config**: los Config rules son el detector de drift y de hallazgos de seguridad; apagarlos ciega a Security Hub.
- **Bucket S3**: aunque Config y CloudTrail estén activos, borrar el bucket destino destruye la evidencia. La restricción por ARN permite ser quirúrgicos (no bloquea otros buckets).

### Excepciones

Un rol específico (`arn:aws:iam::<log-archive-id>:role/LogsLifecycleManager`) podría necesitar modificar la lifecycle policy del bucket. Esa excepción, si se añade, debe ir vía `Condition` con `ArnNotLike` **solo** en el Statement 3, y debe quedar documentada aquí. Hoy no existe tal rol — las lifecycle policies se gestionan desde Terraform ejecutado desde `tools`, no desde dentro del bucket.

### Qué NO deniega

- Lectura (`cloudtrail:LookupEvents`, `config:Get*`, `s3:GetObject`) — los auditores siguen pudiendo leer.
- Creación de **nuevos** trails o recorders (si alguien quiere añadir granularidad, puede).

---

## Prueba y rollout

Secuencia recomendada para Fase 4:

1. Aplicar las 3 SCPs **primero en Sandbox OU**. Monitorear denies en CloudTrail de la cuenta sandbox durante 48 h.
2. Si no hay sorpresas, aplicar en `Workloads/Dev`. Observar 7 días.
3. Promocionar a `Workloads/Stg` y luego `Workloads/Prod`.
4. Finalmente, re-ubicar las adjunciones a Root para herencia uniforme.

Usar el **IAM policy simulator** (`iam:SimulatePrincipalPolicy`) para validar que roles críticos (deployer, break-glass) siguen pudiendo hacer lo que necesitan **antes** de aplicar.
