# Validación de Salidas y Manejo de Errores

## ¿Qué es?

**Validar la salida** de un LLM es verificar — antes de confiar en ella — que cumple: (1) un **contrato sintáctico** (JSON parseable, XML bien formado), (2) un **contrato tipado** (campos del tipo correcto, enums válidos, rangos aceptables), (3) un **contrato de seguridad** (sin PII, sin contenido tóxico, sin inyección de prompts), y (4) un **contrato semántico/negocio** (los números cuadran, la respuesta responde a la pregunta, el tono es apropiado).

**Manejar errores** es decidir qué hacer cuando alguno de esos contratos se rompe: reintentar, reparar, aceptar parcial, o fallar explícitamente.

Esta es la diferencia entre un prototipo de notebook y un sistema de producción. Un LLM es un **componente estadístico**: fallará. La pregunta no es *si*, sino *cómo lo detectas y qué haces al respecto*.

## ¿Por qué importa?

Imagina un bot de soporte que, en hora pico, empieza a devolver JSON truncado por `max_tokens`. Si tu validación lo **rechaza todo**, los tickets se encolan y el soporte colapsa. Si tu validación **ingiere basura**, la base de datos termina con `null` donde debería haber prioridades, y los dashboards mienten durante semanas. En ambos extremos el negocio pierde.

Validación bien diseñada aporta:

- **Confianza para automatizar**: puedes ejecutar la salida sin revisión humana porque el contrato es verificable.
- **Degradación controlada**: fallos predecibles, no caídas sorpresivas.
- **Observabilidad**: cada capa deja métricas (`syntax_fail_rate`, `semantic_fail_rate`) que guían la mejora de prompts.
- **Cumplimiento**: GDPR, HIPAA y PCI exigen validar contenido sensible **antes** de persistirlo.
- **Ahorro**: fallar temprano con una regex es 10 000× más barato que fallar tarde con un juez LLM.

### Cuándo NO sobrecargar la validación

- **Chat casual** con humano final: ya hay un humano revisando.
- **Prototipos**: añade validación cuando mides el *failure rate*, no antes.
- **Costos prohibitivos**: validar cada token con un juez LLM dobla la factura; aplícalo solo a output *de alto riesgo*.

## ¿Cómo funciona?

Una pipeline de validación en producción se organiza en **capas** ordenadas por costo creciente y especificidad creciente. Cada capa decide: *aceptar*, *rechazar*, *reparar* o *escalar*.

### Las 4 capas

| Capa | Qué comprueba | Latencia típica | Herramientas |
|---|---|---|---|
| 1. Sintáctica | JSON parseable, XML bien formado, CSV con N columnas | <50 ms | `json`, `lxml`, `csv`, Pydantic |
| 2. Esquema/tipos | Campos presentes, tipos, enums, rangos | <100 ms | Pydantic, `jsonschema` |
| 3. Seguridad | PII, toxicidad, prompt injection, secretos | 50-500 ms | Regex, Presidio, detoxify, Llama Guard |
| 4. Semántica / negocio | Coherencia lógica, reglas de dominio, calidad | 500-3000 ms | Reglas Python, **AI judges** |

### Patrones de recuperación

- **Immediate recovery**: parsing tolerante, extracción con regex del primer `{...}` balanceado si el modelo añadió prosa, cierre de llaves faltantes por `max_tokens`.
- **Progressive retry**: reintentar con **backoff exponencial** y, crucialmente, **inyectar el error como feedback** en el siguiente turno.
- **Graceful degradation**: aceptar la parte válida de un JSON parcial, rellenar faltantes con defaults, bajar la confianza reportada.
- **Fallback a modelo distinto**: si GPT-4o-mini falla 3 veces, escala a GPT-4o. Más caro, más fiable.
- **Human-in-the-loop**: outputs marcados como `low_confidence` o que fallan la capa 4 van a una cola de revisión.

### Patrones de fallo comunes del LLM

| Patrón | Síntoma | Capa que lo detecta |
|---|---|---|
| Truncamiento | JSON a medias, `finish_reason="length"` | 1 |
| Comillas sin escapar | `"description": "él dijo "hola""` | 1 |
| Campo renombrado | `customer_name` en vez de `name` | 2 |
| Tipo incorrecto | `"rating": "5"` en vez de `5` | 2 |
| Formato de fecha libre | `"next Tuesday"` en vez de ISO | 2 o 4 |
| PII filtrada | Correo real en campo público | 3 |
| Prompt injection reflejada | El modelo repite "ignore previous instructions..." | 3 |
| Mentira plausible | Datos correctamente tipados pero inventados | 4 (juez / RAG check) |
| Sentimiento inconsistente | `rating=5` y `sentiment="negative"` | 4 |

### AI judges (validación con LLM)

Cuando la validez depende de **juicio** (¿este resumen es fiel al original? ¿la respuesta es cortés?), nada de regex alcanza. La solución: una **segunda llamada** a un LLM con rúbrica explícita.

Buenas prácticas:
- **Rúbrica concreta**: criterios discretos (`relevance: 1-5`, `tone: {professional|casual|rude}`), no "¿es bueno?".
- **Few-shot con ejemplos de cada clase**.
- **Modelo distinto o más grande** que el que generó: GPT-4o juzgando a GPT-4o-mini.
- **Jurado**: 3 jueces + voto mayoritario para decisiones críticas; desacuerdo → humano.
- **Aplicar selectivamente**: solo al 5-10 % de outputs que capas previas marcaron de riesgo.

## Ejemplo con código

### 1. Pipeline multi-capa

```python
import json, re, time
from typing import Any
from pydantic import BaseModel, ValidationError, Field
from typing import Literal, Optional

class Ticket(BaseModel):
    name: str
    priority: Literal["low", "medium", "high"]
    sentiment: float = Field(ge=-1, le=1)
    email: Optional[str] = None

class ValidationResult(BaseModel):
    ok: bool
    stage: str
    data: Optional[Ticket] = None
    error: Optional[str] = None
    confidence: float = 1.0

# --- Capa 1: sintaxis ---
def validate_syntax(raw: str) -> tuple[bool, Any]:
    try:
        return True, json.loads(raw)
    except json.JSONDecodeError as e:
        # Intento de reparación: extraer el primer objeto balanceado
        m = re.search(r"\{.*\}", raw, re.DOTALL)
        if m:
            try:
                return True, json.loads(m.group(0))
            except json.JSONDecodeError:
                pass
        return False, str(e)

# --- Capa 2: schema ---
def validate_schema(obj: Any) -> tuple[bool, Any]:
    try:
        return True, Ticket.model_validate(obj)
    except ValidationError as e:
        return False, e.errors()

# --- Capa 3: seguridad (PII) ---
PII_PATTERNS = {
    "ssn":   re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
    "card":  re.compile(r"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"),
    "email": re.compile(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b"),
}

def validate_safety(ticket: Ticket) -> tuple[bool, str]:
    blob = ticket.model_dump_json()
    for name, pat in PII_PATTERNS.items():
        if name == "email":   # el email del cliente SÍ puede ir en su campo
            continue
        if pat.search(blob):
            return False, f"PII detectada: {name}"
    return True, "ok"

# --- Capa 4: semántica (reglas de negocio) ---
def validate_semantics(ticket: Ticket) -> tuple[bool, str]:
    # Coherencia prioridad ↔ sentimiento
    if ticket.priority == "high" and ticket.sentiment > 0.5:
        return False, "high priority con sentimiento positivo es sospechoso"
    return True, "ok"

def run_pipeline(raw: str) -> ValidationResult:
    ok, out = validate_syntax(raw)
    if not ok: return ValidationResult(ok=False, stage="syntax", error=out)

    ok, ticket = validate_schema(out)
    if not ok: return ValidationResult(ok=False, stage="schema", error=str(ticket))

    ok, msg = validate_safety(ticket)
    if not ok: return ValidationResult(ok=False, stage="safety", error=msg)

    ok, msg = validate_semantics(ticket)
    if not ok:
        return ValidationResult(ok=False, stage="semantic", error=msg,
                                data=ticket, confidence=0.4)

    return ValidationResult(ok=True, stage="passed", data=ticket)
```

### 2. Retry progresivo con feedback

```python
from openai import OpenAI

client = OpenAI()

def extract_with_retry(prompt: str, max_attempts: int = 3) -> Ticket:
    messages = [{"role": "user", "content": prompt}]
    for attempt in range(max_attempts):
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            response_format={"type": "json_object"},
        )
        raw = resp.choices[0].message.content
        result = run_pipeline(raw)

        if result.ok:
            return result.data

        # Alimenta al modelo con su propio error
        messages.append({"role": "assistant", "content": raw})
        messages.append({
            "role": "user",
            "content": (f"Error en la etapa `{result.stage}`: {result.error}. "
                        f"Corrige y responde SOLO JSON válido.")
        })
        time.sleep(2 ** attempt)  # backoff exponencial

    raise RuntimeError(f"Falló tras {max_attempts} intentos: {result.error}")
```

### 3. Manejo de truncamiento

```python
def call_with_truncation_check(prompt: str, max_tokens: int = 2048):
    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        response_format={"type": "json_object"},
    )
    choice = resp.choices[0]

    if choice.finish_reason == "length":
        # El JSON probablemente está truncado; intenta cerrar llaves
        raw = choice.message.content
        open_braces = raw.count("{") - raw.count("}")
        open_brackets = raw.count("[") - raw.count("]")
        repaired = raw + ("]" * open_brackets) + ("}" * open_braces)
        try:
            return json.loads(repaired), {"truncated": True, "repaired": True}
        except json.JSONDecodeError:
            return None, {"truncated": True, "repaired": False}

    return json.loads(choice.message.content), {"truncated": False}
```

### 4. AI judge con rúbrica

```python
JUDGE_PROMPT = """Eres un evaluador. Da un veredicto en JSON.

RÚBRICA:
- relevance: 1 (irrelevante) a 5 (totalmente relevante al ticket)
- tone: "professional" | "casual" | "rude"
- hallucination: true si inventa datos que no están en el ticket

Ticket original:
{ticket}

Respuesta del agente:
{answer}

Devuelve: {{"relevance": int, "tone": str, "hallucination": bool, "reason": str}}
"""

class Verdict(BaseModel):
    relevance: int = Field(ge=1, le=5)
    tone: Literal["professional", "casual", "rude"]
    hallucination: bool
    reason: str

def ai_judge(ticket: str, answer: str) -> Verdict:
    resp = client.chat.completions.create(
        model="gpt-4o",   # juez más fuerte que el generador
        messages=[{"role": "user", "content": JUDGE_PROMPT.format(
            ticket=ticket, answer=answer)}],
        response_format={"type": "json_object"},
    )
    return Verdict.model_validate_json(resp.choices[0].message.content)

def should_escalate(verdict: Verdict) -> bool:
    return verdict.hallucination or verdict.relevance < 3 or verdict.tone == "rude"
```

### 5. Métricas y logging

```python
from dataclasses import dataclass, field
from collections import Counter

@dataclass
class ValidationMetrics:
    total: int = 0
    by_stage: Counter = field(default_factory=Counter)
    latencies_ms: list = field(default_factory=list)

    def record(self, result: ValidationResult, latency_ms: float):
        self.total += 1
        self.by_stage[result.stage] += 1
        self.latencies_ms.append(latency_ms)

    def report(self):
        fails = sum(v for k, v in self.by_stage.items() if k != "passed")
        return {
            "pass_rate": self.by_stage["passed"] / max(self.total, 1),
            "fail_rate": fails / max(self.total, 1),
            "fail_by_stage": dict(self.by_stage),
            "p95_latency_ms": sorted(self.latencies_ms)[int(len(self.latencies_ms)*0.95)-1],
        }
```

### 6. Degradación elegante

```python
def extract_or_default(raw: str) -> dict:
    """Devuelve siempre un dict usable, con confidence reflejando el estado."""
    ok, out = validate_syntax(raw)
    if not ok:
        return {"name": None, "priority": "medium", "sentiment": 0.0,
                "_meta": {"confidence": 0.0, "error": "unparseable"}}

    try:
        ticket = Ticket.model_validate(out)
        return {**ticket.model_dump(), "_meta": {"confidence": 1.0}}
    except ValidationError as e:
        # Rellena campos válidos, defaults para faltantes
        safe = {"name": out.get("name"),
                "priority": out.get("priority") if out.get("priority") in ("low","medium","high") else "medium",
                "sentiment": float(out.get("sentiment", 0.0)) if isinstance(out.get("sentiment"), (int,float)) else 0.0}
        return {**safe, "_meta": {"confidence": 0.5, "error": str(e)}}
```

## Errores comunes

- **Validación como afterthought**. Diseñarla al final te obliga a reescribir prompts, schemas y consumidores. Métela desde el día 1.
- **Un `try/except` monstruo**. Mezcla sintaxis, tipos, PII y lógica. Imposible medir qué capa falla ni mejorar prompts.
- **Validar todo con un juez LLM**. Caro y lento. Reserva al 5-10 % de outputs de alto riesgo.
- **Latencia de validación > latencia del modelo**. Si validar tarda más que generar, perdiste el beneficio. Perfila y optimiza.
- **Reintentos sin feedback**. Reintentar con exactamente el mismo prompt rara vez funciona; inyecta el error como mensaje nuevo.
- **Reintentos infinitos**. Define `max_attempts` y una política de escalamiento (modelo mayor, humano, default).
- **No distinguir `finish_reason="length"` de otros fallos**. Un JSON truncado se repara; uno malformado por confusión del modelo no.
- **Rechazar PII en campos donde SÍ es necesaria**. El correo del cliente es PII pero es el dato que buscas. Haz la lista de PII permitida por campo.
- **Jueces LLM con rúbrica vaga**. "¿Es buena esta respuesta?" produce ruido. Usa dimensiones discretas con escala.
- **No loggear fallos**. Sin métricas de `fail_rate_by_stage`, no sabes dónde invertir. Logea el raw, el stage, el error y el prompt usado.
- **Olvidar prompt injection**. Si el input viene de un usuario, puede intentar reprogramar al modelo. Detecta patrones (`ignore previous instructions`, `system:`) y escanea el output por filtraciones del system prompt.
- **Confiar en defaults silenciosos**. Rellenar con `priority="medium"` y no reportarlo oculta un fallo real que crece. Siempre marca `confidence < 1.0` cuando degradas.
- **Validar en el servidor del consumidor**. Para cuando el error llega allí, está lejos del origen. Valida en el borde, inmediatamente después de la llamada al modelo.

## Resumen

- La validación es la **puerta entre el prototipo y la producción**: convierte un componente estadístico en uno confiable.
- Organízala en **4 capas**: sintaxis → schema → seguridad → semántica/negocio, de barata a cara.
- **Pydantic** cubre las capas 1 y 2 con un solo `model_validate_json`.
- Para capa 3 usa **regex + librerías de PII** (Presidio) y filtros de prompt injection.
- Para capa 4, **AI judges** con rúbrica concreta y modelo más fuerte que el generador; aplícalos **selectivamente**.
- **Retry progresivo** con backoff y, sobre todo, **inyectando el error como feedback** al modelo.
- **Degradación elegante** con `confidence` explícita; nunca rellenes defaults en silencio.
- Detecta y maneja **truncamiento** (`finish_reason="length"`) con reparación de llaves y, si no, nuevo intento con `max_tokens` mayor.
- **Mide todo**: `pass_rate`, `fail_by_stage`, `p95_latency`. Sin métricas no hay mejora.
- Diseña la validación **al principio del proyecto**, no al final; cada semana que esperas, el refactor cuesta el doble.
- Un sistema de validación bien hecho **no evita todos los errores**: los hace **predecibles, observables y recuperables**.
