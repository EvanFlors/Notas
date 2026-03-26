# 2-3 Trees y 2-3-4 Trees — Balance Perfecto por Diseño

> **Idea central:** Un BST puede degenerarse hasta O(n). Un AVL lo previene con rotaciones,
> pero conceptualmente sigue siendo un parche sobre una estructura inherentemente frágil.
> Los **2-3 Trees** y **2-3-4 Trees** toman un camino diferente: permiten que un nodo
> almacene **más de una clave** y tenga **más de dos hijos**, logrando **balance perfecto**
> no como excepción, sino como **consecuencia natural** de sus reglas de inserción.
> Estas estructuras son la **base teórica de los Red-Black Trees**, el estándar industrial.

---

## Tabla de Contenidos

**Parte I — Search Trees y el Problema del Balance**
1. [BST: Repaso y Limitaciones](#1-bst-repaso-y-limitaciones)
2. [El Espectro del Balance](#2-el-espectro-del-balance)

**Parte II — 2-3 Trees**
3. [Definición y Propiedades](#3-definición-y-propiedades)
4. [Búsqueda en 2-3 Trees](#4-búsqueda-en-2-3-trees)
5. [Inserción en 2-3 Trees](#5-inserción-en-2-3-trees)
6. [Construcción Paso a Paso](#6-construcción-paso-a-paso)
7. [Eliminación en 2-3 Trees (Conceptual)](#7-eliminación-en-2-3-trees-conceptual)

**Parte III — 2-3-4 Trees**
8. [Extensión: Nodos con 4 hijos](#8-extensión-nodos-con-4-hijos)
9. [Inserción en 2-3-4 Trees](#9-inserción-en-2-3-4-trees)
10. [Top-Down vs Bottom-Up](#10-top-down-vs-bottom-up)
11. [Construcción Paso a Paso](#11-construcción-paso-a-paso)
12. [Ventajas sobre 2-3 Trees](#12-ventajas-sobre-2-3-trees)

**Parte IV — De Multi-way a Binario: Hacia Red-Black Trees**
13. [Motivación: ¿Por qué no implementar 2-3-4 directamente?](#13-motivación-por-qué-no-implementar-2-3-4-directamente)
14. [Correspondencia 2-3-4 → Red-Black](#14-correspondencia-2-3-4--red-black)
15. [Las 5 Propiedades Red-Black](#15-las-5-propiedades-red-black)
16. [Intuición del Balanceo Red-Black](#16-intuición-del-balanceo-red-black)

**Parte V — Análisis**
17. [Complejidad Comparada](#17-complejidad-comparada)
18. [Resumen de Propiedades Estructurales](#18-resumen-de-propiedades-estructurales)

**Parte VI — Síntesis**
19. [Errores Comunes y Buenas Prácticas](#19-errores-comunes-y-buenas-prácticas)
20. [Intuición de Ingeniería](#20-intuición-de-ingeniería)

---

# PARTE I — SEARCH TREES Y EL PROBLEMA DEL BALANCE

---

# 1. BST: Repaso y Limitaciones

## 1.1 La promesa y la realidad

Un Binary Search Tree promete O(log n) para búsqueda, inserción y eliminación. Pero esa promesa depende de una condición: **que el árbol esté razonablemente balanceado**.

```text
Mejor caso (balanceado):          Peor caso (degenerado):

         50                           10
        /  \                            \
      30    70                          20
     / \   / \                            \
    20 40 60 80                           30
                                            \
    h = 2                                   40
    n = 7                                     \
    h ≈ log₂(n)                               50

    Search: O(log n)                   Search: O(n)
    Insert: O(log n)                   Insert: O(n)
    Delete: O(log n)                   Delete: O(n)
```

## 1.2 ¿Cuándo degenera un BST?

```text
Secuencias problemáticas:
  • Datos ordenados:       1, 2, 3, 4, 5, 6, 7    → cadena derecha
  • Datos inversamente:    7, 6, 5, 4, 3, 2, 1    → cadena izquierda
  • Datos casi ordenados:  1, 2, 3, 10, 4, 5, 6   → casi cadena
```

> **Conclusión:** Un BST estándar es un apuesta optimista. Si los datos llegan en buen
> orden, funciona bien. Si no, degenera. Necesitamos una estructura que **garantice** balance.

## 1.3 Tabla de complejidades del BST

| Operación  | Mejor Caso | Caso Promedio | Peor Caso  |
| ---------- | ---------- | ------------- | ---------- |
| Búsqueda   | O(1)       | O(log n)      | O(n)       |
| Inserción  | O(1)       | O(log n)      | O(n)       |
| Eliminación| O(log n)   | O(log n)      | O(n)       |
| Espacio    |            |               | O(n)       |

---

# 2. El Espectro del Balance

## 2.1 Estrategias de balanceo

```text
Estrategia              | Ejemplo       | Filosofía
──────────────────────────────────────────────────────────────
No hacer nada           | BST           | Esperanza (datos aleatorios)
Rotaciones post-hoc     | AVL           | Detectar y corregir
Rotaciones perezosas    | Red-Black     | Corregir lo mínimo necesario
Balance por estructura  | 2-3, 2-3-4   | Imposible desbalancear
Aleatorización          | Treap, Skip   | Probabilísticamente balanceado
```

## 2.2 La idea clave: cambiar la estructura del nodo

```text
BST:     Cada nodo tiene 1 clave y 2 hijos
2-3:     Cada nodo tiene 1-2 claves y 2-3 hijos
2-3-4:   Cada nodo tiene 1-3 claves y 2-4 hijos

Al permitir más claves por nodo, podemos ABSORBER nuevas inserciones
sin aumentar la altura del árbol.
```

## 2.3 ¿Por qué balance perfecto?

En un 2-3 tree (y 2-3-4 tree), **todas las hojas están al mismo nivel**. Esto no es un objetivo que se intenta alcanzar: es una **consecuencia inevitable** de las reglas de inserción.

```text
BST: la altura varía entre log₂(n) y n
AVL: la altura varía entre log₂(n) y 1.44·log₂(n)
2-3: la altura es EXACTAMENTE entre log₃(n) y log₂(n)
     → todas las hojas al mismo nivel → balance perfecto
```

---

# PARTE II — 2-3 TREES

---

# 3. Definición y Propiedades

## 3.1 ¿Qué es un 2-3 Tree?

Un **2-3 Tree** es un árbol de búsqueda donde:

1. **Cada nodo interno** es un **2-nodo** o un **3-nodo**.
2. **Todas las hojas** están en el **mismo nivel**.

### 2-nodo (igual que BST)

```text
    [K]
   /   \
  <K    >K

  • 1 clave: K
  • 2 hijos: izquierdo (< K), derecho (> K)
```

### 3-nodo (novedad)

```text
   [K₁ | K₂]
   /   |    \
 <K₁  K₁<·<K₂  >K₂

  • 2 claves: K₁ < K₂
  • 3 hijos: izquierdo (< K₁), medio (entre K₁ y K₂), derecho (> K₂)
```

## 3.2 Propiedades formales

| Propiedad                          | Descripción                                                           |
| ---------------------------------- | --------------------------------------------------------------------- |
| **Balance perfecto**               | Todas las hojas están al mismo nivel (distancia raíz→hoja constante)  |
| **Nodo 2**                         | 1 clave, 2 hijos                                                     |
| **Nodo 3**                         | 2 claves, 3 hijos                                                    |
| **Orden de búsqueda**              | Las claves dividen los rangos de valores como en BST                  |
| **Hojas**                          | No tienen hijos (pueden ser 2-nodos o 3-nodos con datos)             |
| **Crecimiento**                    | El árbol crece **hacia arriba**, no hacia abajo                       |

## 3.3 Altura de un 2-3 tree

```text
Sea n = número de claves, h = altura del árbol.

Caso mínimo (todos son 3-nodos):
  Cada nivel tiene el máximo de claves.
  Nodos por nivel i: 3ⁱ
  Claves totales: 2·(3⁰ + 3¹ + ... + 3ʰ) = 2·(3^(h+1) - 1)/2 = 3^(h+1) - 1
  → h ≥ log₃(n+1) - 1

Caso máximo (todos son 2-nodos):
  Equivale a un árbol binario perfecto.
  Claves totales: 2^(h+1) - 1
  → h ≤ log₂(n+1) - 1

Resultado:
  ⌈log₃(n+1)⌉ - 1  ≤  h  ≤  ⌈log₂(n+1)⌉ - 1
```

> **En cualquier caso, h = O(log n).** No hay peor caso lineal.

## 3.4 Ejemplo de un 2-3 tree

```text
                  [30]
                /      \
          [10 | 20]     [40 | 50]
          /   |   \     /   |   \
        [5]  [15] [25] [35] [45] [55 | 60]

Verificación:
  Raíz [30]:
    Izq: {5, 10, 15, 20, 25} < 30  ✓
    Der: {35, 40, 45, 50, 55, 60} > 30  ✓

  Nodo [10|20]:
    Izq: {5} < 10  ✓
    Med: {15}, 10 < 15 < 20  ✓
    Der: {25} > 20  ✓

  Todas las hojas al nivel 2  ✓
```

---

# 4. Búsqueda en 2-3 Trees

## 4.1 Algoritmo

```text
Search(node, key):
  if node is NULL:
    return NOT_FOUND

  if node is 2-node [K]:
    if key == K: return FOUND
    if key < K:  return Search(node.left, key)
    if key > K:  return Search(node.right, key)

  if node is 3-node [K1 | K2]:
    if key == K1 or key == K2: return FOUND
    if key < K1:              return Search(node.left, key)
    if K1 < key < K2:        return Search(node.middle, key)
    if key > K2:              return Search(node.right, key)
```

## 4.2 Ejemplo paso a paso

```text
Buscar 45 en:

                  [30]
                /      \
          [10 | 20]     [40 | 50]
          /   |   \     /   |   \
        [5]  [15] [25] [35] [45] [55]

Paso 1: Raíz = [30]. 45 > 30 → ir a la derecha
Paso 2: Nodo = [40|50]. 40 < 45 < 50 → ir al hijo medio
Paso 3: Nodo = [45]. 45 == 45 → FOUND ✓

Comparaciones: 4 (vs. 30, vs. 40, vs. 50, vs. 45)
```

## 4.3 Buscar un valor que no existe

```text
Buscar 42 en el mismo árbol:

Paso 1: Raíz = [30]. 42 > 30 → derecha
Paso 2: Nodo = [40|50]. 40 < 42 < 50 → medio
Paso 3: Nodo = [45]. 42 ≠ 45, 42 < 45 → izquierda = NULL
Paso 4: NULL → NOT_FOUND ✓
```

## 4.4 Complejidad de búsqueda

```text
En cada nodo, hacemos máximo 2 comparaciones (en un 3-nodo).
La altura es O(log n).
→ Búsqueda: O(log n) siempre (no hay peor caso lineal).
```

---

# 5. Inserción en 2-3 Trees

## 5.1 Filosofía de inserción

La inserción en 2-3 trees sigue una filosofía radicalmente diferente a BST:

```text
BST:    Busca el lugar → crea un nuevo nodo hoja
        → el árbol crece HACIA ABAJO

2-3:    Busca la hoja → ABSORBE la clave en la hoja existente
        → si la hoja se desborda (3 claves), SPLIT y propaga hacia ARRIBA
        → el árbol crece HACIA ARRIBA (la raíz se divide)
```

> **Clave:** En un 2-3 tree, **siempre se inserta en una hoja**. Nunca se crea un nuevo
> nivel inferior. Si la raíz se divide, se crea un nuevo nivel **superior**.
> Por eso todas las hojas siempre están al mismo nivel.

## 5.2 Los tres casos de inserción

### Caso 1: La hoja es un 2-nodo → Absorber

```text
Insertar 25 en [20]:

  ANTES:    [20]              DESPUÉS:    [20 | 25]
            / \                           /   |    \

→ El 2-nodo se convierte en 3-nodo. Sin propagación. Trivial.
```

### Caso 2: La hoja es un 3-nodo → Split

```text
Insertar 30 en [20 | 25]:

  El nodo tiene ahora 3 claves: [20, 25, 30] → OVERFLOW

  Split: la clave MEDIA sube al padre.

  ANTES:     [20 | 25]
             /   |   \

  Split de [20, 25, 30]:

    La mediana (25) sube.
    Se crean dos nodos: [20] y [30]

             [25]  ← sube al padre
            /    \
          [20]   [30]
```

### Caso 3: El split se propaga al padre

```text
Si el padre también es un 3-nodo, el split se propaga hacia arriba.
Si llega a la raíz y la raíz se divide:
  → Se crea una nueva raíz
  → La altura del árbol aumenta en 1
  → TODAS las hojas siguen al mismo nivel (se agregó un nivel ARRIBA)
```

## 5.3 Pseudocódigo de inserción

```text
Insert(tree, key):
  1. Si el árbol está vacío:
       crear un nodo hoja con key → return

  2. Buscar la HOJA donde key debería estar (como en búsqueda)

  3. Si la hoja es un 2-nodo:
       Agregar key a la hoja → convertirla en 3-nodo → DONE

  4. Si la hoja es un 3-nodo:
       Temporalmente la hoja tiene 3 claves [a, b, c] (ordenadas)
       Split:
         mediana = b
         nodo_izq = [a]
         nodo_der = [c]
         PUSH_UP(mediana, nodo_izq, nodo_der, padre)

  PUSH_UP(key, left_child, right_child, parent):
    Si parent es NULL (estamos en la raíz):
      crear nueva raíz con key, hijos = left_child, right_child
      → la altura del árbol creció en 1

    Si parent es un 2-nodo:
      Absorber key en parent → convertir en 3-nodo
      Reorganizar los hijos → DONE

    Si parent es un 3-nodo:
      Split parent con key incluido → recursión hacia arriba
```

---

# 6. Construcción Paso a Paso

## 6.1 Insertar: 10, 20, 30, 40, 50, 60, 70

### Insert 10

```text
  [10]

  ← Árbol vacío, crear hoja.
```

### Insert 20

```text
  [10 | 20]

  ← La hoja [10] es 2-nodo → absorber → se convierte en 3-nodo.
```

### Insert 30

```text
  La hoja [10 | 20] es 3-nodo → overflow con [10, 20, 30]

  Split: mediana = 20

       [20]
      /    \
   [10]    [30]

  ← La raíz se dividió. Altura creció de 0 a 1. Todas las hojas en nivel 1.
```

### Insert 40

```text
  Buscar hoja para 40: 40 > 20 → ir a [30]
  [30] es 2-nodo → absorber.

       [20]
      /    \
   [10]    [30 | 40]
```

### Insert 50

```text
  Buscar hoja para 50: 50 > 20 → ir a [30|40]
  [30|40] es 3-nodo → overflow con [30, 40, 50]

  Split: mediana = 40, sube al padre [20]

  Padre [20] es 2-nodo → absorber 40.

       [20 | 40]
      /    |    \
   [10]  [30]   [50]

  ← Sin propagación adicional. Hojas siguen en nivel 1.
```

### Insert 60

```text
  Buscar hoja para 60: 60 > 40 → ir a [50]
  [50] es 2-nodo → absorber.

       [20 | 40]
      /    |    \
   [10]  [30]   [50 | 60]
```

### Insert 70

```text
  Buscar hoja para 70: 70 > 40 → ir a [50|60]
  [50|60] es 3-nodo → overflow con [50, 60, 70]

  Split: mediana = 60, sube al padre [20|40]

  Padre [20|40] es 3-nodo → overflow con [20, 40, 60]

  Split del padre: mediana = 40

           [40]               ← nueva raíz
          /    \
       [20]    [60]
       / \     / \
    [10] [30] [50] [70]

  ← La raíz se dividió. Altura creció de 1 a 2.
  ← Todas las hojas siguen en el mismo nivel (nivel 2).

  Verificación: 7 claves, altura 2.
    log₃(8)-1 ≈ 0.89 ≤ 2 ≤ log₂(8)-1 = 2  ✓
```

## 6.2 Observaciones críticas

```text
┌─────────────────────────────────────────────────────────┐
│  1. El árbol NUNCA crece hacia abajo.                   │
│     Solo hacia arriba (cuando la raíz se divide).       │
│                                                         │
│  2. Todas las hojas SIEMPRE están al mismo nivel.       │
│     Esto es balance perfecto por diseño.                │
│                                                         │
│  3. Se insertaron datos ORDENADOS (10,20,...,70) y      │
│     el árbol quedó perfectamente balanceado.            │
│     Un BST habría generado una cadena derecha.          │
│                                                         │
│  4. Cada inserción es O(log n):                         │
│     - Búsqueda de la hoja: O(log n)                     │
│     - Splits en el camino hacia arriba: máximo O(log n) │
│     - Cada split es O(1)                                │
└─────────────────────────────────────────────────────────┘
```

## 6.3 Segundo ejemplo: Insertar 50, 30, 70, 20, 40, 60, 80, 10

### Insert 50

```text
  [50]
```

### Insert 30

```text
  [30 | 50]
```

### Insert 70

```text
  [30, 50, 70] → overflow

  Split: mediana = 50

       [50]
      /    \
   [30]    [70]
```

### Insert 20

```text
  20 < 50 → ir a [30]. Es 2-nodo → absorber.

       [50]
      /    \
  [20|30]  [70]
```

### Insert 40

```text
  40 < 50 → ir a [20|30]. Es 3-nodo → overflow [20,30,40]

  Split: mediana = 30, sube al padre [50].
  [50] es 2-nodo → absorber.

       [30 | 50]
      /    |    \
   [20]  [40]   [70]
```

### Insert 60

```text
  60 > 50 → ir a [70]. Es 2-nodo → absorber.

       [30 | 50]
      /    |    \
   [20]  [40]   [60 | 70]
```

### Insert 80

```text
  80 > 50 → ir a [60|70]. Es 3-nodo → overflow [60,70,80]

  Split: mediana = 70, sube al padre [30|50].
  [30|50] es 3-nodo → overflow [30, 50, 70]

  Split del padre: mediana = 50

           [50]
          /    \
       [30]    [70]
       / \     / \
    [20] [40] [60] [80]
```

### Insert 10

```text
  10 < 50 → 10 < 30 → ir a [20]. Es 2-nodo → absorber.

           [50]
          /    \
       [30]    [70]
       / \     / \
  [10|20] [40] [60] [80]

  Resultado final: 8 claves, altura 2, balance perfecto.
```

---

# 7. Eliminación en 2-3 Trees (Conceptual)

## 7.1 Filosofía de eliminación

La eliminación en 2-3 Trees es la operación inversa: en lugar de **splits** (dividir nodos desbordados), usamos **merges** (fusionar) y **redistribuciones** (tomar prestado de un hermano).

```text
Inserción:  overflow  → split  → propagar hacia arriba
Eliminación: underflow → merge/redistribuir → propagar hacia arriba
```

## 7.2 Los casos de eliminación

### Caso 1: Eliminar de un 3-nodo

```text
Si el nodo que contiene la clave es un 3-nodo:
  → Simplemente quitar la clave.
  → El 3-nodo se convierte en 2-nodo.
  → No hay underflow. Trivial.

  Eliminar 20 de [10 | 20]:

  ANTES: [10 | 20]     DESPUÉS: [10]
```

### Caso 2: Eliminar de un 2-nodo con hermano 3-nodo → Redistribuir

```text
Si el nodo es un 2-nodo (quitarle la clave lo deja vacío):
  → Si un HERMANO es un 3-nodo, REDISTRIBUIR:
    1. Rotar una clave del hermano a través del padre.
    2. El hermano se hace 2-nodo, el nodo vacío recibe una clave.

  Ejemplo — Eliminar 10:

  ANTES:           [30]              DESPUÉS:         [40]
                  /    \                              /    \
               [10]   [40 | 60]                   [30]    [60]

  → El hermano derecho [40|60] es 3-nodo.
  → 30 baja del padre, 40 sube al padre.
  → Resultado: redistribución sin cambio de altura.
```

### Caso 3: Eliminar de un 2-nodo con hermano 2-nodo → Merge

```text
Si el nodo es 2-nodo y el hermano también es 2-nodo:
  → MERGE: fusionar nodo, hermano y la clave del padre en un 3-nodo.
  → El padre pierde una clave → puede causar underflow en el padre.
  → Si el padre también queda vacío, propagar el merge hacia arriba.

  Ejemplo — Eliminar 10:

  ANTES:           [30]              DESPUÉS:    [30 | 60]
                  /    \
               [10]    [60]

  → Hermano [60] es 2-nodo. No se puede redistribuir.
  → Merge: fusionar [10], 30, [60] → [30 | 60]
  → Padre queda vacío → [30|60] se convierte en la nueva raíz.
  → La altura decreció en 1.
```

### Caso 4: Eliminar un nodo interno

```text
Similar a BST: reemplazar con el sucesor inorder (o predecesor).
El sucesor inorder siempre está en una hoja.
→ Reducir la eliminación interna a eliminación en hoja.
→ Aplicar los casos 1, 2, o 3 en la hoja.
```

## 7.3 Resumen de eliminación

```text
┌─────────────────────────────────────────────────────┐
│  Eliminar de 3-nodo       → quitar clave (trivial)  │
│  Eliminar de 2-nodo:                                 │
│    Hermano es 3-nodo      → redistribuir (rotar)     │
│    Hermano es 2-nodo      → merge + propagar arriba  │
│  Eliminar nodo interno    → reducir a hoja           │
│                                                      │
│  Peor caso: merges hasta la raíz → O(log n)          │
│  La altura puede decrecer (inverso del split)        │
└─────────────────────────────────────────────────────┘
```

---

# PARTE III — 2-3-4 TREES

---

# 8. Extensión: Nodos con 4 hijos

## 8.1 ¿Qué es un 2-3-4 Tree?

Un **2-3-4 Tree** (también llamado **B-tree de orden 4**) extiende el 2-3 tree permitiendo un tercer tipo de nodo:

### 4-nodo

```text
   [K₁ | K₂ | K₃]
   /   |    |    \
 <K₁  K₁<·<K₂  K₂<·<K₃  >K₃

  • 3 claves: K₁ < K₂ < K₃
  • 4 hijos
```

### Los tres tipos de nodos

```text
2-nodo:     [a]           1 clave, 2 hijos
           / \

3-nodo:   [a | b]         2 claves, 3 hijos
          / | \

4-nodo:  [a | b | c]      3 claves, 4 hijos
         / | | \
```

## 8.2 Propiedades formales

| Propiedad                    | 2-3 Tree             | 2-3-4 Tree           |
| ---------------------------- | -------------------- | -------------------- |
| Claves por nodo              | 1-2                  | 1-3                  |
| Hijos por nodo               | 2-3                  | 2-4                  |
| Balance                      | Perfecto             | Perfecto             |
| Hojas al mismo nivel         | Sí                   | Sí                   |
| Altura (n claves)            | Θ(log n)             | Θ(log n)             |
| Altura máxima                | log₂(n+1)            | log₂(n+1)            |
| Altura mínima                | log₃(n+1)            | log₄(n+1)            |

## 8.3 ¿Por qué extender a 4 hijos?

```text
Razón 1: Inserción más simple
  En 2-3 trees, un split de 3-nodo puede propagarse hacia arriba.
  En 2-3-4 trees, podemos hacer SPLITS PREVENTIVOS en el camino
  hacia abajo (top-down), eliminando la propagación.

Razón 2: Relación directa con Red-Black Trees
  Un 2-3-4 tree tiene una correspondencia EXACTA con Red-Black Trees.
  Cada nodo 2, 3 y 4 se mapea a una configuración específica de
  nodos rojos y negros.

Razón 3: Base para B-Trees
  El 2-3-4 tree es un B-tree de orden 4.
  Generalizar a orden m → B-trees para bases de datos.
```

---

# 9. Inserción en 2-3-4 Trees

## 9.1 La regla de inserción

La inserción sigue la misma filosofía que en 2-3 trees:
1. Buscar la hoja donde corresponde la clave.
2. Absorber si hay espacio.
3. Split si hay overflow.

Pero con una mejora crucial: podemos elegir entre dos estrategias.

## 9.2 Bottom-Up Insertion (como 2-3 trees)

```text
1. Bajar hasta la hoja
2. Insertar en la hoja
3. Si la hoja era un 4-nodo → overflow
4. Split: mediana sube al padre
5. Si el padre era un 4-nodo → propagar split
6. Repetir hasta que no haya overflow
```

### Split de un 4-nodo

```text
  [a | b | c]  →  la mediana b sube al padre

          [b]         ← sube
         /   \
       [a]   [c]     ← se divide en dos 2-nodos
```

## 9.3 Top-Down Insertion (exclusivo de 2-3-4)

```text
IDEA: Mientras BAJAMOS buscando la hoja, si encontramos un 4-nodo,
lo dividimos ANTES de continuar. Así garantizamos que cuando llegamos
a la hoja, el padre NUNCA es un 4-nodo → el split nunca se propaga.

Algoritmo:
  1. Comenzar en la raíz
  2. En cada nodo del camino hacia la hoja:
     a. Si es un 4-nodo → split preventivo
     b. Continuar al hijo apropiado
  3. Insertar en la hoja (que será 2-nodo o 3-nodo, garantizado)
  4. Si la hoja era 3-nodo → split, pero el padre no es 4-nodo → OK
```

> **Ventaja:** No requiere volver hacia arriba (no hay propagación).
> La inserción es **single-pass** (una sola pasada hacia abajo).
> Esto es ideal para implementaciones no recursivas.

## 9.4 ¿Cómo se hace un split preventivo (top-down)?

```text
Al bajar, encontramos un 4-nodo [a|b|c] con padre P:

ANTES:
        [... P ...]
            |
       [a | b | c]
       / |   |  \
      T1 T2  T3  T4

DESPUÉS del split preventivo:
        [... P, b, ...]    ← b se incorpora al padre
           /   \
         [a]   [c]
         / \   / \
        T1 T2 T3 T4

El padre P absorbe b. Como garantizamos que P NO es 4-nodo
(lo habríamos dividido antes), siempre hay espacio.
```

---

# 10. Top-Down vs Bottom-Up

## 10.1 Comparación

| Aspecto                | Bottom-Up           | Top-Down              |
| ---------------------- | ------------------- | --------------------- |
| Dirección              | Baja, luego sube    | Solo baja             |
| Propagación de splits  | Posible             | Nunca                 |
| Pases sobre el árbol   | 2 (bajar + subir)   | 1 (solo bajar)        |
| Requiere recursión     | Natural con recur.  | Funciona iterativo    |
| Implementación         | Más simple concepto | Más eficiente         |
| Relación con Red-Black | —                   | Base de RB insert     |
| Usado en 2-3 trees     | ✓ (obligatorio)     | ✗ (necesita 4-nodos)  |

## 10.2 ¿Por qué top-down es exclusivo de 2-3-4?

```text
En un 2-3 tree, el nodo máximo es un 3-nodo (2 claves).
Si al bajar encontramos un 3-nodo, NO podemos dividirlo preventivamente
porque no está en overflow. Solo se desborda cuando llega la 3ra clave.

En un 2-3-4 tree, el nodo máximo es un 4-nodo (3 claves).
Si al bajar encontramos un 4-nodo, SÍ podemos dividirlo preventivamente:
  → Su mediana sube al padre (que tiene máximo 2 claves → puede absorber).
  → Los dos nodos resultantes (2-nodos) tienen espacio para absorber.

El 4-nodo actúa como un "buffer" que permite anticipar el split.
```

## 10.3 ¿Por qué esto importa para Red-Black Trees?

```text
El algoritmo top-down de 2-3-4 trees se traduce DIRECTAMENTE
a la inserción de Red-Black Trees:

  Split preventivo de 4-nodo  →  Recoloreo (color flip) en Red-Black
  No hay propagación            →  Inserción single-pass
  Rotaciones después del split →  Rotaciones en Red-Black

Esta es la razón por la que se estudian 2-3-4 trees:
son la BASE CONCEPTUAL de los Red-Black Trees.
```

---

# 11. Construcción Paso a Paso

## 11.1 Insertar (top-down): 10, 20, 30, 40, 50, 60, 70

### Insert 10

```text
  [10]
```

### Insert 20

```text
  [10 | 20]
```

### Insert 30

```text
  [10 | 20 | 30]

  ← Ahora es un 4-nodo. Esto es válido en 2-3-4 trees.
  ← (En 2-3 trees ya habría sido un overflow)
```

### Insert 40

```text
  Vamos a bajar buscando dónde insertar 40.
  La raíz es un 4-nodo [10|20|30] → split preventivo ANTES de insertar.

  Split de [10|20|30]:
    Mediana = 20 → nueva raíz
    [10] a la izquierda, [30] a la derecha

       [20]
      /    \
   [10]    [30]

  Ahora insertamos 40: 40 > 20 → ir a [30]. Es 2-nodo → absorber.

       [20]
      /    \
   [10]   [30 | 40]
```

### Insert 50

```text
  Bajar: 50 > 20 → ir a [30|40]. Es 3-nodo → no se divide (no es 4-nodo).
  Absorber 50 en [30|40].

       [20]
      /    \
   [10]   [30 | 40 | 50]
```

### Insert 60

```text
  Bajar: 60 > 20 → ir a [30|40|50]. ¡Es 4-nodo! → split preventivo.

  Split de [30|40|50]:
    Mediana = 40 → sube al padre [20]
    [30] a la izquierda, [50] a la derecha

       [20 | 40]
      /    |    \
   [10]  [30]   [50]

  Padre [20] era 2-nodo → absorbe 40 → se hace 3-nodo [20|40]. OK.

  Ahora insertamos 60: 60 > 40 → ir a [50]. Es 2-nodo → absorber.

       [20 | 40]
      /    |    \
   [10]  [30]   [50 | 60]
```

### Insert 70

```text
  Bajar: 70 > 40 → ir a [50|60]. Es 3-nodo → no se divide.
  Absorber 70.

       [20 | 40]
      /    |    \
   [10]  [30]   [50 | 60 | 70]

  Resultado: 7 claves, altura 1.
```

## 11.2 Comparación del mismo ejemplo con 2-3 tree

```text
2-3 Tree (insertar 10,20,30,40,50,60,70):

           [40]
          /    \
       [20]    [60]
       / \     / \
    [10] [30] [50] [70]

    Altura: 2, 7 nodos

2-3-4 Tree (insertar 10,20,30,40,50,60,70):

       [20 | 40]
      /    |    \
   [10]  [30]   [50 | 60 | 70]

    Altura: 1, 4 nodos (pero almacenan 7 claves)

→ El 2-3-4 tree puede tener menor altura (más claves por nodo).
```

---

# 12. Ventajas sobre 2-3 Trees

## 12.1 Tabla comparativa

| Aspecto                        | 2-3 Tree              | 2-3-4 Tree            |
| ------------------------------ | --------------------- | --------------------- |
| Tipos de nodos                 | 2-nodo, 3-nodo        | 2, 3 y 4-nodo         |
| Altura máxima                  | log₂(n+1) - 1         | log₂(n+1) - 1         |
| Altura mínima                  | log₃(n+1) - 1         | log₄(n+1) - 1         |
| Inserción top-down             | No posible             | ✓ (single-pass)       |
| Propagación de splits          | Posible                | Evitable (top-down)   |
| Correspondencia con Red-Black  | Parcial (2-3 → LLRB)  | Exacta (2-3-4 → RB)   |
| Splits por inserción           | Amortizado O(1)        | Amortizado O(1)        |
| Implementación directa         | Compleja (2 tipos)     | Más compleja (3 tipos) |
| Implementación vía Red-Black   | LLRB (Sedgewick)       | Red-Black clásico      |

## 12.2 ¿Cuándo usar cada uno?

```text
En la práctica, NINGUNO se implementa directamente:
  • 2-3 Trees    → se implementan como Left-Leaning Red-Black Trees
  • 2-3-4 Trees  → se implementan como Red-Black Trees clásicos

Se estudian como MODELOS CONCEPTUALES para entender Red-Black Trees,
no como estructuras de datos para implementar directamente.
```

---

# PARTE IV — DE MULTI-WAY A BINARIO: HACIA RED-BLACK TREES

---

# 13. Motivación: ¿Por qué no implementar 2-3-4 directamente?

## 13.1 El problema de implementación

```text
En un 2-3-4 tree, cada nodo puede tener 2, 3 o 4 hijos.
Implementar esto requiere:

struct Node234 {
    int keys[3];       // hasta 3 claves
    Node234* children[4]; // hasta 4 hijos
    int numKeys;       // 1, 2 o 3
};

Problemas:
  1. Desperdicio de memoria: un 2-nodo usa 1 clave pero reserva 3
  2. Código lleno de condicionales (if numKeys == 1... elif 2... elif 3...)
  3. Comparaciones por nodo: hasta 3 (vs. 1 en binario)
  4. Cache-unfriendly: nodos grandes y dispersos
```

## 13.2 La solución: representar como árbol binario

```text
¿Y si pudiéramos representar un 2-3-4 tree como un árbol BINARIO,
donde cada nodo tiene exactamente 1 clave y 2 hijos?

→ Tendríamos la implementación simple de un BST
→ Con las garantías de balance de un 2-3-4 tree

Esa representación binaria es exactamente un RED-BLACK TREE.
```

> **Red-Black Tree = 2-3-4 Tree disfrazado de árbol binario.**

---

# 14. Correspondencia 2-3-4 → Red-Black

## 14.1 La transformación

Cada tipo de nodo en un 2-3-4 tree se convierte en una configuración específica de nodos rojos y negros:

### 2-nodo → Nodo negro solo

```text
2-3-4:        [b]            Red-Black:      (b)
             /   \                          /    \
            A     B                        A      B

  → El nodo b se colorea NEGRO.
  → Correspondencia directa 1:1.
```

### 3-nodo → Nodo negro + un hijo rojo

```text
2-3-4:      [a | b]          Red-Black:      (b)        o       (a)
           /   |   \                        /    \              /    \
          A    B    C                     <a>     C            A    <b>
                                         /  \                      /  \
                                        A    B                    B    C

  Opción izquierda: b es negro, a es hijo rojo izquierdo
  Opción derecha: a es negro, b es hijo rojo derecho

  ( ) = negro     < > = rojo

  → Un 3-nodo tiene DOS representaciones binarias válidas.
  → En Left-Leaning Red-Black (LLRB): solo la opción izquierda.
  → En Red-Black clásico: ambas son válidas.
```

### 4-nodo → Nodo negro con dos hijos rojos

```text
2-3-4:    [a | b | c]       Red-Black:      (b)
         /  |    |   \                      /    \
        A   B    C    D                   <a>    <c>
                                         /  \   /  \
                                        A    B C    D

  → b es NEGRO (la mediana)
  → a y c son ROJOS (los extremos)
  → Los subárboles A, B, C, D se distribuyen exactamente igual.
```

## 14.2 Resumen visual

```text
 2-3-4 NODE          RED-BLACK EQUIVALENT
 ──────────          ────────────────────

   [b]                    (b)              ← negro
   / \                    / \

  [a|b]                   (b)              ← negro
  / | \                  /   \
                       <a>    ·            ← rojo-izq
                       / \

  [a|b]                   (a)              ← negro
  / | \                  /   \
                        ·   <b>            ← rojo-der
                            / \

 [a|b|c]                  (b)              ← negro
 / | | \                 /   \
                       <a>   <c>           ← ambos rojos
                       / \   / \
```

## 14.3 La propiedad fundamental

```text
En un 2-3-4 tree, todas las hojas están al mismo nivel.

En la representación Red-Black:
  → Cada camino raíz→hoja tiene el mismo número de NODOS NEGROS.
  → Los nodos rojos son "extensiones" de sus padres negros
    (forman parte del mismo nodo 2-3-4).
  → Por eso la propiedad "black-height constante" es equivalente
    a "todas las hojas al mismo nivel en 2-3-4".
```

---

# 15. Las 5 Propiedades Red-Black

## 15.1 Definición formal

Un Red-Black Tree es un BST donde cada nodo tiene un color (rojo o negro) y se cumplen las siguientes propiedades:

```text
┌────────────────────────────────────────────────────────────────┐
│  Propiedad 1: Cada nodo es ROJO o NEGRO.                       │
│                                                                │
│  Propiedad 2: La RAÍZ es siempre NEGRA.                       │
│                                                                │
│  Propiedad 3: Todas las hojas (NIL/NULL) son NEGRAS.           │
│               (Las hojas son nodos centinela, no datos reales)  │
│                                                                │
│  Propiedad 4: Si un nodo es ROJO, ambos hijos son NEGROS.      │
│               (No puede haber dos rojos consecutivos)           │
│                                                                │
│  Propiedad 5: Para cada nodo, todos los caminos desde ese nodo │
│               hasta las hojas NIL tienen el mismo número de     │
│               nodos NEGROS (black-height).                      │
└────────────────────────────────────────────────────────────────┘
```

## 15.2 ¿De dónde viene cada propiedad?

| Propiedad RB          | Equivalente en 2-3-4                              |
| --------------------- | ------------------------------------------------- |
| 1. Rojo o negro       | Cada nodo es parte de un 2, 3 o 4-nodo            |
| 2. Raíz negra         | La raíz del 2-3-4 siempre existe como nodo propio |
| 3. Hojas NIL negras   | Convención para simplificar el código              |
| 4. No 2 rojos seguidos | Un 4-nodo tiene máximo 3 claves (no existe 5-nodo) |
| 5. Black-height igual | Todas las hojas del 2-3-4 al mismo nivel           |

## 15.3 Ejemplo con propiedades

```text
Red-Black Tree (válido):

              (13)B                    B = Black, R = Red
             /      \
          (8)R      (17)R
         /    \     /    \
       (1)B  (11)B (15)B (25)B
        \          /       /
       (6)R     (14)R   (22)R

Verificación:
  Prop 1: Cada nodo tiene color  ✓
  Prop 2: Raíz (13) es negra  ✓
  Prop 3: Hojas NIL son negras (implícito)  ✓
  Prop 4: Nodo rojo (8) → hijos (1)B y (11)B  ✓
          Nodo rojo (17) → hijos (15)B y (25)B  ✓
          Nodo rojo (6) → hijos NIL(B) y NIL(B)  ✓
  Prop 5: Camino 13→8→1→NIL: negros = {13, 1} = 2
          Camino 13→8→1→6→NIL: negros = {13, 1} = 2
          Camino 13→8→11→NIL: negros = {13, 11} = 2
          Camino 13→17→15→14→NIL: negros = {13, 15} = 2
          → black-height = 2 en todos los caminos  ✓
```

## 15.4 Black-Height

```text
Black-height bh(x) = número de nodos negros en cualquier camino
                       desde x hasta una hoja NIL (sin contar x).

Para el árbol anterior:
  bh(13) = 2
  bh(8)  = 1 (8 es rojo, camino 8→1→NIL tiene 1 negro: {1})
  bh(17) = 1
  bh(1)  = 1 (camino 1→NIL tiene 0 negros...
              o 1→6→NIL tiene 0 negros → bh(1)=0?
              Depende si contamos el nodo: NO contamos x.
              1→NIL: negros en camino = 0 → bh(1) = 0?
              Pero NIL es negro → bh(1) = 1)

Convención estándar: Se cuentan los NIL negros pero NO el nodo x.
  bh(raíz) = black-height del árbol
```

---

# 16. Intuición del Balanceo Red-Black

## 16.1 ¿Por qué estas propiedades garantizan balance?

```text
Teorema: Un Red-Black tree con n nodos internos tiene altura h ≤ 2·log₂(n+1).

Prueba intuitiva:
  1. Sea bh = black-height de la raíz.
  2. Propiedad 5 → al menos bh nodos negros en cada camino.
  3. Propiedad 4 → entre dos negros puede haber máximo 1 rojo.
  4. → La altura total h ≤ 2·bh (alternando negro-rojo-negro-rojo...).
  5. → n ≥ 2^bh - 1 (un árbol con bh niveles negros tiene al menos 2^bh - 1 nodos).
  6. → bh ≥ log₂(n+1)/2
  7. → h ≤ 2·bh ≤ 2·log₂(n+1)/1...

Más formal:
  - El subárbol con raíz x tiene al menos 2^(bh(x)) - 1 nodos internos.
  - bh(raíz) ≥ h/2 (por Prop 4).
  - n ≥ 2^(h/2) - 1
  - n+1 ≥ 2^(h/2)
  - log₂(n+1) ≥ h/2
  - h ≤ 2·log₂(n+1)
```

## 16.2 Comparación de alturas

```text
                  n = 1,000,000
                  ──────────────
BST peor caso:    h = 999,999
BST promedio:     h ≈ 30 (2·ln(n))
AVL:              h ≤ 1.44·log₂(n) ≈ 29
Red-Black:        h ≤ 2·log₂(n) ≈ 40
2-3 tree:         h ≤ log₂(n) ≈ 20
2-3-4 tree:       h ≤ log₂(n) ≈ 20

→ Red-Black es un poco más alto que AVL,
  pero con operaciones de mantenimiento más simples.
```

## 16.3 El trade-off fundamental

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  AVL:       Más estricto → menor altura → búsqueda más      │
│             rápida, pero rotaciones más frecuentes           │
│                                                              │
│  Red-Black: Menos estricto → un poco más alto → búsqueda    │
│             ligeramente más lenta, pero mantenimiento más    │
│             eficiente en inserción/eliminación               │
│                                                              │
│  En la práctica: Red-Black es el estándar industrial         │
│    • Java: TreeMap, TreeSet                                  │
│    • C++: std::map, std::set                                 │
│    • Linux: CFS scheduler, memory mapping                    │
│    • .NET: SortedDictionary                                  │
│                                                              │
│  AVL: preferido cuando las búsquedas dominan                 │
│    • Bases de datos in-memory                                │
│    • Diccionarios de solo lectura                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

# PARTE V — ANÁLISIS

---

# 17. Complejidad Comparada

## 17.1 Tabla general

| Operación     | BST (peor) | BST (prom.) | AVL      | 2-3      | 2-3-4    | Red-Black |
| ------------- | ---------- | ----------- | -------- | -------- | -------- | --------- |
| Búsqueda      | O(n)       | O(log n)    | O(log n) | O(log n) | O(log n) | O(log n)  |
| Inserción     | O(n)       | O(log n)    | O(log n) | O(log n) | O(log n) | O(log n)  |
| Eliminación   | O(n)       | O(log n)    | O(log n) | O(log n) | O(log n) | O(log n)  |
| Espacio       | O(n)       | O(n)        | O(n)     | O(n)     | O(n)     | O(n)      |
| Altura máxima | n-1        | ~2·ln(n)    | 1.44·log n | log₂ n | log₂ n  | 2·log₂ n  |

## 17.2 Constantes ocultas

```text
Aunque todos son O(log n), las constantes importan:

Búsqueda:
  AVL:       ~1.44·log₂(n) comparaciones (altura máxima)
  Red-Black: ~2·log₂(n) comparaciones (altura máxima)
  → AVL es ~39% más rápido en búsqueda pura

Inserción:
  AVL:       1 rotación máximo (pero siempre recalcular alturas)
  Red-Black: 2 rotaciones máximo + recoloreo O(log n) o O(1) amortizado
  → Red-Black es ligeramente más rápido en inserción

Eliminación:
  AVL:       Hasta O(log n) rotaciones
  Red-Black: Máximo 3 rotaciones
  → Red-Black es significativamente más rápido en eliminación
```

---

# 18. Resumen de Propiedades Estructurales

## 18.1 Tabla de propiedades

| Propiedad              | BST   | AVL   | 2-3   | 2-3-4 | Red-Black |
| ---------------------- | ----- | ----- | ----- | ----- | --------- |
| Balance perfecto       | ✗     | ✗     | ✓     | ✓     | ✗ (aprox) |
| Balance garantizado    | ✗     | ✓     | ✓     | ✓     | ✓         |
| Hojas al mismo nivel   | ✗     | ✗     | ✓     | ✓     | ✗*        |
| Claves por nodo        | 1     | 1     | 1-2   | 1-3   | 1         |
| Hijos por nodo         | 0-2   | 0-2   | 0-3   | 0-4   | 0-2       |
| Campo extra por nodo   | —     | height | numKeys| numKeys| color (1 bit) |
| Implementación binaria | ✓     | ✓     | ✗     | ✗     | ✓         |

```text
* En Red-Black, las "hojas" NIL están al mismo nivel en términos de black-height,
  pero la altura real de las hojas puede diferir por un factor de 2.
```

---

# PARTE VI — SÍNTESIS

---

# 19. Errores Comunes y Buenas Prácticas

## 19.1 Tabla de errores

| #  | Error                                                    | Consecuencia                              | Corrección                                         |
| -- | -------------------------------------------------------- | ----------------------------------------- | -------------------------------------------------- |
| 1  | Confundir 2-3 tree con BST de grado 3                   | Estructura diferente                      | En 2-3, los nodos internos tienen 1-2 claves       |
| 2  | Pensar que 4-nodos son ilegales en 2-3-4 trees          | No insertar correctamente                 | 4-nodos son VÁLIDOS; se dividen al insertar         |
| 3  | Dividir un 3-nodo preventivamente en 2-3-4              | Solo 4-nodos se dividen top-down          | Solo split preventivo en 4-nodos                    |
| 4  | Creer que 2-3 trees crecen hacia abajo                  | Error en inserción                        | Siempre insertar en hojas; crecer hacia arriba      |
| 5  | Confundir split con rotación                             | Operaciones distintas                     | Split: dividir nodo. Rotación: reestructurar BST    |
| 6  | Pensar que Red-Black y 2-3-4 son diferentes              | Son equivalentes                          | RB es representación binaria de 2-3-4               |
| 7  | Olvidar que las hojas NIL son negras                     | Violar propiedades RB                     | Siempre contar NIL como negro                       |
| 8  | Creer que RB requiere menos código que AVL               | RB tiene más casos en eliminación         | RB tiene mantenimiento más eficiente, no más simple |
| 9  | Pensar que 2-3/2-3-4 se implementan directamente         | Desperdicio de memoria                    | Se implementan como Red-Black Trees                 |
| 10 | Confundir black-height con altura real                    | Errores en verificación                   | Black-height cuenta solo nodos negros               |

## 19.2 Buenas prácticas

```text
┌─────────────────────────────────────────────────────────────────┐
│  1. Estudia 2-3-4 ANTES de Red-Black                            │
│     → Entenderás por qué las reglas RB existen                  │
│                                                                 │
│  2. Dibuja la correspondencia 2-3-4 ↔ RB en papel               │
│     → Cada vez que no entiendas una regla RB, tradúcela a 2-3-4│
│                                                                 │
│  3. Memoriza las 5 propiedades Red-Black                        │
│     → Son la base de TODA verificación y corrección             │
│                                                                 │
│  4. Distingue entre modelo conceptual e implementación          │
│     → 2-3/2-3-4: modelo conceptual                              │
│     → Red-Black: implementación real                            │
│                                                                 │
│  5. Para entrevistas: conoce los trade-offs                     │
│     → AVL vs RB: cuándo usar cada uno                           │
│     → BST vs Balanceados: cuándo importa el balance             │
└─────────────────────────────────────────────────────────────────┘
```

---

# 20. Intuición de Ingeniería

> **Los 2-3-4 Trees son la TEORÍA. Los Red-Black Trees son la PRÁCTICA.**
> Estudiar uno sin el otro es como estudiar circuitos sin electrónica, o
> álgebra sin calcular. La belleza está en la equivalencia: un árbol multiway
> perfectamente balanceado, disfrazado de árbol binario con colores.

### La idea en una oración

```text
2-3-4 Tree = balance perfecto con nodos grandes
Red-Black Tree = la misma estructura, comprimida en binario
```

### El mapa mental completo

```text
BST
 │
 ├── Problema: puede degenerar a O(n)
 │
 ├── Solución 1: Rotar post-hoc
 │   └── AVL Tree (balance estricto, h ≤ 1.44·log n)
 │
 ├── Solución 2: Cambiar la estructura del nodo
 │   ├── 2-3 Tree (nodos con 1-2 claves)
 │   │   └── Balance perfecto, todas hojas al mismo nivel
 │   │   └── Implementación: Left-Leaning Red-Black (LLRB)
 │   │
 │   └── 2-3-4 Tree (nodos con 1-3 claves)
 │       └── Balance perfecto + inserción top-down
 │       └── Implementación: Red-Black Tree clásico
 │
 └── Solución 3: Aleatorización
     └── Treap, Skip List (balance probabilístico)
```

### La analogía del almacén

```text
Un BST es un almacén con estantes de 1 producto cada uno.
  → Si llegan productos en orden, se apilan en una sola columna.
  → Buscar: revisar toda la columna.

Un 2-3-4 tree es un almacén con estantes de 1-3 productos.
  → Cuando un estante se llena (4 productos), se divide.
  → Todo queda nivelado automáticamente.

Un Red-Black tree es el MISMO almacén, pero:
  → Cada estante grande se representa como un mini-árbol binario.
  → Los productos "principales" son negros.
  → Los "extras" en el mismo estante son rojos.
  → Es más fácil de programar (todo es binario).
```

### Preguntas clásicas de entrevistas

```text
P: ¿Cuál es la diferencia entre AVL y Red-Black?
R: AVL es más estricto (h ≤ 1.44·log n vs 2·log n).
   Búsquedas más rápidas en AVL, pero inserciones/eliminaciones
   más eficientes en Red-Black. En la práctica, Red-Black domina.

P: ¿Qué es un Red-Black Tree?
R: Es una representación binaria de un 2-3-4 tree.
   Un BST con nodos coloreados que garantizan O(log n)
   mediante 5 propiedades invariantes.

P: ¿Por qué std::map usa Red-Black y no AVL?
R: Porque std::map tiene muchas inserciones y eliminaciones.
   Red-Black hace máximo 3 rotaciones en eliminación vs O(log n) en AVL.
   Para búsquedas puras, AVL sería mejor.

P: ¿Qué es un 2-3-4 tree?
R: Un árbol de búsqueda donde los nodos pueden tener 1, 2 o 3 claves
   (y 2, 3 o 4 hijos). Todas las hojas están al mismo nivel.
   Es el modelo conceptual detrás de los Red-Black Trees.
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
| Binary Search Trees              | BinarySearchTree.md  |
| AVL Trees                        | AVLTree.md           |
| **2-3 Trees y 2-3-4 Trees (este)** | 2-3Trees.md       |
| Red-Black Trees                  | RedBlackTree.md      |
