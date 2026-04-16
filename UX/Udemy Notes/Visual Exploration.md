# Visual Exploration — Módulo Completo

> **Módulo:** Exploración Visual en Diseño de Interfaces
> **Nivel:** Básico → Intermedio → Avanzado
> **Objetivo:** Desarrollar la capacidad de generar, evaluar y evolucionar múltiples soluciones visuales desde etapas tempranas hasta propuestas de alta fidelidad, priorizando la toma de decisiones informada sobre la estética aislada.

---

## Tabla de Contenidos

1. [Introducción a Visual Exploration](#1-introducción-a-visual-exploration)
2. [Fundamentos de exploración visual](#2-fundamentos-de-exploración-visual)
3. [Niveles de fidelidad (Design Fidelity)](#3-niveles-de-fidelidad-design-fidelity)
4. [Exploración de navegación](#4-exploración-de-navegación)
5. [Exploración de componentes clave](#5-exploración-de-componentes-clave)
6. [Screen Design](#6-screen-design)
7. [Evaluación de propuestas](#7-evaluación-de-propuestas)
8. [Metodología de trabajo](#8-metodología-de-trabajo)
9. [Herramientas y flujo de trabajo](#9-herramientas-y-flujo-de-trabajo)
10. [Nivel intermedio / avanzado](#10-nivel-intermedio--avanzado)

---

## 1. Introducción a Visual Exploration

### 1.1 ¿Qué es visual exploration?

**Intuición**
Visual exploration es el proceso de **generar múltiples soluciones visuales** para un mismo problema de diseño antes de comprometerse con una dirección. Es como un chef que prueba cinco combinaciones de ingredientes antes de elegir la receta final: no cocina un solo plato y reza para que funcione. En diseño, explorar visualmente significa crear variantes deliberadas que compiten entre sí.

**Estructura formal**
Visual exploration es una fase del proceso de diseño donde se:
- **Generan** múltiples alternativas visuales (divergencia)
- **Evalúan** las alternativas contra criterios definidos
- **Seleccionan** las direcciones más prometedoras (convergencia)
- **Iteran** sobre las seleccionadas hasta alcanzar una solución sólida

```
PROCESO DE VISUAL EXPLORATION

  PROBLEMA           DIVERGENCIA              CONVERGENCIA          REFINAMIENTO
     │                   │                        │                      │
     ▼                   ▼                        ▼                      ▼
  ┌──────┐     ┌──── Variante A ────┐      ┌── Mejor A' ──┐      ┌─ Final ─┐
  │ Brief│────▶│     Variante B     │─────▶│   Mejor C'   │─────▶│ Solución │
  │      │     │     Variante C     │      └──────────────┘      │ validada │
  └──────┘     │     Variante D     │                            └──────────┘
               │     Variante E     │
               └────────────────────┘
            (5-8 opciones rápidas)      (2-3 refinadas)         (1 pulida)
```

**Aplicación práctica**
Si te piden diseñar una landing page, no abres Figma y empiezas a "mover pixeles" hasta que algo te guste. En cambio:
1. Generas 5 layouts diferentes en papel o lo-fi digital (10 min cada uno)
2. Comparas: ¿cuál comunica mejor? ¿cuál es más escaneable?
3. Tomas 2 finalistas y las llevas a mid-fi con contenido real
4. Evalúas con feedback → refinas → una gana

---

### 1.2 Diferencia entre exploración visual y diseño final

| Aspecto | Exploración visual | Diseño final |
|---|---|---|
| **Objetivo** | Descubrir posibilidades | Pulir una solución |
| **Cantidad** | Muchas variantes (5-10+) | Una dirección definida |
| **Fidelidad** | Baja a media | Alta |
| **Velocidad** | Rápida, iterativa | Meticulosa, precisa |
| **Decisiones** | Abiertas, tentativas | Firmes, documentadas |
| **Perfección** | No importa | Crítica |
| **Descartable** | Sí, la mayoría se descarta | No, se entrega |
| **Feedback** | "¿Cuál dirección prefieren?" | "¿Esto cumple el brief?" |

```
EXPLORACIÓN ≠ DISEÑO FINAL

❌ Lo que muchos hacen:
   Brief → 1 diseño → pulir → entregar → "¿les gusta?"
   (apostando todo a una carta)

✅ Lo que deberías hacer:
   Brief → 8 variantes rápidas → evaluar → 2 finalistas
   → iterar → 1 solución validada → pulir → entregar
   (decisión informada)
```

> **Regla de oro:** La exploración visual NO es indecisión. Es una estrategia para tomar mejores decisiones de diseño en menos tiempo total.

---

### 1.3 Rol dentro del proceso de diseño

La exploración visual no es una etapa aislada; aparece en **tres momentos clave** del proceso:

#### Ideación
```
IDEACIÓN (Fase divergente)
─────────────────────────
Objetivo: Generar el mayor número de ideas posibles
Fidelidad: Baja (sketches, wireframes rápidos)
Mentalidad: "No hay malas ideas"
Duración: 20-30% del proyecto

  Sketch A    Sketch B    Sketch C    Sketch D    Sketch E
  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
  │ ████ │   │ ──── │   │ ▓▓▓▓ │   │      │   │ ████ │
  │ ──── │   │ ████ │   │      │   │ ████ │   │      │
  │ ──── │   │ ──── │   │ ──── │   │ ──── │   │ ▓▓▓▓ │
  │ [CTA]│   │[CTA] │   │ [CT] │   │[CTA] │   │[CTA] │
  └──────┘   └──────┘   └──────┘   └──────┘   └──────┘
     ↓            ↓           ↓
  "Estos 3 tienen potencial, exploremos más"
```

#### Validación
```
VALIDACIÓN (Fase de prueba)
───────────────────────────
Objetivo: Confirmar que la dirección visual comunica lo correcto
Fidelidad: Media
Mentalidad: "¿Esto funciona para el usuario?"
Duración: 15-20% del proyecto

  Variante A (refinada)    Variante C (refinada)
  ┌──────────────────┐    ┌──────────────────┐
  │  Logo   Nav  CTA │    │  Logo            │
  │                  │    │  ─── Nav ───     │
  │  Hero con imagen │    │                  │
  │  ════════════════│    │  Hero tipográfico│
  │  3 cards         │    │  ════════════════│
  │  ┌──┐ ┌──┐ ┌──┐ │    │  Lista vertical  │
  └──────────────────┘    └──────────────────┘
         │                       │
         └──── Test A/B o feedback ────┘
```

#### Iteración
```
ITERACIÓN (Fase de refinamiento)
────────────────────────────────
Objetivo: Mejorar la solución seleccionada hasta que cumpla todos los criterios
Fidelidad: Media → Alta
Mentalidad: "¿Cómo mejoro esto un 10% más?"
Duración: 30-40% del proyecto

  V1.0 → feedback → V1.1 → feedback → V1.2 → V2.0 (final)
  │                   │                  │        │
  Tipografía          Espaciado          Color    Micro-
  ajustada            corregido          final    interacciones
```

---

### 1.4 ¿Por qué explorar múltiples soluciones antes de decidir?

**Intuición**
Enamorarte de tu primera idea es el error #1 del diseñador junior. Tu primera solución casi nunca es la mejor, solo es la más obvia. Explorar múltiples caminos no significa que no confíes en tu criterio — significa que **entrenas tu criterio** al comparar opciones.

**Estructura formal**

| Razón | Explicación | Consecuencia de NO hacerlo |
|---|---|---|
| **Sesgo de anclaje** | La primera idea domina tu mente | Diseñas variaciones de una sola idea, no alternativas reales |
| **Espacio de solución** | Cada problema tiene decenas de soluciones viables | Te quedas en un rincón del espacio de posibilidades |
| **Criterios emergentes** | Al comparar descubres qué valoras realmente | No puedes articular por qué tu diseño "funciona" |
| **Comunicación con stakeholders** | "Elegí la A porque..." vs "Aquí está mi diseño" | Parecer subjetivo o poco profesional |
| **Innovación** | Las mejores ideas suelen ser la 3ra o 4ta iteración | Entregar soluciones genéricas y predecibles |
| **Velocidad total** | Explorar rápido al inicio ahorra rediseños después | Descubrir problemas fundamentales tarde en el proceso |

**Aplicación práctica**
La regla de **"3 antes de 1"**: antes de invertir más de 30 minutos en cualquier dirección visual, genera al menos 3 alternativas radicalmente diferentes. No variaciones del mismo tema — **enfoques distintos**.

```
❌ "3 variaciones de lo mismo":                ✅ "3 enfoques distintos":
   ┌──────┐  ┌──────┐  ┌──────┐               ┌──────┐  ┌──────┐  ┌──────┐
   │ Hero │  │ Hero │  │ Hero │               │ Hero │  │ Card │  │ Video│
   │ img  │  │ img  │  │ img  │               │ img  │  │ Grid │  │ BG   │
   │ left │  │center│  │right │               │ ──── │  │ ┌┐┌┐ │  │ texto│
   │ ──── │  │ ──── │  │ ──── │               │ text │  │ └┘└┘ │  │ CTA  │
   └──────┘  └──────┘  └──────┘               └──────┘  └──────┘  └──────┘
   (Solo cambió la alineación)               (Cada uno tiene un enfoque
                                              completamente diferente)
```

---

## 2. Fundamentos de exploración visual

### 2.1 Divergencia vs convergencia

**Intuición**
El diseño es un acordeón: primero **abres** (diverges, generas muchas ideas) y luego **cierras** (converges, seleccionas las mejores). El error está en cerrar demasiado pronto o nunca cerrar.

**Estructura formal**

```
DOBLE DIAMANTE DE EXPLORACIÓN VISUAL

        DESCUBRIR          DEFINIR          DESARROLLAR         ENTREGAR
      (divergencia)     (convergencia)     (divergencia)     (convergencia)
           ╱╲                ╲╱                ╱╲                ╲╱
          ╱  ╲                ╲╱              ╱  ╲                ╲╱
         ╱    ╲                ╲             ╱    ╲                ╲
        ╱      ╲                ╲           ╱      ╲                ╲
       ╱ Ideas  ╲           Dirección      ╱Variantes╲          Solución
      ╱  muchas  ╲          clara  ╲      ╱ refinadas ╲         final  ╲
     ╱    ╱│╲     ╲            │    ╲    ╱   ╱│╲       ╲          │     ╲
    ╱   ╱  │  ╲    ╲           │     ╲  ╱  ╱  │  ╲      ╲         │      ╲
       10-20        3-5                5-8           1-2
       ideas      direcciones       variantes     propuestas
```

| Fase | Mentalidad | Regla | Herramienta típica |
|---|---|---|---|
| **Divergencia** | "Todo vale" | No juzgar, solo generar | Sketches, crazy 8s, moodboards |
| **Convergencia** | "¿Cuál es mejor?" | Evaluar con criterios | Dot voting, matrices, feedback |

**Aplicación práctica**

```
EJERCICIO: Crazy 8s adaptado a UI

Tiempo: 8 minutos (1 minuto por sketch)
Material: Hoja dividida en 8 secciones

┌─────────┬─────────┬─────────┬─────────┐
│ Layout 1│ Layout 2│ Layout 3│ Layout 4│
│ (hero)  │ (grid)  │ (split) │ (full)  │
│  1 min  │  1 min  │  1 min  │  1 min  │
├─────────┼─────────┼─────────┼─────────┤
│ Layout 5│ Layout 6│ Layout 7│ Layout 8│
│ (card)  │ (video) │ (minimal│ (bold)  │
│  1 min  │  1 min  │  1 min  │  1 min  │
└─────────┴─────────┴─────────┴─────────┘

Regla: NO borrar, NO juzgar durante el ejercicio
Después: selecciona 2-3 favoritos con criterios
```

---

### 2.2 Cantidad vs calidad en etapas tempranas

**Intuición**
En exploración temprana, **cantidad > calidad**. Es contraintuitivo, pero generar 10 bocetos "feos" te da más material para tomar buenas decisiones que 1 boceto "bonito". La calidad emerge de la selección, no de la primera ejecución.

**Estructura formal**

| Fase del proyecto | Prioridad | Nivel de detalle | Tiempo por variante |
|---|---|---|---|
| Exploración inicial | Cantidad (10-20) | Muy bajo | 2-5 min |
| Dirección seleccionada | Balance (5-8) | Bajo-medio | 15-30 min |
| Refinamiento | Calidad (2-3) | Medio-alto | 1-3 horas |
| Entrega | Excelencia (1) | Alto | Todo lo necesario |

```
EMBUDO DE EXPLORACIÓN

   20 sketches rápidos (papel, 2 min c/u = 40 min)
         │
         ▼  ← filtro: "¿Comunica bien?"
   8 wireframes lo-fi (Figma, 10 min c/u = 80 min)
         │
         ▼  ← filtro: "¿Es usable? ¿Es viable?"
   3 mockups mid-fi (30 min c/u = 90 min)
         │
         ▼  ← filtro: "¿Cuál prefiere el usuario?"
   1 diseño hi-fi pulido (4-8 horas)
         │
         ▼
   TOTAL: ~13 horas para una decisión sólida
   vs
   8 horas en una sola idea que "tal vez funcione"
```

> **Principio de Linus Pauling:** "La mejor manera de tener buenas ideas es tener muchas ideas y descartar las malas."

---

### 2.3 Ejes de exploración visual

Cada eje representa una dimensión que puedes variar deliberadamente:

#### Layout
```
EJE: LAYOUT — 4 enfoques para la misma sección "Features"

A) Grid simétrico           B) Asimétrico
┌─────┬─────┬─────┐        ┌─────────────┬─────┐
│  ●  │  ●  │  ●  │        │             │  ●  │
│ txt │ txt │ txt │        │   ●  texto  │ txt │
│     │     │     │        │   largo     │     │
└─────┴─────┴─────┘        └─────────────┴─────┘

C) Lista vertical           D) Zig-zag
┌─────────────────┐        ┌──────────┬────────┐
│ ● texto ──────  │        │  texto   │   ●    │
│ ● texto ──────  │        ├────────┬─┴────────┤
│ ● texto ──────  │        │   ●    │  texto   │
└─────────────────┘        └────────┴──────────┘
```

#### Tipografía
```
EJE: TIPOGRAFÍA — Mismo contenido, distinta personalidad

A) Serif clásica              B) Sans moderna
┌──────────────────┐         ┌──────────────────┐
│ Discover Our     │         │ DISCOVER OUR     │
│ Collection       │         │ COLLECTION       │
│ ─────────────    │         │ ─────────────    │
│ Elegant pieces   │         │ Minimal pieces   │
│ for every...     │         │ for every...     │
└──────────────────┘         └──────────────────┘
  → Lujo, tradición            → Tech, claridad

C) Display bold               D) Mixta (display + body)
┌──────────────────┐         ┌──────────────────┐
│ DISCOVER         │         │ DISCOVER our     │
│ OUR              │         │ collection       │
│ COLLECTION       │         │ ─────────────    │
│ ─────────────    │         │ Elegant pieces   │
│ pieces for...    │         │ for every...     │
└──────────────────┘         └──────────────────┘
  → Impacto, moda              → Jerarquía clara
```

#### Color
```
EJE: COLOR — Misma estructura, distinta emoción

A) Monocromático           B) Complementario
┌──────────────────┐      ┌──────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ Azul │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ Azul
│   Texto blanco   │      │   Texto blanco   │
│ ░░░░░░░░░░░░░░░░ │ Azul │ ████████████████ │ Naranja
│   [CTA azul]     │ claro│   [CTA naranja]  │
└──────────────────┘      └──────────────────┘
  → Profesional, sobrio      → Energético, llamativo

C) Neutro + acento         D) Dark mode
┌──────────────────┐      ┌──────────────────┐
│ Fondo blanco     │      │ ████████████████ │ #1a1a2e
│   Texto negro    │      │   Texto claro    │
│                  │      │                  │
│   [CTA verde]    │      │   [CTA neón]     │
└──────────────────┘      └──────────────────┘
  → Limpio, confiable        → Moderno, premium
```

#### Componentes
```
EJE: COMPONENTES — Mismo dato, distinta presentación

A) Cards                    B) Lista
┌──────┐ ┌──────┐          ┌──────────────────────┐
│ img  │ │ img  │          │ ● Producto A   $20   │
│ name │ │ name │          │ ● Producto B   $35   │
│ $20  │ │ $35  │          │ ● Producto C   $15   │
└──────┘ └──────┘          └──────────────────────┘

C) Carousel                 D) Masonry
◀ ┌──────────────┐ ▶       ┌────┐ ┌──────┐
  │    img       │         │img │ │ img  │
  │  nombre      │         │ nm │ │      │
  │    $20       │         └────┘ │ name │
  └──────────────┘         ┌──────┐└──────┘
                           │ img  │ ┌────┐
                           └──────┘ │img │
                                    └────┘
```

---

### 2.4 Cómo evitar quedarse con la primera solución

**Intuición**
Tu cerebro busca eficiencia: cuando encuentra algo que "funciona", quiere detenerse. Eso es un **sesgo cognitivo**, no diseño inteligente. La primera solución funciona como ancla, y todo lo que hagas después será una variación de ella, no una alternativa real.

**Técnicas anti-anclaje:**

| Técnica | Cómo funciona | Cuándo usarla |
|---|---|---|
| **"Kill your darlings"** | Deliberadamente descarta tu favorita y diseña sin ella | Cuando estás demasiado apegado a una idea |
| **Restricción forzada** | "Diseña esto SIN hero image" o "SIN sidebar" | Cuando todas tus variantes se parecen |
| **Inversión** | Diseña lo opuesto a tu instinto | Cuando la solución obvia domina |
| **Referentes extremos** | Busca inspiración en industrias ajenas | Cuando las soluciones se sienten genéricas |
| **Timer estricto** | 3 minutos máximo por variante | Cuando overdesigns una sola idea |

**Aplicación práctica**

```
EJERCICIO: "La peor idea primero"

1. Diseña la solución MÁS OBVIA (5 min)
2. Diseña la solución MÁS RARA (5 min)
3. Diseña la solución OPUESTA a tu instinto (5 min)
4. Diseña la solución MÁS SIMPLE posible (5 min)
5. Diseña combinando lo mejor de las 4 anteriores (10 min)

→ Esto rompe el anclaje y amplía tu espacio de exploración
```

---

## 3. Niveles de fidelidad (Design Fidelity)

### 3.1 Low-fidelity: wireframes rápidos

**Intuición**
Low-fi es pensar en **estructura, no en estética**. Es como el plano de una casa: muestra dónde van las paredes y puertas, no el color de la pintura. Si estás eligiendo tipografías en lo-fi, vas demasiado rápido.

**Estructura formal**

| Característica | Low-fidelity |
|---|---|
| **Herramienta** | Papel, pizarra, Figma con rectángulos |
| **Tiempo** | 2-10 min por pantalla |
| **Contenido** | Bloques, lorem ipsum, "X" para imágenes |
| **Color** | Solo grises y negro |
| **Tipografía** | Una sola, tamaños relativos |
| **Objetivo** | Estructura y flujo |
| **Descartable** | 100% descartable |

```
LOW-FIDELITY WIREFRAME

┌─────────────────────────────────┐
│  Logo          Nav    Nav  [CTA]│
├─────────────────────────────────┤
│                                 │
│         ┌─────────────┐         │
│         │      X      │         │
│         │   (imagen)  │         │
│         └─────────────┘         │
│    Título principal aquí        │
│    Subtítulo de soporte xxx     │
│         [ Botón CTA ]          │
│                                 │
├─────────────────────────────────┤
│  ┌─────┐  ┌─────┐  ┌─────┐    │
│  │  X  │  │  X  │  │  X  │    │
│  │ txt │  │ txt │  │ txt │    │
│  │ txt │  │ txt │  │ txt │    │
│  └─────┘  └─────┘  └─────┘    │
└─────────────────────────────────┘
```

---

### 3.2 Mid-fidelity: estructura + jerarquía

**Intuición**
Mid-fi es el "borrador avanzado". Ya defines jerarquía real, espaciado proporcional y contenido representativo. Es donde tomas decisiones de **qué va primero, qué es más grande, qué se agrupa con qué**.

**Estructura formal**

| Característica | Mid-fidelity |
|---|---|
| **Herramienta** | Figma con componentes básicos |
| **Tiempo** | 15-45 min por pantalla |
| **Contenido** | Texto real o realista |
| **Color** | Grises + 1 color de acento |
| **Tipografía** | Familia seleccionada, jerarquía definida |
| **Objetivo** | Jerarquía, espaciado, flujo de lectura |
| **Descartable** | Parcialmente reutilizable |

```
MID-FIDELITY MOCKUP

┌─────────────────────────────────────┐
│  Acme Co.     Products  About  [→] │
├─────────────────────────────────────┤
│                                     │
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │     Imagen del producto       │  │
│  │        (800 x 400)           │  │
│  │                               │  │
│  └───────────────────────────────┘  │
│                                     │
│  Discover Premium Furniture         │
│  ────────────────────────           │
│  Quality craftsmanship meets        │
│  modern design for your home.       │
│                                     │
│        [ Shop Collection → ]        │
│                                     │
├─────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌───────┐ │
│  │ (foto)  │ │ (foto)  │ │(foto) │ │
│  │ Chair   │ │ Table   │ │ Lamp  │ │
│  │ $249    │ │ $399    │ │ $89   │ │
│  │ ★★★★☆  │ │ ★★★★★  │ │ ★★★★☆ │ │
│  └─────────┘ └─────────┘ └───────┘ │
└─────────────────────────────────────┘
```

---

### 3.3 High-fidelity: visual casi final

**Intuición**
Hi-fi es lo que el usuario verá (o algo muy cercano). Colores finales, tipografía exacta, imágenes reales, microinteracciones definidas. Solo deberías llegar aquí cuando la **estructura está validada**.

**Estructura formal**

| Característica | High-fidelity |
|---|---|
| **Herramienta** | Figma con design system |
| **Tiempo** | 2-8 horas por pantalla |
| **Contenido** | Real, aprobado |
| **Color** | Paleta final |
| **Tipografía** | Exacta (family, weight, size, line-height) |
| **Objetivo** | Aprobación, handoff a desarrollo |
| **Descartable** | No, es entregable |

---

### 3.4 Cuándo cambiar de fidelidad

```
SEÑALES PARA SUBIR DE FIDELIDAD

Lo-fi → Mid-fi:
  ✅ Ya tienes 3+ layouts diferentes
  ✅ Sabes qué información va en cada sección
  ✅ El flujo general está definido
  ✅ Tienes feedback inicial del equipo

Mid-fi → Hi-fi:
  ✅ La jerarquía está validada
  ✅ El contenido real está disponible
  ✅ Los componentes clave están definidos
  ✅ Stakeholders aprobaron la dirección
  ✅ No hay dudas estructurales pendientes

NUNCA subas de fidelidad si:
  ❌ No has explorado alternativas
  ❌ El contenido es placeholder
  ❌ Hay desacuerdos sobre la estructura
  ❌ No has recibido feedback
```

---

### 3.5 Riesgos de ir demasiado rápido a high-fidelity

**Intuición**
Ir directo a hi-fi es como pintar las paredes antes de revisar los planos. Si la estructura es incorrecta, todo tu trabajo visual (colores, tipografía, imágenes) se desperdicia.

| Riesgo | Consecuencia | Cómo evitarlo |
|---|---|---|
| **Sunk cost fallacy** | "Ya invertí 8 horas, no voy a cambiarlo" | Explorar en lo-fi primero |
| **Feedback sobre lo incorrecto** | Stakeholders opinan sobre colores en vez de estructura | Presentar en escala de grises |
| **Rigidez creativa** | Ya no puedes explorar alternativas radicales | Mantener archivos de exploración separados |
| **Descubrimiento tardío** | Problemas de usabilidad aparecen al final | Testear con prototipos lo-fi |
| **Sobrecarga de detalle** | Perderse en pixels cuando la estructura está rota | Usar un checklist de fidelidad |

```
TRAMPA DEL "PIXEL PERFECTO" PREMATURO

Semana 1: "Voy a hacer el diseño final directamente"
           │
           ▼
Semana 2:  Hi-fi completo, 40 horas invertidas
           │
           ▼
Semana 3:  Feedback → "La navegación debería ser diferente"
           │                  "El hero no comunica bien"
           │                  "Necesitamos otra estructura"
           ▼
Semana 4:  Rehacer todo desde cero (40 horas perdidas)

vs

Semana 1:  Lo-fi (8 opciones, 2 horas) → feedback
Semana 2:  Mid-fi (3 opciones, 4 horas) → feedback
Semana 3:  Hi-fi (1 opción, 15 horas) → aprobado con ajustes menores
TOTAL:     ~25 horas con decisiones validadas en cada paso
```

---

## 4. Exploración de navegación

### 4.1 Variantes de navegación

**Intuición**
La navegación es la columna vertebral de cualquier interfaz. Elegir un patrón de navegación no es una decisión estética — es una decisión **arquitectónica** que afecta todo lo demás.

#### Top Navigation
```
TOP NAVIGATION

┌─────────────────────────────────────────┐
│  Logo    Home  Products  About   [CTA]  │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│           Área de contenido             │
│            (100% de ancho)              │
│                                         │
│                                         │
│                                         │
└─────────────────────────────────────────┘

✅ Ventajas:
   • Familiar, convención web más común
   • Contenido ocupa todo el ancho
   • Escalable con dropdowns/mega menus
   • Responsive: se convierte en hamburger

❌ Desventajas:
   • Espacio horizontal limitado (5-7 items max)
   • Compite con el hero por atención
   • Se pierde al hacer scroll (si no es sticky)
```

#### Sidebar Navigation
```
SIDEBAR NAVIGATION

┌──────────┬──────────────────────────────┐
│          │                              │
│  Logo    │                              │
│  ──────  │     Área de contenido        │
│  Home    │      (ancho reducido)        │
│  Products│                              │
│  Orders  │                              │
│  Settings│                              │
│  ──────  │                              │
│  Users   │                              │
│  Reports │                              │
│  ──────  │                              │
│  [Logout]│                              │
│          │                              │
└──────────┴──────────────────────────────┘

✅ Ventajas:
   • Soporta muchos items (10-20+)
   • Siempre visible
   • Agrupación clara con separadores
   • Ideal para apps complejas (SaaS, dashboards)

❌ Desventajas:
   • Reduce el ancho del contenido
   • No ideal en mobile (debe colapsar)
   • Puede sentirse pesada en sitios simples
```

#### Bottom Navigation (Mobile)
```
BOTTOM NAVIGATION (MOBILE)

┌─────────────────────────────┐
│                             │
│                             │
│       Área de contenido     │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│  🏠    🔍    ➕    ❤️    👤  │
│ Home  Search Add  Favs  Me  │
└─────────────────────────────┘

✅ Ventajas:
   • Zona del pulgar (fácil acceso)
   • Siempre visible
   • Convención fuerte en iOS y Android

❌ Desventajas:
   • Máximo 5 items
   • Ocupa espacio vertical en pantallas chicas
   • No aplica para web desktop
```

---

### 4.2 Cómo comparar soluciones de navegación

**Estructura formal**

| Criterio | Top Nav | Sidebar | Bottom Nav |
|---|---|---|---|
| **Capacidad de items** | 5-7 | 10-20+ | 3-5 |
| **Plataforma ideal** | Web marketing | Web app / SaaS | Mobile nativo |
| **Espacio de contenido** | 100% ancho | 75-85% ancho | 100% ancho |
| **Complejidad soportada** | Baja-media | Alta | Baja |
| **Accesibilidad táctil** | Media | Baja (mobile) | Alta |
| **Familiaridad del usuario** | Muy alta | Media-alta | Alta (mobile) |
| **Escalabilidad** | Mega menus | Secciones colapsables | No escala |

---

### 4.3 Trade-offs entre patrones

**Aplicación práctica: Árbol de decisión**

```
¿Cuántos items de navegación primaria tienes?

  ≤ 5                    6-10                    > 10
   │                      │                        │
   ▼                      ▼                        ▼
  ¿Mobile?             Top nav con             Sidebar
   │                    dropdown/mega
  Sí ──→ Bottom nav        │
   │                   ¿Es una app
  No ──→ Top nav        compleja?
                          │
                       Sí ──→ Sidebar
                          │
                       No ──→ Top nav
```

> **Regla:** No elijas un patrón de navegación porque "se ve bien". Elígelo porque **soporta la complejidad de tu contenido** y **se adapta a las expectativas de tu usuario**.

---

## 5. Exploración de componentes clave

### 5.1 Buttons

#### Variantes principales

**Intuición**
Los botones no son todos iguales. Cada variante comunica un **nivel de importancia** diferente. Usar todos los botones en "filled" es como escribir todo en MAYÚSCULAS — si todo grita, nada destaca.

```
JERARQUÍA DE BOTONES

Importancia:  ALTA ◄──────────────────────────────► BAJA

┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
│  FILLED   │   │  OUTLINE  │   │   GHOST   │   │   LINK    │
│  ▓▓▓▓▓▓▓  │   │  ┌─────┐  │   │           │   │           │
│  ▓ Text ▓  │   │  │ Text│  │   │   Text    │   │  Text →   │
│  ▓▓▓▓▓▓▓  │   │  └─────┘  │   │           │   │           │
└───────────┘   └───────────┘   └───────────┘   └───────────┘
  Primario        Secundario      Terciario       Cuaternario
  1 por sección   1-2 por sección  Múltiples      Navegación
```

**Estructura formal**

| Variante | Uso | Cuándo | Cuándo NO |
|---|---|---|---|
| **Filled** | Acción primaria | CTA principal, submit, confirm | Si hay 3+ acciones iguales |
| **Outline** | Acción secundaria | Cancelar, alternativa, filtros | Como acción principal sola |
| **Ghost** | Acción terciaria | Acciones frecuentes no críticas | Cuando necesita destacar |
| **Link** | Navegación | "Ver más", "Leer términos" | Como CTA de conversión |

#### Tamaños y jerarquía

```
TAMAÑOS DE BOTÓN

Large (48-56px):    ┌───────────────────────┐
                    │    Get Started Now     │   → Hero CTA, formularios
                    └───────────────────────┘

Medium (36-44px):   ┌─────────────────┐
                    │   Add to Cart    │          → Cards, acciones inline
                    └─────────────────┘

Small (28-32px):    ┌───────────┐
                    │  Edit      │                → Tablas, listas, toolbars
                    └───────────┘

REGLA: Un solo tamaño de botón por grupo visual
  ✅ Hero: Large CTA + Medium secondary
  ❌ Hero: Large CTA + Large secondary + Large terciary
```

#### Estados

```
ESTADOS DE UN BOTÓN

  Default          Hover           Active          Focus           Disabled
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │░░░░░░░░░░│
│▓  Text  ▓│   │▓  Text  ▓│   │▓  Text  ▓│   │▓  Text  ▓│   │░  Text  ░│
│▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │▓▓▓▓▓▓▓▓▓▓│   │░░░░░░░░░░│
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
  bg: #2563EB     bg: #1D4ED8    bg: #1E40AF     ring: 2px      bg: #93C5FD
  cursor: default cursor:pointer scale: 0.98     outline        opacity: 0.5
                  brightness↑    duration:100ms   #2563EB       cursor: not-allowed
```

```css
/* Ejemplo de implementación */
.btn-primary {
  background: #2563EB;
  color: white;
  padding: 12px 24px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-primary:hover {
  background: #1D4ED8;
}

.btn-primary:active {
  background: #1E40AF;
  transform: scale(0.98);
}

.btn-primary:focus-visible {
  outline: 2px solid #2563EB;
  outline-offset: 2px;
}

.btn-primary:disabled {
  background: #93C5FD;
  opacity: 0.5;
  cursor: not-allowed;
}
```

#### Comparación visual entre estilos

```
MISMA ACCIÓN, DIFERENTES ESTILOS — ¿Cuál comunica mejor?

Contexto: Card de producto con botón "Add to Cart"

Estilo A (Filled):                   Estilo B (Outline):
┌──────────────────┐                ┌──────────────────┐
│    [producto]    │                │    [producto]    │
│  Wireless Mouse  │                │  Wireless Mouse  │
│  $29.99          │                │  $29.99          │
│ ┌──────────────┐ │                │ ┌──────────────┐ │
│ │▓ Add to Cart▓│ │                │ │ Add to Cart  │ │
│ └──────────────┘ │                │ └──────────────┘ │
└──────────────────┘                └──────────────────┘
→ Agresivo, alto contraste           → Sutil, menos presión
→ E-commerce transaccional           → Catálogo, comparación

Estilo C (Ghost + icon):            Estilo D (Filled + icon):
┌──────────────────┐                ┌──────────────────┐
│    [producto]    │                │    [producto]    │
│  Wireless Mouse  │                │  Wireless Mouse  │
│  $29.99          │                │  $29.99          │
│                  │                │ ┌──────────────┐ │
│   🛒 Add to Cart │                │ │▓ 🛒 Add     ▓│ │
│                  │                │ └──────────────┘ │
└──────────────────┘                └──────────────────┘
→ Mínimo, limpio                     → Claro, accionable
→ Marketplace con muchos items       → Producto destacado
```

---

### 5.2 Effect Styles

**Intuición**
Los effect styles son como el "maquillaje" de tu interfaz: sombras, bordes, blur y gradientes no son decoración — son herramientas para crear **profundidad, jerarquía y separación visual** entre elementos.

#### Sombras (Shadows)

```
NIVELES DE SOMBRA (ELEVACIÓN)

Nivel 0 (flat):          Nivel 1 (sutil):         Nivel 2 (medio):
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│              │         │              │░        │              │▒
│   Content    │         │   Content    │░        │   Content    │▒
│              │         │              │░        │              │▒
└──────────────┘         └──────────────┘░        └──────────────┘▒
                          ░░░░░░░░░░░░░░░░         ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

→ Inline, sin separación  → Cards, inputs           → Modales, dropdowns
  box-shadow: none          box-shadow:               box-shadow:
                            0 1px 3px rgba(0,0,0,0.1) 0 4px 12px rgba(0,0,0,0.15)


Nivel 3 (alto):          Nivel 4 (máximo):
┌──────────────┐         ┌──────────────┐
│              │▓        │              │█
│   Content    │▓        │   Content    │█
│              │▓        │              │█
└──────────────┘▓        └──────────────┘█
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓         ████████████████

→ Popups, tooltips        → Dragging, floating
  box-shadow:               box-shadow:
  0 8px 24px rgba(0,0,0,0.2) 0 16px 48px rgba(0,0,0,0.25)
```

```css
/* Sistema de sombras escalable */
:root {
  --shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.06);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1), 0 2px 4px rgba(0, 0, 0, 0.06);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1), 0 4px 6px rgba(0, 0, 0, 0.05);
  --shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.1), 0 10px 10px rgba(0, 0, 0, 0.04);
}
```

#### Bordes (Borders)

```
USO DE BORDES — Cuándo y por qué

A) Separación sutil            B) Definición de área
┌─────────────────────┐       ┌─────────────────────┐
│ Item 1              │       │ ┌─────────────────┐ │
│─────────────────────│       │ │   Form group    │ │
│ Item 2              │       │ │   input         │ │
│─────────────────────│       │ │   input         │ │
│ Item 3              │       │ └─────────────────┘ │
└─────────────────────┘       └─────────────────────┘
  border-bottom: 1px            border: 1px solid #e5e7eb
  solid #f3f4f6                 border-radius: 8px

C) Estado interactivo          D) Acento visual
┌─────────────────────┐       ┌─────────────────────┐
│ ┌─────────────────┐ │       │ ┌─────────────────┐ │
│ │ Input focused   │ │       │ ▐ Nota importante │ │
│ │ border: 2px     │ │       │ ▐ con borde left  │ │
│ │ #2563EB         │ │       │ ▐ de acento       │ │
│ └─────────────────┘ │       │ └─────────────────┘ │
└─────────────────────┘       └─────────────────────┘
  border: 2px solid #2563EB    border-left: 4px solid #2563EB
```

#### Elevación

```
SISTEMA DE ELEVACIÓN

  z-index / layer        Uso                    Ejemplo
  ─────────────────────────────────────────────────────────
  4  ████████████████    Overlay / modal        Diálogo de confirmación
  3  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   Popup / dropdown       Mega menu, datepicker
  2  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   Card elevada           Card hover, FAB
  1  ░░░░░░░░░░░░░░░░   Card base              Card en reposo
  0  ────────────────    Superficie base        Background de la página

REGLA: Cada nivel hacia arriba = más sombra + más "cerca del usuario"
```

#### Blur / Glassmorphism

```
GLASSMORPHISM

┌──────────────────────────────────┐
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐│
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░ ││
│  │  ░  Background content    ░ ││  ← contenido visible
│  │  ░  parcialmente visible  ░ ││     a través del blur
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░ ││
│  │  ┌────────────────────────┐ ││
│  │  │ Card con glassmorphism │ ││
│  │  │ background: rgba(      │ ││
│  │  │   255,255,255, 0.15)   │ ││
│  │  │ backdrop-filter:       │ ││
│  │  │   blur(12px)           │ ││
│  │  └────────────────────────┘ ││
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘│
└──────────────────────────────────┘
```

```css
/* Glassmorphism */
.glass-card {
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
}
```

#### Gradientes

```
TIPOS DE GRADIENTES

A) Lineal (dirección)           B) Radial (centro)
┌──────────────────┐           ┌──────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│           │         ░░       │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░│           │      ░░░░░░░     │
│▓▓▓▓▓▓▓▓▓▓░░░░░░░│           │   ░░░░░░░░░░░░   │
│▓▓▓▓▓▓░░░░░░░░░░░│           │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │
│▓▓░░░░░░░░░░░░░░░│           │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
└──────────────────┘           └──────────────────┘
 background: linear-gradient    background: radial-gradient
 (135deg, #667eea, #764ba2)    (circle, #667eea, #764ba2)
```

#### Cuándo usar cada efecto

| Efecto | Uso ideal | Evitar cuando | Impacto en rendimiento |
|---|---|---|---|
| **Sombras** | Cards, modales, elevación | Todo tiene sombra (flat es ok) | Bajo |
| **Bordes** | Separadores, inputs, agrupación | Demasiados bordes = ruido | Bajo |
| **Elevación** | Jerarquía espacial, interacción | Sin sistema definido | Bajo |
| **Blur/glass** | Heroes, overlays, navegación | Sobre contenido con texto | Alto (GPU) |
| **Gradientes** | Fondos, CTAs, branding | Sobre texto pequeño | Bajo |

---

### 5.3 Product Cards

**Intuición**
La product card es probablemente el componente más diseñado y rediseñado en la historia del e-commerce. No existe "la card perfecta" — existe la card perfecta **para tu contexto**: qué vende, a quién, y cuántos productos compiten por atención.

#### Elementos fundamentales

```
ANATOMÍA DE UNA PRODUCT CARD

┌────────────────────────┐
│ ┌────────────────────┐ │ ← A) Imagen (el gancho visual)
│ │                    │ │
│ │      Producto      │ │    Aspect ratio consistente
│ │       (img)        │ │    Lazy loading
│ │                    │ │    Hover: zoom o swap
│ └────────────────────┘ │
│                        │
│ ❤️              ★★★★☆  │ ← B) Badges / Rating (confianza)
│                        │
│ Nombre del Producto    │ ← C) Título (identificación)
│ Subtítulo o categoría  │
│                        │
│ $59.99  ~~$79.99~~     │ ← D) Precio (decisión)
│ -25%                   │
│                        │
│ ┌────────────────────┐ │ ← E) CTA (acción)
│ │   Add to Cart  🛒  │ │
│ └────────────────────┘ │
└────────────────────────┘
```

#### Variaciones de layout

```
VARIACIÓN A: Vertical (clásica)     VARIACIÓN B: Horizontal
┌──────────────────┐                ┌──────────────────────────┐
│  ┌──────────────┐│                │ ┌──────┐                 │
│  │    imagen    ││                │ │ img  │ Nombre          │
│  │              ││                │ │      │ ★★★★☆ (42)     │
│  └──────────────┘│                │ │      │ $59.99          │
│  Nombre           │                │ └──────┘ [Add to Cart]  │
│  $59.99           │                └──────────────────────────┘
│  [Add to Cart]   │                → Listas, comparación, mobile
└──────────────────┘
→ Grid, catálogo, browsing

VARIACIÓN C: Compacta              VARIACIÓN D: Expandida
┌──────────┐                       ┌──────────────────────────────┐
│  imagen  │                       │  ┌──────────────────────┐    │
│  ────    │                       │  │                      │    │
│  $59     │                       │  │    imagen grande     │    │
│  [+]     │                       │  │                      │    │
└──────────┘                       │  └──────────────────────┘    │
→ Mobile, alta densidad            │  Nombre del Producto         │
                                   │  Descripción breve que       │
                                   │  explica el valor...         │
                                   │  $59.99  ★★★★☆  [Add →]     │
                                   └──────────────────────────────┘
                                   → Producto destacado, landing page
```

#### Densidad de información

```
DENSIDAD — ¿Cuánta información necesita el usuario para decidir?

Baja densidad              Media densidad            Alta densidad
(browsing)                 (comparación)             (decisión rápida)
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│    imagen    │          │    imagen    │          │    imagen    │
│              │          │   -25% ❤️    │          │  -25% ❤️ 🔄  │
│              │          │              │          │  ★★★★☆ (142) │
│  Nombre      │          │  Nombre      │          │  Nombre      │
│  $59         │          │  Categoría   │          │  Categoría   │
│              │          │  $59  ~~$79~~│          │  $59  ~~$79~~│
└──────────────┘          │  ★★★★☆       │          │  Color: ● ● ●│
                          │  [Add]       │          │  Stock: 3 left│
                          └──────────────┘          │  [Add] [Save]│
                                                    └──────────────┘
Elementos: 3              Elementos: 6              Elementos: 10+
Contexto: Instagram shop  Contexto: Amazon          Contexto: B2B
```

---

### 5.4 Text Cards

**Intuición**
Las text cards son el vehículo para contenido: blog posts, features, testimonios, servicios. A diferencia de las product cards, aquí la **tipografía y el espaciado** hacen todo el trabajo — no hay una foto de producto para salvar un mal diseño.

#### Jerarquía tipográfica

```
TEXT CARD — Anatomía de jerarquía

┌─────────────────────────────────┐
│                                 │
│  CATEGORÍA                      │ ← Overline: 12px, UPPERCASE
│                                 │    tracking: 1.5px, color: #6B7280
│  Título principal del           │
│  artículo aquí                  │ ← Heading: 20-24px, font-weight: 700
│                                 │    line-height: 1.3
│  Texto de soporte que da        │
│  contexto al lector sobre       │ ← Body: 14-16px, font-weight: 400
│  el contenido del artículo.     │    line-height: 1.6, color: #6B7280
│                                 │
│  Author Name · 5 min read       │ ← Meta: 12-14px, color: #9CA3AF
│                                 │
└─────────────────────────────────┘

RELACIÓN DE TAMAÑOS:
  Overline  ←──────  12px  (0.5x)
  Heading   ←──────  24px  (1x)    ← tamaño base de referencia
  Body      ←──────  16px  (0.66x)
  Meta      ←──────  14px  (0.58x)
```

#### Espaciado y escaneabilidad

```
ESPACIADO EN TEXT CARDS

❌ Sin espacio (todo junto)         ✅ Con espacio (escaneable)

┌─────────────────────┐            ┌─────────────────────┐
│CATEGORÍA            │            │                     │
│Título del artículo  │            │  CATEGORÍA          │
│aquí muy largo       │            │                     │
│Texto de soporte que │            │  Título del         │
│da contexto al lector│            │  artículo aquí      │
│sobre el contenido   │            │                     │
│Author · 5 min       │            │  Texto de soporte   │
└─────────────────────┘            │  que da contexto    │
                                   │  al lector sobre    │
  → Incomodo, denso,              │  el contenido.      │
    no invita a leer              │                     │
                                   │  Author · 5 min     │
                                   │                     │
                                   └─────────────────────┘

                                     → Respirable, invita
                                       a la lectura
```

#### Variaciones de diseño

```
VARIACIÓN A: Blog card             VARIACIÓN B: Feature card
┌──────────────────────┐           ┌──────────────────────┐
│ ┌──────────────────┐ │           │                      │
│ │  imagen cover    │ │           │  🚀                   │
│ └──────────────────┘ │           │                      │
│                      │           │  Feature Title       │
│  DESIGN · MAR 15     │           │                      │
│                      │           │  Description text    │
│  How to Build        │           │  that explains the   │
│  Better Cards        │           │  feature value.      │
│                      │           │                      │
│  A guide to...       │           │  Learn more →        │
│                      │           │                      │
│  👤 Jane · 5 min     │           └──────────────────────┘
└──────────────────────┘

VARIACIÓN C: Testimonial           VARIACIÓN D: Stat card
┌──────────────────────┐           ┌──────────────────────┐
│                      │           │                      │
│  "Best tool we've    │           │  98%                 │
│   ever used for      │           │  ─────               │
│   our workflow."     │           │  Customer            │
│                      │           │  Satisfaction        │
│  ── Jane Smith       │           │                      │
│     CEO at Acme      │           │  Based on 2,400+     │
│     ★★★★★            │           │  reviews             │
│                      │           │                      │
└──────────────────────┘           └──────────────────────┘
```

---

## 6. Screen Design

### 6.1 Home Screen

#### Objetivos principales

**Intuición**
La home page tiene 3 trabajos en 3 segundos:
1. **Primera impresión:** ¿Qué es esto? ¿Es para mí?
2. **Navegación clara:** ¿Dónde voy si quiero X?
3. **Prioridad de contenido:** ¿Qué debería hacer primero?

Si tu home no responde estas preguntas en el primer vistazo, el usuario se va. No tienes 30 segundos — tienes 3.

**Estructura formal**

| Objetivo | Métrica | Pregunta del usuario |
|---|---|---|
| **Primera impresión** | Tasa de rebote < 40% | "¿Qué ofrece esto?" |
| **Navegación clara** | Click en nav > 60% de sesiones | "¿Cómo llego a lo que busco?" |
| **Prioridad de contenido** | CTA click-through > 5% | "¿Qué quieren que haga?" |

#### Exploración de layouts

```
LAYOUT A: Hero-driven
───────────────────────────────────────
Filosofía: Una imagen/mensaje grande domina
Ideal para: Branding, producto único, lanzamientos

┌─────────────────────────────────────┐
│  Logo          Nav        [Sign Up] │
├─────────────────────────────────────┤
│                                     │
│                                     │
│     We Build Beautiful              │
│     Digital Products                │
│                                     │
│     Short description about         │
│     your value proposition          │
│                                     │
│     [Get Started]  [Learn More]     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  Feature 1    Feature 2   Feature 3 │
│  ┌──────┐    ┌──────┐    ┌──────┐  │
│  │  ●   │    │  ●   │    │  ●   │  │
│  │ text │    │ text │    │ text │  │
│  └──────┘    └──────┘    └──────┘  │
└─────────────────────────────────────┘

✅ Impacto emocional fuerte
✅ Mensaje claro e inmediato
❌ Poco contenido above the fold
❌ Depende de buen copy y visual
```

```
LAYOUT B: Content-first
───────────────────────────────────────
Filosofía: Mostrar valor inmediatamente con contenido
Ideal para: E-commerce, marketplaces, plataformas

┌─────────────────────────────────────┐
│  Logo    Search...     [Cart] [👤]  │
├─────────────────────────────────────┤
│  Trending  New  Sale  Categories ▼  │
├─────────────────────────────────────┤
│ ┌───────────────┐  ┌──────┬──────┐ │
│ │  Featured     │  │ Cat1 │ Cat2 │ │
│ │  Product      │  │      │      │ │
│ │  [Shop Now]   │  ├──────┼──────┤ │
│ │               │  │ Cat3 │ Cat4 │ │
│ └───────────────┘  └──────┴──────┘ │
├─────────────────────────────────────┤
│  Popular Products                   │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐      │
│  │img │ │img │ │img │ │img │      │
│  │$29 │ │$49 │ │$35 │ │$19 │      │
│  └────┘ └────┘ └────┘ └────┘      │
└─────────────────────────────────────┘

✅ Alta densidad de contenido
✅ Múltiples puntos de entrada
❌ Puede sentirse abrumador
❌ Jerarquía visual más difícil
```

```
LAYOUT C: Minimal
───────────────────────────────────────
Filosofía: Menos es más, eliminar todo lo innecesario
Ideal para: SaaS, portfolios, apps de una función

┌─────────────────────────────────────┐
│  Logo                    [Sign In]  │
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│         Your tasks.                 │
│         Organized.                  │
│                                     │
│         [Start Free Trial]          │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  Trusted by: [logo] [logo] [logo]   │
└─────────────────────────────────────┘

✅ Claridad absoluta
✅ Foco en una sola acción
❌ Poco contexto para usuarios indecisos
❌ Requiere copy excepcional
```

#### Comparación de enfoques

| Criterio | Hero-driven | Content-first | Minimal |
|---|---|---|---|
| **Primera impresión** | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| **Densidad de info** | ★★☆☆☆ | ★★★★★ | ★☆☆☆☆ |
| **Claridad de CTA** | ★★★★★ | ★★★☆☆ | ★★★★★ |
| **Escalabilidad** | ★★★☆☆ | ★★★★★ | ★★☆☆☆ |
| **Ideal para** | Branding | E-commerce | SaaS |

---

### 6.2 Product Pages

#### Elementos clave

**Intuición**
La product page tiene un solo objetivo: convertir. Todo lo que esté en esta página debe responder a una de tres preguntas del usuario: "¿Qué es?", "¿Me conviene?" y "¿Cómo lo compro?"

#### Jerarquía visual

```
PRODUCT PAGE — Jerarquía de atención

Prioridad 1 (primeros 3 seg):     Prioridad 2 (exploración):
┌─────────────────────────────────────────────────┐
│  Breadcrumb: Home > Category > Product          │ ← Orientación
├──────────────────────┬──────────────────────────┤
│                      │                          │
│  ┌────────────────┐  │  Product Name            │ ← ¿Qué es?
│  │                │  │  ★★★★☆ (124 reviews)    │ ← ¿Es bueno?
│  │   Imagen       │  │                          │
│  │   principal    │  │  $129.99  ~~$179.99~~    │ ← ¿Cuánto cuesta?
│  │                │  │  Save 28%                │
│  │                │  │                          │
│  └────────────────┘  │  Color: ● ● ● ●         │ ← Opciones
│  ○ ○ ● ○ (thumbnails)│  Size: [S] [M] [L] [XL]│
│                      │                          │
│                      │  ┌────────────────────┐  │
│                      │  │▓▓ Add to Cart ▓▓▓▓ │  │ ← ACCIÓN (máxima
│                      │  └────────────────────┘  │    prioridad visual)
│                      │  [ ❤️ Wishlist ]         │
│                      │                          │
│                      │  ✓ Free shipping > $50   │ ← Confianza
│                      │  ✓ 30-day returns        │
│                      │  ✓ 2-year warranty       │
├──────────────────────┴──────────────────────────┤
│  Description | Reviews | Shipping               │ ← Detalle
├─────────────────────────────────────────────────┤
│  You might also like...                         │ ← Cross-sell
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                  │
│  └────┘ └────┘ └────┘ └────┘                  │
└─────────────────────────────────────────────────┘
```

#### Variaciones de diseño

```
VARIACIÓN A: Split (50/50)            VARIACIÓN B: Gallery-driven
┌──────────┬───────────┐              ┌──────────────────────────┐
│          │           │              │ ┌──┐ ┌──┐ ┌──┐ ┌──┐     │
│  imagen  │  info +   │              │ │  │ │  │ │  │ │  │     │
│  grande  │  CTA      │              │ └──┘ └──┘ └──┘ └──┘     │
│          │           │              ├──────────────────────────┤
│          │           │              │  Product Name · $129     │
└──────────┴───────────┘              │  [Add to Cart]           │
→ Desktop, producto visual            └──────────────────────────┘
                                      → Mobile, moda, lifestyle

VARIACIÓN C: Full-width hero          VARIACIÓN D: Compact (mobile)
┌──────────────────────────┐          ┌──────────────┐
│                          │          │  ◀  imagen  ▶│
│     Imagen a pantalla    │          │  ○ ● ○ ○     │
│     completa             │          │              │
│                          │          │ Producto     │
├──────────────────────────┤          │ $129  ★★★★☆  │
│  Producto · $129 · [CTA] │          │ Color: ● ●   │
└──────────────────────────┘          │              │
→ Luxury, experiencial                │ [Add to Cart]│
                                      └──────────────┘
                                      → Mobile-first
```

#### Optimización para conversión

| Elemento | Optimización | Por qué funciona |
|---|---|---|
| **CTA sticky** | Botón que sigue al hacer scroll (mobile) | No pierde oportunidad de compra |
| **Urgencia real** | "Solo 3 en stock" (si es verdad) | Reduce parálisis por análisis |
| **Social proof** | Reviews con foto + nombre real | Confianza peer-to-peer |
| **Precio tachado** | Precio original visible junto al descuento | Ancla de referencia psicológica |
| **Trust badges** | Iconos de envío gratis, devoluciones, garantía | Reduce fricción pre-compra |
| **Breadcrumb** | Navegación contextual arriba | Orientación y SEO |

---

## 7. Evaluación de propuestas

### 7.1 Criterios de evaluación

**Intuición**
Evaluar diseño no es decir "me gusta más este". Es aplicar **criterios definidos** que todos entienden y pueden debatir. Sin criterios, la evaluación se convierte en una batalla de gustos — y gana el que tiene más poder, no el mejor diseño.

**Estructura formal**

```
MATRIZ DE EVALUACIÓN

Criterio         │ Peso │ Variante A │ Variante B │ Variante C
─────────────────┼──────┼────────────┼────────────┼────────────
Claridad         │  25% │  ★★★★☆ (4)│  ★★★★★ (5)│  ★★★☆☆ (3)
Usabilidad       │  30% │  ★★★★★ (5)│  ★★★★☆ (4)│  ★★★☆☆ (3)
Consistencia     │  20% │  ★★★☆☆ (3)│  ★★★★☆ (4)│  ★★★★★ (5)
Estética         │  15% │  ★★★★☆ (4)│  ★★★☆☆ (3)│  ★★★★★ (5)
Viabilidad       │  10% │  ★★★★★ (5)│  ★★★★☆ (4)│  ★★☆☆☆ (2)
─────────────────┼──────┼────────────┼────────────┼────────────
TOTAL PONDERADO  │ 100% │    4.15    │    4.10    │    3.60
                 │      │  ← GANA   │            │
```

| Criterio | Qué evalúa | Preguntas clave |
|---|---|---|
| **Claridad** | ¿Se entiende a primera vista? | ¿El usuario sabe qué hacer? ¿La jerarquía es obvia? |
| **Usabilidad** | ¿Es fácil de usar? | ¿Los targets son accesibles? ¿El flujo es lógico? |
| **Consistencia** | ¿Sigue patrones conocidos? | ¿Es coherente con el sistema? ¿Respeta convenciones? |
| **Estética** | ¿Es atractiva visualmente? | ¿El estilo comunica la marca? ¿Es armoniosa? |
| **Viabilidad** | ¿Se puede implementar? | ¿Es factible técnicamente? ¿Escala bien? |

> **Regla:** La estética siempre tiene el peso más bajo. Un diseño bonito pero confuso es peor que uno simple pero claro.

---

### 7.2 Cómo seleccionar la mejor opción

**Aplicación práctica**

```
PROCESO DE SELECCIÓN EN 5 PASOS

1. DEFINIR CRITERIOS (antes de ver las opciones)
   │  → "Para esta pantalla, lo más importante es
   │     claridad (30%) y usabilidad (30%)"
   │
   ▼
2. EVALUAR INDEPENDIENTEMENTE
   │  → Cada evaluador puntúa sin ver las notas de otros
   │
   ▼
3. COMPARAR Y DEBATIR
   │  → "¿Por qué tú le diste 5 a claridad y yo 3?"
   │  → Las discrepancias revelan supuestos ocultos
   │
   ▼
4. COMBINAR LO MEJOR
   │  → A veces la solución ganadora es un híbrido:
   │     "La estructura de A con los componentes de C"
   │
   ▼
5. DOCUMENTAR LA DECISIÓN
   → "Elegimos A porque... descartamos C porque..."
   → Esto protege la decisión de cambios arbitrarios
```

---

### 7.3 Uso de feedback

**Intuición**
El feedback más útil no es "me gusta" o "no me gusta". Es feedback **específico, contextual y accionable**. Tu trabajo es facilitar que stakeholders y usuarios te den feedback útil.

| Tipo de feedback | Fuente | Cuándo | Formato |
|---|---|---|---|
| **Dirección** | Stakeholders | Después de exploración lo-fi | "¿Cuál de estas 3 direcciones prefieren?" |
| **Usabilidad** | Usuarios | Después de mid-fi | "¿Puedes completar la tarea X?" |
| **Estética** | Equipo + stakeholders | Después de hi-fi | "¿Esto representa la marca?" |
| **Técnico** | Desarrolladores | Durante mid-fi a hi-fi | "¿Es viable implementar este patrón?" |

```
CÓMO PRESENTAR OPCIONES PARA FEEDBACK

❌ Incorrecto:
   "Aquí están mis 3 opciones, ¿cuál les gusta?"
   → Feedback superficial basado en gusto

✅ Correcto:
   "Exploré 3 direcciones, cada una optimiza algo diferente:
    A → Maximiza conversión (CTA agresivo)
    B → Maximiza confianza (más info, más reviews)
    C → Maximiza descubrimiento (browsing fácil)

    Según nuestros objetivos, ¿cuál dirección
    priorizamos? ¿O combinamos aspectos de varias?"
   → Feedback estratégico basado en objetivos
```

---

## 8. Metodología de trabajo

### 8.1 Generar múltiples variantes rápidas

**Estructura formal**

```
FLUJO DE GENERACIÓN DE VARIANTES

Paso 1: TIME-BOXED SKETCHING (30-60 min)
────────────────────────────────────────
  • 8-12 sketches en papel
  • 3-5 min máximo por sketch
  • NO juzgar durante el proceso
  • Variar por eje (layout, tipo, color, componente)

Paso 2: SELECCIÓN RÁPIDA (15 min)
────────────────────────────────────────
  • Dot voting: cada persona marca 3 favoritos
  • Discutir brevemente por qué
  • Seleccionar 3-4 para digitalizar

Paso 3: DIGITALIZACIÓN LO-FI (1-2 horas)
────────────────────────────────────────
  • Figma: wireframes grises
  • Contenido placeholder pero realista
  • Comparar side by side

Paso 4: FEEDBACK + FILTRO (30 min)
────────────────────────────────────────
  • Presentar 3-4 opciones con contexto
  • Recoger feedback específico
  • Seleccionar 1-2 para refinamiento
```

---

### 8.2 Iterar sobre las mejores opciones

```
ITERACIÓN PROGRESIVA

  V0 (sketch)          V1 (lo-fi)           V2 (mid-fi)
  ┌──────┐             ┌──────────┐         ┌──────────────┐
  │ ~~~~ │             │ Logo Nav │         │ Acme   Nav   │
  │ ~~~~ │             │ ──────── │         │ ───────────  │
  │ [xx] │    ──▶      │ Hero     │  ──▶    │ Hero image   │
  │      │             │ ──────── │         │ H1 headline  │
  └──────┘             │ Cards    │         │ Body text    │
  (3 min)              └──────────┘         │ [CTA button] │
                       (15 min)             └──────────────┘
                                            (45 min)

  Cambios entre V0 → V1:             Cambios entre V1 → V2:
  • Definir secciones                 • Tipografía real
  • Orden del contenido               • Espaciado proporcional
  • Flujo de lectura                  • Contenido representativo
                                      • 1 color de acento

  V3 (hi-fi)
  ┌──────────────────┐
  │ [Acme logo] Nav  │
  │ ═══════════════  │    Cambios entre V2 → V3:
  │ ┌──────────────┐ │    • Colores finales
  │ │  Hero real   │ │    • Imágenes reales
  │ └──────────────┘ │    • Tipografía exacta
  │ Build Something  │    • Sombras, bordes, radii
  │ Amazing Today    │    • Iconografía
  │                  │    • Microinteracciones
  │ [▓▓ Start ▓▓]   │
  └──────────────────┘
  (3-4 horas)
```

---

### 8.3 Documentar decisiones

**Aplicación práctica**

```
TEMPLATE DE DECISIÓN DE DISEÑO

┌─────────────────────────────────────────────────┐
│  DESIGN DECISION LOG                            │
│  ─────────────────                              │
│  Pantalla: Home page                            │
│  Fecha: 2026-04-15                              │
│  Variantes exploradas: 8 sketches, 4 lo-fi,    │
│                        2 mid-fi                 │
│                                                 │
│  DECISIÓN: Layout Hero-driven (Variante A)      │
│                                                 │
│  POR QUÉ:                                      │
│  ✅ Mayor claridad en la propuesta de valor     │
│  ✅ CTA más visible → mejor conversión esperada │
│  ✅ Alineado con benchmark de competencia       │
│                                                 │
│  DESCARTAMOS:                                   │
│  ❌ Content-first: demasiado denso para la marca│
│  ❌ Minimal: insuficiente contexto para el      │
│     usuario nuevo                               │
│                                                 │
│  RIESGOS:                                       │
│  ⚠️  Depende de buena fotografía               │
│  ⚠️  Copy debe ser excepcional                 │
│                                                 │
│  SIGUIENTE PASO:                                │
│  → Llevar a hi-fi con contenido real            │
│  → Testear con 5 usuarios                       │
└─────────────────────────────────────────────────┘
```

---

### 8.4 Refinar progresivamente

```
CHECKLIST DE REFINAMIENTO POR FIDELIDAD

Lo-fi → Mid-fi:
  □ Secciones definidas y ordenadas
  □ Jerarquía de contenido clara
  □ Flujo de lectura lógico (F-pattern o Z-pattern)
  □ CTA principal identificable
  □ Responsive considerado

Mid-fi → Hi-fi:
  □ Tipografía seleccionada (family + scale)
  □ Paleta de color aplicada
  □ Espaciado con sistema (4px o 8px grid)
  □ Componentes consistentes
  □ Contenido real o muy realista
  □ Estados de componentes definidos

Hi-fi → Entrega:
  □ Pixel perfect en breakpoints clave
  □ Design tokens documentados
  □ Estados de todos los componentes
  □ Animaciones/transiciones especificadas
  □ Edge cases cubiertos (empty, error, loading)
  □ Handoff notes para desarrollo
```

---

### 8.5 Validar antes de finalizar

```
GATES DE VALIDACIÓN

Gate 1: ¿La estructura funciona?
  └─ Test: 5-second test con wireframes
     "¿De qué trata esta página?"
     Si > 80% responde correctamente → PASS

Gate 2: ¿La jerarquía es clara?
  └─ Test: Squint test (entrecierra los ojos)
     ¿Puedes distinguir qué es primario, secundario, terciario?
     Si los 3 niveles son evidentes → PASS

Gate 3: ¿Es usable?
  └─ Test: Task completion con prototipo
     "Agrega este producto al carrito"
     Si > 90% completa sin ayuda → PASS

Gate 4: ¿Es consistente?
  └─ Test: Revisión contra design system
     ¿Todos los componentes siguen las specs?
     Si hay 0 desviaciones injustificadas → PASS

Gate 5: ¿Está aprobado?
  └─ Test: Presentación a stakeholders
     ¿Hay cambios estructurales pendientes?
     Si solo hay ajustes menores → PASS → handoff
```

---

## 9. Herramientas y flujo de trabajo

### 9.1 Figma: variantes y auto layout

**Intuición**
Figma no es solo una herramienta de dibujo — es un **sistema de decisiones visuales**. Usarla bien para exploración significa dominar variantes (para comparar) y auto layout (para escalar rápido).

**Estructura formal**

```
VARIANTES EN FIGMA — Organización para exploración

Component Set: "Button"
┌─────────────────────────────────────────────────┐
│                                                 │
│  Variant 1: Style                               │
│  ├── Filled                                     │
│  ├── Outline                                    │
│  └── Ghost                                      │
│                                                 │
│  Variant 2: Size                                │
│  ├── Large                                      │
│  ├── Medium                                     │
│  └── Small                                      │
│                                                 │
│  Variant 3: State                               │
│  ├── Default                                    │
│  ├── Hover                                      │
│  ├── Active                                     │
│  ├── Focused                                    │
│  └── Disabled                                   │
│                                                 │
│  Total combinations: 3 × 3 × 5 = 45 states     │
│  All managed in a single component              │
└─────────────────────────────────────────────────┘
```

```
AUTO LAYOUT — Flujo de exploración rápida

Sin auto layout:                Con auto layout:
  Mover card A → recalcular     Agregar card D → todo se
  posición de B y C              reordena automáticamente
  manualmente
                                ┌────┐ ┌────┐ ┌────┐ ┌────┐
  ┌────┐  ┌────┐  ┌────┐      │ A  │ │ B  │ │ C  │ │ D  │
  │ A  │  │ B  │  │ C  │      └────┘ └────┘ └────┘ └────┘
  └────┘  └────┘  └────┘        ↑
     ↑       ↑       ↑          Auto layout: gap: 16,
  Posición manual cada una       padding: 24, direction: horizontal
  → 5 min por cambio            → 5 seg por cambio
```

---

### 9.2 Uso de componentes reutilizables

```
ESTRATEGIA DE COMPONENTES PARA EXPLORACIÓN

Nivel 1: Atoms (crear primero)
  ├── Button (filled, outline, ghost × 3 sizes)
  ├── Input (text, select, checkbox)
  ├── Text styles (H1-H6, body, caption)
  ├── Color styles (primary, neutral, semantic)
  └── Icon set (20-30 básicos)

Nivel 2: Molecules (combinar atoms)
  ├── Card (product, text, stat)
  ├── Nav item (icon + label)
  ├── Form field (label + input + helper)
  └── List item (icon + text + action)

Nivel 3: Organisms (combinar molecules)
  ├── Navigation (top, sidebar, bottom)
  ├── Hero section (3-4 variantes)
  ├── Card grid (2, 3, 4 columnas)
  └── Footer (simple, extended)

BENEFICIO:
  → Cambiar un atom actualiza TODAS las pantallas
  → Explorar = recombinar componentes existentes
  → Consistencia automática entre variantes
```

---

### 9.3 Versionado de exploraciones

```
SISTEMA DE VERSIONADO EN FIGMA

Estructura de páginas:
┌─────────────────────────────────┐
│  📄 Cover                       │ ← Portada del archivo
│  📄 —— EXPLORATION ——           │ ← Separador
│  📄 v0.1 — Sketches             │ ← Ideas iniciales
│  📄 v0.2 — Lo-fi wireframes    │ ← Wireframes seleccionados
│  📄 v0.3 — Direction A (mid-fi)│ ← Dirección A refinada
│  📄 v0.3 — Direction B (mid-fi)│ ← Dirección B refinada
│  📄 —— SELECTED ——             │ ← Separador
│  📄 v1.0 — Final design        │ ← Diseño aprobado
│  📄 v1.1 — Revisions           │ ← Ajustes post-feedback
│  📄 —— HANDOFF ——              │ ← Separador
│  📄 Specs & Redlines           │ ← Para desarrollo
│  📄 Components                  │ ← Librería local
└─────────────────────────────────┘

REGLAS:
  • Nunca borrar páginas de exploración
  • Nombrar con versión + descripción
  • Marcar la dirección seleccionada claramente
  • Usar branch de Figma para exploraciones grandes
```

---

### 9.4 Organización de archivos

```
ESTRUCTURA DE PROYECTO EN FIGMA

Proyecto/
├── 📁 Research
│   ├── Moodboard
│   ├── Competitive analysis
│   └── User personas
│
├── 📁 Exploration
│   ├── Sketches & Crazy 8s (fotos)
│   ├── Wireframes (lo-fi)
│   ├── Direction A (mid-fi)
│   ├── Direction B (mid-fi)
│   └── Decision log
│
├── 📁 Design
│   ├── Desktop (hi-fi)
│   ├── Tablet (hi-fi)
│   ├── Mobile (hi-fi)
│   └── Prototype links
│
├── 📁 Design System
│   ├── Tokens (colors, type, spacing)
│   ├── Components
│   └── Patterns
│
└── 📁 Handoff
    ├── Specs
    ├── Assets
    └── Dev notes

CONVENCIÓN DE NOMBRES:
  [Tipo]-[Pantalla]-[Versión]-[Estado]
  Ejemplo: "Explore-Home-v02-DirectionA"
```

---

## 10. Nivel intermedio / avanzado

### 10.1 Sistemas visuales consistentes

**Intuición**
Un sistema visual no es un design system (que incluye código, documentación y procesos). Un sistema visual es el **conjunto de reglas visuales** que hacen que todas las pantallas de tu producto se sientan como una familia: comparten tipografía, colores, espaciado, bordes, sombras.

**Estructura formal**

```
ELEMENTOS DE UN SISTEMA VISUAL

1. TYPE SCALE (progresión tipográfica)
   ─────────────────────────────────
   Display:   48px / 56px  — Headlines de marketing
   H1:        32px / 40px  — Títulos de página
   H2:        24px / 32px  — Títulos de sección
   H3:        20px / 28px  — Subtítulos
   Body:      16px / 24px  — Texto principal
   Small:     14px / 20px  — Texto secundario
   Caption:   12px / 16px  — Metadata

2. COLOR SYSTEM
   ─────────────
   Primary:    ▓▓▓ #2563EB  (acciones, links, acento)
   Secondary:  ▓▓▓ #7C3AED  (complementario)
   Neutral:    ░░░ #111827 → #F9FAFB  (escala de grises)
   Success:    ▓▓▓ #059669  (confirmación)
   Warning:    ▓▓▓ #D97706  (precaución)
   Error:      ▓▓▓ #DC2626  (error, destructivo)

3. SPACING SCALE (base 4px o 8px)
   ──────────────
   4px  → separación mínima (inline elements)
   8px  → espacio entre elementos relacionados
   16px → espacio entre componentes
   24px → espacio entre secciones menores
   32px → espacio entre secciones principales
   48px → espacio entre bloques de contenido
   64px → espacio entre secciones de página

4. BORDER RADIUS
   ──────────────
   None:    0px   → Tablas, dividers
   Small:   4px   → Badges, chips
   Medium:  8px   → Cards, inputs, buttons
   Large:   12px  → Modales, grandes contenedores
   Full:    9999px → Avatares, pills
```

---

### 10.2 Exploración dentro de design systems

**Intuición**
Explorar visualmente dentro de un design system no significa que "todo ya está decidido". Significa que **tienes restricciones inteligentes** que guían tu creatividad. Como un músico de jazz: conoce las escalas (el sistema), pero improvisa dentro de ellas.

```
EXPLORACIÓN CON DESIGN SYSTEM

Lo que puedes variar:             Lo que NO deberías variar:
─────────────────────             ──────────────────────────
✅ Layout y estructura             ❌ Colores fuera de paleta
✅ Orden y prioridad de contenido  ❌ Tipografía no aprobada
✅ Combinación de componentes      ❌ Espaciado arbitrario
✅ Densidad de información         ❌ Componentes custom sin justificar
✅ Jerarquía de acciones           ❌ Bordes/sombras inconsistentes
✅ Responsive behavior             ❌ Iconografía mezclada

EJEMPLO: 3 variantes de dashboard dentro del mismo design system

Variante A:                  Variante B:              Variante C:
┌────┬────────────────┐     ┌─────────────────────┐  ┌────┬────────────────┐
│nav │ KPIs   KPIs    │     │ nav horizontal      │  │nav │ Tabla principal │
│    │ ┌────┐ ┌────┐  │     ├─────────────────────┤  │    │                │
│    │ │ 42%│ │ $1k│  │     │ KPI │ KPI │ KPI│KPI│  │    │ ┌────────────┐ │
│    │ └────┘ └────┘  │     ├─────────────────────┤  │    │ │ row  row   │ │
│    │ ┌────────────┐ │     │                     │  │    │ │ row  row   │ │
│    │ │  Gráfico   │ │     │  Gráfico grande     │  │    │ │ row  row   │ │
│    │ └────────────┘ │     │                     │  │    │ └────────────┘ │
│    │ ┌────────────┐ │     │                     │  │    │ ┌────┐ ┌────┐ │
│    │ │   Tabla    │ │     ├──────────┬──────────┤  │    │ │mini│ │mini│ │
│    │ └────────────┘ │     │  Tabla   │  Recient │  │    │ │graf│ │graf│ │
└────┴────────────────┘     └──────────┴──────────┘  └────┴────────────────┘
Prioriza: overview           Prioriza: tendencias    Prioriza: datos detalle
(KPIs arriba, gráfico,       (gráfico grande,        (tabla como hero,
 tabla al final)              tabla y actividad)       gráficos de soporte)

→ Mismos componentes, mismos colores, misma tipografía
→ Lo que cambió: LAYOUT, PRIORIDAD y JERARQUÍA
```

---

### 10.3 Balance entre creatividad y consistencia

**Estructura formal**

```
ESPECTRO DE LIBERTAD CREATIVA

  100% CONSISTENCIA                            100% CREATIVIDAD
  (todo es idéntico)                           (todo es único)
       │◄──────────────────────────────────────────►│
       │                                            │
       │   ★ ZONA ÓPTIMA ★                         │
       │   ├──────────────────┤                     │
       │                                            │
  Problema:                                    Problema:
  "Todo se ve igual"                           "Nada se ve conectado"
  "Aburrido"                                   "Inconsistente"
  "Sin personalidad"                           "Caótico"

REGLA DEL 80/20:
  80% del diseño sigue el sistema (consistencia)
  20% tiene espacio para soluciones únicas (creatividad)

DÓNDE APLICAR EL 20% CREATIVO:
  • Landing pages (hero sections)
  • Onboarding flows
  • Empty states
  • Feature highlights
  • Marketing pages
  • Momentos de deleite (microinteracciones)

DÓNDE MANTENER EL 80% CONSISTENTE:
  • Formularios
  • Navegación
  • Tablas de datos
  • Settings/configuración
  • Flujos transaccionales
  • Feedback del sistema (errores, success)
```

---

### 10.4 Diseño para productos complejos

```
ESTRATEGIA DE EXPLORACIÓN PARA PRODUCTOS COMPLEJOS

Producto SaaS:
─────────────
Desafío: Muchas funciones, usuarios diversos, data-heavy
Estrategia:
  1. Explorar por MÓDULO, no por pantalla
  2. Definir patrones de página (list, detail, create, settings)
  3. Explorar densidad de información por rol de usuario
  4. Crear "page templates" reutilizables

  Template: List Page              Template: Detail Page
  ┌────────────────────┐           ┌────────────────────┐
  │ Title    [+ New]   │           │ ← Back    [Actions]│
  │ Filters  Search    │           │ ─────────────────  │
  │ ┌────────────────┐ │           │ Title              │
  │ │ item   item    │ │           │ Status: Active     │
  │ │ item   item    │ │           │ ┌──────┬─────────┐ │
  │ │ item   item    │ │           │ │Info  │ Activity│ │
  │ └────────────────┘ │           │ │panel │ feed    │ │
  │ Pagination         │           │ └──────┴─────────┘ │
  └────────────────────┘           └────────────────────┘

Producto E-commerce:
───────────────────
Desafío: Conversión, confianza, mucho catálogo
Estrategia:
  1. Explorar el funnel completo (home → product → cart → checkout)
  2. Optimizar cada paso para reducir abandono
  3. Explorar densidad de cards por viewport
  4. A/B test visual en CTA, layout de producto, checkout

  Home → Categoría → Producto → Cart → Checkout → Confirmación
   │         │           │        │        │            │
   └─────────┴───────────┴────────┴────────┴────────────┘
   Cada paso tiene 2-3 variantes exploradas
   y métricas de conversión asociadas
```

---

### 10.5 Creación de identidad visual a través de exploración

**Intuición**
La identidad visual de un producto no se define en un brief de marca — se **descubre** a través de exploración. Cuando diseñas múltiples variantes y empiezas a notar "esto se siente como nosotros" vs "esto no se siente como nosotros", estás descubriendo tu identidad visual.

```
PROCESO DE DESCUBRIMIENTO DE IDENTIDAD VISUAL

Paso 1: MOODBOARD (sin restricciones)
───────────────────────────────────────
  • 30-50 referencias visuales
  • De cualquier industria
  • Que evoquen el "feeling" del producto

  ┌──────────────────────────────────────┐
  │ ┌─────┐ ┌───┐ ┌───────┐ ┌──────┐  │
  │ │ ref │ │ref│ │  ref  │ │ ref  │  │
  │ │  1  │ │ 2 │ │   3   │ │  4   │  │
  │ └─────┘ └───┘ └───────┘ └──────┘  │
  │ ┌───────┐ ┌────┐ ┌───┐ ┌──────┐   │
  │ │ ref 5 │ │ref6│ │r7 │ │ ref8 │   │
  │ └───────┘ └────┘ └───┘ └──────┘   │
  └──────────────────────────────────────┘

  Pregunta: "¿Qué tienen en común las que más nos gustan?"
  → Colores fríos, tipografía geométrica, mucho espacio blanco

Paso 2: STYLE TILES (3-4 direcciones)
──────────────────────────────────────
  Dirección A: "Bold & Energetic"
  ┌────────────────────────────┐
  │ Colores: ■ ■ ■  (saturados)│
  │ Tipo: Montserrat Bold      │
  │ Estilo: High contrast,     │
  │         large type, minimal │
  │ Ejemplo CTA: [▓▓ GO ▓▓]   │
  └────────────────────────────┘

  Dirección B: "Refined & Quiet"
  ┌────────────────────────────┐
  │ Colores: ░ ░ ░  (neutros)  │
  │ Tipo: Inter Regular        │
  │ Estilo: Subtle shadows,    │
  │         generous spacing   │
  │ Ejemplo CTA: [ Continue ]  │
  └────────────────────────────┘

Paso 3: APLICAR A 1-2 PANTALLAS
────────────────────────────────
  • Misma pantalla (ej: home) diseñada en cada dirección
  • Comparar side by side
  • Evaluar: ¿Cuál se siente más "nosotros"?

Paso 4: REFINAR IDENTIDAD
──────────────────────────
  • Documentar la dirección elegida
  • Extraer tokens (colores, tipografía, espaciado, bordes)
  • Crear UI kit base
  • Aplicar a 3-5 pantallas para validar consistencia
```

---

## Cheat Sheet — Visual Exploration

```
┌─────────────────────────────────────────────────────────────────┐
│                    VISUAL EXPLORATION CHEAT SHEET                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PROCESO:                                                       │
│    Brief → 8+ variantes rápidas → evaluar → 2-3 refinadas      │
│    → feedback → 1 solución → pulir → entregar                  │
│                                                                 │
│  REGLA DE ORO:                                                  │
│    Diverge primero (cantidad), converge después (calidad)       │
│                                                                 │
│  FIDELIDAD:                                                     │
│    Lo-fi: estructura (2-5 min) → Mid-fi: jerarquía (15-45 min) │
│    → Hi-fi: visual final (2-8 hrs)                              │
│                                                                 │
│  EJES DE EXPLORACIÓN:                                           │
│    Layout │ Tipografía │ Color │ Componentes                    │
│    Varía uno a la vez para comparar el impacto                  │
│                                                                 │
│  EVALUACIÓN:                                                    │
│    Claridad (25%) > Usabilidad (30%) > Consistencia (20%)       │
│    > Estética (15%) > Viabilidad (10%)                          │
│                                                                 │
│  ANTI-ANCLAJE:                                                  │
│    • "3 antes de 1" → 3 alternativas antes de invertir tiempo   │
│    • Kill your darlings → descarta tu favorita y diseña sin ella│
│    • Timer estricto → 3-5 min máximo por variante inicial       │
│                                                                 │
│  NAVEGACIÓN:                                                    │
│    Top (5-7 items, web) │ Sidebar (10+, SaaS)                   │
│    Bottom (3-5, mobile)                                         │
│                                                                 │
│  BOTONES:                                                       │
│    Filled → primario │ Outline → secundario                     │
│    Ghost → terciario │ Link → navegación                        │
│                                                                 │
│  HOME LAYOUTS:                                                  │
│    Hero-driven (branding) │ Content-first (e-commerce)          │
│    Minimal (SaaS)                                               │
│                                                                 │
│  DOCUMENTAR SIEMPRE:                                            │
│    Qué se eligió + por qué + qué se descartó + riesgos         │
│                                                                 │
│  FIGMA:                                                         │
│    Variantes para comparar │ Auto layout para escalar           │
│    Páginas por versión │ Nunca borrar exploración               │
│                                                                 │
│  AVANZADO:                                                      │
│    80% sistema + 20% creatividad                                │
│    Explorar por módulo en SaaS                                  │
│    Identidad visual = se descubre, no se impone                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Errores comunes en Visual Exploration

| # | Error | Por qué es problema | Cómo evitarlo |
|---|---|---|---|
| 1 | **Enamorarse de la primera idea** | Sesgo de anclaje, no exploras alternativas reales | Regla "3 antes de 1" |
| 2 | **Ir directo a hi-fi** | Sunk cost fallacy, cambios estructurales son caros | Empezar siempre en lo-fi |
| 3 | **Explorar poco** | Solo 1-2 variantes no es exploración | Mínimo 5-8 sketches rápidos |
| 4 | **Explorar sin criterios** | No puedes elegir la "mejor" sin definir "mejor para qué" | Definir criterios ANTES de explorar |
| 5 | **Sobrediseñar** | Exploración no es perfección, es velocidad | Timer estricto, fidelidad apropiada |
| 6 | **Variaciones superficiales** | Mover el CTA de izquierda a derecha no es explorar | Cambiar el enfoque completo, no el detalle |
| 7 | **No documentar decisiones** | Se olvida por qué se eligió algo, se rediscute | Template de decisión de diseño |
| 8 | **Inconsistencia entre variantes** | Comparar manzanas con naranjas | Mismo contenido, misma fidelidad en todas |
| 9 | **Pedir feedback sin contexto** | "¿Cuál te gusta?" → feedback inútil | "Cada opción optimiza X, ¿cuál priorizamos?" |
| 10 | **No iterar después de elegir** | Elegir ≠ terminar, la opción ganadora necesita refinamiento | Planificar 2-3 rondas post-selección |
| 11 | **Explorar solo el layout** | Ignorar tipografía, color, componentes | Variar por eje deliberadamente |
| 12 | **Borrar la exploración** | Perder el contexto de decisiones pasadas | Versionado en Figma, nunca borrar páginas |

---

> **Nota final:** La exploración visual no es una fase que "se termina". Es una **mentalidad**: en cada decisión de diseño, pregúntate "¿exploré alternativas suficientes?". Los mejores diseñadores no son los que tienen la primera idea más brillante — son los que exploran más, evalúan mejor, y seleccionan con criterios claros.
