# Queue — Estructura FIFO

> **Idea central:** Si el stack modela "deshacer" (el último primero), la queue modela "esperar tu turno"
> (el primero que llega es el primero que sale). **FIFO — First In, First Out.**
> Cada fila en un banco, cada paquete en una red, cada proceso en un sistema operativo,
> cada impresión en una cola de impresión — todo es una queue. Dominar las queues
> es entender cómo el mundo real **serializa demanda concurrente**.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Concepto y Modelo FIFO](#1-concepto-y-modelo-fifo)
2. [Operaciones del ADT Queue](#2-operaciones-del-adt-queue)
3. [Casos de Uso Reales](#3-casos-de-uso-reales)

**Parte II — Implementaciones con Arrays**
4. [Queue con Un Solo Puntero](#4-queue-con-un-solo-puntero)
5. [Queue con Dos Punteros (front y rear)](#5-queue-con-dos-punteros-front-y-rear)
6. [Limitaciones de Queue con Arrays](#6-limitaciones-de-queue-con-arrays)

**Parte III — Circular Queue**
7. [Circular Queue](#7-circular-queue)

**Parte IV — Queue con Linked List**
8. [Queue con Lista Enlazada](#8-queue-con-lista-enlazada)
9. [Comparación de Implementaciones](#9-comparación-de-implementaciones)

**Parte V — Variantes Avanzadas**
10. [Double Ended Queue (Deque)](#10-double-ended-queue-deque)
11. [Priority Queue](#11-priority-queue)
12. [Queue Usando Dos Stacks](#12-queue-usando-dos-stacks)

**Parte VI — Síntesis**
13. [Resumen de Complejidad](#13-resumen-de-complejidad)
14. [Errores Comunes y Buenas Prácticas](#14-errores-comunes-y-buenas-prácticas)
15. [Intuición de Ingeniería](#15-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS

---

# 1. Concepto y Modelo FIFO

## 1.1 Definición formal

Una **Queue** (cola) es una colección ordenada de elementos donde:
- Las **inserciones** ocurren en un extremo llamado **rear** (final / trasero).
- Las **eliminaciones** ocurren en el extremo opuesto llamado **front** (frente).

Principio: **FIFO — First In, First Out** (el primero que entra es el primero que sale).

```text
     dequeue ←  ┌───┬───┬───┬───┬───┐  ← enqueue
     (sale)     │ A │ B │ C │ D │ E │    (entra)
                └───┴───┴───┴───┴───┘
                 ↑                 ↑
               front             rear

A entró primero → A sale primero (FIFO)
```

## 1.2 Analogía

```text
Fila en un banco:

   Salida (atienden)                          Entrada (llegan)
       ←─────                                   ─────→
   ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
   │ Cliente│  │ Cliente│  │ Cliente│  │ Cliente│
   │   A    │  │   B    │  │   C    │  │   D    │
   └────────┘  └────────┘  └────────┘  └────────┘
     front                                rear

  → A llega primero → A es atendido primero.
  → D llega último  → D espera más.
```

## 1.3 Stack vs Queue

| Aspecto          | Stack (LIFO)            | Queue (FIFO)            |
| ---------------- | ----------------------- | ----------------------- |
| Inserción        | En el **top**           | En el **rear**          |
| Eliminación      | En el **top**           | En el **front**         |
| Extremos usados  | **1** (solo top)        | **2** (front y rear)    |
| Analogía         | Pila de platos          | Fila en un banco        |
| Principio        | Último en salir primero | Primero en salir primero|

```text
Stack (1 extremo):          Queue (2 extremos):

   push → ┌───┐ ← pop        dequeue ← ┌───┬───┬───┐ ← enqueue
           │   │                         │   │   │   │
           ├───┤                         └───┴───┴───┘
           │   │                         front      rear
           └───┘
           top
```

---

# 2. Operaciones del ADT Queue

## 2.1 Operaciones fundamentales

| Operación        | Descripción                                  | Precondición       |
| ---------------- | -------------------------------------------- | ------------------ |
| `enqueue(x)`     | Inserta elemento `x` al final (rear)         | Queue no llena*    |
| `dequeue()`      | Elimina y retorna el elemento del frente      | Queue no vacía     |
| `peek()` / `front()` | Retorna el elemento del frente sin eliminarlo | Queue no vacía |
| `isEmpty()`      | Retorna 1 si la queue está vacía              | Ninguna            |
| `isFull()`       | Retorna 1 si la queue está llena*             | Ninguna            |

> *`isFull()` solo aplica en implementaciones con tamaño fijo (arrays).

## 2.2 Ejemplo de ejecución paso a paso

```text
Operación       │ Queue (front → rear) │ Retorna │ Estado
────────────────┼──────────────────────┼─────────┼─────────
                │ [ ]                  │         │ vacía
enqueue(10)     │ [10]                 │         │
enqueue(20)     │ [10, 20]             │         │
enqueue(30)     │ [10, 20, 30]         │         │
peek()          │ [10, 20, 30]         │ 10      │ no modifica
dequeue()       │ [20, 30]             │ 10      │
dequeue()       │ [30]                 │ 20      │
enqueue(40)     │ [30, 40]             │         │
dequeue()       │ [40]                 │ 30      │
dequeue()       │ [ ]                  │ 40      │ vacía
dequeue()       │ ERROR                │ —       │ underflow
```

## 2.3 Interfaz del ADT (contrato)

```c
// ADT Queue — Interfaz abstracta
// (independiente de la implementación)

typedef struct Queue Queue;

Queue*  createQueue(int capacity);
void    enqueue(Queue *q, int value);
int     dequeue(Queue *q);
int     peek(Queue *q);
int     isEmpty(Queue *q);
int     isFull(Queue *q);
void    destroyQueue(Queue *q);
```

> **ADT = QUÉ hace** (interfaz). **Implementación = CÓMO lo hace** (array, linked list, etc.).

---

# 3. Casos de Uso Reales

| Caso de uso                     | Cómo usa Queue                                  |
| ------------------------------- | ------------------------------------------------ |
| **Sistema operativo**           | Cola de procesos esperando CPU (scheduling)      |
| **Impresora**                   | Cola de documentos esperando impresión           |
| **Red / Networking**            | Buffer de paquetes en router (FIFO)              |
| **BFS (Breadth-First Search)**  | Explora grafos/árboles nivel por nivel           |
| **Atención al cliente**         | Sistema de tickets (primero en llegar, primero atendido) |
| **Teclado**                     | Buffer de teclas presionadas                     |
| **Web server**                  | Cola de requests esperando ser procesados        |
| **Simulación**                  | Modelar tiempos de espera, tráfico, etc.         |
| **Level-order traversal**       | Recorrido por niveles en árboles (ver Trees.md)  |

---

# PARTE II — IMPLEMENTACIONES CON ARRAYS

---

# 4. Queue con Un Solo Puntero

## 4.1 Idea

Usar **solo un índice `rear`** que rastrea la posición del último elemento insertado.
El `front` siempre es el índice 0.

```text
Array:  [ 10 | 20 | 30 |    |    ]
Index:    0    1    2    3    4
          ↑              ↑
        front=0        rear=2
```

## 4.2 Problema: dequeue es O(n)

Al hacer `dequeue`, como el `front` siempre es 0, hay que **desplazar todos los elementos** hacia la izquierda.

```text
Antes de dequeue:
  [ 10 | 20 | 30 |    |    ]    rear = 2
    ↑
  front=0, dequeue devuelve 10

Después (shift todos a la izquierda):
  [ 20 | 30 |    |    |    ]    rear = 1
    ↑
  front=0

Costo: mover n-1 elementos = O(n)
```

## 4.3 Implementación

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int rear;
    int capacity;
} SinglePtrQueue;

SinglePtrQueue* createSPQueue(int capacity) {
    SinglePtrQueue *q = (SinglePtrQueue*)malloc(sizeof(SinglePtrQueue));
    q->data = (int*)malloc(sizeof(int) * capacity);
    q->rear = -1;
    q->capacity = capacity;
    return q;
}

int isEmptySP(SinglePtrQueue *q) {
    return q->rear == -1;
}

int isFullSP(SinglePtrQueue *q) {
    return q->rear == q->capacity - 1;
}

void enqueueSP(SinglePtrQueue *q, int value) {
    if (isFullSP(q)) {
        printf("Queue Overflow!\n");
        return;
    }
    q->data[++q->rear] = value;
}

int dequeueSP(SinglePtrQueue *q) {
    if (isEmptySP(q)) {
        printf("Queue Underflow!\n");
        return -1;
    }
    int value = q->data[0];    // front siempre es 0

    // Shift todos a la izquierda — O(n)
    for (int i = 0; i < q->rear; i++)
        q->data[i] = q->data[i + 1];

    q->rear--;
    return value;
}

int peekSP(SinglePtrQueue *q) {
    if (isEmptySP(q)) {
        printf("Queue is empty!\n");
        return -1;
    }
    return q->data[0];
}
```

## 4.4 Análisis

| Operación | Complejidad | Razón                                 |
| --------- | ----------- | ------------------------------------- |
| enqueue   | **O(1)**    | Insertar al final                     |
| dequeue   | **O(n)**    | Shift de todos los elementos          |
| peek      | **O(1)**    | Acceso directo a índice 0             |
| isEmpty   | **O(1)**    | Comparación                           |

> ⚠️ **dequeue O(n) es inaceptable para uso general.** Por eso necesitamos dos punteros.

---

# 5. Queue con Dos Punteros (front y rear)

## 5.1 Idea

Usar **dos índices**: `front` (de dónde se elimina) y `rear` (dónde se inserta).
Cuando hacemos dequeue, simplemente **avanzamos `front`** en vez de mover todos los elementos.

```text
Inicio (vacía):
  front = rear = -1

Enqueue 10, 20, 30:
  [ 10 | 20 | 30 |    |    ]
    ↑              ↑
  front=0        rear=2

Dequeue (sale 10):
  [    | 20 | 30 |    |    ]
         ↑    ↑
       front=1 rear=2

Dequeue (sale 20):
  [    |    | 30 |    |    ]
               ↑
          front=2=rear
```

> **dequeue ahora es O(1)** — solo incrementa `front`, sin mover nada.

## 5.2 Implementación

```c
typedef struct {
    int *data;
    int front;
    int rear;
    int capacity;
} Queue;

Queue* createQueue(int capacity) {
    Queue *q = (Queue*)malloc(sizeof(Queue));
    q->data = (int*)malloc(sizeof(int) * capacity);
    q->front = -1;
    q->rear = -1;
    q->capacity = capacity;
    return q;
}

int isEmpty(Queue *q) {
    return q->front == -1;
}

int isFull(Queue *q) {
    return q->rear == q->capacity - 1;
}

void enqueue(Queue *q, int value) {
    if (isFull(q)) {
        printf("Queue Overflow!\n");
        return;
    }
    if (q->front == -1)         // primer elemento
        q->front = 0;
    q->data[++q->rear] = value;
}

int dequeue(Queue *q) {
    if (isEmpty(q)) {
        printf("Queue Underflow!\n");
        return -1;
    }
    int value = q->data[q->front];

    if (q->front == q->rear) {  // último elemento
        q->front = -1;
        q->rear = -1;
    } else {
        q->front++;
    }
    return value;
}

int peek(Queue *q) {
    if (isEmpty(q)) {
        printf("Queue is empty!\n");
        return -1;
    }
    return q->data[q->front];
}

void display(Queue *q) {
    if (isEmpty(q)) {
        printf("Queue is empty\n");
        return;
    }
    printf("Queue: ");
    for (int i = q->front; i <= q->rear; i++)
        printf("%d ", q->data[i]);
    printf("\n");
}
```

## 5.3 Traza completa

```text
Operación      │ Array                   │ front │ rear │ Retorna
───────────────┼─────────────────────────┼───────┼──────┼────────
(inicio)       │ [ _ | _ | _ | _ | _ ]   │  -1   │  -1  │
enqueue(10)    │ [10 | _ | _ | _ | _ ]   │   0   │   0  │
enqueue(20)    │ [10 |20 | _ | _ | _ ]   │   0   │   1  │
enqueue(30)    │ [10 |20 |30 | _ | _ ]   │   0   │   2  │
dequeue()      │ [ _ |20 |30 | _ | _ ]   │   1   │   2  │  10
dequeue()      │ [ _ | _ |30 | _ | _ ]   │   2   │   2  │  20
enqueue(40)    │ [ _ | _ |30 |40 | _ ]   │   2   │   3  │
enqueue(50)    │ [ _ | _ |30 |40 |50 ]   │   2   │   4  │
enqueue(60)    │ OVERFLOW! (rear=4=cap-1) │  2   │   4  │  ⚠️
```

## 5.4 Análisis

| Operación | Complejidad | Nota                          |
| --------- | ----------- | ----------------------------- |
| enqueue   | **O(1)**    | Insertar al final             |
| dequeue   | **O(1)**    | Solo incrementar front        |
| peek      | **O(1)**    | Acceso directo                |
| isEmpty   | **O(1)**    | Comparación                   |

> ✅ Todas las operaciones son O(1). Pero hay un **problema grave**...

---

# 6. Limitaciones de Queue con Arrays

## 6.1 El problema del espacio desperdiciado

Observa la traza anterior: después de hacer dequeue de 10 y 20, los índices 0 y 1 quedan **vacíos pero inutilizables**.

```text
Después de 2 dequeues y 2 enqueues más:

  [ _ | _ | 30 | 40 | 50 ]
              ↑          ↑
           front=2     rear=4

Posiciones 0 y 1 están vacías pero NO podemos usarlas.
rear == capacity - 1 → "llena" (OVERFLOW)... ¡con 2 espacios vacíos!
```

## 6.2 Visualización del problema

```text
Capacidad = 5. Operaciones:

1. enqueue ×5:  [A|B|C|D|E]  front=0, rear=4  → llena ✓
2. dequeue ×5:  [_|_|_|_|_]  front=-1, rear=-1 → vacía, se resetea ✓

Ahora otro escenario:
1. enqueue ×5:  [A|B|C|D|E]  front=0, rear=4   → llena
2. dequeue ×3:  [_|_|_|D|E]  front=3, rear=4
3. enqueue(F):  OVERFLOW!    front=3, rear=4    → rear=cap-1

┌─────────────────────────────────────────────┐
│ 3 espacios vacíos pero la queue dice LLENA  │
│ Eficiencia: 2/5 = 40% de uso               │
└─────────────────────────────────────────────┘
```

## 6.3 ¿Soluciones posibles?

| Solución                   | Problema                                       |
| -------------------------- | ---------------------------------------------- |
| Shift en dequeue           | Volvemos a O(n) — lo que queríamos evitar       |
| Reset cuando vacía         | Solo ayuda si la queue se vacía por completo    |
| **Circular Queue**         | ✅ Solución elegante — reusar espacios con módulo |

---

# PARTE III — CIRCULAR QUEUE

---

# 7. Circular Queue

## 7.1 Motivación

El problema de la queue lineal es que `front` y `rear` solo avanzan hacia la derecha, dejando huecos irrecuperables. La **circular queue** conecta el final del array con el inicio, formando un "anillo".

```text
Queue lineal (desperdicio):                 Circular queue (reutiliza):

  [ _ | _ | 30 | 40 | 50 ]                    ┌───┐
                         ↑                   ┌─┤ 50├─┐
                  rear=4 (LLENO)             │ └───┘ │
                                          ┌──┤       ├──┐
                                          │  │       │  │
                                          │60│       │30│
                                          │  │       │  │
                                          └──┤       ├──┘
                                             │ ┌───┐ │
                                             └─┤ 40├─┘
                                               └───┘

  ¡60 puede insertarse donde estaban los huecos!
```

## 7.2 La clave: operador módulo (%)

```text
Avanzar un índice de forma circular:

  nextIndex = (currentIndex + 1) % capacity

Ejemplo con capacity = 5:
  (0 + 1) % 5 = 1
  (1 + 1) % 5 = 2
  (2 + 1) % 5 = 3
  (3 + 1) % 5 = 4
  (4 + 1) % 5 = 0   ← ¡vuelve al inicio!
  (0 + 1) % 5 = 1   ← continúa el ciclo
```

## 7.3 ¿Cómo saber si está llena o vacía?

Ambos casos pueden tener `front == rear`. Hay varias convenciones:

| Estrategia                      | Vacía                | Llena                              |
| ------------------------------- | -------------------- | ---------------------------------- |
| **Usar variable `count`**       | `count == 0`         | `count == capacity`                |
| **Desperdiciar 1 espacio**      | `front == rear`      | `(rear+1) % cap == front`         |
| **Flag booleano**               | `flag == 0`          | `flag == 1`                        |

> Usaremos la estrategia con **variable `count`** por ser la más clara y sin desperdicio.

## 7.4 Implementación completa

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int front;
    int rear;
    int count;        // número actual de elementos
    int capacity;
} CircularQueue;

CircularQueue* createCQ(int capacity) {
    CircularQueue *q = (CircularQueue*)malloc(sizeof(CircularQueue));
    q->data = (int*)malloc(sizeof(int) * capacity);
    q->front = 0;
    q->rear = -1;
    q->count = 0;
    q->capacity = capacity;
    return q;
}

int isEmptyCQ(CircularQueue *q) {
    return q->count == 0;
}

int isFullCQ(CircularQueue *q) {
    return q->count == q->capacity;
}

void enqueueCQ(CircularQueue *q, int value) {
    if (isFullCQ(q)) {
        printf("Circular Queue Overflow!\n");
        return;
    }
    q->rear = (q->rear + 1) % q->capacity;     // avanzar circularmente
    q->data[q->rear] = value;
    q->count++;
}

int dequeueCQ(CircularQueue *q) {
    if (isEmptyCQ(q)) {
        printf("Circular Queue Underflow!\n");
        return -1;
    }
    int value = q->data[q->front];
    q->front = (q->front + 1) % q->capacity;   // avanzar circularmente
    q->count--;
    return value;
}

int peekCQ(CircularQueue *q) {
    if (isEmptyCQ(q)) {
        printf("Circular Queue is empty!\n");
        return -1;
    }
    return q->data[q->front];
}

void displayCQ(CircularQueue *q) {
    if (isEmptyCQ(q)) {
        printf("Circular Queue is empty\n");
        return;
    }
    printf("CQueue: ");
    int idx = q->front;
    for (int i = 0; i < q->count; i++) {
        printf("%d ", q->data[idx]);
        idx = (idx + 1) % q->capacity;
    }
    printf("\n");
}
```

## 7.5 Traza completa (capacity = 5)

```text
Operación      │ Array[0..4]             │ front│ rear│count│ Retorna
───────────────┼─────────────────────────┼──────┼─────┼─────┼────────
(inicio)       │ [ _ | _ | _ | _ | _ ]   │  0   │ -1  │  0  │
enqueueCQ(10)  │ [10 | _ | _ | _ | _ ]   │  0   │  0  │  1  │
enqueueCQ(20)  │ [10 |20 | _ | _ | _ ]   │  0   │  1  │  2  │
enqueueCQ(30)  │ [10 |20 |30 | _ | _ ]   │  0   │  2  │  3  │
enqueueCQ(40)  │ [10 |20 |30 |40 | _ ]   │  0   │  3  │  4  │
enqueueCQ(50)  │ [10 |20 |30 |40 |50 ]   │  0   │  4  │  5  │ full
dequeueCQ()    │ [ _ |20 |30 |40 |50 ]   │  1   │  4  │  4  │ 10
dequeueCQ()    │ [ _ | _ |30 |40 |50 ]   │  2   │  4  │  3  │ 20
enqueueCQ(60)  │ [60 | _ |30 |40 |50 ]   │  2   │  0  │  4  │ ← wrap!
               │  ↑                       │      │     │     │
               │ rear volvió al inicio    │      │     │     │
enqueueCQ(70)  │ [60 |70 |30 |40 |50 ]   │  2   │  1  │  5  │ full
enqueueCQ(80)  │ OVERFLOW (count=5=cap)   │  2   │  1  │  5  │ ⚠️
```

### Visualización circular del estado final

```text
Índices:     0     1     2     3     4
Array:     [ 60 | 70 | 30 | 40 | 50 ]
                    ↑    ↑
                  rear  front

Orden lógico (front → rear circular):
  30 → 40 → 50 → 60 → 70
  (front=2, avanza circularmente: 2,3,4,0,1)
```

## 7.6 Análisis

| Operación   | Complejidad | Espacio                 |
| ----------- | ----------- | ----------------------- |
| enqueue     | **O(1)**    | O(n) array estático     |
| dequeue     | **O(1)**    |                         |
| peek        | **O(1)**    |                         |
| isEmpty     | **O(1)**    |                         |
| isFull      | **O(1)**    |                         |

## 7.7 Queue lineal vs Circular

| Aspecto                     | Queue lineal        | Circular Queue       |
| --------------------------- | ------------------- | -------------------- |
| Espacio desperdiciado       | Sí (huecos al front)| **No** (reutiliza)   |
| Uso del módulo              | No                  | Sí (`%`)             |
| Detección llena             | `rear == cap - 1`   | `count == cap`       |
| Detección vacía             | `front == -1`       | `count == 0`         |
| Capacidad efectiva          | Decrece con dequeues| **Constante**        |

> **En la práctica, SIEMPRE se usa circular queue para implementación con arrays.** La versión lineal solo se estudia para entender el problema.

---

# PARTE IV — QUEUE CON LINKED LIST

---

# 8. Queue con Lista Enlazada

## 8.1 Motivación

Las implementaciones con arrays tienen **capacidad fija**. Con una lista enlazada:
- **No hay overflow** (crece dinámicamente).
- **No hay espacio desperdiciado** (solo los nodos que existen).
- **No necesitas circular** (no hay índices que desperdiciar).

## 8.2 Estructura

```text
front                                          rear
  ↓                                              ↓
┌────┬───┐    ┌────┬───┐    ┌────┬───┐    ┌────┬───┐
│ 10 │ ──┼──→ │ 20 │ ──┼──→ │ 30 │ ──┼──→ │ 40 │ / │
└────┴───┘    └────┴───┘    └────┴───┘    └────┴───┘

Enqueue: insertar al final (rear)    → O(1) con puntero rear
Dequeue: eliminar del frente (front) → O(1)
```

## 8.3 Implementación completa

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

typedef struct {
    Node *front;
    Node *rear;
    int count;
} LinkedQueue;

LinkedQueue* createLQ() {
    LinkedQueue *q = (LinkedQueue*)malloc(sizeof(LinkedQueue));
    q->front = NULL;
    q->rear = NULL;
    q->count = 0;
    return q;
}

int isEmptyLQ(LinkedQueue *q) {
    return q->front == NULL;
}

void enqueueLQ(LinkedQueue *q, int value) {
    Node *newNode = (Node*)malloc(sizeof(Node));
    newNode->data = value;
    newNode->next = NULL;

    if (isEmptyLQ(q)) {
        q->front = newNode;         // primer nodo: front y rear apuntan al mismo
        q->rear = newNode;
    } else {
        q->rear->next = newNode;    // enlazar al final
        q->rear = newNode;          // actualizar rear
    }
    q->count++;
}

int dequeueLQ(LinkedQueue *q) {
    if (isEmptyLQ(q)) {
        printf("Queue Underflow!\n");
        return -1;
    }
    Node *temp = q->front;
    int value = temp->data;
    q->front = q->front->next;

    if (q->front == NULL)           // si era el último nodo
        q->rear = NULL;

    free(temp);
    q->count--;
    return value;
}

int peekLQ(LinkedQueue *q) {
    if (isEmptyLQ(q)) {
        printf("Queue is empty!\n");
        return -1;
    }
    return q->front->data;
}

void displayLQ(LinkedQueue *q) {
    if (isEmptyLQ(q)) {
        printf("Queue is empty\n");
        return;
    }
    printf("Queue: ");
    Node *curr = q->front;
    while (curr != NULL) {
        printf("%d ", curr->data);
        curr = curr->next;
    }
    printf("\n");
}

void destroyLQ(LinkedQueue *q) {
    while (!isEmptyLQ(q))
        dequeueLQ(q);
    free(q);
}
```

## 8.4 Traza

```text
Operación      │ Lista                            │ front │ rear │count
───────────────┼──────────────────────────────────┼───────┼──────┼─────
(inicio)       │ NULL                             │ NULL  │ NULL │  0
enqueueLQ(10)  │ [10]→NULL                        │ →10   │ →10  │  1
enqueueLQ(20)  │ [10]→[20]→NULL                   │ →10   │ →20  │  2
enqueueLQ(30)  │ [10]→[20]→[30]→NULL              │ →10   │ →30  │  3
dequeueLQ()    │ [20]→[30]→NULL   free(10)        │ →20   │ →30  │  2
dequeueLQ()    │ [30]→NULL        free(20)        │ →30   │ →30  │  1
enqueueLQ(40)  │ [30]→[40]→NULL                   │ →30   │ →40  │  2
dequeueLQ()    │ [40]→NULL        free(30)        │ →40   │ →40  │  1
dequeueLQ()    │ NULL             free(40)        │ NULL  │ NULL │  0
```

## 8.5 Análisis

| Operación   | Complejidad | Nota                              |
| ----------- | ----------- | --------------------------------- |
| enqueue     | **O(1)**    | Insertar al final con ptr rear    |
| dequeue     | **O(1)**    | Eliminar del frente               |
| peek        | **O(1)**    | Acceder al frente                 |
| isEmpty     | **O(1)**    | Comparar con NULL                 |
| Espacio     | **O(n)**    | Exactamente n nodos (sin desperdicio) |

---

# 9. Comparación de Implementaciones

## 9.1 Tabla comparativa completa

| Criterio                  | 1 Puntero   | 2 Punteros  | Circular    | Linked List  |
| ------------------------- | ----------- | ----------- | ----------- | ------------ |
| **enqueue**               | O(1)        | O(1)        | O(1)        | O(1)         |
| **dequeue**               | **O(n)** ⚠️ | O(1)        | O(1)        | O(1)         |
| Espacio desperdiciado     | No          | **Sí** ⚠️   | No          | No           |
| Capacidad fija            | Sí          | Sí          | Sí          | **No** ✅    |
| Overhead por nodo         | Ninguno     | Ninguno     | Ninguno     | 1 puntero    |
| Cache friendly            | Sí          | Sí          | Sí          | **No**       |
| Complejidad de implementar| Simple      | Simple      | Media       | Media        |
| Recomendado               | ❌ Nunca    | ❌ Educativo| ✅ Cap. fija | ✅ Dinámico |

## 9.2 ¿Cuándo usar cuál?

```text
¿Sabes el tamaño máximo?
├── Sí → ¿Es crítico el rendimiento de cache?
│        ├── Sí → Circular Queue (array)
│        └── No → Circular Queue (array) ← sigue siendo mejor
└── No → Linked Queue
         ├── ¿Necesitas O(1) siempre? → Linked Queue
         └── ¿Crece impredeciblemente? → Linked Queue
```

> **Regla general:** Circular Queue con arrays para tamaño conocido. Linked Queue para tamaño desconocido.

---

# PARTE V — VARIANTES AVANZADAS

---

# 10. Double Ended Queue (Deque)

## 10.1 Definición

Un **Deque** (Double-Ended Queue, pronunciado "deck") permite **inserciones y eliminaciones en ambos extremos**.

```text
      enqueueFront         enqueueRear
          │                     │
          ▼                     ▼
  ← dequeueFront ┌───┬───┬───┐ dequeueRear →
                  │ A │ B │ C │
                  └───┴───┴───┘
                   ↑           ↑
                 front        rear
```

## 10.2 Operaciones

| Operación           | Descripción                        |
| ------------------- | ---------------------------------- |
| `enqueueFront(x)`   | Insertar al frente                 |
| `enqueueRear(x)`    | Insertar al final                  |
| `dequeueFront()`    | Eliminar del frente                |
| `dequeueRear()`     | Eliminar del final                 |
| `peekFront()`       | Ver el frente                      |
| `peekRear()`        | Ver el final                       |
| `isEmpty()`         | ¿Está vacío?                       |
| `isFull()`          | ¿Está lleno?                       |

## 10.3 Relación con Stack y Queue

```text
Deque restringido:
  - Solo inserta/elimina del frente → STACK
  - Solo inserta por atrás, elimina por delante → QUEUE

Un Deque es la generalización de Stack y Queue.

  Stack  ⊂  Deque
  Queue  ⊂  Deque
```

| Restricción aplicada a Deque         | Resultado    |
| ------------------------------------ | ------------ |
| Solo operar en un extremo            | **Stack**    |
| Insertar en rear, eliminar de front  | **Queue**    |
| Sin restricciones                    | **Deque**    |

## 10.4 Tipos de Deque

| Tipo                         | Restricción                                     |
| ---------------------------- | ----------------------------------------------- |
| **Input-restricted Deque**   | Inserción solo por un extremo; eliminación por ambos |
| **Output-restricted Deque**  | Eliminación solo por un extremo; inserción por ambos |
| **Unrestricted Deque**       | Inserción y eliminación por ambos extremos       |

## 10.5 Implementación (Circular Array)

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int front;
    int rear;
    int count;
    int capacity;
} Deque;

Deque* createDeque(int capacity) {
    Deque *d = (Deque*)malloc(sizeof(Deque));
    d->data = (int*)malloc(sizeof(int) * capacity);
    d->front = 0;
    d->rear = -1;
    d->count = 0;
    d->capacity = capacity;
    return d;
}

int isEmptyDeque(Deque *d) { return d->count == 0; }
int isFullDeque(Deque *d)  { return d->count == d->capacity; }

void enqueueRear(Deque *d, int value) {
    if (isFullDeque(d)) { printf("Deque Overflow!\n"); return; }
    d->rear = (d->rear + 1) % d->capacity;
    d->data[d->rear] = value;
    d->count++;
}

void enqueueFront(Deque *d, int value) {
    if (isFullDeque(d)) { printf("Deque Overflow!\n"); return; }
    d->front = (d->front - 1 + d->capacity) % d->capacity;   // retroceder circularmente
    d->data[d->front] = value;
    d->count++;
}

int dequeueFront(Deque *d) {
    if (isEmptyDeque(d)) { printf("Deque Underflow!\n"); return -1; }
    int value = d->data[d->front];
    d->front = (d->front + 1) % d->capacity;
    d->count--;
    return value;
}

int dequeueRear(Deque *d) {
    if (isEmptyDeque(d)) { printf("Deque Underflow!\n"); return -1; }
    int value = d->data[d->rear];
    d->rear = (d->rear - 1 + d->capacity) % d->capacity;     // retroceder circularmente
    d->count--;
    return value;
}

int peekFront(Deque *d) {
    if (isEmptyDeque(d)) { printf("Deque is empty!\n"); return -1; }
    return d->data[d->front];
}

int peekRear(Deque *d) {
    if (isEmptyDeque(d)) { printf("Deque is empty!\n"); return -1; }
    return d->data[d->rear];
}
```

> **Clave del Deque:** Retroceder circularmente usa `(index - 1 + capacity) % capacity` para evitar índices negativos.

## 10.6 Traza (capacity = 5)

```text
Operación        │ Array[0..4]              │ front│ rear│count│ Retorna
─────────────────┼──────────────────────────┼──────┼─────┼─────┼────────
(inicio)         │ [ _ | _ | _ | _ | _ ]    │  0   │ -1  │  0  │
enqueueRear(10)  │ [10 | _ | _ | _ | _ ]    │  0   │  0  │  1  │
enqueueRear(20)  │ [10 |20 | _ | _ | _ ]    │  0   │  1  │  2  │
enqueueFront(5)  │ [10 |20 | _ | _ |  5]    │  4   │  1  │  3  │ front retrocede
                 │                  ↑front   │      │     │     │
enqueueFront(1)  │ [10 |20 | _ | 1 |  5]    │  3   │  1  │  4  │
enqueueRear(30)  │ [10 |20 |30 | 1 |  5]    │  3   │  2  │  5  │ full
dequeueFront()   │ [10 |20 |30 | _ |  5]    │  4   │  2  │  4  │ 1
dequeueRear()    │ [10 |20 | _ | _ |  5]    │  4   │  1  │  3  │ 30

Orden lógico final (front=4 → rear=1): 5, 10, 20
```

## 10.7 Análisis

| Operación       | Complejidad |
| --------------- | ----------- |
| enqueueFront    | **O(1)**    |
| enqueueRear     | **O(1)**    |
| dequeueFront    | **O(1)**    |
| dequeueRear     | **O(1)**    |
| peekFront/Rear  | **O(1)**    |

> Todas O(1) gracias al array circular. Misma eficiencia que una circular queue, pero con doble flexibilidad.

---

# 11. Priority Queue

## 11.1 Definición

Una **Priority Queue** es una queue donde cada elemento tiene una **prioridad** asociada. El elemento con **mayor (o menor) prioridad** se atiende primero, **sin importar el orden de llegada**.

```text
Queue normal (FIFO):
  Llega A, B, C → Sale A, B, C (orden de llegada)

Priority Queue:
  Llega A(p=3), B(p=1), C(p=5) → Sale B, A, C (orden de prioridad)
                                   (menor número = mayor prioridad)
```

## 11.2 ¿Dónde se usa?

| Caso de uso                       | Prioridad                              |
| --------------------------------- | -------------------------------------- |
| **Urgencias en hospital**         | Gravedad del paciente                  |
| **CPU scheduling**                | Prioridad del proceso                  |
| **Dijkstra (shortest path)**      | Distancia mínima actual                |
| **Huffman coding (compresión)**   | Frecuencia del carácter                |
| **A\* pathfinding**               | f(n) = g(n) + h(n)                     |
| **Event-driven simulation**       | Timestamp del evento                   |

## 11.3 Implementaciones posibles

| Implementación                  | enqueue      | dequeue (min/max) | peek         |
| ------------------------------- | ------------ | ----------------- | ------------ |
| **Array desordenado**           | O(1)         | **O(n)**          | O(n)         |
| **Array ordenado**              | **O(n)**     | O(1)              | O(1)         |
| **Linked List ordenada**        | **O(n)**     | O(1)              | O(1)         |
| **Binary Heap**                 | **O(log n)** | **O(log n)**      | O(1)         |
| **BST balanceado**              | O(log n)     | O(log n)          | O(log n)     |

> **El Binary Heap es la implementación estándar** porque ofrece O(log n) para ambas operaciones principales.

## 11.4 Implementación con Array Desordenado

La más simple: insertar al final, buscar el mínimo/máximo al extraer.

```c
typedef struct {
    int data[100];
    int priority[100];     // menor número = mayor prioridad
    int count;
} PriorityQueue;

void initPQ(PriorityQueue *pq) {
    pq->count = 0;
}

void enqueuePQ(PriorityQueue *pq, int value, int priority) {
    if (pq->count >= 100) {
        printf("PQ Overflow!\n");
        return;
    }
    pq->data[pq->count] = value;
    pq->priority[pq->count] = priority;
    pq->count++;
}

int dequeuePQ(PriorityQueue *pq) {
    if (pq->count == 0) {
        printf("PQ Underflow!\n");
        return -1;
    }

    // Encontrar el elemento con mayor prioridad (menor número)
    int minIdx = 0;
    for (int i = 1; i < pq->count; i++) {
        if (pq->priority[i] < pq->priority[minIdx])
            minIdx = i;
    }

    int value = pq->data[minIdx];

    // Reemplazar con el último elemento (orden no importa)
    pq->data[minIdx] = pq->data[pq->count - 1];
    pq->priority[minIdx] = pq->priority[pq->count - 1];
    pq->count--;

    return value;
}
```

## 11.5 Implementación con Array Ordenado

Mantener el array ordenado por prioridad. Insertar en posición correcta (shift), extraer del final.

```c
typedef struct {
    int data[100];
    int priority[100];
    int count;
} SortedPQ;

void initSortedPQ(SortedPQ *pq) {
    pq->count = 0;
}

// Insertar manteniendo orden descendente de prioridad
// (mayor número de prioridad al inicio, menor al final)
// Así dequeue siempre saca del final → O(1)
void enqueueSorted(SortedPQ *pq, int value, int priority) {
    if (pq->count >= 100) { printf("PQ Overflow!\n"); return; }

    // Encontrar posición correcta (inserción ordenada)
    int i = pq->count - 1;
    while (i >= 0 && pq->priority[i] < priority) {
        pq->data[i + 1] = pq->data[i];
        pq->priority[i + 1] = pq->priority[i];
        i--;
    }
    pq->data[i + 1] = value;
    pq->priority[i + 1] = priority;
    pq->count++;
}

// Dequeue: el de mayor prioridad está al final (menor número)
int dequeueSorted(SortedPQ *pq) {
    if (pq->count == 0) { printf("PQ Underflow!\n"); return -1; }
    return pq->data[--pq->count];
}
```

## 11.6 Traza comparativa

```text
Operaciones: enqueue(A,3), enqueue(B,1), enqueue(C,5), enqueue(D,2)
             dequeue(), dequeue()

Array Desordenado:
  Después de 4 enqueues:
  data:     [A, B, C, D]
  priority: [3, 1, 5, 2]

  dequeue → busca mínimo → priority[1]=1 → B sale.
  data:     [A, D, C]        (D reemplaza B)
  priority: [3, 2, 5]

  dequeue → busca mínimo → priority[1]=2 → D sale.

Array Ordenado (desc por priority):
  enqueue(A,3): [A]           priorities: [3]
  enqueue(B,1): [A, B]        priorities: [3, 1]   (1 < 3, va al final)
  enqueue(C,5): [C, A, B]     priorities: [5, 3, 1] (5 > 3, shift)
  enqueue(D,2): [C, A, D, B]  priorities: [5, 3, 2, 1]

  dequeue → pop final → B (priority 1) sale. O(1).
  dequeue → pop final → D (priority 2) sale. O(1).
```

## 11.7 ¿Y el Heap?

El **Binary Heap** es la implementación óptima de Priority Queue:

```text
Binary Heap (Min-Heap):
           1
          / \
         2   5
        / 
       3

Propiedad: padre ≤ hijos (min-heap)

enqueue: insertar al final, "burbujear" hacia arriba → O(log n)
dequeue: sacar raíz, reemplazar con último, "hundir" → O(log n)
```

> El heap se cubrirá en detalle en un módulo separado. Por ahora, saber que **Priority Queue se implementa con heap** y ambas operaciones son **O(log n)**.

---

# 12. Queue Usando Dos Stacks

## 12.1 El problema

¿Cómo implementar una queue (FIFO) usando **solo stacks** (LIFO)?

```text
Stack: LIFO → el último que entra sale primero
Queue: FIFO → el primero que entra sale primero

¡Son opuestos! Pero... LIFO invertido = FIFO.
Si invertimos un stack, los elementos salen en orden FIFO.
```

## 12.2 Idea fundamental

Usar **dos stacks**: `S1` (inbox) y `S2` (outbox).

```text
Enqueue: siempre push a S1.
Dequeue: pop de S2.
         Si S2 está vacío → transferir TODO de S1 a S2 (esto invierte el orden).
```

```text
enqueue(1), enqueue(2), enqueue(3):

  S1 (inbox):    S2 (outbox):
  ┌───┐          ┌───┐
  │ 3 │          │   │  (vacío)
  ├───┤          └───┘
  │ 2 │
  ├───┤
  │ 1 │
  └───┘

dequeue():
  S2 vacío → transferir S1 → S2:

  S1:            S2:
  ┌───┐          ┌───┐
  │   │ (vacío)  │ 1 │  ← top (primero en entrar, primero en salir)
  └───┘          ├───┤
                 │ 2 │
                 ├───┤
                 │ 3 │
                 └───┘

  Pop S2 → devuelve 1 ✓ (FIFO)
```

## 12.3 Implementación

```c
#include <stdio.h>
#include <stdlib.h>

#define MAX 100

typedef struct {
    int data[MAX];
    int top;
} Stack;

void initStack(Stack *s) { s->top = -1; }
int isStackEmpty(Stack *s) { return s->top == -1; }
int isStackFull(Stack *s)  { return s->top == MAX - 1; }

void push(Stack *s, int value) {
    if (isStackFull(s)) { printf("Stack Overflow!\n"); return; }
    s->data[++s->top] = value;
}

int pop(Stack *s) {
    if (isStackEmpty(s)) { printf("Stack Underflow!\n"); return -1; }
    return s->data[s->top--];
}

int stackPeek(Stack *s) {
    if (isStackEmpty(s)) return -1;
    return s->data[s->top];
}

// Queue usando dos stacks
typedef struct {
    Stack s1;       // inbox  — para enqueue
    Stack s2;       // outbox — para dequeue
} QueueTwoStacks;

void initQTS(QueueTwoStacks *q) {
    initStack(&q->s1);
    initStack(&q->s2);
}

void enqueueQTS(QueueTwoStacks *q, int value) {
    push(&q->s1, value);     // siempre push a S1
}

// Transferir S1 → S2 (invierte el orden)
void transfer(QueueTwoStacks *q) {
    while (!isStackEmpty(&q->s1))
        push(&q->s2, pop(&q->s1));
}

int dequeueQTS(QueueTwoStacks *q) {
    if (isStackEmpty(&q->s2))       // si S2 vacío
        transfer(q);                // transferir todo de S1 a S2

    if (isStackEmpty(&q->s2)) {     // si sigue vacío → queue vacía
        printf("Queue Underflow!\n");
        return -1;
    }
    return pop(&q->s2);
}

int peekQTS(QueueTwoStacks *q) {
    if (isStackEmpty(&q->s2))
        transfer(q);

    if (isStackEmpty(&q->s2)) {
        printf("Queue is empty!\n");
        return -1;
    }
    return stackPeek(&q->s2);
}

int isEmptyQTS(QueueTwoStacks *q) {
    return isStackEmpty(&q->s1) && isStackEmpty(&q->s2);
}
```

## 12.4 Traza completa

```text
Operación       │ S1 (top→bot)  │ S2 (top→bot)  │ Retorna │ Nota
────────────────┼───────────────┼───────────────┼─────────┼──────────────
enqueueQTS(10)  │ [10]          │ [ ]           │         │ push S1
enqueueQTS(20)  │ [20, 10]      │ [ ]           │         │ push S1
enqueueQTS(30)  │ [30, 20, 10]  │ [ ]           │         │ push S1
dequeueQTS()    │ [ ]           │ [10, 20, 30]  │ 10      │ transfer + pop S2
dequeueQTS()    │ [ ]           │ [20, 30]      │ 20      │ pop S2 (sin transfer)
enqueueQTS(40)  │ [40]          │ [30]          │         │ push S1
enqueueQTS(50)  │ [50, 40]      │ [30]          │         │ push S1
dequeueQTS()    │ [50, 40]      │ [ ]→[30]→pop  │ 30      │ S2 tiene 30, pop directo
dequeueQTS()    │ [ ]           │ [40, 50]      │ 40      │ transfer + pop S2
dequeueQTS()    │ [ ]           │ [50]          │ 50      │ pop S2
dequeueQTS()    │ [ ]           │ [ ]           │ ERROR   │ underflow
```

## 12.5 Análisis amortizado

```text
Peor caso individual:
  dequeue cuando S2 vacío y S1 tiene n elementos → O(n) para transferir.

Pero... ¿con qué frecuencia ocurre?
```

### Análisis amortizado (método del banquero)

```text
Cada elemento pasa por exactamente 4 operaciones en su vida:
  1. push a S1          → O(1)
  2. pop de S1          → O(1)  ┐
  3. push a S2          → O(1)  ├─ transferencia (ocurre una sola vez)
  4. pop de S2          → O(1)  ┘

Costo total por elemento: 4 operaciones = O(1).
```

| Operación   | Peor caso  | **Amortizado** |
| ----------- | ---------- | -------------- |
| enqueue     | O(1)       | **O(1)**       |
| dequeue     | O(n)       | **O(1)**       |

> **La clave:** Cada elemento se transfiere **exactamente una vez**. El costo O(n) de una transferencia se "reparte" entre los n elementos que se benefician.

## 12.6 ¿Para qué sirve?

| Uso                                                  | Razón                                         |
| ---------------------------------------------------- | --------------------------------------------- |
| Implementar queue en lenguajes con solo stacks       | Reutilizar lo que ya existe                   |
| Pregunta clásica de entrevista                       | Demuestra comprensión de ADTs y amortización  |
| Queue funcional (en lenguajes funcionales)           | Los stacks (listas) son naturales en FP       |
| Entender análisis amortizado                         | Ejemplo canónico de amortized O(1)            |

---

# PARTE VI — SÍNTESIS

---

# 13. Resumen de Complejidad

## 13.1 Por implementación

| Implementación         | enqueue    | dequeue    | peek   | Espacio | Capacidad    |
| ---------------------- | ---------- | ---------- | ------ | ------- | ------------ |
| **1 puntero (array)**  | O(1)       | **O(n)** ⚠️| O(1)   | O(n)    | Fija         |
| **2 punteros (array)** | O(1)       | O(1)       | O(1)   | O(n)*   | Fija (desp.) |
| **Circular (array)**   | O(1)       | O(1)       | O(1)   | O(n)    | Fija         |
| **Linked List**        | O(1)       | O(1)       | O(1)   | O(n)    | Dinámica     |
| **Deque (circular)**   | O(1)       | O(1)       | O(1)   | O(n)    | Fija         |
| **2 Stacks**           | O(1)       | O(1) amort.| O(1) a.| O(n)    | Fija/Din.    |

\* Desperdicia espacio progresivamente.

## 13.2 Priority Queue

| Implementación         | enqueue    | dequeue    | peek   |
| ---------------------- | ---------- | ---------- | ------ |
| Array desordenado      | O(1)       | **O(n)**   | O(n)   |
| Array ordenado         | **O(n)**   | O(1)       | O(1)   |
| **Binary Heap**        | O(log n)   | O(log n)   | O(1)   |

## 13.3 Diagrama de decisión

```text
¿Qué tipo de queue necesitas?

├── FIFO estricto
│   ├── Tamaño conocido → Circular Queue (array)
│   ├── Tamaño variable → Linked Queue
│   └── Solo tienes stacks → Queue con 2 Stacks
│
├── Insertar/eliminar en ambos extremos
│   └── Deque
│
└── Orden por prioridad (no FIFO)
    ├── Pocos elementos → Array ordenado
    └── Muchos elementos → Binary Heap (Priority Queue)
```

---

# 14. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                                  | Consecuencia                              |
| ------------------------------------------------------ | ----------------------------------------- |
| Usar queue lineal con arrays sin circular              | Espacio desperdiciado; overflow falso      |
| Olvidar `% capacity` en circular queue                 | Acceso fuera de rango (buffer overflow)    |
| No actualizar `rear = NULL` al vaciar linked queue     | Puntero colgante → crash en enqueue        |
| Confundir `front == rear` como vacío y lleno           | Comportamiento ambiguo                     |
| No verificar underflow antes de dequeue                | Acceso a datos basura                      |
| No verificar overflow antes de enqueue (array)         | Sobreescritura de datos                    |
| Hacer dequeue con shift O(n) en producción             | Rendimiento inaceptable en carga alta      |
| No liberar nodos en linked queue                       | Memory leak acumulativo                    |
| Priority Queue con array para millones de elementos    | O(n) dequeue → sistema lento               |
| Olvidar transferir S1→S2 en queue con 2 stacks         | Dequeue devuelve elemento incorrecto       |
| Retroceder front sin `+ capacity` en deque             | Índice negativo → crash                    |

### ✅ Buenas Prácticas

| Práctica                                              | Razón                                       |
| ----------------------------------------------------- | ------------------------------------------- |
| **Siempre usar circular** para queue con arrays       | Elimina desperdicio de espacio              |
| Usar variable `count` para full/empty en circular     | Evita ambigüedad front==rear                |
| Verificar overflow/underflow en **toda** operación    | Prevenir crashes y datos corruptos          |
| `rear = NULL` cuando el último nodo sale (linked)     | Evitar puntero colgante                     |
| Usar `(i - 1 + cap) % cap` para retroceder en deque  | Evitar módulo de número negativo            |
| Elegir linked queue si tamaño es impredecible         | Crece sin desperdiciar ni realocar          |
| Usar heap para priority queue con muchos elementos    | O(log n) vs O(n) — diferencia enorme        |
| Destruir/free la queue al terminar                    | Evitar memory leaks                         |
| Entender análisis amortizado (2 stacks)               | No dejarse engañar por peor caso O(n)       |
| Probar con queue vacía, 1 elemento, llena, wrap-around| Edge cases que revelan bugs                 |

```c
// ✅ Patrón seguro para circular queue
void enqueueSafe(CircularQueue *q, int value) {
    if (isFullCQ(q)) {
        printf("Error: Queue full, cannot enqueue %d\n", value);
        return;     // o redimensionar, o retornar código de error
    }
    q->rear = (q->rear + 1) % q->capacity;
    q->data[q->rear] = value;
    q->count++;
}

// ✅ Destruir linked queue
void destroyLinkedQueue(LinkedQueue *q) {
    while (!isEmptyLQ(q))
        dequeueLQ(q);       // free cada nodo
    free(q);                // free la estructura
}
```

---

# 15. Intuición de Ingeniería

> **Un stack dice "lo más reciente primero". Una queue dice "respeta el orden de llegada".**
> El stack es para deshacer. La queue es para **ser justo**.
> Todo sistema que necesita **fairness** — turno, orden, secuencia — necesita una queue.

### El espectro de las colas

```text
                Stack            Queue           Deque          Priority Queue
               (LIFO)           (FIFO)        (ambos extremos)  (por prioridad)

Restricción:   1 extremo        2 extremos      2 extremos       prioridad
               (máxima)         (media)         (mínima)         (diferente eje)

              ←───── más restrictivo                menos restrictivo ─────→

Un Deque puede simular Stack y Queue.
Un Priority Queue rompe con el orden de llegada: atiende por importancia.
```

### ¿Cuándo usar qué?

```text
¿Necesitas...                              → Estructura
────────────────────────────────────────────────────────
...deshacer / revertir?                    → Stack
...procesar en orden de llegada?           → Queue
...procesar por ambos extremos?            → Deque
...procesar por importancia?               → Priority Queue
...recorrer un árbol por niveles (BFS)?    → Queue
...recorrer un árbol en profundidad (DFS)? → Stack
...simular una cola real?                  → Queue
...scheduling de CPU?                      → Priority Queue
```

### El patrón circular

```text
El problema:   Los índices avanzan y nunca retroceden → desperdicio.
La solución:   Conectar el final con el inicio → circular.
La herramienta: El operador módulo (%).

  next = (current + 1) % capacity    ← avanzar
  prev = (current - 1 + cap) % cap   ← retroceder

Este patrón aparece en:
  • Circular Queue
  • Circular Deque
  • Circular Buffer (networking, audio)
  • Ring Buffer (kernels, sistemas embebidos)
  • Round Robin scheduling
```

### Las tres formas de implementar una queue

```text
┌─────────────────────────┐
│  1. Circular Array      │ → Rápida, cache-friendly, tamaño fijo
│     enqueue/dequeue O(1)│
├─────────────────────────┤
│  2. Linked List         │ → Flexible, crece sin límite
│     enqueue/dequeue O(1)│
├─────────────────────────┤
│  3. Dos Stacks          │ → Ingeniosa, amortized O(1)
│     Invierte LIFO→FIFO  │ → Demuestra que LIFO×2 = FIFO
└─────────────────────────┘
```

### Relación con otros temas

| Tema                             | Archivo              |
| -------------------------------- | -------------------- |
| Arrays a bajo nivel              | Arrays CDT.md        |
| Operaciones sobre arrays         | Arrays ADT.md        |
| Matrices densas y especiales     | Matrices.md          |
| Sparse matrices y polinomios     | SparseMatrices.md    |
| Strings (arrays de char)         | Strings.md           |
| Linked Lists                     | LinkedList.md        |
| Stacks                           | Stack.md             |
| Trees (BFS usa queue)            | Trees.md             |
| **Queues (este)**                | Queue.md             |
