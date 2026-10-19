# Starter — FastAPI en ECS Fargate detras de ALB

Copia estos archivos a tu directorio de trabajo:

```bash
mkdir -p /tmp/aws-10-ecs-fargate
cp -r ./* /tmp/aws-10-ecs-fargate/
cd /tmp/aws-10-ecs-fargate
```

Luego:

1. Completa los `TODO` en `task-definition.json`.
2. Completa los `TODO` en `main.tf` (ECS cluster, task definition, service, target group).
3. Corre `terraform init -backend=false && terraform validate`.
4. Corre `bash <ruta-actividad>/tests/validate.sh /tmp/aws-10-ecs-fargate`.

No se necesita cuenta AWS: `provider "aws"` esta configurado con credenciales
*fake* y `skip_*` para que `validate` no llame a AWS.
