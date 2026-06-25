# Dynamic Programming — Programación Dinámica

> **Idea central:** Resolver un problema **descomponiéndolo en subproblemas traslapados**,
> guardar la solución de cada subproblema en una tabla, y **reutilizar** esos resultados
> cuando vuelvan a aparecer.
>
> Es una de las tres grandes estrategias de diseño de algoritmos (junto con Divide & Conquer y Greedy).
> Aparece por primera vez de forma formal en el **Capítulo 15 del CLRS**.

---

## Tabla de Contenidos

1. [¿Qué es Programación Dinámica?](#1-qué-es-programación-dinámica)
2. [Las Dos Condiciones Esenciales](#2-las-dos-condiciones-esenciales)
3. [Top-Down vs Bottom-Up](#3-top-down-vs-bottom-up)
4. [Anatomía de un Algoritmo DP](#4-anatomía-de-un-algoritmo-dp)
5. [Problemas Clásicos Fundamentales](#5-problemas-clásicos-fundamentales)
6. [Problemas con Strings](#6-problemas-con-strings)
7. [Knapsack (Mochila)](#7-knapsack-mochila)
8. [Path & Grid Problems](#8-path--grid-problems)
9. [Subsequence / Subarray Problems](#9-subsequence--subarray-problems)
10. [DP en Cadenas y Palindromos](#10-dp-en-cadenas-y-palindromos)
11. [DP en Intervalos](#11-dp-en-intervalos)
12. [DP en Grafos y Árboles](#12-dp-en-grafos-y-árboles)
13. [Bitmask DP](#13-bitmask-dp)
14. [Patrones de DP](#14-patrones-de-dp)
15. [Optimización de DP](#15-optimización-de-dp)
16. [Errores Comunes y Buenas Prácticas](#16-errores-comunes-y-buenas-prácticas)
17. [Intuición de Ingeniería](#17-intuición-de-ingeniería)

---

# 1. ¿Qué es Programación Dinámica?

## 1.1 Definición

**Programación Dinámica (DP)** es una estrategia algorítmica que resuelve problemas **optimización o conteo** siguiendo dos ideas:

1. **Descomponer** el problema en **subproblemas más pequeños** del mismo tipo.
2. **Guardar** la solución de cada subproblema para no tener que recalcularla.

```text
┌──────────────────────────────────────────────────┐
│              CARACTERIZAR                        │
│  Definir la estructura de la solución óptima     │
│  en términos de subproblemas más pequeños.        │
└──────────────────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│              DEFINIR RECURRENCIA                 │
│  Expresar dp[i] en función de dp[j] con j < i.   │
└──────────────────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│              COMPUTAR                            │
│  Bottom-up (tabla) o top-down (memoización).     │
└──────────────────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│              RECONSTRUIR (opcional)               │
│  Guardar decisiones para recuperar la solución.   │
└──────────────────────────────────────────────────┘
```

> **CLRS (Cap. 15):** *"Dynamic programming, like the divide-and-conquer method, solves problems by combining the solutions to subproblems... Dynamic programming applies when the subproblems overlap."*

## 1.2 La palabra "dinámica" es engañosa

Richard Bellman eligió el nombre en los años 50 para **ocultar** que estaba haciendo investigación matemática. El nombre no tiene nada que ver con "programación" en el sentido de código ni con "dinámica" en el sentido físico. Es simplemente una **etiqueta bonita**.

```text
Lo que realmente es:
   "Resolver subproblemas una sola vez y guardar los resultados"
```

## 1.3 Analogía del mundo real

**Una calculadora con memoria:**

```text
Sin memoria:    calcular 7 × 8 = 56, después calcular 7 × 8 otra vez = 56   ← recalcula
Con memoria:    calcular 7 × 8 = 56, guardar; la próxima vez solo leer       ← reutiliza
```

**Investigar en una biblioteca:**

```text
Brute Force:    cada vez que necesitas un dato, vuelves a buscarlo en la biblioteca. O(n²) búsquedas.
DP:             anotas el dato en tu cuaderno; la próxima vez, lo lees del cuaderno. O(n) búsquedas.
```

**Llenar una tabla de impuestos:**

```text
Cada casilla depende de las anteriores ya rellenadas.
No "recalculas" el renglón 1 cada vez — solo miras la tabla.
```

## 1.4 DP vs otras estrategias

| Estrategia | Idea central | Cuándo gana |
| ---------- | ------------ | ----------- |
| **Brute Force** | Probar todas las opciones | n ≤ 20 |
| **Greedy** | Mejor elección local → óptima global | Greedy-choice property |
| **Divide & Conquer** | Dividir → resolver → combinar | Subproblemas independientes |
| **Programación Dinámica** | Resolver y **guardar** subproblemas | Subproblemas traslapados |
| **Backtracking** | Probar y deshacer | Espacio de búsqueda pequeño |

> **Regla de oro:** Si el algoritmo recursivo recalcula lo mismo muchas veces → necesitas DP.

## 1.5 Ejemplo preview: Fibonacci

```text
Fibonacci naïve:   fib(5) llama a fib(3) dos veces, fib(2) tres veces...   O(2ⁿ)
Fibonacci DP:      fib(5) consulta la tabla; cada fib(k) se calcula una vez O(n)
```

```text
Árbol de llamadas naïve (mismo nodo se calcula muchas veces):

                         fib(5)
                       /       \
                  fib(4)         fib(3)
                 /     \         /     \
            fib(3)   fib(2)   fib(2)   fib(1)
            /   \    /  \     /  \
       fib(2) fib(1) ...   ...   ...
        /  \
   fib(1) fib(0)

   fib(2) se llama 3 veces, fib(3) se llama 2 veces  ← RECALCULADO
```

```text
Con DP solo se calcula una vez:

dp[0] = 0
dp[1] = 1
dp[2] = dp[1] + dp[0] = 1
dp[3] = dp[2] + dp[1] = 2
dp[4] = dp[3] + dp[2] = 3
dp[5] = dp[4] + dp[3] = 5
                    ↑     ↑
                ya calculados, no se recalculan
```

> **Diferencia:** O(2ⁿ) → O(n). Para `n = 40` pasa de ~10¹² ops a 40 ops.

---

# 2. Las Dos Condiciones Esenciales

Para que un problema admita DP, **ambas** condiciones deben cumplirse:

| # | Condición | Significado |
| - | --------- | ----------- |
| 1 | **Subproblemas traslapados** | El mismo subproblema aparece muchas veces en la recursión |
| 2 | **Subestructura óptima** | La solución óptima se construye a partir de soluciones óptimas de subproblemas |

> **CLRS (Cap. 15.1):** *"We typically apply dynamic programming to optimization problems. Such problems can have many possible solutions. Each solution has a value, and we wish to find a solution with the optimal (minimum or maximum) value."*

## 2.1 Subproblemas traslapados (Overlapping Subproblems)

Un subproblema se repite cuando se necesita su solución **múltiples veces** en diferentes ramas de la recursión.

### Ejemplo: Fibonacci

```text
fib(5)
├─ fib(4)
│  ├─ fib(3)        ← fib(3) aquí
│  │  ├─ fib(2)
│  │  └─ fib(1)
│  └─ fib(2)
└─ fib(3)           ← ¡el MISMO fib(3) otra vez!
   ├─ fib(2)        ← fib(2) ya apareció 2 veces antes
   └─ fib(1)

Total de llamadas: 15
Llamadas únicas: 6
```

### Contraejemplo: Merge Sort

```text
mergeSort([1..n])
├─ mergeSort([1..n/2])      ← subproblema A
└─ mergeSort([n/2+1..n])    ← subproblema B (¡distinto!)

Merge Sort NO tiene solapamiento real: cada elemento aparece en UNA sola rama.
Por eso Merge Sort es Divide & Conquer puro, no DP.
```

> **Intuición:** Si dibujas el árbol de llamadas y los **mismos nodos se repiten**, hay solapamiento.

## 2.2 Subestructura óptima (Optimal Substructure)

Una solución óptima del problema se puede construir **combinando soluciones óptimas de subproblemas**.

### Ejemplo: Camino más corto

```text
Camino más corto de A a D:
   A → B → C → D

Si el camino óptimo A→D pasa por C, entonces el tramo A→C es óptimo.
(Si existiera un A→C más corto, lo usaríamos → contradicción.)
```

### Ejemplo: Subarray con suma máxima

```text
El subarray de suma máxima que TERMINA en i:
   maxEndingHere[i] = max(arr[i], maxEndingHere[i-1] + arr[i])

El subarray global óptimo es max sobre todos los maxEndingHere[i].
```

### Contraejemplo: Camino más largo

```text
Camino más largo de A a D en un grafo con ciclos:
   A → B → C → D (largo 3)
   A → B → C → B → C → D (largo 5)  ← pasa por C dos veces

Si "camino óptimo A→D pasa por C", entonces A→C NO necesariamente es óptimo,
porque podemos pasar por C varias veces para alargar el camino.
→ NO tiene subestructura óptima clásica.
```

> **Intuición:** Si puedes demostrar por contradicción que "lo óptimo contiene lo óptimo de los pedazos", tienes subestructura óptima.

## 2.3 Tabla resumen: las dos condiciones

| Problema | Traslapados | Subestructura óptima | ¿DP aplica? |
| -------- | ----------- | -------------------- | ----------- |
| **Fibonacci** | ✅ | ✅ | ✅ Sí |
| **Knapsack 0/1** | ✅ | ✅ | ✅ Sí |
| **LCS** | ✅ | ✅ | ✅ Sí |
| **Edit Distance** | ✅ | ✅ | ✅ Sí |
| **Merge Sort** | ❌ | ✅ | ❌ No (es D&C) |
| **Camino más corto en DAG** | ✅ | ✅ | ✅ Sí |
| **Camino más largo** | ⚠️ | ❌ (con ciclos) | ❌ No |
| **Cambio de monedas (greedy canónico)** | ❌ | ❌ | ❌ No (es greedy) |
| **Mochila fraccionaria** | ❌ | ❌ | ❌ No (es greedy) |

## 2.4 ¿Qué pasa si solo se cumple una?

| Cumple... | Estrategia apropiada |
| --------- | -------------------- |
| Solo subestructura óptima, sin solapamiento | **Divide & Conquer** |
| Solo solapamiento, sin subestructura óptima | Generalmente no hay algoritmo eficiente |
| Ambas | **Programación Dinámica** |
| Greedy-choice property (caso especial de ambas) | **Greedy** |

---

# 3. Top-Down vs Bottom-Up

Hay dos formas de implementar un algoritmo DP. Ambas son **O(n)** en el ejemplo de Fibonacci, pero tienen diferencias prácticas importantes.

| Aspecto | Top-Down (Memoización) | Bottom-Up (Tabulación) |
| ------- | ---------------------- | ---------------------- |
| **Dirección** | Grande → pequeño | Pequeño → grande |
| **Implementación** | Recursión + cache | Iteración + tabla |
| **Espacio típico** | Solo lo necesario | Toda la tabla |
| **Overhead** | Llamadas recursivas | Sin recursión |
| **Stack overflow** | ⚠️ Posible | ✅ No |
| **Cuándo usar** | Solo algunos subproblemas | Todos los subproblemas |

## 3.1 Top-Down con Memoización

```text
fibMemo(n):
   if memo[n] ya calculado: return memo[n]
   if n < 2: memo[n] = n
   else:     memo[n] = fibMemo(n-1) + fibMemo(n-2)
   return memo[n]
```

### Implementación en C

```c
#include <string.h>

long long memo[1000];

long long fibMemo(int n) {
    if (n < 2) return n;
    if (memo[n] != -1) return memo[n];
    return memo[n] = fibMemo(n - 1) + fibMemo(n - 2);
}

void initMemo() {
    memset(memo, -1, sizeof(memo));
}
```

### Implementación en Python

```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fib_memo(n):
    if n < 2:
        return n
    return fib_memo(n - 1) + fib_memo(n - 2)
```

> **Python tip:** `@lru_cache` es memoización automática. `maxsize=None` = cache ilimitada.

## 3.2 Bottom-Up con Tabulación

```text
fibDP(n):
   dp[0] = 0, dp[1] = 1
   for i desde 2 hasta n:
      dp[i] = dp[i-1] + dp[i-2]
   return dp[n]
```

### Implementación en C

```c
long long fibDP(int n) {
    if (n < 2) return n;
    long long dp[n + 1];
    dp[0] = 0;
    dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i - 1] + dp[i - 2];
    return dp[n];
}
```

### Implementación en Python

```python
def fib_tab(n):
    if n < 2:
        return n
    dp = [0] * (n + 1)
    dp[1] = 1
    for i in range(2, n + 1):
        dp[i] = dp[i - 1] + dp[i - 2]
    return dp[n]
```

## 3.3 Visualización de la tabla

Para `n = 6`:

```text
Paso 0:  dp = [0, _, _, _, _, _, _]
Paso 1:  dp = [0, 1, _, _, _, _, _]
Paso 2:  dp = [0, 1, 1, _, _, _, _]    ← 0+1
Paso 3:  dp = [0, 1, 1, 2, _, _, _]    ← 1+1
Paso 4:  dp = [0, 1, 1, 2, 3, _, _]    ← 1+2
Paso 5:  dp = [0, 1, 1, 2, 3, 5, _]    ← 2+3
Paso 6:  dp = [0, 1, 1, 2, 3, 5, 8]    ← 3+5

Resultado: fib(6) = 8
```

## 3.4 Comparación empírica

Para `n = 35`:

| Método | Tiempo (aprox.) | Observaciones |
| ------ | --------------- | ------------- |
| Recursión naïve | ~5 segundos | 29,860,703 llamadas |
| Top-Down memo | < 1 ms | 35 subproblemas resueltos |
| Bottom-Up | < 1 ms | 35 iteraciones |

> **Para `n = 50`:** recursión naïve tardaría ~30 minutos. DP sigue en microsegundos.

## 3.5 ¿Cuál elegir?

```text
✅ Top-Down cuando:
   - Solo necesitas ALGUNOS subproblemas (no todos)
   - La estructura de la recursión es más natural
   - Estás prototipando rápido

✅ Bottom-Up cuando:
   - Necesitas RECONSTRUIR la solución (no solo el valor)
   - Te importa el rendimiento (sin overhead de recursión)
   - El espacio es crítico (rolling array)

✅ En producción, casi siempre bottom-up.
```

---

# 4. Anatomía de un Algoritmo DP

Todo algoritmo DP tiene **cuatro componentes** bien definidos.

## 4.1 Los cuatro componentes

| # | Componente | Pregunta que responde |
| - | ---------- | --------------------- |
| 1 | **Estado** | ¿Qué representa cada celda de la tabla? |
| 2 | **Transición** | ¿Cómo se calcula dp[i] a partir de estados anteriores? |
| 3 | **Caso base** | ¿Qué valores conocemos directamente? |
| 4 | **Respuesta** | ¿Dónde está la solución en la tabla? |

## 4.2 Ejemplo: Climbing Stairs

> Estás en la base de una escalera de `n` escalones. En cada paso puedes subir 1 o 2 escalones. ¿De cuántas formas puedes llegar arriba?

### Estado

```text
dp[i] = número de formas de subir a la escalera considerando los primeros i escalones
```

### Caso base

```text
dp[0] = 1     ← una forma de estar en el suelo (no hacer nada)
dp[1] = 1     ← una forma de subir al primer escalón (un paso de 1)
```

### Transición

```text
Para llegar al escalón i, puedes venir de:
   - escalón i-1 (paso de 1)
   - escalón i-2 (paso de 2)

dp[i] = dp[i-1] + dp[i-2]
```

### Respuesta

```text
dp[n]   ← las formas de llegar al escalón n
```

### Implementación

```c
int climbStairs(int n) {
    if (n <= 1) return 1;
    int dp[n + 1];
    dp[0] = 1;
    dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i - 1] + dp[i - 2];
    return dp[n];
}
```

```python
def climb_stairs(n):
    if n <= 1:
        return 1
    dp = [0] * (n + 1)
    dp[0] = 1
    dp[1] = 1
    for i in range(2, n + 1):
        dp[i] = dp[i - 1] + dp[i - 2]
    return dp[n]
```

### Visualización

```text
n = 4

dp[0] = 1
dp[1] = 1
dp[2] = dp[1] + dp[0] = 2     (1+1, 2)
dp[3] = dp[2] + dp[1] = 3     (1+1+1, 1+2, 2+1)
dp[4] = dp[3] + dp[2] = 5     (1+1+1+1, 1+1+2, 1+2+1, 2+1+1, 2+2)

Formas para n=4:
  [1,1,1,1]
  [1,1,2]
  [1,2,1]
  [2,1,1]
  [2,2]
```

## 4.3 El truco mental: "definir bien el estado"

> **El 80% del trabajo en DP es definir bien el estado.**
> La transición casi siempre sale sola una vez que entiendes qué representa dp[i].

Preguntas útiles para definir el estado:

| Pregunta | Lo que te dice |
| -------- | -------------- |
| ¿Cuál es el "axis" del problema? | Dimensiones del estado (1D, 2D, 3D) |
| ¿Qué información necesito para tomar una decisión? | Variables extra en el estado |
| ¿Qué he "procesado" hasta ahora? | Índice principal |
| ¿Cuál es la decisión en cada paso? | Qué opciones tiene la transición |

## 4.4 Errores comunes al definir el estado

| Error | Consecuencia |
| ----- | ------------ |
| Estado demasiado pequeño | No se puede reconstruir la decisión |
| Estado demasiado grande | La tabla explota (memoria) |
| Confundir índice con valor | Off-by-one, transiciones rotas |
| Olvidar una dimensión | No se capturan todas las dependencias |

## 4.5 Tipos de estado por dimensionalidad

| Dimensiones | Ejemplos |
| ----------- | -------- |
| **1D** | Fibonacci, Climbing Stairs, House Robber, LIS, Coin Change |
| **2D** | Knapsack, LCS, Edit Distance, Unique Paths, Longest Common Substring |
| **3D** | DP con dos índices + máscara, Floyd-Warshall con intermediate node |
| **Bitmask** | TSP, asignación (n ≤ 20) |

---

# 5. Problemas Clásicos Fundamentales

Estos son los problemas "Hola Mundo" de DP. Si los entiendes, el resto es extensión.

## 5.1 Fibonacci (revisión completa)

### El problema

```text
F(0) = 0, F(1) = 1
F(n) = F(n-1) + F(n-2)
```

### Solución naïve (O(2ⁿ))

```c
long long fibNaive(int n) {
    if (n < 2) return n;
    return fibNaive(n - 1) + fibNaive(n - 2);
}
```

### DP (O(n))

```c
long long fibDP(int n) {
    if (n < 2) return n;
    long long dp[n + 1];
    dp[0] = 0;
    dp[1] = 1;
    for (int i = 2; i <= n; i++)
        dp[i] = dp[i - 1] + dp[i - 2];
    return dp[n];
}
```

### DP con espacio O(1)

```c
long long fibOpt(int n) {
    if (n < 2) return n;
    long long prev2 = 0, prev1 = 1, curr;
    for (int i = 2; i <= n; i++) {
        curr = prev1 + prev2;
        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;
}
```

### Complejidades

| Versión | Tiempo | Espacio |
| ------- | ------ | ------- |
| Recursión naïve | O(2ⁿ) | O(n) stack |
| Top-Down memo | O(n) | O(n) |
| Bottom-Up | O(n) | O(n) |
| Bottom-Up optimizado | O(n) | **O(1)** |

## 5.2 Climbing Stairs (ya visto)

```text
Resumen:
   Estado:    dp[i] = formas de llegar al escalón i
   Caso base: dp[0] = dp[1] = 1
   Transición: dp[i] = dp[i-1] + dp[i-2]
   Tiempo:    O(n)
   Espacio:   O(1) con rolling
```

### Variación: puedes subir 1, 2 o 3 escalones

```text
dp[i] = dp[i-1] + dp[i-2] + dp[i-3]
```

## 5.3 House Robber

### El problema

```text
Eres un ladrón que quiere robar la mayor cantidad de dinero de una fila de casas.
No puedes robar dos casas adyacentes (la alarma se activa).
Cada casa tiene una cantidad de dinero nums[i].

Entrada:  [1, 2, 3, 1]
Salida:   4         (robar casas 0 y 2: 1+3, o robar casas 1 y 3: 2+1)
```

### Solución naïve (recursión sin DP)

```text
rob(i) = max(rob(i-1), rob(i-2) + nums[i])
```

Llamadas: `rob(i) → rob(i-1) → rob(i-2) → ...` O(n) subproblemas, cada uno O(1) → **O(n)**.

Pero si la recurrencia fuera más compleja (ej: con 3 casas de separación), el análisis cambia.

### Estado

```text
dp[i] = máxima cantidad de dinero que puedes robar considerando las primeras i+1 casas
```

### Transición

```text
En la casa i, decides:
   - No robar: dp[i] = dp[i-1]
   - Robar:    dp[i] = dp[i-2] + nums[i]

dp[i] = max(dp[i-1], dp[i-2] + nums[i])
```

### Caso base

```text
dp[0] = nums[0]
dp[1] = max(nums[0], nums[1])
```

### Implementación

```c
int rob(int* nums, int n) {
    if (n == 0) return 0;
    if (n == 1) return nums[0];

    int dp[n];
    dp[0] = nums[0];
    dp[1] = (nums[0] > nums[1]) ? nums[0] : nums[1];

    for (int i = 2; i < n; i++) {
        int robar = dp[i - 2] + nums[i];
        int noRobar = dp[i - 1];
        dp[i] = (robar > noRobar) ? robar : noRobar;
    }
    return dp[n - 1];
}
```

```python
def rob(nums):
    if not nums:
        return 0
    if len(nums) == 1:
        return nums[0]

    dp = [0] * len(nums)
    dp[0] = nums[0]
    dp[1] = max(nums[0], nums[1])
    for i in range(2, len(nums)):
        dp[i] = max(dp[i - 1], dp[i - 2] + nums[i])
    return dp[-1]
```

### Visualización

```text
nums = [1, 2, 3, 1]

dp[0] = 1
dp[1] = max(1, 2) = 2
dp[2] = max(dp[1]=2, dp[0]+nums[2]=1+3=4) = 4
dp[3] = max(dp[2]=4, dp[1]+nums[3]=2+1=3) = 4

Resultado: 4
Decisión:   robar casas 0 y 2 → 1+3 = 4 ✓
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(n) |
| Espacio | O(n), optimizable a O(1) |

### Variaciones

| Variación | Cambio en recurrencia |
| --------- | ---------------------- |
| Casas en círculo | `max(rob(nums[0..n-2]), rob(nums[1..n-1]))` |
| Mínimo k casas entre robos | `dp[i] = max(dp[i-1], dp[i-k-1] + nums[i])` (requiere deque) |

## 5.4 Min Cost Climbing Stairs

### El problema

```text
Array de costos en cada escalón. Puedes subir 1 o 2 escalones.
Empiezas en el escalón 0 o en el 1 (sin costo inicial).
Encuentra el costo mínimo para llegar al final (más allá del último).

Entrada:  cost = [10, 15, 20]
Salida:   15   (empezar en 1, pagar 15, subir al final)
```

### Estado

```text
dp[i] = costo mínimo para llegar al escalón i
```

### Caso base

```text
dp[0] = cost[0]
dp[1] = cost[1]
```

### Transición

```text
dp[i] = cost[i] + min(dp[i-1], dp[i-2])
```

### Implementación

```c
int minCostClimbingStairs(int* cost, int n) {
    if (n <= 1) return 0;
    int dp[n];
    dp[0] = cost[0];
    dp[1] = cost[1];
    for (int i = 2; i < n; i++)
        dp[i] = cost[i] + (dp[i - 1] < dp[i - 2] ? dp[i - 1] : dp[i - 2]);
    return dp[n - 1] < dp[n - 2] ? dp[n - 1] : dp[n - 2];
}
```

### Visualización

```text
cost = [10, 15, 20]

dp[0] = 10
dp[1] = 15
dp[2] = 20 + min(dp[1]=15, dp[0]=10) = 20 + 10 = 30

Salida: min(dp[2]=30, dp[1]=15) = 15

Camino:  start → escalón 1 → fin    costo: 15 ✓
```

---

# 6. Problemas con Strings

Los problemas con strings son el corazón de DP: dos dimensiones, transiciones claras, aplicaciones prácticas infinitas.

## 6.1 Longest Common Subsequence (LCS)

### El problema

```text
Dadas dos strings X y Y, encontrar la longitud de la subsecuencia común más larga.
(Una subsecuencia NO necesita ser contigua — solo preservar el orden.)

X = "ABCBDAB"
Y = "BDCAB"

LCS = "BCAB" o "BDAB"   longitud 4
```

### Solución naïve: O(2^n · 2^m)

```text
Generar todas las subsecuencias de X (~2^n) y verificar en Y (~2^m) → O(2^(n+m)).
Imposible para n, m > 25.
```

### DP insight

```text
Si X[i] == Y[j]:
   LCS[i][j] = LCS[i-1][j-1] + 1
Si no:
   LCS[i][j] = max(LCS[i-1][j], LCS[i][j-1])
```

### Estado

```text
dp[i][j] = longitud de la LCS entre X[0..i-1] y Y[0..j-1]
```

### Caso base

```text
dp[0][*] = 0      ← string vacía vs cualquier cosa
dp[*][0] = 0      ← cualquier cosa vs string vacía
```

### Transición

```text
if X[i-1] == Y[j-1]:
   dp[i][j] = dp[i-1][j-1] + 1
else:
   dp[i][j] = max(dp[i-1][j], dp[i][j-1])
```

### Visualización paso a paso

```text
X = "ABCBDAB"     (m = 7)
Y = "BDCAB"       (n = 5)

       ""  B  D  C  A  B
   ""   0  0  0  0  0  0
   A    0  0  0  0  1  1
   B    0  1  1  1  1  2
   C    0  1  1  2  2  2
   B    0  1  1  2  2  3
   D    0  1  2  2  2  3
   A    0  1  2  2  3  3
   B    0  1  2  2  3  4

LCS = 4  ✓
```

### Implementación en C

```c
int lcs(char* X, char* Y) {
    int m = strlen(X);
    int n = strlen(Y);
    int dp[m + 1][n + 1];
    memset(dp, 0, sizeof(dp));

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (X[i - 1] == Y[j - 1])
                dp[i][j] = dp[i - 1][j - 1] + 1;
            else
                dp[i][j] = (dp[i - 1][j] > dp[i][j - 1])
                            ? dp[i - 1][j] : dp[i][j - 1];
        }
    }
    return dp[m][n];
}
```

### Implementación en Python

```python
def lcs(X, Y):
    m, n = len(X), len(Y)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if X[i - 1] == Y[j - 1]:
                dp[i][j] = dp[i - 1][j - 1] + 1
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
    return dp[m][n]
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(n·m) |
| Espacio | O(n·m), optimizable a O(min(n,m)) |

### Reconstrucción de la LCS

Para recuperar la cadena (no solo la longitud), guardamos decisiones:

```c
char* lcs_string(char* X, char* Y) {
    int m = strlen(X), n = strlen(Y);
    int dp[m + 1][n + 1];
    memset(dp, 0, sizeof(dp));

    for (int i = 1; i <= m; i++)
        for (int j = 1; j <= n; j++)
            if (X[i-1] == Y[j-1]) dp[i][j] = dp[i-1][j-1] + 1;
            else dp[i][j] = (dp[i-1][j] > dp[i][j-1]) ? dp[i-1][j] : dp[i][j-1];

    int i = m, j = n, idx = dp[m][n];
    char lcs[idx + 1];
    lcs[idx] = '\0';
    while (i > 0 && j > 0) {
        if (X[i-1] == Y[j-1]) {
            lcs[--idx] = X[i-1];
            i--; j--;
        } else if (dp[i-1][j] > dp[i][j-1]) i--;
        else j--;
    }
    return strdup(lcs);
}
```

## 6.2 Edit Distance (Levenshtein Distance)

### El problema

```text
Distancia mínima para transformar X en Y con operaciones:
   - Insertar un carácter (costo 1)
   - Borrar un carácter  (costo 1)
   - Reemplazar un carácter (costo 1)

X = "KITTEN"
Y = "SITTING"

Distancia = 3:
   1. Reemplazar K → S
   2. Reemplazar E → I
   3. Insertar G al final
```

### Aplicaciones reales

| Aplicación | Uso |
| ---------- | --- |
| **Spell checkers** | ¿Qué tan cerca está "teh" de una palabra válida? |
| **Bioinformática** | Alineamiento de secuencias de ADN/proteínas |
| **Diff tools** (git diff) | ¿Cuántas líneas cambiar? |
| **Autocorrector** | Sugerir palabras similares |
| **Plagiarism detection** | Medir similitud entre textos |

### Estado

```text
dp[i][j] = distancia mínima para transformar X[0..i-1] en Y[0..j-1]
```

### Caso base

```text
dp[i][0] = i        ← borrar i caracteres
dp[0][j] = j        ← insertar j caracteres
```

### Transición

```text
Si X[i-1] == Y[j-1]:
   dp[i][j] = dp[i-1][j-1]                       (match, no operacion)

Si X[i-1] != Y[j-1]:
   dp[i][j] = 1 + min(
       dp[i-1][j],      ← borrar X[i-1]
       dp[i][j-1],      ← insertar Y[j-1]
       dp[i-1][j-1]     ← reemplazar X[i-1] por Y[j-1]
   )
```

### Visualización

```text
X = "KITTEN"     (m = 6)
Y = "SITTING"    (n = 7)

       ""  S  I  T  T  I  N  G
   ""   0  1  2  3  4  5  6  7
   K    1  1  2  3  4  5  6  7
   I    2  2  1  2  3  4  5  6
   T    3  3  2  1  2  3  4  5
   T    4  4  3  2  1  2  3  4
   E    5  5  4  3  2  2  3  4
   N    6  6  5  4  3  3  2  3

Distancia = 3  ✓
```

### Implementación en C

```c
int min3(int a, int b, int c) {
    if (a > b) a = b;
    if (a > c) a = c;
    return a;
}

int editDistance(char* X, char* Y) {
    int m = strlen(X);
    int n = strlen(Y);
    int dp[m + 1][n + 1];

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (X[i-1] == Y[j-1])
                dp[i][j] = dp[i-1][j-1];
            else
                dp[i][j] = 1 + min3(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
        }
    }
    return dp[m][n];
}
```

### Implementación en Python

```python
def edit_distance(X, Y):
    m, n = len(X), len(Y)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if X[i - 1] == Y[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(
                    dp[i - 1][j],      # delete
                    dp[i][j - 1],      # insert
                    dp[i - 1][j - 1]   # replace
                )
    return dp[m][n]
```

### Variaciones

| Variación | Cambio | Costo insert/delete | Costo replace |
| --------- | ------ | ------------------- | ------------- |
| **Levenshtein** | Estándar | 1 | 1 |
| **Damerau-Levenshtein** | + transposición | 1 | 1 |
| **Hamming** | Solo reemplazo | no permitido | 1 |
| **Longest Common Substring** | Solo matches contiguos | — | — |

## 6.3 Longest Palindromic Subsequence (LPS)

### El problema

```text
Encontrar la subsecuencia palindrómica más larga de un string.

s = "BBABCBCAB"
LPS = "BABCBAB"   longitud 7
```

### Idea brillante: LPS(s) = LCS(s, reverse(s))

```text
s        = "BBABCBCAB"
reverse  = "BACBCBAB"

LCS = 7  ✓
```

### Por qué funciona

```text
Una subsecuencia palindrómica es la misma leída al revés.
Equivale a una subsecuencia común entre s y reverse(s).
```

### Implementación

```python
def lps(s):
    return lcs(s, s[::-1])
```

## 6.4 Distinct Subsequences

### El problema

```text
Contar el número de subsecuencias de s que son iguales a t.

s = "rabbbit"
t = "rabbit"

Salida: 3
   rabbbit
   ^^ ^ ^^     (posiciones 0, 4, 5, 7, 8 → "rabbit" via 3 formas)
```

### Estado

```text
dp[i][j] = número de subsecuencias de s[0..i-1] que son iguales a t[0..j-1]
```

### Caso base

```text
dp[i][0] = 1       ← una forma de obtener "" (borrar todo)
dp[0][j] = 0 (j>0) ← no se puede obtener t no vacío de s vacío
```

### Transición

```text
Si s[i-1] == t[j-1]:
   dp[i][j] = dp[i-1][j-1] + dp[i-1][j]    (usar s[i-1] o no)
Si no:
   dp[i][j] = dp[i-1][j]                    (no usar s[i-1])
```

### Implementación

```c
int numDistinct(char* s, char* t) {
    int m = strlen(s), n = strlen(t);
    long long dp[m + 1][n + 1];

    for (int i = 0; i <= m; i++) dp[i][0] = 1;
    for (int j = 1; j <= n; j++) dp[0][j] = 0;

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (s[i-1] == t[j-1])
                dp[i][j] = dp[i-1][j-1] + dp[i-1][j];
            else
                dp[i][j] = dp[i-1][j];
        }
    }
    return dp[m][n];
}
```

---

# 7. Knapsack (Mochila)

La familia de problemas de la **mochila** es probablemente el ejemplo más importante de DP. Aparece en logística, finanzas, bioinformática y optimización de recursos.

## 7.1 0/1 Knapsack (Mochila 0/1)

### El problema

```text
Tienes n objetos, cada uno con:
   - peso w[i]
   - valor v[i]
Y una mochila con capacidad W.

Cada objeto se puede tomar UNA vez (0 o 1).
Maximiza el valor total sin exceder la capacidad.

Ejemplo:
   objetos:   {(peso=2, valor=3), (peso=3, valor=4), (peso=4, valor=5)}
   W = 5
   óptimo:    tomar objetos 1 y 2 → valor 3+4 = 7, peso 5
```

### Solución naïve: O(2ⁿ)

```text
Para cada objeto, decides tomarlo o no → 2^n subconjuntos.
```

### DP insight

```text
Si NO tomas el objeto i: dp[i][w] = dp[i-1][w]
Si SÍ tomas el objeto i: dp[i][w] = dp[i-1][w-w[i]] + v[i]
```

### Estado

```text
dp[i][w] = máximo valor usando los primeros i objetos con peso total ≤ w
```

### Caso base

```text
dp[0][w] = 0      ← sin objetos, valor 0
dp[i][0] = 0      ← sin capacidad, valor 0
```

### Transición

```text
if w >= w[i]:
   dp[i][w] = max(dp[i-1][w], dp[i-1][w - w[i]] + v[i])
else:
   dp[i][w] = dp[i-1][w]
```

### Visualización

```text
Objetos:  (w=2, v=3), (w=3, v=4), (w=4, v=5)
W = 5

         w=0   w=1   w=2   w=3   w=4   w=5
   i=0    0     0     0     0     0     0
   i=1    0     0     3     3     3     3      ← {obj 1} valor 3
   i=2    0     0     3     4     4     7      ← {obj 2} o {obj 1+2}
   i=3    0     0     3     4     5     7      ← {obj 3}

dp[3][5] = 7  ✓
```

### Implementación en C

```c
int knapsack(int W, int weights[], int values[], int n) {
    int dp[n + 1][W + 1];
    for (int i = 0; i <= n; i++)
        for (int w = 0; w <= W; w++)
            dp[i][w] = 0;

    for (int i = 1; i <= n; i++) {
        for (int w = 1; w <= W; w++) {
            if (weights[i-1] <= w) {
                int con = dp[i-1][w - weights[i-1]] + values[i-1];
                int sin = dp[i-1][w];
                dp[i][w] = (con > sin) ? con : sin;
            } else {
                dp[i][w] = dp[i-1][w];
            }
        }
    }
    return dp[n][W];
}
```

### Implementación en Python

```python
def knapsack(W, weights, values, n):
    dp = [[0] * (W + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        for w in range(1, W + 1):
            if weights[i - 1] <= w:
                dp[i][w] = max(
                    dp[i - 1][w],
                    dp[i - 1][w - weights[i - 1]] + values[i - 1]
                )
            else:
                dp[i][w] = dp[i - 1][w]
    return dp[n][W]
```

### Optimización: espacio O(W)

```python
def knapsack_optimized(W, weights, values, n):
    dp = [0] * (W + 1)
    for i in range(n):
        for w in range(W, weights[i] - 1, -1):   # iterar HACIA ATRÁS
            dp[w] = max(dp[w], dp[w - weights[i]] + values[i])
    return dp[W]
```

> **¿Por qué iterar hacia atrás?** Para que `dp[w - weights[i]]` aún contenga el valor del **objeto anterior** (iteración `i-1`), no del objeto actual.

### Complejidad

| Métrica | Tabla 2D | Tabla 1D |
| ------- | -------- | -------- |
| Tiempo | O(n·W) | O(n·W) |
| Espacio | O(n·W) | **O(W)** |

## 7.2 Subset Sum

### El problema

```text
Dados n números y un target T, ¿existe un subconjunto que sume exactamente T?

nums = [3, 34, 4, 12, 5, 2]
T = 9

Sí: {4, 5} o {3, 4, 2}  → 9
```

### Es un caso especial de Knapsack

```text
Cada número tiene peso = valor = nums[i].
¿Quieres dp[n][T] == T?
```

### Estado

```text
dp[i][s] = ¿es posible sumar s usando los primeros i números?
```

### Transición

```text
dp[i][s] = dp[i-1][s] OR dp[i-1][s - nums[i]]
```

### Implementación

```python
def subset_sum(nums, T):
    n = len(nums)
    dp = [[False] * (T + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = True

    for i in range(1, n + 1):
        for s in range(1, T + 1):
            dp[i][s] = dp[i-1][s]
            if s >= nums[i-1]:
                dp[i][s] = dp[i][s] or dp[i-1][s - nums[i-1]]
    return dp[n][T]
```

## 7.3 Unbounded Knapsack

### El problema

```text
Igual que 0/1, pero puedes tomar cada objeto **ilimitadas veces**.

weights = [2, 3]
values  = [3, 4]
W = 7

0/1:        {2,3,2} → valor 3+4+3 = 10
Unbounded:  {2,2,3} repetido infinitas veces → valor 9, 12, 15...
            {3,2,2} → 3+3+3 = 9, ...
            Mejor: {2,2,3} → 10  (pero podemos repetir)
```

### Cambio clave en la transición

```text
0/1:        dp[i][w] = max(dp[i-1][w], dp[i-1][w - w[i]] + v[i])
Unbounded:  dp[i][w] = max(dp[i-1][w], dp[i][w - w[i]] + v[i])
                                     ↑
                              MISMO i (puedes reusar el objeto)
```

### Implementación

```python
def unbounded_knapsack(W, weights, values, n):
    dp = [0] * (W + 1)
    for w in range(1, W + 1):
        for i in range(n):
            if weights[i] <= w:
                dp[w] = max(dp[w], dp[w - weights[i]] + values[i])
    return dp[W]
```

## 7.4 Coin Change (Número mínimo de monedas)

### El problema

```text
Dadas monedas de denominaciones [1, 5, 10, 25] y un monto amount,
encuentra el número MÍNIMO de monedas para sumar exactamente amount.

amount = 41
óptimo: 25 + 10 + 5 + 1 = 4 monedas
```

### Estado

```text
dp[i] = número mínimo de monedas para sumar el monto i
```

### Caso base

```text
dp[0] = 0      ← 0 monedas para sumar 0
```

### Transición

```text
dp[i] = min(dp[i - coin]) + 1   para cada coin ≤ i
```

### Implementación en C

```c
int coinChange(int* coins, int n, int amount) {
    int dp[amount + 1];
    for (int i = 0; i <= amount; i++) dp[i] = amount + 1;
    dp[0] = 0;

    for (int i = 1; i <= amount; i++) {
        for (int j = 0; j < n; j++) {
            if (coins[j] <= i && dp[i - coins[j]] + 1 < dp[i])
                dp[i] = dp[i - coins[j]] + 1;
        }
    }
    return dp[amount] > amount ? -1 : dp[amount];
}
```

### Implementación en Python

```python
def coin_change(coins, amount):
    dp = [float('inf')] * (amount + 1)
    dp[0] = 0
    for i in range(1, amount + 1):
        for coin in coins:
            if coin <= i and dp[i - coin] + 1 < dp[i]:
                dp[i] = dp[i - coin] + 1
    return dp[amount] if dp[amount] != float('inf') else -1
```

### Visualización

```text
coins = [1, 5, 10, 25]
amount = 41

dp[0] = 0
dp[1] = 1     (1)
dp[2] = 2     (1+1)
dp[3] = 3     (1+1+1)
dp[4] = 4     (1+1+1+1)
dp[5] = 1     (5) ✓ baja
dp[10] = 1    (10)
dp[25] = 1    (25)
dp[26] = 2    (25+1)
dp[35] = 2    (25+10)
dp[40] = 2    (25+10+5) → dp[40-5]+1=3, dp[40-10]+1=2, dp[40-25]+1=2, dp[40-1]+1=40 → min=2
dp[41] = 3    (25+10+5+1)
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(amount · n) |
| Espacio | O(amount) |

## 7.5 Coin Change II (Número de formas)

### El problema

```text
Mismo problema, pero contar el NÚMERO DE FORMAS (no el mínimo).

amount = 5, coins = [1, 2, 5]
Formas: 5
   1+1+1+1+1
   1+1+1+2
   1+2+2
   5
   1+1+1+1+1 (cuenta una sola vez, no importa el orden)
```

### Diferencia clave en la transición

```text
Mínimo:  dp[i] = min(dp[i - coin]) + 1
Conteo:  dp[i] = sum(dp[i - coin])
```

### Implementación

```python
def coin_change_ways(coins, amount):
    dp = [0] * (amount + 1)
    dp[0] = 1
    for coin in coins:                  # iterar monedas primero
        for i in range(coin, amount + 1):
            dp[i] += dp[i - coin]
    return dp[amount]
```

> **⚠️ Importante:** Iterar **monedas primero** evita contar permutaciones (1+2 vs 2+1).

## 7.6 Comparación de las variantes

| Variante | Estado | Transición | Tiempo |
| -------- | ------ | ---------- | ------ |
| **0/1 Knapsack** | `dp[i][w]` | max(incluir, no incluir) | O(n·W) |
| **Unbounded Knapsack** | `dp[w]` | max(dp[w], dp[w - w[i]] + v[i]) | O(n·W) |
| **Subset Sum** | `dp[i][s]` | OR lógico | O(n·T) |
| **Coin Change (min)** | `dp[i]` | min + 1 | O(amount·n) |
| **Coin Change (count)** | `dp[i]` | suma | O(amount·n) |

---

# 8. Path & Grid Problems

Problemas donde dp[i][j] representa una celda en una rejilla.

## 8.1 Unique Paths

### El problema

```text
Robot en la esquina superior-izquierda de una rejilla m×n.
Solo puede moverse DERECHA o ABAJO.
¿Cuántos caminos únicos hasta la esquina inferior-derecha?

3 × 7 grid → 28 caminos
```

### Solución matemática directa

```text
C(m+n-2, m-1) = (m+n-2)! / ((m-1)! · (n-1)!)
```

### DP insight

```text
Solo puedes llegar a (i,j) desde (i-1, j) o (i, j-1).
dp[i][j] = dp[i-1][j] + dp[i][j-1]
```

### Estado

```text
dp[i][j] = número de caminos únicos para llegar a la celda (i, j)
```

### Caso base

```text
dp[0][*] = 1, dp[*][0] = 1   ← primera fila y primera columna
```

### Visualización

```text
Grid 3×3:

   1  1  1
   1  2  3
   1  3  6

dp[2][2] = 6 caminos  ✓
```

### Implementación

```c
int uniquePaths(int m, int n) {
    int dp[m][n];
    for (int i = 0; i < m; i++) dp[i][0] = 1;
    for (int j = 0; j < n; j++) dp[0][j] = 1;

    for (int i = 1; i < m; i++)
        for (int j = 1; j < n; j++)
            dp[i][j] = dp[i-1][j] + dp[i][j-1];

    return dp[m-1][n-1];
}
```

```python
def unique_paths(m, n):
    dp = [[1] * n for _ in range(m)]
    for i in range(1, m):
        for j in range(1, n):
            dp[i][j] = dp[i-1][j] + dp[i][j-1]
    return dp[m-1][n-1]
```

### Optimización: espacio O(n)

```python
def unique_paths_opt(m, n):
    dp = [1] * n
    for i in range(1, m):
        for j in range(1, n):
            dp[j] += dp[j-1]
    return dp[n-1]
```

## 8.2 Minimum Path Sum

### El problema

```text
Rejilla con costos en cada celda. Solo derecha/abajo.
Encuentra el camino de suma mínima de (0,0) a (m-1, n-1).

grid =
  1 3 1
  1 5 1
  4 2 1

Camino óptimo: 1 → 3 → 1 → 1 → 1 = 7  (derecha, abajo, derecha, abajo)
```

### Transición

```text
dp[i][j] = grid[i][j] + min(dp[i-1][j], dp[i][j-1])
```

### Visualización

```text
   1   3   1       dp:
   1   5   1       1  4  5
   4   2   1       2  7  6
                   6  8  7

dp[2][2] = 7  ✓
```

### Implementación

```python
def min_path_sum(grid):
    m, n = len(grid), len(grid[0])
    dp = [[0] * n for _ in range(m)]
    dp[0][0] = grid[0][0]

    for j in range(1, n):
        dp[0][j] = dp[0][j-1] + grid[0][j]
    for i in range(1, m):
        dp[i][0] = dp[i-1][0] + grid[i][0]

    for i in range(1, m):
        for j in range(1, n):
            dp[i][j] = grid[i][j] + min(dp[i-1][j], dp[i][j-1])

    return dp[m-1][n-1]
```

## 8.3 Longest Increasing Path in a Matrix

### El problema

```text
Dada una matriz, encontrar la longitud del camino estrictamente creciente más largo.
Puedes mover en 4 direcciones (arriba, abajo, izquierda, derecha).

mat =
  9 9 4
  6 6 8
  2 1 1

Camino: 1 → 2 → 6 → 9 (longitud 4)
```

### Estado

```text
dp[i][j] = longitud del camino creciente más largo EMPEZANDO en (i, j)
```

### Transición

```text
dp[i][j] = 1 + max(dp[nx][ny]) para cada vecino (nx, ny) con grid[nx][ny] > grid[i][j]
Si no hay vecinos mayores: dp[i][j] = 1
```

### Top-Down con memoización

```python
def longest_increasing_path(matrix):
    if not matrix:
        return 0
    m, n = len(matrix), len(matrix[0])
    memo = {}

    def dfs(i, j):
        if (i, j) in memo:
            return memo[(i, j)]
        best = 1
        for di, dj in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            ni, nj = i + di, j + dj
            if 0 <= ni < m and 0 <= nj < n and matrix[ni][nj] > matrix[i][j]:
                best = max(best, 1 + dfs(ni, nj))
        memo[(i, j)] = best
        return best

    return max(dfs(i, j) for i in range(m) for j in range(n))
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(m·n) |
| Espacio | O(m·n) memo + O(m·n) stack |

## 8.4 Dungeon Game (el problema inverso)

### El problema

```text
El caballero entra al dungeon en (0,0) con cierta salud.
Debe llegar a la esquina inferior-derecha con salud > 0.
Celda con valor positivo = cura, negativo = daño.
Encuentra la salud inicial MÍNIMA necesaria.

dungeon =
  -2  -3   3
  -5  -10  1
  10  30  -5

Salud mínima inicial = 7
```

### Por qué es "inverso"

```text
Problemas normales: dp[i][j] = mejor resultado AL LLEGAR.
Dungeon:          dp[i][j] = salud mínima REQUERIDA al llegar a esta celda desde el final.
```

### Estado

```text
dp[i][j] = salud mínima necesaria al estar en la celda (i, j) para sobrevivir el resto
```

### Caso base

```text
dp[m-1][n-1] = max(1, 1 - dungeon[m-1][n-1])
```

### Transición (de derecha-abajo hacia izquierda-arriba)

```text
dp[i][j] = max(1, min(dp[i+1][j], dp[i][j+1]) - dungeon[i][j])
```

### Implementación

```python
def calculate_minimum_hp(dungeon):
    m, n = len(dungeon), len(dungeon[0])
    dp = [[0] * n for _ in range(m)]
    dp[m-1][n-1] = max(1, 1 - dungeon[m-1][n-1])

    for j in range(n-2, -1, -1):
        dp[m-1][j] = max(1, dp[m-1][j+1] - dungeon[m-1][j])
    for i in range(m-2, -1, -1):
        dp[i][n-1] = max(1, dp[i+1][n-1] - dungeon[i][n-1])

    for i in range(m-2, -1, -1):
        for j in range(n-2, -1, -1):
            dp[i][j] = max(1, min(dp[i+1][j], dp[i][j+1]) - dungeon[i][j])

    return dp[0][0]
```

---

# 9. Subsequence / Subarray Problems

## 9.1 Longest Increasing Subsequence (LIS)

### El problema

```text
Encontrar la longitud de la subsecuencia estrictamente creciente más larga.

nums = [10, 9, 2, 5, 3, 7, 101, 18]
LIS  = [2, 3, 7, 18] o [2, 3, 7, 101]   longitud 4
```

### Solución DP estándar: O(n²)

#### Estado

```text
dp[i] = longitud de la LIS que TERMINA en nums[i]
```

#### Transición

```text
dp[i] = 1 + max(dp[j])  para todo j < i con nums[j] < nums[i]
Si no hay: dp[i] = 1
```

#### Implementación

```python
def lis_length(nums):
    n = len(nums)
    dp = [1] * n
    for i in range(1, n):
        for j in range(i):
            if nums[j] < nums[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)
```

#### Visualización

```text
nums = [10, 9, 2, 5, 3, 7, 101, 18]

i=0: dp[0] = 1               (10)
i=1: nums[0]=10 ≥ 9          dp[1] = 1  (9)
i=2: nums[0,1] ≥ 2           dp[2] = 1  (2)
i=3: nums[2]=2 < 5           dp[3] = 2  (2, 5)
i=4: nums[2]=2 < 3           dp[4] = 2  (2, 3)
i=5: nums[2,3,4] < 7         dp[5] = 3  (2, 5, 7) o (2, 3, 7)
i=6: nums[2,3,4,5] < 101     dp[6] = 4  (2, 5, 7, 101)
i=7: nums[2,3,4,5] < 18      dp[7] = 4  (2, 5, 7, 18)

max = 4  ✓
```

### Solución optimizada O(n log n) con Binary Search

```text
Mantener un array "tails" donde tails[k] = menor cola de una subsecuencia creciente de longitud k+1.
Para cada num, hacer binary search en tails.
```

```python
import bisect

def lis_fast(nums):
    tails = []
    for num in nums:
        idx = bisect.bisect_left(tails, num)
        if idx == len(tails):
            tails.append(num)
        else:
            tails[idx] = num
    return len(tails)
```

#### Visualización

```text
nums = [10, 9, 2, 5, 3, 7, 101, 18]

num=10:    tails=[10]
num=9:     reemplaza 10 → tails=[9]
num=2:     reemplaza 9  → tails=[2]
num=5:     append        tails=[2, 5]
num=3:     reemplaza 5  → tails=[2, 3]
num=7:     append        tails=[2, 3, 7]
num=101:   append        tails=[2, 3, 7, 101]
num=18:    reemplaza 101 → tails=[2, 3, 7, 18]

Resultado: len(tails) = 4  ✓
```

### Complejidad

| Versión | Tiempo | Espacio |
| ------- | ------ | ------- |
| DP O(n²) | O(n²) | O(n) |
| Binary Search | **O(n log n)** | O(n) |

## 9.2 Maximum Subarray (Kadane)

### El problema

```text
Encontrar el subarray CONTIGUO con la suma máxima.

nums = [-2, 1, -3, 4, -1, 2, 1, -5, 4]
Mejor subarray: [4, -1, 2, 1]   suma = 6
```

### Algoritmo de Kadane: O(n)

```text
maxEndingHere[i] = max(nums[i], maxEndingHere[i-1] + nums[i])
maxGlobal = max de todos los maxEndingHere
```

### Estado

```text
dp[i] = máxima suma de un subarray que TERMINA en i
```

### Transición

```text
dp[i] = max(nums[i], dp[i-1] + nums[i])
```

### Implementación

```c
int maxSubarray(int* nums, int n) {
    int maxEndingHere = nums[0];
    int maxGlobal = nums[0];

    for (int i = 1; i < n; i++) {
        maxEndingHere = (nums[i] > maxEndingHere + nums[i])
                        ? nums[i] : maxEndingHere + nums[i];
        if (maxEndingHere > maxGlobal)
            maxGlobal = maxEndingHere;
    }
    return maxGlobal;
}
```

```python
def max_subarray(nums):
    max_ending = max_global = nums[0]
    for num in nums[1:]:
        max_ending = max(num, max_ending + num)
        max_global = max(max_global, max_ending)
    return max_global
```

### Visualización

```text
nums = [-2, 1, -3, 4, -1, 2, 1, -5, 4]

i=0: maxEnd=-2  maxGlob=-2
i=1: maxEnd=max(1, -2+1)=1   maxGlob=1
i=2: maxEnd=max(-3, 1-3)=-2  maxGlob=1
i=3: maxEnd=max(4, -2+4)=4   maxGlob=4
i=4: maxEnd=max(-1, 4-1)=3   maxGlob=4
i=5: maxEnd=max(2, 3+2)=5    maxGlob=5
i=6: maxEnd=max(1, 5+1)=6    maxGlob=6  ← máximo
i=7: maxEnd=max(-5, 6-5)=1   maxGlob=6
i=8: maxEnd=max(4, 1+4)=5    maxGlob=6

Resultado: 6  ✓ (subarray [4, -1, 2, 1])
```

### Variaciones

| Variación | Cambio |
| --------- | ------ |
| **Producto máximo** | `maxEnding[i] = max(nums[i], maxEnding[i-1]*nums[i], minEnding[i-1]*nums[i])` |
| **Suma con un reset** | Permitir descartar todo el subarray una vez |
| **Suma circular** | `max(maxKadane, total - minSubarray)` |

## 9.3 Product of Array Except Self

### El problema

```text
Dado un array, retornar un array donde output[i] = producto de todos los elementos excepto nums[i].
Sin usar división.

nums = [1, 2, 3, 4]
output = [24, 12, 8, 6]
```

### Idea DP

```text
output[i] = (producto de nums[0..i-1]) * (producto de nums[i+1..n-1])
```

### Implementación O(n) sin espacio extra (excepto output)

```python
def product_except_self(nums):
    n = len(nums)
    output = [1] * n

    left = 1
    for i in range(n):
        output[i] = left
        left *= nums[i]

    right = 1
    for i in range(n-1, -1, -1):
        output[i] *= right
        right *= nums[i]

    return output
```

### Visualización

```text
nums = [1, 2, 3, 4]

Pasada 1 (prefijos):
   output = [1, 1, 2, 6]
             ↑  ↑  ↑  ↑
             1  1  1·2 1·2·3

Pasada 2 (sufijos):
   right=4: output[3] = 6 · 4 = 24
   right=12: output[2] = 2 · 12 = 8  → wait, recorremos al revés

Reescribir:
   i=3: right=4,  output[3] = 1 · 4  = 4,  right = 4·4  = 16
   i=2: right=16, output[2] = 2 · 16 = 32, ... 

Mejor con el código:
   i=0: left=1,  output[0]=1,  left = 1·1 = 1
   i=1: left=1,  output[1]=1,  left = 1·2 = 2
   i=2: left=2,  output[2]=2,  left = 2·3 = 6
   i=3: left=6,  output[3]=6,  left = 6·4 = 24

   i=3: right=1, output[3]=6·1=6,   right = 1·4 = 4
   i=2: right=4, output[2]=2·4=8,   right = 4·3 = 12
   i=1: right=12,output[1]=1·12=12, right = 12·2 = 24
   i=0: right=24,output[0]=1·24=24, right = 24·1 = 24

Final: [24, 12, 8, 6]  ✓
```

---

# 10. DP en Cadenas y Palindromos

## 10.1 Longest Palindromic Substring

### El problema

```text
Encontrar el substring palindrómico más largo.

s = "babad"
Longest: "bab" o "aba"   longitud 3
```

### Aproximación DP: expandir alrededor del centro

```text
Cada palíndromo tiene un centro.
Para cada centro, expandir hacia los lados mientras s[i] == s[j].
```

### Estado

```text
dp[i][j] = ¿es s[i..j] un palíndromo?
```

### Transición

```text
dp[i][j] = (s[i] == s[j]) AND (j-i < 2 OR dp[i+1][j-1])
```

### Implementación expandir-alrededor

```python
def longest_palindromic_substring(s):
    n = len(s)
    if n == 0:
        return ""
    start, max_len = 0, 1

    def expand(left, right):
        while left >= 0 and right < n and s[left] == s[right]:
            left -= 1
            right += 1
        return left + 1, right - left - 1

    for i in range(n):
        l1, len1 = expand(i, i)       # centro impar
        l2, len2 = expand(i, i + 1)   # centro par
        if len1 > max_len:
            start, max_len = l1, len1
        if len2 > max_len:
            start, max_len = l2, len2

    return s[start:start + max_len]
```

### Visualización

```text
s = "babad"

Centro i=2 ('a'):
   expand(2, 2): "a" → "bab" (s[1]==s[3], s[0]!=s[4])
   Longitud: 3

Centro i=1 ('a'):
   expand(1, 2): s[1]='a' ≠ s[2]='b' → falla
   expand(1, 1): "a" → longitud 1

Centro i=3 ('b'):
   expand(3, 3): "b" → "aba" (s[2]='a', s[4]='d') → falla
   Longitud: 1
```

## 10.2 Word Break

### El problema

```text
Dado un string s y un diccionario de palabras wordDict,
determinar si s puede segmentarse en palabras del diccionario.

s = "leetcode"
wordDict = ["leet", "code"]
Salida: True   (porque "leet" + "code" = "leetcode")
```

### Estado

```text
dp[i] = ¿es posible segmentar s[0..i-1]?
```

### Caso base

```text
dp[0] = True   ← string vacío siempre se puede segmentar
```

### Transición

```text
dp[i] = OR(dp[j] AND s[j:i] in wordDict)  para todo j < i
```

### Implementación

```python
def word_break(s, word_dict):
    n = len(s)
    dp = [False] * (n + 1)
    dp[0] = True
    word_set = set(word_dict)

    for i in range(1, n + 1):
        for j in range(i):
            if dp[j] and s[j:i] in word_set:
                dp[i] = True
                break

    return dp[n]
```

### Visualización

```text
s = "leetcode"
word_dict = {"leet", "code"}

dp[0] = True
dp[4] = True    (dp[0] AND "leet" in dict)
dp[8] = True    (dp[4] AND "code" in dict)

Resultado: True  ✓
```

## 10.3 Palindromic Substrings

### El problema

```text
Contar el número de substrings palindrómicos.

s = "aaa"
Substrings palindrómicas: "a", "a", "a", "aa", "aa", "aaa"   → 6
```

### Misma idea: expandir alrededor del centro

```python
def count_substrings(s):
    n = len(s)
    count = 0

    def expand(left, right):
        c = 0
        while left >= 0 and right < n and s[left] == s[right]:
            c += 1
            left -= 1
            right += 1
        return c

    for i in range(n):
        count += expand(i, i)
        count += expand(i, i + 1)
    return count
```

---

# 11. DP en Intervalos

Problemas donde el estado es un **intervalo** [i, j].

## 11.1 Matrix Chain Multiplication (CLRS 15.2)

### El problema

```text
Dadas matrices A₁, A₂, ..., Aₙ con dimensiones p₀×p₁, p₁×p₂, ..., pₙ₋₁×pₙ,
encontrar el PARÉNTESIS óptimo que minimiza el número de multiplicaciones escalares.

Ejemplo:
   A₁: 10×30
   A₂: 30×5
   A₃: 5×60
   p = (10, 30, 5, 60)

   (A₁A₂)A₃ = (10×30×5) + (10×5×60) = 1500 + 3000 = 4500
   A₁(A₂A₃) = (30×5×60) + (10×30×60) = 9000 + 18000 = 27000

   Óptimo: (A₁A₂)A₃ con 4500 multiplicaciones
```

### Estado

```text
dp[i][j] = mínimo número de multiplicaciones para calcular A_i · A_{i+1} · ... · A_j
```

### Caso base

```text
dp[i][i] = 0   ← una sola matriz no requiere multiplicación
```

### Transición

```text
dp[i][j] = min(dp[i][k] + dp[k+1][j] + p[i-1] * p[k] * p[j])  para k en [i, j-1]
```

### Visualización

```text
p = (10, 30, 5, 60)

       j=1   j=2       j=3
i=1     0    1500      4500    ← dp[1][2]=1500, dp[1][3]=4500
i=2          0         9000
i=3                   0

dp[1][3] = min(
   k=1: dp[1][1] + dp[2][3] + 10·30·60 = 0 + 9000 + 18000 = 27000
   k=2: dp[1][2] + dp[3][3] + 10·5·60  = 1500 + 0 + 3000 = 4500   ← mínimo
) = 4500  ✓
```

### Implementación

```python
def matrix_chain_order(p):
    n = len(p) - 1
    dp = [[0] * (n + 1) for _ in range(n + 1)]

    for length in range(2, n + 1):
        for i in range(1, n - length + 2):
            j = i + length - 1
            dp[i][j] = float('inf')
            for k in range(i, j):
                cost = dp[i][k] + dp[k+1][j] + p[i-1] * p[k] * p[j]
                if cost < dp[i][j]:
                    dp[i][j] = cost
    return dp[1][n]
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(n³) |
| Espacio | O(n²) |

## 11.2 Burst Balloons

### El problema

```text
Tienes n globos con números. Disparas al globo i y obtienes
   nums[left] * nums[i] * nums[right]
donde left y right son los vecinos actuales. left y right se convierten en vecinos.
Maximiza la suma total de monedas.

nums = [3, 1, 5, 8]
Óptimo: 167
   burst 1 → 3·1·5 = 15, nums = [3, 5, 8]
   burst 5 → 3·5·8 = 120, nums = [3, 8]
   burst 3 → 1·3·8 = 24, nums = [8]
   burst 8 → 1·8·1 = 8, nums = []
   Total = 15 + 120 + 24 + 8 = 167
```

### Idea: invertir la perspectiva

```text
En vez de "qué globo reviento primero",
piensa: "qué globo reviento ÚLTIMO en el rango [i, j]".
```

### Estado

```text
dp[i][j] = máxima monedas que puedes obtener reventando todos los globos en (i, j)
           excluyendo nums[i] y nums[j] (que son los "bordes")
```

### Transición

```text
dp[i][j] = max(dp[i][k] + dp[k][j] + nums[i] * nums[k] * nums[j])
           para todo k en (i, j)
```

### Implementación

```python
def max_coins(nums):
    nums = [1] + [n for n in nums if n > 0] + [1]
    n = len(nums)
    dp = [[0] * n for _ in range(n)]

    for length in range(2, n - 1):
        for i in range(n - length - 1):
            j = i + length + 1
            for k in range(i + 1, j):
                dp[i][j] = max(dp[i][j],
                              dp[i][k] + dp[k][j] + nums[i] * nums[k] * nums[j])
    return dp[0][n - 1]
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(n³) |
| Espacio | O(n²) |

## 11.3 Palindromic Partitioning II

### El problema

```text
Dado un string, encontrar el número MÍNIMO de cortes para particionarlo
en substrings palindrómicas.

s = "aab"
Cortes mínimos: 1  ("aa" | "b")
```

### Precomputar palíndromos con dp[i][j]

```python
def min_cut(s):
    n = len(s)
    is_palindrome = [[False] * n for _ in range(n)]

    for i in range(n):
        is_palindrome[i][i] = True

    for i in range(n - 1, -1, -1):
        for j in range(i + 1, n):
            if s[i] == s[j]:
                is_palindrome[i][j] = (j == i + 1) or is_palindrome[i+1][j-1]

    cuts = [0] * n
    for i in range(n):
        if is_palindrome[0][i]:
            cuts[i] = 0
        else:
            cuts[i] = float('inf')
            for j in range(i):
                if is_palindrome[j+1][i]:
                    cuts[i] = min(cuts[i], cuts[j] + 1)
    return cuts[n - 1]
```

---

# 12. DP en Grafos y Árboles

## 12.1 Bellman-Ford

### El problema

```text
Encontrar el camino más corto desde un origen a todos los demás nodos.
Funciona con pesos NEGATIVOS (a diferencia de Dijkstra).
Detecta ciclos negativos.
```

### Estado

```text
dp[v] = distancia más corta conocida del origen al nodo v
```

### Transición

```text
Para cada arista (u, v, w):
   si dp[u] + w < dp[v]:
      dp[v] = dp[u] + w
```

### Implementación

```c
typedef struct {
    int u, v, w;
} Edge;

void bellmanFord(Edge edges[], int E, int V, int src, int dist[]) {
    for (int i = 0; i < V; i++) dist[i] = INT_MAX;
    dist[src] = 0;

    for (int i = 0; i < V - 1; i++) {
        for (int j = 0; j < E; j++) {
            int u = edges[j].u, v = edges[j].v, w = edges[j].w;
            if (dist[u] != INT_MAX && dist[u] + w < dist[v])
                dist[v] = dist[u] + w;
        }
    }
}
```

### Visualización

```text
Grafo:
   1 →(4) 2
   1 →(1) 3
   3 →(2) 2
   2 →(5) 4
   3 →(8) 4

Iteración 0: dist = [0, INF, INF, INF, INF]    (1, 2, 3, 4)
Iteración 1: dist = [0, INF, 1, INF, INF]
Iteración 2: dist = [0, 5, 1, INF, INF]
Iteración 3: dist = [0, 5, 1, INF, INF]
Iteración 4: dist = [0, 5, 1, INF, INF]
Iteración 5: dist = [0, 4, 1, 10, INF]  ← mejora 2→4 por vía 1-3-2

Final: [0, 4, 1, 10]
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(V·E) |
| Espacio | O(V) |

## 12.2 Floyd-Warshall

### El problema

```text
Encontrar el camino más corto entre TODOS los pares de nodos.
```

### Estado

```text
dp[k][i][j] = distancia más corta de i a j usando solo nodos intermedios del set {0, 1, ..., k-1}
```

### Caso base

```text
dp[0][i][j] = peso de la arista (i, j), o INF si no existe
dp[0][i][i] = 0
```

### Transición

```text
dp[k][i][j] = min(
   dp[k-1][i][j],                  ← no usar el nodo k-1
   dp[k-1][i][k-1] + dp[k-1][k-1][j]   ← pasar por el nodo k-1
)
```

### Implementación

```python
def floyd_warshall(graph):
    n = len(graph)
    dist = [row[:] for row in graph]

    for k in range(n):
        for i in range(n):
            for j in range(n):
                if dist[i][k] + dist[k][j] < dist[i][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]

    return dist
```

### Visualización

```text
Grafo:        Matriz inicial:
   1→2 (3)       0   3   INF INF
   2→4 (1)       2   0   INF 1
   1→3 (2)       INF 7   0   INF
   3→2 (5)       6  INF INF 0
   4→1 (4)

Después de k=0 (usando nodo 0 como intermedio):
   ...

Después de k=3:
   0   3   2   4
   2   0   4   1
   7   5   0   6
   6   9   8   0
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(V³) |
| Espacio | O(V²) |

### Variaciones

- **Reconstrucción de caminos:** guardar `next[i][j]` para recuperar la ruta.
- **Detección de ciclos negativos:** si después del algoritmo `dist[i][i] < 0` para algún `i`, hay ciclo negativo.

## 12.3 DP en Árboles

### Tree Diameter

#### El problema

```text
Encontrar el camino más largo en un árbol (en número de aristas).

       1
      /|\
     2 3 4
    /|    \
   5 6     7

Diámetro = 5 → 2 → 1 → 4 → 7, longitud 4
```

#### Algoritmo

```text
Dos BFS/DFS:
   1. BFS desde cualquier nodo → encuentra nodo A (extremo del diámetro)
   2. BFS desde A → encuentra nodo B y la distancia = diámetro

O alternativa DP:
   Para cada nodo v, longestPath[v] = longestDownwardPath que pasa por v
   longestPath[v] = max(longestPath de hijos) + max(longestDownwardPath de hijos) + 1
```

#### Implementación DFS

```python
def tree_diameter(edges, n):
    from collections import defaultdict, deque
    graph = defaultdict(list)
    for u, v in edges:
        graph[u].append(v)
        graph[v].append(u)

    def bfs(start):
        dist = [-1] * n
        dist[start] = 0
        q = deque([start])
        far_node = start
        while q:
            u = q.popleft()
            for v in graph[u]:
                if dist[v] == -1:
                    dist[v] = dist[u] + 1
                    q.append(v)
                    if dist[v] > dist[far_node]:
                        far_node = v
        return far_node, dist[far_node]

    far, _ = bfs(0)
    _, diameter = bfs(far)
    return diameter
```

### Tree Independent Set

#### El problema

```text
Seleccionar el máximo número de nodos tal que ningún par sea adyacente.
```

#### Estado

```text
dp[v][0] = mejor solución en el subárbol de v, NO incluyendo v
dp[v][1] = mejor solución en el subárbol de v, INCLUYENDO v
```

#### Transición

```text
dp[v][1] = 1 + sum(dp[c][0])           para cada hijo c
dp[v][0] = sum(max(dp[c][0], dp[c][1])) para cada hijo c
```

#### Implementación

```python
def tree_independent_set(children, root):
    def dfs(v):
        incl = 1
        excl = 0
        for c in children.get(v, []):
            ic, ec = dfs(c)
            incl += ec
            excl += max(ic, ec)
        return incl, excl

    return max(dfs(root))
```

### Tree Longest Path (otra formulación)

Similar al diameter pero incluyendo pesos en los nodos.

---

# 13. Bitmask DP

## 13.1 La idea

```text
Cada subconjunto de n elementos se representa como un entero de n bits.
DP sobre máscaras: dp[mask] = mejor resultado para el subconjunto 'mask'.

Útil cuando n ≤ 20 (porque 2^20 = ~10^6 es manejable).
```

## 13.2 Traveling Salesman Problem (TSP)

### El problema

```text
Dado un grafo completo con n ciudades y distancias d[i][j],
encontrar el camino más corto que visita cada ciudad EXACTAMENTE UNA VEZ y regresa al inicio.

n ciudades → (n-1)! permutaciones (sin fijar el inicio)
```

### Solución DP bitmask

#### Estado

```text
dp[mask][i] = mínima distancia para visitar las ciudades en 'mask',
              terminando en la ciudad i
```

#### Caso base

```text
dp[1 << 0][0] = 0      ← empezamos en la ciudad 0
```

#### Transición

```text
dp[mask | (1 << j)][j] = min(dp[mask][i] + d[i][j])
                          para cada i en mask, j no en mask
```

#### Respuesta

```text
min(dp[(1 << n) - 1][i] + d[i][0])   para cada i
      ↑ todas las ciudades visitadas     volver al inicio
```

### Implementación

```python
def tsp(dist):
    n = len(dist)
    INF = float('inf')
    dp = [[INF] * n for _ in range(1 << n)]
    dp[1][0] = 0

    for mask in range(1 << n):
        for i in range(n):
            if dp[mask][i] == INF:
                continue
            for j in range(n):
                if mask & (1 << j) == 0:
                    new_mask = mask | (1 << j)
                    if dp[mask][i] + dist[i][j] < dp[new_mask][j]:
                        dp[new_mask][j] = dp[mask][i] + dist[i][j]

    full = (1 << n) - 1
    return min(dp[full][i] + dist[i][0] for i in range(n))
```

### Visualización

```text
n = 4 ciudades: 0, 1, 2, 3

Máscaras (subconjuntos visitados):
   0001: solo ciudad 0
   0011: ciudades 0 y 1
   0111: ciudades 0, 1, 2
   1111: todas

dp[0001][0] = 0
dp[0011][1] = dist[0][1]
dp[0111][2] = min(dp[0011][0] + dist[0][2], dp[0011][1] + dist[1][2])
...

Respuesta: min(dp[1111][i] + dist[i][0]) para i = 0..3
```

### Complejidad

| Métrica | Valor |
| ------- | ----- |
| Tiempo | O(n² · 2ⁿ) |
| Espacio | O(n · 2ⁿ) |

### Cuándo usar

| Tamaño | ¿Bitmask DP? |
| ------ | ------------ |
| n ≤ 15 | ✅ Perfecto |
| n = 20 | ⚠️ Límite (~10⁷ ops) |
| n ≥ 25 | ❌ Inmanejable (usar heurísticas o ILP) |

## 13.3 Asignación (Assignment Problem)

### El problema

```text
n personas y n tareas. Cada persona i cuesta c[i][j] en la tarea j.
Asignar cada persona a UNA tarea minimizando el costo total.
```

### Estado y transición

```text
dp[mask] = mínimo costo de asignar las personas en 'mask' a las primeras |mask| tareas
dp[mask | (1 << i)] = min(dp[mask] + c[i][j])   para cada i no en mask, j = popcount(mask)
```

### Implementación

```python
def assignment(cost):
    n = len(cost)
    dp = [float('inf')] * (1 << n)
    dp[0] = 0

    for mask in range(1 << n):
        j = bin(mask).count('1')
        if j >= n:
            continue
        for i in range(n):
            if mask & (1 << i) == 0:
                new_mask = mask | (1 << i)
                if dp[mask] + cost[i][j] < dp[new_mask]:
                    dp[new_mask] = dp[mask] + cost[i][j]

    return dp[(1 << n) - 1]
```

### Complejidad: O(n · 2ⁿ)

## 13.4 Cuándo usar Bitmask DP

```text
✅ Usa bitmask cuando:
   - El estado es un subconjunto de n elementos pequeños (n ≤ 20)
   - Necesitas rastrear qué elementos ya usaste
   - El problema es "visita cada elemento una vez"

❌ Evita bitmask cuando:
   - n > 25 (memoria y tiempo explotan)
   - El estado no es un conjunto de elementos
   - Hay estructuras más eficientes (DP clásica, greedy, etc.)
```

---

# 14. Patrones de DP

Una vez que entiendes los problemas, **los patrones se repiten**. Reconocer el patrón correcto es la mitad del trabajo.

## 14.1 Los 7 patrones canónicos

| # | Patrón | Estado típico | Ejemplo |
| - | ------ | ------------- | ------- |
| 1 | **1D DP** | `dp[i]` | Fibonacci, Climbing Stairs, Coin Change |
| 2 | **2D DP (grid)** | `dp[i][j]` | Unique Paths, Min Path Sum |
| 3 | **2D DP (dos secuencias)** | `dp[i][j]` | LCS, Edit Distance |
| 4 | **DP sobre subsecuencias** | `dp[i]` con búsqueda en `[0, i-1]` | LIS |
| 5 | **DP sobre intervalos** | `dp[i][j]` | Matrix Chain, Burst Balloons |
| 6 | **DP sobre árboles** | `dp[v][0/1]` | Independent Set, Diameter |
| 7 | **State Machine DP** | `dp[i][state]` | Stock Buy/Sell, House Robber |

## 14.2 1D DP

### Características

```text
- Estado: un índice i
- Transición: usa valores anteriores (dp[i-1], dp[i-2], etc.)
- Caso base: dp[0], a veces dp[1]
- Tabla: array de tamaño n
```

### Ejemplos

| Problema | Transición |
| -------- | ---------- |
| Fibonacci | `dp[i] = dp[i-1] + dp[i-2]` |
| Climbing Stairs | `dp[i] = dp[i-1] + dp[i-2]` |
| Coin Change (min) | `dp[i] = min(dp[i-c]) + 1` para cada moneda c |
| House Robber | `dp[i] = max(dp[i-1], dp[i-2] + nums[i])` |

### Plantilla

```c
int dp[n + 1];
dp[0] = ...;                    // caso base
for (int i = 1; i <= n; i++) {
    dp[i] = f(dp[i-1], dp[i-2], ...);   // transición
}
return dp[n];
```

## 14.3 2D DP (Grid)

### Características

```text
- Estado: posición (i, j) en una rejilla
- Transición: típicamente arriba o izquierda
- Tabla: matriz de m × n
```

### Ejemplos

| Problema | Transición |
| -------- | ---------- |
| Unique Paths | `dp[i][j] = dp[i-1][j] + dp[i][j-1]` |
| Min Path Sum | `dp[i][j] = grid[i][j] + min(dp[i-1][j], dp[i][j-1])` |
| Dungeon Game | `dp[i][j] = max(1, min(...) - dungeon[i][j])` |

### Plantilla

```c
int dp[m][n];
for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) {
        dp[i][j] = ...;   // depende de dp[i-1][j], dp[i][j-1], etc.
    }
}
```

## 14.4 2D DP (Dos secuencias)

### Características

```text
- Estado: dp[i][j] = resultado para primeros i elementos de A y primeros j elementos de B
- Transición: comparas A[i-1] con B[j-1]
- Tabla: m × n
```

### Ejemplos

| Problema | Transición |
| -------- | ---------- |
| LCS | match: dp[i-1][j-1] + 1; no match: max(dp[i-1][j], dp[i][j-1]) |
| Edit Distance | match: dp[i-1][j-1]; no match: 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) |
| Distinct Subsequences | match: dp[i-1][j-1] + dp[i-1][j]; no match: dp[i-1][j] |

## 14.5 DP sobre Subsecuencias

### Características

```text
- Estado: dp[i] = mejor resultado para el prefijo que TERMINA en i
- Transición: mira hacia atrás en todos los j < i
- Tabla: array de n
```

### Ejemplos

| Problema | Transición |
| -------- | ---------- |
| LIS | `dp[i] = 1 + max(dp[j])` para todo j < i con nums[j] < nums[i] |
| Longest Divisible Subset | igual con nums[i] % nums[j] == 0 |
| Max Envelopes | combinación de LIS + sort |

## 14.6 DP sobre Intervalos

### Características

```text
- Estado: dp[i][j] = mejor resultado para el intervalo [i, j]
- Transición: probar todos los puntos medios k en (i, j)
- Tabla: matriz n × n triangular superior
```

### Ejemplos

| Problema | Transición |
| -------- | ---------- |
| Matrix Chain | `dp[i][j] = min(dp[i][k] + dp[k+1][j] + cost)` |
| Burst Balloons | `dp[i][j] = max(dp[i][k] + dp[k][j] + nums[i]*nums[k]*nums[j])` |
| Palindromic Partitioning | `dp[i][j] = min(dp[i][k] + dp[k+1][j] + 1)` |

## 14.7 State Machine DP

### Características

```text
- Estado: dp[i][state] = mejor resultado hasta el día i en el estado 'state'
- Transición: reglas del state machine
- Tabla: n × (# estados)
```

### Ejemplo clásico: Stock Buy/Sell con cooldown

```text
Estados por día:
   hold     = tengo una acción
   sold     = acabo de vender (cooldown)
   free     = puedo comprar

dp[i][hold] = max(dp[i-1][hold], dp[i-1][free] - price[i])
dp[i][sold] = dp[i-1][hold] + price[i]
dp[i][free] = max(dp[i-1][free], dp[i-1][sold])
```

### Visualización

```text
        ┌────(no buy)────┐
        ↓                │
       free ──(buy)──> hold
        ↑                │
        │                │
        └──(cooldown)─── sold <──(sell)── hold
```

## 14.8 Digit DP

### Características

```text
- Estado: dp[pos][tight][otras_dimensiones]
- tight: ¿hemos usado el límite superior hasta ahora?
- Se usa para contar números con propiedades específicas
```

### Ejemplo: contar números sin el dígito 4 hasta N

```python
def count_without_4(n):
    s = str(n)
    from functools import lru_cache

    @lru_cache(maxsize=None)
    def dp(pos, tight):
        if pos == len(s):
            return 1
        limit = int(s[pos]) if tight else 9
        count = 0
        for d in range(0, limit + 1):
            if d == 4:
                continue
            count += dp(pos + 1, tight and (d == limit))
        return count

    return dp(0, True)
```

---

# 15. Optimización de DP

## 15.1 Space Optimization (Rolling Array)

### Problema

```text
Muchas DP solo necesitan las últimas k filas/columnas.
```

### Ejemplo: Fibonacci

```text
Original:    dp = [0, 1, 1, 2, 3, 5, ...]    O(n) espacio
Optimizado:  prev2, prev1, curr               O(1) espacio
```

```python
def fib_optimized(n):
    if n < 2:
        return n
    prev2, prev1 = 0, 1
    for _ in range(2, n + 1):
        curr = prev1 + prev2
        prev2, prev1 = prev1, curr
    return prev1
```

### Ejemplo: 0/1 Knapsack

```text
Original:    dp[i][w] para i objetos y w peso
Optimizado:  dp[w] de tamaño W+1, iterando hacia atrás
```

```python
def knapsack_1d(W, weights, values, n):
    dp = [0] * (W + 1)
    for i in range(n):
        for w in range(W, weights[i] - 1, -1):   # ATRÁS
            dp[w] = max(dp[w], dp[w - weights[i]] + values[i])
    return dp[W]
```

### Ejemplo: 2D a 1D (Unique Paths)

```python
def unique_paths_1d(m, n):
    dp = [1] * n
    for i in range(1, m):
        for j in range(1, n):
            dp[j] += dp[j-1]
    return dp[n-1]
```

### Tabla resumen

| Problema | Tabla original | Optimizado |
| -------- | -------------- | ---------- |
| Fibonacci | O(n) | **O(1)** |
| Climbing Stairs | O(n) | **O(1)** |
| House Robber | O(n) | **O(1)** |
| 0/1 Knapsack | O(n·W) | **O(W)** |
| Coin Change | O(amount) | O(amount) |
| Unique Paths | O(m·n) | **O(n)** |
| Edit Distance | O(m·n) | **O(n)** |
| LCS | O(m·n) | **O(min(m,n))** |

## 15.2 Monotonic Queue Optimization

### Problema

```text
En DP como:
   dp[i] = max(dp[j]) + c[i]  para j en [i-k, i-1]

La búsqueda naive es O(n·k). Con monotonic queue: O(n).
```

### Idea

```text
Mantener una deque con los candidatos j en orden de dp[j] decreciente.
Para cada i:
   1. Agregar i al final, mantener orden.
   2. Descartar índices fuera de [i-k, i-1].
   3. El frente de la deque es el óptimo.
```

### Aplicación: Sliding Window Maximum (DP style)

```python
from collections import deque

def constrained_max_sum(arr, k):
    n = len(arr)
    dp = [0] * n
    dp[0] = arr[0]
    dq = deque([0])

    for i in range(1, n):
        while dq and dq[0] < i - k:
            dq.popleft()
        dp[i] = arr[i] + (dp[dq[0]] if dq else 0)
        while dq and dp[dq[-1]] < dp[i]:
            dq.pop()
        dq.append(i)

    return max(dp)
```

## 15.3 Divide and Conquer Optimization

### Problema

```text
DP de la forma:
   dp[i][j] = min(dp[i-1][k] + C(k, j))   para k < j

Si la "decisión óptima" argmin(k) es monótona en j, podemos usar D&C optimization.
Complejidad: O(n² · log n) o incluso O(n²).
```

### Cuándo aplica

```text
✅ Cuándo:
   - La recurrencia es DP[i][j] = min(DP[i-1][k] + C(k, j)) para k < j
   - opt[j] ≤ opt[j+1]   (monotonicidad de la decisión óptima)

❌ Cuándo NO:
   - Max en lugar de min
   - opt no es monótona
```

### Algoritmo (esquema)

```python
import sys

def compute(arr, dp_prev, dp_curr, left, right, opt_left, opt_right):
    if left > right:
        return
    mid = (left + right) // 2

    best_k = -1
    best_val = sys.maxsize
    for k in range(opt_left, min(mid, opt_right) + 1):
        val = dp_prev[k] + cost(k, mid)
        if val < best_val:
            best_val = val
            best_k = k

    dp_curr[mid] = best_val
    compute(arr, dp_prev, dp_curr, left, mid - 1, opt_left, best_k)
    compute(arr, dp_prev, dp_curr, mid + 1, right, best_k, opt_right)
```

### Ejemplo: Knapsack con costo especial

```text
Si la elección del "último item" tiene monotonicidad garantizada,
podemos usar D&C optimization.
```

## 15.4 Otras optimizaciones (preview)

| Optimización | Reduce | Cuándo aplica |
| ------------ | ------ | ------------- |
| **Rolling Array** | Espacio O(n·k) → O(k) | Solo últimas k filas importan |
| **Monotonic Queue** | O(n·k) → O(n) | DP con max/min en ventana |
| **Divide & Conquer** | O(n²·k) → O(n·k·log n) | opt[j] monótona |
| **Knuth's Optimization** | O(n²) → O(n²) (con constante menor) | Cuadrangle inequality |
| **Convex Hull Trick** | O(n²) → O(n log n) o O(n) | DP lineal con costos cuadráticos |
| **SMAWK** | O(n·m) → O(n+m) | DP totalmente monótono |
| **Aliens trick** | Restricciones parametrizadas | Problemas con restricciones tipo "<= k" |

---

# 16. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error | Consecuencia | Ejemplo |
| ----- | ------------ | ------- |
| **Caso base incorrecto** | Resultados errados en `n` pequeño | `dp[0]=1` cuando debería ser 0 |
| **Off-by-one en transiciones** | Subproblemas perdidos o duplicados | `dp[i-2]` en vez de `dp[i-1]` |
| **Index out of bounds** | Crash | `dp[i-2]` cuando i=1 |
| **Estado mal definido** | Recurrencia incorrecta | No incluir la decisión tomada |
| **Orden de iteración incorrecto** | Subproblemas no calculados aún | Top-down vs bottom-up reversed |
| **Reconstrucción rota** | Solución no reconstruible | Olvidar guardar decisiones |
| **Memoria explotando** | TLE/MLE | dp[20][2^20] = 20 GB |
| **Recursión profunda** | Stack overflow | fibMemo(10⁶) sin bottom-up |
| **Ignorar optimalidad local** | Greedy cuando se necesita DP | Mochila fraccionaria vs 0/1 |
| **DP donde D&C basta** | Código innecesariamente complejo | Merge Sort con memo |

### ✅ Buenas Prácticas

| Práctica | Razón |
| -------- | ----- |
| **Empezar con la pregunta "¿es DP?"** | No todos los problemas lo requieren |
| **Definir el estado en una frase** | Si no puedes, probablemente está mal |
| **Verificar casos base con ejemplos pequeños** | Detecta off-by-one temprano |
| **Implementar primero la versión recursiva** | Más fácil de verificar la recurrencia |
| **Optimizar espacio al final** | Primero correcto, luego eficiente |
| **Dibujar la tabla para n pequeño** | Enseña cómo se llena visualmente |
| **Reconstruir la solución con tabla `choice[][]`** | Útil cuando piden el camino óptimo, no solo el valor |
| **Usar bottom-up en producción** | Sin overhead de recursión |
| **Considerar iteración al revés en knapsack** | Evita usar el mismo objeto dos veces |
| **Probar con casos bordes** | `n=0`, `n=1`, todos iguales, etc. |
| **Conectar con la recurrencia** | `dp[i][j]` debe tener sentido geométrico/estructural |
| **Documentar la invariante** | Mantenibilidad del código |

---

# 17. Intuición de Ingeniería

## 17.1 Cómo reconocer un problema de DP

### Las 5 preguntas

```text
1. ¿El problema pide OPTIMIZAR (max/min) o CONTAR?
   Sí → probablemente DP

2. ¿La solución tiene SUBESTRUCTURA ÓPTIMA?
   Sí → candidato a DP

3. ¿Los SUBPROBLEMAS se TRASLAPAN?
   Sí → DP (no D&C)

4. ¿Si haces recursión naïve, recalculas mucho?
   Sí → DP

5. ¿El espacio de estados es PEQUEÑO comparando con el input?
   Sí → DP es viable
```

### Árbol de decisión

```text
¿El problema pide óptimo (max/min) o contar?
├── NO → probablemente greedy o búsqueda
└── SÍ → ¿Hay subestructura óptima?
    ├── NO → difícil (¿backtracking?)
    └── SÍ → ¿Los subproblemas se repiten?
        ├── NO → Divide & Conquer
        └── SÍ → 🎯 Programación Dinámica
```

### Señales típicas en el enunciado

```text
✅ "Encuentra el número MÁXIMO/MÍNIMO de ..."
✅ "¿De cuántas FORMAS puedes ..."
✅ "¿Cuál es la SUBSECUENCIA más larga ..."
✅ "... usando exactamente X ..."
✅ "... en el menor número de pasos ..."
✅ "... sin repetir ..."
```

## 17.2 Plantilla mental para resolver un problema DP

### Paso 1: Caracterizar la estructura de la solución óptima

```text
Pregúntate:
   - ¿Cómo se ve una solución candidata?
   - ¿De qué "opciones" dispongo en cada paso?
   - ¿Cuál es la "información" que necesito saber para decidir?
```

### Paso 2: Definir el estado

```text
El estado dp[...] debe capturar TODA la información necesaria
para tomar la decisión óptima en cualquier punto.
```

### Paso 3: Plantear la recurrencia

```text
Para cada opción, ¿qué estado siguiente produce?
dp[nuevo_estado] = combinación de dp[estados_anteriores]
```

### Paso 4: Identificar casos base

```text
¿Qué estados tienen respuesta trivial?
¿Qué condiciones evitan transiciones inválidas?
```

### Paso 5: Decidir implementación

```text
Top-down: si solo necesitas algunos estados, o la recurrencia es compleja
Bottom-up: si necesitas reconstruir, o quieres máximo rendimiento
```

### Paso 6: Optimizar (si es necesario)

```text
¿La tabla explota en memoria?
   → Rolling array, reducir dimensiones, compresión

¿Hay monotonicidad?
   → Divide & conquer optimization, monotonic queue

¿La recurrencia es costosa?
   → Convex hull trick, Knuth optimization, etc.
```

## 17.3 Comparación final: DP vs Greedy vs D&C

| Característica | DP | Greedy | D&C |
| -------------- | -- | ------ | --- |
| **Subproblemas** | Traslapados | Independientes | Independientes |
| **Decisión** | Considerar todas las opciones | Mejor local | Combinar resultados |
| **Garantía óptimo** | ✅ Sí (si las 2 condiciones) | ⚠️ Solo si greedy-choice property | ✅ Sí (si combinación es correcta) |
| **Complejidad típica** | O(n²), O(n·m) | O(n log n) | O(n log n) |
| **Cuándo usarlo** | Optimo en problemas complejos | Problemas con estructura matroid/greedy | Subproblemas independientes |

## 17.4 Las 5 reglas mnemotécnicas de DP

| Regla | Significado |
| ----- | ----------- |
| **"DP es para óptimos"** | Max, min, contar formas |
| **"Traslapados, no independientes"** | Si recalculas → DP |
| **"Estado bien definido = 80% del trabajo"** | La transición sale sola |
| **"Casos base primero"** | Sin ellos, todo se cae |
| **"Bottom-up en producción"** | Sin overhead, sin stack overflow |

## 17.5 Conexión con los otros temas de este repositorio

| Tema | Conexión con DP |
| ---- | --------------- |
| **Algorithms.md (sección 14)** | Introducción y resumen |
| **Divide&Conquer.md** | D&C vs DP: ¿independientes o traslapados? |
| **Sorting.md** | Merge Sort y Counting Sort son D&C; Radix Sort usa counting iterativo |
| **Recursion/** | DP es recursión + memoización; las recurrencias de D&C se analizan con método maestro |
| **Greedy/** | Greedy es "DP con mirada corta"; si no funciona, intenta DP |

## 17.6 Tabla de decisión rápida

| Si tu problema es... | Probablemente usa... |
| -------------------- | -------------------- |
| Fibonacci, factorial, combinaciones | **DP 1D** |
| Climbing Stairs, House Robber | **DP 1D** |
| Subsequence longest | **DP 1D o 2D** |
| LCS, Edit Distance | **DP 2D (dos secuencias)** |
| Knapsack (cualquier variante) | **DP 2D (objeto × capacidad)** |
| Subset Sum | **DP 1D o 2D** |
| Unique Paths, Min Path Sum | **DP 2D (grid)** |
| LIS | **DP 1D con binary search** |
| Kadane | **DP 1D** |
| Matrix Chain, Burst Balloons | **DP intervalos** |
| TSP, Asignación (n ≤ 20) | **Bitmask DP** |
| Camino más corto en grafo | **Bellman-Ford, Floyd-Warshall** |
| Subproblemas independientes | **D&C** |
| Greedy-choice property | **Greedy** |
| Espacio de búsqueda pequeño | **Backtracking** |

## 17.7 El principio unificador

> **DP es la versión algorítmica de "no repetir trabajo".**
>
> Cuando un algoritmo recursivo natural tiene **subproblemas traslapados**,
> la memoización lo convierte de exponencial a polinomial.
>
> Es uno de los conceptos más poderosos de la algoritmia:
> aplicado correctamente, problemas O(2ⁿ) o O(n!) se vuelven O(n²) o O(n³).
>
> La habilidad clave es **reconocer el patrón**: estado, transición, caso base.
> Una vez que lo dominas, DP deja de ser una "técnica misteriosa" y se convierte
> en una forma natural de pensar sobre optimización.

---

## Referencias

- **CLRS** — Cormen, Leiserson, Rivest, Stein. *Introduction to Algorithms* (4ª ed.).
  - Capítulo 15: *Dynamic Programming* (rod cutting, matrix chain, LCS, optimal BST)
  - Capítulo 15.1: *Rod cutting* (introducción canónica)
  - Capítulo 15.2: *Matrix-chain multiplication*
  - Capítulo 15.3: *Elements of dynamic programming*
  - Capítulo 15.4: *Longest common subsequence*
  - Capítulo 15.5: *Optimal binary search trees*
  - Apéndice: Relación con Bellman-Ford y Floyd-Warshall
- **Algorithms.md** en este repositorio — sección 14 (intro a DP).
- **Divide&Conquer.md** en este repositorio — comparación DP vs D&C (subproblemas traslapados vs independientes).
- **Sorting.md** en este repositorio — D&C puro (Merge Sort) vs index-based (Counting Sort, similar a DP en algunos aspectos).
- **LeetCode**, **CP-Algorithms** y **AtCoder Educational DP Contest** para práctica.
- **Richard Bellman**, *Eye of the Hurricane* (autobiografía) — historia del nombre "dynamic programming".