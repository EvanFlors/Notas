# Quiz: Redes Neuronales y Deep Learning

Este quiz consolida los conceptos de las tres lecciones del módulo: neuronas y capas, el proceso de entrenamiento y la evolución de arquitecturas. Cada pregunta incluye una **explicación detallada** de por qué la respuesta correcta lo es y por qué las demás opciones fallan.

---

## Pregunta 1

Tu modelo inicial de ML (regresión logística sobre métricas de código) alcanza 72% de accuracy, pero falla con patrones complejos como:

> *"La función adquiere un lock de base de datos en la transacción A, luego llama a una operación async que adquiere lock en la transacción B, provocando un posible deadlock."*

Según los principios de redes neuronales, **¿por qué el deep learning podría capturar mejor las vulnerabilidades de código que un enfoque de ML clásico?**

- A) Las redes neuronales pueden aprender relaciones entre partes distantes del código (declaraciones de variables, llamadas a funciones, patrones de uso).
- B) Las redes neuronales procesan la sintaxis del código más rápido que los parsers tradicionales.
- C) Las redes neuronales requieren menos datos de entrenamiento que ML tradicional.
- D) Las redes neuronales ofrecen resultados más interpretables para los desarrolladores.

**Respuesta correcta: A**

**Explicación:**
- **A es correcta.** El poder clave del deep learning es aprender **relaciones no lineales entre features distantes**. Un deadlock requiere conectar la línea 10 (declaración del lock) con la línea 25 (llamada async) y la línea 40 (adquisición del segundo lock). Una regresión logística suma independientemente las contribuciones de cada feature; una red profunda compone jerarquías de abstracciones (en especial Transformers con self-attention, que relacionan directamente cualquier par de tokens).
- **B es falsa.** Las redes neuronales **no son parsers**. Procesar un AST con un compilador es órdenes de magnitud más rápido que correr una inferencia neuronal, y las redes además necesitan tokenización previa.
- **C es falsa.** Es al revés: el deep learning es **famoso por requerir muchos más datos** que ML clásico. GPT-3 fue entrenado con cientos de miles de millones de tokens. Con poca data, un XGBoost suele superar a una red neuronal.
- **D es falsa.** Las redes neuronales son conocidas como **cajas negras**. Herramientas como SHAP, LIME o attention visualization ayudan, pero la interpretabilidad es sustancialmente **peor** que en un modelo lineal o un árbol de decisión.

---

## Pregunta 2

Tu red neuronal muestra estos resultados:

- Accuracy en entrenamiento: **91%**
- Accuracy en validación: **74%**
- Accuracy en test: **69%**

**¿Qué indica este patrón?**

- A) El modelo está haciendo underfitting y necesita más capas o parámetros.
- B) El modelo está sobre-ajustando (overfitting) los datos de entrenamiento y posiblemente memorizó patrones específicos de código.
- C) El set de validación es demasiado distinto al de entrenamiento.
- D) Es una degradación normal esperada en producción.

**Respuesta correcta: B**

**Explicación:**
- **B es correcta.** La brecha de **17 puntos entre train (91%) y val (74%)** es el síntoma textbook de **overfitting**: el modelo aprendió patrones específicos de los ejemplos de entrenamiento (incluso ruido) en lugar de patrones generalizables. En entrenamiento rinde bien porque "recuerda" los ejemplos; en val/test, al ver datos nuevos, falla.
- **A es falsa.** Underfitting se caracteriza por **train y val bajos y parecidos** (ej. train 70%, val 68%): el modelo es demasiado simple para capturar los patrones. Aquí el train es alto, así que capacidad sobra.
- **C es falsa.** Si val y test estuvieran mal muestreados, verías discrepancias **entre val y test**, no entre train y val. Val (74%) y test (69%) son razonablemente consistentes.
- **D es falsa.** Degradación en producción es un fenómeno distinto (**data drift**, concept drift) y ocurre con el tiempo tras el despliegue. No se detecta midiendo val/test ambos construidos antes del despliegue.

**Soluciones típicas al overfitting:** más datos, data augmentation, **dropout**, **weight decay (L2)**, **early stopping**, reducir capacidad del modelo.

---

## Pregunta 3

Para una herramienta de revisión de código integrada en el flujo de trabajo del desarrollador, **¿cuál es la restricción más crítica para la adopción?**

- A) El modelo debe alcanzar 95%+ de accuracy antes de que los desarrolladores confíen en él.
- B) El modelo debe dar feedback casi instantáneo (bajo 500ms) para encajar en el flujo de codificación.
- C) El modelo debe funcionar igual de bien en todos los lenguajes de programación.
- D) El modelo debe ser suficientemente interpretable como para explicar cada decisión.

**Respuesta correcta: B**

**Explicación:**
- **B es correcta.** Un desarrollador tipea decenas de líneas por minuto. Si cada sugerencia tarda 3-5 segundos, **rompe el flujo cognitivo (flow)** y la herramienta se abandona. GitHub Copilot y Cursor obsesionan con latencia bajo 500 ms justamente por esto. La **UX en tiempo real** supera a la precisión perfecta: un modelo 85% preciso con <200ms gana adopción sobre uno 95% preciso con 3s.
- **A es falsa.** Nadie exige 95% para herramientas asistenciales. Los desarrolladores toleran sugerencias imperfectas si pueden ignorarlas con un `Esc`. Copilot ronda ~30% de sugerencias aceptadas y aun así es masivo. El estándar es "mejor que no tener", no "perfecto".
- **C es falsa.** Es deseable, pero no bloqueante. Un modelo que domina Python y JavaScript (los dos lenguajes más usados) ya cubre a la mayoría. Se puede expandir soporte progresivamente.
- **D es falsa.** La interpretabilidad **ayuda** a la confianza pero no es un requisito duro en herramientas de desarrollo. Copilot no "explica" por qué sugiere algo y aun así es exitoso. En dominios regulados (finanzas, salud) sí es obligatoria; en dev tools no.

---

## Pregunta 4

Para resolver el problema de overfitting, **¿qué enfoque está alineado con las buenas prácticas de entrenamiento de redes neuronales?**

- A) Recolectar más datos de entrenamiento de los mismos codebases.
- B) Aumentar la complejidad del modelo para ajustar mejor los datos de entrenamiento.
- C) Aplicar técnicas de regularización (dropout, weight decay) y usar early stopping basado en el desempeño de validación.
- D) Eliminar el set de validación y entrenar solo con los datos de entrenamiento.

**Respuesta correcta: C**

**Explicación:**
- **C es correcta.** Son las tres técnicas estándar contra overfitting:
  - **Dropout**: durante entrenamiento, apaga aleatoriamente un porcentaje (típ. 0.1–0.5) de neuronas, forzando redundancia.
  - **Weight decay (L2)**: penaliza pesos grandes añadiendo `λ·||θ||²` a la loss, favoreciendo soluciones más simples.
  - **Early stopping**: detiene el entrenamiento cuando el val loss deja de mejorar durante `N` epochs (patience).
- **A es parcialmente útil pero insuficiente.** Más datos ayudan, pero si vienen del **mismo codebase** no amplían la diversidad. El modelo seguirá sin generalizar a estilos de código distintos. Si vas a invertir en datos, prioriza **diversidad** (varios repos, estilos, lenguajes), no volumen del mismo origen.
- **B es exactamente lo opuesto.** Aumentar capacidad en un modelo que ya memoriza **empeora el overfitting**: le das más parámetros con los cuales memorizar. La capacidad debe reducirse o mantenerse mientras agregas regularización.
- **D es un error grave.** El set de validación es tu **única señal honesta** del desempeño en datos no vistos. Sin él, no puedes detectar overfitting, elegir hiperparámetros ni decidir cuándo parar. Eliminarlo garantiza entregar a producción un modelo roto.

---

## Pregunta 5

Tu red neuronal detecta correctamente el 85% de los bugs, pero genera muchos **falsos positivos**. Para la adopción por parte de desarrolladores, **¿cómo debes priorizar las mejoras?**

- A) Enfocarte únicamente en aumentar el recall para atrapar más bugs.
- B) Equilibrar mejoras de precision para reducir falsas alarmas, manteniendo un recall razonable.
- C) Optimizar la accuracy global sin importar el trade-off precision/recall.
- D) Priorizar la interpretabilidad del modelo sobre el desempeño de predicción.

**Respuesta correcta: B**

**Explicación:**
Recordemos las métricas:

```
Precision = TP / (TP + FP)   ← de las alertas emitidas, ¿cuántas son reales?
Recall    = TP / (TP + FN)   ← de los bugs reales, ¿cuántos detecté?
F1        = 2·P·R / (P + R)  ← media armónica
```

- **B es correcta.** El problema explícito son **falsos positivos** (baja precision). Cada falso positivo cuesta tiempo al desarrollador (investigar un bug que no existe) y erosiona la confianza en la herramienta. Al tercer o cuarto falso positivo, el desarrollador la **desactiva**. Hay que subir precision (menos ruido) sin desplomar el recall (seguir detectando bugs reales). Esto se hace subiendo el **umbral de decisión**, re-balanceando con `class_weight`, o usando *cost-sensitive learning*.
- **A es exactamente contraria al diagnóstico.** Subir recall típicamente **empeora precision** (bajas el umbral → más TP pero también más FP). Dado que el síntoma ya es "demasiados FP", esto profundiza el problema.
- **C es engañosa.** La accuracy global es inútil en problemas desbalanceados: si el 99% del código no tiene bugs, un modelo que **nunca alerta** tiene 99% accuracy y es completamente inservible. La métrica correcta en seguridad/calidad es precision, recall, F1 o PR-AUC.
- **D es un *red herring*.** La interpretabilidad es valiosa, pero no soluciona falsos positivos: un modelo interpretable que grita 100 falsas alarmas por día sigue siendo inútil. Primero arregla la calidad de la señal, luego la explicabilidad.

**Analogía:** una alarma de incendios que suena cada vez que alguien tuesta pan terminará siendo silenciada permanentemente. El valor de detectar incendios reales se destruye por el ruido.

---

## Resumen de conceptos evaluados

| Pregunta | Concepto clave |
|---|---|
| 1 | Capacidad de las redes neuronales para capturar **relaciones no lineales distantes** |
| 2 | Diagnóstico de **overfitting** vía gap train/val |
| 3 | Restricciones **operacionales (latencia)** en despliegue de modelos |
| 4 | Técnicas estándar contra overfitting: **dropout, weight decay, early stopping** |
| 5 | Trade-off **precision vs. recall** y por qué accuracy no basta en clases desbalanceadas |
