# Tipos de Machine Learning: Supervisado, No Supervisado y por Refuerzo

## ¿Qué es?

Los **tipos de machine learning** son los **paradigmas fundamentales** que definen *cómo* aprende un modelo a partir de los datos. No todos los problemas de ML son iguales: a veces tienes ejemplos con la respuesta correcta, a veces solo datos crudos sin etiquetas, y a veces tu sistema debe aprender interactuando con un entorno.

Existen tres grandes familias que cubren prácticamente toda aplicación moderna:

| Paradigma | Pregunta que responde | Qué recibe el modelo | Qué produce |
|---|---|---|---|
| **Supervisado** | ¿Qué es esto? | Pares `(x, y)` etiquetados | Mapeo `x → y` |
| **No supervisado** | ¿Cómo se organiza esto? | Solo `x` (sin etiquetas) | Estructura latente (grupos, dimensiones, anomalías) |
| **Por refuerzo (RL)** | ¿Qué debo hacer ahora? | Estado + recompensa | Política de acción `π(a\|s)` |

![Familias de machine learning](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson02-ml-types-comparison.svg)

> **Definición clave:** El paradigma de ML lo determina **el tipo de señal de supervisión** que recibe el modelo, no el algoritmo que uses. Un mismo algoritmo (ej. redes neuronales) puede operar en cualquiera de los tres paradigmas.

### Paradigmas intermedios y modernos

Más allá de las tres familias clásicas, han surgido variantes importantes:

| Paradigma | Idea central | Ejemplo real |
|---|---|---|
| **Semi-supervisado** | Combina pocos datos etiquetados con muchos sin etiquetar | Pseudo-labeling en clasificación médica |
| **Auto-supervisado** | Genera etiquetas automáticamente desde los propios datos | BERT (predicción de palabra enmascarada), SimCLR |
| **Por transferencia** | Reutilizar un modelo pre-entrenado en otra tarea | Fine-tuning de ResNet, LoRA en LLMs |
| **Few-shot / Zero-shot** | Aprender con muy pocos (o cero) ejemplos | GPT-4 clasificando texto sin entrenamiento específico |
| **RLHF (RL from Human Feedback)** | RL donde la recompensa viene de preferencias humanas | Alineamiento de ChatGPT, Claude |

## ¿Por qué importa?

**Elegir el paradigma incorrecto desperdicia meses de trabajo.** Un error común: lanzarse a construir un modelo supervisado cuando no se tiene un proceso confiable para generar etiquetas, o aplicar RL cuando un bandit algorithm resolvería el problema con 100× menos complejidad.

La decisión del paradigma determina:

- **El costo del proyecto:** etiquetar manualmente 100K imágenes cuesta decenas de miles de dólares; clustering es "gratis" pero no te dice qué hacer con los grupos.
- **El time-to-value:** supervisado con labels existentes puede ir a producción en semanas; RL puede tomar meses de ingeniería de recompensa y safety.
- **La capacidad de monitorear:** supervisado tiene métricas claras (accuracy, F1); no supervisado requiere evaluación cualitativa; RL necesita monitoreo de política + reward hacking.
- **El riesgo regulatorio:** modelos auto-supervisados masivos (foundation models) enfrentan escrutinio sobre datos de entrenamiento; RL en producción puede causar daños si la política explora de forma agresiva.

> **Regla práctica de ingeniería:** empieza por el paradigma más simple que resuelva el problema. Supervisado > Semi-supervisado > No supervisado > Bandits > RL completo. Cada escalón añade complejidad operativa y riesgo.

## ¿Cómo funciona?

### Supervised Learning (Aprendizaje Supervisado)

Es el paradigma **más común en producción** porque la mayoría de los sistemas de negocio capturan outcomes de forma natural: sabes si un email fue marcado como spam, si una transacción fue confirmada como fraude, o cuánto tardó realmente una entrega.

En supervisado, alimentas el modelo con entradas y la respuesta correcta, y el modelo aprende el mapeo `f: X → Y`. Una analogía útil es el estudio con flashcards: muestras al modelo muchos pares `(entrada, respuesta)`, y el modelo ajusta sus parámetros internos (`θ`) para que sus predicciones coincidan con las respuestas que diste.

**Formalización:** dado un dataset `D = {(xᵢ, yᵢ)}ⁿᵢ₌₁`, encontramos `θ*` que minimiza una pérdida esperada:

```
θ* = argmin_θ  (1/n) Σᵢ L(f(xᵢ; θ), yᵢ)
```

#### Dos tareas centrales

| Tarea | Salida | Ejemplos | Pérdida típica |
|---|---|---|---|
| **Clasificación** | Categoría discreta | Spam/no-spam, churn/retención, dígitos 0-9 | Cross-entropy |
| **Regresión** | Número continuo | Precio de casa, demanda futura, ETA | MSE, MAE, Huber |

Ambas usan el mismo flujo: dividir datos en `train/val/test`, entrenar en train, tunear en validation, reportar en test una sola vez.

#### Consideraciones de producción

Supervisado funciona cuando puedes obtener **etiquetas de calidad cuando tu sistema las necesita**. En la práctica, las etiquetas:

- Llegan tarde (fraude confirmado semanas después de la transacción → *delayed labels*).
- Son ruidosas (los usuarios mal-etiquetan sentimiento).
- Cambian (la definición de "riesgoso" se actualiza con nuevas políticas → *concept drift*).

Necesitas procesos para re-etiquetar, re-entrenar y re-desplegar, además de guardarraíles como shadow deployments y rollback.

### Unsupervised Learning (Aprendizaje No Supervisado)

Útil cuando **no tienes etiquetas** pero quieres que los datos te revelen algo accionable. En vez de imitar respuestas, el objetivo es **descubrir estructura**: grupos que se comportan similar, dimensiones que resumen la variación, o puntos que lucen anómalos.

#### Familias principales

| Tarea | Objetivo | Algoritmos típicos |
|---|---|---|
| **Clustering** | Agrupar puntos similares | K-Means, DBSCAN, HDBSCAN, Gaussian Mixture |
| **Reducción de dimensionalidad** | Representar datos en menos dimensiones | PCA, t-SNE, UMAP, autoencoders |
| **Detección de anomalías** | Identificar outliers | Isolation Forest, One-Class SVM, autoencoders |
| **Modelos generativos** | Aprender la distribución `p(x)` | VAE, GAN, difusión, LLMs (auto-supervisado) |
| **Reglas de asociación** | Encontrar co-ocurrencias | Apriori, FP-Growth (ej. "market basket") |

#### El desafío del ground truth

La dificultad práctica es que los resultados no supervisados **no vienen con verdad absoluta**. Un cluster matemáticamente limpio puede no mapear a nada que el negocio pueda accionar.

> **Patrón seguro:** "unsupervised to explore, supervised to operate". Usa clustering para proponer segmentos, luego etiqueta una muestra y entrena un clasificador supervisado que reconozca esos segmentos con una métrica ligada al resultado de negocio.

También debes monitorear si los clusters derivan a medida que cambia el comportamiento del usuario: el mismo algoritmo con los mismos hiperparámetros puede producir agrupaciones muy distintas al evolucionar los datos.

### Reinforcement Learning (Aprendizaje por Refuerzo)

RL aplica cuando tu sistema debe **elegir acciones**, observar las consecuencias, y mejorar la política que selecciona acciones para maximizar la **recompensa acumulada**. Después de cada acción recibe una señal (recompensa) que indica qué tan bueno fue el resultado, posiblemente con retraso.

**Analogía:** entrenar a un perro. Cuando hace el truco correcto, le das una golosina; cuando no, nada. Con el tiempo aprende qué comportamientos obtienen más golosinas.

#### Formalización: el MDP

RL se modela como un **Markov Decision Process (MDP)**: la tupla `(S, A, P, R, γ)`.

- `S`: espacio de estados.
- `A`: espacio de acciones.
- `P(s' | s, a)`: probabilidad de transición.
- `R(s, a)`: recompensa.
- `γ ∈ [0,1)`: factor de descuento (prioriza recompensas cercanas).

El objetivo es encontrar una política `π(a|s)` que maximice el **retorno esperado**:

```
π* = argmax_π  E[ Σₜ γᵗ · R(sₜ, aₜ) ]
```

#### Características clave

- **La retroalimentación es experimentada, no dada como ejemplos etiquetados.** Esto hace a RL poderoso (puede descubrir estrategias que nadie codificó) pero caro y delicado.
- **Exploration vs. exploitation:** balancear probar cosas nuevas (exploración) con hacer lo que parece mejor ahora (explotación). Técnicas: ε-greedy, UCB, Thompson sampling.
- **Multi-armed bandits** son la versión simplificada (sin estados, solo acciones) que domina en recomendación y pruebas A/B adaptativas.

#### Consideraciones de seguridad

- **No optimizar la recompensa equivocada:** maximizar watch time puede impulsar métricas de corto plazo pero degradar la confianza del usuario con clickbait (Goodhart's Law).
- **Guardarraíles de exploración:** entrenar online sin límites puede causar caídas abruptas de UX cuando la política explora de forma agresiva.
- **Reward hacking:** el agente encuentra atajos no intencionados (ej. un bot de limpieza que apaga su cámara para no "ver" basura).

### Marco de decisión: ¿cuál usar?

Escribe una oración de la forma **"Predeciremos Y a partir de X para optimizar P"**:

- Si puedes llenar `Y` con un outcome etiquetado → **supervisado**.
- Si `Y` es desconocido y buscas estructura en `X` → **no supervisado**.
- Si `Y` depende de una secuencia de acciones que tomarás → **refuerzo**.

#### Ejemplos reales

| Oración | Paradigma |
|---|---|
| "Predeciremos probabilidad de churn a partir de actividad del usuario para optimizar campañas de retención" | Supervisado (clasificación) |
| "Predeciremos precio de una vivienda a partir de sus atributos para optimizar la tasación" | Supervisado (regresión) |
| "Encontraremos segmentos de clientes a partir de comportamiento de compra para optimizar marketing" | No supervisado (clustering) |
| "Detectaremos transacciones inusuales en logs para optimizar la revisión manual" | No supervisado (anomalías) |
| "Seleccionaremos recomendaciones de contenido a partir de interacciones del usuario para optimizar engagement de largo plazo" | Refuerzo (bandit o RL) |

## Ejemplo con código

### 1. Supervisado: clasificación de urgencia de tickets

```python
# ============================================================
# Supervisado: predecir si un ticket de soporte es urgente
# ============================================================
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Paso 1: datos etiquetados por humanos
texts = [
    "server down in region us-east",
    "can we reschedule tomorrow",
    "payment failed for multiple users",
    "lunch at 1?",
    "critical outage, revenue impact",
    "please update my profile picture",
    "database timeout affecting checkout",
    "team offsite next week",
]
labels = [1, 0, 1, 0, 1, 0, 1, 0]  # 1 = urgente, 0 = no urgente

# Paso 2: pipeline que une preprocesamiento + modelo (crítico para producción)
pipe = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1, 2))),
    ("clf", LogisticRegression(class_weight="balanced", max_iter=1000)),
])

# Paso 3: split estratificado y entrenamiento
X_train, X_test, y_train, y_test = train_test_split(
    texts, labels, test_size=0.25, stratify=labels, random_state=42
)
pipe.fit(X_train, y_train)

# Paso 4: evaluar y predecir
print(classification_report(y_test, pipe.predict(X_test)))

nuevo = ["database error affecting users"]
print(f"Predicción: {'URGENTE' if pipe.predict(nuevo)[0] == 1 else 'normal'}")
```

### 2. No supervisado: clustering + reducción de dimensionalidad

```python
# ============================================================
# No supervisado: segmentar clientes sin etiquetas previas
# ============================================================
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score

# Simular datos de clientes: [edad, gasto_mensual, visitas_app, antigüedad_meses]
rng = np.random.default_rng(42)
jovenes_activos  = rng.normal([25, 50, 30, 6], [3, 10, 5, 2], (100, 4))
adultos_fieles   = rng.normal([45, 200, 15, 36], [5, 30, 3, 6], (100, 4))
seniors_premium  = rng.normal([60, 500, 8, 60], [5, 50, 2, 12], (100, 4))
X = np.vstack([jovenes_activos, adultos_fieles, seniors_premium])

# Normalizar: K-Means es sensible a la escala
X_scaled = StandardScaler().fit_transform(X)

# Elegir k con el "método del codo" + silhouette
for k in [2, 3, 4, 5]:
    km = KMeans(n_clusters=k, n_init="auto", random_state=42).fit(X_scaled)
    score = silhouette_score(X_scaled, km.labels_)
    print(f"k={k} -> silhouette={score:.3f} inercia={km.inertia_:.1f}")

# Entrenar con el mejor k y visualizar en 2D con PCA
best = KMeans(n_clusters=3, n_init="auto", random_state=42).fit(X_scaled)
X_2d = PCA(n_components=2).fit_transform(X_scaled)

print(f"\nAsignaciones (primeras 10): {best.labels_[:10]}")
print(f"Centros en espacio original (desnormalizados):")
print(StandardScaler().fit(X).inverse_transform(best.cluster_centers_))
```

### 3. Refuerzo: multi-armed bandit (ε-greedy)

```python
# ============================================================
# RL simplificado: elegir entre 3 variantes de un banner
# usando ε-greedy (explorar vs explotar)
# ============================================================
import numpy as np

class EpsilonGreedyBandit:
    def __init__(self, n_arms: int, epsilon: float = 0.1):
        self.n_arms = n_arms
        self.epsilon = epsilon
        self.counts = np.zeros(n_arms)         # cuántas veces jalamos cada brazo
        self.values = np.zeros(n_arms)         # recompensa promedio estimada

    def select(self) -> int:
        if np.random.random() < self.epsilon:
            return np.random.randint(self.n_arms)   # explorar
        return int(np.argmax(self.values))          # explotar

    def update(self, arm: int, reward: float):
        self.counts[arm] += 1
        n = self.counts[arm]
        # Actualización incremental del promedio (más estable que recalcular)
        self.values[arm] += (reward - self.values[arm]) / n


# Simulación: 3 banners con CTR real desconocido
ctr_real = [0.02, 0.05, 0.03]   # el banner 1 (índice 1) es el mejor
bandit = EpsilonGreedyBandit(n_arms=3, epsilon=0.1)

np.random.seed(0)
for t in range(10_000):
    arm = bandit.select()
    reward = 1.0 if np.random.random() < ctr_real[arm] else 0.0
    bandit.update(arm, reward)

print("CTR estimado:", bandit.values.round(4))
print("CTR real:    ", ctr_real)
print("Jalones por brazo:", bandit.counts.astype(int))
```

### Herramientas industriales por paradigma

| Paradigma | Librerías / servicios |
|---|---|
| Supervisado | scikit-learn, XGBoost, LightGBM, PyTorch, TensorFlow, Keras |
| No supervisado | scikit-learn, FAISS, HDBSCAN, UMAP, Annoy, pyod |
| RL | Stable-Baselines3, RLlib (Ray), OpenAI Gym / Gymnasium, Dopamine |
| Bandits | Vowpal Wabbit, Thompson Sampling en PyMC |
| Auto-supervisado / LLMs | Hugging Face Transformers, Sentence-Transformers |

## Errores comunes

- **Elegir supervisado sin un plan de etiquetado sostenible.** Logras un POC con 500 ejemplos etiquetados a mano; en producción necesitas 50K/mes y nadie los etiqueta. El modelo decae silenciosamente.
- **Data leakage temporal en supervisado.** Usar `delivered_at` para predecir `delivery_time` filtra información del futuro. El modelo luce perfecto en test y colapsa en producción porque esa columna no existe al momento de predecir.
- **Label drift silencioso.** Un cambio de política redefine "fraude" pero sigues evaluando contra la definición vieja. Mitigación: versiona el código de generación de labels por versión de modelo y haz *backtesting*.
- **Tratar clusters como verdad.** Un cluster matemáticamente limpio no implica un segmento de negocio accionable. Siempre valida con stakeholders y métricas downstream.
- **No normalizar antes de K-Means.** K-Means usa distancia euclidiana; una feature en el rango [0, 1,000,000] dominará sobre otra en [0, 1]. Siempre `StandardScaler` o `MinMaxScaler`.
- **Elegir `k` arbitrariamente en clustering.** Usa métodos cuantitativos: codo (inercia), silhouette, gap statistic, o métricas de negocio downstream.
- **Confundir detección de anomalías con clasificación.** Si tienes etiquetas de "anómalo vs. normal", usa supervisado (aunque sea desbalanceado); detección no supervisada es solo para cuando no tienes labels.
- **Optimizar la recompensa equivocada en RL.** Maximizar watch time → clickbait. Maximizar clics → títulos sensacionalistas. Define recompensa alineada con valor de largo plazo.
- **Saltar directamente a RL cuando bandits bastarían.** RL completo requiere modelar estado y transición. Si no hay dependencia secuencial clara, un contextual bandit es 10× más simple.
- **No capar la exploración de un RL online.** Un sistema de pricing que explora agresivamente puede cobrar $1 o $10,000 por el mismo producto, destruyendo confianza. Siempre define rangos seguros.
- **Reward hacking:** el agente encuentra atajos. Famoso caso de un barco en CoastRunners (OpenAI) que daba vueltas en círculo coleccionando power-ups en vez de terminar la carrera.
- **Combinar paradigmas sin validar la frontera.** Usar embeddings auto-supervisados como features para supervisado es excelente, pero debes revalidar: el embedding entrenado en Wikipedia puede no servir para texto legal.

### Casos de uso reales por paradigma

| Dominio | Supervisado | No supervisado | RL |
|---|---|---|---|
| E-commerce | Predicción de churn, scoring de leads | Segmentación de clientes | Pricing dinámico, recomendación |
| Finanzas | Fraud detection, credit scoring | Detección de anomalías en transacciones | Trading algorítmico (con restricciones) |
| Salud | Diagnóstico por imagen | Clustering de pacientes con síntomas raros | Dosificación personalizada (experimental) |
| Industria | Mantenimiento predictivo | Detección de fallos en sensores | Control de procesos (robótica) |
| LLMs | Fine-tuning con instrucciones | Pre-entrenamiento (auto-supervisado) | RLHF para alineamiento |

## Resumen

- Los **tres paradigmas** se definen por la señal de supervisión: labels explícitos (supervisado), nada (no supervisado), o recompensa diferida (refuerzo).
- **Supervisado** domina en producción porque las operaciones del negocio generan outcomes naturalmente. Se divide en **clasificación** (categorías) y **regresión** (números continuos).
- **No supervisado** descubre estructura cuando no hay etiquetas: clustering, reducción de dimensionalidad, anomalías, modelos generativos. Patrón recomendado: *explorar con no supervisado, operar con supervisado*.
- **RL** aprende por interacción con un entorno maximizando recompensa acumulada. Es poderoso en entornos dinámicos pero caro, delicado y requiere ingeniería de seguridad.
- Paradigmas modernos relevantes: **auto-supervisado** (BERT, GPT, SimCLR), **transferencia** (fine-tuning, LoRA), **RLHF** (alineamiento de LLMs), **bandits** (versión simple de RL para recomendación).
- Para elegir, escribe: *"Predeciremos Y a partir de X para optimizar P"*. El contenido de `Y` revela el paradigma correcto.
- **Empieza simple:** supervisado > bandits > RL completo. Cada escalón añade coste y riesgo operativo.
- Cada paradigma tiene **errores clásicos**: leakage en supervisado, "clusters como verdad" en no supervisado, reward hacking en RL.
- La **calidad y disponibilidad de labels** es más determinante que el algoritmo. Sin un plan sostenible de etiquetado, el supervisado es insostenible.
