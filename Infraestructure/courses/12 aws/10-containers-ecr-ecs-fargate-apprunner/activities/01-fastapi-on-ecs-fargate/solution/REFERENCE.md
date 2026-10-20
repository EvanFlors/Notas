# Referencia — FastAPI en ECS Fargate detras de ALB

Esta solucion no es la unica correcta: solo una canonica para autoevaluarte.

## Decisiones clave

- **`networkMode = "awsvpc"`** es obligatorio para Fargate. Cada tarea obtiene su
  propia ENI con IP privada en la subred elegida, por eso el security group del
  task se puede referenciar como principal del `aws_security_group_rule` del
  ALB.
- **Roles separados**:
  - `execution_role_arn` lo asume el *agente* de ECS/Fargate. Necesita
    `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`,
    `ecr:GetDownloadUrlForLayer` y `logs:CreateLogStream`/`PutLogEvents`.
    Se consigue adjuntando la managed policy
    `AmazonECSTaskExecutionRolePolicy`.
  - `task_role_arn` lo asume el *proceso de la aplicacion* dentro del
    contenedor cuando usa el SDK de AWS. Aqui va `s3:GetObject` o lo que la app
    realmente necesite — nada mas.
- **`target_type = "ip"`** en el target group. Las tareas Fargate no tienen
  `instance_id`; ECS registra la IP privada de la ENI de cada tarea en el
  target group a medida que escala. `target_type = "instance"` romperia esto.
- **`cpu`/`memory` como strings**: la API de ECS los exige asi, aunque Terraform
  acepte numeros ambiguos. Combinacion `512/1024` es valida en Fargate.
- **`logConfiguration` con `awslogs`**: `awslogs-group`, `awslogs-region` y
  `awslogs-stream-prefix` son las tres opciones minimas; el log group debe
  existir antes (lo creamos en Terraform y lo referenciamos).

## Correspondencia JSON <-> Terraform

| Campo en JSON              | Equivalente en `aws_ecs_task_definition` |
|----------------------------|------------------------------------------|
| `family`                   | `family`                                 |
| `requiresCompatibilities`  | `requires_compatibilities`               |
| `networkMode`              | `network_mode`                           |
| `cpu` / `memory`           | `cpu` / `memory`                         |
| `executionRoleArn`         | `execution_role_arn`                     |
| `taskRoleArn`              | `task_role_arn`                          |
| `containerDefinitions`     | `container_definitions = jsonencode([...])` |

Los nombres cambian de camelCase (JSON API) a snake_case (Terraform HCL), excepto
dentro del bloque `jsonencode(...)` donde se mantiene camelCase porque es JSON.

## Que **no** incluye esta solucion

- No crea VPC, subredes ni NAT: se asume que vienen de un modulo de red previo
  (`aws_03`).
- No pone HTTPS: `aws_13` cubrira ACM + Route 53 + CloudFront.
- No activa autoscaling del servicio: ejercicio opcional.
