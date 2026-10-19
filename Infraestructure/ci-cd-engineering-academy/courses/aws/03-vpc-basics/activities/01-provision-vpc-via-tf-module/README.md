# Actividad 01 — Modulo Terraform de VPC multi-AZ (plan-only)

## 1. Identificación

- **ID:** `aws-03-01-provision-vpc-via-tf-module`
- **Tecnología:** `aws`
- **Módulo:** `aws-03-vpc-basics`
- **Dificultad:** beginner
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Vas a escribir tu propio **módulo Terraform de VPC multi-AZ**, de los que luego reutilizas en los módulos EC2, RDS, EKS, etc. Es tu primera pieza de "infraestructura de verdad" en el curso.

**Pero no lo vas a aplicar en AWS.** El trabajo es:

1. Escribir el HCL correctamente.
2. Pasar `terraform validate`.
3. Pasar `terraform plan` en modo offline (provider mockeado, sin credenciales reales).
4. Documentarlo con un **diagrama ASCII** en `DESIGN.md`.

Así ejercitas el 95 % del aprendizaje de este módulo (CIDR, subnets, RTs, IGW, SG, endpoints) sin incurrir en **ningún** costo AWS. En un módulo futuro (por ejemplo `aws-04-ec2`) retomarás el patrón y, si tienes cuenta sandbox, podrás aplicarlo.

## 3. Objetivos

Al terminar deberías poder:

- Expresar en HCL una VPC `/16`, 3 subnets públicas, 3 privadas, 1 IGW, 1 RT pública compartida, 3 RTs privadas (una por AZ), y un S3 Gateway endpoint.
- Pasar `terraform init -backend=false` + `terraform validate` + `terraform plan -out=plan.out` sin credenciales AWS reales.
- Dibujar el diagrama ASCII de tu propio módulo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` secciones 1–8.
- Haber recorrido los 3 `examples/` del módulo.
- **Terraform** instalado (`terraform -v` ≥ 1.5).
- `bash` y un editor.
- **No** se requiere cuenta AWS. **No** se aplicará nada.

**Costos:** cero.

## 5. Instrucciones

### 5.1 Preparar el workspace

```bash
mkdir -p /tmp/aws-03-vpc-module
cd /tmp/aws-03-vpc-module
```

Puedes usar otro directorio; páselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `main.tf`

Requisitos del módulo:

- `terraform { required_version = ">= 1.5.0" }` y `required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }`.
- Provider `aws` con credenciales **mock** y skips para que `plan` no intente llamar a AWS:
  ```
  provider "aws" {
    region                      = "us-east-1"
    access_key                  = "mock"
    secret_key                  = "mock"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
  ```
- `aws_vpc` con `cidr_block = "10.0.0.0/16"`, `enable_dns_support=true`, `enable_dns_hostnames=true`.
- `aws_internet_gateway` asociado a esa VPC.
- **3 subnets públicas**: `10.0.0.0/24`, `10.0.16.0/24`, `10.0.32.0/24` en AZs `us-east-1a`, `us-east-1b`, `us-east-1c`.
- **3 subnets privadas**: `10.0.1.0/24`, `10.0.17.0/24`, `10.0.33.0/24`.
- `aws_route_table` **pública** con ruta `0.0.0.0/0 -> igw`.
- 3 `aws_route_table_association` conectando las subnets públicas con la RT pública.
- 3 `aws_route_table` **privadas** (una por AZ). Rutas por defecto: **solo** la `local`. No añadas NAT en Terraform (la actividad es plan-only; dejar documentado por qué se omite).
- 3 `aws_route_table_association` conectando subnets privadas con sus RT privadas.
- Un `aws_vpc_endpoint` tipo **Gateway** para S3, asociado a las 3 RTs privadas.

### 5.3 Escribe `DESIGN.md`

En el mismo directorio, un `DESIGN.md` que incluya:

- **Sección "CIDR"**: cálculo de hosts utilizables por subnet (restando las 5 IPs reservadas de AWS).
- **Sección "Diagrama"**: diagrama ASCII de tu VPC (ver ejemplo 01 como plantilla, pero adáptalo).
- **Sección "Decisiones"**: al menos 3 decisiones de diseño documentadas (ej.: "una RT privada por AZ", "sin NAT porque es plan-only", "endpoint S3 asociado a las 3 RTs privadas").

### 5.4 Ejecuta la validación offline

```bash
terraform init -backend=false
terraform validate
terraform plan -out=plan.out
```

`plan.out` debe generarse sin errores. **Nunca** ejecutes `terraform apply`.

### 5.5 Ejecuta el validador estructural

```bash
bash <ruta-repo>/courses/aws/03-vpc-basics/activities/01-provision-vpc-via-tf-module/tests/validate.sh /tmp/aws-03-vpc-module
```

## 6. Resultado esperado

- `/tmp/aws-03-vpc-module/main.tf` existe con los recursos listados.
- `/tmp/aws-03-vpc-module/DESIGN.md` existe con las 3 secciones.
- `/tmp/aws-03-vpc-module/plan.out` existe (generado por `terraform plan`).
- El validador sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa; `terraform validate` pasa.
- **Calidad**: nombres de recursos y tags consistentes; `enable_dns_hostnames=true`.
- **Reproducibilidad**: cualquier persona con Terraform instalado reproduce el `plan`.
- **Costos**: cero; nunca se ejecuta `apply`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-03-vpc-module
```

Comprueba estructura (presencia de archivos, strings clave en el HCL, secciones en `DESIGN.md`). La corrección semántica del plan y del diseño la revisas tú contra `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué una RT privada por AZ y no una sola compartida? ¿Qué pierdes al compartir?
2. ¿Qué pasaría si olvidaras asociar el S3 Gateway endpoint a una de las 3 RTs privadas?
3. ¿Por qué `enable_dns_hostnames=true` es necesario incluso si todavía no vas a usar Interface endpoints?
4. ¿Qué cambia en el `plan.out` entre añadir el NAT Gateway y no añadirlo (sin aplicar)? ¿Qué recursos "extras" aparecen?
5. ¿Dónde pondrías la NAT Gateway en un diseño "cheap-but-not-HA"? ¿Y en uno "cost-is-no-object"?

## 10. Extensiones

- Añade un segundo S3 Gateway endpoint para DynamoDB (misma mecánica).
- Añade variables de entrada (`variable "cidr"`, `variable "azs"`) para parametrizar el módulo.
- Añade `outputs.tf` exportando IDs de VPC, subnets públicas, subnets privadas.
- Añade un Security Group `sg-app` que acepte inbound 8080/tcp solo desde un `sg-alb` (crea ambos).

## 11. Limpieza

```bash
rm -rf /tmp/aws-03-vpc-module
```

No hay recursos AWS que destruir (no se aplicó).
