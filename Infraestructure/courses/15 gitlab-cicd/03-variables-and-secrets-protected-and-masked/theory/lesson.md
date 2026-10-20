# gl-03 — Lección: variables y secretos en GitLab CI/CD

> 10 secciones. Mayoritariamente conceptual. Prerrequisitos: `gl-01`, `gl-02`.

---

## 1. Por qué este módulo existe

En GitHub Actions existen `secrets` y `variables`, con scopes `repository`, `environment` y `organization`. Es un modelo relativamente plano. GitLab, al ser un sistema con **jerarquía de grupos anidables** y con un modelo de **environments de primera clase**, tiene **cinco niveles** de variables y **flags por variable** (`protected`, `masked`, `expanded`/`raw`) que cambian el modelo mental.

Lo que casi siempre sale mal al llegar desde GHA:

1. Se declara una variable "`DEPLOY_TOKEN`" en el Project sin `protected: true`, y una rama de feature arbitraria la puede leer.
2. Se define `AWS_SECRET_ACCESS_KEY` como `variable` en vez de `file` y queda expuesta en `printenv` casual.
3. Se añade `masked: true` a un valor que no cumple los requisitos de longitud/alfabeto y GitLab **no enmascara** (y nadie se entera hasta que aparece en un log público).
4. Se usan **tokens de larga vida** cuando GitLab emite **ID Tokens** gratuitos que resuelven el problema con OIDC.

Esta lección ataca esos cuatro errores.

---

## 2. Jerarquía de scopes

GitLab resuelve una variable mirando, de **menor** a **mayor** precedencia:

```
Instance (admin)
   ↓ hereda
Group (puede anidar subgrupos: cada subgroup hereda del padre)
   ↓
Project
   ↓
Environment-scoped (en Project/Group, con filtro por environment)
   ↓
Pipeline / Trigger / Scheduled (definidas al disparar)
```

**El nivel más específico gana** cuando una variable con el mismo nombre existe en varios scopes. En la práctica:

- Credenciales que un **grupo entero** comparte (ej. token de registry interno) → Group.
- Credenciales por aplicación → Project.
- Credenciales que **solo** valen en `production` → Environment-scoped en el Project con el filtro `environment: production`.
- Overrides puntuales → Pipeline (al disparar manualmente, un maintainer puede inyectar variables).

> **Idea clave:** la jerarquía es el *mecanismo DRY* de GitLab para secretos. Si una variable aparece replicada en 10 proyectos, pertenece al Group.

---

## 3. Tipos: `variable` vs `file`

Cada variable del CI/CD tiene un **tipo**:

- `variable` (default): el valor se inyecta como **env var** en el shell del job.
- `file`: el valor se **escribe a un archivo temporal** y la env var contiene el **path** a ese archivo.

Cuándo usar `file`:

- Keys privadas (SSH, PGP) y certificados: evitas tener que `echo "$VAR" > key.pem` manualmente (lo cual arriesga fugas en logs si olvidas `>` por `>>` o si `set -x` está activo).
- Archivos de configuración de kubectl (`KUBECONFIG`), de gcloud, etc.
- Credenciales JSON de GCP: en vez de inyectar el JSON como string, lo escribes a disco y pasas el path a `GOOGLE_APPLICATION_CREDENTIALS`.

Ejemplo de uso en el job:

```yaml
job:
  script:
    - echo "Key is at $SSH_PRIVATE_KEY"        # path, no el valor
    - ssh -i "$SSH_PRIVATE_KEY" user@host ls
```

---

## 4. Flag `protected`

`protected: true` significa: **solo pipelines corriendo sobre refs protegidas pueden leer esta variable**. Una ref protegida es un branch o tag marcado como *protected* en Settings → Repository.

El patrón canónico:

- `main`, `release/*`, tags `v*` → **protegidos**.
- Branches de feature → **no protegidos**.
- Variables de **producción** (deploy keys, API keys de prod) → `protected: true`.
- Variables de **dev/stg** → `protected: false`.

Qué ocurre si una variable `protected` se pide desde un pipeline no protegido: **la variable simplemente no existe** en el entorno del job. No hay error; el job verá un string vacío. Esto es por diseño (fail-safe), pero puede desconcertar: un `echo $DEPLOY_TOKEN` imprime `""` sin pista de por qué.

> **Diagnóstico típico:** "en main funciona, en mi feature branch da `Unauthorized`" → casi siempre es una variable `protected` que la feature branch no puede leer.

---

## 5. Flag `masked`

`masked: true` significa: **el valor se reemplaza por `[masked]` en los logs del job**. GitLab exige que el valor cumpla:

- Longitud ≥ 8 caracteres (configurable a nivel instance en self-managed).
- Caracteres de un alfabeto restringido: letras, dígitos y un subset de símbolos (`+/=@:.~`). No puede contener saltos de línea.
- No puede ser multilínea (por eso un JSON de GCP **no** es enmascarable como `variable`; va como `file`).

Si el valor no cumple, GitLab **no enmascara** y guarda el valor en claro. En GitLab 16+ aparece una advertencia en Settings → CI/CD; antes era silencioso.

Lo que `masked` **sí** hace: filtra apariciones literales del string en stdout/stderr del job.

Lo que `masked` **no** hace:
- No encripta ni oculta la variable al script (es env var en claro dentro del job).
- No protege contra transformaciones: si tu script hace `echo "${TOKEN:0:4}"`, imprimirá los 4 primeros chars y GitLab no los enmascarará (no coinciden con el valor completo).
- No protege contra base64 o similares: si imprimes `$TOKEN | base64`, la salida base64 no coincide con el string original y pasa en claro.

> **Idea clave:** `masked` es protección contra fugas accidentales en logs, no un control de confidencialidad fuerte. Para eso: no imprimas secretos, nunca.

---

## 6. `expanded` vs `raw`

Default: `expanded: true`. GitLab expande `$VAR` dentro del valor de otra variable antes de inyectarla.

Ejemplo problemático:

```
PRICE=10$       # con expanded: true, GitLab intenta expandir $ y el resultado se trunca.
```

Para valores que contienen literales `$` que no deben expandirse (passwords generadas, templates), usar `raw: true`.

---

## 7. ID Tokens (JWT) — equivalente a OIDC token de GHA

Un **ID Token** es un JWT firmado por GitLab, emitido por cada job que lo declare. Permite a cloud providers y a Vault **confiar** en el job sin que éste tenga credenciales de larga vida.

Flujo mental:

```
Job de GitLab    ──(1) pide ID Token──▶    GitLab emite JWT firmado
    │                                         (claims: project_path, ref, environment, sub, aud...)
    │
    └──(2) presenta JWT a Vault/AWS/GCP──▶   Vault/AWS valida firma (JWKS público de GitLab)
                                              + valida claims (sub, aud, ref...)
                                              + emite credencial de corta vida
```

En el `.gitlab-ci.yml`:

```yaml
deploy:
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  secrets:
    DB_PASSWORD:
      vault: production/db/password@kv
      file: false
  script:
    - echo "DB_PASSWORD vino de Vault"
```

Qué pasa en 4 pasos:

1. GitLab genera un JWT y lo coloca en la env var `VAULT_ID_TOKEN` del job.
2. Resuelve el bloque `secrets:`: usa `VAULT_ID_TOKEN` para autenticarse contra Vault en la ruta `production/db/password@kv`.
3. Vault valida el JWT (`aud` debe coincidir, `sub` debe coincidir con un rol configurado en Vault).
4. GitLab recibe el secreto y lo inyecta como env var `DB_PASSWORD` (si `file: true`, como path a un archivo).

**Claims del JWT** (los que importan para pinning):

- `iss` — issuer (`https://gitlab.example.com` o `https://gitlab.com`).
- `sub` — `project_path:<group>/<project>:ref_type:branch:ref:<branch>`.
- `aud` — audience, controlado por ti vía `aud:` en `id_tokens:`.
- `project_path`, `namespace_path`, `ref`, `ref_type`, `ref_protected`, `environment`, `pipeline_id`, `job_id`, `user_login`, `user_id`.

**Pinning recomendado en Vault/AWS**: por `project_path` **y** `ref` **y** `ref_protected: true` para prod. Nunca aceptar cualquier `sub` del issuer de GitLab — eso es puerta abierta a cualquier proyecto del instance.

---

## 8. Integración con secret managers externos

GitLab soporta nativamente, en el `secrets:` block del job, al menos:

- **HashiCorp Vault** (`vault:` key).
- **Azure Key Vault** (`azure_key_vault:` key).
- **GCP Secret Manager** (`gcp_secret_manager:` key).
- **AWS Secrets Manager** (vía `secrets:` + `aws_secrets_manager:`, estado y disponibilidad del plan a verificar en Fase 4).

El patrón conceptual es el mismo en todos: declara `id_tokens:` con el `aud` que espera el proveedor, luego declara `secrets:` apuntando al path remoto. El motor del CI/CD hace el intercambio.

Alternativa manual: en vez de `secrets:` nativo, ejecutar en `script:` un `vault login -method=jwt` + `vault kv get`. Funciona pero obliga a manejar el handshake tú. **Preferir `secrets:` nativo**.

---

## 9. Riesgos de injection

En GitLab la sintaxis es `$VAR` (shell), no `${{ expr }}` (template como en GHA). Pero el riesgo es equivalente: si inyectas input no confiable en `script:`, puedes ejecutar comandos arbitrarios.

Mal:

```yaml
build:
  script:
    - echo "Building $CI_COMMIT_TITLE"   # título del commit puede contener `; rm -rf /`
```

Bien:

```yaml
build:
  script:
    - printf 'Building %s\n' "$CI_COMMIT_TITLE"   # printf no interpreta el string como código
```

O mejor: **nunca** interpoles `$CI_COMMIT_TITLE`, `$CI_COMMIT_MESSAGE`, el nombre de un MR o cualquier otro input de usuario en una posición donde el shell pueda expandirlo. Pásalos vía stdin o escríbelos a un archivo primero.

---

## 10. Jerarquía recomendada para una org típica

Para una organización con 1 grupo top-level, 3 subgrupos (`platform`, `product`, `data`) y N proyectos por subgrupo:

| Variable | Scope | Flags |
|----------|-------|-------|
| `DOCKER_HUB_READER_TOKEN` | Top-level Group | `protected: false`, `masked: true` |
| `INTERNAL_REGISTRY_URL` | Top-level Group | `protected: false`, `masked: false` |
| `PROD_DEPLOY_ROLE_ARN` | Project | `protected: true`, `masked: false` |
| `PROD_DB_PASSWORD` | **Vault** (no en GitLab) | — (via ID Token) |
| `STG_API_KEY` | Project | `protected: false`, `masked: true` |
| `FEATURE_FLAG_NEW_UI` | Pipeline (manual) | — |
| `GCP_SERVICE_ACCOUNT_JSON` | Project | `type: file`, `protected: true` |

La regla de oro: **cualquier credencial que pueda ser rotada automáticamente (ID Token → Vault/AWS/GCP) no vive como variable estática en GitLab**. Lo que queda en GitLab son metadatos (URLs, ARNs, nombres de rol) y los pocos tokens que no admiten federación.

---

## Siguiente paso

Con la teoría asentada, pasa a los `examples/` (muestran la precedencia, el enmascarado y el flujo OIDC → Vault) y luego a las `activities/`:

- `01-least-privilege-variables` — escribir el `variables.yml` + `.gitlab-ci.yml` para dev/stg/prod.
- `02-oidc-to-vault` — eliminar un token de larga vida reemplazándolo por ID Token + Vault.
