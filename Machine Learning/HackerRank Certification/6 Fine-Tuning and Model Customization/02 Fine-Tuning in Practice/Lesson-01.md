# Instruction Tuning vs Completion Tuning

## ¿Qué es?

Al hacer **fine-tuning** de un modelo de lenguaje, la primera decisión arquitectónica es elegir entre **instruction tuning** y **completion tuning**. No es un detalle menor: define cómo formateas los datos, qué aprende el modelo, cómo lo invocas en producción y qué *chat template* debes usar.

- **Instruction tuning:** entrena al modelo a **seguir instrucciones** y responder en formato conversacional. Cada ejemplo tiene una *instrucción* explícita (lo que debe hacer), una *entrada* opcional (el dato sobre el que opera) y una *salida* (la respuesta esperada). Es el formato de ChatGPT, Claude, Llama-Instruct, Mistral-Instruct, etc.
- **Completion tuning:** entrena al modelo a **continuar texto** siguiendo un patrón o estilo. El ejemplo es un `prompt` crudo y la `completion` que el modelo debe generar. Es el formato clásico de GPT-3 (`text-davinci-003`) y de los modelos *base* no alineados.

A lo largo de este submódulo trabajarás con un caso práctico recurrente: **fine-tunear un modelo 7B para un chatbot de soporte al cliente** que clasifica tickets, redacta respuestas y extrae información. Verás cómo cada decisión técnica se traduce en comportamiento real del chatbot.

### Comparación rápida

| Dimensión | Instruction tuning | Completion tuning |
|---|---|---|
| Formato del dato | `{instruction, input, output}` o `{messages: [...]}` | `{prompt, completion}` |
| Qué aprende el modelo | Seguir órdenes variadas | Continuar un patrón fijo |
| Aplicación típica | Chatbots, asistentes, Q&A | Autocompletado de código, templates, estilo literario |
| Requiere chat template | Sí (ChatML, Llama 3, Alpaca…) | No necesariamente |
| Dataset mínimo útil | 500-5,000 ejemplos | 100-1,000 ejemplos |
| Flexibilidad en inferencia | Alta: cambia la instrucción | Baja: depende del prefijo exacto |

## ¿Por qué importa?

Elegir mal el formato es la causa #1 de modelos fine-tuneados que "no funcionan como esperaba". Dos escenarios reales:

1. **Equipo usa completion tuning para un chatbot.** El modelo aprende a continuar texto pero no interpreta variaciones de instrucción. En producción, cualquier reformulación del usuario (`"clasifica este ticket"` vs `"¿de qué categoría es?"`) rompe la respuesta.
2. **Equipo usa instruction tuning para un generador de templates fijos.** Añade overhead de tokens de instrucción, aumenta latencia y requiere más datos para converger en un patrón que podría aprenderse directamente como completion.

Además, el formato elegido **determina el chat template** que debes aplicar en training *y* en inferencia. Un mismatch entre training template y serving template produce respuestas truncadas, repeticiones infinitas o degradación silenciosa de calidad.

## ¿Cómo funciona?

### Formato de datos: JSONL es el estándar

Casi todas las bibliotecas modernas (HuggingFace TRL, OpenAI fine-tuning, Axolotl, Unsloth) consumen **JSONL** (JSON Lines): un objeto JSON por línea. Esto permite streaming, concatenación trivial y shuffling eficiente.

**Instruction tuning estilo Alpaca:**

```jsonl
{"instruction": "Clasifica este ticket por urgencia y categoría.", "input": "Mi pedido #12345 no ha llegado. Debía estar hace 3 días.", "output": "Urgencia: Alta\nCategoría: Problema de envío"}
{"instruction": "Genera una respuesta útil para esta consulta.", "input": "¿Cómo devuelvo un artículo que compré la semana pasada?", "output": "Gracias por contactarnos. Para devolver un artículo, visita tu cuenta..."}
```

**Instruction tuning estilo chat (formato moderno, recomendado):**

```jsonl
{"messages": [{"role": "system", "content": "Eres un asistente de soporte al cliente."}, {"role": "user", "content": "Mi pedido #12345 no ha llegado."}, {"role": "assistant", "content": "Lamento el inconveniente. ¿Me compartes el correo de confirmación?"}]}
{"messages": [{"role": "user", "content": "¿Cómo devuelvo un artículo?"}, {"role": "assistant", "content": "Visita tu cuenta, selecciona la orden y haz clic en 'Devolver'..."}]}
```

**Completion tuning:**

```jsonl
{"prompt": "Asunto: Confirmación de pedido\n\nEstimado", "completion": " [Cliente],\n\nGracias por tu pedido #[Número]..."}
{"prompt": "Ticket #12345 - Problema de envío\nEstado:", "completion": " En progreso\nAsignado a: Equipo de envíos..."}
```

### Chat templates: ChatML, Llama 3, Alpaca

Un **chat template** es la forma de serializar una conversación `[{role, content}, ...]` en una cadena de tokens que el modelo entienda. Cada familia de modelos usa el suyo y **debes usar exactamente el que vino con el modelo base**.

| Template | Modelos | Formato (ejemplo) |
|---|---|---|
| **Alpaca** | Alpaca, Vicuna 1.0 | `### Instruction:\n{instr}\n\n### Input:\n{inp}\n\n### Response:\n{out}` |
| **ChatML** | OpenAI, Qwen, varios open-source | `<|im_start|>user\n{msg}<|im_end|>\n<|im_start|>assistant\n{resp}<|im_end|>` |
| **Llama 3** | Llama 3/3.1/3.2 Instruct | `<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n{msg}<|eot_id|>...` |
| **Llama 2** | Llama 2 Chat | `<s>[INST] <<SYS>>\n{sys}\n<</SYS>>\n\n{msg} [/INST] {resp} </s>` |
| **Mistral** | Mistral/Mixtral Instruct | `<s>[INST] {msg} [/INST] {resp}</s>` |
| **Gemma** | Gemma Instruct | `<start_of_turn>user\n{msg}<end_of_turn>\n<start_of_turn>model\n{resp}<end_of_turn>` |

HuggingFace resuelve esto con `tokenizer.apply_chat_template()`, que lee el template del `tokenizer_config.json` del modelo:

```python
from transformers import AutoTokenizer

tok = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B-Instruct")
messages = [
    {"role": "system", "content": "Eres un asistente de soporte."},
    {"role": "user", "content": "Mi pedido no llegó."},
]
texto = tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
print(texto)
```

### Tokenización para training: máscaras de loss

En **instruction tuning**, un detalle crítico que muchos olvidan: la **pérdida (loss) debe calcularse sólo sobre los tokens del `assistant`**, no sobre los del `user` ni los de la instrucción. Si entrenas con la pérdida activa sobre los tokens de usuario, el modelo intenta "aprender" a predecir las preguntas, lo que degrada su capacidad de responder.

En HuggingFace TRL, `DataCollatorForCompletionOnlyLM` o `SFTTrainer` con `response_template` se encargan de esto automáticamente.

### Cuándo elegir cada enfoque

**Usa instruction tuning cuando:**

- Construyes una aplicación **interactiva** (chatbot, asistente).
- Un solo modelo debe cubrir **múltiples tareas** según la instrucción.
- Los usuarios formularán peticiones **variadas y no predecibles**.
- Quieres aprovechar **modelos *Instruct* existentes** (Llama-Instruct, Mistral-Instruct) como punto de partida.

**Usa completion tuning cuando:**

- La aplicación es **no interactiva** y sigue un **patrón fijo** (generador de templates, autocompletado de código con prefijo claro).
- Dispones de un **modelo base** (no instruct) y quieres especializarlo en un dominio.
- Los datos son escasos y el patrón es muy regular.
- Necesitas **latencia mínima**: sin tokens de instrucción, el prompt es más corto.

## Ejemplo con código

### Preparar un dataset instruction-tuning y aplicar el chat template

```python
import json
from pathlib import Path
from transformers import AutoTokenizer

# 1. Dataset crudo del equipo de soporte
raw = [
    {
        "instruction": "Clasifica este ticket por urgencia y categoría.",
        "input": "Mi pedido #12345 no ha llegado. Era para un evento mañana.",
        "output": "Urgencia: Alta\nCategoría: Problema de envío\nTipo: Retraso",
    },
    {
        "instruction": "Genera una respuesta útil para esta consulta.",
        "input": "¿Cómo devuelvo un artículo que compré la semana pasada?",
        "output": "Para devolver un artículo, visita tu cuenta y haz clic en 'Devolver'...",
    },
    {
        "instruction": "Extrae la información clave de este mensaje.",
        "input": "Hola, hice la orden #67890 el 15 de marzo por $149.99 pero no me llegó el correo.",
        "output": "Número de orden: 67890\nFecha: 15 de marzo\nTotal: $149.99\nIssue: Correo faltante",
    },
]

# 2. Convertir a formato chat (messages)
def a_chat(ex):
    user = ex["instruction"]
    if ex.get("input"):
        user += f"\n\n{ex['input']}"
    return {
        "messages": [
            {"role": "system", "content": "Eres un asistente de soporte al cliente."},
            {"role": "user", "content": user},
            {"role": "assistant", "content": ex["output"]},
        ]
    }

dataset_chat = [a_chat(ex) for ex in raw]

# 3. Escribir JSONL
Path("data").mkdir(exist_ok=True)
with open("data/soporte_train.jsonl", "w", encoding="utf-8") as f:
    for ejemplo in dataset_chat:
        f.write(json.dumps(ejemplo, ensure_ascii=False) + "\n")

# 4. Verificar aplicación del chat template
tok = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B-Instruct")
texto = tok.apply_chat_template(dataset_chat[0]["messages"], tokenize=False)
print(texto[:400])
```

### Formato para OpenAI fine-tuning API

OpenAI espera JSONL con el campo `messages`:

```python
import json

ejemplos_openai = [
    {
        "messages": [
            {"role": "system", "content": "Eres un clasificador de tickets de soporte."},
            {"role": "user", "content": "Mi pedido #12345 no ha llegado."},
            {"role": "assistant", "content": "Urgencia: Alta\nCategoría: Envío"},
        ]
    },
    # ... más ejemplos
]

with open("data/openai_sft.jsonl", "w", encoding="utf-8") as f:
    for ex in ejemplos_openai:
        f.write(json.dumps(ex, ensure_ascii=False) + "\n")
```

### Conversión entre formatos

De **completion** a **instruction** (para habilitar interactividad):

```python
completion_ex = {
    "prompt": "Asunto: Confirmación de pedido\n\nEstimado",
    "completion": " [Cliente],\n\nGracias por tu pedido..."
}

instruction_ex = {
    "instruction": "Genera un correo de confirmación de pedido para este cliente.",
    "input": "Cliente: Juan Pérez, Pedido #12345, Monto: $149.99",
    "output": "Asunto: Confirmación de pedido\n\nEstimado Juan Pérez,\n\nGracias por tu pedido #12345...",
}
```

De **instruction** a **completion** (para sistemas de plantillas fijas):

```python
instruction_ex = {
    "instruction": "Clasifica este ticket por urgencia y categoría.",
    "input": "Mi pedido #12345 no ha llegado.",
    "output": "Urgencia: Alta\nCategoría: Envío",
}

completion_ex = {
    "prompt": "Análisis de ticket\n\nMensaje: Mi pedido #12345 no ha llegado.\n\nUrgencia:",
    "completion": " Alta\nCategoría: Envío",
}
```

### Validar que el chat template aplica loss sólo al assistant

```python
from trl import DataCollatorForCompletionOnlyLM
from transformers import AutoTokenizer

tok = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B-Instruct")

# Para Llama 3, el response template es el header del assistant
response_template = "<|start_header_id|>assistant<|end_header_id|>\n\n"
collator = DataCollatorForCompletionOnlyLM(response_template, tokenizer=tok)

# El collator pone -100 (ignore_index) en todos los tokens
# excepto los del assistant, de modo que la cross-entropy loss
# sólo se calcule sobre la respuesta deseada.
```

## Errores comunes

- **Usar completion tuning para un chatbot.** El modelo no interpreta variaciones de la instrucción. En producción, cada reformulación del usuario rompe la respuesta.
- **Usar instruction tuning para un patrón fijo.** Añade overhead de tokens y requiere más datos; completion tuning converge más rápido.
- **Mezclar formatos dentro del mismo dataset.** Algunos ejemplos como `{instruction, input, output}` y otros como `{prompt, completion}`: el modelo no aprende un patrón consistente.
- **Olvidar el chat template correcto.** Entrenar con un template y servir con otro produce respuestas truncadas o repeticiones infinitas. Siempre usa `tokenizer.apply_chat_template()` del modelo base exacto.
- **No enmascarar los tokens de usuario en la loss.** El modelo intenta aprender a predecir las preguntas y degrada su capacidad de responder.
- **Formato de dataset incorrecto.** OpenAI requiere `messages`; Axolotl acepta `alpaca`, `sharegpt`, `chat_template`; TRL es flexible pero necesita que coincida con `dataset_text_field` o `formatting_func`.
- **Olvidar `add_generation_prompt=True` en inferencia.** Sin el prompt de generación (ej. `<|start_header_id|>assistant<|end_header_id|>\n\n`), el modelo no sabe que es su turno de responder.
- **Entrenar un modelo *Instruct* como si fuera *base*.** Sobrescribes el alineamiento previo y pierdes la capacidad de seguir instrucciones generales.

## Resumen

- **Instruction tuning** enseña a seguir instrucciones variadas → chatbots, asistentes, Q&A. Formato: `{instruction, input, output}` o `{messages: [...]}`.
- **Completion tuning** enseña a continuar un patrón fijo → templates, autocompletado, generación de estilo. Formato: `{prompt, completion}`.
- El estándar de almacenamiento es **JSONL** (una línea = un ejemplo).
- Cada familia de modelo exige su **chat template** (Alpaca, ChatML, Llama 3, Mistral, Gemma). Usa `tokenizer.apply_chat_template()`.
- En instruction tuning, la **loss debe aplicarse sólo a los tokens del assistant** (usa `DataCollatorForCompletionOnlyLM` o equivalente).
- Para el **chatbot de soporte** del submódulo, la elección correcta es **instruction tuning con formato chat**, porque maneja clasificación, generación y extracción en una sola interfaz interactiva.
- Mezclar formatos, olvidar el template o entrenar sin máscara de loss son los errores más caros y más silenciosos de todo el pipeline.
