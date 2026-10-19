# Recursos — aws-09

> Referencias oficiales. Verifica vigencia (los enlaces y APIs cambian).

## KMS

- Guía de desarrollador: `https://docs.aws.amazon.com/kms/latest/developerguide/overview.html`
- Envelope encryption: `https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#enveloping`
- Key policies — concepto y plantilla: `https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html`
- Condiciones (`kms:ViaService`, `kms:CallerAccount`, `kms:EncryptionContext`): `https://docs.aws.amazon.com/kms/latest/developerguide/policy-conditions.html`
- Rotación automática: `https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html`
- Multi-Region keys: `https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html`

## Secrets Manager

- Conceptos y versiones (`AWSCURRENT`, `AWSPENDING`, `AWSPREVIOUS`): `https://docs.aws.amazon.com/secretsmanager/latest/userguide/getting-started.html`
- Rotación — ciclo de 4 pasos: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html`
- Templates oficiales de Lambda rotator (RDS, Redshift, DocumentDB): `https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_available-rotation-templates.html`
- Replicación cross-Region: `https://docs.aws.amazon.com/secretsmanager/latest/userguide/create-manage-multi-region-secrets.html`
- Costos (consulta la página pública): `https://aws.amazon.com/secrets-manager/pricing/`

## SSM Parameter Store

- Parameter Store (overview): `https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html`
- Tiers standard vs advanced: `https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html`
- SecureString: `https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-securestring.html`
- Jerarquía por path: `https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-hierarchies.html`

## LocalStack (para las actividades)

- LocalStack (community edition ofrece KMS, SSM y Secrets Manager): `https://docs.localstack.cloud/`
- Compatibilidad por servicio (feature coverage): `https://docs.localstack.cloud/references/coverage/`
- Cliente `awslocal`: `https://github.com/localstack/awscli-local`

Modo rápido para este módulo:

```bash
# Opcional: usando Docker
docker run --rm -d --name localstack -p 4566:4566 \
  -e SERVICES=kms,secretsmanager,ssm \
  localstack/localstack

# Comprobar
curl -s http://localhost:4566/_localstack/health | jq .
```

Variables de entorno típicas al invocar `boto3` o `aws` contra LocalStack:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

(Nunca uses access keys reales en estas actividades. Los valores `test`/`test` son los dummies oficiales de LocalStack.)

## Lecturas de apoyo

- *AWS Well-Architected Framework — Security pillar*, sección "Protection of Data at Rest": `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/protecting-data-at-rest.html`
- Comparativa "Secrets Manager vs Parameter Store" (blog AWS, buscar la versión más reciente).
- Charla "A Tale of Two Services: Secrets Manager and Parameter Store" (re:Invent — hay varias ediciones).

## Checklist de verificación

- Última versión de boto3 (API de `kms`, `secretsmanager`, `ssm`).
- Feature coverage actual de LocalStack para `secretsmanager:rotate-secret` (históricamente limitado; en este módulo lo tratamos como walkthrough intencionalmente).
- Precios vigentes de Secrets Manager y Parameter Store advanced.
