# Solución de referencia — ans-06-01-encrypt-sensitive-vars

Script completo que lleva el workdir a un estado válido:

```bash
set -eu
BASE="/tmp/ans-06-vault"
rm -rf "$BASE"
mkdir -p "$BASE"/{group_vars,.vault}
cd "$BASE"

echo 'fake-dev-vault-pass'  > .vault/dev_pass
echo 'fake-prod-vault-pass' > .vault/prod_pass
chmod 0600 .vault/*

cat > group_vars/all.yml <<'YAML'
app_name: fastapi-demo
app_port: 8000
YAML

cat > group_vars/prod.yml <<'YAML'
env: prod
api_token: fake-prod-token-not-real
rds_master_password: fake-rds-password-not-real
YAML

ansible-vault encrypt --vault-id prod@.vault/prod_pass group_vars/prod.yml

ansible-vault encrypt_string \
  --vault-id dev@.vault/dev_pass \
  'fake-db-password-not-real' \
  --name 'db_password' >> group_vars/all.yml

cat > README-INTENT.md <<'MD'
# Vault layout

Este repo usa dos vault IDs separados para aislar scopes entre dev y prod.
Las passwords son fake-password-not-real (lab); en real viven en un secret
manager y las entrega el runner via script ejecutable.

## dev vault
- Vault ID: `dev`.
- Protege: valores encriptados individualmente dentro de `group_vars/all.yml`
  mediante encrypt_string (p. ej. `db_password`).
- Password file: `.vault/dev_pass` (fake-password-not-real).

## prod vault
- Vault ID: `prod`.
- Protege: `group_vars/prod.yml` entero (`api_token`, `rds_master_password`).
- Password file: `.vault/prod_pass` (fake-password-not-real).

## Rotation plan
- Rotar cada 90 dias y ante cualquier offboarding con acceso previo.
- Comando: `ansible-vault rekey --vault-id prod@old --new-vault-id prod@new`.
- La vault password **no se commitea** nunca. En CI la provee un script
  ejecutable que la lee del secret manager (AWS SM / HashiCorp Vault).
MD
```

## Checklist de autoevaluación

- [ ] `head -1 group_vars/prod.yml` muestra `$ANSIBLE_VAULT;1.2;AES256;prod`.
- [ ] `grep -c '!vault' group_vars/all.yml` ≥ 1.
- [ ] `ansible-vault view --vault-id prod@.vault/prod_pass group_vars/prod.yml` descifra sin error.
- [ ] `ansible-vault view --vault-id dev@.vault/dev_pass group_vars/prod.yml` falla.
- [ ] `README-INTENT.md` tiene las 4 secciones y menciona `fake-password-not-real`.
- [ ] El validador reporta `OK`.

## Errores comunes

- Olvidar `chmod 0600` sobre `.vault/*`.
- Encriptar `prod.yml` **sin** label (`--vault-id prod@...` → el header lleva `prod`; omitirlo lo deja como `1.1` sin label).
- Pegar el output de `encrypt_string` **sin** indentación consistente dentro del YAML.
- Dejar un valor que parezca secreto real (p. ej. una API key verdadera copiada por accidente).
