# Strings — Arrays de Caracteres

> **Idea central:** Un string NO es mágico — es un **array de `char`** con una regla especial: termina en `'\0'`.
> Toda operación sobre strings es esencialmente una **operación sobre arrays** que recorre hasta encontrar el null terminator.

---

## Tabla de Contenidos

1. [Concepto de String](#1-concepto-de-string)
2. [Representación en Memoria y ASCII](#2-representación-en-memoria-y-ascii)
3. [Creación y Almacenamiento](#3-creación-y-almacenamiento)
4. [Operaciones Fundamentales](#4-operaciones-fundamentales)
5. [Manipulación de Caracteres](#5-manipulación-de-caracteres)
6. [Operaciones de Comparación](#6-operaciones-de-comparación)
7. [Funciones de la Biblioteca Estándar](#7-funciones-de-la-biblioteca-estándar)
8. [Problemas Clásicos](#8-problemas-clásicos)
9. [Resumen de Complejidad](#9-resumen-de-complejidad)
10. [Errores Comunes y Buenas Prácticas](#10-errores-comunes-y-buenas-prácticas)
11. [Intuición de Ingeniería](#11-intuición-de-ingeniería)

---

# 1. Concepto de String

## 1.1 ¿Qué es un string en C?

Un **string** es un **array de caracteres** terminado por el carácter nulo `'\0'` (null terminator).

```c
char str[] = "HELLO";
```

```text
Índice:   0     1     2     3     4     5
        ┌─────┬─────┬─────┬─────┬─────┬─────┐
        │ 'H' │ 'E' │ 'L' │ 'L' │ 'O' │'\0' │
        └─────┴─────┴─────┴─────┴─────┴─────┘
        ├──── contenido visible ─────┤  ↑
                                    null terminator
```

> El `'\0'` **no es visible** pero **siempre está ahí**. Ocupa 1 byte extra.
> `"HELLO"` tiene 5 caracteres pero ocupa **6 bytes**.

## 1.2 Propiedades

| Propiedad                | Valor                                    |
| ------------------------ | ---------------------------------------- |
| Tipo base                | `char` (1 byte por carácter)             |
| Terminación              | `'\0'` (valor ASCII = 0)                 |
| Acceso por índice        | O(1) — igual que cualquier array         |
| Conocer longitud         | O(n) — hay que recorrer hasta `'\0'`     |
| Tamaño en memoria        | `strlen(str) + 1` bytes                  |
| Mutable                  | Depende de cómo se declare               |

---

# 2. Representación en Memoria y ASCII

## 2.1 Tabla ASCII (fragmento clave)

Cada carácter se almacena como un **número entero** según la tabla ASCII:

```text
Carácter     Valor ASCII     Rango
─────────────────────────────────────
'0'–'9'      48–57           Dígitos
'A'–'Z'      65–90           Mayúsculas
'a'–'z'      97–122          Minúsculas
' '          32              Espacio
'\0'         0               Null terminator
'\n'         10              Nueva línea
```

### Relaciones clave

| Relación                    | Fórmula              | Ejemplo              |
| --------------------------- | -------------------- | -------------------- |
| Mayúscula → Minúscula      | `c + 32`             | `'A'(65) → 'a'(97)` |
| Minúscula → Mayúscula      | `c - 32`             | `'a'(97) → 'A'(65)` |
| Char dígito → Entero       | `c - '0'`            | `'5'(53) → 5`        |
| Entero → Char dígito       | `n + '0'`            | `5 → '5'(53)`        |
| Índice letra (0-based)     | `c - 'a'` o `c - 'A'`| `'c' → 2`           |

## 2.2 String en memoria

```c
char str[] = "Hi!";
```

```text
Dirección   Valor (char)   Valor (ASCII)   Índice
┌──────────┬──────────────┬───────────────┬────────┐
│ 0x1000   │     'H'      │      72       │ str[0] │
│ 0x1001   │     'i'      │     105       │ str[1] │
│ 0x1002   │     '!'      │      33       │ str[2] │
│ 0x1003   │    '\0'      │       0       │ str[3] │
└──────────┴──────────────┴───────────────┴────────┘
```

> Cada `char` ocupa exactamente **1 byte**, así que las direcciones incrementan de 1 en 1.

---

# 3. Creación y Almacenamiento

## 3.1 String literal (read-only)

```c
char *str = "HELLO";     // puntero a string literal
```

- Almacenado en **memoria de solo lectura** (segmento DATA/TEXT)
- **No se puede modificar** → `str[0] = 'h'` es **Undefined Behavior**

## 3.2 Array de caracteres (mutable)

```c
char str[] = "HELLO";   // copia en el stack — mutable
```

- Almacenado en el **stack**
- **Se puede modificar** → `str[0] = 'h'` es válido

## 3.3 Dinámico (heap)

```c
char *str = (char*)malloc(6 * sizeof(char));  // 5 chars + '\0'
strcpy(str, "HELLO");
// ... usar ...
free(str);
```

## 3.4 Comparación

| Método              | Ubicación    | Mutable | Tamaño         |
| ------------------- | ------------ | ------- | -------------- |
| `char *s = "ABC";`  | DATA (R/O)   | **No**  | Fijo           |
| `char s[] = "ABC";` | Stack        | **Sí**  | Fijo (4 bytes) |
| `malloc + strcpy`   | Heap         | **Sí**  | Dinámico       |

> **Regla:** Si necesitas modificar el string, usa `char s[]` o `malloc`. Nunca modifiques un literal.

---

# 4. Operaciones Fundamentales

## 4.1 Length (Longitud)

Recorre hasta encontrar `'\0'`.

| Complejidad | Descripción                      |
| ----------- | -------------------------------- |
| **O(n)**    | Debe recorrer todo el string     |

```c
int length(char *str) {
    int i = 0;
    while (str[i] != '\0')
        i++;
    return i;
}
```

> A diferencia de arrays genéricos donde pasas `n`, los strings **no necesitan** el tamaño — el `'\0'` marca el final.

---

## 4.2 Reverse (Invertir)

Swap desde los extremos hacia el centro. In-place.

| Complejidad | Espacio extra |
| ----------- | ------------- |
| **O(n)**    | O(1)          |

```text
Antes:   H  E  L  L  O
         i→           ←j    swap(H, O)
         O  E  L  L  H
            i→     ←j       swap(E, L)
         O  L  L  E  H
               ij            i ≥ j → termina
```

```c
void reverse(char *str) {
    int i = 0, j = length(str) - 1;
    while (i < j) {
        char temp = str[i];
        str[i] = str[j];
        str[j] = temp;
        i++; j--;
    }
}
```

---

## 4.3 Copy (Copiar)

Copia carácter por carácter incluyendo `'\0'`.

| Complejidad | Descripción             |
| ----------- | ----------------------- |
| **O(n)**    | Recorre todo el source  |

```c
void copy(char *dest, char *src) {
    int i = 0;
    while (src[i] != '\0') {
        dest[i] = src[i];
        i++;
    }
    dest[i] = '\0';    // ⚠️ No olvidar el null terminator
}
```

---

## 4.4 Concatenate (Concatenar)

Agrega `src` al final de `dest`.

| Complejidad   | Descripción                          |
| ------------- | ------------------------------------ |
| **O(n + m)**  | Encontrar final de dest + copiar src |

```text
dest = "HEL"     src = "LO"

Paso 1: encontrar '\0' en dest → índice 3
Paso 2: copiar src desde índice 3

Resultado: "HELLO\0"
```

```c
void concat(char *dest, char *src) {
    int i = 0, j = 0;
    while (dest[i] != '\0')     // ir al final de dest
        i++;
    while (src[j] != '\0') {    // copiar src
        dest[i] = src[j];
        i++; j++;
    }
    dest[i] = '\0';
}
```

> **Precondición:** `dest` debe tener suficiente espacio para ambos strings.

---

## 4.5 Compare (Comparar)

Compara carácter por carácter lexicográficamente.

| Complejidad | Descripción                           |
| ----------- | ------------------------------------- |
| **O(n)**    | Hasta encontrar diferencia o `'\0'`   |

```c
int compare(char *a, char *b) {
    int i = 0;
    while (a[i] == b[i] && a[i] != '\0')
        i++;
    return a[i] - b[i];
}
```

| Resultado        | Significado            |
| ---------------- | ---------------------- |
| `0`              | Strings iguales        |
| `> 0`            | `a` es mayor que `b`  |
| `< 0`            | `a` es menor que `b`  |

**Ejemplo:**

```text
compare("ABC", "ABD")  →  'C' - 'D' = 67 - 68 = -1  →  "ABC" < "ABD"
compare("ABC", "ABC")  →  '\0' - '\0' = 0             →  iguales
compare("B", "A")      →  'B' - 'A' = 66 - 65 = 1    →  "B" > "A"
```

---

## 4.6 Substring Search (Buscar subcadena)

Busca la primera ocurrencia de `pattern` dentro de `text`.

| Complejidad       | Descripción                |
| ------------------ | -------------------------- |
| **O(n × m)** naïve | Comparar en cada posición  |

```c
int find(char *text, char *pattern) {
    int n = length(text);
    int m = length(pattern);

    for (int i = 0; i <= n - m; i++) {
        int j = 0;
        while (j < m && text[i + j] == pattern[j])
            j++;
        if (j == m)
            return i;       // encontrado en posición i
    }
    return -1;              // no encontrado
}
```

---

# 5. Manipulación de Caracteres

## 5.1 Cambiar a Mayúsculas / Minúsculas

| Operación | Fórmula      | Complejidad |
| --------- | ------------ | ----------- |
| toLower   | `c + 32`     | O(n)        |
| toUpper   | `c - 32`     | O(n)        |

```c
void toLower(char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] >= 'A' && str[i] <= 'Z')
            str[i] += 32;
    }
}

void toUpper(char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] >= 'a' && str[i] <= 'z')
            str[i] -= 32;
    }
}
```

---

## 5.2 Contar Vocales

| Complejidad | Descripción                   |
| ----------- | ----------------------------- |
| **O(n)**    | Verificar cada carácter       |

```c
int countVowels(char *str) {
    int count = 0;
    for (int i = 0; str[i] != '\0'; i++) {
        char c = str[i];
        if (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u' ||
            c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U')
            count++;
    }
    return count;
}
```

---

## 5.3 Contar Palabras

| Complejidad | Descripción                             |
| ----------- | --------------------------------------- |
| **O(n)**    | Contar transiciones espacio → no-espacio |

```c
int countWords(char *str) {
    int words = 0;
    int inWord = 0;

    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] != ' ' && !inWord) {
            words++;
            inWord = 1;
        } else if (str[i] == ' ') {
            inWord = 0;
        }
    }
    return words;
}
```

> Este método maneja correctamente **múltiples espacios** consecutivos.

---

## 5.4 Validar String

| Función     | Condición                         | Complejidad |
| ----------- | --------------------------------- | ----------- |
| `isAlpha`   | Solo letras (A-Z, a-z)           | O(n)        |
| `isAlnum`   | Letras + dígitos (0-9)           | O(n)        |
| `isDigit`   | Solo dígitos (0-9)               | O(n)        |

```c
int isAlpha(char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (!((str[i] >= 'A' && str[i] <= 'Z') ||
              (str[i] >= 'a' && str[i] <= 'z')))
            return 0;
    }
    return 1;
}

int isAlnum(char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (!((str[i] >= 'A' && str[i] <= 'Z') ||
              (str[i] >= 'a' && str[i] <= 'z') ||
              (str[i] >= '0' && str[i] <= '9')))
            return 0;
    }
    return 1;
}

int isDigit(char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (!(str[i] >= '0' && str[i] <= '9'))
            return 0;
    }
    return 1;
}
```

---

# 6. Operaciones de Comparación

## 6.1 Palíndromo

Se lee igual de izquierda a derecha que de derecha a izquierda.

| Complejidad | Espacio |
| ----------- | ------- |
| **O(n)**    | O(1)    |

```text
"racecar"
 i→          ←j
 r == r ✓
  a == a ✓
   c == c ✓
    e        i ≥ j → es palíndromo ✓
```

```c
int isPalindrome(char *str) {
    int i = 0, j = length(str) - 1;
    while (i < j) {
        if (str[i] != str[j])
            return 0;
        i++; j--;
    }
    return 1;
}
```

---

# 7. Funciones de la Biblioteca Estándar

`#include <string.h>` proporciona funciones optimizadas:

| Función              | Equivalente nuestro  | Descripción                          |
| -------------------- | -------------------- | ------------------------------------ |
| `strlen(s)`          | `length(s)`          | Retorna longitud (sin `'\0'`)        |
| `strcpy(dest, src)`  | `copy(dest, src)`    | Copia `src` a `dest`                 |
| `strncpy(d, s, n)`   | —                    | Copia máximo `n` caracteres (más seguro) |
| `strcat(dest, src)`  | `concat(dest, src)`  | Concatena `src` al final de `dest`   |
| `strncat(d, s, n)`   | —                    | Concatena máximo `n` caracteres      |
| `strcmp(a, b)`        | `compare(a, b)`      | Compara lexicográficamente           |
| `strncmp(a, b, n)`   | —                    | Compara máximo `n` caracteres        |
| `strstr(text, pat)`  | `find(text, pat)`    | Busca subcadena                      |
| `strchr(s, c)`        | —                    | Busca primera ocurrencia de `c`      |
| `strrchr(s, c)`       | —                    | Busca última ocurrencia de `c`       |
| `strtok(s, delim)`    | —                    | Tokeniza (divide) por delimitador    |

### Ejemplo: strtok (Tokenización)

```c
#include <string.h>
#include <stdio.h>

char str[] = "Hola Mundo Cruel";
char *token = strtok(str, " ");

while (token != NULL) {
    printf("%s\n", token);
    token = strtok(NULL, " ");
}
```

```text
Output:
Hola
Mundo
Cruel
```

> **⚠️ Cuidado:** `strtok` **modifica** el string original (reemplaza delimitadores con `'\0'`).

### Versiones seguras (recomendadas)

| Insegura     | Segura             | Por qué                              |
| ------------ | ------------------ | ------------------------------------- |
| `strcpy`     | `strncpy`          | Evita buffer overflow                 |
| `strcat`     | `strncat`          | Limita cuánto se copia                |
| `strcmp`      | `strncmp`          | Limita cuánto se compara              |
| `strtok`     | `strtok_r`         | Thread-safe (reentrante)              |

---

# 8. Problemas Clásicos

## 8.1 Encontrar Duplicados

### Método Hash (array de conteo)

Usar un array de 26 posiciones como tabla de frecuencias:

| Complejidad | Espacio  |
| ----------- | -------- |
| **O(n)**    | O(1) — array fijo de 26 |

```c
void duplicates(char *str) {
    int H[26] = {0};

    for (int i = 0; str[i] != '\0'; i++)
        H[str[i] - 'a']++;

    for (int i = 0; i < 26; i++) {
        if (H[i] > 1)
            printf("'%c' aparece %d veces\n", i + 'a', H[i]);
    }
}
```

### Método Bitwise (optimizado)

Usa los **bits de un `int`** como flags. Cada bit = un carácter.

| Complejidad | Espacio  |
| ----------- | -------- |
| **O(n)**    | **O(1)** — un solo `int` |

```text
H = 0000...0000  (32 bits)

Procesar 'a': bit 0 → H = ...0001, no estaba → OK
Procesar 'b': bit 1 → H = ...0011, no estaba → OK
Procesar 'a': bit 0 → H & 0001 > 0 → ¡DUPLICADO!
```

```c
void duplicatesBitwise(char *str) {
    int H = 0;

    for (int i = 0; str[i] != '\0'; i++) {
        int bit = 1 << (str[i] - 'a');

        if (H & bit)
            printf("Duplicado: %c\n", str[i]);
        else
            H |= bit;      // encender bit
    }
}
```

> **Limitación:** Solo funciona para 26 letras minúsculas (cabe en un `int` de 32 bits).

---

## 8.2 Anagramas

Dos strings son **anagramas** si tienen los **mismos caracteres con la misma frecuencia**.

```text
"listen" ↔ "silent"    → ✅ Anagrama
"hello"  ↔ "world"     → ❌ No
```

| Complejidad | Descripción                    |
| ----------- | ------------------------------ |
| **O(n)**    | Contar frecuencias y comparar  |

```c
int isAnagram(char *a, char *b) {
    int H[26] = {0};

    // Incrementar por cada carácter de 'a'
    for (int i = 0; a[i] != '\0'; i++)
        H[a[i] - 'a']++;

    // Decrementar por cada carácter de 'b'
    for (int i = 0; b[i] != '\0'; i++) {
        H[b[i] - 'a']--;
        if (H[b[i] - 'a'] < 0)
            return 0;       // 'b' tiene un carácter extra
    }

    // Verificar que todo sea 0
    for (int i = 0; i < 26; i++) {
        if (H[i] != 0)
            return 0;       // 'a' tiene un carácter extra
    }
    return 1;
}
```

---

## 8.3 Permutaciones

Generar **todas las formas posibles** de ordenar los caracteres.

```text
"ABC" → ABC, ACB, BAC, BCA, CAB, CBA    (3! = 6 permutaciones)
```

| Complejidad | Descripción                    |
| ----------- | ------------------------------ |
| **O(n!)**   | n! permutaciones posibles      |

### Método: Backtracking

Fija un carácter en cada posición y permuta el resto recursivamente:

```text
         ABC
       /  |  \
     ABC  BAC  CBA      ← fijar posición 0
     / \  / \  / \
   ABC ACB BAC BCA CBA CAB  ← fijar posición 1
```

```c
void swap(char *a, char *b) {
    char temp = *a;
    *a = *b;
    *b = temp;
}

void permute(char *str, int l, int h) {
    if (l == h) {
        printf("%s\n", str);
        return;
    }
    for (int i = l; i <= h; i++) {
        swap(&str[l], &str[i]);         // elegir
        permute(str, l + 1, h);         // explorar
        swap(&str[l], &str[i]);         // backtrack (deshacer)
    }
}

// Uso: permute(str, 0, length(str) - 1);
```

---

## 8.4 Comparación de enfoques

| Problema      | Naïve              | Optimizado              |
| ------------- | ------------------ | ----------------------- |
| Duplicados    | O(n²) dos loops    | O(n) hash / O(1) bits  |
| Anagramas     | O(n log n) sorting | **O(n)** conteo         |
| Permutaciones | —                  | O(n!) backtracking      |

---

# 9. Resumen de Complejidad

| Operación          | Complejidad     | Nota                              |
| ------------------ | --------------- | --------------------------------- |
| **Length**          | O(n)            | Recorrer hasta `'\0'`             |
| **Access `s[i]`**  | O(1)            | Igual que cualquier array         |
| **Reverse**        | O(n)            | In-place, O(1) espacio            |
| **Copy**           | O(n)            | Carácter por carácter             |
| **Concatenate**    | O(n + m)        | Encontrar final + copiar          |
| **Compare**        | O(n)            | Hasta diferencia o `'\0'`         |
| **Substring search** | O(n × m)      | Naïve; KMP es O(n + m)           |
| **toLower/toUpper**| O(n)            | Recorrer cada carácter            |
| **Count vowels/words** | O(n)        | Un solo recorrido                 |
| **Validar**        | O(n)            | Verificar cada carácter           |
| **Palíndromo**     | O(n)            | Dos punteros                      |
| **Duplicados**     | O(n)            | Hash array o bitwise              |
| **Anagramas**      | O(n)            | Array de conteo                   |
| **Permutaciones**  | O(n!)           | Backtracking                      |

---

# 10. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                         | Consecuencia                              |
| --------------------------------------------- | ----------------------------------------- |
| Olvidar espacio para `'\0'`                   | Buffer overflow / sin terminación         |
| Modificar string literal `char *s = "abc"`    | Undefined Behavior (segfault)             |
| No verificar `'\0'` al iterar                 | Leer fuera del string (basura)            |
| `str[i] - 'a'` sin validar que sea minúscula | Índice negativo o fuera de rango          |
| `strcpy` sin verificar tamaño de destino      | Buffer overflow                           |
| Asumir ASCII sin controlar encoding           | Falla con UTF-8 / caracteres especiales   |
| Comparar strings con `==`                     | Compara **punteros**, no contenido        |
| `strtok` en string literal                    | UB — strtok modifica el string            |

### ✅ Buenas Prácticas

| Práctica                                      | Razón                                     |
| --------------------------------------------- | ----------------------------------------- |
| Siempre reservar `n + 1` bytes                | Espacio para `'\0'`                       |
| Usar `char s[]` para strings mutables         | Evitar modificar literales                |
| Usar `strncpy` / `strncat` en vez de `strcpy` / `strcat` | Prevenir buffer overflow    |
| Validar caracteres antes de `c - 'a'`         | Evitar índices inválidos                  |
| Usar `strcmp(a, b) == 0` para comparar        | Compara contenido, no punteros            |
| Preferir conteo sobre sorting para anagramas  | O(n) vs O(n log n)                        |
| Usar funciones auxiliares (`length`, `swap`)   | Código más limpio y reutilizable          |

```c
// ❌ Compara punteros (direcciones)
if (str1 == str2) { ... }

// ✅ Compara contenido
if (strcmp(str1, str2) == 0) { ... }
```

---

# 11. Intuición de Ingeniería

> Strings son **arrays con `'\0'`**. Nada más, nada menos.
> Toda regla de arrays aplica. Toda limitación de arrays también.

### ¿Por qué la mayoría de operaciones son O(n)?

```text
Para saber la longitud:     recorrer hasta '\0'    → O(n)
Para copiar:                recorrer hasta '\0'     → O(n)
Para comparar:              recorrer hasta diferencia → O(n)
Para concatenar:            encontrar final + copiar → O(n + m)
```

> **No hay atajos.** El `'\0'` obliga a recorrer para saber dónde termina.
> (Esto contrasta con arrays genéricos donde pasas `n` directamente.)

### Estrategias de optimización

| Estrategia                     | Aplica cuando                         | Ahorro                    |
| ------------------------------ | ------------------------------------- | ------------------------- |
| Array de conteo (hash)         | Frecuencia de caracteres              | O(n²) → O(n)             |
| Bitwise flags                  | Solo letras minúsculas (≤26)          | Espacio O(26) → O(1)     |
| Dos punteros                   | Palíndromo, reverse                   | Evita string auxiliar     |
| Backtracking                   | Generar combinaciones/permutaciones   | Exploración sistemática   |
| Funciones `<string.h>`         | Cualquier operación común             | Implementaciones optimizadas del sistema |

### Relación con otros archivos

| Tema                     | Archivo           |
| ------------------------ | ----------------- |
| Arrays a bajo nivel      | Arrays CDT.md     |
| Operaciones sobre arrays | Arrays ADT.md     |
| Matrices (arrays 2D)     | Matrices.md       |
| **Strings (este)**       | Arrays de `char`  |
