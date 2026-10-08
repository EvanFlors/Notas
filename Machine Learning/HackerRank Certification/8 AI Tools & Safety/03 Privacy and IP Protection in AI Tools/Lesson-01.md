# Flujos de datos y rutas de fuga en herramientas de IA

## ¿Qué es?

Las **herramientas de IA** (asistentes de código, copilotos, agentes autónomos, chatbots internos) no solo ven el texto que les pegas. Ven **contexto implícito**: archivos abiertos, logs recientes, variables de entorno, metadatos del repositorio, tickets de Jira enlazados, respuestas de APIs intermedias y, en algunos casos, el historial completo de la conversación. Cada uno de esos puntos es una **ruta de fuga potencial** de información sensible.

La **privacidad en herramientas de IA** es la disciplina de **mapear, controlar y auditar** los flujos de datos que atraviesan estas herramientas, con el objetivo de evitar que información regulada (PII, PHI, PCI), secretos (API keys, tokens) o IP propietaria (código fuente, arquitectura) escapen del perímetro autorizado.

> **Definición operativa:** si un dato sale de tu sistema hacia un modelo que no controlas (API externa, SaaS, modelo público) o se almacena en un lugar donde no puedes garantizar su retención y acceso, entonces ese dato ha **cruzado el límite de confianza** y debe tratarse bajo política.

### PII, PHI y PCI: los tres grandes

| Categoría | Qué incluye | Regulación principal | Ejemplos típicos en prompts |
|---|---|---|---|
| **PII** (Personal Identifiable Information) | Nombre, email, teléfono, dirección, IP, cookie IDs, geolocalización | GDPR, CCPA, LGPD | Logs con `user_id=juan@acme.com`, stack traces con direcciones |
| **PHI** (Protected Health Information) | Diagnósticos, historiales médicos, fotos clínicas, resultados de laboratorio | HIPAA (EE.UU.), GDPR Art. 9 | Debug de app de telemedicina con `patient_name` en el payload |
| **PCI** (Payment Card Industry) | PAN (número de tarjeta), CVV, fecha de expiración, nombre del titular | PCI-DSS v4.0 | Logs de pasarela de pago con `card_number=4111...` |

Las tres categorías comparten una propiedad crítica: **basta un solo registro** en un prompt para que la herramienta de IA se convierta en un **procesador de datos** bajo la regulación, lo que activa obligaciones contractuales (DPA), de retención y de derechos del titular.

### Tres rutas de fuga canónicas

```
┌─────────────────────────────────────────────────────────────────┐
│                     USUARIO / DESARROLLADOR                      │
└───────────────────────────┬─────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
   1. PROMPT CONTENT   2. CONTEXT          3. TELEMETRY
      (lo que pegas)     RETRIEVAL           (métricas,
                         (lo que la          logs, traces)
                          herramienta lee
                          automáticamente)
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ▼
                   ┌─────────────────┐
                   │  LLM / Vendor   │
                   │  (OpenAI, etc.) │
                   └────────┬────────┘
                            ▼
                   ┌─────────────────┐
                   │  Training data? │
                   │  Logs? Cache?   │
                   └─────────────────┘
```

- **Prompt content:** lo más obvio. Un desarrollador pega un stack trace que contiene `customer_email=ana@gmail.com`.
- **Context retrieval:** menos visible. El asistente lee automáticamente `.env`, `settings.py`, `README`, los últimos 10 archivos abiertos. Un `OPENAI_API_KEY=sk-...` se envía sin que nadie lo haya escrito en el prompt.
- **Telemetry:** invisible. La herramienta envía métricas de uso (`prompt_length`, `latency`, error traces) que incluyen fragmentos del prompt original.

## ¿Por qué importa?

El escándalo de **Samsung en 2023** es el caso de estudio canónico: tres ingenieros pegaron código propietario de semiconductores en ChatGPT para depurarlo. OpenAI retenía los prompts por defecto para entrenamiento. Resultado: Samsung prohibió ChatGPT en toda la compañía y escribió su propio LLM interno. La fuga no fue por hackeo; fue por **uso normal de una herramienta útil sin entender el flujo de datos**.

Casos similares desde 2023:
- **JPMorgan, Apple, Verizon, Amazon:** prohibiciones corporativas de ChatGPT por el mismo riesgo.
- **Air Canada (2024):** un chatbot inventó una política de reembolso y el tribunal canadiense obligó a la aerolínea a cumplirla (riesgo de output, no de input).
- **Cursor leak (2024):** varios desarrolladores reportaron que prompts con código propietario aparecían como sugerencias para otros usuarios por un bug de aislamiento de contexto.

### El costo real

| Tipo de fuga | Costo típico | Mecanismo |
|---|---|---|
| Multa GDPR | Hasta 4% facturación global o 20M EUR | Procesar PII sin base legal o DPA |
| Multa HIPAA | USD 100 a 1.9M por violación anual | Enviar PHI a un procesador no cubierto por BAA |
| PCI-DSS fine | USD 5,000 a 100,000 mensuales | Logs con PAN sin tokenización |
| Pérdida de IP | Incalculable | Código entrenado dentro del modelo del proveedor |
| Reputación | Alto, difuso | Portada de prensa, pérdida de clientes B2B |

### Zonas de confianza

| Zona | Ejemplos | Qué datos tolera |
|---|---|---|
| **Local / on-prem** | Ollama en laptop, LLM self-hosted en Kubernetes privado | Confidencial, incluso restringido con cifrado |
| **Cloud dedicado** | Azure OpenAI con VNet, AWS Bedrock private endpoint | Confidencial; restringido si hay DPA + BAA |
| **SaaS enterprise** | Anthropic Enterprise, OpenAI Enterprise, Gemini for Workspace | Confidencial con ZDR firmado |
| **SaaS consumer** | ChatGPT free, Claude.ai free, Copilot personal | Solo público. **Nunca** restringido |

## ¿Cómo funciona?

### Construir un data map en una hora

El punto de partida de cualquier programa de privacidad para IA es un **mapa de datos** que responde cuatro preguntas por cada herramienta:

1. **Qué envía el desarrollador** (prompts, archivos adjuntos, screenshots).
2. **Qué recupera la herramienta automáticamente** (contexto del IDE, workspace, variables de entorno).
3. **Qué almacena el proveedor y por cuánto tiempo** (prompts, outputs, telemetría, caches).
4. **Quién puede acceder a ese almacenamiento** (empleados del vendor, otros tenants, auditores internos).

### Tabla de inventario de herramientas

| Herramienta | Owner | Fuentes de datos | Sinks | Retención | Residencia | Nivel de riesgo |
|---|---|---|---|---|---|---|
| Copilot Business | DevEx | Repo abierto, archivos pinned | Sugerencias, telemetría | 0 días (prompts) | US / EU opt-in | Medio |
| ChatGPT Team | Marketing | Prompts manuales | OpenAI logs | 30 días con opt-out | US | Alto si pegas datos |
| Claude Enterprise | Legal | Prompts + archivos | Anthropic (ZDR disponible) | 0 días con ZDR | US / EU | Bajo con ZDR |
| Cursor | Dev | Repo completo si "privacy mode" off | OpenAI/Anthropic backend | Variable | US | Alto sin privacy mode |
| Ollama local | Ind. | Prompts del IDE | Disco local | Según config | Local | Bajo |

### Patrón enterprise: proxy redactor

En vez de permitir que cada desarrollador llame directo a la API del proveedor, se interpone un **proxy** que:

1. **Autentica** al usuario interno (SSO, mTLS).
2. **Redacta** PII/PHI/secretos antes de salir.
3. **Enruta** a la región correcta (GDPR → EU, HIPAA → BAA-covered region).
4. **Registra** una copia *sin* los datos sensibles para auditoría.
5. **Aplica rate limiting** y presupuesto por equipo.

```
Desarrollador ──► Proxy interno ──► Redactor ──► LLM provider
                     │                              │
                     ▼                              ▼
                 Audit log                    Response
                 (sin PII)                        │
                                                  ▼
                                             Post-filter
                                                  │
                                                  ▼
                                             Desarrollador
```

Este patrón es el estándar de facto en bancos, aseguradoras y empresas con cumplimiento regulatorio serio.

## Ejemplo con código

### Detección de PII con Microsoft Presidio

**Presidio** es la librería open-source de referencia (Microsoft) para detectar y anonimizar PII. Soporta reconocimiento basado en patrones regex, listas, modelos NLP (spaCy, transformers) y permite recognizers personalizados.

```python
# pip install presidio-analyzer presidio-anonymizer
# python -m spacy download en_core_web_lg

from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import OperatorConfig

analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

prompt_sucio = """
El cliente Ana García (ana.garcia@acme.com, tel +34 611 223 344,
DNI 12345678A) reporta un error 500 al pagar con tarjeta
4111-1111-1111-1111 el 2025-10-01. Su IP fue 192.168.1.42.
"""

# 1. Detectar entidades sensibles
resultados = analyzer.analyze(
    text=prompt_sucio,
    entities=["EMAIL_ADDRESS", "PHONE_NUMBER", "PERSON",
              "CREDIT_CARD", "IP_ADDRESS", "ES_NIF"],
    language="en",
)

for r in resultados:
    print(f"{r.entity_type:20} score={r.score:.2f}  "
          f"'{prompt_sucio[r.start:r.end]}'")

# 2. Anonimizar antes de enviar al LLM
operadores = {
    "EMAIL_ADDRESS": OperatorConfig("replace", {"new_value": "<EMAIL>"}),
    "PHONE_NUMBER":  OperatorConfig("replace", {"new_value": "<PHONE>"}),
    "PERSON":        OperatorConfig("replace", {"new_value": "<PERSON>"}),
    "CREDIT_CARD":   OperatorConfig("mask",
                                     {"masking_char": "*",
                                      "chars_to_mask": 12,
                                      "from_end": False}),
    "IP_ADDRESS":    OperatorConfig("hash"),
    "ES_NIF":        OperatorConfig("replace", {"new_value": "<DNI>"}),
}

limpio = anonymizer.anonymize(
    text=prompt_sucio,
    analyzer_results=resultados,
    operators=operadores,
).text

print("\n=== Prompt listo para el LLM ===")
print(limpio)
```

Salida esperada:

```
EMAIL_ADDRESS        score=1.00  'ana.garcia@acme.com'
PHONE_NUMBER         score=0.75  '+34 611 223 344'
PERSON               score=0.85  'Ana García'
CREDIT_CARD          score=1.00  '4111-1111-1111-1111'
IP_ADDRESS           score=0.95  '192.168.1.42'

=== Prompt listo para el LLM ===
El cliente <PERSON> (<EMAIL>, tel <PHONE>, DNI <DNI>)
reporta un error 500 al pagar con tarjeta ************1111
el 2025-10-01. Su IP fue 7f3d9a....
```

### Proxy minimal que redacta antes de llamar al LLM

```python
import os
import httpx
from anthropic import Anthropic

cliente = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

def llm_seguro(prompt_usuario: str, modelo: str = "claude-sonnet-4-5") -> str:
    # Paso 1: redactar
    resultados = analyzer.analyze(text=prompt_usuario, language="en",
                                   entities=["EMAIL_ADDRESS", "PHONE_NUMBER",
                                             "PERSON", "CREDIT_CARD",
                                             "US_SSN", "IBAN_CODE"])
    prompt_limpio = anonymizer.anonymize(
        text=prompt_usuario, analyzer_results=resultados).text

    # Paso 2: log de auditoría SIN el contenido crudo
    audit_log({
        "entidades_detectadas": [r.entity_type for r in resultados],
        "longitud_original": len(prompt_usuario),
        "longitud_limpia": len(prompt_limpio),
    })

    # Paso 3: llamar al proveedor
    msg = cliente.messages.create(
        model=modelo,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt_limpio}],
        extra_headers={"anthropic-beta": "zero-data-retention"},
    )
    return msg.content[0].text
```

### Fuentes alternativas y comerciales

| Herramienta | Tipo | Fortaleza |
|---|---|---|
| **Microsoft Presidio** | OSS | Extensible, multi-idioma, gratis |
| **AWS Comprehend PII** | SaaS | Integración nativa AWS, soporta documentos |
| **Google Cloud DLP** | SaaS | 150+ infoTypes, deidentification jobs |
| **Lakera Guard** | SaaS | Prompt injection + PII en tiempo real |
| **Private AI** | SaaS/on-prem | NER multiidioma de alta precisión |
| **Snorkel Flow** | SaaS | Etiquetado programático + redaction |

## Errores comunes

- **Confundir "interno" con "seguro".** Un asistente desplegado en tu VPC puede seguir enviando telemetría a la nube del proveedor. Verifica flags como `telemetry.enabled=false` y revisa el tráfico de salida con un network policy.
- **Logs con PII sin redacción.** El clásico: `logger.info(f"User {email} did X")`. En cuanto esos logs llegan a un asistente de observabilidad (Datadog AI, Grafana AI), la PII cruza al proveedor. Redacta en el **sink**, no solo en el visualizador.
- **No firmar DPA (Data Processing Agreement) con el proveedor.** Sin DPA, procesar PII de ciudadanos UE a través de OpenAI/Anthropic te deja fuera de GDPR Art. 28, aunque el vendor cumpla técnicamente. Es un problema contractual, no técnico.
- **Usar un modelo público (ChatGPT free, Claude.ai free) para datos regulados.** Esos planes **no ofrecen** ZDR ni BAA. Son para datos públicos únicamente.
- **No encriptación at-rest** en los caches de respuestas. Un LLM gateway que cachea prompts en Redis sin cifrar es un honeypot de PII.
- **No retention policy.** "Guardar todo por si acaso" convierte un asistente útil en un lago de PII tóxico. Define TTL desde el día 1.
- **Context retrieval ciego.** Un agente que lee todo tu workspace `~/dev/` sin lista blanca va a leer tu `.env`, tu `~/.ssh/`, tu `~/.aws/credentials`. Usa allowlists explícitas.
- **Telemetría de errores que incluye el prompt.** Sentry y similares capturan `locals()` por defecto. Si el prompt está en una variable local, va a Sentry.
- **Confundir cifrado en tránsito con confidencialidad.** HTTPS protege contra sniffers de red, no contra el vendor que opera el endpoint.
- **Pegar screenshots.** Los OCR modernos extraen PII perfectamente de capturas de pantalla. Son prompts también.

## Resumen

- Las herramientas de IA tienen **tres rutas de fuga canónicas**: prompt content, context retrieval y telemetría. Mapéalas antes de desplegar.
- **PII, PHI y PCI** activan obligaciones legales (GDPR, HIPAA, PCI-DSS) en cuanto cruzan el límite de confianza; una sola fuga puede desencadenar auditoría y multa.
- Construye un **data map** con 4 preguntas: qué envía el usuario, qué recupera la herramienta, qué guarda el proveedor y quién tiene acceso.
- Diferencia **zonas de confianza**: local → cloud dedicado → SaaS enterprise con ZDR → SaaS consumer (jamás para datos regulados).
- El **patrón proxy redactor** es el estándar enterprise: un intermediario autentica, redacta, enruta, audita y filtra antes y después del LLM.
- **Microsoft Presidio** es el punto de entrada OSS más común para detección y anonimización de PII; alternativas comerciales son AWS Comprehend PII, Google Cloud DLP, Lakera y Private AI.
- Firma **DPA** con cada proveedor que procese PII; sin él, estás fuera de GDPR Art. 28 aunque la implementación técnica sea impecable.
- **Nunca** uses tiers consumer (ChatGPT free, Claude.ai free, Copilot personal) para datos confidenciales o regulados: no ofrecen ZDR, BAA, ni residencia.
- Casos reales (Samsung 2023, prohibiciones en JPMorgan/Apple/Verizon) muestran que la fuga por **uso normal** es más común que el hackeo externo.
- Si no sabes dónde va el dato cuando lo pegas en un prompt, **no lo pegues**; mapea primero, usa después.
