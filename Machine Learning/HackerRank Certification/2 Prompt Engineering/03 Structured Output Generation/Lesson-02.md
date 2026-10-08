# XML y Formatos Alternativos

## ¿Qué es?

Aunque JSON domina la integración entre servicios web, existen **otros formatos estructurados** donde un LLM puede escribir con ventajas concretas: **XML** para documentos ricos con metadatos, **CSV** para tablas de alto volumen y **Markdown** para contenido que humanos editarán. Elegir el formato correcto es parte del diseño de la salida estructurada, no un detalle estético.

El principio es simple: **el formato sigue a la estructura del dato**. Datos tabulares → CSV. Documentos jerárquicos con metadatos y espacios de nombres → XML. Contenido semi-estructurado para humanos → Markdown. Datos de API para otro servicio → JSON.

| Formato | Fuerte en | Débil en | Soporte en LLMs |
|---|---|---|---|
| JSON | Interop, APIs, nested data | Metadatos por nodo, comentarios | Nativo (JSON mode, schemas) |
| XML | Metadatos, namespaces, estándares (HL7, XBRL) | Verbosidad, tokens | Prompting + validación externa |
| CSV | Tablas grandes, Excel, bulk import | Jerarquía, escape de comillas | Prompting cuidadoso |
| Markdown | Humanos + máquinas, docs | Validación estricta | Excelente (los LLMs están entrenados en toneladas) |
| YAML | Config legible | Indentación frágil, ambigüedades (`yes` → bool) | Bueno pero riesgoso |
| TOML | Config de aplicación | Jerarquía profunda | Decente |

## ¿Por qué importa?

Un sistema de **historia clínica electrónica** debe conservar la jerarquía del documento, atributos de confidencialidad por nodo (`confidential="HIPAA"`), y cumplir estándares (HL7 FHIR). Forzarlo a JSON pierde la noción de atributo vs. elemento y rompe la validación XSD del receptor. Un **reporte financiero trimestral** de 50 000 filas en JSON pagaría tokens repetidos por cada clave; en CSV cuesta la mitad y abre directo en Excel. Un **generador de documentación de API** que emite Markdown se integra con GitHub, MkDocs y VS Code sin un parser dedicado.

Elegir mal el formato se paga en: **tokens**, **errores de parseo**, **incompatibilidad con herramientas aguas abajo** y **experiencia del usuario final**.

### Cuándo elegir cada uno

- **XML** cuando el consumidor es un sistema regulado (HL7, XBRL, OFX, SEPA) o cuando necesitas **atributos por nodo** (`<diagnosis code="E11.9" confidence="0.92"/>`).
- **CSV** cuando los datos son **planos y voluminosos** y los consumen Excel, pandas, BI tools, o un `COPY FROM` de PostgreSQL.
- **Markdown** cuando el output es **leído por humanos** pero vive en Git, se publica en una wiki o se procesa con un parser estándar (`markdown-it`, `remark`).
- **YAML/TOML** para generar **archivos de configuración** (CI, Kubernetes, pyproject.toml).

## ¿Cómo funciona?

### XML con atributos y namespaces

XML distingue entre **elementos** (contenido jerárquico) y **atributos** (metadatos del nodo). Los **namespaces** (`xmlns:hl7="..."`) evitan colisiones cuando mezclas vocabularios. Validar un XML contra un **XSD** garantiza conformidad estructural; validar con **Schematron** permite reglas de negocio ("si `age > 65` entonces `riskLevel` requerido").

Flujo típico:
1. Prompt que describe la estructura y los atributos requeridos.
2. Parseo con `xml.etree.ElementTree` o, mejor, **`lxml`** para XSD y XPath.
3. Validación contra XSD.
4. Repair pass si falla (ver sección de errores).

### CSV con cuidado del escape

El estándar práctico es **RFC 4180**. Las trampas son el **delimitador** (coma vs. punto y coma en locales europeos), el **escape de comillas** dentro de campos y los **saltos de línea embebidos**. Nunca generes CSV con `",".join(...)`: usa `csv.writer` para producir y `csv.reader` para validar.

### Markdown y dialectos

El Markdown "oficial" (CommonMark) no incluye tablas ni bloques de código con lenguaje; esos vienen de **GitHub Flavored Markdown (GFM)**. Si tu consumidor es GitHub, MkDocs o Docusaurus, exige GFM explícitamente en el prompt. Para validar, parsea con `markdown-it-py` y comprueba la presencia de headings, tablas o bloques esperados.

### Multi-formato en una sola respuesta

Un patrón común es pedir **Markdown que embeba bloques de código JSON o CSV**:

```markdown
## Resumen
...prosa para humanos...

```json
{"metric": "revenue", "value": 1234.56}
```
```

Permite tener prosa + datos estructurados en el mismo output; procesas la parte formal con una regex sobre code fences.

## Ejemplo con código

### 1. Generar XML con atributos y validar

```python
from openai import OpenAI
from lxml import etree

client = OpenAI()

prompt = """Genera un expediente médico en XML con:
- Elemento raíz <PatientRecord xmlns:hl7="urn:hl7-org:v3">
- Atributos: id, confidential="HIPAA", timestamp (ISO 8601)
- Sub-elementos <Demographics>, <Allergies>, <Medications>, <Diagnoses>
- Cada <Diagnosis> con atributos code (ICD-10) y confidence (0-1)

Paciente: Juan Pérez, 45 años, DOB 1979-03-15.
Alergias: Penicilina. Medicación: Lisinopril 10mg/día. Diagnóstico: hipertensión."""

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": prompt}],
)
xml_text = resp.choices[0].message.content.strip()

# Parseo robusto
try:
    root = etree.fromstring(xml_text.encode("utf-8"))
except etree.XMLSyntaxError as e:
    print(f"XML inválido: {e}")
    raise

# Validación contra XSD (si lo tienes)
# schema = etree.XMLSchema(etree.parse("patient.xsd"))
# schema.assertValid(root)

for dx in root.iter("Diagnosis"):
    print(dx.get("code"), dx.get("confidence"), dx.text)
```

### 2. Función de "repair" para XML malformado

```python
import re
from lxml import etree

def repair_xml(xml_text: str) -> etree._Element | str:
    """Intenta parsear; si falla, aplica heurísticas comunes."""
    try:
        return etree.fromstring(xml_text.encode("utf-8"))
    except etree.XMLSyntaxError:
        pass

    # Elimina caracteres no imprimibles
    cleaned = re.sub(r"[^\x09\x0A\x0D\x20-\x7E -￿]", "", xml_text)
    # Escapa & huérfanos (no parte de &amp; &lt; &gt; &quot; &apos; o &#...;)
    cleaned = re.sub(r"&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)", "&amp;", cleaned)
    # Cierra tag raíz si quedó abierto por truncamiento
    try:
        return etree.fromstring(cleaned.encode("utf-8"))
    except etree.XMLSyntaxError:
        return xml_text  # devuélvelo crudo para inspección manual
```

### 3. Generar CSV y validar con `csv.reader`

```python
import csv, io
from openai import OpenAI

client = OpenAI()

prompt = """Genera un reporte financiero trimestral en CSV estricto RFC 4180:
- Primera fila: encabezados exactos: quarter,revenue,expenses,profit,margin_pct
- Fechas en formato YYYY-Qn (ej: 2024-Q3)
- Moneda con 2 decimales, sin signo $
- NO incluyas texto fuera del CSV, ni ```csv fences

Datos: Q1-Q4 2024, revenue 150K/160K/170K/180K, costos 120K/125K/130K/135K."""

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": prompt}],
)
csv_text = resp.choices[0].message.content.strip()

reader = csv.reader(io.StringIO(csv_text))
rows = list(reader)

# Validaciones
assert rows[0] == ["quarter", "revenue", "expenses", "profit", "margin_pct"], \
    f"Encabezados incorrectos: {rows[0]}"
assert all(len(r) == 5 for r in rows[1:]), "Filas con número de columnas distinto"

for r in rows[1:]:
    # Validación de tipos
    float(r[1]); float(r[2]); float(r[3]); float(r[4])

print(f"CSV válido: {len(rows)-1} filas")
```

### 4. Markdown con tablas y validación estructural

```python
from openai import OpenAI
import re

client = OpenAI()

prompt = """Genera documentación en Markdown (GFM) para el endpoint:
GET /users/{id} — devuelve datos de un usuario.

Estructura requerida:
# Título del endpoint
## Parámetros       (tabla con columnas: nombre, tipo, requerido, descripción)
## Respuesta        (bloque ```json con el schema)
## Ejemplo          (bloque ```bash con curl)
## Códigos de error (tabla)
"""

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": prompt}],
)
md = resp.choices[0].message.content

# Validación estructural mínima
required_headings = ["# ", "## Parámetros", "## Respuesta", "## Ejemplo"]
missing = [h for h in required_headings if h not in md]
assert not missing, f"Faltan encabezados: {missing}"

# Extrae el bloque JSON embebido
m = re.search(r"```json\n(.*?)\n```", md, re.DOTALL)
if m:
    import json
    schema = json.loads(m.group(1))  # validación cruzada
    print("Schema embebido:", schema)
```

### 5. Elegir formato dinámicamente

```python
from pydantic import BaseModel
from typing import Literal

class FormatDecision(BaseModel):
    format: Literal["json", "xml", "csv", "markdown"]
    reason: str

def pick_format(use_case: str) -> FormatDecision:
    """Heurística simple basada en keywords."""
    uc = use_case.lower()
    if any(k in uc for k in ["hl7", "fhir", "xbrl", "attribute", "namespace"]):
        return FormatDecision(format="xml", reason="metadatos/estándar")
    if any(k in uc for k in ["excel", "bulk", "import", "tabular", "millones"]):
        return FormatDecision(format="csv", reason="tabular de alto volumen")
    if any(k in uc for k in ["doc", "readme", "wiki", "blog"]):
        return FormatDecision(format="markdown", reason="humano + máquina")
    return FormatDecision(format="json", reason="default para APIs")
```

### 6. Comparativa de costo en tokens (ilustrativa)

Para 1 000 registros de 5 campos:

| Formato | Tokens aprox. | Observación |
|---|---|---|
| JSON (`[{...}, ...]`) | ~45 000 | Claves repetidas |
| JSON compacto sin claves (array de arrays) | ~22 000 | Pierde auto-descripción |
| CSV | ~18 000 | Encabezado 1 vez |
| XML con elementos | ~55 000 | Más verboso que JSON |
| XML con atributos | ~35 000 | Mejor que elementos |

El ahorro de CSV sobre JSON en volumen explica por qué los pipelines de datos siguen prefiriéndolo.

## Errores comunes

- **Usar XML "porque suena enterprise"** cuando el consumidor acepta JSON. XML paga tokens de más sin beneficio.
- **Generar CSV con `str.join(",")`**. Rompe en el momento en que un campo contiene coma, comilla o salto de línea. Usa `csv.writer`.
- **Confundir atributos y elementos XML**. Atributos para metadatos del nodo (sin estructura interna); elementos para contenido jerárquico. Regla: si puede repetirse, debe ser elemento.
- **No declarar namespaces** cuando el consumidor los exige (HL7, SOAP). El documento parsea pero es inválido contra el estándar.
- **Markdown dialectal**. Pedir "Markdown" sin especificar GFM genera tablas que GitHub renderiza y CommonMark ignora, o viceversa.
- **No controlar fences de código** en Markdown. El modelo a veces envuelve su respuesta en ```` ```markdown ```` extra, duplicando bloques.
- **YAML con valores ambiguos**: `yes`, `no`, `on`, `off` se convierten en booleanos. Cita siempre strings dudosos.
- **Olvidar la codificación**. XML por default declara UTF-8; emitir caracteres en latin-1 produce un `XMLSyntaxError` opaco. Fuerza `encoding="utf-8"` en el prompt.
- **Validación tardía**. Si validas solo al llegar al consumidor final, el error aparece lejos del origen. Valida inmediatamente después del `response.create`.
- **Repair indefinido**. Reintentar con heurísticas de reparación hasta "que pase" oculta bugs reales del prompt. Limita a 1-2 pasadas y registra métricas.
- **Mezclar prosa y formato estricto**. El modelo tiende a prefijar "Aquí tienes el XML:". Instrúyelo explícitamente: *"responde con XML únicamente, sin texto adicional"*, y recorta cualquier texto antes del primer `<` o después del último `>`.
- **Pedir Markdown "con JSON embebido" sin fences**. Sin ```` ```json ```` el extractor no distingue la parte estructurada del texto.

## Resumen

- La elección de formato **sigue a la forma del dato y al consumidor**: tabular → CSV, jerárquico con metadatos → XML, humano + máquina → Markdown, APIs → JSON.
- **XML** brilla cuando necesitas **atributos**, **namespaces** y **validación XSD/Schematron** (healthcare, finance, gobierno).
- **CSV** gana en **volumen** y **compatibilidad con Excel/pandas**; cuida el escape con la librería estándar `csv`.
- **Markdown** es el mejor formato para contenido **dual** (humano y máquina); si tu target es GitHub o MkDocs, exige GFM.
- Validación **inmediata**: parsea con la librería adecuada (`lxml`, `csv`, `markdown-it-py`) justo después de recibir la respuesta.
- Implementa un **repair pass** acotado (máximo 1-2 intentos) y registra métricas; nunca un bucle infinito.
- Documenta en el prompt **exactamente** qué dialecto quieres (CommonMark vs GFM, RFC 4180, XML con namespaces específicos).
- Para formatos exóticos sobre modelos abiertos, usa **grammars** (GBNF, Outlines) para garantía dura.
- Mide **costo en tokens** por formato; a veces CSV compacto le gana a JSON incluso en integraciones programáticas.
- Un sistema maduro **elige formato dinámicamente** según el caso de uso en lugar de forzar uno solo.
