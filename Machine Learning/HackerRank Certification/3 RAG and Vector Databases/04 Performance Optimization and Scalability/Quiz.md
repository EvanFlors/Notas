# Quiz: Optimización de Rendimiento y Escalabilidad

**Contexto:** tu empresa opera un sistema RAG que actualmente maneja 100 K documentos con búsqueda por índice `Flat` (fuerza bruta). El negocio escalará a **5 millones de documentos** en el próximo trimestre. La latencia de consulta actual es de **80 ms** y debe mantenerse por debajo de **100 ms** a escala. El sistema corre en un único servidor con **32 GB de RAM**.

---

## Pregunta 1

Con 5 millones de vectores de 768 dimensiones, ¿qué estrategia de indexación debería reemplazar al índice `Flat`?

- Mantener el `Flat` y migrar a un servidor con más RAM.
- **Implementar HNSW para búsqueda aproximada rápida.**
- Partir los documentos en varios índices `Flat` más pequeños.
- Reducir la dimensionalidad de los vectores para acelerar el `Flat`.

**Respuesta correcta:** Implementar HNSW para búsqueda aproximada rápida.

**Explicación:** HNSW ofrece complejidad `O(log n)` con **recall@10 de 0.95–0.99**, lo que permite responder consultas en sub-100 ms incluso con millones de vectores. El `Flat` tiene complejidad `O(n·d)` y con 5 M × 768 implicaría comparar ~3 800 M operaciones por query (segundos de latencia). Añadir RAM no cambia la complejidad algorítmica. Partir en varios `Flat` sigue siendo `O(n)` total. Reducir dimensiones degrada calidad y tampoco cambia la complejidad.

---

## Pregunta 2

Tras implementar HNSW con parámetros por defecto, el recall cae a **0.85** (15 % de documentos relevantes perdidos). ¿Qué ajuste de parámetros mejoraría el recall?

- **Aumentar `efConstruction` para construir más conexiones en el grafo.**
- Disminuir `M` (número de conexiones por nodo).
- Usar una dimensión vectorial menor para mejorar precisión.
- Cambiar de HNSW a IVF.

**Respuesta correcta:** Aumentar `efConstruction` para construir más conexiones en el grafo.

**Explicación:** Un `efConstruction` más alto crea un grafo con más caminos candidatos durante la inserción, lo que mejora la calidad de las conexiones y por tanto el recall en la búsqueda. También puede incrementarse `efSearch` en runtime (más barato que reconstruir). Disminuir `M` degrada aún más el recall porque reduce las conexiones del grafo. Reducir dimensiones no es viable sin reentrenar embeddings. Cambiar a IVF típicamente da **menos** recall que HNSW en el mismo rango de latencia.

---

## Pregunta 3

El uso de memoria se dispara al añadir nuevos documentos al índice HNSW. ¿Qué lo causa?

- **HNSW almacena las conexiones del grafo además de los vectores.**
- El modelo de embeddings se carga en memoria durante la indexación.
- Las bases vectoriales duplican los datos durante la indexación.
- El sistema está creando archivos temporales de backup.

**Respuesta correcta:** HNSW almacena las conexiones del grafo además de los vectores.

**Explicación:** HNSW es un **grafo multi-capa** donde cada nodo mantiene hasta `M` conexiones por capa (y `2·M` en la capa 0). Esto añade entre **30 % y 50 % de overhead** sobre el tamaño de los vectores crudos. Con 5 M vectores × 768 dims × 4 bytes = 15 GB de vectores → HNSW requiere ~20-22 GB totales. El modelo de embeddings se carga una sola vez (overhead fijo) y las DBs serias no duplican datos. Los backups no se crean en caliente durante inserciones.

---

## Pregunta 4

La latencia promedio por consulta es de **120 ms**: 20 ms embedding, 80 ms retrieval, 20 ms post-procesamiento. El objetivo son 100 ms. ¿Qué optimización da el mayor impacto?

- Cachear embeddings de queries para eliminar el tiempo de embedding.
- **Optimizar retrieval ajustando parámetros del índice o usando filtros por metadata.**
- Optimizar el post-procesamiento quitando pasos innecesarios.
- Optimizar todos los componentes por igual para una mejora balanceada.

**Respuesta correcta:** Optimizar retrieval ajustando parámetros del índice o usando filtros por metadata.

**Explicación:** El retrieval consume **80 / 120 = 67 %** de la latencia; es el componente dominante del *latency budget*. Reducir `efSearch`, aplicar prefiltrado por metadata (reduce el espacio de búsqueda) o shardear puede recortar 20-30 ms y cumplir el SLA. Cachear embeddings solo ahorra 20 ms **y** solo cuando hay hit (no siempre). Optimizar los 20 ms de post-procesamiento es techo bajo. Optimizar "todo por igual" ignora la ley de Amdahl: la mejora global está dominada por el componente más caro.

---

## Pregunta 5

El sistema atiende usuarios globales. Los usuarios en Asia experimentan **300 ms** de latencia mientras que los de EE. UU. ven **80 ms**. ¿Qué cambio arquitectónico ayudaría?

- Actualizar HNSW con parámetros más rápidos.
- **Desplegar réplicas regionales de la base vectorial cerca de los usuarios.**
- Usar una CDN para cachear resultados de queries.
- Cambiar a otro proveedor de base vectorial.

**Respuesta correcta:** Desplegar réplicas regionales de la base vectorial cerca de los usuarios.

**Explicación:** La diferencia de 220 ms es consistente con **latencia de red transcontinental** (RTT EE. UU.→Asia es ~150-200 ms, y una query hace múltiples viajes: embedding API + vector DB + LLM). Ningún tuning algorítmico resuelve latencia física de la red. **Replicación regional** (shards geo-distribuidos con enrutamiento por geolocalización) acerca el servicio al usuario y reduce RTT a decenas de ms. Las CDNs cachean estático; una query RAG raramente se repite exacto para beneficiar un CDN. Cambiar de proveedor sin resolver la geografía no cambia la física.
