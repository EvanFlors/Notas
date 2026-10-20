# Ejemplo 04 — Secrets Manager + rotación automática RDS

> Lectura y análisis. **No se despliega**. Objetivo: entender la anatomía de la rotación automática y los 4 pasos del Lambda rotator.

## 1. El flujo de rotación (4 pasos)

Secrets Manager llama a la Lambda rotator con un `step` distinto en cada invocación. La Lambda debe implementar los 4 y ser idempotente.

```
┌───────────────────────────────────────────────────────────────────────┐
│ Secret: miapp/db/prod                                                 │
│   version AWSCURRENT  ──► {"username": "appuser", "password": "OLD"}  │
└───────────────────────────────────────────────────────────────────────┘
                               │
                               │  cron automatico (automatically_after_days)
                               ▼
┌───────────────────────────────────────────────────────────────────────┐
│ Lambda rotator (invocada 4 veces por rotacion)                        │
│                                                                       │
│  1. createSecret                                                      │
│     - genera password nueva                                           │
│     - crea version AWSPENDING con la nueva                            │
│                                                                       │
│  2. setSecret                                                         │
│     - usa AWSPENDING                                                  │
│     - ALTER USER appuser WITH PASSWORD 'NEW';   (en el RDS)           │
│                                                                       │
│  3. testSecret                                                        │
│     - abre conexion a la DB con la nueva password                     │
│     - si falla ──► rollback: elimina AWSPENDING, mantiene AWSCURRENT  │
│                                                                       │
│  4. finishSecret                                                      │
│     - mueve el label AWSCURRENT a la version nueva                    │
│     - la vieja queda como AWSPREVIOUS (por si hace falta rollback)    │
└───────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────────────┐
│ App (lee en runtime)                                                  │
│   GetSecretValue(SecretId=miapp/db/prod)                              │
│     - devuelve la version AWSCURRENT (nueva)                          │
│   La app no se entera de la rotacion:                                 │
│     reconecta al abrir pool nuevo o cuando la conexion se cae.        │
└───────────────────────────────────────────────────────────────────────┘
```

## 2. Terraform (referencia, no se aplica)

```hcl
resource "aws_secretsmanager_secret" "db" {
  name                    = "miapp/db/prod"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "db_initial" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "appuser"
    # placeholder; la Lambda rotator sobreescribe en la primera rotacion
    password = "CHANGEME_WILL_BE_ROTATED"
  })
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotator.outputs["RotationLambdaARN"]

  rotation_rules {
    automatically_after_days = 30
  }
}

# Lambda rotator oficial de AWS (desde Serverless Application Repository)
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotator" {
  name           = "miapp-db-rotator"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities   = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]
  parameters = {
    endpoint     = "https://secretsmanager.us-east-1.amazonaws.com"
    functionName = "miapp-db-rotator"
  }
}
```

## 3. Dos estrategias: single-user vs multi-user

| Estrategia | Qué hace | Trade-off |
|------------|----------|-----------|
| **Single-user** | Rota la password del único usuario. | Hay una ventana (ms-s) en que las conexiones viejas usan la password vieja. En apps con pool, imperceptible. |
| **Multi-user** | Mantiene dos usuarios (`appuser_a`, `appuser_b`) y alterna. | Zero-downtime estricto, pero requiere dos usuarios y permisos iguales. Más complejo. |

Para la mayoría de apps web: **single-user**. Para apps críticas con conexiones de larga duración: **multi-user**.

## 4. Pattern de la app (Python)

```python
import boto3, json
from functools import lru_cache

_sm = boto3.client("secretsmanager")

@lru_cache(maxsize=1)
def db_credentials():
    # Nota: en produccion querras un cache con TTL (p. ej. 5 min)
    # y manejar `ResourceNotFoundException` / credential rotation events
    resp = _sm.get_secret_value(SecretId="miapp/db/prod")
    return json.loads(resp["SecretString"])

def connect():
    creds = db_credentials()
    return psycopg2.connect(
        host="miapp-db.xxx.us-east-1.rds.amazonaws.com",
        user=creds["username"],
        password=creds["password"],
        dbname="miapp",
    )
```

Observaciones:

- La app **nunca** ve la password en env vars ni en Kubernetes Secrets. Vive solo en memoria el tiempo de la llamada.
- El pool de conexiones hay que refrescarlo cuando falla con `password authentication failed` — típicamente una capa `with-retry` que reinvalida el cache y reconecta.

## 5. Permisos (IRSA/Pod Identity policy)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-east-1:111122223333:secret:miapp/db/prod-*"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt"],
      "Resource": "arn:aws:kms:us-east-1:111122223333:key/<key-id>"
    }
  ]
}
```

El sufijo `-*` en el ARN del secret es necesario porque Secrets Manager añade 6 chars aleatorios al nombre.

## 6. Costo (referencia, verificar Fase 4)

- Secret almacenado: **$0.40/mes**.
- API calls: **$0.05 por 10,000**.
- Lambda rotator (mensual): despreciable.
- Para 100 secretos rotados: ~$40/mes de secrets + ~pocos céntimos de API.

## 7. Preguntas

1. Si la Lambda rotator falla en el paso `testSecret`, ¿la app sigue funcionando? ¿Por qué?
2. ¿Por qué `ignore_changes = [secret_string]` en el `aws_secretsmanager_secret_version` inicial?
3. Si la app cachea la credential en memoria sin TTL, ¿qué puede pasar tras la rotación? ¿Cómo lo mitigas?
4. ¿Cuándo elegirías **multi-user** sobre single-user? Da dos ejemplos de workload.
