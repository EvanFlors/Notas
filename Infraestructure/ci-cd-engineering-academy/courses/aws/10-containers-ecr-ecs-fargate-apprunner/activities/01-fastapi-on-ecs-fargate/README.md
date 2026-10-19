# Actividad 01 — FastAPI en ECS Fargate detras de ALB

## 1. Identificacion

- **ID:** `aws-10-01-fastapi-on-ecs-fargate`
- **Tecnologia:** `aws`
- **Modulo:** `aws-10-containers-ecr-ecs-fargate-apprunner`
- **Dificultad:** intermediate
- **Duracion estimada:** 80-100 min
- **Tipo:** guided-lab

## 2. Contexto

El equipo del capstone necesita publicar una API HTTP en Python (FastAPI) con dos
replicas detras de un ALB publico. El plano de datos lo pone **ECS/Fargate** (sin
EC2 propia) y la imagen se asume ya construida y publicada en ECR. **Nadie va a
desplegar esto en una cuenta real desde este laboratorio** — el objetivo es
producir y validar los artefactos (`task-definition.json` + `.tf`) que un
pipeline de verdad aplicaria luego.

Trabajaras en papel (archivos locales). El validador comprueba **estructura**, no
funcionamiento real en AWS.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Explicar en una frase por que un servicio ECS/Fargate detras de ALB exige
  `target_type = "ip"` en el target group (y no `instance`).
- Describir que principal asume el `execution_role_arn` y que principal asume el
  `task_role_arn`, y por que confundirlos termina en `AccessDenied` al pullear
  la imagen o en permisos excesivos al runtime.
- Redactar una `task-definition.json` con `networkMode=awsvpc`, roles separados,
  `requiresCompatibilities=[FARGATE]`, `cpu`/`memory` validos y logging a
  CloudWatch via `awslogs`.
- Redactar Terraform minimo de un `aws_ecs_cluster`, un `aws_ecs_task_definition`,
  un `aws_ecs_service` con `launch_type=FARGATE` y un `aws_lb_target_group` con
  `target_type=ip`.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (secciones de ECS, Fargate, IAM roles y
  ALB target groups).
- Haber recorrido `../../examples/02-ecs-fargate-service/` como referencia.
- Herramientas locales: `bash`, `jq`, `terraform` (>= 1.3). **No** se necesita
  cuenta AWS ni credenciales reales.
- Costos esperados: **cero**. Todo se queda en tu disco.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-10-ecs-fargate
cp -r starter/* /tmp/aws-10-ecs-fargate/
cd /tmp/aws-10-ecs-fargate
```

Puedes trabajar en otra ruta pasandola al validador:
`bash tests/validate.sh /tu/ruta`.

### 5.2 Completa `task-definition.json`

El starter trae un esqueleto con marcadores `TODO`. Debes rellenar:

- `family` (string no vacio).
- `requiresCompatibilities` con `"FARGATE"`.
- `networkMode` igual a `"awsvpc"` (obligatorio para Fargate).
- `cpu` y `memory` (strings, combinacion valida de Fargate — p. ej. `"512"`/`"1024"`).
- `executionRoleArn` y `taskRoleArn` **distintos** (dos ARNs IAM separados).
- `containerDefinitions[0]`:
  - `name`, `image`, `essential: true`.
  - `portMappings` con al menos un puerto (p. ej. `8000/tcp`).
  - `logConfiguration` con `logDriver: "awslogs"` y las tres opciones
    `awslogs-group`, `awslogs-region`, `awslogs-stream-prefix`.

### 5.3 Completa `main.tf`

El starter trae `providers` y variables listas. Debes anadir:

- `aws_ecs_cluster` con `name`.
- `aws_ecs_task_definition` reutilizando los mismos valores clave que tu JSON
  (familia, roles, `network_mode = "awsvpc"`, `requires_compatibilities`,
  `cpu`, `memory`, `container_definitions`).
- `aws_lb_target_group` con `target_type = "ip"` y `health_check` razonable.
- `aws_ecs_service` con `launch_type = "FARGATE"`, `desired_count` >= 1,
  `network_configuration` apuntando a subredes privadas y SG de tareas, y un
  bloque `load_balancer` conectado al target group.

### 5.4 Valida localmente

```bash
cd /tmp/aws-10-ecs-fargate
terraform init -backend=false
terraform validate
```

`terraform validate` **no** llama a AWS. Si falla, lee el mensaje y corrige.

### 5.5 Ejecuta el validador estructural

```bash
bash tests/validate.sh /tmp/aws-10-ecs-fargate
```

## 6. Resultado esperado

- `task-definition.json` es JSON valido y cumple todas las comprobaciones.
- `main.tf` pasa `terraform validate` y contiene los recursos esperados.
- El validador imprime `OK: estructura valida` y sale con codigo 0.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural pasa; `terraform validate` pasa.
- **Calidad**: roles separados, `target_type=ip`, `networkMode=awsvpc`, logs a
  CloudWatch con los tres campos de `options`.
- **Reproducibilidad**: cualquiera puede clonar el starter y reproducir la
  entrega siguiendo este README.
- **Mantenibilidad**: nombres consistentes entre JSON y Terraform (misma
  familia, mismo container name, mismo puerto).

## 8. Validacion

```bash
bash tests/validate.sh /tmp/aws-10-ecs-fargate
```

Si quieres compararte con la referencia:

```bash
diff -u solution/task-definition.json /tmp/aws-10-ecs-fargate/task-definition.json
```

## 9. Preguntas de reflexion

1. Si cambiaras `target_type` a `instance`, el target group dejaria de registrar
   las tareas Fargate. ¿Por que exactamente?
2. ¿Que error exacto veras si el `execution_role_arn` no tiene permiso
   `ecr:GetDownloadUrlForLayer`? ¿Y el *symptom* visible en consola?
3. ¿Por que `cpu` y `memory` son strings y no numeros en la task definition?
4. Si moviste la app a dos regiones, ¿que recursos de este Terraform se
   duplican por region y cuales no?

## 10. Extensiones

- Anade un segundo contenedor sidecar (p. ej. un envoy local) en la misma task
  definition, declarando `dependsOn` y `essential`.
- Anade un `aws_ecs_capacity_provider_strategy` mezclando `FARGATE` y
  `FARGATE_SPOT`.
- Reemplaza la condicion `cidr_blocks` del SG del ALB por un
  `aws_security_group_rule` referenciando CloudFront prefix list.

## 11. Limpieza

```bash
rm -rf /tmp/aws-10-ecs-fargate
```

No hay infraestructura real que destruir.
