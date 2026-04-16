# Mobile Design — Módulo Completo

> **Módulo:** Diseño de Interfaces Móviles
> **Nivel:** Básico → Intermedio → Avanzado
> **Objetivo:** Diseñar experiencias móviles eficientes, intuitivas y escalables, considerando las restricciones reales del contexto móvil y las expectativas de los usuarios.

---

## Tabla de Contenidos

1. [Introducción a Mobile Design](#1-introducción-a-mobile-design)
2. [Fundamentos de UX en Mobile](#2-fundamentos-de-ux-en-mobile)
3. [Layouts Móviles](#3-layouts-móviles)
4. [Navegación en Mobile](#4-navegación-en-mobile)
5. [Componentes Móviles](#5-componentes-móviles)
6. [Interacciones y Feedback](#6-interacciones-y-feedback)
7. [Formularios en Mobile](#7-formularios-en-mobile)
8. [Accesibilidad en Mobile](#8-accesibilidad-en-mobile)
9. [Responsive vs Adaptive Design](#9-responsive-vs-adaptive-design)
10. [Design Systems en Mobile](#10-design-systems-en-mobile)
11. [Performance y Optimización](#11-performance-y-optimización)
12. [Testing y Validación](#12-testing-y-validación)
13. [Nivel Intermedio / Avanzado](#13-nivel-intermedio--avanzado)

---

## 1. Introducción a Mobile Design

### 1.1 ¿Qué es Mobile Design?

**Intuición**
Mobile design es diseñar experiencias digitales para dispositivos que la gente lleva en el bolsillo, usa con una mano, mira durante 3 segundos entre actividades, y opera con el dedo gordo sobre una pantalla de 6 pulgadas. No es "desktop chiquito". Es un medio completamente diferente con sus propias reglas, restricciones y oportunidades.

**Estructura formal**
Mobile design es la disciplina de crear interfaces y experiencias optimizadas para dispositivos móviles (smartphones y tablets), considerando sus restricciones físicas (pantalla pequeña, input táctil), contextuales (movilidad, atención fragmentada) y técnicas (conectividad variable, batería limitada, diversidad de dispositivos).

```
DESKTOP                               MOBILE
────────────────────                   ────────────────────
Pantalla grande (1920px+)              Pantalla pequeña (375-428px)
Mouse + teclado (precisión)            Dedos (imprecisión)
Atención sostenida                     Atención fragmentada
Sentado, estable                       En movimiento
WiFi estable                           3G/4G/5G variable
Multitarea (ventanas)                  Una app a la vez
Hover disponible                       Sin hover
```

### 1.2 Diferencias clave entre mobile y desktop

| Dimensión | Desktop | Mobile |
|---|---|---|
| **Pantalla** | 1024-2560px ancho | 320-428px ancho |
| **Input** | Mouse (1px precisión) | Dedo (~7mm contacto, ~44px target) |
| **Hover** | Sí | No |
| **Atención** | Enfocada, sesiones largas | Fragmentada, sesiones cortas (~3 min) |
| **Contexto** | Oficina, escritorio | Caminando, transporte, fila, cama |
| **Orientación** | Landscape fija | Portrait (95%), landscape (5%) |
| **Conectividad** | WiFi estable | Variable (3G → 5G → sin señal) |
| **Teclado** | Siempre disponible | Virtual, ocupa 50% de la pantalla |
| **Navegación** | Menú visible, breadcrumbs | Bottom nav, gestos, stack |
| **Scroll** | Vertical + horizontal | Vertical (casi exclusivo) |

### 1.3 Limitaciones y oportunidades

**Limitaciones que son oportunidades:**

```
LIMITACIÓN                           OPORTUNIDAD
──────────────────────               ──────────────────────
Pantalla pequeña                     Foco: muestra solo lo esencial
                                     → Mejor priorización de contenido

Interacción táctil                   Gestos naturales e intuitivos
                                     → Swipe, pinch, tap feel natural

Atención fragmentada                 Diseño para micro-momentos
                                     → Completar tareas en < 30 seg

Movilidad                            Contexto real del usuario
                                     → GPS, cámara, acelerómetro, NFC

Conectividad variable                Diseño offline-first
                                     → Experiencia resiliente y rápida

Una app a la vez                     Inmersión total
                                     → Sin distracciones de otras ventanas
```

### 1.4 Enfoque mobile-first

**Intuición**
Mobile-first significa diseñar primero para la pantalla más pequeña y las restricciones más severas. Si funciona en mobile, adaptarlo a desktop es agregar espacio y features. Si diseñas para desktop primero, adaptarlo a mobile es quitar cosas, y siempre queda peor.

```
❌ DESKTOP-FIRST (quitar):          ✅ MOBILE-FIRST (agregar):

Desktop → Tablet → Mobile            Mobile → Tablet → Desktop
┌─────────────────────┐              ┌────────┐
│ Nav │ Content │ Side│              │Content │
│     │ + Side  │ bar │              │        │
│     │ + Extra │     │              │        │
└─────────────────────┘              └────────┘
        │                                   │
        ▼ ¿Qué quito?                       ▼ ¿Qué agrego?
┌─────────────┐                     ┌─────────────────┐
│ ☰  Content  │                     │ Nav  │ Content  │
│ (side oculto)│                    │      │ + Side   │
│ (extra gone)│                     └─────────────────┘
└─────────────┘                             │
                                            ▼ ¿Qué agrego?
La experiencia se siente            ┌─────────────────────┐
"recortada" y forzada               │ Nav │ Content │ Side│
                                    └─────────────────────┘
                                    La experiencia se siente
                                    "expandida" y natural
```

**En CSS:**

```css
/* ✅ Mobile-first: base = mobile, luego escala */
.container {
  padding: 16px;                   /* Mobile default */
  display: flex;
  flex-direction: column;
}

@media (min-width: 768px) {        /* Tablet: agrega */
  .container {
    padding: 24px;
    flex-direction: row;
  }
}

@media (min-width: 1024px) {       /* Desktop: agrega más */
  .container {
    padding: 32px;
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

---

## 2. Fundamentos de UX en Mobile

### 2.1 Ergonomía: uso con una mano

**Intuición**
La mayoría de las personas usan el teléfono con una sola mano. El pulgar es el dedo dominante. Su alcance define qué es fácil, posible o difícil de tocar.

**Datos:**
- 49% de usuarios sostienen el teléfono con una mano (Steven Hoober, 2013/2020)
- 36% usan el pulgar como input principal con dos manos (cradle)
- 15% usan dos manos con ambos pulgares

### 2.2 Thumb zone (zonas de alcance)

```
MANO DERECHA:                      MANO IZQUIERDA:

┌───────────────────────┐          ┌───────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░ │          │ ░░░░░░░░░░░░░░░░░░░░ │
│ ░░ DIFÍCIL ░░░░░░░░░ │          │ ░░░░░░░░░░ DIFÍCIL ░░ │
│ ░░░░░░░░░░░░░░░░░░░░ │          │ ░░░░░░░░░░░░░░░░░░░░ │
│                       │          │                       │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │          │ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
│ ▒▒ ALCANZABLE ▒▒▒▒▒▒ │          │ ▒▒▒▒▒▒ ALCANZABLE ▒▒ │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │          │ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
│                       │          │                       │
│ ████████████████████  │          │ ████████████████████  │
│ ██ ZONA NATURAL ████  │          │ ████ ZONA NATURAL ██  │
│ ██ DEL PULGAR ██████  │          │ ██████ DEL PULGAR ██  │
│ ████████████████████  │          │ ████████████████████  │
└───────────────────────┘          └───────────────────────┘

IMPLICACIONES PARA TU DISEÑO:

  ZONA NATURAL (abajo)     → Acciones primarias, nav, CTAs
  ZONA ALCANZABLE (medio)  → Contenido principal, listas
  ZONA DIFÍCIL (arriba)    → Info secundaria, título, menú (no acciones)
```

**Aplicación práctica:**

```
❌ MAL: CTA arriba                   ✅ BIEN: CTA abajo

┌───────────────────────┐           ┌───────────────────────┐
│ [Enviar pedido]  ← difícil       │ ← Resumen de compra   │
│                       │           │                       │
│ Resumen de compra     │           │ Producto A    $29.99  │
│                       │           │ Producto B    $49.99  │
│ Producto A    $29.99  │           │ Envío          $5.99  │
│ Producto B    $49.99  │           │ ─────────────────     │
│ Envío          $5.99  │           │ Total         $85.97  │
│ ─────────────────     │           │                       │
│ Total         $85.97  │           │ ┌─────────────────┐   │
│                       │           │ │  Enviar pedido  │   │ ← natural
└───────────────────────┘           │ └─────────────────┘   │
                                    └───────────────────────┘
```

### 2.3 Jerarquía de contenido

**En mobile, la jerarquía no es solo visual, es temporal.** El usuario ve primero lo que está arriba; lo de abajo puede que nunca lo vea.

```
PRIORIDAD DE CONTENIDO EN MOBILE:

  ┌─────────────────────┐  ← Lo que ve sin scroll
  │                     │     (above the fold)
  │  PRIORIDAD 1        │     → Título, contexto, CTA principal
  │  Lo más importante  │
  │                     │
  ├─────────────────────┤  ← Primer scroll
  │                     │
  │  PRIORIDAD 2        │     → Contenido de soporte
  │  Detalle relevante  │
  │                     │
  ├─────────────────────┤  ← Segundo scroll
  │                     │
  │  PRIORIDAD 3        │     → Info secundaria, footer
  │  "Nice to have"     │
  │                     │
  └─────────────────────┘

REGLA: Si solo pudieran ver los primeros 600px,
       ¿entenderían de qué trata la pantalla y qué hacer?
```

### 2.4 Reducción de carga cognitiva

```
PRINCIPIOS PARA MOBILE:

1. UNA TAREA POR PANTALLA
   ❌ Pantalla que hace registro + login + info + promo
   ✅ Pantalla de registro. Punto.

2. MÁXIMO 3-5 OPCIONES VISIBLES
   ❌ 10 botones en la pantalla
   ✅ 3 opciones principales + "Más" si necesario

3. PROGRESO CLARO
   ❌ "Rellena este formulario"
   ✅ "Paso 2 de 3: Tu dirección"

4. RECONOCIMIENTO SOBRE MEMORIA
   ❌ "Ingresa el código de tu pedido"
   ✅ Lista de pedidos recientes con preview

5. ACCIONES REVERSIBLES
   ❌ "¿Seguro que deseas eliminar?"
   ✅ (elimina) → "Eliminado. [Deshacer]"
```

### 2.5 Velocidad y simplicidad

```
DATO: El 53% de visitas mobile se abandonan si la página
      tarda más de 3 segundos en cargar (Google, 2018).

DATO: La sesión mobile promedio dura ~72 segundos.

DATO: El usuario mobile toma decisiones en ~3-5 segundos.

IMPLICACIÓN:
  → Cada pantalla debe comunicar su propósito en < 3 segundos
  → Cada tarea debe completarse en < 3 taps si es posible
  → La carga percibida debe ser < 1 segundo
```

---

## 3. Layouts Móviles

### 3.1 Grid systems en mobile

**Intuición**
En desktop usas 12 columnas. En mobile usas 4. Parece poco, pero en 375px de ancho, 4 columnas con márgenes es todo lo que necesitas para crear layouts limpios y consistentes.

```
GRID MOBILE (4 columnas):

  16px                              16px
  ←──→                              ←──→
  margin  col   gap  col   gap  col   gap  col  margin
  ├─────┤█████├───┤█████├───┤█████├───┤█████├─────┤
         ←───→      ←───→
          col        gap
         ~72px       16px

  Ancho total: 375px (iPhone 14/15)
  Margins: 16px × 2 = 32px
  Gaps: 16px × 3 = 48px
  Columnas: (375 - 32 - 48) / 4 = ~73.75px cada una


GRID MOBILE GRANDE (6 columnas):

  Para tablets o phones grandes (> 428px):
  6 columnas con margins de 24px y gaps de 16px.


GRID TABLET (8 columnas):

  Para iPads y tablets (768px+):
  8 columnas con margins de 32px y gaps de 24px.
```

**Aplicación práctica — Uso de columnas:**

```
4 COLUMNAS → Contenido mobile

  FULL WIDTH (4 cols):           2+2 SPLIT:
  ┌─────────────────────┐       ┌──────────┬──────────┐
  │  Hero image / Card  │       │  Card A  │  Card B  │
  │                     │       │          │          │
  └─────────────────────┘       └──────────┴──────────┘
  → Texto, CTAs, forms           → Grid de productos, galería

  3+1 SPLIT:                     1+2+1 SPLIT:
  ┌───────────────┬─────┐       ┌────┬──────────┬────┐
  │  Contenido    │ Ico │       │ Ic │  Texto   │ → │
  │  principal    │     │       │    │          │    │
  └───────────────┴─────┘       └────┴──────────┴────┘
  → Lista con acción             → List items con ícono
```

### 3.2 Spacing adaptativo

```
ESCALA DE SPACING PARA MOBILE:

  4px  → Mínimo (entre ícono y label)
  8px  → Tight (entre elementos relacionados)
  12px → Compact (padding interno de componentes)
  16px → Base (margins, gaps, padding estándar)
  24px → Loose (entre secciones menores)
  32px → Section (entre grupos de contenido)
  48px → Large section (entre secciones principales)

COMPARACIÓN:

  ❌ SPACING DESKTOP EN MOBILE:     ✅ SPACING ADAPTATIVO:

  ┌─────────────────────┐           ┌─────────────────────┐
  │                     │ ← 64px    │                     │ ← 24px
  │  Título             │           │  Título             │
  │                     │ ← 32px    │                     │ ← 16px
  │  Descripción...     │           │  Descripción...     │
  │                     │ ← 48px    │                     │ ← 24px
  │  [  Acción  ]       │           │  [  Acción  ]       │
  │                     │ ← 64px    │                     │ ← 32px
  └─────────────────────┘           └─────────────────────┘

  Demasiado espacio,                Espacio proporcionado,
  contenido se pierde               contenido accesible
  below the fold                    sin scroll excesivo
```

### 3.3 Safe areas

**Intuición**
Los teléfonos modernos tienen notch, dynamic island, bordes redondeados y barras del sistema. Tu contenido debe respetar estas áreas para no quedar oculto o recortado.

```
iPHONE CON NOTCH/DYNAMIC ISLAND:

  ┌─────────────────────────┐
  │ ░░░░░ STATUS BAR ░░░░░ │  ← 59px (con dynamic island)
  │ ░░░░░░░░░░░░░░░░░░░░░ │     No colocar contenido aquí
  ├─────────────────────────┤
  │                         │
  │   SAFE AREA             │  ← Tu contenido va aquí
  │   (tu contenido)        │
  │                         │
  │                         │
  │                         │
  │                         │
  ├─────────────────────────┤
  │ ░░ HOME INDICATOR ░░░░ │  ← 34px
  │ ░░░░░░░░░░░░░░░░░░░░░ │     No colocar botones aquí
  └─────────────────────────┘


ANDROID CON GESTURE NAV:

  ┌─────────────────────────┐
  │ ░░ STATUS BAR ░░░░░░░░ │  ← 24-48px (varía por device)
  ├─────────────────────────┤
  │                         │
  │   SAFE AREA             │
  │                         │
  │                         │
  ├─────────────────────────┤
  │ ░░ GESTURE BAR ░░░░░░░ │  ← Indicador de gestos
  └─────────────────────────┘
```

**En CSS:**

```css
/* Respetar safe areas */
.container {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}

/* Bottom nav respetando home indicator */
.bottom-nav {
  position: fixed;
  bottom: 0;
  padding-bottom: env(safe-area-inset-bottom);
}
```

### 3.4 Scroll vertical como patrón principal

```
REGLA: En mobile, el scroll es VERTICAL. Siempre.

  ✅ SCROLL VERTICAL:               ❌ SCROLL HORIZONTAL:
  ┌─────────────────┐               ┌─────────────────┐
  │ Sección 1       │               │ Pág 1 │ Pág 2   │
  │                 │               │       │         │
  │ Sección 2       │               │ ← swipe →       │
  │                 │               │       │         │
  │ Sección 3       │               └─────────────────┘
  │       ↕         │               El usuario no sabe
  └─────────────────┘               que hay más contenido
  Natural, esperado                  a la derecha.

EXCEPCIÓN — Scroll horizontal aceptable:
  → Carousels de imágenes (con indicadores ●○○)
  → Tab overflow (tabs que no caben en pantalla)
  → Listas de chips/tags
  → Historias (Instagram-style)
  → SIEMPRE con indicador visual de que hay más →
```

### 3.5 Diseño basado en bloques

```
MOBILE = BLOQUES APILADOS

  ┌─────────────────────┐
  │ BLOQUE: Header      │
  │ App bar + status     │
  ├─────────────────────┤
  │ BLOQUE: Hero        │
  │ Imagen + título      │
  ├─────────────────────┤
  │ BLOQUE: Acciones    │
  │ CTA + secondary      │
  ├─────────────────────┤
  │ BLOQUE: Contenido   │
  │ Descripción, detalles│
  ├─────────────────────┤
  │ BLOQUE: Relacionados│
  │ Cards horizontales   │
  ├─────────────────────┤
  │ BLOQUE: Footer      │
  │ Links, legal         │
  └─────────────────────┘

Cada bloque:
  → Full width (4 columnas)
  → Responsabilidad única
  → Padding consistente (16px lateral)
  → Separación clara entre bloques (24-32px)
```

---

## 4. Navegación en Mobile

### 4.1 Bottom navigation (Tab bar)

**Problema:** El usuario necesita acceso rápido a las 3-5 secciones principales de la app desde cualquier pantalla.

```
PATRÓN: BOTTOM NAVIGATION

┌─────────────────────────┐
│                         │
│   Contenido principal   │
│                         │
│                         │
│                         │
├─────────────────────────┤
│ 🏠     🔍     ➕     👤 │
│ Home  Search  New  Profile│
└─────────────────────────┘

REGLAS:
  → 3-5 items (NUNCA > 5)
  → Ícono + label (no solo ícono)
  → El tab activo está claramente diferenciado
  → Siempre visible (no se oculta con scroll)
  → La posición está en la thumb zone natural

CUÁNDO USAR:
  → Secciones del mismo nivel jerárquico
  → Acceso frecuente a múltiples áreas
  → Apps consumer (social, e-commerce, fintech)

CUÁNDO NO:
  → > 5 secciones (necesitas otra estructura)
  → Apps con un flujo lineal (checkout, onboarding)
  → Apps con una pantalla principal dominante
```

**Comparación de implementación:**

```
iOS (Tab Bar):                      Android (Navigation Bar):
┌───────────────────────┐           ┌───────────────────────┐
│                       │           │                       │
│                       │           │                       │
├───────────────────────┤           ├───────────────────────┤
│ 🏠    🔍    💬    👤  │           │ 🏠    🔍    💬    👤  │
│ Home Search Chat  Me  │           │ Home Search Chat  Me  │
│       ●               │           │  ●                    │
│                       │           │ ▬▬▬                   │
│  ─────── (home bar)   │           │ (gesture indicator)   │
└───────────────────────┘           └───────────────────────┘
  Labels siempre visibles             Labels opcionales
  Tint color en activo                Indicator bar en activo
  Height: ~49pt + safe area           Height: ~80dp
```

### 4.2 Hamburger menu

```
PATRÓN: HAMBURGER MENU (☰)

┌─────────────────────┐         ┌─────────────────────┐
│ ☰  Mi App    [🔔]  │    →    │ ████████████████████│
│─────────────────────│         │ ███ DRAWER ████████ │
│                     │         │ ███                 │
│  Contenido          │         │ ███ 🏠 Inicio      │
│                     │         │ ███ 📦 Pedidos     │
│                     │         │ ███ 💳 Pagos       │
│                     │         │ ███ ⚙ Configuración│
│                     │         │ ███ ❓ Ayuda       │
│                     │         │ ███                 │
│                     │         │ ███ Cerrar sesión  │
└─────────────────────┘         └─────────────────────┘

CUÁNDO USAR:
  → Navegación secundaria (settings, help, account)
  → > 5 secciones que no caben en bottom nav
  → Combinado con bottom nav (bottom = primario, hamburger = secundario)

CUÁNDO NO:
  → Como única navegación (reduce descubrimiento ~50%)
  → Para las secciones principales más usadas
  → Si tienes ≤ 5 secciones (usa bottom nav directamente)

⚠️ DATO: Los items dentro del hamburger se usan ~50% menos
   que los items visibles en un bottom nav. Lo oculto se ignora.
```

### 4.3 Navigation stack

**Intuición**
En mobile, la navegación funciona como una pila de cartas. Cada pantalla que abres se "apila" encima de la anterior. El botón "atrás" quita la carta de arriba y revela la anterior.

```
PATRÓN: NAVIGATION STACK

Pantalla 1          Pantalla 2          Pantalla 3
(raíz)              (push)              (push)
┌───────────┐       ┌───────────┐       ┌───────────┐
│ Lista de  │  →    │ ← Detalle │  →    │ ← Editar  │
│ productos │       │ Product A │       │ Product A │
│           │       │           │       │           │
│ Product A │       │ Imagen    │       │ Nombre    │
│ Product B │       │ Precio    │       │ [_______] │
│ Product C │       │ Desc.     │       │ Precio    │
│           │       │           │       │ [_______] │
│           │       │ [Editar]  │       │           │
│           │       │           │       │ [Guardar] │
└───────────┘       └───────────┘       └───────────┘
                         ←                    ←
                    (pop / back)         (pop / back)

REGLAS:
  → ← (back arrow) SIEMPRE visible en pantallas secundarias
  → Back = volver a la pantalla anterior (no a home)
  → El título cambia para reflejar la pantalla actual
  → Transición: slide from right (iOS), fade/slide (Android)
  → Profundidad máxima recomendada: 3-4 niveles
```

### 4.4 Cuándo usar cada patrón de navegación

```
¿Cuántas secciones principales tienes?
│
├─ 2-5 → BOTTOM NAVIGATION
│  └─ ¿Hay secciones secundarias?
│     ├─ SÍ → Bottom nav + hamburger drawer
│     └─ NO → Bottom nav solo
│
├─ 5-8 → BOTTOM NAV (principales) + HAMBURGER (resto)
│
├─ > 8 → TAB BAR + CATEGORIES (app tipo marketplace)
│
└─ 1 flujo lineal → NAVIGATION STACK (no necesitas tabs)
   Ej: Checkout, onboarding, camera app

COMBINACIÓN MÁS COMÚN:
  Bottom nav (3-5 secciones principales)
  + Navigation stack dentro de cada sección
  + Hamburger para settings, help, account
```

### 4.5 Back navigation y consistencia

```
BACK BUTTON — EXPECTATIVAS DEL USUARIO:

iOS:
  ← (top-left arrow) = Volver a pantalla anterior
  Swipe from left edge = Volver (gesto)
  No hay back button del sistema

Android:
  ← (top-left arrow) = Volver (in-app)
  ◁ (system back) o swipe from edge = Volver (sistema)
  El back del sistema puede salir de la app

REGLAS:
  1. Back siempre va a la pantalla anterior (previsible)
  2. Si hay cambios sin guardar → confirmar antes de salir
  3. Close (✕) para modales/overlays, ← para stack navigation
  4. Nunca mezclar close y back en la misma posición

  ← Back:     ┌─────────────────────┐
  Para stack   │ ← Detalle producto │  → Vuelve a la lista
               └─────────────────────┘

  ✕ Close:    ┌─────────────────────┐
  Para modals  │ ✕ Filtros           │  → Cierra el overlay
               └─────────────────────┘
```

---

## 5. Componentes Móviles

### 5.1 Botones (tamaño táctil mínimo)

```
TAMAÑOS DE TOUCH TARGET:

  MÍNIMO:      RECOMENDADO:    IDEAL:
  ┌──────┐     ┌────────┐     ┌──────────┐
  │      │     │        │     │          │
  │ 44px │     │  48px  │     │   56px   │
  │      │     │        │     │          │
  └──────┘     └────────┘     └──────────┘
  WCAG AA       Google MD      Primary CTA

  Apple HIG: mínimo 44×44pt
  Material Design: mínimo 48×48dp
  WCAG 2.5.8: mínimo 24×24px (AA), recomendado 44×44


BOTONES EN MOBILE — Layout:

  ❌ MAL:                            ✅ BIEN:
  ┌─────────────────────┐           ┌─────────────────────┐
  │                     │           │                     │
  │  [Guardar][Cancelar]│           │                     │
  │  (pequeños, pegados)│           │  ┌─────────────────┐│
  │                     │           │  │    Guardar       ││ ← Full width
  └─────────────────────┘           │  └─────────────────┘│    56px height
                                    │    Cancelar          │ ← Text link
                                    └─────────────────────┘

REGLA: En mobile, los botones primarios son FULL WIDTH.
  → Más fácil de alcanzar con el pulgar
  → Más claro visualmente
  → Touch target grande
```

### 5.2 Inputs optimizados para mobile

```
REGLAS PARA INPUTS MOBILE:

1. HEIGHT MÍNIMO: 48px (mejor 56px)
2. FONT SIZE: mínimo 16px (< 16px causa zoom en iOS Safari)
3. INPUT TYPE correcto → teclado correcto

   type="email"    → Teclado con @ y .com
   type="tel"      → Teclado numérico de teléfono
   type="number"   → Teclado numérico
   type="url"      → Teclado con .com, /, :
   type="search"   → Teclado con botón "Buscar"
   inputmode="numeric"  → Teclado numérico sin spinners
   inputmode="decimal"  → Numérico con punto decimal

4. AUTOCOMPLETE habilitado:
   autocomplete="name"
   autocomplete="email"
   autocomplete="tel"
   autocomplete="street-address"
   autocomplete="cc-number"


LAYOUT DE INPUT EN MOBILE:

  ┌─────────────────────────────┐
  │ Label                       │  ← Siempre arriba (no inline)
  │ ┌─────────────────────────┐ │
  │ │ Placeholder...     48px │ │  ← Height suficiente
  │ └─────────────────────────┘ │
  │ Helper text                 │  ← Debajo del input
  └─────────────────────────────┘

  ❌ En mobile, NO uses labels inline (al lado del input).
     No hay espacio horizontal. Siempre ENCIMA.
```

### 5.3 Lists y Cards

```
LISTA MOBILE:

┌─────────────────────────────┐
│  👤  Juan García             │
│      juan@mail.com      →   │  ← 48px+ height
├─────────────────────────────┤     Tap target completo
│  👤  María López             │
│      maria@mail.com     →   │
├─────────────────────────────┤
│  👤  Carlos Ruiz             │
│      carlos@mail.com    →   │
└─────────────────────────────┘

  → Full width
  → Separator lines entre items
  → Disclosure indicator (→) si navega
  → Touch target = toda la fila


CARDS MOBILE:

  VERTICAL (estándar):            HORIZONTAL (scroll):
  ┌─────────────────────┐        ┌─────────┐ ┌─────────┐
  │  ┌─────────────────┐│        │ ┌─────┐ │ │ ┌─────┐ │
  │  │    Imagen       ││        │ │ Img │ │ │ │ Img │ │
  │  └─────────────────┘│        │ └─────┘ │ │ └─────┘ │
  │  Título              │        │ Título  │ │ Título  │
  │  Descripción breve   │        │ $29.99  │ │ $19.99  │
  │  [Acción]            │        └─────────┘ └─────────┘
  └─────────────────────┘            ← scroll →
  Full width, stacked               Horizontal, carousel
```

### 5.4 Modals y Bottom sheets

```
MODAL vs BOTTOM SHEET en mobile:

  MODAL (centrado):               BOTTOM SHEET (desde abajo):
  ┌───────────────────────┐      ┌───────────────────────┐
  │ ░░░░░░░░░░░░░░░░░░░░│      │                       │
  │ ░░┌───────────────┐░░│      │  Contenido de la app  │
  │ ░░│ ¿Eliminar?    │░░│      │  (parcialmente visible)│
  │ ░░│               │░░│      │                       │
  │ ░░│ [No]  [Sí]    │░░│      ├───────────────────────┤
  │ ░░└───────────────┘░░│      │ ──── (drag indicator) │
  │ ░░░░░░░░░░░░░░░░░░░░│      │                       │
  │ ░░░░░░░░░░░░░░░░░░░░│      │  Opciones:            │
  └───────────────────────┘      │  📸 Tomar foto       │
                                 │  🖼 Galería           │
  Usar para:                     │  📄 Archivo           │
  → Confirmaciones               │                       │
  → Alertas críticas             │  [Cancelar]           │
  → Decisiones binarias          └───────────────────────┘

                                 Usar para:
                                 → Opciones / action sheets
                                 → Filtros
                                 → Contenido adicional
                                 → Formularios cortos
                                 → Cualquier cosa que el modal
                                   haría pero con mejor ergonomía

⚠️ En mobile, el BOTTOM SHEET es casi siempre mejor que el modal.
   Está en la thumb zone, se puede swipe down para cerrar,
   y se siente nativo.
```

### 5.5 Gestos

```
GESTOS ESTÁNDAR EN MOBILE:

GESTO              ACCIÓN                    EJEMPLOS
──────────────────────────────────────────────────────────
Tap                Activar, seleccionar      Botones, links, items
Long press         Acciones contextuales     Copiar, seleccionar, preview
Swipe left/right   Revelar acciones          Eliminar, archivar (mail)
Swipe down         Cerrar, refresh           Bottom sheet, pull-to-refresh
Pinch              Zoom in/out               Mapas, fotos
Double tap         Zoom / like               Fotos, Instagram
Swipe from edge    Back navigation           iOS back, Android back
Pull down          Refresh content           Pull-to-refresh


REGLAS PARA GESTOS:

1. Los gestos NUNCA deben ser la ÚNICA forma de hacer algo
   → Siempre ofrecer alternativa visible (botón, menú)

2. Los gestos deben ser DESCUBRIBLES
   → Hint visual (ej: "swipe para ver más")
   → Animación sutil que sugiera el gesto

3. Los gestos estándar NO deben ser reinterpretados
   → Swipe back = atrás (no lo cambies a "eliminar")
   → Pull down = refresh (no lo cambies a "cerrar")

⚠️ ANTI-PATRÓN: Gestos ocultos como única interacción.
   "Para acceder a settings, haz swipe con 3 dedos hacia arriba"
   → Nadie lo va a descubrir.
```

---

## 6. Interacciones y Feedback

### 6.1 Microinteracciones

**Intuición**
Las microinteracciones son los pequeños detalles animados que dan vida a la interfaz: el botón que "responde" al tap, el toggle que desliza suavemente, el ícono de like que late. No son decoración; son feedback que confirma al usuario que la interfaz está viva y respondiendo.

```
ESTRUCTURA DE UNA MICROINTERACCIÓN:

  TRIGGER  →  RULES  →  FEEDBACK  →  LOOPS/MODES

  Ej: Like en un post
  ────────────────────
  Trigger:  Double tap en la imagen
  Rules:    Si no liked → like. Si liked → unlike.
  Feedback: Corazón ❤️ aparece con scale animation
  Loops:    N/A (acción única)


MICROINTERACCIONES ESENCIALES:

  TAP FEEDBACK:
  ┌──────────┐  →  ┌──────────┐  →  ┌──────────┐
  │  Botón   │     │ ████████ │     │  Botón   │
  │ (idle)   │     │ (pressed)│     │ (result) │
  └──────────┘     └──────────┘     └──────────┘
  Estado default    Ripple/darken    Acción completada
                    (< 100ms)

  TOGGLE:
  [○─────]  →  [─────●]
  OFF (gris)    ON (color)
  Transición: 200ms ease

  PULL-TO-REFRESH:
  ↓ Pull  →  ◌ (spinner)  →  ✓ Actualizado
```

### 6.2 Animaciones funcionales

```
PRINCIPIO: Las animaciones en mobile tienen un PROPÓSITO funcional.
           No son decoración.

TIPO              PROPÓSITO                 DURACIÓN
──────────────────────────────────────────────────────
Feedback          Confirmar acción          50-150ms
Transición        Orientar en el espacio    200-300ms
Entrada           Dirigir atención          200-400ms
Loading           Indicar proceso           Loop o indeterminado
Celebración       Reforzar logro            300-500ms

REGLAS:
  → < 200ms: Feedback inmediato (tap, toggle, checkbox)
  → 200-300ms: Transiciones de pantalla
  → 300-500ms: Animaciones de entrada/salida
  → > 500ms: Demasiado lento (se siente pesado)
  → > 1s: Solo para loading con propósito claro

  ❌ ANIMACIÓN DECORATIVA:           ✅ ANIMACIÓN FUNCIONAL:

  Elementos que bounceIn sin         Pantalla nueva que slide-in
  razón → Distracción                desde la derecha → Orienta

  Parallax en toda la página         Card que se expande para
  → Mareo, lento                     mostrar detalle → Continuidad

  Logo animado en cada pantalla      Skeleton que pulsa suavemente
  → Repetitivo, molesto              → Indica que algo viene
```

### 6.3 Estados: Loading, Error, Success

```
LOADING STATES EN MOBILE:

  SKELETON (< 3s, contenido predecible):
  ┌─────────────────────────┐
  │ ████████████████        │
  │ ░░░░░░░░░░░░░░░░░░░░   │
  │ ░░░░░░░░░░░░░░         │
  │                         │
  │ ████████                │
  │ ░░░░░░░░░░░░░░░░       │
  └─────────────────────────┘

  SPINNER (< 1s, espera breve):
  ┌─────────────────────────┐
  │         ◌               │
  └─────────────────────────┘

  PULL-TO-REFRESH (recarga manual):
  ┌─────────────────────────┐
  │         ◌               │
  │ ─────────────────────── │
  │ Feed item 1             │
  │ Feed item 2             │
  └─────────────────────────┘


ERROR STATES:

  INLINE (campo específico):         FULL SCREEN (error fatal):
  ┌─────────────────────┐           ┌─────────────────────┐
  │ Email               │           │                     │
  │ ┌─────────────────┐ │           │     😵              │
  │ │ abc              │ │           │                     │
  │ └─────────────────┘ │           │  Sin conexión       │
  │ ✗ Email inválido    │           │                     │
  └─────────────────────┘           │  Revisa tu internet │
                                    │  e intenta de nuevo │
                                    │                     │
  BANNER (error de sección):         │  [Reintentar]       │
  ┌─────────────────────┐           └─────────────────────┘
  │ ⚠️ No se pudo cargar│
  │    [Reintentar]      │
  └─────────────────────┘


SUCCESS:
  → Toast breve: "✓ Guardado" (desaparece en 3s)
  → Inline check: ícono ✓ junto al campo
  → Celebración: animación de confetti (logros importantes)
  → Redirect: navegar a la siguiente pantalla (checkout → confirmation)
```

### 6.4 Transiciones entre pantallas

```
TRANSICIONES ESTÁNDAR:

  PUSH (navigation stack):
  Pantalla A ──slide left──→ Pantalla B
  Pantalla B ──slide right──→ Pantalla A (back)

  MODAL (bottom-up):
  Pantalla A ──slide up──→ Modal
  Modal ──slide down──→ Pantalla A (dismiss)

  FADE (tab switch):
  Tab A ──crossfade──→ Tab B

  SHARED ELEMENT:
  Card en lista ──expand──→ Detalle
  (la imagen de la card "crece" hacia la pantalla de detalle)


REGLA: La dirección de la transición indica la jerarquía.

  → Push right = ir más profundo
  ← Pop left = volver atrás
  ↑ Slide up = overlay/modal
  ↓ Slide down = dismiss overlay
  Fade = cambio de contexto al mismo nivel
```

---

## 7. Formularios en Mobile

### 7.1 Simplificación de inputs

**Intuición**
En desktop, un formulario de 10 campos es manejable. En mobile, con teclado virtual ocupando la mitad de la pantalla, 10 campos se sienten como 30. Cada campo que eliminas duplica la probabilidad de que el usuario termine.

```
❌ FORMULARIO DESKTOP EN MOBILE:     ✅ FORMULARIO OPTIMIZADO:

┌─────────────────────┐             ┌─────────────────────┐
│ Nombre              │             │ Nombre completo     │
│ ┌─────────────────┐ │             │ ┌─────────────────┐ │
│ │                 │ │             │ │                 │ │
│ └─────────────────┘ │             │ └─────────────────┘ │
│ Apellido            │             │                     │
│ ┌─────────────────┐ │             │ Email               │
│ │                 │ │             │ ┌─────────────────┐ │
│ └─────────────────┘ │             │ │                 │ │
│ Email               │             │ └─────────────────┘ │
│ ┌─────────────────┐ │             │                     │
│ │                 │ │             │ Contraseña    [👁]  │
│ └─────────────────┘ │             │ ┌─────────────────┐ │
│ Confirmar email     │             │ │                 │ │
│ ┌─────────────────┐ │             │ └─────────────────┘ │
│ │                 │ │             │                     │
│ └─────────────────┘ │             │ ┌─────────────────┐ │
│ Contraseña          │             │ │  Crear cuenta   │ │
│ ┌─────────────────┐ │             │ └─────────────────┘ │
│ │                 │ │             │                     │
│ └─────────────────┘ │             │ ── o continuar con──│
│ Confirmar contraseña│             │ [G] Google  [→]Apple│
│ ┌─────────────────┐ │             └─────────────────────┘
│ │                 │ │
│ └─────────────────┘ │             4 campos: nombre, email,
│ Teléfono            │             password, CTA
│ ┌─────────────────┐ │             + social login
│ │                 │ │
│ └─────────────────┘ │
│ [Registrarse]       │
└─────────────────────┘

8 campos + scroll con teclado
= Alto abandono
```

### 7.2 Teclados contextuales

```
EL TECLADO CORRECTO REDUCE ERRORES Y TIEMPO:

EMAIL:
  ┌──────────────────────────────────────┐
  │ q w e r t y u i o p                 │
  │  a s d f g h j k l                  │
  │    z x c v b n m                    │
  │ [123]  [@]  [espacio]  [.com] [→]   │  ← @ y .com accesibles
  └──────────────────────────────────────┘
  input type="email"

TELÉFONO:
  ┌──────────────────────────────────────┐
  │    1       2       3                 │
  │    4       5       6                 │
  │    7       8       9                 │
  │    +       0       ⌫                │
  └──────────────────────────────────────┘
  input type="tel"

NUMÉRICO (PIN, código):
  ┌──────────────────────────────────────┐
  │    1       2       3                 │
  │    4       5       6                 │
  │    7       8       9                 │
  │            0       ⌫                │
  └──────────────────────────────────────┘
  inputmode="numeric"

BÚSQUEDA:
  ┌──────────────────────────────────────┐
  │ q w e r t y u i o p                 │
  │  a s d f g h j k l                  │
  │    z x c v b n m                    │
  │ [123]  [espacio]        [Buscar]    │  ← Botón "Buscar"
  └──────────────────────────────────────┘
  input type="search"
```

### 7.3 Multi-step forms en mobile

```
REGLA: En mobile, multi-step es casi siempre mejor que single-page
       para formularios de 5+ campos.

ESTRUCTURA:

  Paso 1 de 3: Tu cuenta
  ●━━━━━━━○━━━━━━━○

  ┌─────────────────────┐
  │                     │
  │ Email               │
  │ ┌─────────────────┐ │
  │ │                 │ │
  │ └─────────────────┘ │
  │                     │
  │ Contraseña          │
  │ ┌─────────────────┐ │
  │ │                 │ │
  │ └─────────────────┘ │
  │                     │
  │                     │
  │                     │
  │                     │
  │ ┌─────────────────┐ │  ← Sticky bottom CTA
  │ │   Continuar →   │ │
  │ └─────────────────┘ │
  └─────────────────────┘

REGLAS PARA MULTI-STEP MOBILE:
  → 2-4 campos por paso (máximo)
  → Progress indicator siempre visible
  → CTA sticky al fondo (thumb zone)
  → Back arrow en el header (no botón "Atrás" en el form)
  → Validar al avanzar, no al final
  → Guardar progreso entre pasos (si cierra la app, no pierde)
```

### 7.4 Minimizar fricción

```
TÉCNICAS DE REDUCCIÓN DE FRICCIÓN EN MOBILE:

1. AUTOFILL / AUTOCOMPLETE
   → autocomplete="name", "email", "cc-number"
   → El sistema rellena campos automáticamente
   → En iOS: Face ID puede autorellenar passwords

2. SOCIAL LOGIN
   → "Continuar con Google / Apple / Facebook"
   → 1 tap vs 5 campos de formulario
   → Apple Sign-In obligatorio si ofreces social login (App Store)

3. SMART DEFAULTS
   → País según locale/IP
   → Moneda según país
   → Formato de fecha según región

4. BIOMÉTRICOS
   → Face ID / Touch ID para login
   → Fingerprint para confirmar pago
   → 0 campos vs username + password

5. CÁMARA COMO INPUT
   → Escanear tarjeta de crédito con cámara
   → OCR para documentos
   → QR code en vez de escribir un código largo

6. CLIPBOARD DETECTION
   → "¿Pegar el código 123456?" (OTP detection)
   → Detectar contenido relevante del clipboard
```

---

## 8. Accesibilidad en Mobile

### 8.1 Tamaños táctiles adecuados

```
MÍNIMOS DE TOUCH TARGET:

  Apple (HIG):     44 × 44 pt
  Google (MD):     48 × 48 dp
  WCAG 2.5.8 (AA): 24 × 24 CSS px (mínimo absoluto)
  WCAG 2.5.5 (AAA): 44 × 44 CSS px (recomendado)

  ❌ TARGETS PEQUEÑOS:               ✅ TARGETS ACCESIBLES:

  [×]  ← 24px, difícil              [  ✕  ]  ← 44px, cómodo
  de tocar                           de tocar

  ┌─┐┌─┐┌─┐  ← pegados              ┌───┐ ┌───┐ ┌───┐  ← separados
  │A││B││C│                          │ A │ │ B │ │ C │
  └─┘└─┘└─┘                          └───┘ └───┘ └───┘
  Taps accidentales                    8px+ gap

NOTA: El touch target puede ser más grande que el elemento visual.
  → Un ícono de 24px puede tener un tap area de 44px.
  → Usa padding invisible para agrandar el target.
```

### 8.2 Contraste en condiciones reales

```
EN DESKTOP:                          EN MOBILE:
Condiciones controladas              Condiciones reales
  → Oficina con luz estable          → Sol directo en la pantalla
  → Monitor calibrado                → Pantalla con brillo variable
  → Distancia fija                   → Distancia variable

IMPLICACIÓN:
  → Contraste mínimo AA (4.5:1) a veces no es suficiente
  → Apuntar a AAA (7:1) cuando sea posible
  → Nunca usar gris claro sobre blanco para texto importante
  → Botones primarios con alto contraste siempre

TESTING REAL:
  → Sal a la calle con tu prototipo
  → ¿Puedes leer el texto bajo el sol?
  → ¿Los botones son distinguibles con brillo al máximo?
  → ¿Los colores de estado (error/success) se diferencian?
```

### 8.3 Tipografía legible

```
REGLAS DE TIPOGRAFÍA MOBILE:

  Body text mínimo:   16px (< 16px = zoom automático en iOS Safari)
  Captions:           12px (mínimo absoluto, solo para info terciaria)
  Labels:             14px
  Headings:           20-32px
  Line height:        1.4-1.5× (más generoso que desktop)
  Longitud de línea:  35-45 caracteres por línea
  Alineación:         Izquierda (nunca justificado en mobile)

  ❌ MAL:                             ✅ BIEN:
  ┌────────────────────┐             ┌────────────────────┐
  │ Texto a 13px       │             │ Texto a 16px       │
  │ con line-height    │             │                    │
  │ de 1.1 y más de    │             │ con line-height    │
  │ 60 chars por línea │             │ de 1.5 y máximo    │
  │ que se siente muy  │             │ 40-45 caracteres   │
  │ denso y difícil de │             │ por línea.         │
  │ leer en pantalla   │             │                    │
  │ pequeña.           │             │ Se lee bien.       │
  └────────────────────┘             └────────────────────┘
```

### 8.4 Navegación accesible en mobile

```
SCREEN READERS MOBILE:

  iOS:     VoiceOver (activar con triple-click en botón lateral)
  Android: TalkBack (activar en Settings > Accessibility)

GESTOS DE VOICEOVER:
  Tap → Lee el elemento enfocado
  Double tap → Activa el elemento
  Swipe left/right → Navegar entre elementos
  Three-finger swipe → Scroll

CHECKLIST DE ACCESIBILIDAD MOBILE:
  ✅ Todos los elementos interactivos tienen label accesible
  ✅ Imágenes tienen alt text (o alt="" si decorativas)
  ✅ Touch targets ≥ 44px
  ✅ Contraste ≥ 4.5:1 texto, ≥ 3:1 UI
  ✅ No depender solo del color
  ✅ Gestos tienen alternativa visible
  ✅ Formularios con labels asociados
  ✅ Errores anunciados (role="alert")
  ✅ Focus order lógico
  ✅ Orientación landscape/portrait funcional
  ✅ Respeta prefers-reduced-motion
  ✅ Respeta texto escalado por el usuario (Dynamic Type)
```

### 8.5 Dynamic Type / Texto escalable

```
Los usuarios con baja visión escalan el tamaño de texto del sistema.
Tu app DEBE respetar esa configuración.

iOS: Settings > Accessibility > Larger Text
Android: Settings > Display > Font size

IMPLICACIÓN:
  → No usar tamaños fijos en px que ignoran la preferencia
  → Usar unidades relativas (rem, sp en Android, Dynamic Type en iOS)
  → Tu layout debe funcionar con texto 200% más grande
  → WCAG 1.4.4 — Resize Text (AA): funcional hasta 200% zoom

❌ MAL:                              ✅ BIEN:
┌─────────────────────┐             ┌─────────────────────┐
│ Texto a 14px fijo   │             │ Texto que respeta   │
│ No cambia con       │             │ la preferencia      │
│ accesibilidad       │             │ del usuario.        │
│                     │             │                     │
│ (El usuario sube    │             │ (Si el usuario sube │
│  el texto a 200%    │             │  el texto a 200%,   │
│  y nada cambia)     │             │  el texto crece y   │
│                     │             │  el layout se adapta│
└─────────────────────┘             └─────────────────────┘
```

---

## 9. Responsive vs Adaptive Design

### 9.1 Responsive Design

**Intuición**
Responsive design es un layout líquido que se adapta fluidamente a cualquier ancho de pantalla, como agua que toma la forma del recipiente.

```
RESPONSIVE = UN layout que se estira y adapta

  375px                768px                  1440px
  ┌──────────┐        ┌────────────────┐     ┌──────────────────────┐
  │ ████████ │        │ ████ │ ████    │     │ ████ │ ████ │ ████  │
  │ ████████ │        │ ████ │ ████    │     │      │      │       │
  │ ████████ │        │      │         │     │      │      │       │
  └──────────┘        └────────────────┘     └──────────────────────┘
  1 columna           2 columnas             3 columnas

  → El MISMO HTML se reorganiza con CSS
  → Breakpoints determinan cuándo cambia el layout
  → Grid fluido con max-width y porcentajes
```

```css
/* Responsive: un sistema, fluid */
.grid {
  display: grid;
  gap: 16px;
  grid-template-columns: 1fr;               /* Mobile: 1 col */
}

@media (min-width: 768px) {
  .grid {
    grid-template-columns: 1fr 1fr;          /* Tablet: 2 cols */
  }
}

@media (min-width: 1024px) {
  .grid {
    grid-template-columns: 1fr 1fr 1fr;      /* Desktop: 3 cols */
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

### 9.2 Adaptive Design

**Intuición**
Adaptive design crea layouts ESPECÍFICOS para diferentes tamaños de pantalla. No es fluido; son "trajes a medida" para cada dispositivo.

```
ADAPTIVE = MÚLTIPLES layouts fijos para dispositivos específicos

  iPhone 14             iPad                   Desktop
  (375px)               (768px)                (1440px)
  ┌──────────┐         ┌────────────────┐     ┌──────────────────────┐
  │ Bottom   │         │ Sidebar + grid │     │ Full dashboard      │
  │ tabs +   │         │ optimizado     │     │ con sidebar +       │
  │ cards    │         │ para tablet    │     │ panels + widgets    │
  └──────────┘         └────────────────┘     └──────────────────────┘

  Cada uno es un DISEÑO DIFERENTE
  optimizado para ese dispositivo.
```

### 9.3 Cuándo usar cada enfoque

| Criterio | Responsive | Adaptive |
|---|---|---|
| **Contenido** | Mismo contenido, diferente layout | Contenido puede variar por device |
| **Desarrollo** | Un codebase | Puede necesitar código específico |
| **Mantenimiento** | Más fácil (un sistema) | Más complejo (múltiples layouts) |
| **UX óptima** | Buena en general | Excelente por dispositivo |
| **Ideal para** | Sitios web, blogs, landing pages | Apps nativas, dashboards complejos |
| **Breakpoints** | Fluido entre breakpoints | Fijo en cada breakpoint |

```
DECISIÓN:

¿Tu producto es web o app?
│
├─ WEB → Responsive (casi siempre)
│  → Un site que funciona en todos los devices
│  → Mobile-first con breakpoints
│
├─ APP NATIVA → Adaptive
│  → Layout específico para iPhone, iPad, Android
│  → Aprovecha capacidades nativas de cada device
│
└─ DASHBOARD / SaaS → Híbrido
   → Mobile: layout simplificado (adaptive)
   → Tablet: layout intermedio (adaptive)
   → Desktop: layout completo (adaptive)
   → Dentro de cada breakpoint: responsive (fluid)
```

### 9.4 Breakpoints móviles

```
BREAKPOINTS ESTÁNDAR:

  SMALL PHONE:    320px  (iPhone SE, older devices)
  PHONE:          375px  (iPhone 14, Galaxy S)
  LARGE PHONE:    428px  (iPhone 14 Pro Max)
  ──────────────────────────────────────────
  SMALL TABLET:   744px  (iPad Mini)
  TABLET:         768px  (iPad)
  LARGE TABLET:   1024px (iPad Pro 11")
  ──────────────────────────────────────────
  LAPTOP:         1280px
  DESKTOP:        1440px
  WIDE:           1920px

ENFOQUE PRÁCTICO (3-4 breakpoints):

  Mobile:   < 768px   → 4 columnas, stacked
  Tablet:   768-1023  → 8 columnas, 2-col layouts
  Desktop:  1024-1439 → 12 columnas, sidebar + content
  Wide:     ≥ 1440    → 12 columnas, max-width container

EN CSS:
  @media (min-width: 768px)  { /* Tablet */ }
  @media (min-width: 1024px) { /* Desktop */ }
  @media (min-width: 1440px) { /* Wide */ }
```

---

## 10. Design Systems en Mobile

### 10.1 Componentes reutilizables

```
LIBRERÍA DE COMPONENTES MOBILE:

mobile-components/
├── navigation/
│   ├── BottomTabBar/
│   ├── NavigationBar/  (top bar con back, title, actions)
│   ├── Drawer/         (hamburger menu content)
│   └── SegmentedControl/
│
├── inputs/
│   ├── TextField/      (height: 48px, label above)
│   ├── SearchBar/
│   ├── Checkbox/       (44px tap target)
│   ├── RadioGroup/
│   ├── Switch/Toggle/
│   ├── Slider/
│   └── DatePicker/
│
├── feedback/
│   ├── Toast/
│   ├── Alert/
│   ├── BottomSheet/
│   ├── ProgressBar/
│   ├── Skeleton/
│   └── Spinner/
│
├── content/
│   ├── Card/
│   ├── ListItem/       (48px+ height, full-width tap)
│   ├── Avatar/
│   ├── Badge/
│   ├── Chip/
│   └── EmptyState/
│
├── actions/
│   ├── Button/         (56px height, full-width option)
│   ├── FAB/            (Floating Action Button)
│   ├── IconButton/     (44px tap target)
│   └── ActionSheet/
│
└── layout/
    ├── SafeAreaView/
    ├── ScrollView/
    ├── KeyboardAvoidingView/
    └── Divider/
```

### 10.2 Tokens de diseño para mobile

```css
/* ===== MOBILE DESIGN TOKENS ===== */

/* --- Spacing --- */
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 32px;
--space-2xl: 48px;

/* --- Touch targets --- */
--touch-min: 44px;
--touch-comfortable: 48px;
--touch-large: 56px;

/* --- Typography (mobile) --- */
--font-caption: 12px;
--font-label: 14px;
--font-body: 16px;        /* NUNCA menos para body */
--font-title: 20px;
--font-heading: 24px;
--font-display: 32px;

--line-height-tight: 1.2;
--line-height-normal: 1.4;
--line-height-relaxed: 1.6;

/* --- Layout --- */
--margin-screen: 16px;    /* Margin lateral de pantalla */
--grid-columns: 4;
--grid-gap: 16px;

/* --- Safe areas --- */
--safe-top: env(safe-area-inset-top);
--safe-bottom: env(safe-area-inset-bottom);

/* --- Border radius (mobile tiende a más redondeado) --- */
--radius-sm: 8px;
--radius-md: 12px;
--radius-lg: 16px;
--radius-xl: 24px;
--radius-full: 9999px;

/* --- Elevation (mobile usa elevation más que bordes) --- */
--shadow-sm: 0 1px 2px rgba(0,0,0,0.1);
--shadow-md: 0 4px 8px rgba(0,0,0,0.12);
--shadow-lg: 0 8px 24px rgba(0,0,0,0.15);

/* --- Animation --- */
--duration-instant: 50ms;
--duration-fast: 150ms;
--duration-normal: 250ms;
--duration-slow: 400ms;
--easing-default: cubic-bezier(0.4, 0, 0.2, 1);
--easing-decelerate: cubic-bezier(0, 0, 0.2, 1);
--easing-accelerate: cubic-bezier(0.4, 0, 1, 1);
```

### 10.3 Material Design vs Human Interface Guidelines

| Aspecto | Material Design (Android) | HIG (iOS) |
|---|---|---|
| **Filosofía** | "Material is the metaphor" | "Clarity, deference, depth" |
| **Navegación** | Bottom nav + drawer | Tab bar + navigation stack |
| **Botón primario** | FAB (floating action button) | Button in nav bar o full-width |
| **Acciones en listas** | Swipe actions, contextual menu | Swipe actions, edit mode |
| **Tipografía** | Roboto (default) | SF Pro (system) |
| **Bordes** | Rounded corners (md) | Rounded corners (lg) |
| **Elevación** | Shadows (elevation system) | Materials (blur/vibrancy) |
| **Back** | System back (←) + gesture | In-app back (←) + edge swipe |
| **Modales** | Bottom sheets preferidos | Sheets, alerts, popovers |
| **Toggle** | Material Switch | iOS Switch |
| **Touch feedback** | Ripple effect | Highlight/opacity |

```
MATERIAL DESIGN:                    HUMAN INTERFACE GUIDELINES:
┌───────────────────────┐           ┌───────────────────────┐
│ ← Title        ⋮      │           │ < Back   Title   Edit │
├───────────────────────┤           ├───────────────────────┤
│                       │           │                       │
│  Content              │           │  Content              │
│                       │           │                       │
│                       │           │                       │
│                       │           │                       │
│                 [FAB] │           │                       │
│                  ⊕    │           │                       │
├───────────────────────┤           ├───────────────────────┤
│ 🏠   🔍   ➕   👤    │           │ 🏠   🔍   ➕   👤    │
│ ▬▬▬                   │           │            ●          │
└───────────────────────┘           │ ─────────────────     │
                                    └───────────────────────┘
  FAB for primary action              Tab bar con dot indicator
  Indicator bar en active             Tint color en active
  Top bar con overflow (⋮)            Top bar con text actions
```

### 10.4 Consistencia cross-platform

```
CLAVE: Consistente en EXPERIENCIA, no necesariamente en APARIENCIA.

¿Qué debe ser IGUAL en iOS y Android?
  ✅ Arquitectura de información (mismas secciones)
  ✅ Flujos de tareas (mismos pasos)
  ✅ Contenido disponible
  ✅ Brand (colores, tipografía, iconografía)
  ✅ Terminología

¿Qué puede ser DIFERENTE?
  ⚠️ Navegación (tab bar iOS vs bottom nav + drawer Android)
  ⚠️ Gestos nativos (edge swipe back en iOS)
  ⚠️ Componentes nativos (date picker, alert style)
  ⚠️ Transiciones (push iOS vs shared element Android)
  ⚠️ Tipografía del sistema (SF Pro vs Roboto)

REGLA: Sigue las convenciones de cada plataforma para
       las INTERACCIONES, pero mantén tu MARCA y ESTRUCTURA
       consistentes.
```

---

## 11. Performance y Optimización

### 11.1 Carga rápida

```
DATOS CLAVE:

  53% de usuarios abandonan si la carga > 3 segundos (Google)
  1 segundo de delay = 7% menos conversión (Amazon)
  La carga percibida importa más que la carga real

ESTRATEGIAS:

  1. PERFORMANCE BUDGET
     → Máximo 170KB de JavaScript en la carga inicial
     → Máximo 150KB de CSS
     → Time to Interactive (TTI) < 3.8 segundos en 3G

  2. CARGA PERCIBIDA
     → Skeleton screens en vez de spinners
     → Cargar contenido above the fold primero
     → Optimistic UI (mostrar resultado antes de confirmar)

  3. PRIORIZACIÓN
     → Critical CSS inline en el <head>
     → Defer JavaScript no esencial
     → Preload recursos críticos (fonts, hero image)
```

### 11.2 Optimización de imágenes

```
FORMATOS RECOMENDADOS:

  WebP:   30% más ligero que JPEG, soporte universal
  AVIF:   50% más ligero que JPEG, soporte creciente
  SVG:    Íconos y gráficos vectoriales (escala sin peso)
  JPEG:   Fallback para navegadores antiguos
  PNG:    Solo cuando necesitas transparencia y no puedes usar WebP

TÉCNICAS:

  1. SRCSET (responsive images):
     <img srcset="photo-375.webp 375w,
                  photo-768.webp 768w,
                  photo-1440.webp 1440w"
          sizes="(max-width: 768px) 100vw, 50vw"
          src="photo-768.webp"
          alt="Descripción" />
     → El navegador descarga SOLO el tamaño que necesita

  2. LAZY LOADING:
     <img src="photo.webp" loading="lazy" alt="..." />
     → Carga cuando está cerca del viewport
     → NO usar en imágenes above the fold

  3. PLACEHOLDER:
     → LQIP (Low Quality Image Placeholder):
       Mostrar versión borrosa de 1KB mientras carga la real
     → Dominant color: mostrar el color dominante como fondo
```

### 11.3 Reducción de peso visual

```
PRINCIPIO: Lo que no se muestra, no se carga.

TÉCNICAS:
  → Lazy load de secciones below the fold
  → Infinite scroll carga bajo demanda
  → Colapsar secciones con accordion
  → Thumbnails en lista → imagen completa en detalle
  → Skeleton screens con contenido diferido

  ❌ CARGAR TODO:                    ✅ CARGAR PROGRESIVAMENTE:
  ┌─────────────────┐               ┌─────────────────┐
  │ Imagen HD (2MB) │               │ Placeholder     │  ← Instantáneo
  │ Video autoplay  │               │ (color/blur)    │
  │ 50 productos    │               │                 │
  │ Full analytics  │               │ Imagen 375w     │  ← Cuando visible
  │ Chat widget     │               │ (50KB)          │
  │ Social embeds   │               │                 │
  │                 │               │ 10 productos    │  ← First batch
  │ TTI: 8 segundos │               │ más al scroll   │  ← Load more
  └─────────────────┘               │                 │
                                    │ TTI: 1.5 seg    │
                                    └─────────────────┘
```

### 11.4 Impacto en UX

```
RELACIÓN PERFORMANCE ↔ UX:

  TIEMPO        PERCEPCIÓN              ACCIÓN
  ──────────────────────────────────────────────────
  < 100ms       Instantáneo             Feedback inmediato
  100-300ms     Ligero delay            Animación de transición
  300ms-1s      "Está cargando"         Spinner breve
  1-3s          "Es un poco lento"      Skeleton screen
  3-5s          "¿Funciona?"            Progress bar + mensaje
  > 5s          "Está roto"             Background + notificación
  > 10s         Abandono                → Has perdido al usuario

REGLA: Nunca dejes al usuario sin feedback más de 300ms.
       Si algo tarda, DÍSELO.
```

---

## 12. Testing y Validación

### 12.1 Testing en dispositivos reales

**Intuición**
Los emuladores mienten. La experiencia real en un teléfono real, con dedos reales, en condiciones reales, es insustituible.

```
QUÉ NO PUEDES TESTEAR EN EMULADOR:

  ❌ Precisión del touch (dedo vs cursor de mouse)
  ❌ Thumb zone real (alcance del pulgar)
  ❌ Legibilidad bajo el sol
  ❌ Performance real (el emulador usa tu CPU, no la del teléfono)
  ❌ Velocidad de red real (3G en el metro)
  ❌ Notificaciones interrumpiendo tu flujo
  ❌ Multitasking (cambiar entre apps)
  ❌ Teclado virtual real (tamaño, autocorrect)
  ❌ Gestos nativos (edge swipe, force touch)

DISPOSITIVOS MÍNIMOS PARA TESTING:
  → iPhone SE (pantalla más pequeña en uso)
  → iPhone 14/15 (pantalla estándar iOS)
  → Android mid-range (Samsung Galaxy A54 o similar)
  → Tablet (iPad / Android tablet, si tu producto lo soporta)
```

### 12.2 Usability testing en mobile

```
PROTOCOLO DE USABILITY TEST MOBILE:

1. SETUP
   → Dispositivo real del participante (o proporcionar uno)
   → Cámara apuntando a la pantalla (o screen recording)
   → 5-7 participantes por ronda
   → Tareas específicas y medibles

2. TAREAS DE EJEMPLO:
   → "Busca un par de zapatos de running por menos de $100"
   → "Regístrate en la app usando tu email"
   → "Cambia tu dirección de envío"
   → "Encuentra tu último pedido y solicita devolución"

3. MÉTRICAS A OBSERVAR:
   → ¿Completó la tarea? (completion rate)
   → ¿Cuánto tardó? (time on task)
   → ¿Cuántos taps necesitó? (tap count)
   → ¿Se perdió en algún punto? (navigation errors)
   → ¿Usó la mano correctamente? (ergonomía)
   → ¿Entendió el feedback? (comprensión)

4. SEÑALES DE PROBLEMA:
   → Tap repetido en un elemento (no responde o confuso)
   → Scroll up/down buscando algo (perdido)
   → Giro del teléfono (buscando más espacio)
   → Pausa larga antes de actuar (carga cognitiva)
   → Expresiones de frustración
```

### 12.3 Métricas clave

```
MÉTRICAS CUANTITATIVAS:

  TASK COMPLETION RATE
  → % de usuarios que completan una tarea
  → Benchmark: > 78% es aceptable, > 90% es excelente
  → Si < 50%, hay un problema serio de usabilidad

  TIME ON TASK
  → Tiempo promedio para completar una tarea
  → Comparar contra tu benchmark o competidores
  → Outliers (muy lentos) indican problemas específicos

  DROP-OFF RATE (por pantalla)
  → % de usuarios que abandonan en cada pantalla de un flujo
  → Ej: Checkout
        Cart:    100% ──→ Address: 72% ──→ Payment: 58% ──→ Confirm: 45%
        Insight: 28% abandona entre cart y address. ¿Por qué?

  ERROR RATE
  → % de envíos con errores de validación
  → Alto error rate en un campo = mal diseño de ese campo

  TAPS TO COMPLETE
  → # de taps necesarios para completar una tarea core
  → Benchmark: < 3 taps para tareas frecuentes


MÉTRICAS CUALITATIVAS:

  SUS (System Usability Scale)
  → Cuestionario de 10 preguntas, score 0-100
  → > 68 = above average, > 80 = excelente

  CSAT (Customer Satisfaction)
  → "¿Qué tan satisfecho estás?" 1-5
  → Medir después de tareas específicas

  NPS (Net Promoter Score)
  → "¿Recomendarías esta app?" 0-10
  → Detractores (0-6), Pasivos (7-8), Promotores (9-10)
```

### 12.4 Iteración basada en datos

```
CICLO DE ITERACIÓN MOBILE:

  ┌──────────┐     ┌──────────┐     ┌──────────┐
  │          │     │          │     │          │
  │ MEDIR    │────→│ ANALIZAR │────→│ DISEÑAR  │
  │          │     │          │     │          │
  └──────────┘     └──────────┘     └──────────┘
       ↑                                  │
       │                                  ▼
  ┌──────────┐                      ┌──────────┐
  │          │                      │          │
  │ EVALUAR  │←─────────────────────│ ITERAR   │
  │          │                      │          │
  └──────────┘                      └──────────┘

  MEDIR:    Analytics, heatmaps, session recordings
  ANALIZAR: ¿Dónde están los problemas? ¿Qué métricas caen?
  DISEÑAR:  Hipótesis de mejora, prototipos
  ITERAR:   Implementar cambio (A/B test si es posible)
  EVALUAR:  ¿Mejoró la métrica? ¿Hubo efectos secundarios?

HERRAMIENTAS:
  → Firebase Analytics / Mixpanel → Métricas y funnels
  → Hotjar / Microsoft Clarity → Heatmaps, session replays
  → Maze / UserTesting → Usability testing remoto
  → TestFlight (iOS) / Firebase App Distribution → Beta testing
```

---

## 13. Nivel Intermedio / Avanzado

### 13.1 Diseño para apps complejas (SaaS, Fintech)

```
DESAFÍOS DE UX MOBILE EN APPS COMPLEJAS:

1. DENSIDAD DE INFORMACIÓN
   Desktop: dashboard con 10 widgets visibles
   Mobile: ¿cómo mostrar la misma info en 375px?

   SOLUCIÓN: Priorizar → Resumir → Drill-down
   ┌─────────────────────┐
   │ KPI principal: $12K │  ← Resumen (1 número)
   │ ↑ 12% vs mes ant.   │
   │ [Ver detalle →]      │  ← Drill-down para más
   └─────────────────────┘

2. FLUJOS MULTI-PASO
   Desktop: wizard con sidebar de progreso
   Mobile: stack con progress bar minimal

   SOLUCIÓN: 1 paso = 1 pantalla = 2-3 campos

3. DATOS FINANCIEROS
   Desktop: tabla con 10 columnas
   Mobile: lista con los 2-3 datos clave por item

   SOLUCIÓN: Card-based con expand para detalle
   ┌─────────────────────────┐
   │ Transferencia a Juan    │
   │ -$500.00      15 Abr    │
   │                      ▼  │  ← Tap para expandir
   │ ─────────────────────── │
   │ Referencia: TRF-12345   │  ← Detalle expandido
   │ Banco: BBVA             │
   │ Estado: Completada      │
   └─────────────────────────┘
```

### 13.2 Offline-first design

**Intuición**
En mobile, la conexión no es garantía. El metro, el avión, la zona rural, el elevator: todos cortan la red. Una app que no funciona sin conexión es una app rota para millones de momentos reales.

```
OFFLINE-FIRST STRATEGY:

  1. CACHEAR contenido ya visto
     → La última versión del feed, mensajes, datos del perfil
     → El usuario puede navegar lo que ya cargó

  2. PERMITIR acciones offline
     → Redactar mensajes, crear notas, editar datos
     → Encolar y sincronizar cuando haya conexión

  3. INDICAR estado de conexión (sin alarmar)
     ┌─────────────────────────┐
     │ ⚡ Sin conexión.         │  ← Banner sutil, no bloqueante
     │ Los cambios se guardarán│
     │ cuando te reconectes.   │
     └─────────────────────────┘

  4. SINCRONIZAR inteligentemente
     → Cuando recupera conexión: sincronizar en background
     → Resolver conflictos (¿qué pasa si editaron lo mismo offline?)
     → Feedback: "✓ Cambios sincronizados"

  ❌ MAL:                              ✅ BIEN:
  ┌─────────────────────┐             ┌─────────────────────┐
  │                     │             │ ⚡ Modo offline      │
  │    😵 Sin conexión  │             │                     │
  │                     │             │ Mis notas:          │
  │  No puedes usar     │             │ • Nota 1 (✓ sync)  │
  │  la app sin         │             │ • Nota 2 (◌ pending)│
  │  internet.          │             │ • Nota 3 (nuevo)    │
  │                     │             │                     │
  └─────────────────────┘             │ [+ Nueva nota]      │
  App inútil sin red                  └─────────────────────┘
                                      App funcional siempre
```

### 13.3 Manejo de estados complejos

```
ESTADOS QUE UNA APP MOBILE DEBE MANEJAR:

  ESTADO           PANTALLA                         EJEMPLO
  ──────────────────────────────────────────────────────────────
  LOADING          Skeleton / spinner               Cargando feed
  EMPTY            Empty state + CTA                Sin proyectos
  PARTIAL          Contenido parcial + indicator     5 de 50 items
  LOADED           Contenido completo               Feed cargado
  ERROR            Error + retry                    Fallo de red
  OFFLINE          Cached content + indicator        Sin conexión
  UPDATING         Content + subtle refresh          Pull-to-refresh
  STALE            Content + refresh prompt          "Hay actualizaciones"
  PERMISSION       Permission request               Acceso a cámara
  ONBOARDING       Tutorial / walkthrough            Primera vez

CADA PANTALLA de tu app debe diseñar los 10 estados.
  Si solo diseñas "loaded", tienes 9 estados sin diseñar
  donde la experiencia se rompe.
```

### 13.4 Personalización de experiencia

```
PERSONALIZACIÓN EN MOBILE:

  1. ADAPTIVE UI
     → Mostrar acciones frecuentes primero
     → "Accesos rápidos" basados en uso real
     → Reordenar tabs según frecuencia (con cuidado)

  2. CONTEXTUAL
     → Modo oscuro automático según hora del día
     → Notificaciones basadas en ubicación
     → Contenido relevante según comportamiento

  3. PREFERENCIAS EXPLÍCITAS
     → El usuario elige categorías de interés
     → Personalización de home screen (widgets)
     → Nivel de notificaciones

  REGLA: Personalización que FACILITA > que SORPRENDE.
  → "Te muestro lo que más usas" ✅
  → "Cambié todo sin avisarte" ❌
```

### 13.5 Cross-platform consistency (iOS vs Android)

```
ESTRATEGIA DE DISEÑO CROSS-PLATFORM:

  NIVEL 1: COMPARTIDO (igual en ambas plataformas)
  ─────────────────────────────────────────────
  → Brand identity (colores, tipografía, tono)
  → Arquitectura de información
  → Feature parity (mismas funcionalidades)
  → Content strategy

  NIVEL 2: ADAPTADO (mismo concepto, diferente implementación)
  ─────────────────────────────────────────────
  → Navegación (tab bar iOS, bottom nav + drawer Android)
  → Gestos de back (edge swipe iOS, system back Android)
  → Componentes nativos (date picker, alert)
  → Transiciones (iOS slide, Android fade)

  NIVEL 3: NATIVO (específico de plataforma)
  ─────────────────────────────────────────────
  → Haptics (Taptic Engine en iOS)
  → Widgets (home screen)
  → App Clips (iOS) / Instant Apps (Android)
  → System integration (Shortcuts, Intents)
```

### 13.6 Trade-offs de diseño

```
TRADE-OFFS COMUNES EN MOBILE:

  SIMPLICIDAD vs PODER
  ────────────────────
  Simple: 3 opciones visibles, fácil para nuevos
  Poderoso: 20 opciones, eficiente para expertos
  → Solución: Progressive disclosure

  NATIVE vs CROSS-PLATFORM
  ────────────────────
  Native: Mejor performance, feel nativo, más caro
  Cross-platform (Flutter/RN): Un codebase, más rápido, compromiso en UX
  → Depende de presupuesto y complejidad de UX

  ENGAGEMENT vs RESPETO
  ────────────────────
  Engagement: Notificaciones, badges, streaks
  Respeto: Mínimas interrupciones, control del usuario
  → Dar control al usuario sobre notificaciones

  FEATURES vs PERFORMANCE
  ────────────────────
  Más features: Más valor, más peso, más complejidad
  Menos features: Más rápido, más simple, ¿suficiente valor?
  → 80/20: El 80% de los usuarios usan el 20% de features

  CONSISTENCIA vs PLATAFORMA
  ────────────────────
  Consistencia cross-platform: Una app, dos plataformas iguales
  Plataforma nativa: Se siente "de la plataforma"
  → Compartir estructura, adaptar interacción
```

---

## Cheat Sheet — Mobile Design

```
┌──────────────────────────────────────────────────────────────────┐
│                    MOBILE DESIGN CHEAT SHEET                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ENFOQUE: MOBILE-FIRST                                           │
│  → Diseña para 375px primero, luego escala                       │
│  → Menos es más: prioriza contenido                              │
│                                                                  │
│  THUMB ZONE:                                                     │
│  Arriba = difícil | Medio = alcanzable | Abajo = natural         │
│  → CTAs y nav principales ABAJO                                  │
│                                                                  │
│  TOUCH TARGETS:                                                  │
│  Mínimo: 44×44px (Apple) / 48×48dp (Google)                     │
│  Spacing entre targets: ≥ 8px                                    │
│                                                                  │
│  TIPOGRAFÍA:                                                     │
│  Body: 16px mínimo (< 16px = zoom en iOS Safari)                │
│  Labels: 14px | Captions: 12px | Headings: 20-32px              │
│  Line height: 1.4-1.6× | Line length: 35-45 chars              │
│                                                                  │
│  GRID:                                                           │
│  Phone: 4 cols, 16px margin, 16px gap                            │
│  Tablet: 8 cols, 24-32px margin                                  │
│                                                                  │
│  SAFE AREAS:                                                     │
│  → Respetar notch, dynamic island, home indicator                │
│  → env(safe-area-inset-top/bottom)                               │
│                                                                  │
│  NAVEGACIÓN:                                                     │
│  3-5 items → Bottom navigation                                   │
│  + secundarias → Hamburger drawer                                │
│  Dentro de secciones → Navigation stack                          │
│  ← Back siempre visible en pantallas secundarias                 │
│                                                                  │
│  FORMULARIOS:                                                    │
│  → Mínimos campos posibles                                      │
│  → input type correcto → teclado correcto                        │
│  → autocomplete habilitado                                       │
│  → Social login / biométricos                                    │
│  → Multi-step para 5+ campos                                    │
│  → CTA sticky en bottom                                          │
│                                                                  │
│  FEEDBACK:                                                       │
│  < 100ms → Instantáneo (no mostrar nada)                         │
│  100ms-1s → Spinner sutil                                        │
│  1-3s → Skeleton screen                                          │
│  > 3s → Progress bar                                             │
│  > 10s → Background + notificación                               │
│                                                                  │
│  GESTOS:                                                         │
│  → Siempre alternativa visible (no solo gestos ocultos)          │
│  → No reinterpretar gestos del sistema                           │
│  → Tap, swipe, long press = estándar                             │
│                                                                  │
│  PERFORMANCE:                                                    │
│  → TTI < 3 segundos                                              │
│  → WebP/AVIF + srcset + lazy loading                             │
│  → Skeleton > Spinner para cargas > 1s                           │
│                                                                  │
│  ANTI-PATRONES:                                                  │
│  ❌ Hamburger como única nav        ❌ Body text < 16px           │
│  ❌ Touch targets < 44px            ❌ Scroll horizontal oculto  │
│  ❌ Sin safe areas                  ❌ Sin estados (loading/error)│
│  ❌ Desktop layout en mobile        ❌ Gestos sin alternativa    │
│  ❌ Carga > 3s sin feedback         ❌ Labels inline en mobile   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Errores Comunes y Decisiones Incorrectas

| # | Error | Por qué es malo | Solución |
|---|---|---|---|
| 1 | Desktop layout "encogido" en mobile | Texto ilegible, targets pequeños, scroll horizontal | Mobile-first: diseñar para 375px primero |
| 2 | Touch targets < 44px | Taps imprecisos, frustración | Mínimo 44×44px con 8px gap |
| 3 | Body text < 16px | Zoom automático en iOS, ilegibilidad | Mínimo 16px para body text |
| 4 | Hamburger como única navegación | 50% menos uso de secciones ocultas | Bottom nav para secciones principales |
| 5 | CTA principal arriba de la pantalla | Fuera de thumb zone, difícil de alcanzar | CTA al fondo, full-width, sticky |
| 6 | No respetar safe areas | Contenido oculto por notch/home indicator | `env(safe-area-inset-*)` |
| 7 | Input type="text" para email/teléfono | Teclado genérico, más errores | `type="email"`, `type="tel"`, `inputmode` |
| 8 | Sin estados de loading/error/empty | App parece "rota" cuando carga o falla | Diseñar los 10 estados por pantalla |
| 9 | Gestos ocultos como única interacción | Nadie los descubre | Siempre ofrecer alternativa visible |
| 10 | No testear en dispositivos reales | Emulador no captura ergonomía, performance real | Testear en iPhone SE + phone estándar + Android mid |
| 11 | Ignorar offline state | App inútil sin conexión = usuario frustrado | Offline-first: cachear + permitir acciones offline |
| 12 | Scroll horizontal para contenido principal | El usuario no sabe que hay más a la derecha | Scroll vertical siempre; horizontal solo con indicadores |

---

> **Referencia rápida de tamaños:**
> - iPhone SE: 375 × 667 (pantalla más pequeña activa)
> - iPhone 14/15: 393 × 852
> - iPhone 14/15 Pro Max: 430 × 932
> - Galaxy S24: 360 × 780
> - iPad: 768 × 1024
> - iPad Pro 11": 834 × 1194
> - Safe area top (iPhone con Dynamic Island): ~59px
> - Safe area bottom (home indicator): ~34px
> - Bottom nav height: ~49pt (iOS) / ~80dp (Android)
