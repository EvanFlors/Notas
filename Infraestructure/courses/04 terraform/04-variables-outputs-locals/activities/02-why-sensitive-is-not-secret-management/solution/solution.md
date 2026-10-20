# Solución de referencia — tf-04-02

> Este archivo es la referencia que da `ANALYSIS.md` cuando el estudiante lo
> entrega. Los valores exactos (hash, nombre de pet, etc.) varían por
> ejecución; lo relevante es la forma de la demostración y la claridad del
> análisis. El validador buscará en el `ANALYSIS.md` del estudiante los
> elementos marcados abajo.

## Demostración esperada (resumen)

1. `terraform output` oculta `dummy_token` y `derived_fingerprint` como `<sensitive>`.
2. `terraform output -raw dummy_token` imprime la cadena en claro.
3. `grep -o 'DUMMY-SECRET-DO-NOT-USE-[a-z_-]*' terraform.tfstate | sort -u` devuelve
   al menos una coincidencia.
4. `grep -c 'BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY' terraform.tfstate` devuelve >= 1.
5. En el JSON del state, `outputs.dummy_token.value` está en claro y
   `outputs.dummy_token.sensitive` vale `true` — demostrando que el flag es un
   marcador, no un cifrado del campo paralelo.

## Lugares donde el valor sigue siendo recuperable (al menos 3)

- El `terraform.tfstate` (local o backend remoto).
- El plan guardado con `terraform plan -out=plan.tfplan`.
- `terraform output -raw <name>`.
- El provider cuando llama a la API remota (lo envía tal cual).
- Logs del provider con `TF_LOG=DEBUG`.
- Cualquiera con acceso de lectura al backend remoto.

## Conclusión esperada

`sensitive = true` **no cifra** nada. Es un marcador de propagación que
oculta valores en la salida CLI y en logs superficiales. Sigue siendo útil
(evita filtrado accidental en comentarios de PR, logs de CI, chat), pero no
sustituye a un secret manager.

## Mitigación correcta — patrón recomendado

- Los secretos reales no viven como `variable` ni en `.tfvars` que entre a Git.
- Se guardan en un secret manager (AWS Secrets Manager, Vault, GCP Secret
  Manager, SOPS…).
- Se leen con un `data` source:

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/payments/db"
}

resource "aws_db_instance" "payments" {
  username = "payments"
  password = data.aws_secretsmanager_secret_version.db.secret_string
}
```

- La protección del state se hace **al nivel del backend**: encriptación
  at-rest, IAM mínimo, versionado del bucket, access logs.

## Outputs que SÍ se marcarían sensitive en producción

Contraseñas, tokens de bootstrap, llaves privadas emitidas por `tls_private_key`,
strings de conexión. Aunque el state los tenga, evitas que aparezcan en
comentarios de PR, logs de CI o conversaciones compartidas.

## Outputs que NO conviene marcar sensitive

IDs públicos, ARNs, nombres de buckets, dominios DNS — el ruido oculta la
señal de qué sí es realmente sensible.
