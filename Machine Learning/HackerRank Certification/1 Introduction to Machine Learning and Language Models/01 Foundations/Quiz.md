# Quiz: Fundamentos y Ciclo de Vida de ML

> **Contexto del escenario:** Tu equipo de ingeniería depende de herramientas de análisis estático para la calidad del código, pero pasan por alto el 65% de los bugs que luego causan incidentes en producción. Cuentas con 18 meses de historial de Git con:
>
> - 50,000 commits en varios servicios (APIs backend, pipelines de datos, microservicios).
> - Reportes de bugs reportados 1-3 semanas después de los commits (solo el 4% de los commits tiene un bug asociado).
> - Métricas de código: complejidad, tamaño de archivo, número de cambios, dependencias.
> - Feedback y aprobaciones de code review manual.

---

## Pregunta 1

Según los fundamentos de ML, ¿qué hace de este escenario un buen candidato para machine learning en lugar de expandir las reglas de análisis estático?

- [ ] ML procesará el código más rápido que las herramientas de análisis estático basadas en reglas.
- [ ] Los modelos de ML son más fáciles de mantener que actualizar configuraciones de linters.
- [x] **Los patrones de bugs evolucionan con nuevos frameworks y prácticas de codificación más rápido de lo que las reglas pueden actualizarse manualmente.**
- [ ] ML provee mejores mensajes de error que las herramientas tradicionales de linting.

**Explicación:**

La respuesta correcta captura la **razón fundamental** por la que ML existe: cuando los patrones **cambian más rápido** de lo que un humano puede codificar reglas, un sistema que aprende de datos escala mejor. Esto es exactamente el caso de "whack-a-mole" descrito en Lesson-01: nuevos frameworks (React Server Components, async/await, nuevos ORMs) introducen bugs nuevos cada trimestre. Mantener cientos de reglas de linter sincronizadas con el ecosistema es insostenible; un modelo entrenado sobre bugs reales se actualiza simplemente con re-entrenar sobre datos frescos.

Las otras opciones son incorrectas:

- **Velocidad:** falso. El análisis estático basado en AST suele ser **más rápido** que inferir con un modelo (microsegundos vs milisegundos). La velocidad no es ventaja de ML aquí.
- **Mantenimiento:** falso de manera engañosa. Un modelo ML requiere **más** infraestructura (versionado de datos, retraining, monitoreo de drift) que un archivo `.eslintrc`. Los linters son triviales de mantener comparados con un pipeline MLOps completo.
- **Mejores mensajes de error:** falso. Los linters están diseñados para dar mensajes accionables ("variable `foo` nunca usada en línea 42"). Un clasificador binario "este commit es buggy" sin explicación es *peor* para el developer. La ventaja real debe venir de SHAP/explicabilidad y aun así suele ser inferior a un buen linter en claridad.

---

## Pregunta 2

¿Qué tipo de problema de machine learning es "predecir qué commits de código tendrán bugs descubiertos más tarde"?

- [x] **Clasificación supervisada (commits con bugs descubiertos luego vs. commits limpios).**
- [ ] Clustering no supervisado (agrupando patrones de código similares).
- [ ] Aprendizaje por refuerzo (aprendiendo del feedback de code review a lo largo del tiempo).
- [ ] Aprendizaje semi-supervisado (usando historial de commits parcialmente etiquetado).

**Explicación:**

Es **clasificación supervisada binaria**: tienes pares `(commit_features, bug_label)` donde la etiqueta es `1` si el commit resultó en un bug reportado dentro de 1-3 semanas, `0` en caso contrario. El objetivo es aprender `f(commit) → P(bug)`. Las clases están desbalanceadas (4% positivos), lo cual exige elegir métricas como **AUC-PR** y **recall en la clase minoritaria**, no accuracy.

Por qué las otras son incorrectas:

- **Clustering no supervisado:** descubriría grupos de commits similares, pero no te dice *cuáles son buggy*. Podrías usarlo para análisis exploratorio ("¿qué tipos de commits existen?") pero no resuelve la pregunta de predicción.
- **Refuerzo:** RL aplica cuando tomas una secuencia de acciones y recibes recompensa diferida. Aquí no hay "acción" del modelo que modifique el entorno; solo clasifica. Podría tener sentido si estuvieras construyendo un bot que *sugiere refactors* y aprende de aceptaciones, pero no para predicción pasiva.
- **Semi-supervisado:** sería válido **solo si tuvieras muchos commits sin label**. El enunciado dice que el 4% tiene bugs asociados, pero el otro 96% *también está etiquetado* implícitamente como "sin bug reportado". Todos los commits tienen label (binario). Semi-supervisado aplicaría si, por ejemplo, solo 2% de commits tuviera label confiable y el resto fuera incierto.

---

## Pregunta 3

Dado que los bugs se descubren 1-3 semanas después de los commits, ¿cómo deberías estructurar tus data splits?

- [ ] Split aleatorio 70/15/15 para asegurar muestreo representativo.
- [ ] Split por repositorio: algunos codebases para training, otros para testing.
- [x] **Split basado en tiempo con buffer de 3 semanas: entrenar en commits antes de la semana N-3, testear en commits después de la semana N.**
- [ ] Split por desarrollador: commits de algunos programadores para training, otros para testing.

**Explicación:**

Esta es la respuesta correcta porque **respeta la realidad temporal del problema**. En producción, al predecir si un commit nuevo es buggy, **no sabes aún** si causará bugs porque el período de observación (1-3 semanas) no ha transcurrido. Si usas un split aleatorio, tu test set contiene commits cuyos labels se "conocen" solo porque son del pasado — en producción no tendrías esa información. El **buffer de 3 semanas** es crítico: garantiza que todos los labels del training set ya estén "completos" (todos los bugs posibles ya fueron reportados), evitando que commits recientes en train tengan labels incompletos (etiquetados como "limpios" solo porque aún no se descubre su bug).

Por qué las otras son incorrectas:

- **Split aleatorio 70/15/15:** causa **data leakage temporal**. El modelo "ve el futuro" durante el training. Es el error más común y caro en series de tiempo. En el notebook la métrica luce espectacular; en producción colapsa.
- **Split por repositorio:** útil para evaluar **generalización cross-codebase** (¿funciona en un servicio nuevo?), pero no resuelve el problema temporal. Dentro de cada repo seguirías mezclando pasado y futuro. Puede ser una **evaluación secundaria** complementaria, no la primaria.
- **Split por desarrollador:** mismo problema temporal + sesgo por estilo personal. Además, en producción el modelo debe funcionar para los mismos desarrolladores del training (no es que vayan a ser otros). Es un split artificial que no refleja el patrón de uso real.

---

## Pregunta 4

Tu modelo inicial logra 78% de accuracy en datos de validación. El equipo quiere desplegarlo inmediatamente porque "funciona mejor que adivinar al azar". ¿Cuál es la información crítica faltante?

- [ ] 78% de accuracy es demasiado bajo para cualquier sistema de análisis de código en producción.
- [x] **Necesitas entender la tasa base de detección de bugs de las herramientas actuales y el costo de falsos positivos vs. falsos negativos.**
- [ ] El modelo necesita alcanzar al menos 90% de accuracy antes del despliegue en producción.
- [ ] La accuracy no importa si el modelo puede explicar sus decisiones.

**Explicación:**

Esta respuesta encapsula **dos principios fundamentales** de evaluación en producción:

1. **Baseline comparison:** 78% no significa nada sin contexto. Dado el desbalance 96/4, un modelo que "siempre predice limpio" tiene **96% de accuracy** y es inútil. Más aún, el enunciado dice que las herramientas actuales atrapan ~35% de los bugs (pierden 65%). Debes comparar el **recall** del modelo nuevo contra ese baseline, no la accuracy global. Si el modelo nuevo tiene 78% accuracy pero recall en la clase "buggy" de solo 20%, estás **empeorando** la detección respecto al status quo.

2. **Costo asimétrico de errores:** un **falso negativo** (bug no detectado → incidente en producción) puede costar horas de downtime, pérdida de revenue y daño reputacional. Un **falso positivo** (commit limpio marcado como riesgoso → review manual innecesario) cuesta minutos de un ingeniero. Si FN es 100× más caro que FP, debes optimizar **recall** incluso sacrificando precision — y la métrica relevante es el **costo total esperado**, no accuracy.

Por qué las otras son incorrectas:

- **"78% es demasiado bajo":** afirmación arbitraria sin fundamento. Un modelo con 60% accuracy puede ser excelente si supera el baseline con significancia y el ratio precision/recall es apropiado para el costo del negocio. "Alto" o "bajo" solo tiene sentido relativo.
- **"Necesita 90%":** umbral mágico sin justificación. En problemas desbalanceados, 90% accuracy puede ser trivial (predecir siempre la mayoría) y aun así inútil. En problemas intrínsecamente difíciles (ej. predecir churn individual), 70% puede ser estado del arte.
- **"La accuracy no importa si el modelo puede explicar":** falso dilema. Explicabilidad (SHAP, LIME) es **complementaria** al desempeño, no sustituta. Un modelo explicable pero inexacto da explicaciones convincentes de decisiones equivocadas — potencialmente **peor** que un modelo opaco pero correcto, porque genera falsa confianza.

---

## Pregunta 5

Durante el desarrollo del modelo, descubres que tu accuracy de validación es 78% pero cae a 65% al testear en un codebase completamente diferente. Esto indica:

- [ ] El modelo está haciendo underfitting y necesita más complejidad.
- [ ] 65% de accuracy sigue siendo aceptable para despliegue en producción.
- [x] **El modelo ha hecho overfitting a estilos de código específicos y patrones en los datos de entrenamiento.**
- [ ] El codebase de prueba tiene tipos de bugs fundamentalmente diferentes.

**Explicación:**

La caída de 78% → 65% al cambiar de **distribución** (otro codebase) es el síntoma clásico de **overfitting a características específicas del dominio de entrenamiento**: convenciones de naming del equipo, patrones arquitectónicos particulares, estilo de los linters configurados, imports habituales. El modelo aprendió "en este codebase, archivos con más de 300 líneas y nombres de variables cortos tienden a ser buggy" — regla que no transfiere a un codebase con otras convenciones.

Esto es **distinto del overfitting clásico** (train > val en el mismo distribución). Aquí es **distribution shift** o **domain shift**: el gap train/val en el mismo codebase puede ser pequeño, pero el gap *entre codebases* es grande. Técnicamente también se llama **falta de generalización out-of-distribution (OOD)**.

Las soluciones típicas:

- **Features más abstractas** (métricas universales como complejidad ciclomática, no identificadores literales).
- **Multi-domain training:** entrenar con commits de varios codebases desde el principio.
- **Domain adaptation / transfer learning:** fine-tunear el modelo en una muestra del nuevo codebase.
- **Regularización más fuerte** (L2, dropout, feature selection).

Por qué las otras son incorrectas:

- **Underfitting:** sería el diagnóstico si **ambas métricas** (train y validation) fueran bajas. Aquí train+val están razonables, lo que falla es el **test cross-domain**. Añadir complejidad empeoraría el overfit.
- **"65% es aceptable":** repite el error de la pregunta 4. Sin baseline del codebase destino y sin análisis de costo, afirmar aceptabilidad es irresponsable. Más aún, si cae 13 puntos al cambiar de dominio, cada despliegue en un codebase nuevo tendrá desempeño impredecible.
- **"Bugs fundamentalmente diferentes":** puede ser un factor **contribuyente**, pero el diagnóstico primario sigue siendo overfit a patrones específicos. Además, es una hipótesis no verificada por la evidencia dada — necesitarías análisis de los tipos de bug para sustentarla. El overfitting a estilo es la explicación más parsimoniosa y accionable.

---

## Resumen de principios cubiertos

| Pregunta | Principio clave |
|---|---|
| 1 | ML aplica cuando los patrones **cambian más rápido** que las reglas que un humano pueda escribir |
| 2 | **Identificar el paradigma correcto** parte de preguntar qué señal de supervisión existe |
| 3 | Los **splits deben reflejar la realidad temporal** de producción (buffer para delayed labels) |
| 4 | **Siempre comparar contra baseline** y considerar el costo asimétrico de FP vs FN |
| 5 | **Distribution shift** causa caída de desempeño cross-domain; distinguirlo de overfitting intra-domain |
