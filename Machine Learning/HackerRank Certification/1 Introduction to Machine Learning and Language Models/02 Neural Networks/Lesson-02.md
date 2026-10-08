# Entrenamiento: Loss, Gradientes, Épocas y Backpropagation

## ¿Qué es?

**Entrenar una red neuronal** es el proceso iterativo de ajustar sus parámetros `θ = {W⁽ˡ⁾, b⁽ˡ⁾}` para que las predicciones `ŷ = f(x; θ)` se parezcan lo más posible a las etiquetas reales `y`. Formalmente, resolvemos un problema de optimización:

```
θ* = argmin_θ  (1/N) Σᵢ L(f(xᵢ; θ), yᵢ)  +  λ·R(θ)
                └──── pérdida empírica ────┘   └ regul. ┘
```

Dado que esta función no es convexa (típicamente millones de dimensiones y mínimos locales), **no se resuelve en forma cerrada**. En su lugar, se usa **descenso del gradiente** combinado con **backpropagation** para calcular los gradientes eficientemente.

Los cinco conceptos clave son:

1. **Función de pérdida (loss)** — mide qué tan malas son las predicciones.
2. **Gradiente** — dirección en el espacio de parámetros en la que la pérdida aumenta más rápido; nos movemos en sentido opuesto.
3. **Learning rate (tasa de aprendizaje)** — tamaño del paso en cada actualización.
4. **Batch / Step / Epoch** — organización de los datos durante el entrenamiento.
5. **Backpropagation** — algoritmo que calcula gradientes en tiempo lineal al número de parámetros usando la regla de la cadena.

## ¿Por qué importa?

Una red con pesos aleatorios es un generador de números sin sentido. El entrenamiento es lo que convierte una arquitectura genérica en un sistema útil capaz de clasificar correos, detectar fraude o traducir idiomas. Entender el proceso te permite:

- **Diagnosticar** por qué un modelo no converge (loss plano, loss NaN, loss oscilante).
- **Elegir hiperparámetros** con criterio (learning rate, batch size, optimizador).
- **Detectar overfitting** antes de desplegar un modelo que falla en producción.
- **Debuggear gradientes** (vanishing / exploding) en redes profundas.
- **Reducir costos** de GPU evitando entrenamientos innecesariamente largos.

El entrenamiento es también el **mayor costo** en deep learning: entrenar GPT-3 costó ~$4.6M en cómputo; GPT-4 se estima en $100M+. Cada truco que acelera la convergencia tiene impacto económico directo.

## ¿Cómo funciona?

### 1. Función de pérdida (loss function)

La pérdida es un número que resume qué tan mal predice el modelo. Se elige según el tipo de problema:

| Problema | Pérdida | Fórmula | Observaciones |
|---|---|---|---|
| Regresión | **MSE** | `(1/N) Σ (yᵢ − ŷᵢ)²` | Penaliza fuerte errores grandes; sensible a outliers |
| Regresión robusta | **MAE** | `(1/N) Σ |yᵢ − ŷᵢ|` | Menos sensible a outliers; gradiente constante |
| Regresión robusta | **Huber** | cuadrática cerca de 0, lineal lejos | Compromiso MSE/MAE |
| Clasificación binaria | **BCE** | `−[y·log ŷ + (1−y)·log(1−ŷ)]` | Combínala con sigmoid de salida |
| Clasificación multiclase | **Cross-entropy** | `−Σ yᵢ·log ŷᵢ` | Combínala con softmax de salida |
| Ranking / embeddings | **Triplet / Contrastive** | margen entre pares | Face recognition, retrieval |
| Modelado de lenguaje | **Perplexity** = `exp(cross-entropy)` | Métrica derivada de CE | GPT, BERT |

**Ejemplo intuitivo** (clasificación binaria):

- Predicción `ŷ = 0.9`, etiqueta real `y = 1` → BCE = `−log(0.9) ≈ 0.105` (bien).
- Predicción `ŷ = 0.1`, etiqueta real `y = 1` → BCE = `−log(0.1) ≈ 2.30` (muy mal).
- La pérdida **crece sin límite** cuando el modelo está "seguro y equivocado". Esto castiga la sobre-confianza errónea.

### 2. Gradiente y descenso del gradiente

El gradiente `∇_θ L` es un vector con **una componente por cada parámetro** que indica cuánto cambiaría la pérdida si moviéramos ese parámetro un poco. La actualización básica es:

```
θ ← θ − η · ∇_θ L(θ)
```

Donde `η` es el **learning rate**. Interpretación:

- Gradiente positivo → el peso está "muy alto" → bájalo.
- Gradiente negativo → el peso está "muy bajo" → súbelo.
- Magnitud grande → urgencia; magnitud pequeña → casi óptimo.

#### Variantes

| Variante | Datos por paso | Pros | Contras |
|---|---|---|---|
| **Batch GD** | Todo el dataset | Gradiente exacto, estable | Lento, no cabe en memoria |
| **SGD** | 1 ejemplo | Rápido, escapa mínimos locales | Ruidoso, converge errático |
| **Mini-batch SGD** | 32–512 ejemplos | Compromiso estándar en DL | Hay que elegir batch size |

#### Optimizadores modernos

| Optimizador | Idea | Cuándo usar |
|---|---|---|
| **SGD + momentum** | Acumula velocidad en direcciones consistentes | Visión (ResNet, ImageNet) |
| **RMSProp** | Escala el gradiente por su magnitud reciente | RNNs |
| **Adam** | Momentum + RMSProp | Default para empezar |
| **AdamW** | Adam con weight decay desacoplado | **Estándar en LLMs/Transformers** |
| **Lion** | Signo del momentum, menos memoria | Modelos muy grandes |

Fórmula de Adam (simplificada):

```
mₜ = β₁·mₜ₋₁ + (1−β₁)·gₜ          ← momentum
vₜ = β₂·vₜ₋₁ + (1−β₂)·gₜ²         ← varianza del gradiente
θ ← θ − η · m̂ₜ / (√v̂ₜ + ε)
```

### 3. Learning rate: el hiperparámetro más importante

| LR | Síntoma |
|---|---|
| Demasiado alto (ej. 1.0) | Loss diverge o oscila violentamente; puede volverse NaN |
| Correcto (ej. 1e-3) | Loss baja de forma suave y monótona |
| Demasiado bajo (ej. 1e-6) | Loss baja pero tarda eternidad; entrena muy lento |

**Técnicas prácticas:**

- **LR warmup**: empezar con LR pequeño y subirlo linealmente los primeros ~1000 steps (clave en Transformers).
- **LR schedule**: reducir el LR durante el entrenamiento (step decay, cosine annealing, ReduceLROnPlateau).
- **LR finder**: barrido logarítmico (1e-7 → 1) viendo dónde la loss baja más rápido (técnica popularizada por fast.ai).

### 4. Batches, steps y epochs

![Training process](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson02-batch-step-epoch.svg)

- **Batch**: un grupo de ejemplos procesados juntos (ej. 32, 64, 128).
- **Step** (iteración): una actualización de pesos = un batch procesado.
- **Epoch**: una pasada completa por todos los datos de entrenamiento.

**Cálculo típico** con 50,000 ejemplos y batch size 128:

```
steps_por_epoch = ceil(50_000 / 128) = 391
10 epochs       = 3,910 steps  → 3,910 actualizaciones de pesos
```

**Trade-offs del batch size:**

| Batch size | Memoria GPU | Estabilidad del gradiente | Generalización |
|---|---|---|---|
| 1–8 | Muy baja | Muy ruidoso | A veces mejor (regularización implícita) |
| 32–128 | Moderada | Equilibrada | Buena, default común |
| 1024+ | Alta | Casi exacto | Peor sin ajustes (requiere warmup, LR escalado) |

### 5. Backpropagation

Backpropagation es el algoritmo que calcula `∂L/∂θ` para **todos** los parámetros de la red en **una sola pasada hacia atrás**, aplicando la **regla de la cadena** del cálculo.

![Backpropagation](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson02-backpropagation-flow.svg)

Para una red simple `x → z = Wx+b → a = φ(z) → L(a, y)`:

```
∂L/∂W = ∂L/∂a · ∂a/∂z · ∂z/∂W
       └──δ──┘  └φ'(z)┘  └ xᵀ ┘
```

En redes profundas, el gradiente de la capa `l` depende del gradiente de la capa `l+1`:

```
δ⁽ᴸ⁾ = ∇_a L ⊙ φ'(z⁽ᴸ⁾)                        ← capa de salida
δ⁽ˡ⁾ = ((W⁽ˡ⁺¹⁾)ᵀ · δ⁽ˡ⁺¹⁾) ⊙ φ'(z⁽ˡ⁾)        ← capas internas
∂L/∂W⁽ˡ⁾ = δ⁽ˡ⁾ · (h⁽ˡ⁻¹⁾)ᵀ
∂L/∂b⁽ˡ⁾ = δ⁽ˡ⁾
```

Backpropagation es **O(nº parámetros)** por paso, igual que el forward. Sin él, entrenar modelos con millones de pesos sería inviable. Los frameworks modernos (**autograd** en PyTorch, **tf.GradientTape** en TensorFlow, **grad** en JAX) construyen un grafo computacional y aplican backprop automáticamente.

### 6. Ciclo de entrenamiento completo

![Complete Training Process](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson02-training-cycle-complete.svg)

```
1. Inicializar θ (He/Xavier)
2. Para cada epoch:
     mezclar (shuffle) el dataset
     Para cada batch:
         a. Forward pass:  ŷ = f(x; θ)
         b. Calcular loss: L(ŷ, y)
         c. Backward pass: ∇_θ L
         d. Actualizar:    θ ← θ − η·∇_θ L  (vía optimizador)
     evaluar en validation
     si val_loss no mejora en N epochs → early stop
3. Evaluar en test (una sola vez)
```

### 7. Monitoreo: curvas de pérdida

| Patrón | Diagnóstico | Acción |
|---|---|---|
| Train ↓, Val ↓, juntas | Entrena bien | Continuar |
| Train ↓, Val ↑ | Overfitting | Dropout, L2, early stop, más datos |
| Train plano desde el inicio | LR muy bajo, o gradientes muertos | Subir LR, revisar init |
| Train oscilante / NaN | LR muy alto | Bajar LR, gradient clipping |
| Train = Val, ambas altas | Underfitting | Más capacidad, entrenar más |

## Ejemplo con código

### Entrenamiento desde cero con NumPy (binary classification)

```python
import numpy as np

rng = np.random.default_rng(0)

# Dataset sintético: 2 clases linealmente separables en 2D
N = 500
X = rng.normal(0, 1, (N, 2))
y = (X[:, 0] + X[:, 1] > 0).astype(float).reshape(-1, 1)

# MLP: 2 -> 8 (ReLU) -> 1 (sigmoid)
n_in, n_hidden, n_out = 2, 8, 1
W1 = rng.normal(0, np.sqrt(2/n_in),     (n_in, n_hidden))
b1 = np.zeros(n_hidden)
W2 = rng.normal(0, np.sqrt(2/n_hidden), (n_hidden, n_out))
b2 = np.zeros(n_out)

def sigmoid(z): return 1 / (1 + np.exp(-np.clip(z, -500, 500)))
def relu(z):    return np.maximum(0, z)
def drelu(z):   return (z > 0).astype(float)

lr, batch_size, epochs = 0.1, 32, 200
history = []

for epoch in range(epochs):
    idx = rng.permutation(N)
    for start in range(0, N, batch_size):
        b = idx[start:start+batch_size]
        xb, yb = X[b], y[b]

        # ----- Forward -----
        z1 = xb @ W1 + b1
        a1 = relu(z1)
        z2 = a1 @ W2 + b2
        a2 = sigmoid(z2)

        # ----- Loss: binary cross-entropy -----
        eps = 1e-9
        loss = -np.mean(yb*np.log(a2+eps) + (1-yb)*np.log(1-a2+eps))

        # ----- Backward (regla de la cadena) -----
        dz2 = (a2 - yb) / len(b)              # dL/dz2 con sigmoid+BCE
        dW2 = a1.T @ dz2
        db2 = dz2.sum(axis=0)

        da1 = dz2 @ W2.T
        dz1 = da1 * drelu(z1)
        dW1 = xb.T @ dz1
        db1 = dz1.sum(axis=0)

        # ----- Update (SGD) -----
        W1 -= lr * dW1;  b1 -= lr * db1
        W2 -= lr * dW2;  b2 -= lr * db2

    if epoch % 20 == 0:
        preds = (sigmoid(relu(X @ W1 + b1) @ W2 + b2) > 0.5)
        acc = (preds == y).mean()
        print(f"epoch {epoch:3d}  loss={loss:.4f}  acc={acc:.3f}")
```

### Versión PyTorch idiomática

```python
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

device = "cuda" if torch.cuda.is_available() else "cpu"

X_t = torch.tensor(X, dtype=torch.float32)
y_t = torch.tensor(y, dtype=torch.float32)
loader = DataLoader(TensorDataset(X_t, y_t), batch_size=32, shuffle=True)

model = nn.Sequential(
    nn.Linear(2, 8), nn.ReLU(),
    nn.Linear(8, 1)                 # sin sigmoid: usamos BCEWithLogitsLoss
).to(device)

loss_fn   = nn.BCEWithLogitsLoss()  # más estable que sigmoid + BCE
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-2, weight_decay=1e-4)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=50)

for epoch in range(50):
    model.train()
    total = 0.0
    for xb, yb in loader:
        xb, yb = xb.to(device), yb.to(device)
        optimizer.zero_grad()
        logits = model(xb)
        loss = loss_fn(logits, yb)
        loss.backward()
        # Gradient clipping: evita exploding gradients
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()
        total += loss.item() * xb.size(0)
    scheduler.step()
    if epoch % 10 == 0:
        print(f"epoch {epoch:3d}  avg_loss={total/len(loader.dataset):.4f}")
```

### Early stopping y checkpointing

```python
best_val = float("inf")
patience, bad_epochs = 10, 0

for epoch in range(1000):
    train_one_epoch(...)
    val_loss = evaluate(...)
    if val_loss < best_val - 1e-4:
        best_val = val_loss
        bad_epochs = 0
        torch.save(model.state_dict(), "best.pt")
    else:
        bad_epochs += 1
        if bad_epochs >= patience:
            print(f"Early stop en epoch {epoch}, mejor val_loss={best_val:.4f}")
            break
```

## Errores comunes

- **Learning rate incorrecto.** El error #1 en DL. Loss NaN → bájalo 10×. Loss plano → súbelo 10×. Usa LR finder.
- **Olvidar `optimizer.zero_grad()`**. PyTorch acumula gradientes por defecto; sin resetearlos se suman entre batches y la actualización es incorrecta.
- **Olvidar `model.eval()` y `torch.no_grad()`** en inferencia. Dropout y BatchNorm cambian de modo; sin `eval()` evalúas incorrectamente. Sin `no_grad()` gastas memoria calculando gradientes innecesarios.
- **Vanishing gradients**. Gradientes multiplicados muchas veces por valores < 1 colapsan a 0 en capas iniciales. Soluciones: ReLU/GELU, inicialización He, **BatchNorm**/**LayerNorm**, **skip connections** (ResNet).
- **Exploding gradients**. Lo contrario: gradientes crecen exponencialmente, loss se vuelve NaN. Soluciones: **gradient clipping** (`clip_grad_norm_`), bajar LR.
- **Train-test contamination**. Normalizar con media global antes del split, o incluir el target en los features. Resultado: métricas infladas que colapsan en producción.
- **Overfitting silencioso**. Train acc 99%, val acc 65%. Soluciones: dropout, L2 (`weight_decay`), data augmentation, early stopping, más datos.
- **Batch size demasiado grande sin ajustar LR**. Al duplicar batch size debes aproximadamente duplicar LR (regla de escalado lineal) o la convergencia empeora.
- **Mezclar sigmoid + BCELoss manual**. Numéricamente inestable. Usa `BCEWithLogitsLoss` (log-sum-exp trick interno).
- **Doble softmax**. `nn.CrossEntropyLoss` ya aplica softmax internamente. Pásale logits, no `softmax(logits)`.
- **No shuffle en el DataLoader**. Si los datos están ordenados por clase, el modelo ve lotes puros de una sola clase y oscila brutalmente.
- **No fijar la semilla**. Resultados no reproducibles → debugging infernal. `torch.manual_seed(42); np.random.seed(42); random.seed(42)`.

## Resumen

- Entrenar = minimizar una **función de pérdida** ajustando parámetros con **descenso del gradiente**.
- La **loss** se elige según el problema: MSE/MAE (regresión), BCE (binario), Cross-entropy (multiclase).
- El **gradiente** indica dirección y magnitud del ajuste; **backpropagation** lo calcula eficientemente con la regla de la cadena.
- El **learning rate** es el hiperparámetro más sensible: ni muy alto (diverge) ni muy bajo (nunca converge). Usa warmup y schedulers.
- **Batch → step → epoch**: estructura el entrenamiento balanceando memoria, estabilidad del gradiente y generalización.
- **Adam/AdamW** son el default moderno; **SGD + momentum** sigue siendo rey en visión.
- **Monitorea train vs. val**: si divergen → overfitting (dropout, L2, early stop).
- Técnicas esenciales para redes profundas: **inicialización He/Xavier**, **BatchNorm/LayerNorm**, **gradient clipping**, **skip connections**.
- En la próxima lección verás cómo distintas **arquitecturas** (feedforward → CNN → RNN → LSTM → Transformer) resolvieron los límites del entrenamiento clásico y abrieron la era de los LLMs.
