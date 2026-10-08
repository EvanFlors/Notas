# Blue-Green Deployments for Zero-Downtime Updates

![Blue-green deployment with instant traffic switching](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson04-blue-green-deployment.svg)

## ¿Qué es?

Un **progressive delivery pattern** controla cómo una nueva versión del modelo recibe tráfico de producción. En lugar de un corte binario "apaga v1, enciende v2", se usan patrones que **limitan el radio de daño** y permiten **rollback inmediato**. Los cuatro fundamentales:

### Blue-Green

Mantienes dos entornos idénticos: **Blue** (actual, recibe 100% de tráfico) y **Green** (nuevo, recibe 0%). Validas Green con smoke tests, luego **cambias el selector del Service** y el 100% de tráfico va a Green instantáneamente. Blue queda idle como seguro de rollback.

### Canary

Despliegas v2 junto a v1 y envías un **pequeño porcentaje** (5-10%) de tráfico a v2. Monitoreas métricas lado a lado. Si todo bien, incrementas (10% → 25% → 50% → 100%). Si algo falla, rollback = volver el porcentaje a 0.

### Shadow (dark launch / traffic mirroring)

**El patrón más seguro.** v2 corre en producción pero sus respuestas **no se sirven**. Cada request se envía a v1 (que responde al usuario) y una **copia** se envía a v2 (cuya respuesta se logea). Comparas outputs offline. Cero riesgo para usuarios; costo = doble inferencia durante el período shadow.

### A/B testing para modelos

Divide usuarios en cohortes aleatorias y mide **métricas de negocio** (CTR, conversión, revenue), no solo técnicas. Dura días o semanas hasta alcanzar significancia estadística. Puede combinarse con canary.

## ¿Por qué importa?

- **Reduce blast radius:** un bug que afectaría 100% de usuarios afecta 5%, dando tiempo a detectar y mitigar.
- **Rollback instantáneo:** un deploy incorrecto en producción es inevitable; lo que separa a los equipos buenos de los malos es cuán rápido pueden revertir.
- **Validación con producción real:** staging nunca refleja distribuciones reales. Shadow permite validarlo sin riesgo.
- **Confianza para iterar:** equipos que pueden deployar con seguridad lo hacen más seguido, aprenden más rápido y envían mejor producto.
- **Cumplimiento regulatorio:** finanzas y salud requieren documentar rollout gradual y evidencia de pruebas.

El costo de **no** usar estos patrones se mide en incidentes P0, SLO budget quemado, usuarios perdidos y burnout del equipo oncall.

## ¿Cómo funciona?

### Blue-Green con K8s: swap de selector

Dos Deployments (`sentiment-blue`, `sentiment-green`), un Service cuyo selector determina a cuál se enruta:

```yaml
# Antes del cutover: todo tráfico a blue
apiVersion: v1
kind: Service
metadata: { name: sentiment }
spec:
  selector: { app: sentiment, color: blue }
  ports: [ { port: 80, targetPort: 8000 } ]
```

Validas `green` por el ClusterIP o un Service separado (`sentiment-green-preview`). Cuando estás listo:

```bash
kubectl patch svc sentiment -p '{"spec":{"selector":{"app":"sentiment","color":"green"}}}'
```

Rollback = mismo patch volviendo a `blue`. Tiempo: segundos.

### Canary con K8s + Istio

```yaml
# Istio VirtualService: 90% v1, 10% v2
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: sentiment }
spec:
  hosts: [ sentiment ]
  http:
    - route:
        - destination: { host: sentiment, subset: v1 }
          weight: 90
        - destination: { host: sentiment, subset: v2 }
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata: { name: sentiment }
spec:
  host: sentiment
  subsets:
    - name: v1
      labels: { version: v1-3-0 }
    - name: v2
      labels: { version: v1-4-0 }
```

Promueves cambiando pesos: 10 → 25 → 50 → 100. Rollback: pesos a 0 en v2.

### Canary con feature flag (LaunchDarkly)

A diferencia del traffic split por red, las feature flags permiten controlar a **nivel de aplicación**: por usuario, por tenant, por región, por experimento.

```python
import ldclient
from ldclient import Context
from ldclient.config import Config

ldclient.set_config(Config("sdk-key-prod"))
client = ldclient.get()

def route_prediction(user_id: str, payload: dict) -> dict:
    ctx = Context.builder(user_id).kind("user").set("plan", "pro").build()
    # El flag retorna "v2" para 10% canary, "v1" para el resto
    variant = client.variation("sentiment-model-version", ctx, default="v1")
    if variant == "v2":
        return call_model("http://sentiment-v2.ml-prod:80/predict", payload)
    return call_model("http://sentiment-v1.ml-prod:80/predict", payload)
```

El panel de LaunchDarkly / Unleash / Flagsmith permite cambiar el porcentaje sin deploy. Rollback = porcentaje a 0.

### Shadow (traffic mirroring)

![Canary deployment with gradual traffic shifting and monitoring](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson04-canary-deployment.svg)

**Explicación detallada del patrón shadow:**

1. El request llega al proxy (Envoy, Istio, NGINX con `mirror` directive).
2. El proxy envía el request al servicio **primario** (v1) y espera su respuesta.
3. Al mismo tiempo, el proxy clona el request y lo envía **async** al servicio **shadow** (v2).
4. La respuesta de v2 se **descarta** (o se logea en un topic Kafka para análisis offline).
5. El usuario recibe la respuesta de v1 — **jamás nota que v2 existe**.
6. Un pipeline offline compara pares `(input, output_v1, output_v2)` y calcula métricas de concordancia y mejora.

```yaml
# Istio: 100% a v1, mirror 100% a v2
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: sentiment }
spec:
  hosts: [ sentiment ]
  http:
    - route:
        - destination: { host: sentiment, subset: v1 }
          weight: 100
      mirror: { host: sentiment, subset: v2 }
      mirrorPercentage: { value: 100.0 }
```

```yaml
# Envoy filter equivalente
request_mirror_policies:
  - cluster: sentiment-v2
    runtime_fraction:
      default_value: { numerator: 100, denominator: HUNDRED }
    trace_sampled: false
```

Después, un job Spark analiza los logs:

```python
# shadow_analysis.py
from pyspark.sql import functions as F
df = spark.read.parquet("s3://logs/shadow/sentiment/dt=2026-10-07/")

# Métricas de concordancia
agree = df.filter(F.col("label_v1") == F.col("label_v2")).count() / df.count()
# Diferencias significativas de score
diff = df.withColumn("delta", F.abs(F.col("score_v1") - F.col("score_v2"))) \
         .agg(F.avg("delta"), F.expr("percentile(delta, 0.99)")).collect()
# Golden set accuracy (sub-muestra etiquetada por humanos)
golden = df.filter(F.col("golden_label").isNotNull())
acc_v1 = golden.filter(F.col("label_v1") == F.col("golden_label")).count() / golden.count()
acc_v2 = golden.filter(F.col("label_v2") == F.col("golden_label")).count() / golden.count()
```

Si `acc_v2 > acc_v1` con significancia estadística, promueves v2 a primario.

### Automated canary analysis con Flagger

**Flagger** (sobre Istio/Linkerd/Contour) ejecuta la promoción automáticamente leyendo métricas de Prometheus:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata: { name: sentiment, namespace: ml-prod }
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sentiment
  service:
    port: 80
    targetPort: 8000
  analysis:
    interval: 1m
    threshold: 5                 # 5 fallos consecutivos → rollback
    stepWeight: 10               # +10% cada iteración
    maxWeight: 50                # máximo canary 50% antes de promover
    metrics:
      - name: request-success-rate
        thresholdRange: { min: 99 }       # min 99% éxito
        interval: 1m
      - name: request-duration-p99
        thresholdRange: { max: 500 }      # p99 < 500ms
        interval: 1m
      - name: model-drift-score
        templateRef: { name: drift-metric }
        thresholdRange: { max: 0.15 }     # drift KL < 0.15
    webhooks:
      - name: smoke-test
        type: pre-rollout
        url: http://flagger-loadtester.test/
        timeout: 30s
        metadata:
          cmd: "hey -z 1m -q 50 -c 5 http://sentiment-canary/predict"
```

Flagger incrementa el peso automáticamente mientras las métricas estén en umbral; si fallan, rollback.

### Argo Rollouts (alternativa a Flagger)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata: { name: sentiment }
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 5
        - pause: { duration: 10m }
        - analysis: { templates: [ { templateName: success-rate } ] }
        - setWeight: 25
        - pause: { duration: 20m }
        - setWeight: 50
        - pause: { duration: 30m }
        - setWeight: 100
```

### Tabla comparativa de patterns

| Pattern | Tiempo deploy | Costo infra | Riesgo usuario | Rollback | Mejor para |
|---|---|---|---|---|---|
| Big-bang (sin pattern) | Minutos | 1x | Alto (100%) | Lento | Nunca |
| Blue-Green | Minutos | 2x durante deploy | Bajo si validas Green | Instantáneo (swap) | Sistemas stateless con alta confianza |
| Canary (traffic split) | Horas a días | 1.05-1.5x | Limitado al % canary | Instantáneo (reset %) | Default para la mayoría de modelos |
| Canary (feature flag) | Horas a días | 1x | Limitado al % flag | Instantáneo (toggle) | Control fino por usuario/tenant |
| Shadow | Días (validación) | 2x durante shadow | **Cero** | N/A (no sirve traffic) | Modelos críticos, cambios algorítmicos |
| A/B test | Semanas | 1.05-1.5x | Limitado | Instantáneo | Validar impacto en métricas de negocio |

### Fórmulas y umbrales

**Error budget (Google SRE):**

```
error_budget = (1 - SLO) × total_requests_en_ventana
# Ejemplo: SLO 99.9%, 10M req/mes → budget = 10,000 errores/mes
# burn rate = errores_actuales / budget. Si burn > 1x por 1h → alerta. Si > 10x → rollback inmediato.
```

**Umbral de rollback automático:**

```
rollback_if:
    error_rate_v2 > error_rate_v1 × 1.5    (y n > 10,000 requests)
  OR
    latency_p99_v2 > latency_p99_v1 × 1.3
  OR
    drift_kl(output_v2, output_v1) > 0.2
```

**Significancia estadística (z-score para dos proporciones):**

```
p_pool = (errors_v1 + errors_v2) / (n_v1 + n_v2)
se = sqrt( p_pool × (1 - p_pool) × (1/n_v1 + 1/n_v2) )
z = (error_rate_v2 - error_rate_v1) / se
# |z| > 1.96 → significativo al 95%; > 2.58 → 99%
```

### Rollback strategies

- **Automatizado por métrica:** Flagger/Argo Rollouts detectan degradación y revierten en segundos.
- **Instantáneo manual:** `helm rollback`, `kubectl argo rollouts abort`, `kubectl patch svc` para blue-green.
- **GitOps revert:** `git revert <sha> && git push` → ArgoCD reaplica estado anterior en ~1 min.
- **Feature flag kill switch:** toggle a 0% desde el dashboard, sin tocar infra.
- **Snapshot de modelo:** siempre mantén los 3 últimos modelos en S3 con tags inmutables.

## Ejemplo con código

Script Python de rollback automático que monitorea Prometheus y revierte vía Argo Rollouts:

```python
# auto_rollback.py
import time, subprocess, requests, sys

PROM = "http://prometheus.monitoring:9090/api/v1/query"
ROLLOUT = ("sentiment", "ml-prod")
BASELINE_ERROR = 0.005        # 0.5%
MAX_FACTOR = 1.5
WINDOW = "5m"
MIN_SAMPLES = 10_000

def q(expr: str) -> float:
    r = requests.get(PROM, params={"query": expr}, timeout=5).json()
    return float(r["data"]["result"][0]["value"][1]) if r["data"]["result"] else 0.0

def check():
    canary_err = q(f'sum(rate(http_requests_total{{app="sentiment",version="canary",code=~"5.."}}[{WINDOW}])) '
                   f'/ sum(rate(http_requests_total{{app="sentiment",version="canary"}}[{WINDOW}]))')
    canary_n   = q(f'sum(increase(http_requests_total{{app="sentiment",version="canary"}}[{WINDOW}]))')
    canary_p99 = q(f'histogram_quantile(0.99, sum by (le) '
                   f'(rate(http_request_duration_seconds_bucket{{app="sentiment",version="canary"}}[{WINDOW}])))')
    stable_p99 = q(f'histogram_quantile(0.99, sum by (le) '
                   f'(rate(http_request_duration_seconds_bucket{{app="sentiment",version="stable"}}[{WINDOW}])))')

    print(f"canary: err={canary_err:.4f} n={int(canary_n)} p99={canary_p99*1000:.0f}ms "
          f"stable_p99={stable_p99*1000:.0f}ms")

    if canary_n < MIN_SAMPLES:
        return "wait"
    if canary_err > BASELINE_ERROR * MAX_FACTOR:
        return f"rollback: error_rate {canary_err:.4f} > {BASELINE_ERROR*MAX_FACTOR:.4f}"
    if stable_p99 > 0 and canary_p99 > stable_p99 * 1.3:
        return f"rollback: p99 {canary_p99:.3f}s > stable {stable_p99:.3f}s × 1.3"
    return "ok"

def abort_rollout():
    subprocess.run(["kubectl", "argo", "rollouts", "abort",
                    ROLLOUT[0], "-n", ROLLOUT[1]], check=True)
    subprocess.run(["kubectl", "argo", "rollouts", "undo",
                    ROLLOUT[0], "-n", ROLLOUT[1]], check=True)
    # Alerta a PagerDuty / Slack
    requests.post("https://hooks.slack.com/...", json={
        "text": f":rotating_light: Auto-rollback de {ROLLOUT[0]}"
    })

if __name__ == "__main__":
    for _ in range(60):   # 60 × 60s = 1 hora
        verdict = check()
        if verdict.startswith("rollback"):
            print("ABORT:", verdict)
            abort_rollout()
            sys.exit(1)
        time.sleep(60)
    print("Canary saludable tras 1h")
```

## Errores comunes

- **Deploy directo a 100%.** El error número uno. Siempre canary (al menos 5% por 15 min) incluso para hotfixes.
- **No tener rollback plan documentado.** Durante un incidente a las 3 AM, nadie recuerda los comandos. Documenta y practica.
- **Umbrales muy sensibles → false positives.** Rollback en cada spike aleatorio erosiona la confianza del equipo en los pipelines.
- **Umbrales muy laxos → false negatives.** El bug llega a 100% antes de dispararse la alerta.
- **No esperar significancia estadística.** Con 1000 requests y 1 error extra, declarar "v2 es peor" es ruido, no señal.
- **Shadow sin análisis offline.** El patrón solo tiene valor si tienes el pipeline de comparación. Si no, solo duplicas costo.
- **Shadow en modelos no-idempotentes.** Si v2 escribe a BD/trigger webhooks, duplicarás side effects. Shadow solo para inferencia pura o con flags de "dry-run".
- **Blue-Green sin aislamiento de estado.** Si ambos entornos escriben a la misma BD, el swap puede inconsistir datos. Haz migraciones backward-compatible.
- **Feature flags acumuladas.** 500 flags activas = complejidad combinatoria. Lifecycle: crear, canary, 100%, limpiar código.
- **No monitorear métricas de negocio.** Técnicas (error, latency) pueden estar OK y aun así el modelo nuevo bajar conversión 10%.
- **Rollout en horas pico / viernes PM.** Si falla, el oncall sufre. Rollout en horas de baja y días con equipo activo.
- **Canary con tráfico sticky mal configurado.** Si el load balancer hace sticky session, los mismos pocos usuarios ven v2 siempre y el muestreo es sesgado.

## Contexto industrial

- **Google** acuñó el término "progressive rollout"; su stack interno (Spanner, Borg) deploya con canaries de 0.1% → 1% → 10% → 100% sobre semanas.
- **Netflix** creó **Spinnaker** (ahora CNCF) y **Kayenta** (automated canary analysis), hoy evolucionados a **Managed Delivery**.
- **Meta** canariza a nivel de cells (datacenters), con sistemas propios como **Conveyor** y **PackMan**.
- **Stripe** promueve "deploy anytime culture": miles de deploys/día posibles por el stack de canary + feature flags.
- **Anthropic y OpenAI** aplican **model deprecation policies** con 6+ meses de aviso: nuevas versiones salen en modo canary, los clientes pueden fijar versiones concretas, y los deprecated models se mantienen durante el período de migración.
- **Google** anunció Gemini 1.5 primero a 0.1% de usuarios Workspace antes de generalizarlo.
- **Microsoft Azure OpenAI** usa deployment slots (equivalente blue-green) para rollouts regionales.

Herramientas industriales: **Spinnaker**, **Argo Rollouts**, **Flagger**, **Istio**, **Linkerd**, **Envoy**, **LaunchDarkly**, **Unleash**, **Flagsmith**, **Split.io**, **Statsig**, **Harness**, **CodeFresh**.

## Resumen

- **Blue-Green** = dos entornos, swap atómico, rollback instantáneo, costo 2x durante deploy.
- **Canary** = introducción gradual de tráfico a v2, monitoreo lado a lado, pattern default para la mayoría de modelos.
- **Shadow** = v2 ejecuta en producción pero no sirve respuestas; el patrón más seguro, costo doble inferencia temporal.
- **A/B testing** = evaluación con métricas de negocio sobre semanas; combina con canary.
- **Feature flags** (LaunchDarkly, Unleash) permiten canary **por usuario/tenant/región** y kill switch instantáneo.
- **Flagger** y **Argo Rollouts** automatizan canary analysis leyendo Prometheus.
- Define y automatiza **umbrales de rollback**: error rate, p99 latency, drift. Siempre con significancia estadística.
- **Error budget** (SRE) formaliza cuánto "incidente" tolera un SLO antes de pausar deploys.
- Nunca despliegues sin **rollback plan practicado**: GitOps revert, Helm rollback, kill switch de feature flag.
- Cultura: deploys **pequeños, frecuentes, automáticos, reversibles y observables**. Blameless post-mortems para aprender.
