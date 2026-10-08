# Quiz: Desarrollo de aplicaciones RAG en producción

**Escenario:** tu empresa despliega un sistema de búsqueda de documentos legales con RAG para varios departamentos. Los usuarios de finanzas solo necesitan documentos financieros, RRHH necesita políticas de personal y los equipos legales acceden a todo. El sistema atiende 500 usuarios concurrentes en distintas zonas horarias.

---

### Pregunta 1

Usuarios del departamento de finanzas están viendo documentos de compliance legal en sus resultados de búsqueda. ¿Cómo debería resolverlo el filtrado por metadata?

- Aumentar el umbral de similitud para recuperar solo documentos altamente relevantes.
- **Filtrar documentos en query time usando metadata de departamento.**
- Crear bases de datos vectoriales separadas para cada departamento.
- Entrenar el embedding model para que reconozca contenido específico por departamento.

**Respuesta correcta:** Filtrar documentos en query time usando metadata de departamento.

**Explicación:** El problema no es de similitud semántica (los documentos *son* relevantes a la query), es de **control de acceso y alcance**. Subir el umbral de similitud filtraría también documentos financieros legítimos. Crear bases separadas multiplica la infraestructura y rompe la búsqueda cross-departamento para los roles autorizados (legal, ejecutivos). Entrenar el embedding es caro y no resuelve permisos. La solución correcta es almacenar `department` como metadata estructurada y aplicar un filtro `where department == user.department` en el momento de la query — el mismo índice sirve a todos los departamentos y los filtros se aplican antes del ANN para no desperdiciar cómputo.

---

### Pregunta 2

Una query del usuario *"muéstrame las últimas políticas de RRHH"* debería priorizar documentos recientes. ¿Qué estrategia de metadata lo logra?

- **Analizar la query para detectar palabras temporales y aplicar filtrado por fecha.**
- Usar un embedding model especializado entrenado en relaciones temporales.
- Ordenar los resultados por fecha de creación después del retrieval.
- Aumentar el número de documentos recuperados para encontrar los recientes.

**Respuesta correcta:** Analizar la query para detectar palabras temporales y aplicar filtrado por fecha.

**Explicación:** El **intent routing** detecta palabras como *"último", "reciente", "actual", "nuevo"* y añade automáticamente un filtro `created_date >= now - 30d` o un recency scoring. Un embedding "temporal" es un concepto confuso: los embeddings capturan semántica, no fechas. Ordenar por fecha *después* del retrieval desperdicia el top-K (puedes rankear primero documentos irrelevantes pero nuevos). Pedir más documentos no cambia el ranking: los viejos siguen arriba si tienen mejor similitud. La solución correcta es traducir la intención temporal de la query en un filtro estructurado explícito.

---

### Pregunta 3

El sistema filtra por departamento y fecha, pero devuelve cero resultados. ¿Qué estrategia de fallback previene respuestas vacías?

- Mostrar un mensaje de error pidiendo al usuario que reformule.
- **Usar multi-stage filtering que relaja progresivamente las restricciones.**
- Desactivar todos los filtros y buscar en toda la base de datos.
- Usar el LLM para generar una respuesta sin retrieval.

**Respuesta correcta:** Usar multi-stage filtering que relaja progresivamente las restricciones.

**Explicación:** Over-filtering es un problema común: la combinación `department=finance AND date>=90d AND access_level=internal` puede no matchear nada aunque existan documentos útiles ligeramente fuera de esos límites. **Multi-stage filtering** aplica una cascada: Stage 1 estricto → si vacío, Stage 2 relaja fecha → si vacío, Stage 3 relaja acceso a `public`. Mostrar un error empuja la carga al usuario. Desactivar todos los filtros rompe RBAC y puede exponer datos confidenciales. Generar sin retrieval es una invitación a alucinar. Relajar en etapas controladas garantiza respuestas útiles sin violar seguridad.

---

### Pregunta 4

El equipo almacena metadata como: `created_date` (string), `dept` (string), `access` (string). Una query filtra por `department: Finance` pero los documentos usan `dept: finance`. ¿Cuál es el problema?

- La base vectorial necesita ser reindexada.
- **Esquema de metadata inconsistente y case sensitivity causan resultados perdidos.**
- El embedding model no entiende los campos de metadata.
- El umbral de similitud está muy alto.

**Respuesta correcta:** Esquema de metadata inconsistente y case sensitivity causan resultados perdidos.

**Explicación:** Hay dos bugs sumados: (1) el nombre del campo difiere — `department` vs. `dept` — y (2) el valor difiere en capitalización — `Finance` vs. `finance`. El filtro aplica igualdad exacta y falla silenciosamente devolviendo cero. No es un problema del índice vectorial ni del embedding (los embeddings nunca ven la metadata). La solución es doble: **normalización en la ingesta** (lowercasing, nombres canónicos de campo) y **validación de schema con Pydantic/JSON Schema** tanto en la escritura como en la query. Un `MetadataNormalizer` central que mapee alias (`dept` → `department`) y aplique `str.lower().strip()` evita este tipo de bugs.

---

### Pregunta 5

Los documentos legales deben ser accesibles solo para usuarios con nivel de acceso `legal` o `executive`. ¿Cómo debería el filtrado por metadata hacer cumplir esto?

- **Almacenar `access_level` como metadata y filtrar por el permiso del usuario durante las queries.**
- Crear bases vectoriales separadas para cada nivel de acceso.
- Que el LLM filtre las respuestas basándose en los permisos del usuario.
- Encriptar los documentos y dar las claves de desencriptación solo a usuarios autorizados.

**Respuesta correcta:** Almacenar `access_level` como metadata y filtrar por el permiso del usuario durante las queries.

**Explicación:** El control de acceso debe aplicarse **antes** de que los chunks lleguen al LLM — si un documento confidencial entra al contexto del prompt, ya se filtró información aunque la respuesta final no lo mencione. El filtrado por metadata en query time garantiza que el retriever **nunca devuelva** chunks fuera del scope del usuario. Separar bases por nivel multiplica infraestructura y no escala con jerarquías de acceso. Que el LLM filtre a posteriori es inseguro: el modelo ya vio los datos y puede filtrar información en la respuesta. Encriptación resuelve el problema en reposo, no en el flujo de recuperación. **Regla crítica:** `access_level` del usuario debe venir del IdP/token de sesión, nunca del request body del cliente.
