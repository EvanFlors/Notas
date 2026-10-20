# Actividad 01 — Levantar EC2 alcanzable por SSM (sin SSH, con IMDSv2)

## 1. Identificación

- **ID:** `aws-04-01-launch-ec2-reach-via-ssm`
- **Tecnología:** `aws`
- **Módulo:** `aws-04-ec2-fundamentals`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab (seguida — hay plantilla con TODOs)

## 2. Contexto

Vas a escribir el **Terraform** y el **user-data** de una EC2 que cumple las reglas del módulo:

1. **IMDSv2 obligatorio** (`metadata_options { http_tokens = "required" }`).
2. **Sin SSH** (SG sin `ingress`, sin `key_name`).
3. **Alcanzable solo por SSM** (instance profile con `AmazonSSMManagedInstanceCore`).
4. **AMI resuelta dinámicamente** desde SSM Parameter Store.
5. **User-data idempotente** con logging y health check.

**No vas a aplicar en AWS real.** La validación es local y estructural: comprueba que tu HCL tiene los recursos y atributos correctos, y que tu `user-data.sh` es bash sintácticamente válido. Si tienes `terraform` instalado, el validador también corre `terraform fmt -check` y `terraform validate` (sin provider real).

## 3. Objetivos

- Escribir HCL que define los **recursos mínimos**: `aws_iam_role`, `aws_iam_role_policy_attachment`, `aws_iam_instance_profile`, `aws_security_group`, `aws_instance`, y la data source `aws_ssm_parameter`.
- Escribir **`user-data.sh`** con `set -euo pipefail`, logging unificado y health check.
- Documentar en **`EBS-choices.md`** por qué eliges gp3 (o lo que elijas) para el root.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los 3 `examples/` del módulo.
- Herramientas obligatorias: `bash`, `grep`. Opcionales (mejoran el validador): `terraform` ≥ 1.5, `shellcheck`.

**Costos**: cero. No se aplica en AWS.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-04-01
cd /tmp/aws-04-01
```

Copia los archivos del `starter/` como punto de partida:

```bash
cp -r <repo>/courses/aws/04-ec2-fundamentals/activities/01-launch-ec2-reach-via-ssm/starter/* .
ls
# EBS-choices.md  main.tf  outputs.tf  user-data.sh  variables.tf
```

### 5.2 Completar `main.tf`

El starter tiene los recursos esqueleto con **TODOs**. Debes:

1. **`data "aws_ssm_parameter" "al2023"`** — rellenar `name` con la ruta pública:
   `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64`.
2. **`aws_iam_role.ec2_ssm`** — trust policy con `sts:AssumeRole` para `Service: ec2.amazonaws.com`.
3. **`aws_iam_role_policy_attachment.ssm_core`** — adjuntar `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`.
4. **`aws_iam_instance_profile.ec2_ssm`** — envoltura del rol.
5. **`aws_security_group.ec2_private`** — SG **sin** bloque `ingress`, con egress 443 TCP a `0.0.0.0/0`.
6. **`aws_instance.app`**:
   - `ami = data.aws_ssm_parameter.al2023.value`
   - `instance_type = "t4g.small"`
   - `subnet_id`, `vpc_security_group_ids`, `iam_instance_profile`
   - `associate_public_ip_address = false`
   - **`metadata_options`** con `http_endpoint = "enabled"`, `http_tokens = "required"`, `http_put_response_hop_limit = 1`
   - `user_data = file("${path.module}/user-data.sh")`
   - Tags obligatorios: `Name`, `Environment`, `Owner`

### 5.3 Completar `user-data.sh`

El starter tiene el esqueleto. Debes añadir:

- `#!/usr/bin/env bash` como primera línea.
- `set -euo pipefail` (en user-data **sí** queremos pipefail: fallo duro durante el bootstrap).
- Redirección unificada: `exec > >(tee -a /var/log/user-data.log) 2>&1`.
- Un `trap ... ERR` con mensaje legible.
- Un paso de health check al final (`curl -fsS http://127.0.0.1/healthz` con reintentos).

### 5.4 Rellenar `EBS-choices.md`

Debe contener:

- Una **tabla** con los 4 tipos EBS (gp3, io2, st1, sc1), uso típico, caso de uso en 1 línea.
- Una **decisión** justificada: para esta EC2, qué tipo eliges y por qué (típicamente gp3, pero defiende tu respuesta).
- Un párrafo sobre **snapshots** y por qué son incrementales.

### 5.5 Validar

```bash
bash <repo>/courses/aws/04-ec2-fundamentals/activities/01-launch-ec2-reach-via-ssm/tests/validate.sh /tmp/aws-04-01
```

Si no pasas `terraform`, el validador salta esos chequeos con `SKIP` (no `FAIL`).

## 6. Resultado esperado

```
/tmp/aws-04-01/
├── EBS-choices.md
├── main.tf
├── outputs.tf
├── user-data.sh
└── variables.tf
```

Con `bash tests/validate.sh /tmp/aws-04-01` en verde (`RESULT: PASS`).

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Seguridad**: ningún bloque `ingress` en el SG. `http_tokens = "required"` presente. `associate_public_ip_address = false`.
- **Reproducibilidad**: AMI resuelta por SSM, no hardcodeada.
- **Calidad**: user-data pasa `bash -n`; pasa `shellcheck` si está instalado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-04-01
```

Comprueba:

- Existencia de los 5 archivos.
- Presencia de los recursos obligatorios en `main.tf`.
- Ausencia de `ingress` SSH (puerto 22) y de `key_name`.
- Presencia de `http_tokens = "required"`.
- Que `user-data.sh` empieza por shebang y declara `set -euo pipefail`.
- Que `bash -n user-data.sh` no da error.
- Opcionalmente `terraform fmt -check` y `terraform validate` (sin provider real).
- Opcionalmente `shellcheck user-data.sh`.

## 9. Preguntas de reflexión

1. Si tu organización usara contenedores Docker con red `bridge` dentro de la EC2, ¿por qué `http_put_response_hop_limit = 1` es importante?
2. ¿Qué pasaría si olvidas `AmazonSSMManagedInstanceCore` en el rol? ¿Puedes entrar por SSM?
3. Si la EC2 está en subnet **privada** sin NAT, ¿qué piezas de VPC adicionales necesitas para que SSM funcione?
4. ¿Por qué `template file` del `user-data` termina en IMDS y por qué eso te prohíbe hardcodear secretos ahí?
5. ¿Cuál es el riesgo de poner `associate_public_ip_address = true` incluso con el SG sin ingress?

## 10. Extensiones

- Añade una regla egress más estricta: en vez de `0.0.0.0/0:443`, limita a las ranges IP del servicio SSM (via `aws_prefix_list`).
- Añade `aws_cloudwatch_log_group` + política para que SSM grabe las sesiones a CloudWatch Logs.
- Convierte el `aws_instance` en un `aws_launch_template` reutilizable.

## 11. Limpieza

```bash
rm -rf /tmp/aws-04-01
```

No hay nada en AWS que destruir (no se aplicó).
