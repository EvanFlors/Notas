# REFERENCE — jk-08-01-operate-at-scale-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Operación a escala del Jenkins corporativo

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Platform + Security y materializado con Terraform + Helm en Fase 4.

## Contexto

Operamos un Jenkins LTS desde hace 4 años en una VM EC2 con `JENKINS_HOME` en un volumen EBS. Hoy:

- **120 pipelines** activos: 80 declarative versionados y 40 freestyle sin dueño claro.
- **15 agents** EC2 permanentes, mezcla amd64/arm64.
- **40 ingenieros** usan la UI; picos de **60 builds/hora** los lunes.
- **Compliance** exige **retención 7 años** de logs/artefactos de builds marcados `prod`.
- SLA interno: **99.5%** en horario laboral (ventanas fuera de horario son aceptables).
- **No hay presupuesto** para CloudBees CI. Sí existe un **EKS corporativo** operado por otro equipo que acepta tenants adicionales.

El controller es SPOF por diseño, así que no vamos a "lograr 99.9%". Nuestro margen está en **reducir MTTR** y en **reproducibilidad** (JCasC + backup verificado).

## Decisión

### 1. Patrón HA: Jenkins Operator en EKS + activo-pasivo manual

```
┌───────────────────────────────────────────────────────┐
│   EKS cluster (eu-west-1)                             │
│                                                       │
│   ┌─────────────────────────┐                         │
│   │ Jenkins Operator        │   watches CRD           │
│   └──────────┬──────────────┘                         │
│              │ reconcilia                             │
│              ▼                                        │
│   ┌─────────────────────────┐   PVC backed by EBS gp3 │
│   │ Jenkins controller Pod  │───►[JENKINS_HOME PVC]   │
│   │ (configurado por JCasC) │                         │
│   └─────────────────────────┘                         │
│              │ k8s plugin                             │
│              ▼                                        │
│   agents efímeros (Pods per build)                    │
└───────────────────────────────────────────────────────┘
            │   Velero snapshot diario + horario
            ▼
   S3 object-locked (Governance mode, 7 años)
            │
            ▼
   Standby controller "cold" en segunda región (restore script probado mensualmente)
```

**Por qué**:

- Operator da MTTR 1–3 min ante crash del Pod (reconciliación K8s).
- JCasC + CRD = controller **reproducible** desde Git; perder el controller no equivale a perder la configuración.
- Standby frío en segunda región cubre el escenario "EKS cluster perdido". MTTR objetivo: 20–40 min (restore de Velero + DNS swap).
- CloudBees queda descartado por presupuesto; cuando se apruebe, se puede migrar (JCasC es portable; los agents K8s también).

### 2. Backup del `JENKINS_HOME`

- **Herramienta**: Velero con backend S3; snapshot de PVC vía CSI (EBS gp3 snapshot).
- **Qué se respalda**: todo el PVC `JENKINS_HOME`, con especial énfasis en:
  - `config.xml` y `jenkins.yaml` (JCasC).
  - `jobs/*/config.xml` y `jobs/*/builds/*` (historial pipelines, incluidos los freestyle legacy).
  - `credentials.xml`, `secrets/master.key`, `secrets/hudson.util.Secret` — **sin estas dos keys, no se descifran credentials en el restore**.
  - `users/`, `nodes/`, `plugins/*.jpi`.
- **Qué no se respalda**: `workspace/`, `caches/`, `war/`.
- **Destino**: bucket S3 `jenkins-backups-prod-eu-west-1`, **Object Lock Governance mode 7 años** (compliance), replicado a `eu-central-1`.
- **Frecuencia**:
  - Snapshot completo **diario** 02:00 UTC.
  - Incremental **horario** 08:00–20:00 UTC (horario laboral).
  - Retención: 30 días diarios + 7 años de snapshots mensuales (compliance).
- **Prueba de restore**: **mensual**, en un cluster EKS staging. Checklist: UI responde, credenciales descifran, un pipeline conocido arranca y produce artefacto. Falla la prueba → ticket P2.
- **Export histórico separado**: logs de builds `prod` se replican a S3 Glacier con lifecycle policy aparte, para sobrevivir incluso al apagado futuro del controller.

### 3. Upgrade cadence

| Tipo | Ventana | Procedimiento |
|------|---------|---------------|
| **Patch LTS** (`2.479.1 → 2.479.2`) | ≤ 1 semana | PR a `jenkins.yaml` con nueva imagen; Operator reconcilia en staging; promote a prod ventana sábado. |
| **Minor LTS** (`2.479.x → 2.492.x`) | ≤ 1 mes | Lectura previa de **changelog**; test suite de smoke en staging controller; PR a producción. |
| **Salto máximo** | **2 LTS** atrás | Más allá, upgrade intermedio obligatorio. |
| **Plugins** | PR semanal con `plugins.txt` bumps; revisión manual para `credentials`, `pipeline-*`, `kubernetes`. | Pinning estricto; nada de `latest`. |

**Pre-upgrade checklist** (obligatorio):

1. Backup Velero verificado de los últimos 7 días.
2. Changelog leído y breaking changes anotados.
3. Smoke en staging controller (reload JCasC + 3 pipelines canary verdes).
4. Ventana comunicada en #platform y #eng.

### 4. Capacity planning

- **Controller**: `executors = 0` (nunca ejecuta builds). Pod: `4 vCPU / 8 GB RAM`, heap `-Xmx6g`. PVC `gp3` 100 GB con 3000 IOPS.
- **Agents**: 100% **efímeros** vía Kubernetes plugin. `podTemplate` por lenguaje (`python-3.12`, `node-20`, `jdk-21`, `go-1.23`). Autoescala por el cluster via `cluster-autoscaler` + nodos Spot.
- **Ejecutores objetivo**:
  - Base: 60 builds/h × 5 min medios / 60 = ~5 concurrentes.
  - Pico lunes `×3`: ~15 concurrentes.
  - Buffer: `×2` para absorber incidentes → **30 slots** máximos.
- **Separación** amd64/arm64: dos node pools distintos; `podTemplate` apunta a `nodeSelector` por arquitectura.

### 5. Observabilidad y alertas

- **Métricas**: Prometheus plugin exporta a Prometheus corporativo. Scrape cada 30 s.
- **Dashboards**: Grafana — queue depth, builds/h, p95 duración por pipeline crítico, uso de nodo por `podTemplate`, uptime del controller.
- **Alertas que paginan** (3 obligatorias):

| Métrica | Condición | Acción |
|---------|-----------|--------|
| `jenkins_queue_depth` | `> 10 for 15m` | Investigar saturación de agents. |
| `jenkins_executor_in_use_count / jenkins_executor_count` | `> 0.9 for 10m` | Subir capacity del node pool. |
| `jvm_memory_heap_used_bytes / jvm_memory_heap_max_bytes` | `> 0.85 for 10m` | Diagnosticar leak / scheduler GC old gen. |

- **Alertas que no paginan pero mandan ticket**: `up{job="jenkins"} == 0 for 2m` (controller caído — ya hay fallback), ratio de build failures > 20% en 1 h (entorno degradado).

### 6. Reproducibilidad y runbooks

- **JCasC obligatorio**: toda la configuración del controller vive en `jenkins.yaml` versionado en Git (repo `platform/jenkins-config`). Cambios por PR, con CI que valida esquema.
- **Runbooks** publicados en `docs/runbooks/`:
  - `restore-from-velero.md` — paso a paso, probado mensualmente.
  - `upgrade-lts.md` — pre-flight checklist + rollback.
  - `scale-out-agents.md` — subir capacidad de un node pool en incident.
- **Chaos drill mensual**: apagar el Pod del controller un miércoles 15:00 en staging; cronometrar MTTR; publicar postmortem.

## Consecuencias

### Positivas

- MTTR por crash del Pod: 1–3 min (reconciliación K8s).
- MTTR por pérdida de EKS: 20–40 min (restore Velero + DNS swap probado).
- Configuración reproducible desde Git (JCasC) — un desarrollador puede levantar un Jenkins idéntico en 20 min en local con `kind` para pruebas.
- Agents efímeros eliminan contamination; cada build es un entorno limpio.
- Cumple SLA 99.5% con margen.
- Base portable: si mañana se aprueba CloudBees CI, el JCasC y los `podTemplate` migran casi tal cual.

### Negativas

- Dependencia del equipo que opera el EKS corporativo (nuestro Jenkins es su "tenant"). **Mitigación**: SLA cruzado documentado + runbook de restore en segunda región sin EKS primario.
- Operator es OSS con mantenimiento irregular. **Mitigación**: pin de versión del Operator, revisión trimestral; plan B es desplegar el controller como Deployment "plano" (sin Operator) con el mismo JCasC — está documentado.
- Costo de Velero + S3 object-locked a 7 años no es despreciable (~200 USD/mes estimado). **Mitigación**: lifecycle policy mueve snapshots > 90 días a Glacier Deep Archive.
- Upgrade cadence agresiva exige tiempo del equipo platform. **Mitigación**: PR autogenerado semanalmente por Renovate; revisión humana ≤ 1 h/semana.

## Alternativas descartadas

### Alternativa A: seguir en VM EC2 sin K8s

- Pros: ya está montado; cero migración.
- Contras: no reduce MTTR (restore manual de volumen); JCasC se usa a medias; agents permanentes contaminados; difícil reproducir el controller en local.
- **Por qué no**: no resuelve los dolores reales — reproducibilidad y MTTR.

### Alternativa B: CloudBees CI managed

- Pros: HA real, soporte, menos trabajo operativo.
- Contras: licencia fuera de presupuesto.
- **Por qué no**: Finance lo rechazó explícitamente. Reevaluar en 12 meses.

### Alternativa C: migrar YA a GitHub Actions (sin pasar por operar Jenkins)

- Pros: elimina el Jenkins como problema.
- Contras: 120 pipelines, 40 freestyle, Shared Libraries — migración de ≥ 6 meses. Durante ese tiempo, **igual** necesitas operar el Jenkins existente.
- **Por qué no (aún)**: ocurre en la actividad 02. Esta ADR es la base para operar mientras ocurre esa migración.

### Alternativa D: solo activo-pasivo manual sin K8s/Operator

- Pros: simplicidad; ningún componente nuevo.
- Contras: MTTR 2–6 h sin disciplina seria; sin JCasC reproducible la restauración siempre es parcial.
- **Por qué no**: no cumple el SLA 99.5% de forma honesta.

---

## Notas sobre portabilidad futura

Si en 18 meses se aprueba CloudBees CI o si se decide migrar a GHA (actividad 02):

- JCasC `jenkins.yaml` es portable casi 1:1 a cualquier controller moderno.
- `podTemplate` de Kubernetes plugin tiene equivalente directo en GHA ARC (Actions Runner Controller).
- Backups con Velero son útiles también como fuente histórica para extracción de artefactos pre-corte.
