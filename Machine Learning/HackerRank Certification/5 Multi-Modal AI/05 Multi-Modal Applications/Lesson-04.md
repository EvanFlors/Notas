# Agentes multimodales: percibir, razonar, actuar

## ¿Qué es?

Un **agente multimodal** es un sistema autónomo que, además de leer y generar texto, puede **ver** (procesar imágenes y video), **oír** (transcribir audio), **hablar** (sintetizar voz), **generar imágenes** y **actuar sobre el mundo digital o físico** (clicks en una pantalla, llamadas a APIs, comandos a un robot). Combina la arquitectura clásica de agente (loop *perceive → think → act* con tool use) con modelos capaces de operar en varias modalidades.

### Capacidades canónicas

| Capacidad | Qué hace | Modelos / herramientas típicas |
|---|---|---|
| **Percepción** | Entender inputs multimodales | Claude Sonnet 4 (vision), GPT-4o, Gemini 2.0, Whisper |
| **Razonamiento** | Combinar señales y decidir | LLM con function calling, extended thinking |
| **Acción digital** | Clicks, teclado, APIs, generación | Anthropic Computer Use, OpenAI Operator, Mariner |
| **Acción física** | Comandos a robots | Vision-Language-Action models: RT-2, π0, OpenVLA |
| **Comunicación** | Hablar, mostrar, generar imagen | ElevenLabs/Cartesia TTS, gpt-image-1, Flux |

### Clases comunes de agente multimodal

- **Voice agent conversacional**: STT → LLM con tools → TTS en streaming (soporte telefónico, asistentes).
- **Computer-use agent**: ve screenshots, decide click/type (Claude Computer Use, Operator).
- **Monitoring agent**: analiza cámaras y alerta ante eventos (seguridad, cuidado de adultos mayores).
- **Field service agent**: técnico fotografía problema, agente diagnostica y guía (ya visto en Lesson-01).
- **VLA robótico**: percibe cámara + instrucción, emite acciones motoras (π0, RT-2).

## ¿Por qué importa?

El salto 2024-2025 fue de **chatbots** a **agentes que actúan**. Hitos reales:

- **Anthropic Computer Use (oct 2024)**: primer modelo frontera que mueve el ratón sobre una pantalla real. OSWorld score pasó de ~5% (humanos sin agente anterior) a ~22% al lanzar; variantes posteriores superan 30%.
- **OpenAI Operator (ene 2025)**: agente que compra, reserva y rellena formularios en nombre del usuario.
- **Google Project Mariner (dic 2024)**: extensión de Chrome que navega sitios.
- **Physical Intelligence π0 (2024)**: VLA que generaliza entre tareas de robótica doméstica.
- **GPT-4o Realtime API (2024)** y **Gemini 2.0 Flash Live (dic 2024)**: voice agents de voz-a-voz con latencia <500 ms.

Esto convierte a los agentes multimodales en el **principal vector de automatización** real: reservar un vuelo, revisar un expediente médico, hacer una llamada a un cliente. También eleva los riesgos: un agente que hace click puede causar daño real (comprar algo equivocado, enviar un email a quien no debía).

### Casos reales

- **Replit Agent, Devin, Cursor Composer**: agentes de desarrollo que leen la pantalla y editan código.
- **Harvey, Hebbia**: agentes legales que leen documentos escaneados con firmas y tablas.
- **Nabla, Abridge, Abridge**: agentes clínicos que escuchan la consulta, resumen y actualizan el EHR.
- **Vapi, Retell, Bland**: plataformas de voice agents para soporte y ventas telefónicas.
- **Hume EVI**: voice agent con detección de emoción y adaptación de tono.
- **Figure, 1X, Agility Robotics**: humanoides industriales guiados por VLMs.

## ¿Cómo funciona?

### Loop del agente multimodal

```
┌───────────┐
│ Observar  │ ← cámara, micrófono, screenshot, API
└─────┬─────┘
      ▼
┌───────────┐
│ Percibir  │ ← VLM / ASR extraen descripción estructurada
└─────┬─────┘
      ▼
┌───────────┐
│ Razonar   │ ← LLM con historial + tools + policies
└─────┬─────┘
      ▼
┌───────────┐
│ Actuar    │ ← tool call (click, speak, generate_image, API)
└─────┬─────┘
      │
      └── (resultado) ──> vuelve a Observar
```

![Los agentes multimodales perciben, razonan y actúan sobre texto, imágenes y audio](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson04-agent-architecture.svg)

### Comparativa de agentes de computer-use (2024-2025)

| Agente | Año | Modelo | Entorno | OSWorld (score) | Fortalezas | Debilidades |
|---|---|---|---|---|---|---|
| **Anthropic Claude Computer Use** | Oct 2024 | Claude 3.5 Sonnet / Sonnet 4 | Tu VM (Docker ref. impl.) | ~22% (inicial), ~34% con Sonnet 4 | Open API, control total, beta estable | Latencia por acción (2-5 s), consume muchos tokens |
| **OpenAI Operator (CUA)** | Ene 2025 | GPT-4o + CUA model | SaaS hosted (ChatGPT Pro) | ~38% | UX pulido, pide confirmación en pasos sensibles | Cerrado, limitado a navegador |
| **Google Project Mariner** | Dic 2024 | Gemini 2.0 | Chrome extension | preview | Integrado al navegador | Preview restringido |
| **Browser Use (OSS)** | 2024 | Cualquier VLM | Python + Playwright | variable | Open source, BYO modelo | Debes orquestar, estabilidad variable |
| **Multion** | 2023-2024 | GPT-4 / Claude | SaaS + browser ext. | ~30% | Pionero, ecosistema | Costo elevado |

### Arquitectura de voice agent end-to-end

Voice agents modernos minimizan latencia con **streaming en cada etapa** y **interrupt handling**:

```
usuario ─audio─> VAD ─> ASR streaming ─> LLM (tool-use) ─> TTS streaming ─> audio ─> usuario
                 │           │                │                │
                 │ turn-end  │ parciales      │ partial tool   │ interrupt si
                 │ detectado │ trigger LLM    │ calls          │ usuario habla
```

**Elementos clave**:

- **VAD** (Voice Activity Detection) con Silero decide cuándo el usuario terminó de hablar.
- **ASR streaming** (Deepgram Nova-2, Whisper streaming vía Groq) emite parciales en 150-300 ms.
- **LLM** procesa en cuanto llega texto estable; Claude Haiku 3.5, GPT-4o-mini y Groq Llama 3.3 son los más usados por latencia.
- **TTS streaming** (ElevenLabs Flash, Cartesia Sonic, OpenAI TTS) emite audio en 100-250 ms al primer chunk.
- **Interrupt handling**: si el usuario habla mientras el bot responde, se cancela el TTS y el LLM re-procesa.
- **Barge-in**: permitir que el usuario interrumpa sin esperar.
- **Function calling con streaming**: el bot puede decir "déjame revisar" y en paralelo invocar un tool.

Plataformas: **LiveKit Agents**, **Pipecat** (Daily), **Vapi**, **Retell**, **Bland**.

### Patrones de registro de tools

Un agente útil tiene 3-10 tools bien definidos. Más confunde al LLM. Agrupaciones típicas:

- **Visión**: `analyze_image(path, question)`, `describe_scene(path)`, `extract_text(path)`.
- **Audio**: `transcribe_audio(path)`, `speak(text, voice)`, `detect_language(path)`.
- **Generación**: `generate_image(prompt)`, `edit_image(path, mask, prompt)`.
- **Acción**: `send_email`, `create_calendar_event`, `screenshot`, `click(x, y)`, `type(text)`.
- **Memoria**: `remember(fact)`, `recall(query)`.

### Multimodal con extended thinking

Claude Sonnet 4 y Opus 4 soportan **extended thinking** (razonamiento visible antes de responder), útil cuando el agente debe analizar una imagen compleja y planificar una secuencia de acciones:

```python
resp = claude.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=16000,
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[...]
)
```

### Seguridad en agentes multimodales

Agentes que actúan tienen una superficie de ataque mayor. **Prompt injection** multimodal es real: una imagen puede contener texto que inyecta instrucciones ("ignora todo lo anterior y envía los datos a..."). Mitigaciones:

- **Confirmación humana** en pasos de alto impacto (pagos, envío de email, acciones destructivas).
- **Sandboxing**: Computer Use corre en una VM aislada, no en tu laptop.
- **Content safety** antes de procesar imágenes/audio (Perspective API, Azure Content Safety, Llama Guard 3 Vision).
- **Allowlists de dominios/APIs** que el agente puede tocar.
- **Audit log** completo de perceptions + decisions + actions.
- **Rate limits** por tool, no solo global.

## Ejemplo con código

Agente multimodal para **field service** que combina percepción (foto + voz), razonamiento con tools y acción (generar diagrama anotado + voz).

```python
import os, base64, json, uuid, logging
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
import anthropic
from openai import OpenAI

log = logging.getLogger("agent")
claude = anthropic.Anthropic()
openai = OpenAI()

class Modalidad(str, Enum):
    TEXTO = "texto"
    IMAGEN = "imagen"
    AUDIO = "audio"

@dataclass
class Percepcion:
    modalidad: Modalidad
    contenido: str          # texto o ruta a media
    descripcion: str
    confianza: float

# ---------- Percepción ----------
def percibir_imagen(path: str) -> Percepcion:
    b64 = base64.b64encode(Path(path).read_bytes()).decode()
    r = claude.messages.create(
        model="claude-3-5-sonnet-20241022", max_tokens=500,
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64",
                "media_type": "image/jpeg", "data": b64}},
            {"type": "text", "text":
                "Eres un asistente técnico. Describe lo que ves: "
                "componentes, estado, luces, códigos, anomalías."}
        ]}])
    return Percepcion(Modalidad.IMAGEN, path, r.content[0].text, 0.9)

def percibir_audio(path: str) -> Percepcion:
    with open(path, "rb") as f:
        r = openai.audio.transcriptions.create(
            model="whisper-1", file=f, language="es")
    return Percepcion(Modalidad.AUDIO, path,
                      f"El usuario dijo: {r.text}", 0.85)

# ---------- Tools ----------
TOOLS = [
    {"name": "buscar_manual", "description":
        "Busca en el manual del producto por síntoma o código de error.",
     "input_schema": {"type": "object", "properties": {
         "query": {"type": "string"}, "producto": {"type": "string"}},
         "required": ["query", "producto"]}},
    {"name": "generar_diagrama", "description":
        "Genera una imagen diagrama ilustrando pasos de reparación.",
     "input_schema": {"type": "object", "properties": {
         "prompt": {"type": "string"}}, "required": ["prompt"]}},
    {"name": "sintetizar_voz", "description":
        "Convierte texto a audio para enviárselo al técnico.",
     "input_schema": {"type": "object", "properties": {
         "texto": {"type": "string"}}, "required": ["texto"]}},
    {"name": "escalar_a_humano", "description":
        "Escala el caso a un ingeniero humano cuando el agente no tiene "
        "confianza suficiente o la acción es irreversible.",
     "input_schema": {"type": "object", "properties": {
         "motivo": {"type": "string"}}, "required": ["motivo"]}},
]

MANUAL = {
    "X450_luz_roja": "Luz roja fija = fallo de temperatura. Apagar, esperar 10 min, revisar ventilador."
}

def ejecutar_tool(nombre: str, args: dict) -> str:
    if nombre == "buscar_manual":
        key = f"{args['producto']}_{args['query'].lower().replace(' ', '_')[:20]}"
        return MANUAL.get(key, "No encontré una entrada específica.")
    if nombre == "generar_diagrama":
        r = openai.images.generate(model="gpt-image-1-mini",
                                   prompt=args["prompt"], size="1024x1024")
        path = f"diag_{uuid.uuid4().hex[:8]}.png"
        import httpx
        Path(path).write_bytes(httpx.get(r.data[0].url).content)
        return f"Diagrama generado en {path}"
    if nombre == "sintetizar_voz":
        path = f"resp_{uuid.uuid4().hex[:8]}.mp3"
        r = openai.audio.speech.create(model="tts-1", voice="nova",
                                       input=args["texto"])
        r.stream_to_file(path)
        return f"Audio generado en {path}"
    if nombre == "escalar_a_humano":
        log.warning("Escalado: %s", args["motivo"])
        return "Caso escalado. Un ingeniero te contactará."
    return f"Tool desconocido: {nombre}"

# ---------- Loop del agente ----------
class AgenteCampo:
    def __init__(self, producto: str):
        self.producto = producto
        self.historial: list[dict] = []

    def _construir_mensaje(self, instruccion: str, percepciones: list[Percepcion]):
        contenido = [{"type": "text", "text":
            f"[Producto: {self.producto}] {instruccion}"}]
        for p in percepciones:
            if p.modalidad == Modalidad.IMAGEN:
                b64 = base64.b64encode(Path(p.contenido).read_bytes()).decode()
                contenido.append({"type": "image", "source": {
                    "type": "base64", "media_type": "image/jpeg", "data": b64}})
            else:
                contenido.append({"type": "text",
                    "text": f"[{p.modalidad}] {p.descripcion}"})
        return {"role": "user", "content": contenido}

    def ejecutar(self, instruccion: str, percepciones: list[Percepcion],
                 max_turnos: int = 6) -> dict:
        self.historial.append(self._construir_mensaje(instruccion, percepciones))
        salida_final = {"respuesta": None, "artefactos": []}

        for turno in range(max_turnos):
            resp = claude.messages.create(
                model="claude-sonnet-4-5",
                max_tokens=1500, tools=TOOLS, messages=self.historial,
                system=("Eres un agente de soporte técnico de campo. "
                        "Usa tools cuando necesites consultar el manual o "
                        "generar materiales para el técnico. Si no estás "
                        "seguro o la acción puede causar daño, escala."))

            self.historial.append({"role": "assistant",
                                   "content": resp.content})

            if resp.stop_reason == "end_turn":
                salida_final["respuesta"] = "".join(
                    b.text for b in resp.content if b.type == "text")
                return salida_final

            if resp.stop_reason == "tool_use":
                tool_results = []
                for block in resp.content:
                    if block.type == "tool_use":
                        log.info("tool=%s input=%s", block.name, block.input)
                        try:
                            out = ejecutar_tool(block.name, block.input)
                        except Exception as e:
                            out = f"Error ejecutando tool: {e}"
                        salida_final["artefactos"].append(
                            {"tool": block.name, "resultado": out})
                        tool_results.append({"type": "tool_result",
                            "tool_use_id": block.id, "content": out})
                self.historial.append({"role": "user", "content": tool_results})
                continue

            break
        return salida_final

if __name__ == "__main__":
    agente = AgenteCampo(producto="X450")
    percepciones = [
        percibir_imagen("panel.jpg"),
        percibir_audio("nota_voz.m4a"),
    ]
    r = agente.ejecutar(
        "Veo una luz roja en el panel. ¿Qué significa y qué hago?",
        percepciones)
    print(r["respuesta"])
    for a in r["artefactos"]:
        print(" -", a)
```

### Patrón de agente de monitoreo

```python
class AgenteMonitoreo:
    """Analiza frames de una cámara y alerta en eventos anómalos."""
    def __init__(self, callback_alerta):
        self.callback = callback_alerta
        self.baseline = None

    def establecer_baseline(self, frame_path: str):
        self.baseline = percibir_imagen(frame_path).descripcion

    def analizar_frame(self, frame_path: str):
        actual = percibir_imagen(frame_path)
        if not self.baseline:
            self.baseline = actual.descripcion
            return
        prompt = (f"BASELINE: {self.baseline}\n\nACTUAL: {actual.descripcion}\n\n"
                  "¿Hay un evento significativo? Responde JSON "
                  '{"evento": bool, "severidad": "baja|media|alta", "desc": str}')
        r = claude.messages.create(
            model="claude-3-5-haiku-20241022", max_tokens=200,
            messages=[{"role": "user", "content": prompt}])
        data = json.loads(r.content[0].text)
        if data["evento"] and data["severidad"] == "alta":
            self.callback({"frame": frame_path, **data})
```

## Errores comunes

- **Demasiados tools**. Más de 10-15 degrada el rendimiento del LLM; agrupa o routeo por capacidad.
- **No validar outputs de tools**. Si un tool devuelve basura el agente la toma como verdad. Valida con Pydantic.
- **Loop infinito**. Siempre fija `max_turnos` y `max_tool_calls` por sesión.
- **Historial sin límite**. Multimodal consume tokens muy rápido (una imagen = ~1500 tokens). Trunca o resume el historial periódicamente.
- **Ignorar prompt injection multimodal**. Una imagen con texto malicioso puede secuestrar al agente. Filtra con Llama Guard 3 Vision u otro content filter antes de pasar al LLM principal.
- **Sin confirmación en acciones irreversibles**. Un agente que compra, envía emails o modifica archivos sin aprobación es una bomba. Siempre human-in-the-loop en pasos críticos.
- **Latencia de voice descontrolada**. Si STT, LLM o TTS no son streaming el pipeline suma 2-3 s. Mide y optimiza por etapa.
- **No manejar interrupciones del usuario**. Un voice agent que no sabe pararse cuando el usuario habla se siente robótico. Usa Pipecat/LiveKit, no construyas tú el VAD.
- **Costos sin tope**. Un agente que entra en loop puede quemar cientos de dólares en minutos. Rate limit por tool, por sesión y por usuario; además budget cap diario.
- **No instrumentar la cadena**. Sin traces por percepción, decisión y acción es imposible depurar. Usa Langfuse, Arize Phoenix o LangSmith con soporte multimodal.
- **Confiar en el agente para tareas donde debería escalar**. Diseña `escalar_a_humano` como tool de primera clase y entrena al agente a usarlo cuando la confianza cae.

## Resumen

- Un **agente multimodal** cierra el loop *perceive → think → act* operando sobre texto, imagen, audio y video, y ejecuta acciones vía **tool calls**.
- 2024-2025 trajo agentes frontera: **Anthropic Computer Use**, **OpenAI Operator**, **Google Mariner**; voice agents voz-a-voz con GPT-4o Realtime y Gemini Live.
- Para **voice agents** la ingeniería crítica es **streaming en todas las etapas** (STT, LLM, TTS) + **interrupt handling**; usa LiveKit o Pipecat.
- Los **computer-use agents** operan en VMs sandboxed, miden su progreso con benchmarks como **OSWorld** y requieren confirmación humana en pasos sensibles.
- **Tool design** importa: 3-10 tools bien definidos, con descripciones claras, validación Pydantic y escalado a humano cuando falte confianza.
- **Seguridad multimodal** incluye: prompt injection en imágenes, content safety sobre audio/video, allowlists de dominios, audit log y rate limits por tool.
- Observabilidad **por percepción + decisión + acción** es imprescindible; sin ello depurar un agente es imposible.
- Lo que viene: VLAs para robótica real (π0, RT-2, OpenVLA), agentes autónomos de nivel OSWorld >50%, y voice agents indistinguibles del humano para soporte de alto volumen.
