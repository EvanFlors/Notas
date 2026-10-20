# aws-17 — Lección: plataforma, FinOps y Well-Architected

> 12 secciones. 100 % conceptual + hojas de cálculo. Prerrequisitos: `aws-07`, `aws-08`, `aws-12`, `aws-15`.

---

## 1. Punto de partida: AWS como plataforma, no como "la nube"

En Nivel 1 aprendimos a lanzar una EC2 y a crear un bucket. En Nivel 2 aprendimos redes, IAM avanzado, datos, contenedores, observabilidad y DevSecOps. Este módulo responde a la pregunta que cierra el ciclo:

> *"Si tengo que operar AWS para N equipos durante varios años, ¿cómo lo organizo para que no explote ni en costos, ni en seguridad, ni en resiliencia?"*

La respuesta a esa pregunta tiene nombre: **plataforma**. Y una plataforma AWS seria se apoya en tres patas:

1. **Landing zone** — la estructura de cuentas, redes y guardrails base que todos los equipos heredan.
2. **FinOps** — la disciplina que convierte la factura en una señal **medible, atribuible y accionable**.
3. **Well-Architected Framework** — el checklist razonado que la propia AWS publica para que ninguna de las 6 dimensiones críticas quede ciega.

Este módulo las ata. No es un tutorial de un servicio; es el **plano de operación**.

---

## 2. Landing zone: el patrón "varias cuentas, una red central"

### 2.1 Por qué multi-cuenta

Una **single-account AWS** colapsa en producción por tres razones:

- **Blast radius.** Un IAM mal configurado o un `terraform destroy` erróneo afectan a todo.
- **Billing opacidad.** Separar costes entre equipos exige tagging perfecto y aun así es frágil.
- **Compliance.** Auditores quieren ver separación entre `audit`, `log-archive` y `workload`.

AWS Organizations resuelve esto. La **landing zone** es el plano concreto que se define sobre Organizations.

### 2.2 Cuentas canónicas mínimas

```
AWS Organization (root)
│
├── OU: Security
│     ├── log-archive        (bucket central de logs, write-once)
│     └── audit              (Security Hub, GuardDuty master, Config aggregator)
│
├── OU: Infrastructure
│     ├── network            (Transit Gateway, VPC inspection, Route 53 Resolver)
│     └── shared-services    (SSO, DNS raíz, ECR centralizado, artifact repos)
│
└── OU: Workloads
      ├── workload-dev
      ├── workload-stg
      └── workload-prd
```

Con **cuatro OUs** y **seis a ocho cuentas** se cubre el 80 % de los casos. Añadir más es casi siempre reaccionar a una necesidad concreta.

### 2.3 Red hub-and-spoke con Transit Gateway

En vez de **peerings** VPC-a-VPC (que escalan `O(N²)`), se centraliza con **Transit Gateway (TGW)** en la cuenta `network`:

```
   workload-dev VPC ─┐
   workload-stg VPC ─┼──► TGW (cuenta network) ──► inspection VPC ──► NAT central ──► Internet
   workload-prd VPC ─┘                                    │
                                                          └──► Firewall / IDS (opcional)
```

**Consecuencia FinOps directa:** un **NAT Gateway por cuenta** cuesta `~$32/mes de fijo` + tráfico. Centralizar NAT en la *inspection VPC* colapsa N NATs en 1 (o 2 para HA). En una organización con 20 cuentas, pasar de "NAT por cuenta" a "NAT central" ahorra `~$600/mes` solo en fijo. Es el ejemplo canónico de **arquitectura que paga su propio diseño**.

### 2.4 DNS compartido y Route 53 Resolver

Un **private hosted zone** en la cuenta `shared-services`, con **Route 53 Resolver endpoints** inbound/outbound asociados al TGW, permite que todas las cuentas resuelvan los mismos nombres internos sin duplicar zonas. Sin esto, cada equipo mantiene su propia PHZ y nadie encuentra nada.

### 2.5 Logging centralizado

- **CloudTrail Organization Trail** → bucket en `log-archive` (versionado, Object Lock, SSE-KMS).
- **VPC Flow Logs** → mismo bucket o uno paralelo.
- **Config** → agregador en `audit`.
- **Security Hub + GuardDuty + Macie** → `audit` como *delegated administrator*.

El principio es simple: **el que puede escribir logs no puede borrarlos**. Por eso `log-archive` tiene **SCP** que prohíbe `s3:DeleteObject*` incluso al root.

---

## 3. FinOps: la factura como señal de ingeniería

### 3.1 Por qué sin tagging no hay FinOps

La factura AWS cruda muestra `EC2 — $4,200` y `RDS — $1,800`. Esa información es **inútil** para tomar decisiones. Lo útil es:

> `equipo=checkout, env=prd, service=payments-api, cost_center=cc-042` → `$450/mes`

Esto solo es posible si cada recurso lleva **tags** y esos tags están **activados como cost allocation tags** en Billing. Sin eso, Cost Explorer te da totales y nada más.

### 3.2 Tags obligatorios (set mínimo recomendado)

| Tag | Para qué sirve |
|-----|----------------|
| `cost_center` | Quién paga la factura internamente (contabilidad). |
| `env` | `dev`, `stg`, `prd`. Permite filtrar prod del resto. |
| `service` | A qué microservicio/producto pertenece. |
| `team` | Equipo propietario (ownership). |
| `data_classification` | `public`, `internal`, `confidential`, `pii` (seguridad + cost allocation en algunos casos). |

Exigirlos con una **SCP** que deniegue el `RunInstances` / `CreateBucket` / etc. **si no vienen con esos tags** mueve la disciplina de "pedir por favor" a "no puedes crearlo sin ellos". Ver `examples/01-tagging-strategy-and-enforcement-scp/`.

### 3.3 Las palancas de ahorro: cuándo cada una

| Palanca | Compromiso | Descuento típico | Cuándo usarla |
|---------|------------|------------------|---------------|
| **On-Demand** | Ninguno | 0 % | Baseline. Pico impredecible. Prototipos. |
| **Compute Savings Plan** | 1 ó 3 años, `$/hora` comprometido | 20–50 % | Carga **estable** que **sabes** que correrá mínimo X. Flexible: aplica a EC2, Fargate y Lambda. |
| **EC2 Instance Savings Plan** | 1 ó 3 años, familia + región | 30–60 % | Igual que compute SP pero más barato y menos flexible (familia fija). |
| **Reserved Instance (RDS/ElastiCache/…)** | 1 ó 3 años, instancia específica | 30–60 % | Bases de datos u otros servicios que **no** cubre Savings Plan. |
| **Spot** | Interrupción con 2 min de aviso | 60–90 % | Workloads **tolerantes a interrupción**: batch, CI runners, procesado async, data pipelines con checkpointing. |
| **Graviton (ARM)** | Recompilar / probar compatibilidad | 20–40 % extra sobre x86 | Cuando tu stack soporta ARM (la mayoría del ecosistema Python/JVM/Node ya lo hace). |

La regla práctica: **primero mide (al menos 2–3 meses de baseline), luego compra**. Comprar un Savings Plan a 3 años el primer mes de un workload nuevo es la forma más común de desperdiciar dinero.

### 3.4 AWS Compute Optimizer

Compute Optimizer analiza utilización histórica (CPU, memoria, red) y recomienda:

- **Rightsizing** de EC2 (de `m5.2xlarge` subutilizada a `m5.large`).
- Migración a **Graviton** cuando aplica.
- Rightsizing de **ASGs**, **EBS**, **Lambda** (memoria), **ECS tasks**.

Es gratis y la primera herramienta a mirar antes de pensar en Savings Plans: **si una instancia está sobredimensionada, comprometerte 3 años a su tamaño actual es firmar un ahorro negativo**.

### 3.5 Cost Explorer y Cost Anomaly Detection

- **Cost Explorer** — UI web con filtros por servicio, tag, cuenta, región. Grupo-by, forecast, charts guardados. En este módulo se recorre por escrito (sin credenciales), ver actividad 03.
- **Cost Anomaly Detection** — ML que aprende el baseline por *monitor* (todas las cuentas, un servicio concreto, un tag concreto) y alerta cuando el gasto se desvía estadísticamente. Umbrales típicos: `>20 %` **y** `>$100`. Reduce falsos positivos frente a thresholds fijos.

---

## 4. Unit economics: de `$/mes` a `$/MAU` y `$/request`

El total mensual es un dato pobre. Un negocio quiere saber:

- **`$/MAU`** (Monthly Active User) — cuánto cuesta servir a un usuario activo en un mes.
- **`$/request`** — cuánto cuesta un request (API, página, job).
- **`$/tenant`** — en SaaS multi-tenant, por cliente.
- **`$/GB-ingested`** — para plataformas de datos.

### 4.1 La fórmula canónica

```
$/MAU_mes = (costo_total_atribuido_al_servicio_en_el_mes) / MAU_del_mes
$/req     = (costo_total_atribuido_al_servicio_en_el_mes) / requests_totales_del_mes
```

Parece trivial. El trabajo real es:

1. **Atribuir** el coste al servicio (vuelta a tags).
2. **Obtener** el denominador (MAU, requests). Normalmente de un data warehouse o de métricas Prometheus.
3. **Alinear** las ventanas temporales (mes natural vs mes de facturación de AWS).
4. **Separar** fijo (NAT, Transit Gateway, Load Balancers) de variable (compute por hora, transferencia de datos).

### 4.2 Para qué sirve

- **Comparar entre servicios** del mismo producto (`$/req` de `checkout` vs `catalog` vs `search`).
- **Detectar regresiones**: si `$/MAU` sube un 30 % en un mes sin que suba MAU, algo cambió (query más cara, instancia más grande, NAT caro mal diseñado).
- **Pricing**: para una SaaS, saber tu `$/tenant` es la base para decidir si el ARR por cuenta cubre el COGS.
- **Capex vs opex en conversaciones de board**: `$/MAU` es un KPI que un CFO entiende; `t3.medium × 6` no.

La actividad 02 hace este cálculo sobre un CSV sintético que **plantamos** con un mes anómalo. El estudiante tiene que detectarlo con el script.

### 4.3 Qué **no** es unit economics

- No es "dividir la factura entre el número de empleados". Eso es *cost per headcount* y mide otra cosa.
- No es un *proxy* de margen bruto; falta restar ingresos.
- No sustituye al presupuesto. Es una **señal**, no un plan.

---

## 5. DR: patrones y su coste

AWS organiza DR en cuatro patrones canónicos. El eje relevante es **RPO / RTO vs coste**.

| Patrón | RPO típico | RTO típico | Coste relativo | Cuándo |
|--------|-----------|-----------|----------------|--------|
| **Backup & Restore** | 24 h | 24 h | 1× (baseline, solo backups cross-region) | Workloads tolerantes a ventana larga. Internos. |
| **Pilot Light** | minutos (replicación DB) | 10–60 min (levantar compute) | 1.3–1.8× | Core services con criticidad media. |
| **Warm Standby** | segundos | 1–10 min | 2–3× | Public-facing con SLA estricto pero no 24/7 crítico. |
| **Multi-Region Active-Active** | ~0 | ~0 | 2.5–4× | Negocios donde un downtime regional significa pérdida directa de ingresos no recuperables. |

Puntos clave:

- **No todo workload necesita active-active.** La trampa clásica es "lo quiero todo multi-región" sin presupuesto para operar la complejidad (replicación bidireccional, conflict resolution, DNS failover testeado).
- **El coste no es solo la cuenta**: es también el esfuerzo humano de probar el failover. **Un plan DR no testeado no existe.**
- **RPO/RTO se negocian con producto**, no se eligen por ingeniería. Lo técnico solo responde "para `X` RTO necesitas pagar `Y`".

Ver `examples/03-dr-pilot-light/` para el walkthrough del patrón intermedio más usado.

---

## 6. AWS Backup y la estrategia multi-cuenta

**AWS Backup** centraliza políticas de backup para EBS, EFS, RDS, DynamoDB, Aurora, FSx, Storage Gateway, S3 y más. En landing zone típica:

- La cuenta `audit` o `backup` (puede ser separada) es el **delegated administrator** de AWS Backup Organization.
- Define **Backup Plans** con reglas (frecuencia, retención, ventana) y **Backup Policies** aplicadas a OUs/cuentas.
- Guarda las copias en **vaults cross-account y cross-region**, con **Vault Lock** (WORM) para proteger contra ransomware.

Esto reemplaza el patchwork de snapshots manuales + scripts bash + buckets variados que suele crecer orgánicamente.

---

## 7. AWS Config conformance packs y Security Hub

### 7.1 Config

**AWS Config** mantiene un **inventario versionado** de los recursos y evalúa reglas (p. ej. "ningún SG abre 0.0.0.0/0 en el puerto 22", "ningún bucket es público", "todo volumen EBS está cifrado"). Un **conformance pack** es un paquete versionado de reglas (CIS, PCI, HIPAA, Well-Architected…) que se aplica a nivel OU.

### 7.2 Security Hub

**Security Hub** **agrega findings** de GuardDuty, Inspector, Macie, Config, IAM Access Analyzer y vendors externos (p. ej. Snyk) en una **vista unificada** en la cuenta `audit`. Correlaciona, prioriza y permite workflow de triage.

Sin agregación, cada equipo mira su propio tablero y nadie ve el panorama. Con `audit` como *security central*, el SOC trabaja desde un único sitio.

### 7.3 Relación con FinOps

Parece colateral, pero no lo es. **Un recurso no inventariado o sin owner claro acaba facturando sin que nadie lo defienda**. Config + Security Hub + tagging son los tres pilares que evitan el **shadow IT dentro de la propia AWS**.

---

## 8. Well-Architected Framework: los 6 pilares

AWS publica el **Well-Architected Framework (WAF)**: un cuestionario estructurado por **6 pilares**, con preguntas, mejores prácticas y riesgos. Es la **lista de verificación oficial** para una review arquitectónica.

| Pilar | Pregunta que responde | Métricas típicas |
|-------|------------------------|------------------|
| **1. Operational Excellence** | ¿Puedes operar y observar el workload? | Despliegues/semana, MTTR, cobertura de runbooks, % tests pasando. |
| **2. Security** | ¿Puede un atacante dañarte? | Hallazgos críticos abiertos, cobertura MFA, rotación de secretos, cifrado at-rest/in-transit. |
| **3. Reliability** | ¿Aguanta fallos de infra, picos, errores humanos? | SLO cumplimiento, resultado de game days, cobertura multi-AZ, RTO/RPO probados. |
| **4. Performance Efficiency** | ¿Usas los recursos adecuados a la carga? | Utilización media de CPU/memoria, latencia p95/p99, rightsizing pendiente de Compute Optimizer. |
| **5. Cost Optimization** | ¿Pagas lo mínimo necesario para el valor que entregas? | `$/MAU`, `$/req`, cobertura de SP/RI, % Spot en batch, tags obligatorios aplicados. |
| **6. Sustainability** | ¿Minimizas el impacto ambiental por unidad de trabajo? | `gCO2/req` estimado, uso de Graviton, elección de región, right-sizing. |

Un **Well-Architected Review (WAR)** típico consiste en:

1. Elegir **un workload** (no la organización entera, un workload).
2. Responder las preguntas de cada pilar.
3. Marcar **High Risk Issues (HRIs)** y **Medium Risk Issues**.
4. Producir un **Improvement Plan** priorizado.
5. Repetir cada 6–12 meses o tras un cambio arquitectónico mayor.

La actividad 03 hace esto por escrito contra un workload hipotético.

---

## 9. Cost Explorer: cómo se lee (walkthrough escrito)

Como este módulo **no toca AWS real**, el walkthrough es textual. Los pasos canónicos de una revisión de 20 minutos:

1. **Filtro por período**: últimos 3 meses, granularidad mensual.
2. **Group by: Service**. Mira el top 5. Suele ser `EC2 — Other` (que incluye EBS, data transfer, NAT), `EC2 — Instance`, `RDS`, `S3`, `CloudWatch`.
3. **Click en `EC2 — Other`** → group by `Usage Type`. Separa `NatGateway-Bytes` de `NatGateway-Hours` de `EBS:VolumeUsage.gp3`, etc.
4. **Group by: Tag `env`** (requiere tag activado). Mira si `dev` está pesando igual que `prd` — señal roja.
5. **Group by: Tag `service`**. Ordena. Los 3 servicios de arriba suelen justificar el 60–70 %.
6. **Filtro: `Linked Account` = `workload-dev`** y mira si hay algo corriendo 24×7 que no debería (olvidado tras una prueba).
7. **Reservations / Savings Plans tabs**: cobertura actual, recomendaciones del motor de AWS.
8. **Forecast** del siguiente mes. Compara con presupuesto.
9. **Guarda la vista** como *Saved Report* para repetir rápido.
10. **Documenta hallazgos** en el ADR o en el FinOps report.

El error más frecuente: quedarse en el total y no bajar al **Usage Type**. El dato accionable está siempre dos clicks más abajo.

---

## 10. Alternativas y escenarios donde "esto no aplica"

- **Startup de una sola cuenta y 2 ingenieros.** Montar landing zone de 8 cuentas es prematuro. Una sola cuenta + tagging + presupuestos puede durar 1–2 años. Lo que **sí** aplica desde el día 1: tagging, SCP para prohibir regiones no usadas, Budgets alerts.
- **Workload totalmente batch, caro, no crítico.** El plan DR no requiere pilot-light; backup+restore con RTO de 24 h suele bastar.
- **Equipo sin cultura FinOps.** Comprar Savings Plans antes de instalar tagging y dashboards es un error típico: compras a ciegas.
- **Compliance ligero.** No todo workload necesita Config conformance packs completos. Un subset custom puede ser suficiente.
- **"No tenemos tiempo para un WAR."** El WAR corto (half-day) con 2–3 preguntas por pilar da más valor que ninguno. La trampa es querer uno perfecto.

El marco WA es una **guía**, no un contrato. El criterio ingenieril es decidir **qué partes aplicar ahora** y qué deuda documentar para después.

---

## 11. Ventajas y limitaciones honestas

**Ventajas de operar AWS como plataforma:**

- **Blast radius controlado** por cuenta.
- **Facturación segmentada** real (no proxy).
- **Compliance delegable**: `audit`/`log-archive` son el pack que les enseñas a los auditores.
- **FinOps repetible**: con dashboards y rituales mensuales, el gasto se vuelve predecible.
- **WAR institucional**: cada revisión produce acciones concretas y queda registro.

**Limitaciones y riesgos:**

- **Overhead humano**: una landing zone necesita un *platform team* (incluso de 1 persona a tiempo parcial). Sin dueño, se degrada.
- **Costes "ocultos" de la propia plataforma**: Config, Security Hub, GuardDuty, Transit Gateway, CloudTrail no son gratis. En orgs pequeñas pueden representar 5–15 % del total.
- **Rigidez vs velocidad**: SCPs mal calibradas frenan equipos. El equilibrio es iterativo.
- **Lock-in**: Organizations, Control Tower, Landing Zone Accelerator son AWS-específicos. Mover la estructura a otro cloud es un rediseño.
- **FinOps sin cultura es cosmético**: dashboards sin rituales (review mensual, dueños nombrados, acciones priorizadas) no cambian la factura.
- **Un WAR cada 2 años no sirve**: la cadencia tiene que ser real (6–12 meses y post-cambio mayor).

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Dibujar la **landing zone mínima** (6–8 cuentas, 4 OUs, red hub-and-spoke) y explicar por qué cada pieza existe.
- Enumerar las **palancas FinOps** (SP, RI, Spot, Graviton, Compute Optimizer) y decir **cuándo** usar cada una.
- Calcular `$/MAU` y `$/req` a partir de datos de facturación + métricas de uso.
- Hacer un **walkthrough de Cost Explorer** escrito sin tocarlo.
- Elegir un **patrón DR** por workload con RPO/RTO y coste relativo.
- Conducir un **Well-Architected Review** sobre los 6 pilares, produciendo hallazgos priorizados.

Síntesis final en una frase:

> **Operar AWS como plataforma es la unión disciplinada de una landing zone bien pensada, un plan FinOps con unit economics y un ciclo WA repetido — cada una resuelve lo que las otras no pueden.**

Lo que **no** hace este módulo:

- No instala Control Tower.
- No ejecuta `aws` CLI.
- No lee tu factura real.

Lo que **sí** deja:

- Un ADR de landing zone defendible.
- Un reporte FinOps con `$/MAU` y `$/req` calculados.
- Un plan DR y una review WA listos para presentar al equipo.
