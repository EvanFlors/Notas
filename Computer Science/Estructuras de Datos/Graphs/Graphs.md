# Graphs — Modelando Conexiones entre Todo

> **Idea central:** Un array modela una secuencia. Un árbol modela una jerarquía.
> Un **grafo** modela **conexiones arbitrarias** entre cualquier par de entidades.
> Redes sociales, mapas, internet, dependencias de software, circuitos, moléculas: todo es un grafo. Es la estructura de datos más general y más poderosa, y dominarla significa poder modelar **cualquier relación** del mundo real.
> Con dos representaciones (matriz y listas de adyacencia), dos traversals
> fundamentales (BFS y DFS), y un puñado de algoritmos clásicos,
> puedes resolver problemas que ninguna otra estructura puede tocar.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Definición de Grafo](#1-definición-de-grafo)
2. [Terminología](#2-terminología)
3. [Tipos de Grafos](#3-tipos-de-grafos)
4. [Propiedades Matemáticas](#4-propiedades-matemáticas)

**Parte II — Representaciones**
5. [Matriz de Adyacencia](#5-matriz-de-adyacencia)
6. [Lista de Adyacencia](#6-lista-de-adyacencia)
7. [Edge List](#7-edge-list)
8. [Comparación de Representaciones](#8-comparación-de-representaciones)

**Parte III — Recorridos (Traversal)**
9. [Concepto de Recorrido en Grafos](#9-concepto-de-recorrido-en-grafos)
10. [Breadth-First Search (BFS)](#10-breadth-first-search-bfs)
11. [Depth-First Search (DFS)](#11-depth-first-search-dfs)
12. [BFS vs DFS](#12-bfs-vs-dfs)

**Parte IV — Aplicaciones de BFS y DFS**
13. [Camino Más Corto (BFS, sin pesos)](#13-camino-más-corto-bfs-sin-pesos)
14. [Detección de Ciclos](#14-detección-de-ciclos)
15. [Componentes Conexas](#15-componentes-conexas)
16. [Ordenamiento Topológico](#16-ordenamiento-topológico)

**Parte V — Grafos con Pesos: Algoritmos Clásicos**
17. [Dijkstra (Camino Más Corto con Pesos)](#17-dijkstra-camino-más-corto-con-pesos)
18. [Bellman-Ford](#18-bellman-ford)
19. [Prim (Minimum Spanning Tree)](#19-prim-minimum-spanning-tree)
20. [Kruskal (Minimum Spanning Tree)](#20-kruskal-minimum-spanning-tree)

**Parte VI — Implementación Completa**
21. [Implementación: Matriz de Adyacencia](#21-implementación-matriz-de-adyacencia)
22. [Implementación: Lista de Adyacencia](#22-implementación-lista-de-adyacencia)
23. [Implementación: BFS y DFS](#23-implementación-bfs-y-dfs)
24. [Implementación: Dijkstra](#24-implementación-dijkstra)

**Parte VII — Síntesis**
25. [Resumen de Complejidad](#25-resumen-de-complejidad)
26. [Errores Comunes y Buenas Prácticas](#26-errores-comunes-y-buenas-prácticas)
27. [Intuición de Ingeniería](#27-intuición-de-ingeniería)
28. [Ejercicios Sugeridos](#28-ejercicios-sugeridos)

---

# PARTE I — FUNDAMENTOS

---

# 1. Definición de Grafo

## 1.1 ¿Qué es un grafo?

Un **grafo** G es un par ordenado G = (V, E) donde:

- **V** = conjunto de **vértices** (nodos)
- **E** = conjunto de **aristas** (edges), donde cada arista conecta dos vértices

```text
Ejemplo:
  V = {A, B, C, D, E}
  E = {(A,B), (A,C), (B,D), (C,D), (D,E)}

  Visualización:

      A ─── B
      |     |
      C ─── D ─── E
```

## 1.2 Diferencia con árboles

```text
Árbol:                          Grafo:
  • Conectado                     • Puede ser desconectado
  • Sin ciclos                    • Puede tener ciclos
  • n nodos, n-1 aristas         • Cualquier número de aristas
  • Exactamente 1 camino          • Múltiples caminos posibles
    entre dos nodos                entre dos nodos
  • Tiene raíz (usualmente)       • No tiene raíz

Un árbol ES un grafo: un grafo conexo acíclico.
Pero un grafo NO necesariamente es un árbol.
```

## 1.3 ¿Dónde se usan grafos?

```text
┌──────────────────────────┬────────────────────────────────────┐
│  Dominio                 │  Vértices           Aristas        │
├──────────────────────────┼────────────────────────────────────┤
│  Redes sociales          │  Personas           Amistades      │
│  Internet / Web          │  Páginas            Hipervínculos  │
│  Mapas / GPS             │  Intersecciones     Calles         │
│  Dependencias (build)    │  Módulos            Import/require │
│  Circuitos               │  Componentes        Conexiones     │
│  Biología (proteínas)    │  Proteínas          Interacciones  │
│  Scheduling              │  Tareas             Precedencias   │
│  Bases de datos (ER)     │  Entidades          Relaciones     │
│  Compiladores            │  Básic blocks       Flujo control  │
│  Redes de computadoras   │  Routers            Enlaces        │
└──────────────────────────┴────────────────────────────────────┘
```

---

# 2. Terminología

## 2.1 Vocabulario fundamental

```text
┌─────────────────────┬──────────────────────────────────────────────┐
│  Término            │  Definición                                  │
├─────────────────────┼──────────────────────────────────────────────┤
│  Vértice (nodo)     │  Entidad en el grafo                        │
│  Arista (edge)      │  Conexión entre dos vértices                │
│  Adyacente          │  Dos vértices conectados por una arista     │
│  Incidente          │  Una arista es incidente a sus extremos     │
│  Grado (degree)     │  Número de aristas incidentes a un vértice  │
│  Camino (path)      │  Secuencia de vértices conectados por aristas│
│  Ciclo              │  Camino que empieza y termina en el mismo vértice│
│  Longitud de camino │  Número de aristas en el camino             │
│  Distancia          │  Longitud del camino más corto              │
│  Componente conexa  │  Subgrafo maximal donde todos están conectados│
│  Grafo conexo       │  Solo hay una componente conexa             │
│  Vecinos            │  Vértices adyacentes a un vértice dado      │
│  Peso               │  Valor numérico asignado a una arista       │
│  Self-loop          │  Arista de un vértice a sí mismo            │
│  Multigraph         │  Grafo con múltiples aristas entre mismos nodos│
└─────────────────────┴──────────────────────────────────────────────┘
```

## 2.2 Grado de un vértice

```text
Grafo no dirigido:
  deg(v) = número de aristas incidentes a v

      A ─── B ─── C
      |           |
      D ─── E ─── F

  deg(A) = 2  (aristas a B y D)
  deg(B) = 2  (aristas a A y C)
  deg(E) = 2  (aristas a D y F)

Grafo dirigido:
  in-degree(v)  = número de aristas que ENTRAN a v
  out-degree(v) = número de aristas que SALEN de v

      A → B → C
      ↑       ↓
      D ← E ← F

  in-degree(A) = 1 (desde D)    out-degree(A) = 1 (hacia B)
  in-degree(C) = 1 (desde B)    out-degree(C) = 1 (hacia F)
```

## 2.3 Handshaking Lemma

```text
En un grafo no dirigido:

  Σ deg(v) = 2|E|
   v∈V

La suma de todos los grados es exactamente el doble del número de aristas,
porque cada arista contribuye 1 al grado de cada uno de sus extremos.

Consecuencia: el número de vértices con grado impar es SIEMPRE par.
```

---

# 3. Tipos de Grafos

## 3.1 Clasificación principal

### Por dirección

```text
No dirigido (undirected):          Dirigido (directed / digraph):
  A ── B                             A → B
  Arista {A,B} = {B,A}              Arista (A,B) ≠ (B,A)
  Simétrico                          Asimétrico

  Ejemplo: amistades en Facebook     Ejemplo: seguidores en Twitter
```

### Por pesos

```text
Sin peso (unweighted):             Con peso (weighted):
  A ── B                             A ──5── B
  Todas las aristas "valen" 1        Cada arista tiene un costo

  Ejemplo: "¿están conectados?"      Ejemplo: distancia entre ciudades
```

### Por ciclos

```text
Acíclico:                          Cíclico:
  A → B → C                         A → B → C
  (no hay ciclos)                        ↑     ↓
                                         E ← D

  DAG = Directed Acyclic Graph      Puede tener ciclos
  Ejemplo: dependencias de build     Ejemplo: red de carreteras
```

## 3.2 Grafos especiales

```text
┌──────────────────────────┬──────────────────────────────────────┐
│  Tipo                    │  Definición                          │
├──────────────────────────┼──────────────────────────────────────┤
│  Grafo completo (Kₙ)    │  Todos los pares están conectados    │
│                          │  |E| = n(n-1)/2                     │
│  Grafo bipartito         │  V se divide en 2 conjuntos,        │
│                          │  aristas solo entre conjuntos       │
│  Árbol                   │  Grafo conexo acíclico              │
│                          │  |E| = |V| - 1                     │
│  DAG                     │  Dirigido, sin ciclos               │
│  Grafo disperso (sparse) │  |E| << |V|²                       │
│  Grafo denso (dense)     │  |E| ≈ |V|²                        │
│  Grafo planar            │  Se puede dibujar sin cruces        │
└──────────────────────────┴──────────────────────────────────────┘
```

## 3.3 Visualización de tipos

```text
Completo K₄:        Bipartito:         DAG:          Árbol:

  A ── B             A ── D            A → B           A
  |\ /|              |  /|             |   ↓          / \
  | X |              | / |             ↓   D         B   C
  |/ \|              B ── E            C →↗          |
  C ── D             |    |                         D
                     C ── F

  6 aristas          aristas solo       sin ciclos    4 nodos,
  (todo par)         entre {A,B,C}                    3 aristas
                     y {D,E,F}
```

---

# 4. Propiedades Matemáticas

## 4.1 Límites de aristas

```text
Grafo no dirigido simple con n vértices:
  Mínimo de aristas: 0 (grafo sin aristas)
  Máximo de aristas: n(n-1)/2 (grafo completo)

Grafo dirigido simple con n vértices:
  Mínimo de aristas: 0
  Máximo de aristas: n(n-1) (cada par en ambas direcciones)

Ejemplo:
  n = 5 → máximo no dirigido = 5·4/2 = 10
          máximo dirigido = 5·4 = 20
```

## 4.2 Disperso vs Denso

```text
|V| = n,  |E| = m

Disperso (sparse): m = O(n) o m = O(n log n)
  → Lista de adyacencia es mejor
  → La mayoría de grafos reales son dispersos

Denso (dense): m = Θ(n²)
  → Matriz de adyacencia es mejor
  → Grafos completos o casi completos

Ejemplos:
  Red social (n=1M usuarios): m ≈ 150·n = O(n)  → disperso
  Distancias entre ciudades (n=100): m ≈ n²/2    → denso
```

## 4.3 Propiedades de árboles (subconjunto de grafos)

```text
Un grafo G = (V, E) es un árbol si y solo si cumple CUALQUIERA de:
  1. G es conexo y acíclico
  2. G es conexo y |E| = |V| - 1
  3. G es acíclico y |E| = |V| - 1
  4. Existe exactamente un camino entre todo par de vértices

→ Un árbol con n nodos siempre tiene exactamente n-1 aristas.
→ Agregar 1 arista a un árbol crea exactamente 1 ciclo.
→ Quitar 1 arista de un árbol lo desconecta.
```

---

# PARTE II — REPRESENTACIONES

---

# 5. Matriz de Adyacencia

## 5.1 Concepto

Una **matriz de adyacencia** es una matriz cuadrada A de tamaño |V| × |V| donde:

```text
A[i][j] = 1   si existe arista de i a j
A[i][j] = 0   si NO existe arista de i a j

Para grafos con peso:
A[i][j] = peso  si existe arista de i a j
A[i][j] = 0 o ∞ si NO existe arista
```

## 5.2 Ejemplo: Grafo no dirigido

```text
      0 ─── 1
      |   / |
      |  /  |
      | /   |
      2 ─── 3

V = {0, 1, 2, 3}
E = {(0,1), (0,2), (1,2), (1,3), (2,3)}

Matriz de adyacencia:
       0  1  2  3
    ┌─────────────┐
  0 │  0  1  1  0 │
  1 │  1  0  1  1 │
  2 │  1  1  0  1 │
  3 │  0  1  1  0 │
    └─────────────┘

Observaciones:
  • Simétrica (A[i][j] = A[j][i]) porque es no dirigido.
  • Diagonal = 0 (no hay self-loops).
  • Cada 1 representa una arista.
```

## 5.3 Ejemplo: Grafo dirigido

```text
      0 → 1
      ↑   ↓
      3 ← 2

V = {0, 1, 2, 3}
E = {(0,1), (1,2), (2,3), (3,0)}

Matriz:
       0  1  2  3
    ┌─────────────┐
  0 │  0  1  0  0 │      0→1: A[0][1]=1
  1 │  0  0  1  0 │      1→2: A[1][2]=1
  2 │  0  0  0  1 │      2→3: A[2][3]=1
  3 │  1  0  0  0 │      3→0: A[3][0]=1
    └─────────────┘

NO es simétrica (dirigido).
```

## 5.4 Ejemplo: Grafo con pesos

```text
      0 ──4── 1
      |      / |
     2|    3/  |6
      |  /     |
      2 ──5── 3

Matriz de pesos (0 = sin arista, o ∞):
       0    1    2    3
    ┌─────────────────────┐
  0 │  0    4    2    ∞  │
  1 │  4    0    3    6  │
  2 │  2    3    0    5  │
  3 │  ∞    6    5    0  │
    └─────────────────────┘
```

## 5.5 Operaciones con la matriz

```text
¿Existe arista (u,v)?       → A[u][v] != 0           O(1)
Obtener vecinos de v        → Recorrer fila v         O(|V|)
Agregar arista (u,v)        → A[u][v] = 1             O(1)
Eliminar arista (u,v)       → A[u][v] = 0             O(1)
Grado de v (no dirigido)    → Σ A[v][j], j=0..n-1     O(|V|)
Número total de aristas     → Σ A[i][j] / 2           O(|V|²)
```

## 5.6 Ventajas y desventajas

```text
✅ Ventajas:
  • Verificar arista: O(1)
  • Agregar/eliminar arista: O(1)
  • Simplicidad de implementación
  • Buena para grafos densos

❌ Desventajas:
  • Espacio: O(|V|²) SIEMPRE, incluso si hay pocas aristas
  • Iterar vecinos: O(|V|) (hay que recorrer toda la fila)
  • Para grafos dispersos: desperdicio masivo de memoria
  • No escala: 1M vértices → 1 billón de celdas (≈ 4 TB)
```

---

# 6. Lista de Adyacencia

## 6.1 Concepto

Una **lista de adyacencia** es un array de listas. Para cada vértice v, se almacena la lista de sus vecinos (vértices adyacentes).

```text
adj[v] = lista de vecinos de v
```

## 6.2 Ejemplo: Grafo no dirigido

```text
      0 ─── 1
      |   / |
      |  /  |
      | /   |
      2 ─── 3

Lista de adyacencia:
  adj[0] → [1, 2]
  adj[1] → [0, 2, 3]
  adj[2] → [0, 1, 3]
  adj[3] → [1, 2]

Memoria: solo almacena las aristas que EXISTEN.
  Espacio = O(|V| + |E|)  (|V| listas + 2·|E| entradas)
```

## 6.3 Ejemplo: Grafo dirigido

```text
      0 → 1
      ↑   ↓
      3 ← 2

Lista de adyacencia:
  adj[0] → [1]
  adj[1] → [2]
  adj[2] → [3]
  adj[3] → [0]

Cada arista aparece UNA sola vez (la dirección importa).
  Espacio = O(|V| + |E|)
```

## 6.4 Ejemplo: Grafo con pesos

```text
      0 ──4── 1
      |      / |
     2|    3/  |6
      |  /     |
      2 ──5── 3

Lista de adyacencia (con pesos):
  adj[0] → [(1,4), (2,2)]
  adj[1] → [(0,4), (2,3), (3,6)]
  adj[2] → [(0,2), (1,3), (3,5)]
  adj[3] → [(1,6), (2,5)]

Cada entrada es un par (vecino, peso).
```

## 6.5 Implementaciones posibles de la lista

```text
1. Array de linked lists (C clásico):
   adj[v] → nodo → nodo → nodo → NULL

2. Array de arrays dinámicos (C con realloc):
   adj[v] = array dinámico de vecinos

3. Array de arrays estáticos (si se conoce el grado máximo):
   adj[v][0..deg(v)-1] = vecinos

Más común en C: array de linked lists.
```

## 6.6 Operaciones con lista de adyacencia

```text
¿Existe arista (u,v)?       → Recorrer adj[u]         O(deg(u))
Obtener vecinos de v        → Retornar adj[v]          O(deg(v))
Agregar arista (u,v)        → Agregar v a adj[u]       O(1)
Eliminar arista (u,v)       → Buscar y eliminar de adj[u]  O(deg(u))
Grado de v                  → |adj[v]|                 O(1)*
Número total de aristas     → Σ |adj[v]| / 2           O(|V| + |E|)

* O(1) si mantenemos el tamaño de cada lista.
```

---

# 7. Edge List

## 7.1 Concepto

Una **edge list** es simplemente una lista de todas las aristas del grafo:

```text
edges = [(u₁,v₁), (u₂,v₂), ..., (uₘ,vₘ)]
```

## 7.2 Ejemplo

```text
      0 ─── 1
      |   / |
      2 ─── 3

Edge list:
  edges = [(0,1), (0,2), (1,2), (1,3), (2,3)]

Con pesos:
  edges = [(0,1,4), (0,2,2), (1,2,3), (1,3,6), (2,3,5)]
```

## 7.3 ¿Cuándo se usa?

```text
La edge list NO es eficiente para la mayoría de operaciones de grafos.
Pero es MUY útil para:

  • Algoritmo de Kruskal (MST): necesita todas las aristas ordenadas por peso
  • Input/Output: formato natural para leer/escribir grafos
  • Grafos con muy pocas aristas

Operaciones:
  ¿Existe arista (u,v)?    → O(|E|) (recorrido lineal)
  Vecinos de v             → O(|E|) (recorrer todas las aristas)
  Agregar arista           → O(1) (append)
  Espacio                  → O(|E|)
```

---

# 8. Comparación de Representaciones

## 8.1 Tabla comparativa

| Operación              | Matriz Adyacencia | Lista Adyacencia | Edge List   |
| ---------------------- | ----------------- | ---------------- | ----------- |
| Espacio                | O(V²)             | O(V + E)         | O(E)        |
| ¿Existe arista (u,v)?  | **O(1)**          | O(deg(u))        | O(E)        |
| Vecinos de v           | O(V)              | **O(deg(v))**    | O(E)        |
| Agregar arista         | O(1)              | O(1)             | O(1)        |
| Eliminar arista        | O(1)              | O(deg(u))        | O(E)        |
| BFS / DFS              | O(V²)             | **O(V + E)**     | O(V·E)      |
| Buena para             | Grafos densos     | Grafos dispersos | Kruskal     |

## 8.2 ¿Cuál usar?

```text
┌──────────────────────────────────────────────────────────────┐
│  La gran mayoría de grafos reales son DISPERSOS.             │
│  → Usa LISTA DE ADYACENCIA como predeterminada.              │
│                                                              │
│  Excepciones:                                                │
│  • Grafo denso (|E| ≈ |V|²): Matriz de adyacencia           │
│  • Necesitas verificar aristas O(1): Matriz                  │
│  • Algoritmo de Kruskal: Edge list                           │
│  • Floyd-Warshall: Matriz (opera directamente sobre ella)    │
└──────────────────────────────────────────────────────────────┘
```

## 8.3 Ejemplo numérico

```text
Grafo de red social:  n = 1,000,000 usuarios, m = 150·n aristas

Matriz de adyacencia:
  Espacio = n² = 10¹² bits = 125 GB  ← IMPRACTICABLE

Lista de adyacencia:
  Espacio = n + 2m ≈ 301,000,000 entradas ≈ 2.4 GB  ← factible

Grafo completo de 500 ciudades:  n = 500, m = 500·499/2 ≈ 125,000

Matriz de adyacencia:
  Espacio = 500² = 250,000 entradas ≈ 1 MB  ← trivial

Lista de adyacencia:
  Espacio = 500 + 250,000 ≈ 250,500 entradas ≈ 1 MB  ← similar

→ Para grafos pequeños y densos, ambas son similares.
  Para grafos grandes y dispersos, la lista gana por mucho.
```

---

# PARTE III — RECORRIDOS (TRAVERSAL)

---

# 9. Concepto de Recorrido en Grafos

## 9.1 ¿Por qué necesitamos recorridos?

```text
En un array: iterar es trivial (for i = 0 to n-1).
En un árbol: DFS (pre/in/postorder) y BFS (level-order).
En un grafo: ¿Cómo visitar todos los nodos?
  → Puede haber CICLOS (visitaríamos el mismo nodo infinitamente).
  → Puede ser DESCONECTADO (hay nodos inalcanzables).
  → No hay "raíz" obvia desde dónde empezar.

Solución: marcar los nodos como VISITADOS para no repetir.
```

## 9.2 El array de visitados

```text
visited[v] = 1 si ya fue visitado, 0 si no.

Regla fundamental:
  NUNCA proceses un nodo que ya fue visitado.
  → Evita ciclos infinitos.
  → Garantiza que cada nodo se procesa exactamente una vez.
```

## 9.3 Los dos recorridos fundamentales

```text
BFS (Breadth-First Search):
  Usa una QUEUE.
  Explora por NIVELES: primero los vecinos directos,
  luego los vecinos de los vecinos, etc.
  → "Ancho primero"

DFS (Depth-First Search):
  Usa un STACK (o recursión).
  Explora lo más PROFUNDO posible antes de retroceder.
  → "Profundo primero"

Analogía:
  BFS = explorar un mapa expandiéndote como una onda
  DFS = explorar un laberinto siempre girando a la izquierda
```

---

# 10. Breadth-First Search (BFS)

## 10.1 Intuición

```text
BFS explora un grafo nivel por nivel desde un vértice fuente s:
  Nivel 0: s
  Nivel 1: vecinos de s
  Nivel 2: vecinos de vecinos de s (no visitados)
  Nivel 3: ...

Es como lanzar una piedra a un lago: las ondas se expanden uniformemente.
```

## 10.2 Algoritmo

```text
BFS(G, s):
  Crear queue Q
  Marcar s como visitado
  Encolar s en Q

  while Q no está vacía:
    u = desencolar de Q
    procesar(u)

    for cada vecino v de u:
      if v no está visitado:
        marcar v como visitado
        encolar v en Q
```

## 10.3 Ejemplo paso a paso

```text
Grafo:
        0 ─── 1
        |   / |
        |  /  |
        | /   |
        2 ─── 3 ─── 4

Adj:
  0: [1, 2]
  1: [0, 2, 3]
  2: [0, 1, 3]
  3: [1, 2, 4]
  4: [3]

BFS desde 0:

Estado inicial:
  Queue: [0]
  Visited: {0}
  Orden: —

Paso 1: Desencolar 0. Vecinos: 1(no vis), 2(no vis)
  Queue: [1, 2]
  Visited: {0, 1, 2}
  Orden: 0

Paso 2: Desencolar 1. Vecinos: 0(vis), 2(vis), 3(no vis)
  Queue: [2, 3]
  Visited: {0, 1, 2, 3}
  Orden: 0, 1

Paso 3: Desencolar 2. Vecinos: 0(vis), 1(vis), 3(vis)
  Queue: [3]
  Visited: {0, 1, 2, 3}
  Orden: 0, 1, 2

Paso 4: Desencolar 3. Vecinos: 1(vis), 2(vis), 4(no vis)
  Queue: [4]
  Visited: {0, 1, 2, 3, 4}
  Orden: 0, 1, 2, 3

Paso 5: Desencolar 4. Vecinos: 3(vis)
  Queue: []
  Visited: {0, 1, 2, 3, 4}
  Orden: 0, 1, 2, 3, 4

BFS completo: 0 → 1 → 2 → 3 → 4

Niveles:
  Nivel 0: {0}
  Nivel 1: {1, 2}
  Nivel 2: {3}
  Nivel 3: {4}
```

## 10.4 BFS Tree y distancias

```text
BFS produce un ÁRBOL de recorrido (BFS tree) y las DISTANCIAS
desde el vértice fuente:

BFS Tree:                    Distancias:
      0                        dist[0] = 0
     / \                       dist[1] = 1
    1   2                      dist[2] = 1
    |                          dist[3] = 2
    3                          dist[4] = 3
    |
    4

→ dist[v] = nivel de v en el BFS = camino más corto (en # aristas)
  desde s hasta v.
```

## 10.5 Complejidad

```text
Cada vértice se encola y desencola exactamente UNA vez → O(|V|)
Para cada vértice, se recorren todos sus vecinos → total O(|E|)

Total:
  Con lista de adyacencia: O(|V| + |E|)
  Con matriz de adyacencia: O(|V|²)  (recorrer fila completa por vértice)
```

---

# 11. Depth-First Search (DFS)

## 11.1 Intuición

```text
DFS explora lo más PROFUNDO posible desde un vértice antes de retroceder:
  1. Ir al primer vecino no visitado
  2. Repetir recursivamente desde ese vecino
  3. Cuando no hay más vecinos no visitados, RETROCEDER (backtrack)
  4. Intentar el siguiente vecino no visitado

Es como explorar un laberinto: siempre giras en una dirección
hasta llegar a un callejón sin salida, luego retrocedes.
```

## 11.2 Algoritmo (recursivo)

```text
DFS(G, s):
  Marcar s como visitado
  procesar(s)

  for cada vecino v de s:
    if v no está visitado:
      DFS(G, v)
```

## 11.3 Algoritmo (iterativo con stack)

```text
DFS_Iterative(G, s):
  Crear stack S
  Push s en S

  while S no está vacío:
    u = pop de S
    if u no está visitado:
      marcar u como visitado
      procesar(u)

      for cada vecino v de u (en orden inverso para consistencia):
        if v no está visitado:
          push v en S
```

> **Nota:** La versión iterativa puede dar un orden diferente que la recursiva
> dependiendo del orden de push. La recursiva es más natural y usada.

## 11.4 Ejemplo paso a paso

```text
Mismo grafo:
        0 ─── 1
        |   / |
        |  /  |
        | /   |
        2 ─── 3 ─── 4

DFS recursivo desde 0 (vecinos procesados en orden numérico):

DFS(0):
  Visitar 0. Vecinos: 1(no vis), 2(no vis)
  → DFS(1):
      Visitar 1. Vecinos: 0(vis), 2(no vis), 3(no vis)
      → DFS(2):
          Visitar 2. Vecinos: 0(vis), 1(vis), 3(no vis)
          → DFS(3):
              Visitar 3. Vecinos: 1(vis), 2(vis), 4(no vis)
              → DFS(4):
                  Visitar 4. Vecinos: 3(vis)
                  ← backtrack
              ← backtrack
          ← backtrack
      ← backtrack
  ← backtrack

DFS completo: 0 → 1 → 2 → 3 → 4

DFS Tree:
  0 → 1 → 2 → 3 → 4  (un camino, porque siempre fue al primer no visitado)
```

## 11.5 Timestamps (Discovery y Finish)

```text
DFS puede registrar dos tiempos para cada vértice:
  d[v] = tiempo de DESCUBRIMIENTO (cuando se empieza a procesar v)
  f[v] = tiempo de FINALIZACIÓN (cuando se termina de procesar v)

DFS con timestamps:
  time = 0

  DFS(v):
    time++; d[v] = time
    marcar v como visitado

    for cada vecino u de v:
      if u no visitado:
        DFS(u)

    time++; f[v] = time

Para el ejemplo anterior:
  Vértice:  0    1    2    3    4
  d[]:      1    2    3    4    5
  f[]:      10   9    8    7    6

Propiedad del paréntesis:
  Para dos vértices u, v:
    • [d[u], f[u]] y [d[v], f[v]] son disjuntos, o
    • uno contiene completamente al otro.
  → Nunca se solapan parcialmente.
```

## 11.6 Clasificación de aristas (DFS)

```text
DFS clasifica las aristas del grafo en 4 tipos:

Arista          │  Descripción                  │  Detección
────────────────┼───────────────────────────────┼─────────────────────
Tree edge       │  Arista del DFS tree          │  v no visitado
Back edge       │  Hacia un ancestro            │  v visitado, f[v]=0
Forward edge    │  Hacia un descendiente        │  v visitado, d[v]>d[u]
Cross edge      │  Todo lo demás                │  v visitado, f[v]>0

Importante:
  • Back edge → indica un CICLO en el grafo.
  • En grafos NO dirigidos, solo hay tree edges y back edges.
  • Forward y cross edges solo aparecen en grafos DIRIGIDOS.
```

## 11.7 Complejidad

```text
Igual que BFS:
  Con lista de adyacencia: O(|V| + |E|)
  Con matriz de adyacencia: O(|V|²)

DFS recursivo también usa O(|V|) espacio en el call stack.
DFS iterativo usa O(|V|) en el stack explícito.
```

---

# 12. BFS vs DFS

## 12.1 Tabla comparativa

| Aspecto                    | BFS                          | DFS                          |
| -------------------------- | ---------------------------- | ---------------------------- |
| Estructura de datos        | Queue (FIFO)                 | Stack (LIFO) / recursión     |
| Exploración                | Por niveles (ancho)          | Lo más profundo primero      |
| Camino más corto (sin peso)| ✓ (garantizado)              | ✗ (no garantizado)           |
| Distancias                 | Calcula dist[v] correcto     | No calcula distancias        |
| Detección de ciclos        | Posible pero menos natural   | Natural (back edges)         |
| Topological sort           | ✗ (usar Kahn con in-degree)  | ✓ (orden de finalización)    |
| Componentes conexas        | ✓                            | ✓                            |
| Espacio (peor caso)        | O(|V|) en la queue           | O(|V|) en el stack/recursión |
| Complejidad                | O(|V| + |E|)                 | O(|V| + |E|)                 |

## 12.2 ¿Cuándo usar cada uno?

```text
Usar BFS:
  ✓ Camino más corto en grafo sin pesos
  ✓ Exploración nivel por nivel
  ✓ Encontrar todos los nodos a distancia K
  ✓ Redes sociales (grados de separación)
  ✓ Web crawling (explorar páginas por profundidad de enlace)

Usar DFS:
  ✓ Detección de ciclos
  ✓ Ordenamiento topológico
  ✓ Componentes fuertemente conexas
  ✓ Resolver laberintos/puzzles
  ✓ Generar todas las combinaciones/permutaciones (backtracking)
  ✓ Verificar si un grafo es bipartito (cualquiera sirve)
```

## 12.3 Visualización comparativa

```text
Grafo:
        0 ─── 1 ─── 2
        |           |
        3 ─── 4 ─── 5

BFS desde 0:
  Cola: [0] → [1,3] → [3,2] → [2,4] → [4,5] → [5] → []
  Orden: 0, 1, 3, 2, 4, 5

  Exploración como onda:
    0 ← nivel 0
    1, 3 ← nivel 1
    2, 4 ← nivel 2
    5 ← nivel 3

DFS desde 0 (recursivo, vecinos en orden):
  Stack implícito: 0 → 1 → 2 → 5 → 4 → 3
  Orden: 0, 1, 2, 5, 4, 3

  Exploración como penetración:
    0 → 1 → 2 → 5 → backtrack → 4 → backtrack → 3
```

---

# PARTE IV — APLICACIONES DE BFS Y DFS

---

# 13. Camino Más Corto (BFS, sin pesos)

## 13.1 Teorema

```text
En un grafo NO ponderado, BFS desde un vértice s produce las
DISTANCIAS MÁS CORTAS (en número de aristas) desde s a todos
los demás vértices.

→ dist[v] = número mínimo de aristas para ir de s a v.
→ Si v no es alcanzable desde s, dist[v] = ∞.
```

## 13.2 Algoritmo con reconstrucción de camino

```text
BFS_ShortestPath(G, s):
  dist[] = ∞ para todos los vértices
  parent[] = -1 para todos
  dist[s] = 0

  Queue Q
  encolar s

  while Q no vacía:
    u = desencolar
    for cada vecino v de u:
      if dist[v] == ∞:          // no visitado
        dist[v] = dist[u] + 1
        parent[v] = u
        encolar v

Para reconstruir el camino de s a t:
  path = []
  v = t
  while v != -1:
    path.prepend(v)
    v = parent[v]
  // path contiene el camino más corto de s a t
```

## 13.3 Ejemplo

```text
Grafo:
        0 ─── 1 ─── 2
        |           |
        3 ─── 4 ─── 5

BFS desde 0:
  dist[0]=0, dist[1]=1, dist[3]=1
  dist[2]=2, dist[4]=2
  dist[5]=3

  parent[0]=-1, parent[1]=0, parent[3]=0
  parent[2]=1, parent[4]=3, parent[5]=2 (o 4, depende del orden)

Camino más corto de 0 a 5:
  5 ← parent[5]=2 ← parent[2]=1 ← parent[1]=0
  Camino: 0 → 1 → 2 → 5  (longitud 3)
```

---

# 14. Detección de Ciclos

## 14.1 En grafos no dirigidos (DFS)

```text
Un grafo no dirigido tiene un ciclo si y solo si DFS encuentra
una arista hacia un vértice YA VISITADO que NO es su padre.

DetectCycle_Undirected(G):
  for cada vértice v no visitado:
    if DFS_Cycle(v, -1):        // -1 = sin padre
      return "Ciclo detectado"
  return "No hay ciclos"

DFS_Cycle(v, parent):
  marcar v como visitado
  for cada vecino u de v:
    if u no visitado:
      if DFS_Cycle(u, v):
        return true
    elif u != parent:           // visitado Y no es el padre
      return true               // → back edge → CICLO
  return false
```

## 14.2 En grafos dirigidos (DFS con colores)

```text
En un grafo dirigido, usamos 3 colores:
  WHITE: no visitado
  GRAY:  en el stack de recursión (siendo procesado)
  BLACK: completamente procesado

Un ciclo existe si encontramos una arista hacia un nodo GRAY.

DetectCycle_Directed(G):
  color[] = WHITE para todos

  for cada vértice v:
    if color[v] == WHITE:
      if DFS_Directed(v):
        return "Ciclo detectado"
  return "No hay ciclos"

DFS_Directed(v):
  color[v] = GRAY
  for cada vecino u de v:
    if color[u] == GRAY:        // back edge → CICLO
      return true
    if color[u] == WHITE:
      if DFS_Directed(u):
        return true
  color[v] = BLACK
  return false
```

## 14.3 Ejemplo

```text
Grafo dirigido:
    A → B → C
    ↑       ↓
    E ← D ←─┘

DFS desde A:
  A(GRAY) → B(GRAY) → C(GRAY) → D(GRAY) → E(GRAY) → A?
  E tiene vecino A, pero A es GRAY → CICLO DETECTADO.

Ciclo: A → B → C → D → E → A

Grafo dirigido sin ciclo (DAG):
    A → B → C
        ↓   ↓
        D → E

DFS: A(G)→B(G)→D(G)→E(G)→E(B)→D(B)→C(G)→E(B,ya BLACK)→C(B)→B(B)→A(B)
  Nunca se encuentra un nodo GRAY → No hay ciclo ✓ → Es un DAG.
```

---

# 15. Componentes Conexas

## 15.1 En grafos no dirigidos

```text
Una componente conexa es un subconjunto maximal de vértices
donde todos están conectados entre sí.

Algoritmo:
  component = 0
  for cada vértice v no visitado:
    BFS(v) o DFS(v)               // marca todos los alcanzables
    component++

  → Número de veces que inicias un nuevo BFS/DFS = número de componentes.
```

## 15.2 Ejemplo

```text
Grafo:
    0 ─ 1    3 ─ 4    6
    |   |    |
    2   5    7

Componente 1: {0, 1, 2, 5}  (BFS/DFS desde 0 los alcanza todos)
Componente 2: {3, 4, 7}     (BFS/DFS desde 3)
Componente 3: {6}           (BFS/DFS desde 6, solo)

→ 3 componentes conexas.
```

## 15.3 En grafos dirigidos: Componentes Fuertemente Conexas (SCC)

```text
En un digrafo, una Componente Fuertemente Conexa (SCC) es un
subconjunto maximal donde para todo par u,v hay camino de u a v
Y de v a u.

Algoritmos:
  • Kosaraju (2 DFS)
  • Tarjan (1 DFS con stack y lowlinks)

Ejemplo:
    A → B → C
    ↑       ↓
    E ← D ←─┘

    F → G
    ↑   ↓
    H ←─┘

  SCC 1: {A, B, C, D, E} (ciclo completo)
  SCC 2: {F, G, H}       (ciclo completo)
```

---

# 16. Ordenamiento Topológico

## 16.1 Definición

```text
Un ordenamiento topológico de un DAG (Directed Acyclic Graph) es
una secuencia lineal de todos los vértices tal que:
  Si existe arista u → v, entonces u aparece ANTES que v en la secuencia.

Requisitos:
  → Solo existe para DAGs (no puede haber ciclos).
  → Puede no ser único (múltiples órdenes válidos).
```

## 16.2 Aplicación: orden de compilación

```text
Dependencias de módulos:
    main → parser → lexer
    main → codegen → optimizer
    codegen → parser

DAG:
    main → parser → lexer
      ↓       ↑
    codegen ──┘
      ↓
    optimizer

Orden topológico (uno posible):
  lexer, parser, optimizer, codegen, main

→ Si compilamos en este orden, cada módulo se compila
  DESPUÉS de todos sus dependencias.
```

## 16.3 Método 1: DFS (orden de finalización inverso)

```text
TopologicalSort_DFS(G):
  stack S
  visited[] = false

  for cada vértice v:
    if not visited[v]:
      DFS_Topo(v, S)

  // S contiene el orden topológico (pop en orden)

DFS_Topo(v, S):
  visited[v] = true
  for cada vecino u de v:
    if not visited[u]:
      DFS_Topo(u, S)
  push v en S                    // push DESPUÉS de procesar todos los vecinos
```

## 16.4 Método 2: Kahn's Algorithm (BFS con in-degree)

```text
TopologicalSort_Kahn(G):
  Calcular in-degree[v] para todos los vértices
  Queue Q
  for cada v con in-degree[v] == 0:
    encolar v

  result = []
  while Q no vacía:
    u = desencolar
    result.append(u)
    for cada vecino v de u:
      in-degree[v]--
      if in-degree[v] == 0:
        encolar v

  if |result| < |V|:
    ERROR: el grafo tiene un ciclo
  return result
```

## 16.5 Ejemplo paso a paso (Kahn)

```text
DAG:
    5 → 0    4 → 0    4 → 1
    2 → 3    3 → 1    5 → 2

In-degrees:
  0: 2 (de 5 y 4)
  1: 2 (de 4 y 3)
  2: 1 (de 5)
  3: 1 (de 2)
  4: 0
  5: 0

Paso 1: in-degree 0: {4, 5} → encolar
  Q: [4, 5], result: []

Paso 2: Desencolar 4. Vecinos: 0, 1
  in-degree[0]-- = 1, in-degree[1]-- = 1
  Q: [5], result: [4]

Paso 3: Desencolar 5. Vecinos: 0, 2
  in-degree[0]-- = 0 → encolar 0
  in-degree[2]-- = 0 → encolar 2
  Q: [0, 2], result: [4, 5]

Paso 4: Desencolar 0. Sin vecinos salientes.
  Q: [2], result: [4, 5, 0]

Paso 5: Desencolar 2. Vecinos: 3
  in-degree[3]-- = 0 → encolar 3
  Q: [3], result: [4, 5, 0, 2]

Paso 6: Desencolar 3. Vecinos: 1
  in-degree[1]-- = 0 → encolar 1
  Q: [1], result: [4, 5, 0, 2, 3]

Paso 7: Desencolar 1. Sin vecinos salientes.
  Q: [], result: [4, 5, 0, 2, 3, 1]

Orden topológico: 4, 5, 0, 2, 3, 1  ✓
|result| = 6 = |V| → sin ciclos ✓
```

---

# PARTE V — GRAFOS CON PESOS: ALGORITMOS CLÁSICOS

---

# 17. Dijkstra (Camino Más Corto con Pesos)

## 17.1 Problema

```text
Dado un grafo con pesos NO NEGATIVOS y un vértice fuente s,
encontrar el camino más corto (peso total mínimo) desde s
hasta todos los demás vértices.
```

## 17.2 Idea del algoritmo

```text
Dijkstra es un BFS "greedy" que, en lugar de procesar nodos
por nivel, los procesa por DISTANCIA (de menor a mayor).

Usa una priority queue (min-heap) para siempre procesar
el nodo no visitado con la menor distancia conocida.

Intuición:
  "Si ya conozco la distancia más corta a u, y u tiene una arista
  a v con peso w, entonces puedo llegar a v en dist[u] + w.
  Si eso es mejor que lo que ya sabía de v, actualizo."
```

## 17.3 Algoritmo

```text
Dijkstra(G, s):
  dist[] = ∞ para todos
  dist[s] = 0
  parent[] = -1 para todos
  visited[] = false

  PQ = min-heap vacío
  PQ.insert(s, 0)

  while PQ no vacía:
    (u, d) = PQ.extractMin()

    if visited[u]: continue
    visited[u] = true

    for cada vecino (v, weight) de u:
      if dist[u] + weight < dist[v]:
        dist[v] = dist[u] + weight
        parent[v] = u
        PQ.insert(v, dist[v])

  return dist[], parent[]
```

## 17.4 Ejemplo paso a paso

```text
Grafo con pesos:

        0 ──4── 1
        |      /|
       2|    3/ |6
        |  /   |
        2 ──5── 3

Adj con pesos:
  0: [(1,4), (2,2)]
  1: [(0,4), (2,3), (3,6)]
  2: [(0,2), (1,3), (3,5)]
  3: [(1,6), (2,5)]

Dijkstra desde 0:

Inicial:
  dist = [0, ∞, ∞, ∞]
  PQ: [(0, 0)]

Paso 1: ExtractMin → (0, dist=0). Vecinos: 1(w=4), 2(w=2)
  dist[1] = min(∞, 0+4) = 4. PQ.insert(1, 4)
  dist[2] = min(∞, 0+2) = 2. PQ.insert(2, 2)
  dist = [0, 4, 2, ∞]
  PQ: [(2, 2), (1, 4)]

Paso 2: ExtractMin → (2, dist=2). Vecinos: 0(vis), 1(w=3), 3(w=5)
  dist[1] = min(4, 2+3) = 5 → no mejora (4 < 5)
  dist[3] = min(∞, 2+5) = 7. PQ.insert(3, 7)
  dist = [0, 4, 2, 7]
  PQ: [(1, 4), (3, 7)]

Paso 3: ExtractMin → (1, dist=4). Vecinos: 0(vis), 2(vis), 3(w=6)
  dist[3] = min(7, 4+6) = 10 → no mejora (7 < 10)
  dist = [0, 4, 2, 7]
  PQ: [(3, 7)]

Paso 4: ExtractMin → (3, dist=7). Vecinos: 1(vis), 2(vis)
  dist = [0, 4, 2, 7]
  PQ: []

Resultado:
  dist[0] = 0
  dist[1] = 4  (camino: 0→1)
  dist[2] = 2  (camino: 0→2)
  dist[3] = 7  (camino: 0→2→3)
```

## 17.5 Complejidad

```text
Con min-heap binario:
  ExtractMin: O(log V) × V veces = O(V log V)
  Insert/DecreaseKey: O(log V) × E veces = O(E log V)
  Total: O((V + E) log V)

Con Fibonacci Heap:
  Total: O(V log V + E)  (óptimo para grafos dispersos)

Con array simple (sin heap):
  O(V²)  (bueno para grafos densos)

IMPORTANTE: Dijkstra NO funciona con pesos negativos.
  Si hay pesos negativos → usar Bellman-Ford.
```

## 17.6 ¿Por qué no funciona con pesos negativos?

```text
Dijkstra asume que una vez procesado un nodo, su distancia es definitiva.
Con pesos negativos, podría encontrarse un camino MÁS CORTO después:

Ejemplo:
    A ──1── B ──(-10)── C
    A ──5── C

  Dijkstra desde A:
    Procesa A: dist[B]=1, dist[C]=5
    Procesa B: dist[C] = min(5, 1+(-10)) = -9 → ¡pero C ya fue "finalizado"!

→ Dijkstra diría dist[C]=5, pero el real es -9.
→ Usar Bellman-Ford para pesos negativos.
```

---

# 18. Bellman-Ford

## 18.1 Idea

```text
Bellman-Ford resuelve el mismo problema que Dijkstra
(camino más corto desde una fuente) pero:
  ✓ Funciona con pesos NEGATIVOS
  ✓ Detecta ciclos negativos
  ✗ Más lento que Dijkstra: O(V·E) vs O((V+E) log V)
```

## 18.2 Algoritmo

```text
BellmanFord(G, s):
  dist[] = ∞ para todos
  dist[s] = 0
  parent[] = -1

  // Relajar TODAS las aristas, V-1 veces
  for i = 1 to |V| - 1:
    for cada arista (u, v, w) en G:
      if dist[u] + w < dist[v]:
        dist[v] = dist[u] + w
        parent[v] = u

  // Verificar ciclos negativos
  for cada arista (u, v, w) en G:
    if dist[u] + w < dist[v]:
      return "Ciclo negativo detectado"

  return dist[], parent[]
```

## 18.3 ¿Por qué V-1 iteraciones?

```text
El camino más corto entre dos vértices tiene como máximo V-1 aristas
(sin ciclos). Cada iteración "extiende" los caminos más cortos en 1 arista.

Iteración 1: Caminos correctos de longitud 1
Iteración 2: Caminos correctos de longitud ≤ 2
...
Iteración V-1: Caminos correctos de longitud ≤ V-1 = todos

Si después de V-1 iteraciones todavía se puede mejorar alguna distancia,
significa que hay un ciclo negativo (un camino que mejora infinitamente).
```

## 18.4 Ejemplo breve

```text
    A ──6── B
    |       |
   7|      -3|
    |       |
    C ──5── D

    C ──(-2)── E

Bellman-Ford desde A:
  Iteración 1: dist[B]=6, dist[C]=7
  Iteración 2: dist[D]=min(∞, 6+(-3))=3, dist[E]=min(∞, 7+(-2))=5
  Iteración 3: dist[D]=min(3, 7+5)=3 (no cambia)
  ...

dist = [0, 6, 7, 3, 5]
```

## 18.5 Complejidad

```text
Tiempo: O(V · E)  — V-1 iteraciones sobre todas las aristas
Espacio: O(V)
```

---

# 19. Prim (Minimum Spanning Tree)

## 19.1 Problema del MST

```text
Dado un grafo conexo con pesos, encontrar un subconjunto de aristas
que conecte TODOS los vértices con el peso total MÍNIMO.
Este subconjunto forma un ÁRBOL (spanning tree).

Propiedades del MST:
  • Tiene exactamente V-1 aristas
  • Es un árbol (conexo, acíclico)
  • Peso total es mínimo entre todos los spanning trees
```

## 19.2 Algoritmo de Prim

```text
Prim es similar a Dijkstra: crece el MST desde un vértice
usando una priority queue, eligiendo siempre la arista más barata
que conecta un vértice del MST con uno fuera del MST.

Prim(G, s):
  key[] = ∞ para todos        // "costo" de agregar v al MST
  key[s] = 0
  inMST[] = false
  parent[] = -1

  PQ = min-heap con todos los vértices

  while PQ no vacía:
    u = PQ.extractMin()
    inMST[u] = true

    for cada vecino (v, weight) de u:
      if not inMST[v] and weight < key[v]:
        key[v] = weight
        parent[v] = u
        PQ.decreaseKey(v, weight)

  MST = aristas definidas por parent[]
```

## 19.3 Ejemplo

```text
        0 ──4── 1
        |      /|
       2|    3/ |6
        |  /   |
        2 ──5── 3

Prim desde 0:
  key = [0, ∞, ∞, ∞]

  Extract 0. Vecinos: 1(w=4), 2(w=2)
    key[1] = 4, key[2] = 2
    key = [0, 4, 2, ∞]

  Extract 2 (key=2). Vecinos: 0(MST), 1(w=3), 3(w=5)
    key[1] = min(4, 3) = 3, parent[1]=2
    key[3] = 5, parent[3]=2
    key = [0, 3, 2, 5]

  Extract 1 (key=3). Vecinos: 0(MST), 2(MST), 3(w=6)
    key[3] = min(5, 6) = 5 (no mejora)
    key = [0, 3, 2, 5]

  Extract 3 (key=5). Todos en MST.

MST edges: (0,2,w=2), (2,1,w=3), (2,3,w=5)
Peso total: 2 + 3 + 5 = 10

MST:
  0 ──2── 2 ──3── 1
           |
           5
           |
           3
```

## 19.4 Complejidad

```text
Con min-heap binario: O((V + E) log V)  — igual que Dijkstra
Con Fibonacci Heap:   O(E + V log V)
Con array simple:     O(V²) — bueno para grafos densos
```

---

# 20. Kruskal (Minimum Spanning Tree)

## 20.1 Idea

```text
Kruskal toma un enfoque diferente a Prim:
  1. Ordenar TODAS las aristas por peso (de menor a mayor)
  2. Para cada arista (en orden):
     Si no crea un ciclo → agregarla al MST
     Si crea un ciclo → descartarla
  3. Repetir hasta tener V-1 aristas

La detección de ciclos se hace eficientemente con Union-Find.
```

## 20.2 Union-Find (Disjoint Set Union)

```text
Union-Find es una estructura que mantiene conjuntos disjuntos
y soporta:
  Find(x):    ¿A qué conjunto pertenece x?       O(α(n)) ≈ O(1)
  Union(x,y): Fusionar los conjuntos de x e y    O(α(n)) ≈ O(1)

α(n) = inversa de la función de Ackermann ≈ constante para todo n práctico.

Uso en Kruskal:
  Cada vértice empieza en su propio conjunto.
  Para una arista (u,v):
    Si Find(u) == Find(v) → están en el mismo conjunto → ciclo → descartar
    Si Find(u) != Find(v) → Union(u,v) → agregar arista al MST
```

## 20.3 Algoritmo

```text
Kruskal(G):
  Ordenar aristas por peso
  MST = []
  DSU = Union-Find con V conjuntos

  for cada arista (u, v, w) en orden de peso:
    if Find(u) != Find(v):
      MST.append((u, v, w))
      Union(u, v)
    if |MST| == V - 1:
      break

  return MST
```

## 20.4 Ejemplo

```text
Aristas ordenadas por peso:
  (0,2,2), (1,2,3), (0,1,4), (2,3,5), (1,3,6)

Paso 1: (0,2,2). Find(0)≠Find(2) → agregar. Union(0,2).
  MST = [(0,2,2)]    Conjuntos: {0,2}, {1}, {3}

Paso 2: (1,2,3). Find(1)≠Find(2) → agregar. Union(1,2).
  MST = [(0,2,2), (1,2,3)]    Conjuntos: {0,1,2}, {3}

Paso 3: (0,1,4). Find(0)==Find(1) → CICLO → descartar.

Paso 4: (2,3,5). Find(2)≠Find(3) → agregar. Union(2,3).
  MST = [(0,2,2), (1,2,3), (2,3,5)]    Conjuntos: {0,1,2,3}

|MST| = 3 = V-1 → DONE.
Peso total: 2 + 3 + 5 = 10 (mismo que Prim) ✓
```

## 20.5 Prim vs Kruskal

| Aspecto                | Prim                        | Kruskal                    |
| ---------------------- | --------------------------- | -------------------------- |
| Enfoque                | Crece desde un vértice      | Ordena aristas globalmente |
| Estructura auxiliar    | Priority Queue              | Union-Find                 |
| Mejor para             | Grafos densos               | Grafos dispersos           |
| Complejidad (heap)     | O((V+E) log V)              | O(E log E)                 |
| Necesita grafo conexo  | Sí                          | Produce forest si desconexo|

---

# PARTE VI — IMPLEMENTACIÓN COMPLETA

---

# 21. Implementación: Matriz de Adyacencia

```c
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

// ═══════════════════════════════════════════════
//  GRAFO CON MATRIZ DE ADYACENCIA
// ═══════════════════════════════════════════════

#define MAX_VERTICES 100
#define INF INT_MAX

typedef struct {
    int adj[MAX_VERTICES][MAX_VERTICES];
    int numVertices;
    int isDirected;
    int isWeighted;
} GraphMatrix;

// ─────── Crear grafo ───────
GraphMatrix* createGraphMatrix(int vertices, int directed, int weighted) {
    GraphMatrix *g = (GraphMatrix*)malloc(sizeof(GraphMatrix));
    g->numVertices = vertices;
    g->isDirected = directed;
    g->isWeighted = weighted;

    for (int i = 0; i < vertices; i++)
        for (int j = 0; j < vertices; j++)
            g->adj[i][j] = 0;

    return g;
}

// ─────── Agregar arista ───────
void addEdgeMatrix(GraphMatrix *g, int u, int v, int weight) {
    if (u < 0 || u >= g->numVertices || v < 0 || v >= g->numVertices) {
        printf("Error: vértice fuera de rango.\n");
        return;
    }

    g->adj[u][v] = g->isWeighted ? weight : 1;
    if (!g->isDirected) {
        g->adj[v][u] = g->isWeighted ? weight : 1;
    }
}

// ─────── Eliminar arista ───────
void removeEdgeMatrix(GraphMatrix *g, int u, int v) {
    g->adj[u][v] = 0;
    if (!g->isDirected) {
        g->adj[v][u] = 0;
    }
}

// ─────── ¿Existe arista? ───────
int hasEdgeMatrix(GraphMatrix *g, int u, int v) {
    return g->adj[u][v] != 0;
}

// ─────── Grado de un vértice ───────
int degreeMatrix(GraphMatrix *g, int v) {
    int deg = 0;
    for (int i = 0; i < g->numVertices; i++) {
        if (g->adj[v][i] != 0) deg++;
    }
    return deg;
}

// ─────── Imprimir matriz ───────
void printMatrix(GraphMatrix *g) {
    printf("    ");
    for (int j = 0; j < g->numVertices; j++)
        printf("%4d", j);
    printf("\n    ");
    for (int j = 0; j < g->numVertices; j++)
        printf("----");
    printf("\n");

    for (int i = 0; i < g->numVertices; i++) {
        printf("%2d |", i);
        for (int j = 0; j < g->numVertices; j++) {
            printf("%4d", g->adj[i][j]);
        }
        printf("\n");
    }
}
```

---

# 22. Implementación: Lista de Adyacencia

```c
// ═══════════════════════════════════════════════
//  GRAFO CON LISTA DE ADYACENCIA
// ═══════════════════════════════════════════════

// ─────── Nodo de la lista ───────
typedef struct AdjNode {
    int dest;
    int weight;
    struct AdjNode *next;
} AdjNode;

// ─────── Lista de adyacencia ───────
typedef struct {
    AdjNode *head;
} AdjList;

// ─────── Grafo ───────
typedef struct {
    AdjList *array;
    int numVertices;
    int numEdges;
    int isDirected;
} GraphList;

// ─────── Crear nodo ───────
AdjNode* createAdjNode(int dest, int weight) {
    AdjNode *node = (AdjNode*)malloc(sizeof(AdjNode));
    node->dest = dest;
    node->weight = weight;
    node->next = NULL;
    return node;
}

// ─────── Crear grafo ───────
GraphList* createGraphList(int vertices, int directed) {
    GraphList *g = (GraphList*)malloc(sizeof(GraphList));
    g->numVertices = vertices;
    g->numEdges = 0;
    g->isDirected = directed;

    g->array = (AdjList*)malloc(vertices * sizeof(AdjList));
    for (int i = 0; i < vertices; i++) {
        g->array[i].head = NULL;
    }

    return g;
}

// ─────── Agregar arista ───────
void addEdgeList(GraphList *g, int u, int v, int weight) {
    if (u < 0 || u >= g->numVertices || v < 0 || v >= g->numVertices) {
        printf("Error: vértice fuera de rango.\n");
        return;
    }

    // u → v
    AdjNode *node = createAdjNode(v, weight);
    node->next = g->array[u].head;
    g->array[u].head = node;

    // v → u (si no dirigido)
    if (!g->isDirected) {
        node = createAdjNode(u, weight);
        node->next = g->array[v].head;
        g->array[v].head = node;
    }

    g->numEdges++;
}

// ─────── ¿Existe arista? ───────
int hasEdgeList(GraphList *g, int u, int v) {
    AdjNode *curr = g->array[u].head;
    while (curr) {
        if (curr->dest == v) return 1;
        curr = curr->next;
    }
    return 0;
}

// ─────── Imprimir grafo ───────
void printGraphList(GraphList *g) {
    for (int i = 0; i < g->numVertices; i++) {
        printf("  %d → ", i);
        AdjNode *curr = g->array[i].head;
        while (curr) {
            printf("[%d, w=%d]", curr->dest, curr->weight);
            if (curr->next) printf(" → ");
            curr = curr->next;
        }
        printf("\n");
    }
}

// ─────── Liberar grafo ───────
void freeGraphList(GraphList *g) {
    for (int i = 0; i < g->numVertices; i++) {
        AdjNode *curr = g->array[i].head;
        while (curr) {
            AdjNode *temp = curr;
            curr = curr->next;
            free(temp);
        }
    }
    free(g->array);
    free(g);
}
```

---

# 23. Implementación: BFS y DFS

```c
// ═══════════════════════════════════════════════
//  BFS Y DFS
// ═══════════════════════════════════════════════

// ─────── Queue simple para BFS ───────
#define MAX_QUEUE 1000

typedef struct {
    int data[MAX_QUEUE];
    int front, rear;
} Queue;

void initQueue(Queue *q) { q->front = 0; q->rear = 0; }
int isEmptyQueue(Queue *q) { return q->front == q->rear; }
void enqueue(Queue *q, int val) { q->data[q->rear++] = val; }
int dequeue(Queue *q) { return q->data[q->front++]; }

// ─────── BFS ───────
void BFS(GraphList *g, int source) {
    int *visited = (int*)calloc(g->numVertices, sizeof(int));
    int *dist = (int*)malloc(g->numVertices * sizeof(int));
    int *parent = (int*)malloc(g->numVertices * sizeof(int));

    for (int i = 0; i < g->numVertices; i++) {
        dist[i] = -1;
        parent[i] = -1;
    }

    Queue q;
    initQueue(&q);

    visited[source] = 1;
    dist[source] = 0;
    enqueue(&q, source);

    printf("BFS desde %d: ", source);

    while (!isEmptyQueue(&q)) {
        int u = dequeue(&q);
        printf("%d ", u);

        AdjNode *curr = g->array[u].head;
        while (curr) {
            int v = curr->dest;
            if (!visited[v]) {
                visited[v] = 1;
                dist[v] = dist[u] + 1;
                parent[v] = u;
                enqueue(&q, v);
            }
            curr = curr->next;
        }
    }
    printf("\n");

    // Imprimir distancias
    printf("Distancias desde %d:\n", source);
    for (int i = 0; i < g->numVertices; i++) {
        printf("  dist[%d] = %d\n", i, dist[i]);
    }

    free(visited);
    free(dist);
    free(parent);
}

// ─────── DFS recursivo ───────
void DFS_Visit(GraphList *g, int u, int *visited, int *order, int *idx) {
    visited[u] = 1;
    order[(*idx)++] = u;

    AdjNode *curr = g->array[u].head;
    while (curr) {
        if (!visited[curr->dest]) {
            DFS_Visit(g, curr->dest, visited, order, idx);
        }
        curr = curr->next;
    }
}

void DFS(GraphList *g, int source) {
    int *visited = (int*)calloc(g->numVertices, sizeof(int));
    int *order = (int*)malloc(g->numVertices * sizeof(int));
    int idx = 0;

    DFS_Visit(g, source, visited, order, &idx);

    printf("DFS desde %d: ", source);
    for (int i = 0; i < idx; i++) {
        printf("%d ", order[i]);
    }
    printf("\n");

    free(visited);
    free(order);
}

// ─────── DFS iterativo ───────
void DFS_Iterative(GraphList *g, int source) {
    int *visited = (int*)calloc(g->numVertices, sizeof(int));
    int stack[MAX_QUEUE];
    int top = -1;

    stack[++top] = source;

    printf("DFS iterativo desde %d: ", source);

    while (top >= 0) {
        int u = stack[top--];

        if (visited[u]) continue;
        visited[u] = 1;
        printf("%d ", u);

        // Push vecinos en orden inverso para consistencia
        // (necesitaríamos invertir la lista, simplificamos aquí)
        AdjNode *curr = g->array[u].head;
        while (curr) {
            if (!visited[curr->dest]) {
                stack[++top] = curr->dest;
            }
            curr = curr->next;
        }
    }
    printf("\n");

    free(visited);
}

// ─────── Detección de ciclos (no dirigido) ───────
int hasCycleDFS(GraphList *g, int u, int parent, int *visited) {
    visited[u] = 1;

    AdjNode *curr = g->array[u].head;
    while (curr) {
        int v = curr->dest;
        if (!visited[v]) {
            if (hasCycleDFS(g, v, u, visited))
                return 1;
        } else if (v != parent) {
            return 1;   // back edge → ciclo
        }
        curr = curr->next;
    }
    return 0;
}

int hasCycle(GraphList *g) {
    int *visited = (int*)calloc(g->numVertices, sizeof(int));
    int result = 0;

    for (int i = 0; i < g->numVertices; i++) {
        if (!visited[i]) {
            if (hasCycleDFS(g, i, -1, visited)) {
                result = 1;
                break;
            }
        }
    }

    free(visited);
    return result;
}

// ─────── Componentes conexas ───────
int countComponents(GraphList *g) {
    int *visited = (int*)calloc(g->numVertices, sizeof(int));
    int count = 0;

    for (int i = 0; i < g->numVertices; i++) {
        if (!visited[i]) {
            // BFS o DFS para marcar toda la componente
            Queue q;
            initQueue(&q);
            visited[i] = 1;
            enqueue(&q, i);

            while (!isEmptyQueue(&q)) {
                int u = dequeue(&q);
                AdjNode *curr = g->array[u].head;
                while (curr) {
                    if (!visited[curr->dest]) {
                        visited[curr->dest] = 1;
                        enqueue(&q, curr->dest);
                    }
                    curr = curr->next;
                }
            }
            count++;
        }
    }

    free(visited);
    return count;
}

// ─────── Topological Sort (Kahn's) ───────
void topologicalSort(GraphList *g) {
    if (!g->isDirected) {
        printf("Error: topological sort requiere grafo dirigido.\n");
        return;
    }

    int *inDegree = (int*)calloc(g->numVertices, sizeof(int));

    // Calcular in-degrees
    for (int u = 0; u < g->numVertices; u++) {
        AdjNode *curr = g->array[u].head;
        while (curr) {
            inDegree[curr->dest]++;
            curr = curr->next;
        }
    }

    Queue q;
    initQueue(&q);

    for (int i = 0; i < g->numVertices; i++) {
        if (inDegree[i] == 0) enqueue(&q, i);
    }

    int count = 0;
    printf("Topological Sort: ");

    while (!isEmptyQueue(&q)) {
        int u = dequeue(&q);
        printf("%d ", u);
        count++;

        AdjNode *curr = g->array[u].head;
        while (curr) {
            inDegree[curr->dest]--;
            if (inDegree[curr->dest] == 0) {
                enqueue(&q, curr->dest);
            }
            curr = curr->next;
        }
    }
    printf("\n");

    if (count != g->numVertices) {
        printf("¡ADVERTENCIA: El grafo tiene un ciclo! No es un DAG.\n");
    }

    free(inDegree);
}
```

---

# 24. Implementación: Dijkstra

```c
// ═══════════════════════════════════════════════
//  DIJKSTRA (con array simple, O(V²))
// ═══════════════════════════════════════════════

void dijkstra(GraphList *g, int source) {
    int V = g->numVertices;
    int *dist = (int*)malloc(V * sizeof(int));
    int *visited = (int*)calloc(V, sizeof(int));
    int *parent = (int*)malloc(V * sizeof(int));

    for (int i = 0; i < V; i++) {
        dist[i] = INF;
        parent[i] = -1;
    }
    dist[source] = 0;

    for (int count = 0; count < V; count++) {
        // Encontrar el vértice no visitado con menor distancia
        int u = -1;
        int minDist = INF;
        for (int v = 0; v < V; v++) {
            if (!visited[v] && dist[v] < minDist) {
                minDist = dist[v];
                u = v;
            }
        }

        if (u == -1) break;  // no hay más alcanzables
        visited[u] = 1;

        // Relajar vecinos
        AdjNode *curr = g->array[u].head;
        while (curr) {
            int v = curr->dest;
            int w = curr->weight;
            if (!visited[v] && dist[u] != INF && dist[u] + w < dist[v]) {
                dist[v] = dist[u] + w;
                parent[v] = u;
            }
            curr = curr->next;
        }
    }

    // Imprimir resultados
    printf("Dijkstra desde %d:\n", source);
    for (int i = 0; i < V; i++) {
        printf("  dist[%d] = ", i);
        if (dist[i] == INF)
            printf("∞");
        else
            printf("%d", dist[i]);

        // Reconstruir camino
        if (dist[i] != INF && i != source) {
            printf("  camino: ");
            int path[MAX_VERTICES], pathLen = 0;
            int v = i;
            while (v != -1) {
                path[pathLen++] = v;
                v = parent[v];
            }
            for (int j = pathLen - 1; j >= 0; j--) {
                printf("%d", path[j]);
                if (j > 0) printf("→");
            }
        }
        printf("\n");
    }

    free(dist);
    free(visited);
    free(parent);
}

// ═══════════════════════════════════════════════
//  PROGRAMA PRINCIPAL
// ═══════════════════════════════════════════════

int main() {
    printf("════════════════════════════════════\n");
    printf("  GRAFOS — Demostración Completa\n");
    printf("════════════════════════════════════\n\n");

    // ═══ 1. Grafo no dirigido con lista de adyacencia ═══
    printf("── Grafo no dirigido ──\n");
    GraphList *g1 = createGraphList(6, 0);
    addEdgeList(g1, 0, 1, 1);
    addEdgeList(g1, 0, 2, 1);
    addEdgeList(g1, 1, 3, 1);
    addEdgeList(g1, 2, 3, 1);
    addEdgeList(g1, 3, 4, 1);
    addEdgeList(g1, 4, 5, 1);

    printf("Lista de adyacencia:\n");
    printGraphList(g1);

    printf("\n");
    BFS(g1, 0);
    printf("\n");
    DFS(g1, 0);
    printf("\n");

    printf("¿Tiene ciclo? %s\n", hasCycle(g1) ? "SÍ" : "NO");
    printf("Componentes conexas: %d\n", countComponents(g1));

    freeGraphList(g1);

    // ═══ 2. Grafo dirigido (DAG) ═══
    printf("\n── DAG para Topological Sort ──\n");
    GraphList *dag = createGraphList(6, 1);
    addEdgeList(dag, 5, 0, 1);
    addEdgeList(dag, 5, 2, 1);
    addEdgeList(dag, 4, 0, 1);
    addEdgeList(dag, 4, 1, 1);
    addEdgeList(dag, 2, 3, 1);
    addEdgeList(dag, 3, 1, 1);

    printf("Lista de adyacencia:\n");
    printGraphList(dag);
    printf("\n");
    topologicalSort(dag);

    freeGraphList(dag);

    // ═══ 3. Grafo con pesos (Dijkstra) ═══
    printf("\n── Grafo con pesos (Dijkstra) ──\n");
    GraphList *gw = createGraphList(4, 0);
    addEdgeList(gw, 0, 1, 4);
    addEdgeList(gw, 0, 2, 2);
    addEdgeList(gw, 1, 2, 3);
    addEdgeList(gw, 1, 3, 6);
    addEdgeList(gw, 2, 3, 5);

    printf("Lista de adyacencia:\n");
    printGraphList(gw);
    printf("\n");
    dijkstra(gw, 0);

    freeGraphList(gw);

    // ═══ 4. Matriz de adyacencia ═══
    printf("\n── Matriz de adyacencia ──\n");
    GraphMatrix *gm = createGraphMatrix(4, 0, 1);
    addEdgeMatrix(gm, 0, 1, 4);
    addEdgeMatrix(gm, 0, 2, 2);
    addEdgeMatrix(gm, 1, 2, 3);
    addEdgeMatrix(gm, 1, 3, 6);
    addEdgeMatrix(gm, 2, 3, 5);

    printMatrix(gm);
    printf("\nGrado de 1: %d\n", degreeMatrix(gm, 1));
    printf("¿Arista (0,3)? %s\n", hasEdgeMatrix(gm, 0, 3) ? "SÍ" : "NO");
    printf("¿Arista (0,1)? %s\n", hasEdgeMatrix(gm, 0, 1) ? "SÍ" : "NO");

    free(gm);

    return 0;
}
```

### Salida esperada

```text
════════════════════════════════════
  GRAFOS — Demostración Completa
════════════════════════════════════

── Grafo no dirigido ──
Lista de adyacencia:
  0 → [2, w=1] → [1, w=1]
  1 → [3, w=1] → [0, w=1]
  2 → [3, w=1] → [0, w=1]
  3 → [4, w=1] → [2, w=1] → [1, w=1]
  4 → [5, w=1] → [3, w=1]
  5 → [4, w=1]

BFS desde 0: 0 2 1 3 4 5
Distancias desde 0:
  dist[0] = 0
  dist[1] = 1
  dist[2] = 1
  dist[3] = 2
  dist[4] = 3
  dist[5] = 4

DFS desde 0: 0 2 3 4 5 1

¿Tiene ciclo? SÍ
Componentes conexas: 1

── DAG para Topological Sort ──
Lista de adyacencia:
  0 →
  1 →
  2 → [3, w=1]
  3 → [1, w=1]
  4 → [1, w=1] → [0, w=1]
  5 → [2, w=1] → [0, w=1]

Topological Sort: 4 5 0 2 3 1

── Grafo con pesos (Dijkstra) ──
...
Dijkstra desde 0:
  dist[0] = 0
  dist[1] = 4  camino: 0→1
  dist[2] = 2  camino: 0→2
  dist[3] = 7  camino: 0→2→3

── Matriz de adyacencia ──
       0   1   2   3
    ----------------
 0 |   0   4   2   0
 1 |   4   0   3   6
 2 |   2   3   0   5
 3 |   0   6   5   0

Grado de 1: 3
¿Arista (0,3)? NO
¿Arista (0,1)? SÍ
```

---

# PARTE VII — SÍNTESIS

---

# 25. Resumen de Complejidad

## 25.1 Representaciones

| Operación             | Matriz O(?)  | Lista Adj O(?) | Edge List O(?) |
| --------------------- | ------------ | -------------- | -------------- |
| Espacio               | V²           | V + E          | E              |
| Agregar arista        | 1            | 1              | 1              |
| Eliminar arista       | 1            | deg(u)         | E              |
| ¿Existe arista (u,v)? | 1            | deg(u)         | E              |
| Vecinos de v          | V            | deg(v)         | E              |
| BFS / DFS             | V²           | V + E          | V · E          |

## 25.2 Algoritmos

| Algoritmo           | Complejidad          | Usa              | Propósito                      |
| ------------------- | -------------------- | ---------------- | ------------------------------ |
| BFS                 | O(V + E)             | Queue            | Traversal, distancias sin peso |
| DFS                 | O(V + E)             | Stack/Recursión  | Traversal, ciclos, topo sort   |
| Topological Sort    | O(V + E)             | Queue o Stack    | Orden de precedencia (DAG)     |
| Dijkstra (heap)     | O((V+E) log V)       | Min-Heap         | Camino más corto (pesos ≥ 0)  |
| Dijkstra (array)    | O(V²)                | Array            | Camino más corto (denso)      |
| Bellman-Ford        | O(V · E)             | —                | Camino más corto (pesos neg.) |
| Prim (heap)         | O((V+E) log V)       | Min-Heap         | MST                           |
| Kruskal             | O(E log E)           | Union-Find       | MST                           |
| Floyd-Warshall      | O(V³)                | Matriz           | All-pairs shortest paths      |

---

# 26. Errores Comunes y Buenas Prácticas

## 26.1 Tabla de errores

| #  | Error                                                        | Consecuencia                          | Corrección                                     |
| -- | ------------------------------------------------------------ | ------------------------------------- | ---------------------------------------------- |
| 1  | No marcar nodos como visitados                               | Loop infinito (ciclos)                | SIEMPRE usar array visited[]                   |
| 2  | Usar Dijkstra con pesos negativos                            | Distancias incorrectas                | Usar Bellman-Ford                              |
| 3  | Usar BFS para distancias en grafos con pesos                 | Distancias incorrectas                | BFS solo para grafos sin peso; usar Dijkstra   |
| 4  | Confundir dirigido con no dirigido                           | Aristas faltantes o dobles            | Ser explícito al crear el grafo                |
| 5  | Olvidar agregar arista en ambas direcciones (no dirigido)    | Grafo incompleto                      | addEdge debe agregar u→v y v→u                 |
| 6  | Usar matriz de adyacencia para grafos dispersos grandes      | Desperdicio masivo de memoria         | Usar lista de adyacencia                       |
| 7  | No manejar grafos desconectados en DFS/BFS                   | Nodos sin visitar                     | Iterar sobre TODOS los vértices como fuente    |
| 8  | Topological sort en grafo con ciclo                          | Resultado incorrecto                  | Verificar que result.size == V                 |
| 9  | Confundir arista con vértice al contar complejidad           | Análisis incorrecto                   | BFS/DFS es O(V+E), no O(V) ni O(E)            |
| 10 | No inicializar dist[] a ∞                                    | Dijkstra/BF dan resultados basura     | Siempre dist[i] = INF, dist[source] = 0       |

## 26.2 Buenas prácticas

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. SIEMPRE usa lista de adyacencia como DEFAULT                 │
│     → Usa matriz solo si el grafo es denso o necesitas O(1)     │
│     para verificar aristas                                       │
│                                                                  │
│  2. Elige BFS vs DFS según el problema:                          │
│     → Camino más corto sin pesos: BFS                            │
│     → Detección de ciclos, topo sort: DFS                        │
│     → Exploración general: cualquiera                            │
│                                                                  │
│  3. Siempre maneja grafos desconectados:                         │
│     → Itera sobre todos los vértices, no solo desde uno          │
│                                                                  │
│  4. Para grafos con pesos:                                       │
│     → Pesos ≥ 0: Dijkstra                                       │
│     → Pesos negativos (sin ciclo neg.): Bellman-Ford             │
│     → All-pairs: Floyd-Warshall                                  │
│                                                                  │
│  5. Para MST: Prim (denso) o Kruskal (disperso)                 │
│                                                                  │
│  6. En entrevistas: SIEMPRE pregunta:                            │
│     → ¿Dirigido o no dirigido?                                   │
│     → ¿Con pesos o sin pesos?                                    │
│     → ¿Puede tener ciclos?                                       │
│     → ¿Conexo o desconectado?                                    │
│     → ¿Cuántos vértices y aristas (disperso/denso)?             │
└──────────────────────────────────────────────────────────────────┘
```

---

# 27. Intuición de Ingeniería

> **Un grafo es la estructura de datos más general que existe.**
> Arrays, linked lists, árboles, heaps: todos son casos especiales de grafos.
> Cuando puedes modelar un problema como un grafo, tienes acceso a
> décadas de algoritmos probados y optimizados. El reto no es implementar
> los algoritmos — es **reconocer** que el problema es un grafo.

### La idea en una oración

```text
Grafo = vértices + aristas. Eso es todo. Con eso modelas cualquier conexión.
```

### El mapa mental completo

```text
GRAFO
  │
  ├── Representaciones
  │   ├── Matriz de adyacencia: O(V²) espacio, O(1) consulta de arista
  │   ├── Lista de adyacencia:  O(V+E) espacio, O(deg) consulta
  │   └── Edge list:            O(E) espacio, para Kruskal
  │
  ├── Traversals
  │   ├── BFS: Queue, niveles, distancias sin peso
  │   └── DFS: Stack/recursión, ciclos, timestamps, topo sort
  │
  ├── Problemas clásicos
  │   ├── Camino más corto
  │   │   ├── Sin peso: BFS
  │   │   ├── Con peso ≥ 0: Dijkstra
  │   │   ├── Con peso negativo: Bellman-Ford
  │   │   └── All-pairs: Floyd-Warshall
  │   │
  │   ├── MST (Minimum Spanning Tree)
  │   │   ├── Prim (vértice por vértice, como Dijkstra)
  │   │   └── Kruskal (arista por arista, con Union-Find)
  │   │
  │   ├── Detección de ciclos: DFS con colores
  │   ├── Topological Sort: DFS o Kahn (BFS + in-degree)
  │   ├── Componentes conexas: BFS/DFS iterado
  │   └── SCC: Kosaraju o Tarjan
  │
  └── Tipos
      ├── Dirigido / No dirigido
      ├── Con peso / Sin peso
      ├── Cíclico / Acíclico (DAG)
      ├── Conexo / Desconectado
      └── Disperso / Denso
```

### La analogía de los mapas

```text
Vértices = ciudades
Aristas = carreteras
Peso = distancia en km

BFS = "¿Cuántas carreteras necesito cruzar para llegar?"
       (no importa la distancia, solo el número de saltos)

Dijkstra = "¿Cuál es la ruta más corta en km?"
           (considera los pesos de las carreteras)

Prim/Kruskal = "¿Cuál es la red de carreteras más barata
               que conecta todas las ciudades?"

DFS = "Explorar un laberinto siempre girando a la izquierda"

Topo Sort = "¿En qué orden debo tomar los cursos
            si unos son prerequisito de otros?"
```

### Preguntas clásicas de entrevistas

```text
P: ¿BFS o DFS para camino más corto?
R: BFS para grafos sin peso (garantiza distancia mínima en aristas).
   DFS NO garantiza el más corto. Para grafos con peso, Dijkstra.

P: ¿Cuándo usar matriz vs lista de adyacencia?
R: Matriz: grafos densos, necesidad de O(1) para verificar aristas.
   Lista: grafos dispersos (la mayoría), necesidad de iterar vecinos.
   Regla: si |E| << |V|², usa lista.

P: ¿Cómo detectar un ciclo en un grafo dirigido?
R: DFS con 3 colores (WHITE/GRAY/BLACK). Si encuentras una arista
   hacia un nodo GRAY → ciclo. Alternativamente, Kahn's algorithm:
   si el topo sort no incluye todos los nodos, hay ciclo.

P: ¿Diferencia entre Prim y Kruskal?
R: Prim crece desde un vértice (como Dijkstra). Bueno para denso.
   Kruskal ordena aristas y usa Union-Find. Bueno para disperso.
   Ambos producen el MST; pueden dar árboles diferentes si hay
   aristas con pesos iguales.

P: ¿Por qué Dijkstra no funciona con pesos negativos?
R: Dijkstra asume que una vez procesado un nodo, su distancia es final.
   Con pesos negativos, un camino posterior podría ser más corto.
   Solución: Bellman-Ford (O(VE)) o verificar ciclos negativos.
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
| Red-Black Trees                   | RedBlackTree.md      |
| Heaps y Priority Queues           | Heap.md              |
| **Graphs (este)**                 | Graphs.md            |

---

# 28. Ejercicios Sugeridos

## 28.1 Nivel básico

| #  | Ejercicio                                                              | Concepto clave         |
| -- | ---------------------------------------------------------------------- | ---------------------- |
| 1  | Dado el grafo {(0,1),(0,2),(1,3),(2,3),(3,4)}, dibújalo y construye la matriz y lista de adyacencia | Representaciones |
| 2  | Realizar BFS desde el vértice 0 en el grafo anterior. Anotar orden y distancias | BFS |
| 3  | Realizar DFS desde el vértice 0. Anotar orden y timestamps d[]/f[] | DFS |
| 4  | ¿El grafo anterior tiene ciclos? Justifica con DFS | Detección de ciclos |
| 5  | Calcular el grado de cada vértice. Verificar el Handshaking Lemma | Terminología |

## 28.2 Nivel intermedio

| #  | Ejercicio                                                              | Concepto clave         |
| -- | ---------------------------------------------------------------------- | ---------------------- |
| 6  | Dado un DAG con 6 nodos y aristas {5→0, 5→2, 4→0, 4→1, 2→3, 3→1}, encontrar un topological sort | Topo Sort |
| 7  | Encontrar las componentes conexas de un grafo con 8 nodos y aristas {(0,1),(1,2),(3,4),(5,6),(6,7)} | Componentes |
| 8  | Aplicar Dijkstra en un grafo con pesos: {(A,B,1),(A,C,4),(B,C,2),(B,D,6),(C,D,3)} desde A | Dijkstra |
| 9  | Encontrar el MST del grafo del ejercicio 8 usando Kruskal paso a paso | MST |
| 10 | Implementar BFS que reconstruya y muestre el camino más corto entre dos vértices | Shortest path |

## 28.3 Nivel avanzado

| #   | Ejercicio                                                            | Concepto clave          |
| --- | -------------------------------------------------------------------- | ----------------------- |
| 11  | Implementar Bellman-Ford y detectar ciclos negativos                  | Pesos negativos         |
| 12  | Implementar Dijkstra con min-heap (en vez de array lineal)           | PQ + Dijkstra           |
| 13  | Implementar Union-Find con union by rank y path compression          | DSU para Kruskal        |
| 14  | Verificar si un grafo es bipartito usando BFS con 2-coloring         | Bipartito               |
| 15  | Dado un grafo de 100,000 nodos y 200,000 aristas, comparar tiempos de BFS con matriz vs lista | Análisis empírico |
| 16  | Implementar SCC usando el algoritmo de Kosaraju (2 DFS)              | Componentes fuertes     |

### Pistas para ejercicios seleccionados

```text
Ejercicio 8 — Dijkstra desde A:
  Grafo: A─1→B, A─4→C, B─2→C, B─6→D, C─3→D
  dist = [0, ∞, ∞, ∞]
  Process A: dist[B]=1, dist[C]=4
  Process B(1): dist[C]=min(4, 1+2)=3, dist[D]=min(∞, 1+6)=7
  Process C(3): dist[D]=min(7, 3+3)=6
  Process D(6): done
  Result: dist = [0, 1, 3, 6]
  Paths: A→B, A→B→C, A→B→C→D

Ejercicio 9 — Kruskal:
  Aristas ordenadas: (A,B,1), (B,C,2), (C,D,3), (A,C,4), (B,D,6)
  Paso 1: (A,B,1) → Union(A,B). MST = {(A,B,1)}
  Paso 2: (B,C,2) → Union(B,C). MST = {(A,B,1),(B,C,2)}
  Paso 3: (C,D,3) → Union(C,D). MST = {(A,B,1),(B,C,2),(C,D,3)}
  V-1=3 aristas → DONE. Peso total: 6

Ejercicio 14 — Bipartito con BFS:
  Asignar color 0 al source.
  En BFS, cada vecino no visitado recibe el color opuesto.
  Si un vecino ya visitado tiene el MISMO color → NO es bipartito.
  Si BFS termina sin conflictos → ES bipartito.
```
