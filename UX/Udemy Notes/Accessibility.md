# Accesibilidad (Accessibility) — Módulo Completo

> **Módulo:** Accesibilidad Digital en UX/UI
> **Nivel:** Básico → Intermedio → Avanzado
> **Objetivo:** Diseñar experiencias inclusivas, usables y conformes a estándares internacionales para que cualquier persona pueda interactuar con productos digitales sin barreras.

---

## Tabla de Contenidos

1. [¿Qué es la accesibilidad en UX/UI?](#1-qué-es-la-accesibilidad-en-uxui)
2. [Principios de accesibilidad (WCAG)](#2-principios-de-accesibilidad-wcag)
3. [Tecnologías de asistencia](#3-tecnologías-de-asistencia)
4. [Accesibilidad visual](#4-accesibilidad-visual)
5. [Patrones visuales accesibles](#5-patrones-visuales-accesibles)
6. [Accesibilidad en formularios](#6-accesibilidad-en-formularios)
7. [Accesibilidad en navegación](#7-accesibilidad-en-navegación)
8. [Contenido accesible](#8-contenido-accesible)
9. [Interacciones accesibles](#9-interacciones-accesibles)
10. [Implementación técnica](#10-implementación-técnica)
11. [Testing y validación](#11-testing-y-validación)
12. [Nivel intermedio / avanzado](#12-nivel-intermedio--avanzado)

---

## 1. ¿Qué es la accesibilidad en UX/UI?

### 1.1 Definición de accesibilidad digital

**Intuición**
La accesibilidad digital es diseñar productos que cualquier persona pueda usar, sin importar sus capacidades físicas, cognitivas o sensoriales. No es un extra, un modo especial ni un checkbox legal. Es la base sobre la que se construye toda experiencia de usuario real.

**Estructura formal**
La accesibilidad (a menudo abreviada como **a11y** — "a", 11 letras, "y") es la práctica de garantizar que los productos digitales sean percibibles, operables, comprensibles y robustos para todos los usuarios, incluyendo aquellos que usan tecnologías de asistencia.

```
Accesibilidad digital = Eliminar barreras entre el usuario y la interfaz

┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   USUARIO ──→ [¿Puede percibir?] ──→ [¿Puede operar?]      │
│                      │                      │                │
│                      ▼                      ▼                │
│              [¿Puede entender?] ──→ [¿Puede completar       │
│                                       su tarea?]            │
│                                         │                    │
│                                         ▼                    │
│                                    ✓ ACCESIBLE               │
│                                    ✗ BARRERA                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Accesibilidad vs Usabilidad vs Inclusión

| Concepto | Pregunta que responde | Alcance |
|---|---|---|
| **Accesibilidad** | ¿Puede usarlo? | Eliminar barreras técnicas para personas con discapacidades |
| **Usabilidad** | ¿Es fácil usarlo? | Optimizar eficiencia y satisfacción para todos |
| **Inclusión** | ¿Fue pensado para mí? | Considerar la diversidad humana desde el inicio del diseño |

```
INCLUSIÓN (estrategia)
┌───────────────────────────────────────────────┐
│                                               │
│  ACCESIBILIDAD (estándar técnico)             │
│  ┌───────────────────────────────────────┐    │
│  │                                       │    │
│  │  USABILIDAD (calidad de experiencia)  │    │
│  │  ┌───────────────────────────────┐    │    │
│  │  │                               │    │    │
│  │  │  El usuario completa su tarea │    │    │
│  │  │  con facilidad y satisfacción │    │    │
│  │  │                               │    │    │
│  │  └───────────────────────────────┘    │    │
│  │  Puede usar la interfaz sin barreras  │    │
│  └───────────────────────────────────────┘    │
│  Fue diseñado pensando en la diversidad       │
└───────────────────────────────────────────────┘
```

> 💡 Un producto puede ser accesible (cumple WCAG) pero no usable (confuso). Puede ser usable pero no inclusivo (ignora contextos culturales). El objetivo es los tres.

### 1.3 Por qué es crítica

**Tres dimensiones de urgencia:**

**Ética:**
- 1.300 millones de personas en el mundo viven con alguna discapacidad (~16% de la población global, OMS 2023)
- Excluir es una decisión de diseño; incluir también lo es
- Discapacidades temporales y situacionales nos afectan a todos

**Legal:**
- **ADA** (Americans with Disabilities Act) — EE.UU.
- **EAA** (European Accessibility Act) — Unión Europea, vigente desde 2025
- **Ley General de Discapacidad** — España
- Demandas por accesibilidad web crecen cada año (~4,000 en EE.UU. en 2023)

**Negocio:**
- Mercado de $1.9 trillion USD en poder de compra (personas con discapacidades)
- SEO mejora con HTML semántico y accesible
- Mejora la usabilidad para TODOS los usuarios
- Reduce riesgos legales

```
Impacto de accesibilidad en métricas de negocio:

Subtítulos en videos         → +7.3% engagement (3Play Media)
Sitio accesible              → +12% conversiones (Tesco)
Contraste mejorado           → +30% readability (WCAG studies)
Navegación por teclado       → -15% bounce rate (WebAIM)
```

### 1.4 Tipos de discapacidades

**Intuición**
Las discapacidades no son un grupo monolítico. Son un espectro amplio con tres temporalidades: permanente, temporal y situacional. Diseñar para una temporalidad beneficia a todas.

```
              PERMANENTE         TEMPORAL            SITUACIONAL
              ─────────          ─────────           ─────────
VISUAL        Ceguera            Dilatación pupilar  Pantalla con sol
              Baja visión        Ojo vendado         Brillos/reflejos
              Daltonismo         Infección ocular    Conduciendo

AUDITIVA      Sordera            Infección de oído   Ambiente ruidoso
              Hipoacusia         Tímpano perforado   Sin audífonos

MOTORA        Parálisis          Brazo fracturado    Cargando un bebé
              Amputación         Tendinitis          Una sola mano libre
              Temblores          Post-cirugía        Guantes puestos

COGNITIVA     Dislexia           Conmoción cerebral  Cansancio extremo
              TDAH               Medicación          Estrés / prisa
              Autismo            Migraña             Multitasking
```

> ⚠️ **Dato clave:** Cuando diseñas para una persona sin un brazo (permanente), también diseñas para alguien con una fractura (temporal) y para alguien cargando una bolsa (situacional). Un diseño accesible beneficia a más personas de las que imaginas.

### 1.5 Diseño inclusivo como enfoque, no como feature

**Aplicación práctica**

```
❌ ENFOQUE INCORRECTO:                  ✅ ENFOQUE CORRECTO:
"El producto está listo,                "Desde la primera user story,
agreguemos accesibilidad"               considero cómo accede cada
                                        tipo de usuario"

Diseño → Desarrollo → QA → "A11y"      Inclusión → Diseño → Dev → QA
                             ↑                ↑
                        Caro, tarde      Económico, integrado
                        y superficial    y estructural
```

**Principio: Diseñar para los extremos beneficia al centro.**

Cuando diseñas subtítulos para personas sordas, también ayudas a:
- Alguien en un tren sin audífonos
- Una persona aprendiendo el idioma
- Alguien en una oficina silenciosa

---

## 2. Principios de accesibilidad (WCAG)

### 2.1 Introducción a WCAG

**Intuición**
WCAG (Web Content Accessibility Guidelines) es el estándar internacional que define qué hace a un sitio web accesible. Piensa en él como el "código de edificación" de la web: no te dice cómo diseñar tu casa, pero sí los mínimos para que sea segura y habitable.

**Estructura formal**
- Publicado por el **W3C** (World Wide Web Consortium)
- Versión actual: **WCAG 2.2** (octubre 2023)
- WCAG 3.0 en desarrollo (borrador)
- Es el estándar referenciado por la mayoría de legislaciones (ADA, EAA, EN 301 549)

```
Estructura de WCAG:

WCAG 2.2
├── 4 Principios (POUR)
│   ├── 13 Pautas (Guidelines)
│   │   ├── ~87 Criterios de éxito (Success Criteria)
│   │   │   ├── Nivel A     (mínimo)
│   │   │   ├── Nivel AA    (estándar)
│   │   │   └── Nivel AAA   (óptimo)
│   │   │
│   │   └── Técnicas suficientes y recomendadas
```

### 2.2 Principios POUR

**Los 4 pilares de la accesibilidad:**

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  P ─ PERCEIVABLE (Perceptible)                               │
│  "¿Puede el usuario percibir la información?"               │
│  → Alternativas textuales, subtítulos, contraste,            │
│    contenido adaptable, distinguible                         │
│                                                              │
│  O ─ OPERABLE (Operable)                                     │
│  "¿Puede el usuario interactuar con la interfaz?"           │
│  → Teclado, tiempo suficiente, sin convulsiones,             │
│    navegable, modalidades de entrada                         │
│                                                              │
│  U ─ UNDERSTANDABLE (Comprensible)                           │
│  "¿Puede el usuario entender la información y la UI?"       │
│  → Legible, predecible, ayuda para errores                  │
│                                                              │
│  R ─ ROBUST (Robusto)                                        │
│  "¿Funciona con tecnologías actuales y futuras?"            │
│  → Compatible con tecnologías de asistencia,                 │
│    HTML válido, ARIA correcto                                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Desglose con ejemplos:**

| Principio | Pauta clave | Ejemplo práctico | Criterio WCAG |
|---|---|---|---|
| **Perceivable** | Alternativas textuales | Imágenes con `alt` descriptivo | 1.1.1 (A) |
| | Contraste mínimo | Texto 4.5:1 sobre fondo | 1.4.3 (AA) |
| | No depender del color | Error indicado con icono + texto + color | 1.4.1 (A) |
| **Operable** | Accesible por teclado | Toda función sin ratón | 2.1.1 (A) |
| | Tiempo suficiente | Extender o desactivar timeouts | 2.2.1 (A) |
| | Foco visible | Outline visible al tabular | 2.4.7 (AA) |
| **Understandable** | Idioma de la página | `<html lang="es">` | 3.1.1 (A) |
| | Navegación consistente | Menú igual en todas las páginas | 3.2.3 (AA) |
| | Prevención de errores | Confirmar antes de enviar pedido | 3.3.4 (AA) |
| **Robust** | Parsing / HTML válido | Tags bien cerrados, IDs únicos | 4.1.1 (A)* |
| | Nombre, rol, valor | Componentes custom con ARIA | 4.1.2 (A) |

### 2.3 Niveles de conformidad

```
NIVEL A (Mínimo)
─────────────────────────────────────────
Requisitos básicos sin los cuales
el contenido es completamente inaccesible.

Ejemplo: Texto alternativo en imágenes,
         acceso por teclado.

→ Si no cumples nivel A, hay usuarios
  que LITERALMENTE no pueden usar tu sitio.


NIVEL AA (Estándar — El objetivo real)
─────────────────────────────────────────
Estándar de la industria. Lo que exigen
la mayoría de legislaciones.

Ejemplo: Contraste 4.5:1, foco visible,
         navegación consistente.

→ Este es el nivel que debes cumplir
  como mínimo en cualquier producto.


NIVEL AAA (Óptimo)
─────────────────────────────────────────
Máximo nivel. No siempre alcanzable para
todo el contenido, pero ideal como meta.

Ejemplo: Contraste 7:1, lenguaje de señas
         en videos, sin límites de tiempo.

→ Alcanzar AAA en todo el sitio es raro,
  pero cada criterio que cumples ayuda.
```

**Aplicación práctica — Contraste como ejemplo:**

```
Nivel A:    Sin requisito específico de contraste
Nivel AA:   4.5:1 texto normal / 3:1 texto grande
Nivel AAA:  7:1 texto normal / 4.5:1 texto grande

Texto normal = < 18pt (24px) o < 14pt bold (18.5px)
Texto grande = ≥ 18pt (24px) o ≥ 14pt bold (18.5px)

                4.5:1                    7:1
              ┌──────────┐           ┌──────────┐
              │ Aa       │           │ Aa       │
              │ #595959  │           │ #333333  │
              │ on white │           │ on white │
              └──────────┘           └──────────┘
              AA ✓   AAA ✗           AA ✓   AAA ✓
```

### 2.4 Cómo aplicar POUR en tu proceso de diseño

```
FASE DE DISEÑO:
┌───────────────────────────────────────────────────────────┐
│ P → ¿Toda la info tiene alternativa no visual?            │
│     Checklist: alt text, captions, contraste, no-color    │
│                                                           │
│ O → ¿Todo funciona sin mouse?                             │
│     Checklist: focus order, keyboard, touch, time         │
│                                                           │
│ U → ¿Es claro y predecible?                              │
│     Checklist: labels, errores, lenguaje, consistencia    │
│                                                           │
│ R → ¿Usa semántica correcta?                              │
│     Checklist: HTML semántico, ARIA, roles, testing       │
└───────────────────────────────────────────────────────────┘
```

---

## 3. Tecnologías de asistencia

### 3.1 Screen readers (lectores de pantalla)

**Intuición**
Un screen reader convierte el contenido visual de una pantalla en voz sintetizada o braille. El usuario no ve la interfaz; la escucha. Todo lo que no tenga texto alternativo es invisible.

**Screen readers principales:**

| Screen reader | Sistema | Uso |
|---|---|---|
| **VoiceOver** | macOS / iOS | Integrado en Apple, el más usado en mobile |
| **NVDA** | Windows | Gratuito, open source, el más usado en desktop |
| **JAWS** | Windows | Comercial, estándar corporativo |
| **TalkBack** | Android | Integrado en Android |
| **Narrator** | Windows | Integrado en Windows |
| **Orca** | Linux | Open source para GNOME |

**Cómo "ve" un screen reader tu página:**

```
LO QUE TÚ VES:                      LO QUE EL SCREEN READER LEE:
┌────────────────────────┐
│  [Logo] Mi App         │           "Mi App, banner"
│  ━━━━━━━━━━━━━━━━━━━━ │
│  Inicio  Blog  Cuenta  │           "Navegación: Inicio, link. Blog, link.
│                        │            Cuenta, link."
│  Bienvenido, Juan      │           "Heading nivel 1: Bienvenido, Juan"
│                        │
│  Tu plan: Pro          │           "Tu plan: Pro"
│  [📊]                  │           ... (silencio — ¿qué es 📊?)
│                        │
│  [Upgrade]             │           "Upgrade, button" (¿upgrade qué?)
└────────────────────────┘

PROBLEMA: La imagen sin alt y el botón sin contexto
son invisibles o confusos para el screen reader.
```

### 3.2 Navegación por teclado

**Intuición**
Muchos usuarios no pueden usar un mouse: personas con discapacidades motoras, usuarios avanzados (power users), personas con temblores, o simplemente alguien con un touchpad roto. La navegación por teclado es la segunda forma más crítica de interacción después del mouse.

**Teclas fundamentales:**

| Tecla | Acción |
|---|---|
| `Tab` | Mover al siguiente elemento interactivo |
| `Shift + Tab` | Mover al elemento anterior |
| `Enter` | Activar enlaces y botones |
| `Space` | Activar botones, checkboxes, toggles |
| `Arrow keys` | Navegar dentro de componentes (radios, tabs, menús) |
| `Escape` | Cerrar modales, dropdowns, popups |
| `Home / End` | Ir al inicio/final de una lista |

**Flujo de tabulación correcto:**

```
✅ Orden lógico (visual = DOM):

[Logo] → [Nav: Inicio] → [Nav: Blog] → [Nav: Cuenta]
                    ↓
[Heading] → [Input: Email] → [Input: Password] → [Button: Login]

❌ Orden caótico (DOM desordenado):

[Button: Login] → [Nav: Cuenta] → [Input: Password]
→ [Logo] → [Input: Email] → [Nav: Inicio]

El usuario se pierde, no entiende la estructura.
```

### 3.3 Magnificadores de pantalla

**Intuición**
Los magnificadores amplían una porción de la pantalla para usuarios con baja visión. El usuario ve un fragmento ampliado y navega desplazando esa "lupa".

```
Pantalla completa:                    Vista magnificada (4x):
┌───────────────────────────┐        ┌───────────────────────────┐
│ ┌────┐                    │        │                           │
│ │Logo│ Mi App       👤    │        │  Mi App                   │
│ └────┘                    │        │                           │
│ ══════════════════════════│        │  ══════════════            │
│ Inicio   Blog   Cuenta   │        │  Inicio   Blog            │
│                           │        │                           │
│ Bienvenido, Juan          │        │                           │
│ Tu plan: Pro              │        └───────────────────────────┘
│                           │         ↑ Solo ve esta porción
│ [Upgrade a Premium]       │
└───────────────────────────┘

Implicaciones de diseño:
→ Información relacionada debe estar CERCA
→ Mensajes de error JUNTO al campo, no arriba de la página
→ Tooltips que aparecen lejos del trigger son invisibles
→ Layouts muy anchos son difíciles de seguir
```

### 3.4 Voice control (control por voz)

**Herramientas principales:**
- **Voice Control** (macOS/iOS)
- **Voice Access** (Android)
- **Dragon NaturallySpeaking** (Windows)
- **Windows Speech Recognition**

**Cómo funciona:**

```
El usuario dice:          El sistema:
────────────────          ──────────────────────
"Click Submit"        →   Busca un botón con texto "Submit"
"Click link 3"        →   Asigna números a los links y activa el 3
"Type hello"          →   Escribe "hello" en el campo enfocado
"Show numbers"        →   Superpone números en todos los elementos
"Scroll down"         →   Desplaza la página
```

**Implicaciones para tu diseño:**
- Los botones y links **necesitan texto visible** (un ícono sin label no es "clickeable" por voz)
- El texto visible debe coincidir con el `aria-label` (si "Enviar" se ve pero aria-label dice "Submit form", el usuario no puede activarlo por voz)
- Labels de formularios deben ser únicos y descriptivos

### 3.5 Cómo los usuarios interactúan con interfaces

**Mapa de interacción por tecnología:**

```
┌──────────────────┬──────────────┬─────────────────────────────┐
│ Tecnología       │ Percibe vía  │ Interactúa vía              │
├──────────────────┼──────────────┼─────────────────────────────┤
│ Screen reader    │ Audio/Braille│ Teclado, gestos (mobile)    │
│ Magnificador     │ Visual (zoom)│ Mouse/touch (área ampliada) │
│ Solo teclado     │ Visual       │ Tab, Enter, Space, flechas  │
│ Voice control    │ Visual       │ Comandos de voz             │
│ Switch device    │ Visual       │ Un botón (scanning mode)    │
│ Eye tracking     │ Visual       │ Mirada + dwell/blink        │
└──────────────────┴──────────────┴─────────────────────────────┘
```

> ⚠️ **Regla de oro:** Nunca asumas cómo accede tu usuario. Un producto accesible funciona con todas estas tecnologías sin esfuerzo extra del usuario.

---

## 4. Accesibilidad visual

### 4.1 Contraste de color

**Intuición**
El contraste es la diferencia de luminosidad entre el texto (o elemento interactivo) y su fondo. Bajo contraste = texto invisible para millones de personas.

**Ratios WCAG:**

| Elemento | Nivel AA | Nivel AAA |
|---|---|---|
| Texto normal (< 24px) | ≥ 4.5:1 | ≥ 7:1 |
| Texto grande (≥ 24px o ≥ 18.5px bold) | ≥ 3:1 | ≥ 4.5:1 |
| Elementos UI / gráficos | ≥ 3:1 | — |
| Indicadores de foco | ≥ 3:1 | — |

**Ejemplo visual:**

```
CONTRASTE INSUFICIENTE:              CONTRASTE SUFICIENTE:

  #aaaaaa sobre #ffffff               #595959 sobre #ffffff
  Ratio: 2.3:1 ✗ (AA fail)            Ratio: 7:1 ✓ (AAA pass)

  ┌──────────────────┐                ┌──────────────────┐
  │  Texto gris      │                │  Texto oscuro    │
  │  casi invisible  │                │  legible         │
  └──────────────────┘                └──────────────────┘


BOTÓN CON BAJO CONTRASTE:           BOTÓN ACCESIBLE:

  ┌──────────────────┐                ┌──────────────────┐
  │  Enviar          │                │  Enviar          │
  │  #78b4e8 on #fff │                │  #1a6bb5 on #fff │
  │  Ratio: 2.1:1 ✗  │                │  Ratio: 5.2:1 ✓  │
  └──────────────────┘                └──────────────────┘
```

**Herramientas para verificar contraste:**
- **WebAIM Contrast Checker** — webaim.org/resources/contrastchecker
- **Stark** — Plugin de Figma/Sketch
- **Colour Contrast Analyser** — App de escritorio (TPGi)
- **Chrome DevTools** — Inspeccionar > color picker muestra ratio

### 4.2 Tipografía legible

| Criterio | Recomendación |
|---|---|
| **Tamaño mínimo** | 16px para body text (never below 12px) |
| **Line height** | 1.5× el tamaño de fuente mínimo |
| **Paragraph spacing** | ≥ 2× el tamaño de fuente |
| **Letter spacing** | ≥ 0.12× el tamaño de fuente |
| **Word spacing** | ≥ 0.16× el tamaño de fuente |
| **Longitud de línea** | 45-80 caracteres por línea |
| **Alineación** | Izquierda (nunca justificado) |
| **Familia** | Sans-serif para pantalla (Inter, Roboto, etc.) |

**WCAG 1.4.12 — Text Spacing (AA):**

```css
/* Si el usuario aplica estos estilos, tu contenido
   no debe perder funcionalidad ni información: */

p {
  line-height: 1.5 !important;       /* 1.5× font-size */
  letter-spacing: 0.12em !important; /* 0.12× font-size */
  word-spacing: 0.16em !important;   /* 0.16× font-size */
  margin-bottom: 2em !important;     /* 2× font-size */
}

/* Si tu layout se rompe con estos valores,
   tienes un problema de accesibilidad. */
```

### 4.3 No depender solo del color

**Intuición**
El 8% de los hombres y el 0.5% de las mujeres tienen algún tipo de daltonismo. Si la única diferencia entre "éxito" y "error" es el color, millones de usuarios no la percibirán.

```
❌ SOLO COLOR:                        ✅ COLOR + FORMA + TEXTO:

  ┌──────────────────┐                ┌──────────────────┐
  │  Email           │                │  Email           │
  │ ┌──────────────┐ │                │ ┌──────────────┐ │
  │ │ abc          │ │  ← Borde rojo  │ │ abc          │ │  ← Borde rojo
  │ └──────────────┘ │     (solo)     │ └──────────────┘ │
  │                  │                │ ✗ Email inválido │  ← Icono + texto
  └──────────────────┘                └──────────────────┘

  Un daltónico no ve                  Todos entienden:
  el rojo del borde.                  icono ✗ + mensaje + borde.


  GRÁFICO DE DATOS:

  ❌ Solo color:                      ✅ Color + patrón + label:
  ■ Ventas  ■ Gastos                  ■ Ventas (sólido)
  (rojo y verde — invisibles          ░ Gastos (rayado)
   para daltonismo rojo-verde)        → Patrón + color + etiqueta
```

**Regla: Siempre usa al menos dos canales de información:**

| Canal 1 | Canal 2 | Canal 3 (ideal) |
|---|---|---|
| Color rojo | Icono ✗ | Texto "Inválido" |
| Color verde | Icono ✓ | Texto "Correcto" |
| Borde coloreado | Subrayado | Label de estado |
| Punto de color en gráfico | Patrón de relleno | Etiqueta de dato |

### 4.4 Dark mode y accesibilidad

```
LIGHT MODE:                          DARK MODE:
┌────────────────────┐               ┌────────────────────┐
│  ████████████████  │               │  ████████████████  │
│  Text: #1a1a1a     │               │  Text: #e0e0e0     │
│  Bg:   #ffffff     │               │  Bg:   #121212     │
│  Ratio: 17.4:1 ✓   │               │  Ratio: 13.0:1 ✓   │
│                    │               │                    │
│  DON'T:            │               │  DON'T:            │
│  Text: #ffffff     │               │  Text: #ffffff     │
│  Bg:   #121212     │               │  Bg:   #000000     │
│  (pure white on    │               │  (pure white on    │
│   dark = glare)    │               │   pure black = eye │
│                    │               │   strain)          │
└────────────────────┘               └────────────────────┘
```

**Reglas para dark mode accesible:**
- No usar negro puro (`#000000`). Usa `#121212` o `#1a1a1a`
- No usar blanco puro para texto. Usa `#e0e0e0` o `#f0f0f0`
- Verificar contraste en AMBOS modos
- Colores de estado (error, success) necesitan ajuste en dark mode
- Sombras no funcionan en dark mode → usar bordes sutiles o elevación con luminosidad

### 4.5 Diseño para daltonismo

**Tipos principales:**

```
VISIÓN NORMAL:        DEUTERANOPÍA:         PROTANOPÍA:          TRITANOPÍA:
(trichromat)          (sin verde)           (sin rojo)           (sin azul)

🔴 Rojo               🟤 Marrón/dorado      🟤 Marrón oscuro     🔴 Rojo
🟢 Verde              🟡 Amarillo/dorado    🟡 Amarillo/beige    🟢 Verde
🔵 Azul               🔵 Azul               🔵 Azul               🟣 Rosa/púrpura

~5% hombres           ~1% hombres           ~0.01% población

→ Rojo y verde son INDISTINGUIBLES para deuteranopía y protanopía.
→ Azul y amarillo son INDISTINGUIBLES para tritanopía.
```

**Paletas seguras para daltonismo:**

| Combinación | ¿Segura? | Alternativa |
|---|---|---|
| Rojo vs Verde | ❌ | Rojo vs Azul, o agregar formas |
| Rojo vs Gris | ⚠️ | Rojo + icono ✗ |
| Azul vs Naranja | ✅ | Segura para la mayoría |
| Azul vs Amarillo | ⚠️ | Insegura para tritanopía |
| Azul vs Rojo | ✅ | Segura para la mayoría |

**Herramientas de simulación de daltonismo:**
- Chrome DevTools → Rendering → Emulate vision deficiencies
- Figma plugin → **Stark** (simula los 3 tipos)
- macOS → Accessibility → Color Filters

---

## 5. Patrones visuales accesibles

### 5.1 Jerarquía clara

**Intuición**
Una jerarquía visual clara ayuda a todos los usuarios, pero es esencial para usuarios con discapacidades cognitivas, baja visión, o que usan magnificadores. Si todo tiene el mismo peso visual, nadie sabe por dónde empezar.

```
❌ SIN JERARQUÍA:                    ✅ CON JERARQUÍA:

  Mi App                              MI APP
  Bienvenido, Juan                    ━━━━━━━━━━━━━━━━
  Tu plan actual es Pro.
  Puedes cambiar tu plan              Bienvenido, Juan
  en cualquier momento.               ─────────────────
  Ver planes disponibles.             Tu plan actual es Pro.
  Configurar cuenta.                  Puedes cambiar tu plan
  Soporte.                            en cualquier momento.

  (todo se ve igual,                  [Ver planes →]
   texto corrido)                     [Configurar cuenta →]
                                      [Soporte →]

                                      (headings, spacing,
                                       links diferenciados)
```

### 5.2 Indicadores de foco visibles

**Este es uno de los criterios más violados en la web.** WCAG 2.4.7 (AA) exige que todo elemento interactivo tenga un indicador de foco visible.

```
❌ FOCO INVISIBLE (anti-patrón):

  a:focus, button:focus {
    outline: none;          ← NUNCA hagas esto sin reemplazo
  }


✅ FOCO VISIBLE Y CLARO:

  :focus-visible {
    outline: 3px solid #2563eb;
    outline-offset: 2px;
    border-radius: 4px;
  }

  /* :focus-visible = solo muestra el foco
     cuando el usuario navega con teclado,
     no cuando hace click con mouse */
```

**Ejemplo visual:**

```
Sin foco visible:                Con foco visible:
┌──────────────────┐             ┌──────────────────┐
│  [Inicio]        │             │  ┌──────────────┐ │
│   Blog           │             │  │  [Inicio]  ◀ │ │ ← Ring azul 3px
│   Cuenta         │             │  └──────────────┘ │
└──────────────────┘             │   Blog            │
                                 │   Cuenta          │
El usuario con teclado           └──────────────────┘
no sabe dónde está.
                                 El usuario sabe exactamente
                                 qué elemento está enfocado.
```

### 5.3 Estados claros

**Cada elemento interactivo necesita estados distinguibles:**

```
          DEFAULT        HOVER          FOCUS          ACTIVE         DISABLED
Link:     Azul           Azul oscuro    Ring azul      Púrpura        Gris
          subrayado      subrayado      subrayado      subrayado      sin subrayado

Button:   Fondo sólido   Fondo más      Ring azul      Fondo más      Fondo gris
                         oscuro                        oscuro         opacidad 0.5

Input:    Borde gris     Borde oscuro   Ring azul      —              Fondo gris
                                        borde azul                    borde claro

Checkbox: Borde gris     Borde oscuro   Ring azul      Scale 0.95     Gris
          vacío          vacío          vacío                         opacidad 0.5
```

> ⚠️ **Anti-patrón:** Distinguir estados solo por color. Usa cambios de borde, sombra, posición, icono o texto además del color.

### 5.4 Espaciado adecuado

```
WCAG 2.5.8 — Target Size (Minimum) — Nivel AA:

  Mínimo: 24×24 CSS px (WCAG 2.2)
  Recomendado: 44×44 CSS px (WCAG 2.5.5 AAA)

  ❌ MAL:                           ✅ BIEN:
  ┌─┐┌─┐┌─┐                        ┌────┐  ┌────┐  ┌────┐
  │✕││◀││▶│  ← 16px, pegados       │ ✕  │  │ ◀  │  │ ▶  │  ← 44px, 8px gap
  └─┘└─┘└─┘                        └────┘  └────┘  └────┘

  Toques accidentales               Toques precisos
  Frustración                       Confianza
```

### 5.5 Diseño predecible

**WCAG 3.2 — Predecible:**

| Criterio | Significado | Ejemplo |
|---|---|---|
| 3.2.1 On Focus | Enfocar no causa cambio de contexto | ❌ Select que navega al enfocar |
| 3.2.2 On Input | Cambiar un input no causa cambio inesperado | ❌ Form que envía al cambiar un select |
| 3.2.3 Navegación consistente | Misma posición en todas las páginas | ✅ Nav siempre arriba |
| 3.2.4 Identificación consistente | Misma función = mismo nombre | ✅ "Buscar" siempre dice "Buscar" |

```
❌ IMPREDECIBLE:                      ✅ PREDECIBLE:

Página A: [🔍 Buscar]                Página A: [🔍 Buscar]
Página B: [🔎 Encontrar]             Página B: [🔍 Buscar]
Página C: [Buscar productos]         Página C: [🔍 Buscar]

→ 3 nombres distintos para           → Siempre igual.
  la misma función.                     El usuario sabe qué esperar.
```

---

## 6. Accesibilidad en formularios

### 6.1 Labels claros y asociados

**Intuición**
La asociación `<label>` ↔ `<input>` es el acto más importante de accesibilidad en formularios. Sin ella, un screen reader anuncia "edit text, blank" y el usuario no sabe qué escribir.

```html
<!-- ❌ Sin label asociado -->
Email:
<input type="email" />
<!-- Screen reader: "edit text, blank" — ¿qué campo es? -->

<!-- ❌ Label como placeholder -->
<input type="email" placeholder="Email" />
<!-- Se pierde al escribir, bajo contraste -->

<!-- ✅ Label asociado correctamente -->
<label for="email">Email</label>
<input type="email" id="email" name="email" />
<!-- Screen reader: "Email, edit text" — claro -->

<!-- ✅ Alternativa: label envolvente -->
<label>
  Email
  <input type="email" name="email" />
</label>
```

### 6.2 Mensajes de error accesibles

```html
<!-- ❌ Error inaccesible -->
<input type="email" class="error" />
<span class="red-text">Error</span>
<!-- Problemas: no conectado al input, no anunciado,
     solo color rojo, mensaje vago -->

<!-- ✅ Error accesible -->
<label for="email">Email *</label>
<input
  type="email"
  id="email"
  aria-required="true"
  aria-invalid="true"
  aria-describedby="email-error"
/>
<span id="email-error" role="alert" class="error-message">
  ✗ Ingresa un email válido, ej: nombre@dominio.com
</span>
<!-- Beneficios:
     → aria-invalid indica estado de error
     → aria-describedby conecta input con mensaje
     → role="alert" anuncia el error inmediatamente
     → Icono ✗ + texto + color = tres canales
     → Mensaje específico y accionable -->
```

**Checklist de errores accesibles:**
- ✅ Mensaje conectado al campo vía `aria-describedby`
- ✅ `aria-invalid="true"` en el campo con error
- ✅ `role="alert"` para anunciar errores dinámicos
- ✅ Icono + texto + color (no solo color)
- ✅ Mensaje específico ("Email inválido" no "Error")
- ✅ Error visible sin scroll (cerca del campo)

### 6.3 Navegación por teclado en formularios

```
Flujo de tabulación esperado:

[Tab] → Label 1 / Input 1 (focus)
[Tab] → Label 2 / Input 2 (focus)
[Tab] → Label 3 / Select  (focus)
  [Space] → Abre dropdown
  [↑][↓]  → Navega opciones
  [Enter]  → Selecciona
[Tab] → Checkbox (focus)
  [Space] → Marca/desmarca
[Tab] → Radio group (focus)
  [↑][↓] → Cambia selección dentro del grupo
[Tab] → Botón Submit (focus)
  [Enter] / [Space] → Envía

REGLAS:
→ NUNCA usar tabindex > 0 (altera el orden natural)
→ tabindex="0" → Hace focusable (orden natural del DOM)
→ tabindex="-1" → Focusable por JS, no por Tab
→ El orden del DOM = orden de tabulación
```

### 6.4 Agrupación de campos

```html
<!-- ✅ Fieldset + legend para agrupar campos relacionados -->
<fieldset>
  <legend>Dirección de envío</legend>

  <label for="street">Calle</label>
  <input type="text" id="street" autocomplete="street-address" />

  <label for="city">Ciudad</label>
  <input type="text" id="city" autocomplete="address-level2" />

  <label for="zip">Código postal</label>
  <input type="text" id="zip" autocomplete="postal-code" />
</fieldset>

<!-- Screen reader anuncia: "Dirección de envío, group"
     y dentro: "Calle, edit text" -->

<!-- ✅ Radio buttons SIEMPRE en fieldset -->
<fieldset>
  <legend>Método de pago</legend>
  <label><input type="radio" name="pay" value="card" /> Tarjeta</label>
  <label><input type="radio" name="pay" value="paypal" /> PayPal</label>
  <label><input type="radio" name="pay" value="transfer" /> Transferencia</label>
</fieldset>
<!-- Sin fieldset, el screen reader no sabe
     que estos radios van juntos -->
```

### 6.5 Uso correcto de placeholders

```
PLACEHOLDER: Lo que NO es y lo que SÍ es

❌ NO ES:
   → Un reemplazo del label
   → Información crítica
   → Una instrucción importante

✅ SÍ ES:
   → Un ejemplo del formato esperado
   → Una pista visual secundaria
   → Complemento del label

┌──────────────────────────────┐
│ ❌ Solo placeholder:         │
│ ┌──────────────────────────┐ │
│ │ Ingresa tu email         │ │  ← Se pierde al escribir
│ └──────────────────────────┘ │    Bajo contraste (#999)
│                              │    No accesible
│                              │
│ ✅ Label + placeholder:      │
│ Email *                      │
│ ┌──────────────────────────┐ │
│ │ ej: nombre@dominio.com   │ │  ← Ejemplo de formato
│ └──────────────────────────┘ │    Label siempre visible
│                              │    Accesible
└──────────────────────────────┘
```

---

## 7. Accesibilidad en navegación

### 7.1 Menús claros y consistentes

**WCAG 3.2.3 — Navegación consistente (AA):**

```
✅ Menú consistente en todas las páginas:

Página Home:      [Inicio]  [Productos]  [Blog]  [Contacto]
Página Productos: [Inicio]  [Productos]  [Blog]  [Contacto]
Página Blog:      [Inicio]  [Productos]  [Blog]  [Contacto]

→ Mismo orden, misma posición, mismos nombres.

❌ Menú inconsistente:

Página Home:      [Home]     [Products]  [Blog]    [Contact]
Página Productos: [Inicio]   [Blog]      [Tienda]  [Ayuda]
Página Blog:      [Principal][Artículos] [Shop]    [Soporte]

→ Nombres cambian, orden cambia = confusión total.
```

### 7.2 Orden lógico del DOM

**Intuición**
El DOM (Document Object Model) es el "mapa" que leen los screen readers y la navegación por teclado. Si el orden visual no coincide con el orden del DOM, la experiencia es caótica.

```
❌ CSS visual ≠ DOM order:

Visual:                         DOM (lo que lee el screen reader):
┌───────┬─────────────────┐    1. <aside> (sidebar)
│ Side  │    Contenido    │    2. <main> (contenido)
│ bar   │    principal    │    3. <header> (nav)
│       │                 │
│       │                 │    El screen reader lee el sidebar
│       │                 │    antes que el contenido principal.
└───────┴─────────────────┘

✅ DOM order = visual order:

DOM:                            Visual:
1. <header> (nav)              ┌─────────────────────────┐
2. <main> (contenido)          │       Header / Nav      │
3. <aside> (sidebar)           ├───────┬─────────────────┤
                               │ Side  │    Contenido    │
                               │ bar   │    principal    │
                               └───────┴─────────────────┘

Usa CSS Grid/Flexbox para posicionar visualmente,
pero mantén el DOM en orden lógico.
```

### 7.3 Breadcrumbs

```html
<!-- ✅ Breadcrumbs accesibles -->
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Inicio</a></li>
    <li><a href="/productos">Productos</a></li>
    <li><a href="/productos/laptops">Laptops</a></li>
    <li aria-current="page">MacBook Pro 16"</li>
  </ol>
</nav>

<!--
  → <nav> con aria-label distingue de la nav principal
  → <ol> indica orden jerárquico
  → aria-current="page" indica la página actual
  → El último item NO es link (ya estás ahí)
-->
```

### 7.4 Skip links

**Intuición**
Un usuario de teclado que llega a tu sitio debe tabular por todo el header y nav antes de llegar al contenido principal. En un sitio con 20 links en la nav, son 20 tabs para llegar al contenido. Un "skip link" permite saltar directamente.

```html
<!-- ✅ Skip link (primer elemento del body) -->
<body>
  <a href="#main-content" class="skip-link">
    Saltar al contenido principal
  </a>

  <header>
    <nav><!-- 20 links de navegación --></nav>
  </header>

  <main id="main-content">
    <!-- Contenido principal -->
  </main>
</body>
```

```css
/* Skip link: invisible hasta que recibe foco */
.skip-link {
  position: absolute;
  left: -9999px;
  top: auto;
  width: 1px;
  height: 1px;
  overflow: hidden;
}

.skip-link:focus {
  position: fixed;
  top: 8px;
  left: 8px;
  width: auto;
  height: auto;
  padding: 12px 24px;
  background: #1a1a1a;
  color: #ffffff;
  font-size: 1rem;
  font-weight: 600;
  z-index: 9999;
  border-radius: 6px;
  text-decoration: none;
}
```

```
Sin skip link:                      Con skip link:
[Tab] → Logo                        [Tab] → "Saltar al contenido"
[Tab] → Nav item 1                  [Enter] → Focus va al <main>
[Tab] → Nav item 2                  → ¡Directo al contenido!
[Tab] → Nav item 3
...
[Tab] → Nav item 20
[Tab] → Contenido (por fin)
```

### 7.5 Evitar trampas de foco (keyboard traps)

**Intuición**
Una trampa de foco es cuando el usuario navega con teclado y queda "atrapado" dentro de un componente sin poder salir. El ejemplo clásico: un modal que no se cierra con Escape.

```
TRAMPA DE FOCO:

┌─────────────────────────────────────┐
│  Modal                          [X] │
│                                     │
│  [Tab] → Campo 1                    │
│  [Tab] → Campo 2                    │
│  [Tab] → Botón                      │
│  [Tab] → Campo 1 (loop!)           │
│                                     │
│  [Escape] → ??? (nada pasa)        │ ← TRAMPA
│  No puede salir del modal.          │
└─────────────────────────────────────┘

FOCO GESTIONADO CORRECTAMENTE:

┌─────────────────────────────────────┐
│  Modal                          [X] │
│                                     │
│  [Tab] → Campo 1                    │
│  [Tab] → Campo 2                    │
│  [Tab] → Botón enviar               │
│  [Tab] → Botón cerrar [X]           │
│  [Tab] → Campo 1 (loop dentro)      │
│                                     │
│  [Escape] → Cierra modal ✓          │ ← CORRECTO
│  → Foco regresa al trigger          │
└─────────────────────────────────────┘
```

**Reglas para gestión de foco en modales:**
1. Al abrir: foco al primer elemento interactivo dentro del modal
2. Tab cicla solo dentro del modal (focus trap intencionado)
3. Escape cierra el modal
4. Al cerrar: foco regresa al elemento que abrió el modal
5. El fondo (backdrop) no es interactuable

---

## 8. Contenido accesible

### 8.1 Headings (H1–H6)

**Intuición**
Los headings son el esqueleto de tu página. Los screen readers los usan para crear un "índice" del contenido. Un usuario con screen reader puede saltar entre headings como tú saltas entre secciones con el scroll.

```
❌ HEADINGS MAL USADOS:              ✅ HEADINGS CORRECTOS:

<h1>Mi App</h1>                      <h1>Mi App</h1>
<h3>Bienvenido</h3>  ← Salta h2     <h2>Bienvenido</h2>
<h1>Productos</h1>   ← Otro h1      <h2>Productos</h2>
<h5>Categoría</h5>   ← Salta        <h3>Categoría A</h3>
<h2>Ofertas</h2>                     <h3>Categoría B</h3>
                                     <h2>Ofertas</h2>

Screen reader index:                 Screen reader index:
  h1 — Mi App                          h1 — Mi App
  h3 — Bienvenido (¿dónde está h2?)     h2 — Bienvenido
  h1 — Productos (¿dos h1?)             h2 — Productos
  h5 — Categoría (¿dónde está h3,h4?)     h3 — Categoría A
  h2 — Ofertas                             h3 — Categoría B
                                         h2 — Ofertas
Confuso, desordenado.
                                     Claro, jerárquico.
```

**Reglas:**
1. **Un solo `<h1>`** por página (el título principal)
2. **No saltar niveles**: h1 → h2 → h3, nunca h1 → h3
3. **Headings son estructura, no estilo**: No uses h3 porque "se ve más chico". Usa CSS para el tamaño
4. **Todo contenido debe pertenecer a una sección con heading**

### 8.2 Estructura semántica

```html
<!-- ❌ Todo con divs (div soup) -->
<div class="header">
  <div class="nav">
    <div class="nav-item">Inicio</div>
    <div class="nav-item">Blog</div>
  </div>
</div>
<div class="content">
  <div class="title">Artículo</div>
  <div class="text">Lorem ipsum...</div>
</div>
<div class="footer">© 2026</div>

<!-- Screen reader ve: "text, text, text, text..."
     No sabe qué es qué. -->


<!-- ✅ HTML semántico -->
<header>
  <nav aria-label="Principal">
    <ul>
      <li><a href="/">Inicio</a></li>
      <li><a href="/blog">Blog</a></li>
    </ul>
  </nav>
</header>
<main>
  <article>
    <h1>Artículo</h1>
    <p>Lorem ipsum...</p>
  </article>
</main>
<footer>
  <p>© 2026</p>
</footer>

<!-- Screen reader ve: "banner, navigation, main,
     article, heading 1, footer" — estructura clara -->
```

**Landmarks semánticos:**

| Elemento HTML | Rol ARIA implícito | Propósito |
|---|---|---|
| `<header>` | `banner` | Encabezado del sitio |
| `<nav>` | `navigation` | Menú de navegación |
| `<main>` | `main` | Contenido principal |
| `<aside>` | `complementary` | Contenido secundario |
| `<footer>` | `contentinfo` | Pie de página |
| `<section>` | `region` (con aria-label) | Sección temática |
| `<form>` | `form` | Formulario |
| `<search>` | `search` | Área de búsqueda (HTML 5.2+) |

### 8.3 Texto alternativo (alt text)

**Intuición**
El `alt` de una imagen es lo que "ve" un screen reader. Sin alt, la imagen no existe. Con un mal alt, confunde más que ayuda.

```
TIPOS DE ALT TEXT:

1. INFORMATIVA (transmite información):
   <img src="chart.png"
        alt="Gráfico de barras: ventas Q1 $50K, Q2 $75K, Q3 $90K" />

2. FUNCIONAL (es un botón o link):
   <img src="search-icon.png" alt="Buscar" />
   <img src="logo.png" alt="Ir a la página principal de Mi App" />

3. DECORATIVA (no agrega información):
   <img src="decorative-wave.png" alt="" />
   <!-- alt="" vacío = screen reader la ignora (correcto) -->
   <!-- Sin alt = screen reader lee el filename (malo) -->

4. COMPLEJA (gráficos, infografías):
   <img src="infographic.png"
        alt="Infografía sobre el proceso de diseño"
        aria-describedby="infographic-desc" />
   <div id="infographic-desc" class="sr-only">
     Descripción completa: Paso 1: Research...
   </div>
```

**Guía de decisión para alt text:**

```
¿La imagen transmite información?
│
├─ SÍ → ¿Es puramente funcional (botón, link)?
│  │
│  ├─ SÍ → alt = acción ("Buscar", "Cerrar", "Ir a inicio")
│  │
│  └─ NO → ¿Es simple o compleja?
│     ├─ Simple → alt = descripción breve (< 125 chars)
│     └─ Compleja → alt = resumen + aria-describedby con detalle
│
└─ NO → ¿Es puramente decorativa?
   │
   ├─ SÍ → alt="" (vacío, NO omitir el atributo)
   │
   └─ ¿Es redundante con texto cercano?
      └─ SÍ → alt="" (no repetir información)
```

### 8.4 Iconos con soporte textual

```html
<!-- ❌ Icono sin texto: inaccesible -->
<button>
  <svg><!-- icono de papelera --></svg>
</button>
<!-- Screen reader: "button" — ¿qué hace? -->

<!-- ✅ Icono decorativo con texto visible -->
<button>
  <svg aria-hidden="true"><!-- papelera --></svg>
  Eliminar
</button>
<!-- Screen reader: "Eliminar, button" ✓ -->

<!-- ✅ Icono funcional sin texto visible (icon-only button) -->
<button aria-label="Eliminar item">
  <svg aria-hidden="true" focusable="false">
    <!-- papelera -->
  </svg>
</button>
<!-- Screen reader: "Eliminar item, button" ✓ -->

<!-- ✅ Icono informativo (standalone) -->
<span role="img" aria-label="Advertencia">⚠️</span>
<svg role="img" aria-label="Verificado"><!-- check --></svg>
```

**Regla:**

| Tipo de icono | Con texto visible | Sin texto visible |
|---|---|---|
| **Decorativo** | `aria-hidden="true"` | `aria-hidden="true"` + texto sr-only |
| **Funcional** | `aria-hidden="true"` en el SVG | `aria-label` en el botón |
| **Informativo** | `aria-hidden="true"` (el texto basta) | `role="img"` + `aria-label` |

### 8.5 Lenguaje claro y simple

**WCAG 3.1 — Legible y comprensible:**

```
❌ JERGA TÉCNICA:                     ✅ LENGUAJE CLARO:

"Su solicitud ha sido               "Tu cuenta fue creada.
procesada satisfactoriamente.        Ya puedes iniciar sesión."
Proceda a autenticarse en
el sistema."

"Error 403: Forbidden.               "No tienes permiso para
Access denied to the                  ver esta página. Contacta
requested resource."                  al administrador."

"Timeout exception.                   "La conexión tardó demasiado.
Connection reset by peer."            Revisa tu internet e intenta
                                      de nuevo."
```

**Principios de lenguaje accesible:**
- Usa oraciones cortas (15-20 palabras máximo)
- Vocabulario simple (nivel de lectura de 8º grado)
- Voz activa ("Creamos tu cuenta" vs "Su cuenta ha sido creada")
- Un concepto por párrafo
- Evita dobles negaciones ("No es imposible" → "Es posible")
- Define siglas y términos técnicos al primer uso

---

## 9. Interacciones accesibles

### 9.1 Tiempo suficiente para acciones

**WCAG 2.2.1 — Timing Adjustable (A):**

```
❌ TIMEOUT SIN AVISO:                ✅ TIMEOUT ACCESIBLE:

"Tu sesión expirará en               ┌─────────────────────────────┐
 30 segundos."                       │ Tu sesión expirará en 2 min │
 [Solo un texto, sin opción]         │                             │
                                     │ [Extender sesión]           │
 → Un usuario con discapacidad       │ [Cerrar sesión]             │
   motora no alcanza a reaccionar    └─────────────────────────────┘
   en 30 segundos.
                                     → Aviso 2 min antes
                                     → Opción de extender
                                     → Botón grande y claro
```

**Reglas para timing:**
1. El usuario puede desactivar el límite de tiempo antes de encontrarlo
2. El usuario puede ajustar el tiempo (al menos 10x el default)
3. El usuario es avisado con al menos 20 segundos de anticipación y puede extender
4. Excepción: tiempo real (subastas), esencial (examen), o > 20 horas

### 9.2 Animaciones y motion

**WCAG 2.3.3 — Animation from Interactions (AAA) + buena práctica:**

```css
/* ✅ Respetar preferencia del usuario */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* ✅ Animaciones accesibles por defecto */
.card {
  transition: transform 200ms ease;  /* Corta y funcional */
}

/* ❌ Animaciones problemáticas */
.hero {
  animation: parallax-scroll 2s infinite;   /* Loop infinito */
  animation: flash 500ms 5;                 /* Parpadeo */
  animation: spin 1s infinite;              /* Rotación constante */
}
```

**Qué evitar:**
- Parpadeos > 3 veces por segundo (riesgo de convulsiones — WCAG 2.3.1)
- Animaciones en loop infinito sin control de pausa
- Parallax que causa mareo (vestibular disorders)
- Transiciones > 400ms (se sienten lentas)
- Auto-play de videos con movimiento

**Qué es aceptable:**
- Transiciones cortas (150-300ms) para feedback
- Fade in/out suaves
- Micro-interactions (hover, click) breves
- Skeleton screens (loading)
- Animaciones que el usuario activa explícitamente

### 9.3 Feedback claro en acciones

```
CADA ACCIÓN NECESITA FEEDBACK:

Acción                    Feedback esperado
──────────────────        ──────────────────────────────
Click en botón            → Estado "loading" + disabled
                          → Resultado (éxito / error)

Envío de formulario       → Loading state
                          → "Formulario enviado" (toast o redirect)
                          → O errores específicos por campo

Eliminar item             → Confirmación previa
                          → "Eliminado. [Deshacer]" (toast)

Toggle switch             → Cambio visual inmediato
                          → Anuncio para screen reader
                            (aria-live o role="status")

Carga de archivo          → Barra de progreso
                          → "archivo.pdf subido ✓"
```

```html
<!-- ✅ Feedback accesible para acciones asíncronas -->
<div aria-live="polite" aria-atomic="true" class="sr-only" id="status">
  <!-- JS inyecta mensajes aquí -->
</div>

<script>
  // Al completar una acción:
  document.getElementById('status').textContent =
    'Perfil actualizado correctamente';
  // El screen reader anuncia: "Perfil actualizado correctamente"
</script>
```

### 9.4 Estados de carga y error comprensibles

```
LOADING STATES:

❌ INACCESIBLE:                      ✅ ACCESIBLE:

  [spinner girando]                    [spinner] Cargando productos...
  (sin texto, sin ARIA)                aria-busy="true"
                                       aria-live="polite"
                                       → Screen reader anuncia carga


ERROR STATES:

❌ INACCESIBLE:                      ✅ ACCESIBLE:

  (página en blanco)                  ┌──────────────────────────────┐
  (o solo un código: 500)             │  😕 Algo salió mal            │
                                      │                              │
                                      │  No pudimos cargar los       │
                                      │  productos. Esto suele       │
                                      │  resolverse en unos minutos. │
                                      │                              │
                                      │  [Intentar de nuevo]         │
                                      │  [Ir al inicio]              │
                                      └──────────────────────────────┘
                                      role="alert" para screen readers
```

---

## 10. Implementación técnica

### 10.1 HTML semántico como base

**Intuición**
HTML semántico es accesibilidad gratis. Un `<button>` tiene teclado, foco, y rol de botón integrados. Un `<div onclick>` no tiene nada de eso y necesitas reconstruirlo manualmente con ARIA y JavaScript.

```html
<!-- ❌ Div como botón (caro y frágil) -->
<div class="button" onclick="submit()" style="cursor: pointer;">
  Enviar
</div>
<!-- Problemas:
     → No recibe foco con Tab
     → No se activa con Enter/Space
     → Screen reader lo lee como "text"
     → Necesitas tabindex, role, onkeydown...
-->

<!-- ✅ Botón semántico (gratis y robusto) -->
<button type="submit" class="btn-primary">
  Enviar
</button>
<!-- Incluye GRATIS:
     → Focusable con Tab ✓
     → Activable con Enter y Space ✓
     → Screen reader: "Enviar, button" ✓
     → Submit de form nativo ✓
-->
```

**Tabla de elementos semánticos vs divs:**

| En vez de... | Usa... | Obtienes gratis... |
|---|---|---|
| `<div onclick>` | `<button>` | Focus, keyboard, role |
| `<div class="link">` | `<a href>` | Focus, keyboard, navigation |
| `<div class="input">` | `<input>` | Focus, keyboard, autocomplete, validación |
| `<div class="list">` | `<ul>` / `<ol>` | Conteo de items, estructura |
| `<div class="header">` | `<header>` | Landmark navigation |
| `<div class="nav">` | `<nav>` | Landmark navigation |
| `<span>Título</span>` | `<h2>` | Heading navigation, outline |
| `<div class="table">` | `<table>` | Row/column relationships |

### 10.2 ARIA (Accessible Rich Internet Applications)

**Intuición**
ARIA es un puente entre componentes custom y las tecnologías de asistencia. Cuando HTML semántico no es suficiente (porque el componente no existe en HTML), ARIA describe qué es, qué hace y en qué estado está.

**Las 3 reglas de ARIA:**

```
REGLA 1: Si puedes usar HTML nativo, úsalo.
         ARIA es el plan B, no el plan A.

REGLA 2: No cambies la semántica nativa sin razón.
         <h2 role="button"> ← NO. Usa <button>.

REGLA 3: Todo elemento interactivo con ARIA
         debe ser operado por teclado.
         role="button" sin onkeydown = roto.
```

**Categorías de ARIA:**

```
ARIA
├── Roles (¿qué es?)
│   ├── Landmarks:  banner, navigation, main, complementary
│   ├── Widgets:    button, tab, dialog, slider, checkbox
│   ├── Structure:  list, listitem, table, row, cell
│   └── Live:       alert, status, timer, log
│
├── Properties (¿qué tiene?)
│   ├── aria-label         → Nombre accesible
│   ├── aria-labelledby    → Nombre desde otro elemento
│   ├── aria-describedby   → Descripción adicional
│   ├── aria-required      → Campo obligatorio
│   ├── aria-haspopup      → Tiene popup/menú
│   └── aria-controls      → Controla otro elemento
│
└── States (¿en qué estado está?)
    ├── aria-expanded       → Expandido/colapsado
    ├── aria-selected       → Seleccionado
    ├── aria-checked        → Marcado (checkbox)
    ├── aria-disabled       → Deshabilitado
    ├── aria-hidden         → Oculto para AT
    ├── aria-invalid        → Valor inválido
    └── aria-busy           → Cargando
```

### 10.3 Ejemplos de componentes accesibles con ARIA

**Tabs:**

```html
<div role="tablist" aria-label="Secciones de configuración">
  <button role="tab"
          id="tab-general"
          aria-selected="true"
          aria-controls="panel-general">
    General
  </button>
  <button role="tab"
          id="tab-security"
          aria-selected="false"
          aria-controls="panel-security"
          tabindex="-1">
    Seguridad
  </button>
  <button role="tab"
          id="tab-notif"
          aria-selected="false"
          aria-controls="panel-notif"
          tabindex="-1">
    Notificaciones
  </button>
</div>

<div role="tabpanel"
     id="panel-general"
     aria-labelledby="tab-general">
  <!-- Contenido de General -->
</div>

<div role="tabpanel"
     id="panel-security"
     aria-labelledby="tab-security"
     hidden>
  <!-- Contenido de Seguridad -->
</div>

<!--
Keyboard behavior:
  Tab → entra al tablist, focus en tab activo
  ←/→ → navega entre tabs
  Tab → sale al tabpanel
-->
```

**Modal/Dialog:**

```html
<button id="open-modal" aria-haspopup="dialog">
  Eliminar cuenta
</button>

<div role="dialog"
     aria-modal="true"
     aria-labelledby="modal-title"
     aria-describedby="modal-desc"
     hidden>

  <h2 id="modal-title">¿Eliminar tu cuenta?</h2>
  <p id="modal-desc">
    Esta acción no se puede deshacer. Perderás todos tus datos.
  </p>

  <button class="btn-tertiary" id="modal-cancel">Cancelar</button>
  <button class="btn-destructive" id="modal-confirm">
    Eliminar permanentemente
  </button>
</div>

<script>
// Al abrir: focus al primer interactivo dentro del modal
// Tab cicla dentro del modal (focus trap)
// Escape cierra el modal
// Al cerrar: focus regresa al botón que lo abrió (#open-modal)
</script>
```

**Accordion:**

```html
<div class="accordion">
  <h3>
    <button aria-expanded="true" aria-controls="section1-content">
      ¿Cómo cancelo mi suscripción?
    </button>
  </h3>
  <div id="section1-content" role="region" aria-labelledby="section1-heading">
    <p>Ve a Configuración > Suscripción > Cancelar...</p>
  </div>

  <h3>
    <button aria-expanded="false" aria-controls="section2-content">
      ¿Puedo obtener un reembolso?
    </button>
  </h3>
  <div id="section2-content" role="region" hidden>
    <p>Sí, dentro de los primeros 30 días...</p>
  </div>
</div>
```

### 10.4 Navegación por teclado (tabindex)

```
tabindex EXPLICADO:

tabindex="0"
→ Hace el elemento focusable en el orden natural del DOM
→ Úsalo para elementos custom que necesitan foco
→ Ej: <div role="button" tabindex="0">

tabindex="-1"
→ Focusable SOLO por JavaScript (element.focus())
→ NO aparece en el orden de tabulación
→ Ej: Tabs inactivos, elementos que reciben foco programático

tabindex="1" (o cualquier positivo)
→ EVITAR. Altera el orden natural de tabulación.
→ Casi nunca es la solución correcta.
→ Crea confusión para usuarios de teclado.
```

**Ejemplo: Custom component con teclado:**

```html
<div role="toolbar" aria-label="Opciones de formato">
  <button aria-label="Negrita" aria-pressed="false">B</button>
  <button aria-label="Cursiva" aria-pressed="false">I</button>
  <button aria-label="Subrayado" aria-pressed="true">U</button>
</div>

<script>
// Keyboard pattern para toolbar:
// Tab → entra al toolbar (focus en primer botón)
// ←/→ → navega entre botones dentro del toolbar
// Tab → sale del toolbar al siguiente elemento
// Enter/Space → activa el botón

const toolbar = document.querySelector('[role="toolbar"]');
const buttons = toolbar.querySelectorAll('button');

toolbar.addEventListener('keydown', (e) => {
  const currentIndex = Array.from(buttons).indexOf(document.activeElement);

  if (e.key === 'ArrowRight') {
    e.preventDefault();
    const next = (currentIndex + 1) % buttons.length;
    buttons[next].focus();
  }

  if (e.key === 'ArrowLeft') {
    e.preventDefault();
    const prev = (currentIndex - 1 + buttons.length) % buttons.length;
    buttons[prev].focus();
  }
});
</script>
```

### 10.5 Visually Hidden (solo para screen readers)

```css
/* Texto visible solo para screen readers */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}

/* ¿Cuándo usar?
   → Cuando necesitas texto para screen readers
     pero no quieres mostrarlo visualmente.
   → Ej: "3 items en el carrito" en el ícono del carrito
   → Ej: "Abrir menú" en un botón de hamburguesa
*/
```

```html
<button class="cart-icon">
  🛒 <span class="sr-only">Carrito: 3 productos</span>
  <span class="badge" aria-hidden="true">3</span>
</button>

<!-- Visual: ícono 🛒 con badge "3"
     Screen reader: "Carrito: 3 productos, button" -->
```

---

## 11. Testing y validación

### 11.1 Testing manual

**Intuición**
Las herramientas automáticas detectan ~30-40% de los problemas de accesibilidad. El resto requiere testing manual con teclado, screen reader y juicio humano.

**Test #1 — Navegación por teclado (5 minutos):**

```
CHECKLIST:
□ Tab a través de toda la página
  → ¿Todos los interactivos reciben foco?
  → ¿El orden es lógico?
  → ¿El foco es siempre visible?

□ Activar elementos
  → ¿Enter activa links y botones?
  → ¿Space activa botones y checkboxes?
  → ¿Arrow keys navegan radios, tabs, menús?

□ Escape
  → ¿Cierra modales, dropdowns, popovers?
  → ¿El foco regresa al trigger?

□ Sin trampas
  → ¿Puedo salir de cualquier componente con Tab?
  → ¿Nunca me quedo "atrapado"?
```

**Test #2 — Screen reader (10 minutos):**

```
macOS: VoiceOver (Cmd + F5)
Windows: NVDA (gratis) o Narrator (Win + Ctrl + Enter)

CHECKLIST:
□ ¿Todas las imágenes tienen alt text o alt=""?
□ ¿Los headings forman una estructura lógica?
  (VoiceOver: Rotor > Headings)
□ ¿Los form fields anuncian su label?
□ ¿Los errores se anuncian automáticamente?
□ ¿Los botones de solo ícono tienen aria-label?
□ ¿Los landmarks están presentes?
  (header, nav, main, footer)
□ ¿Las regiones dinámicas se anuncian?
  (aria-live, role="alert")
```

**Test #3 — Visual (5 minutos):**

```
CHECKLIST:
□ Zoom al 200% → ¿El contenido sigue legible?
□ Zoom al 400% → ¿Es usable (WCAG 1.4.10)?
□ Color desactivado → ¿La info se entiende sin color?
□ Alto contraste → ¿Los bordes son visibles?
□ prefers-reduced-motion → ¿Las animaciones se detienen?
```

### 11.2 Herramientas automatizadas

**Lighthouse (Chrome DevTools):**

```
Cómo usar:
1. Chrome → DevTools (F12)
2. Pestaña "Lighthouse"
3. Seleccionar "Accessibility"
4. "Analyze page load"

Qué detecta:
✓ Contraste insuficiente
✓ Imágenes sin alt
✓ Labels faltantes en forms
✓ Heading hierarchy rota
✓ ARIA inválido
✓ Focus order issues
✓ Touch target size

Qué NO detecta:
✗ Calidad del alt text
✗ Orden lógico del contenido
✗ Keyboard traps complejas
✗ Experiencia real con screen reader
✗ Comprensibilidad del lenguaje

Score: 0-100 (apunta a 95+, pero 100 ≠ accesible)
```

**axe DevTools:**

```
Instalación:
  Chrome Extension: "axe DevTools - Web Accessibility Testing"

Cómo usar:
  1. DevTools → Pestaña "axe DevTools"
  2. "Scan ALL of my page"
  3. Revisar issues por severidad:
     🔴 Critical — Bloquea uso para algunos usuarios
     🟠 Serious — Dificulta significativamente
     🟡 Moderate — Impacto medio
     🔵 Minor — Mejora potencial

Ventajas sobre Lighthouse:
→ Más criterios evaluados
→ Mejor explicación de cada issue
→ Sugiere fix específico
→ Permite escanear componentes individuales
→ Integración con CI/CD (axe-core npm package)
```

**Otras herramientas:**

| Herramienta | Tipo | Uso |
|---|---|---|
| **WAVE** | Browser extension | Overlay visual de problemas |
| **Stark** | Plugin Figma/Sketch | Contraste y simulación en diseño |
| **Pa11y** | CLI / CI | Testing automatizado en CI/CD |
| **eslint-plugin-jsx-a11y** | Linter | Errores de a11y en React/JSX |
| **axe-core** | npm package | Testing programático |
| **Accessibility Insights** | Browser extension (MS) | Testing manual guiado |

### 11.3 Auditorías de accesibilidad

**Proceso de auditoría completo:**

```
FASE 1: AUTOMATED SCAN
─────────────────────────
→ Lighthouse + axe DevTools
→ Listar todos los issues automáticos
→ Clasificar por severidad
→ ~30% de issues detectados

FASE 2: MANUAL TESTING
─────────────────────────
→ Keyboard navigation completa
→ Screen reader testing (VoiceOver / NVDA)
→ Zoom 200% y 400%
→ Color/contrast manual check
→ ~40% adicional de issues

FASE 3: USER TESTING
─────────────────────────
→ Testing con usuarios reales con discapacidades
→ Observar uso de tecnologías de asistencia
→ Identificar barreras no detectables por herramientas
→ ~30% restante de issues

FASE 4: REPORT + REMEDIATION
─────────────────────────
→ Documentar cada issue con:
   - Criterio WCAG violado
   - Severidad (crítico/serio/moderado)
   - Screenshot / recording
   - Recomendación de fix
→ Priorizar y planificar remediación
```

### 11.4 Integración en procesos de desarrollo

```
SHIFT-LEFT ACCESSIBILITY:

     Antes:                          Después (shift-left):

     Diseño → Dev → QA → Launch      Diseño → Dev → QA → Launch
                          │           │        │      │
                          ▼           ▼        ▼      ▼
                        [A11y        [A11y   [A11y  [A11y
                         audit]       in      lint   auto
                                     Figma]  CI/CD] test]

     Caro: encontrar y arreglar       Barato: prevenir desde
     al final del proceso              el inicio del proceso
```

**Integración práctica:**

| Fase | Herramienta / Proceso |
|---|---|
| **Diseño** | Stark en Figma, checklist de a11y en design review |
| **Desarrollo** | eslint-plugin-jsx-a11y, semantic HTML first |
| **Code Review** | Checklist de a11y en PR template |
| **CI/CD** | axe-core + Pa11y en pipeline |
| **QA** | Testing manual con teclado + screen reader |
| **Monitoring** | Auditorías periódicas, métricas de a11y |

---

## 12. Nivel intermedio / avanzado

### 12.1 Accesibilidad en design systems

**Intuición**
Si un componente del design system es accesible, cada producto que lo use hereda esa accesibilidad. Si es inaccesible, cada producto hereda esa barrera. La accesibilidad en el design system es el mayor multiplicador de impacto.

**Checklist por componente del design system:**

```
PARA CADA COMPONENTE:

□ Semántica
  → ¿Usa el elemento HTML correcto?
  → ¿Tiene roles ARIA si es custom?

□ Teclado
  → ¿Es focusable?
  → ¿Responde a Enter, Space, Escape, flechas?

□ Screen reader
  → ¿Tiene nombre accesible?
  → ¿Anuncia estado (expanded, selected, checked)?
  → ¿Los cambios dinámicos se anuncian?

□ Visual
  → ¿Cumple contraste AA (4.5:1 texto, 3:1 UI)?
  → ¿Tiene foco visible?
  → ¿No depende solo del color?

□ Responsive
  → ¿Touch target ≥ 44px?
  → ¿Funciona con zoom 200%?
  → ¿Funciona con text spacing WCAG 1.4.12?

□ Documentación
  → ¿Incluye guía de accesibilidad?
  → ¿Muestra uso correcto de ARIA?
  → ¿Tiene tests de a11y?
```

### 12.2 Componentes accesibles reutilizables

**Ejemplo: Toggle/Switch accesible:**

```html
<!-- ✅ Toggle accesible con HTML + ARIA -->
<label class="toggle">
  <input type="checkbox"
         role="switch"
         aria-checked="false"
         aria-label="Modo oscuro" />
  <span class="toggle-track">
    <span class="toggle-thumb"></span>
  </span>
  <span class="toggle-label">Modo oscuro</span>
</label>

<!--
  role="switch" → Le dice al screen reader que es un switch
  aria-checked → Estado actual (actualizar con JS)
  Label visible → Siempre saber qué controla
  Input nativo → Keyboard support gratis
-->
```

**Ejemplo: Tooltip accesible:**

```html
<!-- ✅ Tooltip que funciona para todos -->
<button
  aria-describedby="tooltip-1"
  data-tooltip>
  Exportar
</button>

<div id="tooltip-1" role="tooltip" hidden>
  Descarga los datos en formato CSV
</div>

<!--
  Keyboard: Tooltip aparece con focus
  Mouse: Tooltip aparece con hover
  Screen reader: Contenido anunciado vía aria-describedby
  Touch: Tooltip NO depende de hover (long press o toggle)

  ❌ NO hacer tooltips con :hover-only (inaccesible para teclado y touch)
-->
```

### 12.3 Edge cases: Modales, Overlays, Drag & Drop

**Modales — Reglas completas:**

```
AL ABRIR MODAL:
1. Guardar referencia al trigger (el botón que lo abrió)
2. Mostrar modal + backdrop
3. Agregar aria-hidden="true" a TODO fuera del modal
4. Mover foco al primer interactivo (o al heading si no hay)
5. Activar focus trap (Tab cicla dentro del modal)
6. Agregar listener para Escape

AL CERRAR MODAL:
1. Ocultar modal + backdrop
2. Remover aria-hidden="true" del contenido detrás
3. Devolver foco al trigger original
4. Remover focus trap y listener de Escape
```

**Drag & Drop accesible:**

```
El drag & drop es uno de los patrones MÁS difíciles
de hacer accesible. La clave: proveer alternativa.

❌ Solo drag & drop:
  → Inaccesible para teclado, screen reader, voice control

✅ Drag & drop + alternativa accesible:

  VISUAL (mouse):           ALTERNATIVA (teclado):
  ┌──────┐                  ┌────────────────────────┐
  │ Item │ ← Drag           │ Item 1  [↑] [↓] [✕]  │
  │  ⠿   │                  │ Item 2  [↑] [↓] [✕]  │
  └──────┘                  │ Item 3  [↑] [↓] [✕]  │
    ↓ Drop                  └────────────────────────┘
  ┌──────┐                  Botones para reordenar
  │      │                  + aria-live para anunciar
  └──────┘                  la nueva posición

Implementación:
→ Space/Enter para "agarrar" un item
→ Arrow keys para moverlo
→ Space/Enter para "soltar"
→ Escape para cancelar
→ aria-live="assertive" para anunciar:
  "Item 1 movido a posición 3 de 5"
```

**Overlays (popovers, dropdowns, date pickers):**

```
REGLAS COMUNES PARA OVERLAYS:

1. TRIGGER:
   → aria-haspopup="true" (o "dialog", "listbox", "menu")
   → aria-expanded="true/false"
   → aria-controls="overlay-id"

2. OVERLAY:
   → role correcto (menu, listbox, dialog, etc.)
   → aria-labelledby → apunta al trigger o a un título
   → Focusable

3. KEYBOARD:
   → Enter/Space → Abre overlay
   → Escape → Cierra overlay
   → Arrow keys → Navega dentro (si es menu/listbox)
   → Tab → Cierra y avanza (si es popover simple)

4. FOCO:
   → Al abrir: foco al overlay
   → Al cerrar: foco regresa al trigger
   → Focus trap SI es dialog/modal, NO si es tooltip/popover
```

### 12.4 Integración continua de accesibilidad (Shift-Left)

**El concepto "shift-left" significa mover la accesibilidad hacia la izquierda en el timeline del desarrollo: cuanto antes detectes un problema, más barato y fácil es arreglarlo.**

```
COSTO DE ARREGLAR UN ISSUE DE A11Y:

Fase de diseño:      $1x   ← Cambiar un color en Figma
Fase de desarrollo:  $5x   ← Refactorizar un componente
Fase de QA:          $10x  ← Rewrite + re-test
Post-lanzamiento:    $30x  ← Hotfix + posible demanda legal
Después de demanda:  $100x ← Remediation total + multa
```

**Pipeline completo de a11y integrada:**

```
┌─────────────┐    ┌──────────────┐    ┌────────────────┐
│   DISEÑO    │───→│  DESARROLLO  │───→│   QA / TEST    │
│             │    │              │    │                │
│ • Stark     │    │ • eslint     │    │ • Manual KB    │
│ • Contrast  │    │   jsx-a11y   │    │ • Screen reader│
│   checker   │    │ • Semantic   │    │ • axe scan     │
│ • A11y      │    │   HTML first │    │ • Zoom test    │
│   checklist │    │ • axe-core   │    │ • User testing │
│ • Color     │    │   in tests   │    │   (if possible)│
│   blind sim │    │              │    │                │
└─────────────┘    └──────────────┘    └────────────────┘
      ↕                  ↕                    ↕
  Design review      Code review          QA checklist
  con a11y criteria  con a11y criteria    con a11y criteria
```

**En CI/CD:**

```bash
# package.json — scripts de a11y
{
  "scripts": {
    "test:a11y": "axe-core tests",
    "lint:a11y": "eslint --config .eslintrc.a11y.js src/",
    "audit:a11y": "pa11y-ci --config .pa11yci.json"
  }
}

# .github/workflows/a11y.yml
# Bloquear merge si hay issues críticos de a11y
```

---

## Cheat Sheet — Accesibilidad

```
┌──────────────────────────────────────────────────────────────────┐
│                   ACCESSIBILITY CHEAT SHEET                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PRINCIPIOS POUR:                                                │
│  P → ¿Puede percibir? (alt, captions, contraste)                │
│  O → ¿Puede operar? (teclado, tiempo, sin convulsiones)         │
│  U → ¿Puede entender? (claro, predecible, errores útiles)       │
│  R → ¿Es robusto? (HTML válido, ARIA correcto, compatible)      │
│                                                                  │
│  CONTRASTE:                                                      │
│  Texto normal: ≥ 4.5:1 (AA) / ≥ 7:1 (AAA)                      │
│  Texto grande: ≥ 3:1 (AA) / ≥ 4.5:1 (AAA)                      │
│  UI elements:  ≥ 3:1 (AA)                                       │
│                                                                  │
│  NO DEPENDER SOLO DE COLOR:                                      │
│  Siempre: Color + Icono + Texto (mínimo 2 canales)              │
│                                                                  │
│  HTML SEMÁNTICO PRIMERO:                                         │
│  <button> no <div onclick>                                       │
│  <a href> no <span class="link">                                 │
│  <nav>, <main>, <header>, <footer> → Landmarks                  │
│                                                                  │
│  FORMULARIOS:                                                    │
│  ✅ <label for="id"> siempre visible                             │
│  ✅ aria-required, aria-invalid, aria-describedby                │
│  ✅ role="alert" en errores dinámicos                            │
│  ✅ fieldset + legend para grupos                                │
│                                                                  │
│  KEYBOARD:                                                       │
│  Tab → siguiente interactivo                                     │
│  Shift+Tab → anterior                                            │
│  Enter → activar link/botón                                      │
│  Space → activar botón/checkbox                                  │
│  Escape → cerrar overlay                                         │
│  Arrows → dentro de widget (tabs, radios, menús)                 │
│                                                                  │
│  ARIA (solo si HTML nativo no alcanza):                          │
│  Roles: button, tab, dialog, alert, status                       │
│  Props: aria-label, aria-labelledby, aria-describedby            │
│  States: aria-expanded, aria-selected, aria-hidden               │
│                                                                  │
│  FOCO:                                                           │
│  ✅ :focus-visible con outline ≥ 3px                             │
│  ✅ tabindex="0" para custom elements                            │
│  ✅ tabindex="-1" para foco programático                         │
│  ❌ tabindex > 0 (nunca)                                         │
│  ❌ outline: none sin reemplazo                                  │
│                                                                  │
│  ALT TEXT:                                                       │
│  Informativa → descripción breve                                 │
│  Funcional → acción ("Buscar", "Cerrar")                         │
│  Decorativa → alt="" (vacío)                                     │
│  Compleja → resumen + aria-describedby                           │
│                                                                  │
│  TOUCH TARGETS:                                                  │
│  Mínimo: 24×24px (WCAG 2.2 AA)                                  │
│  Recomendado: 44×44px                                            │
│  Spacing: ≥ 8px entre targets                                    │
│                                                                  │
│  TESTING:                                                        │
│  Automático: Lighthouse, axe DevTools, Pa11y (~30-40% issues)    │
│  Manual: Keyboard, screen reader, zoom 200% (~40% issues)        │
│  Usuario: Testing con personas con discapacidades (~30% issues)  │
│                                                                  │
│  ANTI-PATRONES:                                                  │
│  ❌ Placeholder como label         ❌ outline: none              │
│  ❌ Solo color para info           ❌ tabindex > 0               │
│  ❌ div como botón                 ❌ Keyboard traps             │
│  ❌ Imágenes sin alt               ❌ Animaciones sin pausa      │
│  ❌ ARIA innecesario               ❌ "Accesibilidad al final"   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Errores Comunes y Decisiones Incorrectas

| # | Error | Por qué es malo | Solución |
|---|---|---|---|
| 1 | `outline: none` sin reemplazo | Foco invisible para usuarios de teclado | `:focus-visible` con outline claro |
| 2 | Solo color para indicar error | Invisible para daltónicos | Color + icono + texto |
| 3 | `<div onclick>` como botón | Sin teclado, sin rol, sin foco | Usar `<button>` nativo |
| 4 | Imágenes sin `alt` | Invisibles para screen readers | `alt` descriptivo o `alt=""` si decorativa |
| 5 | Placeholder como único label | Desaparece al escribir, bajo contraste | Label visible siempre + placeholder como ejemplo |
| 6 | Saltar niveles de heading | Estructura rota para screen readers | h1 → h2 → h3, sin saltos |
| 7 | Modal sin gestión de foco | Keyboard trap o foco perdido | Focus trap + Escape + return focus |
| 8 | `tabindex="5"` | Rompe el orden natural de tabulación | Usar `tabindex="0"` o `-1` |
| 9 | ARIA redundante o incorrecto | Confunde a screen readers | HTML semántico primero, ARIA solo si necesario |
| 10 | Testing solo con Lighthouse | Detecta ~30% de issues | Combinar automático + manual + usuarios |
| 11 | Accesibilidad al final del proceso | Caro, superficial, incompleto | Shift-left: desde diseño |
| 12 | Animaciones sin `prefers-reduced-motion` | Mareo, convulsiones, distracción | Media query para reducir motion |

---

> **Referencia rápida de criterios WCAG más relevantes:**
> - **1.1.1** (A) — Non-text content (alt text)
> - **1.3.1** (A) — Info and relationships (semántica)
> - **1.4.1** (A) — Use of color (no solo color)
> - **1.4.3** (AA) — Contrast minimum (4.5:1)
> - **1.4.11** (AA) — Non-text contrast (3:1 UI elements)
> - **2.1.1** (A) — Keyboard (todo accesible por teclado)
> - **2.4.3** (A) — Focus order (orden lógico)
> - **2.4.7** (AA) — Focus visible (outline visible)
> - **2.5.8** (AA) — Target size minimum (24×24px)
> - **3.3.2** (A) — Labels or instructions (labels en forms)
> - **4.1.2** (A) — Name, role, value (ARIA correcto)
