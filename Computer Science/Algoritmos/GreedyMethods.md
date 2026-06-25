# Greedy Methods — Algoritmos Voraces

> **Idea central:** Un algoritmo voraz (greedy) construye la solución **tomando, en cada paso, la mejor decisión local posible**, sin reconsiderarla después.
>
> Cuando funciona, es la estrategia **más simple y más rápida**. Cuando falla, hay que cambiar de paradigma (DP, D&C o backtracking).
> El Capítulo 16 del CLRS está dedicado enteramente a esta familia.

---

## Tabla de Contenidos

1. [¿Qué es un Algoritmo Voraz (Greedy)?](#1-qué-es-un-algoritmo-voraz-greedy)
2. [Anatomía de un Algoritmo Greedy](#2-anatomía-de-un-algoritmo-greedy)
3. [Las Propiedades Clave](#3-las-propiedades-clave)
4. [Greedy vs D&C vs DP](#4-greedy-vs-dc-vs-dp)
5. [El Patrón de Intercambio (Exchange Argument)](#5-el-patrón-de-intercambio-exchange-argument)
6. [Teoría de Matroides (Avanzado)](#6-teoría-de-matroides-avanzado)
7. [Problema del Cambio de Monedas](#7-problema-del-cambio-de-monedas)
8. [Activity Selection / Interval Scheduling](#8-activity-selection--interval-scheduling)
9. [Fractional Knapsack (Mochila Fraccionaria)](#9-fractional-knapsack-mochila-fraccionaria)
10. [Huffman Coding](#10-huffman-coding)
11. [Dijkstra (Camino Más Corto)](#11-dijkstra-camino-más-corto)
12. [Minimum Spanning Tree — MST (CLRS Cap. 23)](#12-minimum-spanning-tree--mst-clrs-cap-23)
13. [Kruskal](#13-kruskal)
14. [Prim (Lazy y Eager)](#14-prim-lazy-y-eager)
15. [Boruvka (Mención Histórica)](#15-boruvka-mención-histórica)
16. [Job Sequencing con Deadlines](#16-job-sequencing-con-deadlines)
17. [Greedy en Geometría — Convex Hull](#17-greedy-en-geometría--convex-hull)
18. [Casos donde Greedy Falla](#18-casos-donde-greedy-falla)
19. [Errores Comunes y Buenas Prácticas](#19-errores-comunes-y-buenas-prácticas)
20. [Intuición de Ingeniería](#20-intuición-de-ingeniería)

---

# 1. ¿Qué es un Algoritmo Voraz (Greedy)?

## 1.1 Definición

Un **algoritmo greedy** (voraz) resuelve un problema de optimización haciendo una secuencia de **elecciones局部mente óptimas**, sin reconsiderarlas nunca.

```text
Para cada paso del algoritmo:
    1. Mira las opciones disponibles AHORA MISMO.
    2. Elige la que parece MEJOR en este momento.
    3. Comprométete con esa elección (no vuelvas atrás).
    4. Avanza al siguiente subproblema.
```

> **CLRS Cap. 16 (Greedy Algorithms, intro):**
> *"A greedy algorithm always makes the choice that looks best at the moment. It makes a locally optimal choice in the hope that this choice will lead to a globally optimal solution."*

## 1.2 La intuición: "tomar lo mejor ahora"

La metáfora central es la del **recolector en un mercado**:

```text
Tienes 5 minutos en un mercado y una bolsa.
Greedy:    cada vez pasas por un puesto, agarras lo más caro que cabe.
           Nunca devuelves nada.

Óptimo:    a veces convendría dejar un objeto caro para llevar DOS baratos
           que en conjunto valen más. Greedy NO lo ve.
```

```text
              decisión 1
                ↓
         [estado A]  ──greedy──►  [estado B]  ──greedy──►  [solución]
                ↓ alternativa que greedy ignoró
         [estado A']
```

> **Idea clave:** Greedy **nunca mira hacia atrás**. La pregunta difícil no es "¿cómo lo implemento?", sino **"¿cuándo funciona?"**.

## 1.3 Ejemplos cotidianos

| Situación                                     | Greedy natural                                     |
| --------------------------------------------- | -------------------------------------------------- |
| Dar cambio con monedas (US: 1,5,10,25)       | Tomar siempre la moneda más grande posible         |
| Elegir actividades en un horario              | Hacer la que termina más pronto                     |
| Empacar maleta con límite de peso             | Meter el objeto con mejor relación valor/peso      |
| Tareas con deadlines                          | Hacer primero la de mayor ganancia                 |
| Árbol de expansión mínima (MST)               | Tomar la arista más barata que no forme ciclo      |
| Comprimir un archivo (Huffman)                | Combinar los símbolos menos frecuentes primero     |

## 1.4 Ejemplo no-cotidiano: por qué la intuición falla

```text
Problema: ir de A a B con menos peajes.

Greedy:   en cada bifurcación, tomar el camino con peaje más barato.
¿Óptimo?  No siempre. A veces el camino barato te lleva a una ruta
          larga que cuesta más en tiempo y gasolina.

Esto NO es un problema greedy. Es un grafo con costos ocultos.
La analogía de monedas canónicas es "fácil"; la vida real, no.
```

## 1.5 La pregunta fundamental

> **¿La mejor elección local garantiza la mejor solución global?**
>
> Si la respuesta es **SÍ** → usa greedy.
> Si la respuesta es **NO** → necesitas DP, backtracking o búsqueda exhaustiva.

El resto de este documento enseña a **reconocer cuándo funciona** y a **demostrarlo**.

---

# 2. Anatomía de un Algoritmo Greedy

## 2.1 Los cuatro componentes

Todo algoritmo greedy tiene estas cuatro partes:

```text
┌────────────────────────────────────────────────────────┐
│  1. FUNCIÓN DE SELECCIÓN (choice function)             │
│     Decide cuál es la "mejor" opción actual.           │
│     Ej: "moneda de mayor valor que aún quepa"          │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│  2. FUNCIÓN DE VIABILIDAD (feasibility check)          │
│     ¿La elección sigue produciendo una solución válida?│
│     Ej: "¿el cambio aún se puede completar?"           │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│  3. FUNCIÓN OBJETIVO (objective)                       │
│     Lo que queremos maximizar/minimizar.               │
│     Ej: minimizar el # de monedas                      │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│  4. FUNCIÓN DE SOLUCIÓN (solution construction)         │
│     Construye el resultado a partir de las elecciones. │
└────────────────────────────────────────────────────────┘
```

## 2.2 Pseudocódigo genérico (CLRS 16.1)

```text
GREEDY(problema):
    S = ∅                                   // solución parcial
    C = conjunto de candidatos              // todas las opciones posibles

    while C ≠ ∅ y S no es solución completa:
        x = SELECT(C)                       // 1. choice function
        C = C - {x}

        if VIABLE(S ∪ {x}):                 // 2. feasibility check
            S = S ∪ {x}                     // aceptar la elección

            if S es solución completa:
                return S

    return S
```

## 2.3 Estructura típica en C

```c
typedef struct {
    int n;                  // # candidatos
    Candidato candidatos[];
} Problema;

typedef struct {
    int k;                  // # elegidos
    Candidato elegidos[];
} Solucion;

Solucion greedy(Problema p) {
    Solucion S;
    S.k = 0;

    // 1. Inicializar candidatos ordenados según la choice function
    ordenarSegunCriterio(p.candidatos, p.n);

    // 2. Iterar y aceptar si es viable
    for (int i = 0; i < p.n; i++) {
        Candidato x = p.candidatos[i];
        if (esViable(x, S)) {
            S.elegidos[S.k++] = x;
        }
    }

    return S;
}
```

## 2.4 Tres preguntas antes de aplicar greedy

| Pregunta                                              | Si NO…                                        |
| ----------------------------------------------------- | --------------------------------------------- |
| ¿Existe una **función de selección** clara y natural? | No hay heurística razonable → probablemente no aplica |
| ¿La elección greedy preserva la **viabilidad**?       | Puedes generar soluciones inválidas            |
| ¿**Demostrablemente** lleva a lo óptimo?             | ⚠️ Aquí es donde la mayoría se equivoca        |

> **Regla de oro:** sin una prueba (o al menos un argumento fuerte) de optimalidad, **no confíes en tu greedy**.

---

# 3. Las Propiedades Clave

## 3.1 Greedy-Choice Property (Propiedad de Elección Voraz)

> **Definición (CLRS 16.1):** *Una elección localmente óptima lleva a una solución globalmente óptima.*
>
> Es decir: **existe** una solución óptima que **empieza** con la elección greedy.

```text
Formalmente:

  Si x* es la elección greedy,
  entonces ∃ una solución óptima S* tal que x* ∈ S*.

Consecuencia: podemos "comprometernos" con x* y resolver el resto.
```

### Ejemplo: cambio de monedas (US)

```text
Sistema canónico: {1, 5, 10, 25}

¿La moneda más grande (25) está en alguna solución óptima de 63¢?
   - Sí: 25 + 25 + 10 + 1 + 1 + 1 = 63  ✓
   - 25 ≤ 63, así que SIEMPRE conviene incluirla.

→ Greedy-choice property se cumple.
```

### Ejemplo: cambio NO canónico {1, 3, 4}

```text
Para 6¢:
   Greedy:  4 + 1 + 1 = 3 monedas
   Óptimo:  3 + 3 = 2 monedas     ← ¡la elección 4 NO es parte de la óptima!

→ Greedy-choice property FALLA. Greedy da 3, óptimo es 2.
```

## 3.2 Optimal Substructure (Subestructura Óptima)

> **Definición (CLRS 16.1):** *Una solución óptima al problema contiene soluciones óptimas a los subproblemas que quedan después de la elección greedy.*

```text
Si S* es óptima para P y empieza con la elección greedy x*,
entonces S* - {x*} es óptima para P' (el problema restante).
```

### Ejemplo: Interval Scheduling

```text
Problema P:        12 intervalos. Escoger máximo # compatible.
Greedy:            elegir el que termina más pronto (intervalo a*).

Subproblema P':    11 intervalos restantes, comenzando después del fin de a*.

Reclamo:           la solución óptima de P' sumada a {a*} es óptima de P.

Esto se prueba por CONTRADICCIÓN (exchange argument, sección 5).
```

## 3.3 Las dos propiedades juntas

| Propiedad             | Garantiza que…                                          |
| --------------------- | ------------------------------------------------------- |
| **Greedy-choice**     | Podemos comprometer la elección sin perder optimalidad |
| **Optimal substruct.**| El problema restante se resuelve de forma independiente|

Si **ambas** se cumplen → **el algoritmo greedy es óptimo**.

> **CLRS Cap. 16:** *“The greedy-choice property and optimal substructure are the two key ingredients.”*

## 3.4 Esquema de prueba típico

```text
Para probar optimalidad de un greedy:

  1. DECIR cuál es la choice function.

  2. PROBAR greedy-choice property:
     "Existe una solución óptima que incluye la primera elección greedy."
     → por inducción o por exchange argument.

  3. PROBAR optimal substructure:
     "Después de quitar la elección greedy, el subproblema residual
      tiene estructura óptima propia."
     → por inducción.

  4. CONCLUIR: el algoritmo greedy produce el óptimo.
```

---

# 4. Greedy vs D&C vs DP

## 4.1 Las tres grandes estrategias

| Estrategia     | Idea central                                    | Cuándo gana                               |
| -------------- | ----------------------------------------------- | ----------------------------------------- |
| **D&C**        | Divide, vence recursivo, combina                | Subproblemas **independientes**           |
| **DP**         | Resolver subproblemas **una vez** y guardar     | Subproblemas **traslapados**              |
| **Greedy**     | Elección local óptima, sin retroceder           | Elección local **siempre correcta**       |

## 4.2 Tabla comparativa detallada

| Característica         | D&C                        | DP                              | Greedy                       |
| ---------------------- | -------------------------- | ------------------------------- | ---------------------------- |
| **Subproblemas**       | Independientes             | Traslapados                     | Independientes               |
| **Memorización**       | No necesaria               | Esencial                        | No usada                     |
| **Retrocede**          | No                         | No (top-down) o sí (backtrack)  | No (jamás)                   |
| **Optimalidad**        | Si combinación es correcta | Siempre (si modelo es correcto) | Solo si greedy-choice property|
| **Complejidad típica** | Depende de recurrencia     | O(n²) a O(n³) suele             | O(n log n) o mejor          |
| **Ejemplo canónico**   | Merge Sort                 | Knapsack 0/1                    | Dijkstra, MST                |

## 4.3 Ejemplos donde cada uno gana

| Problema                       | Estrategia ganadora  | Razón                                   |
| ------------------------------ | -------------------- | --------------------------------------- |
| Ordenar `n` números            | **D&C** (Merge Sort) | Subproblemas independientes, combinar O(n)|
| Fibonacci                      | **DP**               | Traslape masivo de subproblemas         |
| Cambio (US canónico)           | **Greedy**           | Greedy-choice property se cumple        |
| Cambio (1, 3, 4)               | **DP**               | Greedy-choice property **NO** se cumple |
| Knapsack 0/1                   | **DP**               | Decisiones interactúan                   |
| Knapsack fraccionario          | **Greedy**           | Ratio valor/peso basta                  |
| Camino más corto (DAG)         | **DP**               | Topological order                       |
| Camino más corto (no-negativo) | **Greedy** (Dijkstra)| Greedy-choice por mínimo local          |
| MST                            | **Greedy**           | Cut property garantiza optimalidad       |
| TSP                            | **DP** (Held-Karp)   | Greedy falla, óptimo es 2ⁿ              |

## 4.4 Diagrama de decisión

```text
                    ¿El problema tiene subproblemas traslapados?
                              │
                ┌─────────────┴─────────────┐
                │ NO                         │ SÍ
                ▼                            ▼
       ¿Una elección local          Subproblemas más
       siempre es correcta?         pequeños: ¿importa
                │                   el orden?
        ┌───────┴───────┐                   │
        │ SÍ            │ NO                ▼
        ▼               ▼              Programación
     Greedy          ¿Combinación      Dinámica
                     de sub-soluciones
                     es eficiente?
                          │
                    ┌─────┴─────┐
                    │ SÍ        │ NO
                    ▼           ▼
                  D&C       Otro enfoque
```

## 4.5 Ejemplo: tres versiones del Knapsack

```text
Problema: mochila con capacidad W, objetos con (peso, valor).

0/1 Knapsack (toma o deja):
  - Greedy FALLA.
  - DP O(nW) lo resuelve.
  - Ej: W=10, items={(6,$8),(5,$5),(5,$5)}.
        Greedy por ratio: 8/6=1.33 → toma el primero → valor 8.
        Óptimo: tomar los dos de 5 → valor 10.

Fractional Knapsack (puede tomar fracciones):
  - Greedy por ratio SÍ funciona.
  - DP innecesario.

Ilimitado (unbounded):
  - DP sobre W.
  - Greedy no aplica.
```

---

# 5. El Patrón de Intercambio (Exchange Argument)

## 5.1 ¿Qué es?

Es la **técnica de prueba canónica** para greedy. La idea es directa:

```text
1. Supón que S* es una solución ÓPTIMA arbitraria.
2. Si S* no empieza con la elección greedy x_g:
   - Encuentra la primera posición donde S* difiere de la greedy.
   - "Intercambia" la elección de S* por x_g.
   - Muestra que el intercambio NO empeora la calidad.
3. Repite hasta que S* se parezca a la greedy.
4. Conclusión: la greedy es óptima.
```

## 5.2 Estructura formal

```text
Teorema: el greedy produce óptimo.

Prueba:
  Sea S* una solución óptima que difiere de la greedy lo MENOS posible
  (lexicográficamente).

  Caso 1: S* empieza con la elección greedy x_g.
         → entonces S* y greedy coinciden en la primera elección.
         → por inducción, el resto también.

  Caso 2: S* empieza con x ≠ x_g.
         → intercambia x por x_g en S*.
         → la nueva S' debe seguir siendo solución válida.
         → S' debe tener calidad ≥ S* (≤ si minimizamos).
         → contradicción con la optimalidad estricta.
```

## 5.3 Ejemplo: cambio de monedas canónico

```text
Sistema {1, 5, 10, 25}. Cambio a dar: 30¢.

S* = {25, 5}             (óptimo: 2 monedas)
Greedy = {25, 5}         (también elige 25 primero)

Coinciden en el primer paso → trivial.
```

Otro caso:

```text
Sistema {1, 5, 10, 25}. Cambio: 40¢.

S* = {25, 10, 5}    (3 monedas, óptimo)
Greedy = {25, 10, 5} (3 monedas)

Pero ahora supón S* = {10, 10, 10, 10} (4 monedas). Esto NO es óptimo,
así que no lo consideramos. El óptimo es único (para este sistema).

Intercambio: si S* empezara con 10, reemplazamos por 25.
   Nueva S' = {25, 10, 5}  → 3 monedas, mejor.
   Por tanto, hay un óptimo que empieza con 25 = elección greedy. ✓
```

## 5.4 Ejemplo: Interval Scheduling

```text
Demostrar que "elegir por mínimo tiempo de fin" es óptimo.

Prueba (esbozo):

Sea S* un conjunto óptimo que maximiza # intervalos.
Sea a* el intervalo con mínimo tiempo de fin entre TODOS.
Sea a_1 el primer intervalo en S*.

Caso 1: a_1 = a*. No hay nada que probar.

Caso 2: a_1 ≠ a*.
   Como a* termina no más tarde que a_1 (por choice function),
   reemplazar a_1 por a* en S*:
      - Sigue siendo factible (a* termina antes, no genera nuevos choques).
      - Tiene la misma cardinalidad.
   Por tanto, existe un óptimo que empieza con a*. ✓
```

## 5.5 Limitaciones

| Limitación                                    | Alternativa                        |
| --------------------------------------------- | ---------------------------------- |
| El intercambio debe preservar factibilidad   | Reformular el problema             |
| El intercambio debe preservar optimalidad    | Usar inducción estructural         |
| Hay empates y no se rompen fácil              | Cuidado con casos degenerados      |

> **CLRS Cap. 16:** el **exchange argument** es la herramienta más usada para greedy; consúltalo en cada prueba formal de optimalidad.

---

# 6. Teoría de Matroides (Avanzado)

## 6.1 La motivación

Hay muchos problemas greedy que **parecen no relacionados**:

```text
- MST (Minimum Spanning Tree)
- Unit-task scheduling con deadlines
- Actividad select con restricciones de "compatibility"

¿Qué tienen en común?  Todos son casos de optimización sobre un MATROID.
```

> **CLRS Cap. 16.4 (Matroid Theory):** *“Matroids provide the right formalism for proving that a greedy algorithm finds an optimal solution.”*

## 6.2 Definición de Matroid

Un **matroid** es un par `M = (S, I)` donde:

| Componente | Significado                                     |
| ---------- | ----------------------------------------------- |
| `S`        | Conjunto **finito** de "elementos"               |
| `I`        | Familia de subconjuntos **independientes**      |

Que satisface dos axiomas:

```text
1. Axioma de vacío:
      ∅ ∈ I                              (el vacío es independiente)

2. Axioma de herencia:
      Si B ∈ I y A ⊆ B, entonces A ∈ I   (subconjunto de independiente es independiente)

3. Axioma de intercambio:
      Si A, B ∈ I y |A| < |B|,
      entonces ∃ x ∈ B - A tal que A ∪ {x} ∈ I
```

## 6.3 Ejemplos de Matroides

### Matroid de un gráfico

```text
M_G = (E, I) donde:
  E = aristas del grafo
  I = conjuntos de aristas que NO forman ciclo

Verifica:
  - ∅ no forma ciclo.                     ✓
  - Si un conjunto no tiene ciclo,        ✓
    cualquier subconjunto tampoco.
  - Si A y B son "bosques" y |A| < |B|,
    existe arista e ∈ B-A que une componentes distintos en A.
    A ∪ {e} sigue sin ciclo.              ✓
```

### Matroid uniforme `U_{n,k}`

```text
S = {1, ..., n}
I = { A ⊆ S : |A| ≤ k }

Todos los axiomas se cumplen trivialmente.
```

### Matroid de partición

```text
S = unión disjunta de grupos S₁, S₂, ..., Sₖ
I = { A : |A ∩ Sᵢ| ≤ 1 para todo i }

Es la base de muchos problemas de scheduling con un trabajo por grupo.
```

## 6.4 Teorema fundamental (CLRS 16.4)

> **Teorema (Rado 1957, Edmonds 1971):**
> *Sea `M = (S, I)` un matroid con función de peso `w: S → ℝ⁺`.*
> *El algoritmo greedy que ordena `S` por peso decreciente y agrega cada elemento si mantiene la independencia, devuelve un **conjunto independiente de peso máximo**.*

```text
Algoritmo:
  1. Ordenar S por w(x) descendente.
  2. Inicializar A = ∅.
  3. Para cada x ∈ S (en orden):
       Si A ∪ {x} ∈ I:
           A = A ∪ {x}
  4. Devolver A.
```

## 6.5 Aplicación a MST

```text
Problema MST en un grafo G = (V, E):
  - S = E (aristas)
  - I = conjuntos de aristas sin ciclos (bosques)
  - w(e) = peso de la arista e

(M_G, w) es un matroid ponderado.

→ Por el teorema: Kruskal es óptimo.   ✓
```

## 6.6 Límite de la teoría

⚠️ **El teorema dice:** si tienes un matroid, el greedy es óptimo.
**Pero no dice:** si NO tienes un matroid, greedy falla.
(Aunque en la práctica, casi siempre falla.)

> **Tarea para el lector:** ¿Por qué el Knapsack 0/1 **no** es un matroid? (Pista: intenta verificar el axioma de intercambio.)

---

# 7. Problema del Cambio de Monedas

## 7.1 El problema

Dado un sistema de monedas `C = {c₁, ..., cₖ}` y un monto `N`, encontrar la **combinación con menos monedas** que sume `N`.

```text
Entrada:   N = 67,  C = {1, 5, 10, 25, 50}
Salida:    {50, 10, 5, 1, 1}     ← 5 monedas
```

## 7.2 Solución naïve (DP)

```text
dp[0] = 0
dp[n] = min( dp[n - cᵢ] + 1 )  sobre cᵢ ≤ n

Complejidad: O(N · k)        ← funciona para todo sistema
```

## 7.3 Solución greedy (cuando funciona)

```text
mientras N > 0:
    tomar la moneda más grande cᵢ ≤ N
    N = N - cᵢ
```

## 7.4 Sistema canónico de Estados Unidos

```text
Sistema: {1, 5, 10, 25, 50}

  67¢:  50 + 10 + 5 + 1 + 1          ← 5 monedas  ✓ óptimo
  42¢:  25 + 10 + 5 + 1 + 1          ← 5 monedas  ✓ óptimo
  99¢:  50 + 25 + 10 + 10 + 1 + 1 + 1 + 1   ← 8 monedas  ✓ óptimo

¿Por qué funciona?  Cada moneda es ≥ 2 × la anterior + 1.
Esto garantiza greedy-choice property.
```

### Implementación en C

```c
#include <stdio.h>

void cambioGreedy(int N, int monedas[], int k) {
    printf("Cambio para %d:\n", N);
    for (int i = k - 1; i >= 0; i--) {
        while (N >= monedas[i]) {
            printf("  %d\n", monedas[i]);
            N -= monedas[i];
        }
    }
}

int main(void) {
    int us[] = {1, 5, 10, 25, 50};
    cambioGreedy(67, us, 5);
    return 0;
}
```

### Implementación en Python

```python
def cambio_greedy(N, monedas):
    """Asume monedas ordenadas ascendentemente."""
    resultado = []
    for c in reversed(monedas):
        while N >= c:
            resultado.append(c)
            N -= c
    return resultado

print(cambio_greedy(67, [1, 5, 10, 25, 50]))
# → [50, 10, 5, 1, 1]
```

## 7.5 Sistema NO canónico: {1, 3, 4}

```text
Este sistema NO es canónico.

Problema: N = 6.
  Greedy:  4 + 1 + 1 = 3 monedas
  Óptimo:  3 + 3 = 2 monedas

→ Greedy FALLA.
```

### Tabla de fallos

| N | Greedy ({1,3,4}) | Óptimo | # monedas G | # monedas Ópt |
| - | ---------------- | ------ | ----------- | ------------- |
| 1 | 1                | 1      | 1           | 1             |
| 2 | 1,1              | 1,1    | 2           | 2             |
| 3 | 3                | 3      | 1           | 1             |
| 4 | 4                | 4      | 1           | 1             |
| 5 | 4,1              | 4,1    | 2           | 2             |
| **6** | **4,1,1**     | **3,3** | **3**     | **2** ← falla |
| 7 | 4,3              | 4,3    | 2           | 2             |
| **8** | **4,4**       | **4,4**| 2           | 2             |
| **9** | **4,4,1**     | **3,3,3** | **3**    | **3**         |
| **10**| **4,4,1,1**    | **3,3,4**  | **4**    | **3** ← falla |

## 7.6 Solución DP universal

```c
#include <string.h>
#define INF 1e9

int minMonedasDP(int N, int monedas[], int k) {
    int dp[N + 1];
    dp[0] = 0;
    for (int n = 1; n <= N; n++) {
        dp[n] = INF;
        for (int i = 0; i < k; i++) {
            if (monedas[i] <= n && dp[n - monedas[i]] + 1 < dp[n]) {
                dp[n] = dp[n - monedas[i]] + 1;
            }
        }
    }
    return dp[N];
}
```

```python
def min_monedas_dp(N, monedas):
    INF = float('inf')
    dp = [0] + [INF] * N
    for n in range(1, N + 1):
        for c in monedas:
            if c <= n and dp[n - c] + 1 < dp[n]:
                dp[n] = dp[n - c] + 1
    return dp[N]
```

## 7.7 Complejidad

| Método         | Sistema canónico | Sistema arbitrario |
| -------------- | ---------------- | ------------------ |
| **Greedy**     | O(k)             | ❌ Incorrecto      |
| **DP**         | O(N·k)           | ✅ Correcto         |

## 7.8 Variaciones

| Variación                          | Estrategia            |
| ---------------------------------- | --------------------- |
| Mínimo **# de monedas**            | DP (greedy solo en canónicos) |
| Mínimo **valor** (cada moneda con valor≠valor) | DP |
| **# de formas** de dar el cambio   | DP (cuenta, no minimiza) |
| Cambio ilimitado (unbounded)       | DP                    |

> **Conexión:** El cambio de monedas es la versión "didáctica" de muchos problemas combinatorios. Aparece en secciones 18 y más.

---

# 8. Activity Selection / Interval Scheduling

## 8.1 El problema

Dada una colección de `n` actividades con tiempo de **inicio** `sᵢ` y **fin** `fᵢ`, elegir el **máximo número de actividades mutuamente compatibles** (no se solapan).

```text
Actividad  i        1    2    3    4    5    6    7    8    9   10   11
sᵢ              |  1    3    0    5    3    5    6    8    8    2   12
fᵢ              |  4    5    6    7    8    9   10   11   12   13   14
```

## 8.2 Estrategia greedy

> **Elección voraz:** ordenar por **tiempo de fin** ascendente. Seleccionar la primera actividad y luego, recursivamente, las que empiecen después de su fin.

```text
Después de ordenar por f:
  Act 1: [1, 4)
  Act 4: [5, 7)
  Act 8: [8, 11)
  Act 11:[12, 14)

Total: 4 actividades (óptimo).
```

## 8.3 ¿Por qué esta elección y no otra?

| Estrategia greedy intuitiva       | ¿Óptimo?     | Razón                                      |
| --------------------------------- | ------------ | ------------------------------------------ |
| Tomar la más corta                | ❌           | Puede "matar" dos largas                   |
| Tomar la que empieza más temprano  | ❌           | Puede solapar con muchas                   |
| Tomar la de mayor duración        | ❌           | Idem                                       |
| **Tomar la que termina más pronto**| ✅          | Maximiza el tiempo libre para el resto    |

> **Intuición:** la que termina primero **deja más espacio** para las demás. Maximiza el residuo del problema.

## 8.4 Algoritmo

```text
ACTIVITY-SELECTOR(s, f, n):
    Sort f in increasing order  (acompaña a s)
    A = {a₁}                            // primera actividad siempre
    k = 1
    for m = 2 to n:
        if s[m] ≥ f[k]:                  // aₘ empieza cuando aₖ termina
            A = A ∪ {aₘ}
            k = m
    return A
```

### Visualización del algoritmo

```text
        0    2    4    6    8   10   12   14
tiempo: ├────┼────┼────┼────┼────┼────┼────┤
   a₁:  [════════]                       (1,4)
   a₂:       [══════]                    (3,5)
   a₃:  [══════════]                     (0,6)
   a₄:             [═══]                 (5,7)
   a₅:                [═══]              (3,8)
   a₆:                [════]             (5,9)
   a₇:                   [═══]           (6,10)
   a₈:                      [════]       (8,11)
   a₉:                      [════]       (8,12)
  a₁₀:    [══════════]                   (2,13)
  a₁₁:                            [═══] (12,14)

Ordenadas por fin: a₁, a₂, a₄, a₈, a₁₁
Seleccionadas:     a₁, a₂, a₄, a₈, a₁₁    ✓ 5 actividades
```

## 8.5 Implementación en C

```c
typedef struct {
    int inicio, fin;
} Intervalo;

void activitySelector(Intervalo a[], int n) {
    // Ordenar por fin (usando qsort de stdlib)
    qsort(a, n, sizeof(Intervalo), cmpFin);

    printf("Actividades seleccionadas:\n");
    int k = 0;                          // índice de la última elegida
    printf("  (%d, %d)\n", a[k].inicio, a[k].fin);

    for (int m = 1; m < n; m++) {
        if (a[m].inicio >= a[k].fin) {
            printf("  (%d, %d)\n", a[m].inicio, a[m].fin);
            k = m;
        }
    }
}

int cmpFin(const void *a, const void *b) {
    Intervalo *ia = (Intervalo *)a;
    Intervalo *ib = (Intervalo *)b;
    return ia->fin - ib->fin;
}
```

## 8.6 Implementación en Python

```python
def activity_selector(actividades):
    """actividades: lista de tuplas (inicio, fin)."""
    actividades = sorted(actividades, key=lambda x: x[1])
    resultado = [actividades[0]]
    ultimo_fin = actividades[0][1]

    for act in actividades[1:]:
        if act[0] >= ultimo_fin:
            resultado.append(act)
            ultimo_fin = act[1]

    return resultado

acts = [(1,4),(3,5),(0,6),(5,7),(3,8),(5,9),
        (6,10),(8,11),(8,12),(2,13),(12,14)]
print(activity_selector(acts))
# → [(1,4), (3,5), (5,7), (8,11), (12,14)]   ← 5 actividades
```

## 8.7 Prueba de optimalidad (exchange argument)

```text
Teorema: GREEDY-ACTIVITY-SELECTOR es óptimo.

Prueba (por inducción sobre n):

  Caso base: n = 1. Trivial.

  Paso inductivo:
    Sea aₘ la primera actividad que elige GREEDY (la que termina primero).
    Sea S* una solución óptima que maximiza el # actividades y
    empieza lo más parecido a GREEDY.

    Sub-caso 1: S* contiene aₘ.
       → S* \ {aₘ} es una solución óptima al subproblema
         (intervalos que empiezan ≥ fₘ).
       → Por inducción, GREEDY los elige óptimo.
       → S* = GREEDY en este caso.

    Sub-caso 2: S* no contiene aₘ pero contiene otra aⱼ que termina ≥ fₘ.
       → Reemplazar aⱼ por aₘ NO reduce el # de actividades
         (mismo tamaño de S*) y NO causa solapamiento
         (porque aₘ termina no después que aⱼ).
       → Hay un óptimo que empieza con aₘ.
       → Por inducción, GREEDY es óptimo.

  Conclusión: GREEDY produce óptimo. ∎
```

## 8.8 Complejidad

| Fase            | Tiempo                |
| --------------- | --------------------- |
| Ordenar         | O(n log n)            |
| Selección greedy| O(n)                  |
| **Total**       | **O(n log n)**        |

> **CLRS 16.1:** Activity Selection es el ejemplo canónico de greedy con prueba por exchange argument.

## 8.9 Variaciones

| Variación                                 | Algoritmo                  |
| ----------------------------------------- | -------------------------- |
| Máximo # actividades                      | Greedy por menor fin (CLRS)|
| **Máximo peso** de actividades            | **DP** (CLRS 16.2)         |
| Mínimo # aulas para todos los cursos      | Interval partitioning (DP) |
| Scheduling con pausas entre actividades    | DP                         |

> **Conexión:** Ver `Sorting.md` sección 9 — Quick Sort también elige pivotes localmente, aunque su optimalidad es estadística.

---

# 9. Fractional Knapsack (Mochila Fraccionaria)

## 9.1 El problema

Mochila con capacidad `W`. `n` objetos con peso `wᵢ` y valor `vᵢ`. **Puedes tomar fracciones**. Maximizar el valor total.

```text
Capacidad W = 50
Objetos:   i=1: peso=10, valor=60  →  ratio 6.0
           i=2: peso=20, valor=100 →  ratio 5.0
           i=3: peso=30, valor=120 →  ratio 4.0

Óptimo:    1 (10) + 2 (20) + ½·3 (15) → 60 + 100 + 60 = 220
```

## 9.2 Estrategia greedy

```text
1. Calcular ratio rᵢ = vᵢ / wᵢ para cada objeto.
2. Ordenar por rᵢ descendente.
3. Tomar todo el objeto con mayor ratio.
4. Si todavía cabe, tomar el siguiente.
5. Si no cabe entero, tomar fracción.
```

## 9.3 Algoritmo

```text
FRACTIONAL-KNAPSACK(W, items):
    ordenar items por vᵢ/wᵢ descendente
    capacidad = W
    valor = 0
    for i = 1 to n:
        if items[i].peso ≤ capacidad:
            tomar items[i] entero
            capacidad -= items[i].peso
            valor += items[i].valor
        else:
            tomar items[i] parcialmente
            valor += items[i].valor · (capacidad / items[i].peso)
            capacidad = 0
            break
    return valor
```

## 9.4 Implementación en C

```c
typedef struct {
    double peso, valor, ratio;
    int idx;
} Objeto;

int cmpRatio(const void *a, const void *b) {
    double ra = ((Objeto *)a)->ratio;
    double rb = ((Objeto *)b)->ratio;
    return (rb > ra) - (rb < ra);       // descendente
}

double fractionalKnapsack(int W, Objeto items[], int n) {
    for (int i = 0; i < n; i++)
        items[i].ratio = items[i].valor / items[i].peso;

    qsort(items, n, sizeof(Objeto), cmpRatio);

    double cap = W, val = 0;
    for (int i = 0; i < n && cap > 0; i++) {
        if (items[i].peso <= cap) {
            cap -= items[i].peso;
            val += items[i].valor;
        } else {
            val += items[i].valor * (cap / items[i].peso);
            cap = 0;
        }
    }
    return val;
}
```

## 9.5 Implementación en Python

```python
def fractional_knapsack(W, items):
    """items: lista de tuplas (peso, valor)."""
    items = sorted(items, key=lambda x: x[1]/x[0], reverse=True)
    cap, val = W, 0
    for peso, valor in items:
        if peso <= cap:
            cap -= peso
            val += valor
        else:
            val += valor * (cap / peso)
            break
    return val

print(fractional_knapsack(50, [(10,60),(20,100),(30,120)]))
# → 220.0
```

## 9.6 Prueba de optimalidad

```text
Teorema: el greedy por ratio es óptimo.

Prueba (exchange argument):
  Sea S* una solución óptima que maximiza valor.
  Sea g el objeto con mayor ratio.

  Si S* incluye g entero o en la misma fracción que el greedy, listo.
  Si S* lo incluye menos que el greedy:
    - S* incluye OTRO objeto h con menor ratio.
    - Intercambia una unidad de peso de h por una unidad de g.
    - El valor sube en (ratio_g - ratio_h) · ε > 0.
    - Contradice optimalidad de S*.

  Por tanto, hay un óptimo que toma g lo más posible. ✓
```

## 9.7 Complejidad

| Fase              | Tiempo       |
| ----------------- | ------------ |
| Calcular ratios   | O(n)         |
| Ordenar           | O(n log n)   |
| Selección greedy  | O(n)         |
| **Total**         | **O(n log n)**|

## 9.8 Comparación con Knapsack 0/1

| Aspecto                    | Fraccional           | 0/1                 |
| -------------------------- | -------------------- | ------------------- |
| **Solución**               | Greedy               | DP O(nW) o Branch & Bound |
| **Fracciones permitidas**  | Sí                   | No                  |
| **Complejidad**            | O(n log n)           | O(nW) pseudopolinómico |
| **NP-completo si 0/1**     | N/A                  | Sí                  |

### Contraejemplo famoso (0/1)

```text
Capacidad: W = 10
Items:
   A: peso=6, valor=8   →  ratio 1.33
   B: peso=5, valor=5   →  ratio 1.00
   C: peso=5, valor=5   →  ratio 1.00

Greedy 0/1 por ratio: A → valor 8.
Óptimo 0/1:            B + C → valor 10.

Greedy FRACCIONAL por ratio:
   Toma A entero (6), quedan 4.
   Toma 4/5 de B (4·1 = 4).  Valor = 12.
   Óptimo fraccional.
```

> **Moraleja:** "fraccionario" y "0/1" son **problemas distintos**. Confundirlos es uno de los errores más comunes.

---

# 10. Huffman Coding

## 10.1 El problema

Comprimir texto asignando **códigos binarios de longitud variable** a cada símbolo, de modo que el código total sea mínimo.

```text
Símbolo      Frecuencia
   a               45
   b               13
   c               12
   d              16
   e               9
   f               5
```

**Idea:** caracteres más frecuentes → códigos más cortos.

## 10.2 Códigos prefijos

Para que un código sea **decodificable** sin ambigüedad, debe ser un **prefix code**: ningún código es prefijo de otro.

```text
   a: 0
   b: 101
   c: 100
   d: 111
   e: 1101
   f: 1100

Esto es un prefix code: ningún código es prefijo de otro.
Forma un árbol binario:

            (root)
           /     \
          a      (·)
                /    \
              (·)    (·)
              / \    / \
             b   c  d   (·)
                       / \
                      e   f
```

## 10.3 Algoritmo greedy de Huffman (CLRS 16.3)

```text
HUFFMAN(C):                          // C = cola de prioridad con frecuencias
    n = |C|
    Q = min-heap con las n frecuencias

    for i = 1 to n-1:
        z = nuevo nodo
        z.left  = x = EXTRACT-MIN(Q)
        z.right = y = EXTRACT-MIN(Q)
        z.freq  = x.freq + y.freq
        INSERT(Q, z)

    return EXTRACT-MIN(Q)           // raíz del árbol
```

## 10.4 Ejemplo paso a paso

```text
Frecuencias iniciales: {a:45, b:13, c:12, d:16, e:9, f:5}

Paso 1: combinar los dos menores: f(5) y e(9) → fe(14)
         Cola: {a:45, b:13, c:12, d:16, fe:14}

Paso 2: combinar los dos menores: c(12) y b(13) → bc(25)
         Cola: {a:45, d:16, fe:14, bc:25}

Paso 3: combinar fe(14) y d(16) → fed(30)
         Cola: {a:45, bc:25, fed:30}

Paso 4: combinar bc(25) y fed(30) → bcfed(55)
         Cola: {a:45, bcfed:55}

Paso 5: combinar a(45) y bcfed(55) → raíz(100)
         Cola: {raíz:100}
```

## 10.5 Árbol resultante

```text
                   (100)
                  /     \
                a(45)    (55)
                        /    \
                     bc(25)   (30)
                     /   \    /    \
                  b(13) c(12) f(14) e(16)
                                / \
                              f(5) e(9)

Códigos resultantes (0=izquierda, 1=derecha):
   a: 0
   b: 100
   c: 101
   d: 111
   e: 1101
   f: 1100
```

## 10.6 Costo total

```text
B(f) = Σᵢ fᵢ · lᵢ   donde lᵢ = longitud del código del símbolo i

   a: 45 · 1  =  45
   b: 13 · 3  =  39
   c: 12 · 3  =  36
   d: 16 · 3  =  48
   e:  9 · 4  =  36
   f:  5 · 4  =  20
   ─────────────────
   Total      = 224  bits

vs ASCII fijo (8 bits/caracter): 6·8 = 48 caracteres × 8 = 384 bits
Ahorro: 41.7%
```

## 10.7 Implementación en C

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Nodo {
    char ch;
    int freq;
    struct Nodo *izq, *der;
} Nodo;

Nodo *nuevoNodo(char ch, int freq) {
    Nodo *n = malloc(sizeof(Nodo));
    n->ch = ch; n->freq = freq;
    n->izq = n->der = NULL;
    return n;
}

typedef struct {
    Nodo **arr;
    int tam;
} MinHeap;

void swapNodo(Nodo **a, Nodo **b) { Nodo *t = *a; *a = *b; *b = t; }

void heapify(MinHeap *h, int i) {
    int menor = i, izq = 2*i+1, der = 2*i+2;
    if (izq < h->tam && h->arr[izq]->freq < h->arr[menor]->freq) menor = izq;
    if (der < h->tam && h->arr[der]->freq < h->arr[menor]->freq) menor = der;
    if (menor != i) {
        swapNodo(&h->arr[i], &h->arr[menor]);
        heapify(h, menor);
    }
}

Nodo *extractMin(MinHeap *h) {
    Nodo *n = h->arr[0];
    h->arr[0] = h->arr[--h->tam];
    heapify(h, 0);
    return n;
}

void insertHeap(MinHeap *h, Nodo *n) {
    h->arr[h->tam++] = n;
    for (int i = h->tam/2 - 1; i >= 0; i--) heapify(h, i);
}

Nodo *huffman(char chars[], int freqs[], int n) {
    MinHeap h = { malloc(n * 2 * sizeof(Nodo*)), 0 };
    for (int i = 0; i < n; i++)
        insertHeap(&h, nuevoNodo(chars[i], freqs[i]));

    while (h.tam > 1) {
        Nodo *x = extractMin(&h);
        Nodo *y = extractMin(&h);
        Nodo *z = nuevoNodo('$', x->freq + y->freq);
        z->izq = x; z->der = y;
        insertHeap(&h, z);
    }
    return extractMin(&h);
}

void imprimirCodigos(Nodo *raiz, int arr[], int top) {
    if (raiz->izq) { arr[top] = 0; imprimirCodigos(raiz->izq, arr, top+1); }
    if (raiz->der) { arr[top] = 1; imprimirCodigos(raiz->der, arr, top+1); }
    if (!raiz->izq && !raiz->der) {
        printf("  %c: ", raiz->ch);
        for (int i = 0; i < top; i++) printf("%d", arr[i]);
        printf("\n");
    }
}
```

## 10.8 Implementación en Python

```python
import heapq

class Nodo:
    def __init__(self, ch, freq, izq=None, der=None):
        self.ch, self.freq = ch, freq
        self.izq, self.der = izq, der

    def __lt__(self, other):
        return self.freq < other.freq

def huffman(frecuencias):
    """frecuencias: dict {simbolo: freq}"""
    heap = [Nodo(ch, f) for ch, f in frecuencias.items()]
    heapq.heapify(heap)

    while len(heap) > 1:
        x = heapq.heappop(heap)
        y = heapq.heappop(heap)
        z = Nodo('$', x.freq + y.freq, x, y)
        heapq.heappush(heap, z)

    return heap[0]

def imprimir(nodo, prefijo=""):
    if nodo.ch != '$':
        print(f"  {nodo.ch}: {prefijo}")
        return
    imprimir(nodo.izq, prefijo + "0")
    imprimir(nodo.der, prefijo + "1")

freqs = {'a':45, 'b':13, 'c':12, 'd':16, 'e':9, 'f':5}
raiz = huffman(freqs)
imprimir(raiz)
```

## 10.9 Prueba de optimalidad (CLRS 16.3)

```text
Lema 1 (greedy-choice): Existe un árbol óptimo donde los dos símbolos
menos frecuentes son hermanos en las hojas más profundas.

  Prueba: si los símbolos menos frecuentes x e y no son hermanos,
  intercambiamos sus posiciones. La profundidad de x crece, pero
  la de y decrece (o queda igual). Como fᵢ ≤ fⱼ ≤ fₖ, el costo
  total no aumenta. ✓

Lema 2 (optimal substructure): Considera los dos menos frecuentes
x e y combinados en un nuevo símbolo z con freq f(x)+f(y).
Si T' es óptimo para el problema reducido, entonces T (con z
expandido de nuevo) es óptimo para el original.

  Prueba: por contradicción, manipulación algebraica del costo. ✓

Teorema: HUFFMAN es óptimo.
```

## 10.10 Complejidad

| Fase              | Tiempo                          |
| ----------------- | ------------------------------- |
| Construir heap    | O(n)                            |
| n-1 extracciones  | O(n log n)                      |
| **Total**         | **O(n log n)**                  |

## 10.11 Aplicaciones

| Aplicación             | Por qué Huffman                  |
| ---------------------- | -------------------------------- |
| **ZIP / GZIP**         | Huffman en DEFLATE                |
| **JPEG**               | Huffman en codificación de coefs  |
| **MP3**                | Huffman en cuantización           |
| **PNG**                | Compresión lossless              |
| **Transmisión de datos**| Minimiza ancho de banda          |

> **Conexión:** Ver `Sorting.md` (Heap Sort) — Huffman es esencialmente un heap en acción.

---

# 11. Dijkstra (Camino Más Corto)

## 11.1 El problema

Dado un grafo `G = (V, E)` con pesos **no negativos** `w: E → ℝ⁺`, y un vértice origen `s`, encontrar el camino de peso mínimo desde `s` a cada otro vértice.

```text
Este es el problema SSSP (Single-Source Shortest Path) en grafos con
pesos no negativos. (CLRS Cap. 24, Single-Source Shortest Paths.)
```

## 11.2 Idea greedy

> **Elección voraz:** en cada paso, elegir el vértice **no procesado** con la **distancia más corta** desde el origen.

```text
¿Por qué funciona con pesos no negativos?
   Una vez que fijas la distancia más corta al vértice u, ningún camino
   alternativo que pase por otros vértices no procesados puede mejorarla
   (los pesos son no negativos, no hay "descuento" esperando).
```

## 11.3 Algoritmo (CLRS 24.3)

```text
DIJKSTRA(G, w, s):
    INIT-SINGLE-SOURCE(G, s)            // d[v] = ∞, π[v] = NIL
    S = ∅                               // conjunto de "ya fijados"
    Q = min-priority-queue con todos los vértices, clave = d[v]

    while Q ≠ ∅:
        u = EXTRACT-MIN(Q)
        S = S ∪ {u}
        for each v ∈ Adj[u]:
            RELAX(u, v, w)
```

```text
RELAX(u, v, w):
    if d[v] > d[u] + w(u, v):
        d[v]  = d[u] + w(u, v)
        π[v]  = u
        DECREASE-KEY(Q, v, d[v])
```

## 11.4 Ejemplo paso a paso

```text
Grafo:
      (2)        (4)
   s ───→ A ────→ B
   │      │        │
   │(4)   │(1)    │(3)
   ↓      ↓       ↓
   C ────→ D      E
    (3)    (2)   (1)
     \            /
      \──────────┘
       (5)

Tabla de ejecución:

Iter | u     | d[s] | d[A] | d[B] | d[C] | d[D] | d[E] | S
-----+-------+------+------+------+------+------+------+------
inic |  -    |   0  |   ∞  |   ∞  |   ∞  |   ∞  |   ∞  | {}
  1  |  s    |   0  |   2  |   ∞  |   4  |   ∞  |   ∞  | {s}
  2  |  A    |   0  |   2  |   6  |   4  |   3  |   ∞  | {s,A}
  3  |  D    |   0  |   2  |   6  |   4  |   3  |   5  | {s,A,D}
  4  |  C    |   0  |   2  |   6  |   4  |   3  |   5  | {s,A,D,C}
  5  |  E    |   0  |   2  |   6  |   4  |   3  |   5  | {s,A,D,C,E}
  6  |  B    |   0  |   2  |   6  |   4  |   3  |   5  | ALL
```

## 11.5 Implementación en C (con matriz de adyacencia)

```c
#include <stdio.h>
#include <limits.h>

#define V 6
#define INF INT_MAX

int minDist(int dist[], int visitado[]) {
    int min = INF, idx = -1;
    for (int v = 0; v < V; v++)
        if (!visitado[v] && dist[v] <= min)
            min = dist[v], idx = v;
    return idx;
}

void dijkstra(int grafo[V][V], int src) {
    int dist[V], visitado[V] = {0};

    for (int i = 0; i < V; i++) dist[i] = INF;
    dist[src] = 0;

    for (int count = 0; count < V - 1; count++) {
        int u = minDist(dist, visitado);
        visitado[u] = 1;

        for (int v = 0; v < V; v++)
            if (!visitado[v] && grafo[u][v] && dist[u] + grafo[u][v] < dist[v])
                dist[v] = dist[u] + grafo[u][v];
    }

    printf("Distancias desde %d:\n", src);
    for (int i = 0; i < V; i++) printf("  %d: %d\n", i, dist[i]);
}
```

## 11.6 Implementación en C (con heap — más eficiente)

```c
typedef struct { int v; int peso; } Arista;
typedef struct { int n; Arista *adj; int *tam; } Grafo;

// Versión simplificada con priority queue
// (Para grafos grandes, usar binary heap o Fibonacci heap.)

void dijkstraHeap(Grafo *g, int src, int *dist) {
    // Implementación con binary heap
    // ... EXTRACT-MIN y DECREASE-KEY en O(log n) ...
}
```

## 11.7 Implementación en Python

```python
import heapq

def dijkstra(grafo, origen):
    """
    grafo: dict {u: [(v, peso), ...]}
    Retorna: dict {v: distancia minima}
    """
    dist = {v: float('inf') for v in grafo}
    dist[origen] = 0
    pq = [(0, origen)]
    visitados = set()

    while pq:
        d, u = heapq.heappop(pq)
        if u in visitados:
            continue
        visitados.add(u)

        for v, w in grafo[u]:
            nueva = d + w
            if nueva < dist[v]:
                dist[v] = nueva
                heapq.heappush(pq, (nueva, v))

    return dist

# Ejemplo:
g = {
    's': [('A', 2), ('C', 4)],
    'A': [('B', 4), ('D', 1)],
    'B': [('E', 3)],
    'C': [('D', 3), ('E', 5)],
    'D': [('E', 2)],
    'E': []
}
print(dijkstra(g, 's'))
# → {'s':0, 'A':2, 'C':4, 'B':6, 'D':3, 'E':5}
```

## 11.8 Pruebas de optimalidad (CLRS 24.3)

```text
Lema (greedy-choice): existe un camino más corto que pasa solo por
vértices de S ∪ {u} cuando u es elegido.

  Prueba: si existiera un camino más corto que sale de S sin pasar
  por u primero, su primer vértice fuera de S tendría distancia ≤ la
  de u (por la propiedad de optimalidad de subestructura). Contradice
  que u tiene la menor distancia en Q. ✓

Lema (correctitud del RELAX): el camino a través de u nunca es peor
que el camino óptimo si actualizamos cuando es mejor. ✓

Teorema: Dijkstra es correcto para pesos no negativos.
```

## 11.9 Complejidad

| Implementación                | Tiempo        |
| ----------------------------- | ------------- |
| Matriz de adyacencia          | O(V²)         |
| Lista + binary heap           | O((V+E) log V)|
| Lista + Fibonacci heap        | O(E + V log V)|

| Espacio     | O(V)                       |

## 11.10 Limitaciones

| Situación                          | ¿Dijkstra funciona?          |
| ---------------------------------- | ---------------------------- |
| Pesos **no negativos**             | ✅ Sí                         |
| Pesos negativos (sin ciclos)       | ⚠️ Usar Bellman-Ford         |
| Pesos negativos con ciclos         | ❌ Problema está mal definido |
| Grafo dirigido vs no dirigido      | Ambos funcionan              |

> **CLRS Cap. 24:** Dijkstra aparece en el Capítulo 24 (Single-Source Shortest Paths). Bellman-Ford maneja pesos negativos.

## 11.11 Variaciones

| Variación                                  | Algoritmo                  |
| ------------------------------------------ | -------------------------- |
| SSSP con pesos no negativos                | Dijkstra                   |
| SSSP con pesos negativos                   | Bellman-Ford               |
| APSP (todos los pares)                     | Floyd-Warshall             |
| APSP grafos densos                         | Johnson                    |
| Caminos K-cortos                            | Eppstein / Yen             |

---

# 12. Minimum Spanning Tree — MST (CLRS Cap. 23)

## 12.1 El problema

Dado un grafo **conexo** y **no dirigido** `G = (V, E)` con pesos `w: E → ℝ`, encontrar un subconjunto `T ⊆ E` tal que:

```text
1. (V, T) es un árbol (conexo, sin ciclos).
2. La suma de pesos es mínima.
```

> **CLRS Cap. 23 (Minimum Spanning Trees):** capítulo entero dedicado.

## 12.2 Notación

| Símbolo     | Significado                               |
| ----------- | ----------------------------------------- |
| `G = (V,E)` | Grafo original                            |
| `T`         | MST resultante                            |
| `w(T)`      | Peso total de las aristas en T            |
| `cut (S, V-S)` | Partición del conjunto de vértices     |

## 12.3 Las dos propiedades fundamentales

### Cut Property (CLRS 23.1)

> **Si una arista `e` es la de peso mínimo cruzando algún cut `(S, V-S)`, entonces `e` está en TODA MST.**

```text
Demostración: por contradicción.
   Supón MST T no incluye e.
   Como T es spanning, hay otra arista f cruzando el cut en T.
   Si w(e) < w(f), podemos reemplazar f por e → T' tiene menos peso,
   contradiciendo minimalidad de T. ✓
```

### Cycle Property (CLRS 23.1)

> **Si una arista `e` es la de peso MÁXIMO en algún ciclo `C`, entonces `e` NO está en ninguna MST.**

```text
Demostración: análoga, por contradicción.
   Si T incluye e, podemos quitarla (ciclo se rompe en otro lado),
   y reemplazar por otra arista de peso menor en el ciclo. ✓
```

## 12.4 Generic-MST (CLRS 23.2)

```text
GENERIC-MST(G, w):
    A = ∅
    while A no forma un spanning tree:
        encontrar arista (u, v) que es "segura" para A
        A = A ∪ {(u, v)}
    return A
```

```text
¿Qué significa "segura"?
   Una arista (u, v) es SEGURA para A si:
      - Une dos componentes distintas del bosque (V, A).
      - Es la de menor peso cruzando ese cut.
```

## 12.5 Tres algoritmos clásicos

| Algoritmo  | Estrategia                                          | Estrategia interna          |
| ---------- | --------------------------------------------------- | --------------------------- |
| **Kruskal** | Ordenar aristas por peso; agregar si no forma ciclo | Edge-based greedy           |
| **Prim**   | Crecer un árbol desde un vértice                    | Vertex-based greedy         |
| **Boruvka**| Combinar componentes en paralelo                    | Edge-based (paralelo)       |

Los tres son **greedy** con diferentes reglas de selección.

## 12.6 Comparación rápida

| Característica          | Kruskal          | Prim (lazy)         | Prim (eager)        | Boruvka      |
| ---------------------- | ---------------- | ------------------- | ------------------- | ------------ |
| **Estructura**         | Union-Find       | PQ de aristas       | PQ de vértices      | Union-Find   |
| **Complejidad**        | O(E log E)       | O(E log V)          | O(E + V log V)      | O(E log V)   |
| **Grafos densos**      | Más lento        | OK                  | **Mejor**           | OK           |
| **Grafos dispersos**   | **Mejor**        | OK                  | OK                  | OK           |
| **Paralelizable**      | Difícil          | Difícil             | Difícil             | **Sí**       |

## 12.7 ¿Por qué greedy funciona aquí?

```text
Por el cut property: en cada paso, agregar la arista más barata que
CRUZA algún cut preserva optimalidad.

Esto es exactamente el teorema del matroid:
   - M_G = (E, bosques) es un matroid.
   - El peso es la suma de pesos de aristas.
   - Por el teorema (CLRS 16.4), el greedy es óptimo. ✓
```

> **Conexión directa con la sección 6 (Matroides).** MST es la aplicación más importante de la teoría de matroides.

---

# 13. Kruskal

## 13.1 La idea

> **Estrategia greedy:** considerar las aristas en **orden de peso ascendente**. Agregar cada arista si **no forma ciclo**.

```text
Equivalente al cut property:
   cuando ordenas por peso y agregas la más barata, esa arista cruza
   algún cut y es la más barata cruzando ese cut. ✓
```

## 13.2 Algoritmo (CLRS 23.2)

```text
MST-KRUSKAL(G, w):
    A = ∅
    for each v ∈ V:
        MAKE-SET(v)                    // Union-Find

    ordenar E en orden no decreciente de peso

    for each (u, v) ∈ E (en ese orden):
        if FIND-SET(u) ≠ FIND-SET(v):  // no forman ciclo
            A = A ∪ {(u, v)}
            UNION(u, v)

    return A
```

## 13.3 Estructura: Union-Find (Disjoint Set)

| Operación       | Con path compression + union by rank |
| --------------- | ----------------------------------- |
| `MAKE-SET(x)`   | O(1)                                |
| `FIND-SET(x)`   | O(α(n)) amortizado (α = inversa de Ackermann, < 5) |
| `UNION(x, y)`   | O(α(n)) amortizado                  |

> En la práctica, `α(n)` se trata como O(1).

## 13.4 Ejemplo paso a paso

```text
Grafo:
                2              3
            A ───── B ──────── C
            │ \     │ \        │
           6│  5\   │1  4\     │7
            │    \  │    \    │
            D ───── E ─────── F
                3              2

Aristas ordenadas:
   (A,B): 2
   (B,C): 3
   (D,E): 3
   (E,F): 2
   (B,E): 1
   (A,E): 5
   (C,F): 7
   (A,D): 6

Ejecución:

paso | arista     | peso | acción         | componentes
-----+------------+------+----------------+-------------------
  -  |    init    |  -   | 6 singletons   | {A}{B}{C}{D}{E}{F}
  1  | (B,E)      |  1   | agregar        | {A}{B,E}{C}{D}{F}
  2  | (A,B)      |  2   | agregar (une AB-E) | {A,B,E}{C}{D}{F}
  3  | (E,F)      |  2   | agregar        | {A,B,E,F}{C}{D}
  4  | (B,C)      |  3   | agregar        | {A,B,C,E,F}{D}
  5  | (D,E)      |  3   | agregar (une D-ABCEF) | {A,B,C,D,E,F}
  6  | (A,E)      |  5   | SKIP (ciclo)
  7  | (A,D)      |  6   | SKIP (ciclo)
  8  | (C,F)      |  7   | SKIP (ciclo)

MST: {(B,E),(A,B),(E,F),(B,C),(D,E)}
Peso: 1 + 2 + 2 + 3 + 3 = 11
```

### Visualización del MST

```text
                2              3
            A ───── B ──────── C
                       \        │
                       1\       │ (no incluida)
                          \     │
                           E ───┘ (F se conecta por E)
                           │
                           3
                           │
                           D

MST final:
   A ── B
   │    │ \
   │    │  \
   │    E   C
   │    │
   D────┘
        │
        F
```

## 13.5 Implementación en C

```c
typedef struct {
    int u, v, peso;
} Arista;

int cmpArista(const void *a, const void *b) {
    return ((Arista*)a)->peso - ((Arista*)b)->peso;
}

int parent[100], rango[100];

void makeSet(int v) { parent[v] = v; rango[v] = 0; }
int findSet(int v) {
    if (parent[v] != v) parent[v] = findSet(parent[v]);
    return parent[v];
}
void unionSets(int a, int b) {
    a = findSet(a); b = findSet(b);
    if (a == b) return;
    if (rango[a] < rango[b]) { int t = a; a = b; b = t; }
    parent[b] = a;
    if (rango[a] == rango[b]) rango[a]++;
}

void kruskal(Arista aristas[], int nAristas, int nVerts) {
    Arista mst[nVerts - 1];
    int k = 0;

    for (int i = 0; i < nVerts; i++) makeSet(i);
    qsort(aristas, nAristas, sizeof(Arista), cmpArista);

    for (int i = 0; i < nAristas && k < nVerts - 1; i++) {
        int u = aristas[i].u, v = aristas[i].v;
        if (findSet(u) != findSet(v)) {
            mst[k++] = aristas[i];
            unionSets(u, v);
        }
    }

    printf("MST (peso %d):\n", sumaPesos(mst, k));
    for (int i = 0; i < k; i++)
        printf("  (%d, %d) peso %d\n",
               mst[i].u, mst[i].v, mst[i].peso);
}
```

## 13.6 Implementación en Python

```python
class UnionFind:
    def __init__(self, n):
        self.padre = list(range(n))
        self.rango = [0] * n

    def find(self, x):
        if self.padre[x] != x:
            self.padre[x] = self.find(self.padre[x])
        return self.padre[x]

    def union(self, a, b):
        a, b = self.find(a), self.find(b)
        if a == b: return False
        if self.rango[a] < self.rango[b]: a, b = b, a
        self.padre[b] = a
        if self.rango[a] == self.rango[b]: self.rango[a] += 1
        return True

def kruskal(n, aristas):
    """
    n: # vértices
    aristas: lista de (u, v, peso)
    """
    aristas = sorted(aristas, key=lambda x: x[2])
    uf = UnionFind(n)
    mst, peso = [], 0

    for u, v, w in aristas:
        if uf.union(u, v):
            mst.append((u, v, w))
            peso += w

    return mst, peso

# Ejemplo:
aristas = [('A','B',2),('B','C',3),('D','E',3),('E','F',2),
           ('B','E',1),('A','E',5),('C','F',7),('A','D',6)]
verts = {'A':0,'B':1,'C':2,'D':3,'E':4,'F':5}
ar_idx = [(verts[u], verts[v], w) for u, v, w in aristas]

mst, peso = kruskal(6, ar_idx)
print(f"MST peso = {peso}")
for u, v, w in mst:
    print(f"  {u} - {v}  ({w})")
```

## 13.7 Prueba de optimalidad

```text
Teorema: Kruskal produce un MST.

Prueba (cut property):
   Sea e la arista de menor peso entre todas las no revisadas que
   conectan dos componentes distintas.
   Esta arista cruza el cut entre esas dos componentes.

   Por el cut property, e está en toda MST.

   Por inducción sobre # de aristas agregadas, el algoritmo completo
   construye un MST. ✓
```

## 13.8 Complejidad

| Fase                         | Tiempo                |
| ---------------------------- | --------------------- |
| Ordenar aristas              | O(E log E)            |
| `n-1` operaciones Union-Find | O((V+E) α(V)) ≈ O(E)  |
| **Total**                    | **O(E log E)** = O(E log V) |

> **Espacio:** O(V + E).

## 13.9 Variaciones

| Variación                            | Algoritmo                      |
| ------------------------------------ | ------------------------------ |
| **Maximum** Spanning Tree            | Mismo algoritmo, orden inverso |
| MST con costos en vértices            | Transformar: edge cost = suma  |
| MST dinámico (cambios en grafo)       | Estructuras dinámicas (complejo) |
| MST en grafos **dirigidos** (arborescencias) | Edmonds/Chu-Liu          |

---

# 14. Prim (Lazy y Eager)

## 14.1 La idea

> **Estrategia greedy:** crecer **un solo árbol** desde un vértice inicial. En cada paso, agregar la arista de menor peso que conecta el árbol con un vértice fuera de él.

```text
Diferencia con Kruskal:
   Kruskal: множество árboles que se van uniendo.
   Prim:    un solo árbol que va creciendo.
```

## 14.2 Algoritmo base (CLRS 23.2)

```text
MST-PRIM(G, w, r):
    for each u ∈ V:
        key[u]  = ∞
        π[u]   = NIL
    key[r]  = 0
    Q = V                               // cola con todos los vértices

    while Q ≠ ∅:
        u = EXTRACT-MIN(Q)             // vértice con menor key
        for each v ∈ Adj[u]:
            if v ∈ Q and w(u, v) < key[v]:
                π[v]   = u
                key[v] = w(u, v)
```

## 14.3 Dos versiones: Lazy vs Eager

### Lazy Prim (CLRS 23.2, Exercise)

```text
- PQ guarda ARISTAS candidatas (puede haber duplicados).
- Al extraer, verifica si el destino aún no está en T.
- Si ya está, descarta.

Complejidad: O(E log E)
```

### Eager Prim

```text
- PQ guarda VÉRTICES con su key actual.
- Solo una entrada por vértice → DECREASE-KEY en lugar de duplicados.

Complejidad: O(E + V log V) con binary heap, mejor para grafos densos.
```

## 14.4 Ejemplo paso a paso

```text
Grafo:
      (A)──2──(B)
       │ \     │
       6  5    1
       │   \   │
      (D)──3──(E)──4──(C)
                  │
                  7
                  │
                 (F)

Empezamos en A.   T = {A}

Iter | u  | key[B] key[C] key[D] key[E] key[F] | T
-----+----+--------+--------+--------+--------+--------+--------
inic |  - |   ∞    |   ∞    |   ∞    |   ∞    |   ∞    | {A}
  1  |  A |   2(A) |   ∞    |   6(A) |   5(A) |   ∞    | {A,B}
  2  |  B |   -    |   ∞    |   6(A) |   1(B) |   ∞    | {A,B,E}
  3  |  E |   -    |   5(E) |   3(E) |   -    |   ∞    | {A,B,E,D}
  4  |  D |   -    |   5(E) |   -    |   -    |   ∞    | {A,B,E,D,C}
  5  |  C |   -    |   -    |   -    |   -    |  7(C)  | {A,B,E,D,C,F}
  6  |  F |   -    |   -    |   -    |   -    |   -    | ALL

MST: {(A,B),(B,E),(E,D),(E,C),(C,F)}
Peso: 2 + 1 + 3 + 4 + 7 = 17
```

## 14.5 Implementación en C (Lazy Prim)

```c
typedef struct {
    int destino, peso;
    int activo;       // ¿aún es candidato válido?
} AristaPQ;

typedef struct {
    AristaPQ *arr;
    int tam;
} MinHeap;

void lazyPrim(int n, int grafo[n][n], int origen) {
    int enArbol[n] = {0};
    int key[n];
    int padre[n];

    for (int i = 0; i < n; i++) { key[i] = INT_MAX; padre[i] = -1; }
    key[origen] = 0;

    MinHeap pq = { malloc(n * n * sizeof(AristaPQ)), 0 };
    // Insertar aristas desde origen
    for (int v = 0; v < n; v++)
        if (v != origen) {
            pq.arr[pq.tam++] = (AristaPQ){v, grafo[origen][v], 1};
        }

    while (pq.tam > 0) {
        AristaPQ e = extractMin(&pq);
        int u = e.destino;
        if (enArbol[u]) continue;
        enArbol[u] = 1;
        for (int v = 0; v < n; v++)
            if (!enArbol[v] && grafo[u][v] < key[v]) {
                key[v] = grafo[u][v];
                padre[v] = u;
                pq.arr[pq.tam++] = (AristaPQ){v, key[v], 1};
            }
    }
}
```

## 14.6 Implementación en Python (Eager Prim)

```python
import heapq

def prim(grafo, origen):
    """
    grafo: dict {u: [(v, peso), ...]}
    """
    visitados = {origen}
    # (peso, origen, destino)
    pq = [(w, origen, v) for v, w in grafo[origen]]
    heapq.heapify(pq)

    mst = []
    peso_total = 0

    while pq:
        w, u, v = heapq.heappop(pq)
        if v in visitados:
            continue
        visitados.add(v)
        mst.append((u, v, w))
        peso_total += w

        for prox, peso in grafo[v]:
            if prox not in visitados:
                heapq.heappush(pq, (peso, v, prox))

    return mst, peso_total

g = {
    'A': [('B', 2), ('D', 6), ('E', 5)],
    'B': [('A', 2), ('C', 3), ('E', 1)],
    'C': [('B', 3), ('E', 4), ('F', 7)],
    'D': [('A', 6), ('E', 3)],
    'E': [('A', 5), ('B', 1), ('C', 4), ('D', 3)],
    'F': [('C', 7)]
}
mst, peso = prim(g, 'A')
print(f"MST peso = {peso}")
# → MST peso = 17
```

## 14.7 Prueba de optimalidad

```text
Teorema: Prim produce un MST.

Prueba (cut property):
   En cada paso, el algoritmo elige la arista de menor peso cruzando
   el cut (T, V - T).
   Por el cut property, esa arista está en TODA MST.
   Por inducción, las aristas elegidas forman un MST. ✓
```

## 14.8 Complejidad

| Versión            | Tiempo           | Mejor para              |
| ------------------ | ---------------- | ----------------------- |
| Lazy Prim          | O(E log E)       | Grafos dispersos        |
| Eager Prim         | O(E + V log V)   | Grafos densos           |
| Prim con Fibonacci | O(E + V log V)   | Asintóticamente óptimo  |

| Espacio | O(V)                           |

## 14.9 Kruskal vs Prim: ¿cuándo usar cada uno?

| Característica del grafo      | Recomendación        |
| ----------------------------- | -------------------- |
| Disperso (E ≈ V)              | **Kruskal**          |
| Denso (E ≈ V²)                | **Prim (eager)**     |
| Necesitas otros bosques       | **Kruskal** (más natural) |
| Procesamiento paralelo        | **Boruvka**          |
| Implementación simple         | **Kruskal**          |

> **Regla práctica:** Kruskal es **más fácil de implementar correctamente**. Prim es más eficiente en grafos densos.

---

# 15. Boruvka (Mención Histórica)

## 15.1 Contexto histórico

> **Otakar Borůvka (1926)** describió el **primer algoritmo de MST** conocido, para la red eléctrica de Moravia.
> Es anterior a Kruskal (1956) y Prim (1957) por **30 años**.

## 15.2 La idea (paralela)

```text
1. Para cada componente, encontrar la arista más barata que sale.
2. Agregar TODAS esas aristas simultáneamente.
3. Repetir hasta tener un solo componente.
```

```text
Por el cut property, cada arista elegida es la más barata
cruzando el cut de su componente → está en alguna MST. ✓
```

## 15.3 Visualización

```text
Iteración 1: cada vértice es su propio componente.

   (A)──2──(B)
    │       │           Componente {A}: elige (A,B) peso 2
    6       1           Componente {B}: elige (B,E) peso 1
    │       │           Componente {C}: elige (C,E) peso 4
   (D)──3──(E)──4──(C)  Componente {D}: elige (D,E) peso 3
               │         Componente {E}: elige (B,E) peso 1
               7
               │
              (F)

Agregar: (A,B), (B,E), (C,E), (D,E), (C,F)   ← las 5 aristas en paralelo

Iteración 2: componentes son {A,B,E,D,C,F}.
   Componente elige arista más barata saliente → puede que sea (B,C) o (C,F)
   ...
```

## 15.4 Complejidad

| Tiempo               | Observación                         |
| -------------------- | ----------------------------------- |
| O(E log V)           | # de iteraciones ≤ log₂ V (cada una al menos duplica componentes) |
| **Paralelizable**    | Cada iteración es paralela por componente |

## 15.5 Importancia moderna

> **Borůvka es el algoritmo paralelo de MST más simple.** Es la base de algoritmos más avanzados (Karger-Klein-Tarjan, O(E) randomized).

---

# 16. Job Sequencing con Deadlines

## 16.1 El problema

Tienes `n` trabajos. Cada trabajo `i` tiene:
- ganancia `gᵢ`
- deadline `dᵢ` (1 ≤ dᵢ ≤ n)

**Solo un trabajo por unidad de tiempo.** Empezando en t=1. Si un trabajo termina después de su deadline → no cuenta.

```text
Objetivo: maximizar la ganancia total.

Trabajos:    J1 (g=20, d=2),  J2 (g=15, d=2),  J3 (g=10, d=1),  J4 (g=5, d=3)

Óptimo: J1 en slot 1-2, J4 en slot 3 → 25
        (Otra opción: J3 + J2 → 25, también óptimo)
```

## 16.2 Estrategia greedy

```text
1. Ordenar trabajos por ganancia DESCENDENTE.
2. Para cada trabajo, asignarlo al ÚLTIMO slot disponible antes de su deadline.
3. Si el slot está ocupado, saltar (no se puede).
```

```text
Trabajos ordenados: J1(20,d=2), J2(15,d=2), J3(10,d=1), J4(5,d=3)

  J1 → último slot libre ≤ 2: slot 2 ✓   {[1, J1]}
  J2 → último slot libre ≤ 2: slot 1 ✓   {[J2, J1]}
  J3 → último slot libre ≤ 1: ninguno ✗
  J4 → último slot libre ≤ 3: slot 3 ✓   {[J2, J1, J4]}

Ganancia: 15 + 20 + 5 = 40
```

## 16.3 Algoritmo

```text
JOB-SEQ(g, d, n):
    ordenar trabajos por g descendente
    slots[1..max(d)] = {LIBRE}

    for i = 1 to n:
        for t = min(d[i], max_d) downto 1:
            if slots[t] == LIBRE:
                slots[t] = i
                break

    return trabajos en slots
```

## 16.4 Implementación en C

```c
typedef struct {
    int id, ganancia, deadline;
} Trabajo;

int cmpGanancia(const void *a, const void *b) {
    return ((Trabajo *)b)->ganancia - ((Trabajo *)a)->ganancia;
}

int jobSequencing(Tabajo trab[], int n, int max_d) {
    qsort(trab, n, sizeof(Trabajo), cmpGanancia);

    int slots[max_d + 1];
    for (int i = 0; i <= max_d; i++) slots[i] = -1;

    int gananciaTotal = 0;
    for (int i = 0; i < n; i++) {
        for (int t = trab[i].deadline; t > 0; t--) {
            if (slots[t] == -1) {
                slots[t] = trab[i].id;
                gananciaTotal += trab[i].ganancia;
                break;
            }
        }
    }

    printf("Slots:\n");
    for (int t = 1; t <= max_d; t++)
        printf("  slot %d: trabajo %s\n", t,
               slots[t] == -1 ? "libre" : "ocupado");
    return gananciaTotal;
}
```

## 16.5 Implementación en Python (con Union-Find)

```python
class DSU:
    def __init__(self, n):
        self.padre = list(range(n))
    def find(self, x):
        if self.padre[x] != x:
            self.padre[x] = self.find(self.padre[x])
        return self.padre[x]
    def union(self, a, b):
        self.padre[a] = b

def job_sequencing(trabajos, max_d):
    """
    trabajos: lista de (ganancia, deadline)
    """
    trabajos = sorted(trabajos, key=lambda x: -x[0])
    dsu = DSU(max_d + 2)
    resultado = []
    ganancia = 0

    for g, d in trabajos:
        # Encontrar slot libre más tardío antes de d
        slot = dsu.find(min(d, max_d))
        if slot > 0:
            resultado.append((slot, g))
            ganancia += g
            dsu.union(slot, slot - 1)

    return sorted(resultado), ganancia
```

## 16.6 Complejidad

| Versión                  | Tiempo                |
| ------------------------ | --------------------- |
| Ordenar                  | O(n log n)            |
| Búsqueda ingenua         | O(n²)                 |
| Búsqueda con Union-Find  | O(n α(n) + n log n) ≈ O(n log n) |

## 16.7 Prueba de optimalidad

```text
Teorema: el algoritmo greedy es óptimo.

Prueba (exchange argument):
   Sea g₁ ≥ g₂ ≥ ... ≥ gₙ la lista ordenada.
   Sea S el conjunto seleccionado por greedy.
   Sea S* un óptimo.

   Para cada trabajo en S* pero no en S, hay un trabajo en S pero
   no en S* con ganancia MAYOR O IGUAL (por la elección greedy).
   Por intercambio, podemos transformar S* en S sin perder ganancia.

   Conclusión: S es óptimo. ✓
```

## 16.8 Variaciones

| Variación                                | Estrategia              |
| ---------------------------------------- | ----------------------- |
| Una tarea por slot                       | Greedy (sección 16)     |
| Múltiples tareas por slot                | DP                      |
| Tareas con duraciones variables          | **DP** (NP-hard en general) |
| Tareas con收益 dependientes de tiempo    | DP                      |

---

# 17. Greedy en Geometría — Convex Hull

## 17.1 El problema

Dados `n` puntos en el plano, encontrar el **polígono convexo más pequeño** que los contiene a todos.

```text
              *
            *   *
           *     *
          *       *                *
        *           *           *
       *              *       *
        *                *  *
          *                  *
            *            *
               *      *
                   *
   → El convex hull es el polígono que pasa por los *
     "extremos" conectándolos en orden.
```

## 17.2 Aplicaciones

| Aplicación                              | Por qué importa el convex hull            |
| --------------------------------------- | ---------------------------------------- |
| Detección de colisiones en videojuegos  | ¿Está el punto dentro del hull?          |
| Path planning (robot)                   | Navegar alrededor de obstáculos           |
| Análisis de formas (visión)             | Encontrar el contorno de un objeto       |
| Cómputo de diámetro de un conjunto      | El diámetro siempre está en el hull      |

## 17.3 Algoritmos clásicos

| Algoritmo               | Tiempo        | Estrategia                      |
| ----------------------- | ------------- | ------------------------------- |
| **Graham Scan**         | O(n log n)    | Greedy por ángulo               |
| Jarvis March (gift wrap)| O(nh)         | Greedy por "extremo lateral"    |
| QuickHull               | O(n log n) esperado | D&C-like                |
| Chan's Algorithm        | O(n log h)    | Combina los dos                 |

## 17.4 Graham Scan — versión greedy

```text
1. Encontrar el punto más bajo (pivote). Llámalo p₀.
2. Ordenar los demás puntos por ángulo polar respecto a p₀.
3. Recorrer en orden. Agregar al hull si NO genera "giro a la derecha".
   Si genera giro a la derecha, descartar el último punto.
```

### Visualización

```text
       7
        \
         6 ─ 5
          \  │
       8   \ │
            \│
             4 ─ 3
              \
               2 ─ 1
                  \
                   0 (pivote, el más bajo)

Puntos ordenados por ángulo desde 0:
   0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Hull construido:
   {0, 1}
   {0, 1, 2}
   {0, 1, 2, 3}
   {0, 1, 2, 3, 4}
   {0, 1, 2, 3, 4, 5}
   {0, 1, 2, 3, 4, 5, 6}
   {0, 1, 2, 3, 4, 5, 6, 7}
   {0, 1, 2, 3, 4, 5, 6, 7, 8}   ← hull final
```

## 17.5 Implementación en C

```c
typedef struct {
    double x, y;
} Punto;

int orientation(Punto a, Punto b, Punto c) {
    double val = (b.y - a.y) * (c.x - b.x) -
                 (b.x - a.x) * (c.y - b.y);
    if (val == 0) return 0;        // colineales
    return (val > 0) ? 1 : 2;      // CCW o CW
}

void grahamScan(Punto puntos[], int n) {
    // 1. Encontrar el punto más bajo (y mínimo)
    int minIdx = 0;
    for (int i = 1; i < n; i++)
        if (puntos[i].y < puntos[minIdx].y ||
            (puntos[i].y == puntos[minIdx].y &&
             puntos[i].x < puntos[minIdx].x))
            minIdx = i;
    swap(&puntos[0], &puntos[minIdx]);

    // 2. Ordenar por ángulo polar (CCW) desde puntos[0]
    qsort(&puntos[1], n - 1, sizeof(Punto), cmpPolar);

    // 3. Construir el hull
    Punto pila[n];
    int top = 0;
    pila[top++] = puntos[0];
    pila[top++] = puntos[1];

    for (int i = 2; i < n; i++) {
        while (top > 1 &&
               orientation(pila[top-2], pila[top-1], puntos[i]) != 1)
            top--;
        pila[top++] = puntos[i];
    }
}
```

## 17.6 Implementación en Python

```python
def orientation(a, b, c):
    val = (b[1]-a[1])*(c[0]-b[0]) - (b[0]-a[0])*(c[1]-b[1])
    if val == 0: return 0
    return 1 if val > 0 else 2   # 1 = CCW, 2 = CW

def graham_scan(puntos):
    n = len(puntos)

    # 1. Punto más bajo
    p0 = min(puntos, key=lambda p: (p[1], p[0]))

    # 2. Ordenar por ángulo polar
    import math
    def angulo(p):
        return math.atan2(p[1] - p0[1], p[0] - p0[0])
    pts = [p0] + sorted([p for p in puntos if p != p0], key=angulo)

    # 3. Construir hull
    pila = []
    for p in pts:
        while len(pila) > 1 and orientation(pila[-2], pila[-1], p) != 1:
            pila.pop()
        pila.append(p)

    return pila
```

## 17.7 ¿Por qué greedy funciona?

```text
En Graham Scan, en cada paso agregas un punto al hull.
Si ese punto causa un giro a la DERECHA (CW), entonces los últimos
puntos del hull NO podían estar en un polígono convexo:
   el segmento final es cóncavo.
Descartarlos y reintentar es seguro: el hull sigue siendo convexo.

Este es esencialmente un greedy CON retrocesos locales, pero los
retrocesos solo afectan los últimos puntos. Al terminar, el hull
es convexo.
```

## 17.8 Complejidad

| Fase               | Tiempo                |
| ------------------ | --------------------- |
| Encontrar p₀       | O(n)                  |
| Ordenar por ángulo | O(n log n)            |
| Construir hull     | O(n) (cada punto entra/sale una vez) |
| **Total**          | **O(n log n)**        |

## 17.9 Closest Pair (mención)

> El **closest pair** también tiene una versión greedy (incremental), pero es **mucho más lenta** que D&C. D&C da O(n log n), greedy solo en casos especiales.

```text
Greedy naive:    O(n²)    (probar todos los pares)
D&C:             O(n log n)  ← opción correcta
```

> **Lección:** no todo problema geométrico admite un buen greedy.

---

# 18. Casos donde Greedy Falla

> **Esta es la sección más importante del documento.** Aquí aprendes cuándo NO usar greedy.

## 18.1 Cambio de monedas no canónico (1, 3, 4)

Ya cubierto en sección 7.5. Greedy falla para N=6: da 3 monedas, óptimo es 2.

```text
N = 6,  C = {1, 3, 4}
   Greedy:  4 + 1 + 1 = 3 monedas
   Óptimo:  3 + 3 = 2 monedas      ← DP necesario
```

## 18.2 Knapsack 0/1

```text
W = 10
Items:
   A: (peso 6, valor 8)    ratio 1.33
   B: (peso 5, valor 5)    ratio 1.00
   C: (peso 5, valor 5)    ratio 1.00

Greedy por ratio: A → valor 8
Óptimo:            B + C → valor 10       ← DP O(nW)
```

## 18.3 Longest Path en un grafo (general)

```text
Problema: encontrar el camino más largo entre dos vértices.

En grafos generales: NP-hard.

Greedy FALLA: cada paso elige la arista más larga, pero puedes
              "encerrarte" sin salida.
```

```text
    a
    │ 3
    b
    │ 1       5      2
    c ───── d ──── e ──── f
                          │ 1
                          g

Longest path a → g:
   a-b-c-d-e-f-g = 3+1+5+2+1 = 12
   NO es greedy. La elección greedy (tomar 5) te lleva por un
   camino que termina en un callejón sin salida.
```

## 18.4 TSP (Traveling Salesman Problem)

```text
Problema: visitar todas las ciudades, volver al inicio, mínimo costo.

Nearest-neighbor greedy:
   Empezar en cualquier ciudad. En cada paso, ir a la más cercana
   no visitada.

Falla: puede generar un tour mucho peor que el óptimo.

   Ejemplo clásico:
       4 ciudades formando un cuadrado con un punto en una esquina.
       NN greedy:  tour largo
       Óptimo:     perímetro del cuadrado
```

### Implementación NN (para mostrar que NO es óptimo)

```python
def tsp_nn(dists, inicio):
    """Vecino más cercano. NO es óptimo."""
    n = len(dists)
    visitadas = {inicio}
    tour = [inicio]
    costo = 0
    actual = inicio

    for _ in range(n - 1):
        siguiente = min(
            (v for v in range(n) if v not in visitadas),
            key=lambda v: dists[actual][v]
        )
        costo += dists[actual][siguiente]
        tour.append(siguiente)
        visitadas.add(siguiente)
        actual = siguiente

    return tour + [inicio], costo
```

| Método                  | Calidad           |
| ----------------------- | ----------------- |
| Vecino más cercano (NN) | Aprox. **O(log n)** peor caso (Christofides-like) |
| Óptimo exacto           | NP-hard (DP O(n² 2ⁿ) con Held-Karp) |
| 2-opt, simulated annealing | Heurísticas locales |

## 18.5 Set Cover

```text
Problema: cubrir todos los elementos con mínimo # de conjuntos.

Greedy FALLA en general (aproximación O(log n), pero no óptimo).

Ejemplo:
   U = {1, 2, 3, 4}
   S1 = {1, 2}
   S2 = {2, 3}
   S3 = {3, 4}
   S4 = {1, 4}

   Greedy elige S1 (cubre 2): {1,2}
              luego S3 (cubre 2 nuevos): {1,2,3,4}
   Total: 2 conjuntos. ¡Pero S4 + S2 también da 2! (Coincide aquí.)
```

## 18.6 Mochila ilimitada con restricciones extra

```text
Si hay restricciones de "objetos incompatibles" o "mínimo # por categoría",
greedy por ratio falla.
```

## 18.7 Tabla resumen de fallos

| Problema                        | Greedy falla por qué               | Alternativa          |
| ------------------------------- | ---------------------------------- | -------------------- |
| Cambio no canónico              | Elección local no es parte del óptimo | DP               |
| Knapsack 0/1                    | Fraccionabilidad de ratio          | DP o Branch & Bound |
| Longest Path                    | Sin optimal substructure           | NP-hard (no greedy)  |
| TSP                             | Mirar local → perder global        | DP exacto / heurística|
| Set Cover                       | Elección local no es global        | Aprox. LP rounding   |
| Mochila con restricciones        | Combinaciones                      | DP / ILP             |

## 18.8 La heurística de verificación

```text
Para saber si tu greedy es correcto, intenta encontrar un CONTRAEJEMPLO:

  1. Inventa instancias pequeñas.
  2. Ejecuta tu greedy a mano.
  3. Ejecuta el óptimo (por fuerza bruta si n es pequeño).
  4. ¿Coinciden?  Si no, tu greedy está MAL.

Si en 10 instancias pequeñas coinciden, es PROBABLE que esté bien,
pero no es PRUEBA. La prueba formal es necesaria.
```

> **Regla de oro:** Si no puedes probar optimalidad, asume que greedy **falla** hasta que se demuestre lo contrario.

---

# 19. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| # | Error                                                       | Consecuencia                                |
| - | ----------------------------------------------------------- | ------------------------------------------- |
| 1 | Asumir que greedy funciona sin **probarlo**                 | Produce soluciones incorrectas silenciosamente |
| 2 | Asumir que el sistema de monedas es canónico sin verificarlo| Cambios subóptimos en producción            |
| 3 | Ordenar por el criterio **incorrecto**                      | El algoritmo puede estar mal formulado      |
| 4 | Confundir **0/1 knapsack** con fraccional                   | Greedy funciona solo en el fraccional       |
| 5 | Usar greedy en TSP y creer que es óptimo                   | Tour mucho peor de lo necesario             |
| 6 | Olvidar el caso de **empates** en la elección greedy        | Puede cambiar el resultado sin querer       |
| 7 | Asumir optimalidad de un greedy en un problema NP-hard      | Imposible en general                        |
| 8 | Implementar MST con grafo que tiene ciclos negativos        | Puede no funcionar correctamente           |
| 9 | No verificar que el heap soporte **DECREASE-KEY**           | Dijkstra/Prim incorrecto o lento            |
| 10| Implementar Dijkstra en grafo con pesos **negativos**       | Resultado incorrecto                        |
| 11| Implementar Kruskal sin **Union-Find** eficiente            | Lento: O(E log E) → O(E²)                  |
| 12| Pensar que Huffman funciona para cualquier fuente de datos   | Requiere conocer frecuencias               |
| 13| Olvidar la propiedad de **independencia** al modelar como matroid | Greedy puede fallar                       |
| 14| Olvidar tratar empates en los códigos de Huffman            | Árboles subóptimos                          |

### ✅ Buenas Prácticas

| # | Práctica                                                        | Razón                                       |
| - | --------------------------------------------------------------- | ------------------------------------------- |
| 1 | **Siempre probar** optimalidad antes de confiar                 | Exchange argument, inducción o matroid      |
| 2 | Construir **casos pequeños** a mano para verificar              | Falsificar la conjetura rápido              |
| 3 | Comparar con **DP/brute force** para `n` pequeño                | Validación experimental                     |
| 4 | Documentar **qué propiedad** garantiza optimalidad             | Mantenibilidad                              |
| 5 | Usar **Union-Find con path compression** en Kruskal             | O(α(n)) en lugar de O(n) por find           |
| 6 | Usar **DECREASE-KEY** explícito en heaps para Dijkstra/Prim     | Performance correcta                        |
| 7 | **Randomizar** tie-breaking para evitar casos degenerados       | Mejor comportamiento esperado               |
| 8 | Medir empíricamente con datos **reales**                        | Las constantes importan                     |
| 9 | Separar la **función de selección** del resto del código        | Legibilidad y testeabilidad                 |
| 10| Cuando hay duda, **DP suele ganar** (a costa de memoria)        | Solución correcta garantizada               |
| 11| Conectar el problema con un **matroid** conocido                | Acceso a teoremas de optimalidad            |
| 12| Verificar el **cut/cycle property** en MST antes de usar greedy | Evita errores sutiles en grafos raros       |

---

# 20. Intuición de Ingeniería

## 20.1 El árbol de decisión para "qué estrategia usar"

```text
                         ¿Qué tipo de problema es?
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        ▼                         ▼                         ▼
   Optimización              Búsqueda             Multi-objetivo
        │                      exhaustiva              │
        │                                              ▼
        │                                        Pareto / heurísticas
        ▼
   ¿Cuál es la estructura?
        │
   ┌────┼──────────────────┐
   │    │                  │
   ▼    ▼                  ▼
  D&C  DP              GREEDY
   │    │                  │
   │    │                  │
   │    │   ¿La elección local
   │    │    es siempre segura?
   │    │         │
   │    │      Sí ─┴─ No
   │    │      │     │
   │    │      ▼     ▼
   │    │   GREEDY   DP (o backtracking)
   ▼    ▼
  Combinar   Tabular
   barato     subproblemas
```

## 20.2 Reglas mnemotécnicas del greedy

| Regla                                          | Significado                                        |
| ---------------------------------------------- | -------------------------------------------------- |
| **"Local óptimo, global óptimo"**             | Si no puedes probarlo, no es greedy               |
| **"Matroid = greedy siempre"**                 | Si puedes modelar como matroid, el greedy funciona |
| **"Cut/cycle property"**                      | En MST y similares, verifica estas propiedades    |
| **"Empatar es trampa"**                        | Empates ocultan optimalidad (Huffman, MST)        |
| **"Cuando dudes, DP"**                        | Más lento pero correcto                           |
| **"Counterexample first"**                    | Intenta romper tu greedy antes de creer en él      |
| **"Sort by importance"**                      | Casi todo greedy empieza con un orden             |

## 20.3 Tabla de decisión: problema → algoritmo

| Si tu problema es...                                  | Probablemente usa...              |
| ----------------------------------------------------- | --------------------------------- |
| Cambio de monedas (canónico)                          | **Greedy O(k)**                    |
| Cambio de monedas (general)                          | **DP O(N·k)**                      |
| Máximo # actividades sin solapamiento                | **Greedy por menor fin O(n log n)** |
| Máximo peso de actividades                            | **DP O(n log n)**                  |
| Mochila fraccionaria                                  | **Greedy por ratio O(n log n)**    |
| Mochila 0/1                                           | **DP O(nW) o Branch & Bound**      |
| Comprimir archivo                                     | **Huffman O(n log n)**             |
| Camino más corto (pesos ≥ 0)                         | **Dijkstra O(E log V)**            |
| Camino más corto (pesos negativos)                   | **Bellman-Ford O(VE)**             |
| MST en grafo disperso                                 | **Kruskal O(E log E)**             |
| MST en grafo denso                                    | **Prim eager O(E + V log V)**      |
| MST paralelo                                          | **Borůvka**                       |
| Maximizar ganancia con deadlines                      | **Greedy + Union-Find O(n log n)**|
| Convex Hull                                           | **Graham Scan O(n log n)**         |

## 20.4 Conexión con el resto del repositorio

| Tema del repositorio                | Conexión con Greedy                                |
| ----------------------------------- | -------------------------------------------------- |
| **Algorithms.md (sección 13)**      | Resumen de greedy (versión corta)                  |
| **Divide&Conquer.md**               | MST como matroid; contraste D&C vs greedy          |
| **Sorting.md**                      | Heap (clave en Huffman, Prim, Dijkstra)            |
| **Hashing.md**                      | Algunas heurísticas greedy para resize             |
| **Recursion/**                      | Greedy es iterativo (no recursivo en general)      |
| **Dynamic Programming/** (futuro)   | DP es el "siguiente paso" cuando greedy falla     |

## 20.5 El principio unificador

> **Greedy es el patrón más simple y rápido de los tres grandes paradigmas**
> (junto con D&C y DP).
>
> Cuando funciona, es **muy difícil de superar**: óptimo, simple, O(n log n) o mejor.
> Cuando falla, es **peligroso**: produce respuestas "plausibles pero incorrectas".
>
> La habilidad clave no es implementar greedy.
> Es **reconocer cuándo funciona y demostrarlo**.

```text
   D&C:    "divide el problema en pedazos independientes y combínalos"
   DP:     "resuelve cada subproblema UNA vez y reutilízalo"
   Greedy: "toma la mejor decisión local y NO mires atrás"

   Cada uno es la respuesta correcta en su contexto.
   Saber cuál usar es la esencia del diseño de algoritmos.
```

## 20.6 Resumen final de los algoritmos cubiertos

| Algoritmo                 | Estrategia greedy                       | Optimalidad                        | Complejidad       |
| ------------------------- | --------------------------------------- | ---------------------------------- | ----------------- |
| **Cambio canónico**       | Moneda más grande                       | ✅ Solo en sistemas canónicos       | O(k)              |
| **Activity Selection**    | Por menor tiempo de fin                 | ✅ (CLRS 16.1)                     | O(n log n)        |
| **Fractional Knapsack**   | Por ratio v/w                           | ✅ (fraccionario)                   | O(n log n)        |
| **Huffman Coding**        | Combinar menos frecuentes               | ✅ (CLRS 16.3)                     | O(n log n)        |
| **Dijkstra**              | Vértice con menor distancia             | ✅ (pesos no negativos)            | O(E log V)        |
| **Kruskal**               | Arista de menor peso (Union-Find)       | ✅ (CLRS 23.2)                     | O(E log E)        |
| **Prim (lazy)**           | Arista más barata saliente              | ✅ (CLRS 23.2)                     | O(E log E)        |
| **Prim (eager)**          | Vértice con menor key                   | ✅                                  | O(E + V log V)    |
| **Borůvka**               | Mínima saliente de cada componente      | ✅ (1926)                           | O(E log V)        |
| **Job Sequencing**        | Mayor ganancia, último slot libre       | ✅                                  | O(n log n)        |
| **Graham Scan**           | Por ángulo polar + retroceso local      | ✅                                  | O(n log n)        |

---

## Referencias

- **CLRS** — Cormen, Leiserson, Rivest, Stein. *Introduction to Algorithms* (4ª ed.).
  - **Capítulo 16**: *Greedy Algorithms* (Activity Selection, Huffman, Matroid theory)
  - **Capítulo 16.4**: *Matroid theory* (sección avanzada)
  - **Capítulo 23**: *Minimum Spanning Trees* (Kruskal, Prim, Borůvka)
  - **Capítulo 24**: *Single-Source Shortest Paths* (Dijkstra, Bellman-Ford)
- **Algorithms.md** en este repositorio — sección 13 (resumen de greedy).
- **Divide&Conquer.md** en este repositorio — MST como matroid, contraste D&C vs greedy.
- **Sorting.md** en este repositorio — Heap (estructura fundamental en Prim, Dijkstra, Huffman).
- **Kleinberg, Tardos** — *Algorithm Design*, Capítulo 4 (Greedy).
- **Borůvka, O.** (1926) — *O jistém problému minimálním* (primer algoritmo MST).
