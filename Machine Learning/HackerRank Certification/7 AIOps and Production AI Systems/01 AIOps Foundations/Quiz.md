## Quiz: Fundamentos de AIOps

Tu empresa está desplegando su primer modelo de machine learning en producción: un sistema de recomendación que sugiere productos a los usuarios. El modelo fue entrenado y validado con buenas métricas offline (92% de accuracy). Tú eres responsable de los aspectos operativos de este despliegue.

---

### Pregunta 1

El modelo de recomendación lleva dos semanas en producción. Las métricas de infraestructura muestran 100% de uptime, cero errores y latencia normal. Sin embargo, los usuarios reportan que las recomendaciones son cada vez menos relevantes. ¿Qué enfoque de monitoreo habría detectado este problema?

- Monitoreo DevOps tradicional de CPU, memoria y tasa de errores.
- Monitoreo MLOps de la ejecución del pipeline de entrenamiento.
- **Monitoreo AIOps de distribuciones de predicción y métricas de negocio.**
- Monitoreo de rendimiento de queries de base de datos.

**Respuesta correcta:** Monitoreo AIOps de distribuciones de predicción y métricas de negocio.

**Explicación:** este es un caso clásico de **fallo silencioso**: el servicio responde correctamente a nivel de infraestructura pero la calidad real de las predicciones se degrada. Las métricas tradicionales de DevOps (CPU, RAM, códigos HTTP) solo miden si el servicio "responde", no si lo hace *bien*. El monitoreo MLOps se enfoca en el pipeline de entrenamiento, no en inferencia en producción. AIOps añade específicamente observabilidad sobre **distribuciones de inputs** (data drift), **distribuciones de outputs** (prediction drift) y **métricas de negocio** (CTR, conversión), que son las únicas que detectan degradación de calidad cuando todo lo demás luce verde.

---

### Pregunta 2

Durante el entrenamiento, tu modelo procesa 1 millón de interacciones de usuarios en 2 horas usando 4 GPUs. En producción, el modelo necesita servir recomendaciones individuales en menos de 100ms. ¿Cuál es la diferencia de infraestructura más crítica?

- **Serving necesita baja latencia por request mientras training necesita alto throughput.**
- Training necesita más almacenamiento que serving.
- Training requiere CPUs mientras serving requiere GPUs.
- Training necesita networking más rápido que serving.

**Respuesta correcta:** Serving necesita baja latencia por request mientras training necesita alto throughput.

**Explicación:** los entornos de entrenamiento y de serving son **opuestos en sus optimizaciones**. Training procesa batches enormes a lo largo de horas, maximizando throughput sin importar la latencia de ejemplos individuales (6 horas vs 4 horas es irrelevante). Serving procesa requests individuales en milisegundos: cada ejemplo cuenta y la latencia es visible para el usuario. Esta diferencia fundamental impacta en el tamaño de batch, el tipo de GPU, la arquitectura del servicio y las técnicas de optimización (dynamic batching, cuantización, caching). Las otras opciones son incorrectas: training suele usar GPUs grandes mientras serving puede usar GPUs chicas o incluso CPUs; el almacenamiento depende del caso; el networking de alta velocidad es más crítico en training distribuido que en serving.

---

### Pregunta 3

La accuracy de tu modelo cae súbitamente de 92% a 78%. Tienes el archivo del modelo, pero no la versión de los datos de entrenamiento, los hiperparámetros ni la versión exacta del código usado para entrenarlo. ¿Por qué es un problema?

- No puedes reentrenar el modelo sin las especificaciones exactas de GPU.
- El archivo del modelo es inutilizable sin metadata de almacenamiento.
- El versionado de modelos solo importa para requisitos de compliance.
- **No puedes debuggear ni reproducir el modelo sin lineage completo de artefactos.**

**Respuesta correcta:** No puedes debuggear ni reproducir el modelo sin lineage completo de artefactos.

**Explicación:** la **reproducibilidad** en IA requiere versionar simultáneamente **cinco artefactos**: código, datos, modelo, configuración (hiperparámetros) y dependencias. Si falta cualquiera de ellos, no puedes determinar qué cambió entre el modelo que funcionaba (92%) y el que falla (78%). ¿Fue drift en los datos? ¿Un cambio de código? ¿Diferentes hiperparámetros? Sin lineage completo es imposible saberlo. Herramientas como MLflow (metadata), DVC (datos) y Git (código) existen precisamente para resolver este problema. Las especificaciones de GPU rara vez son el bloqueador; el compliance es una consecuencia, no la causa raíz; y la metadata de almacenamiento es irrelevante para debugging.

---

### Pregunta 4

Las pruebas muestran que tu modelo tarda 200ms por predicción en CPUs y 10ms en GPUs. Las instancias de CPU cuestan $0.50/hora y las de GPU cuestan $3/hora. A 1,000 predicciones por segundo, ¿qué elección de infraestructura es más rentable?

- Usar siempre GPUs porque son 20x más rápidas.
- **Calcular cuántas instancias de cada tipo necesitas y comparar el costo total.**
- Usar CPUs porque cuestan menos por instancia.
- Usar aceleradores especializados como TPUs para minimizar costo.

**Respuesta correcta:** Calcular cuántas instancias de cada tipo necesitas y comparar el costo total.

**Explicación:** el costo correcto se calcula multiplicando el **precio por hora** por el **número de instancias necesarias** para atender la carga. Hagamos la matemática:

- **CPU:** 200ms por predicción = **5 req/s por instancia**. Para 1,000 req/s → **200 instancias** × $0.50 = **$100/hora**.
- **GPU:** 10ms por predicción = **100 req/s por instancia**. Para 1,000 req/s → **10 instancias** × $3 = **$30/hora**.

GPU es ~3.3x más barata en este escenario a pesar de costar 6x más por instancia, porque atiende 20x más throughput. Esta es la lección clave: la decisión CPU vs GPU **no es intuitiva** y requiere medir throughput real + costo. "Siempre GPU" es incorrecto para modelos pequeños con tráfico bajo; "siempre CPU" es incorrecto para modelos neuronales a volumen alto; "siempre aceleradores especializados" ignora el costo de portabilidad, compatibilidad y lock-in.

---

### Pregunta 5

Tu modelo está listo para desplegar. Tienes tiempo limitado para implementar salvaguardas adicionales. ¿Qué elemento del checklist de preparación para producción deberías priorizar?

- **Monitoreo, alertas y un procedimiento de rollback probado.**
- Documentación de API exhaustiva para todos los endpoints.
- Optimización de rendimiento para reducir latencia en 50%.
- Framework de A/B testing para rollout gradual.

**Respuesta correcta:** Monitoreo, alertas y un procedimiento de rollback probado.

**Explicación:** monitoreo + alertas + rollback son el **mínimo irrenunciable** para desplegar cualquier sistema de IA. Sin monitoreo, estás desplegando a ciegas y los problemas los descubrirán los usuarios (o peor, no los descubrirás nunca si son silenciosos). Sin alertas, el monitoreo es inútil porque nadie los revisa en tiempo real. Sin rollback probado, cuando el modelo falle no tendrás ruta de escape rápida y el incidente se extenderá. Las otras opciones son valiosas pero secundarias: documentación mejora la mantenibilidad pero no previene incidentes; optimizar más allá del SLO es prematura optimización; A/B testing es útil pero complementa, no sustituye, la capacidad básica de detectar y revertir fallos. Regla práctica: **nunca despliegues sin tener un botón de "deshacer" ensayado**.
