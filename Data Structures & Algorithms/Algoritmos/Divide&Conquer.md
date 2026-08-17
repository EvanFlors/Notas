# Divide & Conquer — Divide y Vencerás

> **Idea central:** Resolver un problema **dividiéndolo en subproblemas más pequeños** del mismo tipo,
> resolviendo cada uno recursivamente, y **combinando** las soluciones.
>
> Es una de las tres grandes estrategias de diseño de algoritmos (junto con Greedy y Programación Dinámica).
> Aparece por primera vez de forma formal en el Capítulo 2 y 4 del CLRS.

---

## Tabla de Contenidos

1. [¿Qué es Divide & Conquer?](#1-qué-es-divide--conquer)
2. [La Anatomía de un Algoritmo D&C](#2-la-anatomía-de-un-algoritmo-dc)
3. [Por qué Funciona: La Intuición](#3-por-qué-funciona-la-intuición)
4. [Recurrencias: El Lenguaje del D&C](#4-recurrencias-el-lenguaje-del-dc)
5. [Métodos para Resolver Recurrencias](#5-métodos-para-resolver-recurrencias)
6. [El Método Maestro (CLRS 4.5)](#6-el-método-maestro-clrs-45)
7. [Método de Akra–Bazzi (Avanzado)](#7-método-de-akrabazzi-avanzado)
8. [Algoritmos Clásicos — CLRS Capítulo 2](#8-algoritmos-clásicos--clrs-capítulo-2)
9. [Algoritmos Avanzados — CLRS Capítulo 4](#9-algoritmos-avanzados--clrs-capítulo-4)
10. [FFT y Convolución](#10-fft-y-convolución)
11. [Cuándo Usar (y Cuándo NO) Divide & Conquer](#11-cuándo-usar-y-cuándo-no-divide--conquer)
12. [Errores Comunes y Buenas Prácticas](#12-errores-comunes-y-buenas-prácticas)
13. [Intuición de Ingeniería](#13-intuición-de-ingeniería)

---

# 1. ¿Qué es Divide & Conquer?

## 1.1 Definición

**Divide & Conquer (D&C)** es una estrategia algorítmica que resuelve un problema siguiendo **tres pasos**:

```text
┌──────────────────────────────────────────────────┐
│              DIVIDE                              │
│  Dividir el problema en subproblemas más         │
│  pequeños del mismo tipo.                        │
└──────────────────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│              CONQUER (Vence)                     │
│  Resolver cada subproblema recursivamente.       │
│  Si es suficientemente pequeño, resolverlo       │
│  directamente (caso base).                       │
└──────────────────────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│              COMBINE                             │
│  Combinar las soluciones de los subproblemas     │
│  para formar la solución del problema original.  │
└──────────────────────────────────────────────────┘
```

> **CLRS (Cap. 2.3):** *“Many useful algorithms are recursive in structure: to solve a given problem, they call themselves recursively one or more times to deal with closely related subproblems.”*

## 1.2 Analogía del mundo real

**Resolver un misterio:**

```text
Tienes que encontrar a un sospechoso en una ciudad de 1 millón de habitantes.

Brute Force:        Preguntar a cada persona, una por una.           O(n)
Divide & Conquer:   Dividir la ciudad en 4 cuadrantes.               O(n)
                    Interrogar 1 persona por cuadrante (representante).
                    Eliminar los 3 cuadrantes donde no está.
                    Repetir recursivamente en el cuadrante sospechoso.
```

**Organizar un torneo de eliminación:**

```text
64 equipos → 32 partidos → 16 → 8 → 4 → 2 → 1 campeón

Cada partido es un "conquer" de un subproblema.
No necesitas que todos jueguen contra todos.
```

## 1.3 Ejemplos famosos (preview)

| Algoritmo              | Divide                              | Combine                    | Complejidad |
| ---------------------- | ----------------------------------- | -------------------------- | ----------- |
| **Merge Sort**         | Mitad izquierda / mitad derecha     | Merge O(n)                 | O(n log n)  |
| **Quick Sort**         | Por pivote (< pivot, = pivot, >)    | Recursivo (sin merge)      | O(n log n)  |
| **Binary Search**      | Mitad del rango                     | Elegir mitad               | O(log n)    |
| **Karatsuba**          | Mitades de dígitos                  | 3 multiplicaciones         | O(n^1.585)  |
| **Strassen**           | Bloques de matrices                 | 7 multiplicaciones         | O(n^2.807)  |
| **Closest Pair**       | Línea vertical al medio             | Tira central O(n)          | O(n log n)  |
| **FFT**                | Coeficientes pares / impares        | Combinación O(n)           | O(n log n)  |

---

# 2. La Anatomía de un Algoritmo D&C

## 2.1 Pseudocódigo genérico (CLRS 2.3.1)

```text
DAC(p):
    if p es lo suficientemente pequeño o simple:
        return solución_directa(p)

    dividir p en subproblemas p₁, p₂, ..., pₖ

    for i = 1 to k:
        yᵢ = DAC(pᵢ)

    return combinar(y₁, y₂, ..., yₖ)
```

> **Notación CLRS:** DAC = Divide-And-Conquer.

## 2.2 Estructura típica en C

```c
Resultado resolver(Problema p, int n) {
    // 1. CASO BASE: problema pequeño → resolver directo
    if (n <= UMBRAL) {
        return solucionDirecta(p, n);
    }

    // 2. DIVIDE: partir en subproblemas
    // (por ejemplo, partir el array a la mitad)
    int m = n / 2;
    Subproblema izq = dividirIzquierda(p, m);
    Subproblema der = dividirDerecha(p, n - m);

    // 3. CONQUER: llamadas recursivas
    Resultado r_izq = resolver(izq, m);
    Resultado r_der = resolver(der, n - m);

    // 4. COMBINE: juntar soluciones
    return combinar(r_izq, r_der);
}
```

## 2.3 Las tres preguntas antes de aplicar D&C

| Pregunta                                            | Si la respuesta es NO…                              |
| --------------------------------------------------- | --------------------------------------------------- |
| ¿Se puede dividir el problema en partes menores?    | D&C probablemente no aplica.                       |
| ¿Las partes son **independientes** entre sí?        | Si NO → considera **Programación Dinámica**.       |
| ¿Combinar las soluciones es eficiente (sub-lineal)? | Si NO → puede no haber ganancia sobre brute force. |

> **CLRS Cap. 2.3:** *“The divide-and-conquer paradigm involves three steps at each level of the recursion.”*

---

# 3. Por qué Funciona: La Intuición

## 3.1 La idea central: achicar exponencialmente

Si divides el problema en `a` subproblemas de tamaño `n/b`, y gastas `f(n)` en combinar:

```text
Nivel 0:  1 problema de tamaño n            → f(n)
Nivel 1:  a problemas de tamaño n/b         → a · f(n/b)
Nivel 2:  a² problemas de tamaño n/b²       → a² · f(n/b²)
...
Nivel k:  aᵏ problemas de tamaño n/bᵏ       → aᵏ · f(n/bᵏ)

Profundidad: log_b(n) niveles hasta llegar a tamaño 1
```

Si el **trabajo por nivel** crece, se mantiene o decrece, el total es manejable.

## 3.2 Visualización: el árbol de recursión

```text
                    [n]                      ← Nivel 0:  1 nodo
                  /     \
              [n/2]     [n/2]                ← Nivel 1:  2 nodos
              /   \     /   \
          [n/4] [n/4] [n/4] [n/4]            ← Nivel 2:  4 nodos
           ...       ...
       [1][1][1][1][1][1][1][1]...           ← Nivel log₂(n): n nodos de tamaño 1
```

**Truco mental:** suma el trabajo de **cada nivel** y multiplícalo por el número de niveles.

## 3.3 Ejemplo numérico: Merge Sort

```text
T(n) = 2·T(n/2) + n          ← dividir en 2, combinar en O(n)

Nivel 0:    n                    → trabajo total del nivel: n
Nivel 1:    2 × (n/2)           → n
Nivel 2:    4 × (n/4)           → n
...
Nivel log n: n × 1               → n

Total: (log₂ n + 1) × n  =  O(n log n)   ✓
```

> **Intuición:** Como el trabajo por nivel es **constante** (siempre `n`) y hay `log n` niveles, el total es `O(n log n)`.

---

# 4. Recurrencias: El Lenguaje del D&C

## 4.1 ¿Qué es una recurrencia?

Una **recurrencia** es una ecuación que describe una función en términos de **sí misma con entradas más pequeñas**.

```text
T(n) = trabajo_total_problema_de_tamaño_n
     = (trabajo de dividir) + (trabajo de subproblemas) + (trabajo de combinar)
```

## 4.2 Anatomía de una recurrencia D&C

```text
T(n) = a · T(n/b) + D(n) + C(n)
        ↑      ↑       ↑       ↑
       #subp  tamaño  dividir combinar
       prob   subprob
```

| Símbolo | Significado                                     |
| ------- | ----------------------------------------------- |
| `a`     | Número de subproblemas en que dividimos         |
| `b`     | Factor por el que se reduce el tamaño           |
| `D(n)`  | Costo de **dividir** el problema                |
| `C(n)`  | Costo de **combinar** las soluciones            |

## 4.3 Ejemplos clásicos

```text
┌────────────────────┬──────────────────────────┬────────────────────────┐
│ Algoritmo          │ Recurrencia              │ Explicación            │
├────────────────────┼──────────────────────────┼────────────────────────┤
│ Merge Sort         │ T(n) = 2·T(n/2) + O(n)   │ 2 mitades + merge      │
│ Binary Search      │ T(n) = 1·T(n/2) + O(1)   │ 1 mitad + elegir       │
│ Quick Sort (avg)   │ T(n) = 2·T(n/2) + O(n)   │ 2 particiones + costo  │
│ Quick Sort (peor)  │ T(n) = 1·T(n-1) + O(n)   │ pivote mal elegido     │
│ Karatsuba          │ T(n) = 3·T(n/2) + O(n)   │ 3 multiplicaciones     │
│ Strassen           │ T(n) = 7·T(n/2) + O(n²)  │ 7 multiplicaciones     │
│ Closest Pair       │ T(n) = 2·T(n/2) + O(n)   │ dividir + tira central │
│ Naive Fibonacci    │ T(n) = 2·T(n-1) + O(1)   │ (NO es D&C eficiente)  │
└────────────────────┴──────────────────────────┴────────────────────────┘
```

## 4.4 Por qué las recurrencias importan

> Una recurrencia **es la complejidad de tu algoritmo**. Resolverla te dice si tu algoritmo es rápido o lento.

---

# 5. Métodos para Resolver Recurrencias

Tres métodos canónicos (CLRS Cap. 4):

| Método                | Idea                                  | Mejor para              |
| --------------------- | ------------------------------------- | ----------------------- |
| **Sustitución**       | Adivinar la solución, probar por inducción | Verificar cota         |
| **Árbol de recursión**| Dibujar el árbol y sumar trabajo por nivel | Intuición visual       |
| **Método maestro**    | Fórmula cerrada para `T(n) = aT(n/b)+f(n)` | Recurrencias estándar |

---

## 5.1 Método de Sustitución (CLRS 4.1)

### Idea

1. **Adivinar** la forma de la solución (`O(n log n)`, `O(n²)`, etc.)
2. **Probar** por inducción que la conjetura es válida.
3. Ajustar las constantes hasta que la inducción cierre.

### Ejemplo: `T(n) = 2T(n/2) + n`

**Conjetura:** `T(n) = O(n log n)` ⟹ existe `c` tal que `T(n) ≤ c·n·log n`.

**Paso inductivo** (asumimos cierto para `n/2`):

```text
T(n)   = 2·T(n/2) + n
       ≤ 2·(c·(n/2)·log(n/2)) + n        ← sustitución de la hipótesis
       = c·n·log(n/2) + n
       = c·n·(log n - 1) + n
       = c·n·log n - c·n + n
       ≤ c·n·log n                         ← si c ≥ 1, entonces -c·n + n ≤ 0 ✓
```

### Truco: probar `T(n) ≤ c·n·log n + d`

A veces la forma `c·n·log n` no cierra la inducción por detalles de pisos (`⌊n/2⌋`).
La solución es **restar** o **sumar** un término de menor orden:

```text
T(n) ≤ c·n·log n + d

Demostración:
T(n) = 2T(⌊n/2⌋) + n
     ≤ 2(c·(n/2)·log(n/2) + d) + n
     = c·n·log(n/2) + 2d + n
     = c·n·(log n - 1) + 2d + n
     = c·n·log n - c·n + 2d + n
     ≤ c·n·log n + d       ← si -c·n + 2d + n ≤ d, i.e. n(1-c) ≤ -d
                            ← basta con c ≥ 2 y d ≥ -n (caso base)
```

### Cuándo usar sustitución

✅ Cuando el método maestro **no aplica** (forma no estándar).
✅ Para **verificar** una conjetura que sacaste por intuición o árbol.
❌ Es artesanal — requiere práctica y a veces "trucos" para cerrar la inducción.

---

## 5.2 Método del Árbol de Recursión (CLRS 4.2)

### Idea

Convertir la recurrencia en un **árbol**, calcular el trabajo de cada nivel, y sumar.

### Ejemplo: `T(n) = 3T(n/4) + cn²`

```text
Nivel 0:           cn²                                total nivel: cn²
                  /  |  \
Nivel 1:      c(n/4)²  c(n/4)²  c(n/4)²              total: 3·c·n²/16
              / | \   / | \    / | \
Nivel 2:  9 nodos de c(n/16)²  cada uno              total: 9·c·n²/256
          ...
Nivel log₄n:  3^(log₄n) hojas = n^(log₄ 3)            total: ≈ n^(log₄ 3)
```

**Trabajo por nivel (serie geométrica):**

```text
Nivel i: 3ⁱ · c · (n/4ⁱ)² = c · n² · (3/16)ⁱ
```

Como `3/16 < 1`, la suma **decrece geométricamente**. El nivel 0 domina:

```text
T(n) = O(n²)        ← dominado por el trabajo del primer nivel
```

### Truco: árbol para `T(n) = T(n/3) + T(2n/3) + n`

```text
                    [n]                  ← n
                  /      \
              [n/3]      [2n/3]         ← n/3 + 2n/3 = n
              /   \      /    \
          [n/9][2n/9] [2n/9][4n/9]      ← n
          ...
          ...                              ← cada nivel suma n

Profundidad: el camino más largo es n → 2n/3 → 4n/9 → ... → 1
            log_{3/2}(n) ≈ 1.71 · log₂(n)

Total: O(n log n)
```

### Cuándo usar árbol de recursión

✅ Cuando la recurrencia **no es balanceada** (subproblemas de distinto tamaño).
✅ Para **desarrollar intuición** antes de probar formalmente.
❌ No es una prueba formal; suele combinarse con sustitución.

---

# 6. El Método Maestro (CLRS 4.5)

## 6.1 Teorema (CLRS 4.1)

Dada la recurrencia:

```text
T(n) = a · T(n/b) + f(n)
```

con `a ≥ 1`, `b > 1`, y `f(n)` asintóticamente positiva, comparamos `f(n)` con `n^(log_b a)`:

| Caso | Condición                  | Resultado              | Intuición                                |
| ---- | -------------------------- | ---------------------- | ---------------------------------------- |
| 1    | `f(n) = O(n^(log_b a - ε))` | `T(n) = Θ(n^(log_b a))` | **El árbol crece**: las hojas dominan |
| 2    | `f(n) = Θ(n^(log_b a) · logᵏ n)` | `T(n) = Θ(n^(log_b a) · logᵏ⁺¹ n)` | **Niveles equilibrados**           |
| 3    | `f(n) = Ω(n^(log_b a + ε))` | `T(n) = Θ(f(n))`        | **La raíz domina**: trabajo por nivel decrece |

> El `ε > 0` indica que la desigualdad es **polinómicamente** más ajustada (no solo por constantes).

## 6.2 La intuición: ¿quién gana, las hojas o la raíz?

Imagina el árbol de recursión:

```text
            Raíz: f(n)
          /       |       \
      f(n/b)    f(n/b)  ... f(n/b)        ← a hijos
       ...
      Hojas: trabajo_total = n^(log_b a)
```

- **Si el trabajo por nivel CRECE:** las hojas ganan → Caso 1
- **Si el trabajo por nivel se mantiene CONSTANTE:** todos los niveles contribuyen → Caso 2
- **Si el trabajo por nivel DECRECE:** la raíz gana → Caso 3

```text
Caso 1:    nivel raíz < nivel hojas       → Θ(hojas) = Θ(n^log_b a)
Caso 2:    todos los niveles ≈ iguales   → Θ(nivel × log n)
Caso 3:    nivel raíz > nivel hojas       → Θ(raíz) = Θ(f(n))
```

## 6.3 Ejemplos resueltos

### Merge Sort: `T(n) = 2T(n/2) + n`

```text
a = 2, b = 2, f(n) = n
log_b a = log₂ 2 = 1
f(n) = Θ(n^1) = Θ(n^log_b a · log⁰ n)    ← Caso 2 con k=0

T(n) = Θ(n · log n)  ✓
```

### Binary Search: `T(n) = T(n/2) + 1`

```text
a = 1, b = 2, f(n) = 1
log_b a = log₂ 1 = 0
f(n) = Θ(n⁰) = Θ(1)                       ← Caso 2 con k=0

T(n) = Θ(log n)  ✓
```

### Karatsuba: `T(n) = 3T(n/2) + cn`

```text
a = 3, b = 2, f(n) = cn
log_b a = log₂ 3 ≈ 1.585
f(n) = O(n^(1.585 - ε))                    ← Caso 1 (con ε ≈ 0.585)

T(n) = Θ(n^log₂ 3) = Θ(n^1.585)  ✓
```

### Strassen: `T(n) = 7T(n/2) + cn²`

```text
a = 7, b = 2, f(n) = cn²
log_b a = log₂ 7 ≈ 2.807
f(n) = O(n^(2.807 - ε))                    ← Caso 1

T(n) = Θ(n^log₂ 7) = Θ(n^2.807)  ✓
```

### Recorrido de árbol: `T(n) = 2T(n/2) + n²`

```text
a = 2, b = 2, f(n) = n²
log_b a = 1
f(n) = Ω(n^(1+ε)) con ε=1                 ← Caso 3

Verificación de regularidad (CLRS 4.5.2):
   a·f(n/b) ≤ c·f(n) para algún c < 1?
   2·(n/2)² = n²/2 ≤ c·n²   sí, con c = 1/2  ✓

T(n) = Θ(n²)  ✓
```

### Recurrencia crítica para Caso 3: `T(n) = T(n/2) + n`

```text
a = 1, b = 2, f(n) = n
log_b a = 0
f(n) = Ω(n^ε) con ε = 1                    ← Caso 3

T(n) = Θ(n)  ✓
```

## 6.4 Cuando el método maestro NO aplica

El método maestro **no funciona** si:

| Situación                                    | Por qué no aplica                          |
| -------------------------------------------- | ------------------------------------------ |
| `f(n)` no es polinómicamente menor/mayor     | Ej: `f(n) = n·log n` con `n^(log_b a)`     |
| La división no es uniforme                   | Ej: `T(n) = T(n/3) + T(2n/3) + n`         |
| `a` no es constante                          | Ej: `T(n) = n·T(n/2)`                     |
| Hay pisos o techos no acotados               | `T(n) = T(⌊n/2⌋) + ...` con casos patológicos |

Para esos casos → **método de sustitución** o **Akra–Bazzi**.

---

# 7. Método de Akra–Bazzi (Avanzado)

## 7.1 El teorema

Para recurrencias más generales:

```text
T(n) = Σ aᵢ · T(bᵢ · n) + g(n)
       i=1..k

con:
  - 0 < bᵢ < 1
  - aᵢ > 0
  - g(n) "suave" (condición técnica)
```

Si `p` satisface `Σ aᵢ · bᵢᵖ = 1`, entonces:

```text
T(n) = Θ(nᵖ · (1 + ∫₁ⁿ g(u)/u^(p+1) du))
```

> **Método maestro** es un caso especial de Akra–Bazzi cuando solo hay un término `T(n/b)`.

## 7.2 Ejemplo: `T(n) = T(n/3) + T(2n/3) + n`

```text
Buscar p tal que:
   (1/3)ᵖ + (2/3)ᵖ = 1

Por inspección / numérico:  p ≈ 0.7887... (no es entero bonito)

Sin integral complicada:
   g(n) = n = Θ(n¹)
   nᵖ con p ≈ 0.788 → n⁰·⁷⁸⁸ no domina a n

   T(n) = Θ(n · log n)      ← porque la integral aporta un factor log
```

---

# 8. Algoritmos Clásicos — CLRS Capítulo 2

## 8.1 Maximum Subarray Problem (CLRS 4.1)

### El problema

Dado un array de números (con negativos y positivos), encontrar el **subarray contiguo** con la suma máxima.

```text
Entrada:  [13, -3, -25, 20, -3, -16, -23, 18, 20, -7, 12, -5, -22, 15, -4, 7]
                                ↓
Subarray:               [18, 20, -7, 12, -5, 22, ...]
Salida:   suma máxima = 43   (subarray [7, 10, 14] en este ejemplo)
```

### Por qué importa

Brute force da O(n³). Versión mejorada (prefijo) da O(n²). Pero Kadane da O(n).
Aquí mostramos la **solución D&C** del CLRS, que es O(n log n) — un escalón antes de Kadane.

### Idea D&C

```text
Cualquier subarray maximal está completamente en una de tres regiones:
   1. Mitad izquierda
   2. Mitad derecha
   3. Cruza el medio (parte en cada mitad)

Caso 3 = máximo que termina en m + máximo que empieza en m+1
```

### Algoritmo (CLRS)

```c
typedef struct {
    int izq, der, suma;
} Subarray;

Subarray maxSubarray(int A[], int bajo, int alto) {
    if (alto == bajo) {                         // caso base
        Subarray base = {bajo, alto, A[bajo]};
        return base;
    }

    int medio = (bajo + alto) / 2;

    Subarray izq  = maxSubarray(A, bajo, medio);
    Subarray der  = maxSubarray(A, medio + 1, alto);
    Subarray cruz = maxSubarrayCruz(A, bajo, medio, alto);

    if (izq.suma >= der.suma && izq.suma >= cruz.suma) return izq;
    else if (der.suma >= izq.suma && der.suma >= cruz.suma) return der;
    else return cruz;
}

Subarray maxSubarrayCruz(int A[], int bajo, int medio, int alto) {
    int suma_izq = -INFINITY, suma = 0;
    for (int i = medio; i >= bajo; i--) {
        suma += A[i];
        if (suma > suma_izq) suma_izq = suma;
    }

    int suma_der = -INFINITY;
    suma = 0;
    for (int j = medio + 1; j <= alto; j++) {
        suma += A[j];
        if (suma > suma_der) suma_der = suma;
    }

    Subarray res = {i_max_izq, j_max_der, suma_izq + suma_der};
    return res;
}
```

### Análisis

```text
T(n) = 2T(n/2) + Θ(n)        ← dos llamadas + maxSubarrayCruz en O(n)

Por método maestro:  Caso 2

T(n) = Θ(n log n)
```

> **Kadane** es O(n) y aún mejor — pero la versión D&C es importante para entender la técnica.

---

## 8.2 Búsqueda Binaria (recursiva) — CLRS 2.3.2

### El problema

Buscar un valor en un array **ordenado** en tiempo O(log n).

### Algoritmo

```c
int binarySearch(int A[], int bajo, int alto, int x) {
    if (bajo > alto) return -1;

    int medio = bajo + (alto - bajo) / 2;   // evita overflow

    if      (A[medio] == x) return medio;
    else if (x < A[medio])  return binarySearch(A, bajo, medio - 1, x);
    else                    return binarySearch(A, medio + 1, alto, x);
}
```

### Recurrencia y análisis

```text
T(n) = 1·T(n/2) + O(1)

a=1, b=2, f(n)=1
log_b a = log₂ 1 = 0
f(n) = Θ(1) = Θ(n⁰)                ← Caso 2 con k=0

T(n) = Θ(log n)  ✓
```

---

## 8.3 Exponenciación Rápida (Power)

### El problema

Calcular `aⁿ` eficientemente.

### Idea D&C

```text
aⁿ = (a^(n/2))²          ← si n es par
aⁿ = a · (a^((n-1)/2))²  ← si n es impar
```

### Algoritmo

```c
long long power(long long a, int n) {
    if (n == 0) return 1;
    if (n == 1) return a;

    long long mitad = power(a, n / 2);

    if (n % 2 == 0) return mitad * mitad;
    else            return a * mitad * mitad;
}
```

### Análisis

```text
T(n) = T(n/2) + O(1)    ← ¡misma recurrencia que binary search!

T(n) = O(log n)
```

> **Comparación:** iterativo naïve es O(n). D&C es O(log n). Diferencia enorme para `n = 10⁹`.

---

## 8.4 Búsqueda del k-ésimo menor (Quickselect)

### El problema

Encontrar el **k-ésimo elemento más pequeño** en tiempo esperado O(n).

### Idea (variante de Quicksort)

```text
Si solo quieres UN elemento, no necesitas ordenar TODO.

Quickselect:
   1. Particionar alrededor de un pivote
   2. Si el pivote está en la posición k → listo
   3. Si k < posición_pivote → buscar en izquierda
   4. Si k > posición_pivote → buscar en derecha
```

### Algoritmo

```c
int quickselect(int A[], int bajo, int alto, int k) {
    if (bajo == alto) return A[bajo];

    int p = partition(A, bajo, alto);    // partición estilo quicksort

    int rieles = p - bajo + 1;           // elementos en A[bajo..p]

    if      (k == rieles) return A[p];
    else if (k <  rieles) return quickselect(A, bajo, p - 1, k);
    else                  return quickselect(A, p + 1, alto, k - rieles);
}
```

### Análisis

```text
Peor caso:    T(n) = T(n-1) + O(n) = O(n²)
Promedio:     T(n) = T(n/2) + O(n) = O(n)

→ Aleatorizar el pivote elimina el peor caso con probabilidad altísima.
```

---

## 8.5 Fibonacci (con matriz, D&C)

### La observación clave

```text
[F(n+1)]   [1  1]ⁿ   [1]
[F(n)  ] = [1  0]   · [0]
```

Por lo tanto, `F(n)` se puede calcular con **exponenciación rápida de matrices**.

### Algoritmo

```c
typedef struct { long long m[2][2]; } Matriz;

Matriz mult(Matriz A, Matriz B) {
    Matriz C;
    C.m[0][0] = A.m[0][0]*B.m[0][0] + A.m[0][1]*B.m[1][0];
    C.m[0][1] = A.m[0][0]*B.m[0][1] + A.m[0][1]*B.m[1][1];
    C.m[1][0] = A.m[1][0]*B.m[0][0] + A.m[1][1]*B.m[1][0];
    C.m[1][1] = A.m[1][0]*B.m[0][1] + A.m[1][1]*B.m[1][1];
    return C;
}

Matriz power(Matriz M, int n) {
    if (n == 1) return M;
    Matriz mitad = power(M, n/2);
    if (n % 2 == 0) return mult(mitad, mitad);
    return mult(M, mult(mitad, mitad));
}

long long fib(int n) {
    if (n < 2) return n;
    Matriz M = {{{1, 1}, {1, 0}}};
    Matriz R = power(M, n);
    return R.m[0][1];
}
```

### Análisis

```text
T(n) = T(n/2) + O(1) = O(log n)
```

> **Comparación:**
> | Versión              | Complejidad |
> |----------------------|-------------|
> | Recursión naïve      | O(2ⁿ)       |
> | DP iterativo         | O(n)        |
> | D&C con matriz       | **O(log n)**|

---

## 8.6 Tabla resumen — Algoritmos clásicos

| Algoritmo               | Recurrencia              | Solución       | Mejora vs naïve      |
| ----------------------- | ------------------------ | -------------- | -------------------- |
| **Merge Sort**          | `2T(n/2) + n`            | O(n log n)     | O(n²) → O(n log n)   |
| **Binary Search**       | `T(n/2) + 1`             | O(log n)       | O(n) → O(log n)      |
| **Max Subarray**        | `2T(n/2) + n`            | O(n log n)     | O(n³) → O(n log n)   |
| **Exponenciación**      | `T(n/2) + 1`             | O(log n)       | O(n) → O(log n)      |
| **Quickselect**         | `T(n/2) + n` (promedio)  | O(n)           | O(n log n) → O(n)    |
| **Fibonacci (matriz)**  | `T(n/2) + 1`             | O(log n)       | O(2ⁿ) → O(log n)     |

---

# 9. Algoritmos Avanzados — CLRS Capítulo 4

## 9.1 Multiplicación de Enteros: Karatsuba (CLRS 4.2)

### El problema

Multiplicar dos enteros de `n` dígitos. El método escolar es **O(n²)**.

### Observación clave

Escribir números en mitades:

```text
x = a · 10^(n/2) + b       ← a = mitad alta, b = mitad baja
y = c · 10^(n/2) + d

Producto:
x·y = a·c · 10ⁿ + (a·d + b·c) · 10^(n/2) + b·d
```

Naïve D&C: 4 multiplicaciones (`ac`, `ad`, `bc`, `bd`).
Gauss/Karatsuba: **solo 3**.

### El truco de Gauss

```text
(a·d + b·c) = (a + b)·(c + d) - a·c - b·d
                              ↑      ↑
                            ya los  ya los
                            tenemos tenemos
```

¡Podemos reutilizar `ac` y `bd`!

### Algoritmo

```c
// Multiplica dos números grandes representados como strings o arrays
// Retorna x * y
BigInt karatsuba(BigInt x, BigInt y) {
    if (x.num_digitos <= UMBRAL || y.num_digitos <= UMBRAL)
        return multiplicarEscolar(x, y);

    int m = max(x.num_digitos, y.num_digitos) / 2;

    BigInt a = x.high(m);
    BigInt b = x.low(m);
    BigInt c = y.high(m);
    BigInt d = y.low(m);

    BigInt ac = karatsuba(a, c);
    BigInt bd = karatsuba(b, d);
    BigInt ab_cd = karatsuba(a + b, c + d);

    // ab_cd - ac - bd = a·d + b·c
    BigInt ad_bc = ab_cd - ac - bd;

    return ac · 10^(2m) + ad_bc · 10^m + bd;
}
```

### Recurrencia y análisis

```text
T(n) = 3·T(n/2) + Θ(n)

a = 3, b = 2, f(n) = Θ(n)
log_b a = log₂ 3 ≈ 1.585
f(n) = O(n^(1.585 - ε))                  ← Caso 1

T(n) = Θ(n^log₂ 3) = Θ(n^1.585)
```

### Impacto histórico

```text
Naïve:    O(n²)
Karatsuba: O(n^1.585)   ← descubierto por Anatoly Karatsuba (1960)

El primero en ROMPER la barrera O(n²) para multiplicación.
Inspiró décadas de algoritmos sub-cuadráticos.
```

> **Generalización (Toom-Cook):** Generaliza Karatsuba a `k` trozos. Más rápido pero más complejo. Para `k → ∞` se acerca al FFT.

---

## 9.2 Multiplicación de Matrices: Strassen (CLRS 4.3)

### El problema

Multiplicar dos matrices `n × n`. Naïve es **O(n³)**.

### El truco de Strassen (1969)

Partir cada matriz en 4 bloques:

```text
         [A B]   [E F]      [AE+BG  AF+BH]
[A B] ·  [   ] = [       ] = [            ]
[C D]   [C D]   [G H]      [CE+DG  CF+DH]
```

Naïve necesita 8 multiplicaciones de bloques. Strassen: **solo 7**.

```text
M₁ = A(F - H)
M₂ = (A + B)H
M₃ = (C + D)E
M₄ = D(G - E)
M₅ = (A + D)(E + H)
M₆ = (B - D)(G + H)
M₇ = (A - C)(E + F)

Resultado:
C₁₁ = M₅ + M₄ - M₂ + M₆
C₁₂ = M₁ + M₂
C₂₁ = M₃ + M₄
C₂₂ = M₁ + M₅ - M₃ - M₇
```

### Implementación (esqueleto)

```c
Matriz strassen(Matriz A, Matriz B) {
    int n = A.tam;

    if (n == 1) {
        Matriz C = {{A[0][0] * B[0][0]}};
        return C;
    }

    // Partir A y B en 4 cuadrantes cada una
    Matriz A11 = A.sub(0, 0, n/2);
    Matriz A12 = A.sub(0, n/2, n/2);
    Matriz A21 = A.sub(n/2, 0, n/2);
    Matriz A22 = A.sub(n/2, n/2, n/2);
    // ... igual para B

    // 7 multiplicaciones recursivas
    Matriz M1 = strassen(A11, B12 - B22);
    Matriz M2 = strassen(A11 + A12, B22);
    Matriz M3 = strassen(A21 + A22, B11);
    Matriz M4 = strassen(A22, B21 - B11);
    Matriz M5 = strassen(A11 + A22, B11 + B22);
    Matriz M6 = strassen(A12 - A22, B21 + B22);
    Matriz M7 = strassen(A11 - A21, B11 + B12);

    // Combinar
    Matriz C;
    C11 = M5 + M4 - M2 + M6;
    C12 = M1 + M2;
    C21 = M3 + M4;
    C22 = M5 + M1 - M3 - M7;
    return C;
}
```

### Recurrencia y análisis

```text
T(n) = 7·T(n/2) + Θ(n²)

a = 7, b = 2, f(n) = Θ(n²)
log_b a = log₂ 7 ≈ 2.807
f(n) = O(n^(2.807 - ε))                  ← Caso 1

T(n) = Θ(n^log₂ 7) = Θ(n^2.807)
```

### ¿Por qué importa si en la práctica no se usa?

| Aspecto              | Naïve O(n³)        | Strassen O(n^2.807) | En la práctica |
| -------------------- | ------------------ | ------------------- | -------------- |
| Constantes           | Pequeñas           | Grandes             | ❌ Más lento para n típico |
| Memoria              | O(n²)              | O(n² log n) extra   | ❌ Más RAM     |
| Implementación       | Trivial            | Compleja            | ❌ Bug-prone   |
| n muy grande         | Imposible          | Teóricamente viable | ✅ Único uso real |

> **Conclusión:** Strassen es **teóricamente** importante porque rompió la barrera O(n³), pero las constantes altas lo hacen impráctico excepto para matrices **enormes** (n > 1000). Hoy, **algoritmos de bloques** + SIMD/GPU son más rápidos.

---

## 9.3 Par de Puntos Más Cercanos (Closest Pair) — CLRS 4.2

### El problema

Dados `n` puntos en el plano, encontrar los **dos más cercanos** en distancia euclidiana.

```text
  *           *
     *                 *
        *
   *           *
        *  ← ¿Cuál par tiene menor distancia?
```

### Algoritmo naïve: O(n²)

Comparar todos los pares.

### Algoritmo D&C: O(n log n)

```text
1. Ordenar puntos por coordenada X  → O(n log n)

2. DIVIDE:
   Trazar línea vertical L en el medio
   Dividir puntos en Q (izquierda) y R (derecha)

3. CONQUER:
   Resolver recursivamente en Q y R
   Obtener d1, d2

4. COMBINE:
   d = min(d1, d2)
   Examinar la "tira" de puntos a distancia ≤ d de L
   Para cada punto, comparar con los siguientes 7 puntos ordenados por Y
   (garantía geométrica: solo 7 candidatos)

5. Mantener puntos ordenados por Y en cada paso: O(n log n) total
```

### Implementación (esqueleto)

```c
typedef struct {
    double x, y;
} Punto;

double stripClosest(Punto strip[], int tam, double d) {
    double min_d = d;
    // strip ya viene ordenada por Y
    for (int i = 0; i < tam; i++) {
        for (int j = i + 1; j < tam && (strip[j].y - strip[i].y) < min_d; j++) {
            double dist = distancia(strip[i], strip[j]);
            if (dist < min_d) min_d = dist;
        }
    }
    return min_d;
}

double closestUtil(Punto Px[], Punto Py[], int n) {
    if (n <= 3) return bruteForce(Px, n);   // caso base

    int mid = n / 2;
    Punto midPoint = Px[mid];

    // Dividir Py en izquierda y derecha según midPoint.x
    Punto Pyl[mid + 1], Pyr[n - mid - 1];
    int il = 0, ir = 0;
    for (int i = 0; i < n; i++) {
        if (Py[i].x <= midPoint.x) Pyl[il++] = Py[i];
        else                        Pyr[ir++] = Py[i];
    }

    double dl = closestUtil(Px, Pyl, mid);
    double dr = closestUtil(Px + mid, Pyr, n - mid);

    double d = min(dl, dr);

    // Construir strip: puntos a menos de d de la línea media
    Punto strip[n];
    int k = 0;
    for (int i = 0; i < n; i++)
        if (abs(Py[i].x - midPoint.x) < d)
            strip[k++] = Py[i];

    return min(d, stripClosest(strip, k, d));
}
```

### ¿Por qué solo 7 comparaciones en la tira?

```text
Geometría: si divides el plano en cuadrículas de lado d/2,
cada cuadrícula contiene a lo más UN punto (si no, dos puntos estarían a < d).

  ┌──┬──┬──┬──┐
  │  │  │  │  │     Hay 8 cuadrículas adyacentes
  ├──┼──┼──┼──┤     en un cuadrado 3×3 centrado
  │  │ P│  │  │     en P (incluyendo la propia).
  ├──┼──┼──┼──┤     En 2D, basta examinar
  │  │  │  │  │     7 cuadrículas vecinas (CLRS prueba ≤ 7).
  └──┴──┴──┴──┘
```

### Recurrencia y análisis

```text
T(n) = 2T(n/2) + Θ(n)         ← merge de la tira

Por método maestro:  Caso 2

T(n) = Θ(n log n)
```

---

## 9.4 Tabla resumen — Algoritmos avanzados

| Algoritmo              | Recurrencia              | Solución       | Naïve          |
| ---------------------- | ------------------------ | -------------- | -------------- |
| **Karatsuba**          | `3T(n/2) + Θ(n)`         | Θ(n^1.585)     | Θ(n²)          |
| **Strassen**           | `7T(n/2) + Θ(n²)`        | Θ(n^2.807)     | Θ(n³)          |
| **Closest Pair**       | `2T(n/2) + Θ(n)`         | Θ(n log n)     | Θ(n²)          |

---

# 10. FFT y Convolución

## 10.1 El problema

Multiplicar dos polinomios de grado `n`:

```text
A(x) = a₀ + a₁x + a₂x² + ... + aₙxⁿ
B(x) = b₀ + b₁x + b₂x² + ... + bₙxⁿ

C(x) = A(x) · B(x)   ← grado hasta 2n
```

### Naïve

```text
Para cada i, j:
   C[i+j] += A[i] · B[j]

Tiempo: O(n²)
```

### El truco: cambiar de representación

```text
Evaluación:  coeficientes → puntos         (forward DFT)
Interpolación: puntos → coeficientes        (inverse DFT)

Teorema:  Sean A y B polinomios de grado n.
Si los evaluamos en (2n+1) puntos y multiplicamos punto a punto,
el polinomio interpolado es exactamente A·B.
```

```text
A(x), B(x)      evaluación       [A(k), B(k)]
(coefs)       ──────────────►   (valores)
                                  │
                                  │ multiplicar punto a punto
                                  ▼
              interpolación    [C(k)]
C(x) = A·B    ◄──────────────   (valores)
(coefs)
```

> **FFT = Fast Fourier Transform.** Permite hacer DFT en **O(n log n)** en lugar de O(n²).

## 10.2 FFT Recursiva (Cooley–Tukey)

La idea es **D&C sobre índices pares e impares**:

```text
Dado A(x) = a₀ + a₁x + a₂x² + a₃x³ + a₄x⁴ + ...

Separar pares e impares:
A(x) = (a₀ + a₂x² + a₄x⁴ + ...) + x·(a₁ + a₃x² + a₅x⁴ + ...)
     = A_par(x²) + x · A_impar(x²)
```

Evaluamos en **raíces n-ésimas de la unidad** (`ω^k` para `k = 0..n-1`).

```text
Para ω = e^(2πi/n):

A(ωᵏ)   = A_par(ω²ᵏ) + ωᵏ · A_impar(ω²ᵏ)
A(ω^(k+n/2)) = A_par(ω²ᵏ) - ωᵏ · A_impar(ω²ᵏ)

Las dos mitades usan los MISMOS sub-problemas,
solo cambian de signo → una sola llamada recursiva.
```

### Algoritmo

```c
#include <complex.h>

void fft(complex double a[], int n) {
    if (n == 1) return;

    // Dividir en pares e impares
    complex double a_par[n/2], a_impar[n/2];
    for (int i = 0; i < n/2; i++) {
        a_par[i]   = a[2*i];
        a_impar[i] = a[2*i + 1];
    }

    // Conquistar (recursión)
    fft(a_par, n/2);
    fft(a_impar, n/2);

    // Combinar
    for (int k = 0; k < n/2; k++) {
        complex double w = cexp(-2.0 * I * M_PI * k / n);
        a[k]       = a_par[k] + w * a_impar[k];
        a[k + n/2] = a_par[k] - w * a_impar[k];
    }
}
```

### Multiplicación de polinomios con FFT

```c
void multiplyPolys(complex double A[], complex double B[], int n) {
    // Tamaño: siguiente potencia de 2 ≥ 2n
    int N = 1;
    while (N < 2*n) N *= 2;

    // FFT en ambos
    fft(A, N);
    fft(B, N);

    // Multiplicar punto a punto
    for (int i = 0; i < N; i++)
        A[i] *= B[i];

    // FFT inversa
    ifft(A, N);   // similar a fft pero con exponente positivo y escala
}
```

### Recurrencia y análisis

```text
T(n) = 2T(n/2) + Θ(n)         ← dos llamadas + combinación

Por método maestro:  Caso 2

T(n) = Θ(n log n)
```

## 10.3 Aplicaciones de FFT

| Aplicación                  | Idea                                       |
| --------------------------- | ------------------------------------------ |
| **Multiplicación de polinomios** | FFT → producto punto a punto → FFT⁻¹  |
| **Multiplicación de enteros grandes** | Codificar dígitos en coeficientes polinomiales |
| **Convolución** (señal/audio/imagen) | `c[k] = Σ a[i]·b[k-i]` = IFFT(FFT(A)·FFT(B)) |
| **Compresión (MP3, JPEG)**  | DCT (variante de FFT)                      |
| **Resolución de ecuaciones diferenciales** | Aproximación espectral               |

> **El FFT está entre los 10 algoritmos más importantes del siglo XX** (IEEE, 2000).

---

# 11. Cuándo Usar (y Cuándo NO) Divide & Conquer

## 11.1 Checklist — ¿D&C aplica?

```text
✅  El problema se puede dividir en ≥ 2 subproblemas del mismo tipo.
✅  Los subproblemas son independientes (no comparten estado).
✅  Combinar las soluciones es eficiente (≤ O(n)).
✅  Existe un caso base trivial.
✅  Las particiones son "limpias" (idealmente tamaños similares).
```

## 11.2 Comparación con otras estrategias

| Característica         | D&C                       | Programación Dinámica    | Greedy                  |
| ---------------------- | ------------------------- | ------------------------ | ----------------------- |
| **Subproblemas**       | Independientes            | Traslapados              | Independientes          |
| **Solución**           | Combinar sub-soluciones   | Usar sub-solucionescacheadas | Elección local óptima |
| **Recurrencia típica** | `T(n) = aT(n/b) + f(n)`  | `T(n) = aT(n/b) + O(n) + cacheo` | Sin recurrencia    |
| **Garantía óptimo**    | Sí (si combinación es correcta) | Sí                       | Solo si greedy-choice property |
| **Ejemplo**            | Merge Sort                | Fibonacci, Knapsack      | Dijkstra, MST           |

## 11.3 D&C vs DP: la diferencia crucial

```text
D&C:
   fib_naive(n) = fib_naive(n-1) + fib_naive(n-2)
   Las llamadas a fib(k) son INDEPENDIENTES en cada nivel.
   Pero el MISMO fib(k) se llama MUCHAS veces.

DP:
   fib_dp(n) = fib_dp(n-1) + fib_dp(n-2)
   Pero los fib(k) compartidos se GUARDAN en una tabla.

   D&C: "dividir el problema en pedazos que NO se reutilizan"
   DP:  "dividir el problema en pedazos que SÍ se reutilizan"
```

### Ejemplo concreto

```text
Merge Sort:     D&C    ← cada sub-array se procesa UNA vez
Fibonacci naïve: parece D&C, pero DP es mejor porque hay solapamiento
```

> **CLRS Cap. 4 (notas):** *“Divide-and-conquer algorithms are typically recursive, but they may not always be the best approach when subproblems are shared.”*

## 11.4 Tabla: cuándo elegir cada estrategia

| Si el problema tiene...                              | Usa...                |
| ---------------------------------------------------- | --------------------- |
| Subproblemas **independientes**                      | **D&C**               |
| Subproblemas **traslapados**                         | **DP**                |
| Elección local **siempre correcta**                  | **Greedy**            |
| Búsqueda con poda inteligente                        | **Backtracking**      |
| Múltiples dimensiones independientes                 | **Branch & Bound**    |

---

# 12. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                                       | Consecuencia                              |
| ----------------------------------------------------------- | ---------------------------------------- |
| Olvidar el **caso base**                                    | Stack overflow (recursión infinita)       |
| Caso base **incorrecto** (off-by-one)                       | El algoritmo falla en arreglos de tamaño 1 |
| Asumir división uniforme cuando no lo es                   | El análisis se rompe (ej: `T(n) = T(n/3)+T(2n/3)+n`) |
| Ignorar el costo del **paso de combinación**                | Puede dominar y arruinar la ganancia     |
| Confundir `T(n) = T(n/2) + O(1)` con O(log n) vs O(n)      | Diferencia abismal en la práctica        |
| Aplicar método maestro cuando la recurrencia **no encaja** | Respuesta incorrecta                      |
| D&C sobre subproblemas **traslapados**                     | Explota la complejidad (Fibonacci naïve) |
| Implementar Strassen sin considerar constantes             | Más lento que naïve en la práctica       |
| Olvidar la condición de regularidad en Caso 3               | Conclusión inválida                      |

### ✅ Buenas Prácticas

| Práctica                                                        | Razón                                       |
| --------------------------------------------------------------- | ------------------------------------------- |
| **Caso base primero**: identificar `n_pequeño` antes de dividir | Garantiza terminación                       |
| **Hacer el árbol de recursión** mental o en papel              | Detecta "cuellos de botella"               |
| **Verificar regularidad** en Caso 3 del método maestro         | Condición técnica para que la prueba cierre |
| **Umbral de inserción** (insertion sort para n ≤ 16)           | Reduce overhead de recursión                |
| **Tail-call optimization** cuando una rama es trivial           | Evita stack overflow                        |
| **Medir empíricamente** con datos reales                        | Las constantes importan                     |
| **Documentar la recurrencia** en el código                      | Mantenibilidad                              |
| **Pensar primero en el peor caso**                              | Producción ≠ laboratorio                   |

---

# 13. Intuición de Ingeniería

## 13.1 Las 5 reglas mnemotécnicas de D&C

| Regla                            | Significado                                          |
| -------------------------------- | ---------------------------------------------------- |
| **"Divide en piezas iguales"**   | División balanceada → análisis limpio                |
| **"Combina barato"**             | Si combinar es O(n^d), el método maestro te guía    |
| **"Caso base simple"**           | Sin caso base → recursión infinita → stack overflow  |
| **"Independiente primero"**     | Si hay solapamiento, probablemente necesitas DP      |
| **"Mide las constantes"**        | Teoría dice O(n^1.585) vs O(n²); la práctica puede ser al revés |

## 13.2 El árbol mental

Para cualquier recurrencia `T(n) = aT(n/b) + f(n)`, pregúntate:

```text
1. ¿Cuántos nodos por nivel?           → aⁱ
2. ¿Tamaño de cada nodo en nivel i?    → n/bⁱ
3. ¿Trabajo total del nivel i?         → aⁱ · f(n/bⁱ)
4. ¿Cuántos niveles?                   → log_b(n) (hasta hojas de tamaño 1)
5. ¿Quién domina, raíz u hojas?
```

## 13.3 Conexión con los otros temas de este repositorio

| Tema                            | Conexión con D&C                          |
| ------------------------------- | ----------------------------------------- |
| **Sorting.md**                  | Merge Sort, Quick Sort son D&C puros      |
| **Algorithms.md (sección 6)**   | Recurrencias y método maestro (versión resumida) |
| **Hashing.md**                  | Búsqueda hash O(1) "reemplaza" a búsqueda binaria O(log n) |
| **Recursion/**                  | D&C es recursión aplicada a diseño algorítmico |
| **Programación Dinámica**       | Cuando los subproblemas de D&C se solapan |

## 13.4 Tabla de decisión rápida

| Si tu problema es...                                  | Probablemente usa...              |
| ----------------------------------------------------- | --------------------------------- |
| Ordenar                                               | **Merge Sort** (D&C estable)      |
| Búsqueda en array ordenado                            | **Binary Search** (D&C = log n)   |
| Multiplicar enteros enormes                           | **Karatsuba**                     |
| Multiplicar matrices enormes                          | **Strassen** (teórico), bloques en práctica |
| Multiplicar polinomios / convoluciones                | **FFT**                           |
| Par de puntos más cercanos                            | **Closest Pair (D&C)**            |
| k-ésimo elemento                                      | **Quickselect**                   |
| Subarray contiguo con suma máxima                     | **Kadane O(n)** o D&C O(n log n)  |
| Cálculo de potencia                                   | **Exponenciación rápida**         |
| Subproblemas traslapados                              | **DP** (no D&C)                   |

## 13.5 El principio unificador

> **Divide & Conquer es la versión algorítmica de "divide y vencerás" del mundo real.**
>
> Pero a diferencia de la política, en algoritmos la **división debe ser clara, los subproblemas deben ser independientes, y la combinación debe ser eficiente**.
>
> Si una de esas tres cosas falla, busca otra estrategia.

---

## Referencias

- **CLRS** — Cormen, Leiserson, Rivest, Stein. *Introduction to Algorithms* (4ª ed.).
  - Capítulo 2.3: *Designing algorithms: Divide-and-Conquer*
  - Capítulo 4: *Divide-and-Conquer* (recurrencias, método maestro, Karatsuba, Strassen, Closest Pair, FFT)
- **Algorithms.md** en este repositorio — fundamentos de complejidad y recurrencias.
- **Sorting.md** en este repositorio — Merge Sort y Quick Sort como ejemplos canónicos de D&C.