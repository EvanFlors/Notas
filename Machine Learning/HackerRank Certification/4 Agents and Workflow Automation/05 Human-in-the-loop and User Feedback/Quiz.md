# Quiz: Human-in-the-Loop y feedback del usuario

**Contexto:** Tu agente de code review está listo para producción, pero necesitas supervisión humana para decisiones de alto riesgo. El agente debe publicar comentarios menores de forma autónoma, pero requerir aprobación antes de bloquear PRs o solicitar cambios. También quieres recolectar feedback para mejorar el agente con el tiempo. El sistema debe manejar workflows de aprobación, timeouts e integración de feedback.

---

### 1. ¿Por qué es esencial la supervisión humana (HITL) para agentes en producción?

- Los humanos son más rápidos que los agentes tomando decisiones.
- **Los agentes cometen errores que el testing no puede prevenir completamente; la supervisión humana provee redes de seguridad para decisiones de alto riesgo y permite corregir errores del agente.**
- La supervisión humana elimina la necesidad de hacer testing de sistemas de agentes.
- Los agentes no pueden funcionar sin aprobación humana para cada acción.

**Explicación:** Los agentes son imperfectos y cometen errores de razonamiento (alucinaciones, mala interpretación de contexto, decisiones con baja evidencia). La supervisión humana captura esos errores antes de que causen daño, especialmente en acciones **irreversibles** o de **alto impacto**. HITL no es desconfianza; es "confianza calibrada": el humano no reemplaza al testing, lo complementa en el espacio donde el testing no puede llegar (edge cases nuevos, decisiones probabilísticas, contexto fuera del prompt).

---

### 2. En el espectro de autonomía del agente, ¿qué significa 'agent-initiated con override'?

- Los agentes proponen acciones pero los humanos deben aprobar antes de ejecutar.
- **Los agentes ejecutan acciones automáticamente, pero los humanos pueden intervenir, editar o retractar esas acciones después de la ejecución.**
- Los humanos toman todas las decisiones y los agentes solo proveen información.
- Los agentes ejecutan sin ninguna intervención ni supervisión humana.

**Explicación:** El espectro de autonomía va de **manual** (humano decide y ejecuta) a **totalmente autónomo** (agente decide y ejecuta sin intervención). "Agent-initiated con override" está en el medio-alto: el agente actúa por default, pero el humano **retiene el poder de modificar o deshacer**. Es apropiado cuando la acción es reversible y la latencia importa (ej. publicar un comentario que luego puede editarse). Se diferencia de "human-initiated", donde el agente **no** ejecuta hasta recibir aprobación previa.

---

### 3. Al determinar si una acción del agente requiere aprobación humana, ¿qué factores debes considerar?

- Solo el tipo de acción, sin importar contexto o impacto.
- **Reversibilidad (qué tan fácil es deshacer la acción), alcance del impacto (cuántas personas o sistemas afecta) y nivel de confianza del agente.**
- Solo el costo de la acción en tokens de API.
- Solo si el agente ha tomado decisiones similares antes.

**Explicación:** Las tres dimensiones son complementarias. **Reversibilidad**: borrar una rama con trabajo no mergeado es irreversible; publicar un comentario se deshace con un click. **Impacto** (blast radius): un typo-fix afecta un archivo, una migración afecta a todos los usuarios. **Confianza**: una decisión con 0.95 en un caso rutinario es muy distinta a 0.4 en un caso novedoso. La regla práctica: `requiere_humano = baja_reversibilidad OR alto_impacto OR baja_confianza`.

---

### 4. ¿Cuáles son los elementos clave que un workflow de aprobación debe manejar?

- Solo rutear solicitudes de aprobación a la persona correcta.
- **Qué dispara la aprobación, quién aprueba, qué información ven, cómo responden y qué pasa después de aprobar o rechazar.**
- Solo almacenar las solicitudes de aprobación en una base de datos.
- Solo enviar notificaciones por email a los aprobadores.

**Explicación:** Un workflow completo cubre el ciclo de vida entero: **trigger** (qué dispara), **routing** (quién recibe, con load balancing), **presentation** (resumen, confianza, findings, efectos de aprobar/rechazar), **response** (approve / reject / modify / escalate), **timeout** (escalate / auto-approve / auto-reject), y **post-action** (ejecución y auditoría). Omitir cualquiera genera fricción, bloqueos o auditoría pobre. Por ejemplo, no definir timeout convierte una ausencia breve del aprobador en un bloqueo indefinido.

---

### 5. Cuando una solicitud de aprobación expira (el aprobador no responde dentro del deadline), ¿qué debe pasar?

- La acción debe ejecutarse automáticamente tras el timeout.
- **El sistema debe escalar a aprobadores alternativos, cancelar la acción, o aplicar una política default basada en el nivel de riesgo de la acción.**
- El agente debe reintentar la solicitud indefinidamente hasta que alguien responda.
- La solicitud debe borrarse y la acción olvidarse.

**Explicación:** El comportamiento correcto en timeout depende del **riesgo**. Para acciones críticas (merge a main, deploy): **escalate** a aprobador senior o manager. Para acciones de bajo riesgo con default seguro: **auto-approve** aceptable. Para acciones donde "no hacer nada" es seguro: **auto-reject** con notificación. Nunca uses auto-approve universal (teatro de seguridad) ni dejes el item colgado para siempre (bloqueo oculto). Reintentar indefinidamente satura al aprobador y degrada la señal.

---

### 6. ¿Por qué es importante recolectar feedback humano para mejorar sistemas de agentes?

- El feedback solo sirve para métricas de satisfacción del usuario.
- **El feedback ayuda a identificar errores del agente, corregir falsos positivos/negativos y mejorar la toma de decisiones futura aprendiendo de las correcciones humanas.**
- El feedback elimina la necesidad de testing automatizado de agentes.
- El feedback solo se necesita durante desarrollo, no en producción.

**Explicación:** Sin feedback, un agente está **congelado en su configuración inicial**: comete los mismos errores indefinidamente porque nada cierra el gap entre su comportamiento y la expectativa humana. El feedback alimenta: refinamiento de prompts (añadir guidelines, ejemplos negativos), datasets para fine-tuning (DPO/RLHF), recalibración de confianza (isotonic/Platt), suites de regresión y detección de drift. Es imprescindible **en producción** porque la distribución real de inputs y las expectativas evolucionan con el tiempo.

---

### 7. ¿Cómo debe un agente usar la estimación de confianza para decidir cuándo escalar a humanos?

- Los agentes deben escalar siempre, sin importar el nivel de confianza.
- **Los agentes deben escalar cuando la confianza es baja o cuando las acciones son de alto riesgo, permitiendo ejecución autónoma para decisiones de alta confianza y bajo riesgo.**
- La estimación de confianza no es útil para determinar escalation.
- Los agentes solo deben escalar basándose en el tipo de acción, no en la confianza.

**Explicación:** La escalation basada en confianza habilita **autonomía para lo rutinario** y **supervisión para lo incierto**. La decisión correcta combina confianza con riesgo en una matriz: alto riesgo siempre pide humano aunque la confianza sea alta; bajo riesgo puede ir autónomo si la confianza supera un umbral. Confianza se estima combinando: stated confidence del modelo, consistency entre múltiples muestras, calibración histórica (si decía 0.9 y acertaba 0.7, ajusta) y señales de contexto (tamaño del PR, novedad del área). Escalar siempre satura al humano; no escalar nunca produce daño silencioso.
