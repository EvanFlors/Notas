# Ejemplo 03 — CloudTrail organization trail y anatomía de un evento

> Lectura y análisis. Sin deploy real. Útil para visualizar qué hay en un trail y cómo se audita.

## 1. ¿Qué es un organization trail?

Un **organization trail** se crea desde la cuenta `management` (o delegado) de **AWS Organizations** y captura eventos de **todas las cuentas miembro** en un único bucket central. Beneficios:

- **Una sola fuente de verdad** para auditoría.
- Las cuentas miembro **no pueden desactivarlo** (política de la organización lo refuerza).
- Combinado con **SCP** (`aws-15`) se garantiza que ninguna cuenta disable logging.

Arquitectura típica:

```
   mgmt account ──creates──► Organization Trail
                                   │
                                   ▼
                        central S3 bucket (log-archive account)
                                   │  (KMS, Object Lock, bucket policy)
                                   ▼
                        Athena / CloudTrail Lake para queries
```

El bucket central está en la cuenta `log-archive` del landing zone (patrón Control Tower).

## 2. Tipos de evento y coste

| Tipo | Coste | Ejemplo | Recomendación |
|------|-------|---------|---------------|
| Management | Primera copia gratis / cuenta / región | `RunInstances`, `AssumeRole`, `CreateBucket` | **SIEMPRE on** |
| Data | USD/100k eventos | `s3:GetObject`, `lambda:Invoke`, `dynamodb:PutItem` | Habilitar selectivamente (bucket con PII, Lambda crítica) |
| Insights | USD por evento Insights generado | Explosión de `AssumeRole` fallidos | Útil en cuentas con mucha actividad |

**Patrón:** data events se activan **por recurso** (bucket específico), no globalmente — así no estalla la factura.

## 3. Anatomía de un evento (JSON)

Ejemplo real-shape (no es cuenta real):

```json
{
  "eventVersion": "1.09",
  "eventTime": "2026-10-16T14:23:11Z",
  "eventSource": "s3.amazonaws.com",
  "eventName": "DeleteBucket",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "203.0.113.42",
  "userAgent": "aws-cli/2.17.0 Python/3.12",
  "userIdentity": {
    "type": "AssumedRole",
    "principalId": "AROAEXAMPLEID:cli-session",
    "arn": "arn:aws:sts::111111111111:assumed-role/PlatformAdmin/cli-session",
    "accountId": "111111111111",
    "sessionContext": {
      "sessionIssuer": {
        "type": "Role",
        "principalId": "AROAEXAMPLEID",
        "arn": "arn:aws:iam::111111111111:role/PlatformAdmin",
        "accountId": "111111111111",
        "userName": "PlatformAdmin"
      },
      "attributes": {
        "mfaAuthenticated": "true",
        "creationDate": "2026-10-16T14:00:00Z"
      }
    }
  },
  "requestParameters": {"bucketName": "legacy-reports"},
  "responseElements": null,
  "readOnly": false,
  "eventType": "AwsApiCall",
  "managementEvent": true,
  "recipientAccountId": "111111111111",
  "eventCategory": "Management"
}
```

**Qué mirar en una investigación:**

- `userIdentity.sessionContext.sessionIssuer.arn` — qué rol se asumió.
- `userIdentity.sessionContext.attributes.mfaAuthenticated` — true/false (debería ser true para ops sensibles).
- `sourceIPAddress` — IP corporativa, VPN, o algo raro.
- `eventTime` + `eventName` + `requestParameters` — qué, cuándo, sobre qué recurso.
- `errorCode` / `errorMessage` (ausentes en éxito) — intentos denegados dejan huella y son señal temprana de reconocimiento.

## 4. Query Athena típica sobre el bucket central

```sql
SELECT eventtime, eventname, useridentity.arn, requestparameters
FROM cloudtrail_logs
WHERE eventname IN ('DeleteBucket','PutBucketAcl','DeleteObject')
  AND eventtime > '2026-10-15T00:00:00Z'
ORDER BY eventtime DESC
LIMIT 100;
```

## 5. Qué CloudTrail NO hace

- No registra el **contenido** de los objetos S3 (solo que hubo un `GetObject`). Para eso: **S3 server access logs** o **VPC Flow Logs** si quieres red.
- No registra llamadas **internas** entre servicios AWS que no pasen por tu principal (p. ej. un trigger S3 → Lambda; verás el `Invoke` desde S3 como service principal).
- No es un **SIEM**: necesitas Athena, Security Lake o Splunk para correlación.

## 6. Enlace con el resto del programa

- `aws-15-multi-account` monta el trail de organización como parte del landing zone.
- `aws-16-devsecops-on-aws` usa CloudTrail + GuardDuty + Security Hub como pipeline de detección.
- `prometheus-grafana` no entra aquí: CloudTrail no es métrica, es auditoría.
