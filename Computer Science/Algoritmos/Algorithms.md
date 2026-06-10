# Algorithms — Análisis y Diseño

> **Idea central:** Un algoritmo es una **receta precisa y finita** para resolver un problema.
> La pregunta no es solo "¿funciona?", sino **"¿qué tan bien funciona?"**.
> Esa respuesta vive en el **análisis de complejidad** (Big-O).

---

## Tabla de Contenidos

1. [¿Qué es un Algoritmo?](#1-qué-es-un-algoritmo)
2. [Análisis de Complejidad (Big-O)](#2-análisis-de-complejidad-big-o)
3. [Notación Asintótica](#3-notación-asintótica)
4. [Reglas para Calcular Big-O](#4-reglas-para-calcular-big-o)
5. [Análisis de Bucles](#5-análisis-de-bucles)
6. [Análisis de Recurrencias](#6-análisis-de-recurrencias)
7. [Comparación de Complejidades](#7-comparación-de-complejidades)
8. [Estrategias de Diseño de Algoritmos](#8-estrategias-de-diseño-de-algoritmos)
9. [Algoritmos Fundamentales](#9-algoritmos-fundamentales)
10. [Criterios de Análisis](#10-criterios-de-análisis)
11. [Tipos de Algoritmos: Comparación vs Índice](#11-tipos-de-algoritmos-comparación-vs-índice)
12. [Divide and Conquer](#12-divide-and-conquer)
13. [Greedy (Voraz)](#13-greedy-voraz)
14. [Programación Dinámica](#14-programación-dinámica)
15. [Resumen de Complejidades](#15-resumen-de-complejidades)
16. [Errores Comunes y Buenas Prácticas](#16-errores-comunes-y-buenas-prácticas)
17. [Intuición de Ingeniería](#17-intuición-de-ingeniería)

---

# 1. ¿Qué es un Algoritmo?

## 1.1 Definición

Un **algoritmo** es una **secuencia finita, precisa y ordenada** de instrucciones que resuelve un problema específico en **tiempo finito**.

```text
Entrada  →  [ Algoritmo ]  →  Salida
```

## 1.2 Características obligatorias

| Propiedad      | Significado                                       |
| -------------- | ------------------------------------------------- |
| **Finitud**    | Termina después de un número finito de pasos     |
| **Definitud**  | Cada paso es preciso y sin ambigüedad             |
| **Entrada**    | Cero o más valores de entrada                     |
| **Salida**     | Al menos un valor producido                       |
| **Efectividad**| Cada operación es lo suficientemente básica       |

## 1.3 Ejemplo cotidiano

**Receta para hacer café:**

```text
1. Hervir agua
2. Poner café en el filtro
3. Verter agua caliente
4. Esperar 3 minutos
5. Servir

Entrada:  agua, café, filtro
Salida:   café listo
```

Es **finita**, **precisa** y **efectiva** → es un algoritmo.

## 1.4 ¿Por qué importan los algoritmos?

El mismo problema se puede resolver de formas radicalmente distintas:

```text
Ordenar 1,000,000 números:

Algoritmo A (burbuja):   ~10^12 operaciones  →  varias horas
Algoritmo B (quicksort): ~2·10^7 operaciones  →  ~0.2 segundos
```

> **Mismo problema. Diferente algoritmo. Diferencia abismal.**

---

# 2. Análisis de Complejidad (Big-O)

## 2.1 Los dos recursos que medimos

| Recurso       | Notación          | Pregunta que responde        |
| ------------- | ----------------- | ---------------------------- |
| **Tiempo**    | `T(n)`            | ¿Cuántas operaciones hace?   |
| **Espacio**   | `S(n)`            | ¿Cuánta memoria extra usa?   |

## 2.2 ¿Qué es `n`?

`n` = el **tamaño de la entrada**.

| Problema          | `n`                     |
| ----------------- | ----------------------- |
| Buscar en array   | Cantidad de elementos   |
| Ordenar lista     | Cantidad de elementos   |
| Multiplicar matrices | Dimensión            |
| Recorrer string   | Largo del string        |

## 2.3 La idea clave de Big-O

Big-O describe el **comportamiento asintótico**: cómo crece el costo cuando `n` se vuelve **muy grande**.

Ignoramos:
- Constantes (`3n` → `n`)
- Términos de menor orden (`n² + 5n` → `n²`)

> **Intuición:** Big-O es el "techo" del crecimiento. La pregunta es: **¿cuál es la tendencia dominante?**

---

# 3. Notación Asintótica

## 3.1 Las tres notaciones esenciales

| Notación | Nombre         | Significado                              | Visual           |
| -------- | -------------- | ---------------------------------------- | ---------------- |
| **O(f)** | Big-O (techo)  | Crece **a lo más** como `f(n)`           | ≤ `f(n)`         |
| **Ω(f)** | Omega (piso)   | Crece **al menos** como `f(n)`           | ≥ `f(n)`         |
| **Θ(f)** | Theta (exacto) | Crece **exactamente** como `f(n)`        | = `f(n)`         |

## 3.2 Analogía del mundo real

Imagina una carretera y el tráfico:

| Notación | Analogía                                  |
| -------- | ----------------------------------------- |
| **O**    | "El tráfico **nunca supera** 50 km/h"     |
| **Ω**    | "El tráfico **nunca baja** de 30 km/h"    |
| **Θ**    | "El tráfico **siempre está** entre 30 y 50" |

## 3.3 ¿Por qué O es la más usada?

Porque en ingeniería lo que más nos importa es el **peor caso** (o al menos, una cota superior razonable).

---

# 4. Reglas para Calcular Big-O

## 4.1 Reglas fundamentales

| Regla                              | Ejemplo                    | Resultado    |
| ---------------------------------- | -------------------------- | ------------ |
| **Constantes**                     | `O(5n)`                    | `O(n)`       |
| **Suma: max domina**               | `O(n² + n)`                | `O(n²)`      |
| **Producto: multiplicar**          | `O(n · m)`                 | `O(n·m)`     |
| **Bucles = multiplicar iteraciones** | 3 bucles de `n`           | `O(n³)`      |
| **Bucles anidados**                | loop dentro de loop        | `O(n²)`      |
| **Bucles secuenciales**            | loop + loop                | `O(n + n)` = `O(n)` |
| **Logaritmos**                     | Dividir a la mitad cada vez| `O(log n)`   |

## 4.2 Ejemplo paso a paso

```c
int ejemplo(int arr[], int n) {
    int suma = 0;                          // O(1)
    for (int i = 0; i < n; i++)            // O(n)
        suma += arr[i];
    for (int i = 0; i < n; i++)            // O(n)
        for (int j = 0; j < n; j++)        // O(n)
            printf("%d ", arr[i] * arr[j]); // O(1)
    return suma;                            // O(1)
}
```

**Análisis:**

```text
O(1) + O(n) + O(n·n) + O(1)
= O(1) + O(n) + O(n²) + O(1)
= O(n²)            ← el término dominante gana
```

## 4.3 La jerarquía del crecimiento

De **más rápido** a **más lento**:

```text
O(1) < O(log n) < O(√n) < O(n) < O(n log n) < O(n²) < O(n³) < O(2ⁿ) < O(n!)
```

> **Para `n = 1,000,000`:**
>
> | Big-O       | Operaciones aprox. |
> | ----------- | ------------------ |
> | O(1)        | 1                  |
> | O(log n)    | 20                 |
> | O(n)        | 1,000,000          |
> | O(n log n)  | 20,000,000         |
> | O(n²)       | 10¹² (¡demasiadas!)|
> | O(2ⁿ)       | Calor del universo |

---

# 5. Análisis de Bucles

## 5.1 Bucle simple

```c
for (int i = 0; i < n; i++)    // n iteraciones
    printf("%d", arr[i]);
```

```text
Complejidad: O(n)
```

## 5.2 Bucles anidados

```c
for (int i = 0; i < n; i++)          // n veces
    for (int j = 0; j < n; j++)      // n veces
        printf("%d", arr[i] + arr[j]);
```

```text
Complejidad: O(n · n) = O(n²)
```

## 5.3 Bucles con división (logarítmicos)

```c
for (int i = 1; i < n; i *= 2)       // i: 1, 2, 4, 8, 16, ...  → log₂(n) iteraciones
    printf("%d", i);
```

```text
Complejidad: O(log n)
```

> **Regla práctica:** Si el contador se **multiplica o divide**, es **log n**. Si se **suma o resta**, es **n**.

## 5.4 Tabla resumen

| Patrón de bucle                              | Complejidad   |
| -------------------------------------------- | ------------- |
| `i++; i < n`                                  | `O(n)`        |
| `i *= 2; i < n`                               | `O(log n)`    |
| `i /= 2; i > 0`                               | `O(log n)`    |
| `i = i*i; i < n`                              | `O(log log n)`|
| Anidado: `i < n` con `j < n` dentro          | `O(n²)`       |
| Anidado: `i < n` con `j < log n` dentro      | `O(n log n)`  |
| Anidado: `i < n` con `j < m` dentro          | `O(n·m)`      |

---

# 6. Análisis de Recurrencias

## 6.1 ¿Qué es una recurrencia?

Una **recurrencia** es una ecuación que define una función en términos de **sí misma con entrada más pequeña**.

```text
T(n) = 2·T(n/2) + O(n)        ← merge sort
T(n) = T(n-1) + O(1)          ← búsqueda lineal recursiva
T(n) = T(n/2) + O(1)          ← búsqueda binaria
```

## 6.2 Método maestro (Maestro Theorem)

Para recurrencias de la forma:

```text
T(n) = a·T(n/b) + O(nᵈ)
```

| Caso   | Condición              | Resultado             | Ejemplo             |
| ------ | ---------------------- | --------------------- | ------------------- |
| **1**  | `d < log_b(a)`         | `O(n^(log_b(a)))`     | Búsqueda con 2 ramas|
| **2**  | `d = log_b(a)`         | `O(nᵈ · log n)`       | Merge sort          |
| **3**  | `d > log_b(a)`         | `O(nᵈ)`               | Recorrido simple    |

> **Intuición:** Compara el **trabajo por nivel** (la división) con el **trabajo de combinación** (`nᵈ`).

## 6.3 Ejemplo: Merge Sort

```text
T(n) = 2·T(n/2) + O(n)

a = 2, b = 2, d = 1
log_b(a) = log₂(2) = 1
d = log_b(a)  →  Caso 2

Resultado: O(n¹ · log n) = O(n log n)
```

## 6.4 Ejemplo: Búsqueda Binaria

```text
T(n) = 1·T(n/2) + O(1)

a = 1, b = 2, d = 0
log_b(a) = log₂(1) = 0
d = log_b(a)  →  Caso 2

Resultado: O(n⁰ · log n) = O(log n)
```

---

# 7. Comparación de Complejidades

## 7.1 Tabla de tiempos concretos

| n        | O(1)   | O(log n) | O(n)      | O(n log n)  | O(n²)         | O(2ⁿ)              |
| -------- | ------ | -------- | --------- | ----------- | ------------- | ------------------ |
| 10       | 1      | 3        | 10        | 33          | 100           | 1,024              |
| 100      | 1      | 7        | 100       | 664         | 10,000        | 1.27 × 10³⁰        |
| 1,000    | 1      | 10       | 1,000     | 9,966       | 1,000,000     | Infinito           |
| 10,000   | 1      | 13       | 10,000    | 132,877     | 10⁸           | Absurdo            |
| 1,000,000| 1      | 20       | 10⁶       | 2·10⁷       | 10¹²          | Calor del universo |

## 7.2 Visualización del crecimiento

```text
Crecimiento
    │
10²⁰│                                          *
    │                                       *
    │                                    *
    │                                 *
    │                              *
    │                          *
    │                      *
    │                  *
    │              *
    │          *
    │      *
    │   *
    │ *
  0 └──────────────────────────────────────────→ n
    0    10   20   30   40   50   60   70   80

    O(1) ─── O(log n) ─── O(n) ─── O(n²) ─── O(2ⁿ)
```

## 7.3 Regla de oro

> **Si tu algoritmo es O(n²) o peor, probablemente hay una mejor solución.**

---

# 8. Estrategias de Diseño de Algoritmos

## 8.1 Panorama general

| Estrategia                  | Idea central                                  |
| --------------------------- | --------------------------------------------- |
| **Brute Force**             | Probar todas las opciones                     |
| **Divide and Conquer**      | Dividir → resolver → combinar                 |
| **Greedy**                  | Elegir la opción localmente óptima            |
| **Programación Dinámica**   | Resolver subproblemas una sola vez            |
| **Backtracking**            | Probar opciones y deshacer si no funciona     |
| **Branch and Bound**        | Backtracking + poda inteligente               |

## 8.2 Brute Force

La solución más obvia: **probar todo**.

```text
Ejemplo: encontrar par que suma K
Recorrer todos los pares (i, j) y verificar.

Complejidad: O(n²)
```

> **Ventaja:** simple. **Desventaja:** lento.

---

# 9. Algoritmos Fundamentales

## 9.1 Búsqueda Lineal

Recorre el array de izquierda a derecha.

```c
int linearSearch(int arr[], int n, int key) {
    for (int i = 0; i < n; i++)
        if (arr[i] == key)
            return i;
    return -1;
}
```

| Caso     | Complejidad |
| -------- | ----------- |
| Mejor    | O(1)        |
| Promedio | O(n)        |
| Peor     | O(n)        |

## 9.2 Búsqueda Binaria

Divide el espacio de búsqueda a la mitad en cada paso.

```c
int binarySearch(int arr[], int n, int key) {
    int low = 0, high = n - 1;
    while (low <= high) {
        int mid = low + (high - low) / 2;
        if (arr[mid] == key)      return mid;
        else if (key < arr[mid])  high = mid - 1;
        else                      low = mid + 1;
    }
    return -1;
}
```

| Caso | Complejidad |
| ---- | ----------- |
| Todos| O(log n)    |

> **Requisito:** array **ordenado**.

## 9.3 Comparación

| n            | Lineal (O(n)) | Binaria (O(log n)) |
| ------------ | ------------- | ------------------ |
| 1,000        | 1,000 ops     | 10 ops             |
| 1,000,000    | 1,000,000 ops | 20 ops             |
| 1,000,000,000| 10⁹ ops       | 30 ops             |

---

# 10. Criterios de Análisis

> **Idea central:** Big-O no cuenta toda la historia. Para elegir bien entre algoritmos que comparten la misma complejidad (o similar), necesitamos otros **criterios de análisis** que revelen su comportamiento real.

## 10.1 ¿Por qué necesitamos más criterios?

Dos algoritmos pueden ser ambos `O(n²)` y comportarse **muy distinto** en la práctica.

```text
Bubble Sort:    O(n²) pero termina en O(n) si ya está ordenado
Selection Sort: O(n²) SIEMPRE, aunque esté ordenado
```

**Big-O por sí solo no captura esa diferencia.** Necesitamos métricas más finas.

## 10.2 Número de Comparaciones

Cuenta **cuántas veces el algoritmo compara dos elementos**.

Es la métrica dominante en algoritmos de **búsqueda y ordenamiento**, porque las comparaciones son típicamente la operación más costosa.

| Algoritmo          | Comparaciones (peor caso) |
| ------------------ | ------------------------- |
| Bubble Sort        | O(n²)                     |
| Selection Sort     | O(n²)                     |
| Insertion Sort     | O(n²)                     |
| Merge Sort         | O(n log n)                |
| Quick Sort         | O(n²) peor / O(n log n) promedio |
| Binary Search      | O(log n)                  |

> **Por qué importa:** comparar puede ser caro (strings largos, objetos complejos). Menos comparaciones = más rápido.

## 10.3 Número de Swaps (Intercambios)

Cuenta **cuántas veces el algoritmo intercambia dos elementos**.

Crítico cuando:
- Los elementos son **grandes** (struct, objetos)
- El swap es **costoso** (copiar memoria)
- Estamos en hardware con **memoria limitada** (escribir es caro)

| Algoritmo          | Swaps (peor caso)          |
| ------------------ | -------------------------- |
| Bubble Sort        | O(n²) — muchos swaps       |
| Selection Sort     | **O(n)** — mínimo posible  |
| Insertion Sort     | O(n²) — muchos shifts      |
| Quick Sort         | O(n log n) promedio        |
| Merge Sort         | **O(n log n)** — muchas escrituras |

> **Selección clave:** Si los elementos son enormes y minimizar swaps es crítico → **Selection Sort** es sorprendentemente bueno.

## 10.4 Adaptive (Adaptativo)

Un algoritmo es **adaptativo** si su rendimiento **mejora cuando la entrada ya está parcialmente ordenada**.

```text
Entrada: [1, 2, 3, 4, 5, 6, 7, 8]   ← ya ordenada

Bubble Sort:    O(n)   (termina en una pasada, sin swaps)  → ADAPTATIVO
Selection Sort: O(n²)  (recorre todo sin importar)         → NO ADAPTATIVO
Insertion Sort: O(n)   (cero inserciones necesarias)       → ADAPTATIVO
```

### Definición formal

> Un algoritmo es **adaptativo** si su complejidad en el caso **mejor** es estrictamente menor que en el caso **peor**.

| Algoritmo         | Mejor caso | Peor caso | ¿Adaptativo? |
| ----------------- | ---------- | --------- | ------------ |
| **Bubble Sort**   | O(n)       | O(n²)     | ✅ Sí        |
| **Insertion Sort**| O(n)       | O(n²)     | ✅ Sí        |
| **Selection Sort**| O(n²)      | O(n²)     | ❌ No        |
| **Merge Sort**    | O(n log n) | O(n log n)| ❌ No        |
| **Quick Sort**    | O(n log n) | O(n²)     | ❌ No        |
| **Heap Sort**     | O(n log n) | O(n log n)| ❌ No        |

> **Intuición:** Si tus datos están **casi ordenados** o son **pocas modificaciones de un conjunto ya ordenado**, usa algoritmos adaptativos.

## 10.5 Stable (Estable)

Un algoritmo es **estable** si **preserva el orden relativo** de elementos con valores iguales.

```text
Entrada:  [(name="Alice", age=25), (name="Bob", age=20), (name="Carol", age=25)]
                              ↑                              ↑
                          age=25                          age=25

Ordenar por edad ASCENDENTE:

Estable:    [(Bob, 20), (Alice, 25), (Carol, 25)]   ← Alice antes que Carol (mantiene orden)
Inestable:  [(Bob, 20), (Carol, 25), (Alice, 25)]   ← orden original roto
```

### ¿Por qué importa?

Cuando haces **ordenamientos múltiples**, la estabilidad acumula consistencia.

```text
Ordenar empleados primero por departamento, luego por nombre:

Si el segundo sort es estable → los nombres quedan agrupados dentro de cada depto
Si no es estable → los nombres se mezclan entre departamentos
```

### Tabla de estabilidad

| Algoritmo         | ¿Estable?     |
| ----------------- | ------------- |
| **Bubble Sort**   | ✅ Sí         |
| **Insertion Sort**| ✅ Sí         |
| **Merge Sort**    | ✅ Sí         |
| **Selection Sort**| ❌ No         |
| **Quick Sort**    | ❌ No         |
| **Heap Sort**     | ❌ No         |
| **Counting Sort** | ✅ Sí         |
| **Radix Sort**    | ✅ Sí         |

> **Regla práctica:** Si necesitas estabilidad → elige **Merge Sort**, **Insertion Sort** o **Counting Sort**.

## 10.6 Extra Memory (Memoria Extra)

¿Cuánta memoria adicional usa el algoritmo más allá de la entrada?

| Categoría            | Memoria extra  | Ejemplos                       |
| -------------------- | -------------- | ------------------------------ |
| **In-place**         | **O(1)**       | Bubble, Selection, Insertion, Heap, Quick |
| **O(log n)**         | Recursión      | Quick Sort (pila de recursión) |
| **O(n)**             | Array auxiliar | Merge Sort, Counting Sort      |
| **O(n + k)**         | Buckets        | Radix Sort (k = base)          |

### ¿Por qué importa?

En sistemas con **memoria limitada** (embebidos, móviles, kernels), in-place es obligatorio. En servidores con RAM abundante, un poco de espacio extra por mayor velocidad es buen trade-off.

> **Quick Sort** es popular porque es O(n log n) en promedio **y** O(1) de espacio extra. **Merge Sort** es estable pero usa O(n) extra.

## 10.7 Resumen visual de criterios

```text
                        Comparaciones  Swaps   Adaptativo  Estable  In-place
Bubble Sort                 O(n²)       O(n²)     ✅         ✅        ✅
Insertion Sort              O(n²)       O(n²)     ✅         ✅        ✅
Selection Sort              O(n²)       O(n)      ❌         ❌        ✅
Merge Sort                O(n log n)  O(n log n)  ❌         ✅        ❌ (O(n))
Quick Sort (avg)          O(n log n)  O(n log n)  ❌         ❌        ✅
Heap Sort                 O(n log n)  O(n log n)  ❌         ❌        ✅
```

## 10.8 Cómo usar estos criterios en la práctica

| Si necesitas...                                | Elige...                          |
| ---------------------------------------------- | --------------------------------- |
| Pocos swaps en datos grandes                   | **Selection Sort**                |
| Estabilidad garantizada                        | **Merge Sort** o **Counting Sort**|
| Memoria mínima                                 | **Quick Sort** o **Heap Sort**    |
| Datos casi ordenados                           | **Insertion Sort** o **Bubble**   |
| Garantía de O(n log n) en el peor caso         | **Heap Sort** o **Merge Sort**    |
| Velocidad promedio máxima                      | **Quick Sort**                    |

> **Conclusión:** Big-O es el **filtro grueso**. Estos cinco criterios son el **filtro fino** que decide el ganador.

---

# 11. Tipos de Algoritmos: Comparación vs Índice

> **Idea central:** No todos los algoritmos de ordenamiento funcionan igual. La diferencia fundamental está en **cómo deciden dónde va cada elemento**: comparando elementos entre sí, o usando la **posición/índice** como pista.

## 11.1 Las dos grandes familias

| Familia                       | Cómo ordenan                                | Lower bound    |
| ----------------------------- | ------------------------------------------- | -------------- |
| **Comparison-based sorts**    | Comparan pares de elementos con `<`, `>`   | **Ω(n log n)** |
| **Index-based sorts**         | Usan el **valor** del elemento como índice  | **O(n + k)**   |

> Esta distinción es crucial: los index-based sorts pueden **romper la barrera Ω(n log n)** porque no comparan.

## 11.2 Comparison-Based Sorts (Ordenamiento por Comparación)

### Definición

Algoritmos que ordenan elementos **únicamente comparándolos entre sí** con operaciones tipo `a < b`.

```text
¿25 < 15?  →  no
¿25 < 35?  →  sí  →  25 va antes que 35
```

### Ejemplos

| Algoritmo            | Estrategia                    | Complejidad       |
| -------------------- | ----------------------------- | ----------------- |
| **Bubble Sort**      | Intercambiar adyacentes       | O(n²)             |
| **Selection Sort**   | Seleccionar el mínimo         | O(n²)             |
| **Insertion Sort**   | Insertar en posición correcta | O(n²)             |
| **Merge Sort**       | Divide y merge                | O(n log n)        |
| **Quick Sort**       | Particionar por pivote        | O(n log n) avg    |
| **Heap Sort**        | Usar heap                     | O(n log n)        |

### El lower bound: Ω(n log n)

Cualquier comparison-based sort necesita **al menos Ω(n log n)** comparaciones en el peor caso.

**¿Por qué?**

```text
Con n elementos hay n! permutaciones posibles.
Para distinguirlas necesitamos un árbol de decisión de altura h tal que:

   2^h ≥ n!

   h ≥ log₂(n!) ≈ n log n   (por la aproximación de Stirling)
```

> **Visualización (árbol de decisión para n=3):**

```text
                    [a<b?]
                   /      \
                sí /        \ no
                 /            \
            [b<c?]            [a<c?]
           /      \           /      \
        sí/        \ no     sí/        \ no
         /          \       /            \
      [a,b,c]    [a,c,b] [b,a,c]      [c,a,b]
                                (orden correcto)
```

Cada hoja = una permutación. Para n=3, necesitamos 6 hojas → log₂(6) ≈ 2.58 comparaciones mínimas.

### Implicación práctica

> **Ningún comparison-based sort puede ser mejor que O(n log n) en el caso general.**
> Si necesitas O(n) u O(n + k), necesitas un sort **no basado en comparaciones**.

### Resumen de comparison-based sorts

| Algoritmo          | Mejor      | Promedio   | Peor        | Espacio   | Estable | Adaptativo |
| ------------------ | ---------- | ---------- | ----------- | --------- | ------- | ---------- |
| **Bubble Sort**    | O(n)       | O(n²)      | O(n²)       | O(1)      | ✅      | ✅         |
| **Insertion Sort** | O(n)       | O(n²)      | O(n²)       | O(1)      | ✅      | ✅         |
| **Selection Sort** | O(n²)      | O(n²)      | O(n²)       | O(1)      | ❌      | ❌         |
| **Merge Sort**     | O(n log n) | O(n log n) | O(n log n)  | O(n)      | ✅      | ❌         |
| **Quick Sort**     | O(n log n) | O(n log n) | O(n²)       | O(log n)  | ❌      | ❌         |
| **Heap Sort**      | O(n log n) | O(n log n) | O(n log n)  | O(1)      | ❌      | ❌         |

## 11.3 Index-Based Sorts (Ordenamiento por Índice)

### Definición

Algoritmos que **no comparan** elementos. En su lugar, usan el **valor** del elemento como índice directo en un array auxiliar.

```text
Array original:  [3, 1, 4, 1, 5, 9, 2, 6]

Counting Sort:
  contar cuántos 0s, 1s, 2s, 3s, 4s, 5s, 6s, 7s, 8s, 9s hay
  reconstruir el array por posición
```

### Ejemplos

| Algoritmo              | Restricción principal                  | Complejidad   |
| ---------------------- | -------------------------------------- | ------------- |
| **Counting Sort**      | Valores en rango pequeño `[0, k]`      | O(n + k)      |
| **Radix Sort**         | Dígitos/bytes; usa counting internamente| O(n·k)        |
| **Bucket Sort**        | Distribución uniforme de valores       | O(n + k) avg  |
| **Pigeonhole Sort**    | n elementos en n casillas              | O(n + k)      |

### ¿Por qué son más rápidos?

Porque **evitan las comparaciones**. En lugar de decidir entre dos elementos, **leen** directamente la posición donde va cada uno.

```text
Comparison sort:   "preguntar" → log₂(n!) decisiones
Index-based sort:  "ubicar"     → 1 cálculo por elemento
```

### Desventaja: restricciones

| Desventaja                                  | Consecuencia                                |
| ------------------------------------------- | ------------------------------------------- |
| Necesitan conocer el **rango** de valores   | Si k es muy grande, consumen mucha memoria  |
| Solo funcionan con tipos **discretos**       | No sirven para floats arbitrarios           |
| Requieren **memoria auxiliar** proporcional a k | Más espacio que los sorts in-place     |
| En la práctica, son **menos generales**     | No适用的 para todo tipo de datos            |

### Resumen de index-based sorts

| Algoritmo         | Mejor      | Promedio   | Peor        | Espacio   | Estable | Cuándo usarlo |
| ----------------- | ---------- | ---------- | ----------- | --------- | ------- | -------------- |
| **Counting Sort** | O(n + k)   | O(n + k)   | O(n + k)    | O(n + k)  | ✅      | Enteros pequeños, k = O(n) |
| **Radix Sort**    | O(n·k)     | O(n·k)     | O(n·k)      | O(n + k)  | ✅      | Enteros, strings, fijo dígitos |
| **Bucket Sort**   | O(n + k)   | O(n + k)   | O(n²)       | O(n + k)  | ✅      | Distribución uniforme |
| **Pigeonhole**    | O(n + k)   | O(n + k)   | O(n + k)    | O(n + k)  | ✅      | n elementos, k buckets |

## 11.4 Comparación directa

| Aspecto                  | Comparison-based            | Index-based               |
| ------------------------ | --------------------------- | ------------------------- |
| **Operación primitiva**  | Comparación `a < b`         | Cálculo de índice `a → i` |
| **Lower bound**          | Ω(n log n)                  | **O(n + k)**              |
| **Generalidad**          | ✅ Cualquier tipo ordenable  | ❌ Solo tipos discretos    |
| **Memoria extra**        | O(1) o O(n)                 | O(n + k)                  |
| **Estabilidad**          | Depende del algoritmo       | ✅ Casi siempre estable    |
| **Complejidad real**     | O(n log n) típico           | **O(n)** posible          |
| **Algoritmos típicos**   | Merge, Quick, Heap          | Counting, Radix, Bucket   |

## 11.5 ¿Cuándo usar cada familia?

| Situación                                       | Familia recomendada        |
| ----------------------------------------------- | -------------------------- |
| Datos genéricos, cualquier tipo comparable      | **Comparison-based**       |
| Enteros en rango pequeño, k = O(n)              | **Counting Sort**          |
| Enteros grandes o strings de longitud fija      | **Radix Sort**              |
| Distribución uniforme de valores reales          | **Bucket Sort**            |
| Memoria limitada, datos genéricos                | **Heap Sort** (in-place)   |
| Necesitas garantía de estabilidad                | **Merge Sort** o **Counting** |
| Velocidad pura con n = 10⁷ y datos discretos    | **Radix Sort**              |

## 11.6 Intuición: la barrera Ω(n log n)

```text
Comparison-based:
   Tienes una caja opaca con n números.
   Solo puedes hacer preguntas "¿a es menor que b?".
   Necesitas al menos n log n preguntas para ordenarlos.

Index-based:
   Tienes una caja con etiquetas del 0 al k.
   Puedes MIRAR la etiqueta y poner el número en su lugar exacto.
   Solo necesitas UNA pasada.
```

> **Romper la barrera Ω(n log n) requiere renunciar a la generalidad.** Esa es la regla de oro.

---

# 12. Divide and Conquer

## 10.1 Idea central

```text
Problema grande
      ↓
   DIVIDIR en subproblemas
      ↓
   RESOLVER recursivamente
      ↓
   COMBINAR las soluciones
```

## 10.2 Ejemplos clásicos

| Algoritmo          | Divide                | Combina              | Complejidad |
| ------------------ | --------------------- | -------------------- | ----------- |
| **Merge Sort**     | Mitad izquierda/derecha| Merge O(n)          | O(n log n)  |
| **Quick Sort**     | Por pivote             | Recursivo (sin merge)| O(n log n) avg |
| **Binary Search**  | Mitad del rango       | Elegir mitad         | O(log n)    |
| **Karatsuba**      | Mitades de dígitos    | Multiplicación       | O(n^1.585)  |
| **FFT**            | Polinomios pares/impares | Combinación        | O(n log n)  |

## 10.3 Estructura típica

```c
Resultado resolver(Problema p) {
    if (p.esTrivial())
        return Solución directa;

    subproblemas = dividir(p);

    s1 = resolver(subproblemas[0]);
    s2 = resolver(subproblemas[1]);
    // ...

    return combinar(s1, s2, ...);
}
```

---

# 13. Greedy (Voraz)

## 11.1 Idea central

En cada paso, tomar la **mejor opción local** esperando que lleve a la **mejor global**.

> **No siempre funciona**, pero cuando lo hace, es **muy eficiente**.

## 11.2 Estructura típica

```c
Resultado greedy(Problema p) {
    resultado = vacío;
    while (p.noTerminado()) {
        mejor = elegirMejorOpción(p.opciones());
        if (esVálido(mejor, resultado))
            resultado.agregar(mejor);
        p.eliminarOpción(mejor);
    }
    return resultado;
}
```

## 11.3 Ejemplos clásicos

| Problema                         | Estrategia Greedy                      |
| -------------------------------- | -------------------------------------- |
| Cambio de monedas (canónico)     | Tomar la moneda más grande posible     |
| Actividad select (intervalos)    | Ordenar por fin y elegir los que caben |
| Dijkstra (camino más corto)      | Elegir el nodo con menor distancia     |
| Kruskal (MST)                    | Tomar arista de menor peso             |
| Huffman coding                   | Combinar los dos árboles más pequeños  |

## 11.4 Cuándo funciona y cuándo no

```text
✅ Greedy funciona:
- Monedas: 1, 5, 10, 25  →  30 = 25 + 5
- Intervalos sin solapamiento
- MST (árbol de expansión mínima)

❌ Greedy falla:
- Monedas: 1, 3, 4  →  6 = 3+3 (óptimo) vs 4+1+1 (greedy)
- Mochila 0/1 (mejor DP)
```

> **Verificación clave:** ¿La decisión local óptima **siempre** produce la solución global óptima?

---

# 14. Programación Dinámica

## 12.1 Idea central

Resolver subproblemas **una sola vez** y **guardar el resultado** para reutilizarlo.

```text
Recursión:  resolver(n) llama a resolver(n-1) y resolver(n-2)  ← recalcula
DP:         resolver(n) usa los valores ya calculados          ← reutiliza
```

## 12.2 Las dos condiciones necesarias

| Condición                                  | Significado                              |
| ------------------------------------------ | ---------------------------------------- |
| **Subproblemas traslapados**               | El mismo subproblema aparece muchas veces|
| **Subestructura óptima**                   | La solución óptima usa soluciones óptimas de subproblemas |

## 12.3 Dos enfoques

| Enfoque        | Dirección          | Implementación              |
| -------------- | ------------------ | --------------------------- |
| **Top-Down**   | Grande → pequeño   | Recursión + memoización     |
| **Bottom-Up**  | Pequeño → grande   | Tabla iterativa (tabulation)|

## 12.4 Ejemplo clásico: Fibonacci

### Recursión naïve (lenta)

```c
int fib(int n) {
    if (n < 2) return n;
    return fib(n-1) + fib(n-2);     // O(2ⁿ) ← recalcula todo
}
```

### Top-Down con memoización

```c
int memo[1000];

int fibMemo(int n) {
    if (n < 2) return n;
    if (memo[n] != 0) return memo[n];
    return memo[n] = fibMemo(n-1) + fibMemo(n-2);
}
```

### Bottom-Up con tabulación

```c
int fibDP(int n) {
    if (n < 2) return n;
    int dp[n+1];
    dp[0] = 0; dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i-1] + dp[i-2];
    return dp[n];
}
```

| Versión       | Complejidad |
| ------------- | ----------- |
| Recursión naïve| O(2ⁿ)      |
| DP (memo o tab)| **O(n)**  |

## 12.5 Ejemplos clásicos de DP

| Problema                  | Estado                   | Transición                    |
| ------------------------- | ------------------------ | ----------------------------- |
| **Fibonacci**             | `dp[i]` = fib(i)         | `dp[i] = dp[i-1] + dp[i-2]`   |
| **Knapsack 0/1**          | `dp[i][w]` = mejor valor  | max(incluir, no incluir)      |
| **Coin Change**           | `dp[i]` = min monedas    | `dp[i] = min(dp[i-c]) + 1`    |
| **LCS** (subsecuencia)    | `dp[i][j]` = LCS         | si match: +1, si no: max     |
| **Edit Distance**         | `dp[i][j]` = costo       | min(insertar, borrar, reemplazar) |
| **Longest Increasing Subsequence** | `dp[i]` = LIS terminada en i | `dp[i] = max(dp[j]) + 1` |

---

# 15. Resumen de Complejidades

## 13.1 Tabla maestra

| Complejidad   | Nombre           | Algoritmo típico              | Sensación        |
| ------------- | ---------------- | ----------------------------- | ---------------- |
| `O(1)`        | Constante        | Array access, hash lookup     | Instantáneo      |
| `O(log n)`    | Logarítmico      | Binary search                 | Dividir y vencer |
| `O(n)`        | Lineal           | Linear search, suma           | Recorrer una vez |
| `O(n log n)`  | Cuasi-lineal     | Merge sort, quick sort        | El "sweet spot"  |
| `O(n²)`       | Cuadrático       | Bubble sort, selection sort   | Doble bucle      |
| `O(n³)`       | Cúbico           | Multiplicación naïve de matrices | Triple bucle  |
| `O(2ⁿ)`       | Exponencial      | Fibonacci naïve, subsets      | Solo n pequeño   |
| `O(n!)`       | Factorial        | Permutaciones, TSP naïve      | Solo n ≤ 12      |

## 13.2 Por estrategia

| Estrategia              | Complejidad típica   |
| ----------------------- | -------------------- |
| Brute force             | O(2ⁿ), O(n!)         |
| Divide and conquer      | O(n log n), O(log n) |
| Greedy                  | O(n log n)           |
| Programación dinámica   | O(n²), O(n·m)        |
| Backtracking            | Exponencial          |

---

# 16. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                          | Consecuencia                                |
| ---------------------------------------------- | ------------------------------------------- |
| Confundir Big-O del mejor caso con peor caso   | Subestimar el costo en producción           |
| Ignorar constantes ("n² no es siempre malo")   | Sobreestimar mejoras lineales               |
| Usar DP cuando greedy es suficiente            | Código innecesariamente complejo            |
| No considerar el espacio además del tiempo     | Solución "rápida" que consume toda la RAM   |
| Recursión sin caso base                        | Stack overflow                              |
| Aplicar binary search en array no ordenado     | Resultado incorrecto                        |
| Olvidar memoizar en DP top-down                | Pérdida total del beneficio de DP           |

### ✅ Buenas Prácticas

| Práctica                                            | Razón                                    |
| --------------------------------------------------- | ---------------------------------------- |
| Empezar con brute force, luego optimizar            | Garantiza correctitud primero            |
| Verificar la correctitud con casos pequeños         | Detectar bugs antes de optimizar        |
| Medir antes de optimizar (profiling)                | No adivinar dónde está el cuello de botella |
| Documentar la recurrencia o invariante             | Hacer el código mantenible               |
| Considerar el peor caso, no el promedio             | Producción ≠ laboratorio                |
| Elegir el algoritmo según el **tamaño real de n**   | O(n²) puede ser mejor que O(n log n) si n es pequeño |

---

# 17. Intuición de Ingeniería

> **El mejor algoritmo no es el más elegante, sino el que resuelve el problema con los recursos disponibles.**

### Heurísticas rápidas de decisión

| Si...                                        | Considera...                                |
| -------------------------------------------- | ------------------------------------------- |
| `n` ≤ 20 y necesitas optimalidad             | **Backtracking / fuerza bruta**             |
| `n` ≤ 10⁴ y necesitas optimalidad            | **O(n²) está bien**                         |
| `n` ≤ 10⁶ y necesitas optimalidad            | **O(n log n) es el techo**                  |
| Hay greedy válido                            | **Greedy (simple y rápido)**                |
| Subproblemas repetidos                       | **Programación Dinámica**                   |
| Dividir y combinar                           | **Divide and Conquer**                      |
| Solo importa una respuesta sí/no              | **Búsqueda binaria en el espacio**          |

### Principios universales

| Principio                              | Significado                                          |
| -------------------------------------- | ---------------------------------------------------- |
| **KISS**                               | Keep It Simple, Stupid — simple gana                |
| **Medir, no adivinar**                 | El profiling supera a la intuición                  |
| **Algoritmo + estructura**             | Un buen algoritmo en una mala estructura sigue siendo malo |
| **Complejidad importa**                | `O(n²)` con `n = 10⁷` no es viable                  |
| **Correctitud > rendimiento**          | Un programa rápido pero incorrecto es un bug grande  |

> **Si aprendes bien Big-O, el resto de la algoritmia se vuelve una pregunta de "¿cómo lo aplico aquí?".**
