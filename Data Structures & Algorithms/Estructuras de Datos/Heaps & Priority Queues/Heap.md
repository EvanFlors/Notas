# Heap — El Árbol que Vive en un Array

> **Idea central:** Un BST optimiza la *búsqueda*: cualquier valor en O(log n).
> Un Heap optimiza el *extremo*: el máximo (o mínimo) en **O(1)**, siempre.
> No es un árbol de búsqueda — es un **árbol de prioridad**.
> Su genialidad es doble: un árbol binario completo que se representa como un **simple array**, sin punteros, sin overhead, con locality perfecta.
> Con él se construyen **colas de prioridad**, **Heap Sort**, Dijkstra, schedulers
> de sistemas operativos, y cualquier sistema que necesite responder:
> *"¿cuál es el más importante ahora?"*

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Definición de Heap](#1-definición-de-heap)
2. [Propiedades Fundamentales](#2-propiedades-fundamentales)
3. [Representación en Array](#3-representación-en-array)
4. [Heap vs BST](#4-heap-vs-bst)

**Parte II — Operaciones Fundamentales**
5. [Inserción (Insert)](#5-inserción-insert)
6. [Eliminación de la Raíz (Extract)](#6-eliminación-de-la-raíz-extract)
7. [Peek (Consultar el Extremo)](#7-peek-consultar-el-extremo)
8. [Eliminación Arbitraria y Decrease Key](#8-eliminación-arbitraria-y-decrease-key)

**Parte III — Heapify y Construcción**
9. [Heapify Down (Sift-Down)](#9-heapify-down-sift-down)
10. [Heapify Up (Sift-Up)](#10-heapify-up-sift-up)
11. [Build Heap: Método Incremental](#11-build-heap-método-incremental)
12. [Build Heap: Método Bottom-Up (Floyd)](#12-build-heap-método-bottom-up-floyd)
13. [¿Por qué Build Heap es O(n) y no O(n log n)?](#13-por-qué-build-heap-es-on-y-no-on-log-n)

**Parte IV — Heap Sort**
14. [Idea General del Algoritmo](#14-idea-general-del-algoritmo)
15. [Heap Sort Paso a Paso](#15-heap-sort-paso-a-paso)
16. [Análisis de Heap Sort](#16-análisis-de-heap-sort)
17. [Comparación con Otros Algoritmos de Sorting](#17-comparación-con-otros-algoritmos-de-sorting)

**Parte V — Priority Queue**
18. [Definición y Operaciones](#18-definición-y-operaciones)
19. [Implementación con Heap](#19-implementación-con-heap)
20. [Aplicaciones Reales](#20-aplicaciones-reales)

**Parte VI — Implementación Completa**
21. [Implementación en C (Max-Heap)](#21-implementación-en-c-max-heap)
22. [Implementación en C (Min-Heap Priority Queue)](#22-implementación-en-c-min-heap-priority-queue)

**Parte VII — Síntesis**
23. [Resumen de Complejidad](#23-resumen-de-complejidad)
24. [Errores Comunes y Buenas Prácticas](#24-errores-comunes-y-buenas-prácticas)
25. [Intuición de Ingeniería](#25-intuición-de-ingeniería)
26. [Ejercicios Sugeridos](#26-ejercicios-sugeridos)

---

# PARTE I — FUNDAMENTOS

---

# 1. Definición de Heap

## 1.1 ¿Qué es un Heap?

Un **Heap** es un árbol binario **completo** que satisface la **propiedad de heap** (heap property):

> En un **Max-Heap**, cada nodo es **mayor o igual** que todos sus descendientes.

> En un **Min-Heap**, cada nodo es **menor o igual** que todos sus descendientes.

```text
Max-Heap:                          Min-Heap:

         90                               5
        /  \                             / \
      70    80                         10   15
     / \   / \                        / \   / \
    40 50 60 30                     20  25 30  40

  Raíz = máximo (90)               Raíz = mínimo (5)
  Todo padre ≥ hijos               Todo padre ≤ hijos
```

## 1.2 Definición formal

```text
Max-Heap:
  Para todo nodo i (excepto la raíz):
    A[parent(i)] ≥ A[i]

Min-Heap:
  Para todo nodo i (excepto la raíz):
    A[parent(i)] ≤ A[i]
```

## 1.3 ¿Qué NO es un Heap?

```text
✗ NO es un BST:
  Un heap NO mantiene orden izquierda-derecha.
  En un max-heap, el hijo izquierdo puede ser mayor que el derecho.

         90
        /  \
      50    70     ← 50 < 70, pero 50 es hijo izquierdo
     / \
    40  30         ← Válido como heap, inválido como BST

✗ NO permite búsqueda eficiente:
  Buscar un valor arbitrario en un heap es O(n).
  Solo el extremo (raíz) es accesible en O(1).

✗ NO necesariamente es un árbol con punteros:
  Se implementa como ARRAY. El árbol es solo la abstracción visual.
```

---

# 2. Propiedades Fundamentales

## 2.1 Propiedad estructural: Árbol Binario Completo

```text
Un árbol binario COMPLETO tiene todos los niveles llenos,
excepto posiblemente el último, que se llena de IZQUIERDA A DERECHA.

✓ Completo:                    ✗ NO completo:
       A                             A
      / \                           / \
     B   C                         B   C
    / \  /                        / \   \
   D  E F                       D   E    F
                                         ↑
  Último nivel: D,E,F               Hueco a la izquierda
  llenándose de izquierda
  a derecha  ✓
```

> **¿Por qué completo?** Porque un árbol completo se puede representar como un **array
> sin huecos**. Si no fuera completo, habría posiciones vacías en el array → desperdicio.

## 2.2 Propiedad de orden: Heap Property

```text
Max-Heap Property:
  ∀ nodo i: A[parent(i)] ≥ A[i]
  → La raíz es el máximo global.
  → Cada subárbol también es un heap.

Min-Heap Property:
  ∀ nodo i: A[parent(i)] ≤ A[i]
  → La raíz es el mínimo global.
```

## 2.3 Consecuencias de ambas propiedades

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. La raíz siempre contiene el max (o min).          → O(1)     │
│  2. El árbol tiene altura h = ⌊log₂(n)⌋.             → O(log n)  │
│  3. Se puede almacenar en un array sin punteros.       → cache   │
│  4. No hay garantía sobre el orden entre hermanos.     → NO BST  │
│  5. Inserción y extracción: O(log n).                            │
│  6. Construir un heap desde n datos: O(n).                       │
└──────────────────────────────────────────────────────────────────┘
```

## 2.4 Altura de un Heap

```text
Un heap con n nodos tiene exactamente:
  h = ⌊log₂(n)⌋

Ejemplo:
  n = 1   → h = 0  (solo raíz)
  n = 7   → h = 2  (3 niveles: 1 + 2 + 4)
  n = 10  → h = 3  (4 niveles: 1 + 2 + 4 + 3)
  n = 15  → h = 3  (4 niveles completos: 1 + 2 + 4 + 8)
  n = 1M  → h = 19
```

---

# 3. Representación en Array

## 3.1 La idea clave

Un árbol binario completo tiene una correspondencia **perfecta** con un array:

```text
Árbol:
              90                    Nivel 0
             /  \
           70    80                 Nivel 1
          / \   / \
        40  50 60  30               Nivel 2

Array (índice 0):
  Índice:  0   1   2   3   4   5   6
  Valor: [90, 70, 80, 40, 50, 60, 30]

Array (índice 1, convención alternativa):
  Índice:  1   2   3   4   5   6   7
  Valor: [90, 70, 80, 40, 50, 60, 30]
```

## 3.2 Fórmulas de navegación

### Indexado desde 0 (más común en C)

```text
Para un nodo en índice i:
  Parent(i)      = (i - 1) / 2     (división entera)
  Left_Child(i)  = 2*i + 1
  Right_Child(i) = 2*i + 2

Ejemplo con i = 1 (nodo 70):
  Parent(1) = (1-1)/2 = 0 → nodo 90  ✓
  Left(1)   = 2*1+1   = 3 → nodo 40  ✓
  Right(1)  = 2*1+2   = 4 → nodo 50  ✓
```

### Indexado desde 1 (más limpio matemáticamente)

```text
Para un nodo en índice i:
  Parent(i)      = i / 2
  Left_Child(i)  = 2*i
  Right_Child(i) = 2*i + 1

Ejemplo con i = 2 (nodo 70):
  Parent(2) = 2/2 = 1 → nodo 90  ✓
  Left(2)   = 2*2 = 4 → nodo 40  ✓
  Right(2)  = 2*2+1 = 5 → nodo 50  ✓
```

> **Convención en este módulo:** Usaremos indexado desde 0 (estándar en C).

## 3.3 Visualización dual: Árbol ↔ Array

```text
Siempre visualiza AMBAS representaciones simultáneamente:

Árbol:                    Array [90, 70, 80, 40, 50, 60, 30]
         90               Índice: 0   1   2   3   4   5   6
        /  \
      70    80            parent(3) = (3-1)/2 = 1 → A[1] = 70  ✓
     / \   / \            left(1)   = 2*1+1   = 3 → A[3] = 40  ✓
    40 50 60 30           right(2)  = 2*2+2   = 6 → A[6] = 30  ✓
```

## 3.4 ¿Por qué array y no punteros?

```text
┌──────────────────────┬────────────────┬───────────────────────┐
│  Aspecto             │  Array (Heap)  │  Punteros (BST/AVL)   │
├──────────────────────┼────────────────┼───────────────────────┤
│  Navegar a hijo      │  2*i+1 (O(1)) │  ptr->left (O(1))      │
│  Navegar a padre     │  (i-1)/2 (O(1))│ ptr->parent o stack   │
│  Memoria por nodo    │  solo el dato  │  dato + 2-3 punteros  │
│  Cache locality      │  Excelente     │  Mala (malloc disper.)│
│  Inserta al final    │  A[size++]     │  malloc + enlazar     │
│  Desperdicio         │  Ninguno       │  Punteros NULL        │
│  Requiere completo   │  SÍ            │  NO                   │
└──────────────────────┴────────────────┴───────────────────────┘

→ El array es mejor en TODO para un árbol completo.
→ Solo funciona porque el heap es COMPLETO (sin huecos).
```

---

# 4. Heap vs BST

## 4.1 Tabla comparativa

| Operación            | Max-Heap   | BST (balanceado) | BST (peor) |
| -------------------- | ---------- | ---------------- | ---------- |
| Obtener máximo       | **O(1)**   | O(log n)         | O(n)       |
| Obtener mínimo       | O(n)       | O(log n)         | O(n)       |
| Insertar             | O(log n)   | O(log n)         | O(n)       |
| Eliminar máximo      | O(log n)   | O(log n)         | O(n)       |
| Buscar un valor      | **O(n)**   | O(log n)         | O(n)       |
| Recorrido ordenado   | O(n log n) | O(n)             | O(n)       |
| Construir            | **O(n)**   | O(n log n)       | O(n log n) |
| Espacio extra        | **O(1)**   | O(n) (punteros)  | O(n)       |

## 4.2 Intuición de las diferencias

```text
BST:  "Puedo encontrar CUALQUIER valor rápido"
      → Optimizado para BÚSQUEDA general
      → Mantiene ORDEN TOTAL (inorder = sorted)

Heap: "Puedo encontrar EL EXTREMO rápido"
      → Optimizado para acceso al MAX o MIN
      → NO mantiene orden total (solo padre ≥ hijos)
      → Pero se construye en O(n), no O(n log n)

Analogía:
  BST = biblioteca con libros en orden alfabético
        → Encontrar cualquier libro: rápido
        → Encontrar el "más importante": caminar al extremo

  Heap = pila de tareas donde la más urgente está arriba
        → Encontrar la más urgente: instantáneo (mirar arriba)
        → Encontrar una tarea específica: revisar toda la pila
```

## 4.3 ¿Cuándo usar cada uno?

```text
✅ Usar Heap:
  • Necesitas acceso rápido al max/min
  • Priority queues
  • Heap Sort (sorting in-place)
  • Dijkstra, Prim (MST)
  • Top-K elements
  • Mediana de un stream (2 heaps)

✅ Usar BST (AVL/Red-Black):
  • Necesitas buscar valores arbitrarios
  • Necesitas recorrido ordenado
  • Necesitas sucesor/predecesor
  • Necesitas range queries
  • Diccionarios ordenados (std::map)
```

---

# PARTE II — OPERACIONES FUNDAMENTALES

---

# 5. Inserción (Insert)

## 5.1 Algoritmo

```text
Insert(heap, key):
  1. Agregar key al FINAL del array (mantener completitud)
  2. "Bubble Up" (sift-up): subir key mientras sea mayor que su padre

     ┌────────────────────────────────────────────────┐
     │  Insertar al final preserva la ESTRUCTURA.     │
     │  Bubble up restaura la PROPIEDAD DE ORDEN.     │
     └────────────────────────────────────────────────┘
```

## 5.2 Bubble Up (Sift-Up)

```text
BubbleUp(heap, i):
  while i > 0 and heap[parent(i)] < heap[i]:   // para max-heap
    swap(heap[parent(i)], heap[i])
    i = parent(i)
```

## 5.3 Ejemplo paso a paso (Max-Heap)

```text
Heap inicial: [90, 70, 80, 40, 50, 60, 30]

           90
          /  \
        70    80
       / \   / \
      40 50 60 30

Insertar 85:

Paso 1: Agregar 85 al final → [90, 70, 80, 40, 50, 60, 30, 85]

           90
          /  \
        70    80
       / \   / \
      40 50 60 30
     /
    85  ← nuevo nodo (índice 7)

Paso 2: Bubble up. parent(7) = 3 → A[3] = 40. ¿85 > 40? SÍ → swap

           90
          /  \
        70    80
       / \   / \
     [85] 50 60 30       A = [90, 70, 80, 85, 50, 60, 30, 40]
     /
   [40]

Paso 3: parent(3) = 1 → A[1] = 70. ¿85 > 70? SÍ → swap

           90
          /  \
       [85]   80
       / \   / \
     [70] 50 60 30       A = [90, 85, 80, 70, 50, 60, 30, 40]
     /
    40

Paso 4: parent(1) = 0 → A[0] = 90. ¿85 > 90? NO → STOP

           90
          /  \
        85    80
       / \   / \
      70 50 60 30
     /
    40

Resultado: [90, 85, 80, 70, 50, 60, 30, 40]  ✓ Max-Heap válido.
Comparaciones: 3 (= altura del nodo insertado)
```

## 5.4 Complejidad

```text
Mejor caso:  O(1)      — key ≤ padre → no sube
Peor caso:   O(log n)  — key sube hasta la raíz
Promedio:    O(1)*     — la mayoría de nodos están en niveles bajos
                         y suben poco (demostrable por análisis amortizado)

* Sorprendente: la inserción promedio es O(1), no O(log n).
  Razón: la mitad de los nodos son hojas. Solo ~1/4 suben 1 nivel,
  ~1/8 suben 2 niveles, etc. La suma es acotada por una constante.
```

---

# 6. Eliminación de la Raíz (Extract)

## 6.1 Algoritmo

```text
ExtractMax(heap):
  1. Guardar heap[0] (el máximo)
  2. Mover el ÚLTIMO elemento a la raíz: heap[0] = heap[size-1]
  3. Reducir size
  4. "Bubble Down" (sift-down) desde la raíz: bajar mientras sea menor que algún hijo

     ┌───────────────────────────────────────────────────┐
     │  Mover el último a la raíz preserva ESTRUCTURA.   │
     │  Bubble down restaura la PROPIEDAD DE ORDEN.       │
     └───────────────────────────────────────────────────┘
```

## 6.2 Bubble Down (Sift-Down)

```text
BubbleDown(heap, i, size):
  while true:
    largest = i
    left = 2*i + 1
    right = 2*i + 2

    if left < size and heap[left] > heap[largest]:
      largest = left
    if right < size and heap[right] > heap[largest]:
      largest = right

    if largest == i:
      break                  // heap property restaurada
    swap(heap[i], heap[largest])
    i = largest
```

## 6.3 Ejemplo paso a paso

```text
Heap: [90, 85, 80, 70, 50, 60, 30, 40]

           90
          /  \
        85    80
       / \   / \
      70 50 60 30
     /
    40

ExtractMax:

Paso 1: Guardar max = 90
Paso 2: Mover último (40) a la raíz → [40, 85, 80, 70, 50, 60, 30]

          [40]  ← fuera de lugar
          /  \
        85    80
       / \   / \
      70 50 60 30

Paso 3: Bubble down. Hijos de 40: left=85, right=80.
        largest = 85 (índice 1). ¿85 > 40? SÍ → swap

           85
          /  \
        [40]  80
       / \   / \
      70 50 60 30

Paso 4: Hijos de 40 (ahora índice 1): left=70, right=50.
        largest = 70 (índice 3). ¿70 > 40? SÍ → swap

           85
          /  \
        70    80
       / \   / \
     [40] 50 60 30

Paso 5: Hijos de 40 (ahora índice 3): left = índice 7 → fuera de rango.
        No hay hijos → STOP.

Resultado: [85, 70, 80, 40, 50, 60, 30]  ✓ Max-Heap válido.
Devuelve: 90
```

## 6.4 Detalle crucial: ¿por qué intercambiar con el MAYOR hijo?

```text
Si intercambiamos con el MENOR hijo:

         [40]
         /  \
       85    80

  Swap 40 ↔ 80 (menor):

          80
         /  \
       85   [40]

  ¡VIOLACIÓN! 85 > 80, pero 85 es hijo de 80.

  Swap 40 ↔ 85 (mayor):

          85
         /  \
       [40]  80

  ✓ Correcto: 85 > 40 y 85 > 80.

→ Siempre intercambiar con el MAYOR hijo (max-heap)
  o el MENOR hijo (min-heap).
```

## 6.5 Complejidad

```text
Mejor caso:  O(1)      — el nuevo valor en la raíz es mayor que ambos hijos
Peor caso:   O(log n)  — baja hasta una hoja
Promedio:    O(log n)  — usualmente baja bastante
```

---

# 7. Peek (Consultar el Extremo)

## 7.1 Operación

```text
PeekMax(heap):
  return heap[0]      // O(1), sin modificar el heap

PeekMin(heap):        // para min-heap
  return heap[0]      // O(1)
```

## 7.2 ¿Dónde está el mínimo en un Max-Heap?

```text
En un max-heap, el mínimo está en alguna HOJA.
Las hojas van de índice ⌊n/2⌋ hasta n-1.

→ Encontrar el mínimo en un max-heap: O(n/2) = O(n)

Ejemplo: [90, 85, 80, 70, 50, 60, 30, 40]
  Hojas: índices 3,4,5,6,7 → {70, 50, 60, 30, 40}
  Mínimo = 30 (hay que revisar todas las hojas)
```

---

# 8. Eliminación Arbitraria y Decrease Key

## 8.1 Eliminación de un elemento arbitrario

```text
Delete(heap, i):
  1. heap[i] = +∞ (o un valor mayor que la raíz)  // para max-heap
  2. BubbleUp(heap, i)    // sube a la raíz
  3. ExtractMax(heap)     // extrae la raíz

Complejidad: O(log n)
Pero requiere CONOCER el índice i → encontrarlo es O(n).
```

## 8.2 Decrease Key / Increase Key

```text
DecreaseKey(heap, i, newValue):      // para min-heap
  if newValue > heap[i]:
    error "nueva clave mayor que la actual"
  heap[i] = newValue
  BubbleUp(heap, i)                  // puede violar heap property hacia arriba

IncreaseKey(heap, i, newValue):      // para max-heap
  if newValue < heap[i]:
    error "nueva clave menor que la actual"
  heap[i] = newValue
  BubbleUp(heap, i)

→ Usado en Dijkstra: cuando encontramos un camino más corto a un nodo,
  hacemos DecreaseKey para actualizar su prioridad en el min-heap.
```

---

# PARTE III — HEAPIFY Y CONSTRUCCIÓN

---

# 9. Heapify Down (Sift-Down)

## 9.1 Definición

**Heapify Down** (también llamado sift-down, percolate-down, o bubble-down) es la operación que restaura la propiedad de heap **bajando** un nodo que es menor (en max-heap) que alguno de sus hijos.

```text
Precondición:
  Los subárboles izquierdo y derecho de i YA son heaps válidos.
  Solo el nodo i puede violar la propiedad de heap.

Postcondición:
  El subárbol con raíz en i es un heap válido.
```

## 9.2 Pseudocódigo (Max-Heap)

```text
HeapifyDown(A, i, n):
  while true:
    largest = i
    left = 2*i + 1
    right = 2*i + 2

    if left < n and A[left] > A[largest]:
      largest = left
    if right < n and A[right] > A[largest]:
      largest = right

    if largest == i:
      return               // propiedad restaurada

    swap(A[i], A[largest])
    i = largest            // seguir bajando
```

## 9.3 Ejemplo detallado

```text
Aplicar HeapifyDown en índice 0:

Array: [30, 85, 80, 70, 50, 60, 40]

          [30]  ← viola heap property (30 < 85, 30 < 80)
          /  \
        85    80
       / \   / \
      70 50 60 40

Iteración 1: i=0, left=1(85), right=2(80)
  largest = 1 (85 > 30)
  right: 80 < 85 → largest sigue = 1
  swap A[0] ↔ A[1]: [85, 30, 80, 70, 50, 60, 40]

           85
          /  \
        [30]  80
       / \   / \
      70 50 60 40

Iteración 2: i=1, left=3(70), right=4(50)
  largest = 3 (70 > 30)
  right: 50 < 70 → largest sigue = 3
  swap A[1] ↔ A[3]: [85, 70, 80, 30, 50, 60, 40]

           85
          /  \
        70    80
       / \   / \
     [30] 50 60 40

Iteración 3: i=3, left=7(fuera), right=8(fuera)
  No hay hijos → STOP.

Resultado: [85, 70, 80, 30, 50, 60, 40]  ✓ Max-Heap.
Swaps: 2 (bajó 2 niveles)
```

---

# 10. Heapify Up (Sift-Up)

## 10.1 Definición

**Heapify Up** (sift-up, percolate-up, bubble-up) restaura la propiedad de heap **subiendo** un nodo que es mayor (en max-heap) que su padre.

```text
Precondición:
  Todo el heap es válido EXCEPTO posiblemente en la posición i,
  donde A[i] puede ser mayor que A[parent(i)].

Postcondición:
  El heap completo es válido.
```

## 10.2 Pseudocódigo (Max-Heap)

```text
HeapifyUp(A, i):
  while i > 0 and A[parent(i)] < A[i]:
    swap(A[parent(i)], A[i])
    i = parent(i)
```

## 10.3 Heapify Down vs Heapify Up

```text
┌─────────────────────┬──────────────────────┬───────────────────────┐
│  Aspecto            │  HeapifyDown         │  HeapifyUp            │
├─────────────────────┼──────────────────────┼───────────────────────┤
│  Dirección          │  Raíz → Hojas        │  Hojas → Raíz         │
│  Compara con        │  Hijos (el mayor)    │  Padre                │
│  Usado en           │  ExtractMax,         │  Insert,              │
│                     │  Build Heap          │  IncreaseKey          │
│  Complejidad        │  O(log n)            │  O(log n)             │
│  Precondición       │  Subárboles son heap │  Resto del heap OK    │
└─────────────────────┴──────────────────────┴───────────────────────┘
```

---

# 11. Build Heap: Método Incremental

## 11.1 Idea

Construir un heap insertando elementos uno por uno:

```text
BuildHeap_Incremental(A, n):
  heap_size = 0
  for i = 0 to n-1:
    Insert(heap, A[i])     // Insert hace BubbleUp → O(log k) para k-ésimo

  Complejidad:
    Σ(i=1 to n) log(i) = log(n!) = Θ(n log n)
```

## 11.2 Ejemplo

```text
Construir heap desde [30, 10, 80, 50, 70, 40, 90]:

Insert 30: [30]                               — 0 swaps
Insert 10: [30, 10]                            — 0 swaps (10 < 30)
Insert 80: [80, 10, 30] ← 80 sube sobre 30    — 1 swap
Insert 50: [80, 50, 30, 10] ← 50 sube sobre 10 — 1 swap
Insert 70: [80, 70, 30, 10, 50] ← 70 sube sobre 50, luego no sobre 80 — 1 swap
Insert 40: [80, 70, 40, 10, 50, 30] ← 40 sube sobre 30 — 1 swap
Insert 90: [90, 70, 80, 10, 50, 30, 40] ← 90 sube: 40→80→90 — 2 swaps

Total: 6 swaps, O(n log n) en general.
```

## 11.3 Problema con este método

```text
O(n log n) es demasiado lento. Si ya tenemos todos los datos,
hay una forma de construir el heap en O(n).
```

---

# 12. Build Heap: Método Bottom-Up (Floyd)

## 12.1 La idea genial

```text
Observación: Las hojas (la mitad del array) ya son heaps triviales.
  → Solo necesitamos hacer HeapifyDown en los nodos INTERNOS.
  → Empezamos desde el último nodo interno y vamos SUBIENDO.

BuildHeap_Floyd(A, n):
  for i = (n/2 - 1) down to 0:     // desde último nodo interno
    HeapifyDown(A, i, n)
```

## 12.2 ¿Por qué funciona?

```text
HeapifyDown(i) requiere que los subárboles de i ya sean heaps.
Si procesamos de abajo hacia arriba:
  → Cuando procesamos i, sus hijos (2i+1 y 2i+2) ya fueron procesados
  → Sus subárboles ya son heaps → la precondición de HeapifyDown se cumple
```

## 12.3 Ejemplo completo

```text
Array original: [30, 10, 80, 50, 70, 40, 90]

Árbol (no es heap):
            30
           /  \
         10    80
        / \   / \
       50 70 40 90

n = 7, último nodo interno = (7/2)-1 = 2

──── HeapifyDown(i=2): nodo 80 ────

  Hijos: left=5(40), right=6(90)
  largest = 6 (90 > 80)
  swap A[2] ↔ A[6]: 80 ↔ 90

            30
           /  \
         10   [90]
        / \   / \
       50 70 40 [80]

──── HeapifyDown(i=1): nodo 10 ────

  Hijos: left=3(50), right=4(70)
  largest = 4 (70 > 10)
  swap A[1] ↔ A[4]: 10 ↔ 70

            30
           /  \
        [70]   90
        / \   / \
       50[10] 40 80

  Continuar: i=4, left=9(fuera) → STOP

──── HeapifyDown(i=0): nodo 30 ────

  Hijos: left=1(70), right=2(90)
  largest = 2 (90 > 70 > 30)
  swap A[0] ↔ A[2]: 30 ↔ 90

           [90]
           /  \
         70   [30]
        / \   / \
       50 10 40 80

  Continuar: i=2, left=5(40), right=6(80)
  largest = 6 (80 > 30)
  swap A[2] ↔ A[6]: 30 ↔ 80

            90
           /  \
         70   [80]
        / \   / \
       50 10 40 [30]

  Continuar: i=6, left=13(fuera) → STOP

──── Resultado ────

Array: [90, 70, 80, 50, 10, 40, 30]

            90
           /  \
         70    80
        / \   / \
       50 10 40 30

✓ Max-Heap válido.
Total HeapifyDown: 3 llamadas, 4 swaps.
Mucho menos que el método incremental.
```

---

# 13. ¿Por qué Build Heap es O(n) y no O(n log n)?

## 13.1 El argumento incorrecto

```text
"Hacemos HeapifyDown n/2 veces, y cada HeapifyDown es O(log n).
 Entonces Build Heap es O(n/2 · log n) = O(n log n)."

→ Esto es una COTA SUPERIOR CORRECTA pero NO AJUSTADA.
  La realidad es mucho mejor porque NO todos los HeapifyDown cuestan O(log n).
```

## 13.2 El argumento correcto

```text
Observación clave: HeapifyDown en un nodo de nivel k puede bajar como máximo
(h - k) niveles, donde h = ⌊log₂(n)⌋ es la altura del árbol.

Nivel   Nodos en nivel   Máx bajada   Trabajo por nivel
──────  ──────────────   ──────────   ──────────────────
  0         1               h             1·h
  1         2               h-1           2·(h-1)
  2         4               h-2           4·(h-2)
  ...
  k         2^k             h-k           2^k·(h-k)
  ...
  h-1     2^(h-1)           1             2^(h-1)·1
  h       2^h               0             0 (hojas, no se procesan)

Trabajo total:
  T = Σ(k=0 to h) 2^k · (h - k)
```

## 13.3 La suma matemática

```text
Sea j = h - k (cambio de variable):
  T = Σ(j=0 to h) 2^(h-j) · j
    = 2^h · Σ(j=0 to h) j / 2^j

La serie Σ(j=0 to ∞) j/2^j converge a 2.

→ T = 2^h · 2 = 2^(h+1) = 2·2^h ≤ 2·n = O(n)

¿Por qué converge?
  j/2^j:  0/1 + 1/2 + 2/4 + 3/8 + 4/16 + 5/32 + ...
        = 0 + 0.5 + 0.5 + 0.375 + 0.25 + 0.15625 + ...
        → Cada término decrece exponencialmente → suma acotada
```

## 13.4 Intuición sin matemáticas

```text
┌──────────────────────────────────────────────────────────────────┐
│  La MAYORÍA de los nodos están ABAJO (hojas y niveles bajos).    │
│  Los nodos de abajo bajan POCO (0-1 niveles).                    │
│  Los nodos de arriba bajan MUCHO pero son MUY POCOS.             │
│                                                                  │
│  Nivel 0: 1 nodo  baja hasta h niveles    → 1·h                 │
│  Nivel h: n/2 nodos bajan 0 niveles       → 0                   │
│                                                                  │
│  El "peso" del trabajo está ARRIBA (pocos nodos, mucho trabajo)  │
│  no ABAJO (muchos nodos, poco trabajo).                          │
│                                                                  │
│  En contraste, el método incremental (insert) sube cada nodo:    │
│  los nodos de ABAJO suben MUCHO → muchos nodos × mucho trabajo  │
│  → O(n log n).                                                   │
│                                                                  │
│  Build Heap (Floyd): muchos nodos × poco trabajo = O(n)          │
│  Build Heap (Insert): muchos nodos × mucho trabajo = O(n log n)  │
└──────────────────────────────────────────────────────────────────┘
```

## 13.5 Comparación visual

```text
Método Floyd (sift-down):          Método Incremental (sift-up):

  1 nodo  baja h niveles               n/2 nodos suben ~h niveles
  2 nodos bajan h-1 niveles            n/4 nodos suben ~h-1 niveles
  4 nodos bajan h-2 niveles            ...
  ...                                  1 nodo sube 0 niveles
  n/2 nodos bajan 0 niveles

  Triángulo "pesado arriba"            Triángulo "pesado abajo"
  (poco trabajo total)                 (mucho trabajo total)

  → O(n)                              → O(n log n)
```

---

# PARTE IV — HEAP SORT

---

# 14. Idea General del Algoritmo

## 14.1 Concepto

```text
Heap Sort ordena un array in-place usando un max-heap:

  Fase 1: Construir un max-heap desde el array              O(n)
  Fase 2: Extraer el máximo repetidamente:
           - Swap raíz (máximo) con el último elemento
           - Reducir el tamaño del heap
           - HeapifyDown la nueva raíz                       O(n log n)

  Total: O(n) + O(n log n) = O(n log n)
```

## 14.2 ¿Por qué funciona?

```text
Después de construir el max-heap:
  → A[0] = máximo del array.

Swap A[0] ↔ A[n-1]:
  → El máximo queda en su posición final (última).
  → El heap se reduce a los primeros n-1 elementos.
  → HeapifyDown en la nueva raíz restaura el heap de tamaño n-1.

Repetir:
  → Cada iteración coloca el siguiente máximo en su posición final.
  → Después de n-1 iteraciones, el array está ordenado ascendentemente.
```

## 14.3 Pseudocódigo

```text
HeapSort(A, n):
  // Fase 1: Build Max-Heap
  for i = (n/2 - 1) down to 0:
    HeapifyDown(A, i, n)

  // Fase 2: Extraer máximos
  for i = n-1 down to 1:
    swap(A[0], A[i])           // máximo va al final
    HeapifyDown(A, 0, i)       // restaurar heap de tamaño i
```

---

# 15. Heap Sort Paso a Paso

## 15.1 Ejemplo completo

```text
Array original: [4, 10, 3, 5, 1]

════════ FASE 1: Build Max-Heap ════════

Árbol original:
         4
        / \
      10    3
     / \
    5   1

HeapifyDown(i=1): nodo 10
  Hijos: 5, 1. largest = 10. No swap.

HeapifyDown(i=0): nodo 4
  Hijos: 10, 3. largest = 10. Swap 4 ↔ 10.

        10
       /  \
      4    3
     / \
    5   1

  Continuar i=1: Hijos: 5, 1. largest = 5. Swap 4 ↔ 5.

        10
       /  \
      5    3
     / \
    4   1

Max-Heap construido: [10, 5, 3, 4, 1]

════════ FASE 2: Extraer máximos ════════

─── Iteración 1: swap A[0] ↔ A[4] (10 ↔ 1) ───

Array: [1, 5, 3, 4, | 10]
               heap ↑     ↑ sorted

HeapifyDown(A, 0, 4):

       [1]                    5
       / \       →           / \
      5   3                 4   3
     /                     /
    4                    [1]

Array: [5, 4, 3, 1, | 10]

─── Iteración 2: swap A[0] ↔ A[3] (5 ↔ 1) ───

Array: [1, 4, 3, | 5, 10]

HeapifyDown(A, 0, 3):

       [1]                    4
       / \       →           / \
      4   3                [1]  3

Array: [4, 1, 3, | 5, 10]

─── Iteración 3: swap A[0] ↔ A[2] (4 ↔ 3) ───

Array: [3, 1, | 4, 5, 10]

HeapifyDown(A, 0, 2):

       [3]
       /          3 > 1 → no swap
      1

Array: [3, 1, | 4, 5, 10]

─── Iteración 4: swap A[0] ↔ A[1] (3 ↔ 1) ───

Array: [1, | 3, 4, 5, 10]

Heap de tamaño 1 → ya es heap.

════════ RESULTADO FINAL ════════

Array: [1, 3, 4, 5, 10]  ✓ Ordenado ascendentemente.
```

## 15.2 Visualización resumen

```text
Array original:         [4, 10, 3, 5, 1]
Después de Build Heap:  [10, 5, 3, 4, 1]
Swap 10↔1, heapify:    [5, 4, 3, 1, | 10]
Swap 5↔1, heapify:     [4, 1, 3, | 5, 10]
Swap 4↔3, heapify:     [3, 1, | 4, 5, 10]
Swap 3↔1:              [1, | 3, 4, 5, 10]
Final:                  [1, 3, 4, 5, 10]  ✓
```

---

# 16. Análisis de Heap Sort

## 16.1 Complejidad temporal

```text
Fase 1 (Build Heap):   O(n)
Fase 2 (Extracciones): n-1 extracciones × O(log n) cada una = O(n log n)

Total:
  Mejor caso:   O(n log n)    — siempre hace las extracciones
  Promedio:     O(n log n)
  Peor caso:    O(n log n)    — ¡NO degenera!

→ Heap Sort es Θ(n log n) en TODOS los casos.
  No tiene un peor caso peor que el promedio (a diferencia de Quick Sort).
```

## 16.2 Complejidad espacial

```text
Espacio extra: O(1)   — in-place (solo variables temporales para swaps)

→ Heap Sort es uno de los pocos sorting O(n log n) que es in-place.
```

## 16.3 Estabilidad

```text
Heap Sort NO es estable.
Elementos iguales pueden cambiar de orden relativo.

Ejemplo:
  [(5,"A"), (3,"B"), (5,"C")]
  Después de Heap Sort: [(3,"B"), (5,"C"), (5,"A")]
  → Los dos 5 cambiaron su orden relativo. No es estable.
```

---

# 17. Comparación con Otros Algoritmos de Sorting

## 17.1 Tabla comparativa

| Algoritmo    | Mejor    | Promedio   | Peor       | Espacio  | Estable | In-place |
| ------------ | -------- | ---------- | ---------- | -------- | ------- | -------- |
| Bubble Sort  | O(n)     | O(n²)     | O(n²)     | O(1)     | ✓       | ✓        |
| Selection    | O(n²)   | O(n²)     | O(n²)     | O(1)     | ✗       | ✓        |
| Insertion    | O(n)     | O(n²)     | O(n²)     | O(1)     | ✓       | ✓        |
| Merge Sort   | O(n lg n)| O(n lg n) | O(n lg n) | O(n)     | ✓       | ✗        |
| Quick Sort   | O(n lg n)| O(n lg n) | **O(n²)** | O(log n) | ✗       | ✓        |
| **Heap Sort**| O(n lg n)| O(n lg n) | O(n lg n) | **O(1)** | ✗       | ✓        |
| Counting     | O(n+k)  | O(n+k)    | O(n+k)    | O(k)     | ✓       | ✗        |

## 17.2 ¿Cuándo elegir Heap Sort?

```text
✅ Usar Heap Sort:
  • Se necesita garantía O(n log n) sin peor caso O(n²)
  • Se necesita sorting in-place (sin memoria extra)
  • Datos no caben en memoria → external sorting parcial
  • Encontrar los K más grandes/pequeños (no sortear todo)

❌ Preferir Quick Sort:
  • En la práctica, Quick Sort es más rápido (mejores constantes)
  • Quick Sort es más cache-friendly (acceso secuencial)

❌ Preferir Merge Sort:
  • Se necesita estabilidad
  • Linked lists (merge sort es O(1) espacio en linked lists)

Nota: En la práctica, Heap Sort se usa POCO para sorting general.
Su verdadero valor está en PRIORITY QUEUES.
```

## 17.3 El "problema" de Heap Sort

```text
Heap Sort es O(n log n) siempre, in-place, sin recursión...
¿Por qué no es el sorting por defecto?

1. Cache misses: Heap Sort accede A[i], A[2i+1], A[2i+2]
   → saltos grandes en memoria → cache-unfriendly.
   Quick Sort accede secuencialmente → cache-friendly.

2. Constantes: Quick Sort hace ~1.39·n·log₂(n) comparaciones promedio.
   Heap Sort hace ~2·n·log₂(n) comparaciones.
   → Quick Sort es ~30% más rápido en práctica.

3. No adaptativo: Heap Sort NO aprovecha datos parcialmente ordenados.
   Insertion Sort: O(n) si casi ordenado.
   Heap Sort: O(n log n) siempre.

→ En la práctica:
  • IntroSort (C++) = Quick Sort + cambio a Heap Sort si degenera
  • TimSort (Python, Java) = Merge Sort + Insertion Sort adaptativo
```

---

# PARTE V — PRIORITY QUEUE

---

# 18. Definición y Operaciones

## 18.1 ¿Qué es una Priority Queue?

```text
Una Priority Queue es un ADT (Abstract Data Type) donde cada elemento
tiene una PRIORIDAD, y las operaciones trabajan con el elemento de
mayor (o menor) prioridad.

Operaciones:
  • Insert(pq, element, priority) — agregar con prioridad
  • ExtractMax(pq) / ExtractMin(pq) — quitar el de mayor/menor prioridad
  • Peek(pq) — ver el de mayor/menor prioridad sin quitarlo
  • ChangePriority(pq, element, new_priority) — cambiar prioridad
  • IsEmpty(pq) — verificar si está vacía

NO es una cola FIFO. Es una cola donde el "orden" lo da la prioridad.
```

## 18.2 Implementaciones posibles

| Implementación    | Insert    | ExtractMin | Peek  | ChangePriority |
| ----------------- | --------- | ---------- | ----- | -------------- |
| Array no ordenado | O(1)      | O(n)       | O(n)  | O(n)           |
| Array ordenado    | O(n)      | O(1)       | O(1)  | O(n)           |
| Linked list       | O(1)      | O(n)       | O(n)  | O(n)           |
| BST balanceado    | O(log n)  | O(log n)   | O(log n)| O(log n)     |
| **Heap (binario)**| O(log n)  | O(log n)   | **O(1)**| O(log n)     |
| Fibonacci Heap    | O(1)*     | O(log n)*  | O(1)  | O(1)*          |

```text
* = amortizado

→ El Heap binario es la implementación estándar de priority queue.
  Simple, eficiente, y con constantes pequeñas.
  Para aplicaciones extremas (Dijkstra con muchos decrease-key),
  el Fibonacci Heap es teóricamente mejor pero raramente usado en práctica.
```

## 18.3 Priority Queue vs Queue vs Stack

```text
Queue (FIFO):     sale el que LLEGÓ PRIMERO
Stack (LIFO):     sale el que LLEGÓ ÚLTIMO
Priority Queue:   sale el de MAYOR PRIORIDAD (sin importar cuándo llegó)

Ejemplo — sala de emergencias:
  Queue:    atiende en orden de llegada (injusto si llega un caso grave)
  Stack:    atiende al último en llegar (absurdo)
  PQ:       atiende al más grave primero (correcto)
```

---

# 19. Implementación con Heap

## 19.1 Mapping

```text
Priority Queue          →  Heap
─────────────────────      ────────────
Insert(element, prio)   →  Insert + BubbleUp
ExtractMin()            →  ExtractMin + BubbleDown     (min-heap)
ExtractMax()            →  ExtractMax + BubbleDown     (max-heap)
Peek()                  →  return A[0]
ChangePriority(i, new)  →  Cambiar + BubbleUp/Down
IsEmpty()               →  size == 0
```

## 19.2 Min-Heap vs Max-Heap para PQ

```text
Min-Heap:
  → ExtractMin = extraer el de MENOR valor = MAYOR prioridad
  → Usado cuando prioridad = costo (menor costo = más prioritario)
  → Dijkstra, scheduling

Max-Heap:
  → ExtractMax = extraer el de MAYOR valor = MAYOR prioridad
  → Usado cuando prioridad = importancia directa
  → Heap Sort

Convención: "Priority Queue" usualmente implica Min-Heap en la literatura.
```

---

# 20. Aplicaciones Reales

## 20.1 Algoritmo de Dijkstra (camino más corto)

```text
Dijkstra necesita:
  1. Extraer el nodo no visitado con MENOR distancia  → ExtractMin
  2. Actualizar distancias de vecinos               → DecreaseKey

→ Priority Queue con Min-Heap.

Sin PQ: O(V²) para encontrar el mínimo en cada paso.
Con PQ: O((V + E) · log V) — mucho más rápido en grafos dispersos.

Pseudocódigo simplificado:
  pq = MinHeap()
  pq.insert(source, 0)
  while not pq.isEmpty():
    u, dist = pq.extractMin()
    for each neighbor v of u:
      if dist + weight(u,v) < dist[v]:
        dist[v] = dist + weight(u,v)
        pq.insert(v, dist[v])        // o decreaseKey
```

## 20.2 Scheduling de procesos (OS)

```text
Un sistema operativo tiene múltiples procesos compitiendo por CPU.
Cada proceso tiene una prioridad.

→ Priority Queue para el scheduler:
  • Insert: nuevo proceso → agregarlo con su prioridad
  • ExtractMax: darle CPU al proceso más prioritario
  • ChangePriority: ajustar prioridad (aging, boost)

Linux CFS (Completely Fair Scheduler):
  Usa un Red-Black Tree (no heap), pero el concepto es el mismo.

Sistemas en tiempo real:
  Usan heaps porque ExtractMax es O(log n) con constantes pequeñas
  y sin overhead de punteros.
```

## 20.3 Merge de K listas ordenadas

```text
Problema: Dadas K listas ordenadas, producir una sola lista ordenada.

Solución con Min-Heap:
  1. Insertar el primer elemento de cada lista en un min-heap
  2. ExtractMin → ese elemento va al resultado
  3. Insertar el siguiente elemento de la lista de donde salió el mínimo
  4. Repetir hasta vaciar todas las listas

Complejidad: O(N · log K)  donde N = total de elementos

Ejemplo:
  Lista 1: [1, 4, 7]
  Lista 2: [2, 5, 8]
  Lista 3: [3, 6, 9]

  Heap: [1, 2, 3]  → extract 1 (de L1), insert 4 → [2, 3, 4]
        [2, 3, 4]  → extract 2 (de L2), insert 5 → [3, 4, 5]
        ...
  Resultado: [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

## 20.4 Top-K elementos

```text
Problema: Encontrar los K más grandes de un stream de N elementos.

Solución con Min-Heap de tamaño K:
  1. Insertar los primeros K elementos
  2. Para cada nuevo elemento:
     • Si es MAYOR que el mínimo del heap (raíz):
       → Reemplazar la raíz con el nuevo elemento
       → HeapifyDown
     • Si no: ignorar

Complejidad: O(N · log K)  — mucho mejor que sortear O(N log N) si K << N

→ Usado en: motores de búsqueda (top-10 resultados),
  sistemas de recomendación, analytics en tiempo real.
```

## 20.5 Mediana de un stream

```text
Problema: Mantener la mediana de un stream de datos.

Solución con DOS heaps:
  • Max-Heap (mitad inferior): contiene los n/2 elementos más pequeños
  • Min-Heap (mitad superior): contiene los n/2 elementos más grandes

  Invariante: |maxHeap.size - minHeap.size| ≤ 1

  Insert(x):
    if x ≤ maxHeap.peek():
      maxHeap.insert(x)
    else:
      minHeap.insert(x)
    // rebalancear si tamaños difieren por más de 1

  Mediana:
    if maxHeap.size == minHeap.size:
      return (maxHeap.peek() + minHeap.peek()) / 2
    else:
      return el peek del heap más grande

Complejidad: Insert O(log n), Mediana O(1)
```

## 20.6 Resumen de aplicaciones

```text
┌────────────────────────────┬──────────────────────────┬────────────┐
│  Aplicación                │  Operación clave         │  Tipo Heap │
├────────────────────────────┼──────────────────────────┼────────────┤
│  Heap Sort                 │  ExtractMax repetido     │  Max-Heap  │
│  Dijkstra                  │  ExtractMin + DecreaseKey│  Min-Heap  │
│  Prim (MST)                │  ExtractMin + DecreaseKey│  Min-Heap  │
│  Huffman Coding            │  ExtractMin × 2 + Insert │  Min-Heap  │
│  Scheduling (OS)           │  ExtractMax + Insert     │  Max-Heap  │
│  Merge K listas            │  ExtractMin + Insert     │  Min-Heap  │
│  Top-K                     │  Peek + Replace          │  Min-Heap  │
│  Mediana de stream         │  Insert + Peek           │  Ambos     │
│  Event-driven simulation   │  ExtractMin + Insert     │  Min-Heap  │
│  Bandwidth management      │  ExtractMax + Insert     │  Max-Heap  │
└────────────────────────────┴──────────────────────────┴────────────┘
```

---

# PARTE VI — IMPLEMENTACIÓN COMPLETA

---

# 21. Implementación en C (Max-Heap)

## 21.1 Estructura y funciones auxiliares

```c
#include <stdio.h>
#include <stdlib.h>

// ─────── Estructura ───────
#define MAX_HEAP_SIZE 1000

typedef struct {
    int data[MAX_HEAP_SIZE];
    int size;
} MaxHeap;

// ─────── Crear heap vacío ───────
MaxHeap* createMaxHeap() {
    MaxHeap *heap = (MaxHeap*)malloc(sizeof(MaxHeap));
    heap->size = 0;
    return heap;
}

// ─────── Funciones de navegación ───────
int parent(int i) { return (i - 1) / 2; }
int leftChild(int i) { return 2 * i + 1; }
int rightChild(int i) { return 2 * i + 2; }

// ─────── Swap ───────
void swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}
```

## 21.2 Heapify Down y Heapify Up

```c
// ─────── Heapify Down (sift-down) ───────
// Precondición: subárboles de i ya son max-heaps
// Postcondición: subárbol con raíz i es max-heap
void heapifyDown(MaxHeap *heap, int i) {
    int size = heap->size;

    while (1) {
        int largest = i;
        int left = leftChild(i);
        int right = rightChild(i);

        if (left < size && heap->data[left] > heap->data[largest]) {
            largest = left;
        }
        if (right < size && heap->data[right] > heap->data[largest]) {
            largest = right;
        }

        if (largest == i) {
            break;    // heap property restaurada
        }

        swap(&heap->data[i], &heap->data[largest]);
        i = largest;  // seguir bajando
    }
}

// ─────── Heapify Up (sift-up) ───────
// Precondición: heap es válido excepto posiblemente en i
// Postcondición: heap completo es válido
void heapifyUp(MaxHeap *heap, int i) {
    while (i > 0 && heap->data[parent(i)] < heap->data[i]) {
        swap(&heap->data[parent(i)], &heap->data[i]);
        i = parent(i);
    }
}
```

## 21.3 Inserción

```c
// ─────── Insert ───────
// 1. Agregar al final (mantener completitud)
// 2. Bubble up (restaurar heap property)
void insert(MaxHeap *heap, int value) {
    if (heap->size >= MAX_HEAP_SIZE) {
        printf("Error: heap lleno.\n");
        return;
    }

    // Agregar al final
    heap->data[heap->size] = value;
    heap->size++;

    // Bubble up
    heapifyUp(heap, heap->size - 1);
}
```

## 21.4 Extracción del máximo

```c
// ─────── Extract Max ───────
// 1. Guardar raíz (máximo)
// 2. Mover último a la raíz
// 3. Bubble down
int extractMax(MaxHeap *heap) {
    if (heap->size <= 0) {
        printf("Error: heap vacío.\n");
        return -1;
    }

    int max = heap->data[0];

    // Mover último elemento a la raíz
    heap->data[0] = heap->data[heap->size - 1];
    heap->size--;

    // Restaurar heap property
    heapifyDown(heap, 0);

    return max;
}
```

## 21.5 Peek y utilidades

```c
// ─────── Peek ───────
int peekMax(MaxHeap *heap) {
    if (heap->size <= 0) {
        printf("Error: heap vacío.\n");
        return -1;
    }
    return heap->data[0];
}

// ─────── Is Empty ───────
int isEmpty(MaxHeap *heap) {
    return heap->size == 0;
}

// ─────── Print Heap como Array ───────
void printHeapArray(MaxHeap *heap) {
    printf("[");
    for (int i = 0; i < heap->size; i++) {
        printf("%d", heap->data[i]);
        if (i < heap->size - 1) printf(", ");
    }
    printf("]\n");
}

// ─────── Print Heap como Árbol ───────
void printHeapTree(MaxHeap *heap, int i, char *prefix, int isRight) {
    if (i >= heap->size) return;

    printf("%s", prefix);
    printf("%s", isRight ? "R── " : "L── ");
    printf("%d\n", heap->data[i]);

    char newPrefix[256];
    snprintf(newPrefix, sizeof(newPrefix), "%s%s",
             prefix, isRight ? "    " : "│   ");

    printHeapTree(heap, leftChild(i), newPrefix, 0);
    printHeapTree(heap, rightChild(i), newPrefix, 1);
}

void printHeap(MaxHeap *heap) {
    if (heap->size == 0) {
        printf("(heap vacío)\n");
        return;
    }
    printf("%d\n", heap->data[0]);
    char prefix[256] = "";
    printHeapTree(heap, leftChild(0), prefix, 0);
    printHeapTree(heap, rightChild(0), prefix, 1);
}
```

## 21.6 Build Heap (Floyd's algorithm)

```c
// ─────── Build Heap desde array ───────
// Copia el array al heap y aplica Floyd's algorithm
MaxHeap* buildMaxHeap(int arr[], int n) {
    MaxHeap *heap = (MaxHeap*)malloc(sizeof(MaxHeap));

    // Copiar datos
    for (int i = 0; i < n && i < MAX_HEAP_SIZE; i++) {
        heap->data[i] = arr[i];
    }
    heap->size = n;

    // Floyd's algorithm: heapify desde el último nodo interno
    for (int i = (n / 2) - 1; i >= 0; i--) {
        heapifyDown(heap, i);
    }

    return heap;
}
```

## 21.7 Heap Sort

```c
// ─────── Heap Sort ───────
// Ordena un array in-place usando max-heap
void heapSort(int arr[], int n) {
    // Fase 1: Build max-heap in-place
    // Usamos el array directamente (sin struct)
    MaxHeap tempHeap;
    for (int i = 0; i < n; i++) {
        tempHeap.data[i] = arr[i];
    }
    tempHeap.size = n;

    for (int i = (n / 2) - 1; i >= 0; i--) {
        heapifyDown(&tempHeap, i);
    }

    // Fase 2: Extraer máximos
    for (int i = n - 1; i > 0; i--) {
        swap(&tempHeap.data[0], &tempHeap.data[i]);
        tempHeap.size--;
        heapifyDown(&tempHeap, 0);
    }

    // Copiar de vuelta
    for (int i = 0; i < n; i++) {
        arr[i] = tempHeap.data[i];
    }
}

// ─────── Heap Sort in-place (sin struct) ───────
void heapifyDownArray(int arr[], int i, int n) {
    while (1) {
        int largest = i;
        int left = 2 * i + 1;
        int right = 2 * i + 2;

        if (left < n && arr[left] > arr[largest])
            largest = left;
        if (right < n && arr[right] > arr[largest])
            largest = right;

        if (largest == i) break;

        swap(&arr[i], &arr[largest]);
        i = largest;
    }
}

void heapSortInPlace(int arr[], int n) {
    // Build max-heap
    for (int i = n / 2 - 1; i >= 0; i--) {
        heapifyDownArray(arr, i, n);
    }

    // Extract max repeatedly
    for (int i = n - 1; i > 0; i--) {
        swap(&arr[0], &arr[i]);
        heapifyDownArray(arr, 0, i);
    }
}
```

## 21.8 Verificación de heap

```c
// ─────── Verificar Max-Heap Property ───────
int isMaxHeap(MaxHeap *heap) {
    for (int i = 1; i < heap->size; i++) {
        if (heap->data[parent(i)] < heap->data[i]) {
            printf("VIOLACIÓN: A[%d]=%d < A[%d]=%d (padre < hijo)\n",
                   parent(i), heap->data[parent(i)], i, heap->data[i]);
            return 0;
        }
    }
    printf("✓ Max-Heap válido (size=%d)\n", heap->size);
    return 1;
}
```

## 21.9 Programa principal (Max-Heap)

```c
int main() {
    printf("═══════════════════════════════════\n");
    printf("   MAX-HEAP — Demostración\n");
    printf("═══════════════════════════════════\n\n");

    // ═══ Inserción uno por uno ═══
    MaxHeap *heap = createMaxHeap();
    int values[] = {30, 10, 80, 50, 70, 40, 90};
    int n = sizeof(values) / sizeof(values[0]);

    printf("── Insertando valores: ");
    for (int i = 0; i < n; i++) printf("%d ", values[i]);
    printf("──\n\n");

    for (int i = 0; i < n; i++) {
        insert(heap, values[i]);
        printf("Insert %d: ", values[i]);
        printHeapArray(heap);
    }

    printf("\nÁrbol resultante:\n");
    printHeap(heap);
    isMaxHeap(heap);

    // ═══ Extracciones ═══
    printf("\n── Extracciones ──\n");
    while (!isEmpty(heap)) {
        int max = extractMax(heap);
        printf("ExtractMax = %d  →  ", max);
        printHeapArray(heap);
    }

    free(heap);

    // ═══ Build Heap (Floyd) ═══
    printf("\n── Build Heap (Floyd) ──\n");
    int arr2[] = {30, 10, 80, 50, 70, 40, 90};
    int n2 = sizeof(arr2) / sizeof(arr2[0]);

    printf("Array original: ");
    for (int i = 0; i < n2; i++) printf("%d ", arr2[i]);
    printf("\n");

    MaxHeap *heap2 = buildMaxHeap(arr2, n2);
    printf("Después de Build Heap: ");
    printHeapArray(heap2);
    printHeap(heap2);
    isMaxHeap(heap2);

    free(heap2);

    // ═══ Heap Sort ═══
    printf("\n── Heap Sort ──\n");
    int arr3[] = {4, 10, 3, 5, 1, 8, 7, 2, 9, 6};
    int n3 = sizeof(arr3) / sizeof(arr3[0]);

    printf("Antes:   ");
    for (int i = 0; i < n3; i++) printf("%d ", arr3[i]);
    printf("\n");

    heapSortInPlace(arr3, n3);

    printf("Después: ");
    for (int i = 0; i < n3; i++) printf("%d ", arr3[i]);
    printf("\n");

    return 0;
}
```

## 21.10 Salida esperada

```text
═══════════════════════════════════
   MAX-HEAP — Demostración
═══════════════════════════════════

── Insertando valores: 30 10 80 50 70 40 90 ──

Insert 30: [30]
Insert 10: [30, 10]
Insert 80: [80, 10, 30]
Insert 50: [80, 50, 30, 10]
Insert 70: [80, 70, 30, 10, 50]
Insert 40: [80, 70, 40, 10, 50, 30]
Insert 90: [90, 70, 80, 10, 50, 30, 40]

Árbol resultante:
90
L── 70
│   L── 10
│   R── 50
R── 80
    L── 30
    R── 40
✓ Max-Heap válido (size=7)

── Extracciones ──
ExtractMax = 90  →  [80, 70, 40, 10, 50, 30]
ExtractMax = 80  →  [70, 50, 40, 10, 30]
ExtractMax = 70  →  [50, 30, 40, 10]
ExtractMax = 50  →  [40, 30, 10]
ExtractMax = 40  →  [30, 10]
ExtractMax = 30  →  [10]
ExtractMax = 10  →  []

── Build Heap (Floyd) ──
Array original: 30 10 80 50 70 40 90
Después de Build Heap: [90, 70, 80, 50, 10, 40, 30]
90
L── 70
│   L── 50
│   R── 10
R── 80
    L── 40
    R── 30
✓ Max-Heap válido (size=7)

── Heap Sort ──
Antes:   4 10 3 5 1 8 7 2 9 6
Después: 1 2 3 4 5 6 7 8 9 10
```

---

# 22. Implementación en C (Min-Heap Priority Queue)

## 22.1 Estructura con prioridad

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PQ_SIZE 1000

// ─────── Elemento con prioridad ───────
typedef struct {
    int id;           // identificador del elemento
    int priority;     // menor valor = mayor prioridad
    char name[50];    // descripción
} PQElement;

// ─────── Min-Heap Priority Queue ───────
typedef struct {
    PQElement data[MAX_PQ_SIZE];
    int size;
} MinPQ;

MinPQ* createMinPQ() {
    MinPQ *pq = (MinPQ*)malloc(sizeof(MinPQ));
    pq->size = 0;
    return pq;
}
```

## 22.2 Operaciones de la Priority Queue

```c
// ─────── Swap ───────
void swapPQ(PQElement *a, PQElement *b) {
    PQElement temp = *a;
    *a = *b;
    *b = temp;
}

// ─────── Heapify Up (Min-Heap) ───────
void pqHeapifyUp(MinPQ *pq, int i) {
    while (i > 0) {
        int p = (i - 1) / 2;
        if (pq->data[p].priority <= pq->data[i].priority) break;
        swapPQ(&pq->data[p], &pq->data[i]);
        i = p;
    }
}

// ─────── Heapify Down (Min-Heap) ───────
void pqHeapifyDown(MinPQ *pq, int i) {
    while (1) {
        int smallest = i;
        int left = 2 * i + 1;
        int right = 2 * i + 2;

        if (left < pq->size &&
            pq->data[left].priority < pq->data[smallest].priority)
            smallest = left;
        if (right < pq->size &&
            pq->data[right].priority < pq->data[smallest].priority)
            smallest = right;

        if (smallest == i) break;
        swapPQ(&pq->data[i], &pq->data[smallest]);
        i = smallest;
    }
}

// ─────── Insert ───────
void pqInsert(MinPQ *pq, int id, int priority, const char *name) {
    if (pq->size >= MAX_PQ_SIZE) {
        printf("Error: PQ llena.\n");
        return;
    }

    PQElement elem;
    elem.id = id;
    elem.priority = priority;
    strncpy(elem.name, name, 49);
    elem.name[49] = '\0';

    pq->data[pq->size] = elem;
    pq->size++;
    pqHeapifyUp(pq, pq->size - 1);
}

// ─────── Extract Min (mayor prioridad = menor valor) ───────
PQElement pqExtractMin(MinPQ *pq) {
    PQElement empty = {-1, -1, ""};
    if (pq->size <= 0) {
        printf("Error: PQ vacía.\n");
        return empty;
    }

    PQElement min = pq->data[0];
    pq->data[0] = pq->data[pq->size - 1];
    pq->size--;
    pqHeapifyDown(pq, 0);

    return min;
}

// ─────── Peek ───────
PQElement pqPeek(MinPQ *pq) {
    PQElement empty = {-1, -1, ""};
    if (pq->size <= 0) {
        printf("Error: PQ vacía.\n");
        return empty;
    }
    return pq->data[0];
}

// ─────── Print PQ ───────
void printPQ(MinPQ *pq) {
    printf("Priority Queue (size=%d):\n", pq->size);
    for (int i = 0; i < pq->size; i++) {
        printf("  [prio=%d] id=%d \"%s\"\n",
               pq->data[i].priority, pq->data[i].id, pq->data[i].name);
    }
}
```

## 22.3 Programa principal (Priority Queue)

```c
int main() {
    printf("═══════════════════════════════════════\n");
    printf("   MIN-HEAP PRIORITY QUEUE — Demo\n");
    printf("═══════════════════════════════════════\n\n");

    MinPQ *pq = createMinPQ();

    // Simular una sala de emergencias
    printf("── Pacientes llegando ──\n");
    pqInsert(pq, 1, 5, "Dolor de cabeza");
    pqInsert(pq, 2, 1, "Paro cardiaco");
    pqInsert(pq, 3, 3, "Fractura de brazo");
    pqInsert(pq, 4, 2, "Hemorragia severa");
    pqInsert(pq, 5, 4, "Fiebre alta");

    printf("\nEstado de la PQ:\n");
    printPQ(pq);

    printf("\nPróximo a atender (peek): ");
    PQElement next = pqPeek(pq);
    printf("[prio=%d] \"%s\"\n", next.priority, next.name);

    // Atender pacientes por prioridad
    printf("\n── Atendiendo pacientes ──\n");
    while (pq->size > 0) {
        PQElement patient = pqExtractMin(pq);
        printf("Atendiendo [prio=%d]: \"%s\" (id=%d)\n",
               patient.priority, patient.name, patient.id);
    }

    // Simular Dijkstra simplificado
    printf("\n── Simulación tipo Dijkstra ──\n");
    pqInsert(pq, 0, 0, "Nodo A (source)");
    pqInsert(pq, 1, 4, "Nodo B");
    pqInsert(pq, 2, 2, "Nodo C");
    pqInsert(pq, 3, 7, "Nodo D");
    pqInsert(pq, 4, 1, "Nodo E");

    printf("\nProcesando nodos por distancia:\n");
    while (pq->size > 0) {
        PQElement node = pqExtractMin(pq);
        printf("  Procesar %s (dist=%d)\n", node.name, node.priority);
    }

    free(pq);
    return 0;
}
```

## 22.4 Salida esperada

```text
═══════════════════════════════════════
   MIN-HEAP PRIORITY QUEUE — Demo
═══════════════════════════════════════

── Pacientes llegando ──

Estado de la PQ:
Priority Queue (size=5):
  [prio=1] id=2 "Paro cardiaco"
  [prio=2] id=4 "Hemorragia severa"
  [prio=3] id=3 "Fractura de brazo"
  [prio=5] id=1 "Dolor de cabeza"
  [prio=4] id=5 "Fiebre alta"

Próximo a atender (peek): [prio=1] "Paro cardiaco"

── Atendiendo pacientes ──
Atendiendo [prio=1]: "Paro cardiaco" (id=2)
Atendiendo [prio=2]: "Hemorragia severa" (id=4)
Atendiendo [prio=3]: "Fractura de brazo" (id=3)
Atendiendo [prio=4]: "Fiebre alta" (id=5)
Atendiendo [prio=5]: "Dolor de cabeza" (id=1)

── Simulación tipo Dijkstra ──

Procesando nodos por distancia:
  Procesar Nodo A (source) (dist=0)
  Procesar Nodo E (dist=1)
  Procesar Nodo C (dist=2)
  Procesar Nodo B (dist=4)
  Procesar Nodo D (dist=7)
```

---

# PARTE VII — SÍNTESIS

---

# 23. Resumen de Complejidad

## 23.1 Operaciones del Heap

| Operación          | Max-Heap   | Min-Heap   | Notas                           |
| ------------------ | ---------- | ---------- | ------------------------------- |
| Peek Max/Min       | **O(1)**   | **O(1)**   | Solo leer A[0]                  |
| Insert             | O(log n)   | O(log n)   | Promedio O(1) amortizado        |
| Extract Max/Min    | O(log n)   | O(log n)   |                                 |
| Build Heap         | **O(n)**   | **O(n)**   | Floyd's algorithm               |
| Heap Sort          | O(n log n) | O(n log n) | In-place, no estable            |
| Buscar un valor    | O(n)       | O(n)       | No hay orden de búsqueda        |
| Delete arbitrary   | O(log n)*  | O(log n)*  | *Si se conoce el índice         |
| Decrease/Increase  | O(log n)   | O(log n)   | Usado en Dijkstra               |

## 23.2 Heap vs todo lo demás

```text
                   Heap    BST(bal.)  Array_ord  Array_no  Hash
                   ────    ─────────  ─────────  ────────  ────
Acceso al extremo  O(1)    O(log n)   O(1)       O(n)     O(n)
Inserción          O(lg n) O(log n)   O(n)       O(1)     O(1)
Buscar cualquiera  O(n)    O(log n)   O(log n)   O(n)     O(1)
Construir          O(n)    O(n lg n)  O(n lg n)  O(n)     O(n)
Espacio extra      O(1)    O(n) ptr   O(1)       O(1)     O(n)

→ Heap: el MEJOR para acceso al extremo + inserción.
  Si necesitas buscar cualquier valor: usa BST o Hash.
```

---

# 24. Errores Comunes y Buenas Prácticas

## 24.1 Tabla de errores

| #  | Error                                                          | Consecuencia                        | Corrección                                     |
| -- | -------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------- |
| 1  | Confundir Heap con BST                                         | Buscar como BST → incorrecto        | Heap no mantiene orden izq-der                 |
| 2  | Usar sift-up para Build Heap                                   | O(n log n) en vez de O(n)           | Usar Floyd (sift-down desde último interno)    |
| 3  | Intercambiar con el hijo MENOR en max-heap                     | Viola heap property                 | Siempre swap con el MAYOR hijo (max-heap)      |
| 4  | Olvidar decrementar size en extractMax                         | Elemento fantasma                   | size-- antes de heapifyDown                    |
| 5  | Indexar desde 1 pero calcular como desde 0                     | Hijos/padres incorrectos            | Elegir convención y ser consistente            |
| 6  | Creer que el min está en la última posición (max-heap)         | Incorrecto                          | El mínimo puede estar en CUALQUIER hoja        |
| 7  | Pensar que Heap Sort es estable                                | Resultados incorrectos con iguales  | Heap Sort NO es estable                        |
| 8  | No verificar límites antes de acceder a hijos                  | Acceso fuera del array              | Siempre: if (left < size) antes de comparar    |
| 9  | Usar heap para búsqueda general                                | O(n) en vez de O(log n) con BST     | Para búsqueda general, usa BST o Hash          |
| 10 | Confundir min-heap con max-heap en priority queue              | Prioridades invertidas              | PQ clásica: min-heap (menor valor = más urgente)|

## 24.2 Buenas prácticas

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. SIEMPRE usa Build Heap (Floyd) si tienes todos los datos     │
│     → O(n) vs O(n log n) del método incremental                 │
│                                                                  │
│  2. Visualiza SIEMPRE árbol + array simultáneamente              │
│     → El array es la implementación, el árbol es la abstracción  │
│                                                                  │
│  3. Escribe isMaxHeap/isMinHeap para verificar en debug          │
│     → Recorrer y verificar parent ≥ child para todo nodo         │
│                                                                  │
│  4. Para priority queue, encapsula las operaciones               │
│     → El usuario no debería manipular el array directamente      │
│                                                                  │
│  5. Si necesitas decrease-key frecuente (Dijkstra):              │
│     → Mantén un array posición[id] → índice en el heap           │
│     → Actualiza al hacer swap                                    │
│     → O(1) para localizar + O(log n) para heapify               │
│                                                                  │
│  6. Para K más grandes: usa min-heap de tamaño K                 │
│     → Mucho más eficiente que sortear todo                       │
│                                                                  │
│  7. Para producción: usa la librería estándar                    │
│     → C: qsort + manual heap, o implementar                     │
│     → C++: std::priority_queue                                   │
│     → Java: PriorityQueue<E>                                     │
│     → Python: heapq                                              │
└──────────────────────────────────────────────────────────────────┘
```

---

# 25. Intuición de Ingeniería

> **Un Heap no es un BST. Es un RANKING.**
> El BST te dice "¿dónde está X?". El Heap te dice "¿quién es el número 1?".
> Esa diferencia simple lo hace perfecto para colas de prioridad, scheduling,
> y cualquier sistema donde la pregunta no es "buscar" sino "¿cuál es el mejor ahora?".
> Y lo hace viviendo en un array, sin punteros, con cache-locality perfecta.

### La idea en una oración

```text
Heap = árbol completo en un array donde la raíz siempre es el extremo.
```

### El mapa mental completo

```text
HEAP
  │
  ├── Propiedad estructural: árbol binario COMPLETO
  │   → Se puede almacenar en ARRAY (sin punteros)
  │   → parent = (i-1)/2, children = 2i+1, 2i+2
  │
  ├── Propiedad de orden: MAX-HEAP o MIN-HEAP
  │   → Raíz = extremo global (max o min)
  │   → padre ≥ hijos (max) o padre ≤ hijos (min)
  │
  ├── Operaciones
  │   ├── Insert:     agregar al final + bubble up    → O(log n)
  │   ├── Extract:    swap raíz↔último + bubble down  → O(log n)
  │   ├── Peek:       return A[0]                     → O(1)
  │   └── Build Heap: Floyd (sift-down bottom-up)     → O(n)
  │
  ├── Aplicaciones
  │   ├── Priority Queue (Dijkstra, scheduling)
  │   ├── Heap Sort (in-place, O(n log n) worst case)
  │   ├── Top-K elements
  │   ├── Mediana de stream (dual heap)
  │   └── Merge de K listas
  │
  └── Limitaciones
      ├── Búsqueda general: O(n) → usar BST
      ├── No estable → usar Merge Sort
      └── Cache: peor que Quick Sort → IntroSort como híbrido
```

### La analogía de la empresa

```text
BST = organigrama donde puedes encontrar a cualquier empleado rápido.
      "¿Dónde está Juan?" → O(log n)

Heap = sistema donde siempre sabes quién es el CEO.
       "¿Quién manda?" → O(1)
       "Reemplazar al CEO" → O(log n) (el siguiente asciende)
       "¿Dónde está Juan?" → O(n) (hay que buscarlo a mano)
```

### Preguntas clásicas de entrevistas

```text
P: ¿Cuál es la complejidad de Build Heap y por qué no es O(n log n)?
R: Es O(n). Aunque heapifyDown es O(log n), la mayoría de nodos están
   abajo y bajan poco. La suma Σ 2^k·(h-k) = O(n) por convergencia
   de la serie geométrica.

P: ¿Heap Sort es estable?
R: No. El swap de la raíz con el último elemento puede cambiar el
   orden relativo de elementos iguales.

P: ¿Cómo encontrar el K-ésimo más grande?
R: Min-heap de tamaño K. Recorrer los datos; si un elemento es mayor
   que el mínimo del heap, reemplazarlo y heapify. Al final, la raíz
   del heap es el K-ésimo más grande. O(n log K).

P: ¿Cuál es la diferencia entre Heap y BST?
R: Heap optimiza acceso al extremo (O(1)) pero no busca (O(n)).
   BST optimiza búsqueda (O(log n)) pero acceso al extremo es O(log n).
   Heap se implementa en array. BST usa punteros.

P: ¿Cómo mantener la mediana de un stream?
R: Dos heaps: max-heap (mitad inferior), min-heap (mitad superior).
   Balancear tamaños. Mediana = peek del más grande o promedio de ambos.
```

### Relación con otros temas

| Tema                              | Archivo              |
| --------------------------------- | -------------------- |
| Arrays a bajo nivel               | Arrays CDT.md        |
| Operaciones sobre arrays          | Arrays ADT.md        |
| Matrices densas y especiales      | Matrices.md          |
| Sparse matrices y polinomios      | SparseMatrices.md    |
| Strings (arrays de char)          | Strings.md           |
| Linked Lists                      | LinkedList.md        |
| Stacks                            | Stack.md             |
| Queues                            | Queue.md             |
| Trees (fundamentos)               | Trees.md             |
| Binary Search Trees               | BinarySearchTree.md  |
| AVL Trees                         | AVLTree.md           |
| 2-3 Trees y 2-3-4 Trees           | 2-3Trees.md          |
| Red-Black Trees                   | RedBlackTree.md      |
| **Heaps y Priority Queues (este)**| Heap.md              |

---

# 26. Ejercicios Sugeridos

## 26.1 Nivel básico

| #  | Ejercicio                                                              | Concepto clave        |
| -- | ---------------------------------------------------------------------- | --------------------- |
| 1  | Insertar {40, 30, 50, 10, 35, 70, 20} en un max-heap, dibujar árbol+array | Insert + sift-up |
| 2  | Extraer el máximo 3 veces del heap anterior, mostrar estado tras cada extracción | ExtractMax + sift-down |
| 3  | Dado el array [5, 3, 17, 10, 84, 19, 6, 22, 9], ¿es un max-heap? | Verificación |
| 4  | Construir un min-heap con {15, 10, 20, 5, 25, 30, 8} paso a paso | Insert en min-heap |

## 26.2 Nivel intermedio

| #  | Ejercicio                                                              | Concepto clave        |
| -- | ---------------------------------------------------------------------- | --------------------- |
| 5  | Construir un max-heap con {3, 1, 6, 5, 2, 4} usando Floyd. Mostrar cada paso | Build Heap bottom-up |
| 6  | Realizar Heap Sort completo sobre {12, 11, 13, 5, 6, 7}. Mostrar cada swap y heapify | Heap Sort paso a paso |
| 7  | Demostrar que la suma Σ(k=0 to h) 2^k·(h-k) ≤ 2n | Análisis de Build Heap |
| 8  | Implementar una PQ donde los pacientes tienen nombre y prioridad numérica | Priority Queue |
| 9  | Dado un stream de 100 enteros, encontrar los 5 más grandes usando un min-heap de tamaño 5 | Top-K |

## 26.3 Nivel avanzado

| #   | Ejercicio                                                            | Concepto clave          |
| --- | -------------------------------------------------------------------- | ----------------------- |
| 10  | Implementar merge de K arrays ordenados usando min-heap              | Merge K listas          |
| 11  | Implementar mediana de un stream con dos heaps                       | Dual heap               |
| 12  | Comparar empíricamente Build Heap (Floyd) vs incremental para n=10000 | Análisis experimental |
| 13  | Implementar decrease-key con array auxiliar de posiciones para Dijkstra | Dijkstra + PQ eficiente |
| 14  | Probar que un heap con n nodos tiene exactamente ⌈n/2⌉ hojas        | Propiedad estructural   |

### Pistas para ejercicios seleccionados

```text
Ejercicio 5 — Build Heap Floyd:
  Array: [3, 1, 6, 5, 2, 4]
  n=6, último nodo interno = (6/2)-1 = 2
  Procesar: i=2 (valor 6), i=1 (valor 1), i=0 (valor 3)
  Para cada uno, aplicar heapifyDown y dibujar el resultado.

Ejercicio 9 — Top-5:
  1. Crear min-heap con los primeros 5 elementos
  2. Para cada nuevo elemento:
     Si > heap[0]: reemplazar heap[0] y heapifyDown
     Si ≤ heap[0]: ignorar
  3. Al final, el heap contiene los 5 más grandes
  → La raíz es el 5to más grande

Ejercicio 11 — Mediana con dos heaps:
  maxHeap = mitad inferior, minHeap = mitad superior
  Insertar x:
    if x ≤ maxHeap.peek(): maxHeap.insert(x)
    else: minHeap.insert(x)
  Rebalancear si |sizes| > 1:
    Mover peek del más grande al más pequeño
  Mediana:
    Si tamaños iguales: (maxHeap.peek() + minHeap.peek()) / 2
    Si no: peek del más grande

Ejercicio 14 — Demostración de hojas:
  En un árbol binario completo con n nodos:
    Nodos internos = ⌊n/2⌋ (tienen al menos un hijo)
    Hojas = n - ⌊n/2⌋ = ⌈n/2⌉
  Esto se puede ver observando que las hojas están en los
  índices ⌊n/2⌋ hasta n-1 del array.
```
