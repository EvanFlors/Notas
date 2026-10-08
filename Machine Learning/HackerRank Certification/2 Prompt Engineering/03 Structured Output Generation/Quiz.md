# Quiz: Generación de Salidas Estructuradas

Este quiz evalúa tu comprensión de JSON mode, diseño de schemas, formatos alternativos (XML, CSV, Markdown) y estrategias de validación multi-capa. Resuelve problemas realistas de consistencia de datos, validación y elección de formato.

---

### 1. Tu plataforma de e-commerce extrae información de productos desde correos de proveedores. La implementación inicial con JSON mode devuelve JSON válido pero con nombres inconsistentes: a veces `"product_name"`, a veces `"productName"`. La inconsistencia rompe la integración con el inventario. ¿Cuál es la solución más efectiva?

- Implementar una capa de post-procesamiento que normalice los nombres de campo antes de insertar en la base de datos.
- **Diseñar un schema estricto con definiciones explícitas de campos e incluirlo en el prompt. ✅**
- Cambiar a XML porque maneja convenciones de nombres de forma más fiable.
- Usar few-shot prompting con ejemplos que muestren el patrón correcto de nombres.

**Explicación:** JSON mode solo garantiza **sintaxis** JSON válida, no consistencia **semántica**. Un schema estricto (OpenAI structured outputs con `strict: true`, Anthropic tool use con `tool_choice` forzado, o Pydantic con constrained decoding) fija los nombres de campo a nivel del decoder: el modelo literalmente no puede emitir `productName` si el schema dice `product_name`. Normalizar en post-proceso trata el síntoma, no la causa, y falla silenciosamente cuando aparece un nombre nuevo. Few-shot ayuda pero no garantiza. XML no soluciona el problema de naming.

---

### 2. Construiste un sistema de soporte que genera tickets estructurados. En hora pico, el 15 % de las respuestas contiene JSON incompleto por truncamiento de tokens. Tu capa de validación las rechaza todas, causando retrasos. ¿Qué deberías implementar primero?

- Aumentar el parámetro `max_tokens` del modelo para prevenir el truncamiento.
- **Añadir manejo inteligente de respuestas parciales que rescate datos útiles con scoring de confianza. ✅**
- Cambiar a XML porque maneja datos incompletos de forma más elegante.
- Implementar retry progresivo con backoff exponencial para generaciones fallidas.

**Explicación:** Subir `max_tokens` reduce la frecuencia pero no elimina el problema (y cuesta más). El retry con backoff añade latencia sin aprovechar el 15 % que ya está casi completo. El **parsing parcial** detecta `finish_reason="length"`, intenta cerrar llaves/corchetes faltantes, extrae los campos ya emitidos, y marca el resultado con `confidence < 1.0`. Así entregas valor en el 15 % de los casos degradados en vez de rechazarlos. El scoring permite a los consumidores decidir si usan el dato o lo escalan.

---

### 3. Tu sistema de reportes financieros genera análisis trimestrales en CSV para Excel. Necesitas validar que los cálculos de ingresos sean lógicamente consistentes con los gastos y márgenes reportados. ¿Qué capa de validación debe manejar esta comprobación?

- Validación sintáctica para asegurar que la estructura CSV sea correcta.
- **Validación semántica para verificar la consistencia lógica de las relaciones numéricas. ✅**
- Validación de seguridad para buscar PII o contenido inapropiado.
- Validación de negocio para aplicar reglas regulatorias de la industria.

**Explicación:** La validación **sintáctica** solo revisa que el CSV parsee (número correcto de columnas, encabezados). La de **seguridad** busca PII. La de **negocio** aplica reglas regulatorias (ej. SOX, IFRS). La **semántica** verifica que los datos tienen **sentido lógico entre sí**: que `profit == revenue - expenses`, que `margin_pct == profit / revenue * 100`. Es exactamente el chequeo descrito. Puede implementarse con reglas Python (`abs(revenue - expenses - profit) < 0.01`) o con un juez LLM si la lógica es más fuzzy.

---

### 4. Diseñas un sistema de historia clínica que debe preservar notas con formato, datos del paciente con validación estricta, y relaciones entre diagnósticos y tratamientos. El sistema requiere cumplir estándares de datos de salud. ¿Qué formato cumple mejor estos requisitos?

- **XML con atributos para metadatos, namespaces para cumplimiento de estándares y estructura jerárquica. ✅**
- CSV para almacenamiento eficiente e importación fácil de datos tabulares.
- JSON con objetos anidados para relaciones y validación estricta de schema.
- Markdown para notas legibles por humanos con secciones estructuradas embebidas.

**Explicación:** El dominio clínico exige **HL7 FHIR**, **CDA** o similares, todos basados en XML. Los **atributos** (`<diagnosis code="E11.9" confidential="HIPAA"/>`) llevan metadatos sin ensuciar la jerarquía. Los **namespaces** (`xmlns:hl7="..."`) previenen colisiones cuando mezclas vocabularios. **XSD/Schematron** validan contra el estándar oficial. CSV es plano (sin relaciones). JSON puede modelar la jerarquía pero carece de atributos vs elementos y namespaces nativos. Markdown no valida nada estricto. En healthcare, elegir XML no es gusto: es cumplimiento.

---

### 5. Tu sistema de moderación de contenido usa validación multi-capa: syntax (50 ms), safety (200 ms) y validación semántica vía juez LLM (1500 ms). En alto tráfico, la latencia de validación supera al tiempo de generación. ¿Qué estrategia balancea mejor velocidad y fiabilidad?

- **Aplicar la validación con juez LLM selectivamente solo a contenido de alto riesgo marcado por la capa de seguridad. ✅**
- Correr las tres capas en paralelo para minimizar tiempo total.
- Eliminar la validación semántica para reducir latencia.
- Cachear resultados de validación para contenido similar y evitar chequeos repetidos.

**Explicación:** Correr en paralelo no sirve porque las capas son **dependientes** (sin JSON parseable no hay semántica que juzgar) y, aunque fuera independiente, el juez LLM dominaría la latencia igual. Eliminar la semántica deja pasar errores reales. El caché ayuda marginalmente pero el contenido rara vez se repite exacto. La estrategia correcta es **selectividad**: la capa de seguridad (barata) actúa como triage; solo el 5-10 % marcado como riesgoso paga el juez. Latencia promedio baja drásticamente, fiabilidad se mantiene donde importa.

---

### 6. Construiste un generador de documentación de API en Markdown. Funciona bien con endpoints simples pero falla al documentar estructuras anidadas con múltiples parámetros opcionales. Los usuarios se quejan de que no se ve la jerarquía de parámetros. ¿Qué debes hacer?

- Cambiar a JSON porque representa mejor las estructuras anidadas.
- Añadir más ejemplos en few-shot prompting mostrando documentación compleja.
- Cambiar a XML con atributos para metadatos de parámetros y elementos anidados para jerarquía.
- **Mejorar la generación de Markdown con tablas para parámetros y bloques de código anidados para estructura. ✅**

**Explicación:** El consumidor (GitHub, MkDocs, Docusaurus) es un **lector humano** de Markdown; cambiar a JSON o XML rompe la UX. Few-shot ayuda pero no resuelve la limitación estructural de pedir "describe en texto plano". Markdown en su dialecto **GFM** sí tiene herramientas: **tablas** (`| param | tipo | required | descripción |`) muestran la lista; **bloques de código ```json anidados** muestran el shape del request/response; **sub-headings** (`### Parámetros opcionales`) agrupan. Resolver el problema **dentro del formato correcto** es casi siempre mejor que cambiar de formato.
