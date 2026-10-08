# Quiz: Fine-Tuning Decisions and Strategy

**Contexto del escenario**

Tu equipo construye un sistema de soporte al cliente con IA que debe atender **500,000 tickets/mes**. El sistema necesita responder sobre características de producto, políticas de reembolso y documentación técnica. Están evaluando: prompting con GPT-4 API, RAG con una base de conocimiento, PEFT con LoRA, o full fine-tuning de un modelo open-source. Cuentan con **2,000 ejemplos** de interacciones de alta calidad y una base de 10,000 artículos que se actualiza mensualmente. Deben balancear costo, latencia, accuracy y mantenimiento.

---

**1. El sistema debe responder preguntas sobre características de producto que cambian cada mes. El modelo entiende cómo responder pero no tiene acceso a la documentación actualizada. ¿Qué enfoque es más apropiado?**

- Fine-tunear el modelo sobre la documentación para enseñarle la información
- **Usar RAG para recuperar documentación actual e inyectarla como contexto** ✅
- Prompt engineering con ejemplos tomados de la documentación
- Full fine-tuning para "meter" todo el conocimiento del producto en el modelo

**Explicación:** El problema es una **brecha de conocimiento**, no de capacidad: el modelo sabe conversar y resolver dudas de soporte, lo que no tiene es la data. RAG resuelve exactamente eso al recuperar documentos y pasarlos como contexto. Además, como la documentación cambia mensualmente, fine-tunear sería absurdo (requeriría re-entrenar cada vez); con RAG basta con re-indexar los documentos nuevos en el vector store. Fine-tuning se usa para enseñar *comportamiento*, no para memorizar hechos cambiantes.

---

**2. El equipo tiene 200 ejemplos de interacciones de soporte y considera fine-tunear. Según buenas prácticas, ¿qué deberían hacer primero?**

- Proceder con fine-tuning porque ya tienen ejemplos
- **Agotar prompt engineering primero y luego evaluar si fine-tuning es necesario** ✅
- Usar RAG porque tienen una base de conocimiento
- Juntar más ejemplos hasta llegar a 10,000 antes de fine-tunear

**Explicación:** La **escalera de personalización** dicta empezar siempre por lo más barato. Con 200 ejemplos, usar incluso 5-10 como few-shot en el prompt + instrucciones claras puede alcanzar 85-92% de accuracy sin entrenamiento. Fine-tunear con 200 ejemplos es muy riesgoso: el modelo tiende a sobreajustarse y perder capacidades generales (catastrophic forgetting). La regla práctica es que PEFT empieza a tener sentido con 500-2,000 ejemplos *de calidad*, y full fine-tuning con 10,000+. Primero mides el techo con prompting; solo si no alcanza, escalas.

---

**3. A 500,000 requests/mes, ¿qué enfoque es probablemente el más costo-efectivo?**

- Prompting con GPT-4 API a $0.027 por request
- RAG con GPT-4 API, sumando costos de vector DB
- **PEFT self-hosted con LoRA, requiriendo infraestructura GPU** ✅
- Full fine-tuning con infraestructura self-hosted

**Explicación:** A 500K req/mes, la API con GPT-4 costaría ~$13,500/mes solo en inferencia; sumando RAG, más. Una infra self-hosted con A10G (~$600/mes) + costo de entrenamiento LoRA amortizado (~$50-100/mes) ronda **$700/mes**: ~20x más barato. PEFT con LoRA ofrece un buen equilibrio: menos requisitos de GPU que full FT (16 GB alcanzan para un 7B en 4-bit), tiempo de entrenamiento corto (horas, no días), y permite mantener múltiples adapters si en el futuro hay otras tareas. Full fine-tuning también sería viable pero añade complejidad y costo de GPUs mayores sin beneficio claro para esta tarea.

---

**4. El equipo considera usar Llama 3 para fine-tuning. Su empresa tiene 800 millones de MAU. ¿Qué consideración de licencia aplica?**

- La Llama Community License permite uso comercial sin restricciones
- **Necesitan un acuerdo comercial separado con Meta o elegir un modelo con licencia Apache 2.0** ✅
- Pueden usar Llama pero deben hacer open-source su modelo fine-tuneado
- La licencia no aplica al fine-tuning, solo al modelo base

**Explicación:** La **Llama Community License** incluye una cláusula explícita: empresas con **más de 700 millones de MAU** al momento del release del modelo necesitan un acuerdo comercial separado con Meta para usar Llama comercialmente. Con 800M MAU, la empresa está por encima del umbral. Las opciones reales son: (1) negociar un acuerdo con Meta (tiempo y costo inciertos) o (2) elegir un modelo con licencia Apache 2.0 como **Mistral 7B** o **Mixtral 8x7B**, que permiten uso comercial sin restricciones de tamaño de empresa ni obligación de abrir el fine-tune. Verificar la licencia **antes** de invertir en el entrenamiento evita migraciones costosas.

---

**5. El sistema procesará datos personales de residentes de la UE. ¿Qué consideración de residencia de datos aplica?**

- GDPR exige explícitamente que todos los datos permanezcan en la UE
- **Modelos self-hosted en data centers de la UE, o proveedores con garantías de residencia de datos en la UE, simplifican el cumplimiento** ✅
- Cualquier proveedor cloud sirve siempre que se use cifrado
- La residencia de datos solo aplica a datos de entrenamiento, no a inferencia

**Explicación:** GDPR **no exige literalmente** residencia en la UE, pero sí regula estrictamente las **transferencias internacionales** de datos personales fuera del EEA: requiere mecanismos como Standard Contractual Clauses (SCCs), adequacy decisions, o Binding Corporate Rules, y evaluaciones de impacto post-Schrems II. En la práctica, mantener los datos (y la inferencia) dentro de la UE **simplifica muchísimo** el cumplimiento y elimina riesgos de interpretaciones legales cambiantes. Las opciones viables son: self-hostear Mistral/Llama en AWS Frankfurt / GCP Belgium / Azure UE, o usar proveedores API que ofrezcan explícitamente procesamiento en la UE (OpenAI EU data residency, Anthropic AWS Bedrock EU, Gemini Vertex AI UE). El cifrado por sí solo no exime de la obligación de residencia, y GDPR aplica tanto a datos de entrenamiento como de inferencia.
