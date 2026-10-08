# Monitoreo de Desempeño del Modelo y Triggers de Reentrenamiento

## ¿Qué es?

El **monitoreo de desempeño del modelo** es la práctica de medir, de forma continua y en producción, qué tan bien un modelo cumple su objetivo real de negocio: precisión, recall, calidad de la respuesta, utilidad para el usuario. Es la contraparte "de calidad" del monitoreo de infraestructura.

La dificultad central es que, en la mayoría de sistemas, **no se conoce la verdad (ground truth) en el momento de la predicción**. Un modelo de fraude predice ahora, pero sabremos si acertó dentro de 2-3 semanas. Un LLM responde ahora, pero sabremos si fue útil cuando el usuario regrese... o no regrese.

El **trigger de reentrenamiento** es la decisión automática o semi-automática de volver a entrenar el modelo cuando se cumplen ciertas condiciones: drift sostenido, caída de métrica proxy, llegada de un volumen suficiente de nuevos datos etiquetados, etc.

## ¿Por qué importa?

- Un modelo sin medición de performance es un modelo que **nadie puede defender**: no se sabe si está mejorando, degradando o estable.
- La **frecuencia óptima de reentrenamiento** depende del dominio: fraude puede necesitar diario, recomendación semanal, clasificación médica trimestral. Reentrenar poco pierde dinero; reentrenar demasiado desperdicia cómputo y arriesga inestabilidad.
- La **calibración** importa tanto como la precisión: un modelo que dice "0.9 de probabilidad" pero acierta el 60% engaña a cualquier sistema downstream que use ese score (p. ej. para priorizar alertas o decidir thresholds).

## ¿Cómo funciona?

### Fuentes de ground truth

| Fuente | Latencia | Costo | Calidad |
|---|---|---|---|
| Feedback explícito del usuario (ratings, correcciones) | Minutos | Bajo | Alta pero sesgada |
| Feedback implícito (clicks, dwell time, retención) | Minutos | Nulo | Media, requiere interpretación |
| Verificación posterior (chargebacks, cancelaciones) | Días a semanas | Nulo | Muy alta |
| Etiquetado humano (annotators) | Horas a días | Alto | Alta pero costosa |
| Reglas de negocio / expert systems | Instantáneo | Bajo | Variable |
| LLM-as-judge | Segundos | Medio | Buena para evaluación continua |

En la práctica se combinan varias: feedback implícito en tiempo real para alertas tempranas, muestreo con etiquetado humano para auditoría, y LLM-as-judge para evaluaciones automáticas de calidad en LLMs.

### Métricas proxy mientras llegan los labels

Cuando el ground truth tarda, hay que apoyarse en **proxies**:

- **Confianza del modelo**: si la distribución de probabilidades predichas se vuelve más plana, el modelo "sabe menos".
- **Distribución de outputs**: si la clase "aprobado" sube del 85% al 95%, hay señal de problema.
- **Tasa de intervención humana**: en loops human-in-the-loop, aumentos en override son proxy de calidad bajando.
- **Comportamiento del usuario**: en LLM chatbots, tasa de "regenerate", longitud de la sesión, abandono.

### Degradation detection

Hay dos regímenes:

1. **Degradación lenta** (semanas o meses): típica de drift gradual. Se detecta comparando métricas móviles en ventanas largas.
2. **Degradación súbita** (horas o días): típica de deploys, cambios upstream del proveedor, bugs en pipelines de features. Se detecta con alertas sobre deltas rápidos.

### Calibración

Un modelo está **bien calibrado** si cuando dice "70% probabilidad", acierta el 70% de las veces. Se mide con:

- **Reliability diagram**: eje x = probabilidad predicha binned, eje y = frecuencia real observada; la diagonal perfecta es `y = x`.
- **Expected Calibration Error (ECE)**: promedio ponderado de la diferencia entre confianza y precisión por bin.
- **Brier score**: error cuadrático medio sobre probabilidades.

Técnicas correctivas: **Platt scaling** (regresión logística sobre scores) y **isotonic regression** (más flexible, requiere más datos).

### Pipeline de reentrenamiento automatizado

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Trigger: PSI > 0.25  OR  accuracy < baseline - 3%        │
│    OR  N nuevos labels disponibles  OR  cron semanal        │
├─────────────────────────────────────────────────────────────┤
│ 2. Snapshot de datos: últimas N semanas, versionado DVC     │
├─────────────────────────────────────────────────────────────┤
│ 3. Entrenamiento + validación cruzada                       │
├─────────────────────────────────────────────────────────────┤
│ 4. Evaluación offline vs. baseline (champion / challenger)  │
├─────────────────────────────────────────────────────────────┤
│ 5. Shadow deploy (predice en paralelo sin servir)           │
├─────────────────────────────────────────────────────────────┤
│ 6. Canary (5% → 25% → 100%) con guardrails                  │
├─────────────────────────────────────────────────────────────┤
│ 7. Promoción o rollback automático                          │
└─────────────────────────────────────────────────────────────┘
```

### LLM-as-judge para evaluación continua

Para LLMs sin ground truth, se usa un modelo más fuerte (o el mismo con prompt distinto) para evaluar en una rúbrica: relevancia, factualidad, tono, completitud. Es rápido y escalable, pero requiere calibración contra evaluaciones humanas para evitar sesgos del juez.

## Ejemplo con código

### Trackeo de performance con Langfuse y LLM-as-judge

```python
from langfuse import Langfuse
import openai, json

lf = Langfuse()

RUBRIC = """Evalúa la respuesta en una escala 1-5 según:
- Relevancia a la pregunta
- Factualidad verificable con el contexto
- Claridad
Devuelve JSON: {"score": int, "reason": str}
"""

def judge(question: str, context: str, answer: str) -> dict:
    resp = openai.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": RUBRIC},
            {"role": "user", "content":
             f"Pregunta: {question}\nContexto: {context}\nRespuesta: {answer}"},
        ],
    )
    return json.loads(resp.choices[0].message.content)

def score_recent_traces(hours: int = 1):
    traces = lf.get_traces(from_timestamp=f"-{hours}h", tags=["prod"])
    for t in traces:
        verdict = judge(t.input["question"], t.metadata["context"], t.output)
        lf.score(
            trace_id=t.id,
            name="llm_judge_quality",
            value=verdict["score"],
            comment=verdict["reason"],
        )
```

### Detección de degradación con ventanas móviles

```python
import pandas as pd
import numpy as np

def check_degradation(scores_df: pd.DataFrame,
                      metric: str = "accuracy",
                      baseline: float = 0.92,
                      long_window: str = "7D",
                      short_window: str = "1D",
                      threshold: float = 0.03) -> dict:
    scores_df = scores_df.set_index("timestamp").sort_index()
    long_ma  = scores_df[metric].rolling(long_window).mean().iloc[-1]
    short_ma = scores_df[metric].rolling(short_window).mean().iloc[-1]

    status = "ok"
    if short_ma < baseline - threshold:
        status = "degraded_absolute"
    elif short_ma < long_ma - threshold:
        status = "degraded_relative"

    return {
        "status": status,
        "short": float(short_ma),
        "long": float(long_ma),
        "baseline": baseline,
    }
```

### Calibración con Platt scaling

```python
from sklearn.linear_model import LogisticRegression
from sklearn.calibration import calibration_curve
import matplotlib.pyplot as plt

# raw_scores: probabilidades crudas del modelo
# y_true:     etiquetas reales (0/1)
calibrator = LogisticRegression()
calibrator.fit(raw_scores.reshape(-1, 1), y_true)
calibrated = calibrator.predict_proba(raw_scores.reshape(-1, 1))[:, 1]

frac_pos, mean_pred = calibration_curve(y_true, calibrated, n_bins=10)
plt.plot(mean_pred, frac_pos, marker="o", label="calibrated")
plt.plot([0, 1], [0, 1], "--", label="perfect")
plt.xlabel("Probabilidad predicha"); plt.ylabel("Frecuencia observada")
plt.legend(); plt.savefig("calibration.png")
```

### Pipeline de reentrenamiento con guardrails

```python
from mlflow import MlflowClient
import mlflow

def promote_if_better(candidate_run_id: str, metric: str = "f1"):
    client = MlflowClient()
    cand = client.get_run(candidate_run_id).data.metrics[metric]

    prod = client.get_latest_versions("fraud-detector", stages=["Production"])[0]
    prod_metric = client.get_run(prod.run_id).data.metrics[metric]

    if cand < prod_metric + 0.005:  # mínimo 0.5 pp de mejora para promover
        print(f"Candidato {cand:.4f} no supera a prod {prod_metric:.4f}; no promover")
        return False

    client.transition_model_version_stage(
        name="fraud-detector",
        version=client.create_model_version(
            "fraud-detector",
            source=f"runs:/{candidate_run_id}/model",
            run_id=candidate_run_id,
        ).version,
        stage="Production",
        archive_existing_versions=True,
    )
    return True
```

## Errores comunes

- **No capturar ground truth sistemáticamente**: sin labels, no hay forma de validar que el modelo funcione.
- **Usar accuracy como única métrica** en datasets desbalanceados: 99% accuracy en fraude puede significar que nunca detectas nada.
- **Reentrenar sin validación offline**: desplegar un modelo nuevo porque "los datos cambiaron" sin verificar que mejora.
- **Ignorar la calibración**: usar scores crudos para thresholds de negocio cuando el modelo está mal calibrado.
- **No comparar con un baseline (champion/challenger)**: no basta con "el nuevo es bueno"; tiene que ser **mejor que el actual** por un margen que supere el ruido.
- **No usar shadow mode o canary**: desplegar 0→100% y descubrir el bug con tráfico real.
- **Confiar ciegamente en LLM-as-judge**: el juez tiene sus propios sesgos (favorece respuestas largas, propio estilo); calibrar contra humanos.
- **Reentrenar demasiado frecuentemente**: añade varianza, dificulta el debugging y encarece operaciones.
- **No versionar datos de entrenamiento**: imposible reproducir el modelo prod cuando algo falla.
- **Mezclar métricas proxy con métricas finales** sin aclarar cuál es cuál: el equipo pierde confianza en los números.

## Resumen

- La **ground truth** es escasa, tardía y costosa; estrategias combinadas (explícito, implícito, humano, LLM-judge) son la norma.
- Mientras llega el label real, las **métricas proxy** (confianza, distribución de outputs, comportamiento del usuario) permiten alertas tempranas.
- Hay dos regímenes de degradación: **lenta** (drift) y **súbita** (deploy, upstream); se detectan con ventanas móviles distintas.
- La **calibración** es tan importante como la precisión; Platt scaling e isotonic regression la corrigen.
- Un **pipeline de reentrenamiento maduro** incluye trigger, snapshot versionado, champion/challenger, shadow, canary y rollback automático.
- **Shadow deployment** y **canary release** son la red de seguridad entre un modelo entrenado y uno sirviendo tráfico completo.
- **LLM-as-judge** escala la evaluación de calidad en sistemas LLM, pero requiere calibración humana periódica para no incorporar sesgos del juez.
- La frecuencia de reentrenamiento es un **hiperparámetro de negocio**: lo determina la velocidad del drift y el costo del fallo, no la moda.
