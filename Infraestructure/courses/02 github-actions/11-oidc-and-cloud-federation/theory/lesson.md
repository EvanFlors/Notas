# Lección: OIDC y federación con clouds

> **ID:** `gha-11-oidc-and-cloud-federation` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `gha-05`, `gha-09`.

---

## 1. Introducción intuitiva

Pensemos cómo despliega CI/CD en el patrón "clásico":

```
Humano crea una AWS Access Key (AKIA...) → la pega como secret del repo →
     el workflow la exporta como variable de entorno → la CLI de AWS la usa.
```

Esa Access Key vive **años** si nadie la rota. Si alguien la filtra en un log, en un fork público, en un screenshot, en una paste a un asistente de IA… cualquiera que la lea puede, desde cualquier lugar del mundo, operar la cuenta AWS con los permisos del rol asociado hasta que alguien se dé cuenta y la desactive. En AWS esto se traduce en incidentes públicos cada año: miners de criptomonedas levantando flotas, buckets vaciados, bases de datos exfiltradas.

El modelo **OIDC + federación** elimina la Access Key del juego: ya no hay nada que guardar. Cada run del workflow pide a GitHub un **JSON Web Token (JWT) firmado** que *describe el run concreto* (qué repo, qué rama, qué environment, qué workflow). GitHub lo firma con su clave privada; el cloud (AWS, GCP, Azure) tiene configurada la clave pública de GitHub y una política que dice "si viene un JWT firmado por GitHub cuyo claim `sub` es exactamente `repo:MyOrg/MyRepo:environment:production`, dale credenciales temporales con estos permisos durante como mucho 1 hora". Expirado el run, se acabó.

No es solo "ya no leakeas la Access Key". Es que el cloud ahora **puede diferenciar** entre "este workflow en `main` de este repo" y "este workflow en una PR de un fork". Antes, con la Access Key, ambos tenían el mismo poder; con OIDC, el `sub` del token es distinto y la trust policy puede aceptar uno y rechazar el otro.

Hay una trampa: la trust policy mal escrita rompe toda la propuesta. Si pones el pin solo al owner (`repo:MyOrg/*`), cualquier repo de la organización —incluyendo uno nuevo que un atacante consiga crear— asume el rol. Si solo exiges `aud: sts.amazonaws.com`, cualquier workflow de cualquier repo de **cualquier usuario de GitHub en el mundo** lo asume. Por eso este módulo gira igual alrededor del flujo que de la **auditoría activa** de los trust policies.

---

## 2. Fundamentos

### 2.1 Qué es OpenID Connect (brevísimo)

**OIDC** es una capa de autenticación sobre OAuth 2.0 que estandariza la emisión y verificación de un **JWT** con claims sobre quién hizo qué. Un JWT tiene tres partes separadas por puntos (`header.payload.signature`), codificadas en base64url, y la firma se verifica contra la clave pública publicada por el emisor en su **JWKS** (`/.well-known/jwks.json`), descubierta vía el documento de configuración OIDC (`/.well-known/openid-configuration`).

GitHub actúa como **Identity Provider** (IdP): emite tokens que describen quién corre qué.

El emisor (`iss`) es:

```
https://token.actions.githubusercontent.com
```

El JWKS está en:

```
https://token.actions.githubusercontent.com/.well-known/jwks
```

Lo publica GitHub, lo cachea el cloud. No hay secret compartido: solo la clave pública.

### 2.2 El id-token de GitHub Actions

Cuando un workflow con `permissions: id-token: write` solicita un token, GitHub emite un JWT firmado con claims aproximados a:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "aud": "sts.amazonaws.com",
  "sub": "repo:MyOrg/MyRepo:environment:production",
  "repository": "MyOrg/MyRepo",
  "repository_owner": "MyOrg",
  "ref": "refs/heads/main",
  "ref_type": "branch",
  "environment": "production",
  "workflow": "deploy",
  "workflow_ref": "MyOrg/MyRepo/.github/workflows/deploy.yml@refs/heads/main",
  "job_workflow_ref": "MyOrg/MyRepo/.github/workflows/deploy.yml@refs/heads/main",
  "actor": "alice",
  "run_id": "123456789",
  "run_attempt": "1",
  "exp": 1760000000,
  "iat": 1759996400
}
```

Dos cosas importantes:

- El `sub` **cambia de forma determinista** según el contexto del job. Las variantes más comunes:
  - Job sin `environment`, en rama: `repo:Org/Repo:ref:refs/heads/<branch>`
  - Job con `environment`: `repo:Org/Repo:environment:<env-name>` (**gana** sobre el `ref`).
  - Job disparado por tag: `repo:Org/Repo:ref:refs/tags/<tag>`
  - Job disparado desde un pull request: `repo:Org/Repo:pull_request`
- El `aud` es, **por defecto**, el `iss` (`https://token.actions.githubusercontent.com`), pero las acciones oficiales lo cambian a algo útil para el cloud destino: AWS pide `sts.amazonaws.com`, GCP pide el nombre del Workload Identity Provider.

Puedes personalizarlo:

```yaml
- uses: actions/github-script@v7
  with:
    script: |
      const t = await core.getIDToken('my-custom-audience');
      core.setSecret(t);
```

### 2.3 Flujo OIDC → cloud (vista aérea)

```
┌─────────────────────┐                                 ┌──────────────────┐
│ Workflow run        │                                 │ Cloud IAM / IdP  │
│ (ubuntu-latest)     │                                 │ (AWS / GCP /     │
│                     │                                 │  Entra ID)       │
│  permissions:       │                                 │                  │
│    id-token: write  │                                 │  Trust policy +  │
│                     │                                 │  OIDC provider   │
│                     │                                 │  registrado      │
└──────────┬──────────┘                                 └─────────┬────────┘
           │                                                      │
           │ 1) GET $ACTIONS_ID_TOKEN_REQUEST_URL                 │
           │    (con header Authorization del runner)             │
           │    → JWT firmado por GitHub                          │
           │                                                      │
           │ 2) POST con el JWT:                                  │
           │       AWS:   sts:AssumeRoleWithWebIdentity           │
           │       GCP:   iamcredentials:GenerateAccessToken      │
           │       Azure: /oauth2/v2.0/token (client_assertion)   │
           │ ──────────────────────────────────────────────────▶ │
           │                                                      │
           │ 3) IdP del cloud: verifica firma vs JWKS de GitHub,  │
           │    aplica trust policy (match aud + sub + ...)       │
           │                                                      │
           │                           4) tokens efímeros (≤ 1h) │
           │ ◀────────────────────────────────────────────────── │
           │                                                      │
           ▼
   usar credenciales con CLIs/SDKs (aws, gcloud, az);
   al terminar el job, se descartan.
```

Detalle crítico: en el paso 3, el cloud **vuelve a consultar** periódicamente el JWKS de GitHub (lo cachea unos minutos). Si GitHub rota su clave de firma, el cloud se entera sin intervención manual. Y si alguna vez GitHub publicara una clave distinta, el token con la clave antigua simplemente dejaría de verificar — nada que rotar en tu lado.

### 2.4 Por qué el `sub` es el campo que importa

De todos los claims, el `sub` es el único que **conjuntamente** identifica tres cosas: el repo, el contexto (rama/tag/env), y el valor exacto de ese contexto. Es también el claim al que las trust policies se ancla por convención.

Compara los dos extremos:

| `sub` pin | ¿Quién puede asumir el rol? |
|---|---|
| `repo:MyOrg/MyRepo:environment:production` | Solo jobs del repo `MyOrg/MyRepo` cuyo `environment:` sea exactamente `production`. |
| `repo:MyOrg/*` | **Cualquier repo** dentro de `MyOrg`, cualquier branch, cualquier env, cualquier tipo de job (incluyendo PRs de forks). Catástrofe. |
| (solo `aud=sts.amazonaws.com`, sin `sub`) | **Cualquier workflow de cualquier organización en GitHub** — cross-tenant. Peor que una Access Key sin rotar. |

Un `sub` por `environment:` es más fuerte que un `sub` por `ref:refs/heads/main` porque los environments admiten **required reviewers**, **wait timers**, **deployment branches** y **custom deployment protection rules**. Un atacante que crea una rama `main` en un fork no engaña nada; un atacante que quiere pasar un gate de `environment: production` necesita que alguien le apruebe.

### 2.5 El JWKS, el issuer y el thumbprint (AWS específico)

Al registrar el OIDC provider de GitHub en AWS, históricamente te pedía además de la URL (`https://token.actions.githubusercontent.com`) y la `audience` (`sts.amazonaws.com`), un **thumbprint** del certificado TLS que servía el JWKS. Desde 2023 AWS **ignora en la práctica** ese thumbprint para GitHub (lo valida contra sus propios root CAs) y acepta un valor cualquiera, pero `aws iam create-open-id-connect-provider` sigue pidiéndolo por compatibilidad hacia atrás. Si lo necesitas, el valor comúnmente usado en la práctica es `6938fd4d98bab03faadb97b34396831e3780aea1` (SHA-1 del certificado emisor histórico). Modelo mental: no es un control de seguridad real; es papeleo.

En GCP no hay thumbprint: solo `issuer_uri` + `allowed_audiences`.

En Azure es idéntico: `issuer`, `subject`, `audience`.

---

## 3. Contexto histórico

- **2020 (Nov):** GitHub Actions añade soporte OIDC. Primero AWS; después, el resto de clouds.
- **2021:** Explosión de incidentes públicos de Access Keys filtradas (AWS detecta y notifica, pero el daño ya está hecho antes del aviso). El patrón "secret estático en CI" cae en desgracia.
- **2022:** GitHub promueve OIDC en documentación oficial y aumenta ejemplos. `aws-actions/configure-aws-credentials@v2+` soporta OIDC de primera clase.
- **2023:** AWS deja de exigir que el thumbprint sea realmente el del cert (ver §2.5). Azure habilita Federated Identity Credentials en App Registrations sin requerir una Managed Identity.
- **2024–2025:** Documentación de todos los clouds mueve OIDC a "default recommended path" para CI. Las guías de hardening de GitHub (y herramientas tipo *StepSecurity*, *allstar*) empiezan a flaggear workflows con secrets AWS de larga vida.
- **2025–2026:** Incidentes públicos de trust policies mal escritas (p. ej., pin solo al owner, pin con wildcard) hacen explícito que la federación no basta: la **trust policy correcta** es la pieza.

---

## 4. Funcionamiento interno

### 4.1 Paso a paso HTTP (AWS como ejemplo)

Dentro de un step que pide el id-token, el runner expone dos variables:

- `ACTIONS_ID_TOKEN_REQUEST_URL`
- `ACTIONS_ID_TOKEN_REQUEST_TOKEN`

El flujo completo:

```
┌──────────────┐ 1. GET $ACTIONS_ID_TOKEN_REQUEST_URL?audience=sts.amazonaws.com
│ Workflow     │    Header: Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN
│ step         │ ──────────────────────────────────────────────────────────▶
│              │                                                    ┌───────────────────┐
│              │                                                    │ GitHub Actions    │
│              │                                                    │ ID token service  │
│              │ 2. { "value": "<JWT>" }                           │                   │
│              │ ◀──────────────────────────────────────────────── │                   │
│              │                                                    └───────────────────┘
│              │ 3. POST https://sts.amazonaws.com/
│              │    Action=AssumeRoleWithWebIdentity
│              │    &RoleArn=arn:aws:iam::ACCOUNT:role/github-deploy
│              │    &WebIdentityToken=<JWT>
│              │    &RoleSessionName=GitHubActions-<run_id>
│              │ ──────────────────────────────────────────────────────────▶
│              │                                                    ┌───────────────────┐
│              │                                                    │ AWS STS           │
│              │                                                    │ 1. Decodifica JWT │
│              │                                                    │ 2. Verifica       │
│              │                                                    │    firma vs JWKS  │
│              │                                                    │    (cacheado)     │
│              │                                                    │ 3. Carga trust    │
│              │                                                    │    policy del rol │
│              │                                                    │ 4. Evalúa         │
│              │                                                    │    Condition      │
│              │                                                    │    (aud, sub)     │
│              │                                                    │ 5. Si pasa: emite │
│              │                                                    │    creds temp     │
│              │                                                    └───────────────────┘
│              │ 4. { "AccessKeyId": "ASIA...", "SecretAccessKey": "...",
│              │      "SessionToken": "...", "Expiration": "+1h" }
│              │ ◀──────────────────────────────────────────────── 
│              │
│              │ 5. Las exporta como env (AWS_ACCESS_KEY_ID / ...)
│              │    y las CLIs las usan transparentemente.
└──────────────┘
```

GCP y Azure son isomorfos; cambia el nombre del endpoint y el formato del body:

- **GCP:** `POST https://sts.googleapis.com/v1/token` con `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` y el JWT como `subject_token`. Devuelve un federated token con el que se llama a `iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/<sa>:generateAccessToken` para obtener un access token real de la Service Account.
- **Azure:** `POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token` con `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer` y el JWT como `client_assertion`.

### 4.2 Dónde vive la trust policy

| Cloud | Nombre del recurso | Qué compara |
|---|---|---|
| AWS | `AssumeRolePolicyDocument` del rol | `Condition.StringEquals/StringLike` sobre `token.actions.githubusercontent.com:aud` y `:sub`. |
| GCP | `attribute_condition` del Workload Identity **Provider** + `roles/iam.workloadIdentityUser` **binding** sobre la SA | Expresión CEL (p. ej. `assertion.repository == "MyOrg/MyRepo"`) + principal `principal://.../attribute.repository/MyOrg/MyRepo`. |
| Azure | `federatedIdentityCredentials` de la App Registration | `issuer`, `subject` (exacto, sin wildcards hasta recientemente), `audience`. |

**Las tres hacen semánticamente lo mismo**: comparan claims del JWT contra una expresión preconfigurada. Las trampas también son equivalentes: *demasiado laxo = cross-tenant abuse*.

### 4.3 Interacción con `environment:` del job

Clave sutil que confunde a mucha gente: si tu job declara `environment: production`, el **sub** del JWT emitido **cambia** a `repo:Org/Repo:environment:production` *aunque* el workflow esté corriendo en una rama concreta. El claim `environment:` **sustituye** al `ref:` en la composición del `sub`.

Esto significa que:

- Puedes tener una trust policy pinneada por `environment:production` y permitir el deploy desde cualquier rama (p. ej., branches de hotfix) **siempre que** pasen el environment gate.
- No puedes pinnear "a `main` **y** a `production`" en el mismo `sub`. Si quieres doble barrera, haces el pin en el `sub` + usas `deployment branches` del environment en GitHub.

### 4.4 Lo que se evalúa cuándo

| Momento | Qué se evalúa |
|---|---|
| Al preparar el job | GitHub comprueba `environment:` → aplica deployment protection rules (approvals, wait timers, branch restrictions). *Si no pasa, el job no corre y no se emite ningún OIDC token.* |
| Al pedir el token | GitHub emite el JWT con `sub` compuesto *según* el environment efectivo y el ref. |
| Al llamar a STS | AWS/GCP/Azure comparan el JWT con la trust policy. |
| Al usar las creds | El cloud aplica la *permission policy* del rol/SA (lo que puede hacer una vez autenticado). |

Dos capas, dos funciones distintas: **trust policy** (quién puede asumir), **permission policy** (qué puede hacer una vez asumido). Confundirlas es el error #1 en revisiones.

---

## 5. Ejemplo mínimo

Trust policy AWS **buena**:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:production"
      }
    }
  }]
}
```

Workflow mínimo:

```yaml
name: deploy
on:
  push: { branches: [main] }

permissions: {}      # top-level restrictivo

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
        with:
          role-to-assume: arn:aws:iam::000000000000:role/github-deploy
          aws-region: eu-west-1
      - run: aws sts get-caller-identity
```

Combina: el environment `production` exige approval (configurado en GitHub); el `sub` del JWT va a ser `repo:MyOrg/MyRepo:environment:production`; la trust policy exige exactamente ese `sub`; cualquier otro workflow (otro repo, otro env) falla el `AssumeRoleWithWebIdentity`.

---

## 6. Implementación progresiva

Pasos recomendados para construir el patrón:

1. **Teoría primero.** Antes de tocar la cuenta cloud, haz la actividad `02-review-vulnerable-trust-policy`. Entender qué está mal evita que escribas tu primera trust policy mal.
2. **AWS primero** (sintaxis más declarativa y el cloud más usado en el programa). Haz la actividad `01-federate-with-aws` en `MODE=local` end-to-end: validar sin tocar AWS. Después (opcional) en `MODE=live`.
3. **GCP a continuación.** Workload Identity Federation tiene más piezas (Pool + Provider + binding sobre la SA) pero es más expresivo (CEL). Replica el ejercicio AWS cambiando el cloud.
4. **Azure al final.** Federated Identity Credentials son más simples pero menos documentados en material de CI/CD; úsalo como mini-extensión.
5. **Multi-cloud.** Un mismo workflow puede federar simultáneamente a los tres clouds si cada paso declara `with: audience` adecuada.

---

## 7. Aplicación profesional

### 7.1 Convenciones de nombrado

- Rol IAM: `github-<repo-slug>-<env>` (p. ej. `github-payments-prod`).
- Session name: `GitHubActions-${{ github.run_id }}` para traza en CloudTrail.
- OIDC provider en AWS: uno por cuenta, compartido entre todos los repos (es solo un apuntador al IdP de GitHub).

### 7.2 Permisos del rol (no de la trust)

Aplica mínimo privilegio al rol:

- Rol `-prod`: permisos de deploy a los recursos de prod. **Nunca** `AdministratorAccess`.
- Rol `-staging`: permisos a staging.
- Rol `-ci`: permisos de lectura (describe/get) para checks pre-deploy.

Esto es completamente ortogonal al OIDC — es la "permission policy" clásica.

### 7.3 Variables inyectadas por `configure-aws-credentials`

Después del step, el runner tiene en env:

- `AWS_ACCESS_KEY_ID` (empieza con `ASIA`, no `AKIA` — así es como distingues una creds temporal).
- `AWS_SECRET_ACCESS_KEY`.
- `AWS_SESSION_TOKEN`.
- `AWS_REGION`.

Son **marcadas automáticamente como secrets** por el runner (redacción en logs). No las imprimas tú manualmente a propósito; si las ves claras en un log es que había algún `set -x` fuera de control.

### 7.4 Caducidad

Por defecto `AssumeRoleWithWebIdentity` emite credenciales de **1 h**. Puedes forzar hasta la `MaxSessionDuration` del rol (default 1 h, se puede subir a 12 h), con `role-duration-seconds` en la action. Trade-off: menos renovaciones vs ventana de abuso más larga si el runner se compromete. Keep it short unless demostrablemente necesario.

### 7.5 Revisión en PR

Cuando revisas un PR que toca workflows o trust policies:

- `permissions: id-token: write` **solo** en el job que lo necesita. Si está top-level, pregúntate por qué.
- `role-to-assume` referencia un ARN plausible. Si es un rol con `-admin` o `-root` en el nombre, bandera roja.
- `sub` del trust: ¿incluye `repo:Org/Repo:` con un sufijo específico (`ref:…` o `environment:…`)? ¿O es un wildcard?
- `aud`: `sts.amazonaws.com` para AWS. Si es otro, pide explicación.

### 7.6 Debugging

Si el `AssumeRoleWithWebIdentity` falla, el error de STS *te dice qué condición no matcheó*. Ejemplo:

```
Not authorized to perform sts:AssumeRoleWithWebIdentity: Request ARN is invalid
```

o:

```
Not authorized to perform sts:AssumeRoleWithWebIdentity:
condition "StringEquals":"token.actions.githubusercontent.com:sub":"repo:X:env:Y"
```

Dumpear el JWT crudo (en dev, nunca en prod) para ver el `sub` real:

```yaml
- name: Debug OIDC token (dev only)
  run: |
    IDTOKEN=$(curl -sLS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | jq -r .value)
    echo "$IDTOKEN" | awk -F. '{print $2}' | base64 -d 2>/dev/null | jq .sub
```

---

## 8. Trade-offs

### 8.1 OIDC vs Access Keys

| Dimensión | Access Key (AKIA) | OIDC |
|---|---|---|
| Rotación | Manual, se olvida | No existe |
| Fuga en log | Compromiso de meses | Ventana ≤ 1 h, además marcadas como secret |
| Granularidad | Igual para todos los workflows del repo | Por repo + branch/env |
| Setup inicial | 1 min | 15 min (OIDC provider + rol + trust) |
| Multi-cloud | Igual trabajo por cloud | Igual trabajo por cloud (el patrón se repite) |
| Audit trail | `IAM user` → run | `GitHubActions-<run_id>` → run exacto |

### 8.2 Pin por `ref` vs por `environment`

| | `ref:refs/heads/main` | `environment:production` |
|---|---|---|
| Fuerza | Pin a una branch concreta. Si creas una rama `main` en un fork, no match (`repo:` es distinto). | Pin a un recurso GitHub administrado. |
| Gates | Depende de branch protection del repo. | Approvals, wait timers, deployment branches del env. |
| Flexibilidad | Si deployo desde un hotfix, no funciona. | Deploy desde cualquier rama si pasa el gate. |
| Recomendado para | Builds, pruebas, no-prod. | **Prod**. |

### 8.3 AWS vs GCP vs Azure

- **AWS**: trust policy declarativa en JSON; el modelo es "verifica tú el JWT contra Condition". Simple pero verboso.
- **GCP**: Workload Identity Federation con CEL en el attribute condition — expresivo, puedes escribir lógica. Más piezas (pool + provider + binding sobre SA).
- **Azure**: Federated Identity Credentials por subject exacto; menos expresivo pero muy simple. Útil cuando el workflow siempre viene del mismo `sub`.

### 8.4 "¿Un OIDC provider por repo o uno compartido?"

Uno por cuenta cloud. El provider es un apuntador al IdP de GitHub; es idéntico para todos los repos. Lo que cambia es el **rol** y su trust.

---

## 9. Errores frecuentes

### 9.1 "No se emite id-token"

Síntoma: `aws-actions/configure-aws-credentials` falla con `Could not load credentials from any providers`.
Causa: olvidaste `permissions: id-token: write` en el job (o lo pusiste top-level pero el job redefine `permissions:` sin incluirlo).
Fix: asegúralo *en el job*.

### 9.2 "`Not authorized to perform sts:AssumeRoleWithWebIdentity`"

Causa #1: trust policy no match. Dumpea el `sub` real (ver §7.6) y compáralo con el `Condition` de la trust.
Causa #2: `aud` no match. Si cambiaste `audience` en la action pero no actualizaste la trust, falla.
Causa #3: el `OIDC provider` no está registrado en IAM (o lo está con una URL distinta).

### 9.3 Trust pinneada solo al owner

```json
"StringLike": { "...:sub": "repo:MyOrg/*" }
```

Cualquier repo nuevo de la organización asume el rol. Un atacante que convence a alguien de crear un repo trivial puede asumir prod. **Siempre** pin al repo completo + sufijo.

### 9.4 `StringLike` con wildcard sutil

```json
"StringLike": { "...:sub": "repo:MyOrg/MyRepo:*" }
```

Esto permite **cualquier** sufijo: `ref:refs/heads/main`, `ref:refs/heads/whatever`, `pull_request`, `environment:production`, `environment:dev`… Un PR de un contributor externo con un workflow modificado podría asumir el rol (depende de si tu repo acepta ejecutar workflows de PRs externos, lo cual es otro módulo). Prefiere `StringEquals` o `StringLike` con wildcard *controlado*: `repo:MyOrg/MyRepo:ref:refs/heads/*` (si quieres cualquier branch pero *no* PRs).

### 9.5 `permissions: write-all` top-level

Hace que todos los jobs tengan tokens con todos los scopes, incluyendo `id-token: write`. Innecesario y peligroso. Mantén top-level restrictivo y eleva por job.

### 9.6 Checkout a `pull_request_target` con `id-token: write`

`pull_request_target` corre con secretos y en contexto del repo base. Si lo combinas con `id-token: write` y haces checkout del head del PR sin aislar, un atacante puede exfiltrar el OIDC token. Patrón prohibido en 99% de casos. Ver `gha-13` para el patrón seguro.

### 9.7 Confundir trust policy con permission policy

En revisión, alguien añade a la *permission policy* `"Condition": {"StringEquals": {"...:sub": "repo:Org/Repo:..."}}`. No tiene efecto: la permission policy evalúa el principal ya autenticado (una session del rol), no el JWT. El pin **va en la trust policy** y en ningún otro sitio.

---

## 10. Buenas prácticas

1. **Pin por `environment:` para prod**. Combina con approvals.
2. **Un rol por (repo, env)**. No reutilices `github-deploy` para 20 repos.
3. **Trust explícito con `StringEquals`** siempre que puedas. Usa `StringLike` solo con wildcards controlados y revisa dos veces.
4. **`permissions:` top-level `{}`** o `contents: read`. Eleva por job.
5. **`role-session-name` incluye `run_id`** para traza en CloudTrail.
6. **Audita periodicamente** las trust policies: un script que lista roles y hace diff con un baseline detecta cambios no revisados.
7. **No mezcles OIDC con Access Keys legacy** en el mismo rol / repo si puedes evitarlo; es ruido de auditoría.

---

## 11. Ejercicios recomendados

- Haz `activities/02-review-vulnerable-trust-policy` **antes** que `01`. La exposición a los antipatrones hace que la implementación salga sola.
- Replica la actividad 01 contra GCP (WIF) como ejercicio extra, usando la documentación oficial. Compara el YAML del workflow — es casi idéntico, con otra audience y otra action (`google-github-actions/auth`).
- Audita un workflow público real (en un repo open source conocido). ¿Pinnean por repo+env? ¿Pinnean solo por owner? ¿Mezclan Access Keys con OIDC?

---

## 12. Evaluación

Al terminar debes poder:

- [ ] Dibujar el flujo OIDC paso a paso contra AWS/GCP/Azure.
- [ ] Explicar la diferencia entre trust policy y permission policy.
- [ ] Dado un trust policy, decir si es seguro o vulnerable y por qué.
- [ ] Escribir el pin correcto del `sub` para 3 escenarios: deploy desde `main`, deploy desde `environment:production`, build CI desde cualquier branch (sin env).
- [ ] Describir qué pasa si olvidas `permissions: id-token: write`.
- [ ] Explicar por qué `permissions: write-all` es un problema aunque no "haga daño por sí mismo".

## Referencias

Ver `../resources/links.md`.
