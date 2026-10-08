# Neuronas, Capas y Funciones de Activación

## ¿Qué es?

Una **red neuronal artificial (ANN)** es una función matemática compuesta por muchas unidades simples llamadas **neuronas**, organizadas en **capas**, que transforman un vector de entrada `x ∈ ℝⁿ` en un vector de salida `y ∈ ℝᵐ` mediante una secuencia de operaciones lineales y no lineales. Cada neurona es, en esencia, una **regresión logística generalizada**: calcula una suma ponderada de sus entradas, le suma un sesgo (`bias`) y aplica una **función de activación** no lineal.

Formalmente, una neurona individual computa:

```
z = w·x + b = Σᵢ wᵢ·xᵢ + b
a = φ(z)
```

Donde:
- `x ∈ ℝⁿ` son las entradas.
- `w ∈ ℝⁿ` son los **pesos aprendibles**.
- `b ∈ ℝ` es el **bias** (desplazamiento).
- `φ` es una función de activación no lineal (ReLU, sigmoid, tanh, GELU, etc.).
- `a` es la **activación** (salida de la neurona).

Una **capa densa** (fully-connected) con `m` neuronas aplica esta operación en paralelo mediante multiplicación matricial:

```
z = W·x + b     con W ∈ ℝᵐˣⁿ,  b ∈ ℝᵐ
a = φ(z)        aplicada elemento a elemento
```

Una **red profunda (deep neural network)** apila `L` capas de este tipo:

```
h⁽⁰⁾ = x
h⁽ˡ⁾ = φ⁽ˡ⁾(W⁽ˡ⁾·h⁽ˡ⁻¹⁾ + b⁽ˡ⁾)   para l = 1, ..., L
ŷ   = h⁽ᴸ⁾
```

### Jerarquía conceptual

```
Neurona        → una función escalar φ(w·x + b)
Capa           → m neuronas en paralelo, operación matricial
Red (MLP)      → L capas apiladas → función compuesta
Deep Learning  → redes con L ≥ 3 capas ocultas
```

### Teorema de aproximación universal

**Cybenko (1989)** y **Hornik (1991)** demostraron que una red neuronal con **una sola capa oculta** de suficientes neuronas y una activación no polinomial puede aproximar cualquier función continua `f: K ⊂ ℝⁿ → ℝ` sobre un conjunto compacto `K` con precisión arbitraria. En la práctica, redes **profundas** aproximan las mismas funciones con **exponencialmente menos neuronas** que redes anchas y planas.

## ¿Por qué importa?

Las reglas `if/else` escritas a mano no escalan cuando el problema tiene cientos de variables de entrada y relaciones no lineales. Un sistema de recomendación debe considerar edad, historial, hora del día, dispositivo, estacionalidad y miles de interacciones entre ellos. Las redes neuronales **aprenden automáticamente estas interacciones** desde datos.

Por qué dominan hoy:

- **Universalidad**: pueden aproximar cualquier función medible dada capacidad suficiente.
- **Composicionalidad**: cada capa aprende representaciones cada vez más abstractas (pixels → bordes → formas → objetos).
- **Escalabilidad en GPU**: las operaciones son multiplicaciones de matrices densas, perfectas para hardware paralelo (CUDA, cuDNN, TPU).
- **Transferencia**: una red pre-entrenada en millones de imágenes se puede *fine-tunear* a tareas específicas con pocos datos.
- **End-to-end**: eliminan el *feature engineering* manual que dominaba ML clásico.

### Contexto histórico

| Año | Hito |
|---|---|
| 1943 | McCulloch & Pitts formalizan la neurona matemática |
| 1957 | Rosenblatt construye el **Perceptrón** (hardware físico) |
| 1969 | Minsky & Papert prueban que el perceptrón no resuelve XOR → **invierno de la IA** |
| 1986 | Rumelhart, Hinton & Williams popularizan **backpropagation** |
| 1989 | LeCun aplica CNNs a dígitos manuscritos (LeNet) |
| 1998 | LeNet-5 en producción para leer cheques bancarios |
| 2006 | Hinton: Deep Belief Networks → renace el término *Deep Learning* |
| 2012 | **AlexNet** gana ImageNet por 10 puntos usando GPUs → revolución moderna |
| 2015 | ResNet (152 capas) con conexiones residuales |
| 2017 | Transformers (*Attention Is All You Need*) |
| 2020 | GPT-3 (175B parámetros) |
| 2022 | ChatGPT masifica el deep learning |

## ¿Cómo funciona?

### 1. La neurona como votación ponderada

Imagina un detector de spam con tres señales:

- `x₁` = número de signos de exclamación
- `x₂` = 1 si contiene "FREE", 0 si no
- `x₃` = longitud del correo (normalizada)

La neurona asigna pesos según la importancia que descubra al entrenarse:

```
z = 0.8·x₁ + 0.6·x₂ + 0.2·x₃ − 0.3
a = ReLU(z)
```

![Single Neuron Example](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson01-single-neuron-example.svg)

El bias `−0.3` representa la **predisposición inicial**: con todas las entradas en cero, la neurona está "ligeramente inclinada" a decir *no spam*.

### 2. Funciones de activación: la no linealidad es obligatoria

Sin activación no lineal, una red de `L` capas colapsa a una sola transformación lineal:

```
W₃·(W₂·(W₁·x + b₁) + b₂) + b₃  =  W'·x + b'
```

Es decir, sin `φ`, no importa cuántas capas apiles: solo puedes aprender hiperplanos. **La no linealidad es lo que permite aproximar funciones arbitrarias.**

#### Comparativa de activaciones

| Activación | Fórmula | Rango | Derivada | Uso típico | Problemas |
|---|---|---|---|---|---|
| **Sigmoid** | `1 / (1 + e⁻ᶻ)` | (0, 1) | `σ(z)·(1−σ(z))` | Salida binaria | Saturación → vanishing gradients |
| **Tanh** | `(eᶻ − e⁻ᶻ)/(eᶻ + e⁻ᶻ)` | (−1, 1) | `1 − tanh²(z)` | RNNs clásicas | Satura en los extremos |
| **ReLU** | `max(0, z)` | [0, ∞) | 1 si z>0, 0 si no | Default en capas ocultas | *Dead ReLU* (neuronas estancadas en 0) |
| **Leaky ReLU** | `max(αz, z)`, α≈0.01 | ℝ | 1 o α | Evita dead ReLU | Un hiperparámetro extra |
| **GELU** | `z·Φ(z)` | ≈ℝ | suave | Transformers (BERT, GPT) | Más costosa |
| **Swish/SiLU** | `z·σ(z)` | ≈ℝ | suave | EfficientNet, LLMs modernos | Más costosa que ReLU |
| **Softmax** | `eᶻⁱ / Σⱼ eᶻʲ` | (0,1), suma 1 | Jacobiano denso | Clasificación multiclase (salida) | No usar en capas ocultas |

![Activation Functions](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson01-activation-functions.svg)

**Regla práctica actual (2024+):**
- Capas ocultas de MLPs/CNNs: **ReLU** o **GELU**.
- Capas ocultas de Transformers modernos: **GELU**, **SwiGLU**.
- Salida binaria: **sigmoid** + binary cross-entropy.
- Salida multiclase: **softmax** + categorical cross-entropy.
- Salida de regresión: **sin activación** (identidad).

### 3. Capas y propagación hacia adelante (forward pass)

Una red *feedforward* con una capa oculta se expresa compactamente como:

```
Entrada x ∈ ℝⁿ
    ↓  W₁ ∈ ℝʰˣⁿ,  b₁ ∈ ℝʰ
h = ReLU(W₁·x + b₁)       ← capa oculta
    ↓  W₂ ∈ ℝᵐˣʰ,  b₂ ∈ ℝᵐ
ŷ = softmax(W₂·h + b₂)    ← capa de salida
```

![Multilayer Architecture](https://hrcdn.net/ai-engineering/module-1/light/neural-nets-lesson01-multilayer-architecture.svg)

Cada capa transforma la representación de la anterior en una más abstracta. En visión por computador esto se visualiza nítidamente:

| Capa | Qué aprende |
|---|---|
| 1 | Bordes orientados, gradientes de color |
| 2 | Texturas, esquinas, patrones repetidos |
| 3 | Partes de objetos (ruedas, ojos, ventanas) |
| 4 | Objetos completos (coches, caras, edificios) |

### 4. Profundidad vs. ancho

| Dimensión | Ventajas | Desventajas | Cuándo preferir |
|---|---|---|---|
| **Más profundo** (más capas) | Jerarquías de features ricas; menos parámetros para la misma expresividad | Más propenso a vanishing/exploding gradients; difícil de optimizar sin skip connections | Imágenes, texto, audio (datos con estructura jerárquica) |
| **Más ancho** (más neuronas/capa) | Fácil de paralelizar; capta muchos patrones por nivel | Explosión de parámetros; overfitting con poca data | Datos tabulares, pocas features |

**Regla práctica**: empieza con 2-3 capas ocultas de 64-256 neuronas, usa ReLU, y aumenta la profundidad solo cuando el baseline se queda corto.

## Ejemplo con código

### Una neurona desde cero (NumPy)

```python
import numpy as np

def neurona(x, w, b, phi):
    """Una neurona: z = w·x + b, a = phi(z)."""
    z = np.dot(w, x) + b
    return phi(z)

# Detector de spam de una sola neurona
x = np.array([5, 1, 0.8])           # [exclamaciones, has_FREE, longitud]
w = np.array([0.8, 0.6, 0.2])       # pesos
b = -0.3

relu    = lambda z: np.maximum(0, z)
sigmoid = lambda z: 1 / (1 + np.exp(-z))

print("Pre-activación z =", np.dot(w, x) + b)
print("ReLU   →", neurona(x, w, b, relu))
print("Sigmoid→", neurona(x, w, b, sigmoid))
```

### MLP de 3 capas desde cero

```python
import numpy as np

rng = np.random.default_rng(42)

class MLP:
    """Red feedforward: entrada → oculta(ReLU) → oculta(ReLU) → salida(sigmoid)."""
    def __init__(self, n_in, n_hidden1, n_hidden2, n_out):
        # Inicialización de He para ReLU (var = 2/n_in)
        self.W1 = rng.normal(0, np.sqrt(2/n_in),     (n_hidden1, n_in))
        self.b1 = np.zeros(n_hidden1)
        self.W2 = rng.normal(0, np.sqrt(2/n_hidden1), (n_hidden2, n_hidden1))
        self.b2 = np.zeros(n_hidden2)
        self.W3 = rng.normal(0, np.sqrt(2/n_hidden2), (n_out, n_hidden2))
        self.b3 = np.zeros(n_out)

    @staticmethod
    def relu(z):    return np.maximum(0, z)
    @staticmethod
    def sigmoid(z): return 1 / (1 + np.exp(-np.clip(z, -500, 500)))

    def forward(self, x):
        self.h1 = self.relu(self.W1 @ x + self.b1)
        self.h2 = self.relu(self.W2 @ self.h1 + self.b2)
        self.y  = self.sigmoid(self.W3 @ self.h2 + self.b3)
        return self.y

net = MLP(n_in=3, n_hidden1=8, n_hidden2=4, n_out=1)
print("P(spam) =", net.forward(np.array([5, 1, 0.8])))
```

### Versión industrial con PyTorch

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class SpamNet(nn.Module):
    def __init__(self, n_in=3, hidden=(16, 8), p_dropout=0.2):
        super().__init__()
        self.fc1 = nn.Linear(n_in, hidden[0])
        self.fc2 = nn.Linear(hidden[0], hidden[1])
        self.fc3 = nn.Linear(hidden[1], 1)
        self.dropout = nn.Dropout(p_dropout)

    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = self.dropout(x)
        x = F.relu(self.fc2(x))
        return torch.sigmoid(self.fc3(x))

model = SpamNet()
x = torch.tensor([[5.0, 1.0, 0.8]])
print("P(spam) =", model(x).item())
print("Nº parámetros:", sum(p.numel() for p in model.parameters()))
```

### Visualizar el poder de la no linealidad

```python
import numpy as np, matplotlib.pyplot as plt

# Puntos XOR: no separables por un hiperplano
X = np.array([[0,0],[0,1],[1,0],[1,1]])
y = np.array([0, 1, 1, 0])

# Un MLP de 1 capa oculta con 2 neuronas ReLU resuelve XOR;
# una regresión logística (sin capa oculta) no puede.
```

## Errores comunes

- **Olvidar la no linealidad**. Apilar `nn.Linear → nn.Linear → nn.Linear` sin `ReLU` entre medio es matemáticamente equivalente a una sola capa lineal. Error silencioso: el modelo entrena pero nunca aprende patrones no lineales.
- **Usar sigmoid en capas ocultas profundas**. Satura en los extremos (derivada ≈ 0), produciendo **vanishing gradients**: las capas iniciales dejan de aprender. Solución: ReLU o GELU en capas ocultas; sigmoid solo en la salida binaria.
- **Dead ReLUs**. Si una neurona recibe entradas siempre negativas, ReLU la fija en 0 y su gradiente es 0 permanentemente: queda "muerta". Causas: learning rate alto, mala inicialización. Solución: **Leaky ReLU**, **GELU**, inicialización de **He** (`Var(W) = 2/n_in`).
- **Inicialización mala**. Pesos todos a cero → todas las neuronas computan lo mismo (simetría no se rompe). Pesos muy grandes → activaciones saturadas. Usa **He** para ReLU, **Xavier/Glorot** para tanh/sigmoid.
- **Overfitting por red demasiado grande**. Un MLP con 1M parámetros entrenado en 500 ejemplos memoriza los datos. Solución: reducir capacidad, añadir **dropout**, **weight decay (L2)**, **early stopping**.
- **No normalizar las entradas**. Si una feature está en [0, 10⁶] y otra en [0, 1], la primera domina los gradientes. Usa `StandardScaler` o **BatchNorm**/**LayerNorm**.
- **Softmax en capas ocultas**. Softmax normaliza a una distribución de probabilidad; en capas intermedias destruye información. Resérvalo exclusivamente para la salida multiclase.
- **Confundir logits con probabilidades**. `nn.CrossEntropyLoss` en PyTorch **ya aplica softmax internamente**: pásale logits, no probabilidades. Doble softmax = gradientes rotos.
- **Ignorar el costo computacional**. Una red de 10 capas × 2048 neuronas tiene ~40M parámetros: puede no caber en una GPU modesta. Perfila memoria con `torch.cuda.memory_summary()`.

## Herramientas del ecosistema

| Herramienta | Rol |
|---|---|
| **PyTorch** | Framework DL dominante en investigación y producción |
| **TensorFlow / Keras** | Alternativa de Google, fuerte en móviles (TFLite) |
| **JAX** | Diferenciación automática + XLA, favorito en labs (DeepMind) |
| **CUDA / cuDNN** | Backend GPU de NVIDIA |
| **ONNX** | Formato intermedio para interoperar modelos |
| **Hugging Face** | Hub de modelos pre-entrenados |

## Resumen

- Una **neurona** computa `a = φ(w·x + b)`: suma ponderada + activación no lineal.
- Una **red neuronal** es una **composición de capas** de neuronas; cada capa produce representaciones más abstractas.
- Sin **no linealidad** la red colapsa a una función lineal. ReLU/GELU son el default moderno en capas ocultas.
- El **teorema de aproximación universal** garantiza que una red con suficientes neuronas puede aproximar cualquier función continua.
- Elige la **salida** según la tarea: identidad (regresión), sigmoid (binaria), softmax (multiclase).
- La **profundidad** aporta jerarquía de features; el **ancho** aporta diversidad por nivel. Empieza simple (2-3 capas, 64-256 neuronas).
- Cuida la **inicialización** (He para ReLU, Xavier para tanh), **normaliza entradas**, y evita trampas clásicas como dead ReLUs o sigmoid en capas profundas.
- Las redes neuronales son el motor de los sistemas modernos de visión, lenguaje y recomendación; dominarlas es prerrequisito para entender Transformers y LLMs.
