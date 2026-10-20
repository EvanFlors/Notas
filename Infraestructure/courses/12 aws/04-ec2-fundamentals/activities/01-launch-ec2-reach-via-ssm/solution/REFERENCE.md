# REFERENCE — aws-04-01-launch-ec2-reach-via-ssm

> Una **referencia** razonada. No es la única respuesta correcta — pequeñas variaciones (región, nombre, size) son válidas mientras cumplas las reglas.

## `main.tf` (completo esperado)

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.name_prefix}-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_security_group" "ec2_private" {
  name        = "${var.name_prefix}-sg"
  description = "No ingress. Egress 443 only."
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound for SSM endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t4g.small"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_private.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  user_data = file("${path.module}/user-data.sh")

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.name_prefix}-app"
    Environment = "lab"
    Owner       = "aws-04"
  }
}
```

## `user-data.sh` (completo esperado)

```bash
#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1
trap 'echo "[user-data] FAILED at line $LINENO (exit $?)"' ERR

echo "[user-data] START $(date -Is)"

dnf -y install nginx jq awscli

TMP=$(mktemp)
cat > "$TMP" <<'CONF'
server {
  listen 80 default_server;
  server_name _;
  location /healthz { return 200 "ok\n"; }
  location /        { return 200 "aws-04 ssm demo\n"; }
}
CONF
install -o root -g root -m 0644 "$TMP" /etc/nginx/conf.d/hello.conf
rm -f "$TMP"

systemctl enable --now nginx

for i in 1 2 3 4 5; do
  if curl -fsS http://127.0.0.1/healthz >/dev/null; then
    echo "[user-data] healthz OK (try $i)"
    break
  fi
  echo "[user-data] healthz not ready (try $i), sleeping 2s..."
  sleep 2
  if [ "$i" = "5" ]; then
    echo "[user-data] ERROR: healthz never came up"
    exit 1
  fi
done

echo "[user-data] DONE $(date -Is)"
```

## `EBS-choices.md` (referencia)

### Comparativa

| Tipo | Clase | Caso típico | Comentario |
|------|-------|-------------|------------|
| gp3  | SSD   | Default moderno: root disk, apps, DB pequeñas. | 3000 IOPS / 125 MB/s baseline **independiente del tamaño**. Pagas aparte si subes. Normalmente la elección correcta. |
| io2  | SSD provisioned IOPS | DBs críticas, >16k IOPS, durabilidad 99.999 %. | Caro. Solo si el workload lo justifica. |
| st1  | HDD throughput | Logs grandes secuenciales, data warehouse. | Barato para GB masivos; mala latencia para random. |
| sc1  | HDD cold | Backups, data histórica raramente accedida. | El más barato por GB. |

### Decisión

Para esta EC2 (web app pequeña, root disk) elijo **gp3** porque:

- El root de la mayoría de workloads cabe cómodo en el baseline (3000 IOPS / 125 MB/s).
- Es más barato por GB que gp2 y rinde mejor.
- No necesito garantía de IOPS específicos → no justifica io2.
- Es SSD → latencia aceptable para OS + logs; HDD no sirve para root.

### Snapshots

Los snapshots EBS son **incrementales**: solo se almacenan los bloques que cambiaron desde el snapshot anterior. El primer snapshot copia todo; los siguientes solo las diferencias. Esto hace que el almacenamiento sea proporcional al delta, no al tamaño total multiplicado por el número de snapshots. En restauración, AWS reconstruye el volumen entero a partir del encadenado de snapshots (transparente al usuario).

## Reflexiones (respuestas modelo)

1. **`http_put_response_hop_limit = 1`**: cuando un contenedor Docker usa red `bridge`, el TTL del paquete viaja un hop extra. Si lo dejas en el default 2 (o superior), un proceso dentro del contenedor podría pedir el token IMDSv2 y leer credenciales del host. Ponerlo en 1 bloquea ese salto. En Fargate/ECS el equivalente se maneja a nivel de task definition.
2. Sin `AmazonSSMManagedInstanceCore` el SSM Agent no puede autenticarse contra el servicio → la instancia no aparece en `aws ssm describe-instance-information` → `start-session` falla con "not registered".
3. En subnet privada sin NAT: necesitas **VPC Interface Endpoints** para `com.amazonaws.<region>.ssm`, `com.amazonaws.<region>.ssmmessages`, `com.amazonaws.<region>.ec2messages`. Con NAT los endpoints son opcionales, pero cobras egress por GB.
4. El user-data queda legible vía IMDS en `http://169.254.169.254/latest/user-data`. Cualquier proceso dentro de la EC2 (y cualquier SSRF si no fuerzas v2) puede leerlo. Secretos ahí = secretos filtrados.
5. `associate_public_ip_address = true` con SG sin ingress: la EC2 sigue sin aceptar tráfico entrante por el SG, pero gana una IP pública **enumerable** por escáneres (shodan, censys). Aumenta huella de ataque, consume IPv4 pública (que AWS cobra desde 2024), y si alguien cambia el SG por error la deja expuesta de inmediato. Mejor: nunca pública si no es necesaria.
