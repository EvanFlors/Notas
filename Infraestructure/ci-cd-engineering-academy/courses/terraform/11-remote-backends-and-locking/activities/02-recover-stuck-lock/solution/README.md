# Solución — tf-11-02

## Recuperación paso a paso

```bash
cd /tmp/tf-11-02

# 1. Simular (ya hecho si corriste inject-lock.sh)
MODE=local bash scripts/inject-lock.sh

# 2. Reproducir
terraform init -backend-config=backend.hcl
terraform plan           # falla con "Error acquiring the state lock" + LockID visible

# 3. Investigar
aws --endpoint-url=$AWS_ENDPOINT_URL_DYNAMODB dynamodb get-item \
  --table-name tf-lock-tf11 \
  --key '{"LockID":{"S":"tf-state-tf11/tf-11-02/terraform.tfstate-md5"}}'
# → Lees Info.Who, Info.Created, Info.ID

aws --endpoint-url=$AWS_ENDPOINT_URL_S3 s3api list-object-versions \
  --bucket tf-state-tf11 --prefix tf-11-02/
# → Confirmas que no hay escrituras recientes al state

# 4. Confirmar que el proceso original está muerto
#    (en el mundo real: Slack, PagerDuty, 'ps' en el runner).

# 5. Liberar — usa el ID del campo Info.ID (NO el LockID completo)
LOCK_ID="f3a1c9e2-aaaa-bbbb-cccc-ddddeeeeffff"
terraform force-unlock "$LOCK_ID"   # pide confirmación: 'yes'

# 6. Verificar
terraform plan                      # ya no da error
aws --endpoint-url=$AWS_ENDPOINT_URL_DYNAMODB dynamodb scan \
  --table-name tf-lock-tf11         # fila eliminada
```

## Post-mortem — ejemplo

Ver `postmortem.example.md`.

## Por qué `aws dynamodb delete-item` no es equivalente

- No deja huella en los logs de Terraform (no hay registro de que fuera un force-unlock).
- No pide confirmación → fácil de ejecutar por accidente sobre un lock legítimo.
- Si en el futuro Terraform añade pasos adicionales al unlock (p. ej. verificar el objeto .tflock en S3 native locking), `delete-item` se los salta.

Usa siempre `terraform force-unlock`.
