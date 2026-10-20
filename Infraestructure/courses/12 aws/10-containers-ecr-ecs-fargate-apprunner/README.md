# aws-10 — Containers en AWS: ECR, ECS, Fargate y App Runner

## Identificación

- **ID:** `aws-10-containers-ecr-ecs-fargate-apprunner`
- **Nivel:** intermedio
- **Duración estimada:** 6 h
- **Prerrequisitos:** curso **docker**; `aws-02-iam-fundamentals`, `aws-03-vpc-basics`, `aws-07-networking-advanced`.

## Objetivo

Correr contenedores en AWS **sin Kubernetes** cuando no se justifica. Terminar el módulo entendiendo cuándo usar **ECS/Fargate** (el "sweet spot" para la mayoría de servicios HTTP), cuándo **App Runner** (opinionado, cero devops) y qué papel juega **ECR** (registry gestionado) como ancla del *supply chain* de imágenes.

## Alcance

Este módulo cubre:

- **ECR** privado y público, *scan on push* básico, *lifecycle policies* para controlar coste de almacenamiento, replicación cross-región y permisos IAM que gobiernan el `push` desde CI y el `pull` desde la plataforma.
- **ECS**: `cluster`, `task definition`, `service`, los dos *launch types* (**EC2** vs **Fargate**), modo de red `awsvpc` (ENI por tarea), *service discovery* vía **Cloud Map** y asociación con un **ALB** por target group.
- **IAM dentro de ECS**: la distinción crítica entre **execution role** (quién puede *pullear* la imagen desde ECR y escribir en CloudWatch Logs) y **task role** (quién asume el proceso de la aplicación cuando llama a servicios AWS).
- **App Runner**: la alternativa más opinionada — pensada para una API detrás de HTTPS sin tener que diseñar red, task definitions ni ALBs; se da la URL de un repo ECR o de GitHub y AWS resuelve el resto, con menos palancas.

## Fundamentos internos

- **Execution role vs task role.** Es el error de diseño IAM más común en ECS. El *execution role* lo asume **ECS/Fargate** (no tu código) para *pullear* la imagen de ECR, resolver secretos de Secrets Manager/SSM que inyectas por variable de entorno, y escribir logs a CloudWatch. El *task role* lo asume el **proceso de la aplicación** corriendo dentro del contenedor cuando usa el SDK de AWS (p. ej. subir a S3). Si confundes ambos, acabas o dando permisos excesivos al runtime, o rompiendo el `pull` de la imagen con "image not found" cuando en realidad es un `AccessDenied`.
- **Por qué Fargate elimina EC2 pero no IAM/networking.** Fargate te quita la gestión del plano de datos (no hay AMIs, ni parchear SO, ni autoscaling groups), pero cada tarea sigue siendo una ENI con una IP privada en una subred tuya, con security groups tuyos, con roles IAM tuyos y con logs tuyos. "Serverless" en ECS significa "no gestionas los nodos", **no** "no diseñas red ni IAM".
- **ALB target group por servicio, no por cluster.** La naturaleza dinámica de IPs de las tareas Fargate exige que el ALB resuelva *targets* por **IP** (no por *instance id*). ECS registra/deregistra IPs de las tareas en el target group a medida que escalan — por eso cada *service* ECS se mapea 1:1 con un target group.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — tres demos de lectura y ejecución local (coste 0, sin AWS real):
  - [`01-ecr-push-from-ci/`](examples/01-ecr-push-from-ci/) — construir una imagen FastAPI y empujarla a un **registry local `registry:2`** que actúa como *stand-in* de ECR.
  - [`02-ecs-fargate-service/`](examples/02-ecs-fargate-service/) — Terraform `init + validate` + `plan` de un servicio ECS Fargate detrás de ALB, con `task-definition.json` validada estructuralmente (sin crear nada en AWS).
  - [`03-apprunner-oneclick/`](examples/03-apprunner-oneclick/) — Terraform `validate` + `plan` de un servicio **App Runner** apuntando a un repo ECR imaginario.
- **`activities/`** — dos actividades (independientes entre sí):
  - [`activities/01-fastapi-on-ecs-fargate/`](activities/01-fastapi-on-ecs-fargate/) — *guided-lab*: completa un `task-definition.json` + Terraform de ECS Fargate + ALB para una app FastAPI, validando estructura.
  - [`activities/02-ecr-lifecycle-policy-cost/`](activities/02-ecr-lifecycle-policy-cost/) — *independent*: diseñar una `lifecycle-policy.json` para contener coste de ECR, defendiendo cada regla.
- **`resources/links.md`** — documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia *execution role* ↔ *task role* sin dudar; justificar `awsvpc` + ALB-by-IP; nombrar los *trade-offs* de ECS/Fargate vs EC2 vs App Runner. |
| Operativa | Construir una imagen de una API en Docker, empujarla a un registry (ECR o compatible), redactar una task definition válida y describir un *service* ECS detrás de ALB. |
| Arquitectónica | Decidir, dado un caso ("una API HTTP sin equipo devops dedicado", "una flota de microservicios con *sidecars*"), si usar **App Runner**, **ECS/Fargate** o **ECS/EC2**, con las *razones* detrás. |

## Criterios de evaluación

- Define en una frase por qué el *execution role* no es un rol que use el código de la app.
- Enumera al menos tres razones concretas para preferir **Fargate** sobre **EC2** como *launch type*.
- Enumera al menos dos escenarios donde **App Runner** encaja mejor que ECS/Fargate, y uno donde definitivamente **no**.
- Produce una `task-definition.json` sintácticamente válida con `networkMode=awsvpc`, roles separados, logging a CloudWatch, y pasa el validador estructural de la actividad 01.
- Produce una `lifecycle-policy.json` que combine reglas por *tag* y por antigüedad y pasa el validador estructural de la actividad 02.

## Entregables

- Terraform `.tf` + `task-definition.json` del servicio FastAPI corriendo en ECS Fargate detrás de ALB (actividad 01).
- `lifecycle-policy.json` con al menos tres reglas y defensa escrita (actividad 02).
- Imagen Docker construida localmente y empujada al registry local (ejemplo 01).

## Evaluación de altura (opcional)

Para la app del capstone, defender por escrito en 1 página: **ECS vs EKS vs Lambda vs App Runner**. Dar los *drivers* de decisión (equipo, SLOs, concurrencia, estado, latencia P99, coste, control sobre red, portabilidad).

## Siguiente módulo

→ `aws-11-eks-in-depth` — cuando ECS/Fargate **no basta** y hace falta Kubernetes gestionado.
