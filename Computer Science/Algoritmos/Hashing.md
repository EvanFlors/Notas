# Hashing — Tablas Hash

> **Idea central:** Convertir una **clave** en un **índice de array** mediante una función hash.
> El objetivo es lograr **búsqueda, inserción y eliminación en O(1) promedio** — el santo grial de las estructuras de datos.

---

## Tabla de Contenidos

1. [El Problema que Resuelve Hashing](#1-el-problema-que-resuelve-hashing)
2. [¿Qué es una Función Hash?](#2-qué-es-una-función-hash)
3. [Tabla Hash: La Estructura](#3-tabla-hash-la-estructura)
4. [Colisiones](#4-colisiones)
5. [Resolución de Colisiones: Chaining](#5-resolución-de-colisiones-chaining)
6. [Resolución de Colisiones: Open Addressing](#6-resolución-de-colisiones-open-addressing)
7. [Función Hash: Diseño](#7-función-hash-diseño)
8. [Tamaño de la Tabla y Factor de Carga](#8-tamaño-de-la-tabla-y-factor-de-carga)
9. [Rehashing](#9-rehashing)
10. [Operaciones y Complejidad](#10-operaciones-y-complejidad)
11. [Hashing en el Mundo Real](#11-hashing-en-el-mundo-real)
12. [Errores Comunes y Buenas Prácticas](#12-errores-comunes-y-buenas-prácticas)
13. [Intuición de Ingeniería](#13-intuición-de-ingeniería)

---

# 1. El Problema que Resuelve Hashing

## 1.1 El mundo sin hashing

Imagina que tienes 1 millón de usuarios y necesitas buscar uno por su ID en cada login.

| Estructura              | Búsqueda | 1,000,000 elementos |
| ----------------------- | -------- | ------------------- |
| Array no ordenado       | O(n)     | ~1,000,000 ops      |
| Array ordenado + binary search | O(log n) | ~20 ops        |
| **Hash Table**          | **O(1)** | **~1 op**           |

> **Hashing reduce 1,000,000 de operaciones a 1 sola.** Esa es la promesa.

## 1.2 La idea intuitiva

```text
Piénsalo como un casillero de gimnasio:

Para encontrar la llave del casillero 42:
  1. Tomas tu número de socio (clave)
  2. Calculas 42 mod 100 (función hash)
  3. Vas directo al casillero 42

Sin buscar en 99 casilleros. UNA sola operación.
```

> **La clave está en el paso 2: convertir la clave en una posición.**

---

# 2. ¿Qué es una Función Hash?

## 2.1 Definición

Una **función hash** `h(x)` toma una **clave** de cualquier tamaño y produce un **número entero** dentro de un rango fijo (el tamaño de la tabla).

```text
h: Claves (strings, ints, objetos)  →  Índices [0, m-1]
```

## 2.2 Propiedades deseables

| Propiedad              | Significado                                          |
| ---------------------- | ---------------------------------------------------- |
| **Determinista**       | Misma clave → mismo índice **siempre**               |
| **Uniforme**           | Distribuye las claves de forma pareja en la tabla    |
| **Rápida**             | O(1) — calcular el índice debe ser instantáneo      |
| **Avalancha**          | Cambiar 1 bit de la clave cambia muchos bits del hash|

## 2.3 Ejemplos simples

### Método de la división

```text
h(k) = k mod m
```

```c
int hash(int key, int tableSize) {
    return key % tableSize;
}
```

| key | tableSize=10 | h(key) |
| --- | ------------ | ------ |
| 25  | 10           | 5      |
| 91  | 10           | 1      |
| 37  | 10           | 7      |

> ⚠️ **Problema:** si `m` es potencia de 2, solo usas los últimos bits de la clave.

### Método de la multiplicación

```text
h(k) = floor(m · frac(k · A))
```

donde `A` es una constante entre 0 y 1 (típicamente `(√5 - 1)/2 ≈ 0.618`).

### Hashing de strings

Para strings, sumamos los valores ASCII y aplicamos módulo:

```c
int hashString(const char* str, int m) {
    int sum = 0;
    for (int i = 0; str[i] != '\0'; i++)
        sum += str[i];           // suma ASCII
    return sum % m;
}
```

Versión mejorada (polinomial):

```c
int hashStringPoly(const char* str, int m) {
    int h = 0;
    for (int i = 0; str[i] != '\0'; i++)
        h = (h * 31 + str[i]) % m;   // 31 es un primo común
    return h;
}
```

> **Por qué multiplicar por un primo:** anagramas como `"abc"` y `"cba"` producirían el mismo hash con suma simple. La multiplicación los distingue.

---

# 3. Tabla Hash: La Estructura

## 3.1 Definición

Una **tabla hash** es un **array** donde cada posición puede contener:
- Un valor directo, o
- Una colección de valores (cuando hay colisiones)

```text
Tabla de tamaño m=10 (vacía):

Índice:  0    1    2    3    4    5    6    7    8    9
       ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
       │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │
       └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
```

## 3.2 Inserción

```text
Insertar (clave=25, valor="Alice"):
   h(25) = 25 mod 10 = 5
   →  tabla[5] = "Alice"

Insertar (clave=15, valor="Bob"):
   h(15) = 15 mod 10 = 5  ← MISMA posición que Alice!
   →  COLISIÓN 😱
```

```text
Índice:  0    1    2    3    4    5    6    7    8    9
       ┌────┬────┬────┬────┬────┬─────────┬────┬────┬────┬────┐
       │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ Alice   │ ∅  │ ∅  │ ∅  │ ∅  │
       └────┴────┴────┴────┴────┴─────────┴────┴────┴────┴────┘
                                          ↑
                                    h(25)=5, h(15)=5
```

## 3.3 Búsqueda

```c
Valor* buscar(Tabla* t, int clave) {
    int idx = hash(clave, t->size);
    return t->buckets[idx];   // depende de la estrategia de colisión
}
```

---

# 4. Colisiones

## 4.1 ¿Qué es una colisión?

Ocurre cuando **dos claves diferentes** producen el **mismo índice hash**.

```text
h(25) = 5
h(15) = 5   ← colisión: ambas quieren el bucket 5
```

## 4.2 ¿Son inevitables?

**Sí, por la paradoja del cumpleaños (Birthday Paradox):**

> Con solo **23 personas** en una habitación, hay **50% de probabilidad** de que dos cumplan años el mismo día.

Para una tabla de tamaño `m` con `n` elementos:

```text
Probabilidad de al menos una colisión ≈ 1 - e^(-n²/2m)
```

Con `n ≈ m`, la probabilidad de colisión es ~63%. Con `n ≈ 2m`, es ~86%.

> **Conclusión:** Las colisiones son **inevitables**. Necesitamos estrategias para manejarlas.

## 4.3 Las dos grandes familias

| Estrategia              | Idea                                                |
| ----------------------- | --------------------------------------------------- |
| **Chaining**            | Cada bucket guarda una **lista** de elementos       |
| **Open Addressing**     | Si el bucket está ocupado, **busca otro**            |

---

# 5. Resolución de Colisiones: Chaining

## 5.1 Idea

Cada bucket de la tabla apunta a una **lista enlazada** (o array dinámico) que contiene todos los elementos cuyo hash cae en ese bucket.

```text
Insertar (25, "Alice"), (15, "Bob"), (35, "Carol") con m=10:

Índice:  0    1    2    3    4    5                  6    7    8    9
       ┌────┬────┬────┬────┬────┬───────────────┬────┬────┬────┬────┐
       │ ∅  │ ∅  │ ∅  │ ∅  │ ∅  │ → Alice → Bob │ ∅  │ ∅  │ ∅  │ ∅  │
       └────┴────┴────┴────┴────┴───────────────┴────┴────┴────┴────┘
                                          ↑       ↑
                                       h(25)=5  h(15)=5
                                       h(35)=5  (todos caen aquí)
```

> Nota: el orden dentro de la lista puede ser de inserción o reordenarse por acceso.

## 5.2 Implementación

```c
typedef struct Nodo {
    int key;
    char value[50];
    struct Nodo* next;
} Nodo;

typedef struct {
    Nodo* buckets[TABLE_SIZE];
} HashTable;

void insert(HashTable* ht, int key, const char* value) {
    int idx = hash(key, TABLE_SIZE);
    Nodo* nuevo = malloc(sizeof(Nodo));
    nuevo->key = key;
    strcpy(nuevo->value, value);
    nuevo->next = ht->buckets[idx];     // insertar al frente: O(1)
    ht->buckets[idx] = nuevo;
}

Nodo* search(HashTable* ht, int key) {
    int idx = hash(key, TABLE_SIZE);
    Nodo* curr = ht->buckets[idx];
    while (curr != NULL) {
        if (curr->key == key) return curr;
        curr = curr->next;
    }
    return NULL;
}
```

## 5.3 Análisis de complejidad (Chaining)

| Operación | Promedio | Peor caso          |
| --------- | -------- | ------------------ |
| Insertar  | **O(1)** | O(n) — todos al mismo bucket |
| Buscar    | **O(1 + α)** | O(n)           |
| Eliminar  | **O(1 + α)** | O(n)           |

> `α` = factor de carga = `n / m` (elementos por bucket en promedio)

Si la función hash es buena y `α` ≈ 1, la búsqueda es prácticamente **O(1)**.

## 5.4 Variantes de Chaining

| Variante             | Descripción                              |
| -------------------- | ---------------------------------------- |
| **Linked List**      | Simple, fácil de implementar             |
| **Lista ordenada**   | Búsqueda O(log k) dentro del bucket      |
| **BST / AVL**        | Bucket = árbol → búsqueda O(log k)       |
| **Tabla hash anidada** | Bucket = mini-hash-table               |

---

# 6. Resolución de Colisiones: Open Addressing

## 6.1 Idea

En lugar de guardar listas, **todos los elementos van en el array principal**. Si el bucket deseado está ocupado, **probamos otros buckets** siguiendo una secuencia.

```text
Insertar (25, "Alice") con h(25)=5:
  tabla[5] libre → guardar ahí

Insertar (15, "Bob") con h(15)=5:
  tabla[5] ocupado → probar tabla[6]
  tabla[6] libre → guardar ahí
```

## 6.2 Las tres estrategias principales

| Estrategia              | Fórmula                              | Patrón              |
| ----------------------- | ------------------------------------ | ------------------- |
| **Linear Probing**      | `h(k, i) = (h(k) + i) mod m`        | 5, 6, 7, 8, 9, 0... |
| **Quadratic Probing**   | `h(k, i) = (h(k) + i²) mod m`       | 5, 6, 9, 14, 21... |
| **Double Hashing**      | `h(k, i) = (h₁(k) + i·h₂(k)) mod m` | pasos variables     |

### Linear Probing — ejemplo completo

```text
Insertar 25, 15, 35, 45 con m=10 (h = key mod 10):

25 → h=5 → tabla[5] libre   → [5]=25
15 → h=5 → tabla[5] ocupado → tabla[6] libre → [6]=15
35 → h=5 → [5] lleno, [6] lleno → [7] libre → [7]=35
45 → h=5 → [5,6,7] llenos  → [8] libre → [8]=45

Resultado:
Índice: 0   1   2   3   4   5   6   7   8   9
       ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
       │ ∅ │ ∅ │ ∅ │ ∅ │ ∅ │25 │15 │35 │45 │ ∅ │
       └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
```

> ⚠️ **Problema:** la linear probing causa **clustering primario** — grupos contiguos de slots ocupados que crecen.

### Quadratic Probing

```text
Insertar 25, 15, 35, 45 con m=10 (h = key mod 10):

25 → h=5, i=0 → [5] libre   → [5]=25
15 → h=5, i=0 → [5] lleno
        i=1 → [6] libre     → [6]=15
35 → h=5, i=0 → [5] lleno
        i=1 → [6] lleno
        i=2 → [9] libre     → [9]=35    ← salta 2²=4 posiciones
45 → h=5, i=0 → [5] lleno
        i=1 → [6] lleno
        i=2 → [9] lleno
        i=3 → [8] libre     → [8]=45    ← salta 3²=9 posiciones
```

> **Ventaja:** reduce el clustering. **Desventaja:** puede no encontrar slot libre aunque exista.

### Double Hashing

```text
h₁(k) = k mod m
h₂(k) = 1 + (k mod (m-1))      ← segundo hash para los saltos

Insertar 25, 15, 35, 45 con m=10:

25 → h₁=5, i=0 → [5] libre   → [5]=25
15 → h₁=5, h₂=6
        i=0 → [5] lleno
        i=1 → (5+1·6) mod 10 = 1 → [1] libre → [1]=15
35 → h₁=5, h₂=6
        i=0 → [5] lleno
        i=1 → [1] lleno
        i=2 → (5+2·6) mod 10 = 7 → [7] libre → [7]=35
```

> **Ventaja:** mejor distribución que linear/quadratic. **Desventaja:** más costoso de calcular.

## 6.3 Implementación de Linear Probing

```c
typedef struct {
    int key;
    char value[50];
    int occupied;        // 0 = libre, 1 = ocupado, 2 = borrado (tombstone)
} Entry;

typedef struct {
    Entry table[TABLE_SIZE];
} HashTable;

int linearProbe(int key, int i, int m) {
    return (hash(key, m) + i) % m;
}

void insert(HashTable* ht, int key, const char* value) {
    int idx = hash(key, TABLE_SIZE);
    for (int i = 0; i < TABLE_SIZE; i++) {
        int probe = linearProbe(key, i, TABLE_SIZE);
        if (!ht->table[probe].occupied) {
            ht->table[probe].key = key;
            strcpy(ht->table[probe].value, value);
            ht->table[probe].occupied = 1;
            return;
        }
    }
}
```

## 6.4 El problema del borrado: Tombstones

En open addressing, **no puedes simplemente poner el slot como "libre"**, porque romperías las cadenas de probing.

```text
Insertar 25, 15, 35
tabla: [∅, ∅, ∅, ∅, ∅, 25, 15, 35, ∅, ∅]

Borrar 15
tabla: [∅, ∅, ∅, ∅, ∅, 25, ∅, 35, ∅, ∅]   ← ¡NO! rompería la búsqueda de 35

Solución: usar un marcador "tombstone" (borrado)
tabla: [∅, ∅, ∅, ∅, ∅, 25, 🪦, 35, ∅, ∅]   ← el slot cuenta como ocupado
                                       durante búsqueda, pero permite inserción
```

```c
// Búsqueda con tombstone
Nodo* search(HashTable* ht, int key) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        int probe = linearProbe(key, i, TABLE_SIZE);
        if (ht->table[probe].occupied == 0)     // libre real → no está
            return NULL;
        if (ht->table[probe].occupied == 1 &&
            ht->table[probe].key == key)
            return &ht->table[probe];
        // si es tombstone, sigue buscando
    }
    return NULL;
}
```

## 6.5 Comparación de estrategias de Open Addressing

| Estrategia            | Pros                          | Contras                            |
| --------------------- | ----------------------------- | ---------------------------------- |
| **Linear Probing**    | Simple, cache-friendly        | Clustering primario                |
| **Quadratic Probing** | Menos clustering              | Puede no cubrir todo el espacio    |
| **Double Hashing**    | Mejor distribución            | Más costoso de calcular            |

---

# 7. Función Hash: Diseño

## 7.1 Propiedades críticas

| Propiedad      | Por qué importa                                        |
| -------------- | ------------------------------------------------------ |
| **Uniformidad**| Distribuye claves parejo → menos colisiones            |
| **Determinismo**| Misma clave → mismo hash siempre                      |
| **Rapidez**    | O(1) por cálculo; nunca debe iterar                    |
| **Avalancha**  | Cambio mínimo en clave → cambio grande en hash         |

## 7.2 Funciones hash populares

| Función          | Uso típico                            | Bits  |
| ---------------- | ------------------------------------- | ----- |
| **DJB2**         | Hashing de strings simple             | 32    |
| **FNV-1a**       | Hashing rápido y bueno para strings   | 32/64 |
| **MurmurHash**   | Alto rendimiento, no criptográfico    | 32/64/128 |
| **SHA-256**      | Criptográfico, seguridad              | 256   |
| **MD5**          | Históricamente popular, **inseguro**  | 128   |
| **xxHash**       | Extremadamente rápido, buena calidad  | 32/64 |

## 7.3 Ejemplo: DJB2

```c
unsigned long djb2(const char* str) {
    unsigned long hash = 5381;
    int c;
    while ((c = *str++))
        hash = ((hash << 5) + hash) + c;   // hash * 33 + c
    return hash;
}
```

## 7.4 Hashing criptográfico vs no criptográfico

| Tipo              | Velocidad  | Resistencia a colisiones | Uso                              |
| ----------------- | ---------- | ------------------------ | -------------------------------- |
| **No criptográfico** (DJB2, Murmur) | Muy rápido | Baja       | Hash tables, Bloom filters       |
| **Criptográfico** (SHA-256)         | Lento      | Altísima   | Firmas, integridad, passwords    |

> **Regla:** Para **hash tables**, usa funciones **no criptográficas** (son 10–100× más rápidas).

---

# 8. Tamaño de la Tabla y Factor de Carga

## 8.1 Factor de carga (Load Factor)

```text
α = n / m
donde:
  n = número de elementos insertados
  m = tamaño de la tabla
```

| α     | Significado                               |
| ----- | ----------------------------------------- |
| 0.0   | Tabla vacía                               |
| 0.5   | Tabla a media capacidad (ideal para open addressing) |
| 0.75  | Umbral típico de **rehashing**            |
| 1.0   | Tabla llena (chaining sigue funcionando)  |
| > 1.0 | Chaining degrada; open addressing falla   |

## 8.2 Efecto de α en el rendimiento

| α     | Búsqueda (chaining) | Búsqueda (open addressing) |
| ----- | ------------------- | -------------------------- |
| 0.5   | O(1.5)              | O(1.5)                     |
| 0.75  | O(1.75)             | O(2.5)                     |
| 1.0   | O(2)                | O(∞ en el peor caso)       |
| 2.0   | O(3)                | Inviable                   |

> **Conclusión:** Mantener `α < 0.75` es la diferencia entre "instantáneo" y "lento".

---

# 9. Rehashing

## 9.1 ¿Qué es?

Cuando `α` supera un umbral (típicamente **0.75**), creamos una **tabla nueva más grande** (típicamente **2× más grande**) y reinsertamos todos los elementos.

```text
Tabla vieja (m=10, α=0.9):
Índice:  0    1    2    3    4    5    6    7    8    9
       ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
       │ 10 │ 21 │ 32 │ ∅  │ ∅  │ 25 │ 15 │ 35 │ 45 │ ∅  │
       └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
       n=7, α=0.7

Rehashing cuando α > 0.75:
  1. Crear tabla nueva de tamaño 20
  2. Recorrer tabla vieja
  3. Para cada elemento, recalcular h(k) mod 20
  4. Insertar en tabla nueva
```

## 9.2 Implementación

```c
HashTable* rehash(HashTable* old) {
    int newSize = old->size * 2;
    HashTable* newHt = createTable(newSize);

    for (int i = 0; i < old->size; i++) {
        if (old->table[i].occupied == 1) {
            insert(newHt, old->table[i].key, old->table[i].value);
        }
    }

    free(old->table);
    return newHt;
}
```

## 9.3 Análisis amortizado

Aunque un rehashing individual es **O(n)**, sucede tan rara vez que el costo **amortizado por inserción** sigue siendo **O(1)**.

```text
Inserciones: 1, 2, 3, ..., n
Rehashings:  en α=0.75 → log₂(n) veces

Costo amortizado: O(n + n/2 + n/4 + ...) = O(2n) = O(n) total
Costo por inserción: O(n) / n = O(1) amortizado
```

> Misma idea que el `realloc` de un array dinámico: **duplicar tamaño → O(1) amortizado**.

## 9.4 Tamaños de tabla: usar primos

| Mal tamaño              | Por qué                              |
| ----------------------- | ------------------------------------ |
| Potencia de 2 (8, 16)   | Hash por división solo usa bits bajos |
| Múltiplos de 2          | Igual problema                       |

| Buen tamaño             | Por qué                              |
| ----------------------- | ------------------------------------ |
| **Primo** (7, 13, 23)   | Mejora distribución en hashing por división |

```c
// Tamaños primos comunes para tablas hash
int primeSizes[] = {7, 13, 23, 47, 97, 197, 397, 797, 1597, 3203, 6421};
```

---

# 10. Operaciones y Complejidad

## 10.1 Tabla resumen

| Operación | Promedio | Peor caso  | Notas                              |
| --------- | -------- | ---------- | ---------------------------------- |
| Insertar  | **O(1)** | O(n)       | Peor = todos al mismo bucket       |
| Buscar    | **O(1)** | O(n)       | Peor = colisiones masivas          |
| Eliminar  | **O(1)** | O(n)       | Más caro con tombstones            |
| Espacio   | **O(n)** | O(n)       | + overhead de buckets vacíos       |

> El **peor caso O(n)** es evitable con una buena función hash y `α` controlado. Por eso el caso **promedio es O(1)**.

## 10.2 Comparación con otras estructuras

| Estructura             | Buscar   | Insertar | Eliminar | Ordenado |
| ---------------------- | -------- | -------- | -------- | -------- |
| **Array no ordenado**  | O(n)     | O(1)     | O(n)     | ❌        |
| **Array ordenado**     | O(log n) | O(n)     | O(n)     | ✅        |
| **Lista enlazada**     | O(n)     | O(1)     | O(1)     | ❌        |
| **BST balanceado**    | O(log n) | O(log n) | O(log n) | ✅        |
| **Hash Table**         | **O(1)** | **O(1)** | **O(1)** | ❌        |

> **Hash table gana en velocidad pura**, pero pierde la noción de orden.

---

# 11. Hashing en el Mundo Real

## 11.1 Aplicaciones

| Aplicación                          | Por qué hash                                  |
| ----------------------------------- | --------------------------------------------- |
| **Diccionarios / Maps**             | Búsqueda instantánea de clave→valor           |
| **Conjuntos (Sets)**                | Verificar pertenencia en O(1)                |
| **Cachés (Memcached, Redis)**       | Lookup de páginas/resultados en O(1)          |
| **Bases de datos** (índices hash)   | Búsqueda por clave primaria                  |
| **Deduplicación**                   | Detectar archivos repetidos por su hash       |
| **Tablas de símbolos** (compiladores)| Resolver variables y funciones                |
| **Bloom filters**                   | Test de pertenencia con espacio mínimo        |
| **Distributed hash tables** (DHT)   | Chord, Pastry, BitTorrent                     |
| **Git**                             | Identifica objetos por SHA-1                  |
| **Password storage**                | bcrypt, argon2 → almacenan hashes, no texto   |

## 11.2 Implementaciones reales

| Lenguaje / Sistema        | Estructura interna                      |
| ------------------------- | --------------------------------------- |
| **Python `dict`**         | Open addressing con probing aleatorio   |
| **Java `HashMap`**        | Chaining (lista → árbol rojo-negro si k>8) |
| **C++ `unordered_map`**   | Chaining con buckets                    |
| **Go `map`**              | Open addressing                         |
| **Redis**                 | Hash table + skiplist                   |

## 11.3 Variantes especializadas

| Variante               | Característica                                       |
| ---------------------- | ---------------------------------------------------- |
| **Consistent Hashing** | Distribuye claves entre nodos con mínimo rebalanceo  |
| **Perfect Hashing**    | Hash sin colisiones para conjuntos estáticos         |
| **Cuckoo Hashing**     | Dos funciones hash, garantiza O(1) en el peor caso   |
| **Rolling Hash**       | Hash actualizable en O(1) al deslizar (Rabin-Karp)   |
| **Universal Hashing**  | Familia de funciones hash elegidas al azar           |
| **Locality-Sensitive** | Claves similares → hashes similares                  |

---

# 12. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                          | Consecuencia                                |
| ---------------------------------------------- | ------------------------------------------- |
| Usar tamaño potencia de 2 con mod              | Solo se usan bits bajos de la clave         |
| Función hash mal diseñada (no uniforme)        | Colisiones excesivas → degrada a O(n)       |
| Ignorar el factor de carga                    | Tabla saturada → rendimiento colapsa        |
| No usar tombstone en open addressing           | Búsquedas incorrectas tras borrar           |
| Usar MD5/SHA para hash tables                  | 100× más lento que Murmur, sin beneficio    |
| Hardcodear el tamaño de la tabla              | Tabla pequeña → α alto → lentitud           |
| Asumir que las claves son únicas               | Implementar lógica de duplicados mal        |
| Olvidar el caso de tabla llena en open addr.   | Loop infinito en inserción                 |

### ✅ Buenas Prácticas

| Práctica                                            | Razón                                    |
| --------------------------------------------------- | ---------------------------------------- |
| Usar tamaño **primo** para la tabla                | Mejor distribución                       |
| Mantener `α < 0.75` con rehashing automático       | Garantiza O(1) promedio                  |
| Usar MurmurHash o xxHash para hash tables           | Rápido y buena distribución              |
| Usar SHA-256 solo cuando se necesita criptografía  | Contraseñas, integridad, firmas          |
| Hacer rehashing al duplicar tamaño                 | O(1) amortizado por inserción            |
| Probar con datos reales antes de elegir `m`        | Patrones de acceso importan              |
| Documentar la estrategia de colisión elegida       | Mantenibilidad                           |
| Manejar correctamente el caso de clave no encontrada | Retornar valor centinela o NULL        |

---

# 13. Intuición de Ingeniería

> **Hashing es la estructura de datos más usada en producción** (Map, dict, HashMap, objeto JS).
> La promesa de O(1) promedio es **casi siempre cumplida** con una buena función hash y un factor de carga controlado.

### Cuándo usar una Hash Table

| ✅ Usar hash table                                  | ❌ Evitar hash table                |
| --------------------------------------------------- | ----------------------------------- |
| Lookup por clave sin orden                          | Necesitas datos ordenados            |
| Insertar/buscar/eliminar con frecuencia similar     | Necesitas el mínimo/máximo           |
| Las claves no tienen orden natural                  | Iterar en orden es crítico          |
| Cachés, índices, sets, diccionarios                 | Búsqueda por rango (`<`, `>`)       |
| Acceso aleatorio uniforme                           | Necesitas persistencia de orden entre inserciones |

### La regla mnemotécnica

> **Si lo que necesitas es "dame el valor asociado a esta clave" → Hash Table.**
> **Si lo que necesitas es "dame los valores en orden" → usa otra estructura (BST, skiplist).**

### Comparación final con la vida real

| Concepto abstracto       | Análogo del mundo real                  |
| ------------------------ | --------------------------------------- |
| **Clave**                | Tu número de socio                     |
| **Función hash**         | El casillero asignado por la recepcionista |
| **Tabla**                | El conjunto de casilleros              |
| **Colisión**             | Dos socios con mismo casillero         |
| **Chaining**             | Lista de espera en cada casillero      |
| **Open addressing**      | "Si tu casillero está lleno, usa el siguiente" |
| **Rehashing**            | "Construimos un casillero más grande"   |
| **Factor de carga**      | Qué tan lleno está el gimnasio         |

> **Si entiendes la analogía del casillero de gimnasio, entiendes hashing.**
