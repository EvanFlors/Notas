# Quiz: Técnicas Avanzadas de RAG y Aplicaciones Empresariales

Tu empresa construye un sistema RAG avanzado para una plataforma de investigación. El sistema debe buscar en papers técnicos con diagramas complejos, detectar cuándo la información recuperada es insuficiente y manejar consultas que abarquen múltiples tipos de documento, incluyendo PDFs con gráficos y repositorios de código.

---

**1.** Los usuarios buscan `"machine learning architectures"`, pero los resultados pierden papers porque usan solo retrieval denso y los papers contienen nombres específicos de modelos como `"ResNet"` y `"BERT"`. ¿Qué enfoque híbrido ayudaría?

- Usar un modelo de embeddings específico del dominio entrenado con papers de ML.
- **Combinar embeddings densos con retrieval disperso BM25.**
- Aumentar el número de documentos recuperados del índice denso.
- Fine-tunear el LLM para que reconozca terminología técnica.

**Respuesta correcta:** Combinar embeddings densos con retrieval disperso BM25.

**Explicación:** Los sistemas híbridos fusionan búsqueda semántica densa con coincidencia por palabras clave (BM25), capturando a la vez conceptos ("architectures") y términos exactos ("ResNet", "BERT"). BM25 brilla con tokens raros, siglas y nombres propios que los embeddings tienden a diluir. Un embedder específico del dominio ayuda, pero no resuelve el problema del match exacto; subir top-k solo trae más ruido; y fine-tunear el LLM no mejora el retrieval.

---

**2.** Al combinar resultados densos (similitud 0-1) y BM25 (score 0-50), un promedio ingenuo produce rankings sesgados. ¿Qué enfoque de normalización los balancearía?

- **Convertir ambos a rankings percentiles dentro de sus conjuntos de resultados antes de combinarlos.**
- Multiplicar los scores BM25 por 0.02 para igualar el rango 0-1.
- Usar solo el orden del ranking e ignorar los scores reales.
- Priorizar siempre los resultados densos sobre los de BM25.

**Respuesta correcta:** Convertir ambos a rankings percentiles dentro de sus conjuntos de resultados antes de combinarlos.

**Explicación:** La normalización por percentiles (o Reciprocal Rank Fusion, RRF) hace que los scores sean comparables sin importar la escala original, permitiendo una ponderación justa. Multiplicar por un factor fijo (0.02) depende de la distribución específica y rompe cuando BM25 produce outliers. Ignorar los scores pierde información fina de ranking. Priorizar siempre uno sobre otro anula el propósito de la fusión híbrida.

---

**3.** Los papers de investigación incluyen diagramas de arquitectura. Los embeddings de texto denso pierden información visual. ¿Qué enfoque multimodal capturaría tanto texto como imágenes?

- Usar OCR para convertir imágenes a texto e indexarlas junto con el contenido textual.
- **Usar un modelo de embeddings multimodal como CLIP que codifique texto e imágenes en un espacio vectorial compartido.**
- Guardar las imágenes como enlaces de metadata junto a los embeddings de texto.
- Crear índices separados para texto e imágenes y luego fusionar resultados.

**Respuesta correcta:** Usar un modelo de embeddings multimodal como CLIP que codifique texto e imágenes en un espacio vectorial compartido.

**Explicación:** CLIP (y modelos descendientes como SigLIP o ColPali, 2024) crea embeddings alineados donde texto e imágenes con significado similar quedan cerca en el mismo espacio, habilitando búsqueda unificada: una query de texto encuentra diagramas relevantes directamente. OCR funciona para texto dentro de imágenes pero no captura relaciones visuales (flujos, estructura). Guardar enlaces como metadata no las hace buscables. Índices separados sirven como respaldo, pero fusionar resultados post-hoc rinde peor que un espacio compartido.

---

**4.** Un usuario pregunta sobre `"quantum computing applications in cryptography"`. El sistema recupera papers generales de quantum computing con baja relevancia. ¿Qué técnica de Self-RAG detectaría esto?

- **Implementar un critic de relevancia que puntúe qué tan bien los documentos recuperados coinciden con la query específica.**
- Aumentar el umbral de similitud para recuperar solo documentos con score alto.
- Usar filtros de metadata para restringir resultados a papers de criptografía.
- Hacer que el LLM genere una respuesta y verificar si parece confiado.

**Respuesta correcta:** Implementar un critic de relevancia que puntúe qué tan bien los documentos recuperados coinciden con la query específica.

**Explicación:** Self-RAG (2023) y CRAG (2024) usan un modelo critic (reflection token `ISREL`) para evaluar explícitamente la relevancia de cada pasaje recuperado, detectando cuándo faltan especificidad o cobertura. Subir el umbral de similitud puede dejarte sin resultados sin resolver la falta de especificidad. Los filtros de metadata ayudan si existen las etiquetas correctas, pero son frágiles. La confianza del LLM es un indicador pobre: los modelos alucinan con alta confianza.

---

**5.** Un sistema RAG multi-tenant sirve a 50 departamentos. Cada departamento necesita datos aislados y distintos SLAs de rendimiento. ¿Qué estrategia de despliegue balancea aislamiento y eficiencia?

- Desplegar bases de datos vectoriales separadas para cada departamento.
- **Usar una sola base de datos vectorial con filtrado por metadata de tenant y cuotas de recursos.**
- Usar una base de datos pero cifrar los datos de cada tenant de forma distinta.
- Desplegar bases de datos regionales y asignar departamentos por geografía.

**Respuesta correcta:** Usar una sola base de datos vectorial con filtrado por metadata de tenant y cuotas de recursos.

**Explicación:** Una base única con particionado por `tenant_id` (o namespaces, o Row Level Security en pgvector) y cuotas de recursos entrega aislamiento lógico con mínima complejidad operacional. 50 DBs separadas multiplican el costo, los backups y la monitorización por 50. Cifrado diferente por tenant es útil (CMEK), pero no sustituye al filtro de autorización en la query. La asignación geográfica es relevante para residencia de datos (GDPR), no para aislamiento entre departamentos. Clave: el filtro `tenant_id` debe aplicarse **pre-ANN** y nunca ser elegido por el LLM.
