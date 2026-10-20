# Lección — Platform patterns y gobierno de costo en GitHub Actions

> Módulo `gha-15`. Nivel: producción. Prerrequisitos: `gha-08`, `gha-09`, `gha-13`.
>
> Esta lección no te enseña *cómo escribir un workflow* (eso lo cubrieron 01–14). Te enseña a tratar GitHub Actions como una **plataforma interna**: con contrato explícito, SLOs, presupuesto, observabilidad y plan de contingencia.

---

## 1. Introducción intuitiva

Hasta aquí fuiste **consumidor** de GitHub Actions. En una org con 50, 200 o 2 000 repositorios dejas de ser consumidor y pasas a ser **platform engineer**: ya no escribes el workflow del día, defines el **contrato** que todos los workflows del día deben cumplir.

El síntoma de que una org **no tiene** este contrato se parece a:

- Cada equipo descubre a pelo cómo hacer SBOM, OIDC, pin a SHA, etc. — y cada uno lo hace mal de forma distinta.
- La factura mensual de Actions crece sin que nadie la mire; cuando alguien mira, nadie puede explicar por qué.
- Un deploy a prod se solapa con otro deploy a prod porque "a mí no me falló el workflow".
- "Esperamos 25 min a que termine CI" es una queja normalizada; nadie sabe cuál es p50 ni p95.
- Cuando GitHub tiene un incidente, 40 ingenieros hacen `/incident` sin plan.

Platform patterns resuelven lo anterior con **cuatro palancas**: contrato obligatorio (required workflows), golden path reutilizable (reusable workflows), presupuesto medible (billing + métricas), y plan de contingencia (DR).

---

## 2. Fundamentos

### 2.1 Platform contract

El **platform contract** de CI/CD es el conjunto de reglas que la org exige a *todo* repo. Opera a tres niveles:

| Nivel | Mecanismo | Ejemplos |
|-------|-----------|----------|
| **Obligatorio** (gate) | Repository rulesets a nivel org con `required_workflows` | `security-scan.yml`, `license-check.yml` deben pasar en PRs a `main`. |
| **Golden path** (recomendado) | Starter workflows + reusable workflows versionados | Cualquier app Python usa `org/.github/.github/workflows/python-ci.yml@v1`. |
| **Blando** (convención) | Docs + CODEOWNERS + lint | Nombres de workflows, uso de `permissions:`, `concurrency:` por workflow. |

**Idea clave**: cuanto más alta la obligatoriedad, mayor el *blast radius* si te equivocas. Un ruleset mal escrito **bloquea los PRs de toda la org**. Un starter workflow mal escrito solo molesta a quien lo escoge.

### 2.2 Required workflows (vía rulesets)

El mecanismo moderno es un **repository ruleset** a nivel org/enterprise con regla `required_workflows`. Cuando se evalúa un push o PR a una rama cubierta, GitHub exige que un check de un workflow específico (`owner/repo/.github/workflows/file.yml@ref`) esté presente y pase. Reemplaza al modelo clásico de "required status checks" dentro de branch protection, con dos ventajas:

- Se define una vez a nivel org y se aplica a N repos vía selector (nombre, visibilidad, propiedades custom).
- El `ref` del workflow es parte del contrato: si lo bajas a `@main` sin pin, el contrato se mueve bajo tus pies.

### 2.3 Starter vs. reusable

- **Starter workflow**: plantilla que GitHub ofrece al usuario al crear un workflow nuevo. **Se copia** al repo. Divergen con el tiempo.
- **Reusable workflow** (`on: workflow_call`): se **invoca** desde otros workflows con `uses:`. La versión queda bajo tu control; los consumidores pueden pinnear.

Regla operativa: starter solo para *bootstrap* (quiero que empiecen con *algo*). Para contrato real, **reusable workflow** pinneado y, si es realmente obligatorio, exigido vía ruleset.

### 2.4 Versionado de reusables: patrón `vN` + SHA

Convención robusta (análoga a cómo versionan `actions/checkout` y amigos):

```
org/.github
  .github/workflows/python-ci.yml     ← fuente única
  tags:
    v1  (mutable, mueve al último SHA de la major 1)
    v1.3.2  (inmutable)
    sha  ba12...   (inmutable, lo que viste en Dependabot PRs)
```

- Los consumidores declaran `uses: org/.github/.github/workflows/python-ci.yml@v1`.
- Tú (platform) mueves `v1` al nuevo SHA cuando ya validaste no romper.
- Un consumidor **paranoico** pinnea a SHA y Dependabot le abre PRs cuando `v1` se mueve.
- Breaking changes = **`v2`**. Nunca romper semántica dentro de una major.

### 2.5 Políticas de concurrency a nivel org

`concurrency:` es por workflow; a nivel plataforma, lo que haces es **convención obligatoria**:

- Workflows de deploy: `concurrency: deploy-${{ github.ref }}` con `cancel-in-progress: false` → cola.
- Workflows de CI de PR: `concurrency: ci-pr-${{ github.ref }}` con `cancel-in-progress: true` → ahorra minutos al rebajar pushes rápidos sucesivos.

Esto no es un gate técnico (GHA no te obliga): es un **lint** que corre en el ruleset o en el reusable workflow que todos usan.

### 2.6 Billing: la unidad es *runner-minute*

Fórmula canónica (hosted):

```
runner_minutes_cobrables =
    sum_over_runs( duration_minutes * sku_multiplier )
```

Multiplicadores públicos (hosted estándar, al momento de escribir — **verificar siempre en billing docs oficiales**):

| Runner | Multiplicador |
|--------|---------------|
| Linux (ubuntu-*)   | ×1 |
| Windows (windows-*)| ×2 |
| macOS (macos-*)    | ×10 |

**Larger runners** (p. ej. `ubuntu-latest-16-core`) tienen su propio precio por minuto por tier; no se expresan como múltiplo del ×1 estándar. Trátalos como SKU aparte.

Repos **públicos** con runners hosted estándar: minutos gratis. Repos **privados**: tienes una bolsa mensual incluida en el plan y lo que excede se cobra. Es importante entender que el **cobro se reporta por repo**, pero la **bolsa es por org** (y existen limits por repo configurables).

**Storage que también cuesta**:
- **Actions cache**: 10 GB por repo (hard-limit; GitHub evicta LRU al exceder).
- **Artifacts**: contratados en GB-mes; retención por defecto 90 días (configurable).
- **GHCR**: por GB-mes para privados.

### 2.7 Métricas que importan

| Métrica | Qué cuenta | Para qué sirve |
|---------|-----------|----------------|
| **Lead time del pipeline** | Tiempo entre `push` y `success` en `main` | DORA; detecta pipelines dolorosos. |
| **Duración p50/p95 por workflow** | Percentiles sobre runs completados | p50 orienta promedio; p95 refleja la cola larga (que es la que genera queja). |
| **Tasa de éxito** | `success / (success+failure)` | <95% → o la rama está rota o el pipeline es flaky. |
| **Flakiness** | reruns que cambian de resultado | Mide tests inestables. |
| **Runner-minutes/día por workflow** | Suma de `duration × multiplier` | Dónde se va la plata. |

Las obtienes de `GET /repos/{o}/{r}/actions/runs?per_page=100&...` y `GET /repos/{o}/{r}/actions/runs/{id}/timing` o directamente desde webhook `workflow_run` → sink.

### 2.8 Observabilidad: webhook → sink

Hay dos vías:

1. **Pull**: cron que llama a la REST API y escribe a tu almacén. Simple, pierde granularidad fina, cuesta rate-limit.
2. **Push**: webhook `workflow_run` / `workflow_job` apuntando a un receptor propio (Lambda, Cloud Run, `webhook-relay`) → BigQuery / Datadog / Grafana.

Push escala mejor y da latencia baja; requiere infra propia. Para una org pequeña, pull cada 15 min es suficiente.

### 2.9 Self-hosted vs. hosted (TCO, no tarifa)

Comparación honesta:

```
+---------------------+-----------------------+-------------------------+
|                     | Hosted (GitHub)       | Self-hosted (ARC)       |
+---------------------+-----------------------+-------------------------+
| Precio por minuto   | Fijo por SKU          | ~coste K8s + ops        |
| Elasticidad         | Instantánea           | Depende de autoscaling  |
| Mantenimiento       | 0                     | Equipo platform         |
| Imagen customizada  | Larger runners payasos| Total control           |
| Blast radius seguro | Aislado por GitHub    | Compartido en tu infra  |
| Secretos / red int. | Difícil (OIDC o tunel)| Trivial                 |
| DR si GitHub cae    | Sin ejecución         | Igual: control plane GH |
+---------------------+-----------------------+-------------------------+
```

Regla: **empieza hosted**. Pasa a self-hosted/ARC cuando una de estas sea cierta: necesitas acceso a red privada; tu workload no cabe en SKUs hosted (p. ej. GPU, 64 cores); o el gasto hosted es >>> coste operativo medido (no estimado) de ARC.

### 2.10 Disaster recovery: ¿qué pasa si GitHub cae?

Importante: aun con self-hosted runners, el **control plane es GitHub**. Si la API de Actions está caída, no se encolan jobs.

Qué puedes hacer *antes*:

- **Builds reproducibles fuera de GHA**: `make build`, `docker build` deben correr en local y en cualquier runner Linux.
- **Imágenes y binarios inmutables** publicados: si ya tienes `v1.2.3` en GHCR, puedes redesplegarla sin pipeline.
- **Deploy via GitOps** (ArgoCD/Flux lee el repo): si tienes la imagen en el registry, Argo redeploya sin GHA.
- **Runbook de hotfix sin GHA**: `git tag` + `docker push` + `kubectl set image` manual, con quién tiene permisos.
- **Comunicación**: alguien monitoreando `githubstatus.com` y canal #sev formado.

Qué **no** puedes hacer: `gh api`, mergear PRs, mover tags en el repo remoto. Si esos son parte del hotfix, tu runbook ya está roto.

---

## 3. Contexto histórico

- 2019 — Actions GA. Branch protection classic + required checks por nombre.
- 2021 — Reusable workflows.
- 2022 — Required workflows (modelo original, deprecated).
- 2023 — **Repository rulesets** con `required_workflows` (modelo actual) + larger runners.
- 2024+ — Properties de repo para selectors, enterprise rulesets, mejoras a billing dashboard.

Lección histórica: el contrato de plataforma **ha migrado tres veces** su mecanismo. Si lo codificas en Terraform/GH Provider en vez de clics en UI, la migración duele mucho menos.

---

## 4. Funcionamiento interno

### 4.1 Evaluación de un ruleset con `required_workflows`

Cuando llega un evento (push a rama cubierta o PR dirigido a ella):

```
PR open --> ruleset engine
             │
             ├─ ¿la ref está cubierta por el ruleset?         (branch filter)
             ├─ ¿el actor está en bypass list?                (si sí, no gatea)
             ├─ para cada required_workflow:
             │     resolver owner/repo/path/file.yml @ ref
             │     ¿el workflow corrió en este SHA?           (sí → check pass)
             │                                                (no → pide run)
             └─ no se puede mergear hasta que todos los required pasen
```

El `ref` del workflow decide **qué versión** se exige. Si usas `@main`, cambiar el main de ese repo cambia el contrato de toda la org sin PR en los repos consumidores — a veces lo quieres (parche urgente), a veces no.

### 4.2 Cómo se calcula un runner-minute

El reloj corre desde que el job *empieza a ejecutarse* en el runner hasta que termina — **no** incluye el tiempo en cola. Se redondea al **minuto superior** por job y se multiplica por el SKU.

```
job A: 3m 10s en ubuntu-latest  → 4 min × 1  = 4 min cobrables
job B: 3m 10s en macos-latest   → 4 min × 10 = 40 min cobrables
job C: 3m 10s en ubuntu-latest-16-core → tarifa de SKU larger
```

### 4.3 Scope de cache (10 GB por repo)

El cache de `actions/cache` tiene *scope por rama + key*:

- Un `restore` en una PR puede leer el cache de **su rama** o del **default branch**.
- Un `restore` en `main` lee solo caches de `main`.
- Al **exceder 10 GB** por repo, GitHub elimina entradas LRU — no te lo notifica en logs.

Consecuencia operativa: una org con repos monorepo + ramas largas + caches grandes degrada rendimiento sin señal clara. Monitorizar `actions/cache` stats es parte del platform contract.

---

## 5. Ejemplo mínimo

Un **ruleset** mínimo (JSON) que exige un reusable workflow en PRs a `main`:

```json
{
  "name": "ci-contract-min",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": { "required_approving_review_count": 1 }
    },
    {
      "type": "workflows",
      "parameters": {
        "workflows": [
          {
            "repository_id": 1234567,
            "path": ".github/workflows/security-scan.yml",
            "ref": "refs/heads/main"
          }
        ]
      }
    }
  ]
}
```

Aplicado con:

```bash
gh api -X POST /orgs/ACME/rulesets --input ruleset.json
```

Un **reusable workflow** mínimo que vive en `org/.github`:

```yaml
# .github/workflows/security-scan.yml
name: security-scan
on:
  workflow_call:
    inputs:
      python-version: { type: string, default: "3.12" }
permissions:
  contents: read
  security-events: write
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
      - run: pip install bandit
      - run: bandit -r .
```

Consumidor en cualquier repo de la org:

```yaml
name: ci
on: [pull_request]
jobs:
  security:
    uses: ACME/.github/.github/workflows/security-scan.yml@v1
```

---

## 6. Implementación progresiva

1. **Semana 0**: audita gasto actual (billing dashboard) y top 10 workflows por minutos.
2. **Semana 1**: publica 1 reusable workflow golden-path (CI de la stack dominante) con tag `v1`.
3. **Semana 2**: convence (no obligues) a 3 repos piloto; mide p95 antes/después.
4. **Semana 3**: pasa 1 workflow (p. ej. `security-scan`) a *required via ruleset* con bypass para el equipo platform.
5. **Semana 4**: activa webhook → sink mínimo (BigQuery dataset + tabla).
6. **Mes 2+**: SLOs declarados (p. ej. `p95 CI < 10 min, success-rate ≥ 97%`), revisión mensual, review triggers escritos.

---

## 7. Aplicación profesional

- **Como platform engineer**: tu artefacto es el *contract*. Repo `org/.github` + repo `org/platform-rulesets` versionados en Terraform.
- **Como tech lead de producto**: consumes el contrato; pinneas los reusables a SHA en repos sensibles; haces lobby para cambios al contrato.
- **Como SRE**: operas los runners self-hosted/ARC si existen; alertas sobre p95 y runner-minutes.
- **Como finanzas/eng-ops**: lees el dashboard de minutos por workflow; conectas gasto a equipo (CODEOWNERS → cost center).

---

## 8. Trade-offs

| Decisión | A favor | En contra |
|----------|---------|-----------|
| Required workflow obligatorio | Garantía uniforme | Bloqueo global ante bug del reusable |
| Reusable @v1 (mutable) | Updates automáticos | Puede introducir regresión silenciosa |
| Reusable @SHA (inmutable) | Reproducible, auditable | Requiere Dependabot y disciplina |
| Self-hosted (ARC) | Barato a volumen, red interna | TCO oculto, blast radius |
| Hosted larger runners | Zero-ops, elástico | Caro, sin personalización |
| Webhook sink propio | Baja latencia | Infra adicional |
| Pull API por cron | Nada que mantener | Rate-limit, pierde datos |

---

## 9. Errores frecuentes

1. **Pinnear reusable a `@main`**: tu platform repo rompe los PRs de 200 repos a la vez.
2. **Olvidar el multiplicador macOS ×10**: una matriz con `[ubuntu, windows, macos]` ×3 Python no son 9 minutos, son *30 minutos cobrables* por versión.
3. **Caches > 10 GB sin monitorear**: hit-rate cae; nadie entiende por qué CI es más lento.
4. **Required workflow sin bypass para platform**: cuando el reusable rompe, no puedes mergear el fix al propio reusable porque exige pasar el reusable roto.
5. **Confundir cobro con bolsa**: ves repo A cobrando 10 000 minutos y culpas al equipo A — pero la bolsa org se agotó por workflows de org, no de repo A.
6. **`cancel-in-progress: true` en deploy**: cancelas el deploy a prod a la mitad al mergear otro PR; patrón para romper producción.
7. **Starter workflow como contrato**: nadie recibe tus fixes; divergen y la "golden path" es ficción.
8. **No tener runbook de GitHub-outage**: durante un sev, el equipo improvisa.

---

## 10. Buenas prácticas

- **Infra-as-code el platform contract**: rulesets, custom properties y permisos a `GITHUB_TOKEN` por workflow en Terraform (`integrations/github` provider) o Pulumi.
- **Convención de tags en reusables**: `vN` mutable + `vN.M.P` inmutable + SHA. Documentado en el README del repo `org/.github`.
- **SLOs declarados**: p95, success-rate, lead-time; review mensual; **review triggers** que fuerzan refactor del contrato.
- **CODEOWNERS** del repo platform = equipo platform con 2 approvals.
- **Dependabot** para actions y para reusables.
- **Dashboard mínimo**: duración p50/p95 por workflow, minutos por SKU, caches aged out, PRs bloqueados por required workflow.
- **Chaos drill trimestral**: "GitHub cae 2 h". Alguien juega al oráculo y respondes el runbook. Mide tiempo a hotfix sin GHA.
- **Shared responsibility matrix** publicada: qué hace platform, qué hace el equipo de producto.

---

## 11. Ejercicios recomendados

1. Toma el billing CSV de tu org (o uno sintético con 10 repos × 30 días). Calcula los 5 workflows más caros.
2. Diseña el ruleset JSON que exigiría un `license-check.yml` en todos los repos privados sin tocar los públicos.
3. Escribe el runbook "GitHub Actions down 2 h, debo deployar hotfix" para tu stack real.
4. Mide hit-rate de tu `actions/cache` principal con la API; descubre si estás sobre los 10 GB.
5. Convierte tu CI principal en un reusable workflow con tag `v1` y pinnea un repo cliente a SHA.

---

## 12. Evaluación

Responde sin consultar:

1. ¿Cuál es la diferencia práctica entre un `required_workflows` dentro de un ruleset y los *required status checks* de branch protection classic?
2. ¿Por qué `v1` apunta al último SHA de la major y qué pasa si lo pinneas a `@main` directamente?
3. Un workflow usa `strategy: matrix: os: [ubuntu-latest, windows-latest, macos-latest]`, cada job dura 5 min reales. ¿Cuántos runner-minutes cobrables son?
4. ¿Qué consume espacio en el límite de 10 GB por repo del cache y qué pasa al excederlo?
5. ¿Dónde pondrías `cancel-in-progress: true` y dónde `false`, y por qué?
6. Mencionas tres cosas que puedes hacer para que un deploy a prod sea posible aun con GitHub Actions caído 2 h.
7. ¿Cuándo tiene sentido self-hosted/ARC y cuándo es pura complejidad extra?
8. Nombra una métrica de pipeline con un umbral que, de incumplirse, dispare revisión del platform contract.

---

## Referencias

Ver `../resources/links.md`.
