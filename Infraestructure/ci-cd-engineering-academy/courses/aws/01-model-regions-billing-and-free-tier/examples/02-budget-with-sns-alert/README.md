# Ejemplo 02 — Presupuesto con alerta SNS (Terraform `plan` sin `apply`)

> Objetivo: leer el *shape* de un `aws_budgets_budget` + `aws_sns_topic` + `aws_sns_topic_subscription` sin crear nada en AWS. Usa credenciales ficticias; se queda en `terraform plan`.

**Costos:** cero. **Red:** cero (Terraform `plan` offline-friendly salvo descarga del provider la primera vez).

## 1. Qué modelamos

Un presupuesto típico de cuenta nueva:

- **50 USD/mes** de coste total.
- Alertas vía **SNS topic** cuando se alcance:
  - 50 % del budget (actual).
  - 80 % del budget (actual).
  - 100 % **previsto** (forecast).
- Email del equipo responsable suscrito al topic.

Esto es lo que configurarías el día 1 de una cuenta real, en el orden del runbook de la lección.

## 2. Archivos

- `main.tf` — recursos.
- `variables.tf` — email y nombre del budget parametrizados.
- `terraform.tfvars.example` — ejemplo con valores no reales.

## 3. `main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credenciales ficticias. Este modulo se usa SOLO con `terraform plan`.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

resource "aws_sns_topic" "billing_alerts" {
  name = "${var.name_prefix}-billing-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_budgets_budget" "monthly_cost" {
  name              = "${var.name_prefix}-monthly-cost"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_limit_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.billing_alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.billing_alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.billing_alerts.arn]
  }
}
```

## 4. `variables.tf`

```hcl
variable "name_prefix" {
  type        = string
  default     = "aws-01-demo"
  description = "Prefijo para los recursos."
}

variable "alert_email" {
  type        = string
  description = "Email que recibira las alertas de budget."
}

variable "monthly_limit_usd" {
  type        = number
  default     = 50
  description = "Limite mensual del budget en USD."
}
```

## 5. `terraform.tfvars.example`

```hcl
alert_email       = "finops@example.com"
monthly_limit_usd = 50
```

## 6. Cómo ejecutar (SOLO `plan`)

```bash
cd examples/02-budget-with-sns-alert
cp terraform.tfvars.example terraform.tfvars  # edita con tu email de pruebas
terraform init
terraform plan -out=/tmp/aws-01-ex02.plan
```

**NO ejecutes `terraform apply`**. Con las credenciales ficticias no funcionaría contra AWS real, y contra una cuenta real crearía recursos — este módulo aún no ha visto cómo auditarlos.

## 7. Qué buscar en el plan

```
# aws_budgets_budget.monthly_cost will be created
+ resource "aws_budgets_budget" "monthly_cost" {
    + name              = "aws-01-demo-monthly-cost"
    + budget_type       = "COST"
    + limit_amount      = "50.0"
    + limit_unit        = "USD"
    + time_unit         = "MONTHLY"
    ...
    + notification { threshold = 50 ... notification_type = "ACTUAL" }
    + notification { threshold = 80 ... notification_type = "ACTUAL" }
    + notification { threshold = 100 ... notification_type = "FORECASTED" }
  }

# aws_sns_topic.billing_alerts will be created
+ resource "aws_sns_topic" "billing_alerts" {
    + name = "aws-01-demo-billing-alerts"
    ...
  }

# aws_sns_topic_subscription.email will be created
+ resource "aws_sns_topic_subscription" "email" {
    + protocol = "email"
    + endpoint = "finops@example.com"
    ...
  }

Plan: 3 to add, 0 to change, 0 to destroy.
```

Qué llevarte del plan:

- **3 recursos**: el budget, el topic SNS, la suscripción email.
- **3 notificaciones** sobre el mismo budget: 50/80 % actual + 100 % previsto. Es el patrón mínimo recomendado.
- La suscripción email requiere confirmación por correo en AWS real; sin confirmar, no llegan avisos.

## 8. Variante SNS → Lambda → Slack (para pensar)

Si quisieras que la alerta cayera en Slack en vez de email, el topic SNS no cambia; añades:

- Una `aws_lambda_function` suscrita al topic.
- La Lambda recibe el evento SNS, formatea y hace POST al webhook de Slack.

Queda **fuera** de este ejemplo porque Lambda ejecutada cuesta (céntimos, pero cuesta), y este módulo se mantiene a coste cero.

## 9. Limpieza

Solo hay archivos locales:

```bash
rm -rf .terraform .terraform.lock.hcl terraform.tfvars /tmp/aws-01-ex02.plan
```

## 10. Qué llevarte

- Un budget en Terraform son ~15 líneas por notificación. Vale la pena por el seguro mental.
- SNS es el *fan-out* natural de alertas AWS: email, SMS, Lambda, HTTP.
- El `forecast` es tan importante como el `actual`: te avisa **antes** de pasar.
- `plan` + credenciales ficticias es tu primer sandbox para leer *shapes* de AWS sin arriesgar nada.
