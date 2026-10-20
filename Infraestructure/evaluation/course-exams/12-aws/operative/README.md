# Ejercicio operativo — Examen AWS

Peso total: **35%** del examen. Duración sugerida: **40–50 min**.

## Entorno

- **No** se requiere cuenta AWS real. **No** se evalúa consumo.
- Validación en este orden de preferencia:
  1. **LocalStack Community** (`DOCKER` + `localstack start`) para S3/IAM/STS.
  2. `terraform validate` + `terraform plan` con el provider en modo offline (`skip_credentials_validation = true`, `skip_metadata_api_check = true`, `skip_requesting_account_id = true`, endpoints apuntando a `http://localhost:4566`).
  3. Lectura estática del código si lo anterior no está disponible (SKIP automático documentado).
- Account IDs permitidos: **`123456789012`** y **`210987654321`**. Cualquier otro ID = `red flag` de "cuenta real filtrada".
- Prohibido: `terraform apply` contra AWS real; `aws configure` con credenciales reales; secretos en texto plano.

## Entregables

Un directorio `submission/` con:

```
submission/
  task-1-s3/
    main.tf
    variables.tf
    README.md
  task-2-oidc-audit/
    before/            # el pipeline original (dado en fixtures/)
    after/             # tu versión corregida
    AUDIT.md           # hallazgos + justificación
  task-3-observability/
    cloudwatch.tf
    retention-policy.md
    alarms.tf
```

Y, al nivel raíz de `submission/`, un `report.md` con un resumen de cada tarea (máx. 300 palabras cada una).

> **No** entregues un `ANALYSIS.md`.

---

## OP-task-1 — S3 bucket seguro por default (C5) — 12 pts

### Enunciado

Escribe Terraform para un bucket S3 llamado `reports-${var.env}-${random_id}` que cumpla:

1. Block Public Access habilitado en los 4 flags.
2. Versioning activado.
3. SSE-KMS con una CMK propia (no `aws/s3`), con `bucket_key_enabled = true`.
4. Lifecycle: `logs/` → Glacier IR a 30 días, expiración a 365 días; multipart aborted a 7 días.
5. Bucket policy que deniega conexiones sin TLS (`aws:SecureTransport = false`) y deniega `s3:*` si no viene del `aws:PrincipalOrgID = "o-exampleorg"`.
6. Logging a bucket aparte `reports-${var.env}-access-logs` (sólo crea el recurso, no el bucket destino).
7. Variables tipadas: `env` (`dev`|`stg`|`prod`), `kms_admin_role_arn`.
8. Outputs: `bucket_name`, `bucket_arn`, `kms_key_arn`.

### Validación

```bash
cd submission/task-1-s3
terraform init -backend=false
terraform validate
terraform plan \
  -var='env=dev' \
  -var='kms_admin_role_arn=arn:aws:iam::123456789012:role/kms-admin' \
  -out=tfplan.binary
terraform show -json tfplan.binary > plan.json

# Checks estáticos con jq:
jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_public_access_block") | .change.after | select(.block_public_acls==true and .block_public_policy==true and .ignore_public_acls==true and .restrict_public_buckets==true)' plan.json
jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_versioning") | .change.after.versioning_configuration[0].status | select(.=="Enabled")' plan.json
jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_server_side_encryption_configuration")' plan.json
jq -e '.resource_changes[] | select(.type=="aws_s3_bucket_policy") | .change.after.policy' plan.json | grep -q 'aws:SecureTransport'
```

(Script completo en `validate.sh`.)

### Rúbrica

| Criterio | Insuf (0) | Básico (1) | Comp (2) | Experto (3) |
|---------|-----------|------------|----------|-------------|
| BPA + versioning + SSE | Falta alguno | Los tres presentes pero con `aws/s3` | CMK propia con bucket key | CMK + rotation + alias documentado |
| Lifecycle | Ausente | Solo expiración | Expiración + transición + multipart | Todo + justificación coste |
| Bucket policy | Sin SecureTransport ni PrincipalOrgID | Uno de los dos | Ambos | Ambos + Deny explícito al root y a usuarios IAM (fuerza SSO) |
| Operabilidad | No `plan`ea | `plan` pasa | `plan` + `validate` + `fmt` | Lo anterior + tflint/checkov limpio |

---

## OP-task-2 — Auditar y corregir pipeline OIDC GitHub Actions → AWS (C2, C13) — 15 pts

### Enunciado

En `fixtures/` encontrarás `pipeline-before.yml` (workflow GHA) y `trust-policy-before.json` (trust policy del rol). Están rotos. Entrégame:

- `before/` tal cual.
- `after/pipeline.yml` y `after/trust-policy.json` corregidos.
- `AUDIT.md` listando cada hallazgo con: evidencia (linea), categoría (`security`/`correctness`/`cost`), severidad (`critical`/`high`/`medium`/`low`), fix propuesto, justificación en ≤4 líneas.

Debes encontrar **al menos** estos 6 problemas (hay más):

1. Trust policy con `sub: *` o sin `sub`.
2. Uso de `aws-actions/configure-aws-credentials` con `aws-access-key-id` / `aws-secret-access-key` en vez de `role-to-assume` + OIDC.
3. Secreto hardcodeado en env del workflow.
4. `permissions:` del workflow sin `id-token: write` (OIDC roto) o con `contents: write` innecesario.
5. Account ID real filtrado (deberá quedar como `123456789012`).
6. Imagen pusheada a ECR sin scan ni firma (falta `aws ecr get-login-password`, falta `cosign sign` o `--immutable-tags`).

### Fixtures (ya provistos)

Ver `fixtures/pipeline-before.yml` y `fixtures/trust-policy-before.json`.

### Validación

```bash
# el workflow después debe pasar actionlint
actionlint submission/task-2-oidc-audit/after/pipeline.yml

# el trust policy después debe contener sub pinneado
jq -e '.Statement[] | .Condition.StringEquals["token.actions.githubusercontent.com:sub"]' \
  submission/task-2-oidc-audit/after/trust-policy.json | grep -E 'repo:[^:]+:(environment|ref|pull_request)'

# cero credenciales largas en el workflow
! grep -E 'aws-(access-key-id|secret-access-key)' submission/task-2-oidc-audit/after/pipeline.yml

# ningún account id distinto al dummy en los entregables
! grep -rE '\b[0-9]{12}\b' submission/task-2-oidc-audit/after/ | grep -v '123456789012\|210987654321'
```

### Rúbrica

| Criterio | Insuf (0) | Básico (1) | Comp (2) | Experto (3) |
|---------|-----------|------------|----------|-------------|
| Hallazgos encontrados | <3 de los 6 | 4–5 | Los 6 | Los 6 + hallazgos extra pertinentes |
| Trust policy corregido | Sigue sin pinnear | `sub` pinneado a repo | pinneado a repo + env/ref | pinneado + `aud` + comentario doc + least priv del role atttached |
| Justificación | Repite el fix | Nombra el riesgo | Explica attack path | Attack path + impacto + referencia a SRA/OIDC spec |

---

## OP-task-3 — Retención y alarmas CloudWatch (C9) — 8 pts

### Enunciado

Para una app FastAPI corriendo en ECS Fargate detrás de ALB, entrega:

1. `cloudwatch.tf` con log groups por servicio: `app` (retention 30 días), `audit` (400 días), `access-logs-alb` (90 días). KMS encryption en todos.
2. `alarms.tf` con:
   - **Composite alarm** `prod-api-degraded` = (5xx-rate > 1% durante 5 min) **AND** (p99 latency > 500 ms durante 5 min).
   - **Anomaly detection alarm** sobre `RequestCount` del ALB con banda ±2σ.
   - SNS topic `ops-alerts` (sólo recurso; sin suscripciones reales).
3. `retention-policy.md` (≤ 300 palabras) justificando: por qué estas retenciones, qué métricas de las ingestadas se exportan a Prometheus vía ADOT, qué logs sí se archivan a S3 vía subscription filter y por qué CW Insights no sustituye a Loki para alto volumen.

### Validación

```bash
cd submission/task-3-observability
terraform init -backend=false && terraform validate
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > plan.json

jq -e '[.resource_changes[] | select(.type=="aws_cloudwatch_log_group")] | length >= 3' plan.json
jq -e '.resource_changes[] | select(.type=="aws_cloudwatch_composite_alarm")' plan.json
jq -e '.resource_changes[] | select(.type=="aws_cloudwatch_metric_alarm" and (.change.after.metric_query // [] | length > 0))' plan.json
```

### Rúbrica

| Criterio | Insuf (0) | Básico (1) | Comp (2) | Experto (3) |
|---------|-----------|------------|----------|-------------|
| Retenciones | Infinita o 1 solo valor | Diferenciadas pero sin justificación | Diferenciadas + justificación | + estrategia S3 + Glacier + costo estimado |
| Alarma composite | Ausente | Métrica única | Composite con 2 señales | Composite + anomaly + justificación falsos positivos |
| Encryption | Sin KMS | KMS AWS-managed | CMK propia | CMK + key policy mínima |

---

## Red flags que invalidan la tarea entera

Ver `../competency-matrix.yaml` → `red_flags`. Específicos de operativa:

- Any `aws-access-key-id`/`aws-secret-access-key` en workflows.
- `sub: "*"` o ausencia de `sub` en trust policy OIDC.
- Account ID real.
- `terraform apply` ejecutado contra AWS real (lo sabemos por `terraform.tfstate` con account real).
- Secretos hardcodeados (p. ej. password en `main.tf`).

## Script `validate.sh`

Ver `validate.sh` en este directorio. Ejecuta las tres tareas en secuencia y resume PASS/FAIL por check. Si LocalStack no está disponible, los pasos que lo requieren se marcan `SKIP` con razón, no `FAIL`.
