# Licensing and Compliance

## ¿Qué es?

Un modelo fine-tuneado es un **artefacto legal** tanto como técnico. La **licencia del modelo base** y el **marco regulatorio** del dominio determinan qué puedes hacer con los pesos entrenados, dónde puedes desplegarlos y qué datos puedes meterles. Ignorar esto es la forma más rápida de descubrir, seis meses después, que todo tu producto es inviable comercialmente o viola la ley.

Las piezas en juego:

- **Licencias de modelos open-source** — Apache 2.0, MIT, Llama Community License, Gemma Terms, licencias no-comerciales.
- **Leyes de residencia de datos** — GDPR (UE), LGPD (Brasil), LFPDPPP (México), PIPL (China), leyes de localización en India, Rusia.
- **Marcos de cumplimiento sectoriales** — HIPAA (salud EUA), SOC 2 (SaaS enterprise), PCI-DSS (tarjetas), ISO 27001, FedRAMP.
- **Regulación emergente de IA** — EU AI Act (entrada escalonada 2024-2026), Executive Orders en EUA, propuestas en LATAM.

### Dos ejes de decisión

```
          Licencia permite tu uso comercial?
          ┌──────────────┬──────────────┐
          │     SÍ       │      NO      │
┌─────────┼──────────────┼──────────────┤
Deploy    │  LIBRE       │  BLOQUEADO   │
cumple    │  CORRECTO    │  POR         │
compliance│              │  LICENCIA    │
├─────────┼──────────────┼──────────────┤
Deploy    │  BLOQUEADO   │  DOBLE       │
NO cumple │  POR         │  BLOQUEO     │
compliance│  COMPLIANCE  │              │
└─────────┴──────────────┴──────────────┘
```

Necesitas **ambas** celdas verdes para desplegar legalmente.

## ¿Por qué importa?

Los costos de equivocarse son concretos y rastreables:

- **Migración forzada de modelo** por licencia incompatible: 2-4 semanas, $10K-100K en re-entrenamiento + re-evaluación.
- **Multas regulatorias:** GDPR hasta 4% del revenue global anual o €20M. HIPAA hasta $1.5M por categoría de violación/año. EU AI Act hasta €35M o 7% revenue.
- **Pérdida de contratos enterprise:** sin SOC 2 Type II, grandes B2B no te firman.
- **Daño reputacional:** una brecha de datos de salud en un modelo de IA genera cobertura mediática que pulveriza la confianza.
- **Imposibilidad de distribuir el modelo:** si fine-tuneaste sobre Llama, por licencia debes distribuir el adapter bajo la misma licencia; no puedes venderlo como SaaS propietario cerrado sin ciertas consideraciones.

Esta lección no reemplaza asesoría legal, pero te da el **mapa mental** para hablar con tu equipo legal sabiendo qué preguntar.

## ¿Cómo funciona?

### Licencias open-source más comunes

| Licencia | Uso comercial | Modificación | Derivados cerrados | Patent grant | Notas |
|---|---|---|---|---|---|
| **Apache 2.0** | Sí, sin restricciones | Sí | Sí (puedes mantener fine-tunes privados) | Sí | Mistral, Falcon, Qwen (varía), BERT |
| **MIT** | Sí | Sí | Sí | No explícito | Phi, muchos repos académicos |
| **BSD-3** | Sí | Sí | Sí | No | Modelos académicos |
| **Llama Community** | Sí, con topes | Sí | Mayormente sí (ver términos) | Limitado | Prohibida para empresas con >700M MAU; prohibida para entrenar otros LLMs competidores |
| **Gemma Terms** | Sí | Sí | Sí, con "prohibited use policy" | Sí | Google obliga a seguir una política de uso aceptable |
| **CC-BY-NC** | **No** (solo no comercial) | Sí | — | — | ¡Cuidado! Varios modelos "open" no son comerciales |
| **OpenRAIL-M** | Sí, con restricciones de uso | Sí | Sí | Varía | BLOOM, usada para añadir cláusulas éticas |

### Caso Llama en detalle

La **Llama Community License** (v2, v3) permite uso comercial *excepto*:

1. Empresas con **>700 millones de MAU** al momento de release del modelo necesitan acuerdo separado con Meta.
2. No puedes usar outputs de Llama para **entrenar otros LLMs** que compitan.
3. Debes incluir el **aviso de atribución** y propagar la licencia en derivados.

Para la mayoría de equipos no es un problema; para TikTok, Snapchat, X, sí lo es.

### Marcos de cumplimiento (lo esencial)

| Marco | Jurisdicción | Qué protege | Impacto en fine-tuning |
|---|---|---|---|
| **GDPR** | UE/EEA | Datos personales de residentes UE | Transferencias fuera UE requieren mecanismos aprobados (SCCs, adequacy); derecho al olvido obliga a poder "desaprender" (hard con pesos) |
| **HIPAA** | EUA | PHI (datos de salud) | Business Associate Agreement con proveedor cloud; cifrado at-rest y in-transit; audit logs; acceso restringido |
| **SOC 2 Type II** | Global (B2B) | Seguridad, disponibilidad, confidencialidad | Controles continuos auditados sobre 6-12 meses |
| **PCI-DSS** | Global (tarjetas) | Datos de tarjeta de crédito | Segmentación de red; nunca entrenar con PANs en claro |
| **LGPD** | Brasil | Datos personales | Similar a GDPR; consentimiento explícito, DPO obligatorio |
| **LFPDPPP** | México | Datos personales | Aviso de privacidad, derechos ARCO |
| **PIPL** | China | Datos personales | Localización dura; evaluación de seguridad para transferir |
| **EU AI Act** | UE | Sistemas de IA | Clasificación por riesgo; GPAI (como LLMs) con obligaciones de transparencia y evaluación de riesgo sistémico |

### Residencia de datos: regla práctica

- **GDPR:** no exige residencia pero *simplifica* mantener datos en UE. Si usas APIs US (OpenAI, Anthropic), necesitas SCCs + Data Processing Agreement + evaluar impacto Schrems II.
- **Rusia, China, India (algunos sectores):** localización dura. Debes correr el modelo en infraestructura local.
- **Sector público LATAM:** cada vez más exige nubes regionales (AWS São Paulo, GCP Santiago).

### Decision framework legal

```
1. Clasifica tus datos
   - PII? PHI? datos financieros? propiedad intelectual?
   - origen geográfico de los sujetos?

2. Identifica marcos aplicables
   - HIPAA/PCI/SOC2/GDPR/LGPD/EU AI Act?

3. Filtra licencias de modelos
   - uso comercial? MAU threshold? derivados cerrados permitidos?
   - tu caso de uso está en prohibited uses?

4. Elige región de deployment
   - residencia de datos compatible?
   - proveedor con BAA/DPA firmable?

5. Documenta la cadena
   - data lineage, model card, DPIA, risk register
```

### Modalidades híbridas inteligentes

- **Dev con API, prod con self-hosted:** prototipa con GPT-4o, migra a Mistral self-hosted en región UE para producción con datos regulados.
- **API con zero-retention mode:** OpenAI, Anthropic y Google ofrecen contratos enterprise que no retienen prompts (clave para HIPAA).
- **Private endpoints en nube cumplidora:** AWS Bedrock corre Claude/Llama/Mistral en tu VPC con BAA firmable (HIPAA).

## Ejemplo con código

### 1. Validador automático de compatibilidad licencia × caso de uso

```python
# ============================================================
# ¿Puedo usar este modelo en mi contexto?
# ============================================================
from dataclasses import dataclass
from typing import Optional

@dataclass
class Modelo:
    nombre: str
    licencia: str
    mau_threshold: Optional[int] = None   # None = sin tope
    permite_derivados_cerrados: bool = True
    prohibited_uses: tuple = ()

@dataclass
class CasoDeUso:
    empresa_mau: int
    distribuira_fine_tune_cerrado: bool
    dominio: str                           # p.ej. "salud", "finanzas", "marketing"
    region_deployment: str                 # "ue", "us", "latam", "cn"

CATALOGO = [
    Modelo("Mistral-7B", "Apache-2.0"),
    Modelo("Llama-3-8B", "Llama-Community",
           mau_threshold=700_000_000,
           prohibited_uses=("entrenar LLMs competidores",)),
    Modelo("Gemma-7B", "Gemma-Terms",
           prohibited_uses=("desinformación", "armamento", "vigilancia masiva")),
    Modelo("Phi-3-mini", "MIT"),
    Modelo("Falcon-7B", "Apache-2.0"),
]

def validar(m: Modelo, uso: CasoDeUso) -> list[str]:
    problemas = []
    if m.mau_threshold and uso.empresa_mau > m.mau_threshold:
        problemas.append(
            f"Tu empresa ({uso.empresa_mau:,} MAU) supera el tope de "
            f"{m.mau_threshold:,} del {m.licencia}. Necesitas acuerdo comercial."
        )
    if uso.distribuira_fine_tune_cerrado and not m.permite_derivados_cerrados:
        problemas.append("Esta licencia no permite derivados cerrados.")
    if uso.dominio in m.prohibited_uses:
        problemas.append(f"Dominio '{uso.dominio}' está en prohibited uses.")
    return problemas

mi_caso = CasoDeUso(
    empresa_mau=1_200_000_000,          # red social gigante
    distribuira_fine_tune_cerrado=True,
    dominio="marketing",
    region_deployment="ue",
)

for m in CATALOGO:
    issues = validar(m, mi_caso)
    estado = "OK" if not issues else "BLOQUEADO"
    print(f"{m.nombre:<15} [{estado}] " + ("" if not issues else " | ".join(issues)))
```

### 2. Checklist HIPAA aplicado al pipeline

```python
# ============================================================
# ¿Mi pipeline de fine-tuning con datos de salud cumple HIPAA?
# ============================================================
checklist_hipaa = {
    "BAA firmado con cloud provider": False,     # AWS, Azure, GCP ofrecen BAA
    "PHI cifrado at-rest (AES-256)": False,
    "PHI cifrado in-transit (TLS 1.2+)": False,
    "Audit logs inmutables": False,
    "Acceso basado en roles (least privilege)": False,
    "De-identificación o Safe Harbor aplicado al dataset": False,
    "Modelo deployado en región compatible": False,
    "Prompts/outputs no se envían a servicios sin BAA": False,
    "Plan de respuesta a brechas documentado": False,
    "Entrenamiento al personal registrado": False,
}

def auditar(cl: dict) -> None:
    total = len(cl)
    ok = sum(cl.values())
    print(f"Cumplimiento HIPAA: {ok}/{total}")
    for item, v in cl.items():
        marca = "[x]" if v else "[ ]"
        print(f"  {marca} {item}")
    if ok < total:
        print("\nNO despliegues hasta cerrar todos los items.")

auditar(checklist_hipaa)
```

### 3. Model Card mínima (recomendada por EU AI Act)

```python
# ============================================================
# Model Card: documenta origen, licencia, limitaciones
# ============================================================
model_card = {
    "nombre": "soporte-cliente-es-v1",
    "modelo_base": "Mistral-7B-Instruct-v0.3",
    "licencia_base": "Apache-2.0",
    "licencia_derivado": "Apache-2.0",
    "tecnica": "QLoRA (r=16, alpha=32, 4-bit NF4)",
    "dataset": {
        "fuente": "tickets internos anonimizados 2023-2024",
        "tamano": 3200,
        "idioma": "es-MX",
        "pii_eliminada": True,
        "metodo_anonimizacion": "presidio + revisión humana del 10%",
    },
    "metrica_eval": {"accuracy": 0.91, "latencia_p95_ms": 320},
    "limitaciones_conocidas": [
        "no apto para asesoría legal o médica",
        "degrada en dialectos fuera de MX/CO/AR",
        "no entrenado para detectar fraude",
    ],
    "cumplimiento": ["GDPR", "LFPDPPP"],
    "contacto_responsable": "ia-governance@empresa.com",
    "fecha": "2025-10-07",
}

import json
print(json.dumps(model_card, indent=2, ensure_ascii=False))
```

## Errores comunes

- **Elegir modelo solo por benchmark sin leer la licencia.** Clásico: fine-tunear Llama y descubrir meses después que tu empresa supera 700M MAU.
- **Asumir que "open-source" = "libre para todo".** Hay licencias no comerciales (CC-BY-NC), con cláusulas éticas (OpenRAIL), con topes (Llama).
- **Confundir cloud compliance con end-to-end compliance.** AWS puede ser HIPAA-eligible, pero *tu* pipeline debe implementar los controles: cifrado, logs, roles, BAA.
- **Ignorar prompts como vector de PHI.** Un usuario pega su historial clínico en tu chatbot — si no tienes BAA con el proveedor de API, acabas de violar HIPAA.
- **No separar datos de entrenamiento vs inferencia.** GDPR aplica a ambos. "Entrené con datos UE y despliegué en US" es transferencia internacional.
- **Olvidar el derecho al olvido.** GDPR exige poder borrar datos de un sujeto. Si memorizaste su info en los pesos, no basta con eliminarla del dataset.
- **No versionar la Model Card.** Cuando audite el regulador, no poder decir qué datos entrenaron qué modelo es una red flag enorme.
- **Fiarse de que la licencia "no cambiará".** Meta ha ajustado términos de Llama entre versiones. Guarda copia de la licencia del día que descargaste los pesos.
- **Ignorar el EU AI Act.** Aunque opera "fuera de UE", si procesas datos de residentes UE, aplica. Hay obligaciones de transparencia para GPAI desde 2025.

### Herramientas y recursos

- **De-identificación:** Microsoft Presidio, AWS Comprehend Medical, scrubadub.
- **Governance y catálogo:** HuggingFace model cards, MLflow Model Registry, Weights & Biases Model Registry.
- **Auditoría:** Vanta, Drata, Secureframe (SOC 2, HIPAA, ISO 27001 automation).
- **Cloud BAA:** AWS BAA (gratis), Azure (gratis con enterprise), GCP (gratis).
- **Legal LLM-friendly:** Choose a License (choosealicense.com), TLDRLegal, SPDX license list.

## Resumen

- Un modelo fine-tuneado es un artefacto **legal además de técnico**: licencia + cumplimiento + residencia de datos definen qué puedes hacer con él.
- **Apache 2.0** es la licencia más segura para uso comercial sin restricciones (Mistral, Falcon).
- **Llama Community License** permite uso comercial *excepto* para empresas de >700M MAU y para entrenar competidores directos.
- **GDPR, HIPAA, PCI-DSS, SOC 2, EU AI Act** cada uno impone requerimientos distintos sobre cifrado, logs, residencia, consentimiento y transparencia.
- Para datos regulados (salud, finanzas, UE), **self-hosted en región compatible** suele ser el único camino.
- **BAA (HIPAA)** y **DPA/SCC (GDPR)** son contratos *obligatorios* con tu proveedor de cloud o API — no son opcionales.
- Documenta siempre una **Model Card**: modelo base, licencia, dataset, anonimización, métricas, limitaciones, contacto responsable.
- El **derecho al olvido** (GDPR) choca con la memorización de pesos: anonimizar antes de entrenar es la defensa real.
- Verifica licencias **antes** de invertir semanas en fine-tuning; migrar después es caro y lento.
- Estas guías no reemplazan asesoría legal: úsalas para tener la conversación correcta con tu equipo de compliance.
