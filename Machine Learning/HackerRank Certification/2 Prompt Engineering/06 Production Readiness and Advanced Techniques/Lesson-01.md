# A/B Testing y Validación Estadística de Prompts

## ¿Qué es?

**A/B testing de prompts** es la práctica de comparar dos (o más) variantes de un prompt midiendo su desempeño en producción con usuarios reales (o tráfico sintético controlado), para decidir con rigor estadístico cuál variante es *demostrablemente* mejor.

A diferencia de la evaluación offline (benchmarks fijos, "vibes" sobre 20 ejemplos), un A/B test se corre contra:

- **Tráfico vivo**, muestreado aleatoriamente.
- **Métricas de negocio** (satisfacción, resolución, conversión), no solo métricas proxy.
- **Un marco estadístico** que distingue señal de ruido: hipótesis nula, p-value, tamaño del efecto, intervalos de confianza.

En términos formales, dado un prompt control `A` con métrica media `μ_A` y una variante `B` con media `μ_B`, se contrasta:

```
H₀: μ_A = μ_B   (no hay diferencia real)
H₁: μ_A ≠ μ_B   (hay diferencia real)
```

y se rechaza `H₀` solo si la probabilidad de observar la diferencia bajo `H₀` (el **p-value**) es menor que un umbral `α` prefijado (típicamente 0.05).

### Vocabulario mínimo

| Término | Qué significa | Valor típico |
|---|---|---|
| `α` (significancia) | Prob. de falso positivo tolerada | 0.05 |
| `β` | Prob. de falso negativo | 0.20 |
| Poder estadístico | `1 - β`: prob. de detectar un efecto real | 0.80 |
| MDE (minimum detectable effect) | Efecto mínimo que vale la pena detectar | 2-5% relativo |
| Tamaño del efecto (Cohen's d) | Magnitud estandarizada: `(μ_B - μ_A)/σ` | 0.2 pequeño, 0.5 medio, 0.8 grande |
| Intervalo de confianza 95% | Rango que contiene `μ_B - μ_A` con 95% de prob. | — |

## ¿Por qué importa?

Un prompt que "se siente mejor" en pruebas manuales puede empeorar la métrica real por razones que no viste: cambios de distribución, usuarios distintos a los de tu dataset, interacciones con otros componentes. Sin A/B testing, prompt engineering se convierte en superstición: cambios se aprueban porque alguien con autoridad los prefirió, no porque muevan la aguja.

Las razones concretas para invertir en infra de A/B testing:

- **Varianza enorme en salidas de LLMs.** Con `temperature > 0`, el mismo prompt genera outputs distintos. Dos muestras pequeñas pueden sugerir diferencias que no existen.
- **Métricas multidimensionales.** Un prompt más empático puede aumentar satisfacción, aumentar latencia *y* subir costo por tokens. Hay que medir las tres.
- **Regresiones silenciosas.** Un cambio "obvio y bueno" (añadir una regla de seguridad) puede romper 3% de casos previamente correctos. Sin medición, no te enteras.
- **Riesgo de reputación.** Un prompt que alucina más en producción daña usuarios y marca antes de que lo notes.
- **Costo.** Un prompt 15% más largo multiplica el gasto en tokens por millones de requests. El A/B debe incluir costo como métrica.

### Significancia estadística vs. significancia práctica

Este es el error #1 en equipos sin cultura experimental:

> Un p-value de 0.03 confirma que la diferencia **existe**, no que **importa**.

Reducir latencia de 2.40s a 2.39s puede ser estadísticamente significativo con un millón de muestras y ser **completamente irrelevante** para el usuario. Antes de correr un test, define el **MDE** (mínimo efecto detectable que justifica el costo de implementar) y descarta resultados por debajo de él aunque sean "significativos".

## ¿Cómo funciona?

### 1. Formular una hipótesis específica

Mal: *"queremos mejorar las respuestas"*.

Bien: *"Añadir una frase de empatía al inicio aumentará CSAT ≥ 0.3 puntos (en escala 1-10) sin aumentar latencia P95 más de 100 ms ni subir el costo por request más de 5%"*.

La hipótesis amarra:

- Qué cambia (el *tratamiento*).
- Qué métrica primaria mueve y en qué dirección.
- Qué métricas *guardarraíl* no deben empeorar.
- Qué magnitud mínima importa.

### 2. Elegir métricas con jerarquía

| Nivel | Ejemplo | Rol |
|---|---|---|
| Primaria (OEC) | CSAT, resolución al primer contacto | La que decide ganar/perder |
| Secundarias | Longitud, tono, cobertura | Ayudan a entender el "por qué" |
| Guardarraíl | Latencia P95, tasa de violaciones de política, costo/request | No deben empeorar |
| Diagnóstico | Distribución de temas, tasa de tool-calls | Explican comportamiento interno |

### 3. Determinar el tamaño de muestra (power analysis)

Para una comparación de medias con `α = 0.05` y poder `0.8`, el tamaño por brazo aproximado es:

```
n ≈ 16 · σ² / Δ²
```

donde `σ` es la desviación estándar de la métrica y `Δ` el MDE absoluto. Ejemplo numérico: `σ = 1.5`, `Δ = 0.3` ⇒ `n ≈ 400` por brazo. Para `Δ = 0.1` saltas a `n ≈ 3600`. Si tu tráfico diario es 500 requests, un test con MDE pequeño tarda semanas.

### 4. Asignación aleatoria consistente

- **Hash estable del user_id** → mismo usuario siempre ve la misma variante (evita contaminación por repetidas visitas).
- **Estratificación** por segmento (nuevos vs. recurrentes, idioma, canal) cuando se sabe que hay heterogeneidad.
- **Nunca** randomización por request si el usuario tiene una conversación multi-turno; romperás la experiencia.

### 5. Analizar con herramientas correctas

| Métrica | Test apropiado |
|---|---|
| Continuas, aprox. normales (CSAT) | Welch t-test |
| Continuas sesgadas (latencia) | Mann-Whitney U, o log-transform + t-test |
| Binarias (resolvió sí/no) | z-test de proporciones, Chi-cuadrado |
| Múltiples métricas | Corrección Bonferroni / FDR (Benjamini-Hochberg) |
| Decisión secuencial / peek diario | mSPRT, Group Sequential, o Bayesian A/B |

### 6. Monitoreo continuo

- Dashboards en tiempo real con intervalos de confianza, no solo medias.
- **Guardrails automáticos** que paran el test si la variante B dispara errores, violaciones de seguridad o churn por encima de un umbral.
- Rollout gradual: 1% → 10% → 50% → 100%.

## Ejemplo con código

### Framework mínimo con asignación estable, t-test y corrección por múltiples métricas

```python
import hashlib
import random
import numpy as np
from scipy import stats
from statsmodels.stats.multitest import multipletests
from dataclasses import dataclass, field
from collections import defaultdict


@dataclass
class ABExperiment:
    name: str
    variants: dict[str, str]           # nombre -> prompt
    primary_metric: str
    guardrail_metrics: list[str] = field(default_factory=list)
    mde: float = 0.3                   # mínimo efecto detectable
    alpha: float = 0.05
    results: dict = field(default_factory=lambda: defaultdict(list))

    def assign(self, user_id: str) -> str:
        """Asignación determinista: mismo user_id → misma variante."""
        h = int(hashlib.sha256(user_id.encode()).hexdigest(), 16)
        names = list(self.variants.keys())
        return names[h % len(names)]

    def log(self, variant: str, **metrics):
        self.results[variant].append(metrics)

    def summary(self, metric: str):
        groups = {v: [r[metric] for r in logs] for v, logs in self.results.items()}
        base = next(iter(groups))
        out = {base: {"n": len(groups[base]), "mean": np.mean(groups[base])}}
        pvals, labels = [], []
        for v, data in groups.items():
            if v == base:
                continue
            t, p = stats.ttest_ind(groups[base], data, equal_var=False)
            diff = np.mean(data) - np.mean(groups[base])
            # Intervalo de confianza 95% para la diferencia
            se = np.sqrt(np.var(groups[base], ddof=1)/len(groups[base]) +
                         np.var(data, ddof=1)/len(data))
            ci = (diff - 1.96*se, diff + 1.96*se)
            cohens_d = diff / np.sqrt((np.var(groups[base]) + np.var(data)) / 2)
            out[v] = {"n": len(data), "mean": np.mean(data),
                      "diff": diff, "ci95": ci,
                      "p_raw": p, "cohens_d": cohens_d}
            pvals.append(p); labels.append(v)
        # Corrección por múltiples pruebas (Benjamini-Hochberg)
        if pvals:
            _, p_adj, _, _ = multipletests(pvals, alpha=self.alpha, method="fdr_bh")
            for v, pa in zip(labels, p_adj):
                out[v]["p_adjusted"] = pa
                out[v]["significant"] = pa < self.alpha
                out[v]["practically_significant"] = abs(out[v]["diff"]) >= self.mde
        return out


# ------------------------------------------------------------
# Simulación: control vs. variante con empatía
# ------------------------------------------------------------
exp = ABExperiment(
    name="empathy_v1",
    variants={
        "control":   "Please help the user with their request.",
        "treatment": "I understand this can be frustrating. Let me help you find a solution.",
    },
    primary_metric="csat",
    guardrail_metrics=["latency_ms", "tokens_out"],
    mde=0.3,
)

rng = np.random.default_rng(0)
for uid in range(4000):
    variant = exp.assign(f"user_{uid}")
    boost = 0.4 if variant == "treatment" else 0
    csat = np.clip(rng.normal(7.0 + boost, 1.5), 1, 10)
    latency = rng.normal(820 + (40 if variant == "treatment" else 0), 90)
    tokens = rng.normal(180 + (30 if variant == "treatment" else 0), 25)
    exp.log(variant, csat=csat, latency_ms=latency, tokens_out=tokens)

for m in ("csat", "latency_ms", "tokens_out"):
    print(f"\n== {m} ==")
    for v, s in exp.summary(m).items():
        print(v, s)
```

### Guardrails automáticos para detener un test

```python
def should_stop(exp: ABExperiment) -> tuple[bool, str]:
    s = exp.summary("csat")
    for v, data in s.items():
        if "p_adjusted" not in data:
            continue
        # 1) Caída severa en métrica primaria: detener de inmediato
        if data["diff"] < -0.5 and data["p_adjusted"] < 0.01:
            return True, f"{v} degrada CSAT en {data['diff']:.2f}"
    # 2) Guardarraíl de latencia: no permitir >15% peor
    lat = exp.summary("latency_ms")
    for v, data in lat.items():
        if "diff" in data and data["diff"] / lat["control"]["mean"] > 0.15:
            return True, f"{v} aumenta latencia >15%"
    return False, ""
```

### Testing offline con Promptfoo (regresión antes del A/B online)

```yaml
# promptfooconfig.yaml
prompts:
  - id: control
    raw: "Please help the user with their request. Query: {{query}}"
  - id: treatment
    raw: "I understand this can be frustrating. Let me help. Query: {{query}}"

providers:
  - openai:gpt-4o-mini

tests:
  - vars: { query: "Mi pedido no llegó" }
    assert:
      - type: contains-any
        value: ["lamento", "siento", "comprendo"]
      - type: latency
        threshold: 2000
      - type: cost
        threshold: 0.001
      - type: llm-rubric
        value: "El tono es empático y propone un siguiente paso concreto"
```

```bash
promptfoo eval -c promptfooconfig.yaml --output report.html
```

## Errores comunes

### Confundir significancia estadística con práctica

Un p-value < 0.05 con `Δ = 0.1s` en latencia o `+0.05` en CSAT es *ruido útil* para publicar un paper, no para implementar en producción. Define siempre tu MDE antes de ver los números.

### Peeking y detención temprana no planificada

Mirar el p-value cada hora y detener al primer `< 0.05` **infla la tasa de falsos positivos** desde 5% hasta >30% en pocos días. Soluciones:

- Fijar duración mínima y no mirar hasta cerrarla.
- Usar métodos secuenciales válidos: **mSPRT, always-valid p-values, Group Sequential Testing con alpha spending** (O'Brien-Fleming, Pocock).
- Alternativamente, enfoque Bayesiano con *expected loss*.

### Multiple comparisons sin corrección

Evaluar 20 métricas con `α = 0.05` genera ~1 falso positivo esperado por puro azar. Celebrar "3 métricas movieron" sin corregir es engañarte. Usa Bonferroni (`α/m`) para control estricto o Benjamini-Hochberg (FDR) para más poder.

### Confounding temporal

Lanzar el test justo al liberar una feature nueva, un lunes festivo o durante un pico de tráfico mezcla señales. Mitigaciones:

- Correr control y tratamiento **concurrentemente**, nunca secuencialmente ("semana 1 vs. semana 2").
- Estratificar análisis por día de la semana / segmento.
- Repetir el experimento (replicación es la mejor validación).

### SRM (Sample Ratio Mismatch)

Si tu asignación es 50/50 pero recibes 55/45, algo rompió la aleatorización (bug de routing, cache sesgado). Un chi-cuadrado trivial lo detecta y debe **invalidar el test**, no "ajustarse post hoc".

### Métricas desalineadas con negocio

Optimizar "longitud de respuesta" porque es fácil de medir, cuando el negocio importa resolución al primer contacto, lleva a prompts que escriben ensayos inútiles (Goodhart's Law). Valida regularmente las métricas proxy contra outcomes reales.

### Tamaño de muestra decidido "por intuición"

"Vamos a correr una semana" sin power analysis típicamente deja tests underpowered (poder < 50%). Resultados "no significativos" se interpretan como "no hay diferencia" cuando en realidad **no había poder para detectarla**. Reporta siempre poder observado y MDE.

### No incluir costo como métrica

Un prompt que gana en CSAT por 0.2 puntos pero duplica tokens de salida puede ser pérdida neta. En producción, `$/request` y `tokens/request` son métricas de primera clase, no notas al pie.

### Ignorar heterogeneidad del efecto (HTE)

Promedios ocultan subgrupos. Un prompt puede subir CSAT global pero bajarlo brutalmente para usuarios en japonés. Analiza por segmento clave (idioma, canal, segmento de cliente) antes de rollout global.

## Resumen

- A/B testing convierte prompt engineering de arte a ciencia: hipótesis, aleatorización, medición rigurosa.
- La **significancia estadística** solo dice "la diferencia existe"; la **significancia práctica** dice "importa lo suficiente para implementar".
- Antes de correr: define hipótesis, MDE, métricas primaria/guardarraíl y calcula tamaño de muestra con power analysis.
- Usa **asignación determinista por hash de user_id** y **estratificación** cuando corresponda.
- **No hagas peek**: usa duración fija o métodos secuenciales válidos (mSPRT, GST).
- Corrige por múltiples pruebas (Bonferroni, Benjamini-Hochberg).
- Incluye **costo y latencia** como métricas de primera clase, no solo calidad.
- Automatiza guardrails que **detengan el test** ante regresiones severas.
- Combina **testing offline** (Promptfoo, deepeval) para regresiones antes del tráfico vivo con A/B online para la decisión final.
- Reporta intervalos de confianza y tamaños de efecto (Cohen's d), no solo p-values.
