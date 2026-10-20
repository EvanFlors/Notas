# Ejemplo 03 — Secretos desde Vault con ID Token (OIDC)

> Lectura y análisis. Muestra el patrón moderno: cero tokens de larga vida en GitLab; GitLab emite un JWT efímero, Vault lo valida y entrega el secreto.

## Idea

En vez de guardar `VAULT_TOKEN` como variable protegida/enmascarada (y rotarlo manualmente), el job pide a GitLab un **ID Token** (JWT firmado por GitLab), lo entrega a Vault, Vault valida la firma + los claims y responde con el secreto. Nada perdura entre jobs.

Equivalente mental en GitHub Actions: `permissions: id-token: write` + `aws-actions/configure-aws-credentials`. Mismo concepto, keyword distinto.

## Configuración en Vault (dummy, no se ejecuta)

Suponiendo Vault accesible en `https://vault.example.com`:

```bash
# 1) Habilitar el método JWT (una sola vez por operador de Vault).
vault auth enable -path=jwt-gitlab jwt

# 2) Apuntarlo al issuer de GitLab para que descargue el JWKS.
vault write auth/jwt-gitlab/config \
  oidc_discovery_url="https://gitlab.example.com" \
  bound_issuer="https://gitlab.example.com"

# 3) Definir un rol pinneado al project + ref protegida.
vault write auth/jwt-gitlab/role/checkout-prod-reader \
  role_type="jwt" \
  user_claim="project_id" \
  bound_audiences="https://vault.example.com" \
  bound_claims_type="glob" \
  bound_claims='{"project_path":"acme/platform/checkout","ref":"main","ref_protected":"true"}' \
  policies="checkout-prod-read" \
  ttl=15m
```

Y la policy de Vault `checkout-prod-read`:

```hcl
path "kv/data/checkout/prod/*" {
  capabilities = ["read"]
}
```

> Nada de esto va al repositorio. Es configuración del operador de Vault.

## `.gitlab-ci.yml` del proyecto

```yaml
stages: [deploy]

deploy-prod:
  stage: deploy
  image: alpine:3.20
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
    - echo "DB_PASSWORD lives in env var (masked)"
    - echo "TLS_CERT lives at path $TLS_CERT (file-type)"
    - deploy.sh
```

## Qué pasa, paso a paso

1. GitLab genera un JWT con claims aproximados:
   ```json
   {
     "iss": "https://gitlab.example.com",
     "sub": "project_path:acme/platform/checkout:ref_type:branch:ref:main",
     "aud": "https://vault.example.com",
     "project_path": "acme/platform/checkout",
     "ref": "main",
     "ref_protected": "true",
     "environment": null,
     "pipeline_id": "12345",
     "job_id": "67890"
   }
   ```
   y lo mete en la env var `VAULT_ID_TOKEN`.
2. GitLab resuelve `secrets:`. Hace `POST` a Vault en `auth/jwt-gitlab/login` con el JWT y el `role=checkout-prod-reader`.
3. Vault valida la firma del JWT contra el JWKS público de GitLab, valida que `aud == https://vault.example.com`, valida que `project_path/ref/ref_protected` coinciden con los `bound_claims` del rol, y emite un token de Vault de 15 min.
4. GitLab usa ese token para hacer `vault kv get kv/data/checkout/prod/db` y `vault kv get kv/data/checkout/prod/tls`.
5. `DB_PASSWORD` se inyecta como env var (`file: false`); `TLS_CERT` se escribe a disco y `$TLS_CERT` contiene el path (`file: true`).
6. El script usa los valores. Al terminar el job, el token de Vault expira solo. Nada queda.

## Qué cambió respecto al patrón "variable de larga vida"

| Antes | Después |
|---|---|
| `VAULT_TOKEN` en Project vars, `protected: true`, `masked: true`. | No existe. |
| Rotación manual del token cada N días. | Rotación automática: cada job es un JWT nuevo. |
| Si el token se filtra, válido hasta rotación. | Si el JWT se filtra, válido 15 min y pinned a `project_path+ref` — fuera del job no sirve. |
| Trust: "quien tenga el token". | Trust: "quien venga del project `acme/platform/checkout` sobre `main` protegido". |

## Pinning: qué pasa si lo relajas

- Si quitas `bound_claims.project_path`: cualquier project del instance de GitLab puede leer `checkout/prod/*`.
- Si quitas `bound_claims.ref`: cualquier branch del project puede leerlo (una feature branch podría exfiltrar).
- Si quitas `bound_claims.ref_protected`: una feature branch con nombre `main` en un fork... no suele importar en GitLab (el fork es otro project y cambia el `project_path`), pero sí si usas `ref: *` + no verificas `ref_protected`.

**Regla**: pinnea `project_path` + `ref` + `ref_protected: true` para secretos de prod. Para dev, acepta más branches pero cambia la policy de Vault a un namespace `dev/`.

## Mapping GHA ↔ GitLab

| GHA | GitLab |
|---|---|
| `permissions: id-token: write` | `id_tokens: { NAME: { aud: ... } }` |
| JWT en `ACTIONS_ID_TOKEN_REQUEST_TOKEN` + `_URL` | JWT en la env var que nombras (`VAULT_ID_TOKEN`) |
| `aws-actions/configure-aws-credentials` | `secrets:` nativo (Vault/AWS SM/GCP SM) |
| `hashicorp/vault-action` | `secrets:` nativo con `vault:` key |

## Siguiente

Pasa a `activities/01-least-privilege-variables` para diseñar el `variables.yml` + `.gitlab-ci.yml` de una org dev/stg/prod aplicando lo visto.
