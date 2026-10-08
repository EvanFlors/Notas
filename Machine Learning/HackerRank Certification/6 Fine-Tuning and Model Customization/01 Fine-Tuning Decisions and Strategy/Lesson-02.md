# Open-Source vs Hosted Models

## ¿Qué es?

La **elección de modelo base** es la decisión más consecuente antes de fine-tunear: define tu techo de calidad, tu factura mensual, tu postura de cumplimiento y el nivel de control que tendrás sobre el sistema. El universo se divide en dos grandes familias:

- **Modelos open-source autogestionados (self-hosted):** descargas los pesos (Llama, Mistral, Qwen, Gemma, Falcon, Phi) y los corres en tu propia GPU o en una nube IaaS. Control total sobre arquitectura, cuantización, deployment y datos.
- **Modelos hospedados (APIs gestionadas):** consumes a GPT, Claude, Gemini vía API. Infra administrada, cero fricción operativa, pero per-token pricing y customización limitada.

Entre ambos extremos existe un **continuo de control**:

```
Prompt-only API  →  Fine-tuning gestionado  →  PEFT self-hosted  →  Full FT self-hosted
   mínimo control                                                      control total
   cero infra                                                           tú manejas todo
```

### Panorama open-source (2024-2025)

| Familia | Variantes populares | Licencia | Fortaleza |
|---|---|---|---|
| **Llama** (Meta) | 3-8B, 3-70B, 3.1, 3.2, 4 (Scout/Maverick) | Llama Community (restrictiva para gigantes) | Ecosistema más maduro para fine-tuning |
| **Mistral** | 7B, 8x7B (Mixtral), Nemo | Apache 2.0 | Eficiencia, licencia permisiva |
| **Qwen** (Alibaba) | Qwen3 (densos y MoE), hasta 128K ctx | Apache 2.0 (varía por tamaño) | Multilingüe, razonamiento |
| **Gemma** (Google) | 2B, 7B, 27B | Gemma License | Compacto, arquitectura Google |
| **Phi** (Microsoft) | Phi-3, Phi-4 | MIT | Pequeños y potentes |
| **Falcon** (TII) | 7B, 40B, 180B | Apache 2.0 | Licencia 100% abierta |

### Panorama hospedado

- **OpenAI:** GPT-4o, GPT-4o-mini, GPT-5 series. Fine-tuning API disponible para GPT-4.1, GPT-4o-mini (no para GPT-5 full).
- **Anthropic:** Claude Sonnet 4, Opus 4, Haiku. Fine-tuning accesible vía AWS Bedrock para algunos modelos.
- **Google:** Gemini 1.5/2.5/3 Pro y Flash. Fine-tuning gestionado en Vertex AI.

## ¿Por qué importa?

La decisión impacta **cuatro variables** simultáneamente:

1. **Costo total.** APIs son lineales con el volumen; self-hosted tiene costo fijo. El punto de cruce suele caer entre 50K y 100K requests/mes.
2. **Soberanía y cumplimiento.** GDPR, HIPAA, residencia de datos en LATAM/UE pueden *obligarte* a self-hosting.
3. **Techo de capacidad.** GPT-4o y Claude Opus siguen superando a los open-source en razonamiento complejo; un 7B self-hosted no es un reemplazo directo.
4. **Agilidad operativa.** Con API en 10 minutos tienes un prototipo; con self-hosted dedicas 1-2 ingenieros a infra.

Equivocarse en esta decisión implica migrar modelos a mitad del proyecto, lo que significa **re-entrenar, re-evaluar y re-desplegar** — típicamente 2-4 semanas y entre $5K y $50K en costos de ingeniería.

## ¿Cómo funciona?

### El espectro de control, en detalle

| Dimensión | Prompt-only API | Fine-tuning gestionado | PEFT self-hosted | Full FT self-hosted |
|---|---|---|---|---|
| **Quién maneja GPUs** | Proveedor | Proveedor | Tú | Tú |
| **Hiperparámetros expuestos** | Ninguno (temperature, top_p) | Limitados (epochs, lr) | Todos | Todos |
| **Modificar arquitectura** | No | No | No (adapters) | Sí |
| **Cuantización** | No controlas | No | Sí (QLoRA 4-bit) | Sí |
| **Costo fijo mensual** | $0 | Medio | $500-800 (A10G) | $3K-10K (A100/H100) |
| **Costo por request** | Alto ($0.0002-0.002) | Alto + sobrecargo | ~$0 | ~$0 |
| **Residencia de datos** | Donde esté el proveedor | Donde esté el proveedor | Donde tú elijas | Donde tú elijas |
| **Switch de modelo** | 1 línea de código | API change | Cambiar pesos | Re-entrenar todo |

### Fórmula de break-even

```
costo_api_mes = (tokens_in·precio_in + tokens_out·precio_out) · requests_mes
costo_self_hosted_mes = gpu_mensual + (costo_entrenamiento / meses_amortizacion)

break_even_requests = (gpu_mensual - costo_training_mensual) / costo_por_request_api
```

Con un A10G ($600/mes) y GPT-4o-mini ($0.00016/req) el cruce queda muy arriba (~3.75M requests). Contra GPT-4o ($0.00145/req), el cruce baja a ~414K/mes. Contra GPT-4 clásico ($0.027/req) el cruce aparece ya en ~22K/mes.

### Precios de GPUs (nubes públicas, octubre 2025, orden de magnitud)

| GPU | VRAM | USD/hora (bajo demanda) | USD/mes 24/7 | Modelo que corre full-precision |
|---|---|---|---|---|
| A10G | 24 GB | $0.8-1.2 | $600-900 | 7B |
| L4 | 24 GB | $0.6-1.0 | $450-750 | 7B |
| A100 40 GB | 40 GB | $2-3 | $1,500-2,200 | 13B |
| A100 80 GB | 80 GB | $3-5 | $2,200-3,700 | 30B / 70B 4-bit |
| H100 80 GB | 80 GB | $6-10 | $4,500-7,500 | 70B / entrenamiento |

(Precios indicativos: AWS, Lambda Labs, RunPod, Together AI, Modal varían.)

### Impacto de la cuantización

| Precisión | Bits | Memoria para 70B | Pérdida de calidad típica |
|---|---|---|---|
| FP32 | 32 | 280 GB | 0% (referencia) |
| FP16 / BF16 | 16 | 140 GB | <0.1% |
| INT8 | 8 | 70 GB | 0.5-1% |
| **NF4 (QLoRA)** | 4 | **40 GB** | 1-3% (aceptable casi siempre) |

QLoRA (Dettmers et al. 2023) hizo posible fine-tunear Llama-65B en una sola A100 de 48 GB.

### Decision tree para elegir modelo base

```
¿Datos sensibles / regulados (salud, finanzas, PII UE)?
  SÍ → self-hosted en región compatible
  NO ↓
¿Volumen > 100K requests/mes esperado?
  SÍ → self-hosted amortiza
  NO ↓
¿Necesitas calidad GPT-4+ (razonamiento complejo)?
  SÍ → API hospedada (quizá con fine-tuning gestionado)
  NO ↓
¿Equipo con experiencia en MLOps/GPUs?
  NO → API hospedada
  SÍ → self-hosted 7B/13B con PEFT es el sweet spot
```

### Tamaño del modelo vs tarea

| Tamaño | VRAM mínima (BF16) | Buenas tareas | Cuándo escalar |
|---|---|---|---|
| **7-8B** | 16 GB | Clasificación, extracción, RAG, generación simple, SQL | Si evaluación plateau en razonamiento multi-paso |
| **13-14B** | 32 GB | Instrucciones complejas, análisis matizado | Si necesitas conocimiento más amplio |
| **30-34B** | 70 GB | Razonamiento, code, dominios técnicos | Rara vez vale el salto; prefiere mejor data |
| **70B+** | 140 GB (4-bit: 40 GB) | Agentes complejos, código avanzado | Solo si validaste que smaller models no bastan |

## Ejemplo con código

### 1. Estimador de costo total (self-hosted vs varias APIs)

```python
# ============================================================
# Costo mensual: open-source self-hosted vs APIs hospedadas
# ============================================================
from dataclasses import dataclass

@dataclass
class API:
    nombre: str
    usd_1m_in: float    # USD por 1M tokens input
    usd_1m_out: float

@dataclass
class SelfHosted:
    nombre: str
    gpu_usd_hora: float
    horas_mes: float = 24 * 30   # siempre encendida
    overhead: float = 1.0        # 1.0 = sin redundancia; 2.5 = HA real
    def mensual(self) -> float:
        return self.gpu_usd_hora * self.horas_mes * self.overhead

def costo_api_mes(api: API, reqs: int, tok_in=500, tok_out=200) -> float:
    por_req = (tok_in * api.usd_1m_in + tok_out * api.usd_1m_out) / 1_000_000
    return por_req * reqs

# Catálogo (precios de referencia, verifica siempre)
apis = [
    API("GPT-4o-mini", 0.15, 0.60),
    API("GPT-4o",      2.50, 10.00),
    API("Claude Sonnet 4", 3.00, 15.00),
    API("Gemini 1.5 Flash", 0.075, 0.30),
]
sh = SelfHosted("Llama-3-8B + LoRA en A10G", gpu_usd_hora=0.80, overhead=2.0)

volumenes = [10_000, 100_000, 500_000, 2_000_000]
print(f"{'Volumen':>10} | " + " | ".join(f"{a.nombre:<18}" for a in apis) + f" | {sh.nombre}")
for v in volumenes:
    fila = [f"${costo_api_mes(a, v):>7,.0f}" for a in apis]
    fila.append(f"${sh.mensual():>7,.0f}")
    print(f"{v:>10,} | " + " | ".join(f"{c:<18}" for c in fila))
```

**Interpretación:** a volúmenes bajos, Gemini Flash o GPT-4o-mini aplastan en costo. A partir de ~500K req/mes y modelos premium, self-hosted empieza a ganar incluso con overhead 2x.

### 2. Elegir modelo base con reglas explícitas

```python
# ============================================================
# Selector automático de modelo base
# ============================================================
from enum import Enum

class Industria(Enum):
    GENERAL = "general"
    SALUD   = "salud"       # HIPAA
    FINANZAS = "finanzas"   # PCI-DSS, SOX
    GOBIERNO = "gobierno"

def recomendar_modelo(volumen_mes: int,
                      industria: Industria,
                      datos_en_ue: bool,
                      MAU_empresa: int,
                      necesita_razonamiento_complejo: bool,
                      presupuesto_mensual_usd: int) -> str:

    if industria in {Industria.SALUD, Industria.GOBIERNO} or datos_en_ue:
        base = "Mistral-7B (Apache 2.0) self-hosted en región compatible"
        if MAU_empresa > 700_000_000:
            base += "  # Llama queda descartado por licencia"
        return base

    if necesita_razonamiento_complejo and volumen_mes < 50_000:
        return "Claude Sonnet 4 o GPT-4o vía API (sin fine-tuning por ahora)"

    if volumen_mes > 500_000 and presupuesto_mensual_usd >= 1500:
        if MAU_empresa > 700_000_000:
            return "Mistral-7B / Mixtral-8x7B self-hosted + LoRA"
        return "Llama-3-8B self-hosted + LoRA (QLoRA 4-bit)"

    return "GPT-4o-mini vía API con prompt + few-shot; re-evalúa en 3 meses"

print(recomendar_modelo(
    volumen_mes=800_000,
    industria=Industria.GENERAL,
    datos_en_ue=False,
    MAU_empresa=50_000_000,
    necesita_razonamiento_complejo=False,
    presupuesto_mensual_usd=2000,
))
```

### 3. Cargar un modelo cuantizado 4-bit (QLoRA ready)

```python
# ============================================================
# Mistral-7B en 4-bit: entra en 16 GB de VRAM
# ============================================================
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",            # Normal Float 4 (QLoRA)
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,       # ahorra ~0.4 bit/param extra
)

model_id = "mistralai/Mistral-7B-Instruct-v0.3"
tok = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb,
    device_map="auto",
)
print(f"VRAM usada: {torch.cuda.memory_allocated()/1e9:.2f} GB")
# Resultado típico: ~5-6 GB en vez de ~14 GB en BF16
```

## Errores comunes

- **Defaultear a OpenAI "por simplicidad" sin calcular volumen.** Un servicio con 1M req/mes puede estar quemando $2K/mes evitables.
- **Elegir Llama sin leer la licencia.** Si tu empresa supera 700M MAU necesitas acuerdo comercial con Meta; migrar después cuesta mucho más.
- **Pedir una H100 cuando una A10G alcanza.** 7B en 4-bit corre fluido en GPU de $600/mes; no uses $7K/mes porque "parece más serio".
- **Olvidar overhead de infra.** El precio *list* de la GPU no incluye load balancer, autoscaling, monitoreo, redundancia. Multiplica por 2-3x.
- **Suponer que precios de API son estáticos.** Cambian cada 3-6 meses; construye tu stack con capacidad de intercambiar proveedor.
- **No considerar latencia regional.** Un modelo gestionado en US-East desde Buenos Aires suma 150-200 ms por request.
- **Suponer que open-source siempre iguala a frontier.** Un Mistral-7B afinado le gana a GPT-4 en tareas acotadas, pero *no* en razonamiento complejo general.
- **Ignorar el ciclo de vida.** APIs deprecan modelos (GPT-3.5 Turbo). Si fine-tuneaste sobre un snapshot deprecado, re-entrenas forzado.

### Herramientas por categoría

- **Entrenamiento gestionado:** OpenAI fine-tuning, Vertex AI Tuning, AWS Bedrock Custom Models, Azure OpenAI fine-tuning.
- **GPUs on-demand:** Modal, RunPod, Lambda Labs, Together AI, Replicate, Vast.ai, CoreWeave.
- **Serving optimizado:** vLLM, TGI (HuggingFace), SGLang, TensorRT-LLM, Ollama (dev local).
- **Cuantización:** bitsandbytes, AutoGPTQ, AutoAWQ, llama.cpp (GGUF).
- **Observabilidad LLM:** Langfuse, LangSmith, Arize Phoenix, Weights & Biases Weave.

## Resumen

- La elección open-source vs hospedado define costo, control, cumplimiento y techo de capacidad **al mismo tiempo**.
- **APIs** ganan en volúmenes bajos-medios (<50-100K req/mes) y en tareas que exigen frontier models.
- **Self-hosted** gana con volumen alto, requisitos de soberanía de datos o necesidad de deep customization.
- El **break-even** entre A10G self-hosted y GPT-4o-mini está muy arriba (~1-4M req/mes); contra GPT-4 clásico, muy abajo (~20-50K).
- **Llama** domina ecosistema pero su licencia bloquea a empresas de 700M+ MAU; **Mistral** (Apache 2.0) es el refugio seguro.
- **Tamaño:** empieza en 7B. Escala a 13B solo si evaluación lo exige; a 70B solo si todo lo demás falló.
- **Cuantización 4-bit (QLoRA)** reduce memoria ~4x con pérdida de 1-3%: hace accesibles modelos grandes en GPUs modestas.
- Precios de API cambian con frecuencia: diseña tu stack para poder cambiar proveedor sin re-escribir todo.
- Modelos **hospedados** son perfectos para prototipar y validar; migra a self-hosted cuando el producto y el volumen justifiquen la infra.
- No elijas un modelo por benchmark público: elige por **tu eval set** con **tus datos reales**.
