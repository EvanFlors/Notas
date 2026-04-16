# Spacing & Grid Systems — Módulo Completo

---

## 1. Introducción a Spacing y Grids

### 1.1 Qué es Spacing y Por Qué es Crítico

- **Intuición:** El spacing es el "silencio" entre elementos de una interfaz. Así como en música las pausas definen el ritmo y la emoción, en diseño el espacio vacío define la claridad, la jerarquía y la respiración visual. Sin spacing intencional, una interfaz es ruido.
- **Estructura formal:** Spacing es la distancia deliberada entre y dentro de los elementos de una interfaz — controlada por margin, padding y gap — que establece relaciones visuales, agrupa contenido relacionado y separa contenido no relacionado.
- **Aplicación práctica:** Cada decisión de spacing responde a una pregunta: *¿estos dos elementos están relacionados o no?* Si sí → espacio pequeño. Si no → espacio grande. Esa lógica simple, aplicada con consistencia, produce interfaces que se sienten profesionales y claras.

### 1.2 Qué es un Grid System y su Propósito

- **Intuición:** Un grid es la cuadrícula invisible que organiza dónde va cada cosa en la pantalla. Piensa en las líneas de un cuaderno — no las ves en el contenido final, pero definen la estructura de todo lo que se escribe.
- **Estructura formal:** Un grid system es una estructura de columnas, márgenes y gutters que divide el viewport en regiones proporcionales, proporcionando un framework para posicionar y alinear contenido de forma predecible y consistente.
- **Aplicación práctica:** Sin grid, cada pantalla se diseña desde cero y nada se alinea. Con grid, tienes un sistema donde las decisiones de layout ya están tomadas — solo eliges cuántas columnas ocupa cada elemento.

### 1.3 Relación entre Spacing, Layout y Jerarquía Visual

```
Jerarquía visual = Tamaño + Color/Peso + ★ SPACING ★

  ┌─────────────────────────────────────────────┐
  │                                             │
  │   TÍTULO PRINCIPAL                          │  ← más espacio arriba
  │                                             │     (separa del contexto anterior)
  │   Subtítulo descriptivo                     │  ← poco espacio
  │                                             │     (pertenece al título)
  │   Párrafo de texto que explica el           │  ← espacio medio
  │   contenido de esta sección con más         │     (relacionado pero diferente)
  │   detalle y contexto para el usuario.       │
  │                                             │
  │                                             │  ← MUCHO espacio
  │                                             │     (separa secciones)
  │   SIGUIENTE SECCIÓN                         │
  │                                             │
  └─────────────────────────────────────────────┘

  Principio de proximidad (Gestalt):
  Elementos cercanos → se perciben como grupo
  Elementos lejanos  → se perciben como separados
```

**Regla fundamental:** El spacing comunica relación. No es decoración — es **información**.

### 1.4 Impacto en Legibilidad, Escaneo y Usabilidad

| Aspecto | Spacing pobre | Spacing intencional |
|---|---|---|
| **Legibilidad** | Texto apretado, difícil de leer | Line-height y párrafos con respiración |
| **Escaneo** | Todo parece igual de importante | La jerarquía de espacio guía el ojo |
| **Usabilidad** | Targets táctiles muy juntos | Áreas de toque cómodas (48px mín) |
| **Percepción** | "Se siente amateur, saturado" | "Se siente profesional, limpio" |
| **Carga cognitiva** | Alta — usuario no sabe dónde mirar | Baja — la interfaz respira |

> **Error común:** Pensar que spacing es "espacio desperdiciado". En realidad, el espacio vacío es uno de los elementos de diseño más poderosos — comunica calma, jerarquía y profesionalismo.

---

## 2. Fundamentos de Spacing

### 2.1 Tipos de Spacing

```
┌──────────────────────── MARGIN (externo) ──────┐
│                                                 │
│    ┌──────────── PADDING (interno) ──────┐     │
│    │                                     │     │
│    │         [ Contenido ]               │     │
│    │                                     │     │
│    └─────────────────────────────────────┘     │
│                                                 │
│                    GAP                           │
│                                                 │
│    ┌─────────────────────────────────────┐     │
│    │                                     │     │
│    │         [ Contenido ]               │     │
│    │                                     │     │
│    └─────────────────────────────────────┘     │
│                                                 │
└─────────────────────────────────────────────────┘
```

| Tipo | Qué controla | Analogía | CSS |
|---|---|---|---|
| **Margin** | Espacio FUERA del elemento | Distancia entre muebles | `margin` |
| **Padding** | Espacio DENTRO del elemento | Margen de un cuadro alrededor del contenido | `padding` |
| **Gap** | Espacio ENTRE hijos de un contenedor | Pasillo entre asientos | `gap` (grid/flex) |

```css
/* Margin — separa este elemento de los demás */
.card {
  margin-bottom: 24px;
}

/* Padding — espacio interno del elemento */
.card {
  padding: 24px;
}

/* Gap — espacio entre hijos (moderno, limpio) */
.card-grid {
  display: grid;
  gap: 24px;        /* reemplaza margins entre hijos */
}
```

> **Preferencia moderna:** Usar `gap` siempre que sea posible (en grid y flexbox). Evita problemas de margin collapsing y es más predecible.

### 2.2 Sistemas de Spacing: Escala Base

Un sistema de spacing define **valores fijos** que se usan en toda la interfaz. Nunca espaciado arbitrario.

**Escala base de 4px (la más común):**

```
Escala de spacing (4px base):

  Nombre      Valor     Uso típico
  ─────────────────────────────────────────────────
  xxs         2px       Borde óptico, ajuste fino
  xs          4px       Spacing mínimo entre inline elements
  sm          8px       Spacing interno compacto, icon gap
  md          12px      Padding de botones, gap en forms
  base        16px      Padding de cards, gap de secciones
  lg          24px      Separación entre bloques
  xl          32px      Separación entre secciones
  2xl         48px      Separación entre secciones grandes
  3xl         64px      Page sections, hero spacing
  4xl         96px      Mega spacing, page-level
  5xl         128px     Hero sections, landing page

  Patrón: 2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128
          (múltiplos de 4, con 12 como excepción útil)
```

**¿Por qué base 4?**

- La mayoría de resoluciones de pantalla son divisibles por 4
- Escala lo suficientemente granular sin ser caótica
- Compatible con grids de 4, 8 y 12 columnas
- Standard de la industria (Material Design, Apple HIG, Tailwind)

**¿Por qué NO spacing arbitrario?**

```
❌ Spacing arbitrario:
  margin-top: 13px;
  padding: 17px;
  gap: 11px;
  margin-bottom: 23px;
  → Cada valor es diferente, sin lógica, imposible de mantener

✅ Spacing sistemático:
  margin-top: 12px;    /* md */
  padding: 16px;       /* base */
  gap: 8px;            /* sm */
  margin-bottom: 24px; /* lg */
  → Todos en la escala de 4px, predecible y mantenible
```

### 2.3 Ritmo Vertical (Vertical Rhythm)

- **Intuición:** El ritmo vertical es la cadencia regular de espacio a lo largo del eje Y de tu página. Como un metrónomo visual — crea un patrón predecible que el ojo sigue con confort.
- **Estructura formal:** Vertical rhythm significa que todos los elementos se alinean a una baseline grid (usualmente de 4px u 8px), creando una progresión vertical consistente.

```
Ritmo vertical con baseline de 8px:

  ── 0px   ┌────────────────────────────────┐
            │  Heading (line-height: 40px)   │  40 = 8×5 ✓
  ── 40px  └────────────────────────────────┘
  ── 48px  ┌────────────────────────────────┐  8px gap ✓
            │  Subheading (line-height: 24px)│  24 = 8×3 ✓
  ── 72px  └────────────────────────────────┘
  ── 80px                                      8px gap ✓
  ── 80px  ┌────────────────────────────────┐
            │  Párrafo (line-height: 24px)   │  24 = 8×3 ✓
            │  Segunda línea del párrafo     │
            │  Tercera línea del párrafo     │
  ──152px  └────────────────────────────────┘
  ──176px  ┌────────────────────────────────┐  24px gap ✓
            │  Siguiente sección             │
            └────────────────────────────────┘

  Todo alineado a la grid de 8px → ritmo vertical consistente
```

**Práctica:** Asegúrate de que `line-height` y `margin/padding` sean múltiplos de tu base (4 u 8).

### 2.4 Spacing y Jerarquía Visual

El spacing crea **niveles de agrupación**:

```
Niveles de spacing jerárquico:

  Nivel 1: Intra-componente (4-8px)
  ┌────────────────────────────┐
  │  [Icon] 8px [Label]       │  ← entre icono y texto
  └────────────────────────────┘

  Nivel 2: Entre elementos relacionados (8-16px)
  ┌────────────────────────────┐
  │  Label                     │
  │  8px                       │  ← label y su input
  │  [Input field_______]      │
  │  16px                      │  ← entre campos de un form
  │  Label                     │
  │  8px                       │
  │  [Input field_______]      │
  └────────────────────────────┘

  Nivel 3: Entre bloques/secciones (24-48px)
  ┌────────────────────────────┐
  │  Sección de Contacto       │
  │  (formulario completo)     │
  └────────────────────────────┘
              32px                 ← entre secciones
  ┌────────────────────────────┐
  │  Sección de FAQ            │
  │  (acordeón completo)       │
  └────────────────────────────┘

  Nivel 4: Entre secciones de página (48-96px)
  ═══════════════════════════════
  │  Hero Section              │
  ═══════════════════════════════
              64px                 ← entre secciones de página
  ═══════════════════════════════
  │  Features Section          │
  ═══════════════════════════════
```

**Regla:** Cuanto más relacionados están dos elementos, menor es el espacio entre ellos. Cuanto menos relacionados, mayor el espacio.

### 2.5 Densidad de Interfaz

| Densidad | Spacing típico | Uso | Ejemplo |
|---|---|---|---|
| **Compacta** | 4-8px entre elementos | Dashboards, tablas de datos, herramientas pro | Bloomberg terminal, VS Code |
| **Default** | 8-16px entre elementos | Apps generales, e-commerce, SaaS | Gmail, Spotify |
| **Espaciosa** | 16-32px entre elementos | Landing pages, marketing, onboarding | Apple.com, Stripe |

```
Compacta (data-dense):
┌────────────────────────────────────────┐
│ Name        │ Status  │ Date   │ Amt  │
│─────────────┼─────────┼────────┼──────│
│ John Smith  │ Active  │ 04/15  │ $120 │  4px row padding
│ Jane Doe    │ Pending │ 04/14  │ $85  │  4px row padding
│ Bob Wilson  │ Active  │ 04/13  │ $240 │  4px row padding
└────────────────────────────────────────┘

Default:
┌────────────────────────────────────────┐
│ Name          │ Status   │ Date │ Amt  │
│               │          │      │      │
│ John Smith    │ Active   │04/15 │ $120 │  12px row padding
│               │          │      │      │
│ Jane Doe      │ Pending  │04/14 │ $85  │  12px row padding
│               │          │      │      │
└────────────────────────────────────────┘

Espaciosa:
┌─────────────────────────────────────────┐
│                                         │
│   John Smith                            │
│   Active · Apr 15, 2026 · $120.00      │  24px padding
│                                         │
│─────────────────────────────────────────│
│                                         │
│   Jane Doe                              │
│   Pending · Apr 14, 2026 · $85.00      │  24px padding
│                                         │
└─────────────────────────────────────────┘
```

> **Decisión clave:** La densidad depende del **usuario y la tarea**. Un trader necesita densidad compacta (mucha info rápido). Un usuario casual necesita espacio (claridad sobre velocidad).

---

## 3. Grid Systems (Fundamentos)

### 3.1 Qué es un Grid

- **Intuición:** Un grid es una estructura invisible de columnas verticales que divide la pantalla en porciones iguales. Todo tu contenido se alinea a estas columnas, como edificios alineados a lotes de terreno en una calle.
- **Estructura formal:** Un grid system es una estructura bidimensional definida por **columnas** (regiones de contenido), **gutters** (espacio entre columnas) y **márgenes** (espacio en los bordes del viewport), que proporciona alineación y proporción consistentes.

### 3.2 Componentes del Grid

```
← ────────────── Viewport (ancho total de la pantalla) ──────────────── →

  │ Margin │ Col │ Gutter │ Col │ Gutter │ Col │ Gutter │ Col │ Margin │
  │        │     │        │     │        │     │        │     │        │
  │◄──24──►│◄─?─►│◄──16──►│◄─?─►│◄──16──►│◄─?─►│◄──16──►│◄─?─►│◄──24──►│
  │        │     │        │     │        │     │        │     │        │
  │        │█████│        │█████│        │█████│        │█████│        │
  │        │█████│        │█████│        │█████│        │█████│        │
  │        │█████│        │█████│        │█████│        │█████│        │

  Viewport = Margins + (Columns × Column Width) + (Gutters × Gutter Width)

  Container = Viewport - (2 × Margin)
```

| Componente | Qué es | Valor típico |
|---|---|---|
| **Columna** | Región vertical donde se coloca contenido | Flexible (fracción del container) |
| **Gutter** | Espacio entre columnas | 16px, 20px, 24px |
| **Margen** | Espacio entre el borde del viewport y el contenido | 16px (mobile), 24-32px (tablet), 32-64px (desktop) |
| **Container** | Ancho máximo del contenido | 1200px, 1280px, 1440px (fijo o fluid) |

### 3.3 Grids más Comunes

**12 columnas — El estándar de la industria:**

```
12 Column Grid (desktop):

  │1│2│3│4│5│6│7│8│9│10│11│12│
  │▓│▓│▓│▓│▓│▓│▓│▓│▓│▓ │▓ │▓ │

  Divisible por: 1, 2, 3, 4, 6, 12
  Layouts posibles:
  │────── 12 ──────│                    Full width
  │── 6 ──│── 6 ──│                    50/50
  │─ 4 ─│─ 4 ─│─ 4 ─│                 Tercios
  │─ 3 ─│─ 3 ─│─ 3 ─│─ 3 ─│          Cuartos
  │── 8 ──│─ 4 ─│                      Content + sidebar
  │─ 3 ─│──── 9 ────│                  Nav + content
  │─ 3 ─│── 6 ──│─ 3 ─│               Centrado con márgenes
```

**8 columnas — Alternativa para interfaces más simples:**

```
8 Column Grid:

  │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │

  Divisible por: 1, 2, 4, 8
  │──────── 8 ────────│             Full width
  │──── 4 ────│──── 4 ────│        50/50
  │── 2 ──│── 2 ──│── 2 ──│── 2 ──│  Cuartos
```

**4 columnas — Mobile:**

```
4 Column Grid (mobile):

  │  1  │  2  │  3  │  4  │

  │──────── 4 ────────│         Full width
  │── 2 ──│── 2 ──│            50/50 (raro en mobile)

  Mobile casi siempre usa full-width (4/4)
  o stack vertical
```

### 3.4 Cómo Elegir el Número de Columnas

| Contexto | Columnas recomendadas | Por qué |
|---|---|---|
| **Mobile** | 4 | Pantalla angosta, contenido apilado |
| **Tablet** | 8 | Balance entre espacio y flexibilidad |
| **Desktop** | 12 | Máxima flexibilidad de layout |
| **Dashboard complejo** | 12 o 16 | Necesita muchas divisiones |
| **Landing page simple** | 12 (usando pocos) | 12 columnas pero layouts de 2-3 bloques |
| **Email / newsletter** | 6 | Limitaciones de clientes de email |

**Regla práctica:** Usa 12 columnas como default. Solo cambia si tienes una razón específica (como un dashboard que necesita 16).

> **Anti-patrón:** Usar un grid de 5 columnas. No es divisible de forma útil — 5 no se divide en mitades, tercios o cuartos limpios.

---

## 4. Fixed vs Fluid Grids

### 4.1 Fixed Grid

- **Intuición:** Un grid fijo tiene un ancho que no cambia — como un poster impreso. La pantalla puede ser más grande, pero el contenido mantiene su tamaño.
- **Estructura formal:** En un fixed grid, las columnas tienen un ancho definido en píxeles. El container tiene un `max-width` fijo y se centra horizontalmente.

```
Fixed Grid (1200px container):

  Viewport: 1440px
  ┌────────────────────────────────────────────────────────┐
  │        ┌────────────────────────────────┐              │
  │  120px │       1200px container         │  120px       │
  │        │ │col│g│col│g│col│...│col│      │              │
  │        └────────────────────────────────┘              │
  └────────────────────────────────────────────────────────┘

  Viewport: 1200px
  ┌────────────────────────────────────────┐
  │ │col│g│col│g│col│...│col│              │  Sin margen extra
  └────────────────────────────────────────┘

  Viewport: 900px → scroll horizontal o breakpoint
```

```css
/* Fixed Grid */
.container {
  width: 1200px;      /* ancho fijo */
  margin: 0 auto;     /* centrado */
}

.grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 24px;
}
```

| ✅ Ventajas | ❌ Limitaciones |
|---|---|
| Predictible — siempre se ve igual | No se adapta a pantallas pequeñas |
| Fácil de diseñar en Figma | Desperdicia espacio en pantallas grandes |
| Control total del layout | Requiere breakpoints para ser responsive |

### 4.2 Fluid Grid

- **Intuición:** Un grid fluido se estira y encoge con la pantalla — como un acordeón. Las columnas crecen proporcionalmente al espacio disponible.
- **Estructura formal:** Las columnas se definen en porcentajes o fracciones (`fr`), adaptándose al ancho del viewport en tiempo real.

```
Fluid Grid (porcentajes):

  Viewport: 1440px
  ┌──────────────────────────────────────────────────────────┐
  │  24px  │ ████ │ 24px │ ████ │ 24px │ ████ │  24px      │
  │ margin │ 30%  │ gut  │ 30%  │ gut  │ 30%  │ margin     │
  └──────────────────────────────────────────────────────────┘

  Viewport: 1024px
  ┌──────────────────────────────────────┐
  │  24px │ ███ │ 24px │ ███ │ 24px │ ███ │ 24px │
  │       │ 30% │      │ 30% │      │ 30% │      │
  └──────────────────────────────────────┘

  Viewport: 768px
  ┌───────────────────────────┐
  │ 16px │ ██ │16│ ██ │16│ ██ │ 16px │
  │      │30% │  │ 30% │  │30%│      │
  └───────────────────────────┘

  Las columnas se ENCOGEN proporcionalmente
```

```css
/* Fluid Grid */
.container {
  width: 100%;         /* ocupa todo el viewport */
  max-width: 1440px;   /* pero no más de esto */
  margin: 0 auto;
  padding: 0 24px;     /* margins laterales */
}

.grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);  /* fracciones iguales */
  gap: 24px;
}
```

| ✅ Ventajas | ❌ Limitaciones |
|---|---|
| Se adapta a cualquier viewport | Puede estirarse demasiado en pantallas ultra-wide |
| Responsive por naturaleza | Menos control pixel-perfect |
| Menos breakpoints necesarios | Textos pueden ser muy anchos en pantallas grandes |

### 4.3 Hybrid Approach

La solución más profesional: **container fijo dentro de layout fluido**.

```
Hybrid Grid:

  Viewport: 1920px (ultra-wide)
  ┌──────────────────────────────────────────────────────────────────┐
  │  ░░░░░░░  ┌─────────────────────────────┐  ░░░░░░░             │
  │  espacio  │    Container max: 1280px     │  espacio             │
  │  fluido   │    Grid: 12 cols fluid       │  fluido              │
  │           └─────────────────────────────┘                       │
  └──────────────────────────────────────────────────────────────────┘

  Viewport: 1280px
  ┌─────────────────────────────┐
  │    Container: 1280px        │  Container llena el viewport
  │    Grid: 12 cols fluid      │
  └─────────────────────────────┘

  Viewport: 768px (tablet)
  ┌───────────────────┐
  │ 16px│  Grid fluid  │16px│  Container = 100% - margins
  │     │  8 cols      │    │
  └───────────────────┘
```

```css
/* Hybrid: lo mejor de ambos mundos */
.container {
  width: 100%;
  max-width: 1280px;   /* no se estira infinitamente */
  margin: 0 auto;      /* centrado cuando viewport > max-width */
  padding: 0 24px;     /* margins laterales mínimos */
}

.grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 24px;
}
```

> **Recomendación:** Hybrid es el approach default en la industria. Casi todos los design systems profesionales lo usan.

---

## 5. Breakpoints y Responsive Design

### 5.1 Qué son Breakpoints

- **Intuición:** Un breakpoint es el punto donde tu layout "se rompe" — donde el diseño actual ya no funciona bien y necesita reorganizarse. Es como un libro que al encogerse se convierte en folleto: mismo contenido, diferente formato.
- **Estructura formal:** Un breakpoint es un valor de viewport width en el que se aplican reglas CSS diferentes, adaptando grid, spacing, tipografía y layout para ese rango de tamaño.

### 5.2 Breakpoints Comunes

```
Breakpoints estándar:

  0px          576px         768px         1024px        1440px
  │─── Mobile ──│── Tablet ──│─ Desktop S ─│─ Desktop L ─│── XL ──►
  │   4 cols    │   8 cols   │   12 cols   │   12 cols   │ 12 cols
  │  16px marg  │  24px marg │  32px marg  │  64px marg  │ centered
  │   sm gap    │   md gap   │   lg gap    │   lg gap    │  lg gap
```

| Breakpoint | Nombre | Rango típico | Columnas | Margin | Gutter |
|---|---|---|---|---|---|
| **xs** | Mobile small | 0 – 575px | 4 | 16px | 16px |
| **sm** | Mobile large | 576 – 767px | 4 | 16px | 16px |
| **md** | Tablet | 768 – 1023px | 8 | 24px | 20px |
| **lg** | Desktop | 1024 – 1439px | 12 | 32px | 24px |
| **xl** | Desktop large | 1440px+ | 12 | auto (centrado) | 24px |

### 5.3 Mobile-First vs Desktop-First

**Mobile-first (recomendado):**

```css
/* Mobile-First: estilos base = mobile, escalar hacia arriba */

/* Base: mobile (4 cols, stacked) */
.grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 16px;
  padding: 0 16px;
}

/* Tablet: 8 cols, 2 columnas */
@media (min-width: 768px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 20px;
    padding: 0 24px;
  }
}

/* Desktop: 12 cols, 3 columnas */
@media (min-width: 1024px) {
  .grid {
    grid-template-columns: repeat(3, 1fr);
    gap: 24px;
    padding: 0 32px;
  }
}

/* Large desktop: centered container */
@media (min-width: 1440px) {
  .grid {
    max-width: 1280px;
    margin: 0 auto;
  }
}
```

**Desktop-first (legacy, no recomendado):**

```css
/* Desktop-First: estilos base = desktop, reducir hacia abajo */

.grid {
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

@media (max-width: 1023px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 20px;
  }
}

@media (max-width: 767px) {
  .grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
```

| Factor | Mobile-First | Desktop-First |
|---|---|---|
| **Filosofía** | Empezar con lo esencial, agregar | Empezar con todo, quitar |
| **Performance** | Mejor (mobile carga menos CSS) | Peor (mobile carga CSS que no usa) |
| **Prioridad** | Contenido primero | Features primero |
| **Industria** | Standard actual | Legacy |

### 5.4 Adaptación del Grid según Breakpoint

```
Ejemplo: Grid de cards de producto

  ┌── Desktop (1280px) ─ 12 cols ──────────────────────────┐
  │                                                         │
  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐               │
  │  │ Card │  │ Card │  │ Card │  │ Card │               │
  │  │  3c  │  │  3c  │  │  3c  │  │  3c  │   4 por fila │
  │  └──────┘  └──────┘  └──────┘  └──────┘               │
  │                                                         │
  └─────────────────────────────────────────────────────────┘

  ┌── Tablet (768px) ─ 8 cols ──────────────┐
  │                                          │
  │  ┌──────────┐  ┌──────────┐             │
  │  │   Card   │  │   Card   │  2 por fila │
  │  │   4c     │  │   4c     │             │
  │  └──────────┘  └──────────┘             │
  │  ┌──────────┐  ┌──────────┐             │
  │  │   Card   │  │   Card   │             │
  │  └──────────┘  └──────────┘             │
  │                                          │
  └──────────────────────────────────────────┘

  ┌── Mobile (375px) ─ 4 cols ──┐
  │                              │
  │  ┌────────────────────┐     │
  │  │      Card          │     │  1 por fila
  │  │      4c            │     │  (full width)
  │  └────────────────────┘     │
  │  ┌────────────────────┐     │
  │  │      Card          │     │
  │  └────────────────────┘     │
  │                              │
  └──────────────────────────────┘
```

```css
/* Card grid responsive */
.product-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: 1fr;               /* mobile: 1 col */
}

@media (min-width: 768px) {
  .product-grid {
    grid-template-columns: repeat(2, 1fr);  /* tablet: 2 cols */
    gap: 20px;
  }
}

@media (min-width: 1024px) {
  .product-grid {
    grid-template-columns: repeat(4, 1fr);  /* desktop: 4 cols */
    gap: 24px;
  }
}
```

### 5.5 Reflow del Contenido

Reflow = cómo el contenido se reorganiza al cambiar de breakpoint.

```
Patrones de reflow comunes:

  1. STACK (horizontal → vertical)
  ┌────┐ ┌────┐         ┌────────────┐
  │    │ │    │    →     │            │
  └────┘ └────┘         └────────────┘
                         ┌────────────┐
                         │            │
                         └────────────┘

  2. COLLAPSE (sidebar desaparece o se convierte en menú)
  ┌──┐ ┌──────┐         ┌────────────┐
  │  │ │      │    →     │ [☰] + body │
  │  │ │      │         └────────────┘
  └──┘ └──────┘

  3. SHRINK (elementos se achican manteniendo layout)
  ┌──────┐ ┌──────┐     ┌────┐ ┌────┐
  │      │ │      │ →   │    │ │    │
  └──────┘ └──────┘     └────┘ └────┘

  4. DROP (elementos caen a la siguiente fila)
  ┌──┐┌──┐┌──┐┌──┐      ┌───┐ ┌───┐
  └──┘└──┘└──┘└──┘  →   └───┘ └───┘
                         ┌───┐ ┌───┐
                         └───┘ └───┘
```

### 5.6 Priorización de Contenido

En pantallas más pequeñas, no todo cabe. Decide qué mostrar, qué esconder y qué reorganizar:

| Contenido | Desktop | Tablet | Mobile |
|---|---|---|---|
| Navegación principal | Horizontal | Horizontal | Hamburger menu |
| Sidebar | Visible | Colapsable | Oculta / bottom sheet |
| Tabla de datos | Completa | Scroll horizontal | Cards o lista simplificada |
| Imagen hero | Grande (50%) | Media (70%) | Full width |
| CTAs secundarios | Visibles | Visibles | Menú "más" |
| Footer completo | Multi-columna | 2 columnas | Stack / acordeón |

> **Error común:** Simplemente achicar todo para mobile. El diseño mobile no es una versión pequeña del desktop — es una **re-priorización** del contenido.

---

## 6. Grid Styles y Layout Patterns

### 6.1 Layouts Comunes

**Cards Grid:**

```
┌─────────────────────────────────────────────────┐
│                                                  │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│   │  Image  │  │  Image  │  │  Image  │       │
│   │         │  │         │  │         │       │
│   │ Title   │  │ Title   │  │ Title   │       │
│   │ Desc    │  │ Desc    │  │ Desc    │       │
│   │ [CTA]   │  │ [CTA]   │  │ [CTA]   │       │
│   └─────────┘  └─────────┘  └─────────┘       │
│                                                  │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│   │  Image  │  │  Image  │  │  Image  │       │
│   │ ...     │  │ ...     │  │ ...     │       │
│   └─────────┘  └─────────┘  └─────────┘       │
│                                                  │
└─────────────────────────────────────────────────┘

CSS:
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 24px;
```

**List Layout:**

```
┌─────────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────────┐ │
│ │ [Img]  Title              Meta    [Action]  │ │
│ │        Description                          │ │
│ └─────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────┐ │
│ │ [Img]  Title              Meta    [Action]  │ │
│ │        Description                          │ │
│ └─────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────┐ │
│ │ [Img]  Title              Meta    [Action]  │ │
│ │        Description                          │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

CSS:
  display: flex;
  flex-direction: column;
  gap: 12px;
```

**Dashboard Layout:**

```
┌──────────────────────────────────────────────────────┐
│  [☰] Dashboard                       [🔔] [👤]      │
├─────────┬────────────────────────────────────────────┤
│         │  KPI    KPI    KPI    KPI                  │
│  Nav    │  ┌───┐  ┌───┐  ┌───┐  ┌───┐              │
│         │  └───┘  └───┘  └───┘  └───┘              │
│  📊     │                                            │
│  👥     │  ┌──────────────────┐  ┌────────────┐     │
│  💰     │  │                  │  │            │     │
│  📋     │  │   Chart (8 col) │  │ Side (4col)│     │
│  ⚙️     │  │                  │  │            │     │
│         │  └──────────────────┘  └────────────┘     │
│         │                                            │
│         │  ┌──────────────────────────────────┐     │
│         │  │          Table (12 col)          │     │
│         │  └──────────────────────────────────┘     │
├─────────┴────────────────────────────────────────────┤

CSS:
  .dashboard {
    display: grid;
    grid-template-columns: 240px 1fr;  /* sidebar fija + contenido fluido */
  }
  .main-content {
    display: grid;
    grid-template-columns: repeat(12, 1fr);
    gap: 24px;
  }
```

**Split Screen:**

```
┌────────────────────┬────────────────────┐
│                    │                    │
│                    │                    │
│    Contenido A     │    Contenido B     │
│    (imagen/video)  │    (texto/form)    │
│                    │                    │
│                    │                    │
│       50%          │       50%          │
│                    │                    │
└────────────────────┴────────────────────┘

CSS:
  display: grid;
  grid-template-columns: 1fr 1fr;
  min-height: 100vh;
```

### 6.2 Grids por Tipo de Producto

**Landing Page:**

```
┌────────────────────────────────────────────┐
│              Hero (full width)             │  12/12
│           Heading + CTA centrado           │
└────────────────────────────────────────────┘
│       Features (3 cols iguales)            │  4+4+4
│  ┌────────┐ ┌────────┐ ┌────────┐        │
│  └────────┘ └────────┘ └────────┘        │
└────────────────────────────────────────────┘
│   Social proof (centrado, narrow)          │  3+6+3
│         ┌──────────────────┐               │
│         │   Testimonials   │               │
│         └──────────────────┘               │
└────────────────────────────────────────────┘
│          CTA final (full width)            │  12/12
└────────────────────────────────────────────┘
```

**E-commerce (Product Listing):**

```
┌──────────────────────────────────────────────┐
│  [Filtros]  │  Product Grid                  │
│  (3 cols)   │  (9 cols)                      │
│             │  ┌─────┐ ┌─────┐ ┌─────┐     │
│  Category   │  │     │ │     │ │     │     │  3 per row
│  Price      │  └─────┘ └─────┘ └─────┘     │
│  Rating     │  ┌─────┐ ┌─────┐ ┌─────┐     │
│  Brand      │  │     │ │     │ │     │     │
│             │  └─────┘ └─────┘ └─────┘     │
└──────────────────────────────────────────────┘

Mobile: Filtros → bottom sheet modal, products → 2 col grid o list
```

**SaaS App:**

```
┌──────────────────────────────────────────────┐
│  Topbar (full width)                         │
├─────────┬────────────────────────────────────┤
│         │  Content area (fluid grid)         │
│  Side   │                                    │
│  nav    │  Varía según la sección:           │
│  (fija) │  - Settings: form layout (6+6)     │
│         │  - Dashboard: KPIs + charts        │
│         │  - Tables: full width              │
│         │  - Detail: content + sidebar       │
└─────────┴────────────────────────────────────┘
```

### 6.3 CSS Grid vs Flexbox

| Aspecto | CSS Grid | Flexbox |
|---|---|---|
| **Dimensiones** | 2D (filas Y columnas) | 1D (fila O columna) |
| **Mejor para** | Layouts de página, grids | Componentes, alineación |
| **Control** | El container define la estructura | Los hijos definen su tamaño |
| **Ejemplo** | Layout de dashboard, card grid | Navbar, botón con icono, card interna |

```css
/* CSS Grid: layout de página (2D) */
.page {
  display: grid;
  grid-template-columns: 240px 1fr;
  grid-template-rows: 64px 1fr;
  grid-template-areas:
    "nav header"
    "nav main";
}

/* Flexbox: componente (1D) */
.button {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* Combinación (lo más común): */
.card-grid {
  display: grid;                              /* Grid para el layout */
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

.card {
  display: flex;                              /* Flex para el contenido */
  flex-direction: column;
  gap: 12px;
}
```

**Regla práctica:**

```
¿Necesitas controlar filas Y columnas? → CSS Grid
¿Necesitas alinear elementos en UNA dirección? → Flexbox
¿Duda? → Grid para layout, Flex para componentes
```

### 6.4 Composición Visual con Grids

```
Principios de composición:

  1. ASIMETRÍA INTENCIONAL (más interesante que 50/50)
  ┌──────────────┬────────┐
  │              │        │
  │   8 cols     │ 4 cols │  ← contenido principal + sidebar
  │              │        │
  └──────────────┴────────┘

  2. JERARQUÍA POR TAMAÑO DE COLUMNAS
  ┌────────────────────────┐
  │    Hero (12 cols)      │  ← máxima importancia
  ├────────┬───────────────┤
  │ 4 cols │  8 cols       │  ← contenido principal
  ├────┬───┴┬────┬─────────┤
  │ 3c │ 3c │ 3c │   3c    │  ← items iguales = igual importancia
  └────┴────┴────┴─────────┘

  3. WHITESPACE COMO ELEMENTO
  ┌────────────────────────────────────────┐
  │                                        │
  │         ┌──────────────────┐           │
  │         │   Content (6/12) │           │  Centrado con espacio
  │         │   respira en el  │           │  = elegancia y foco
  │         │   centro         │           │
  │         └──────────────────┘           │
  │                                        │
  └────────────────────────────────────────┘
```

---

## 7. Mobile vs Desktop Layout

### 7.1 Mobile-First Design

- **Intuición:** Diseñar primero para la pantalla más restrictiva te obliga a priorizar. Lo que funciona en mobile funciona en cualquier parte — lo contrario no es cierto.
- **Estructura formal:** Mobile-first es una estrategia de diseño donde se comienza por el viewport más pequeño, definiendo el contenido esencial, y luego se escala progresivamente hacia viewports más grandes añadiendo complejidad.

```
Proceso mobile-first:

  Paso 1: Mobile (esencial)
  ┌──────────┐
  │ Logo [☰] │     Solo lo fundamental
  │          │     1 columna
  │ Content  │     Prioridad al contenido
  │          │     Touch-friendly
  │ [CTA]    │
  └──────────┘

  Paso 2: Tablet (expandir)
  ┌──────────────────────┐
  │ Logo    Nav    [CTA] │   Nav visible
  │                      │   2 columnas
  │ ┌────┐  ┌────┐      │   Más contenido visible
  │ │    │  │    │      │
  │ └────┘  └────┘      │
  └──────────────────────┘

  Paso 3: Desktop (enriquecer)
  ┌──────────────────────────────────────┐
  │ Logo    Nav items       Search [CTA] │  Nav completa
  │                                      │  3-4 columnas
  │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│  Sidebar
  │ │      │ │      │ │      │ │      ││  Features extra
  │ └──────┘ └──────┘ └──────┘ └──────┘│
  └──────────────────────────────────────┘
```

### 7.2 Cambios Clave entre Mobile y Desktop

**Número de columnas:**

| Viewport | Columnas | Container | Margin | Gutter |
|---|---|---|---|---|
| Mobile (< 576px) | 4 | 100% | 16px | 16px |
| Tablet (768px) | 8 | 100% | 24px | 20px |
| Desktop (1024px) | 12 | 100% / max | 32px | 24px |
| Large (1440px+) | 12 | 1280px fixed | auto | 24px |

**Espaciado:**

```
Reducción de spacing para mobile:

  Desktop              Mobile
  ─────────────────────────────
  Section gap: 64px  → 40px
  Block gap:   32px  → 24px
  Card gap:    24px  → 16px
  Element gap: 16px  → 12px
  Inline gap:   8px  →  8px  (se mantiene)

  Regla: Reducir 25-40% en mobile, pero nunca
  menos del nivel mínimo de la escala (8px).
```

**Jerarquía:**

```
Desktop: Jerarquía horizontal y vertical
┌──────────────────────────────────────┐
│  H1 Title                  [Action] │  ← lectura horizontal
│  Subtitle                           │
│                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐       │  ← comparación lado a lado
│  │ Opt1 │ │ Opt2 │ │ Opt3 │       │
│  └──────┘ └──────┘ └──────┘       │
└──────────────────────────────────────┘

Mobile: Jerarquía puramente vertical
┌───────────────┐
│  H1 Title     │  ← lectura vertical (scroll)
│  Subtitle     │
│               │
│  [Action]     │  ← action se mueve abajo
│               │
│  ┌──────────┐ │
│  │  Opt 1   │ │  ← opciones apiladas
│  └──────────┘ │
│  ┌──────────┐ │
│  │  Opt 2   │ │
│  └──────────┘ │
│  ┌──────────┐ │
│  │  Opt 3   │ │
│  └──────────┘ │
└───────────────┘
```

**Navegación:**

| Componente | Desktop | Mobile |
|---|---|---|
| Nav principal | Horizontal en header | Hamburger menu / bottom nav |
| Breadcrumbs | Completos | Truncados o eliminados |
| Tabs | Horizontal scroll o todas visibles | Horizontal scroll |
| Sidebar | Persistente | Off-canvas / bottom sheet |
| Pagination | Números + anterior/siguiente | Infinite scroll o "Cargar más" |
| Actions | Botones inline | FAB (floating action button) / bottom bar |

### 7.3 Adaptación de Componentes

```
Tabla: Desktop → Mobile

  Desktop (tabla completa):
  ┌──────────┬────────┬──────────┬────────┬──────┐
  │ Name     │ Email  │ Role     │ Status │ Act  │
  ├──────────┼────────┼──────────┼────────┼──────┤
  │ John     │ j@...  │ Admin    │ Active │ [⋮]  │
  │ Jane     │ j@...  │ Editor   │ Paused │ [⋮]  │
  └──────────┴────────┴──────────┴────────┴──────┘

  Mobile opción A: Scroll horizontal
  ┌──────────┬────────┬──────
  │ Name     │ Email  │ Ro →   (scroll horizontal)
  ├──────────┼────────┼──────
  │ John     │ j@...  │ Ad →
  └──────────┴────────┴──────

  Mobile opción B: Cards (recomendada)
  ┌──────────────────────┐
  │ John Smith           │
  │ j@example.com        │
  │ Admin · Active       │
  │                 [⋮]  │
  └──────────────────────┘
  ┌──────────────────────┐
  │ Jane Doe             │
  │ j@example.com        │
  │ Editor · Paused      │
  │                 [⋮]  │
  └──────────────────────┘
```

### 7.4 Consideraciones de Interacción

| Factor | Desktop (mouse) | Mobile (touch) |
|---|---|---|
| **Target mínimo** | 24×24px (clickable) | **48×48px** (tappable) — Apple HIG |
| **Hover states** | Sí (cursor hover) | No (no existe hover nativo) |
| **Tooltips** | Hover-triggered | Tap-triggered o eliminados |
| **Drag & drop** | Natural | Posible pero con friction |
| **Right-click** | Context menu | Long press |
| **Scroll** | Vertical + horizontal | Vertical principal (horizontal es confuso) |
| **Text input** | Teclado completo | Teclado virtual (reduce viewport 50%) |
| **Multi-select** | Click + Shift/Ctrl | Tap + checkboxes explícitos |

```
Touch targets:

  ❌ Demasiado pequeño (32px):
  ┌────┐ ┌────┐ ┌────┐
  │ ✗  │ │ ✗  │ │ ✗  │    ← error frecuente de tap
  └────┘ └────┘ └────┘

  ✅ Correcto (48px con spacing):
  ┌────────┐    ┌────────┐    ┌────────┐
  │        │    │        │    │        │
  │   ✓    │    │   ✓    │    │   ✓    │
  │        │    │        │    │        │
  └────────┘    └────────┘    └────────┘
       48px  8px     48px  8px     48px
```

> **Regla crítica:** Si un elemento es tappable en mobile, su target area debe ser mínimo 48×48px, incluso si el elemento visual es más pequeño. Usa padding invisible.

---

## 8. Metodología de Diseño

### Paso 1: Definir Sistema de Spacing

Elige una escala base y documéntala:

```
Sistema de spacing (Design Tokens):

  --space-0:    0px
  --space-1:    4px      (xxs)
  --space-2:    8px      (xs)
  --space-3:    12px     (sm)
  --space-4:    16px     (base)
  --space-5:    20px     (md)
  --space-6:    24px     (lg)
  --space-8:    32px     (xl)
  --space-10:   40px     (2xl)
  --space-12:   48px     (3xl)
  --space-16:   64px     (4xl)
  --space-20:   80px     (5xl)
  --space-24:   96px     (6xl)

  Regla: Todo spacing en la interfaz DEBE usar
  estos valores. Cero excepciones.
```

**Aplicación semántica:**

```
Semantic spacing tokens (más mantenible):

  --spacing-inline-xs:     4px     /* entre icono y label */
  --spacing-inline-sm:     8px     /* entre elementos inline */
  --spacing-stack-xs:      4px     /* entre label y input */
  --spacing-stack-sm:      8px     /* entre items de lista */
  --spacing-stack-md:      16px    /* entre campos de form */
  --spacing-stack-lg:      24px    /* entre bloques */
  --spacing-section-sm:    32px    /* entre secciones pequeñas */
  --spacing-section-md:    48px    /* entre secciones medianas */
  --spacing-section-lg:    64px    /* entre secciones de página */
  --spacing-page:          96px    /* hero, top-level separación */
```

### Paso 2: Elegir Grid Base

```
Decisión de grid:

  ¿Qué estás diseñando?
  │
  ├── Web app / SaaS → 12 cols, sidebar fija + contenido fluido
  ├── Landing page   → 12 cols, container centrado (max 1280px)
  ├── E-commerce     → 12 cols, filtros + grid de productos
  ├── Dashboard      → 12 cols, dense, sidebar colapsable
  └── Blog/content   → 12 cols, narrow center (max 720px texto)

  Especificaciones del grid:
  ┌──────────────────────────────────────────┐
  │  Columnas: 12                            │
  │  Gutter:   24px (desktop), 16px (mobile) │
  │  Margin:   32px (desktop), 16px (mobile) │
  │  Container: max 1280px                   │
  │  Breakpoints: 576, 768, 1024, 1440       │
  └──────────────────────────────────────────┘
```

### Paso 3: Diseñar para Mobile

1. Definir contenido esencial (¿qué NO puede faltar?)
2. Diseñar en 375px width (iPhone standard)
3. Layout de 1 columna (4-col grid pero casi todo full-width)
4. Establecer jerarquía vertical
5. Definir navegación mobile (hamburger o bottom nav)
6. Validar touch targets (48px mínimo)

### Paso 4: Escalar a Desktop

1. Tomar el diseño mobile como base
2. Expandir a tablet (768px) — introducir 2 columnas donde tenga sentido
3. Expandir a desktop (1024px+) — agregar sidebar, multi-columna, features extra
4. Definir qué se AGREGA (no solo qué se estira)
5. Validar que el grid se mantiene consistente

### Paso 5: Validar Consistencia

**Checklist de validación:**

```
  ☐ Todo spacing usa valores de la escala definida
  ☐ Mismo spacing para mismos tipos de relación
    (ej: todos los label-to-input = 8px)
  ☐ Gutters consistentes en todo el grid
  ☐ Márgenes consistentes por breakpoint
  ☐ Vertical rhythm respetado (line-heights múltiplos de 4)
  ☐ Touch targets ≥ 48px en mobile
  ☐ No hay "números mágicos" (spacing arbitrario)
  ☐ El grid se respeta en TODAS las pantallas
  ☐ Los breakpoints producen reflows predecibles
  ☐ La jerarquía visual se mantiene en todos los viewports
```

### Paso 6: Integración con Design System

```
Estructura del sistema:

  Design Tokens (fuente de verdad)
       │
       ├── Spacing Scale       → --space-1 a --space-24
       ├── Grid Config         → columns, gutter, margin
       ├── Breakpoints         → sm, md, lg, xl
       └── Typography Scale    → size + line-height (en la grid)
           │
           ▼
  Components (usan tokens)
       │
       ├── Card         → padding: --space-6, gap: --space-3
       ├── Form         → gap: --space-4, label-gap: --space-2
       ├── Section      → padding: --space-16 0
       └── Page Layout  → grid 12-col, gutter: --space-6
           │
           ▼
  Pages (usan components + grid)
       │
       ├── Home         → Hero + Features + CTA (sections)
       ├── Dashboard    → Sidebar + Main (grid areas)
       └── Product      → Filters + Cards (grid)
```

> **Regla:** Si un diseñador y un developer no pueden señalar exactamente qué token usar para un spacing, el sistema no está bien definido.

---

## 9. Implementación Práctica

### 9.1 CSS Grid — Layout Completo

```css
/* ═══════════════════════════════════════════
   GRID SYSTEM COMPLETO — CSS Grid
   ═══════════════════════════════════════════ */

/* ── Spacing Scale (Custom Properties) ── */
:root {
  --space-1:  4px;
  --space-2:  8px;
  --space-3:  12px;
  --space-4:  16px;
  --space-5:  20px;
  --space-6:  24px;
  --space-8:  32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
  --space-20: 80px;
  --space-24: 96px;
}

/* ── Container ── */
.container {
  width: 100%;
  max-width: 1280px;
  margin-inline: auto;          /* centrado horizontal */
  padding-inline: var(--space-4); /* mobile margins */
}

@media (min-width: 768px) {
  .container {
    padding-inline: var(--space-6);
  }
}

@media (min-width: 1024px) {
  .container {
    padding-inline: var(--space-8);
  }
}

/* ── Grid Base ── */
.grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);   /* mobile: 4 cols */
  gap: var(--space-4);                      /* mobile: 16px gap */
}

@media (min-width: 768px) {
  .grid {
    grid-template-columns: repeat(8, 1fr); /* tablet: 8 cols */
    gap: var(--space-5);                   /* 20px gap */
  }
}

@media (min-width: 1024px) {
  .grid {
    grid-template-columns: repeat(12, 1fr); /* desktop: 12 cols */
    gap: var(--space-6);                    /* 24px gap */
  }
}

/* ── Column Spans ── */
.col-1  { grid-column: span 1; }
.col-2  { grid-column: span 2; }
.col-3  { grid-column: span 3; }
.col-4  { grid-column: span 4; }
.col-6  { grid-column: span 6; }
.col-8  { grid-column: span 8; }
.col-12 { grid-column: span 12; }

/* Full-width en mobile, span en desktop */
.col-full-mobile {
  grid-column: 1 / -1;           /* full width en mobile */
}

@media (min-width: 1024px) {
  .col-full-mobile {
    grid-column: span 6;          /* 6 cols en desktop */
  }
}

/* ── Page Layout con Grid Areas ── */
.page-layout {
  display: grid;
  grid-template-columns: 1fr;
  grid-template-areas:
    "header"
    "main"
    "footer";
  min-height: 100vh;
}

@media (min-width: 1024px) {
  .page-layout {
    grid-template-columns: 240px 1fr;
    grid-template-areas:
      "sidebar header"
      "sidebar main"
      "sidebar footer";
  }
}

.header  { grid-area: header; }
.sidebar { grid-area: sidebar; }
.main    { grid-area: main; }
.footer  { grid-area: footer; }
```

### 9.2 Flexbox — Componentes

```css
/* ═══════════════════════════════════════════
   COMPONENTES CON FLEXBOX
   ═══════════════════════════════════════════ */

/* ── Navbar ── */
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) var(--space-6);
  height: 64px;
}

.nav-links {
  display: flex;
  gap: var(--space-6);              /* 24px entre links */
}

/* ── Card ── */
.card {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);              /* 12px entre elementos internos */
  padding: var(--space-6);          /* 24px padding interno */
  border-radius: var(--space-2);    /* 8px border radius */
}

.card__header {
  display: flex;
  align-items: center;
  gap: var(--space-2);              /* 8px entre avatar y nombre */
}

.card__actions {
  display: flex;
  gap: var(--space-2);              /* 8px entre botones */
  margin-top: auto;                 /* push al fondo */
}

/* ── Button ── */
.button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);              /* 8px entre icono y texto */
  padding: var(--space-3) var(--space-4);  /* 12px 16px */
}

/* ── Form ── */
.form {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);              /* 20px entre campos */
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);              /* 4px entre label e input */
}

.form-actions {
  display: flex;
  gap: var(--space-3);              /* 12px entre botones */
  justify-content: flex-end;
}
```

### 9.3 Tailwind CSS — Spacing Scale

Tailwind usa base 4px out-of-the-box:

```
Tailwind spacing scale:

  Class    Value    Uso
  ──────────────────────────────────
  p-0      0px      Reset
  p-0.5    2px      Micro spacing
  p-1      4px      Inline icon gap
  p-2      8px      Tight spacing
  p-3      12px     Button padding (y)
  p-4      16px     Card padding (mobile)
  p-5      20px     Form field gap
  p-6      24px     Card padding (desktop)
  p-8      32px     Section gap
  p-10     40px     Large gap
  p-12     48px     Section padding
  p-16     64px     Page section
  p-20     80px     Large section
  p-24     96px     Hero spacing
```

```html
<!-- Tailwind: Card Grid Responsive -->
<div class="container mx-auto px-4 md:px-6 lg:px-8 max-w-screen-xl">

  <!-- Grid: 1 col mobile → 2 tablet → 3 desktop -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5 lg:gap-6">

    <!-- Card -->
    <div class="flex flex-col gap-3 p-4 md:p-6 rounded-lg bg-white shadow">
      <img class="rounded-md" src="..." alt="Product" />
      <h3 class="text-lg font-semibold">Product Name</h3>
      <p class="text-sm text-gray-600">Description text...</p>
      <div class="flex items-center justify-between mt-auto pt-3">
        <span class="text-lg font-bold">$99.00</span>
        <button class="inline-flex items-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-md">
          Add to Cart
        </button>
      </div>
    </div>

    <!-- Más cards... -->
  </div>
</div>

<!--
  Breakdown del spacing:
  - Container: px-4 (16px) → md:px-6 (24px) → lg:px-8 (32px)
  - Grid gap: gap-4 (16px) → md:gap-5 (20px) → lg:gap-6 (24px)
  - Card padding: p-4 (16px) → md:p-6 (24px)
  - Internal gap: gap-3 (12px)
  - Button: gap-2 (8px) icon-text, px-4 py-3 (16px × 12px)
  Todos en la escala de 4px ✓
-->
```

### 9.4 Bootstrap Grid System

```html
<!-- Bootstrap 5: Grid System -->

<!-- Container (responsive padding automático) -->
<div class="container">

  <!-- Row = flex container con gutters -->
  <div class="row g-4">

    <!--
      col-12: mobile (full width)
      col-md-6: tablet (50%)
      col-lg-4: desktop (33%)
    -->
    <div class="col-12 col-md-6 col-lg-4">
      <div class="card p-4">Card 1</div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
      <div class="card p-4">Card 2</div>
    </div>
    <div class="col-12 col-md-6 col-lg-4">
      <div class="card p-4">Card 3</div>
    </div>

  </div>
</div>

<!--
  Bootstrap breakpoints:
  sm: 576px
  md: 768px
  lg: 992px
  xl: 1200px
  xxl: 1400px

  Bootstrap grid:
  - 12 columnas
  - Gutter: 1.5rem (24px) default (configurable con g-0 a g-5)
  - Container max-widths por breakpoint
-->
```

```
Bootstrap vs Tailwind vs Custom CSS Grid:

  ┌──────────────┬─────────────────┬───────────────────┐
  │  Bootstrap   │   Tailwind      │   CSS Grid puro   │
  ├──────────────┼─────────────────┼───────────────────┤
  │ Opinionated  │ Utility-first   │ Sin framework     │
  │ 12 cols fijo │ Flexible        │ Totalmente libre  │
  │ Rápido start │ Rápido + custom │ Máximo control    │
  │ Pesado       │ Purged = liviano│ Cero dependencias │
  │ Legacy code  │ Standard actual │ Requiere setup    │
  └──────────────┴─────────────────┴───────────────────┘

  Recomendación 2026:
  - Nuevo proyecto → Tailwind o CSS Grid puro
  - Proyecto existente Bootstrap → Migrar gradualmente
  - Prototipo rápido → Tailwind (más rápido de iterar)
```

### 9.5 Design Tokens

Design tokens = la fuente de verdad que conecta diseño y desarrollo:

```css
/* ═══════════════════════════════════════════
   DESIGN TOKENS — Spacing & Grid
   ═══════════════════════════════════════════ */

:root {
  /* ── Primitive Tokens (escala base) ── */
  --space-unit: 4px;
  --space-1:  calc(var(--space-unit) * 1);   /*  4px */
  --space-2:  calc(var(--space-unit) * 2);   /*  8px */
  --space-3:  calc(var(--space-unit) * 3);   /* 12px */
  --space-4:  calc(var(--space-unit) * 4);   /* 16px */
  --space-6:  calc(var(--space-unit) * 6);   /* 24px */
  --space-8:  calc(var(--space-unit) * 8);   /* 32px */
  --space-12: calc(var(--space-unit) * 12);  /* 48px */
  --space-16: calc(var(--space-unit) * 16);  /* 64px */
  --space-24: calc(var(--space-unit) * 24);  /* 96px */

  /* ── Semantic Tokens (intención) ── */
  /* Inline (horizontal entre elementos) */
  --spacing-inline-xxs: var(--space-1);    /* icono ↔ texto */
  --spacing-inline-xs:  var(--space-2);    /* badges, tags */
  --spacing-inline-sm:  var(--space-3);    /* botones en grupo */
  --spacing-inline-md:  var(--space-4);    /* nav items */
  --spacing-inline-lg:  var(--space-6);    /* secciones inline */

  /* Stack (vertical entre elementos) */
  --spacing-stack-xxs: var(--space-1);     /* label ↔ input */
  --spacing-stack-xs:  var(--space-2);     /* list items */
  --spacing-stack-sm:  var(--space-3);     /* párrafos */
  --spacing-stack-md:  var(--space-4);     /* form fields */
  --spacing-stack-lg:  var(--space-6);     /* bloques */
  --spacing-stack-xl:  var(--space-8);     /* secciones */

  /* Inset (padding de contenedores) */
  --spacing-inset-xs:  var(--space-2);     /* badges */
  --spacing-inset-sm:  var(--space-3);     /* buttons */
  --spacing-inset-md:  var(--space-4);     /* inputs */
  --spacing-inset-lg:  var(--space-6);     /* cards */
  --spacing-inset-xl:  var(--space-8);     /* modals */

  /* Section (padding vertical de secciones de página) */
  --spacing-section-sm: var(--space-8);    /* 32px */
  --spacing-section-md: var(--space-12);   /* 48px */
  --spacing-section-lg: var(--space-16);   /* 64px */
  --spacing-section-xl: var(--space-24);   /* 96px */

  /* ── Grid Tokens ── */
  --grid-columns-mobile:  4;
  --grid-columns-tablet:  8;
  --grid-columns-desktop: 12;
  --grid-gutter-mobile:   var(--space-4);  /* 16px */
  --grid-gutter-tablet:   var(--space-5);  /* 20px */
  --grid-gutter-desktop:  var(--space-6);  /* 24px */
  --grid-margin-mobile:   var(--space-4);  /* 16px */
  --grid-margin-tablet:   var(--space-6);  /* 24px */
  --grid-margin-desktop:  var(--space-8);  /* 32px */
  --grid-max-width:       1280px;
}
```

**Uso de tokens en componentes:**

```css
/* Componentes usando semantic tokens */

.card {
  padding: var(--spacing-inset-lg);          /* 24px */
  display: flex;
  flex-direction: column;
  gap: var(--spacing-stack-sm);              /* 12px */
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-stack-xxs);             /* 4px */
}

.form {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-stack-md);              /* 16px */
}

.section {
  padding-block: var(--spacing-section-lg);  /* 64px top/bottom */
}

.button {
  padding: var(--spacing-inset-sm) var(--spacing-inset-md);  /* 12px 16px */
  display: inline-flex;
  align-items: center;
  gap: var(--spacing-inline-xxs);            /* 4px */
}
```

### 9.6 Ejemplo Completo: Landing Page

```css
/* ═══════════════════════════════════════════
   LANDING PAGE — Ejemplo completo
   ═══════════════════════════════════════════ */

/* Reset */
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

/* Container */
.container {
  width: 100%;
  max-width: var(--grid-max-width);
  margin-inline: auto;
  padding-inline: var(--grid-margin-mobile);
}

@media (min-width: 768px) {
  .container { padding-inline: var(--grid-margin-tablet); }
}

@media (min-width: 1024px) {
  .container { padding-inline: var(--grid-margin-desktop); }
}

/* Hero Section */
.hero {
  padding-block: var(--spacing-section-xl);   /* 96px */
  text-align: center;
}

.hero h1 {
  margin-bottom: var(--spacing-stack-md);     /* 16px */
}

.hero p {
  margin-bottom: var(--spacing-stack-lg);     /* 24px */
  max-width: 640px;
  margin-inline: auto;
}

/* Features Grid */
.features {
  padding-block: var(--spacing-section-lg);   /* 64px */
}

.features-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--grid-gutter-mobile);
}

@media (min-width: 768px) {
  .features-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: var(--grid-gutter-tablet);
  }
}

@media (min-width: 1024px) {
  .features-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: var(--grid-gutter-desktop);
  }
}

.feature-card {
  padding: var(--spacing-inset-lg);
  display: flex;
  flex-direction: column;
  gap: var(--spacing-stack-sm);
}

/* CTA Section */
.cta-section {
  padding-block: var(--spacing-section-xl);
  text-align: center;
}

.cta-section h2 {
  margin-bottom: var(--spacing-stack-md);
}

.cta-section .button {
  margin-top: var(--spacing-stack-lg);
}
```

```html
<!-- HTML Structure -->
<header class="navbar container">
  <a href="/" class="logo">Brand</a>
  <nav class="nav-links">
    <a href="#">Features</a>
    <a href="#">Pricing</a>
    <a href="#">About</a>
  </nav>
  <a href="#" class="button">Get Started</a>
</header>

<section class="hero">
  <div class="container">
    <h1>Build Better Products</h1>
    <p>Description that explains the value proposition clearly
       and concisely in two lines maximum.</p>
    <a href="#" class="button button--primary">Start Free Trial</a>
  </div>
</section>

<section class="features">
  <div class="container">
    <div class="features-grid">
      <div class="feature-card">
        <span class="feature-icon">⚡</span>
        <h3>Feature One</h3>
        <p>Brief description of this feature and its value.</p>
      </div>
      <div class="feature-card">
        <span class="feature-icon">🎯</span>
        <h3>Feature Two</h3>
        <p>Brief description of this feature and its value.</p>
      </div>
      <div class="feature-card">
        <span class="feature-icon">🔒</span>
        <h3>Feature Three</h3>
        <p>Brief description of this feature and its value.</p>
      </div>
    </div>
  </div>
</section>

<section class="cta-section">
  <div class="container">
    <h2>Ready to Get Started?</h2>
    <a href="#" class="button button--primary button--lg">
      Start Free Trial
    </a>
  </div>
</section>
```

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Al empezar | ¿Tengo una escala de spacing definida? | Definir base-4 scale + tokens semánticos |
| Al elegir grid | ¿Cuántas columnas necesito? | 12 default; 4 mobile, 8 tablet |
| Al definir container | ¿Fixed, fluid o hybrid? | Hybrid (max-width + fluid) |
| Al definir breakpoints | ¿Mobile-first o desktop-first? | Mobile-first (siempre) |
| Al diseñar layout | ¿CSS Grid o Flexbox? | Grid para layout, Flex para componentes |
| Al espaciar elementos | ¿Estos están relacionados? | Sí → espacio menor; No → espacio mayor |
| Al pasar a mobile | ¿Solo achico o re-priorizo? | Re-priorizar contenido, no solo achicar |
| Al hacer handoff | ¿Los developers saben qué tokens usar? | Documentar tokens + usar herramienta de inspección |

**Cheat Sheet de spacing por contexto:**

```
  Relación                    Spacing
  ────────────────────────────────────────
  Icono ↔ Texto               4-8px
  Label ↔ Input                4px
  Items en lista               8-12px
  Campos de formulario         16-20px
  Padding de card              16-24px
  Entre bloques                24-32px
  Entre secciones              48-64px
  Entre secciones de página    64-96px
```

> **Mantra del spacing y grids:** La consistencia es más importante que la perfección. Un sistema de spacing mediocre aplicado rigurosamente se ve mejor que decisiones brillantes aplicadas arbitrariamente. Define tu sistema, úsalo sin excepciones, y tu interfaz se sentirá profesional sin esfuerzo extra.
