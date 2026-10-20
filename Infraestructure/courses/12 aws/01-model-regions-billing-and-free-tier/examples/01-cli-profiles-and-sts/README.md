# Ejemplo 01 — Perfiles de AWS CLI y `sts get-caller-identity` (contra LocalStack)

> Objetivo: entender la mecánica de perfiles de la CLI y el comando `aws sts get-caller-identity` **sin tocar AWS real**. Toda la práctica corre contra LocalStack si está disponible; si no, se queda en lectura.

## 1. Qué vamos a ver

- Configurar **dos perfiles** distintos (`demo-local` y `demo-local-eu`) en `~/.aws/config` y `~/.aws/credentials`.
- Comprobar la **precedencia** de credenciales: variable de entorno vs flag `--profile` vs default.
- Ejecutar `aws sts get-caller-identity` contra LocalStack y leer el ARN devuelto.
- Entender por qué, aun con credenciales ficticias, el comando responde (LocalStack no valida la firma SigV4 real).

**Costos:** cero. **Red:** solo `localhost`.

## 2. Requisitos (opcional — skip graceful si faltan)

- `aws` CLI v2 instalada.
- `docker` + LocalStack image (`localstack/localstack:latest`). Si no tienes Docker, pasa a la variante "sin LocalStack" al final.

Verifica:

```bash
aws --version
docker --version
```

## 3. Levantar LocalStack

```bash
docker run --rm -d --name aws-01-localstack \
  -p 4566:4566 \
  -e SERVICES=sts,iam,s3 \
  localstack/localstack:latest

# Espera unos segundos
sleep 5
curl -s http://localhost:4566/_localstack/health | head -c 200
```

Deberías ver un JSON con `"sts": "available"`.

## 4. Configurar dos perfiles **aislados** en archivos de este ejemplo

Para no tocar tu `~/.aws/` real, generamos un `AWS_CONFIG_FILE` y `AWS_SHARED_CREDENTIALS_FILE` locales:

```bash
mkdir -p /tmp/aws-01-ex01-cli
cat > /tmp/aws-01-ex01-cli/config <<'EOF'
[profile demo-local]
region = us-east-1
output = json

[profile demo-local-eu]
region = eu-west-1
output = json
EOF

cat > /tmp/aws-01-ex01-cli/credentials <<'EOF'
[demo-local]
aws_access_key_id = test
aws_secret_access_key = test

[demo-local-eu]
aws_access_key_id = test
aws_secret_access_key = test
EOF

export AWS_CONFIG_FILE=/tmp/aws-01-ex01-cli/config
export AWS_SHARED_CREDENTIALS_FILE=/tmp/aws-01-ex01-cli/credentials
```

## 5. Ejecutar `sts get-caller-identity`

```bash
aws --endpoint-url=http://localhost:4566 --profile demo-local sts get-caller-identity
```

Salida esperada (los IDs cambian según versión de LocalStack):

```json
{
    "UserId": "AKIAIOSFODNN7EXAMPLE",
    "Account": "000000000000",
    "Arn": "arn:aws:iam::000000000000:user/moto"
}
```

Observa:

- `Account = 000000000000` — es el placeholder que LocalStack usa siempre. En AWS real sería tu `AccountId` de 12 dígitos.
- `Arn` termina en `user/moto` o similar porque LocalStack simplifica el principal.
- **El comando funcionó aun con credenciales `test`/`test`.** LocalStack no verifica la firma; AWS real **sí** y rechazaría con 403.

## 6. Observa la precedencia de credenciales

Con una env var sobrescribes el perfil:

```bash
AWS_ACCESS_KEY_ID=otro AWS_SECRET_ACCESS_KEY=otro \
  aws --endpoint-url=http://localhost:4566 --profile demo-local sts get-caller-identity
```

El perfil `demo-local` dice `test`/`test`, pero las env vars tienen **mayor** precedencia. En LocalStack ambos devuelven la misma identidad simulada; en AWS real, si tu env var apunta a otra cuenta, acabas operando contra **otra cuenta** sin darte cuenta. **Este es el bug #1 de principiantes.**

## 7. Comprueba el `region` por perfil

```bash
aws --profile demo-local configure get region
# us-east-1

aws --profile demo-local-eu configure get region
# eu-west-1
```

Cuando llamas, p. ej., `aws s3 ls`, el perfil `demo-local-eu` apunta a `s3.eu-west-1.amazonaws.com` y `demo-local` a `s3.us-east-1.amazonaws.com`. Un bucket creado en una región **no aparece** desde la otra (aunque el namespace de nombres sea global).

## 8. Limpieza

```bash
docker stop aws-01-localstack 2>/dev/null || true
unset AWS_CONFIG_FILE AWS_SHARED_CREDENTIALS_FILE
rm -rf /tmp/aws-01-ex01-cli
```

## 9. Variante sin LocalStack (lectura seca)

Si no tienes Docker, salta a la lectura del archivo `expected-output.txt` incluido abajo y memoriza el *shape* de la respuesta JSON. En AWS real, el ARN sería `arn:aws:iam::123456789012:user/tu-usuario` o `arn:aws:sts::123456789012:assumed-role/AdminRole/alice` si usas SSO.

### Expected output (de referencia, sin ejecutar)

```json
{
    "UserId": "AIDAEXAMPLEUSERID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/alice"
}
```

## 10. Qué llevarte

- `aws sts get-caller-identity` es **siempre** tu primer comando.
- Los perfiles viven en dos archivos (`config` y `credentials`) con una sintaxis asimétrica (`[profile X]` vs `[X]`).
- Las variables de entorno **ganan** al perfil — si no lo sabes, es la trampa que más caro paga en producción.
- La región determina el endpoint; el endpoint determina a qué datacenter van tus llamadas.
