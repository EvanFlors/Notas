# Maquetación: Wireframing, Layouts y Diseño Responsive

> *"Content precedes design. Design in the absence of content is not design, it's decoration."*
> — Jeffrey Zeldman

---

## Tabla de Contenidos

### Parte I — Wireframing
- [1. ¿Qué es un wireframe?](#1-qué-es-un-wireframe)
  - [1.1 Definición profesional](#11-definición-profesional)
  - [1.2 Qué es y qué NO es un wireframe](#12-qué-es-y-qué-no-es-un-wireframe)
- [2. Niveles de fidelidad](#2-niveles-de-fidelidad)
  - [2.1 Low-fidelity](#21-low-fidelity)
  - [2.2 Mid-fidelity](#22-mid-fidelity)
  - [2.3 High-fidelity](#23-high-fidelity)
  - [2.4 Matriz comparativa de fidelidad](#24-matriz-comparativa-de-fidelidad)
- [3. Anatomía de una Landing Page](#3-anatomía-de-una-landing-page)
  - [3.1 Componentes estándar](#31-componentes-estándar)
  - [3.2 Wireframe completo de landing](#32-wireframe-completo-de-landing)
- [4. Patrones de lectura en layout](#4-patrones-de-lectura-en-layout)
  - [4.1 Z-Pattern](#41-z-pattern)
  - [4.2 F-Pattern](#42-f-pattern)
  - [4.3 Cuándo usar cada uno](#43-cuándo-usar-cada-uno)
- [5. Principios de wireframing](#5-principios-de-wireframing)
- [6. Proceso de wireframing](#6-proceso-de-wireframing)
- [7. Errores comunes en wireframing](#7-errores-comunes-en-wireframing)

### Parte II — Layouts y Patrones de Diseño
- [8. Tipos de layout](#8-tipos-de-layout)
  - [8.1 Columna única](#81-columna-única)
  - [8.2 Múltiples columnas](#82-múltiples-columnas)
  - [8.3 Split screen (pantalla dividida)](#83-split-screen-pantalla-dividida)
  - [8.4 Grid-based](#84-grid-based)
  - [8.5 Modular (cards)](#85-modular-cards)
- [9. Patrones de secciones](#9-patrones-de-secciones)
  - [9.1 Hero Section](#91-hero-section)
  - [9.2 Features en grid](#92-features-en-grid)
  - [9.3 Alternating layout (zig-zag)](#93-alternating-layout-zig-zag)
  - [9.4 Prueba social](#94-prueba-social)
  - [9.5 CTA repetido](#95-cta-repetido)
- [10. Principios clave de layout](#10-principios-clave-de-layout)
- [11. Grid system práctico](#11-grid-system-práctico)
- [12. Cómo elegir el layout correcto](#12-cómo-elegir-el-layout-correcto)
- [13. Proceso de diseño de layout](#13-proceso-de-diseño-de-layout)
- [14. Errores comunes en layout](#14-errores-comunes-en-layout)

### Parte III — Diseño Responsive (Mobile-First)
- [15. ¿Qué es diseño responsive?](#15-qué-es-diseño-responsive)
  - [15.1 Definición y concepto](#151-definición-y-concepto)
  - [15.2 Responsive vs Adaptive](#152-responsive-vs-adaptive)
- [16. Enfoque mobile-first](#16-enfoque-mobile-first)
- [17. Breakpoints](#17-breakpoints)
- [18. Layouts responsive por dispositivo](#18-layouts-responsive-por-dispositivo)
- [19. Adaptación de componentes](#19-adaptación-de-componentes)
- [20. Grid responsive](#20-grid-responsive)
- [21. Patrones responsive](#21-patrones-responsive)
- [22. Performance en responsive](#22-performance-en-responsive)
- [23. Proceso de diseño mobile-first](#23-proceso-de-diseño-mobile-first)
- [24. Errores comunes en responsive](#24-errores-comunes-en-responsive)

---

# Parte I — Wireframing

---

# 1. ¿Qué es un wireframe?

---

## 1.1 Definición profesional

Un **wireframe** es una representación esquemática de baja a media fidelidad de una interfaz. Funciona como el plano arquitectónico de una pantalla: define **qué contenido va**, **dónde va** y **cómo se organiza**, sin preocuparse por el diseño visual final.

Es la herramienta que conecta la estrategia con el diseño. Traduce objetivos de negocio y necesidades del usuario en una estructura visual concreta.

```
ESTRATEGIA          WIREFRAME            DISEÑO VISUAL
(qué y por qué) → (dónde y cómo) → (cómo se ve)

  Brief              Estructura            Mockup
  Research           Layout                Colores
  User stories       Jerarquía             Tipografía
  IA                 Contenido             Componentes
```

---

## 1.2 Qué es y qué NO es un wireframe

| ✅ Un wireframe ES                          | ❌ Un wireframe NO ES                      |
|---------------------------------------------|---------------------------------------------|
| Estructura y jerarquía de contenido          | Diseño visual final                         |
| Mapa de componentes y su posición            | Mockup con colores y tipografía real        |
| Herramienta de comunicación y validación     | Prototipo interactivo completo              |
| Base para iterar rápido                      | Entregable final para el cliente            |
| Decisión sobre qué incluir y qué excluir    | Ejercicio artístico o estético              |

> **Regla fundamental:** Un wireframe se evalúa por su claridad estructural, no por su apariencia visual.

---

# 2. Niveles de fidelidad

---

## 2.1 Low-fidelity (baja fidelidad)

### Características

- Formas básicas: rectángulos, líneas, X para imágenes
- Sin texto real (lorem ipsum o líneas)
- Sin colores ni tipografía definida
- Rápido de crear (papel, pizarra, herramienta básica)

### Cuándo usarlo

- Fase inicial de exploración
- Brainstorming de estructura
- Cuando necesitas iterar rápido (5-10 versiones)

### Ejemplo ASCII

```
┌──────────────────────────────────────┐
│  [LOGO]           [NAV] [NAV] [NAV] │
├──────────────────────────────────────┤
│                                      │
│  ─────────────────────               │
│  ─────────────                       │
│                                      │
│  [ ████████ ]                        │
│                                      │
├──────────────────────────────────────┤
│  ┌────┐  ┌────┐  ┌────┐             │
│  │ X  │  │ X  │  │ X  │             │
│  │────│  │────│  │────│             │
│  │    │  │    │  │    │             │
│  └────┘  └────┘  └────┘             │
├──────────────────────────────────────┤
│  ───────────                         │
│  [ ████████ ]                        │
└──────────────────────────────────────┘
```

---

## 2.2 Mid-fidelity (media fidelidad)

### Características

- Contenido más definido (títulos reales, copy placeholder)
- Espaciado y proporciones más precisas
- Componentes reconocibles (botones, inputs, cards)
- Sin colores ni estilos finales

### Cuándo usarlo

- Validación de estructura con stakeholders
- Definición de contenido y jerarquía
- Base para testing temprano

### Ejemplo ASCII

```
┌──────────────────────────────────────────┐
│  Logo       Inicio  Servicios  Contacto  │
├──────────────────────────────────────────┤
│                                          │
│  Simplifica tu gestión                   │
│  de proyectos                            │
│                                          │
│  Herramienta diseñada para               │
│  equipos que quieren resultados.         │
│                                          │
│  [ Empieza gratis ]   Ver demo →         │
│                                          │
├──────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │  ⚡       │ │  📊       │ │  🔒       │ │
│  │ Rápido   │ │ Analítica│ │ Seguro   │ │
│  │ Desc...  │ │ Desc...  │ │ Desc...  │ │
│  └──────────┘ └──────────┘ └──────────┘ │
├──────────────────────────────────────────┤
│  "Testimonial del cliente..."            │
│   — Nombre, Empresa                      │
└──────────────────────────────────────────┘
```

---

## 2.3 High-fidelity (alta fidelidad)

### Características

- Contenido final (copy real)
- Tipografía, colores y estilos definidos
- Componentes completos con estados
- Interacciones básicas posibles

### Cuándo usarlo

- Presentación a cliente/stakeholders
- Handoff a desarrollo
- Testing de usabilidad detallado

---

## 2.4 Matriz comparativa de fidelidad

| Aspecto              | Low-fi              | Mid-fi               | High-fi              |
|---------------------|----------------------|-----------------------|----------------------|
| Tiempo de creación  | Minutos              | Horas                 | Días                 |
| Detalle visual      | Mínimo               | Moderado              | Completo             |
| Contenido           | Placeholder          | Semi-real             | Final                |
| Iteraciones         | Muy rápidas          | Moderadas             | Costosas             |
| Herramientas        | Papel, pizarra       | Figma, Balsamiq       | Figma, Sketch        |
| Stakeholder review  | Interno              | Equipo + cliente      | Aprobación final     |
| Testing             | Conceptual           | Usabilidad básica     | Usabilidad completa  |

> **Regla:** Empieza siempre en low-fi. Sube la fidelidad solo cuando la estructura esté validada.

---

# 3. Anatomía de una Landing Page

---

## 3.1 Componentes estándar

Toda landing page profesional contiene estos bloques (en orden estratégico):

| # | Componente          | Función                                           |
|---|--------------------|----------------------------------------------------|
| 1 | Hero Section       | Captar atención + comunicar propuesta de valor     |
| 2 | Beneficios         | Mostrar qué gana el usuario                        |
| 3 | Prueba social      | Generar confianza (testimonios, logos, datos)       |
| 4 | Cómo funciona      | Reducir incertidumbre sobre el proceso             |
| 5 | Features/Contenido | Detallar capacidades del producto/servicio          |
| 6 | Pricing (opcional) | Mostrar planes y precios                            |
| 7 | FAQ (opcional)     | Resolver objeciones comunes                         |
| 8 | CTA final          | Reforzar la conversión al final del scroll          |
| 9 | Footer             | Links legales, redes, contacto                      |

---

## 3.2 Wireframe completo de landing

```
┌─────────────────────────────────────────────────────┐
│  NAVBAR                                              │
│  Logo           Nav1  Nav2  Nav3    [ CTA Header ]   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────┐  ┌───────────────────────┐ │
│  │  H1: Propuesta      │  │                       │ │
│  │  de valor            │  │    Hero Image /       │ │
│  │                      │  │    Ilustración        │ │
│  │  Subtítulo           │  │                       │ │
│  │                      │  │                       │ │
│  │  [ CTA Primario ]   │  │                       │ │
│  │  CTA Secundario →   │  │                       │ │
│  └─────────────────────┘  └───────────────────────┘ │
│                                                      │
│  Logos de clientes: ○ ○ ○ ○ ○                       │
│                                                      │
├─────────────────────────────────────────────────────┤
│  BENEFICIOS                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Icono    │  │ Icono    │  │ Icono    │          │
│  │ Título   │  │ Título   │  │ Título   │          │
│  │ Desc     │  │ Desc     │  │ Desc     │          │
│  └──────────┘  └──────────┘  └──────────┘          │
├─────────────────────────────────────────────────────┤
│  CÓMO FUNCIONA                                       │
│  ① Paso 1  →  ② Paso 2  →  ③ Paso 3               │
├─────────────────────────────────────────────────────┤
│  ZIG-ZAG FEATURES                                    │
│  ┌─────────────────┐  ┌────────────────────┐        │
│  │  Texto Feature1 │  │  Imagen Feature1   │        │
│  └─────────────────┘  └────────────────────┘        │
│  ┌────────────────────┐  ┌─────────────────┐        │
│  │  Imagen Feature2   │  │  Texto Feature2 │        │
│  └────────────────────┘  └─────────────────┘        │
├─────────────────────────────────────────────────────┤
│  PRUEBA SOCIAL                                       │
│  ┌────────────────────────────────────────────┐     │
│  │  "Testimonio del cliente que genera        │     │
│  │   confianza y valida el producto."         │     │
│  │   — Nombre, Cargo, Empresa                 │     │
│  └────────────────────────────────────────────┘     │
│  ★★★★★  +2,500 usuarios activos                    │
├─────────────────────────────────────────────────────┤
│  CTA FINAL (refuerzo)                                │
│  Título de cierre + [ CTA Primario ]                 │
├─────────────────────────────────────────────────────┤
│  FOOTER                                              │
│  Links │ Legal │ Redes │ © 2024                      │
└─────────────────────────────────────────────────────┘
```

---

# 4. Patrones de lectura en layout

---

## 4.1 Z-Pattern

### Concepto

El ojo sigue un recorrido en forma de Z: de izquierda a derecha en la parte superior, luego en diagonal hacia abajo a la izquierda, y de nuevo de izquierda a derecha en la parte inferior.

### Diagrama

```
┌────────────────────────────────────┐
│  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━→ ●  │  ← Barra superior (logo → CTA)
│       ↘                            │
│            ↘                       │  ← Diagonal (contenido central)
│                 ↘                  │
│  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━→ ●  │  ← Zona inferior (texto → CTA)
└────────────────────────────────────┘
```

### Aplicación práctica

```
Logo ──────────────── Menú / CTA header
          ↘
        Headline + propuesta de valor
          ↘
Imagen/Visual ──────── Botón CTA principal
```

### Ideal para

- Landing pages simples
- Páginas con poco contenido
- Cualquier diseño que necesite guiar hacia UN CTA

---

## 4.2 F-Pattern

### Concepto

El ojo escanea horizontalmente en la parte superior, luego una segunda línea horizontal más corta, y después escanea verticalmente por el lado izquierdo.

### Diagrama

```
┌────────────────────────────────────┐
│  █████████████████████████████████ │  ← Primera lectura horizontal
│  █████████████████████████████████ │
│                                    │
│  ████████████████████              │  ← Segunda lectura (más corta)
│  ████████████████                  │
│                                    │
│  █████████                         │  ← Escaneo vertical izquierdo
│  ████████                          │
│  ██████                            │
│  █████                             │
└────────────────────────────────────┘
```

### Ideal para

- Blogs y artículos
- Páginas con mucho texto
- Documentación
- Resultados de búsqueda

---

## 4.3 Cuándo usar cada uno

| Patrón    | Tipo de contenido               | Ejemplo                          |
|----------|---------------------------------|----------------------------------|
| Z-Pattern | Poco contenido, conversión     | Landing page, hero section       |
| F-Pattern | Mucho texto, información       | Blog, docs, listados             |
| Gutenberg | Lectura natural (4 cuadrantes) | Páginas de texto puro            |

---

# 5. Principios de wireframing

| Principio          | Descripción                                                    |
|-------------------|----------------------------------------------------------------|
| Jerarquía visual  | Lo más importante debe ser lo más visible                      |
| Simplicidad       | Solo incluir lo necesario — cada elemento justifica su espacio |
| User flow primero | El wireframe sigue el flujo del usuario, no la estética        |
| Consistencia      | Mismos patrones y componentes en todas las pantallas           |
| Contenido real    | Usar contenido real (o representativo) lo antes posible        |
| Mobile-first      | Comenzar por la versión más restringida                        |

> **Regla:** Si no puedes explicar por qué un elemento está en el wireframe, probablemente no debería estar.

---

# 6. Proceso de wireframing

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROCESO DE WIREFRAMING                        │
│                                                                  │
│  1. DEFINIR CONTENIDO                                            │
│     └─ Lista de bloques necesarios + contenido por bloque        │
│            ↓                                                     │
│  2. PRIORIZAR                                                    │
│     └─ Ordenar bloques según importancia para el objetivo        │
│            ↓                                                     │
│  3. SKETCHING (low-fi)                                           │
│     └─ 3-5 variantes rápidas en papel o pizarra                 │
│            ↓                                                     │
│  4. SELECCIONAR MEJOR OPCIÓN                                     │
│     └─ Elegir la estructura que mejor sirve al objetivo          │
│            ↓                                                     │
│  5. DIGITALIZAR (mid-fi)                                         │
│     └─ Pasar a herramienta digital con más detalle               │
│            ↓                                                     │
│  6. VALIDAR                                                      │
│     └─ Revisar con equipo, stakeholders o usuarios               │
│            ↓                                                     │
│  7. ITERAR                                                       │
│     └─ Ajustar basándose en feedback antes de pasar a UI         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

# 7. Errores comunes en wireframing

| Error                                        | Consecuencia                                  | Solución                               |
|---------------------------------------------|-----------------------------------------------|----------------------------------------|
| Pasar directo a high-fi                      | Pérdida de tiempo en cambios costosos         | Empezar siempre en low-fi              |
| Diseñar sin definir contenido                | Estructura que no sirve al contenido real     | Content-first: definir qué va antes    |
| Ignorar el flujo del usuario                 | Interfaz confusa y sin dirección              | Mapear user flow antes de wireframear  |
| Enfocarse en estética                        | Wireframes "bonitos" que no resuelven         | Wireframe = estructura, no arte        |
| No incluir estados                           | Se olvidan vacíos, errores, carga             | Wireframear todos los estados clave    |
| Crear solo una versión                       | Se pierde exploración de alternativas         | Crear mínimo 2-3 variantes            |
| No validar con usuarios o equipo             | Supuestos no probados                         | Testing temprano con wireframes        |

---

# Parte II — Layouts y Patrones de Diseño

---

# 8. Tipos de layout

---

## 8.1 Columna única

### Estructura

Todo el contenido se organiza en una sola columna vertical.

```
┌──────────────────────┐
│      Navbar          │
├──────────────────────┤
│                      │
│      Hero            │
│                      │
├──────────────────────┤
│      Sección 1       │
├──────────────────────┤
│      Sección 2       │
├──────────────────────┤
│      CTA             │
├──────────────────────┤
│      Footer          │
└──────────────────────┘
```

### Ideal para

- Landing pages
- Blogs / artículos
- Funnels de conversión
- Mobile (por defecto)

### Ventajas

- Flujo de lectura claro y natural
- Ideal para mobile
- Mínima distracción
- Fuerza la priorización de contenido

---

## 8.2 Múltiples columnas

### Estructura

Contenido distribuido en 2 o más columnas usando un grid.

```
┌──────────────────────────────────────┐
│            Navbar                     │
├──────────────────────────────────────┤
│                                      │
│  ┌──────────────┐  ┌──────────────┐ │
│  │  Contenido   │  │  Sidebar     │ │
│  │  Principal   │  │              │ │
│  │              │  │  - Widget    │ │
│  │              │  │  - Filter    │ │
│  │              │  │  - Ads       │ │
│  └──────────────┘  └──────────────┘ │
├──────────────────────────────────────┤
│            Footer                     │
└──────────────────────────────────────┘
```

### Ideal para

- Dashboards y paneles administrativos
- E-commerce (productos + filtros)
- Sitios con mucha información

### Ventajas

- Mayor densidad de información
- Permite navegación secundaria (sidebar)
- Buena organización visual

---

## 8.3 Split screen (pantalla dividida)

### Estructura

La pantalla se divide en dos mitades, cada una con contenido diferente.

```
┌─────────────────┬─────────────────┐
│                 │                 │
│   Contenido A   │   Contenido B   │
│                 │                 │
│   (Texto,       │   (Imagen,      │
│    beneficios)  │    formulario)  │
│                 │                 │
│   [ CTA ]       │                 │
│                 │                 │
└─────────────────┴─────────────────┘
```

### Ideal para

- Comparaciones (antes/después, producto A vs B)
- Login / registro (formulario + branding)
- Producto vs beneficios

### Ventajas

- Contraste visual fuerte
- Claridad en decisiones binarias
- Impacto visual alto

---

## 8.4 Grid-based

### Estructura

Sistema de filas y columnas (normalmente 12 columnas) que permite combinar diferentes anchos.

```
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │
├───┴───┴───┴───┴───┴───┼───┴───┴───┴───┴───┴───┤
│     Hero Text (6)      │     Hero Image (6)     │
├───┬───┬───┬───┼───┬───┬───┬───┼───┬───┬───┬───┤
│  Feature 1 (4) │  Feature 2 (4) │  Feature 3 (4) │
├───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┤
│              Full-width CTA (12)                │
└─────────────────────────────────────────────────┘
```

### Ventajas

- Máxima flexibilidad y consistencia
- Escalable y responsive nativo
- Estándar de la industria

---

## 8.5 Modular (cards)

### Estructura

Bloques independientes (cards) que se organizan en grid.

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │
│ │ IMG  │ │  │ │ IMG  │ │  │ │ IMG  │ │
│ └──────┘ │  │ └──────┘ │  │ └──────┘ │
│ Título   │  │ Título   │  │ Título   │
│ Desc...  │  │ Desc...  │  │ Desc...  │
│ [ CTA ]  │  │ [ CTA ]  │  │ [ CTA ]  │
└──────────┘  └──────────┘  └──────────┘

┌──────────┐  ┌──────────┐  ┌──────────┐
│ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │
│ │ IMG  │ │  │ │ IMG  │ │  │ │ IMG  │ │
│ └──────┘ │  │ └──────┘ │  │ └──────┘ │
│ Título   │  │ Título   │  │ Título   │
│ Desc...  │  │ Desc...  │  │ Desc...  │
│ [ CTA ]  │  │ [ CTA ]  │  │ [ CTA ]  │
└──────────┘  └──────────┘  └──────────┘
```

### Ideal para

- Features / servicios
- Productos (e-commerce)
- Blog posts
- Portfolios

### Ventajas

- Altamente reutilizable
- Flexible (se reorganiza en responsive)
- Cada card es independiente

---

# 9. Patrones de secciones

---

## 9.1 Hero Section

La primera sección visible. Define la primera impresión.

### Variantes principales

```
VARIANTE A — Split (texto + imagen):
┌─────────────────┬─────────────────┐
│  H1             │                 │
│  Subtítulo      │  [Imagen/Video] │
│  [ CTA ]        │                 │
└─────────────────┴─────────────────┘

VARIANTE B — Centrado:
┌─────────────────────────────────────┐
│              H1 centrado            │
│           Subtítulo centrado        │
│           [ CTA ] [ CTA 2 ]        │
│                                     │
│           [Imagen centrada]         │
└─────────────────────────────────────┘

VARIANTE C — Full background:
┌─────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░░░░░░░░ H1 sobre imagen ░░░░░░░░ │
│ ░░░░░░░░ Subtítulo ░░░░░░░░░░░░░░ │
│ ░░░░░░░░ [ CTA ] ░░░░░░░░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────┘
```

---

## 9.2 Features en grid

```
┌──────────────────────────────────────┐
│         Título de sección            │
│         Subtítulo                    │
│                                      │
│  ┌────────┐  ┌────────┐  ┌────────┐ │
│  │ Icono  │  │ Icono  │  │ Icono  │ │
│  │ Título │  │ Título │  │ Título │ │
│  │ Desc   │  │ Desc   │  │ Desc   │ │
│  └────────┘  └────────┘  └────────┘ │
│                                      │
│  ┌────────┐  ┌────────┐  ┌────────┐ │
│  │ Icono  │  │ Icono  │  │ Icono  │ │
│  │ Título │  │ Título │  │ Título │ │
│  │ Desc   │  │ Desc   │  │ Desc   │ │
│  └────────┘  └────────┘  └────────┘ │
└──────────────────────────────────────┘

Responsive:
Desktop  → 3 columnas
Tablet   → 2 columnas
Mobile   → 1 columna
```

---

## 9.3 Alternating layout (zig-zag)

Secciones que alternan la posición de texto e imagen:

```
Sección 1:
┌─────────────────┬─────────────────┐
│  Texto          │  Imagen         │
│  Feature 1      │                 │
│  Descripción    │                 │
└─────────────────┴─────────────────┘

Sección 2 (invertida):
┌─────────────────┬─────────────────┐
│  Imagen         │  Texto          │
│                 │  Feature 2      │
│                 │  Descripción    │
└─────────────────┴─────────────────┘
```

**Uso:** Explicaciones progresivas de features o beneficios.

---

## 9.4 Prueba social

```
VARIANTE A — Testimonios:
┌─────────────────────────────────────────┐
│  "Texto del testimonio..."              │
│   ★★★★★                                │
│   Foto │ Nombre │ Cargo │ Empresa       │
└─────────────────────────────────────────┘

VARIANTE B — Logos de clientes:
┌─────────────────────────────────────────┐
│  Empresas que confían en nosotros:      │
│  [Logo1] [Logo2] [Logo3] [Logo4] [Logo5]│
└─────────────────────────────────────────┘

VARIANTE C — Datos / Métricas:
┌──────────┬──────────┬──────────┐
│  +10K    │  98%     │  4.9★    │
│ Usuarios │ Satisf.  │ Rating   │
└──────────┴──────────┴──────────┘
```

---

## 9.5 CTA repetido

El CTA principal debe repetirse después de cada sección clave:

```
Hero      → [ CTA ]
Features  → [ CTA ]
Social    → [ CTA ]
Pricing   → [ CTA ]
Footer    → [ CTA ]
```

> **Objetivo:** Reducir la fricción de conversión. El usuario no debería tener que buscar el botón.

---

# 10. Principios clave de layout

| Principio        | Descripción                                                   |
|-----------------|---------------------------------------------------------------|
| Jerarquía visual| Controlar tamaño, posición, contraste y espaciado             |
| Alineación      | Todo elemento alineado a un sistema (grid, columnas)          |
| Proximidad      | Elementos relacionados deben estar cerca (Ley de Gestalt)     |
| Whitespace      | Separar bloques, mejorar legibilidad, evitar saturación       |
| Consistencia    | Repetir espaciados, tamaños y componentes en todo el diseño   |

---

# 11. Grid system práctico

### Grid de 12 columnas

| Dispositivo | Columnas | Gutter  | Margin     |
|------------|----------|---------|------------|
| Desktop    | 12       | 24-32px | 48-80px    |
| Tablet     | 6-8      | 16-24px | 24-48px    |
| Mobile     | 4        | 16px    | 16-24px    |

### Distribuciones comunes

```
50/50:   │◄───── 6 col ─────►│◄───── 6 col ─────►│
Tercios: │◄── 4 col ──►│◄── 4 col ──►│◄── 4 col ──►│
70/30:   │◄──────── 8 col ────────►│◄── 4 col ──►│
Full:    │◄────────────── 12 col ──────────────►│
```

---

# 12. Cómo elegir el layout correcto

### Según objetivo

| Objetivo                 | Layout recomendado              |
|-------------------------|---------------------------------|
| Conversión              | Columna única + Z-pattern       |
| Exploración             | Grid / cards                    |
| Información densa       | Multi-columna + sidebar         |
| Comparación             | Split screen                    |
| Productividad           | Dashboard (sidebar + contenido) |

### Según tipo de contenido

| Contenido               | Layout recomendado              |
|-------------------------|---------------------------------|
| Mucho texto             | F-pattern + columna única       |
| Visual / productos      | Cards / grid                    |
| Datos / métricas        | Dashboard + tablas              |
| Formularios             | Columna única centrada          |

### Según complejidad

| Complejidad             | Layout recomendado              |
|-------------------------|---------------------------------|
| Simple (pocas secciones)| Lineal / columna única          |
| Media (varias secciones)| Grid con variaciones            |
| Alta (mucha data)       | Modular + sidebar + búsqueda    |

---

# 13. Proceso de diseño de layout

```
1. DEFINIR CONTENIDO          → Lista de bloques y su contenido
       ↓
2. PRIORIZAR                  → Ordenar por importancia de negocio
       ↓
3. ELEGIR PATRÓN              → Z-pattern, F-pattern, Grid, etc.
       ↓
4. APLICAR GRID               → Definir columnas, gutters, margins
       ↓
5. WIREFRAMEAR                → Crear estructura low-fi / mid-fi
       ↓
6. ITERAR VARIANTES           → Crear Variante A (clásica) y Variante B (alternativa)
       ↓
7. VALIDAR                    → Test con equipo / usuarios
       ↓
8. ESCALAR A RESPONSIVE       → Adaptar a tablet y mobile
```

---

# 14. Errores comunes en layout

| Error                                    | Consecuencia                          |
|-----------------------------------------|---------------------------------------|
| Usar patrones sin entender su propósito | Layout que no sirve al objetivo       |
| Romper alineaciones del grid            | Diseño desordenado y amateur          |
| Sobrecargar con columnas               | Interfaz saturada y confusa           |
| No adaptar a mobile                     | Pérdida del 50%+ del tráfico          |
| Falta de consistencia entre secciones   | Experiencia fragmentada               |
| Ignorar whitespace                      | Interfaz apretada y difícil de leer   |

---

# Parte III — Diseño Responsive (Mobile-First)

---

# 15. ¿Qué es diseño responsive?

---

## 15.1 Definición y concepto

**Diseño responsive** es la capacidad de una interfaz para adaptarse a diferentes tamaños de pantalla, manteniendo usabilidad, legibilidad y claridad en todos los dispositivos.

No se trata de "hacer que se vea bien en mobile". Se trata de que la **experiencia sea correcta** en cada contexto.

---

## 15.2 Responsive vs Adaptive

| Aspecto              | Responsive                        | Adaptive                          |
|---------------------|-----------------------------------|-----------------------------------|
| Comportamiento      | Layout fluido que se adapta       | Layouts fijos por dispositivo     |
| Breakpoints         | El contenido decide los quiebres  | Dispositivos dictan los quiebres  |
| Flexibilidad        | Alta — se adapta a cualquier ancho| Media — diseños predefinidos      |
| Complejidad         | Moderada                          | Mayor (múltiples versiones)       |
| Estándar actual     | ✅ Preferido                       | Menos común                       |

---

# 16. Enfoque mobile-first

### Concepto

Diseñar primero para la pantalla más pequeña y restringida, luego **escalar hacia arriba**.

### Por qué mobile-first

| Razón                   | Explicación                                            |
|------------------------|--------------------------------------------------------|
| Obliga a priorizar     | En mobile no cabe todo → fuerza a elegir lo esencial  |
| Reduce complejidad     | Empezar simple → añadir complejidad es más fácil      |
| Mejor performance      | Menos recursos → carga más rápida                     |
| Mayoría de tráfico     | 50-70% del tráfico web es mobile                       |
| Mejor UX base          | Si funciona en mobile, funciona en todos lados        |

### Regla clave

```
MOBILE-FIRST:
Primero: Contenido esencial (qué NECESITA ver el usuario)
Después: Mejoras visuales y estructurales (qué PUEDE ver)
```

---

# 17. Breakpoints

### Breakpoints estándar

| Nombre         | Rango             | Columnas típicas |
|---------------|-------------------|------------------|
| Mobile (sm)   | 320px – 480px     | 4                |
| Tablet (md)   | 481px – 768px     | 6-8              |
| Laptop (lg)   | 769px – 1024px    | 12               |
| Desktop (xl)  | 1025px – 1440px   | 12               |
| Wide (2xl)    | 1441px+           | 12               |

### Buenas prácticas

- Basarse en **contenido**, no solo en dispositivos — el breakpoint es donde el contenido "se rompe"
- Evitar demasiados breakpoints (3-4 son suficientes)
- Testear en dispositivos reales, no solo en simuladores

---

# 18. Layouts responsive por dispositivo

```
MOBILE (320-480px):              TABLET (481-768px):
┌──────────────────┐             ┌─────────────────────────┐
│    Navbar        │             │    Navbar               │
├──────────────────┤             ├────────────┬────────────┤
│    Hero          │             │            │            │
│    (stacked)     │             │   Col 1    │   Col 2    │
├──────────────────┤             │            │            │
│    Sección 1     │             ├────────────┴────────────┤
├──────────────────┤             │    Sección completa     │
│    Sección 2     │             ├────────────┬────────────┤
├──────────────────┤             │   Col 1    │   Col 2    │
│    Sección 3     │             └────────────┴────────────┘
├──────────────────┤
│    Footer        │
└──────────────────┘

DESKTOP (1025px+):
┌───────────────────────────────────────────────────┐
│    Navbar                                          │
├───────────────────────┬───────────────────────────┤
│    Hero Text          │    Hero Image             │
├───────────┬───────────┼───────────┬───────────────┤
│  Col 1    │  Col 2    │  Col 3    │  Col 4        │
├───────────┴───────────┴───────────┴───────────────┤
│    Full-width section                              │
└───────────────────────────────────────────────────┘
```

---

# 19. Adaptación de componentes

| Componente   | Mobile                              | Desktop                             |
|-------------|--------------------------------------|--------------------------------------|
| Texto       | Más corto y directo                  | Más descriptivo                      |
| Imágenes    | Optimizadas, simples                 | Más detalladas, mayor resolución     |
| Botones     | Grandes (44px+ height), full-width   | Más compactos, inline                |
| Navegación  | Hamburger menu                       | Menú horizontal completo             |
| Cards       | Stacked (1 por fila)                 | Grid (2-4 por fila)                  |
| Tablas      | Scroll horizontal o cards            | Tabla completa visible               |
| Formularios | Inputs full-width, stacked           | Inputs en grid (2 columnas)          |
| Modales     | Full-screen                          | Centrados con overlay                |

### Jerarquía adaptable

La importancia visual debe mantenerse en todos los dispositivos:

```
HERO — Mobile:              HERO — Desktop:
┌──────────────────┐        ┌─────────────┬──────────────┐
│  Título          │        │  Título     │              │
│  Subtítulo       │        │  Subtítulo  │  [Imagen]    │
│  [ CTA ]         │        │  [ CTA ]    │              │
│  [Imagen]        │        └─────────────┴──────────────┘
└──────────────────┘
```

---

# 20. Grid responsive

### Cómo colapsan las columnas

```
DESKTOP (12 cols):   │ 3 │ 3 │ 3 │ 3 │   → 4 cards por fila
TABLET (6-8 cols):   │  3  │  3  │        → 2 cards por fila
MOBILE (4 cols):     │    4    │           → 1 card por fila
```

### Ejemplo: Features section

| Dispositivo | Layout                     | Columnas usadas |
|------------|----------------------------|-----------------|
| Desktop    | 4 features por fila         | 3 cols c/u      |
| Tablet     | 2 features por fila         | 4 cols c/u      |
| Mobile     | 1 feature por fila (stacked)| 4 cols (full)   |

---

# 21. Patrones responsive

| Patrón       | Descripción                                    | Uso                              |
|-------------|------------------------------------------------|----------------------------------|
| Stack       | Apilar elementos verticalmente                  | Cards, features en mobile        |
| Hide/Show   | Ocultar secundarios en mobile, mostrar en desktop| Sidebar, elementos extra         |
| Reflow      | Cambiar disposición sin eliminar contenido      | Grid → stack                     |
| Resize      | Ajustar tamaños sin cambiar estructura          | Imágenes, tipografía             |
| Overflow    | Scroll horizontal para contenido que no cabe    | Tablas, carruseles               |

---

# 22. Performance en responsive

### Por qué importa especialmente en mobile

| Factor               | Mobile                     | Desktop                    |
|---------------------|----------------------------|----------------------------|
| Velocidad de red    | Más lenta (3G/4G)          | Más rápida (WiFi/fibra)   |
| Procesador          | Menor capacidad            | Mayor capacidad            |
| Batería             | Limitada                   | No es factor               |
| Paciencia           | Menor                      | Mayor                      |

### Buenas prácticas

- Optimizar imágenes (WebP, AVIF, lazy loading)
- Evitar JavaScript pesado en mobile
- Priorizar Above the Fold content
- Usar formatos responsivos (srcset)
- Minimizar requests HTTP

---

# 23. Proceso de diseño mobile-first

```
┌─────────────────────────────────────────────────┐
│              PROCESO MOBILE-FIRST                │
│                                                  │
│  1. Definir contenido esencial                   │
│     └─ ¿Qué NECESITA ver el usuario en mobile?  │
│            ↓                                     │
│  2. Diseñar layout mobile                        │
│     └─ 1 columna, priorizado, esencial           │
│            ↓                                     │
│  3. Validar flujo y jerarquía                    │
│     └─ ¿El usuario puede completar su tarea?    │
│            ↓                                     │
│  4. Escalar a tablet                             │
│     └─ Añadir columnas, expandir contenido       │
│            ↓                                     │
│  5. Escalar a desktop                            │
│     └─ Grid completo, mayor densidad visual      │
│            ↓                                     │
│  6. Refinar detalles visuales                    │
│     └─ Animaciones, hover states, extras          │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

# 24. Errores comunes en responsive

| Error                                     | Consecuencia                                |
|------------------------------------------|---------------------------------------------|
| Diseñar desktop primero                   | Mobile termina siendo una versión recortada |
| Ocultar contenido importante en mobile    | Usuario mobile no puede completar tareas    |
| Botones demasiado pequeños               | Imposible hacer tap (mínimo 44x44px)        |
| Ignorar spacing en mobile                | Interfaz comprimida y difícil de leer       |
| No probar en dispositivos reales         | Bugs que solo aparecen en hardware real     |
| Imágenes sin optimizar                   | Carga lenta → abandono                      |
| Menú hamburguesa abusado                 | Esconder navegación importante              |
| Texto idéntico en mobile y desktop       | Mobile necesita copy más conciso            |

---

> *"Mobile is not a small screen. It's a different context entirely."*
> — Luke Wroblewski
