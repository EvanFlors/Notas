# Quiz: In-Context Learning y Razonamiento Básico

Este quiz evalúa tu capacidad para elegir la estrategia de prompting adecuada (zero-shot, few-shot, chain-of-thought, self-consistency) según restricciones reales: costo, latencia, accuracy, auditabilidad y complejidad de la tarea.

---

### Pregunta 1

Tu plataforma de e-commerce necesita generar descripciones para 50,000 productos en categorías diversas. Las descripciones deben destacar características y hablarle a la audiencia objetivo, pero **no tienes presupuesto para mantener sets de ejemplos** y el tiempo de respuesta es crítico por el tráfico alto. ¿Qué enfoque de prompting elegirías?

- **Zero-shot prompting con instrucciones claras que especifiquen características y audiencia objetivo** ← Correcto
- Few-shot prompting con 5-7 ejemplos por categoría principal
- Chain-of-thought para razonar sobre priorización de features
- Self-consistency con múltiples generaciones para asegurar calidad

**Explicación:** Zero-shot es la elección correcta cuando la tarea es **común y bien definida** (generación de descripciones), el **volumen es alto** (50K ítems), y **mantener bancos de ejemplos** por categoría es inviable. Minimiza tokens → menor costo y latencia. Few-shot añadiría coste proporcional sin mejorar significativamente una tarea que GPT-class resuelve nativamente. CoT y self-consistency son overkill: no hay razonamiento multi-paso ni decisión crítica que auditar.

---

### Pregunta 2

Estás construyendo un clasificador de tickets de soporte entre "Problema técnico", "Facturación", "Solicitud de función" y "Gestión de cuenta". Zero-shot funciona bien para casos obvios pero **falla en ambiguos** como *"no puedo acceder a mis funciones premium después del pago"*. ¿Cuál es el primer paso?

- Cambiar a chain-of-thought para mostrar razonamiento en cada clasificación
- **Añadir 3-5 ejemplos few-shot cubriendo casos frontera y categorías con overlap** ← Correcto
- Subir la temperatura para generar clasificaciones más diversas
- Implementar self-consistency con voto mayoritario

**Explicación:** El síntoma —fallo específico en **casos borde con overlap entre clases**— es el escenario clásico para **few-shot con ejemplos estratégicos de frontera**: un ticket "no accedo tras pagar" ilustra el límite entre facturación y problema técnico. Few-shot ataca directamente la ambigüedad enseñando ejemplos de desambiguación. CoT no ayuda (no es problema de razonamiento sino de categorización). Subir temperatura empeora clasificación (introduce ruido). Self-consistency es caro y no soluciona la causa raíz.

---

### Pregunta 3

Tu asistente de evaluación de riesgo financiero debe analizar **condiciones de mercado, salud financiera de la empresa, riesgos sectoriales e indicadores macro** antes de asignar un rating. Los stakeholders necesitan entender **cómo** se llegó al rating. ¿Qué estrategia atiende accuracy y explicabilidad?

- Zero-shot con instrucciones explícitas para cada dimensión
- Few-shot con ejemplos diversos de buenas y malas inversiones
- **Chain-of-thought exigiendo análisis paso a paso de cada factor** ← Correcto
- Self-consistency sin chain-of-thought para reducir latencia

**Explicación:** El requisito dual —**accuracy en razonamiento multi-paso** + **auditabilidad para stakeholders**— es el caso canónico de **CoT**. Al forzar al modelo a enumerar sus pasos, obtienes tanto mejor desempeño en razonamiento financiero como un rastro revisable. Zero-shot sería caja negra. Few-shot ayuda con formato pero no con razonamiento. Self-consistency sin CoT es contradictorio: necesitas cadenas para votar, y además la latencia es menos crítica que la explicabilidad en inversiones.

---

### Pregunta 4

Construiste un sistema de code review con few-shot usando **tres ejemplos**: uno de problema de seguridad, uno de performance y uno de código limpio. Ahora el sistema **marca casi todo como "problema de seguridad"**, incluyendo utilidades triviales. ¿Qué está pasando?

- Temperatura muy baja causa overfitting a patrones de seguridad
- Los ejemplos son demasiado similares y falta diversidad en tipos de problema
- Tres ejemplos están por debajo del rango óptimo 5-7 para tareas complejas
- **La distribución de ejemplos está sesgada hacia el enfoque de seguridad en vez de balancear tipos de issue** ← Correcto

**Explicación:** El modelo aprende la **distribución a priori** de los ejemplos. Con 1 de 3 etiquetado como seguridad (33%, y el único "problema identificado" por categoría dominante), implícitamente eleva la probabilidad de clasificar cualquier cosa como seguridad. La solución es **balancear**: añadir varios ejemplos limpios, varios de performance, varios de mantenibilidad, de modo que ninguna categoría quede sobrerrepresentada. La temperatura no causa overfitting; k=3 es suficiente para tareas simples; el problema es la **composición**, no la cantidad.

---

### Pregunta 5

Tu asistente de diagnóstico médico usa CoT para analizar síntomas: vitales → síntomas → diagnósticos diferenciales → tests recomendados. A veces **el razonamiento parece sólido pero llega a conclusiones incorrectas por supuestos erróneos en pasos tempranos**. ¿Cómo mejoras la confiabilidad?

- Cambiar a few-shot con casos clínicos en vez de pasos de razonamiento
- Implementar validación en checkpoints tras cada paso principal
- **Usar self-consistency con múltiples cadenas de razonamiento y elegir por consenso** ← Correcto
- Reducir la cantidad de pasos de razonamiento para minimizar oportunidades de error lógico

**Explicación:** **Self-consistency** (Wang et al., 2022) ataca exactamente este fallo: una sola cadena puede partir de un supuesto incorrecto y propagarlo coherentemente. Múltiples cadenas **independientes** tienden a converger en la respuesta correcta, mientras que los errores idiosincráticos se dispersan. El grado de consenso además cuantifica confianza —señal valiosa para enrutar casos de bajo consenso a revisión humana, crítico en medicina. Los checkpoints de validación ayudan, pero no detectan supuestos erróneos tan efectivamente como el consenso cruzado. Reducir pasos degrada el razonamiento. Few-shot sin CoT pierde la auditabilidad clínica.

---

### Pregunta 6

Tienes un sistema de análisis de sentimiento con zero-shot al **75% de accuracy**, aceptable para tu caso. Pero falla específicamente en **sarcasmo** y **sentimiento mixto** (*"Gran producto, pésimo servicio al cliente"*). ¿Cuál es la mejora más eficiente?

- Mantener zero-shot y añadir instrucciones explícitas sobre sarcasmo y mezcla
- Cambiar a chain-of-thought para razonar sobre indicadores de sentimiento
- **Añadir 4-5 ejemplos few-shot enfocados específicamente en sarcasmo y sentimiento mixto** ← Correcto
- Implementar self-consistency con 5 intentos para mejorar casos difíciles

**Explicación:** Con baseline zero-shot funcionando bien (**75%**) y fallos **localizados en patrones específicos**, few-shot dirigido es la intervención de **mayor ROI**: 4-5 ejemplos cubriendo exactamente sarcasmo y mezcla enseñan los patrones que la instrucción no captura, con un coste marginal en tokens. Instrucciones adicionales en zero-shot pueden ayudar poco porque el sarcasmo es inherentemente contextual. CoT es overkill y multiplica latencia/costo para un 25% de fallos. Self-consistency multiplica el costo 5x sin atacar la causa (el modelo falla **consistentemente** en estos patrones, el voto reforzaría el error).

---

## Resumen de criterios

| Síntoma / escenario | Técnica |
|---|---|
| Tarea común, alto volumen, costo crítico | **Zero-shot** |
| Formato específico o fronteras ambiguas | **Few-shot** (3-7 ejemplos balanceados) |
| Razonamiento multi-paso + necesidad de auditoría | **Chain-of-Thought** |
| Decisión crítica, errores por supuestos tempranos | **Self-Consistency** sobre CoT |
| Falla por falta de hechos actualizados | RAG (otro módulo) |
| Tarea requiere herramientas externas | **ReAct** / tool use |
| Dificultad alta y hay presupuesto | **Reasoning models** (o3, Claude thinking) |
