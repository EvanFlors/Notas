# Optimización de Modelos: Cuantización, Pruning, Distilación y Hardware

## ¿Qué es?

**Optimización de modelos** es el conjunto de técnicas que reducen el tamaño, latencia o costo de inferencia de un modelo entrenado, idealmente sin degradar su calidad de forma inaceptable. Se trabaja en tres frentes:

1. **Compresión del modelo:** cuantización, pruning, distilación.
2. **Optimización del grafo de ejecución:** fusión de kernels, Flash Attention, speculative decoding.
3. **Hardware adecuado:** GPU vs TPU vs Inferentia, memoria vs cómputo.

### FLOPs y memoria: las dos restricciones

Para un transformer, el costo de un forward pass es aproximadamente:

```
FLOPs ≈ 2 · P · D       (P = número de parámetros, D = tokens procesados)
```

Para Llama-3-8B procesando 1000 tokens: `2 × 8e9 × 1000 = 1.6e13 FLOPs = 16 TFLOPs`. Una A100 entrega ~312 TFLOPs en FP16 → mínimo teórico ~50ms. En la práctica, la restricción real suele ser **memoria**, no cómputo:

```
Memoria KV-cache = 2 · L · H · d · bytes_por_valor
```

Donde `L` = capas, `H` = heads, `d` = dimensión por head, `bytes_por_valor` = 2 (FP16) ó 1 (INT8). Para Llama-3-70B con contexto de 8K tokens, el KV-cache por secuencia pesa ~2.5 GB. Esta es la razón por la que **batch size** está limitado en LLMs grandes.

## ¿Por qué importa?

Un modelo FP32 de 70B parámetros ocupa 280 GB de VRAM: no cabe en ninguna GPU individual. Cuantizado a INT4 ocupa ~35 GB y entra en una A100 de 80GB. La diferencia entre "no se puede servir" y "se sirve bien" suele ser cuantización + Flash Attention + continuous batching.

Impactos típicos de optimizaciones apiladas en producción:

| Optimización | Latencia | Memoria | Calidad |
|---|---|---|---|
| FP16 (desde FP32) | ÷2 | ÷2 | <0.5% |
| INT8 | ÷3-4 | ÷4 | 0.5-2% |
| INT4 (GPTQ/AWQ) | ÷5-6 | ÷8 | 1-3% |
| Flash Attention 2 | ÷2-4 (long ctx) | lineal vs. cuadrática | 0% |
| Speculative decoding | ÷2-3 | +25% (draft model) | 0% (verificado) |
| Distilación 70B→8B | ÷10 | ÷10 | 3-10% |

Multiplicado todo, un stack bien optimizado puede entregar **20-50× más throughput por dólar** que la configuración ingenua.

## ¿Cómo funciona?

### Cuantización

Representar pesos y/o activaciones con menos bits. En vez de FP32 (4 bytes), usar FP16 (2), INT8 (1), INT4 (0.5), e incluso INT2.

| Precisión | Rango | Bits | Memoria 70B | Speedup típico | Pérdida calidad |
|---|---|---|---|---|---|
| **FP32** | ±3.4e38 | 32 | 280 GB | 1× | baseline |
| **FP16 / BF16** | ±65504 / ±3.4e38 | 16 | 140 GB | 2× | <0.5% |
| **INT8** | ±127 | 8 | 70 GB | 3-4× | 0.5-2% |
| **INT4** (GPTQ/AWQ) | ±7 | 4 | 35 GB | 4-6× | 1-3% |
| **INT2** | ±1 | 2 | 17 GB | 6-8× | 5-15% (experimental) |

Modos:

- **Post-training quantization (PTQ):** cuantizas el modelo ya entrenado con un dataset de calibración pequeño (128-1024 muestras). Rápido, sin reentrenar.
- **Quantization-aware training (QAT):** simulas cuantización durante entrenamiento. Mejor calidad, más caro.
- **Métodos modernos:** **GPTQ**, **AWQ**, **SmoothQuant**, **bitsandbytes (NF4)**. GPTQ y AWQ son los estándares para LLMs INT4.

### Pruning

Pone a cero los pesos con menor magnitud. Dos variantes:

- **Unstructured pruning:** cero los pesos individuales → modelo sparse. Necesita hardware/kernel que explote sparsity (NVIDIA 2:4 sparsity).
- **Structured pruning:** elimina heads de attention, canales, capas enteras. Siempre speedup, menor flexibilidad.

Típicamente puedes "podar" 30-50% de los pesos manteniendo >99% de calidad; más allá degrada rápido.

### Knowledge distillation

Entrenas un modelo pequeño (**student**) para que imite las logits del modelo grande (**teacher**). El student aprende no solo la respuesta correcta sino la *distribución* del teacher, lo que transfiere más información que simplemente entrenarlo con labels duras.

Casos emblemáticos: **DistilBERT** (40% más pequeño, 60% más rápido, 97% de BERT); **TinyLlama**; familias "mini" de modelos propietarios.

### Flash Attention

El attention estándar materializa la matriz `Q·Kᵀ` de tamaño `N×N` en memoria HBM. Para `N=8192` eso son 268 MB solo para una capa. Flash Attention (Dao, 2022) *reordena* el cómputo con tiling en SRAM y recomputa en backward, logrando:

- Memoria lineal en `N` en vez de cuadrática.
- 2-4× speedup en secuencias largas.
- Precisión numéricamente idéntica.

Flash Attention 2 y 3 añaden paralelismo mejorado y soporte para FP8 en H100.

### Speculative decoding (Leviathan et al. 2023)

Un modelo **draft** pequeño y rápido (ej. 1B) genera K tokens candidatos; el modelo **target** grande los **verifica en un solo forward pass batched** y acepta un prefijo. Resultado: 2-3× menos pasos del modelo grande sin cambiar la distribución final. Variantes: Medusa, EAGLE, Lookahead decoding.

### Model cascading / routing

No todas las queries requieren el modelo más grande. Un **router** barato (modelo pequeño o clasificador) decide el modelo apropiado:

```
Query ─► Router (Haiku) ─► ¿complejidad?
                            ├─ baja  → Haiku responde (1×)
                            ├─ media → Sonnet (5×)
                            └─ alta  → Opus (15×)
```

En promedio, 60-80% de queries son triviales y se resuelven con el modelo barato, bajando el costo medio drásticamente.

### Formatos y runtimes de inferencia

| Formato / runtime | Ideal para | Speedup típico |
|---|---|---|
| **ONNX Runtime** | Portabilidad multi-hardware | 2-3× |
| **TensorRT-LLM** | NVIDIA GPUs, max perf | 5-10× |
| **vLLM** | Serving LLMs con continuous batching + PagedAttention | 3-10× |
| **TGI (HuggingFace)** | Serving LLMs OSS | 2-5× |
| **Triton Inference Server** | Multi-modelo, multi-framework | 2× |
| **DeepSpeed-Inference** | Modelos muy grandes, tensor parallel | 2-5× |
| **llama.cpp** | CPU / edge / Metal | varía |
| **Ollama** | Dev local, Mac | varía |
| **TorchScript / torch.compile** | PyTorch nativo | 1.5-2× |

Servicios gestionados: **Modal**, **Together AI**, **Groq** (LPU, hasta 500 tok/s), **Fireworks**, **Anyscale**.

## Ejemplo con código

### 4-bit quantization con bitsandbytes (NF4) + QLoRA

```python
# pip install bitsandbytes transformers accelerate
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",            # Normal Float 4 (QLoRA paper)
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,       # cuantiza tambien las constantes
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B",
    quantization_config=bnb,
    device_map="auto",
)
tok = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B")

# Memoria: ~5 GB en vez de ~16 GB (FP16) o ~32 GB (FP32)
# Calidad: <2% de perdida en MMLU en Llama-3-8B
```

### Speculative decoding con draft model

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

target = AutoModelForCausalLM.from_pretrained("meta-llama/Meta-Llama-3-70B", torch_dtype=torch.bfloat16, device_map="auto")
draft  = AutoModelForCausalLM.from_pretrained("meta-llama/Meta-Llama-3-8B",  torch_dtype=torch.bfloat16, device_map="auto")
tok    = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-70B")

inputs = tok("Explica el teorema de Bayes:", return_tensors="pt").to("cuda")

# HuggingFace soporta speculative decoding nativo via assistant_model
output = target.generate(
    **inputs,
    assistant_model=draft,
    max_new_tokens=256,
    do_sample=False,          # determinista
    num_assistant_tokens=5,   # K tokens candidatos por iteracion
)
print(tok.decode(output[0], skip_special_tokens=True))
# Throughput tipico: 2-3x mas rapido que target solo, misma distribucion
```

### Model cascade (routing por confianza)

```python
import anthropic
client = anthropic.Anthropic()

MODELS = [
    ("claude-haiku-4-5",   1.0),   # multiplicador de costo relativo
    ("claude-sonnet-4-5",  5.0),
    ("claude-opus-4-5",   15.0),
]

def ask_with_cascade(query: str, min_confidence: float = 0.85) -> str:
    """
    Pide al modelo chico. Si su auto-reporte de confianza es bajo,
    escala al siguiente nivel. Patron router+cascade.
    """
    for model, _cost in MODELS:
        resp = client.messages.create(
            model=model,
            max_tokens=1024,
            system=(
                "Responde en JSON: {\"answer\": str, \"confidence\": float 0-1}. "
                "Pon confidence baja si no estas seguro."
            ),
            messages=[{"role": "user", "content": query}],
        )
        import json
        try:
            parsed = json.loads(resp.content[0].text)
            if parsed["confidence"] >= min_confidence:
                return parsed["answer"]
        except Exception:
            continue
    return parsed["answer"]   # fallback al mas grande
```

### Flash Attention 2 habilitado

```python
from transformers import AutoModelForCausalLM

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B",
    torch_dtype="bfloat16",
    attn_implementation="flash_attention_2",   # requiere flash-attn >= 2.0 instalado
    device_map="auto",
)
# Para contextos de 8K+, el speedup es 2-4x y la memoria pasa de O(N^2) a O(N).
```

### Serving optimizado end-to-end con vLLM

| Optimización | Flag vLLM |
|---|---|
| PagedAttention | activo por defecto |
| Continuous batching | activo por defecto |
| Prefix caching | `enable_prefix_caching=True` |
| Tensor parallel | `tensor_parallel_size=N` |
| Cuantización INT4 (AWQ) | `quantization="awq"` |
| FP8 KV-cache | `kv_cache_dtype="fp8"` |
| Speculative decoding | `speculative_model=...` |

```python
from vllm import LLM, SamplingParams

llm = LLM(
    model="TheBloke/Llama-3-70B-AWQ",
    quantization="awq",                  # INT4 pesos
    kv_cache_dtype="fp8",                # KV-cache en FP8 → 2x menos VRAM
    tensor_parallel_size=2,
    enable_prefix_caching=True,
    max_num_seqs=256,
    gpu_memory_utilization=0.9,
    speculative_model="meta-llama/Meta-Llama-3-8B",
    num_speculative_tokens=5,
)
```

## Errores comunes

- **Cuantizar sin eval.** Pasas a INT4 y degradas 15% en tu benchmark de dominio pero nunca lo mediste. Siempre corre eval (MMLU, HumanEval, benchmarks propios) antes y después.
- **Elegir INT8/INT4 sin considerar el hardware.** Las GPUs pre-Ampere (T4, V100) no tienen Tensor Cores INT4; no verás speedup. H100 añade FP8 nativo.
- **Pruning sin kernel sparse.** Pones a cero 50% de los pesos pero sigues ejecutando denso: memoria ↓, latencia igual. Necesitas kernels (cuSPARSE, Sparsity 2:4).
- **Distilar sin dominio.** Un student entrenado solo con general web data pierde conocimiento específico (código, legal, médico). Incluye datos del dominio objetivo.
- **Flash Attention con tipos no soportados.** FA2 solo soporta FP16/BF16; con FP32 no sirve.
- **Speculative decoding con draft malo.** Si el acceptance rate <40%, pierdes más tiempo verificando del que ahorras. El draft debe ser ~10× más chico y de la misma familia.
- **Cascade sin logging.** No sabes qué porcentaje escala a Opus y por qué. Siempre loguea `(query, model_usado, confidence)` para iterar la lógica del router.
- **TensorRT-LLM lock-in.** Compila el modelo para una arquitectura específica (ej. H100); al desplegar en A100 no funciona. Compila por target.
- **Fundir frameworks en producción.** PyTorch + ONNX + TensorRT + vLLM en un mismo request = pesadilla de debug. Elige uno y mantenlo.

## Resumen

- Dos restricciones manda: `FLOPs = 2·P·D` (cómputo) y `KV-cache = 2·L·H·d·bytes` (memoria). La memoria suele ser el cuello en LLMs.
- **Cuantización** (FP16 → INT8 → INT4 con GPTQ/AWQ/bitsandbytes) corta memoria 2-8× con pérdida <3% si evalúas bien.
- **Pruning** 30-50% suele mantener calidad; requiere kernels sparse para dar speedup real.
- **Distilación** (DistilBERT, TinyLlama) reduce 10× tamaño reteniendo 90-97% de calidad.
- **Flash Attention 2/3** vuelve lineal la memoria del attention y acelera 2-4× en contextos largos.
- **Speculative decoding** usa un draft chico + verificación batched → 2-3× speedup sin cambiar distribución.
- **Cascading / routing** (Haiku→Sonnet→Opus) abarata costo medio: la mayoría de queries no necesitan el modelo tope.
- Runtimes: **vLLM** (PagedAttention + continuous batching) es el default actual OSS; **TensorRT-LLM** para max perf en NVIDIA; **Groq**, **Together**, **Modal** si prefieres gestionado.
- Papers de referencia: Flash Attention (Dao 2022), vLLM/PagedAttention (Kwon 2023), QLoRA (Dettmers 2023), Speculative Decoding (Leviathan 2023).
