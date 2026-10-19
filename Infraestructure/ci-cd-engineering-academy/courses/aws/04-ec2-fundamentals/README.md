# aws-04 — EC2 Fundamentals

## Identificación

- **ID:** `aws-04-ec2-fundamentals`
- **Curso:** `aws`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `aws-02-iam-fundamentals`, `aws-03-vpc-basics`.

## Objetivo

Entender el compute básico de AWS — aunque luego el curso derive a contenedores y serverless — con el foco puesto en **seguridad por default**: acceso administrativo vía **SSM Session Manager** (no SSH abierto), **IMDSv2 obligatorio**, **instance profile** en vez de credenciales montadas, y **user-data** idempotente.

Al terminar deberías poder:

- Elegir una familia de instancia razonable para un workload dado (general, compute, memory, storage, GPU, ARM/Graviton).
- Levantar una EC2 por Terraform con **IMDSv2 enforced**, **sin SSH abierto**, llegando por **SSM**.
- Explicar la cadena `EC2 → IMDSv2 → STS → credenciales temporales` que da identidad a la aplicación sin keys en disco.
- Escribir un `user-data` reproducible (idempotente y defensivo).
- Diferenciar los tipos de EBS (gp3 / io2 / st1 / sc1) y cuándo aplicar snapshots.
- Esbozar un **launch template** usable por un Auto Scaling Group (introducción).

## Alcance

Este módulo cubre:

- **Familias y tipos** de instancia; nomenclatura (`m7g.large`, `c6i.xlarge`, etc.).
- **AMIs**: oficiales, propias (hechas con Packer/Image Builder), AWS Marketplace. SSM Parameter Store como fuente del AMI ID estable.
- **Keypairs** y por qué el patrón recomendado hoy es **no abrir 22** y entrar por SSM Session Manager.
- **User-data** (cloud-init): idempotencia, logging, estrategias de bootstrap.
- **EBS**: tipos (gp3, io2, st1, sc1), snapshots, encryption at-rest.
- **IMDS v1 vs v2**: por qué v2 (session token) mitiga SSRF-to-credential-leak, cómo forzarlo (`http_tokens = required`).
- **Instance profile**: cómo una EC2 obtiene credenciales temporales vía IMDS → STS a partir del rol asumido.
- **Launch templates** y **Auto Scaling Groups** (introducción; se profundiza más adelante).

Lo que **no** cubre (se verá después):

- EKS (`aws-11`), ECS (`aws-10`), Lambda (en el curso serverless).
- Networking avanzado (ALB/NLB, PrivateLink) → `aws-07`.
- Observabilidad (CloudWatch Agent, OTel) → `aws-12`.

## Enfoque sin costo real

Dado el compromiso del programa de **evitar costos de AWS**, este módulo **no provisiona** instancias reales. Las actividades consisten en:

- Escribir el Terraform correcto (`main.tf`, `variables.tf`, `outputs.tf`, `user-data.sh`).
- Validar el código localmente con `terraform fmt`, `terraform validate`, y — cuando esté disponible — `terraform plan` **sin credenciales reales** (usando `-var` dummy y provider con `skip_credentials_validation`).
- Validar `user-data` como script bash (`bash -n` siempre; `shellcheck` si está instalado).
- Comparar tipos de instancia en una **tabla CSV** de costo estimado.
- Describir el **launch template** en YAML estructural y validarlo.

Los validadores son **estructurales**: comprueban que el código tiene los recursos y atributos correctos, no que levanta la máquina.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — tres ejemplos de lectura:
  - `01-ec2-ssm-no-ssh/` — EC2 accesible solo por SSM, sin puerto 22 abierto.
  - `02-imdsv2-enforced/` — qué cambia al forzar IMDSv2 y por qué.
  - `03-user-data-bootstrap/` — patrones de user-data idempotente.
- **`activities/`** — dos actividades:
  - `01-launch-ec2-reach-via-ssm/` — **guided-lab**: completar un Terraform que define EC2 + rol SSM + user-data; validar en local.
  - `02-attach-instance-profile-and-test-sts/` — **independent**: definir instance profile, policy mínima, snippet de `aws sts get-caller-identity` y tabla comparativa de familias.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la cadena `IMDSv2 → STS → credenciales temporales`. Diferenciar IMDS v1 y v2. Nombrar los 4 tipos clave de EBS. |
| Operativa | Escribir HCL que levanta EC2 con `metadata_options { http_tokens = "required" }`, `iam_instance_profile`, sin SSH abierto, con user-data idempotente. |
| Arquitectónica | Decidir familia e instancia por workload. Decidir SSM vs SSH para acceso administrativo. Decidir EBS por patrón de IO. |

## Criterios de evaluación

- Explica por qué IMDSv1 es un riesgo (SSRF → fuga de credenciales) y cómo IMDSv2 lo mitiga.
- Levanta (código) una EC2 cumpliendo las 4 reglas: IMDSv2, instance profile, sin SSH, user-data idempotente.
- Justifica elección de familia e instancia para 3 workloads.
- Entrega las dos actividades con validador estructural en verde.

## Entregables

- Un `main.tf` + `user-data.sh` reproducibles (sale de la actividad 01).
- Tabla CSV de familias + snippet de verificación STS (sale de la actividad 02).

## Siguiente módulo

→ `aws-05-s3-fundamentals` — S3 con seguridad razonable por default.
