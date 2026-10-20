# Ejemplo 03 — App Runner one-click (Terraform validate + plan)

Describe un servicio **App Runner** apuntando a una imagen en ECR, con HTTPS gestionado por AWS. Como en el ejemplo 02, no se crea nada: `terraform validate` + `plan` sobre fake creds.

## Requisitos

- `terraform` >= 1.3.

## Correr

```bash
cd "$(dirname "$0")"
bash run.sh
```

El script:

1. `SKIP` si falta `terraform`.
2. Copia `main.tf` a `/tmp/aws-10-ex03/`.
3. `terraform init -backend=false`.
4. `terraform validate`.
5. `terraform plan` toleramos fallo (no hay AWS real).
6. Chequea que el `main.tf` contenga los recursos clave de App Runner (`aws_apprunner_service`, `health_check_configuration`, `source_configuration.image_repository`).
7. Limpia.

## Que observar en `main.tf`

- `aws_apprunner_service.api` con `source_configuration.image_repository.image_identifier` apuntando a una imagen ECR.
- `authentication_configuration.access_role_arn` — un rol IAM que App Runner asume para hacer `pull` desde ECR (equivalente al execution role en ECS).
- `instance_configuration.cpu` y `memory` en los valores limitados de App Runner (`"1024"` vCPU y `"2048"` MB en el ejemplo).
- `health_check_configuration` con path y protocolo.
- `auto_deployments_enabled = false` — explicito para evitar sorpresas de CD automatico.

## Diferencias con ECS/Fargate (ejemplo 02)

| Aspecto | ECS/Fargate (ex 02) | App Runner (ex 03) |
|---------|---------------------|---------------------|
| Lineas de HCL | ~150 | ~40 |
| ALB | explicito | gestionado |
| HTTPS | configuras ACM + listener | automatico |
| N contenedores por tarea | 1+ (sidecars posibles) | **1** |
| Autoscaling | ApplicationAutoScaling policy | integrado por `max_concurrency` |
| Observabilidad | logs + metrics configurables | basica |
| Control de red | VPC, subnets, SG | opcional via `network_configuration` |

Si tu caso **cabe** en App Runner, es la mitad de superficie. Si no, ECS/Fargate.

## Coste

Cero.
