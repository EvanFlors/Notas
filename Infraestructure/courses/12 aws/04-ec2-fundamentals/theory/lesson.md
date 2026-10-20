# aws-04 — Lección: EC2 Fundamentals

> 10 secciones. Compute básico de AWS con foco en seguridad por default.
> Prerrequisito: `aws-02-iam-fundamentals`, `aws-03-vpc-basics`.

---

## 1. Qué es una EC2 y por qué sigue siendo relevante

Una **EC2 instance** es una **máquina virtual** corriendo en un **hypervisor** de AWS (Nitro hoy, Xen antes de 2017 en familias antiguas). Para el usuario parece un servidor Linux o Windows corriente: tiene disco, red, procesos, kernel. Para AWS es una ranura de CPU/memoria vendida por hora (o por segundo en Linux).

¿Por qué estudiarla si el programa se moverá luego a contenedores (ECS/EKS) y serverless (Lambda)?

- **Es el denominador común.** Casi todo compute de AWS termina siendo EC2: Fargate corre en EC2 ajenas, EKS node groups son EC2, RDS son EC2 administradas. Entender EC2 es entender qué está debajo.
- **Las decisiones de IAM, networking y bootstrap que se toman aquí se repiten en todas partes.** Instance profile → task role. User-data → `cloud-init` del nodo EKS. IMDSv2 → el mismo IMDSv2 en Fargate.
- **Para workloads que no caben en abstracciones superiores** (GPUs específicas, binarios opacos, licencias ligadas a hostnames), EC2 sigue siendo la respuesta correcta.

El objetivo del módulo **no** es que montes servidores a mano para siempre. Es que entiendas la primitiva.

---

## 2. Familias y tipos de instancia

El nombre `m7g.large` codifica cuatro cosas:

```
   m       7       g       .large
   │       │       │          │
   │       │       │          └── tamaño (nano, micro, small, medium,
   │       │       │              large, xlarge, 2xlarge, ..., 48xlarge)
   │       │       └── variante / modificador:
   │       │              g = Graviton (ARM)
   │       │              i = Intel
   │       │              a = AMD
   │       │              n = network-optimized
   │       │              d = NVMe local storage
   │       └── generación (7 = más reciente al momento del curso).
   │              Generaciones nuevas son casi siempre más baratas por core.
   └── familia:
          m = general purpose (balance CPU/mem)
          c = compute optimized (CPU alta, mem baja)
          r = memory optimized (RAM alta)
          x = extreme memory (SAP HANA, in-memory DBs)
          i = storage optimized con NVMe local
          d = dense HDD storage
          g = GPU (ML, rendering)
          p = GPU más potente
          t = burstable (CPU baratas por créditos; dev/test)
```

### Regla simple de elección

| Workload                                   | Familia típica |
|--------------------------------------------|----------------|
| Web app genérica, API                      | `m7g`, `m7i`   |
| CPU-bound (build, compilación, batch)      | `c7g`, `c7i`   |
| Base de datos relacional / in-memory       | `r7g`, `r7i`   |
| ElasticSearch, Kafka, con disco local      | `i4i`, `im4gn` |
| ML training                                | `p5`, `g5`     |
| Dev / test ocasional                       | `t3`, `t4g`    |

**Graviton (`g` → ARM64)** suele ser **~20 % más barato** y energéticamente eficiente. Si tu stack compila para ARM (Python puro, Go, Rust, Java 11+, Node), **elígelo por default**. El único freno real son binarios cerrados que solo tienen build x86.

### Trampa clásica: `t`-family y los créditos

Las `t2`/`t3`/`t4g` son **burstable**: tu CPU base está limitada (p. ej. 20 %) y acumula **créditos** cuando no la usas. Al picar los gastas; cuando se agotan la instancia se **estrangula** a ese 20 %. Para dev está bien. Para producción con cargas sostenidas suele morderte sin aviso. Alternativa: `t3.unlimited` (deja gastar créditos "negativos" y te cobra el extra; a veces sale más barato que un `m5` fijo, a veces no).

---

## 3. AMIs: la imagen de arranque

Una **AMI** (Amazon Machine Image) es la **plantilla** desde la que una instancia arranca: snapshot EBS de root + metadata (kernel, arch, permisos). Tipos:

1. **Oficiales de AWS** (`amazon/al2023-ami-*`, `amazon/amzn2-ami-*`, Canonical para Ubuntu, Red Hat, etc.). Actualizadas, soportadas, auditadas.
2. **Propias**, construidas con **Packer** o **EC2 Image Builder**: parten de una oficial, aplican tu config (hardening CIS, agentes, binarios internos), publican una AMI nueva. Clave para immutable infrastructure.
3. **AWS Marketplace**: AMIs de terceros con software preinstalado (Palo Alto firewalls, Trend Micro, bases de datos propietarias). Normalmente cobran extra por hora encima del precio EC2.

### No hardcodees el AMI ID

Un AMI ID (`ami-0abcdef1234567890`) es **específico de región y versión**. AWS publica el ID "latest estable" en el **SSM Parameter Store** bajo rutas como:

```
/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64
/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id
```

En Terraform:

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_instance" "app" {
  ami = data.aws_ssm_parameter.al2023.value
  # ...
}
```

Así tu Terraform no caduca cuando AWS publica una AMI nueva. (El trade-off: cada `terraform plan` puede detectar un cambio de AMI si acaba de salir una versión nueva, y rotar la instancia. Si no quieres eso, "congela" el ID resuelto en una variable y rota a conciencia.)

---

## 4. Keypairs, SSH y por qué preferir SSM Session Manager

El patrón clásico de los años 2010 era: generar un **keypair** AWS, descargar el `.pem`, abrir el puerto **22** desde tu IP en el Security Group, y entrar con `ssh -i key.pem ec2-user@...`.

Hoy ese patrón está **desaconsejado** por tres razones:

1. **Nunca deberías tener el puerto 22 abierto a Internet**, ni siquiera "solo a tu IP" (cambia, se olvida, se queda abierto). La superficie de ataque crece sin beneficio.
2. **Las `.pem` se filtran** por mil mecanismos (repos, Slack, backups, portátiles perdidos). Rotarlas es doloroso y pocas veces se hace.
3. **No hay audit trail estructurado**: `ssh` da un log de login pero no graba la sesión; para forense necesitas tooling adicional.

**SSM Session Manager** resuelve las tres de un plumazo:

- No requiere **ningún puerto abierto entrante**. La EC2 abre una conexión saliente al servicio SSM (HTTPS 443 → endpoint SSM). AWS actúa de "pivote" entre tu CLI y la EC2.
- No requiere `.pem` ni usuario local; la autorización es **IAM**: `ssm:StartSession` sobre el ARN de la instancia.
- Graba la sesión opcionalmente a S3/CloudWatch Logs. Audit real.

Para que funcione la EC2 solo necesita:

- Un **instance profile** con la managed policy `AmazonSSMManagedInstanceCore`.
- El **SSM Agent** instalado (ya viene en AL2023, Amazon Linux 2, Ubuntu reciente).
- Conectividad al endpoint SSM (**NAT** o **Interface VPC Endpoints** `ssm`, `ssmmessages`, `ec2messages`).

Entras con:

```bash
aws ssm start-session --target i-0123456789abcdef0
```

Regla general del programa: **no abras 22 nunca** si no hay una justificación específica. Y si hay, cuestionarla.

---

## 5. User-data y cloud-init: bootstrap de arranque

**User-data** es un blob (bash script, cloud-config YAML, mime multiparte) que se entrega a la instancia al **primer arranque**. Lo ejecuta `cloud-init` como root.

### Regla de oro: idempotencia

El user-data corre **una vez** por default (`cloud-init` marca una semilla), pero debes escribirlo como si pudiera correr muchas veces. Razones:

- Imágenes AMI "doradas" pueden tener residuos de ejecuciones anteriores.
- Si debuggeando lanzas `cloud-init clean && cloud-init init`, debe no romper nada.
- Si lo transformas en un `UserData` reutilizable por un launch template de un ASG, cada nodo nuevo lo correrá.

### Patrón mínimo (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/user-data.log
exec > >(tee -a "$LOG") 2>&1
echo "[user-data] started at $(date -Is)"

# 1. Paquetes (idempotente — dnf no reinstala si ya existe)
dnf -y install nginx jq

# 2. Config (overwrite seguro)
cat > /etc/nginx/conf.d/hello.conf <<'CONF'
server {
  listen 80 default_server;
  location / { return 200 "ok\n"; }
}
CONF

# 3. Service (enable + start es idempotente)
systemctl enable --now nginx

echo "[user-data] finished at $(date -Is)"
```

Qué hace bien:

- **Logging explícito** a `/var/log/user-data.log` (más fácil que buscar en `cloud-init.log`).
- **`set -euo pipefail`** para fallar temprano. (Nota: en los **validadores** del programa evitamos `pipefail` por el tema SIGPIPE, pero en **user-data** sí lo queremos: queremos que el bootstrap falle duro, no silente.)
- **Comandos naturalmente idempotentes** (`dnf install`, `systemctl enable --now`, overwrite de archivos).

### Qué NO hacer

- Hardcodear secretos. Para eso: Secrets Manager / SSM Parameter Store SecureString (módulo `aws-09`).
- Hacer `curl ... | bash` sin pin a un commit/hash. Es un supply-chain riesgo.
- Dejar el user-data creciendo hasta 16 KB (límite). Si crece: mueve el grueso a un script en S3 y hazlo `aws s3 cp && bash script.sh` (con rol para leer).

---

## 6. EBS: discos para EC2

**EBS (Elastic Block Store)** es el disco por red de EC2. Vive separado de la instancia (sobrevive al stop/start). Tipos:

| Tipo | Clase | Caso de uso típico | Clave |
|------|-------|---------------------|-------|
| **gp3** | SSD general | **Default moderno.** Volúmenes de root, apps, BBDD pequeñas. | Baseline 3000 IOPS / 125 MB/s **independiente del tamaño**; pagas aparte si subes. |
| **gp2** | SSD general (legacy) | — | Deprecated en nuevos diseños. Rendimiento ligado al tamaño. |
| **io2** / **io2 Block Express** | SSD provisioned IOPS | BBDD críticas, latencia estricta, >16k IOPS. | Durabilidad 99.999 %. Caro. |
| **st1** | HDD throughput-optimized | Data warehousing, logs grandes secuenciales. | Barato, latencia mala para random. |
| **sc1** | HDD cold | Backups, data histórica raramente leída. | El más barato por GB. |

### Reglas prácticas

- **Default: gp3**. gp2 solo si migras algo antiguo.
- **Encryption at-rest**: enciende el **default encryption de la región** (una vez por región, por cuenta). Todo volumen nuevo nace cifrado con la CMK que elijas.
- **Snapshots** son incrementales: solo se almacenan los bloques cambiados desde el snapshot anterior. Son el mecanismo de backup/clonado base.
- **Si tu workload necesita disco local súper rápido** (shuffle de Spark, caches), mira familias con `d` (NVMe local), pero recuerda: ese disco **no sobrevive** stop/start — se pierde.

---

## 7. IMDS: el servicio que da identidad a la EC2

Este es **el punto más importante del módulo** desde seguridad.

Cada EC2 tiene un **Instance Metadata Service** reachable **solo desde dentro** de la instancia en la IP mágica `169.254.169.254`. Expone cosas como:

- `/latest/meta-data/instance-id`
- `/latest/meta-data/public-ipv4`
- `/latest/meta-data/iam/security-credentials/<role-name>` → **credenciales temporales** del instance profile (STS AccessKey + Secret + SessionToken + Expiration)

Esas credenciales las usa automáticamente la **AWS SDK / CLI** cuando corres código dentro de la EC2 sin configurar `~/.aws/credentials`. Esa es la magia que permite:

```bash
# dentro de la EC2, sin credenciales:
aws s3 ls s3://mi-bucket
# funciona porque la SDK va a IMDS → saca credenciales → firma con ellas.
```

### IMDSv1 vs IMDSv2

**IMDSv1** (legacy): basta un **GET HTTP** sin headers especiales:

```
GET http://169.254.169.254/latest/meta-data/iam/security-credentials/mi-rol
```

Problema catastrófico: cualquier **SSRF** (Server-Side Request Forgery) en tu aplicación — pedir una URL arbitraria desde el backend — permite al atacante **leer tus credenciales**. Pide `http://169.254.169.254/...` desde la vulnerabilidad y se las lleva. Caso famoso: Capital One 2019, 100M+ registros.

**IMDSv2** fuerza una **sesión** con token:

```
# 1. Pedir token (PUT, con header de TTL)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
          -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# 2. Usar el token en cada request
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
     http://169.254.169.254/latest/meta-data/iam/security-credentials/mi-rol
```

Esto rompe el ataque SSRF porque:

- La mayoría de SSRF solo permiten **GET** simples, no PUT con headers custom.
- El token tiene **TTL** y **hop limit** (`X-aws-ec2-metadata-token-ttl-seconds` default 2 h; `metadata-options.http_put_response_hop_limit` default 1, lo que evita que un contenedor Docker con `--network bridge` haga el PUT a través del host).

### Cómo forzar IMDSv2 por Terraform

```hcl
resource "aws_instance" "app" {
  # ...
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 obligatorio
    http_put_response_hop_limit = 1            # default pero sé explícito
    instance_metadata_tags      = "enabled"
  }
}
```

**Regla del programa:** toda EC2 nueva nace con `http_tokens = "required"`. No negociable.

---

## 8. Instance profile: cómo una EC2 asume un rol

Un **instance profile** es un **contenedor** de **un** rol IAM que se adjunta a una EC2. Al arrancar, la EC2 "asume" ese rol periódicamente y las credenciales viven en IMDS.

### Pieza por pieza

```hcl
# 1. Trust policy: quién puede asumir el rol (en este caso el servicio EC2)
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. El rol
resource "aws_iam_role" "app" {
  name               = "app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# 3. Permisos (mínimos — ejemplo: SSM + leer un bucket)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. El instance profile (envoltura del rol)
resource "aws_iam_instance_profile" "app" {
  name = "app-profile"
  role = aws_iam_role.app.name
}

# 5. Adjunto a la instancia
resource "aws_instance" "app" {
  # ...
  iam_instance_profile = aws_iam_instance_profile.app.name
}
```

### Verificación desde dentro

Entra con SSM y pregunta a STS "¿quién soy?":

```bash
aws sts get-caller-identity
# {
#   "UserId": "AROAEXAMPLEEXAMPLE:i-0123...",
#   "Account": "111111111111",
#   "Arn": "arn:aws:sts::111111111111:assumed-role/app-role/i-0123..."
# }
```

El `Arn` empieza por `assumed-role/<nombre-del-rol>/<instance-id>`. Esto confirma que la EC2 está hablando con AWS como ese rol — **sin ninguna credencial estática montada**.

### Error típico

- Rol con **demasiados permisos** ("por si acaso"). Rompe el principio de least privilege. El módulo `aws-02` ya nos entrenó: identifica las acciones concretas, pon `Resource` concreto, no "`*`".
- Cambiar el rol **requiere reinicio** del SSM Agent (o de la instancia) para que relea credenciales. No es inmediato.
- Rol **sin** `AmazonSSMManagedInstanceCore` → no puedes entrar por SSM. Primera cosa a comprobar si falla la sesión.

---

## 9. Launch templates y Auto Scaling Groups (vista previa)

Hasta ahora pensamos "una EC2". En producción casi siempre quieres **N EC2 que se autoreemplazan**. Ahí entran:

### Launch Template

Un **launch template** es la **plantilla reutilizable** que describe cómo lanzar instancias: AMI, tipo, subnet, security groups, user-data, metadata options, instance profile, EBS layout, tags. En Terraform:

```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t4g.small"
  user_data     = base64encode(file("${path.module}/user-data.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "web" }
  }
}
```

### Auto Scaling Group (ASG)

Consume el launch template, se despliega en varias subnets (varias AZs) y mantiene un `desired_capacity` con `min` / `max`:

```hcl
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  health_check_type         = "ELB"   # delega health check al load balancer
  health_check_grace_period = 60
  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}
```

Qué te da el ASG:

- **Reemplazo automático** de nodos no sanos.
- **Escalado horizontal** por política (CPU, SQS, custom metric).
- **Rolling updates** cuando cambias el launch template (si usas `instance_refresh`).

En este módulo solo vemos la **estructura**. ASG en profundidad llega con `aws-07` (balanceo) y `aws-10` (contenedores, donde ASG mueve nodos de ECS).

---

## 10. Checklist mental: EC2 segura por default

Antes de hacer `terraform apply` de cualquier EC2, el checklist obligado:

1. **¿IMDSv2 enforced?** `metadata_options { http_tokens = "required" }`.
2. **¿SSH cerrado?** El Security Group **no** debe abrir 22 a `0.0.0.0/0`. Idealmente no abrir 22 en absoluto.
3. **¿Instance profile?** Aunque sea solo con `AmazonSSMManagedInstanceCore`. Nunca credenciales en disco.
4. **¿AMI de fuente confiable?** SSM Parameter Store oficial o AMI propia versionada. No "la de ese tutorial".
5. **¿User-data idempotente y logueado?** `set -euo pipefail`, logs a `/var/log/user-data.log`.
6. **¿EBS cifrado?** Default encryption de la región encendida.
7. **¿Tags?** `Name`, `Environment`, `Owner`, `CostCenter`. Sin tags el billing es imposible.
8. **¿Subnet correcta?** Privada por default; pública solo si hay razón explícita.
9. **¿Reachable por SSM?** Si estás en subnet privada: necesitas endpoints `ssm`, `ssmmessages`, `ec2messages` (o NAT).
10. **¿Destroy fácil?** El Terraform limpia TODO (rol, instance profile, SG, EBS). Nada residual.

Si no puedes marcar las 10 casillas, no apliques. Vuelve y corrige. Ese es el músculo que entrena este módulo.
