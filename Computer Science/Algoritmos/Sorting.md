# Sorting — Algoritmos de Ordenamiento

> **Idea central:** Ordenar es la operación más fundamental de la computación.
> Detrás de búsqueda, bases de datos, gráficos, compresión y Machine Learning hay un sort.
> La pregunta no es "¿ordeno?", sino **"¿con qué algoritmo?"**.

---

## Tabla de Contenidos

1. [El Problema de Ordenar](#1-el-problema-de-ordenar)
2. [Criterios para Elegir un Algoritmo](#2-criterios-para-elegir-un-algoritmo)
3. [Clasificación: Comparación vs Índice](#3-clasificación-comparación-vs-índice)
4. [Bubble Sort](#4-bubble-sort)
5. [Insertion Sort](#5-insertion-sort)
6. [Selection Sort](#6-selection-sort)
7. [Shell Sort](#7-shell-sort)
8. [Merge Sort](#8-merge-sort)
9. [Quick Sort](#9-quick-sort)
10. [Heap Sort](#10-heap-sort)
11. [Counting Sort](#11-counting-sort)
12. [Radix Sort](#12-radix-sort)
13. [Bucket Sort](#13-bucket-sort)
14. [Comparación Global](#14-comparación-global)
15. [Errores Comunes y Buenas Prácticas](#15-errores-comunes-y-buenas-prácticas)
16. [Intuición de Ingeniería](#16-intuición-de-ingeniería)

---

# 1. El Problema de Ordenar

## 1.1 Definición

Dada una secuencia de `n` elementos comparables, **reorganizarlos** en orden ascendente (o descendente) según una relación de orden.

```text
Entrada:   [5, 2, 8, 1, 9, 3]
                ↓
           [algoritmo]
                ↓
Salida:    [1, 2, 3, 5, 8, 9]
```

## 1.2 ¿Por qué es tan importante?

| Aplicación                   | Por qué importa el orden                |
| ---------------------------- | --------------------------------------- |
| **Búsqueda binaria**         | Requiere datos ordenados → O(log n)     |
| **Bases de datos**           | Índices, joins, agregaciones            |
| **Compresión de datos**      | Run-length encoding, Huffman             |
| **Algoritmos gráficos**      | Kruskal, Dijkstra                       |
| **Computación gráfica**      | Z-buffer, transparencia                 |
| **Machine Learning**         | K-NN, top-k, ranking                    |
| **Sistemas operativos**      | Schedulers, gestión de memoria          |

> **Ordenar es el "Hola Mundo" de la algoritmia. Si lo entiendes bien, el resto es extensión.**

## 1.3 Estabilidad: por qué importa

Un sort es **estable** si preserva el orden relativo de elementos con claves iguales.

```text
Entrada:  [(Alice, 25), (Bob, 20), (Carol, 25)]
                              ↑              ↑
                            empatan en edad

Estable:    [(Bob, 20), (Alice, 25), (Carol, 25)]  ✓ orden original preservado
Inestable:  [(Bob, 20), (Carol, 25), (Alice, 25)]  ✗
```

> **Caso real:** Ordenar empleados primero por depto, luego por nombre. Si el segundo sort no es estable, el primero se pierde.

---

# 2. Criterios para Elegir un Algoritmo

Antes de elegir un algoritmo, hay **5 preguntas clave**:

| # | Pregunta                                       | Criterio         |
| - | ---------------------------------------------- | ---------------- |
| 1 | ¿Cuántas comparaciones hace?                   | Comparaciones    |
| 2 | ¿Cuántos intercambios hace?                    | Swaps            |
| 3 | ¿Su rendimiento mejora con datos parcialmente ordenados? | Adaptativo |
| 4 | ¿Preserva el orden de elementos iguales?       | Estable          |
| 5 | ¿Cuánta memoria extra usa?                     | In-place o no    |

> **Big-O no cuenta toda la historia.** Dos algoritmos O(n²) pueden comportarse de forma muy distinta en la práctica.

---

# 3. Clasificación: Comparación vs Índice

## 3.1 Las dos grandes familias

| Familia              | Cómo ordenan                              | Límite teórico          |
| -------------------- | ----------------------------------------- | ----------------------- |
| **Comparación**      | Usan `a < b` para decidir                 | Ω(n log n) — no mejorable |
| **Índice**           | Usan el **valor** como posición directa   | O(n + k) — lineal posible |

## 3.2 Comparación rápida

| Aspecto              | Comparison-based           | Index-based               |
| -------------------- | -------------------------- | ------------------------- |
| **Operación**        | `a < b`                    | `a → bucket[a]`           |
| **Límite**           | Ω(n log n)                 | O(n + k)                  |
| **Generalidad**      | ✅ Cualquier tipo           | ❌ Tipos discretos         |
| **Memoria**          | O(1) o O(n)                | O(n + k)                  |
| **Estabilidad**      | Depende                    | ✅ Casi siempre            |
| **Algoritmos**       | Bubble, Insertion, Merge, Quick, Heap | Counting, Radix, Bucket |

---

# 4. Bubble Sort

## 4.1 Idea

Comparar **pares adyacentes** e intercambiarlos si están en orden incorrecto. Repetir hasta que no haya intercambios.

> **Analogía:** Burbujas en agua suben a la superficie. Los elementos grandes "burbujean" hacia el final.

## 4.2 Algoritmo

```text
Para i desde 0 hasta n-1:
    Para j desde 0 hasta n-i-1:
        Si arr[j] > arr[j+1]:
            intercambiar arr[j] y arr[j+1]
```

## 4.3 Visualización paso a paso

```text
Pasada 1:  [5, 2, 8, 1, 9]
           [2, 5, 8, 1, 9]    (5>2, swap)
           [2, 5, 8, 1, 9]    (5<8, no swap)
           [2, 5, 1, 8, 9]    (8>1, swap)
           [2, 5, 1, 8, 9]    (8<9, no swap)

Pasada 2:  [2, 5, 1, 8, 9]
           [2, 5, 1, 8, 9]    (2<5, no swap)
           [2, 1, 5, 8, 9]    (5>1, swap)
           [2, 1, 5, 8, 9]    (5<8, no swap)
           [2, 1, 5, 8, 9]    (8<9, no swap)

Pasada 3:  [2, 1, 5, 8, 9]
           [1, 2, 5, 8, 9]    (2>1, swap)
           [1, 2, 5, 8, 9]    resto ya está en orden

Resultado: [1, 2, 5, 8, 9]   ✓
```

## 4.4 Implementación

```c
void bubbleSort(int arr[], int n) {
    for (int i = 0; i < n - 1; i++) {
        int swapped = 0;
        for (int j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
                swapped = 1;
            }
        }
        if (!swapped) break;     // ya está ordenado
    }
}
```

## 4.5 Análisis

| Caso     | Comparaciones | Swaps  | Complejidad |
| -------- | ------------- | ------ | ----------- |
| Mejor    | O(n)          | 0      | O(n)        |
| Promedio | O(n²)         | O(n²)  | O(n²)       |
| Peor     | O(n²)         | O(n²)  | O(n²)       |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(1)    | ✅ Sí   | ✅ Sí      | ✅ Sí    |

## 4.6 Variantes

| Variante                     | Mejora                            |
| ---------------------------- | --------------------------------- |
| **Bubble con flag**          | Terminar si no hubo swaps en una pasada |
| **Cocktail Shaker**          | Bubble en ambas direcciones        |
| **Odd-Even Sort**            | Intercalado para paralelismo       |

---

# 5. Insertion Sort

## 5.1 Idea

Construir el array ordenado **un elemento a la vez**, insertando cada nuevo elemento en su posición correcta dentro de la parte ya ordenada.

> **Analogía:** Ordenar cartas en tu mano. Tomas una carta nueva y la insertas donde corresponde.

## 5.2 Algoritmo

```text
Para i desde 1 hasta n-1:
    key = arr[i]
    j = i - 1
    Mientras j >= 0 y arr[j] > key:
        arr[j+1] = arr[j]      // desplazar
        j--
    arr[j+1] = key             // insertar
```

## 5.3 Visualización paso a paso

```text
[5, 2, 8, 1, 9]   ← arr[0] es "ya ordenado"

i=1, key=2:
  [5, 5, 8, 1, 9]   desplazar 5 a la derecha
  [2, 5, 8, 1, 9]   insertar 2 al inicio

i=2, key=8:
  [2, 5, 8, 1, 9]   8 ya está en su lugar

i=3, key=1:
  [2, 5, 5, 8, 9]   desplazar 5
  [2, 2, 5, 8, 9]   desplazar 2
  [1, 2, 5, 8, 9]   insertar 1

i=4, key=9:
  [1, 2, 5, 8, 9]   ya está

Resultado: [1, 2, 5, 8, 9]   ✓
```

## 5.4 Implementación

```c
void insertionSort(int arr[], int n) {
    for (int i = 1; i < n; i++) {
        int key = arr[i];
        int j = i - 1;
        while (j >= 0 && arr[j] > key) {
            arr[j + 1] = arr[j];
            j--;
        }
        arr[j + 1] = key;
    }
}
```

## 5.5 Análisis

| Caso     | Comparaciones | Shifts   | Complejidad |
| -------- | ------------- | -------- | ----------- |
| Mejor    | O(n)          | 0        | O(n)        |
| Promedio | O(n²)         | O(n²)    | O(n²)       |
| Peor     | O(n²)         | O(n²)    | O(n²)       |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(1)    | ✅ Sí   | ✅ Sí      | ✅ Sí    |

## 5.6 ¿Cuándo es el mejor?

> **Insertion Sort es el rey de los arrays pequeños y casi ordenados.**
> Por eso, algoritmos como Quick Sort lo usan para sub-arrays de tamaño ≤ 16.

| Escenario                    | ¿Por qué gana?                          |
| ---------------------------- | ---------------------------------------- |
| `n` < 16                     | Bajo overhead, sin recursión             |
| Datos casi ordenados         | O(n) en el mejor caso                    |
| Online (llega un dato a la vez) | Insertar es O(log n) con búsqueda binaria |
| Sistema estable + simple     | Código de 5 líneas, sin recursión        |

---

# 6. Selection Sort

## 6.1 Idea

En cada pasada, encontrar el **mínimo** del resto del array y colocarlo en su posición definitiva.

> **Analogía:** Cada vez seleccionas al jugador más bajo del equipo y lo pones al frente de la fila.

## 6.2 Algoritmo

```text
Para i desde 0 hasta n-1:
    minIdx = i
    Para j desde i+1 hasta n:
        Si arr[j] < arr[minIdx]:
            minIdx = j
    intercambiar arr[i] y arr[minIdx]
```

## 6.3 Visualización paso a paso

```text
[5, 2, 8, 1, 9]

i=0: min=1 (en idx 3)  →  swap(arr[0], arr[3])  →  [1, 2, 8, 5, 9]
i=1: min=2 (en idx 1)  →  no swap                →  [1, 2, 8, 5, 9]
i=2: min=5 (en idx 3)  →  swap(arr[2], arr[3])  →  [1, 2, 5, 8, 9]
i=3: min=8 (en idx 3)  →  no swap                →  [1, 2, 5, 8, 9]
i=4: ya está al final  →  no swap                →  [1, 2, 5, 8, 9]
```

## 6.4 Implementación

```c
void selectionSort(int arr[], int n) {
    for (int i = 0; i < n - 1; i++) {
        int minIdx = i;
        for (int j = i + 1; j < n; j++) {
            if (arr[j] < arr[minIdx])
                minIdx = j;
        }
        int temp = arr[i];
        arr[i] = arr[minIdx];
        arr[minIdx] = temp;
    }
}
```

## 6.5 Análisis

| Caso     | Comparaciones | Swaps   | Complejidad |
| -------- | ------------- | ------- | ----------- |
| Mejor    | O(n²)         | O(n)    | O(n²)       |
| Promedio | O(n²)         | O(n)    | O(n²)       |
| Peor     | O(n²)         | O(n)    | O(n²)       |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(1)    | ❌ No   | ❌ No      | ✅ Sí    |

## 6.6 Características únicas

| Fortaleza                       | Razón                                |
| ------------------------------- | ------------------------------------ |
| **Mínimo número de swaps: O(n)** | Solo un swap por pasada             |
| Predecible                      | Mismo tiempo siempre                 |
| Simple                          | Sin condición de parada提前         |

> **Cuándo usarlo:** Cuando el costo de **swap** es enorme (objetos grandes, memoria limitada para escribir) y `n` es pequeño.

---

# 7. Shell Sort

## 7.1 Idea

Generalización de Insertion Sort. Compara elementos **separados por un gap** que se va reduciendo. Cuando el gap = 1, equivale a Insertion Sort, pero el array ya está "casi ordenado".

> **Analogía:** En lugar de comparar cartas adyacentes, primero las ordenas en grupos de 3, luego en grupos de 2, luego 1.

## 7.2 Algoritmo (con secuencia de gaps)

```text
gap = n/2
Mientras gap > 0:
    Para i desde gap hasta n-1:
        temp = arr[i]
        j = i
        Mientras j >= gap y arr[j-gap] > temp:
            arr[j] = arr[j-gap]
            j -= gap
        arr[j] = temp
    gap /= 2
```

## 7.3 Visualización

```text
Array:  [5, 2, 8, 1, 9, 3, 7, 4, 6]
n=9, gaps = 4, 2, 1

Gap = 4: comparar posiciones a distancia 4
        [5, 2, 8, 1, 9, 3, 7, 4, 6]
         ↓           ↓
        comparar (5,9) → no swap
        [2, 5, 8, 1, 9, 3, 7, 4, 6]  swap
            ↓           ↓
        comparar (2,3) → no swap
        ...

Gap = 2:  h-sorted
Gap = 1:  insertion sort (ya casi ordenado)
```

## 7.4 Secuencias de gaps comunes

| Secuencia           | Gap values           | Performance      |
| ------------------- | -------------------- | ---------------- |
| **Original Shell**  | n/2, n/4, ..., 1     | O(n²) peor       |
| **Knuth** (3k+1)    | 1, 4, 13, 40, ...    | O(n^1.5)         |
| **Sedgewick**       | 1, 5, 19, 41, ...    | O(n^1.33)        |
| **Ciura**           | 1, 4, 10, 23, 57, 132| O(n^1.25) empírico |

## 7.5 Análisis

| Caso     | Complejidad        |
| -------- | ------------------ |
| Mejor    | O(n log n)         |
| Promedio | O(n^1.25 – n^1.5)  |
| Peor     | O(n²) (gaps Shell originales) |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(1)    | ❌ No   | ❌ No      | ✅ Sí    |

---

# 8. Merge Sort

## 8.1 Idea

**Divide y conquista:** dividir el array en dos mitades, ordenar cada mitad recursivamente, y luego **merge** (combinar) las dos mitades ordenadas.

> **Analogía:** Ordenar dos pilas de cartas ya ordenadas. Tomas la carta más pequeña de cada pila y la pones en la nueva pila.

## 8.2 Algoritmo

```text
mergeSort(arr, l, r):
    si l < r:
        m = (l + r) / 2
        mergeSort(arr, l, m)        // ordenar mitad izquierda
        mergeSort(arr, m+1, r)      // ordenar mitad derecha
        merge(arr, l, m, r)         // combinar ambas mitades
```

## 8.3 Visualización

```text
[5, 2, 8, 1, 9, 3, 7, 4]

        [5, 2, 8, 1, 9, 3, 7, 4]
        /                       \
   [5, 2, 8, 1]              [9, 3, 7, 4]
   /         \               /          \
[5, 2]    [8, 1]          [9, 3]      [7, 4]
 /  \      /  \            /  \         /  \
[5] [2]  [8] [1]         [9] [3]     [7] [4]
  \/      \/               \/          \/
 [2,5]   [1,8]            [3,9]       [4,7]
    \      /                 \          /
   [1, 2, 5, 8]            [3, 4, 7, 9]
        \                       /
         [1, 2, 3, 4, 5, 7, 8, 9]   ✓
```

## 8.4 Implementación

```c
void merge(int arr[], int l, int m, int r) {
    int n1 = m - l + 1, n2 = r - m;
    int L[n1], R[n2];

    for (int i = 0; i < n1; i++) L[i] = arr[l + i];
    for (int j = 0; j < n2; j++) R[j] = arr[m + 1 + j];

    int i = 0, j = 0, k = l;
    while (i < n1 && j < n2) {
        if (L[i] <= R[j]) arr[k++] = L[i++];
        else              arr[k++] = R[j++];
    }
    while (i < n1) arr[k++] = L[i++];
    while (j < n2) arr[k++] = R[j++];
}

void mergeSort(int arr[], int l, int r) {
    if (l < r) {
        int m = l + (r - l) / 2;
        mergeSort(arr, l, m);
        mergeSort(arr, m + 1, r);
        merge(arr, l, m, r);
    }
}
```

## 8.5 Análisis

| Caso     | Comparaciones | Complejidad |
| -------- | ------------- | ----------- |
| Mejor    | O(n log n)    | O(n log n)  |
| Promedio | O(n log n)    | O(n log n)  |
| Peor     | O(n log n)    | O(n log n)  |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(n)    | ✅ Sí   | ❌ No      | ❌ No    |

## 8.6 Características únicas

| Fortaleza                              | Razón                              |
| -------------------------------------- | ---------------------------------- |
| **Garantía O(n log n)**                | No tiene peor caso malo            |
| **Estable**                            | Merge preserva orden relativo      |
| **Ideal para listas enlazadas**        | Merge no necesita acceso aleatorio |
| **Predecible**                         | Siempre O(n log n)                 |

| Debilidad                              | Consecuencia                       |
| -------------------------------------- | ---------------------------------- |
| **O(n) memoria extra**                 | Problema en sistemas con poca RAM  |
| **No in-place**                        | Cache misses en arrays grandes     |
| **Más lento que Quick en la práctica** | Constantes más altas               |

---

# 9. Quick Sort

## 9.1 Idea

Elegir un **pivote** y **particionar** el array en dos: elementos menores al pivote a la izquierda, mayores a la derecha. Repetir recursivamente.

> **Analogía:** En una fila, todos los menores que X van a la izquierda, los mayores a la derecha. Luego ordenas cada lado.

## 9.2 Algoritmo (esquema)

```text
quickSort(arr, low, high):
    si low < high:
        p = partition(arr, low, high)   // índice del pivote
        quickSort(arr, low, p - 1)
        quickSort(arr, p + 1, high)
```

## 9.3 Estrategias de elección del pivote

| Estrategia           | Descripción                              | Riesgo               |
| -------------------- | ---------------------------------------- | -------------------- |
| **Primer elemento**  | `pivot = arr[low]`                       | ❌ Peor en arrays ordenados |
| **Último elemento**  | `pivot = arr[high]`                      | ❌ Peor en arrays ordenados |
| **Mediana de tres**  | Mediana entre `arr[low]`, `arr[mid]`, `arr[high]` | ✅ Robusto       |
| **Aleatorio**        | `pivot = arr[rand(low, high)]`           | ✅ Robusto            |

## 9.4 Partition (esquema Lomuto)

```text
partition(arr, low, high):
    pivot = arr[high]               // último elemento
    i = low - 1                     // frontera de "menores"
    Para j desde low hasta high-1:
        Si arr[j] <= pivot:
            i++
            swap(arr[i], arr[j])
    swap(arr[i+1], arr[high])
    return i + 1                    // nueva posición del pivote
```

## 9.5 Visualización

```text
[5, 2, 8, 1, 9, 3, 7, 4]   pivot=4

Partition:
  menores a 4: [2, 1, 3]
  pivot: 4
  mayores a 4: [5, 8, 9, 7]

[2, 1, 3, 4, 5, 8, 9, 7]
        ↑
      pivote en su lugar

Recursión:
  quickSort([2, 1, 3])   →  [1, 2, 3]
  quickSort([5, 8, 9, 7]) →  [5, 7, 8, 9]

Resultado: [1, 2, 3, 4, 5, 7, 8, 9]   ✓
```

## 9.6 Implementación

```c
int partition(int arr[], int low, int high) {
    int pivot = arr[high];
    int i = low - 1;
    for (int j = low; j < high; j++) {
        if (arr[j] <= pivot) {
            i++;
            int temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }
    int temp = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp;
    return i + 1;
}

void quickSort(int arr[], int low, int high) {
    if (low < high) {
        int p = partition(arr, low, high);
        quickSort(arr, low, p - 1);
        quickSort(arr, p + 1, high);
    }
}
```

## 9.7 Análisis

| Caso     | Comparaciones | Complejidad |
| -------- | ------------- | ----------- |
| Mejor    | O(n log n)    | O(n log n)  |
| Promedio | O(n log n)    | O(n log n)  |
| Peor     | O(n²)         | O(n²)       |

> El peor caso ocurre cuando el pivote es siempre el mínimo o máximo (array ordenado + mal pivote).

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(log n) | ❌ No  | ❌ No      | ✅ Sí    |

## 9.8 Optimizaciones comunes

| Optimización                  | Mejora                                  |
| ----------------------------- | --------------------------------------- |
| **Pivote aleatorio**          | Evita el peor caso adversarial          |
| **Mediana de tres**           | Buena elección de pivote con poco overhead |
| **Tail call elimination**     | Reduce stack overflow en arrays ordenados |
| **Insertion Sort para n ≤ 16**| Menos recursión, más rápido             |
| **3-way partitioning**        | Maneja duplicados eficientemente (Dutch National Flag) |

## 9.9 Por qué Quick Sort es el rey en la práctica

| Razón                                | Explicación                       |
| ------------------------------------ | --------------------------------- |
| **Cache-friendly**                   | Acceso secuencial en la partición |
| **In-place**                         | Solo O(log n) de stack            |
| **Constante baja**                   | Aunque sea O(n log n), las constantes son menores que Merge Sort |
| **Predicción de branches**           | Hardware moderno optimiza las comparaciones |
| **Usado por la STL de C++**          | `std::sort` es introsort (quicksort + heapsort) |

---

# 10. Heap Sort

## 10.1 Idea

Construir un **max-heap** (montículo máximo) a partir del array. Repetidamente extraer el máximo (raíz) y ponerlo al final.

> **Analogía:** Una fila de優先 donde siempre puedes agarrar al más alto (CEO). Lo "despides" y la fila se reordena.

## 10.2 Algoritmo

```text
heapSort(arr, n):
    // 1. Construir max-heap
    Para i desde n/2 - 1 hasta 0:
        heapify(arr, n, i)

    // 2. Extraer elementos uno a uno
    Para i desde n-1 hasta 1:
        swap(arr[0], arr[i])         // mover raíz al final
        heapify(arr, i, 0)           // restaurar heap en tamaño i
```

## 10.3 Heapify (hundir un nodo)

```c
void heapify(int arr[], int n, int i) {
    int largest = i;
    int left = 2*i + 1;
    int right = 2*i + 2;

    if (left < n && arr[left] > arr[largest])
        largest = left;
    if (right < n && arr[right] > arr[largest])
        largest = right;

    if (largest != i) {
        swap(arr[i], arr[largest]);
        heapify(arr, n, largest);
    }
}
```

## 10.4 Visualización

```text
Array: [5, 2, 8, 1, 9, 3, 7, 4]

Construir max-heap:
                 9
              /     \
             5       8
           /   \    / \
          1     4  3   7
         /
        2

Representación en array: [9, 5, 8, 1, 4, 3, 7, 2]

Extracción:
  swap(9, 2)  →  [2, 5, 8, 1, 4, 3, 7, 9]
  heapify     →  [8, 5, 7, 1, 4, 3, 2, 9]
  swap(8, 2)  →  [2, 5, 7, 1, 4, 3, 8, 9]
  heapify     →  [7, 5, 3, 1, 4, 2, 8, 9]
  ...

Final: [1, 2, 3, 4, 5, 7, 8, 9]   ✓
```

## 10.5 Análisis

| Caso     | Complejidad  |
| -------- | ------------ |
| Mejor    | O(n log n)   |
| Promedio | O(n log n)   |
| Peor     | **O(n log n)** |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(1)    | ❌ No   | ❌ No      | ✅ Sí    |

## 10.6 Características únicas

| Fortaleza                              | Razón                              |
| -------------------------------------- | ---------------------------------- |
| **O(n log n) garantizado**             | No tiene peor caso O(n²)           |
| **In-place**                           | Solo O(1) extra                    |
| **Sin recursión profunda**             | Solo O(log n) de stack             |

| Debilidad                              | Consecuencia                       |
| -------------------------------------- | ---------------------------------- |
| **Constante alta**                     | Más lento que Quick en la práctica |
| **No estable**                         | No apto si necesitas estabilidad   |
| **Cache-unfriendly**                   | El heap "salta" en memoria         |

---

# 11. Counting Sort

## 11.1 Idea

**No compara** elementos. Cuenta cuántas veces aparece cada valor posible y reconstruye el array ordenadamente.

> **Analogía:** En una elección, cuentas los votos por candidato. Luego los ordenas por cantidad.

## 11.2 Algoritmo

```text
countingSort(arr, n, k):        // k = valor máximo
    count[0..k] = 0
    Para cada x en arr:
        count[x]++               // contar ocurrencias

    // reconstruir (versión estable con prefix sum)
    Para i desde 1 hasta k:
        count[i] += count[i-1]   // prefix sum

    output[n]
    Para i desde n-1 hasta 0:
        output[--count[arr[i]]] = arr[i]
    copiar output a arr
```

## 11.3 Visualización

```text
Array: [2, 5, 2, 8, 1, 4, 4, 3]

Contar:
  count[0] = 0
  count[1] = 1
  count[2] = 2
  count[3] = 1
  count[4] = 2
  count[5] = 1
  count[6] = 0
  count[7] = 0
  count[8] = 1

Reconstruir:
  [_, 1, _, 3, _, 5, _, _, 8, _, _, _, 2, _, 4, _, 2]

Resultado: [1, 2, 2, 3, 4, 4, 5, 8]   ✓
```

## 11.4 Implementación

```c
void countingSort(int arr[], int n, int k) {
    int count[k + 1] = {0};
    int output[n];

    for (int i = 0; i < n; i++) count[arr[i]]++;
    for (int i = 1; i <= k; i++) count[i] += count[i - 1];
    for (int i = n - 1; i >= 0; i--)
        output[--count[arr[i]]] = arr[i];
    for (int i = 0; i < n; i++) arr[i] = output[i];
}
```

## 11.5 Análisis

| Caso     | Complejidad |
| -------- | ----------- |
| Mejor    | O(n + k)    |
| Promedio | O(n + k)    |
| Peor     | O(n + k)    |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(n + k)| ✅ Sí   | ❌ No      | ❌ No    |

## 11.6 Restricción crítica

> **Counting Sort solo funciona si el rango `k` es pequeño (k = O(n)).**
> Si los valores son `[1, 10⁹]`, no es viable.

---

# 12. Radix Sort

## 12.1 Idea

Ordenar los números **dígito por dígito**, del menos significativo al más significativo, usando un sort estable (Counting Sort) en cada pasada.

> **Analogía:** Ordenar facturas por día (1-31), luego por mes (1-12), luego por año. Si cada paso es estable, el resultado final es correcto.

## 12.2 Algoritmo

```text
radixSort(arr, n):
    maxVal = max(arr)
    exp = 1                          // dígito menos significativo
    Mientras maxVal / exp > 0:
        countingSortByDigit(arr, n, exp)
        exp *= 10
```

## 12.3 Visualización

```text
Array: [170, 45, 75, 90, 802, 24, 2, 66]

Pasada 1 (unidades):
  [170, 90, 802, 2, 24, 45, 75, 66]

Pasada 2 (decenas):
  [802, 2, 24, 45, 66, 170, 75, 90]

Pasada 3 (centenas):
  [2, 24, 45, 66, 75, 90, 170, 802]   ✓
```

## 12.4 Implementación (LSD con Counting Sort)

```c
void countingSortByDigit(int arr[], int n, int exp) {
    int output[n];
    int count[10] = {0};

    for (int i = 0; i < n; i++)
        count[(arr[i] / exp) % 10]++;

    for (int i = 1; i < 10; i++)
        count[i] += count[i - 1];

    for (int i = n - 1; i >= 0; i--) {
        output[--count[(arr[i] / exp) % 10]] = arr[i];
    }

    for (int i = 0; i < n; i++) arr[i] = output[i];
}

void radixSort(int arr[], int n) {
    int maxVal = arr[0];
    for (int i = 1; i < n; i++)
        if (arr[i] > maxVal) maxVal = arr[i];

    for (int exp = 1; maxVal / exp > 0; exp *= 10)
        countingSortByDigit(arr, n, exp);
}
```

## 12.5 Análisis

| Caso     | Complejidad            |
| -------- | ---------------------- |
| Todos    | O(d · (n + b))         |

Donde:
- `d` = número de dígitos
- `b` = base (típicamente 10)
- `n` = cantidad de elementos

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(n + b)| ✅ Sí   | ❌ No      | ❌ No    |

## 12.6 Variantes

| Variante       | Dirección                       | Uso                        |
| -------------- | ------------------------------- | -------------------------- |
| **LSD**        | Del menos al más significativo  | Números de ancho fijo, strings |
| **MSD**        | Del más al menos significativo  | Strings, números variables |

## 12.7 Radix Sort para strings

```text
Ordenar ["apple", "banana", "cherry", "apricot"]

LSD por carácter:
  por 'e','a','r','t': reorganiza
  por 'p','n','y','p': reorganiza
  por 'p','a','c','r': reorganiza
  ...
Resultado: ["apple", "apricot", "banana", "cherry"]   ✓
```

---

# 13. Bucket Sort

## 13.1 Idea

Distribuir los elementos en **buckets** (cubetas) según su valor, ordenar cada bucket (con insertion sort u otro), y concatenar.

> **Analogía:** En una biblioteca, los libros se separan en estantes por género. Dentro de cada estante, están ordenados alfabéticamente.

## 13.2 Algoritmo

```text
bucketSort(arr, n, k):           // k = número de buckets
    buckets[k] = listas vacías
    Para cada x en arr:
        idx = floor(k * x / maxVal)
        buckets[idx].append(x)

    Para cada bucket:
        insertionSort(bucket)

    concatenar buckets en arr
```

## 13.3 Visualización

```text
Array: [0.42, 0.32, 0.23, 0.52, 0.25, 0.47, 0.51]   k=5

Distribución:
  bucket[0] = [0.23, 0.25, 0.32]    [0.0 - 0.2)
  bucket[1] = [0.42, 0.47]          [0.2 - 0.4)
  bucket[2] = [0.51, 0.52]          [0.4 - 0.6)
  bucket[3] = []
  bucket[4] = []

Ordenar cada bucket (insertion sort):
  bucket[0] = [0.23, 0.25, 0.32]
  bucket[1] = [0.42, 0.47]
  bucket[2] = [0.51, 0.52]

Concatenar: [0.23, 0.25, 0.32, 0.42, 0.47, 0.51, 0.52]   ✓
```

## 13.4 Análisis

| Caso     | Complejidad         |
| -------- | ------------------- |
| Mejor    | O(n + k)            |
| Promedio | O(n + k)            |
| Peor     | **O(n²)** (todos al mismo bucket) |

| Memoria | Estable | Adaptativo | In-place |
| ------- | ------- | ---------- | -------- |
| O(n + k)| ✅ Sí   | ❌ No      | ❌ No    |

## 13.5 Restricción crítica

> **Bucket Sort solo es rápido si la distribución es uniforme.**
> Si todos los valores caen en un solo bucket, degenera a O(n²).

---

# 14. Comparación Global

## 14.1 Tabla maestra

| Algoritmo         | Mejor      | Promedio   | Peor        | Espacio   | Estable | Adaptativo | In-place |
| ----------------- | ---------- | ---------- | ----------- | --------- | ------- | ---------- | -------- |
| **Bubble Sort**   | O(n)       | O(n²)      | O(n²)       | O(1)      | ✅      | ✅         | ✅       |
| **Insertion Sort**| O(n)       | O(n²)      | O(n²)       | O(1)      | ✅      | ✅         | ✅       |
| **Selection Sort**| O(n²)      | O(n²)      | O(n²)       | O(1)      | ❌      | ❌         | ✅       |
| **Shell Sort**    | O(n log n) | O(n^1.5)   | O(n²)       | O(1)      | ❌      | ❌         | ✅       |
| **Merge Sort**    | O(n log n) | O(n log n) | O(n log n)  | O(n)      | ✅      | ❌         | ❌       |
| **Quick Sort**    | O(n log n) | O(n log n) | O(n²)       | O(log n)  | ❌      | ❌         | ✅       |
| **Heap Sort**     | O(n log n) | O(n log n) | O(n log n)  | O(1)      | ❌      | ❌         | ✅       |
| **Counting Sort** | O(n + k)   | O(n + k)   | O(n + k)    | O(n + k)  | ✅      | ❌         | ❌       |
| **Radix Sort**    | O(n·k)     | O(n·k)     | O(n·k)      | O(n + k)  | ✅      | ❌         | ❌       |
| **Bucket Sort**   | O(n + k)   | O(n + k)   | O(n²)       | O(n + k)  | ✅      | ❌         | ❌       |

## 14.2 ¿Cuándo usar cada uno?

| Escenario                                     | Algoritmo recomendado    |
| --------------------------------------------- | ------------------------ |
| `n` ≤ 16                                      | **Insertion Sort**       |
| Datos casi ordenados                          | **Insertion Sort** o **Bubble** |
| Uso general, sin restricciones                | **Quick Sort** (con pivote aleatorio) |
| Garantía de O(n log n) en peor caso          | **Merge Sort** o **Heap Sort**     |
| Necesidad de estabilidad                      | **Merge Sort**           |
| Memoria limitada (in-place)                   | **Heap Sort** o **Quick Sort** |
| Enteros pequeños, k = O(n)                    | **Counting Sort**        |
| Enteros grandes, strings                      | **Radix Sort**           |
| Distribución uniforme (floats en [0,1))      | **Bucket Sort**          |
| Pocos swaps en elementos grandes              | **Selection Sort**       |

## 14.3 Comparación visual de tiempos

```text
Para n = 1,000,000:

Algoritmo              Tiempo aproximado
────────────────────────────────────────
Counting Sort          ~0.01 s
Radix Sort             ~0.5 s
Quick Sort             ~0.5 s
Merge Sort             ~0.8 s
Heap Sort              ~1.2 s
Shell Sort             ~5 s
Insertion Sort         ~30 min (impractical)
Bubble Sort            ~horas
Selection Sort         ~horas
```

## 14.4 Los reyes de la práctica

| Algoritmo          | Cuándo es el rey                                  |
| ------------------ | ------------------------------------------------- |
| **Quick Sort**     | Default en C (`qsort`), C++ (`std::sort` con introsort) |
| **Merge Sort**     | Java (`Arrays.sort` para objetos), Python `Timsort` |
| **Insertion Sort** | Arrays pequeños dentro de Quick/Merge             |
| **Timsort**        | Python, Java para arrays, Swift, V8               |
| **Radix Sort**     | Enteros grandes, strings de longitud fija         |

---

# 15. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                          | Consecuencia                                |
| ---------------------------------------------- | ------------------------------------------- |
| Elegir Bubble Sort "porque es simple"          | O(n²) → inutilizable para n grande         |
| Quick Sort con pivote fijo en array ordenado   | O(n²) garantizado → stack overflow         |
| Ignorar estabilidad cuando se necesita         | Orden de inserciones previas se pierde     |
| Counting Sort con k muy grande                 | OOM (out of memory)                         |
| Implementar Merge Sort con arrays in-place     | Pierde estabilidad y simplicidad            |
| Asumir que O(n log n) es siempre mejor que O(n²)| Para `n < 50`, O(n²) puede ser más rápido  |
| Usar radix sort con números negativos sin adaptar | Orden incorrecto                        |

### ✅ Buenas Prácticas

| Práctica                                            | Razón                                    |
| --------------------------------------------------- | ---------------------------------------- |
| Para uso general → **Quick Sort con pivote aleatorio** | Rápido en promedio, in-place           |
| Si necesitas garantía → **Merge Sort** o **Heap Sort** | Sin sorpresas en el peor caso           |
| Si datos casi ordenados → **Insertion Sort**        | O(n) en el mejor caso                    |
| Combina: Quick Sort + Insertion Sort para `n ≤ 16` | Mejor de ambos mundos                    |
| Counting/Radix solo si rango es manejable           | k = O(n) o n·log(k) razonable            |
| Mide antes de optimizar                             | Profiling > intuición                    |
| Usa `qsort` de la librería estándar                 | Implementación probada y optimizada     |

---

# 16. Intuición de Ingeniería

> **El "mejor" algoritmo de sorting no existe.** Depende de los datos, las restricciones y la métrica que te importa.

### El árbol de decisión

```text
¿Los datos son genéricos (cualquier tipo comparable)?
├── SÍ → ¿Necesitas garantía O(n log n)?
│   ├── SÍ → ¿Memoria es problema?
│   │   ├── SÍ → **Heap Sort**
│   │   └── NO → **Merge Sort** (estable)
│   └── NO → **Quick Sort** (pivote aleatorio)
│
└── NO (tipos discretos) → ¿Cuál es el rango?
    ├── Pequeño (k = O(n)) → **Counting Sort**
    ├── Grande, número de dígitos fijo → **Radix Sort**
    └── Distribución uniforme → **Bucket Sort**
```

### Las 5 reglas mnemotécnicas

| Mnemotécnica          | Significado                                |
| --------------------- | ------------------------------------------ |
| **"Quick en práctica"** | Quick Sort es el más rápido en promedio     |
| **"Merge estable"**   | Merge Sort es estable y predecible         |
| **"Insertion pequeño"**| Insertion Sort gana con `n` < 16           |
| **"Counting pequeño rango"**| Counting Sort gana si k = O(n)         |
| **"Heap in-place"**   | Heap Sort cuando memoria es crítica        |

### El sort que usa Python: Timsort

Python usa **Timsort**, que es un **híbrido**:

```text
Timsort = Merge Sort + Insertion Sort

1. Detecta "runs" (subsecuencias ya ordenadas)
2. Las extiende a un mínimo (típicamente 32-64)
3. Ordena cada run con Insertion Sort
4. Combina runs con Merge Sort (de forma inteligente)
```

| Propiedad                | Valor             |
| ------------------------ | ----------------- |
| Mejor caso (ordenado)    | **O(n)**          |
| Peor caso                | O(n log n)        |
| Estable                  | ✅ Sí             |
| Adaptativo               | ✅ Sí             |
| En práctica              | Más rápido que Quick y Merge |

> **Conclusión:** El sort "perfecto" no es uno solo, sino un **híbrido que aprovecha las características de los datos reales**.

> **Si solo puedes aprender un algoritmo, aprende Quick Sort. Si aprendes dos, agrega Merge Sort. Si quieres el sort definitivo, estudia Timsort.**
