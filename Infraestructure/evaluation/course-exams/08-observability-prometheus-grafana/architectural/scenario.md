# Ejercicio arquitectónico — plataforma de observabilidad para FinOps-SaaS

Peso: **25%** del examen. Duración recomendada: **25–40 min**.

## Contexto

**FinOps-SaaS** es una fintech B2B con la siguiente topología a 12 meses vista:

- **40 microservicios** en 3 clusters EKS (`eu-west-1`, `us-east-1`, `ap-southeast-1`), 90% Python/FastAPI y Go.
- **Carga actual:** 18 M series activas totales (6 M por región), ~2 TB logs/día.
- **Retención requerida:** métricas 13 meses (regulación financiera), logs 90 días hot + 395 días cold.
- **SLO contract** por servicio: disponibilidad 99.9% y latency p99 ≤ 400 ms, ventana 30 d.
- **Equipos:** 6 equipos de producto + 1 equipo de plataforma; cada equipo *owner* de ≥ 3 servicios.
- **Alertas on-call:** PagerDuty para `severity=page`, Jira para `severity=ticket`; política explícita: *una alerta sin runbook_url es un bug*.
- **Governance:** auditoría financiera exige trazabilidad de cambios en reglas de alerta (quién/cuándo/por qué).
- **Presupuesto:** no debe superar **18 % del gasto de cloud** del año fiscal; hoy están en 12% y el crecimiento proyectado los lleva a 25% si no se interviene.

## Restricciones

1. GitOps con Argo CD ya existe; no se admite click-ops en producción.
2. No se puede exportar datos de clientes fuera de la región donde se generan (data residency).
3. El equipo de plataforma es de **4 personas** — no puede operar un stack de +10 componentes nuevos sin un camino "default" claro.
4. Prohibido secretos en plano. Rotación de credenciales soportada.

## Tu tarea

Produce `ADR-001-observability-platform.md` cubriendo:

### 1. Elección de long-term store
- Compara **Thanos (sidecar+querier+compactor+store)**, **Grafana Mimir**, **VictoriaMetrics cluster**, y "no LTS — single Prometheus con retención 13m".
- Justifica tu elección con: operabilidad para 4 personas, data residency, costo (series + egress + object storage), compatibilidad PromQL/Grafana, downsampling.
- Trade-offs: menciona qué pierdes y por qué es aceptable.

### 2. Topología de scrape
- Un Prometheus por cluster vs sharding por `hashmod` vs Prometheus Agent + remote_write centralizado.
- Decidir cómo se mantiene **data residency** (cada región escribe a un LTS regional vs un LTS global).
- Rol de `kube-prometheus-stack`, de ServiceMonitor/PodMonitor/ScrapeConfig/PrometheusRule/AlertmanagerConfig.

### 3. Golden path por servicio
- Cómo un equipo de producto que da de alta un servicio nuevo obtiene **sin ticket**:
  - un `ServiceMonitor` (release label correcto),
  - 4 recording rules RED (`job:*:rate5m`, `job:*:ratio_rate5m`, `job:*:p95_rate5m`, `job:*:p99_rate5m`),
  - un dashboard parametrizado,
  - un `PrometheusRule` MWMBR con SLO default 99.9%/30d.
- Nombra la herramienta (plantilla de Backstage, Helm chart interno, Jsonnet library, operator propio) y justifica.

### 4. Política de alertas
- MWMBR por severity (page/ticket) con fórmulas explícitas (14.4×, 6×, por qué).
- Inhibition multi-nivel (page silencia ticket del mismo `service`).
- Qué ocurre con alertas de **causa** (CPU, disk) — ¿se eliminan? ¿se bajan a ticket? Justifica.
- Low-traffic guard.

### 5. Governance y costos
- Naming y labels obligatorios (`service`, `team`, `env`, `version`, `commit`); ownership en code owners.
- CI gate: `promtool test rules` + `amtool check-config` + lint de dashboards + preview en PR.
- "Meta-observabilidad": qué métricas monitoreas de la propia plataforma (`prometheus_tsdb_head_series`, `prometheus_remote_storage_samples_dropped_total`, `cortex_ingester_*` / `vm_*`), y qué alerta disparas cuando el budget mensual se proyecta sobre el 18%.
- Rotación de secretos y qué pasa si el `remote_write` falla.

## Entregable

Un archivo `architectural/ADR-001-observability-platform.md` con el formato ADR (Context, Decision, Alternatives considered, Consequences, Open questions). Longitud sugerida: 2–4 páginas. No se admite ADR genérico "copy-paste" — se descuenta si no cita cifras del escenario (18 M series, 13 m, 4 personas, 18% budget).

## Rúbrica

| Criterio | Peso | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------|------------------|------------|----------------|-------------|
| Elección de LTS justificada | 4 | No elige o elige por "sonaba bien" | Elige y da 1 razón | Elige con 3+ razones y nombra trade-offs | Elige, cita cifras, y menciona qué métricas de la plataforma vigilan la decisión en producción |
| Topología + data residency | 3 | Omite residency o la rompe | Menciona el requisito pero no lo aterriza | Diseño cumple y lo prueba con flujo de datos concreto | Diseño cumple, y propone verificación (p. ej. test de policy sobre remote_write) |
| Golden path | 4 | "El equipo lo pide por ticket" | Plantilla pero manual | Plantilla ejecutable + ejemplo | Plantilla + CI gate + evolución (versionado del template, migraciones) |
| Política de alertas MWMBR | 4 | Single-window / sin runbook | MWMBR básico sin inhibition | MWMBR + inhibition + low-traffic | Todo lo anterior + argumento sobre causas (reduce o reclasifica) + plan de dead-letter runbook |
| Governance y costos | 3 | No cita cifras, no CI gate | Menciona CI gate general | CI gate concreto + meta-observabilidad listada | CI gate + alertas de budget + plan de reducción escalonada |
| Red flags | — | descuenta 1 nivel por cada una | — | — | — |

**Umbral de la parte arquitectónica:** 50% (≥ 9 / 18 pts).

## Red flags del ADR

- Elegir Thanos/Mimir/VM sin tocar operabilidad ni costo.
- Diseño que rompe data residency (p. ej. remote_write global sin partición).
- "Dashboards los crea cada equipo cuando quiera" (sin contrato).
- Alertas basadas en causas sin reclasificar.
- Secretos de `remote_write` en el ADR en plano, incluso de ejemplo.
- Afirmar "Prometheus escala solo" o "con federation basta" sin cuentas.
