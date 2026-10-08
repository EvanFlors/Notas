# Few-Shot Prompting y selección de ejemplos

## ¿Qué es?

**Few-shot prompting** consiste en incluir dentro del propio prompt un pequeño número de **demostraciones** `(x₁, y₁), (x₂, y₂), ..., (xₖ, yₖ)` antes de la entrada real `x_test`. El modelo infiere el patrón de los ejemplos y lo aplica para generar `y_test`.

Formalmente, se condiciona la distribución de salida sobre los ejemplos:

```
y_test ~ P(y | (x₁,y₁), (x₂,y₂), ..., (xₖ,yₖ), x_test; θ)
```

Nada en `θ` cambia: no hay backpropagation. Este fenómeno se llama **in-context learning (ICL)** y fue el hallazgo central del paper de GPT-3 (**Brown et al., 2020**): modelos suficientemente grandes aprenden tareas nuevas *en tiempo de inferencia* solo mirando ejemplos en el contexto.

### Variantes según cantidad de ejemplos

| k (ejemplos) | Nombre | Uso típico |
|---|---|---|
| 0 | zero-shot | Tareas comunes, bien pre-entrenadas |
| 1 | one-shot | Fijar un formato de salida específico |
| 2-5 | low few-shot | Tareas con cierta ambigüedad |
| 5-20 | high few-shot | Clasificación con muchas clases, formatos complejos |
| 20-100+ | many-shot | Modelos de contexto largo (Gemini 1M, Claude 200K+) |

Chen et al. (2024) y Agarwal et al. (2024) mostraron que **many-shot** en modelos de contexto largo puede acercarse al desempeño de fine-tuning en varias tareas.

## ¿Por qué importa?

Few-shot resuelve el problema recurrente de los sistemas en producción: *"zero-shot funciona la mayor parte del tiempo, pero falla justo en los casos que importan"*. Al mostrar ejemplos:

- **Desambiguas la tarea** sin escribir párrafos de instrucciones.
- **Fijas el formato de salida** con un ejemplo, no con 50 reglas.
- **Enseñas casos borde** (sarcasmo, mezcla de sentimientos, overlaps de categorías).
- **Reduces varianza** entre respuestas, haciendo el sistema más predecible.
- **Mejoras métricas** sin tocar los pesos del modelo (ni GPU, ni dataset de fine-tuning).

### Zero-shot vs. few-shot: comparación directa

| Dimensión | Zero-shot | Few-shot |
|---|---|---|
| Tokens de entrada | Mínimos | Más altos (k × longitud de ejemplo) |
| Costo por request | Más bajo | Más alto (proporcional a k) |
| Latencia | Menor | Mayor |
| Consistencia de formato | Media | Alta |
| Manejo de casos borde | Débil | Fuerte si los ejemplos los cubren |
| Mantenimiento | Solo instrucción | Instrucción + banco de ejemplos |
| Riesgo de sesgo | Instrucción mal escrita | Ejemplos sesgados o desbalanceados |

## ¿Cómo funciona?

### El "punto dulce" de k

La literatura y la experiencia convergen en que **3 a 7 ejemplos de alta calidad** maximizan la razón beneficio/costo para la mayoría de tareas:

```
desempeño
   ▲
   │             ╭──────────────── (saturación)
   │           ╭─╯
   │        ╭──╯
   │     ╭──╯
   │  ╭──╯
   │╭─╯
   └─────────────────────────────▶ k
       1  2  3  5  7   10   20
```

- **k < 3:** el modelo aún trata ejemplos como coincidencias; alta varianza.
- **k = 3-7:** ganancia marginal fuerte.
- **k > 7:** rendimientos decrecientes y riesgo de introducir contradicciones.
- **k >> 20:** solo útil si el modelo es de contexto largo *y* la tarea es compleja.

### Selección de ejemplos: similaridad vs. diversidad

Dos filosofías para elegir qué ejemplos poner:

| Estrategia | Idea | Ventaja | Riesgo |
|---|---|---|---|
| **Similaridad** (kNN sobre embeddings) | Elegir ejemplos semánticamente parecidos a `x_test` | Alta precisión en casos claros | Falla si el banco no cubre el espacio; sesgo por "vecinos" raros |
| **Diversidad** (MMR, k-medoids) | Elegir ejemplos lo más distintos posible entre sí | Robustez; cubre variedad de patrones | Puede incluir ejemplos irrelevantes al input |
| **Híbrido** (relevancia + diversidad) | MMR, DPP, o re-ranking por LLM | Mejor compromiso en producción | Más complejo de implementar |

La estrategia por default en LangChain es `SemanticSimilarityExampleSelector` (kNN), pero `MaxMarginalRelevanceExampleSelector` suele rendir mejor en tareas con heterogeneidad real.

### Orden de los ejemplos

Lu et al. (2022, *"Fantastically Ordered Prompts"*) demostraron que **el mismo set de ejemplos en distinto orden puede cambiar la accuracy en >30 puntos**. Reglas prácticas:

- Pon el ejemplo más representativo **al final** (recency bias: el modelo pondera más lo cercano a `x_test`).
- Mezcla las clases/etiquetas: no pongas 3 positivos seguidos y luego 3 negativos.
- Si clasificas, **balancea** las etiquetas en los ejemplos (iguales conteos por clase).
- Para producción crítica: evalúa varios órdenes y fija el mejor.

### Formato típico

```
Instrucción general de la tarea.

Ejemplo 1:
Input: ...
Output: ...

Ejemplo 2:
Input: ...
Output: ...

...

Input: {entrada_real}
Output:
```

Separadores consistentes (`---`, `###`, saltos de línea dobles) ayudan al parser interno del modelo. Mezclar formatos entre ejemplos degrada el desempeño.

## Ejemplo con código

### Few-shot manual: generador de respuestas de API

```python
from openai import OpenAI
import json

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

EJEMPLOS = [
    {
        "input": "Crear usuario Ana Lopez, correo ana@ejemplo.com",
        "output": {
            "status": "success",
            "user_id": "usr_001",
            "data": {"nombre": "Ana Lopez", "email": "ana@ejemplo.com"},
        },
    },
    {
        "input": "Crear usuario con correo invalido test@",
        "output": {
            "status": "error",
            "error_code": "INVALID_EMAIL",
            "data": {},
        },
    },
    {
        "input": "Crear usuario Juan Perez, correo juan@empresa.mx",
        "output": {
            "status": "success",
            "user_id": "usr_002",
            "data": {"nombre": "Juan Perez", "email": "juan@empresa.mx"},
        },
    },
]

def generar_respuesta_api(peticion):
    partes = ["Genera una respuesta JSON para la peticion del usuario.\n"]
    for i, ej in enumerate(EJEMPLOS, 1):
        partes.append(f"Ejemplo {i}:")
        partes.append(f"Input: {ej['input']}")
        partes.append(f"Output: {json.dumps(ej['output'], ensure_ascii=False)}\n")
    partes.append(f"Input: {peticion}")
    partes.append("Output:")
    prompt = "\n".join(partes)
    r = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,
        response_format={"type": "json_object"},
    )
    return json.loads(r.choices[0].message.content)

print(generar_respuesta_api("Crear usuario Mike Johnson, correo mike@dominio-invalido"))
```

### Selección por similaridad con embeddings (manual)

```python
import numpy as np
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

BANCO = [
    ("La pelicula fue fantastica", "Positivo"),
    ("Odie cada minuto del film", "Negativo"),
    ("La actuacion decente pero la trama lenta", "Mixto"),
    ("Este restaurante supero mis expectativas", "Positivo"),
    ("Nunca mas pediria aqui", "Negativo"),
    ("Comida rica pero servicio pesimo", "Mixto"),
]

def embed(textos):
    r = client.embeddings.create(model="text-embedding-3-small", input=textos)
    return np.array([d.embedding for d in r.data])

BANCO_EMB = embed([t for t, _ in BANCO])

def seleccionar_knn(query, k=3):
    q_emb = embed([query])[0]
    sims = BANCO_EMB @ q_emb / (
        np.linalg.norm(BANCO_EMB, axis=1) * np.linalg.norm(q_emb)
    )
    idx = np.argsort(-sims)[:k]
    return [BANCO[i] for i in idx]

def clasificar_sentimiento(texto):
    ejemplos = seleccionar_knn(texto, k=3)
    prompt = "Clasifica el sentimiento como Positivo, Negativo o Mixto.\n\n"
    for t, s in ejemplos:
        prompt += f"Texto: {t}\nSentimiento: {s}\n\n"
    prompt += f"Texto: {texto}\nSentimiento:"
    r = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,
    )
    return r.choices[0].message.content.strip()

print(clasificar_sentimiento("El hotel estaba limpio pero el personal fue grosero"))
```

### LangChain `FewShotPromptTemplate` + selector por similaridad

```python
from langchain_core.prompts import FewShotPromptTemplate, PromptTemplate
from langchain_core.example_selectors import SemanticSimilarityExampleSelector
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import Chroma

ejemplos = [
    {"input": "La pelicula fue fantastica", "output": "Positivo"},
    {"input": "Odie cada minuto del film", "output": "Negativo"},
    {"input": "Decente pero lenta", "output": "Mixto"},
]

selector = SemanticSimilarityExampleSelector.from_examples(
    ejemplos,
    OpenAIEmbeddings(model="text-embedding-3-small"),
    Chroma,
    k=2,
)

ejemplo_template = PromptTemplate(
    input_variables=["input", "output"],
    template="Texto: {input}\nSentimiento: {output}",
)

prompt = FewShotPromptTemplate(
    example_selector=selector,
    example_prompt=ejemplo_template,
    prefix="Clasifica el sentimiento como Positivo, Negativo o Mixto.\n",
    suffix="Texto: {input}\nSentimiento:",
    input_variables=["input"],
)

print(prompt.format(input="El servicio fue excelente pero la comida fria"))
```

### Many-shot con contexto largo (Claude / Gemini)

```python
# Idea general: cargar 50-200 ejemplos y aprovechar la ventana extendida.
import anthropic

client = anthropic.Anthropic(api_key="API_KEY")

ejemplos_largos = [...]  # ej. 100 pares input/output
contexto = "\n\n".join(
    f"Input: {e['input']}\nOutput: {e['output']}" for e in ejemplos_largos
)

r = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=512,
    messages=[{
        "role": "user",
        "content": (
            "Clasifica siguiendo exactamente el patron de los ejemplos.\n\n"
            f"{contexto}\n\nInput: {{entrada_real}}\nOutput:"
        ),
    }],
)
print(r.content[0].text)
```

## Errores comunes

- **Ejemplos con labels incorrectos.** Un solo ejemplo mal etiquetado contamina toda la tarea; el modelo aprenderá el patrón equivocado.
- **Ejemplos demasiado similares entre sí.** El modelo cree que la tarea es "esto específico" y no generaliza. Síntoma: la clase mayoritaria en los ejemplos aparece siempre en la salida.
- **Distribución sesgada.** 3 ejemplos de "seguridad", 1 de "performance", 1 limpio → el modelo marca casi todo como "seguridad". **Balancea** las clases.
- **Orden no controlado.** El mismo set en orden distinto da métricas distintas. Fija el orden tras evaluación.
- **Formato inconsistente entre ejemplos.** Si uno usa comillas y otro no, uno es JSON y otro texto, el modelo se confunde.
- **Olvidar la instrucción.** Ejemplos solos, sin un verbo que indique la tarea, dejan al modelo adivinar.
- **Context pollution.** Añadir texto irrelevante dentro de los ejemplos (comentarios, metadata) distrae al modelo.
- **No actualizar el banco.** Los casos borde cambian con el tiempo; un banco de ejemplos congelado envejece y degrada.
- **Usar few-shot cuando CoT es lo que falta.** Si el error es de razonamiento (no de formato), más ejemplos no ayudan: necesitas chain-of-thought.
- **Overfitting al banco en producción.** Si el selector siempre devuelve los mismos 3 ejemplos, el sistema no cubrirá queries fuera de distribución. Monitorea cobertura.

## Herramientas y ecosistema

| Herramienta | Rol |
|---|---|
| **LangChain `FewShotPromptTemplate`** | Templating + selectores (similaridad, MMR, longitud) |
| **DSPy** | Optimiza automáticamente qué ejemplos usar según una métrica |
| **PromptLayer / LangSmith** | Versionar prompts y A/B testear sets de ejemplos |
| **ChromaDB / Pinecone / pgvector** | Store vectorial para selección por similaridad |
| **Instructor / Pydantic** | Validar que la salida few-shot cumpla el esquema |

## Resumen

- **Few-shot** = incluir ejemplos `(xᵢ, yᵢ)` en el prompt para enseñar un patrón en tiempo de inferencia (**in-context learning**).
- Punto dulce: **3-7 ejemplos de alta calidad**; en modelos de contexto largo, **many-shot** (50+) puede acercarse a fine-tuning.
- La **selección** importa: kNN (similaridad), diversidad (MMR) o híbrido.
- El **orden** importa: ejemplos más representativos al final; balancea clases; evita bloques por etiqueta.
- Errores típicos: labels incorrectos, ejemplos sesgados o demasiado similares, formatos inconsistentes.
- Few-shot resuelve problemas de **formato y desambiguación**, no de **razonamiento** (para eso, CoT).
- En producción: versiona ejemplos, mide cobertura, y combina con validación de esquema.
