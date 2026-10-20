# Capstone — Etapa 15: Postmortem simulado + runbook definitivo

> Fase 5 del programa · Dominios tocados: **D10 (observabilidad y SRE)**, con guiños a D11 (plataforma / DX) y D9 (DevSecOps).
> Stack asumido: GHA + Terraform + K8s (kind/EKS) + Argo CD + Prometheus Operator + OpenTelemetry + Loki + cosign/syft/kyverno/falco (todo lo acumulado en etapas 1–14).
> Esta etapa es **100 % documental**: no se despliega infraestructura nueva. Es el cierre narrativo del capstone.

---

## 1. Resumen de la etapa

**Objetivo.** Simular un incidente productivo real sobre la plataforma construida en las etapas 1–14, escribir un **postmortem sin culpables** siguiendo la plantilla de Google SRE y materializar un **runbook definitivo** que la próxima guardia pueda usar sin preguntar nada. El estudiante demuestra que entiende el ciclo completo *detectar → mitigar → recuperar → aprender*.

**Delta vs. la etapa 14.** En la etapa 14 se ejecutó un load test y un *chaos ligero*: ya existe un plan de DR y SLOs vivos. Esta etapa toma esa base y añade **la disciplina posterior al incidente**: cómo convertir una hora de dolor en semanas de mejoras. No se cambia código ni infraestructura; se cambia el *proceso* alrededor.

**Fuera de scope.**

- Nuevos componentes de observabilidad (ya existen desde la etapa 11).
- Nuevas políticas de seguridad (están en la etapa 12).
- Automatización del postmortem (bots, generadores, LLMs): aquí lo escribe un humano a mano.
- Métricas de madurez SRE a nivel organización (DORA avanzado, error budget policy formal): se tocaron en la etapa 13.
- Ejercicios de *game day* multi-equipo: fuera; aquí simulamos un incidente que resuelve una persona.

---

## 2. Arquitectura al cierre de esta etapa

```
+------------------------------------------------------------------+
|                   PRODUCCIÓN SIMULADA (etapas 1-14)              |
|                                                                  |
|   +--------+    +----------+    +-----------------+              |
|   | Client |--->| Ingress  |--->| FastAPI (Deploy)|              |
|   +--------+    +----------+    |  3 replicas     |              |
|                                 +--------+--------+              |
|                                          |                       |
|                                          v                       |
|                                 +-----------------+              |
|                                 | PostgreSQL (RDS)|              |
|                                 | pool_max = 20   |              |
|                                 +-----------------+              |
|                                                                  |
|   Observabilidad: Prometheus + Grafana + Loki + Tempo (OTel)     |
+------------------------------------------------------------------+
                              |
                              | INCIDENTE INYECTADO
                              v
+------------------------------------------------------------------+
|                        PROCESO POST-INCIDENTE                    |
|                                                                  |
|  incident/scenario.md ----> runbook/TEMPLATE.md ---> runbook/*   |
|          |                                            ^          |
|          v                                            |          |
|   postmortem/TEMPLATE.md -> postmortem/REFERENCE.md --+          |
|                                                                  |
|  Entregable: dos documentos vivos que la guardia usa realmente.  |
+------------------------------------------------------------------+
```

**Entradas.** El escenario de `incident/scenario.md` (síntomas, timeline, señales en Grafana/Loki).
**Salidas.** Un postmortem llenado + un runbook pulido, ambos revisables por un peer.
**Resource list.** Cero recursos cloud nuevos. Solo archivos Markdown versionados en el repo.

---

## 3. Prerrequisitos verificados

Esta etapa asume que las etapas previas cerraron. En particular necesita las *salidas* educativas, no las infraestructuras vivas:

- [ ] Etapa 11 cerrada: existe un dashboard de Grafana con métricas de la app y SLOs definidos (p95 latencia, error rate).
- [ ] Etapa 12 cerrada: hay logs estructurados en Loki o equivalente y un canal de alertas simulado.
- [ ] Etapa 13 cerrada: Backstage o un catálogo equivalente tiene el servicio registrado con `owner` y `on-call`.
- [ ] Etapa 14 cerrada: existe un documento de DR y los SLOs tienen *error budget* calculado.
- [ ] El estudiante leyó al menos los capítulos **"Postmortem Culture"** y **"Being On-Call"** del libro *Site Reliability Engineering* (gratis en línea).

Si falta alguno, **no bloquea** la etapa (puede completarse con los documentos de referencia), pero la actividad `independent` será más pobre en contexto.

---

## 4. Implementación guiada

Los pasos no "construyen" nada ejecutable: construyen comprensión y dos documentos. Están pensados para ~3 horas totales.

### 4.1 Leer el escenario inyectado

```bash
cd projects/capstone/stages/15-postmortem-simulated-runbook
less incident/scenario.md
```

El fallo elegido es **agotamiento del pool de conexiones a PostgreSQL** disparado por un endpoint nuevo (`/tasks/search`) con una query sin índice. Es un clásico porque:

- No es un "bug obvio": el código compila, los tests pasan, el deploy fue verde.
- Los síntomas iniciales (`5xx` + latencia alta) apuntan a muchísimas cosas: red, DNS, cert, upstream, etc.
- La mitigación rápida (bajar réplicas o rollback) es distinta de la causa raíz (índice faltante + timeout mal configurado).

**Por qué este escenario y no otro.** Un *bad deploy* se arregla con `kubectl rollout undo`: enseña poco. Un *cert expiry* lo detecta cualquier monitor estándar. Una *upstream outage* es un ejercicio de comunicación, no de debug. El pool exhausto obliga a atravesar las tres capas (app, infra, datos) y correlacionar métricas, logs y traces.

### 4.2 Dibujar la timeline

Antes de escribir el postmortem, se trabaja con un papel y una línea horizontal:

```
13:45    13:58    14:03    14:07    14:12    14:18    14:35    15:10
  |        |        |        |        |        |        |        |
deploy   first    pager   on-call   rollback  pool    patch    status
v2.4.1   slow      page   joins     attempt   drains   deploy   green
         req                                   (noop)
```

**Por qué dibujarla antes.** La timeline es el esqueleto del postmortem. Si no está clara, el resto se escribe en círculos.

### 4.3 Rellenar `postmortem/TEMPLATE.md`

Se copia a un nombre nuevo (`YYYY-MM-DD-pool-exhaustion.md`) y se llena. La **plantilla** vive aquí para ser reutilizada en cualquier incidente futuro. La **referencia** (`postmortem/REFERENCE.md`) es el "ejemplo resuelto" para este escenario específico y sirve como auto-check.

Reglas duras del postmortem (vienen de Google SRE):

1. **Blameless.** Se habla de sistemas y de decisiones, nunca de "quién la cagó".
2. **Factual.** Se citan logs y métricas con timestamps, no sensaciones.
3. **Accionable.** Cada *action item* tiene dueño, due date, y severidad (`P0/P1/P2`).
4. **Público internamente.** Se asume que lo lee cualquiera de la compañía.

### 4.4 Rellenar `runbook/TEMPLATE.md`

El runbook es la **versión operacional** del postmortem: lo que la próxima guardia necesita para *resolver el mismo síntoma* en 10 minutos, aunque no sepa nada del incidente original. Debe responder:

- ¿Cómo reconozco este incidente? (síntomas, dashboards, alertas que lo disparan)
- ¿Qué pruebas rápidas diagnóstico hago? (comandos exactos, no "revisa la DB")
- ¿Cuál es la mitigación menos invasiva? (orden explícito)
- ¿Cuándo escalo y a quién?
- ¿Cómo verifico que ya recuperé?

### 4.5 Peer review

Un compañero (o el instructor) revisa los dos documentos con una checklist:

- [ ] Timeline tiene al menos 6 eventos con `HH:MM` UTC.
- [ ] "Impact" cuantificado (requests fallidas, usuarios afectados, SLO burn).
- [ ] "Root cause" no es "humano cometió error".
- [ ] Al menos 3 *action items* con owner y fecha.
- [ ] Runbook arranca con "SI VES ESTO" (síntoma) y no con "haz esto".
- [ ] Runbook tiene un paso de "cómo verificar que ya está mitigado".

---

## 5. Actividades del estudiante

| ID activity | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-15-01-write-blameless-postmortem` | independent | 75 min | Rellenar un postmortem completo a partir del escenario, validado por estructura. |
| `cap-15-02-author-oncall-runbook` | independent | 60 min | Escribir el runbook para pool exhaustion que un peer podría usar sin conocerlo. |
| `cap-15-03-debug-broken-timeline` | debug | 40 min | Reparar un postmortem con timeline inconsistente, campos faltantes y culpabilizaciones; dejarlo blameless y accionable. |

Se cumple el criterio *"al menos una actividad independent o debug"* con creces (2 independent + 1 debug).

---

## 6. Entregables

Al cerrar la etapa el estudiante tiene:

1. `postmortem/2026-04-17-pool-exhaustion.md` (o fecha equivalente) completo y revisado.
2. `runbook/db-pool-exhaustion.md` publicado en el *runbook index* del equipo (en una org real sería Backstage, aquí basta un `runbook/index.md`).
3. Las 3 actividades con `validate.sh` en verde.
4. Un *action item* ejecutado: por ejemplo, un `CREATE INDEX CONCURRENTLY` en una migración Alembic nueva. No se exige mergearlo para cerrar la etapa, solo abrir el PR.

---

## 7. Pruebas y criterios de aceptación

Chequeos automáticos (via `activities/*/tests/validate.sh`):

- [ ] Postmortem tiene todas las secciones Google SRE (summary, impact, timeline, root cause, trigger, resolution, detection, action items, lessons learned).
- [ ] Timeline tiene ≥ 6 eventos con formato `HH:MM`.
- [ ] Action items tienen owner y due date.
- [ ] Runbook tiene las secciones *symptoms, diagnostics, mitigations, escalation, recovery, verification*.
- [ ] Ningún documento contiene palabras bandera: `fault of`, `blame`, `stupid`, `careless`, `idiot`, `culpa de`.

Criterios de calidad (revisión humana):

- [ ] Las secciones de *detection* y *resolution* mencionan señales concretas: nombres de métricas, queries de PromQL o LogQL, dashboards reales.
- [ ] Los *action items* están priorizados y uno al menos es *preventivo* (no solo *corrective*).

---

## 8. Costos y limpieza

**Costo cloud:** `$0.00`. Esta etapa no provisiona nada.

**Limpieza:**

```bash
rm -rf /tmp/cap-15-*
```

No hay recursos externos. Los documentos del postmortem/runbook se dejan en el repo porque son el entregable permanente del capstone.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El estudiante escribe un postmortem "narrativo" sin datos. | La plantilla exige citar timestamps, métricas y queries. El validador verifica presencia de secciones mínimas. |
| El runbook se vuelve "manual de la app" en vez de "manual del incidente". | La plantilla fuerza el patrón *symptoms → diagnostics → mitigations*. Nada que no responda a un síntoma concreto va al runbook. |
| Se cae en culpabilización implícita ("el dev no probó el índice"). | El validador rechaza una lista de palabras bandera. En peer review se exige reformular en términos de proceso. |

**Hints progresivos** (si el estudiante se atasca):

1. ¿Tienes la timeline antes del texto? Si no, dibújala en papel con `pre-trigger / trigger / detection / mitigation / resolution`.
2. ¿La *root cause* está formulada como "porque X causó Y"? Si tiene menos de dos pasos de "porque", todavía es síntoma.
3. ¿Cada *action item* tiene dueño con nombre (o rol) y fecha? Si no, no es accionable.

---

## 10. Puente con la siguiente etapa

Esta es la **última etapa del capstone**. No hay "siguiente". Lo que sí hay es un ciclo:

- El postmortem genera *action items*.
- Los *action items* se convierten en PRs que vuelven a entrar por la etapa 3 (CI), 5 (supply chain) o 10 (GitOps multi-ambiente).
- Los runbooks se vuelven *source of truth* del equipo on-call: cada incidente real futuro los pule o los deprecia.

**Cliffhanger (meta).** Si tuvieras que elegir *una sola* práctica de todo el capstone para instaurar primero en un equipo real, ¿cuál generaría mayor rendimiento compuesto en 6 meses? La respuesta de la industria (Accelerate, DORA, Google SRE) suele ser **feedback loops cortos y blameless postmortems**. Todo lo demás es táctica alrededor de esos dos.
