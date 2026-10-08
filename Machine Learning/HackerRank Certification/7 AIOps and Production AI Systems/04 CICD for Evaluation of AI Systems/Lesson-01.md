# CI/CD tradicional vs CI/CD para sistemas de AI

## ¿Qué es?

**CI/CD** (Continuous Integration / Continuous Deployment) es la práctica de automatizar el build, test y despliegue de software. En aplicaciones tradicionales el ciclo es relativamente simple: un commit dispara un pipeline que compila, corre tests unitarios y de integración, y si todo pasa publica el artefacto (binario, container, lambda) a producción.

En **AI CI/CD** el pipeline debe lidiar con un universo mucho más amplio de artefactos: no solo código, sino también **modelos** (pesos binarios de GB), **datos** (datasets de entrenamiento y evaluación), **prompts** (versionados como código) y **configuraciones** (hiperparámetros, temperatura, system prompts). Cada tipo de artefacto tiene su propio ciclo de vida, su propia prueba y su propia estrategia de rollback.

La diferencia central es que el comportamiento de un sistema de AI es **probabilístico**: dos builds idénticos del mismo prompt sobre el mismo modelo pueden producir salidas distintas. Por eso los tests dejan de ser asserts binarios (`assert output == "foo"`) y pasan a ser **evaluaciones estadísticas** sobre un *golden dataset*, con umbrales de aceptación (accuracy, F1, pass-rate del juez, etc.).

> **Definición operativa:** AI CI/CD = CI/CD + evaluación automática de calidad del modelo/prompt + versionado de datos + gates estadísticos antes de merge y antes de promoción a producción.

### Comparación directa

| Aspecto | CI/CD tradicional | AI CI/CD |
|---|---|---|
| Artefacto principal | Binario / container | Código + modelo + dataset + prompts |
| Tests | Determinísticos (unit, integration) | Probabilísticos (eval sobre golden set) |
| Tiempo de build | Minutos | Minutos (código) + horas o días (entrenamiento) |
| Criterio de éxito | Tests pasan (verde/rojo) | Umbral estadístico (accuracy > X, drop < Y%) |
| Dependencias | Librerías + config | Librerías + config + data + model + embeddings |
| Rollback | Deploy versión previa | Rollback de código, modelo, prompt o los tres |
| Trigger | Commit, tag, PR | Commit, PR, nueva data, drift detectado, schedule |
| Gates | Tests + lint + review humano | Lo anterior + eval gates + significance tests + aprobación |

## ¿Por qué importa?

Un bug tradicional se manifiesta como *crash* o excepción: fácil de detectar. En AI, una **regresión silenciosa** puede pasar inadvertida durante semanas: el modelo nuevo responde con la misma estructura y latencia, pero su calidad bajó 7% en un subdominio crítico (por ejemplo, consultas en español rioplatense o preguntas de dominio médico). Sin un pipeline que evalúe cada cambio contra un *golden dataset* versionado, esas regresiones llegan a producción.

Las razones por las que un equipo de AI serio invierte en CI/CD de evaluación:

- **Prompts son código.** Un cambio en el system prompt puede mejorar un caso de uso y romper otros tres. Sin eval automática no te enteras.
- **Modelos cambian solos.** Si tu proveedor (OpenAI, Anthropic, Google) hace *silent updates* de `gpt-4o` o `claude-sonnet-4`, tu comportamiento cambia sin que tú hayas tocado nada. Necesitas tests que corran de forma periódica.
- **El costo del fallo es asimétrico.** Un chatbot que empieza a alucinar política de refunds puede costarle a la empresa dinero real y confianza. Un gate que bloquea el merge es barato comparado con un incidente.
- **Velocidad con seguridad.** Equipos con buen CI/CD de eval mergean prompts 5-10 veces al día. Sin pipeline, cada cambio requiere revisión manual: cuellos de botella y errores humanos.
- **Comparar modelos objetivamente.** ¿`claude-sonnet-4.5` es mejor que `gpt-4o` para tu caso de uso? Sin un pipeline de eval reproducible la respuesta es anecdótica.

### Contexto de industria

Herramientas que empujaron esta disciplina en los últimos años:

- **Promptfoo** — framework open-source que corre evaluaciones declarativas (YAML) sobre múltiples modelos/prompts y produce diff visual.
- **Braintrust** — SaaS con enfoque en evaluación continua, trazas y comparación side-by-side.
- **Humanloop** — plataforma para iterar prompts con evals y revisores humanos.
- **LangSmith** — del equipo de LangChain, integra tracing + eval + dataset management.
- **DeepEval** — eval framework estilo `pytest` para LLMs (métricas: hallucination, faithfulness, G-Eval).
- **Anthropic internal eval infra** — descripta en los *model cards*: miles de evals automáticas corren antes de cada release de modelo.

## ¿Cómo funciona?

Un pipeline de AI CI/CD maduro tiene varios componentes integrados.

### 1. Múltiples tipos de artefactos

Cada uno con su propio ciclo:

| Artefacto | Versionado en | Trigger de rebuild | Tamaño típico |
|---|---|---|---|
| Código (serving, orchestration) | Git | Commit | KB - MB |
| Prompts | Git (YAML/Jinja) | Commit | KB |
| Modelo fine-tuned | Model registry (MLflow, W&B) | Nueva data, schedule | GB - TB |
| Datos de entrenamiento | DVC, LakeFS, Delta Lake | Pipeline ETL | GB - TB |
| Golden eval dataset | Git LFS o DVC | Curaduría manual | MB |
| Configuración (temp, top-p) | Git (YAML) | Commit | Bytes |
| Embeddings (RAG) | Vector DB con snapshot | Reindex | GB |
| Container de serving | Container registry (ECR, GCR) | Build | GB |

### 2. Pipelines separados pero integrados

```
┌─────────────────────┐     ┌──────────────────────┐
│ Code pipeline       │     │ Training pipeline    │
│  trigger: commit    │     │  trigger: schedule   │
│  - lint             │     │  - data validation   │
│  - unit tests       │     │  - preprocess        │
│  - eval gates       │     │  - train             │
│  - build container  │     │  - eval              │
└──────────┬──────────┘     │  - register model    │
           │                └──────────┬───────────┘
           │                           │
           ▼                           ▼
      ┌─────────────────────────────────────┐
      │ Deployment pipeline                 │
      │  trigger: model promote OR tag      │
      │  - deploy staging                   │
      │  - integration + eval tests         │
      │  - shadow in prod (opcional)        │
      │  - canary (1% → 10% → 100%)         │
      │  - monitor + auto-rollback          │
      └─────────────────────────────────────┘
```

### 3. Golden datasets versionados

Un **golden dataset** es un conjunto curado de ejemplos `(input, expected_output_or_rubric)` que representa el "contrato" de tu sistema. Debe:

- Vivir en control de versiones (Git LFS o DVC) con hash reproducible.
- Cubrir casos **happy path**, **edge cases**, **adversarial**, **compliance** y **regresiones históricas** (cada bug reportado se convierte en un caso del golden set).
- Nunca estar presente en el training set (**data contamination** = eval inservible).
- Crecer con el producto: toda vez que un usuario reporte un fallo, el ejemplo se agrega al golden set.

### 4. Eval como test suite

En AI CI/CD la métrica no es "pasa / falla" sino **"se mantiene o mejora respecto al baseline"**. Tipos de tests:

| Tipo | Qué prueba | Herramienta típica | Frecuencia |
|---|---|---|---|
| Unit test de prompt | Prompt individual sobre un caso | pytest + DeepEval | Cada commit |
| Integration test RAG | Pipeline retrieve + generate | Promptfoo | Cada PR |
| Eval benchmark | Modelo completo sobre golden set | Promptfoo, Braintrust | Cada PR |
| Regression suite | Casos históricos que ya rompieron | pytest + fixtures | Cada PR |
| LLM-as-judge | Juez evalúa output abierto | DeepEval G-Eval | Cada PR |
| A/B eval | Comparar dos variantes | Promptfoo compare | Antes de merge |
| Shadow eval | Modelo nuevo recibe tráfico real sin servir | Custom | Pre-promoción |
| Canary | Nuevo sirve a X% de usuarios | Service mesh + flags | Promoción |

### 5. Frameworks de eval CI-friendly

| Framework | Lenguaje | Fortaleza | Salida |
|---|---|---|---|
| **Promptfoo** | YAML + JS/Python | Config declarativa, compara N modelos/prompts, matriz visual | HTML + JSON + exit code |
| **DeepEval** | Python | Estilo pytest, métricas built-in (hallucination, faithfulness) | pytest report |
| **Braintrust** | Python/TS | SaaS con UI de comparación, trazas | Dashboard web |
| **LangSmith** | Python/TS | Integrado con LangChain, datasets + eval | Dashboard web |
| **Humanloop** | Python/TS | Eval + human review en el mismo loop | Dashboard web |
| **Ragas** | Python | Específico para RAG (context precision, recall) | pytest report |

### 6. Gates automáticos antes de merge

Un **eval gate** es un check de GitHub/GitLab que bloquea el merge si la métrica cae por debajo de un umbral. Patrón típico:

```
if nueva_accuracy < baseline_accuracy - 0.05:
    exit 1   # falla el PR
```

Para evitar que **ruido estadístico** se interprete como regresión, el gate debe aplicar un **test de significancia** (bootstrap, t-test, McNemar) antes de bloquear.

### 7. Patrón de promoción: PR → staging → shadow → canary → rollout

```
PR → eval gates automáticos (golden set subset, rápido)
  ↓ merge
main → full eval suite nightly
  ↓
staging → integration tests + eval completo
  ↓
shadow en prod → mismo tráfico, no sirve respuestas, se mide delta
  ↓
canary 1% → 10% → 50% → 100%, con auto-rollback por métricas
```

### 8. Significancia estadística

Comparar dos modelos sobre N ejemplos y declarar "el nuevo es mejor" porque sacó 83% vs 81% es irresponsable si N es chico. Herramientas:

- **Bootstrap resampling:** remuestrea el golden set B veces (B = 1000-10000), calcula el intervalo de confianza del delta.
- **Paired t-test:** cuando cada ejemplo recibe un score numérico de ambos modelos.
- **McNemar's test:** para outputs binarios (correcto/incorrecto) con muestras pareadas.

Fórmulas clave:

```
# Error estándar del delta (dos proporciones)
SE = sqrt( p₁(1-p₁)/n + p₂(1-p₂)/n )

# IC 95% del delta
delta ± 1.96 · SE

# McNemar (b = nuevo correcto / viejo incorrecto, c = al revés)
χ² = (b - c)² / (b + c)
```

Regla de dedo: si tu golden set tiene menos de **500 ejemplos**, cualquier mejora menor al 3-4% probablemente sea ruido.

## Ejemplo con código

Pipeline mínimo pero realista: GitHub Actions que corre `promptfoo` en cada PR y bloquea el merge si cae la accuracy.

```yaml
# .github/workflows/llm-eval.yml
name: LLM Evaluation

on:
  pull_request:
    paths:
      - "prompts/**"
      - "src/llm/**"
      - "evals/**"

jobs:
  eval:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true   # golden datasets en Git LFS

      - uses: actions/setup-node@v4
        with: { node-version: "20" }

      - name: Instalar promptfoo
        run: npm install -g promptfoo@latest

      - name: Cache de embeddings y resultados
        uses: actions/cache@v4
        with:
          path: ~/.promptfoo
          key: promptfoo-${{ hashFiles('evals/golden.jsonl') }}

      - name: Correr eval
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: promptfoo eval -c evals/promptfoo.yaml --output results.json

      - name: Comparar contra baseline en main
        run: python scripts/compare_vs_baseline.py results.json

      - name: Publicar comentario en el PR
        if: always()
        run: promptfoo share --output results.json | tee -a $GITHUB_STEP_SUMMARY
```

Config declarativa de `promptfoo`:

```yaml
# evals/promptfoo.yaml
prompts:
  - file://prompts/support_agent.v2.txt

providers:
  - anthropic:messages:claude-sonnet-4-5
  - openai:chat:gpt-4o

tests: file://evals/golden.jsonl

defaultTest:
  assert:
    - type: llm-rubric
      value: "La respuesta es correcta, cordial y no inventa políticas de reembolso."
    - type: latency
      threshold: 3000   # ms
    - type: cost
      threshold: 0.01   # USD por request
```

Script de comparación con **significancia estadística**:

```python
# scripts/compare_vs_baseline.py
import json
import sys
import math
import numpy as np

THRESHOLD_DROP = 0.05   # bloquea si cae > 5 puntos
N_BOOTSTRAP = 5000

def load_scores(path: str) -> list[float]:
    with open(path) as f:
        data = json.load(f)
    return [1.0 if r["success"] else 0.0 for r in data["results"]]

def bootstrap_ci(deltas: list[float], alpha: float = 0.05) -> tuple[float, float]:
    """IC del delta por bootstrap pareado."""
    rng = np.random.default_rng(42)
    boots = [rng.choice(deltas, size=len(deltas), replace=True).mean()
             for _ in range(N_BOOTSTRAP)]
    lo, hi = np.quantile(boots, [alpha / 2, 1 - alpha / 2])
    return float(lo), float(hi)

nuevo = load_scores("results.json")
viejo = load_scores("baseline.json")

if len(nuevo) != len(viejo):
    sys.exit("Golden set cambió de tamaño; recomputa baseline.")

acc_nuevo = sum(nuevo) / len(nuevo)
acc_viejo = sum(viejo) / len(viejo)
delta = acc_nuevo - acc_viejo
deltas_pareados = [n - v for n, v in zip(nuevo, viejo)]
lo, hi = bootstrap_ci(deltas_pareados)

print(f"Baseline: {acc_viejo:.3f}")
print(f"Nuevo:    {acc_nuevo:.3f}")
print(f"Delta:    {delta:+.3f}  (IC95%: [{lo:+.3f}, {hi:+.3f}])")

# Gate: bloquear solo si el IC95% excluye el umbral de caída tolerable
if hi < -THRESHOLD_DROP:
    sys.exit(f"REGRESION: delta < -{THRESHOLD_DROP} con significancia estadistica.")

if lo > 0:
    print("Mejora estadisticamente significativa.")
else:
    print("Sin cambio significativo (dentro del ruido).")
```

Test unitario de un prompt con `pytest` + DeepEval:

```python
# tests/test_support_prompt.py
import pytest
from deepeval import assert_test
from deepeval.test_case import LLMTestCase
from deepeval.metrics import HallucinationMetric, AnswerRelevancyMetric
from src.llm import ask

CASES = [
    ("¿Cuánto cuesta el plan Pro?", "USD 20/mes", ["pricing_v3.md"]),
    ("¿Reembolsan si cancelo?", "7 dias para pedir reembolso", ["policy.md"]),
]

@pytest.mark.parametrize("question, expected_substring, context", CASES)
def test_support_agent(question, expected_substring, context):
    actual = ask(question, context=context)
    tc = LLMTestCase(
        input=question,
        actual_output=actual,
        expected_output=expected_substring,
        context=context,
    )
    assert_test(tc, [
        HallucinationMetric(threshold=0.3),
        AnswerRelevancyMetric(threshold=0.7),
    ])
```

Ejecutar en paralelo con `pytest-xdist`:

```bash
pytest tests/ -n auto --dist loadfile
```

## Errores comunes

- **Dataset de evaluación contaminado con training data.** Si el modelo vio el golden set durante fine-tuning, los números de eval son fantasiosos. Mantén un *holdout* estricto, con hash de cada ejemplo, y audita que no aparezca en los pipelines de training.
- **No aplicar test de significancia.** Reportar "el nuevo modelo es 2% mejor" sobre 200 ejemplos sin IC es engañar al equipo. Casi siempre eso cae dentro del ruido. Usa bootstrap o McNemar.
- **Evaluación demasiado lenta que bloquea PRs.** Si cada eval tarda 30 min, los devs la saltarán ("push a main y arreglo luego"). Divide: *fast suite* (< 3 min) en PR + *full suite* nightly.
- **No cachear embeddings ni resultados LLM.** Correr la misma eval 20 veces al día contra `gpt-4o` sin cache quema USD de más. Cachea por hash de `(prompt, model, input)`.
- **Gate opcional que los humanos saltan.** Si el check se puede ignorar sin aprobación, se ignora. Protege la rama (branch protection rules) y requiere eval verde para merge.
- **No versionar el golden dataset.** Cambiar el dataset sin bump de versión invalida comparaciones históricas. Usa `golden-v1.3.jsonl` + hash.
- **Confundir eval offline con calidad real.** El golden set es una proxy. Debes complementar con *shadow eval* en tráfico real y feedback de usuarios.
- **Un solo juez LLM-as-judge.** Un juez único (`claude` juzga a `claude`) sesga el resultado. Usa un juez distinto al evaluado y/o un ensemble.
- **No distinguir drift de dataset vs regresión del modelo.** Si la métrica cae pero el modelo no cambió, puede ser que el golden set envejeció. Agenda revisiones trimestrales.
- **Reentrenar el modelo en cada commit de código.** 6 horas y USD 50 por commit. Separa el training pipeline (schedule + data change) del code pipeline (commit).
- **Ignorar costos y latencia en los gates.** Un prompt más preciso pero 4x más caro o 3x más lento es regresión. Incluye `cost` y `latency` como assertions.
- **No tener plan de rollback de prompts.** Rollback de código es un `git revert`; rollback de prompt requiere pensar qué versión del prompt estaba live y restaurarla. Guarda el prompt en el model registry junto con el modelo.

## Resumen

- CI/CD para AI extiende el pipeline tradicional con **múltiples artefactos** (código, modelo, data, prompts) y **tests probabilísticos** sobre golden datasets.
- Separar **code pipeline** (minutos, cada commit) de **training pipeline** (horas, por schedule o nueva data) es la regla de oro.
- El **golden dataset versionado** es el contrato de calidad; debe estar fuera del training set y crecer con cada incidente.
- Los **eval gates** bloquean el merge cuando la métrica cae por debajo de un umbral *con significancia estadística* (bootstrap, McNemar).
- Patrón de promoción: **PR → staging → shadow → canary → rollout**, con auto-rollback si las métricas en vivo degradan.
- Herramientas CI-friendly: **Promptfoo**, **DeepEval**, **Braintrust**, **Humanloop**, **LangSmith**, orquestadas con **GitHub Actions** o **GitLab CI** y paralelismo con **pytest-xdist**.
- Errores clásicos: contaminación de datos, no aplicar significancia, pipelines lentos que bloquean, no cachear, gates opcionales, reentrenar en cada commit.
- Un buen pipeline permite mergear prompts 5-10 veces al día **con confianza**, no "con los dedos cruzados".
