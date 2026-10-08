# Quiz: Vision-Language Models

Pon a prueba lo aprendido en los lessons 01–04 sobre VLMs: fundamentos (CLIP, ViT), VLMs generativos modernos (Claude, GPT-4V, Gemini, LLaVA), OCR implícito vs explícito, extracción structured con Pydantic y casos de uso aplicados.

---

### Pregunta 1

¿Cuál es la función de pérdida que entrena CLIP para alinear embeddings de imagen y texto?

- A) Cross-entropy categórica multiclase
- B) InfoNCE (contrastive loss simétrica entre imagen y texto)
- C) Mean Squared Error entre pixeles y tokens
- D) Triplet loss con margen fijo

**Respuesta correcta:** B) InfoNCE (contrastive loss simétrica entre imagen y texto)

**Explicación:** CLIP (Radford et al., 2021) entrena dos encoders (visual y de texto) con la **InfoNCE loss simétrica**: `L = (L_i2t + L_t2i) / 2`. Para cada batch de N pares, maximiza la similitud coseno de los pares correctos y la minimiza para los N-1 pares incorrectos, dividido por una temperatura `τ`. Cross-entropy multiclase (A) se usa en clasificación supervisada tradicional, no en aprendizaje contrastivo. MSE (C) no aplica a espacios de embeddings normalizados. Triplet loss (D) usa tripletas (anchor, positive, negative), un paradigma distinto al batch-contrastive de CLIP.

---

### Pregunta 2

En un Vision Transformer (ViT) con imágenes de 224x224 y patches de 16x16, ¿cuántos tokens visuales genera (sin contar el token [CLS])?

- A) 14
- B) 196
- C) 224
- D) 768

**Respuesta correcta:** B) 196

**Explicación:** El ViT divide la imagen en una grid de `(H/P) x (W/P)` patches. Con `H=W=224` y `P=16`: `(224/16)² = 14² = 196` patches. Cada patch se aplana (16·16·3 = 768 valores) y se proyecta linealmente a dimensión D (típicamente 768). Luego se antepone un token [CLS] aprendible y se suman positional embeddings, resultando en 197 tokens totales. La respuesta A confunde el lado de la grid (14) con el total. 224 (C) y 768 (D) son otras dimensiones del modelo pero no el número de tokens visuales.

---

### Pregunta 3

Procesas 50,000 facturas por mes con layouts muy variables y necesitas extraer `emisor`, `total` y `fecha` en JSON. ¿Cuál es el enfoque más eficiente en costo y mantenimiento?

- A) Tesseract puro + regex específicas por proveedor
- B) VLM (Claude 3.5 / GPT-4o) con prompt + validación Pydantic
- C) Entrenar una CNN desde cero con tus facturas
- D) Enviar la imagen y pedir una descripción en lenguaje natural para parsear después

**Respuesta correcta:** B) VLM (Claude 3.5 / GPT-4o) con prompt + validación Pydantic

**Explicación:** Para layouts variables, un VLM moderno con prompt estricto + schema Pydantic reemplaza miles de líneas de regex frágiles. Tesseract + regex (A) funciona solo si tienes pocos layouts estables; con proveedores variables se vuelve inmantenible. Entrenar una CNN desde cero (C) requiere miles de ejemplos etiquetados y meses de trabajo. Pedir descripción libre (D) obliga a parsing post-hoc, perdiendo la ventaja de JSON mode. A 50k/mes y costo típico de $0.01–$0.03 por imagen, el VLM queda en $500–$1500/mes, muy manejable para un back-office automatizado.

---

### Pregunta 4

¿Qué diferencia principal hay entre el modo `detail: "low"` y `detail: "high"` en la API de visión de OpenAI?

- A) `low` solo acepta JPEG; `high` acepta cualquier formato
- B) `low` usa aproximadamente 85 tokens fijos; `high` divide la imagen en tiles de 512x512 y suma ~170 tokens por tile
- C) `low` solo detecta objetos; `high` también hace OCR
- D) No hay diferencia real, es cosmético

**Respuesta correcta:** B) `low` usa aproximadamente 85 tokens fijos; `high` divide la imagen en tiles de 512x512 y suma ~170 tokens por tile

**Explicación:** OpenAI documenta explícitamente que `detail: "low"` tiene un costo fijo (~85 tokens) y es apto para comprensión general. `detail: "high"` divide la imagen en tiles de 512x512 y suma ~170 tokens por tile más el costo base, aumentando significativamente el costo pero habilitando OCR fino y detalle. Los formatos (A) son los mismos (JPEG, PNG, GIF, WebP). La capacidad de OCR (C) no está apagada en `low`, solo degrada su calidad. (D) es falso: la diferencia de costo puede ser 5x o más.

---

### Pregunta 5

Tienes un dataset de 10 millones de páginas de libros escaneados que necesitas convertir a texto plano. ¿Cuál es la mejor estrategia?

- A) Enviar cada página a Claude 3.5 Sonnet con detail=high
- B) Usar Tesseract o AWS Textract: OCR explícito dedicado
- C) Usar GPT-4o con detail=low para ahorrar
- D) Entrenar LLaVA desde cero con tus páginas

**Respuesta correcta:** B) Usar Tesseract o AWS Textract: OCR explícito dedicado

**Explicación:** Para **texto denso a gran escala**, el OCR explícito gana por 2–3 órdenes de magnitud en costo. Textract cuesta ~$0.0015 por página; Claude 3.5 Sonnet costaría ~$0.015–$0.030 por página (10–20x más caro) y es muchísimo más lento. A 10M páginas, la diferencia es de ~$15,000 vs. $150,000–$300,000. Un VLM solo tiene sentido cuando necesitas **interpretación semántica** (clasificar, extraer campos nombrados), no transcripción masiva. (A) y (C) son costosos y lentos; (D) requiere datos etiquetados y hardware que no justifica el ahorro.

---

### Pregunta 6

¿Por qué es importante validar la salida de un VLM con Pydantic en pipelines de extracción structured?

- A) Pydantic hace el VLM más rápido
- B) Garantiza que el JSON cumple el schema esperado (tipos, formatos, campos obligatorios) y lanza errores accionables cuando no
- C) Reduce el costo por token
- D) Elimina la necesidad del prompt

**Respuesta correcta:** B) Garantiza que el JSON cumple el schema esperado (tipos, formatos, campos obligatorios) y lanza errores accionables cuando no

**Explicación:** Los VLMs pueden devolver JSON con tipos inconsistentes (`total` como string `"1,234.56"`), fechas en formatos arbitrarios o campos ausentes. Pydantic aplica validaciones (`Field(ge=0)`, `pattern`, coerción de tipos) y lanza `ValidationError` con mensajes específicos que permiten **reintentos guiados**. Pydantic no afecta velocidad (A) ni costo de tokens (C) del modelo. (D) es falso: Pydantic complementa el prompt, no lo reemplaza; de hecho, se recomienda derivar la descripción del prompt a partir del schema (`model_json_schema()`).

---

### Pregunta 7

¿Cuál de los siguientes es un uso correcto de `alt=""` (texto alternativo vacío) para accessibility según WCAG 2.1?

- A) Para una gráfica de ventas trimestrales
- B) Para el logo principal de la marca en el header
- C) Para una imagen puramente decorativa (línea divisoria ornamental) que no aporta información
- D) Para una foto de producto en una tienda e-commerce

**Respuesta correcta:** C) Para una imagen puramente decorativa (línea divisoria ornamental) que no aporta información

**Explicación:** WCAG 2.1 establece que las imágenes **puramente decorativas** (ornamentos, separadores, fondos sin significado) deben usar `alt=""` para que los lectores de pantalla las omitan. Una gráfica de ventas (A) necesita alt + long_description detallada. Un logo de marca (B) debe tener alt con el nombre de la marca (ej. `alt="Acme"`). Una foto de producto (D) debe describir el producto para que usuarios con discapacidad visual puedan comprar. Confundir "decorativa" con "cualquier imagen" rompe accessibility sistemáticamente.

---

### Pregunta 8

En un pipeline de UI testing con VLM, ¿cuál es la mejor forma de obtener resultados consistentes entre ejecuciones?

- A) Pedir "¿está bien esta UI?" en lenguaje libre
- B) Usar temperature=0.9 para explorar más opciones
- C) Enviar un checklist cerrado y pedir JSON validado con Pydantic
- D) Enviar la imagen sin instrucciones y esperar que el modelo deduzca qué revisar

**Respuesta correcta:** C) Enviar un checklist cerrado y pedir JSON validado con Pydantic

**Explicación:** La consistencia en tests automatizados exige **salida determinista y estructurada**. Un checklist cerrado (ej. "¿botón Login visible? ¿contraste adecuado? ¿logo en esquina?") con JSON schema fijo valida con Pydantic produce resultados reproducibles y accionables. Lenguaje libre (A) y (D) causa tests flaky. Temperature alta (B) agrava la variabilidad; de hecho se recomienda `temperature=0` o cercano para extracción. Además, los resultados JSON permiten integración directa con CI/CD y reportes de regresión.

---

### Pregunta 9

¿Qué significa que una imagen se convierte en "image tokens" dentro de un VLM generativo como GPT-4V o Claude 3.5?

- A) La imagen se traduce a texto plano en inglés antes de procesarse
- B) La imagen se codifica como una secuencia de embeddings que el LLM procesa igual que tokens de texto, consumiendo cuota de contexto
- C) La imagen se almacena en una base vectorial separada
- D) El modelo detecta objetos y guarda sus coordenadas como tokens

**Respuesta correcta:** B) La imagen se codifica como una secuencia de embeddings que el LLM procesa igual que tokens de texto, consumiendo cuota de contexto

**Explicación:** En VLMs modernos (LLaVA, GPT-4V, Claude 3.x), un encoder visual (ViT o similar) transforma la imagen en una secuencia de vectores (image tokens, típicamente 256–2048 por imagen). Esos vectores se proyectan al espacio del LLM y se concatenan con los tokens de texto. Por eso **las imágenes cuestan tokens** y afectan tanto el precio como la ventana de contexto. (A) es un mito simplificado y falso. (C) describe RAG, no VLMs. (D) describe detectores de objetos tradicionales (YOLO), no VLMs modernos.

---

### Pregunta 10

Procesas 100,000 recibos/día y notas que el 60% son el mismo recibo (facturas recurrentes de clientes empresa). ¿Qué optimización reduce más tu factura mensual?

- A) Cambiar de Claude Sonnet a Opus para mejor calidad
- B) Enviar siempre `detail: "high"` para no fallar
- C) Implementar caché por `hash(imagen) + hash(prompt)` y devolver respuestas cacheadas cuando coinciden
- D) Procesar en serie (sin asyncio) para no saturar la API

**Respuesta correcta:** C) Implementar caché por `hash(imagen) + hash(prompt)` y devolver respuestas cacheadas cuando coinciden

**Explicación:** Si el 60% de las imágenes se repiten, un caché simple (Redis, S3, SQLite) con clave `sha256(imagen_bytes) + sha256(prompt)` elimina el 60% de las llamadas al VLM: ahorro directo del 60% de la factura. Cambiar a Opus (A) **sube** el costo ~5x sin beneficio claro para extracción simple. `detail: "high"` (B) encarece todo sin resolver el problema de duplicados. Procesar en serie (D) no ahorra dinero, solo aumenta la latencia total. El caché es la optimización individual con mejor ROI en aplicaciones de alto volumen con redundancia.
