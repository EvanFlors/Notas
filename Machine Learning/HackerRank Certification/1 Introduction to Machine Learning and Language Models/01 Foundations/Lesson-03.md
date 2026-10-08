# Ciclo de Vida del Modelo (Model Lifecycle)

## ¿Qué es?

El **ciclo de vida del modelo** es la secuencia **disciplinada de etapas** por las que pasa un sistema de ML desde los datos crudos hasta un servicio en producción que se mantiene con el tiempo. No es un proyecto con fecha de cierre: es un **loop continuo** de entrenar, validar, desplegar, monitorear y re-entrenar.

> **Definición operativa:** un modelo tiene un *ciclo de vida* saludable cuando puedes responder, para cualquier predicción servida en producción, estas tres preguntas: ¿qué datos lo entrenaron?, ¿qué código lo generó?, ¿cómo se comporta hoy vs. ayer?

El error cultural más común es tratar al modelo como un *entregable* (como un reporte de Jupyter) en vez de un *servicio* que vive, decae y debe mantenerse. Un modelo con 95% accuracy en el notebook puede desplomarse a 60% tres meses después si no hay disciplina de ciclo de vida.

### Las fases del ciclo

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Recolección → EDA → Features → Split → Train → Validate →      │
│                                                        ↓        │
│         ┌─────── Monitor ← Serve ← Deploy ← Test ◄────┘        │
│         ↓                                                       │
│      Retrain (schedule o trigger)  →  nuevo ciclo               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ¿Por qué importa?

Un modelo que **no sobrevive el paso a producción** no genera valor, por bueno que sea su `R²`. Las fallas típicas son:

- **Preprocessing leakage:** el `StandardScaler` se ajustó con datos del test, inflando artificialmente la métrica.
- **Distribution shift silencioso:** la data drift hace que un modelo "preciso" degrade mes a mes sin que nadie se entere.
- **Imposibilidad de rollback:** no se versionó qué dataset entrenó el modelo que hoy sirve → debuggear un incidente requiere arqueología digital.
- **Métrica desalineada con negocio:** maximizar F1 cuando el costo real está en falsos negativos de 100× el de falsos positivos.

El ciclo de vida importa porque **transforma ML de un arte artesanal a una disciplina de ingeniería**: reproducible, auditable, operacional. Esta disciplina se conoce como **MLOps** (y para LLMs, **LLMOps**).

### Analogía: pasta cocinada

- **Underfitting:** pasta cruda. El modelo no absorbió los patrones.
- **Overfitting:** pasta sobrecocida. Memoriza ruido, se vuelve rígido e inútil fuera del plato específico.
- **Sweet spot:** al dente. Captura la señal, generaliza, y mantiene estabilidad.

## ¿Cómo funciona?

### 1. Diseño de splits: train / validation / test

Dividir los datos correctamente es la **decisión de producto más subestimada** en ML. Es análogo a preparar un examen: *training* = estudiar, *validation* = exámenes de práctica, *test* = examen final.

| Split | Tamaño típico | Propósito | Cuándo lo "ve" el modelo |
|---|---|---|---|
| **Training** | 60-70% | Ajusta parámetros (`θ`) | En cada paso de gradient descent |
| **Validation** | 15-20% | Tunea hiperparámetros, elige arquitectura, early stopping | Entre épocas, para decisiones |
| **Test** | 15-20% | Estimación honesta del desempeño futuro | **Una sola vez**, al final |

![Visualización del split de datos](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson03-train-val-test-split.svg)

> **Regla de oro:** el test set es sagrado. Si lo tocas más de una vez para tomar decisiones, ya no es un test set — se convirtió en otro validation. Esto se llama *test set contamination* y es la fuente #1 de modelos que fallan en producción.

#### Elegir la estrategia de split

El split **debe reflejar cómo se usará el modelo en producción**:

| Estrategia | Cuándo usar | Qué prevenir |
|---|---|---|
| **Random + stratified** | Datos i.i.d. sin dependencia temporal ni identidad; mantener proporción de clases | Clases minoritarias ausentes en un split |
| **Time-based** | Datos con componente temporal (forecast, churn, fraude) | Ver el futuro al predecir el pasado |
| **Group-aware (GroupKFold)** | La misma entidad se repite (usuario, paciente, dispositivo) | *Identity leakage*: mismo usuario en train y test |
| **Stratified group** | Combinas grupos con desbalance de clases | Ambos problemas simultáneos |
| **TimeSeriesSplit** | Backtesting con ventana expansiva o deslizante | Overfit a un periodo específico |

```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GroupKFold, TimeSeriesSplit

# Dataset simulado con usuarios y timestamps
np.random.seed(42)
n = 1000
df = pd.DataFrame({
    "user_id":   np.random.randint(1, 100, n),
    "timestamp": pd.date_range("2023-01-01", periods=n, freq="H"),
    "feature1":  np.random.randn(n),
    "feature2":  np.random.randn(n),
    "target":    np.random.randint(0, 2, n),
})

# 1) Random stratified: datos sin tiempo ni identidad
train, test = train_test_split(df, test_size=0.2, stratify=df["target"], random_state=42)

# 2) Time-based: respetar la flecha del tiempo
df = df.sort_values("timestamp")
cut = df["timestamp"].quantile(0.8)
train_t = df[df["timestamp"] <  cut]
test_t  = df[df["timestamp"] >= cut]
assert train_t["timestamp"].max() < test_t["timestamp"].min()

# 3) Group-aware: ningún usuario cruza entre train y test
gkf = GroupKFold(n_splits=5)
for fold, (tr_idx, te_idx) in enumerate(gkf.split(df, df["target"], groups=df["user_id"])):
    tr_users = set(df.iloc[tr_idx]["user_id"])
    te_users = set(df.iloc[te_idx]["user_id"])
    assert len(tr_users & te_users) == 0, "¡Fuga de usuarios!"
    print(f"Fold {fold}: train={len(tr_idx)} test={len(te_idx)}")

# 4) Series de tiempo con ventanas crecientes
tss = TimeSeriesSplit(n_splits=5)
for fold, (tr, te) in enumerate(tss.split(df)):
    print(f"Fold {fold}: train[0..{tr[-1]}]  test[{te[0]}..{te[-1]}]")
```

### 2. Pipelines reproducibles: fit solo en training

En producción, el preprocesamiento debe ser **idéntico** al de entrenamiento. La forma segura es empaquetar preprocesamiento + modelo en un **único pipeline** y serializarlo como una unidad.

> **Preprocessing leakage:** ajustar un `StandardScaler`, `TfidfVectorizer` o `OneHotEncoder` sobre todos los datos *antes* del split. El modelo "ve" estadísticas del test (media, varianza, vocabulario) y la métrica se infla.

```python
# ❌ MAL: fit sobre todos los datos → leakage
from sklearn.preprocessing import StandardScaler
scaler = StandardScaler().fit(all_data)
X_train = scaler.transform(train_data)
X_test  = scaler.transform(test_data)   # test contaminó al scaler

# ✅ BIEN: fit solo en train, aplica a test / producción
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.ensemble import GradientBoostingClassifier

pre = ColumnTransformer([
    ("num", StandardScaler(),                 ["spending", "visits"]),
    ("cat", OneHotEncoder(handle_unknown="ignore"), ["plan", "region"]),
])

pipe = Pipeline([
    ("pre", pre),
    ("clf", GradientBoostingClassifier(random_state=42)),
])
pipe.fit(X_train, y_train)
# Guardar la unidad completa:
import joblib
joblib.dump(pipe, "churn_v1.3.joblib")
```

### 3. Overfitting vs. underfitting

![Overfitting vs underfitting](https://hrcdn.net/ai-engineering/module-1/light/1.1.3_underfitting_overfitting.svg)

| Diagnóstico | Train error | Val error | Causa | Qué hacer |
|---|---|---|---|---|
| **Underfit (alto bias)** | Alto | Alto | Modelo demasiado simple o pocas features | Más capacidad, mejores features, menos regularización |
| **Overfit (alta varianza)** | Bajo | Alto | Modelo memoriza ruido | Regularizar, más datos, dropout, early stopping |
| **Sweet spot** | Bajo | Bajo (similar) | Captura la señal, generaliza | Nada, lanza a producción |
| **Datos pobres** | Alto en ambos pero train > val | — | Dataset tiene mucho ruido o labels malos | Mejorar labels, limpiar datos |

**Descomposición formal:**

```
Error_total = Bias² + Varianza + Ruido_irreducible
```

- **Bias:** error por supuestos simplificadores del modelo.
- **Varianza:** sensibilidad a fluctuaciones del dataset de entrenamiento.
- **Ruido irreducible:** aleatoriedad intrínseca del fenómeno.

#### Learning curves: la herramienta de diagnóstico #1

```python
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import learning_curve
from sklearn.ensemble import RandomForestClassifier

sizes, train_s, val_s = learning_curve(
    RandomForestClassifier(n_estimators=100, random_state=42),
    X, y,
    train_sizes=np.linspace(0.1, 1.0, 10),
    cv=5, scoring="f1_macro", n_jobs=-1,
)

plt.plot(sizes, train_s.mean(axis=1), label="train")
plt.plot(sizes, val_s.mean(axis=1),   label="validation")
plt.fill_between(sizes, val_s.mean(axis=1)-val_s.std(axis=1),
                        val_s.mean(axis=1)+val_s.std(axis=1), alpha=0.2)
plt.xlabel("tamaño del training set")
plt.ylabel("F1 macro")
plt.legend(); plt.title("Learning Curve")
```

- Si ambas curvas convergen alto → underfit.
- Si gap grande que no cierra con más datos → overfit.
- Si gap que *sí* cierra con más datos → recolectar más es la mejor inversión.

### 4. Versionado: datos + código + modelo

En desarrollo de software versionas tu código. En ML debes versionar **tres capas**, porque todas evolucionan constantemente:

| Capa | Qué incluye | Herramientas |
|---|---|---|
| **Datos** | Datasets crudos, limpios, features engineereadas, splits exactos | DVC, LakeFS, Delta Lake, Pachyderm |
| **Código** | Git SHA, versión de librerías, hiperparámetros, random seeds, umbral de decisión | Git + `requirements.txt` / `poetry.lock`, Hydra |
| **Modelo** | Pesos, métricas, metadata del training run | MLflow, Weights & Biases, Neptune, Vertex AI Model Registry |

**Convenciones de naming útiles:**

```
customer_data_v2.1_2024_03_15.parquet
fraud_detection_v1.3_acc_0.94_f1_0.87_2024_03_15.joblib
```

> **Netflix:** versiona sus modelos de recomendación continuamente. Cuando el comportamiento cambió durante la pandemia, pudieron rollback rápido a versiones previas y re-entrenar manteniendo trazabilidad total de qué cambió y por qué.

### 5. Fases de despliegue

| Fase | Objetivo | Riesgo que mitiga |
|---|---|---|
| **Development** | EDA, feature engineering, iteración rápida | Decidir si el problema es siquiera resoluble |
| **Staging** | Probar con volumen y latencia productivos | Descubrir que tu XGBoost tarda 10s por predicción |
| **Shadow deployment** | Correr nuevo modelo en paralelo sin servir sus respuestas | Comparar vs. baseline sin impactar usuarios |
| **Canary (1-5%)** | Servir a una fracción pequeña de tráfico | Detectar bugs antes del rollout masivo |
| **Full rollout** | 100% del tráfico | — |
| **Rollback plan** | Volver al modelo anterior en minutos | Incidentes en producción |

### 6. Monitoreo continuo

Un modelo en producción debe medir constantemente:

| Dimensión | Qué monitorear | Ejemplo de alerta |
|---|---|---|
| **Sistema** | Latencia p50/p95/p99, errores HTTP, uso de CPU/GPU | p95 > 300ms |
| **Datos de entrada** | Input drift (KS test, PSI) | PSI > 0.25 en una feature clave |
| **Predicciones** | Output drift (distribución de scores) | Media de scores cambia >3σ |
| **Desempeño (cuando llegan labels)** | Precision/recall/F1 vs. baseline | F1 cae >5% semana a semana |
| **Negocio** | Conversión, revenue, satisfacción | Conversión del grupo tratado < control |

Herramientas: Evidently AI, WhyLabs, Arize, Fiddler, Datadog ML Monitoring.

### 7. Estrategia de re-entrenamiento

| Trigger | Cuándo | Ejemplo |
|---|---|---|
| **Scheduled** | Cada N días/semanas | Weekly retrain de modelos de churn |
| **Drift-based** | Cuando PSI o KL supera umbral | Reentrenar si drift > 0.25 |
| **Performance-based** | Cuando F1 cae X% | Reentrenar si F1 cae >5% |
| **Volume-based** | Cuando llega N nuevo data | Reentrenar cada 100K nuevos ejemplos |
| **Schema change** | Nueva feature o cambio de upstream | Reentrenar + validar pipeline |

Cada retrain es **una nueva versión** con su propia evaluación y plan de rollback. Automatiza esto con Airflow, Prefect, Kubeflow Pipelines o Vertex AI Pipelines.

## Errores comunes

- **Data leakage temporal.** Incluir `account_closed_date` como feature para predecir churn: obviamente los que churned tienen esa fecha. En producción no la tendrás y el modelo se desploma. Siempre audita el **timeline de disponibilidad** de cada feature.
- **Target leakage.** Usar `default_flag` para predecir default de crédito: circular. El modelo "aprende" algo que es consecuencia directa del target.
- **Preprocessing leakage.** Ajustar scaler/encoder sobre todo el dataset antes del split. Usa `Pipeline` + `fit` solo en train.
- **Split aleatorio para series de tiempo.** Entrenar con datos de diciembre y testear con enero funciona en el notebook, pero en producción debes predecir febrero con info solo hasta enero. Usa **time-based split**.
- **Identity leakage.** Mismo usuario/paciente en train y test. El modelo "memoriza" la identidad en vez de aprender patrones. Usa `GroupKFold`.
- **Celebrar accuracy sin ver la matriz de confusión.** 99% accuracy con 1% de clase positiva = modelo que predice "no" siempre. Siempre revisa precision/recall por clase.
- **No versionar el dataset de entrenamiento.** 6 meses después alguien pregunta "¿cómo entrenamos este modelo?" y el CSV fue sobreescrito. DVC lo resuelve.
- **No fijar random seeds.** Resultados no reproducibles → debuggear bugs se vuelve brujería. `random.seed(42)`, `np.random.seed(42)`, `torch.manual_seed(42)`.
- **Modelo bellísimo pero inviable en latencia.** XGBoost con 2000 árboles da +0.3% F1 pero tarda 500ms. En hot path de ads/search es inviable. Mide latencia desde el día 1.
- **Olvidar el feedback loop perverso.** Un recomendador que solo recomienda lo popular refuerza su propio sesgo: los nuevos ítems nunca se exponen. Mitiga con exploración.
- **No tener plan de rollback.** El modelo nuevo degrada producción un sábado a las 2am. ¿Cómo vuelves al anterior en 5 minutos? Si no sabes la respuesta, no estás listo para producción.
- **Confundir "modelo entrenado" con "sistema desplegado".** El 90% del trabajo real está en pipelines, monitoreo, retraining y governance — no en el `.fit()`.
- **Scale mismatch.** El modelo funciona con CSVs limpios en el laptop pero falla con streaming real que tiene nulos, formatos variables y volumen 100× mayor. Testea con **production-scale data** desde staging.
- **Ignorar fairness por grupo.** El modelo promedia bien pero discrimina sistemáticamente a un grupo. Audita por género, raza, edad, geografía (fairlearn, AIF360).

### Herramientas industriales por fase

| Fase | Herramientas típicas |
|---|---|
| Versionado de datos | DVC, LakeFS, Delta Lake, Pachyderm |
| Experiment tracking | MLflow, Weights & Biases, Neptune, Comet |
| Orquestación | Airflow, Prefect, Dagster, Kubeflow Pipelines |
| Feature stores | Feast, Tecton, Hopsworks, Vertex AI Feature Store |
| Model serving | TorchServe, Triton, BentoML, Seldon, KServe, SageMaker |
| Monitoreo | Evidently, WhyLabs, Arize, Fiddler, Datadog ML |
| Governance | ModelDB, MLflow Model Registry, Vertex Model Registry |

## Resumen

- El ciclo de vida del modelo es un **loop continuo**, no un proyecto con fecha de cierre. Un modelo en producción es un servicio que vive, decae y se mantiene.
- Diseñar los **splits** es una decisión de producto: deben **espejar la realidad de producción** (tiempo, identidad, desbalance).
- El **test set es sagrado**: una sola mirada al final. Tocarlo repetidamente lo contamina.
- **Pipeline reproducible:** fit del preprocesamiento solo en train, serializa pre + modelo como una unidad. Previene preprocessing leakage.
- **Overfitting vs underfitting** se diagnostica con el gap train/validation y learning curves. La respuesta no siempre es "más capacidad": a veces es más datos, mejores features o más regularización.
- **Versiona tres capas**: datos (DVC), código (Git), modelos (MLflow). Debes poder responder: "¿qué modelo, entrenado con qué datos, tomó esta decisión?"
- **Despliegue seguro:** staging → shadow → canary → full rollout. Siempre con plan de rollback de minutos.
- **Monitoreo multidimensional:** sistema (latencia), datos (drift), predicciones (output drift), negocio (métricas de impacto).
- **Re-entrenamiento disciplinado:** por schedule, drift, performance o volumen. Cada retrain es una nueva versión con evaluación propia.
- **MLOps** es la disciplina que hace sostenible todo lo anterior. Sin ella, cada modelo nuevo es un prototipo frágil.
- El fallo más caro no es un modelo que no funciona en el notebook — es uno que *parece* funcionar y degrada silenciosamente en producción.
