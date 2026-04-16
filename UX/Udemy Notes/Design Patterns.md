# Design Patterns en UX/UI — Módulo Completo

> **Módulo:** Patrones de Diseño en Experiencia de Usuario
> **Nivel:** Básico → Intermedio → Avanzado
> **Objetivo:** Reconocer, aplicar y adaptar soluciones reutilizables a problemas recurrentes de interacción y experiencia, priorizando decisiones de diseño sobre memorización de patrones.

---

## Tabla de Contenidos

1. [Introducción a Design Patterns en UX/UI](#1-introducción-a-design-patterns-en-uxui)
2. [Fundamentos de Design Patterns](#2-fundamentos-de-design-patterns)
3. [Categorías principales de patrones](#3-categorías-principales-de-patrones)
4. [Patrones de comportamiento del usuario](#4-patrones-de-comportamiento-del-usuario)
5. [Patrones en flujos complejos](#5-patrones-en-flujos-complejos)
6. [Evaluación de patrones](#6-evaluación-de-patrones)
7. [Design Patterns en Design Systems](#7-design-patterns-en-design-systems)
8. [Mobile vs Desktop Patterns](#8-mobile-vs-desktop-patterns)
9. [Nivel intermedio / avanzado](#9-nivel-intermedio--avanzado)
10. [Casos prácticos](#10-casos-prácticos)

---

## 1. Introducción a Design Patterns en UX/UI

### 1.1 ¿Qué es un design pattern?

**Intuición**
Un design pattern es una solución probada a un problema recurrente de diseño. No es un componente ni un template: es una **estrategia de interacción** que se ha demostrado efectiva en múltiples contextos. Así como en arquitectura un "arco" resuelve el problema de sostener peso sobre un espacio abierto, en UX un "breadcrumb" resuelve el problema de saber dónde estás dentro de una jerarquía.

**Estructura formal**
Un design pattern documenta:
- **El problema** que resuelve (no el componente que usa)
- **El contexto** donde aplica (y donde no)
- **La solución** como estrategia de interacción
- **Los trade-offs** de elegirlo

```
PATRÓN ≠ COMPONENTE

COMPONENTE:                        PATRÓN:
"Un dropdown"                      "Permitir al usuario seleccionar
                                    una opción de una lista grande
Qué es: Un menú desplegable         sin abrumarlo"
Cómo se ve: Lista que se abre
Cómo funciona: Click → opciones    Qué resuelve: Selección de opciones
                                   Cuándo: > 5 opciones, espacio limitado
                                   Solución: Dropdown, autocomplete,
                                             radio group, chips...
                                   Depende del contexto
```

### 1.2 Diferencia entre UI components, design patterns y heurísticas

| Concepto | Qué es | Nivel | Ejemplo |
|---|---|---|---|
| **UI Component** | Pieza atómica de interfaz | Implementación | Button, Input, Card, Modal |
| **Design Pattern** | Solución reutilizable a un problema de interacción | Estrategia | Progressive disclosure, Infinite scroll, Multi-step form |
| **Heurística** | Principio general de usabilidad | Filosofía | "Visibilidad del estado del sistema" (Nielsen #1) |

```
Jerarquía de abstracción:

HEURÍSTICA (principio general)
"El usuario debe saber siempre dónde está"
        │
        ▼
DESIGN PATTERN (solución al problema)
"Breadcrumbs: mostrar la ruta jerárquica de navegación"
        │
        ▼
UI COMPONENT (implementación concreta)
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Inicio</a></li>
    <li><a href="/productos">Productos</a></li>
    <li aria-current="page">Laptops</li>
  </ol>
</nav>
```

> 💡 **Analogía:** La heurística es la ley de tráfico ("señalizar antes de girar"), el pattern es la solución ("usar luces direccionales"), y el componente es la implementación ("la palanca de la luz del auto").

### 1.3 Por qué existen los design patterns

**Problemas recurrentes:**

```
Los mismos problemas aparecen en todos los productos digitales:

¿Cómo muestro muchos items?           → Cards, Lists, Tables, Grid
¿Cómo navego una estructura grande?   → Sidebar, Breadcrumbs, Tabs
¿Cómo pido datos sin abrumar?         → Multi-step, Progressive disclosure
¿Cómo informo que algo pasó?          → Toast, Alert, Inline feedback
¿Cómo confirmo una acción peligrosa?  → Confirmation modal, Undo
¿Cómo muestro que algo está cargando? → Skeleton, Spinner, Progress bar
¿Cómo muestro que no hay datos?       → Empty state
```

**Estandarización:**
Los patterns funcionan porque los usuarios ya los conocen. Un usuario que ha usado 100 apps ya sabe:
- El ícono ☰ abre un menú
- Un card es clickeable
- Un toast desaparece solo
- Los tabs cambian contenido sin navegar

### 1.4 Beneficios

| Beneficio | Descripción |
|---|---|
| **Consistencia** | Misma solución para el mismo problema en todo el producto |
| **Usabilidad** | El usuario no necesita aprender algo nuevo |
| **Reducción de carga cognitiva** | Menos decisiones = menos esfuerzo mental |
| **Velocidad de diseño** | No reinventar la rueda cada vez |
| **Comunicación** | Vocabulario compartido entre diseño y desarrollo |
| **Escalabilidad** | Soluciones que funcionan en múltiples contextos |

---

## 2. Fundamentos de Design Patterns

### 2.1 Estructura de un patrón

**Intuición**
Todo patrón existe porque hay un problema que se repite. Si no hay problema, no hay patrón. Documentar un patrón sin el problema es como escribir una receta sin decir qué plato estás cocinando.

**Estructura formal — Template de documentación:**

```
┌──────────────────────────────────────────────────────┐
│  NOMBRE DEL PATRÓN                                   │
├──────────────────────────────────────────────────────┤
│                                                      │
│  PROBLEMA:                                           │
│  ¿Qué necesidad del usuario resuelve?               │
│  Ej: "El usuario necesita ver el estado de una       │
│  acción asíncrona sin bloquear su flujo"             │
│                                                      │
│  CONTEXTO:                                           │
│  ¿Cuándo aplica? ¿Cuándo NO aplica?                │
│  Ej: "Acciones no críticas (guardar, enviar).        │
│  NO para errores que requieren acción del usuario"   │
│                                                      │
│  SOLUCIÓN:                                           │
│  Descripción de la estrategia de interacción         │
│  Ej: "Mostrar un mensaje temporal (toast) que        │
│  aparece en una esquina y desaparece en 5s"          │
│                                                      │
│  TRADE-OFFS:                                         │
│  ¿Qué sacrificas al elegir este patrón?             │
│  Ej: "El usuario puede no ver el toast si no está    │
│  mirando. No permite acciones complejas"             │
│                                                      │
│  COMPONENTES INVOLUCRADOS:                           │
│  Toast, Snackbar, NotificationBanner                 │
│                                                      │
│  ALTERNATIVAS:                                       │
│  Inline message (más visible, ocupa espacio),        │
│  Alert dialog (intrusivo pero garantiza atención)    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 2.2 Cuándo usar (y cuándo NO usar) un patrón

**Matriz de decisión:**

```
                      PROBLEMA CONOCIDO    PROBLEMA NUEVO
                      ──────────────────   ─────────────────
CONTEXTO ESTÁNDAR     ✅ Usar patrón       ⚠️ Adaptar patrón
                      conocido             existente

CONTEXTO ÚNICO        ⚠️ Adaptar patrón    🆕 Crear patrón
                      al contexto          propio (con cuidado)
```

**Señales de que DEBES usar un patrón:**
- El problema ya fue resuelto miles de veces (login, search, navigation)
- Los usuarios tienen expectativas establecidas (el ícono 🔍 = buscar)
- Necesitas consistencia con el resto del producto
- El equipo necesita un vocabulario común

**Señales de que NO debes usar un patrón ciegamente:**
- El contexto es fundamentalmente diferente (ej: VR, voice UI)
- El patrón genera más fricción que solución
- Estás forzando un patrón para un problema que no tiene
- La novedad del producto es parte de su valor (ej: gaming, arte)

### 2.3 Adaptación vs copia literal

```
❌ COPIA LITERAL:                    ✅ ADAPTACIÓN INTELIGENTE:

"Spotify usa tabs en mobile,         "Nuestro producto tiene 3
 nosotros también tenemos             secciones principales.
 que usar tabs"                       Para mobile, tabs funcionan
                                      porque son ≤ 5 items y el
                                      acceso debe ser rápido.
                                      Pero nuestra 4ta sección
                                      es rara vez usada, así que
                                      la movemos a un menú 'Más'"

→ Copiar sin entender                → Entender el porqué y
  el porqué                            adaptar al contexto
```

> ⚠️ **Regla:** Nunca copies un patrón porque "así lo hace X empresa". Copia el razonamiento detrás de su decisión, y luego evalúa si aplica a tu contexto.

### 2.4 Anti-patrones

**Intuición**
Un anti-patrón es un patrón mal aplicado: parece una buena solución, pero causa más problemas de los que resuelve.

| Anti-patrón | Qué hace | Por qué es malo |
|---|---|---|
| **Modal abuse** | Usar modales para todo (confirmaciones, info, forms) | Interrumpe el flujo, fatiga de "cerrar" |
| **Mystery meat navigation** | Iconos sin labels, menús sin contexto | El usuario no sabe qué hace cada opción |
| **Carousel of neglect** | Carousel automático de contenido importante | Los usuarios ignoran carousels (~1% CTR en slides 2+) |
| **Infinite scroll everywhere** | Scroll infinito en listados donde el usuario necesita llegar al footer | Imposible encontrar items específicos o el footer |
| **Hamburger all the things** | Ocultar TODA la nav en un hamburger (incluso en desktop) | Reduce descubrimiento, oculta opciones clave |
| **Confirm shaming** | "No gracias, no quiero ahorrar dinero" | Manipulativo, erosiona confianza |
| **Dark patterns** | Trampas de diseño para forzar acciones | Poco ético, posiblemente ilegal (EU, CA) |

---

## 3. Categorías principales de patrones

### 3a. Patrones de navegación

#### Navbar (top navigation)

**Problema:** El usuario necesita acceso rápido a las secciones principales desde cualquier página.

```
PATRÓN: TOP NAVIGATION BAR

┌──────────────────────────────────────────────────────────┐
│  [Logo]    Inicio   Productos   Blog   Precios   [CTA]  │
└──────────────────────────────────────────────────────────┘

Cuándo usar:
  → 3-7 secciones principales
  → Acceso global necesario
  → Desktop y tablet

Cuándo NO usar:
  → > 7 items (demasiado ancho)
  → Mobile (espacio insuficiente)
  → Aplicaciones con nav lateral dominante (dashboards)

Trade-offs:
  ✅ Visible siempre, acceso rápido
  ❌ Espacio horizontal limitado
  ❌ Ocupa espacio vertical fijo
```

#### Sidebar

**Problema:** El usuario necesita navegar una estructura jerárquica con muchas secciones y subsecciones.

```
PATRÓN: SIDEBAR NAVIGATION

┌──────────┬──────────────────────────────────┐
│          │                                  │
│ Dashboard│     Contenido principal          │
│ Proyectos│                                  │
│  ├ Activos│                                 │
│  ├ Archivo│                                 │
│ Equipo   │                                  │
│ Config   │                                  │
│          │                                  │
│          │                                  │
│          │                                  │
│ [?]Ayuda │                                  │
└──────────┴──────────────────────────────────┘

Cuándo usar:
  → Aplicaciones tipo dashboard o admin
  → > 5 secciones con subsecciones
  → Navegación jerárquica (2-3 niveles)
  → Desktop-first apps

Cuándo NO usar:
  → Sitios de contenido simple (blog, landing)
  → Mobile (se convierte en drawer o hamburger)
  → Pocas secciones (usar top nav)

Variantes:
  → Colapsable: ícono + tooltip cuando está minimizado
  → Con secciones agrupadas
  → Con badge/indicadores de estado
```

#### Tab navigation

```
PATRÓN: TABS

  [General]  [Seguridad]  [Notificaciones]  [Integraciones]
  ──────────
  Contenido de General...

Cuándo usar:
  → 2-7 secciones del MISMO nivel jerárquico
  → Contenido que NO necesita verse simultáneamente
  → Dentro de una página (no navegación global)

Cuándo NO usar:
  → > 7 tabs (overflow confuso)
  → Contenido que se compara entre tabs
  → Navegación primaria del sitio (usar navbar)
  → Cuando el contenido es secuencial (usar stepper)

Trade-offs:
  ✅ Organiza contenido relacionado sin cambiar de página
  ❌ Solo un tab visible a la vez
  ❌ El usuario puede no descubrir contenido en otros tabs
```

#### Breadcrumbs

```
PATRÓN: BREADCRUMBS

  Inicio  >  Productos  >  Laptops  >  MacBook Pro 16"

Cuándo usar:
  → Estructura jerárquica de 3+ niveles
  → El usuario puede llegar desde múltiples caminos
  → E-commerce, documentación, file systems

Cuándo NO usar:
  → Sitios planos (1-2 niveles)
  → Apps de flujo lineal (checkout)
  → Como navegación primaria (es secundaria)
```

#### Hamburger menu

```
PATRÓN: HAMBURGER MENU (☰)

  ┌──────────────────────┐
  │ ☰  Mi App     [🔔]  │
  └──────────────────────┘
       │
       ▼
  ┌──────────────────────┐
  │ Inicio               │
  │ Productos            │
  │ Blog                 │
  │ Cuenta               │
  │ Configuración        │
  └──────────────────────┘

Cuándo usar:
  → Mobile: nav que no cabe en pantalla
  → Navegación secundaria que no necesita estar siempre visible
  → Cuando el contenido es más importante que la nav

Cuándo NO usar:
  → Desktop con espacio suficiente (mostrar la nav directamente)
  → Si hay ≤ 5 items (usar tab bar en mobile)
  → Para ocultar la acción principal del producto

⚠️ El hamburger REDUCE descubrimiento. Lo que está oculto
   se usa ~50% menos que lo que está visible.
```

#### Mega menu

```
PATRÓN: MEGA MENU

┌──────────────────────────────────────────────────────────────┐
│  [Logo]    Productos ▾   Soluciones   Recursos   Precios    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Hardware        Software         Servicios                  │
│  ─────────       ─────────        ─────────                  │
│  Laptops         OS Suite         Soporte                    │
│  Monitores       Design Tools     Consultoría                │
│  Periféricos     Dev Tools        Training                   │
│  Accesorios      Analytics        Implementación             │
│                                                              │
│  [Ver todos los productos →]                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘

Cuándo usar:
  → Sitios con MUCHAS categorías (e-commerce, enterprise)
  → Estructura de navegación ancha (muchas opciones de nivel 2)
  → Desktop exclusivo

Cuándo NO usar:
  → Mobile (usar accordions o drill-down en su lugar)
  → Pocas categorías (< 10 items totales)
  → Si causa "choice paralysis"
```

---

### 3b. Patrones de contenido

#### Cards

```
PATRÓN: CARDS

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  ┌─────────────┐│  │  ┌─────────────┐│  │  ┌─────────────┐│
│  │   Imagen    ││  │  │   Imagen    ││  │  │   Imagen    ││
│  └─────────────┘│  │  └─────────────┘│  │  └─────────────┘│
│  Título          │  │  Título          │  │  Título          │
│  Descripción     │  │  Descripción     │  │  Descripción     │
│  breve...        │  │  breve...        │  │  breve...        │
│                  │  │                  │  │                  │
│  [Acción]        │  │  [Acción]        │  │  [Acción]        │
└─────────────────┘  └─────────────────┘  └─────────────────┘

Problema: Mostrar múltiples items con preview visual que inviten
          a explorar más detalle.

Cuándo usar:
  → Colecciones de items heterogéneos (productos, artículos, proyectos)
  → Cuando la imagen/preview es importante
  → Cuando cada item es independiente

Cuándo NO usar:
  → Datos homogéneos y densos (usar tabla)
  → Listas de texto puro (usar list)
  → Cuando el espacio es crítico (cards desperdician espacio)
```

#### Lists vs Tables vs Grid

```
DECISIÓN: ¿Cómo muestro una colección de datos?

¿Es visual (imágenes)?
│
├─ SÍ → ¿Cada item es independiente?
│  ├─ SÍ → CARD GRID (productos, artículos)
│  └─ NO → MEDIA LIST (feed, timeline)
│
└─ NO → ¿Tiene múltiples atributos por item?
   │
   ├─ SÍ → ¿El usuario necesita comparar/ordenar/filtrar?
   │  ├─ SÍ → TABLE (datos estructurados, admin)
   │  └─ NO → LIST con metadata (contactos, archivos)
   │
   └─ NO → SIMPLE LIST (menús, settings, to-dos)
```

**Comparación:**

| Patrón | Mejor para | Datos por item | Escaneo |
|---|---|---|---|
| **Simple List** | Items con 1-2 atributos | Título + descripción | Vertical rápido |
| **Card Grid** | Items visuales independientes | Imagen + título + acción | Visual, browsing |
| **Table** | Datos estructurados comparables | 3+ atributos por fila | Horizontal + vertical |
| **Media List** | Items con imagen + texto | Thumbnail + título + meta | Vertical, feed-like |

#### Infinite scroll vs Pagination

```
INFINITE SCROLL:                     PAGINATION:

┌──────────────┐                     ┌──────────────┐
│ Item 1       │                     │ Item 1       │
│ Item 2       │                     │ Item 2       │
│ Item 3       │                     │ ...          │
│ Item 4       │                     │ Item 10      │
│ Item 5       │                     ├──────────────┤
│ ... (scroll) │                     │ ◀ 1 2 [3] 4 ▶│
│ ◌ Loading... │                     └──────────────┘
│ Item 6       │
│ Item 7       │
│ ...          │
└──────────────┘

INFINITE SCROLL                      PAGINATION
─────────────────                    ─────────────────
✅ Browsing / discovery              ✅ Búsqueda específica
✅ Feeds (social, noticias)          ✅ E-commerce, catálogos
✅ Engagement alto                   ✅ Resultados de búsqueda
❌ No puedes llegar al footer        ✅ Puedes volver al item X
❌ Difícil encontrar item X          ✅ Compartir posición (URL)
❌ Performance en listas largas      ❌ Más clicks
❌ Accesibilidad compleja            ✅ Accesible

HÍBRIDO: "Load more" button
→ Lo mejor de ambos: el usuario controla cuándo cargar más,
  puede llegar al footer, y no necesita cambiar de página.
```

---

### 3c. Patrones de interacción

#### Modals

```
PATRÓN: MODAL / DIALOG

┌────────────────────────────────────────┐
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░┌──────────────────────────────┐░░░░│
│░░░│  ¿Eliminar este proyecto?    │░░░░│
│░░░│                              │░░░░│
│░░░│  Esta acción no se puede     │░░░░│
│░░░│  deshacer. Se eliminarán     │░░░░│
│░░░│  todos los archivos.         │░░░░│
│░░░│                              │░░░░│
│░░░│  [Cancelar]  [Eliminar]      │░░░░│
│░░░└──────────────────────────────┘░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
└────────────────────────────────────────┘

Cuándo usar:
  → Confirmación de acciones destructivas
  → Información crítica que requiere decisión inmediata
  → Formularios cortos (login, quick edit)
  → El usuario DEBE actuar antes de continuar

Cuándo NO usar:
  → Información que no requiere acción (usar toast o inline)
  → Formularios largos (usar página o panel)
  → Mensajes de bienvenida, promos, newsletters (anti-patrón)
  → En secuencia (modal dentro de modal = caos)

Reglas:
  → Máximo 1 acción principal + 1 secundaria
  → Siempre ofrecer "cancelar" o cierre con ✕
  → Escape cierra el modal
  → Focus trap activo
  → No usar para contenido scrollable largo
```

#### Dropdowns, Tooltips, Accordions

```
DROPDOWN:                            TOOLTIP:
┌──────────────────┐                 Elemento [?]
│ Opciones      ▾  │                      │
├──────────────────┤                 ┌────────────────────┐
│ Editar           │                 │ Texto explicativo   │
│ Duplicar         │                 │ breve y contextual  │
│ ───────────────  │                 └────────────────────┘
│ 🗑 Eliminar      │
└──────────────────┘                 Cuándo usar:
                                     → Info complementaria breve
Cuándo usar:                         → Definiciones, ayuda contextual
→ Acciones sobre un item            → Al hover / focus
→ Opciones de menú contextual
→ Filtros y selección                Cuándo NO:
                                     → Info esencial (no depender de hover)
Cuándo NO:                           → Texto largo (> 1-2 oraciones)
→ 2-3 opciones visibles             → Mobile (no hay hover)
  (usar radio/buttons)


ACCORDION:
┌─────────────────────────────────────┐
│ ▶ ¿Cuál es su política de cambios? │
├─────────────────────────────────────┤
│ ▼ ¿Cómo puedo rastrear mi pedido?  │
│                                     │
│   Ingresa a "Mis pedidos" y...     │
│   ...texto expandido...             │
│                                     │
├─────────────────────────────────────┤
│ ▶ ¿Ofrecen envío internacional?    │
└─────────────────────────────────────┘

Cuándo usar:
  → FAQs, contenido "escaneable" largo
  → El usuario NO necesita ver todo a la vez
  → Reducir scroll en páginas densas

Cuándo NO:
  → Si la mayoría de users necesitan todo el contenido (mostrar directo)
  → Contenido esencial que no debe ocultarse
  → Si solo hay 2-3 secciones cortas
```

#### Tabs (como interacción)

```
PATRÓN: TABS (content switching)

  [Overview]  [Activity]  [Settings]
  ───────────
  Contenido de Overview...

REGLAS:
  → El tab activo está claramente marcado (borde, color, peso)
  → El contenido cambia SIN cambiar de página
  → El orden de tabs es consistente
  → Max 7 tabs (mobile: max 5)
  → En mobile: scroll horizontal si hay overflow

vs LINKS/NAV:
  Tabs → Mismo nivel jerárquico, mismo contexto, sin URL change
  Links → Diferente página, diferente URL, diferente contexto
```

---

### 3d. Patrones de entrada de datos

#### Formularios

```
PROBLEMA: Pedir datos al usuario con la menor fricción posible.

PATRÓN BASE: FORM

  Sección: Información personal
  ─────────────────────────────
  Nombre          Apellido
  ┌─────────────┐ ┌─────────────┐
  │             │ │             │
  └─────────────┘ └─────────────┘

  Email
  ┌─────────────────────────────┐
  │                             │
  └─────────────────────────────┘
  Usaremos tu email para confirmar

  [Cancelar]            [Continuar →]

PRINCIPIOS:
  → Un solo propósito por formulario
  → Agrupar campos relacionados (fieldsets)
  → Labels siempre visibles
  → Validate on blur, revalidate on change
  → Acción primaria obvia (1 CTA principal)
  → Reducir campos al mínimo necesario
```

#### Multi-step forms

```
PROBLEMA: El formulario tiene 10+ campos y abruma al usuario.

PATRÓN: MULTI-STEP / WIZARD

  Paso 2 de 4: Tu dirección
  ●━━━●━━━○━━━○

  ┌───────────────────────────────┐
  │ Dirección                     │
  │ ┌───────────────────────────┐ │
  │ │                           │ │
  │ └───────────────────────────┘ │
  │                               │
  │ Ciudad        Estado    CP    │
  │ ┌──────────┐ ┌──────┐ ┌────┐ │
  │ │          │ │   ▾  │ │    │ │
  │ └──────────┘ └──────┘ └────┘ │
  │                               │
  │  [← Atrás]    [Continuar →]  │
  └───────────────────────────────┘

REGLAS:
  → 3-5 pasos máximo
  → Progress indicator visible
  → Validar al avanzar, no al final
  → Permitir "Atrás" siempre
  → Resumen en el último paso
  → Autosave entre pasos
```

#### Inline editing

```
PROBLEMA: El usuario necesita editar un dato puntual sin abrir
          un formulario completo.

PATRÓN: INLINE EDITING

  MODO LECTURA:                      MODO EDICIÓN:
  ┌──────────────────────────┐       ┌──────────────────────────┐
  │ Nombre del proyecto   ✏️ │  →    │ ┌────────────────────┐   │
  │ Mi proyecto increíble    │       │ │ Mi proyecto incre█ │   │
  └──────────────────────────┘       │ └────────────────────┘   │
                                     │ [Cancelar]  [Guardar]    │
                                     └──────────────────────────┘

  Click en ✏️ o double-click → activa edición
  Enter o click fuera → guarda (si autosave)
  Escape → cancela

Cuándo usar:
  → Ediciones frecuentes de campos individuales
  → Dashboards, tablas editables, settings
  → El dato editado es visible en contexto

Cuándo NO:
  → Edición de múltiples campos relacionados (usar form)
  → Datos que requieren validación compleja
  → Mobile (targets pequeños, doble-tap confuso)
```

#### Autocomplete y Search

```
PATRÓN: AUTOCOMPLETE / AUTOSUGGEST

  ┌────────────────────────────────┐
  │ 🔍  react ho█                 │
  ├────────────────────────────────┤
  │  react hooks                   │ ← Sugerencia basada en input
  │  react hooks tutorial          │
  │  react hooks useEffect         │
  │  react hot reload              │
  └────────────────────────────────┘

VARIANTES:
  → Search suggestions (texto predictivo)
  → Search + results (muestra resultados inline)
  → Combobox (select + text input)
  → Command palette (Cmd+K, /, Ctrl+P)


PATRÓN: SEARCH

  SEARCH BAR:              FILTERABLE SEARCH:
  ┌──────────────────┐     ┌──────────┬───────────────────┐
  │ 🔍 Buscar...     │     │ Filtros  │ 🔍 Buscar...     │
  └──────────────────┘     │ ☑ Activos│ Resultados:       │
                           │ ☐ Archivo│ ─────────────      │
                           │          │ Item 1             │
                           │ Tipo:    │ Item 2             │
                           │ ○ Todos  │ Item 3             │
                           │ ○ Docs   │                    │
                           │ ○ Media  │ 42 resultados      │
                           └──────────┴───────────────────┘
```

---

### 3e. Patrones de feedback

#### Toast notifications

```
PATRÓN: TOAST / SNACKBAR

                                    ┌──────────────────────────┐
  Contenido de la página            │ ✓ Cambios guardados      │
  ...                               │              [Deshacer]  │
                                    └──────────────────────────┘
                                    ↑ Aparece abajo-derecha
                                      Desaparece en 5s

Cuándo usar:
  → Confirmación de acciones exitosas no críticas
  → Acciones reversibles (con "Deshacer")
  → Feedback que no requiere acción del usuario

Cuándo NO:
  → Errores que requieren corrección (usar inline error)
  → Información crítica (usar alert o modal)
  → Múltiples toasts simultáneos (confuso)
```

#### Loading states

```
DECISIÓN: ¿Cómo muestro que algo está cargando?

¿Cuánto tarda?
│
├─ < 300ms → NO mostrar nada (imperceptible)
│
├─ 300ms - 1s → SPINNER sutil
│  ┌──────────────┐
│  │      ◌       │
│  └──────────────┘
│
├─ 1s - 5s → SKELETON SCREEN
│  ┌──────────────────────────────┐
│  │ ████████████                 │
│  │ ░░░░░░░░░░░░░░░░░░░░░      │
│  │ ░░░░░░░░░░░░░░░             │
│  │                              │
│  │ ████████                     │
│  │ ░░░░░░░░░░░░░░░░░░          │
│  └──────────────────────────────┘
│  (Muestra la estructura del contenido que vendrá)
│
├─ 5s - 30s → PROGRESS BAR con porcentaje
│  ┌──────────────────────────────┐
│  │ Subiendo archivo...  67%    │
│  │ ████████████████░░░░░░░░    │
│  └──────────────────────────────┘
│
└─ > 30s → BACKGROUND PROCESS + notification
   "Te notificaremos cuando el reporte esté listo"
```

#### Empty states

```
PATRÓN: EMPTY STATE

❌ MAL:                              ✅ BIEN:
┌──────────────────────┐            ┌──────────────────────┐
│                      │            │                      │
│                      │            │     📋               │
│   No hay datos       │            │                      │
│                      │            │  No tienes proyectos  │
│                      │            │  aún.                 │
│                      │            │                      │
│                      │            │  Crea tu primer       │
│                      │            │  proyecto para        │
│                      │            │  empezar.             │
│                      │            │                      │
│                      │            │  [+ Crear proyecto]   │
│                      │            │                      │
└──────────────────────┘            └──────────────────────┘

ESTRUCTURA DE UN BUEN EMPTY STATE:
  1. Ilustración / icono contextual
  2. Mensaje claro (qué está vacío y por qué)
  3. Call to action (qué hacer para llenarlo)
  4. Opcional: link a documentación o tutorial
```

#### Error handling patterns

```
NIVELES DE ERROR:

NIVEL 1 — INLINE (campo específico):
  Email
  ┌──────────────────────────┐
  │ abc                      │
  └──────────────────────────┘
  ✗ Ingresa un email válido

NIVEL 2 — BANNER (error de sección/formulario):
  ┌──────────────────────────────────────────┐
  │ ⚠️ Hay 3 errores en el formulario.       │
  │    Corrígelos para continuar.            │
  └──────────────────────────────────────────┘

NIVEL 3 — TOAST (error de acción):
  ┌───────────────────────────────────┐
  │ ✗ No se pudo guardar. Reintenta. │
  └───────────────────────────────────┘

NIVEL 4 — FULL PAGE (error de sistema):
  ┌──────────────────────────────────────────┐
  │                                          │
  │           😵 Algo salió mal              │
  │                                          │
  │   No pudimos cargar esta página.         │
  │   El equipo ya fue notificado.           │
  │                                          │
  │   [Reintentar]  [Ir al inicio]           │
  │                                          │
  └──────────────────────────────────────────┘

REGLA: Usa el MENOR nivel de intrusión que resuelva el problema.
  Inline > Banner > Toast > Full page
```

---

## 4. Patrones de comportamiento del usuario

### 4.1 Progressive disclosure

**Intuición**
Muestra solo lo necesario ahora. Revela complejidad conforme el usuario la necesita. Nadie necesita ver 50 opciones de configuración al abrir la app por primera vez.

```
PROBLEMA: La interfaz tiene mucha funcionalidad y abruma al nuevo usuario.

SOLUCIÓN: Revelar en capas.

CAPA 1 (siempre visible):      Las opciones más comunes
CAPA 2 (click para expandir):  Opciones avanzadas
CAPA 3 (settings/admin):       Configuración profunda

EJEMPLO — Filtros de búsqueda:

  Estado inicial:                  Después de "Más filtros":
  ┌──────────────────────┐        ┌──────────────────────┐
  │ Categoría     [▾]    │        │ Categoría     [▾]    │
  │ Precio        [▾]    │        │ Precio        [▾]    │
  │                      │        │ Marca         [▾]    │
  │ [+ Más filtros]      │        │ Color         [▾]    │
  └──────────────────────┘        │ Tamaño        [▾]    │
                                  │ Valoración    [▾]    │
  Solo 2 filtros principales      │                      │
  → Menos abrumador               │ [– Menos filtros]    │
                                  └──────────────────────┘
```

### 4.2 Recognition over recall

**Intuición**
Es más fácil reconocer algo que recordarlo. Muestra opciones en vez de pedir que el usuario las recuerde.

```
❌ RECALL (recordar):                ✅ RECOGNITION (reconocer):

  "Ingresa el código de color"       "Selecciona un color"
  ┌──────────────────────┐           ┌──────┬──────┬──────┐
  │ #                    │           │  🔴  │  🟢  │  🔵  │
  └──────────────────────┘           │  🟡  │  🟣  │  ⚫  │
  El usuario necesita recordar       └──────┴──────┴──────┘
  el código hexadecimal.             El usuario elige visualmente.


❌ RECALL:                           ✅ RECOGNITION:
  "Escribe el comando"               ┌──────────────────────┐
  ┌──────────────────────┐           │ Recientes:           │
  │ >                    │           │  📄 report.pdf       │
  └──────────────────────┘           │  📊 dashboard.xlsx   │
                                     │  📝 notas.md         │
                                     └──────────────────────┘
                                     Archivos recientes visibles.
```

### 4.3 Default choices (smart defaults)

```
PROBLEMA: El usuario tiene que configurar muchas opciones antes de empezar.

SOLUCIÓN: Pre-configurar con los valores más comunes.

EJEMPLO:
  Nuevo proyecto

  Nombre: [Mi proyecto           ]    ← Auto-generado
  Idioma: [Español            ▾ ]    ← Según locale
  Zona:   [America/Mexico_City▾ ]    ← Según IP
  Moneda: [MXN                ▾ ]    ← Según país
  Formato de fecha: [DD/MM/YYYY ▾]    ← Según región

  ☑ Notificaciones por email          ← Activado por defecto
  ☐ Notificaciones push               ← Desactivado (pedir permiso)

  [Crear proyecto]

→ El usuario puede crear el proyecto con 1 click.
→ Cada default es editable, pero ya funciona.
```

### 4.4 Constraint-based design

**Intuición**
Las restricciones bien diseñadas previenen errores. Es más fácil no dejar al usuario equivocarse que pedirle que corrija.

```
EJEMPLO:

Fecha de ida:     [ 15 Abril 2026 ▾ ]
Fecha de regreso: [ _____________ ▾ ]  ← Calendario NO muestra
                                          fechas ANTES del 15 abril

→ Restricción: imposible seleccionar regreso antes de ida.
→ Sin restricción: el usuario selecciona fechas inválidas,
  ve un error, se frustra, corrige.


EJEMPLO:
  Contraseña:
  ┌──────────────────────────────┐
  │ MiPassword1█                 │
  └──────────────────────────────┘
  ✓ 8+ caracteres   ✓ Mayúscula   ✓ Número   ✗ Símbolo

→ Restricción visible en tiempo real → el usuario sabe qué falta
  ANTES de enviar.
```

### 4.5 Confirmación vs Acción inmediata + Undo

```
ENFOQUE A: CONFIRMAR ANTES                ENFOQUE B: ACCIÓN + UNDO

  [🗑 Eliminar]                            [🗑 Eliminar]
        │                                       │
        ▼                                       ▼
  ┌─────────────────────┐              (se elimina inmediatamente)
  │ ¿Estás seguro?      │
  │                     │              ┌──────────────────────────┐
  │ [Cancelar][Eliminar]│              │ Item eliminado. [Deshacer]│
  └─────────────────────┘              └──────────────────────────┘

USAR CONFIRMACIÓN:                     USAR UNDO:
  → Acciones destructivas              → Acciones reversibles
    irreversibles                      → Acciones frecuentes
  → Alto impacto (eliminar cuenta)     → Bajo costo de error
  → Datos sensibles                    → Mejor UX (menos fricción)

EJEMPLO: Gmail usa "Deshacer envío" en vez de "¿Seguro que quieres enviar?"
→ Menos fricción para la acción más frecuente.
```

### 4.6 Feedback loops

```
ACCIÓN ──→ FEEDBACK ──→ RESULTADO ──→ NUEVO ESTADO

EJEMPLO: Like en una publicación
  [♡] → Click → [❤️] (animación) → "1 like" → Completado

EJEMPLO: Form submit
  [Guardar] → Click → [◌ Guardando...] → [✓ Guardado] → Estado normal

EJEMPLO: Upload
  [Subir] → Click → [████░░░░ 45%] → [✓ archivo.pdf subido] → Preview

TODO feedback loop necesita:
  1. ACKNOWLEDGMENT — "Recibí tu acción" (loading)
  2. PROGRESS — "Estoy trabajando" (progress bar, spinner)
  3. COMPLETION — "Terminé" (success/error state)
  4. NEXT STATE — "Así es la nueva realidad" (UI actualizada)
```

---

## 5. Patrones en flujos complejos

### 5.1 Onboarding

```
PROBLEMA: El usuario nuevo no sabe cómo usar el producto.

PATRONES DE ONBOARDING:

1. WELCOME TOUR (paso a paso):
   ┌──────────────────────────────────────┐
   │                                      │
   │  ┌────────────────────────────────┐  │
   │  │ 💡 Este es tu dashboard.       │  │
   │  │ Aquí verás todos tus           │  │
   │  │ proyectos y métricas.          │  │
   │  │                                │  │
   │  │  1/4  [Siguiente →]            │  │
   │  └────────────────────────────────┘  │
   │           ↑ (apunta al dashboard)     │
   └──────────────────────────────────────┘
   → Bueno para: features complejas o no obvias
   → Malo si: es largo (> 5 pasos), o bloquea el uso

2. EMPTY STATE ONBOARDING:
   ┌──────────────────────────────────────┐
   │                                      │
   │         📋 Tu workspace              │
   │                                      │
   │   Aún no tienes proyectos.           │
   │   Empieza creando uno:               │
   │                                      │
   │   [+ Crear proyecto]                 │
   │                                      │
   │   O explora nuestra plantilla de     │
   │   ejemplo → [Ver plantilla]          │
   │                                      │
   └──────────────────────────────────────┘
   → Bueno para: apps donde el valor viene de crear contenido
   → El propio uso es el onboarding

3. PROGRESSIVE ONBOARDING (checklist):
   ┌──────────────────────────────────────┐
   │ Completa tu setup (2/5)             │
   │ ████████░░░░░░░░░░░░  40%          │
   │                                      │
   │ ✓ Crear cuenta                       │
   │ ✓ Completar perfil                   │
   │ ○ Crear primer proyecto              │
   │ ○ Invitar equipo                     │
   │ ○ Conectar integración               │
   └──────────────────────────────────────┘
   → Bueno para: SaaS con múltiples pasos de setup
   → Gamificación sutil (progreso visible)
```

### 5.2 Checkout flows

```
PATRÓN: CHECKOUT OPTIMIZADO

                    ┌─────────────────────────────────────────────┐
                    │             CHECKOUT                        │
  ●━━━━●━━━━○━━━━○ │                                             │
  Info   Envío      │  Tu pedido:                                │
                    │  ┌──────────────────────────────────────┐  │
  Dirección de envío│  │ Product A            $29.99          │  │
  ┌──────────────── │  │ Product B            $49.99          │  │
  │ ┌────────────┐  │  │ Envío                 $5.99          │  │
  │ │Juan García │  │  │                    ──────────        │  │
  │ └────────────┘  │  │ Total                $85.97          │  │
  │                 │  └──────────────────────────────────────┘  │
  │ ┌────────────┐  │                                             │
  │ │Calle 123   │  │  [← Atrás]          [Continuar →]         │
  │ └────────────┘  │                                             │
  └─────────────────┴─────────────────────────────────────────────┘

PRINCIPIOS DE CHECKOUT:
  → Eliminar distracciones (quitar nav, footer, links externos)
  → Progress bar visible (3-4 pasos max)
  → Resumen del pedido siempre visible
  → Autosave / recovery si cierra la ventana
  → Guest checkout (no obligar a crear cuenta)
  → Múltiples métodos de pago
  → Trust signals (candado, logos de seguridad)
  → Dirección con autocomplete (Google Maps)
  → "Misma dirección de facturación" por defecto
```

### 5.3 Dashboard interactions

```
PATRÓN: DASHBOARD

┌─────────┬──────────────────────────────────────────────┐
│         │  Buenos días, Juan          [🔔 3] [👤]      │
│ 📊 Home ├──────────────────────────────────────────────┤
│ 📁 Proj │                                              │
│ 👥 Team │  ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│ 📈 Stats│  │ Ventas   │ │ Usuarios │ │ Tareas   │     │
│ ⚙ Config│  │ $12,450  │ │   1,234  │ │   23/50  │     │
│         │  │  ↑ 12%   │ │  ↑ 5%   │ │  ↓ 2%   │     │
│         │  └──────────┘ └──────────┘ └──────────┘     │
│         │                                              │
│         │  Actividad reciente                          │
│         │  ─────────────────                           │
│         │  • Juan editó "Report Q2"     Hace 2h       │
│         │  • María creó "Campaign X"    Hace 5h       │
│         │  • API: 3 errores detectados  Hace 1d       │
│         │                                              │
└─────────┴──────────────────────────────────────────────┘

PATRONES DE DASHBOARD:
  → KPI cards en la parte superior (overview rápido)
  → Actividad reciente (feed cronológico)
  → Quick actions (atajos a tareas frecuentes)
  → Sidebar para navegación persistente
  → Contenido personalizado según rol/permisos
  → Drill-down: click en KPI → detalle
```

### 5.4 CRUD interfaces

```
PATRÓN: CRUD (Create, Read, Update, Delete)

  LIST (Read all):
  ┌────┬──────────────┬──────────┬────────┬─────────┐
  │ ☐  │ Nombre       │ Estado   │ Fecha  │ Acción  │
  ├────┼──────────────┼──────────┼────────┼─────────┤
  │ ☐  │ Proyecto A   │ 🟢 Activo│ 15 Abr │ ⋯      │
  │ ☐  │ Proyecto B   │ 🟡 Pausa │ 10 Abr │ ⋯      │
  │ ☐  │ Proyecto C   │ 🔴 Cerrado│  1 Mar │ ⋯      │
  └────┴──────────────┴──────────┴────────┴─────────┘
  [+ Nuevo proyecto]        2 seleccionados: [Archivar] [🗑]

  CREATE (formulario o modal):
  → Click "Nuevo" → Form → Guardar → Redirect a detalle o lista

  READ (detalle):
  → Click en item → Página de detalle → Tabs (overview, activity, settings)

  UPDATE:
  → Inline editing para cambios rápidos (nombre, estado)
  → Full form para edición completa
  → Autosave o "Guardar cambios"

  DELETE:
  → Acción en item ⋯ → "Eliminar"
  → Confirmación modal (acción destructiva)
  → O "Archivar" como alternativa reversible (preferible)
```

---

## 6. Evaluación de patrones

### 6.1 Framework de evaluación

**Intuición**
Elegir el patrón correcto no es memorizar una lista. Es evaluar el contexto y las restricciones de tu problema específico.

**Matriz de evaluación:**

```
CRITERIO              PESO    PREGUNTA CLAVE
──────────────────────────────────────────────────────────
Usabilidad            ★★★★★   ¿El usuario completa su tarea
                              sin fricción?

Familiaridad          ★★★★    ¿El usuario ya conoce este
                              patrón de otros productos?

Contexto del producto ★★★★    ¿El patrón encaja con el tipo
                              de producto (SaaS, e-commerce,
                              content, social)?

Tipo de usuario       ★★★★    ¿El usuario es novato, intermedio
                              o experto? (novato = simple,
                              experto = potente)

Plataforma            ★★★     ¿Funciona en web, mobile, ambos?
                              ¿Touch vs pointer?

Accesibilidad         ★★★★★   ¿Es accesible por teclado,
                              screen reader, contraste?

Performance           ★★★     ¿El patrón escala con muchos
                              datos? (infinite scroll vs pagination)

Implementación        ★★      ¿El equipo puede implementarlo
                              correctamente?
```

### 6.2 Evaluación por contexto de producto

| Tipo de producto | Patrones dominantes | Evitar |
|---|---|---|
| **E-commerce** | Cards, filters, search, pagination, checkout, breadcrumbs | Infinite scroll en catálogos (imposible llegar al footer) |
| **SaaS / Dashboard** | Sidebar, tables, CRUD, modals, inline edit, toasts | Mega menus (complejidad innecesaria) |
| **Content / Blog** | Top nav, cards, infinite scroll, feed, search | Tabs profundos, sidebars complejas |
| **Social / Feed** | Infinite scroll, cards, feed, modals, bottom nav | Pagination (rompe el flujo de discovery) |
| **Enterprise / Admin** | Tables, sidebar, CRUD, multi-step, filters | Diseño minimalista excesivo (usuarios expertos necesitan densidad) |

### 6.3 Métricas de éxito por patrón

| Patrón | Métrica clave | Señal de éxito | Señal de problema |
|---|---|---|---|
| **Search** | Search success rate | > 80% encuentran lo que buscan | Muchas búsquedas sin click |
| **Onboarding** | Completion rate | > 70% completan todos los pasos | Drop-off en paso 2 |
| **Checkout** | Conversion rate | > 60% completan compra | Abandono en paso de pago |
| **Infinite scroll** | Engagement time | Alto scroll depth | Bounce rate alto |
| **Pagination** | Pages viewed | 2-3 páginas promedio | Solo visitan página 1 |
| **Multi-step form** | Step completion | > 85% por paso | Drop-off en paso específico |
| **Modal** | Completion rate | > 90% interactúan | > 50% cierran sin leer |
| **Empty state** | Activation rate | > 50% realizan el CTA | Usuarios se van sin actuar |

---

## 7. Design Patterns en Design Systems

### 7.1 Documentación de patrones

**Estructura de documentación:**

```markdown
# Patrón: [Nombre]

## Problema
¿Qué problema del usuario resuelve?

## Contexto
¿Cuándo usar este patrón? ¿Cuándo NO usarlo?

## Solución
Descripción de la interacción + wireframe/diagrama.

## Variantes
- Variante A: Contexto desktop
- Variante B: Contexto mobile
- Variante C: Contexto con muchos datos

## Componentes involucrados
Lista de componentes del design system que implementan este patrón.

## Accesibilidad
Requerimientos a11y específicos de este patrón.

## Ejemplos
### ✅ Uso correcto
[Imagen/diagrama + explicación]

### ❌ Uso incorrecto
[Imagen/diagrama + por qué es incorrecto]

## Trade-offs
¿Qué sacrificas al elegir este patrón? ¿Alternativas?

## Métricas
¿Cómo mides si el patrón está funcionando?
```

### 7.2 Relación patrón ↔ componente

```
UN PATRÓN puede usar MÚLTIPLES componentes:

Patrón "Confirmation"
├── Modal (componente)
├── Button Primary "Confirmar" (componente)
├── Button Tertiary "Cancelar" (componente)
└── Icon Warning (componente)

UN COMPONENTE puede participar en MÚLTIPLES patrones:

Componente "Modal"
├── Patrón: Confirmación destructiva
├── Patrón: Quick edit form
├── Patrón: Image preview
└── Patrón: Alert dialog

→ PATRÓN = ESTRATEGIA (cómo resolver el problema)
→ COMPONENTE = IMPLEMENTACIÓN (con qué piezas)
```

### 7.3 Reutilización y escalabilidad

```
PATTERN LIBRARY dentro del Design System:

design-system/
├── foundations/
│   ├── colors/
│   ├── typography/
│   └── spacing/
│
├── components/         ← Piezas atómicas
│   ├── Button/
│   ├── Input/
│   ├── Modal/
│   ├── Card/
│   ├── Toast/
│   └── ...
│
├── patterns/           ← Soluciones a problemas
│   ├── navigation/
│   │   ├── sidebar.md
│   │   ├── breadcrumbs.md
│   │   └── tab-navigation.md
│   ├── data-entry/
│   │   ├── form-layout.md
│   │   ├── multi-step-form.md
│   │   └── inline-editing.md
│   ├── feedback/
│   │   ├── loading-states.md
│   │   ├── empty-states.md
│   │   └── error-handling.md
│   └── flows/
│       ├── onboarding.md
│       ├── checkout.md
│       └── crud.md
│
└── templates/          ← Composiciones de patrones
    ├── dashboard.md
    ├── settings-page.md
    └── list-detail.md
```

### 7.4 Consistencia entre equipos

```
SIN PATTERN LIBRARY:

  Equipo A                Equipo B                Equipo C
  "Loading" = Spinner     "Loading" = Skeleton    "Loading" = Text
  Error = Modal           Error = Toast           Error = Inline
  Delete = Immediate      Delete = Confirm        Delete = Archive

  → 3 experiencias diferentes para el mismo usuario
  → Confusión, inconsistencia, deuda de diseño


CON PATTERN LIBRARY:

  Equipo A                Equipo B                Equipo C
  "Loading" = definido    "Loading" = definido    "Loading" = definido
  Error = definido        Error = definido        Error = definido
  Delete = definido       Delete = definido       Delete = definido

  → 1 experiencia consistente
  → Un solo lugar para actualizar = cambio global
```

---

## 8. Mobile vs Desktop Patterns

### 8.1 Diferencias clave

| Aspecto | Desktop | Mobile |
|---|---|---|
| **Input** | Mouse + teclado | Touch (dedo gordo) |
| **Pantalla** | Grande (1024-2560px) | Pequeña (320-428px) |
| **Hover** | Sí | No (no existe hover) |
| **Multitarea** | Sí (múltiples ventanas) | Limitada (una app a la vez) |
| **Atención** | Enfocada (trabajo) | Dividida (en movimiento) |
| **Navegación** | Top nav, sidebar | Bottom nav, hamburger, tabs |
| **Scrolling** | Vertical + horizontal | Vertical (casi siempre) |
| **Densidad de info** | Alta (tablas, dashboards) | Baja (una cosa a la vez) |

### 8.2 Adaptación de patrones

**Navegación:**

```
DESKTOP:                              MOBILE:
┌─────────────────────────────┐      ┌──────────────────┐
│ Logo  Nav1  Nav2  Nav3  [CTA]│      │ ☰  Logo    [🔔]  │
├─────────────────────────────┤      ├──────────────────┤
│                             │      │                  │
│  Contenido                  │      │  Contenido       │
│                             │      │  (full width)    │
│                             │      │                  │
│                             │      │                  │
│                             │      ├──────────────────┤
└─────────────────────────────┘      │ 🏠  🔍  ➕  👤  │
                                     └──────────────────┘
Top nav visible                      Hamburger + Bottom tab bar
```

**Tablas:**

```
DESKTOP (tabla completa):            MOBILE (lista adaptada):
┌─────┬──────────┬────────┬────┐    ┌──────────────────────┐
│ Nom │ Email    │ Plan   │ $  │    │ Juan García          │
├─────┼──────────┼────────┼────┤    │ Pro · $29/mes        │
│ Juan│ j@ma.com │ Pro    │ $29│    │ j@mail.com           │
│ María│m@ma.com │ Free   │ $0 │    ├──────────────────────┤
│ Carlos│c@ma.com│ Team   │ $49│    │ María López          │
└─────┴──────────┴────────┴────┘    │ Free · $0/mes        │
                                    │ m@mail.com           │
Todas las columnas visibles         ├──────────────────────┤
                                    │ Carlos Ruiz          │
                                    │ Team · $49/mes       │
                                    └──────────────────────┘
                                    Columnas → stacked por item
```

**Acciones:**

```
DESKTOP — Hover para acciones:       MOBILE — Swipe o long press:
┌──────────────────────────────┐    ┌──────────────────────────┐
│ Item  │           [✏️] [🗑]  │    │ ←← Swipe                 │
│       │          (on hover)  │    │ Item │ [Editar] [Eliminar]│
└──────────────────────────────┘    └──────────────────────────┘

DESKTOP — Right click:               MOBILE — Long press:
  Right click → Context menu          Long press → Action sheet
  ┌──────────┐                        ┌──────────────────────┐
  │ Editar   │                        │ Editar               │
  │ Duplicar │                        │ Duplicar             │
  │ Eliminar │                        │ Compartir            │
  └──────────┘                        │ Eliminar             │
                                      └──────────────────────┘
```

### 8.3 Touch vs Pointer

```
POINTER (mouse):                     TOUCH (dedo):
  → Precisión: ~1px                  → Precisión: ~7mm (44px)
  → Hover disponible                 → NO hay hover
  → Right click                      → Long press
  → Double click                     → Double tap
  → Drag preciso                     → Swipe gestures
  → Scroll wheel                     → Scroll momentum
  → Cursor cambia (pointer, grab)    → Sin cursor

IMPLICACIONES:
  → Touch targets: mínimo 44×44px (vs 24px en desktop)
  → Sin hover: acciones siempre visibles o con alternativa
  → Gestos: swipe, pinch, rotate son nativos de touch
  → Fat finger: espacio entre targets para evitar taps accidentales
  → Thumb zone: contenido importante al alcance del pulgar

     ┌───────────────────┐
     │  ░░ Difícil  ░░   │
     │  ░░ alcanzar ░░   │
     │                   │
     │  ▒▒ Alcanzable ▒▒ │
     │                   │
     │  ██ Zona del  ██  │
     │  ██ pulgar    ██  │
     │  ██ (fácil)   ██  │
     └───────────────────┘
       Mano derecha
```

---

## 9. Nivel intermedio / avanzado

### 9.1 Composición de múltiples patrones

**Intuición**
Las interfaces reales no usan un solo patrón. Un checkout combina multi-step + progressive disclosure + inline validation + loading states + error handling. La habilidad avanzada es componer patrones de manera coherente.

```
EJEMPLO: Settings page compuesta

PATRONES INVOLUCRADOS:
  1. Sidebar navigation (secciones de settings)
  2. Tab navigation (sub-secciones)
  3. Form layout (campos de configuración)
  4. Inline editing (cambios rápidos)
  5. Toast feedback (confirmación de guardado)
  6. Confirmation modal (acciones destructivas)
  7. Progressive disclosure (opciones avanzadas)

┌──────────┬─────────────────────────────────────────┐
│          │  [General]  [Seguridad]  [Notificaciones]│ ← Tabs
│ Cuenta   │  ─────────                               │
│ Equipo   │                                          │
│ Billing  │  Nombre de empresa                       │ ← Inline edit
│ API      │  ┌─────────────────────────┐  ✏️        │
│ Seguridad│  │ Acme Corp               │             │
│          │  └─────────────────────────┘             │
│          │                                          │
│          │  Zona horaria                            │ ← Form field
│          │  ┌─────────────────────────┐             │
│          │  │ UTC-6 (Mexico City)  ▾  │             │
│          │  └─────────────────────────┘             │
│          │                                          │
│          │  [▶ Opciones avanzadas]                  │ ← Progressive
│          │                                          │    disclosure
│          │                           [Guardar]      │
│          │                                          │
│          │  ───────────────────────────────────      │
│          │  Zona de peligro                         │
│          │  [Eliminar organización]                  │ ← Confirmation
│          │                                          │    modal
└──────────┴─────────────────────────────────────────┘
    ↑ Sidebar
```

### 9.2 Creación de patrones propios

**Cuándo crear un patrón nuevo:**
- No existe un patrón estándar para tu problema
- Los patrones existentes crean más fricción que solución
- Tu producto tiene una interacción única y recurrente
- Has validado la solución con usuarios

**Proceso:**

```
1. IDENTIFICAR EL PROBLEMA RECURRENTE
   "Nuestros usuarios necesitan comparar 3-4 planes
    con 20+ features cada uno"

2. INVESTIGAR SOLUCIONES EXISTENTES
   → Pricing tables → Funcionan con 3-4 planes y 5-10 features
   → Comparison matrix → Funciona pero es densa con 20+ features
   → Tabs por plan → No permite comparación directa

3. DISEÑAR LA SOLUCIÓN
   → Hybrid: pricing cards con expand/collapse por categoría
   → Top row: plans con precio y CTA
   → Categorías colapsables con features
   → Highlight de diferencias entre planes

4. VALIDAR CON USUARIOS
   → Testear con 5+ usuarios reales
   → ¿Completan la tarea? ¿Entienden la interacción?

5. DOCUMENTAR COMO PATRÓN
   → Problema, contexto, solución, trade-offs
   → Agregar al design system

6. ITERAR
   → Mejorar basándose en datos y feedback
```

### 9.3 Adaptación a productos complejos (SaaS / Enterprise)

```
DESAFÍOS DE UX EN ENTERPRISE:

1. DENSIDAD DE INFORMACIÓN
   → Usuarios expertos necesitan VER muchos datos a la vez
   → Solución: tablas densas + personalizables, NO simplificar
   → Permitir personalización de vistas (columnas, filtros guardados)

2. ROLES Y PERMISOS
   → La misma pantalla se ve diferente según el rol
   → Solución: progressive disclosure por permisos
   → Admin ve todo, Viewer ve solo lectura

3. FLUJOS LARGOS
   → Procesos de 10-20 pasos (aprobaciones, workflows)
   → Solución: progress trackers + autosave + resume capability

4. DATOS RELACIONADOS
   → Todo está conectado (cliente → pedidos → facturas → envíos)
   → Solución: master-detail, breadcrumbs profundos, drill-down

5. LEGACY MENTAL MODELS
   → Usuarios llevan años con la herramienta anterior
   → Solución: migración gradual, shortcuts familiares, modo classic
```

### 9.4 Trade-offs entre patrones

```
EJEMPLO: ¿Cómo muestro una lista de 500 items?

OPCIÓN A: PAGINATION
  ✅ Predecible, posición compartible, accesible
  ❌ Más clicks, pierde contexto al cambiar página

OPCIÓN B: INFINITE SCROLL
  ✅ Fluido, menos clicks, bueno para browsing
  ❌ No puede llegar al footer, posición no compartible

OPCIÓN C: LOAD MORE BUTTON
  ✅ Balance entre ambos, usuario controla
  ❌ Más clicks que infinite scroll

OPCIÓN D: VIRTUALIZED LIST
  ✅ Performance con 10,000+ items, fluido
  ❌ Implementación compleja, scroll bar buggy

DECISIÓN DEPENDE DE:
  → ¿El usuario busca algo específico? → Pagination + search
  → ¿El usuario explora/browsea? → Infinite scroll
  → ¿Necesita llegar al footer? → Pagination o Load more
  → ¿10,000+ items? → Virtualized list
```

### 9.5 Innovación sin romper estándares

```
REGLA: Innova en el VALOR, no en la INTERACCIÓN.

❌ INNOVAR EN INTERACCIÓN:           ✅ INNOVAR EN VALOR:

  "Inventamos un nuevo tipo           "Usamos un patrón conocido
   de menú que funciona con            (search + autocomplete)
   gestos circulares"                  pero mostramos resultados
                                       con AI que entiende
  → Nadie sabe usarlo                 intención, no solo keywords"
  → Curva de aprendizaje alta
  → Ego del diseñador                → Interacción familiar
                                     → Resultado superior
                                     → Valor real

FÓRMULA:
  Interacción familiar + Tecnología nueva = Innovación real
  Interacción nueva + Tecnología nueva = Confusión
```

---

## 10. Casos prácticos

### 10.1 Dashboard — Composición de patrones

```
BRIEF: Dashboard para un SaaS de gestión de proyectos.
USUARIOS: Project managers, intermedio-avanzado.
PATRONES USADOS:

┌──────────┬──────────────────────────────────────────────────┐
│          │  Buen día, Juan     [🔍 Cmd+K] [🔔 3] [👤]     │
│ 📊 Home  ├──────────────────────────────────────────────────┤
│          │                                                  │
│ 📁 Proj  │  KPI CARDS (patrón: summary overview)            │
│  ├ Alpha │  ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  ├ Beta  │  │ Proyectos│ │ Tareas   │ │ Deadlines│         │
│  └ Gamma │  │   12     │ │  45/120  │ │  3 hoy   │         │
│          │  │  +2 mes  │ │  37.5%   │ │  ⚠️ 2 late│         │
│ 👥 Team  │  └──────────┘ └──────────┘ └──────────┘         │
│ 📅 Cal   │                                                  │
│ 📈 Report│  ACTIVIDAD RECIENTE (patrón: feed)               │
│          │  ─────────────────────────                       │
│ ─────    │  ● Juan cerró "Bug fix login"         Hace 1h   │
│ ⚙ Config │  ● María creó "Sprint 24 planning"    Hace 3h   │
│          │  ● Deploy v2.4.1 completado           Hace 5h   │
│          │  [Ver toda la actividad →]                       │
│          │                                                  │
│          │  MIS TAREAS (patrón: personal task list)         │
│          │  ─────────────                                   │
│          │  ☐ Revisar PR #234          ⚡ Alta    Hoy       │
│          │  ☐ Preparar demo            🔵 Media   Mañana    │
│          │  ☑ Actualizar docs          🟢 Baja    Ayer ✓    │
│          │                                                  │
└──────────┴──────────────────────────────────────────────────┘

PATRONES COMPUESTOS:
  1. Sidebar navigation → Acceso persistente a secciones
  2. Command palette (Cmd+K) → Power users, búsqueda rápida
  3. KPI cards → Resumen ejecutivo
  4. Activity feed → Conciencia de equipo
  5. Task list → Acción personal inmediata
  6. Notification badge → Atención selectiva
  7. Drill-down → Click en KPI → detalle
```

### 10.2 Onboarding optimizado

```
BRIEF: Onboarding para una app de email marketing (SaaS).
OBJETIVO: Llevar al usuario de "cuenta creada" a "primer email enviado".

ANTI-PATRÓN (❌):
  → 10 slides de introducción antes de dejar usar la app
  → El usuario cierra todo sin leer
  → No sabe qué hacer después

PATRÓN OPTIMIZADO (✅):
  Combina: Checklist + Empty state + Progressive disclosure

  PASO 1: Post-registro → Checklist mínimo
  ┌──────────────────────────────────────────┐
  │  🎉 ¡Bienvenido! Empecemos.             │
  │                                          │
  │  Para enviar tu primer email:            │
  │  ✓ Crear cuenta                          │
  │  ○ Importar contactos                    │
  │  ○ Crear tu primer email                 │
  │  ○ Enviar                                │
  │                                          │
  │  [Importar contactos →]                  │
  └──────────────────────────────────────────┘

  PASO 2: Empty state como guía
  ┌──────────────────────────────────────────┐
  │  📧 Emails                               │
  │                                          │
  │  Aún no tienes emails.                   │
  │                                          │
  │  Crea tu primer email con nuestro        │
  │  editor visual. Sin código necesario.    │
  │                                          │
  │  [+ Crear email]  [Ver plantillas]       │
  └──────────────────────────────────────────┘

  PASO 3: Contextual tips (solo la primera vez)
  ┌──────────────────────────────────────────┐
  │  Editor de email                         │
  │  ┌────────────────────────────────────┐  │
  │  │ 💡 Arrastra bloques desde la      │  │
  │  │    barra lateral para construir   │  │
  │  │    tu email.     [Entendido]      │  │
  │  └────────────────────────────────────┘  │
  │                                          │
  │  [Bloques]  │  Preview del email         │
  │  ──────────│                             │
  │  📝 Texto   │                             │
  │  🖼 Imagen  │                             │
  │  🔘 Botón   │                             │
  └──────────────────────────────────────────┘

RESULTADO:
  → El usuario hace, no lee
  → Cada paso tiene UN objetivo claro
  → El progreso es visible
  → La app se enseña a sí misma
```

### 10.3 Sistema de navegación completo

```
BRIEF: App de e-commerce con 200+ categorías, búsqueda y cuenta.

DESKTOP:
┌──────────────────────────────────────────────────────────────┐
│  [Logo]  Categorías ▾  Ofertas  Nuevos  [🔍 Buscar...]  👤 🛒│
├──────────────────────────────────────────────────────────────┤
│  Mega menu (al hover en Categorías):                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Electrónica    Ropa          Hogar        Deportes     │  │
│  │ ──────────     ──────        ──────       ──────       │  │
│  │ Laptops        Hombre        Cocina       Running      │  │
│  │ Phones         Mujer         Baño         Gym          │  │
│  │ Audio          Niños         Jardín       Outdoor      │  │
│  │ Gaming         Accesorios    Iluminación  Ciclismo     │  │
│  │                                                        │  │
│  │ [Ver todas las categorías →]                           │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Breadcrumbs: Inicio > Electrónica > Laptops > Gaming        │
│                                                              │
│  [Filtros sidebar]  [Grid de productos con cards]            │
└──────────────────────────────────────────────────────────────┘

MOBILE:
┌────────────────────────┐
│ ☰  [Logo]   🔍  🛒    │  ← Top bar: hamburger + search + cart
├────────────────────────┤
│                        │
│  Contenido principal   │
│  (full width)          │
│                        │
│  Cards en 2 columnas   │
│  ┌──────┐ ┌──────┐    │
│  │  📷  │ │  📷  │    │
│  │ $299 │ │ $199 │    │
│  └──────┘ └──────┘    │
│                        │
├────────────────────────┤
│ 🏠   📂   🔍   👤    │  ← Bottom nav: Home, Categories,
└────────────────────────┘    Search, Account

HAMBURGER → Drill-down categories:
┌────────────────────────┐
│ ← Categorías           │
├────────────────────────┤
│ Electrónica        →   │
│ Ropa               →   │  ← Primer nivel
│ Hogar              →   │
│ Deportes           →   │
└────────────────────────┘
        │ Click
        ▼
┌────────────────────────┐
│ ← Electrónica          │
├────────────────────────┤
│ Laptops            →   │
│ Phones             →   │  ← Segundo nivel
│ Audio              →   │
│ Gaming             →   │
└────────────────────────┘

PATRONES USADOS:
  Desktop: Top nav + Mega menu + Breadcrumbs + Sidebar filters
  Mobile: Hamburger + Bottom nav + Drill-down + Floating search
  Ambos: Search (autocomplete), Cards, Pagination
```

### 10.4 Comparación: Bien vs Mal uso de patrones

```
CASO: Página de pricing

❌ MAL USO:

  ┌────────────────────────────────────────────────────────┐
  │  ← → Carousel de planes (auto-rotate cada 3s)          │
  │                                                        │
  │  ┌──────────────────────────────────────────────────┐  │
  │  │  PLAN PRO                                        │  │
  │  │  $29/mes                                         │  │
  │  │  • Feature 1 • Feature 2 • Feature 3             │  │
  │  │  [Comprar] [Info] [Comparar] [Chat] [Demo]       │  │
  │  │         (5 botones, ¿cuál presiono?)             │  │
  │  └──────────────────────────────────────────────────┘  │
  │         ● ○ ○ ← dots del carousel                     │
  │                                                        │
  │  Popup: "¡OFERTA! 20% OFF si compras HOY" [X]         │
  │                                                        │
  └────────────────────────────────────────────────────────┘

  Problemas:
  → Carousel: el usuario no ve los otros planes
  → Auto-rotate: distrae, pierde control
  → 5 CTAs: sin jerarquía, parálisis de decisión
  → Popup: interrumpe, patrón oscuro
  → No puede comparar planes

✅ BUEN USO:

  ┌──────────────────────────────────────────────────────────┐
  │  Elige tu plan          [Mensual] [Anual -20%]          │
  │                                                          │
  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
  │  │  FREE    │  │  PRO ⭐  │  │  TEAM    │              │
  │  │          │  │ Popular   │  │          │              │
  │  │  $0/mes  │  │  $29/mes  │  │  $49/mes │              │
  │  │          │  │           │  │  p/user  │              │
  │  │ 3 proyect│  │ ∞ proyect │  │ ∞ proyect│              │
  │  │ 1 GB     │  │ 50 GB     │  │ 500 GB   │              │
  │  │ Email    │  │ Email+Chat│  │ Priority │              │
  │  │          │  │ API access│  │ SSO      │              │
  │  │          │  │ Analytics │  │ Admin    │              │
  │  │          │  │           │  │          │              │
  │  │[Empezar] │  │[Probar 14d]│ │[Contactar]│             │
  │  │ gratis   │  │  gratis   │  │ ventas   │              │
  │  └──────────┘  └──────────┘  └──────────┘              │
  │                                                          │
  │  [Comparar todos los features ▼]                        │
  └──────────────────────────────────────────────────────────┘

  Aciertos:
  → Todos los planes visibles y comparables
  → Plan más popular destacado (⭐ Popular)
  → 1 CTA por plan con texto específico
  → Toggle mensual/anual
  → Comparación detallada opcional (progressive disclosure)
  → Sin carousel, sin popup, sin dark patterns
```

---

## Cheat Sheet — Design Patterns

```
┌──────────────────────────────────────────────────────────────────┐
│                   DESIGN PATTERNS CHEAT SHEET                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ESTRUCTURA DE UN PATRÓN:                                        │
│  Problema → Contexto → Solución → Trade-offs                     │
│                                                                  │
│  NAVEGACIÓN:                                                     │
│  Top nav → 3-7 items, global, desktop                            │
│  Sidebar → Dashboard, jerárquica, 5+ secciones                   │
│  Tabs → 2-7 items, mismo nivel, dentro de página                 │
│  Breadcrumbs → 3+ niveles jerárquicos                            │
│  Hamburger → Mobile, nav secundaria                              │
│  Bottom nav → Mobile, 3-5 items principales                      │
│                                                                  │
│  CONTENIDO:                                                      │
│  Cards → Items visuales independientes                           │
│  Tables → Datos comparables multi-atributo                       │
│  Lists → Items simples, 1-2 atributos                            │
│  Pagination → Búsqueda específica, posición importa              │
│  Infinite scroll → Discovery, browsing, feeds                    │
│  Load more → Balance entre ambos                                 │
│                                                                  │
│  INTERACCIÓN:                                                    │
│  Modal → Confirmación destructiva, decisión obligatoria          │
│  Dropdown → Acciones en item, selección de lista                 │
│  Tooltip → Info complementaria breve (no en mobile)              │
│  Accordion → Contenido largo scaneable                           │
│  Tabs → Contenido del mismo nivel, sin comparar                  │
│                                                                  │
│  ENTRADA DE DATOS:                                               │
│  Form → Captura estructurada, mínimos campos                    │
│  Multi-step → 6+ campos, reducir percepción de complejidad      │
│  Inline edit → Cambios rápidos, datos en contexto               │
│  Autocomplete → 15+ opciones, búsqueda en lista                 │
│  Search → Discovery, filtrado, command palette                   │
│                                                                  │
│  FEEDBACK:                                                       │
│  Toast → Confirmación no crítica, reversible                     │
│  Alert → Información importante, requiere atención               │
│  Skeleton → Carga 1-5s, preview de estructura                   │
│  Spinner → Carga < 1s, espera breve                             │
│  Progress bar → Carga > 5s, proceso largo                       │
│  Empty state → Sin datos + CTA para crear                       │
│  Error → Inline > Banner > Toast > Full page                    │
│                                                                  │
│  COMPORTAMIENTO:                                                 │
│  Progressive disclosure → Revelar complejidad gradualmente       │
│  Recognition > Recall → Mostrar opciones, no pedir memoria      │
│  Smart defaults → Pre-configurar lo más común                   │
│  Constraints → Prevenir errores en vez de corregirlos           │
│  Undo > Confirm → Menos fricción, más reversible               │
│                                                                  │
│  ANTI-PATRONES:                                                  │
│  ❌ Modal para todo              ❌ Carousel auto-rotate         │
│  ❌ Hamburger en desktop         ❌ Infinite scroll + footer     │
│  ❌ Iconos sin label             ❌ Confirm shaming              │
│  ❌ Copiar sin entender          ❌ Innovar la interacción       │
│                                                                  │
│  DECISIÓN:                                                       │
│  Contexto > Regla rígida                                         │
│  Familiar > Novedoso                                             │
│  Simple > Complejo                                               │
│  Reversible > Confirmable                                        │
│  Validar > Asumir                                                │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Errores Comunes y Decisiones Incorrectas

| # | Error | Por qué es malo | Solución |
|---|---|---|---|
| 1 | Usar modal para información no crítica | Interrumpe el flujo, fatiga de cierre | Toast, inline message o banner |
| 2 | Carousel de contenido importante | < 1% CTR en slides 2+ | Cards estáticas comparables |
| 3 | Hamburger menu en desktop | Oculta navegación innecesariamente | Nav visible con 3-7 items |
| 4 | Infinite scroll en catálogos con búsqueda | No puede volver a un item específico | Pagination + search |
| 5 | Copiar patrones de apps populares sin analizar contexto | Tu producto tiene necesidades diferentes | Evaluar problema → contexto → solución |
| 6 | Múltiples CTAs del mismo nivel | Parálisis de decisión | 1 primary + 1 secondary máximo |
| 7 | Tooltip como contenido esencial | No funciona en mobile (no hay hover) | Texto visible o helper text |
| 8 | Loading spinner para cargas > 3s | Se siente como que se colgó | Skeleton screen o progress bar |
| 9 | Empty state sin CTA | El usuario no sabe qué hacer | Ilustración + mensaje + acción |
| 10 | Innovar en la interacción en vez del valor | Curva de aprendizaje, confusión | Interacción familiar + valor nuevo |

---

> **Referencia rápida — Decisiones por contexto:**
> - **E-commerce:** Cards + Pagination + Filters + Breadcrumbs + Mega menu
> - **SaaS Dashboard:** Sidebar + Tables + CRUD + Toasts + Inline edit
> - **Content/Blog:** Top nav + Cards/Feed + Infinite scroll + Search
> - **Mobile App:** Bottom tabs + Cards + Swipe actions + Pull to refresh
> - **Enterprise:** Dense tables + Sidebar + Multi-step + Command palette
