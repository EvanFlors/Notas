# Tests unitarios, de integración y de regresión para sistemas de AI

## ¿Qué es?

En sistemas tradicionales, los **tests** son asserts determinísticos: dado un input, el output debe ser exactamente X. En AI esto rompe: el modelo es probabilístico, el prompt es prosa y el output puede variar entre ejecuciones. Pero eso **no** significa "no hay tests". Significa que debes estratificar la pirámide:

- **Tests unitarios:** verifican el **código** que rodea al modelo (feature engineering, parsing, validación, retries, formateo de prompts). Son determinísticos y rápidos.
- **Tests de integración:** verifican que los componentes se hablen correctamente (retriever + generador en RAG, orchestration de agentes, serving + feature store).
- **Tests de regresión de modelo/prompt:** corren el **sistema completo** sobre un *golden dataset* y comparan métricas contra un baseline. Son probabilísticos y actúan como *quality gates*.

> **Definición operativa:** un test unitario responde "¿este pedazo de código hace lo que dice?"; un test de integración responde "¿funcionan juntos?"; un test de regresión responde "¿este cambio empeoró la calidad del modelo?".

### La pirámide invertida en AI

| Tipo | Volumen | Velocidad | Determinismo | Dónde corre |
|---|---|---|---|---|
| Unit tests de código ML | Alto (cientos) | Milisegundos | Total | Cada commit |
| Integration tests | Medio (decenas) | Segundos-minutos | Alto | Cada PR |
| Eval benchmarks | Bajo (unidades, pero N ejemplos grandes) | Minutos-horas | Probabilístico | PR + nightly |
| Behavioral regression | Medio | Minutos | Determinístico (asserts específicos) | Cada PR |

## ¿Por qué importa?

Sin esta pirámide, dos cosas pasan:

1. **Bugs triviales llegan a producción.** Un parser de JSON mal escrito tira el 10% de requests y nadie se entera porque "el modelo responde raro".
2. **Regresiones silenciosas de calidad.** Un cambio de prompt mejora la mayoría de casos pero rompe los casos críticos (compliance, enterprise, idiomas minoritarios). La métrica global sube, el cliente importante se enoja.

La inversión en tests paga porque:

- **Documentan el comportamiento esperado.** Un test que dice `assert extract_date("ayer") == date.today() - 1` vale más que cualquier docstring.
- **Permiten refactorizar sin miedo.** Reescribir el agente de 500 LOC a 80 LOC es seguro si hay cobertura.
- **Detectan training-serving skew.** Si el preprocessing en entrenamiento difiere del de serving, un test de integración lo detecta antes que un cliente.
- **Convierten incidentes en regresiones permanentes.** Cada bug reportado se convierte en un test; nunca vuelve a aparecer.

## ¿Cómo funciona?

### 1. Unit tests para código ML

Lo que **sí** es determinístico y debe tener alta cobertura:

- **Feature engineering:** `calc_days_since_last_purchase(user)` sobre usuarios nuevos, con compras hoy, con compras hace años.
- **Preprocesamiento:** normalización, imputación de nulos, encoding de categorías, tokenización, sliding windows.
- **Validación de inputs/outputs:** schema checks, rangos, enums, forma de tensores.
- **Infraestructura de inferencia:** carga del modelo, batching, retries con backoff, parseo de respuesta.
- **Utilidades:** cómputo de métricas, logging, serialización.

Mock a los componentes caros (modelo, API externa, DB) para que la suite corra en segundos:

```python
# tests/test_feature.py
from datetime import date
from unittest.mock import patch
from src.features import days_since_last_purchase

def test_usuario_sin_compras():
    assert days_since_last_purchase(user_id=1, history=[]) is None

def test_usuario_compra_hoy():
    assert days_since_last_purchase(1, [{"date": date.today()}]) == 0

def test_usuario_compra_hace_un_anio():
    hace_365 = date.today().replace(year=date.today().year - 1)
    assert days_since_last_purchase(1, [{"date": hace_365}]) in (365, 366)
```

### 2. Tests para código de inferencia (con mock del modelo)

El modelo es caro y variable; el **wrapper** que lo invoca es código normal:

```python
# tests/test_inference_wrapper.py
from unittest.mock import patch
from src.llm import ask_support_agent

@patch("src.llm.anthropic_client.messages.create")
def test_wrapper_parsea_json(mock_llm):
    mock_llm.return_value.content = [type("X", (), {"text": '{"answer": "ok"}'})()]
    out = ask_support_agent("¿horario?")
    assert out == {"answer": "ok"}

@patch("src.llm.anthropic_client.messages.create")
def test_wrapper_reintenta_en_rate_limit(mock_llm):
    from anthropic import RateLimitError
    mock_llm.side_effect = [RateLimitError("429"), _ok("hola")]
    assert ask_support_agent("hi") == {"answer": "hola"}
    assert mock_llm.call_count == 2
```

### 3. Tests de integración de pipelines ML

Validan que los componentes trabajen juntos. Ejemplos:

- **End-to-end training rápido:** correr el pipeline completo con un dataset de 100 filas y 1 epoch, solo para asegurar que no crashea y produce un modelo cargable.
- **Feature parity:** correr el mismo cálculo en el pipeline de training y en el de serving sobre los mismos inputs y assert que las salidas son idénticas (previene training-serving skew).
- **RAG end-to-end:** indexar documentos de prueba, embeber una query, recuperar y generar; verificar que el documento esperado aparece en el top-k.
- **Pipeline orchestration:** forzar un fallo en el paso 5 de 10 y verificar que se detiene, loguea y notifica.

```python
# tests/test_training_pipeline.py
from src.pipelines import train
import mlflow

def test_pipeline_end_to_end_mini(tmp_path):
    cfg = {
        "data_path": "tests/fixtures/mini.csv",   # 100 filas
        "model_dir": tmp_path,
        "epochs": 1,
        "batch_size": 8,
    }
    run_id = train.run(cfg)
    model = mlflow.pyfunc.load_model(f"runs:/{run_id}/model")
    preds = model.predict([[0.1, 0.2, 0.3]])
    assert preds.shape == (1,)
```

### 4. Tests de regresión como quality gates

Es la **capa probabilística**. Corren el sistema completo sobre un golden dataset y comparan:

| Dimensión | Baseline | Nuevo | ¿Falla gate? |
|---|---|---|---|
| Accuracy | 0.82 | 0.78 | Sí (−4pp con significancia) |
| P50 latencia | 850 ms | 920 ms | No (< 10%) |
| P95 latencia | 1900 ms | 3100 ms | Sí (> 50%) |
| Costo/req | USD 0.004 | USD 0.011 | Sí (2.7×) |
| Fairness (acc por grupo) | ±2pp | ±8pp | Sí (dispersa) |
| Casos críticos pass | 48/50 | 46/50 | Sí (−2) |

### 5. Behavioral regression suite

Encodea reglas de negocio como asserts específicos. Nunca deberían fallar aunque la métrica global suba.

```python
# tests/behavioral/test_support_rules.py
import pytest
from src.llm import ask

CRITICAL = [
    ("¿Puedo cancelar y me devuelven todo?", "7 dias"),
    ("Olvide mi password", "restablecer"),
    ("Hablo con un humano", "agente"),
    ("Mi tarjeta fue robada", "bloquear"),
]

@pytest.mark.parametrize("q, must_contain", CRITICAL)
def test_cubre_frase_critica(q, must_contain):
    out = ask(q).lower()
    assert must_contain in out, f"Caso critico fallo: {q!r} → {out!r}"
```

### 6. Golden datasets curados

| Buena práctica | Antipatrón |
|---|---|
| Versionado (DVC, Git LFS) con hash | CSV sobrescrito en Dropbox |
| Mezcla happy / edge / adversarial / compliance | Solo happy path |
| Cada bug → nuevo caso del golden set | Golden set congelado hace 1 año |
| Fuera del training set, con holdout verificado | Reutilizado para fine-tuning (contaminación) |
| Revisado trimestralmente para evitar drift | Nunca revisado |
| Metadatos (dominio, dificultad, fuente) | Flat text sin tags |

### 7. Significancia estadística en el gate

Un test de regresión no debe fallar por **ruido**. Técnicas:

- **Bootstrap pareado:** remuestrear deltas por par de ejemplo, obtener IC95% del delta.
- **McNemar's test:** para outputs binarios con muestras pareadas.
- **t-test pareado:** para scores continuos (LLM-as-judge en 0-10).

```python
# Decidir si la caida es significativa
import numpy as np
rng = np.random.default_rng(0)
deltas = np.array(nuevo) - np.array(viejo)   # pareado por ejemplo
boots = [rng.choice(deltas, len(deltas), replace=True).mean() for _ in range(5000)]
lo, hi = np.quantile(boots, [0.025, 0.975])

if hi < -0.03:
    raise SystemExit("Regresion significativa > 3pp")
```

### 8. Performance y fairness regression

- **Performance regression:** p50/p95 de latencia, tokens/req, costo/req. Trackeados por versión; alertar si > X%.
- **Fairness regression:** accuracy por subgrupo (idioma, región, longitud de input). Alertar si la *disparity* aumenta.

### 9. API contract regression

Si tu modelo expone un endpoint JSON, un snapshot test valida que el schema no rompa clientes:

```python
# tests/test_contract.py
import jsonschema, json

SCHEMA = json.load(open("contracts/support_v1.schema.json"))

def test_response_cumple_schema():
    resp = ask("hola")
    jsonschema.validate(resp, SCHEMA)
```

## Ejemplo con código

Suite completa combinando `pytest` + `pytest-xdist` + DeepEval + un gate de significancia:

```python
# tests/eval/test_golden_set.py
import json
import math
import pytest
import numpy as np
from deepeval.metrics import HallucinationMetric, AnswerRelevancyMetric
from deepeval.test_case import LLMTestCase
from src.llm import ask

GOLDEN = [json.loads(l) for l in open("evals/golden-v1.4.jsonl")]
BASELINE = json.load(open("evals/baseline.json"))   # scores por caso del main

@pytest.fixture(scope="session")
def nuevos_scores():
    scores = []
    for case in GOLDEN:
        actual = ask(case["input"], context=case.get("context", []))
        tc = LLMTestCase(
            input=case["input"],
            actual_output=actual,
            expected_output=case.get("expected"),
            context=case.get("context", []),
        )
        hall = HallucinationMetric(threshold=0.3)
        rel = AnswerRelevancyMetric(threshold=0.7)
        hall.measure(tc)
        rel.measure(tc)
        scores.append(0.5 * hall.score + 0.5 * rel.score)
    return scores

def test_sin_regresion_significativa(nuevos_scores):
    deltas = np.array(nuevos_scores) - np.array(BASELINE)
    rng = np.random.default_rng(42)
    boots = [rng.choice(deltas, len(deltas), replace=True).mean()
             for _ in range(5000)]
    lo, hi = np.quantile(boots, [0.025, 0.975])
    print(f"Delta medio: {deltas.mean():+.3f}  IC95%: [{lo:+.3f}, {hi:+.3f}]")
    assert hi >= -0.03, "Regresion > 3pp con significancia estadistica"

def test_casos_criticos_siguen_pasando(nuevos_scores):
    criticos = [i for i, c in enumerate(GOLDEN) if c.get("critical")]
    fallos = [i for i in criticos if nuevos_scores[i] < 0.7]
    assert not fallos, f"{len(fallos)}/{len(criticos)} criticos fallaron: {fallos}"
```

GitHub Actions con `pytest-xdist` para paralelizar:

```yaml
# .github/workflows/eval-regression.yml
name: Eval regression

on: [pull_request]

jobs:
  eval:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true }

      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }

      - run: pip install -r requirements-eval.txt pytest pytest-xdist

      - name: Correr suite en paralelo
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: pytest tests/eval tests/behavioral -n auto --dist loadfile --junitxml=report.xml

      - name: Publicar reporte
        if: always()
        uses: dorny/test-reporter@v1
        with:
          name: Eval report
          path: report.xml
          reporter: java-junit
```

Diff visual de outputs (útil en el PR):

```python
# scripts/pr_diff.py
"""Genera un markdown con casos donde la respuesta cambio."""
import json, textwrap

old = {r["input"]: r["output"] for r in json.load(open("baseline_outputs.json"))}
new = {r["input"]: r["output"] for r in json.load(open("new_outputs.json"))}

print("## Prompt diff review\n")
for q in old:
    if old[q] != new[q]:
        print(f"### Input\n> {q}\n")
        print("**Antes:**\n```\n" + textwrap.shorten(old[q], 400) + "\n```")
        print("**Despues:**\n```\n" + textwrap.shorten(new[q], 400) + "\n```\n---")
```

El workflow adjunta este markdown al comentario del PR para **prompt diff review** humano, complementando los gates automáticos.

## Errores comunes

- **Mezclar unit tests y eval en la misma suite.** Los unit tests deben correr en segundos y nunca llamar al modelo. Si tu `pytest` tarda 10 minutos porque hace calls a Anthropic, los devs no lo correrán localmente.
- **No mockear el LLM en unit tests.** Cada corrida cuesta dinero, es lenta y es flaky. Usa `unittest.mock.patch` o `responses`/`vcrpy` para fijar respuestas.
- **Tests "flaky" por no fijar seed ni temperatura.** `temperature=0` + seed donde el provider lo permita. Si aún así flakea, es signo de que el prompt no es robusto.
- **Golden set que crece sin curación.** Agregar 50 casos semanales sin revisar duplicados ni etiquetas convierte el set en basura. Nombra un *dataset owner*.
- **Behavioral tests demasiado estrictos.** `assert output == "El plan Pro cuesta USD 20"` falla con "El plan Pro vale 20 USD". Usa `substring`, `regex` o un juez semántico.
- **Interpretar ruido como mejora.** Pasar de 81% a 83% sobre 200 ejemplos **no** es significativo. Aplica bootstrap.
- **No separar baseline por versión del modelo.** Si cambias de `gpt-4o` a `claude-sonnet-4.5`, el baseline cambia; mantener uno solo mezcla variables.
- **Omitir fairness y latencia del gate.** Un modelo "mejor" que es 3× más lento o discrimina por idioma es regresión.
- **No practicar el rollback.** El rollback "obvio" falla en producción. Haz drills en staging mensualmente.
- **No testear el pipeline de orchestration.** Un error en el paso de "subir modelo al registry" se descubre en producción si no hay integration test del orchestrator (Airflow, Kubeflow).
- **Reusar el golden set para fine-tuning.** Contaminación → eval inservible. Mantén holdout estricto, con hash y auditoría.
- **No cachear outputs del LLM en CI.** Si el input no cambió, no vuelvas a pagar. Cachea por hash de `(model, prompt, input, params)`.

## Resumen

- Estratifica la pirámide: **unit tests** del código determinístico, **integration tests** de los componentes, **eval benchmarks** probabilísticos sobre golden set, **behavioral tests** para reglas de negocio.
- El código que rodea al modelo (features, parsing, retries) **es** determinístico y debe tener cobertura alta.
- Los tests probabilísticos requieren **significancia estadística** (bootstrap, McNemar) antes de fallar el gate.
- Un **golden dataset versionado**, curado y fuera del training set es el corazón de la regresión.
- Cada bug reportado se convierte en un caso del golden o behavioral set: la suite crece con el producto.
- Paralelismo (`pytest-xdist`) y caché de respuestas LLM evitan que la suite bloquee a los devs.
- Herramientas clave: **pytest**, **pytest-xdist**, **DeepEval**, **Promptfoo**, **Braintrust**, **LangSmith**, **Ragas** para RAG.
- Un pipeline sin estos niveles deja pasar regresiones silenciosas que los dashboards de accuracy promedio esconden.
