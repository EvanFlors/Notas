# Ejemplo 02 — ECS Fargate + ALB (Terraform validate + plan)

Describe la receta Terraform de un servicio **ECS Fargate** detras de un **ALB** sin crearlo en AWS: `terraform init -backend=false`, `terraform validate` y `terraform plan` (dejando que el plan falle a nivel API — queremos la **sintaxis** y el **grafo de recursos**).

Tambien valida **estructuralmente** la `task-definition.json` del servicio: `networkMode=awsvpc`, roles separados, `logConfiguration`, portMappings coherentes.

## Requisitos

- `terraform` >= 1.3.
- `jq`.

## Correr

```bash
cd "$(dirname "$0")"
bash run.sh
```

El script:

1. `SKIP` limpio si falta `terraform` o `jq`.
2. Copia `main.tf` + `task-definition.json` a `/tmp/aws-10-ex02/` (sandbox).
3. `terraform init -backend=false` (descarga provider).
4. `terraform validate` — chequeo de HCL.
5. `terraform plan -input=false -refresh=false` — permite que falle en llamadas AWS reales (no hay credenciales); lo que nos importa es que el **grafo** se construya sin errores de sintaxis o referencias rotas.
6. `jq` sobre `task-definition.json` chequea claves obligatorias.
7. Limpia `/tmp/aws-10-ex02/`.

## Que observar

- `aws_ecs_task_definition.api` referencia los dos roles (`execution_role_arn` ≠ `task_role_arn`).
- `aws_lb_target_group.api` usa `target_type = "ip"` (requerido con `awsvpc` + Fargate).
- `aws_ecs_service.api` tiene `network_configuration` con subnets privadas y SG propio, y `load_balancer { target_group_arn, container_name, container_port }`.
- La `task-definition.json` tiene `networkMode="awsvpc"`, `requiresCompatibilities=["FARGATE"]`, `cpu` y `memory` en combinaciones permitidas, y un `logConfiguration` con `awslogs`.

## Coste

Cero. `terraform plan` falla al llamar AWS (no hay credenciales), pero `validate` ya ha probado el grafo.
