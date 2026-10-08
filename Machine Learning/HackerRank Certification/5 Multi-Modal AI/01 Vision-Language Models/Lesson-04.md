# Casos de Uso Aplicados: UI Testing, Document Extraction, Visual QA y Accessibility

## ¿Qué es?

Este lesson aterriza los VLMs en **cuatro casos de uso prácticos** que un ingeniero AI se encuentra repetidamente en producción:

1. **UI testing automation:** validar automáticamente que un screenshot cumple con lo esperado (regresiones visuales, flujos end-to-end dirigidos por un VLM).
2. **Document extraction:** completar lo visto en Lesson-03 con pipelines reales (multi-página, batch, con fallback).
3. **Visual QA (Question Answering):** responder preguntas específicas sobre imágenes para apps de usuario final.
4. **Accessibility:** generación automática de **alt text** descriptivo para imágenes dinámicas (CMS, redes sociales, e-commerce).

![Arquitectura de producción: validación, preprocesado, cliente VLM, caché, monitoreo y lógica de negocio](https://hrcdn.net/ai-engineering/module-5/light/vision-language-lesson04-production-architecture.svg)

## ¿Por qué importa?

Estos cuatro patrones cubren probablemente el 70% de las aplicaciones de visión en producción fuera de dominios muy especializados (médico, satelital, autónomo). Dominarlos reduce el time-to-market de features nuevas de semanas a días:

- **UI testing con VLM** detecta regresiones que Playwright / Cypress ignoran (texto cortado, íconos mal alineados, contraste roto).
- **Document extraction** automatiza back-office en seguros, banca, logística: lo que antes requería 50 personas revisando papeles.
- **Visual QA** habilita UX conversacional: "¿qué talla me queda mejor según mi foto?" o "¿este error de código es un typo?".
- **Alt text automático** cumple requisitos legales (WCAG 2.1, ADA en EEUU, EN 301 549 en UE) sin equipos editoriales dedicados.

## ¿Cómo funciona?

### Patrones de prompting para visión

Hay cuatro patrones de prompt que se repiten:

| Patrón | Cuándo | Ejemplo |
|---|---|---|
| **Instrucción directa** | Tarea simple | "¿Qué color de camiseta lleva la persona?" |
| **Rol + instrucción** | Dominio especializado | "Eres un reviewer de UX; evalúa jerarquía visual." |
| **Schema structured** | Necesitas JSON | "Devuelve JSON con `componentes[]`, `issues[]`." |
| **Few-shot con imágenes** | Tareas visuales ambiguas | 2–3 pares (imagen, respuesta) antes del caso real |

### Few-shot visual

El few-shot con imágenes mejora drásticamente la consistencia en tareas subjetivas (clasificar sentimiento de un meme, calificar calidad de una foto de producto). Estructura:

```
user: [imagen_ej1] "Clasifica: aprobada / rechazada"
assistant: "aprobada"
user: [imagen_ej2] "Clasifica: aprobada / rechazada"
assistant: "rechazada - fondo sucio"
user: [imagen_real] "Clasifica: aprobada / rechazada"
```

### Flujo de UI testing dirigido por VLM

```
1. Playwright/Puppeteer navega a la página
2. Toma screenshot
3. Envía screenshot + checklist al VLM
4. VLM devuelve JSON: {aprobado: bool, issues: [...]}
5. Si falla, se adjunta screenshot al reporte y se marca el test
```

### Flujo de accessibility (alt text)

```
Imagen subida al CMS → VLM genera alt text (<125 chars, sin "imagen de") →
Validación de longitud y lenguaje → se guarda como atributo alt=""
```

## Ejemplo con código

### 1) UI testing: validar un screenshot contra un checklist

```python
# pip install anthropic playwright pydantic
import anthropic, base64, json
from playwright.sync_api import sync_playwright
from pydantic import BaseModel

client = anthropic.Anthropic()

class ResultadoUI(BaseModel):
    aprobado: bool
    issues: list[str]
    severidad: str  # "ninguna" | "menor" | "mayor" | "critica"

CHECKLIST_LOGIN = """Verifica que esta pantalla de login cumpla:
1. Campo de email visible y etiquetado.
2. Campo de contraseña visible y etiquetado.
3. Botón primario de "Iniciar sesión" presente.
4. Enlace "¿Olvidaste tu contraseña?" visible.
5. Logo de la marca en la esquina superior izquierda.
6. Contraste de texto adecuado (texto oscuro sobre fondo claro, o viceversa).

Devuelve JSON:
{"aprobado": bool, "issues": [string], "severidad": "ninguna|menor|mayor|critica"}
Solo JSON, sin texto adicional."""

def tomar_screenshot(url: str, path: str = "shot.png") -> str:
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        page.goto(url, wait_until="networkidle")
        page.screenshot(path=path, full_page=False)
        browser.close()
    return path

def validar_pantalla(url: str, checklist: str) -> ResultadoUI:
    path = tomar_screenshot(url)
    data = base64.standard_b64encode(open(path, "rb").read()).decode()
    msg = client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=1024,
        system="Eres un QA engineer. Responde solo JSON válido.",
        messages=[{
            "role": "user",
            "content": [
                {"type": "image",
                 "source": {"type": "base64", "media_type": "image/png", "data": data}},
                {"type": "text", "text": checklist},
            ],
        }],
    )
    return ResultadoUI.model_validate(json.loads(msg.content[0].text.strip()))

resultado = validar_pantalla("https://app.ejemplo.com/login", CHECKLIST_LOGIN)
assert resultado.aprobado, f"UI falló: {resultado.issues}"
```

### 2) Comparación visual (regresión) entre dos builds

```python
def comparar_builds(url_stable: str, url_pr: str) -> dict:
    s1, s2 = tomar_screenshot(url_stable, "stable.png"), tomar_screenshot(url_pr, "pr.png")
    img1 = base64.b64encode(open(s1, "rb").read()).decode()
    img2 = base64.b64encode(open(s2, "rb").read()).decode()

    msg = client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=1024,
        system="Eres un reviewer de regresión visual. Responde solo JSON.",
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": "La primera imagen es la versión estable. La segunda es un PR candidato."},
                {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": img1}},
                {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": img2}},
                {"type": "text",
                 "text": """Lista diferencias relevantes (ignora anti-aliasing).
Devuelve JSON: {"regresion_detectada": bool, "diferencias": [{"tipo": "layout|texto|color|otro",
"descripcion": str, "severidad": "menor|mayor|critica"}]}"""},
            ],
        }],
    )
    return json.loads(msg.content[0].text.strip())
```

### 3) Generación de alt text para accessibility (WCAG 2.1)

```python
from pydantic import Field

class AltText(BaseModel):
    alt: str = Field(max_length=125)
    long_description: str | None = None  # para imágenes complejas
    es_decorativa: bool = False

ALT_PROMPT = """Genera texto alternativo (alt text) para accessibility según WCAG 2.1.

Reglas:
- Máximo 125 caracteres.
- Describe qué muestra la imagen y su función, no digas "imagen de" ni "foto de".
- Si contiene texto esencial, inclúyelo.
- Si la imagen es puramente decorativa (sin aportar información), es_decorativa=true y alt="".
- Si la imagen es compleja (gráfica, mapa, diagrama), añade `long_description` detallada.
- Responde en español neutro.

Devuelve JSON: {"alt": string, "long_description": string|null, "es_decorativa": bool}"""

def generar_alt_text(path_img: str) -> AltText:
    data = base64.b64encode(open(path_img, "rb").read()).decode()
    msg = client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=512,
        system="Responde solo JSON válido.",
        messages=[{
            "role": "user",
            "content": [
                {"type": "image",
                 "source": {"type": "base64", "media_type": "image/jpeg", "data": data}},
                {"type": "text", "text": ALT_PROMPT},
            ],
        }],
    )
    return AltText.model_validate(json.loads(msg.content[0].text.strip()))

alt = generar_alt_text("producto.jpg")
print(f'<img src="producto.jpg" alt="{alt.alt}">')
if alt.long_description:
    print(f"<p id='desc'>{alt.long_description}</p>")
```

### 4) Visual QA conversacional

```python
class SesionVisualQA:
    def __init__(self, path_img: str, modelo: str = "claude-3-5-sonnet-20240620"):
        self.modelo = modelo
        data = base64.b64encode(open(path_img, "rb").read()).decode()
        self.img_block = {"type": "image",
                          "source": {"type": "base64", "media_type": "image/jpeg", "data": data}}
        self.historia: list[dict] = []

    def preguntar(self, pregunta: str) -> str:
        user_content = [self.img_block, {"type": "text", "text": pregunta}] \
                       if not self.historia else [{"type": "text", "text": pregunta}]
        self.historia.append({"role": "user", "content": user_content})
        msg = client.messages.create(
            model=self.modelo, max_tokens=600, messages=self.historia
        )
        respuesta = msg.content[0].text
        self.historia.append({"role": "assistant", "content": respuesta})
        return respuesta

sesion = SesionVisualQA("habitacion.jpg")
print(sesion.preguntar("¿Cuántas sillas hay?"))
print(sesion.preguntar("¿De qué color es la pared del fondo?"))
print(sesion.preguntar("¿Qué estilo de decoración describirías?"))
```

### 5) Document extraction en batch con control de concurrencia

```python
import asyncio, anthropic
aclient = anthropic.AsyncAnthropic()

async def extraer_uno(path: str, sem: asyncio.Semaphore) -> dict:
    async with sem:
        data = base64.b64encode(open(path, "rb").read()).decode()
        msg = await aclient.messages.create(
            model="claude-3-5-sonnet-20240620",
            max_tokens=1500,
            system="Responde solo JSON.",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image",
                     "source": {"type": "base64", "media_type": "image/jpeg", "data": data}},
                    {"type": "text",
                     "text": "Extrae emisor, fecha (YYYY-MM-DD), total y moneda. JSON."},
                ],
            }],
        )
        return {"path": path, "data": json.loads(msg.content[0].text.strip())}

async def procesar_lote(paths: list[str], concurrencia: int = 5):
    sem = asyncio.Semaphore(concurrencia)
    return await asyncio.gather(*[extraer_uno(p, sem) for p in paths],
                                return_exceptions=True)

# resultados = asyncio.run(procesar_lote(["f1.jpg", "f2.jpg", ...], concurrencia=5))
```

### 6) Few-shot visual para clasificación de calidad de fotos de producto

```python
def _img_block(path: str) -> dict:
    data = base64.b64encode(open(path, "rb").read()).decode()
    return {"type": "image",
            "source": {"type": "base64", "media_type": "image/jpeg", "data": data}}

msg = client.messages.create(
    model="claude-3-5-sonnet-20240620",
    max_tokens=200,
    messages=[
        {"role": "user", "content": [_img_block("ok1.jpg"),
         {"type": "text", "text": "Clasifica: 'aprobada' o 'rechazada: <razón>'"}]},
        {"role": "assistant", "content": "aprobada"},
        {"role": "user", "content": [_img_block("bad1.jpg"),
         {"type": "text", "text": "Clasifica: 'aprobada' o 'rechazada: <razón>'"}]},
        {"role": "assistant", "content": "rechazada: fondo con desorden"},
        {"role": "user", "content": [_img_block("nueva.jpg"),
         {"type": "text", "text": "Clasifica: 'aprobada' o 'rechazada: <razón>'"}]},
    ],
)
print(msg.content[0].text)
```

## Errores comunes

- **Usar VLM para pixel-diff.** Para comparación bit-a-bit usa `pixelmatch`, `odiff` o Percy; el VLM es para diferencias **semánticas** (texto cortado, botón movido, color cambiado).
- **Flaky tests con VLM.** Pedir "¿esta UI está bien?" en lenguaje libre produce respuestas inconsistentes. Siempre pide **JSON con checklist cerrado** y valida con Pydantic.
- **Enviar screenshots full-page gigantes.** Un `fullPage=True` de una landing puede ser 1280x5000 → caro y pierde detalle. Recorta por sección (hero, nav, footer) y procesa por bloques.
- **Alt text redundante o muy largo.** "Imagen de un gato naranja sentado en un sofá rojo" rompe WCAG. Pide máximo 125 caracteres y prohíbe "imagen de" / "foto de".
- **No marcar imágenes decorativas.** Logos y separadores decorativos deben tener `alt=""`, no una descripción. El prompt debe permitirlo.
- **Olvidar el idioma del alt text.** Si tu sitio es en español, pedir alt text sin especificar idioma devuelve inglés inconsistente.
- **Visual QA sin reintentos ni validación.** Si el usuario pregunta "¿cuántos hay?" y el modelo falla al contar, no hay feedback loop. Añade verificación cruzada o advierte de incertidumbre.
- **Batch sin límite de concurrencia.** Lanzar 1000 requests en paralelo tira contra rate limits inmediatamente. Usa `asyncio.Semaphore` y backoff exponencial.
- **No considerar PII en screenshots.** Capturas de dashboards reales pueden contener datos de clientes. Enmascara antes de enviar al VLM (bluring, cropping).
- **Hardcodear prompts en producción.** Los prompts deben vivir en un archivo versionado (prompts/) junto a tests golden, no incrustados en el código.

## Resumen

- **UI testing con VLM** detecta regresiones semánticas que diff de pixeles no ve: usa checklist cerrado + JSON + Pydantic.
- **Document extraction** se escala con `asyncio.Semaphore`, reintentos y validación cruzada (suma líneas == total).
- **Visual QA** funciona bien conversacional: la primera imagen se envía una vez y las preguntas siguientes reutilizan el contexto.
- **Alt text automático** debe respetar WCAG: máximo 125 chars, sin "imagen de", flag para decorativas, long_description para gráficas complejas.
- **Few-shot con imágenes** mejora consistencia en tareas subjetivas (calidad, sentimiento, aprobación).
- Para **pixel-diff** usa `pixelmatch`/`odiff`/Percy; VLM es para diferencias semánticas.
- Recorta screenshots full-page en secciones; nunca envíes imágenes gigantes.
- Versiona los prompts junto a un dataset golden; mide precision/recall antes de desplegar.
- Enmascara PII en screenshots antes de enviar a cualquier VLM.
