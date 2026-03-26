# Linked Lists — Estructuras Dinámicas Enlazadas

> **Idea central:** Un array dice "dame espacio contiguo y fijo". Una lista enlazada dice "dame espacio cuando lo necesite, donde sea".
> Las listas enlazadas sacrifican **acceso directo O(1)** a cambio de **inserciones/eliminaciones O(1)** y **tamaño dinámico ilimitado**.
> Entender este trade-off es entender el 90% de la ingeniería de estructuras de datos.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Motivación: Limitaciones de los Arrays](#1-motivación-limitaciones-de-los-arrays)
2. [Modelo de Nodos y Punteros](#2-modelo-de-nodos-y-punteros)
3. [Representación en Memoria](#3-representación-en-memoria)

**Parte II — Singly Linked List**
4. [Singly Linked List — Concepto](#4-singly-linked-list--concepto)
5. [Operaciones de Recorrido](#5-operaciones-de-recorrido)
6. [Búsqueda](#6-búsqueda)
7. [Inserción](#7-inserción)
8. [Eliminación](#8-eliminación)
9. [Operaciones Avanzadas](#9-operaciones-avanzadas)

**Parte III — Circular Linked List**
10. [Circular Linked List — Concepto](#10-circular-linked-list--concepto)
11. [Operaciones en Circular List](#11-operaciones-en-circular-list)

**Parte IV — Doubly Linked List**
12. [Doubly Linked List — Concepto](#12-doubly-linked-list--concepto)
13. [Operaciones en Doubly Linked List](#13-operaciones-en-doubly-linked-list)

**Parte V — Circular Doubly Linked List**
14. [Circular Doubly Linked List — Concepto](#14-circular-doubly-linked-list--concepto)
15. [Operaciones en Circular Doubly List](#15-operaciones-en-circular-doubly-list)

**Parte VI — Síntesis**
16. [Comparación entre Variantes](#16-comparación-entre-variantes)
17. [Resumen de Complejidad](#17-resumen-de-complejidad)
18. [Errores Comunes y Buenas Prácticas](#18-errores-comunes-y-buenas-prácticas)
19. [Intuición de Ingeniería](#19-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS

---

# 1. Motivación: Limitaciones de los Arrays

## 1.1 ¿Por qué no basta con arrays?

Los arrays son poderosos, pero tienen **tres limitaciones fundamentales**:

```text
┌───────────────────────────────────────────────────────────────┐
│                   LIMITACIONES DE ARRAYS                      │
├──────────────────┬────────────────────────────────────────────┤
│ Tamaño fijo      │ Debes declarar el tamaño por adelantado.   │
│                  │ Si crece → realloc (copia todo, O(n)).     │
├──────────────────┼────────────────────────────────────────────┤
│ Memoria contigua │ Necesitas un bloque continuo en RAM.       │
│                  │ Si la RAM está fragmentada → falla.        │
├──────────────────┼────────────────────────────────────────────┤
│ Inserción/Elim.  │ Insertar al inicio o medio → mover todo    │
│ costosa          │ hacia la derecha/izquierda → O(n).         │
└──────────────────┴────────────────────────────────────────────┘
```

## 1.2 Ejemplo concreto

Insertar el valor `15` en la posición 0 de un array de 5 elementos:

```text
Antes:    [10, 20, 30, 40, 50]

Paso 1:   mover 50 →           [10, 20, 30, 40, _, 50]
Paso 2:   mover 40 →           [10, 20, 30, _, 40, 50]
Paso 3:   mover 30 →           [10, 20, _, 30, 40, 50]
Paso 4:   mover 20 →           [10, _, 20, 30, 40, 50]
Paso 5:   mover 10 →           [_, 10, 20, 30, 40, 50]
Paso 6:   insertar 15 →        [15, 10, 20, 30, 40, 50]

Total: 5 movimientos + 1 inserción = O(n)
```

> Con 1,000,000 elementos, insertar al inicio mueve **un millón** de valores. Inaceptable.

## 1.3 La solución: estructuras dinámicas

¿Y si cada elemento pudiera vivir **en cualquier parte** de la memoria, y simplemente **apuntara** al siguiente?

```text
Array (contiguo):
┌────┬────┬────┬────┬────┐
│ 10 │ 20 │ 30 │ 40 │ 50 │     ← bloque continuo
└────┴────┴────┴────┴────┘

Lista enlazada (dispersa):
┌────┬──┐   ┌────┬──┐   ┌────┬──┐   ┌────┬──┐   ┌────┬──────┐
│ 10 │ ─┼──→│ 20 │ ─┼──→│ 30 │ ─┼──→│ 40 │ ─┼──→│ 50 │ NULL │
└────┴──┘   └────┴──┘   └────┴──┘   └────┴──┘   └────┴──────┘
 0x100       0x400       0x200       0x800       0x500
              ↑ no contiguo ↑
```

> **No se necesita memoria contigua.** Cada nodo vive donde haya espacio.

---

# 2. Modelo de Nodos y Punteros

## 2.1 ¿Qué es un nodo?

Un **nodo** es la unidad fundamental de una lista enlazada. Contiene:

| Campo    | Tipo            | Propósito                            |
| -------- | --------------- | ------------------------------------ |
| `data`   | tipo de dato    | El valor almacenado                  |
| `next`   | puntero a nodo  | Dirección del siguiente nodo         |

```c
typedef struct Node {
    int data;
    struct Node *next;
} Node;
```

> `struct Node *next` es una **auto-referencia**: un nodo contiene un puntero a otro nodo del mismo tipo.

## 2.2 Diagrama de un nodo

```text
┌────────────────────────┐
│         Node           │
├────────────┬───────────┤
│   data     │   next    │
│   (int)    │ (Node *)  │
│   4 bytes  │  8 bytes  │
└────────────┴───────────┘
      ↑            ↑
   el valor    puntero al
  almacenado   siguiente nodo
```

> En un sistema de 64 bits, cada nodo de `int` ocupa **12 bytes** (4 data + 8 puntero), mientras que un `int` en un array ocupa solo **4 bytes**. Este es el **costo del dinamismo**.

## 2.3 Creación de un nodo

```c
#include <stdlib.h>

Node* createNode(int value) {
    Node *newNode = (Node*)malloc(sizeof(Node));
    if (newNode == NULL) {
        printf("Error: malloc failed\n");
        exit(1);
    }
    newNode->data = value;
    newNode->next = NULL;
    return newNode;
}
```

```text
Después de createNode(42):

         heap
         ┌───────────┬──────────┐
newNode →│ data = 42  │ next = NULL │
         └───────────┴──────────┘
```

## 2.4 El puntero `head`

El **head** es un puntero al **primer nodo** de la lista. Es la **única forma de acceder** a la lista completa.

```c
Node *head = NULL;   // lista vacía
```

```text
head = NULL     →  lista vacía (0 nodos)
head → [10|─]  →  lista con 1 nodo
head → [10|─]→[20|─]→[30|NULL]  →  lista con 3 nodos
```

> **Si pierdes `head`, pierdes toda la lista.** No hay forma de recuperar los nodos.

---

# 3. Representación en Memoria

## 3.1 Array vs Lista en RAM

```text
ARRAY (contiguo en stack o heap):

Dirección   Valor
0x1000      10      ← arr[0]
0x1004      20      ← arr[1]
0x1008      30      ← arr[2]
0x100C      40      ← arr[3]


LINKED LIST (disperso en heap):

Dirección   data    next
0x2010      10      0x2050    ← head apunta aquí
0x2050      20      0x2030
0x2030      30      0x2080
0x2080      40      NULL

Orden lógico: 10 → 20 → 30 → 40
Orden físico: 0x2010, 0x2050, 0x2030, 0x2080  (¡NO contiguo!)
```

## 3.2 Impacto en el CPU cache

```text
Array — Cache-friendly:
┌─────────────────────────────────────────────┐
│ Cache line (64 bytes) carga 16 ints:        │
│ arr[0] arr[1] arr[2] ... arr[15]            │  ← 1 acceso a RAM
└─────────────────────────────────────────────┘

Lista enlazada — Cache-unfriendly:
  node[0] @ 0x2010 → acceso a RAM (miss)
  node[1] @ 0x2050 → acceso a RAM (miss)
  node[2] @ 0x2030 → acceso a RAM (miss)
  ... cada nodo puede causar un cache miss
```

> Las listas enlazadas son **más lentas en la práctica** de lo que sugiere su complejidad teórica, por los cache misses.

## 3.3 Trade-off fundamental

| Aspecto               | Array                    | Linked List                |
| ---------------------- | ------------------------ | -------------------------- |
| Memoria               | Contigua                 | Dispersa                   |
| Tamaño                | Fijo (o realloc)         | Dinámico                   |
| Acceso por índice     | **O(1)**                 | O(n)                       |
| Insertar al inicio    | O(n) — mover todo        | **O(1)**                   |
| Insertar al final     | O(1) amortizado          | O(n) sin tail, O(1) con tail |
| Eliminar al inicio    | O(n) — mover todo        | **O(1)**                   |
| Espacio por elemento  | `sizeof(T)`              | `sizeof(T) + sizeof(ptr)` |
| Cache performance     | **Excelente**            | Pobre                      |

---

# PARTE II — SINGLY LINKED LIST

---

# 4. Singly Linked List — Concepto

## 4.1 Definición

Una **Singly Linked List** (lista enlazada simple) es una secuencia de nodos donde:
- Cada nodo tiene `data` y `next`
- `next` apunta al siguiente nodo
- El último nodo tiene `next = NULL`
- Se accede mediante un puntero `head`

```text
head
 │
 ▼
┌────┬──┐   ┌────┬──┐   ┌────┬──┐   ┌────┬──────┐
│ 10 │ ─┼──→│ 20 │ ─┼──→│ 30 │ ─┼──→│ 40 │ NULL │
└────┴──┘   └────┴──┘   └────┴──┘   └────┴──────┘
```

## 4.2 Estructura base

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

Node* createNode(int value) {
    Node *n = (Node*)malloc(sizeof(Node));
    n->data = value;
    n->next = NULL;
    return n;
}
```

## 4.3 Crear una lista desde un array

```c
Node* createFromArray(int arr[], int n) {
    if (n == 0) return NULL;

    Node *head = createNode(arr[0]);
    Node *tail = head;

    for (int i = 1; i < n; i++) {
        tail->next = createNode(arr[i]);
        tail = tail->next;
    }
    return head;
}
```

```text
int arr[] = {10, 20, 30, 40};
Node *head = createFromArray(arr, 4);

Resultado:
head → [10|─]→[20|─]→[30|─]→[40|NULL]
```

---

# 5. Operaciones de Recorrido

## 5.1 Display (Imprimir)

### Iterativo

```c
void display(Node *head) {
    Node *p = head;
    while (p != NULL) {
        printf("%d → ", p->data);
        p = p->next;
    }
    printf("NULL\n");
}
```

### Recursivo

```c
void displayRec(Node *p) {
    if (p == NULL) {
        printf("NULL\n");
        return;
    }
    printf("%d → ", p->data);
    displayRec(p->next);
}
```

### Recursivo inverso (imprimir al revés)

```c
void displayReverse(Node *p) {
    if (p == NULL) return;
    displayReverse(p->next);   // primero llegar al final
    printf("%d → ", p->data);  // luego imprimir al volver
}
```

```text
displayReverse(head) con head → [10|─]→[20|─]→[30|NULL]

Llamadas:  displayReverse(10) → displayReverse(20) → displayReverse(30) → displayReverse(NULL)
Retorno:                                                                    return
           ← print 30        ← print 20            ← print 10

Output: 30 → 20 → 10 →
```

| Operación       | Complejidad | Espacio         |
| --------------- | ----------- | --------------- |
| Display iter.   | O(n)        | O(1)            |
| Display rec.    | O(n)        | O(n) — stack    |
| Display reverse | O(n)        | O(n) — stack    |

---

## 5.2 Count (Contar nodos)

### Iterativo

```c
int count(Node *head) {
    int c = 0;
    Node *p = head;
    while (p != NULL) {
        c++;
        p = p->next;
    }
    return c;
}
```

### Recursivo

```c
int countRec(Node *p) {
    if (p == NULL) return 0;
    return 1 + countRec(p->next);
}
```

---

## 5.3 Sum (Suma de elementos)

### Iterativo

```c
int sum(Node *head) {
    int total = 0;
    Node *p = head;
    while (p != NULL) {
        total += p->data;
        p = p->next;
    }
    return total;
}
```

### Recursivo

```c
int sumRec(Node *p) {
    if (p == NULL) return 0;
    return p->data + sumRec(p->next);
}
```

---

## 5.4 Max y Min

### Iterativo

```c
int max(Node *head) {
    if (head == NULL) return INT_MIN;
    int m = head->data;
    Node *p = head->next;
    while (p != NULL) {
        if (p->data > m) m = p->data;
        p = p->next;
    }
    return m;
}

int min(Node *head) {
    if (head == NULL) return INT_MAX;
    int m = head->data;
    Node *p = head->next;
    while (p != NULL) {
        if (p->data < m) m = p->data;
        p = p->next;
    }
    return m;
}
```

### Recursivo (max)

```c
int maxRec(Node *p) {
    if (p->next == NULL) return p->data;
    int restMax = maxRec(p->next);
    return (p->data > restMax) ? p->data : restMax;
}
```

| Operación | Complejidad | Espacio (iter) | Espacio (rec) |
| --------- | ----------- | -------------- | ------------- |
| Count     | O(n)        | O(1)           | O(n)          |
| Sum       | O(n)        | O(1)           | O(n)          |
| Max/Min   | O(n)        | O(1)           | O(n)          |

---

# 6. Búsqueda

## 6.1 Linear Search

### Iterativo

```c
Node* linearSearch(Node *head, int key) {
    Node *p = head;
    while (p != NULL) {
        if (p->data == key) return p;
        p = p->next;
    }
    return NULL;
}
```

### Recursivo

```c
Node* linearSearchRec(Node *p, int key) {
    if (p == NULL) return NULL;
    if (p->data == key) return p;
    return linearSearchRec(p->next, key);
}
```

| Caso    | Complejidad |
| ------- | ----------- |
| Mejor   | O(1)        |
| Peor    | O(n)        |
| Promedio | O(n)       |

## 6.2 Búsqueda con Transposición

**Idea:** Después de encontrar un elemento, **moverlo una posición adelante** (swap con el anterior). Elementos frecuentes migran gradualmente al frente.

```text
Antes:    head → [10|─]→[20|─]→[30|─]→[40|NULL]
Buscar 30:
Después:  head → [10|─]→[30|─]→[20|─]→[40|NULL]
                          ↑
                    se movió 1 posición adelante
```

```c
Node* searchTransposition(Node **headRef, int key) {
    Node *prev = NULL;
    Node *curr = *headRef;

    while (curr != NULL) {
        if (curr->data == key) {
            if (prev != NULL) {
                // Swap: mover curr antes de prev
                prev->next = curr->next;
                curr->next = prev;

                // Encontrar el nodo antes de prev para actualizar su next
                // Más simple: swap data
                int temp = prev->data;
                prev->data = curr->data;
                curr->data = temp;

                // Restaurar punteros (el swap fue de data, no de nodos)
                prev->next = curr;   // no, esto no funciona bien

                // Mejor enfoque: swap solo data
            }
            return curr;
        }
        prev = curr;
        curr = curr->next;
    }
    return NULL;
}
```

> **Implementación limpia usando swap de data:**

```c
Node* searchTransposition(Node *head, int key) {
    Node *prev = NULL;
    Node *curr = head;

    while (curr != NULL) {
        if (curr->data == key) {
            if (prev != NULL) {
                // Swap data con el anterior
                int temp = prev->data;
                prev->data = curr->data;
                curr->data = temp;
                return prev;    // ahora el dato está en prev
            }
            return curr;        // ya está al inicio
        }
        prev = curr;
        curr = curr->next;
    }
    return NULL;
}
```

## 6.3 Búsqueda Move-to-Head

**Idea:** Después de encontrar un elemento, **moverlo directamente al frente** de la lista. Más agresivo que transposición.

```text
Antes:    head → [10|─]→[20|─]→[30|─]→[40|NULL]
Buscar 30:
Después:  head → [30|─]→[10|─]→[20|─]→[40|NULL]
                  ↑
            movido directo al frente
```

```c
Node* searchMoveToHead(Node **headRef, int key) {
    Node *prev = NULL;
    Node *curr = *headRef;

    while (curr != NULL) {
        if (curr->data == key) {
            if (prev != NULL) {
                prev->next = curr->next;    // desconectar curr
                curr->next = *headRef;      // curr apunta al antiguo head
                *headRef = curr;            // curr es el nuevo head
            }
            return curr;
        }
        prev = curr;
        curr = curr->next;
    }
    return NULL;
}
```

```text
Paso a paso (buscar 30):

Estado inicial:
  head → [10|─]→[20|─]→[30|─]→[40|NULL]
                  prev   curr

1. prev->next = curr->next
   head → [10|─]→[20|────────]→[40|NULL]
                         [30|─]

2. curr->next = *headRef
   head → [10|─]→[20|─]→[40|NULL]
          [30|─]→[10|...]

3. *headRef = curr
   head → [30|─]→[10|─]→[20|─]→[40|NULL]
```

## 6.4 Comparación de estrategias de búsqueda

| Estrategia      | Búsquedas repetidas | Localidad temporal | Overhead  |
| --------------- | ------------------- | ------------------ | --------- |
| Simple          | Sin mejora          | —                  | Ninguno   |
| Transposición   | Mejora gradual      | Media              | Swap data |
| Move-to-head    | Mejora inmediata    | Alta               | Relink    |

---

# 7. Inserción

## 7.1 Insertar al inicio (prepend)

```text
Antes:    head → [20|─]→[30|NULL]
Insert 10:
Después:  head → [10|─]→[20|─]→[30|NULL]
```

```c
Node* insertFirst(Node *head, int value) {
    Node *n = createNode(value);
    n->next = head;
    return n;       // nuevo head
}
```

| Complejidad |
| ----------- |
| **O(1)**    |

## 7.2 Insertar al final (append)

```text
Antes:    head → [10|─]→[20|NULL]
Append 30:
Después:  head → [10|─]→[20|─]→[30|NULL]
```

```c
Node* insertLast(Node *head, int value) {
    Node *n = createNode(value);
    if (head == NULL) return n;

    Node *p = head;
    while (p->next != NULL)
        p = p->next;

    p->next = n;
    return head;
}
```

| Complejidad | Nota                             |
| ----------- | -------------------------------- |
| **O(n)**    | Debe recorrer hasta el final     |
| **O(1)**    | Si mantienes un puntero `tail`   |

## 7.3 Insertar en posición `pos` (0-indexed)

```text
Antes:    head → [10|─]→[30|─]→[40|NULL]
Insert 20 en pos=1:
Después:  head → [10|─]→[20|─]→[30|─]→[40|NULL]
```

```c
Node* insertAt(Node *head, int value, int pos) {
    if (pos == 0) return insertFirst(head, value);

    Node *p = head;
    for (int i = 0; i < pos - 1 && p != NULL; i++)
        p = p->next;

    if (p == NULL) {
        printf("Error: posición %d fuera de rango\n", pos);
        return head;
    }

    Node *n = createNode(value);
    n->next = p->next;
    p->next = n;
    return head;
}
```

```text
Paso a paso (insert 20 en pos=1):

1. Avanzar a pos-1 = 0:   p → [10|─]
2. Crear nodo:             n = [20|NULL]
3. n->next = p->next:      n = [20|─]→[30|...]
4. p->next = n:            [10|─]→[20|─]→[30|─]→[40|NULL]
```

| Complejidad          | Nota                        |
| -------------------- | --------------------------- |
| **O(n)** peor caso   | Recorrer hasta la posición  |
| **O(1)** pos = 0     | Insertar al inicio          |

## 7.4 Insertar en lista ordenada

Mantener el orden al insertar:

```text
Antes:    head → [10|─]→[20|─]→[40|─]→[50|NULL]
Insert 30 (ordenado):
Después:  head → [10|─]→[20|─]→[30|─]→[40|─]→[50|NULL]
```

```c
Node* insertSorted(Node *head, int value) {
    Node *n = createNode(value);

    // Caso 1: lista vacía o insertar antes del head
    if (head == NULL || value <= head->data) {
        n->next = head;
        return n;
    }

    // Caso 2: buscar posición correcta
    Node *p = head;
    while (p->next != NULL && p->next->data < value)
        p = p->next;

    n->next = p->next;
    p->next = n;
    return head;
}
```

| Complejidad |
| ----------- |
| **O(n)**    |

---

# 8. Eliminación

## 8.1 Eliminar al inicio

```text
Antes:    head → [10|─]→[20|─]→[30|NULL]
Delete first:
Después:  head → [20|─]→[30|NULL]
          (10 liberado)
```

```c
Node* deleteFirst(Node *head) {
    if (head == NULL) return NULL;
    Node *temp = head;
    head = head->next;
    free(temp);
    return head;
}
```

| Complejidad |
| ----------- |
| **O(1)**    |

## 8.2 Eliminar al final

```text
Antes:    head → [10|─]→[20|─]→[30|NULL]
Delete last:
Después:  head → [10|─]→[20|NULL]
          (30 liberado)
```

```c
Node* deleteLast(Node *head) {
    if (head == NULL) return NULL;
    if (head->next == NULL) { free(head); return NULL; }

    Node *p = head;
    while (p->next->next != NULL)
        p = p->next;

    free(p->next);
    p->next = NULL;
    return head;
}
```

| Complejidad |
| ----------- |
| **O(n)**    |

## 8.3 Eliminar por valor

```c
Node* deleteValue(Node *head, int key) {
    if (head == NULL) return NULL;

    // Caso especial: eliminar el head
    if (head->data == key) {
        Node *temp = head;
        head = head->next;
        free(temp);
        return head;
    }

    Node *prev = head;
    Node *curr = head->next;

    while (curr != NULL) {
        if (curr->data == key) {
            prev->next = curr->next;
            free(curr);
            return head;
        }
        prev = curr;
        curr = curr->next;
    }

    return head;    // no encontrado
}
```

```text
Paso a paso (delete 20):

head → [10|─]→[20|─]→[30|NULL]
        prev    curr

1. curr->data == 20 ✓
2. prev->next = curr->next:
   head → [10|────────]→[30|NULL]
                [20|─]  ← desconectado
3. free(curr):
   head → [10|─]→[30|NULL]
```

## 8.4 Eliminar en posición `pos`

```c
Node* deleteAt(Node *head, int pos) {
    if (head == NULL) return NULL;
    if (pos == 0) return deleteFirst(head);

    Node *p = head;
    for (int i = 0; i < pos - 1 && p->next != NULL; i++)
        p = p->next;

    if (p->next == NULL) {
        printf("Error: posición %d fuera de rango\n", pos);
        return head;
    }

    Node *temp = p->next;
    p->next = temp->next;
    free(temp);
    return head;
}
```

## 8.5 Eliminar duplicados (lista ordenada)

```text
Antes:    head → [10|─]→[10|─]→[20|─]→[20|─]→[30|NULL]
Después:  head → [10|─]→[20|─]→[30|NULL]
```

```c
void removeDuplicatesSorted(Node *head) {
    Node *p = head;
    while (p != NULL && p->next != NULL) {
        if (p->data == p->next->data) {
            Node *temp = p->next;
            p->next = temp->next;
            free(temp);
        } else {
            p = p->next;
        }
    }
}
```

> **⚠️ Nota:** Si `p->data == p->next->data`, NO avanzamos `p` — puede haber más duplicados consecutivos.

## 8.6 Eliminar duplicados (lista NO ordenada)

Requiere comparar cada nodo con todos los que le siguen:

```c
void removeDuplicatesUnsorted(Node *head) {
    Node *p = head;
    while (p != NULL) {
        Node *prev = p;
        Node *q = p->next;
        while (q != NULL) {
            if (q->data == p->data) {
                prev->next = q->next;
                free(q);
                q = prev->next;
            } else {
                prev = q;
                q = q->next;
            }
        }
        p = p->next;
    }
}
```

| Duplicados en     | Complejidad |
| ----------------- | ----------- |
| Lista ordenada    | **O(n)**    |
| Lista no ordenada | **O(n²)**   |

---

# 9. Operaciones Avanzadas

## 9.1 Reverse (Invertir la lista)

### Iterativo (Sliding Pointers)

Usar tres punteros: `prev`, `curr`, `next`.

```text
Paso a paso:

Estado inicial:
  prev=NULL  curr=head  next=?
  NULL  ←?  [10|─]→[20|─]→[30|NULL]

Paso 1: next = curr->next;  curr->next = prev;  prev = curr;  curr = next;
  NULL ← [10|NULL]   [20|─]→[30|NULL]
          prev        curr

Paso 2:
  NULL ← [10|NULL] ← [20|─]   [30|NULL]
                      prev      curr

Paso 3:
  NULL ← [10|NULL] ← [20|─] ← [30|NULL]
                                prev      curr=NULL → STOP

head = prev → [30|─]→[20|─]→[10|NULL]   ✓
```

```c
Node* reverse(Node *head) {
    Node *prev = NULL;
    Node *curr = head;
    Node *next = NULL;

    while (curr != NULL) {
        next = curr->next;     // guardar siguiente
        curr->next = prev;     // invertir enlace
        prev = curr;           // avanzar prev
        curr = next;           // avanzar curr
    }
    return prev;               // nuevo head
}
```

### Recursivo

```c
Node* reverseRec(Node *head) {
    // Caso base: lista vacía o un solo nodo
    if (head == NULL || head->next == NULL)
        return head;

    Node *newHead = reverseRec(head->next);
    head->next->next = head;    // el siguiente apunta de vuelta a mí
    head->next = NULL;          // yo dejo de apuntar adelante
    return newHead;
}
```

```text
Traza recursiva con [10|─]→[20|─]→[30|NULL]:

reverseRec(10):
  reverseRec(20):
    reverseRec(30):
      30->next == NULL → return 30  (newHead = 30)
    head=20: 20->next->next = 20  →  [30|─]→[20|...]
             20->next = NULL       →  [30|─]→[20|NULL]
    return 30
  head=10: 10->next->next = 10    →  [20|─]→[10|...]
           10->next = NULL         →  [20|─]→[10|NULL]
  return 30

Resultado: 30 → 20 → 10 → NULL   ✓
```

| Método    | Complejidad | Espacio |
| --------- | ----------- | ------- |
| Iterativo | O(n)        | O(1)    |
| Recursivo | O(n)        | O(n)    |

---

## 9.2 Concatenar dos listas

```text
A: head1 → [10|─]→[20|NULL]
B: head2 → [30|─]→[40|NULL]

Resultado: head1 → [10|─]→[20|─]→[30|─]→[40|NULL]
```

```c
Node* concat(Node *head1, Node *head2) {
    if (head1 == NULL) return head2;
    if (head2 == NULL) return head1;

    Node *p = head1;
    while (p->next != NULL)
        p = p->next;

    p->next = head2;
    return head1;
}
```

| Complejidad   | Nota                           |
| ------------- | ------------------------------ |
| **O(n)**      | n = longitud de la primera lista |
| **O(1)**      | Si mantienes puntero `tail`    |

---

## 9.3 Merge de dos listas ordenadas

```text
A: [5|─]→[10|─]→[15|NULL]
B: [3|─]→[8|─]→[12|NULL]

Merge: [3|─]→[5|─]→[8|─]→[10|─]→[12|─]→[15|NULL]
```

### Iterativo

```c
Node* mergeSorted(Node *a, Node *b) {
    // Nodo dummy para simplificar la lógica
    Node dummy;
    dummy.next = NULL;
    Node *tail = &dummy;

    while (a != NULL && b != NULL) {
        if (a->data <= b->data) {
            tail->next = a;
            a = a->next;
        } else {
            tail->next = b;
            b = b->next;
        }
        tail = tail->next;
    }

    // Enlazar lo que quede
    tail->next = (a != NULL) ? a : b;

    return dummy.next;
}
```

### Recursivo

```c
Node* mergeSortedRec(Node *a, Node *b) {
    if (a == NULL) return b;
    if (b == NULL) return a;

    if (a->data <= b->data) {
        a->next = mergeSortedRec(a->next, b);
        return a;
    } else {
        b->next = mergeSortedRec(a, b->next);
        return b;
    }
}
```

```text
Traza recursiva:
  merge([5,...], [3,...]) → 3 < 5, return b(3), b->next = merge([5,...],[8,...])
    merge([5,...], [8,...]) → 5 < 8, return a(5), a->next = merge([10,...],[8,...])
      merge([10,...], [8,...]) → 8 < 10, return b(8), b->next = merge([10,...],[12,...])
        merge([10,...],[12,...]) → 10 < 12, return a(10), a->next = merge([15,...],[12,...])
          merge([15,...],[12,...]) → 12 < 15, return b(12), b->next = merge([15,...],NULL)
            merge([15,...],NULL) → return a(15)
          12→15
        10→12→15
      8→10→12→15
    5→8→10→12→15
  3→5→8→10→12→15   ✓
```

| Método    | Complejidad     | Espacio          |
| --------- | --------------- | ---------------- |
| Iterativo | O(n + m)        | O(1)             |
| Recursivo | O(n + m)        | O(n + m) — stack |

---

## 9.4 Detección de ciclos

Un **ciclo** ocurre cuando un nodo apunta a un nodo anterior en la lista (la lista nunca llega a `NULL`).

```text
Normal:   head → [10|─]→[20|─]→[30|NULL]

Con ciclo:
  head → [10|─]→[20|─]→[30|─]→[40|─]─┐
                  ↑                     │
                  └─────────────────────┘
  (40 apunta de vuelta a 20)
```

### Floyd's Cycle Detection (Tortoise and Hare)

**Idea:** Dos punteros recorren la lista — uno lento (`slow`, avanza 1) y uno rápido (`fast`, avanza 2). Si hay ciclo, se encuentran.

```text
      slow →
      fast →→

Sin ciclo: fast llega a NULL antes.
Con ciclo: fast "alcanza" a slow dentro del ciclo.
```

```c
int hasCycle(Node *head) {
    Node *slow = head;
    Node *fast = head;

    while (fast != NULL && fast->next != NULL) {
        slow = slow->next;           // avanza 1
        fast = fast->next->next;     // avanza 2

        if (slow == fast)
            return 1;                // ciclo detectado
    }
    return 0;                        // no hay ciclo
}
```

```text
Traza con ciclo (nodos: 10→20→30→40→20):

Paso  slow  fast
 0    10    10
 1    20    30
 2    30    20    (fast dio la vuelta)
 3    40    40    ← slow == fast → ¡CICLO!
```

### ¿Por qué funciona?

```text
Dentro del ciclo de longitud L:
- Cada paso, la distancia entre slow y fast cambia en 1.
- Si slow entra al ciclo, fast eventualmente lo alcanza.
- Máximo L pasos dentro del ciclo para encontrarse.

Complejidad: O(n) donde n = nodos totales (incluyendo cola + ciclo).
```

### Encontrar el inicio del ciclo

Después de detectar el encuentro, mover uno de los punteros al head. Avanzar ambos de a 1. Donde se encuentren es el **inicio del ciclo**.

```c
Node* findCycleStart(Node *head) {
    Node *slow = head;
    Node *fast = head;

    // Detectar ciclo
    while (fast != NULL && fast->next != NULL) {
        slow = slow->next;
        fast = fast->next->next;
        if (slow == fast) break;
    }

    if (fast == NULL || fast->next == NULL)
        return NULL;    // no hay ciclo

    // Encontrar inicio: mover slow al head, avanzar ambos de a 1
    slow = head;
    while (slow != fast) {
        slow = slow->next;
        fast = fast->next;
    }
    return slow;    // inicio del ciclo
}
```

| Operación              | Complejidad | Espacio |
| ---------------------- | ----------- | ------- |
| Detectar ciclo         | **O(n)**    | O(1)    |
| Encontrar inicio ciclo | **O(n)**    | O(1)    |

---

## 9.5 Verificar si la lista está ordenada

```c
int isSorted(Node *head) {
    if (head == NULL) return 1;
    Node *p = head;
    while (p->next != NULL) {
        if (p->data > p->next->data)
            return 0;
        p = p->next;
    }
    return 1;
}
```

---

## 9.6 Liberar toda la lista

**⚠️ Crítico:** No hacer `free(head)` y olvidar el resto — eso causa memory leak.

```c
void freeList(Node *head) {
    Node *temp;
    while (head != NULL) {
        temp = head;
        head = head->next;
        free(temp);
    }
}
```

---

# PARTE III — CIRCULAR LINKED LIST

---

# 10. Circular Linked List — Concepto

## 10.1 Definición

Una **Circular Linked List** es una lista enlazada donde el **último nodo apunta al primero** (en vez de `NULL`).

```text
Singly Linked:
head → [10|─]→[20|─]→[30|─]→[40|NULL]

Circular Linked:
head → [10|─]→[20|─]→[30|─]→[40|─]─┐
        ↑                             │
        └─────────────────────────────┘
```

> El **último nodo** apunta a `head`, no a `NULL`. No hay final — es un **anillo**.

## 10.2 ¿Cuándo usarla?

| Caso de uso                           | Por qué circular                          |
| ------------------------------------- | ----------------------------------------- |
| Round-robin scheduling (CPU)          | Ciclar continuamente entre procesos       |
| Playlist circular (música)            | Al terminar la última canción, volver a la primera |
| Buffer circular                       | Reutilizar posiciones en un buffer fijo   |
| Juegos por turnos                     | Ciclar entre jugadores sin fin            |
| Josephus Problem                      | Eliminar cada k-ésimo en un círculo       |

## 10.3 Convención: `head` o `tail`?

Podemos mantener un puntero a:
- **`head`** (primer nodo) — natural, pero insertar al final es O(n)
- **`tail`** (último nodo) — insertar al inicio Y al final en O(1)

```text
Con tail:
  tail → [40|─]→[10|─]→[20|─]→[30|─]→[40|...]
          ↑              ↑
         último         primero = tail->next
```

> **Usar `tail` es más eficiente.** Accedes al primero con `tail->next` y al último con `tail`.

---

# 11. Operaciones en Circular List

## 11.1 Detección: ¿Está vacía? / ¿Cuándo terminar?

```c
// La lista está vacía si head == NULL
// Al recorrer, terminar cuando volvamos al head

void displayCircular(Node *head) {
    if (head == NULL) { printf("Lista vacía\n"); return; }

    Node *p = head;
    do {
        printf("%d → ", p->data);
        p = p->next;
    } while (p != head);
    printf("(back to head)\n");
}
```

> **Clave:** Usar `do...while` en vez de `while` — necesitamos ejecutar al menos una vez antes de comparar con `head`.

## 11.2 Count y Sum

```c
int countCircular(Node *head) {
    if (head == NULL) return 0;
    int c = 0;
    Node *p = head;
    do {
        c++;
        p = p->next;
    } while (p != head);
    return c;
}

int sumCircular(Node *head) {
    if (head == NULL) return 0;
    int total = 0;
    Node *p = head;
    do {
        total += p->data;
        p = p->next;
    } while (p != head);
    return total;
}
```

## 11.3 Insertar al inicio

```text
Antes:  head → [10|─]→[20|─]→[30|─]→[10]  (circular)
Insert 5 al inicio:
Después: head → [5|─]→[10|─]→[20|─]→[30|─]→[5]
```

```c
Node* insertFirstCircular(Node *head, int value) {
    Node *n = createNode(value);

    if (head == NULL) {
        n->next = n;       // apunta a sí mismo
        return n;
    }

    // Encontrar el último nodo
    Node *tail = head;
    while (tail->next != head)
        tail = tail->next;

    n->next = head;
    tail->next = n;
    return n;               // nuevo head
}
```

> **Truco O(1):** En vez de buscar el tail, insertar DESPUÉS del head y hacer swap de data:

```c
Node* insertFirstCircularO1(Node *head, int value) {
    Node *n = createNode(value);

    if (head == NULL) {
        n->next = n;
        return n;
    }

    // Insertar después del head y swap data
    n->next = head->next;
    head->next = n;

    int temp = head->data;
    head->data = n->data;
    n->data = temp;

    return head;     // head no cambia (pero su data sí)
}
```

| Método                | Complejidad |
| --------------------- | ----------- |
| Buscar tail + insert  | **O(n)**    |
| Swap data trick       | **O(1)**    |

## 11.4 Insertar al final

```c
Node* insertLastCircular(Node *head, int value) {
    Node *n = createNode(value);

    if (head == NULL) {
        n->next = n;
        return n;
    }

    Node *tail = head;
    while (tail->next != head)
        tail = tail->next;

    tail->next = n;
    n->next = head;
    return head;
}
```

> Con el truco de swap, insertar al final también es O(1):

```c
// Insertar después del head (O(1)), swap data, avanzar head
Node* insertLastCircularO1(Node *head, int value) {
    Node *n = createNode(value);

    if (head == NULL) {
        n->next = n;
        return n;
    }

    n->next = head->next;
    head->next = n;

    // Swap data: ahora n tiene el dato viejo de head, head tiene el nuevo
    int temp = head->data;
    head->data = value;
    n->data = temp;

    return head;    // el "head lógico" se movió al nuevo nodo n, pero head pointer se mantiene
}
```

## 11.5 Eliminar al inicio

```c
Node* deleteFirstCircular(Node *head) {
    if (head == NULL) return NULL;

    if (head->next == head) {
        // Solo un nodo
        free(head);
        return NULL;
    }

    // Copiar data del segundo al primero, eliminar segundo
    Node *second = head->next;
    head->data = second->data;
    head->next = second->next;
    free(second);
    return head;
}
```

> **Truco:** En vez de buscar el tail para actualizar su next, copiamos el data del segundo nodo al head y eliminamos el segundo. **O(1)**.

## 11.6 Eliminar al final

```c
Node* deleteLastCircular(Node *head) {
    if (head == NULL) return NULL;

    if (head->next == head) {
        free(head);
        return NULL;
    }

    Node *p = head;
    while (p->next->next != head)
        p = p->next;

    free(p->next);
    p->next = head;
    return head;
}
```

| Operación       | Complejidad |
| --------------- | ----------- |
| Insert first    | O(1)*       |
| Insert last     | O(n) / O(1)*|
| Delete first    | O(1)*       |
| Delete last     | O(n)        |

*Con truco de swap de data.

## 11.7 Búsqueda

```c
Node* searchCircular(Node *head, int key) {
    if (head == NULL) return NULL;

    Node *p = head;
    do {
        if (p->data == key)
            return p;
        p = p->next;
    } while (p != head);

    return NULL;
}
```

## 11.8 Josephus Problem (caso de uso clásico)

N personas en un círculo. Se elimina cada k-ésima persona. ¿Quién sobrevive?

```text
N=5, k=3:    Personas: 1 → 2 → 3 → 4 → 5 → (1)

Ronda 1: contar 3 → eliminar 3:    1 → 2 → 4 → 5 → (1)
Ronda 2: contar 3 desde 4 → eliminar 1:  2 → 4 → 5 → (2)
Ronda 3: contar 3 desde 2 → eliminar 5:  2 → 4 → (2)
Ronda 4: contar 3 desde 2 → eliminar 2:  4 → (4)

Sobreviviente: 4
```

```c
int josephus(int n, int k) {
    // Crear lista circular 1..n
    Node *head = createNode(1);
    Node *tail = head;
    for (int i = 2; i <= n; i++) {
        tail->next = createNode(i);
        tail = tail->next;
    }
    tail->next = head;     // hacer circular

    Node *p = tail;        // empezar antes del head
    while (p->next != p) { // mientras quede más de 1
        // Avanzar k-1 pasos
        for (int i = 1; i < k; i++)
            p = p->next;

        // Eliminar p->next
        Node *temp = p->next;
        p->next = temp->next;
        printf("Eliminado: %d\n", temp->data);
        free(temp);
    }

    int survivor = p->data;
    free(p);
    return survivor;
}
```

---

# PARTE IV — DOUBLY LINKED LIST

---

# 12. Doubly Linked List — Concepto

## 12.1 Definición

Cada nodo tiene **tres campos**: puntero al anterior, dato, y puntero al siguiente.

```c
typedef struct DNode {
    struct DNode *prev;
    int data;
    struct DNode *next;
} DNode;
```

```text
        NULL ← [prev|10|next] ⇄ [prev|20|next] ⇄ [prev|30|next] → NULL
                ↑
               head
```

## 12.2 Diagrama detallado

```text
head
 │
 ▼
┌──────┬────┬──────┐     ┌──────┬────┬──────┐     ┌──────┬────┬──────┐
│ NULL │ 10 │  ─── ┼────→│  ←── │ 20 │  ─── ┼────→│  ←── │ 30 │ NULL │
│ prev │data│ next │     │ prev │data│ next │     │ prev │data│ next │
└──────┴────┴──────┘     └──────┴────┴──────┘     └──────┴────┴──────┘
                    ←────┤                   ←────┤
```

## 12.3 Ventajas y trade-offs

| Aspecto                | Singly             | Doubly              |
| ---------------------- | ------------------ | ------------------- |
| Espacio por nodo       | 1 puntero (8 B)    | 2 punteros (16 B)   |
| Recorrer adelante      | ✅ O(n)            | ✅ O(n)             |
| Recorrer atrás         | ❌ Imposible       | ✅ O(n)             |
| Eliminar nodo dado     | O(n) — necesita prev | **O(1)** — tiene prev |
| Insertar antes de nodo | O(n) — necesita prev | **O(1)** — tiene prev |
| Complejidad extra      | Baja               | Media (más punteros) |

> El **superpoder** de la doubly: dado un puntero a un nodo, puedes eliminarlo en **O(1)** sin necesitar recorrer la lista para encontrar el anterior.

## 12.4 Crear nodo

```c
DNode* createDNode(int value) {
    DNode *n = (DNode*)malloc(sizeof(DNode));
    n->prev = NULL;
    n->data = value;
    n->next = NULL;
    return n;
}
```

---

# 13. Operaciones en Doubly Linked List

## 13.1 Display (adelante y atrás)

```c
void displayDL(DNode *head) {
    DNode *p = head;
    printf("Forward: ");
    while (p != NULL) {
        printf("%d ⇄ ", p->data);
        if (p->next == NULL) break;   // guardar el tail
        p = p->next;
    }
    printf("NULL\n");

    printf("Backward: ");
    while (p != NULL) {
        printf("%d ⇄ ", p->data);
        p = p->prev;
    }
    printf("NULL\n");
}
```

## 13.2 Insertar al inicio

```text
Antes:   head → [NULL|20|─]⇄[─|30|NULL]
Insert 10:
Después: head → [NULL|10|─]⇄[─|20|─]⇄[─|30|NULL]
```

```c
DNode* insertFirstDL(DNode *head, int value) {
    DNode *n = createDNode(value);
    n->next = head;
    if (head != NULL)
        head->prev = n;
    return n;
}
```

| Complejidad |
| ----------- |
| **O(1)**    |

## 13.3 Insertar al final

```c
DNode* insertLastDL(DNode *head, int value) {
    DNode *n = createDNode(value);
    if (head == NULL) return n;

    DNode *p = head;
    while (p->next != NULL)
        p = p->next;

    p->next = n;
    n->prev = p;
    return head;
}
```

## 13.4 Insertar en posición

```c
DNode* insertAtDL(DNode *head, int value, int pos) {
    if (pos == 0) return insertFirstDL(head, value);

    DNode *p = head;
    for (int i = 0; i < pos - 1 && p != NULL; i++)
        p = p->next;

    if (p == NULL) return head;

    DNode *n = createDNode(value);
    n->next = p->next;
    n->prev = p;
    if (p->next != NULL)
        p->next->prev = n;
    p->next = n;
    return head;
}
```

```text
Insert 25 en pos=2 de [10]⇄[20]⇄[30]:

1. p apunta a nodo con 20 (pos-1 = 1)

2. n = [NULL|25|NULL]

3. n->next = p->next     → n = [NULL|25|─]→[30]
   n->prev = p           → n = [←20|25|─]→[30]
   p->next->prev = n     → [30].prev = n
   p->next = n            → [20].next = n

Resultado: [10]⇄[20]⇄[25]⇄[30]   ✓
```

## 13.5 Eliminar al inicio

```c
DNode* deleteFirstDL(DNode *head) {
    if (head == NULL) return NULL;

    DNode *temp = head;
    head = head->next;
    if (head != NULL)
        head->prev = NULL;
    free(temp);
    return head;
}
```

## 13.6 Eliminar al final

```c
DNode* deleteLastDL(DNode *head) {
    if (head == NULL) return NULL;
    if (head->next == NULL) { free(head); return NULL; }

    DNode *p = head;
    while (p->next != NULL)
        p = p->next;

    p->prev->next = NULL;
    free(p);
    return head;
}
```

## 13.7 Eliminar nodo dado (O(1) — superpoder)

```c
DNode* deleteNodeDL(DNode *head, DNode *target) {
    if (target == NULL) return head;

    if (target->prev != NULL)
        target->prev->next = target->next;
    else
        head = target->next;    // eliminando el head

    if (target->next != NULL)
        target->next->prev = target->prev;

    free(target);
    return head;
}
```

> **Esta es la razón principal de usar doubly linked list.** Con solo el puntero al nodo, se elimina en O(1).

## 13.8 Reverse

```c
DNode* reverseDL(DNode *head) {
    DNode *curr = head;
    DNode *temp = NULL;

    while (curr != NULL) {
        // Swap prev y next
        temp = curr->prev;
        curr->prev = curr->next;
        curr->next = temp;

        curr = curr->prev;     // avanzar (prev es el antiguo next)
    }

    // temp apunta al penúltimo procesado; temp->prev es el nuevo head
    if (temp != NULL)
        head = temp->prev;

    return head;
}
```

> **Observación:** Invertir una doubly linked list es simplemente **swap prev ↔ next** en cada nodo. Elegante.

## 13.9 Eliminar duplicados (ordenada)

```c
void removeDuplicatesDL(DNode *head) {
    DNode *p = head;
    while (p != NULL && p->next != NULL) {
        if (p->data == p->next->data) {
            DNode *temp = p->next;
            p->next = temp->next;
            if (temp->next != NULL)
                temp->next->prev = p;
            free(temp);
        } else {
            p = p->next;
        }
    }
}
```

## 13.10 Merge de dos listas ordenadas

```c
DNode* mergeSortedDL(DNode *a, DNode *b) {
    DNode dummy;
    dummy.next = NULL;
    DNode *tail = &dummy;

    while (a != NULL && b != NULL) {
        if (a->data <= b->data) {
            tail->next = a;
            a->prev = tail;
            a = a->next;
        } else {
            tail->next = b;
            b->prev = tail;
            b = b->next;
        }
        tail = tail->next;
    }

    tail->next = (a != NULL) ? a : b;
    if (tail->next != NULL)
        tail->next->prev = tail;

    DNode *result = dummy.next;
    result->prev = NULL;
    return result;
}
```

---

# PARTE V — CIRCULAR DOUBLY LINKED LIST

---

# 14. Circular Doubly Linked List — Concepto

## 14.1 Definición

Combina doubly linked + circular:
- Cada nodo tiene `prev`, `data`, `next`
- El **último nodo** apunta al primero (`next`)
- El **primer nodo** apunta al último (`prev`)

```text
      ┌────────────────────────────────────────────────────┐
      │                                                    │
      ▼                                                    │
┌──────┬────┬──────┐   ┌──────┬────┬──────┐   ┌──────┬────┴──────┐
│  ←── │ 10 │  ─── ┼──→│  ←── │ 20 │  ─── ┼──→│  ←── │ 30 │  ─── │
│ prev │data│ next │   │ prev │data│ next │   │ prev │data│ next │
└──┬───┴────┴──────┘   └──────┴────┴──────┘   └──────┴────┴──────┘
   │         ↑                                    │
   │         └────────────────────────────────────┘
   │
   └──── prev del primero = último
```

> **No hay `NULL` en ningún puntero.** Cada nodo está completamente conectado.

## 14.2 Propiedades

| Propiedad                           | Valor                                  |
| ----------------------------------- | -------------------------------------- |
| `head->prev`                        | Último nodo (= tail)                   |
| `head->prev->next`                  | `head`                                 |
| Insertar al inicio                  | O(1)                                   |
| Insertar al final                   | **O(1)** — `head->prev` es el tail     |
| Eliminar al inicio                  | O(1)                                   |
| Eliminar al final                   | **O(1)** — `head->prev` es el tail     |
| Recorrer en cualquier dirección     | ✅                                      |

> **Es la variante más poderosa y flexible.** Todas las operaciones en los extremos son O(1).

## 14.3 Casos de uso reales

| Caso de uso                     | Por qué                                  |
| ------------------------------- | ---------------------------------------- |
| Navegador (back/forward)        | Historial bidireccional circular          |
| LRU Cache                       | Eliminar nodo arbitrario en O(1)          |
| Deque (double-ended queue)      | Insertar/eliminar en ambos extremos O(1)  |
| Editores de texto (líneas)      | Navegar adelante/atrás entre líneas       |
| Task scheduler avanzado         | Round-robin con prioridad reversa         |

---

# 15. Operaciones en Circular Doubly List

## 15.1 Estructura y creación

```c
// Reutilizamos DNode (prev, data, next)

DNode* insertFirstCDL(DNode *head, int value) {
    DNode *n = createDNode(value);

    if (head == NULL) {
        n->next = n;
        n->prev = n;
        return n;
    }

    DNode *tail = head->prev;

    n->next = head;
    n->prev = tail;
    head->prev = n;
    tail->next = n;

    return n;           // nuevo head
}
```

## 15.2 Insertar al final (O(1))

```c
DNode* insertLastCDL(DNode *head, int value) {
    if (head == NULL) return insertFirstCDL(head, value);

    DNode *n = createDNode(value);
    DNode *tail = head->prev;

    n->next = head;
    n->prev = tail;
    tail->next = n;
    head->prev = n;

    return head;        // head no cambia
}
```

```text
Antes: head → [10] ⇄ [20] ⇄ [30] ⇄ (back to 10)
InsertLast(40):

tail = head->prev = nodo 30

n = [NULL|40|NULL]
n->next = head(10)
n->prev = tail(30)
tail(30)->next = n(40)
head(10)->prev = n(40)

Después: head → [10] ⇄ [20] ⇄ [30] ⇄ [40] ⇄ (back to 10)
```

## 15.3 Eliminar al inicio (O(1))

```c
DNode* deleteFirstCDL(DNode *head) {
    if (head == NULL) return NULL;

    if (head->next == head) {
        // Solo un nodo
        free(head);
        return NULL;
    }

    DNode *tail = head->prev;
    DNode *newHead = head->next;

    tail->next = newHead;
    newHead->prev = tail;
    free(head);

    return newHead;
}
```

## 15.4 Eliminar al final (O(1))

```c
DNode* deleteLastCDL(DNode *head) {
    if (head == NULL) return NULL;

    if (head->next == head) {
        free(head);
        return NULL;
    }

    DNode *tail = head->prev;
    DNode *newTail = tail->prev;

    newTail->next = head;
    head->prev = newTail;
    free(tail);

    return head;
}
```

## 15.5 Eliminar nodo dado (O(1))

```c
DNode* deleteNodeCDL(DNode *head, DNode *target) {
    if (head == NULL || target == NULL) return head;

    if (target->next == target) {
        // Único nodo
        free(target);
        return NULL;
    }

    target->prev->next = target->next;
    target->next->prev = target->prev;

    DNode *newHead = (target == head) ? head->next : head;
    free(target);
    return newHead;
}
```

## 15.6 Display

```c
void displayCDL(DNode *head) {
    if (head == NULL) { printf("Lista vacía\n"); return; }

    DNode *p = head;
    printf("Forward:  ");
    do {
        printf("%d ⇄ ", p->data);
        p = p->next;
    } while (p != head);
    printf("(back to head)\n");

    printf("Backward: ");
    p = head->prev;    // empezar desde el tail
    do {
        printf("%d ⇄ ", p->data);
        p = p->prev;
    } while (p != head->prev);
    printf("(back to tail)\n");
}
```

## 15.7 Búsqueda

```c
DNode* searchCDL(DNode *head, int key) {
    if (head == NULL) return NULL;

    DNode *p = head;
    do {
        if (p->data == key) return p;
        p = p->next;
    } while (p != head);

    return NULL;
}
```

## 15.8 Reverse

```c
DNode* reverseCDL(DNode *head) {
    if (head == NULL || head->next == head) return head;

    DNode *curr = head;
    DNode *temp;

    do {
        temp = curr->next;
        curr->next = curr->prev;
        curr->prev = temp;
        curr = curr->prev;     // avanzar (prev es el antiguo next)
    } while (curr != head);

    return head->next;          // el antiguo tail es el nuevo head
}
```

---

# PARTE VI — SÍNTESIS

---

# 16. Comparación entre Variantes

## 16.1 Tabla general

| Característica         | Singly           | Circular         | Doubly           | Circular Doubly  |
| ---------------------- | ---------------- | ---------------- | ---------------- | ---------------- |
| Punteros por nodo      | 1 (next)         | 1 (next)         | 2 (prev, next)   | 2 (prev, next)   |
| Último nodo apunta a   | NULL             | Head             | NULL             | Head             |
| Recorrer adelante      | ✅               | ✅               | ✅               | ✅               |
| Recorrer atrás         | ❌               | ❌               | ✅               | ✅               |
| Acceso al tail         | O(n)             | O(n)*            | O(n)             | **O(1)**         |
| Insert first           | **O(1)**         | **O(1)**†        | **O(1)**         | **O(1)**         |
| Insert last            | O(n)             | O(n) / O(1)†     | O(n)             | **O(1)**         |
| Delete first           | **O(1)**         | **O(1)**†        | **O(1)**         | **O(1)**         |
| Delete last            | O(n)             | O(n)             | O(n)             | **O(1)**         |
| Delete nodo dado       | O(n)             | O(n)             | **O(1)**         | **O(1)**         |
| Detectar fin           | `p == NULL`      | `p == head`      | `p == NULL`      | `p == head`      |
| Espacio / nodo (int)   | 12 bytes         | 12 bytes         | 20 bytes         | 20 bytes         |
| Complejidad de impl.   | Baja             | Media            | Media            | Alta             |

*O(1) si se mantiene puntero a tail
†Con truco de swap de data

## 16.2 ¿Cuándo usar cuál?

| Necesidad                                    | Variante recomendada     |
| -------------------------------------------- | ------------------------ |
| Estructura simple, solo recorrer             | Singly                   |
| Stack o Queue básicos                        | Singly                   |
| Ciclar indefinidamente (scheduler)           | Circular                 |
| Eliminar nodos arbitrarios rápido            | Doubly                   |
| Navegar adelante y atrás                     | Doubly                   |
| O(1) en ambos extremos                       | **Circular Doubly**      |
| LRU Cache, Deque                             | **Circular Doubly**      |
| Memoria limitada (embebido)                  | Singly (menos punteros)  |

---

# 17. Resumen de Complejidad

## Singly Linked List

| Operación            | Complejidad | Notas                              |
| -------------------- | ----------- | ---------------------------------- |
| Access by index      | O(n)        | Debe recorrer                      |
| Search               | O(n)        | Lineal                             |
| Insert first         | **O(1)**    | Solo ajustar head                  |
| Insert last          | O(n)        | O(1) con tail                      |
| Insert at pos        | O(n)        | Recorrer hasta pos                 |
| Insert sorted        | O(n)        | Buscar posición                    |
| Delete first         | **O(1)**    | Solo mover head                    |
| Delete last          | O(n)        | Buscar penúltimo                   |
| Delete by value      | O(n)        | Buscar + eliminar                  |
| Reverse              | O(n)        | Sliding pointers                   |
| Merge sorted         | O(n+m)      | Merge de dos listas                |
| Detect cycle         | O(n)        | Floyd's tortoise & hare            |
| Remove duplicates    | O(n)        | Si ordenada; O(n²) si no           |
| Count / Sum / Max    | O(n)        | Un recorrido                       |

## Doubly Linked List

| Operación            | Complejidad | Ventaja sobre Singly               |
| -------------------- | ----------- | ---------------------------------- |
| Delete given node    | **O(1)**    | No necesita buscar prev            |
| Insert before node   | **O(1)**    | Tiene acceso a prev                |
| Reverse              | O(n)        | Swap prev ↔ next                   |
| Traverse backward    | O(n)        | Imposible en Singly                |

## Circular Doubly Linked List

| Operación            | Complejidad | Ventaja sobre las demás            |
| -------------------- | ----------- | ---------------------------------- |
| Insert last          | **O(1)**    | head->prev = tail                  |
| Delete last          | **O(1)**    | head->prev = tail                  |
| Access tail          | **O(1)**    | head->prev                         |

---

# 18. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                            | Consecuencia                               |
| ------------------------------------------------ | ------------------------------------------ |
| No verificar `head == NULL` antes de operar      | Segfault al desreferenciar NULL            |
| `free(head)` sin recorrer toda la lista          | Memory leak (nodos restantes perdidos)     |
| Perder el puntero `head`                         | Toda la lista inaccesible                  |
| No actualizar `prev` en doubly linked            | Lista corrupta en ambas direcciones        |
| Loop infinito en circular (usar `while(p!=NULL)`)| Nunca termina — no hay NULL en circular    |
| No manejar el caso de un solo nodo en circular   | `head->next == head` es caso especial      |
| Modificar `next` antes de guardar la referencia  | Perder el resto de la lista                |
| Olvidar `free()` al eliminar nodos               | Memory leak                                |
| Insertar sin hacer `malloc`                      | Variables locales en stack → dangling ptr  |
| Confundir Singly con Doubly (olvidar `prev`)     | Operaciones incompletas                    |

### ✅ Buenas Prácticas

| Práctica                                         | Razón                                       |
| ------------------------------------------------ | ------------------------------------------- |
| Siempre verificar `head == NULL`                 | Manejar lista vacía correctamente           |
| Guardar `next` ANTES de modificar punteros       | No perder la cadena                         |
| Usar `do...while` en listas circulares           | Ejecutar al menos una iteración             |
| Liberar TODA la lista con `freeList()`           | Prevenir memory leak                        |
| Mantener puntero `tail` si necesitas O(1) append | Evitar recorrer toda la lista               |
| Usar nodo dummy/centinela para simplificar merge | Evita casos especiales para head            |
| Dibujar el diagrama ANTES de escribir el código  | Visualizar los cambios de punteros          |
| Verificar retorno de `malloc`                    | Puede fallar → retorna NULL                 |
| Probar con: 0 nodos, 1 nodo, 2 nodos, n nodos   | Cubrir todos los edge cases                 |

```c
// ✅ Patrón seguro para modificar punteros
Node *next = curr->next;    // GUARDAR primero
curr->next = prev;          // MODIFICAR después
prev = curr;
curr = next;                // AVANZAR con la copia guardada
```

---

# 19. Intuición de Ingeniería

> **Una lista enlazada es una cadena de confianza.**
> Cada nodo confía en que su puntero `next` lo lleva al lugar correcto.
> Romper un enlace sin repararlo es romper toda la estructura.

### El espectro de trade-offs

```text
    Acceso directo O(1)              Inserción/Eliminación O(1)
    ◄──────────────────────────────────────────────────────────►
    Array                                         Linked List

    Cache-friendly                               Dinámico
    Tamaño fijo                                  Tamaño flexible
    Menos memoria                                Más memoria (punteros)
```

### Regla de decisión rápida

```text
¿Necesitas acceso por índice frecuente?     → Array
¿Inserciones/eliminaciones frecuentes?      → Linked List
¿Ambas?                                     → Considerar estructuras híbridas
                                               (skip lists, deques, etc.)
```

### ¿Por qué estudiar listas enlazadas?

```text
Las listas enlazadas son los LADRILLOS de:

├── Stacks (pila con singly list)
├── Queues (cola con singly list + tail)
├── Deques (circular doubly list)
├── Hash tables (chaining = listas en cada bucket)
├── Grafos (listas de adyacencia)
├── LRU Cache (doubly list + hash map)
├── Memoria del OS (free list)
└── Implementaciones de malloc/free
```

> **No estudias listas enlazadas para usar listas enlazadas.**
> Las estudias porque son la **base** de casi toda estructura de datos avanzada.

### Relación con otros archivos

| Tema                             | Archivo              |
| -------------------------------- | -------------------- |
| Arrays a bajo nivel              | Arrays CDT.md        |
| Operaciones sobre arrays         | Arrays ADT.md        |
| Matrices densas y especiales     | Matrices.md          |
| Sparse matrices y polinomios     | SparseMatrices.md    |
| Strings (arrays de char)         | Strings.md           |
| **Linked Lists (este)**          | LinkedList.md        |
