# Wireframes — Módulo Completo

---

## 1. Introducción a Wireframes

### 1.1 Qué es un Wireframe y su Propósito

- **Intuición:** Un wireframe es el "esqueleto" de una pantalla. Así como un arquitecto dibuja planos antes de construir, un diseñador traza wireframes antes de diseñar visualmente.
- **Estructura formal:** Es una representación visual de baja/media fidelidad que define la **estructura, jerarquía y disposición del contenido** de una interfaz, sin incluir estilo visual (color, tipografía final, imágenes reales).
- **Aplicación práctica:** Sirve para validar ideas rápidamente, alinear al equipo y detectar problemas de estructura **antes** de invertir tiempo en diseño visual o desarrollo.

**Propósitos clave:**

1. Presentar la información que se mostrará en cada pantalla
2. Definir la estructura y layout de la página
3. Comunicar la dirección general de la interfaz
4. Servir como lenguaje común entre diseñadores, developers, PMs y stakeholders

### 1.2 Wireframe vs Mockup vs Prototipo

| Aspecto | Wireframe | Mockup | Prototipo |
|---|---|---|---|
| **Fidelidad** | Baja/Media | Alta | Alta |
| **Interactividad** | Ninguna o mínima | Ninguna | Navegable/funcional |
| **Propósito** | Estructura y layout | Apariencia visual final | Simular experiencia real |
| **Velocidad** | Muy rápido | Medio | Lento |
| **Costo de cambio** | Muy bajo | Medio-alto | Alto |
| **Cuándo usarlo** | Exploración temprana | Aprobación visual | Testing con usuarios |

```
Proceso lineal simplificado:

  Sketches → Wireframes → Mockups → Prototipos → Desarrollo
     ↑______________________________________________|
              (ciclo iterativo constante)
```

> **Error común:** Saltar directamente a mockups o prototipos sin validar la estructura. Esto genera retrabajo costoso cuando la arquitectura de la pantalla no funciona.

### 1.3 Niveles de Fidelidad

#### Low-Fidelity

- Papel y lápiz o pizarrón
- Bloques, líneas y texto placeholder
- Ideal para brainstorming y exploración rápida
- Tiempo: minutos

```
┌─────────────────────────────┐
│  [  Logo  ]    [ Nav  Nav ] │
├─────────────────────────────┤
│                             │
│   ┌─────┐  Título grande   │
│   │  X  │  ───────────     │
│   │ img │  ───────────     │
│   └─────┘  [ Botón CTA ]  │
│                             │
├─────────────────────────────┤
│  footer info                │
└─────────────────────────────┘
```

#### Mid-Fidelity

- Herramientas digitales (Figma, Balsamiq)
- Espaciado más preciso, tipografía genérica, escala de grises
- Se definen interacciones básicas
- Ideal para **validación con equipo y primeros tests**
- Tiempo: horas

#### High-Fidelity

- Casi idéntico al diseño final pero sin color/branding completo
- Tipografía real, espaciado exacto, contenido real o cercano
- Ideal para handoff a desarrollo o testing detallado
- Tiempo: días

**Cuándo usar cada nivel:**

| Situación | Fidelidad recomendada |
|---|---|
| Kick-off / exploración de ideas | Low |
| Validación de estructura con equipo | Low → Mid |
| Testing con usuarios (navegación) | Mid |
| Demo a stakeholders / clientes | Mid → High |
| Handoff a desarrollo | High |
| Pitch o presentación ejecutiva | High |

> **Anti-patrón:** Usar high-fidelity en etapas tempranas. El costo de cambio es alto y genera apego emocional al diseño.

---

## 2. Rol de los Wireframes en UX/UI

### 2.1 Estructura antes de Estética

Los wireframes fuerzan a tomar decisiones **estructurales** sin distracciones visuales:

- ¿Qué contenido va en esta pantalla?
- ¿Cuál es la jerarquía de importancia?
- ¿Qué acción principal debe tomar el usuario?
- ¿Cómo navega hacia/desde esta pantalla?

> **Principio:** La estructura define la experiencia. La estética la refina.

### 2.2 Relación con otros Artefactos UX

```
                    ┌──────────────┐
                    │   Research   │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌───────────┐
        │ Personas │ │ User     │ │ Story     │
        │          │ │ Stories  │ │ Mapping   │
        └────┬─────┘ └────┬─────┘ └─────┬─────┘
             │             │             │
             ▼             ▼             ▼
        ┌──────────────────────────────────────┐
        │            Sitemap                   │
        └──────────────────┬───────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │          User Flows                  │
        └──────────────────┬───────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │     ★ WIREFRAMES ★                   │
        │  (estructura + layout + jerarquía)   │
        └──────────────────┬───────────────────┘
                           │
                           ▼
                  Mockups → Prototipos → Dev
```

**Sitemap → Wireframes:**

- El sitemap define **qué páginas** existen
- El wireframe define **qué contiene** cada página y cómo se organiza

**User Flows → Wireframes:**

- Los user flows definen la **secuencia de pasos** del usuario
- Los wireframes materializan **cada paso** como pantalla concreta

**Arquitectura de Información → Wireframes:**

- La AI define la **organización lógica** del contenido
- El wireframe la traduce a **disposición espacial** en pantalla

### 2.3 Reducción de Incertidumbre

Los wireframes implementan el ciclo **Build → Measure → Learn** (Lean Startup):

1. **Build:** Crear wireframe rápido
2. **Measure:** Probar con usuarios/equipo (¿funciona la interacción? ¿se entiende?)
3. **Learn:** Identificar fallos y oportunidades
4. **Repetir**

**Beneficios concretos:**

- Fallar rápido y barato (minutos/horas vs días/semanas)
- Alinear expectativas antes del desarrollo
- Descubrir flujos rotos o contenido faltante tempranamente
- Dar claridad al equipo técnico sobre qué construir

> **Error común:** No iterar. Crear un wireframe, aprobarlo y pasar directamente a UI sin validar con usuarios reales.

---

## 3. Componentes Clave de un Wireframe

### 3.1 Layout (Estructura Base)

El layout es la distribución espacial de los bloques de contenido en la pantalla.

```
Patrones de layout comunes:

1) Single Column         2) Two Column           3) Grid
┌───────────────┐        ┌────────┬──────┐       ┌────┬────┬────┐
│    Header     │        │ Header │      │       │  Header       │
├───────────────┤        ├────────┤ Side │       ├────┬────┬────┤
│               │        │        │ bar  │       │    │    │    │
│   Content     │        │ Main   │      │       │ C1 │ C2 │ C3 │
│               │        │        │      │       │    │    │    │
├───────────────┤        ├────────┴──────┤       ├────┴────┴────┤
│    Footer     │        │    Footer     │       │    Footer     │
└───────────────┘        └───────────────┘       └──────────────┘

Mejor para:             Mejor para:              Mejor para:
- Mobile               - Blogs, docs            - E-commerce
- Landing pages        - Dashboards             - Portfolios
- Formularios          - Email clients          - Galerías
```

### 3.2 Jerarquía Visual

Define qué ve el usuario **primero, segundo y tercero** sin usar color.

**Herramientas en wireframes para establecer jerarquía:**

- **Tamaño:** Elementos más grandes = más importantes
- **Posición:** Arriba y a la izquierda = más prominente (en culturas LTR)
- **Peso visual:** Bloques más gruesos o con borde atraen la vista
- **Espacio en blanco:** Aislar un elemento le da protagonismo

```
Ejemplo: Landing page con jerarquía clara

┌─────────────────────────────────────┐
│  Logo          Nav1  Nav2  [Login]  │  ← Nivel 3: Navegación
├─────────────────────────────────────┤
│                                     │
│      TÍTULO PRINCIPAL GRANDE        │  ← Nivel 1: Mensaje clave
│      Subtítulo descriptivo          │
│                                     │
│         [ CTA Principal ]           │  ← Nivel 1: Acción deseada
│                                     │
├──────────┬──────────┬───────────────┤
│  ┌────┐  │  ┌────┐  │  ┌────┐      │
│  │icon│  │  │icon│  │  │icon│      │  ← Nivel 2: Propuesta de valor
│  └────┘  │  └────┘  │  └────┘      │
│ Feature 1│ Feature 2│ Feature 3    │
│  ─────── │  ─────── │  ───────     │
└──────────┴──────────┴───────────────┘
```

> **Anti-patrón:** Todo al mismo tamaño y peso. Si todo es importante, nada lo es.

### 3.3 Navegación

| Patrón | Uso ideal | Representación en wireframe |
|---|---|---|
| **Navbar horizontal** | Sitios con 3-7 secciones principales | `[Logo] [Nav1] [Nav2] [Nav3] [CTA]` |
| **Hamburger menu** | Mobile o apps con muchas secciones | `[Logo] [☰]` |
| **Sidebar** | Dashboards, admin panels, SaaS | Columna fija a la izquierda |
| **Tabs** | Contenido relacionado en una misma vista | `[Tab1] [Tab2*] [Tab3]` |
| **Breadcrumbs** | Sitios con jerarquía profunda | `Home > Categoría > Producto` |
| **Bottom nav** | Apps mobile (3-5 items) | `[🏠] [🔍] [➕] [❤️] [👤]` |

### 3.4 Contenido (Placeholders)

En wireframes **no se usa contenido real** (excepto en high-fidelity). Se usan placeholders:

- **Texto:** Líneas horizontales `───────` o "Lorem ipsum"
- **Imágenes:** Rectángulo con X diagonal `[  X  ]`
- **Video:** Rectángulo con triángulo `[  ▶  ]`
- **Iconos:** Círculo pequeño o cuadrado `[●]` `[■]`
- **Avatares:** Círculo `(👤)`

### 3.5 Calls to Action (CTA)

Son los elementos que guían al usuario a completar la acción deseada.

**Reglas para CTAs en wireframes:**

1. **Un CTA primario por pantalla** — La acción más importante
2. **CTAs secundarios claramente diferenciados** — Menor peso visual
3. **Posición predecible** — Donde el usuario espera encontrarlos
4. **Copy de acción** — Verbos: "Comprar", "Registrarse", "Ver más" (no "Click aquí")

```
CTA Primario:    [ ██████████████ ]    (bloque sólido, prominente)
CTA Secundario:  [ ─────────────── ]   (outline, menos peso)
Link:             Texto subrayado       (mínimo peso)
```

### 3.6 Elementos Interactivos Básicos

```
Formularios:
┌──────────────────────┐
│ Label                │
│ ┌──────────────────┐ │
│ │ Input text       │ │
│ └──────────────────┘ │
│                      │
│ Label                │
│ ┌──────────────────┐ │
│ │ ▼ Dropdown       │ │
│ └──────────────────┘ │
│                      │
│ [○] Opción A         │
│ [●] Opción B         │
│                      │
│ [✓] Acepto términos  │
│                      │
│ [ ████ Enviar ████ ] │
└──────────────────────┘

Otros elementos:
- Toggle:      [===○  ] OFF    [  ○===] ON
- Slider:      [──●────────]
- Search:      [🔍 Buscar...        ]
- Pagination:  [<] [1] [2*] [3] [>]
- Modal:       Caja superpuesta con overlay
```

---

## 4. Tipos de Wireframes

### 4.1 Wireframes de Páginas Estáticas

Para pantallas individuales con contenido fijo (landing, about, pricing).

```
Ejemplo: Pricing Page

┌─────────────────────────────────────────┐
│  Logo                       Nav  [CTA]  │
├─────────────────────────────────────────┤
│          Elige tu plan                  │
│     [Mensual] [Anual - 20% off]        │
├─────────────┬─────────────┬─────────────┤
│   BÁSICO    │    PRO      │  ENTERPRISE │
│   $9/mes    │   $29/mes   │   $99/mes   │
│  ─────────  │  ─────────  │  ─────────  │
│  ✓ Feature  │  ✓ Feature  │  ✓ Feature  │
│  ✓ Feature  │  ✓ Feature  │  ✓ Feature  │
│  ✗ Feature  │  ✓ Feature  │  ✓ Feature  │
│  ✗ Feature  │  ✗ Feature  │  ✓ Feature  │
│ [Elegir]    │ [██Elegir██]│  [Elegir]   │
└─────────────┴─────────────┴─────────────┘
```

### 4.2 Wireframes de Flujos (Multi-step)

Documentan secuencias completas de interacción.

```
Flujo: Checkout en e-commerce

  ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
  │ Carrito │ ──→ │ Datos   │ ──→ │  Pago   │ ──→ │ Confir- │
  │         │     │ envío   │     │         │     │ mación  │
  └─────────┘     └─────────┘     └─────────┘     └─────────┘
       │               │               │               │
       ▼               ▼               ▼               ▼
  ┌─────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
  │Lista    │   │ Nombre    │   │ Tarjeta   │   │ ✓ Pedido  │
  │productos│   │ Dirección │   │ Fecha exp │   │  #12345   │
  │ Qty  $  │   │ Ciudad    │   │ CVV       │   │           │
  │─────────│   │ CP        │   │           │   │ Resumen   │
  │Subtotal │   │           │   │ Total: $X │   │ ────────  │
  │Envío    │   │[Continuar]│   │ [Pagar]   │   │ [Inicio]  │
  │[Checkout│   └───────────┘   └───────────┘   └───────────┘
  └─────────┘

  Barra de progreso: [1 ●──────2 ○──────3 ○──────4 ○]
```

> **Decisión clave:** En flujos multi-step, siempre incluir indicador de progreso y opción de retroceso.

### 4.3 Wireframes Responsive

Diseñar la misma pantalla para múltiples breakpoints.

```
Desktop (1200px+)           Tablet (768px)        Mobile (375px)
┌──────────────────────┐   ┌───────────────┐     ┌─────────┐
│ Logo    Nav Nav [CTA]│   │ Logo  Nav [☰] │     │Logo [☰] │
├────────┬─────────────┤   ├───────────────┤     ├─────────┤
│        │             │   │               │     │         │
│  Img   │  Título     │   │    Título     │     │  Título │
│        │  ────────   │   │    ────────   │     │ ─────── │
│        │  ────────   │   │    ┌─────┐   │     │ ┌─────┐ │
│        │  [CTA]      │   │    │ Img │   │     │ │ Img │ │
│        │             │   │    └─────┘   │     │ └─────┘ │
├────────┴─────────────┤   │    [CTA]     │     │  [CTA]  │
│ Card  Card  Card     │   ├──────┬────────┤     ├─────────┤
│                      │   │ Card │ Card   │     │  Card   │
└──────────────────────┘   └──────┴────────┘     │  Card   │
                                                  │  Card   │
                                                  └─────────┘
```

**Reglas para responsive wireframing:**

1. **Mobile-first:** Diseñar primero para la pantalla más pequeña
2. **Priorizar contenido:** ¿Qué se elimina/colapsa en mobile?
3. **Navegación adaptable:** Navbar → Hamburger
4. **Layouts fluidos:** Columnas se apilan verticalmente
5. **Touch targets:** Mínimo 44x44px en mobile

### 4.4 Wireframes para Productos Complejos

Dashboards, SaaS, herramientas internas.

```
Dashboard - Analytics

┌──────────────────────────────────────────────────┐
│  [☰] App Name         🔔  (👤) Admin ▼          │
├──────────┬───────────────────────────────────────┤
│          │  Dashboard     [Filtro ▼] [Exportar]  │
│ 📊 Dash  │───────────────────────────────────────│
│ 👥 Users │  ┌────────┐┌────────┐┌────────┐      │
│ 📈 Stats │  │ KPI 1  ││ KPI 2  ││ KPI 3  │      │
│ ⚙️ Config│  │ $12.5k ││ 1,234  ││ 87%    │      │
│ 📋 Logs  │  │ +12% ↑ ││ -3% ↓  ││ +5% ↑  │      │
│          │  └────────┘└────────┘└────────┘      │
│          │                                       │
│          │  ┌─────────────────────────────────┐  │
│          │  │                                 │  │
│          │  │   [Gráfico de línea/barras]     │  │
│          │  │                                 │  │
│          │  └─────────────────────────────────┘  │
│          │                                       │
│          │  ┌────────────────┐ ┌──────────────┐  │
│          │  │ Tabla reciente │ │ Actividad    │  │
│          │  │ ────────────── │ │ ──────────── │  │
│          │  │ Row 1          │ │ Item 1       │  │
│          │  │ Row 2          │ │ Item 2       │  │
│          │  └────────────────┘ └──────────────┘  │
└──────────┴───────────────────────────────────────┘
```

**Consideraciones para productos complejos:**

- **Sidebar persistente** para navegación principal
- **KPIs visibles** al primer vistazo (above the fold)
- **Filtros y acciones contextuales** cercanos al contenido
- **Densidad de información controlada** — agrupar por relevancia
- **Estados:** vacío, cargando, error, con datos (wireframear todos)

> **Error común:** Solo wireframear el "happy path". Los estados vacíos, errores y edge cases son igual de importantes.

---

## 5. Metodología Paso a Paso

### Paso 1: Definir Objetivos de la Pantalla

Antes de dibujar, responder:

- **¿Qué debe lograr el usuario en esta pantalla?** (objetivo del usuario)
- **¿Qué debe lograr el negocio con esta pantalla?** (objetivo de negocio)
- **¿Cuál es la acción principal?** (un solo CTA primario)

```
Ejemplo — Pantalla de producto e-commerce:

  Objetivo usuario: Evaluar si quiere comprar el producto
  Objetivo negocio: Convertir visita en compra
  Acción principal: "Agregar al carrito"
  Acciones secundarias: Ver reviews, comparar, guardar
```

### Paso 2: Identificar Necesidades del Usuario

Consultar artefactos previos:

- **User Stories:** "Como usuario, quiero ver el precio claramente para decidir si compro"
- **User Flows:** ¿De dónde viene el usuario? ¿A dónde va después?
- **Personas:** ¿Qué nivel técnico tiene? ¿Qué le importa más?

### Paso 3: Priorización de Contenido

Listar **todo** lo que podría ir en la pantalla y priorizar:

| Prioridad | Contenido | Justificación |
|---|---|---|
| P1 - Esencial | Nombre, precio, CTA compra, imagen | Sin esto no hay conversión |
| P2 - Importante | Descripción, reviews, variantes | Ayuda a la decisión |
| P3 - Complementario | Productos relacionados, breadcrumbs | Mejora la experiencia |
| P4 - Opcional | Redes sociales, share | Bajo impacto |

> **Regla:** P1 siempre above the fold. P4 puede eliminarse si hay restricciones.

### Paso 4: Bocetado Rápido (Sketching)

- Papel y lápiz: 3-5 variaciones en 10-15 minutos
- No borrar, hacer múltiples versiones
- Anotar decisiones y dudas directamente en el sketch
- **Crazy 8s:** 8 ideas en 8 minutos (1 por minuto) para forzar creatividad

### Paso 5: Digitalización

1. Elegir la mejor variación del sketch
2. Traducir a herramienta digital (Figma, Balsamiq)
3. Usar grilla para alineación
4. Definir espaciado consistente (8px grid system)
5. Agregar anotaciones para el equipo

### Paso 6: Iteración y Validación

```
Ciclo de iteración:

  Wireframe v1 → Review interno → Ajustes
       ↓
  Wireframe v2 → Test con usuarios → Hallazgos
       ↓
  Wireframe v3 → Demo a stakeholders → Feedback
       ↓
  Wireframe final → Handoff a UI/Dev
```

> **Tackle the riskiest features first.** Priorizar wireframes de pantallas con mayor impacto en el éxito del producto (search, onboarding, checkout) sobre pantallas de bajo riesgo (perfil, configuración).

---

## 6. Buenas Prácticas de Diseño

### 6.1 Claridad sobre Estética

- Colores: solo escala de grises (blanco, gris claro, gris oscuro, negro)
- Tipografía: máximo 2 fuentes genéricas; usar tamaño y peso para jerarquía
- Sin imágenes reales: solo placeholders
- Sin sombras, gradientes o efectos

> **Si un wireframe necesita color para entenderse, tiene un problema de jerarquía.**

### 6.2 Uso de Grillas (Grid Systems)

```
12-Column Grid (estándar):

│ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │
├───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┤

Ejemplo de distribución:
│◄──── 8 cols (contenido) ────►│◄── 4 cols (sidebar) ──►│
│◄── 4 cols ──►│◄── 4 cols ──►│◄── 4 cols ──►│  (3 cards)
│◄──────────── 12 cols (full width) ─────────────────────►│

Spacing: múltiplos de 8px (8, 16, 24, 32, 48, 64)
```

### 6.3 Consistencia entre Pantallas

- Misma posición para header, nav y footer en **todas** las pantallas
- Mismo patrón de layout para páginas del mismo tipo
- CTAs primarios siempre con el mismo estilo de bloque
- Mismo espaciado y márgenes

### 6.4 Diseño Basado en Patrones

Usar patrones conocidos reduce la curva de aprendizaje del usuario:

| Patrón | Cuándo usarlo |
|---|---|
| **F-pattern** | Páginas con mucho texto (blogs, noticias) |
| **Z-pattern** | Landing pages con pocos elementos |
| **Card pattern** | Listados de contenido homogéneo |
| **Master-detail** | Listas con vista de detalle (email, dashboards) |
| **Wizard/Steps** | Procesos secuenciales (checkout, onboarding) |

### 6.5 Minimizar Carga Cognitiva

- **Ley de Hick:** Menos opciones = decisión más rápida → limitar navegación a 5-7 items
- **Ley de Miller:** Agrupar información en chunks de 3-5 elementos
- **Proximidad (Gestalt):** Elementos relacionados deben estar cerca
- **Espacio en blanco:** No es espacio vacío, es espacio que da respiro

### 6.6 Enfoque en Tareas Clave

Cada pantalla debe tener **una tarea principal**. Si una pantalla intenta hacer demasiado, dividirla.

> **Anti-patrón — "The Kitchen Sink":** Meter todo en una sola pantalla. Si necesitas scroll infinito para ver el CTA, la pantalla necesita simplificarse.

---

## 7. Herramientas y Flujo de Trabajo

### 7.1 Herramientas por Contexto

| Herramienta | Mejor para | Fidelidad | Curva de aprendizaje |
|---|---|---|---|
| **Papel + lápiz** | Brainstorming, sketching | Low | Ninguna |
| **Balsamiq** | Wireframes rápidos, look "hand-drawn" | Low-Mid | Baja |
| **Whimsical** | Wireframes + flowcharts integrados | Low-Mid | Baja |
| **Figma** | Todo el flujo de diseño, colaboración | Mid-High | Media |
| **Sketch** | Diseño UI (macOS only) | Mid-High | Media |
| **Axure** | Wireframes complejos + interacciones | Mid-High | Alta |

> **Recomendación:** Figma es el estándar actual. Permite wireframing, mockups, prototipos y colaboración en tiempo real en una sola herramienta.

### 7.2 Componentes Reutilizables

Crear una **librería de wireframe** con componentes base:

```
Componentes esenciales:

  □ Navbar (desktop + mobile)
  □ Footer
  □ Cards (horizontal, vertical)
  □ Formularios (inputs, dropdowns, checkboxes, radio)
  □ Botones (primario, secundario, link)
  □ Modales
  □ Tablas
  □ Paginación
  □ Breadcrumbs
  □ Alertas / Notificaciones
  □ Empty states
  □ Loading states
```

**Ventajas:**

- Consistencia automática entre pantallas
- Velocidad: arrastrar y soltar vs dibujar desde cero
- Cambio global: editar componente → se actualiza en todos los wireframes

### 7.3 Librerías UI Básicas para Wireframing

- **Figma:** Wireframe Kit (community), Ant Design Wireframe
- **Balsamiq:** Librería integrada
- **Whimsical:** Templates de wireframe

### 7.4 Versionado y Colaboración

- **Nombrado:** `NombreProyecto_Pantalla_v01`, `v02`, etc.
- **Páginas en Figma:** Una página por flujo o sección
- **Comentarios:** Usar comentarios en Figma para feedback contextual
- **Branches (Figma):** Para explorar alternativas sin romper el archivo principal
- **Presentaciones:** Usar modo presentación para demos a stakeholders

---

## 8. Validación y Testing

### 8.1 Pruebas Rápidas con Usuarios

**Tipos de test con wireframes:**

| Test | Qué valida | Cómo hacerlo |
|---|---|---|
| **5-second test** | Primera impresión, jerarquía | Mostrar wireframe 5 seg → preguntar qué recuerdan |
| **Think-aloud** | Comprensión del flujo | Usuario narra mientras navega wireframes |
| **Task completion** | Eficacia de la estructura | "Encuentra X", "Completa Y" |
| **A/B de wireframes** | Comparar alternativas | Mostrar variante A y B → medir preferencia/eficacia |
| **Card sorting** | Organización de contenido | Validar si la agrupación tiene sentido para el usuario |

**Mínimo viable de testing:**

- 5 usuarios son suficientes para encontrar ~85% de problemas de usabilidad
- No necesitas lab: videollamada + screen share funciona
- Wireframes impresos + un café es suficiente para early testing

### 8.2 Feedback Iterativo

```
Fuentes de feedback:

  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
  │   Usuarios   │   │    Equipo    │   │ Stakeholders │
  │              │   │              │   │              │
  │ Validación   │   │ Feasibility  │   │ Alineación   │
  │ de usabilidad│   │ técnica y    │   │ con business │
  │              │   │ consistencia │   │ goals        │
  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
         │                  │                   │
         └──────────────────┼───────────────────┘
                            ▼
                    Wireframe mejorado
```

**Cómo documentar feedback:**

- **Qué se observó** (hecho, no interpretación)
- **Dónde ocurrió** (pantalla/elemento específico)
- **Severidad** (crítico / mayor / menor)
- **Acción propuesta** (cambio concreto)

### 8.3 Identificación de Fricción en la Navegación

**Señales de fricción:**

- Usuario no encuentra el CTA
- Usuario no sabe cómo regresar
- Usuario no entiende dónde está (falta breadcrumbs/indicadores)
- Usuario necesita más de 3 clicks para completar tarea clave
- Usuario confunde elementos interactivos con decorativos

**Checklist de validación de navegación:**

- [ ] ¿El usuario sabe en qué página está?
- [ ] ¿Puede regresar fácilmente a la pantalla anterior?
- [ ] ¿Encuentra el CTA principal en < 3 segundos?
- [ ] ¿El flujo requiere el mínimo de pasos necesarios?
- [ ] ¿Los labels de navegación son claros y sin ambigüedad?

### 8.4 Ajustes antes de Pasar a UI Visual

**Criterios de "Done" para wireframes:**

1. ✅ Todos los flujos principales están wireframeados
2. ✅ Estados edge case documentados (vacío, error, loading)
3. ✅ Al menos una ronda de feedback con usuarios
4. ✅ Aprobación del equipo técnico (feasibility)
5. ✅ Alineación con stakeholders en estructura y contenido
6. ✅ Responsive contemplado (al menos mobile y desktop)
7. ✅ Anotaciones claras para el handoff

> **Decisión incorrecta frecuente:** Pasar a UI visual cuando "se ve bonito" en lugar de cuando está **validado estructuralmente**. Un wireframe bonito que nadie ha testeado es solo decoración.

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Antes de wireframear | ¿Tengo sitemap, user flows y requirements? | Si no → obtenerlos primero |
| Al iniciar | ¿Cuáles son las pantallas de mayor riesgo? | Priorizar esas |
| Durante el diseño | ¿El usuario entiende qué hacer? | Si no → simplificar jerarquía |
| Al iterar | ¿He validado con al menos 5 usuarios? | Si no → testear antes de avanzar |
| Antes del handoff | ¿Están documentados todos los estados? | Si no → completar edge cases |

> **Mantra del wireframing:** Estructura primero, estética después. Valida temprano, itera siempre. Mantén al usuario en el centro de cada decisión.