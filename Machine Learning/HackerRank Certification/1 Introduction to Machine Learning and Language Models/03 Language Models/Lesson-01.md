# Modelado de Lenguaje: Clasificación y Reconocimiento de Entidades (NER)

## ¿Qué es?

El **modelado de lenguaje** (Language Modeling) es la disciplina dentro del NLP (Natural Language Processing) que enseña a una computadora a **entender, representar y manipular lenguaje humano** mediante patrones estadísticos aprendidos a partir de grandes volúmenes de texto. Un *modelo de lenguaje* (LM) es, formalmente, una **distribución de probabilidad sobre secuencias de tokens**:

```
P(w₁, w₂, …, wₙ) = Π P(wᵢ | w₁, …, wᵢ₋₁)
```

Esta formulación —la **regla de la cadena** aplicada al texto— es la base matemática que une tanto a los modelos n-gram clásicos de los años 80 como a los LLMs modernos tipo GPT-4. Un LM responde a la pregunta: *"¿qué tan plausible es esta secuencia de palabras?"*. A partir de esa capacidad se derivan tareas concretas:

- **Clasificación de texto:** asignar una etiqueta (o varias) a un documento completo.
- **Reconocimiento de entidades nombradas (NER):** encontrar y etiquetar fragmentos específicos (personas, lugares, organizaciones, fechas).
- **Generación de texto:** completar o producir texto nuevo.
- **Traducción, resumen, respuesta a preguntas, etc.**

En esta lección nos enfocamos en los dos pilares más usados en producción: **clasificación** y **NER**.

> **Dato histórico:** Claude Shannon, en *A Mathematical Theory of Communication* (1948), fue el primero en usar modelos probabilísticos de lenguaje para estimar la entropía del inglés escrito. Shannon modeló letras y palabras como procesos de Markov, sembrando la semilla matemática del campo.

### Jerarquía conceptual

```
Procesamiento de Lenguaje Natural (NLP)
└── Modelado de Lenguaje (LM)
    ├── Modelos estadísticos (n-grams, HMM)
    ├── Modelos neuronales clásicos (RNN, LSTM)
    └── Modelos basados en Transformers
        ├── Encoder-only  → BERT, RoBERTa      (entendimiento)
        ├── Decoder-only  → GPT, LLaMA, Claude (generación)
        └── Encoder-Decoder → T5, BART         (seq2seq)
```

## ¿Por qué importa?

El texto no estructurado representa, según IDC, más del **80% de los datos empresariales**: correos, tickets, contratos, chats, publicaciones, documentación. Procesar manualmente ese volumen es inviable. El modelado de lenguaje convierte texto crudo en **señal accionable**:

- **Enrutamiento automático de tickets:** reduce tiempos de respuesta de horas a segundos.
- **Moderación de contenido:** detecta discursos de odio o spam antes del humano.
- **Análisis de sentimiento:** mide satisfacción de clientes a escala.
- **Extracción estructurada:** convierte un contrato PDF en filas de base de datos.
- **Compliance y legal:** identifica PII (datos personales) para GDPR o HIPAA.

Sin modelado de lenguaje, no existirían Gmail (filtro de spam), LinkedIn (parseo de CVs), Zendesk (routing), Grammarly (corrección), ni los asistentes conversacionales que usamos hoy.

### Impacto económico

| Industria | Caso de uso | Beneficio típico |
|---|---|---|
| Atención al cliente | Clasificación de tickets | -40% en tiempo de resolución |
| Reclutamiento | NER sobre CVs | 10x candidatos filtrados por hora |
| Legal / M&A | Extracción de cláusulas en contratos | 70% menos horas de abogado junior |
| Salud | NER de medicamentos y dosis | Reducción de errores de medicación |
| Finanzas | Clasificación de reclamos | Automatización de triage |

## ¿Cómo funciona?

Un sistema de modelado de lenguaje opera en tres fases:

1. **Preprocesamiento y tokenización:** convertir texto en unidades discretas (tokens) y luego en vectores numéricos.
2. **Modelo:** una función que mapea esos vectores a predicciones (etiquetas o probabilidades).
3. **Evaluación:** métricas específicas de la tarea (accuracy, F1, precision/recall por entidad).

### Clasificación de texto

En clasificación, dado un documento `x`, el modelo predice una etiqueta `y ∈ {C₁, C₂, …, Cₖ}`:

```
ŷ = argmax_{c ∈ C}  P(c | x)
```

Para calcular `P(c | x)` existen múltiples enfoques:

| Enfoque | Representación | Modelo | Cuándo usarlo |
|---|---|---|---|
| Bolsa de palabras (BoW) + Naive Bayes | Conteos de palabras | Multinomial NB | Baseline rápido, datasets pequeños |
| TF-IDF + Regresión Logística / SVM | Pesos TF-IDF | LogReg, SVM lineal | Clasificación de texto corto, interpretable |
| Embeddings estáticos + CNN/LSTM | Word2Vec, GloVe | Red neuronal | Datasets medianos (10k–100k ejemplos) |
| Transformers fine-tuned | BERT, DistilBERT | Encoder + head | Alto rendimiento, datos abundantes |
| LLMs con zero/few-shot | Prompt engineering | GPT-4, Claude | Sin datos de entrenamiento |

#### Tipos de clasificación

- **Binaria:** spam vs. no-spam.
- **Multiclase:** categorizar noticia en {deportes, política, ciencia, ...}.
- **Multi-etiqueta:** un correo puede ser {urgente, facturación} simultáneamente.
- **Jerárquica:** categorías anidadas (electrónica → smartphones → Android).

### Named Entity Recognition (NER)

NER es un problema de **etiquetado de secuencias**: a cada token le asignamos una etiqueta de entidad. El esquema estándar es **BIO (Beginning–Inside–Outside)**:

```
Token:  John   Smith   trabaja  en   Google   Mountain  View
BIO:    B-PER  I-PER    O       O    B-ORG    B-LOC     I-LOC
```

- `B-X`: inicio de una entidad de tipo X.
- `I-X`: continuación de esa entidad.
- `O`: fuera de toda entidad.

Variantes: **BIOES** (añade `E` para fin y `S` para entidades de un solo token), útil cuando necesitas delimitar límites con precisión.

![Esquema BIO para NER](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson01-bio-tagging-scheme.svg)

#### Entidades típicas

| Tipo | Ejemplo | Dominio donde importa |
|---|---|---|
| PER (persona) | "Marie Curie" | Noticias, biografías |
| ORG (organización) | "Google", "ONU" | Finanzas, prensa |
| LOC (lugar) | "Berlín" | Logística, viajes |
| DATE | "15 de marzo de 2024" | Contratos, legal |
| MONEY | "$1,250.00" | Facturación, finanzas |
| EMAIL / PHONE | contacto@ejemplo.com | CRM, soporte |
| DRUG, DOSE | "ibuprofeno 400 mg" | Salud |
| LAW, CASE | "Art. 123 LFT" | Legal |

![Clasificación vs. NER](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson01-classification-vs-ner.svg)

### Pipeline completo

```
Texto crudo
    ↓
Normalización (lowercase, acentos, Unicode NFC)
    ↓
Tokenización (whitespace, regex, subword BPE)
    ↓
Vectorización (BoW, TF-IDF, embeddings)
    ↓
Modelo (clasificador o etiquetador de secuencia)
    ↓
Post-procesamiento (umbrales, consolidación BIO)
    ↓
Métricas (accuracy, F1 por entidad)
```

### Métricas específicas

Para clasificación:

- **Accuracy** si las clases están balanceadas.
- **Precision, Recall, F1** por clase, y **macro-F1** o **weighted-F1** si no lo están.

Para NER, la métrica estándar es **F1 a nivel de entidad** (no de token): una entidad cuenta como correcta sólo si *tanto el tipo como los límites exactos* coinciden. Es más estricta que el F1 por token.

## Ejemplo con código

### 1. Clasificador de tickets de soporte

```python
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Dataset de entrenamiento
training_data = [
    ("No puedo iniciar sesión en mi cuenta",   "Autenticación"),
    ("Olvidé mi contraseña",                   "Autenticación"),
    ("La verificación en dos pasos falla",     "Autenticación"),
    ("Cobro duplicado en mi tarjeta",          "Facturación"),
    ("Pregunta sobre mi factura mensual",      "Facturación"),
    ("Quiero cancelar mi suscripción",         "Facturación"),
    ("La app se cierra sola",                  "Técnico"),
    ("No carga los datos del dashboard",       "Técnico"),
    ("Error 500 al guardar cambios",           "Técnico"),
    ("Me gustaría una función de exportar",    "Producto"),
    ("Sugerencia: modo oscuro en móvil",       "Producto"),
]

X, y = zip(*training_data)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42, stratify=y
)

pipeline = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=1, sublinear_tf=True)),
    ("clf", MultinomialNB(alpha=0.5)),
])

pipeline.fit(X_train, y_train)
y_pred = pipeline.predict(X_test)

print(classification_report(y_test, y_pred, zero_division=0))

# Predicción con umbral de confianza (para enrutar casos ambiguos a humano)
nuevos = [
    "Me cobraron de más este mes",
    "El botón de guardar no responde",
    "Pueden añadir integración con Slack?",
]
probs = pipeline.predict_proba(nuevos)
clases = pipeline.classes_

for texto, p in zip(nuevos, probs):
    top = max(zip(clases, p), key=lambda kv: kv[1])
    categoria, conf = top
    destino = categoria if conf >= 0.60 else "Revisión humana"
    print(f"'{texto}' → {destino} (confianza={conf:.2f})")
```

**Observa el umbral de confianza:** en producción nunca debes forzar cada caso a una categoría. Enrutar lo ambiguo a un humano protege la experiencia del usuario y provee datos valiosos para re-entrenar.

### 2. NER basado en reglas (regex)

Útil como baseline y para entidades estructuradas (emails, teléfonos, dinero):

```python
import re
from collections import defaultdict

class SimpleNER:
    def __init__(self):
        self.patterns = {
            "PERSON": [
                r"\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+ [A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\b",
                r"\b(?:Sr|Sra|Dr|Dra)\.?\s[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\b",
            ],
            "EMAIL": [r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"],
            "PHONE": [
                r"\b\d{3}-\d{3}-\d{4}\b",
                r"\(\d{3}\)\s?\d{3}-\d{4}\b",
                r"\+\d{1,3}\s?\d{2,}\s?\d{4,}\b",
            ],
            "MONEY": [r"\$\s?[\d,]+(?:\.\d{2})?\b"],
            "DATE":  [r"\b\d{1,2}/\d{1,2}/\d{2,4}\b"],
        }

    def extract(self, text: str):
        found = defaultdict(list)
        for tipo, patrones in self.patterns.items():
            for pat in patrones:
                for m in re.finditer(pat, text):
                    found[tipo].append({"text": m.group(), "start": m.start(), "end": m.end()})
        return dict(found)


ner = SimpleNER()
texto = "Contacta a Sra. López en lopez@empresa.com o (555) 123-4567 por el contrato de $12,500.00 vencido el 15/03/2024."
for tipo, lista in ner.extract(texto).items():
    print(f"{tipo}: {[e['text'] for e in lista]}")
```

### 3. NER profesional con spaCy

```python
# pip install spacy && python -m spacy download es_core_news_md
import spacy

nlp = spacy.load("es_core_news_md")

texto = ("Elon Musk anunció en Austin que Tesla invertirá 10 mil millones de dólares "
         "en una nueva planta durante 2025, en colaboración con Panasonic.")

doc = nlp(texto)
for ent in doc.ents:
    print(f"{ent.text:<25} {ent.label_:<10} ({ent.start_char}-{ent.end_char})")

# Entrenamiento rápido con tus propias entidades (patrones):
from spacy.pipeline import EntityRuler
ruler = nlp.add_pipe("entity_ruler", before="ner")
patterns = [
    {"label": "DRUG",  "pattern": "ibuprofeno"},
    {"label": "DOSE",  "pattern": [{"LIKE_NUM": True}, {"LOWER": {"IN": ["mg", "ml"]}}]},
]
ruler.add_patterns(patterns)
```

### 4. Clasificación con BERT (vista previa)

```python
# pip install transformers torch
from transformers import pipeline

clf = pipeline("sentiment-analysis",
               model="nlptown/bert-base-multilingual-uncased-sentiment")

for frase in ["Me encantó el producto", "Pésima atención", "Está bien, nada especial"]:
    print(frase, "→", clf(frase)[0])
```

Verás BERT en profundidad en la Lesson 02; aquí basta notar que con 3 líneas obtenemos un clasificador multilingüe listo para producción.

## Errores comunes

- **Confundir clasificación con NER.** Clasificación etiqueta el *documento entero*; NER etiqueta *fragmentos internos*. Mezclar objetivos conduce a modelos imposibles de evaluar.
- **Preprocesar demasiado para NER.** Para clasificación bajar a minúsculas puede ayudar; para NER *destruye* señal: "Apple" (empresa) y "apple" (fruta) deben distinguirse.
- **Forzar todo a categorías existentes.** Siempre añade una categoría `"otros"` o `"revisión_humana"` con umbral de confianza para evitar errores silenciosos.
- **Olvidar BIO en NER.** Si no modelas los límites, "Nueva York" aparecerá como dos entidades `LOC` separadas.
- **Clases desbalanceadas sin ajuste.** 99% "no-spam" + 1% "spam" → accuracy 99% con un modelo que predice siempre "no-spam". Usa `class_weight="balanced"` o técnicas de resampling (SMOTE).
- **Data leakage por normalización global.** Calcular TF-IDF sobre todo el corpus (train + test) antes del split filtra información del test al train.
- **Concept drift ignorado.** Un clasificador entrenado en 2019 no reconoce "COVID" o "stake" (cripto). Reentrena con feedback real.
- **Métricas en el nivel equivocado.** NER evaluado a nivel de token sobreestima el desempeño; usa F1 a nivel de entidad.
- **No manejar OOV (out-of-vocabulary).** Con tokenización por palabras, cualquier palabra nueva en producción se vuelve `UNK`. Prefiere subword tokenization (BPE, WordPiece, SentencePiece).
- **Ambigüedad semántica sin contexto.** "Apple" sin el resto de la oración es irresoluble; esto motivó la transición de Word2Vec a embeddings contextuales como ELMo (2018) y BERT (2018).

## Herramientas del ecosistema

| Herramienta | Propósito | Fortaleza |
|---|---|---|
| **NLTK** | Didáctica, baseline académico | Tokenizadores, corpora clásicos |
| **spaCy** | NER + pipelines productivos | Rápido, multilingüe, API limpia |
| **scikit-learn** | Clasificación tradicional | TF-IDF, SVM, LogReg, pipelines |
| **gensim** | Topic modeling, Word2Vec | LDA, embeddings estáticos |
| **HuggingFace Transformers** | LLMs y encoders modernos | 100k+ modelos, `pipeline()` |
| **tiktoken** | Tokenización de OpenAI | Rápido, consistente con GPT |
| **Flair** | NER con embeddings contextuales | Buen SOTA para NER |
| **Stanza (Stanford)** | NLP multilingüe académico | Modelos para 70+ idiomas |

## Combinando clasificación y NER

Los sistemas reales suelen encadenar ambos:

```
Documento legal
    ↓
Clasificador  → "Contrato de arrendamiento"
    ↓
NER especializado para arrendamientos
    ↓
{partes: ["Juan Pérez", "InmoSA"], renta: "$15,000 MXN",
 vigencia: "12 meses", inicio: "2024-04-01"}
    ↓
Base de datos estructurada
```

Esta combinación es la base de productos como **DocuSign Insight**, **Hyperscience** o **UiPath Document Understanding**.

## Resumen

- Un **modelo de lenguaje** asigna probabilidad a secuencias de texto; esa capacidad habilita clasificación, NER, generación y más.
- La **clasificación** etiqueta documentos enteros; el **NER** etiqueta fragmentos internos mediante esquemas como **BIO**.
- Para clasificación clásica, el stack **TF-IDF + regresión logística/Naive Bayes** sigue siendo un baseline competitivo y barato.
- Para NER usa **spaCy** (producción) o **BERT fine-tuned** (SOTA); los regex sirven para entidades estructuradas.
- Las **métricas** importan: F1 a nivel entidad para NER, macro/weighted-F1 para clases desbalanceadas, umbrales de confianza para casos ambiguos.
- **Preprocesamiento ≠ NER-friendly:** lowercase y stemming ayudan a clasificar pero destruyen pistas para NER.
- Los sistemas reales **combinan ambos**: primero clasifican el tipo de documento, luego aplican el NER correcto.
- Monitorea **concept drift**, maneja **OOV con subwords**, incluye una categoría de **"revisión humana"** y audita **sesgos** por grupo (género, región, idioma).
- Shannon (1948) sentó la base probabilística; de ahí evolucionamos a n-grams, luego a RNN/LSTM, hasta llegar a los Transformers que verás en las siguientes lecciones.
