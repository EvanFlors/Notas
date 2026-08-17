# Binary Tree Traversals — Recorridos, Generación y Procesamiento

> **Idea central:** Un árbol binario almacena datos, pero sin un **recorrido** no puedes acceder a ellos. La forma en que visitas los nodos determina el **orden del procesamiento** — y ese orden tiene consecuencias profundas en compiladores, evaluación de expresiones, serialización y reconstrucción de estructuras. Dominar los recorridos es dominar la **mecánica interna** de los árboles.

---

## Tabla de Contenidos

**Parte I — Fundamentos de Recorridos**
1. [¿Qué es un Recorrido?](#1-qué-es-un-recorrido)
2. [Los Cuatro Recorridos](#2-los-cuatro-recorridos)

**Parte II — Recorridos en Profundidad (DFS)**
3. [Preorder Traversal](#3-preorder-traversal)
4. [Inorder Traversal](#4-inorder-traversal)
5. [Postorder Traversal](#5-postorder-traversal)
6. [Comparación de Recorridos DFS](#6-comparación-de-recorridos-dfs)

**Parte III — Recorrido en Amplitud (BFS)**
7. [Level Order Traversal](#7-level-order-traversal)

**Parte IV — Implementaciones Iterativas**
8. [Preorder Iterativo](#8-preorder-iterativo)
9. [Inorder Iterativo](#9-inorder-iterativo)
10. [Postorder Iterativo](#10-postorder-iterativo)

**Parte V — Generación de Árboles**
11. [Crear un Árbol con Queue](#11-crear-un-árbol-con-queue)
12. [Reconstrucción desde Recorridos](#12-reconstrucción-desde-recorridos)

**Parte VI — Procesamiento sobre Árboles**
13. [Conteo de Nodos](#13-conteo-de-nodos)
14. [Funciones Derivadas](#14-funciones-derivadas)

**Parte VII — Síntesis**
15. [Resumen de Complejidad](#15-resumen-de-complejidad)
16. [Errores Comunes](#16-errores-comunes)
17. [Intuición de Ingeniería](#17-intuición-de-ingeniería)

---

# PARTE I — FUNDAMENTOS DE RECORRIDOS

---

# 1. ¿Qué es un Recorrido?

## 1.1 El problema

En una estructura **lineal** (array, lista enlazada), recorrer es trivial: de inicio a fin, o de fin a inicio.

En un árbol — una estructura **no lineal** — no hay un orden único natural. Desde cualquier nodo puedes ir hacia la izquierda, hacia la derecha, o hacia arriba. Se necesitan **reglas** que definan un orden de visita.

> **Recorrer (traverse)** = visitar **todos** los nodos de un árbol exactamente una vez, en un orden definido.

## 1.2 ¿Por qué importa?

| Necesidad | Recorrido involucrado |
|-----------|----------------------|
| Imprimir todos los elementos | Cualquier recorrido |
| Evaluar una expresión aritmética | Postorder |
| Serializar un árbol para transmisión | Preorder + marcadores NULL |
| Obtener elementos ordenados de un BST | Inorder |
| Procesar por niveles (BFS en grafos) | Level order |
| Destruir un árbol (liberar memoria) | Postorder |
| Copiar un árbol | Preorder |

---

# 2. Los Cuatro Recorridos

## 2.1 Definiciones

| Recorrido | Orden de visita | Mnemónico |
|-----------|----------------|-----------|
| **Preorder** | Nodo → Izquierdo → Derecho | **N**LR |
| **Inorder** | Izquierdo → Nodo → Derecho | L**N**R |
| **Postorder** | Izquierdo → Derecho → Nodo | LR**N** |
| **Level order** | Nivel por nivel, izquierda a derecha | BFS |

Los tres primeros son recorridos en **profundidad** (DFS — Depth-First Search).
El último es un recorrido en **amplitud** (BFS — Breadth-First Search).

## 2.2 Ejemplo base con árboles pequeños

```text
Árbol 1:        Árbol 2:        Árbol 3:
    A               A               A
   / \             /                 \
  B   C           B                   B

Pre:  A,B,C      Pre:  A,B          Pre:  A,B
In:   B,A,C      In:   B,A          In:   A,B
Post: B,C,A      Post: B,A          Post: B,A
Level: A,B,C     Level: A,B         Level: A,B
```

> **Observación:** En el Árbol 2, inorder y postorder son iguales (no hay hijo derecho). En el Árbol 3, preorder e inorder son iguales (no hay hijo izquierdo).

---

# PARTE II — RECORRIDOS EN PROFUNDIDAD (DFS)

---

# 3. Preorder Traversal

## 3.1 Definición recursiva

```text
preorder(node):
    si node es NULL → retornar
    1. Visitar (imprimir) node
    2. preorder(node.left)
    3. preorder(node.right)
```

> **Primero el nodo, luego sus hijos.** El nodo se procesa **antes** de descender.

## 3.2 Ejemplo completo

```text
Árbol:
           8
          / \
         3   5
        /   / \
       4   7   2
        \
         9

Procedimiento paso a paso:

1. Visitar 8 → preorder(izq) → preorder(der)
2.   Visitar 3 → preorder(izq) → preorder(der)
3.     Visitar 4 → preorder(izq=NULL) → preorder(der)
4.       Visitar 9 → preorder(NULL) → preorder(NULL)
5.   Volver a 8 → preorder(der)
6.     Visitar 5 → preorder(izq) → preorder(der)
7.       Visitar 7 → preorder(NULL) → preorder(NULL)
8.       Visitar 2 → preorder(NULL) → preorder(NULL)

Resultado: 8, 3, 4, 9, 5, 7, 2
```

## 3.3 Implementación recursiva en C

```c
void preorder(TreeNode *t) {
    if (t != NULL) {
        printf("%d ", t->data);       // 1. Visitar
        preorder(t->left);            // 2. Izquierdo
        preorder(t->right);           // 3. Derecho
    }
}
```

## 3.4 Método visual rápido

Para obtener preorder sin trazar recursión: imagina que recorres el contorno del árbol en sentido antihorario. Registra cada nodo cuando lo encuentras por su **lado izquierdo**.

```text
           8
          / \
         3   5
        /   / \
       4   7   2
        \
         9

Recorrido por contorno → lado izquierdo de cada nodo:
8 → 3 → 4 → 9 → 5 → 7 → 2
```

---

# 4. Inorder Traversal

## 4.1 Definición recursiva

```text
inorder(node):
    si node es NULL → retornar
    1. inorder(node.left)
    2. Visitar (imprimir) node
    3. inorder(node.right)
```

> **Primero el subárbol izquierdo, luego el nodo, luego el derecho.** El nodo se procesa **en medio**.

## 4.2 Ejemplo completo

```text
Árbol:
           8
          / \
         3   5
        /   / \
       4   7   2
        \
         9

Traza:
  inorder(8)
    inorder(3)
      inorder(4)
        inorder(NULL) → retorna
        Visitar 4
        inorder(9)
          inorder(NULL) → retorna
          Visitar 9
          inorder(NULL) → retorna
      Visitar 3
      inorder(NULL) → retorna
    Visitar 8
    inorder(5)
      inorder(7)
        inorder(NULL) → retorna
        Visitar 7
        inorder(NULL) → retorna
      Visitar 5
      inorder(2)
        inorder(NULL) → retorna
        Visitar 2
        inorder(NULL) → retorna

Resultado: 4, 9, 3, 8, 7, 5, 2
```

## 4.3 Implementación recursiva en C

```c
void inorder(TreeNode *t) {
    if (t != NULL) {
        inorder(t->left);             // 1. Izquierdo
        printf("%d ", t->data);       // 2. Visitar
        inorder(t->right);            // 3. Derecho
    }
}
```

## 4.4 Método visual rápido

Registra cada nodo cuando lo encuentras por su **parte inferior** (proyección vertical sobre una línea horizontal).

```text
           8
          / \
         3   5
        /   / \
       4   7   2
        \
         9

Proyección inferior:
4  9  3  8  7  5  2
```

> **Propiedad clave:** En un BST (Binary Search Tree), inorder produce los elementos en **orden ascendente**.

---

# 5. Postorder Traversal

## 5.1 Definición recursiva

```text
postorder(node):
    si node es NULL → retornar
    1. postorder(node.left)
    2. postorder(node.right)
    3. Visitar (imprimir) node
```

> **Primero los hijos, luego el nodo.** El nodo se procesa **después** de sus descendientes.

## 5.2 Ejemplo completo

```text
Árbol:
           8
          / \
         3   5
        /   / \
       4   7   2
        \
         9

Resultado: 9, 4, 3, 7, 2, 5, 8
```

## 5.3 Implementación recursiva en C

```c
void postorder(TreeNode *t) {
    if (t != NULL) {
        postorder(t->left);           // 1. Izquierdo
        postorder(t->right);          // 2. Derecho
        printf("%d ", t->data);       // 3. Visitar
    }
}
```

## 5.4 Método visual rápido

Registra cada nodo cuando lo encuentras por su **lado derecho** al recorrer el contorno.

> **Postorder es el recorrido más usado para procesamiento** (evaluar expresiones, liberar memoria, calcular propiedades bottom-up).

---

# 6. Comparación de Recorridos DFS

## 6.1 Diferencia en una línea

La **única diferencia** entre preorder, inorder y postorder es **cuándo se procesa el nodo** respecto a las llamadas recursivas:

```c
// Preorder:   PRINT → left → right
// Inorder:    left → PRINT → right
// Postorder:  left → right → PRINT
```

## 6.2 Análisis de llamadas

Para un árbol con **n nodos** y **n+1 punteros NULL**:

| Métrica | Valor |
|---------|-------|
| Total de llamadas recursivas | `2n + 1` |
| Llamadas a nodos reales | `n` |
| Llamadas a NULL (caso base) | `n + 1` |
| Tamaño máximo del stack | `h + 2` (h = altura) |
| Complejidad temporal | **O(n)** |
| Complejidad espacial (stack) | **O(h)** → entre O(log n) y O(n) |

## 6.3 Orden de las llamadas

El **orden en que se hacen las llamadas es idéntico** en los tres recorridos. Lo que cambia es **cuándo** se ejecuta el `printf` dentro de cada llamada:

```text
Llamada #:  1    2    3    4    5    6    7   ...  15

                  Todos los recorridos siguen el mismo
                  camino por el árbol. La diferencia es
                  solo CUÁNDO imprimen.
```

---

# PARTE III — RECORRIDO EN AMPLITUD (BFS)

---

# 7. Level Order Traversal

## 7.1 Definición

Visitar todos los nodos **nivel por nivel**, de izquierda a derecha.

```text
Árbol:
           8
          / \
         3   9
        /   / \
       7   6   4
      /       /
     5       2

Level order: 8, 3, 9, 7, 6, 4, 5, 2
              ↑    ↑↑    ↑↑↑    ↑↑
           nivel0  n1    n2     n3
```

## 7.2 ¿Por qué se necesita una Queue?

En DFS, la recursión (o un stack) gestiona el retroceso. En level order, necesitamos procesar nodos **en el orden en que los descubrimos** — eso es FIFO (First-In First-Out) → **Queue**.

## 7.3 Procedimiento

```text
1. Visitar root, insertar root en la queue
2. Mientras la queue no esté vacía:
   a. Sacar un nodo P de la queue
   b. Si P.left existe → visitar, insertar en queue
   c. Si P.right existe → visitar, insertar en queue
```

### Traza completa

```text
Árbol:
           8
          / \
         3   9
        /   / \
       7   6   4

Queue:  [8]
  Sacar 8 → hijos: 3, 9 → Queue: [3, 9]          Output: 8
  Sacar 3 → hijos: 7    → Queue: [9, 7]           Output: 8, 3
  Sacar 9 → hijos: 6, 4 → Queue: [7, 6, 4]       Output: 8, 3, 9
  Sacar 7 → sin hijos   → Queue: [6, 4]           Output: 8, 3, 9, 7
  Sacar 6 → sin hijos   → Queue: [4]              Output: 8, 3, 9, 7, 6
  Sacar 4 → sin hijos   → Queue: []               Output: 8, 3, 9, 7, 6, 4
  Queue vacía → FIN
```

## 7.4 Implementación en C

```c
void levelOrder(TreeNode *root) {
    if (!root) return;

    Queue *q = createQueue();
    TreeNode *p;

    printf("%d ", root->data);
    enqueue(q, root);

    while (!isEmpty(q)) {
        p = dequeue(q);

        if (p->left) {
            printf("%d ", p->left->data);
            enqueue(q, p->left);
        }
        if (p->right) {
            printf("%d ", p->right->data);
            enqueue(q, p->right);
        }
    }
}
```

## 7.5 Análisis

| Métrica | Valor |
|---------|-------|
| Complejidad temporal | **O(n)** |
| Complejidad espacial | **O(w)** donde w = ancho máximo del árbol |
| Ancho máximo (full tree) | `⌈n/2⌉` ≈ O(n) |
| Queue tipo | Almacena **punteros a nodo** (`TreeNode *`) |

---

# PARTE IV — IMPLEMENTACIONES ITERATIVAS

---

# 8. Preorder Iterativo

## 8.1 ¿Por qué iterativo?

Las funciones recursivas usan el **system stack** implícitamente. Para control explícito (evitar stack overflow, optimizar) podemos usar nuestro propio stack.

## 8.2 Idea

Cuando visitamos un nodo y vamos al hijo izquierdo, necesitamos **recordar** el nodo para luego ir al hijo derecho. Eso lo hace el stack.

```text
Procedimiento:
  Mientras T no sea NULL o el stack no esté vacío:
    Si T no es NULL:
      1. Imprimir T->data
      2. Push T al stack
      3. T = T->left
    Si T es NULL:
      1. Pop del stack → T
      2. T = T->right
```

## 8.3 Implementación en C

```c
void preorderIterative(TreeNode *t) {
    Stack *st = createStack();

    while (t != NULL || !isEmpty(st)) {
        if (t != NULL) {
            printf("%d ", t->data);    // Imprimir ANTES de ir a izquierda
            push(st, t);
            t = t->left;
        } else {
            t = pop(st);
            t = t->right;
        }
    }
}
```

---

# 9. Inorder Iterativo

## 9.1 Idea

Idéntico al preorder iterativo, pero el `printf` se mueve: en vez de imprimir **antes** de ir a la izquierda, se imprime **antes** de ir a la derecha (al hacer pop).

```text
Diferencia clave:
  Preorder:  printf → push → ir izquierda
  Inorder:   push → ir izquierda ... pop → printf → ir derecha
```

## 9.2 Implementación en C

```c
void inorderIterative(TreeNode *t) {
    Stack *st = createStack();

    while (t != NULL || !isEmpty(st)) {
        if (t != NULL) {
            push(st, t);
            t = t->left;
        } else {
            t = pop(st);
            printf("%d ", t->data);    // Imprimir DESPUÉS de terminar izquierda
            t = t->right;
        }
    }
}
```

---

# 10. Postorder Iterativo

## 10.1 ¿Por qué es más complejo?

En preorder e inorder, cada nodo se saca del stack una vez. En postorder, necesitamos visitar el nodo **después** de procesar **ambos** subárboles. El nodo debe permanecer en el stack hasta que su hijo derecho esté procesado.

## 10.2 Estrategia: doble push

Cada dirección se pushea **dos veces**:
1. Primera vez (positivo) → para ir al hijo derecho.
2. Segunda vez (negativo) → para imprimir.

Al hacer pop:
- Si el valor es **positivo** → push negativo, ir a hijo derecho.
- Si el valor es **negativo** → imprimir, hacer T = NULL.

## 10.3 Implementación en C

```c
void postorderIterative(TreeNode *t) {
    Stack *st = createStack();    // Stack de long int
    long int temp;

    while (t != NULL || !isEmpty(st)) {
        if (t != NULL) {
            push(st, (long int)t);
            t = t->left;
        } else {
            temp = pop(st);
            if (temp > 0) {
                // Primera vez: push negativo, ir a derecha
                push(st, -temp);
                t = ((TreeNode *)temp)->right;
            } else {
                // Segunda vez: imprimir
                printf("%d ", ((TreeNode *)(-temp))->data);
                t = NULL;
            }
        }
    }
}
```

## 10.4 Comparación de las tres versiones iterativas

| Aspecto | Preorder | Inorder | Postorder |
|---------|----------|---------|-----------|
| Printf ubicación | Antes de push | Después de pop | Después de segundo pop |
| Pushes por nodo | 1 | 1 | **2** |
| Complejidad extra | Ninguna | Ninguna | Dirección positiva/negativa |
| Complejidad temporal | O(n) | O(n) | O(n) |
| Complejidad espacial | O(h) | O(h) | O(h) |

---

# PARTE V — GENERACIÓN DE ÁRBOLES

---

# 11. Crear un Árbol con Queue

## 11.1 Procedimiento

Para generar un árbol binario en representación enlazada, se construye **nivel por nivel** usando una queue:

```text
1. Crear nodo root, insertar su dirección en la queue
2. Mientras la queue no esté vacía:
   a. Sacar dirección P de la queue
   b. Leer valor para hijo izquierdo:
      - Si es -1 → no hay hijo izquierdo
      - Si no → crear nodo, enlazar como P->left, insertar en queue
   c. Leer valor para hijo derecho:
      - Si es -1 → no hay hijo derecho
      - Si no → crear nodo, enlazar como P->right, insertar en queue
```

## 11.2 Ejemplo

```text
Entrada: 5, 8, 6, -1, 9, 3, -1, 4, 2, -1, -1, -1, -1, -1, -1

Árbol generado:
           5
          / \
         8   6
          \  /
          9  3
         / \
        4   2
```

## 11.3 Implementación en C

```c
TreeNode* createTree() {
    Queue *q = createQueue();
    TreeNode *root, *t, *p;
    int x;

    printf("Enter root value: ");
    scanf("%d", &x);
    root = createNode(x);
    enqueue(q, root);

    while (!isEmpty(q)) {
        p = dequeue(q);

        printf("Enter left child of %d (-1 for none): ", p->data);
        scanf("%d", &x);
        if (x != -1) {
            t = createNode(x);
            p->left = t;
            enqueue(q, t);
        }

        printf("Enter right child of %d (-1 for none): ", p->data);
        scanf("%d", &x);
        if (x != -1) {
            t = createNode(x);
            p->right = t;
            enqueue(q, t);
        }
    }

    return root;
}
```

---

# 12. Reconstrucción desde Recorridos

## 12.1 Requisito fundamental

> Para reconstruir un árbol binario **único**, se necesitan **exactamente dos recorridos**, y uno de ellos **debe ser inorder**.

| Par de recorridos | ¿Genera árbol único? |
|-------------------|---------------------|
| Preorder + Inorder | ✅ Sí |
| Postorder + Inorder | ✅ Sí |
| Preorder + Postorder | ❌ No (ambiguo) |

## 12.2 Algoritmo: Preorder + Inorder

```text
Dado:
  Preorder: 4, 7, 9, 6, 3, 2, 5, 8, 1
  Inorder:  7, 6, 9, 3, 4, 5, 8, 2, 1

Procedimiento:
1. Tomar el primer elemento de preorder → es la RAÍZ (4)
2. Buscar 4 en inorder → divide en:
   - Izquierda: [7, 6, 9, 3]
   - Derecha: [5, 8, 2, 1]
3. Siguiente elemento de preorder → 7 (buscar en partición izquierda)
4. Buscar 7 en [7, 6, 9, 3] → divide en:
   - Izquierda de 7: []
   - Derecha de 7: [6, 9, 3]
5. Repetir recursivamente...
```

### Resultado

```text
            4
           / \
          7   2
           \   \
            9   1
           / \
          6   3
             /
            5
             \
              8
```

## 12.3 Análisis

| Métrica | Valor |
|---------|-------|
| Escanear preorder | O(n) |
| Buscar cada elemento en inorder | O(n) por búsqueda |
| **Complejidad total** | **O(n²)** |

> Se puede reducir a O(n) usando un **hash map** para las posiciones en inorder.

---

# PARTE VI — PROCESAMIENTO SOBRE ÁRBOLES

---

# 13. Conteo de Nodos

## 13.1 Función recursiva (Postorder)

```c
int count(TreeNode *p) {
    if (p == NULL) return 0;

    int x = count(p->left);     // Contar izquierda
    int y = count(p->right);    // Contar derecha
    return x + y + 1;           // Izq + Der + este nodo
}
```

> **Observación:** Esta función trabaja en **postorder** — primero procesa los hijos, luego el nodo actual.

## 13.2 Traza

```text
Árbol:
       8
      / \
     3   5
    /   / \
   4   7   2

count(8):
  count(3):
    count(4):
      count(NULL) → 0
      count(NULL) → 0
      return 0 + 0 + 1 = 1
    count(NULL) → 0
    return 1 + 0 + 1 = 2
  count(5):
    count(7):
      return 0 + 0 + 1 = 1
    count(2):
      return 0 + 0 + 1 = 1
    return 1 + 1 + 1 = 3
  return 2 + 3 + 1 = 6 ✓
```

---

# 14. Funciones Derivadas

Modificando la línea `return x + y + 1` se obtienen funciones completamente distintas:

## 14.1 Tabla de variaciones

| Función | Modificación | Resultado |
|---------|-------------|-----------|
| **Contar todos los nodos** | `return x + y + 1` | Total de nodos |
| **Suma de todos los valores** | `return x + y + p->data` | Suma total |
| **Contar nodos grado 2** | `if (p->left && p->right) return x+y+1; else return x+y;` | Nodos con 2 hijos |
| **Contar hojas** | `if (!p->left && !p->right) return x+y+1; else return x+y;` | Nodos sin hijos |
| **Contar nodos grado 1** | `if ((p->left && !p->right) \|\| (!p->left && p->right)) return x+y+1; else return x+y;` | Nodos con 1 hijo |
| **Altura del árbol** | `if (x > y) return x+1; else return y+1;` | Altura máxima |

## 14.2 Ejemplo: Altura del árbol

```c
int height(TreeNode *p) {
    if (p == NULL) return -1;    // Árbol vacío: altura -1

    int x = height(p->left);
    int y = height(p->right);

    return (x > y) ? x + 1 : y + 1;
}
```

> **Patrón:** Casi todo procesamiento sobre árboles binarios usa la forma **postorder** — procesar hijos primero, combinar resultados en el padre.

---

# PARTE VII — SÍNTESIS

---

# 15. Resumen de Complejidad

## 15.1 Recorridos

| Recorrido | Tiempo | Espacio | Estructura auxiliar |
|-----------|--------|---------|-------------------|
| Preorder (recursivo) | O(n) | O(h) — system stack | Ninguna |
| Inorder (recursivo) | O(n) | O(h) — system stack | Ninguna |
| Postorder (recursivo) | O(n) | O(h) — system stack | Ninguna |
| Preorder (iterativo) | O(n) | O(h) | Stack propio |
| Inorder (iterativo) | O(n) | O(h) | Stack propio |
| Postorder (iterativo) | O(n) | O(h) | Stack propio (doble push) |
| Level order | O(n) | O(w) | Queue |

Donde: h = altura del árbol, w = ancho máximo, n = número de nodos.

## 15.2 Operaciones

| Operación | Tiempo | Patrón de recorrido |
|-----------|--------|-------------------|
| Contar nodos | O(n) | Postorder |
| Suma de valores | O(n) | Postorder |
| Altura del árbol | O(n) | Postorder |
| Contar hojas | O(n) | Postorder |
| Generar árbol (con queue) | O(n) | Level order |
| Reconstruir desde 2 recorridos | O(n²) | Preorder + búsqueda |

---

# 16. Errores Comunes

| Error | Corrección |
|-------|-----------|
| Olvidar el caso base `if (t == NULL)` | Sin él, la recursión nunca termina → stack overflow. |
| Confundir el orden de `printf` | Pre = antes de llamadas. In = entre llamadas. Post = después de llamadas. |
| Usar solo preorder + postorder para reconstruir | Es **ambiguo**. Se necesita inorder obligatoriamente. |
| Pensar que postorder iterativo es igual que los otros | Requiere doble push (positivo/negativo) por la visita tardía. |
| No liberar memoria del stack/queue auxiliar | Memory leak en implementaciones iterativas. |
| Confundir altura del stack con complejidad temporal | Stack = O(h). Tiempo = O(n). Son métricas independientes. |

---

# 17. Intuición de Ingeniería

## 17.1 ¿Cuándo usar cada recorrido?

| Situación | Recorrido | Razón |
|-----------|-----------|-------|
| Copiar/clonar un árbol | **Preorder** | Creas el padre antes que los hijos |
| Evaluar expresión aritmética | **Postorder** | Necesitas los operandos antes del operador |
| Liberar memoria (`free`) | **Postorder** | Liberas hijos antes que el padre |
| Obtener datos ordenados (BST) | **Inorder** | BST: izq < nodo < der |
| Serializar para transmisión | **Preorder** + marcadores NULL | Reconstrucción directa |
| Procesar por niveles | **Level order** | BFS natural |
| Calcular propiedades (altura, conteo) | **Postorder** | Bottom-up: combinar resultados de hijos |

## 17.2 La regla de oro

> **Postorder es el patrón dominante** para procesamiento en árboles binarios.
> La razón: la mayoría de las propiedades de un nodo dependen de las propiedades de sus hijos.
> Necesitas resolver los subproblemas (hijos) antes de resolver el problema (padre).
> Eso es exactamente lo que hace postorder.

## 17.3 Recursivo vs Iterativo

| Criterio | Recursivo | Iterativo |
|----------|-----------|-----------|
| Legibilidad | **Excelente** — refleja la definición | Más complejo |
| Control del stack | Implícito (system stack) | **Explícito** (stack propio) |
| Riesgo de overflow | Sí (árboles muy profundos) | **No** (stack en heap) |
| Performance | Overhead de llamadas | Ligeramente más rápido |
| Cuándo preferir | Árboles balanceados, código limpio | Árboles potencialmente sesgados |
