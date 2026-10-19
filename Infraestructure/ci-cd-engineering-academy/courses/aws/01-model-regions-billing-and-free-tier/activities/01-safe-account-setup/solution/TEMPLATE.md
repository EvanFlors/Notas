# TEMPLATE de referencia — aws-01-01-safe-account-setup

> Este es un ejemplo de runbook completo. Compáralo con tu `ACCOUNT-SETUP.md` **después** de haberlo escrito.

## Archivo `ACCOUNT-SETUP.md` (referencia)

```markdown
# Runbook: puesta en marcha segura de cuenta AWS

> Cuenta objetivo: 123456789012. Region primaria: us-east-1.
> Ejecutor: humano con acceso temporal al email root.

## Paso 1 — MFA en root
Descripcion: activar MFA (TOTP o hardware token) en la identidad root.
Comando/navegacion:
` ` `bash
# No hay CLI: solo consola.
# 1) login en console.aws.amazon.com como root (email + password)
# 2) menu usuario (arriba derecha) -> My Security Credentials
# 3) Multi-factor authentication -> Assign MFA device
` ` `
Verificacion:
` ` `bash
aws iam get-account-summary --profile tmp-root-check | grep -i mfa
# AccountMFAEnabled = 1
` ` `

## Paso 2 — Borrar access keys de root
Descripcion: si existen, borrarlas. Idealmente nunca existieron.
Comando/navegacion:
` ` `bash
# Consola -> My Security Credentials -> Access keys -> Delete
# No existe CLI para listar keys del root desde otro principal.
` ` `
Verificacion: en la misma seccion, la lista aparece vacia.

## Paso 3 — IAM access to Billing
Descripcion: permitir que roles no-root puedan leer billing.
Comando/navegacion:
` ` `bash
# Consola -> Account -> IAM user and role access to Billing information -> Edit -> Activate
` ` `
Verificacion: tras asumir un rol admin, `aws ce get-cost-and-usage ...` responde en vez de dar AccessDenied.

## Paso 4 — Budget con alerta
Descripcion: budget de 50 USD/mes, alertas en 50/80 % actual y 100 % forecast, via SNS + email.
Comandos (preferido: Terraform plan — ver examples/02):
` ` `bash
cd ../../examples/02-budget-with-sns-alert
terraform init
terraform plan -var alert_email=finops@example.com
# tras revisar, un operador con permisos apropiados hara apply.
` ` `
Alternativa CLI directa:
` ` `bash
aws budgets create-budget --account-id 123456789012 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
` ` `
Verificacion:
` ` `bash
aws budgets describe-budgets --account-id 123456789012
# Devuelve el budget "aws-01-demo-monthly-cost" con 3 notifications.
` ` `

## Paso 5 — Admin humano no-root
Decision: **IAM Identity Center** (SSO) por encima de IAM user. Razones: credenciales temporales por default, MFA integrado, un portal para N cuentas, sin access keys que fuguen.
Comandos:
` ` `bash
# Habilitar Identity Center (una vez por organizacion):
aws sso-admin list-instances
# Crear permission set AdministratorAccess y asignarlo al usuario:
aws sso-admin create-permission-set --name AdministratorAccess ...
aws sso-admin attach-managed-policy-to-permission-set \
  --managed-policy-arn arn:aws:iam::aws:policy/AdministratorAccess ...
aws sso-admin create-account-assignment \
  --target-id 123456789012 --target-type AWS_ACCOUNT ...
` ` `
Verificacion:
` ` `bash
aws sso login --profile admin
aws sts get-caller-identity --profile admin
# Arn debe ser: arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_xxxx/alice
` ` `

## Paso 6 — Cerrar sesion de root
Descripcion: logout del navegador, guardar password+MFA en un password manager con MFA propia.
Checklist:
- [ ] Password del root guardado en gestor con MFA
- [ ] MFA device (TOTP seed o hardware) guardado offline
- [ ] Email root tiene MFA propio
- [ ] Nadie mas tiene el email root sin motivo

## Paso 7 — CloudTrail
Descripcion: trail multi-region de management events, va a bucket S3 propio.
Comando:
` ` `bash
aws cloudtrail create-trail --name org-trail \
  --s3-bucket-name cloudtrail-123456789012-logs \
  --is-multi-region-trail --enable-log-file-validation
aws cloudtrail start-logging --name org-trail
` ` `
Verificacion:
` ` `bash
aws cloudtrail get-trail-status --name org-trail
# IsLogging = true
` ` `

## Cargos silenciosos (fuera de Free Tier)

- **NAT Gateway**: ~0.045 USD/h = ~32 USD/mes solo por existir + 0.045 USD/GB procesado.
- **Elastic IPs sin asociar**: ~3.6 USD/mes por IP ociosa.
- **EBS snapshots acumulados**: ~0.05 USD/GB/mes. Snapshots viejos son el leak #2.
- **Egress a internet** mas alla de 100 GB/mes gratis: ~0.09 USD/GB.
- **ALB/NLB idle**: ~16 USD/mes por load balancer encendido aunque no sirva trafico.
- **CloudWatch Logs** sin retention: ~0.50 USD/GB ingestado + storage perpetuo.
- **KMS CMK**: 1 USD/mes por key gestionada + 0.03 USD por 10k requests.
```

## Archivo `COSTS.md` (referencia)

```markdown
# Estimacion mensual — workload trivial

## Workload
- 1 x EC2 t3.micro, 730 h/mes, us-east-1, Linux on-demand
- 10 GB S3 Standard
- 50 GB egress a internet
- (hipotetico) 1 NAT Gateway con 20 GB procesados

## Estimacion (precios on-demand, us-east-1, orientativos)
| Item | Precio unitario | Cantidad | Mensual |
|------|-----------------|----------|---------|
| EC2 t3.micro Linux | 0.0104 USD/h | 730 h | 7.59 USD |
| S3 Standard | 0.023 USD/GB | 10 GB | 0.23 USD |
| Egress (sobre 100 GB free) | 0.09 USD/GB | 0 GB (50 <= 100 gratis) | 0.00 USD |
| **Subtotal sin NAT** |  |  | **~7.82 USD** |
| NAT Gateway hora | 0.045 USD/h | 730 h | 32.85 USD |
| NAT Gateway procesado | 0.045 USD/GB | 20 GB | 0.90 USD |
| **Total con NAT** |  |  | **~41.57 USD** |

## Comentarios
- En los **primeros 12 meses** la EC2 t3.micro cae en Free Tier (750 h/mes) → 0 USD por compute si es la unica instancia.
- S3 10 GB cae en Free Tier 12 meses (5 GB gratis, cobras 5 GB → 0.11 USD).
- El egress 50 GB cae dentro de los 100 GB gratis always-free globales → 0 USD.
- Introducir **1 NAT Gateway** multiplica x5 el coste total del workload. Esto justifica aprender VPC endpoints (modulo aws-03).
- Un budget de 20 USD con alerta al 80 % te hubiera avisado el dia que arrancaste el NAT por error.
```
