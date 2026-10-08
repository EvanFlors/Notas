# Quiz: Generación de Imágenes

**Contexto del escenario:** estás construyendo una plataforma de visualización de producto para una empresa de e-commerce. El sistema genera imágenes de producto para campañas de marketing, crea variaciones de fotos existentes y edita imágenes para mostrar productos en distintos contextos. Usas la API `gpt-image-1-mini` de OpenAI y necesitas manejar 500 generaciones por hora manteniendo consistencia de marca y calidad.

---

## Pregunta 1

Un vendedor quiere mostrar su zapatilla blanca sobre un fondo de playa en lugar del fondo blanco de estudio. La foto original del producto es de alta calidad. ¿Qué enfoque deberías usar?

- Generar una imagen completamente nueva con `gpt-image-1-mini` describiendo zapatillas en la playa
- **Usar edición de imagen (inpainting) con una máscara para reemplazar solo el fondo** ✅
- Crear una variación de la imagen original
- Usar `gpt-4.1-mini` para describir la zapatilla y luego generar desde esa descripción

**Explicación:** la edición con máscara (inpainting) preserva **exactamente** el producto original (color, textura, forma, iluminación) y solo modifica la región enmascarada —en este caso el fondo blanco—. Esto garantiza fidelidad al producto real, algo crítico en e-commerce donde el cliente espera recibir lo que ve. Generar desde cero introduce variaciones no deseadas en el producto (color ligeramente distinto, suela diferente, logo mal); las variaciones de DALL-E 2 cambian el producto entero; y describir con un LLM pierde detalles visuales exactos. En OpenAI, `images.edit` acepta una imagen base + máscara PNG (con píxeles transparentes marcando la zona a modificar) + prompt describiendo el nuevo contenido.

---

## Pregunta 2

Tu prompt `"product photo of headphones"` genera resultados inconsistentes. Algunas imágenes muestran earbuds, otras over-ear, con estilos variados. ¿Cómo mejoras la consistencia?

- Añadir `"high quality"` y `"professional"` al prompt
- **Especificar detalles exactos: `"over-ear wireless headphones, matte black, cushioned ear cups, on white background, product photography lighting"`** ✅
- Generar 10 imágenes y elegir la mejor
- Bajar la temperatura para reducir aleatoriedad

**Explicación:** la **ambigüedad del prompt** es la causa raíz. `"headphones"` es un término genérico que cubre múltiples categorías (earbuds, on-ear, over-ear, noise-cancelling, gaming). Al añadir especificidad —tipo (`over-ear`), características técnicas (`wireless`, `cushioned ear cups`), color/material (`matte black`), setting (`white background`) e iluminación (`product photography lighting`)— reduces el espacio de interpretación del modelo y obtienes resultados reproducibles. Añadir palabras genéricas como `"high quality"` no desambigua. Generar y filtrar es caro (10× costo). La API de imágenes no expone un parámetro de temperatura equivalente al de LLMs; el control de aleatoriedad se hace con **seed** en modelos open-source, no en DALL-E/GPT-Image.

---

## Pregunta 3

Quieres usar la API de edición de imágenes de OpenAI para añadir un logo a una imagen de producto. ¿Cuáles son los requisitos técnicos para la máscara?

- La máscara debe ser JPEG resaltando el área del logo en rojo
- **La máscara debe ser PNG con regiones transparentes indicando dónde editar** ✅
- No necesitas máscara: solo describe en el prompt dónde colocar el logo
- La máscara debe tener el mismo tamaño que el logo que quieres añadir

**Explicación:** la API `client.images.edit` de OpenAI exige una máscara en formato **PNG con canal alpha**, del **mismo tamaño que la imagen base**, donde los **píxeles transparentes (alpha = 0)** marcan la región que el modelo debe modificar y los píxeles opacos se preservan intactos. JPEG no soporta transparencia, por lo que es inválido. Describir en el prompt sin máscara usaría `images.generate`, pero perderías la imagen base entera. La máscara debe cubrir toda la imagen (no solo el tamaño del logo) porque sus dimensiones indican la región permitida de cambio. Este contrato es el estándar de inpainting en toda la industria (Stable Diffusion, DALL-E, GPT-Image).

---

## Pregunta 4

Necesitas generar tanto banners de marketing artísticos como mockups de producto realistas. ¿Cómo deberías configurar el parámetro `style`?

- Usar siempre `"vivid"` para resultados más llamativos
- Usar siempre `"natural"` para resultados más profesionales
- **Usar `"vivid"` para banners de marketing y `"natural"` para mockups de producto** ✅
- El parámetro `style` no afecta la calidad; solo importa el wording del prompt

**Explicación:** DALL-E 3 expone un parámetro `style` con dos valores: `"vivid"` (saturación alta, colores dramáticos, apariencia hiperrealista estilizada) y `"natural"` (colores más apagados y realistas, menos post-procesado). El uso correcto depende del caso: `"vivid"` funciona para **banners de marketing** donde quieres impacto visual, saturación comercial y estética publicitaria llamativa; `"natural"` funciona para **mockups de producto** donde el cliente debe ver colores fieles a la realidad para tomar decisión de compra (una zapatilla roja debe verse roja, no fluorescente). Elegir uno solo para todo degrada el otro caso de uso. El parámetro **sí tiene efecto medible** en el output y no depende solo del prompt.

---

## Pregunta 5

Tu petición de generación falla con una violación de política de contenido para un producto legítimo (cuchillos de cocina). ¿Cuál es la mejor estrategia de producción?

- Reintentar la misma petición: el filtrado de contenido es probabilístico
- **Reformular el prompt enfatizando el contexto culinario: `"chef's kitchen knife set for cooking, professional culinary equipment"`** ✅
- Usar otra API sin restricciones de contenido
- Eliminar el producto del catálogo porque no se puede generar

**Explicación:** los filtros de contenido de OpenAI son **determinísticos para el mismo input** —reintentar la misma petición dará exactamente el mismo rechazo, consumiendo cuota y métricas de error sin resolver el problema—. La solución correcta es **añadir contexto semántico** que desambigüe la intención: palabras como `"chef"`, `"kitchen"`, `"cooking"`, `"culinary equipment"` sitúan al cuchillo en un marco culinario legítimo, no en uno violento. Esto se llama **prompt engineering defensivo** y es una capa estándar en pipelines de producción. Migrar a una API "sin restricciones" expone al negocio a riesgos legales (deepfakes, contenido ilegal) y reputacionales enormes. Eliminar el producto del catálogo es rendirse ante un problema soluble con 10 segundos de rework. En producción conviene mantener una tabla de **plantillas de reformulación por categoría de producto** para automatizar esta mitigación.
