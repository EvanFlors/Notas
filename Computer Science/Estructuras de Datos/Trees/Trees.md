# Trees — Estructuras Jerárquicas

> **Idea central:** Un array es lineal. Una lista enlazada es lineal. El mundo real **no es lineal**.
> Los árboles modelan **jerarquías**: sistema de archivos, HTML, decisiones, expresiones, bases de datos.
> Dominar árboles es pasar de pensar en **secuencias** a pensar en **estructuras recursivas**.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Definición de Árbol](#1-definición-de-árbol)
2. [Terminología](#2-terminología)
3. [Propiedades Matemáticas](#3-propiedades-matemáticas)

**Parte II — Binary Trees**
4. [Árbol Binario — Concepto](#4-árbol-binario--concepto)
5. [Representaciones](#5-representaciones)
6. [Tipos de Árboles Binarios](#6-tipos-de-árboles-binarios)

**Parte III — N-ary Trees**
7. [N-ary Trees](#7-n-ary-trees)

**Parte IV — Recorridos**
8. [Concepto de Recorrido](#8-concepto-de-recorrido)
9. [Preorder Traversal](#9-preorder-traversal)
10. [Inorder Traversal](#10-inorder-traversal)
11. [Postorder Traversal](#11-postorder-traversal)
12. [Level-Order Traversal (BFS)](#12-level-order-traversal-bfs)
13. [Comparación de Recorridos](#13-comparación-de-recorridos)

**Parte V — Construcción**
14. [Crear un Árbol Manualmente](#14-crear-un-árbol-manualmente)
15. [Construcción desde Recorridos](#15-construcción-desde-recorridos)

**Parte VI — Métricas y Propiedades**
16. [Altura del Árbol](#16-altura-del-árbol)
17. [Conteo de Nodos](#17-conteo-de-nodos)
18. [Conteo de Hojas](#18-conteo-de-hojas)

**Parte VII — Síntesis**
19. [Resumen de Complejidad](#19-resumen-de-complejidad)
20. [Errores Comunes y Buenas Prácticas](#20-errores-comunes-y-buenas-prácticas)
21. [Intuición de Ingeniería](#21-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS

---

# 1. Definición de Árbol

## 1.1 ¿Qué es un árbol?

Un **árbol** es una colección de **nodos** conectados por **aristas** que satisface:

1. Hay exactamente **un nodo raíz** (sin padre).
2. Cada nodo (excepto la raíz) tiene **exactamente un padre**.
3. Hay **exactamente un camino** entre la raíz y cualquier nodo.
4. **No hay ciclos.**

```text
            A            ← raíz (root)
          / | \
         B  C   D        ← hijos de A
        / \     |
       E   F    G        ← hojas (E, F, G) y nodo interno (B, D)
```

## 1.2 Definición recursiva

> Un árbol es:
> - Un nodo **vacío** (árbol vacío, NULL), o
> - Un nodo **raíz** con **cero o más subárboles** (cada uno es un árbol).

Esta definición recursiva es la base de casi toda operación sobre árboles.

```text
T = vacío  |  (raíz, T₁, T₂, ..., Tₖ)

Ejemplo: A con subárboles B, C, D
         B a su vez tiene subárboles E, F
         D tiene subárbol G
```

## 1.3 ¿Dónde aparecen los árboles?

| Caso de uso                   | Estructura de árbol                     |
| ----------------------------- | --------------------------------------- |
| Sistema de archivos           | Directorios y archivos                  |
| HTML / XML / JSON             | Etiquetas anidadas                      |
| Expresiones aritméticas       | Árbol de expresión `(a + b) * c`        |
| Bases de datos (B-Tree)       | Índices para búsqueda eficiente         |
| Compiladores (AST)            | Árbol Sintáctico Abstracto              |
| Decisiones (Decision Tree)    | Machine Learning                        |
| Autocompletar                 | Trie (árbol de prefijos)                |
| Red de routing                | Spanning Tree                           |

---

# 2. Terminología

## 2.1 Tabla completa

```text
                    A          ← raíz (root), nivel 0
                  / | \
                B    C   D     ← nivel 1
               / \       |
              E   F      G    ← nivel 2
             /
            H                 ← nivel 3
```

| Término            | Definición                                           | Ejemplo                          |
| ------------------ | ---------------------------------------------------- | -------------------------------- |
| **Nodo (Node)**    | Unidad fundamental con dato y enlaces a hijos        | A, B, C, D, E, F, G, H          |
| **Raíz (Root)**    | Nodo sin padre; punto de entrada al árbol            | A                                |
| **Hoja (Leaf)**    | Nodo sin hijos (nodo terminal/externo)               | C, F, G, H                       |
| **Nodo interno**   | Nodo con al menos un hijo                            | A, B, D, E                       |
| **Padre (Parent)** | Nodo que tiene un enlace directo hacia abajo         | A es padre de B, C, D            |
| **Hijo (Child)**   | Nodo directamente debajo de otro                     | B, C, D son hijos de A           |
| **Hermanos**       | Nodos con el mismo padre                             | B, C, D son hermanos             |
| **Subárbol**       | Árbol formado por un nodo y todos sus descendientes  | Subárbol de B = {B, E, F, H}    |
| **Ancestro**       | Cualquier nodo en el camino desde un nodo a la raíz  | Ancestros de H: E, B, A          |
| **Descendiente**   | Cualquier nodo en el subárbol de un nodo             | Descendientes de B: E, F, H      |

## 2.2 Nivel, Profundidad y Altura

| Concepto          | Definición                                              | Ejemplo                    |
| ----------------- | ------------------------------------------------------- | -------------------------- |
| **Nivel (Level)** | Distancia desde la raíz (raíz = nivel 0)               | A=0, B=1, E=2, H=3        |
| **Profundidad**   | Igual que nivel (número de aristas raíz → nodo)         | depth(H) = 3               |
| **Altura de nodo**| Número de aristas del nodo a su hoja más lejana         | height(B) = 2, height(H) = 0 |
| **Altura del árbol** | Altura de la raíz = profundidad máxima               | height(A) = 3              |

```text
Nivel 0:        A                height(A) = 3
               /|\
Nivel 1:      B  C  D            height(B) = 2, height(C) = 0, height(D) = 1
             / \     |
Nivel 2:    E   F    G           height(E) = 1, height(F) = 0
           /
Nivel 3:  H                      height(H) = 0 (hoja)
```

> **Profundidad** se mide **desde la raíz hacia abajo** (top-down).
> **Altura** se mide **desde las hojas hacia arriba** (bottom-up).

## 2.3 Grado

| Concepto             | Definición                                    | Ejemplo           |
| -------------------- | --------------------------------------------- | ------------------ |
| **Grado de un nodo** | Número de hijos directos                      | deg(A) = 3, deg(E) = 1, deg(F) = 0 |
| **Grado del árbol**  | Máximo grado entre todos los nodos            | deg(tree) = 3 (por A) |

```text
Grados en nuestro árbol:
  A: 3 hijos (B, C, D) → grado 3
  B: 2 hijos (E, F)    → grado 2
  D: 1 hijo (G)        → grado 1
  E: 1 hijo (H)        → grado 1
  C, F, G, H: 0 hijos  → grado 0 (hojas)

Grado del árbol = max(3, 2, 1, 1, 0, 0, 0, 0) = 3
```

---

# 3. Propiedades Matemáticas

## 3.1 Propiedades generales de árboles

| Propiedad                                    | Fórmula / Valor                          |
| -------------------------------------------- | ---------------------------------------- |
| Número de aristas                            | `n - 1` (donde n = nodos)               |
| Nodos en un árbol con e aristas              | `e + 1`                                  |
| Mínimo de nodos para altura h                | `h + 1` (cadena lineal)                  |
| Máximo de nodos para altura h (binario)      | `2^(h+1) - 1`                            |

## 3.2 Propiedades específicas de árboles binarios

| Propiedad                                    | Fórmula                                  |
| -------------------------------------------- | ---------------------------------------- |
| Mín. nodos para altura h                     | `h + 1`                                  |
| Máx. nodos para altura h                     | `2^(h+1) - 1`                            |
| Mín. altura para n nodos                     | `⌊log₂(n)⌋`                              |
| Máx. altura para n nodos                     | `n - 1`                                  |
| Máx. nodos en nivel k                        | `2^k`                                    |
| Nodos hoja en full binary tree               | `internos + 1`                            |
| Árboles binarios posibles con n nodos (Catalan) | `C(n) = C(2n,n)/(n+1)`               |

### Demostración visual: nodos vs altura

```text
Altura h = 3:

Mínimo de nodos (h + 1 = 4):       Máximo de nodos (2⁴ - 1 = 15):
        A                                      A
        |                                   /     \
        B                                  B       C
        |                                / \     / \
        C                              D   E   F   G
        |                             /\ /\ /\ /\
        D                            H I J K L M N O

4 nodos, h=3                        15 nodos, h=3
```

### Números de Catalan

El número de **árboles binarios estructuralmente distintos** con n nodos:

```text
n:  0   1   2   3    4    5     6     7
C:  1   1   2   5   14   42   132   429

C(n) = C(2n, n) / (n + 1) = (2n)! / ((n+1)! × n!)
```

```text
n = 3 → C(3) = 5 árboles posibles:

    O       O       O       O       O
   /       / \       \     /         \
  O       O   O       O   O           O
 /                      \   \        /
O                        O   O      O
```

---

# PARTE II — BINARY TREES

---

# 4. Árbol Binario — Concepto

## 4.1 Definición

Un **árbol binario** es un árbol donde cada nodo tiene **como máximo 2 hijos**: izquierdo (left) y derecho (right).

```text
Definición recursiva:
  BinaryTree = vacío  |  (dato, BinaryTree_izq, BinaryTree_der)
```

```text
           10
          /  \
         5    15
        / \     \
       3   7    20
```

## 4.2 Estructura en C

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct TreeNode {
    int data;
    struct TreeNode *left;
    struct TreeNode *right;
} TreeNode;

TreeNode* createNode(int value) {
    TreeNode *n = (TreeNode*)malloc(sizeof(TreeNode));
    n->data = value;
    n->left = NULL;
    n->right = NULL;
    return n;
}
```

## 4.3 Internal vs External Nodes

| Tipo              | Definición                          | También llamado      |
| ----------------- | ----------------------------------- | -------------------- |
| **Internal node** | Nodo con al menos 1 hijo           | Nodo de bifurcación  |
| **External node** | Nodo sin hijos (hoja)              | Nodo terminal        |

```text
           10          ← internal
          /  \
         5    15       ← 5: internal, 15: internal
        / \     \
       3   7    20     ← external (hojas)

Internal nodes: {10, 5, 15}    → 3 nodos
External nodes: {3, 7, 20}     → 3 nodos
```

### Relación en strict binary tree

En un **strict (proper)** binary tree:

```text
external = internal + 1

Si internal = 3 → external = 4
```

---

# 5. Representaciones

## 5.1 Representación con Arrays

### Idea

Almacenar los nodos en un array usando la posición para codificar las relaciones padre-hijo.

```text
Para un nodo en índice i (1-indexed):
  - Hijo izquierdo:  2i
  - Hijo derecho:    2i + 1
  - Padre:           ⌊i/2⌋

Para un nodo en índice i (0-indexed):
  - Hijo izquierdo:  2i + 1
  - Hijo derecho:    2i + 2
  - Padre:           ⌊(i-1)/2⌋
```

### Ejemplo

```text
Árbol:
           A
          / \
         B   C
        / \   \
       D   E   F

Array (1-indexed):
Index:   1    2    3    4    5    6    7
Value: [ A ][ B ][ C ][ D ][ E ][ - ][ F ]
                                  ↑
                              espacio vacío (C no tiene hijo izq)

Fórmulas (i=1 → A):
  Left(1) = 2×1 = 2 → B  ✓
  Right(1) = 2×1+1 = 3 → C  ✓
  Left(3) = 2×3 = 6 → vacío  ✓
  Right(3) = 2×3+1 = 7 → F  ✓
  Parent(5) = ⌊5/2⌋ = 2 → B  ✓
```

### Implementación

```c
#define MAX_NODES 100

typedef struct {
    int data[MAX_NODES + 1];    // 1-indexed
    int used[MAX_NODES + 1];    // 1 = nodo existe, 0 = vacío
    int size;                    // máximo índice usado
} ArrayTree;

ArrayTree* createArrayTree() {
    ArrayTree *t = (ArrayTree*)malloc(sizeof(ArrayTree));
    for (int i = 0; i <= MAX_NODES; i++)
        t->used[i] = 0;
    t->size = 0;
    return t;
}

void setNode(ArrayTree *t, int index, int value) {
    t->data[index] = value;
    t->used[index] = 1;
    if (index > t->size) t->size = index;
}

int leftChild(int i)  { return 2 * i; }
int rightChild(int i) { return 2 * i + 1; }
int parent(int i)     { return i / 2; }
```

### Análisis

| Aspecto                  | Array                        | Nota                          |
| ------------------------ | ---------------------------- | ----------------------------- |
| Acceso a hijo/padre      | **O(1)** — fórmula aritmética | Gran ventaja                |
| Espacio para full tree   | O(n) — sin desperdicio       | Ideal                         |
| Espacio para skewed tree | O(2ⁿ) — mayormente vacío    | Terrible                      |
| Inserciones dinámicas    | Difícil (redimensionar)      | No flexible                   |

```text
Peor caso (árbol sesgado, n=4 nodos):

     A
      \
       B
        \
         C
          \
           D

Necesita array de tamaño 2⁴ = 16 para 4 nodos:
[ A ][ - ][ B ][ - ][ - ][ - ][ C ][ - ][ - ][ - ][ - ][ - ][ - ][ - ][ D ]

75% de espacio desperdiciado.
```

> **Regla:** Usa representación con arrays solo para árboles **completos** o **casi completos** (como heaps).

## 5.2 Representación con Linked List (Nodos)

### Idea

Cada nodo contiene el dato y dos punteros: uno al hijo izquierdo y otro al derecho.

```text
┌──────┬──────┬──────┐
│ left  │ data │ right│
│  *    │      │  *   │
└──┬───┴──────┴───┬──┘
   │              │
   ▼              ▼
 hijo izq      hijo der
```

### Ejemplo en memoria

```text
Árbol:          10
               /  \
              5    15
             / \
            3   7

En memoria (heap, disperso):

0x100: [NULL | 3 | NULL]
0x200: [NULL | 7 | NULL]
0x300: [0x100 | 5 | 0x200]     ← left=3, right=7
0x400: [NULL | 15 | NULL]
0x500: [0x300 | 10 | 0x400]    ← root: left=5, right=15
```

### Análisis

| Aspecto                  | Linked                         | Nota                      |
| ------------------------ | ------------------------------ | ------------------------- |
| Espacio                  | O(n) — exactamente n nodos     | Sin desperdicio           |
| Acceso a hijo            | O(1) — seguir puntero          |                           |
| Acceso a padre           | O(n)* — no hay enlace al padre | *A menos que lo agregues  |
| Inserciones              | O(1) — crear nodo + enlazar    | Flexible                  |
| Árboles sesgados         | O(n) espacio — eficiente       | Sin desperdicio           |

> **Regla:** Usa representación con nodos/punteros para árboles **generales** y **dinámicos**.

## 5.3 Comparación

| Criterio            | Array              | Linked List         |
| ------------------- | ------------------ | ------------------- |
| Acceso a padre      | **O(1)**           | O(n) sin ptr padre  |
| Acceso a hijo       | **O(1)**           | O(1)                |
| Espacio (full)      | O(n)               | O(n) + punteros     |
| Espacio (skewed)    | O(2ⁿ)             | **O(n)**            |
| Flexibilidad        | Baja               | **Alta**            |
| Mejor para          | Heaps, complete BT | Árboles generales   |

---

# 6. Tipos de Árboles Binarios

## 6.1 Strict (Proper) Binary Tree

Cada nodo tiene **exactamente 0 o 2 hijos**. Nunca 1.

```text
✅ Strict:           ❌ No strict:
      A                    A
     / \                  / \
    B   C                B   C
   / \                  /
  D   E                D
```

### Propiedades

| Propiedad                               | Fórmula                              |
| --------------------------------------- | ------------------------------------ |
| Hojas (external)                        | `internal + 1`                       |
| Total de nodos                          | `2 × internal + 1`                   |
| Mín. nodos para altura h               | `2h + 1`                             |
| Máx. nodos para altura h               | `2^(h+1) - 1`                        |
| Mín. altura para n nodos               | `⌊log₂(n)⌋`                          |
| Máx. altura para n nodos               | `(n - 1) / 2`                        |

### Demostración: hojas = internal + 1

```text
Inducción:
  Base: 1 nodo interno + 0 hijos = imposible en strict.
        Mínimo strict: 3 nodos (1 interno, 2 hojas). 2 = 1 + 1 ✓

  Paso: Al agregar un hijo a una hoja en strict,
        esa hoja se convierte en nodo interno (+1 interno)
        y se crean 2 nuevas hojas (neto: +1 hoja).
        → Relación se mantiene.
```

---

## 6.2 Full Binary Tree

**Todos los niveles** están completamente llenos. Máxima cantidad de nodos para su altura.

```text
Full Binary Tree (h = 2):

         A              Nivel 0: 1 nodo  = 2⁰
        / \
       B   C            Nivel 1: 2 nodos = 2¹
      / \ / \
     D  E F  G          Nivel 2: 4 nodos = 2²

Total: 2⁰ + 2¹ + 2² = 1 + 2 + 4 = 7 = 2³ - 1 = 2^(h+1) - 1
```

### Propiedades

| Propiedad              | Fórmula                              |
| ---------------------- | ------------------------------------ |
| Nodos totales          | `2^(h+1) - 1`                        |
| Hojas                  | `2^h`                                 |
| Nodos internos         | `2^h - 1`                             |
| Altura dado n nodos    | `log₂(n+1) - 1`                      |

```text
h = 3:
  Nodos = 2⁴ - 1 = 15
  Hojas = 2³ = 8
  Internos = 2³ - 1 = 7
  Verificación: 15 = 8 + 7 ✓
```

---

## 6.3 Complete Binary Tree

Todos los niveles están llenos **excepto posiblemente el último**, y el último nivel se llena de **izquierda a derecha**.

```text
✅ Complete:              ❌ No complete:
        A                        A
       / \                      / \
      B   C                    B   C
     / \ /                    / \   \
    D  E F                   D   E   F
                                     (falta nodo antes de F)
```

### Propiedades

| Propiedad              | Valor                                  |
| ---------------------- | -------------------------------------- |
| Altura                 | `⌊log₂(n)⌋`                            |
| Hojas                  | `⌈n/2⌉`                                |
| Nodos internos         | `⌊n/2⌋`                                |
| Se puede almacenar en array | **Sí, sin desperdiciar espacio**  |

> **Los heaps (min-heap, max-heap) son árboles binarios completos.** Por eso se implementan con arrays.

---

## 6.4 Comparación

```text
         Full              Complete           Strict
         (todo lleno)      (lleno izq→der)    (0 o 2 hijos)

           A                  A                  A
          / \                / \                / \
         B   C              B   C              B   C
        / \ / \            / \ /              / \
       D  E F  G          D  E F             D   E
```

| Propiedad             | Full     | Complete   | Strict    |
| --------------------- | -------- | ---------- | --------- |
| Todos niveles llenos  | **Sí**   | Casi (último parcial) | No necesariamente |
| Último nivel          | Lleno    | Izq → Der  | Cualquier orden |
| Nodos con 1 hijo      | **0**    | **≤ 1**    | **0**     |
| Representable en array | Sí      | **Sí**     | Con huecos |
| Es strict?            | Sí       | No siempre | **Sí** (definición) |
| Es complete?          | **Sí**   | **Sí**     | No siempre |

> **Todo Full es Complete y Strict. Un Complete puede no ser Strict (último nivel incompleto). Un Strict puede no ser Complete (huecos en niveles).**

---

# PARTE III — N-ARY TREES

---

# 7. N-ary Trees

## 7.1 Definición

Un **N-ary tree** (o árbol m-ario) es un árbol donde cada nodo puede tener **hasta N hijos**.

| Tipo          | Máximo hijos | Ejemplo                    |
| ------------- | ------------ | -------------------------- |
| Binario       | 2            | Árboles de expresión       |
| Ternario      | 3            | Ternary Search Trie        |
| N-ario general | N           | Sistema de archivos, DOM   |

## 7.2 Estructura en C

```c
// Opción 1: Array de hijos (cuando N es conocido y pequeño)
#define MAX_CHILDREN 10

typedef struct NaryNode {
    int data;
    struct NaryNode *children[MAX_CHILDREN];
    int numChildren;
} NaryNode;

// Opción 2: Left-Child Right-Sibling (cualquier N)
typedef struct LCRSNode {
    int data;
    struct LCRSNode *firstChild;     // primer hijo
    struct LCRSNode *nextSibling;    // siguiente hermano
} LCRSNode;
```

## 7.3 Representación Left-Child Right-Sibling

**Idea:** Convertir cualquier árbol N-ario en un **árbol binario** usando:
- `left` = primer hijo
- `right` = siguiente hermano

```text
N-ary tree:                   LCRS binary tree:
        A                            A
      / | \                         /
     B  C  D                       B
    / \    |                      / \
   E   F   G                    E   C
                               / \   \
                              (n) F    D
                                      /
                                     G

Lectura: A.firstChild = B
         B.nextSibling = C
         C.nextSibling = D
         B.firstChild = E
         E.nextSibling = F
         D.firstChild = G
```

> Esto permite representar **cualquier árbol** con solo **2 punteros por nodo** (como un árbol binario).

## 7.4 Propiedades de N-ary trees

Para un **full N-ary tree** de altura h:

| Propiedad              | Fórmula                              |
| ---------------------- | ------------------------------------ |
| Nodos totales          | `(N^(h+1) - 1) / (N - 1)`            |
| Hojas                  | `N^h`                                  |
| Nodos internos         | `(N^h - 1) / (N - 1)`                 |
| Altura dado n nodos    | `logN((N-1)n + 1) - 1`                |

```text
Ejemplo: Ternario (N=3), h=2:
  Nodos  = (3³ - 1) / (3 - 1) = 26/2 = 13
  Hojas  = 3² = 9
  Internos = (3² - 1) / (3 - 1) = 8/2 = 4
  Verificación: 13 = 9 + 4 ✓
```

## 7.5 Casos de uso

| Estructura           | N     | Uso                                     |
| -------------------- | ----- | --------------------------------------- |
| Binary Tree          | 2     | Expresiones, BST, Heaps                 |
| Ternary Search Trie  | 3     | Autocompletar, diccionarios             |
| B-Tree               | m     | Bases de datos, sistemas de archivos    |
| Trie                  | 26+  | Búsqueda de strings                    |
| DOM Tree             | var   | HTML/XML parsing                        |
| File System          | var   | Directorios con múltiples archivos      |

---

# PARTE IV — RECORRIDOS

---

# 8. Concepto de Recorrido

## 8.1 ¿Qué es recorrer un árbol?

**Recorrer** (traverse) un árbol es **visitar cada nodo exactamente una vez** en un orden definido.

A diferencia de arrays y listas (donde el orden es natural: izquierda → derecha), los árboles tienen **múltiples caminos**. Necesitamos un criterio para decidir el orden.

## 8.2 Los cuatro recorridos principales

| Recorrido     | Orden de visita                    | Tipo       |
| ------------- | ---------------------------------- | ---------- |
| **Preorder**  | Raíz → Izquierdo → Derecho        | DFS        |
| **Inorder**   | Izquierdo → Raíz → Derecho        | DFS        |
| **Postorder** | Izquierdo → Derecho → Raíz        | DFS        |
| **Level-order** | Nivel por nivel (izq → der)     | **BFS**    |

```text
Árbol de referencia para todos los ejemplos:

            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7
```

> **DFS** (Depth-First Search) explora profundidad primero. Usa **stack** (implícito en recursión o explícito).
> **BFS** (Breadth-First Search) explora nivel por nivel. Usa **queue**.

---

# 9. Preorder Traversal

## 9.1 Orden: Raíz → Izquierdo → Derecho (NLR)

> "Visita el nodo ANTES de sus hijos."

```text
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

Preorder: 1, 2, 4, 5, 2, 3, 6, 7

Traza detallada:
  visit(1)                    → 1
    visit(2)                  → 1, 2
      visit(4)                → 1, 2, 4
        left(NULL) → return
        right(NULL) → return
      visit(5)                → 1, 2, 4, 5
        left(NULL) → return
        right(NULL) → return
    visit(3)                  → 1, 2, 4, 5, 3
      left(NULL) → return
      visit(6)                → 1, 2, 4, 5, 3, 6
        visit(7)              → 1, 2, 4, 5, 3, 6, 7
          left(NULL) → return
          right(NULL) → return
        right(NULL) → return

Resultado: 1  2  4  5  3  6  7
```

## 9.2 Implementación recursiva

```c
void preorder(TreeNode *root) {
    if (root == NULL) return;
    printf("%d ", root->data);      // Visitar raíz
    preorder(root->left);           // Recorrer izquierdo
    preorder(root->right);          // Recorrer derecho
}
```

## 9.3 Implementación iterativa (con stack)

```c
void preorderIterative(TreeNode *root) {
    if (root == NULL) return;

    // Necesitamos un stack de punteros a TreeNode
    TreeNode *stack[100];
    int top = -1;

    stack[++top] = root;

    while (top >= 0) {
        TreeNode *curr = stack[top--];      // pop
        printf("%d ", curr->data);

        // Push right PRIMERO (sale después → se procesa después)
        if (curr->right != NULL)
            stack[++top] = curr->right;

        // Push left DESPUÉS (sale primero → se procesa primero)
        if (curr->left != NULL)
            stack[++top] = curr->left;
    }
}
```

```text
Traza iterativa:

Stack (top→bot)    │ Pop    │ Output          │ Push
───────────────────┼────────┼─────────────────┼──────────
[1]                │ 1      │ 1               │ R:3, L:2
[2, 3]             │ 2      │ 1 2             │ R:5, L:4
[4, 5, 3]          │ 4      │ 1 2 4           │ (nada)
[5, 3]             │ 5      │ 1 2 4 5         │ (nada)
[3]                │ 3      │ 1 2 4 5 3       │ R:6
[6]                │ 6      │ 1 2 4 5 3 6     │ L:7
[7]                │ 7      │ 1 2 4 5 3 6 7   │ (nada)
[]                 │        │                 │ FIN

Resultado: 1 2 4 5 3 6 7  ✓
```

> **Clave:** Se pushea el right ANTES que el left, porque el stack es LIFO — queremos que left salga primero.

---

# 10. Inorder Traversal

## 10.1 Orden: Izquierdo → Raíz → Derecho (LNR)

> "Visita el nodo ENTRE sus hijos."

```text
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

Inorder: 4, 2, 5, 1, 3, 7, 6

Traza:
  inorder(1):
    inorder(2):
      inorder(4):
        inorder(NULL) → return
        visit(4)              → 4
        inorder(NULL) → return
      visit(2)                → 4, 2
      inorder(5):
        inorder(NULL) → return
        visit(5)              → 4, 2, 5
        inorder(NULL) → return
    visit(1)                  → 4, 2, 5, 1
    inorder(3):
      inorder(NULL) → return
      visit(3)                → 4, 2, 5, 1, 3
      inorder(6):
        inorder(7):
          inorder(NULL) → return
          visit(7)            → 4, 2, 5, 1, 3, 7
          inorder(NULL) → return
        visit(6)              → 4, 2, 5, 1, 3, 7, 6
        inorder(NULL) → return

Resultado: 4  2  5  1  3  7  6
```

## 10.2 Implementación recursiva

```c
void inorder(TreeNode *root) {
    if (root == NULL) return;
    inorder(root->left);             // Recorrer izquierdo
    printf("%d ", root->data);       // Visitar raíz
    inorder(root->right);           // Recorrer derecho
}
```

## 10.3 Implementación iterativa (con stack)

La idea: ir lo más a la izquierda posible, apilando todo. Cuando no se puede ir más a la izquierda, pop, visitar, ir a la derecha.

```c
void inorderIterative(TreeNode *root) {
    TreeNode *stack[100];
    int top = -1;
    TreeNode *curr = root;

    while (curr != NULL || top >= 0) {
        // Ir lo más a la izquierda posible
        while (curr != NULL) {
            stack[++top] = curr;
            curr = curr->left;
        }

        // Pop, visitar, ir a la derecha
        curr = stack[top--];
        printf("%d ", curr->data);
        curr = curr->right;
    }
}
```

```text
Traza iterativa:

curr    │ Acción                    │ Stack (top→bot)  │ Output
────────┼───────────────────────────┼──────────────────┼──────────
1       │ push 1, go left           │ [1]              │
2       │ push 2, go left           │ [2, 1]           │
4       │ push 4, go left           │ [4, 2, 1]        │
NULL    │ pop 4, visit, go right    │ [2, 1]           │ 4
NULL    │ pop 2, visit, go right    │ [1]              │ 4 2
5       │ push 5, go left           │ [5, 1]           │ 4 2
NULL    │ pop 5, visit, go right    │ [1]              │ 4 2 5
NULL    │ pop 1, visit, go right    │ [ ]              │ 4 2 5 1
3       │ push 3, go left           │ [3]              │ 4 2 5 1
NULL    │ pop 3, visit, go right    │ [ ]              │ 4 2 5 1 3
6       │ push 6, go left           │ [6]              │ 4 2 5 1 3
7       │ push 7, go left           │ [7, 6]           │ 4 2 5 1 3
NULL    │ pop 7, visit, go right    │ [6]              │ 4 2 5 1 3 7
NULL    │ pop 6, visit, go right    │ [ ]              │ 4 2 5 1 3 7 6
NULL    │ stack vacío, curr=NULL    │ [ ]              │ FIN

Resultado: 4 2 5 1 3 7 6  ✓
```

> **Nota importante:** En un **BST (Binary Search Tree)**, el recorrido inorder produce los elementos **en orden ascendente**.

---

# 11. Postorder Traversal

## 11.1 Orden: Izquierdo → Derecho → Raíz (LRN)

> "Visita el nodo DESPUÉS de sus hijos."

```text
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

Postorder: 4, 5, 2, 7, 6, 3, 1

Traza:
  postorder(1):
    postorder(2):
      postorder(4):
        postorder(NULL) → return
        postorder(NULL) → return
        visit(4)                → 4
      postorder(5):
        postorder(NULL) → return
        postorder(NULL) → return
        visit(5)                → 4, 5
      visit(2)                  → 4, 5, 2
    postorder(3):
      postorder(NULL) → return
      postorder(6):
        postorder(7):
          postorder(NULL) → return
          postorder(NULL) → return
          visit(7)              → 4, 5, 2, 7
        postorder(NULL) → return
        visit(6)                → 4, 5, 2, 7, 6
      visit(3)                  → 4, 5, 2, 7, 6, 3
    visit(1)                    → 4, 5, 2, 7, 6, 3, 1

Resultado: 4  5  2  7  6  3  1
```

## 11.2 Implementación recursiva

```c
void postorder(TreeNode *root) {
    if (root == NULL) return;
    postorder(root->left);           // Recorrer izquierdo
    postorder(root->right);          // Recorrer derecho
    printf("%d ", root->data);       // Visitar raíz
}
```

## 11.3 Implementación iterativa (con dos stacks)

**Idea:** Postorder es casi el reverso de un preorder modificado (Raíz → Derecho → Izquierdo).

```text
Preorder normal:    N L R  →  1 2 4 5 3 6 7
Preorder modificado: N R L  →  1 3 6 7 2 5 4
Reverso de NRL:     L R N  →  4 5 2 7 6 3 1  ← ¡Es postorder!
```

```c
void postorderIterative(TreeNode *root) {
    if (root == NULL) return;

    TreeNode *stack1[100], *stack2[100];
    int top1 = -1, top2 = -1;

    stack1[++top1] = root;

    while (top1 >= 0) {
        TreeNode *curr = stack1[top1--];
        stack2[++top2] = curr;          // en vez de imprimir, apilar en stack2

        if (curr->left != NULL)
            stack1[++top1] = curr->left;
        if (curr->right != NULL)
            stack1[++top1] = curr->right;
    }

    // stack2 tiene los nodos en orden inverso al postorder
    while (top2 >= 0)
        printf("%d ", stack2[top2--]->data);
}
```

```text
Stack1 procesa NRL (preorder modificado):
  Pop 1 → push to stack2. Push L:2, R:3
  Pop 3 → push to stack2. Push R:6
  Pop 6 → push to stack2. Push L:7
  Pop 7 → push to stack2.
  Pop 2 → push to stack2. Push L:4, R:5
  Pop 5 → push to stack2.
  Pop 4 → push to stack2.

Stack2 (bottom→top): 1, 3, 6, 7, 2, 5, 4
Pop stack2:           4, 5, 2, 7, 6, 3, 1  ✓ (postorder)
```

---

## 11.4 Implementación iterativa (con un solo stack)

```c
void postorderOneStack(TreeNode *root) {
    TreeNode *stack[100];
    int top = -1;
    TreeNode *curr = root;
    TreeNode *lastVisited = NULL;

    while (curr != NULL || top >= 0) {
        // Ir lo más a la izquierda
        while (curr != NULL) {
            stack[++top] = curr;
            curr = curr->left;
        }

        TreeNode *peekNode = stack[top];

        // Si hay hijo derecho y no lo hemos visitado
        if (peekNode->right != NULL && peekNode->right != lastVisited) {
            curr = peekNode->right;
        } else {
            // Visitar
            printf("%d ", peekNode->data);
            lastVisited = stack[top--];
        }
    }
}
```

> El postorder iterativo con un stack es el más complejo de los tres recorridos. Usa `lastVisited` para saber si ya procesó el subárbol derecho.

---

# 12. Level-Order Traversal (BFS)

## 12.1 Orden: Nivel por nivel, izquierda → derecha

```text
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

Level-order: 1, 2, 3, 4, 5, 6, 7

Nivel 0: 1
Nivel 1: 2, 3
Nivel 2: 4, 5, 6
Nivel 3: 7
```

## 12.2 ¿Por qué una Queue?

DFS usa stack (LIFO) → profundidad primero.
BFS usa queue (FIFO) → nivel por nivel.

```text
Queue procesa en orden de llegada:
  Enqueue root (1)
  Dequeue 1 → enqueue hijos (2, 3)
  Dequeue 2 → enqueue hijos (4, 5)
  Dequeue 3 → enqueue hijos (6)
  Dequeue 4 → sin hijos
  Dequeue 5 → sin hijos
  Dequeue 6 → enqueue hijos (7)
  Dequeue 7 → sin hijos

Orden de dequeue: 1, 2, 3, 4, 5, 6, 7  ✓
```

## 12.3 Implementación con Queue (array circular)

```c
void levelOrder(TreeNode *root) {
    if (root == NULL) return;

    // Queue simple con array
    TreeNode *queue[100];
    int front = 0, rear = 0;

    queue[rear++] = root;      // enqueue root

    while (front < rear) {
        TreeNode *curr = queue[front++];    // dequeue
        printf("%d ", curr->data);

        if (curr->left != NULL)
            queue[rear++] = curr->left;
        if (curr->right != NULL)
            queue[rear++] = curr->right;
    }
}
```

```text
Traza:

Queue (front→rear)    │ Dequeue │ Output          │ Enqueue
──────────────────────┼─────────┼─────────────────┼───────────
[1]                   │ 1       │ 1               │ 2, 3
[2, 3]                │ 2       │ 1 2             │ 4, 5
[3, 4, 5]             │ 3       │ 1 2 3           │ 6
[4, 5, 6]             │ 4       │ 1 2 3 4         │ (nada)
[5, 6]                │ 5       │ 1 2 3 4 5       │ (nada)
[6]                   │ 6       │ 1 2 3 4 5 6     │ 7
[7]                   │ 7       │ 1 2 3 4 5 6 7   │ (nada)
[]                    │         │                 │ FIN

Resultado: 1 2 3 4 5 6 7  ✓
```

---

# 13. Comparación de Recorridos

## 13.1 Resultados con el árbol de referencia

```text
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

Preorder  (NLR): 1  2  4  5  3  6  7
Inorder   (LNR): 4  2  5  1  3  7  6
Postorder (LRN): 4  5  2  7  6  3  1
Level-order:     1  2  3  4  5  6  7
```

## 13.2 Tabla comparativa

| Recorrido   | Orden          | Estructura | Recursivo | Iterativo     | Aplicación principal          |
| ----------- | -------------- | ---------- | --------- | ------------- | ----------------------------- |
| Preorder    | N → L → R      | Stack      | Trivial   | 1 stack       | Copiar árbol, serializar      |
| Inorder     | L → N → R      | Stack      | Trivial   | 1 stack       | BST en orden, expr. infix     |
| Postorder   | L → R → N      | Stack      | Trivial   | 2 stacks / 1  | Borrar árbol, expr. postfix   |
| Level-order | Nivel a nivel   | **Queue**  | Menos natural | 1 queue    | BFS, imprimir por niveles    |

## 13.3 Truco mnemotécnico

```text
PRE:   print ANTES de las llamadas recursivas
IN:    print ENTRE las llamadas recursivas
POST:  print DESPUÉS de las llamadas recursivas
```

```c
void preorder(TreeNode *r)  { if(!r) return; VISIT;  pre(r->left);  pre(r->right);  }
void inorder(TreeNode *r)   { if(!r) return; in(r->left);   VISIT;  in(r->right);   }
void postorder(TreeNode *r) { if(!r) return; post(r->left); post(r->right); VISIT;   }
```

> La **única diferencia** entre los tres DFS es **dónde va el `printf`**. Todo lo demás es idéntico.

---

# PARTE V — CONSTRUCCIÓN

---

# 14. Crear un Árbol Manualmente

## 14.1 Construcción nodo por nodo

```c
TreeNode* buildSampleTree() {
    TreeNode *root = createNode(1);
    root->left = createNode(2);
    root->right = createNode(3);
    root->left->left = createNode(4);
    root->left->right = createNode(5);
    root->right->right = createNode(6);
    root->right->right->left = createNode(7);
    return root;
}
```

```text
Resultado:
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7
```

## 14.2 Construcción con Level-Order Input

Construir el árbol leyendo valores nivel por nivel (útil para input desde usuario).

```c
TreeNode* buildFromLevelOrder(int arr[], int n) {
    if (n == 0 || arr[0] == -1) return NULL;   // -1 = NULL

    TreeNode *root = createNode(arr[0]);
    TreeNode *queue[100];
    int front = 0, rear = 0;
    queue[rear++] = root;

    int i = 1;
    while (front < rear && i < n) {
        TreeNode *curr = queue[front++];

        // Hijo izquierdo
        if (i < n && arr[i] != -1) {
            curr->left = createNode(arr[i]);
            queue[rear++] = curr->left;
        }
        i++;

        // Hijo derecho
        if (i < n && arr[i] != -1) {
            curr->right = createNode(arr[i]);
            queue[rear++] = curr->right;
        }
        i++;
    }
    return root;
}

// Uso: int arr[] = {1, 2, 3, 4, 5, -1, 6, -1, -1, -1, -1, 7};
//      TreeNode *root = buildFromLevelOrder(arr, 12);
```

---

# 15. Construcción desde Recorridos

## 15.1 ¿Es posible reconstruir un árbol desde un solo recorrido?

| Recorrido dado     | ¿Único árbol? | Razón                              |
| ------------------ | -------------- | ---------------------------------- |
| Solo Preorder      | **No**         | Múltiples árboles posibles         |
| Solo Inorder       | **No**         | Múltiples árboles posibles         |
| Solo Postorder     | **No**         | Múltiples árboles posibles         |
| **Preorder + Inorder** | **Sí**    | Combinación única                  |
| **Postorder + Inorder** | **Sí**   | Combinación única                  |
| Preorder + Postorder  | No*         | *Solo si es strict/full binary tree |

> **Necesitas al menos dos recorridos, y uno de ellos DEBE ser inorder**, para reconstruir un árbol binario único.

### ¿Por qué se necesita inorder?

Inorder define la **partición izquierda/derecha** de cada nodo. Preorder o postorder definen la **raíz** de cada subárbol.

## 15.2 Preorder + Inorder → Árbol

### Algoritmo

```text
1. El PRIMER elemento de Preorder es la RAÍZ.
2. Buscar esa raíz en Inorder → divide en subárbol izquierdo y derecho.
3. Recursivamente construir izquierdo y derecho con las subsecuencias correspondientes.
```

### Ejemplo paso a paso

```text
Preorder: [1, 2, 4, 5, 3, 6, 7]
Inorder:  [4, 2, 5, 1, 3, 7, 6]

Paso 1: Raíz = pre[0] = 1
        Buscar 1 en inorder → índice 3
        Izquierdo inorder: [4, 2, 5]     (3 elementos)
        Derecho inorder:   [3, 7, 6]     (3 elementos)
        Izquierdo preorder: [2, 4, 5]    (siguientes 3 de preorder)
        Derecho preorder:   [3, 6, 7]    (últimos 3 de preorder)

            1
           / \
         [?]  [?]

Paso 2a (izquierdo): pre=[2,4,5], in=[4,2,5]
        Raíz = 2, en inorder idx=1
        Izq in: [4]   →  pre: [4]
        Der in: [5]   →  pre: [5]

            1
           / \
          2   [?]
         / \
        4   5

Paso 2b (derecho): pre=[3,6,7], in=[3,7,6]
        Raíz = 3, en inorder idx=0
        Izq in: []    →  (vacío)
        Der in: [7,6] →  pre: [6,7]

            1
           / \
          2   3
         / \   \
        4   5  [?]

Paso 3: pre=[6,7], in=[7,6]
        Raíz = 6, en inorder idx=1
        Izq in: [7] → pre: [7]
        Der in: []  → (vacío)

            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7       ✓
```

### Implementación

```c
// Función auxiliar: buscar valor en inorder
int findIndex(int inorder[], int start, int end, int value) {
    for (int i = start; i <= end; i++)
        if (inorder[i] == value)
            return i;
    return -1;
}

// preIdx es un puntero para llevar cuenta global del índice en preorder
TreeNode* buildFromPreIn(int preorder[], int inorder[],
                          int inStart, int inEnd, int *preIdx) {
    if (inStart > inEnd)
        return NULL;

    // La raíz es el siguiente elemento en preorder
    int rootVal = preorder[*preIdx];
    (*preIdx)++;
    TreeNode *root = createNode(rootVal);

    // Si es hoja (no tiene rango para dividir)
    if (inStart == inEnd)
        return root;

    // Encontrar la raíz en inorder
    int inIdx = findIndex(inorder, inStart, inEnd, rootVal);

    // Construir subárboles
    root->left  = buildFromPreIn(preorder, inorder, inStart, inIdx - 1, preIdx);
    root->right = buildFromPreIn(preorder, inorder, inIdx + 1, inEnd, preIdx);

    return root;
}

// Wrapper
TreeNode* buildPreorderInorder(int preorder[], int inorder[], int n) {
    int preIdx = 0;
    return buildFromPreIn(preorder, inorder, 0, n - 1, &preIdx);
}
```

```c
// Uso:
int pre[] = {1, 2, 4, 5, 3, 6, 7};
int in[]  = {4, 2, 5, 1, 3, 7, 6};
TreeNode *root = buildPreorderInorder(pre, in, 7);
```

---

## 15.3 Postorder + Inorder → Árbol

### Algoritmo

```text
Similar a Preorder+Inorder, pero:
  - El ÚLTIMO elemento de Postorder es la RAÍZ (no el primero).
  - Se recorre Postorder de DERECHA A IZQUIERDA.
  - Se construye el subárbol DERECHO ANTES que el izquierdo.
```

### Ejemplo

```text
Postorder: [4, 5, 2, 7, 6, 3, 1]
Inorder:   [4, 2, 5, 1, 3, 7, 6]

Paso 1: Raíz = post[último] = 1
        En inorder idx=3 → izq:[4,2,5], der:[3,7,6]

Paso 2 (derecho primero): post=[7,6,3], in=[3,7,6]
        Raíz = 3, idx=0 → izq:[], der:[7,6]

Paso 3: post=[7,6], in=[7,6]
        Raíz = 6, idx=1 → izq:[7], der:[]

Paso 4: post=[7], in=[7]
        Raíz = 7, hoja.

Ahora el izquierdo del paso 1:
        post=[4,5,2], in=[4,2,5]
        Raíz = 2, idx=1 → izq:[4], der:[5]

Resultado:
            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7       ✓
```

### Implementación

```c
TreeNode* buildFromPostIn(int postorder[], int inorder[],
                           int inStart, int inEnd, int *postIdx) {
    if (inStart > inEnd)
        return NULL;

    int rootVal = postorder[*postIdx];
    (*postIdx)--;       // decrementar (recorremos postorder de derecha a izquierda)
    TreeNode *root = createNode(rootVal);

    if (inStart == inEnd)
        return root;

    int inIdx = findIndex(inorder, inStart, inEnd, rootVal);

    // ⚠️ Construir DERECHO primero (porque recorremos postorder de der→izq)
    root->right = buildFromPostIn(postorder, inorder, inIdx + 1, inEnd, postIdx);
    root->left  = buildFromPostIn(postorder, inorder, inStart, inIdx - 1, postIdx);

    return root;
}

TreeNode* buildPostorderInorder(int postorder[], int inorder[], int n) {
    int postIdx = n - 1;
    return buildFromPostIn(postorder, inorder, 0, n - 1, &postIdx);
}
```

> **⚠️ Error crítico:** Si construyes el izquierdo antes que el derecho en postorder, el `postIdx` se desincroniza y el árbol queda mal. Siempre **derecho primero** con postorder.

---

# PARTE VI — MÉTRICAS Y PROPIEDADES

---

# 16. Altura del Árbol

## 16.1 Definición

La **altura** de un árbol es el número de aristas en el camino más largo desde la raíz hasta una hoja.

```text
Convención: árbol vacío (NULL) tiene altura -1.
            Árbol con solo raíz tiene altura 0.
```

## 16.2 Implementación recursiva

```c
int height(TreeNode *root) {
    if (root == NULL)
        return -1;          // convención: vacío = -1

    int leftH  = height(root->left);
    int rightH = height(root->right);

    return 1 + (leftH > rightH ? leftH : rightH);
}
```

```text
Traza con nuestro árbol:

            1
           / \
          2   3
         / \   \
        4   5   6
               /
              7

height(7) = 1 + max(-1, -1) = 0
height(6) = 1 + max(height(7), -1) = 1 + max(0, -1) = 1
height(4) = 0, height(5) = 0
height(2) = 1 + max(0, 0) = 1
height(3) = 1 + max(-1, 1) = 2
height(1) = 1 + max(1, 2) = 3   ✓
```

| Complejidad | Espacio             |
| ----------- | ------------------- |
| **O(n)**    | O(h) — profundidad de recursión |

## 16.3 Implementación iterativa (level-order)

```c
int heightIterative(TreeNode *root) {
    if (root == NULL) return -1;

    TreeNode *queue[100];
    int front = 0, rear = 0;
    queue[rear++] = root;
    int h = -1;

    while (front < rear) {
        int levelSize = rear - front;   // nodos en este nivel
        h++;

        for (int i = 0; i < levelSize; i++) {
            TreeNode *curr = queue[front++];
            if (curr->left)  queue[rear++] = curr->left;
            if (curr->right) queue[rear++] = curr->right;
        }
    }
    return h;
}
```

---

# 17. Conteo de Nodos

## 17.1 Contar todos los nodos

```c
int countNodes(TreeNode *root) {
    if (root == NULL) return 0;
    return 1 + countNodes(root->left) + countNodes(root->right);
}
```

```text
count(1) = 1 + count(2) + count(3)
         = 1 + (1 + count(4) + count(5)) + (1 + count(NULL) + count(6))
         = 1 + (1 + 1 + 1) + (1 + 0 + (1 + count(7) + count(NULL)))
         = 1 + 3 + (1 + (1 + 1 + 0))
         = 1 + 3 + 3
         = 7   ✓
```

## 17.2 Contar nodos internos (con al menos 1 hijo)

```c
int countInternal(TreeNode *root) {
    if (root == NULL) return 0;
    if (root->left == NULL && root->right == NULL) return 0;   // hoja
    return 1 + countInternal(root->left) + countInternal(root->right);
}
```

## 17.3 Contar nodos con grado exacto (0, 1, o 2)

```c
int countDegree(TreeNode *root, int degree) {
    if (root == NULL) return 0;

    int nodeDegree = (root->left != NULL) + (root->right != NULL);
    int match = (nodeDegree == degree) ? 1 : 0;

    return match + countDegree(root->left, degree)
                 + countDegree(root->right, degree);
}

// Uso:
// countDegree(root, 0)  → hojas
// countDegree(root, 1)  → nodos con 1 hijo
// countDegree(root, 2)  → nodos con 2 hijos
```

| Operación        | Complejidad | Espacio        |
| ---------------- | ----------- | -------------- |
| Count all        | O(n)        | O(h) recursión |
| Count internal   | O(n)        | O(h)           |
| Count by degree  | O(n)        | O(h)           |

---

# 18. Conteo de Hojas

## 18.1 Definición

Una **hoja** (leaf) es un nodo con **grado 0** (sin hijos).

```c
int countLeaves(TreeNode *root) {
    if (root == NULL) return 0;
    if (root->left == NULL && root->right == NULL) return 1;   // es hoja
    return countLeaves(root->left) + countLeaves(root->right);
}
```

```text
Hojas de nuestro árbol: 4, 5, 7
countLeaves(1) = countLeaves(2) + countLeaves(3)
               = (countLeaves(4) + countLeaves(5)) + (0 + countLeaves(6))
               = (1 + 1) + (countLeaves(7) + 0)
               = 2 + 1
               = 3   ✓
```

## 18.2 Iterativo (level-order)

```c
int countLeavesIterative(TreeNode *root) {
    if (root == NULL) return 0;

    TreeNode *queue[100];
    int front = 0, rear = 0;
    queue[rear++] = root;
    int leaves = 0;

    while (front < rear) {
        TreeNode *curr = queue[front++];
        if (curr->left == NULL && curr->right == NULL)
            leaves++;
        if (curr->left)  queue[rear++] = curr->left;
        if (curr->right) queue[rear++] = curr->right;
    }
    return leaves;
}
```

---

# PARTE VII — SÍNTESIS

---

# 19. Resumen de Complejidad

## Operaciones sobre árboles binarios

| Operación               | Complejidad | Espacio          | Nota                          |
| ----------------------- | ----------- | ---------------- | ----------------------------- |
| **Preorder** (rec)      | O(n)        | O(h)             | h = altura                    |
| **Preorder** (iter)     | O(n)        | O(h)             | 1 stack                       |
| **Inorder** (rec)       | O(n)        | O(h)             |                               |
| **Inorder** (iter)      | O(n)        | O(h)             | 1 stack                       |
| **Postorder** (rec)     | O(n)        | O(h)             |                               |
| **Postorder** (iter)    | O(n)        | O(n)             | 2 stacks                      |
| **Level-order**         | O(n)        | O(w)             | w = ancho máximo              |
| **Height**              | O(n)        | O(h)             |                               |
| **Count nodes**         | O(n)        | O(h)             |                               |
| **Count leaves**        | O(n)        | O(h)             |                               |
| **Build from Pre+In**   | O(n²)*      | O(h)             | *O(n) con hash para findIndex |
| **Build from Post+In**  | O(n²)*      | O(h)             | *O(n) con hash para findIndex |

```text
h varía entre:
  Mejor caso (árbol balanceado):  h = O(log n)
  Peor caso (árbol sesgado):     h = O(n)
```

## Espacio de representación

| Representación     | Espacio                      | Mejor para                |
| ------------------ | ---------------------------- | ------------------------- |
| Array              | O(2^h) peor, O(n) completo  | Heaps, complete BT        |
| Linked (nodos)     | O(n) siempre                 | Árboles generales         |

---

# 20. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                          | Consecuencia                               |
| ---------------------------------------------- | ------------------------------------------ |
| No verificar `root == NULL` (caso base)        | Segfault al desreferenciar NULL            |
| Confundir altura (-1 vacío) vs nivel (0 raíz)  | Cálculos off-by-one                        |
| Olvidar `return` en funciones recursivas        | Resultado indefinido                       |
| Construir postorder+inorder con izq antes de der | Árbol completamente incorrecto           |
| Push right antes de left en preorder iterativo  | Invertir el resultado (inverso correcto)   |
| No liberar nodos al destruir el árbol           | Memory leak de todo el árbol               |
| Usar array para árboles sesgados                | Desperdicio exponencial de espacio         |
| Confundir Strict con Complete                   | Implementaciones incorrectas               |
| No pasar `preIdx` por referencia                | Cada rama usa el mismo índice (duplicados) |
| Asumir que un recorrido basta para reconstruir  | Múltiples árboles posibles                 |

### ✅ Buenas Prácticas

| Práctica                                        | Razón                                       |
| ----------------------------------------------- | ------------------------------------------- |
| **Siempre** empezar con `if (root == NULL)`     | Caso base de toda recursión                 |
| Dibujar el árbol ANTES de codificar             | Visualizar estructura y recorridos          |
| Verificar con árbol vacío, 1 nodo, sesgado      | Edge cases que revelan bugs                 |
| Usar `postorder` para liberar un árbol           | Libera hijos antes que el padre             |
| Pasar contadores por **referencia** (`int *`)    | Mantener estado global en recursión         |
| Usar hash map para `findIndex` en construcción  | O(1) búsqueda → O(n) total vs O(n²)        |
| Preferir representación linked para generales   | Funciona para cualquier forma               |
| Usar array solo para heaps/complete trees       | Aprovecha la fórmula hijo=2i sin desperdicio|

```c
// ✅ Liberar un árbol completo (postorder)
void freeTree(TreeNode *root) {
    if (root == NULL) return;
    freeTree(root->left);      // liberar hijos primero
    freeTree(root->right);
    free(root);                // luego liberar la raíz
}
// Si usaras preorder: free(root) y luego root->left → ¡segfault!
```

---

# 21. Intuición de Ingeniería

> **Un árbol es una lista enlazada que se bifurca.**
> Cada operación sobre árboles es esencialmente **"hacer algo en cada nodo" + "decidir qué subárbol explorar"**.
> Si entiendes recursión, entiendes árboles. Si no, los árboles te enseñarán recursión.

### El patrón recursivo universal

```c
resultado operacion(TreeNode *root) {
    if (root == NULL) return caso_base;           // 1. Caso base

    resultado izq = operacion(root->left);        // 2. Resolver izquierdo
    resultado der = operacion(root->right);       // 3. Resolver derecho

    return combinar(root->data, izq, der);        // 4. Combinar
}
```

```text
height:      combinar = 1 + max(izq, der)
count:       combinar = 1 + izq + der
countLeaves: combinar = izq + der  (si es hoja, return 1)
sum:         combinar = root->data + izq + der
```

> **Casi toda operación sobre árboles sigue este patrón.** Cambia solo el caso base y la función de combinación.

### El mapa de recorridos

```text
                    ┌──────────┐
                    │  DFS     │──── Usa STACK
                    │          │
                    ├──────────┤
                    │ Preorder │  N L R  →  Serializar, copiar
                    │ Inorder  │  L N R  →  BST en orden
                    │ Postorder│  L R N  →  Borrar, evaluar expr.
                    └──────────┘
                    ┌──────────┐
                    │  BFS     │──── Usa QUEUE
                    │          │
                    ├──────────┤
                    │ Level    │  Nivel por nivel → shortest path
                    └──────────┘
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
| **Trees (este)**                 | Trees.md             |
