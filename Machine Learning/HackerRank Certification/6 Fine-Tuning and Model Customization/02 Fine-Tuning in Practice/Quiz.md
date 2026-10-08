# Quiz: Fine-Tuning en la Práctica

**Contexto del escenario:** estás fine-tuneando un modelo de lenguaje de 7B parámetros para un chatbot de soporte al cliente. Dispones de 2,000 interacciones de soporte, debes entrenar en una GPU de 16 GB y buscas al menos 90% de accuracy tanto en clasificación de tickets como en generación de respuestas.

---

## Pregunta 1

Tu chatbot debe manejar instrucciones variadas de los usuarios (clasificar tickets, generar respuestas, extraer información). ¿Qué enfoque de tuning debes usar?

- Completion tuning: es más eficiente
- **Instruction tuning: enseña al modelo a seguir instrucciones variadas** ✅
- Cualquiera funciona igual de bien
- Sólo full fine-tuning: los adapters no bastan

**Explicación:** instruction tuning entrena al modelo a interpretar y seguir instrucciones variadas, lo que lo hace adecuado para aplicaciones interactivas que manejan múltiples tipos de tarea en una misma interfaz. El formato recomendado es `{messages: [{role, content}, ...]}` con el chat template del modelo base (Llama 3, ChatML, etc.) y máscara de loss sobre los tokens del `assistant` únicamente. Completion tuning se queda corto porque no generaliza ante reformulaciones del usuario; full fine-tuning sería innecesariamente caro para esta tarea cuando LoRA logra 95-99% de la calidad con 10-100× menos memoria.

---

## Pregunta 2

Tienes 2,000 ejemplos para un chatbot que maneja clasificación y generación. ¿Es suficiente?

- Sí, 2,000 son más que suficientes para cualquier tarea
- **Sí, 2,000 son suficientes para tareas de complejidad moderada como chatbots** ✅
- No, necesitas al menos 10,000 ejemplos
- No, necesitas al menos 50,000 ejemplos

**Explicación:** el rango típico para instruction tuning de complejidad moderada (clasificación + generación en un dominio acotado) es **2,000-5,000 ejemplos de alta calidad**. Con menos de 500 corres riesgo de underfitting; más de 10,000 rinde retornos decrecientes salvo para tareas muy abiertas. La **calidad y diversidad** importan más que el volumen: 2,000 ejemplos balanceados por categoría, con cobertura de edge cases y 90%+ de calidad, superan a 10,000 ejemplos sucios y desbalanceados. Si identificas gaps de cobertura, complétalos con 20-30% de datos sintéticos validados.

---

## Pregunta 3

Tienes una GPU de 16 GB y quieres fine-tunear un modelo 7B. ¿Deberías usar LoRA o QLoRA?

- QLoRA: 16 GB no alcanza para LoRA
- **LoRA: 16 GB es suficiente y da mejor calidad** ✅
- QLoRA: siempre es mejor
- Full fine-tuning: los adapters no bastan

**Explicación:** LoRA sobre un 7B en `bf16` consume aproximadamente **14-18 GB** de VRAM con `gradient_checkpointing` activo y batch pequeño con acumulación — justo en el presupuesto de una GPU de 16 GB (RTX 3090/4090, A4000, Colab A100). Mantiene **precisión completa** del modelo base y evita el 1-3% de pérdida de calidad que introduce la cuantización 4-bit de QLoRA. QLoRA sería la elección si bajaras a 8 GB o si quisieras fine-tunear 13B+ en el mismo hardware. Full fine-tuning de un 7B requiere 80-100 GB, imposible en 16 GB.

---

## Pregunta 4

¿Qué configuración de LoRA es apropiada para una tarea de chatbot de complejidad moderada?

- `r=4, alpha=8`, sólo `q_proj`
- **`r=16, alpha=32`, `q_proj` y `v_proj`** ✅
- `r=128, alpha=256`, todas las capas lineales
- `r=8, alpha=8`, sólo `v_proj`

**Explicación:** `r=16` con `lora_alpha=32` (regla `alpha = 2·r`) es el default estándar para tareas de complejidad moderada: suficiente capacidad para aprender patrones variados sin sobre-parametrizar. Target modules `q_proj + v_proj` es el mínimo útil para atención; una mejora frecuente es extender a `q_proj, k_proj, v_proj, o_proj` para capacidad adicional sin coste significativo. Con `r=4` apenas captas señal (underfitting); con `r=128` sobre todas las capas lineales sobre-parametrizas, aumentas riesgo de overfitting y pierdes velocidad. Para esta configuración se entrenan ~0.1% de los parámetros totales (~8M sobre 7B).

---

## Pregunta 5

Durante el entrenamiento observas que la training loss baja de forma estable pero la validation loss aumenta después de la época 2. ¿Qué está ocurriendo?

- El modelo aprende bien, continúa entrenando
- **El modelo está sobreajustando (overfitting): aumenta dropout o reduce capacidad** ✅
- El modelo está subajustando: aumenta capacidad
- El entrenamiento es inestable: reduce el learning rate

**Explicación:** este patrón — `train_loss` ↓ mientras `val_loss` ↑ — es la **firma clásica del overfitting**: el modelo memoriza patrones específicos del training set que no generalizan al validation set. Las correcciones estándar son:

- Aumentar `lora_dropout` de 0.05 a 0.15.
- Reducir `r` (ej. de 16 a 8).
- Reducir `num_train_epochs` o activar `EarlyStoppingCallback(early_stopping_patience=3)` con `load_best_model_at_end=True`.
- Añadir `weight_decay=0.01`.
- Verificar que el dataset no tenga duplicados ni leaks entre train y val.

Si en cambio **ambas** losses fueran altas y planas, sería underfitting (fix: más rank, más target modules, más epochs). Si la curva fuera errática con spikes, sería inestabilidad (fix: bajar LR 10×, warmup, gradient clipping).

---

## Resumen de conceptos clave

- **Instruction vs completion tuning:** elige según interactividad y variedad de tareas.
- **Tamaño del dataset:** 2,000-5,000 ejemplos de calidad para complejidad moderada; prioriza calidad sobre volumen.
- **LoRA vs QLoRA:** LoRA en 16 GB+, QLoRA en 8 GB con 1-3% pérdida.
- **Config LoRA default:** `r=16, alpha=32, dropout=0.05, q/k/v/o`, `lr=2e-4`.
- **Lectura de curvas:** overfitting (val ↑), underfitting (ambas altas), instability (varianza), convergence (plateau).
- **Fixes rápidos:** overfitting → dropout + menos rank; underfitting → más rank + all-linear; inestabilidad → LR 10× menor + clipping + warmup.
- **Monitoreo:** W&B/TensorBoard siempre; early stopping y `load_best_model_at_end=True`.
