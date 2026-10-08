# ¿Qué es Machine Learning?

## ¿Qué es?

**Machine Learning (ML)** es una rama de la inteligencia artificial donde los programas **aprenden patrones a partir de datos** en lugar de seguir reglas escritas a mano. En términos técnicos, un sistema de ML construye una **función parametrizada** `f(x; θ)` cuyos parámetros `θ` se ajustan automáticamente para minimizar un error entre predicciones y realidad.

La diferencia esencial con la programación tradicional es la dirección del flujo:

| Enfoque | Entrada | Salida |
|---|---|---|
| Programación tradicional | Reglas + Datos | Resultado |
| Machine Learning | Datos + Resultados (etiquetas) | Reglas (modelo) |

> **Definición formal (Tom Mitchell, 1997):** Se dice que un programa aprende de la experiencia `E` respecto a una tarea `T` y una medida de desempeño `P`, si su desempeño en `T`, medido por `P`, mejora con la experiencia `E`.

### Jerarquía: IA → ML → Deep Learning → Generative AI

Es común confundir estos términos. La relación de inclusión es:

```
Inteligencia Artificial (IA)
└── Machine Learning (ML)                    ← aprender de datos
    └── Deep Learning (DL)                   ← ML con redes neuronales profundas
        └── Generative AI (LLMs, difusión)   ← DL que genera contenido nuevo
```

- **IA** es el campo amplio: cualquier sistema que exhiba comportamiento "inteligente" (incluye sistemas expertos basados en reglas, búsqueda, planificación).
- **ML** es un subconjunto: *aprende* en lugar de ser programado.
- **DL** usa redes neuronales con muchas capas (típicamente >3).
- **GenAI** son modelos de DL que generan texto, imágenes, audio o código (GPT, Stable Diffusion, Whisper).

### Formalización matemática

Dado un dataset `D = {(xᵢ, yᵢ)}ⁿᵢ₌₁` donde `xᵢ ∈ X` (espacio de entrada) e `yᵢ ∈ Y` (espacio de salida), queremos encontrar una función `f: X → Y` dentro de una familia `H` (hypothesis space) que minimice una **función de pérdida** `L`:

```
θ* = argmin_θ  (1/n) Σᵢ L(f(xᵢ; θ), yᵢ)  +  λ·R(θ)
                └─── pérdida empírica ───┘   └ regularización ┘
```

- `L` penaliza errores (ej. error cuadrático para regresión, cross-entropy para clasificación).
- `R(θ)` desincentiva modelos demasiado complejos (L1, L2) para evitar overfitting.
- `λ` controla el balance entre ajuste y simplicidad.

Este es el **principio de minimización del riesgo empírico (ERM)** y es la base matemática de prácticamente todo ML supervisado.

## ¿Por qué importa?

Las reglas escritas a mano se rompen cuando el mundo cambia. Un filtro anti-spam basado en reglas (`if "win" in email and "money" in email`) queda obsoleto en días: los spammers escriben `w1n m0ney`, `claim reward`, usan imágenes o inyectan texto invisible. Mantener miles de reglas en constante actualización es un juego de **whack-a-mole** imposible de ganar.

Machine Learning importa cuando:

- Los **patrones cambian** con el tiempo (fraude, spam, preferencias de usuario).
- Los patrones son **demasiado complejos** para enumerarse (reconocer una cara, traducir un idioma).
- Hay **mucha data histórica** disponible pero las reglas no son obvias.
- Se requiere **personalización a escala** (recomendaciones para millones de usuarios).

Un modelo bien entrenado **generaliza** a casos que nunca vio, mientras que un sistema de reglas solo cubre los casos que su autor imaginó.

### Cuándo NO usar ML

Igual de importante es saber cuándo evitarlo:

- **Reglas estables y bien definidas:** calcular impuestos, validar un RFC, aplicar una fórmula física. Usa código tradicional.
- **Datos escasos:** <1,000 ejemplos y sin posibilidad de generar más. Un sistema de reglas o un humano experto rendirá mejor.
- **El costo del error es catastrófico y no hay humano en el loop:** cirugía autónoma, control de reactor nuclear. ML en estos dominios requiere capas de seguridad y verificación formal.
- **No se puede explicar la decisión y la regulación lo exige:** aprobación de crédito en ciertas jurisdicciones (GDPR Art. 22). Modelos muy complejos son difíciles de auditar.
- **Problemas combinatorios resolubles exactamente:** mejor usar programación lineal, SAT solvers o algoritmos clásicos.

### Historia breve (contexto cultural)

| Año | Hito |
|---|---|
| 1943 | McCulloch & Pitts: primera neurona matemática |
| 1957 | Rosenblatt: Perceptrón |
| 1986 | Rumelhart et al.: Backpropagation popularizado |
| 1997 | Deep Blue vence a Kasparov (ajedrez) |
| 1998 | LeCun: LeNet-5 (CNN para dígitos) |
| 2006 | Hinton: Deep Belief Networks → nace "Deep Learning" |
| 2012 | AlexNet gana ImageNet por 10 puntos → revolución DL |
| 2017 | Vaswani et al.: *Attention Is All You Need* (Transformers) |
| 2020 | GPT-3 (175B parámetros) |
| 2022 | ChatGPT: ML llega al público masivo |
| 2024+ | Modelos multimodales, agentes autónomos, razonamiento |

## ¿Cómo funciona?

Todo sistema de ML se compone de cuatro ingredientes mínimos:

### 1. Datos
- **Features (características):** variables de entrada medibles. Ejemplo: para un correo, `[cantidad_palabras, tiene_link, remitente_conocido, hora_envío]`.
- **Labels (etiquetas):** la respuesta correcta durante el entrenamiento. Ejemplo: `spam` o `no_spam`.
- **Representación:** los datos crudos (texto, imagen, audio) deben convertirse en números. Un pixel es un entero 0-255; una palabra puede ser un *embedding* vectorial de 768 dimensiones; una categoría se codifica con one-hot encoding.

Regla de oro: la **calidad y cantidad** de los datos suele importar más que la elección del algoritmo. El dicho común en la industria es *"garbage in, garbage out"*.

### 2. Modelo
Una función matemática con **parámetros aprendibles**. En regresión lineal:

```
precio = w₁·área + w₂·habitaciones + b
```

Donde `w₁`, `w₂` y `b` son los parámetros que se ajustan. En redes neuronales profundas estos parámetros son millones o miles de millones (GPT-4 tiene ~1.7 trillones).

**Capacidad del modelo (bias-variance tradeoff):**

- **Alto bias (underfitting):** el modelo es demasiado simple y no captura los patrones. Ejemplo: usar regresión lineal para datos circulares.
- **Alta varianza (overfitting):** el modelo memoriza el ruido del entrenamiento y no generaliza. Ejemplo: un árbol de decisión sin profundidad limitada.
- El objetivo es el **punto dulce**: suficiente capacidad para aprender la señal, pero no tanta como para memorizar el ruido.

```
Error total = Bias² + Varianza + Ruido_irreducible
```

### 3. Algoritmo de aprendizaje
El procedimiento que modifica `θ` para reducir el error. El más común es el **descenso del gradiente**:

```
θ_nuevo = θ_viejo - η · ∇L(θ)
         └─ parámetros ─┘ └ tasa de aprendizaje · gradiente ┘
```

Variantes:

- **Batch GD:** usa todo el dataset para cada paso. Preciso pero lento.
- **SGD (Stochastic):** un ejemplo a la vez. Ruidoso pero escapa de mínimos locales.
- **Mini-batch SGD:** compromiso práctico (32, 64, 128 ejemplos por paso). Estándar en deep learning.
- **Adam, RMSProp, AdamW:** optimizadores adaptativos que ajustan la tasa de aprendizaje por parámetro. AdamW es el default actual en LLMs.

### 4. Métrica de evaluación
Un número que mide qué tan bien funciona el modelo:

| Tipo de problema | Métricas comunes | Cuándo usar |
|---|---|---|
| Clasificación balanceada | Accuracy | Todas las clases importan por igual |
| Clasificación desbalanceada | Precision, Recall, F1 | Fraude, enfermedades raras |
| Clasificación binaria con umbral móvil | AUC-ROC, AUC-PR | Rankear riesgo |
| Regresión | MAE, MSE, RMSE, R² | Predecir cantidades continuas |
| Ranking / Recomendación | NDCG, MAP, MRR, Hit@K | Búsqueda, recsys |
| Generación de texto | BLEU, ROUGE, perplejidad, eval humana, LLM-as-judge | Traducción, resumen, chatbots |
| Visión | mAP (detección), IoU (segmentación), FID (generación) | Imágenes |

**La matriz de confusión** es la herramienta base para clasificación:

```
                 Predicho +    Predicho -
Real +           TP            FN        → Recall = TP/(TP+FN)
Real -           FP            TN        → Specificity = TN/(TN+FP)
                 ↓
                 Precision = TP/(TP+FP)
```

### Tipos de aprendizaje

| Paradigma | Qué recibe | Qué aprende | Ejemplos |
|---|---|---|---|
| **Supervisado** | `(x, y)` etiquetados | Mapeo `x → y` | Spam, precio de casa, diagnóstico |
| **No supervisado** | Solo `x` | Estructura latente | Clustering (K-means), reducción (PCA, UMAP), anomalías |
| **Auto-supervisado** | `x` + tarea artificial | Representaciones ricas | BERT (masked LM), SimCLR (contrastivo), GPT (predecir siguiente token) |
| **Semi-supervisado** | Poco etiquetado + mucho sin etiquetar | Combinar ambos | Pseudo-labeling, consistency training |
| **Por refuerzo (RL)** | Estado + recompensa | Política de acción | AlphaGo, robótica, RLHF para LLMs |
| **Transferencia** | Modelo pre-entrenado + poca data nueva | Ajustar a tarea específica | Fine-tuning, LoRA |

### Pipeline completo

```
Recolección de datos
      ↓
Exploración (EDA: distribuciones, nulos, outliers)
      ↓
Limpieza y feature engineering
      ↓
Split: train / validation / test (ej. 70/15/15)
      ↓
Entrenamiento (ajuste de parámetros)
      ↓
Validación (ajuste de hiperparámetros)
      ↓
Evaluación en test (una sola vez, al final)
      ↓
Despliegue (API, batch, edge, embebido)
      ↓
Monitoreo + re-entrenamiento
```

**Hiperparámetros vs. parámetros:**

- **Parámetros:** se aprenden automáticamente (pesos `w`, bias `b`).
- **Hiperparámetros:** se eligen a mano o con búsqueda (learning rate, número de capas, profundidad de árbol, `k` en KNN). Se tunean con el *validation set*, no con el test set.

Analogía: el **entrenamiento** es estudiar con exámenes pasados; la **validación** es un simulacro para elegir estrategia de estudio; la **evaluación final** es el examen real que solo presentas una vez. Si el modelo memoriza los ejemplos de entrenamiento pero falla en el examen nuevo, hablamos de **overfitting**.

### Validación cruzada (k-fold)

Cuando los datos son escasos, dividirlos en train/val/test desperdicia información. **K-fold cross-validation** divide los datos en `k` partes, entrena `k` veces usando cada parte como validación una vez, y promedia el resultado:

```
Fold 1: [val][train][train][train][train]
Fold 2: [train][val][train][train][train]
Fold 3: [train][train][val][train][train]
...
```

Métricas más robustas, pero `k` veces más costo computacional.

## Ejemplo con código

Comparación lado a lado de un enfoque tradicional y uno de ML para detección de spam:

```python
# ============================================================
# Enfoque tradicional: reglas escritas a mano
# ============================================================
def spam_tradicional(email: str) -> str:
    palabras_sospechosas = ["win", "money", "free", "prize", "urgent"]
    email = email.lower()
    hits = sum(1 for w in palabras_sospechosas if w in email)
    return "SPAM" if hits >= 2 else "NO_SPAM"


# ============================================================
# Enfoque ML: aprender de ejemplos (Naive Bayes simplificado)
# ============================================================
from collections import defaultdict
import math

def entrenar(ejemplos: list[tuple[str, str]]):
    """Cuenta frecuencia de cada palabra por clase."""
    conteos = {"SPAM": defaultdict(int), "NO_SPAM": defaultdict(int)}
    totales = {"SPAM": 0, "NO_SPAM": 0}
    for texto, etiqueta in ejemplos:
        for palabra in texto.lower().split():
            conteos[etiqueta][palabra] += 1
            totales[etiqueta] += 1
    return conteos, totales

def predecir(email: str, conteos, totales, alpha=1.0) -> str:
    """Clasifica usando log-probabilidades con suavizado de Laplace."""
    scores = {}
    vocab = set(conteos["SPAM"]) | set(conteos["NO_SPAM"])
    for clase in ("SPAM", "NO_SPAM"):
        log_prob = math.log(totales[clase] / sum(totales.values()))
        for palabra in email.lower().split():
            # Suavizado: evita probabilidad cero para palabras nuevas
            freq = conteos[clase][palabra] + alpha
            log_prob += math.log(freq / (totales[clase] + alpha * len(vocab)))
        scores[clase] = log_prob
    return max(scores, key=scores.get)


# ============================================================
# Datos de entrenamiento
# ============================================================
dataset = [
    ("win free money now",        "SPAM"),
    ("claim your prize today",    "SPAM"),
    ("urgent action required",    "SPAM"),
    ("w1n money in few days",     "SPAM"),
    ("meeting tomorrow at 3pm",   "NO_SPAM"),
    ("project deadline friday",   "NO_SPAM"),
    ("lunch with team tuesday",   "NO_SPAM"),
]

conteos, totales = entrenar(dataset)

# ============================================================
# Comparación
# ============================================================
pruebas = [
    "win money fast",
    "w1n m0n3y fast",            # el tradicional lo pierde
    "meeting about budget",
    "urgent prize notification",
]

print(f"{'Email':<30} {'Tradicional':<14} {'ML'}")
print("-" * 60)
for correo in pruebas:
    print(f"{correo:<30} {spam_tradicional(correo):<14} {predecir(correo, conteos, totales)}")
```

**Qué observar:** el enfoque tradicional falla con `w1n m0n3y fast` porque la regla no contempla variantes ortográficas. El modelo ML, al aprender estadísticamente de los ejemplos, puede capturar que el patrón general de "pedir dinero con urgencia" es spam, independientemente de la ortografía exacta.

### Versión industrial con scikit-learn (pipeline + validación cruzada)

```python
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import cross_val_score, GridSearchCV
from sklearn.metrics import classification_report, confusion_matrix

X = [t for t, _ in dataset]
y = [l for _, l in dataset]

pipe = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=1, sublinear_tf=True)),
    ("clf", LogisticRegression(max_iter=1000, class_weight="balanced")),
])

# Búsqueda de hiperparámetros con validación cruzada
grid = {
    "tfidf__ngram_range": [(1, 1), (1, 2), (1, 3)],
    "clf__C": [0.1, 1.0, 10.0],       # inverso de la regularización
}
search = GridSearchCV(pipe, grid, cv=3, scoring="f1_macro", n_jobs=-1)
search.fit(X, y)

print("Mejores hiperparámetros:", search.best_params_)
print("F1 promedio en CV:", search.best_score_)

# Reporte de métricas
y_pred = search.predict(X)
print(classification_report(y, y_pred))
print("Matriz de confusión:")
print(confusion_matrix(y, y_pred))
```

### Visualizando bias vs. varianza

```python
import numpy as np
import matplotlib.pyplot as plt
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import LinearRegression
from sklearn.pipeline import make_pipeline

# Datos sintéticos: y = sin(x) + ruido
rng = np.random.default_rng(42)
X = np.linspace(0, 2 * np.pi, 30).reshape(-1, 1)
y = np.sin(X).ravel() + rng.normal(0, 0.2, X.shape[0])

X_test = np.linspace(0, 2 * np.pi, 200).reshape(-1, 1)

fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, grado in zip(axes, [1, 4, 15]):
    modelo = make_pipeline(PolynomialFeatures(grado), LinearRegression())
    modelo.fit(X, y)
    ax.scatter(X, y, color="black", s=20)
    ax.plot(X_test, modelo.predict(X_test), color="red")
    ax.plot(X_test, np.sin(X_test), color="green", linestyle="--", label="verdad")
    diagnostico = {1: "underfitting", 4: "ajuste correcto", 15: "overfitting"}[grado]
    ax.set_title(f"grado {grado} → {diagnostico}")
    ax.legend()
plt.show()
```

- Grado 1: línea recta → *underfitting* (alto bias).
- Grado 4: curva suave que sigue el seno → punto dulce.
- Grado 15: pasa por casi todos los puntos pero oscila salvajemente → *overfitting* (alta varianza).

## Errores comunes

- **Confundir correlación con causalidad.** Un modelo puede aprender que la gente que compra pañales también compra cerveza, pero eso no significa que vender pañales *cause* ventas de cerveza. Para decisiones causales usa inferencia causal (DAGs, do-calculus de Pearl), no solo correlaciones.
- **Data leakage.** Incluir en los features información que en producción no estará disponible al momento de predecir (ej. usar el precio final de venta para predecir el precio de venta). Formas sutiles:
  - *Target leakage:* feature que es efecto de la etiqueta.
  - *Train-test contamination:* normalizar con media global antes del split.
  - *Temporal leakage:* usar datos futuros para predecir el pasado.
- **Entrenar y evaluar en los mismos datos.** El modelo parece perfecto porque memorizó; en producción se desploma. Siempre usa un split train/val/test.
- **Olvidar el *data drift* y *concept drift*.**
  - *Data drift:* la distribución de entradas cambia (nueva demografía de usuarios).
  - *Concept drift:* la relación entre entrada y salida cambia (durante COVID, patrones de compra cambiaron radicalmente).
- **Métrica mal elegida.** Un modelo que siempre predice "no fraude" tiene 99.9% accuracy si solo 0.1% de transacciones son fraude, pero es inútil. Usa precision/recall o F1 cuando las clases están desbalanceadas.
- **Sobre-ingenierizar antes de validar.** Primero comprueba que el problema realmente necesita ML (un *baseline* simple como reglas o regresión logística con TF-IDF puede ganarle a modelos complejos si los datos son limitados).
- **Ignorar el sesgo (bias) en los datos.** Si el dataset histórico refleja discriminación (ej. aprobaciones de crédito sesgadas), el modelo la perpetúa y amplifica. Audita por grupos protegidos.
- **Optimizar la métrica incorrecta.** Goodhart's Law: *"cuando una medida se convierte en objetivo, deja de ser una buena medida"*. Un modelo optimizado por clicks puede generar clickbait y destruir la experiencia del usuario.
- **No versionar datos.** Reproducir un experimento 6 meses después es imposible si el CSV original fue modificado. Usa herramientas como DVC, LakeFS o Delta Lake.
- **No fijar la semilla aleatoria.** Resultados no reproducibles → debuggear bugs es una pesadilla. `random.seed(42)`, `np.random.seed(42)`, `torch.manual_seed(42)`.
- **Olvidar el costo de los falsos positivos/negativos.** En diagnóstico médico, un falso negativo (no detectar cáncer) es mucho más costoso que un falso positivo (biopsia innecesaria). Elige el umbral consciente de esto.

## Casos de uso reales

| Dominio | Aplicación | Tipo de modelo típico |
|---|---|---|
| Email | Filtro de spam (Gmail) | Clasificación (SVM, LR, Transformers) |
| Streaming | Recomendación de películas (Netflix) | Collaborative filtering, matrix factorization, two-tower NN |
| Banca | Detección de fraude en tiempo real | Gradient boosting (XGBoost, LightGBM), redes neuronales |
| Industria | Mantenimiento predictivo | Series de tiempo, LSTM, Prophet |
| Salud | Diagnóstico asistido por imagen | CNN (ResNet, EfficientNet), ViT |
| Dev tools | Autocompletado de código (Copilot) | Transformers / LLMs (Codex, Code Llama) |
| Logística | Optimización de rutas (Uber, Amazon) | Reinforcement learning, grafos (GNN) |
| Marketing | Churn prediction, LTV | XGBoost, survival analysis |
| Legal | Clasificación de contratos, due diligence | BERT fine-tuned, LLMs con RAG |
| Agricultura | Detección de plagas por drone | Object detection (YOLO), segmentación |

## Machine Learning en producción

Entrenar un modelo en Jupyter es apenas el 10% del trabajo. Un sistema en producción debe gestionar:

- **Latencia:** responder en milisegundos (autocompletado, antifraude en tiempo real). Un modelo con 500ms de inferencia es inviable para búsqueda web.
- **Throughput:** millones de requests por hora → batching, cuantización, modelos destilados.
- **Escala horizontal:** balanceadores, autoscaling en Kubernetes, serving con Triton / vLLM / TorchServe.
- **Monitoreo:** detectar degradación por *data drift* o *concept drift*. Herramientas: Evidently, WhyLabs, Arize.
- **Versionado completo:** saber exactamente qué datos + código + hiperparámetros produjeron el modelo desplegado (reproducibilidad). Stack común: MLflow + DVC + Git.
- **Feedback loop:** capturar predicciones y outcomes reales para re-entrenar. Cuidado con *feedback loops* perversos (un sistema de recomendación que solo recomienda lo popular refuerza su propio sesgo).
- **Fairness y sesgo:** auditar que el modelo no discrimine por género, raza, edad, etc. (fairlearn, AIF360).
- **Explicabilidad:** SHAP, LIME, counterfactuals. Obligatorio en finanzas, salud, HR.
- **Rollback y canary deployments:** desplegar al 1% de usuarios primero, medir, luego escalar.
- **Shadow deployment:** correr el modelo nuevo en paralelo con el viejo sin servir sus respuestas, para comparar.

### El ciclo real (MLOps)

```
┌──────────────────────────────────────────────┐
│   Data → Features → Train → Eval → Deploy    │
│     ↑                                   ↓    │
│     └──── Monitor ← Serve ← Users ←─────┘    │
└──────────────────────────────────────────────┘
```

Esto es el territorio de **MLOps** (y para modelos generativos, **LLMOps**), que verás en módulos posteriores del curso.

## Conceptos relacionados que explorarás

- **Feature engineering** y **feature stores** (Feast, Tecton).
- **AutoML** (H2O, AutoGluon, Google Vertex AI).
- **Transfer learning** y **fine-tuning** (ver Módulo 6).
- **Prompt engineering** como "programación" de LLMs (ver Módulo 2).
- **Retrieval-Augmented Generation (RAG)** para dar contexto fresco a los LLMs (ver Módulo 3).
- **Agentes** que combinan LLMs con herramientas y memoria (ver Módulo 4).

## Resumen

- Machine Learning **invierte** la lógica tradicional: en vez de reglas, le damos datos y etiquetas y el sistema aprende las reglas.
- Todo sistema ML tiene cuatro ingredientes: **datos**, **modelo**, **algoritmo de aprendizaje** y **métrica**.
- El modelo es una **función parametrizada**; aprender = resolver `argmin_θ L(θ) + λR(θ)` (ERM).
- Entender el **bias-variance tradeoff** es esencial: ni demasiado simple (underfitting) ni demasiado complejo (overfitting).
- Existen muchos **paradigmas** de aprendizaje: supervisado, no supervisado, auto-supervisado, semi-supervisado, refuerzo, transferencia. Elegir el correcto depende de qué datos tengas.
- ML es la respuesta correcta cuando los patrones son **complejos**, **cambiantes** o requieren **generalización**. Para reglas estables, mejor código tradicional.
- **Métricas desalineadas** son el error más caro: siempre pregúntate qué significa fallar y a quién le duele.
- Un modelo que funciona en el notebook no sirve si no sobrevive en producción: **monitoreo**, **versionado**, **fairness** y **re-entrenamiento** son parte del trabajo real.
- Siempre valida con un **baseline simple** antes de invertir en modelos complejos: a veces una regresión logística con buenos features le gana a una red neuronal gigante.
- La historia va de perceptrones (1957) a transformers (2017) a agentes (2024+); entender esa trayectoria te da intuición sobre qué viene después.
