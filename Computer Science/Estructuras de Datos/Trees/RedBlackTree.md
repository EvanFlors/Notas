# Red-Black Tree — El Estándar Industrial de Árboles Balanceados

> **Idea central:** Un 2-3-4 Tree garantiza balance perfecto, pero su implementación multiway es
> incómoda. El **Red-Black Tree** resuelve esto: es un BST binario donde cada nodo lleva un bit
> de color (rojo o negro) que codifica la estructura de un 2-3-4 tree. Cinco propiedades simples
> garantizan que la altura nunca exceda **2·log₂(n+1)**, con inserciones que requieren máximo
> 2 rotaciones y eliminaciones que requieren máximo 3. Es la estructura detrás de `std::map`,
> `TreeMap`, el scheduler de Linux, y casi todo sistema que necesita un diccionario ordenado eficiente.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Definición y Propiedades](#1-definición-y-propiedades)
2. [Estructura del Nodo](#2-estructura-del-nodo)
3. [Nodos NIL y Sentinela](#3-nodos-nil-y-sentinela)
4. [Black-Height y Altura](#4-black-height-y-altura)

**Parte II — Correspondencia con 2-3-4 Trees**
5. [De 2-3-4 a Red-Black: La Transformación](#5-de-2-3-4-a-red-black-la-transformación)
6. [Ejemplos Paralelos (Lado a Lado)](#6-ejemplos-paralelos-lado-a-lado)
7. [Ventajas de la Representación Binaria](#7-ventajas-de-la-representación-binaria)

**Parte III — Inserción**
8. [Algoritmo de Inserción](#8-algoritmo-de-inserción)
9. [Los Casos de Fix-Up](#9-los-casos-de-fix-up)
10. [Inserción como Split de 2-3-4](#10-inserción-como-split-de-2-3-4)
11. [Construcción Paso a Paso](#11-construcción-paso-a-paso)

**Parte IV — Eliminación**
12. [Algoritmo de Eliminación](#12-algoritmo-de-eliminación)
13. [El Problema del Double-Black](#13-el-problema-del-double-black)
14. [Los Casos de Delete Fix-Up](#14-los-casos-de-delete-fix-up)
15. [Eliminación como Merge/Borrow de 2-3-4](#15-eliminación-como-mergeborrow-de-2-3-4)
16. [Ejemplos de Eliminación Paso a Paso](#16-ejemplos-de-eliminación-paso-a-paso)

**Parte V — Implementación Completa**
17. [Implementación en C](#17-implementación-en-c)

**Parte VI — Comparación y Análisis**
18. [Red-Black vs 2-3-4: Operaciones Comparadas](#18-red-black-vs-2-3-4-operaciones-comparadas)
19. [Red-Black vs AVL](#19-red-black-vs-avl)
20. [Complejidad de Operaciones](#20-complejidad-de-operaciones)

**Parte VII — Síntesis**
21. [Errores Comunes y Buenas Prácticas](#21-errores-comunes-y-buenas-prácticas)
22. [Intuición de Ingeniería](#22-intuición-de-ingeniería)
23. [Ejercicios Sugeridos](#23-ejercicios-sugeridos)

---

# PARTE I — FUNDAMENTOS

---

# 1. Definición y Propiedades

## 1.1 ¿Qué es un Red-Black Tree?

Un **Red-Black Tree** es un Binary Search Tree (BST) donde cada nodo tiene un atributo adicional de **color** (rojo o negro) y se cumplen cinco propiedades invariantes:

```text
┌─────────────────────────────────────────────────────────────────┐
│  P1. Cada nodo es ROJO o NEGRO.                                │
│  P2. La RAÍZ es NEGRA.                                         │
│  P3. Toda hoja (NIL) es NEGRA.                                 │
│  P4. Si un nodo es ROJO, ambos hijos son NEGROS.               │
│      (No hay dos rojos consecutivos padre→hijo)                 │
│  P5. Para cada nodo, todos los caminos simples hasta hojas NIL  │
│      contienen el MISMO número de nodos NEGROS (black-height).  │
└─────────────────────────────────────────────────────────────────┘
```

## 1.2 ¿Por qué estas 5 propiedades?

```text
P1 + P2: Establecen la estructura básica.

P3: Simplifica el código (cada puntero NULL apunta a un nodo "centinela" negro).

P4: Limita la altura.
    Si no puede haber dos rojos consecutivos, entre cada par de negros
    hay MÁXIMO un rojo → la altura es máximo 2× la cantidad de negros.

P5: Garantiza balance.
    Equivale a decir que en el 2-3-4 tree subyacente, todas las hojas
    están al mismo nivel. Es LA propiedad de balance.

Juntas:
    P4 + P5 → h ≤ 2·log₂(n+1) → todas las operaciones O(log n).
```

## 1.3 Ejemplo de un Red-Black Tree válido

```text
Leyenda: (x)B = nodo negro    (x)R = nodo rojo    NIL = hoja negra

                     (13)B
                    /      \
               (8)R         (17)R
              /    \        /     \
          (1)B   (11)B  (15)B   (25)B
            \       \     /       /
          (6)R    NIL  (14)R  (22)R
          /  \         /  \    /  \
        NIL  NIL     NIL NIL NIL  NIL

Verificación:
  P1: Todos tienen color  ✓
  P2: Raíz (13) es negra  ✓
  P3: Todas las hojas NIL son negras  ✓
  P4: Rojo (8) → hijos (1)B, (11)B  ✓
      Rojo (17) → hijos (15)B, (25)B  ✓
      Rojo (6) → hijos NIL(B), NIL(B)  ✓
      Rojo (14) → hijos NIL(B), NIL(B)  ✓
      Rojo (22) → hijos NIL(B), NIL(B)  ✓
  P5: Todos los caminos tienen black-height = 2:
      13→8→1→NIL:      negros en camino (excl. raíz según convención): {1} → bh=2 contando 13,1
      13→8→1→6→NIL:    negros: {13, 1} = 2  ✓
      13→8→11→NIL:     negros: {13, 11} = 2  ✓
      13→17→15→NIL:    negros: {13, 15} = 2  ✓
      13→17→15→14→NIL: negros: {13, 15} = 2  ✓
      13→17→25→NIL:    negros: {13, 25} = 2  ✓
      13→17→25→22→NIL: negros: {13, 25} = 2  ✓
```

---

# 2. Estructura del Nodo

## 2.1 Definición en C

```c
typedef enum { RED, BLACK } Color;

typedef struct RBNode {
    int data;
    Color color;
    struct RBNode *left;
    struct RBNode *right;
    struct RBNode *parent;    // necesario para fix-up
} RBNode;
```

## 2.2 ¿Por qué se necesita el puntero al padre?

```text
En AVL, las rotaciones se manejan con recursión (el padre está en el stack).
En Red-Black, los fix-ups necesitan navegar hacia arriba (al tío, al abuelo).
El puntero parent permite:
  1. Acceder al tío (hermano del padre) en O(1)
  2. Acceder al abuelo en O(1)
  3. Implementar fix-ups iterativamente (sin recursión)
```

## 2.3 Overhead de memoria

```text
Por nodo:
  BST:       data + left + right                    = 12 bytes (32-bit)
  AVL:       data + left + right + height            = 16 bytes
  Red-Black: data + left + right + parent + color    = 20 bytes

El color puede almacenarse en 1 bit.
En la práctica, se usa el bit menos significativo del puntero parent
(ya que los punteros están alineados a 4/8 bytes):

  Red-Black (optimizado): data + left + right + parent_with_color = 16 bytes
```

---

# 3. Nodos NIL y Sentinela

## 3.1 El concepto de NIL

```text
En un Red-Black Tree, NULL no se usa directamente.
En su lugar, todos los punteros "vacíos" apuntan a un nodo centinela:

  T.nil = nodo especial con color = BLACK

Ventaja: No hay que chequear NULL antes de acceder al color.
         Simplifica enormemente el código.

         if (x->left == NULL || x->left->color == BLACK)  // sin centinela
         if (x->left->color == BLACK)                     // con centinela
```

## 3.2 Implementación del centinela

```c
// Nodo centinela global (compartido por todos los NIL)
RBNode SENTINEL = {0, BLACK, NULL, NULL, NULL};
RBNode *NIL = &SENTINEL;

// Inicializar un árbol vacío:
RBNode *root = NIL;  // la raíz apunta al centinela
```

## 3.3 Visualización

```text
Con centinela:                    Sin centinela (conceptual):

     (10)B                              (10)B
    /      \                            /      \
  (5)R    (15)R                       (5)R    (15)R
  / \      / \                        / \      / \
NIL NIL  NIL NIL                    ∅  ∅    ∅   ∅

NIL es un NODO real (color BLACK)    ∅ es NULL (sin nodo)

→ Con centinela, nunca accedemos a NULL. Más seguro.
```

---

# 4. Black-Height y Altura

## 4.1 Definición de black-height

```text
bh(x) = número de nodos NEGROS en cualquier camino simple
         desde x (sin incluir x) hasta una hoja NIL.

Por P5, este valor es el mismo para TODOS los caminos → está bien definido.
```

## 4.2 Relación entre black-height y altura

```text
Sea h = altura del Red-Black Tree, bh = bh(raíz).

Cota inferior de bh:
  Por P4 (no dos rojos seguidos), en un camino de longitud h:
  → Al menos la mitad de los nodos son negros
  → bh ≥ h/2
  → h ≤ 2·bh

Cota inferior de n (nodos internos):
  Un subárbol con black-height k tiene al menos 2^k - 1 nodos internos.
  (Prueba por inducción sobre bh)
  → n ≥ 2^bh - 1
  → bh ≤ log₂(n+1)

Combinando:
  h ≤ 2·bh ≤ 2·log₂(n+1)
```

## 4.3 Ejemplo numérico

```text
n = 15 nodos:
  BST peor:    h = 14
  BST mejor:   h = 3 (árbol perfecto)
  AVL:         h ≤ 1.44·log₂(16) = 5.76 → h ≤ 5
  Red-Black:   h ≤ 2·log₂(16) = 8 → h ≤ 8
  2-3-4:       h ≤ log₂(16) = 4

n = 1,000,000:
  Red-Black:   h ≤ 2·log₂(1000001) ≈ 40
  AVL:         h ≤ 1.44·log₂(1000001) ≈ 29
  → En la práctica, Red-Black tiene ~10 niveles más que AVL
  → Pero las operaciones de mantenimiento son más rápidas
```

---

# PARTE II — CORRESPONDENCIA CON 2-3-4 TREES

---

# 5. De 2-3-4 a Red-Black: La Transformación

## 5.1 Regla de transformación

Cada nodo de un 2-3-4 tree se traduce a una mini-configuración Red-Black:

### 2-nodo → Un nodo negro

```text
2-3-4:          [b]                Red-Black:      (b)B
               /   \                              /    \
              A     C                            A      C
```

### 3-nodo → Un negro con un hijo rojo

```text
2-3-4:        [a | b]             Red-Black (opción 1):    (b)B
             /   |   \                                    /    \
            A    B    C                                (a)R     C
                                                      /  \
                                                     A    B

                                  Red-Black (opción 2):    (a)B
                                                          /    \
                                                         A    (b)R
                                                              /  \
                                                             B    C
```

> En el RB clásico, ambas representaciones del 3-nodo son válidas.
> En LLRB (Left-Leaning Red-Black), solo la opción 1 es válida.

### 4-nodo → Un negro con dos hijos rojos

```text
2-3-4:      [a | b | c]           Red-Black:        (b)B
           /  |    |   \                            /    \
          A   B    C    D                        (a)R    (c)R
                                                /  \    /  \
                                               A    B  C    D
```

## 5.2 La regla inversa (Red-Black → 2-3-4)

```text
Para "ver" el 2-3-4 tree dentro de un Red-Black tree:
  1. Toma cada nodo negro
  2. "Absorbe" sus hijos rojos → forma un super-nodo
  3. Cada super-nodo es un 2-nodo, 3-nodo o 4-nodo

Ejemplo:
  Negro sin hijos rojos → 2-nodo
  Negro con 1 hijo rojo → 3-nodo
  Negro con 2 hijos rojos → 4-nodo
```

## 5.3 ¿Por qué la correspondencia es correcta?

```text
Propiedad RB                →  Propiedad 2-3-4
─────────────────────────────────────────────────
P2 (raíz negra)             →  La raíz es un nodo propio
P4 (no 2 rojos seguidos)    →  Máximo 2 rojos por negro = máximo 3 claves = 4-nodo
P5 (black-height constante) →  Todas las hojas al mismo nivel

Si hay 2 rojos consecutivos → habría un "5-nodo" → no existe en 2-3-4 → violación.
```

---

# 6. Ejemplos Paralelos (Lado a Lado)

## 6.1 Ejemplo 1: Insertar 10, 20, 30, 40, 50, 60, 70

### Estado final en 2-3-4 tree

```text
       [20 | 40]
      /    |    \
   [10]  [30]   [50 | 60 | 70]
```

### Estado final equivalente en Red-Black tree

```text
Traducción nodo por nodo:
  [20|40] → 3-nodo → (40)B con (20)R izquierdo
                      o (20)B con (40)R derecho

  [10] → 2-nodo → (10)B
  [30] → 2-nodo → (30)B
  [50|60|70] → 4-nodo → (60)B con (50)R y (70)R

Opción con 40 como raíz negra, 20 como rojo izquierdo:

              (40)B
             /      \
          (20)R    (60)B
          /    \   /    \
       (10)B (30)B (50)R (70)R

Verificación de propiedades:
  P1: Todos coloreados  ✓
  P2: Raíz (40) negra  ✓
  P4: Rojo (20) → hijos (10)B, (30)B  ✓
      Rojo (50) → hijos NIL(B), NIL(B)  ✓
      Rojo (70) → hijos NIL(B), NIL(B)  ✓
  P5: 40→20→10→NIL: negros = {40, 10} = 2  ✓
      40→20→30→NIL: negros = {40, 30} = 2  ✓
      40→60→50→NIL: negros = {40, 60} = 2  ✓
      40→60→70→NIL: negros = {40, 60} = 2  ✓
```

## 6.2 Ejemplo 2: Árbol más grande

```text
2-3-4 Tree:
                     [25]
                    /    \
            [10 | 20]    [30 | 40 | 50]
           /   |    \    /  |    |    \
         [5]  [15]  [22] [28] [35] [45] [55|60]

Red-Black equivalente (una posible representación):

                    (25)B
                   /      \
              (10)B        (40)B
             /     \      /      \
           (5)B  (20)B (30)R    (50)R
                 /       \      /    \
              (15)R    (28)B (45)B  (55)B
                         \               \
                        (35)R           (60)R

  Correspondencia:
    [25] → 2-nodo → (25)B
    [10|20] → 3-nodo → (10)B con (20)B...

  NOTA: hay MÚLTIPLES representaciones RB válidas para un mismo 2-3-4 tree
  (según cómo se orienten los 3-nodos). Lo importante es que las 5 propiedades
  se cumplan.
```

---

# 7. Ventajas de la Representación Binaria

## 7.1 Comparación directa

| Aspecto             | 2-3-4 Tree (directo)           | Red-Black Tree               |
| ------------------- | ------------------------------ | ---------------------------- |
| Estructura del nodo | Variable (2, 3 o 4 hijos)     | Uniforme (2 hijos)           |
| Memoria por nodo    | Reservar para máximo (4 hijos) | Fija (2 punteros + color)    |
| Comparaciones/nodo  | Hasta 3                        | Exactamente 1                |
| Código              | Muchos condicionales           | Uniforme (BST + colores)     |
| Cache locality      | Mala (nodos grandes)           | Buena (nodos pequeños)       |
| Campos extra        | numKeys, keys[3], child[4]     | color (1 bit)                |

## 7.2 El costo de la traducción

```text
El único costo de usar Red-Black en vez de 2-3-4:
  → La altura aumenta (máximo 2× más que 2-3-4)
  → Pero las operaciones por nivel son más simples y rápidas
  → En la práctica, Red-Black es MÁS rápido que 2-3-4 directo

Es como la diferencia entre:
  → Código en lenguaje de alto nivel (2-3-4): menos líneas, más complejo por línea
  → Código compilado a binario (Red-Black): más instrucciones, cada una más simple
  → El compilado es más rápido en hardware real.
```

---

# PARTE III — INSERCIÓN

---

# 8. Algoritmo de Inserción

## 8.1 Visión general

La inserción en un Red-Black Tree tiene dos fases:

```text
Fase 1: Inserción estándar BST
  → Insertar como en cualquier BST
  → Colorear el nuevo nodo como ROJO

Fase 2: Fix-Up (reparar violaciones)
  → El nuevo nodo rojo puede violar P4 (padre rojo → dos rojos seguidos)
  → Aplicar rotaciones y recoloreos para restaurar las propiedades
```

## 8.2 ¿Por qué insertar como ROJO?

```text
Si insertamos como NEGRO:
  → P5 se viola SIEMPRE (un camino tiene un negro más que los demás)
  → Esto es muy difícil de arreglar

Si insertamos como ROJO:
  → P5 NUNCA se viola (el nuevo nodo no cambia la black-height)
  → P4 PUEDE violarse (si el padre también es rojo)
  → Pero P4 es más fácil de arreglar (recoloreo + máximo 2 rotaciones)

→ Insertar como rojo es la estrategia óptima.
```

## 8.3 Pseudocódigo de inserción

```text
RB_Insert(T, key):
  // Fase 1: Inserción BST estándar
  z = crear nuevo nodo con key, color = RED
  y = NIL
  x = T.root

  while x ≠ NIL:
    y = x
    if key < x.data:
      x = x.left
    else:
      x = x.right

  z.parent = y
  if y == NIL:
    T.root = z          // árbol estaba vacío
  elif key < y.data:
    y.left = z
  else:
    y.right = z

  z.left = NIL
  z.right = NIL
  z.color = RED

  // Fase 2: Reparar violaciones
  RB_Insert_Fixup(T, z)
```

---

# 9. Los Casos de Fix-Up

## 9.1 ¿Cuándo se necesita fix-up?

```text
Después de insertar z (rojo):
  • Si z es la raíz → colorear negro. DONE.
  • Si z.parent es negro → no hay violación. DONE.
  • Si z.parent es rojo → VIOLACIÓN de P4 → fix-up necesario.
```

## 9.2 El parentesco clave

```text
Para el fix-up necesitamos identificar:
  z     = nodo recién insertado (rojo)
  p     = z.parent (rojo → por eso hay violación)
  g     = z.parent.parent (abuelo, debe ser negro por P4)
  uncle = hermano de p (el otro hijo de g)

         (g)B
        /    \
     (p)R   (uncle)?
      |
    (z)R  ← violación: rojo-rojo
```

## 9.3 Los tres casos (padre es hijo izquierdo del abuelo)

### Caso 1: Tío ROJO → Recoloreo

```text
Situación:
         (g)B                         (g)R  ← ahora rojo
        /    \                       /    \
     (p)R   (u)R     ───────→    (p)B   (u)B  ← ambos negros
      |                           |
    (z)R                        (z)R

Acción:
  1. p.color = BLACK
  2. uncle.color = BLACK
  3. g.color = RED
  4. z = g  (propagar el fix-up hacia arriba, g ahora es "el nodo rojo problemático")

¿Por qué funciona?
  → El recoloreo no cambia la black-height de ningún camino
  → Pero puede crear una nueva violación en g (si g.parent es rojo)
  → Por eso se propaga hacia arriba

Equivalente en 2-3-4:
  → Es un COLOR FLIP, que corresponde a un SPLIT de 4-nodo.
  → p(R), g(B), u(R) = 4-nodo [p, g, u]
  → Split: g sube, p y u se hacen negros (nodos independientes)
```

### Caso 2: Tío NEGRO, z es hijo "interno" → Rotación para convertir en Caso 3

```text
Situación (z es hijo derecho de p, y p es hijo izquierdo de g):

         (g)B                       (g)B
        /    \                     /    \
     (p)R   (u)B   ─LeftRot(p)→  (z)R  (u)B
       \                         /
      (z)R                     (p)R

Acción:
  1. z = p  (ahora el "nuevo z" es el antiguo padre)
  2. leftRotate(T, z)
  → Esto convierte el caso en Caso 3

Intuición:
  z está en la "esquina interna" → rotarlo lo pone en la "esquina externa"
  → Ahora se puede resolver con una rotación simple (Caso 3)
```

### Caso 3: Tío NEGRO, z es hijo "externo" → Rotación + Recoloreo

```text
Situación (z es hijo izquierdo de p, y p es hijo izquierdo de g):

         (g)B                         (p)B
        /    \                       /    \
     (p)R   (u)B   ─RightRot(g)→ (z)R   (g)R
     /                                     \
   (z)R                                   (u)B

Acción:
  1. p.color = BLACK
  2. g.color = RED
  3. rightRotate(T, g)
  → FIN. No hay más violaciones.

Equivalente en 2-3-4:
  → Es una ROTACIÓN necesaria después de un split que dejó
    el árbol localmente desbalanceado.
```

## 9.4 Los casos simétricos (padre es hijo derecho del abuelo)

```text
Si p es hijo DERECHO de g, los tres casos son simétricos:
  Caso 1: Tío rojo → recoloreo (idéntico)
  Caso 2: z es hijo izquierdo (interno) → rightRotate(p) → Caso 3
  Caso 3: z es hijo derecho (externo) → leftRotate(g) + recoloreo
```

## 9.5 Pseudocódigo completo del fix-up

```text
RB_Insert_Fixup(T, z):
  while z.parent.color == RED:
    if z.parent == z.parent.parent.left:
      uncle = z.parent.parent.right

      if uncle.color == RED:                    // Caso 1
        z.parent.color = BLACK
        uncle.color = BLACK
        z.parent.parent.color = RED
        z = z.parent.parent                    // propagar arriba

      else:
        if z == z.parent.right:                // Caso 2
          z = z.parent
          leftRotate(T, z)

        z.parent.color = BLACK                 // Caso 3
        z.parent.parent.color = RED
        rightRotate(T, z.parent.parent)

    else:                                      // simétrico (parent es hijo derecho)
      uncle = z.parent.parent.left

      if uncle.color == RED:                   // Caso 1
        z.parent.color = BLACK
        uncle.color = BLACK
        z.parent.parent.color = RED
        z = z.parent.parent

      else:
        if z == z.parent.left:                 // Caso 2
          z = z.parent
          rightRotate(T, z)

        z.parent.color = BLACK                 // Caso 3
        z.parent.parent.color = RED
        leftRotate(T, z.parent.parent)

  T.root.color = BLACK                        // P2: raíz siempre negra
```

## 9.6 Resumen de los casos

```text
┌─────────┬──────────────┬─────────────────────┬──────────────────┐
│  Caso   │  Tío         │  Posición de z      │  Acción          │
├─────────┼──────────────┼─────────────────────┼──────────────────┤
│  1      │  ROJO        │  cualquiera         │  Recoloreo       │
│         │              │                     │  + propagar      │
│  2      │  NEGRO       │  interno (esquina)  │  Rotación → C3   │
│  3      │  NEGRO       │  externo (línea)    │  Rotación + color│
│         │              │                     │  → FIN           │
└─────────┴──────────────┴─────────────────────┴──────────────────┘

Peor caso: Caso 1 se repite O(log n) veces + Caso 2 + Caso 3
           = O(log n) recoloreos + máximo 2 rotaciones
```

---

# 10. Inserción como Split de 2-3-4

## 10.1 La correspondencia exacta

```text
Cada caso del fix-up de inserción tiene un equivalente en 2-3-4:

Caso 1 (Recoloreo / Color Flip):
  → SPLIT de un 4-nodo en el 2-3-4 tree
  → El 4-nodo [p, g, u] se divide: g sube al padre
  → p y u se convierten en 2-nodos independientes
  → Puede propagarse si el padre también era un 4-nodo

Caso 2 + 3 (Rotación):
  → REESTRUCTURACIÓN después de un split
  → Cuando la mediana sube al padre, puede quedar mal orientada
  → La rotación corrige la orientación
```

## 10.2 Ejemplo visual

```text
Insertar 15 en este RB tree:

     (10)B           Equivalente 2-3-4:     [10]
    /      \                               /    \
  (5)R    (20)R                         [5|10|20]  ← 4-nodo!
         /    \                          (representado con 5 y 20 rojos)
       ...    ...

En 2-3-4: El nodo raíz [5|10|20] es un 4-nodo.
  Al insertar 15, primero split el 4-nodo:
  → 10 queda como raíz, 5 y 20 son hijos independientes
  → Luego 15 va al subárbol de 20

En Red-Black: Esto es Caso 1 (Color Flip):
  → (5) y (20) se hacen negros
  → (10) se hace rojo (pero es raíz → se fuerza a negro por P2)
  → Luego se inserta 15 normalmente (hijo izquierdo de 20)

     (10)B                    (10)B
    /      \     flip →      /      \
  (5)R    (20)R            (5)B    (20)B
                                    /
                                 (15)R
```

## 10.3 Top-down insertion y color flips

```text
La inserción top-down de 2-3-4 (split preventivo al bajar)
se traduce directamente a:

  "Al bajar buscando la posición, si encuentras un nodo negro
   con dos hijos rojos, haz un color flip (Caso 1)."

Esto es exactamente lo que hace el Caso 1 del fix-up cuando se propaga
hacia arriba. La versión top-down lo hace al bajar, evitando la propagación.

Top-down (bajar):  preventivo, sin propagación, 1 pase
Bottom-up (subir): reactivo, con propagación, 2 pases conceptuales
→ El resultado es el mismo árbol.
```

---

# 11. Construcción Paso a Paso

## 11.1 Insertar: 10, 20, 30, 15, 25, 5, 1

### Insert 10

```text
  (10)B     ← nuevo nodo, se colorea rojo, pero es raíz → forzar negro (P2)
```

### Insert 20

```text
  (10)B
     \
    (20)R   ← nuevo nodo rojo. Padre (10) negro → no violación. OK.
```

### Insert 30

```text
  (10)B
     \
    (20)R
       \
      (30)R   ← VIOLACIÓN: (20)R → (30)R, dos rojos consecutivos

  z = 30, p = 20, g = 10, uncle = NIL(B) → tío NEGRO

  z es hijo derecho de p, p es hijo derecho de g → Caso 3 (externo)

  Acción: p(20) se hace negro, g(10) se hace rojo, leftRotate(g=10)

  ANTES:          DESPUÉS:
    (10)B            (20)B
       \            /    \
      (20)R      (10)R  (30)R
         \
        (30)R

  Verificación: P2(20=B) ✓, P4(10R→hijos NIL(B)) ✓, P5(bh=1) ✓
```

### Insert 15

```text
  Estado actual:
       (20)B
      /    \
   (10)R  (30)R

  Insertar 15: 15 < 20 → izq, 15 > 10 → der de (10)

       (20)B
      /    \
   (10)R  (30)R
      \
     (15)R   ← VIOLACIÓN? Padre (10) es rojo.

  z = 15, p = 10, g = 20, uncle = 30(R) → tío ROJO → Caso 1

  Acción: Recoloreo
    p(10) → BLACK, uncle(30) → BLACK, g(20) → RED
    z = g = 20
    Pero 20 es raíz → forzar BLACK (P2)

       (20)B
      /    \
   (10)B  (30)B
      \
     (15)R

  Verificación: P2 ✓, P4 ✓, P5(bh=2 en todos los caminos...
    20→10→NIL: negros {20,10} = 2 ✓
    20→10→15→NIL: negros {20,10} = 2 ✓
    20→30→NIL: negros {20,30} = 2 ✓)
```

### Insert 25

```text
  25 > 20 → der, 25 < 30 → izq de (30)

       (20)B
      /    \
   (10)B  (30)B
      \      /
     (15)R (25)R   ← Padre (30) negro → no violación. OK.
```

### Insert 5

```text
  5 < 20 → izq, 5 < 10 → izq de (10)

       (20)B
      /    \
   (10)B  (30)B
   /   \     /
 (5)R (15)R (25)R    ← Padre (10) negro → no violación. OK.
```

### Insert 1

```text
  1 < 20 → izq, 1 < 10 → izq, 1 < 5 → izq de (5)

       (20)B
      /    \
   (10)B  (30)B
   /   \     /
 (5)R (15)R (25)R
  /
(1)R   ← VIOLACIÓN: (5)R → (1)R, dos rojos consecutivos

  z = 1, p = 5, g = 10, uncle = 15(R) → tío ROJO → Caso 1

  Acción: Recoloreo
    p(5) → BLACK, uncle(15) → BLACK, g(10) → RED
    z = g = 10

       (20)B
      /    \
   (10)R  (30)B
   /   \     /
 (5)B (15)B (25)R
  /
(1)R

  ¿Sigue habiendo violación? z = 10(R), z.parent = 20(B) → NO. DONE.

  Verificación:
    P2: (20)B ✓
    P4: (10)R → (5)B, (15)B ✓
        (1)R → NIL(B), NIL(B) ✓
        (25)R → NIL(B), NIL(B) ✓
    P5: Todos los caminos tienen bh = 2:
        20→10→5→1→NIL: negros {20,5} = 2 ✓
        20→10→5→NIL: negros {20,5} = 2 ✓
        20→10→15→NIL: negros {20,15} = 2 ✓
        20→30→25→NIL: negros {20,30} = 2 ✓
        20→30→NIL: negros {20,30} = 2 ✓
```

### Estado final

```text
Red-Black Tree:                    2-3-4 equivalente:

       (20)B                              [20]
      /    \                             /    \
   (10)R  (30)B                    [5|10|15]  [25|30]
   /   \     /                    / |  |  \   /   \
 (5)B (15)B (25)R              [1] [·] [·] [·] [·] [·]
  /
(1)R

  [5|10|15] = 4-nodo (10 negro con 5R y 15R absorbidos)
  [25|30] = 3-nodo (30 negro con 25R)
```

---

# PARTE IV — ELIMINACIÓN

---

# 12. Algoritmo de Eliminación

## 12.1 Visión general

La eliminación en Red-Black Trees es la operación más compleja:

```text
Fase 1: Eliminación BST estándar
  → Encontrar el nodo a eliminar
  → Si tiene dos hijos: reemplazar con sucesor inorder
  → Reducir a eliminar un nodo con 0 o 1 hijo

Fase 2: Ajustar colores
  → Si el nodo eliminado era ROJO: no pasa nada (P5 no se afecta)
  → Si era NEGRO: la black-height de algún camino se redujo
  → Esto crea un "double-black" que hay que resolver

Fase 3: Fix-Up
  → Rotaciones y recoloreos para restaurar las propiedades
```

## 12.2 ¿Cuándo NO se necesita fix-up?

```text
Si el nodo eliminado (o su reemplazo) es ROJO:
  → Simplemente quitarlo o recolorearlo a negro
  → La black-height no cambia
  → DONE

Esto ocurre cuando:
  a) El nodo a eliminar es rojo y es hoja → quitarlo
  b) El nodo a eliminar es negro con un hijo rojo
     → reemplazarlo con el hijo, coloreándolo negro
```

## 12.3 ¿Cuándo SÍ se necesita fix-up?

```text
Si el nodo eliminado era NEGRO y su reemplazo es NEGRO (o NIL):
  → El camino que pasaba por ese nodo perdió un negro
  → El nodo reemplazo hereda una "negrura extra" → "DOUBLE-BLACK"
  → Hay que redistribuir esa negrura extra
```

## 12.4 Pseudocódigo de eliminación

```text
RB_Delete(T, z):
  y = z                              // nodo a eliminar físicamente
  y_original_color = y.color

  if z.left == NIL:
    x = z.right                      // x es el reemplazo
    RB_Transplant(T, z, z.right)

  elif z.right == NIL:
    x = z.left
    RB_Transplant(T, z, z.left)

  else:                              // dos hijos
    y = minimum(z.right)             // sucesor inorder
    y_original_color = y.color
    x = y.right

    if y.parent == z:
      x.parent = y                   // en caso de que x sea NIL
    else:
      RB_Transplant(T, y, y.right)
      y.right = z.right
      y.right.parent = y

    RB_Transplant(T, z, y)
    y.left = z.left
    y.left.parent = y
    y.color = z.color

  if y_original_color == BLACK:
    RB_Delete_Fixup(T, x)           // x tiene el "double-black"
```

```text
RB_Transplant(T, u, v):
  // Reemplaza el subárbol de u con el subárbol de v
  if u.parent == NIL:
    T.root = v
  elif u == u.parent.left:
    u.parent.left = v
  else:
    u.parent.right = v
  v.parent = u.parent
```

---

# 13. El Problema del Double-Black

## 13.1 ¿Qué es el double-black?

```text
Cuando eliminamos un nodo negro y su reemplazo es negro (o NIL),
el reemplazo hereda una "negrura extra":

  Negro + extra negro = "Double-Black"

Double-black NO es un color real. Es un concepto para rastrear
que un camino tiene un negro de menos.

El objetivo del fix-up es ELIMINAR el double-black:
  1. Transferir la negrura extra a un nodo rojo (que se vuelve negro) → DONE
  2. Redistribuir la negrura mediante rotaciones
  3. Propagar el double-black hacia arriba (si no se puede resolver)
```

## 13.2 Analogía con 2-3-4

```text
En 2-3-4 trees:
  Eliminar de un 2-nodo (que solo tiene 1 clave) → el nodo queda vacío.
  → Esto es el equivalente del "double-black" en Red-Black.
  → Se resuelve con: redistribuir (borrow) o fusionar (merge) con hermano.

En Red-Black:
  Double-black → un camino tiene un negro de menos.
  → Caso hermano rojo: reestructurar para reducir a caso hermano negro.
  → Caso hermano negro con hijos negros: merge → propagar.
  → Caso hermano negro con hijo rojo: redistribuir → DONE.
```

## 13.3 Los participantes del fix-up

```text
x = nodo con double-black (el reemplazo)
w = hermano de x (sibling)
p = padre de x

     (p)?
    /    \
  (x)DB  (w)?
         / \
       (a)? (b)?

DB = double-black
? = color desconocido (depende del caso)
```

---

# 14. Los Casos de Delete Fix-Up

## 14.1 Los cuatro casos (x es hijo izquierdo)

### Caso 1: Hermano w es ROJO

```text
Situación:
         (p)B
        /    \
     (x)DB  (w)R
             / \
           (a)B (b)B

Acción:
  1. w.color = BLACK
  2. p.color = RED
  3. leftRotate(T, p)
  4. w = p.right  (nuevo hermano, que ahora es (a), que es NEGRO)

Después:
         (w)B
        /    \
      (p)R   (b)B
     /    \
   (x)DB  (a)B ← nuevo w

→ Ahora el hermano es NEGRO → reducido a Caso 2, 3 o 4.

Equivalente 2-3-4:
  → Reestructurar para exponer el verdadero hermano.
  → El hermano rojo significa que en el 2-3-4, el hermano y el padre
    forman un 3-nodo o 4-nodo. La rotación los separa.
```

### Caso 2: Hermano w es NEGRO, ambos hijos de w son NEGROS

```text
Situación:
         (p)?           ? = puede ser rojo o negro
        /    \
     (x)DB  (w)B
             / \
           (a)B (b)B

Acción:
  1. w.color = RED
  2. x = p  (mover el double-black al padre)

Si p era ROJO → colorearlo NEGRO → double-black eliminado → DONE.
Si p era NEGRO → p se vuelve double-black → propagar hacia arriba.

Después (si p era rojo):
         (p)B           ← era rojo, absorbe la negrura extra
        /    \
     (x)B   (w)R       ← w se hizo rojo para compensar
             / \
           (a)B (b)B

Equivalente 2-3-4:
  → MERGE: el hermano y la clave del padre se fusionan.
  → El padre pierde una clave → puede quedar vacío (propagar).
  → En RB: mover negrura al padre = el padre absorbió la fusión.
```

### Caso 3: Hermano w NEGRO, hijo izquierdo de w ROJO, hijo derecho NEGRO

```text
Situación:
         (p)?
        /    \
     (x)DB  (w)B
             / \
           (a)R (b)B

Acción:
  1. a.color = BLACK
  2. w.color = RED
  3. rightRotate(T, w)
  4. w = p.right  (nuevo hermano)

Después:
         (p)?
        /    \
     (x)DB  (a)B ← nuevo w
               \
              (w)R
                \
               (b)B

→ Ahora el hermano tiene hijo derecho ROJO → Caso 4.

Equivalente 2-3-4:
  → Preparar la redistribución: reorientar el nodo del hermano
    para que la clave disponible quede en la posición correcta.
```

### Caso 4: Hermano w NEGRO, hijo derecho de w ROJO

```text
Situación:
         (p)?
        /    \
     (x)DB  (w)B
             / \
           (a)? (b)R

Acción:
  1. w.color = p.color
  2. p.color = BLACK
  3. b.color = BLACK
  4. leftRotate(T, p)
  5. x = T.root  (terminar el loop)

Después:
         (w)?           ← hereda el color original de p
        /    \
      (p)B   (b)B
     /    \
   (x)B   (a)?

→ Double-black ELIMINADO. El camino por x ganó un negro (p se hizo negro).
→ FIN. No hay más propagación.

Equivalente 2-3-4:
  → REDISTRIBUCIÓN (borrow): tomar una clave del hermano a través del padre.
  → El hermano tenía una clave extra (representada por el hijo rojo).
  → Esa clave se redistribuye → balance restaurado.
```

## 14.2 Pseudocódigo completo del delete fix-up

```text
RB_Delete_Fixup(T, x):
  while x ≠ T.root and x.color == BLACK:
    if x == x.parent.left:
      w = x.parent.right                  // hermano

      if w.color == RED:                  // Caso 1
        w.color = BLACK
        x.parent.color = RED
        leftRotate(T, x.parent)
        w = x.parent.right

      if w.left.color == BLACK and w.right.color == BLACK:  // Caso 2
        w.color = RED
        x = x.parent                     // propagar

      else:
        if w.right.color == BLACK:        // Caso 3
          w.left.color = BLACK
          w.color = RED
          rightRotate(T, w)
          w = x.parent.right

        w.color = x.parent.color          // Caso 4
        x.parent.color = BLACK
        w.right.color = BLACK
        leftRotate(T, x.parent)
        x = T.root                        // terminar

    else:                                 // simétrico (x es hijo derecho)
      w = x.parent.left

      if w.color == RED:                  // Caso 1
        w.color = BLACK
        x.parent.color = RED
        rightRotate(T, x.parent)
        w = x.parent.left

      if w.right.color == BLACK and w.left.color == BLACK:  // Caso 2
        w.color = RED
        x = x.parent

      else:
        if w.left.color == BLACK:         // Caso 3
          w.right.color = BLACK
          w.color = RED
          leftRotate(T, w)
          w = x.parent.left

        w.color = x.parent.color          // Caso 4
        x.parent.color = BLACK
        w.left.color = BLACK
        rightRotate(T, x.parent)
        x = T.root

  x.color = BLACK                         // eliminar double-black
```

## 14.3 Resumen de los casos de eliminación

```text
┌─────────┬──────────────────────────┬─────────────────────────────────┐
│  Caso   │  Condición               │  Acción                         │
├─────────┼──────────────────────────┼─────────────────────────────────┤
│  1      │  Hermano ROJO            │  Rotar + recolorear → C2/C3/C4 │
│  2      │  Hermano NEGRO,          │  Recolorear hermano → propagar  │
│         │  ambos hijos negros      │  (merge en 2-3-4)               │
│  3      │  Hermano NEGRO,          │  Rotar hermano → Caso 4         │
│         │  hijo cercano ROJO,      │  (preparar redistribución)      │
│         │  hijo lejano NEGRO       │                                 │
│  4      │  Hermano NEGRO,          │  Rotar padre + recolorear → FIN │
│         │  hijo lejano ROJO        │  (redistribución en 2-3-4)      │
└─────────┴──────────────────────────┴─────────────────────────────────┘

Rotaciones máximas: 3 (Caso 1→Caso 3→Caso 4, cada uno con 1 rotación)
Recoloreos máximos: O(log n) (Caso 2 puede propagarse hasta la raíz)
```

---

# 15. Eliminación como Merge/Borrow de 2-3-4

## 15.1 Tabla de correspondencia

| Caso RB Delete  | Operación 2-3-4              | Descripción                                          |
| --------------- | ---------------------------- | ---------------------------------------------------- |
| Caso 1          | Reestructurar               | Hermano rojo = parte de un nodo grande → separar     |
| Caso 2          | Merge                        | Fusionar hermano y clave del padre en un nodo         |
| Caso 3          | Preparar redistribución     | Rotar para posicionar la clave prestable              |
| Caso 4          | Redistribuir (borrow)        | Tomar clave del hermano a través del padre            |

## 15.2 Merge vs Borrow en detalle

### Merge (Caso 2 de RB)

```text
En 2-3-4:
  El nodo a eliminar está en un 2-nodo.
  Su hermano también es un 2-nodo.
  → No hay clave que prestar.
  → Fusionar: hermano + clave del padre → 3-nodo.
  → El padre pierde una clave → puede quedar vacío → propagar.

En Red-Black:
  x es double-black, hermano w es negro con hijos negros.
  → No hay hijo rojo que redistribuir.
  → w se hace rojo (ambos "comparten" la negrura).
  → El padre absorbe el double-black → propagar si es negro.

Ejemplo:
  2-3-4:                     Red-Black:
    [P]                        (P)?
   /   \         →           /    \
  [x] [w]  vaciar x        (x)DB (w)B → (w)R, x=P
                              → merge
```

### Borrow / Redistribute (Caso 4 de RB)

```text
En 2-3-4:
  El nodo a eliminar está en un 2-nodo.
  Su hermano es un 3-nodo o 4-nodo (tiene claves extra).
  → Tomar prestada una clave del hermano, pasándola por el padre.
  → El padre recibe una clave del hermano.
  → El nodo vacío recibe una clave del padre.
  → Nadie queda vacío → no se propaga.

En Red-Black:
  x es double-black, hermano w negro con hijo lejano rojo (b).
  → La clave extra (hijo rojo b) se redistribuye.
  → Rotación + recoloreo mueven la negrura → x deja de ser double-black.

Ejemplo:
  2-3-4:                     Red-Black:
    [P]                        (P)?
   /   \         →           /    \
  [x]  [w|b]               (x)DB (w)B
                                    \
                                   (b)R → Caso 4 → rotación → FIN
```

## 15.3 La diferencia clave en eliminación

```text
En 2-3-4 trees:
  → Merge y borrow son operaciones sobre nodos multi-clave.
  → Conceptualmente simples, pero la implementación es compleja
    (manejar nodos de tamaño variable).

En Red-Black trees:
  → Merge = recoloreo (O(1)).
  → Borrow = rotación + recoloreo (O(1)).
  → Implementación uniforme (siempre nodos binarios con 1 clave).
  → Pero hay 4 casos (+ simétricos) que pueden ser confusos.

Trade-off:
  → 2-3-4 es más fácil de ENTENDER.
  → Red-Black es más fácil de IMPLEMENTAR (y más rápido).
```

---

# 16. Ejemplos de Eliminación Paso a Paso

## 16.1 Ejemplo 1: Eliminar nodo rojo (trivial)

```text
Árbol inicial:
         (20)B
        /      \
     (10)B    (30)B
      /
    (5)R

Eliminar 5:
  → 5 es rojo y es hoja → simplemente quitarlo.
  → No se afecta la black-height.

         (20)B
        /      \
     (10)B    (30)B

  → Ninguna propiedad violada. DONE.
```

## 16.2 Ejemplo 2: Eliminar negro con hijo rojo

```text
Árbol inicial:
         (20)B
        /      \
     (10)B    (30)B
      /
    (5)R

Eliminar 10:
  → 10 es negro con 1 hijo rojo (5).
  → Reemplazar 10 con 5, colorear 5 negro.

         (20)B
        /      \
      (5)B    (30)B

  → P5 se mantiene (5 es negro, reemplazó a 10 negro).
  → DONE. Sin fix-up.
```

## 16.3 Ejemplo 3: Caso 2 (merge) → terminación directa

```text
Árbol inicial:
         (20)B
        /      \
     (10)B    (30)B

Eliminar 10:
  → 10 es negro, sin hijos (ambos NIL).
  → Reemplazado por NIL.
  → y_original_color = BLACK → fix-up necesario.
  → x = NIL (hijo izquierdo de 20), w = 30 (hermano).

  Antes del fix-up:
         (20)B
        /      \
     (x)DB   (30)B    ← x=NIL es double-black
                        w=30 es negro
                        w.left=NIL(B), w.right=NIL(B)
                        → ambos hijos de w negros → Caso 2

  Caso 2:
    w(30).color = RED
    x = p = 20

         (20)?         ← x se movió al padre
        /      \
      NIL    (30)R

  x = 20, que es la raíz → salir del loop.
  x.color = BLACK → (20) se queda negro.

  Resultado:
         (20)B
             \
           (30)R

  Verificación:
    P2: (20)B ✓
    P4: (30)R → NIL(B), NIL(B) ✓
    P5: 20→NIL: negros {20} = 1 ✓
        20→30→NIL: negros {20} = 1 ✓  (30 es rojo, no cuenta)
```

## 16.4 Ejemplo 4: Caso 4 (redistribución)

```text
Árbol inicial:
              (20)B
             /      \
          (10)B    (30)B
                      \
                    (40)R

Eliminar 10:
  → 10 es negro, sin hijos → reemplazar con NIL → fix-up.
  → x = NIL (izq de 20), w = 30 (hermano).

  w = 30(B), w.left = NIL(B), w.right = 40(R) → hijo lejano ROJO → Caso 4

  Caso 4:
    w(30).color = p(20).color = BLACK
    p(20).color = BLACK
    b(40).color = BLACK
    leftRotate(p = 20)
    x = root → terminar

  Antes:                   Después:
       (20)B                   (30)B
      /      \                /      \
    NIL    (30)B           (20)B    (40)B
               \
             (40)R

  Verificación:
    P2: (30)B ✓
    P4: no hay rojos ✓
    P5: 30→20→NIL: negros {30,20} = 2 ✓
        30→40→NIL: negros {30,40} = 2 ✓
```

## 16.5 Ejemplo 5: Caso 1 → Caso 4 (complejo)

```text
Árbol inicial:
              (20)B
             /      \
          (10)B    (40)R
                   /    \
                (30)B  (50)B

Eliminar 10:
  → 10 negro, sin hijos → x = NIL, w = 40.
  → w = 40(R) → hermano ROJO → Caso 1

  Caso 1:
    w(40).color = BLACK
    p(20).color = RED
    leftRotate(p = 20)
    w = p.right = 30 (nuevo hermano)

  Después de Caso 1:
              (40)B
             /      \
          (20)R    (50)B
         /      \
       NIL    (30)B  ← nuevo w

  x = NIL, w = 30(B), w.left = NIL(B), w.right = NIL(B)
  → Ambos hijos negros → Caso 2

  Caso 2:
    w(30).color = RED
    x = p = 20

  x = 20, x.color = RED → salir del loop (x no es negro)
  x.color = BLACK → (20) se queda/se hace negro.

  Resultado:
              (40)B
             /      \
          (20)B    (50)B
               \
             (30)R

  Verificación:
    P2: (40)B ✓
    P4: (30)R → NIL(B), NIL(B) ✓
    P5: 40→20→NIL: negros {40,20} = 2 ✓
        40→20→30→NIL: negros {40,20} = 2 ✓  (30 es rojo)
        40→50→NIL: negros {40,50} = 2 ✓
```

## 16.6 Patrones a reconocer

```text
┌─────────────────────────────────────────────────────────────────┐
│  Patrón                         │  Resultado                    │
├─────────────────────────────────┼───────────────────────────────┤
│  Eliminar nodo rojo (hoja)      │  Trivial, sin fix-up          │
│  Negro con 1 hijo rojo          │  Reemplazo + recolorear       │
│  Negro hoja, hermano negro      │  Caso 2, 3 o 4               │
│  Negro hoja, hermano rojo       │  Caso 1 primero, luego 2/3/4  │
│  Caso 2 con padre rojo          │  Se resuelve inmediatamente   │
│  Caso 2 con padre negro         │  Se propaga hacia arriba      │
│  Caso 4                         │  Siempre termina el fix-up    │
└─────────────────────────────────┴───────────────────────────────┘
```

---

# PARTE V — IMPLEMENTACIÓN COMPLETA

---

# 17. Implementación en C

## 17.1 Definiciones y estructuras

```c
#include <stdio.h>
#include <stdlib.h>

// ─────── Colores ───────
typedef enum { RED, BLACK } Color;

// ─────── Nodo ───────
typedef struct RBNode {
    int data;
    Color color;
    struct RBNode *left;
    struct RBNode *right;
    struct RBNode *parent;
} RBNode;

// ─────── Árbol ───────
typedef struct {
    RBNode *root;
    RBNode *nil;    // nodo centinela
} RBTree;
```

## 17.2 Funciones auxiliares

```c
// Crear nodo centinela
RBNode* createNilNode() {
    RBNode *nil = (RBNode*)malloc(sizeof(RBNode));
    nil->color = BLACK;
    nil->left = NULL;
    nil->right = NULL;
    nil->parent = NULL;
    nil->data = 0;
    return nil;
}

// Crear un nuevo árbol vacío
RBTree* createTree() {
    RBTree *tree = (RBTree*)malloc(sizeof(RBTree));
    tree->nil = createNilNode();
    tree->root = tree->nil;
    return tree;
}

// Crear un nuevo nodo
RBNode* createNode(RBTree *tree, int data) {
    RBNode *node = (RBNode*)malloc(sizeof(RBNode));
    node->data = data;
    node->color = RED;    // nuevos nodos siempre rojos
    node->left = tree->nil;
    node->right = tree->nil;
    node->parent = tree->nil;
    return node;
}
```

## 17.3 Rotaciones

```c
// ─────── Left Rotate ───────
//
//     x                y
//    / \              / \
//   a   y    →      x   c
//      / \         / \
//     b   c       a   b
//
void leftRotate(RBTree *tree, RBNode *x) {
    RBNode *y = x->right;        // y es el hijo derecho de x

    // 1. El subárbol izquierdo de y se vuelve derecho de x
    x->right = y->left;
    if (y->left != tree->nil) {
        y->left->parent = x;
    }

    // 2. El padre de x se convierte en padre de y
    y->parent = x->parent;
    if (x->parent == tree->nil) {
        tree->root = y;
    } else if (x == x->parent->left) {
        x->parent->left = y;
    } else {
        x->parent->right = y;
    }

    // 3. x se vuelve hijo izquierdo de y
    y->left = x;
    x->parent = y;
}

// ─────── Right Rotate ───────
//
//       y              x
//      / \            / \
//     x   c    →    a   y
//    / \                / \
//   a   b              b   c
//
void rightRotate(RBTree *tree, RBNode *y) {
    RBNode *x = y->left;

    y->left = x->right;
    if (x->right != tree->nil) {
        x->right->parent = y;
    }

    x->parent = y->parent;
    if (y->parent == tree->nil) {
        tree->root = x;
    } else if (y == y->parent->left) {
        y->parent->left = x;
    } else {
        y->parent->right = x;
    }

    x->right = y;
    y->parent = x;
}
```

## 17.4 Inserción

```c
// ─────── Insert Fix-Up ───────
void insertFixup(RBTree *tree, RBNode *z) {
    while (z->parent->color == RED) {
        if (z->parent == z->parent->parent->left) {
            RBNode *uncle = z->parent->parent->right;

            if (uncle->color == RED) {
                // Caso 1: Tío rojo → recoloreo
                z->parent->color = BLACK;
                uncle->color = BLACK;
                z->parent->parent->color = RED;
                z = z->parent->parent;
            } else {
                if (z == z->parent->right) {
                    // Caso 2: Tío negro, z es hijo interno
                    z = z->parent;
                    leftRotate(tree, z);
                }
                // Caso 3: Tío negro, z es hijo externo
                z->parent->color = BLACK;
                z->parent->parent->color = RED;
                rightRotate(tree, z->parent->parent);
            }
        } else {
            // Simétrico: padre es hijo derecho del abuelo
            RBNode *uncle = z->parent->parent->left;

            if (uncle->color == RED) {
                z->parent->color = BLACK;
                uncle->color = BLACK;
                z->parent->parent->color = RED;
                z = z->parent->parent;
            } else {
                if (z == z->parent->left) {
                    z = z->parent;
                    rightRotate(tree, z);
                }
                z->parent->color = BLACK;
                z->parent->parent->color = RED;
                leftRotate(tree, z->parent->parent);
            }
        }
    }
    tree->root->color = BLACK;  // P2: raíz siempre negra
}

// ─────── Insert ───────
void rbInsert(RBTree *tree, int data) {
    RBNode *z = createNode(tree, data);
    RBNode *y = tree->nil;
    RBNode *x = tree->root;

    // Fase 1: Búsqueda BST estándar
    while (x != tree->nil) {
        y = x;
        if (z->data < x->data) {
            x = x->left;
        } else {
            x = x->right;
        }
    }

    z->parent = y;
    if (y == tree->nil) {
        tree->root = z;
    } else if (z->data < y->data) {
        y->left = z;
    } else {
        y->right = z;
    }

    // Fase 2: Fix-Up
    insertFixup(tree, z);
}
```

## 17.5 Eliminación

```c
// ─────── Transplant ───────
void rbTransplant(RBTree *tree, RBNode *u, RBNode *v) {
    if (u->parent == tree->nil) {
        tree->root = v;
    } else if (u == u->parent->left) {
        u->parent->left = v;
    } else {
        u->parent->right = v;
    }
    v->parent = u->parent;
}

// ─────── Minimum ───────
RBNode* rbMinimum(RBTree *tree, RBNode *x) {
    while (x->left != tree->nil) {
        x = x->left;
    }
    return x;
}

// ─────── Delete Fix-Up ───────
void deleteFixup(RBTree *tree, RBNode *x) {
    while (x != tree->root && x->color == BLACK) {
        if (x == x->parent->left) {
            RBNode *w = x->parent->right;   // hermano

            // Caso 1: Hermano rojo
            if (w->color == RED) {
                w->color = BLACK;
                x->parent->color = RED;
                leftRotate(tree, x->parent);
                w = x->parent->right;
            }

            // Caso 2: Hermano negro, ambos hijos negros
            if (w->left->color == BLACK && w->right->color == BLACK) {
                w->color = RED;
                x = x->parent;
            } else {
                // Caso 3: Hermano negro, hijo lejano negro
                if (w->right->color == BLACK) {
                    w->left->color = BLACK;
                    w->color = RED;
                    rightRotate(tree, w);
                    w = x->parent->right;
                }
                // Caso 4: Hermano negro, hijo lejano rojo
                w->color = x->parent->color;
                x->parent->color = BLACK;
                w->right->color = BLACK;
                leftRotate(tree, x->parent);
                x = tree->root;   // terminar
            }
        } else {
            // Simétrico: x es hijo derecho
            RBNode *w = x->parent->left;

            if (w->color == RED) {
                w->color = BLACK;
                x->parent->color = RED;
                rightRotate(tree, x->parent);
                w = x->parent->left;
            }

            if (w->right->color == BLACK && w->left->color == BLACK) {
                w->color = RED;
                x = x->parent;
            } else {
                if (w->left->color == BLACK) {
                    w->right->color = BLACK;
                    w->color = RED;
                    leftRotate(tree, w);
                    w = x->parent->left;
                }
                w->color = x->parent->color;
                x->parent->color = BLACK;
                w->left->color = BLACK;
                rightRotate(tree, x->parent);
                x = tree->root;
            }
        }
    }
    x->color = BLACK;
}

// ─────── Delete ───────
void rbDelete(RBTree *tree, int data) {
    // Buscar el nodo a eliminar
    RBNode *z = tree->root;
    while (z != tree->nil) {
        if (data < z->data) {
            z = z->left;
        } else if (data > z->data) {
            z = z->right;
        } else {
            break;
        }
    }

    if (z == tree->nil) {
        printf("Clave %d no encontrada.\n", data);
        return;
    }

    RBNode *y = z;
    Color y_original_color = y->color;
    RBNode *x;

    if (z->left == tree->nil) {
        x = z->right;
        rbTransplant(tree, z, z->right);

    } else if (z->right == tree->nil) {
        x = z->left;
        rbTransplant(tree, z, z->left);

    } else {
        // Dos hijos: sucesor inorder
        y = rbMinimum(tree, z->right);
        y_original_color = y->color;
        x = y->right;

        if (y->parent == z) {
            x->parent = y;
        } else {
            rbTransplant(tree, y, y->right);
            y->right = z->right;
            y->right->parent = y;
        }

        rbTransplant(tree, z, y);
        y->left = z->left;
        y->left->parent = y;
        y->color = z->color;
    }

    free(z);

    if (y_original_color == BLACK) {
        deleteFixup(tree, x);
    }
}
```

## 17.6 Funciones de utilidad

```c
// ─────── Búsqueda ───────
RBNode* rbSearch(RBTree *tree, int data) {
    RBNode *x = tree->root;
    while (x != tree->nil) {
        if (data < x->data) {
            x = x->left;
        } else if (data > x->data) {
            x = x->right;
        } else {
            return x;
        }
    }
    return tree->nil;  // no encontrado
}

// ─────── Inorder Traversal ───────
void inorder(RBTree *tree, RBNode *node) {
    if (node == tree->nil) return;
    inorder(tree, node->left);
    printf("%d(%c) ", node->data, node->color == RED ? 'R' : 'B');
    inorder(tree, node->right);
}

// ─────── Imprimir árbol (visual) ───────
void printTreeHelper(RBTree *tree, RBNode *node, char *indent, int isRight) {
    if (node == tree->nil) return;

    printf("%s", indent);
    if (isRight) {
        printf("R── ");
    } else {
        printf("L── ");
    }
    printf("%d(%c)\n", node->data, node->color == RED ? 'R' : 'B');

    char newIndent[256];
    snprintf(newIndent, sizeof(newIndent), "%s%s", indent, isRight ? "    " : "│   ");

    printTreeHelper(tree, node->left, newIndent, 0);
    printTreeHelper(tree, node->right, newIndent, 1);
}

void printTree(RBTree *tree) {
    if (tree->root == tree->nil) {
        printf("(árbol vacío)\n");
        return;
    }
    printf("%d(%c)\n", tree->root->data, tree->root->color == RED ? 'R' : 'B');
    char indent[256] = "";
    printTreeHelper(tree, tree->root->left, indent, 0);
    printTreeHelper(tree, tree->root->right, indent, 1);
}

// ─────── Verificar propiedades Red-Black ───────
int verifyHelper(RBTree *tree, RBNode *node, int blackCount, int *pathBlackCount) {
    if (node == tree->nil) {
        if (*pathBlackCount == -1) {
            *pathBlackCount = blackCount;
        }
        return blackCount == *pathBlackCount;
    }

    // P4: No dos rojos consecutivos
    if (node->color == RED && node->parent->color == RED) {
        printf("VIOLACIÓN P4: %d(R) tiene padre %d(R)\n",
               node->data, node->parent->data);
        return 0;
    }

    if (node->color == BLACK) {
        blackCount++;
    }

    return verifyHelper(tree, node->left, blackCount, pathBlackCount) &&
           verifyHelper(tree, node->right, blackCount, pathBlackCount);
}

int verifyRBTree(RBTree *tree) {
    // P2: Raíz negra
    if (tree->root != tree->nil && tree->root->color != BLACK) {
        printf("VIOLACIÓN P2: raíz no es negra\n");
        return 0;
    }

    // P4 y P5
    int pathBlackCount = -1;
    if (!verifyHelper(tree, tree->root, 0, &pathBlackCount)) {
        printf("VIOLACIÓN P5: black-height inconsistente\n");
        return 0;
    }

    printf("✓ Árbol Red-Black válido (black-height = %d)\n", pathBlackCount);
    return 1;
}

// ─────── Liberar memoria ───────
void freeTree(RBTree *tree, RBNode *node) {
    if (node == tree->nil) return;
    freeTree(tree, node->left);
    freeTree(tree, node->right);
    free(node);
}

void destroyTree(RBTree *tree) {
    freeTree(tree, tree->root);
    free(tree->nil);
    free(tree);
}
```

## 17.7 Programa principal

```c
int main() {
    RBTree *tree = createTree();

    // ═══ Insertar valores ═══
    int values[] = {10, 20, 30, 15, 25, 5, 1, 40, 35, 50};
    int n = sizeof(values) / sizeof(values[0]);

    printf("═══ Insertando valores ═══\n");
    for (int i = 0; i < n; i++) {
        printf("\nInsertando %d:\n", values[i]);
        rbInsert(tree, values[i]);
        printTree(tree);
        verifyRBTree(tree);
    }

    // ═══ Recorrido inorder ═══
    printf("\n═══ Inorder Traversal ═══\n");
    inorder(tree, tree->root);
    printf("\n");

    // ═══ Búsqueda ═══
    printf("\n═══ Búsqueda ═══\n");
    int searchVals[] = {15, 42, 50};
    for (int i = 0; i < 3; i++) {
        RBNode *result = rbSearch(tree, searchVals[i]);
        if (result != tree->nil) {
            printf("Encontrado: %d (%s)\n", result->data,
                   result->color == RED ? "ROJO" : "NEGRO");
        } else {
            printf("No encontrado: %d\n", searchVals[i]);
        }
    }

    // ═══ Eliminación ═══
    int deleteVals[] = {1, 15, 30, 20};
    printf("\n═══ Eliminando valores ═══\n");
    for (int i = 0; i < 4; i++) {
        printf("\nEliminando %d:\n", deleteVals[i]);
        rbDelete(tree, deleteVals[i]);
        printTree(tree);
        verifyRBTree(tree);
    }

    // ═══ Recorrido final ═══
    printf("\n═══ Inorder Final ═══\n");
    inorder(tree, tree->root);
    printf("\n");

    destroyTree(tree);
    return 0;
}
```

## 17.8 Salida esperada (extracto)

```text
═══ Insertando valores ═══

Insertando 10:
10(B)
✓ Árbol Red-Black válido (black-height = 1)

Insertando 20:
10(B)
R── 20(R)
✓ Árbol Red-Black válido (black-height = 1)

Insertando 30:
20(B)
L── 10(R)
R── 30(R)
✓ Árbol Red-Black válido (black-height = 1)

...

═══ Inorder Traversal ═══
1(R) 5(B) 10(B) 15(R) 20(B) 25(B) 30(R) 35(B) 40(R) 50(R)

═══ Búsqueda ═══
Encontrado: 15 (ROJO)
No encontrado: 42
Encontrado: 50 (ROJO)

═══ Eliminando valores ═══
...
✓ Árbol Red-Black válido después de cada eliminación
```

---

# PARTE VI — COMPARACIÓN Y ANÁLISIS

---

# 18. Red-Black vs 2-3-4: Operaciones Comparadas

## 18.1 Tabla de equivalencias operacionales

| Operación RB              | Equivalente 2-3-4                | Costo   |
| ------------------------- | -------------------------------- | ------- |
| Color flip (Caso 1 ins.)  | Split de 4-nodo                  | O(1)    |
| Rotación (Caso 2/3 ins.)  | Reestructuración post-split      | O(1)    |
| Recoloreo hermano (C2 del)| Merge de nodos                   | O(1)    |
| Rotación (C3/C4 del.)     | Redistribución (borrow)          | O(1)    |
| Rotación (C1 del.)        | Reestructurar para exponer hermano| O(1)   |
| Inserción BST             | Buscar hoja + absorber            | O(log n)|
| Búsqueda                  | Navegar nodos multi-clave         | O(log n)|

## 18.2 Comportamiento en inserción

```text
2-3-4 (top-down):
  1. Bajar dividiendo 4-nodos preventivamente
  2. Insertar en hoja (2 o 3-nodo → siempre hay espacio)
  3. Sin propagación hacia arriba
  → 1 pase, O(log n) splits preventivos (amortizado O(1))

Red-Black (bottom-up, CLRS):
  1. Insertar como BST + colorear rojo
  2. Subir reparando: color flips (Caso 1) + rotaciones (Caso 2/3)
  → 2 pases conceptuales, O(log n) recoloreos + máx 2 rotaciones

Red-Black (top-down, Sedgewick):
  1. Bajar haciendo color flips en nodos negro-con-2-hijos-rojos
  2. Insertar + rotación local si es necesario
  → 1 pase, equivalente directo al 2-3-4 top-down
```

## 18.3 Comportamiento en eliminación

```text
2-3-4:
  Merge:  fusionar hermano 2-nodo + clave padre → puede propagar
  Borrow: tomar de hermano 3/4-nodo → no propaga
  → Hasta O(log n) merges

Red-Black:
  Caso 2: merge → propagar → hasta O(log n)
  Caso 4: borrow → termina → máx 3 rotaciones totales

→ La eliminación es la operación más costosa en ambos,
  pero ambos garantizan O(log n) en total.
```

---

# 19. Red-Black vs AVL

## 19.1 Tabla comparativa detallada

| Aspecto                  | AVL Tree               | Red-Black Tree          |
| ------------------------ | ---------------------- | ----------------------- |
| Invariante               | |bf| ≤ 1 para todo nodo | 5 propiedades de color  |
| Altura máxima            | 1.44·log₂(n)           | 2·log₂(n)               |
| Campo extra por nodo     | height (int, 4 bytes)  | color (1 bit)           |
| Puntero al padre         | No necesario            | Necesario (o recursión)  |
| Búsqueda                 | Más rápida (menor h)   | Un poco más lenta        |
| Inserción: rotaciones    | Máx 1 (simple o doble) | Máx 2                    |
| Inserción: actualizaciones| O(log n) alturas       | O(log n) recoloreos     |
| Eliminación: rotaciones  | Hasta O(log n)          | Máx 3                    |
| Inserción/eliminación    | Más lento               | Más rápido               |
| Modelo conceptual        | —                       | 2-3-4 tree               |
| Complejidad de código    | Moderada                | Alta                     |
| Uso en librerías estándar| Pocos                   | Java, C++, Linux, .NET   |

## 19.2 ¿Cuándo elegir cada uno?

```text
Elegir AVL:
  ✓ Las búsquedas dominan (muchas más búsquedas que inserciones/eliminaciones)
  ✓ Bases de datos in-memory con datos relativamente estáticos
  ✓ Se necesita la menor altura posible
  ✓ Implementación más intuitiva

Elegir Red-Black:
  ✓ Inserciones y eliminaciones son frecuentes
  ✓ Se necesita buen rendimiento en TODAS las operaciones
  ✓ Se implementa una librería estándar
  ✓ Se necesita que eliminación sea eficiente (máx 3 rotaciones)
  ✓ Memoria limitada (color = 1 bit vs height = 4 bytes)
```

## 19.3 Benchmark conceptual

```text
Operación: insertar 1,000,000 elementos aleatorios + 1,000,000 búsquedas

                    AVL              Red-Black
                    ─────            ──────────
Inserción total:    ~20M comps       ~20M comps
                    ~500K rotaciones ~1M rotaciones
                    (más recálculos  (pero sin recalcular
                     de altura)       alturas)

Búsqueda total:     ~20M comps       ~26M comps
                    (h ≈ 20)         (h ≈ 26)

→ Diferencia real: ~5-10%. Insignificante para la mayoría de aplicaciones.
→ Red-Black gana en versatilidad y es el estándar de facto.
```

---

# 20. Complejidad de Operaciones

## 20.1 Tabla de complejidad final

| Operación     | Tiempo   | Rotaciones (inserción)  | Rotaciones (eliminación) |
| ------------- | -------- | ----------------------- | ----------------------- |
| Búsqueda      | O(log n) | —                       | —                       |
| Inserción     | O(log n) | Máx 2                   | —                       |
| Eliminación   | O(log n) | —                       | Máx 3                   |
| Mínimo/Máximo | O(log n) | —                       | —                       |
| Sucesor       | O(log n) | —                       | —                       |
| Espacio       | O(n)     | —                       | —                       |

## 20.2 Desglose de costos

```text
Inserción O(log n):
  • Búsqueda de posición: O(log n)
  • Crear nodo: O(1)
  • Fix-up: O(log n) recoloreos + O(1) rotaciones (máx 2)
  • Total: O(log n)

Eliminación O(log n):
  • Búsqueda del nodo: O(log n)
  • Eliminación BST: O(log n) (encontrar sucesor)
  • Fix-up: O(log n) recoloreos + O(1) rotaciones (máx 3)
  • Total: O(log n)

Amortizado:
  • Una secuencia de m inserciones: O(m·log n) total, O(m) rotaciones
  • → Rotaciones amortizadas: O(1) por inserción
```

---

# PARTE VII — SÍNTESIS

---

# 21. Errores Comunes y Buenas Prácticas

## 21.1 Tabla de errores

| #  | Error                                                   | Consecuencia                               | Corrección                                        |
| -- | ------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------- |
| 1  | Insertar como NEGRO                                      | P5 se viola siempre                         | Siempre insertar como ROJO                        |
| 2  | Olvidar forzar la raíz a negro                           | P2 se viola                                 | Al final del fix-up: root.color = BLACK            |
| 3  | No usar nodo centinela NIL                               | Segfault al acceder a color de NULL         | Usar centinela global con color BLACK              |
| 4  | Confundir tío con hermano                                | Casos mal aplicados                         | Tío = hermano del padre. Hermano = hermano de x   |
| 5  | No actualizar parent en rotaciones                       | Árbol corrupto                              | Actualizar los 3 enlaces en cada rotación          |
| 6  | Aplicar Caso 3 directamente sin verificar                | Caso 2 primero si z es hijo interno         | Siempre verificar posición de z antes del Caso 3   |
| 7  | No distinguir Caso 3 y 4 en eliminación                  | Fix-up incorrecto                           | Caso 3: hijo lejano negro. Caso 4: hijo lejano rojo|
| 8  | Olvidar el caso simétrico                                | Solo funciona cuando parent es hijo izq.    | Implementar ambas ramas (izq y der)                |
| 9  | No liberar el nodo eliminado                             | Memory leak                                 | free(z) después de transplant                      |
| 10 | Creer que Red-Black es "BST con colores"                 | No entender la estructura subyacente        | Es un 2-3-4 tree disfrazado de BST                 |

## 21.2 Buenas prácticas

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. SIEMPRE usa un nodo centinela NIL (no NULL)                  │
│     → Elimina todos los chequeos de NULL antes de acceder a color│
│                                                                  │
│  2. Verifica el árbol después de cada operación (en debug)       │
│     → La función verifyRBTree detecta violaciones al instante    │
│                                                                  │
│  3. Dibuja el 2-3-4 equivalente cuando no entiendas un caso      │
│     → El color flip = split, la rotación = reestructuración      │
│                                                                  │
│  4. Escribe tests con secuencias conocidas:                      │
│     → Datos ordenados (1,2,3,...,n): peor caso para BST          │
│     → Datos inversamente ordenados                               │
│     → Insertar y luego eliminar todos                            │
│     → Verificar propiedades después de cada operación            │
│                                                                  │
│  5. Implementa rotaciones como operaciones atómicas              │
│     → Siempre actualizan los 3 enlaces bidireccionales           │
│     → leftRotate y rightRotate son simétricas                    │
│                                                                  │
│  6. Para producción: usa la implementación de tu lenguaje        │
│     → Java: TreeMap<K,V> / TreeSet<E>                            │
│     → C++: std::map<K,V> / std::set<K>                           │
│     → Python: sortedcontainers.SortedDict                        │
│     → Implementar RB tree es un ejercicio educativo, no práctico │
└──────────────────────────────────────────────────────────────────┘
```

---

# 22. Intuición de Ingeniería

> **Un Red-Black Tree es un 2-3-4 Tree que eligió disfrazarse de BST.**
> Los colores no son un truco arbitrario: codifican la estructura multiway.
> Cada color flip es un split. Cada rotación es una reestructuración.
> Entender Red-Black sin 2-3-4 es memorizar recetas sin saber cocinar.

### La idea en una oración

```text
Red-Black Tree = 2-3-4 Tree + representación binaria + un bit de color
```

### El mapa mental completo

```text
Inserción:
  Nuevo nodo (rojo) → ¿padre rojo? → fix-up
    │
    ├─ Tío rojo → Color Flip (= split 4-nodo) → propagar
    │
    └─ Tío negro → Rotación (= reestructurar) → FIN
       ├─ z externo → 1 rotación
       └─ z interno → 2 rotaciones

Eliminación:
  Eliminar nodo → ¿era negro? → fix-up
    │
    ├─ Hermano rojo → Caso 1: rotar para exponer verdadero hermano
    │
    ├─ Hermano negro, hijos negros → Caso 2: merge → propagar
    │
    ├─ Hermano negro, hijo cercano rojo → Caso 3: rotar → Caso 4
    │
    └─ Hermano negro, hijo lejano rojo → Caso 4: redistribuir → FIN
```

### La analogía del lenguaje

```text
2-3-4 Tree:    Español (expresivo, intuitivo, fácil de entender)
Red-Black Tree: Código máquina (difícil de leer, pero eficiente)

La COMPILACIÓN es la correspondencia entre ambos.
Cada instrucción en 2-3-4 tiene su traducción en Red-Black.

Como programador, quieres:
  → PENSAR en 2-3-4 (modelo mental)
  → IMPLEMENTAR en Red-Black (ejecución eficiente)
```

### ¿Cuándo usar Red-Black Trees en la vida real?

```text
✅ Casi nunca implementas uno desde cero. Usas la librería:
   • std::map / std::set (C++)
   • TreeMap / TreeSet (Java)
   • SortedDictionary (.NET)

✅ Pero ENTENDERLO es crucial para:
   • Entrevistas técnicas (Google, Meta, Amazon)
   • Entender por qué std::map es O(log n)
   • Debugging de performance en código que usa maps
   • Diseñar sistemas que requieren diccionarios ordenados

✅ Implementarlo es un RITO DE PASO en CS:
   • Demuestra comprensión profunda de árboles
   • Demuestra capacidad de manejar complejidad
   • Es el algoritmo con más casos edge que verás en pregrado
```

### Comparación final: todas las variantes

```text
┌──────────────────┬───────────┬───────────┬──────────────┐
│  Estructura      │  Búsqueda │  Insert   │  Delete      │
├──────────────────┼───────────┼───────────┼──────────────┤
│  BST (peor)      │  O(n)     │  O(n)     │  O(n)        │
│  BST (promedio)  │  O(log n) │  O(log n) │  O(log n)    │
│  AVL             │  O(log n) │  O(log n) │  O(log n)*   │
│  2-3             │  O(log n) │  O(log n) │  O(log n)    │
│  2-3-4           │  O(log n) │  O(log n) │  O(log n)    │
│  Red-Black       │  O(log n) │  O(log n) │  O(log n)**  │
├──────────────────┼───────────┼───────────┼──────────────┤
│  * AVL delete    │  hasta O(log n) rotaciones            │
│  ** RB delete    │  máximo 3 rotaciones                  │
└──────────────────┴───────────────────────────────────────┘
```

### Relación con otros temas

| Tema                              | Archivo              |
| --------------------------------- | -------------------- |
| Arrays a bajo nivel               | Arrays CDT.md        |
| Operaciones sobre arrays          | Arrays ADT.md        |
| Matrices densas y especiales      | Matrices.md          |
| Sparse matrices y polinomios      | SparseMatrices.md    |
| Strings (arrays de char)          | Strings.md           |
| Linked Lists                      | LinkedList.md        |
| Stacks                            | Stack.md             |
| Queues                            | Queue.md             |
| Trees (fundamentos)               | Trees.md             |
| Binary Search Trees               | BinarySearchTree.md  |
| AVL Trees                         | AVLTree.md           |
| 2-3 Trees y 2-3-4 Trees           | 2-3Trees.md          |
| **Red-Black Trees (este)**        | RedBlackTree.md      |

---

# 23. Ejercicios Sugeridos

## 23.1 Nivel básico

| #  | Ejercicio                                                              | Concepto clave        |
| -- | ---------------------------------------------------------------------- | --------------------- |
| 1  | Insertar {7, 3, 18, 10, 22, 8, 11, 26} en un RB tree y dibujar       | Inserción + fix-up    |
| 2  | Verificar las 5 propiedades en el árbol resultante                     | Propiedades RB        |
| 3  | Calcular el black-height de cada nodo                                   | Black-height          |
| 4  | Dibujar el 2-3-4 tree equivalente al RB del ejercicio 1               | Correspondencia       |

## 23.2 Nivel intermedio

| #  | Ejercicio                                                              | Concepto clave        |
| -- | ---------------------------------------------------------------------- | --------------------- |
| 5  | Insertar {1, 2, 3, ..., 15} en un RB tree (datos ordenados)           | Peor caso inserción   |
| 6  | Comparar la altura del RB resultante vs BST con los mismos datos       | Garantía de balance   |
| 7  | Eliminar {11, 18, 7} del árbol del ejercicio 1 paso a paso            | Eliminación + fix-up  |
| 8  | Construir un 2-3-4 tree con {10,20,30,...,100} y traducir a RB         | Transformación        |
| 9  | Dado un RB tree, identificar si una inserción causará Caso 1, 2 o 3   | Predicción de caso    |

## 23.3 Nivel avanzado

| #   | Ejercicio                                                            | Concepto clave          |
| --- | -------------------------------------------------------------------- | ----------------------- |
| 10  | Implementar inserción top-down (color flips preventivos al bajar)    | Top-down = 2-3-4        |
| 11  | Demostrar que la inserción RB hace máximo 2 rotaciones               | Análisis de rotaciones  |
| 12  | Demostrar que n ≥ 2^(bh) - 1 por inducción                           | Cota de black-height    |
| 13  | Implementar un iterador inorder sobre RB tree (sin recursión)         | Iterador con parent ptr |
| 14  | Insertar y luego eliminar 100,000 elementos aleatorios, verificando propiedades | Testing exhaustivo |

### Pistas para ejercicios seleccionados

```text
Ejercicio 5 — Datos ordenados en RB tree:
  Los datos ordenados son el peor caso para BST (cadena h=n-1).
  En RB, los color flips y rotaciones mantienen h ≤ 2·log₂(n).
  Con n=15: BST h=14, RB h≤8.
  Dibuja paso a paso: notarás que los color flips actúan como
  splits de 4-nodos en el 2-3-4 equivalente.

Ejercicio 7 — Eliminación paso a paso:
  Para cada eliminación:
  1. Identifica si el nodo es hoja, tiene 1 hijo, o 2 hijos
  2. Si tiene 2 hijos, encuentra el sucesor inorder
  3. Determina y_original_color
  4. Si era negro → identifica el caso del fix-up
  5. Aplica el caso y verifica las 5 propiedades

Ejercicio 10 — Top-down insertion:
  Al bajar, si encuentras un nodo negro con ambos hijos rojos:
    → Color flip (padre→rojo, hijos→negros)
    → Esto es Caso 1 de forma preventiva
  Al llegar a la hoja, insertar como rojo.
  Si hay violación local → máximo 1-2 rotaciones.
  → Equivale exactamente al split preventivo de 2-3-4 top-down.

Ejercicio 12 — Demostración por inducción:
  Base: bh(x)=0 → x es hoja NIL → subárbol tiene 0 nodos = 2⁰-1 ✓
  Paso: bh(x)=k → cada hijo tiene bh ≥ k-1
    → cada subárbol hijo tiene ≥ 2^(k-1)-1 nodos
    → nodo x tiene ≥ 2·(2^(k-1)-1)+1 = 2^k-1 nodos ✓
```
