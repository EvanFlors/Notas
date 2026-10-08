# Fundamentos de AIOps: operar sistemas de IA en producción

## ¿Qué es?

**AIOps (AI Operations)** es la disciplina que se encarga de **desplegar, monitorear y mantener sistemas de inteligencia artificial en producción**. Combina prácticas de DevOps (infraestructura y entregas continuas), MLOps (ciclo de vida de modelos de machine learning) y conocimiento específico sobre el comportamiento de modelos probabilísticos cuando interactúan con usuarios reales.

A diferencia del software tradicional, donde la misma entrada produce la misma salida, los sistemas de IA son **probabilísticos**: dependen de datos de entrenamiento, versión del modelo, semillas aleatorias y hasta de la temperatura del muestreo. Esto significa que un servicio puede estar "verde" en todos los indicadores clásicos (CPU, memoria, latencia, códigos HTTP 200) y aun así estar **degradando silenciosamente** su calidad de predicción.

> **Idea clave:** en software tradicional, "sin errores" suele equivaler a "funciona". En IA, "sin errores" solo significa "el servicio responde"; la calidad del contenido de esa respuesta es un problema aparte y requiere su propio sistema de observabilidad.

### AIOps vs MLOps vs DevOps vs LLMOps

![Comparación de alcances operativos de DevOps, MLOps y AIOps](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-devops-mlops-aiops-comparison.svg)

Es común confundir estos cuatro términos. Cada uno cubre un alcance distinto y responde a necesidades distintas:

| Dimensión | DevOps | MLOps | AIOps | LLMOps |
|---|---|---|---|---|
| **Objeto que opera** | Aplicaciones y servicios de software | Pipelines de entrenamiento y modelos de ML | Sistemas de IA en producción (end-to-end) | Modelos de lenguaje grandes y aplicaciones RAG/agentes |
| **Artefactos versionados** | Código, infraestructura | Código + datos + modelos + experimentos | Todo lo anterior + prompts, políticas, reglas de negocio | Prompts, embeddings, índices vectoriales, cadenas, herramientas |
| **Métrica base** | Latencia, errores, throughput | Accuracy, F1, loss en validación | Calidad de predicción + impacto de negocio | Toxicidad, factualidad, costo por token, tasa de alucinación |
| **Tipo de fallos** | Determinísticos (crash, 500, timeout) | Entrenamientos que no convergen, pipelines rotos | Fallos silenciosos (drift, degradación de calidad) | Alucinaciones, jailbreaks, prompt injection, deriva semántica |
| **Loop de feedback** | Minutos | Horas/días | Días/semanas | Horas (con eval LLM-as-judge) o días (con feedback humano) |
| **Herramientas típicas** | Jenkins, ArgoCD, Terraform, Prometheus | MLflow, Weights & Biases, DVC, Kubeflow | Evidently, Arize, WhyLabs, Fiddler | LangSmith, Langfuse, Helicone, Phoenix |
| **Rol responsable** | SRE / Platform engineer | ML engineer | AI engineer / ML platform | AI engineer / Prompt engineer |

En términos de inclusión conceptual:

```
DevOps  ⊂  MLOps  ⊂  AIOps
                    └── LLMOps (caso especial para modelos generativos)
```

MLOps extiende DevOps añadiendo versionado de datos y modelos, experiment tracking y pipelines de entrenamiento. **MLOps lleva un modelo hasta el despliegue; AIOps lo mantiene útil después del despliegue**. LLMOps es un sub-caso de AIOps enfocado en los retos específicos de los LLMs: prompts, contexto, costo por token y evaluación subjetiva.

### Las señales doradas de SRE adaptadas a IA

El libro *Site Reliability Engineering* de Google definió las **cuatro señales doradas** para monitorear cualquier servicio: latencia, tráfico, errores y saturación. Para sistemas de IA, no bastan: hay que extenderlas con dos señales nuevas:

| Señal | Software tradicional | Sistema de IA | Cómo medirla |
|---|---|---|---|
| **Latencia** | Tiempo de respuesta HTTP | Tiempo de inferencia + pre/post-procesamiento | p50, p95, p99 en Prometheus/Grafana |
| **Tráfico** | Requests por segundo | Predicciones por segundo, tokens/segundo | Contador acumulado |
| **Errores** | 5xx, excepciones | Timeouts del modelo, OOM, respuestas inválidas | Rate = errores/total |
| **Saturación** | CPU/RAM | GPU utilization, memoria VRAM, cola de batching | nvidia-smi, DCGM exporter |
| **Costo** (nuevo) | Irrelevante o estable | $/predicción, $/1K tokens | Billing por endpoint |
| **Calidad** (nuevo) | Implícita en "no errores" | Accuracy, F1, drift, factualidad | Evaluación continua offline + online |

Las dos últimas son **específicas de IA** y son las que distinguen a AIOps de SRE tradicional.

### Modos de fallo únicos de los sistemas de IA

Los sistemas de IA fallan de maneras que no existen en el software tradicional:

- **Fallos silenciosos:** el modelo responde con alta confianza predicciones incorrectas. No hay excepción, no hay 500, no hay alerta.
- **Data drift:** la distribución de los inputs cambia con el tiempo (nuevos usuarios, nuevos dispositivos, estacionalidad).
- **Concept drift:** la relación entre input y output cambia (durante COVID, los patrones de compra se invirtieron en días).
- **Model staleness:** un modelo entrenado hace 12 meses puede ser inútil hoy sin que su código haya cambiado una línea.
- **Feedback loops perversos:** un recomendador que solo sugiere lo popular refuerza su propio sesgo hasta colapsar la diversidad.
- **Training-serving skew:** las features se calculan distinto en entrenamiento y en producción, y el modelo ve inputs que nunca vio durante training.

## ¿Por qué importa?

Un modelo que logra 92% de accuracy en Jupyter representa aproximadamente el 10% del trabajo real de llevarlo a producción. El 90% restante es ingeniería de operaciones: cómo lo sirves, cómo lo monitoreas, cómo lo versionas, cómo lo reemplazas cuando falle y cómo controlas su costo.

Las consecuencias de no tener una práctica sólida de AIOps son concretas y caras:

- **Pérdida de ingresos silenciosa:** un recomendador que degradó 15% su CTR durante tres semanas sin alertar pudo costar millones en ventas no capturadas.
- **Facturas de GPU descontroladas:** sin autoscaling y sin atribución por feature o cliente, es fácil pasar de $5K a $50K/mes sin notarlo hasta que llega la factura.
- **Incidentes irreproducibles:** cuando el modelo baja de 92% a 78% y no sabes qué datos, qué código y qué hiperparámetros lo produjeron, debuggear se vuelve imposible.
- **Riesgo regulatorio:** GDPR, el AI Act europeo y regulaciones sectoriales (finanzas, salud) exigen trazabilidad, explicabilidad y auditoría. Sin AIOps es imposible cumplir.
- **Erosión de confianza:** cada alucinación de un chatbot, cada recomendación discriminatoria, cada falso positivo en antifraude degrada la confianza del usuario y es muy difícil recuperarla.

### Un ejemplo típico

Imagina que has desplegado un sistema de recomendaciones. Durante dos semanas todo luce perfecto:

- Uptime: 100%
- Latencia p99: 180ms (dentro de SLO)
- Error rate: 0.01%
- CPU/RAM: utilización normal

Y sin embargo, el CTR cae del 8% al 5.5%. Los usuarios reportan que "las recomendaciones ya no son relevantes". Ningún dashboard tradicional detecta esto porque **ninguna métrica tradicional mide calidad de predicción**. AIOps es precisamente el conjunto de prácticas que agrega esa capa faltante.

## ¿Cómo funciona?

### El ciclo de vida completo de un sistema de IA

AIOps no es un paso al final del proceso, es la práctica que atraviesa **todo el ciclo de vida**:

```
Ingesta de datos
      ↓
Entrenamiento (train)
      ↓
Evaluación (eval offline)
      ↓
Despliegue (deploy)
      ↓
Monitoreo (monitor)
      ↓
Re-entrenamiento (retrain) ──┐
      ↑                      │
      └──────────────────────┘
```

Cada transición entre fases es un punto donde las prácticas operativas marcan la diferencia entre un sistema confiable y uno frágil. **El ciclo es cíclico, no lineal**: nunca se "termina" un sistema de IA; se itera continuamente.

### El modelo de madurez MLOps/AIOps (Databricks)

Databricks publicó un modelo de madurez útil para evaluar dónde está tu organización:

| Nivel | Nombre | Características |
|---|---|---|
| 0 | Manual | Notebooks, despliegues manuales, sin versionado, sin monitoreo |
| 1 | Reproducible | Código en Git, entornos en Docker, experimentos trackeados |
| 2 | Automatizado | CI/CD para entrenamiento, model registry, despliegue automatizado |
| 3 | Monitoreado | Observabilidad de predicciones, drift detection, alerting |
| 4 | Auto-adaptable | Re-entrenamiento automático disparado por drift, A/B testing continuo |

La mayoría de organizaciones está entre el nivel 1 y 2. Llegar al nivel 3-4 es lo que distingue a los sistemas de IA que escalan de los que se vuelven ingobernables.

### Entornos de entrenamiento vs. de serving

Estos dos entornos son fundamentalmente distintos y confundirlos es una fuente constante de bugs en producción:

| Aspecto | Entrenamiento | Serving (inferencia) |
|---|---|---|
| Optimiza | Throughput, exactitud | Latencia, concurrencia |
| Tamaño de batch | Grande (256, 1024, 4096) | Pequeño (1-32) con batching dinámico |
| Hardware típico | GPUs A100/H100 de 40-80GB | GPUs T4/A10 o Inferentia, incluso CPUs |
| Duración | Horas o días | Milisegundos por request |
| Tolerancia a fallo | Alta (reintenta job) | Baja (usuario esperando) |
| Datos | Dataset completo histórico | Features del momento actual |
| Costo | Pico corto, controlable | Continuo, debe optimizarse |

### Reproducibilidad: la base de todo

Para que un sistema de IA sea mantenible en producción, cada predicción debe poder trazarse al **conjunto exacto de artefactos** que la produjo:

```
Predicción  ←  Modelo (v2.3.1)
              ├── Código (git commit abc123)
              ├── Datos de entrenamiento (DVC hash xyz789)
              ├── Hiperparámetros (config.yaml v4)
              ├── Dependencias (requirements.lock)
              └── Infraestructura (Docker image sha256:...)
```

Sin esta trazabilidad, cuando el modelo falle en producción no podrás reconstruir qué pasó. Herramientas como **MLflow**, **Weights & Biases**, **DVC** y **LakeFS** están diseñadas precisamente para esto.

## Ejemplo con código

A continuación un ejemplo mínimo pero completo que ilustra las piezas básicas de un sistema AIOps: definición de SLOs, tracking de costo por request y detección de drift.

```python
# ============================================================
# 1. Definición de SLOs con error budget
# ============================================================
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass
class SLO:
    """Service Level Objective para un endpoint de IA."""
    name: str
    target: float          # ej. 0.995 = 99.5% de requests deben cumplir
    window_days: int = 30  # ventana rodante

    def error_budget(self, total_requests: int) -> int:
        """Cantidad máxima de 'bad events' permitidos en la ventana."""
        return int(total_requests * (1 - self.target))

    def budget_remaining(self, total: int, bad: int) -> float:
        """Porcentaje de budget restante. Negativo = SLO violado."""
        budget = self.error_budget(total)
        return 1 - (bad / budget) if budget > 0 else 0.0


# SLOs típicos para un recomendador en producción
slos = [
    SLO("latency_p95_200ms",       target=0.95),
    SLO("latency_p99_500ms",       target=0.99),
    SLO("error_rate_below_1pct",   target=0.99),
    SLO("prediction_quality_ctr",  target=0.90, window_days=7),
]

# Formula general: SLO = 1 - (bad_events / total_events)
# Error budget = (1 - SLO) * total_events


# ============================================================
# 2. Tracking de costo por request (atribución por tenant)
# ============================================================
from collections import defaultdict

class CostTracker:
    """Costo acumulado por modelo, endpoint y cliente."""
    # Precios aproximados por 1K tokens (septiembre 2025)
    PRICES_PER_1K_TOKENS = {
        "gpt-4o":           {"in": 0.0025, "out": 0.010},
        "claude-sonnet-4":  {"in": 0.003,  "out": 0.015},
        "llama-3.1-70b":    {"in": 0.0004, "out": 0.0004},  # autohospedado
    }

    def __init__(self):
        self.costs = defaultdict(float)

    def record(self, model: str, tenant: str, feature: str,
               tokens_in: int, tokens_out: int) -> float:
        p = self.PRICES_PER_1K_TOKENS[model]
        cost = (tokens_in / 1000) * p["in"] + (tokens_out / 1000) * p["out"]
        self.costs[(model, tenant, feature)] += cost
        return cost

    def report(self):
        print(f"{'Modelo':<20} {'Cliente':<15} {'Feature':<20} {'Costo USD'}")
        for (m, t, f), c in sorted(self.costs.items(),
                                   key=lambda x: -x[1]):
            print(f"{m:<20} {t:<15} {f:<20} ${c:>8.4f}")


# ============================================================
# 3. Detección simple de data drift (test KS)
# ============================================================
import numpy as np
from scipy.stats import ks_2samp

def detect_drift(reference: np.ndarray, current: np.ndarray,
                 alpha: float = 0.05) -> dict:
    """Compara distribuciones usando Kolmogorov-Smirnov.

    reference: muestra de la distribución de entrenamiento.
    current:   muestra reciente de producción.
    """
    stat, p_value = ks_2samp(reference, current)
    return {
        "ks_statistic": float(stat),
        "p_value":      float(p_value),
        "drift_detected": p_value < alpha,
    }


# ============================================================
# 4. Pipeline simplificado con Prefect
# ============================================================
# pip install prefect
from prefect import flow, task

@task(retries=3, retry_delay_seconds=60)
def ingest_data():
    """Descarga datos nuevos del data warehouse."""
    print("Ingiriendo datos...")
    return np.random.randn(10_000)

@task
def validate_data(data):
    """Verifica que los datos tengan calidad mínima."""
    assert len(data) > 1000, "Dataset insuficiente"
    assert not np.isnan(data).any(), "Nulos detectados"
    return data

@task
def check_drift(reference, current):
    result = detect_drift(reference, current)
    if result["drift_detected"]:
        print(f"ALERTA: drift detectado (p={result['p_value']:.4f})")
    return result

@task
def train_if_needed(drift_result, data):
    if drift_result["drift_detected"]:
        print("Reentrenando modelo...")
        # ... código de entrenamiento ...
        return {"model_version": "v2.4.0", "accuracy": 0.93}
    return None

@flow(name="aiops-daily-check")
def daily_pipeline(reference_data: np.ndarray):
    data = ingest_data()
    data = validate_data(data)
    drift = check_drift(reference_data, data)
    new_model = train_if_needed(drift, data)
    return new_model

if __name__ == "__main__":
    reference = np.random.randn(10_000)
    daily_pipeline(reference)
```

### Definición de un SLO en Prometheus

Los SLOs no viven en código Python: viven como reglas de alerting en tu stack de observabilidad. Un ejemplo en Prometheus:

```yaml
# prometheus-rules.yaml
groups:
  - name: ai_slos
    interval: 30s
    rules:
      # Latencia p95 < 200ms
      - record: slo:latency_p95:ratio_5m
        expr: |
          histogram_quantile(0.95,
            rate(inference_duration_seconds_bucket[5m])
          ) < 0.2

      # Error rate < 1%
      - record: slo:error_rate:ratio_5m
        expr: |
          sum(rate(inference_errors_total[5m]))
          / sum(rate(inference_requests_total[5m]))

      # Error budget consumido en ventana de 30 días
      - record: slo:error_budget_remaining
        expr: |
          1 - (
            sum(increase(inference_errors_total[30d]))
            / (sum(increase(inference_requests_total[30d])) * 0.01)
          )

      # Alerta: quema rápida de error budget
      - alert: ErrorBudgetBurnFast
        expr: slo:error_budget_remaining < 0.5
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Se consumió >50% del error budget en las últimas horas"
```

## Errores comunes

- **No definir SLOs antes de desplegar.** Sin un umbral acordado, no hay forma de saber si el sistema "funciona bien". Define SLOs con el equipo de producto *antes* del lanzamiento, no después del primer incidente.
- **Monitorear solo infraestructura.** CPU, RAM y uptime no dicen nada sobre la calidad del modelo. Agrega siempre monitoreo de distribuciones de input, confianza de predicción y métricas de negocio.
- **No versionar modelos, datos y código juntos.** Si solo versionas uno de los tres, reproducir un experimento o un incidente se vuelve imposible. Usa MLflow + Git + DVC como mínimo.
- **GPUs ociosas sin autoscaling.** Una GPU A100 a $3/hora cuesta $2,160/mes aunque esté al 5% de utilización. Configura autoscaling basado en profundidad de cola, no en CPU.
- **Costo sin atribución.** Si no sabes cuánto cuesta cada feature o cada cliente, no puedes decidir qué desactivar cuando el presupuesto se agota. Añade tags por tenant y feature desde el día uno.
- **No monitorear data drift ni concept drift.** El modelo "se oxida" naturalmente aunque el código no cambie. Sin detección automática, lo descubres cuando el negocio ya está afectado.
- **Confundir eval offline con eval online.** Un modelo con 92% accuracy en test puede tener 78% con usuarios reales por data drift, training-serving skew o features que en producción llegan con delay.
- **Despliegues sin rollback probado.** Tener un botón de rollback que nunca se ensayó es equivalente a no tenerlo. Haz drills regulares.
- **Ignorar el training-serving skew.** Si las features se calculan con pandas en training y con SQL en serving, los resultados divergen. Usa un feature store (Feast, Tecton) o la misma librería en ambos lados.
- **No tener runbook para incidentes.** A las 3am, nadie recuerda qué hacer. Documenta: a quién llamar, cómo rollback, qué logs revisar, cómo degradar graciosamente.

## Contexto y referencias

- **Google SRE Book** (gratis en sre.google): define las señales doradas, SLIs/SLOs/SLAs y el concepto de error budget. Lectura obligatoria.
- **Databricks MLOps Maturity Model:** marco para evaluar madurez operativa (niveles 0-4).
- **Anthropic & OpenAI SLAs:** publican sus propios SLAs para APIs (típicamente 99.5% uptime mensual). Útil como referencia al diseñar tus propios SLOs.
- **"Hidden Technical Debt in Machine Learning Systems"** (Sculley et al., NeurIPS 2015): paper fundacional que mostró que el código ML es apenas una fracción del sistema real.
- **"Reliable Machine Learning"** (O'Reilly, 2022): aplica principios SRE a sistemas de ML.

## Resumen

- **AIOps** opera sistemas de IA en producción; extiende DevOps y MLOps con monitoreo de calidad de predicción, drift y métricas de negocio.
- Los sistemas de IA **fallan silenciosamente**: pueden parecer sanos en métricas tradicionales mientras degradan su calidad real.
- La relación de inclusión es **DevOps ⊂ MLOps ⊂ AIOps**, con **LLMOps** como caso especial para modelos generativos.
- Las **señales doradas de SRE** (latencia, tráfico, errores, saturación) se extienden en IA con **costo** y **calidad**.
- **MLOps lleva un modelo al despliegue; AIOps lo mantiene útil** semanas, meses y años después.
- La **reproducibilidad total** (modelo + datos + código + config + infra) es prerrequisito para debuggear incidentes.
- El modelo de madurez de Databricks va de nivel 0 (manual) a nivel 4 (auto-adaptable). La mayoría de equipos está en 1-2.
- Los errores más caros son estructurales: no definir SLOs antes de desplegar, no versionar todo, no atribuir costos y no monitorear drift.
- El objetivo no es la perfección, sino construir un sistema donde los problemas se **detecten antes que los usuarios** y donde el **rollback sea seguro, rápido y ensayado**.
