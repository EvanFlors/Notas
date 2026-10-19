# REFERENCE — aws-04-02-attach-instance-profile-and-test-sts

## `main.tf` — policy mínima (fragmento clave)

```hcl
data "aws_iam_policy_document" "app_min" {
  statement {
    sid     = "ReadDemoParameters"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id_dummy}:parameter${var.parameter_prefix}/*"
    ]
  }
}

resource "aws_iam_role_policy" "app_min" {
  name   = "${var.name_prefix}-min"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.app_min.json
}
```

Nota la **doble restricción**:

- `actions` lista 2 acciones concretas (no `ssm:*`).
- `resources` apunta a un ARN concreto con wildcard **solo** en el sufijo bajo el prefijo controlado por `var.parameter_prefix`.

## `test-sts.sh` — completo

```bash
#!/usr/bin/env bash
# Verifica identidad del instance profile, IMDSv2 enforced y permiso minimo.
#
# NOTA SIGPIPE: deliberadamente omitimos la opcion pipefail. Usamos
# `aws ... | grep -q` para detectar strings esperadas; grep puede cerrar
# el pipe pronto y hacer que el proceso aws termine con 141. Habilitar
# pipefail convertiria eso en un falso-negativo.
set -eu

PARAM_ALLOWED="${PARAM_ALLOWED:-/aws-04/demo/foo}"
PARAM_FORBIDDEN="${PARAM_FORBIDDEN:-/aws-04/other/bar}"

fail() { echo "FAIL: $*"; exit 1; }
ok()   { echo "  OK   $*"; }

echo "== test-sts =="

echo "-- A. sts get-caller-identity --"
arn=$(aws sts get-caller-identity --query Arn --output text)
echo "    Arn: $arn"
echo "$arn" | grep -q 'assumed-role/' || fail "no es un rol asumido"
ok "la EC2 opera como rol asumido"

echo "-- B. IMDSv2 enforced --"
code=$(curl -o /dev/null -s -w "%{http_code}" http://169.254.169.254/latest/meta-data/ || true)
[ "$code" = "401" ] || fail "IMDS respondio $code sin token (deberia ser 401 con IMDSv2)"
ok "GET sin token → 401 (IMDSv1 bloqueado)"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
          -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
code=$(curl -o /dev/null -s -w "%{http_code}" \
         -H "X-aws-ec2-metadata-token: $TOKEN" \
         http://169.254.169.254/latest/meta-data/instance-id)
[ "$code" = "200" ] || fail "GET con token devolvio $code (deberia 200)"
ok "GET con token → 200"

echo "-- C. permiso minimo --"
aws ssm get-parameter --name "$PARAM_ALLOWED" --query 'Parameter.Name' --output text \
  | grep -q "$PARAM_ALLOWED" \
  || fail "no pude leer $PARAM_ALLOWED (deberia estar permitido)"
ok "lectura de $PARAM_ALLOWED permitida"

if aws ssm get-parameter --name "$PARAM_FORBIDDEN" >/tmp/sts-forbid.out 2>&1; then
  fail "pude leer $PARAM_FORBIDDEN (deberia haber sido denegado)"
fi
grep -qiE 'AccessDenied|not authorized' /tmp/sts-forbid.out \
  || fail "la llamada a $PARAM_FORBIDDEN fallo pero no con AccessDenied"
ok "lectura de $PARAM_FORBIDDEN correctamente denegada"
rm -f /tmp/sts-forbid.out

echo
echo "OK: todas las verificaciones pasaron."
```

## `instance-families.csv` — ejemplo

```csv
type,family,vcpu,memory_gib,arch,use_case,on_demand_usd_per_hour_eu_west_1
t4g.small,burstable-arm,2,2,arm64,dev/test ocasional,0.0176
m7g.large,general-arm,2,8,arm64,API HTTP generica Go/Python,0.0896
m7i.large,general-intel,2,8,x86_64,workload x86-only general,0.1008
c7g.xlarge,compute-arm,4,8,arm64,CI builds C++ en horario laboral,0.1445
r7g.xlarge,memory-arm,4,32,arm64,Redis in-memory 32 GB,0.1890
g5.xlarge,gpu-nvidia,4,16,x86_64,ML inference con GPU A10G,1.3080
# Fuente: https://aws.amazon.com/ec2/pricing/on-demand/ consultado 2025-01 (eu-west-1).
```

(Los precios cambian; sirven como orden de magnitud y disciplina de citar fuente.)

## `launch-template.yaml` — completo

```yaml
LaunchTemplateName: aws-04-web
LaunchTemplateData:
  ImageId: resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64
  InstanceType: t4g.small
  IamInstanceProfile:
    Name: aws04-sts-profile
  MetadataOptions:
    HttpTokens: required
    HttpPutResponseHopLimit: 1
    HttpEndpoint: enabled
  NetworkInterfaces:
    - AssociatePublicIpAddress: false
      Groups:
        - sg-00000000
  TagSpecifications:
    - ResourceType: instance
      Tags:
        - Key: Name
          Value: aws-04-web
        - Key: Environment
          Value: lab
```

## `DECISION.md` — referencia

### 1. API HTTP de latencia moderada, tráfico constante, binarios Go

- **Familia:** general purpose, Graviton (`m7g`).
- **Tipo:** `m7g.large` (2 vCPU / 8 GiB).
- **Justificación:** tráfico constante excluye la burstable `t4g` (los créditos se agotarían). `m7g` da equilibrio CPU/mem al mejor precio por core; Go compila nativo a ARM64 sin fricción, por lo que Graviton es ~20 % más barato que `m7i`.

### 2. Build de CI que compila C++ grande, horario laboral, idle de madrugada

- **Familia:** compute optimized, Graviton (`c7g`) **si el C++ compila cross** a ARM, si no `c7i`.
- **Tipo:** `c7g.2xlarge` (8 vCPU / 16 GiB) con **ASG escalado por cola de jobs** y `scheduled-action` para apagar de madrugada.
- **Justificación:** compilación C++ es CPU-bound → familia `c`. La ventaja real es el **auto-scaling** horario, no la familia: ejecutar `c7g.2xlarge` 10h/día cuesta menos que `t3.large` 24h/día. Spot instances pueden rebajar aún más (toleran interrupción).

### 3. Base de datos in-memory tipo Redis, 32 GB residentes

- **Familia:** memory optimized, Graviton (`r7g`).
- **Tipo:** `r7g.xlarge` (4 vCPU / 32 GiB) con **snapshot EBS periódico** (gp3) y **ElastiCache** evaluado como alternativa.
- **Justificación:** ratio memoria/CPU alto → familia `r`. 32 GiB en una `r.xlarge` cabe justo; una `.2xlarge` da margen de headroom + buffers. Redis es single-thread en el loop principal → cores extra solo ayudan al kernel y persist/replica. Graviton funciona nativo con Redis desde hace años.

## Reflexiones (modelo)

1. **ARN con prefijo**: permite agrupar varios parámetros bajo un namespace lógico (`/aws-04/demo/db-password`, `.../api-key`) y dar permiso en bloque sin tocar la policy cada vez que creas uno nuevo. El wildcard está acotado al prefijo que **tú** controlas, no es `*` global.
2. Con `ssm:*` sobre `*` el atacante podría leer **cualquier** parámetro de la cuenta (incluidos secretos de otros equipos), modificar parámetros, borrarlos, ejecutar `send-command` para correr comandos arbitrarios en otras EC2 administradas por SSM, etc. IMDSv2 solo detiene el **método inicial** de extracción; el **blast radius** sigue siendo lo que diga el rol.
3. `t4g` tiene CPU base baja (10–40 %) pero acumula **créditos** mientras no se usa. Si tu app es idle la mayor parte del día y pica brevemente, pagas por una `t4g.small` barata y el pico consume créditos acumulados. Una `m7g.small` fija cuesta más y rinde igual en ese patrón → `t4g` sale ganando. Para carga sostenida se invierte el cálculo.
4. **PascalCase vs snake_case**: el YAML del launch template es el formato de la **API de AWS** (todas las APIs usan PascalCase en los campos). Terraform le mete una capa idiomática: traduce `MetadataOptions` → `metadata_options`, `HttpTokens` → `http_tokens`, etc. Al final la llamada a AWS es la misma.
5. `instance_refresh` del ASG hace rolling replace **in situ** respetando `min_healthy_percentage`, con health checks; `terraform taint` + `apply` destruye y recrea sin orquestar healthiness. Para producción con tráfico vivo, siempre `instance_refresh` (o un deploy via blue/green con nuevo ASG).
