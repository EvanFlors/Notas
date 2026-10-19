# Actividad 01 — Publicar app con ALB + ACM + Route 53 (guiada)

## 1. Identificación

- **ID:** `aws-07-01-publish-app-with-alb-tls-dns`
- **Tecnología:** `aws`
- **Módulo:** `aws-07-networking-advanced`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (sin dependencia con la actividad 02)

## 2. Contexto

Vas a publicar una API HTTP interna en HTTPS con un nombre bonito (`api.example.internal`), delante de un ALB con cert gestionado por ACM y DNS en Route 53. **No vas a aplicar nada contra AWS real**: un NAT, un ALB y un ACM `apply` olvidados te sacan dólares. Trabajarás con **Terraform `init -backend=false` + `validate` + `plan` offline** y entregarás `DECISIONS.md` con 3 ADRs que justifican las decisiones de diseño.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir Terraform HCL válido para VPC + ALB + target group + listeners (80→redirect, 443→forward) + ACM + Route 53 alias.
- Pasar `terraform validate` con exit 0.
- Generar `terraform plan` sin credenciales reales.
- Defender tus 3 decisiones de diseño con ADRs cortos y concretos.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` secciones 2, 3, 4 y 9.
- Haber recorrido `../../examples/01-alb-with-acm-and-route53/`.
- Haber completado `aws-03-vpc-basics`.
- Herramientas: `bash`, `terraform` ≥ 1.5 (ningún provider real necesario), un editor Markdown.

**Costos**: **$0.00**. Nada se aplica contra AWS.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-07-alb
cd /tmp/aws-07-alb
```

Puedes usar otro directorio pasándoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Crea los archivos Terraform

Mínimo:

- `main.tf`
- `variables.tf`
- `providers.tf`

El `providers.tf` debe permitir `terraform plan` **sin credenciales reales**:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}
```

En `main.tf` tu solución debe incluir, como mínimo:

- `aws_vpc`, `aws_subnet` públicas (al menos 2 AZs), `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association`.
- `aws_security_group` para el ALB (443, 80 desde `0.0.0.0/0`).
- `aws_lb` tipo `application`, `internal = false`, en las subnets públicas.
- `aws_lb_target_group` con `health_check` en `/healthz`.
- `aws_lb_listener` en **443 HTTPS** con `certificate_arn` referenciando el ACM, y `aws_lb_listener` en **80 HTTP** con `redirect` a 443.
- `aws_acm_certificate` con `validation_method = "DNS"`.
- `aws_route53_zone` o `data "aws_route53_zone"`, `aws_route53_record` para la validación ACM (CNAME) y para el `alias` A record final.
- `aws_acm_certificate_validation` que vincula ambos.

**Pistas**:

- Usa `example.internal` como dominio placeholder — nunca metas un dominio real que no controles.
- Nunca escribas Account IDs reales. Si necesitas uno, usa `012345678901`.
- Nunca commits de un `.tfstate` real; en este lab no habrá apply.

### 5.3 Ejecuta validate y plan

```bash
cd /tmp/aws-07-alb
terraform init -backend=false
terraform validate      # debe salir Success
terraform plan -out=tfplan   # offline: lista los recursos a crear
```

El `plan` emitirá *warnings* por los `data` sources que no pueden consultarse sin credenciales. Está esperado. Guarda la salida en `plan.txt` si quieres:

```bash
terraform plan -no-color > plan.txt 2>&1 || true
```

> Si el `plan` falla por un `data "aws_route53_zone"` que no puede consultarse, sustitúyelo por un `aws_route53_zone` recurso creado por el propio Terraform (una zona *mock* para el lab).

### 5.4 Escribe `DECISIONS.md`

Debe contener **tres ADRs** siguiendo la estructura mínima:

```markdown
# DECISIONS — aws-07-01-publish-app-with-alb-tls-dns

## ADR-001: ALB vs NLB para esta API

- **Contexto:** ...
- **Decisión:** ...
- **Alternativas descartadas:** ...
- **Consecuencias:** ...

## ADR-002: Validación de ACM por DNS vs email

...

## ADR-003: Alias record vs CNAME para apuntar al ALB

...
```

Cada ADR debe nombrar al menos un **criterio técnico concreto** (no "porque es mejor"): p.ej. ADR-001 debería mencionar L7 routing, OIDC, WAF, o IP fija.

### 5.5 Entregable

```
/tmp/aws-07-alb/
├── main.tf
├── variables.tf
├── providers.tf
├── DECISIONS.md
└── (opcional) plan.txt
```

## 6. Resultado esperado

- `terraform validate` sale en verde.
- `terraform plan` corre offline y emite el plan (los `data` que no se puedan resolver pueden dar error — está documentado como fallback: sustituirlos por recursos creados).
- `DECISIONS.md` tiene las 3 ADRs completas.
- `bash tests/validate.sh /tmp/aws-07-alb` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada ADR cita un criterio técnico concreto; el Terraform usa nombres descriptivos y no hardcodea IDs reales.
- **Reproducibilidad**: cualquier compañero que clone tu `/tmp/aws-07-alb` y corra los comandos obtiene el mismo `plan`.
- **Mantenibilidad**: HCL legible; variables en `variables.tf`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-07-alb
```

El validador comprueba **estructura**: existencia de archivos, strings esperados (`aws_lb`, `aws_acm_certificate`, `aws_route53_record`, `alias`, listener `443`, redirect `301`), y las tres ADRs en `DECISIONS.md`. **No** ejecuta `terraform apply`. Compara tu solución con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué el listener 80 hace redirect 301 en vez de simplemente no existir?
2. ¿Qué pasaría si pones el cert ACM en `eu-west-1` y el ALB en `us-east-1`?
3. ¿En qué escenario sustituirías el `alias` por un `CNAME` manual?
4. ¿Cómo cambiarías el diseño si necesitaras **IP fija** para que un cliente te whiteliste?
5. ¿Qué pierdes si usas `email` como `validation_method` en lugar de `DNS`?

## 10. Extensiones

- Añade un **listener rule** adicional para `/admin*` que requiera `authenticate_oidc`.
- Añade `access_logs` del ALB a un bucket S3 (recuerda que requiere la bucket policy correcta para que el ALB pueda escribir).
- Añade un segundo cert con `aws_acm_certificate` para `*.example.internal` y asócialo al listener 443 vía `aws_lb_listener_certificate`.

## 11. Limpieza

```bash
rm -rf /tmp/aws-07-alb
```

No hay infraestructura AWS que destruir (no se aplicó nada). Nada que destruir en consola.
