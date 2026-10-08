# Quiz: Privacidad y Protección de IP en Herramientas de IA

Tu organización está desplegando herramientas de IA para programación en múltiples equipos. Debes proteger el código propietario, impedir que los logs de prompts almacenen datos sensibles y cumplir con los requisitos de privacidad sin frenar la productividad de los desarrolladores.

---

**1. ¿Cuál es el conjunto de rutas de fuga más común en las herramientas de desarrollo con IA?**

- Tamaño del modelo, temperatura y límite de tokens.
- **Contenido del prompt, context retrieval y logs de telemetría.** ✅
- Uso de CPU, uso de memoria y latencia de red.
- Errores de sintaxis, fallos de lint y pruebas unitarias.

**Explicación:** Las tres rutas canónicas por las que información sensible escapa de forma no intencionada son: (1) el **contenido del prompt** que el desarrollador pega explícitamente, (2) el **context retrieval** que la herramienta ejecuta automáticamente (archivos abiertos, variables de entorno, repos) y (3) la **telemetría** invisible (métricas, stack traces, muestras de prompts enviadas al vendor para "mejorar el producto"). Las otras opciones son métricas de performance o de calidad de código, no rutas de exposición de datos.

---

**2. ¿Cuál es la regla por defecto más segura para secretos en flujos de trabajo con IA?**

- Permitir secretos si la herramienta es interna.
- Permitir secretos solo cuando se depuran problemas de producción.
- **Nunca permitir que los secretos entren en prompts o logs de herramientas.** ✅
- Permitir secretos si tienen vida corta.

**Explicación:** Los secretos (API keys, tokens, passwords, certificados) son la categoría de **más alto riesgo** porque conceden acceso directo a sistemas. Una sola fuga puede comprometer infra entera. Las excepciones ("solo interno", "solo si es corto", "solo en debug") son el camino a los incidentes: la clasificación debe ser **absoluta y automática**. Herramientas como gitleaks, trufflehog o Presidio deben bloquear secretos antes del request, independientemente de la justificación.

---

**3. ¿Por qué es importante la clasificación de datos para el uso de herramientas de IA?**

- Ayuda a elegir la mejor arquitectura de modelo.
- **Define qué puede compartirse y qué debe redactarse.** ✅
- Reemplaza la necesidad de redacción.
- Elimina la necesidad de logs de auditoría.

**Explicación:** La clasificación (Public, Internal, Confidential, Restricted) convierte una política vaga como "no compartas datos sensibles" en reglas **enforceables automáticamente**: Restricted bloquea, Confidential exige redacción, Internal permite con precaución, Public no requiere control. Sin clasificación, cada desarrollador decide ad-hoc bajo presión y las decisiones son inconsistentes. La clasificación **habilita** la redacción y la auditoría; no las reemplaza.

---

**4. ¿Qué enfoque de retención balancea mejor utilidad y riesgo?**

- Guardar todos los prompts para siempre para maximizar el análisis futuro.
- **Conservar los prompts crudos poco tiempo y almacenar métricas agregadas por más tiempo.** ✅
- Borrar todos los logs inmediatamente, incluso para incident response.
- Guardar solo outputs, no inputs.

**Explicación:** La **retención por tiers basada en riesgo** es el patrón correcto: los prompts crudos contienen la mayor concentración de PII y rara vez son útiles después de una semana (TTL corto), mientras que las métricas agregadas (latencia, tokens, tasa de error) son valiosas para analytics y contienen poco dato sensible (TTL largo). Guardar todo acumula riesgo sin beneficio; borrar todo inmediatamente destruye la capacidad de incident response; guardar solo outputs pierde la mitad de la historia (los outputs sin inputs son irreproducibles).

---

**5. ¿Por qué el provenance tagging es valioso para los cambios asistidos por IA?**

- Mejora directamente la precisión del modelo.
- **Permite reproducir y auditar las decisiones posteriormente.** ✅
- Elimina la necesidad de aprobaciones.
- Permite almacenar datos sensibles indefinidamente.

**Explicación:** Un **provenance tag** (prompt template ID + versión, context manifest ID, nombre y config del modelo, timestamp, actor) funciona como el `package-lock.json` de la IA: permite **reproducir** exactamente cómo se generó un output semanas después, lo cual es esencial para debugging, incident response y evidencia de cumplimiento ante auditores. No mejora la precisión del modelo (el modelo ya corrió) ni cambia las políticas de aprobación o retención.

---

**6. ¿Qué afirmación describe mejor el cumplimiento regulatorio para herramientas de IA?**

- El cumplimiento es un asunto puramente legal y no afecta a la ingeniería.
- El cumplimiento se maneja mejor después del despliegue.
- **El cumplimiento se vuelve accionable cuando se implementa como controles técnicos.** ✅
- El cumplimiento solo es relevante para vendors externos.

**Explicación:** Regulaciones como **GDPR, HIPAA, CCPA y EU AI Act** se traducen en controles técnicos concretos: redacción (data minimization Art. 5), retención automática con TTL (storage limitation), scoped permissions (access control), structured audit logs (accountability), DSAR handlers (right to erasure Art. 17), routing por región (residencia). Tratar compliance como legal-only lleva a retrofits de emergencia; tratarlo como requisito de ingeniería desde el día 1 lo convierte en features testeables en CI. Herramientas internas también están sujetas (uso interno no exime de GDPR).

---

**7. ¿Cuándo debe ocurrir la redacción en los flujos de trabajo con IA?**

- Después de que los prompts se envían al modelo.
- **Antes de que cualquier dato sensible abandone el límite del sistema.** ✅
- Solo cuando se programa una auditoría de cumplimiento.
- Solo para herramientas externas, no para las internas.

**Explicación:** La redacción debe ocurrir **antes del request HTTP**, idealmente en un proxy que intercepta la salida. Si el prompt ya salió al vendor, el dato ya está en sus logs, caches y potencialmente training data: la política falló. Herramientas internas son igual de peligrosas (logs internos siguen cruzando límites de confianza entre equipos). La auditoría programada es demasiado tarde: cuando el auditor pregunta, ya hay fuga histórica. El patrón correcto es **pipeline determinístico** (Presidio + policy as code) que redacta antes de cualquier egress.
