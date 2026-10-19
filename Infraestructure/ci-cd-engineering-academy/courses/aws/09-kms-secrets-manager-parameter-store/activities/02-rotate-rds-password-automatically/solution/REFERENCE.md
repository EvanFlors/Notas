# REFERENCE — aws-09-02-rotate-rds-password-automatically

> Referencia razonada. Todos los valores son *fake* y están etiquetados.

## Sección A — Arquitectura (modelo)

```
                 ┌──────────────────────────────┐
                 │ EventBridge Scheduler        │
                 │ cron(every 30d)              │
                 └───────────┬──────────────────┘
                             │ invoke
                             ▼
                 ┌──────────────────────────────┐
                 │ Secrets Manager              │
                 │ secret: fake/app/db          │
                 │ CMK: FAKE-CMK-ID             │
                 └───────────┬──────────────────┘
                             │ RotateSecret → Lambda
                             ▼
          ┌──────────────────────────────────────────┐
          │ Lambda rotator (in VPC subnets)          │
          │ SG: sg-rotator-fake                      │
          │ env: SECRETS_MANAGER_ENDPOINT=...        │
          └───────────┬──────────────────────────────┘
                      │ TCP/5432
                      ▼
          ┌──────────────────────────────────────────┐
          │ RDS Postgres  (private subnets)          │
          │ SG allows sg-rotator-fake on 5432        │
          └──────────────────────────────────────────┘
```

Puntos a defender:

- La Lambda **debe** estar en la VPC (subnets privadas) con un SG que RDS acepte.
- Si Secrets Manager no es accesible desde esas subnets, añadir un **VPC interface endpoint** `com.amazonaws.us-east-1.secretsmanager`.
- La CMK y el secret viven fuera de la VPC (son APIs regionales); por eso el endpoint.

## Sección B — Ciclo de 4 pasos (modelo)

1. **createSecret**: genera una password nueva aleatoria y la escribe como `AWSPENDING` con el `ClientRequestToken` recibido. Idempotente: si ya existe un `AWSPENDING` con ese token, no hace nada.
2. **setSecret**: conecta a RDS **con la credencial `AWSCURRENT`** y ejecuta `ALTER USER fake_app WITH PASSWORD <pending>`. La password vieja sigue viva **hasta** este punto (en multi-user esto cambia por cuenta alterna).
3. **testSecret**: abre una conexión con la credencial `AWSPENDING` y lanza `SELECT 1`. Si falla, aborta — `AWSCURRENT` sigue intacta.
4. **finishSecret**: `UpdateSecretVersionStage` promueve `AWSPENDING` → `AWSCURRENT`. La anterior pasa a `AWSPREVIOUS`.

Fallos típicos y qué hacer:

- `createSecret` falla por `kms:GenerateDataKey` denied → arreglar key policy de la CMK.
- `setSecret` falla por SG mal configurado → la vieja sigue viva, re-intentar tras arreglar SG.
- `testSecret` falla por DNS → añadir el VPC endpoint de Secrets Manager o permitir el egress a Internet.
- `finishSecret` falla a mitad → siguiente invocación detecta `AWSPENDING` existente y reintenta.

## Sección C — IAM (modelo)

Execution role de la Lambda:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:000000000000:secret:fake/app/db-*"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"],
      "Resource": "arn:aws:kms:us-east-1:000000000000:key/FAKE-CMK-ID"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface",
                 "ec2:DescribeNetworkInterfaces"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "*"
    }
  ]
}
```

Statement en la **key policy** de la CMK:

```json
{
  "Sid": "AllowRotatorLambdaDecrypt",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::000000000000:role/fake-rotator-role" },
  "Action": ["kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"],
  "Resource": "*"
}
```

## Sección D — Variantes (modelo)

| Criterio | single-user | multi-user |
|----------|-------------|------------|
| Riesgo si `setSecret` falla a mitad | la vieja queda inválida en DB | la otra cuenta sigue intacta |
| Ventana crítica | ~segundos | ~0 |
| Complejidad | baja (una cuenta) | media (dos cuentas, master secret) |
| Preferido en prod | no | **sí** |

Decisión para este diseño: **multi-user** (alternating `fake_app_a` / `fake_app_b`) porque la app corre múltiples pods que podrían reconectar justo durante la ventana.

## Sección E — Fallos y runbook (modelo)

- `testSecret` falla por SG: añadir regla, re-invocar `rotate-secret --rotate-immediately`.
- VPC endpoint de Secrets Manager caído: la Lambda ni siquiera arranca; CloudWatch alarma por timeout. Mitigar con endpoint multi-AZ.
- `AWSPENDING` huérfano (rotación abortada): la siguiente invocación la detecta y reintenta con el mismo `ClientRequestToken`. Si tras N intentos sigue fallando, borrarla manualmente con `UpdateSecretVersionStage --remove-from-version-id`.
- App con la credencial vieja cacheada tras `finishSecret`: `AWSPREVIOUS` sigue válida durante la ventana para que la próxima reconexión no caiga; luego la app recarga `AWSCURRENT`.

## Sección F — Decisiones Secrets Manager vs Parameter Store (modelo)

| # | Ítem | Categoría | Justificación |
|---|------|-----------|---------------|
| 1 | Password del master de PostgreSQL RDS (fake-pw-NOT-REAL) | SecretsManager | rotacion integrada con RDS 4-pasos |
| 2 | API token de proveedor que no rota (fake-token-NOT-REAL) | ParameterStore-SecureString | sensible pero sin rotación: no justifica el costo de SecretsManager |
| 3 | Endpoint Kafka interno (`b-1.kafka.example.internal:9092`) | ParameterStore | config no sensible, costo cero, visibilidad conveniente |
| 4 | 300 feature flags booleanos | ParameterStore | volumen alto: tamano agregado + costo cero por parámetro standard |
| 5 | Private key PEM JWT (fake-pem-NOT-REAL, rota 90d) | SecretsManager | rotable; AWSPREVIOUS permite verificar JWTs firmados con la clave anterior durante la ventana |

Nota: para el ítem 4, si crecen por encima del límite por cuenta o por path, consolidar en 1 solo `String` JSON — pierde granularidad IAM pero simplifica mucho.
