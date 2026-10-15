# Lección: Environments, approvals y deployment protection

> **ID:** `gha-09-environments-approvals-and-deployment-protection` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `gha-05`, `gha-06`.

---

## 1. Introducción intuitiva

Hasta aquí tus workflows **pueden** desplegar: `on: push` a `main`, un job con `aws s3 sync`, un secret del repo, listo. El problema es que *cualquier cosa que mergea a `main`* dispara el deploy, sin pausa, sin aprobación, sin registro de "quién dijo que sí". En equipos pequeños eso puede estar bien. En equipos con on-call, PCI, SOX, SRE o simplemente con cuidado, no lo está.

GitHub Actions resuelve esto con un concepto llamado **environment**. Un environment es un *recurso de GitHub* (no una línea de YAML) que agrupa tres cosas sobre una fase de deployment:

1. **Secretos y variables** propios de esa fase (p. ej. `PROD_DB_URL`).
2. **Gates de protección** que se evalúan *antes* de que el job corra (reviewers, wait timer, branch policy, protection rules de terceros).
3. **Un registro auditado** (*deployment record*) de cada vez que algo "se desplegó" a ese environment, con quién aprobó, cuándo, y a qué `sha`.

El YAML del workflow solo lo *referencia* con la palabra clave `environment:`. Toda la política vive en el recurso, no en el repo. Esto es contraintuitivo cuando vienes de pensar en "pipeline as code" puro, y es la primera cosa que hay que interiorizar.

```
┌───────────────────────┐   referencia   ┌─────────────────────────┐
│ Workflow YAML         │ ─────────────> │ Environment "prod"      │
│  deploy:              │                │  - reviewers: [...]     │
│    environment: prod  │                │  - wait_timer: 10       │
│    needs: [staging]   │                │  - branch_policy: main  │
│    run: ./deploy.sh   │                │  - secrets: PROD_*      │
└───────────────────────┘                │  - deployment records   │
         │                               └─────────────────────────┘
         │ al ejecutarse el job          ▲
         │ el runner PIDE permiso        │ gh api
         └──────────────────────────────>┘
             (si falla el gate: job queda "waiting")
```

El escenario que vamos a dominar:

```
┌──────┐   push    ┌───────┐  needs   ┌─────────┐  needs+gate   ┌──────┐
│ main │ ────────> │  dev  │ ───────> │ staging │ ────────────> │ prod │
└──────┘           └───────┘          └─────────┘   approve     └──────┘
                   auto               auto         humano+wait   deploy real
```

---

## 2. Fundamentos

### 2.1 Qué es un environment, operacionalmente

Un environment es:

- Un **recurso REST** en `/repos/{owner}/{repo}/environments/{name}`.
- Opcional: *reviewers* (hasta 6 users o teams).
- Opcional: *wait timer* (0–43200 minutos — hasta 30 días).
- Opcional: *deployment branch policy* (dos modos: `protected_branches` o `custom_branch_policies` con patrones).
- Opcional: *custom deployment protection rules* (GitHub Apps instaladas que votan sí/no).
- Namespace propio de **secretos** y **variables**.
- Historial de **deployments** y **deployment-statuses**.

Nada de esto está en tu YAML. El YAML solo dice `environment: prod`. Cuando el runner intenta empezar el job, GitHub:

1. Consulta el recurso `prod`.
2. Crea un `deployment` (API) y un `deployment_status` inicial `queued` o `waiting`.
3. Evalúa los gates. Si fallan, el job queda **esperando** (no corriendo — importante: no consume minutos todavía).
4. Si pasan todos los gates (humanos y automáticos), despierta el job y le entrega el token con los secrets del environment.

### 2.2 Gates: qué ofrece GitHub de serie

| Gate | Qué hace | Cuándo usarlo |
|------|----------|---------------|
| **Required reviewers** | Hasta 6 users/teams; cualquiera aprueba. `prevent_self_review` opcional. | Prod. Operaciones destructivas. |
| **Wait timer** | Espera N minutos entre que el job se encola y empieza. | "Cool-off" para cancelar deploys dudosos; dar tiempo a métricas; evitar deploys en viernes a las 17:59. |
| **Deployment branch policy** | Restringe desde qué refs se puede desplegar. Dos modos: solo *protected branches* o patrones custom. | Impedir deploy a prod desde una rama de feature. |
| **Custom protection rules** | Delega la decisión a una **GitHub App** que vota sí/no vía webhook. | Chequear ventana de mantenimiento, feature flag listo, Sev-1 abierto, etc. |

Importante: los reviewers no tienen que ser los mismos para dev, staging y prod. Es común que dev no tenga ningún gate, staging tenga wait_timer de 2 minutos sin reviewers, y prod tenga 1 reviewer + wait_timer de 5 minutos.

### 2.3 Branch policies: dos modos excluyentes

```
deployment_branch_policy:
  # Modo A — alinearse con branch protection del repo
  protected_branches: true
  custom_branch_policies: false
```

o

```
deployment_branch_policy:
  # Modo B — patrones propios (soporta glob)
  protected_branches: false
  custom_branch_policies: true
  # luego: POST /environments/prod/deployment-branch-policies con cada patrón
  # patterns: ["refs/heads/main", "refs/heads/release/*", "refs/tags/v*"]
```

Son excluyentes: no puedes tener los dos `true` ni los dos `false`. Si pones los dos `false`, cualquier rama puede desplegar (equivalente a no tener policy).

### 2.4 Secretos y variables por environment

Un secret definido en el environment **sobrescribe** uno con el mismo nombre a nivel repo *solo cuando el job declara ese environment*. Esto permite:

- Repo-level `API_KEY=dev-key-xxx` para jobs sin environment.
- Environment `prod` tiene `API_KEY=prod-key-yyy`.
- El job con `environment: prod` ve `prod-key-yyy`.
- Un job sin `environment:` sigue viendo `dev-key-xxx`.

No hay herencia hacia abajo (de org a env), hay **resolución por scope más específico**: environment > repo > org.

### 2.5 El deployment record

Cada vez que un job declara `environment:`, GitHub crea un objeto en la API:

```
POST /repos/{owner}/{repo}/deployments
{
  "ref": "<sha o branch>",
  "environment": "prod",
  "task": "deploy",
  "auto_merge": false,
  ...
}
```

Y luego, a lo largo del ciclo de vida:

```
POST /repos/{owner}/{repo}/deployments/{deployment_id}/statuses
state: queued → waiting → in_progress → success | failure | error | inactive
```

El `deployment_status` guarda `environment_url` (lo pone el workflow con `environment: { name: prod, url: ... }`), `log_url`, `description`, y critical: `creator` del status. Esto es tu **auditoría**: quién/qué/cuándo/a qué sha.

**Dónde se ve**: tab *Environments* del repo, badge *View deployment* en el PR, API `GET /deployments`.

---

## 3. Contexto histórico

- **2020** — GitHub introduce environments como feature paga.
- **2021** — Se abre a repos públicos gratis; agrega required reviewers y wait timer.
- **2022** — Deployment branch policies (patrones custom).
- **2023** — Custom deployment protection rules via GitHub Apps; integraciones con Datadog, ServiceNow, PagerDuty como gates.
- **2024+** — Mejoras de UI (vista de environments), relación con OIDC (claim `environment:` en el token OIDC), queryable deployment history.

Antes de environments, lo que la gente hacía era: una condición `if: github.ref == 'refs/heads/main'` + un secret del repo + "le gritamos a alguien en Slack para que mergée". Hoy ya no.

---

## 4. Funcionamiento interno

### 4.1 Ciclo de vida de un job con `environment:`

```
1. push a main dispara workflow
2. runner reserva slot, GitHub crea run
3. job "deploy" tiene environment: prod
4. GitHub ANTES de asignar runner:
     - POST /deployments con ref=sha, environment=prod
     - POST /deployment_statuses state=waiting
     - evalúa reviewers → notifica, UI muestra "Review deployments"
     - evalúa wait_timer → arranca contador
     - evalúa branch policy → fail inmediato si no matchea
     - evalúa protection rules (apps) → webhook, espera respuesta
5. Mientras tanto el job NO corre, no consume minutos.
6. Cuando TODOS los gates pasan:
     - POST /deployment_statuses state=in_progress
     - GitHub asigna runner, inyecta secrets del env, corre el job
7. Al terminar:
     - El workflow puede POSTEAR status final (success/failure)
     - Si no lo hace explícitamente, GHA lo infiere del resultado del job
```

### 4.2 Por qué el gate es *antes* del job

Si el gate se evaluara *durante* el job (p. ej. como un step que llama a Slack), ya tendrías un runner corriendo, consumiendo minutos, con el token y los secrets *disponibles en memoria*. Un paso previo malicioso ya podría haberlos exfiltrado antes del "approval". Al evaluar *antes*, los secrets del env ni siquiera se materializan hasta que el gate pasa.

### 4.3 Reviewers: semántica real

- "Required reviewers" significa que **al menos uno** aprueba (OR, no AND). Si listas 3 teams, con un miembro de uno basta.
- Si pones un `team`, cualquier miembro del team cuenta.
- `prevent_self_review`: el actor que disparó el workflow (`github.actor`) no puede ser el reviewer.
- La aprobación es *por run*, no por branch. Un segundo push al mismo branch dispara otra evaluación.
- Puedes **rechazar** desde la UI; el job pasa a `failed`.

### 4.4 Interacción con `needs:` y matrices

`needs:` se evalúa normalmente: si `prod` tiene `needs: [staging]`, no se crea el deployment de prod hasta que staging termina OK. Si `staging` falla, `prod` queda `skipped`, no `waiting`.

En matrices (`strategy.matrix`), cada entrada de la matriz **crea su propio deployment**. Si tienes `environment: prod-${{ matrix.region }}`, GHA crea environments distintos (uno por región) — a menudo lo que quieres para multi-region.

---

## 5. Ejemplo mínimo

Un workflow mínimo con tres environments:

```yaml
name: cd
on:
  push:
    branches: [main]

jobs:
  dev:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to dev"

  staging:
    needs: dev
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to staging"

  prod:
    needs: staging
    runs-on: ubuntu-latest
    environment:
      name: prod
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - run: echo "deploy to prod"
```

Y los environments correspondientes (vía `gh api`):

```bash
# dev: sin gates
gh api -X PUT repos/$O/$R/environments/dev

# staging: solo wait_timer
gh api -X PUT repos/$O/$R/environments/staging -F wait_timer=2

# prod: wait + reviewers + branch policy
gh api -X PUT repos/$O/$R/environments/prod \
  -F wait_timer=5 \
  -F "reviewers[][type]=User" -F "reviewers[][id]=<USER_ID>" \
  -F deployment_branch_policy[protected_branches]=false \
  -F deployment_branch_policy[custom_branch_policies]=true
gh api -X POST repos/$O/$R/environments/prod/deployment-branch-policies \
  -f name='refs/heads/main'
```

El workflow es *idéntico* para los tres environments; la diferencia vive en el recurso GitHub.

---

## 6. Implementación progresiva

### 6.1 Paso 1 — Un solo environment sin gates

Añade `environment: dev` a un job existente. Observa que ahora aparece en la pestaña *Environments* y hay un *deployment record* por cada run. Ya tienes auditoría.

### 6.2 Paso 2 — Secreto por environment

Mueve `API_KEY` de repo-level a environment-level. Verifica que el workflow lo sigue encontrando. Añade otro environment con el mismo nombre de secret y un valor distinto; verifica que cada job ve el suyo.

### 6.3 Paso 3 — Reviewers en prod

Añade tu usuario como required reviewer de `prod`. Haz push: el job queda `waiting`. Apruébalo desde la UI. Observa el deployment record: `creator` del status es tu usuario.

### 6.4 Paso 4 — Wait timer

Añade `wait_timer: 2` a `staging`. Haz push: staging espera 2 minutos antes de correr. Útil para "ventana de arrepentimiento".

### 6.5 Paso 5 — Branch policy

Pon `prod` en `custom_branch_policies: true` y añade el patrón `refs/heads/main`. Prueba desde una rama feature con `workflow_dispatch`: el deployment de prod se rechaza *antes* de evaluar reviewers.

### 6.6 Paso 6 — Describir todo como código

Escribe un `environment-prod.yaml` que describa reviewers, wait, branch policy y la lista de secretos (nombres, no valores). Un script `apply.sh` traduce ese YAML a `gh api`. Esto es lo que pedimos en las actividades.

---

## 7. Aplicación profesional

- **On-call rotation**: lista como reviewers al **team** (no al individuo). PagerDuty rota el shift, GitHub siempre ve el team. Combina con *custom protection rule* que consulta la rotación activa.
- **Deploy ventanas**: wait_timer + Protection Rule (App propia) que lee calendario y falla fuera de ventana.
- **Multi-region**: matriz `region: [us, eu, ap]` con `environment: prod-${{ matrix.region }}`. Cada región tiene su propio deployment record y reviewer (p. ej. SRE regional).
- **Rollback**: no es nativo. Patrón: workflow `rollback.yaml` con `workflow_dispatch` y `environment: prod` — reusa los mismos gates.
- **Compliance (SOX/PCI)**: el deployment record + los reviewers + los secrets scoped son parte del evidence del control de deployment.

---

## 8. Trade-offs

| Decisión | Ventaja | Costo |
|----------|---------|-------|
| Reviewers humanos en prod | Último filtro, control | Latencia, fatiga de aprobaciones, bus factor |
| Solo wait_timer, sin reviewers | Sin fricción humana | Nadie "lee" el deploy; dependes de monitoring |
| Branch policy estricta a `main` | Impide deploys desde ramas | Impide hotfix desde `hotfix/*` salvo que lo añadas |
| Secrets por env | Blast radius pequeño | Más secrets que mantener |
| Protection rules via App | Lógica arbitraria (ventanas, feature flags) | Operar la App, otro punto de fallo |
| Un env por microservicio | Granular | Explosión combinatoria con regiones |

Anti-patrones comunes:
- Reviewer **único** humano (bus factor 1, fatiga). Siempre team.
- `wait_timer: 60` como "revisión": nadie revisa, solo retrasa.
- Reviewer = el mismo que mergea (sin `prevent_self_review`): rubber stamp.
- Branch policy `custom_branch_policies: false` *y* `protected_branches: false`: no hay policy (silencioso).
- Secret de prod también en env `dev` por "comodidad": filtra en logs.

---

## 9. Errores frecuentes

1. **"Mi `environment: prod` no exige nada"** — Es porque el recurso `prod` no existe o se creó sin reviewers. Añadir la línea YAML no crea el environment, solo lo referencia.
2. **"Puse `required_reviewers` en el YAML del workflow"** — No existe esa clave. Los reviewers viven en el recurso, no en el YAML.
3. **Gate que no se dispara** — El job no tiene `environment:`, o tiene un typo (`prod` vs `production`).
4. **"La aprobación no persiste"** — Correcto: es por *run*, no por branch. Cada push vuelve a pedir.
5. **Secrets de env no aparecen** — El job no declara `environment:`, o el nombre no coincide exacto (case-sensitive).
6. **Branch policy no bloquea `workflow_dispatch`** — Sí bloquea, pero el error aparece como "The deployment was rejected"; mucha gente lo lee como "fallo de permiso" y pierde horas.
7. **"Mi `wait_timer` consume minutos"** — No, el job está `waiting`, no `in_progress`. Verifica en la UI si tienes dudas.
8. **Reviewer = `github.actor`** — Si no pones `prevent_self_review`, puedes auto-aprobarte. Rubber stamp.

---

## 10. Buenas prácticas

- **Describe el environment como código** (un `environment-<name>.yaml` versionado) y aplícalo con un script. No lo configures solo por UI: no habría auditoría de cambios al gate.
- **Reviewers = team** (no users), para sobrevivir a rotación y vacaciones.
- Siempre `prevent_self_review: true` en prod.
- Dev sin gates, staging con wait_timer corto, prod con reviewers + wait_timer. Escalado monotónico.
- `environment.url` apuntando al dashboard de ese ambiente (no la home del producto). Facilita verificar post-deploy.
- Branch policy custom con `refs/heads/main` y `refs/heads/hotfix/*`. Nada más.
- Secrets de prod **solo** en `prod`. Dev/staging ni los ven.
- Un **workflow de rollback** separado con `workflow_dispatch` y los mismos gates. No hagas rollback por SSH.
- Dependabot y `release-please` suelen ser `github.actor` del deploy; configurar reviewers que no sean ellos si usas `prevent_self_review`.

---

## 11. Ejercicios recomendados

1. Toma un workflow existente con `environment: prod` y añade el recurso real por `gh api` con un reviewer. Haz push y aprueba.
2. Añade un `wait_timer: 1` a staging. Mide la latencia end-to-end.
3. Cambia `prod` a `custom_branch_policies` solo con `refs/heads/main`. Prueba a desplegar desde `feature/x` con `workflow_dispatch` y observa el rechazo.
4. Modela la cadena dev → staging → prod en un solo workflow con `needs:`. Verifica que si staging falla, prod queda `skipped`.
5. Diseña (en papel) qué reviewers pondrías para un on-call de 24/7 con 4 ingenieros.

---

## 12. Evaluación

Preguntas que deberías poder responder **sin consultar**:

1. ¿Por qué el gate se evalúa *antes* de que corra el job y no durante? ¿Qué pasaría de seguridad si fuese durante?
2. Un compañero dice: "añadí `required_reviewers: [alice]` al YAML del workflow y no funciona". ¿Qué le respondes?
3. Diferencia entre `protected_branches: true` y `custom_branch_policies: true` en `deployment_branch_policy`. ¿Pueden coexistir?
4. ¿Qué información queda registrada en el deployment record? ¿Es suficiente para una auditoría SOX?
5. Diseña la **política de approvals** para un equipo con **on-call** de 4 ingenieros rotando por semana. ¿Pones users o teams? ¿Un reviewer o dos? ¿Wait timer? ¿Qué pasa a las 3am del sábado con un hotfix?
6. En matriz `region: [us, eu, ap]` con `environment: prod-${{ matrix.region }}`, ¿cuántos deployment records se crean por run? ¿Un reviewer puede aprobar los tres a la vez?
7. ¿Cuándo preferirías un *custom protection rule* (GitHub App) sobre un *required reviewer* humano?

---

## Referencias

Ver `../resources/links.md`.
