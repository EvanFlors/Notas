# Métodos Tradicionales de Evaluación

## ¿Qué es?

La **evaluación tradicional** es el conjunto de técnicas que miden la calidad de las salidas de un sistema de IA usando métricas deterministas o estadísticas: comparaciones de texto (BLEU, ROUGE), similitud semántica con embeddings (cosine similarity), métricas de legibilidad (Flesch-Kincaid) y conjuntos de referencia (*golden datasets*). Son el equivalente a los *unit tests* del software clásico aplicados a modelos generativos.

A diferencia de la evaluación humana o del LLM-as-a-Judge (que veremos en lecciones posteriores), estos métodos:

- Producen **números reproducibles** dado el mismo input y la misma referencia.
- Se ejecutan en **milisegundos** y se integran en CI/CD.
- No requieren API calls a modelos caros.
- Pero **miden superficie, no significado profundo** (una respuesta correcta con palabras distintas puede recibir BLEU=0).

> **Regla general:** si tu tarea tiene *una sola respuesta correcta* o un espacio pequeño de respuestas aceptables (traducción, extracción, clasificación), las métricas tradicionales son suficientes. Si el espacio de respuestas correctas es grande (chatbot, generación creativa, resumen abierto), necesitas complementarlas con LLM judges o humanos.

### Taxonomía rápida

| Categoría | Qué mide | Métricas típicas |
|---|---|---|
| Deterministas | Coincidencia exacta de forma | Exact match, regex, string containment |
| Estadísticas de n-gramas | Solapamiento léxico | BLEU, ROUGE-N, METEOR, chrF |
| Semánticas | Similitud de significado | Cosine similarity sobre embeddings, BERTScore |
| Lingüísticas | Legibilidad, sentimiento, toxicidad | Flesch-Kincaid, VADER, Detoxify |
| Agregadas | Combinación ponderada | Weighted scoring, composite indices |

## ¿Por qué importa?

Sin evaluación sistemática, "mejorar el prompt" es superstición. Cambias una palabra, el output te gusta más en 3 ejemplos, y despliegas sin saber si rompiste 300 casos distintos. Las métricas tradicionales dan la **línea base cuantitativa** que convierte el desarrollo de IA en ingeniería:

- **Detección de regresiones:** un cambio en el prompt baja ROUGE-L de 0.52 a 0.41 → algo se rompió, lo ves antes de desplegar.
- **Comparación objetiva de modelos:** GPT-4 vs Claude vs Llama en la misma tarea con el mismo dataset.
- **Costo despreciable:** calcular BLEU sobre 10,000 ejemplos cuesta centavos de CPU, no dólares de inferencia.
- **Base de contratos SLA:** "nuestro sistema mantiene cosine similarity ≥ 0.80 contra el golden set en el 95% de los casos".

### Benchmarks públicos influyentes

| Benchmark | Qué evalúa | Métrica dominante |
|---|---|---|
| **HELM** (Stanford) | Capacidades generales de LLMs en 42 escenarios | Accuracy, calibración, robustez, bias |
| **MT-Bench** | Chatbots multi-turno | LLM-as-judge (GPT-4) + ratings 1-10 |
| **AlpacaEval 2.0** | Seguimiento de instrucciones | Win-rate vs GPT-4 (LLM judge) |
| **LMSYS Chatbot Arena** | Preferencias humanas pareadas | Elo rating con millones de votos |
| **MMLU** | Conocimiento multidisciplinar | Accuracy en opción múltiple |
| **HumanEval** | Generación de código Python | pass@k (ejecuta tests) |

Los primeros tres combinan métricas tradicionales con LLM judges; los dos últimos son puramente deterministas (opción correcta / test que pasa).

## ¿Cómo funciona?

### Golden datasets (conjuntos de referencia)

Un **golden set** es una colección curada de pares `(input, output_ideal)` que define qué significa "bueno" en tu dominio. Es la fuente de verdad contra la que mides todo lo demás.

**Principios de construcción:**

1. **Cobertura:** incluir casos felices, edge cases, inputs adversariales, variantes lingüísticas, longitudes extremas.
2. **Realismo:** sacar ejemplos de **logs reales de producción**, no inventarlos. Un golden set hecho a mano por el equipo tiende a parecerse al equipo, no a los usuarios.
3. **Etiquetado múltiple:** cada ejemplo debería ser revisado por al menos 2 personas; medir *inter-annotator agreement* con **Cohen's kappa**:

```
κ = (p_o − p_e) / (1 − p_e)
```

Donde `p_o` es acuerdo observado y `p_e` acuerdo esperado por azar. Valores de referencia:

| κ | Interpretación |
|---|---|
| < 0.00 | Peor que azar |
| 0.01 – 0.20 | Acuerdo pobre |
| 0.21 – 0.40 | Débil |
| 0.41 – 0.60 | Moderado |
| 0.61 – 0.80 | Sustancial |
| 0.81 – 1.00 | Casi perfecto |

Si tus anotadores humanos sacan κ < 0.6, el problema no es tu modelo: tu *definición* de calidad es ambigua. Vuelve a escribir la rúbrica antes de evaluar nada.

4. **Versionado:** `golden_v1.jsonl`, `golden_v2.jsonl`, con changelog. Nunca sobrescribas en silencio.
5. **Tamaño mínimo:** para detectar diferencias estadísticamente significativas entre dos modelos, apunta a **≥ 300 ejemplos** por categoría crítica. Golden sets de 20 ejemplos son teatro, no ingeniería.

### Evaluaciones deterministas (regex, exact match)

Las más baratas y las más rotas. Útiles cuando el formato de salida es contractual.

```python
import re

def eval_json_valid(output: str) -> bool:
    """¿El modelo devolvió JSON parseable?"""
    import json
    try:
        json.loads(output)
        return True
    except json.JSONDecodeError:
        return False

def eval_contiene_citas(output: str, min_citas: int = 1) -> bool:
    """¿Hay al menos N citas con formato [n]?"""
    return len(re.findall(r"\[\d+\]", output)) >= min_citas

def eval_sin_pii(output: str) -> bool:
    """¿La salida está libre de emails y teléfonos?"""
    email = r"[\w.+-]+@[\w-]+\.[\w.-]+"
    tel = r"\+?\d[\d\s\-()]{7,}\d"
    return not (re.search(email, output) or re.search(tel, output))
```

Ventajas: instantáneas, 100% reproducibles, sin alucinación. Limitaciones: no entienden paráfrasis ni semántica.

### BLEU (Bilingual Evaluation Understudy)

Mide **precisión de n-gramas** del candidato contra una o más referencias, con penalización por brevedad (BP) para evitar inflar scores con outputs truncados:

```
BLEU = BP · exp( Σ wₙ · log(pₙ) )
BP   = 1                 si c > r
BP   = exp(1 − r/c)      si c ≤ r
```

Donde `pₙ` es la precisión de n-gramas, `c` longitud del candidato y `r` longitud de la referencia. Típicamente `n ∈ {1,2,3,4}` con pesos uniformes.

**Cuándo usar:** traducción automática (tarea para la que fue diseñado en 2002), tareas con outputs cortos y vocabulario restringido.

**Cuándo NO usar:** chatbot abierto (paráfrasis legítimas obtienen BLEU bajo), tareas creativas, resúmenes abstractivos.

### ROUGE (Recall-Oriented Understudy for Gisting Evaluation)

Dual de BLEU centrado en **recall**. Variantes:

- **ROUGE-N:** solapamiento de n-gramas.
- **ROUGE-L:** longest common subsequence (LCS), captura orden sin exigir contigüidad.
- **ROUGE-S:** skip-bigrams.

Estándar en evaluación de resúmenes.

### Similitud semántica con embeddings

Convertimos ambos textos en vectores con un modelo pre-entrenado (sentence-transformers, OpenAI `text-embedding-3-small`, Cohere embed) y calculamos **cosine similarity**:

```
cos(u, v) = (u · v) / (‖u‖ · ‖v‖)
```

Rango `[-1, 1]`; para embeddings de texto en la práctica cae en `[0, 1]`. Umbrales típicos:

| Cosine | Interpretación cualitativa |
|---|---|
| > 0.85 | Casi equivalentes |
| 0.70 – 0.85 | Mismo tema, mismo mensaje |
| 0.50 – 0.70 | Mismo tema, mensaje distinto |
| < 0.50 | Temas diferentes |

Captura paráfrasis que BLEU/ROUGE ignoran, pero sigue siendo ciego a **factualidad** (dos textos con cosine 0.92 pueden contradecirse en los hechos).

### Métricas de legibilidad y tono

- **Flesch-Kincaid Grade Level:** nivel educativo necesario para leer el texto.
- **Flesch Reading Ease:** 0 (muy difícil) a 100 (muy fácil).
- **VADER / Detoxify:** sentimiento y toxicidad.

Útiles para auditar que el output *suena* como esperas (tono profesional, nivel escolar apropiado, no tóxico).

### Comparación de enfoques

| Dimensión | Deterministas | Estadísticas (BLEU/ROUGE) | Semánticas (cosine) | LLM-as-judge | Humano |
|---|---|---|---|---|---|
| Costo por eval | ~0 | ~0 | ~$0.0001 | ~$0.01 | ~$1-5 |
| Latencia | ms | ms | ms | segundos | horas-días |
| Reproducibilidad | 100% | 100% | 100% | ~85% | ~70% |
| Entiende paráfrasis | No | No | Sí | Sí | Sí |
| Juzga factualidad | No | No | No | Parcial | Sí |
| Juzga tono/empatía | No | No | Parcial | Sí | Sí |
| Escala a 10M evals | Sí | Sí | Sí | Caro | No |

## Ejemplo con código

### Pipeline multi-métrica con pytest

```python
# tests/test_eval_summarizer.py
import json
import math
import pytest
from collections import Counter
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

ENCODER = SentenceTransformer("all-MiniLM-L6-v2")

with open("data/golden_summaries_v3.jsonl") as f:
    GOLDEN = [json.loads(line) for line in f]


def generar_resumen(texto: str) -> str:
    """Función bajo test: llama a tu modelo real."""
    from mi_app.summarizer import summarize
    return summarize(texto)


def cosine(a: str, b: str) -> float:
    emb = ENCODER.encode([a, b])
    return float(cosine_similarity([emb[0]], [emb[1]])[0][0])


def rouge_l_f1(ref: str, cand: str) -> float:
    r, c = ref.lower().split(), cand.lower().split()
    m, n = len(r), len(c)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            dp[i][j] = dp[i-1][j-1] + 1 if r[i-1] == c[j-1] else max(dp[i-1][j], dp[i][j-1])
    lcs = dp[m][n]
    p = lcs / len(c) if c else 0
    rec = lcs / len(r) if r else 0
    return 2 * p * rec / (p + rec) if (p + rec) else 0.0


@pytest.mark.parametrize("caso", GOLDEN, ids=lambda c: c["id"])
def test_calidad_resumen(caso):
    salida = generar_resumen(caso["input"])
    cos = cosine(caso["output_ideal"], salida)
    rouge = rouge_l_f1(caso["output_ideal"], salida)

    # Umbrales acordados con el producto en un contrato explícito
    assert cos >= 0.75, f"[{caso['id']}] cosine={cos:.2f} < 0.75"
    assert rouge >= 0.30, f"[{caso['id']}] rougeL={rouge:.2f} < 0.30"
    assert 50 <= len(salida.split()) <= 200, "Longitud fuera de rango"
```

Correlo en CI: cada PR que modifique el prompt o el modelo rompe el test si degrada la calidad agregada.

### Agregación por batches y reporting

```python
import statistics
from dataclasses import dataclass

@dataclass
class ResultadoEval:
    caso_id: str
    cosine: float
    rouge_l: float
    tokens_salida: int
    passed: bool

def correr_suite(golden: list[dict]) -> dict:
    resultados = []
    for caso in golden:
        salida = generar_resumen(caso["input"])
        cos = cosine(caso["output_ideal"], salida)
        rouge = rouge_l_f1(caso["output_ideal"], salida)
        r = ResultadoEval(
            caso_id=caso["id"],
            cosine=cos,
            rouge_l=rouge,
            tokens_salida=len(salida.split()),
            passed=(cos >= 0.75 and rouge >= 0.30),
        )
        resultados.append(r)

    return {
        "n": len(resultados),
        "pass_rate": sum(r.passed for r in resultados) / len(resultados),
        "cosine_media": statistics.mean(r.cosine for r in resultados),
        "cosine_p10": statistics.quantiles([r.cosine for r in resultados], n=10)[0],
        "rouge_media": statistics.mean(r.rouge_l for r in resultados),
        "fallos_por_id": [r.caso_id for r in resultados if not r.passed],
    }

reporte = correr_suite(GOLDEN)
print(json.dumps(reporte, indent=2, ensure_ascii=False))
```

Fíjate en el **p10 de cosine**: la media esconde la cola. Un sistema con media 0.82 pero p10 = 0.40 tiene un 10% de casos horribles que la media no revela.

### Config declarativa con Promptfoo

Si prefieres no escribir pytest a mano, [Promptfoo](https://promptfoo.dev) te permite declarar la suite en YAML:

```yaml
# promptfooconfig.yaml
prompts:
  - "Resume en 3 frases: {{texto}}"

providers:
  - openai:gpt-4o-mini
  - anthropic:claude-3-5-haiku-20241022

tests:
  - vars:
      texto: file://data/articulo_01.txt
    assert:
      - type: contains
        value: "conclusion"
      - type: similar
        value: file://data/resumen_ideal_01.txt
        threshold: 0.80
      - type: rouge-n
        value: file://data/resumen_ideal_01.txt
        threshold: 0.3
        n: 2
      - type: javascript
        value: "output.split(' ').length < 60"
```

Ejecutas `promptfoo eval` y obtienes una matriz comparando ambos modelos sobre todos los casos.

## Errores comunes

- **Leakage del golden set en los datos de entrenamiento/fine-tuning.** Si tus ejemplos de evaluación aparecen (incluso parafraseados) en el corpus con el que afinaste el modelo, tus métricas son fantasía. Audita con búsqueda exacta y por embeddings antes de confiar en un número.
- **Usar accuracy en tareas generativas abiertas.** Una pregunta como "resume este artículo" no tiene *una* respuesta correcta. Reportar "accuracy 0.42" es engañoso; usa cosine/ROUGE/LLM judge.
- **Golden sets de 10-30 ejemplos.** El intervalo de confianza es tan ancho que cualquier mejora cae dentro del ruido. Mínimo 100 por sub-categoría, idealmente 300+.
- **Rúbrica vaga.** "Evalúa la calidad del 1 al 5" sin definir niveles produce κ bajo entre anotadores y evaluaciones no reproducibles. Define cada nivel con 2-3 frases de criterio operacional.
- **No versionar evals.** Comparar métricas calculadas con `golden_v1` contra `golden_v3` no significa nada. Cada reporte debe citar la versión exacta del dataset, el prompt, el modelo y los hiperparámetros.
- **Optimizar sólo la media.** Un modelo que mejora la media bajando la mediana (más consistente pero menos picos) puede ser peor en percepción de usuario. Mira distribución completa: p10, mediana, p90.
- **Métrica única.** BLEU alto + cosine bajo + usuarios enojados es un escenario clásico. Siempre combina 2-3 métricas de familias distintas (léxica + semántica + estilo) para triangulación.
- **Confundir evaluación con test unitario del modelo.** Las métricas evalúan el **sistema** (prompt + modelo + post-procesado), no "el modelo". Un cambio de prompt sin cambiar modelo puede mover BLEU 10 puntos.
- **Golden sets sin casos adversariales.** Si todo tu set son inputs limpios y bien formados, no sabrás nada de robustez ante typos, prompt injection, inputs ambiguos o lenguaje tóxico.

## Resumen

- Las **métricas tradicionales** (deterministas, BLEU/ROUGE, cosine similarity, legibilidad) son el piso de la evaluación: baratas, rápidas, reproducibles.
- **BLEU** mide precisión de n-gramas (traducción); **ROUGE** mide recall (resumen); **cosine similarity** sobre embeddings captura paráfrasis.
- Un **golden set** bien construido (cobertura, realismo, etiquetado múltiple con Cohen's κ ≥ 0.6, versionado) es más valioso que la elección de métrica.
- Combina siempre **varias familias** de métricas y reporta **distribución**, no sólo media.
- Las métricas tradicionales **no entienden factualidad, tono ni empatía** → complementar con LLM judges (siguiente lección) o humanos.
- Integra la suite en **pytest / Promptfoo** para que cada PR dispare la evaluación en CI.
- Benchmarks públicos como **HELM, MT-Bench, AlpacaEval, LMSYS Arena** te dan referencia externa, pero **tu golden set privado** es lo que te diferencia.
