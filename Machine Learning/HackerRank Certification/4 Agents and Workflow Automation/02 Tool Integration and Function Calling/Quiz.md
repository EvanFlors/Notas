# Quiz: Tool Integration y Function Calling

Tu agente de code review necesita interactuar con APIs de GitHub, scanners de seguridad y sistemas de CI. El agente entiende qué hay que hacer pero no puede ejecutar acciones. Debes implementar function calling para que pueda realmente obtener detalles de PRs, correr escaneos, chequear coverage y publicar comentarios. El sistema debe manejar rate limits, validar parámetros y dar errores claros cuando las tools fallan.

---

**1. En el workflow de function calling, ¿qué ocurre durante la fase de 'selección'?**

- El modelo emite una tool call que tú parseas y ejecutas.
- **El modelo decide qué función llamar basándose en la petición del usuario y las definiciones de tools disponibles.** ✅
- Tú describes las funciones disponibles al modelo con nombre, descripción y schema.
- El resultado de la función se devuelve al modelo para que continúe razonando.

**Explicación:** La fase de **selección** es cuando el modelo evalúa el prompt del usuario frente a las descripciones de tools y decide cuál (o cuáles) invocar y con qué parámetros. La definición es previa, la ejecución es posterior y la integración de respuesta ocurre al final del ciclo.

---

**2. ¿Por qué el function calling nativo es preferible a los enfoques de prompt-based parsing?**

- Es más rápido que parsear texto.
- **Produce salida estructurada y validada que respeta tus schemas, eliminando ambigüedad y errores de parsing.** ✅
- Requiere menos código que los enfoques de parsing.
- Solo funciona con modelos de OpenAI.

**Explicación:** El function calling nativo devuelve datos estructurados que ya coinciden con tus schemas, evitando bugs de JSON mal formado, texto extra o inconsistencias de formato. El modelo está entrenado específicamente para emitir estas estructuras.

---

**3. Tu agente llama todo el tiempo a las tools equivocadas. Cuando se le pide chequear coverage, llama al scanner de seguridad. ¿Cuál es la causa más probable?**

- Las implementaciones de las tools tienen bugs.
- **Las descripciones de los schemas son vagas o poco claras, dificultando que el modelo distinga entre tools.** ✅
- La capa de ejecución no está enrutando correctamente.
- La temperatura del modelo está demasiado alta.

**Explicación:** El modelo selecciona tools casi exclusivamente por su **description**. Descripciones vagas o solapadas son la causa #1 de selección errónea. Mejora las descripciones antes de tocar temperatura, infra o fine-tuning.

---

**4. Al diseñar parámetros de un tool schema, ¿por qué conviene usar `enum` para valores como niveles de severidad en vez de strings libres?**

- Hace que la tool se ejecute más rápido.
- **Proveen validación, previenen valores inválidos y hacen explícitas las opciones aceptables para el modelo.** ✅
- Reducen el número de tokens necesarios en la function call.
- Son obligatorios en todas las APIs de function calling.

**Explicación:** Los `enum` restringen los valores aceptados, previenen typos (`"HIGH"` vs `"high"`), evitan que el modelo invente opciones y comunican claramente qué valores son válidos, mejorando reliability.

---

**5. ¿Cuáles son las tres responsabilidades centrales de la capa de ejecución en un sistema de function calling?**

- Definir schemas, seleccionar tools y ejecutar funciones.
- **Enrutar llamadas a sus implementaciones, ejecutarlas de forma segura y formatear resultados para el modelo.** ✅
- Validar parámetros, llamar APIs y guardar resultados en base de datos.
- Parsear lenguaje natural, generar function calls y manejar errores.

**Explicación:** La capa de ejecución recibe el nombre y argumentos emitidos por el modelo, los enruta al impl correcto, lo ejecuta con validación/timeouts/retry, y devuelve el resultado en un formato consumible por el LLM.

---

**6. Cuando una tool falla (ej. API rate limit excedido), ¿cómo debería manejarlo la capa de ejecución para el agente?**

- Devolver `null` o resultado vacío y dejar que el agente continúe sin saber del fallo.
- **Devolver una respuesta de error estructurada que explique qué falló y por qué, habilitando al agente a reintentar o elegir alternativas.** ✅
- Reintentar automáticamente hasta 3 veces antes de devolver un error.
- Lanzar una excepción que detenga el loop del agente inmediatamente.

**Explicación:** Un error estructurado (`{"type", "message", "retryable", "recovery_options"}`) le da al agente contexto para razonar: puede reintentar con backoff, probar otra tool o pedir ayuda al usuario. Fallos silenciosos o excepciones crudas rompen la autonomía del agente.

---

**7. ¿Qué hace que la descripción de un tool schema sea efectiva para una selección confiable?**

- Descripciones cortas y concisas que quepan en una línea.
- **Descripciones que expliquen qué hace la función, cuándo usarla, qué devuelve y cualquier limitación o constraint importante.** ✅
- Descripciones que coincidan exactamente con el nombre de la función.
- Descripciones escritas en jerga técnica que coincida con el código de implementación.

**Explicación:** Una descripción completa (qué, cuándo, qué devuelve, limitaciones) le da al modelo todo el contexto necesario para elegir la tool correcta y usarla bien. Las descripciones cortas o puramente técnicas producen selecciones erráticas.
