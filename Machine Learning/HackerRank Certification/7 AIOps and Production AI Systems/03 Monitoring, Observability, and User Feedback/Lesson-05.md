# Recolección de Feedback del Usuario y A/B Testing

## ¿Qué es?

El **feedback del usuario** es la señal más directa (y a menudo la única real) sobre si un modelo está sirviendo bien a sus usuarios. Se divide en dos grandes categorías:

- **Explícito**: el usuario le dice al sistema qué le pareció la salida. Ejemplos: thumbs up/down, estrellas, corrección manual, reporte de error, encuesta.
- **Implícito**: el sistema infiere la calidad del comportamiento. Ejemplos: click, tiempo en página, aceptación de sugerencia, regenerate, abandono.

El **A/B testing** (o split testing) es la metodología estándar para decidir si un cambio (nuevo modelo, nuevo prompt, nueva política de retrieval) es realmente mejor que el actual, midiendo el efecto en métricas de negocio sobre dos grupos aleatorios de usuarios.

## ¿Por qué importa?

- Las métricas offline (accuracy, BLEU, score del juez) **no siempre correlacionan con utilidad real**. Un modelo con mejor accuracy puede empeorar la experiencia.
- Decisiones basadas en intuición o en demos escogidas producen regresiones silenciosas; A/B testing con significancia estadística es la defensa.
- El feedback del usuario alimenta el **flywheel de datos**: labels gratis para el próximo entrenamiento, señales para RLHF/DPO, insumos para evals.
- Sin feedback, los equipos operan a ciegas y confían en anécdotas: "me pareció que anoche respondía peor".

## ¿Cómo funciona?

### Diseño de feedback explícito

| Patrón | Tasa de respuesta típica | Mejor para |
|---|---|---|
| Thumbs up/down en cada respuesta | 1-5% | Señal binaria rápida, agregable |
| Rating 1-5 estrellas | 0.5-2% | Granularidad, correlación con NPS |
| Comentario libre (opcional) | 0.1-0.5% | Diagnóstico cualitativo |
| Corrección inline ("edit response") | 2-10% en coding | Preference data para fine-tuning |
| Reporte explícito ("flag") | 0.01-0.1% | Casos extremos, moderación |

Reglas prácticas:

- **Fricción mínima**: dos clics máximo. Nada de modales que bloquean.
- **Pedir contexto solo si el usuario quiere**: un botón "¿quieres contarnos más?" después del thumbs down.
- **No preguntar siempre**: muestreo (p. ej., preguntar solo al 10% de los usuarios por sesión) evita fatiga.

### Feedback implícito en LLMs

Señales valiosas que no requieren acción explícita:

- **Regenerate rate**: cuántas veces el usuario pide "intenta de nuevo".
- **Edit rate**: cuántas veces copia-pega-edita la respuesta.
- **Follow-up questions**: una pregunta aclaratoria sugiere que la respuesta no fue completa.
- **Session length**: sesiones muy cortas pueden indicar frustración o éxito inmediato (ambiguo).
- **Copy rate**: en productos de código, cuánto se copia la salida.
- **Retention**: ¿el usuario vuelve mañana?

Las señales implícitas son más abundantes pero más ruidosas; requieren más análisis.

### A/B testing: fundamentos

1. **Hipótesis**: "El nuevo prompt aumentará el CTR en al menos 2 pp".
2. **Métrica primaria**: una sola, inequívoca (CTR, conversión, satisfacción).
3. **Métricas guardrail**: no pueden empeorar (latencia, costo, tasa de errores, retención).
4. **Aleatorización estable** por `user_id` (no por sesión) para evitar que el mismo usuario rebote entre variantes.
5. **Tamaño de muestra calculado a priori** según effect size, baseline, poder estadístico (típico 80%) y nivel de significancia (típico 0.05).
6. **Duración**: cubrir al menos un ciclo semanal para capturar estacionalidad.

### Significancia estadística

Para métricas binarias (CTR, conversión) se usa habitualmente un **two-proportion z-test** o un **chi-squared**. Para continuas, un **Welch's t-test**.

Fórmula del z-test para dos proporciones:

```
p̂ = (x_A + x_B) / (n_A + n_B)
SE = sqrt( p̂ (1-p̂) (1/n_A + 1/n_B) )
z  = (p_A - p_B) / SE
```

Un `p-value < 0.05` sugiere que la diferencia observada es improbable bajo H0 (no hay diferencia). Pero **p-value no es magnitud**: una diferencia significativa de 0.1 pp puede ser irrelevante en el negocio.

### Significancia estadística vs. significancia práctica

Con tamaños de muestra enormes, cualquier diferencia es estadísticamente significativa. La pregunta real es: **¿la mejora compensa el costo del cambio?** Ejemplo: un nuevo modelo mejora el CTR 0.5 pp con p=0.03 pero cuesta 3x más por request → probablemente no vale la pena.

### Guardrail metrics

Son métricas que no deben empeorar aunque la métrica primaria mejore. Típicas en LLMs:

- Latencia p95
- Costo por request
- Tasa de respuestas moderadas / rechazadas
- Tasa de errores
- Retención semanal

Si alguna guardrail cae significativamente, el experimento se para incluso si la métrica primaria sube.

### Peligros clásicos

- **Peeking**: mirar el p-value cada día y detener en cuanto cruza 0.05 infla el falso positivo. Usar **sequential testing** (SPRT, mSPRT, always-valid p-values) o fijar la duración de antemano.
- **Novelty effect**: lo nuevo gusta solo por ser nuevo. Correr experimentos lo suficientemente largos.
- **Interacciones entre experimentos**: dos tests simultáneos en el mismo flow pueden contaminarse.
- **Simpson's paradox**: la métrica global sube pero cae en cada segmento.

## Ejemplo con código

### Captura de feedback thumbs y asociación con la trace

```python
from fastapi import FastAPI
from pydantic import BaseModel
from langfuse import Langfuse

app = FastAPI()
lf = Langfuse()

class Feedback(BaseModel):
    trace_id: str
    thumbs: int        # +1 / -1
    comment: str | None = None

@app.post("/feedback")
def submit_feedback(fb: Feedback):
    lf.score(
        trace_id=fb.trace_id,
        name="user_thumbs",
        value=fb.thumbs,
        comment=fb.comment,
    )
    return {"ok": True}
```

### Test de significancia para A/B binario con scipy

```python
import numpy as np
from scipy.stats import norm

def two_proportion_z_test(x_a: int, n_a: int, x_b: int, n_b: int):
    p_a, p_b = x_a / n_a, x_b / n_b
    p_pool = (x_a + x_b) / (n_a + n_b)
    se = np.sqrt(p_pool * (1 - p_pool) * (1 / n_a + 1 / n_b))
    z = (p_b - p_a) / se
    p_value = 2 * (1 - norm.cdf(abs(z)))

    # Intervalo de confianza 95% para la diferencia
    se_diff = np.sqrt(p_a * (1 - p_a) / n_a + p_b * (1 - p_b) / n_b)
    diff = p_b - p_a
    ci = (diff - 1.96 * se_diff, diff + 1.96 * se_diff)

    return {
        "ctr_A": p_a, "ctr_B": p_b,
        "lift_abs": diff, "lift_rel": diff / p_a,
        "z": z, "p_value": p_value, "ci95": ci,
    }

# Caso del quiz: 10k usuarios por variante, 5.0% vs 5.5%
r = two_proportion_z_test(x_a=500, n_a=10_000, x_b=550, n_b=10_000)
print(r)
# ctr_A=0.050, ctr_B=0.055, lift_abs=0.005, p_value≈0.03
```

### Cálculo de tamaño de muestra

```python
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

baseline = 0.05
mde = 0.005  # minimum detectable effect: 0.5 pp
effect = proportion_effectsize(baseline + mde, baseline)
n = NormalIndPower().solve_power(
    effect_size=effect, alpha=0.05, power=0.8, alternative="two-sided"
)
print(f"Necesitas {int(n):,} usuarios por variante")
# Aproximadamente 31k por variante para detectar 0.5pp con 80% de poder
```

### Asignación estable por `user_id` (hashing)

```python
import hashlib

def assign_variant(user_id: str, experiment: str, split: float = 0.5) -> str:
    key = f"{experiment}:{user_id}".encode()
    bucket = int(hashlib.sha256(key).hexdigest(), 16) % 10_000 / 10_000
    return "B" if bucket < split else "A"
```

### Guardrail check automático

```python
def check_guardrails(metrics_A: dict, metrics_B: dict) -> list[str]:
    violations = []
    for name, max_delta in {
        "latency_p95_ms": 50,       # no empeorar más de 50 ms
        "cost_per_req":   0.001,    # no más de +0.1 ¢
        "error_rate":     0.005,    # no más de +0.5 pp
    }.items():
        if metrics_B[name] - metrics_A[name] > max_delta:
            violations.append(f"{name}: +{metrics_B[name] - metrics_A[name]:.4f}")
    return violations
```

## Errores comunes

- **Pedir feedback a todos, siempre**: fatiga al usuario y baja la tasa de respuesta. Usar muestreo inteligente.
- **No asociar el feedback a la trace exacta**: imposible investigar por qué el usuario dio thumbs down.
- **Confundir p-value con magnitud del efecto**: significancia estadística no implica relevancia práctica.
- **Peeking al experimento**: mirar y parar en cuanto cruza p=0.05 convierte 5% de falso positivo en 30%.
- **Olvidar las métricas guardrail**: optimizar CTR mientras la latencia se dobla.
- **Aleatorización por sesión en lugar de por usuario**: el mismo usuario ve ambas variantes y contamina el experimento.
- **Experimento demasiado corto**: no se captura estacionalidad semanal; viernes y lunes se comportan distinto.
- **Novelty effect confundido con mejora real**: correr al menos 2 semanas para que el efecto novedad decaiga.
- **No corregir por múltiples comparaciones**: analizar 20 métricas secundarias casi garantiza encontrar una "significativa" por azar.
- **Interpretar feedback explícito como representativo**: quien se queja no es la mayoría; sesgo de autoselección.

## Resumen

- El feedback **explícito** (thumbs, ratings) es claro pero escaso; el **implícito** (regenerate, edit, retention) es abundante pero ruidoso. Usar ambos.
- Diseñar feedback con **fricción mínima** y **muestreo** para evitar fatiga; capturar siempre el `trace_id` para investigación.
- El **A/B testing** es la forma rigurosa de medir impacto; requiere hipótesis, métrica primaria, guardrails y tamaño de muestra calculado.
- **Aleatorizar por `user_id`** (no por sesión) y correr el experimento al menos un ciclo semanal.
- **Significancia estadística** no es lo mismo que **relevancia práctica**: una mejora de 0.5 pp puede o no justificar el costo.
- Las **métricas guardrail** (latencia, costo, errores, retención) deben vigilarse en todo experimento.
- Peeking, novelty effect, interacciones entre experimentos y Simpson's paradox son trampas conocidas; evitarlas con metodología y herramientas.
- El feedback alimenta el **flywheel de datos**: insumos para evals, labels para reentrenar, preferences para DPO/RLHF.
