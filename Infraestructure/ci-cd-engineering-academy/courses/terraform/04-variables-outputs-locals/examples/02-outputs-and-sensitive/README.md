# Ejemplo 02 — Outputs y sensitive (y por qué sensitive no es cifrado)

## Concepto que demuestra

- Un `output` con `sensitive = true` aparece como `<sensitive>` en `terraform output`.
- **El mismo valor queda en claro** en `terraform.tfstate`.
- Cómo extraer el valor con `terraform output -raw` cuando necesitas pasarlo a otro proceso.
- Cómo un valor sensitive se **propaga**: si una expresión lo usa, su resultado también se marca sensitive.

> **Importante:** los "secretos" en este ejemplo son **cadenas dummy** claramente marcadas (`fake-token-NOT-A-REAL-SECRET`). Nunca pongas secretos reales en archivos de Git.

## Objetivo

Al terminar sabrás:

- Marcar un `output` como `sensitive` y entender qué oculta y qué no.
- Explicar por qué el state tiene el valor en claro aunque el output lo oculte.
- Enumerar los dos lugares donde el "secreto" fuga: el state y el `-raw` del output.
- Justificar por qué los secretos reales no viven como `variable` ni como `output`.

## Prerrequisitos

- Terraform >= 1.3.0.
- `bash`, `grep`, `jq` (opcional).
- Sin costo (providers locales: `tls`, `local`, `random`).

## Archivos

```
versions.tf      # required_providers tls, local, random
main.tf          # genera una llave privada TLS self-signed (secreto real por naturaleza)
                 # + un token dummy para completar la demo
outputs.tf       # tres outputs: visible, sensitive, sensitive propagado
```

## Ejecución

```bash
cd courses/terraform/04-variables-outputs-locals/examples/02-outputs-and-sensitive/

terraform init
terraform apply -auto-approve

# 1. Mira los outputs: los sensitive aparecen como <sensitive>.
terraform output
#   public_pem        = <<EOT ... -----BEGIN PUBLIC KEY----- ... EOT
#   private_pem       = <sensitive>
#   kid_dummy_token   = <sensitive>
#   derived_fingerprint = <sensitive>   # ← se contagió por usar el private_pem

# 2. Pero puedes sacarlos:
terraform output -raw kid_dummy_token
echo
terraform output -raw private_pem | head -3

# 3. Y están tal cual en el state:
grep -c "fake-token-NOT-A-REAL-SECRET" terraform.tfstate
#   Devuelve un número >= 1. El token "oculto" vive en claro en el state.

grep -c "BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY" terraform.tfstate
#   Igual: la llave privada completa está en el state.

# 4. Compara con lo que verías en logs de CI:
#    Si tu pipeline hace `terraform apply`, los valores sensitive no aparecen
#    en los logs. Esa es la (única) protección real que te da `sensitive`.
```

## Qué mirar

- `terraform output` oculta los valores marcados; `terraform output -raw <name>` los imprime (es intencional, para pasarlos a otros procesos).
- `derived_fingerprint` es un valor "derivado" del `private_pem`; TF lo marca sensitive automáticamente porque uno de sus inputs lo es.
- `terraform.tfstate` es JSON legible. Puedes abrirlo con tu editor. El valor "sensitive" está ahí tal cual.
- Si tuvieras un backend remoto (S3, GCS, HCP, etc.), este mismo contenido viajaría al backend. La protección real está en el **backend** (encriptación at-rest, IAM mínimo, versionado).

## Conclusión operacional

- `sensitive = true` **sirve** para no filtrar valores a stdout/logs/consola. Úsalo.
- `sensitive = true` **no sirve** como gestión de secretos. Para secretos reales:
  1. No los pongas en `variable` ni en `tfvars` que entren a Git.
  2. Guárdalos en un secret manager (Vault, AWS Secrets Manager, GCP Secret Manager, SOPS…).
  3. Léelos con un `data` source.
  4. Protege el state al nivel del backend.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```
