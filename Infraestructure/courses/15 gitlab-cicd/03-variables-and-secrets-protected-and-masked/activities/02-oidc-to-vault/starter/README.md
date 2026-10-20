# Starter — gl-03-02-oidc-to-vault

Produces 2 archivos: `.gitlab-ci.yml` (con `id_tokens:` + `secrets:`) y `README-INTENT.md` (justificación).

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/03-secrets-from-vault-with-idtoken/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-03-02
   cd /tmp/gl-03-02
   ```
3. Escribe `.gitlab-ci.yml` con un job `deploy-prod` que:
   - Corra en `main` (`rules:`).
   - Tenga `environment: name: production`.
   - Declare `id_tokens:` con una entrada cuya `aud` empiece por `https://vault`.
   - Declare `secrets:` con **dos** secretos distintos — uno `file: false`, otro `file: true`.
   - **No** incluya `VAULT_TOKEN`, `VAULT_ROLE_ID` ni `VAULT_SECRET_ID` por ningún lado.
4. Verifica YAML:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))" && echo OK
   ```
5. Escribe `README-INTENT.md` con 3 secciones (`## Antes`, `## Despues`, `## Pinning en Vault`). Menciona explícitamente `project_path`, `ref`, `ref_protected`, `HashiCorp Vault`, `GitLab`, y aclara que todos los valores son dummy.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/03-variables-and-secrets-protected-and-masked/activities/02-oidc-to-vault/tests/validate.sh /tmp/gl-03-02
   ```
7. Compara con `../solution/` para autoevaluarte.

## Nunca pongas valores reales

Audiencias dummy: `https://vault.example.com`, `https://vault.dev.internal`.
Rutas dummy: `checkout/prod/db#password@kv`, `checkout/prod/tls#cert@kv`.

Si tu editor te sugiere autocompletar un hostname real de Vault o un path real, bórralo y usa `.example.com`.

## Esqueleto sugerido para `.gitlab-ci.yml`

```yaml
stages:
  - deploy

deploy-prod:
  stage: deploy
  image: alpine:3.20
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  secrets:
    DB_PASSWORD:
      vault: checkout/prod/db#password@kv
      file: false
    TLS_CERT:
      vault: checkout/prod/tls#cert@kv
      file: true
  script:
    - echo "DB_PASSWORD inyectado como env var (masked)"
    - echo "TLS_CERT escrito a $TLS_CERT (file-type)"
```

## Esqueleto sugerido para `README-INTENT.md`

```markdown
# Refactor: VAULT_TOKEN -> ID Token (OIDC) a HashiCorp Vault

## Antes
```yaml
deploy-prod:
  variables:
    VAULT_TOKEN: $VAULT_TOKEN   # Project var protected+masked, rotada manualmente cada 90d
  script:
    - vault kv get -field=password kv/checkout/prod/db
```

## Despues
<explica el flujo: GitLab emite JWT -> Vault valida -> entrega secreto efimero>

## Pinning en Vault
<menciona project_path, ref, ref_protected; que pasa si cada uno se relaja>

## Nota de seguridad
Los valores de `aud` y rutas son dummy. No hay credenciales reales en estos archivos.
```
