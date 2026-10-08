# Zero-Shot Prompting

## ¿Qué es?

**Zero-shot prompting** es la técnica de pedirle a un modelo de lenguaje que resuelva una tarea **sin mostrarle ejemplos** de entrada-salida: solo le damos la instrucción en lenguaje natural y confiamos en que el conocimiento adquirido durante su pre-entrenamiento sea suficiente para generalizar.

Formalmente, dado un prompt `p` que describe la tarea `T` y una entrada `x`, el modelo produce una respuesta `y` muestreando de la distribución condicional:

```
y ~ P(y | p, x; θ)
```

Donde `θ` son los parámetros del modelo (congelados: no hay entrenamiento ni fine-tuning). Lo relevante es que `P(y | p, x; θ)` ya ha sido *implícitamente* aprendido durante el pre-entrenamiento masivo, y el prompt `p` actúa como una **señal condicional** que selecciona la sub-distribución relevante para la tarea.

### Zero-shot vs. one-shot vs. few-shot

| Variante | # de ejemplos en el prompt | Cuándo usar |
|---|---|---|
| **Zero-shot** | 0 | Tareas comunes y bien definidas; alto volumen; sin ejemplos curados |
| **One-shot** | 1 | Formato de salida muy específico que un solo ejemplo deja claro |
| **Few-shot** | 2 a ~10 | Tareas con ambigüedad, bordes sutiles o salidas estructuradas |

El término se popularizó con **Brown et al., 2020** (*"Language Models are Few-Shot Learners"*, el paper de GPT-3), donde se demostró que modelos grandes pueden alcanzar desempeño competitivo en benchmarks sin un solo ejemplo supervisado.

## ¿Por qué importa?

Zero-shot es la forma por default en que los usuarios interactúan con LLMs en producción: ChatGPT, Claude.ai o Gemini reciben instrucciones directas, no demostraciones. Importa porque:

- **Escala a bajo costo:** no requiere mantener bancos de ejemplos ni labels de entrenamiento.
- **Ahorra tokens:** cada ejemplo que no incluyes libera contexto para la entrada real y la respuesta.
- **Reduce latencia:** menos tokens de entrada → menor TTFT (time-to-first-token) y menor costo por request.
- **Es el baseline obligatorio:** antes de añadir ejemplos, debes medir qué tan lejos llega el modelo solo con la instrucción. Si zero-shot ya alcanza la métrica objetivo, añadir few-shot es sobre-ingeniería.
- **Habilita tareas abiertas:** generar contenido creativo o explorar ideas se beneficia de **no** anclar al modelo con ejemplos que lo encajonen.

### Cuándo NO usar zero-shot

| Síntoma | Técnica recomendada |
|---|---|
| Salida con formato muy específico que el modelo "casi" acierta | Few-shot con 2-3 ejemplos del formato |
| Tarea de clasificación con fronteras ambiguas entre clases | Few-shot con ejemplos de casos borde |
| Razonamiento aritmético o lógico multi-paso | Chain-of-thought (ver Lesson-03) |
| Dominio con jerga especializada (legal, médico, financiero) | Few-shot + system prompt experto |
| Alucinaciones recurrentes sobre hechos | RAG (recuperación de contexto) |

## ¿Cómo funciona?

El modelo depende de tres mecanismos aprendidos durante el pre-entrenamiento:

1. **Reconocimiento de patrones de instrucción.** Verbos como *"summarize"*, *"classify"*, *"translate"* activan sub-distribuciones de respuesta porque el modelo vio millones de ejemplos durante pre-entrenamiento y RLHF.
2. **Instruction following.** El fine-tuning por instrucciones (InstructGPT, Flan, Alpaca) alinea al modelo para obedecer directivas en vez de limitarse a continuar texto.
3. **Comprensión contextual.** Mecanismos de atención permiten que el modelo relacione la instrucción con la entrada específica, incluso cuando ambas están entrelazadas.

### Anatomía de un buen prompt zero-shot

```
┌──────────────────────────────────────────┐
│  [ROL]       Eres un analista fiscal...  │  ← system prompt
├──────────────────────────────────────────┤
│  [TAREA]     Clasifica la siguiente...   │  ← verbo + objeto
│  [CONTEXTO]  Las categorías son A,B,C... │  ← información necesaria
│  [FORMATO]   Responde solo con la etiq.  │  ← estructura de salida
│  [RESTRICC.] No expliques tu decisión.   │  ← prohibiciones explícitas
├──────────────────────────────────────────┤
│  [ENTRADA]   {texto_a_clasificar}        │  ← datos variables
└──────────────────────────────────────────┘
```

### Factores que determinan el éxito

| Factor | Efecto |
|---|---|
| Tamaño del modelo | Capacidades zero-shot emergen con escala (GPT-3 175B >> GPT-2) |
| RLHF / instruction tuning | Convierte un modelo autocompletador en un seguidor de instrucciones |
| Especificidad de la instrucción | "Analiza esto" falla; "Lista 3 riesgos operacionales" funciona |
| Formato explícito | Pedir JSON válido reduce errores de parsing en producción |
| Longitud y claridad del contexto | Demasiado contexto diluye la atención; muy poco causa ambigüedad |

## Ejemplo con código

### Generador de descripciones de producto

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

def generar_descripcion(nombre, caracteristicas, audiencia):
    prompt = f"""
    Escribe una descripcion de producto para "{nombre}" que:
    - Resalte estas caracteristicas: {', '.join(caracteristicas)}
    - Hable directamente a: {audiencia}
    - Use lenguaje persuasivo sin ser exagerado
    - Tenga entre 50 y 100 palabras
    - Termine con un call-to-action concreto
    """
    respuesta = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
    )
    return respuesta.choices[0].message.content

print(generar_descripcion(
    nombre="Audifonos con cancelacion de ruido",
    caracteristicas=["ANC activo", "30h de bateria", "carga rapida"],
    audiencia="trabajadores remotos y viajeros frecuentes",
))
```

### Clasificador de tickets de soporte

```python
def clasificar_ticket(contenido, categorias):
    prompt = f"""
    Clasifica el siguiente ticket en EXACTAMENTE una de estas categorias:
    {', '.join(categorias)}

    Reglas:
    - Responde con el nombre exacto de la categoria, sin explicaciones.
    - Si no encaja en ninguna, responde "OTRO".

    Ticket: "{contenido}"
    Categoria:"""
    respuesta = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,  # determinista para clasificacion
    )
    return respuesta.choices[0].message.content.strip()

categorias = ["Problema tecnico", "Facturacion", "Solicitud de funcion", "Cuenta"]
print(clasificar_ticket("No puedo iniciar sesion desde ayer", categorias))
```

El uso de `temperature=0` es clave en zero-shot para clasificación: elimina la aleatoriedad y hace reproducibles las decisiones, condición indispensable para auditoría y para medir métricas de forma estable.

### Zero-shot con JSON estructurado (producción)

```python
import json

def extraer_entidades(texto):
    prompt = f"""
    Extrae entidades del siguiente texto. Devuelve SOLO JSON valido con el esquema:
    {{"personas": [str], "organizaciones": [str], "fechas": [str]}}

    Texto: "{texto}"
    JSON:"""
    respuesta = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
        temperature=0,
    )
    return json.loads(respuesta.choices[0].message.content)

print(extraer_entidades(
    "Ayer, Ana Lopez de Globex anuncio la fusion con Initech para el 15 de marzo de 2026."
))
```

Forzar `response_format={"type": "json_object"}` (OpenAI) o usar *tool use* / *structured outputs* (Anthropic) hace que zero-shot sea viable incluso para pipelines con parsing estricto.

## Errores comunes

- **Instrucción ambigua.** "Analiza esto" admite decenas de interpretaciones. Reemplaza por "Identifica los 3 productos con mayor margen y explica la estacionalidad de cada uno".
- **Mezclar formatos sin especificarlos.** Si pides "una lista" sin aclarar si es Markdown, JSON o texto plano, cada corrida saldrá distinta.
- **Esperar razonamiento multi-paso en una sola corrida.** Zero-shot sin chain-of-thought alucina pasos intermedios o salta a la conclusión. Para aritmética y lógica, escala a CoT.
- **Suponer conocimiento especializado.** Pedir "diagnostica este ECG" en zero-shot sin contexto clínico produce respuestas plausibles pero no confiables.
- **No fijar `temperature`.** Para clasificación o extracción debe ser 0 o cercano a 0; para creatividad, 0.7-1.0. Dejarlo en el default sin pensarlo introduce varianza invisible.
- **Terminología inconsistente.** Alternar entre "usuario", "cliente" y "lead" en el mismo prompt confunde al modelo.
- **Prompts gigantes "por si acaso".** Añadir contexto irrelevante diluye la atención del modelo y aumenta costo + latencia.
- **No validar el output.** En producción siempre debes verificar que la respuesta cumple el esquema esperado (schema validation, regex o `pydantic`), con un fallback definido.
- **Confundir "falló zero-shot" con "necesito few-shot".** A veces el problema es la instrucción, no la falta de ejemplos. Itera el prompt antes de añadir examples.

## Herramientas y ecosistema

| Herramienta | Rol en zero-shot |
|---|---|
| **OpenAI / Anthropic SDK** | APIs base; `response_format` y `tools` para estructura |
| **LangChain `PromptTemplate`** | Reutilizar y versionar prompts |
| **DSPy** | Optimizar prompts automáticamente con métricas |
| **Guardrails / Instructor / Pydantic** | Validar y re-pedir si el JSON está mal formado |
| **LangSmith / Langfuse / Weights & Biases Prompts** | Trazar, versionar y A/B-testear prompts en producción |

## Resumen

- **Zero-shot** = pedir sin ejemplos; depende del conocimiento pre-entrenado del modelo.
- Funciona bien para tareas comunes, bien definidas y con alto volumen.
- Fue el gran hallazgo de **GPT-3 (Brown et al., 2020)**: los LLMs grandes generalizan sin fine-tuning.
- La calidad del output depende de **instrucción explícita + formato definido + `temperature` adecuada**.
- No es siempre la mejor opción: para fronteras ambiguas usa few-shot, para razonamiento usa CoT, para hechos usa RAG.
- En producción, **valida el output** (JSON schema, regex, re-ask) y **mide una línea base zero-shot** antes de añadir complejidad.
