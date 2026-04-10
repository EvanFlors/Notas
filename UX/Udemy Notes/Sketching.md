# UX Sketching — Guía Completa: Ideación, Flujos y Diseño de Interfaces

> **Idea central:** Sketching no es dibujar bonito — es pensar con las manos.
> Es la herramienta más rápida, barata y poderosa que tiene un diseñador UX/UI
> para explorar ideas, comunicar conceptos y validar soluciones antes de invertir
> un solo minuto en alta fidelidad. Un sketch de 30 segundos puede ahorrarte
> semanas de desarrollo mal dirigido. No necesitas talento artístico: necesitas
> capacidad de síntesis, pensamiento visual y la disciplina de externalizar ideas
> antes de enamorarte de ellas. El lápiz es más rápido que Figma. Siempre.

---

## Tabla de Contenidos

**Parte I — Fundamentos del Sketching**
1. [¿Qué es el Sketching en UX?](#1-qué-es-el-sketching-en-ux)
2. [Sketching dentro del Proceso de Diseño](#2-sketching-dentro-del-proceso-de-diseño)
3. [El Proceso de Dos Fases](#3-el-proceso-de-dos-fases)
4. [Herramientas y Materiales](#4-herramientas-y-materiales)

**Parte II — El Proceso de Sketching**
5. [Preparación](#5-preparación)
6. [Ejecución: De la Idea al Papel](#6-ejecución-de-la-idea-al-papel)
7. [Refinamiento y Documentación](#7-refinamiento-y-documentación)
8. [Feedback y Colaboración](#8-feedback-y-colaboración)

**Parte III — Tipos de Sketches UX**
9. [Flujo General (Customer Journey)](#9-flujo-general-customer-journey)
10. [Flujos de Pantalla (Screen Flows)](#10-flujos-de-pantalla-screen-flows)
11. [Esquemas de Navegación](#11-esquemas-de-navegación)
12. [Estados de Pantalla (Screen States)](#12-estados-de-pantalla-screen-states)
13. [Micro-interacciones y Gestos](#13-micro-interacciones-y-gestos)

**Parte IV — Principios UX Aplicados al Sketching**
14. [Jerarquía Visual](#14-jerarquía-visual)
15. [Affordances y Señales](#15-affordances-y-señales)
16. [Patrones de Diseño Comunes](#16-patrones-de-diseño-comunes)
17. [Principios de Usabilidad en Papel](#17-principios-de-usabilidad-en-papel)

**Parte V — Vocabulario Visual: Componentes en Sketch**
18. [Bloques Básicos de Construcción](#18-bloques-básicos-de-construcción)
19. [Componentes UI en Sketch](#19-componentes-ui-en-sketch)
20. [Anotaciones y Convenciones](#20-anotaciones-y-convenciones)
21. [Layouts y Grids en Sketch](#21-layouts-y-grids-en-sketch)

**Parte VI — Buenas Prácticas y Anti-Patrones**
22. [Buenas Prácticas](#22-buenas-prácticas)
23. [Anti-Patrones y Errores Comunes](#23-anti-patrones-y-errores-comunes)
24. [Checklist de Calidad](#24-checklist-de-calidad)

**Parte VII — Inspiración y Crecimiento**
25. [Cómo Mantenerse Inspirado](#25-cómo-mantenerse-inspirado)
26. [Fuentes de Inspiración Online](#26-fuentes-de-inspiración-online)
27. [Ejercicios Prácticos](#27-ejercicios-prácticos)

---

# PARTE I — FUNDAMENTOS DEL SKETCHING

---

# 1. ¿Qué es el Sketching en UX?

## 1.1 Definición

```
Sketching en UX es el acto de externalizar ideas de diseño rápidamente
mediante dibujos de baja fidelidad — con el objetivo de explorar, comunicar
y validar soluciones de interfaz y experiencia de usuario.

  → No es arte                → Es pensamiento visual
  → No es wireframing         → Es pre-wireframing
  → No es un entregable       → Es una herramienta de proceso
  → No requiere precisión     → Requiere intención
```

Un sketch UX traduce conceptos abstractos (flujos, interacciones, jerarquías) en
representaciones visuales concretas que se pueden discutir, iterar y descartar en
minutos — no en días.

## 1.2 Sketch vs Wireframe vs Mockup vs Prototipo

```
Fidelidad
  ▲
  │
  │   ┌──────────────────┐
  │   │    PROTOTIPO      │  → Interactivo, clickeable
  │   │   Alta fidelidad  │  → Figma / Framer / código
  │   └──────────────────┘
  │   ┌──────────────────┐
  │   │     MOCKUP        │  → Visual final, colores, tipografía
  │   │  Media-Alta fid.  │  → Figma / Sketch / XD
  │   └──────────────────┘
  │   ┌──────────────────┐
  │   │    WIREFRAME      │  → Estructura, layout, contenido
  │   │  Media fidelidad  │  → Figma / Balsamiq / papel
  │   └──────────────────┘
  │   ┌──────────────────┐
  │   │     SKETCH        │  → Ideas rápidas, exploración
  │   │  Baja fidelidad   │  → Papel / pizarra / tablet
  │   └──────────────────┘
  │
  └──────────────────────────────────────────► Tiempo/Costo
        Minutos    Horas     Días     Semanas
```

| Aspecto | Sketch | Wireframe | Mockup | Prototipo |
|---------|--------|-----------|--------|-----------|
| **Fidelidad** | Muy baja | Baja-Media | Alta | Alta + Interacción |
| **Tiempo** | 30 seg – 5 min | 30 min – 2 hrs | 2 – 8 hrs | 4 – 40 hrs |
| **Herramienta** | Lápiz, papel | Figma, Balsamiq | Figma, Sketch | Figma, Framer, código |
| **Objetivo** | Explorar ideas | Definir estructura | Definir visual | Validar interacción |
| **Descartable** | ✅ Siempre | ✅ Sí | ⚠️ Costoso | ❌ Muy costoso |
| **Audiencia** | Tú, tu equipo | Equipo, stakeholders | Stakeholders, devs | Usuarios, testing |

## 1.3 Por qué Sketching es Indispensable

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌─────────────────┐                                            │
│  │  💡 10 IDEAS     │──→ Sketch rápido ──→ 3 prometedoras       │
│  │  en tu cabeza    │     (20 minutos)      seleccionadas       │
│  └─────────────────┘                            │               │
│                                                 ▼               │
│                                          ┌──────────────┐       │
│                                          │  Wireframes   │      │
│                                          │  de las 3     │      │
│                                          └──────┬───────┘       │
│                                                 │               │
│                                                 ▼               │
│                                          ┌──────────────┐       │
│                                          │  1 solución   │      │
│                                          │  validada     │      │
│                                          └──────────────┘       │
│                                                                 │
│  Sin sketching: saltas directo a Figma con la PRIMERA idea      │
│  → Sesgo de anclaje → Solución subóptima → Retrabajo            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Ventajas concretas del sketching:**

- **Velocidad radical** — Produces 10 variaciones en el tiempo de 1 wireframe
- **Coste cero** — Descartar un sketch no duele; descartar un mockup sí
- **Reduce el sesgo de anclaje** — Al generar múltiples opciones, no te casas con la primera
- **Facilita la comunicación** — Un dibujo rápido vale más que 10 minutos explicando
- **Involucra al equipo** — Cualquiera puede sketchar; no necesitas saber Figma
- **Descubre requisitos ocultos** — Al dibujar, surgen preguntas que no surgían pensando
- **Documenta decisiones** — Un sketch anotado captura el "por qué" de una decisión

---

# 2. Sketching dentro del Proceso de Diseño

## 2.1 El Double Diamond

```
         DISCOVER          DEFINE          DEVELOP          DELIVER
        ╱          ╲      ╱       ╲       ╱        ╲      ╱        ╲
       ╱            ╲    ╱         ╲     ╱          ╲    ╱          ╲
      ╱   Research   ╲  ╱  Síntesis ╲   ╱  Ideación  ╲  ╱  Entrega   ╲
     ╱    Empatía     ╲╱   Problem   ╲ ╱   Diseño     ╲╱   Testing    ╲
     ╲   Entrevistas  ╱╲  Statement  ╱ ╲   Prototipos ╱╲   Iteración  ╱
      ╲              ╱  ╲          ╱   ╲            ╱  ╲            ╱
       ╲            ╱    ╲        ╱     ╲          ╱    ╲          ╱
        ╲          ╱      ╲      ╱       ╲        ╱      ╲        ╱
                              ▲                ▲
                              │                │
                     Sketching aquí      Y sobre todo aquí
                     (explorar el        (generar soluciones
                      problema)           rápidamente)
```

## 2.2 Dónde Encaja el Sketching en cada Fase

| Fase del Proyecto | Uso del Sketching | Ejemplo |
|---|---|---|
| **Discovery** | Mapear journeys observados, capturar insights | Dibujar el flujo actual del usuario durante una entrevista |
| **Define** | Visualizar el problema, sketchar escenarios | Dibujar los pain points del journey actual |
| **Ideation** | Generar múltiples soluciones (⭐ uso principal) | Crazy 8s: 8 ideas en 8 minutos |
| **Design** | Explorar layouts antes de wireframear | Probar 3 variantes de navegación en papel |
| **Prototype** | Paper prototyping para testing rápido | Recortar pantallas y simular flujo con usuario |
| **Testing** | Capturar feedback visual en tiempo real | Sketchar cambios sugeridos durante una sesión |

## 2.3 Metodologías de Ideación que usan Sketching

**Crazy 8s (Design Sprint)**

```
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ Idea │ │ Idea │ │ Idea │ │ Idea │
│  #1  │ │  #2  │ │  #3  │ │  #4  │
│      │ │      │ │      │ │      │
│ 1min │ │ 1min │ │ 1min │ │ 1min │
└──────┘ └──────┘ └──────┘ └──────┘
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ Idea │ │ Idea │ │ Idea │ │ Idea │
│  #5  │ │  #6  │ │  #7  │ │  #8  │
│      │ │      │ │      │ │      │
│ 1min │ │ 1min │ │ 1min │ │ 1min │
└──────┘ └──────┘ └──────┘ └──────┘

→ 1 hoja doblada en 8 secciones
→ 1 minuto por idea
→ 8 ideas en 8 minutos
→ Sin juzgar, sin borrar
```

**Design Studio (Collaborative Sketching)**

```
Paso 1: Individual      Paso 2: Presentar       Paso 3: Iterar
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Cada diseñador   │    │ Cada uno presenta│    │ Combinar las     │
│ sketcha 3-5      │──→ │ sus ideas al     │──→ │ mejores ideas    │
│ soluciones       │    │ grupo (2 min)    │    │ en nuevos        │
│ (10 min)         │    │                  │    │ sketches (10 min)│
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

**Paper Prototyping**

```
1. Sketchar cada pantalla en una hoja separada
2. Recortar elementos interactivos (modals, dropdowns)
3. Sentar a un usuario frente a las hojas
4. "¿Dónde harías click para buscar un producto?"
5. Mover las hojas como respuesta a sus acciones
6. Capturar reacciones y confusiones en tiempo real
```

---

# 3. El Proceso de Dos Fases

## 3.1 La Regla Fundamental

```
Sketching es un proceso de DOS fases. Nunca las mezcles:

  ┌─────────────────────────┐     ┌─────────────────────────┐
  │   FASE 1: DIVERGIR      │     │   FASE 2: CONVERGER     │
  │                         │     │                         │
  │  → Generar ideas        │     │  → Refinar las mejores  │
  │  → Cantidad > Calidad   │     │  → Calidad > Cantidad   │
  │  → Sin juzgar           │     │  → Juzgar y seleccionar │
  │  → Rápido y sucio       │     │  → Lento y deliberado   │
  │  → Muchas opciones      │     │  → Pocas, detalladas    │
  │  → Lápiz grueso         │     │  → Lápiz fino           │
  │                         │     │                         │
  │  "¿Cuántas formas hay   │     │  "¿Cuál de estas es la  │
  │   de resolver esto?"    │     │   mejor solución?"      │
  └────────────┬────────────┘     └────────────┬────────────┘
               │                               │
               ▼                               ▼
         10-20 sketches                   2-3 refinados
         en 20 minutos                    con detalle
```

## 3.2 Fase 1 — Generación de Ideas

**Qué hacer:**

- Dibujar la mayor cantidad posible de variaciones
- No detenerse en detalles — trazos rápidos, formas simples
- No autocensurarse — las ideas "malas" abren camino a las buenas
- Explorar enfoques radicalmente diferentes, no variaciones mínimas
- Usar timer: 1–2 minutos máximo por sketch

**Ejemplo — Generar ideas para una pantalla de búsqueda:**

```
Idea A: Búsqueda      Idea B: Búsqueda     Idea C: Búsqueda
con barra fija         con overlay          conversacional

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ [🔍 Buscar ] │      │              │      │              │
├──────────────┤      │ ┌──────────┐ │      │  ¿Qué estás  │
│              │      │ │ 🔍       │ │      │  buscando?   │
│  resultado 1 │      │ ├──────────┤ │      │              │
│  resultado 2 │      │ │ suger. 1 │ │      │  [chat input] │
│  resultado 3 │      │ │ suger. 2 │ │      │              │
│              │      │ │ suger. 3 │ │      │  Bot: Te     │
│              │      │ └──────────┘ │      │  recomiendo...│
│ [nav] [nav]  │      │              │      │ [nav] [nav]  │
└──────────────┘      └──────────────┘      └──────────────┘

Idea D: Búsqueda      Idea E: Sin barra     Idea F: Visual
por categorías         (solo filtros)        (búsqueda por
                                              imagen)
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   BUSCAR     │      │  Filtros:    │      │              │
│ ┌────┐┌────┐ │      │ [Precio ▼]   │      │   📷 Sube    │
│ │Ropa││Tech│ │      │ [Color  ▼]   │      │   una foto   │
│ └────┘└────┘ │      │ [Talla  ▼]   │      │              │
│ ┌────┐┌────┐ │      │              │      │  ┌────────┐  │
│ │Casa││Dep.│ │      │  resultado 1 │      │  │ 📷     │  │
│ └────┘└────┘ │      │  resultado 2 │      │  └────────┘  │
│              │      │  resultado 3 │      │              │
│ [nav] [nav]  │      │ [nav] [nav]  │      │ [nav] [nav]  │
└──────────────┘      └──────────────┘      └──────────────┘
```

> **Nota:** En 10 minutos generaste 6 enfoques completamente diferentes.
> En Figma, esos mismos 10 minutos apenas te alcanzan para configurar un frame.

## 3.3 Fase 2 — Refinamiento y Detalle

Una vez seleccionadas las ideas más prometedoras, es momento de detallar:

**Progresión del refinamiento:**

```
Nivel 1: Idea cruda           Nivel 2: Estructura          Nivel 3: Componentes
(30 segundos)                 (3-5 minutos)                (10-15 minutos)

┌──────────────┐              ┌──────────────┐              ┌──────────────┐
│ [búsqueda]   │              │ [🔍 Buscar...]│              │ ← Back  🔍   │
│              │              │──────────────│              │─────────────── │
│  cosas       │              │ 24 resultados│              │ 24 resultados │
│  aquí        │              │              │              │ para "zapatos"│
│              │              │ ┌──┐ nombre  │              │ ┌──────┐      │
│              │              │ │  │ precio  │              │ │ IMG  │ Nike │
│              │              │ └──┘         │              │ │      │ Air  │
│  [boton]     │              │ ┌──┐ nombre  │              │ └──────┘ $120 │
│              │              │ │  │ precio  │              │   ★★★★☆ (48) │
└──────────────┘              │ └──┘         │              │ ♡ Guardar    │
                              │              │              │───────────────│
                              │ [🏠][🔍][🛒] │              │ ┌──────┐      │
                              └──────────────┘              │ │ IMG  │ Adid.│
                                                            │ └──────┘ $95  │
                                                            │   ★★★★★ (72) │
                                                            │ ♡ Guardar    │
                                                            │───────────────│
                                                            │ [🏠][🔍][❤️][🛒]│
                                                            └──────────────┘
```

**Qué agregar en el refinamiento:**

- Contenido real (no "Lorem ipsum" — usa datos creíbles)
- Jerarquía clara (qué es más importante visualmente)
- Estados (vacío, cargando, error, con datos)
- Interacciones (¿qué pasa al tocar X?)
- Anotaciones que expliquen decisiones

---

# 4. Herramientas y Materiales

## 4.1 Kit Básico

| Herramienta | Para qué | Recomendación |
|---|---|---|
| **Papel** | Sketches individuales | Hojas A4 o cuaderno dot grid |
| **Lápiz** | Trazos iniciales, borrables | Lápiz mecánico 0.5mm |
| **Marcador fino** | Líneas definitivas | Micron 0.3 o 0.5 |
| **Marcador grueso** | Títulos, énfasis, CTAs | Micron 0.8 o Sharpie fino |
| **Marcador gris** | Sombras, profundidad, fondos | Copic Sketch gris claro |
| **Marcador color** | Highlights, CTAs, estados | 1-2 colores máximo (rojo, azul) |
| **Regla** | Frames de dispositivo | Opcional — la imperfección es virtud |
| **Templates impresos** | Frames de dispositivo consistentes | Plantillas de iPhone/Android/Browser |
| **Notas adhesivas** | Ideación grupal, reorganizar | Post-its estándar |

## 4.2 Kit Digital

| Herramienta | Plataforma | Mejor para |
|---|---|---|
| **Concepts** | iPad | Lienzo infinito, vectores |
| **Procreate** | iPad | Trazos naturales, texturas |
| **Paper by WeTransfer** | iPad | Simplicidad, rapidez |
| **Excalidraw** | Web (gratis) | Colaboración remota, diagramas |
| **Miro / FigJam** | Web | Sketching colaborativo en equipo |
| **GoodNotes / Notability** | iPad | Sketching + notas combinadas |

## 4.3 Templates de Dispositivos

```
MOBILE (iPhone)              TABLET (iPad)             DESKTOP (Browser)

┌──────────────────┐        ┌──────────────────────┐   ┌────────────────────────────┐
│    ○              │        │                      │   │ ← → ↻  [         🔍  ]    │
│ ┌──────────────┐ │        │                      │   │────────────────────────────│
│ │              │ │        │                      │   │                            │
│ │              │ │        │                      │   │                            │
│ │   CONTENIDO  │ │        │      CONTENIDO       │   │         CONTENIDO          │
│ │              │ │        │                      │   │                            │
│ │              │ │        │                      │   │                            │
│ │              │ │        │                      │   │                            │
│ │              │ │        │                      │   │                            │
│ └──────────────┘ │        │                      │   │                            │
│       ───        │        │                      │   │                            │
└──────────────────┘        └──────────────────────┘   └────────────────────────────┘
   Ratio ~9:19.5               Ratio ~3:4                 Ratio ~16:9
   375×812 pts                 1024×1366 pts              1440×900 px
```

> **Tip:** Imprime templates de dispositivos en hojas A4. Tener el frame ya dibujado
> elimina la fricción inicial y te permite empezar a sketchar contenido inmediatamente.

---

# PARTE II — EL PROCESO DE SKETCHING

---

# 5. Preparación

## 5.1 Antes de Tocar el Lápiz

La calidad de tus sketches depende directamente de la calidad de tu preparación.
No se trata de "ponerse a dibujar" — se trata de pensar con propósito.

**Checklist de preparación:**

```
□ ¿Cuál es el OBJETIVO de esta sesión de sketching?
  → ¿Explorar un flujo completo?
  → ¿Resolver una pantalla específica?
  → ¿Comparar alternativas de navegación?

□ ¿Cuál es el CONTEXTO?
  → ¿Qué sabemos del usuario? (personas, research)
  → ¿Qué restricciones técnicas existen?
  → ¿Hay patrones existentes en el producto?

□ ¿Quién es la AUDIENCIA de estos sketches?
  → Para ti → Pueden ser caóticos
  → Para tu equipo → Necesitan anotaciones
  → Para stakeholders → Necesitan contexto y limpieza

□ ¿Cuánto TIEMPO tengo?
  → 15 min → Solo Fase 1 (generar ideas)
  → 30 min → Fase 1 + selección
  → 60 min → Fase 1 + Fase 2 (refinamiento)
  → 2+ hrs → Proceso completo con alternativas
```

## 5.2 Definir el Problema con Claridad

Antes de sketchar, escribe en una oración qué estás resolviendo:

```
❌ "Voy a sketchar la app"
✅ "Voy a explorar 5 formas diferentes en que un usuario
    puede encontrar un producto sin usar la barra de búsqueda"

❌ "Diseñar el checkout"
✅ "Reducir los pasos de checkout de 5 pantallas a 3,
    manteniendo toda la información necesaria"

❌ "Hacer la home"
✅ "Priorizar productos personalizados en la home para
    usuarios recurrentes que saben lo que quieren"
```

## 5.3 Time-Boxing

```
┌─────────────────────────────────────────────────────┐
│  TIME-BOXING: El arma secreta del sketching eficaz  │
│                                                     │
│  La presión del tiempo ELIMINA la parálisis.        │
│  Sin límite → Perfeccionismo → Pocas ideas          │
│  Con límite → Urgencia → Muchas ideas               │
│                                                     │
│  Tiempos recomendados:                              │
│    → 1 min  por sketch exploratorio                 │
│    → 5 min  por sketch con estructura               │
│    → 10 min por sketch detallado                    │
│    → 15 min total para Crazy 8s                     │
│    → 30 min para sesión de ideación individual      │
│    → 60 min para Design Studio grupal               │
└─────────────────────────────────────────────────────┘
```

> **Tip profesional:** Usa un timer visible. El timer no es tu enemigo — es el mecanismo
> que te libera de la autocensura. Cuando tienes 60 segundos, no hay tiempo para
> juzgar si una idea es buena o mala. Solo hay tiempo para dibujarla.

---

# 6. Ejecución: De la Idea al Papel

## 6.1 Paso 1 — Dibujar el Frame

Empieza siempre por el contenedor. Esto ancla tu mente al contexto real:

```
¿Es mobile?          ¿Es desktop?          ¿Es tablet?
Dibuja esto:         Dibuja esto:          Dibuja esto:

┌──────────┐         ┌───────────────────┐  ┌─────────────────┐
│          │         │ ←  →  [url    ]   │  │                 │
│          │         │───────────────────│  │                 │
│          │         │                   │  │                 │
│          │         │                   │  │                 │
│          │         │                   │  │                 │
│          │         │                   │  │                 │
└──────────┘         └───────────────────┘  └─────────────────┘
```

## 6.2 Paso 2 — Elementos Estructurales Primero

Coloca los elementos que se repiten en toda la app — el "esqueleto":

```
┌──────────────┐
│  HEADER      │  ← Navegación principal, logo, búsqueda
│──────────────│
│              │
│              │
│  CONTENIDO   │  ← Varía por pantalla (lo dejas vacío por ahora)
│              │
│              │
│──────────────│
│  FOOTER/NAV  │  ← Tab bar, acciones principales
└──────────────┘
```

## 6.3 Paso 3 — Contenido Principal

Ahora rellena el contenido específico de esta pantalla:

```
┌──────────────────┐
│ ← Atrás    🛒 2  │
│──────────────────│
│                  │
│  ┌────────────┐  │
│  │            │  │
│  │   IMAGEN   │  │  ← Área visual principal
│  │            │  │
│  └────────────┘  │
│                  │
│  Nike Air Max    │  ← Título prominente
│  ★★★★☆ (127)    │  ← Social proof
│                  │
│  $129.99         │  ← Precio claro
│                  │
│  Talla: [S][M][L]│  ← Opciones interactivas
│                  │
│  Color: ● ● ○   │
│                  │
│ ┌──────────────┐ │
│ │ AGREGAR AL   │ │  ← CTA principal (grande, al alcance del pulgar)
│ │   CARRITO    │ │
│ └──────────────┘ │
│──────────────────│
│ 🏠  🔍  ❤️  👤  │
└──────────────────┘
```

## 6.4 Paso 4 — Interacciones y Transiciones

Indica qué pasa cuando el usuario interactúa:

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│          │  tap    │          │  swipe  │          │
│  Home    │──────→  │ Producto │──────→  │ Galería  │
│          │         │          │  left   │          │
└──────────┘         └──────────┘         └──────────┘
                          │
                          │ tap "Agregar"
                          ▼
                     ┌──────────┐
                     │  ✓ Toast │
                     │ Agregado │
                     │ al carrito│
                     └──────────┘
```

## 6.5 Principio de las Formas Básicas

No necesitas saber dibujar. Todo sketch UI se construye con 5 formas:

```
□ Rectángulo  → Contenedores, cards, botones, inputs, imágenes
○ Círculo     → Avatares, iconos, checkboxes, radio buttons
— Línea       → Texto, separadores, bordes
✕ Cruz / X    → Cerrar, eliminar, placeholder de imagen
→ Flecha      → Transiciones, direcciones, flujo
```

**Combinaciones comunes:**

```
□ + —        = Input de texto      [_______________]
□ + ○        = Toggle              [○━━━━━━━━━━━]
□ + □        = Card con imagen     ┌──┐ Título
                                   │  │ Descripción
                                   └──┘
○ + —        = Avatar + nombre     (○) Juan Pérez
— + — + —    = Párrafo de texto    ————————————————
                                   ————————————————
                                   ————————————
□ + →        = Botón con acción    [ Siguiente → ]
```

---

# 7. Refinamiento y Documentación

## 7.1 Títulos

Cada sketch necesita un título que lo identifique inmediatamente:

```
          ❌ Sin título              ✅ Con título

     ┌──────────────┐           "Checkout - Paso 2/3"
     │              │           ┌──────────────┐
     │   ???        │           │              │
     │              │           │  Dirección   │
     └──────────────┘           │  de envío    │
     (¿Qué pantalla es?)       └──────────────┘
                                (Inmediatamente claro)
```

## 7.2 Numeración

Numera los sketches para indicar secuencia dentro de un flujo:

```
  ①               ②               ③               ④
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│ Login  │ ──→  │ Home   │ ──→  │Producto│ ──→  │ Cart   │
│        │      │        │      │        │      │        │
└────────┘      └────────┘      └────────┘      └────────┘
```

> **Beneficio:** Durante el feedback, alguien puede decir "En la pantalla 3,
> creo que el botón debería estar más arriba" — sin ambigüedad.

## 7.3 Anotaciones

Las anotaciones transforman un dibujo ambiguo en una decisión documentada:

```
┌──────────────────────────┐
│  ← Atrás         🛒 (2) │ ──── Badge muestra items en carrito
│──────────────────────────│
│                          │
│  ┌──────────────────┐    │
│  │                  │    │
│  │    HERO IMAGE    │◄───────── Carousel: swipe horizontal
│  │                  │    │      3-5 imágenes del producto
│  └──────────────────┘    │
│                          │
│  Nike Air Max 90         │
│  ★★★★☆  (127 reviews) ◄─────── Tap → scroll a reviews
│                          │
│  $129.99  ̶$̶1̶5̶9̶.̶9̶9̶  ◄──────── Precio tachado muestra
│                          │       descuento (urgencia)
│  ┌────────────────────┐  │
│  │  AGREGAR AL CARRO  │◄─────── Sticky bottom button
│  └────────────────────┘  │      (zona de fácil acceso
│                          │       del pulgar en mobile)
└──────────────────────────┘
```

## 7.4 Flechas y Flujo

Usa flechas para indicar transiciones y relaciones entre pantallas:

```
Flechas de navegación:

  ──→   Navegación directa (tap, click)
  ──→   Flujo principal (happy path)
  - - → Flujo alternativo (error, cancelar)
  ←──→  Navegación bidireccional
  ──↓   Scroll / contenido debajo del fold

Flechas de interacción:

  ╔══→  Animación / transición
  ──⊕   Overlay / modal que aparece
  ──✕   Elemento que se cierra / destruye
```

## 7.5 Gestos (Mobile)

```
Vocabulario de gestos para anotar sketches mobile:

  ☝️ Tap          →  (tap)     Acción principal
  ☝️☝️ Double tap  →  (2x tap)  Zoom, like
  👆 Long press   →  (hold)    Menú contextual
  👈 Swipe left   →  (←)       Siguiente, eliminar
  👉 Swipe right  →  (→)       Atrás, archivar
  👆 Swipe up     →  (↑)       Scroll, pull-up sheet
  👇 Swipe down   →  (↓)       Refresh, dismiss
  🤏 Pinch        →  (pinch)   Zoom in/out
```

---

# 8. Feedback y Colaboración

## 8.1 Presentar Sketches al Equipo

```
┌─────────────────────────────────────────────────────────────┐
│  Framework para presentar sketches:                         │
│                                                             │
│  1. CONTEXTO (30 seg)                                       │
│     "Estamos resolviendo: [problem statement]"              │
│                                                             │
│  2. OPCIONES (2 min por opción)                             │
│     "Exploré N enfoques. Les muestro los 3 más             │
│      prometedores y por qué..."                             │
│                                                             │
│  3. TRADE-OFFS (1 min)                                      │
│     "La opción A es más simple pero limita X.               │
│      La opción B es más compleja pero permite Y."           │
│                                                             │
│  4. FEEDBACK (5-10 min)                                     │
│     "¿Qué ven que yo no estoy viendo?                       │
│      ¿Hay un caso que no estoy contemplando?"               │
│                                                             │
│  ⚠️ NUNCA digas "esto es lo que voy a hacer".               │
│     DI: "estas son las opciones que exploré".               │
│     → Invita contribución, no aprobación.                   │
└─────────────────────────────────────────────────────────────┘
```

## 8.2 Con Quién Compartir

| Persona | Qué Buscar de Ellos | Pregunta Clave |
|---|---|---|
| **Producto / PM** | Validar que resuelve el problema correcto | "¿Esto resuelve lo que necesita el usuario?" |
| **Desarrollo** | Viabilidad técnica, complejidad | "¿Es factible? ¿Cuánto costaría esto?" |
| **QA** | Casos edge, escenarios no contemplados | "¿Qué podría fallar aquí?" |
| **Otro diseñador** | Patrones, consistencia, UX | "¿Hay un patrón mejor para esto?" |
| **Stakeholder** | Alineamiento con objetivos de negocio | "¿Esto se alinea con nuestros KPIs?" |
| **Usuario real** | Comprensión, expectativas | "¿Qué esperas que pase si tocas aquí?" |

## 8.3 Métodos de Compartir

```
Presencial:
  → Llevar las hojas originales
  → Pegar sketches en pared/pizarra
  → Usar dot voting (cada persona pega stickers en su favorita)

Remoto:
  → Foto → Figma/FigJam (pegar como imagen)
  → Escanear → compartir por Slack/Teams
  → Excalidraw en vivo para sketchar juntos
  → Miro board con sketches organizados por flujo
```

---

# PARTE III — TIPOS DE SKETCHES UX

---

# 9. Flujo General (Customer Journey)

## 9.1 Qué Es

Un sketch de flujo general mapea la experiencia completa del usuario con el producto
— desde el primer contacto hasta que completa su objetivo (y después). No se enfoca
en UI específica, sino en las **etapas emocionales y funcionales** del journey.

## 9.2 Cuándo Usarlo

- Al inicio de un proyecto para entender el alcance
- Para identificar pain points y oportunidades
- Para alinear al equipo en la visión del producto
- Antes de decidir qué pantallas diseñar primero

## 9.3 Cómo Sketchar un Journey

**Paso 1: Identificar las etapas principales**

```
Ejemplo: App de e-commerce personalizado (Habitual)

  Descubre     Explora      Decide      Compra      Recibe
     ①           ②           ③           ④           ⑤

  ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐
  │     │     │     │     │     │     │     │     │     │
  │Welcome│──→│ Home │──→│Product│──→│ Cart │──→│Confirm│
  │     │     │     │     │     │     │     │     │     │
  └─────┘     └─────┘     └─────┘     └─────┘     └─────┘
```

**Paso 2: Agregar emociones y oportunidades**

```
Emoción:   😐          😊          🤔          😰          😄
           Neutral     Interesado  Evaluando   Ansiedad    Satisfecho
                                               (¿será
                                               seguro?)

  ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐
  │Welcom│──→ │ Home │──→ │Produc│──→ │ Cart │──→ │Confir│
  └─────┘     └─────┘     └─────┘     └─────┘     └─────┘

Oportun:  Onboarding   Personalizar   Reviews    Garantía   Tracking
          atractivo    contenido      visibles   visible    en tiempo
                                                            real
```

**Paso 3: Identificar flujos alternativos**

```
                                    ┌─────────────┐
                                    │ No encuentra │
                              ┌────→│  producto    │────→ Buscar por categoría
                              │     └─────────────┘              │
  ┌─────┐     ┌─────┐        │     ┌─────┐     ┌─────┐         │
  │Welcom│──→ │ Home │──→ Busca ──→│Produc│──→ │ Cart │         │
  └─────┘     └─────┘              └─────┘     └─────┘         │
                   │                   ▲                         │
                   │                   └─────────────────────────┘
                   │
                   └────→ Ve recomendaciones ──→ Producto
                          personalizadas
```

## 9.4 Template de Journey Sketch

```
┌──────────────────────────────────────────────────────────────────┐
│  JOURNEY: [nombre del flujo]                                     │
│  PERSONA: [quién es el usuario]                                  │
│  OBJETIVO: [qué quiere lograr]                                   │
│                                                                  │
│  Emoción: ───────────────────────────────────────────            │
│           😐    😊    😊    🤔    😰    😊    😄                 │
│                                                                  │
│  Etapas:  ①──→②──→③──→④──→⑤──→⑥──→⑦                            │
│           │    │    │    │    │    │    │                         │
│  Pantalla: [  ][  ][  ][  ][  ][  ][  ]                         │
│                                                                  │
│  Pain      ·    ·    ·    ·    ·    ·    ·                       │
│  points:  ___  ___  ___  ___  ___  ___  ___                     │
│                                                                  │
│  Oportun:  ·    ·    ·    ·    ·    ·    ·                       │
│           ___  ___  ___  ___  ___  ___  ___                     │
└──────────────────────────────────────────────────────────────────┘
```

---

# 10. Flujos de Pantalla (Screen Flows)

## 10.1 Qué Es

Un screen flow sketcha la secuencia exacta de pantallas que un usuario atraviesa
para completar una tarea específica. Se enfoca en **UI concreta**, no en emociones.

## 10.2 Cuándo Usarlo

- Cuando necesitas definir cuántas pantallas tiene un flujo
- Para identificar qué información necesita cada paso
- Para encontrar pasos innecesarios que se pueden eliminar
- Para validar que el flujo cubre los escenarios alternativos

## 10.3 Preguntas para Guiar el Sketch

```
Antes de dibujar cada pantalla, pregúntate:

  → ¿Qué necesita el usuario para tomar la SIGUIENTE decisión?
  → ¿Qué pasa si el usuario quiere ir ATRÁS?
  → ¿Qué pasa si algo sale MAL? (error, timeout, dato faltante)
  → ¿Hay un ATAJO para usuarios experimentados?
  → ¿Dónde regresa el usuario si CIERRA la app aquí?
```

## 10.4 Ejemplo — Flujo de Búsqueda

```
FLUJO: Buscar y comprar un producto
USUARIO: Cliente recurrente que sabe lo que quiere

① HOME                ② RESULTADOS          ③ PRODUCTO            ④ CARRITO
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Logo    🛒   │     │ ← "zapatos"  │     │ ← Back  ♡ 🛒│     │ ← Carrito    │
│──────────────│     │──────────────│     │──────────────│     │──────────────│
│ [🔍 Buscar..]│     │ 24 result.   │     │ ┌──────────┐ │     │              │
│              │     │ [Filtrar ▼]  │     │ │          │ │     │ ┌──┐ Nike    │
│ Recomendados │     │              │     │ │  IMAGEN  │ │     │ │  │ $129    │
│ ┌──┐ ┌──┐   │     │ ┌──┐ Nike    │     │ │          │ │     │ └──┘  × 1    │
│ │  │ │  │   │     │ │  │ $129    │     │ └──────────┘ │     │              │
│ └──┘ └──┘   │     │ └──┘ ★★★★   │     │              │     │──────────────│
│              │     │              │     │ Nike Air Max │     │ Subtotal:    │
│ Categorías   │     │ ┌──┐ Adidas │     │ ★★★★☆ (127) │     │ $129.99      │
│ [Ropa][Tech] │     │ │  │ $95    │     │              │     │              │
│              │     │ └──┘ ★★★★★  │     │ $129.99      │     │ ┌──────────┐ │
│──────────────│     │              │     │              │     │ │ CHECKOUT │ │
│ 🏠 🔍 ❤️ 👤  │     │──────────────│     │ Talla:[M][L] │     │ └──────────┘ │
└──────────────┘     │ 🏠 🔍 ❤️ 👤  │     │              │     └──────────────┘
       │             └──────────────┘     │ ┌──────────┐ │
       │ tap 🔍             │             │ │AGREGAR   │ │
       └─────────→──────────┘             │ │AL CARRO  │ │
                        │                 │ └──────────┘ │
                        │ tap card        └──────────────┘
                        └────────→────────────────┘


FLUJOS ALTERNATIVOS:

  Desde ①:
    → Tap en producto recomendado ──→ directo a ③
    → Tap en categoría ──→ resultados filtrados (②)

  Desde ②:
    → No hay resultados ──→ pantalla vacía con sugerencias
    → Tap filtro ──→ overlay de filtros
    → Tap ♡ en producto ──→ agregar a guardados

  Desde ③:
    → Producto sin stock ──→ botón "Notificar cuando disponible"
    → Tap en reviews ──→ scroll a sección de reviews
```

## 10.5 Mapear el Happy Path vs Edge Cases

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   HAPPY PATH (línea verde)                                  │
│   ① → ② → ③ → ④ → ⑤ → ✅ Compra exitosa                  │
│                                                             │
│   EDGE CASES (líneas rojas)                                 │
│   ② → ✕ Sin resultados → Sugerir categorías                │
│   ③ → ✕ Sin stock → Notificar disponibilidad               │
│   ④ → ✕ Error de pago → Reintentar / método alternativo    │
│   ④ → ← Usuario abandona → Email de carrito abandonado     │
│   ⑤ → ✕ Envío demorado → Tracking + notificación           │
│                                                             │
│   Sketcha PRIMERO el happy path.                            │
│   Sketcha DESPUÉS cada edge case.                           │
│   Los edge cases son donde se gana o pierde al usuario.     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

# 11. Esquemas de Navegación

## 11.1 Qué Es

Un esquema de navegación sketcha la **estructura** del producto: qué pantallas
existen, cómo se conectan entre sí, y cuáles son los caminos posibles. Es el
plano arquitectónico antes de construir la casa.

## 11.2 Cuándo Usarlo

- Al inicio del proyecto para definir el alcance
- Para decidir qué va en la navegación principal
- Para definir la jerarquía de información
- Para comunicar estructura al equipo de desarrollo

## 11.3 Tipos de Estructura de Navegación

```
JERÁRQUICA (tree)              FLAT (hub-and-spoke)        LINEAL (wizard)

       Home                          Home                   Paso 1
      / | \                     /  |  |  \                    │
     /  |  \                   /   |  |   \                   ▼
   Cat  Sav  Perf           P1  P2  P3  P4               Paso 2
   / \                                                        │
  /   \                                                       ▼
 P1   P2                                                  Paso 3
                                                              │
                                                              ▼
                                                           Hecho


MATRICIAL (filtrada)           RED (social/content)

  ┌────────────────┐            A ←──→ B
  │  [Filtro 1 ▼]  │            ↕  ╲ ╱  ↕
  │  [Filtro 2 ▼]  │            C ←──→ D
  │  [Filtro 3 ▼]  │            ↕  ╱ ╲  ↕
  │  ─────────────  │            E ←──→ F
  │  Resultados     │
  │  dinámicos      │        (Todo conecta con todo
  └────────────────┘          — difícil pero poderoso)
```

## 11.4 Ejemplo — Esquema de Navegación de App E-commerce

```
NAVEGACIÓN PRINCIPAL (Tab Bar):

  [🏠 Home]  [🔍 Search]  [❤️ Saved]  [🛒 Cart]  [👤 Profile]
       │          │           │           │           │
       ▼          ▼           ▼           ▼           ▼


NIVEL 1 (Accesible desde tab bar):

  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
  │ Home │  │Search│  │Saved │  │ Cart │  │Profil│
  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘
     │         │         │         │         │
     ▼         ▼         ▼         ▼         ▼


NIVEL 2 (Requiere un tap desde nivel 1):

  Home ──→ Producto          Search ──→ Resultados
       ──→ Categoría                 ──→ Filtros (overlay)
       ──→ Ofertas
       ──→ Intereses         Saved ──→ Producto
                                    ──→ Checkout rápido

                             Cart ──→ Checkout
                                  ──→ Producto (editar)

                             Profile ──→ Pedidos
                                     ──→ Settings
                                     ──→ Direcciones


NIVEL 3 (Requiere dos taps desde nivel 1):

  Categoría ──→ Producto ──→ Reviews
  Resultados ──→ Producto ──→ Galería de imágenes
  Checkout ──→ Dirección ──→ Pago ──→ Confirmación
  Pedidos ──→ Detalle de pedido ──→ Tracking
```

## 11.5 Priorización por Jerarquía

```
┌─────────────────────────────────────────────────────────────┐
│  REGLA: La profundidad de navegación indica la prioridad.   │
│                                                             │
│  1 tap desde home  = Funcionalidad CORE                     │
│  2 taps desde home = Funcionalidad importante               │
│  3 taps desde home = Funcionalidad secundaria               │
│  4+ taps           = ⚠️ Riesgo de que el usuario no llegue  │
│                                                             │
│  Pregunta: ¿La acción más importante del usuario            │
│  está a máximo 2 taps de distancia?                         │
│                                                             │
│  Si la respuesta es NO → Reestructurar la navegación.       │
└─────────────────────────────────────────────────────────────┘
```

> **Ejemplo:** Si el objetivo principal es "comprar un producto", y llegar al botón
> "Agregar al carrito" requiere: Home → Categoría → Subcategoría → Producto (4 taps),
> considera agregar productos directamente en Home (1 tap) o un acceso rápido desde
> búsqueda (2 taps).

---

# 12. Estados de Pantalla (Screen States)

## 12.1 Qué Es

Sketchar screen states significa dibujar la **misma pantalla en diferentes momentos**
de la interacción: antes de que el usuario haga algo, mientras lo hace, después
de hacerlo, y cuando algo falla.

## 12.2 Los 5 Estados que Toda Pantalla Debe Tener

```
┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
│            │  │            │  │            │  │            │  │            │
│   EMPTY    │  │  LOADING   │  │   IDEAL    │  │   ERROR    │  │  PARTIAL   │
│   STATE    │  │   STATE    │  │   STATE    │  │   STATE    │  │   STATE    │
│            │  │            │  │            │  │            │  │            │
│ No hay     │  │ Cargando...│  │ Con datos  │  │ Algo salió │  │ Pocos      │
│ datos aún  │  │ skeleton   │  │ completos  │  │ mal        │  │ datos      │
│            │  │            │  │            │  │            │  │            │
└────────────┘  └────────────┘  └────────────┘  └────────────┘  └────────────┘
```

## 12.3 Ejemplo Detallado — Pantalla de Búsqueda

**Estado 1: Default (antes de buscar)**

```
┌──────────────────┐
│ ← Home      🛒   │
│──────────────────│
│                  │
│ [🔍 Buscar...]   │  ← Input vacío, placeholder visible
│                  │
│ Búsquedas        │
│ recientes:       │  ← Historial del usuario
│                  │
│  · zapatos nike  │
│  · mochila       │
│  · audifonos     │
│                  │
│ Trending:        │  ← Contenido dinámico
│  🔥 Summer sale  │
│  🔥 New arrivals │
│                  │
│──────────────────│
│ 🏠 🔍 ❤️ 👤      │
└──────────────────┘
```

**Estado 2: Typing (escribiendo)**

```
┌──────────────────┐
│                  │
│ [🔍 zapa█    ✕ ] │  ← Input activo, botón clear visible
│──────────────────│
│                  │
│  🔍 zapatos      │  ← Autocompletado
│  🔍 zapatos nike │
│  🔍 zapatillas   │
│  🔍 zapatos mujer│
│                  │
│                  │
│                  │
│                  │
│                  │
│──────────────────│
│ ┌──────────────┐ │
│ │   BUSCAR     │ │  ← Teclado del sistema
│ └──────────────┘ │
│ [Q][W][E][R][T]  │
│ [A][S][D][F][G]  │
│ [Z][X][C][V][B]  │
└──────────────────┘
```

**Estado 3: Resultados (con datos)**

```
┌──────────────────┐
│ ← "zapatos"  ⚙  │
│──────────────────│
│ 24 resultados    │
│ [Precio▼][Marca] │  ← Filtros rápidos
│──────────────────│
│ ┌──────┐         │
│ │ IMG  │ Nike    │
│ │      │ Air Max │
│ └──────┘ $129  ♡ │
│──────────────────│
│ ┌──────┐         │
│ │ IMG  │ Adidas  │
│ │      │ Ultra   │
│ └──────┘ $95   ♡ │
│──────────────────│
│ 🏠 🔍 ❤️ 👤      │
└──────────────────┘
```

**Estado 4: Sin resultados (empty state)**

```
┌──────────────────┐
│ ← "xyzabc"   ⚙  │
│──────────────────│
│                  │
│                  │
│     🔍           │
│                  │
│  No encontramos  │
│  resultados para │
│  "xyzabc"        │
│                  │
│  Sugerencias:    │
│  · Revisa la     │
│    ortografía    │
│  · Prueba con    │
│    menos filtros │
│                  │
│  [Ver categorías]│  ← Acción alternativa (no dead-end)
│──────────────────│
│ 🏠 🔍 ❤️ 👤      │
└──────────────────┘
```

**Estado 5: Error (fallo de conexión)**

```
┌──────────────────┐
│ ← "zapatos"   ⚙ │
│──────────────────│
│                  │
│                  │
│      ⚠️          │
│                  │
│  Sin conexión    │
│                  │
│  Revisa tu       │
│  conexión a      │
│  internet e      │
│  inténtalo de    │
│  nuevo.          │
│                  │
│  [  Reintentar ] │  ← Siempre dar una acción recuperable
│                  │
│──────────────────│
│ 🏠 🔍 ❤️ 👤      │
└──────────────────┘
```

## 12.4 Overlay como Screen State

```
Estado: Filtros abiertos (overlay)

┌──────────────────┐
│░░░░░░░░░░░░░░░░░░│  ← Fondo oscurecido (indica contexto anterior)
│░░░░░░░░░░░░░░░░░░│
│┌────────────────┐│
││ Filtros      ✕ ││  ← Título + cerrar
││────────────────││
││ Precio:        ││
││ [$50]──[$200]  ││  ← Range slider
││                ││
││ Marca:         ││
││ ☑ Nike         ││
││ ☑ Adidas       ││
││ ☐ Puma         ││
││ ☐ Reebok       ││
││                ││
││ ★★★★☆ y más   ││  ← Filtro por rating
││                ││
││ ┌────────────┐ ││
││ │  APLICAR   │ ││
││ │ (24 result)│ ││  ← Muestra count en tiempo real
││ └────────────┘ ││
│└────────────────┘│
└──────────────────┘
```

---

# 13. Micro-interacciones y Gestos

## 13.1 Qué Son

Las micro-interacciones son los pequeños momentos de feedback que guían al
usuario: un botón que cambia de color al presionarlo, un toast que confirma
una acción, un pull-to-refresh. Son difíciles de sketchar, pero esenciales
de **pensar** durante el sketching.

## 13.2 Cómo Anotar Micro-interacciones

```
No necesitas animarlas — necesitas DOCUMENTARLAS:

┌──────────────┐              ┌──────────────┐
│              │   (tap)      │              │
│ [♡ Guardar]  │ ──────────→  │ [❤️ Guardado] │
│              │              │              │
│  Estado:     │              │  Estado:     │
│  default     │              │  activo      │
│              │              │              │
│  Anotación:  │              │  Anotación:  │
│  Borde gris  │              │  Fill rojo   │
│  Icono vacío │              │  Escala 1.2x │
│              │              │  + haptic    │
│              │              │  + toast     │
│              │              │  "Guardado"  │
└──────────────┘              └──────────────┘
```

## 13.3 Micro-interacciones Comunes para Sketchar

| Interacción | Sketchar Como | Anotación |
|---|---|---|
| **Pull to refresh** | Flecha ↓ sobre la lista | "Indicador de carga, recargar contenido" |
| **Swipe to delete** | Card desplazada + ícono 🗑 | "Swipe left revela acción destructiva" |
| **Toast / Snackbar** | Rectángulo pequeño inferior | "Aparece 3seg, autocierra, con undo" |
| **Loading skeleton** | Rectángulos grises animados | "Placeholder con pulse animation" |
| **Shake on error** | Línea zigzag junto al input | "Input vibra si validación falla" |
| **Expandir / Colapsar** | Flecha ▼ / ▲ | "Accordion: tap muestra/oculta contenido" |
| **Carousel** | Puntos ● ● ○ ○ bajo imágenes | "Swipe horizontal, indicador de posición" |
| **Bottom sheet** | Rectángulo inferior con handle | "Drag up para expandir, drag down para cerrar" |
| **Floating Action Button** | Círculo con + | "FAB fijo en esquina, acción primaria" |

## 13.4 Pensar en Motion Temprano

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Si dejas la motion para el final, tendrás:             │
│                                                             │
│  → Transiciones que no se sienten naturales                 │
│  → Feedback que confunde en lugar de guiar                  │
│  → Animaciones decorativas que no aportan                   │
│  → Developers que implementan lo que pueden, no lo ideal    │
│                                                             │
│  Preguntas para cada pantalla:                              │
│                                                             │
│  → ¿Cómo LLEGA el usuario aquí?                            │
│    (push desde derecha, fade in, slide up)                  │
│  → ¿Cómo SE VA de aquí?                                    │
│    (slide out, collapse, fade)                              │
│  → ¿Qué CONFIRMA que una acción se completó?               │
│    (checkmark, color change, haptic)                        │
│  → ¿Qué indica que algo está PROCESANDO?                   │
│    (spinner, skeleton, progress bar)                        │
└─────────────────────────────────────────────────────────────┘
```

---

# PARTE IV — PRINCIPIOS UX APLICADOS AL SKETCHING

---

# 14. Jerarquía Visual

## 14.1 Qué Es

Jerarquía visual es el orden en que el ojo del usuario procesa la información
en una pantalla. Un buen sketch establece esta jerarquía desde el principio
— antes de colores, tipografía o espaciado exacto.

## 14.2 Establecer Jerarquía con Peso Visual

```
En un sketch, controlas jerarquía con:

  ┌────────────────────────────────────────────┐
  │                                            │
  │  GRANDE           = Importante             │
  │  ████████         = Muy importante         │
  │  ┌──────────────┐ = Llama la atención      │
  │  │  CONTENEDOR  │                          │
  │  └──────────────┘                          │
  │                                            │
  │  Mediano          = Secundario             │
  │  ████             = Soporte                │
  │                                            │
  │  pequeño          = Terciario              │
  │  ██               = Metadata               │
  │                                            │
  └────────────────────────────────────────────┘

  Tamaño    → Más grande = más importante
  Grosor    → Más grueso = más peso visual
  Posición  → Arriba/izquierda = se lee primero
  Contraste → Más oscuro/llenado = más prominente
  Espacio   → Más espacio alrededor = más importancia
```

## 14.3 Ejemplo — Jerarquía en Product Card

```
   ❌ Sin jerarquía               ✅ Con jerarquía

┌──────────────────┐          ┌──────────────────┐
│                  │          │ ┌──────────────┐  │
│ nombre producto  │          │ │              │  │
│ precio           │          │ │    IMAGEN    │  │  ← Área visual grande
│ descripcion      │          │ │    (grande)  │  │     captura atención
│ reviews          │          │ └──────────────┘  │
│ boton            │          │                   │
│                  │          │ NOMBRE PRODUCTO   │  ← Título prominente
│ (todo del mismo  │          │ ★★★★☆ (127)      │  ← Social proof
│  tamaño, nada    │          │                   │
│  destaca)        │          │ $129.99           │  ← Precio claro
│                  │          │                   │
│                  │          │ ┌──────────────┐  │
│                  │          │ │   COMPRAR    │  │  ← CTA prominente
│                  │          │ └──────────────┘  │
└──────────────────┘          └──────────────────┘
```

## 14.4 La Regla de los 3 Niveles

```
Cada pantalla debe tener MÁXIMO 3 niveles de jerarquía claros:

  Nivel 1 (Primario):   1-2 elementos  → Lo que quieres que vea PRIMERO
  Nivel 2 (Secundario): 2-4 elementos  → Lo que necesita para DECIDIR
  Nivel 3 (Terciario):  Todo lo demás  → Disponible pero no intrusivo

  Si todo es importante → nada es importante.
  Si tienes 4+ niveles → la pantalla está sobrecargada.
```

---

# 15. Affordances y Señales

## 15.1 Qué Es

Una affordance es una señal visual que indica al usuario qué puede hacer con
un elemento. En un sketch, necesitas asegurar que los elementos interactivos
se **vean** interactivos.

## 15.2 Affordances en Sketch

```
ELEMENTO         CÓMO SKETCHARLO                 SEÑAL QUE COMUNICA
─────────────────────────────────────────────────────────────────────
Botón            [  TEXTO  ]                     "Puedo presionarme"
                 Rectángulo con borde/fill

Link             texto subrayado                 "Puedo hacer click"

Input            [____________]                  "Puedo escribir aquí"
                 Rectángulo vacío con línea

Toggle           [○━━━━━━━━━]                    "Puedo activar/desactivar"

Checkbox         ☐ Opción                        "Puedo seleccionar"

Card clickable   ┌─────────────┐                 "Soy un contenedor
                 │   >         │                  interactivo"
                 └─────────────┘                  (chevron indica acción)

Swipeable        ● ● ○ ○                         "Hay más contenido
                                                  a los lados"

Scrollable       ───────                         "Hay contenido abajo"
                 (contenido cortado)              (cortar a la mitad
                                                  un elemento)

Draggable        ≡ Item                          "Puedo reordenarme"
                 (hamburger handle)
```

## 15.3 Error Común — Affordance Ambigua

```
   ❌ ¿Es un botón o un texto?         ✅ Claramente un botón

     Agregar al carrito                 ┌──────────────────┐
                                        │ AGREGAR AL CARRO │
     (parece un label,                  └──────────────────┘
      no invita al click)
                                        (tiene contenedor,
                                         invita a presionar)

   ❌ ¿Puedo hacer click aquí?         ✅ Claramente clickable

   ┌──────────────────┐                ┌──────────────────┐
   │  Juan Pérez      │                │  Juan Pérez    > │
   │  Último pedido   │                │  Último pedido   │
   └──────────────────┘                └──────────────────┘
                                        (chevron > indica
                                         que hay una acción)
```

---

# 16. Patrones de Diseño Comunes

## 16.1 Patrones de Navegación Mobile

```
TAB BAR (iOS)               NAV DRAWER (Android)       BOTTOM SHEET
┌──────────────┐            ┌──────────────┐           ┌──────────────┐
│              │            │ ☰           │           │              │
│              │            │──────────────│           │              │
│  Contenido   │            │  Contenido   │           │──────────────│
│              │            │              │           │ ── handle ── │
│              │            │              │           │              │
│──────────────│            │              │           │  Opciones    │
│ 🏠 🔍 ❤️ 👤  │            │              │           │  del sheet   │
└──────────────┘            └──────────────┘           │              │
 (3-5 items máx)            (menú lateral              └──────────────┘
                             deslizable)               (acciones
                                                        contextuales)
```

## 16.2 Patrones de Contenido

```
LIST VIEW                   GRID VIEW                  CARD VIEW
┌──────────────┐            ┌──────────────┐           ┌──────────────┐
│ ──────────── │            │ ┌──┐  ┌──┐  │           │ ┌──────────┐ │
│ ──────────── │            │ │  │  │  │  │           │ │          │ │
│ ──────────── │            │ └──┘  └──┘  │           │ │  IMG     │ │
│ ──────────── │            │ ┌──┐  ┌──┐  │           │ │          │ │
│ ──────────── │            │ │  │  │  │  │           │ └──────────┘ │
│              │            │ └──┘  └──┘  │           │  Título      │
└──────────────┘            └──────────────┘           │  Descripción │
 Emails, mensajes,          Fotos, productos,          │ [Acción]     │
 contactos, settings        galería, icons             └──────────────┘
                                                        E-commerce,
                                                        noticias, social
```

## 16.3 Patrones de Input

```
SEARCH BAR                  FORM                       MULTI-STEP
┌──────────────┐            ┌──────────────┐           ┌──────────────┐
│ [🔍 Buscar..]│            │ Nombre:      │           │ ① ──② ── ③  │
│              │            │ [__________] │           │──────────────│
│ Resultados   │            │              │           │              │
│ en tiempo    │            │ Email:       │           │ Paso 2 de 3  │
│ real debajo  │            │ [__________] │           │              │
│              │            │              │           │ [contenido   │
│              │            │ [  Enviar  ] │           │  del paso]   │
│              │            │              │           │              │
└──────────────┘            └──────────────┘           │[Atrás][Sigue]│
                                                       └──────────────┘
```

## 16.4 Patrones de Feedback

```
TOAST / SNACKBAR            MODAL / DIALOG             INLINE ERROR
┌──────────────┐            ┌──────────────┐           ┌──────────────┐
│              │            │░░░░░░░░░░░░░░│           │              │
│              │            │░┌──────────┐░│           │ Email:       │
│  Contenido   │            │░│  ¿Seguro? │░│           │ [invalid@  ] │
│  normal      │            │░│          │░│           │ ⚠ Email no   │
│              │            │░│ Eliminar  │░│           │   válido     │
│              │            │░│ este item │░│           │              │
│──────────────│            │░│          │░│           │              │
│ ✅ Guardado  │            │░│[No] [Sí] │░│           │              │
│       [Undo] │            │░└──────────┘░│           │              │
└──────────────┘            │░░░░░░░░░░░░░░│           └──────────────┘
 (temporal,                  └──────────────┘           (junto al
  no intrusivo)              (bloquea                    elemento,
                              interacción)               no intrusivo)
```

---

# 17. Principios de Usabilidad en Papel

## 17.1 Leyes UX que Impactan tus Sketches

| Ley / Principio | Qué Dice | Cómo Afecta el Sketch |
|---|---|---|
| **Ley de Fitts** | Elementos más grandes y cercanos son más fáciles de tocar | CTAs principales deben ser grandes, en zona de pulgar |
| **Ley de Hick** | Más opciones = más tiempo para decidir | Máximo 5-7 opciones visibles por pantalla |
| **Ley de Miller** | La memoria de trabajo retiene 7±2 items | Agrupar información en chunks de 3-5 |
| **Ley de Proximidad** | Elementos cercanos se perciben como grupo | Agrupar elementos relacionados, separar los distintos |
| **Ley de Jakob** | Los usuarios prefieren lo que ya conocen | Usar patrones estándar (tab bar abajo, búsqueda arriba) |
| **Principio de Pareto** | 80% de usuarios usa 20% de funciones | Esas funciones deben ser las más accesibles |
| **Efecto von Restorff** | Lo diferente se recuerda | El CTA principal debe verse diferente al resto |

## 17.2 Zonas de Alcance del Pulgar (Mobile)

```
┌──────────────────┐
│ ╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳│  ← DIFÍCIL: Settings, filtros,
│ ╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳│    acciones secundarias
│ ─ ─ ─ ─ ─ ─ ─ ─ │
│ ░░░░░░░░░░░░░░░░░│  ← MEDIO: Contenido scrollable,
│ ░░░░░░░░░░░░░░░░░│    información principal
│ ░░░░░░░░░░░░░░░░░│
│ ─ ─ ─ ─ ─ ─ ─ ─ │
│ ████████████████ │  ← FÁCIL: Tab bar, CTA principal,
│ ████████████████ │    acciones más frecuentes
│ ████████████████ │
└──────────────────┘

  ████ = Zona natural del pulgar (fácil acceso)
  ░░░░ = Zona de estiramiento (requiere esfuerzo)
  ╳╳╳╳ = Zona difícil (esquinas superiores)

  → CTAs PRINCIPALES → zona inferior
  → Navegación → tab bar inferior
  → Acciones destructivas → zona superior (difícil = intencional)
```

## 17.3 Above the Fold

```
┌──────────────────────────────────────────┐
│                                          │
│   Lo que el usuario ve SIN SCROLLEAR     │
│   debe responder:                        │
│                                          │
│   1. ¿Dónde estoy?                       │
│   2. ¿Qué puedo hacer aquí?              │
│   3. ¿Por qué me interesa?               │
│                                          │
│ ═══════════════ THE FOLD ═════════════   │
│                                          │
│   Contenido secundario aquí              │
│                                          │
│   El contenido below the fold NO está    │
│   muerto — pero necesita una SEÑAL de    │
│   que hay más (un elemento cortado a     │
│   la mitad que invite al scroll).        │
│                                          │
└──────────────────────────────────────────┘
```

---

# PARTE V — VOCABULARIO VISUAL: COMPONENTES EN SKETCH

---

# 18. Bloques Básicos de Construcción

## 18.1 Los 5 Elementos Atómicos

Todo lo que sketches se construye con estas 5 primitivas:

```
1. RECTÁNGULO          2. LÍNEA              3. CÍRCULO
   ┌──────────┐           ──────────            ○
   │          │
   │          │        Texto, separadores,    Avatares, iconos,
   └──────────┘        indicadores            estados, bullets

   Contenedores,
   botones, inputs,     4. TEXTO              5. ÍCONO
   cards, imágenes
                           Aa Bb Cc           ☰  🔍  ✕  ♡  🛒

                        Títulos, body,        Acciones rápidas,
                        labels                navegación
```

## 18.2 Cómo Representar Texto

```
TÍTULO (prominente):        ═══════════════════

SUBTÍTULO:                  ─────────────────

BODY TEXT (párrafo):        ─────────────────────
                            ─────────────────────
                            ─────────────────

LABEL (pequeño):            ── ── ──

ENLACE:                     ___________ (subrayado)

PRECIO:                     $XXX (escribir número real)

PLACEHOLDER:                [  texto gris...  ]
```

> **Tip:** Siempre usa contenido real en los sketches refinados (Fase 2).
> "Lorem ipsum" oculta problemas de longitud, truncado y jerarquía.
> Usa datos reales: nombres creíbles, precios reales, textos del largo esperado.

---

# 19. Componentes UI en Sketch

## 19.1 Librería Visual de Referencia

```
──────────── NAVEGACIÓN ────────────

Header:                    Tab Bar:
┌──────────────────────┐   ┌──────────────────────┐
│ ← Título       ⚙ 🛒 │   │ 🏠  🔍  +  ❤️  👤   │
└──────────────────────┘   └──────────────────────┘

Breadcrumb:                Segmented Control:
Home > Categoría > Item    [ Opción A | Opción B ]


──────────── INPUTS ────────────

Text Input:                Search:
  Label                    [🔍 Buscar...         ]
  [________________]

Password:                  Text Area:
  [••••••••    👁]         ┌────────────────────┐
                           │                    │
                           │                    │
                           └────────────────────┘

Dropdown:                  Date Picker:
  [Seleccionar     ▼]     [📅 DD / MM / AAAA   ]


──────────── SELECCIÓN ────────────

Checkbox:                  Radio:
  ☑ Opción A               ● Opción A
  ☐ Opción B               ○ Opción B
  ☐ Opción C               ○ Opción C

Toggle:                    Chips:
  [━━━━━━━━●]  On         [  Tag 1  ✕]  [  Tag 2  ✕]
  [●━━━━━━━━]  Off


──────────── CONTENIDO ────────────

Card:                      List Item:
┌──────────────────┐       ┌──────────────────────┐
│ ┌──────────────┐ │       │ (○) Título          >│
│ │    IMAGEN    │ │       │     Subtítulo         │
│ └──────────────┘ │       └──────────────────────┘
│ Título           │
│ Descripción      │       Avatar + Info:
│ [  Acción  ]     │       ┌──────────────────────┐
└──────────────────┘       │ (○) Nombre            │
                           │     @username          │
                           └──────────────────────┘

Image Placeholder:         Skeleton / Loading:
┌──────────────────┐       ┌──────────────────┐
│       ✕          │       │ ░░░░░░░░░░░░░░░░ │
│     (imagen)     │       │ ░░░░░░░░         │
│                  │       │ ░░░░░░░░░░░░░    │
└──────────────────┘       └──────────────────┘


──────────── ACCIONES ────────────

Primary Button:            Secondary Button:
┌──────────────────┐       ┌──────────────────┐
│ ████ COMPRAR ████│       │   CANCELAR       │
└──────────────────┘       └──────────────────┘
(relleno / prominente)     (solo borde / sutil)

Icon Button:               FAB:
  [ 🗑 ]  [ ✏️ ]  [ ♡ ]      (  +  )

Link Button:
  Ver todos →


──────────── FEEDBACK ────────────

Toast:                     Badge:
┌──────────────────────┐      🛒 (3)
│ ✅ Guardado    [Undo]│
└──────────────────────┘

Progress Bar:              Spinner:
[████████░░░░░░] 60%         ◌ Cargando...

Alert / Banner:
┌──────────────────────────┐
│ ⚠️ Tu sesión expira en 5m│
└──────────────────────────┘
```

---

# 20. Anotaciones y Convenciones

## 20.1 Sistema de Anotaciones

```
Tipo de anotación y cómo usarla:

  ──── Línea + texto    Para explicar un elemento específico
       │
       └─→ "Este botón solo aparece
            si hay items en el carrito"


  [N]  Número en círculo   Para referenciar en discusiones
       [1] Login
       [2] Validación
       [3] Dashboard


  ⚡   Rayo               Para indicar interacción
       ⚡ Tap → abre modal


  ⚠️    Triángulo          Para señalar un riesgo o duda
       ⚠️ ¿Y si no hay conexión?


  ✅   Check               Para decisión tomada
       ✅ Aprobado por PM


  ❓   Pregunta            Para items pendientes de resolver
       ❓ ¿Qué copy va aquí?


  💡   Idea                Para propuesta a discutir
       💡 Quizá un onboarding tooltip
```

## 20.2 Convenciones de Color (si usas marcadores)

| Color | Uso | Ejemplo |
|---|---|---|
| **Negro** | Estructura, layout, texto | Todos los elementos base |
| **Gris claro** | Sombras, fondos, separación | Placeholders de imagen |
| **Azul** | Links, interacciones, CTAs | "Tap aquí" |
| **Rojo** | Errores, alertas, items críticos | "Estado de error" |
| **Verde** | Éxito, confirmación | "✅ Acción completada" |
| **Amarillo** | Advertencias, notas | "⚠️ Revisar con dev" |

---

# 21. Layouts y Grids en Sketch

## 21.1 Layouts Mobile Comunes

```
LAYOUT A:                LAYOUT B:              LAYOUT C:
Full-width               Split content          Card feed

┌──────────────┐         ┌──────────────┐       ┌──────────────┐
│   Header     │         │   Header     │       │   Header     │
│──────────────│         │──────────────│       │──────────────│
│              │         │ ┌────┐┌────┐ │       │ ┌──────────┐ │
│    HERO      │         │ │    ││    │ │       │ │ Card 1   │ │
│   (imagen    │         │ │    ││    │ │       │ └──────────┘ │
│    grande)   │         │ └────┘└────┘ │       │ ┌──────────┐ │
│              │         │ ┌────┐┌────┐ │       │ │ Card 2   │ │
│──────────────│         │ │    ││    │ │       │ └──────────┘ │
│   Título     │         │ │    ││    │ │       │ ┌──────────┐ │
│   Contenido  │         │ └────┘└────┘ │       │ │ Card 3   │ │
│              │         │              │       │ └──────────┘ │
│──────────────│         │──────────────│       │──────────────│
│   Tab Bar    │         │   Tab Bar    │       │   Tab Bar    │
└──────────────┘         └──────────────┘       └──────────────┘

Ideal para:              Ideal para:             Ideal para:
Landing, producto,       Categorías, grid        Feed, timeline,
artículo                 de productos            social media
```

## 21.2 Layouts Desktop Comunes

```
LAYOUT A: Sidebar + Content

┌──────────────────────────────────────────────────┐
│  Logo          Nav 1    Nav 2    Nav 3     🔍 👤 │
│──────────────────────────────────────────────────│
│ ┌─────────┐ ┌────────────────────────────────┐   │
│ │         │ │                                │   │
│ │ Sidebar │ │      Contenido principal       │   │
│ │         │ │                                │   │
│ │ • Item  │ │                                │   │
│ │ • Item  │ │                                │   │
│ │ • Item  │ │                                │   │
│ │         │ │                                │   │
│ └─────────┘ └────────────────────────────────┘   │
└──────────────────────────────────────────────────┘

LAYOUT B: Dashboard (2-3 columnas)

┌──────────────────────────────────────────────────┐
│  Logo          Nav 1    Nav 2    Nav 3     🔍 👤 │
│──────────────────────────────────────────────────│
│  ┌──────────────────────────────────────────┐    │
│  │           KPI / Hero / Summary           │    │
│  └──────────────────────────────────────────┘    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Widget 1 │  │ Widget 2 │  │ Widget 3 │       │
│  └──────────┘  └──────────┘  └──────────┘       │
│  ┌─────────────────────┐  ┌─────────────────┐   │
│  │   Tabla / Lista     │  │  Gráfico        │   │
│  └─────────────────────┘  └─────────────────┘   │
└──────────────────────────────────────────────────┘
```

## 21.3 Responsive: Mismo Contenido, Diferente Layout

```
DESKTOP                    TABLET                   MOBILE

┌─────────────────────┐   ┌─────────────────┐    ┌──────────┐
│ [IMG] Título        │   │ [IMG]           │    │ [IMAGEN] │
│       Descripción   │   │ Título          │    │          │
│       $99 [Comprar] │   │ Desc            │    │ Título   │
└─────────────────────┘   │ $99 [Comprar]   │    │ Desc     │
                          └─────────────────┘    │ $99      │
 Horizontal layout         Vertical compacto     │[Comprar] │
                                                 └──────────┘
                                                  Full vertical
```

---

# PARTE VI — BUENAS PRÁCTICAS Y ANTI-PATRONES

---

# 22. Buenas Prácticas

## 22.1 Las 15 Reglas del Sketching Efectivo

| # | Regla | Por qué |
|---|---|---|
| 1 | **No te preocupes por lo feo** | El propósito es comunicar ideas, no crear arte |
| 2 | **Siempre usa time-boxing** | Presión = productividad, no perfeccionismo |
| 3 | **Genera antes de evaluar** | Divergir primero, converger después — nunca al mismo tiempo |
| 4 | **Titula cada sketch** | Sin título → olvidarás qué pantalla era en 48 horas |
| 5 | **Numera la secuencia** | Facilita discusiones: "pantalla 3 necesita cambios" |
| 6 | **Anota SIEMPRE** | Las anotaciones capturan el "por qué", no solo el "qué" |
| 7 | **Usa contenido real** | "Lorem ipsum" oculta problemas de longitud y jerarquía |
| 8 | **Sketcha los 5 estados** | Empty, loading, ideal, error, partial — todos importan |
| 9 | **Piensa en mobile first** | Es más fácil expandir a desktop que comprimir desde desktop |
| 10 | **Comparte temprano** | Un sketch no compartido es una idea que no se validó |
| 11 | **Habla con developers** | "¿Es factible?" antes de invertir horas de diseño |
| 12 | **Guarda tus sketches** | Escanea o fotografía inmediatamente — el papel se pierde |
| 13 | **Cuelga sketches visibles** | En la pared, monitor, pizarra — sirve de recordatorio |
| 14 | **Sketcha alternativas** | Mínimo 3 opciones antes de decidir |
| 15 | **Prototipa en papel** | Antes de Figma, prueba el flujo con hojas recortadas |

## 22.2 Flujo de Trabajo Profesional

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. BRIEF / PROBLEMA                                            │
│     └─→ Leer brief, entender usuarios, definir scope            │
│                                                                 │
│  2. SKETCH EXPLORATORIO (20-30 min)                             │
│     └─→ Crazy 8s o sketches rápidos, sin juzgar                 │
│                                                                 │
│  3. SELECCIÓN (10 min)                                          │
│     └─→ Elegir 2-3 direcciones prometedoras                     │
│                                                                 │
│  4. SKETCH DETALLADO (30-60 min)                                │
│     └─→ Refinar las seleccionadas con anotaciones               │
│                                                                 │
│  5. FEEDBACK RÁPIDO (15-30 min)                                 │
│     └─→ Mostrar a PM, dev, otro diseñador                       │
│                                                                 │
│  6. ITERAR (15-30 min)                                          │
│     └─→ Incorporar feedback, resolver dudas                     │
│                                                                 │
│  7. TRANSFERIR A DIGITAL                                        │
│     └─→ Wireframes en Figma basados en los sketches             │
│         (NO empezar de cero en Figma)                           │
│                                                                 │
│  Tiempo total: 2-3 horas antes de abrir Figma                   │
│  Resultado: Dirección validada, menos retrabajo                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# 23. Anti-Patrones y Errores Comunes

## 23.1 Tabla de Anti-Patrones

| Anti-Patrón | Problema | Solución |
|---|---|---|
| **Saltar directo a Figma** | Te casas con la primera idea, no exploras alternativas | Sketcha 5+ opciones antes de tocar cualquier herramienta digital |
| **Sketch único** | Una sola opción = sesgo de anclaje | Mínimo 3 variantes para cualquier pantalla o flujo |
| **Perfeccionismo en papel** | Pierdes tiempo en estética, no en ideas | Time-box de 1-2 min por sketch. Feo está bien. |
| **Sin anotaciones** | En 3 días no entenderás tu propio sketch | Anota intención, interacciones, y decisiones |
| **Solo happy path** | Ignoras errores, estados vacíos, edge cases | Sketcha explícitamente: empty, error, loading |
| **Sketchar solo** | Pierdes perspectivas valiosas | Design Studio: sketchar juntos, compartir, iterar |
| **No guardar sketches** | Ideas perdidas, contexto perdido | Foto/scan inmediato. Carpeta dedicada. |
| **Lorem ipsum** | No descubres problemas de contenido real | Usa nombres, precios, textos del largo esperado |
| **Ignorar restricciones** | Sketches inviables técnicamente | Consulta con dev ANTES de refinar |
| **Sketches sin objetivo** | Dibujar sin dirección = time waste | Define el problema en una oración antes de empezar |
| **Todo es importante** | Sin jerarquía visual = usuario perdido | Máximo 3 niveles: primario, secundario, terciario |
| **Copiar competitors** | Soluciones genéricas, sin diferenciación | Estudia patrones, pero diseña para TUS usuarios |
| **Ignorar mobile constraints** | Zonas del pulgar, teclado, one-hand use | Sketcha con template de dispositivo a escala real |
| **Motion al final** | Transiciones que no encajan | Documenta transiciones durante el sketching |

## 23.2 Señales de que tus Sketches Necesitan Mejora

```
⚠️  Tu equipo necesita que EXPLIQUES cada sketch
    → Solución: Mejor jerarquía, títulos, anotaciones

⚠️  Siempre terminas con 1 sola opción
    → Solución: Usa Crazy 8s o genera 5 antes de evaluar

⚠️  Tus wireframes en Figma son muy diferentes a los sketches
    → Solución: Más detalle en Fase 2 del sketching

⚠️  Developers encuentran problemas que no previste
    → Solución: Sketcha los 5 estados + consulta temprana

⚠️  Nunca miras tus sketches anteriores
    → Solución: Organiza en carpetas por proyecto/fecha
```

---

# 24. Checklist de Calidad

## 24.1 Antes de Pasar a Digital

```
POR PANTALLA:
  □ Tiene título identificable
  □ Tiene número de secuencia
  □ Header/Nav están definidos
  □ Jerarquía visual clara (3 niveles máximo)
  □ CTAs prominentes y en zona accesible (mobile)
  □ Contenido usa datos realistas
  □ Elementos interactivos tienen affordance clara
  □ Anotaciones explican decisiones no obvias

POR FLUJO:
  □ Happy path completo y numerado
  □ Mínimo 2 flujos alternativos contemplados
  □ Empty state sketchado
  □ Error state sketchado
  □ Loading state considerado
  □ Transiciones/animaciones documentadas
  □ Flechas indican dirección de navegación

POR SESIÓN:
  □ Mínimo 3 variantes exploradas
  □ Compartido con al menos 1 persona
  □ Feedback incorporado
  □ Sketches fotografiados/escaneados
  □ Decisiones clave documentadas
  □ Dudas listadas para resolver
```

---

# PARTE VII — INSPIRACIÓN Y CRECIMIENTO

---

# 25. Cómo Mantenerse Inspirado

## 25.1 La Creatividad es un Músculo

```
La creatividad no es un don — es una práctica.
Si no la ejercitas, se atrofia.

  ┌──────────────────────────────────────────────┐
  │  Hábito                      Frecuencia      │
  │  ─────────────────────────────────────────── │
  │  Hablar con peers            Diariamente     │
  │  Estudiar trabajo de otros   2-3x por semana │
  │  Leer (diseño y otros)       Semanalmente    │
  │  Diseñar para ti mismo       Mensualmente    │
  │  Salir a caminar             Cuando te atasques│
  │  Explorar nueva disciplina   Trimestralmente │
  └──────────────────────────────────────────────┘
```

## 25.2 Estrategias Probadas

**1. Habla con tus peers**

Las conversaciones con colegas — sobre diseño, desarrollo, producto o cualquier
tema — son la fuente de inspiración más subestimada. Un café con un compañero
puede desbloquear una idea que no encontrarías en Dribbble.

**2. Estudia (no copies) el trabajo de otros**

```
No hagas esto:        Haz esto:
"Me gusta ese         "¿Por qué funciona esta navegación?"
 diseño, voy a        "¿Qué problema están resolviendo?"
 copiarlo"            "¿Qué trade-off hicieron?"
                      "¿Funcionaría esto para MIS usuarios?"
```

Crea una colección categorizada de soluciones que admiras. No por lo bonitas,
sino por lo efectivas. Organízalas por patrón de diseño: onboarding, checkout,
búsqueda, navegación, formularios.

**3. Rodéate de buen diseño**

Tu entorno físico influye en tu output creativo. Un escritorio organizado,
buena iluminación, tus sketches pegados en la pared — todo contribuye a mantener
el cerebro en "modo diseño".

**4. Educa sin parar**

| Categoría | Por qué | Fuentes |
|---|---|---|
| **Diseño UX/UI** | Tu disciplina core | Nielsen Norman, Smashing Magazine, UX Collective |
| **Desarrollo** | Saber qué es factible | CSS-Tricks, MDN, dev.to |
| **Producto** | Entender métricas y negocio | Lenny's Newsletter, Reforge |
| **Psicología** | Entender comportamiento humano | "Don't Make Me Think", "Thinking Fast and Slow" |
| **Otras disciplinas** | Perspectivas inesperadas | Arquitectura, tipografía, cine, música |

**5. Diseña para ti mismo**

Cuando un proyecto largo te drena, diseña algo personal. Una app que tú quieras,
un rediseño por diversión, un concept art. El objetivo no es publicarlo — es
recargar tu creatividad.

**6. Camina**

Un estudio de Stanford (2014) demostró que caminar incrementa el pensamiento
creativo en un 60%. Cuando estés atascado: levántate, sal, camina 15 minutos.
La solución probablemente aparezca en el minuto 8.

---

# 26. Fuentes de Inspiración Online

## 26.1 Plataformas Principales

| Plataforma | Tipo | Mejor Para | Costo |
|---|---|---|---|
| **Dribbble** | Showcases de diseño | Screenshots de UI, colecciones temáticas | Gratis (premium disponible) |
| **Behance** | Case studies de diseño | Proyectos completos con proceso | Gratis |
| **Pinterest** | Colección visual general | Agregar de cualquier fuente, boards organizados | Gratis |
| **Mobbin** | Patrones mobile reales | Screenshots de apps reales categorizados por patrón | Freemium |
| **Awwwards** | Sitios web premiados | Tendencias web, experiencias interactivas | Gratis |
| **Pttrns** | Patrones mobile | UI patterns específicos por categoría | Freemium |
| **UI Garage** | Colección de diseño | Patterns específicos de UI | Gratis |
| **Screenlane** | Screenshots de UI | Flows completos de apps reales | Freemium |

## 26.2 Cómo Usar Dribbble Efectivamente

```
No hagas:
  → Scrollear sin rumbo por la home
  → Guardar solo lo "bonito"
  → Copiar soluciones sin entenderlas

Haz esto:
  1. Busca por PATRÓN: "mobile navigation", "checkout flow", "search UI"
  2. Guarda en COLECCIONES temáticas (una por patrón de diseño)
  3. Anota POR QUÉ guardaste cada referencia
  4. Estudia la ESTRUCTURA, no la estética
  5. Pregunta: "¿Esto resolvería el problema de MI usuario?"
```

## 26.3 Cómo Usar Behance Efectivamente

```
Ventaja sobre Dribbble:
  → Behance muestra el PROCESO, no solo el resultado
  → Case studies completos con problema → solución
  → Más profundidad, menos vanity shots

Busca:
  → El "challenge" que describe el diseñador
  → El proceso de investigación
  → Las decisiones de diseño y por qué
  → Los resultados / métricas
```

## 26.4 Centralizar la Inspiración

```
Estrategia recomendada:

  Fuente primaria → Dribbble (UI rápido)
                  → Behance (procesos completos)
                  → Mobbin (apps reales)

  Centralizar en → Pinterest (boards organizados)
               o → Figma (archivo de referencia)
               o → Notion / Eagle / Milanote

  Organizar por:
    ├── Navegación
    ├── Búsqueda
    ├── Onboarding
    ├── Checkout / Pago
    ├── Formularios
    ├── Cards / Listas
    ├── Modals / Overlays
    ├── Empty states
    ├── Micro-interacciones
    └── Motion / Animación
```

---

# 27. Ejercicios Prácticos

## 27.1 Ejercicio 1 — Crazy 8s para Pantalla de Login

```
Objetivo: Generar 8 variantes de una pantalla de login en 8 minutos.

  Instrucciones:
  1. Dobla una hoja A4 en 8 secciones
  2. Pon timer de 8 minutos
  3. Cada sección = 1 variante de login
  4. NO te detengas, NO borres, NO juzgues

  Ideas para explorar:
  → Login con email/password clásico
  → Login solo con magic link (sin password)
  → Social login prominente (Google, Apple)
  → Login con biometría (Face ID, huella)
  → Login + registro en la misma pantalla
  → Login con número de teléfono (OTP)
  → Login con QR code
  → Login progresivo (primero email, después password)

  Al terminar:
  → Marca con ★ tus 2 favoritas
  → Pregúntate: ¿cuál es más rápida para el usuario recurrente?
  → Pregúntate: ¿cuál reduce más la fricción en el primer uso?
```

## 27.2 Ejercicio 2 — Screen Flow de E-commerce

```
Objetivo: Sketchar el flujo completo de compra en 30 minutos.

  Instrucciones:
  1. Define la persona: "María, 28 años, busca zapatos deportivos"
  2. Sketcha el happy path: Home → Buscar → Producto → Carrito → Checkout → Confirmación
  3. Sketcha 2 flujos alternativos:
     a. María no encuentra lo que busca (empty state)
     b. El pago falla (error state)
  4. Numera cada pantalla
  5. Usa flechas para conectar
  6. Anota al menos 1 decisión por pantalla

  Criterios de éxito:
  □ Mínimo 6 pantallas en el happy path
  □ Mínimo 2 pantallas de edge cases
  □ Todas las pantallas tienen título
  □ Flujo numerado y con flechas
  □ Anotaciones en las decisiones clave
```

## 27.3 Ejercicio 3 — Esquema de Navegación

```
Objetivo: Diseñar la estructura de navegación de una app de fitness.

  Instrucciones:
  1. Define 5 secciones principales de la app
  2. Sketcha la tab bar con iconos
  3. Para cada sección, sketcha qué pantallas contiene (nivel 2)
  4. Conecta pantallas que se acceden desde múltiples secciones
  5. Identifica la acción más importante → ¿a cuántos taps está?

  Contexto del producto:
  → Los usuarios quieren: registrar entrenamientos, ver progreso,
    descubrir rutinas, seguir un plan, configurar su perfil
  → La acción más frecuente: iniciar un entrenamiento
  → La acción más importante para el negocio: suscribirse a premium

  Al terminar:
  → ¿"Iniciar entrenamiento" está a 1 tap de distancia?
  → ¿"Suscribirse" está a máximo 2 taps?
  → ¿La navegación tiene 5 items o menos?
```

## 27.4 Ejercicio 4 — Los 5 Estados

```
Objetivo: Sketchar los 5 estados de una pantalla de mensajes.

  Para cada estado, sketcha la MISMA pantalla:

  1. EMPTY STATE:
     → No hay mensajes aún
     → ¿Qué ve el usuario? ¿Cómo lo motivamos a actuar?

  2. LOADING STATE:
     → Los mensajes están cargando
     → ¿Skeleton? ¿Spinner? ¿Placeholder?

  3. IDEAL STATE:
     → 5-10 conversaciones con preview
     → Jerarquía: nombre, último mensaje, hora, badge de no leído

  4. ERROR STATE:
     → Sin conexión a internet
     → ¿Qué muestra? ¿Puede ver mensajes cacheados?

  5. PARTIAL STATE:
     → Solo 1 conversación (nuevo usuario)
     → ¿Se siente vacío? ¿Sugieres contactos?

  Al terminar:
  → ¿Cada estado tiene una acción clara para el usuario?
  → ¿El empty state motiva o desalienta?
  → ¿El error state ofrece una salida?
```

## 27.5 Ejercicio 5 — Redesign Challenge

```
Objetivo: Tomar una app que uses diariamente y rediseñar una pantalla.

  Instrucciones:
  1. Elige una app (Instagram, Spotify, Uber, tu banco, etc.)
  2. Elige UNA pantalla que te frustre o podrías mejorar
  3. Sketcha la versión actual (tal como es)
  4. Lista 3 problemas que identificas
  5. Sketcha 3 variantes que resuelvan esos problemas
  6. Selecciona la mejor y refínala con anotaciones

  ⚠️ No copies el estilo visual — enfócate en:
  → ¿La información está en el orden correcto?
  → ¿Los CTAs están en la zona correcta?
  → ¿Hay elementos innecesarios?
  → ¿Falta algo que el usuario necesita?

  Tiempo sugerido: 45 minutos
  → 10 min: analizar y sketchar la versión actual
  → 5 min: listar problemas
  → 15 min: generar 3 variantes
  → 15 min: refinar la ganadora
```

---

> **Nota final:** El sketching no es un paso que completas y abandonas — es un
> hábito que atraviesa todo el proceso de diseño. Los mejores diseñadores UX/UI
> no son los que mejor dibujan; son los que más rápido externalizan ideas, las
> validan con otros, y las iteran antes de comprometerse con pixeles.
> Tu lápiz es tu prototipo más rápido. Úsalo sin miedo.