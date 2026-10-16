# plat-11 — Lección: medir la plataforma como un producto

> *"When a measure becomes a target, it ceases to be a good measure."* — Charles Goodhart.

Una plataforma interna sin métricas es un acto de fe. Con las métricas equivocadas, es peor: una fábrica de números bonitos que esconden una plataforma que nadie quiere usar. Este módulo pone orden en qué medir, cómo medirlo y, sobre todo, **qué conversaciones habilitar** con esos números.

---

## 1. Por qué medir una plataforma

Un platform team es un **equipo de producto** interno. Su "mercado" son los stream-aligned teams (ver `plat-01`). Si los stream-aligned pueden elegir *no* usar la plataforma (y en empresas sanas, pueden), entonces la plataforma necesita demostrar su propuesta de valor con la misma evidencia que un producto SaaS: adopción, retención, satisfacción, tiempo-al-valor.

Si solo medimos *outputs del platform team* ("templates publicados", "tickets cerrados"), estamos midiendo esfuerzo, no valor. El esfuerzo sin valor es *waste*. Las métricas correctas separan ambos.

## 2. DORA — las cuatro métricas canónicas

El equipo **DORA** (DevOps Research & Assessment, hoy parte de Google Cloud) publica desde 2014 el *Accelerate State of DevOps Report*. Tras una década de research, consolidó cuatro métricas que, correlacionadas, predicen *performance organizacional*:

1. **Deployment Frequency (DF).** Cuántas veces por unidad de tiempo se despliega a producción. Proxy de *batch size* y de confianza en el pipeline.
2. **Lead Time for Changes (LTC).** Tiempo entre que un commit entra en la rama principal y llega a producción. Proxy de la fricción del delivery pipeline (NO del tiempo de diseño/discovery previo — eso es otra métrica).
3. **Change Failure Rate (CFR).** Porcentaje de deploys que causan un incidente / rollback / hotfix inmediato. Proxy de calidad del release.
4. **Failed Deployment Recovery Time (FDRT).** Mediana del tiempo entre que un deploy fallido causa impacto y se restaura el servicio. (En reportes previos a 2024 se llamaba *Time to Restore Service / MTTR*; DORA renombró para enfocar que la métrica mide **recuperar deploys**, no cualquier incidente de ops.)

### El par velocidad / estabilidad

DORA agrupa las métricas en dos ejes:

- **Throughput (velocidad):** DF + LTC. Más alto = mejor.
- **Stability:** CFR + FDRT. Más bajo = mejor.

La tesis de *Accelerate* es: **los equipos elite son altos en los dos ejes a la vez**. El trade-off clásico "velocidad vs calidad" es un falso dilema cuando se aplica buena ingeniería (CI, trunk-based, feature flags, test automation).

### Buckets DORA (reporte reciente)

| Bucket  | DF                      | LTC                 | CFR       | FDRT         |
|---------|-------------------------|---------------------|-----------|--------------|
| Elite   | On-demand (varios/día)  | < 1 día             | 0–15 %    | < 1 hora     |
| High    | 1/día – 1/semana        | 1 día – 1 semana    | 0–15 %    | < 1 día      |
| Medium  | 1/semana – 1/mes        | 1 semana – 1 mes    | 0–15 %    | 1 día – 1 semana |
| Low     | 1/mes – 1/6 meses       | > 1 mes             | > 15 %    | > 1 semana   |

Los umbrales varían entre reportes; usa los del reporte vigente y cita la edición. **No** inventes buckets propios; perderás la capacidad de compararte con la industria.

## 3. Cómo computar DORA desde eventos reales

En una plataforma madura, los eventos existen:

- **Deployment start / success / failure**: GitHub Actions runs (`workflow_run` webhook), eventos `Sync`/`Succeeded`/`Failed` de Argo CD, releases de GitLab/Jenkins.
- **Commit → merge**: la metadata de Git (merge commit timestamp) o la API de PRs.
- **Incidents**: PagerDuty incidents, Opsgenie alerts, tickets de Jira marcados `incident`.

El patrón canónico:

```
                    ┌──────────────┐
    GitHub webhook  │              │
    Argo CD webhook │  Event bus   │   ──►  Compute job (hourly/daily)
    PagerDuty API   │  (Kafka/SQS/ │        - group by service
                    │   NDJSON)    │        - join commits ↔ deploys
                    │              │        - join deploys ↔ incidents
                    └──────────────┘        - emit metrics
                                                 │
                                                 ▼
                                           Prometheus / BigQuery
                                                 │
                                                 ▼
                                           Grafana / Backstage widget
```

Lo importante no es el stack sino **la calidad del join**:

- Un deploy debe tener `service_id`, `env`, `commit_sha`, `started_at`, `finished_at`, `status`.
- Un incident debe tener `started_at`, `resolved_at`, y **vincularse al deploy** que lo causó (campo `caused_by_deploy_id` o convención por ventana temporal).
- Un commit debe tener `merged_at` y `service_id` (del repo).

Sin estos campos, DORA se vuelve adivinación.

### Fórmulas de referencia

```
deployment_frequency(service, window) = count(deploy where status='success') / window_days

lead_time_for_changes(service, window) = median(
    deploy.finished_at - commit.merged_at
    for each deploy where status='success'
    joined with commits included in that deploy
)

change_failure_rate(service, window) = count(deploy where caused_incident=true)
                                     / count(deploy where status='success')

failed_deployment_recovery_time(service, window) = median(
    incident.resolved_at - incident.started_at
    for each incident where caused_by_deploy_id is not null
)
```

Nota las decisiones implícitas: ventana (típicamente 90 días rolling), scope (por servicio o por organización), definición de "incident" (page vs ticket vs user report).

## 4. SPACE — lo que DORA no mide

DORA mide el **flujo de entrega**. No mide:

- Si los developers están satisfechos.
- Si están colaborando o aislados.
- Si están en flujo o en interrupción constante.
- Si lo que entregan **vale la pena**.

El framework **SPACE** (Forsgren, Storey et al., 2021) nace para rellenar ese hueco. Cinco dimensiones:

- **S — Satisfaction & wellbeing**: NPS interno, burnout, retención, "¿recomendarías este equipo a un amigo?"
- **P — Performance**: ¿lo entregado funciona? bugs post-release, SLO breaches, revenue impact.
- **A — Activity**: PRs abiertos, commits, code reviews. **Esta es la dimensión más fácil de medir y más fácil de abusar** — es activity, no outcome.
- **C — Communication & collaboration**: tiempo de review de PR, calidad de los PRs (comentarios por review), onboarding time, cross-team contributions.
- **E — Efficiency & flow**: time-in-flow, interruption rate, meetings/day, context switches.

Regla de oro de SPACE: **nunca mides una sola dimensión**. Siempre al menos tres, idealmente una cuantitativa + una cualitativa + una de outcome.

## 5. Platform NPS y adoption metrics

### Platform NPS

Una encuesta trimestral a los developers que usan la plataforma. Pregunta canónica:

> *"How likely are you to recommend our internal platform to a new team joining the company? (0–10)"*

- **Promoters (9–10)** − **Detractors (0–6)** = NPS (rango teórico −100 a +100).
- Añade **2 preguntas abiertas**: "¿Qué es lo que más te sirve?" y "¿Qué deberíamos arreglar primero?".
- Cadencia: trimestral. Más frecuente es ruido. Menos frecuente, llegas tarde.

Trampas:

- *Response bias*: los enojados responden, los contentos no. Fuerza respuesta en un canal de alcance (team all-hands).
- *Survivorship bias*: solo mides a quien **ya usa** la plataforma. Entrevista también a quien eligió no usarla.
- *NPS no es un número para contar en el stand-up*: es un número para abrir una conversación. Si lo celebras cuando sube sin leer los comentarios, pierdes su valor.

### Adoption metrics

Las métricas de adopción prueban si la plataforma cumple su promesa:

- **% de servicios registrados en catalog** (del total conocido en la org).
- **% de nuevos servicios creados vía template** (vs clonar un repo a mano).
- **Templates usados / semana** (y breakdown por template: cuál tracciona, cuál no).
- **Recursos self-service provisionados** (DBs, buckets, colas) **sin ticket al platform team**.
- **Time to first production deploy** para un nuevo servicio desde cero (ideal: < 1 día; realista: 1–3 días).
- **% de servicios con scorecard ≥ silver** (ver `plat-10`).

Son métricas de **leading indicator**: si bajan, el impacto en DORA llega 2–3 trimestres después.

## 6. Leading vs lagging indicators

- **Lagging** (resultado consumado): DORA, revenue, churn, incidents.
- **Leading** (predictor): adoption, NPS, template usage, time-to-first-deploy, # de recursos self-service.

Un dashboard de plataforma necesita **ambos**. Solo lagging = llegas tarde. Solo leading = celebras actividad sin comprobar outcome.

## 7. Platform-as-a-product

Tratar a la plataforma como producto significa adoptar la mentalidad y las prácticas de product management:

### Visión y propuesta de valor

Un *one-pager* que responde: ¿para quién es?, ¿qué dolor resuelve?, ¿cómo se mide el éxito?, ¿qué **no** hace? El "qué no hace" es tan importante como el "qué hace".

### Roadmap trimestral: now / next / later

- **Now**: comprometido para el trimestre en curso, con criterios de aceptación.
- **Next**: candidato al siguiente trimestre, aún no comprometido.
- **Later**: ideas con tracción pero sin fecha.

Evita roadmaps a 12 meses con precisión mensual: son ficción.

### Backlog priorizado por valor

Scoring como **RICE** (Reach, Impact, Confidence, Effort), **WSJF** (SAFe) o un *weighted shortest job first* simple. Lo importante es tener **un criterio público** por el que un ítem está en el top, no "porque el VP lo pidió".

### Releases y release notes

- **Release cadence**: continuo (feature flags) o trimestral (big release). Elige explícitamente.
- **Release notes**: cambios user-visible, breaking changes, deprecations, con **upgrade path** cuando aplique.
- **Changelog público interno**: canal Slack / página en TechDocs, no un email que se pierde.

### Feedback groups y user interviews

- *Design partners*: 3–5 stream-aligned teams que ven features **antes** del release y dan feedback.
- *Office hours*: slot semanal público donde cualquier dev puede traer un problema.
- *User interviews*: 30 min 1:1 trimestrales con desarrolladores clave. Pregunta por tareas, no por features.

## 8. Financiamiento: showback, chargeback, platform fee

Un platform team sin modelo de financiamiento claro muere con el primer recorte de presupuesto. Opciones:

- **Centralmente financiado** (platform team es cost center de la org). Simple, pero invisible el consumo.
- **Showback**: muestra a cada equipo cuánto cuesta su uso de la plataforma, **sin cobrar**. Genera conciencia sin fricción.
- **Chargeback**: factura internamente el consumo. Genera disciplina, pero puede incentivar a los equipos a *no* usar la plataforma para evitar el gasto.
- **Platform fee**: tarifa fija por equipo o por servicio registrado. Previsible, pero no refleja consumo real.

Regla práctica: empieza con **showback** durante el primer año, para educar. Decide chargeback/fee después, cuando los patrones de uso sean estables.

## 9. Antipatterns: vanity metrics y Goodhart's Law

- **Vanity metric clásico**: "número de deploys" como headline. Sin tasa de fallos y recovery time al lado, celebra actividad.
- **"Templates publicados por el platform team"**: output del platform team, no outcome del dev. Mide templates **usados**, no publicados.
- **Goodhart aplicado a DORA**: si el bonus del platform team depende de "más deploys / semana", obtendrás más deploys triviales (bump de versión, cambio de whitespace) y perderás la señal.
- **NPS como KPI de board**: cuando NPS pasa de ser un termómetro a ser el termostato, los equipos encuestan a sus amigos y hacen cherry-picking de respuestas.
- **"Platform team solved X tickets"**: medir resolución de tickets premia una plataforma que **genera** muchos tickets. Lo que quieres es una plataforma donde el ticket es raro porque el self-service funciona.

## 10. Dashboard de plataforma defendible

Un dashboard honesto para un platform team mediano:

| Widget | Qué muestra | Por qué está |
|--------|-------------|--------------|
| DORA DF | Deploys/semana (p50, p95) por servicio top-10 | Throughput |
| DORA LTC | Mediana lead time (90 d rolling) | Throughput |
| DORA CFR | % deploys que causaron incident | Estabilidad |
| DORA FDRT | Mediana recovery time (90 d rolling) | Estabilidad |
| Adoption | % servicios registrados / vía template | Leading |
| Platform NPS | Trend 4 trimestres + top 3 quejas | Satisfacción |
| Time to first deploy | p50 para nuevos servicios | Promesa de valor |
| Scorecard adoption | % servicios ≥ silver | Calidad agregada |

Lo que **no** está: "tickets cerrados", "features released", "líneas de código", "commits al platform repo". Son outputs del equipo, no outcomes del usuario.

## 11. Comunicando resultados sin manipular

- **Narrativa > número**. "DF subió 20 % y CFR se mantuvo igual" es mejor que "DF subió".
- **Mostrar siempre pares**: velocidad con estabilidad, adopción con satisfacción.
- **Admite las caídas**. Un dashboard que solo sube es un dashboard editado.
- **Separa correlación de causación**. "Lanzamos el template X y DF subió" no implica causalidad; otros factores existen.
- **Haz las métricas públicas internamente**. Si solo las ve el platform team, se vuelven munición política.

## 12. Síntesis

- **DORA mide flujo**, no calidad de ingeniería ni satisfacción.
- **SPACE rellena** lo que DORA no ve: wellbeing, colaboración, flow.
- **Platform NPS + adoption** son el *leading indicator* del impacto de la plataforma.
- **Platform-as-a-product** es la mentalidad; roadmap, backlog, release notes y user interviews son las prácticas.
- **Financiamiento explícito** (showback mínimo) es un seguro de vida.
- **Un buen dashboard combina lagging + leading, cuantitativo + cualitativo, y nunca celebra actividad sin outcome.**
- **Goodhart's Law es constante**: cualquier métrica que se vuelve objetivo deja de ser métrica útil.

> La plataforma madura no se defiende con "mira cuántos deploys hubo este mes". Se defiende con: "El 72 % de los nuevos servicios ya nacen con nuestro template, DF subió 30 %, CFR bajó al 7 %, y el NPS pasó de +12 a +24. Aquí están las tres cosas que los developers más piden para el próximo trimestre."
