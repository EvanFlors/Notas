# ADR (reference) — k8s-01-01: Adopción de Kubernetes para Panadería SaaS

> Autoevaluación. **No** es una respuesta única — es *una* respuesta profesional y defendible. Si tu ADR argumenta "sí, adoptar K8s" con criterios equivalentes, también es válido.

## Contexto

Panadería SaaS es una startup de 4 personas (2 backend, 1 frontend, 1 DevOps a medias). Producto en producción: un backend FastAPI + un frontend Next.js + Postgres managed en RDS. Tráfico: ~200 req/min en pico, 50 clientes de pago. Actualmente corre con **Docker Compose en un único VPS de DigitalOcean**, lo cual ha funcionado 18 meses sin incidentes materiales. El CTO propone migrar a Kubernetes tras una conferencia; no hay un driver técnico explícito (no hay dolor concreto que K8s resolvería hoy).

Datos relevantes para la decisión:

- **Equipo** sin experiencia previa operando K8s en producción.
- **Postgres fuera del cluster** (RDS managed) — la parte stateful ya está delegada.
- **Un solo servicio real** (FastAPI backend) + frontend estático.
- **Carga baja y previsible** (~200 req/min).
- **Bus-factor actual**: el VPS lo gestiona 1 persona a medias.

## Decisión

**No adoptamos Kubernetes en este momento.** Mantenemos Docker Compose sobre VPS, con dos mejoras incrementales inmediatas (snapshots automáticos del VPS + health checks + un segundo VPS en standby con script de failover manual). Revisaremos esta decisión cuando se cumpla **cualquiera** de los disparadores de la sección siguiente.

El criterio es: K8s resuelve problemas que **todavía no tenemos** y añade una carga operacional que **no podemos sostener** con 4 personas.

## Consecuencias y disparadores (triggers)

### Consecuencias de la decisión

**Ganamos**:

- Cero carga operacional adicional. El equipo sigue enfocado en producto.
- Costo infra mínimo (~$20–40/mes de VPS vs ~$150–300/mes de EKS + nodos + observabilidad).
- Decisiones de arquitectura reversibles — no hay lock-in de policies, operators ni CRDs.

**Perdemos** (y lo asumimos):

- **Rollouts sin downtime** no son nativos; cada deploy tiene ~30s de downtime. Aceptable para 200 req/min.
- **Bus-factor alto**: una sola persona entiende el VPS. Mitigamos con documentación + runbook + segundo VPS en standby.
- **Self-healing manual**: si el VPS se cae, hay que levantarlo. Mitigamos con alertas + snapshots + script de failover al standby.
- **No autoscaling**: el VPS tiene capacidad para ~10x el tráfico actual; cuando se acerque, es un disparador.

### Disparadores para revisar la decisión (concretos y medibles)

Si **cualquiera** se cumple, se reabre este ADR:

1. **Tráfico sostenido > 2000 req/min** o necesidad de > 3 instancias de la app detrás de un LB.
2. **Equipo crece a > 10 ingenieros** con necesidad de aislar entornos por equipo/producto.
3. **> 5 servicios independientes** con ciclos de vida distintos y necesidad de rollout coordinado.
4. **Requisito contractual** de **rollouts sin downtime** (SLA 99.9%+ con cláusula explícita).
5. **Requisitos regulatorios** (SOC2, HIPAA, PCI DSS) que exijan NetworkPolicies, auditoría centralizada o aislamiento de workloads tipo cluster.
6. **Necesidad de autoscaling** basado en métricas custom (longitud de cola, tiempo medio de respuesta) — HPA + KEDA es el patrón natural.
7. **Hiring explícito** de 2+ ingenieros con experiencia operacional de K8s y mandato de construir plataforma.

## Alternativas descartadas

### Mantener Docker Compose + VPS (status quo mejorado)

- **Pros**: cero migración, equipo lo opera hoy, costo mínimo.
- **Contras**: bus-factor, downtime en deploys, scaling manual.
- **Cuándo sí**: carga baja, equipo pequeño, una sola app principal. **Es lo que elegimos**, con mejoras (snapshots, standby, runbook).

### Managed K8s (EKS / GKE / AKS)

- **Pros**: estándar de la industria, portabilidad, mejor historia a largo plazo si crecemos mucho.
- **Contras**: ~$73/mes solo el control plane de EKS + nodos + observabilidad (Prometheus/Grafana) + ingeniería de plataforma (Argo CD, policies, admission, upgrades, cert-manager). Para 4 personas sin experiencia previa, la curva es alta.
- **Cuándo sí**: cuando se cumpla alguno de los disparadores — especialmente el 2 (equipo creciendo) o el 3 (muchos servicios).

### Nomad (HashiCorp)

- **Pros**: un solo binario, orquesta contenedores y binarios, ecosistema HashiCorp (Consul, Vault), curva mucho más suave.
- **Contras**: ecosistema mucho menor, mercado laboral más chico, menos "estándar".
- **Cuándo sí**: equipo pequeño que **sí** necesita orquestación pero quiere evitar la carga de K8s. Para esta startup, antes que K8s si llega el caso.

### ECS Fargate (AWS)

- **Pros**: contenedores sin cluster que operar, integrado con el resto de AWS, scaling automático. Buen "escalón intermedio" entre Compose y K8s.
- **Contras**: lock-in AWS, menos extensibilidad (no CRDs, no admission policies ricas), skill menos portable.
- **Cuándo sí**: si ya están comprometidos con AWS y RDS, y el disparador 1 (tráfico) o el 3 (más servicios) se cumple **antes** que los demás.

### Cloud Run / App Runner / Fly.io

- **Pros**: PaaS puro sobre contenedores; cero infra que operar; buen fit para APIs HTTP sin estado.
- **Contras**: límites de cold-start, menos control sobre red/scheduling, costo por request puede escalar mal con tráfico sostenido alto.
- **Cuándo sí**: pico de tráfico muy variable con largos periodos de baja actividad. No es el caso aquí (tráfico pequeño pero sostenido).

### Serverless puro (Lambda / Cloud Functions)

- **Pros**: cero servidor que operar, pagas por invocación, excelente para spikes.
- **Contras**: refactor del backend FastAPI (handler-por-handler, cold starts, timeouts, SQLAlchemy en Lambda es doloroso).
- **Cuándo sí**: endpoints específicos (webhook de Stripe, cron de reportes) — **complementario**, no reemplazo.

## Preguntas obligatorias

1. El costo oculto más grande es la **ingeniería de plataforma continua**: alguien tiene que mantener el cluster al día (upgrades cada 3–4 meses porque las versiones de K8s tienen soporte limitado), gestionar admission policies, actualizar Argo CD, mantener dashboards, responder a CVEs de la cadena de suministros, lidiar con APIs deprecadas entre upgrades. Para una startup de 4 personas eso es **el 20–40% del tiempo de 1 persona** — en una empresa de 100 personas se diluye, en una de 4 compite directamente con el roadmap de producto.

2. Postgres en RDS significa que **el estado está fuera del cluster**. Gran parte del valor de K8s (StatefulSets, PVCs, storage orchestration, operadores de bases de datos) ya no aplica. El resto del valor (self-healing, rolling updates, scheduling) sigue aplicando, pero para **un solo servicio stateless** es como usar un bazooka para matar una mosca. La proporción valor/complejidad baja mucho cuando el estado ya está delegado.

3. Managed no elimina: (a) **upgrades del cluster** — EKS obliga a planificar ventanas y a validar que tus manifests no usan APIs deprecadas; (b) **elección y operación de add-ons** — tienes que elegir CNI, ingress controller, cert-manager, observabilidad, policy engine, autoscaler; (c) **RBAC, admission policies, seguridad** — nada viene "configurado para prod"; (d) **CSI/CNI** correctamente configurados — p. ej. EBS CSI tiene su propia IAM; (e) **costos** — tanto del control plane (EKS cobra $0.10/h ≈ $73/mes por cluster) como de nodos, LBs, observabilidad.

4. "Adoptamos K8s para contratar mejor" es **defendible** cuando: (a) ya tienes el equipo y la plataforma montada y K8s es simplemente la elección estándar; (b) tu dominio es ingeniería de plataforma y vendes esa expertise. Es **antipatrón** cuando: (a) adoptas K8s para atraer talento que *luego* montará la plataforma (poner la tecnología antes que la necesidad); (b) descartas candidatos buenísimos en Nomad/ECS/Compose porque "no saben K8s", perdiendo señal real de skill; (c) el equipo que llega se frustra porque la realidad es "Compose en una VM con K8s pintado encima".

5. **Escenario donde K8s sí es la respuesta aquí**: la startup firma un contrato enterprise con un cliente grande que exige: (a) SLA 99.95%, (b) auditoría SOC2 que incluye NetworkPolicies y RBAC auditable, (c) rollouts sin downtime para 3 servicios independientes (frontend, backend, worker de reportes), (d) el equipo ha crecido a 10 ingenieros con mandato explícito de "plataforma interna". En ese contexto, EKS + Argo CD + Kyverno + Prometheus Operator se paga solo.

6. **Compose en VM**: lo que tienen. Cero infra que operar más allá del VPS; cero orquestación; deploy = `docker compose up`. **ECS Fargate**: scheduling y rolling update gestionados por AWS; sin cluster que operar; menos extensibilidad y lock-in AWS, pero **enorme** escalón intermedio antes de K8s. Para una startup en AWS que necesita rollouts sin downtime pero no quiere operar un cluster, es la respuesta más honesta.

7. El disparador que primero reabriría este ADR en Panadería SaaS es probablemente el **#3 (más de 5 servicios con ciclos de vida distintos)**: pasa cuando el producto crece y aparecen worker de reportes, servicio de notificaciones, API para integraciones B2B, panel admin separado, etc. Lo mediría con un conteo de "servicios independientes en producción" revisado trimestralmente. Si llegamos a 5+ con rollouts coordinados entre ellos, Compose empieza a doler y K8s (o ECS) deja de ser overkill.
