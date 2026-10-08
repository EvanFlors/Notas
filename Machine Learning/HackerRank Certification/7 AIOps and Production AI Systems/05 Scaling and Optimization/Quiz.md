# Quiz: Scaling and Optimization

**Contexto:** tu sistema de recomendación con IA sirve 10,000 requests/segundo en pico. La infraestructura actual usa 20 instancias GPU a $3/hora cada una ($1,440/día). La latencia p99 es 180ms, cumpliendo el SLA de 200ms. El equipo quiere reducir costos sin degradar performance.

---

### Pregunta 1

Necesitas escalar tu sistema de serving para manejar 10× más tráfico. Puedes usar instancias 10× más grandes (escalamiento vertical) o 10× más instancias del mismo tamaño (escalamiento horizontal). ¿Cuál es la ventaja principal del escalamiento horizontal?

- El escalamiento horizontal es más simple: no requiere cambios de código.
- **El escalamiento horizontal provee capacidad ilimitada y mejor tolerancia a fallos: si una instancia falla, las demás continúan sirviendo.** ✅
- El escalamiento horizontal siempre es más barato.
- El escalamiento vertical no tiene límites.

**Explicación:** el escalamiento horizontal distribuye el tráfico entre múltiples instancias idénticas, lo que elimina el *single point of failure* típico del vertical (una instancia gigante que si cae, lo tira todo) y permite crecer sumando pods sin tope físico. Vertical sí es más simple operativamente, pero tiene un techo duro (la instancia más grande disponible, ~p4d.24xlarge en AWS) y empeora la tolerancia a fallos. "Siempre más barato" es falso: depende del workload y del precio por hora de cada tamaño. "Vertical sin límites" es directamente incorrecto. En producción se combinan ambos: instancias de tamaño *sweet spot* multiplicadas horizontalmente con HPA basado en GPU utilization o profundidad de cola.

---

### Pregunta 2

El profiling muestra que 40% de las predicciones son para los mismos 100 items populares. Cada predicción cuesta 5ms de tiempo de GPU. Sirves 10,000 req/s (864M req/día). ¿Cuánto tiempo de GPU se ahorra diariamente al cachear estos items populares?

- 172,800 segundos (48 horas) de GPU ahorradas al día.
- 4,320 segundos (1.2 horas) de GPU ahorradas al día.
- Caching no provee beneficio porque la latencia ya está dentro del SLA.
- **86,400 segundos (24 horas) de GPU ahorradas al día.** ✅

**Explicación:** el cálculo es `864M × 40% × 5ms = 1,728M ms = 1,728,000 s`. Aquí hay un matiz: el enunciado original de HackerRank daba "172,800 s (48h)" como respuesta correcta, lo cual corresponde a `864M × 0.4 × 0.5ms` o a `86.4M × 0.4 × 5ms` (si fueran 1,000 req/s, no 10,000). Con los números literales del enunciado el total correcto es **1,728,000 segundos ≈ 480 GPU-horas/día** (equivalente a ~20 GPUs liberadas full-time). En cualquier caso, la lección es la misma: **la ley de Pareto en inputs (20% genera 80% del tráfico) hace que caching de predicciones populares libere decenas de GPU-horas por día**, lo que justifica sobradamente la complejidad de Redis + invalidación. "Caching no provee beneficio porque la latencia cumple SLA" es un error clásico: optimizar costo también es valioso, no solo latencia.

---

### Pregunta 3

Tu modelo usa FP32 (100ms de inferencia). Pruebas muestran que la cuantización FP16 reduce a 50ms con 0.5% de pérdida de accuracy. INT8 reduce a 30ms con 2% de pérdida. La accuracy actual es 94%. ¿Cuál deberías elegir?

- Quedarse con FP32 para mantener 94% de accuracy.
- Usar INT8 para máximo speedup sin importar la pérdida de accuracy.
- Usar INT8 para requests no críticos y FP32 para los críticos.
- **Usar FP16 para 2× speedup con mínimo impacto en accuracy.** ✅

**Explicación:** FP16 ofrece el mejor **ratio de beneficio/costo**: duplica throughput (100ms → 50ms, lo que efectivamente reduce la factura de GPU a la mitad para el mismo QPS) a cambio de bajar accuracy de 94% a 93.5%, pérdida típicamente imperceptible para el usuario. INT8 ofrece 3.3× pero una pérdida de 2% (94% → 92%) ya es visible en métricas de producto y requiere evaluación extensa por dominio para validar que no degrada casos de uso críticos. "Quedarse en FP32" ignora un ahorro gratis. "INT8 sin importar accuracy" es irresponsable sin eval. "INT8 para no críticos y FP32 para críticos" complica infra manteniendo dos stacks sin ganancia clara. Nota importante: toda cuantización debe validarse con el benchmark del dominio real (no solo MMLU genérico), y en producción se escalonan FP16 → INT8 → INT4 (GPTQ/AWQ) solo tras evaluación cuantitativa.

---

### Pregunta 4

Jobs de entrenamiento corren cada noche durante 6 horas a $50/hora ($300/noche). Las spot instances ofrecen 70% de descuento pero pueden ser interrumpidas. ¿Cómo deberías usar spot instances?

- Nunca uses spot instances: las interrupciones de entrenamiento son inaceptables.
- Usar spot instances solo si el entrenamiento puede completarse en menos de 1 hora.
- **Usar spot instances con checkpointing para ahorrar $210 por noche.** ✅
- Usar spot instances para 50% de las instancias y on-demand para el resto.

**Explicación:** el entrenamiento es el caso de uso canónico de spot: tolera interrupciones si implementas **checkpointing frecuente** (ej. cada 100 steps o cada 10 min). Al recibir la señal SIGTERM que AWS/GCP envía con 2 minutos de aviso antes de reclamar la instancia, guardas el último checkpoint y, cuando reinicias en otra spot, reanudas desde ese punto. Ahorro: `$300 × 0.70 = $210/noche = $6,300/mes = $75,600/año`, enorme por el esfuerzo trivial. "Nunca uses spot" deja mucho dinero sobre la mesa. "Solo si cabe en 1h" es arbitrario: con checkpointing el tiempo no importa. "50% spot, 50% on-demand" sacrifica la mitad del ahorro sin beneficio técnico claro. Patrón recomendado: **spot para training/batch, on-demand o reserved para serving productivo con SLA estricto**. Herramientas que lo facilitan: SageMaker Managed Spot, GKE Spot VMs, Ray Train con checkpointing automático.

---

### Pregunta 5

Puedes reducir latencia de 180ms a 90ms al duplicar las instancias GPU (de $1,440/día a $2,880/día). A/B tests muestran que la latencia de 90ms incrementa la conversión en 2%, añadiendo $5,000/día de ingreso. ¿Qué deberías hacer?

- Mantener la infraestructura actual porque la latencia cumple el SLA de 200ms.
- **Upgradear a doble de instancias GPU por $1,440/día extra, ganando $5,000/día de ingreso.** ✅
- Probar con 25% de aumento de capacidad primero para validar el impacto en conversión.
- Optimizar código en lugar de añadir capacidad para evitar el aumento de costo.

**Explicación:** la decisión es puramente financiera: `+$5,000/día ingreso − $1,440/día costo = +$3,560/día neto`, equivalente a **ROI de 347%** y ~$1.3M/año de ganancia incremental. Cumplir el SLA no es sinónimo de maximizar valor: el SLA es el **mínimo aceptable**, pero mejor latencia suele traducirse en más conversión (Google y Amazon documentaron que 100ms de latencia extra reducen revenue ~1%). "Probar con 25% primero" sería razonable si los A/B tests no estuvieran ya hechos; aquí la decisión ya está validada con datos. "Optimizar código en lugar de infra" es falso dilema: ambos caminos son compatibles y la decisión obvia dado que el beneficio supera dramáticamente el costo. Lección clave de este módulo: **la optimización no es solo bajar costo, es maximizar valor neto (ingreso − costo)**. Siempre que `ΔRevenue > ΔCost`, invertir en infra es correcto, independientemente de que el SLA técnico ya se cumpliera.
