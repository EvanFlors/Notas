# Arrays — Concrete Data Type (CDT)

> **Idea central:** Un array no es más que **memoria contigua + una fórmula matemática**.
> `arr[i]` es simplemente `base + i × sizeof(tipo)`. Entender esto es entender el 90% de cómo funcionan los arrays a bajo nivel.

---

## Tabla de Contenidos

1. [Fundamentos Previos](#1-fundamentos-previos)
2. [¿Qué es un Array?](#2-qué-es-un-array)
3. [Declaración e Inicialización](#3-declaración-e-inicialización)
4. [Modelo de Memoria](#4-modelo-de-memoria)
5. [Acceso y Aritmética de Punteros](#5-acceso-y-aritmética-de-punteros)
6. [Arrays y Funciones](#6-arrays-y-funciones)
7. [Tipos de Arrays](#7-tipos-de-arrays)
8. [Arrays Multidimensionales](#8-arrays-multidimensionales)
9. [Resumen de Complejidad](#9-resumen-de-complejidad)
10. [Errores Comunes y Buenas Prácticas](#10-errores-comunes-y-buenas-prácticas)
11. [Intuición de Ingeniería](#11-intuición-de-ingeniería)

---

# 1. Fundamentos Previos

## 1.1 Variables y Tipos de Datos

Una **variable** es un nombre que referencia un espacio en memoria.

En C, cada variable tiene:
- **Tipo** → define cuántos bytes ocupa y cómo se interpreta
- **Nombre** → identificador para el programador
- **Dirección** → ubicación física en RAM

```c
int edad = 25;       // 4 bytes
float precio = 9.99; // 4 bytes
char letra = 'A';    // 1 byte
```

### Tamaños típicos

| Tipo     | Tamaño típico | Rango (simplificado)    |
| -------- | ------------- | ----------------------- |
| `char`   | 1 byte        | -128 a 127              |
| `int`    | 4 bytes       | ±2.1 billones           |
| `float`  | 4 bytes       | ±3.4 × 10³⁸            |
| `double` | 8 bytes       | ±1.7 × 10³⁰⁸           |

> Usa `sizeof(tipo)` para obtener el tamaño exacto en tu plataforma.

## 1.2 Variables Escalares vs Agregadas

| Tipo      | Valores       | Ejemplo                    |
| --------- | ------------- | -------------------------- |
| Escalar   | **1** solo    | `int x = 10;`             |
| Agregada  | **Múltiples** | `int arr[5] = {1,2,3,4,5};` |

## 1.3 Representación en memoria

Cada variable ocupa una dirección específica:

```text
Variable: int x = 10;

Dirección   Bytes (little-endian)
0x1000      [0A][00][00][00]    ← 10 en 4 bytes
```

En C puedes ver la dirección con:

```c
printf("Dirección de x: %p\n", (void*)&x);
```

---

# 2. ¿Qué es un Array?

## 2.1 Definición concreta

Un **array** es un bloque **contiguo** de memoria que almacena múltiples valores del **mismo tipo**.

```c
int arr[5] = {10, 20, 30, 40, 50};
```

```text
Nombre: arr
Tipo:   int (4 bytes cada uno)
Total:  5 × 4 = 20 bytes contiguos

Dirección   Valor    Índice
┌──────────┬───────┬────────┐
│ 0x1000   │  10   │ arr[0] │
│ 0x1004   │  20   │ arr[1] │
│ 0x1008   │  30   │ arr[2] │
│ 0x100C   │  40   │ arr[3] │
│ 0x1010   │  50   │ arr[4] │
└──────────┴───────┴────────┘
```

## 2.2 Escalar vs Array

| Característica | Escalar          | Array                    |
| -------------- | ---------------- | ------------------------ |
| Valores        | 1                | N (fijo en declaración)  |
| Memoria        | 1 bloque         | N bloques contiguos      |
| Acceso         | Directo por nombre | Por índice `arr[i]`    |
| Tamaño         | `sizeof(tipo)`   | `N × sizeof(tipo)`      |

## 2.3 Propiedades clave

| Propiedad          | Descripción                              |
| ------------------ | ---------------------------------------- |
| Contiguo           | Elementos uno tras otro en RAM           |
| Homogéneo          | Todos del mismo tipo                     |
| Indexado desde 0   | Primer elemento = `arr[0]`               |
| Tamaño fijo        | No crece automáticamente (en C)          |
| Acceso O(1)        | Fórmula directa para cualquier índice    |

---

# 3. Declaración e Inicialización

## 3.1 Declaración

```c
int arr[5];    // reserva 20 bytes, valores = basura ⚠️
```

> **Advertencia:** Sin inicializar, el contenido es **indefinido** (basura en memoria).

## 3.2 Métodos de Inicialización

### Explícita (lista de valores)

```c
int arr[5] = {1, 2, 3, 4, 5};
```

```text
Memoria: [1][2][3][4][5]    ← todo definido
```

### Parcial (resto se llena con 0)

```c
int arr[5] = {1, 2};
```

```text
Memoria: [1][2][0][0][0]    ← C llena el resto con 0
```

### Implícita (tamaño deducido)

```c
int arr[] = {10, 20, 30};   // compilador deduce: arr[3]
```

### Inicialización en ceros

```c
int arr[5] = {0};           // todo en 0
```

```text
Memoria: [0][0][0][0][0]
```

### Designada (C99+)

Permite asignar valores a índices específicos:

```c
int arr[5] = {[2] = 10, [4] = 20};
```

```text
Memoria: [0][0][10][0][20]
```

### En tiempo de ejecución

```c
int arr[5];
for (int i = 0; i < 5; i++)
    arr[i] = i * 2;
```

```text
Memoria: [0][2][4][6][8]
```

### Dinámica (heap)

```c
// malloc — NO inicializa (basura)
int* arr = (int*)malloc(5 * sizeof(int));

// calloc — inicializa todo en 0
int* arr = (int*)calloc(5, sizeof(int));

// ⚠️ Obligatorio liberar
free(arr);
```

## 3.3 Comparación de métodos

| Método       | Inicializa | Momento      | Ubicación | Uso típico                |
| ------------ | ---------- | ------------ | --------- | ------------------------- |
| Explícita    | Sí         | Compilación  | Stack     | Datos conocidos           |
| Parcial      | Sí (0s)    | Compilación  | Stack     | Defaults parciales        |
| Implícita    | Sí         | Compilación  | Stack     | Evitar errores de tamaño  |
| Ceros        | Sí         | Compilación  | Stack     | Inicialización segura     |
| Designada    | Sí         | Compilación  | Stack     | Índices específicos       |
| Runtime      | Sí         | Ejecución    | Stack     | Datos calculados          |
| `malloc`     | **No**     | Ejecución    | Heap      | Alto control, tamaño variable |
| `calloc`     | Sí (0s)    | Ejecución    | Heap      | Heap + inicialización segura  |

---

# 4. Modelo de Memoria

## 4.1 Memoria contigua

La esencia de un array: **elementos consecutivos en RAM**.

```c
int arr[4] = {10, 20, 30, 40};
```

```text
         ┌──────────────────────────────────────────┐
         │              RAM (contigua)               │
         ├──────────┬──────────┬──────────┬──────────┤
Direc.   │  0x1000  │  0x1004  │  0x1008  │  0x100C  │
         ├──────────┼──────────┼──────────┼──────────┤
Valor    │    10    │    20    │    30    │    40    │
         ├──────────┼──────────┼──────────┼──────────┤
Índice   │  arr[0]  │  arr[1]  │  arr[2]  │  arr[3]  │
         └──────────┴──────────┴──────────┴──────────┘
              ↑
              base = 0x1000
```

## 4.2 Fórmula de acceso

```text
address(arr[i]) = base + i × sizeof(tipo)
```

| Variable     | Significado                          |
| ------------ | ------------------------------------ |
| `base`       | Dirección del primer elemento        |
| `i`          | Índice del elemento                  |
| `sizeof(tipo)` | Tamaño en bytes de cada elemento  |

**Ejemplo:** `int arr[4]`, acceder a `arr[2]`:

```text
address = 0x1000 + 2 × 4 = 0x1008    ✓
```

> **Esto es lo que hace acceso O(1) posible.** No se recorre nada — se calcula directamente.

## 4.3 Stack vs Heap

```text
┌──────────────────────┐  Direcciones altas
│       STACK          │  ← arrays estáticos: int arr[5];
│  (crece hacia abajo) │     automático, rápido, limitado
├──────────────────────┤
│         ...          │
├──────────────────────┤
│        HEAP          │  ← arrays dinámicos: malloc(...)
│  (crece hacia arriba)│     manual, flexible, más lento
├──────────────────────┤
│   DATA (globals)     │  ← variables globales/static
├──────────────────────┤
│       CODE           │  ← instrucciones del programa
└──────────────────────┘  Direcciones bajas
```

| Aspecto       | Stack                          | Heap                             |
| ------------- | ------------------------------ | -------------------------------- |
| Declaración   | `int arr[5];`                  | `int *arr = malloc(5*sizeof(int));` |
| Liberación    | Automática (al salir del scope)| Manual (`free(arr)`)             |
| Velocidad     | Muy rápido                     | Más lento (syscall)              |
| Tamaño        | Limitado (~1-8 MB)             | Limitado por RAM disponible      |
| Redimensionar | Imposible                      | Posible (`realloc`)              |

---

# 5. Acceso y Aritmética de Punteros

## 5.1 El nombre del array ES un puntero

En C, el nombre de un array **decae** (decay) a un puntero al primer elemento:

```c
int arr[5] = {10, 20, 30, 40, 50};

printf("%p\n", arr);       // dirección de arr[0]
printf("%p\n", &arr[0]);   // lo mismo
```

> `arr` ≡ `&arr[0]` → ambos son la dirección base.

## 5.2 Equivalencia: índice ↔ puntero

Estas dos formas son **idénticas**:

```c
arr[i]   ≡   *(arr + i)
```

| Notación        | Significado                           |
| --------------- | ------------------------------------- |
| `arr[i]`        | Acceso por índice (sintaxis azúcar)   |
| `*(arr + i)`    | Desreferencia puntero desplazado      |
| `&arr[i]`       | Dirección del i-ésimo elemento        |
| `arr + i`       | Lo mismo que `&arr[i]`                |

**Ejemplo:**

```c
int arr[3] = {10, 20, 30};

arr[1]       → 20          // notación de índice
*(arr + 1)   → 20          // aritmética de puntero
&arr[1]      → 0x1004      // dirección
arr + 1      → 0x1004      // lo mismo
```

## 5.3 Aritmética de punteros

El compilador **escala automáticamente** según el tipo:

```c
int *p = arr;      // p apunta a arr[0]

p + 1              // NO avanza 1 byte, avanza sizeof(int) = 4 bytes
p + 2              // avanza 2 × 4 = 8 bytes
```

```text
p        p+1      p+2      p+3
↓        ↓        ↓        ↓
┌────────┬────────┬────────┬────────┐
│ arr[0] │ arr[1] │ arr[2] │ arr[3] │
└────────┴────────┴────────┴────────┘
0x1000   0x1004   0x1008   0x100C

p + i  =  dirección base + i × sizeof(int)
```

> **Clave:** `p + 1` avanza `sizeof(*p)` bytes, no 1 byte.

## 5.4 Recorrer con puntero vs con índice

```c
// Con índice (más legible)
for (int i = 0; i < n; i++)
    printf("%d ", arr[i]);

// Con puntero (más bajo nivel)
for (int *p = arr; p < arr + n; p++)
    printf("%d ", *p);
```

Ambos generan el **mismo código máquina**. Usa el que sea más legible.

---

# 6. Arrays y Funciones

## 6.1 Pasar array a función

En C, los arrays **siempre se pasan por referencia** (como puntero). No se copia el array.

```c
void printArray(int arr[], int n) {    // arr[] = puntero
    for (int i = 0; i < n; i++)
        printf("%d ", arr[i]);
}
```

Estas declaraciones son **equivalentes**:

```c
void f(int arr[]);      // parece array, pero es puntero
void f(int arr[5]);     // el 5 se ignora
void f(int *arr);       // la verdad: es un puntero
```

> **Consecuencia:** La función **puede modificar** el array original.

## 6.2 ¿Por qué no se copia?

Copiar arrays grandes sería muy costoso. En cambio, solo se copia la **dirección** (8 bytes en 64-bit).

```text
main():                              printArray():
┌──────────────┐                     ┌──────────────┐
│ arr → 0x1000 │ ──copia dirección→  │ arr → 0x1000 │
└──────────────┘                     └──────────────┘
        ↓                                    ↓
┌────┬────┬────┬────┬────┐          Apuntan al MISMO
│ 10 │ 20 │ 30 │ 40 │ 50 │          bloque de memoria
└────┴────┴────┴────┴────┘
0x1000
```

## 6.3 sizeof dentro de funciones

⚠️ **Problema clásico:** `sizeof(arr)` dentro de una función retorna el tamaño del **puntero**, no del array.

```c
void f(int arr[]) {
    sizeof(arr);    // → 8 (tamaño del puntero en 64-bit)
                    // NO el tamaño del array
}

int main() {
    int arr[5] = {1, 2, 3, 4, 5};
    sizeof(arr);    // → 20 (5 × 4 bytes) ✓
}
```

> **Solución:** Siempre pasar el tamaño como parámetro separado: `f(arr, n)`.

## 6.4 Retornar arrays de funciones

En C, **no puedes retornar un array local** (vive en el stack y se destruye):

```c
// ❌ INCORRECTO — undefined behavior
int* f() {
    int arr[5] = {1, 2, 3, 4, 5};
    return arr;     // arr se destruye al salir de f()
}

// ✅ CORRECTO — usar heap
int* f() {
    int *arr = (int*)malloc(5 * sizeof(int));
    // ... llenar arr ...
    return arr;     // el caller debe hacer free()
}
```

---

# 7. Tipos de Arrays

## 7.1 Estáticos (Stack)

```c
int arr[10];            // tamaño fijo en compilación
```

- Muy rápidos (stack allocation)
- No redimensionables
- Se liberan automáticamente

## 7.2 Variable Length Arrays — VLA (C99)

Tamaño definido en **tiempo de ejecución**, pero sigue en el **stack**:

```c
int n;
scanf("%d", &n);
int arr[n];             // VLA — tamaño decidido en runtime
```

| Ventaja                | Desventaja                          |
| ---------------------- | ----------------------------------- |
| No necesita malloc     | Puede causar stack overflow          |
| Sintaxis simple        | No disponible en todos los compiladores |
| Automáticamente liberado | Tamaño no puede cambiar después   |

> **Nota:** VLA fue obligatorio en C99, luego **opcional** en C11. Evítalo en código portátil.

## 7.3 Dinámicos (Heap)

```c
int *arr = (int*)malloc(n * sizeof(int));
// ... usar ...
arr = (int*)realloc(arr, newN * sizeof(int));  // redimensionar
// ... usar ...
free(arr);                                      // obligatorio
```

### Estrategia: Over-allocation (sobre-reservar)

Para evitar `realloc` frecuentes, se reserva **más espacio del necesario** y se duplica cuando se llena:

```text
Estado 1:  length=3, capacity=4
           [10, 20, 30, _ ]

Append(40): length=4, capacity=4  ← lleno!

Estado 2:  realloc × 2 → capacity=8
           [10, 20, 30, 40, _, _, _, _ ]

Append(50): length=5, capacity=8  ← espacio de sobra
           [10, 20, 30, 40, 50, _, _, _ ]
```

**Implementación básica:**

```c
typedef struct {
    int *data;
    int length;
    int capacity;
} DynamicArray;

DynamicArray* createDynArray(int initialCapacity) {
    DynamicArray* da = malloc(sizeof(DynamicArray));
    da->data = malloc(initialCapacity * sizeof(int));
    da->length = 0;
    da->capacity = initialCapacity;
    return da;
}

void dynAppend(DynamicArray* da, int value) {
    if (da->length >= da->capacity) {
        da->capacity *= 2;                              // duplicar
        da->data = realloc(da->data, da->capacity * sizeof(int));
    }
    da->data[da->length++] = value;
}

void freeDynArray(DynamicArray* da) {
    free(da->data);
    free(da);
}
```

| Operación  | Complejidad          |
| ---------- | -------------------- |
| Append     | **O(1) amortizado**  |
| Resize     | O(n) — copia todo    |

> Duplicar la capacidad garantiza que **en promedio** cada inserción es O(1).

## 7.4 Comparación

| Aspecto          | Estático       | VLA            | Dinámico              |
| ---------------- | -------------- | -------------- | --------------------- |
| Tamaño decidido  | Compilación    | Ejecución      | Ejecución             |
| Ubicación        | Stack          | Stack          | Heap                  |
| Redimensionable  | No             | No             | Sí (`realloc`)        |
| Liberación       | Automática     | Automática     | Manual (`free`)       |
| Velocidad        | Más rápido     | Rápido         | Más lento             |
| Riesgo           | —              | Stack overflow | Memory leak           |

---

# 8. Arrays Multidimensionales

## 8.1 Array 2D (Matriz)

```c
int mat[2][3] = {
    {1, 2, 3},
    {4, 5, 6}
};
```

```text
Lógica (2D):             Física (1D, Row-Major):
┌───┬───┬───┐
│ 1 │ 2 │ 3 │  fila 0    [ 1, 2, 3, 4, 5, 6 ]
├───┼───┼───┤              ─fila 0─  ─fila 1─
│ 4 │ 5 │ 6 │  fila 1
└───┴───┴───┘
```

## 8.2 Representación en memoria (Row-Major)

C almacena matrices en **Row-Major** (fila por fila):

```text
Dirección   Valor    Elemento
0x1000      1        mat[0][0]
0x1004      2        mat[0][1]
0x1008      3        mat[0][2]
0x100C      4        mat[1][0]
0x1010      5        mat[1][1]
0x1014      6        mat[1][2]
```

## 8.3 Fórmula de acceso

```text
address(A[i][j]) = base + (i × columnas + j) × sizeof(tipo)
```

**Ejemplo:** `mat[1][2]` en `int mat[2][3]`:

```text
address = base + (1 × 3 + 2) × 4 = base + 20
```

## 8.4 Generalización a N dimensiones

Para un array `A[d₀][d₁]...[dₙ₋₁]`, el **stride** de cada dimensión determina el offset:

```text
offset = i₀ × (d₁ × d₂ × ... × dₙ₋₁)
       + i₁ × (d₂ × d₃ × ... × dₙ₋₁)
       + ...
       + iₙ₋₁
```

**Ejemplo 3D:** `A[2][3][4]`, acceder a `A[1][2][3]`:

```text
offset = 1 × (3 × 4) + 2 × (4) + 3 = 12 + 8 + 3 = 23
address = base + 23 × sizeof(tipo)
```

> Para matrices especiales (diagonal, triangular, etc.), ver el archivo **Matrices.md**.

---

# 9. Resumen de Complejidad

| Operación           | Complejidad | Nota                                  |
| ------------------- | ----------- | ------------------------------------- |
| **Acceso `arr[i]`** | O(1)        | Fórmula directa                       |
| **Asignación**      | O(1)        | Fórmula directa                       |
| **Declaración**     | O(1)        | Stack: instantáneo                    |
| **malloc / calloc** | O(1)*       | Syscall, pero amortizado ~O(1)        |
| **realloc**         | O(n)        | Copia todos los elementos             |
| **free**            | O(1)        | Libera el bloque                      |
| **sizeof(arr)**     | O(1)        | Calculado en compilación (no en funciones) |

---

# 10. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                      | Consecuencia                              |
| ------------------------------------------ | ----------------------------------------- |
| Acceder fuera de rango `arr[n]`            | Undefined Behavior (crash o corrupción)   |
| No inicializar `int arr[5];`               | Basura en memoria                         |
| `sizeof(arr)` dentro de función            | Retorna tamaño del puntero, no del array  |
| Retornar array local de función            | Dangling pointer (memoria destruida)      |
| `free()` en array estático                 | Crash                                     |
| Olvidar `free()` en array dinámico         | Memory leak                               |
| `realloc` sin guardar resultado            | Posible pérdida del puntero original      |
| Usar VLA con tamaño grande                 | Stack overflow                            |

### ✅ Buenas Prácticas

| Práctica                                   | Razón                                     |
| ------------------------------------------ | ----------------------------------------- |
| Siempre inicializar arrays                 | Evitar basura                              |
| Usar constantes para tamaños               | `#define SIZE 10` → mantenibilidad        |
| Pasar tamaño como parámetro a funciones    | `sizeof` no funciona en funciones          |
| Usar `calloc` en vez de `malloc` + memset  | Más limpio y seguro                        |
| Guardar resultado de `realloc` en temporal | Evitar perder puntero si falla            |
| Verificar retorno de `malloc` / `realloc`  | Pueden retornar `NULL`                     |
| Preferir `arr[i]` sobre `*(arr + i)`       | Más legible (mismo resultado)              |

```c
// ✅ realloc seguro
int *temp = realloc(arr, newSize * sizeof(int));
if (temp == NULL) {
    // manejar error — arr original sigue válido
} else {
    arr = temp;
}
```

---

# 11. Intuición de Ingeniería

> Un array es **la estructura más simple y poderosa** que existe.
> Todo lo demás (listas, árboles, hash tables) es un intento de solucionar sus limitaciones.

### ¿Por qué los arrays son tan rápidos?

```text
arr[i]  →  base + i × sizeof(tipo)  →  1 operación de CPU

No hay:
  ✗ Recorrido de nodos
  ✗ Seguimiento de punteros
  ✗ Cálculos complejos
```

Además, la **memoria contigua** es amigable con el **CPU cache**:

```text
Cache line (64 bytes) carga 16 ints de golpe:

┌─────────────────────────────────────────────────┐
│ arr[0] arr[1] arr[2] ... arr[15]                │  ← 1 acceso a RAM
└─────────────────────────────────────────────────┘    carga 16 elementos

vs. Lista enlazada:
  arr[0] → acceso a RAM
  arr[1] → acceso a RAM (otra dirección)
  arr[2] → acceso a RAM (otra dirección)
  ...
```

### Relación CDT ↔ ADT

| Nivel | Archivo          | Se enfoca en                          |
| ----- | ---------------- | ------------------------------------- |
| CDT   | Este archivo     | **Cómo** se almacena (bytes, punteros, RAM) |
| ADT   | Arrays ADT.md   | **Qué** operaciones existen (insert, search) |

> El **CDT** es la cocina. El **ADT** es el menú.
> Necesitas entender ambos para ser un buen ingeniero.
