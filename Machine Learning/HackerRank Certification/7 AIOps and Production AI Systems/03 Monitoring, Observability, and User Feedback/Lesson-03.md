# Detección de Data Drift y Concept Drift

![Data drift](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson03-data-drift.svg)

## ¿Qué es?

**Drift** es cualquier cambio estadístico en los datos o en la relación entre inputs y outputs que afecta el desempeño de un modelo en producción. Se distinguen dos tipos fundamentales:

- **Data drift (covariate shift)**: la distribución de los **inputs** cambia. Por ejemplo, los usuarios ahora escriben queries más cortas, o aparecen productos nuevos en el catálogo, o el idioma dominante cambia.
- **Concept drift**: la **relación entre inputs y outputs** cambia, aunque los inputs se vean iguales. Por ejemplo, lo que antes era fraude ya no lo es (los defraudadores cambiaron su patrón), o lo que un usuario consideraba "relevante" ahora significa otra cosa.

Hay subcategorías adicionales útiles:

- **Label drift / prior shift**: cambia la frecuencia de las clases (ejemplo: desbalance que se corrige o empeora).
- **Feature drift local**: solo una o pocas features cambian, no toda la distribución.
- **Embedding drift**: en sistemas LLM/RAG, el espacio semántico de los inputs cambia (nuevos temas, nueva jerga).

## ¿Por qué importa?

Los modelos asumen que los datos de producción se parecen a los de entrenamiento. Cuando esa suposición se rompe, la precisión cae, a veces de forma abrupta, a veces lenta y silenciosa durante meses.

Ejemplos reales:

- Modelos de recomendación entrenados antes de la pandemia que colapsaron en marzo 2020.
- Clasificadores de spam que degradan constantemente porque los spammers evolucionan.
- Chatbots RAG cuyo índice vectorial envejece y empieza a devolver documentos irrelevantes.
- Modelos de pricing dinámico ante inflación súbita.

En todos los casos, detectar el drift temprano permite reaccionar (reentrenar, ajustar prompts, actualizar el índice) **antes de que el negocio sienta el impacto**.

## ¿Cómo funciona?

### Pipeline general de detección

1. Guardar una **distribución de referencia** (train o un periodo "sano" de producción).
2. Capturar una ventana reciente de datos de producción (hora/día/semana según volumen).
3. Comparar las dos distribuciones feature por feature con una métrica estadística.
4. Alertar si la métrica supera un umbral.
5. Investigar: ¿es drift benigno (estacionalidad) o maligno (degradación real)?

### Métricas estadísticas clave

#### Population Stability Index (PSI)

Es la métrica estándar en industria para features categóricas o binned. Mide cuánto cambió la distribución de bins entre referencia y actual.

```
PSI = Σ (actual% - expected%) * ln(actual% / expected%)
```

Interpretación convencional:

| PSI | Interpretación |
|---|---|
| < 0.1 | Sin cambio significativo |
| 0.1 – 0.25 | Cambio moderado, investigar |
| > 0.25 | Cambio severo, considerar reentrenamiento |

#### Kolmogorov-Smirnov (KS test)

Para features numéricas continuas, compara las CDFs (funciones de distribución acumulada). Devuelve un estadístico `D` (distancia máxima entre CDFs) y un `p-value`. KS no requiere binning y es muy sensible a cambios en toda la distribución.

#### Chi-squared

Para features categóricas. Compara frecuencias esperadas vs. observadas por categoría; devuelve un `p-value`.

#### Divergencias KL y JS

**KL (Kullback–Leibler)** mide cuántos "bits extra" se necesitan para codificar P usando Q:

```
KL(P || Q) = Σ P(x) log( P(x) / Q(x) )
```

KL es asimétrica y explota si `Q(x) = 0` donde `P(x) > 0`. Por eso en producción se prefiere **JS (Jensen-Shannon)**, que es simétrica y acotada en `[0, 1]`:

```
M = 0.5 * (P + Q)
JS(P, Q) = 0.5 * KL(P || M) + 0.5 * KL(Q || M)
```

#### Embedding drift (específico de LLMs y RAG)

Para texto o imágenes, no existe un espacio de features tabulares. En su lugar, se monitorea la **distribución de embeddings**:

- Calcular el embedding centroide de la referencia.
- Para cada input nuevo, computar `cosine_distance(embedding, centroide)`.
- Rastrear la distribución de esas distancias en el tiempo.

```
cosine_distance(a, b) = 1 - (a · b) / (||a|| * ||b||)
```

Si la media o el p95 de esas distancias se desplaza, el espacio semántico del tráfico cambió. Esto suele traducirse en: usuarios preguntando sobre temas nuevos, idiomas no cubiertos, o jerga reciente.

### Herramientas

- **Evidently.ai** (open source): calcula docenas de métricas de drift y produce reportes HTML interactivos.
- **NannyML**: foco en estimación de performance sin ground truth, drift detection.
- **Arize Phoenix / Arize AI**: visualizaciones de embedding drift específicamente para LLMs.
- **WhyLabs / whylogs**: profiling continuo con bajo overhead.
- **Alibi Detect**: biblioteca de detección de drift y outliers.

### Estrategias de respuesta

Detectar drift no es la meta; **reaccionar bien** sí lo es:

1. **Investigar la causa raíz**: ¿cambio estacional, campaña de marketing, bug upstream, cambio real del mundo?
2. **Reentrenar con datos recientes** si el drift es sostenido y la calidad cayó.
3. **Actualizar el índice vectorial** si el drift es semántico en un sistema RAG.
4. **Ajustar prompts** si el input cambió pero el modelo base es capaz.
5. **Rollback** si el drift coincide con un deploy reciente.
6. **Aceptar y recalibrar umbrales** si es un cambio permanente benigno.

## Ejemplo con código

### PSI desde cero

```python
import numpy as np

def psi(expected: np.ndarray, actual: np.ndarray, bins: int = 10) -> float:
    """PSI entre dos arrays numéricos usando bins basados en los cuantiles de expected."""
    edges = np.quantile(expected, np.linspace(0, 1, bins + 1))
    edges[0], edges[-1] = -np.inf, np.inf

    e_counts, _ = np.histogram(expected, bins=edges)
    a_counts, _ = np.histogram(actual, bins=edges)

    # Evitar ceros (sumar epsilon)
    e_pct = (e_counts + 1e-6) / (e_counts.sum() + 1e-6 * bins)
    a_pct = (a_counts + 1e-6) / (a_counts.sum() + 1e-6 * bins)

    return float(np.sum((a_pct - e_pct) * np.log(a_pct / e_pct)))


# Uso
reference = np.random.normal(50, 10, size=10_000)   # datos de train
current   = np.random.normal(55, 12, size=5_000)    # datos de producción última semana

score = psi(reference, current)
print(f"PSI = {score:.3f}")

if score > 0.25:
    print("ALERTA: drift severo, considerar reentrenamiento")
elif score > 0.1:
    print("WARN: drift moderado, monitorear")
else:
    print("OK: distribución estable")
```

### Monitoreo integral con Evidently.ai

```python
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, DataQualityPreset
import pandas as pd

reference = pd.read_parquet("s3://ml-data/features_train.parquet")
current   = pd.read_parquet("s3://ml-data/features_last_7d.parquet")

report = Report(metrics=[
    DataDriftPreset(stattest="psi", stattest_threshold=0.2),
    DataQualityPreset(),
])
report.run(reference_data=reference, current_data=current)
report.save_html("drift_report.html")

result = report.as_dict()
drift_share = result["metrics"][0]["result"]["dataset_drift"]
if drift_share:
    import requests
    requests.post(
        "https://hooks.slack.com/services/...",
        json={"text": f":rotating_light: Data drift detectado. Ver drift_report.html"},
    )
```

### Embedding drift para un chatbot RAG

```python
import numpy as np
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2")

# Centroide de referencia (precomputado con queries históricos "sanos")
ref_embeddings = model.encode(reference_queries, normalize_embeddings=True)
centroid = ref_embeddings.mean(axis=0)
centroid /= np.linalg.norm(centroid)

def cosine_distance(a, b):
    return 1.0 - float(np.dot(a, b))

def check_batch_drift(new_queries: list[str]) -> dict:
    embs = model.encode(new_queries, normalize_embeddings=True)
    distances = np.array([cosine_distance(e, centroid) for e in embs])
    return {
        "mean":   float(distances.mean()),
        "p95":    float(np.quantile(distances, 0.95)),
        "n_outliers": int((distances > 0.6).sum()),
    }

# Umbrales calibrados con datos históricos
BASELINE_P95 = 0.42
stats = check_batch_drift(latest_queries)
if stats["p95"] > BASELINE_P95 * 1.3:
    alert_team(f"Embedding drift: p95 {stats['p95']:.3f} vs baseline {BASELINE_P95}")
```

### Chi-squared y KS con scipy

```python
from scipy.stats import ks_2samp, chi2_contingency

# KS para feature numérica continua
d_stat, p_value = ks_2samp(reference["price"], current["price"])
print(f"KS: D={d_stat:.3f}, p={p_value:.4g}")

# Chi-squared para feature categórica
import pandas as pd
contingency = pd.crosstab(
    index=pd.concat([reference["country"], current["country"]]),
    columns=["ref"] * len(reference) + ["cur"] * len(current),
)
chi2, p, dof, _ = chi2_contingency(contingency.values)
print(f"Chi2={chi2:.2f}, p={p:.4g}")
```

## Errores comunes

- **Confundir data drift con concept drift**. Los inputs pueden cambiar sin que el modelo pierda precisión; lo opuesto también. Monitorear ambos.
- **Ventana de referencia desactualizada**: comparar producción contra datos de hace 2 años detecta "drift" que ya es la normalidad.
- **Ventana actual demasiado pequeña**: ruido estadístico se confunde con drift real; usar al menos miles de muestras.
- **No corregir por estacionalidad**: cada lunes a las 9 AM el patrón cambia; no es drift, es la realidad del negocio.
- **Alertar en cada feature**: 200 alertas de PSI son 200 ignoradas. Agregar o priorizar por features importantes del modelo.
- **Ignorar drift en features derivadas**: una feature compuesta puede driftar aunque sus componentes individuales no.
- **No tener plan de respuesta**: detectar drift sin saber qué hacer con la alerta la convierte en ruido.
- **No monitorear la distribución de outputs**: a veces la mejor señal de drift es que el modelo empieza a predecir "clase A" el 80% del tiempo cuando antes era 50%.
- **KL con ceros**: explota a infinito; usar JS o aplicar suavizado (Laplace smoothing).
- **Olvidar embedding drift en LLMs**: en RAG, el drift semántico suele ser invisible a métricas tabulares clásicas.

## Resumen

- **Data drift** cambia la distribución de inputs; **concept drift** cambia la relación input→output. Ambos degradan el modelo.
- La detección se basa en comparar una **ventana actual** contra una **referencia** con pruebas estadísticas.
- **PSI** es el estándar de industria para features binned; **KS** para numéricas continuas; **chi-squared** para categóricas; **JS divergence** cuando se quiere algo simétrico y acotado.
- Para LLMs y RAG, el **embedding drift** (distribución de distancias coseno al centroide de referencia) es la señal más informativa.
- Herramientas como **Evidently.ai, Arize Phoenix, NannyML y WhyLabs** aceleran la implementación.
- El drift es síntoma, no diagnóstico: siempre investigar la **causa raíz** antes de reentrenar.
- Toda alerta de drift debe tener una **estrategia de respuesta** predefinida: reentrenar, actualizar índice, ajustar prompt, hacer rollback o aceptar.
- Monitorear también la **distribución de outputs**: muchas veces es el primer indicador de que algo cambió, incluso cuando los inputs parecen estables.
