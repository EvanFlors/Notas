# Cumplimiento regulatorio, residencia de datos y propiedad intelectual

## ¿Qué es?

**Cumplimiento (compliance)** en herramientas de IA es la traducción de obligaciones legales (GDPR, HIPAA, CCPA, EU AI Act, PCI-DSS) a **controles técnicos verificables**: redacción, retención, cifrado, residencia, consentimiento, auditoría. **Residencia de datos** garantiza que los prompts y outputs permanezcan en jurisdicciones específicas. **Propiedad intelectual (IP)** cubre dos preguntas abiertas: ¿puede un LLM aprender de datos protegidos por copyright?, y ¿de quién es el output que genera?

> Cumplimiento no es papeleo legal: es un conjunto de **requisitos de ingeniería** que se diseñan, implementan y testean como cualquier otra feature.

### Panorama regulatorio

| Regulación | Alcance | Año | Requisitos AI-específicos |
|---|---|---|---|
| **GDPR** (UE 2016/679) | PII de residentes UE | Vigente desde 2018 | Base legal, DPA Art. 28, DSAR Art. 15/17, DPIA Art. 35 para alto riesgo, Art. 22 (decisiones automatizadas) |
| **HIPAA** (EE.UU.) | PHI de pacientes | 1996 | BAA con cada "business associate" que procese PHI (incluye vendors LLM) |
| **CCPA/CPRA** (California) | Datos de consumidores | 2020/2023 | Opt-out de venta/compartición, right to delete, right to know |
| **EU AI Act** | Sistemas de IA en UE | 2024, aplicación por fases hasta 2027 | Clasificación por riesgo, Art. 10 (data governance), transparency Art. 50, obligaciones GPAI Art. 53 |
| **PCI-DSS v4.0** | Datos de tarjetas | 2024 (vigente) | PAN tokenizado antes de LLM; LLMs normalmente no deben ver PAN |
| **LGPD** (Brasil) | Equivalente GDPR | 2020 | Similar a GDPR; ANPD como regulador |
| **PIPEDA** (Canadá) | Consumidores | 2000 | Consent model, meaningful consent |
| **UK AI Regulation** | Reino Unido | Sectorial, 2024+ | Enfoque pro-innovación, sin ley única por ahora |

### EU AI Act: el nuevo paisaje

El **EU AI Act** (Reglamento 2024/1689) categoriza sistemas de IA en cuatro niveles:

| Nivel | Ejemplos | Obligaciones |
|---|---|---|
| **Prohibido** | Social scoring, manipulación subliminal | Prohibición total |
| **Alto riesgo** | IA en reclutamiento, crédito, infraestructura crítica | Registro, DPIA, transparencia, supervisión humana, auditoría |
| **Riesgo limitado** | Chatbots, deepfakes | Transparencia (declarar que es IA) |
| **Mínimo** | Filtros de spam, videojuegos | Sin obligación |

**Art. 10 (Data governance)** es clave para herramientas: los datasets de entrenamiento, validación y test deben ser **relevantes, representativos, libres de errores y completos**, con examen de posibles sesgos. **Art. 53** aplica a GPAI (General Purpose AI) e introduce obligaciones de documentación técnica y resumen de datos de entrenamiento.

## ¿Por qué importa?

### Zero-Data-Retention (ZDR) y data policies de proveedores

| Proveedor | Opción ZDR | Default retention | Entrenamiento con tus prompts | BAA (HIPAA) |
|---|---|---|---|---|
| **Anthropic API** | Sí, por defecto en Enterprise | 0–30 días | No (nunca entrena con API) | Sí, bajo contrato |
| **Anthropic Claude.ai Free/Pro** | No | Hasta 30 días; opt-out para training en settings | Sí por defecto en Free (desde 2025) | No |
| **OpenAI API** | Sí (ZDR opt-in para enterprise) | 30 días default | No (API) | Sí con Enterprise + BAA |
| **OpenAI ChatGPT Enterprise/Team** | Sí (no training por default) | Según admin | No | Sí |
| **ChatGPT Free/Plus** | No | Hasta 30 días | Sí salvo opt-out en settings | No |
| **Azure OpenAI** | Sí (opt-in abuse monitoring off) | 30 días con monitoring | Nunca | Sí |
| **AWS Bedrock** | Sí (no retention por defecto) | 0 días | Nunca | Sí |
| **Google Vertex AI / Gemini** | Sí (customer-managed) | Variable | Nunca en Vertex | Sí |
| **GitHub Copilot Business/Enterprise** | Sí (no training) | Prompts no retenidos | No en Business | No típicamente |
| **Copilot Individual** | No | Variable | Sí (telemetry opt-out) | No |

Dos reglas prácticas:

1. **API empresarial ≠ chat consumer.** Las APIs enterprise de Anthropic, OpenAI, Google y AWS **no entrenan con tus datos** por contrato; los chats públicos (Free/Plus) sí lo hacen a menos que optes por salirte.
2. **ZDR no es automático.** Pedirlo explícitamente, firmar el addendum y configurar el header o flag correspondiente.

### Residencia de datos

Operar en UE con un modelo cuyo endpoint vive en us-east-1 implica **transferencia internacional** regulada por GDPR Cap. V. Opciones:

- **Standard Contractual Clauses (SCCs)** firmadas con el proveedor.
- **EU-US Data Privacy Framework** (desde julio 2023, reemplazando al invalidado Privacy Shield).
- **Endpoints regionales**: Azure OpenAI EU, Bedrock eu-central-1, Vertex AI europe-west4, Anthropic AWS Bedrock EU, OpenAI Dublin.
- **On-prem / self-hosted** para datos de máxima sensibilidad: Llama 3.1, Mistral Large, Qwen 2.5, DeepSeek V3 con vLLM/TGI.

### On-prem vs. cloud LLMs

| Dimensión | On-prem / self-hosted | Cloud (API managed) |
|---|---|---|
| Residencia | Total control | Depende de región |
| Capex | Alto (GPUs, infra) | Bajo |
| Opex | Energía, mantenimiento | Por token |
| Modelo top-tier | Difícil (quantization, latencia) | GPT-4.5, Claude 4.5 fácil |
| Updates | Manual | Automático |
| Compliance strict | Más fácil (nada sale) | Depende de DPA/BAA |
| Latencia | Baja intra-red | Red pública |

Patrón híbrido común: **modelo pequeño on-prem** para redacción, clasificación y rutas sensibles; **cloud API** para tareas no sensibles con prompts ya redactados.

### Propiedad intelectual

Dos preguntas abiertas con jurisprudencia en evolución:

#### 1. Training data provenance (¿puede el modelo aprender de tus datos?)

Casos legales en curso:

- **Getty Images vs. Stability AI (2023, UK/EU/US).** Getty demandó por scraping de 12 millones de imágenes con marca de agua. Juicio UK sentencia parcial 2024-2025.
- **New York Times vs. OpenAI & Microsoft (dic 2023, US).** NYT alega entrenamiento sobre millones de artículos protegidos y output que regurgita texto literal. Juicio en 2025-2026.
- **Authors Guild vs. OpenAI, Meta (2023-2024).** Grupos de autores (Grisham, Martin) por entrenamiento sobre libros.
- **Thomson Reuters vs. ROSS Intelligence (fallo feb 2025).** Primera decisión US sustantiva contra "fair use" en entrenamiento comercial.
- **Andersen vs. Stability AI (US).** Artistas demandan por derivación de estilos.

Impacto práctico: hasta que haya jurisprudencia firme, los enterprise contracts suelen incluir **IP indemnification** (Microsoft Copilot Copyright Commitment, Google Shielded AI, Anthropic IP indemnity) donde el vendor asume la defensa legal si el output infringe copyright.

#### 2. Output ownership (¿de quién es el código/texto generado?)

- **US Copyright Office (2023-2024):** las obras generadas puramente por IA no son copyrightables. Solo lo son las contribuciones humanas significativas.
- **UK:** permite copyright a "computer-generated works" (CDPA s. 9(3)), con autor el humano que hizo los arreglos.
- **UE:** sin armonización; mayoría de estados requiere autoría humana.

Consecuencia para equipos: código generado por Copilot/Cursor sin edición significativa puede **no estar protegido** por copyright en US, aunque sea tuyo contractualmente ("you own what you create" en Copilot ToS).

#### 3. Code licensing con Copilot

El **Business Source License** y **GPL** generan problemas: si Copilot aprendió de código GPL y regurgita snippets casi idénticos, tu producto podría estar derivando de GPL sin cumplir. GitHub introdujo:

- **Duplication detection filter** (reduce output copiado literal de training set público).
- **Copilot Copyright Commitment** para Business/Enterprise: Microsoft defiende y paga daños si demandan al cliente por el output de Copilot usado con los filtros activos.

### Checklist de compliance mínimo

- ¿Firmaste **DPA** con todos los procesadores (vendor LLM incluido)?
- ¿Firmaste **BAA** con cada vendor que ve PHI?
- ¿**ZDR** activo o explícitamente aceptas el default retention?
- ¿**Región** del endpoint cumple residencia (EU para UE, etc.)?
- ¿Mecanismo de **DSAR** operativo y testeado?
- ¿**DPIA** (GDPR Art. 35) hecha para casos de alto riesgo?
- ¿**Transparencia** AI Act Art. 50 implementada (declarar que es IA)?
- ¿**IP indemnity** del vendor cubre tu caso de uso?

## ¿Cómo funciona?

### Policy as code

Expresar reglas de compliance como código ejecutable permite testearlas y aplicarlas en runtime:

```yaml
policies:
  - name: eu_residency
    when: data.classification in [confidential, restricted]
       and user.region == "EU"
    enforce: route_to(region="eu-west-1", provider="azure_openai")

  - name: no_phi_without_baa
    when: contains_phi(prompt)
    enforce: require(vendor.has_baa == true)

  - name: ai_act_transparency
    when: output_consumer_facing == true
    enforce: inject_disclosure("Este contenido fue generado por IA")

  - name: training_opt_out
    enforce: send_header("x-training-opt-out: true")
```

## Ejemplo con código

### Gateway con enforcement de policies

```python
# pip install anthropic
import os, re
from anthropic import Anthropic

cliente_eu = Anthropic(api_key=os.environ["ANTHROPIC_EU_KEY"])  # endpoint EU
cliente_us = Anthropic(api_key=os.environ["ANTHROPIC_US_KEY"])

PATRONES_PHI = [r"\bpatient\b", r"\bdiagnos", r"\bICD-10\b", r"\bHbA1c\b"]

class ComplianceError(Exception): pass

def contiene_phi(texto: str) -> bool:
    return any(re.search(p, texto, re.I) for p in PATRONES_PHI)

def gateway(prompt: str, usuario: dict, clasificacion: str) -> str:
    # 1. Residencia
    if usuario["region"] == "EU" and clasificacion in {"confidential",
                                                        "restricted"}:
        cliente = cliente_eu
    else:
        cliente = cliente_us

    # 2. BAA requerida si PHI
    if contiene_phi(prompt) and not usuario.get("baa_signed"):
        raise ComplianceError("PHI sin BAA — ruta prohibida")

    # 3. ZDR siempre on para datos regulados
    headers = {}
    if clasificacion in {"confidential", "restricted"}:
        headers["anthropic-beta"] = "zero-data-retention"

    # 4. AI Act transparency: inyectar disclosure si es customer-facing
    if usuario.get("output_customer_facing"):
        prompt += ("\n\nIMPORTANTE: Si tu respuesta será mostrada "
                   "al usuario final, iníciala con 'Respuesta generada "
                   "por IA:'.")

    resp = cliente.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
        extra_headers=headers,
    )
    return resp.content[0].text
```

### Test de compliance en CI

```python
import pytest

def test_phi_sin_baa_rechaza():
    with pytest.raises(ComplianceError):
        gateway("patient John has diagnosis of type 2 diabetes",
                usuario={"region": "US", "baa_signed": False},
                clasificacion="restricted")

def test_eu_user_va_a_eu_endpoint(monkeypatch):
    rutas = []
    monkeypatch.setattr("tu_modulo.cliente_eu",
                        type("C", (), {"messages": type("M", (), {
                            "create": lambda **kw: rutas.append("eu") or
                                     type("R", (), {"content":[
                                         type("B", (), {"text":"ok"})()]})()
                        })()})())
    gateway("código propietario", {"region":"EU"}, "confidential")
    assert rutas == ["eu"]

def test_zdr_header_en_restricted(httpx_mock):
    # mockear request y verificar header
    ...
```

### Clase para gestión de proveedores y DPAs

```python
from dataclasses import dataclass
from datetime import date

@dataclass
class VendorContract:
    name: str
    dpa_signed: bool
    baa_signed: bool
    zdr_available: bool
    regions: list[str]
    ip_indemnity: bool
    sccs_signed: bool
    expiry: date

VENDORS = {
    "anthropic": VendorContract("Anthropic", True, True, True,
                                  ["us-east-1","eu-west-1"],
                                  True, True, date(2026,12,31)),
    "openai":    VendorContract("OpenAI Enterprise", True, True, True,
                                  ["us","eu-dublin"],
                                  True, True, date(2026,6,30)),
    "azure_oai": VendorContract("Azure OpenAI", True, True, True,
                                  ["eastus","westeurope","swedencentral"],
                                  True, True, date(2027,1,1)),
}

def seleccionar_vendor(data_type: str, region: str) -> str:
    for nombre, v in VENDORS.items():
        if region not in v.regions:
            continue
        if data_type == "phi" and not v.baa_signed:
            continue
        if data_type == "eu_pii" and not (v.dpa_signed and v.sccs_signed):
            continue
        if not v.zdr_available:
            continue
        return nombre
    raise ComplianceError(f"Sin vendor válido para {data_type} en {region}")
```

### Herramientas de ecosistema

| Herramienta | Función |
|---|---|
| **OneTrust / TrustArc** | Gestión de consentimientos, DSAR, DPIA |
| **BigID / Securiti** | Discovery de PII en data lakes y prompts |
| **Snorkel Flow** | Weak supervision + redaction programática |
| **Lakera Guard** | Prompt injection + PII en runtime |
| **Private AI** | NER multilingüe para redaction |
| **Protect AI** | Model risk management, MLBOM |
| **Opal / Styra OPA** | Policy as code (Rego) para enforcement |

## Errores comunes

- **Tratar compliance como asunto legal.** Si el equipo de ingeniería no implementa los controles, los acuerdos quedan en el papel. Convierte cada obligación en user story y testéala en CI.
- **No firmar DPA con el proveedor.** Procesar PII UE vía API sin DPA Art. 28 es violación aunque el vendor sea técnicamente seguro.
- **Confundir "no entrena con mis datos" con "no retiene".** OpenAI API no entrena por default pero sí retiene 30 días para abuse monitoring; para ZDR debes solicitarlo.
- **Usar ChatGPT Free/Plus para datos de clientes.** Esos tiers entrenan con tus prompts salvo opt-out explícito. Jamás para datos regulados.
- **Olvidar la residencia.** Un prompt con PII de ciudadano UE enviado a `api.openai.com` (us-east) sin SCCs es transferencia internacional ilegal.
- **No BAA con vendor LLM procesando PHI.** HIPAA exige BAA con cada business associate; sin él, exposición a fines OCR de hasta 1.9M USD anuales por violación.
- **No considerar licencia upstream del código generado.** Si Copilot genera un snippet derivado de GPL y lo usas en producto propietario, puede obligarte a liberar el producto bajo GPL.
- **Asumir ownership del output automáticamente.** El US Copyright Office exige autoría humana significativa; el output puro de IA no es copyrightable en US.
- **Ignorar derivatives y fine-tunes.** Fine-tunear Llama con datos propietarios y luego publicarlo puede filtrar esos datos vía membership inference attacks.
- **No DPIA para alto riesgo.** GDPR Art. 35 exige Data Protection Impact Assessment para sistemas de IA que procesan datos sensibles a gran escala; sin ella, violación procedimental.
- **No cumplir transparency AI Act Art. 50.** Chatbots customer-facing deben declarar que son IA; sanción hasta 15M EUR o 3% facturación.
- **Vendor único.** Depender de un solo proveedor sin plan B deja el servicio expuesto a cambios de ToS, outages regulatorios o decisiones adversas de corte.
- **No monitorear jurisprudencia.** Casos como NYT vs OpenAI o Thomson Reuters vs ROSS cambian el panorama IP; revisa trimestralmente.

## Resumen

- **Compliance = ingeniería**, no papeleo: cada obligación (GDPR, HIPAA, CCPA, EU AI Act, PCI-DSS) se traduce a controles técnicos verificables (redacción, retención, cifrado, residencia, DSAR).
- **GDPR (2018)**: DPA Art. 28, DSAR Art. 15/17, DPIA Art. 35 para alto riesgo, Art. 22 para decisiones automatizadas. **HIPAA**: BAA con cada procesador de PHI. **EU AI Act (2024)**: clasifica por riesgo; Art. 10 data governance; Art. 50 transparency.
- **Zero-Data-Retention (ZDR)**: Anthropic Enterprise lo activa por default; OpenAI, Azure OpenAI, AWS Bedrock, Google Vertex ofrecen opción. **Nunca es automático**: requiere contrato y configuración.
- **APIs enterprise no entrenan con tus datos**; chats consumer (Free/Plus) sí a menos que optes por salirte. Reglas distintas.
- **Residencia**: Transferencia UE→US requiere SCCs o EU-US Data Privacy Framework; usa endpoints regionales (Azure OAI EU, Bedrock eu-central-1) para datos regulados.
- **On-prem vs cloud**: patrón híbrido común — modelo pequeño local para redacción y rutas sensibles, cloud API para tareas no sensibles con prompts limpios.
- **IP training**: casos abiertos — **NYT vs OpenAI (2023)**, **Getty vs Stability (2023)**, **Thomson Reuters vs ROSS (fallo 2025)**, **Authors Guild**. Hasta jurisprudencia firme, apóyate en **IP indemnity** del vendor (Microsoft Copyright Commitment, Google Shielded AI, Anthropic indemnity).
- **Output ownership**: US Copyright Office requiere autoría humana significativa; output puro de IA no es copyrightable. UK sí permite via CDPA s. 9(3).
- **Copilot y licensing**: filtro de duplicación y Copyright Commitment reducen (no eliminan) riesgo de derivar de código GPL/BSL.
- **Policy as code** (OPA/Rego, YAML enforcement) convierte compliance en algo testeable en CI; test de compliance = test de software.
- **Checklist mínimo**: DPA + BAA + ZDR + región + DSAR operativo + DPIA + transparency + IP indemnity del vendor. Si falta cualquiera, no estás listo para producción con datos regulados.
