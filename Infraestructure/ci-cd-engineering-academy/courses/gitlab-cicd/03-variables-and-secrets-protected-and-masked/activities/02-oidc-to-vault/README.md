# Actividad 02 — Eliminar token de larga vida: OIDC a Vault

## 1. Identificación

- **ID:** `gl-03-02-oidc-to-vault`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-03-variables-and-secrets-protected-and-masked`
- **Dificultad:** intermediate
- **Duración estimada:** 85–95 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El proyecto `acme/platform/checkout` tiene hoy un `VAULT_TOKEN` como variable `protected: true, masked: true` del Project. Lo rota un humano cada 90 días. Security te pide eliminarlo: usar un **ID Token** emitido por GitLab por job y federado con Vault vía OIDC/JWT. El resultado:

- Cero tokens de larga vida en la configuración de GitLab.
- Cada job obtiene un JWT efímero firmado por GitLab, lo cambia por un token de Vault de 15 min, lee el secreto, termina.
- Si el JWT se filtra, es inútil fuera del contexto `project_path + ref + ref_protected` por el que fue emitido.

**Importante**: no hay Vault real. No se ejecuta nada. El entregable son 2 archivos (`.gitlab-ci.yml` + `README-INTENT.md`) que un validador comprueba estructuralmente.

**Nunca** uses tokens reales. Audiencias y rutas de Vault son dummy (`https://vault.example.com`, `checkout/prod/db#password@kv`).

## 3. Objetivos

Al terminar deberías poder:

- Declarar un bloque `id_tokens:` con un `aud` apropiado y un nombre de variable claro.
- Declarar un bloque `secrets:` con la key `vault:` apuntando a una ruta remota.
- Diferenciar cuándo usar `file: true` (secretos multilinea o certificados) vs `file: false` (strings cortos).
- Justificar por escrito el pinning del rol de Vault por `project_path`, `ref` y `ref_protected`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 7, 8 y 10).
- Haber recorrido `../../examples/03-secrets-from-vault-with-idtoken/`.
- Herramientas: `bash`, `python3`. Un editor.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gl-03-02
cd /tmp/gl-03-02
```

### 5.2 Escribe `.gitlab-ci.yml`

Un pipeline con **al menos** un job `deploy-prod` que:

- Corra solo en `main` (`rules: - if: $CI_COMMIT_BRANCH == "main"`).
- Declare un bloque `id_tokens:` con **al menos** una entrada cuya `aud` empiece por `https://vault` (ej. `https://vault.example.com`).
- Declare un bloque `secrets:` con **al menos dos** secretos distintos leídos de Vault:
  - Uno con `file: false` (ej. `DB_PASSWORD`), ruta Vault en formato `checkout/prod/db#password@kv` o similar.
  - Uno con `file: true` (ej. `TLS_CERT`), ruta Vault en formato `checkout/prod/tls#cert@kv` o similar.
- Tenga `environment: name: production`.
- **No** debe contener ninguna variable llamada `VAULT_TOKEN`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID` ni cadena similar (el validador prohíbe credenciales de larga vida de Vault en el YAML).

Esqueleto esperado (adáptalo):

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
    - echo "DB_PASSWORD inyectado como env var"
    - echo "TLS_CERT escrito a $TLS_CERT"
    - ./deploy.sh
```

### 5.3 Escribe `README-INTENT.md`

Un documento Markdown que debe contener:

- Un título que mencione **OIDC** o **ID Token** (lo que el validador busca).
- Una sección **`## Antes`** mostrando (en code fence) cómo era el `.gitlab-ci.yml` con `VAULT_TOKEN` como variable protegida/enmascarada.
- Una sección **`## Despues`** (o `## Después`) describiendo cómo quedó con `id_tokens:` + `secrets:`.
- Una sección **`## Pinning en Vault`** que mencione explícitamente las palabras `project_path`, `ref` y `ref_protected`, y qué pasa si se relaja cada uno.
- Mención explícita de **HashiCorp Vault** y de **GitLab**.
- Una declaración explícita de que **no hay credenciales reales** en los archivos (p. ej. una frase: "los valores de aud y rutas son dummy; nunca se commiten secretos reales").

Secciones mínimas requeridas por el validador:

- `## Antes`
- `## Despues` (o `## Después`)
- `## Pinning en Vault` (o similar que contenga `pinning` o `claims`)

### 5.4 Entregables

```
/tmp/gl-03-02/
├── .gitlab-ci.yml
└── README-INTENT.md
```

> **No llames al archivo `ANALYSIS.md`** — convenciones del repo. Usa `README-INTENT.md`.

## 6. Resultado esperado

- `.gitlab-ci.yml` existe, es YAML válido, tiene `id_tokens:` + `secrets:` con las condiciones listadas.
- `README-INTENT.md` existe, tiene las 3 secciones y menciona pinning + claims.
- No hay variable `VAULT_TOKEN` ni similares.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud**: `aud` coherente con el rol de Vault; dos secretos con `file:` distinto; pinning documentado.
- **Seguridad**: ningún valor real, cero credenciales de larga vida en el YAML.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-03-02
```

El validador comprueba estructura; no ejecuta contra Vault.

## 9. Preguntas de reflexión

1. Si tu rol de Vault acepta `bound_claims.project_path = "*"`, ¿qué puede pasar?
2. Un atacante filtra el JWT (`VAULT_ID_TOKEN`) en un log público. ¿Qué daño puede hacer? ¿Durante cuánto tiempo?
3. ¿Por qué usar `file: true` para el TLS cert y no `file: false`?
4. ¿Qué cambia en el `.gitlab-ci.yml` si en vez de Vault usaras GCP Secret Manager?
5. ¿Por qué necesitas también `rules: - if: $CI_COMMIT_BRANCH == "main"` aunque el rol de Vault ya pinnea `ref: main`?

## 10. Extensiones

- Añade un segundo job `deploy-stg` con un `id_tokens:` separado y un rol de Vault distinto (`checkout-stg-reader`), con `aud` o scope distintos.
- Añade al job un `environment: { name: production, deployment_tier: production }` y comenta en `README-INTENT.md` cómo esto expone el claim `environment` en el JWT para poder pinnear por él.
- Escribe un pequeño documento `VAULT-CONFIG.md` con los comandos `vault write` dummy que un operador correría para crear el rol que casa con tu `aud`.

## 11. Limpieza

```bash
rm -rf /tmp/gl-03-02
```

No hay infraestructura que detener.
