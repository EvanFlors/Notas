# Actividad 02 — PrivateLink productor+consumidor + análisis NAT vs Interface Endpoint (independiente)

## 1. Identificación

- **ID:** `aws-07-02-expose-internal-service-via-privatelink`
- **Tecnología:** `aws`
- **Módulo:** `aws-07-networking-advanced`
- **Dificultad:** intermediate
- **Duración estimada:** 75–120 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Dos entregables en una:

1. **Terraform PrivateLink**: escribes los dos lados — **productor** (NLB + VPC Endpoint Service con `allowed_principals`) y **consumidor** (Interface Endpoint apuntando al Endpoint Service). Nada se aplica.
2. **Análisis coste**: produces `cost-tradeoff.csv` y `cost-tradeoff.md` comparando **NAT Gateway solo** vs **Gateway Endpoint S3 + Interface Endpoints** para un workload que consume 1, 5 y 10 servicios AWS desde subnets privadas. Decides el ganador por tramo con **cifras explícitas** (no "más barato en algunos casos").

## 3. Objetivos

- Escribir Terraform HCL válido para ambos lados de PrivateLink y pasar `terraform validate` en los dos módulos.
- Entender `acceptance_required` y `private_dns_enabled` lo suficiente para defender tu elección en una ADR.
- Hacer un cálculo de coste reproducible: alguien que lea tu CSV + MD puede verificar las cifras aritméticamente.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` secciones 6 y 7.
- Haber recorrido `../../examples/02-nlb-with-privatelink/`.
- Herramientas: `bash`, `terraform` ≥ 1.5, editor Markdown. Opcionalmente `awk`/`python3` para verificar el CSV.

**Costos**: **$0.00**. Nada se aplica.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-07-privatelink/{producer,consumer}
cd /tmp/aws-07-privatelink
```

### 5.2 Módulo productor (`producer/`)

Debe incluir, como mínimo:

- `providers.tf` con el stub offline (igual que en actividad 01).
- `main.tf` con:
  - `aws_vpc`, `aws_subnet` privadas (2 AZs).
  - `aws_lb` tipo `network`, `internal = true`.
  - `aws_lb_target_group` TCP:8080.
  - `aws_lb_listener` TCP:8080.
  - `aws_vpc_endpoint_service` con `network_load_balancer_arns = [aws_lb.svc.arn]` y `acceptance_required = false`.
  - `aws_vpc_endpoint_service_allowed_principal` con un `principal_arn` **placeholder** (`arn:aws:iam::012345678901:root`).
- `outputs.tf` exportando `service_name`.

### 5.3 Módulo consumidor (`consumer/`)

Debe incluir, como mínimo:

- `providers.tf` con el stub offline.
- `main.tf` con:
  - `aws_vpc`, `aws_subnet` privadas (2 AZs).
  - `aws_security_group` para el Interface Endpoint.
  - `aws_vpc_endpoint` con `vpc_endpoint_type = "Interface"`, `service_name = var.producer_service_name`, `private_dns_enabled = false`.
- `variables.tf` con `producer_service_name`.

Ejecuta en cada carpeta:

```bash
terraform init -backend=false
terraform validate
```

### 5.4 `DECISIONS.md`

Dos ADRs:

```markdown
# DECISIONS — aws-07-02-expose-internal-service-via-privatelink

## ADR-001: acceptance_required = false (confianza por allowed_principals)
...

## ADR-002: private_dns_enabled = false en el consumidor
...
```

Cada ADR con **Contexto / Decisión / Alternativas descartadas / Consecuencias**.

### 5.5 `cost-tradeoff.csv`

Compara, para N = 1, 5 y 10 servicios AWS consumidos (Interface Endpoint-capables, p. ej. Secrets Manager, SSM, KMS, ECR, Kinesis…), el coste mensual en dos opciones:

- **Opción A — NAT solo** (2 NAT Gateways multi-AZ + GB procesados).
- **Opción B — NAT + Interface Endpoints** (2 ENIs por servicio × 2 AZs, con tráfico redirigido por los endpoints).

Asume: 2 AZs, 500 GB/mes de egress total, de los cuales el **80 %** va a esos N servicios AWS y el 20 % a internet general. Precios orientativos US-east-1 (**verificar al leer**):

- NAT Gateway: $0.045/h + $0.045/GB procesado.
- Interface Endpoint: $0.010/h/ENI + $0.010/GB procesado.
- Horas/mes: 730.

Formato CSV **exacto** (encabezado + 3 filas + 1 fila "winner"):

```csv
services,option,fixed_usd,data_usd,total_usd
1,nat_only,65.70,22.50,88.20
1,nat_plus_endpoints,61.18,20.10,81.28
5,nat_only,65.70,22.50,88.20
5,nat_plus_endpoints,138.70,8.10,146.80
10,nat_only,65.70,22.50,88.20
10,nat_plus_endpoints,211.70,8.10,219.80
```

> Los **números del ejemplo son ilustrativos**. Haz tu propio cálculo y documenta la fórmula en `cost-tradeoff.md`. Lo que valida el test es: encabezado exacto, 6 filas de datos (3 tramos × 2 opciones), y que `cost-tradeoff.md` nombre al ganador por tramo.

### 5.6 `cost-tradeoff.md`

Debe:

- Explicar la fórmula usada para `fixed_usd` y `data_usd`.
- Para cada tramo (1, 5, 10 servicios), indicar explícitamente **ganador: nat_only / nat_plus_endpoints**.
- Mencionar al menos **un factor no-coste** que mueva la decisión (p. ej. seguridad: evitar que tráfico a Secrets Manager pase por internet aunque sea más caro).

### 5.7 Entregable

```
/tmp/aws-07-privatelink/
├── producer/
│   ├── providers.tf
│   ├── main.tf
│   └── outputs.tf
├── consumer/
│   ├── providers.tf
│   ├── main.tf
│   └── variables.tf
├── DECISIONS.md
├── cost-tradeoff.csv
└── cost-tradeoff.md
```

## 6. Resultado esperado

- `terraform validate` en verde en `producer/` y `consumer/`.
- `DECISIONS.md` con dos ADRs.
- `cost-tradeoff.csv` con encabezado y 6 filas de datos.
- `cost-tradeoff.md` con fórmula, ganador por tramo y factor no-coste.
- `bash tests/validate.sh /tmp/aws-07-privatelink` en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: aritmética del CSV reproducible (fórmula escrita en el MD); ADRs citan criterios concretos.
- **Reproducibilidad**: `producer/` y `consumer/` corren `init -backend=false` + `validate` sin credenciales.
- **Mantenibilidad**: HCL legible; nombres descriptivos; ningún ID real.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-07-privatelink
```

## 9. Preguntas de reflexión

1. ¿Por qué `acceptance_required = true` suma fricción si ya tienes `allowed_principals`?
2. ¿Qué pasa si pones `private_dns_enabled = true` sin haber verificado el dominio en el productor?
3. En el tramo donde NAT gana, ¿qué debería cambiar en el workload para que Interface Endpoints valgan la pena?
4. ¿Qué pasa con el coste si pasas de 2 AZs a 3?
5. ¿Qué servicio AWS consumible usarías para reemplazar NAT por completo si solo consumieras ese servicio? (Pista: Gateway Endpoint.)

## 10. Extensiones

- Añade un **tercer módulo** (`shared/`) que use `terraform_remote_state` para compartir el `service_name` del productor con el consumidor.
- Añade una fila al CSV para N = 20 servicios: el crossover suele estar entre 3 y 5 servicios con el perfil de egress del enunciado.
- Añade al CSV una tercera opción `nat_plus_endpoints_singlenaz` (1 solo NAT en 1 AZ): más barato pero perdiendo HA.

## 11. Limpieza

```bash
rm -rf /tmp/aws-07-privatelink
```

Nada que destruir en AWS (no se aplicó).
