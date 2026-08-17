# Arrays — Abstract Data Type (ADT)

> **Idea central:** Un array es la estructura de datos más fundamental.
> Su poder está en el **acceso directo O(1)** por índice, pero su debilidad está en las **inserciones/eliminaciones O(n)**.
> Saber cuándo usarlo (y cuándo no) es clave.

---

## Tabla de Contenidos

1. [¿Qué es un ADT?](#1-qué-es-un-adt)
2. [El Array como ADT](#2-el-array-como-adt)
3. [Tamaño Lógico vs Físico](#3-tamaño-lógico-vs-físico)
4. [Arrays Estáticos vs Dinámicos](#4-arrays-estáticos-vs-dinámicos)
5. [Operaciones Básicas](#5-operaciones-básicas)
6. [Búsqueda](#6-búsqueda)
7. [Operaciones Avanzadas](#7-operaciones-avanzadas)
8. [Operaciones de Conjuntos](#8-operaciones-de-conjuntos)
9. [Resumen de Complejidad](#9-resumen-de-complejidad)
10. [Errores Comunes y Buenas Prácticas](#10-errores-comunes-y-buenas-prácticas)
11. [Intuición de Ingeniería](#11-intuición-de-ingeniería)

---

# 1. ¿Qué es un ADT?

Un **ADT (Abstract Data Type)** es una **especificación lógica** que define:

- **Qué** operaciones existen
- **Qué** comportamiento tienen
- **Qué** resultados producen

**Sin definir cómo se implementan.**

| Aspecto  | ADT (Abstracto)      | Implementación (Concreta)       |
| -------- | -------------------- | ------------------------------- |
| Enfoque  | Qué hace             | Cómo lo hace                    |
| Nivel    | Conceptual           | Bajo nivel (memoria, punteros)  |
| Ejemplo  | `get(i)` → elemento  | `base + i * sizeof(int)` → RAM  |

> **Analogía:** Un ADT es como el **menú** de un restaurante (qué puedes pedir).
> La implementación es la **cocina** (cómo se prepara).

---

# 2. El Array como ADT

## 2.1 Definición

Un **Array** es una colección **ordenada** de elementos del **mismo tipo**, accesibles por **índice numérico**.

```text
Índice:    0     1     2     3     4
         ┌─────┬─────┬─────┬─────┬─────┐
Valores: │  10 │  20 │  30 │  40 │  50 │
         └─────┴─────┴─────┴─────┴─────┘
```

## 2.2 Características

| Propiedad            | Valor                              |
| -------------------- | ---------------------------------- |
| Ordenado             | Sí (por posición, no por valor)    |
| Acceso por índice    | O(1) — directo                     |
| Tipo de elementos    | Homogéneos (todos del mismo tipo)  |
| Tamaño               | Fijo (estático) o variable (dinámico) |
| Memoria              | Contigua                           |

## 2.3 Operaciones del ADT

| Operación        | Descripción                           |
| ---------------- | ------------------------------------- |
| `create(n)`      | Crear array de tamaño `n`            |
| `get(i)`         | Obtener elemento en índice `i`       |
| `set(i, val)`    | Asignar valor en índice `i`          |
| `insert(i, val)` | Insertar valor en posición `i`       |
| `delete(i)`      | Eliminar elemento en posición `i`    |
| `search(val)`    | Buscar valor y retornar su índice    |
| `length()`       | Retornar cantidad de elementos       |
| `display()`      | Mostrar todos los elementos          |

## 2.4 Casos de uso reales

| Caso de uso                    | Por qué array                         |
| ------------------------------ | ------------------------------------- |
| Buffers en sistemas            | Acceso secuencial rápido              |
| Tablas de datos                | Acceso por índice O(1)                |
| Base para heap, hash table     | Acceso directo necesario              |
| Imágenes (pixels)              | Matriz = array 2D                     |
| Lookup tables                  | Mapeo directo índice → valor          |

---

# 3. Tamaño Lógico vs Físico

Esta distinción es **crítica** y fuente de muchos bugs.

```text
Tamaño físico (capacity) = 8
Tamaño lógico (length)   = 5

Índice:   0    1    2    3    4    5    6    7
        ┌────┬────┬────┬────┬────┬────┬────┬────┐
        │ 10 │ 20 │ 30 │ 40 │ 50 │  ? │  ? │  ? │
        └────┴────┴────┴────┴────┴────┴────┴────┘
        ├──── datos válidos ─────┤├── basura ────┤
```

| Concepto        | Significado                          |
| --------------- | ------------------------------------ |
| **Físico**      | Memoria total reservada (capacity)   |
| **Lógico**      | Elementos realmente almacenados (n)  |

> **Regla:** Siempre usa el tamaño **lógico** para iterar. Nunca el físico.

```c
// ✅ Correcto
for (int i = 0; i < length; i++) { ... }

// ❌ Incorrecto — accede a basura
for (int i = 0; i < capacity; i++) { ... }
```

---

# 4. Arrays Estáticos vs Dinámicos

## 4.1 Array Estático

Tamaño fijo en **tiempo de compilación**. Se almacena en el **stack**.

```c
int arr[10];  // 10 elementos, tamaño inmutable
```

## 4.2 Array Dinámico

Tamaño definido en **tiempo de ejecución**. Se almacena en el **heap**.

```c
int *arr = (int*)malloc(10 * sizeof(int));  // 10 elementos en heap
// ... usar ...
free(arr);  // ⚠️ Obligatorio liberar
```

## 4.3 Comparación

| Aspecto          | Estático              | Dinámico                      |
| ---------------- | --------------------- | ----------------------------- |
| Tamaño           | Fijo (compilación)    | Variable (ejecución)          |
| Memoria          | Stack                 | Heap                          |
| Rendimiento      | Más rápido            | Overhead de malloc/free       |
| Redimensionable  | No                    | Sí (con `realloc`)           |
| Liberar memoria  | Automático            | Manual (`free`)               |
| Riesgo           | Stack overflow        | Memory leak si no haces free  |

## 4.4 Redimensionamiento dinámico

Cuando el array se llena, se crea uno nuevo del **doble de tamaño** y se copian los datos:

```text
Antes:   [10, 20, 30, 40]   ← lleno (capacity = 4)
                                 ↓ realloc × 2
Después: [10, 20, 30, 40, _, _, _, _]   ← capacity = 8
```

```c
arr = (int*)realloc(arr, newCapacity * sizeof(int));
```

| Operación           | Complejidad amortizada |
| ------------------- | ---------------------- |
| Append (con resize) | **O(1) amortizado**    |
| Resize individual   | O(n) — copia todo      |

> La estrategia de **duplicar** el tamaño garantiza que en promedio cada inserción es O(1).

---

# 5. Operaciones Básicas

## 5.1 Get / Set

Acceso y modificación directa por índice.

| Operación | Complejidad | Descripción               |
| --------- | ----------- | ------------------------- |
| `get(i)`  | **O(1)**    | Retorna `arr[i]`          |
| `set(i,v)`| **O(1)**    | Asigna `arr[i] = v`       |

```c
int get(int arr[], int index) {
    return arr[index];
}

void set(int arr[], int index, int value) {
    arr[index] = value;
}
```

> **¿Por qué O(1)?** Porque la dirección se calcula directamente: `base + index × sizeof(int)`

---

## 5.2 Append (Insertar al final)

| Complejidad | Descripción                          |
| ----------- | ------------------------------------ |
| **O(1)**    | Solo escribe en la siguiente posición |

```text
Antes:  [10, 20, 30, _]     length = 3
Append(40):
Después:[10, 20, 30, 40]    length = 4
```

```c
void append(int arr[], int* n, int value) {
    arr[*n] = value;
    (*n)++;
}
```

---

## 5.3 Insert (Insertar en posición)

| Caso              | Complejidad | Descripción                    |
| ----------------- | ----------- | ------------------------------ |
| Al final          | **O(1)**    | No hay desplazamiento          |
| En medio / inicio | **O(n)**    | Desplazar elementos a la derecha |

```text
Insertar 15 en índice 1:

Paso 0: [10, 20, 30, _ ]     length = 3
Paso 1: [10, 20, 30, 30]     mover arr[2] → arr[3]
Paso 2: [10, 20, 20, 30]     mover arr[1] → arr[2]
Paso 3: [10, 15, 20, 30]     escribir 15 en arr[1]
```

```c
void insert(int arr[], int* n, int index, int value) {
    for (int i = *n; i > index; i--)
        arr[i] = arr[i - 1];       // desplazar → derecha
    arr[index] = value;
    (*n)++;
}
```

### Insert en array ordenado

Encuentra la posición correcta y luego inserta manteniendo el orden:

```text
Insertar 25 en array ordenado:

[10, 20, 30, 40, _]  →  [10, 20, 25, 30, 40]
```

```c
void insertSorted(int arr[], int* n, int value) {
    int i = *n - 1;
    while (i >= 0 && arr[i] > value) {
        arr[i + 1] = arr[i];       // desplazar → derecha
        i--;
    }
    arr[i + 1] = value;
    (*n)++;
}
```

---

## 5.4 Delete (Eliminar)

| Caso              | Complejidad | Descripción                      |
| ----------------- | ----------- | -------------------------------- |
| Al final          | **O(1)**    | Solo decrementar length          |
| En medio / inicio | **O(n)**    | Desplazar elementos a la izquierda |

```text
Eliminar índice 1:

Paso 0: [10, 20, 30, 40]     length = 4
Paso 1: [10, 30, 30, 40]     mover arr[2] → arr[1]
Paso 2: [10, 30, 40, 40]     mover arr[3] → arr[2]
Paso 3: [10, 30, 40,  _]     length = 3
```

```c
int delete(int arr[], int* n, int index) {
    int val = arr[index];               // guardar valor eliminado
    for (int i = index; i < *n - 1; i++)
        arr[i] = arr[i + 1];           // desplazar ← izquierda
    (*n)--;
    return val;                         // retornar valor eliminado
}
```

---

## 5.5 Display

| Complejidad | Descripción                |
| ----------- | -------------------------- |
| **O(n)**    | Recorrer todos los elementos |

```c
void display(int arr[], int n) {
    for (int i = 0; i < n; i++)
        printf("%d ", arr[i]);
    printf("\n");
}
```

---

# 6. Búsqueda

## 6.1 Búsqueda Lineal

Recorre **todos** los elementos secuencialmente.

| Caso     | Complejidad |
| -------- | ----------- |
| Mejor    | O(1) — primer elemento |
| Promedio | O(n/2) ≈ O(n) |
| Peor     | O(n) — último o no existe |

```c
int linearSearch(int arr[], int n, int key) {
    for (int i = 0; i < n; i++) {
        if (arr[i] == key)
            return i;
    }
    return -1;
}
```

### Mejora 1: Transposición

Al encontrar el elemento, lo **intercambia con el anterior**. Con búsquedas repetidas, los elementos más buscados "migran" al inicio.

```text
Buscar 30:  [10, 20, 30, 40]
Resultado:  [10, 30, 20, 40]    ← 30 avanzó una posición
```

```c
int linearSearchTranspose(int arr[], int n, int key) {
    for (int i = 0; i < n; i++) {
        if (arr[i] == key) {
            if (i > 0) {
                int temp = arr[i];
                arr[i] = arr[i - 1];
                arr[i - 1] = temp;
            }
            return (i > 0) ? i - 1 : 0;
        }
    }
    return -1;
}
```

### Mejora 2: Move to Front (MTF)

Al encontrar el elemento, lo **mueve al inicio**. Ideal para datos con **acceso sesgado (hot data)**.

```text
Buscar 30:  [10, 20, 30, 40]
Resultado:  [30, 10, 20, 40]    ← 30 se movió al frente
```

```c
int linearSearchMTF(int arr[], int n, int key) {
    for (int i = 0; i < n; i++) {
        if (arr[i] == key) {
            int temp = arr[i];
            arr[i] = arr[0];
            arr[0] = temp;
            return 0;
        }
    }
    return -1;
}
```

### Comparación de estrategias

| Estrategia    | Movimiento           | Mejor para                          |
| ------------- | -------------------- | ----------------------------------- |
| Normal        | Ninguno              | Búsquedas únicas                    |
| Transposición | Avanza 1 posición    | Acceso gradualmente frecuente       |
| Move to Front | Va al índice 0       | Datos con acceso muy sesgado (80/20)|

---

## 6.2 Búsqueda Binaria

Requiere que el array esté **ordenado**. Divide el espacio de búsqueda a la **mitad** en cada paso.

| Caso     | Complejidad  |
| -------- | ------------ |
| Mejor    | O(1) — justo en el medio |
| Promedio | O(log n)     |
| Peor     | O(log n)     |

```text
Buscar 30 en [10, 20, 30, 40, 50, 60, 70]:

Paso 1: low=0, high=6, mid=3 → arr[3]=40 > 30 → high=2
Paso 2: low=0, high=2, mid=1 → arr[1]=20 < 30 → low=2
Paso 3: low=2, high=2, mid=2 → arr[2]=30 = 30 ✓ → return 2
```

### Iterativa

```c
int binarySearch(int arr[], int n, int key) {
    int low = 0, high = n - 1;

    while (low <= high) {
        int mid = low + (high - low) / 2;   // evita overflow

        if (arr[mid] == key)      return mid;
        else if (key < arr[mid])  high = mid - 1;
        else                      low = mid + 1;
    }
    return -1;
}
```

### Recursiva

```c
int binarySearchRec(int arr[], int low, int high, int key) {
    if (low > high)
        return -1;

    int mid = low + (high - low) / 2;

    if (arr[mid] == key)      return mid;
    else if (key < arr[mid])  return binarySearchRec(arr, low, mid - 1, key);
    else                      return binarySearchRec(arr, mid + 1, high, key);
}
```

### Comparación: Lineal vs Binaria

| Aspecto          | Lineal       | Binaria      |
| ---------------- | ------------ | ------------ |
| Complejidad      | O(n)         | O(log n)     |
| Requiere orden   | No           | **Sí**       |
| n = 1,000,000    | ~1,000,000 ops | ~20 ops    |
| Implementación   | Más simple   | Más compleja |

---

# 7. Operaciones Avanzadas

## 7.1 Sum / Average / Min / Max

| Operación   | Complejidad | Descripción                        |
| ----------- | ----------- | ---------------------------------- |
| `sum()`     | O(n)        | Suma de todos los elementos        |
| `average()` | O(n)        | Promedio = sum / length            |
| `min()`     | O(n)        | Valor mínimo                       |
| `max()`     | O(n)        | Valor máximo                       |

```c
int sum(int arr[], int n) {
    int total = 0;
    for (int i = 0; i < n; i++)
        total += arr[i];
    return total;
}

float average(int arr[], int n) {
    return (float)sum(arr, n) / n;
}

int min(int arr[], int n) {
    int m = arr[0];
    for (int i = 1; i < n; i++)
        if (arr[i] < m) m = arr[i];
    return m;
}

int max(int arr[], int n) {
    int m = arr[0];
    for (int i = 1; i < n; i++)
        if (arr[i] > m) m = arr[i];
    return m;
}
```

---

## 7.2 Reverse

Invierte el array **in-place** usando dos punteros.

| Complejidad | Espacio extra |
| ----------- | ------------- |
| O(n)        | O(1)          |

```text
Antes:   [10, 20, 30, 40, 50]
          i→              ←j     swap(10, 50)
          [50, 20, 30, 40, 10]
              i→      ←j         swap(20, 40)
          [50, 40, 30, 20, 10]
                  ij              i ≥ j → termina
```

```c
void reverse(int arr[], int n) {
    int i = 0, j = n - 1;
    while (i < j) {
        int temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
        i++; j--;
    }
}
```

---

## 7.3 Shift (Desplazamiento)

Desplaza todos los elementos una posición. **Se pierde** el elemento del extremo.

| Operación   | Complejidad | Descripción                      |
| ----------- | ----------- | -------------------------------- |
| Shift Left  | O(n)        | `arr[i] = arr[i+1]`, pierde `arr[0]` |
| Shift Right | O(n)        | `arr[i] = arr[i-1]`, pierde `arr[n-1]` |

```text
Shift Left:   [10, 20, 30, 40]  →  [20, 30, 40,  _]
Shift Right:  [10, 20, 30, 40]  →  [ _, 10, 20, 30]
```

```c
void shiftLeft(int arr[], int n) {
    for (int i = 0; i < n - 1; i++)
        arr[i] = arr[i + 1];
}

void shiftRight(int arr[], int n) {
    for (int i = n - 1; i > 0; i--)
        arr[i] = arr[i - 1];
}
```

---

## 7.4 Rotate (Rotación)

Similar a shift, pero el elemento que "sale" **re-entra** por el otro lado. **No se pierde** ningún elemento.

| Operación    | Complejidad | Descripción                      |
| ------------ | ----------- | -------------------------------- |
| Rotate Left  | O(n)        | El primero pasa al final         |
| Rotate Right | O(n)        | El último pasa al inicio         |

```text
Rotate Left:   [10, 20, 30, 40]  →  [20, 30, 40, 10]
Rotate Right:  [10, 20, 30, 40]  →  [40, 10, 20, 30]
```

```c
void rotateLeft(int arr[], int n) {
    int first = arr[0];
    for (int i = 0; i < n - 1; i++)
        arr[i] = arr[i + 1];
    arr[n - 1] = first;
}

void rotateRight(int arr[], int n) {
    int last = arr[n - 1];
    for (int i = n - 1; i > 0; i--)
        arr[i] = arr[i - 1];
    arr[0] = last;
}
```

---

## 7.5 isSorted (Verificar orden)

| Complejidad | Descripción                              |
| ----------- | ---------------------------------------- |
| O(n)        | Compara cada par de elementos adyacentes |

```c
int isSorted(int arr[], int n) {
    for (int i = 0; i < n - 1; i++) {
        if (arr[i] > arr[i + 1])
            return 0;   // no ordenado
    }
    return 1;           // ordenado
}
```

---

## 7.6 Merge (Arrays ordenados)

Combina dos arrays **ya ordenados** en uno solo manteniendo el orden.

| Complejidad | Espacio extra |
| ----------- | ------------- |
| O(n + m)    | O(n + m)      |

```text
a = [1, 3, 5]       b = [2, 4, 6]

Paso 1: 1 < 2 → tomar 1    result = [1]
Paso 2: 3 > 2 → tomar 2    result = [1, 2]
Paso 3: 3 < 4 → tomar 3    result = [1, 2, 3]
Paso 4: 5 > 4 → tomar 4    result = [1, 2, 3, 4]
Paso 5: 5 < 6 → tomar 5    result = [1, 2, 3, 4, 5]
Paso 6: copiar 6           result = [1, 2, 3, 4, 5, 6]
```

```c
void merge(int a[], int n, int b[], int m, int result[]) {
    int i = 0, j = 0, k = 0;

    while (i < n && j < m) {
        if (a[i] <= b[j])
            result[k++] = a[i++];
        else
            result[k++] = b[j++];
    }

    while (i < n) result[k++] = a[i++];
    while (j < m) result[k++] = b[j++];
}
```

---

# 8. Operaciones de Conjuntos

> **Precondición:** Ambos arrays deben estar **ordenados** y sin duplicados para que estas funciones sean O(n + m).

La lógica es siempre la misma: **dos punteros** que avanzan comparando valores.

## 8.1 Union (A ∪ B)

Todos los elementos de ambos arrays, **sin duplicados**.

```text
A = [1, 3, 5, 7]     B = [2, 3, 6, 7]

Union = [1, 2, 3, 5, 6, 7]
```

```c
int unionArr(int a[], int n, int b[], int m, int res[]) {
    int i = 0, j = 0, k = 0;

    while (i < n && j < m) {
        if (a[i] < b[j])       res[k++] = a[i++];
        else if (b[j] < a[i])  res[k++] = b[j++];
        else {                                      // iguales → tomar uno
            res[k++] = a[i];
            i++; j++;
        }
    }

    while (i < n) res[k++] = a[i++];
    while (j < m) res[k++] = b[j++];
    return k;   // retorna tamaño del resultado
}
```

## 8.2 Intersection (A ∩ B)

Solo los elementos que están en **ambos** arrays.

```text
A = [1, 3, 5, 7]     B = [2, 3, 6, 7]

Intersection = [3, 7]
```

```c
int intersection(int a[], int n, int b[], int m, int res[]) {
    int i = 0, j = 0, k = 0;

    while (i < n && j < m) {
        if (a[i] < b[j])       i++;
        else if (b[j] < a[i])  j++;
        else {                                      // iguales → incluir
            res[k++] = a[i];
            i++; j++;
        }
    }
    return k;
}
```

## 8.3 Difference (A - B)

Elementos en A que **no están** en B.

```text
A = [1, 3, 5, 7]     B = [2, 3, 6, 7]

Difference = [1, 5]
```

```c
int difference(int a[], int n, int b[], int m, int res[]) {
    int i = 0, j = 0, k = 0;

    while (i < n && j < m) {
        if (a[i] < b[j])       res[k++] = a[i++];  // solo en A → incluir
        else if (b[j] < a[i])  j++;                 // solo en B → ignorar
        else {                  i++; j++; }          // en ambos → excluir
    }

    while (i < n) res[k++] = a[i++];
    return k;
}
```

## 8.4 Comparación: Naïve vs Eficiente

| Operación    | Naïve (sin ordenar) | Eficiente (ordenados) |
| ------------ | ------------------- | --------------------- |
| Union        | O(n × m)            | **O(n + m)**          |
| Intersection | O(n × m)            | **O(n + m)**          |
| Difference   | O(n × m)            | **O(n + m)**          |

> **Conclusión:** Mantener los arrays ordenados transforma operaciones cuadráticas en lineales.

---

# 9. Resumen de Complejidad

### Operaciones individuales

| Operación         | Mejor caso | Peor caso  | Nota                         |
| ----------------- | ---------- | ---------- | ---------------------------- |
| **Get / Set**     | O(1)       | O(1)       | Acceso directo por índice    |
| **Append**        | O(1)       | O(1)       | Insertar al final            |
| **Insert**        | O(1)       | O(n)       | Peor = inicio (desplazar todo) |
| **Delete**        | O(1)       | O(n)       | Peor = inicio (desplazar todo) |
| **Linear Search** | O(1)       | O(n)       | Mejor = primer elemento      |
| **Binary Search** | O(1)       | O(log n)   | Requiere array ordenado      |
| **Sum/Avg/Min/Max** | O(n)     | O(n)       | Recorrer todo                |
| **Reverse**       | O(n)       | O(n)       | In-place, O(1) espacio extra |
| **Shift/Rotate**  | O(n)       | O(n)       | Mover todos los elementos    |
| **isSorted**      | O(1)       | O(n)       | Mejor = primer par desordenado |
| **Merge**         | O(n+m)     | O(n+m)     | Dos arrays ordenados         |

### Operaciones de conjuntos

| Operación    | Ordenados   | No ordenados |
| ------------ | ----------- | ------------ |
| Union        | O(n + m)    | O(n × m)     |
| Intersection | O(n + m)    | O(n × m)     |
| Difference   | O(n + m)    | O(n × m)     |

---

# 10. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                     | Consecuencia                                |
| ----------------------------------------- | ------------------------------------------- |
| Confundir tamaño lógico con físico        | Iterar sobre basura / datos inválidos       |
| No validar índices antes de acceder       | Index out of bounds → crash o UB            |
| Búsqueda binaria en array no ordenado     | Resultado incorrecto                        |
| Olvidar `(*n)++` después de insert        | Tamaño lógico desincronizado                |
| No liberar memoria dinámica (`free`)      | Memory leak                                 |
| `(low + high) / 2` en binary search       | Integer overflow para n grande              |
| Insertar sin verificar capacity            | Buffer overflow                             |

### ✅ Buenas Prácticas

| Práctica                                  | Razón                                       |
| ----------------------------------------- | ------------------------------------------- |
| Mantener arrays ordenados si hay muchas búsquedas | Habilita binary search O(log n)     |
| Usar Transpose/MTF para búsquedas repetidas | Adapta el array al patrón de acceso       |
| Usar `low + (high - low) / 2` para mid    | Evita integer overflow                      |
| Retornar el valor eliminado en delete      | El caller puede necesitarlo                 |
| Retornar el nuevo tamaño en operaciones de conjuntos | Saber cuántos elementos hay en resultado |
| Verificar `n < capacity` antes de insertar | Prevenir buffer overflow                    |

---

# 11. Intuición de Ingeniería

> Si **lees** más de lo que **modificas** → **array es la mejor opción**.
> Si **modificas** más de lo que **lees** → probablemente necesitas una **lista enlazada**.

### Fortalezas del Array

| Fortaleza              | Razón                                    |
| ---------------------- | ---------------------------------------- |
| Acceso O(1)            | Cálculo directo de dirección             |
| Cache-friendly         | Memoria contigua → prefetch del CPU      |
| Base de otras estructuras | Heap, hash table, queue circular      |
| Simplicidad            | Fácil de entender e implementar          |

### Debilidades del Array

| Debilidad                    | Alternativa                       |
| ---------------------------- | --------------------------------- |
| Insert/Delete en medio O(n)  | Lista enlazada O(1)               |
| Tamaño fijo (estático)       | Array dinámico, vector            |
| Desperdicio de memoria       | Lista enlazada (usa solo lo que necesita) |

### ¿Cuándo usar qué?

| Escenario                              | Estructura recomendada |
| -------------------------------------- | ---------------------- |
| Acceso frecuente por índice            | **Array**              |
| Muchas inserciones/eliminaciones       | **Lista enlazada**     |
| Búsquedas frecuentes en datos ordenados| **Array** + binary search |
| Tamaño desconocido que crece mucho     | **Array dinámico**     |
| Cola/Pila simple                       | **Array** (stack) / **Lista** (queue) |
