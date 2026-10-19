# Ejemplo 02 — Rotación de Secrets Manager (walkthrough)

> Lectura y análisis. **No se ejecuta**: la rotación requiere una Lambda real + un backend real (RDS, por ejemplo). LocalStack community no implementa el flujo completo de rotación, y los valores aquí son *fake* por diseño.

## 1. Contexto

Rotación automática = Secrets Manager invoca periódicamente una **Lambda rotator** que cambia la credencial en el sistema destino y actualiza el secret. El ciclo son **4 pasos**, con un valor en `AWSPENDING` que se promueve al final.

```
                    ┌─────────────────────────────────┐
                    │   Secrets Manager (scheduler)   │
                    └────────────────┬────────────────┘
                                     │ invoke
                                     ▼
                    ┌─────────────────────────────────┐
                    │     Lambda rotator (your fn)    │
                    │    event.Step ∈ {createSecret,  │
                    │       setSecret,                │
                    │       testSecret,               │
                    │       finishSecret}             │
                    └─────┬───────────────────────────┘
                          │
                          ▼
                    ┌─────────────────────────────────┐
                    │   Target backend (p. ej. RDS)   │
                    │   `ALTER USER … IDENTIFIED BY`  │
                    └─────────────────────────────────┘
```

## 2. Los 4 pasos

### 2.1 createSecret

Entrada:
```json
{ "Step": "createSecret", "SecretId": "...", "ClientRequestToken": "<uuid>" }
```

Pseudo-código:

```python
def create_secret(sm, secret_id, token):
    # Si AWSPENDING ya existe para este token, no hace nada (idempotente)
    try:
        sm.get_secret_value(SecretId=secret_id, VersionId=token, VersionStage="AWSPENDING")
        return
    except sm.exceptions.ResourceNotFoundException:
        pass

    current = sm.get_secret_value(SecretId=secret_id, VersionStage="AWSCURRENT")
    new_payload = {
        "username": json.loads(current["SecretString"])["username"],
        "password": generate_password(32),   # <- nueva password aleatoria
    }
    sm.put_secret_value(
        SecretId=secret_id,
        ClientRequestToken=token,
        SecretString=json.dumps(new_payload),
        VersionStages=["AWSPENDING"],
    )
```

### 2.2 setSecret

Aplica el nuevo valor en el **backend**. Para RDS single-user:

```python
def set_secret(sm, secret_id, token, db_connect):
    pending = json.loads(sm.get_secret_value(
        SecretId=secret_id, VersionId=token, VersionStage="AWSPENDING"
    )["SecretString"])
    current = json.loads(sm.get_secret_value(
        SecretId=secret_id, VersionStage="AWSCURRENT"
    )["SecretString"])

    # Conectamos con la credencial VIEJA (sigue viva)
    conn = db_connect(user=current["username"], password=current["password"])
    conn.execute(
        f"ALTER USER {pending['username']} WITH PASSWORD %s",
        (pending["password"],),
    )
```

### 2.3 testSecret

Comprueba que la nueva credencial funciona. Si falla, el rotator aborta — y la vieja sigue operativa.

```python
def test_secret(sm, secret_id, token, db_connect):
    pending = json.loads(sm.get_secret_value(
        SecretId=secret_id, VersionId=token, VersionStage="AWSPENDING"
    )["SecretString"])
    conn = db_connect(user=pending["username"], password=pending["password"])
    conn.execute("SELECT 1")   # smoke
```

### 2.4 finishSecret

Promueve `AWSPENDING` a `AWSCURRENT`.

```python
def finish_secret(sm, secret_id, token):
    meta = sm.describe_secret(SecretId=secret_id)
    current_version = next(
        v for v, stages in meta["VersionIdsToStages"].items()
        if "AWSCURRENT" in stages
    )
    if current_version == token:
        return   # ya promovida
    sm.update_secret_version_stage(
        SecretId=secret_id,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
```

Resultado final: la versión antigua pasa a `AWSPREVIOUS` (no se borra). Las apps que aún tengan la conexión abierta siguen vivas; en la siguiente reconexión leen `AWSCURRENT`.

## 3. Key policy mínima para rotación

El rol de ejecución de la Lambda rotator necesita:

- `secretsmanager:GetSecretValue`, `PutSecretValue`, `UpdateSecretVersionStage`, `DescribeSecret` sobre el secret.
- `kms:Decrypt`, `kms:GenerateDataKey*` sobre la CMK (si el secret no usa `aws/secretsmanager`).
- Red hacia el backend (VPC, SG, DNS).

Y en la **key policy** de la CMK:

```json
{
  "Sid": "AllowSecretsManagerUse",
  "Effect": "Allow",
  "Principal": { "Service": "secretsmanager.amazonaws.com" },
  "Action": [
    "kms:Encrypt", "kms:Decrypt",
    "kms:GenerateDataKey*", "kms:DescribeKey",
    "kms:CreateGrant"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com",
      "kms:CallerAccount": "111111111111"
    }
  }
}
```

Sin esto, la rotación crea el `AWSPENDING` pero falla al cifrar.

## 4. Single-user vs Multi-user

| | Single-user | Multi-user (alternating) |
|---|---|---|
| Cuentas en el DB | 1 (`app`) | 2 (`app_a`, `app_b`) |
| Ventana crítica | ~segundos (vieja → nueva en la misma cuenta) | ~0 (siempre hay una cuenta operativa estable) |
| Riesgo si el `setSecret` falla a mitad | la vieja queda inválida en el DB | la vieja (otra cuenta) sigue intacta |
| Preferido en prod | Para apps simples | **Sí** |

La Lambda template oficial soporta ambos (parámetro `MASTER_SECRET_ARN` para multi-user).

## 5. Por qué este ejemplo es walkthrough y no demo ejecutable

- `secretsmanager:RotateSecret` necesita invocar una Lambda real. LocalStack community no provee Lambda runtime completo y menos aún trigger desde Secrets Manager.
- Un ejemplo "fake" (sin backend real) no muestra el valor del patrón — el valor está precisamente en que **nadie se queda fuera** durante la ventana.
- En entornos corporativos con AWS real, el patrón recomendado es: usa la **template oficial** (`SecretsManagerRDSPostgreSQLRotationSingleUser`, por ejemplo) desde el Serverless Application Repository y adáptala; no escribas la Lambda desde cero.

En la actividad `02-rotate-rds-password-automatically` entregas el **diseño** completo (red, IAM, key policy, variantes y ventanas) sobre este esqueleto.

## 6. Lectura adicional

- Rotación — guía oficial: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html`
- Templates oficiales (código fuente abierto): `https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas`
