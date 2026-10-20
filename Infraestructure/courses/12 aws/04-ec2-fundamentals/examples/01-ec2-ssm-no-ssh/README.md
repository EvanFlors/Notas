# Ejemplo 01 — EC2 accesible solo por SSM (sin SSH abierto)

> Lectura y análisis. No se ejecuta en AWS real. Objetivo: ver cómo luce un `main.tf` que levanta una EC2 **privada**, **sin puerto 22 abierto**, administrable solo vía **SSM Session Manager**.

## 1. Topología objetivo

```
         Internet
            │
            │   (nada entra directamente a la EC2)
            │
            ▼
     ┌──────────────┐
     │     VPC      │
     │              │
     │  ┌────────┐  │       endpoints VPC (interface):
     │  │ EC2    │◄─┼────── com.amazonaws.<region>.ssm
     │  │ (priv) │◄─┼────── com.amazonaws.<region>.ssmmessages
     │  │        │◄─┼────── com.amazonaws.<region>.ec2messages
     │  └────────┘  │       (o alternativa: NAT Gateway → endpoints publicos)
     │              │
     └──────────────┘
            ▲
            │  AWS CLI: aws ssm start-session --target i-xxxx
            │
         Developer
```

Puntos clave:

- EC2 **sin IP pública**, en subnet **privada**.
- Security Group con **cero** reglas de ingreso. Egress abierto (o restringido a HTTPS 443).
- Entrada administrativa 100 % vía SSM: la EC2 abre túnel saliente al servicio, no al revés.

## 2. HCL — fragmento comentado

```hcl
# AMI resuelta dinámicamente desde SSM Parameter Store (no hardcodeada).
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# Rol que la EC2 asumira (trust policy: solo el servicio EC2 puede asumirlo).
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
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# Lo minimo-minimo para que SSM funcione.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# SG sin ingress. Egress solo HTTPS a cualquier destino (para hablar con SSM).
resource "aws_security_group" "ec2_private" {
  name        = "ec2-private-no-ssh"
  description = "No ingress. Egress 443 only."
  vpc_id      = var.vpc_id

  egress {
    description      = "HTTPS outbound for SSM endpoints"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # (OJO: ningun bloque `ingress`. Eso es intencional.)
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t4g.small"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_private.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  # IMDSv2 obligatorio (siguiente ejemplo entra en detalle).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "ssm-demo"
    Environment = "lab"
    Owner       = "aws-04"
  }
}
```

## 3. Qué observar

1. **No hay `key_name`** en `aws_instance`. No se crea keypair porque no se usa SSH.
2. **No hay regla `ingress`** en el SG. El egress HTTPS es suficiente para que el SSM Agent hable con los endpoints.
3. **`associate_public_ip_address = false`** — la instancia no es alcanzable desde internet, ni siquiera por error.
4. El **instance profile** adjuntado trae **solo** `AmazonSSMManagedInstanceCore`. Eso basta para que SSM funcione; cualquier permiso adicional (leer S3, etc.) se adjunta aparte y a conciencia.

## 4. Cómo se entraría (en un entorno real, no aquí)

```bash
# Lista de EC2 "manageable" por SSM:
aws ssm describe-instance-information --query 'InstanceInformationList[].InstanceId'

# Abrir shell interactiva:
aws ssm start-session --target i-0123456789abcdef0

# Dentro: comportamiento normal, pero el usuario por default es `ssm-user`.
```

## 5. Antipatron que este ejemplo evita

```hcl
# ANTIPATRON — NO HACER
resource "aws_security_group_rule" "ssh_from_my_ip" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["1.2.3.4/32"]  # mi IP de casa
  security_group_id = aws_security_group.ec2_private.id
}
```

Problema:

- "Mi IP de casa" cambia (ISP dinámico).
- Si trabajas con varias personas, la lista crece sin control.
- Si la instancia es compartida, la `.pem` acaba filtrada.
- No queda grabación de la sesión; audit forense es manual.

SSM resuelve las cuatro cosas de un golpe.
