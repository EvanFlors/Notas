# Matrices — Arrays Multidimensionales

> **Idea central:** La memoria es siempre **lineal**. La multidimensionalidad es una **abstracción**.
> El poder real está en **cómo mapeas** una estructura lógica 2D a un bloque 1D de memoria.

---

## Tabla de Contenidos

1. [Fundamentos](#1-fundamentos)
2. [Tipos de Matrices Especiales](#2-tipos-de-matrices-especiales)
3. [Mapeo en Memoria](#3-mapeo-en-memoria)
4. [Operaciones Fundamentales](#4-operaciones-fundamentales)
5. [Diagonal Matrix — Implementación](#5-diagonal-matrix)
6. [Lower Triangular — Row Major](#6-lower-triangular--row-major)
7. [Upper Triangular — Row Major](#7-upper-triangular--row-major)
8. [Lower Triangular — Column Major](#8-lower-triangular--column-major)
9. [Upper Triangular — Column Major](#9-upper-triangular--column-major)
10. [Symmetric Matrix](#10-symmetric-matrix)
11. [Tri-Diagonal Matrix](#11-tri-diagonal-matrix)
12. [Tri-Band Matrix](#12-tri-band-matrix)
13. [Toeplitz Matrix](#13-toeplitz-matrix)
14. [Comparación de Mapeos](#14-comparación-de-mapeos)
15. [Complejidad](#15-complejidad)
16. [Errores Comunes y Buenas Prácticas](#16-errores-comunes-y-buenas-prácticas)
17. [Intuición de Ingeniería](#17-intuición-de-ingeniería)

---

# 1. Fundamentos

## 1.1 ¿Qué es una matriz?

Una **matriz** es un arreglo de **dos o más dimensiones** que organiza datos en **filas** y **columnas**.

```c
int A[3][4];   // 3 filas × 4 columnas
```

```text
         Col 0  Col 1  Col 2  Col 3
        ┌──────┬──────┬──────┬──────┐
Fila 0  │   1  │   2  │   3  │   4  │
        ├──────┼──────┼──────┼──────┤
Fila 1  │   5  │   6  │   7  │   8  │
        ├──────┼──────┼──────┼──────┤
Fila 2  │   9  │  10  │  11  │  12  │
        └──────┴──────┴──────┴──────┘
```

## 1.2 Relación con arrays 1D

Una matriz **NO es más** que un array lineal **interpretado en 2D**:

```text
Lógico (2D):        [ 1  2  3  4 ]       Físico (1D):
                     [ 5  6  7  8 ]   →   [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
                     [ 9 10 11 12 ]
```

La diferencia es **cómo interpretas los índices**.

## 1.3 Estructura lógica vs física

| Nivel  | Descripción                          |
| ------ | ------------------------------------ |
| Lógica | Filas y columnas (cómo lo piensas)   |
| Física | Bloque contiguo de memoria (la RAM)  |

---

# 2. Tipos de Matrices Especiales

Cada tipo explota un **patrón de ceros** para ahorrar memoria.

### Diagonal

Solo la diagonal principal tiene valores → **espacio: `n`**

```text
[ d  0  0 ]        Almacenas: [d, d, d]
[ 0  d  0 ]        Condición: i == j
[ 0  0  d ]
```

### Lower Triangular (Triangular Inferior)

Valores solo donde `i ≥ j` → **espacio: `n(n+1)/2`**

```text
[ x  0  0 ]
[ x  x  0 ]
[ x  x  x ]
```

### Upper Triangular (Triangular Superior)

Valores solo donde `i ≤ j` → **espacio: `n(n+1)/2`**

```text
[ x  x  x ]
[ 0  x  x ]
[ 0  0  x ]
```

### Symmetric (Simétrica)

`A[i][j] == A[j][i]` → almacenas solo **media matriz** → **espacio: `n(n+1)/2`**

```text
[ x  y  z ]        A[0][1] = y = A[1][0]
[ y  x  w ]        A[0][2] = z = A[2][0]
[ z  w  x ]        A[1][2] = w = A[2][1]
```

### Tri-Diagonal

Valores solo donde `|i - j| ≤ 1` → **espacio: `3n - 2`**

```text
[ x  x  0  0 ]     3 bandas: inferior, principal, superior
[ x  x  x  0 ]
[ 0  x  x  x ]
[ 0  0  x  x ]
```

### Tri-Band (Banda `k`)

Generalización de tri-diagonal: valores donde `|i - j| ≤ k` → **espacio: `~(2k+1)n`**

```text
[ x  x  x  0 ]     k = 2 en este ejemplo
[ x  x  x  x ]
[ x  x  x  x ]
[ 0  x  x  x ]
```

### Toeplitz

Cada diagonal descendente tiene el mismo valor: `A[i][j] == A[i-1][j-1]` → **espacio: `2n - 1`**

```text
[ a  b  c  d ]     Solo necesitas: primera fila + primera columna
[ e  a  b  c ]     = n + (n-1) = 2n - 1 valores
[ f  e  a  b ]
[ g  f  e  a ]
```

---

# 3. Mapeo en Memoria

> **Problema:** La memoria es 1D, pero la matriz es 2D.
> **Solución:** Una fórmula que convierte `(i, j)` → dirección lineal.

## 3.1 Row-Major Order (fila por fila)

```text
Matriz:                    Memoria:
┌─────────┐
│ 1  2  3 │       →       [ 1, 2, 3, 4, 5, 6 ]
│ 4  5  6 │                 ─fila 0─  ─fila 1─
└─────────┘
```

**Fórmula:**
```text
Address(A[i][j]) = base + (i × n + j) × size
```

| Variable | Significado                       |
| -------- | --------------------------------- |
| `base`   | Dirección base del array          |
| `n`      | Número de **columnas**            |
| `size`   | Tamaño del tipo (ej: `int` = 4B) |

**Ejemplo:** `int A[2][3]`, acceder a `A[1][2]`:

```text
offset = 1 × 3 + 2 = 5    →    dirección = base + 5 × 4
```

## 3.2 Column-Major Order (columna por columna)

```text
Matriz:                    Memoria:
┌─────────┐
│ 1  2  3 │       →       [ 1, 4, 2, 5, 3, 6 ]
│ 4  5  6 │                 ─c0─  ─c1─  ─c2─
└─────────┘
```

**Fórmula:**
```text
Address(A[i][j]) = base + (j × m + i) × size
```

| Variable | Significado            |
| -------- | ---------------------- |
| `m`      | Número de **filas**    |

## 3.3 Lower Triangular Mapping (Row-Major)

**Elementos almacenados:** `n(n+1)/2`

```text
Lógica:          Memoria (Row-Major):
[ a  ·  · ]
[ b  c  · ]  →   [ a, b, c, d, e, f ]
[ d  e  f ]
```

**Fórmula** (cuando `i ≥ j`):
```text
Index = i×(i+1)/2 + j
```

**Ejemplo:** Matriz 3×3

```text
[1 0 0]
[2 3 0]   →   Array = [1, 2, 3, 4, 5, 6]
[4 5 6]

A[2][1] → Index = 2×3/2 + 1 = 4   →   Array[4] = 5 ✓
```

## 3.4 Upper Triangular Mapping (Row-Major)

**Elementos almacenados:** `n(n+1)/2`

**Fórmula** (cuando `i ≤ j`):
```text
Index = i×n - i×(i-1)/2 + (j - i)
```

**Fórmula alternativa** (Column-Major):
```text
Index = j×(j+1)/2 + i
```

**Ejemplo:** Matriz 3×3

```text
[1 2 4]
[0 3 5]   →   Array = [1, 2, 4, 3, 5, 6]
[0 0 6]

A[0][2] → Index = 0×3 - 0 + (2 - 0) = 2   →   Array[2] = 4 ✓
```

---

# 4. Operaciones Fundamentales

| Operación  | Código               | Complejidad |
| ---------- | -------------------- | ----------- |
| **Create** | `int A[3][3];`       | O(1)        |
| **Insert** | `A[1][2] = 10;`      | O(1)        |
| **Access** | `int x = A[1][2];`   | O(1)        |
| **Update** | `A[1][2] = 20;`      | O(1)        |

**Display** — O(n × m):

```c
void display(int A[][3], int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%d ", A[i][j]);
        }
        printf("\n");
    }
}
```

---

# 5. Diagonal Matrix

| Propiedad | Valor              |
| --------- | ------------------ |
| Condición | `i == j`           |
| Espacio   | `n`                |
| Mapeo     | `Index = i`        |

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int n;
    int *A;
} Diagonal;

Diagonal* createDiagonal(int n) {
    Diagonal* d = malloc(sizeof(Diagonal));
    d->n = n;
    d->A = calloc(n, sizeof(int));
    return d;
}

void setDiagonal(Diagonal* d, int i, int j, int val) {
    if (i == j)
        d->A[i] = val;
}

int getDiagonal(Diagonal* d, int i, int j) {
    if (i == j)
        return d->A[i];
    return 0;
}

void displayDiagonal(Diagonal* d) {
    for (int i = 0; i < d->n; i++) {
        for (int j = 0; j < d->n; j++) {
            printf("%d ", (i == j) ? d->A[i] : 0);
        }
        printf("\n");
    }
}
```

---

# 6. Lower Triangular — Row Major

| Propiedad | Valor                    |
| --------- | ------------------------ |
| Condición | `i ≥ j`                  |
| Espacio   | `n(n+1)/2`               |
| Mapeo     | `Index = i(i+1)/2 + j`   |

```c
typedef struct {
    int n;
    int *A;
} LowerRow;

LowerRow* createLowerRow(int n) {
    LowerRow* m = malloc(sizeof(LowerRow));
    m->n = n;
    m->A = calloc(n * (n + 1) / 2, sizeof(int));
    return m;
}

void setLowerRow(LowerRow* m, int i, int j, int val) {
    if (i >= j)
        m->A[i * (i + 1) / 2 + j] = val;
}

int getLowerRow(LowerRow* m, int i, int j) {
    if (i >= j)
        return m->A[i * (i + 1) / 2 + j];
    return 0;
}
```

---

# 7. Upper Triangular — Row Major

| Propiedad | Valor                              |
| --------- | ---------------------------------- |
| Condición | `i ≤ j`                            |
| Espacio   | `n(n+1)/2`                         |
| Mapeo     | `Index = i·n - i(i-1)/2 + (j - i)` |

```c
typedef struct {
    int n;
    int *A;
} UpperRow;

UpperRow* createUpperRow(int n) {
    UpperRow* m = malloc(sizeof(UpperRow));
    m->n = n;
    m->A = calloc(n * (n + 1) / 2, sizeof(int));
    return m;
}

void setUpperRow(UpperRow* m, int i, int j, int val) {
    if (i <= j)
        m->A[i * m->n - i * (i - 1) / 2 + (j - i)] = val;
}

int getUpperRow(UpperRow* m, int i, int j) {
    if (i <= j)
        return m->A[i * m->n - i * (i - 1) / 2 + (j - i)];
    return 0;
}
```

---

# 8. Lower Triangular — Column Major

| Propiedad | Valor                              |
| --------- | ---------------------------------- |
| Condición | `i ≥ j`                            |
| Espacio   | `n(n+1)/2`                         |
| Mapeo     | `Index = j·n - j(j-1)/2 + (i - j)` |

```c
typedef struct {
    int n;
    int *A;
} LowerCol;

LowerCol* createLowerCol(int n) {
    LowerCol* m = malloc(sizeof(LowerCol));
    m->n = n;
    m->A = calloc(n * (n + 1) / 2, sizeof(int));
    return m;
}

void setLowerCol(LowerCol* m, int i, int j, int val) {
    if (i >= j)
        m->A[j * m->n - j * (j - 1) / 2 + (i - j)] = val;
}

int getLowerCol(LowerCol* m, int i, int j) {
    if (i >= j)
        return m->A[j * m->n - j * (j - 1) / 2 + (i - j)];
    return 0;
}
```

---

# 9. Upper Triangular — Column Major

| Propiedad | Valor                    |
| --------- | ------------------------ |
| Condición | `i ≤ j`                  |
| Espacio   | `n(n+1)/2`               |
| Mapeo     | `Index = j(j+1)/2 + i`   |

```c
typedef struct {
    int n;
    int *A;
} UpperCol;

UpperCol* createUpperCol(int n) {
    UpperCol* m = malloc(sizeof(UpperCol));
    m->n = n;
    m->A = calloc(n * (n + 1) / 2, sizeof(int));
    return m;
}

void setUpperCol(UpperCol* m, int i, int j, int val) {
    if (i <= j)
        m->A[j * (j + 1) / 2 + i] = val;
}

int getUpperCol(UpperCol* m, int i, int j) {
    if (i <= j)
        return m->A[j * (j + 1) / 2 + i];
    return 0;
}
```

---

# 10. Symmetric Matrix

| Propiedad   | Valor                                |
| ----------- | ------------------------------------ |
| Condición   | `A[i][j] == A[j][i]`                |
| Estrategia  | Almacenar solo triangular inferior   |
| Espacio     | `n(n+1)/2`                           |

**Mapeo:**
- Si `i ≥ j` → `Index = i(i+1)/2 + j`
- Si `i < j` → usar `A[j][i]`

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int n;
    int *A;
} Symmetric;

Symmetric* createSymmetric(int n) {
    Symmetric* m = malloc(sizeof(Symmetric));
    m->n = n;
    m->A = calloc(n * (n + 1) / 2, sizeof(int));
    return m;
}

void setSymmetric(Symmetric* m, int i, int j, int val) {
    if (i >= j)
        m->A[i * (i + 1) / 2 + j] = val;
    else
        m->A[j * (j + 1) / 2 + i] = val;
}

int getSymmetric(Symmetric* m, int i, int j) {
    if (i >= j)
        return m->A[i * (i + 1) / 2 + j];
    else
        return m->A[j * (j + 1) / 2 + i];
}

void displaySymmetric(Symmetric* m) {
    for (int i = 0; i < m->n; i++) {
        for (int j = 0; j < m->n; j++)
            printf("%d ", getSymmetric(m, i, j));
        printf("\n");
    }
}
```

---

# 11. Tri-Diagonal Matrix

| Propiedad  | Valor                                        |
| ---------- | -------------------------------------------- |
| Condición  | `|i - j| ≤ 1`                               |
| Espacio    | `3n - 2`                                     |
| Estrategia | 3 arrays: lower (`n-1`), diag (`n`), upper (`n-1`) |

```text
Bandas:
                 upper[0]  upper[1]  upper[2]
                    ↓         ↓         ↓
          ┌──────┬──────┬──────┬──────┐
          │ d[0] │ u[0] │   0  │   0  │
          │ l[0] │ d[1] │ u[1] │   0  │
          │   0  │ l[1] │ d[2] │ u[2] │
          │   0  │   0  │ l[2] │ d[3] │
          └──────┴──────┴──────┴──────┘
            ↑         ↑         ↑
         diag[0]   diag[1]   lower[2]
```

```c
typedef struct {
    int n;
    int *lower;  // n-1 elementos
    int *diag;   // n   elementos
    int *upper;  // n-1 elementos
} TriDiagonal;

TriDiagonal* createTriDiagonal(int n) {
    TriDiagonal* m = malloc(sizeof(TriDiagonal));
    m->n = n;
    m->lower = calloc(n - 1, sizeof(int));
    m->diag  = calloc(n, sizeof(int));
    m->upper = calloc(n - 1, sizeof(int));
    return m;
}

void setTriDiagonal(TriDiagonal* m, int i, int j, int val) {
    if (i - j == 1)       m->lower[j] = val;    // banda inferior
    else if (i == j)      m->diag[i]  = val;    // diagonal principal
    else if (j - i == 1)  m->upper[i] = val;    // banda superior
}

int getTriDiagonal(TriDiagonal* m, int i, int j) {
    if (i - j == 1)       return m->lower[j];
    else if (i == j)      return m->diag[i];
    else if (j - i == 1)  return m->upper[i];
    return 0;
}
```

---

# 12. Tri-Band Matrix

| Propiedad  | Valor                                     |
| ---------- | ----------------------------------------- |
| Condición  | `|i - j| ≤ k`                            |
| Espacio    | `(2k + 1)n - k(k + 1)`                   |
| Estrategia | Array 2D comprimido: `band[2k+1][n]`     |

> Es la **generalización** de la tri-diagonal (tri-diagonal = tri-band con `k = 1`).

```c
#include <stdlib.h>

typedef struct {
    int n;
    int k;
    int **band;
} TriBand;

TriBand* createTriBand(int n, int k) {
    TriBand* m = malloc(sizeof(TriBand));
    m->n = n;
    m->k = k;
    m->band = malloc((2 * k + 1) * sizeof(int*));
    for (int i = 0; i < 2 * k + 1; i++)
        m->band[i] = calloc(n, sizeof(int));
    return m;
}

void setTriBand(TriBand* m, int i, int j, int val) {
    if (abs(i - j) <= m->k)
        m->band[m->k + i - j][j] = val;
}

int getTriBand(TriBand* m, int i, int j) {
    if (abs(i - j) <= m->k)
        return m->band[m->k + i - j][j];
    return 0;
}
```

---

# 13. Toeplitz Matrix

| Propiedad  | Valor                                     |
| ---------- | ----------------------------------------- |
| Condición  | `A[i][j] == A[i-1][j-1]`                 |
| Espacio    | `2n - 1`                                  |
| Estrategia | Primera fila (`n`) + primera columna sin repetir `A[0][0]` (`n-1`) |

```text
Mapeo:

          Índices del array A[]:
            0    1    2    3        ← primera fila (i ≤ j)
          ┌────┬────┬────┬────┐
          │ a  │ b  │ c  │ d  │     A[j - i]
          │ e  │ a  │ b  │ c  │
          │ f  │ e  │ a  │ b  │
          │ g  │ f  │ e  │ a  │
          └────┴────┴────┴────┘
            4    5    6             ← primera columna (i > j)
                                      A[n + i - j - 1]
```

```c
typedef struct {
    int n;
    int *A;
} Toeplitz;

Toeplitz* createToeplitz(int n) {
    Toeplitz* m = malloc(sizeof(Toeplitz));
    m->n = n;
    m->A = calloc(2 * n - 1, sizeof(int));
    return m;
}

void setToeplitz(Toeplitz* m, int i, int j, int val) {
    if (i <= j)
        m->A[j - i] = val;            // parte superior + diagonal
    else
        m->A[m->n + i - j - 1] = val; // parte inferior
}

int getToeplitz(Toeplitz* m, int i, int j) {
    if (i <= j)
        return m->A[j - i];
    else
        return m->A[m->n + i - j - 1];
}
```

---

# 14. Comparación de Mapeos

### Fórmulas de Acceso

| Tipo             | Fórmula de índice                        |
| ---------------- | ---------------------------------------- |
| Completa         | `i × n + j`                             |
| Lower Row-Major  | `i(i+1)/2 + j`                          |
| Upper Row-Major  | `i·n - i(i-1)/2 + (j - i)`              |
| Lower Col-Major  | `j·n - j(j-1)/2 + (i - j)`              |
| Upper Col-Major  | `j(j+1)/2 + i`                          |
| Simétrica        | Igual que triangular inferior/superior   |
| Tri-diagonal     | 3 arrays separados                       |
| Tri-band (k)     | `band[k + i - j][j]`                    |
| Toeplitz         | `j - i` (superior) / `n + i - j - 1` (inferior) |

### Uso de Memoria

| Tipo             | Espacio      | Ahorro vs `n²`         |
| ---------------- | ------------ | ----------------------- |
| Completa         | `n²`         | —                       |
| Triangular       | `n(n+1)/2`   | **~50%**                |
| Tri-diagonal     | `3n - 2`     | **~97%** (para n grande)|
| Tri-band (k)     | `~(2k+1)n`   | Depende de k            |
| Toeplitz         | `2n - 1`     | **~98%** (para n grande)|

---

# 15. Complejidad

| Operación   | Complejidad | Nota                                     |
| ----------- | ----------- | ---------------------------------------- |
| **Access**  | O(1)        | Acceso directo por fórmula de mapeo      |
| **Update**  | O(1)        | Escritura directa por fórmula de mapeo   |
| **Display** | O(n²)       | Recorrer todos los elementos lógicos     |

---

# 16. Errores Comunes y Buenas Prácticas

### Errores Comunes

| Error                                  | Consecuencia                          |
| -------------------------------------- | ------------------------------------- |
| Confundir índices 0-based vs 1-based   | Fórmula incorrecta                    |
| Usar fórmula Row-Major en Column-Major | Acceso a posición incorrecta          |
| No validar `i ≥ j` o `i ≤ j`          | Escritura fuera del array comprimido  |
| Olvidar liberar memoria (`free`)       | Memory leak                           |
| Index out of bounds                    | Comportamiento indefinido (UB)        |

### Buenas Prácticas

| Práctica                             | Razón                                  |
| ------------------------------------ | -------------------------------------- |
| Encapsular lógica en funciones       | Claridad y reutilización               |
| Validar índices antes de acceder     | Evitar UB                              |
| Documentar qué fórmula se usa        | Evitar confusiones Row vs Column       |
| Usar `calloc` en vez de `malloc`     | Inicialización en 0 automática         |
| Usar `typedef struct` para claridad  | Código más legible                     |

---

# 17. Intuición de Ingeniería

> El verdadero poder no está en la matriz, sino en **cómo la representas**.

Si dominas estos mapeos:
- **Reduces memoria** drásticamente (50–98%)
- **Mantienes acceso O(1)** sin sacrificar velocidad
- **Escalas** sistemas grandes eficientemente

### ¿Dónde aparecen estas matrices?

| Área                          | Tipo de matriz     | Ejemplo                            |
| ----------------------------- | ------------------ | ---------------------------------- |
| **Machine Learning**          | Simétrica          | Matrices de covarianza             |
| **Simulación física**         | Tri-diagonal       | Ecuaciones diferenciales (FDM)     |
| **Procesamiento de señales**  | Toeplitz           | Convolución, filtros               |
| **Sistemas numéricos**        | Band matrices      | Métodos de elementos finitos (FEM) |
| **Grafos**                    | Simétrica/Sparse   | Matrices de adyacencia optimizadas |
