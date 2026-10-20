# Lección: Workflows — trunk-based vs GitFlow (y los demás)

> **ID:** `gh-08-workflows-trunk-vs-gitflow` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `gh-07-collaboration-prs-and-review`.

---

## 1. Introducción intuitiva

Un **workflow de branching** es un acuerdo social, no un comando de Git. Git no sabe (ni le importa) si tu rama se llama `feature/x`, `develop` o `release/1.2.0`: todas son punteros móviles al mismo DAG. Lo que decide la **salud operativa** de un equipo no es *qué comandos* usan, sino **cuánto tiempo viven las ramas antes de integrarse** y **cómo se corta una release**.

Dos preguntas te revelan la cultura técnica de cualquier equipo:

1. "¿Cuántas horas pasan entre que empiezo una rama y la mergeo a la línea principal?"
2. "¿Cuántas ramas largas tenéis vivas simultáneamente?"

Si la respuesta a (1) está en **horas** y a (2) es **una** (`main`), haces trunk-based. Si (1) está en **semanas** y (2) incluye `develop`, `release/*` y quizá `env/staging`, haces GitFlow (o un primo).

La investigación de **Accelerate / DORA** (Forsgren, Humble, Kim) muestra una correlación robusta: los equipos de alto rendimiento **integran al menos diariamente** a una única línea principal. No es casualidad: la Teoría de Restricciones aplicada a software dice que *el lote grande siempre es más caro que el lote pequeño*. Un PR de 2000 líneas no es "2 PRs de 1000", es "20 PRs de 100 que se van a atascar entre sí".

Este módulo te enseña a **ver** eso en un DAG, a reproducirlo con Git y a **defender tu elección** con un ADR.

---

## 2. Fundamentos

### 2.1 Terminología precisa

- **Rama efímera** (*short-lived branch*): nace y muere en el mismo día (<24 h). Idealmente horas.
- **Rama larga** (*long-lived branch*): sobrevive días o semanas. `develop`, `release/1.2.0`, `main` son largas.
- **Línea principal** (*trunk*, *mainline*): la rama en la que la *release* se corta. En trunk-based y GitHub Flow es `main`. En GitFlow son dos: `main` (producción) y `develop` (integración).
- **Integración continua (CI)**: cada push se construye y testea. **Esto no es trunk-based todavía**.
- **Trunk-based development (TBD)**: todas las ramas efímeras integran a `main` al menos **una vez al día**, con `main` siempre deployable.
- **Deploy ≠ Release.** *Deploy* es poner bits en producción. *Release* es exponer la funcionalidad a usuarios. Un feature flag las desacopla.
- **Feature flag** (*toggle*): condicional (`if FLAG:`) que decide si una rama de código se ejecuta en runtime. Permite mergear código inacabado sin exponerlo.
- **Merge commit**: commit con 2+ padres que une historias.
- **Fast-forward (FF) merge**: la ref se mueve adelante; no hay commit nuevo.
- **Merge hell**: estado en el que mergear una rama vieja requiere resolver cientos de conflictos y re-testear todo.

### 2.2 La física del merge hell

Un conflicto se produce cuando dos ramas modifican **las mismas líneas** o **tocan la misma estructura** desde el ancestro común. La probabilidad de conflicto crece **cuadráticamente** con:

- líneas tocadas por la rama,
- commits en `main` desde que la rama nació.

Un modelo simplificado: si en tu base de código `C` developers tocan `k` archivos al día y tu rama vive `d` días tocando `n` archivos, la **probabilidad de conflicto** aproxima `1 − exp(−α · n · k · C · d / A)`, donde `A` es el total de archivos activos. Lo relevante no es la fórmula exacta: es que `d` entra lineal — **doblar el tiempo de rama dobla la probabilidad base de conflicto**, y combinado con `n` (ramas grandes tocan más), el efecto es **cuadrático en el peor caso**.

Trunk-based minimiza `d` por diseño. GitFlow, por diseño, empuja `d` hacia arriba (`feature/*` vive hasta aprobación, `release/*` vive durante QA, `develop` acumula semanas).

### 2.3 Lead time to integration

Métrica clave: **tiempo entre el primer commit de una rama y su merge a la línea principal**.

- Alto rendimiento (DORA): **< 1 día**.
- Medio: 1–7 días.
- Bajo: 1 semana a 1+ mes.

Observación empírica repetida en Accelerate: *no es que los equipos buenos integren rápido porque son buenos; integran rápido y eso los hace buenos*. La causalidad corre en ambas direcciones, pero el acto de forzar la integración diaria dispara prácticas que sanean todo lo demás (CI real, tests, flags, trunk estable, revisiones pequeñas).

---

## 3. Contexto histórico

- **1991–2000 — CVS, SVN.** Branching caro, merging aún más. "Trunk" era la única opción práctica; las ramas de release se usaban solo para parches.
- **2005 — Git.** Branching barato (una ref es 41 bytes). Explosión de experimentación en modelos.
- **2008 — GitHub + Pull Request.** La PR se vuelve la *unidad social* de integración.
- **2010 — "A successful Git branching model" de Vincent Driessen.** Nace **GitFlow**: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`. Pensado para productos *shrink-wrapped* (software con versiones mayores, instaladores, soporte paralelo de versiones). Se vuelve dogma en toda la industria por efecto meme.
- **2011 — Scott Chacon publica "GitHub Flow".** Reacción minimalista: una sola rama larga (`main`), PRs cortas, deploy continuo.
- **2014 — Fowler/Humble popularizan trunk-based + feature flags** (y luego *Continuous Delivery*).
- **2016 — "Trunk-Based Development" (Paul Hammant) consolida el término.** Variantes "scaled trunk" para equipos grandes.
- **2016+ — GitLab Flow** como intento intermedio con *environment branches*.
- **2019 — Driessen publica una nota en su propio post** diciendo que **GitFlow fue para su contexto de 2010 y que si haces SaaS con despliegues continuos, no uses GitFlow**. La industria lo ignora en gran medida.
- **2018–2026 — DORA / Accelerate consolidan la evidencia**: trunk-based correlaciona con alto rendimiento; GitFlow correlaciona con bajo. Esto no demuestra causalidad universal, pero sí que el *default* debería ser trunk-based.

---

## 4. Funcionamiento interno

Esta sección no describe comandos nuevos de Git — todos los conoces desde `gh-03`. Describe **cómo cada workflow se materializa en el DAG**.

### 4.1 Trunk-based development

```
     o---o---o---o---o---o---o---o  main
         ^   ^       ^       ^
         |   |       |       |
         |   |       |       └── feat/billing merged same day
         |   |       └────────── feat/dark-mode merged same day
         |   └────────────────── feat/search merged same day
         └────────────────────── feat/user-pref merged same day
```

- Una rama larga: `main`.
- Ramas efímeras `feat/*` nacen y mueren en el día.
- Código "no listo para usuario" vive en `main` **detrás de feature flags** apagadas.
- La release es `main @ HEAD` en cualquier momento (o un *tag* sobre `main`).

### 4.2 GitHub Flow

Idéntico al DAG anterior, pero sin énfasis explícito en flags; típicamente **cada merge a `main` dispara deploy**. Funciona bien si el blast radius de un bug es tolerable (SaaS multi-tenant con rollback rápido). Mal si "deploy" implica un cliente moviendo bits.

### 4.3 GitFlow

```
             feature/auth       feature/search
                  o---o              o---o
                 /     \            /     \
    develop  o-o-------o----------o-------o---o-------o---o  develop
             |                              \         |     \
             |                               \        |      \
             |                                \       |       release/1.1
             |                                 release/1.0.0   o---o
             |                                 o---o          /     \
             |                                /     \        /       \
    main    o--------------------------------o-------o------o---------o  main
                                             v1.0.0  hotfix v1.0.1
                                                     o
                                                    /|
                                                   / |
                                                  /  └──> merged back to develop
```

- **Dos ramas largas**: `main` (producción) y `develop` (integración).
- `feature/*` ramifica de `develop`, merge back a `develop`.
- `release/X.Y.Z` ramifica de `develop` cuando se congela el scope → QA → merge a `main` **y** a `develop`, con tag `vX.Y.Z` sobre `main`.
- `hotfix/*` ramifica de `main` → merge a `main` **y** a `develop`, con tag `vX.Y.(Z+1)`.

**Observa el doble merge**: cada release y cada hotfix merge en dos sitios. Es la fuente #1 de errores operativos ("se olvidó mergearlo a `develop`").

### 4.4 GitLab Flow (con environment branches)

```
    o---o---o---o---o---o  main (dev)
              \       \
               o-------o   pre-production
                        \
                         o production
```

Los environments son **ramas**. Un cambio progresa por *merge forward* (main → pre-prod → prod). Promete gating por entorno. Problema: en la práctica, los equipos **cherry-pickean** entre entornos ("solo esta corrección va a prod, no las otras"), lo que mata la propiedad de "la rama de prod es un prefijo de la de pre-prod". Entonces merges forward empiezan a conflictuar y vuelves al caos.

**Alternativa sana**: una sola rama (`main`), **tagging por entorno** o **GitOps con un repo de deploy separado**. Ver `gh-12` y D8 (GitOps).

### 4.5 Release branches (independiente del modelo)

Una `release/X.Y` que recibe solo parches, usada por equipos que soportan múltiples versiones mayores en producción simultáneamente (bibliotecas, SDK, firmware). Útil **cuando lo necesitas de verdad**; superfluo cuando solo tienes "la versión actual en producción".

### 4.6 Feature flags: la palanca mecánica

```
# Antes (sin flag)
def checkout(cart):
    return legacy_checkout(cart)

# Con flag
def checkout(cart):
    if FLAGS.new_checkout:
        return new_checkout(cart)
    return legacy_checkout(cart)
```

Permite:
- Mergear `new_checkout` a `main` el mismo día que empiezas (sin exponerlo).
- Activarlo por % de tráfico, por usuario, por tenant.
- Apagarlo si algo arde (rollback en segundos sin re-deploy).

Costos reales a reconocer:
- **Deuda de flags**: cada flag es `if/else` que hay que limpiar cuando el feature se consolida. Sin disciplina, el código se vuelve un árbol de condicionales (ver "flag debt").
- **Testing combinatorio**: `N` flags → `2^N` estados; en la práctica solo testeas rutas realistas, pero debes nombrarlas.
- **Infraestructura**: necesitas un *flag service* (LaunchDarkly, Flagsmith, Unleash, OpenFeature, o uno propio simple como `flags.yaml` por entorno).

---

## 5. Ejemplo mínimo

Reproducible en < 5 min: trunk-based con flag "simulado" como variable Python.

```bash
mkdir -p /tmp/tbd-mini && cd /tmp/tbd-mini
git init -q -b main
git config user.name "Demo" && git config user.email "demo@example.com"

cat > flags.py <<'EOF'
FLAGS = {"new_checkout": False, "dark_mode": False}
EOF
cat > app.py <<'EOF'
from flags import FLAGS

def checkout():
    if FLAGS["new_checkout"]:
        return "new"
    return "legacy"
EOF
git add . && git commit -q -m "init: scaffold with flags off"

# Day 1 morning: feature in a short-lived branch
git switch -q -c feat/new-checkout
# Imagine 2h of work; code goes in guarded by FLAGS["new_checkout"]
git commit -q --allow-empty -m "feat(checkout): new flow behind flag (off)"
git switch -q main
git merge -q --no-ff feat/new-checkout -m "merge: feat/new-checkout"
git branch -d feat/new-checkout

# Day 1 afternoon: another feature in parallel, same pattern
git switch -q -c feat/dark-mode
git commit -q --allow-empty -m "feat(ui): dark mode behind flag (off)"
git switch -q main
git merge -q --no-ff feat/dark-mode -m "merge: feat/dark-mode"
git branch -d feat/dark-mode

git log --oneline --graph --all
```

Observa: una sola rama viva (`main`), merges del mismo día, código "incompleto" ya integrado detrás de un flag apagado.

---

## 6. Implementación progresiva

### 6.1 Nivel 0 — Solo trunk, equipo de 1–3

- Push directo a `main` o PRs cortas; auto-merge.
- Sin flags todavía: si algo rompe, revert.
- CI mínimo: lint + tests unitarios en cada push.

### 6.2 Nivel 1 — Trunk + CI real + flags simples

- Branch protection sobre `main`: requiere PR, 1 approval, status checks verdes.
- PRs < 400 líneas idealmente; vida de rama < 1 día.
- `flags.yaml` (o equivalente) por entorno (dev/staging/prod).
- Deploy automático a staging; a prod con click.

### 6.3 Nivel 2 — Trunk + plataforma de flags + canary

- Flag service (LaunchDarkly / Flagsmith / Unleash / OpenFeature).
- Despliegues en canary / blue-green.
- *Trunk-based scaled*: ramas efímeras + feature flags, equipo de 20+ devs commiteando a la misma `main`.

### 6.4 Nivel 3 — GitOps + progressive delivery

- Repo de código y repo de deployment separados (ArgoCD / Flux).
- Argo Rollouts / Flagger para canary automatizado basado en SLOs.
- Progressive delivery: nuevo feature → 1% tráfico → observar error budget → 10% → 50% → 100%.

### 6.5 Casos donde GitFlow (o algo parecido) sí tiene sentido

- Productos *on-premise* con versiones mayores soportadas en paralelo (ej. SDK v2, v3 y v4 en soporte simultáneo).
- Firmware o software embebido con ciclos de release largos y procesos de certificación.
- Software regulado donde cada release requiere evidencia de QA formal sobre una rama congelada.

Aun en esos casos, considera **"trunk-based + release branches"** en vez de GitFlow completo (sin `develop`): mantienes rapidez en `main` y usas `release/*` solo cuando toca cortar.

---

## 7. Aplicación profesional

### 7.1 Rúbrica rápida para elegir workflow

| Pregunta | TBD | GitHub Flow | GitLab Flow | GitFlow |
|----------|-----|-------------|-------------|---------|
| ¿Despliegas al menos a diario? | ✓ | ✓ | ✓ | ✗ |
| ¿Soportas múltiples versiones mayores en paralelo? | ✗ | ✗ | ~ | ✓ |
| ¿Puedes feature-flagear casi todo? | ✓ | ✓ | ✓ | ~ |
| ¿Tus clientes son on-premise con upgrades mensuales/trimestrales? | ✗ | ✗ | ~ | ✓ |
| ¿Equipo grande (20+) commiteando al mismo producto? | ✓ (scaled) | ~ | ~ | ✗ |
| ¿Regulación requiere "versión congelada en QA formal"? | con release/* | con release/* | ✓ | ✓ |

### 7.2 Branch protection asociada

Un workflow sin branch protection es un acuerdo verbal. Lo mínimo (ver `gh-12`):

- `main` requiere PR + status checks + 1 revisor + lineal (opcional) + sin force-push.
- Si trunk-based: *merge queue* a partir de ~15 PRs/día concurrentes.
- Si GitFlow: `develop` y `main` ambas protegidas; prohibir push directo.

### 7.3 Métricas a observar

- **Lead time** (first commit → prod).
- **Deployment frequency** (releases/día).
- **Change failure rate** (% de deploys que requieren rollback/hotfix).
- **MTTR** tras incidente.
- **Branch lifetime** promedio.
- **PR size** (p50, p90).

Si tu `branch lifetime` p50 > 2 días, tu modelo tiende a fallar aunque lo llames "trunk-based".

### 7.4 Migrar de GitFlow a trunk-based

Camino típico:
1. Introducir feature flags en el código *antes* de tocar el workflow.
2. Reducir el scope de `release/*`: solo lo necesario para QA formal.
3. Acortar vida de `feature/*` a < 2 días con PRs chicas forzadas por tooling.
4. Eliminar `develop`: `feature/*` empiezan a ramificar de `main`.
5. Automatizar release con tagging sobre `main`.
6. Retirar `develop`.

Es un proyecto de 3–12 meses, no un `git branch -D develop` de viernes por la tarde.

---

## 8. Trade-offs

### 8.1 Trunk-based vs GitFlow

**TBD**:
- + Lead time muy bajo, feedback rápido.
- + Historia simple de leer y bisectar.
- − Exige disciplina de PRs chicas y feature flags.
- − Testing en flags cuesta.

**GitFlow**:
- + Scope de release claramente demarcado.
- + Natural para múltiples versiones en soporte.
- − Doble merge (release y hotfix a `main` + `develop`) propenso a error.
- − `develop` tiende a acumular estado "casi listo" sin fecha.
- − Latencia alta entre dev y usuario → feedback tardío → decisiones basadas en opiniones no datos.

### 8.2 Feature flags vs ramas largas

**Flags**:
- + Permiten mergear temprano.
- + Permiten rollback instantáneo (apagar flag).
- − Deuda si no se retiran.
- − Testing combinatorio.

**Ramas largas**:
- + "Más simple" en apariencia.
- − Merge hell cuadrático.
- − Rollback = revert de merge → doloroso.

### 8.3 Environment branches vs tags + GitOps

**Env branches**:
- + Modelo visual atractivo.
- − Divergen inevitablemente con cherry-picks.
- − Convierten `main` en 2 líneas de verdad.

**Tags + GitOps**:
- + Una línea de verdad (código).
- + El estado por entorno vive en otro repo (de deployment).
- − Más piezas móviles iniciales.

### 8.4 Merge commit vs squash vs rebase (en TBD)

Ver `gh-07`. En trunk-based lo típico es **squash & merge** por PR: 1 PR = 1 commit en `main`, historia lineal fácil de bisectar. Alternativa: **merge commit** con `--no-ff` para preservar la agrupación de commits de la PR (útil si tus PRs tienen 3–5 commits lógicos que valen la pena preservar).

---

## 9. Errores frecuentes

### 9.1 "Hacemos trunk-based" pero las PRs viven 1 semana

No. Hacéis "GitHub Flow lento". El nombre del modelo no te da sus beneficios; la **duración de rama** sí.

### 9.2 Usar GitFlow para una SaaS web con deploys continuos

Over-engineering. `develop` + `release/*` + `hotfix/*` sirven para "versiones", pero tu SaaS no tiene versiones externas visibles: tiene `main @ HEAD`.

### 9.3 Olvidar mergear `release/*` o `hotfix/*` de vuelta a `develop`

Clásico en GitFlow. Resultado: el hotfix vive en `main` pero no en `develop`, y vuelve a aparecer el bug en la siguiente release.

### 9.4 Environment branches con cherry-pick a producción

Al tercer cherry-pick, `prod` ya no es un prefijo de `pre-prod`. Al décimo, nadie sabe qué está realmente desplegado. Usa tags o GitOps.

### 9.5 Feature flags que nunca se retiran

A los 2 años tienes 500 flags, 450 "ganadoras" permanentemente encendidas, y el código es un árbol de condicionales. Añade a tu DoD: "al cerrar el feature, abrir issue de retiro del flag con fecha".

### 9.6 Confundir *deploy* con *release*

"No podemos mergear este feature porque no lo queremos exponer". Sí puedes: mergealo detrás de un flag apagado. Deploy ≠ release.

### 9.7 Branch protection débil

Si cualquiera puede `git push origin main --force`, no tienes trunk-based, tienes "esperanza-based development".

### 9.8 PRs gigantes "porque este cambio es grande"

Los cambios grandes se dividen con **branch by abstraction** o **feature flags**, no con PRs de 3000 líneas que nadie revisa de verdad.

### 9.9 Elegir workflow por meme ("en mi anterior empresa usábamos X")

Diseña contra tu contexto (ver §7.1), no por nostalgia.

---

## 10. Buenas prácticas

- **Default: trunk-based** salvo justificación explícita.
- **Ramas < 1 día**. Si tarda más, se divide.
- **PRs < 400 líneas**. Idealmente < 200.
- **Branch protection desde el commit 1** del repo (`main` protegida).
- **Feature flags para desacoplar deploy de release**.
- **1 feature = 1 flag; 1 flag = 1 ticket de retiro con fecha**.
- **Tags para releases, no branches** (salvo si realmente mantienes múltiples mayores).
- **Si GitFlow: tooling obligatorio** (`git-flow` CLI o equivalente) para no olvidar los doble-merges.
- **Mide `branch lifetime` y `PR size`**. Lo que no mides se degrada.
- **ADR** para la elección: por qué este modelo *aquí* y bajo qué condiciones lo revisaríamos.

---

## 11. Ejercicios recomendados

1. **`activities/01-simulate-trunk-based/`** — guided-lab: dos features cortas detrás de flags, integradas a `main` el mismo día.
2. **`activities/02-simulate-gitflow/`** — guided-lab: reproducir el ciclo completo (develop + release + hotfix) y notar la fricción.
3. **`activities/03-architecture-decision/`** — **independent**: escribir un ADR eligiendo workflow para un escenario dado.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Define en una frase cada uno: *trunk-based development*, *GitHub Flow*, *GitLab Flow*, *GitFlow*. ¿Qué los distingue?

**P2.** ¿Por qué una rama que vive 3 semanas produce "merge hell" aunque "yo trabaje solo en ella"? Explica mecánicamente.

**P3.** ¿Qué significa "deploy ≠ release" y cómo lo materializa un feature flag? Da un pseudocódigo.

**P4.** Dibuja el DAG de GitFlow para un ciclo: `feature/x` → `develop` → `release/1.0` → `main` (tag `v1.0.0`) + hotfix `v1.0.1`. Marca los commits dobles de merge.

**P5.** ¿En qué escenario trunk-based **falla** o es inadecuado? Da uno concreto y por qué.

**P6.** ¿En qué escenario GitFlow **falla** o es inadecuado? Da uno concreto y por qué.

**P7.** ¿Por qué las *environment branches* con cherry-pick a producción degeneran? ¿Qué alternativa recomendarías?

**P8.** Te asignan a un equipo nuevo (8 devs, SaaS multi-tenant, deploy diario deseado). Diseña su workflow en 10 líneas y defiende la elección en 3 bullets.

---

## Referencias

- **Vincent Driessen — "A successful Git branching model"** (2010, con nota de 2020). <https://nvie.com/posts/a-successful-git-branching-model/>
- **Scott Chacon — "GitHub Flow"**. <https://docs.github.com/en/get-started/using-github/github-flow>
- **GitLab Flow**. <https://docs.gitlab.com/ee/topics/gitlab_flow.html>
- **Paul Hammant — Trunk-Based Development** (sitio canónico). <https://trunkbaseddevelopment.com/>
- **Martin Fowler — Patterns for Managing Source Code Branches**. <https://martinfowler.com/articles/branching-patterns.html>
- **Martin Fowler — Feature Toggles (aka Feature Flags)**. <https://martinfowler.com/articles/feature-toggles.html>
- **Humble & Farley — *Continuous Delivery*** (2010).
- **Forsgren, Humble, Kim — *Accelerate*** (2018). Métricas DORA.
- **DORA State of DevOps reports**. <https://dora.dev/>
- **OpenFeature** (estándar abierto de flags). <https://openfeature.dev/>
- **Driessen 2020 nota retroactiva** sobre cuándo NO usar GitFlow (al pie del post de 2010).
