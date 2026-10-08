# OCR Implícito vs Explícito y Extracción Structured con Pydantic

## ¿Qué es?

**OCR (Optical Character Recognition)** es el proceso de convertir texto contenido en una imagen en texto digital procesable. En 2026 coexisten dos enfoques:

- **OCR explícito:** herramientas especializadas (Tesseract, AWS Textract, Google Document AI, Azure Document Intelligence) que detectan caracteres pixel por pixel y devuelven texto plano, bounding boxes y niveles de confianza.
- **OCR implícito:** VLMs generativos (Claude 3.5, GPT-4o, Gemini) que "leen" la imagen como parte de su razonamiento y pueden devolver directamente **datos estructurados** (JSON, Pydantic) con la información útil, no solo el texto crudo.

**Extracción structured** es ir un paso más allá: en lugar de pedir "describe la factura", pides "devuélveme un objeto `Factura` con `total`, `fecha`, `rfc_emisor`, `lineas[]`" y validas la respuesta con un schema (Pydantic, JSON Schema, Zod).

### Comparación rápida

| Dimensión | OCR explícito (Tesseract/Textract) | OCR implícito (VLM) |
|---|---|---|
| Salida nativa | Texto plano + bounding boxes | Texto, JSON, razonamiento |
| Entiende layout | Solo con reglas o modelos adicionales | Sí, nativo |
| Costo por página | Muy bajo ($0.001 – $0.015) | Medio-alto ($0.005 – $0.05) |
| Latencia | Decenas de ms | Segundos |
| Texto denso (libros) | Excelente | Bueno pero caro |
| Formularios con layout variable | Frágil | Excelente |
| Idiomas raros | Depende de modelos | Depende del proveedor |
| Datos tabulares | Requiere parsing manual | Devuelve tabla estructurada |
| Trazabilidad por carácter | Sí (confidence por token) | Limitada |

## ¿Por qué importa?

El 80% de los proyectos de "AI con documentos" terminan necesitando **extracción structured**: facturas, recibos, contratos, formularios de alta, pólizas, estados de cuenta. Hacer esto a mano con regex sobre un OCR plano es un infierno de mantenimiento porque:

- Cada proveedor emite facturas con layouts distintos.
- Cambios menores en plantillas rompen las regex.
- OCR explícito no sabe que "Total:" y "T O T A L" son lo mismo.
- Totales en gráficas o campos manuscritos vencen al OCR tradicional.

Un VLM moderno con un buen prompt + validación Pydantic reemplaza miles de líneas de parsing frágil. Pero **no es gratis**: para volumen alto conviene un pipeline híbrido (Tesseract/Textract para el texto crudo + VLM para la interpretación semántica solo cuando se necesita).

### Cuándo elegir cada enfoque

- **Elige OCR explícito** si: millones de páginas, texto denso regular (ej. libros), presupuesto ajustado, latencia crítica, necesitas bounding boxes exactos.
- **Elige OCR implícito (VLM)** si: layouts variables, pocos miles de documentos/día, necesitas interpretación semántica (clasificar tipo de documento, extraer campos nombrados).
- **Pipeline híbrido** si: alto volumen pero necesitas semántica. Ej. **Textract** extrae texto + layout → **Claude** interpreta y clasifica.

## ¿Cómo funciona?

### Flujo de extracción structured con un VLM

```
Imagen → VLM (con prompt estricto + response_format JSON)
                ↓
       JSON string (texto generado)
                ↓
       Validación con Pydantic (parse_raw / model_validate)
                ↓
       Objeto tipado o ValidationError (reintentar)
```

### Pydantic como contrato

**Pydantic** valida tipos, aplica coerciones, y lanza `ValidationError` con mensajes útiles si el modelo devolvió algo inválido. Es el estándar de facto en Python para esto.

```python
from pydantic import BaseModel, Field
from datetime import date
from typing import Optional

class LineaFactura(BaseModel):
    descripcion: str
    cantidad: float = Field(gt=0)
    precio_unitario: float = Field(ge=0)
    importe: float = Field(ge=0)

class Factura(BaseModel):
    emisor: str
    rfc_emisor: Optional[str] = None
    fecha: date
    moneda: str = Field(pattern=r"^[A-Z]{3}$")  # ISO 4217
    subtotal: float = Field(ge=0)
    impuestos: float = Field(ge=0)
    total: float = Field(ge=0)
    lineas: list[LineaFactura]
```

### Patrones de prompt para extracción structured

Un buen prompt para extracción tiene estos ingredientes:

1. **Rol claro:** "Eres un extractor de datos de facturas en México."
2. **Esquema explícito:** describe cada campo, su tipo, su formato esperado.
3. **Qué hacer cuando falte:** "Si un campo no es visible, usa `null`."
4. **Formato de salida:** "Responde solo con JSON válido, sin texto adicional."
5. **Few-shot opcional:** 1–2 ejemplos para formatos ambiguos (fechas, monedas).

## Ejemplo con código

### 1) Extracción structured de factura con Claude + Pydantic

```python
# pip install anthropic pydantic pillow
import anthropic, base64, json, pathlib
from pydantic import BaseModel, Field, ValidationError
from datetime import date
from typing import Optional

client = anthropic.Anthropic()

class LineaFactura(BaseModel):
    descripcion: str
    cantidad: float = Field(gt=0)
    precio_unitario: float = Field(ge=0)
    importe: float = Field(ge=0)

class Factura(BaseModel):
    emisor: str
    rfc_emisor: Optional[str] = None
    fecha: date
    moneda: str = Field(pattern=r"^[A-Z]{3}$")
    subtotal: float = Field(ge=0)
    impuestos: float = Field(ge=0)
    total: float = Field(ge=0)
    lineas: list[LineaFactura]

PROMPT = """Eres un extractor de datos de facturas en español.

Analiza la imagen y devuelve ÚNICAMENTE un JSON válido con este schema:
{
  "emisor": string,
  "rfc_emisor": string | null,
  "fecha": "YYYY-MM-DD",
  "moneda": "MXN" | "USD" | "EUR" | ...,     // código ISO 4217
  "subtotal": number,
  "impuestos": number,
  "total": number,
  "lineas": [
    {"descripcion": string, "cantidad": number,
     "precio_unitario": number, "importe": number}
  ]
}

Reglas:
- Convierte fechas al formato YYYY-MM-DD.
- Elimina símbolos de moneda y separadores de miles de los números.
- Si un campo no aparece, usa null (nunca inventes).
- No añadas texto fuera del JSON."""

def cargar_imagen(path: str) -> dict:
    ext = pathlib.Path(path).suffix.lower().lstrip(".")
    media_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                  "png": "image/png", "webp": "image/webp"}[ext]
    data = base64.standard_b64encode(pathlib.Path(path).read_bytes()).decode()
    return {"type": "image",
            "source": {"type": "base64", "media_type": media_type, "data": data}}

def extraer_factura(path: str, max_reintentos: int = 2) -> Factura:
    for intento in range(max_reintentos + 1):
        msg = client.messages.create(
            model="claude-3-5-sonnet-20240620",
            max_tokens=2048,
            system="Responde solo con JSON válido, sin texto adicional ni markdown.",
            messages=[{
                "role": "user",
                "content": [cargar_imagen(path), {"type": "text", "text": PROMPT}],
            }],
        )
        raw = msg.content[0].text.strip()
        # Quitar fences accidentales
        if raw.startswith("```"):
            raw = raw.strip("`").split("\n", 1)[1].rsplit("```", 1)[0]
        try:
            return Factura.model_validate(json.loads(raw))
        except (json.JSONDecodeError, ValidationError) as e:
            if intento == max_reintentos:
                raise
            print(f"[intento {intento+1}] inválido: {e}, reintentando...")

factura = extraer_factura("factura.jpg")
print(factura.model_dump_json(indent=2))
print(f"Suma líneas: {sum(l.importe for l in factura.lineas):.2f}")
print(f"Total reportado: {factura.total:.2f}")
```

### 2) Mismo patrón con OpenAI y `response_format=json_object`

```python
from openai import OpenAI
import base64, json, pathlib
from pydantic import ValidationError

client = OpenAI()

def extraer_openai(path: str) -> Factura:
    img_b64 = base64.b64encode(pathlib.Path(path).read_bytes()).decode()
    resp = client.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system",
             "content": "Devuelves solo JSON válido, nada más."},
            {"role": "user", "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url",
                 "image_url": {"url": f"data:image/jpeg;base64,{img_b64}",
                               "detail": "high"}},
            ]},
        ],
        max_tokens=2048,
    )
    return Factura.model_validate(json.loads(resp.choices[0].message.content))
```

### 3) Extracción de recibo (schema más simple)

```python
class Recibo(BaseModel):
    comercio: str
    fecha: Optional[date]
    total: float = Field(ge=0)
    moneda: str = "USD"
    metodo_pago: Optional[str] = None
    items: list[dict] = Field(default_factory=list)

prompt_recibo = """Extrae del recibo:
- comercio: nombre del negocio
- fecha: YYYY-MM-DD si está visible
- total: monto total pagado
- moneda: código ISO 4217 (USD, MXN, EUR, ...)
- metodo_pago: "tarjeta", "efectivo" o null
- items: lista [{"nombre": str, "precio": float}]

Responde solo con JSON."""
```

### 4) Pipeline híbrido: Tesseract + Claude

```python
# pip install pytesseract pillow anthropic
import pytesseract
from PIL import Image

def ocr_texto_crudo(path: str) -> str:
    """Tesseract extrae el texto rápido y barato."""
    return pytesseract.image_to_string(Image.open(path), lang="spa")

def interpretar_con_claude(texto_crudo: str) -> dict:
    """Claude convierte el texto crudo en JSON estructurado."""
    msg = client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Convierte este texto OCR en JSON con los campos
emisor, fecha (YYYY-MM-DD), total y moneda. Responde solo JSON.

TEXTO:
{texto_crudo}""",
        }],
    )
    return json.loads(msg.content[0].text.strip())

# El VLM solo ve texto (no la imagen) → mucho más barato por request
datos = interpretar_con_claude(ocr_texto_crudo("factura.jpg"))
```

### 5) Validación cruzada: suma de líneas vs. total

```python
def validar_factura(f: Factura, tolerancia: float = 0.02) -> list[str]:
    errores = []
    suma = sum(l.importe for l in f.lineas)
    esperado = round(f.subtotal + f.impuestos, 2)
    if abs(f.total - esperado) > tolerancia:
        errores.append(f"Total {f.total} ≠ subtotal+impuestos {esperado}")
    if abs(suma - f.subtotal) > tolerancia:
        errores.append(f"Suma líneas {suma} ≠ subtotal {f.subtotal}")
    return errores
```

## Errores comunes

- **Confiar en OCR implícito para texto denso.** Procesar libros, periódicos o documentos de 50+ páginas con un VLM cuesta cientos de dólares cuando **Tesseract** o **AWS Textract** lo harían por céntimos. Usa VLM solo para interpretación semántica.
- **Prompts sin ejemplos para extracción structured.** Sin few-shot, modelos devuelven fechas como "15 de marzo del 2024", "15/03/2024" o "2024-03-15" indistintamente. Especifica el formato y valida con Pydantic.
- **No validar con Pydantic.** Confiar en que el JSON está bien formado sin schema produce bugs silenciosos: `total` llega como string `"1,234.56"` y tu base de datos lo acepta como texto.
- **Olvidar que el modelo "alucina" campos.** Si pides `rfc_emisor` y no está en la imagen, un VLM mal prompteado se lo inventa. Siempre instruye explícitamente "si no es visible, devuelve null".
- **No desactivar fences de markdown.** Muchos modelos envuelven el JSON en ```json ... ``` aunque les digas que no. Haz strip defensivo antes de `json.loads`.
- **Procesar PDFs multi-página en una sola llamada.** La resolución efectiva por página baja, el OCR implícito falla. Divide el PDF en páginas con `pdf2image` y procesa página por página.
- **Mandar imágenes gigantes sin preprocesar.** Un escaneo de 300 DPI de un A4 son ~2500x3500 pixeles → cientos de tokens por tile. Redimensiona a 1500–2000 px máximo salvo que necesites texto muy pequeño.
- **No medir precision/recall sobre un dataset golden.** Antes de desplegar extracción, etiqueta a mano 100 documentos y mide por campo. Sin métricas, no sabes si tu prompt mejoró o empeoró.
- **Rechazar en lugar de reintentar.** Si Pydantic falla, pedir al modelo que corrija su propia salida (con el mensaje de error) suele arreglarlo en 1–2 iteraciones.

## Resumen

- **OCR explícito** (Tesseract, Textract, Google DocAI) es barato y rápido para texto denso; da texto plano + bounding boxes.
- **OCR implícito** (Claude 3.5, GPT-4o, Gemini) entiende layout, interpreta semántica y devuelve JSON directo; más caro y más lento.
- **Pipeline híbrido** (Tesseract + VLM sobre el texto) combina lo mejor: barato + semántico.
- **Pydantic** es el contrato ideal: define schema, valida tipos, lanza `ValidationError` útil, permite reintentos guiados.
- Un buen **prompt de extracción** incluye rol, schema explícito, qué hacer con nulos, formato estricto de salida.
- Para producción: **valida cruzado** (suma de líneas == subtotal, total == subtotal + impuestos) y mide **precision/recall por campo** sobre un dataset golden.
- Divide **PDFs multi-página** antes de procesar; no envíes imágenes gigantes sin resize.
- Reintentos guiados con el `ValidationError` suelen recuperar el 90%+ de los casos borde.
