# Herramientas: Figma, Design Systems y Prototipado

> *"A design system isn't a project. It's a product, serving products."*
> — Nathan Curtis

---

## Tabla de Contenidos

### Parte I — Figma
- [1. Introducción a Figma](#1-introducción-a-figma)
  - [1.1 Qué es Figma y por qué domina](#11-qué-es-figma-y-por-qué-domina)
  - [1.2 Estructura: File → Page → Frame](#12-estructura-file--page--frame)
- [2. Auto Layout](#2-auto-layout)
  - [2.1 Concepto y modelo mental](#21-concepto-y-modelo-mental)
  - [2.2 Propiedades fundamentales](#22-propiedades-fundamentales)
  - [2.3 Buenas prácticas](#23-buenas-prácticas)
- [3. Componentes](#3-componentes)
  - [3.1 Definición y ventajas](#31-definición-y-ventajas)
  - [3.2 Estructura de un componente](#32-estructura-de-un-componente)
  - [3.3 Instancias y overrides](#33-instancias-y-overrides)
- [4. Variantes](#4-variantes)
  - [4.1 Concepto](#41-concepto)
  - [4.2 Propiedades y naming](#42-propiedades-y-naming)
  - [4.3 Variantes vs componentes separados](#43-variantes-vs-componentes-separados)
- [5. Estilos y tokens](#5-estilos-y-tokens)
- [6. Prototyping en Figma](#6-prototyping-en-figma)
  - [6.1 Conexiones e interacciones](#61-conexiones-e-interacciones)
  - [6.2 Overlays y Smart Animate](#62-overlays-y-smart-animate)
- [7. Organización y naming](#7-organización-y-naming)
- [8. Colaboración y handoff](#8-colaboración-y-handoff)
- [9. Nivel avanzado en Figma](#9-nivel-avanzado-en-figma)

### Parte II — Design Systems
- [10. ¿Qué es un Design System?](#10-qué-es-un-design-system)
  - [10.1 Definición y objetivos](#101-definición-y-objetivos)
  - [10.2 Design System ≠ UI Kit ≠ Style Guide](#102-design-system--ui-kit--style-guide)
- [11. Componentes de un Design System](#11-componentes-de-un-design-system)
  - [11.1 Tokens de diseño](#111-tokens-de-diseño)
  - [11.2 Componentes UI](#112-componentes-ui)
  - [11.3 Patrones](#113-patrones)
  - [11.4 Guías de uso (documentación)](#114-guías-de-uso-documentación)
- [12. Tipos de Design Systems](#12-tipos-de-design-systems)
- [13. Creación de un Design System](#13-creación-de-un-design-system)
  - [13.1 Auditoría inicial](#131-auditoría-inicial)
  - [13.2 Definición de tokens](#132-definición-de-tokens)
  - [13.3 Construcción de componentes](#133-construcción-de-componentes)
  - [13.4 Documentación](#134-documentación)
- [14. Escalabilidad del sistema](#14-escalabilidad-del-sistema)
- [15. Integración con desarrollo](#15-integración-con-desarrollo)
- [16. Mantenimiento y gobernanza](#16-mantenimiento-y-gobernanza)
- [17. Nivel avanzado en Design Systems](#17-nivel-avanzado-en-design-systems)

### Parte III — Prototipado e Interacción
- [18. Fundamentos del prototipado](#18-fundamentos-del-prototipado)
  - [18.1 Definición y objetivo](#181-definición-y-objetivo)
  - [18.2 Tipos de prototipos](#182-tipos-de-prototipos)
- [19. Interacciones en interfaces](#19-interacciones-en-interfaces)
  - [19.1 Tipos de interacciones](#191-tipos-de-interacciones)
  - [19.2 Estados de componentes](#192-estados-de-componentes)
  - [19.3 Feedback visual](#193-feedback-visual)
- [20. Flujos de usuario en prototipos](#20-flujos-de-usuario-en-prototipos)
- [21. Animaciones y transiciones](#21-animaciones-y-transiciones)
- [22. Testing con prototipos](#22-testing-con-prototipos)
- [23. Nivel avanzado en prototipado](#23-nivel-avanzado-en-prototipado)

---

# Parte I — Figma

---

# 1. Introducción a Figma

---

## 1.1 Qué es Figma y por qué domina

**Figma** es una herramienta de diseño de interfaces basada en navegador que permite diseñar, prototipar y colaborar en tiempo real. Es el estándar de la industria para diseño UI/UX.

### Por qué Figma es el estándar

| Ventaja                  | Descripción                                         |
|-------------------------|-----------------------------------------------------|
| Basado en navegador     | No necesita instalación, funciona en cualquier OS   |
| Colaboración en vivo    | Múltiples diseñadores trabajando al mismo tiempo    |
| Componentes + variantes | Sistema robusto para crear UI libraries              |
| Auto Layout             | Layout dinámico que se comporta como CSS Flexbox    |
| Prototyping integrado   | Prototipos interactivos sin salir de la herramienta |
| Dev Mode                | Handoff directo a desarrollo con specs exactas       |
| Plugins                 | Ecosistema extensible                               |
| Gratuito (starter)      | Plan free viable para proyectos personales          |

---

## 1.2 Estructura: File → Page → Frame

```
┌─────────────────────────────────────────────────────┐
│  FILE (Proyecto)                                     │
│  ├── PAGE: Design                                    │
│  │   ├── Frame: Home Desktop                         │
│  │   ├── Frame: Home Mobile                          │
│  │   ├── Frame: Product Page                         │
│  │   └── Frame: Checkout                             │
│  ├── PAGE: Components                                │
│  │   ├── Frame: Buttons                              │
│  │   ├── Frame: Inputs                               │
│  │   ├── Frame: Cards                                │
│  │   └── Frame: Navigation                           │
│  ├── PAGE: Prototypes                                │
│  └── PAGE: Archive                                   │
└─────────────────────────────────────────────────────┘
```

| Concepto   | Qué es                                             | Analogía                    |
|-----------|-----------------------------------------------------|-----------------------------|
| File      | El archivo del proyecto completo                    | El proyecto                 |
| Page      | Sección dentro del archivo                          | Capítulo del proyecto       |
| Frame     | Contenedor de diseño (artboard)                     | Una pantalla o componente   |
| Section   | Agrupación visual de frames dentro de una page      | Folder visual               |

---

# 2. Auto Layout

---

## 2.1 Concepto y modelo mental

**Auto Layout** es la funcionalidad de Figma que permite crear layouts dinámicos que se ajustan automáticamente al contenido. Funciona de manera similar a **CSS Flexbox**.

```
SIN AUTO LAYOUT:                    CON AUTO LAYOUT:
┌──────────────────────┐            ┌──────────────────────┐
│  [ Botón ]           │            │  [ Botón ]           │
│  (tamaño fijo)       │            │  (se adapta al texto)│
│                      │            │                      │
│  Si cambias el texto,│            │  Si cambias el texto,│
│  se rompe el layout  │            │  se ajusta solo      │
└──────────────────────┘            └──────────────────────┘
```

---

## 2.2 Propiedades fundamentales

| Propiedad              | Descripción                                    | CSS equivalente         |
|-----------------------|------------------------------------------------|-------------------------|
| Direction             | Horizontal o vertical                           | flex-direction          |
| Padding               | Espacio interno (top, right, bottom, left)      | padding                 |
| Gap (spacing)         | Espacio entre elementos hijos                   | gap                     |
| Alignment             | Alineación de hijos (start, center, end)        | align-items, justify    |
| Resizing              | Hug (ajusta al contenido) / Fill (ocupa espacio)| width: auto vs 100%    |
| Wrap                  | Los elementos pasan a la siguiente línea        | flex-wrap               |

### Diagrama de Auto Layout

```
┌─ Auto Layout (Vertical, gap: 16px, padding: 24px) ───────┐
│                                                            │
│  ┌── Child 1 (Fill Container) ──────────────────────────┐ │
│  │  Texto del headline                                  │ │
│  └──────────────────────────────────────────────────────┘ │
│                           ← 16px gap →                     │
│  ┌── Child 2 (Fill Container) ──────────────────────────┐ │
│  │  Texto descriptivo                                    │ │
│  └──────────────────────────────────────────────────────┘ │
│                           ← 16px gap →                     │
│  ┌── Child 3 (Hug Contents) ──┐                           │
│  │  [ CTA Button ]            │                           │
│  └────────────────────────────┘                           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 2.3 Buenas prácticas

| Práctica                                 | Razón                                         |
|-----------------------------------------|-----------------------------------------------|
| Usar Auto Layout en TODO                | Layouts predecibles y escalables              |
| Anidarlo (nesting)                       | Crear estructuras complejas con control       |
| Usar Fill Container para adaptabilidad   | Comportamiento responsive nativo              |
| Definir padding y gap consistentes       | Coherencia visual en todo el diseño           |
| Nombrar layers descriptivamente          | Facilita handoff y mantenimiento              |

---

# 3. Componentes

---

## 3.1 Definición y ventajas

Un **componente** en Figma es un elemento reutilizable con un master (Main Component) que controla todas sus copias (Instances).

### Ventajas

| Ventaja               | Descripción                                          |
|----------------------|------------------------------------------------------|
| Consistencia         | Un cambio en el master se propaga a todas las instances |
| Eficiencia           | Diseñar una vez, reutilizar siempre                   |
| Escalabilidad        | Facilita la construcción de UI libraries              |
| Mantenimiento        | Actualizaciones centralizadas                         |
| Handoff              | Desarrolladores entienden la estructura               |

---

## 3.2 Estructura de un componente

```
MAIN COMPONENT (◆ diamante morado):
┌──────────────────────────────────────┐
│  Button / Primary / Large            │
│  ┌──────────────────────────────┐    │
│  │  🔵  Auto Layout (horizontal) │    │
│  │  ┌──────┐  ┌──────────────┐  │    │
│  │  │ Icon │  │ Label text   │  │    │
│  │  └──────┘  └──────────────┘  │    │
│  └──────────────────────────────┘    │
│  padding: 12px 24px                  │
│  gap: 8px                            │
│  border-radius: 8px                  │
│  fill: #2563EB                       │
└──────────────────────────────────────┘

INSTANCE (◇ diamante vacío):
→ Copia del Main Component
→ Puedes hacer overrides (cambiar texto, icono, etc.)
→ Cambios en el Main se propagan a todas las instances
```

---

## 3.3 Instancias y overrides

| Concepto            | Descripción                                        |
|--------------------|----------------------------------------------------|
| Instance           | Copia vinculada al Main Component                  |
| Override           | Cambio local en una instance (texto, icono, color) |
| Detach             | Desvincula la instance del Main (⚠️ último recurso)|
| Reset              | Restaura la instance a su estado original          |
| Swap               | Cambiar un componente por otro del mismo tipo      |

### Regla

> **Nunca hagas Detach** a menos que sea absolutamente necesario. Pierdes la conexión con el sistema.

---

# 4. Variantes

---

## 4.1 Concepto

Las **variantes** permiten agrupar diferentes versiones de un mismo componente bajo un solo componente maestro.

```
COMPONENTE: Button
├── Variant: Type = Primary
│   ├── Size = Small
│   ├── Size = Medium
│   └── Size = Large
├── Variant: Type = Secondary
│   ├── Size = Small
│   ├── Size = Medium
│   └── Size = Large
├── Variant: Type = Ghost
│   ├── Size = Small
│   ├── Size = Medium
│   └── Size = Large
└── States: Default, Hover, Active, Disabled
```

---

## 4.2 Propiedades y naming

### Propiedades de variantes

| Propiedad    | Tipo     | Valores ejemplo                    |
|-------------|----------|------------------------------------|
| Type        | Variant  | Primary, Secondary, Ghost, Outline |
| Size        | Variant  | Small, Medium, Large               |
| State       | Variant  | Default, Hover, Active, Disabled   |
| Icon        | Boolean  | True / False                       |
| Label       | Text     | (editable en cada instance)        |

### Naming convention

```
Button / Primary / Medium / Default
Button / Primary / Medium / Hover
Button / Secondary / Small / Default
Button / Secondary / Small / Disabled
```

---

## 4.3 Variantes vs componentes separados

| Criterio                  | Usar Variantes                    | Usar Componentes Separados        |
|--------------------------|-----------------------------------|-----------------------------------|
| Mismo elemento, distintas versiones | ✅ Sí                       | ❌ No                              |
| Elementos completamente diferentes | ❌ No                        | ✅ Sí                              |
| Botones con distintos estados      | ✅ Sí                       | ❌ No                              |
| Card vs Modal                      | ❌ No (distintos componentes)| ✅ Sí                              |

---

# 5. Estilos y tokens

### Estilos en Figma

| Tipo de estilo  | Qué controla                         | Ejemplo                    |
|----------------|--------------------------------------|----------------------------|
| Color          | Fills, strokes                       | Primary/500, Neutral/100   |
| Typography     | Font, size, weight, line-height      | Heading/H1, Body/Regular   |
| Effect         | Sombras, blurs                       | Shadow/SM, Shadow/LG       |
| Grid           | Columnas, gutters, margins           | Grid/Desktop-12col         |

### De estilos a tokens

Los **tokens** son la evolución de los estilos. Son variables que se pueden compartir entre diseño y código:

```
ESTILOS (Figma):                    TOKENS (Código):
Color/Primary/500 → #2563EB        --color-primary-500: #2563EB;
Spacing/MD → 16px                   --spacing-md: 16px;
Font/Body/Regular → Inter 16/24     --font-body: Inter 16px/1.5;
Radius/MD → 8px                     --radius-md: 8px;
```

> **La sincronización entre tokens de Figma y tokens de código es lo que hace un Design System funcional.**

---

# 6. Prototyping en Figma

---

## 6.1 Conexiones e interacciones

### Anatomía de una interacción

```
TRIGGER      →    ACTION         →    ANIMATION
(evento)          (qué pasa)          (cómo se ve)

On Click     →    Navigate to    →    Smart Animate
On Hover     →    Open Overlay   →    Slide In
On Drag      →    Swap With      →    Dissolve
While Pressing→   Back           →    Instant
```

### Ejemplo de flujo

```
┌──────────┐  Click CTA  ┌──────────┐  Click "Buy"  ┌──────────┐
│  Landing  │ ──────────→ │  Pricing  │ ────────────→ │ Checkout │
│  Page     │             │  Page     │               │  Page    │
└──────────┘              └──────────┘               └──────────┘
                               │
                          Hover card
                               ↓
                          ┌──────────┐
                          │  Tooltip  │  (Overlay)
                          └──────────┘
```

---

## 6.2 Overlays y Smart Animate

### Overlays

Permiten mostrar elementos sobre la pantalla actual sin navegar.

| Uso                  | Ejemplo                              |
|---------------------|--------------------------------------|
| Modales             | Confirmación, formulario emergente   |
| Dropdowns           | Menú desplegable                     |
| Tooltips            | Información contextual               |
| Bottom sheets       | Opciones en mobile                   |
| Toasts              | Notificaciones temporales            |

### Smart Animate

Anima automáticamente las diferencias entre dos frames con el mismo nombre de layers.

**Requisitos:** Layers con nombres idénticos + propiedades diferentes (posición, tamaño, opacidad, color).

---

# 7. Organización y naming

### Estructura de archivos recomendada

```
📁 Project Name
├── 📄 Design File
│   ├── 📑 Cover
│   ├── 📑 Screens - Desktop
│   ├── 📑 Screens - Mobile
│   ├── 📑 Components (local)
│   └── 📑 Archive
├── 📄 Design System (library)
│   ├── 📑 Tokens
│   ├── 📑 Components
│   ├── 📑 Patterns
│   └── 📑 Documentation
└── 📄 Prototypes
```

### Naming convention para layers

```
Bueno:                          Malo:
Hero / Container               Frame 47
Hero / Headline                 Rectangle 12
Hero / CTA / Primary            Group 3
Card / Image                    Vector 8
Nav / Link / Active             Text
```

> **Regla:** Si un desarrollador abre tu archivo y no entiende la estructura sin explicación, la organización está mal.

---

# 8. Colaboración y handoff

### Flujo de colaboración

```
DESIGNER                    DEVELOPER
    │                           │
    ├── Diseña en Figma ────────┤
    │                           │
    ├── Marca "Ready for dev" ──┤
    │                           │
    │   ←── Revisa en Dev Mode  ┤
    │                           │
    │   ←── Preguntas/Feedback  ┤
    │                           │
    ├── Ajustes ────────────────┤
    │                           │
    │   ←── Implementa ────────┤
    │                           │
    ├── QA / Review ────────────┤
    │                           │
```

### Qué incluir en el handoff

| Elemento                  | Descripción                                    |
|--------------------------|------------------------------------------------|
| Specs de componentes     | Tamaños, colores, estados, spacing             |
| Tokens                   | Variables compartidas (color, spacing, typo)    |
| Interacciones            | Qué pasa en click, hover, error, carga         |
| Responsive behavior      | Cómo se adaptan los componentes                |
| Edge cases               | Estados vacíos, errores, límites de texto      |
| Assets exportados        | Iconos, imágenes, ilustraciones                |

---

# 9. Nivel avanzado en Figma

| Habilidad                        | Descripción                                        |
|---------------------------------|----------------------------------------------------|
| Pensamiento sistémico           | Diseñar componentes para el sistema, no la pantalla|
| Auto Layout anidado complejo    | Layouts que replican CSS real                      |
| Variables y modes               | Temas (light/dark), breakpoints, localization      |
| Component properties            | Boolean, text, instance swap como propiedades      |
| Branching y versioning          | Control de versiones dentro de Figma               |
| Plugins avanzados               | Automatización, linting, sincronización de tokens  |
| Dev integration                 | Figma Tokens → código (Style Dictionary)           |

---

# Parte II — Design Systems

---

# 10. ¿Qué es un Design System?

---

## 10.1 Definición y objetivos

Un **Design System** es un conjunto de estándares, componentes, tokens y documentación que permite a equipos de diseño y desarrollo construir productos de forma **consistente, eficiente y escalable**.

No es una biblioteca de componentes. Es un **producto que sirve a otros productos**.

### Objetivos

| Objetivo              | Descripción                                          |
|----------------------|------------------------------------------------------|
| Consistencia         | Misma experiencia en todas las pantallas y productos |
| Eficiencia           | No rediseñar lo mismo, reutilizar lo probado         |
| Escalabilidad        | Soportar crecimiento sin perder calidad              |
| Calidad              | Estándar mínimo elevado para todo el equipo          |
| Comunicación         | Lenguaje común entre diseño y desarrollo             |

---

## 10.2 Design System ≠ UI Kit ≠ Style Guide

| Concepto          | Qué es                                        | Alcance                     |
|------------------|------------------------------------------------|-----------------------------|
| Style Guide      | Documentación de reglas visuales               | Colores, tipografía, logo   |
| UI Kit           | Colección de componentes diseñados             | Botones, inputs, cards      |
| Component Library| Componentes implementados en código            | React components, CSS       |
| Design System    | **Todo lo anterior** + tokens + documentación + gobernanza | Sistema completo    |

```
┌─────────────────────────────────────────────────────┐
│                  DESIGN SYSTEM                       │
│  ┌──────────────────────────────────────────────┐   │
│  │              COMPONENT LIBRARY                │   │
│  │  ┌───────────────────────────────────┐       │   │
│  │  │           UI KIT                   │       │   │
│  │  │  ┌─────────────────────────┐      │       │   │
│  │  │  │     STYLE GUIDE         │      │       │   │
│  │  │  └─────────────────────────┘      │       │   │
│  │  └───────────────────────────────────┘       │   │
│  └──────────────────────────────────────────────┘   │
│  + Tokens + Documentación + Governance               │
└─────────────────────────────────────────────────────┘
```

---

# 11. Componentes de un Design System

---

## 11.1 Tokens de diseño

Los tokens son las **unidades más básicas** del sistema. Son decisiones de diseño representadas como variables reutilizables.

### Tipos de tokens

| Categoría     | Ejemplos                                        |
|--------------|-------------------------------------------------|
| Color        | primary-500, neutral-100, error-600             |
| Spacing      | space-4 (4px), space-8 (8px), space-16 (16px)  |
| Typography   | font-family, font-size-body, line-height-tight  |
| Border       | radius-sm (4px), radius-md (8px), radius-full   |
| Shadow       | shadow-sm, shadow-md, shadow-lg                 |
| Breakpoints  | screen-sm (480px), screen-md (768px), screen-lg |

### Niveles de tokens

```
GLOBAL TOKENS (primitivos):
  color-blue-500: #2563EB
  space-16: 16px
  font-size-16: 16px

SEMANTIC TOKENS (con significado):
  color-primary: color-blue-500
  spacing-md: space-16
  font-body: font-size-16

COMPONENT TOKENS (específicos):
  button-bg: color-primary
  button-padding: spacing-md
  button-font: font-body
```

> **Los tokens permiten cambios globales sin tocar cada componente.** Cambias `color-primary` y TODO se actualiza.

---

## 11.2 Componentes UI

Elementos reutilizables construidos a partir de tokens:

| Componente    | Estados requeridos                              |
|--------------|-------------------------------------------------|
| Button       | Default, Hover, Active, Focus, Disabled, Loading|
| Input        | Default, Focus, Filled, Error, Disabled         |
| Card         | Default, Hover, Selected                        |
| Modal        | Open, Closing (animation)                       |
| Navbar       | Default, Scrolled, Mobile open                  |
| Dropdown     | Closed, Open, Option hover, Selected            |
| Toast        | Info, Success, Warning, Error                   |
| Checkbox     | Unchecked, Checked, Indeterminate, Disabled     |

> **Cada componente debe tener estados definidos Y variantes (tamaños, tipos).** Sin esto, el componente no está completo.

---

## 11.3 Patrones

Los patrones son **combinaciones de componentes** que resuelven problemas recurrentes:

| Patrón                 | Componentes involucrados                      |
|-----------------------|-----------------------------------------------|
| Formulario completo   | Inputs, labels, buttons, validation, progress |
| Listado con filtros   | Table, filters, pagination, search            |
| Dashboard             | Cards, charts, KPIs, sidebar, header          |
| Checkout              | Form, summary, steps, payment, confirmation   |
| Onboarding            | Steps, illustrations, CTAs, progress bar      |

---

## 11.4 Guías de uso (documentación)

Cada elemento del sistema debe estar documentado:

| Sección              | Contenido                                      |
|---------------------|------------------------------------------------|
| Descripción         | Qué es y para qué sirve                        |
| Cuándo usar         | Contextos apropiados                            |
| Cuándo NO usar      | Contextos inapropiados                          |
| Anatomía            | Partes del componente                           |
| Variantes           | Tipos y tamaños disponibles                    |
| Estados             | Todos los estados posibles                      |
| Accesibilidad       | Requisitos a11y del componente                  |
| Código              | Ejemplo de implementación                       |
| Do's and Don'ts     | Ejemplos visuales de uso correcto e incorrecto  |

> **Sin documentación, el Design System pierde efectividad.** El sistema es tan bueno como su documentación.

---

# 12. Tipos de Design Systems

| Tipo            | Descripción                                  | Ventaja                   | Riesgo                    |
|----------------|----------------------------------------------|---------------------------|---------------------------|
| Centralizado   | Un equipo mantiene y controla el sistema     | Alta consistencia         | Puede ser lento           |
| Distribuido    | Varios equipos contribuyen                    | Evolución rápida          | Riesgo de inconsistencia  |
| Híbrido        | Control central + contribuciones distribuidas | Balance                   | Requiere buena governance |

> **El modelo híbrido es el más común en organizaciones grandes.** Core team define estándares, product teams proponen.

---

# 13. Creación de un Design System

---

## 13.1 Auditoría inicial

Antes de crear, analiza lo existente:

```
1. Capturar screenshots de toda la UI actual
       ↓
2. Identificar componentes repetidos
       ↓
3. Detectar inconsistencias (colores, spacing, tipografía)
       ↓
4. Categorizar patrones recurrentes
       ↓
5. Priorizar qué estandarizar primero
```

---

## 13.2 Definición de tokens

| Token              | Decisión                                  |
|-------------------|-------------------------------------------|
| Paleta de colores | Primary, secondary, neutrals, semantic    |
| Escala tipográfica| Families, sizes, weights, line-heights    |
| Sistema de spacing| Base unit (4px o 8px) + escala            |
| Border radius     | Scale (sm, md, lg, full)                  |
| Shadows           | Elevation levels (sm, md, lg)             |

---

## 13.3 Construcción de componentes

### Orden recomendado (de atomos a organismos)

```
1. Tokens (colores, spacing, tipografía)
     ↓
2. Foundations (iconos, grid, sistema de spacing)
     ↓
3. Atoms (botones, inputs, badges, labels)
     ↓
4. Molecules (cards, form groups, list items)
     ↓
5. Organisms (navbar, footer, hero sections)
     ↓
6. Templates (layouts de página completos)
     ↓
7. Pages (instancias de templates con contenido real)
```

---

## 13.4 Documentación

Para cada componente:

```
BUTTON DOCUMENTATION:
┌──────────────────────────────────────────────────┐
│  Name: Button                                     │
│  Description: Interactive element that triggers   │
│               an action when clicked.             │
│                                                   │
│  Variants: Primary, Secondary, Ghost, Outline     │
│  Sizes: Small (32px), Medium (40px), Large (48px) │
│  States: Default, Hover, Active, Focus, Disabled  │
│                                                   │
│  Accessibility:                                   │
│  - Keyboard navigable (Tab + Enter)               │
│  - aria-label when icon-only                      │
│  - Minimum 44x44px touch target                   │
│                                                   │
│  Do: Use Primary for main action                  │
│  Don't: Use more than 1 Primary button per section│
└──────────────────────────────────────────────────┘
```

---

# 14. Escalabilidad del sistema

| Principio            | Descripción                                         |
|---------------------|-----------------------------------------------------|
| Modularidad         | Componentes independientes, actualizables por separado|
| Consistencia + flex | Reglas claras pero adaptables a necesidades nuevas   |
| Versionado          | Semantic versioning (v1.0.0 → v1.1.0 → v2.0.0)    |
| Backward compat     | Cambios no rompen implementaciones existentes        |
| Migration guides    | Documentar cómo actualizar cuando hay breaking changes|

---

# 15. Integración con desarrollo

### Sincronización diseño-código

```
FIGMA                                   CODE
┌────────────────────┐                 ┌─────────────────────┐
│  Design Tokens     │  ← Sync →      │  CSS/JS Variables    │
│  Components        │  ← Spec →      │  React Components    │
│  Prototypes        │  ← Ref →       │  Behavior/Logic      │
│  Documentation     │  ← Guide →     │  Storybook           │
└────────────────────┘                 └─────────────────────┘
```

### Herramientas de sincronización

| Herramienta           | Función                                     |
|----------------------|----------------------------------------------|
| Figma Tokens plugin  | Gestionar y exportar tokens desde Figma      |
| Style Dictionary     | Transformar tokens a CSS, SCSS, JS, etc.     |
| Storybook            | Documentar componentes de código interactivos|
| Chromatic            | Testing visual de componentes                |
| Zeroheight           | Documentación de Design System               |

---

# 16. Mantenimiento y gobernanza

### Gobernanza

| Aspecto              | Responsabilidad                                |
|---------------------|------------------------------------------------|
| Revisión de cambios | Core team aprueba modificaciones al sistema    |
| Nuevos componentes  | Proceso de propuesta → revisión → aprobación   |
| Deprecación         | Proceso para retirar componentes obsoletos      |
| Versionado          | Semantic versioning + changelog                 |
| Quality assurance   | Testing visual + a11y + responsive              |

### Fuentes de feedback

- Diseñadores (usabilidad del sistema)
- Desarrolladores (implementabilidad)
- Usuarios finales (experiencia resultante)
- Analytics (métricas de producto)

---

# 17. Nivel avanzado en Design Systems

| Habilidad                        | Descripción                                            |
|---------------------------------|--------------------------------------------------------|
| Pensamiento sistémico           | Diseñar para reutilización y escalabilidad              |
| Multi-producto                  | Un sistema que sirve a múltiples productos              |
| Multi-marca (theming)           | Tokens temáticos para diferentes marcas                 |
| Automatización                  | Generación de tokens, sync con código, docs dinámicas   |
| Impacto en negocio              | Medir ROI: ahorro de tiempo, consistencia, velocidad    |
| Contribution model              | Permitir contribuciones de equipos de producto           |

### Impacto medible

```
┌──────────────────────────────────────────────────────┐
│           IMPACTO DE UN DESIGN SYSTEM                 │
│                                                       │
│  ✓ Reduce tiempo de diseño 30-50%                     │
│  ✓ Reduce tiempo de desarrollo 20-40%                 │
│  ✓ Acelera time-to-market                             │
│  ✓ Mejora consistencia de marca                       │
│  ✓ Reduce bugs de UI                                  │
│  ✓ Facilita onboarding de nuevos miembros             │
│                                                       │
│  → Se convierte en un activo estratégico,             │
│    no solo técnico                                    │
└──────────────────────────────────────────────────────┘
```

---

# Parte III — Prototipado e Interacción

---

# 18. Fundamentos del prototipado

---

## 18.1 Definición y objetivo

Un **prototipo** es una representación interactiva de una interfaz que simula el comportamiento real de un producto digital antes de que exista código funcional.

### Objetivos

| Objetivo                   | Descripción                                      |
|---------------------------|--------------------------------------------------|
| Validar experiencia       | Comprobar si los flujos son claros               |
| Detectar fricciones       | Identificar problemas antes de desarrollar       |
| Comunicar ideas           | Mostrar de forma tangible lo que se propone      |
| Reducir riesgo            | Evitar errores costosos en desarrollo            |
| Testing con usuarios      | Obtener feedback real sobre la interacción       |

> **Un buen prototipo evita errores costosos en desarrollo.**

---

## 18.2 Tipos de prototipos

| Tipo            | Detalle                        | Cuándo usar                           | Herramienta          |
|----------------|--------------------------------|---------------------------------------|----------------------|
| Low-fidelity   | Formas básicas, sin estilo     | Exploración, validación de concepto   | Papel, Balsamiq      |
| Mid-fidelity   | Estructura clara, sin diseño final | Usabilidad temprana             | Figma, Axure         |
| High-fidelity  | Diseño completo, interacciones | Validación final, handoff, stakeholders| Figma, Principle     |

---

# 19. Interacciones en interfaces

---

## 19.1 Tipos de interacciones

| Interacción     | Descripción                          | Plataforma         |
|----------------|--------------------------------------|---------------------|
| Click / Tap    | Acción principal                     | Desktop / Mobile    |
| Hover          | Cursor sobre elemento                | Desktop only        |
| Scroll         | Navegar contenido vertical           | Ambas               |
| Drag & Drop    | Mover elementos                      | Ambas (más desktop) |
| Swipe          | Deslizar horizontal                  | Mobile              |
| Long press     | Mantener presionado                  | Mobile              |
| Input          | Escribir texto                       | Ambas               |

> **Cada interacción debe ser predecible y consistente.**

---

## 19.2 Estados de componentes

Todo elemento interactivo debe tener estados definidos:

```
┌────────────────────────────────────────────────────┐
│              ESTADOS DE COMPONENTES                 │
│                                                     │
│  Default   → Estado inicial, listo para interactuar │
│  Hover     → Cursor encima (solo desktop)           │
│  Active    → Siendo presionado/clickeado            │
│  Focus     → Seleccionado por teclado (a11y)        │
│  Disabled  → No disponible para interacción         │
│  Error     → Estado de error (formularios)          │
│  Loading   → Procesando una acción                  │
│  Success   → Acción completada exitosamente         │
│  Empty     → Sin datos (empty state)                │
│                                                     │
└────────────────────────────────────────────────────┘
```

---

## 19.3 Feedback visual

| Acción del usuario    | Feedback esperado                          |
|----------------------|---------------------------------------------|
| Click en botón       | Cambio visual + acción resultante           |
| Envío de formulario  | Loading → Success/Error                     |
| Hover en card        | Sombra, scale sutil, cursor pointer         |
| Error en input       | Borde rojo + mensaje descriptivo            |
| Carga de página      | Skeleton screen o spinner                   |
| Acción exitosa       | Toast de confirmación + cambio visual       |

---

# 20. Flujos de usuario en prototipos

### Definición

Un **flujo de usuario** es la secuencia de pasos que sigue una persona para completar una tarea.

### Diseño de flujos efectivos

| Principio                    | Descripción                                 |
|-----------------------------|----------------------------------------------|
| Objetivo claro              | Cada flujo tiene una meta definida           |
| Mínimos pasos               | Eliminar pasos innecesarios                  |
| Coherencia entre pantallas  | Diseño consistente en todo el flujo          |
| Feedback continuo           | El usuario sabe dónde está y qué falta       |
| Microinteracciones          | Detalles que mejoran la fluidez (animaciones)|

### Ejemplo de flujo

```
Registro en SaaS:
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Landing  │ → │  Sign Up  │ → │ Onboarding│ → │ Dashboard │
│  Page     │   │  Form     │   │  (3 steps)│   │ (primer   │
│           │   │           │   │           │   │  valor)   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘
     CTA →         Submit →       Next →          Done ✓
```

---

# 21. Animaciones y transiciones

### Función de las animaciones

| Función                    | Ejemplo                                    |
|---------------------------|--------------------------------------------|
| Guiar la atención         | Elemento que aparece con fade              |
| Explicar cambios          | Transición entre pantallas                 |
| Mejorar percepción        | Skeleton screen durante carga              |
| Feedback                  | Botón que pulsa al hacer clic              |
| Delicadeza                | Micro-animaciones que añaden personalidad  |

### Buenas prácticas

| Práctica                          | Razón                                  |
|----------------------------------|----------------------------------------|
| Rápidas y sutiles (200-400ms)    | No hacer esperar al usuario            |
| Consistentes                     | Misma animación para misma acción      |
| Con propósito                    | Cada animación resuelve un problema    |
| Reducir motion para a11y         | `prefers-reduced-motion` en CSS        |
| No exceder                       | Demasiadas animaciones distraen        |

---

# 22. Testing con prototipos

### Validación temprana

| Qué se evalúa                   | Cómo                                    |
|---------------------------------|------------------------------------------|
| Comprensión del flujo           | Observar si el usuario llega al objetivo |
| Facilidad de uso                | Medir tiempo y errores                   |
| Problemas de navegación         | Detectar dónde se pierde el usuario      |
| Claridad de la información      | Preguntar qué entendió                   |

### Ciclo de testing

```
1. Crear prototipo → 2. Definir tareas → 3. Reclutar usuarios
         ↑                                        ↓
5. Ajustar diseño ← 4. Observar + analizar resultados
```

> **Este ciclo se repite hasta que los problemas principales se resuelvan.**

---

# 23. Nivel avanzado en prototipado

| Habilidad                          | Descripción                                        |
|-----------------------------------|----------------------------------------------------|
| Simulación de lógica compleja     | Condicionales, flujos dinámicos, estados dependientes|
| Prototipos para handoff           | Specs completas: comportamiento + estados + transiciones|
| Experiencia completa (end-to-end) | No pantallas aisladas, sino flujos conectados       |
| Velocidad de iteración            | Crear, validar y ajustar sin fricción               |
| Variables en prototipos           | Figma Variables para simular lógica real             |
| Interactive components            | Componentes con estados interactivos nativos         |

> **Un diseñador avanzado no prototipa pantallas. Prototipa experiencias completas.**

---

> *"If a picture is worth a thousand words, a prototype is worth a thousand meetings."*
> — Tom & David Kelley (IDEO)
