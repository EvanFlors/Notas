# Recurrence Relations — Relaciones de Recurrencia

> **Idea central:** Una **relación de recurrencia** es una ecuación que define una función
> en términos de **sí misma con entradas más pequeñas**. Es el lenguaje natural de los algoritmos
> recursivos y, por tanto, el corazón del análisis de complejidad en Divide & Conquer.
>
> Resolver una recurrencia significa encontrar su **forma cerrada** o, al menos,
> su **comportamiento asintótico** (`O`, `Θ`, `Ω`).
> Este documento es un curso completo: desde la definición matemática hasta el Teorema de Akra–Bazzi, pasando por los tres métodos canónicos de CLRS.

---

## Tabla de Contenidos

1. [¿Qué es una Relación de Recurrencia?](#1-qué-es-una-relación-de-recurrencia)
2. [Aplicaciones en Análisis de Algoritmos](#2-aplicaciones-en-análisis-de-algoritmos)
3. [Anatomía de una Recurrencia](#3-anatomía-de-una-recurrencia)
4. [Recurrencias Lineales Homogéneas](#4-recurrencias-lineales-homogéneas)
5. [Recurrencias Lineales NO Homogéneas](#5-recurrencias-lineales-no-homogéneas)
6. [Métodos para Resolver Recurrencias](#6-métodos-para-resolver-recurrencias)
7. [Método de Iteración (Sustitución Iterativa)](#7-método-de-iteración-sustitución-iterativa)
8. [Método de Sustitución (CLRS 4.1)](#8-método-de-sustitución-clrs-41)
9. [Método del Árbol de Recursión (CLRS 4.2)](#9-método-del-árbol-de-recursión-clrs-42)
10. [Método Maestro (CLRS 4.5) — DEEP DIVE](#10-método-maestro-clrs-45--deep-dive)
11. [Teorema de Akra–Bazzi (Avanzado)](#11-teorema-de-akrabazzi-avanzado)
12. [Funciones Generadoras](#12-funciones-generadoras)
13. [Cambio de Variable](#13-cambio-de-variable)
14. [Recurrencias Comunes en Algoritmos](#14-recurrencias-comunes-en-algoritmos)
15. [Límites Inferiores y Superiores](#15-límites-inferiores-y-superiores)
16. [Errores Comunes](#16-errores-comunes)
17. [Buenas Prácticas](#17-buenas-prácticas)
18. [Intuición de Ingeniería](#18-intuición-de-ingeniería)

---

# 1. ¿Qué es una Relación de Recurrencia?

## 1.1 Definición formal

Una **relación de recurrencia** (o simplemente **recurrencia**) es una ecuación que define una
sucesión o función `T(n)` en términos de sus **valores anteriores**: `T(n-1)`, `T(n/2)`,
`T(n/3)`, etc.

```text
T(n) = 2·T(n/2) + n        ← T depende de T(n/2)
T(n) = T(n-1) + T(n-2)     ← T depende de T(n-1) y T(n-2)
T(n) = T(n-1) + 1          ← T depende solo de T(n-1)
```

Acompañada de **condiciones iniciales** (casos base):

```text
T(1) = 1,  o bien  T(0) = 0
```

> **CLRS Cap. 4:** *“A recurrence is a function that is defined in terms of itself. It describes
> the running time of a recursive algorithm.”*

## 1.2 Conexión con sucesiones matemáticas

Toda recurrencia define una **sucesión infinita** de valores:

```text
T(1), T(2), T(3), T(4), T(5), ...
```

Dados los casos base y la regla recursiva, **todos** los términos quedan unívocamente determinados.

### Ejemplo: la recurrencia `T(n) = 2T(n-1)`, con `T(1) = 1`

```text
T(1) = 1
T(2) = 2·T(1) = 2
T(3) = 2·T(2) = 4
T(4) = 2·T(3) = 8
T(5) = 2·T(4) = 16
...
T(n) = 2^(n-1)
```

> La "fórmula cerrada" o "solución explícita" es `T(n) = 2^(n-1)`. Esto es lo que queremos
> encontrar cuando "resolvemos" una recurrencia.

## 1.3 Sucesiones famosas que SON recurrencias

| Sucesión              | Recurrencia                  | Cerrada                  |
| --------------------- | ---------------------------- | ------------------------ |
| **Factorial**         | `n! = n·(n-1)!`, `0! = 1`    | `n!`                     |
| **Fibonacci**         | `F(n) = F(n-1) + F(n-2)`     | (Fórmula de Binet)       |
| **Potencias de 2**    | `a(n) = 2·a(n-1)`, `a(1) = 1`| `2^(n-1)`                |
| **Suma 1..n**         | `S(n) = S(n-1) + n`, `S(1)=1`| `n(n+1)/2`               |
| **Torres de Hanoi**   | `T(n) = 2T(n-1) + 1`         | `2^n - 1`                |

## 1.4 Recurrencias vs. ecuaciones funcionales

> ⚠️ No confundir: una recurrencia es una **definición recursiva** (los valores se calculan
> iterativamente desde la base). Una **ecuación funcional** pide los `T(n)` que satisfacen
> una identidad para todo `n` (como `T(n) = 2T(n-1)` puede no tener solución analítica
> sin caso base).

## 1.5 El vocabulario esencial

| Término            | Significado                                              |
| ------------------ | -------------------------------------------------------- |
| **Caso base**      | Los valores "semilla": `T(0)`, `T(1)`, `T(constante)`   |
| **Caso recursivo** | La regla que conecta `T(n)` con `T(sublista)`            |
| **Parámetro**      | `n` (el "tamaño" del problema)                           |
| **Orden**          | Cuántos pasos hacia atrás mira la recurrencia            |
| **Forma cerrada**  | Fórmula directa `T(n) = f(n)` sin referencias recursivas |
| **Cota asintótica**| `O(f(n))`, `Θ(f(n))`, `Ω(f(n))`                          |

> **Intuición:** Una recurrencia es una "máquina" que produce una sucesión. El caso base
> es la semilla, y el caso recursivo es la regla de producción.

---

# 2. Aplicaciones en Análisis de Algoritmos

## 2.1 El "porque" de las recurrencias

**Casi todo algoritmo recursivo** produce una recurrencia cuando analizamos su tiempo de ejecución.

```c
int mergeSort(int A[], int n) {
    if (n <= 1) return A[0];          // caso base
    int m = n / 2;
    mergeSort(A, m);                  // T(n/2)
    mergeSort(A+m, n-m);              // T(n/2)
    merge(A, n);                      // O(n) combinar
}
```

Análisis:

```text
T(n) = 2·T(n/2) + n         ← dividir + conquistar + combinar
T(1) = 1                    ← caso base
```

**Si resolvemos esta recurrencia → `T(n) = Θ(n log n)`** → sabemos que merge sort es eficiente.

> **La complejidad de tu algoritmo RECURSIVO vive en su recurrencia. Resolverla es medirla.**

## 2.2 Recurrencias vs. análisis de bucles

| Tipo de algoritmo        | Cómo se analiza          | Forma del resultado        |
| ------------------------ | ------------------------ | -------------------------- |
| **Iterativo**            | Contar operaciones en bucles | Polinomio / log directo |
| **Recursivo**            | Plantear y resolver la recurrencia | Forma cerrada o cota |

Ejemplo comparativo de Fibonacci:

```text
Iterativo:        bucle for    →  O(n)        (análisis directo)
DP recursivo:     T(n) = T(n-1) + T(n-2) cacheado  →  O(n) (resolver recurrencia)
Naïve recursivo:  T(n) = T(n-1) + T(n-2)            →  O(2^n) (resolver recurrencia)
Matriz recursivo: T(n) = T(n/2) + O(1)              →  O(log n) (resolver recurrencia)
```

Mismo problema, **4 recurrencias distintas** → 4 complejidades distintas.

## 2.3 De algoritmo a recurrencia: 3 pasos

```text
PASO 1:  Identifica el caso base.
          ¿Cuál es el input "más pequeño" que se resuelve directamente?

PASO 2:  Para n "grande", cuenta:
          (a) tiempo de dividir el problema
          (b) tiempo de las llamadas recursivas
          (c) tiempo de combinar las soluciones

PASO 3:  Escribe la recurrencia:
          T(n) = (a) + (b) + (c)
```

### Ejemplo paso a paso: Búsqueda Binaria

```c
int binarySearch(int A[], int n, int x) {
    if (n == 0) return -1;                       // (1) caso base
    int m = n / 2;
    if (A[m] == x) return m;
    if (x < A[m]) return binarySearch(A, m, x);   // (2a) subproblema n/2
    return binarySearch(A+m+1, n-m-1, x);         // (2b) subproblema n/2
}
```

```text
(1) Caso base:  T(0) = 1     (o T(1) = 1)
(2) Paso recursivo: 1 comparación O(1) + 1 llamada sobre n/2
    T(n) = 1·T(n/2) + O(1)
```

> **Divide & Conquer.md** cubre la conexión algoritmo-recurrencia con más detalle. Aquí nos
> enfocamos en **cómo resolver** la recurrencia una vez planteada.

---

# 3. Anatomía de una Recurrencia

## 3.1 Las 4 partes de una recurrencia

```text
T(n) =  a · T(n/b)  +  f(n)        con  T(1) = Θ(1)
         ───────      ─────        ──────────
         recursión    trabajo      condición
         subproblemas externo     inicial
```

| Parte          | Símbolo       | Pregunta que responde                       |
| -------------- | ------------- | ------------------------------------------- |
| **Coeficiente**| `a`           | ¿Cuántos subproblemas?                      |
| **Divisor**    | `b`           | ¿Cuánto más pequeño es cada subproblema?    |
| **Función externa** | `f(n)`  | ¿Cuánto trabajo "no recursivo" hay?         |
| **Caso base**  | `T(constante)`| ¿Cuándo paramos?                            |

## 3.2 Ejemplo etiquetado: Merge Sort

```text
T(n) =  2 · T(n/2)  +  n            con  T(1) = 1
        ─ ──── ─    ───              ────────
        a   b       f(n)             caso base
        2   2       Θ(n)             O(1)
        │   │       │                │
        │   │       │                └── "Para n=1, solo comparamos"
        │   │       └── "Merge toma Θ(n)"
        │   └── "Cada mitad es tamaño n/2"
        └── "Dos llamadas recursivas"
```

## 3.3 Ejemplo etiquetado: Fibonacci naïve

```text
F(n) =  1·F(n-1)  +  1·F(n-2)  +  1        con  F(0)=0, F(1)=1
        ────────     ────────     ─
        a₁·T(n-b₁)  a₂·T(n-b₂)  f(n)
        1·F(n-1)    1·F(n-2)     O(1) comparaciones y sumas
```

> En Fibonacci hay **dos** recurrencias con **diferentes** decrementos. Esto complica el método maestro.

## 3.4 Notaciones y consideraciones técnicas

```text
T(n) = 2T(⌊n/2⌋) + n      ← con piso
T(n) = 2T(⌈n/2⌉) + n      ← con techo
T(n) = 2T(n/2) + n        ← asintóticamente equivalente
```

> **Regla:** Para análisis asintótico, `⌊n/2⌋` y `⌈n/2⌉` y `n/2` son **iguales** (cambian por O(1)).

## 3.5 Tipos de recurrencias (taxonomía)

| Tipo                            | Forma general                    | Ejemplo                 |
| ------------------------------- | -------------------------------- | ----------------------- |
| **División uniforme**           | `T(n) = a·T(n/b) + f(n)`        | Merge sort, Karatsuba   |
| **Disminución**                 | `T(n) = a·T(n-c) + f(n)`        | Hanoi, Fibonacci naïve  |
| **División no uniforme**        | `T(n) = T(n/b) + T(n/c) + f(n)` | Quicksort (peor)        |
| **Lineal con inhomogénea**      | `T(n) = a·T(n-1) + g(n)`        | Suma 1..n               |
| **Functional / coeficientes variables** | `T(n) = n·T(n-2) + 1`    | Factorial, particiones  |
| **Con subproblemas variables**  | `T(n) = T(n/2) + T(n/4) + f(n)` | Algoritmos geométricos  |

---

# 4. Recurrencias Lineales Homogéneas

## 4.1 Definición

Una recurrencia es **lineal homogénea de orden k** si tiene la forma:

```text
aₙ = c₁·aₙ₋₁ + c₂·aₙ₋₂ + ... + cₖ·aₙ₋ₖ
```

donde `c₁, ..., cₖ` son **constantes** y no hay término dependiente solo de `n`.

> "Lineal" porque `aₙ` aparece elevada a la primera potencia.
> "Homogénea" porque **no** hay término `f(n)` que dependa solo de `n`.

## 4.2 El truco: la ecuación característica

Probamos una solución del tipo `aₙ = rⁿ`. Sustituyendo:

```text
rⁿ = c₁·rⁿ⁻¹ + c₂·rⁿ⁻² + ... + cₖ·rⁿ⁻ᵏ

Dividir por rⁿ⁻ᵏ:

rᵏ = c₁·rᵏ⁻¹ + c₂·rᵏ⁻² + ... + cₖ

Reordenar:

rᵏ - c₁·rᵏ⁻¹ - c₂·rᵏ⁻² - ... - cₖ = 0
```

> Esto es la **ecuación característica**. Sus raíces determinan la solución.

## 4.3 Caso 1: raíces distintas

Si la ecuación tiene `k` raíces **distintas** `r₁, r₂, ..., rₖ`, la solución general es:

```text
aₙ = α₁·r₁ⁿ + α₂·r₂ⁿ + ... + αₖ·rₖⁿ
```

Las constantes `αᵢ` se determinan con los **casos base**.

### Ejemplo: `aₙ = 5aₙ₋₁ - 6aₙ₋₂`, con `a₀ = 0, a₁ = 1`

```text
Ecuación característica:    r² - 5r + 6 = 0
                            (r-2)(r-3) = 0
                            r₁ = 2,  r₂ = 3

Solución general:           aₙ = α₁·2ⁿ + α₂·3ⁿ

Aplicar casos base:
  a₀ = 0:    α₁ + α₂ = 0
  a₁ = 1:    2α₁ + 3α₂ = 1

  Resolver:  α₁ = -1,  α₂ = 1

Solución:    aₙ = 3ⁿ - 2ⁿ

Verificar:
  a₂ = 5·1 - 6·0 = 5        y   3² - 2² = 9 - 4 = 5    ✓
  a₃ = 5·5 - 6·1 = 19       y   3³ - 2³ = 27 - 8 = 19   ✓
```

## 4.4 Caso 2: raíces repetidas

Si una raíz `r` tiene **multiplicidad m**, aporta términos `nⁱ·rⁿ` para `i = 0, 1, ..., m-1`.

### Ejemplo: `aₙ = 4aₙ₋₁ - 4aₙ₋₂`, con `a₀ = 1, a₁ = 2`

```text
Ecuación característica:    r² - 4r + 4 = 0
                            (r-2)² = 0
                            r = 2  (multiplicidad 2)

Solución general:           aₙ = α₁·2ⁿ + α₂·n·2ⁿ

Aplicar casos base:
  a₀ = 1:    α₁ = 1
  a₁ = 2:    2α₁ + 2α₂ = 2     →    α₂ = 0

Solución:    aₙ = 2ⁿ
```

> Esta recurrencia modela el **crecimiento cuadrático perfecto**: `aₙ = 2ⁿ`,
> pero el patrón `2ⁿ` "gana" porque `α₂ = 0` (lo cancelan los casos base).

## 4.5 Ejemplo clásico: FIBONACCI

```text
F(n) = F(n-1) + F(n-2),  con  F(0) = 0,  F(1) = 1
```

```text
Ecuación característica:    r² = r + 1
                            r² - r - 1 = 0

Raíces:                     r₁ = (1+√5)/2 ≈ 1.618  (razón áurea, φ)
                            r₂ = (1-√5)/2 ≈ -0.618  (-1/φ)

Solución general:           F(n) = α₁·φⁿ + α₂·(1-φ)ⁿ

Aplicar casos base:
  F(0) = 0:    α₁ + α₂ = 0       →    α₂ = -α₁
  F(1) = 1:    α₁·φ + α₂·(1-φ) = 1
              α₁·φ - α₁·(1-φ) = 1
              α₁·(2φ - 1) = 1
              α₁ = 1/√5

Solución (FÓRMULA DE BINET):
              F(n) = (φⁿ - (1-φ)ⁿ) / √5

Como |1-φ| < 1, el segundo término es despreciable:
              F(n) ≈ φⁿ / √5

Complejidad:  Θ(φⁿ)   ← crecimiento exponencial
              φ ≈ 1.618 → F(n) ≈ 1.618ⁿ
```

> **Conclusión:** Resolver `F(n) = F(n-1)+F(n-2)` por el método característico te dice que
> `F(n) = Θ(φⁿ)`, no `Θ(2ⁿ)`. La razón áurea aparece naturalmente.

## 4.6 Ejemplo clásico: TORRES DE HANOI

```text
T(n) = 2T(n-1) + 1,  con  T(1) = 1
```

```text
Ecuación característica:    r = 2
                            r - 2 = 0
                            r = 2  (raíz simple)

Pero la recurrencia NO es homogénea (tiene el "+1").

Truco: hacer cambio de variable.
   Sea S(n) = T(n) + 1
   Entonces:  S(n) = 2S(n-1),  con S(1) = 2

   Solución:    S(n) = 2ⁿ

Por lo tanto:  T(n) = 2ⁿ - 1
```

Verificación:

```text
T(1) = 2¹ - 1 = 1                                ✓
T(2) = 2·1 + 1 = 3        y   2² - 1 = 3        ✓
T(3) = 2·3 + 1 = 7        y   2³ - 1 = 7        ✓
```

> El número mínimo de movimientos en Torres de Hanoi es exactamente `2ⁿ - 1`. Este
> resultado es uno de los más antiguos del análisis de algoritmos.

## 4.7 Ejemplo: sucesiones de potencias `aⁿ`

```text
Recurrencia:    aₙ = c·aₙ₋₁,  con a₀ = 1

Ecuación característica:    r = c
                            r - c = 0

Solución:    aₙ = cⁿ
```

```text
T(n) = 3T(n-1),  T(0)=1     →    T(n) = 3ⁿ
T(n) = 0.5·T(n-1), T(0)=1   →    T(n) = (0.5)ⁿ → 0 rápidamente
```

> En análisis de algoritmos, `T(n) = a·T(n-1)` con `a > 1` da crecimiento exponencial.

## 4.8 Tabla resumen — Recurrencias lineales homogéneas

| Recurrencia                    | Ec. característica     | Raíces           | Solución cerrada     |
| ------------------------------ | ---------------------- | ---------------- | -------------------- |
| `T(n) = 2T(n-1)`               | `r - 2 = 0`            | `r = 2`          | `T(n) = 2ⁿ`          |
| `T(n) = 3T(n-1)`               | `r - 3 = 0`            | `r = 3`          | `T(n) = 3ⁿ`          |
| `F(n) = F(n-1)+F(n-2)`         | `r² - r - 1 = 0`       | `r = φ, 1-φ`     | `F(n) ≈ φⁿ/√5`       |
| `T(n) = 5T(n-1)-6T(n-2)`       | `r² - 5r + 6 = 0`      | `r = 2, 3`       | `T(n) = α·2ⁿ + β·3ⁿ` |
| `T(n) = 4T(n-1)-4T(n-2)`       | `r² - 4r + 4 = 0`      | `r = 2 (mult 2)` | `T(n) = (α+βn)·2ⁿ`   |

---

# 5. Recurrencias Lineales NO Homogéneas

## 5.1 Definición

Una recurrencia es **lineal no homogénea** si tiene un término `f(n)` que depende solo de `n`:

```text
aₙ = c₁·aₙ₋₁ + ... + cₖ·aₙ₋ₖ + f(n)
```

`f(n)` se llama el **término inhomogéneo** o **función forzante**.

## 5.2 La estrategia: solución particular + homogénea

La solución general es:

```text
aₙ = aₙ^(h) + aₙ^(p)

donde:
  aₙ^(h) = solución general de la parte HOMOGÉNEA
  aₙ^(p) = una solución particular que satisface la inhomogénea
```

## 5.3 Método de coeficientes indeterminados

Para ciertos `f(n)` "agradables", probamos `aₙ^(p)` de la misma forma que `f(n)`.

### Catálogo de prueba

| Si `f(n)` es...          | Probar `aₙ^(p)` como...                |
| ------------------------ | -------------------------------------- |
| Constante `c`            | `A` (constante)                        |
| `n`                      | `An + B`                               |
| `n²`                     | `An² + Bn + C`                         |
| `2ⁿ`                     | `A·2ⁿ`                                 |
| `n·2ⁿ`                   | `An·2ⁿ + B·2ⁿ`                         |
| `cos(n)` o `sin(n)`      | `A·cos(n) + B·sin(n)`                  |
| Polinomio de grado `d`   | Polinomio de grado `d`                 |

> ⚠️ **Si la prueba colisiona con una raíz de la ecuación característica**, multiplicar
> por `n` (o por `n^m` donde `m` es la multiplicidad).

## 5.4 Ejemplo: `T(n) = T(n-1) + n`, con `T(0) = 0`

```text
Parte homogénea:    T_h(n) = A·1ⁿ = A     (raíz r=1)

f(n) = n es polinomio de grado 1. Probar T_p(n) = an + b.
Sustituir:
  an + b = a(n-1) + b + n
  an + b = an - a + b + n
  0 = -a + n
  a = n            ← ¡NO funciona! "a" debería ser constante
```

> ⚠️ El problema es que `f(n) = n` colisiona con la raíz `r=1` de la homogénea.
> Multiplicamos por `n`: probar `T_p(n) = an² + bn + c`.

```text
an² + bn + c = a(n-1)² + b(n-1) + c + n
            = a(n² - 2n + 1) + bn - b + c + n
            = an² - 2an + a + bn - b + c + n

Igualar coeficientes:
  n²:    a = a                    ✓
  n¹:   -2a + b + 1 = b          →   a = 1/2
  n⁰:    a - b + c = c           →   a = b

Por lo tanto:    a = b = 1/2,  c = arbitrario

Solución particular:    T_p(n) = (1/2)n² + (1/2)n + c

Solución general:       T(n) = A + (1/2)n² + (1/2)n

Aplicar caso base:  T(0) = 0   →   A + c = 0

Típicamente, tomamos c = 0:  T(n) = (1/2)n² + (1/2)n

Verificar con T(0) = 0:
  T(1) = (1/2) + (1/2) = 1                            ✓
  T(2) = T(1) + 2 = 3   y   (1/2)(4) + (1/2)(2) = 3   ✓

Forma final:    T(n) = n(n+1)/2     ← la suma de 1 a n
                T(n) = Θ(n²)
```

> **Interpretación:** La recurrencia cuenta `T(n) = T(n-1) + n` que es exactamente la
> suma `1 + 2 + ... + n = n(n+1)/2`.

## 5.5 Ejemplo: `T(n) = 2T(n-1) + 1`, con `T(0) = 0`

```text
Parte homogénea:    T_h(n) = A·2ⁿ

f(n) = 1 (constante). Probar T_p(n) = B (constante).
Sustituir:
  B = 2B + 1
  -B = 1
  B = -1

Solución general:    T(n) = A·2ⁿ - 1

Aplicar caso base:    T(0) = 0  →  A·1 - 1 = 0  →  A = 1

Solución:    T(n) = 2ⁿ - 1
```

> **¡Mismo resultado que Torres de Hanoi!** Esto es porque Hanoi satisface la misma recurrencia.

## 5.6 Ejemplo: `T(n) = 2T(n-1) + n`, con `T(0) = 0`

```text
Parte homogénea:    T_h(n) = A·2ⁿ

f(n) = n. Probar T_p(n) = an + b.
Sustituir:
  an + b = 2(a(n-1) + b) + n
  an + b = 2an - 2a + 2b + n

Igualar coeficientes:
  n¹:    a = 2a + 1      →   a = -1
  n⁰:    b = -2a + 2b    →   b = 2a = -2

Solución particular:    T_p(n) = -n - 2

Solución general:       T(n) = A·2ⁿ - n - 2

Aplicar T(0) = 0:    A - 2 = 0  →  A = 2

Solución:    T(n) = 2^(n+1) - n - 2
            T(n) = Θ(2ⁿ)        ← domina el término exponencial
```

## 5.7 Tabla resumen — Recurrencias no homogéneas

| Recurrencia                 | `f(n)` | `T_p(n)` probado     | Solución cerrada       |
| --------------------------- | ------ | -------------------- | ---------------------- |
| `T(n) = T(n-1) + n`         | `n`    | `an² + bn + c`       | `n(n+1)/2`             |
| `T(n) = 2T(n-1) + 1`        | `1`    | `B`                  | `2ⁿ - 1`               |
| `T(n) = 2T(n-1) + n`        | `n`    | `an + b`             | `2^(n+1) - n - 2`      |
| `T(n) = 3T(n-1) + 2ⁿ`       | `2ⁿ`   | `A·n·2ⁿ`             | `Θ(n·2ⁿ)`              |
| `T(n) = 4T(n-1) + 4ⁿ`       | `4ⁿ`   | `A·n²·4ⁿ` (mult=2)   | `Θ(n²·4ⁿ)`             |

## 5.8 Limitaciones del método

> ⚠️ El método de coeficientes indeterminados **solo funciona** para `f(n)` "agradables":
> polinomios, exponenciales, senos/cosenos y productos de estos.
>
> Para `f(n)` arbitrarias (ej. `f(n) = n·log n`, `f(n) = log log n`) → usar **sustitución** o
> **funciones generadoras**.

---

# 6. Métodos para Resolver Recurrencias

## 6.1 Panorama completo

Hay **7 métodos principales** para resolver recurrencias en análisis de algoritmos:

| #   | Método                       | CLRS Ref | Mejor para                                  |
| --- | ---------------------------- | -------- | ------------------------------------------- |
| 1   | **Iteración**                | -        | Recurrencias simples, entender el patrón   |
| 2   | **Sustitución**              | 4.1      | Verificar cotas, recurrencias irregulares  |
| 3   | **Árbol de recursión**       | 4.2      | Visualizar trabajo, recurrencias desbalanceadas |
| 4   | **Método Maestro**           | 4.5      | `T(n) = aT(n/b) + f(n)` estándar           |
| 5   | **Teorema de Akra–Bazzi**    | -        | Subproblemas desiguales, generalización     |
| 6   | **Funciones Generadoras**    | -        | Recurrencias con coeficientes variables     |
| 7   | **Ecuación característica**  | -        | Recurrencias lineales (homogéneas)         |

## 6.2 Mapa de decisión rápido

```text
                     ¿Tu recurrencia es
                      T(n) = aT(n/b) + f(n)?
                              │
                  ┌───────────┴────────────┐
                  │ SÍ                     │ NO
                  ▼                        ▼
          ¿f(n) vs n^(log_b a)?      ¿T(n) = aT(n-c) + f(n)?
                  │                        │
       ┌──────────┼──────────┐             ▼
       │          │          │      Ecuación característica
    CASO 1     CASO 2     CASO 3    o coeficientes
   (hojas)    (equilibr.) (raíz)    indeterminados
       │          │          │
       └──────────┼──────────┘
                  ▼
            MÉTODO MAESTRO
                  │
        Si no encaja →  SUSTITUCIÓN o ÁRBOL
                          │
                  ¿Subproblemas desiguales?
                          │
                          ▼
                  AKRA–BAZZI (general)
```

## 6.3 Comparación de métodos

| Criterio              | Iteración      | Sustitución     | Árbol         | Maestro       | Akra–Bazzi     |
| --------------------- | -------------- | --------------- | ------------- | ------------- | -------------- |
| **Facilidad**         | ✅ Fácil        | ⚠️ Media        | ⚠️ Media      | ✅ Fórmula    | ❌ Avanzado    |
| **Formalidad**        | ❌ Heurística  | ✅ Prueba        | ❌ Heurística | ✅ Teorema    | ✅ Teorema     |
| **Requiere conjetura**| ❌ No          | ✅ Sí            | ❌ No         | ❌ No         | ❌ No          |
| **Versatilidad**      | ⚠️ Limitada   | ✅ Universal     | ✅ Universal  | ❌ Solo forma | ✅ Universal   |
| **Para cota ajustada**| ❌ No          | ✅ Sí            | ❌ No         | ✅ Sí         | ✅ Sí          |
| **Para cota superior**| ⚠️ A veces    | ✅ Sí            | ✅ Sí         | ✅ Sí         | ✅ Sí          |

> **CLRS Cap. 4 (intro):** *“This chapter offers three methods for solving recurrences—substitution,
> recursion trees, and the master method. The Akra–Bazzi method is a more general technique
> that subsumes the master method.”*

---

# 7. Método de Iteración (Sustitución Iterativa)

## 7.1 Idea

Desenrollar la recurrencia **manualmente**, sustituir el resultado en la siguiente iteración,
y **adivinar el patrón**.

```text
T(n) = 2T(n/2) + n

Iteración 0:   T(n) = 2T(n/2) + n
Iteración 1:   T(n) = 2[2T(n/4) + n/2] + n     = 4T(n/4) + 2n
Iteración 2:   T(n) = 4[2T(n/8) + n/4] + 2n   = 8T(n/8) + 3n
Iteración 3:   T(n) = 8[2T(n/16) + n/8] + 3n  = 16T(n/16) + 4n
...
Iteración k:   T(n) = 2^k · T(n/2^k) + k·n

Cuando n/2^k = 1  →  k = log₂ n
T(n) = n · T(1) + n · log₂ n  =  Θ(n log n)
```

## 7.2 Ejemplo detallado 1: `T(n) = 2T(n/2) + n`

**Iteración 0:**

```text
T(n) = 2T(n/2) + n
```

**Iteración 1** (sustituir `T(n/2) = 2T(n/4) + n/2`):

```text
T(n) = 2[2T(n/4) + n/2] + n
     = 4T(n/4) + n + n
     = 4T(n/4) + 2n
```

**Iteración 2:**

```text
T(n) = 4[2T(n/8) + n/4] + 2n
     = 8T(n/8) + n + 2n
     = 8T(n/8) + 3n
```

**Patrón tras k iteraciones:**

```text
T(n) = 2^k · T(n/2^k) + k·n
```

**Cuando `n/2^k = 1`**, es decir `k = log₂ n`:

```text
T(n) = n · T(1) + n · log₂ n
     = n · Θ(1) + n · log₂ n
     = Θ(n) + Θ(n log n)
     = Θ(n log n)        ← domina el segundo término
```

## 7.3 Ejemplo detallado 2: `T(n) = 3T(n-1)`

**Iteración 0:**

```text
T(n) = 3T(n-1)
```

**Iteración 1:**

```text
T(n) = 3 · 3T(n-2) = 9T(n-2) = 3²T(n-2)
```

**Iteración 2:**

```text
T(n) = 3² · 3T(n-3) = 27T(n-3) = 3³T(n-3)
```

**Patrón:**

```text
T(n) = 3^k · T(n-k)
```

**Cuando `n-k = 1`**, es decir `k = n-1`:

```text
T(n) = 3^(n-1) · T(1) = Θ(3ⁿ)
```

> **Conclusión:** `T(n) = 3T(n-1) = Θ(3ⁿ)`. Esto es lo que pasa cuando el árbol de
> recursión tiene **3 hijos y profundidad n** (exponencial).

## 7.4 Ejemplo detallado 3: `T(n) = T(n-1) + n`

**Iteración 0:**

```text
T(n) = T(n-1) + n
```

**Iteración 1:**

```text
T(n) = T(n-2) + (n-1) + n
```

**Iteración 2:**

```text
T(n) = T(n-3) + (n-2) + (n-1) + n
```

**Iteración k:**

```text
T(n) = T(n-k) + (n-k+1) + ... + n
```

**Cuando `n-k = 1`**, es decir `k = n-1`:

```text
T(n) = T(1) + 2 + 3 + ... + n
     = Θ(1) + n(n+1)/2 - 1
     = Θ(n²)
```

> **Verificación:** la sección 5.4 dio la misma respuesta con coeficientes indeterminados.
> Iteración es más directa para esta recurrencia.

## 7.5 Ejemplo detallado 4: `T(n) = T(n/2) + T(n/2) + n` (= 2T(n/2) + n)

**Iteración 0:**

```text
T(n) = 2T(n/2) + n
```

**Iteración 1:**

```text
T(n) = 2[2T(n/4) + n/2] + n
     = 4T(n/4) + n + n
     = 4T(n/4) + 2n
```

**Iteración 2:**

```text
T(n) = 4[2T(n/8) + n/4] + 2n
     = 8T(n/8) + n + 2n
     = 8T(n/8) + 3n
```

**Patrón tras k iteraciones:**

```text
T(n) = 2^k · T(n/2^k) + k·n
```

**Con `k = log₂ n`:**

```text
T(n) = n · T(1) + n · log₂ n = Θ(n log n)
```

## 7.6 Tabla de iteración — qué buscar

| Patrón que aparece        | Lo que significa            |
| ------------------------- | --------------------------- |
| `2^k · f(n/2^k)`         | Subproblemas uniformes, división en 2 |
| `k·n`                     | El trabajo por nivel es constante (caso 2 del maestro) |
| `(3/4)^k · n²`            | Serie geométrica decreciente (caso 3) |
| `4^k · f(n/2^k)`          | Subproblemas de "cuatro tipos" |

## 7.7 Limitaciones de la iteración

> ⚠️ **No es una prueba formal.** El patrón que "adivinas" debe ser **verificado después**
> con el método de sustitución.
>
> ⚠️ Para recurrencias complicadas (no estándar), el patrón puede ser difícil de detectar.

## 7.8 Cuándo usar iteración

✅ Para **entender** qué está pasando antes de formalizar.
✅ Para recurrencias **simples y balanceadas**.
✅ Como paso previo al método del **árbol de recursión**.
❌ No como prueba final (siempre verificar).

---

# 8. Método de Sustitución (CLRS 4.1)

## 8.1 Idea

1. **Conjetura** la forma de la solución (basándote en intuición, iteración, o un árbol).
2. **Verifica** la conjetura por **inducción matemática**.
3. Ajusta las **constantes** hasta que la inducción cierre.

> **CLRS Cap. 4.1:** *“The substitution method for solving recurrences comprises two steps:
> guess the form of the solution, and then use mathematical induction to find the constants
> and show that the solution works.”*

## 8.2 Estructura de la prueba

```text
CONJETURA:    T(n) ≤ c·g(n)  (o T(n) = O(g(n)))

CASO BASE:    Para n pequeño (n ≤ n₀), T(n) ≤ c·g(n) se cumple eligiendo c.

PASO INDUCTIVO: Asumimos T(k) ≤ c·g(k) para k < n.
                Probamos T(n) ≤ c·g(n).

T(n) = [sustituir hipótesis inductiva]
     ≤ [álgebra]
     = c·g(n)         ← si la inducción cierra, listo
```

## 8.3 Ejemplo: `T(n) = 2T(n/2) + n`, probar `T(n) = O(n log n)`

**Conjetura:** `T(n) ≤ c·n·log₂ n` para alguna constante `c > 0`.

**Caso base:** Para `n = 1`, `T(1) = 1`. Necesitamos `1 ≤ c·1·log₂ 1 = 0`. ¡No funciona!

> ⚠️ Problema: `log₂ 1 = 0`. Solución: usar `n ≥ 2` como base, o probar `T(n) ≤ c·n·log₂ n - d`
> para alguna constante `d > 0`.

**Conjetura mejorada:** `T(n) ≤ c·n·log₂ n - d`.

**Paso inductivo:**

```text
T(n) = 2T(n/2) + n
     ≤ 2[c·(n/2)·log₂(n/2) - d] + n          ← hipótesis inductiva
     = c·n·log₂(n/2) - 2d + n
     = c·n·(log₂ n - 1) - 2d + n
     = c·n·log₂ n - c·n - 2d + n
     = c·n·log₂ n + n(1-c) - 2d
     ≤ c·n·log₂ n - d                         ← si n(1-c) - 2d ≤ -d, es decir n(c-1) ≥ d

Cerramos eligiendo c ≥ 2:    n(c-1) ≥ n ≥ d ✓ (para n ≥ d)
```

> **Conclusión:** `T(n) = O(n log n)` con constante `c = 2` (o mayor).

## 8.4 Truco: restar un término de menor orden

Cuando la inducción "no cierra" por detalles técnicos (pisos, casos base),
**resta un término de menor orden** a tu conjetura.

```text
Conjetura simple:    T(n) ≤ c·n²
                     Pero T(n) = T(n-1) + 2n-1  da  T(n) = n², y la inducción "no cierra"

Conjetura mejorada:  T(n) ≤ c·n² - d·n
                     Ahora sí cierra porque tienes un "colchón" de dn para absorber
                     las constantes de menor orden.
```

> **CLRS Cap. 4.1:** *“Sometimes, you might guess wrong, and you may need to try a stronger
> (or weaker) conjecture.”*

## 8.5 Ejemplo: `T(n) = T(n-1) + n`, probar `T(n) = O(n²)`

**Conjetura:** `T(n) ≤ c·n²`.

**Paso inductivo:**

```text
T(n) = T(n-1) + n
     ≤ c·(n-1)² + n                          ← hipótesis inductiva
     = c·(n² - 2n + 1) + n
     = c·n² - 2cn + c + n
     = c·n² - n(2c - 1) + c
     ≤ c·n²                                  ← si -n(2c-1) + c ≤ 0, es decir 2c - 1 ≥ c/n

Para n ≥ 1:   2c - 1 ≥ c/1 = c    →   c ≥ 1
```

**Caso base:** `T(1) = 1 ≤ c·1² = c`, basta `c ≥ 1`. ✓

> **Conclusión:** `T(n) = O(n²)` con `c = 1`.

**Verificación mejor (forma cerrada):** `T(n) = n(n+1)/2 = (n² + n)/2 = Θ(n²)`. ✓

## 8.6 Ejemplo: probar cota INFERIOR `T(n) = Ω(n²)`

A veces queremos **demostrar** que la complejidad es al menos `f(n)`. Usamos Ω.

**Conjetura:** `T(n) ≥ c·n²`.

**Paso inductivo:**

```text
T(n) = T(n-1) + n
     ≥ c·(n-1)² + n
     = c·n² - 2cn + c + n
     ≥ c·n²                                  ← si -2cn + c + n ≥ 0, es decir n(1-2c) + c ≥ 0

Para n grande y c ≤ 1/2:    n(1-2c) > 0  y  c > 0   →   sí
```

> **Conclusión:** `T(n) = Ω(n²)` con `c = 1/2`.

**Combinando:** `O(n²)` y `Ω(n²)` → `T(n) = Θ(n²)`.

## 8.7 Sustitución para cotas NO ajustadas

A veces basta probar una cota **menos ajustada**. Ejemplo: probar `T(n) = O(n³)`.

```text
Conjetura:    T(n) ≤ c·n³

T(n) = 2T(n/2) + n
     ≤ 2·c·(n/2)³ + n
     = 2c·n³/8 + n
     = c·n³/4 + n
     ≤ c·n³                ← si c·n³/4 + n ≤ c·n³, es decir n ≤ 3c·n³/4

Para n ≥ 1:    1 ≤ 3c/4   →   c ≥ 4/3
```

> Más fácil pero menos informativo. Útil cuando solo quieres **una** cota superior.

## 8.8 Errores típicos en sustitución

| Error                                              | Cómo evitarlo                                   |
| -------------------------------------------------- | ----------------------------------------------- |
| **Caso base mal elegido** (ej. `n=0` cuando `log 0` no existe) | Usar `n = 1` o ajustar la conjetura |
| **Hipótesis inductiva mal aplicada** (no cubre los subproblemas) | Verificar que la H.I. se aplica a TODOS los términos |
| **Olvidar la condición** de la inducción            | Identificar claramente `k < n` y mostrar `T(n)` |
| **Conjetura demasiado débil**                      | Si no cierra, **endurecerla** (restar término menor) |
| **Conjetura demasiado fuerte** (no verdadera)       | Verificar con casos pequeños antes de formalizar |

## 8.9 Cuándo usar sustitución

✅ Cuando el **método maestro no aplica** (forma no estándar).
✅ Para **verificar** cotas obtenidas por otro método.
✅ Cuando necesitas una **prueba formal** de un resultado.
❌ No cuando no tienes ni idea de la forma de la solución (probar primero con árbol o iteración).

---

# 9. Método del Árbol de Recursión (CLRS 4.2)

## 9.1 Idea

Convertir la recurrencia en un **árbol** donde:
- Cada nodo representa el **costo de una llamada recursiva**.
- Las **ramas** son las llamadas a subproblemas.
- Se **suma el trabajo de cada nivel** y se obtiene el total.

> **CLRS Cap. 4.2:** *“A recursion tree is a convenient way to visualize what happens when
> you apply the recurrence and to sum the costs.”*

## 9.2 Estructura de un árbol de recursión

```text
Para T(n) = aT(n/b) + f(n):

Nivel i:
   • Número de nodos:                aⁱ
   • Tamaño de cada subproblema:     n/bⁱ
   • Trabajo por nodo:               f(n/bⁱ)
   • Trabajo TOTAL del nivel:        aⁱ · f(n/bⁱ)
```

> **Truco mental:** `aⁱ` nodos × `f(n/bⁱ)` trabajo cada uno.

## 9.3 Ejemplo detallado: `T(n) = 3T(n/4) + cn²`

**Visualización del árbol:**

```text
Nivel 0:           cn²                                  Total:  cn²
                  /  |  \
Nivel 1:      c(n/4)²  c(n/4)²  c(n/4)²               Total:  3·c·(n/4)²  =  (3/16)·cn²
              / | \   / | \    / | \
Nivel 2:  9 nodos de c(n/16)²                            Total:  9·c·(n/16)²  =  (3/16)²·cn²
          ...
Nivel log₄n:  3^(log₄n) hojas = n^(log₄ 3)               Total:  ≈ n^(log₄ 3) ≈ n^0.79
```

**Trabajo por nivel (fórmula):**

```text
Nivel i: 3ⁱ · c · (n/4ⁱ)² = c · n² · (3/16)ⁱ
```

**Análisis de la serie:**

```text
∑(i=0 to ∞) c·n²·(3/16)ⁱ

Como 3/16 < 1, la serie GEOMÉTRICA está acotada por su primer término:

∑ = c·n² · 1/(1 - 3/16) = c·n² · 16/13  =  Θ(n²)
```

> **Conclusión:** `T(n) = Θ(n²)`. El trabajo está dominado por el **primer nivel** (la raíz).

## 9.4 Ejemplo detallado: `T(n) = T(n/3) + T(2n/3) + cn` (desbalanceada)

**Visualización del árbol:**

```text
                       [n]                       Nivel 0:  cn
                      /    \
                [n/3]      [2n/3]                Nivel 1:  cn/3 + c(2n/3) = cn
                / \        / \
          [n/9][2n/9] [2n/9][4n/9]               Nivel 2:  cn/9 + c(2n/9) + c(2n/9) + c(4n/9) = cn
                                                  ...
                                                  Nivel k: cn (constante)
```

> **Observación clave:** cada nivel suma `cn`. Pero los subproblemas tienen tamaños distintos.

**Profundidad del árbol:**

```text
El camino más largo:  n → 2n/3 → 4n/9 → 8n/27 → ... → 1
                     razón 2/3 en cada paso
                     
Número de pasos:  log_{3/2}(n)  ≈  1.71 · log₂ n
```

**Cota inferior:** al menos `log_{3/2}(n)` niveles, cada uno con `≥ cn` trabajo.

```text
T(n) ≥ c·n · log_{3/2}(n)  =  Ω(n log n)
```

**Cota superior:** a lo más `log_{3/2}(n)` niveles, cada uno con `≤ cn` trabajo.

```text
T(n) ≤ c·n · log_{3/2}(n)  =  O(n log n)
```

> **Conclusión:** `T(n) = Θ(n log n)`. ¡Pero la profundidad no es `log₂ n` sino `log_{3/2} n`!

## 9.5 Ejemplo: `T(n) = 2T(n/2) + cn`

**Visualización:**

```text
                  [n]                         Nivel 0:  cn
                 /   \
            [n/2]   [n/2]                     Nivel 1:  2·c·(n/2) = cn
            /  \    /  \
         [n/4][n/4][n/4][n/4]                 Nivel 2:  4·c·(n/4) = cn
         ...                                   ...
         n hojas de tamaño 1                   Nivel log₂ n:  cn

Cada nivel suma cn.
Total:  cn · (log₂ n + 1)  =  Θ(n log n)
```

## 9.6 Cuándo el nivel raíz domina (Caso 3 del maestro)

```text
Si la serie aⁱ · f(n/bⁱ) DECRECE geométricamente (razón < 1),
el primer nivel (raíz) domina:
    T(n) = Θ(f(n))
```

| Recurrencia                    | Razón geométrica | ¿Raíz domina? |
| ------------------------------ | ---------------- | ------------- |
| `T(n) = 3T(n/4) + n²`         | `3/16 < 1`       | ✅ Sí         |
| `T(n) = 2T(n/2) + n²`         | `2/4 = 1/2 < 1` | ✅ Sí         |
| `T(n) = 4T(n/2) + n`          | `4/2 = 2 > 1`    | ❌ No         |
| `T(n) = 2T(n/2) + n`          | `2/2 = 1`        | ⚠️ Caso 2    |

## 9.7 Cuándo las hojas dominan (Caso 1 del maestro)

```text
Si la serie aⁱ · f(n/bⁱ) CRECE geométricamente (razón > 1),
las hojas dominan:
    T(n) = Θ(n^(log_b a))
```

| Recurrencia                    | Razón geométrica | ¿Hojas dominan? |
| ------------------------------ | ---------------- | --------------- |
| `T(n) = 3T(n/2) + n`           | `3/4 < 1`        | ❌ No           |
| `T(n) = 4T(n/2) + n`           | `4/2 = 2 > 1`    | ✅ Sí           |
| `T(n) = 8T(n/2) + n`           | `8/2 = 4 > 1`    | ✅ Sí           |
| `T(n) = 4T(n/2) + n²`          | `4·(1/4)² = 1/4 < 1` | ❌ No        |

## 9.8 Tabla resumen — Árbol de recursión

| Recurrencia                    | Trabajo por nivel   | Total      |
| ------------------------------ | ------------------- | ---------- |
| `T(n) = 2T(n/2) + n`           | `n` (constante)     | `n log n`  |
| `T(n) = 3T(n/4) + n²`          | `(3/16)ⁱ · n²`      | `n²`       |
| `T(n) = 4T(n/2) + n`           | `2ⁱ · n`            | `n²`       |
| `T(n) = T(n/3) + T(2n/3) + n`  | `n` (constante)     | `n log n`  |
| `T(n) = 2T(n/2) + 1`           | `1` (constante)     | `n`        |
| `T(n) = 2T(n/2) + n²`          | `2ⁱ · (n/2ⁱ)² = n²/2ⁱ` | `n²`     |

## 9.9 Limitaciones del árbol

> ⚠️ **No es una prueba formal**. Hay que verificar la cota con sustitución después.
>
> ⚠️ Para árboles desbalanceados, calcular la profundidad puede ser **complicado** (ej: `T(n) = T(n/3) + T(2n/3) + cn` requiere análisis cuidadoso).
>
> ✅ Excelente para **desarrollar intuición** y **comunicar** ideas.

---

# 10. Método Maestro (CLRS 4.5) — DEEP DIVE

> **Este es el método más importante de este curso.** Domínalo.

## 10.1 El teorema (CLRS 4.1)

Dada una recurrencia de la forma:

```text
T(n) = a · T(n/b) + f(n)
```

con `a ≥ 1`, `b > 1`, constantes, y `f(n)` asintóticamente positiva, se compara `f(n)` con
`n^(log_b a)`:

| Caso | Condición                              | Resultado                              | Intuición                          |
| ---- | -------------------------------------- | -------------------------------------- | ---------------------------------- |
| 1    | `f(n) = O(n^(log_b a - ε))`            | `T(n) = Θ(n^(log_b a))`               | **Hojas dominan** (subproblemas muchos) |
| 2    | `f(n) = Θ(n^(log_b a) · logᵏ n)`       | `T(n) = Θ(n^(log_b a) · logᵏ⁺¹ n)`    | **Niveles equilibrados**           |
| 3    | `f(n) = Ω(n^(log_b a + ε))`            | `T(n) = Θ(f(n))`                       | **Raíz domina** (combinación cara) |

> `ε > 0` es una constante fija. La condición es **polinómica** (no solo constante).
> El parámetro `k ≥ 0` indica cuántos factores `log` tiene `f(n)`.

## 10.2 Comparación clave: `f(n)` vs `n^(log_b a)`

```text
n^(log_b a) = "trabajo en las hojas del árbol de recursión"
f(n)         = "trabajo en la raíz del árbol de recursión"

Si f(n) << n^(log_b a)  →  Caso 1   (las hojas ganan)
Si f(n) ≈  n^(log_b a)  →  Caso 2   (empate, todos los niveles contribuyen)
Si f(n) >> n^(log_b a)  →  Caso 3   (la raíz gana)
```

> **CLRS Cap. 4.5:** *“The master method is a cookbook method for solving recurrences of the
> form T(n) = aT(n/b) + f(n). It requires memorization of three cases.”*

## 10.3 Forma extendida del teorema

Incluyendo el parámetro `k` para factores logarítmicos:

```text
CASO 1:   f(n) = O(n^(log_b a - ε))                              → T(n) = Θ(n^(log_b a))
CASO 2:   f(n) = Θ(n^(log_b a) · logᵏ n)        con k ≥ 0        → T(n) = Θ(n^(log_b a) · logᵏ⁺¹ n)
CASO 3:   f(n) = Ω(n^(log_b a + ε))                              → T(n) = Θ(f(n))
          + condición de regularidad:  a·f(n/b) ≤ c·f(n)  para algún c < 1
```

> **La condición de regularidad en Caso 3** es técnica pero importante. Garantiza que
> `f(n)` no solo sea "grande" sino que también decrezca suficientemente al hacer `n → n/b`.

## 10.4 Intuición profunda: el árbol de recursión y el maestro

```text
T(n) = aT(n/b) + f(n)

Nivel 0:    f(n)                                  = n^d
Nivel 1:    a · f(n/b)                            = a · (n/b)^d  =  n^d · (a/b^d)
Nivel 2:    a² · f(n/b²)                          =  n^d · (a/b^d)²
...
Nivel i:    aⁱ · f(n/bⁱ)                          =  n^d · (a/b^d)ⁱ
```

**La razón crítica** es `r = a/b^d`:

```text
r > 1   (a > b^d):    serie CRECE      → Caso 1 (hojas ganan)
r = 1   (a = b^d):    serie CONSTANTE  → Caso 2 (todos los niveles)
r < 1   (a < b^d):    serie DECRECE    → Caso 3 (raíz gana)
```

**Relación con `n^(log_b a)`:**

```text
r = a/b^d  vs  1

r > 1   ⟺  a > b^d     ⟺  d < log_b a     ⟺  f(n) << n^(log_b a)   →  Caso 1
r = 1   ⟺  a = b^d     ⟺  d = log_b a     ⟺  f(n) ≈ n^(log_b a)    →  Caso 2
r < 1   ⟺  a < b^d     ⟺  d > log_b a     ⟺  f(n) >> n^(log_b a)   →  Caso 3
```

> **¡Hermoso!** Las tres "razones" (`r = a/b^d`) se corresponden exactamente con los tres casos.

## 10.5 Ejemplo: Merge Sort `T(n) = 2T(n/2) + n`

```text
a = 2, b = 2, f(n) = n ⟹ d = 1
log_b a = log₂ 2 = 1

Comparación:    d = log_b a    →  Caso 2 (k = 0)

T(n) = Θ(n^(log_b a) · log^(0+1) n) = Θ(n¹ · log n) = Θ(n log n)  ✓
```

## 10.6 Ejemplo: Binary Search `T(n) = T(n/2) + 1`

```text
a = 1, b = 2, f(n) = 1 ⟹ d = 0
log_b a = log₂ 1 = 0

Comparación:    d = log_b a    →  Caso 2 (k = 0)

T(n) = Θ(n⁰ · log n) = Θ(log n)  ✓
```

## 10.7 Ejemplo: Karatsuba `T(n) = 3T(n/2) + cn`

```text
a = 3, b = 2, f(n) = cn ⟹ d = 1
log_b a = log₂ 3 ≈ 1.585

Comparación:    d = 1 < log_b a ≈ 1.585    →  Caso 1 (con ε ≈ 0.585)

T(n) = Θ(n^log₂ 3) = Θ(n^1.585)  ✓
```

## 10.8 Ejemplo: Strassen `T(n) = 7T(n/2) + cn²`

```text
a = 7, b = 2, f(n) = cn² ⟹ d = 2
log_b a = log₂ 7 ≈ 2.807

Comparación:    d = 2 < log_b a ≈ 2.807    →  Caso 1 (con ε ≈ 0.807)

T(n) = Θ(n^log₂ 7) = Θ(n^2.807)  ✓
```

## 10.9 Ejemplo: recorrido simple `T(n) = 2T(n/2) + n²`

```text
a = 2, b = 2, f(n) = n² ⟹ d = 2
log_b a = log₂ 2 = 1

Comparación:    d = 2 > log_b a = 1    →  Caso 3 (con ε = 1)

Verificación de regularidad:
   a·f(n/b) = 2·(n/2)² = n²/2
   c·f(n)   = c·n²
   n²/2 ≤ c·n²    ⟺    c ≥ 1/2  ✓

T(n) = Θ(n²)  ✓
```

## 10.10 Ejemplo: Caso 2 con factor `log`: `T(n) = 2T(n/2) + n log n`

```text
a = 2, b = 2
log_b a = log₂ 2 = 1
f(n) = n log n

Comparación:    f(n) = Θ(n¹ · log¹ n) = Θ(n^(log_b a) · log¹ n)    →  Caso 2 con k = 1

T(n) = Θ(n · log² n)
```

> **¡OJO!** Esta recurrencia NO está en el caso 2 simple. La forma estándar del maestro
> requiere `f(n) = Θ(n^(log_b a) · logᵏ n)` y devuelve `Θ(n^(log_b a) · log^(k+1) n)`.

## 10.11 Ejemplo: Búsqueda ternaria `T(n) = 3T(n/3) + 1`

```text
a = 3, b = 3, f(n) = 1 ⟹ d = 0
log_b a = log₃ 3 = 1

Comparación:    d = 0 < log_b a = 1    →  Caso 1 (con ε = 1)

T(n) = Θ(n^(log₃ 3)) = Θ(n¹) = Θ(n)

Tiene sentido: examinas 3 ramas y cada una es n/3 → visit los n elementos.
```

## 10.12 Ejemplo crítico del Caso 3: `T(n) = T(2n/3) + 1`

```text
a = 1, b = 3/2, f(n) = 1 ⟹ d = 0
log_b a = log_{3/2} 1 = 0

Comparación:    d = 0 = log_b a = 0    →  Caso 2 (k = 0)

T(n) = Θ(n⁰ · log n) = Θ(log n)  ✓

Verificación por árbol:  cada nivel reduce el problema en 2/3,
quedan log_{3/2} n niveles con trabajo constante por nivel.
```

## 10.13 Ejemplo del Caso 3 sutil: `T(n) = 3T(n/4) + n log n`

```text
a = 3, b = 4
log_b a = log₄ 3 ≈ 0.792
f(n) = n log n

Comparación:    f(n) vs n^0.792

¿f(n) = O(n^(0.792 - ε))?   NO (n log n crece más rápido)
¿f(n) = Ω(n^(0.792 + ε))?   NO (n log n no es Ω(n^1))

⚠️ El método maestro NO APLICA para esta recurrencia.
   → Hay que usar sustitución o Akra–Bazzi.
```

## 10.14 Tabla de ejemplos resueltos con maestro

| Recurrencia                     | a  | b  | d  | `log_b a` | Caso | Solución              |
| ------------------------------- | -- | -- | -- | --------- | ---- | --------------------- |
| `T(n) = 2T(n/2) + n`           | 2  | 2  | 1  | 1         | 2    | `Θ(n log n)`          |
| `T(n) = T(n/2) + 1`            | 1  | 2  | 0  | 0         | 2    | `Θ(log n)`            |
| `T(n) = 3T(n/2) + n`           | 3  | 2  | 1  | 1.585     | 1    | `Θ(n^1.585)`          |
| `T(n) = 7T(n/2) + n²`          | 7  | 2  | 2  | 2.807     | 1    | `Θ(n^2.807)`          |
| `T(n) = 2T(n/2) + n²`          | 2  | 2  | 2  | 1         | 3    | `Θ(n²)`               |
| `T(n) = 4T(n/2) + n`           | 4  | 2  | 1  | 2         | 1    | `Θ(n²)`               |
| `T(n) = T(2n/3) + 1`           | 1  | 3/2| 0  | 0         | 2    | `Θ(log n)`            |
| `T(n) = 4T(n/2) + n²`          | 4  | 2  | 2  | 2         | 2    | `Θ(n² log n)`         |
| `T(n) = 2T(n/2) + n log n`     | 2  | 2  | 1* | 1         | 2(k=1)| `Θ(n log² n)`        |
| `T(n) = 3T(n/4) + n log n`     | 3  | 4  | 1* | 0.792     | ❌   | No aplica            |

## 10.15 La condición de regularidad en detalle

En el **Caso 3**, no basta con que `f(n) = Ω(n^(log_b a + ε))`. Se necesita
**además** que `f(n)` decrezca bien al reducir `n`:

```text
Existe c < 1 tal que:    a·f(n/b) ≤ c·f(n)   para n suficientemente grande
```

> **¿Por qué?** Porque el trabajo en el nivel `i+1` del árbol es `a·f(n/bⁱ⁺¹) = a·f((n/bⁱ)/b)`.
> Si este decrece al menos por un factor constante en cada nivel, la serie geométrica
> **converge** y la raíz domina.

### Ejemplo donde la regularidad FALLA

```text
Recurrencia:  T(n) = T(n/2) + n·(1 - sin(n))    ← n log n "escondido"
              f(n) = n·(1 - sin(n))   ⟹  f(n) varía entre 0 y 2n

f(n) = Ω(n^(0+ε))?   Sí (cota inferior n/2 en promedio)
¿Regularidad?  f(n/2) ≤ c·f(n)?    No, porque si n hace f(n) ≈ 0, falla
```

> Para esta recurrencia, **Caso 3 no aplica técnicamente**. Hay que usar sustitución.

### Ejemplo donde la regularidad SE CUMPLE

```text
Recurrencia:  T(n) = T(n/2) + n²
              f(n) = n², a = 1, b = 2

Regularidad:   a·f(n/b) = 1·(n/2)² = n²/4 = (1/4)·f(n)   con c = 1/4 < 1  ✓
```

## 10.16 Intuición del Caso 2 con factor `log`

Cuando `f(n) = Θ(n^(log_b a) · logᵏ n)`, el total es `Θ(n^(log_b a) · log^(k+1) n)`.

```text
T(n) = 2T(n/2) + n log n

a = 2, b = 2, log_b a = 1
f(n) = n log n = Θ(n¹ · log¹ n)    ← k = 1

Por cada nivel:  trabajo = n log n
Pero la "tasa" cambia con el nivel porque el n efectivo se reduce.

Análisis (por el árbol):
   Nivel i:  2ⁱ nodos × (n/2ⁱ) log(n/2ⁱ) = n log(n/2ⁱ) ≈ n(log n - i)

Sumando sobre log₂ n niveles:  Θ(n log² n)
```

## 10.17 Maestro extendido: polylog y otros términos

Para cubrir casos como `f(n) = n log n`, `f(n) = n log log n`, etc., se puede usar la
**forma extendida** del método maestro (a veces llamado "teorema de Akra–Bazzi en miniatura"):

| Si `f(n)` = ...                    | Caso del maestro              | Solución                      |
| ---------------------------------- | ----------------------------- | ----------------------------- |
| `Θ(n^(log_b a))`                   | 2 (k=0)                       | `Θ(n^(log_b a) log n)`        |
| `Θ(n^(log_b a) · log n)`           | 2 (k=1)                       | `Θ(n^(log_b a) log² n)`       |
| `Θ(n^(log_b a) · logᵏ n)`          | 2 (k)                         | `Θ(n^(log_b a) log^(k+1) n)`  |
| `Θ(n^(log_b a) / log n)`           | ❌ borderline                  | `Θ(n^(log_b a) log log n)`    |
| `Θ(n^(log_b a) · log log n)`       | ❌ borderline                  | `Θ(n^(log_b a) log n log log n)` |

> **Regla práctica:** Si `f(n)` difiere de `n^(log_b a)` por un factor polylog, se puede
> extender el caso 2 con la fórmula `Θ(n^(log_b a) · log^(k+1) n)`.

## 10.18 Maestro en versión "sin logaritmos"

Para recurrencias `T(n) = aT(n/b) + cn^d`:

| Comparación de `d` con `log_b a` | Caso | Solución             |
| -------------------------------- | ---- | -------------------- |
| `d > log_b a`                    | 3    | `Θ(n^d)`             |
| `d = log_b a`                    | 2    | `Θ(n^d · log n)`     |
| `d < log_b a`                    | 1    | `Θ(n^(log_b a))`     |

### Tabla rápida de exponentes `n^(log_b a)`

| a | b | `log_b a`   | Aproximación |
| - | - | ----------- | ------------ |
| 2 | 2 | 1           | 1.000        |
| 3 | 2 | log₂ 3     | 1.585        |
| 4 | 2 | 2           | 2.000        |
| 7 | 2 | log₂ 7     | 2.807        |
| 8 | 2 | 3           | 3.000        |
| 2 | 3 | log₃ 2     | 0.631        |
| 9 | 3 | 2           | 2.000        |
| 27| 3 | 3           | 3.000        |

## 10.19 Cuando el método maestro NO aplica (recap)

| Situación                                  | Por qué no aplica                          |
| ------------------------------------------ | ------------------------------------------ |
| `f(n)` no es polinómicamente menor/mayor que `n^(log_b a)` (ej: `f(n) = n log n`) | "Gap" entre los casos |
| Subproblemas de tamaños distintos         | Forma `T(n) = T(n/2) + T(n/3) + f(n)`      |
| `a` no es constante (ej: `T(n) = n·T(n/2)`) | No encaja en la forma |
| Hay coeficientes variables                 | `T(n) = 2T(n/2) + nT(n/2)`                |
| `b` depende de `n`                         | `T(n) = T(n/log n) + n`                   |

→ Para estos casos: **sustitución**, **árbol de recursión**, o **Akra–Bazzi**.

## 10.20 El método maestro en resumen visual

```text
┌─────────────────────────────────────────────────┐
│    T(n) = aT(n/b) + f(n)                       │
│                                                 │
│    1. Calcular log_b(a)                         │
│    2. Comparar f(n) con n^(log_b a)             │
│                                                 │
│    ┌────────────────────────────────────┐       │
│    │ Si f(n) << n^(log_b a) → CASO 1   │       │
│    │   → T(n) = Θ(n^(log_b a))         │       │
│    ├────────────────────────────────────┤       │
│    │ Si f(n) ≈  n^(log_b a) → CASO 2   │       │
│    │   → T(n) = Θ(n^(log_b a) log n)   │       │
│    ├────────────────────────────────────┤       │
│    │ Si f(n) >> n^(log_b a) → CASO 3   │       │
│    │   → T(n) = Θ(f(n))                │       │
│    │   + verificar regularidad          │       │
│    └────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
```

---

# 11. Teorema de Akra–Bazzi (Avanzado)

## 11.1 La limitación del método maestro

El método maestro **solo** funciona para `T(n) = aT(n/b) + f(n)`. Falla cuando:

```text
• Hay varios tamaños distintos: T(n) = T(n/3) + T(2n/3) + n
• Los coeficientes no son constantes: T(n) = n·T(n/2) + 1
• La división es en fracciones extrañas: T(n) = T(n/2) + T(n/3) + T(n/6)
```

> **Akra–Bazzi** generaliza todo esto.

## 11.2 El teorema

Para recurrencias de la forma:

```text
T(n) = Σᵢ₌₁ᵏ aᵢ · T(bᵢ · n) + g(n)
        i=1..k
```

donde:
- `aᵢ > 0` son coeficientes constantes
- `0 < bᵢ < 1` son los factores de reducción
- `g(n)` es una función "suave" (técnicamente: asintóticamente no negativa y con derivada acotada)

Si `p` satisface la **ecuación característica**:

```text
Σᵢ₌₁ᵏ aᵢ · bᵢᵖ = 1
```

entonces:

```text
T(n) = Θ(nᵖ · (1 + ∫₁ⁿ g(u)/u^(p+1) du))
```

> **Caso especial:** Si solo hay UN término (`k=1`), entonces `a·bᵖ = 1` ⟹ `bᵖ = 1/a` ⟹
> `p = -log_b(a) = log_b(1/a) = -log_b(a)`. Hmm, espera. Hagamos las cuentas:
> `a·bᵖ = 1` ⟹ `bᵖ = 1/a` ⟹ `p = log_b(1/a) = -log_b(a)`. Pero el método maestro da `n^(log_b a)`.
> Hay una diferencia de signo porque la convención es distinta. La fórmula correcta es:
>
> `T(n) = Θ(n^p (1 + ∫ g(u)/u^(p+1) du))` donde `p = log_b(a)`. Es decir, recuperamos el
> método maestro.

## 11.3 Ejemplo: `T(n) = T(n/3) + T(2n/3) + cn`

```text
Ecuación característica:    (1/3)^p + (2/3)^p = 1

Por inspección / numérico:    p ≈ 0.7887...

Por el método del maestro no podemos (subproblemas desiguales).

Por Akra–Bazzi:
   g(n) = cn = Θ(n¹)
   La integral:   ∫₁ⁿ u/u^(p+1) du = ∫₁ⁿ u^(-p) du
                = [u^(1-p)/(1-p)]₁ⁿ
                = (n^(1-p) - 1)/(1-p)
   
   Con p ≈ 0.7887:  1-p ≈ 0.2113
   n^(1-p) ≈ n^0.2113
   
   T(n) = Θ(n^p · n^(1-p)) = Θ(n)    ?
   
   ¡No! Falta el factor log porque g(n) es Θ(n^p · ...).
   En este caso, el análisis cuidadoso (ver Divide&Conquer.md §7.2) da:
   
   T(n) = Θ(n log n)
```

> **Resultado:** Aunque `g(n) = n = Θ(n¹)` y `p ≈ 0.788 < 1`, la integral "se compensa"
> y el resultado es `Θ(n log n)`. Esto es sutil y requiere análisis cuidadoso.

## 11.4 Ejemplo: `T(n) = n·T(n/2) + 1`

```text
Ecuación característica:    n·(1/2)^p = 1
   
Espera, "a = n" no es constante. Akra–Bazzi requiere aᵢ constantes.
Toca usar una versión más general o sustitución directa.

Sustitución directa:
   T(n) = n · T(n/2) + 1
        = n · [(n/2)·T(n/4) + 1] + 1
        = (n²/2)·T(n/4) + n + 1
        
   Patrón: T(n) ≈ n · (n/2) · (n/4) · ... · T(1)
              = n^(log₂ n) · T(1)            ← "altura factorial"
              = n^(log₂ n)
   
   T(n) = Θ(n^(log₂ n)) = Θ(2^((log n)²))
```

> Esta recurrencia es **super-exponencial**. Crecimiento `O(2^((log n)²))`, más rápido que
> cualquier `n^k` pero más lento que `2ⁿ`.

## 11.5 Ejemplo: `T(n) = T(n/4) + T(3n/4) + cn`

```text
Ecuación característica:    (1/4)^p + (3/4)^p = 1

Por inspección / numérico:    p ≈ 0.85 (aproximado)

g(n) = cn = Θ(n¹) > n^p (con p < 1)
   → La integral aporta factor log
   → T(n) = Θ(n log n)
```

## 11.6 Cuándo usar Akra–Bazzi

✅ Recurrencias con **múltiples subproblemas de tamaños distintos**.
✅ Casos donde el método maestro falla por la **forma**.
✅ Análisis riguroso en papers y demostraciones.
❌ **No** cuando `aᵢ` no son constantes (usar otra técnica).
❌ **No** cuando los coeficientes dependen de `n` (necesita generalización).

## 11.7 Limitaciones de Akra–Bazzi

> ⚠️ Resolver `Σ aᵢ·bᵢᵖ = 1` a menudo requiere **métodos numéricos** (la raíz `p` puede
> no tener forma cerrada).
>
> ⚠️ La integral puede ser **difícil de evaluar**.
>
> ⚠️ La condición de "suavidad" de `g(n)` es técnica.

## 11.8 Tabla — Maestro vs Akra–Bazzi

| Característica            | Método Maestro               | Akra–Bazzi                          |
| ------------------------- | ---------------------------- | ----------------------------------- |
| **Forma**                 | `T(n) = aT(n/b) + f(n)`     | `T(n) = Σ aᵢT(bᵢn) + g(n)`         |
| **Subproblemas**          | Iguales                      | Pueden ser distintos                |
| **Coeficientes**          | Constantes                   | Constantes                          |
| **Cálculo de p**          | `p = log_b(a)` (cerrado)     | Resolver `Σ aᵢbᵢᵖ = 1` (puede ser numérico) |
| **Resultado**             | Una de 3 formas              | Fórmula integral                    |
| **Facilidad**             | ✅ Muy fácil                  | ❌ Avanzado                         |

---

# 12. Funciones Generadoras

## 12.1 Idea

Una **función generadora** codifica una sucesión `a₀, a₁, a₂, ...` en una serie de potencias:

```text
A(x) = a₀ + a₁x + a₂x² + a₃x³ + ... = Σₙ₌₀^∞ aₙxⁿ
```

**Resolver la recurrencia ↔ encontrar una forma cerrada para A(x).**

## 12.2 El truco

Si `aₙ = c₁aₙ₋₁ + c₂aₙ₋₂`, multiplicar por `xⁿ` y sumar:

```text
Σ aₙxⁿ  =  c₁·Σ aₙ₋₁xⁿ  +  c₂·Σ aₙ₋₂xⁿ
A(x)      =  c₁·x·A(x)   +  c₂·x²·A(x)  +  (casos base)

Despejar A(x) y expandir como serie de potencias.
```

## 12.3 Ejemplo: Fibonacci con funciones generadoras

```text
F(n) = F(n-1) + F(n-2),  con F(0) = 0, F(1) = 1
```

**Paso 1:** Multiplicar por `xⁿ` y sumar `n ≥ 2`:

```text
Σ(n≥2) F(n)xⁿ = Σ(n≥2) F(n-1)xⁿ + Σ(n≥2) F(n-2)xⁿ
```

**Paso 2:** Identificar las series:

```text
Σ(n≥2) F(n)xⁿ   = F(x) - F(0) - F(1)x = F(x) - x
Σ(n≥2) F(n-1)xⁿ = x · Σ(n≥2) F(n-1)x^(n-1) = x · F(x)
Σ(n≥2) F(n-2)xⁿ = x² · F(x)
```

**Paso 3:** Despejar:

```text
F(x) - x = x·F(x) + x²·F(x)
F(x) - x·F(x) - x²·F(x) = x
F(x)·(1 - x - x²) = x
F(x) = x / (1 - x - x²)
```

**Paso 4:** Descomposición en fracciones parciales:

```text
1 - x - x² = -(x - r₁)(x - r₂)  donde r₁, r₂ son raíces

r₁ = (1 - √5)/2  =  1-φ ≈ -0.618
r₂ = (1 + √5)/2  =  φ ≈ 1.618

F(x) = x / ((1 - φx)(1 + x/φ))  ≈  ...  expansión como serie

F(n) = (φⁿ - (1-φ)ⁿ) / √5     ← ¡La fórmula de Binet!
```

> **Conexión:** ¡Recuperamos la misma fórmula que con la ecuación característica! Las funciones
> generadoras y la ecuación característica son **dualidad**: una es la transformada de la otra.

## 12.4 Ejemplo: `aₙ = 2aₙ₋₁ + 1`, con `a₀ = 0`

```text
A(x) = Σ aₙxⁿ
A(x) - a₀ = 2x·A(x) + Σ 1·xⁿ  (n ≥ 1)
A(x) = 2x·A(x) + x/(1-x)
A(x)·(1 - 2x) = x/(1-x)
A(x) = x / [(1-x)(1-2x)]

Por fracciones parciales:
   A(x) = 1/(1-2x) - 1/(1-x) = Σ (2ⁿ - 1)·xⁿ

Solución:  aₙ = 2ⁿ - 1     ← ¡Igual que con coeficientes indeterminados!
```

## 12.5 Tabla de operaciones

| Operación                | Efecto                                      |
| ------------------------ | ------------------------------------------- |
| `A(x) ↔ {aₙ}`            | Definición                                  |
| `x·A(x) ↔ {aₙ₋₁}` (con `a₋₁ = 0`) | Desplazamiento a la derecha |
| `A(x)/x ↔ {aₙ₊₁}` (con `a₋₁ = 0`) | Desplazamiento a la izquierda |
| `A'(x) ↔ {n·aₙ}`         | Multiplicación por `n`                      |
| `A(x)·B(x) ↔ {Σ aₖbₙ₋ₖ}` | Convolución                                 |

## 12.6 Cuándo usar funciones generadoras

✅ Recurrencias con **coeficientes variables** (ej: `aₙ = n·aₙ₋₁`).
✅ Análisis de **combinatoria** y conteo.
✅ Cuando quieres una **fórmula cerrada exacta** (no solo asintótica).
❌ Más complejo que otros métodos para recurrencias simples.

## 12.7 Limitaciones

> ⚠️ Requiere conocimiento de **series de potencias** y **fracciones parciales**.
>
> ⚠️ La integral o derivada de la serie puede ser técnica.
>
> ⚠️ Para análisis asintótico, suele ser **exceso de trabajo**.

---

# 13. Cambio de Variable

## 13.1 Idea

A veces la recurrencia tiene una forma "rara" (ej: `T(n) = T(√n) + 1`) que no encaja en
ningún método estándar. El truco es **sustituir** `n = 2^k` (o similar) para convertirla
en una forma conocida.

## 13.2 Ejemplo clásico: `T(n) = T(√n) + 1`

```text
Sustituir n = 2^k.   Sea S(k) = T(2^k).
   T(2^k) = T(2^(k/2)) + 1
   S(k)    = S(k/2)    + 1

¡Ahora es la recurrencia clásica de binary search!

S(k) = Θ(log k)

Revertir:  k = log₂ n,  por lo tanto  T(n) = Θ(log log n)
```

> **Verificación:** para `n = 2^16 = 65536`, se hacen `log log n = 4` llamadas. Tiene sentido.

## 13.3 Ejemplo: `T(n) = 2T(√n) + 1`

```text
Sustituir n = 2^k,  S(k) = T(2^k):
   S(k) = 2S(k/2) + 1

Por método maestro:  a = 2, b = 2, d = 0
   log_b a = 1,  d = 0 < 1    →  Caso 1
   S(k) = Θ(k¹) = Θ(k)

Revertir:  T(n) = Θ(log n)
```

## 13.4 Ejemplo: `T(n) = 2T(n^(1/3)) + log n`

```text
Sustituir n = 2^k,  S(k) = T(2^k):
   T(2^k) = 2·T(2^(k/3)) + k
   S(k)   = 2·S(k/3)    + k

Por método maestro:  a = 2, b = 3, d = 1
   log_b a = log₃ 2 ≈ 0.631
   d = 1 > 0.631    →  Caso 3
   S(k) = Θ(k)

Revertir:  T(n) = Θ(log n)
```

## 13.5 Cuándo usar cambio de variable

✅ Recurrencias con `√n`, `n^(1/3)`, `log n` dentro.
✅ Recurrencias con `floor(log n)` o `ceil(log n)`.
❌ No abuses: a veces puedes resolver directamente con el árbol.

## 13.6 Tabla — cambio de variable común

| Recurrencia original         | Sustitución          | Recurrencia transformada |
| ---------------------------- | -------------------- | ------------------------ |
| `T(n) = T(√n) + f(n)`       | `n = 2^k`            | `S(k) = S(k/2) + f(2^k)`|
| `T(n) = 2T(√n) + f(n)`      | `n = 2^k`            | `S(k) = 2S(k/2) + f(2^k)`|
| `T(n) = T(n/log n) + f(n)`  | `n = 2^(2^k)` o `k = log log n` | `S(k) = S(k-1) + f(2^(2^k))` |
| `T(n) = T(n-1) + log n`     | (suma directa)        | (suma telescópica)        |

---

# 14. Recurrencias Comunes en Algoritmos

## 14.1 Catálogo definitivo

| #   | Algoritmo                     | Recurrencia                   | Solución       | Caso |
| --- | ----------------------------- | ----------------------------- | -------------- | ---- |
| 1   | **Búsqueda lineal**           | `T(n) = T(n-1) + 1`           | `Θ(n)`         | Linear |
| 2   | **Búsqueda binaria**          | `T(n) = T(n/2) + 1`           | `Θ(log n)`     | Master 2 |
| 3   | **Merge Sort**                | `T(n) = 2T(n/2) + n`          | `Θ(n log n)`   | Master 2 |
| 4   | **Quick Sort (promedio)**     | `T(n) = 2T(n/2) + n`          | `Θ(n log n)`   | Master 2 |
| 5   | **Quick Sort (peor)**         | `T(n) = T(n-1) + n`           | `Θ(n²)`        | Lineal |
| 6   | **Heap Sort**                 | `T(n) = 2T(n/2) + log n` build + n log n extract | `Θ(n log n)` | (mixto) |
| 7   | **Karatsuba**                 | `T(n) = 3T(n/2) + n`          | `Θ(n^1.585)`   | Master 1 |
| 8   | **Strassen**                  | `T(n) = 7T(n/2) + n²`         | `Θ(n^2.807)`   | Master 1 |
| 9   | **Closest Pair**              | `T(n) = 2T(n/2) + n`          | `Θ(n log n)`   | Master 2 |
| 10  | **FFT**                       | `T(n) = 2T(n/2) + n`          | `Θ(n log n)`   | Master 2 |
| 11  | **Naive Fibonacci**           | `T(n) = 2T(n-1) + 1`          | `Θ(2ⁿ)`        | Exponencial |
| 12  | **DP Fibonacci**              | `T(n) = T(n-1) + 1` cacheado  | `Θ(n)`         | Lineal |
| 13  | **Matrix Fibonacci**          | `T(n) = T(n/2) + 1`           | `Θ(log n)`     | Master 2 |
| 14  | **Exponenciación**            | `T(n) = T(n/2) + 1`           | `Θ(log n)`     | Master 2 |
| 15  | **Torres de Hanoi**           | `T(n) = 2T(n-1) + 1`          | `Θ(2ⁿ)`        | Lineal |
| 16  | **Cobertura de tablero**      | `T(n) = 4T(n/2) + 1`          | `Θ(n²)`        | Master 1 |
| 17  | **Búsqueda ternaria**         | `T(n) = 3T(n/3) + 1`          | `Θ(n)`         | Master 1 |
| 18  | **Max subarray D&C**          | `T(n) = 2T(n/2) + n`          | `Θ(n log n)`   | Master 2 |
| 19  | **Quickselect (promedio)**    | `T(n) = T(n/2) + n`           | `Θ(n)`         | (random) |
| 20  | **Quickselect (peor)**        | `T(n) = T(n-1) + n`           | `Θ(n²)`        | Lineal |

## 14.2 Análisis línea por línea de las más importantes

### Búsqueda lineal recursiva

```c
int linearSearch(int A[], int n, int x) {
    if (n == 0) return -1;
    if (A[0] == x) return 0;
    return 1 + linearSearch(A+1, n-1, x);
}
```

```text
T(n) = T(n-1) + 1,  T(0) = 1
T(n) = 1 + 1 + ... + 1  (n veces)  =  n  →  Θ(n)
```

### Búsqueda binaria

```text
T(n) = T(n/2) + 1
     = T(n/4) + 2
     = T(n/8) + 3
     = T(1) + log₂ n
     = Θ(log n)
```

### Merge Sort

```text
T(n) = 2T(n/2) + n
Por método maestro:  Caso 2  →  T(n) = Θ(n log n)
```

### Quick Sort (peor caso)

```text
T(n) = T(n-1) + n    (pivote siempre en un extremo)
     = T(n-2) + (n-1) + n
     = T(1) + 2 + 3 + ... + n
     = Θ(n²)
```

### Quick Sort (caso promedio, particiones balanceadas)

```text
T(n) = 2T(n/2) + n
     = Θ(n log n)
```

### Heap Sort

```text
Build-heap:    O(n)       (no recursivo, o recursión no dominante)
Extract-max:   log n por extracción × n extracciones = O(n log n)
                                    ─────
                                     T(n) implícito = O(n log n)
```

### Karatsuba

```text
T(n) = 3T(n/2) + Θ(n)
Por método maestro:  Caso 1 (log₂ 3 ≈ 1.585 > 1)
T(n) = Θ(n^log₂ 3) = Θ(n^1.585)
```

### Strassen

```text
T(n) = 7T(n/2) + Θ(n²)
Por método maestro:  Caso 1 (log₂ 7 ≈ 2.807 > 2)
T(n) = Θ(n^log₂ 7) = Θ(n^2.807)
```

### Closest Pair

```text
T(n) = 2T(n/2) + Θ(n)    (merge de la tira)
Por método maestro:  Caso 2
T(n) = Θ(n log n)
```

### FFT

```text
T(n) = 2T(n/2) + Θ(n)    (combinación con raíces de la unidad)
Por método maestro:  Caso 2
T(n) = Θ(n log n)
```

### Naive Fibonacci

```text
F(n) = F(n-1) + F(n-2) + 1
T(n) ≥ 2T(n-2)  (rama mayor)
T(n) = Ω(2^(n/2))  = Ω(φⁿ)    (crecimiento exponencial)
```

### DP Fibonacci

```text
Con memoización, cada F(k) se calcula UNA vez:
T(n) = n  →  Θ(n)
```

### Matrix Fibonacci (Divide & Conquer)

```text
T(n) = T(n/2) + 1  (exponenciar matriz cuadrada 2×2)
Por método maestro:  Caso 2
T(n) = Θ(log n)
```

### Torres de Hanoi

```text
T(n) = 2T(n-1) + 1
T(n) = 2ⁿ - 1  =  Θ(2ⁿ)
```

> ⚠️ Curiosidad histórica: la leyenda dice que el mundo se acabará cuando los monjes
> terminen de mover 64 discos de la Torre de Hanoi. Con `T(64) = 2^64 - 1 ≈ 1.8 × 10¹⁹`
> movimientos a 1 por segundo, faltan ~585 mil millones de años. El sol se habrá extinguido
> antes. 😉

### Cobertura de tablero (tiling) `T(n) = 4T(n/2) + 1`

```text
a = 4, b = 2, log_b a = 2
f(n) = 1,  d = 0
d < log_b a    →  Caso 1
T(n) = Θ(n²)
```

### Quickselect (peor)

```text
T(n) = T(n-1) + n
T(n) = Θ(n²)        (peor caso, mismo que quicksort)
```

### Quickselect (promedio, con pivote aleatorio)

```text
T(n) = T(n/2) + n   (esperado)
     = Θ(n)
```

## 14.3 Tabla de recurrencias por orden de complejidad

```text
O(log log n):     T(n) = T(√n) + 1
O(log n):         T(n) = T(n/2) + 1,  T(n) = 2T(n/2) - 1  (técnicamente)
O(n):             T(n) = T(n-1) + 1,  T(n) = T(n/2) + n,  T(n) = 3T(n/3) + 1
O(n log n):       T(n) = 2T(n/2) + n,  T(n) = T(n/3) + T(2n/3) + n
O(n log log n):   (casos raros)
O(n^1.585):       T(n) = 3T(n/2) + n
O(n²):            T(n) = 2T(n/2) + n²,  T(n) = 4T(n/2) + 1,  T(n) = T(n-1) + n
O(n^2.807):       T(n) = 7T(n/2) + n²
O(2^n):           T(n) = 2T(n-1) + 1,  F(n) = F(n-1) + F(n-2)
O(n^log n):       T(n) = n·T(n/2) + 1
```

## 14.4 Comparación final

| Recurrencia          | Solución        | Algoritmo                 |
| -------------------- | --------------- | ------------------------- |
| `T(n) = T(n/2) + 1` | `Θ(log n)`      | Búsqueda binaria          |
| `T(n) = 2T(n/2) + n`| `Θ(n log n)`    | Merge Sort, FFT, Closest  |
| `T(n) = 3T(n/2) + n`| `Θ(n^1.585)`    | Karatsuba                 |
| `T(n) = 7T(n/2) + n²`| `Θ(n^2.807)`   | Strassen                  |
| `T(n) = 2T(n-1) + 1`| `Θ(2ⁿ)`         | Torres de Hanoi, subsets  |
| `T(n) = T(n-1) + n` | `Θ(n²)`         | Quick Sort peor, selection|
| `T(n) = 2T(n-1) - 1`| `Θ(1)`          | (artificio matemático)    |

---

# 15. Límites Inferiores y Superiores

## 15.1 Recordatorio: las tres notaciones

| Notación | Significado                          | Uso en recurrencias             |
| -------- | ------------------------------------ | ------------------------------- |
| `O(f)`   | Cota superior: `T(n) ≤ c·f(n)`       | "Tu algoritmo es a lo más `f`"  |
| `Ω(f)`   | Cota inferior: `T(n) ≥ c·f(n)`       | "Tu algoritmo es al menos `f`"  |
| `Θ(f)`   | Cota ajustada: `c₁·f(n) ≤ T(n) ≤ c₂·f(n)` | "Tu algoritmo es exactamente `f`" |

## 15.2 Probar cota superior O(f) con sustitución

```text
CONJETURA:    T(n) ≤ c·f(n)  para n ≥ n₀

CASO BASE:    n₀ elegido para que se cumpla trivialmente.

PASO INDUCTIVO:
   T(n) = 2T(n/2) + n
        ≤ 2·c·f(n/2) + n
        = ...
        ≤ c·f(n)            ← necesitamos "álgebra correcta"
```

> Si la inducción cierra con alguna constante `c > 0` → cota superior probada.

## 15.3 Probar cota inferior Ω(f) con sustitución

```text
CONJETURA:    T(n) ≥ c·f(n)  para n ≥ n₀

PASO INDUCTIVO:
   T(n) = 2T(n/2) + n
        ≥ 2·c·f(n/2) + n
        = ...
        ≥ c·f(n)            ← álgebra "al revés"
```

> Si cierra → cota inferior probada.

## 15.4 Ejemplo completo: probar `T(n) = 2T(n/2) + n = Θ(n log n)`

**Cota superior `O(n log n)`:**

```text
Conjetura: T(n) ≤ c·n·log₂ n  para n ≥ 2

T(n) = 2T(n/2) + n
     ≤ 2·c·(n/2)·log₂(n/2) + n
     = c·n·log₂(n/2) + n
     = c·n·log₂ n - c·n + n
     ≤ c·n·log₂ n         ← si -cn + n ≤ 0, es decir c ≥ 1
```

**Cota inferior `Ω(n log n)`:**

```text
Conjetura: T(n) ≥ c·n·log₂ n  para n ≥ 2

T(n) = 2T(n/2) + n
     ≥ 2·c·(n/2)·log₂(n/2) + n
     = c·n·log₂ n - c·n + n
     ≥ c·n·log₂ n         ← si -cn + n ≥ 0, es decir c ≤ 1
```

> **Conclusión:** Para todo `n ≥ 2` y para todo `1/2 ≤ c ≤ 1`, `T(n) = Θ(n log n)`. ∎

## 15.5 Truco: la cota inferior puede ser más difícil

A veces es **más difícil** probar la cota inferior que la superior:

```text
T(n) = 2T(n/2) + n

Probar O(n log n):    "restamos" términos para que cierre
Probar Ω(n log n):    hay que mostrar que CADA paso inductivo es justo
```

## 15.6 Cambio de constantes

Si tu conjetura es "casi correcta" pero no cierra, prueba:

```text
T(n) ≤ c·f(n)    →   T(n) ≤ c·f(n) - g(n)    (g(n) término menor)
T(n) ≥ c·f(n)    →   T(n) ≥ c·f(n) + g(n)
```

## 15.7 Tabla de técnicas

| Para probar... | Técnica                              |
| -------------- | ------------------------------------ |
| `O(f)` superior | Sustitución, conjetura con `c·f(n)` |
| `Ω(f)` inferior | Sustitución, conjetura con `c·f(n)`  |
| `Θ(f)` ajustada | Ambas: probar O y Ω por separado     |
| Cota ajustada pero sin prueba directa | Acotar por dos lados y aplicar sándwich |

## 15.8 Ejemplo: probar `T(n) = T(n-1) + n = Θ(n²)`

**Cota superior:**

```text
T(n) = T(n-1) + n
     ≤ c·(n-1)² + n
     = c·n² - 2cn + c + n
     ≤ c·n²                ← si -2cn + c + n ≤ 0, es decir c ≥ (c+1)/(2n-1) → c ≥ 1
```

**Cota inferior (forma cerrada es más fácil):**

```text
T(n) = T(n-1) + n = T(n-2) + (n-1) + n = ... = T(1) + 2 + 3 + ... + n
     = 1 + n(n+1)/2 - 1 = n(n+1)/2 = Ω(n²)
```

> Conclusión: `T(n) = Θ(n²)`. ∎

## 15.9 La cota inferior del mergesort (lower bound en comparaciones)

La pregunta es: ¿puede un algoritmo de ordenamiento ser **mejor** que `O(n log n)`?

**Teorema:** Cualquier algoritmo de ordenamiento basado en comparaciones requiere
**al menos Ω(n log n)** comparaciones.

**Demostración (sketch):**
- Hay `n!` permutaciones posibles.
- Un árbol de decisión binario de altura `h` tiene a lo más `2^h` hojas.
- Para distinguir todas las permutaciones: `2^h ≥ n!`, por lo tanto `h ≥ log₂(n!)`.
- Por la aproximación de Stirling: `log₂(n!) ≈ n log₂ n`.

> **Implicación:** `O(n log n)` es óptimo para sorting por comparación. No se puede mejorar
> con esta familia de algoritmos. (Ver Algorithms.md §11.2.)

---

# 16. Errores Comunes

## 16.1 ⚠️ Catálogo de errores

| #  | Error                                                          | Consecuencia                                  | Solución                                          |
| -- | -------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------- |
| 1  | Aplicar maestro cuando `f(n)` no es polinómicamente comparable | Respuesta incorrecta                          | Usar sustitución o Akra–Bazzi                     |
| 2  | Confundir `T(n) = T(n-1) + n` con `O(n log n)`                | Subestimar la complejidad (es `Θ(n²)`)        | Reconocer el "disminución" vs "división"          |
| 3  | Olvidar el caso base                                           | Recursión infinita, stack overflow            | Especificar `T(0)` o `T(1)` explícitamente        |
| 4  | Caso base off-by-one (T(0) vs T(1))                           | Algoritmo falla en `n = 0` o `n = 1`          | Probar con `n = 0, 1, 2`                          |
| 5  | Ignorar pisos y techos (`⌊n/2⌋`, `⌈n/2⌉`)                     | Pequeña diferencia en recurrencias, pero asintóticamente OK | Aceptable para análisis asintótico              |
| 6  | Conjetura débil que no cierra la inducción                     | Quedarse atascado en la prueba                | Endurecer: `T(n) ≤ c·f(n) - d`                   |
| 7  | Conjetura falsa (no verdadera)                                 | Probar algo incorrecto                        | Verificar con casos pequeños antes                |
| 8  | Asumir división uniforme cuando no lo es                      | Análisis totalmente incorrecto                | Usar Akra–Bazzi o análisis caso por caso         |
| 9  | Olvidar la condición de regularidad en Caso 3                  | Conclusión inválida                           | Verificar `a·f(n/b) ≤ c·f(n)` con `c < 1`        |
| 10 | Contar mal el número de subproblemas (a)                       | Aplicar mal el maestro                        | Recontar las llamadas recursivas                  |
| 11 | Confundir `log_b a` con `log a / log b`                        | Error aritmético en el exponente              | Verificar con valores concretos                   |
| 12 | Tratar `T(n) = 2T(n/2) + 1` como `O(n)` en vez de `O(n)`     | En realidad es `Θ(n)`, así que está bien     | (Este error es en realidad correcto, pero confunde) |
| 13 | Asumir que `T(n) = aT(n/b) + cn` con `a < b` da `Θ(n)`        | A veces sí, a veces no                        | Aplicar Caso 3 con verificación de regularidad    |
| 14 | No distinguir entre la **forma cerrada** y la **cota asintótica** | Confundir `T(n) = 2^n` con `T(n) = Θ(2^n)`   | Saber cuál necesitas en cada contexto            |
| 15 | Tratar `O` y `Θ` como sinónimos                               | Decir `O(n log n)` cuando se quiere `Θ`       | Usar notación precisa                             |

## 16.2 Los 3 errores más comunes (con ejemplos)

### Error 1: "Es `O(n log n)` porque es un divide & conquer"

```text
❌ INCORRECTO:
   "T(n) = 2T(n/2) + n²  →  O(n log n)"
   No, esto es Θ(n²) (Caso 3 del maestro, no Caso 2).

✅ CORRECTO:
   "T(n) = 2T(n/2) + n²  →  Θ(n²)  (Método Maestro, Caso 3)"
```

> **Regla:** El divide & conquer da `O(n log n)` SOLO cuando el trabajo por nivel es uniforme.
> Si la combinación es más cara, el resultado es **peor**.

### Error 2: "Es `O(n log n)` porque `n/2` aparece"

```text
❌ INCORRECTO:
   "T(n) = T(n/2) + n  →  O(n log n)"
   No, esto es Θ(n) (Caso 3, no Caso 2).

✅ CORRECTO:
   "T(n) = T(n/2) + n  →  Θ(n)  (Método Maestro, Caso 3)"
```

> **Regla:** Que `n/2` aparezca NO garantiza `log n` en la respuesta. La clave es la
> comparación entre `f(n)` y `n^(log_b a)`.

### Error 3: Confundir recurrencias con división vs. con decremento

```text
División (D&C):       T(n) = T(n/2) + ...    → puede ser log n si la combinación es cheap
Decremento:           T(n) = T(n-1) + ...    → puede ser n si la combinación es O(1)

Confundir estas formas lleva a errores de orden exponencial.
```

## 16.3 Tests rápidos para detectar errores

```text
1. ¿La inducción cierra?
   → Si no, ajustar constantes o endurecer conjetura.

2. ¿La conjetura es verdadera?
   → Verificar con n=1, 2, 4, 8 antes de probar.

3. ¿La condición de regularidad se cumple en Caso 3?
   → Si no, no se puede aplicar Caso 3 directamente.

4. ¿El método maestro realmente aplica?
   → Verificar la FORMA: T(n) = aT(n/b) + f(n).

5. ¿Las llamadas recursivas son correctas?
   → Contar de nuevo el número de subproblemas.
```

---

# 17. Buenas Prácticas

## 17.1 ✅ Catálogo de buenas prácticas

| #  | Práctica                                                        | Por qué                                          |
| -- | --------------------------------------------------------------- | ------------------------------------------------ |
| 1  | **Verificar la recurrencia** con casos pequeños (`n=1, 2, 4`)  | Detecta errores antes de la formalización        |
| 2  | **Hacer el árbol de recursión** mental o en papel               | Desarrolla intuición                             |
| 3  | **Aplicar múltiples métodos** al mismo problema                | Verificación cruzada                             |
| 4  | **Comprobar la condición de regularidad** en Caso 3             | Evita conclusiones inválidas                     |
| 5  | **Documentar la recurrencia** en el código                      | Mantenibilidad y debugging                       |
| 6  | **Pensar primero en casos base correctos**                      | Sin caso base, no hay algoritmo                  |
| 7  | **Usar Θ cuando la respuesta es ajustada**                      | Mayor precisión en la comunicación               |
| 8  | **Medir empíricamente** para validar el análisis                | Las constantes importan                          |
| 9  | **Considerar el peor caso** en producción                       | Producción ≠ laboratorio                         |
| 10 | **Estimar el orden antes de codear**                            | Predecir problemas de performance                |

## 17.2 El flujo de trabajo recomendado

```text
┌──────────────────────────────────────────┐
│ 1. ¿Es un algoritmo recursivo?           │
│    → SÍ: continuar                       │
│    → NO: análisis directo de bucles      │
├──────────────────────────────────────────┤
│ 2. Identificar:                          │
│    a) caso base                          │
│    b) número de llamadas (a)            │
│    c) tamaño de subproblemas (b)        │
│    d) trabajo no recursivo (f(n))       │
├──────────────────────────────────────────┤
│ 3. Escribir la recurrencia:             │
│    T(n) = aT(n/b) + f(n)                │
├──────────────────────────────────────────┤
│ 4. ¿Encaja en método maestro?           │
│    → SÍ: usarlo                          │
│    → NO: ir a paso 5                    │
├──────────────────────────────────────────┤
│ 5. ¿Subproblemas desiguales?            │
│    → SÍ: Akra–Bazzi                      │
│    → NO: sustitución o árbol            │
├──────────────────────────────────────────┤
│ 6. Verificar el resultado:              │
│    a) Con n=1, 2, 4                     │
│    b) Con código real                   │
└──────────────────────────────────────────┘
```

## 17.3 Sanity checks para verificar soluciones

```text
CHECK 1:  ¿El resultado satisface la recurrencia?
          → Sustituir T(n) = c·f(n) en la recurrencia
          → Verificar que la igualdad es aproximadamente cierta

CHECK 2:  ¿El caso base funciona?
          → T(1) o T(0) debe dar el valor correcto

CHECK 3:  ¿La complejidad tiene sentido?
          → Un algoritmo O(n²) que parece O(n) es señal de error

CHECK 4:  ¿Las constantes son razonables?
          → Teoría O(n log n) con constante 1000 puede ser peor que O(n²) con constante 1
          → Para n pequeño

CHECK 5:  ¿La recurrencia original es la correcta?
          → Volver a contar las llamadas recursivas
```

## 17.4 Estimación rápida de orden

Para tener una idea del orden sin resolver la recurrencia formalmente:

```text
Mira la recurrencia. Pregúntate:
  1. ¿Cuántos subproblemas? (a)
  2. ¿Cada uno es ~ n/b?
  3. ¿Cuánto trabajo extra por nivel? (f(n))

Si f(n) ~ n por nivel →  Θ(n · log n)   (si se mantiene)  o  Θ(n) (si decrece)
Si f(n) ~ n^k constante por nivel →  Θ(n^k · log n)  o  Θ(n^k)
```

## 17.5 Comunicación efectiva de la complejidad

```text
❌ "T(n) = 2T(n/2) + n, así que es O(n log n)"
   → ¿Cómo lo sabes? Muestra el método usado.

✅ "Por el método maestro (Caso 2), T(n) = 2T(n/2) + n = Θ(n log n)"
   → Claro, preciso, verificable.

❌ "Es muy rápido"
   → Inútil.

✅ "Es Θ(n log n), mejor que Θ(n²) para n > 1000"
   → Cuantitativo.
```

---

# 18. Intuición de Ingeniería

## 18.1 El "árbol mental" — qué hacer para CUALQUIER recurrencia

```text
┌────────────────────────────────────────────────────────────┐
│ Para T(n) = aT(n/b) + f(n):                               │
│                                                            │
│  1. ¿Cuántos nodos tiene el árbol?              →  aⁱ      │
│  2. ¿Qué tamaño tiene cada nodo en nivel i?    →  n/bⁱ    │
│  3. ¿Cuánto trabajo hay en cada nodo?          →  f(n/bⁱ) │
│  4. ¿Trabajo total del nivel i?                →  aⁱ·f(n/bⁱ)│
│  5. ¿Cuántos niveles tiene?                     →  log_b n │
│  6. ¿Quién crece más rápido, raíz u hojas?                │
│                                                            │
│  Si f(n/bⁱ) DECRECE con i  →  raíz domina →  Caso 3     │
│  Si f(n/bⁱ) SE MANTIENE    →  todos los niveles → Caso 2 │
│  Si f(n/bⁱ) CRECE con i    →  hojas dominan →  Caso 1   │
└────────────────────────────────────────────────────────────┘
```

## 18.2 El "checklist" de 60 segundos

```text
□ ¿La recurrencia es T(n) = aT(n/b) + f(n)?
   → SÍ: usar método maestro
   → NO: usar sustitución o Akra–Bazzi

□ Si es método maestro:
   □ Calcular log_b a
   □ Comparar con d (el exponente de f(n) = n^d)
   □ Si d es menor/igual/mayor → Caso 1/2/3
   □ Si Caso 3, verificar regularidad

□ Si no encaja en maestro:
   □ ¿Subproblemas desiguales? → Akra–Bazzi
   □ ¿Forma "rara" (√n, log n)? → Cambio de variable
   □ Si no, sustitución o árbol
```

## 18.3 Mapa de decisión final

```text
                            T(n) = ?
                                │
              ┌─────────────────┼──────────────────┐
              │                 │                  │
       T(n) = aT(n/b) + f(n)   T(n) = aT(n-1) + f(n)   T(n) = T(b₁n) + T(b₂n) + ...
              │                 │                  │
       Método Maestro      Ecuación característica   Akra–Bazzi
              │                 │                  │
              │                 └── Coeficientes
              │                     indeterminados
              │
   ┌──────────┼──────────┐
   │          │          │
 CASO 1    CASO 2     CASO 3
 hojas     equil.     raíz
   │          │          │
 Θ(n^log_ba)  Θ(n^d lg n) Θ(f(n))
```

## 18.4 Tabla resumen de los 7 métodos

| Método              | Forma que resuelve                       | Dificultad | Velocidad |
| ------------------- | ---------------------------------------- | ---------- | --------- |
| **Iteración**       | Cualquiera (manual)                      | Baja       | Media     |
| **Sustitución**     | Cualquiera (con conjetura)               | Media      | Lenta     |
| **Árbol**           | Cualquiera (visual)                      | Media      | Media     |
| **Maestro**         | `T(n) = aT(n/b) + f(n)`                  | Baja       | Rápida    |
| **Akra–Bazzi**      | General con `Σ aᵢT(bᵢn) + g(n)`          | Alta       | Media     |
| **Generadoras**     | Lineales con coeficientes variables      | Alta       | Lenta     |
| **Ecuación caract.**| Recurrencias lineales homogéneas         | Media      | Rápida    |

## 18.5 Las 5 reglas mnemotécnicas

| #  | Regla                              | Significado                                          |
| -- | ---------------------------------- | ---------------------------------------------------- |
| 1  | **Maestro primero**                | Si encaja en `T(n) = aT(n/b) + f(n)`, es lo más rápido |
| 2  | **Árbol para ver, sustitución para probar** | El árbol desarrolla intuición, la sustitución formaliza |
| 3  | **Si los subproblemas son desiguales, no hay maestro** | → Akra–Bazzi |
| 4  | **Verificar siempre con casos pequeños** | `n=1, 2, 4, 8` antes de probar |
| 5  | **El Θ es la respuesta ajustada** | Si puedes probarlo, úsalo; si no, al menos da O y Ω |

## 18.6 Conexión con el resto del repositorio

| Tema                            | Conexión con Recurrencias                      |
| ------------------------------- | ---------------------------------------------- |
| **Algorithms.md (sección 6)**   | Versión resumida (aquí profundizamos)          |
| **Divide&Conquer.md**           | Genera las recurrencias; aquí las resolvemos   |
| **Sorting.md**                  | Merge/Quick/Heap Sort → recurrencias canónicas |
| **Programación Dinámica**       | Recurrencias + memoización; análisis similar   |
| **Recursion/**                  | Recurrencias = recursión matemática            |
| **Grafos/**                     | Dijkstra, BFS, DFS son análisis de recurrencias |

## 18.7 Tabla de decisión rápida por problema

| Si tu algoritmo hace...                       | Recurrencia esperada       | Complejidad      |
| --------------------------------------------- | -------------------------- | ---------------- |
| Búsqueda secuencial                           | `T(n) = T(n-1) + 1`        | `Θ(n)`           |
| Búsqueda binaria                              | `T(n) = T(n/2) + 1`        | `Θ(log n)`       |
| Ordenamiento divide & conquer balanceado      | `T(n) = 2T(n/2) + n`       | `Θ(n log n)`     |
| Multiplicación naïve                          | `T(n) = 4T(n/2) + n`       | `Θ(n²)`          |
| Multiplicación Karatsuba                      | `T(n) = 3T(n/2) + n`       | `Θ(n^1.585)`     |
| Multiplicación matrices naïve                | `T(n) = 8T(n/2) + n²`      | `Θ(n³)`          |
| Multiplicación matrices Strassen              | `T(n) = 7T(n/2) + n²`      | `Θ(n^2.807)`     |
| Recorrido árbol (cada nodo)                   | `T(n) = 2T(n/2) + 1`       | `Θ(n)`           |
| Hanoi, subsets naïve                          | `T(n) = 2T(n-1) + 1`       | `Θ(2ⁿ)`          |
| Fibonacci naïve                               | `T(n) = T(n-1) + T(n-2)`   | `Θ(φⁿ)`          |
| Fibonacci con memoización                     | (lineal, no recursión útil)| `Θ(n)`           |

## 18.8 El principio unificador

> **Toda recurrencia es una afirmación sobre cómo se COMPONE el trabajo.**
>
> **Resolverla** es saber **cuánto** trabajo total se compone.
>
> Las tres preguntas clave son siempre:
> 1. **¿Cuántos subproblemas?** (coeficiente `a`)
> 2. **¿De qué tamaño?** (factor `b`)
> 3. **¿Cuánto trabajo extra por nivel?** (`f(n)`)
>
> Si puedes responder esas tres, **puedes resolver casi cualquier recurrencia**.

## 18.9 Resumen ejecutivo de una página

```text
┌──────────────────────────────────────────────────────────────┐
│                  MÉTODOS PARA RECURRENCIAS                   │
│                                                              │
│  1. Iteración:      Desenrollar, identificar patrón.        │
│  2. Sustitución:    Conjeturar, probar por inducción.       │
│  3. Árbol:          Visualizar, sumar por nivel.            │
│  4. Maestro:        T(n) = aT(n/b) + f(n), 3 casos.        │
│  5. Akra–Bazzi:     Σ aᵢT(bᵢn) + g(n), general.            │
│  6. Generadoras:    Series de potencias, fracciones parciales│
│  7. Ecuación car.:  Lineales homogéneas, raíces.            │
│                                                              │
│  REGLA DE ORO:                                               │
│  Maestro si encaja. Si no, sustitución o árbol.            │
│  Akra–Bazzi si los subproblemas son desiguales.            │
│                                                              │
│  RECURRENCIAS CANÓNICAS:                                     │
│  T(n) = T(n/2) + 1      → Θ(log n)    (binary search)      │
│  T(n) = 2T(n/2) + n     → Θ(n log n)  (merge sort)         │
│  T(n) = 3T(n/2) + n     → Θ(n^1.585)  (Karatsuba)          │
│  T(n) = 7T(n/2) + n²    → Θ(n^2.807)  (Strassen)           │
│  T(n) = 2T(n-1) + 1     → Θ(2ⁿ)       (Hanoi, subsets)     │
│  T(n) = T(n-1) + n      → Θ(n²)       (QS worst)           │
└──────────────────────────────────────────────────────────────┘
```

## 18.10 Las tres leyes de las recurrencias

> **Primera ley:** *El método maestro es la primera herramienta que intentas. Si no aplica,
> pasas a sustitución o Akra–Bazzi.*
>
> **Segunda ley:** *Siempre verifica tu solución con casos pequeños antes de formalizar.*
>
> **Tercera ley:** *Si una recurrencia parece difícil, haz el árbol de recursión. La respuesta
> suele ser visible después de los primeros 2-3 niveles.*

---

## Referencias

- **CLRS** — Cormen, Leiserson, Rivest, Stein. *Introduction to Algorithms* (4ª ed.).
  - Capítulo 4: *Divide-and-Conquer* (sección 4.1: sustitución, 4.2: árbol, 4.3: método de prueba,
    4.4: teorema maestro, 4.5: maestro formal, 4.6: prueba del maestro)
  - Capítulo 2.3: *Divide-and-Conquer* (vista general)
  - Capítulo 30: *Polynomials and the FFT* (recurrencias en el contexto de FFT)
  - Capítulo 33: *Computational Geometry* (closest pair)
- **Concrete Mathematics** — Graham, Knuth, Patashnik. *A Foundation for Computer Science*.
  Capítulos 1, 2 y 7: estudio profundo de recurrencias, funciones generadoras y sumas.
- **Algorithms** — Sedgewick, Wayne. *Algorithms* (4ª ed.). Capítulos 2, 5 sobre recurrencias en sorting.
- **Divide&Conquer.md** en este repositorio — vista general de recurrencias en algoritmos D&C.
- **Algorithms.md** en este repositorio — sección 6 (introducción a recurrencias) y sección 11 (límite Ω(n log n) en sorting).
