# Stack — Estructura LIFO

> **Idea central:** Un stack es la estructura de datos más simple con la restricción más poderosa:
> **solo puedes operar en un extremo** — el tope. Esta restricción (LIFO) convierte al stack en la herramienta
> perfecta para resolver problemas de **anidamiento**, **reversión** y **evaluación de expresiones**.
> Detrás de cada llamada a función, cada `Ctrl+Z`, y cada compilador, hay un stack trabajando.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Concepto y Modelo LIFO](#1-concepto-y-modelo-lifo)
2. [Casos de Uso Reales](#2-casos-de-uso-reales)

**Parte II — Implementaciones**
3. [Stack con Arrays](#3-stack-con-arrays)
4. [Stack con Linked List](#4-stack-con-linked-list)
5. [Comparación de Implementaciones](#5-comparación-de-implementaciones)

**Parte III — Aplicación: Parenthesis Matching**
6. [Parenthesis Matching](#6-parenthesis-matching)

**Parte IV — Expresiones Aritméticas**
7. [Infix, Postfix y Prefix](#7-infix-postfix-y-prefix)
8. [Infix to Postfix — Conversión](#8-infix-to-postfix--conversión)
9. [Evaluación de Expresiones Postfix](#9-evaluación-de-expresiones-postfix)

**Parte V — Síntesis**
10. [Resumen de Complejidad](#10-resumen-de-complejidad)
11. [Errores Comunes y Buenas Prácticas](#11-errores-comunes-y-buenas-prácticas)
12. [Intuición de Ingeniería](#12-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS

---

# 1. Concepto y Modelo LIFO

## 1.1 Definición

Un **Stack** (pila) es una colección ordenada de elementos donde las inserciones y eliminaciones
ocurren **solo en un extremo** llamado **top** (tope).

Principio: **LIFO — Last In, First Out** (el último que entra es el primero que sale).

```text
         ┌─────────┐
         │   top    │  ← push / pop / peek aquí
         ├─────────┤
         │         │
         ├─────────┤
         │         │
         ├─────────┤
         │  base   │
         └─────────┘

Push (insertar): colocar en el tope
Pop (eliminar):  sacar del tope
Peek (ver):      ver el tope sin sacarlo
```

## 1.2 Analogía

```text
Pila de platos:
                 ┌─────┐
    último →     │  D  │  ← primer plato que sacas
                 ├─────┤
                 │  C  │
                 ├─────┤
                 │  B  │
                 ├─────┤
    primero →    │  A  │  ← último plato que sacas
                 └─────┘

Push D  →  D queda arriba
Pop     →  D sale primero (LIFO)
```

## 1.3 ADT Stack — Operaciones

| Operación       | Descripción                                | Precondición        |
| --------------- | ------------------------------------------ | ------------------- |
| `push(x)`       | Insertar `x` en el tope                   | Stack no lleno*     |
| `pop()`         | Eliminar y retornar el tope               | Stack no vacío      |
| `peek()` / `top()` | Retornar el tope sin eliminarlo        | Stack no vacío      |
| `isEmpty()`     | ¿Está vacío?                               | Ninguna             |
| `isFull()`      | ¿Está lleno? (solo con arrays)             | Ninguna             |

*Solo aplica en implementación con arrays de tamaño fijo.

## 1.4 Comportamiento visual

```text
Operación       Stack (tope → base)     Retorno
─────────────────────────────────────────────────
push(10)        [10]                     —
push(20)        [20, 10]                 —
push(30)        [30, 20, 10]             —
peek()          [30, 20, 10]             30
pop()           [20, 10]                 30
pop()           [10]                     20
isEmpty()       [10]                     false
pop()           []                       10
isEmpty()       []                       true
pop()           []                       ERROR: underflow
```

---

# 2. Casos de Uso Reales

| Caso de uso                       | Cómo usa el stack                                      |
| --------------------------------- | ------------------------------------------------------ |
| **Call Stack** (funciones)        | Cada llamada a función se apila; al retornar, se desapila |
| **Undo/Redo** (Ctrl+Z)           | Cada acción se apila; undo = pop                       |
| **Navegador** (back/forward)     | Páginas visitadas en un stack                          |
| **Evaluación de expresiones**    | Evaluar `3 + 4 * 2` con precedencia                   |
| **Paréntesis matching**          | Verificar que `({[]})` está balanceado                 |
| **Conversión de bases**          | Dividir entre base, apilar restos, pop para resultado  |
| **DFS** (grafos)                 | Stack para explorar en profundidad                     |
| **Recursión**                    | El compilador usa un stack implícito                   |
| **Syntax parsing** (compilador)  | Análisis de gramáticas con stack                       |

### El Call Stack — ejemplo concreto

```c
void C() { printf("C\n"); }
void B() { C(); }
void A() { B(); }
int main() { A(); return 0; }
```

```text
Call Stack durante ejecución:

main() llama A():       main() llama A(), A() llama B():
┌──────┐                ┌──────┐
│  A() │                │  B() │
├──────┤                ├──────┤
│ main │                │  A() │
└──────┘                ├──────┤
                        │ main │
                        └──────┘

B() llama C():          C() retorna:           B() retorna:
┌──────┐                ┌──────┐               ┌──────┐
│  C() │                │  B() │               │  A() │
├──────┤                ├──────┤               ├──────┤
│  B() │                │  A() │               │ main │
├──────┤                ├──────┤               └──────┘
│  A() │                │ main │
├──────┤                └──────┘
│ main │
└──────┘
```

> **Cada `return` es un `pop`.** Si nunca haces return (recursión infinita), el stack se desborda → **Stack Overflow**.

---

# PARTE II — IMPLEMENTACIONES

---

# 3. Stack con Arrays

## 3.1 Modelo

Usar un array de tamaño fijo y un índice `top` que indica la posición del elemento en el tope.

```text
Convención: top = -1 → stack vacío

Capacidad = 5:

  Índice:   0     1     2     3     4
          ┌─────┬─────┬─────┬─────┬─────┐
          │  10 │  20 │  30 │     │     │
          └─────┴─────┴─────┴─────┴─────┘
                         ↑
                       top = 2

push(40):
          ┌─────┬─────┬─────┬─────┬─────┐
          │  10 │  20 │  30 │  40 │     │
          └─────┴─────┴─────┴─────┴─────┘
                                ↑
                              top = 3

pop() → retorna 40:
          ┌─────┬─────┬─────┬─────┬─────┐
          │  10 │  20 │  30 │ (40)│     │
          └─────┴─────┴─────┴─────┴─────┘
                         ↑
                       top = 2
                       (40 sigue en memoria pero es inaccesible)
```

## 3.2 Estructura

```c
#include <stdio.h>
#include <stdlib.h>

#define MAX_SIZE 100

typedef struct {
    int data[MAX_SIZE];
    int top;
} Stack;
```

## 3.3 Implementación completa

```c
// --- Crear ---
Stack* createStack() {
    Stack *s = (Stack*)malloc(sizeof(Stack));
    s->top = -1;
    return s;
}

// --- isEmpty ---
int isEmpty(Stack *s) {
    return s->top == -1;
}

// --- isFull ---
int isFull(Stack *s) {
    return s->top == MAX_SIZE - 1;
}

// --- Push ---
void push(Stack *s, int value) {
    if (isFull(s)) {
        printf("Error: Stack Overflow\n");
        return;
    }
    s->top++;
    s->data[s->top] = value;
}

// Equivalente compacto:
// void push(Stack *s, int value) { s->data[++s->top] = value; }

// --- Pop ---
int pop(Stack *s) {
    if (isEmpty(s)) {
        printf("Error: Stack Underflow\n");
        return -1;      // valor centinela (problema: -1 podría ser dato válido)
    }
    int val = s->data[s->top];
    s->top--;
    return val;
}

// --- Peek ---
int peek(Stack *s) {
    if (isEmpty(s)) {
        printf("Error: Stack vacío\n");
        return -1;
    }
    return s->data[s->top];
}

// --- Display ---
void displayStack(Stack *s) {
    printf("Stack (top → base): ");
    for (int i = s->top; i >= 0; i--)
        printf("%d ", s->data[i]);
    printf("\n");
}

// --- Liberar ---
void freeStack(Stack *s) {
    free(s);
}
```

## 3.4 Ejemplo de uso

```c
int main() {
    Stack *s = createStack();

    push(s, 10);
    push(s, 20);
    push(s, 30);
    displayStack(s);       // Stack (top → base): 30 20 10

    printf("Pop: %d\n", pop(s));    // Pop: 30
    printf("Peek: %d\n", peek(s));  // Peek: 20

    displayStack(s);       // Stack (top → base): 20 10

    freeStack(s);
    return 0;
}
```

## 3.5 Stack dinámico con arrays (realloc)

Si el tamaño fijo es limitante, se puede usar un array dinámico con over-allocation:

```c
typedef struct {
    int *data;
    int top;
    int capacity;
} DynStack;

DynStack* createDynStack(int initialCap) {
    DynStack *s = (DynStack*)malloc(sizeof(DynStack));
    s->data = (int*)malloc(initialCap * sizeof(int));
    s->top = -1;
    s->capacity = initialCap;
    return s;
}

void dynPush(DynStack *s, int value) {
    if (s->top == s->capacity - 1) {
        s->capacity *= 2;
        int *temp = realloc(s->data, s->capacity * sizeof(int));
        if (temp == NULL) { printf("Error: realloc failed\n"); return; }
        s->data = temp;
    }
    s->data[++s->top] = value;
}
```

| Operación | Complejidad                        |
| --------- | ---------------------------------- |
| Push      | **O(1)** amortizado (O(n) resize) |
| Pop       | **O(1)**                           |
| Peek      | **O(1)**                           |
| isEmpty   | **O(1)**                           |

---

# 4. Stack con Linked List

## 4.1 Modelo

Cada push crea un nuevo nodo que apunta al anterior tope. El **head** de la lista es el **top** del stack.

```text
Push(10):    top → [10|NULL]

Push(20):    top → [20|─]→[10|NULL]

Push(30):    top → [30|─]→[20|─]→[10|NULL]

Pop():       top → [20|─]→[10|NULL]     retorna 30, free(30)
```

> **Push = insertFirst.** **Pop = deleteFirst.** Ambos O(1).

## 4.2 Estructura

```c
typedef struct SNode {
    int data;
    struct SNode *next;
} SNode;

typedef struct {
    SNode *top;
    int size;       // opcional: llevar cuenta del tamaño
} LLStack;
```

## 4.3 Implementación completa

```c
// --- Crear ---
LLStack* createLLStack() {
    LLStack *s = (LLStack*)malloc(sizeof(LLStack));
    s->top = NULL;
    s->size = 0;
    return s;
}

// --- isEmpty ---
int isEmptyLL(LLStack *s) {
    return s->top == NULL;
}

// --- Push ---
void pushLL(LLStack *s, int value) {
    SNode *n = (SNode*)malloc(sizeof(SNode));
    if (n == NULL) {
        printf("Error: malloc failed (heap exhausto)\n");
        return;
    }
    n->data = value;
    n->next = s->top;
    s->top = n;
    s->size++;
}

// --- Pop ---
int popLL(LLStack *s) {
    if (isEmptyLL(s)) {
        printf("Error: Stack Underflow\n");
        return -1;
    }
    SNode *temp = s->top;
    int val = temp->data;
    s->top = temp->next;
    free(temp);
    s->size--;
    return val;
}

// --- Peek ---
int peekLL(LLStack *s) {
    if (isEmptyLL(s)) {
        printf("Error: Stack vacío\n");
        return -1;
    }
    return s->top->data;
}

// --- Display ---
void displayLLStack(LLStack *s) {
    printf("Stack (top → base): ");
    SNode *p = s->top;
    while (p != NULL) {
        printf("%d ", p->data);
        p = p->next;
    }
    printf("\n");
}

// --- Liberar todo ---
void freeLLStack(LLStack *s) {
    while (!isEmptyLL(s))
        popLL(s);
    free(s);
}
```

| Operación | Complejidad |
| --------- | ----------- |
| Push      | **O(1)**    |
| Pop       | **O(1)**    |
| Peek      | **O(1)**    |
| isEmpty   | **O(1)**    |
| isFull    | N/A (crece dinámicamente) |

---

# 5. Comparación de Implementaciones

| Aspecto                | Array (fijo)            | Array (dinámico)       | Linked List             |
| ---------------------- | ----------------------- | ---------------------- | ----------------------- |
| Tamaño                 | Fijo                    | Crece × 2             | Ilimitado (heap)        |
| Push                   | O(1)                    | O(1) amortizado       | O(1)                    |
| Pop                    | O(1)                    | O(1)                  | O(1)                    |
| Overflow               | Posible                 | Raro (resize)         | Solo si heap se agota   |
| Espacio por elemento   | `sizeof(int)` = 4B     | `sizeof(int)` = 4B   | `sizeof(int) + sizeof(ptr)` = 12B |
| Cache performance      | **Excelente**           | **Excelente**         | Pobre (nodos dispersos) |
| Memoria desperdiciada  | Espacio no usado        | Hasta 50% (×2)       | Overhead de punteros    |
| Liberación             | `free(stack)` — simple  | `free(data)+free(s)`  | Recorrer y liberar cada nodo |
| Complejidad de impl.   | Baja                    | Media                 | Media                   |
| Mejor para             | Tamaño conocido         | Tamaño variable       | Muchos push/pop + tamaño impredecible |

> **Regla práctica:** Si sabes el tamaño máximo, usa array (mejor cache). Si no, usa linked list o array dinámico.

---

# PARTE III — APLICACIÓN: PARENTHESIS MATCHING

---

# 6. Parenthesis Matching

## 6.1 El problema

Determinar si una expresión tiene **paréntesis balanceados**:

```text
✅ Balanceados:    ()    (())    ({[]})    a*(b+c)
❌ No balanceados: (     )(      ({)}      ((()
```

## 6.2 ¿Por qué un stack?

Los paréntesis tienen una propiedad **LIFO natural**: el último paréntesis abierto es el primero que debe cerrarse.

```text
Expresión: ( { [ ] } )

Lectura izq → der:
  '(' → push      Stack: [( ]
  '{' → push      Stack: [{ ( ]
  '[' → push      Stack: [[ { ( ]
  ']' → pop '['   Stack: [{ ( ]     ← ']' cierra '['  ✓
  '}' → pop '{'   Stack: [( ]       ← '}' cierra '{'  ✓
  ')' → pop '('   Stack: [ ]        ← ')' cierra '('  ✓

Stack vacío al final → ✅ balanceado
```

## 6.3 Caso básico: solo `()`

```c
int isBalancedSimple(char *expr) {
    Stack *s = createStack();

    for (int i = 0; expr[i] != '\0'; i++) {
        if (expr[i] == '(') {
            push(s, expr[i]);
        } else if (expr[i] == ')') {
            if (isEmpty(s)) {
                freeStack(s);
                return 0;           // ')' sin '(' correspondiente
            }
            pop(s);
        }
    }

    int balanced = isEmpty(s);      // si queda algo → '(' sin cerrar
    freeStack(s);
    return balanced;
}
```

## 6.4 Caso extendido: `()`, `{}`, `[]`

```c
int isMatchingPair(char open, char close) {
    return (open == '(' && close == ')') ||
           (open == '{' && close == '}') ||
           (open == '[' && close == ']');
}

int isBalanced(char *expr) {
    Stack *s = createStack();

    for (int i = 0; expr[i] != '\0'; i++) {
        char c = expr[i];

        if (c == '(' || c == '{' || c == '[') {
            push(s, c);
        }
        else if (c == ')' || c == '}' || c == ']') {
            if (isEmpty(s)) {
                freeStack(s);
                return 0;       // cierre sin apertura
            }
            char top = pop(s);
            if (!isMatchingPair(top, c)) {
                freeStack(s);
                return 0;       // tipo no coincide
            }
        }
        // otros caracteres se ignoran
    }

    int balanced = isEmpty(s);
    freeStack(s);
    return balanced;
}
```

## 6.5 Traza paso a paso

```text
Expresión: "{[a*(b+c)]-d}"

Char │ Acción            │ Stack (top → base)  │ Estado
─────┼───────────────────┼─────────────────────┼───────
 {   │ push '{'          │ [{ ]                │
 [   │ push '['          │ [[ { ]              │
 a   │ ignorar           │ [[ { ]              │
 *   │ ignorar           │ [[ { ]              │
 (   │ push '('          │ [( [ { ]            │
 b   │ ignorar           │ [( [ { ]            │
 +   │ ignorar           │ [( [ { ]            │
 c   │ ignorar           │ [( [ { ]            │
 )   │ pop '(' match ')' │ [[ { ]              │ ✓
 ]   │ pop '[' match ']' │ [{ ]                │ ✓
 -   │ ignorar           │ [{ ]                │
 d   │ ignorar           │ [{ ]                │
 }   │ pop '{' match '}' │ [ ]                 │ ✓

Stack vacío → ✅ balanceado
```

## 6.6 Casos edge

| Expresión | Resultado | Razón                               |
| --------- | --------- | ----------------------------------- |
| `""`      | ✅        | Vacío es balanceado                 |
| `"("`     | ❌        | Apertura sin cierre                 |
| `")"`     | ❌        | Cierre sin apertura                 |
| `"({)}"`  | ❌        | Tipo cruzado: `{` espera `}` no `)` |
| `"abc"`   | ✅        | Sin paréntesis = balanceado         |
| `"((()))"`| ✅        | Anidamiento profundo válido         |

---

# PARTE IV — EXPRESIONES ARITMÉTICAS

---

# 7. Infix, Postfix y Prefix

## 7.1 Tres formas de escribir expresiones

| Notación   | Formato                     | Ejemplo (`a + b`)  |
| ---------- | --------------------------- | ------------------- |
| **Infix**  | `operando operador operando` | `a + b`            |
| **Prefix** | `operador operando operando` | `+ a b`            |
| **Postfix**| `operando operando operador` | `a b +`            |

## 7.2 ¿Por qué importa?

```text
Infix:    a + b * c        ← ¿Es (a+b)*c o a+(b*c)?
                              Necesitas precedencia y paréntesis.

Postfix:  a b c * +        ← Sin ambigüedad. El orden define todo.
                              No necesitas paréntesis ni precedencia.

Prefix:   + a * b c        ← Igual que postfix, pero leído de derecha a izquierda.
```

> **Los compiladores convierten infix → postfix** porque postfix se puede evaluar linealmente con un stack, sin preocuparse por precedencia ni paréntesis.

## 7.3 Ejemplos de conversión

| Infix                    | Postfix                  | Prefix                   |
| ------------------------ | ------------------------ | ------------------------ |
| `a + b`                  | `a b +`                  | `+ a b`                  |
| `a + b * c`              | `a b c * +`              | `+ a * b c`              |
| `(a + b) * c`            | `a b + c *`              | `* + a b c`              |
| `a + b * c - d`          | `a b c * + d -`          | `- + a * b c d`          |
| `(a + b) * (c - d)`      | `a b + c d - *`          | `* + a b - c d`          |
| `a ^ b ^ c`              | `a b c ^ ^`              | `^ a ^ b c`              |

## 7.4 Precedencia y asociatividad

| Operador | Precedencia | Asociatividad |
| -------- | ----------- | ------------- |
| `^`      | 3 (alta)    | **Derecha**   |
| `*` `/`  | 2           | Izquierda     |
| `+` `-`  | 1 (baja)    | Izquierda     |

> **Asociatividad** define cómo se agrupan operadores de **igual precedencia**:
> - Izquierda: `a - b - c` = `(a - b) - c`
> - Derecha: `a ^ b ^ c` = `a ^ (b ^ c)`

---

# 8. Infix to Postfix — Conversión

## 8.1 Método A: Solo operadores (sin paréntesis)

### Algoritmo

```text
Para cada símbolo en la expresión infix (izquierda → derecha):
  1. Si es operando → agregar directamente al output
  2. Si es operador:
     a. Mientras el stack no esté vacío
        Y el tope del stack tenga precedencia >= al operador actual
        Y (si misma precedencia, el operador es left-associative):
        → pop del stack y agregar al output
     b. Push el operador actual al stack
  3. Al terminar: pop todo lo que quede en el stack al output
```

### Tabla de precedencia

```c
int precedence(char op) {
    switch (op) {
        case '^': return 3;
        case '*': case '/': return 2;
        case '+': case '-': return 1;
        default: return 0;
    }
}

int isRightAssociative(char op) {
    return op == '^';
}
```

### Implementación

```c
int isOperand(char c) {
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
}

int isOperator(char c) {
    return c == '+' || c == '-' || c == '*' || c == '/' || c == '^';
}

// Infix to Postfix — sin paréntesis
void infixToPostfixSimple(char *infix, char *postfix) {
    Stack *s = createStack();
    int j = 0;

    for (int i = 0; infix[i] != '\0'; i++) {
        char c = infix[i];

        if (c == ' ') continue;     // ignorar espacios

        if (isOperand(c)) {
            postfix[j++] = c;
        }
        else if (isOperator(c)) {
            while (!isEmpty(s) &&
                   isOperator(peek(s)) &&
                   (precedence(peek(s)) > precedence(c) ||
                    (precedence(peek(s)) == precedence(c) && !isRightAssociative(c))))
            {
                postfix[j++] = pop(s);
            }
            push(s, c);
        }
    }

    // Vaciar el stack
    while (!isEmpty(s))
        postfix[j++] = pop(s);

    postfix[j] = '\0';
    freeStack(s);
}
```

### Traza: `a + b * c - d`

```text
Precedencia: * (2) > + (1) = - (1)

Char │ Acción                            │ Stack  │ Output
─────┼───────────────────────────────────┼────────┼──────────
 a   │ operando → output                 │ [ ]    │ a
 +   │ stack vacío → push                │ [+]    │ a
 b   │ operando → output                 │ [+]    │ ab
 *   │ prec(*) > prec(+) → push          │ [*+]   │ ab
 c   │ operando → output                 │ [*+]   │ abc
 -   │ prec(*) > prec(-) → pop * output  │ [+]    │ abc*
     │ prec(+) = prec(-), left → pop +   │ [ ]    │ abc*+
     │ push -                             │ [-]    │ abc*+
 d   │ operando → output                 │ [-]    │ abc*+d
 FIN │ pop todo                           │ [ ]    │ abc*+d-

Resultado: a b c * + d -   ✓
```

### Traza con asociatividad derecha: `a ^ b ^ c`

```text
Char │ Acción                               │ Stack  │ Output
─────┼──────────────────────────────────────┼────────┼──────────
 a   │ operando → output                    │ [ ]    │ a
 ^   │ stack vacío → push                   │ [^]    │ a
 b   │ operando → output                    │ [^]    │ ab
 ^   │ prec(^) = prec(^), right-assoc       │ [^^]   │ ab
     │ → NO pop (right-assoc), push         │        │
 c   │ operando → output                    │ [^^]   │ abc
 FIN │ pop todo                              │ [ ]    │ abc^^

Resultado: a b c ^ ^   ✓
(Equivale a a ^ (b ^ c), correcto para right-associative)
```

---

## 8.2 Método B: Con paréntesis

### El problema

Los paréntesis anulan la precedencia natural:

```text
Sin paréntesis:  a + b * c    →    a b c * +    (* antes que +)
Con paréntesis:  (a + b) * c  →    a b + c *    (+ antes que *, por los paréntesis)
```

### Algoritmo extendido

```text
Para cada símbolo:
  1. Operando         → output
  2. '('              → push al stack
  3. ')'              → pop y output hasta encontrar '(' en el stack, luego descartar '('
  4. Operador         → (misma lógica de precedencia, pero NUNCA pop un '(')
  5. Fin              → pop todo al output
```

### Implementación

```c
void infixToPostfix(char *infix, char *postfix) {
    Stack *s = createStack();
    int j = 0;

    for (int i = 0; infix[i] != '\0'; i++) {
        char c = infix[i];

        if (c == ' ') continue;

        if (isOperand(c)) {
            postfix[j++] = c;
        }
        else if (c == '(') {
            push(s, c);
        }
        else if (c == ')') {
            while (!isEmpty(s) && peek(s) != '(') {
                postfix[j++] = pop(s);
            }
            if (!isEmpty(s))
                pop(s);     // descartar '('
        }
        else if (isOperator(c)) {
            while (!isEmpty(s) &&
                   peek(s) != '(' &&
                   isOperator(peek(s)) &&
                   (precedence(peek(s)) > precedence(c) ||
                    (precedence(peek(s)) == precedence(c) && !isRightAssociative(c))))
            {
                postfix[j++] = pop(s);
            }
            push(s, c);
        }
    }

    while (!isEmpty(s))
        postfix[j++] = pop(s);

    postfix[j] = '\0';
    freeStack(s);
}
```

### Traza: `(a + b) * (c - d)`

```text
Char │ Acción                            │ Stack      │ Output
─────┼───────────────────────────────────┼────────────┼──────────
 (   │ push '('                          │ [(]        │
 a   │ operando → output                 │ [(]        │ a
 +   │ tope es '(' → push               │ [+(]       │ a
 b   │ operando → output                 │ [+(]       │ ab
 )   │ pop hasta '(': pop '+'           │ [ ]        │ ab+
 *   │ stack vacío → push               │ [*]        │ ab+
 (   │ push '('                          │ [(*]       │ ab+
 c   │ operando → output                 │ [(*]       │ ab+c
 -   │ tope es '(' → push               │ [-(* ]     │ ab+c
 d   │ operando → output                 │ [-(*]      │ ab+cd
 )   │ pop hasta '(': pop '-'           │ [*]        │ ab+cd-
 FIN │ pop todo: pop '*'                 │ [ ]        │ ab+cd-*

Resultado: a b + c d - *   ✓
```

---

## 8.3 Método C: In-Stack vs Out-Stack Precedence (ISP/OSP)

### Motivación

Los métodos anteriores tratan `(` como caso especial con `if`s. Este método **unifica todo** asignando dos precedencias distintas a cada símbolo:

| Concepto | Sigla | Significado |
| -------- | ----- | ----------- |
| **In-Stack Precedence** | ISP | Precedencia del símbolo **cuando ya está dentro** del stack |
| **Out-Stack Precedence** | OSP | Precedencia del símbolo **cuando viene de la entrada** |

### Tabla ISP / OSP

| Símbolo | OSP (entrada) | ISP (en stack) | Nota                                |
| ------- | ------------- | -------------- | ----------------------------------- |
| `+` `-` | 1             | 1              | Normal                              |
| `*` `/` | 3             | 3              | Normal                              |
| `^`     | 6             | 5              | Right-assoc: OSP > ISP → se apila   |
| `(`     | 7             | 0              | OSP alto (siempre entra), ISP bajo (nunca expulsa nada) |
| `)`     | 0             | —              | OSP bajo (nunca entra), provoca pops |
| `\0`    | 0             | —              | Fin de expresión, vaciar stack       |

> **Regla unificada:**
> - Si `OSP(c) > ISP(top)` → **push** `c`
> - Si `OSP(c) < ISP(top)` → **pop** top al output, repetir
> - Si `OSP(c) == ISP(top)` → **pop** (para `()` se cancelan mutuamente)

### ¿Por qué funciona?

```text
'(' tiene OSP=7 (máximo) → SIEMPRE entra al stack (push por encima de todo)
'(' tiene ISP=0 (mínimo) → NUNCA es expulsado por un operador (actúa como barrera)

')' tiene OSP=0 → nunca entra, pero provoca pop de todo hasta encontrar '('
Cuando ISP('(') == OSP(')') = 0, ambos se cancelan (pop '(' y descartar ')')

'^' tiene OSP=6 > ISP=5 → cuando hay ^ en stack y llega otro ^,
OSP(6) > ISP(5) → push (right-associative, se apilan)
```

### Implementación ISP/OSP

```c
int outStackPrecedence(char c) {
    switch (c) {
        case '+': case '-': return 1;
        case '*': case '/': return 3;
        case '^':           return 6;
        case '(':           return 7;
        case ')':           return 0;
        default:            return -1;
    }
}

int inStackPrecedence(char c) {
    switch (c) {
        case '+': case '-': return 1;
        case '*': case '/': return 3;
        case '^':           return 5;
        case '(':           return 0;
        default:            return -1;
    }
}

void infixToPostfixISP(char *infix, char *postfix) {
    Stack *s = createStack();
    int j = 0;

    for (int i = 0; infix[i] != '\0'; i++) {
        char c = infix[i];

        if (c == ' ') continue;

        if (isOperand(c)) {
            postfix[j++] = c;
        } else {
            // Pop mientras ISP(top) >= OSP(c)
            // (excepto cuando son iguales Y es un par () que se cancela)
            while (!isEmpty(s) && inStackPrecedence(peek(s)) >= outStackPrecedence(c)) {
                if (peek(s) == '(' && c == ')') {
                    pop(s);         // descartar '('
                    goto nextChar;  // ')' tampoco entra
                }
                postfix[j++] = pop(s);
            }

            if (c != ')')
                push(s, c);
        }
        nextChar:;
    }

    // Vaciar stack
    while (!isEmpty(s))
        postfix[j++] = pop(s);

    postfix[j] = '\0';
    freeStack(s);
}
```

### Traza ISP/OSP: `((a+b)*c)-d^e^f`

```text
Char │ OSP vs ISP(top)                    │ Acción              │ Stack        │ Output
─────┼─────────────────────────────────────┼─────────────────────┼──────────────┼──────────
 (   │ OSP(7) > stack vacío               │ push                │ [(]          │
 (   │ OSP(7) > ISP('(')=0               │ push                │ [((]         │
 a   │ operando                            │ output              │ [((]         │ a
 +   │ OSP(1) > ISP('(')=0               │ push                │ [+((]        │ a
 b   │ operando                            │ output              │ [+((]        │ ab
 )   │ OSP(0) < ISP('+')=1               │ pop + → output      │ [((]         │ ab+
     │ OSP(0) == ISP('(')=0              │ pop '(' cancel ')'  │ [(]          │ ab+
 *   │ OSP(3) > ISP('(')=0               │ push                │ [*(]         │ ab+
 c   │ operando                            │ output              │ [*(]         │ ab+c
 )   │ OSP(0) < ISP('*')=3               │ pop * → output      │ [(]          │ ab+c*
     │ OSP(0) == ISP('(')=0              │ pop '(' cancel ')'  │ [ ]          │ ab+c*
 -   │ OSP(1) > stack vacío               │ push                │ [-]          │ ab+c*
 d   │ operando                            │ output              │ [-]          │ ab+c*d
 ^   │ OSP(6) > ISP('-')=1               │ push                │ [^-]         │ ab+c*d
 e   │ operando                            │ output              │ [^-]         │ ab+c*de
 ^   │ OSP(6) > ISP('^')=5               │ push (right-assoc!) │ [^^-]        │ ab+c*de
 f   │ operando                            │ output              │ [^^-]        │ ab+c*def
 FIN │ pop todo                            │                     │ [ ]          │ ab+c*def^^-

Resultado: a b + c * d e f ^ ^ -   ✓

Verificación: ((a+b)*c) - d^(e^f)  ← correcto
```

---

## 8.4 Comparación de los tres métodos

| Método                    | Paréntesis | Right-assoc | Complejidad impl. | Elegancia |
| ------------------------- | ---------- | ----------- | ------------------ | --------- |
| **A** (solo operadores)   | ❌         | ✅          | Baja               | Simple    |
| **B** (con paréntesis)    | ✅         | ✅          | Media              | Con `if`s |
| **C** (ISP/OSP)           | ✅         | ✅          | Media              | **Unificado** |

> Método C es el más **elegante** — un solo `while` con dos funciones de precedencia maneja todo:
> operadores, paréntesis y asociatividad. Es el que usan los compiladores reales.

---

## 8.5 Referencia rápida: ISP/OSP completa

```text
┌──────────┬─────┬─────┬───────────────────────────────────┐
│ Símbolo  │ OSP │ ISP │ Comportamiento                    │
├──────────┼─────┼─────┼───────────────────────────────────┤
│  + -     │  1  │  1  │ Left-assoc: OSP = ISP → pop       │
│  * /     │  3  │  3  │ Left-assoc: OSP = ISP → pop       │
│  ^       │  6  │  5  │ Right-assoc: OSP > ISP → push     │
│  (       │  7  │  0  │ Siempre entra, nunca es expulsado  │
│  )       │  0  │  —  │ Nunca entra, expulsa hasta '('    │
│  \0      │  0  │  —  │ Fin, vaciar stack                 │
└──────────┴─────┴─────┴───────────────────────────────────┘
```

> Para **left-associative** con la misma precedencia: ISP = OSP → `ISP >= OSP` es verdadero → **pop** (correcto).
> Para **right-associative** con la misma precedencia: ISP < OSP → `ISP >= OSP` es falso → **push** (correcto).

---

# 9. Evaluación de Expresiones Postfix

## 9.1 ¿Por qué evaluar postfix?

La expresión postfix **ya tiene el orden de ejecución resuelto**. No necesitas precedencia ni paréntesis.
Solo necesitas un stack.

## 9.2 Algoritmo

```text
Para cada símbolo (izquierda → derecha):
  1. Si es operando → push al stack
  2. Si es operador:
     a. Pop dos operandos: op2 = pop(), op1 = pop()    ← ORDEN IMPORTA
     b. Calcular:  resultado = op1 OPERADOR op2
     c. Push resultado al stack
  3. Al terminar: el único elemento en el stack es el resultado
```

> **⚠️ Orden de pop:** `op2` sale primero (es el operando derecho), `op1` sale segundo (es el izquierdo).
> Esto importa para operadores no conmutativos: `5 3 -` = `5 - 3` = 2, **no** `3 - 5`.

## 9.3 Implementación

```c
int evalPostfix(char *postfix) {
    Stack *s = createStack();

    for (int i = 0; postfix[i] != '\0'; i++) {
        char c = postfix[i];

        if (c == ' ') continue;

        if (c >= '0' && c <= '9') {
            push(s, c - '0');           // convertir char a int
        }
        else if (isOperator(c)) {
            int op2 = pop(s);           // ⚠️ op2 sale PRIMERO
            int op1 = pop(s);           // op1 sale SEGUNDO
            int result;

            switch (c) {
                case '+': result = op1 + op2; break;
                case '-': result = op1 - op2; break;
                case '*': result = op1 * op2; break;
                case '/':
                    if (op2 == 0) {
                        printf("Error: división por cero\n");
                        freeStack(s);
                        return 0;
                    }
                    result = op1 / op2;
                    break;
                case '^':
                    result = 1;
                    for (int p = 0; p < op2; p++)
                        result *= op1;
                    break;
                default: result = 0;
            }

            push(s, result);
        }
    }

    int finalResult = pop(s);
    freeStack(s);
    return finalResult;
}
```

## 9.4 Traza: `5 3 + 8 2 - *`

Equivale a: `(5 + 3) * (8 - 2)` = `8 * 6` = `48`

```text
Char │ Acción                          │ Stack (top → base) │ Nota
─────┼─────────────────────────────────┼────────────────────┼──────────────
 5   │ push 5                          │ [5]                │
 3   │ push 3                          │ [3, 5]             │
 +   │ pop 3, pop 5 → 5+3=8, push 8   │ [8]                │ op1=5, op2=3
 8   │ push 8                          │ [8, 8]             │
 2   │ push 2                          │ [2, 8, 8]          │
 -   │ pop 2, pop 8 → 8-2=6, push 6   │ [6, 8]             │ op1=8, op2=2
 *   │ pop 6, pop 8 → 8*6=48, push 48 │ [48]               │ op1=8, op2=6

Resultado: 48   ✓
```

## 9.5 Traza compleja: `2 3 1 * + 9 -`

Equivale a: `2 + 3 * 1 - 9` = `(2 + (3*1)) - 9` = `5 - 9` = `-4`

```text
Char │ Acción                          │ Stack (top → base) │
─────┼─────────────────────────────────┼────────────────────┤
 2   │ push 2                          │ [2]                │
 3   │ push 3                          │ [3, 2]             │
 1   │ push 1                          │ [1, 3, 2]          │
 *   │ pop 1, pop 3 → 3*1=3, push 3   │ [3, 2]             │
 +   │ pop 3, pop 2 → 2+3=5, push 5   │ [5]                │
 9   │ push 9                          │ [9, 5]             │
 -   │ pop 9, pop 5 → 5-9=-4, push -4 │ [-4]               │

Resultado: -4   ✓
```

## 9.6 Traza con potencia: `2 3 2 ^ *`

Equivale a: `2 * 3^2` = `2 * 9` = `18`

```text
Char │ Acción                          │ Stack (top → base) │
─────┼─────────────────────────────────┼────────────────────┤
 2   │ push 2                          │ [2]                │
 3   │ push 3                          │ [3, 2]             │
 2   │ push 2                          │ [2, 3, 2]          │
 ^   │ pop 2, pop 3 → 3^2=9, push 9   │ [9, 2]             │
 *   │ pop 9, pop 2 → 2*9=18, push 18 │ [18]               │

Resultado: 18   ✓
```

## 9.7 Evaluación de postfix con operandos multi-dígito

La implementación anterior asume un dígito por operando. Para números de múltiples dígitos, se necesitan delimitadores (espacios):

```c
int evalPostfixMultiDigit(char *postfix) {
    Stack *s = createStack();
    int i = 0;

    while (postfix[i] != '\0') {
        if (postfix[i] == ' ') { i++; continue; }

        if (postfix[i] >= '0' && postfix[i] <= '9') {
            // Leer número completo
            int num = 0;
            while (postfix[i] >= '0' && postfix[i] <= '9') {
                num = num * 10 + (postfix[i] - '0');
                i++;
            }
            push(s, num);
        }
        else if (isOperator(postfix[i])) {
            int op2 = pop(s);
            int op1 = pop(s);
            int result;
            switch (postfix[i]) {
                case '+': result = op1 + op2; break;
                case '-': result = op1 - op2; break;
                case '*': result = op1 * op2; break;
                case '/': result = op1 / op2; break;
                default:  result = 0;
            }
            push(s, result);
            i++;
        }
        else { i++; }
    }

    int finalResult = pop(s);
    freeStack(s);
    return finalResult;
}

// Uso: evalPostfixMultiDigit("15 3 + 12 *")  →  (15+3)*12 = 216
```

---

# PARTE V — SÍNTESIS

---

# 10. Resumen de Complejidad

## Operaciones del Stack

| Operación       | Array (fijo) | Array (dinámico) | Linked List |
| --------------- | ------------ | ---------------- | ----------- |
| `push`          | O(1)         | O(1) amortizado  | O(1)        |
| `pop`           | O(1)         | O(1)             | O(1)        |
| `peek`          | O(1)         | O(1)             | O(1)        |
| `isEmpty`       | O(1)         | O(1)             | O(1)        |
| `isFull`        | O(1)         | N/A              | N/A         |
| **Espacio**     | O(n) fijo    | O(n) dinámico    | O(n) + ptrs |

## Aplicaciones

| Algoritmo                    | Complejidad    | Espacio    | Nota                      |
| ---------------------------- | -------------- | ---------- | ------------------------- |
| Parenthesis Matching         | **O(n)**       | O(n)       | Un recorrido              |
| Infix to Postfix             | **O(n)**       | O(n)       | Un recorrido + stack      |
| Evaluación Postfix           | **O(n)**       | O(n)       | Un recorrido + stack      |

> **Todas las aplicaciones son O(n)** — cada símbolo se procesa exactamente una vez (entra y sale del stack una vez).

---

# 11. Errores Comunes y Buenas Prácticas

### ⚠️ Errores Comunes

| Error                                            | Consecuencia                                |
| ------------------------------------------------ | ------------------------------------------- |
| Pop en stack vacío (underflow)                   | Basura o segfault                           |
| Push en stack lleno sin verificar (overflow)     | Sobreescribir memoria                       |
| Olvidar que `top = -1` es vacío (no 0)           | Off-by-one en todas las operaciones         |
| Orden incorrecto de pop en postfix eval          | `5 3 -` evalúa como `3-5` en vez de `5-3`  |
| No descartar `(` al encontrar `)` en conversión | `(` aparece en el output postfix            |
| Tratar `^` como left-associative                 | `2^3^2` da 64 en vez de 512                |
| No manejar paréntesis no balanceados             | Loop infinito o resultado incorrecto        |
| Comparar con `>=` para right-assoc               | Debería ser `>` para right-assoc            |
| Liberar stack sin vaciar (linked list)           | Memory leak de todos los nodos              |
| Asumir operandos de un solo dígito               | `"12"` se interpreta como `1` y `2`        |

### ✅ Buenas Prácticas

| Práctica                                          | Razón                                       |
| ------------------------------------------------- | ------------------------------------------- |
| Siempre verificar underflow antes de pop/peek    | Prevenir acceso a basura                    |
| Verificar overflow antes de push (arrays)        | Prevenir corrupción de memoria              |
| Usar `top = -1` como convención de vacío         | Consistente y simple                        |
| `op2 = pop()` ANTES de `op1 = pop()` en eval    | Mantener orden correcto de operandos        |
| Usar ISP/OSP para conversión robusta             | Maneja todo: precedencia, assoc, paréntesis |
| Separar tokens con espacios para multi-dígito    | Sin ambigüedad: `"12 3 +"` vs `"1 2 3 +"`  |
| Validar paréntesis ANTES de convertir infix      | Prevenir errores en la conversión           |
| Liberar toda la lista al destruir un LL stack    | Prevenir memory leaks                       |
| Probar con: stack vacío, 1 elemento, overflow    | Edge cases que revelan bugs                 |

```c
// ✅ Pop seguro
int safePop(Stack *s) {
    if (isEmpty(s)) {
        fprintf(stderr, "Error: stack underflow\n");
        exit(EXIT_FAILURE);
    }
    return s->data[s->top--];
}
```

---

# 12. Intuición de Ingeniería

> **Un stack no es una estructura de datos. Es un principio de diseño.**
> Cada vez que un problema requiere "recordar el contexto" y "deshacerlo en orden inverso", necesitas un stack.

### El patrón LIFO está en todas partes

```text
¿Necesitas...                              Solución
─────────────────────────────────────────────────────
...verificar anidamiento?                  Stack
...revertir algo?                          Stack
...evaluar con precedencia?                Stack
...convertir notaciones?                   Stack
...implementar recursión sin recursión?    Stack explícito
...deshacer operaciones?                   Stack
...gestionar contextos (funciones)?        Call Stack
```

### ¿Por qué ISP/OSP es brillante?

```text
El problema:
  Infix tiene 5 conceptos: operandos, operadores, precedencia, asociatividad, paréntesis.

La solución ingenua:
  Un if/else para cada concepto → código frágil y propenso a errores.

La solución ISP/OSP:
  Codificar TODO en dos números por símbolo → un solo while loop decide todo.

  Left-assoc:  ISP = OSP → el que está en stack gana (pop)
  Right-assoc: ISP < OSP → el que llega gana (push)
  '(' entra:   OSP = máximo → siempre entra
  '(' bloquea: ISP = mínimo → nunca es expulsado
  ')' limpia:  OSP = 0 → expulsa todo hasta '('

Toda la complejidad se reduce a: "¿ISP(top) >= OSP(nuevo)?"
```

### El pipeline completo de un compilador

```text
Expresión humana:    (3 + 4) * 2 - 1

  ┌────────────────────────┐
  │ 1. Parenthesis check   │  → ¿Balanceado? ✓
  ├────────────────────────┤
  │ 2. Infix → Postfix     │  → 3 4 + 2 * 1 -
  ├────────────────────────┤
  │ 3. Evaluar Postfix     │  → 13
  └────────────────────────┘

Los tres pasos usan stack. Los tres son O(n).
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
| **Stacks (este)**                | Stack.md             |
