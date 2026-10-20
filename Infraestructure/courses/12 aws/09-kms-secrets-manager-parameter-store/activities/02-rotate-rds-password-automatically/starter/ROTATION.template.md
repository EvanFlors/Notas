# ROTATION — diseño de rotación RDS vía Secrets Manager

> Plantilla de arranque. Reemplaza los `TODO` por tu diseño.
> Todos los valores son *fake* y están etiquetados.

## Sección A — Arquitectura

```
TODO: diagrama ASCII con rotator, rds, secret, cmk, VPC
```

## Sección B — Ciclo de 4 pasos

1. **createSecret** — TODO
2. **setSecret** — TODO
3. **testSecret** — TODO
4. **finishSecret** — TODO

## Sección C — IAM

Execution role de la Lambda rotator (fake ARNs):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue",
                 "secretsmanager:UpdateSecretVersionStage", "secretsmanager:DescribeSecret"],
      "Resource": "arn:aws:secretsmanager:us-east-1:000000000000:secret:fake/*" },
    { "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey*"],
      "Resource": "arn:aws:kms:us-east-1:000000000000:key/FAKE-CMK-ID" }
  ]
}
```

TODO: añade el statement del rol en la key policy de la CMK.

## Sección D — Variantes single-user vs multi-user

| Criterio | single-user | multi-user |
|----------|-------------|------------|
| Riesgo   | TODO | TODO |
| Ventana crítica | TODO | TODO |
| Complejidad | TODO | TODO |

Decisión: TODO (`single-user` o `multi-user`) porque TODO.

## Sección E — Fallos y runbook

- TODO (menciona AWSPENDING y AWSPREVIOUS).

## Sección F — Decisiones Secrets Manager vs Parameter Store (5 ítems)

| # | Ítem | Categoría | Justificación (rotacion/tamano/costo/visibilidad/compartido) |
|---|------|-----------|-------------------|
| 1 | Password del master de PostgreSQL RDS | TODO | TODO |
| 2 | API token de proveedor que no rota | TODO | TODO |
| 3 | Endpoint del broker Kafka interno | TODO | TODO |
| 4 | 300 feature flags booleanos | TODO | TODO |
| 5 | Private key PEM de JWT (rota 90d) | TODO | TODO |
