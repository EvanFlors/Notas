# AVL Tree — El Primer Árbol Auto-Balanceado

> **Idea central:** Un BST degenerado es una linked list disfrazada: O(n) en todo.
> El AVL Tree resuelve esto con una regla simple: **la diferencia de alturas entre
> subárboles izquierdo y derecho de cualquier nodo nunca puede ser mayor que 1.**
> Cuando se viola, se **rota** el árbol para restaurar el balance. Resultado:
> búsqueda, inserción y eliminación **garantizadas en O(log n)**, siempre.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [¿Por qué AVL?](#1-por-qué-avl)
2. [Definición y Propiedades](#2-definición-y-propiedades)
3. [Factor de Balance](#3-factor-de-balance)
4. [Diferencias con BST](#4-diferencias-con-bst)

**Parte II — Rotaciones**
5. [Concepto de Rotación](#5-concepto-de-rotación)
6. [Rotación Simple LL (Right Rotation)](#6-rotación-simple-ll-right-rotation)
7. [Rotación Simple RR (Left Rotation)](#7-rotación-simple-rr-left-rotation)
8. [Rotación Doble LR (Left-Right)](#8-rotación-doble-lr-left-right)
9. [Rotación Doble RL (Right-Left)](#9-rotación-doble-rl-right-left)
10. [Resumen de Rotaciones](#10-resumen-de-rotaciones)

**Parte III — Inserción**
11. [Algoritmo de Inserción](#11-algoritmo-de-inserción)
12. [Construcción Paso a Paso](#12-construcción-paso-a-paso)

**Parte IV — Eliminación**
13. [Algoritmo de Eliminación](#13-algoritmo-de-eliminación)
14. [Ejemplos de Eliminación](#14-ejemplos-de-eliminación)

**Parte V — Implementación Completa**
15. [Implementación en C](#15-implementación-en-c)

**Parte VI — Análisis**
16. [Altura y Nodos: Relación Matemática](#16-altura-y-nodos-relación-matemática)
17. [Complejidad de Operaciones](#17-complejidad-de-operaciones)

**Parte VII — Síntesis**
18. [Resumen de Complejidad](#18-resumen-de-complejidad)
19. [Errores Comunes y Buenas Prácticas](#19-errores-comunes-y-buenas-prácticas)
20. [Intuición de Ingeniería](#20-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS

---

# 1. ¿Por qué AVL?

## 1.1 El problema del BST

```text
Insertar en BST: 10, 20, 30, 40, 50

BST resultante:              AVL resultante:
    10                             20
      \                           /  \
       20                       10    40
         \                           / \
          30                        30   50
            \
             40
               \
                50

  h = 4                        h = 2
  Search: O(n)                 Search: O(log n)
```

> El BST **no garantiza** balance. El AVL sí.

## 1.2 Historia

- Inventado en **1962** por **Adelson-Velsky y Landis** (de ahí "AVL").
- Fue el **primer** árbol binario de búsqueda auto-balanceado.
- Garantiza altura **O(log n)** después de cada inserción y eliminación.

## 1.3 ¿Cuándo importa?

| n (elementos) | BST degenerado O(n) | AVL O(log n) | Speedup    |
| ------------- | ------------------- | ------------ | ---------- |
| 1,000         | 1,000 ops           | 10 ops       | **100×**   |
| 1,000,000     | 1,000,000 ops       | 20 ops       | **50,000×**|
| 1,000,000,000 | 1,000,000,000 ops   | 30 ops       | **33M×**   |

> Para un millón de elementos, la diferencia entre BST degenerado y AVL es de **50,000 veces**.

---

# 2. Definición y Propiedades

## 2.1 Definición formal

Un **AVL Tree** es un Binary Search Tree donde, para **cada nodo**:

```text
| altura(subárbol_izquierdo) − altura(subárbol_derecho) | ≤ 1
```

Es decir, la **diferencia de alturas** entre los subárboles izquierdo y derecho de **cualquier nodo** es como máximo **1**.

## 2.2 Propiedades

| Propiedad                        | Valor / Descripción                        |
| -------------------------------- | ------------------------------------------ |
| Es un BST                        | Sí (izquierdo < nodo < derecho)            |
| Factor de balance                | {-1, 0, 1} para cada nodo                  |
| Altura máxima                    | ≤ 1.44 × log₂(n + 2)                       |
| Todas las operaciones            | O(log n) garantizado                        |
| Mecanismo de balance             | Rotaciones (simples o dobles)               |
| Máximo rotaciones por inserción  | 1 (una rotación simple o doble)             |
| Máximo rotaciones por eliminación| O(log n) (puede propagar hasta la raíz)     |

## 2.3 ¿Qué es y qué no es AVL?

```text
✅ AVL válido:           ✅ AVL válido:          ❌ NO es AVL:

       30                     30                      30
      /  \                   /  \                    /
    20    40               20    40                20
   /                      /  \                    /
  10                    10    25                 10

  bf(30) = 1-1 = 0       bf(30) = 2-1 = 1       bf(30) = 2-0 = 2  ⚠️
  bf(20) = 1-0 = 1       bf(20) = 1-1 = 0       bf(20) = 1-0 = 1
  bf(40) = 0              bf(40) = 0              bf(10) = 0
  bf(10) = 0              bf(10) = 0, bf(25) = 0
  Todos ∈ {-1,0,1} ✓     Todos ∈ {-1,0,1} ✓     bf(30)=2 → VIOLA ✗
```

---

# 3. Factor de Balance

## 3.1 Definición

```text
balance_factor(node) = height(node->left) − height(node->right)
```

| Balance Factor | Significado                              | Estado     |
| -------------- | ---------------------------------------- | ---------- |
| **bf = 0**     | Subárboles izq y der tienen misma altura | Perfecto   |
| **bf = 1**     | Izquierdo es 1 nivel más alto            | OK (left-heavy) |
| **bf = -1**    | Derecho es 1 nivel más alto              | OK (right-heavy) |
| **bf = 2**     | Izquierdo es 2 niveles más alto          | ⚠️ DESBALANCEADO |
| **bf = -2**    | Derecho es 2 niveles más alto            | ⚠️ DESBALANCEADO |

> **Regla AVL:** `bf ∈ {-1, 0, 1}` para CADA nodo. Si bf = ±2, hay que **rotar**.

## 3.2 Convención de altura

```text
height(NULL) = -1         (árbol vacío)
height(hoja) = 0          (nodo sin hijos)
height(nodo) = 1 + max(height(left), height(right))
```

## 3.3 Ejemplo de cálculo

```text
           30
          /  \
        20    40
       / \      \
      10  25    50

Alturas:
  h(10) = 0, h(25) = 0, h(50) = 0
  h(20) = 1 + max(0, 0) = 1
  h(40) = 1 + max(-1, 0) = 1
  h(30) = 1 + max(1, 1) = 2

Balance factors:
  bf(10) = h(NULL) - h(NULL) = -1 - (-1) = 0
  bf(25) = 0
  bf(50) = 0
  bf(20) = h(10) - h(25) = 0 - 0 = 0
  bf(40) = h(NULL) - h(50) = -1 - 0 = -1
  bf(30) = h(20) - h(40) = 1 - 1 = 0

Todos ∈ {-1, 0, 1} → AVL válido ✓
```

---

# 4. Diferencias con BST

| Aspecto                    | BST                    | AVL Tree                |
| -------------------------- | ---------------------- | ----------------------- |
| Invariante                 | izq < nodo < der       | BST + \|bf\| ≤ 1       |
| Altura garantizada         | **No** (puede ser n-1) | **Sí** (≤ 1.44 log n)  |
| Search peor caso           | O(n)                   | **O(log n)**            |
| Insert peor caso           | O(n)                   | **O(log n)**            |
| Delete peor caso           | O(n)                   | **O(log n)**            |
| Overhead por nodo          | 0 extra                | Campo `height` (1 int)  |
| Overhead por operación     | 0                      | Calcular bf + rotar     |
| Complejidad de implementar | Simple                 | Más complejo            |
| Cuándo usar                | Datos aleatorios       | **Siempre** si necesitas garantía |

```text
BST:  Simple pero impredecible.
AVL:  Un poco más complejo, pero SIEMPRE O(log n).
```

---

# PARTE II — ROTACIONES

---

# 5. Concepto de Rotación

## 5.1 ¿Qué es una rotación?

Una **rotación** es una operación local que **reorganiza 2-3 nodos** para restaurar el balance, **sin violar la propiedad BST**.

```text
Idea clave:
  - Una rotación cambia la ESTRUCTURA (quién es padre de quién).
  - Pero PRESERVA el ORDEN (propiedad BST).
  - Es una operación O(1): solo cambia unos punteros.
```

## 5.2 ¿Cuándo rotar?

Después de insertar o eliminar, recalculamos los balance factors subiendo por el camino de la inserción. Si encontramos un nodo con bf = ±2:

```text
bf = +2 → desbalance hacia la IZQUIERDA (left-heavy)
           ┌── bf(hijo_izq) ≥ 0 → caso LL → rotación derecha
           └── bf(hijo_izq) < 0  → caso LR → rotación izq-der

bf = -2 → desbalance hacia la DERECHA (right-heavy)
           ┌── bf(hijo_der) ≤ 0 → caso RR → rotación izquierda
           └── bf(hijo_der) > 0  → caso RL → rotación der-izq
```

## 5.3 Nomenclatura LL, RR, LR, RL

El nombre indica **dónde está el exceso de peso** (dónde se insertó relativo al nodo desbalanceado):

| Caso   | Significado                                      | Rotación necesaria    |
| ------ | ------------------------------------------------ | --------------------- |
| **LL** | Inserción en el subárbol **Left** del hijo **Left**  | Rotación derecha      |
| **RR** | Inserción en el subárbol **Right** del hijo **Right** | Rotación izquierda   |
| **LR** | Inserción en el subárbol **Right** del hijo **Left** | Doble: izq luego der  |
| **RL** | Inserción en el subárbol **Left** del hijo **Right** | Doble: der luego izq  |

---

# 6. Rotación Simple LL (Right Rotation)

## 6.1 Cuándo aplicar

Cuando el nodo desbalanceado tiene bf = +2 y su hijo izquierdo tiene bf ≥ 0.

```text
El "peso" está en Left-Left → rotar hacia la derecha para equilibrar.
```

## 6.2 Diagrama

```text
Antes (bf(A) = +2, bf(B) ≥ 0):        Después (rotación derecha sobre A):

        A  [bf=+2]                            B  [bf=0]
       / \                                   / \
      B   Ar                               Bl    A
     / \                                         / \
    Bl  Br                                     Br   Ar

Donde:
  Bl, Br, Ar son subárboles (pueden ser NULL o tener nodos).
  h(Bl) ≥ h(Br)  (por eso bf(B) ≥ 0)
```

## 6.3 Operación en punteros

```text
rightRotate(A):
  1. B = A->left
  2. A->left = B->right    (Br se convierte en hijo izq de A)
  3. B->right = A           (A se convierte en hijo der de B)
  4. Actualizar alturas de A y B
  5. Retornar B como nueva raíz del subárbol
```

## 6.4 Ejemplo concreto

```text
Insertar 10, 20, 30... no, eso sería RR.
Insertar 30, 20, 10:

Paso 1: insert(30)        Paso 2: insert(20)        Paso 3: insert(10)

    30                        30                         30  [bf=2]
                             /                          /
                           20                         20
                                                     /
                                                   10

bf(30) = 2 → desbalanceado.
bf(20) = 1 (≥ 0) → caso LL → rotación derecha sobre 30.

rightRotate(30):
  B = 20
  30->left = 20->right = NULL
  20->right = 30
  return 20

Resultado:
        20
       /  \
      10    30

bf(20) = 0, bf(10) = 0, bf(30) = 0  → AVL ✓
```

## 6.5 Implementación

```c
AVLNode* rightRotate(AVLNode *y) {
    AVLNode *x = y->left;
    AVLNode *T2 = x->right;

    // Rotación
    x->right = y;
    y->left = T2;

    // Actualizar alturas (y primero porque ahora es hijo de x)
    y->height = 1 + max(height(y->left), height(y->right));
    x->height = 1 + max(height(x->left), height(x->right));

    return x;    // nueva raíz
}
```

---

# 7. Rotación Simple RR (Left Rotation)

## 7.1 Cuándo aplicar

Cuando el nodo desbalanceado tiene bf = -2 y su hijo derecho tiene bf ≤ 0.

```text
El "peso" está en Right-Right → rotar hacia la izquierda para equilibrar.
```

## 7.2 Diagrama

```text
Antes (bf(A) = -2, bf(B) ≤ 0):       Después (rotación izquierda sobre A):

      A  [bf=-2]                             B  [bf=0]
     / \                                    / \
    Al   B                                A    Br
        / \                              / \
       Bl  Br                           Al  Bl
```

## 7.3 Ejemplo concreto

```text
Insertar 10, 20, 30:

Paso 1: 10    Paso 2:  10       Paso 3:  10  [bf=-2]
                        \                  \
                         20                 20  [bf=-1]
                                              \
                                               30

bf(10) = -2, bf(20) = -1 (≤ 0) → caso RR → rotación izquierda sobre 10.

leftRotate(10):
  B = 20
  10->right = 20->left = NULL
  20->left = 10
  return 20

Resultado:
        20
       /  \
      10    30

bf(20) = 0, bf(10) = 0, bf(30) = 0  → AVL ✓
```

## 7.4 Implementación

```c
AVLNode* leftRotate(AVLNode *x) {
    AVLNode *y = x->right;
    AVLNode *T2 = y->left;

    // Rotación
    y->left = x;
    x->right = T2;

    // Actualizar alturas
    x->height = 1 + max(height(x->left), height(x->right));
    y->height = 1 + max(height(y->left), height(y->right));

    return y;    // nueva raíz
}
```

---

# 8. Rotación Doble LR (Left-Right)

## 8.1 Cuándo aplicar

Cuando bf(nodo) = +2 y bf(hijo_izq) < 0.

```text
El peso está en Left-Right → una sola rotación no basta.
Solución: rotar izquierda sobre el hijo, luego derecha sobre el nodo.
```

## 8.2 ¿Por qué no basta una rotación simple?

```text
        30  [bf=+2]
       /
      10  [bf=-1]
        \
         20

Si hacemos rightRotate(30):
      10
        \
         30
        /
       20

bf(10) = -2 → ¡Sigue desbalanceado! La rotación simple no arregló nada.

El problema: el nodo 20 está en la "esquina interna" (right del left).
Una rotación simple mueve la "esquina externa" a la raíz, pero la interna queda mal.
```

## 8.3 Solución: doble rotación

```text
Paso 1: leftRotate sobre el hijo izquierdo (10):

        30                      30
       /                       /
      10          →           20
        \                    /
         20                10

Paso 2: rightRotate sobre el nodo desbalanceado (30):

        30
       /              →         20
      20                       /  \
     /                        10    30
    10

Resultado:
        20
       /  \
      10    30

bf(20) = 0, bf(10) = 0, bf(30) = 0  → AVL ✓
```

## 8.4 Caso general con subárboles

```text
Antes:                      Después de LR rotation:

        C [bf=+2]                     B
       / \                          /   \
      A   Cr                      A       C
     / \                         / \     / \
    Al   B [bf de A < 0]        Al  Bl  Br  Cr
        / \
       Bl  Br

Paso 1: leftRotate(A)

        C                            C
       / \                          / \
      B   Cr         →             B   Cr
     / \                          / \
    A   Br                       A   Br
   / \                          / \
  Al  Bl                       Al  Bl

Paso 2: rightRotate(C)

        B
      /   \
    A       C
   / \     / \
  Al  Bl  Br  Cr
```

## 8.5 Implementación

```c
// LR Rotation = leftRotate(node->left) + rightRotate(node)
// No necesita función separada; se maneja en la lógica de balance:

// En la función de balance:
if (bf > 1 && getBalance(node->left) < 0) {
    node->left = leftRotate(node->left);    // Paso 1
    return rightRotate(node);                // Paso 2
}
```

---

# 9. Rotación Doble RL (Right-Left)

## 9.1 Cuándo aplicar

Cuando bf(nodo) = -2 y bf(hijo_der) > 0.

```text
El peso está en Right-Left → esquina interna.
Solución: rotar derecha sobre el hijo, luego izquierda sobre el nodo.
```

## 9.2 Ejemplo

```text
Insertar 10, 30, 20:

    10  [bf=-2]
      \
       30  [bf=+1]
      /
     20

Paso 1: rightRotate(30):

    10
      \
       20
         \
          30

Paso 2: leftRotate(10):

        20
       /  \
      10    30

bf(20) = 0, bf(10) = 0, bf(30) = 0  → AVL ✓
```

## 9.3 Caso general

```text
Antes:                      Después de RL rotation:

      A [bf=-2]                       B
     / \                            /   \
    Al   C                        A       C
        / \                      / \     / \
       B   Cr                   Al  Bl  Br  Cr
      / \
     Bl  Br

Paso 1: rightRotate(C)     Paso 2: leftRotate(A)
```

## 9.4 Implementación

```c
// RL Rotation = rightRotate(node->right) + leftRotate(node)
if (bf < -1 && getBalance(node->right) > 0) {
    node->right = rightRotate(node->right);   // Paso 1
    return leftRotate(node);                   // Paso 2
}
```

---

# 10. Resumen de Rotaciones

## 10.1 Tabla de decisión

| bf(nodo) | bf(hijo) | Caso | Rotación              | Resultado          |
| -------- | -------- | ---- | --------------------- | ------------------ |
| **+2**   | **≥ 0**  | LL   | rightRotate(nodo)     | Balance restaurado |
| **+2**   | **< 0**  | LR   | leftRotate(hijo) + rightRotate(nodo) | Balance restaurado |
| **-2**   | **≤ 0**  | RR   | leftRotate(nodo)      | Balance restaurado |
| **-2**   | **> 0**  | RL   | rightRotate(hijo) + leftRotate(nodo) | Balance restaurado |

## 10.2 Diagrama de decisión

```text
¿bf(nodo) = +2 o -2?
│
├── bf = +2 (left-heavy)
│   ├── bf(left child) ≥ 0 → LL → rightRotate(nodo)
│   └── bf(left child) < 0  → LR → leftRotate(left) + rightRotate(nodo)
│
└── bf = -2 (right-heavy)
    ├── bf(right child) ≤ 0 → RR → leftRotate(nodo)
    └── bf(right child) > 0  → RL → rightRotate(right) + leftRotate(nodo)
```

## 10.3 Propiedad fundamental

> **Cada rotación es O(1):** solo reasigna 2-3 punteros y actualiza 2-3 alturas.
> **Las rotaciones preservan la propiedad BST:** el inorder traversal no cambia.

```text
Antes de cualquier rotación:     Después de cualquier rotación:
  inorder = [10, 20, 30]          inorder = [10, 20, 30]  ✓

Solo cambia la FORMA, no el ORDEN.
```

---

# PARTE III — INSERCIÓN

---

# 11. Algoritmo de Inserción

## 11.1 Pasos

```text
insert(root, value):
  1. Insertar como en BST normal (buscar posición, crear hoja).
  2. Subir por el camino de inserción actualizando alturas.
  3. Calcular balance factor en cada nodo del camino.
  4. Si |bf| > 1 → aplicar la rotación correspondiente (LL/RR/LR/RL).
  5. Retornar la nueva raíz del subárbol.
```

## 11.2 Pseudocódigo detallado

```text
insert(node, value):
  // Paso 1: BST insertion
  if node == NULL → return createNode(value)
  if value < node.data → node.left = insert(node.left, value)
  if value > node.data → node.right = insert(node.right, value)
  if value == node.data → return node (no duplicados)

  // Paso 2: Actualizar altura
  node.height = 1 + max(height(node.left), height(node.right))

  // Paso 3: Calcular balance factor
  bf = getBalance(node)

  // Paso 4: Rotaciones si es necesario
  if bf > 1  AND value < node.left.data  → return rightRotate(node)        // LL
  if bf < -1 AND value > node.right.data → return leftRotate(node)         // RR
  if bf > 1  AND value > node.left.data  → LR rotation                    // LR
  if bf < -1 AND value < node.right.data → RL rotation                    // RL

  // Paso 5: Retornar nodo (sin cambio si estaba balanceado)
  return node
```

> **Nota:** En inserción, **como máximo 1 rotación** (simple o doble) restaura el balance. Esto es porque solo 1 nodo se desbalancea al insertar.

---

# 12. Construcción Paso a Paso

## 12.1 Ejemplo completo: insertar 30, 20, 10, 25, 40, 35, 50

### Insert 30

```text
    30 [h=0, bf=0]

Sin desbalance.
```

### Insert 20

```text
      30 [h=1, bf=1]
     /
    20 [h=0, bf=0]

bf(30) = 1 → OK.
```

### Insert 10

```text
        30 [h=2, bf=2] ⚠️
       /
      20 [h=1, bf=1]
     /
    10 [h=0]

bf(30) = 2 → desbalanceado.
bf(20) = 1 (≥ 0) → caso LL → rightRotate(30).

rightRotate(30):
  x = 20
  30->left = 20->right = NULL
  20->right = 30

        20 [h=1, bf=0]
       /  \
      10    30
    [h=0]  [h=0]

✅ AVL válido.
```

### Insert 25

```text
        20 [h=2, bf=0]
       /  \
      10    30
    [h=0]  [h=1, bf=1]
            /
           25 [h=0]

bf(30) = 1, bf(20) = 0 → Todo OK.
```

### Insert 40

```text
        20 [h=2, bf=-1]
       /  \
      10    30 [h=2, bf=0]
            / \
           25  40
```

¡Verificamos todos los bf!

```text
bf(10) = 0, bf(25) = 0, bf(40) = 0
bf(30) = h(25) - h(40) = 0 - 0 = 0
bf(20) = h(10) - h(30) = 0 - 1 = -1

Todos ∈ {-1, 0, 1} → OK ✓
```

### Insert 35

```text
        20 [h=3, bf=-2] ⚠️
       /  \
      10    30 [h=2, bf=-1]
            / \
           25  40 [h=1, bf=1]
              /
             35

bf(20) = h(10) - h(30) = 0 - 2 = -2 → desbalanceado.
bf(30) = h(25) - h(40) = 0 - 1 = -1 (≤ 0) → caso RR → leftRotate(20).

¡Espera! Verifiquemos con cuidado. El nodo desbalanceado es 20.
Su hijo derecho es 30. bf(30) = -1 ≤ 0 → caso RR.

leftRotate(20):
  y = 30
  20->right = 30->left = 25
  30->left = 20

           30 [h=2, bf=0]
          /  \
        20    40 [h=1, bf=1]
       / \   /
      10  25 35

Verificar:
  bf(10) = 0, bf(25) = 0, bf(35) = 0
  bf(20) = h(10) - h(25) = 0 - 0 = 0
  bf(40) = h(35) - h(NULL) = 0 - (-1) = 1
  bf(30) = h(20) - h(40) = 1 - 1 = 0

Todos ∈ {-1, 0, 1} → AVL ✓

Inorder: 10, 20, 25, 30, 35, 40 → ordenado ✓
```

### Insert 50

```text
           30 [h=2, bf=-1]
          /  \
        20    40 [h=1, bf=0]
       / \   / \
      10 25 35  50

bf(40) = h(35) - h(50) = 0 - 0 = 0
bf(30) = h(20) - h(40) = 1 - 1 = 0

Todos OK. Sin rotación necesaria.

Árbol final:
           30
          /  \
        20    40
       / \   / \
      10 25 35  50

Inorder: 10, 20, 25, 30, 35, 40, 50  ✓
```

## 12.2 Ejemplo con rotación LR

```text
Insertar 30, 10, 20:

1. insert(30):    30

2. insert(10):      30 [bf=1]
                   /
                  10

3. insert(20):      30 [bf=+2] ⚠️
                   /
                  10 [bf=-1]
                    \
                     20

bf(30) = +2, bf(10) = -1 (< 0) → caso LR.

Paso 1: leftRotate(10):
        30
       /
      20
     /
    10

Paso 2: rightRotate(30):
        20
       /  \
      10    30

✅ AVL válido.
```

## 12.3 Ejemplo con rotación RL

```text
Insertar 10, 30, 20:

1. insert(10):    10

2. insert(30):    10 [bf=-1]
                    \
                     30

3. insert(20):    10 [bf=-2] ⚠️
                    \
                     30 [bf=+1]
                    /
                   20

bf(10) = -2, bf(30) = +1 (> 0) → caso RL.

Paso 1: rightRotate(30):
    10
      \
       20
         \
          30

Paso 2: leftRotate(10):
        20
       /  \
      10    30

✅ AVL válido.
```

---

# PARTE IV — ELIMINACIÓN

---

# 13. Algoritmo de Eliminación

## 13.1 Pasos

```text
delete(root, value):
  1. Eliminar como en BST normal (3 casos: hoja, 1 hijo, 2 hijos).
  2. Subir actualizando alturas.
  3. Calcular balance factor.
  4. Si |bf| > 1 → rotar.
  5. Retornar nueva raíz.
```

## 13.2 Diferencia clave con inserción

| Aspecto                   | Inserción                    | Eliminación                    |
| ------------------------- | ---------------------------- | ------------------------------ |
| Máximo rotaciones         | **1** (simple o doble)       | **O(log n)** (puede propagar) |
| Desbalance se propaga     | No (1 rotación lo arregla)   | **Sí** (puede subir)          |
| Razón                     | Solo 1 nodo se añadió        | La altura del subárbol cambia  |

> ⚠️ **En eliminación, una rotación puede desbalancear al padre**, requiriendo otra rotación, y así sucesivamente hasta la raíz. Por eso el peor caso es O(log n) rotaciones.

## 13.3 Lógica de balance (igual para insert y delete)

```c
AVLNode* balance(AVLNode *node) {
    // Actualizar altura
    node->height = 1 + max(height(node->left), height(node->right));

    int bf = getBalance(node);

    // LL
    if (bf > 1 && getBalance(node->left) >= 0)
        return rightRotate(node);

    // LR
    if (bf > 1 && getBalance(node->left) < 0) {
        node->left = leftRotate(node->left);
        return rightRotate(node);
    }

    // RR
    if (bf < -1 && getBalance(node->right) <= 0)
        return leftRotate(node);

    // RL
    if (bf < -1 && getBalance(node->right) > 0) {
        node->right = rightRotate(node->right);
        return leftRotate(node);
    }

    return node;    // ya está balanceado
}
```

---

# 14. Ejemplos de Eliminación

## 14.1 Eliminar una hoja (caso simple)

```text
AVL:            30                Eliminar 35:         30
               /  \                                   /  \
             20    40                               20    40
            / \   / \                              / \      \
           10 25 35  50                           10 25      50

bf(40) = h(NULL) - h(50) = -1 - 0 = -1 → OK.
bf(30) = h(20) - h(40) = 1 - 1 = 0 → OK.

Sin rotación necesaria.
```

## 14.2 Eliminar causando desbalance

```text
AVL:            30
               /  \
             20    40
            / \      \
           10 25      50

Eliminar 50:
               30
              /  \
            20    40 [h=0]
           / \
          10  25

bf(30) = h(20) - h(40) = 1 - 0 = 1 → OK (justo en el límite).

Ahora eliminar 40:
               30 [bf=2] ⚠️
              /
            20 [bf=0]
           / \
          10  25

bf(30) = +2, bf(20) = 0 (≥ 0) → caso LL → rightRotate(30).

rightRotate(30):
            20
           /  \
          10    30
                /
               25

Verificar:
  bf(10) = 0, bf(25) = 0
  bf(30) = h(25) - h(NULL) = 0 - (-1) = 1
  bf(20) = h(10) - h(30) = 0 - 1 = -1

Todos ∈ {-1, 0, 1} → AVL ✓
```

## 14.3 Eliminar nodo con 2 hijos

```text
AVL:            30
               /  \
             20    40
            / \   / \
           10 25 35  50

Eliminar 30 (raíz, 2 hijos):
  Sucesor inorder = min del subárbol derecho = 35.
  Copiar 35 al nodo 30 → ahora es 35.
  Eliminar el nodo original 35 del subárbol derecho.

               35
              /  \
            20    40
           / \      \
          10 25      50

bf(40) = -1, bf(35) = 1-1 = 0 → OK. Sin rotación.
```

## 14.4 Eliminación con propagación de rotaciones

```text
AVL:              50
                /    \
              30      70
             / \     / \
            20  40  60  80
           /       /      \
          10      55       90

Eliminar 40:
              50
            /    \
          30      70
         /       / \
        20      60  80
       /       /      \
      10      55       90

bf(30) = h(20) - h(NULL) = 1 - (-1) = 2 → ⚠️ desbalanceado.
bf(20) = 1 (≥ 0) → caso LL → rightRotate(30).

Después de rightRotate(30):
              50
            /    \
          20      70
         /  \    / \
        10   30 60  80
                /      \
               55       90

bf(50) = h(20) - h(70) = 1 - 2 = -1 → OK.
Todo ∈ {-1, 0, 1} → AVL ✓

En este caso solo necesitamos 1 rotación, pero en árboles más grandes
podría propagarse hasta la raíz.
```

---

# PARTE V — IMPLEMENTACIÓN COMPLETA

---

# 15. Implementación en C

## 15.1 Estructura del nodo

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct AVLNode {
    int data;
    struct AVLNode *left;
    struct AVLNode *right;
    int height;
} AVLNode;
```

## 15.2 Funciones auxiliares

```c
int max(int a, int b) {
    return (a > b) ? a : b;
}

int height(AVLNode *node) {
    if (node == NULL) return -1;
    return node->height;
}

int getBalance(AVLNode *node) {
    if (node == NULL) return 0;
    return height(node->left) - height(node->right);
}

AVLNode* createNode(int value) {
    AVLNode *node = (AVLNode*)malloc(sizeof(AVLNode));
    node->data = value;
    node->left = NULL;
    node->right = NULL;
    node->height = 0;
    return node;
}
```

## 15.3 Rotaciones

```c
AVLNode* rightRotate(AVLNode *y) {
    AVLNode *x = y->left;
    AVLNode *T2 = x->right;

    x->right = y;
    y->left = T2;

    y->height = 1 + max(height(y->left), height(y->right));
    x->height = 1 + max(height(x->left), height(x->right));

    return x;
}

AVLNode* leftRotate(AVLNode *x) {
    AVLNode *y = x->right;
    AVLNode *T2 = y->left;

    y->left = x;
    x->right = T2;

    x->height = 1 + max(height(x->left), height(x->right));
    y->height = 1 + max(height(y->left), height(y->right));

    return y;
}
```

## 15.4 Inserción

```c
AVLNode* insert(AVLNode *node, int value) {
    // 1. BST insertion
    if (node == NULL)
        return createNode(value);

    if (value < node->data)
        node->left = insert(node->left, value);
    else if (value > node->data)
        node->right = insert(node->right, value);
    else
        return node;    // no duplicados

    // 2. Actualizar altura
    node->height = 1 + max(height(node->left), height(node->right));

    // 3. Calcular balance factor
    int bf = getBalance(node);

    // 4. Rotaciones

    // LL: bf > 1, insertado en left del left
    if (bf > 1 && value < node->left->data)
        return rightRotate(node);

    // RR: bf < -1, insertado en right del right
    if (bf < -1 && value > node->right->data)
        return leftRotate(node);

    // LR: bf > 1, insertado en right del left
    if (bf > 1 && value > node->left->data) {
        node->left = leftRotate(node->left);
        return rightRotate(node);
    }

    // RL: bf < -1, insertado en left del right
    if (bf < -1 && value < node->right->data) {
        node->right = rightRotate(node->right);
        return leftRotate(node);
    }

    return node;
}
```

## 15.5 Encontrar mínimo

```c
AVLNode* findMin(AVLNode *node) {
    while (node->left != NULL)
        node = node->left;
    return node;
}
```

## 15.6 Eliminación

```c
AVLNode* delete(AVLNode *root, int value) {
    // 1. BST deletion
    if (root == NULL)
        return root;

    if (value < root->data)
        root->left = delete(root->left, value);
    else if (value > root->data)
        root->right = delete(root->right, value);
    else {
        // Nodo encontrado

        // Caso 1 & 2: 0 o 1 hijo
        if (root->left == NULL || root->right == NULL) {
            AVLNode *temp = root->left ? root->left : root->right;

            if (temp == NULL) {
                // Sin hijos (hoja)
                temp = root;
                root = NULL;
            } else {
                // 1 hijo: copiar contenido del hijo
                *root = *temp;
            }
            free(temp);
        } else {
            // Caso 3: 2 hijos — usar sucesor inorder
            AVLNode *successor = findMin(root->right);
            root->data = successor->data;
            root->right = delete(root->right, successor->data);
        }
    }

    if (root == NULL)
        return root;

    // 2. Actualizar altura
    root->height = 1 + max(height(root->left), height(root->right));

    // 3. Calcular balance factor
    int bf = getBalance(root);

    // 4. Rotaciones

    // LL
    if (bf > 1 && getBalance(root->left) >= 0)
        return rightRotate(root);

    // LR
    if (bf > 1 && getBalance(root->left) < 0) {
        root->left = leftRotate(root->left);
        return rightRotate(root);
    }

    // RR
    if (bf < -1 && getBalance(root->right) <= 0)
        return leftRotate(root);

    // RL
    if (bf < -1 && getBalance(root->right) > 0) {
        root->right = rightRotate(root->right);
        return leftRotate(root);
    }

    return root;
}
```

> **Nota:** En delete usamos `getBalance(hijo)` en vez de comparar con `value`, porque el desbalance puede no estar relacionado con el valor eliminado (a diferencia de insert).

## 15.7 Funciones de utilidad

```c
void inorder(AVLNode *root) {
    if (root == NULL) return;
    inorder(root->left);
    printf("%d ", root->data);
    inorder(root->right);
}

void preorder(AVLNode *root) {
    if (root == NULL) return;
    printf("%d(%d) ", root->data, getBalance(root));
    preorder(root->left);
    preorder(root->right);
}

void freeAVL(AVLNode *root) {
    if (root == NULL) return;
    freeAVL(root->left);
    freeAVL(root->right);
    free(root);
}
```

## 15.8 Programa completo de ejemplo

```c
int main() {
    AVLNode *root = NULL;

    // Insertar
    int values[] = {30, 20, 10, 25, 40, 35, 50};
    int n = sizeof(values) / sizeof(values[0]);

    for (int i = 0; i < n; i++) {
        root = insert(root, values[i]);
        printf("Insert %d → Preorder: ", values[i]);
        preorder(root);
        printf("\n");
    }

    printf("\nInorder: ");
    inorder(root);
    printf("\n");

    // Eliminar
    printf("\nDelete 20:\n");
    root = delete(root, 20);
    printf("Inorder: ");
    inorder(root);
    printf("\n");
    printf("Preorder: ");
    preorder(root);
    printf("\n");

    freeAVL(root);
    return 0;
}
```

```text
Output esperado:
Insert 30 → Preorder: 30(0)
Insert 20 → Preorder: 30(1) 20(0)
Insert 10 → Preorder: 20(0) 10(0) 30(0)          ← rotación LL
Insert 25 → Preorder: 20(-1) 10(0) 30(1) 25(0)
Insert 40 → Preorder: 20(-1) 10(0) 30(0) 25(0) 40(0)
Insert 35 → Preorder: 30(0) 20(0) 10(0) 25(0) 40(1) 35(0)   ← rotación RR
Insert 50 → Preorder: 30(0) 20(0) 10(0) 25(0) 40(0) 35(0) 50(0)

Inorder: 10 20 25 30 35 40 50

Delete 20:
Inorder: 10 25 30 35 40 50
```

---

# PARTE VI — ANÁLISIS

---

# 16. Altura y Nodos: Relación Matemática

## 16.1 Número mínimo de nodos para altura h

¿Cuál es el **AVL más "flaco"** (con menos nodos) posible de altura h?

```text
Sea N(h) = número mínimo de nodos para un AVL de altura h.

N(-1) = 0    (árbol vacío)
N(0) = 1     (solo raíz)
N(1) = 2     (raíz + 1 hijo)
N(h) = 1 + N(h-1) + N(h-2)    para h ≥ 2

¿Por qué? Para que un AVL tenga altura h con mínimos nodos:
  - Un subárbol debe tener altura h-1 (para que el nodo tenga esa altura)
  - El otro puede tener altura h-2 (máximo desbalance permitido: 1)
  - +1 por la raíz

Es similar a Fibonacci:
  h:    0   1   2   3   4    5    6    7
  N(h): 1   2   4   7  12   20   33   54
```

```text
AVL mínimo de altura 3 (N(3) = 7 nodos):

            A
           / \
          B   C            h(B)=2, h(C)=1 → bf(A) = 1
         / \   \
        D   E   F          h(D)=1, h(E)=0, h(F)=0
       /
      G                    h(G)=0

7 nodos, altura 3. No se puede hacer un AVL de h=3 con menos de 7 nodos.
```

## 16.2 Relación N(h) y Fibonacci

```text
N(h) = F(h+3) - 1

Donde F(k) es el k-ésimo número de Fibonacci.

Fibonacci: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, ...
           F(0) F(1) F(2) ...

N(0) = F(3) - 1 = 2 - 1 = 1  ✓
N(1) = F(4) - 1 = 3 - 1 = 2  ✓
N(2) = F(5) - 1 = 5 - 1 = 4  ✓
N(3) = F(6) - 1 = 8 - 1 = 7  ✓
```

## 16.3 Altura máxima dado n nodos

```text
De N(h) = F(h+3) - 1 y F(k) ≈ φᵏ/√5 (φ = (1+√5)/2 ≈ 1.618):

N(h) ≈ φ^(h+3)/√5

Despejando h:
  h ≈ 1.44 × log₂(n + 2) - 1.33

Simplificado:
  h ≤ 1.44 × log₂(n)

Comparación:
  Árbol perfectamente balanceado: h = log₂(n)
  AVL:                           h ≤ 1.44 × log₂(n)

  AVL puede ser hasta 44% más alto que el óptimo, pero sigue siendo O(log n).
```

| n          | log₂(n)  | 1.44×log₂(n) | Ratio |
| ---------- | -------- | ------------- | ----- |
| 100        | 6.6      | 9.6           | 1.44× |
| 1,000      | 10.0     | 14.4          | 1.44× |
| 1,000,000  | 20.0     | 28.8          | 1.44× |

> **Aunque 44% más alto que el óptimo, sigue siendo O(log n) — incomparablemente mejor que O(n) del BST degenerado.**

---

# 17. Complejidad de Operaciones

## 17.1 Todas las operaciones

| Operación   | Tiempo         | Espacio        | Rotaciones              |
| ----------- | -------------- | -------------- | ----------------------- |
| **Search**  | O(log n)       | O(1) iter / O(log n) rec | 0                |
| **Insert**  | O(log n)       | O(log n)       | Máximo **1** (simple o doble) |
| **Delete**  | O(log n)       | O(log n)       | Máximo **O(log n)**     |
| **Min/Max** | O(log n)       | O(1)           | 0                       |
| **Inorder** | O(n)           | O(log n)       | 0                       |

## 17.2 Desglose de Insert

```text
Insert = BST insert + actualizar alturas + rotar
       = O(log n)   + O(log n)           + O(1)
       = O(log n)
```

## 17.3 Desglose de Delete

```text
Delete = BST delete + actualizar alturas + rotar (puede propagar)
       = O(log n)   + O(log n)           + O(log n) × O(1)
       = O(log n)
```

## 17.4 ¿Por qué solo 1 rotación en insert pero O(log n) en delete?

```text
Insert:
  Solo se añade una hoja. Solo un camino raíz→hoja se afecta.
  La primera rotación que se aplica restaura la altura del subárbol
  a su valor original → no se propaga.

Delete:
  Se elimina un nodo. La rotación puede REDUCIR la altura del subárbol.
  Si la altura baja → el padre puede desbalancearse.
  Efecto dominó hacia la raíz.
```

---

# PARTE VII — SÍNTESIS

---

# 18. Resumen de Complejidad

## 18.1 AVL vs BST vs otros

| Operación | BST (promedio) | BST (peor) | **AVL (siempre)** | Red-Black    |
| --------- | -------------- | ---------- | ------------------ | ------------ |
| Search    | O(log n)       | O(n)       | **O(log n)**       | O(log n)     |
| Insert    | O(log n)       | O(n)       | **O(log n)**       | O(log n)     |
| Delete    | O(log n)       | O(n)       | **O(log n)**       | O(log n)     |
| Altura    | O(log n) avg   | O(n)       | **≤ 1.44 log n**   | ≤ 2 log n    |
| Balance   | No garantizado | No         | **|bf| ≤ 1**       | Reglas color |
| Rotac/ins | 0              | 0          | **≤ 1**            | ≤ 2          |
| Rotac/del | 0              | 0          | **≤ O(log n)**     | ≤ 3          |

## 18.2 AVL vs Red-Black

| Aspecto           | AVL                           | Red-Black               |
| ----------------- | ----------------------------- | ----------------------- |
| Balance más estricto | **Sí** (\|bf\| ≤ 1)        | No (h ≤ 2 log n)       |
| Búsquedas         | **Más rápido** (más bajo)     | Ligeramente más lento   |
| Inserciones       | Más lento (más rotaciones)    | **Más rápido**          |
| Eliminaciones     | Más lento (propaga)           | **Más rápido** (≤3 rot) |
| Usado en          | Bases de datos, búsqueda      | Librerías estándar (Java TreeMap, C++ std::map) |

> **Regla general:**
> - **Muchas búsquedas, pocas inserciones** → AVL (más corto, búsqueda más rápida).
> - **Muchas inserciones/eliminaciones** → Red-Black (menos rotaciones).

---

# 19. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                                    | Consecuencia                               |
| -------------------------------------------------------- | ------------------------------------------ |
| Olvidar actualizar altura después de rotación            | Alturas incorrectas → bf incorrecto → árbol corrupto |
| Actualizar altura en orden incorrecto en rotación        | El padre se calcula antes que el hijo      |
| No retornar nueva raíz después de rotación               | El padre apunta al nodo viejo, no al nuevo |
| Usar `value` para decidir rotación en delete             | En delete el desbalance no depende del valor eliminado |
| Confundir LL/LR (o RR/RL)                               | Aplicar rotación incorrecta → sigue desbalanceado |
| No verificar `node == NULL` antes de acceder a `height`  | Segfault                                   |
| Olvidar caso `root == NULL` después de delete            | Segfault al actualizar altura de NULL      |
| Asumir que solo 1 rotación basta en delete               | Desbalance puede propagarse                |
| No liberar nodo eliminado (`free`)                       | Memory leak                                |
| Confundir `height` del nodo con `balance factor`         | Son conceptos diferentes                   |

### ✅ Buenas Prácticas

| Práctica                                                 | Razón                                       |
| -------------------------------------------------------- | ------------------------------------------- |
| `height(NULL) = -1` como convención                     | Simplifica cálculos, evita casos especiales |
| Actualizar altura del **hijo antes** que del padre       | El padre depende de las alturas actualizadas de los hijos |
| Siempre `return` la nueva raíz en insert/delete          | Las rotaciones cambian quién es la raíz del subárbol |
| Usar `getBalance(hijo)` en delete (no comparar con value)| El desbalance puede no estar en la dirección de eliminación |
| Verificar AVL con inorder + chequeo de bf en cada nodo   | Doble verificación: orden + balance         |
| Encapsular rotaciones en funciones separadas             | Reutilización y claridad                    |
| Probar con secuencias: ordenada, inversa, y aleatoria    | Cubrir LL, RR, LR, RL                      |
| Probar eliminación seguida de múltiples inserciones      | Verificar que no se corrompe               |
| Imprimir preorder con bf para depurar                    | Visualizar estructura + balance             |
| Siempre `freeAVL` al terminar                            | Prevenir memory leaks                       |

```c
// ✅ Función de verificación (útil para testing)
int verifyAVL(AVLNode *root) {
    if (root == NULL) return 1;

    int bf = getBalance(root);
    if (bf < -1 || bf > 1) {
        printf("ERROR: nodo %d tiene bf=%d\n", root->data, bf);
        return 0;
    }

    return verifyAVL(root->left) && verifyAVL(root->right);
}

// ✅ Imprimir con balance factor (para depuración)
void printTree(AVLNode *root, int level) {
    if (root == NULL) return;
    printTree(root->right, level + 1);
    for (int i = 0; i < level; i++) printf("    ");
    printf("%d(bf=%d)\n", root->data, getBalance(root));
    printTree(root->left, level + 1);
}
```

---

# 20. Intuición de Ingeniería

> **El AVL Tree es un BST que se niega a degenerarse.**
> Cada vez que una inserción o eliminación amenaza con convertirlo en lista,
> el AVL **rota** para mantenerse bajo. El precio: un poco más de trabajo por operación.
> La recompensa: **O(log n) garantizado, sin excepciones.**

### La idea en una oración

```text
BST + "si me desbalanceo, roto" = AVL
```

### El mapa mental de rotaciones

```text
¿Dónde está el peso extra?

  bf = +2 (izquierdo pesado)          bf = -2 (derecho pesado)
  │                                   │
  ├── Peso en Left-Left (LL)          ├── Peso en Right-Right (RR)
  │   → rightRotate                   │   → leftRotate
  │   (simple, una rotación)          │   (simple, una rotación)
  │                                   │
  └── Peso en Left-Right (LR)        └── Peso en Right-Left (RL)
      → leftRotate(hijo)                 → rightRotate(hijo)
        + rightRotate(nodo)                + leftRotate(nodo)
      (doble, esquina interna)           (doble, esquina interna)
```

### La analogía del equilibrista

```text
Un BST es un equilibrista sin red.
  → Si le sale todo bien (datos aleatorios), se mantiene balanceado.
  → Si tiene mala suerte (datos ordenados), se cae (O(n)).

Un AVL es un equilibrista CON red.
  → Cada vez que se inclina demasiado (bf = ±2), la red lo corrige (rotación).
  → Nunca se cae. Siempre O(log n).
  → La red tiene un pequeño costo (overhead de rotaciones), pero vale la pena.
```

### ¿Cuándo usar AVL en la vida real?

```text
✅ Usar AVL:
  • Base de datos in-memory con muchas búsquedas
  • Diccionarios con búsqueda frecuente
  • Cuando necesitas GARANTÍA de O(log n)
  • Cuando el costo de una operación lenta es inaceptable

❌ Preferir Red-Black:
  • Muchas inserciones/eliminaciones
  • Librerías estándar (Java TreeMap, C++ std::map)

❌ Preferir Hash Table:
  • Solo necesitas buscar/insertar/eliminar (sin orden)
  • No necesitas min/max/rango/sucesor
```

### Relación con otros temas

| Tema                             | Archivo               |
| -------------------------------- | --------------------- |
| Arrays a bajo nivel              | Arrays CDT.md         |
| Operaciones sobre arrays         | Arrays ADT.md         |
| Matrices densas y especiales     | Matrices.md           |
| Sparse matrices y polinomios     | SparseMatrices.md     |
| Strings (arrays de char)         | Strings.md            |
| Linked Lists                     | LinkedList.md         |
| Stacks                           | Stack.md              |
| Queues                           | Queue.md              |
| Trees (fundamentos)              | Trees.md              |
| Binary Search Trees              | BinarySearchTree.md   |
| **AVL Trees (este)**             | AVLTree.md            |
