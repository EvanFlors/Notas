# Lección: GitHub governance and automation

> **ID:** `gh-12-github-governance-and-automation` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `gh-07-collaboration-prs-and-review`, `gh-08-workflows-trunk-vs-gitflow`.

---

## 1. Introducción intuitiva

Imagínate esta escena. Tu equipo decidió **trunk-based development** con PRs de 1–2 días y un reviewer humano antes de merge. Perfecto en teoría. Lunes por la mañana, un dev con prisa hace `git push origin main` directo porque "era un hotfix de una línea". Rompe producción a las 10:00. En el postmortem alguien dice: *"habíamos acordado no pushear directo a main"*. El acuerdo era real; el **enforcement**, no. Esa es la diferencia que cubre este módulo.

**Gobernanza** en GitHub es el conjunto de controles que convierten acuerdos de equipo en **invariantes** que la plataforma rechaza violar: no se puede pushear a `main`, un PR exige dos aprobaciones del team `platform`, los deploys a `production` esperan 10 minutos y requieren OK humano, un workflow sólo puede asumir un rol en AWS si proviene de la rama `release/*`. Sin esto, cualquier política es una línea en un README que todo el mundo olvida bajo presión.

En paralelo, **automation** es cómo la plataforma deja que agentes no-humanos (bots, pipelines, scripts) actúen con la *mínima* identidad necesaria: no un PAT eterno con `repo` scope, sino un **installation token de GitHub App de una hora** o — mejor — una credencial de cloud emitida por **OIDC** que vive 15 minutos y nunca pasa por un `secrets.FOO`.

Dos ideas, una tesis: **lo que no está enforzado, no existe; lo que no caduca, se filtra.**

---

## 2. Fundamentos

### 2.1 El triángulo organización / repo / usuario

GitHub organiza el acceso en tres planos:

```
  ┌───────────── enterprise (opcional, SSO/SAML, policies cross-org) ────────────┐
  │                                                                              │
  │   ┌──────── organization ────────┐    ┌──────── organization ────────┐       │
  │   │   members (roles: owner,     │    │                              │       │
  │   │   member, outside collab.)   │    │                              │       │
  │   │                              │    │                              │       │
  │   │   teams ── nested teams      │    │                              │       │
  │   │     │                        │    │                              │       │
  │   │     └── permissions on       │    │                              │       │
  │   │         repositories         │    │                              │       │
  │   │                              │    │                              │       │
  │   │   repos                      │    │                              │       │
  │   │     └── branch rules,        │    │                              │       │
  │   │         rulesets,            │    │                              │       │
  │   │         environments,        │    │                              │       │
  │   │         secrets, actions     │    │                              │       │
  │   └──────────────────────────────┘    └──────────────────────────────┘       │
  └──────────────────────────────────────────────────────────────────────────────┘
```

Las políticas se evalúan **de arriba hacia abajo**: una restricción de la enterprise domina a la org; la de la org domina al repo. Un ruleset puede vivir en los tres niveles y **superponerse** (ver §4.1).

### 2.2 Teams y roles

Un **team** agrupa usuarios y recibe permisos sobre repos (Read, Triage, Write, Maintain, Admin). Los teams se **anidan** (`platform/sre`, `platform/data`) y los permisos se **heredan**. CODEOWNERS referencia teams (`@org/platform-sre`), no personas, para que la rotación de personal no rompa el enforcement.

Reglas de higiene:
- **Nunca** dar `Admin` directo a personas; va a teams muy chicos y auditados.
- **Outside collaborator** para contratistas o vendors — no se cuentan como seats de la org.
- Toda automatización (bot) se añade como **GitHub App**, no como usuario humano con PAT.

### 2.3 Branch protection *classic* vs Rulesets

Hasta ~2023, la protección de ramas era *classic branch protection*: una por rama, UI only, campos fijos, difícil de evaluar en bulk. En 2023 GitHub introdujo **Rulesets**: reglas evaluables, superponibles, con **bypass controlado**, scope por **pattern** de refs (`refs/heads/release/*`), y audibles por API.

| Dimensión | Classic | Rulesets |
|-----------|---------|----------|
| Scope | 1 rama a la vez | patrón (`main`, `release/*`, `v*`) |
| Superposición | 1 regla por rama | varias reglas se *union-mergean* |
| Bypass | sólo "Allow administrators to bypass" | bypass por **actor** (user, team, app) con nivel (`always`, `pull_request`) y audit log |
| Target | sólo branches | branches **y** tags |
| Evaluación en PR | implícita | explícita via REST `/rulesets/rule-suites` |
| Enforcement states | on/off | **active**, **evaluate** (dry-run con reporting), **disabled** |
| Export/import | no | JSON exportable/aplicable vía `gh api` |

**Importante**: ambas pueden coexistir sobre el mismo repo; GitHub une sus restricciones (la más estricta gana). Para repos nuevos, usa Rulesets.

### 2.4 Environments con approvals

Un **environment** es una abstracción asociada a *deploys* (`job.environment: production` en un workflow de Actions). Soporta:

- **Required reviewers** (hasta 6; users o teams).
- **Wait timer** (0–43 200 min).
- **Deployment branch policy** (sólo refs que matcheen el patrón pueden desplegar).
- **Environment secrets** y **variables** scoped al environment.

Un deploy encolado espera hasta que un reviewer autorizado haga *Approve* en la UI (o vía API). El wait timer corre **después** de aprobación. Esto da ventana para abortar un deploy ya aceptado que empezó a mostrar métricas feas.

### 2.5 Identidades para automatización

Cuatro mecanismos para que algo no-humano actúe sobre GitHub o sobre otros sistemas desde GitHub:

| Mecanismo | Scope | TTL | Para qué sirve |
|-----------|-------|-----|----------------|
| **PAT classic** | per-user, scopes amplios (`repo`, `workflow`, etc.) | hasta "nunca" (configurable) | legacy, **evita** |
| **PAT fine-grained** | per-user, scope **por repo** y permisos granulares | ≤ 1 año | scripts personales |
| **GitHub App** (installation token) | per-install, permisos declarados | **1 h**, auto-renovable | bots productivos |
| **OIDC federation** | per-workflow, claims verificables | 15 min (lado cloud) | Actions → AWS/GCP/Azure sin secretos |

El patrón productivo moderno es: **GitHub Apps** para actuar sobre GitHub mismo, **OIDC** para actuar sobre clouds. PATs quedan para casos ad-hoc.

---

## 3. Contexto histórico

- **2008–2017** — permisos por repo, roles simples (collaborator). Branch protection introducida ~2016 (require PR, require status checks).
- **2017–2020** — expansión de GitHub Apps (reemplazando OAuth Apps para integraciones server-side), CODEOWNERS (2017), GitHub Actions (2019).
- **2021** — PATs *fine-grained* en beta (GA 2022). Introducción de OIDC entre Actions y clouds (sts, Workload Identity Federation).
- **2022** — merge queues en beta.
- **2023** — **Rulesets** GA; empiezan a reemplazar classic branch protection.
- **2024** — enterprise-level rulesets, delegated bypass, mejoras de API para auditar rule evaluation.

La tendencia es clara: **menos credenciales de larga vida, más políticas evaluables como código, más control granular con bypass controlado**.

---

## 4. Funcionamiento interno

### 4.1 Evaluación de rulesets

Cuando llega un push o se abre un PR, GitHub:

1. Resuelve todos los rulesets aplicables al ref (patrón match).
2. Para cada regla aplicable, consulta el **actor** y su lista de bypass.
3. Si el actor **no** está en bypass, la regla se evalúa en estado `active` (bloqueante) o `evaluate` (sólo reporta).
4. Las reglas se **union-mergean**: si ruleset A exige 1 approval y ruleset B exige 2, se exigen 2.
5. El resultado queda en el **rule suite** (consultable vía `GET /repos/{o}/{r}/rulesets/rule-suites/{id}`).

Esto permite flujos como: "sobre `main`, enforcement estricto; sobre `release/*`, el mismo + required signatures; durante la ventana de migración, poner el nuevo ruleset en `evaluate` y leer el audit log antes de pasar a `active`".

### 4.2 Installation tokens de GitHub App

El flujo criptográfico:

```
  ┌─ GitHub App privada ─┐
  │   RSA private key    │
  └──────────┬───────────┘
             │ firma JWT (iss=App ID, exp ≤ 10 min)
             ▼
  POST /app/installations/{id}/access_tokens
             │
             ▼
  ┌────────── access_token ──────────┐
  │ TTL 1h, scope = permisos         │
  │ declarados por la App ∩ otorgados│
  │ por la installation              │
  └──────────────────────────────────┘
             │ Authorization: Bearer <token>
             ▼
      API de GitHub actúa como la App
```

Clave: ni el JWT ni el access token son credenciales de usuario. Rotar la private key invalida futuros tokens pero no los emitidos (hay que esperar su expiración o revocarlos). El installation token **nunca** debe guardarse en `secrets.*`; se obtiene al vuelo dentro del workflow.

### 4.3 OIDC entre Actions y clouds

```
  ┌─── GitHub Actions runner ───┐
  │   id-token: write permission│
  └─────────────┬───────────────┘
                │  (1) solicita OIDC token al token service de GitHub
                ▼
         JWT firmado por GitHub
         claims: repo, ref, workflow, environment, job_workflow_sha, actor...
                │
                │  (2) runner llama STS del cloud con el JWT
                ▼
      ┌── AWS STS / GCP STS / AAD ──┐
      │ valida JWT contra JWKS      │
      │ confirma claims vs trust    │
      │ policy del role             │
      └─────────────┬───────────────┘
                    │ (3) devuelve credencial temporal (15 min AWS)
                    ▼
             AWS SDK en el job usa esa cred.
```

El **trust policy** del lado cloud **debe** restringir claims específicos (`repo:org/repo:ref:refs/heads/main` o `repo:org/repo:environment:production`). Un trust policy mal escrito (sólo `repo:org/*`) convierte el OIDC en una credencial equivalente a un PAT compartido — peor incluso, porque es invisible desde GitHub.

### 4.4 Required signatures

Si un ruleset exige `required_signatures`, GitHub rechaza cualquier push cuyo commit tip no esté **verified** (firma SSH, GPG o Sigstore `gitsign` cuyo signer sea reconocido por GitHub). La verificación ocurre contra las llaves públicas registradas en el perfil del autor (SSH/GPG) o contra la cadena de confianza de Sigstore (gitsign). Detalle extenso en `gh-13`.

### 4.5 Merge queues

Un *merge queue* resuelve el problema de "varios PRs listos para merge pero sólo uno puede estar `up-to-date` con `main` a la vez". GitHub serializa: toma el próximo PR aprobado, lo rebasa (o lo mergea en un *merge group*), corre CI contra ese estado, y mergea si pasa. Convierte N re-runs de CI por el equipo en 1 re-run por PR, eliminando el *push stampede*.

---

## 5. Ejemplo mínimo

Crear un **ruleset JSON** para `main` que exige PR + 1 approval + status check, aplicable con `gh api`.

```bash
mkdir -p /tmp/governance-demo && cd /tmp/governance-demo

cat > ruleset-main.json <<'EOF'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true
      }
    },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "ci/build", "integration_id": null }
        ]
      }
    }
  ],
  "bypass_actors": []
}
EOF

# Validar JSON offline (sin GitHub)
python3 -c "import json; json.load(open('ruleset-main.json')); print('OK: ruleset JSON válido')"

# Aplicarlo (si tienes gh auth y un repo propio):
#   gh api -X POST \
#     repos/OWNER/REPO/rulesets \
#     --input ruleset-main.json
```

Observa: el JSON es **portable y versionable** (vive en tu repo), aplicable idempotentemente, y auditable. Esto es gobernanza-como-código.

---

## 6. Implementación progresiva

### 6.1 De classic a Ruleset

Si vienes de classic branch protection, el mapping típico es:

| Classic | Ruleset equivalente |
|---------|---------------------|
| "Require pull request before merging" | `{ "type": "pull_request" }` |
| "Require approvals: N" | `pull_request.parameters.required_approving_review_count = N` |
| "Dismiss stale pull request approvals when new commits are pushed" | `dismiss_stale_reviews_on_push: true` |
| "Require review from Code Owners" | `require_code_owner_review: true` |
| "Require status checks to pass before merging" | `{ "type": "required_status_checks" }` |
| "Require branches to be up to date before merging" | `strict_required_status_checks_policy: true` |
| "Require signed commits" | `{ "type": "required_signatures" }` |
| "Require linear history" | `{ "type": "required_linear_history" }` |
| "Do not allow bypassing the above settings" | `bypass_actors: []` |
| "Restrict who can push to matching branches" | regla implícita del ruleset (todos quedan bloqueados salvo bypass) |

### 6.2 CODEOWNERS

Un `.github/CODEOWNERS` asigna owners por path:

```codeowners
# Default owner si nada más matchea
*                       @my-org/platform

# Infra as code
infra/                  @my-org/sre
*.tf                    @my-org/sre

# Backend
services/api/           @my-org/backend @alice

# Frontend
apps/web/               @my-org/frontend

# Docs: cualquier miembro del team docs
docs/                   @my-org/docs

# El propio CODEOWNERS es sensible
.github/CODEOWNERS      @my-org/platform-admins
```

Reglas no obvias:
- **El último match gana** (orden en el archivo importa — al revés del `.gitignore`).
- Entries con usuarios/teams **inexistentes** o **sin acceso al repo** se ignoran silenciosamente. Verifica con `gh api repos/OWNER/REPO/codeowners/errors`.
- `require_code_owner_review` sólo tiene efecto si existe un CODEOWNERS **y** la rama está protegida.

### 6.3 Environment con approval

Vía API:

```bash
# Crear/actualizar el environment "production"
gh api -X PUT repos/OWNER/REPO/environments/production -f \
  wait_timer=10 \
  --field "reviewers[]=type=Team,id=<team_id>" \
  --field "deployment_branch_policy[protected_branches]=false" \
  --field "deployment_branch_policy[custom_branch_policies]=true"

# Añadir regla de branches permitidas
gh api -X POST \
  repos/OWNER/REPO/environments/production/deployment-branch-policies \
  -f name='release/*'
```

En un workflow Actions:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production   # dispara approvals + wait timer
    steps:
      - run: ./deploy.sh
```

### 6.4 OIDC a AWS (sin secretos)

Setup (una vez, en AWS):

1. Crear OIDC provider: `token.actions.githubusercontent.com` con thumbprint oficial.
2. Crear IAM role con trust policy restrictivo (ver `examples/03`).
3. En el workflow, `permissions: id-token: write` + `aws-actions/configure-aws-credentials@v4` con `role-to-assume`.

Sin PAT, sin AWS access key en secrets, sin cosas que caducan en años.

### 6.5 Elección de token: una tabla

| Caso | Elección |
|------|----------|
| Script personal que sincroniza issues entre dos repos tuyos | PAT fine-grained |
| Bot que etiqueta PRs en varios repos de la org | GitHub App |
| CI que necesita leer un repo privado del mismo owner | `${{ secrets.GITHUB_TOKEN }}` del propio workflow |
| CI que necesita pushear a **otro** repo | GitHub App (con permisos de contents:write) |
| CI que despliega a AWS | **OIDC** |
| Herramienta Enterprise multi-tenant (vendor) | GitHub App publicada en Marketplace |

---

## 7. Aplicación profesional

### 7.1 Diseño coherente con el workflow (gh-08)

**Trunk-based**:
- Ruleset sobre `main`: PR obligatoria, 1–2 approvals, status checks estrictos, `require_last_push_approval`, dismiss stale, lineal.
- No required signatures al principio — introducir después, con onboarding.
- Merge queue si el equipo supera ~10 PRs/día en el mismo repo.

**GitHub Flow / release branches**:
- Ruleset sobre `main` como arriba.
- Ruleset adicional sobre `release/*`: idem + `required_signatures`, bypass solo `release-manager` team con audit.
- Environment `staging` sin approval, `production` con approval del team on-call.

**GitFlow**:
- Normalmente evitable (ver `gh-08`). Si hay que soportarlo: ruleset separado para `develop`, `release/*`, `hotfix/*` con niveles distintos.

### 7.2 Delegated bypass

Mal:

```json
"bypass_actors": [
  { "actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "always" }
]
```

(Admin siempre puede saltarse todo — invisible salvo audit log.)

Mejor:

```json
"bypass_actors": [
  { "actor_type": "Team", "actor_id": 42, "bypass_mode": "pull_request" }
]
```

(El team `release-managers` sólo puede bypass al mergear PRs; nunca pushear directo.)

### 7.3 Secrets de environment vs repo vs org

- **Org secrets** — comunes a muchos repos (ej. `NPM_TOKEN` publicado por el team de release).
- **Repo secrets** — específicos del repo.
- **Environment secrets** — scoped por env (`PROD_DB_URL` sólo visible en jobs con `environment: production`).

Regla: el **secret más estricto** siempre; nunca duplicar entre niveles.

### 7.4 Audit log y reporting

Las orgs Enterprise exponen audit log por API (`GET /orgs/{org}/audit-log`). Automatiza una exportación semanal a tu SIEM. Para rulesets, usa `rule-suites` para detectar quién hizo bypass y por qué.

---

## 8. Trade-offs

### 8.1 Enforcement estricto vs velocidad

Reglas duras eliminan ciertos pies de bala pero añaden fricción. Mitigaciones:

- **Merge queue** reduce el "mi PR volvió a estar out of date" aunque la rama exija up-to-date.
- **Bypass por team**, no por rol, con audit log revisado.
- Enforcement `evaluate` primero, `active` después (ver §4.1).

### 8.2 Classic vs Rulesets durante migración

Mantener ambos un tiempo es común. Cuidado: la *unión* se aplica. Si classic exige 2 approvals y ruleset exige 1, se exigen 2.

### 8.3 PAT fine-grained vs GitHub App

PAT fine-grained:
- (+) rápido de crear por un dev.
- (+) scoped por repo.
- (–) atado a un usuario (si se va, se filtra con él y hay que rotar).
- (–) máx 1 año.

GitHub App:
- (+) identidad propia (no se va con un empleado).
- (+) installation tokens de 1 h (si se filtra uno, caduca pronto).
- (+) permisos declarados por manifest (auditable).
- (–) curva de setup inicial (private key, webhook URL si quieres eventos).

Para cualquier automatización productiva: **GitHub App**.

### 8.4 OIDC vs secret estático de cloud

OIDC:
- (+) sin secretos long-lived.
- (+) claims verificables (job, env, ref, sha).
- (+) permite políticas finas en la cloud ("solo si viene de refs/heads/main AND environment=production").
- (–) setup inicial no trivial (provider OIDC + trust policy).
- (–) requiere `permissions: id-token: write` en el workflow.

Secret estático:
- (+) trivial.
- (–) secreto compartido que vive meses, lo ve `read:secrets` de la org, se replica en logs si no se cuida.

En greenfield: **OIDC siempre**. Secret estático sólo para providers sin soporte OIDC.

### 8.5 Required signatures: señal real vs fricción

Pro: evita push de identidades suplantadas, da señal real para supply chain.
Contra: onboarding duro (todo dev necesita firmar). `gitsign` (Sigstore) reduce la fricción pero añade dependencia externa. Normalmente se adopta en el momento de endurecer supply chain (gh-13), no en el primer ruleset.

---

## 9. Errores frecuentes

### 9.1 "Mi ruleset no aplica a mis admins"

Causa: enforcement se saltea para admins por configuración implícita de classic, o `bypass_actors` contiene un team del que eres miembro.

Fix: revisar `bypass_actors` del ruleset y la config classic coexistente. Verificar con `GET /repos/.../rulesets/rule-suites/{id}` quién hizo bypass del último push.

### 9.2 "CODEOWNERS no bloquea el PR"

Causas (ordenadas por frecuencia):
1. El ruleset no exige `require_code_owner_review`.
2. El usuario/team en CODEOWNERS no tiene acceso al repo (silencioso).
3. El path no matchea ninguna entrada.

Fix: `gh api repos/OWNER/REPO/codeowners/errors` revela errores silenciosos.

### 9.3 "El environment approval no se dispara"

Causa típica: el job no declara `environment: production` o no hay reviewers listados o el reviewer es el propio actor que ejecutó el workflow (GitHub no permite auto-aprobar deploys por default — hay un setting).

### 9.4 "El trust policy de OIDC permite cualquier repo de la org"

Síntoma: cualquier workflow de cualquier repo de la org puede asumir el role. Es una **credencial compartida de facto**.

Fix: en el trust policy, condicionar sobre `token.actions.githubusercontent.com:sub` con el valor exacto `repo:org/repo:environment:production` o `repo:org/repo:ref:refs/heads/main`. Nunca `repo:org/*` salvo deliberado y documentado.

### 9.5 "Guardé el installation token de la App en secrets"

Lo mataste. El token caduca en 1 h; el secret vive hasta que lo borres. Obtén el token **en runtime** dentro del workflow (acción `actions/create-github-app-token`).

### 9.6 "Hice push a una rama protegida con `--force` y me dejó"

Si fuiste admin y la ruleset tenía bypass para admins con `always`, o si existía classic protection sin "Do not allow bypassing", el push pasó. Audit log tiene registro. Fix: elimina bypass `always`, pasa a `pull_request`.

### 9.7 "Fine-grained PAT no funciona para `gh pr create`"

Algunos endpoints de GitHub aún no están cubiertos por fine-grained PATs. Verifica el error del endpoint; a veces hay que caer a classic PAT o GitHub App. GitHub va cerrando esto con cada release.

---

## 10. Buenas prácticas

- **Toda política vive como código** (JSON de ruleset en el repo, CODEOWNERS versionado, workflow en `.github/workflows/`). Nada en la UI que no esté también en el repo.
- **Enforcement `evaluate` antes de `active`** cuando introduces una regla nueva.
- **Bypass por team, no por rol**, con TTL conceptual y revisión mensual del audit log.
- **CODEOWNERS granular pero sostenible**. Un CODEOWNERS que exige review de 5 teams en cada PR se convierte en no-ops.
- **GitHub App para bots** productivos; PAT fine-grained para scripts personales; **OIDC para clouds**.
- **Nunca** un token con TTL > 90 días si puedes evitarlo.
- **Environment production siempre con approval + wait timer** (aunque sea 1 min); el wait timer es tu botón de aborto.
- **Audit log exportado** a tu SIEM, revisado por humanos.
- **Documenta cada política** con un ADR corto: *por qué esta regla, qué daño previene, cómo se bypasea con control, cómo se migra*.

---

## 11. Ejercicios recomendados

1. **`activities/01-apply-rulesets/`** — guided-lab: escribir un ruleset JSON y aplicarlo (modo `local` por default; `live` si tienes repo).
2. **`activities/02-codeowners-plus-required-reviewers/`** — guided-lab: configurar CODEOWNERS correcto, enlazarlo con ruleset.
3. **`activities/03-github-app-vs-pat/`** — **independent**: ADR eligiendo identidad para un escenario dado.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Diferencias esenciales entre **classic branch protection** y **Rulesets**. Da al menos 3.

**P2.** Un ruleset `A` sobre `main` exige 1 approval. Otro ruleset `B` sobre `main` exige 2 approvals y `required_signatures`. ¿Cuántas approvals exige el merge resultante? ¿Están firmados?

**P3.** Explica el flujo criptográfico para obtener un **installation token** de una GitHub App. ¿Por qué el access_token no se guarda en `secrets.*`?

**P4.** Diseña un trust policy OIDC (seudo-JSON) que permita assumeRole únicamente desde workflows de `my-org/payments-api` en la rama `main` y con `environment: production`.

**P5.** ¿Cuándo elegirías **PAT fine-grained** sobre **GitHub App**, y viceversa? Un escenario de cada.

**P6.** Un dev reporta: "mi PR fue mergeado sin aprobación de code owners aunque la ruleset lo exige". Enumera 3 causas plausibles y cómo verificarlas.

**P7.** Un `environment: production` tiene `wait_timer: 10`. Un deploy pasa approval a las 12:00. ¿Cuándo empieza realmente a correr el job? ¿Qué puedes hacer entre 12:00 y 12:10 si notas algo raro?

**P8.** Justifica (o rebate) la afirmación: *"required_signatures debería activarse en el primer ruleset de main de cualquier repo nuevo"*. Da al menos un argumento a favor y uno en contra.

---

## Referencias

- GitHub Docs — Rulesets. <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets>
- GitHub Docs — About code owners. <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- GitHub Docs — Managing environments for deployment. <https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment>
- GitHub Docs — OIDC in GitHub Actions. <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- GitHub Docs — Creating a GitHub App. <https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps>
- GitHub Docs — About authentication with a GitHub App. <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app>
- GitHub Docs — Personal access tokens (fine-grained). <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- GitHub Changelog — Rulesets GA. <https://github.blog/changelog/>
