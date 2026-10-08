# Fundamentos de Evaluación de Modelos

## ¿Qué es?

La **evaluación de modelos** es el conjunto de métricas, pruebas y procedimientos que **cuantifican qué tan bien un modelo cumple su propósito**. No es un número único: es un *lenguaje* para comunicar desempeño, trade-offs y riesgos a stakeholders técnicos y de negocio.

Un modelo sin evaluación rigurosa es, literalmente, **volar a ciegas**: puedes desplegar algo que degrade la experiencia, pierda revenue o cause daño antes de que alguien lo note.

> **Definición operativa:** evaluar un modelo es responder, con evidencia reproducible, tres preguntas: ¿acierta?, ¿cuándo falla?, ¿cuánto cuesta cada tipo de error?

### Dos grandes familias de métricas

| Tipo de problema | Salida | Métricas base |
|---|---|---|
| **Clasificación** | Categoría discreta | Accuracy, Precision, Recall, F1, AUC-ROC, AUC-PR |
| **Regresión** | Valor continuo | MAE, MSE, RMSE, R², MAPE |
| **Ranking** | Orden relativo | NDCG, MAP, MRR, Hit@K |
| **Generación (NLP)** | Texto libre | BLEU, ROUGE, perplejidad, LLM-as-judge, eval humana |

Esta lección se enfoca en **clasificación y regresión**, los dos pilares del ML supervisado tradicional.

## ¿Por qué importa?

Elegir **la métrica correcta** suele ser más importante que elegir el algoritmo. Un modelo optimizado para accuracy en un dataset desbalanceado puede ser peor que una regla trivial. Un modelo con RMSE bajo puede ser inservible si lo que importa es minimizar los errores catastróficos.

Casos reales donde la métrica equivocada causó daño:

- **Content moderation:** optimizar F1 global dejó pasar demasiado contenido dañino porque el equipo no priorizó recall en la clase crítica.
- **Fraud detection:** 99.9% accuracy "exitoso" cuando el fraude es 0.1% — el modelo nunca lo detectaba.
- **Diagnóstico médico:** un modelo con alto precision pero bajo recall diagnostica correctamente lo que marca, pero **omite** la mayoría de los casos reales de la enfermedad.
- **Recomendadores:** optimizar CTR produce clickbait y erosiona la retención de largo plazo (Goodhart's Law).

> **Regla de ingeniería:** la mejor métrica es la que **refleja el costo real de equivocarse** en tu dominio. Si cada tipo de error tiene un costo distinto, tu métrica debe reflejar esa asimetría.

## ¿Cómo funciona?

### Verdad vs. predicción: los cuatro resultados posibles

Toda clasificación binaria produce cuatro resultados al comparar la predicción con la verdad:

| | Predicho: Positivo | Predicho: Negativo |
|---|---|---|
| **Real: Positivo** | TP (True Positive) | FN (False Negative) — *Error Tipo II* |
| **Real: Negativo** | FP (False Positive) — *Error Tipo I* | TN (True Negative) |

![Matriz de confusión](https://hrcdn.net/ai-engineering/module-1/light/foundations-lesson04-confusion-matrix.svg)

En el ejemplo de tickets de soporte, prediciendo "urgente":

- **TP:** el modelo dice "urgente" y realmente lo es.
- **TN:** el modelo dice "normal" y realmente lo es.
- **FP:** el modelo dice "urgente" pero era normal → **falsa alarma**, desperdicio de atención del equipo.
- **FN:** el modelo dice "normal" pero era urgente → **asunto crítico omitido**, cliente molesto.

### La matriz de confusión

Es la herramienta base para clasificación. Para el ejemplo de tickets:

| Real \ Predicho | Normal | Urgente | Total |
|---|---:|---:|---:|
| **Normal** | 950 (TN) | 50 (FP) | 1000 |
| **Urgente** | 30 (FN) | 220 (TP) | 250 |
| **Total** | 980 | 270 | 1250 |

Las **filas son la realidad**, las **columnas la predicción**. De aquí se derivan todas las métricas de clasificación.

### Métricas de clasificación

#### Accuracy

```
Accuracy = (TP + TN) / Total = (950 + 220) / 1250 = 0.936  → 93.6%
```

Intuitiva, pero **engañosa con clases desbalanceadas**. Si 99% de los tickets fueran normales, un modelo que siempre predice "normal" tiene 99% accuracy y es inútil.

> **Cuándo usar accuracy:** clases balanceadas y todos los errores cuestan lo mismo. En producción real esto es raro.

#### Precision

Responde: *"Cuando el modelo dice positivo, ¿cuántas veces acierta?"*

```
Precision = TP / (TP + FP) = 220 / (220 + 50) = 0.815  → 81.5%
```

Alta precision importa cuando **los falsos positivos son caros**:

- Fraude: bloquear transacciones legítimas pierde revenue y clientes.
- Email marketing: enviar a quien no quiere → spam complaints, dominio penalizado.
- Diagnóstico: biopsia innecesaria tiene costo monetario y psicológico.

#### Recall (Sensibilidad)

Responde: *"De todos los casos realmente positivos, ¿cuántos capturé?"*

```
Recall = TP / (TP + FN) = 220 / (220 + 30) = 0.88  → 88%
```

Alto recall importa cuando **los falsos negativos son catastróficos**:

- Diagnóstico de cáncer: omitir un caso cuesta vidas.
- Seguridad: no detectar una amenaza real.
- Fraude en préstamos de alto monto.

#### F1-Score: media armónica

```
F1 = 2 · (Precision · Recall) / (Precision + Recall) = 2·(0.815·0.88)/(0.815+0.88) = 0.846
```

La **media armónica** es estricta: si cualquiera de precision o recall es baja, F1 cae fuerte. Útil cuando quieres ambas razonablemente altas y las clases están desbalanceadas.

Variantes: **F0.5** (pondera más precision), **F2** (pondera más recall), **F-beta** general.

#### El trade-off precision ↔ recall

Al mover el **umbral de decisión** (threshold), inviertes una por la otra:

| Umbral | Efecto |
|---|---|
| Alto (ej. 0.9) | Pocos positivos predichos → Precision ↑, Recall ↓ |
| Bajo (ej. 0.3) | Muchos positivos predichos → Recall ↑, Precision ↓ |

La curva **Precision-Recall** y la curva **ROC** visualizan este trade-off en todos los umbrales.

#### AUC-ROC y AUC-PR

| Métrica | Qué mide | Cuándo usar |
|---|---|---|
| **AUC-ROC** | Área bajo curva TPR vs FPR | Clases balanceadas; rankeo general |
| **AUC-PR** | Área bajo curva Precision vs Recall | Clases **muy** desbalanceadas (preferida en fraude, enfermedades raras) |

> **Regla práctica:** si la clase positiva es <10% del dataset, **AUC-PR es más honesta que AUC-ROC**. ROC puede verse espectacular aun cuando el modelo es inútil para la clase minoritaria.

#### Métricas multi-clase

| Promedio | Fórmula conceptual | Cuándo usar |
|---|---|---|
| **Macro** | Promedio simple por clase | Todas las clases importan igual |
| **Micro** | Agrega TP/FP/FN globalmente | Clases ponderadas por frecuencia |
| **Weighted** | Promedio ponderado por soporte | Compromiso entre macro y micro |

### Métricas de regresión

Para predicciones continuas (precio, demanda, temperatura), no hay "correcto/incorrecto": solo **grados de error**.

#### Mean Absolute Error (MAE)

```
MAE = (1/n) · Σ |y_real - y_pred|
```

Ejemplo: predices $320K para una casa de $300K, y $280K para una de $290K → MAE = (20K + 10K) / 2 = **$15K**.

- Interpretable: "en promedio me equivoco por $15K".
- Robusto a outliers: cada error pesa linealmente.

#### Mean Squared Error (MSE)

```
MSE = (1/n) · Σ (y_real - y_pred)²
```

Mismo ejemplo: MSE = (20K² + 10K²) / 2 = **250K²**.

- Penaliza **cuadráticamente** errores grandes: un error de $40K pesa 16× más que uno de $10K.
- Útil cuando errores grandes son desproporcionadamente malos.
- Problema: unidades son "dólares²", no interpretables.

#### Root Mean Squared Error (RMSE)

```
RMSE = √MSE  →  √250K² ≈ $22.4K
```

Vuelve a las unidades originales manteniendo la penalización cuadrática. Es el default en muchos benchmarks de regresión.

#### R² (coeficiente de determinación)

```
R² = 1 - (SS_res / SS_tot)
```

Mide qué fracción de la varianza explica el modelo. `R² = 1` perfecto, `R² = 0` igual a predecir la media, `R² < 0` peor que la media (modelo roto).

#### MAPE (Mean Absolute Percentage Error)

```
MAPE = (100/n) · Σ |y_real - y_pred| / |y_real|
```

Error en porcentaje. Útil para reportar a negocio ("el modelo se equivoca en ~8%"), pero **colapsa cuando `y_real` tiene valores cercanos a cero**.

### Tabla comparativa de métricas

| Métrica | Rango | Unidades | Robusta a outliers | Interpretable | Cuándo usar |
|---|---|---|---|---|---|
| Accuracy | 0-1 | — | — | Alta | Clases balanceadas |
| Precision | 0-1 | — | — | Alta | FP caros |
| Recall | 0-1 | — | — | Alta | FN caros |
| F1 | 0-1 | — | — | Media | Balance con desbalance |
| AUC-ROC | 0-1 | — | — | Media | Rankeo, clases balanceadas |
| AUC-PR | 0-1 | — | — | Media | Clases muy desbalanceadas |
| MAE | ≥0 | Target | Sí | Alta | Error promedio interpretable |
| RMSE | ≥0 | Target | No | Alta | Penalizar errores grandes |
| MSE | ≥0 | Target² | No | Baja | Optimización (gradientes suaves) |
| R² | ≤1 | — | No | Media | % de varianza explicada |
| MAPE | ≥0 | % | No (falla con y≈0) | Alta | Reportes a negocio |

## Ejemplo con código

```python
# ============================================================
# Evaluación completa: clasificación y regresión
# ============================================================
import numpy as np
from sklearn.datasets import make_classification, make_regression
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import (
    confusion_matrix, classification_report,
    precision_score, recall_score, f1_score, accuracy_score,
    roc_auc_score, average_precision_score,
    mean_absolute_error, mean_squared_error, r2_score,
    precision_recall_curve, roc_curve,
)

# ----------------------------------------------------------------
# 1) CLASIFICACIÓN con desbalance 95/5 (parecido a fraude)
# ----------------------------------------------------------------
X, y = make_classification(
    n_samples=10000, n_features=20, weights=[0.95, 0.05],
    random_state=42,
)
Xtr, Xte, ytr, yte = train_test_split(X, y, stratify=y, test_size=0.3, random_state=42)

clf = RandomForestClassifier(class_weight="balanced", random_state=42).fit(Xtr, ytr)
proba = clf.predict_proba(Xte)[:, 1]
pred  = (proba >= 0.5).astype(int)

print("Matriz de confusión:")
print(confusion_matrix(yte, pred))
print(f"Accuracy : {accuracy_score(yte, pred):.3f}")
print(f"Precision: {precision_score(yte, pred):.3f}")
print(f"Recall   : {recall_score(yte, pred):.3f}")
print(f"F1       : {f1_score(yte, pred):.3f}")
print(f"AUC-ROC  : {roc_auc_score(yte, proba):.3f}")
print(f"AUC-PR   : {average_precision_score(yte, proba):.3f}  <-- preferida en desbalance")
print()
print(classification_report(yte, pred, digits=3))

# ----------------------------------------------------------------
# 2) Elegir el umbral óptimo según costo del negocio
#    Supón: FN cuesta $100, FP cuesta $5
# ----------------------------------------------------------------
costo_fn, costo_fp = 100, 5
best_t, best_cost = 0.5, float("inf")
for t in np.linspace(0.05, 0.95, 19):
    p = (proba >= t).astype(int)
    tn, fp, fn, tp = confusion_matrix(yte, p).ravel()
    cost = fn * costo_fn + fp * costo_fp
    if cost < best_cost:
        best_cost, best_t = cost, t
print(f"\nUmbral óptimo por costo: {best_t:.2f}  (costo total: ${best_cost})")

# ----------------------------------------------------------------
# 3) REGRESIÓN
# ----------------------------------------------------------------
Xr, yr = make_regression(n_samples=2000, n_features=10, noise=15, random_state=42)
Xtr, Xte, ytr, yte = train_test_split(Xr, yr, test_size=0.3, random_state=42)

reg = RandomForestRegressor(random_state=42).fit(Xtr, ytr)
yp  = reg.predict(Xte)

mae  = mean_absolute_error(yte, yp)
mse  = mean_squared_error(yte, yp)
rmse = np.sqrt(mse)
r2   = r2_score(yte, yp)
print(f"\nMAE : {mae:.2f}")
print(f"RMSE: {rmse:.2f}  (penaliza errores grandes)")
print(f"R²  : {r2:.3f}")
```

### Visualizando curvas y matriz de confusión

```python
import matplotlib.pyplot as plt

fig, axes = plt.subplots(1, 3, figsize=(16, 4))

# Confusion matrix como heatmap
from sklearn.metrics import ConfusionMatrixDisplay
ConfusionMatrixDisplay(confusion_matrix(yte, pred)).plot(ax=axes[0], colorbar=False)
axes[0].set_title("Confusion Matrix")

# ROC
fpr, tpr, _ = roc_curve(yte, proba)
axes[1].plot(fpr, tpr); axes[1].plot([0,1],[0,1],"k--")
axes[1].set_title(f"ROC (AUC={roc_auc_score(yte, proba):.3f})")
axes[1].set_xlabel("FPR"); axes[1].set_ylabel("TPR")

# Precision-Recall
prec, rec, _ = precision_recall_curve(yte, proba)
axes[2].plot(rec, prec)
axes[2].set_title(f"PR (AP={average_precision_score(yte, proba):.3f})")
axes[2].set_xlabel("Recall"); axes[2].set_ylabel("Precision")
plt.tight_layout()
```

### Elegir la métrica según el caso

| Dominio | Costo asimétrico | Métrica primaria | Métrica secundaria |
|---|---|---|---|
| Fraude en pagos | FP: fricción al cliente; FN: pérdida de dinero | AUC-PR | Recall @ precision fija |
| Diagnóstico médico | FN: muertes; FP: biopsias | Recall (sensibilidad) | Specificity |
| Spam filter | FP: email importante perdido; FN: spam en inbox | Precision | Recall |
| Content moderation | FN: contenido dañino; FP: censura excesiva | Recall en clase crítica | Precision |
| Precio de casa | — | RMSE | MAE para reportar |
| Demanda retail | Sobre-stock > sub-stock (o viceversa) | Pérdida asimétrica custom | MAPE |
| LLMs | Alucinación, utilidad | LLM-as-judge, eval humana | ROUGE / BLEU como proxy |

## Errores comunes

- **Confiar en accuracy con clases desbalanceadas.** 99.9% accuracy en fraude = modelo que nunca detecta fraude. Siempre revisa matriz de confusión por clase.
- **Reportar una sola métrica.** F1 oculta si el problema es precision o recall. Reporta ambas + matriz de confusión + curva PR.
- **Optimizar la métrica equivocada por conveniencia estadística.** Elegir F1 porque "balancea", cuando el negocio claramente penaliza más los FN. Define costos reales de FP y FN antes de elegir métrica.
- **Umbral default 0.5 sin justificación.** El umbral debe elegirse en el **validation set** según costo del negocio, no asumir 0.5. Puede ser 0.3 o 0.8 según el caso.
- **Evaluar en test set con distribución distinta a producción.** Entrenaste con 20% positivos, pero en producción es 5%. Las métricas no transfieren. Usa test set representativo o calcula métricas "normalizadas" por prevalencia.
- **Confundir AUC alta con "modelo bueno" en desbalance severo.** AUC-ROC infla con clase mayoritaria. En desbalance usa **AUC-PR**.
- **Ignorar el intervalo de confianza.** Reportar F1 = 0.84 sin decir "±0.03" oculta que el modelo puede ser peor que el baseline con significancia estadística. Usa bootstrap.
- **Comparar modelos en splits distintos.** No es válido. Fija semilla + splits + hiperparámetros antes de comparar.
- **RMSE sin contexto.** RMSE = 15 significa nada sin saber el rango de la variable. ¿Es RMSE/mean = 1%? ¿50%?
- **MAPE con valores cercanos a cero.** Dividir por `y ≈ 0` explota la métrica. Usa SMAPE o MAE en esos casos.
- **No monitorear métricas en producción.** Las métricas de offline evaluation no reflejan drift. Monitorea métricas vivas con dashboards (Evidently, Arize).
- **Ignorar sesgo por subgrupo.** Métrica global = 90% F1, pero para el 15% de usuarios de un grupo demográfico = 50%. Audita por grupos (fairlearn, slicing analysis).
- **Goodhart's Law:** cuando una métrica se vuelve objetivo, deja de ser buena métrica. CTR → clickbait. Watch time → contenido adictivo. Siempre incluye métricas contra-equilibrantes de calidad.
- **No validar el baseline simple.** Si tu modelo profundo con 10M parámetros da F1=0.82 y "siempre predecir la mayoría" da 0.80, no estás ganando casi nada. Baseline primero, siempre.

### Herramientas industriales

| Función | Herramientas |
|---|---|
| Métricas estándar | scikit-learn, torchmetrics, Keras `metrics` |
| Visualización de evaluación | Yellowbrick, scikit-plot, matplotlib |
| Fairness / slicing | Fairlearn, Aequitas, AIF360, SliceLine |
| Monitoreo en producción | Evidently AI, WhyLabs, Arize, Fiddler |
| Experiment tracking de métricas | MLflow, Weights & Biases, Neptune, Comet |
| Eval de LLMs | LangSmith, Promptfoo, OpenAI Evals, DeepEval, Ragas |

## Resumen

- Evaluación no es un número único: es un **lenguaje** para comunicar desempeño y trade-offs. Reporta siempre matriz de confusión + varias métricas.
- Para **clasificación**: parte de la matriz de confusión. Elige entre precision, recall, F1 según el **costo real de cada tipo de error**.
- **Accuracy miente con clases desbalanceadas.** Usa AUC-PR, precision/recall por clase, o métricas ponderadas.
- **F1** balancea precision y recall con media armónica; variantes F0.5/F2 ajustan el peso relativo.
- Para **regresión**: MAE es interpretable y robusto; RMSE penaliza errores grandes; R² mide % de varianza explicada; MAPE funciona para reportes salvo con `y ≈ 0`.
- El **umbral de decisión** se optimiza en validation según costo del negocio, no se asume 0.5.
- La métrica correcta refleja **qué duele realmente** cuando fallas: FP vs FN, errores grandes vs chicos, grupos sensibles.
- **Audita por subgrupo**: una métrica global que luce bien puede esconder discriminación sistemática.
- **Monitorea en producción**: las métricas de offline no reflejan drift. Sin monitoreo, el modelo degrada sin aviso.
- Cuidado con **Goodhart's Law**: cuando una métrica se vuelve objetivo, deja de ser una buena métrica. Siempre incluye métricas contra-equilibrantes.
- **Baseline simple siempre**: compara contra "predecir la mayoría", regla trivial, o un modelo mínimo. Si no ganas con claridad, no vale la complejidad.
