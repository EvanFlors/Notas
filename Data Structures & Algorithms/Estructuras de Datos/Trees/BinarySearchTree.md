# Binary Search Tree (BST) — Búsqueda Eficiente en Árboles

> **Idea central:** Un array ordenado permite búsqueda binaria O(log n), pero insertar/eliminar cuesta O(n).
> Una linked list permite insertar/eliminar O(1), pero buscar cuesta O(n).
> El **BST** fusiona ambas ventajas: búsqueda, inserción y eliminación en **O(log n)** — cuando está balanceado.
> Es la primera estructura que ofrece **las tres operaciones** de forma eficiente.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Definición Formal](#1-definición-formal)
2. [Propiedad BST (Invariante de Orden)](#2-propiedad-bst-invariante-de-orden)
3. [Representación en Memoria](#3-representación-en-memoria)
4. [BST e Inorder Traversal](#4-bst-e-inorder-traversal)

**Parte II — Operaciones**
5. [Búsqueda (Search)](#5-búsqueda-search)
6. [Inserción (Insert)](#6-inserción-insert)
7. [Eliminación (Delete)](#7-eliminación-delete)
8. [Min, Max, Sucesor, Predecesor](#8-min-max-sucesor-predecesor)

**Parte III — Construcción**
9. [Construir BST desde Preorder](#9-construir-bst-desde-preorder)

**Parte IV — Análisis y Limitaciones**
10. [Complejidad: Mejor, Promedio y Peor Caso](#10-complejidad-mejor-promedio-y-peor-caso)
11. [Árboles Degenerados](#11-árboles-degenerados)
12. [Comparación con Otras Estructuras](#12-comparación-con-otras-estructuras)

**Parte V — Síntesis**
13. [Resumen de Complejidad](#13-resumen-de-complejidad)
14. [Errores Comunes y Buenas Prácticas](#14-errores-comunes-y-buenas-prácticas)
15. [Intuición de Ingeniería](#15-intuición-de-ingeniería)
16. [Ejercicios Sugeridos](#16-ejercicios-sugeridos)

---

# PARTE I — FUNDAMENTOS

---

# 1. Definición Formal

## 1.1 ¿Qué es un BST?

Un **Binary Search Tree** es un árbol binario donde **cada nodo** satisface la siguiente propiedad:

> Para todo nodo N:
> - Todos los valores en el **subárbol izquierdo** de N son **menores** que N.
> - Todos los valores en el **subárbol derecho** de N son **mayores** que N.

```text
           30
          /  \
        15    50
       / \   / \
      10  20 40  60

Verificación:
  30: izq={10,15,20} < 30, der={40,50,60} > 30  ✓
  15: izq={10} < 15, der={20} > 15               ✓
  50: izq={40} < 50, der={60} > 50               ✓
  10, 20, 40, 60: hojas → trivialmente ✓
```

## 1.2 Definición recursiva

```text
BST = vacío
    | (valor, BST_izq, BST_der)
      donde: ∀x ∈ BST_izq: x < valor
             ∀x ∈ BST_der: x > valor
```

> **Nota sobre duplicados:** La definición clásica **no permite duplicados**. Si se necesitan:
> - Convención 1: duplicados van a la **izquierda** (≤ en vez de <)
> - Convención 2: duplicados van a la **derecha** (≥ en vez de >)
> - Convención 3: cada nodo almacena un **contador** de repeticiones
>
> En este módulo usamos la convención estricta: **sin duplicados**.

## 1.3 ¿Qué NO es un BST?

```text
✅ BST válido:          ❌ NO es BST:

       20                    20
      /  \                  /  \
    10    30              10    30
   / \                   / \
  5   15                5   25     ← 25 > 20 pero está en subárbol izq!

En el árbol derecho:
  25 está en el subárbol izquierdo de 20,
  pero 25 > 20 → viola la propiedad BST.

La propiedad debe cumplirse para TODO el subárbol, no solo hijos directos.
```

---

# 2. Propiedad BST (Invariante de Orden)

## 2.1 El invariante

La propiedad BST es un **invariante**: debe ser verdadera **antes y después** de cada operación.

```text
Invariante BST:
  Para cada nodo N con valor v:
    ∀ nodo X en subárbol izquierdo: X.valor < v
    ∀ nodo Y en subárbol derecho:   Y.valor > v
```

## 2.2 ¿Por qué es poderoso?

Este invariante nos da una **regla de decisión** en cada nodo:

```text
Buscando valor K, estoy en nodo con valor V:

  K == V → ¡Encontrado!
  K < V  → K solo puede estar a la IZQUIERDA (descartar derecha)
  K > V  → K solo puede estar a la DERECHA (descartar izquierda)

En cada paso descartamos la MITAD del árbol (si está balanceado).
→ Es binary search, pero sobre una estructura de árbol.
```

## 2.3 BST como extensión de Binary Search

| Concepto         | Binary Search (array) | BST (árbol)          |
| ---------------- | --------------------- | -------------------- |
| Estructura       | Array ordenado        | Árbol con orden      |
| Búsqueda         | O(log n)              | O(h)                 |
| Inserción        | O(n) — shift          | **O(h)** — enlazar   |
| Eliminación      | O(n) — shift          | **O(h)** — enlazar   |
| h (balanceado)   | —                     | O(log n)             |
| h (degenerado)   | —                     | O(n)                 |

> El BST **es** binary search transformado en estructura dinámica.

---

# 3. Representación en Memoria

## 3.1 Estructura del nodo

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct BSTNode {
    int data;
    struct BSTNode *left;
    struct BSTNode *right;
} BSTNode;

BSTNode* createNode(int value) {
    BSTNode *node = (BSTNode*)malloc(sizeof(BSTNode));
    node->data = value;
    node->left = NULL;
    node->right = NULL;
    return node;
}
```

## 3.2 Visualización en memoria

```text
BST:           30
              /  \
            15    50

Heap memory:
  0x100: [NULL  | 15 | NULL ]     → nodo 15 (hoja)
  0x200: [NULL  | 50 | NULL ]     → nodo 50 (hoja)
  0x300: [0x100 | 30 | 0x200]     → nodo 30 (raíz): left→15, right→50

Variable en stack:
  BSTNode *root = 0x300;
```

## 3.3 ¿Por qué punteros y no array?

| Aspecto          | Array                    | Punteros (linked)       |
| ---------------- | ------------------------ | ----------------------- |
| Inserción        | Reordenar → O(n)         | Enlazar → O(h)          |
| Eliminación      | Reordenar → O(n)         | Reenlazar → O(h)        |
| Forma dinámica   | Tamaño fijo              | Crece sin límite        |
| Desperdicio       | Sí (si desbalanceado)   | No                      |

> **BST siempre se implementa con nodos/punteros**, no con arrays.

---

# 4. BST e Inorder Traversal

## 4.1 La propiedad fundamental

> El **recorrido inorder** de un BST produce los elementos **en orden ascendente**.

```text
BST:           30
              /  \
            15    50
           / \   / \
          10  20 40  60

Inorder (L → N → R):
  10 → 15 → 20 → 30 → 40 → 50 → 60

¡Orden ascendente!
```

### ¿Por qué?

```text
Inorder visita: todo el subárbol izquierdo, luego el nodo, luego todo el derecho.
BST dice:       izquierdo < nodo < derecho.
Combinados:     valores menores, luego el valor, luego valores mayores = ORDENADO.
```

## 4.2 Verificar si un árbol es BST

```c
// Usar inorder: si cada valor es mayor que el anterior → es BST
int isBSTHelper(BSTNode *root, int *prev) {
    if (root == NULL) return 1;

    if (!isBSTHelper(root->left, prev)) return 0;

    if (*prev >= root->data) return 0;   // no es estrictamente creciente
    *prev = root->data;

    return isBSTHelper(root->right, prev);
}

int isBST(BSTNode *root) {
    int prev = -2147483648;     // INT_MIN
    return isBSTHelper(root, &prev);
}
```

```text
Traza con BST válido (10, 15, 20, 30, 40, 50, 60):
  prev = INT_MIN
  visit 10: INT_MIN < 10 ✓, prev = 10
  visit 15: 10 < 15 ✓, prev = 15
  visit 20: 15 < 20 ✓, prev = 20
  visit 30: 20 < 30 ✓, prev = 30
  ...
  Todos crecientes → es BST ✓
```

---

# PARTE II — OPERACIONES

---

# 5. Búsqueda (Search)

## 5.1 Algoritmo

```text
search(root, key):
  1. Si root == NULL → no encontrado.
  2. Si key == root.data → ¡encontrado!
  3. Si key < root.data → buscar en root.left
  4. Si key > root.data → buscar en root.right
```

## 5.2 Ejemplo paso a paso

```text
BST:           30
              /  \
            15    50
           / \   / \
          10  20 40  60

Buscar 40:
  Nodo 30: 40 > 30 → ir a la derecha
  Nodo 50: 40 < 50 → ir a la izquierda
  Nodo 40: 40 == 40 → ¡Encontrado! ✓

Buscar 25:
  Nodo 30: 25 < 30 → ir a la izquierda
  Nodo 15: 25 > 15 → ir a la derecha
  Nodo 20: 25 > 20 → ir a la derecha
  NULL → No encontrado ✗

Comparaciones: 3 (profundidad del nodo + 1)
```

## 5.3 Implementación iterativa

```c
BSTNode* searchIterative(BSTNode *root, int key) {
    while (root != NULL) {
        if (key == root->data)
            return root;            // encontrado
        else if (key < root->data)
            root = root->left;      // ir izquierda
        else
            root = root->right;     // ir derecha
    }
    return NULL;                    // no encontrado
}
```

```text
Traza searchIterative(root, 40):

  root → 30: 40 > 30 → root = root->right
  root → 50: 40 < 50 → root = root->left
  root → 40: 40 == 40 → return root  ✓
```

## 5.4 Implementación recursiva

```c
BSTNode* searchRecursive(BSTNode *root, int key) {
    if (root == NULL)
        return NULL;            // caso base: no encontrado

    if (key == root->data)
        return root;            // caso base: encontrado
    else if (key < root->data)
        return searchRecursive(root->left, key);
    else
        return searchRecursive(root->right, key);
}
```

## 5.5 Análisis

| Caso           | Comparaciones | Forma del árbol            |
| -------------- | ------------- | -------------------------- |
| **Mejor**      | O(1)          | El nodo buscado es la raíz |
| **Promedio**   | O(log n)      | Árbol balanceado           |
| **Peor**       | O(n)          | Árbol degenerado (cadena)  |

| Aspecto    | Iterativo | Recursivo |
| ---------- | --------- | --------- |
| Tiempo     | O(h)      | O(h)      |
| Espacio    | **O(1)**  | O(h) — call stack |
| Claridad   | Más código| Más elegante |

> **h** = altura del árbol. En un BST balanceado: h ≈ log₂(n). En uno degenerado: h = n − 1.

---

# 6. Inserción (Insert)

## 6.1 Algoritmo

```text
insert(root, value):
  1. Si root == NULL → crear nodo con value, retornarlo como nueva raíz.
  2. Si value < root.data → root.left = insert(root.left, value)
  3. Si value > root.data → root.right = insert(root.right, value)
  4. Si value == root.data → duplicado (ignorar o manejar según convención).
  5. Retornar root.
```

> **Clave:** La inserción en BST **siempre crea una hoja**. Nunca se inserta en el medio.

## 6.2 Ejemplo paso a paso

```text
Insertar secuencia: 30, 15, 50, 10, 20, 40, 60

1. insert(30): árbol vacío → 30 es la raíz.
       30

2. insert(15): 15 < 30 → izquierda de 30.
       30
      /
    15

3. insert(50): 50 > 30 → derecha de 30.
       30
      /  \
    15    50

4. insert(10): 10 < 30 → izq; 10 < 15 → izq de 15.
       30
      /  \
    15    50
   /
  10

5. insert(20): 20 < 30 → izq; 20 > 15 → der de 15.
       30
      /  \
    15    50
   / \
  10  20

6. insert(40): 40 > 30 → der; 40 < 50 → izq de 50.
       30
      /  \
    15    50
   / \   /
  10  20 40

7. insert(60): 60 > 30 → der; 60 > 50 → der de 50.
       30
      /  \
    15    50
   / \   / \
  10  20 40  60
```

## 6.3 Implementación recursiva

```c
BSTNode* insertRecursive(BSTNode *root, int value) {
    if (root == NULL)
        return createNode(value);       // caso base: crear hoja

    if (value < root->data)
        root->left = insertRecursive(root->left, value);
    else if (value > root->data)
        root->right = insertRecursive(root->right, value);
    // else: value == root->data → duplicado, ignorar

    return root;
}
```

```text
Traza insertRecursive(root, 25) con el BST anterior:

  insert(30, 25): 25 < 30 → root->left = insert(15, 25)
    insert(15, 25): 25 > 15 → root->right = insert(20, 25)
      insert(20, 25): 25 > 20 → root->right = insert(NULL, 25)
        insert(NULL, 25): return createNode(25)
      20->right = nodo(25). return 20.
    15->right = 20 (sin cambio). return 15.
  30->left = 15 (sin cambio). return 30.

Resultado:
       30
      /  \
    15    50
   / \   / \
  10  20 40  60
        \
        25    ← nuevo nodo (hoja)
```

## 6.4 Implementación iterativa

```c
BSTNode* insertIterative(BSTNode *root, int value) {
    BSTNode *newNode = createNode(value);

    if (root == NULL)
        return newNode;

    BSTNode *curr = root;
    BSTNode *parent = NULL;

    while (curr != NULL) {
        parent = curr;
        if (value < curr->data)
            curr = curr->left;
        else if (value > curr->data)
            curr = curr->right;
        else {
            free(newNode);      // duplicado: liberar nodo creado
            return root;
        }
    }

    // curr == NULL → parent es donde debemos colgar el nodo
    if (value < parent->data)
        parent->left = newNode;
    else
        parent->right = newNode;

    return root;
}
```

```text
Traza insertIterative(root, 25):

  curr=30, parent=NULL: 25 < 30 → curr = left(15)
  curr=15, parent=30:   25 > 15 → curr = right(20)
  curr=20, parent=15:   25 > 20 → curr = right(NULL)
  curr=NULL, parent=20: 25 > 20 → parent->right = newNode(25)
```

## 6.5 Análisis

| Caso           | Tiempo    | Descripción                           |
| -------------- | --------- | ------------------------------------- |
| **Mejor**      | O(1)      | Insertar en árbol vacío               |
| **Promedio**   | O(log n)  | Árbol balanceado                      |
| **Peor**       | O(n)      | Insertar en orden (cadena)            |

| Aspecto    | Recursivo     | Iterativo      |
| ---------- | ------------- | -------------- |
| Tiempo     | O(h)          | O(h)           |
| Espacio    | O(h) — stack  | **O(1)**       |
| Elegancia  | Alta          | Media          |

## 6.6 Impacto del orden de inserción

```text
Insertar: 30, 15, 50, 10, 20, 40, 60     Insertar: 10, 15, 20, 30, 40, 50, 60

       30                                   10
      /  \                                    \
    15    50            vs                     15
   / \   / \                                     \
  10  20 40  60                                   20
                                                    \
  h = 2 (balanceado)                                 30
  Operaciones: O(log n)                                \
                                                       40
                                                         \
                                                          50
                                                            \
                                                             60

                                               h = 6 (degenerado)
                                               Operaciones: O(n)
```

> **El mismo conjunto de datos puede dar árboles radicalmente diferentes según el orden de inserción.**

---

# 7. Eliminación (Delete)

## 7.1 Los tres casos

La eliminación es la operación más compleja del BST porque debe **mantener el invariante** después de remover un nodo.

```text
Caso 1: Nodo hoja (0 hijos)        → Simplemente eliminarlo.
Caso 2: Nodo con 1 hijo            → Reemplazar con su hijo.
Caso 3: Nodo con 2 hijos           → Reemplazar con sucesor inorder
                                      (o predecesor inorder).
```

## 7.2 Caso 1 — Nodo hoja (sin hijos)

```text
Eliminar 20:

  Antes:          Después:
       30              30
      /  \            /  \
    15    50        15    50
   / \   / \       /     / \
  10  20 40  60   10    40  60

20 es hoja → simplemente poner el puntero del padre a NULL y free(20).
```

## 7.3 Caso 2 — Nodo con un hijo

```text
Eliminar 15 (tiene solo hijo izquierdo = 10):

  Antes:          Después:
       30              30
      /  \            /  \
    15    50        10    50
   /     / \             / \
  10    40  60          40  60

15 tiene 1 hijo (10) → reemplazar 15 por su hijo 10.
El padre de 15 (30) ahora apunta a 10.
```

```text
Eliminar 50 (tiene hijos 40 y 60):  ← ESTO NO ES caso 2, es caso 3.

Otro ejemplo caso 2:
Eliminar 50 cuando solo tiene un hijo:

       30                   30
      /  \                 /  \
    15    50             15    60
           \
            60

50 tiene 1 hijo (60) → reemplazar 50 por 60.
```

## 7.4 Caso 3 — Nodo con dos hijos

**Problema:** No podemos simplemente borrar el nodo — ¿quién toma su lugar?

**Solución:** Reemplazar el nodo con su **sucesor inorder** (el menor valor del subárbol derecho) o su **predecesor inorder** (el mayor valor del subárbol izquierdo).

### ¿Por qué el sucesor inorder?

```text
El sucesor inorder de un nodo N es el MENOR valor MAYOR que N.
→ Es el nodo más a la izquierda del subárbol derecho.
→ Garantiza que el invariante BST se mantiene al reemplazar.
```

### Ejemplo paso a paso

```text
Eliminar 30 (raíz, tiene 2 hijos):

       30                     ?
      /  \                   / \
    15    50               15   50
   / \   / \              / \  / \
  10  20 40  60          10 20 ? 60

Sucesor inorder de 30 = menor del subárbol derecho:
  Subárbol derecho de 30: {40, 50, 60}
  Menor = 40 (nodo más a la izquierda)

Paso 1: Copiar valor 40 al nodo 30.
Paso 2: Eliminar el nodo 40 original del subárbol derecho.
         (40 es hoja o tiene máximo 1 hijo derecho → caso 1 o 2)

Resultado:
       40
      /  \
    15    50
   / \      \
  10  20     60

Verificar BST:
  40: izq={10,15,20} < 40, der={50,60} > 40  ✓
  15: izq={10} < 15, der={20} > 15            ✓
  50: der={60} > 50                           ✓  ✓
```

### Alternativa: Predecesor inorder

```text
Predecesor inorder de 30 = mayor del subárbol izquierdo:
  Subárbol izquierdo de 30: {10, 15, 20}
  Mayor = 20 (nodo más a la derecha)

Resultado usando predecesor:
       20
      /  \
    15    50
   /     / \
  10    40  60

También válido.
```

## 7.5 Encontrar el sucesor inorder

```c
// El sucesor inorder es el nodo más a la izquierda del subárbol derecho
BSTNode* inorderSuccessor(BSTNode *node) {
    BSTNode *curr = node;
    while (curr->left != NULL)
        curr = curr->left;
    return curr;
}
```

```text
Encontrar sucesor de 30:
  Subárbol derecho de 30 → nodo 50
  Ir a la izquierda desde 50 → nodo 40
  40->left == NULL → 40 es el sucesor ✓
```

## 7.6 Implementación recursiva de Delete

```c
BSTNode* deleteRecursive(BSTNode *root, int key) {
    // Caso base: nodo no encontrado
    if (root == NULL)
        return NULL;

    // Buscar el nodo a eliminar
    if (key < root->data) {
        root->left = deleteRecursive(root->left, key);
    } else if (key > root->data) {
        root->right = deleteRecursive(root->right, key);
    } else {
        // ¡Encontrado! root es el nodo a eliminar.

        // Caso 1: Hoja (0 hijos)
        if (root->left == NULL && root->right == NULL) {
            free(root);
            return NULL;
        }

        // Caso 2a: Solo hijo derecho
        if (root->left == NULL) {
            BSTNode *temp = root->right;
            free(root);
            return temp;
        }

        // Caso 2b: Solo hijo izquierdo
        if (root->right == NULL) {
            BSTNode *temp = root->left;
            free(root);
            return temp;
        }

        // Caso 3: Dos hijos
        // Encontrar sucesor inorder (menor del subárbol derecho)
        BSTNode *successor = inorderSuccessor(root->right);

        // Copiar el valor del sucesor al nodo actual
        root->data = successor->data;

        // Eliminar el sucesor del subárbol derecho
        root->right = deleteRecursive(root->right, successor->data);
    }

    return root;
}
```

### Traza completa: eliminar 30

```text
BST inicial:
       30
      /  \
    15    50
   / \   / \
  10  20 40  60

deleteRecursive(root=30, key=30):
  key == root->data → ¡encontrado!
  root tiene 2 hijos → Caso 3.
  sucesor = inorderSuccessor(root->right = 50)
          → ir a la izquierda de 50 → 40
          → 40->left == NULL → sucesor = 40

  root->data = 40    (copiar valor del sucesor)

  Estado temporal:
       40              ← valor cambiado
      /  \
    15    50
   / \   / \
  10  20 40  60         ← 40 duplicado, hay que eliminarlo

  root->right = deleteRecursive(50, 40)
    → 40 < 50 → left = deleteRecursive(40, 40)
      → 40 == 40 → ¡encontrado!
      → 40 es hoja → free(40), return NULL
    → 50->left = NULL
    → return 50

  Resultado final:
       40
      /  \
    15    50
   / \      \
  10  20     60       ✓ BST válido
```

## 7.7 Implementación iterativa de Delete

```c
BSTNode* deleteIterative(BSTNode *root, int key) {
    BSTNode *parent = NULL;
    BSTNode *curr = root;

    // Buscar el nodo a eliminar
    while (curr != NULL && curr->data != key) {
        parent = curr;
        if (key < curr->data)
            curr = curr->left;
        else
            curr = curr->right;
    }

    if (curr == NULL)
        return root;    // no encontrado

    // Caso 3: Dos hijos → reducir a caso 1 o 2
    if (curr->left != NULL && curr->right != NULL) {
        // Encontrar sucesor inorder y su padre
        BSTNode *succParent = curr;
        BSTNode *succ = curr->right;
        while (succ->left != NULL) {
            succParent = succ;
            succ = succ->left;
        }

        // Copiar valor
        curr->data = succ->data;

        // Ahora eliminar el sucesor (tiene 0 o 1 hijo)
        curr = succ;
        parent = succParent;
    }

    // Caso 1 o 2: curr tiene 0 o 1 hijo
    BSTNode *child = (curr->left != NULL) ? curr->left : curr->right;

    if (parent == NULL) {
        // Eliminar la raíz
        free(curr);
        return child;
    }

    if (curr == parent->left)
        parent->left = child;
    else
        parent->right = child;

    free(curr);
    return root;
}
```

## 7.8 Análisis de Delete

| Caso              | Tiempo | Descripción                        |
| ----------------- | ------ | ---------------------------------- |
| **Hoja**          | O(h)   | Buscar + free                      |
| **1 hijo**        | O(h)   | Buscar + reenlazar                 |
| **2 hijos**       | O(h)   | Buscar + encontrar sucesor + delete sucesor |
| **Promedio**      | O(log n) | Árbol balanceado                 |
| **Peor**          | O(n)   | Árbol degenerado                   |

| Aspecto    | Recursivo     | Iterativo      |
| ---------- | ------------- | -------------- |
| Tiempo     | O(h)          | O(h)           |
| Espacio    | O(h)          | **O(1)**       |
| Claridad   | Más clara     | Más código     |

## 7.9 Resumen visual de los 3 casos

```text
┌─────────────────────────────────────────────────────────────┐
│                    DELETE EN BST                             │
├──────────────┬──────────────────────────────────────────────┤
│ Caso 1       │ Hoja: free(nodo), parent→NULL                │
│ (0 hijos)    │                                              │
├──────────────┼──────────────────────────────────────────────┤
│ Caso 2       │ 1 hijo: parent apunta al hijo del nodo       │
│ (1 hijo)     │ eliminado. free(nodo).                       │
├──────────────┼──────────────────────────────────────────────┤
│ Caso 3       │ 2 hijos:                                     │
│ (2 hijos)    │  1. Encontrar sucesor inorder (min del der)  │
│              │  2. Copiar valor del sucesor al nodo          │
│              │  3. Eliminar sucesor (caso 1 o 2)            │
└──────────────┴──────────────────────────────────────────────┘
```

---

# 8. Min, Max, Sucesor, Predecesor

## 8.1 Mínimo

El nodo con el valor mínimo está en el nodo **más a la izquierda**.

```c
// Iterativo
BSTNode* findMin(BSTNode *root) {
    if (root == NULL) return NULL;
    while (root->left != NULL)
        root = root->left;
    return root;
}

// Recursivo
BSTNode* findMinRec(BSTNode *root) {
    if (root == NULL) return NULL;
    if (root->left == NULL) return root;
    return findMinRec(root->left);
}
```

```text
       30
      /  \
    15    50
   / \   / \
  10  20 40  60

findMin: 30 → 15 → 10 → left=NULL → return 10  ✓
```

## 8.2 Máximo

El nodo con el valor máximo está en el nodo **más a la derecha**.

```c
BSTNode* findMax(BSTNode *root) {
    if (root == NULL) return NULL;
    while (root->right != NULL)
        root = root->right;
    return root;
}
```

```text
findMax: 30 → 50 → 60 → right=NULL → return 60  ✓
```

## 8.3 Sucesor Inorder

El **sucesor inorder** de un nodo N es el nodo con el **menor valor mayor que N**.

```text
Dos casos:
  1. N tiene subárbol derecho → sucesor = mínimo del subárbol derecho.
  2. N NO tiene subárbol derecho → sucesor = el ancestro más bajo
     cuyo subárbol izquierdo contiene a N.
```

```c
// Si tenemos puntero al padre:
BSTNode* inorderSuccessorWithParent(BSTNode *node) {
    // Caso 1: tiene subárbol derecho
    if (node->right != NULL)
        return findMin(node->right);

    // Caso 2: subir hasta encontrar un ancestro del cual somos hijo izquierdo
    BSTNode *parent = node->parent;    // requiere campo parent
    while (parent != NULL && node == parent->right) {
        node = parent;
        parent = parent->parent;
    }
    return parent;
}
```

```text
       30
      /  \
    15    50
   / \   / \
  10  20 40  60

Sucesor de 20:
  20 no tiene subárbol derecho.
  Subir: 20 es hijo derecho de 15 → seguir subiendo.
  15 es hijo izquierdo de 30 → sucesor = 30.  ✓
  (En inorder: 10,15,20,30,40,50,60 → después de 20 viene 30)

Sucesor de 15:
  15 tiene subárbol derecho → min(subárbol der) = min({20}) = 20.  ✓

Sucesor de 60:
  60 no tiene subárbol derecho.
  Subir: 60 es hijo derecho de 50 → seguir.
  50 es hijo derecho de 30 → seguir.
  30 no tiene padre → sucesor = NULL (60 es el máximo).  ✓
```

## 8.4 Predecesor Inorder

El **predecesor inorder** es simétrico: el nodo con el **mayor valor menor que N**.

```text
  1. N tiene subárbol izquierdo → predecesor = máximo del subárbol izquierdo.
  2. N NO tiene subárbol izquierdo → subir hasta ancestro cuyo hijo derecho contiene a N.
```

## 8.5 Análisis

| Operación        | Tiempo  | Nota                               |
| ---------------- | ------- | ---------------------------------- |
| findMin          | O(h)    | Ir todo a la izquierda             |
| findMax          | O(h)    | Ir todo a la derecha               |
| Sucesor inorder  | O(h)    | Caso 1: findMin(right). Caso 2: subir. |
| Predecesor       | O(h)    | Simétrico al sucesor               |

---

# PARTE III — CONSTRUCCIÓN

---

# 9. Construir BST desde Preorder

## 9.1 El problema

```text
Dado un array con el recorrido preorder de un BST, reconstruir el árbol.

Preorder: [30, 15, 10, 20, 50, 40, 60]
→ Construir el BST original.
```

> **Recordatorio:** Preorder = Raíz → Izquierda → Derecha.
> El **primer elemento** siempre es la **raíz**.

## 9.2 Método 1: Inserción secuencial — O(n²)

Simplemente insertar cada elemento del preorder en un BST vacío.

```c
BSTNode* buildFromPreorderNaive(int preorder[], int n) {
    BSTNode *root = NULL;
    for (int i = 0; i < n; i++)
        root = insertRecursive(root, preorder[i]);
    return root;
}
```

```text
Preorder: [30, 15, 10, 20, 50, 40, 60]

insert(30): raíz
insert(15): izq de 30
insert(10): izq de 15
insert(20): der de 15
insert(50): der de 30
insert(40): izq de 50
insert(60): der de 50

       30
      /  \
    15    50
   / \   / \
  10  20 40  60    ✓
```

**Complejidad:** Cada inserción cuesta O(h). En el mejor caso O(n log n). En el peor (preorder ya ordenado → cadena): O(n²).

## 9.3 Método 2: Usando rango de valores — O(n)

**Idea:** Usar la propiedad BST para decidir dónde va cada nodo **sin buscarlo**. Mantenemos un rango [min, max] para cada posición.

```text
Algoritmo:
  1. Mantener un índice global preIdx que recorre el preorder.
  2. Para cada llamada recursiva, definir rango (min, max).
  3. Si preorder[preIdx] está en rango → crear nodo, avanzar preIdx.
  4. Construir izquierdo (rango [min, valor-1]).
  5. Construir derecho (rango [valor+1, max]).
  6. Si preorder[preIdx] NO está en rango → return NULL.
```

### Implementación

```c
BSTNode* buildFromPreHelper(int preorder[], int n, int *preIdx,
                             int minVal, int maxVal) {
    if (*preIdx >= n)
        return NULL;

    int val = preorder[*preIdx];

    // Si el valor no está en el rango válido, no pertenece a este subárbol
    if (val < minVal || val > maxVal)
        return NULL;

    // Crear nodo y avanzar
    BSTNode *node = createNode(val);
    (*preIdx)++;

    // Construir subárboles con rangos apropiados
    node->left  = buildFromPreHelper(preorder, n, preIdx, minVal, val - 1);
    node->right = buildFromPreHelper(preorder, n, preIdx, val + 1, maxVal);

    return node;
}

BSTNode* buildFromPreorder(int preorder[], int n) {
    int preIdx = 0;
    return buildFromPreHelper(preorder, n, &preIdx, -2147483648, 2147483647);
}
```

### Traza paso a paso

```text
Preorder: [30, 15, 10, 20, 50, 40, 60]
preIdx = 0

buildHelper(preIdx=0, min=INT_MIN, max=INT_MAX):
  val=30, en rango → crear nodo(30), preIdx=1

  left = buildHelper(preIdx=1, min=INT_MIN, max=29):
    val=15, 15 ≤ 29 → crear nodo(15), preIdx=2

    left = buildHelper(preIdx=2, min=INT_MIN, max=14):
      val=10, 10 ≤ 14 → crear nodo(10), preIdx=3
      left = buildHelper(preIdx=3, min=INT_MIN, max=9):
        val=20, 20 > 9 → return NULL
      right = buildHelper(preIdx=3, min=11, max=14):
        val=20, 20 > 14 → return NULL
      return nodo(10)

    right = buildHelper(preIdx=3, min=16, max=29):
      val=20, 16 ≤ 20 ≤ 29 → crear nodo(20), preIdx=4
      left = buildHelper(preIdx=4, min=16, max=19):
        val=50, 50 > 19 → return NULL
      right = buildHelper(preIdx=4, min=21, max=29):
        val=50, 50 > 29 → return NULL
      return nodo(20)

    return nodo(15){left=10, right=20}

  right = buildHelper(preIdx=4, min=31, max=INT_MAX):
    val=50, 50 ≥ 31 → crear nodo(50), preIdx=5

    left = buildHelper(preIdx=5, min=31, max=49):
      val=40, 31 ≤ 40 ≤ 49 → crear nodo(40), preIdx=6
      left, right → NULL
      return nodo(40)

    right = buildHelper(preIdx=6, min=51, max=INT_MAX):
      val=60, 60 ≥ 51 → crear nodo(60), preIdx=7
      left, right → NULL
      return nodo(60)

    return nodo(50){left=40, right=60}

  return nodo(30){left=15, right=50}

Resultado:
       30
      /  \
    15    50
   / \   / \
  10  20 40  60    ✓
```

### Comparación de métodos

| Método                  | Tiempo     | Espacio | Nota                            |
| ----------------------- | ---------- | ------- | ------------------------------- |
| Inserción secuencial    | O(n log n) a O(n²) | O(h) | Simple, pero lento para secuencias ordenadas |
| **Rango de valores**    | **O(n)**   | O(h)   | Cada nodo se procesa exactamente una vez |

---

# PARTE IV — ANÁLISIS Y LIMITACIONES

---

# 10. Complejidad: Mejor, Promedio y Peor Caso

## 10.1 Las tres formas de un BST

```text
n = 7, valores = {10, 15, 20, 30, 40, 50, 60}

Mejor caso (balanceado):        Caso promedio:         Peor caso (degenerado):

       30                           20                   10
      /  \                         /  \                    \
    15    50                     15    40                   15
   / \   / \                    /    /  \                     \
  10  20 40  60               10   30    50                   20
                                           \                    \
                                            60                   30
                                                                   \
  h = 2                       h = 3                                 40
  Ops = O(log n)              Ops = O(log n)                          \
                                                                       50
                                                                         \
                                                                          60
                                                               h = 6
                                                               Ops = O(n)
```

## 10.2 Análisis formal

| Caso            | Altura h        | Search / Insert / Delete |
| --------------- | --------------- | ------------------------ |
| **Mejor**       | h = ⌊log₂(n)⌋  | O(log n)                 |
| **Promedio**    | h ≈ 1.39 log₂(n)| O(log n)                |
| **Peor**        | h = n − 1       | **O(n)**                 |

> **Promedio:** Si insertamos n claves aleatorias, la altura esperada es ~1.39 log₂(n), que sigue siendo O(log n).

## 10.3 ¿Cuándo ocurre el peor caso?

```text
Insertar datos ya ordenados (ascendente o descendente):

  insert(10): 10
  insert(15): 10→15
  insert(20): 10→15→20
  insert(30): 10→15→20→30

→ El BST se convierte en una linked list.
   Todas las operaciones pasan de O(log n) a O(n).
```

---

# 11. Árboles Degenerados

## 11.1 El problema

Un BST degenerado es un árbol donde **cada nodo tiene como máximo 1 hijo**, formando una **cadena lineal**.

```text
BST degenerado (skewed right):    BST degenerado (skewed left):

  10                                    60
    \                                  /
     15                              50
       \                            /
        20                        40
          \                      /
           30                  30
             \                /
              40            20
                \          /
                 50      15
                   \    /
                    60 10

h = n - 1 = 6
Espacio: O(n) — igual que linked list
Operaciones: O(n) — igual que linked list
```

## 11.2 ¿Por qué es un problema grave?

| Operación | BST balanceado | BST degenerado | Linked List |
| --------- | -------------- | -------------- | ----------- |
| Search    | O(log n)       | **O(n)**       | O(n)        |
| Insert    | O(log n)       | **O(n)**       | O(n)        |
| Delete    | O(log n)       | **O(n)**       | O(n)        |

> Un BST degenerado **es** una linked list. Perdemos toda ventaja del árbol.

## 11.3 ¿Cómo evitarlo?

La solución es usar **árboles auto-balanceados** que mantienen h = O(log n) automáticamente:

| Estructura            | Garantía de altura | Mecanismo                     |
| --------------------- | ------------------ | ----------------------------- |
| **AVL Tree**          | h ≤ 1.44 log₂(n)  | Factor de balance ≤ 1; rotaciones |
| **Red-Black Tree**    | h ≤ 2 log₂(n+1)   | Colores + reglas; rotaciones  |
| **B-Tree**            | h = O(log_m n)     | Múltiples claves por nodo     |
| **Splay Tree**        | O(log n) amortizado| Rotaciones al acceder          |

> Estos árboles se estudian en módulos posteriores. El BST es la base sobre la que todos se construyen.

---

# 12. Comparación con Otras Estructuras

## 12.1 Tabla comparativa

| Estructura          | Search     | Insert     | Delete     | Espacio | Nota                       |
| ------------------- | ---------- | ---------- | ---------- | ------- | -------------------------- |
| **Array desordenado** | O(n)     | O(1)       | O(n)       | O(n)    | Inserción rápida, todo lo demás lento |
| **Array ordenado**  | **O(log n)** | O(n)    | O(n)       | O(n)    | Búsqueda rápida, insertar/eliminar lento |
| **Linked List**     | O(n)       | O(1)       | O(n)*      | O(n)    | *O(1) si tienes el puntero |
| **BST (balanceado)**| O(log n)   | O(log n)   | O(log n)   | O(n)    | Lo mejor de ambos mundos   |
| **BST (degenerado)**| O(n)       | O(n)       | O(n)       | O(n)    | Pierde toda ventaja        |
| **Hash Table**      | O(1) avg   | O(1) avg   | O(1) avg   | O(n)    | Más rápido, pero sin orden |

## 12.2 ¿Cuándo usar BST vs Hash Table?

| Necesito...                          | BST             | Hash Table    |
| ------------------------------------ | --------------- | ------------- |
| Buscar un elemento                   | O(log n)        | **O(1)**      |
| Insertar/eliminar                    | O(log n)        | **O(1)**      |
| Encontrar min/max                    | **O(h)**        | O(n)          |
| Recorrer en orden                    | **O(n) inorder**| O(n log n)*   |
| Range query (valores entre A y B)    | **O(h + k)**    | O(n)          |
| Sucesor/predecesor                   | **O(h)**        | O(n)          |

> *Hash table no tiene orden → necesitas extraer y ordenar.

**Regla:**
- Si solo necesitas **buscar/insertar/eliminar** → Hash Table.
- Si necesitas **orden, rangos, min/max, sucesor** → BST.

---

# PARTE V — SÍNTESIS

---

# 13. Resumen de Complejidad

## 13.1 Operaciones BST

| Operación              | Mejor    | Promedio   | Peor     | Espacio (rec) |
| ---------------------- | -------- | ---------- | -------- | ------------- |
| **Search**             | O(1)     | O(log n)   | O(n)     | O(h) / O(1)  |
| **Insert**             | O(1)     | O(log n)   | O(n)     | O(h) / O(1)  |
| **Delete**             | O(log n) | O(log n)   | O(n)     | O(h) / O(1)  |
| **findMin / findMax**  | O(1)     | O(log n)   | O(n)     | O(1)          |
| **Sucesor / Predecesor**| O(1)    | O(log n)   | O(n)     | O(1)          |
| **Inorder Traversal**  | O(n)     | O(n)       | O(n)     | O(h)          |
| **Build from Preorder (naive)** | O(n log n) | O(n log n) | O(n²) | O(h) |
| **Build from Preorder (range)** | O(n) | O(n)  | O(n)     | O(h)          |

```text
h (altura):
  Balanceado:  h = O(log n)  →  operaciones O(log n)
  Degenerado:  h = O(n)      →  operaciones O(n)
```

## 13.2 Recursivo vs Iterativo

| Operación | Recursivo: Espacio | Iterativo: Espacio | Recomendación         |
| --------- | ------------------ | ------------------ | --------------------- |
| Search    | O(h) — stack       | **O(1)**           | Iterativo              |
| Insert    | O(h) — stack       | **O(1)**           | Recursivo (más claro) |
| Delete    | O(h) — stack       | **O(1)**           | Recursivo (más claro) |

---

# 14. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                                       | Consecuencia                            |
| ----------------------------------------------------------- | --------------------------------------- |
| Verificar BST solo con hijos directos (no subárboles)       | Acepta árboles inválidos                |
| Olvidar `return root` al final de insert/delete recursivo   | Pierde la conexión padre→hijo           |
| No manejar los 3 casos de delete                            | Rompe el invariante BST                 |
| Copiar el nodo sucesor en vez de copiar solo el valor       | Memory leak o punteros rotos            |
| No liberar memoria en delete (`free`)                       | Memory leak                             |
| Insertar datos ordenados en BST sin balanceo                | Árbol degenerado, O(n) en todo          |
| Confundir sucesor inorder con hijo derecho                  | Es el MÍNIMO del subárbol derecho       |
| No pasar `preIdx` por referencia en build from preorder     | Cada rama procesa el mismo índice       |
| Asumir que BST siempre es O(log n)                          | Solo si está balanceado                 |
| Usar BST cuando hash table basta                            | Más lento sin necesitar orden           |

### ✅ Buenas Prácticas

| Práctica                                                   | Razón                                    |
| ---------------------------------------------------------- | ---------------------------------------- |
| Siempre verificar `root == NULL` como caso base            | Prevenir segfault                        |
| Usar `root->left = insert(root->left, val)` (retorno)     | Permite construir el árbol limpiamente   |
| Para delete con 2 hijos, buscar **sucesor inorder**        | Mantiene invariante BST automáticamente  |
| Verificar BST con inorder traversal (no solo hijos)        | Detecta violaciones profundas            |
| Usar build con rango O(n) en vez de inserción O(n²)        | Diferencia de rendimiento significativa  |
| Si los datos pueden llegar ordenados → usar árbol balanceado| Prevenir degeneración                   |
| Preferir recursivo para claridad, iterativo para producción | Trade-off elegancia vs eficiencia       |
| Probar con: vacío, 1 nodo, solo izq, solo der, balanceado  | Edge cases que revelan bugs             |
| Liberar todo el árbol con postorder traversal               | Hijos primero, luego padre              |
| Documentar la convención de duplicados                      | Evitar ambigüedad                       |

```c
// ✅ Liberar un BST completo (postorder)
void freeBST(BSTNode *root) {
    if (root == NULL) return;
    freeBST(root->left);
    freeBST(root->right);
    free(root);
}

// ✅ Insertar múltiples valores
BSTNode* buildBST(int values[], int n) {
    BSTNode *root = NULL;
    for (int i = 0; i < n; i++)
        root = insertRecursive(root, values[i]);
    return root;
}

// ✅ Imprimir BST inorder (verificación visual)
void inorder(BSTNode *root) {
    if (root == NULL) return;
    inorder(root->left);
    printf("%d ", root->data);
    inorder(root->right);
}
```

---

# 15. Intuición de Ingeniería

> **Un BST es binary search convertido en estructura dinámica.**
> Arrays ordenados son buenos buscando pero malos insertando.
> Linked lists son buenas insertando pero malas buscando.
> El BST toma el **principio de decisión** de binary search (izquierda/derecha)
> y lo **materializa en una estructura** que permite insertar y eliminar sin mover nada.

### El patrón BST

```text
Toda operación en BST sigue el mismo patrón:

  1. Comparar con el nodo actual.
  2. Decidir: izquierda o derecha.
  3. Repetir hasta encontrar (o llegar a NULL).

Search:  compara → decide → baja → ¿encontrado?
Insert:  compara → decide → baja → ¿NULL? → crear nodo
Delete:  compara → decide → baja → ¿encontrado? → manejar caso 1/2/3
```

### La tensión fundamental

```text
      Datos aleatorios              Datos ordenados
            │                             │
            ▼                             ▼
     BST balanceado               BST degenerado
     h = O(log n)                 h = O(n)
     Ops = O(log n)               Ops = O(n)
            │                             │
            ▼                             ▼
     ¡Excelente!                  = Linked list
                                  ¿Para qué usar BST?

Solución: Árboles auto-balanceados (AVL, Red-Black)
  → Rotan el árbol después de insert/delete
  → Garantizan h = O(log n) SIEMPRE
  → BST es la base; balanceo es la mejora
```

### El mapa de estructuras de datos

```text
         Array        Linked List       BST           Hash Table
         ─────        ───────────       ───           ──────────
Search:  O(n)/O(logn)  O(n)            O(log n)*      O(1)
Insert:  O(1)/O(n)     O(1)            O(log n)*      O(1)
Delete:  O(n)          O(1)**          O(log n)*      O(1)
Orden:   ✓ (si sorted)  ✗              ✓ (inorder)    ✗
Min/Max: O(1)/O(n)     O(n)            O(log n)*      O(n)
Range:   O(logn+k)     O(n)            O(logn+k)*     O(n)

* = si está balanceado
** = si tienes el puntero

BST: el generalista. No es el más rápido en nada individual,
pero es competitivo en TODO y mantiene ORDEN.
```

### Relación con otros temas

| Tema                             | Archivo              |
| -------------------------------- | -------------------- |
| Arrays a bajo nivel              | Arrays CDT.md        |
| Operaciones sobre arrays         | Arrays ADT.md        |
| Matrices densas y especiales     | Matrices.md          |
| Sparse matrices y polinomios     | SparseMatrices.md    |
| Strings (arrays de char)         | Strings.md           |
| Linked Lists                     | LinkedList.md        |
| Stacks                           | Stack.md             |
| Queues                           | Queue.md             |
| Trees (fundamentos)              | Trees.md             |
| **Binary Search Trees (este)**   | BinarySearchTree.md  |

---

# 16. Ejercicios Sugeridos

## 16.1 Nivel básico

| #  | Ejercicio                                              | Operación clave    |
| -- | ------------------------------------------------------ | ------------------ |
| 1  | Insertar {45, 30, 60, 15, 40, 55, 70} y dibujar el BST | Insert             |
| 2  | Hacer inorder del BST anterior y verificar que es ordenado | Inorder          |
| 3  | Buscar 40, luego buscar 100 (no existe). ¿Cuántas comparaciones? | Search     |
| 4  | Encontrar mínimo y máximo del BST                       | findMin, findMax   |

## 16.2 Nivel intermedio

| #  | Ejercicio                                              | Concepto clave     |
| -- | ------------------------------------------------------ | ------------------ |
| 5  | Eliminar una hoja (70), un nodo con 1 hijo (60), un nodo con 2 hijos (30) | Delete 3 casos |
| 6  | Insertar {10, 20, 30, 40, 50} y analizar la forma del árbol | Degeneración   |
| 7  | Dado preorder [50, 30, 20, 40, 70, 60, 80], construir el BST | Build from preorder |
| 8  | Encontrar el sucesor inorder de cada nodo en el BST     | Sucesor            |
| 9  | Escribir función que verifique si un árbol binario es BST | isBST            |

## 16.3 Nivel avanzado

| #   | Ejercicio                                             | Concepto clave         |
| --- | ----------------------------------------------------- | ---------------------- |
| 10  | Convertir BST a array ordenado y de vuelta a BST balanceado | Inorder + build  |
| 11  | Contar nodos en un rango [low, high] en un BST        | Range query            |
| 12  | Encontrar el LCA (Lowest Common Ancestor) de dos nodos | Propiedad BST        |
| 13  | Implementar `floor(key)` y `ceil(key)` en BST         | Búsqueda con variantes |
| 14  | Comparar tiempos de inserción/búsqueda de 10,000 elementos aleatorios vs ordenados | Análisis empírico |

### Pistas para ejercicios seleccionados

```text
Ejercicio 10 — BST a balanceado:
  1. Inorder del BST → array ordenado O(n)
  2. Tomar el elemento medio como raíz
  3. Recursivamente construir izq con mitad izquierda, der con mitad derecha
  → BST balanceado O(n)

Ejercicio 12 — LCA en BST:
  LCA(a, b) en un BST:
    Si a y b < nodo → LCA está a la izquierda
    Si a y b > nodo → LCA está a la derecha
    Si a ≤ nodo ≤ b → nodo ES el LCA
  → O(h)

Ejercicio 13 — Floor y Ceil:
  floor(key): mayor valor ≤ key
  ceil(key):  menor valor ≥ key
  Recorrer BST actualizando candidato cuando sea apropiado.
```
