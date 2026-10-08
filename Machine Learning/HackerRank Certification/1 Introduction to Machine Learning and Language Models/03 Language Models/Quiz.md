# Quiz: Modelos de Lenguaje y Tokenización

> **Contexto del escenario:** tu red neuronal detecta bugs pero no explica **por qué** el código es problemático. Los desarrolladores ignoran el 60% de las advertencias sin explicación. Exploras modelos de lenguaje para entender el código semánticamente y generar explicaciones útiles.

---

### Pregunta 1

¿Qué capacidad **distingue** a los modelos de lenguaje de los enfoques tradicionales de análisis de código?

- [x] Los modelos de lenguaje aprenden **relaciones semánticas** entre distintas convenciones de nombres (p. ej. `readFile`, `load_data`, `fetch_content` realizan operaciones similares).
- [ ] Los modelos de lenguaje procesan código más rápido que el parseo de un árbol de sintaxis abstracta (AST).
- [ ] Los modelos de lenguaje requieren menos recursos computacionales que las redes neuronales.
- [ ] Los modelos de lenguaje funcionan mejor con lenguajes compilados que con interpretados.

**Respuesta correcta:** opción 1.

**Explicación:** los modelos de lenguaje aprenden **embeddings** que acercan en el espacio vectorial a identificadores con significado parecido aunque la cadena de caracteres sea distinta (`readFile ≈ load_data ≈ fetch_content`). Esto les permite **generalizar más allá del match exacto** que hacen los AST o las reglas basadas en regex. Los AST son más rápidos y deterministas, pero son ciegos a la semántica: sólo ven la estructura sintáctica. Los LMs son más caros en cómputo (no menos), y son agnósticos al tipo de lenguaje (compilado o interpretado).

---

### Pregunta 2

Para **entender y clasificar** patrones de código existentes, ¿qué arquitectura de modelo de lenguaje es la más adecuada?

- [x] Modelos tipo **BERT** (encoder bidireccional) para entender el contexto del código.
- [ ] Modelos tipo **GPT** (generación autorregresiva) para entender el contexto del código.
- [ ] Ambas arquitecturas son igualmente adecuadas.
- [ ] Ninguna: el parseo tradicional es mejor para análisis de código.

**Respuesta correcta:** opción 1.

**Explicación:** BERT usa **atención bidireccional**, viendo todo el contexto a izquierda y derecha simultáneamente. Esto es exactamente lo que necesitas para *clasificar* o *entender* un fragmento de código: cada token aprovecha información tanto previa como posterior. GPT, al ser causal (sólo mira hacia atrás), está diseñado para **generar** texto nuevo; aunque puede clasificar vía prompt, es menos eficiente y más caro que un BERT fine-tuned para la misma tarea. El parseo tradicional es útil, pero no reemplaza la comprensión semántica que da el embedding contextual.

---

### Pregunta 3

¿Por qué la **tokenización** es particularmente importante para analizar código en comparación con el lenguaje natural?

- [x] El código contiene **símbolos significativos** (operadores, corchetes, delimitadores) e identificadores que una tokenización basada en palabras destruiría.
- [ ] El código es generalmente más corto que el texto en lenguaje natural.
- [ ] El código no sigue reglas gramaticales como el lenguaje natural.
- [ ] El código usa sólo caracteres ASCII, sin complejidad Unicode.

**Respuesta correcta:** opción 1.

**Explicación:** en lenguaje natural puedes tokenizar por espacios y perder poco. En código, símbolos como `==`, `!=`, `=>`, `::`, `++`, los paréntesis y los corchetes **cargan semántica crítica** (un `==` es muy distinto de un `=`). Además, los identificadores camelCase o snake_case necesitan dividirse de forma informativa: `getUserData → ['get', 'User', 'Data']` con tokenizadores subword (BPE/WordPiece) preserva la señal de las sub-palabras. Un tokenizador que descarta símbolos o corta mal los identificadores destruye información necesaria para que el modelo entienda el programa. Las otras opciones son falsas (el código suele ser largo, sí tiene gramática formal estricta, y hoy día usa Unicode con frecuencia).

---

### Pregunta 4

Tu modelo logra 89% de accuracy detectando bugs. ¿Qué capacidad mejoraría más la adopción por parte de los desarrolladores?

- [ ] Subir la accuracy a 95% con mejor entrenamiento.
- [ ] Reducir el tiempo de inferencia de 200 ms a 50 ms.
- [x] **Generar explicaciones claras** de por qué un fragmento de código se marca como potencialmente defectuoso.
- [ ] Soportar lenguajes de programación adicionales más allá del stack actual.

**Respuesta correcta:** opción 3.

**Explicación:** el problema planteado es social, no técnico: los desarrolladores **ignoran el 60%** de las advertencias por falta de contexto. Subir del 89% al 95% de accuracy mejora el producto, pero no ataca la raíz —la **confianza**. Las explicaciones permiten que el desarrollador: (a) valide si la advertencia aplica a su caso, (b) aprenda del error, y (c) construya confianza en el sistema. Esto es precisamente dónde los **LLMs tipo GPT** aportan valor sobre un clasificador puro: pueden *generar* justificaciones en lenguaje natural. Latencia y cobertura ayudan, pero no resuelven el problema del "ignore rate".

---

### Pregunta 5

Al procesar código con modelos de lenguaje, ¿qué desafío de **tokenización** es más crítico manejar correctamente?

- [ ] Manejar comentarios y docstrings.
- [ ] Procesar archivos muy largos que exceden los límites de tokens.
- [x] **Preservar la estructura del código** y las relaciones entre identificadores mientras se manejan unidades subword.
- [ ] Gestionar distintos estilos de indentación y formato.

**Respuesta correcta:** opción 3.

**Explicación:** el reto central es balancear dos fuerzas opuestas. Por un lado, debes **preservar el significado estructural**: llamadas a funciones, declaraciones de variables, encadenamiento de métodos. Por otro, debes **tolerar identificadores desconocidos** usando tokenización subword (BPE/WordPiece/SentencePiece) para que `myCustomParserV2` no se vuelva un `UNK`. Si la tokenización corta mal (`myCustom` + `ParserV2` perdiendo la relación), el modelo pierde la pista de que es un identificador único. Los comentarios, el tamaño del archivo y la indentación son problemas reales, pero secundarios: se resuelven con sliding windows, filtrado o normalización. Lo que **no** se puede arreglar después es una tokenización que haya destruido la estructura semántica original.

---

## Resumen conceptual del quiz

- Los **modelos de lenguaje** entienden similitud semántica entre nombres distintos, algo que los AST no pueden hacer.
- Para **entender** usa encoders bidireccionales (**BERT**); para **generar explicaciones** usa decoders (**GPT**).
- La **tokenización subword** (BPE, WordPiece, SentencePiece, tiktoken) es la que mejor equilibra vocabulario finito y cobertura de identificadores raros.
- La adopción de herramientas de IA depende tanto de la **calidad de la salida** como de su **explicabilidad**.
- En código, preservar **operadores, delimitadores y relaciones entre identificadores** es la decisión de tokenización más importante.
