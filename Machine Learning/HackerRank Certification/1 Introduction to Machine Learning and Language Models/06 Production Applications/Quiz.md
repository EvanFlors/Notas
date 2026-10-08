# Quiz: LLMs en Producción

Estás desplegando un sistema de **AI code review** integrado con IDEs, pipelines CI/CD y flujos de code review. Restricciones del mundo real:

- **200 ms de tiempo de respuesta** para integración en el IDE.
- **$0.02 por análisis** de presupuesto.
- **99.9% uptime** requerido.
- Integración limpia con herramientas de desarrollo existentes.

---

## Pregunta 1

**Para integración en el IDE en tiempo real, ¿qué estrategia de implementación balancea mejor rendimiento y capacidad?**

- Correr todo el análisis a través de LLMs para resultados consistentes de alta calidad.
- **Implementar un sistema por niveles (tiered): modelos locales rápidos para feedback en tiempo real, LLMs para análisis profundo bajo demanda.** ✅
- Cachear todos los patrones posibles de código y sus análisis para lookup instantáneo.
- Usar solo los modelos más rápidos disponibles sin importar la calidad del análisis.

**Explicación:**
Un **enfoque tiered (por niveles)** es el patrón correcto en producción cuando tienes restricciones duras de latencia y presupuesto. Funciona así:

- **Nivel 1 (local, 10-50 ms):** modelos pequeños como linters (ESLint, Ruff), tree-sitter para AST, o SLMs on-device (Phi-3-mini, Gemma-2B, StarCoder-1B cuantizado) para errores sintácticos, estilo, variables sin usar.
- **Nivel 2 (cache Redis, <5 ms):** respuestas previas a snippets similares (fingerprint por AST hash) sirven la mayoría de patrones repetidos.
- **Nivel 3 (LLM potente, 1-3 s):** solo cuando el dev pide "explain", "refactor", o detecta un patrón ambiguo. Se dispara on-demand, no en cada keystroke.

Correr **todo** por LLM revienta tanto el SLA de 200 ms (los flagship rondan los 1-3 s) como el presupuesto de $0.02 ($0.002-$0.03 por llamada). Cachear "todos los patrones" es imposible (el espacio de código es combinatorio). Solo modelos rápidos sacrifica la calidad que justifica el producto. El balance correcto es **capas**.

---

## Pregunta 2

**¿Cómo deberías monitorear tu sistema en producción para asegurar que entrega valor de negocio?**

- **Trackear tasa de adopción de developers, tasa de aceptación de sugerencias, reducción real de bugs y métricas de productividad del developer.** ✅
- Enfocarte solo en métricas técnicas como accuracy del modelo, latencia y uptime del sistema.
- Monitorear principalmente basándote en quejas de usuarios y tickets de soporte.
- Usar las mismas métricas de evaluación de tu ambiente de desarrollo.

**Explicación:**
Las **métricas técnicas** (latencia, uptime, accuracy) son necesarias pero **no suficientes**. Un sistema con 99.99% uptime y 50 ms de latencia que nadie usa es un fracaso. Las métricas que importan en producción son **de producto y negocio**:

- **Adoption rate**: % de developers activos / developers con acceso. Si <20% lo usa, hay fricción oculta.
- **Suggestion acceptance rate**: % de sugerencias aceptadas vs ignoradas vs rechazadas explícitamente. GitHub Copilot reporta ~26-30% históricamente.
- **Bugs prevented**: con A/B test (grupo con AI vs sin AI), medir bugs reportados a 30 días.
- **Time-to-merge**: PRs con AI review deberían mergearse más rápido.
- **DORA metrics**: deployment frequency, lead time for changes, change failure rate, MTTR.
- **Developer satisfaction (DevX)**: encuestas tipo SPACE framework.

Esperar quejas de usuarios es **reactivo** (los developers simplemente dejan de usarlo sin reportar). Las métricas del dev environment (BLEU, perplexity) no correlacionan directamente con utilidad real.

---

## Pregunta 3

**Una actualización mayor de una librería dependiente introduce nuevos patrones no presentes en tus datos de entrenamiento, haciendo que tu sistema marque código correcto como potencialmente buggy. ¿Cuál es tu respuesta inmediata?**

- Deshabilitar el sistema hasta que puedas reentrenar con los nuevos patrones de la librería.
- Dejar que el LLM lo maneje porque debería poder generalizar a patrones nuevos.
- **Implementar colección rápida de feedback de developers y pipelines de actualización rápida del modelo mientras provees opciones de override manual.** ✅
- Agregar excepciones basadas en reglas para los nuevos patrones de la librería.

**Explicación:**
Esto es un caso clásico de **concept drift**. La respuesta correcta combina **graceful degradation** y **feedback loop acelerado**:

1. **Override manual visible**: el dev marca "false positive" en un click. Vital para no destruir la confianza en el producto.
2. **Thumbs up/down** por sugerencia alimentando una tabla `feedback_events` con `suggestion_id`, `verdict`, `library_version`, `file_hash`.
3. **Alertas de drift**: si la tasa de rechazo sube >30% WoW para una librería particular, se abre un ticket automático.
4. **Pipeline rápido de actualización**: no reentrenar un modelo grande (semanas), sino:
   - Añadir al **RAG context** docs y ejemplos de la versión nueva (horas).
   - Fine-tune LoRA pequeño con los false positives corregidos (días).
   - Ajustar el system prompt para mencionar la versión y los patrones nuevos (minutos).
5. **Feature flag** para apagar rápido las validaciones de esa librería mientras tanto.

Deshabilitar todo el sistema es demasiado drástico y erosiona la confianza. Confiar en que el LLM "generalice" ignora que su conocimiento tiene cutoff. Reglas hard-coded se multiplican y son inmantenibles.

---

## Pregunta 4

**Tu sistema necesita manejar código propietario sensible. ¿Qué enfoque de despliegue aborda mejor seguridad y privacidad?**

- Usar APIs de LLMs en la nube para el análisis más capaz.
- Anonimizar el código removiendo nombres de variables y comentarios antes del análisis.
- **Desplegar modelos más pequeños y especializados on-premises mientras usas LLMs en la nube solo para patrones anonimizados y generalizados.** ✅
- Evitar usar cualquier servicio de IA externo y confiar solo en análisis basado en reglas.

**Explicación:**
Un **modelo híbrido** es el estándar enterprise. Arquitectura:

```
┌──────────────────────────────────────┐
│  Repo privado (código propietario)   │
└───────────────┬──────────────────────┘
                ▼
┌──────────────────────────────────────┐
│  Modelo on-prem (self-hosted)        │
│  Code Llama 70B / Qwen2.5-Coder 32B  │
│  vLLM/TGI en GPU interna o AWS/Azure │
│  dentro del VPC privado              │
└───────────────┬──────────────────────┘
                │  (código NUNCA sale del VPC)
                ▼
         Análisis sensible
                │
                │  Si necesita conocimiento general:
                ▼
┌──────────────────────────────────────┐
│  Patrones genéricos abstraídos       │
│  (sin IP, sin nombres de clase)      │
│  → API en la nube (OpenAI/Anthropic) │
└──────────────────────────────────────┘
```

Opciones de despliegue:

| Opción | Pros | Contras |
|---|---|---|
| **vLLM on-prem** | Control total, zero data egress | OpEx GPU, mantenimiento |
| **Azure OpenAI con PNA** | Data residency, no training | Sigue en la nube MS |
| **AWS Bedrock + VPC endpoint** | Multi-modelo, IAM | Vendor lock-in |
| **Modal / Replicate privado** | Serverless GPU | Latencia, cold starts |

Anonimizar solo nombres de variables **no funciona**: la estructura del código, los patrones de negocio y los imports suelen ser reconocibles (deanonymization attacks demostrados). Rules-only sacrifica demasiada capacidad. La API pública directa con código propietario viola la mayoría de políticas corporativas.

---

## Pregunta 5

**Después de 6 meses en producción, notas que los developers ignoran cada vez más ciertos tipos de sugerencias. ¿Cómo adaptas el sistema?**

- Incrementar el threshold de confianza para esos tipos de sugerencias.
- Remover esos tipos de sugerencias completamente del sistema.
- **Analizar por qué las sugerencias son ignoradas (falsos positivos, timing pobre, valor poco claro) y adaptar el sistema en consecuencia.** ✅
- Agregar notificaciones más agresivas para asegurar que los developers vean las sugerencias.

**Explicación:**
Lo primero es **diagnosticar la causa raíz** antes de actuar. "Developers ignoran" es un síntoma con múltiples causas posibles, cada una con fix distinto:

| Causa | Diagnóstico | Fix |
|---|---|---|
| **Falsos positivos** | % de aceptación <5% | Mejorar prompts, añadir ejemplos negativos, aumentar threshold |
| **Timing pobre** | se muestran mid-typing, interrumpen el flow | Debounce, mostrar solo on-save o en PR |
| **Valor poco claro** | aceptan pero no sabe por qué | Añadir explicación del "por qué" + link a docs |
| **Verbosidad** | sugieren refactors de 10 líneas por error de estilo | Scope por severidad |
| **Duplicación con linter** | ESLint ya lo marca | Eliminar overlap |
| **Confianza baja** | sugerencias ambiguas | Mostrar solo si confidence > umbral |
| **Fatiga de notificaciones** | demasiadas por archivo | Rate limit por archivo/día |

**Herramientas de diagnóstico:**

- **Session recordings** (anonimizadas) para ver el comportamiento real.
- **Clustering de sugerencias ignoradas** por tipo/archivo/lenguaje.
- **Entrevistas con 10 power users** y 10 que dejaron de usarlo.
- **A/B test** removiendo o modificando el tipo de sugerencia.

Subir el threshold a ciegas pierde sugerencias valiosas. Remover el tipo entero destruye valor si solo algunos sub-casos fallan. Notificaciones más agresivas producen **alert fatigue** y empeoran la relación con el usuario (muchas veces lleva al abandono completo del producto). La respuesta profesional es **medir → entender → iterar**.

---

## Resumen de principios cubiertos

- **Tiered architecture** para balancear latencia, costo y calidad.
- **Métricas de producto**, no solo técnicas, para medir éxito real.
- **Graceful degradation** y **feedback loops rápidos** ante drift.
- **Despliegue híbrido on-prem + cloud** para datos sensibles.
- **Diagnóstico antes que acción** cuando el uso baja.
