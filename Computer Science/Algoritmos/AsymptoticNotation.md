# Asymptotic Notation — Notación Asintótica

> **Idea central:** La notación asintótica es el **lenguaje con el que hablamos del crecimiento** de funciones y, por extensión, del costo de los algoritmos.
> Nos permite ignorar constantes y términos de menor orden para enfocarnos en la **tendencia dominante** cuando `n → ∞`.
> Es la diferencia entre saber que un programa "tarda algo" y saber que su costo crece como `n log n`.

---

## Tabla de Contenidos

1. [¿Por qué Notación Asintótica?](#1-por-qué-notación-asintótica)
2. [Las Cinco Notaciones Esenciales](#2-las-cinco-notaciones-esenciales)
3. [Definición Formal de Big-O (CLRS 3.1)](#3-definición-formal-de-big-o-clrs-31)
4. [Definición Formal de Big-Ω](#4-definición-formal-de-big-ω)
5. [Definición Formal de Big-Θ](#5-definición-formal-de-big-θ)
6. [Little-o: Estrictamente Menor](#6-little-o-estrictamente-menor)
7. [Little-ω: Estrictamente Mayor](#7-little-ω-estrictamente-mayor)
8. [La Jerarquía de Crecimiento](#8-la-jerarquía-de-crecimiento)
9. [Propiedades de las Notaciones](#9-propiedades-de-las-notaciones)
10. [Aritmética Asintótica](#10-aritmética-asintótica)
11. [Composición de Funciones](#11-composición-de-funciones)
12. [Límites y la Notación Asintótica](#12-límites-y-la-notación-asintótica)
13. [Funciones Comunes y sus Crecimientos](#13-funciones-comunes-y-sus-crecimientos)
14. [Smoothness (Suavidad) — CLRS 4.5](#14-smoothness-suavidad--clrs-45)
15. [Funciones Monótonas](#15-funciones-monótonas)
16. [Pisos y Techos (Floors and Ceilings)](#16-pisos-y-techos-floors-and-ceilings)
17. [Análisis Amortizado (CLRS Cap. 17)](#17-análisis-amortizado-clrs-cap-17)
18. [Notaciones Adicionales](#18-notaciones-adicionales)
19. [Errores Comunes y Trampas](#19-errores-comunes-y-trampas)
20. [Ejercicios Resueltos](#20-ejercicios-resueltos)
21. [Buenas Prácticas](#21-buenas-prácticas)
22. [Intuición de Ingeniería](#22-intuición-de-ingeniería)

---

# 1. ¿Por qué Notación Asintótica?

## 1.1 El problema: comparar funciones sin constantes

Supongamos dos algoritmos cuyo tiempo de ejecución es:

```text
Algoritmo A:   3n² + 5n + 100   operaciones
Algoritmo B:   0.5n² + 1000n    operaciones
```

**¿Cuál es más rápido?**

La respuesta **depende de n**:

```text
n = 10:    A = 450,    B = 10,050   →  A gana
n = 100:   A = 30,500, B = 105,000  →  A gana
n = 1,000: A = 3,005,000  vs B = 1,000,500   →  B gana
n = 10⁶:   A ≈ 3·10¹²    B ≈ 5·10⁸            →  B gana por mucho
```

Para `n` **muy grande**, el término cuadrático `n²` domina sobre el lineal `n`. La constante `1000` que parece enorme en `B` se vuelve **irrelevante** comparada con `n²`.

> **Idea central:** Cuando `n → ∞`, solo importa el **término de mayor orden**.

## 1.2 Lo que la notación asintótica hace

| Lo que hace                                  | Lo que NO hace                          |
| -------------------------------------------- | --------------------------------------- |
| Identifica la **tendencia dominante**        | Da el número exacto de operaciones      |
| Compara **clases de funciones**              | Predice el rendimiento para `n` pequeño |
| Es **independiente del hardware**            | Captura constantes multiplicativas      |
| Permite **pruebas formales** de cotas        | Sustituye al benchmarking               |
| Es el **lenguaje universal** de algoritmos  | Considera el caso promedio vs peor caso (sin ayuda) |

## 1.3 Realidad de ingeniería

En la práctica:

```text
1. Un algoritmo O(n²) puede ser MÁS RÁPIDO que uno O(n log n) si las
   constantes son muy diferentes y n es pequeño.

2. Para n "grande", el término dominante gana SIEMPRE.

3. La notación asintótica responde: "¿qué pasa cuando n → ∞?"
```

> **CLRS Cap. 3:** *"We seek a methodology that will let us compare the inherent complexity of two algorithms, independent of constant factors and lower-order terms."*

## 1.4 Conexión con el resto del repositorio

`Algorithms.md` da una **introducción rápida** a Big-O. Este archivo profundiza:

| Tema                                | Algorithms.md        | Este archivo                       |
| ----------------------------------- | -------------------- | ---------------------------------- |
| Definiciones O, Ω, Θ                | Intuitiva (sección 3)| **Formal con cuantificadores**     |
| Jerarquía de crecimiento            | Tabla corta          | **Tabla completa con valores**     |
| Reglas aritméticas                  | Mención breve        | **Teoría completa con pruebas**    |
| Little-o / little-ω                | No cubierto          | **Definido y usado**               |
| Límites y L'Hôpital                 | No cubierto          | **Sección dedicada**               |
| Smoothness (CLRS 4.5)               | No cubierto          | **Definido formalmente**           |
| Análisis amortizado                 | Mención superficial  | **Tres métodos, ejemplos completos**|
| Errores comunes                     | Lista corta          | **Trampas con explicación**        |

---

# 2. Las Cinco Notaciones Esenciales

## 2.1 Panorama

Hay **cinco** notaciones estándar. Tres "Big" (cota ajustada a una constante) y dos "Little" (cota estricta).

| Notación   | Nombre formal       | Lectura              | Cuantifica            |
| ---------- | ------------------- | -------------------- | --------------------- |
| **O(f)**   | Big-O               | "O de f"             | Cota superior         |
| **Ω(f)**   | Big-Omega           | "Omega de f"         | Cota inferior         |
| **Θ(f)**   | Big-Theta           | "Theta de f"         | Cota ajustada         |
| **o(f)**   | Little-o            | "o minúscula de f"   | Cota superior estricta|
| **ω(f)**   | Little-omega        | "omega minúscula de f" | Cota inferior estricta |

## 2.2 Visualización conceptual

```text
            Crecimiento (eje Y)
                  ↑
                  │
        f(n)  ───┤  ← curva de referencia
              ╱  │
            ╱    │
          ╱      │       o(f): f SIEMPRE está estrictamente arriba
        ╱        │       O(f): f puede estar arriba O igual
      ╱          │
    ╱            │       Θ(f): f está SANDWICHEADO entre c₁·g y c₂·g
  ╱              │       Ω(f): f SIEMPRE está abajo o igual
╱                │       ω(f): f SIEMPRE está estrictamente abajo
─────────────────┼──────────→ n
```

## 2.3 Analogía del mundo real

| Notación | Analogía vehicular                                    |
| -------- | ----------------------------------------------------- |
| **O(f)** | "El coche **nunca pasa** de 200 km/h"                 |
| **Ω(f)** | "El coche **nunca baja** de 80 km/h"                  |
| **Θ(f)** | "El coche **siempre** está entre 80 y 200 km/h"       |
| **o(f)** | "El coche **nunca alcanza** los 200 km/h"             |
| **ω(f)** | "El coche **siempre supera** los 80 km/h"             |

## 2.4 Cuándo usar cada una

| Situación                                          | Usar                |
| -------------------------------------------------- | ------------------- |
| Análisis de **peor caso** (lo más común)           | **O(f)**            |
| Prueba de **optimalidad** (límite inferior)        | **Ω(f)**            |
| Quiero decir "es exactamente de este orden"        | **Θ(f)**            |
| Quiero decir "crece más lento" (estricto)          | **o(f)**            |
| Quiero decir "crece más rápido" (estricto)         | **ω(f)**            |
| Estoy comparando con **límites**                   | **o** o **ω**       |
| Estoy probando una **igualdad ajustada**           | **Θ(f)**            |

> **Regla de oro:** En ingeniería, usa **O** para cotas superiores, **Θ** cuando puedas probar que es ajustado, **Ω** solo cuando pruebes optimalidad. Las notaciones little-o/ω son para textos teóricos y pruebas rigurosas.

---

# 3. Definición Formal de Big-O (CLRS 3.1)

## 3.1 Definición

> **Definición (CLRS 3.1):**
> Sea `f, g: ℕ → ℝ⁺`. Decimos que
>
> ```text
> f(n) = O(g(n))
> ```
>
> si **existen** constantes positivas `c > 0` y `n₀ ≥ 1` tales que
>
> ```text
> f(n) ≤ c · g(n)     para todo n ≥ n₀
> ```

En símbolos:

```text
f(n) = O(g(n))    ⟺    ∃ c > 0,  ∃ n₀ ≥ 1  tales que  ∀ n ≥ n₀:  f(n) ≤ c · g(n)
```

## 3.2 Lectura detallada

```text
∃ c > 0      "existe alguna constante positiva c"
∃ n₀ ≥ 1     "existe algún umbral n₀"
∀ n ≥ n₀     "para todos los n a partir de ese umbral"

f(n) ≤ c·g(n)    "f nunca supera a g multiplicada por c"
```

**Interpretación:** A partir de cierto tamaño `n₀`, `f` está **dominado** por `g` salvo por una constante multiplicativa.

## 3.3 Visualización

```text
g(n)
│         ╱──────────── c·g(n)         ← recta techo
│        ╱
│       ╱
│      ╱
│   f(n)
│    ╱
│  ╱
│╱
└─────────────────────────────→ n
0           n₀

A partir de n₀, f(n) siempre queda DEBAJO de c·g(n).
```

## 3.4 Ejemplo 1: `f(n) = 3n + 5 = O(n)`

**Demostración formal:**

```text
Buscamos c > 0 y n₀ ≥ 1 tales que:
   3n + 5 ≤ c · n     ∀ n ≥ n₀

Reorganizamos:
   3n + 5 ≤ c·n
   5 ≤ c·n - 3n
   5 ≤ (c - 3)·n

Para que esto se cumpla ∀ n ≥ n₀, basta con:
   - Elegir c = 4 (entonces c - 3 = 1)
   - Entonces: 5 ≤ 1·n  ⟺  n ≥ 5

Conclusión: c = 4, n₀ = 5.
   Para todo n ≥ 5:   3n + 5 ≤ 4n   ✓
```

**Verificación numérica:**

```text
n = 5:    3·5 + 5 = 20   ≤  4·5 = 20    ✓
n = 6:    3·6 + 5 = 23   ≤  4·6 = 24    ✓
n = 100:  3·100 + 5 = 305  ≤  4·100 = 400   ✓
```

## 3.5 Ejemplo 2: `f(n) = 5n² + 3n + 2 = O(n²)`

**Demostración:**

```text
5n² + 3n + 2 ≤ c · n²

Para n ≥ 1:
   3n ≤ 3n²   (porque n ≤ n² cuando n ≥ 1)
   2  ≤ 2n²   (idem)

Por tanto:
   5n² + 3n + 2 ≤ 5n² + 3n² + 2n² = 10n²

Conclusión: c = 10, n₀ = 1.
   Para todo n ≥ 1:   5n² + 3n + 2 ≤ 10n²   ✓
```

## 3.6 Ejemplo 3: `f(n) = n log n = O(n²)`

**Demostración:**

```text
Para n ≥ 2:
   log n ≤ n       (porque log n crece más lento)
   ⟹  n · log n ≤ n · n = n²

Conclusión: c = 1, n₀ = 2.
```

## 3.7 Ejemplo 4: `100n + 5 ≠ O(1)` — falso positivo

**Demostración por contradicción:**

```text
Supongamos que 100n + 5 = O(1).
Entonces:  ∃ c, n₀  tales que  100n + 5 ≤ c  para todo n ≥ n₀.

Pero si n → ∞, el lado izquierdo crece sin cota,
mientras que c es CONSTANTE.
Para n > (c - 5) / 100:    100n + 5 > c   ✗

Contradicción.  Por tanto 100n + 5 ≠ O(1).
```

## 3.8 Ejemplo 5: cualquier polinomio de grado k es `O(nᵏ)`

```text
Si f(n) = aₖnᵏ + aₖ₋₁nᵏ⁻¹ + ... + a₀   con aₖ > 0,

entonces para n ≥ 1:
   n^j ≤ nᵏ     para j ≤ k
   aⱼn^j ≤ |aⱼ| · nᵏ

Sumando:
   f(n) ≤ (|aₖ| + |aₖ₋₁| + ... + |a₀|) · nᵏ

Por tanto, c = Σ |aᵢ|   y   n₀ = 1.
```

## 3.9 Errores comunes con Big-O

### ⚠️ Error 1: Confundir `O(f)` con `f`

```text
❌ "El algoritmo es O(n²)"        → ambiguo (¿tarda n² o menos?)
✅ "El algoritmo es O(n²)"         → correcto: tarda a lo más n²
✅ "El algoritmo es Θ(n²)"        → más fuerte: tarda exactamente n²
```

### ⚠️ Error 2: Decir "es" en vez de "está en"

```text
❌ "f(n) es O(n²)"                → sugiere que f es igual a O(n²)
✅ "f(n) = O(n²)"                 → significa f es MIEMBRO del conjunto O(n²)
✅ "f(n) ∈ O(n²)"                 → aún más claro (CLRS usa "=" por tradición)
```

### ⚠️ Error 5: Confundir con `≤`

```text
❌ "O(n²) ≤ O(n³)"               → no tiene sentido (las O son conjuntos)
✅ "O(n²) ⊆ O(n³)"               → cualquier función O(n²) también es O(n³)
```

> **CLRS Cap. 3.1 (nota):** *"The equality sign in 'f(n) = O(g(n))' is not symmetric: it means 'f is a member of the set O(g(n))'."*

---

# 4. Definición Formal de Big-Ω

## 4.1 Definición

> **Definición (CLRS 3.1):**
> Sea `f, g: ℕ → ℝ⁺`. Decimos que
>
> ```text
> f(n) = Ω(g(n))
> ```
>
> si **existen** constantes positivas `c > 0` y `n₀ ≥ 1` tales que
>
> ```text
> c · g(n) ≤ f(n)     para todo n ≥ n₀
> ```

En símbolos:

```text
f(n) = Ω(g(n))    ⟺    ∃ c > 0,  ∃ n₀ ≥ 1  tales que  ∀ n ≥ n₀:  c·g(n) ≤ f(n)
```

## 4.2 Lectura

**Big-Ω** da una **cota inferior**: `f` nunca baja de `c·g` para `n` suficientemente grande.

## 4.3 Visualización

```text
g(n)
│         ╱
│        ╱
│       ╱
│      ╱
│     ╱
│   f(n)
│  ╱   c·g(n)  ← recta piso
│╱ ─────────────
└──────────────────────→ n
0           n₀

A partir de n₀, f(n) siempre queda ENCIMA de c·g(n).
```

## 4.4 Dualidad con Big-O

> **Teorema (CLRS 3.1-5):** Para cualquier `f, g`:
>
> ```text
> f(n) = Ω(g(n))    ⟺    g(n) = O(f(n))
> ```

**Demostración:**

```text
(⟹) Si f(n) = Ω(g(n)):
       ∃ c, n₀:  c·g(n) ≤ f(n)  ∀ n ≥ n₀
       ⟹        g(n) ≤ (1/c)·f(n)
       ⟹        g(n) = O(f(n))    con c' = 1/c

(⟸) Si g(n) = O(f(n)):
       ∃ c, n₀:  g(n) ≤ c·f(n)  ∀ n ≥ n₀
       ⟹        (1/c)·g(n) ≤ f(n)
       ⟹        f(n) = Ω(g(n))   con c' = 1/c
```

## 4.5 Ejemplo 1: `f(n) = 5n² - 3n = Ω(n²)`

```text
Para n ≥ 1:
   3n ≤ 3n²
   ⟹  5n² - 3n ≥ 5n² - 3n² = 2n²

Conclusión: c = 2, n₀ = 1.
   Para todo n ≥ 1:   2n² ≤ 5n² - 3n   ✓
```

## 4.6 Ejemplo 2: `n² = Ω(n log n)`

```text
Para n ≥ 2:
   log n ≤ n       ⟹  n · log n ≤ n · n = n²

Conclusión: c = 1, n₀ = 2.
   Para todo n ≥ 2:   1·n·log n ≤ n²    ✓
```

## 4.7 Ejemplo 3: `n! = Ω(2ⁿ)`

```text
n! = 1 · 2 · 3 · ... · n

Para n ≥ 4:   los últimos n/2 factores son todos ≥ n/2 ≥ 2
   n! ≥ 2^(n/2) · (n/2)!    ...

Más simple: para n ≥ 4, los factores 1, 2, ..., n/2 son todos ≥ 2.
   n! ≥ (n/2)^(n/2) = 2^((n/2)·log(n/2))

Conclusión: n! crece estrictamente más rápido que 2ⁿ.
```

## 4.8 ¿Por qué Ω es importante?

| Uso                                            | Ejemplo                                          |
| ---------------------------------------------- | ------------------------------------------------ |
| **Probar optimalidad** de un algoritmo         | "Comparison sort requiere Ω(n log n) comparaciones" |
| **Demostrar límites inferiores** teóricos      | "No se puede ordenar mejor que Ω(n log n)"      |
| **Establecer que un problema es difícil**      | "SAT es NP-hard, NP-completo implica Ω(2ⁿ)" (?) |
| **Diferenciar algoritmos óptimos**             | "Merge sort es O(n log n) y Ω(n log n) → óptimo"|

> **CLRS Cap. 8:** El Ω(n log n) de comparison-sort es uno de los resultados más importantes del libro.

---

# 5. Definición Formal de Big-Θ

## 5.1 Definición

> **Definición (CLRS 3.1):**
> Sea `f, g: ℕ → ℝ⁺`. Decimos que
>
> ```text
> f(n) = Θ(g(n))
> ```
>
> si **existen** constantes positivas `c₁, c₂ > 0` y `n₀ ≥ 1` tales que
>
> ```text
> c₁ · g(n) ≤ f(n) ≤ c₂ · g(n)     para todo n ≥ n₀
> ```

Equivalente:

```text
f(n) = Θ(g(n))    ⟺    f(n) = O(g(n))    Y    f(n) = Ω(g(n))
```

## 5.2 Visualización

```text
g(n)
│         ╱──────────── c₂·g(n)        ← techo
│        ╱
│       ╱
│      ╱
│   f(n)
│    ╱
│  ╱
│╱
│ ───────────── c₁·g(n)        ← piso
└──────────────────────→ n
0           n₀

A partir de n₀, f(n) está SANDWICHEADO entre c₁·g y c₂·g.
```

## 5.3 Ejemplo 1: `(1/2)n² - 3n = Θ(n²)`

**Demostración:**

```text
Cota superior (O):
   Para n ≥ 1:    (1/2)n² - 3n ≤ (1/2)n² = (1/2)·n²    con c₂ = 1/2

Cota inferior (Ω):
   Para n ≥ 1:    -3n ≥ -3n²  (porque n ≤ n²)
                  (1/2)n² - 3n ≥ (1/2)n² - 3n² = -(5/2)n²
                  ⟹ (1/2)n² - 3n ≥ -(5/2)·n²

Pero esto da cota inferior NEGATIVA — no sirve.

   Probemos con n ≥ 12:
      -3n ≥ -(1/4)n²       (porque n ≥ 12 ⟹ 3 ≤ n/4)
      (1/2)n² - 3n ≥ (1/2)n² - (1/4)n² = (1/4)n²
      ⟹  c₁ = 1/4,  n₀ = 12

Conclusión:
   Para todo n ≥ 12:    (1/4)n² ≤ (1/2)n² - 3n ≤ (1/2)n²
   ⟹  f(n) = Θ(n²)   con c₁ = 1/4, c₂ = 1/2, n₀ = 12
```

## 5.4 Ejemplo 2: `an² + bn + c = Θ(n²)` para `a > 0`

```text
Caso general:
   Cota superior: para n ≥ 1,
      an² + bn + c ≤ an² + |b|n² + |c|n² = (a + |b| + |c|)·n²
      ⟹  c₂ = a + |b| + |c|,  n₀ = 1

   Cota inferior: para n suficientemente grande (n ≥ 2·|b|/a y n ≥ 2·|c|/a),
      bn ≥ -|b|n ≥ -(a/2)n²  (cuando n ≥ 2|b|/a)
      cn ≥ -|c|n ≥ -(a/2)n²  (cuando n ≥ 2|c|/a)
      ⟹  an² + bn + c ≥ an² - (a/2)n² - (a/2)n² = 0

   Hmm, esto da 0. Probemos mejor:
      bn ≥ -|b|n²   (siempre)
      cn ≥ -|c|n²   (siempre)
      an² + bn + c ≥ (a - |b| - |c|)·n²

      Tomando n grande para que esto sea > 0:
      (a - |b| - |c|) > 0   ⟺   |b| + |c| < a
      Esto NO se cumple en general.

   Toca ser más cuidadoso. Para n ≥ 1:
      Si a ≥ |b| + |c|, entonces (a - |b| - |c|)n² > 0.
      Si no, se necesita un n₀ más grande.

   En cualquier caso, EXISTEN c₁, c₂, n₀ (dependiendo de a, b, c).
```

## 5.5 Ejemplo 3: `f(n) = log(n²) = Θ(log n)`

```text
log(n²) = 2·log n

Cota superior: log(n²) ≤ 2·log n   con c₂ = 2, trivial.
Cota inferior: log(n²) = 2·log n ≥ 1·log n   con c₁ = 1.

Conclusión: c₁ = 1, c₂ = 2, n₀ = 1.
   Para todo n ≥ 1:    log n ≤ log(n²) ≤ 2·log n
```

> **Regla general:** `logᵏ(nᵏ') = Θ(log n)` para cualquier constante `k, k' > 0`. Los logaritmos absorben exponentes constantes.

## 5.6 Ejemplo 4: `f(n) = n³ + n² log n ≠ Θ(n²)`

**Demostración por contradicción:**

```text
Supongamos f(n) = Θ(n²).
   Entonces:  ∃ c₂, n₀  tales que  n³ + n² log n ≤ c₂·n²  ∀ n ≥ n₀

   ⟹  n + log n ≤ c₂

   Pero n + log n → ∞ cuando n → ∞.
   Para n > c₂:   n + log n > c₂   ✗

Conclusión: f(n) ≠ Θ(n²). De hecho, f(n) = Ω(n³).
```

## 5.7 Θ define una clase de equivalencia

> **Teorema:** Θ es una **relación de equivalencia** sobre las funciones asintóticamente positivas.
>
> ```text
> f = Θ(g)    ⟺    "f y g crecen al mismo ritmo"
> ```

| Propiedad              | Verificación                                      |
| ---------------------- | ------------------------------------------------- |
| **Reflexividad**       | `f = Θ(f)` (c₁ = c₂ = 1)                         |
| **Simetría**           | `f = Θ(g) ⟹ g = Θ(f)`                            |
| **Transitividad**      | `f = Θ(g)` y `g = Θ(h) ⟹ f = Θ(h)`               |

> **CLRS Cap. 3:** *"`Θ(g(n))` is the set of all functions that are asymptotically tightly bounded by `g(n)`."*

---

# 6. Little-o: Estrictamente Menor

## 6.1 Definición

> **Definición (CLRS 3.1):**
> Sea `f, g: ℕ → ℝ⁺`. Decimos que
>
> ```text
> f(n) = o(g(n))
> ```
>
> si para **toda** constante `c > 0`, **existe** `n₀ ≥ 1` tal que
>
> ```text
> f(n) < c · g(n)     para todo n ≥ n₀
> ```

La diferencia con Big-O: el cuantificador de `c` cambia.

| Notación | Cuantificador de `c` | Lectura                                       |
| -------- | -------------------- | --------------------------------------------- |
| **O**    | `∃ c`                | Existe ALGUNA constante `c` que funciona      |
| **o**    | `∀ c`                | Para TODA constante `c`, funciona             |

## 6.2 Forma con límites

> **Teorema (CLRS 3.1-7):**
>
> ```text
> f(n) = o(g(n))    ⟺    lim_{n→∞}  f(n)/g(n) = 0
> ```

Esto hace `o` muy útil: si el cociente se va a cero, `f` es estrictamente menor que `g`.

## 6.3 Visualización

```text
        c₁·g(n)
g(n) ────────────────
       ╱
      ╱
     ╱
   f(n)
    ╱
  ╱
╱       ← la brecha CRECE sin parar
───────────────────────────────────→ n
       n₀
```

A diferencia de `O`, no basta con encontrar UNA constante que funcione: `f` debe estar eventualmente debajo de **cualquier** constante por `g`.

## 6.4 Ejemplo 1: `n = o(n²)`

```text
lim_{n→∞} n/n² = lim 1/n = 0    ⟹  n = o(n²)   ✓
```

## 6.5 Ejemplo 2: `n log n = o(n²)`

```text
lim_{n→∞} (n log n)/n² = lim (log n)/n = 0   (log crece más lento)

⟹  n log n = o(n²)   ✓
```

## 6.6 Ejemplo 3: `log n = o(n^ε)` para cualquier `ε > 0`

```text
lim_{n→∞} log n / n^ε = 0    (por L'Hôpital)

⟹  log n = o(n^ε)    ∀ ε > 0
```

## 6.7 Ejemplo 4: `n² ≠ o(n²)`

**Demostración:**

```text
Supongamos n² = o(n²).
   Entonces:  ∀ c > 0,  ∃ n₀  tal que  n² < c·n²  ∀ n ≥ n₀.

   ⟹  1 < c   para todo c > 0.

   Pero tomando c = 1/2:   1 < 1/2   ✗  (¡falso!)

Por tanto n² ≠ o(n²).    ✓
```

> **Regla clave:** `f = o(g)` y `f = g` no pueden ocurrir simultáneamente (salvo trivialmente).

## 6.8 Cuándo usar little-o

| Situación                                           | Usar             |
| --------------------------------------------------- | ---------------- |
| Quiero decir "crece estrictamente más lento"        | **o**            |
| Estoy haciendo un **límite** y es 0                 | **o**            |
| Estoy en un texto **teórico formal**                | **o**            |
| Hago análisis de complejidad "informal"             | **O** (más común)|

> **CLRS Cap. 3.1:** *"The "little-o" notation is more stringent than the "big-O" notation. From the definition... if f(n) = o(g(n)), then f(n) = O(g(n))."*

---

# 7. Little-ω: Estrictamente Mayor

## 7.1 Definición

> **Definición (CLRS 3.1):**
> Sea `f, g: ℕ → ℝ⁺`. Decimos que
>
> ```text
> f(n) = ω(g(n))
> ```
>
> si para **toda** constante `c > 0`, **existe** `n₀ ≥ 1` tal que
>
> ```text
> c · g(n) < f(n)     para todo n ≥ n₀
> ```

## 7.2 Forma con límites

> **Teorema (CLRS 3.1-8):**
>
> ```text
> f(n) = ω(g(n))    ⟺    lim_{n→∞}  f(n)/g(n) = ∞
> ```

## 7.3 Dualidad con little-o

> **Teorema:**
>
> ```text
> f(n) = ω(g(n))    ⟺    g(n) = o(f(n))
> ```

## 7.4 Ejemplo 1: `n² = ω(n)`

```text
lim_{n→∞} n²/n = lim n = ∞    ⟹  n² = ω(n)   ✓
```

## 7.5 Ejemplo 2: `n log n = ω(n)`

```text
lim_{n→∞} (n log n)/n = lim log n = ∞    ⟹  n log n = ω(n)   ✓
```

## 7.6 Ejemplo 3: `2ⁿ = ω(n^k)` para cualquier constante `k`

```text
lim_{n→∞} 2ⁿ/n^k = ∞    (por L'Hôpital, derivado k veces)

⟹  2ⁿ = ω(n^k)    ∀ k constante
```

## 7.7 Ejemplo 4: `n! = ω(2ⁿ)`

```text
log(n!) = log(1·2·3·...·n) = Σ log(i) ≥ (n/2)·log(n/2)   para n ≥ 2

Por tanto:
   lim log(n!)/n = ∞
   ⟹  lim (log n!)/n = ∞
   ⟹  n! crece más rápido que cualquier c·2ⁿ

⟹  n! = ω(2ⁿ)   ✓
```

## 7.8 Tabla resumen de las cinco notaciones

| Notación | Cuantificadores                      | Límite equivalente                | Significado                  |
| -------- | ------------------------------------ | --------------------------------- | ---------------------------- |
| **O**    | `∃ c > 0, ∃ n₀: ∀ n ≥ n₀: f ≤ c·g`  | `lim sup f/g < ∞`                 | `f ≤ g` (a lo más)          |
| **Ω**    | `∃ c > 0, ∃ n₀: ∀ n ≥ n₀: c·g ≤ f`  | `lim inf f/g > 0`                 | `f ≥ g` (al menos)          |
| **Θ**    | `∃ c₁, c₂, n₀: c₁·g ≤ f ≤ c₂·g`     | `0 < lim inf < lim sup < ∞`       | `f = g` (ajustado)          |
| **o**    | `∀ c > 0, ∃ n₀: ∀ n ≥ n₀: f < c·g`  | `lim f/g = 0`                     | `f ≪ g` (estrictamente menor) |
| **ω**    | `∀ c > 0, ∃ n₀: ∀ n ≥ n₀: c·g < f`  | `lim f/g = ∞`                     | `f ≫ g` (estrictamente mayor) |

---

# 8. La Jerarquía de Crecimiento

## 8.1 La cadena canónica

```text
O(1) < O(log n) < O(√n) < O(n) < O(n log n) < O(n²) < O(n³) < O(2ⁿ) < O(n!)
```

Esto significa:

```text
O(1) ⊂ O(log n) ⊂ O(√n) ⊂ O(n) ⊂ O(n log n) ⊂ O(n²) ⊂ O(n³) ⊂ O(2ⁿ) ⊂ O(n!)
```

(La inclusión es estricta.)

## 8.2 Tabla maestra con valores concretos

Asumiendo **1 operación = 1 nanosegundo** (`10⁻⁹ s`):

| Función     | n = 10        | n = 100       | n = 1,000      | n = 10,000     | n = 10⁶        | n = 10⁹        |
| ----------- | ------------- | ------------- | -------------- | -------------- | -------------- | -------------- |
| **log n**   | 3 ns          | 7 ns          | 10 ns          | 13 ns          | 20 ns          | 30 ns          |
| **√n**      | 3 ns          | 10 ns         | 32 ns          | 100 ns         | 1 µs           | 32 µs          |
| **n**       | 10 ns         | 100 ns        | 1 µs           | 10 µs          | 1 ms           | 1 s            |
| **n log n** | 33 ns         | 664 ns        | 10 µs          | 133 µs         | 20 ms          | 30 s           |
| **n²**      | 100 ns        | 10 µs         | 1 ms           | 100 ms         | 16.7 min       | 31.7 años      |
| **n³**      | 1 µs          | 1 ms          | 1 s            | 16.7 min       | 31.7 años      | 31.7 × 10⁹ años |
| **2ⁿ**      | 1 µs          | 1.27 × 10²³ años | ⚠️ imposible | ⚠️ imposible  | ⚠️ imposible   | ⚠️ imposible   |
| **n!**      | 3.6 ms        | ⚠️ imposible  | ⚠️ imposible   | ⚠️ imposible   | ⚠️ imposible   | ⚠️ imposible   |

> **Nota:** "imposible" significa más que la edad del universo (~10¹⁰ años).

## 8.3 Crecimiento comparativo en escala log-log

```text
log₂(tiempo)
   50 ┤                              ● n!
      │                          ●
   40 ┤                       ●
      │                    ●
   30 ┤                 ●
      │              ●         2ⁿ
   20 ┤         ●●         n³
      │      ●          n²
   10 ┤   ●       n log n
      │ ●     n
    0 ┤●  √n   log n   1
      │
  -10 ┤
      └──────────────────────────────→ log₂(n)
       0   10   20   30   40   50

Cada incremento en Y = duplicación del tiempo.
Cada incremento en X = duplicación de n.

Línea recta = ley de potencia. Curva que sube = superpolinomial.
```

## 8.4 Ejemplo dramático: el umbral cuadrático

```text
Aritmética: 10⁹ ops/segundo (procesador moderno)

n = 10³:    n² = 10⁶ ops  →  1 ms       ✓ instantáneo
n = 10⁴:    n² = 10⁸ ops  →  100 ms     ✓ rápido
n = 10⁵:    n² = 10¹⁰ ops →  10 s       ⚠ molesto
n = 10⁶:    n² = 10¹² ops →  16 minutos ⚠ largo
n = 10⁷:    n² = 10¹⁴ ops →  27 horas   ⚠ impracticable
n = 10⁸:    n² = 10¹⁶ ops →  115 días   ❌ no
n = 10⁹:    n² = 10¹⁸ ops →  31 años    ❌ definitivamente no
```

> **Conclusión:** Para `n > 10⁶`, un algoritmo O(n²) probablemente **no es viable**.

## 8.5 Subdivisiones de la jerarquía

| Familia            | Funciones                       | Característica                              |
| ------------------ | ------------------------------- | ------------------------------------------- |
| **Sub-lineal**     | `1`, `log n`, `√n`              | Más rápido que lineal                       |
| **Lineal**         | `n`                             | Óptimo para recorrer una vez                |
| **Casi-lineal**    | `n log n`                       | El "sweet spot" (mergesort, heapsort)      |
| **Polinomial**     | `n^k` para `k ≥ 2`              | Crece rápido pero todavía manejable         |
| **Exponencial**    | `2ⁿ`, `eⁿ`                      | Solo viable para `n` pequeño                |
| **Super-exp.**     | `n!`, `nⁿ`                      | Solo viable para `n ≤ 20` aprox.            |

## 8.6 El efecto "doubling"

Cada vez que duplicas `n`:

| Función     | Tiempo se multiplica por... |
| ----------- | --------------------------- |
| `1`         | × 1   (constante)           |
| `log n`     | + 1  (suma un paso)         |
| `n`         | × 2                         |
| `n log n`   | ≈ × 2.1  (ligeramente peor) |
| `n²`        | × 4                         |
| `n³`        | × 8                         |
| `2ⁿ`        | × 4 (y crece cada vez)      |
| `n!`        | × muy rápido                |

> **Regla práctica del doubling:** Si al duplicar `n` tu programa se vuelve **2× más lento**, es lineal. Si se vuelve **4× más lento**, es cuadrático. Si se vuelve **8× más lento**, es cúbico.

---

# 9. Propiedades de las Notaciones

## 9.1 Transitividad

| Propiedad                          | Válida |
| ---------------------------------- | ------ |
| `f = O(g)` y `g = O(h)` ⟹ `f = O(h)` | ✅    |
| `f = Ω(g)` y `g = Ω(h)` ⟹ `f = Ω(h)` | ✅    |
| `f = Θ(g)` y `g = Θ(h)` ⟹ `f = Θ(h)` | ✅    |
| `f = o(g)` y `g = o(h)` ⟹ `f = o(h)` | ✅    |
| `f = ω(g)` y `g = ω(h)` ⟹ `f = ω(h)` | ✅    |

## 9.2 Reflexividad

| Propiedad                          | Válida |
| ---------------------------------- | ------ |
| `f = O(f)`                          | ✅     |
| `f = Ω(f)`                          | ✅     |
| `f = Θ(f)`                          | ✅     |
| `f = o(f)`                          | ❌     |
| `f = ω(f)`                          | ❌     |

**Demostración de `f ≠ o(f)`:**

```text
Supongamos f = o(f).
   Entonces:  ∀ c > 0,  ∃ n₀:  f(n) < c·f(n)  ∀ n ≥ n₀
   ⟹  1 < c  para todo c > 0
   ⟹  Tomando c = 1/2:  1 < 1/2  ✗

Conclusión: f ≠ o(f).    ✓
```

## 9.3 Simetría

| Propiedad                          | Válida |
| ---------------------------------- | ------ |
| `f = O(g)` ⟹ `g = O(f)`           | ❌     |
| `f = Ω(g)` ⟹ `g = Ω(f)`           | ❌     |
| `f = Θ(g)` ⟹ `g = Θ(f)`           | ✅     |
| `f = o(g)` ⟹ `g = o(f)`           | ❌     |
| `f = ω(g)` ⟹ `g = ω(f)`           | ❌     |

> **Nota:** `f = O(g)` y `g = O(f)` NO implica `f = Θ(g)` (puede ser `f = o(g)` y `g = o(f)` simultáneamente solo si `f = g`).

## 9.4 Simetría transitiva

```text
f = O(g)    ⟺    g = Ω(f)         (CLRS 3.1-5)
f = o(g)    ⟺    g = ω(f)         (CLRS 3.1-8)
```

## 9.5 Tabla completa de propiedades

| Propiedad       | O    | Ω    | Θ    | o    | ω    |
| --------------- | ---- | ---- | ---- | ---- | ---- |
| Reflexividad    | ✅   | ✅   | ✅   | ❌   | ❌   |
| Simetría        | ❌   | ❌   | ✅   | ❌   | ❌   |
| Transitividad   | ✅   | ✅   | ✅   | ✅   | ✅   |
| Antisimetría   | ❌   | ❌   | ✅   | ❌   | ❌   |

## 9.6 Implicaciones entre notaciones

```text
f = o(g)    ⟹    f = O(g)         (little-o es más estricto que big-O)

f = O(g)  y  f = Ω(g)    ⟹    f = Θ(g)

f = ω(g)    ⟹    f = Ω(g)        (little-ω es más estricto que big-Ω)
```

> **⚠️ Cuidado:** `f = O(g)` y `g = O(f)` **NO** implica `f = Θ(g)`. Solo implica `f` y `g` son del mismo "orden asintótico" salvo que también tengamos la cota inversa.

---

# 10. Aritmética Asintótica

## 10.1 Reglas básicas

> **CLRS Cap. 3.1, Lemas:** Si `f(n) = O(g(n))`, entonces para cualquier constante `c > 0`:
>
> ```text
> c · f(n) = O(g(n))
> f(n) + c = O(g(n))
> f(n) · c = O(g(n))     (esto es lo mismo que lo primero)
> ```

## 10.2 Suma de notaciones O

```text
O(f(n)) + O(g(n)) = O(max(f(n), g(n)))
```

**Demostración:**

```text
Sean f₁ = O(f), f₂ = O(g). Es decir:
   ∃ c₁, n₁:  f₁(n) ≤ c₁·f(n)    ∀ n ≥ n₁
   ∃ c₂, n₂:  f₂(n) ≤ c₂·g(n)    ∀ n ≥ n₂

Sean c = max(c₁, c₂),  n₀ = max(n₁, n₂).

Para n ≥ n₀:
   f₁(n) + f₂(n) ≤ c₁·f(n) + c₂·g(n)
                  ≤ c·f(n) + c·g(n)
                  = c · (f(n) + g(n))
                  ≤ 2c · max(f(n), g(n))
                  = O(max(f(n), g(n)))
```

## 10.3 Producto de notaciones O

```text
O(f(n)) · O(g(n)) = O(f(n) · g(n))
```

**Demostración:**

```text
Sean f₁ = O(f), f₂ = O(g). Es decir:
   ∃ c₁, n₁:  f₁(n) ≤ c₁·f(n)
   ∃ c₂, n₂:  f₂(n) ≤ c₂·g(n)

Para n ≥ max(n₁, n₂):
   f₁(n) · f₂(n) ≤ (c₁·f(n)) · (c₂·g(n)) = c₁·c₂·f(n)·g(n)
```

## 10.4 Otras reglas

```text
O(f(n)) + Ω(f(n)) = Θ(f(n))    ?     ❌ NO necesariamente
```

**Contraejemplo:** `O(n) + Ω(n²) = Θ(n²)` no tiene por qué ser cierto.

> **⚠️ Trampa común:** Sumar una cota superior y una cota inferior no da una cota ajustada. Necesitas probar AMBAS cotas por separado.

## 10.5 Tabla resumen

```text
┌───────────────────────────────────────────────────────────────┐
│ Regla                          │  Ejemplo                     │
├────────────────────────────────┼──────────────────────────────│
│ O(c) = O(1)                    │  O(5) = O(1)                 │
│ O(c · f) = O(f)                │  O(3n²) = O(n²)              │
│ O(f) + O(g) = O(max(f,g))      │  O(n²) + O(n) = O(n²)        │
│ O(f) · O(g) = O(f · g)         │  O(n) · O(log n) = O(n log n)│
│ max(O(f), O(g)) = O(max(f,g))  │  mismo que arriba            │
│ min(O(f), O(g)) = ?            │  ⚠ NO es O(min(f,g))        │
└───────────────────────────────────────────────────────────────┘
```

## 10.6 Ejemplos detallados

### Ejemplo 1: `f(n) = 5n³ + 100n² + 3n + 100`

```text
f(n) = O(n³) + O(n²) + O(n) + O(1)
     = O(max(n³, n², n, 1))     ← regla de suma
     = O(n³)                    ← el máximo es n³
```

### Ejemplo 2: `(n² + 1)(n + 3) = ?`

```text
= n² · n + n² · 3 + 1 · n + 1 · 3
= n³ + 3n² + n + 3

Cada término:  O(n³), O(n²), O(n), O(1)
Suma:         O(n³)
Producto:     O(n²) · O(n) = O(n³)    (consistente)
```

### Ejemplo 3: `f(n) = 3 log n + 5 log² n`

```text
log² n domina sobre log n cuando n es grande:
   lim log² n / log n = lim log n = ∞

Por tanto:  3 log n + 5 log² n = Θ(log² n)
```

### Ejemplo 4: `f(n) = n log n + n√n`

```text
¿log n o √n domina?
   lim log n / √n = 0    (log más lento)

Por tanto: √n > log n,  y   n√n > n log n  cuando n ≥ 4.

   f(n) = Θ(n√n)
```

## 10.7 ⚠️ Trampas en aritmética asintótica

### Trampa 1: `O(f) + O(g) ≠ O(f + g)` literalmente

```text
O(f(n)) + O(g(n))    NO es lo mismo que    O(f(n) + g(n))   como SETS.

Pero:
   Cualquier miembro de O(f) + O(g) es también miembro de O(f + g).
   Y O(f + g) = O(max(f, g)).
```

### Trampa 2: `O(f · g) ≠ O(f) · O(g)` literalmente

```text
Pero:
   O(f · g) = O(f) · O(g)         ✓
   { h : h = O(f · g) } ⊇ { h₁·h₂ : h₁ = O(f), h₂ = O(g) }
```

### Trampa 3: Máximo vs mínimo en sumas

```text
O(f) + O(g) = O(max(f, g))      ✓ (suma → el mayor gana)
O(f) · O(g) = O(f · g)          ✓ (producto → se multiplica)

Pero:
   O(max(f, g)) no necesariamente = O(f) + O(g) ni viceversa.
   Ejemplo: max(n², n) = n².  O(n²) + O(n) = O(n²).  Pero O(max) = O(n²) ⊆ O(n²).  ✓
```

### Trampa 4: `f + g` donde una es O y otra Ω

```text
O(n) + Ω(n²)  =  ?
   El término Ω(n²) DOMINA al O(n).
   Por tanto:  O(n) + Ω(n²) = Ω(n²).
   Pero NO es Θ(n²) necesariamente (podría ser mayor).
```

## 10.8 Aritmética de Θ

Θ es la más restrictiva y más útil:

```text
Θ(f) + Θ(g) = Θ(max(f, g))        si f y g son monótonas no-negativas
Θ(f) · Θ(g) = Θ(f · g)            si f y g son monótonas no-negativas
Θ(c · f)   = Θ(f)                 para c > 0
```

---

# 11. Composición de Funciones

## 11.1 La pregunta

Si tengo dos funciones `f(g(n))`, ¿cómo se combinan sus clases asintóticas?

## 11.2 Resultados principales

> **Teorema:** Si `f` y `g` son asintóticamente no-negativas y monótonas no-decrecientes, entonces:
>
> ```text
> f(n) = Θ(g(n))    ⟹    h(f(n)) = Θ(h(g(n)))
> ```
>
> siempre que `h` sea monótona no-decreciente.

Más débil pero útil:

```text
f(n) = O(g(n))    ⟹    h(f(n)) = O(h(g(n)))      si h es monótona no-decreciente
f(n) = Ω(g(n))    ⟹    h(f(n)) = Ω(h(g(n)))      si h es monótona no-decreciente
```

## 11.3 Ejemplo 1: composición con `log`

```text
f(n) = 2n²  =  Θ(n²)
log f(n) = log(2n²) = log 2 + 2 log n = Θ(log n)    ✓
```

## 11.4 Ejemplo 2: composición con `n²`

```text
f(n) = n log n
(f(n))² = n² (log n)²

Si tuviéramos f = Θ(n) entonces (f)² = Θ(n²).
Con f = n log n: (n log n)² = n² (log n)² = ω(n²)    ← el log²n aporta
```

## 11.5 ⚠️ Cuándo falla la composición

La composición `f(g(n))` es delicada si `f` no es "limpia".

**Contraejemplo:**

```text
f(n) = n²  y  g(n) = n/2

f(g(n)) = (n/2)² = n²/4  →  Θ(n²)    ✓ OK

Pero:
   f(n) = 2ⁿ   y   g(n) = log n    (con composición)
   f(g(n)) = 2^(log n) = n

   Si f = Θ(2ⁿ) y g = Θ(log n), entonces f(g(n)) debería ser Θ(2^log n) = Θ(n). ✓
```

## 11.6 Regla para exponenciación de notación

```text
Si  f(n) = O(g(n))  entonces:
   2^(f(n)) = O(2^(g(n)))    ← vale porque 2^x es monótona creciente
```

> **Útil en recurrencias:** Si `T(n) = O(n²)` y el costo se duplica exponencialmente, el costo sigue `O(2^n²)` y no `O(2^(2n))`.

---

# 12. Límites y la Notación Asintótica

## 12.1 El puente fundamental

Los límites de cálculo son la herramienta principal para **decidir** la relación asintótica entre dos funciones.

> **Teorema (CLRS 3.1-6, 3.1-7, 3.1-8):**
>
> ```text
> lim_{n→∞}  f(n)/g(n) = 0       ⟺    f(n) = o(g(n))
> lim_{n→∞}  f(n)/g(n) = c       donde 0 < c < ∞    ⟺    f(n) = Θ(g(n))
> lim_{n→∞}  f(n)/g(n) = ∞       ⟺    f(n) = ω(g(n))
> ```

## 12.2 Algoritmo de decisión

```text
┌────────────────────────────────────────────────────┐
│  Para decidir la relación entre f y g:             │
│                                                    │
│  1. Calcular  lim_{n→∞}  f(n)/g(n).                │
│  2. Si el límite es 0         → f = o(g)           │
│  3. Si el límite es c ≠ 0, ∞  → f = Θ(g)           │
│  4. Si el límite es ∞         → f = ω(g)           │
│  5. Si el límite NO EXISTE    → no se puede concluir│
└────────────────────────────────────────────────────┘
```

## 12.3 L'Hôpital: la herramienta clave

Para límites con formas indeterminadas `0/0` o `∞/∞`:

> **Regla de L'Hôpital:**
> Si `lim f/g` es de forma indeterminada `0/0` o `∞/∞`, y `lim f'/g'` existe, entonces:
>
> ```text
> lim_{n→∞}  f(n)/g(n)   =   lim_{n→∞}  f'(n)/g'(n)
> ```

## 12.4 Ejemplo 1: `log n vs n^ε`

> **Probar:** `log n = o(n^ε)` para cualquier `ε > 0`.

```text
lim_{n→∞}  log n / n^ε

Forma: ∞/∞. Aplicamos L'Hôpital:
   = lim_{n→∞}  (1/n) / (ε·n^(ε-1))
   = lim_{n→∞}  1 / (ε·n^ε)
   = 0

Conclusión: log n = o(n^ε)  ⟹  log n = O(n^ε).  ✓
```

## 12.5 Ejemplo 2: `n^k vs 2^n`

> **Probar:** `n^k = o(2^n)` para cualquier `k` constante.

```text
Sea f(n) = n^k,  g(n) = 2^n = e^(n ln 2).

lim_{n→∞}  n^k / 2^n

Aplicando L'Hôpital k veces (cada vez baja el grado):
   = lim  k·n^(k-1) / (ln 2) · 2^n
   = lim  k(k-1)·n^(k-2) / (ln 2)² · 2^n
   = ...
   = lim  k! / (ln 2)^k · 2^n
   = 0

Conclusión: n^k = o(2^n).  ✓
```

> **Intuición:** Cualquier polinomio es `o(2ⁿ)`. Las exponenciales ganan.

## 12.6 Ejemplo 3: `n log n vs n^1.5`

> **Determinar la relación.**

```text
lim_{n→∞}  (n log n) / n^1.5

= lim_{n→∞}  log n / n^0.5

Aplicamos L'Hôpital:
= lim_{n→∞}  (1/n) / (0.5 · n^(-0.5))
= lim_{n→∞}  (1/n) · (n^0.5 / 0.5)
= lim_{n→∞}  2 · n^(-0.5)
= 0

Conclusión: n log n = o(n^1.5).  ✓
```

## 12.7 Ejemplo 4: `n! vs n^n`

> **Probar:** `n! = o(n^n)`.

```text
n! / n^n = (1·2·3·...·n) / (n·n·n·...·n)
        = (1/n)·(2/n)·(3/n)·...·(n/n)
        = (1/n)·(2/n)·(3/n)·...·1

Cada factor i/n ≤ 1, y hay n factores.
Los últimos n/2 factores son ≤ 1/2.

Por tanto:
   n! / n^n ≤ (1/2)^(n/2)

Y:
   lim_{n→∞}  (1/2)^(n/2) = 0

Conclusión: n! = o(n^n).  ✓
```

## 12.8 Ejemplo 5: `n! vs 2^n`

> **Probar:** `n! = ω(2^n)`.

```text
lim_{n→∞}  n! / 2^n

n! / 2^n = (1/2)·(2/2)·(3/2)·(4/2)·...·(n/2)
        = (1/2)·1·(3/2)·2·(5/2)·3·...·(n/2)·(n-1)/2

Cada término crece: para i > 2,  i/2 ≥ 3/2, 4/2, 5/2, ...

Producto: ≥ (3/2)^(n-2)
   lim (3/2)^(n-2) = ∞

Conclusión: n! = ω(2^n).  ✓
```

## 12.9 Ejemplo 6: `log n vs log² n`

> **Determinar la relación.**

```text
lim_{n→∞}  log n / log² n = lim 1/log n = 0

Conclusión: log n = o(log² n).  ✓
```

> **Generalización:** Para cualquier constante `ε > 0`: `log n = o(log^(1+ε) n)`.

## 12.10 ⚠️ Cuándo los límites NO deciden

### Problema 1: el límite oscila

```text
f(n) = n + (-1)^n · n
g(n) = n

f(n)/g(n) = 1 + (-1)^n  →  oscila entre 0 y 2

El límite NO EXISTE, pero...
   0 ≤ f(n)/g(n) ≤ 2  para todo n
   ⟹  g(n) ≤ f(n) ≤ 2·g(n)
   ⟹  f = Θ(g)
```

### Problema 2: el límite no existe en una dirección

```text
f(n) = sin(n)
g(n) = 1

sin(n)/1 oscila, no tiene límite.
Pero f = Θ(g) (ambos acotados).

Esto muestra que el método de límites es SUFICIENTE pero no NECESARIO.
```

## 12.11 Tabla resumen de relaciones vía límites

| Límite de `f/g`     | Relación       | Lectura                      |
| ------------------- | -------------- | ---------------------------- |
| `0`                 | `f = o(g)`     | `f` es asintóticamente menor |
| `c ∈ (0, ∞)`        | `f = Θ(g)`     | `f` y `g` son del mismo orden |
| `∞`                 | `f = ω(g)`     | `f` es asintóticamente mayor |
| oscila (entre 0 y c)| `f = O(g)`     | solo cota superior           |
| oscila (entre c y ∞)| `f = Ω(g)`     | solo cota inferior           |
| no existe (salvaje) | puede ser O, Ω, o ninguno | depende del análisis caso a caso |

---

# 13. Funciones Comunes y sus Crecimientos

## 13.1 Polinomios

| Función    | Crecimiento        | Notas                                |
| ---------- | ------------------ | ------------------------------------ |
| `1`        | Constante          | Acceso a array, hash lookup          |
| `n`        | Lineal             | Recorrer una vez                     |
| `n²`       | Cuadrático         | Pares, matrices pequeñas            |
| `n³`       | Cúbico             | Multiplicación naïve de matrices     |
| `n^k`      | Polinomial         | k constante                         |

**Propiedades:**

```text
n^j = O(n^k)     si j ≤ k
n^j = o(n^k)     si j < k
n^j = Θ(n^k)     si j = k
```

## 13.2 Logaritmos

| Función         | Crecimiento            | Notas                          |
| --------------- | ---------------------- | ------------------------------ |
| `log n`         | Logarítmico            | Base 2 (default), base e, base 10 |
| `log² n`        | Cuasi-logarítmico      | `log n` elevado al cuadrado   |
| `log log n`     | Prácticamente constante| `log(10⁹) ≈ 30`, `log(30) ≈ 5` |
| `log* n`        | Logaritmo iterado      | Crece increíblemente lento     |
| `log^(k) n`     | Poli-logarítmico       | `log n` aplicado k veces      |

**Propiedades:**

```text
log(n^a) = a · log n = Θ(log n)
log^b(n) = O(n^ε)        para cualquier ε > 0
log n = o(n^ε)           para cualquier ε > 0
log n = ω(1)             (cualquier log eventualmente supera cualquier constante)
```

## 13.3 Exponenciales

| Función         | Crecimiento            | Notas                          |
| --------------- | ---------------------- | ------------------------------ |
| `2^n`           | Exponencial base 2     | Subsets, subsetsum             |
| `e^n`           | Exponencial natural    | Constante vs `2ⁿ`: Θ(2ⁿ)       |
| `n^n`           | Super-exponencial      | `ω(cⁿ)` para cualquier `c`   |
| `(3/2)^n`       | Exponencial base 1.5   | Fibonacci, branch-and-bound    |
| `a^n` para a>1  | Exponencial            | Crece super-polinomial        |

**Propiedades:**

```text
n^k = o(a^n)         para cualquier constante a > 1 y k
a^n = o(b^n)         si 1 < a < b
a^n = ω(b^n)         si 1 < b < a
```

## 13.4 Factoriales

| Función         | Crecimiento            | Notas                          |
| --------------- | ---------------------- | ------------------------------ |
| `n!`            | Factorial              | Permutaciones, TSP naïve      |
| `(2n)!/(n!)²`   | Central binomial       | Coeficientes de `(1+x)^(2n)`   |
| `n^n`           | Mayor que `n!`         | Todas las palabras de longitud n |

**Propiedades:**

```text
n! ≈ √(2πn) · (n/e)^n    (Fórmula de Stirling)

log n! = Θ(n log n)        (suma de logs)

Por tanto:  n! = Θ(n^n / e^n · √n)   (de Stirling)
```

## 13.5 Funciones iteradas

### `log* n` (logaritmo iterado)

> `log* n` = número de veces que hay que aplicar `log` para llegar a `≤ 1`.

```text
log*(1)     = 0
log*(2)     = 1      (log 2 = 1)
log*(4)     = 2      (log 4 = 2, log 2 = 1)
log*(16)    = 3      (log 16 = 4, log 4 = 2, log 2 = 1)
log*(65536) = 4
log*(2^65536) = 5     ≈ 10^19728

log*(10^100) ≈ 5
log*(10^(10^100)) ≈ 6

Para TODOS los valores prácticos de n:  log*(n) ≤ 5.
```

**Propiedad:** `log* n = o(log n)`, pero crece MUY lentamente.

> **Aplicación:** Algoritmo de Union-Find con path compression + union by rank: `O((m+n) · log* n) ≈ O(m+n)` en la práctica.

## 13.6 Función inversa de Ackermann

```text
α(m, n) ≈ inversa de la función de Ackermann
Para m y n prácticos:  α(m, n) ≤ 4.

Aplicación: Union-Find con union by rank + path compression = O(m · α(n)).
```

## 13.7 Catálogo completo de crecimientos

Ordenados de menor a mayor crecimiento:

```text
1       <  log* n   <  log log n   <  √log n   <  log n   <
log² n  <  √n       <  n            <  n log n   <  n^(1.5) <
n²      <  n² log n <  n³           <  n^k       <  2^n     <
(3/2)^n <  e^n      <  n!           <  n^n
```

## 13.8 Tabla: cuántas operaciones para `n = 1,000,000`

| Función       | Valor numérico                | Equivalencia                  |
| ------------- | ----------------------------- | ----------------------------- |
| `1`           | 1                             | 1 nanosegundo                 |
| `log* n`      | ≤ 3                           | 3 ns                          |
| `log log n`   | ≈ 3                           | 3 ns                          |
| `log n`       | ≈ 20                          | 20 ns                         |
| `√n`          | 1,000                         | 1 µs                          |
| `n`           | 1,000,000                     | 1 ms                          |
| `n log n`     | 20,000,000                    | 20 ms                         |
| `n^1.5`       | 10⁹                           | 1 segundo                     |
| `n²`          | 10¹²                          | 16 minutos                    |
| `n³`          | 10¹⁸                          | 31.7 años                     |
| `2ⁿ`          | 10^(301,030)                  | Calor del universo            |
| `n!`          | ≈ 10^(5,565,705)              | Absurdo                       |

---

# 14. Smoothness (Suavidad) — CLRS 4.5

## 14.1 Definición

> **Definición (CLRS 4.5, también en CLRS p.113-114):**
> Una función `f: ℕ → ℝ⁺` es **suave** (smooth) si `f(n)` es eventualmente no-decreciente y
>
> ```text
> f(2n) = O(f(n))
> ```

Equivalente: existe constante `c > 0` tal que `f(2n) ≤ c · f(n)` para `n` suficientemente grande.

## 14.2 Intuición

Una función es suave si **duplicar la entrada** no la hace explotar. Las funciones de crecimiento razonable (polinomios, logaritmos, exponenciales) son suaves.

```text
f(2n) ≤ c · f(n)   significa:    al duplicar n, f no se multiplica por más de c.
```

## 14.3 Ejemplos

| Función `f(n)`   | ¿Suave? | Verificación                            |
| ---------------- | ------- | --------------------------------------- |
| `1`              | ✅      | `f(2n) = 1 = 1 · f(n)`                  |
| `n`              | ✅      | `2n ≤ 2 · n`                            |
| `n²`             | ✅      | `(2n)² = 4n² ≤ 4 · n²`                  |
| `log n`          | ✅      | `log(2n) = 1 + log n ≤ 2 · log n` (eventualmente) |
| `n^k`            | ✅      | `(2n)^k = 2^k · n^k ≤ 2^k · n^k`       |
| `2ⁿ`             | ✅      | `2^(2n) = (2ⁿ)² ≤ 2 · 2ⁿ` ??? ❌         |
| `n!`             | ❌      | `(2n)!/(n!)² ≈ 4ⁿ` → `f(2n)/f(n) → ∞`   |

**Espera, ¿`2ⁿ` no es suave?** Veamos:

```text
f(2n) = 2^(2n) = (2^n)^2
f(n)  = 2^n

f(2n) / f(n) = (2^n)^2 / 2^n = 2^n   →  ∞ cuando n → ∞

Por tanto, 2^n NO es suave bajo la definición estricta de CLRS.
```

**Pero**, otra definición alternativa:

```text
Una función es "suave" si  f(n) / n  es eventualmente no-decreciente.
Bajo esta definición, 2^n ES suave.
```

> **CLRS usa la primera definición (más estricta).** Esto importa porque el método maestro requiere suavidad para Caso 1 con `f(n) = Ω(n^(log_b a + ε))`.

## 14.4 ¿Por qué importa la suavidad?

La suavidad garantiza que el comportamiento de `f` a `n` es comparable a su comportamiento a `n/2`, `n/4`, etc.

Esto es crucial para:

```text
1. Método maestro (CLRS 4.5)
2. Análisis de recurrencias con D&C
3. Garantizar que la división del problema es "limpia"
```

## 14.5 Función "smoothly" más fuerte

> **Definición alternativa (CLRS 4.5):** Una función `f` es **strongly smooth** si existen constantes `c > 0` y `k ≥ 0` tales que:
>
> ```text
> f(n) ≤ c · g(n) · f(n/b)    donde g es polinomial en n
> ```

En la práctica, la mayoría de funciones "naturales" son smooth.

---

# 15. Funciones Monótonas

## 15.1 Definiciones

> **Monótona no-decreciente:** `f(n) ≤ f(n+1)` para todo `n`.
>
> **Monótona creciente (estricta):** `f(n) < f(n+1)` para todo `n`.
>
> **Monótona no-creciente:** `f(n) ≥ f(n+1)` para todo `n`.
>
> **Monótona decreciente (estricta):** `f(n) > f(n+1)` para todo `n`.

## 15.2 ¿Por qué importan?

La mayoría de funciones de complejidad son eventualmente monótonas:

```text
- Polinomios con coeficiente principal positivo: eventualmente crecientes
- Logaritmos: crecientes
- Exponenciales: crecientes
- Factoriales: crecientes

Pero:
   sin(n), (-1)^n, n·sin(n)  →  NO monótonas
```

## 15.3 Propiedades que requieren monotonía

| Propiedad                                              | ¿Requiere monotonía? |
| ------------------------------------------------------ | -------------------- |
| `Θ(f) + Θ(g) = Θ(max(f, g))`                          | ✅ Sí                |
| `Θ(f) · Θ(g) = Θ(f · g)`                              | ✅ Sí                |
| `f(n) = Θ(g(n)) ⟹ h(f(n)) = Θ(h(g(n)))`              | ✅ Sí (h monótona)   |
| Análisis de recurrencias (método maestro)              | ✅ Sí (típicamente)  |

## 15.4 Asumir monotonía es razonable en análisis

En CLRS y la mayoría de textos, se asume que las funciones de complejidad son eventualmente monótonas no-decrecientes. Esto es:

```text
1. Realista: la mayoría de algoritmos se vuelven más lentos con más datos.
2. Útil: simplifica las pruebas enormemente.
3. Inocuo: las cotas O, Ω, Θ son las mismas para f que para max(f, 1).
```

---

# 16. Pisos y Techos (Floors and Ceilings)

## 16.1 El problema

En recurrencias aparecen `⌊n/2⌋` y `⌈n/2⌉`. ¿Importan?

```text
T(n) = T(⌊n/2⌋) + n
T(n) = T(⌈n/2⌉) + n
T(n) = T(n/2) + n        ← piso implícito
```

## 16.2 Resultado (CLRS 4.5.3)

> **Teorema:** Para cualquier función `f`, las versiones con piso y techo:
>
> ```text
> T(n) = a·T(⌊n/b⌋) + f(n)
> T(n) = a·T(⌈n/b⌉) + f(n)
> T(n) = a·T(n/b)    + f(n)
> ```
>
> tienen la **misma solución asintótica** siempre que se cumplan las condiciones del método maestro.

> **Intuición:** La diferencia entre `⌊n/2⌋` y `n/2` es como mucho 1, y ese "1" es despreciable asintóticamente.

## 16.3 Demostración intuitiva

```text
Para n grande:
   ⌊n/2⌋ ≈ n/2  (error < 1)
   ⌈n/2⌉ ≈ n/2  (error < 1)

Recursión: el error se acumula, pero:
   Total acumulado de error < O(log n)  (1 por nivel)
   Y O(log n) < cualquier término polinomial > O(1)

Por tanto, los pisos y techos no cambian la clase Θ.
```

## 16.4 Ejemplo

```text
T(n) = T(⌊n/2⌋) + 1

Por el teorema: igual que T(n) = T(n/2) + 1.
Por método maestro (Caso 2):
   T(n) = Θ(log n)    ✓

Verificación:
   n = 100:  ⌊100/2⌋ = 50 → 25 → 12 → 6 → 3 → 1 → 0
   Total: 6 niveles ≈ log₂(100) ≈ 6.6  ✓
```

---

# 17. Análisis Amortizado (CLRS Cap. 17)

## 17.1 ¿Qué es el análisis amortizado?

> **Definición:** El análisis amortizado distribuye el costo de operaciones **individualmente caras** a lo largo de muchas operaciones **baratas**, mostrando que el costo **promedio** por operación es pequeño.

**Idea clave:** Una operación puede ser cara, pero si ocurre rara vez, el costo amortizado (promediado) es bajo.

## 17.2 Ejemplo motivador: pila con MultiPop

### El problema

```c
void multipop(stack *s, int k) {
    while (!stack_empty(s) && k > 0) {
        pop(s);
        k--;
    }
}
```

### Análisis naïve (peor caso)

```text
Peor caso: multipop(S, n)   ⟹   O(n)

Parece que multipop es O(n), y por tanto n operaciones cuestan O(n²).
```

### Análisis amortizado (correcto)

```text
Cada elemento se puede popear A LO SUMA una vez por cada push.
n pushes + n multipops = 2n pops = O(n).

Costo amortizado por operación: O(n)/n = O(1) por operación.

Conclusión: cualquier secuencia de n operaciones cuesta O(n).
```

## 17.3 Tres métodos de análisis amortizado

| Método              | Idea                                              | Útil cuando...                |
| ------------------- | ------------------------------------------------- | ----------------------------- |
| **Agregado**        | Calcular costo total, dividir entre operaciones   | Todas las operaciones tienen costo similar |
| **Contabilidad**    | Asignar "crédito" a operaciones baratas           | Quiero asociar costo a operación específica |
| **Potencial**       | Definir una "energía" potencial Φ                 | Quiero una prueba elegante    |

## 17.4 Método agregado

### Idea

```text
1. Encuentra una cota superior T(n) al costo TOTAL de n operaciones.
2. El costo amortizado es T(n)/n.
```

### Ejemplo: pila con multipop

```text
Operaciones: n pushes, n pops/multipops.

Cada elemento se mete con un push y se saca con un pop.
Por tanto, total de pops ≤ total de pushes = n.

Costo total: n (pushes) + n (pops) = 2n = O(n).

Costo amortizado por operación: O(1).
```

### Ejemplo: incrementar contador binario

**Problema:** Mantener un contador binario de k bits, inicialmente en 0. Operación: `increment`.

```c
void increment(int A[], int k) {
    int i = 0;
    while (i < k && A[i] == 1) {
        A[i] = 0;
        i++;
    }
    if (i < k) A[i] = 1;
}
```

**Análisis de peor caso:** El bit menos significativo cambia en cada operación. El siguiente bit cambia la mitad. El siguiente la cuarta parte...

```text
Total flips en n operaciones:
   bit 0:  n veces
   bit 1:  n/2 veces
   bit 2:  n/4 veces
   ...
   bit k:  ≤ 1 vez

Total ≤ n + n/2 + n/4 + ... ≤ 2n = O(n).

Costo amortizado por operación: O(1).
```

## 17.5 Método de contabilidad

### Idea

```text
1. Asignar un "costo amortizado" ĉᵢ a cada tipo de operación i.
2. Algunos pagan de más (operaciones baratas), otros de menos (caras).
3. El "crédito" acumulado paga las caras.
4. Requisito:  Σ ĉᵢ ≥ Σ cᵢ  (el total amortizado es ≥ el total real).
```

### Ejemplo: pila con multipop

```text
Asignamos:
   push:    ĉ = 2  (paga 1 por sí mismo, guarda 1 de crédito)
   pop:     ĉ = 0  (usa el crédito guardado por push)
   multipop: ĉ = 0

Verificación:
   Cada elemento guardado tiene 1 crédito (del push).
   Cuando se hace pop, se usa ese crédito.

Total amortizado = 2·pushes = 2n ≥ costo real = O(n).   ✓
```

## 17.6 Método de potencial

### Idea

> **Definición:** Una **función potencial** `Φ` mapea el estado de la estructura de datos a un número real no-negativo.
>
> El costo amortizado de la operación `i` es:
>
> ```text
> ĉᵢ = cᵢ + Φ(Dᵢ) - Φ(Dᵢ₋₁)
> ```
>
> donde `Dᵢ` es el estado después de la operación `i` y `cᵢ` es el costo real.

> **Requisito:** `Φ(D₀) = 0` y `Φ(Dᵢ) ≥ 0` para todo `i`.

> **Acumulación:** El costo amortizado total es:
>
> ```text
> Σ ĉᵢ = Σ cᵢ + Φ(Dₙ) - Φ(D₀) ≥ Σ cᵢ
> ```
>
> (porque `Φ(Dₙ) ≥ 0` y `Φ(D₀) = 0`.)

### Ejemplo: pila con multipop

```text
Φ = número de elementos en la pila.

push:  cᵢ = 1,  Φᵢ - Φᵢ₋₁ = +1
       ĉᵢ = 1 + 1 = 2

pop:   cᵢ = 1,  Φᵢ - Φᵢ₋₁ = -1
       ĉᵢ = 1 - 1 = 0

multipop(k):  cᵢ = k'  (k' elementos realmente popeados)
              Φᵢ - Φᵢ₋₁ = -k'
              ĉᵢ = k' - k' = 0

Costo amortizado total: 2·(pushes) + 0·(pops) + 0·(multipops) = 2n.
```

## 17.7 Ejemplo clásico: arreglo dinámico (vector)

### El problema

```c
void push_back(vector *v, int x) {
    if (v->size == v->capacity) {
        v->capacity *= 2;
        v->data = realloc(v->data, v->capacity * sizeof(int));
    }
    v->data[v->size++] = x;
}
```

**Análisis naïve:** Un push puede costar O(n) (cuando hay realloc). Parece O(n²) total.

**Análisis amortizado (método de contabilidad):**

```text
Costo de cada push = 1 (almacenar) o n (cuando hay realloc).

Si cobramos 3 por cada push:
   - 1 paga el almacenamiento
   - 1 paga la copia de un elemento antiguo
   - 1 se guarda como crédito

Cuando llega el realloc (de tamaño n a 2n):
   - Necesitamos copiar n elementos
   - Tenemos n créditos guardados (uno por cada push anterior)
   - El realloc se paga con esos créditos.  ✓

Costo amortizado por push: O(1).
```

**Análisis con potencial:**

```text
Φ = 2·size - capacity    (siempre ≥ 0)

push_back sin realloc:
   ΔΦ = 2 (size++)
   c = 1
   ĉ = 1 + 2 = 3

push_back CON realloc (size = capacity = n, nuevo capacity = 2n):
   ΔΦ = 2(n+1) - 2n - (2n - n) = 2n + 2 - 2n - n = 2 - n
   c = n (copia) + 1 (push) = n + 1
   ĉ = (n + 1) + (2 - n) = 3

Conclusión: costo amortizado constante = 3.   ✓
```

## 17.8 Tabla resumen de los tres métodos

| Método              | Qué requiere                                       | Resultado                  |
| ------------------- | -------------------------------------------------- | -------------------------- |
| **Agregado**        | Costo total exacto                                | Costo amortizado = total/n |
| **Contabilidad**    | Asignación de costo amortizado por tipo de op.    | Invariante: crédito ≥ 0   |
| **Potencial**       | Función Φ bien elegida                            | Invariante: Φ ≥ 0        |

## 17.9 Ejemplo: dynamic array con método agregado

```text
n operaciones push_back.

Capacidades: 1, 2, 4, 8, ..., 2^(⌈log₂ n⌉)

Total de copiado (reallocs):
   1 + 2 + 4 + 8 + ... + n/2 + n
   ≤ 2n    (serie geométrica)

Total: n pushes + 2n copies = O(n).

Costo amortizado: O(1) por operación.
```

## 17.10 Ejemplo completo: tabla hash con direccionamiento abierto

```text
Inserción sin colisión: O(1)
Inserción con k colisiones: O(k)

En una tabla de factor de carga α:
   Costo promedio de búsqueda/inserción: O(1 / (1-α))

Si mantenemos α < c (constante), entonces el costo amortizado es O(1).
```

## 17.11 ¿Cuándo usar análisis amortizado?

| Situación                                              | Usar análisis amortizado                  |
| ------------------------------------------------------ | ----------------------------------------- |
| Una operación es muy cara pero **rara vez** ocurre     | ✅ SÍ                                    |
| Todas las operaciones tienen costo similar              | ❌ No necesario (usa peor caso)          |
| Estructura de datos dinámica (vector, hash, heap)       | ✅ Típico                                |
| Algoritmos con "rachas" de costos                       | ✅ Ideal                                 |
| Quieres probar cotas **promedio** sobre secuencias      | ✅                                       |

> **CLRS Cap. 17:** *"Amortized analysis is a worst-case analysis that averages over a sequence of operations."*

---

# 18. Notaciones Adicionales

## 18.1 Soft-O (Õ) — O con factores logarítmicos ocultados

> **Definición:** `f(n) = Õ(g(n))` si `f(n) = O(g(n) · log^k n)` para alguna constante `k`.

Es decir: Õ **ignora** factores polilogarítmicos.

### Ejemplo

```text
O(n log n)  =  Õ(n)        (porque O(n log n) = O(n · log¹ n))
O(n²)        =  Õ(n²)       (trivialmente)
O(n log² n)  =  Õ(n)        (k = 2)
O(n · log log n) = Õ(n)     (k = 1, absorbemos log log en log)
```

### Cuándo se usa

| Notación | Aparece en                       |
| -------- | -------------------------------- |
| `Õ(n)`   | Algoritmos aleatorizados, análisis de grafos, algoritmos de streaming |
| `Õ(n²)`  | Algunos algoritmos geométricos, DP |

> **Regla práctica:** Si ves `Õ` en un paper, lee con cuidado: ignora los factores `log`.

## 18.2 Soft-Theta (Θ̃)

Análogamente:

```text
f(n) = Θ̃(g(n))    ⟺    f(n) = Θ(g(n) · log^k n)  para alguna k
```

## 18.3 Notación tilde (~)

> **Definición:** `f(n) ~ g(n)` si
>
> ```text
> lim_{n→∞}  f(n)/g(n) = 1
> ```

Es decir: `f` y `g` son **asintóticamente iguales** (más fuerte que Θ).

### Ejemplo

```text
n² + 3n ~ n²                (límite = 1)
n² + log n ~ n²             (límite = 1)
n + log n ~ n               (límite = 1)

Pero:
   n² + n ≠ n²    (límite = 1 + 0 = 1, entonces SÍ ~)
   n² + n²/2 ≠ n² (límite = 3/2, NO ~)
```

## 18.4 Notación omega con subíndice (variantes raras)

Algunos textos usan variantes como:

| Notación    | Significado                                |
| ----------- | ------------------------------------------ |
| `f = Ω_∞(g)`| `f = Ω(g)` pero el cociente `f/g` no está acotado |
| `f = Ω_R(g)`| `f = Ω(g)` donde el cociente `f/g` es infinito |

Estas son raras y solo aparecen en textos muy teóricos.

## 18.5 Tabla de notaciones — referencia rápida

| Notación     | Cuantificadores                          | Límite                       |
| ------------ | ---------------------------------------- | ---------------------------- |
| `O(g)`       | `∃ c: f ≤ c·g`                           | `lim sup f/g < ∞`            |
| `Ω(g)`       | `∃ c: f ≥ c·g`                           | `lim inf f/g > 0`            |
| `Θ(g)`       | `∃ c₁, c₂: c₁·g ≤ f ≤ c₂·g`             | `0 < lim inf, lim sup < ∞`   |
| `o(g)`       | `∀ c: f < c·g`                           | `lim f/g = 0`                |
| `ω(g)`       | `∀ c: f > c·g`                           | `lim f/g = ∞`                |
| `Õ(g)`       | `∃ k: f = O(g · log^k n)`                | (ignora polilogs)            |
| `f ~ g`      | (no cuantificadores, igualdad asintótica)| `lim f/g = 1`                |

---

# 19. Errores Comunes y Trampas

## 19.1 ⚠️ Confundir O con Θ

```text
❌ "Mi algoritmo es O(n²), entonces hace exactamente n² operaciones"

✅ "Mi algoritmo es O(n²) → hace a lo más cn² operaciones"
   "Mi algoritmo es Θ(n²) → hace entre c₁n² y c₂n² operaciones"
```

**Implicación:** Decir O cuando realmente es Θ es **incorrecto pero común**. La inversa (decir Θ cuando solo es O) es **presumir** optimalidad.

## 19.2 ⚠️ Usar O donde Θ es correcto

```text
Insertion sort en array ordenado: O(n), pero también Ω(n).
   Mejor + peor: ambos O(n) → Θ(n) en array ordenado.

Pero en array arbitrario:
   Mejor: O(n)
   Peor:  O(n²)
   Promedio: Θ(n²)

Decir Θ(n²) sin contexto es ambiguo — ¿peor caso? ¿promedio?
```

## 19.3 ⚠️ Asumir `f = O(g) ⟹ g = O(f)`

```text
n = O(n²)    ✓      (claro)
n² = O(n)    ❌     (falso)

n = O(n²) NO implica n² = O(n).
```

**Analogía:** "Juan es menor que Pedro" no implica "Pedro es menor que Juan".

## 19.4 ⚠️ "Aritmética O" mal aplicada

```text
❌ "O(n) + O(n²) = O(n²)"    ←  en realidad es O(n²), pero el resultado está OK
                              pero la SUMA no es O(n²): es Ω(n²), luego Θ(n²).
                              Técnicamente: O(n) + O(n²) ⊆ O(n²) ⊆ O(max(n, n²)) = O(n²).  ✓
```

> **Mejor:** Di "cota superior es O(n²)" directamente, sin la aritmética intermedia.

## 19.5 ⚠️ Confundir "pertenencia" con "igualdad"

```text
❌ "f(n) = O(n²)"  sugiere igualdad
✅ "f(n) ∈ O(n²)"  es más claro
✅ "f(n) = O(n²)"  es la notación CLRS (por tradición, pero ES pertenencia)
```

## 19.6 ⚠️ Olvidar el "eventualmente"

```text
❌ "f(n) ≤ c·g(n) para todo n"      ←  exigiría que valga desde n=1

✅ "f(n) ≤ c·g(n) para todo n ≥ n₀" ←  solo a partir de cierto n₀
```

**Contraejemplo de la versión ❌:**

```text
n = O(n²):    ¿ vale para n=1?    1 ≤ c·1?  Sí, con c=1.  ✓
n² = O(n):    ¿ vale para n=1?    1 ≤ c·1?  Sí, con c=1.   PERO para n=2:  4 ≤ c·2?
                Con c=4:  4 ≤ 8 ✓;  con c=2:  4 ≤ 4 ✓.   Hmm.
              Pero eventualmente falla.

La definición correcta es "para todo n ≥ n₀".
```

## 19.7 ⚠️ Confundir O con peor caso

```text
❌ "Merge sort es O(n log n)"        ←  ambiguo

✅ "Merge sort hace Θ(n log n) comparaciones en todos los casos"
   O "Peor caso de merge sort es O(n log n) (de hecho, Θ(n log n))"
```

## 19.8 ⚠️ Constantes importan (¡sí!)

```text
Algoritmo A: O(n) con constante 1000  →  1000n ops
Algoritmo B: O(n²) con constante 1    →  n² ops

Para n = 100:    A = 100,000,  B = 10,000     →  B gana
Para n = 10,000: A = 10⁷,      B = 10⁸         →  A gana
```

> **Para `n` pequeño**, el algoritmo de mayor orden puede ganar. Pero para `n` grande, el orden gana.

## 19.9 ⚠️ Decir "exponencial" cuando es "polinomial"

```text
❌ "Backtracking es exponencial SIEMPRE"
   (muchos backtrackings con poda son sub-exponenciales en la práctica)

✅ "Peor caso de backtracking es exponencial"
   "En la práctica, con poda eficiente, suele comportarse mejor"
```

## 19.10 ⚠️ `2n ≠ O(n)` — sí, sí es

```text
❌ "2n es O(2n), no O(n)"      ←  conceptual error

✅ 2n = O(n) porque 2n ≤ 2·n para todo n.  La constante se ignora.
```

## 19.11 ⚠️ `n² + 5n = O(n²)` pero `5n` no se descarta mágicamente

```text
❌ "El 5n es despreciable, lo descartamos"   ←  NO se descarta, solo es dominado

✅ n² + 5n ≤ n² + 5n² = 6n²  para n ≥ 1.
   Por tanto, con c = 6, n₀ = 1:  n² + 5n ≤ 6·n².   ✓
```

## 19.12 Tabla resumen de trampas

| Trampa                                          | Corrección                                  |
| ----------------------------------------------- | ------------------------------------------- |
| Decir O y querer decir Θ                        | Verificar si la cota es ajustada            |
| Asumir `f = O(g) ⟹ g = O(f)`                   | Las O no son simétricas                    |
| Decir "Aritmética O" sin contexto               | Mejor dar la cota final directamente        |
| Olvidar `n ≥ n₀`                                | Big-O es **eventual**, no universal         |
| Decir "exponencial" sin verificar               | Comprobar empíricamente                     |
| Confundir `f(n) = O(g(n))` con igualdad         | Es pertenencia al conjunto                  |
| Asumir constantes irrelevantes                  | Importan para `n` pequeño                   |
| Confundir peor caso con Θ                       | Θ requiere cota superior E inferior        |

---

# 20. Ejercicios Resueltos

## 20.1 Ejercicio 1: Probar `3n² + 5n = O(n²)`

**Demostración:**

```text
Buscamos c > 0 y n₀ ≥ 1 tales que:
   3n² + 5n ≤ c · n²     ∀ n ≥ n₀

Para n ≥ 1:
   5n ≤ 5n²     (porque n ≤ n² para n ≥ 1)

Por tanto:
   3n² + 5n ≤ 3n² + 5n² = 8n²

Conclusión: c = 8, n₀ = 1.
```

**Verificación:**

```text
n = 1:    3 + 5 = 8     ≤ 8·1   = 8     ✓
n = 10:   300 + 50 = 350 ≤ 8·100 = 800   ✓
n = 100:  30000 + 500 = 30500 ≤ 8·10000 = 80000  ✓
```

## 20.2 Ejercicio 2: Probar `log n = O(n^ε)` para `ε > 0`

**Demostración (con cálculo):**

```text
Para cualquier ε > 0:
   lim_{n→∞}  log n / n^ε  =  0   (por L'Hôpital, ya demostrado)

Por tanto, existe n₀ tal que para n ≥ n₀:
   log n / n^ε ≤ 1
   ⟹  log n ≤ n^ε

Conclusión: c = 1, n₀ según ε (pero finito siempre).
```

**Demostración (sin L'Hôpital, solo definición):**

```text
Sea ε > 0. Necesitamos: log n ≤ c · n^ε.

Probemos por inducción que para k entero positivo:
   2^k ≥ k · (cualquier constante)

Específicamente, para todo n ≥ n₀:
   log₂ n ≤ n^(ε/2)

Dividiendo ambos lados por n^(ε/2):
   log₂ n / n^(ε/2) ≤ 1

Para n suficientemente grande, esto es cierto (lo probamos abajo).

[Detalle técnico:] Si log₂ n ≤ n^(ε/2), entonces log₂ n ≤ n^ε.
```

## 20.3 Ejercicio 3: Probar `n! = ω(2^n)`

**Demostración (con Stirling):**

```text
Fórmula de Stirling:
   n! ≈ √(2πn) · (n/e)^n

Por tanto:
   n! / 2^n ≈ √(2πn) · (n/e)^n / 2^n
           = √(2πn) · (n / (2e))^n

Como n/(2e) → ∞ cuando n → ∞:
   n! / 2^n → ∞

Conclusión: n! = ω(2^n).   ✓
```

**Demostración alternativa (sin Stirling):**

```text
n! = 1 · 2 · 3 · ... · n

Para n ≥ 4:
   los últimos ⌈n/2⌉ factores son todos ≥ n/2 ≥ 2

   n! ≥ (n/2)^(n/2) = 2^((n/2) · log₂(n/2))

Comparando con 2^n:
   (n/2) · log₂(n/2) vs n
   (1/2) · log₂(n/2) vs 1
   log₂(n/2) vs 2
   n/2 vs 4
   n vs 8

Para n ≥ 8:  log₂(n/2) > 2   ⟹   n! > 2^n

Por tanto n! = ω(2^n).   ✓
```

## 20.4 Ejercicio 4: Relación entre `n log n` y `n^1.5`

**Demostración:**

```text
lim_{n→∞}  (n log n) / n^1.5
= lim  log n / n^0.5

L'Hôpital:
= lim  (1/n) / (0.5 · n^(-0.5))
= lim  (1/n) · (2 · n^0.5)
= lim  2 · n^(-0.5)
= 0

Conclusión: n log n = o(n^1.5).   ✓
```

## 20.5 Ejercicio 5: ¿Es `log^k n = O(n)`?

**Demostración:**

```text
Para cualquier k constante, queremos probar:  log^k n ≤ c · n  para n ≥ n₀.

Equivalente a:  log^k n / n ≤ c.

lim_{n→∞}  log^k n / n   (L'Hôpital k veces)
         = lim  k! / n   = 0

Por tanto, log^k n = o(n) ⊆ O(n).   ✓

Conclusión: SÍ, log^k n = O(n) para cualquier k constante.
```

## 20.6 Ejercicio 6: Probar `n^n ≠ O(2^(n²))` — falso o verdadero

**Análisis:**

```text
¿n^n = O(2^(n²))?
Equivale a:  n^n ≤ c · 2^(n²)  para n ≥ n₀.

log₂(n^n) = n · log₂ n
log₂(2^(n²)) = n²

Pregunta:  ¿ n · log n ≤ c · n²  para n ≥ n₀ ?
⟺         log n ≤ c · n
⟺         SÍ (esto siempre es cierto para c ≥ 1 y n ≥ 2)

Por tanto:
   n^n = O(2^(n²))   ✓  (¡VERDADERO!)
```

**Verificación numérica:**

```text
n = 10:    n^n = 10¹⁰ = 10,000,000,000
           2^(n²) = 2^100 ≈ 10^30
           n^n << 2^(n²)   ✓

n = 100:   n^n = 100^100 = 10^200
           2^(n²) = 2^10000 ≈ 10^3010
           n^n << 2^(n²)   ✓
```

## 20.7 Ejercicio 7: ¿`n · 2^n = O(3^n)`?

**Demostración:**

```text
¿ n · 2^n ≤ c · 3^n  para n ≥ n₀ ?
⟺  n ≤ c · (3/2)^n

L'Hôpital:
lim  n / (3/2)^n = 0    (exponencial domina)

Por tanto: n · 2^n = o(3^n) ⊆ O(3^n).   ✓
```

## 20.8 Ejercicio 8: Determinar `n!` vs `n^n`

```text
lim_{n→∞}  n! / n^n

n! / n^n = (1/n)·(2/n)·(3/n)·...·(n/n)
        = (1/n)·(2/n)·(3/n)·...·1

Cada factor ≤ 1. Los últimos n/2 factores ≤ 1/2.

Por tanto:
   n! / n^n ≤ (1/2)^(n/2)

lim (1/2)^(n/2) = 0

Conclusión: n! = o(n^n).   ✓
```

## 20.9 Ejercicio 9: Probar `2^(n+1) = O(2^n)`

```text
2^(n+1) = 2 · 2^n ≤ 2 · 2^n

Conclusión: c = 2, n₀ = 1.   ✓
```

> **Lección:** Las constantes en el exponente no importan en la base.

## 20.10 Ejercicio 10: ¿`2^(2n) = O(2^n)`?

```text
¿2^(2n) ≤ c · 2^n ?
⟺ 2^n ≤ c
⟺ falso para n grande.

Conclusión: 2^(2n) ≠ O(2^n).   ✓ (de hecho, 2^(2n) = ω(2^n))
```

> **Lección:** Los factores constantes en el exponente **sí** importan.

## 20.11 Ejercicio 11: `Σ_{i=1}^n i = Θ(n²)`

```text
Σ i = n(n+1)/2 = (n² + n)/2

Cota superior: (n² + n)/2 ≤ n²  para n ≥ 1.   ⟹  c₂ = 1
Cota inferior: (n² + n)/2 ≥ n²/2.            ⟹  c₁ = 1/2

Conclusión: c₁ = 1/2, c₂ = 1, n₀ = 1.   ✓
```

## 20.12 Ejercicio 12: `Σ_{i=1}^n 1/i = O(log n)`

```text
Serie armónica: 1 + 1/2 + 1/3 + ... + 1/n ≈ log n + γ (constante de Euler)

Demostración:
   1 + 1/2 + 1/3 + ... + 1/n
   ≤ 1 + 1/2 + (1/3 + 1/4) + (1/5+...+1/8) + ...
   ≤ 1 + 1/2 + 1/2 + 1/2 + ...   (cada grupo de potencias de 2 suma ≤ 1)
   = 1 + log₂ n
   = O(log n)   ✓
```

## 20.13 Ejercicio 13: Determinar relación `f(n) = n log n` y `g(n) = n^1.01`

```text
lim  (n log n) / n^1.01
= lim  log n / n^0.01
= 0     (por L'Hôpital)

Conclusión: n log n = o(n^1.01).   ✓
```

> **Lección:** Cualquier potencia de `n`, por pequeña que sea, eventualmente supera a `n log n`.

## 20.14 Ejercicio 14: Probar o refutar `n log n = O(n^2)`

```text
¿ n log n ≤ c · n²  para n ≥ n₀ ?
⟺  log n ≤ c · n
⟺  SÍ para c ≥ 1, n ≥ 2.

Conclusión: n log n = O(n²).   ✓
```

## 20.15 Ejercicio 15: Probar `f(n) = n² + n log n = Θ(n²)`

```text
Cota superior: n² + n log n ≤ n² + n² = 2n²  (para n ≥ 2, log n ≤ n).
               ⟹  c₂ = 2, n₀ = 2.

Cota inferior: n² + n log n ≥ n²  (siempre).
               ⟹  c₁ = 1, n₀ = 1.

Conclusión: c₁ = 1, c₂ = 2.   ✓
```

## 20.16 Ejercicio 16: ¿Es `g(n) = n^1.5 + 100n log n = Θ(n^1.5)`?

```text
Cota superior: n^1.5 + 100n log n ≤ n^1.5 + 100n^1.5 = 101·n^1.5  (log n ≤ n^0.5 para n ≥ 1).
               ⟹  c₂ = 101.

Cota inferior: n^1.5 + 100n log n ≥ n^1.5  (siempre).
               ⟹  c₁ = 1.

Conclusión: SÍ, g(n) = Θ(n^1.5).   ✓
```

## 20.17 Ejercicio 17: Comparar `f(n) = log(n!)` y `g(n) = n log n`

```text
log(n!) = log(1·2·3·...·n) = log 1 + log 2 + ... + log n

Por la desigualdad integral:
   ∫₁ⁿ log x dx ≤ log(n!) ≤ ∫₁ⁿ⁺¹ log x dx

∫ log x dx = x log x - x

Por tanto:
   n log n - n ≤ log(n!) ≤ (n+1) log(n+1) - (n+1) + 1

Para n grande:
   n log n - O(n) ≤ log(n!) ≤ n log n + O(n log n)

Conclusión: log(n!) = Θ(n log n).   ✓
```

> **Aplicación:** Esto se usa en algoritmos que generan permutaciones.

---

# 21. Buenas Prácticas

## 21.1 Cuándo usar cada notación

| Situación                                            | Notación recomendada         |
| ---------------------------------------------------- | ---------------------------- |
| Análisis estándar de algoritmo (caso general)        | **O** (cota superior)        |
| Probando optimalidad (límite inferior)               | **Ω**                        |
| Resultados ajustados (algoritmo y cota coinciden)    | **Θ**                        |
| Teoría de algoritmos, papers formales                | **o** y **ω** (con límites)  |
| Análisis amortizado                                  | Depende del método            |
| Comunicación con no-expertos                         | **O** (siempre)              |

## 21.2 Cómo comunicar la complejidad

### Para audiencias técnicas

```text
"Este algoritmo es O(n log n) en el peor caso, Ω(n log n) en el mejor,
y Θ(n log n) en promedio."
```

### Para managers y PMs

```text
"Para 1 millón de datos, tarda 1 segundo.
Para 10 millones, tarda ~13 segundos (escala casi linealmente)."
```

### Para papers

```text
"The running time is T(n) = O(n log n) operations,
and this is tight: T(n) = Θ(n log n)."
```

## 21.3 ✅ Lista de verificación

| ✅ Hacer                                                | ❌ Evitar                                  |
| ------------------------------------------------------ | ------------------------------------------ |
| Especificar caso (peor, promedio, mejor)               | Decir solo "O(...)" sin contexto           |
| Probar cotas O y Ω por separado si quieres Θ           | Asumir Θ sin probar                        |
| Usar Θ cuando puedas                                  | Decir O cuando es Θ (subóptimo)            |
| Especificar `n₀` y `c` en pruebas formales             | Decir "es O(...)" sin justificación        |
| Distinguir entre tiempo y espacio                      | Decir "complejidad" sin precisar           |
| Reconocer cuándo el análisis amortizado aplica         | Confundirlo con análisis promedio          |
| Aclarar constantes en hardware específico              | Asumir que O(n²) siempre es lento         |

## 21.4 Estilo de escritura

### En código

```c
// ❌ No recomendado
void sort(int arr[], int n);   // O(n²)

// ✅ Recomendado
// Ordena arr de tamaño n en O(n log n) en el peor caso,
// O(n) si ya está ordenado (algoritmo adaptativo).
void sort(int arr[], int n);
```

### En análisis

```text
❌ "El algoritmo es O(n²)"

✅ "El algoritmo hace Θ(n²) comparaciones en el peor caso,
    pero Θ(n) en el mejor caso si el array está pre-ordenado.
    Costo amortizado de inserciones: Θ(1)."
```

## 21.5 Cuándo NO usar notación asintótica

| Situación                                  | Mejor herramienta                |
| ------------------------------------------ | -------------------------------- |
| `n` es pequeño y conocido                  | **Benchmarking / profiling**     |
| Hardware específico importa               | **Constantes medidas**           |
| Variabilidad entre inputs es alta          | **Análisis de distribución**     |
| Decisión de diseño en producción           | **Datos reales + profiling**     |

> **Regla:** La notación asintótica es para **entender** el algoritmo. Las decisiones de producción requieren **medir**.

---

# 22. Intuición de Ingeniería

## 22.1 Por qué la notación asintótica es el "lenguaje universal"

```text
"Inventé un algoritmo nuevo que hace X en O(n log log n)."

Sin notación: no se puede comparar nada.
Con notación: inmediatamente comparable con O(n log n), O(n²), O(n).
```

## 22.2 Cuándo la notación "miente"

### Caso 1: constantes enormes

```text
Algoritmo A: O(n²) con 1 op.
Algoritmo B: O(n log n) con 1000·n log n ops.

Para n = 10:
   A = 100,    B = 1000·30 = 30,000    →  A gana
Para n = 1,000,000:
   A = 10¹²,   B ≈ 2·10¹⁰                →  B gana
```

### Caso 2: `n` pequeño

```text
O(n²) puede ser más rápido que O(n log n) para n < 100.
Por eso muchos algoritmos D&C tienen "insertion sort threshold" en n = 16.
```

### Caso 3: peor caso vs promedio

```text
Quicksort: O(n²) peor caso, O(n log n) promedio.
Si tu input no es patológico, es O(n log n) "siempre".
```

## 22.3 Tabla de decisión rápida

| Si necesitas procesar...                            | Apunta a...                           |
| -------------------------------------------------- | ------------------------------------- |
| Pocos datos, latency crítica                       | **O(1) o O(log n)**                   |
| Muchos datos, throughput                           | **O(n) o O(n log n)**                 |
| Procesar por batches grandes                       | **O(n log n)** (suele ser óptimo)     |
| Modelo de ML con datasets enormes                  | **O(n · k) donde k es chico**         |
| Interactivo (< 100 ms de respuesta)                | **O(n log n) con n ≤ 10⁶**            |
| Batch processing (minutos a horas OK)              | **O(n²) con n ≤ 10⁴** o **O(n log n)** |

## 22.4 El "sweet spot" de los algoritmos

```text
Complejidades "buenas" (orden creciente):
   O(1), O(log n), O(√n), O(n), O(n log n)

   Estas son las que debes apuntar.

Complejidades "aceptables" (con n limitado):
   O(n log n) con n ≤ 10⁹     ✓ factible
   O(n^1.5) con n ≤ 10⁶       ✓ factible
   O(n²)     con n ≤ 10⁴      ✓ factible

Complejidades "evitar":
   O(n²)     con n ≥ 10⁶      ❌ impracticable
   O(n³)     con n ≥ 10³      ❌ impracticable
   O(2^n)    con n ≥ 30       ❌ impracticable
   O(n!)     con n ≥ 12       ❌ impracticable
```

## 22.5 La jerarquía visual de complejidad

```text
Tiempo (escala log)
   ↑
   │                                            ● n!
   │                                          ●
   │                                        ●
   │                                     ● 2ⁿ
   │                                  ●
   │                              ● n³
   │                          ●
   │                      ● n²
   │                  ●
   │              ● n log n
   │          ●
   │      ● n
   │   ● √n
   │ ● log n
   │● log log n
   ● constante
   └──────────────────────────────────────────→ n (escala log)

Para n = 10⁹:  log n ≈ 30,  n = 10⁹,  n² = 10¹⁸,  2^n = ⚠
```

## 22.6 La conexión con el resto del repositorio

| Archivo del repo                                | Conexión con notación asintótica                |
| ----------------------------------------------- | ----------------------------------------------- |
| **Algorithms.md** (secciones 2, 3, 4, 5, 7)     | Overview (este archivo profundiza)               |
| **Divide&Conquer.md** (sección 6)               | Método maestro usa Θ formal                     |
| **Sorting.md**                                  | Comparación de algoritmos usa Θ y O             |
| **Hashing.md**                                  | Análisis amortizado del rehashing                |
| **Recursion/**                                  | Notación Θ en recurrencias                      |
| **Greedy/**                                     | Pruebas de optimalidad usan Ω                   |
| **DP/**                                         | Subproblemas solapados: análisis de complejidad|

## 22.7 Lo que este archivo NO cubre

Para profundizar más allá, consulta:

```text
1. Análisis de recurrencias específicas (Akra-Bazzi, sustitución)
2. Análisis de algoritmos probabilistas (esperanza, varianza)
3. Análisis smooth / quasi-linear (smoothness lemma)
4. Análisis competitivo (online algorithms)
5. Análisis paramétrico (multivariado: n, m, k)
6. Análisis de espacio vs tiempo (trade-offs)
7. Modelo de cálculo (RAM, pointer machine, etc.)
```

## 22.8 El mensaje final

> **La notación asintótica es el "lenguaje común" de los algoritmos.**
>
> Sin ella, no podríamos decir "mi algoritmo es más rápido que el tuyo" sin entrar en detalles irrelevantes.
>
> Pero **no es la historia completa**. Las constantes importan, `n` pequeño importa, el hardware importa.
>
> Usa la notación asintótica como **primer filtro** para comparar ideas algorítmicas, y luego **mide** para tomar decisiones finales.

---

## 22.9 Tabla resumen final

| Quiero decir...                            | Escribo...            |
| ------------------------------------------ | --------------------- |
| "A lo más proporcional a f"                | `O(f)`                |
| "Al menos proporcional a f"                | `Ω(f)`                |
| "Exactamente del orden de f"               | `Θ(f)`                |
| "Crece estrictamente más lento que f"      | `o(f)`                |
| "Crece estrictamente más rápido que f"     | `ω(f)`                |
| "f es asintóticamente igual a g"           | `f ~ g`               |
| "O(f) ignorando log^k n"                   | `Õ(f)`                |
| "Peor caso amortizado O(1)"                | "costo amortizado O(1)" |

---

## Referencias

- **CLRS (Cormen, Leiserson, Rivest, Stein)** — *Introduction to Algorithms* (4ª ed.).
  - **Capítulo 3**: *Growth of Functions* — definiciones formales de O, Ω, Θ, o, ω, smoothness, floors/ceilings.
  - **Capítulo 4.5**: *The Master Method* — usa smoothness y funciones monótonas.
  - **Capítulo 17**: *Amortized Analysis* — los tres métodos (agregado, contabilidad, potencial).
- **Algorithms.md** en este repositorio — overview de complejidad.
- **Divide&Conquer.md** en este repositorio — recurrencias, método maestro.
- **Sorting.md** en este repositorio — ejemplos concretos de algoritmos Θ.

> **CLRS, p. 47:** *"The asymptotic notations are a vocabulary for discussing the rate of growth of functions."*