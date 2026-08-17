# Binary Trees — Análisis Combinatorio, Fórmulas y Clasificación

> **Idea central:** Un árbol binario no es solo una estructura — es un objeto matemático con propiedades precisas.
> Saber **cuántos árboles existen**, cómo se relacionan **nodos con altura**, y qué distingue a un árbol **strict** de uno **complete** es lo que separa a quien usa árboles de quien los **entiende**.

---

## Tabla de Contenidos

**Parte I — Conteo de Árboles Binarios**
1. [Número de Árboles Binarios](#1-número-de-árboles-binarios)
2. [Números de Catalan](#2-números-de-catalan)
3. [Nodos Etiquetados vs No Etiquetados](#3-nodos-etiquetados-vs-no-etiquetados)

**Parte II — Fórmulas Altura ↔ Nodos**
4. [Altura Dada → Nodos](#4-altura-dada--nodos)
5. [Nodos Dados → Altura](#5-nodos-dados--altura)
6. [Rango de Altura de un Árbol Binario](#6-rango-de-altura-de-un-árbol-binario)

**Parte III — Nodos Internos vs Externos**
7. [Relación Grado 2 y Grado 0](#7-relación-grado-2-y-grado-0)

**Parte IV — Strict Binary Tree**
8. [Definición y Propiedades](#8-definición-y-propiedades)
9. [Fórmulas de Strict Binary Tree](#9-fórmulas-de-strict-binary-tree)

**Parte V — Representaciones**
10. [Representación con Arrays](#10-representación-con-arrays)
11. [Representación Enlazada](#11-representación-enlazada)

**Parte VI — Full y Complete Binary Tree**
12. [Full Binary Tree](#12-full-binary-tree)
13. [Complete Binary Tree](#13-complete-binary-tree)
14. [Comparación: Strict vs Complete vs Full](#14-comparación-strict-vs-complete-vs-full)

**Parte VII — Síntesis**
15. [Resumen de Fórmulas](#15-resumen-de-fórmulas)
16. [Errores Comunes](#16-errores-comunes)
17. [Intuición de Ingeniería](#17-intuición-de-ingeniería)

---

# PARTE I — CONTEO DE ÁRBOLES BINARIOS

---

# 1. Número de Árboles Binarios

## 1.1 El problema

Dado un número **n** de nodos, ¿cuántos **árboles binarios estructuralmente distintos** se pueden generar?

No nos importa el contenido de los nodos — solo la **forma** (shape) del árbol. Estos son **nodos no etiquetados** (unlabeled).

## 1.2 Observación por enumeración

### n = 3 nodos → 5 formas

```text
  O        O       O         O        O
 /        / \       \       /          \
O        O   O       O     O            O
/                      \     \          /
O                        O     O      O
```

### n = 4 nodos → 14 formas

Se generan 7 formas distintas. Cada una tiene su imagen espejo, produciendo 7 más. Total: **14**.

### Tabla de valores

| n | Árboles distintos |
|---|-------------------|
| 0 | 1                 |
| 1 | 1                 |
| 2 | 2                 |
| 3 | 5                 |
| 4 | 14                |
| 5 | 42                |
| 6 | 132               |
| 7 | 429               |

## 1.3 Árboles con altura máxima

De todos los árboles posibles con n nodos, ¿cuántos tienen la **altura máxima** (n - 1)?

Son los árboles completamente sesgados (skewed). En cada nivel hay una decisión binaria: ir a la izquierda o a la derecha.

```text
n = 3:  árboles con altura máxima = 2² = 4
n = 4:  árboles con altura máxima = 2³ = 8
n = 5:  árboles con altura máxima = 2⁴ = 16
```

> **Fórmula:** Número de árboles con altura máxima = **2^(n-1)**

---

# 2. Números de Catalan

## 2.1 Fórmula combinatoria

El número de árboles binarios estructuralmente distintos con n nodos es el **n-ésimo número de Catalan**:

```text
T(n) = C(2n, n) / (n + 1)

     = (2n)! / ((n + 1)! × n!)
```

### Ejemplo: T(5)

```text
T(5) = C(10, 5) / 6
     = (10 × 9 × 8 × 7 × 6) / (5 × 4 × 3 × 2 × 1 × 6)
     = 252 / 6
     = 42
```

## 2.2 Fórmula recursiva

Los números de Catalan también se pueden calcular recursivamente:

```text
T(n) = Σ T(i-1) × T(n-i)     para i = 1 hasta n
```

**Intuición:** Para construir un árbol de n nodos, se elige un nodo como raíz. Los restantes n-1 nodos se dividen entre el subárbol izquierdo (i-1 nodos) y el derecho (n-i nodos). Se multiplican las posibilidades de cada lado y se suman sobre todas las particiones.

### Verificación: T(6)

```text
T(6) = T(0)×T(5) + T(1)×T(4) + T(2)×T(3) + T(3)×T(2) + T(4)×T(1) + T(5)×T(0)
     = 1×42 + 1×14 + 2×5 + 5×2 + 14×1 + 42×1
     = 42 + 14 + 10 + 10 + 14 + 42
     = 132 ✓
```

---

# 3. Nodos Etiquetados vs No Etiquetados

## 3.1 Nodos no etiquetados (Unlabeled)

Son nodos vacíos — sin nombres ni valores. Solo importa la **forma** del árbol.

```text
Fórmula: T(n) = C(2n, n) / (n + 1)
```

## 3.2 Nodos etiquetados (Labeled)

Cada nodo tiene una etiqueta única (A, B, C... o 1, 2, 3...). Ahora importa tanto la **forma** como la **asignación** de etiquetas.

Para una forma dada, n etiquetas se pueden asignar de **n!** formas (permutaciones).

```text
Forma fija, n = 3, etiquetas {A, B, C}:

    A       A       B       B       C       C
   / \     / \     / \     / \     / \     / \
  B   C   C   B   A   C   C   A   A   B   B   A

→ 3! = 6 asignaciones por forma
```

### Fórmula para nodos etiquetados

```text
T_labeled(n) = C(2n, n) / (n + 1) × n!
               ─────────────────   ────
               formas distintas    permutaciones
               (Catalan)           de etiquetas
```

| Componente | Significado |
|-----------|-------------|
| `C(2n,n)/(n+1)` | Número de **formas** (shapes) del árbol |
| `n!` | Número de **maneras de llenar** una forma con n etiquetas |

---

# PARTE II — FÓRMULAS ALTURA ↔ NODOS

---

# 4. Altura Dada → Nodos

## 4.1 Mínimo de nodos

Para alcanzar una altura h, se necesita al menos **un nodo por nivel** (cadena lineal).

```text
Altura h = 3, mínimo de nodos:

    A
    |
    B
    |
    C
    |
    D

4 nodos para h = 3
```

> **Fórmula:** N_min = **h + 1**

| Altura | Nodos mínimos |
|--------|---------------|
| 1      | 2             |
| 2      | 3             |
| 3      | 4             |
| 4      | 5             |

## 4.2 Máximo de nodos

Para obtener el máximo, cada nivel debe estar completamente lleno (full binary tree).

```text
Altura h = 3, máximo de nodos:

Nivel 0:  1 nodo   = 2⁰
Nivel 1:  2 nodos  = 2¹
Nivel 2:  4 nodos  = 2²
Nivel 3:  8 nodos  = 2³

Total = 1 + 2 + 4 + 8 = 15
```

Esto es una **serie geométrica** con A=1, R=2, K=h:

```text
S = A × (R^(K+1) - 1) / (R - 1)
  = 1 × (2^(h+1) - 1) / (2 - 1)
  = 2^(h+1) - 1
```

> **Fórmula:** N_max = **2^(h+1) - 1**

### Verificación

```text
h = 3 → N_max = 2⁴ - 1 = 15 ✓
h = 2 → N_max = 2³ - 1 = 7  ✓
h = 1 → N_max = 2² - 1 = 3  ✓
```

---

# 5. Nodos Dados → Altura

## 5.1 Máxima altura

Ocurre con un árbol completamente sesgado (cada nodo tiene un solo hijo).

```text
n = 7 nodos, altura máxima:

A → B → C → D → E → F → G

Altura = 6 = n - 1
```

> **Fórmula:** H_max = **n - 1**

**Derivación:** Viene de invertir N_min = h + 1 → h = n - 1.

## 5.2 Mínima altura

Ocurre con un árbol completamente lleno (full binary tree).

> **Fórmula:** H_min = **⌊log₂(n+1)⌋ - 1**

**Derivación:** Invertir N_max = 2^(h+1) - 1:

```text
N = 2^(h+1) - 1
N + 1 = 2^(h+1)
h + 1 = log₂(N + 1)
h = log₂(N + 1) - 1
```

### Verificación

```text
n = 15 → H_min = log₂(16) - 1 = 4 - 1 = 3 ✓
n = 7  → H_min = log₂(8) - 1  = 3 - 1 = 2 ✓
n = 3  → H_min = log₂(4) - 1  = 2 - 1 = 1 ✓
```

---

# 6. Rango de Altura de un Árbol Binario

> **La altura de un árbol binario con n nodos varía entre log₂(n) y n.**
>
> ```text
> ⌊log₂(n)⌋ ≤ h ≤ n - 1
> ```
>
> **Logarítmica → Lineal.** Esta es la propiedad más importante del árbol binario.

| Escenario | Forma del árbol | Altura | Orden |
|-----------|----------------|--------|-------|
| Mejor caso (más compacto) | Full / Complete | log₂(n) | O(log n) |
| Peor caso (degenerado) | Skewed (cadena) | n - 1 | O(n) |

```text
n = 15 nodos:

  Altura mínima = 3 (full tree)      Altura máxima = 14 (cadena lineal)

         A                            A
       /   \                          |
      B     C                         B
     / \   / \                        |
    D   E F   G                       C
   /\ /\ /\ /\                       |
  ...                                ...
```

---

# PARTE III — NODOS INTERNOS VS EXTERNOS

---

# 7. Relación Grado 2 y Grado 0

## 7.1 Clasificación por grado

En un árbol binario, cada nodo puede tener grado 0, 1 o 2:

| Grado | Significado | Tipo |
|-------|-------------|------|
| 0 | Sin hijos | Nodo externo (hoja) |
| 1 | Un hijo | Nodo interno |
| 2 | Dos hijos | Nodo interno |

## 7.2 La fórmula

> **En cualquier árbol binario:**
> ```text
> n₀ = n₂ + 1
> ```
> Donde n₀ = nodos de grado 0 (hojas), n₂ = nodos de grado 2.

**Nota:** Los nodos de grado 1 (n₁) no participan en esta relación. La fórmula se cumple **sin importar** cuántos nodos de grado 1 existan.

## 7.3 Verificación con ejemplos

```text
Ejemplo 1:                    Ejemplo 2:
      A                            A
     / \                          / \
    B   C                        B   C
   / \                          / \   \
  D   E                        D   E   F
 /                                    / \
F                                    G   H

n₂ = 2 (A, B)                 n₂ = 3 (A, B, F)
n₁ = 1 (D)                    n₁ = 1 (C)
n₀ = 3 (C, E, F)              n₀ = 4 (D, E, G, H)
→ n₀ = n₂ + 1 = 3 ✓           → n₀ = n₂ + 1 = 4 ✓
```

---

# PARTE IV — STRICT BINARY TREE

---

# 8. Definición y Propiedades

## 8.1 ¿Qué es un Strict Binary Tree?

Un **strict binary tree** (también llamado **proper binary tree**) es un árbol binario donde cada nodo tiene **exactamente 0 o 2 hijos**. Nunca 1.

```text
✅ Strict:               ❌ No strict:
      A                        A
     / \                      / \
    B   C                    B   C
   / \                      /
  D   E                    D
```

> **Regla:** No existen nodos de grado 1 (n₁ = 0).

## 8.2 Consecuencia directa

Como n₁ = 0, la fórmula n₀ = n₂ + 1 implica:

```text
Total de nodos = n₀ + n₂ = (n₂ + 1) + n₂ = 2n₂ + 1

→ Un strict binary tree siempre tiene un número impar de nodos.
```

Y la relación entre hojas y nodos internos es aún más directa:

> **e = i + 1** (external = internal + 1)

---

# 9. Fórmulas de Strict Binary Tree

## 9.1 Altura dada → Nodos

| Métrica | Fórmula | Derivación |
|---------|---------|------------|
| Nodos mínimos | `2h + 1` | Un nodo interno con 2 hijos por nivel |
| Nodos máximos | `2^(h+1) - 1` | Full binary tree (igual que BT general) |

```text
Altura h = 3:

Mínimo (2×3 + 1 = 7 nodos):        Máximo (2⁴ - 1 = 15 nodos):

        A                                    A
       / \                                /     \
      B   C                              B       C
     / \                                / \     / \
    D   E                              D   E   F   G
   / \                                /\ /\ /\ /\
  F   G                              H I J K L M N O
```

### Verificación de mínimo

```text
h = 2 → 2(2) + 1 = 5
h = 3 → 2(3) + 1 = 7
h = 4 → 2(4) + 1 = 9

Patrón: 5, 7, 9 → números impares consecutivos ✓
```

## 9.2 Nodos dados → Altura

| Métrica | Fórmula |
|---------|---------|
| Altura mínima | `⌊log₂(n+1)⌋ - 1` |
| Altura máxima | `(n - 1) / 2` |

## 9.3 Tabla comparativa: BT General vs Strict BT

| Fórmula | Binary Tree | Strict Binary Tree |
|---------|------------|-------------------|
| N_min (dado h) | h + 1 | **2h + 1** |
| N_max (dado h) | 2^(h+1) - 1 | 2^(h+1) - 1 |
| H_min (dado n) | log₂(n+1) - 1 | log₂(n+1) - 1 |
| H_max (dado n) | n - 1 | **(n - 1) / 2** |
| Rango de altura | log n → n | log n → n |

> **El rango de altura (logarítmico a lineal) se mantiene.** Lo que cambia es que el strict tree limita más el crecimiento lineal.

---

# PARTE V — REPRESENTACIONES

---

# 10. Representación con Arrays

## 10.1 Idea

Almacenar los nodos nivel por nivel en un array, usando el **índice** para codificar las relaciones padre-hijo.

### Fórmulas de navegación (1-indexed)

```text
Para un nodo en índice i:
  Hijo izquierdo:  2i
  Hijo derecho:    2i + 1
  Padre:           ⌊i/2⌋
```

## 10.2 Ejemplo

```text
Árbol:
           A
          / \
         B   C
        / \   \
       D   E   G

Array (1-indexed):
Index:  1    2    3    4    5    6    7
Value: [A]  [B]  [C]  [D]  [E]  [-]  [G]
                                  ↑
                           C no tiene hijo izq → espacio vacío
```

### Verificación de fórmulas

```text
Left(1) = 2×1 = 2 → B ✓
Right(1) = 2×1+1 = 3 → C ✓
Left(3) = 2×3 = 6 → vacío ✓
Right(3) = 2×3+1 = 7 → G ✓
Parent(5) = ⌊5/2⌋ = 2 → B ✓
Parent(7) = ⌊7/2⌋ = 3 → C ✓
```

## 10.3 Cuándo usar arrays

| Caso | Resultado |
|------|-----------|
| Árbol completo/full | ✅ Sin desperdicio de espacio |
| Árbol sesgado (skewed) | ❌ O(2ⁿ) espacio para n nodos |

> **Regla:** Usa arrays solo para árboles **completos** (heaps).

---

# 11. Representación Enlazada

## 11.1 Estructura del nodo

```text
┌──────┬──────┬──────┐
│ left  │ data │ right│
│  *    │      │  *   │
└──┬───┴──────┴───┬──┘
   │              │
   ▼              ▼
 hijo izq      hijo der
```

```c
typedef struct TreeNode {
    int data;
    struct TreeNode *left;
    struct TreeNode *right;
} TreeNode;
```

## 11.2 Propiedad de punteros NULL

> **Si un árbol binario tiene n nodos, tiene exactamente n + 1 punteros NULL.**

```text
       A               Punteros NULL:
      / \               D.left, D.right,
     B   C              E.left, E.right,
    / \                 C.left, C.right
   D   E
                        n = 5 nodos → 6 punteros NULL ✓
```

**Analogía con strict binary tree:** Esta fórmula es análoga a `e = i + 1`. Los punteros NULL son las "hojas externas" de la representación enlazada.

## 11.3 Comparación: Array vs Enlazada

| Criterio | Array | Enlazada |
|----------|-------|----------|
| Acceso a padre | **O(1)** — fórmula | O(n) sin ptr padre |
| Acceso a hijo | **O(1)** — fórmula | O(1) — puntero |
| Espacio (full tree) | O(n) | O(n) + punteros |
| Espacio (skewed) | O(2ⁿ) | **O(n)** |
| Flexibilidad | Baja | **Alta** |
| Mejor para | Heaps, complete BT | Árboles generales |

---

# PARTE VI — FULL Y COMPLETE BINARY TREE

---

# 12. Full Binary Tree

## 12.1 Definición

Un **full binary tree** de altura h tiene **todos los niveles completamente llenos**. Contiene el máximo número de nodos posible para su altura.

```text
Full Binary Tree (h = 2):

         A              Nivel 0: 1 nodo  = 2⁰
        / \
       B   C            Nivel 1: 2 nodos = 2¹
      / \ / \
     D  E F  G          Nivel 2: 4 nodos = 2²

Total = 2⁰ + 2¹ + 2² = 7 = 2³ - 1
```

### Propiedades

| Propiedad | Fórmula |
|-----------|---------|
| Nodos totales | `2^(h+1) - 1` |
| Hojas | `2^h` |
| Nodos internos | `2^h - 1` |
| Verificación | hojas = internos + 1 ✓ |

> **Un full binary tree es siempre strict Y siempre complete.**

---

# 13. Complete Binary Tree

## 13.1 Definición

Un **complete binary tree** de altura h es un árbol que:
1. Es **full hasta el nivel h-1**.
2. En el **último nivel**, los nodos se llenan de **izquierda a derecha** sin saltos.

```text
✅ Complete (sin huecos):          ❌ No complete (hay hueco):

        A                                A
       / \                              / \
      B   C                            B   C
     / \ /                            / \   \
    D  E F                            D   E   F
                                     (falta hijo izq de C)
```

## 13.2 Representación en array

La propiedad clave del complete binary tree: al almacenarlo en un array nivel por nivel, **no hay espacios vacíos** entre el primer y el último elemento.

```text
Complete tree:          Array:
      A                 [A][B][C][D][E][F]
     / \                 1   2   3   4   5   6
    B   C                → Sin huecos ✓
   / \ /
  D  E F

No complete:            Array:
      A                 [A][B][C][-][-][F]
     / \                 1   2   3   4   5   6
    B   C                → Huecos en 4 y 5 ✗
         \
          F
```

## 13.3 Por qué importa

> **Los heaps (min-heap, max-heap) son complete binary trees.** Por eso se implementan eficientemente con arrays — sin desperdiciar espacio.

---

# 14. Comparación: Strict vs Complete vs Full

## 14.1 Tabla comparativa

| Propiedad | Full | Complete | Strict |
|-----------|------|----------|--------|
| Todos los niveles llenos | **Sí** | Todos menos el último | No necesariamente |
| Último nivel | Lleno | Izq → Der | Cualquier orden |
| Nodos con 1 hijo | **0** | **≤ 1** | **0** |
| Representable en array sin huecos | Sí | **Sí** | Con huecos |
| ¿Es strict? | **Sí** | No siempre | **Sí** (definición) |
| ¿Es complete? | **Sí** | **Sí** (definición) | No siempre |

## 14.2 Relaciones lógicas

```text
Full → Complete ✓     (todo full es complete)
Full → Strict ✓       (todo full es strict)
Complete → Strict ✗   (un complete puede tener 1 nodo con 1 hijo)
Strict → Complete ✗   (un strict puede tener huecos entre niveles)
```

## 14.3 Ejemplos comparativos

```text
Solo Strict:               Solo Complete:           Ambos (Full):
      A                          A                       A
     / \                        / \                    /   \
    B   C                      B   C                  B     C
       / \                    /                      / \   / \
      D   E                  D                      D   E F   G
(strict ✓, complete ✗)    (complete ✓, strict ✗)   (full, strict, complete ✓)

Ninguno:
      A
     / \
    B   C
         \
          D
(strict ✗, complete ✗)
```

---

# PARTE VII — SÍNTESIS

---

# 15. Resumen de Fórmulas

## 15.1 Conteo de árboles

| Tipo de nodo | Fórmula |
|-------------|---------|
| Unlabeled (formas) | `C(2n, n) / (n + 1)` (Catalan) |
| Labeled | `C(2n, n) / (n + 1) × n!` |
| Con altura máxima | `2^(n-1)` |

## 15.2 Altura ↔ Nodos (Binary Tree general)

| Dado | Mínimo | Máximo |
|------|--------|--------|
| Altura h → Nodos | `h + 1` | `2^(h+1) - 1` |
| Nodos n → Altura | `⌊log₂(n+1)⌋ - 1` | `n - 1` |

## 15.3 Altura ↔ Nodos (Strict Binary Tree)

| Dado | Mínimo | Máximo |
|------|--------|--------|
| Altura h → Nodos | `2h + 1` | `2^(h+1) - 1` |
| Nodos n → Altura | `⌊log₂(n+1)⌋ - 1` | `(n - 1) / 2` |

## 15.4 Relaciones de nodos

| Fórmula | Aplica a |
|---------|----------|
| `n₀ = n₂ + 1` | Cualquier árbol binario |
| `external = internal + 1` | Strict binary tree |
| Punteros NULL = `n + 1` | Representación enlazada |

## 15.5 Navegación en array (1-indexed)

| Relación | Fórmula |
|----------|---------|
| Hijo izquierdo | `2i` |
| Hijo derecho | `2i + 1` |
| Padre | `⌊i/2⌋` |

---

# 16. Errores Comunes

| Error | Corrección |
|-------|-----------|
| Confundir **strict** con **complete** | Strict = 0 o 2 hijos. Complete = sin huecos en array. Son propiedades independientes. |
| Asumir que un strict tree es complete | Un strict tree puede tener huecos en niveles intermedios. |
| Olvidar que la altura empieza en 0 | Un solo nodo tiene altura 0, no 1. |
| Usar `n₀ = n₂ + 1` solo para strict | La fórmula aplica a **cualquier** árbol binario, no solo strict. |
| Usar arrays para árboles sesgados | Un árbol sesgado de n nodos necesita O(2ⁿ) espacio en array. Usar representación enlazada. |
| Confundir Catalan con permutaciones | Catalan cuenta **formas**. Para nodos etiquetados, multiplicar por n!. |

---

# 17. Intuición de Ingeniería

## 17.1 ¿Por qué importa la altura?

La altura de un árbol determina el **costo de las operaciones** (búsqueda, inserción, eliminación):

```text
Árbol balanceado (h ≈ log n):  Búsqueda = O(log n) — eficiente
Árbol degenerado (h ≈ n):      Búsqueda = O(n) — como una lista enlazada
```

> **La diferencia entre un buen y un mal árbol es la diferencia entre O(log n) y O(n).**

## 17.2 ¿Cuándo usar cada representación?

| Necesidad | Representación |
|-----------|----------------|
| Heap / Priority Queue | Array (complete binary tree) |
| BST dinámico | Enlazada (nodos + punteros) |
| Árbol estático conocido | Array |
| Árbol que crece/decrece | Enlazada |

## 17.3 ¿Cuándo importa el tipo de árbol?

| Tipo | Garantiza | Útil para |
|------|-----------|-----------|
| Complete | Sin desperdicio en array | Heaps |
| Strict | Relación e = i + 1 estricta | Análisis teórico, Huffman |
| Full | Máxima densidad | Cota inferior de altura |
