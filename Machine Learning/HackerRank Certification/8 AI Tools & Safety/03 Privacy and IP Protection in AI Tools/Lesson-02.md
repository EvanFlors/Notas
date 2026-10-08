# Clasificación de datos y pipelines de redacción

## ¿Qué es?

**Clasificación de datos** es el proceso de etiquetar cada activo (archivo, log, campo de base de datos, prompt) con un nivel de sensibilidad que determina **qué controles** aplican. **Redacción** es la implementación técnica de esa política: antes de que un dato cruce al LLM, los campos sensibles se reemplazan por placeholders, hashes o tokens.

La fórmula operativa es simple:

> **Política vaga ("no compartas datos sensibles") → fuga.
> Clasificación + redacción determinística → control automático que no depende del juicio humano bajo presión.**

### Esquema mínimo de clasificación

| Nivel | Qué incluye | Reglas con herramientas de IA |
|---|---|---|
| **Public** | Documentación pública, código open source, ejemplos | Sin restricción |
| **Internal** | Documentación interna, código no sensible, discusiones generales | Herramientas con DPA, redacción light |
| **Confidential** | Código propietario, decisiones de arquitectura, roadmap, datos de negocio | Herramientas enterprise con ZDR, redacción de PII |
| **Restricted** | Secretos, credenciales, PII, PHI, PCI, datos regulados | Prohibido en prompts; redacción obligatoria o bloqueo |

### Dónde se esconden los datos sensibles

Los datos sensibles rara vez están donde "deberían". En flujos de desarrollo típicos aparecen en:

- **Headers de request** en logs (`Authorization: Bearer eyJ...`, cookies de sesión).
- **Config files** con tokens embebidos (`.env`, `settings.yaml`, `kubeconfig`).
- **Stack traces** que incluyen identificadores (`user_id=12345`, `email=ana@acme.com` en el mensaje de error).
- **Datasets de test** que son copias de producción sin anonimizar.
- **Tickets de soporte** con capturas de pantalla y conversaciones con clientes.
- **Historial de prompts** en el propio asistente de IA.

## ¿Por qué importa?

La diferencia entre una política escrita y un control efectivo es la **determinación**. Un reglamento que dice "no envíes PII al LLM" transfiere la responsabilidad al desarrollador en el momento más vulnerable: cuando está apurado, debuggeando a las 3am. Un pipeline de redacción determinístico, en cambio, **no permite** que el dato salga, independientemente del juicio humano.

### Redacción como control de calidad, no solo de seguridad

Un segundo motivo, menos obvio: **los LLMs producen mejores respuestas con prompts limpios**. Un prompt que incluye 2 KB de API keys, UUIDs y timestamps irrelevantes distrae al modelo. Redactar los datos sensibles reemplazándolos por `<EMAIL>`, `<API_KEY>` o `<USER_ID>` mejora la señal/ruido y suele subir la precisión del output.

### El costo de no clasificar

| Síntoma | Causa raíz | Consecuencia |
|---|---|---|
| "No supimos que era sensible" | Falta de clasificación | Fuga sin ownership claro |
| "El tool lo leyó solo" | Context retrieval sin allowlist | Secretos en logs del vendor |
| "Lo redactamos manualmente" | Sin automatización | Inconsistencia + fatiga |
| "Pasó el test, falló en prod" | Sin regresión de redacción | Fuga silenciosa |

## ¿Cómo funciona?

### Operacionalizar clasificación en el repositorio

Una técnica concreta es **etiquetar carpetas** con convenciones y hacerlas enforceables desde el tooling:

```
my-repo/
├── public/              # Nivel Public — safe to share
├── docs/                # Internal
├── src/                 # Confidential (código propietario)
├── restricted/          # Restricted — bloqueado para IA
│   ├── secrets/
│   ├── pii-samples/
│   └── patient-data/
└── .data-classification.yaml
```

El archivo `.data-classification.yaml` es leído por el proxy de IA, el pre-commit hook y el CI:

```yaml
classifications:
  public:    [public/**, examples/**]
  internal:  [docs/**, tests/**]
  confidential: [src/**, architecture/**]
  restricted: [restricted/**, secrets/**, "**/.env*", "**/*.pem"]

ai_tool_rules:
  restricted: block
  confidential: require_redaction
  internal: redact_pii
  public: allow
```

### Pipeline de redacción determinístico

Las cuatro etapas de un pipeline sólido son:

1. **Pattern detection**: regex y reconocedores NLP para patrones comunes (emails, PAN, SSN, tokens).
2. **Context filters**: evitar falsos positivos (una cadena que parece API key puede ser un fixture).
3. **Masking rules**: reemplazar por placeholder legible, hash o token reversible.
4. **Audit log**: registrar qué se redactó, dónde y cuándo (sin registrar el contenido crudo).

## Ejemplo con código

### Pipeline completo con Presidio + hashing + cifrado

```python
# pip install presidio-analyzer presidio-anonymizer cryptography

import hashlib
import json
import logging
from datetime import datetime
from pathlib import Path

from cryptography.fernet import Fernet
from presidio_analyzer import AnalyzerEngine, PatternRecognizer, Pattern
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import OperatorConfig

# ---------------------------------------------------------------
# 1. Configurar analyzer con recognizers custom
# ---------------------------------------------------------------
analyzer = AnalyzerEngine()

# Recognizer custom: tokens internos tipo "acme_tok_...."
acme_token = PatternRecognizer(
    supported_entity="ACME_TOKEN",
    patterns=[Pattern(name="acme_tok", regex=r"acme_tok_[A-Za-z0-9]{32}",
                      score=0.95)],
)
analyzer.registry.add_recognizer(acme_token)

anonymizer = AnonymizerEngine()

# ---------------------------------------------------------------
# 2. Reglas de masking por tipo
# ---------------------------------------------------------------
OPERADORES = {
    "EMAIL_ADDRESS": OperatorConfig("replace", {"new_value": "<EMAIL>"}),
    "PERSON":        OperatorConfig("replace", {"new_value": "<PERSON>"}),
    "PHONE_NUMBER":  OperatorConfig("replace", {"new_value": "<PHONE>"}),
    "CREDIT_CARD":   OperatorConfig("mask", {"masking_char": "*",
                                              "chars_to_mask": 12,
                                              "from_end": False}),
    "US_SSN":        OperatorConfig("replace", {"new_value": "<SSN>"}),
    "IBAN_CODE":     OperatorConfig("hash"),
    "IP_ADDRESS":    OperatorConfig("hash"),
    "ACME_TOKEN":    OperatorConfig("replace", {"new_value": "<ACME_TOKEN>"}),
}

ENTIDADES = list(OPERADORES.keys())

# ---------------------------------------------------------------
# 3. Cifrado at-rest con Fernet (symmetric AES-128-CBC + HMAC)
# ---------------------------------------------------------------
# En producción: la clave vive en KMS (AWS KMS, GCP KMS, Vault)
LLAVE = Fernet.generate_key()
fernet = Fernet(LLAVE)

def cifrar(texto: str) -> bytes:
    return fernet.encrypt(texto.encode("utf-8"))

def descifrar(token: bytes) -> str:
    return fernet.decrypt(token).decode("utf-8")

# ---------------------------------------------------------------
# 4. Audit log con hash del input crudo (no el crudo)
# ---------------------------------------------------------------
AUDIT_LOG = Path("/var/log/ai-proxy/audit.jsonl")

def audit(entry: dict) -> None:
    entry["ts"] = datetime.utcnow().isoformat() + "Z"
    AUDIT_LOG.parent.mkdir(parents=True, exist_ok=True)
    with AUDIT_LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")

# ---------------------------------------------------------------
# 5. Pipeline principal
# ---------------------------------------------------------------
def redactar_para_llm(prompt: str, user_id: str,
                      clasificacion: str = "confidential") -> str:
    if clasificacion == "restricted":
        raise PermissionError("Datos restricted bloqueados para herramientas IA")

    # Hash del original (para correlación forense sin exponer PII)
    hash_input = hashlib.sha256(prompt.encode()).hexdigest()

    resultados = analyzer.analyze(text=prompt, language="en",
                                   entities=ENTIDADES)

    limpio = anonymizer.anonymize(text=prompt,
                                   analyzer_results=resultados,
                                   operators=OPERADORES).text

    audit({
        "user_id": user_id,
        "input_sha256": hash_input,
        "input_len": len(prompt),
        "output_len": len(limpio),
        "entidades": {r.entity_type: 0 for r in resultados} and
                     {r.entity_type:
                      sum(1 for x in resultados if x.entity_type == r.entity_type)
                      for r in resultados},
        "clasificacion": clasificacion,
    })

    # Guardar copia cifrada del output limpio por si hace falta auditar
    (AUDIT_LOG.parent / f"{hash_input}.enc").write_bytes(cifrar(limpio))

    return limpio

# ---------------------------------------------------------------
# 6. Uso
# ---------------------------------------------------------------
sucio = """
Ana García (ana.garcia@acme.com, +34 611 223 344) reporta error.
API key: acme_tok_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
Tarjeta usada: 4111 1111 1111 1111
"""

limpio = redactar_para_llm(sucio, user_id="eng_42",
                            clasificacion="confidential")
print(limpio)
# → <PERSON> (<EMAIL>, <PHONE>) reporta error.
#   API key: <ACME_TOKEN>
#   Tarjeta usada: ************1111
```

### Datos estructurados: redacción por campo

Cuando el input es JSON, la redacción por campo es más precisa que regex:

```python
import copy

CAMPOS_SENSIBLES = {
    "email", "phone", "ssn", "credit_card", "password",
    "api_key", "token", "patient_name", "diagnosis",
}

def redactar_json(obj, placeholder="<REDACTED>"):
    if isinstance(obj, dict):
        return {k: (placeholder if k.lower() in CAMPOS_SENSIBLES
                    else redactar_json(v, placeholder))
                for k, v in obj.items()}
    if isinstance(obj, list):
        return [redactar_json(x, placeholder) for x in obj]
    return obj

log = {"user_id": "12345", "email": "ana@acme.com",
       "action": "login", "ip": "10.0.0.1"}

print(redactar_json(log))
# → {'user_id': '12345', 'email': '<REDACTED>',
#     'action': 'login', 'ip': '10.0.0.1'}
```

### Tests de regresión

Redacción sin tests es redacción rota. Mínimo:

```python
import pytest

CASOS = [
    ("Mi email es ana@acme.com", "<EMAIL>", "EMAIL_ADDRESS"),
    ("SSN 123-45-6789", "<SSN>", "US_SSN"),
    ("acme_tok_" + "a"*32, "<ACME_TOKEN>", "ACME_TOKEN"),
    ("4111 1111 1111 1111", "************1111", "CREDIT_CARD"),
]

@pytest.mark.parametrize("entrada, esperado, entidad", CASOS)
def test_redaccion(entrada, esperado, entidad):
    salida = redactar_para_llm(entrada, user_id="test",
                                clasificacion="internal")
    assert esperado in salida
    assert entidad.lower() not in salida.lower() or esperado in salida

def test_restricted_bloqueado():
    with pytest.raises(PermissionError):
        redactar_para_llm("algo", user_id="x", clasificacion="restricted")
```

### Comparativa de herramientas

| Herramienta | Open source | Idiomas | Formatos | Recognizers custom |
|---|---|---|---|---|
| **Microsoft Presidio** | Sí | 30+ con transformers | Texto, imágenes (OCR), PDFs | Sí, Python |
| **AWS Comprehend PII** | No | 8 | Texto | Limitado (regex entities) |
| **Google Cloud DLP** | No | 50+ | Texto, imágenes, BQ, GCS | Sí, infoTypes custom |
| **Lakera Guard** | No | Multi | Texto streaming | Vía policies |
| **Private AI** | Freemium | 50+ | Texto, voz, docs | Sí |
| **Snorkel Flow** | No | — | Label functions programáticas | Núcleo del producto |

## Errores comunes

- **Reglas regex sin tests.** Un regex de credit card que ignora espacios funciona hasta que llega un `4111 1111 1111 1111`. Testea los formatos reales que ves en producción.
- **Over-redaction.** Si redactas tanto que el modelo pierde el contexto (`"<X> <Y> <Z> hizo <W>"`), degradas la calidad. Mantén estructura: usa placeholders con etiqueta (`<EMAIL>`, `<USER_ID>`) en lugar de borrar.
- **Redactar después de enviar.** Si el prompt ya salió al vendor, el daño está hecho. La redacción tiene que ocurrir **antes** del request HTTP, idealmente en un proxy a nivel red.
- **Logs con PII sin redacción.** El error más repetido: el pipeline redacta antes del LLM pero el `logger.info(prompt_original)` manda el crudo a Datadog/Splunk/CloudWatch. Audita todos los sinks.
- **No DPA con el proveedor.** La redacción técnica no sustituye el contrato. Si procesas PII, necesitas DPA aunque redactes.
- **Clasificación manual sin automatización.** Pedirle a los desarrolladores que etiqueten cada archivo falla. Usa convenciones de path, scanner de secretos (gitleaks, trufflehog) y defaults seguros.
- **Allowlist de "test tokens" demasiado permisiva.** `test_api_key = "sk-live-..."` deja pasar secretos reales. Prohíbe prefijos de producción incluso en tests.
- **No encryption at rest** en el cache del proxy o en el audit log. Un dump de Redis con prompts sin redactar es equivalente a la fuga original.
- **No retention policy** para los logs de redacción. Guardar "qué se redactó" durante años acumula metadatos que pueden ser reversibles por correlación.
- **Ignorar formatos nuevos** (nuevos tipos de token, nuevos infoTypes). Haz sampling audits mensuales de prompts reales para detectar drift.

## Resumen

- **Clasificación** convierte política vaga en reglas enforceables: Public, Internal, Confidential, Restricted. Define qué puede ir a qué herramienta.
- Los datos sensibles se esconden en **headers, configs, stack traces, test fixtures y tickets**: redacta en el **sink**, no solo en el visualizador.
- Un pipeline de **redacción determinístico** tiene cuatro etapas: detección por patrón, filtros contextuales, masking con placeholders legibles y audit log sin contenido crudo.
- **Microsoft Presidio** es el estándar OSS para PII; alternativas comerciales (AWS Comprehend, GCP DLP, Lakera, Private AI, Snorkel) añaden integraciones y precisión multilingüe.
- Combina **Presidio + Fernet** para cifrar at-rest cualquier copia del prompt que persistas (cache, audit, debugging).
- **Hashea el input crudo** (SHA-256) y guarda solo el hash en el audit log: permite correlación forense sin exponer PII.
- **Datos estructurados** (JSON, dict) permiten redacción por campo, más precisa que regex sobre texto plano.
- **Tests de regresión** son obligatorios: cada formato nuevo detectado en producción se convierte en caso de test.
- **Redacta antes del request**, nunca después; si el prompt ya salió, la política falló.
- **Over-redaction** degrada la utilidad del LLM: usa placeholders con etiqueta (`<EMAIL>`) para preservar estructura y mejorar la respuesta del modelo.
- La redacción es a la vez **control de seguridad y control de calidad**: prompts limpios producen outputs mejores.
