# Sparse Matrices & Polynomials — Representaciones Compactas

> **Idea central:** Cuando una estructura tiene **más vacío que datos**, almacenarla completa es un desperdicio absurdo.
> Las matrices dispersas y los polinomios dispersos nos obligan a pensar en **qué almacenamos** y no solo en **cómo** lo almacenamos.
> La clave: representar **solo lo que importa** — los elementos no nulos.

---

## Tabla de Contenidos

1. [El Problema: ¿Por Qué Representaciones Compactas?](#1-el-problema-por-qué-representaciones-compactas)
2. [Sparse Matrix — Concepto](#2-sparse-matrix--concepto)
3. [Formato Triplet (Coordinate / COO)](#3-formato-triplet-coordinate--coo)
4. [Compressed Sparse Row (CSR)](#4-compressed-sparse-row-csr)
5. [Compressed Sparse Column (CSC)](#5-compressed-sparse-column-csc)
6. [Operaciones sobre Sparse Matrices](#6-operaciones-sobre-sparse-matrices)
7. [Polinomios — Representación con Arrays](#7-polinomios--representación-con-arrays)
8. [Evaluación de Polinomios](#8-evaluación-de-polinomios)
9. [Operaciones sobre Polinomios](#9-operaciones-sobre-polinomios)
10. [Resumen de Complejidad](#10-resumen-de-complejidad)
11. [Errores Comunes y Buenas Prácticas](#11-errores-comunes-y-buenas-prácticas)
12. [Intuición de Ingeniería](#12-intuición-de-ingeniería)

---

# 1. El Problema: ¿Por Qué Representaciones Compactas?

## 1.1 Desperdicio de memoria

Considera una matriz 1000 × 1000 con solo 50 elementos no nulos:

```text
Almacenamiento completo:    1000 × 1000 × 4 bytes = 4,000,000 bytes (≈ 4 MB)
Elementos útiles:           50 × 4 bytes            = 200 bytes
Desperdicio:                99.995% del espacio
```

> **4 MB para guardar 200 bytes de información útil.** Eso es inaceptable.

## 1.2 Desperdicio de tiempo

Operaciones como la suma de dos matrices 1000 × 1000:

```text
Forma ingenua:   1000 × 1000 = 1,000,000 sumas   (incluye 999,950 sumas de 0 + 0)
Forma compacta:  solo sumar los ≤ 100 elementos no nulos
```

## 1.3 ¿Cuándo una matriz es "dispersa"?

| Densidad                           | Clasificación     | Representación recomendada |
| ---------------------------------- | ----------------- | -------------------------- |
| > 30% no nulos                     | **Densa**         | Array 2D tradicional       |
| 1–30% no nulos                     | **Dispersa**      | Triplet, CSR, CSC          |
| < 1% no nulos                      | **Muy dispersa**  | CSR / CSC / listas         |

> **Factor de dispersión** (sparsity) = `nº de ceros / (filas × columnas)`

---

# 2. Sparse Matrix — Concepto

## 2.1 Definición

Una **sparse matrix** (matriz dispersa) es una matriz donde la **mayoría** de los elementos son **cero**.

```text
Ejemplo: Matriz 5×6 con 6 elementos no nulos

         Col 0  Col 1  Col 2  Col 3  Col 4  Col 5
        ┌──────┬──────┬──────┬──────┬──────┬──────┐
Fila 0  │   0  │   0  │  15  │   0  │   0  │   0  │
        ├──────┼──────┼──────┼──────┼──────┼──────┤
Fila 1  │   0  │  22  │   0  │   0  │  11  │   0  │
        ├──────┼──────┼──────┼──────┼──────┼──────┤
Fila 2  │   0  │   0  │   0  │   6  │   0  │   0  │
        ├──────┼──────┼──────┼──────┼──────┼──────┤
Fila 3  │  91  │   0  │   0  │   0  │   0  │  28  │
        ├──────┼──────┼──────┼──────┼──────┼──────┤
Fila 4  │   0  │   0  │   0  │   0  │   0  │   0  │
        └──────┴──────┴──────┴──────┴──────┴──────┘

Total de elementos: 5 × 6 = 30
No nulos (nnz):     6
Sparsity:           24/30 = 80%
```

## 2.2 ¿Dónde aparecen?

| Dominio                      | Ejemplo                                     |
| ---------------------------- | ------------------------------------------- |
| Grafos                       | Matriz de adyacencia (la mayoría sin aristas)|
| Machine Learning             | Matrices de features con muchos ceros        |
| Procesamiento de texto       | Bag-of-words / TF-IDF                        |
| Ecuaciones diferenciales     | Matrices de discretización                   |
| Redes sociales               | Matrices usuario-producto                    |

---

# 3. Formato Triplet (Coordinate / COO)

## 3.1 Idea

Almacenar **solo los elementos no nulos** como tripletas `(fila, columna, valor)`.

```text
Matriz original (5×6):

     0   0  15   0   0   0
     0  22   0   0  11   0
     0   0   0   6   0   0
    91   0   0   0   0  28
     0   0   0   0   0   0

Representación Triplet:

Índice │ Fila │ Col │ Valor
───────┼──────┼─────┼───────
  0    │  0   │  2  │  15
  1    │  1   │  1  │  22
  2    │  1   │  4  │  11
  3    │  2   │  3  │   6
  4    │  3   │  0  │  91
  5    │  3   │  5  │  28
```

## 3.2 Estructura de datos

```c
typedef struct {
    int row;
    int col;
    int val;
} Element;

typedef struct {
    int rows;       // filas de la matriz original
    int cols;       // columnas de la matriz original
    int nnz;        // número de no-nulos (non-zeros)
    Element *data;  // array de tripletas
} SparseTriplet;
```

## 3.3 Análisis de espacio

| Representación | Espacio                          | Ejemplo (5×6, nnz=6)    |
| -------------- | -------------------------------- | ------------------------ |
| Densa          | `rows × cols × sizeof(int)`     | 30 × 4 = **120 bytes**  |
| Triplet        | `nnz × 3 × sizeof(int) + meta`  | 6 × 12 + 12 = **84 bytes** |

**¿Cuándo conviene?** Triplet ahorra espacio cuando:

```text
nnz × 3 < rows × cols
nnz < (rows × cols) / 3
```

> Para nuestra matriz 5×6: `nnz < 10` → con 6 no-nulos, **sí conviene**.

## 3.4 Implementación completa

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int row;
    int col;
    int val;
} Element;

typedef struct {
    int rows;
    int cols;
    int nnz;
    Element *data;
} SparseTriplet;

// --- Crear desde matriz densa ---
SparseTriplet* createFromDense(int A[][6], int rows, int cols) {
    // Contar no-nulos
    int nnz = 0;
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            if (A[i][j] != 0)
                nnz++;

    SparseTriplet *S = malloc(sizeof(SparseTriplet));
    S->rows = rows;
    S->cols = cols;
    S->nnz = nnz;
    S->data = malloc(nnz * sizeof(Element));

    int k = 0;
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            if (A[i][j] != 0) {
                S->data[k].row = i;
                S->data[k].col = j;
                S->data[k].val = A[i][j];
                k++;
            }

    return S;
}

// --- Mostrar ---
void displayTriplet(SparseTriplet *S) {
    printf("Dimensiones: %d × %d, nnz = %d\n", S->rows, S->cols, S->nnz);
    printf("%-6s %-6s %-6s\n", "Row", "Col", "Val");
    printf("──────────────────\n");
    for (int i = 0; i < S->nnz; i++)
        printf("%-6d %-6d %-6d\n",
               S->data[i].row, S->data[i].col, S->data[i].val);
}

// --- Acceder a un elemento ---
int getElement(SparseTriplet *S, int r, int c) {
    for (int i = 0; i < S->nnz; i++)
        if (S->data[i].row == r && S->data[i].col == c)
            return S->data[i].val;
    return 0;   // no encontrado → es cero
}

// --- Liberar ---
void freeTriplet(SparseTriplet *S) {
    free(S->data);
    free(S);
}
```

## 3.5 Transponer en Triplet

La **transpuesta** intercambia filas y columnas: `A[i][j] → Aᵀ[j][i]`.

```text
Original:                    Transpuesta:
Row  Col  Val                Row  Col  Val
 0    2   15                  0    3   91
 1    1   22                  1    1   22
 1    4   11                  2    0   15
 2    3    6                  3    2    6
 3    0   91                  4    1   11
 3    5   28                  5    3   28
```

```c
SparseTriplet* transpose(SparseTriplet *S) {
    SparseTriplet *T = malloc(sizeof(SparseTriplet));
    T->rows = S->cols;      // filas ← columnas originales
    T->cols = S->rows;      // columnas ← filas originales
    T->nnz = S->nnz;
    T->data = malloc(T->nnz * sizeof(Element));

    // Intercambiar row ↔ col
    for (int i = 0; i < S->nnz; i++) {
        T->data[i].row = S->data[i].col;
        T->data[i].col = S->data[i].row;
        T->data[i].val = S->data[i].val;
    }

    // Ordenar por fila (para mantener row-major order)
    // Usando counting sort por columna original
    // (Omitido por brevedad — ver Fast Transpose abajo)

    return T;
}
```

| Método                | Complejidad      | Nota                                   |
| --------------------- | ---------------- | -------------------------------------- |
| Transpuesta simple    | O(nnz)           | No ordena — resultado desordenado      |
| Transpuesta ordenada  | O(nnz × cols)    | Recorre cols veces                     |
| Fast Transpose        | O(nnz + cols)    | Counting sort — **óptimo**             |

### Fast Transpose (Counting Sort)

```c
SparseTriplet* fastTranspose(SparseTriplet *S) {
    SparseTriplet *T = malloc(sizeof(SparseTriplet));
    T->rows = S->cols;
    T->cols = S->rows;
    T->nnz = S->nnz;
    T->data = malloc(T->nnz * sizeof(Element));

    // Paso 1: contar cuántos elementos hay en cada columna de S
    int *count = calloc(S->cols, sizeof(int));
    for (int i = 0; i < S->nnz; i++)
        count[S->data[i].col]++;

    // Paso 2: calcular posición inicial de cada fila en T
    int *pos = malloc(S->cols * sizeof(int));
    pos[0] = 0;
    for (int i = 1; i < S->cols; i++)
        pos[i] = pos[i - 1] + count[i - 1];

    // Paso 3: colocar cada elemento en su posición correcta
    for (int i = 0; i < S->nnz; i++) {
        int j = pos[S->data[i].col]++;
        T->data[j].row = S->data[i].col;
        T->data[j].col = S->data[i].row;
        T->data[j].val = S->data[i].val;
    }

    free(count);
    free(pos);
    return T;
}
```

```text
Ejemplo paso a paso — Fast Transpose:

S original (filas=5, cols=6):
  (0,2,15) (1,1,22) (1,4,11) (2,3,6) (3,0,91) (3,5,28)

Paso 1 — count[col]:
  col:   0   1   2   3   4   5
  cnt:   1   1   1   1   1   1

Paso 2 — pos[col] (posición acumulada):
  col:   0   1   2   3   4   5
  pos:   0   1   2   3   4   5

Paso 3 — colocar en T:
  (3,0,91) → pos[0]=0 → T[0] = (0,3,91)
  (1,1,22) → pos[1]=1 → T[1] = (1,1,22)
  (0,2,15) → pos[2]=2 → T[2] = (2,0,15)
  (2,3, 6) → pos[3]=3 → T[3] = (3,2, 6)
  (1,4,11) → pos[4]=4 → T[4] = (4,1,11)
  (3,5,28) → pos[5]=5 → T[5] = (5,3,28)

Resultado T (filas=6, cols=5, ordenado por fila ✓):
  (0,3,91) (1,1,22) (2,0,15) (3,2,6) (4,1,11) (5,3,28)
```

---

# 4. Compressed Sparse Row (CSR)

## 4.1 El problema del Triplet

El formato Triplet almacena la fila de **cada** elemento. Si hay muchos elementos en la misma fila, se repite el número de fila innecesariamente.

```text
Triplet:              Repetición:
Row  Col  Val
 3    0   91          fila 3 aparece 2 veces
 3    5   28          fila 3 aparece 2 veces  ← redundante
```

## 4.2 Idea del CSR

En lugar de almacenar la fila de cada elemento, almacenamos **dónde empieza cada fila** en el array de valores.

Usamos **3 arrays**:

| Array         | Tamaño       | Contenido                                    |
| ------------- | ------------ | -------------------------------------------- |
| `values[]`    | nnz          | Los valores no nulos                          |
| `colIndex[]`  | nnz          | La columna de cada valor                      |
| `rowPtr[]`    | rows + 1     | Índice en `values` donde empieza cada fila   |

## 4.3 Ejemplo detallado

```text
Matriz 5×6:

     0   0  15   0   0   0       ← fila 0: 1 elemento
     0  22   0   0  11   0       ← fila 1: 2 elementos
     0   0   0   6   0   0       ← fila 2: 1 elemento
    91   0   0   0   0  28       ← fila 3: 2 elementos
     0   0   0   0   0   0       ← fila 4: 0 elementos

values   = [ 15,  22,  11,   6,  91,  28 ]
colIndex = [  2,   1,   4,   3,   0,   5 ]
rowPtr   = [  0,   1,   3,   4,   6,   6 ]
             ↑    ↑    ↑    ↑    ↑    ↑
           fila0 fila1 fila2 fila3 fila4 centinela
```

### ¿Cómo leer los elementos de la fila `i`?

```text
Fila i tiene elementos desde rowPtr[i] hasta rowPtr[i+1] - 1

Fila 0: rowPtr[0]=0, rowPtr[1]=1 → values[0..0]   = { 15 }     en col { 2 }
Fila 1: rowPtr[1]=1, rowPtr[2]=3 → values[1..2]   = { 22, 11 } en col { 1, 4 }
Fila 2: rowPtr[2]=3, rowPtr[3]=4 → values[3..3]   = { 6 }      en col { 3 }
Fila 3: rowPtr[3]=4, rowPtr[4]=6 → values[4..5]   = { 91, 28 } en col { 0, 5 }
Fila 4: rowPtr[4]=6, rowPtr[5]=6 → values[vacío]  = { }        (fila vacía)
```

> El **centinela** `rowPtr[rows]` siempre es `nnz`. Permite iterar sin caso especial.

## 4.4 Estructura de datos

```c
typedef struct {
    int rows;
    int cols;
    int nnz;
    int *values;     // tamaño: nnz
    int *colIndex;   // tamaño: nnz
    int *rowPtr;     // tamaño: rows + 1
} SparseCSR;
```

## 4.5 Implementación

```c
// --- Crear CSR desde matriz densa ---
SparseCSR* createCSR(int A[][6], int rows, int cols) {
    // Contar no-nulos
    int nnz = 0;
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            if (A[i][j] != 0)
                nnz++;

    SparseCSR *S = malloc(sizeof(SparseCSR));
    S->rows = rows;
    S->cols = cols;
    S->nnz = nnz;
    S->values   = malloc(nnz * sizeof(int));
    S->colIndex = malloc(nnz * sizeof(int));
    S->rowPtr   = calloc(rows + 1, sizeof(int));

    int k = 0;
    for (int i = 0; i < rows; i++) {
        S->rowPtr[i] = k;
        for (int j = 0; j < cols; j++) {
            if (A[i][j] != 0) {
                S->values[k] = A[i][j];
                S->colIndex[k] = j;
                k++;
            }
        }
    }
    S->rowPtr[rows] = nnz;     // centinela

    return S;
}

// --- Acceder a un elemento ---
int getCSR(SparseCSR *S, int r, int c) {
    for (int k = S->rowPtr[r]; k < S->rowPtr[r + 1]; k++) {
        if (S->colIndex[k] == c)
            return S->values[k];
    }
    return 0;   // es cero
}

// --- Mostrar CSR ---
void displayCSR(SparseCSR *S) {
    printf("values   = [ ");
    for (int i = 0; i < S->nnz; i++) printf("%d ", S->values[i]);
    printf("]\n");

    printf("colIndex = [ ");
    for (int i = 0; i < S->nnz; i++) printf("%d ", S->colIndex[i]);
    printf("]\n");

    printf("rowPtr   = [ ");
    for (int i = 0; i <= S->rows; i++) printf("%d ", S->rowPtr[i]);
    printf("]\n");
}

// --- Liberar ---
void freeCSR(SparseCSR *S) {
    free(S->values);
    free(S->colIndex);
    free(S->rowPtr);
    free(S);
}
```

## 4.6 Análisis de espacio CSR vs Triplet

| Formato  | Espacio (enteros almacenados)     | Ejemplo (5×6, nnz=6)       |
| -------- | --------------------------------- | --------------------------- |
| Denso    | `rows × cols`                     | 30 enteros = **120 bytes**  |
| Triplet  | `3 × nnz`                         | 18 enteros = **72 bytes**   |
| CSR      | `2 × nnz + rows + 1`              | 12 + 6 = 18 ent. = **72 bytes** |

> Para pocas filas, CSR y Triplet son similares. CSR brilla con **muchas filas** y **nnz >> rows**.

---

# 5. Compressed Sparse Column (CSC)

## 5.1 Idea

Es lo **mismo que CSR pero orientado por columnas**. Útil cuando las operaciones predominantes acceden por columna.

| Array         | Tamaño       | Contenido                                    |
| ------------- | ------------ | -------------------------------------------- |
| `values[]`    | nnz          | Los valores no nulos (ordenados por columna) |
| `rowIndex[]`  | nnz          | La fila de cada valor                         |
| `colPtr[]`    | cols + 1     | Índice en `values` donde empieza cada columna |

## 5.2 Ejemplo

```text
Misma matriz 5×6:

     0   0  15   0   0   0
     0  22   0   0  11   0
     0   0   0   6   0   0
    91   0   0   0   0  28
     0   0   0   0   0   0

Recorrido por columnas:
  Col 0: (3,91)
  Col 1: (1,22)
  Col 2: (0,15)
  Col 3: (2,6)
  Col 4: (1,11)
  Col 5: (3,28)

values   = [ 91,  22,  15,   6,  11,  28 ]
rowIndex = [  3,   1,   0,   2,   1,   3 ]
colPtr   = [  0,   1,   2,   3,   4,   5,   6 ]
             ↑    ↑    ↑    ↑    ↑    ↑    ↑
           col0 col1 col2 col3 col4 col5 centinela
```

## 5.3 CSR vs CSC — ¿Cuándo usar cuál?

| Operación predominante                | Formato ideal |
| ------------------------------------- | ------------- |
| Iterar por filas (Ax = b)             | **CSR**       |
| Iterar por columnas                   | **CSC**       |
| Multiplicación matriz-vector          | **CSR**       |
| Transpuesta (sin copiar)              | CSR de A = CSC de Aᵀ |
| Acceso aleatorio                      | Ninguno es ideal (O(nnz_per_row/col)) |

---

# 6. Operaciones sobre Sparse Matrices

## 6.1 Suma de Sparse Matrices (Triplet)

Sumar dos matrices dispersas `A + B = C`.

**Algoritmo** (merge de dos listas ordenadas por fila, luego columna):

```text
A: (0,2,15) (1,1,22) (1,4,11) (2,3,6)
B: (0,2, 5) (1,1, 8) (2,0,3)  (2,3,4)

Recorrer A y B simultáneamente:
  A(0,2)=15 vs B(0,2)=5  → misma pos → C(0,2) = 15+5 = 20
  A(1,1)=22 vs B(1,1)=8  → misma pos → C(1,1) = 22+8 = 30
  A(1,4)=11 vs B(2,0)=3  → A menor   → C(1,4) = 11
  A(2,3)=6  vs B(2,0)=3  → B menor   → C(2,0) = 3
  A(2,3)=6  vs B(2,3)=4  → misma pos → C(2,3) = 6+4 = 10

C: (0,2,20) (1,1,30) (1,4,11) (2,0,3) (2,3,10)
```

> **Precondición:** Ambas tripletas deben estar **ordenadas** por (fila, columna).

```c
SparseTriplet* addTriplet(SparseTriplet *A, SparseTriplet *B) {
    if (A->rows != B->rows || A->cols != B->cols) {
        printf("Error: dimensiones incompatibles\n");
        return NULL;
    }

    // Máximo posible de no-nulos en C
    SparseTriplet *C = malloc(sizeof(SparseTriplet));
    C->rows = A->rows;
    C->cols = A->cols;
    C->data = malloc((A->nnz + B->nnz) * sizeof(Element));

    int i = 0, j = 0, k = 0;

    while (i < A->nnz && j < B->nnz) {
        int rA = A->data[i].row, cA = A->data[i].col;
        int rB = B->data[j].row, cB = B->data[j].col;

        if (rA < rB || (rA == rB && cA < cB)) {
            // Elemento solo en A
            C->data[k++] = A->data[i++];
        } else if (rA > rB || (rA == rB && cA > cB)) {
            // Elemento solo en B
            C->data[k++] = B->data[j++];
        } else {
            // Misma posición → sumar
            int sum = A->data[i].val + B->data[j].val;
            if (sum != 0) {   // ⚠️ solo agregar si no es cero
                C->data[k].row = rA;
                C->data[k].col = cA;
                C->data[k].val = sum;
                k++;
            }
            i++; j++;
        }
    }

    // Copiar restantes de A
    while (i < A->nnz)
        C->data[k++] = A->data[i++];

    // Copiar restantes de B
    while (j < B->nnz)
        C->data[k++] = B->data[j++];

    C->nnz = k;
    C->data = realloc(C->data, k * sizeof(Element));  // ajustar tamaño

    return C;
}
```

| Operación         | Complejidad        | Nota                              |
| ----------------- | ------------------ | --------------------------------- |
| Suma (Triplet)    | O(nnz_A + nnz_B)  | Merge de listas ordenadas         |
| Suma (Denso)      | O(rows × cols)     | Recorre todo, incluso los ceros   |

## 6.2 Suma de Sparse Matrices (CSR)

```c
SparseCSR* addCSR(SparseCSR *A, SparseCSR *B) {
    if (A->rows != B->rows || A->cols != B->cols) return NULL;

    // Estimar espacio máximo
    int maxNNZ = A->nnz + B->nnz;
    int *values   = malloc(maxNNZ * sizeof(int));
    int *colIndex = malloc(maxNNZ * sizeof(int));
    int *rowPtr   = calloc(A->rows + 1, sizeof(int));

    int k = 0;

    for (int i = 0; i < A->rows; i++) {
        rowPtr[i] = k;

        int pA = A->rowPtr[i], endA = A->rowPtr[i + 1];
        int pB = B->rowPtr[i], endB = B->rowPtr[i + 1];

        while (pA < endA && pB < endB) {
            if (A->colIndex[pA] < B->colIndex[pB]) {
                colIndex[k] = A->colIndex[pA];
                values[k++] = A->values[pA++];
            } else if (A->colIndex[pA] > B->colIndex[pB]) {
                colIndex[k] = B->colIndex[pB];
                values[k++] = B->values[pB++];
            } else {
                int sum = A->values[pA] + B->values[pB];
                if (sum != 0) {
                    colIndex[k] = A->colIndex[pA];
                    values[k++] = sum;
                }
                pA++; pB++;
            }
        }
        while (pA < endA) { colIndex[k] = A->colIndex[pA]; values[k++] = A->values[pA++]; }
        while (pB < endB) { colIndex[k] = B->colIndex[pB]; values[k++] = B->values[pB++]; }
    }
    rowPtr[A->rows] = k;

    SparseCSR *C = malloc(sizeof(SparseCSR));
    C->rows = A->rows;
    C->cols = A->cols;
    C->nnz = k;
    C->values   = realloc(values, k * sizeof(int));
    C->colIndex = realloc(colIndex, k * sizeof(int));
    C->rowPtr   = rowPtr;
    return C;
}
```

## 6.3 Multiplicación Matriz-Vector (CSR)

`y = A × x` donde A es sparse (CSR) y x es un vector denso.

```text
Para cada fila i:
  y[i] = Σ A[i][j] × x[j]   (solo para j no-nulos en fila i)
```

```c
void spMV_CSR(SparseCSR *A, int *x, int *y) {
    for (int i = 0; i < A->rows; i++) {
        y[i] = 0;
        for (int k = A->rowPtr[i]; k < A->rowPtr[i + 1]; k++) {
            y[i] += A->values[k] * x[A->colIndex[k]];
        }
    }
}
```

| Operación          | Denso            | CSR             |
| ------------------ | ---------------- | --------------- |
| Mat × Vec          | O(n²)            | **O(nnz)**      |
| Ahorro con 1% nnz | 1,000,000 ops    | **10,000 ops**  |

---

# 7. Polinomios — Representación con Arrays

## 7.1 ¿Qué es un polinomio?

Un **polinomio** es una suma de términos, cada uno con un **coeficiente** y un **exponente**:

```text
P(x) = 3x⁵ + 2x³ + 7x + 4

Términos: (3, x⁵), (2, x³), (7, x¹), (4, x⁰)
Grado:    5 (exponente máximo)
```

## 7.2 Representación 1: Array de coeficientes

Usar un array donde el **índice = exponente** y el **valor = coeficiente**.

```text
P(x) = 3x⁵ + 2x³ + 7x + 4

Índice (exponente):  0   1   2   3   4   5
Coeficiente:       [ 4,  7,  0,  2,  0,  3 ]
                     ↑              ↑       ↑
                    x⁰=4          x³=2    x⁵=3
```

```c
typedef struct {
    int *coeff;     // coeff[i] = coeficiente de x^i
    int degree;     // grado del polinomio
} PolyDense;

PolyDense* createPolyDense(int degree) {
    PolyDense *P = malloc(sizeof(PolyDense));
    P->degree = degree;
    P->coeff = calloc(degree + 1, sizeof(int));   // todo en 0
    return P;
}
```

| Ventaja                | Desventaja                              |
| ---------------------- | --------------------------------------- |
| Acceso directo O(1)    | Desperdicia espacio si es disperso       |
| Implementación simple  | `3x¹⁰⁰⁰ + 1` necesita 1001 posiciones |
| Operaciones sencillas  | Ineficiente para polinomios dispersos    |

## 7.3 Representación 2: Array de términos (Sparse)

Almacenar solo los **términos con coeficiente ≠ 0** como pares `(coeficiente, exponente)`.

```text
P(x) = 3x⁵ + 2x³ + 7x + 4

Términos:
Índice │ Coeff │ Exp
───────┼───────┼─────
  0    │   3   │  5
  1    │   2   │  3
  2    │   7   │  1
  3    │   4   │  0

Solo 4 entradas vs 6 en representación densa.
```

```c
typedef struct {
    int coeff;
    int exp;
} Term;

typedef struct {
    Term *terms;
    int nTerms;     // número de términos no nulos
} PolySparse;

PolySparse* createPolySparse(int nTerms) {
    PolySparse *P = malloc(sizeof(PolySparse));
    P->nTerms = nTerms;
    P->terms = malloc(nTerms * sizeof(Term));
    return P;
}
```

## 7.4 Comparación

| Aspecto              | Denso (`coeff[]`)       | Sparse (`terms[]`)          |
| -------------------- | ----------------------- | --------------------------- |
| Espacio              | `degree + 1`            | `2 × nTerms`               |
| Acceso a coeff de xⁱ | O(1)                   | O(nTerms)                  |
| `3x¹⁰⁰⁰ + 1`       | 1001 enteros            | 4 enteros                   |
| Suma                 | O(max(degA, degB))      | O(nA + nB)                  |
| Mejor para           | Polinomios densos       | Polinomios dispersos         |

> **Regla:** Si `nTerms << degree`, usa representación sparse.

---

# 8. Evaluación de Polinomios

## 8.1 Método directo (ingenuo)

```text
P(x) = 3x⁵ + 2x³ + 7x + 4

Para x = 2:
  3 × 2⁵ = 3 × 32  = 96     (5 multiplicaciones para x⁵)
  2 × 2³ = 2 × 8   = 16     (3 multiplicaciones para x³)
  7 × 2¹ = 7 × 2   = 14     (1 multiplicación para x¹)
  4 × 2⁰ = 4 × 1   = 4

Total = 96 + 16 + 14 + 4 = 130
```

```c
// Función auxiliar: potencia entera
int power(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++)
        result *= base;
    return result;
}

// Evaluación directa (representación densa)
int evalDirect(PolyDense *P, int x) {
    int result = 0;
    for (int i = 0; i <= P->degree; i++) {
        result += P->coeff[i] * power(x, i);
    }
    return result;
}
```

| Complejidad                    | Multiplicaciones totales      |
| ------------------------------ | ----------------------------- |
| **O(n²)** donde n = degree     | `0 + 1 + 2 + ... + n = n(n+1)/2` |

> Para un polinomio de grado 100: **5050 multiplicaciones**. Inaceptable.

## 8.2 Método de Horner (óptimo)

### La idea clave: factorizar anidadamente

```text
P(x) = 3x⁵ + 2x³ + 7x + 4

Reescribir con exponentes completos (rellenando los ceros):
P(x) = 3x⁵ + 0x⁴ + 2x³ + 0x² + 7x + 4

Factorizar desde afuera hacia adentro:
P(x) = ((((3·x + 0)·x + 2)·x + 0)·x + 7)·x + 4
```

```text
Evaluación paso a paso para x = 2:

Empezar con el coeficiente líder: result = 3

result = 3 × 2 + 0 = 6
result = 6 × 2 + 2 = 14
result = 14 × 2 + 0 = 28
result = 28 × 2 + 7 = 63
result = 63 × 2 + 4 = 130   ✓
```

```text
Diagrama visual:

Coeff:   3      0      2      0      7      4
         │      │      │      │      │      │
         ↓      ↓      ↓      ↓      ↓      ↓
    ┌→  ×x  ┌→ ×x  ┌→ ×x  ┌→ ×x  ┌→ ×x
    │   +0  │  +2   │  +0  │  +7  │  +4
    │   =6  │  =14  │  =28 │  =63 │  =130
    3 ──┘   6──┘   14──┘  28──┘  63──┘     → 130
```

### Implementación

```c
// Horner — representación densa
int horner(PolyDense *P, int x) {
    int result = P->coeff[P->degree];   // empezar con coeff líder

    for (int i = P->degree - 1; i >= 0; i--) {
        result = result * x + P->coeff[i];
    }
    return result;
}
```

### Análisis comparativo

| Método    | Multiplicaciones | Sumas   | Complejidad |
| --------- | ---------------- | ------- | ----------- |
| Directo   | n(n+1)/2         | n       | **O(n²)**   |
| Horner    | **n**            | **n**   | **O(n)**    |

> Para grado 100: Directo = 5050 mults, Horner = **100 mults**. **50× más rápido.**

## 8.3 Evaluación con representación Sparse

```c
// Horner no aplica directamente (exponentes no consecutivos).
// Usar método directo con precalculated powers o iterar inteligentemente.

int evalSparse(PolySparse *P, int x) {
    int result = 0;
    for (int i = 0; i < P->nTerms; i++) {
        result += P->terms[i].coeff * power(x, P->terms[i].exp);
    }
    return result;
}
```

> **Complejidad:** O(Σ expᵢ) en el peor caso para `power`, o **O(nTerms × log(maxExp))** si usas exponenciación rápida.

### Horner adaptado para Sparse (técnica avanzada)

Si los términos están **ordenados por exponente decreciente**, puedes adaptar Horner:

```c
// Términos ordenados: terms[0].exp > terms[1].exp > ... > terms[n-1].exp
int hornerSparse(PolySparse *P, int x) {
    int result = P->terms[0].coeff;

    for (int i = 1; i < P->nTerms; i++) {
        int gap = P->terms[i - 1].exp - P->terms[i].exp;
        // Multiplicar por x^gap (los exponentes "vacíos")
        for (int j = 0; j < gap; j++)
            result *= x;
        result += P->terms[i].coeff;
    }

    // Multiplicar por x^(último exponente) si no es 0
    for (int j = 0; j < P->terms[P->nTerms - 1].exp; j++)
        result *= x;

    return result;
}
```

---

# 9. Operaciones sobre Polinomios

## 9.1 Suma de Polinomios (Denso)

```text
A(x) = 3x⁴ + 2x² + 5
B(x) = 4x³ + 2x² + 1

A.coeff = [5, 0, 2, 0, 3]      (grado 4)
B.coeff = [1, 0, 2, 4, 0]      (grado 3, extendido a 4)

C = A + B:
  C.coeff[0] = 5 + 1 = 6
  C.coeff[1] = 0 + 0 = 0
  C.coeff[2] = 2 + 2 = 4
  C.coeff[3] = 0 + 4 = 4
  C.coeff[4] = 3 + 0 = 3

C(x) = 3x⁴ + 4x³ + 4x² + 6
```

```c
PolyDense* addPolyDense(PolyDense *A, PolyDense *B) {
    int maxDeg = A->degree > B->degree ? A->degree : B->degree;
    PolyDense *C = createPolyDense(maxDeg);

    for (int i = 0; i <= A->degree; i++)
        C->coeff[i] += A->coeff[i];

    for (int i = 0; i <= B->degree; i++)
        C->coeff[i] += B->coeff[i];

    return C;
}
```

| Complejidad         | Descripción                      |
| ------------------- | -------------------------------- |
| **O(max(degA, degB))** | Recorre ambos arrays una vez  |

## 9.2 Suma de Polinomios (Sparse)

Similar al merge de dos listas ordenadas:

```text
A: (3,5) (2,3) (7,1) (4,0)     ← (coeff, exp) ordenado por exp decreciente
B: (5,4) (2,3) (3,0)

Merge:
  A(exp=5) vs B(exp=4) → A mayor → C: (3,5)
  A(exp=3) vs B(exp=4) → B mayor → C: (3,5)(5,4)
  A(exp=3) vs B(exp=3) → iguales → C: (3,5)(5,4)(4,3)   [2+2=4]
  A(exp=1) vs B(exp=0) → A mayor → C: (3,5)(5,4)(4,3)(7,1)
  A agotado              → copiar B → C: (3,5)(5,4)(4,3)(7,1)(3,0)   [4+3=7? No, 3,0 de B]

Resultado: C(x) = 3x⁵ + 5x⁴ + 4x³ + 7x + 7
```

> Ups — corrijamos: el término x⁰ de A es 4, de B es 3, así que C tiene (7,0).

```text
Resultado correcto: C(x) = 3x⁵ + 5x⁴ + 4x³ + 7x + 7
```

```c
PolySparse* addPolySparse(PolySparse *A, PolySparse *B) {
    PolySparse *C = malloc(sizeof(PolySparse));
    C->terms = malloc((A->nTerms + B->nTerms) * sizeof(Term));

    int i = 0, j = 0, k = 0;

    while (i < A->nTerms && j < B->nTerms) {
        if (A->terms[i].exp > B->terms[j].exp) {
            C->terms[k++] = A->terms[i++];
        } else if (A->terms[i].exp < B->terms[j].exp) {
            C->terms[k++] = B->terms[j++];
        } else {
            // Mismo exponente → sumar coeficientes
            int sum = A->terms[i].coeff + B->terms[j].coeff;
            if (sum != 0) {
                C->terms[k].coeff = sum;
                C->terms[k].exp = A->terms[i].exp;
                k++;
            }
            i++; j++;
        }
    }

    while (i < A->nTerms) C->terms[k++] = A->terms[i++];
    while (j < B->nTerms) C->terms[k++] = B->terms[j++];

    C->nTerms = k;
    C->terms = realloc(C->terms, k * sizeof(Term));
    return C;
}
```

| Complejidad              | Descripción                       |
| ------------------------ | --------------------------------- |
| **O(nA + nB)**           | Merge de listas ordenadas          |

## 9.3 Multiplicación de Polinomios (Denso)

```text
A(x) = 2x² + 3x + 1       (grado 2)
B(x) = x + 2               (grado 1)

Grado de C = degA + degB = 3

Cada término de A × cada término de B:
  2x² × x  = 2x³
  2x² × 2  = 4x²
  3x  × x  = 3x²
  3x  × 2  = 6x
  1   × x  = x
  1   × 2  = 2

C(x) = 2x³ + 7x² + 7x + 2
```

```c
PolyDense* mulPolyDense(PolyDense *A, PolyDense *B) {
    int newDeg = A->degree + B->degree;
    PolyDense *C = createPolyDense(newDeg);   // calloc → todo en 0

    for (int i = 0; i <= A->degree; i++) {
        for (int j = 0; j <= B->degree; j++) {
            C->coeff[i + j] += A->coeff[i] * B->coeff[j];
        }
    }
    return C;
}
```

| Complejidad            | Descripción                          |
| ---------------------- | ------------------------------------ |
| **O(degA × degB)**     | Cada término con cada término        |

---

# 10. Resumen de Complejidad

## Sparse Matrices

| Operación         | Denso            | Triplet (COO)     | CSR              |
| ----------------- | ---------------- | ------------------ | ---------------- |
| **Espacio**       | O(n × m)         | O(nnz)             | O(nnz + n)       |
| **Acceso A[i][j]**| O(1)             | O(nnz)             | O(nnz_per_row)   |
| **Suma**          | O(n × m)         | O(nnz_A + nnz_B)  | O(nnz_A + nnz_B) |
| **Mat × Vec**     | O(n × m)         | O(nnz)             | O(nnz)           |
| **Transpuesta**   | O(n × m)         | O(nnz + cols)*     | O(nnz + n + m)   |
| **Creación**      | O(1)             | O(n × m)           | O(n × m)         |

*Fast Transpose

## Polinomios

| Operación         | Denso                | Sparse (terms)       |
| ----------------- | -------------------- | -------------------- |
| **Espacio**       | O(degree)            | O(nTerms)            |
| **Evaluación**    | O(degree) [Horner]   | O(nTerms × maxExp)   |
| **Suma**          | O(max(degA, degB))   | O(nA + nB)           |
| **Multiplicación**| O(degA × degB)       | O(nA × nB)           |
| **Acceso coeff xⁱ** | O(1)              | O(nTerms)            |

---

# 11. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                          | Consecuencia                              |
| ---------------------------------------------- | ----------------------------------------- |
| No verificar dimensiones antes de sumar        | Crash o resultado incorrecto              |
| Olvidar el centinela `rowPtr[rows]` en CSR     | Loop fuera de rango en última fila        |
| No verificar que suma = 0 al merge             | Elementos "cero" en la sparse (desperdicio)|
| Asumir que Triplet está ordenado               | Merge produce resultado incorrecto        |
| No hacer `free()` de arrays internos           | Memory leak (3 arrays en CSR)             |
| Confundir índice con exponente (polinomios)    | Coeficiente asignado al grado equivocado  |
| No manejar grado 0 (constante)                | Off-by-one en loops                       |
| Evaluar sin Horner para grados altos           | O(n²) innecesario                         |
| `realloc` sin verificar `NULL`                 | Pérdida de datos si falla                 |

### ✅ Buenas Prácticas

| Práctica                                       | Razón                                      |
| ---------------------------------------------- | ------------------------------------------ |
| Siempre incluir centinela en CSR/CSC           | Evita casos especiales en última fila/col  |
| Ordenar Triplet por (fila, col) al crear       | Requisito para merge eficiente             |
| Usar `calloc` para arrays de conteo            | Evita basura en inicialización             |
| Verificar si la suma de coeficientes es 0      | Evitar almacenar ceros innecesarios        |
| Siempre validar dimensiones antes de operar    | Prevenir errores silenciosos               |
| Usar Horner siempre que sea posible            | O(n) vs O(n²) — no hay razón para no usarlo|
| Guardar `realloc` en temporal                  | Evitar perder puntero original si falla    |
| Documentar orden de exponentes (asc/desc)      | Evitar bugs en merge de polinomios         |

```c
// ✅ realloc seguro
int *temp = realloc(arr, newSize * sizeof(int));
if (temp == NULL) {
    // manejar error — arr sigue válido
    perror("realloc failed");
} else {
    arr = temp;
}
```

---

# 12. Intuición de Ingeniería

> **No almacenes lo que puedes deducir.** Si el 99% de tu matriz es cero, almacenar esos ceros es almacenar ignorancia.
> Las representaciones compactas no son "trucos" — son la **forma correcta** de pensar sobre datos dispersos.

### El patrón universal: Dense vs Sparse

```text
¿Tu estructura tiene muchos "vacíos"?

  SÍ → Representación compacta (solo lo que importa)
       ├── Matrices: Triplet / CSR / CSC
       └── Polinomios: Array de términos (coeff, exp)

  NO → Representación directa (array completo)
       ├── Matrices: int A[n][m]
       └── Polinomios: int coeff[degree + 1]
```

### ¿Por qué Horner importa?

```text
Sin Horner:  P(x) = aₙxⁿ + aₙ₋₁xⁿ⁻¹ + ... + a₀
             Calcular cada xⁱ independientemente → O(n²)

Con Horner:  P(x) = (...((aₙx + aₙ₋₁)x + aₙ₋₂)x + ...)x + a₀
             Reutilizar el resultado anterior     → O(n)

Es la diferencia entre recalcular todo y construir sobre lo ya calculado.
Es el mismo principio que la programación dinámica.
```

### Relación entre formatos

```text
                    ┌────────────────┐
                    │  Matriz Densa  │
                    │   int A[n][m]  │
                    └───────┬────────┘
                            │ extraer no-nulos
                    ┌───────▼────────┐
                    │    Triplet     │
                    │  (row,col,val) │
                    └──┬──────────┬──┘
          comprimir    │          │    comprimir
          por filas    │          │    por columnas
                ┌──────▼──┐  ┌───▼──────┐
                │   CSR   │  │   CSC    │
                │ rowPtr  │  │ colPtr   │
                └─────────┘  └──────────┘
```

### Relación con otros archivos

| Tema                         | Archivo            |
| ---------------------------- | ------------------ |
| Arrays a bajo nivel          | Arrays CDT.md      |
| Operaciones sobre arrays     | Arrays ADT.md      |
| Matrices densas y especiales | Matrices.md        |
| Strings (arrays de char)     | Strings.md         |
| **Sparse Matrices & Polys**  | Este archivo       |
