# Ejemplo 01 — CMK con key policy correcta

> Lectura y análisis. Opcionalmente ejecutable contra LocalStack. Objetivo: internalizar la **anatomía de una key policy** para los dos principals más confundidos: un **rol de aplicación** (IAM) y un **servicio AWS** (Secrets Manager).

## 1. Escenario

Queremos una **CMK customer-managed** que:

- La administre el rol `arn:aws:iam::111111111111:role/kms-admin`.
- La use **Secrets Manager** para cifrar los secretos del servicio *checkout*.
- La use **la app `checkout`** (que corre con el rol `arn:aws:iam::111111111111:role/checkout-task`) para `kms:Decrypt` cuando levanta y resuelve secretos.

Los principals son **tres distintos** y conviven en la misma policy.

## 2. Policy JSON comentada

```json
{
  "Version": "2012-10-17",
  "Id": "key-policy-checkout-cmk",
  "Statement": [

    {
      "Sid": "EnableIAMDelegation",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111111111111:root" },
      "Action": "kms:*",
      "Resource": "*"
    },

    {
      "Sid": "AllowKeyAdministration",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111111111111:role/kms-admin" },
      "Action": [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },

    {
      "Sid": "AllowCheckoutAppDecrypt",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111111111111:role/checkout-task" },
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:EncryptionContext:service": "checkout"
        }
      }
    },

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
  ]
}
```

Lee con atención:

- **`EnableIAMDelegation`**: sin esto, ninguna IAM policy puede autorizar nada sobre la CMK. No da acceso a nadie — habilita que las IAM policies cuenten.
- **`AllowKeyAdministration`**: separa quién administra la key (puede destruirla, cambiar policy) de quién la usa. Buen hábito, aunque muchos equipos empiezan metiendo todo en el root.
- **`AllowCheckoutAppDecrypt`**: la app sólo descifra, y sólo cuando la operación trae `EncryptionContext:service=checkout`. Si otra app robara el rol, no podría abrir blobs que no fueron cifrados con ese contexto.
- **`AllowSecretsManagerUse`**: el principal es un **servicio** (`secretsmanager.amazonaws.com`), no un rol. La condición `kms:ViaService` ata esta policy a llamadas que entren por Secrets Manager; `kms:CallerAccount` evita confused-deputy entre cuentas.

## 3. Qué sucede si falta una pieza

- Sin `EnableIAMDelegation` y sin statement explícito para `checkout-task`: *AccessDenied* aunque la IAM policy del rol diga `kms:Decrypt *`.
- Sin la condición `kms:ViaService` en el statement de Secrets Manager: alguien con `secretsmanager:GetSecretValue` podría usar la CMK vía rutas no previstas (no es un fallo crítico siempre, pero es un *least-privilege gap* detectable por auditoría).
- Sin la condición `EncryptionContext` en el statement del rol: si otro proceso ciframos cosas con esa CMK sin contexto, la app podría descifrarlas por descuido.

## 4. Validar el JSON

El JSON de este ejemplo está en `key-policy.json`. Puedes validar estructuralmente con `jq`:

```bash
jq empty examples/01-cmk-with-key-policy/key-policy.json && echo "valid JSON"
jq '.Statement | length' examples/01-cmk-with-key-policy/key-policy.json
jq '[.Statement[].Sid]' examples/01-cmk-with-key-policy/key-policy.json
```

Esperado: 4 statements, los 4 Sids listados arriba.

## 5. (Opcional) Aplicar contra LocalStack

Si tienes LocalStack corriendo (`http://localhost:4566` con `kms` habilitado):

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

aws kms create-key \
  --description "example cmk aws-09-01" \
  --policy "$(cat examples/01-cmk-with-key-policy/key-policy.json)"
```

LocalStack acepta la policy pero **no la enforza** (es un stub). El objetivo del ejemplo es la estructura, no la enforzabilidad. En AWS real, un typo en el principal te deja la key creada pero inutilizable.

## 6. Lectura adicional

- Guía oficial de key policies: `https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html`
- Policy conditions (`kms:ViaService`, `EncryptionContext`): `https://docs.aws.amazon.com/kms/latest/developerguide/policy-conditions.html`
