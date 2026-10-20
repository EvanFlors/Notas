# Refactor: `VAULT_TOKEN` -> ID Token (OIDC) a HashiCorp Vault

Objetivo: eliminar la credencial de larga vida `VAULT_TOKEN` del proyecto `acme/platform/checkout` y reemplazarla por un **ID Token** emitido por **GitLab** por job, validado por **HashiCorp Vault** vía OIDC/JWT.

## Antes

El job de prod usaba un token de Vault almacenado como variable de proyecto `protected: true, masked: true`, rotado manualmente cada 90 dias por un humano:

```yaml
deploy-prod:
  stage: deploy
  image: alpine:3.20
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  variables:
    VAULT_ADDR: https://vault.example.com
  script:
    # VAULT_TOKEN se inyecta desde Project vars (protected + masked)
    - export VAULT_TOKEN="$VAULT_TOKEN"
    - vault kv get -field=password kv/checkout/prod/db > /tmp/dbpass
    - vault kv get -field=cert     kv/checkout/prod/tls > /tmp/tls.crt
    - ./deploy.sh
```

Problemas:

- **Rotacion manual** olvidable; si se filtra, valido hasta la siguiente rotacion.
- **Trust por posesion**: cualquiera con el token (operador, atacante que lo exfiltra) actua como el pipeline.
- **No audit trail por job**: Vault ve el mismo cliente para todos los jobs.
- **No pinning**: el token puede usarse desde cualquier contexto (local, CI, otro project).

## Despues

Nuevo `.gitlab-ci.yml` (ver archivo adjunto):

- Bloque `id_tokens:` declara `VAULT_ID_TOKEN` con `aud: https://vault.example.com`. GitLab emite un JWT firmado por su JWKS publico y lo coloca en esa env var del job.
- Bloque `secrets:` nativo con dos entradas:
  - `DB_PASSWORD` con `vault: checkout/prod/db#password@kv` y `file: false` -> se inyecta como env var.
  - `TLS_CERT` con `vault: checkout/prod/tls#cert@kv` y `file: true` -> se escribe a disco y `$TLS_CERT` contiene el path (necesario porque un cert PEM es multilinea y no se enmascara bien como string).
- No existe ninguna variable `VAULT_TOKEN`, `VAULT_ROLE_ID` ni `VAULT_SECRET_ID` en el proyecto. La vida util del JWT es la del job; al terminar, el token de Vault emitido (TTL 15 min) expira solo.

Flujo:

```
Job de GitLab ──(JWT con aud=https://vault.example.com)──▶ Vault
Vault valida firma (JWKS de GitLab) + bound_claims del rol
Vault emite token efimero (TTL=15 min, policy=checkout-prod-read)
GitLab lee kv/checkout/prod/* y inyecta DB_PASSWORD/TLS_CERT en el job
```

## Pinning en Vault

El rol `checkout-prod-reader` en Vault debe pinnear al minimo:

- **`project_path`** = `acme/platform/checkout` — garantiza que solo este project emita JWTs aceptables. Si se relaja (p. ej. a `acme/platform/*`), cualquier project del subgrupo puede leer los secretos de prod del checkout.
- **`ref`** = `main` — garantiza que solo pipelines sobre la branch `main` reciban el token. Si se relaja, una feature branch puede exfiltrar los secretos con un simple `env` en el script.
- **`ref_protected`** = `"true"` — defensa en profundidad: aunque la branch se llame `main`, debe estar marcada como protegida. Si alguien crea un branch llamado `main` en un fork (no aplica directamente a GitLab porque el fork cambia `project_path`, pero conceptualmente este claim refuerza el modelo).
- **`aud`** = `https://vault.example.com` — pinnea la audiencia; previene replay del JWT en otro proveedor que acepte el mismo issuer de GitLab.

Configuracion dummy del rol (operador de Vault, no vive en el repo):

```bash
vault write auth/jwt-gitlab/role/checkout-prod-reader \
  role_type="jwt" \
  user_claim="project_id" \
  bound_audiences="https://vault.example.com" \
  bound_claims_type="glob" \
  bound_claims='{"project_path":"acme/platform/checkout","ref":"main","ref_protected":"true"}' \
  policies="checkout-prod-read" \
  ttl=15m
```

### Que pasa si se relaja cada claim

| Claim relajado | Consecuencia |
|---|---|
| `project_path` fuera | Cualquier project del instance de GitLab puede leer prod. |
| `ref` fuera | Cualquier branch del project puede leer prod. Feature branch que haga `env` filtra el secreto. |
| `ref_protected` fuera | Si se protegieran branches con nombres equivocados, se abre a mas superficies. |
| `aud` fuera | Un JWT de GitLab emitido para otro proveedor (ej. AWS) seria aceptado por Vault; perdemos aislamiento entre destinos. |

## Nota de seguridad

Todos los valores en los archivos (`aud`, rutas de Vault, hostnames) son **dummy**. No hay credenciales reales ni endpoints de produccion reales. `vault.example.com` es un placeholder; en un repo real se mantendria igualmente como variable configurable o se parametrizaria por include.
