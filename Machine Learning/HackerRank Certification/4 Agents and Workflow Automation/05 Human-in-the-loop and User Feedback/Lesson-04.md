# Integración: un sistema HITL completo

## ¿Qué es?

Un **sistema HITL integrado** combina en un solo pipeline los patrones vistos antes (calibración de autonomía, workflows de aprobación, estimación de confianza, escalation y recolección de feedback) de modo que cada componente informa a los demás. La estimación de confianza alimenta la decisión de autonomía; el feedback mejora la calibración de confianza; los workflows de aprobación capturan correcciones que se convierten en training data; las correcciones ajustan los prompts que usará la próxima generación.

> **Idea central:** las piezas HITL no son aditivas, son **retro-alimentadas**. Un sistema maduro mejora con el tiempo porque cada ciclo deja mejor configurado al siguiente.

### Arquitectura de alto nivel

![Arquitectura HITL completa para code review agent](https://hrcdn.net/ai-engineering/module-4/dark/hitl-lesson04-system-architecture.svg)

```
PR webhook
   │
   ▼
Review Engine ──► prompt refinado por feedback histórico
   │
   ▼
Confidence Assessor ──► (stated + consistency + calibración histórica + contexto)
   │
   ▼
Autonomy Decision ──► risk × confidence → mode
   │
   ├── autonomous:   publica y adjunta botones de feedback
   ├── assisted:     publica con disclaimer "revisar manualmente"
   ├── approval:     encola para revisión humana
   └── escalated:    hace handoff con draft para completar
         │
         ▼
Feedback Collector ──► explícito + implícito ──► dataset ──► prompt + calibración
```

### Modos de ejecución

| Modo | Cuándo | Qué hace el agente | Rol del humano |
|---|---|---|---|
| **Autonomous** | Riesgo bajo + confianza alta | Publica directamente | Puede dar feedback post-hoc |
| **Assisted** | Riesgo medio + confianza media | Publica con disclaimer y request de verificación | Verifica si tiene tiempo |
| **Approval required** | Riesgo alto o confianza baja-media | Encola la propuesta | Debe aprobar antes de publicar |
| **Escalated** | Riesgo crítico o confianza muy baja | Hace draft y notifica a experto | Toma el control del caso |

## ¿Por qué importa?

Los patrones HITL individuales mejoran la seguridad en bordes puntuales; integrados, cambian la curva: el sistema **mejora semana a semana** sin re-entrenar el modelo base. Dos semanas después del despliegue, el prompt tiene guidelines derivadas de 300 👎, la calibración de confianza está ajustada contra accuracy real, la cola de aprobaciones se procesa más rápido porque ya solo recibe casos genuinamente dudosos, y la tasa de escalations bajó porque el agente aprendió a evitar sus zonas conocidas de error.

Sin integración: cada componente opera en silo. El feedback se recolecta pero no mejora prompts. Las aprobaciones se dan pero las modificaciones no se analizan. El confidence score se calcula pero nunca se calibra contra realidad. Resultado: HITL caro operacionalmente y sin ROI.

### Lo que una integración correcta habilita

- **Autonomía creciente con el tiempo.** A medida que la confianza se calibra y los prompts mejoran, más acciones pueden ejecutarse autónomamente sin aumentar el riesgo.
- **Reducción de carga humana** sin pérdida de supervisión: los humanos ven cada vez menos casos triviales y más casos realmente ambiguos.
- **Detección temprana de regresión.** Si cambias de modelo (Sonnet 4.5 → Opus 4.7) y la satisfacción baja, lo sabes en días, no meses.
- **Dataset de evaluación vivo** siempre al día, derivado del uso real.

## ¿Cómo funciona?

### Combinar múltiples señales de confianza

El agente estima su confianza combinando:

1. **Stated confidence**: lo que el modelo declara en su propia salida estructurada.
2. **Response consistency**: generas la respuesta `N` veces y mides acuerdo entre ellas.
3. **Historical calibration**: factor correctivo basado en accuracy pasada (si decía 0.9 y acertaba 0.7, multiplica por 0.78).
4. **Context adjustments**: penalización por tamaño del PR, novedad del área del código, autor desconocido.

### Decisión de modo

Una matriz simple:

| Riesgo \ Confianza | Baja (<0.6) | Media (0.6–0.8) | Alta (>0.8) |
|---|---|---|---|
| **Low** | approval | assisted | **autonomous** |
| **Medium** | escalated | approval | assisted |
| **High** | escalated | escalated | approval |
| **Critical** | escalated | escalated | escalated |

### Loop de mejora diario

Cada noche (o cada hora, según volumen), un job:

1. Lee feedback nuevo del último período.
2. Detecta patrones (tipos de sugerencia con alta tasa de rechazo, archivos con baja precisión).
3. Añade guidelines al prompt o actualiza umbrales.
4. Recalibra la función de confianza contra accuracy observada.
5. Publica reporte y alerta si la satisfacción cae por debajo del umbral.

### Monitoreo que importa

| Métrica | Qué indica | Umbral típico |
|---|---|---|
| Satisfaction score (feedback agregado) | Salud general | Alertar si cae >10% semana a semana |
| Approval rate | Qué tan bien calibrado está el agente | Si baja de 70% → prompt o modelo mal |
| Time-to-approval | Fricción del workflow | Alertar si >24h p90 |
| Escalation rate | Overuse del humano experto | Alertar si crece sin razón externa |
| Confidence calibration (ECE) | Qué tan honesto es el agente sobre sí mismo | ECE < 0.1 es sano |
| Autonomy ratio (% autonomous) | Cuánto trabajo se evita a humanos | Debe crecer con el tiempo si todo va bien |

## Ejemplo con código

### Agente integrado

```python
from dataclasses import dataclass
from datetime import timedelta
from typing import Literal

Mode = Literal["autonomous", "assisted", "approval_required", "escalated"]

@dataclass
class ReviewConfig:
    risk_matrix: dict
    satisfaction_floor: float = 0.7

class HITLCodeReviewAgent:
    def __init__(self, llm, storage, notifier, github, config: ReviewConfig):
        self.llm = llm
        self.policy_engine = PolicyEngine()
        self.risk_assessor = RiskAssessor()
        self.confidence_estimator = ConsistencyBasedConfidence(llm)
        self.escalation_engine = EscalationEngine(config)
        self.approval_engine = ApprovalEngine(storage, notifier)
        self.feedback_collector = FeedbackCollector(storage)
        self.prompt_manager = FeedbackDrivenPromptManager(storage)
        self.github = github
        self.config = config

    async def review_pr(self, pr_number: int, repo: str) -> dict:
        pr_context = await self._fetch_pr_context(pr_number, repo)
        prompt = await self.prompt_manager.get_refined_prompt(pr_context)
        draft = await self._generate_review(prompt, pr_context)
        confidence = await self.confidence_estimator.estimate(draft, pr_context)
        risk = self.risk_assessor.assess("post_review", pr_context)
        mode = self._determine_mode(risk["risk"], confidence)
        return await self._execute(mode, draft, confidence, pr_context)

    def _determine_mode(self, risk: str, confidence: float) -> Mode:
        if risk == "critical":
            return "escalated"
        if risk == "high" and confidence < 0.7:
            return "escalated"
        if risk == "high":
            return "approval_required"
        if risk == "low" and confidence > 0.8:
            return "autonomous"
        if confidence < 0.5:
            return "escalated"
        return "approval_required" if confidence < 0.7 else "assisted"
```

### Ejecución por modo

```python
    async def _execute(self, mode: Mode, review: dict,
                        confidence: float, context: dict) -> dict:
        dispatch = {
            "autonomous": self._exec_autonomous,
            "assisted": self._exec_assisted,
            "approval_required": self._exec_approval,
            "escalated": self._exec_escalation,
        }
        return await dispatch[mode](review, confidence, context)

    async def _exec_autonomous(self, review, confidence, context):
        payload = self._format_for_github(review)
        payload["body"] += self._feedback_footer(review["review_id"])
        await self.github.post_review(context["repo"], context["pr_number"], payload)
        return {"mode": "autonomous", "confidence": confidence}

    async def _exec_assisted(self, review, confidence, context):
        payload = self._format_for_github(review)
        payload["body"] = (
            f"> _Agente ({confidence:.0%} de confianza). Por favor verifica._\n\n"
            + payload["body"]
            + self._feedback_footer(review["review_id"])
        )
        await self.github.post_review(context["repo"], context["pr_number"], payload)
        return {"mode": "assisted", "confidence": confidence}

    async def _exec_approval(self, review, confidence, context):
        req = await self.approval_engine.submit(
            action_type="post_review",
            payload={"review": review, "context": context},
            context={"pr_number": context["pr_number"], "confidence": confidence},
        )
        return {"mode": "approval_required", "approval_id": req.action_id}

    async def _exec_escalation(self, review, confidence, context):
        decision = self.escalation_engine.decide(review, confidence, context)
        targets = await self.escalation_engine.route(decision, context)
        for t in targets:
            await self.notifier.escalate(t, {
                "pr": context, "draft": review,
                "reason": decision.get("reason"),
                "confidence": confidence,
            })
        return {"mode": "escalated", "targets": targets}
```

### Footer de feedback inline en el comentario

```python
    def _feedback_footer(self, review_id: str) -> str:
        base = "https://feedback.ejemplo.com"
        return f"""

---
<details>
<summary>Rate this review</summary>

- [Helpful]({base}/{review_id}?r=helpful)
- [Not helpful]({base}/{review_id}?r=not_helpful)
- [Good catch]({base}/{review_id}?r=good_catch)
- [Incorrect]({base}/{review_id}?r=incorrect)
</details>
"""
```

### Loop diario de mejora

```python
async def daily_improvement_loop(agent: HITLCodeReviewAgent):
    window = timedelta(days=7)
    patterns = await agent.feedback_collector.detect_patterns(window)

    for p in patterns:
        if p["pattern"] == "high_rejection_rate":
            await agent.prompt_manager.add_guideline(
                f"Precaución con sugerencias de tipo '{p['suggestion_type']}'. "
                f"Tasa de rechazo reciente: {p['rejection_rate']:.0%}. "
                "Solo propónla si hay evidencia clara."
            )
        if p["pattern"] == "low_accuracy_file_type":
            await agent.prompt_manager.add_guideline(
                f"Para archivos '{p['file_type']}', aplica criterios más laxos "
                "(ej. tests no requieren el mismo nivel de error-handling)."
            )

    # Recalibrar confianza contra accuracy observada
    await agent.confidence_estimator.recalibrate(window)

    # Métricas y alertas
    sat = await agent.feedback_collector.satisfaction_score(window)
    if sat < agent.config.satisfaction_floor:
        await agent.notifier.alert_team(
            f"Satisfaction cayó a {sat:.0%} (<{agent.config.satisfaction_floor:.0%})"
        )
```

### Recalibración de confianza (isotonic regression)

```python
from sklearn.isotonic import IsotonicRegression
import numpy as np

class ConfidenceCalibrator:
    def __init__(self):
        self.iso = IsotonicRegression(out_of_bounds="clip")
        self.fitted = False

    def fit(self, stated: np.ndarray, correct: np.ndarray):
        """stated: confianzas declaradas en [0,1]; correct: 0/1 outcome real."""
        self.iso.fit(stated, correct)
        self.fitted = True

    def calibrate(self, stated: float) -> float:
        if not self.fitted:
            return stated
        return float(self.iso.predict([stated])[0])
```

### Suite de regresión derivada de feedback negativo

```python
import pytest

@pytest.mark.parametrize("case", load_regression_cases("negative_examples.jsonl"))
def test_no_regression(case, agent):
    output = agent.review(case["prompt"])
    # No debería volver a cometer el mismo tipo de error
    for forbidden in case.get("forbidden_patterns", []):
        assert forbidden not in output, f"Regresión: volvió a sugerir '{forbidden}'"
```

## Errores comunes

- **Over-escalation.** El agente escala el 60% de los casos y satura al experto. Síntoma de umbrales mal calibrados o modelo subdimensionado. Mide `escalation_rate` y ajústalo.
- **Feedback que no cierra el loop.** Recolectas pero el prompt manager nunca lo lee. Define el job diario y verifica que efectivamente modifica el prompt.
- **Thresholds hardcodeados y rígidos.** Un único umbral de confianza para todo tipo de PR ignora que `auth/` y `docs/` tienen necesidades distintas. Define thresholds por contexto.
- **Sin monitoreo de tendencias.** La satisfacción cae 15% en dos semanas y nadie se entera hasta que un usuario escribe en Slack. Alerta automática en umbrales.
- **Confianza no calibrada.** El modelo dice 0.9 pero acierta 0.6. Isotonic regression o Platt scaling contra outcomes reales.
- **Agregar guidelines indefinidamente.** El system prompt crece a 20k tokens porque cada patrón detectado añade líneas sin reemplazar las obsoletas. Rota guidelines (si una regla no se dispara en 30 días, retírala).
- **Modos definidos pero no diferenciados en la UI.** El usuario no distingue entre "autonomous" y "assisted" porque ambos se ven igual. El modo *assisted* debe mostrar el disclaimer visiblemente.
- **No separar métricas por cohorte.** Satisfacción global sube pero la cohorte de usuarios senior cae. Desagrega siempre.
- **Modelo cambia, calibración no se actualiza.** Pasas de Claude Sonnet 4.5 a Opus 4.7; el calibrador anterior ya no aplica. Marca "modelo nuevo = recalibrar desde cero".
- **Falta de kill switch.** Si el agente entra en loop de malas decisiones (ej. tras un deploy roto), no hay forma rápida de ponerlo en modo "approval en todo". Expón un flag operacional de override.

## Resumen

- Un sistema HITL maduro **integra** autonomía calibrada, workflows de aprobación, estimación de confianza, escalation y feedback en un solo pipeline retroalimentado.
- El agente combina **múltiples señales de confianza** (stated, consistency, calibración histórica, contexto) antes de decidir el modo.
- La decisión de modo surge de una matriz **riesgo × confianza** con cuatro modos: autonomous, assisted, approval_required, escalated.
- Cada modo tiene **lógica de ejecución distinta**: autónomo publica directo, assisted publica con disclaimer, approval encola, escalated hace handoff con draft.
- Un **loop diario** detecta patrones en el feedback, añade guidelines al prompt, recalibra la función de confianza y alerta si la satisfacción cae.
- Monitoreo clave: satisfaction, approval rate, time-to-approval, escalation rate, calibration error (ECE), autonomy ratio.
- Buenas señales de un sistema sano: **autonomy ratio creciente** sin bajar satisfacción, **escalation rate decreciente**, ECE bajo y estable.
- Errores de integración: feedback que no cierra el loop, thresholds rígidos, confianza no calibrada, prompts que crecen sin rotar guidelines y falta de kill switch operacional.
- Un buen agente HITL **mejora semana a semana sin re-entrenar** el modelo base, porque la infraestructura alrededor convierte el uso real en configuración más fina.
