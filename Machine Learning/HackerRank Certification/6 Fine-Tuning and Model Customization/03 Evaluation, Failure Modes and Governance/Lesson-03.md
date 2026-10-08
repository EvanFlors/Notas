# Governance: model cards, licencias, EU AI Act y audit trails

## ¿Qué es?

La **governance de modelos** es el conjunto de prácticas, documentación y controles que hacen que un modelo fine-tuned sea **auditable, trazable y conforme** con las regulaciones aplicables. No es papeleo: es la infraestructura que te permite demostrar quién entrenó qué, con qué datos, bajo qué licencia, con qué evaluaciones y qué pasó con cada inferencia en producción.

Un sistema de governance mínimo cubre seis componentes:

| Componente | Pregunta que responde | Artefacto |
|---|---|---|
| **Model card** | ¿Qué es el modelo, para qué sirve, qué limitaciones tiene? | `MODEL_CARD.md` |
| **Data card** | ¿De dónde salen los datos, cómo se procesaron? | `DATA_CARD.md` |
| **License compliance** | ¿Puedo usarlo comercialmente? ¿Cumplo con la licencia? | Audit de dependencias |
| **Impact assessment** | ¿Qué riesgos tiene? ¿A quién afecta? | DPIA / AIA |
| **Audit log de inferencias** | ¿Qué respondió el modelo, cuándo, a quién? | Logs inmutables |
| **Red-teaming report** | ¿Qué pasa cuando lo atacan adversarialmente? | Reporte firmado |

### Model cards (Mitchell et al., 2019)

Documento estructurado que acompaña al modelo. Secciones estándar:

1. **Model details**: arquitectura, versión, autor, licencia, fecha.
2. **Intended use**: casos de uso previstos y **out-of-scope**.
3. **Factors**: subgrupos demográficos o contextos relevantes.
4. **Metrics**: desagregadas por factor.
5. **Evaluation data**: datasets de eval y cómo se eligieron.
6. **Training data**: fuente, tamaño, preprocesamiento.
7. **Ethical considerations**: sesgos, usos indebidos, riesgos.
8. **Caveats and recommendations**: lo que todavía no sabes.

HuggingFace ha estandarizado un template YAML + Markdown; cada modelo en el Hub tiene uno.

### Licenciamiento de modelos open

| Modelo | Licencia | Uso comercial | Restricciones clave |
|---|---|---|---|
| **Llama 3.1 / 3.2 / 3.3** | Llama Community License | Sí, salvo >700M MAU (requiere licencia Meta) | Prohibido entrenar otros LLMs; naming "Llama" obligatorio en derivados |
| **Llama 4** (2025) | Llama Community License v4 | Sí, con mismas condiciones | Attribution + redistribución bajo misma licencia |
| **Mistral 7B / Mixtral** | Apache 2.0 | Sí, sin restricciones | Attribution; sin uso del nombre Mistral para endorsement |
| **Mistral Large / Medium** | Mistral Research License (MRL) | **No** sin licencia comercial | Solo investigación y evaluación |
| **Qwen 2.5 / 3** | Apache 2.0 (la mayoría); Qwen License para >100M usuarios | Sí (con umbral) | Attribution |
| **Gemma 2 / 3** | Gemma Terms of Use (Google) | Sí | Prohibited Use Policy; redistribuir ToU |
| **Phi-3 / Phi-4** | MIT | Sí, sin restricciones | Attribution |
| **DeepSeek V3 / R1** | MIT (modelo) + licencia propia (uso) | Sí | Revisar términos de uso específicos |
| **Falcon** | Apache 2.0 | Sí | Attribution |
| **Command R / R+** | CC-BY-NC 4.0 | **No** (NonCommercial) | Solo research |

**Puntos ciegos frecuentes:**

- Un modelo con licencia permisiva (Apache, MIT) **no** garantiza que sus **datos de entrenamiento** sean de uso libre. Revisar también el *data card*.
- Fine-tunear Llama con datos generados por GPT-4 **viola** los TOS de OpenAI (prohíben usar sus outputs para entrenar modelos competidores).
- Redistribuir pesos de Llama requiere incluir la licencia completa y el **naming convention** ("Llama" en el nombre del derivado).
- **CC-BY-NC** (Non-Commercial) prohíbe cualquier uso comercial, incluso interno en una empresa con fines de lucro.

### Frameworks de governance

| Framework | Jurisdicción | Vigencia | Alcance |
|---|---|---|---|
| **EU AI Act** | Unión Europea | Agosto 2024 (vigor); feb 2025 (prohibiciones); agosto 2025 (GPAI); agosto 2026 (alto riesgo) | Cualquier sistema de IA usado o puesto en el mercado en la UE |
| **NIST AI RMF 1.0** | EE.UU. (voluntario, de facto obligatorio para contratos federales) | Enero 2023 | Govern, Map, Measure, Manage |
| **ISO/IEC 42001** | Internacional | 2023 | Sistema de gestión de IA (certificable) |
| **UK AI White Paper + AI Safety Institute** | Reino Unido | 2023+ | Approach pro-innovación, evaluaciones voluntarias |
| **China Interim Measures for Generative AI** | China | Agosto 2023 | Content review, security assessment, registration |
| **Anthropic Responsible Scaling Policy** | Interno | 2023+ | Niveles ASL para modelos frontier |
| **OpenAI Preparedness Framework** | Interno | 2023+ | Evaluaciones pre-deploy en cuatro dominios de riesgo |

### EU AI Act: lo que importa para fine-tuners

El reglamento clasifica sistemas en 4 niveles:

- **Riesgo inaceptable** (prohibido): social scoring, manipulación subliminal, categorización biométrica por raza.
- **Alto riesgo**: salud, educación, empleo, justicia, migración, infraestructura crítica. Requiere evaluación de conformidad, data governance, logging, supervisión humana.
- **Riesgo limitado**: chatbots, deepfakes → **obligación de transparencia** (informar que es IA).
- **Riesgo mínimo**: resto (filtro de spam, videojuegos).

**Para modelos de propósito general (GPAI)**, el art. 53 obliga a:

- Mantener documentación técnica del entrenamiento.
- Publicar un **resumen** de los datos de entrenamiento.
- Respetar derechos de autor (incluyendo opt-outs tipo `robots.txt`).
- Si FLOPs > 10²⁵: evaluaciones adversariales, reporte de incidentes serios al AI Office, ciberseguridad reforzada.

**Multas**: hasta 35M€ o 7% del volumen global.

## ¿Por qué importa?

### Riesgos operativos sin governance

| Riesgo | Ejemplo real | Mitigación |
|---|---|---|
| **Multa regulatoria** | GDPR: Clearview AI multada 20M€ (2022) por data scraping | DPIA + consent |
| **Litigio por licencia** | GitHub Copilot (2022): demanda colectiva por reproducir código GPL | Attribution + filtros |
| **Rollback por incidente** | Google Gemini (feb 2024): over-correction en generación de imágenes | Red-teaming pre-deploy |
| **Daño reputacional** | Air Canada chatbot (feb 2024): condenado a pagar por inventar política | Guardrails + logs |
| **Pérdida de contrato** | Vendor rechazado en RFP por no tener ISO 42001 o SOC 2 | Certificación |

### Beneficios de documentar

- **Reproducibilidad**: 6 meses después, puedes reentrenar el mismo modelo con los mismos datos.
- **Debugging**: cuando un cliente reporta una respuesta rara, el audit log te dice exactamente qué pasó.
- **Onboarding**: un nuevo miembro del equipo entiende el modelo en 1 hora en vez de 1 semana.
- **Due diligence**: en una adquisición o auditoría, tener model + data cards es un filtro.

## ¿Cómo funciona?

### Pipeline de governance de principio a fin

```
┌───────────────────────────────────────────────────────────────┐
│  (1) Data provenance                                          │
│      - DATA_CARD.md: fuentes, licencias, consentimiento       │
│      - Hash + versionado (DVC, LakeFS)                        │
├───────────────────────────────────────────────────────────────┤
│  (2) Training                                                 │
│      - Logging W&B: hyperparams, seed, código git-sha         │
│      - Checksums de pesos                                     │
├───────────────────────────────────────────────────────────────┤
│  (3) Evaluation + red-teaming                                 │
│      - Benchmarks, bias audit, safety eval                    │
│      - Red team report firmado                                │
├───────────────────────────────────────────────────────────────┤
│  (4) Model card                                               │
│      - MODEL_CARD.md en el repo del modelo                    │
│      - Published to HuggingFace Hub / internal registry       │
├───────────────────────────────────────────────────────────────┤
│  (5) Impact assessment                                        │
│      - DPIA (si procesa datos personales)                     │
│      - AI Impact Assessment (NIST AI RMF Measure/Manage)      │
├───────────────────────────────────────────────────────────────┤
│  (6) Deployment                                               │
│      - Audit log de cada inferencia (hash de prompt+output)   │
│      - Monitoring dashboard                                   │
├───────────────────────────────────────────────────────────────┤
│  (7) Incident response                                        │
│      - Runbook, oncall, postmortem template                   │
└───────────────────────────────────────────────────────────────┘
```

### Audit trail de inferencias

Cada request debería generar un registro inmutable con:

- `request_id` (UUID).
- `user_id` (hash si aplica).
- `prompt_hash` (SHA-256).
- `model_version` (git sha + checksum de pesos).
- `response_hash`.
- `latency_ms`, `tokens_in`, `tokens_out`.
- `safety_scores` (toxicidad, bias detectado).
- `timestamp` + `trace_id` (OpenTelemetry).

Almacenamiento recomendado: write-once (append-only) en S3 Object Lock, BigQuery con retention policy, o Loki/Elasticsearch con integridad verificable (hash chain estilo blockchain ligero).

### Red-teaming

Práctica importada del security: equipos adversariales intentan hacer que el modelo falle. **Perez et al. (2022)** y la **Anthropic Red Team methodology** son referencias. Vectores típicos:

- **Jailbreaks** (DAN, prompt injection, roleplay).
- **Extracción de datos** (membership inference, prompt-based leakage).
- **Sesgo** (BBQ, StereoSet, Winogender).
- **Toxicidad inducida** (RealToxicityPrompts, ToxiGen).
- **Capacidades peligrosas** (CBRN uplift, autonomous replication, cyber-offense).

El reporte firmado del red team es un artefacto obligatorio bajo EU AI Act para GPAI de riesgo sistémico.

### Herramientas de governance

| Herramienta | Propósito |
|---|---|
| **HuggingFace Model Cards** | Template y hosting público |
| **Model Card Toolkit (Google)** | Generación programática |
| **MLflow Model Registry** | Versionado, stages (staging/prod/archived) |
| **Weights & Biases Artifacts** | Versionado de datasets + modelos |
| **DVC / LakeFS** | Versionado de datos (git-like) |
| **Giskard** | Tests de sesgo, robustez y vulnerabilidad |
| **Fairlearn / AIF360** | Métricas y mitigación de fairness |
| **OpenTelemetry + Langfuse** | Observabilidad y audit trail para LLMs |
| **Credo AI / Fiddler** | Plataformas comerciales de AI governance |

## Ejemplo con código

### 1. Generar un model card estructurado

```python
# pip install model-card-toolkit huggingface_hub
from huggingface_hub import ModelCard, ModelCardData
from datetime import datetime

card_data = ModelCardData(
    language="es",
    license="llama3.1",
    base_model="meta-llama/Llama-3.1-8B-Instruct",
    tags=["customer-support", "lora", "fine-tuned", "spanish"],
    datasets=["internal/support-tickets-v3"],
    metrics=["accuracy", "f1", "rouge-l", "mmlu", "gsm8k"],
    model_name="support-chatbot-es-v1.2",
)

content = f"""
---
{card_data.to_yaml()}
---

# Support Chatbot ES v1.2

## Model details
- **Base model**: meta-llama/Llama-3.1-8B-Instruct
- **Fine-tuning**: QLoRA r=16, alpha=32, dropout=0.05
- **Trained on**: 2025-10-01 (git sha: 7f3a9b2)
- **Checksum (sha256)**: `9ab4...e1f2`
- **License**: Llama 3.1 Community (atención: límite 700M MAU)
- **Autor**: Equipo IA, support@empresa.com

## Intended use
- **Primary**: clasificación y respuesta a tickets de soporte en español (categorías: billing, shipping, product, technical).
- **Out of scope**: asesoría médica, legal o financiera; cualquier decisión automatizada con efecto jurídico (prohibido por EU AI Act art. 22 GDPR si no hay revisión humana).

## Factors
- Idioma: evaluado en es-MX, es-ES, es-AR.
- Tipo de cliente: B2C y B2B SMB.
- Canales: email, chat, formulario web.

## Metrics (eval set: 2000 tickets held-out)
| Métrica | Base | Fine-tuned | Δ |
|---|---|---|---|
| Accuracy (clasificación) | 0.74 | 0.91 | +0.17 |
| F1 macro | 0.68 | 0.88 | +0.20 |
| ROUGE-L (respuestas) | 0.31 | 0.47 | +0.16 |
| **MMLU** (regresión) | 0.682 | 0.671 | -0.011 |
| **GSM8K** (regresión) | 0.774 | 0.761 | -0.013 |
| **HumanEval** (regresión) | 0.591 | 0.584 | -0.007 |
| **TruthfulQA MC2** | 0.502 | 0.498 | -0.004 |

## Training data
- Fuente: tickets de soporte internos 2023-01 a 2025-06 (anonimizados).
- Volumen: 24,500 ejemplos (SFT) + 1,800 pares preferenciales (DPO).
- Preprocesamiento: PII removal (Presidio), deduplicación (MinHash), balanceo por categoría.
- Replay: 15% ejemplos generales de `tulu-v2-sft-mixture` para mitigar forgetting.
- Data card: `./DATA_CARD.md`.

## Ethical considerations
- **Bias audit**: gap de accuracy entre categorías < 4 pp (ver `./bias_report.json`).
- **Toxicidad** (Detoxify): 0.4% de outputs > 0.5 en score (umbral alertable: 2%).
- **Red-teaming**: reporte firmado el 2025-10-03 (ver `./redteam_v1.pdf`).
- **Riesgos conocidos**: puede alucinar números de factura si el ticket no da contexto.

## Caveats and recommendations
- Siempre revisar escalaciones a humano para refunds > $500.
- Monitorear drift cada 30 días; reentrenar si F1 cae > 3 pp.
- No desplegar sin DPIA aprobada por legal.
"""

ModelCard(content).save("./support-chatbot-es-v1.2/README.md")
```

### 2. Audit log de inferencias (append-only)

```python
import hashlib, json, time, uuid
from dataclasses import dataclass, asdict
from pathlib import Path

@dataclass
class InferenceRecord:
    request_id: str
    timestamp: float
    user_id_hash: str
    model_version: str
    model_sha: str
    prompt_sha: str
    response_sha: str
    tokens_in: int
    tokens_out: int
    latency_ms: int
    safety_scores: dict
    prev_hash: str          # hash del registro anterior -> hash chain

def sha(data: str) -> str:
    return hashlib.sha256(data.encode()).hexdigest()[:16]

class AuditLogger:
    def __init__(self, path: str = "./audit.log.jsonl"):
        self.path = Path(path)
        self.prev_hash = self._bootstrap_prev()

    def _bootstrap_prev(self) -> str:
        if not self.path.exists():
            return "GENESIS"
        last = self.path.read_text().strip().splitlines()[-1]
        return sha(last)

    def log(self, user_id, prompt, response, model_version,
            model_sha, latency_ms, safety_scores):
        rec = InferenceRecord(
            request_id    = str(uuid.uuid4()),
            timestamp     = time.time(),
            user_id_hash  = sha(user_id),
            model_version = model_version,
            model_sha     = model_sha,
            prompt_sha    = sha(prompt),
            response_sha  = sha(response),
            tokens_in     = len(prompt.split()),
            tokens_out    = len(response.split()),
            latency_ms    = latency_ms,
            safety_scores = safety_scores,
            prev_hash     = self.prev_hash,
        )
        line = json.dumps(asdict(rec))
        with self.path.open("a") as f:
            f.write(line + "\n")
        self.prev_hash = sha(line)
        return rec.request_id

def verify_chain(path: str) -> bool:
    prev = "GENESIS"
    for line in Path(path).read_text().strip().splitlines():
        rec = json.loads(line)
        if rec["prev_hash"] != prev:
            return False
        prev = sha(line)
    return True
```

### 3. Check de licencia (dependency audit)

```python
# Verifica que los modelos usados tengan licencias compatibles con uso comercial
import json
from huggingface_hub import HfApi

INCOMPATIBLE = {"cc-by-nc-4.0", "cc-by-nc-sa-4.0",
                "mistral-research-license", "openrail-m"}

def check_license(model_id: str) -> dict:
    api = HfApi()
    info = api.model_info(model_id)
    license = (info.card_data.license if info.card_data else "unknown")
    monthly_users = get_monthly_active_users()   # tu métrica interna

    issues = []
    if license in INCOMPATIBLE:
        issues.append(f"Licencia {license} NO permite uso comercial.")
    if "llama" in license and monthly_users > 700_000_000:
        issues.append("Llama License: >700M MAU requiere licencia Meta.")
    if license == "unknown":
        issues.append("Licencia no declarada en el model card.")
    return {"model": model_id, "license": license,
            "mau": monthly_users, "issues": issues}

for m in ["meta-llama/Llama-3.1-8B-Instruct",
          "mistralai/Mistral-7B-v0.1",
          "CohereForAI/c4ai-command-r-v01"]:
    print(json.dumps(check_license(m), indent=2))
```

### 4. Impact assessment template (AIA)

```python
AIA_TEMPLATE = """
# AI Impact Assessment — {model_name}

## 1. Sistema
- Propósito: {purpose}
- Decisión automatizada: {automated}  (Sí/No/Humano en el loop)
- Clasificación EU AI Act: {eu_class}  (prohibido / alto / limitado / mínimo)

## 2. Stakeholders afectados
- Usuarios finales: {end_users}
- Terceros potencialmente impactados: {third_parties}
- Grupos vulnerables involucrados: {vulnerable_groups}

## 3. Riesgos identificados
- Sesgo / discriminación: {bias_risk}
- Privacidad / PII: {privacy_risk}
- Seguridad / toxicidad: {safety_risk}
- Explicabilidad: {explainability}

## 4. Mitigaciones
- Técnicas: {technical}
- Procesuales: {procedural}
- Supervisión humana: {human_oversight}

## 5. Métricas de monitoreo continuo
- Drift: {drift_metric}
- Fairness: {fairness_metric}
- Safety: {safety_metric}

## 6. Owner y revisión
- Owner técnico: {owner}
- Legal reviewer: {legal}
- Fecha próxima revisión: {next_review}
"""
```

## Errores comunes

- **No documentar la provenance de los datos.** Si no sabes de dónde salió cada ejemplo, no puedes defender el modelo ante un auditor ni cumplir el art. 53 del EU AI Act.
- **Licencia incorrecta.** Casos típicos: usar Llama >700M MAU sin licencia Meta, usar Mistral Large en producción con MRL, redistribuir Command R comercialmente (es NC).
- **Fine-tunear Llama con outputs de GPT-4.** Viola los TOS de OpenAI (prohibido entrenar modelos competidores con sus outputs). Documenta de dónde vienen las sintéticas.
- **Model card copy-paste.** Rellenar el template sin medir realmente. El valor del model card está en que los números sean reales.
- **No evaluar sesgo.** Reportar accuracy global oculta disparidades por subgrupo. Siempre desagrega.
- **Audit log sin integridad.** Logs mutables son evidencia débil. Usa hash chain, Object Lock o un ledger inmutable.
- **No tener runbook de incidentes.** Cuando el modelo rompe en producción, el equipo improvisa. Tener playbook pre-escrito reduce MTTR en >50%.
- **Omitir out-of-scope use.** El model card debe decir **para qué NO sirve** el modelo. Es tu defensa legal cuando alguien lo usa mal.
- **Ignorar el EU AI Act si no estás en la UE.** Aplica a cualquier modelo cuyos outputs se usen en la UE. Si tienes clientes europeos, aplica.
- **No red-teamear antes de deploy.** Los jailbreaks fáciles se descubren en 30 minutos de red team; descubrirlos en producción cuesta reputación.
- **No actualizar el model card tras cambios.** Un model card desactualizado es peor que no tenerlo: induce a error.
- **Tratar governance como responsabilidad de "otro equipo".** Es responsabilidad del equipo que entrena y despliega.

## Resumen

- **Governance** = model card + data card + licensing audit + impact assessment + audit log + red-teaming report. Es infraestructura, no papeleo.
- Un **model card** (Mitchell et al., 2019) documenta model details, intended use, factors, metrics, training data, ethical considerations y caveats. Es el estándar en HuggingFace.
- Las **licencias de modelos open** varían mucho: Llama exige naming y limita a <700M MAU; Mistral Large es research-only; Command R es CC-BY-NC; Mistral 7B, Qwen y Phi son permisivas. Audita antes de desplegar.
- **EU AI Act** (vigor agosto 2024) obliga a documentar training data, resistir derechos de autor y hacer evaluaciones adversariales para GPAI de riesgo sistémico (>10²⁵ FLOPs). Multas hasta 7% del volumen global.
- **NIST AI RMF** (Govern, Map, Measure, Manage) es el framework voluntario de facto en EE.UU.
- Un **audit trail de inferencias** inmutable (hash chain, S3 Object Lock) es la base de la trazabilidad y de la defensa legal.
- **Red-teaming** antes de deploy es obligatorio bajo EU AI Act para modelos frontier y es best practice para cualquier modelo público.
- **Impact assessment** (DPIA bajo GDPR, AIA bajo NIST) convierte riesgos difusos en riesgos accionables con owner y métrica.
- Governance mal hecha causa multas, rollbacks y pérdida de contratos; governance bien hecha es un **activo competitivo** en RFPs y auditorías.
