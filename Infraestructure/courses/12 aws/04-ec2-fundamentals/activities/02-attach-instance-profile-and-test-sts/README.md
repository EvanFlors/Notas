# Actividad 02 — Instance profile mínimo, test STS y comparativa de familias

## 1. Identificación

- **ID:** `aws-04-02-attach-instance-profile-and-test-sts`
- **Tecnología:** `aws`
- **Módulo:** `aws-04-ec2-fundamentals`
- **Dificultad:** beginner
- **Duración estimada:** 40–60 min
- **Tipo:** independent (no depende operacionalmente de la 01, aunque conviene haberla hecho)

## 2. Contexto

En la actividad 01 montaste una EC2 segura con `AmazonSSMManagedInstanceCore`. Ahora vas un paso más: **le añades un permiso de aplicación mínimo** (leer un parámetro concreto de SSM Parameter Store) y escribes un **script de verificación** que, al correrse dentro de la EC2, demuestra:

1. Que la EC2 tiene la **identidad asumida correcta** (`aws sts get-caller-identity` devuelve `assumed-role/<rol>/<instance-id>`).
2. Que **IMDSv2 está activo** (el GET sin token devuelve 401; con token devuelve 200).
3. Que el permiso mínimo funciona (`aws ssm get-parameter` sobre **ese parámetro** sí; sobre otro, no).

Además, produces una **tabla CSV** comparando 6 tipos de instancia reales y un **launch template YAML** estructural, y defiendes en `DECISION.md` qué familia elegirías para 3 workloads.

**No se aplica en AWS**: todo se valida en local.

## 3. Objetivos

- Definir la policy mínima (`ssm:GetParameter` sobre un ARN concreto).
- Adjuntarla al rol vía `aws_iam_role_policy` o `aws_iam_policy` + `aws_iam_role_policy_attachment`.
- Escribir `test-sts.sh` con las 3 verificaciones.
- Rellenar `instance-families.csv`.
- Rellenar `launch-template.yaml` con los campos estructurales clave.
- Escribir `DECISION.md`.

## 4. Prerrequisitos

- `aws-02-iam-fundamentals` (saber escribir una policy mínima).
- Haber hecho la actividad 01 ayuda pero no es bloqueante.
- Herramientas: `bash`, `grep`. Opcionales: `terraform`, `shellcheck`, `python3` con `pyyaml` (para validar YAML).

**Costos**: cero.

## 5. Instrucciones

### 5.1 Directorio

```bash
mkdir -p /tmp/aws-04-02
cp -r <repo>/courses/aws/04-ec2-fundamentals/activities/02-attach-instance-profile-and-test-sts/starter/* /tmp/aws-04-02/
cd /tmp/aws-04-02
```

### 5.2 Completar `main.tf`

El starter define el rol y el instance profile. **Añade tú**:

1. Una policy JSON (vía `aws_iam_policy_document` → `aws_iam_role_policy`) que:
   - Permite `ssm:GetParameter` solo sobre el ARN `arn:aws:ssm:eu-west-1:123456789012:parameter/aws-04/demo/*`.
   - **No** usa `Action: "*"` ni `Resource: "*"`.

### 5.3 Completar `test-sts.sh`

El starter tiene el esqueleto. Añade:

- Shebang `#!/usr/bin/env bash` y `set -eu` (aquí **no** `pipefail` por los `| grep -q` del propio script — igual que los validadores).
- Función `assert_contains` que verifica que un comando produce una cadena.
- Las 3 verificaciones:
  - **A** — `aws sts get-caller-identity` debe contener `assumed-role/`.
  - **B** — IMDSv2 enforced: `curl -o /dev/null -s -w "%{http_code}" http://169.254.169.254/latest/meta-data/` debe devolver `401`. Luego con token debe devolver `200`.
  - **C** — `aws ssm get-parameter --name /aws-04/demo/foo` debe funcionar; `--name /aws-04/other/bar` debe fallar con `AccessDenied`.

### 5.4 Rellenar `instance-families.csv`

6 filas con columnas: `type,family,vcpu,memory_gib,arch,use_case,on_demand_usd_per_hour_eu_west_1`. Al menos deben aparecer `t4g`, `m7g` o `m7i`, `c7g` o `c7i`, `r7g` o `r7i`, y una `g` o `p` (GPU). Los precios son estimados aproximados; cita en una línea al final la **fuente** y **fecha de consulta**.

### 5.5 Rellenar `launch-template.yaml`

YAML estructural (no se aplica), debe tener al menos las claves:

```yaml
LaunchTemplateName: aws-04-web
LaunchTemplateData:
  ImageId: resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64
  InstanceType: t4g.small
  IamInstanceProfile:
    Name: aws04-ssm-profile
  MetadataOptions:
    HttpTokens: required
    HttpPutResponseHopLimit: 1
    HttpEndpoint: enabled
  NetworkInterfaces:
    - AssociatePublicIpAddress: false
      Groups: [sg-00000000]
  UserData: # base64 del user-data.sh
  TagSpecifications:
    - ResourceType: instance
      Tags:
        - { Key: Name, Value: aws-04-web }
```

### 5.6 Rellenar `DECISION.md`

Para 3 workloads dados:

1. **API HTTP de latencia moderada**, tráfico constante, binarios Go.
2. **Build de CI** (compila C++ grande), horario laboral, idle de madrugada.
3. **Base de datos in-memory tipo Redis** con 32 GB residentes.

Para cada uno: familia, tipo específico, 1 párrafo justificando (incluye si eliges Graviton y por qué).

### 5.7 Validar

```bash
bash <repo>/courses/aws/04-ec2-fundamentals/activities/02-attach-instance-profile-and-test-sts/tests/validate.sh /tmp/aws-04-02
```

## 6. Resultado esperado

```
/tmp/aws-04-02/
├── DECISION.md
├── instance-families.csv
├── launch-template.yaml
├── main.tf
├── test-sts.sh
└── variables.tf
```

Validador en verde (`RESULT: PASS`).

## 7. Criterios de aceptación

- Policy **mínima** (sin `*` en Action ni Resource).
- `test-sts.sh` cubre las 3 verificaciones (identidad, IMDSv2, permiso puntual).
- CSV con 6 filas y 7 columnas, incluyendo Graviton y GPU.
- YAML parseable con `python3 -c 'import yaml; yaml.safe_load(open("launch-template.yaml"))'`.
- `DECISION.md` cubre los 3 workloads.

## 8. Preguntas de reflexión

1. ¿Por qué el permiso mínimo apunta a un ARN con wildcard **de prefijo** (`.../aws-04/demo/*`) en vez de a un parámetro suelto?
2. Si el rol tuviera `ssm:*` sobre `*`, ¿qué podría hacer un atacante que explotara una SSRF a pesar de IMDSv2?
3. En la comparativa, ¿cuál es la razón económica para preferir `t4g` sobre `m7g.small` para una app con picos cortos y mucho idle?
4. ¿Por qué los campos del launch template son `PascalCase` cuando los de Terraform `aws_launch_template` son `snake_case`?
5. ¿Cuándo un ASG con `instance_refresh` sustituye a hacer `terraform taint` + `apply`?

## 9. Limpieza

```bash
rm -rf /tmp/aws-04-02
```
