# Backtracking — Búsqueda con Retroceso

> **Idea central:** Explorar **todas** las posibles soluciones de un problema **incrementando la solución parcial paso a paso**,
> pero **retrocediendo (backtrack)** en cuanto detectas que el camino elegido **no puede llevar a una solución válida**.
>
> Es la versión inteligente de la fuerza bruta: no pruebas todo, **podas** lo que no vale la pena.
>
> Conecta directamente con BFS/DFS de CLRS Sección 22.1 — un backtracking es esencialmente un **DFS con poda**.

---

## Tabla de Contenidos

1. [¿Qué es Backtracking?](#1-qué-es-backtracking)
2. [Backtracking vs Brute Force vs D&C vs DP vs Greedy](#2-backtracking-vs-brute-force-vs-dc-vs-dp-vs-greedy)
3. [Anatomía de un Algoritmo de Backtracking](#3-anatomía-de-un-algoritmo-de-backtracking)
4. [El Template General](#4-el-template-general)
5. [Visualización: El Árbol de Decisión](#5-visualización-el-árbol-de-decisión)
6. [Problema 1: Generate All Binary Strings](#6-problema-1-generate-all-binary-strings)
7. [Problema 2: Generate All Permutations](#7-problema-2-generate-all-permutations)
8. [Problema 3: N-Queens](#8-problema-3-n-queens)
9. [Problema 4: Sudoku Solver](#9-problema-4-sudoku-solver)
10. [Problema 5: Subset Sum](#10-problema-5-subset-sum)
11. [Problema 6: Combination Sum](#11-problema-6-combination-sum)
12. [Problema 7: Word Search (en grid)](#12-problema-7-word-search-en-grid)
13. [Problema 8: Rat in a Maze](#13-problema-8-rat-in-a-maze)
14. [Problema 9: Hamiltonian Path/Cycle](#14-problema-9-hamiltonian-pathcycle)
15. [Problema 10: M-Coloring de Grafos](#15-problema-10-m-coloring-de-grafos)
16. [Problema 11: Knight's Tour](#16-problema-11-knights-tour)
17. [Poda (Pruning) — El Verdadero Arte](#17-poda-pruning--el-verdadero-arte)
18. [Branch and Bound (Avanzado)](#18-branch-and-bound-avanzado)
19. [Iterative Deepening](#19-iterative-deepening)
20. [Complejidad de Backtracking](#20-complejidad-de-backtracking)
21. [Errores Comunes y Buenas Prácticas](#21-errores-comunes-y-buenas-prácticas)
22. [Intuición de Ingeniería](#22-intuición-de-ingeniería)

---

# 1. ¿Qué es Backtracking?

## 1.1 Definición

**Backtracking** es una estrategia algorítmica para resolver problemas **combinatorios** construyendo la solución **incrementalmente**, una pieza a la vez, y **eliminando** (pruning) aquellas soluciones parciales que **no pueden completarse** hasta el final.

```text
Idea:

    1. Empiezas con una solución PARCIAL (vacía).
    2. En cada paso, INTENTAS una elección.
    3. Si la elección lleva a una contradicción → DESHACES (backtrack).
    4. Si la elección lleva a una solución completa → GUARDAS.
    5. Pruebas la siguiente elección.
```

> Es como caminar por un laberinto con un hilo: avanzas, y cuando un callejón no tiene salida, **regresas por donde viniste** y pruebas otro camino.

## 1.2 Las tres preguntas que responde Backtracking

| Pregunta                                          | Cómo la responde               |
| ------------------------------------------------- | ------------------------------ |
| ¿Generar **todas** las soluciones posibles?       | Sí — recorre el árbol entero    |
| ¿Encontrar **una** solución válida?               | Sí — termina al encontrar la primera |
| ¿Encontrar la **mejor** (óptima) solución?        | Sí — explora todo o usa Branch & Bound |

## 1.3 Analogías del mundo real

### Laberinto

```text
                    ┌───┐
                    │ E │  ← entrada
                    └─┬─┘
              ┌───────┴───────┐
            ┌─┴─┐           ┌─┴─┐
            │ X │  ← muerto │   │  ← camino vivo
            └───┘           └─┬─┘
                              │
                          ┌───┴───┐
                          │   S   │  ← salida
                          └───────┘

Si entras por X → callejón sin salida → REGRESAS al cruce (BACKTRACK).
```

### Cerradura de combinación

```text
Una cerradura con 3 discos de 0-9.
    Fuerza bruta:  10 × 10 × 10 = 1000 combinaciones.
    Backtracking:  usas realimentación ("click") para podar.
```

### Resolver un Sudoku

```text
1. Ubicas un número en una celda vacía.
2. Verificas que no rompa las reglas (fila, columna, bloque).
3. Si las rompe → BORRAS y pruebas otro número (BACKTRACK).
4. Si completas el tablero → ¡SOLUCIÓN!
```

### Armar un rompecabezas pieza por pieza

```text
    Pongo una pieza.
    ¿Encaja con las vecinas?
        Sí → sigo poniendo piezas.
        No  → la QUITO y pruebo otra (BACKTRACK).
```

## 1.4 ¿Por qué Backtracking y no fuerza bruta pura?

| Estrategia                | Explora    | Cuándo gana                                |
| ------------------------- | ---------- | ------------------------------------------ |
| **Brute Force puro**      | Todo       | Solo si el espacio es pequeño (`n ≤ 20`)   |
| **Backtracking**          | Todo **podado** | Cuando restricciones eliminan muchas ramas |
| **DP / Greedy**           | Una rama   | Cuando el problema tiene estructura que permite no explorar todo |

> **Regla de oro:** si la **fuerza bruta es viable** pero **lenta**, prueba **backtracking**; si backtracking sigue lento, busca **DP**.

## 1.5 Ejemplos famosos (preview)

| Problema                      | Espacio total | Espacio podado    |
| ----------------------------- | ------------- | ----------------- |
| **Permutaciones de `n`**      | `n!`          | `n!` (sin poda)   |
| **Combinaciones `C(n, k)`**   | `2ⁿ`          | mucho menor       |
| **N-Queens (`n = 8`)**        | `64⁸ ≈ 2.8·10¹⁴` | ~ 92 soluciones |
| **Sudoku (`9 × 9`)**          | `9⁸¹` !!!     | miles de millones |
| **Subset Sum**                | `2ⁿ`          | depende de target |

---

# 2. Backtracking vs Brute Force vs D&C vs DP vs Greedy

## 2.1 Tabla comparativa

| Característica        | Brute Force           | Backtracking        | D&C                       | DP                          | Greedy               |
| --------------------- | --------------------- | ------------------- | ------------------------- | --------------------------- | -------------------- |
| **Explora**           | Todo                  | Todo **podado**     | Subproblemas              | Subproblemas                | Una elección local   |
| **Estructura**        | Bucles anidados       | DFS con poda        | Recursión con divide/combine | Tabla + recurrencia       | Selección iterativa  |
| **Garantía óptimo**   | Sí (si examina todo)  | Sí (si poda no descarta óptimos) | Sí                | Sí                          | **No siempre**        |
| **Complejidad típica**| Exponencial           | Exponencial (menor) | Polinómica                | Polinómica                  | Polinómica           |
| **Memoria**           | O(1)                  | O(profundidad)      | O(profundidad)            | O(estado)                   | O(1) o O(n)          |
| **Cuándo gana**       | `n` pequeño           | Muchas restricciones eliminan ramas | Subproblemas independientes | Subproblemas solapados | Greedy-choice property |

## 2.2 Ejemplos canónicos de cada uno

```text
Brute Force:   Probar todas las contraseñas de 4 dígitos   → 10,000 intentos
Backtracking:  N-Queens, Sudoku                            → poda por restricciones
D&C:           Merge Sort, FFT                              → dividir y combinar
DP:            Fibonacci, Knapsack 0/1                      → guardar subproblemas
Greedy:        Cambio de monedas (canónico), Dijkstra       → elegir lo mejor local
```

## 2.3 ¿Cuándo es Backtracking la respuesta correcta?

> **Backtracking gana cuando:**
> 1. El problema pide **todas las soluciones** (o el óptimo entre muchas).
> 2. Las restricciones eliminan **muchas** ramas del árbol.
> 3. La estructura es **combinatoria** (permutaciones, combinaciones, asignaciones).
> 4. No hay (o no conviene) subestructura óptima para DP.

> **Backtracking pierde cuando:**
> 1. Hay muchas soluciones y solo quieres una (DP o greedy suele bastar).
> 2. Las restricciones son débiles (casi no podan).
> 3. `n` es grande (> 25-30) sin buena poda.

## 2.4 La "zona de backtracking" en el espectro

```text
n muy pequeño (≤ 12-15):
    Brute Force    OK, simple

n pequeño-mediano (15-30):
    Backtracking   ← ★ aquí ★

n mediano-grande (30-50):
    Backtracking con PODA fuerte
    o Programación Dinámica
    o Branch & Bound

n grande (> 50):
    Greedy (si funciona)
    o Aproximaciones (heurísticas, algoritmos randomized)
```

> **CLRS Sección 22.1 (BFS/DFS):** *“DFS lends itself nicely to backtracking algorithms because it explores a tree by going as deep as possible before backtracking.”*

---

# 3. Anatomía de un Algoritmo de Backtracking

## 3.1 Los tres componentes canónicos

Todo problema de backtracking se puede modelar con tres elementos:

```text
┌─────────────────────────────────────────────────────┐
│  CHOICE   (Elección)                                │
│  ¿Qué opciones tengo en este paso?                  │
│  Ej: en N-Queens, las columnas disponibles.         │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  CONSTRAINTS  (Restricciones)                       │
│  ¿Cuáles de esas opciones son VÁLIDAS ahora?        │
│  Ej: ninguna reina en la misma fila/col/diagonal.   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  GOAL  (Meta)                                       │
│  ¿Cuándo terminé? ¿Qué guardo?                      │
│  Ej: coloqué N reinas sin violar reglas.             │
└─────────────────────────────────────────────────────┘
```

## 3.2 Los tres pasos en cada llamada recursiva

```text
    ┌─────────────────────────────────────────────┐
    │ 1. CHOOSE (Elegir)                          │
    │    Hacer una elección: x[i] = algo.         │
    └─────────────────┬───────────────────────────┘
                      ↓
    ┌─────────────────────────────────────────────┐
    │ 2. EXPLORE (Explorar)                       │
    │    Llamar recursivamente con la nueva       │
    │    elección hecha.                          │
    └─────────────────┬───────────────────────────┘
                      ↓
    ┌─────────────────────────────────────────────┐
    │ 3. UNCHOOSE (Deshacer)  ← BACKTRACK         │
    │    Restaurar el estado previo a la          │
    │    elección (deshacer para probar otra).    │
    └─────────────────────────────────────────────┘
```

> **El paso UNCHOOSE es lo que distingue a backtracking.** Sin él, sería solo DFS; con él, puedes explorar **todas** las ramas sin ensuciar el estado.

## 3.3 Estado: lo que rastreamos

El **estado** es la información que describe la "solución parcial" actual.

| Problema               | Estado                                       |
| ---------------------- | -------------------------------------------- |
| **Permutaciones**      | El prefijo construido: `perm[0..k-1]`        |
| **N-Queens**           | Qué columna se eligió en cada fila: `col[0..k-1]` |
| **Sudoku**             | El tablero parcialmente lleno                |
| **Subset Sum**         | El subconjunto parcial y su suma acumulada   |
| **Word Search**        | Posición actual + celdas visitadas           |
| **M-Coloring**         | Color asignado a cada vértice hasta ahora    |

## 3.4 Poda: el corazón de Backtracking

```text
SIN poda:
    Exploras TODO el árbol → 2ⁿ, n!, exponencial crudo.
    Equivale a fuerza bruta con recursión.

CON poda:
    En cada paso verificas restricciones.
    Si NO se cumplen → NO exploras esa rama.
    A veces reduces el árbol de 2ⁿ a n². ⚡
```

> **Ejemplo dramático:** Sudoku tiene `9⁸¹ ≈ 1.9·10⁷⁷` tableros posibles sin restricciones. Con las reglas de Sudoku (fila, columna, bloque 3×3), el espacio efectivo es del orden de **miles de millones** — manejable.

---

# 4. El Template General

## 4.1 Pseudocódigo canónico

```text
función BACKTRACK(estado, opciones, resultado):
    si estado es meta:
        agregar estado a resultado
        return                  # (o seguir si quieres TODAS)

    para cada elección en opciones:
        si elección es VÁLIDA según restricciones(estado):
            HACER elección              # CHOOSE
            BACKTRACK(nuevo_estado, nuevas_opciones, resultado)
            DESHACER elección          # UNCHOOSE
```

## 4.2 Implementación genérica en C

```c
typedef struct {
    // define tu estado aquí (solución parcial)
    // por ejemplo: int data[MAX];
    //             int size;
} Estado;

int esMeta(Estado *e);
int esValido(Estado *e, int eleccion);

void backtrack(Estado *e) {
    if (esMeta(e)) {
        guardar(e);
        return;
    }

    int n_opciones = obtenerOpciones(e);
    for (int i = 0; i < n_opciones; i++) {
        if (esValido(e, i)) {
            elegir(e, i);           // CHOOSE
            backtrack(e);           // EXPLORE
            des elegir(e, i);       // UNCHOOSE ← backtrack real
        }
    }
}
```

## 4.3 Implementación genérica en Python

```python
def backtrack(estado, opciones):
    if es_meta(estado):
        resultados.append(estado.copy())   # copiar es CLAVE
        return

    for eleccion in opciones:
        if es_valido(estado, eleccion):
            estado.append(eleccion)        # CHOOSE
            backtrack(estado, nuevas_opciones(estado))
            estado.pop()                   # UNCHOOSE ← backtrack
```

## 4.4 El "deshacer" — por qué es esencial

```text
ERROR COMÚN: olvidar el "deshacer".

    Estado: [1, 2]
    Elijo 3 → Estado: [1, 2, 3]   exploro
    Termino esa rama.
    Vuelvo al for y elijo 4 → Estado: [1, 2, 3, 4]   ← ¡ERROR! Debería ser [1, 2, 4]

CORRECTO: el "deshacer" limpia el estado antes de probar la siguiente opción.

    Estado: [1, 2]
    Elijo 3 → Estado: [1, 2, 3]   exploro
    DESHAGO 3 → Estado: [1, 2]   ✅
    Elijo 4 → Estado: [1, 2, 4]   ✅
```

## 4.5 Estado mutable vs inmutable

| Enfoque            | C / C++                          | Python                                |
| ------------------ | -------------------------------- | ------------------------------------- |
| **Mutable**        | Modificar + deshacer explícito   | `lista.append/pop`                    |
| **Inmutable**      | Crear copia, pasar a recursión   | `tupla`, `frozenset`                  |

> **Tip:** En Python, pasar una **copia** del estado es más seguro pero menos eficiente. Usar `pop()` es más rápido pero requiere cuidado.

## 4.6 Backtracking iterativo (con stack explícito)

```python
def backtrack_iterativo(estado_inicial):
    stack = [(estado_inicial, 0)]   # (estado, índice de opción)

    while stack:
        estado, idx = stack[-1]

        if es_meta(estado):
            guardar(estado)
            stack.pop()
            continue

        opciones = obtener_opciones(estado)

        if idx >= len(opciones):
            stack.pop()             # ← backtrack
            continue

        # Actualizar el índice para la próxima iteración
        stack[-1] = (estado, idx + 1)

        eleccion = opciones[idx]
        if es_valido(estado, eleccion):
            nuevo_estado = estado + [eleccion]
            stack.append((nuevo_estado, 0))
```

> El iterativo **evita stack overflow** para árboles muy profundos (N-Queens con N grande, Knight's Tour).

---

# 5. Visualización: El Árbol de Decisión

## 5.1 Idea

Todo algoritmo de backtracking **recorre un árbol** donde:

```text
- Cada NODO es una solución PARCIAL.
- Cada ARISTA es una elección (agregar/quitar algo).
- Cada HOJA es una solución COMPLETA o una rama muerta.
- La RAÍZ es el estado vacío.
```

## 5.2 Ejemplo: generar todos los strings binarios de longitud 3

```text
                                    []                    ← raíz
                              /           \
                          [0]                [1]
                        /     \            /     \
                    [0,0]     [0,1]    [1,0]     [1,1]
                    /   \     /   \    /   \     /   \
                [0,0,0][0,0,1][0,1,0][0,1,1][1,0,0][1,0,1][1,1,0][1,1,1]
                  ✓      ✓     ✓      ✓      ✓      ✓      ✓      ✓
                                                    ↑
                                                  hojas = soluciones completas (8)
```

## 5.3 Ejemplo: permutaciones de [1, 2, 3]

```text
                                    []
                          /         |         \
                       [1]        [2]        [3]
                      /   \      /   \      /   \
                  [1,2] [1,3] [2,1] [2,3] [3,1] [3,2]
                   /     /     /     /     /     /
              [1,2,3][1,3,2][2,1,3][2,3,1][3,1,2][3,2,1]
                ✓     ✓     ✓     ✓     ✓     ✓
                                          ↑
                                  3! = 6 hojas
```

## 5.4 Poda visual: N-Queens (N = 4)

```text
Colocar reina en fila 0, columna 0:

        Fila 0:  Q . . .            Estado: Q en (0,0)

        Fila 1: opciones son {1, 2, 3}, pero columna 0 atacada y diagonales...
                  [X] columnas atacadas por (0,0)
                  [D] diagonales atacadas por (0,0)

        Fila 1:  . . Q .            Elegimos columna 2 (única segura)
                  Estado: Q en (0,0), (1,2)

        Fila 2: . . . .            Ninguna columna segura
                  [X][X][D]      ← toda atacada
                  [D][X][X]
                  BACKTRACK a fila 1.

        Fila 1: probamos otra columna... tampoco funciona.
        BACKTRACK a fila 0: probar otra columna inicial.

        Fila 0:  . Q . .            Q en (0,1)

        Fila 1:  . . . Q            Q en (1,3) (única segura)

        Fila 2:  Q . . .            Q en (2,0)

        Fila 3:  . . Q .            Q en (3,2) ✓ SOLUCIÓN

Resultado:
        Q . . .
        . . . Q
        Q . . .
        . . Q .
```

## 5.5 Por qué backtracking puede ser exponencial

```text
El árbol de backtracking tiene, en el PEOR CASO:
    - altura = n (longitud de la solución)
    - branching factor = n (número de opciones por nivel)
    - nodos totales = nⁿ

Poda típica:
    - Restricciones eliminan 50-99% de las ramas.
    - Sin poda, vuelve a ser fuerza bruta.

Effective branching factor = branching factor · (1 - tasa_de_poda)
    Si b = 5, poda = 80%  →  b_efectivo = 1  →  O(n)  (milagro)
    Si b = 5, poda = 0%   →  b_efectivo = 5  →  O(5ⁿ)  (desastre)
```

> **La regla empírica:** la poda convierte backtracking de "fuerza bruta lenta" a "fuerza bruta a veces viable". La calidad de la poda **es** la calidad del algoritmo.

---

# 6. Problema 1: Generate All Binary Strings

## 6.1 El problema

Generar **todas** las cadenas binarias de longitud `n`.

```text
Entrada:  n = 3
Salida:   000, 001, 010, 011, 100, 101, 110, 111   (8 cadenas)
```

## 6.2 Idea naïve (iterativa)

```c
for (int i = 0; i < (1 << n); i++) {
    // convertir i a binario de n bits
    for (int j = n - 1; j >= 0; j--)
        printf("%d", (i >> j) & 1);
    printf("\n");
}
```

Funciona pero no generaliza (¿qué si quiero strings sobre `{0,1,2,3}`?).

## 6.3 Insight backtracking

> En cada posición tengo **2 opciones**: poner `0` o poner `1`. Recorrer el árbol de profundidad `n`.

## 6.4 Estado

```text
Estado: el prefijo construido hasta ahora.
       largo = profundidad actual.
       Cuando largo == n → solución completa.
```

## 6.5 Código en C

```c
void generarBinarios(char str[], int pos, int n) {
    if (pos == n) {
        str[pos] = '\0';
        printf("%s\n", str);
        return;
    }

    for (char c = '0'; c <= '1'; c++) {
        str[pos] = c;            // CHOOSE
        generarBinarios(str, pos + 1, n);  // EXPLORE
        // No hay UNCHOOSE explícito porque sobrescribimos str[pos]
    }
}
```

## 6.6 Código en Python

```python
def generar_binarios(n):
    resultado = []
    def backtrack(prefijo):
        if len(prefijo) == n:
            resultado.append(prefijo)
            return
        for c in ['0', '1']:
            backtrack(prefijo + c)
    backtrack('')
    return resultado

print(generar_binarios(3))
# ['', '0', '00', '000', '001', '01', '010', '011', '1', '10', '100', '101', '11', '110', '111']
```

## 6.7 Trace para `n = 3`

```text
Llamada                   Estado              ¿Meta?     Acción
─────────────────────────────────────────────────────────────────
backtrack('')             []                  No         probar '0'
backtrack('0')            [0]                 No         probar '0'
backtrack('00')           [0,0]               No         probar '0'
backtrack('000')          [0,0,0]             SÍ         guardar
backtrack('001')          [0,0,1]             SÍ         guardar
                          [0,0]               -          pop → [0]
backtrack('01')           [0,1]               No         probar '0'
backtrack('010')          [0,1,0]             SÍ         guardar
backtrack('011')          [0,1,1]             SÍ         guardar
                          [0,1]               -          pop → [0]
                          [0]                 -          pop → []
backtrack('1')            [1]                 ... (análogo)
... etc

Total: 8 strings generados.
```

## 6.8 Análisis

| Recurso        | Costo                     |
| -------------- | ------------------------- |
| **Tiempo**     | `Θ(2ⁿ · n)`               |
| **Espacio**    | `O(n)` (stack + string)   |
| **# llamadas** | `2ⁿ⁺¹ - 1`                |

## 6.9 Variaciones

| Variación                  | Cambio                                |
| -------------------------- | ------------------------------------- |
| Strings sobre `{0,1,2,...,k-1}` | Cambiar el rango del bucle       |
| Solo strings con misma cantidad de 0s y 1s | Podar si `|0s - 1s| > restantes` |
| Strings sin "000" como substring | Podar si las últimas 3 son '0' |

---

# 7. Problema 2: Generate All Permutations

## 7.1 El problema

Dado un conjunto de `n` elementos **distintos**, generar **todas** sus permutaciones.

```text
Entrada:  [1, 2, 3]
Salida:   [1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1]   (6 = 3!)
```

## 7.2 Idea naïve

```c
// generar todas las permutaciones con bucles anidados:
// solo funciona para n fijo
```

No generaliza. Backtracking es la solución natural.

## 7.3 Insight backtracking

> En cada posición coloco un elemento **aún no usado**. Rastreo cuáles he usado.

## 7.4 Estado

```text
Estado:
    perm[0..k-1]    ← permutación parcial
    usado[i]        ← ya está en perm?
```

## 7.5 Código en C

```c
void permutar(int arr[], int n, int nivel, int perm[], int usado[]) {
    if (nivel == n) {
        for (int i = 0; i < n; i++) printf("%d ", perm[i]);
        printf("\n");
        return;
    }

    for (int i = 0; i < n; i++) {
        if (!usado[i]) {
            perm[nivel] = arr[i];         // CHOOSE
            usado[i] = 1;
            permutar(arr, n, nivel + 1, perm, usado);  // EXPLORE
            usado[i] = 0;                 // UNCHOOSE ← backtrack
        }
    }
}
```

## 7.6 Código en Python

```python
def permutar(nums):
    resultado = []

    def backtrack(perm, usado):
        if len(perm) == len(nums):
            resultado.append(perm.copy())
            return

        for i in range(len(nums)):
            if not usado[i]:
                perm.append(nums[i])      # CHOOSE
                usado.add(i)
                backtrack(perm, usado)    # EXPLORE
                perm.pop()                # UNCHOOSE
                usado.remove(i)

    backtrack([], set())
    return resultado

print(permutar([1, 2, 3]))
# [[1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1]]
```

## 7.7 Versión con swap (in-place, más rápida)

```python
def permutar_swap(nums):
    resultado = []

    def backtrack(inicio):
        if inicio == len(nums):
            resultado.append(nums.copy())
            return

        for i in range(inicio, len(nums)):
            nums[inicio], nums[i] = nums[i], nums[inicio]   # CHOOSE
            backtrack(inicio + 1)                          # EXPLORE
            nums[inicio], nums[i] = nums[i], nums[inicio]   # UNCHOOSE

    backtrack(0)
    return resultado
```

## 7.8 Trace para `[1, 2, 3]`

```text
backtrack([], {})

├── elijo 1: backtrack([1], {1})
│   ├── elijo 2: backtrack([1,2], {1,2}) → elijo 3 → [1,2,3]  ✓
│   └── elijo 3: backtrack([1,3], {1,3}) → elijo 2 → [1,3,2]  ✓
├── elijo 2: backtrack([2], {2})
│   ├── elijo 1: backtrack([2,1], {2,1}) → elijo 3 → [2,1,3]  ✓
│   └── elijo 3: backtrack([2,3], {2,3}) → elijo 1 → [2,3,1]  ✓
└── elijo 3: backtrack([3], {3})
    ├── elijo 1: backtrack([3,1], {3,1}) → elijo 2 → [3,1,2]  ✓
    └── elijo 2: backtrack([3,2], {3,2}) → elijo 1 → [3,2,1]  ✓

Total: 6 permutaciones (3!).
```

## 7.9 Análisis

| Recurso        | Costo                            |
| -------------- | -------------------------------- |
| **Tiempo**     | `Θ(n! · n)`                     |
| **Espacio**    | `O(n)` (stack + arreglo usado)   |
| **# llamadas** | `Σᵢ₌₀ⁿ n! / i! ≈ n! · e`         |

## 7.10 Variaciones

| Variación                          | Cambio                                  |
| ---------------------------------- | --------------------------------------- |
| **Permutaciones con repetición**   | Permitir que `usado[i]` se re-use si `nums[i] == nums[i-1]` y no se usó `nums[i-1]` |
| **Permutaciones de tamaño `k`**    | Detenerse cuando `|perm| == k`          |
| **Siguiente permutación** (lex)    | Algoritmo de Narayana Pandita, O(n)     |

---

# 8. Problema 3: N-Queens

## 8.1 El problema

Colocar `N` reinas en un tablero de ajedrez `N × N` de modo que **ninguna** ataque a otra.

```text
Reglas:
    - Una reina ataca toda su FILA, COLUMNA y DIAGONALES.
    - En una solución válida, no hay dos reinas en la misma fila, columna, o diagonal.

Entrada:  N = 4
Salida:   2 soluciones:
              Q . . .      . Q . .
              . . Q .      . . . Q
              Q . . .      . . Q .
              . . Q .      Q . . .
              (inválido)   (válida ✓)
```

## 8.2 Por qué fuerza bruta falla

```text
Sin restricciones:
    64 casillas para N reinas sin superposición
    ≈ 64! / (64 - N)! / N!

Para N = 8:
    64! / 56! / 8! ≈ 4.4 × 10⁹    (4 mil millones)
    Con colisiones y diagonal check: mucho peor.

Soluciones reales para N = 8: solo 92.
```

## 8.3 Insight backtracking

> 1. **Una reina por fila** (restricción implícita obvia).
> 2. En cada fila, probar columnas. Si una columna está atacada → siguiente.
> 3. Backtrack cuando ninguna columna funcione.

## 8.4 Estado

```text
Estado:
    col[i]  = columna de la reina en la fila i  (i = 0..nivel-1)
    diag1[i] = marcado si la diagonal "\" en la fila i está ocupada
    diag2[i] = marcado si la diagonal "/"  en la fila i está ocupada

Alternativa más simple: tres arreglos booleanos:
    cols[j]          = columna j ocupada?
    diag_principal[k] = diagonal (i + j = k) ocupada?
    diag_secundaria[k] = diagonal (i - j + n - 1 = k) ocupada?
```

## 8.5 Código en C

```c
#include <stdio.h>

#define MAX 20

int N;
int cols[MAX];
int diag1[2 * MAX];
int diag2[2 * MAX];
int soluciones = 0;

void imprimirTablero() {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++)
            printf("%s ", (cols[i] == j) ? "Q" : ".");
        printf("\n");
    }
    printf("\n");
}

int esSeguro(int fila, int col) {
    return !cols[col] && !diag1[fila + col] && !diag2[fila - col + N - 1];
}

void resolver(int fila) {
    if (fila == N) {
        soluciones++;
        // imprimirTablero();   // descomentar para ver
        return;
    }

    for (int col = 0; col < N; col++) {
        if (esSeguro(fila, col)) {
            cols[col] = 1;
            diag1[fila + col] = 1;
            diag2[fila - col + N - 1] = 1;

            resolver(fila + 1);

            cols[col] = 0;
            diag1[fila + col] = 0;
            diag2[fila - col + N - 1] = 0;
        }
    }
}

int main() {
    printf("Ingresa N: ");
    scanf("%d", &N);
    resolver(0);
    printf("Soluciones para N = %d: %d\n", N, soluciones);
    return 0;
}
```

## 8.6 Código en Python

```python
def resolver_n_queens(n):
    soluciones = []

    def backtrack(fila, cols, diag1, diag2, tablero):
        if fila == n:
            soluciones.append([''.join(fila) for fila in tablero])
            return

        for col in range(n):
            if col in cols or (fila + col) in diag1 or (fila - col) in diag2:
                continue

            tablero[fila][col] = 'Q'
            cols.add(col)
            diag1.add(fila + col)
            diag2.add(fila - col)

            backtrack(fila + 1, cols, diag1, diag2, tablero)

            tablero[fila][col] = '.'
            cols.remove(col)
            diag1.remove(fila + col)
            diag2.remove(fila - col)

    tablero = [['.' for _ in range(n)] for _ in range(n)]
    backtrack(0, set(), set(), set(), tablero)
    return soluciones

for sol in resolver_n_queens(4):
    for fila in sol:
        print(fila)
    print()
```

## 8.7 Trace para N = 4

```text
backtrack(fila=0, cols={}, diag1={}, diag2={})

├─ col=0:  cols={0}, diag1={0}, diag2={0}     tablero: Q . . .
│
│  backtrack(fila=1, ...)
│  ├─ col=0: ATACADA  skip
│  ├─ col=1: diag2 contiene 0 (reina de fila 0) → ATACADA  skip
│  ├─ col=2: cols={0,2}, diag1={0,3}, diag2={0,-1}     tablero: Q . . . / . . Q .
│  │  backtrack(fila=2, ...) — todas las columnas atacadas → BACKTRACK
│  └─ col=3: cols={0,3}, diag1={0,4}, diag2={0,-2}     tablero: Q . . . / . . . Q
│     backtrack(fila=2, ...) — col=1 funciona
│     cols={0,3,1}, diag1={0,4,3}, diag2={0,-2,1}       tablero: Q... / ...Q / .Q..
│     backtrack(fila=3, ...) — col=2 funciona
│     cols={0,3,1,2}, diag1={0,4,3,5}, diag2={0,-2,1,1}  ✓ SOLUCIÓN
│
├─ col=1, 2, 3 (continúa simétricamente)

SOLUCIONES ENCONTRADAS:
    ┌─────────────┐  ┌─────────────┐
    │ . Q . .     │  │ . . Q .     │
    │ . . . Q     │  │ Q . . .     │
    │ Q . . .     │  │ . . . Q     │
    │ . . Q .     │  │ . Q . .     │
    └─────────────┘  └─────────────┘
```

## 8.8 Análisis

```text
Tiempo en el peor caso:    O(N!)  (sin poda)
Tiempo con poda:           O(N!) en el peor caso, pero MUCHO menor en la práctica.
Espacio:                   O(N)  (stack + arreglos de marca)

Tasa de poda típica:
    - Para N = 8: solo 15,720 nodos visitados (vs 8⁸ = 16.7M sin poda).
    - "Solo" 92 soluciones de 4.4 × 10⁹ configuraciones posibles.
```

| N  | # Soluciones  | # Nodos (aprox)  | Tiempo        |
| -- | ------------- | ---------------- | ------------- |
| 4  | 2             | 50               | < 1 ms        |
| 8  | 92            | 15,720           | ~ 5 ms        |
| 10 | 724           | ~ 350,000        | ~ 100 ms      |
| 12 | 14,200        | ~ 9,000,000      | ~ 3 s         |
| 14 | 365,596       | ~ 250,000,000    | ~ 1 min       |

## 8.9 Variaciones

| Variación                    | Cambio                                    |
| ---------------------------- | ----------------------------------------- |
| **N-Queens II**: solo contar | No guardar tableros, solo incrementar contador |
| **Imprimir una** (no todas)  | Retornar al encontrar la primera          |
| **N-Queens con obstáculos**  | Marcar celdas prohibidas                  |
| **Simétrico**                | Solo explorar hasta `N/2` y reflejar      |

> **CLRS Capítulo 2 (ejercicio):** *“Describe a backtracking algorithm for solving the 4-queens problem.”*

---

# 9. Problema 4: Sudoku Solver

## 9.1 El problema

Dado un tablero de Sudoku `9 × 9` parcialmente lleno, completar las celdas vacías siguiendo las reglas.

```text
Reglas:
    - Cada fila debe contener los dígitos 1-9 sin repetir.
    - Cada columna debe contener los dígitos 1-9 sin repetir.
    - Cada bloque 3×3 debe contener los dígitos 1-9 sin repetir.

Entrada:
    5 3 . . 7 . . . .
    6 . . 1 9 5 . . .
    . 9 8 . . . . 6 .
    8 . . . 6 . . . 3
    4 . . 8 . 3 . . 1
    7 . . . 2 . . . 6
    . 6 . . . . 2 8 .
    . . . 4 1 9 . . 5
    . . . . 8 . . 7 9

Salida:   tablero completo válido.
```

## 9.2 Insight backtracking

> Para cada celda vacía, probar dígitos `1-9`. Si ninguno funciona → **retroceder a la celda anterior** y probar otro dígito.

## 9.3 Estado

```text
Estado: el tablero 9x9 mismo.
       (Las restricciones se verifican en línea).
```

## 9.4 Código en C

```c
#include <stdio.h>

#define N 9

int tablero[N][N];

int esValido(int fila, int col, int num) {
    // Verificar fila
    for (int x = 0; x < N; x++)
        if (tablero[fila][x] == num) return 0;

    // Verificar columna
    for (int x = 0; x < N; x++)
        if (tablero[x][col] == num) return 0;

    // Verificar bloque 3x3
    int f0 = (fila / 3) * 3;
    int c0 = (col / 3) * 3;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            if (tablero[f0 + i][c0 + j] == num) return 0;

    return 1;
}

int resolverSudoku(int fila, int col) {
    if (fila == N - 1 && col == N)
        return 1;   // tablero completo

    if (col == N) {
        fila++;
        col = 0;
    }

    if (tablero[fila][col] != 0)
        return resolverSudoku(fila, col + 1);

    for (int num = 1; num <= 9; num++) {
        if (esValido(fila, col, num)) {
            tablero[fila][col] = num;            // CHOOSE

            if (resolverSudoku(fila, col + 1))   // EXPLORE
                return 1;

            tablero[fila][col] = 0;              // UNCHOOSE
        }
    }

    return 0;   // backtrack
}
```

## 9.5 Código en Python

```python
def resolver_sudoku(tablero):
    def es_valido(fila, col, num):
        for x in range(9):
            if tablero[fila][x] == num or tablero[x][col] == num:
                return False

        f0, c0 = (fila // 3) * 3, (col // 3) * 3
        for i in range(3):
            for j in range(3):
                if tablero[f0 + i][c0 + j] == num:
                    return False
        return True

    def backtrack():
        for fila in range(9):
            for col in range(9):
                if tablero[fila][col] == 0:
                    for num in range(1, 10):
                        if es_valido(fila, col, num):
                            tablero[fila][col] = num          # CHOOSE
                            if backtrack():                   # EXPLORE
                                return True
                            tablero[fila][col] = 0           # UNCHOOSE
                    return False   # ningún número funciona → backtrack
        return True                # tablero lleno → solución

    backtrack()
    return tablero
```

## 9.6 Trace (simplificado)

```text
Estado inicial (vacío = 0):
    5 3 0  0 7 0  0 0 0
    6 0 0  1 9 5  0 0 0
    0 9 8  0 0 0  0 6 0
    ...

backtrack():
    (0,2)=0 VACÍA → probar 1: ya está en fila → skip
                  → probar 2: idem
                  → probar 4: ✓
                      tablero[0][2] = 4

    (0,3)=0 VACÍA → probar 1: ya en fila (5,3,4,1) → skip
                  → probar 2: ✓
                      tablero[0][3] = 2

    ... eventualmente se llega a una contradicción ...
    → backtrack: tablero[i][j] = 0, probar siguiente número en (i, j - 1)
```

## 9.7 Mejora: elegir la celda más restringida (MRV)

```text
En lugar de recorrer las celdas en orden,
elegir la celda vacía con MENOS candidatos (Minimum Remaining Values).

Esto poda MUCHO más rápido.
```

```python
def resolver_sudoku_mrv(tablero):
    def encontrar_mejor_celda():
        mejor = None
        min_opciones = 10
        for fila in range(9):
            for col in range(9):
                if tablero[fila][col] == 0:
                    opciones = sum(1 for n in range(1, 10) if es_valido(fila, col, n))
                    if opciones < min_opciones:
                        min_opciones = opciones
                        mejor = (fila, col)
                        if opciones == 0:
                            return None  # rama muerta
        return mejor

    def backtrack():
        celda = encontrar_mejor_celda()
        if celda is None:
            return True   # no hay celdas vacías → resuelto
        fila, col = celda

        for num in range(1, 10):
            if es_valido(fila, col, num):
                tablero[fila][col] = num
                if backtrack():
                    return True
                tablero[fila][col] = 0
        return False
```

## 9.8 Análisis

```text
Tiempo (peor caso):  O(9^m), donde m = número de celdas vacías
                     (típicamente m < 50 para Sudoku 9x9)

Con poda agresiva (MRV + propagación):
    Sudokus reales se resuelven en < 1 ms.
    El Sudoku más difícil del mundo: < 50 ms.
```

| Recurso        | Costo                |
| -------------- | -------------------- |
| **Tiempo**     | O(9^m) peor caso     |
| **Espacio**    | O(m) stack           |
| **# llamadas** | muy variable         |

## 9.9 Variaciones

| Variación                       | Cambio                                |
| ------------------------------- | ------------------------------------- |
| **Contar soluciones**           | No retornar al encontrar, contar todas |
| **Generar Sudoku**              | Llenar tablero vacío, eliminar números asegurando unicidad |
| **Sudoku killer**               | Restricciones adicionales de "jaulas" |
| **Sudoku 16 × 16**              | Cambiar N y el bloque a 4 × 4         |
| **Constraint Propagation**      | Antes de backtrack, deducir valores por propagación (más eficiente) |

---

# 10. Problema 5: Subset Sum

## 10.1 El problema

Dado un conjunto de `n` enteros y un valor `target`, encontrar **todos los subconjuntos** cuya suma sea exactamente `target`.

```text
Entrada:  nums = [1, 2, 3, 5], target = 5
Salida:   {1, 2, 2}  → no, espera, todos distintos
          {2, 3}      → suma 5 ✓
          {5}         → suma 5 ✓
          {1, 2, 2}   no aplica porque nums no tiene 2 repetido
```

(Si hubiera repetidos sería diferente; aquí asumo todos distintos por simplicidad.)

## 10.2 Variantes del problema

| Variante                 | Objetivo                                    |
| ------------------------ | ------------------------------------------- |
| **¿Existe** un subconjunto? | sí/no                                       |
| **Encontrar uno**        | retornar el primero                         |
| **Encontrar todos**      | listar todos                                |
| **Contar cuántos**       | solo el número                              |
| **Subset Sum cercano**   | el más cercano a `target` (sin exceder)    |

## 10.3 Insight backtracking

> Para cada elemento decidir: **lo incluyo** o **no lo incluyo**.
> Ramificación binaria → árbol con `2ⁿ` hojas.

## 10.4 Estado

```text
Estado:
    idx        = posición actual en nums
    suma       = suma acumulada del subconjunto parcial
    subset[]   = elementos del subconjunto parcial
```

## 10.5 Código en C

```c
#include <stdio.h>

#define MAX 100

int nums[MAX];
int n, target;
int subset[MAX];
int subset_size = 0;

void encontrar(int idx, int suma) {
    if (suma == target) {
        printf("{ ");
        for (int i = 0; i < subset_size; i++) printf("%d ", subset[i]);
        printf("}\n");
        return;     // o seguir para más subconjuntos
    }

    if (idx == n) return;

    // Poda: si suma > target y nums son positivos, parar
    if (suma > target) return;

    // NO incluir nums[idx]
    encontrar(idx + 1, suma);

    // Incluir nums[idx]
    subset[subset_size++] = nums[idx];
    encontrar(idx + 1, suma + nums[idx]);
    subset_size--;     // UNCHOOSE
}

int main() {
    int arr[] = {1, 2, 3, 5};
    n = 4; target = 5;
    for (int i = 0; i < n; i++) nums[i] = arr[i];

    encontrar(0, 0);
    return 0;
}
```

## 10.6 Código en Python

```python
def subset_sum(nums, target):
    resultado = []

    def backtrack(inicio, suma_actual, subset):
        if suma_actual == target:
            resultado.append(subset.copy())
            return

        if inicio == len(nums):
            return

        # Poda: si suma > target y nums son positivos, parar
        if suma_actual > target:
            return

        for i in range(inicio, len(nums)):
            if suma_actual + nums[i] <= target:        # poda
                subset.append(nums[i])                  # CHOOSE
                backtrack(i + 1, suma_actual + nums[i], subset)
                subset.pop()                            # UNCHOOSE

    backtrack(0, 0, [])
    return resultado

print(subset_sum([1, 2, 3, 5], 5))
# [[2, 3], [5]]
```

## 10.7 Trace para `[1, 2, 3, 5]`, target = 5

```text
backtrack(inicio=0, suma=0, [])

├─ incluyo 1: subset=[1], suma=1
│  ├─ incluyo 2: [1,2], suma=3
│  │  ├─ incluyo 3: [1,2,3], suma=6 > 5, poda ✗
│  │  └─ incluyo 5: [1,2,5], suma=8 > 5, poda ✗
│  └─ incluyo 3: [1,3], suma=4
│     └─ incluyo 5: [1,3,5], suma=9 > 5, poda ✗
├─ incluyo 2: subset=[2], suma=2
│  ├─ incluyo 3: [2,3], suma=5  ✓ guardar [2,3]
│  └─ incluyo 5: [2,5], suma=7 > 5, poda ✗
├─ incluyo 3: subset=[3], suma=3
│  └─ incluyo 5: [3,5], suma=8 > 5, poda ✗
└─ incluyo 5: subset=[5], suma=5  ✓ guardar [5]

Resultado: [[2, 3], [5]]
```

## 10.8 Análisis

| Recurso        | Costo                          |
| -------------- | ------------------------------ |
| **Tiempo**     | O(2ⁿ) peor caso                |
| **Espacio**    | O(n) stack                     |
| **Con poda**   | O(n·target) si nums son positivos (DP) |

> **Conexión con DP:** Subset Sum **sin repeticiones y con números positivos** tiene solución DP en `O(n·target)`. Backtracking es mejor cuando `target` es grande.

## 10.9 Variaciones

| Variación                          | Cambio                                       |
| ---------------------------------- | -------------------------------------------- |
| **Con números negativos**          | No podar por suma > target (puede mejorar)   |
| **Subconjunto más cercano**        | Guardar la mejor solución hasta ahora        |
| **Múltiples targets**              | Repetir para cada target                     |
| **Partition Equal Subset Sum**     | target = suma_total / 2                      |

---

# 11. Problema 6: Combination Sum

## 11.1 El problema

Dado un conjunto de candidatos y un `target`, encontrar **todas las combinaciones** de candidatos que sumen exactamente `target`.

```text
Entrada:  candidates = [2, 3, 6, 7], target = 7
Salida:   [[2, 2, 3], [7]]    (con repetición permitida)

          (sin repetición)
Salida:   [[7]]                (solo 7 = 7)
```

## 11.2 Las cuatro variantes

| Variante                  | Repetición | Reposición | Ejemplo                            |
| ------------------------- | ---------- | ---------- | ---------------------------------- |
| **Con repetición, con repos.** | sí        | sí         | `target=4, [2,3]` → `[2,2], [3]`... espera, pero `[2,2] = 4` ✓ |
| **Con repetición, sin repos.** | sí        | no         | `[2, 2, 3] = 7` pero 2 ya no se usa |
| **Sin repetición, con repos.** | no        | sí         | Cada candidato solo UNA vez en cada combinación |
| **Sin repetición, sin repos.** | no        | no         | Subset Sum puro                    |

## 11.3 Insight backtracking

> Variación de Subset Sum con la restricción extra de **orden**.
> Mantener un índice `start` para evitar duplicados.

## 11.4 Estado

```text
Estado:
    start    = desde dónde puedo elegir
    restante = target - suma_acumulada
    combo    = combinación parcial
```

## 11.5 Código en Python — Combinación CON repetición

```python
def combination_sum(nums, target):
    resultado = []

    def backtrack(start, restante, combo):
        if restante == 0:
            resultado.append(combo.copy())
            return

        if restante < 0:
            return     # poda: excedimos

        for i in range(start, len(nums)):
            # nums[i] >= 0 (si no, no podemos podar por restante < 0)
            combo.append(nums[i])           # CHOOSE
            backtrack(i, restante - nums[i], combo)   # i, no i+1 → REPETICIÓN
            combo.pop()                     # UNCHOOSE

    backtrack(0, target, [])
    return resultado

print(combination_sum([2, 3, 6, 7], 7))
# [[2, 2, 3], [7]]
```

## 11.6 Código en Python — Combinación SIN repetición

```python
def combination_sum_no_rep(nums, target):
    resultado = []

    def backtrack(start, restante, combo):
        if restante == 0:
            resultado.append(combo.copy())
            return

        for i in range(start, len(nums)):
            if nums[i] > restante:
                break   # poda: nums está ordenado

            combo.append(nums[i])
            backtrack(i + 1, restante - nums[i], combo)   # i+1 → NO repetición
            combo.pop()

    nums.sort()  # para que la poda funcione
    backtrack(0, target, [])
    return resultado
```

## 11.7 Trace — `nums=[2,3,6,7]`, target=7, CON repetición

```text
backtrack(start=0, rest=7, [])

├─ elijo 2: combo=[2], backtrack(0, 5)
│  ├─ elijo 2: combo=[2,2], backtrack(0, 3)
│  │  ├─ elijo 2: [2,2,2], rest=1 — sigue (ningún candidato cabe)
│  │  └─ elijo 3: [2,2,3], rest=0  ✓ guardar [2,2,3]
│  ├─ elijo 3: [2,3], backtrack(1, 2)  — poda, ningún candidato cabe
│  ├─ elijo 6, 7: rest < 0  poda ✗
├─ elijo 3: combo=[3], backtrack(1, 4)
│  ├─ elijo 3: [3,3], rest=1 — poda
│  ├─ elijo 6, 7: poda ✗
├─ elijo 6: rest=1, poda ✗
└─ elijo 7: [7], rest=0  ✓ guardar [7]

Resultado: [[2, 2, 3], [7]]
```

## 11.8 Análisis

| Recurso        | Costo                              |
| -------------- | ---------------------------------- |
| **Tiempo**     | O(N^(T/M)) donde T=target, M=min(nums[i]) |
| **Espacio**    | O(T/M) stack                      |

> **Ejemplo:** target = 30, nums = [2, 3, 5] → profundidad máx 15 → O(3^15) en el peor caso, pero con poda es mucho menos.

## 11.9 Variaciones

| Variación                  | Cambio                                  |
| -------------------------- | --------------------------------------- |
| **Con números negativos**   | No podar por `restante < 0`, usar otro criterio |
| **Mínimo número de elementos** | Branch & Bound con cota inferior    |
| **Multi-target**           | Repetir para cada target                |

---

# 12. Problema 7: Word Search (en grid)

## 12.1 El problema

Dada una cuadrícula `m × n` de caracteres y una palabra, determinar si la palabra **existe** en la cuadrícula formando un camino de **celdas adyacentes** (horizontal o vertical, sin repetir celdas).

```text
Cuadrícula:
    A B C E
    S F C S
    A D E E

Palabra: "ABCCED"  → ¿existe?
    A → B → C → C → E → D
        ✓ sí existe

Palabra: "ABCB"  → ¿existe?
    A → B → C → B  (B ya visitado) → no
        ✗ no existe (con regla de no repetir)
```

## 12.2 Insight backtracking

> Desde cada celda, intentar la primera letra. Si coincide, **DFS en 4 direcciones** buscando la siguiente letra. Si falla, backtrack.

## 12.3 Estado

```text
Estado:
    (i, j)    = posición actual
    idx       = índice en la palabra (qué letra busco)
    visitado  = celdas ya usadas en este camino
```

## 12.4 Código en C

```c
#include <stdbool.h>

#define MAX 100

char grid[MAX][MAX];
bool visitado[MAX][MAX];
int m, n;

int dirs[4][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};

bool dfs(int i, int j, char *word, int idx) {
    if (word[idx] == '\0') return true;   // llegamos al final

    if (i < 0 || i >= m || j < 0 || j >= n)
        return false;
    if (visitado[i][j])
        return false;
    if (grid[i][j] != word[idx])
        return false;

    visitado[i][j] = true;

    for (int d = 0; d < 4; d++) {
        int ni = i + dirs[d][0];
        int nj = j + dirs[d][1];
        if (dfs(ni, nj, word, idx + 1))
            return true;
    }

    visitado[i][j] = false;     // UNCHOOSE
    return false;
}

bool exist(char *word) {
    for (int i = 0; i < m; i++)
        for (int j = 0; j < n; j++)
            if (dfs(i, j, word, 0))
                return true;
    return false;
}
```

## 12.5 Código en Python

```python
def exist(grid, word):
    if not grid:
        return False

    m, n = len(grid), len(grid[0])
    visitado = [[False] * n for _ in range(m)]

    def dfs(i, j, idx):
        if idx == len(word):
            return True

        if (i < 0 or i >= m or j < 0 or j >= n or
                visitado[i][j] or grid[i][j] != word[idx]):
            return False

        visitado[i][j] = True

        for di, dj in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            if dfs(i + di, j + dj, idx + 1):
                return True

        visitado[i][j] = False        # UNCHOOSE
        return False

    for i in range(m):
        for j in range(n):
            if dfs(i, j, 0):
                return True

    return False
```

## 12.6 Trace — palabra "ABCCED"

```text
Cuadrícula:
    (0,0)A  (0,1)B  (0,2)C  (0,3)E
    (1,0)S  (1,1)F  (1,2)C  (1,3)S
    (2,0)A  (2,1)D  (2,2)E  (2,3)E

Camino encontrado:
    (0,0)A → (0,1)B → (0,2)C → (1,2)C → (2,2)E → (2,1)D    ✓ "ABCCED"

Si en el paso 3 hubiéramos elegido (0,3) en lugar de (1,2):
    (0,0)A → (0,1)B → (0,2)C → (0,3)E → (1,3)S    ✗ no es "ABCCED"
    → BACKTRACK al paso 2 y probar (1,2).
```

## 12.7 Análisis

```text
Tiempo (peor caso):   O(m·n·4^L)   donde L = len(word)
                      (cada celda de inicio, cada celda del path tiene 4 opciones)
Espacio:               O(L)         (stack)
```

| Recurso        | Costo                |
| -------------- | -------------------- |
| **Tiempo**     | O(m·n·4^L)           |
| **Espacio**    | O(L)                 |

## 12.8 Variaciones

| Variación                       | Cambio                                  |
| ------------------------------- | --------------------------------------- |
| **Word Search II** (multi-palabra) | Construir Trie, podar caminos           |
| **8 direcciones** (diagonales)  | Agregar 4 direcciones más               |
| **Word Search con peso**        | Encontrar camino de mínimo costo        |

---

# 13. Problema 8: Rat in a Maze

## 13.1 El problema

Un ratón parte de la celda `(0, 0)` y debe llegar a la celda `(N-1, N-1)` moviéndose solo **abajo o derecha**. Algunas celdas están bloqueadas. Encontrar **uno** o **todos** los caminos posibles.

```text
Maze (1 = libre, 0 = bloqueada):
    1 0 0 0
    1 1 0 1
    1 1 0 0
    0 1 1 1

Salida:
    D R R D D R     (Derecha, Abajo, etc.)
    D D R D D R
    etc.
```

## 13.2 Insight backtracking

> Desde `(i, j)` intentar ir **abajo** o **derecha**. Marcar como visitado, recursar, desmarcar.

## 13.3 Código en C

```c
#define N 4

int maze[N][N] = {
    {1, 0, 0, 0},
    {1, 1, 0, 1},
    {1, 1, 0, 0},
    {0, 1, 1, 1}
};

int sol[N][N];

void imprimirSol() {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++)
            printf("%d ", sol[i][j]);
        printf("\n");
    }
    printf("\n");
}

int resolver(int x, int y) {
    if (x == N - 1 && y == N - 1) {
        sol[x][y] = 1;
        return 1;
    }

    if (x < 0 || x >= N || y < 0 || y >= N)
        return 0;
    if (maze[x][y] != 1 || sol[x][y] == 1)
        return 0;

    sol[x][y] = 1;     // CHOOSE

    if (resolver(x + 1, y)) return 1;   // abajo
    if (resolver(x, y + 1)) return 1;   // derecha

    sol[x][y] = 0;     // UNCHOOSE
    return 0;
}
```

## 13.4 Versión: encontrar TODOS los caminos

```python
def rat_in_maze_todos(maze):
    n = len(maze)
    resultado = []

    def backtrack(i, j, camino):
        if (i, j) == (n - 1, n - 1):
            resultado.append(camino.copy())
            return

        # movimientos: abajo, derecha
        for di, dj, letra in [(1, 0, 'D'), (0, 1, 'R')]:
            ni, nj = i + di, j + dj
            if 0 <= ni < n and 0 <= nj < n and maze[ni][nj] == 1:
                camino.append(letra)
                backtrack(ni, nj, camino)
                camino.pop()

    backtrack(0, 0, [])
    return resultado
```

## 13.5 Visualización

```text
Maze:
    1 0 0 0
    1 1 0 1
    1 1 0 0
    0 1 1 1

Árbol de exploración (recorrido válido):
    (0,0) → (1,0) → (2,0) → (1,1) → (2,1) → (3,1) → (3,2) → (3,3)✓
                                                        ↑
                                                    salida

    En cada paso: solo "abajo" o "derecha". Si choca con 0 o se sale → BACKTRACK.
```

## 13.6 Análisis

```text
Tiempo (peor caso):   O(2^(N²))  sin poda
                      O(N²) con poda efectiva
Espacio:               O(N²)  (stack + tablero)
```

## 13.7 Variaciones

| Variación                   | Cambio                              |
| --------------------------- | ----------------------------------- |
| **4 direcciones**           | Permitir arriba, abajo, izq, der    |
| **Con peso en celdas**      | Minimizar suma de pesos            |
| **Multi-rat**               | Múltiples ratones, sin colisión    |

---

# 14. Problema 9: Hamiltonian Path/Cycle

## 14.1 El problema

Dado un grafo, encontrar un **camino Hamiltoniano**: un camino que visita **cada vértice exactamente una vez**.

```text
Variantes:
    - PATH:     visita cada vértice una vez (no requiere cerrar el ciclo)
    - CYCLE:    visita cada vértice una vez y regresa al inicio

Ejemplo:
    A — B
    |   |
    C — D

Hamiltonian Cycle: A → B → D → C → A ✓
Hamiltonian Path:  A → B → D → C   (sin regresar) ✓
```

## 14.2 Aplicaciones y por qué importa

| Aplicación                       | Uso                                |
| -------------------------------- | ---------------------------------- |
| **TSP** (Traveling Salesman)     | Encontrar la ruta más corta        |
| **Planificación de tareas**      | Orden óptimo respetando dependencias |
| **Diseño de circuitos**          | Encontrar orden de visita          |
| **Genómica**                     | Reconstrucción de secuencias       |

> **Importante:** Hamiltonian Cycle es **NP-completo**. No hay algoritmo polinómico conocido.

## 14.3 Insight backtracking

> Probar todos los vértices como inicio. En cada paso, elegir un vecino no visitado.

## 14.4 Estado

```text
Estado:
    path[0..idx-1]   = camino construido
    en_path[v]       = ¿v ya está en el path?
```

## 14.5 Código en C

```c
#define N 10

int V;
int adj[N][N];
int path[N];
int en_path[N];

int esHamiltoniano(int v, int idx) {
    if (idx == V) {
        // Para cycle: return adj[path[idx-1]][path[0]];
        return 1;
    }

    for (int i = 0; i < V; i++) {
        if (adj[v][i] && !en_path[i]) {
            path[idx] = i;
            en_path[i] = 1;
            if (esHamiltoniano(i, idx + 1)) return 1;
            en_path[i] = 0;       // UNCHOOSE
        }
    }
    return 0;
}
```

## 14.6 Análisis

```text
Tiempo:  O(V!)  peor caso (sin poda)
Espacio: O(V)
```

## 14.7 Mejoras (Branch & Bound)

| Mejora                       | Cómo funciona                          |
| ---------------------------- | -------------------------------------- |
| **Dirac's theorem**          | Si `grado(v) ≥ V/2 ∀v` → seguro Hamiltoniano |
| **Ore's theorem**            | Si `deg(u) + deg(v) ≥ V ∀u≠v` → seguro |
| **Bound**                    | Si quedan vértices inalcanzables → podar |

---

# 15. Problema 10: M-Coloring de Grafos

## 15.1 El problema

Dado un grafo y `M` colores, asignar un color a cada vértice de modo que **vértices adyacentes tengan colores distintos**.

```text
Entrada:
    Grafo:    A — B
              |   |
              C — D
    M = 3 colores: {rojo, verde, azul}

Salida:
    A=rojo, B=verde, C=verde, D=azul   (muchas soluciones posibles)
```

## 15.2 Aplicaciones

| Aplicación                       | Modelo                          |
| -------------------------------- | ------------------------------- |
| **Horarios**                     | Exámenes = vértices, conflictos = aristas |
| **Asignación de registros**      | Variables = vértices, conflictos = aristas |
| **Coloreo de mapas**             | Regiones = vértices, fronteras = aristas |
| **Frequency assignment**         | Torres = vértices, interferencia = aristas |

## 15.3 Insight backtracking

> Para cada vértice, intentar `M` colores. Si colorea sin conflicto → siguiente vértice. Si no → siguiente color. Si no hay color → backtrack.

## 15.4 Estado

```text
Estado:
    color[v] = color asignado al vértice v
    vértices se colorean en orden 0, 1, ..., V-1
```

## 15.5 Código en Python

```python
def m_coloring(grafo, M):
    V = len(grafo)
    color = [-1] * V

    def es_valido(v, c):
        for u in range(V):
            if grafo[v][u] == 1 and color[u] == c:
                return False
        return True

    def backtrack(v):
        if v == V:
            return True   # todos coloreados

        for c in range(M):
            if es_valido(v, c):
                color[v] = c           # CHOOSE
                if backtrack(v + 1):   # EXPLORE
                    return True
                color[v] = -1         # UNCHOOSE

        return False

    if backtrack(0):
        return color
    return None
```

## 15.6 Versión: encontrar todas las coloraciones

```python
def m_coloring_todas(grafo, M):
    V = len(grafo)
    color = [-1] * V
    resultado = []

    def backtrack(v):
        if v == V:
            resultado.append(color.copy())
            return

        for c in range(M):
            if es_valido(v, c):
                color[v] = c
                backtrack(v + 1)
                color[v] = -1

    backtrack(0)
    return resultado
```

## 15.7 Análisis

```text
Tiempo (peor caso):   O(M^V)
Espacio:               O(V) + O(profundidad)

> Mejora importante: elegir el vértice con MENOS colores disponibles (MRV).
```

## 15.8 Teorema fundamental: los 4 colores

```text
Teorema de los 4 colores (1976, Appel & Haken):
    Todo grafo planar es 4-coloreable.

→ Para colorear MAPAS nunca necesitas más de 4 colores.
→ Pero encontrar la coloración con MÍNIMO número de colores es NP-hard.
```

## 15.9 Variaciones

| Variación                       | Cambio                                |
| ------------------------------- | ------------------------------------- |
| **Minimum coloring**            | Encontrar el menor `M` que funciona   |
| **Edge coloring**               | Colorear aristas en vez de vértices   |
| **List coloring**               | Cada vértice tiene su propia lista de colores disponibles |

---

# 16. Problema 11: Knight's Tour

## 16.1 El problema

Un caballo de ajedrez debe visitar **cada casilla** de un tablero `N × N` **exactamente una vez**.

```text
El caballo se mueve en "L":
    ┌───┬───┬───┬───┐         (2 horizontal + 1 vertical,
    │   │   │   │   │          o 1 horizontal + 2 vertical)
    ├───┼───┼───┼───┤
    │   │ ↑ │   │   │
    ├───┼───┼───┼───┤
    │   │   │   │   │
    ├───┼───┼───┼───┤
    │   │   │   │   │
    └───┴───┴───┴───┘
```

## 16.2 Insight backtracking

> Desde cada casilla, intentar hasta 8 movimientos. Marcar visitado, recursar, desmarcar.

## 16.3 Código en Python

```python
def knights_tour(N):
    movs = [(2, 1), (1, 2), (-1, 2), (-2, 1),
            (-2, -1), (-1, -2), (1, -2), (2, -1)]

    tablero = [[-1] * N for _ in range(N)]
    tablero[0][0] = 0

    def backtrack(x, y, paso):
        if paso == N * N:
            return True

        for dx, dy in movs:
            nx, ny = x + dx, y + dy
            if (0 <= nx < N and 0 <= ny < N and tablero[nx][ny] == -1):
                tablero[nx][ny] = paso          # CHOOSE
                if backtrack(nx, ny, paso + 1):  # EXPLORE
                    return True
                tablero[nx][ny] = -1            # UNCHOOSE

        return False

    return tablero if backtrack(0, 0, 1) else None
```

## 16.4 Heurística de Warnsdorff

> **Observación empírica:** elegir el movimiento que deja MENOS opciones futuras.

```python
def knights_tour_warnsdorff(N):
    movs = [(2, 1), (1, 2), (-1, 2), (-2, 1),
            (-2, -1), (-1, -2), (1, -2), (2, -1)]

    tablero = [[-1] * N for _ in range(N)]
    tablero[0][0] = 0

    def contar_grado(x, y):
        return sum(1 for dx, dy in movs
                   if 0 <= x + dx < N and 0 <= y + dy < N
                   and tablero[x + dx][y + dy] == -1)

    def backtrack(x, y, paso):
        if paso == N * N:
            return True

        # Ordenar movimientos por grado del destino (Warnsdorff)
        candidatos = []
        for dx, dy in movs:
            nx, ny = x + dx, y + dy
            if (0 <= nx < N and 0 <= ny < N and tablero[nx][ny] == -1):
                candidatos.append((contar_grado(nx, ny), nx, ny))

        candidatos.sort()    # menor grado primero

        for _, nx, ny in candidatos:
            tablero[nx][ny] = paso
            if backtrack(nx, ny, paso + 1):
                return True
            tablero[nx][ny] = -1

        return False

    return tablero if backtrack(0, 0, 1) else None
```

## 16.5 Análisis

```text
Sin heurística:
    Para 8x8: ~4 × 10⁵¹ caminos posibles (mayoría no cerrados).
    Backtracking naïve puede tomar horas.

Con Warnsdorff:
    Para 8x8: típicamente < 1 ms.
    (Heurística empírica, no garantía formal.)
```

## 16.6 Salida visual (Warnsdorff, 8×8)

```text
    0  59  38  33  30  17   8  63
   37  34  31  60  15  62  29  16
   58   1  36  39  32  27  18   7
   35  48  41  26  61  14  23  10
   42  57   2  49  40  21   6  19
   47  50  45  54  25  12  11  24
   56  43  52   3  20   5  28  13
   51  46  55  44  53   4  65  22
```

## 16.7 Variaciones

| Variación                       | Cambio                                |
| ------------------------------- | ------------------------------------- |
| **Tour cerrado**                | Verificar arista final al inicio       |
| **N variable**                  | Probar varios N                        |
| **Knight's tour con obstáculos**| Marcar celdas prohibidas              |

---

# 17. Poda (Pruning) — El Verdadero Arte

> **La poda es lo que diferencia backtracking de fuerza bruta.** Sin poda, backtracking es fuerza bruta disfrazada.

## 17.1 Los tres tipos de poda

```text
1. CONSTRAINT-BASED PRUNING (poda por restricciones):
   "Esta rama viola una regla del problema → no la explores."

2. BOUND-BASED PRUNING / FORWARD CHECKING (poda por cotas):
   "Esta rama NO PUEDE llevar a una solución óptima/mejor → no la explores."

3. SYMMETRY BREAKING (rotura de simetría):
   "Esta rama es EQUIVALENTE a otra ya explorada → no la explores."
```

## 17.2 Poda por restricciones

**Idea:** si una elección parcial viola una regla, **abortar inmediatamente**.

```c
// En N-Queens: verificar que la nueva reina no sea atacada
if (esAtacada(fila, col)) continue;  // PODA

// En Sudoku: verificar fila, columna, bloque 3x3
if (!esValido(fila, col, num)) continue;  // PODA
```

```text
Ejemplo dramático en Sudoku:
    Sin poda: 9⁸¹ ≈ 1.9 × 10⁷⁷  tableros.
    Con poda (9 candidatos → 4 promedio por celda):
        4⁸¹ ≈ 4.4 × 10⁴⁸   (sigue siendo mucho, pero 10²⁹ veces mejor).
```

## 17.3 Poda por cotas (Forward Checking)

**Idea:** estimar si la rama puede mejorar la mejor solución actual.

```text
Subset Sum con target = 20:
    nums restantes: [10, 15, 7]
    suma actual: 12
    suma_max_posible = 12 + 10 + 15 + 7 = 44

    Si ya encontré una solución de 22, y 12 < 22,
    ¿vale la pena seguir?
        Sí, porque 12 + 10 = 22 (puede empatar/mejorar).
        Pero 12 + 7 = 19 < 22 → no vale la pena.

    COTA INFERIOR: mejor valor posible con lo que queda.
    COTA SUPERIOR: peor valor posible con lo que queda.
```

```python
def subset_sum_optimizado(nums, target):
    nums.sort(reverse=True)
    mejor = [None]
    mejor_suma = [0]

    def backtrack(inicio, suma, subset):
        if suma == target:
            if suma > mejor_suma[0]:
                mejor_suma[0] = suma
                mejor[0] = subset.copy()
            return

        # PODA: si la mejor suma posible no supera la actual
        max_futuro = suma + sum(nums[inicio:])
        if max_futuro <= mejor_suma[0]:
            return

        for i in range(inicio, len(nums)):
            if suma + nums[i] > target:
                continue    # PODA

            subset.append(nums[i])
            backtrack(i + 1, suma + nums[i], subset)
            subset.pop()

    backtrack(0, 0, [])
    return mejor[0]
```

## 17.4 Rotura de simetría

**Idea:** evitar explorar configuraciones equivalentes.

```text
Ejemplo 1: N-Queens
    Solución simétrica (rotación/reflexión):
        Q . . .          . . . Q
        . . Q .   ↔     . Q . .
        . . . Q          Q . . .
        . Q . .          . . Q .

    Estrategia: solo considerar la mitad de las primeras filas,
                y luego generar simétricas.

Ejemplo 2: 8 reinas
    92 soluciones totales.
    Con simetría: solo 12 únicas (las otras son rotaciones/reflexiones).

Ejemplo 3: Permutaciones
    Permutar [1,1,2]:
        Original:    [1,1,2], [1,2,1], [2,1,1]
        Con duplicados:    [1,1,2], [1,2,1], [2,1,1]   (3 únicas)

    Estrategia: si nums[i] == nums[i-1] y nums[i-1] no se usó, skip nums[i].
```

```python
def permutar_unicas(nums):
    nums.sort()  # necesario
    resultado = []

    def backtrack(perm, usado):
        if len(perm) == len(nums):
            resultado.append(perm.copy())
            return

        for i in range(len(nums)):
            if usado[i]:
                continue
            # SYMMETRY BREAKING
            if i > 0 and nums[i] == nums[i - 1] and not usado[i - 1]:
                continue

            perm.append(nums[i])
            usado[i] = True
            backtrack(perm, usado)
            perm.pop()
            usado[i] = False

    backtrack([], [False] * len(nums))
    return resultado
```

## 17.5 Tabla resumen de podas

| Tipo                       | Ejemplo                                            | Ganancia típica       |
| -------------------------- | -------------------------------------------------- | --------------------- |
| **Restricciones**          | Sudoku: verificar fila/col/bloque                  | 10⁶ a 10³⁰ veces     |
| **Cota superior**          | TSP: si ya tengo un tour < cota inf. restante      | 2x a 10x              |
| **Cota inferior**          | Branch & Bound para Knapsack                       | 5x a 100x             |
| **MRV** (Min Remaining Val)| Sudoku: celda con menos candidatos                 | 2x a 5x               |
| **Forward checking**       | M-Coloring: verificar vecinos                      | 2x a 10x              |
| **Simetría**               | N-Queens: mitad de las configuraciones              | Constante             |
| **Ordenamiento**           | Probar primero las opciones más restrictivas       | 2x a 5x               |

## 17.6 Ejemplo completo: N-Queens con múltiples podas

```python
def n_queens_podado(n):
    soluciones = []

    def backtrack(fila, cols, diag1, diag2):
        if fila == n:
            soluciones.append(cols.copy())
            return

        for col in range(n):
            # PODA 1: restricciones (ataques)
            if col in cols or (fila + col) in diag1 or (fila - col) in diag2:
                continue

            # PODA 2: forward checking — mirar si es posible completar
            # (heurística simple: que queden al menos n - fila - 1 columnas libres)
            # (omitido en este ejemplo para brevedad)

            cols.add(col)
            diag1.add(fila + col)
            diag2.add(fila - col)

            backtrack(fila + 1, cols, diag1, diag2)

            cols.remove(col)
            diag1.remove(fila + col)
            diag2.remove(fila - col)

    backtrack(0, set(), set(), set())
    return soluciones
```

---

# 18. Branch and Bound (Avanzado)

## 18.1 Idea

**Branch and Bound** es backtracking + **cotas** que permiten descartar ramas que **no pueden mejorar** la mejor solución actual.

```text
Backtracking puro:   explora todo lo que sea VÁLIDO.
Branch & Bound:       explora solo lo que sea VÁLIDO Y POSIBLEMENTE ÓPTIMO.
```

## 18.2 Estructura

```text
función BRANCH_AND_BOUND(estado, mejor):
    si estado es meta:
        si es mejor que mejor:
            mejor = estado
        return

    para cada hijo:
        calcular cota_inferior(hijo)
        calcular cota_superior(hijo)

        si cota_superior ≤ valor(mejor):
            continue    // PODA: no puede mejorar

        BRANCH_AND_BOUND(hijo, mejor)
```

## 18.3 TSP con Branch and Bound

```text
Problema: Traveling Salesman Problem
    - Ciudades: 0, 1, ..., n-1
    - Distancias: dist[i][j]
    - Encontrar tour de costo mínimo.

Branch & Bound:
    - Cota inferior: costo del tour parcial + mínimo posible para el resto.
    - Si cota_inferior ≥ mejor: podar.
```

```python
import heapq

def tsp_branch_and_bound(dist):
    n = len(dist)
    estado_inicial = (0, frozenset([0]), 0)
    mejor_costo = [float('inf')]
    pila = [estado_inicial]

    while pila:
        ciudad, visitados, costo = pila.pop()

        if len(visitados) == n:
            costo_total = costo + dist[ciudad][0]
            if costo_total < mejor_costo[0]:
                mejor_costo[0] = costo_total
            continue

        for prox in range(n):
            if prox not in visitados:
                nuevo_costo = costo + dist[ciudad][prox]

                # Cota inferior simple: mínimo posible para completar
                restantes = [c for c in range(n) if c not in visitados]
                if restantes:
                    cota = nuevo_costo + sum(
                        min(dist[c][j] for j in range(n) if j != c)
                        for c in restantes)
                else:
                    cota = nuevo_costo + dist[prox][0]

                if cota < mejor_costo[0]:    # PODA
                    pila.append((prox, visitados | {prox}, nuevo_costo))

    return mejor_costo[0]
```

## 18.4 Asignación con Branch and Bound

```text
Problema: Asignar N tareas a N personas minimizando costo total.
    - costo[i][j] = costo de persona i haciendo tarea j.
    - Cada persona hace UNA tarea, cada tarea UNA persona.

Cota inferior: costo actual + suma de los mínimos de las filas restantes.
```

```python
def asignacion_branch_bound(costo):
    n = len(costo)
    mejor = [float('inf')]

    def backtrack(i, asignacion, costo_actual):
        if i == n:
            mejor[0] = min(mejor[0], costo_actual)
            return

        # Cota inferior
        cota = costo_actual + sum(min(costo[j]) for j in range(i, n))
        if cota >= mejor[0]:
            return   # PODA

        for j in range(n):
            if j not in asignacion:
                asignacion.append(j)
                backtrack(i + 1, asignacion, costo_actual + costo[i][j])
                asignacion.pop()

    backtrack(0, [], 0)
    return mejor[0]
```

## 18.5 Comparación: Backtracking vs Branch & Bound

| Aspecto                | Backtracking                  | Branch & Bound                 |
| ---------------------- | ----------------------------- | ------------------------------ |
| **Objetivo**           | Todas las soluciones / una    | La mejor solución              |
| **Poda**               | Por restricciones             | Por restricciones + cotas      |
| **Memoria**            | O(profundidad)                | O(nodos explorados)            |
| **Optimalidad**        | Sí (si explora todo)          | Sí (más rápido en promedio)    |
| **Velocidad**          | Lento en promedio             | Más rápido en promedio         |

---

# 19. Iterative Deepening

## 19.1 Idea

Combinar **DFS** (memoria eficiente) con **BFS** (completitud) haciendo DFS con un **límite de profundidad** creciente.

```text
DFS(0)         ← límite 0: solo raíz
DFS(0)         ← límite 1: raíz + hijos
DFS(0)         ← límite 2: raíz + hijos + nietos
...
```

## 19.2 Aplicación: Knight's Tour sin Warnsdorff

```python
def knights_tour_iddfs(N):
    """Encuentra UN tour con IDDFS."""

    movs = [(2, 1), (1, 2), (-1, 2), (-2, 1),
            (-2, -1), (-1, -2), (1, -2), (2, -1)]

    def dfs_limitado(x, y, paso, limite, tablero):
        if paso == limite:
            return paso == N * N   # éxito si alcanzamos todas

        for dx, dy in movs:
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and tablero[nx][ny] == -1:
                tablero[nx][ny] = paso
                if dfs_limitado(nx, ny, paso + 1, limite, tablero):
                    return True
                tablero[nx][ny] = -1

        return False

    tablero = [[-1] * N for _ in range(N)]
    tablero[0][0] = 0

    for limite in range(1, N * N + 1):
        if dfs_limitado(0, 0, 1, limite, tablero):
            return tablero

    return None
```

## 19.3 Análisis

```text
Tiempo:    O(b^d)  donde b = branching factor, d = profundidad
Espacio:   O(d)    ← solo el camino actual (como DFS)

Útil cuando:
    - El espacio es enorme y no puedes guardar frontera.
    - La solución puede estar a profundidad variable.
```

---

# 20. Complejidad de Backtracking

## 20.1 El peor caso

```text
En el peor caso, backtracking = fuerza bruta.
    T(n) = branching_factor ^ profundidad

Ejemplos:
    Permutaciones:          n!
    Combinaciones:           2^n
    N-Queens (sin poda):    n^n
    Sudoku (sin poda):      9^m (m = celdas vacías)

Esto NO es viable para n grande. Solo funciona porque PODAMOS.
```

## 20.2 El factor de ramificación efectivo

> **Clave:** la poda cambia el branching factor efectivo de `b` a `b · (1 - p)`, donde `p` es la tasa de poda.

```text
Si b = 5 y podas el 80%:
    b_efectivo = 5 · 0.2 = 1
    T(n) = 1^n = 1   ← ridículamente rápido (raro)

Si b = 5 y podas el 50%:
    b_efectivo = 5 · 0.5 = 2.5
    T(n) ≈ 2.5^n

Si b = 5 y podas el 10%:
    b_efectivo = 5 · 0.9 = 4.5
    T(n) ≈ 4.5^n   ← aún exponencial pero mejor que 5^n
```

## 20.3 Cómo estimar el branching factor efectivo

```python
def estimar_branching(problema, instancias):
    """Mide cuántas opciones se prueban en promedio por nodo."""

    # Instrumentar el backtracking
    nodos = [0]
    opciones_probadas = [0]

    def medir_backtrack(estado):
        opciones = obtener_opciones(estado)
        opciones_probadas[0] += len(opciones)
        nodos[0] += 1

        for opcion in opciones:
            if es_valido(estado, opcion):
                nuevo_estado = aplicar(estado, opcion)
                medir_backtrack(nuevo_estado)

    medir_backtrack(estado_inicial)

    if nodos[0] > 0:
        b_efectivo = opciones_probadas[0] / nodos[0]
        return b_efectivo
```

## 20.4 Tabla de complejidades por problema

| Problema                | Peor caso    | Con poda                | Realidad              |
| ----------------------- | ------------ | ----------------------- | --------------------- |
| **Permutaciones**       | O(n!)        | O(n!) (no se puede podar fácilmente) | O(n!) |
| **Subset Sum**          | O(2ⁿ)        | O(2ⁿ) si nums > target   | O(n·target) con DP    |
| **N-Queens**            | O(n!)        | O(n!) pero con factor < 1 | < 1 ms para n ≤ 14  |
| **Sudoku**              | O(9^m)       | O(9^m) pero m ≪ 81 real  | < 100 ms típico       |
| **Word Search**         | O(m·n·4^L)   | depende de la palabra    | < 1 ms para L < 10   |
| **Knight's Tour**       | O(8^(n²))    | O(n²) con Warnsdorff     | < 1 ms con heurística |
| **M-Coloring**          | O(M^V)       | O(M^V) pero M pequeño   | segundos para V ≤ 20  |

## 20.5 Cuando backtracking es viable

```text
✅ VIABLE si:
    - n ≤ 20-25 con poda débil.
    - n ≤ 30-40 con poda fuerte.
    - n ≤ 50+ con buenas heurísticas.
    - Una sola instancia (no muchas).

❌ NO VIABLE si:
    - n > 50 sin poda fuerte.
    - Necesitas resolver millones de instancias.
    - El branching factor sigue siendo muy alto incluso con poda.

→ Considerar: DP, Branch & Bound con buenas cotas, o heurísticas/aproximaciones.
```

---

# 21. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                                      | Consecuencia                              |
| ---------------------------------------------------------- | ---------------------------------------- |
| **Olvidar el UNCHOOSE** (deshacer)                         | Estado contaminado → resultados incorrectos |
| **Caso base incorrecto** (off-by-one)                      | Faltan o sobran soluciones               |
| **Poda demasiado agresiva**                                | Eliminar la solución óptima              |
| **No podar NADA**                                          | Explorar todo = fuerza bruta pura         |
| **Recursión sin límite de profundidad**                    | Stack overflow en instancias grandes     |
| **Pasar el estado por referencia sin copia**               | Modificaciones afectan llamadas hermanas  |
| **Modificar el set/lista durante iteración**               | Iteración rota, soluciones perdidas      |
| **Copiar el estado en cada llamada**                       | O(n) extra por nodo → O(n·b^n) memoria/tiempo |
| **No ordenar las opciones**                                | Pierdes poda por orden                   |
| **Asumir que backtracking siempre encuentra la mejor**      | Requiere explorar todo O Branch & Bound   |

### ✅ Buenas Prácticas

| Práctica                                                   | Razón                                       |
| ---------------------------------------------------------- | ------------------------------------------- |
| **Empezar con brute force y luego agregar poda**          | Garantiza correctitud primero              |
| **Elegir el orden de exploración** (más restrictivo primero) | Poda más rápido                            |
| **MRV (Minimum Remaining Values)**: elegir el nodo con menos opciones | Poda temprano                              |
| **Reutilizar estructuras de datos** (boolean arrays en vez de sets) | Más rápido en C/C++                     |
| **Pasar referencias cuando es seguro**                     | Evitar copias innecesarias                 |
| **Versión iterativa** para árboles muy profundos           | Evitar stack overflow                      |
| **Aleatorizar el orden de exploración** si las instancias son difíciles | A veces poda más rápido           |
| **Limitar el tiempo de ejecución** (`signal.alarm`, `threading`) | Producción                                  |
| **Documentar la poda** con invariantes claras             | Mantenibilidad                             |
| **Probar con instancias pequeñas primero**                | Detectar bugs antes de optimizar           |

## 21.1 El checklist del "backtracking bien hecho"

```text
□ ¿Identifiqué las 3 componentes: CHOICE, CONSTRAINT, GOAL?
□ ¿Escribí el pseudocódigo con CHOOSE/EXPLORE/UNCHOOSE?
□ ¿Verifiqué el caso base?
□ ¿Probé con n = 2, 3, 4 (manualmente)?
□ ¿Implementé la poda más obvia?
□ ¿Medí el branching factor efectivo?
□ ¿Funciona dentro del tiempo esperado?
□ ¿La versión iterativa es necesaria (por stack overflow)?
□ ¿Tengo un test para verificar correctitud?
```

---

# 22. Intuición de Ingeniería

## 22.1 El diagrama de decisión

```text
                        ┌─────────────────────┐
                        │ ¿Cuál es mi         │
                        │  problema?          │
                        └──────────┬──────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
              ¿Óptimo?      ¿Todas las      ¿Una sola
                    │      soluciones?     solución?
                    │              │              │
                    ▼              ▼              ▼
              ¿Greedy       ¿Espacio      DP / Greedy
               funciona?     pequeño?
                    │              │              │
                    ▼              ▼              ▼
                  Sí:        Sí (n≤20):          Sí:
                  Greedy     Backtracking         (Sí)
                    │              │              │
                    ▼              ▼              ▼
                  No:         No:                No:
                  DP o        DP o               Aprox.
                  B&B
```

## 22.2 Tabla de decisión rápida

| Si tu problema es...                                  | Probablemente usa...        |
| ----------------------------------------------------- | --------------------------- |
| Generar **todas** las permutaciones / combinaciones   | **Backtracking**            |
| Encontrar **una** asignación válida                   | **Backtracking** (corte temprano) |
| Sudoku, N-Queens, laberintos                          | **Backtracking con poda**   |
| Suma de subconjuntos, mochila booleana                | **Backtracking o DP**       |
| TSP / Asignación (encontrar óptimo)                   | **Branch & Bound**          |
| Subproblemas traslapados                              | **DP**                      |
| Elección local obvia                                  | **Greedy**                  |
| `n` enorme, cualquier solución sirve                  | **Heurística / greedy**     |
| Subproblemas independientes                           | **Divide & Conquer**        |

## 22.3 Las 5 reglas mnemotécnicas de Backtracking

| Regla                              | Significado                                          |
| ---------------------------------- | ---------------------------------------------------- |
| **"CHOOSE-EXPLORE-UNCHOOSE"**      | El patrón sagrado; el UNCHOOSE es la clave          |
| **"Poda temprano, poda siempre"**  | Cada rama podada es tiempo ahorrado                  |
| **"Más restrictivo primero"**      | MRV reduce el árbol dramáticamente                   |
| **"Estado explícito"**             | No esconder el estado en closures / globales        |
| **"Mide el branching factor"**     | Sin medición, no sabes si la poda ayuda             |

## 22.4 Backtracking como caso particular de DFS

```text
DFS general (CLRS Cap. 22.1):
    - Recorre el grafo, sin poda.

Backtracking = DFS con poda:
    - Recorre un árbol (no grafo, no hay ciclos).
    - La poda corta subárboles completos.

Conexión con Divide & Conquer:
    - Ambos son recursivos.
    - D&C divide y combina; backtracking prueba y deshace.

Conexión con DP:
    - Si las llamadas se SOLAPAN (mismo estado visitado varias veces),
      backtracking se puede convertir en DP con memoización.
    - Ej: Fibonacci naïve (backtracking O(2ⁿ)) → DP O(n).
```

## 22.5 Backtracking ↔ DP: cuándo convertir

```text
Backtracking es preferible cuando:
    - Las llamadas NO se solapan (cada estado es único).
    - El espacio de búsqueda es acotado.
    - Se quieren TODAS las soluciones.

DP es preferible cuando:
    - Las llamadas SÍ se solapan.
    - El espacio de estados es grande pero con estructura.
    - Solo se quiere UNA solución óptima.

Truco de conversión:
    1. Escribe backtracking.
    2. Identifica qué estado se repite (memo key).
    3. Agrega memoización.
    4. Si quieres más velocidad, convierte a bottom-up.
```

## 22.6 Patrones donde backtracking gana + mundo real

| Patrón                                    | Ejemplos                           |
| ----------------------------------------- | ---------------------------------- |
| **Generación exhaustiva**                 | Permutaciones, combinaciones, strings |
| **Asignación con restricciones**          | N-Queens, M-Coloring, asignación   |
| **Camino en grafo implícito**             | Sudoku, Word Search, Maze, Knight  |
| **Sumas / conteo exacto**                 | Subset Sum, Partition              |
| **Encontrar TODAS las soluciones**        | "Lista todas..."                   |

**Aplicaciones reales:** Compiladores (register allocation), SAT solvers, planificación AI, bioinformática (sequence alignment), VLSI routing, criptoanálisis, rompecabezas (Sudoku, Rubik).

## 22.7 Conexión con otros temas del repositorio

| Tema                            | Conexión con Backtracking                |
| ------------------------------- | ----------------------------------------- |
| **Algorithms.md (sección 8)**   | Backtracking es una de las estrategias de diseño |
| **Sorting.md**                  | Bogo Sort es backtracking trivial       |
| **Divide&Conquer.md**           | Backtracking es D&C con poda             |
| **Greedy (en Algorithms.md)**   | Greedy es "backtracking sin backtrack"   |
| **DP**                          | DP es backtracking con memoización       |
| **BFS/DFS (CLRS Cap. 22.1)**    | Backtracking es DFS sobre árbol de decisión |

## 22.8 El principio unificador

> **Backtracking es la versión inteligente de "probar todo":**
>
> - **Pruebas todo lo que podría funcionar** (es exhaustivo).
> - **Descartas lo que no puede funcionar** (es eficiente).
> - **Reconstruyes paso a paso** (es constructivo).
> - **Y te das cuenta pronto si vas por mal camino** (es la poda).
>
> Cuando un problema tiene una estructura combinatoria
> y necesitas **explorar muchas posibilidades con restricciones claras**,
> **backtracking es casi siempre la respuesta correcta**.

---

## Referencias

- **CLRS** — Cormen, Leiserson, Rivest, Stein. *Introduction to Algorithms* (4ª ed.).
  - **Capítulo 22.1** (BFS/DFS): bases de backtracking como DFS con poda.
  - **Capítulo 2** (ejercicios): N-Queens, Subset Sum como ejemplos introductorios.
  - **Capítulo 34** (NP-completitud): muchos problemas de backtracking son NP-completos.
- **Algorithms.md** en este repositorio — estrategias de diseño de algoritmos.
- **Divide&Conquer.md** en este repositorio — conexión entre D&C y backtracking.
- **Sorting.md** en este repositorio — base algorítmica general.
- **LeetCode / HackerRank** — banco masivo de problemas de backtracking (N-Queens, Sudoku, Word Search, Combination Sum, etc.).