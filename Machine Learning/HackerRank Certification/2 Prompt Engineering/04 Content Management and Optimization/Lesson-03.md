# Prompt Chaining para Tareas Complejas

## ¿Qué es?

**Prompt chaining** es la técnica de descomponer una tarea compleja en una **secuencia de prompts más pequeños**, donde la salida de uno alimenta a los siguientes. En vez de pedirle al modelo "analiza el trimestre, diseña la estrategia y arma el plan de ejecución" en un solo tiro —y obtener resultados superficiales—, se encadenan pasos especializados, cada uno con un objetivo único.

Formalmente, una cadena es una función composicional:

```
resultado = f_n ∘ f_{n-1} ∘ … ∘ f_1 (input_inicial)
```

donde cada `f_i` es una llamada al LLM con un prompt distinto, y el estado intermedio (`output_i`) se pasa como contexto a `f_{i+1}`.

Hay tres topologías básicas:

| Tipo | Forma | Cuándo usarla |
|---|---|---|
| **Secuencial** | A → B → C | Flujo lineal donde cada paso depende del anterior |
| **Branching (paralela)** | A → {B, C, D} → E | Perspectivas independientes que se sintetizan |
| **Condicional** | A → (si X: B, sino: C) | El camino depende del resultado intermedio |

### Relación con otros conceptos

- **Chain-of-Thought (CoT):** razonar en voz alta dentro de **un solo** prompt. Chaining es "CoT entre llamadas".
- **Agentes:** chains con bucle + herramientas + memoria. Chaining es el ancestro directo.
- **LangChain Expression Language (LCEL), LangGraph, DSPy:** frameworks modernos para expresar cadenas como grafos.

## ¿Por qué importa?

Porque los LLMs tienen **atención finita**: cuando un solo prompt mezcla análisis, decisión y redacción, la calidad de cada subtarea cae. Chaining importa cuando:

- La tarea tiene **más de 3-4 subtareas distintas** (síntoma: tu prompt pasa de 400 palabras).
- Los pasos requieren **modelos diferentes** (clasificar barato, razonar caro).
- Necesitas **validar y reintentar** pasos intermedios.
- Hay **ramas condicionales** basadas en el contenido (si es queja → escalar, si es pregunta → responder).
- Quieres **paralelizar** análisis independientes para reducir latencia.

### Ventajas concretas

| Ventaja | Impacto |
|---|---|
| Mejor calidad por paso | Cada prompt tiene un objetivo único, no se dispersa |
| Debug granular | Puedes inspeccionar el output de cada eslabón |
| Modelo apropiado por paso | Mini para clasificación, grande para síntesis |
| Reintento selectivo | Falló el paso 3, no re-corres 1 y 2 |
| Guardrails incrementales | Validas entre pasos antes de propagar errores |

### El costo: latencia y acumulación de errores

- **Latencia:** 5 llamadas secuenciales ≈ 5× la latencia de una. Mitiga con branches paralelos y streaming.
- **Error propagation:** si cada paso tiene 95% de éxito, 5 pasos secuenciales dan 0.95⁵ ≈ **77%**. Añade validadores.

## ¿Cómo funciona?

### 1. Descomposición de tareas

Toda cadena nace de una **descomposición** correcta. Reglas:

- Cada paso tiene **una** responsabilidad clara ("extraer entidades", no "extraer y clasificar").
- Identifica **dependencias**: qué paso necesita qué output.
- Lo que es **independiente** → paraleliza en branches.
- El output de cada paso debe tener **formato estructurado** (JSON, lista, markdown) para que el siguiente lo consuma sin ambigüedad.

### 2. Patrones de orquestación

| Patrón | Uso típico |
|---|---|
| **Sequential pipeline** | Resumir → traducir → corregir estilo |
| **Map-reduce** | Procesar N chunks en paralelo, luego sintetizar |
| **Router** | Clasificar intent, enviar al handler apropiado |
| **Reflection** | Generar → criticar → refinar |
| **Debate** | Dos agentes argumentan, un juez decide |
| **Plan-and-execute** | LLM-planner genera plan, LLM-worker ejecuta pasos |

### 3. Validación entre pasos

```
Paso i → Output_i → Validador(Output_i) → ¿OK?
                                          ├─ sí → Paso i+1
                                          └─ no → reintentar / fallback
```

Validadores comunes:

- **Schema:** `pydantic.ValidationError` sobre JSON esperado.
- **Semántica:** "¿el output cita las fuentes requeridas?" vía regex o LLM-judge.
- **Business rules:** "el monto no puede ser negativo".
- **Guardrails libraries:** NeMo Guardrails, Guardrails AI.

### 4. Context management entre eslabones

El error más común es pasar **todo** el output del paso anterior al siguiente. Mejor:

- Pasa **solo lo necesario** (ej. la lista de IDs, no el reasoning completo).
- **Resume** outputs largos antes de propagar.
- Mantén un **"estado"** separado del "mensaje" (patrón LangGraph).

## Ejemplo con código

### Pipeline secuencial: análisis de API → documentación

```python
from openai import OpenAI
client = OpenAI()

def llm(prompt: str, modelo: str = "gpt-5-mini", temp: float = 0.2) -> str:
    r = client.chat.completions.create(
        model=modelo, temperature=temp,
        messages=[{"role": "user", "content": prompt}],
    )
    return r.choices[0].message.content

# Paso 1: Análisis estructural
def paso1_analizar(endpoint: str) -> str:
    return llm(f"""Analiza este endpoint y devuelve JSON con:
- functionality: str
- parameters: list[{{name, type, required}}]
- response_schema: dict
- error_cases: list[str]

Endpoint: {endpoint}""")

# Paso 2: Esquema de documentación
def paso2_outline(analisis: str) -> str:
    return llm(f"""Dado este análisis:
{analisis}

Produce un outline markdown con secciones: Overview, Parameters, Examples, Errors.""")

# Paso 3: Redacción final
def paso3_redactar(outline: str, analisis: str) -> str:
    return llm(f"""Escribe la documentación completa siguiendo este outline:
{outline}

Datos técnicos:
{analisis}

Incluye ejemplos curl y respuestas JSON.""", modelo="gpt-5")

# Orquestación
endpoint = "GET /users/{user_id}/orders"
analisis = paso1_analizar(endpoint)
outline  = paso2_outline(analisis)
doc      = paso3_redactar(outline, analisis)
print(doc)
```

### Branching: análisis de adquisición empresarial

```python
import asyncio
from openai import AsyncOpenAI

aclient = AsyncOpenAI()

async def allm(prompt: str, modelo: str = "gpt-5-mini") -> str:
    r = await aclient.chat.completions.create(
        model=modelo, temperature=0.3,
        messages=[{"role": "user", "content": prompt}],
    )
    return r.choices[0].message.content

async def pipeline_adquisicion(datos_empresa: str) -> dict:
    # Paso 1: estructurar datos
    estructurado = await allm(f"Extrae métricas financieras, mercado, equipo:\n{datos_empresa}")

    # Paso 2: ramas en paralelo
    financiera, mercado, operaciones = await asyncio.gather(
        allm(f"Análisis financiero profundo:\n{estructurado}"),
        allm(f"Análisis de posición de mercado:\n{estructurado}"),
        allm(f"Análisis operacional y escalabilidad:\n{estructurado}"),
    )

    # Paso 3: síntesis con modelo potente
    sintesis = await allm(f"""Integra estos tres análisis en una recomendación go/no-go:

[FINANZAS]
{financiera}

[MERCADO]
{mercado}

[OPERACIONES]
{operaciones}

Devuelve: executive summary, riesgos, prioridades de integración, recomendación.""",
        modelo="gpt-5")

    return {"financiera": financiera, "mercado": mercado,
            "operaciones": operaciones, "sintesis": sintesis}

# resultado = asyncio.run(pipeline_adquisicion(datos))
```

Latencia: con 4 llamadas, secuencial ≈ 20s; con el branching de 3 paralelas, ≈ 10s.

### Conditional chaining: router de soporte

```python
import json

def paso_router(mensaje_usuario: str) -> dict:
    out = llm(f"""Clasifica el mensaje y devuelve JSON:
{{"intent": "complaint|question|feature_request|billing",
  "sentiment": "negative|neutral|positive",
  "urgency": "low|medium|high"}}

Mensaje: {mensaje_usuario}""")
    return json.loads(out)

def handle_complaint(msg, meta):   return llm(f"Escribe respuesta empática y escala a humano:\n{msg}", modelo="gpt-5")
def handle_question(msg, meta):    return llm(f"Responde con hechos y cita docs:\n{msg}")
def handle_billing(msg, meta):     return llm(f"Deriva a sistema de billing con JSON de acción:\n{msg}")

ROUTER = {
    "complaint": handle_complaint,
    "question":  handle_question,
    "billing":   handle_billing,
}

def responder(msg: str) -> str:
    meta = paso_router(msg)
    if meta["urgency"] == "high":
        return handle_complaint(msg, meta)   # bypass: urgencias siempre a humano
    return ROUTER.get(meta["intent"], handle_question)(msg, meta)
```

### Reflection loop: generar → criticar → refinar

```python
def generar_refinar(tarea: str, iteraciones: int = 2) -> str:
    draft = llm(f"Escribe un primer borrador de:\n{tarea}")
    for _ in range(iteraciones):
        critica = llm(f"""Critica este borrador señalando errores factuales,
ambigüedades y mejoras concretas:

{draft}""", modelo="gpt-5")
        draft = llm(f"""Reescribe el borrador aplicando esta crítica.

Borrador:
{draft}

Crítica:
{critica}""")
    return draft
```

### Validación entre pasos con Pydantic

```python
from pydantic import BaseModel, ValidationError

class AnalisisAPI(BaseModel):
    functionality: str
    parameters: list[dict]
    response_schema: dict
    error_cases: list[str]

def paso1_con_validacion(endpoint: str, max_reintentos: int = 3) -> AnalisisAPI:
    for intento in range(max_reintentos):
        try:
            raw = paso1_analizar(endpoint)
            return AnalisisAPI.model_validate_json(raw)
        except ValidationError as e:
            if intento == max_reintentos - 1:
                raise
            # Reintenta pasando el error como contexto
            endpoint = f"{endpoint}\n\nIntento anterior falló: {e}. Devuelve JSON válido."
```

### Prompt versioning (LangSmith / Langfuse / hash local)

```python
import hashlib, json, datetime

class RegistroPrompts:
    def __init__(self, path="prompts.jsonl"):
        self.path = path

    def registrar(self, nombre: str, template: str, metadata: dict | None = None) -> str:
        version_hash = hashlib.sha256(template.encode()).hexdigest()[:12]
        registro = {
            "nombre": nombre,
            "version": version_hash,
            "template": template,
            "metadata": metadata or {},
            "ts": datetime.datetime.utcnow().isoformat(),
        }
        with open(self.path, "a") as f:
            f.write(json.dumps(registro) + "\n")
        return version_hash

reg = RegistroPrompts()
v = reg.registrar("router_soporte_v2", "Clasifica el mensaje...", {"owner": "support-team"})
# Guarda el `v` junto con cada trace para poder reproducir después.
```

En producción se usa **LangSmith** (Hub de prompts versionados con A/B testing nativo), **Langfuse** (open source, versiones + eval), **Promptfoo** (benchmark CLI entre versiones), **Helicone** (observabilidad por prompt_id).

### A/B testing de prompts con Promptfoo

```yaml
# promptfooconfig.yaml
prompts:
  - "promptA.txt"
  - "promptB.txt"
providers:
  - openai:gpt-5-mini
tests:
  - vars:
      pregunta: "¿Cómo reseteo mi contraseña?"
    assert:
      - type: contains
        value: "ajustes"
      - type: llm-rubric
        value: "La respuesta es empática y menciona pasos concretos"
  - vars:
      pregunta: "No puedo iniciar sesión"
    assert:
      - type: latency
        threshold: 2000
```

Ejecuta `npx promptfoo eval` y obtienes tabla comparativa de calidad, costo y latencia por versión.

## Errores comunes

- **Cadenas demasiado largas.** 10 pasos secuenciales = latencia alta y acumulación de errores (0.95¹⁰ ≈ 60% success). Empieza con 2-3 pasos.
- **Pasar demasiado contexto entre pasos.** Reenviar el output completo del paso 1 al paso 5 multiplica tokens. Pasa solo lo necesario o resume.
- **No validar outputs intermedios.** Un JSON malformado del paso 2 revienta todo el resto. Usa Pydantic + reintento con feedback.
- **Prompts hardcodeados sin versionar.** No puedes comparar "antes vs. después" ni reproducir regresiones. Usa LangSmith/Langfuse o al menos un hash local.
- **Mismo modelo caro para todos los pasos.** Clasifica con `gpt-5-mini` ($0.0008/MTok), sintetiza con `gpt-5` ($0.025/MTok). Ahorro típico: 70%.
- **Ramas paralelas secuenciales.** Si usas `asyncio.gather` mal (o requests sync), pierdes el beneficio. Mide latencia end-to-end.
- **Síntesis sin estructurar las ramas.** Si cada rama devuelve prosa libre, la síntesis se vuelve resumen de resúmenes. Pide formato estructurado (JSON, bullets) a cada rama.
- **No instrumentar la cadena.** Sin tracing (LangSmith, Langfuse, OpenTelemetry) no puedes debuggear por qué el paso 4 es lento o caro.
- **Sobre-ingeniería prematura.** Si un prompt bien hecho con CoT funciona, no armes una chain de 5 pasos "porque es más elegante".
- **Olvidar human-in-the-loop en decisiones críticas.** Para finanzas, salud o legal, añade checkpoints de aprobación humana entre ramas.

## Herramientas del ecosistema

| Herramienta | Para qué |
|---|---|
| **LangChain / LCEL** | Expresar chains como pipes (`prompt | model | parser`) |
| **LangGraph** | Chains como grafos con estado y ciclos |
| **DSPy** | Chains optimizables programáticamente |
| **LangSmith** | Tracing, versionado y A/B de prompts |
| **Langfuse** | Alternativa open-source a LangSmith |
| **Promptfoo** | Benchmark CLI de calidad y costo entre versiones |
| **Helicone** | Observabilidad de costos y latencia por prompt_id |
| **Guardrails AI / NeMo Guardrails** | Validación semántica entre pasos |

## Resumen

- **Prompt chaining** descompone tareas complejas en pasos pequeños y especializados; sube calidad y permite debug granular.
- Tres topologías: **secuencial** (A→B→C), **branching paralela** (A→{B,C}→D), **condicional** (ramas según resultado).
- Cada paso debe tener **una** responsabilidad y producir **output estructurado** para el siguiente.
- Usa **modelos distintos por paso**: mini para clasificar, grande para sintetizar; ahorro típico 50-70%.
- Las ramas independientes se **paralelizan** con `asyncio.gather` para cortar latencia.
- **Valida outputs intermedios** con Pydantic o guardrails; sin validación, errores se propagan y multiplican.
- **Versiona todos los prompts** (hash local, LangSmith, Langfuse); sin versiones no hay reproducibilidad ni A/B.
- Haz **A/B testing** con Promptfoo o LangSmith para medir calidad, costo y latencia por versión.
- Instrumenta tracing extremo a extremo (LangSmith, Langfuse, Helicone) desde el día uno.
- Empieza simple: 2-3 pasos secuenciales. Añade branching, condicionales o reflection solo cuando los datos lo justifiquen.
