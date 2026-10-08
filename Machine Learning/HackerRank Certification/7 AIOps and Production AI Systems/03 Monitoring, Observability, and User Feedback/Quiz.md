# Quiz: Monitoreo, Observabilidad y Feedback del Usuario

---

### Pregunta 1

Tu modelo de recomendación en producción muestra infraestructura perfectamente sana: CPU al 40%, memoria estable, latencia p95 de 120 ms, cero errores HTTP. Sin embargo, el equipo de producto reporta que el CTR ha caído un 15% durante las últimas dos semanas. ¿Qué estrategia de monitoreo habría detectado este problema a tiempo?

- a) Añadir más alertas sobre uso de CPU y memoria para detectar saturación oculta.
- b) **Implementar monitoreo de la distribución de predicciones y detección de data drift sobre las features de entrada.**
- c) Aumentar la frecuencia del muestreo de métricas de latencia a cada segundo.
- d) Configurar alertas sobre el throughput del servicio.

**Explicación:** El síntoma clásico de un **fallo silencioso del modelo**: la infraestructura responde bien pero el modelo entrega predicciones cada vez menos útiles. CPU, latencia y errores no capturan calidad; sí lo hace monitorear cómo cambia la distribución de inputs (data drift) y la distribución de outputs del modelo. Es exactamente el tipo de problema para el que las métricas de modelo (no de servicio) existen.

---

### Pregunta 2

Un endpoint de clasificación tarda en promedio 500 ms por request. Al instrumentar con tracing distribuido descubres que **350 ms** se consumen en la etapa de "feature retrieval" (consulta a feature store) y solo 80 ms en la inferencia del modelo. ¿Qué acción tiene mayor impacto?

- a) Reemplazar el modelo por una arquitectura más pequeña y rápida.
- b) Añadir más réplicas del servicio de inferencia para absorber la carga.
- c) **Optimizar la etapa de feature retrieval con caching y/o batching, por ejemplo con un cache en memoria o Redis para features de baja volatilidad.**
- d) Mover todo el pipeline a GPUs más potentes.

**Explicación:** El principio de optimización es claro: **atacar el cuello de botella mayor**. El 70% de la latencia (350/500) está en feature retrieval, no en inferencia. Reducir el modelo o escalar GPUs apenas afectaría los 80 ms de inferencia. Caching de features frecuentes puede recortar la mayor parte de esos 350 ms y es un cambio de alto ROI.

---

### Pregunta 3

El monitoreo reporta un **PSI = 0.32** sobre varias features de entrada, y la accuracy del modelo cayó del 92% al 85% durante las últimas tres semanas. ¿Cuál es la respuesta correcta?

- a) Aumentar la capacidad del hardware; probablemente es un problema de recursos.
- b) Ignorar la alerta: PSI bajo 0.5 no es relevante estadísticamente.
- c) **Reentrenar el modelo con datos recientes que reflejen la nueva distribución, validarlo offline contra el baseline y desplegar con canary.**
- d) Rebajar el umbral de PSI para que la alerta no vuelva a dispararse.

**Explicación:** Un **PSI > 0.25 se considera drift severo** y, combinado con una caída concreta de 7 puntos de accuracy, confirma degradación real (no un falso positivo). La respuesta correcta es reentrenar con datos actuales, validar que el nuevo modelo supere al champion y promoverlo con canary para controlar riesgo. Silenciar la alerta o aumentar hardware ignora el problema real.

---

### Pregunta 4

Operas un modelo de detección de fraude en el que las etiquetas verdaderas (chargebacks, disputas confirmadas) tardan **2-3 semanas** en llegar. ¿Cómo monitoreas la performance mientras tanto?

- a) Esperar las etiquetas y calcular métricas únicamente cuando lleguen.
- b) **Combinar métricas proxy en tiempo real (distribución de scores, confianza, tasa de intervención manual, aprobaciones) con validación diferida contra las etiquetas reales cuando lleguen.**
- c) Usar accuracy sobre predicciones aleatorias como estimador.
- d) Confiar únicamente en alertas de infraestructura hasta tener los labels.

**Explicación:** Cuando el ground truth es tardío, las **métricas proxy** son indispensables para detectar degradación temprano: la distribución de scores, la confianza del modelo, la tasa de aprobación/rechazo y la tasa de override humano son señales inmediatas. En paralelo, se mantiene la **validación diferida** contra las etiquetas reales cuando llegan para calcular las métricas verdaderas (precision/recall) y recalibrar los proxies.

---

### Pregunta 5

Un A/B test comparó la variante A (modelo actual, CTR 5.0%) contra la variante B (modelo nuevo, CTR 5.5%), con **10,000 usuarios por variante y p-value = 0.03**. El nuevo modelo cuesta 3x más por inferencia. ¿Qué deberías hacer?

- a) Promover inmediatamente la variante B: la diferencia es estadísticamente significativa.
- b) Descartar la variante B: la diferencia es despreciable.
- c) **Evaluar si la mejora absoluta de 0.5 pp justifica el costo 3x mayor, considerando guardrails (latencia, retención), magnitud real del lift y segmentos donde el efecto es mayor; posiblemente correr el experimento más tiempo o en segmentos específicos.**
- d) Ignorar el p-value porque el tamaño de muestra es insuficiente.

**Explicación:** El error clásico es confundir **significancia estadística** con **relevancia práctica**. Un p=0.03 confirma que la diferencia probablemente no es azar, pero una mejora absoluta de 0.5 pp (lift relativo ~10%) contra un costo 3x requiere un análisis económico: ¿el margen por conversión cubre el aumento de inferencia? ¿empeoran guardrails como latencia o retención? ¿hay segmentos donde la mejora sea mayor y donde desplegar solo allí tenga sentido?

---

### Pregunta 6

Tu dashboard muestra: utilización de GPU al **95%**, latencia p99 de 450 ms (SLA 500 ms), **shift del 20%** en la distribución de predicciones vs. la semana pasada, y revenue atribuible **+5%**. ¿Qué métrica es más preocupante?

- a) El revenue +5% podría indicar fraude o abuso.
- b) La latencia p99 de 450 ms cerca del SLA es el principal riesgo.
- c) **La utilización de GPU al 95%: no deja headroom para picos de tráfico ni para procesos de rebalance; cualquier pequeña variación puede violar el SLA de latencia y causar un incidente.**
- d) El shift del 20% en predicciones no requiere acción si el revenue sube.

**Explicación:** Con GPU al 95% no hay **margen de saturación**: cualquier aumento de tráfico, un deploy, un cold start o una campaña empujará la latencia por encima del SLA y disparará errores. El p99 ya está a 50 ms del límite, lo que confirma que el sistema está operando al borde. Aunque el shift del 20% también merece investigación (podría explicar el +5% o esconder drift), el riesgo inmediato de incidente proviene de la **falta de headroom en GPU**, principio directo de la señal dorada de **saturación**.
