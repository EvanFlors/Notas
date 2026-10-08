# Evaluación de modelos fine-tuned y catastrophic forgetting

## ¿Qué es?

La **evaluación de un modelo fine-tuned** es el proceso sistemático de medir si el ajuste fino **realmente mejoró** el modelo en la tarea objetivo **sin degradar** las capacidades generales que ya tenía el modelo base. No es un paso opcional: es la única forma de distinguir entre un modelo que funciona y uno que *parece* funcionar en una demo.

Un buen framework de evaluación responde cuatro preguntas:

| Pregunta | Qué mide | Herramienta típica |
|---|---|---|
| ¿Mejoró en la tarea objetivo? | Accuracy, F1, ROUGE, pass@k | Test set propio del dominio |
| ¿Perdió capacidades base? | MMLU, HumanEval, GSM8K pre y post | `lm-evaluation-harness` |
| ¿Produce outputs diversos? | Distinct-n, self-BLEU, entropía | Scripts custom + LLM-as-judge |
| ¿Es seguro y sin sesgos? | TruthfulQA, ToxiGen, BBQ | HELM, Giskard |

**Catastrophic forgetting** (olvido catastrófico) es el fenómeno descrito por McCloskey y Cohen (1989) donde una red neuronal, al aprender una tarea nueva, **sobrescribe** los pesos que codificaban el conocimiento previo. En LLMs modernos se manifiesta como: haces fine-tuning de Llama 3.1 para SQL y, de pronto, el modelo responde peor en francés o resuelve mal problemas de matemáticas que antes acertaba.

> **Definición operacional:** hay catastrophic forgetting si el modelo fine-tuned pierde más del 5-10% de rendimiento en al menos un benchmark de capacidades base (MMLU, HumanEval, GSM8K, MGSM) respecto al modelo base, incluso si mejoró en la tarea objetivo.

### Benchmarks estándar para capacidades base

| Benchmark | Qué mide | Formato | Métrica | Año |
|---|---|---|---|---|
| **MMLU** | Conocimiento general multidisciplinario (57 materias) | 4-way multiple choice | Accuracy | 2020 |
| **HumanEval** | Generación de código Python | 164 problemas con tests | pass@1, pass@10 | 2021 |
| **GSM8K** | Razonamiento matemático escolar | 8.5K problemas verbales | Exact match | 2021 |
| **HellaSwag** | Sentido común / finalizar oración | 4-way multiple choice | Accuracy | 2019 |
| **TruthfulQA** | Resistencia a mentiras populares | Generación + MC | % respuestas verídicas | 2021 |
| **ARC-Challenge** | Razonamiento científico | MC complejo | Accuracy | 2018 |
| **MGSM** | GSM8K traducido a 10 idiomas | Exact match | Accuracy por idioma | 2022 |
| **BBH** (Big-Bench Hard) | 23 tareas difíciles de BIG-bench | Variable | Accuracy promedio | 2022 |
| **HELM** | Suite holística (precisión + robustez + sesgo + eficiencia) | Multi-tarea | Dashboard multidimensional | 2022 |
| **MT-Bench** | Diálogo multi-turno evaluado por GPT-4 | 80 preguntas abiertas | Score 1-10 | 2023 |

### Jerarquía de evaluaciones

```
Evaluación completa de un modelo fine-tuned
├── (1) Métricas de la tarea objetivo         ← ¿mejoró en lo que querías?
│       └── Test set in-domain, held-out
├── (2) Regresión de capacidades base          ← ¿no rompió nada?
│       └── MMLU, HumanEval, GSM8K, TruthfulQA
├── (3) Diversidad y calidad de generación     ← ¿no colapsó el output?
│       └── Distinct-n, self-BLEU, LLM-as-judge
├── (4) Robustez y adversarial                 ← ¿aguanta prompts raros?
│       └── Paraphrase tests, jailbreaks, inyecciones
└── (5) Seguridad, sesgo y toxicidad           ← ¿es responsable publicarlo?
        └── BBQ, ToxiGen, Detoxify, red-teaming
```

## ¿Por qué importa?

Un modelo que no evalúas correctamente es un **pasivo oculto**. Casos reales que han ocurrido en producción:

- Un equipo hace fine-tune para clasificar tickets de soporte y pasa de 72% a 94% de accuracy. Lo despliega. Semanas después descubre que el modelo contesta en inglés incluso cuando el cliente escribe en español: fine-tune en datos exclusivamente en inglés **borró** el bilingüismo.
- Un modelo fine-tuned para generar SQL mejora de 60% a 88% en el benchmark interno. Pero el equipo nunca lo evaluó en MMLU y el modelo perdió 15 puntos en razonamiento general: ya no puede explicar las consultas que genera.
- Un chatbot entrenado con DPO para "ser más útil" aprende que respuestas más **largas** reciben mejor reward. En producción produce párrafos innecesarios y aumenta costos de inferencia 3x sin mejorar la satisfacción del usuario. Esto es **reward hacking**.

### Costo de no evaluar bien

| Falla | Costo de negocio | Prevención |
|---|---|---|
| Catastrophic forgetting | El modelo deja de cubrir casos de uso adyacentes | Eval de regresión en MMLU/HumanEval/GSM8K |
| Mode collapse | Outputs repetitivos, baja diversidad, UX pobre | Distinct-n, self-BLEU, muestreo manual |
| Reward hacking | Métrica de proxy mejora, calidad real baja | Human eval + LLM-as-judge con rúbrica |
| Data contamination | Benchmarks inflados, falso sentido de mejora | Decontamination (n-gram overlap vs. train) |
| Overfitting a estilo | El modelo imita formato pero no razonamiento | Eval en paraphrases y out-of-distribution |

### Contexto regulatorio

- **EU AI Act** (en vigor desde **agosto 2024**, aplicable a modelos de propósito general desde **agosto 2025**): obliga a documentar evaluaciones de modelos de "riesgo sistémico" (>10²⁵ FLOPs de entrenamiento), reportar incidentes y mantener trazabilidad.
- **NIST AI RMF 1.0** (enero 2023): framework voluntario pero adoptado como estándar de facto por el gobierno de EE.UU.; exige las funciones *Govern, Map, Measure, Manage*.
- **Anthropic Responsible Scaling Policy** y las **Preparedness Frameworks** de otros labs: evaluaciones obligatorias de capacidades peligrosas antes de desplegar modelos frontier.
- **Model Cards** (Mitchell et al., 2019): estándar académico, hoy incorporado por HuggingFace, Google, Meta.

## ¿Cómo funciona?

### Metodología de evaluación en 5 fases

```
┌──────────────────────────────────────────────────────────────┐
│  FASE 0: Baseline                                            │
│    Evaluar el modelo base en: tarea objetivo + benchmarks    │
│    base + benchmarks de seguridad. Congelar resultados.      │
├──────────────────────────────────────────────────────────────┤
│  FASE 1: Fine-tune                                           │
│    Entrenar (LoRA/QLoRA/full FT) con logging de val loss.    │
├──────────────────────────────────────────────────────────────┤
│  FASE 2: Eval in-domain                                      │
│    Test set held-out del dominio. Comparar vs. baseline.     │
├──────────────────────────────────────────────────────────────┤
│  FASE 3: Eval de regresión                                   │
│    Re-correr MMLU, HumanEval, GSM8K, HellaSwag, TruthfulQA.  │
│    Alertar si cualquier benchmark cae > 5-10%.               │
├──────────────────────────────────────────────────────────────┤
│  FASE 4: Diversidad + seguridad                              │
│    Distinct-n, self-BLEU, toxicidad, sesgo, red-teaming.     │
├──────────────────────────────────────────────────────────────┤
│  FASE 5: Reporte                                             │
│    Model card + decisión go/no-go documentada.               │
└──────────────────────────────────────────────────────────────┘
```

### Catastrophic forgetting: mecanismo

Durante backpropagation, el gradiente de la pérdida en la tarea nueva empuja a los pesos `θ` hacia una región del espacio que minimiza esa pérdida específica. Si la tarea nueva es muy diferente a la distribución de pre-entrenamiento, esta región **no coincide** con la región donde los pesos codificaban las capacidades previas. En términos de Kirkpatrick et al. (2017, *Elastic Weight Consolidation*):

```
L_total(θ) = L_nueva(θ)  +  λ · Σᵢ Fᵢ · (θᵢ - θ*ᵢ)²
             └ tarea FT ┘   └── ancla a pesos previos ────┘
```

Donde `Fᵢ` es la Fisher Information Matrix diagonal (importancia de cada peso para la tarea previa). Esto se traduce prácticamente en:

- **PEFT (LoRA/QLoRA)** mitiga el forgetting porque el modelo base queda **congelado**; solo se entrenan adaptadores de baja dimensionalidad (<1% de parámetros).
- **Rehearsal / replay**: mezclar 10-20% de ejemplos del pre-entrenamiento (o de un corpus general como The Pile) con la tarea nueva.
- **Lower learning rate**: `1e-5` a `2e-4` en vez de `1e-3`.
- **Fewer epochs**: 1-3 épocas suele bastar; más incrementa el forgetting.
- **Early stopping** basado en benchmarks base, no solo en val loss de la tarea.

### Mode collapse

El modelo converge a producir **un conjunto reducido de respuestas** que maximizan la métrica de entrenamiento. Síntomas:

- Baja **entropía** del output a temperatura fija.
- Alto **self-BLEU** (muchas respuestas parecidas entre sí).
- Bajo **distinct-n** (pocos n-gramas únicos).
- "Me as a language model" repetido en RLHF mal calibrado.

### Reward hacking

En RLHF/DPO/RLAIF, el modelo descubre atajos para maximizar el reward sin resolver la tarea:

- Respuestas más **largas** (si el annotator humano confunde longitud con calidad).
- Uso excesivo de **bullet points** o markdown.
- **Sycophancy**: estar siempre de acuerdo con el usuario (Perez et al., 2022).
- Rechazar preguntas inofensivas para parecer "seguro".

### Data contamination

Si el modelo base ya vio el benchmark durante pre-entrenamiento, el score es inflado. Detección estándar:

- **n-gram overlap**: buscar 13-gramas del test set en el corpus de entrenamiento (Brown et al., GPT-3).
- **Canary strings**: insertar frases únicas en el training y buscarlas en outputs.
- **Timestamp check**: usar benchmarks publicados *después* del cutoff del modelo (ej. LiveBench, SWE-Bench Verified).

### Herramientas estándar

| Herramienta | Mantenedor | Para qué sirve |
|---|---|---|
| **lm-evaluation-harness** | EleutherAI | Suite estándar: >200 tareas (MMLU, HellaSwag, ARC, GSM8K, HumanEval, TruthfulQA) |
| **HELM** | Stanford CRFM | Evaluación holística: accuracy + robustez + sesgo + toxicidad + eficiencia |
| **BIG-bench / BBH** | Google + colaboradores | 200+ tareas creativas y de razonamiento |
| **MT-Bench / Chatbot Arena** | LMSYS | Evaluación por LLM-judge y por humanos (ELO) |
| **Giskard** | Giskard AI | Tests de sesgo, robustez e injection para LLMs |
| **Detoxify** | Unitary | Clasificador de toxicidad (6 categorías) |
| **Weights & Biases** | W&B | Logging de experimentos, comparación de runs |
| **TruLens** | TruEra | Observabilidad y eval en producción |

## Ejemplo con código

### 1. Evaluación con `lm-evaluation-harness`

```python
# pip install lm-eval accelerate
# Evalúa un modelo fine-tuned en los benchmarks estándar y compara con el base
import subprocess
import json
from pathlib import Path

BASE  = "meta-llama/Llama-3.1-8B-Instruct"
FTUN  = "./outputs/llama31-8b-sql-lora"      # adaptador LoRA mergeado
TASKS = "mmlu,hellaswag,arc_challenge,gsm8k,truthfulqa_mc2,humaneval"

def run_harness(model_path: str, out_dir: str) -> dict:
    """Lanza lm-eval y devuelve resultados en formato dict."""
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    cmd = [
        "lm_eval",
        "--model", "hf",
        "--model_args", f"pretrained={model_path},dtype=bfloat16",
        "--tasks", TASKS,
        "--batch_size", "auto",
        "--output_path", out_dir,
    ]
    subprocess.run(cmd, check=True)
    # lm-eval guarda results_*.json
    result_file = next(Path(out_dir).rglob("results_*.json"))
    return json.loads(result_file.read_text())["results"]

base_res = run_harness(BASE, "evals/base")
ft_res   = run_harness(FTUN, "evals/ft")

# Reporte de regresión
print(f"{'Benchmark':<20} {'Base':>8} {'FT':>8} {'Δ':>8}  Status")
print("-" * 60)
THRESHOLD = -0.05  # 5 pp de caída = regresión
for task in ["mmlu", "hellaswag", "arc_challenge", "gsm8k",
             "truthfulqa_mc2", "humaneval"]:
    b = base_res[task].get("acc,none") or base_res[task].get("pass@1,create_test")
    f = ft_res[task].get("acc,none")   or ft_res[task].get("pass@1,create_test")
    delta = f - b
    flag  = "FAIL" if delta < THRESHOLD else "OK"
    print(f"{task:<20} {b:>8.3f} {f:>8.3f} {delta:>+8.3f}  {flag}")
```

### 2. Test de regresión de capacidades (ejemplo multilenguaje)

```python
# Caso: fine-tune en SQL en inglés. ¿Rompimos el francés?
from transformers import pipeline

pipe_base = pipeline("text-generation", model=BASE, device_map="auto")
pipe_ft   = pipeline("text-generation", model=FTUN, device_map="auto")

french_probe = [
    ("Traduis en français: 'The meeting is at 3pm'",
     "La réunion est à 15h"),
    ("Explique en français ce qu'est l'entropie en 2 phrases.", None),
    ("Résous: 23 * 17 = ?",   "391"),
]

def answers_in_french(text: str) -> bool:
    french_markers = {" le ", " la ", " les ", " est ", " une ", " de "}
    return any(m in text.lower() for m in french_markers)

for prompt, expected in french_probe:
    b = pipe_base(prompt, max_new_tokens=80, do_sample=False)[0]["generated_text"]
    f = pipe_ft(prompt,   max_new_tokens=80, do_sample=False)[0]["generated_text"]
    print(f"PROMPT: {prompt}")
    print(f"  BASE french={answers_in_french(b)} | FT french={answers_in_french(f)}")
```

### 3. Detección de mode collapse (diversidad del output)

```python
from collections import Counter
import math

def distinct_n(texts: list[str], n: int = 2) -> float:
    """Fracción de n-gramas únicos sobre el total."""
    all_ngrams, uniq = 0, set()
    for t in texts:
        toks = t.split()
        ngrams = list(zip(*[toks[i:] for i in range(n)]))
        all_ngrams += len(ngrams)
        uniq.update(ngrams)
    return len(uniq) / max(all_ngrams, 1)

def self_bleu(texts: list[str]) -> float:
    """Mide cuánto se parecen las respuestas entre sí. Alto = colapso."""
    from sacrebleu import corpus_bleu
    scores = []
    for i, hyp in enumerate(texts):
        refs = [texts[:i] + texts[i+1:]]
        scores.append(corpus_bleu([hyp], refs).score)
    return sum(scores) / len(scores)

def entropy(texts: list[str]) -> float:
    counts = Counter(w for t in texts for w in t.split())
    total  = sum(counts.values())
    return -sum((c/total) * math.log2(c/total) for c in counts.values())

# Pedimos 50 respuestas distintas a la misma pregunta con temperature=0.9
prompt = "Dame un consejo breve para aprender programación."
samples_base = [pipe_base(prompt, max_new_tokens=40, do_sample=True,
                          temperature=0.9)[0]["generated_text"] for _ in range(50)]
samples_ft   = [pipe_ft(prompt,   max_new_tokens=40, do_sample=True,
                        temperature=0.9)[0]["generated_text"] for _ in range(50)]

for name, s in [("BASE", samples_base), ("FT", samples_ft)]:
    print(f"{name}: distinct-2={distinct_n(s,2):.3f}  "
          f"self-BLEU={self_bleu(s):.1f}  entropy={entropy(s):.2f}")
# Si FT tiene distinct-2 mucho menor y self-BLEU mucho mayor -> mode collapse.
```

### 4. Suite integrada: pre + post con reporte go/no-go

```python
import json
from dataclasses import dataclass, asdict

@dataclass
class EvalReport:
    task_metric: dict         # métricas in-domain
    base_regression: dict     # Δ en benchmarks base
    diversity: dict           # distinct-n, self-BLEU
    safety: dict              # toxicidad, sesgo
    verdict: str              # "SHIP", "BLOCK", "REVIEW"

def decide(report: EvalReport, thresholds: dict) -> str:
    if any(d < thresholds["regression"] for d in report.base_regression.values()):
        return "BLOCK: regresión en capacidades base"
    if report.diversity["distinct_2"] < thresholds["min_distinct"]:
        return "REVIEW: posible mode collapse"
    if report.safety["toxicity_rate"] > thresholds["max_toxicity"]:
        return "BLOCK: toxicidad por encima del umbral"
    if report.task_metric["improvement"] < thresholds["min_improvement"]:
        return "REVIEW: la mejora in-domain no justifica el riesgo"
    return "SHIP"

thresholds = {
    "regression":      -0.05,
    "min_distinct":     0.30,
    "max_toxicity":     0.02,
    "min_improvement":  0.05,
}

report = EvalReport(
    task_metric    = {"accuracy": 0.91, "baseline": 0.74, "improvement": 0.17},
    base_regression= {"mmlu": -0.02, "humaneval": -0.01, "gsm8k": -0.08},
    diversity      = {"distinct_2": 0.42, "self_bleu": 24.1},
    safety         = {"toxicity_rate": 0.004, "bias_gap": 0.03},
    verdict        = "",
)
report.verdict = decide(report, thresholds)
print(json.dumps(asdict(report), indent=2))
```

## Errores comunes

- **No evaluar capacidades base post fine-tuning.** El error más común. Shipping del modelo asumiendo que "si mejoró en lo mío, lo demás seguirá igual". Casi nunca es cierto. Siempre corre al menos MMLU + GSM8K + HumanEval antes y después.
- **Usar benchmarks contaminados.** Si tu training data vino scraped de internet, es muy probable que contenga MMLU o GSM8K. Decontamina con n-gram overlap o usa benchmarks post-cutoff (LiveBench, SWE-Bench Verified, MMLU-Pro).
- **Confundir mejora en val loss con mejora real.** Val loss baja no implica outputs mejores: puede ser overfitting al formato. Evalúa con métricas de tarea, no solo loss.
- **Un solo seed de evaluación.** Benchmarks con muestreo tienen varianza; corre al menos 3 seeds y reporta media ± std.
- **Ignorar diversidad del output.** Un modelo con 95% de accuracy pero que siempre responde lo mismo es inútil en diálogo. Mide distinct-n y self-BLEU.
- **Confiar ciegamente en LLM-as-judge.** GPT-4-judge tiene sesgos (prefiere respuestas largas, su propio estilo, posiciones específicas). Rota jueces, aleatoriza orden, calibra con human eval en una muestra.
- **No separar eval set del dev set.** Si tuneas hiperparámetros contra el mismo set que reportas, estás overfiteando a la métrica.
- **Olvidar la distribución de producción.** Tu test set interno rara vez refleja el tráfico real. Añade *eval en producción* con muestreo + labeling asíncrono.
- **Interpretar diferencias pequeñas como significativas.** 0.5 pp en MMLU es ruido. Usa intervalos de confianza (bootstrap) o tests de significancia.
- **No versionar el benchmark.** MMLU v1 vs v2, HumanEval+ vs HumanEval original dan números distintos. Fija versión en el reporte.

## Resumen

- Evaluar un modelo fine-tuned requiere **cinco frentes**: tarea objetivo, regresión en capacidades base, diversidad, seguridad y reporte.
- Los **benchmarks estándar** (MMLU, HumanEval, GSM8K, HellaSwag, TruthfulQA) son el mínimo para detectar regresiones; `lm-evaluation-harness` los corre todos.
- **Catastrophic forgetting** aparece cuando el fine-tune empuja los pesos lejos de las regiones que codificaban capacidades previas. Se mitiga con **PEFT**, learning rates bajos, pocas épocas y mezcla de ejemplos generales (10-20%).
- **Mode collapse** se detecta con distinct-n, self-BLEU y entropía del output. **Reward hacking** se detecta cuando una métrica proxy mejora pero la calidad humana no.
- **Data contamination** infla scores: valida con n-gram overlap o usa benchmarks post-cutoff del modelo.
- La **decisión de desplegar** (go/no-go) debe basarse en umbrales explícitos de regresión, no en intuición ni en la métrica que te gusta más.
- La **EU AI Act** (en vigor desde agosto 2024) y **NIST AI RMF** elevan la evaluación de "buena práctica" a **requisito regulatorio** para modelos de propósito general.
- Un modelo que no se evalúa correctamente es un pasivo oculto: tarde o temprano te pasa factura en producción.
