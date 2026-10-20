# Starter — ans-06-01-encrypt-sensitive-vars

Esta actividad es un **guided-lab** práctico. No hay código precargado — construyes el estado paso a paso con `ansible-vault`.

## Pasos resumen

1. `mkdir -p /tmp/ans-06-vault/{group_vars,.vault}` y crea `.vault/dev_pass` y `.vault/prod_pass` con contenido `fake-dev-vault-pass` / `fake-prod-vault-pass` y permisos `0600`.
2. Crea `group_vars/all.yml` con `app_name` / `app_port` en claro.
3. Crea `group_vars/prod.yml` con `env`, `api_token`, `rds_master_password` (todos `fake-...`).
4. Encripta `group_vars/prod.yml` con `ansible-vault encrypt --vault-id prod@.vault/prod_pass`.
5. Encripta un string `fake-db-password-not-real` con `ansible-vault encrypt_string --vault-id dev@.vault/dev_pass --name 'db_password'` y **anexa** el output a `group_vars/all.yml`.
6. Verifica el header de `prod.yml` (`$ANSIBLE_VAULT;1.2;AES256;prod`).
7. Verifica con `ansible-vault view --vault-id prod@.vault/prod_pass group_vars/prod.yml` que puedes descifrar.
8. Verifica que `ansible-vault view --vault-id dev@.vault/dev_pass group_vars/prod.yml` **falla**.
9. Escribe `README-INTENT.md` con las 4 secciones requeridas.
10. Ejecuta `bash <repo>/courses/ansible/06-vault-and-secrets-management/activities/01-encrypt-sensitive-vars/tests/validate.sh /tmp/ans-06-vault`.

> **Importante**: `ansible-vault` debe estar en `PATH`. En macOS con `pip --user`: `export PATH="$HOME/Library/Python/3.10/bin:$PATH"`.

## Plantilla sugerida para `README-INTENT.md`

```markdown
# Vault layout

Este repo usa dos vault IDs separados para aislar scopes de secretos entre
entornos. Las passwords son fake (`fake-*-not-real`) porque este es un
laboratorio; en real, viven en un secret manager y las lee el runner.

## dev vault
- Vault ID: `dev`
- Protege: valores encriptados individualmente dentro de `group_vars/all.yml`
  (via encrypt_string).
- Password: `.vault/dev_pass` (fake-password-not-real-en-el-lab).

## prod vault
- Vault ID: `prod`
- Protege: `group_vars/prod.yml` entero (api_token, rds_master_password).
- Password: `.vault/prod_pass` (fake-password-not-real-en-el-lab).

## Rotation plan
- Rotar con `ansible-vault rekey --vault-id prod@... --new-vault-id prod@...`
  cada 90 dias o ante cualquier salida de personal con acceso.
- La password **no se commitea** nunca. En CI la provee el secret manager via
  script ejecutable.
```
