# Typography — Módulo Completo

---

## 1. Introducción a Typography en UX/UI

### 1.1 Qué es la Tipografía y su Rol en Productos Digitales

- **Intuición:** La tipografía es la voz visual de tu producto. Así como el tono de voz de una persona comunica confianza, urgencia o calma antes de que proceses las palabras, la tipografía comunica profesionalismo, claridad o caos antes de que el usuario lea una sola línea.
- **Estructura formal:** La tipografía en UX/UI es el sistema de decisiones sobre la selección, tamaño, peso, espaciado y disposición del texto en una interfaz digital, con el objetivo de maximizar legibilidad, establecer jerarquía visual y reforzar la identidad del producto.
- **Aplicación práctica:** El 95% del contenido en una interfaz es texto. Si tu tipografía no funciona, tu producto no funciona — sin importar cuán buenos sean los colores, los iconos o las ilustraciones.

### 1.2 Impacto en Legibilidad, Escaneo y Jerarquía Visual

```
El mismo contenido con diferente tipografía:

  ❌ Sin sistema tipográfico:
  ┌─────────────────────────────────────────┐
  │  welcome to our platform                │  ← sin jerarquía
  │  Manage your projects with ease.        │  ← mismo peso que todo
  │  start now  learn more                  │  ← CTAs invisibles
  │  Features  Pricing  About               │  ← nav sin distinción
  └─────────────────────────────────────────┘
  Todo se ve igual → el usuario no sabe dónde mirar.

  ✅ Con sistema tipográfico:
  ┌─────────────────────────────────────────┐
  │  Welcome to Our Platform                │  ← H1: 40px, bold
  │                                         │
  │  Manage your projects with ease.        │  ← Body: 18px, regular
  │                                         │
  │  [ Start Now ]    Learn more →          │  ← CTA: 16px, semibold
  │                                         │
  │  Features   Pricing   About             │  ← Nav: 14px, medium
  └─────────────────────────────────────────┘
  La jerarquía guía el ojo: título → descripción → acción → nav.
```

| Aspecto | Tipografía pobre | Tipografía intencional |
|---|---|---|
| **Legibilidad** | Texto difícil de leer, fatiga rápida | Lectura fluida y cómoda |
| **Escaneo** | El usuario no encuentra lo importante | El ojo va directamente al contenido clave |
| **Jerarquía** | Todo parece igual de relevante | Cada nivel de información es distinguible |
| **Confianza** | "Se ve amateur, no confío" | "Se ve profesional, inspira confianza" |
| **Velocidad** | Tarda más en encontrar lo que busca | Encuentra lo que necesita en segundos |

### 1.3 Relación entre Tipografía, Branding y UX

```
Tipografía = Intersección de tres mundos:

         BRANDING
        (identidad)
           /\
          /  \
         /    \
        / Tipo-\
       / grafía \
      /──────────\
     /            \
    UX             UI
 (legibilidad)  (estética)

  - Branding: ¿La fuente refleja la personalidad de la marca?
  - UX: ¿El texto se lee sin esfuerzo?
  - UI: ¿El sistema visual es consistente y atractivo?

  La tipografía debe satisfacer LOS TRES.
  Si sacrificas legibilidad por personalidad → mala UX.
  Si sacrificas personalidad por seguridad → marca genérica.
  El equilibrio es la clave.
```

### 1.4 Tipografía como Sistema, No como Decisión Aislada

Un sistema tipográfico define **todas las decisiones de texto por adelantado**:

```
Decisión aislada vs Sistema:

  ❌ Decisión aislada:
  "Esta pantalla necesita un título... ¿36px? ¿Bold? ¿Inter?
   Y este otro texto... ¿14px? ¿Regular? Hmm, ¿o 13px?"
   → Cada pantalla se diseña ad-hoc, inconsistencia garantizada.

  ✅ Sistema tipográfico:
  "Esto es un H2 → consulto mi sistema → 24px, Semibold, Inter.
   Esto es body text → 16px, Regular, Inter. Line-height 1.5."
   → Toda decisión está pre-definida, consistencia automática.
```

**Componentes de un sistema tipográfico:**

| Componente | Qué define | Ejemplo |
|---|---|---|
| Font family | Qué fuente(s) usar | Inter, Merriweather |
| Type scale | Tamaños disponibles | 12, 14, 16, 18, 20, 24, 32, 40, 48 |
| Weight scale | Pesos disponibles | Regular (400), Medium (500), Semibold (600), Bold (700) |
| Line-height | Altura de línea por tamaño | 1.5 para body, 1.2 para headings |
| Letter-spacing | Tracking por contexto | -0.02em para headings, 0 para body |
| Text styles | Combinaciones nombradas | Heading/Large, Body/Default, Caption |

> **Error común:** Elegir una fuente bonita y pensar que el trabajo está hecho. La fuente es solo el primer paso — el sistema completo incluye tamaños, pesos, spacing, jerarquía y reglas de uso.

---

## 2. Propiedades de Texto

### 2.1 Tamaño (font-size)

- **Intuición:** El tamaño del texto es lo primero que comunica importancia. Grande = importante. Pequeño = secundario. Simple pero poderoso.
- **Estructura formal:** `font-size` define la altura del cuerpo de la fuente en unidades absolutas (px) o relativas (rem, em).

```
Tamaños típicos en interfaces:

  48px ─── Display / Hero heading
  40px ─── H1 (título principal de página)
  32px ─── H2 (secciones)
  24px ─── H3 (subsecciones)
  20px ─── H4 (bloques)
  18px ─── H5 / Lead text
  16px ─── Body (texto principal) ← BASE
  14px ─── Body small / UI text
  12px ─── Caption / metadata
  11px ─── Mínimo legible (evitar en lo posible)

  Regla: body text NUNCA menor a 16px en interfaces.
  En mobile, 16px es el mínimo para evitar zoom automático en iOS.
```

```css
/* Usar rem para escalabilidad (1rem = 16px por defecto) */
html { font-size: 16px; }       /* base */
h1   { font-size: 2.5rem; }    /* 40px */
h2   { font-size: 2rem; }      /* 32px */
h3   { font-size: 1.5rem; }    /* 24px */
p    { font-size: 1rem; }      /* 16px */
small { font-size: 0.875rem; } /* 14px */
```

### 2.2 Peso (font-weight)

- **Intuición:** El peso es el "volumen" del texto — regular es hablar normalmente, bold es enfatizar, light es susurrar.

```
Escala de font-weight:

  100 ─── Thin         (rara vez se usa en UI)
  200 ─── Extra Light  (rara vez se usa en UI)
  300 ─── Light        (cuerpo muy ligero, difícil de leer en small sizes)
  400 ─── Regular      ← Body text, descripciones
  500 ─── Medium       ← Labels, nav items, UI text con énfasis
  600 ─── Semibold     ← Headings, botones, énfasis fuerte
  700 ─── Bold         ← Headings principales, CTAs
  800 ─── Extra Bold   (uso decorativo)
  900 ─── Black        (uso decorativo / branding)

  En la práctica: usa 3-4 pesos máximo.
  Recomendación: Regular (400) + Medium (500) + Semibold (600) + Bold (700)
```

> **Anti-patrón:** Usar 6+ pesos diferentes. La diferencia entre 400 y 500, o entre 600 y 700, es sutil — si usas demasiados, el usuario no puede distinguir la jerarquía.

### 2.3 Altura de Línea (line-height)

- **Intuición:** La altura de línea es el espacio entre renglones. Muy apretado y el texto se siente ahogado. Muy abierto y pierde cohesión. El punto justo hace que la lectura fluya.
- **Estructura formal:** `line-height` define la distancia entre baselines consecutivas. Se expresa como multiplicador (1.5), porcentaje (150%) o valor absoluto (24px).

```
Line-height según contexto:

  Headings (display):     1.1 – 1.2
  ──────────────────────────────
  This Is a Large
  Heading Text             ← líneas cercanas, bloque compacto

  Headings (section):     1.2 – 1.3
  ──────────────────────────────
  Section Heading
  That May Wrap            ← un poco más de aire

  Body text:              1.4 – 1.6 (ideal: 1.5)
  ──────────────────────────────
  This is a paragraph of body text that
  needs comfortable reading. The spacing

  between lines should feel natural and     ← espacio cómodo
  allow the eye to track easily to the
  next line without losing its place.

  Small text / captions:  1.4 – 1.5
  ──────────────────────────────
  Caption text or metadata        ← proporcional al tamaño
```

**Regla clave:** Texto más pequeño necesita proporcionalmente más line-height. Texto más grande necesita menos.

```css
h1 { font-size: 40px; line-height: 1.2; }   /* 48px → 40×1.2 */
h2 { font-size: 32px; line-height: 1.25; }  /* 40px → 32×1.25 */
h3 { font-size: 24px; line-height: 1.3; }   /* ~31px */
p  { font-size: 16px; line-height: 1.5; }   /* 24px → 16×1.5 */
```

### 2.4 Espaciado entre Letras (letter-spacing / tracking)

- **Intuición:** El tracking ajusta el "aire" entre todas las letras de un texto. Headings grandes suelen compactarse un poco (tracking negativo). Text uppercase se abre (tracking positivo).

```
Letter-spacing por contexto:

  TEXTO EN UPPERCASE (tracking positivo obligatorio):
  ❌ LABEL        → apretado, difícil de leer
  ✅ L A B E L   → tracking positivo, legible

  Headings grandes (tracking ligeramente negativo):
  ❌ W e l c o m e    → se siente desconectado
  ✅ Welcome           → tracking -0.02em, compacto y cohesivo

  Body text (tracking normal / cero):
  → No tocar el tracking del body text. Las fuentes están
    diseñadas para leer bien a 16px con tracking default.
```

```css
.uppercase-label { letter-spacing: 0.05em; }    /* uppercase → abrir */
.heading-large   { letter-spacing: -0.02em; }   /* display → compactar */
.body-text       { letter-spacing: normal; }     /* body → no tocar */
```

### 2.5 Espaciado entre Palabras (word-spacing)

Rara vez se ajusta manualmente. Útil en casos muy específicos:

```css
/* Casi nunca necesitas esto. Default es suficiente. */
.wide-reading { word-spacing: 0.05em; }   /* ligeramente más abierto */
```

> En la práctica, si necesitas ajustar word-spacing, probablemente el problema está en la fuente o en el tracking, no en el word-spacing.

### 2.6 Longitud de Línea (Measure)

- **Intuición:** Una línea de texto demasiado larga y el ojo se pierde al volver al inicio. Demasiado corta y el ojo rebota constantemente. El sweet spot es 45-75 caracteres por línea.
- **Estructura formal:** La "measure" es el ancho de un bloque de texto, idealmente limitado a 45-75 caracteres (incluyendo espacios) para máxima legibilidad.

```
Longitudes de línea:

  ❌ Demasiado ancha (100+ caracteres):
  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ This is a paragraph of text that is way too wide. The reader's eye has to travel an extremely long │
  │ distance to get back to the beginning of the next line, causing fatigue and frequent line-skipping.│
  └─────────────────────────────────────────────────────────────────────────────────────────────────────┘

  ❌ Demasiado corta (< 30 caracteres):
  ┌──────────────────────────┐
  │ This is text that        │
  │ wraps constantly,        │
  │ making reading feel      │
  │ choppy and               │
  │ interrupted.             │
  └──────────────────────────┘

  ✅ Ideal (45-75 caracteres):
  ┌──────────────────────────────────────────────────────────────┐
  │ This is a paragraph of text with a comfortable line         │
  │ length. The eye can easily scan from the end of one         │
  │ line to the beginning of the next without strain.           │
  └──────────────────────────────────────────────────────────────┘
```

```css
/* Controlar measure con max-width */
.readable-text {
  max-width: 65ch;      /* ~65 caracteres — ideal */
}

/* Alternativa con px */
.readable-text {
  max-width: 680px;     /* ~65 chars a 16px con Inter */
}
```

### 2.7 Alineación

| Alineación | Cuándo usar | Cuándo NO usar |
|---|---|---|
| **Left** (default) | Body text, forms, listas, UI general | — |
| **Center** | Headings cortos, CTAs, hero sections, empty states | Párrafos largos (> 3 líneas), listas, forms |
| **Right** | Números en tablas, precios, datos alineados | Body text, labels |
| **Justify** | ⚠️ Casi nunca en UI digital | Siempre — crea "ríos" de espacio en textos cortos |

```
Alineación en contexto:

  ✅ Left-aligned body text:
  The quick brown fox jumps over
  the lazy dog. This paragraph is
  easy to read because each line
  starts in the same place.

  ❌ Center-aligned body text:
       The quick brown fox jumps over
         the lazy dog. This paragraph
       is hard to read because the eye
          can't predict where each
              line starts.

  ❌ Justified text en UI:
  The  quick  brown  fox  jumps  over
  the   lazy   dog.   Notice   the
  uneven   spacing   between  words
  creating  "rivers"  of  white.
```

> **Regla:** Left-align todo por defecto. Solo centra lo que tiene máximo 2-3 líneas y es visualmente destacado (títulos, CTAs). Nunca justifiques en interfaces digitales.

---

## 3. Tipos de Fuentes (Font Families)

### 3.1 Serif

- **Intuición:** Las serif son fuentes con "pies" — pequeños trazos decorativos al final de las letras. Evocan tradición, elegancia, autoridad y seriedad.

```
Serif — Anatomía:

  ┌──┐        ┌──┐
  │  │        │  │
  │  │        │  │
  │  │────────│  │
  │  │        │  │
  │  │        │  │
  ┴──┴        ┴──┴
  ↑               ↑
  serifs          serifs

  Ejemplos: Georgia, Merriweather, Lora, Playfair Display,
            Source Serif Pro, PT Serif, Noto Serif
```

| Aspecto | Detalle |
|---|---|
| **Personalidad** | Tradicional, elegante, autoritaria, confiable |
| **Legibilidad** | Excelente en body text largo (especialmente en print) |
| **Uso en UI** | Headings con personalidad, blogs, editorial, finanzas, legal |
| **Limitación** | Puede sentirse "old school" para productos tech modernos |
| **En digital** | Funciona mejor en tamaños medianos-grandes (16px+) |

### 3.2 Sans-Serif

- **Intuición:** Las sans-serif son fuentes "sin pies" — limpias, geométricas, modernas. Son el estándar de facto en interfaces digitales porque priorizan claridad sobre decoración.

```
Sans-Serif — Anatomía:

  │  │        │  │
  │  │        │  │
  │  │────────│  │
  │  │        │  │
  │  │        │  │
                        ← sin serifs

  Subcategorías:
  - Grotesque:   Helvetica, Arial (neutras, clásicas)
  - Neo-grotesque: Inter, Roboto (optimizadas para pantalla)
  - Geometric:   Futura, Poppins (basadas en formas geométricas)
  - Humanist:    Open Sans, Lato (trazos orgánicos, cálidas)

  Ejemplos top para UI:
  Inter, SF Pro (Apple), Roboto (Google), Segoe UI (Microsoft),
  Open Sans, Lato, Nunito, DM Sans, Plus Jakarta Sans
```

| Aspecto | Detalle |
|---|---|
| **Personalidad** | Moderna, limpia, neutral, accesible |
| **Legibilidad** | Excelente en pantalla a cualquier tamaño |
| **Uso en UI** | Todo: body, headings, labels, buttons, nav — el estándar |
| **Limitación** | Puede ser genérica si no se elige con intención |
| **En digital** | Funciona en todos los tamaños, incluso 12px |

### 3.3 Monospace

- **Intuición:** En monospace, cada carácter ocupa exactamente el mismo ancho — como una máquina de escribir. Ideal para código, datos tabulares y cualquier contexto donde la alineación vertical por carácter importa.

```
Monospace vs Proporcional:

  Proporcional (Inter):
  illimitable    ← 'i' y 'l' son estrechas, 'm' es ancha
  MWMWMWMW      ← cada letra tiene su propio ancho

  Monospace (JetBrains Mono):
  i l l i m i t a b l e    ← cada carácter = mismo ancho
  M W M W M W M W          ← alineación vertical perfecta

  Uso en código:
  const name  = "John";     ← se alinea verticalmente
  const email = "j@a.com";  ← fácil de escanear columnas

  Ejemplos: JetBrains Mono, Fira Code, SF Mono, Source Code Pro,
            IBM Plex Mono, Roboto Mono
```

| Aspecto | Detalle |
|---|---|
| **Personalidad** | Técnica, precisa, de confianza |
| **Legibilidad** | Excelente para código; mala para prosa larga |
| **Uso en UI** | Code blocks, datos técnicos, tablas numéricas, terminales |
| **Limitación** | No usar para body text o headings generales |
| **En digital** | Tamaños de 13-16px para código |

### 3.4 Display

- **Intuición:** Las display son fuentes diseñadas para ser grandes y llamativas — como un cartel. Tienen personalidad fuerte pero sacrifican legibilidad en tamaños pequeños.

```
Display — Uso correcto:

  ✅ Como heading grande (32px+):
  ╔══════════════════════════════════════╗
  ║                                      ║
  ║   𝔹𝕠𝕝𝕕 𝔻𝕚𝕤𝕡𝕝𝕒𝕪 𝕋𝕚𝕥𝕝𝕖             ║  ← impactante, memorable
  ║                                      ║
  ║   Regular body text underneath       ║  ← sans-serif legible
  ║   in a clean, readable font.         ║
  ║                                      ║
  ╚══════════════════════════════════════╝

  ❌ Como body text (16px):
  ╔══════════════════════════════════════╗
  ║   𝔹𝕠𝕝𝕕 display font used for        ║
  ║   entire paragraphs becomes          ║  ← ilegible, fatiga visual
  ║   exhausting to read very quickly    ║
  ╚══════════════════════════════════════╝

  Ejemplos: Playfair Display, Abril Fatface, Bebas Neue,
            Space Grotesk (border display/sans), Sora
```

### 3.5 Legibilidad vs Personalidad Visual

```
Espectro de decisión:

  LEGIBILIDAD ◄──────────────────────────► PERSONALIDAD

  Inter         Open Sans       Playfair     Lobster
  Roboto        Lora            Display      Pacifico
  SF Pro        Merriweather    Bebas Neue   Comfortaa

  ← Máxima claridad                Máximo carácter →
  ← UI segura                      Branding fuerte →
  ← Texto largo                    Solo headings →

  Regla: Body text → priorizar legibilidad (izquierda)
         Headings  → puedes añadir personalidad (centro-derecha)
         Nunca usar extrema derecha para UI text
```

> **Error común:** Elegir una fuente porque "se ve cool" sin probarla en contexto real — texto pequeño, párrafos largos, mobile. La fuente más bonita en Dribbble puede ser ilegible en producción a 14px en un iPhone.

---

## 4. Typeface vs Font

### 4.1 Definición de Typeface

- **Intuición:** Un typeface es la **familia** — como "Inter" o "Roboto". Un font es una **variante específica** dentro de esa familia — como "Inter Bold 16px" o "Roboto Regular Italic".
- **Estructura formal:** Typeface = diseño tipográfico completo (todas las variantes). Font = instancia específica (peso + estilo + tamaño).

```
Typeface vs Font:

  TYPEFACE: Inter (la familia completa)
  │
  ├── FONT: Inter Thin (100)
  ├── FONT: Inter Extra Light (200)
  ├── FONT: Inter Light (300)
  ├── FONT: Inter Regular (400)          ← body text
  ├── FONT: Inter Regular Italic (400i)
  ├── FONT: Inter Medium (500)           ← labels, UI
  ├── FONT: Inter Medium Italic (500i)
  ├── FONT: Inter Semibold (600)         ← headings
  ├── FONT: Inter Bold (700)             ← CTAs, emphasis
  └── FONT: Inter Extra Bold (800)

  Analogía: "Inter" es como "Beatles" (la banda),
  "Inter Bold" es como "Let It Be" (una canción específica).
```

### 4.2 Variantes dentro de una Familia

| Variante | Descripción | Uso |
|---|---|---|
| **Weight** | Thin → Black (100-900) | Jerarquía: lighter = menos importante |
| **Style** | Normal / Italic | Énfasis, citas, metadata |
| **Width** | Condensed / Normal / Extended | Condensed para espacios reducidos |
| **Optical Size** | Display / Text / Small | Optimizado para el tamaño de uso |

### 4.3 Cómo Elegir una Familia Tipográfica Completa

**Checklist de selección:**

```
  ☐ Tiene al menos 4 pesos (Regular, Medium, Semibold, Bold)
  ☐ Tiene estilo Italic (para énfasis)
  ☐ Legible a 14px en pantalla (probar en mobile)
  ☐ Buena cobertura de caracteres (acentos, ñ, ü, etc.)
  ☐ Disponible como web font (Google Fonts, CDN, self-hosted)
  ☐ Licencia compatible (SIL Open Font License para gratuitas)
  ☐ Rendimiento aceptable (file size por peso)
  ☐ Se alinea con la personalidad de la marca
  ☐ Buena hinting (se ve nítida en pantallas de baja res)
  ☐ Variable font disponible (ideal para rendimiento)
```

> **Consejo:** Elige fuentes con **variable font** disponible. Un solo archivo `.woff2` reemplaza múltiples archivos de pesos, mejorando rendimiento y flexibilidad.

### 4.4 Consistencia dentro del Sistema

```
❌ Inconsistencia típica:

  Pantalla Login:     Roboto Regular 16px / line-height 24px
  Pantalla Dashboard: Inter Regular 15px / line-height 22px
  Pantalla Settings:  Roboto Regular 14px / line-height 20px
  → 3 pantallas, 2 fuentes, 3 tamaños, 3 line-heights diferentes para body text.

✅ Consistencia:

  TODA la app:        Inter Regular 16px / line-height 24px = "Body/Default"
  → Un text style, usado en todas las pantallas.
  → Cambiar la fuente = cambiar UN token, se actualiza todo.
```

---

## 5. Typeface Scenarios / Exploración

### 5.1 Selección según Contexto

**Producto SaaS (dashboard, data-heavy):**

```
Prioridad: Legibilidad máxima + densidad + números claros

  Recomendadas:
  - Inter           → la más popular para SaaS, excelente a todos los tamaños
  - SF Pro          → ecosistema Apple
  - IBM Plex Sans   → profesional, buena para datos
  - DM Sans         → limpia, geométrica

  Configuración típica:
  - Body: Inter Regular 14px (dense) o 16px (default)
  - Headings: Inter Semibold 20-32px
  - Data/Numbers: Inter Tabular (monospaced figures)
  - Code: JetBrains Mono 13px

  ┌──────────────────────────────────────────────────┐
  │  Dashboard        [Search]          [Profile]    │
  │──────────────────────────────────────────────────│
  │  Revenue          Users            Churn         │
  │  $45,230          12,847           2.3%          │  ← tabular figures
  │  +12% ↑           -3% ↓            -0.5% ↑      │
  │──────────────────────────────────────────────────│
  │  Inter 14px everywhere, Semibold para KPIs       │
  └──────────────────────────────────────────────────┘
```

**E-commerce:**

```
Prioridad: Confianza + precios claros + CTAs fuertes

  Recomendadas:
  - Primary: Plus Jakarta Sans / DM Sans (moderno, amigable)
  - Alternativa: Nunito (redondeada, approachable)
  - Precios: Tabular figures (números de mismo ancho)

  ┌──────────────────────────────────────────┐
  │  [Product Image]                         │
  │                                          │
  │  Plus Jakarta Sans Semibold 20px         │
  │  Product Name Here                       │
  │                                          │
  │  Plus Jakarta Sans Regular 14px          │
  │  Brief product description text.         │
  │                                          │
  │  Plus Jakarta Sans Bold 24px             │
  │  $1,299.00                               │
  │                                          │
  │  [ Add to Cart ]  Semibold 16px          │
  └──────────────────────────────────────────┘
```

**Blog / Contenido editorial:**

```
Prioridad: Lectura prolongada cómoda + personalidad editorial

  Recomendadas:
  - Body: Merriweather / Lora / Source Serif Pro (serif para lectura)
  - Headings: Playfair Display / Fraunces (serif display)
  - UI/Nav: Inter / Open Sans (sans-serif para UI)

  ┌──────────────────────────────────────────────────┐
  │  Nav (Inter 14px Medium)                         │
  │  Blog   Categories   About                       │
  │──────────────────────────────────────────────────│
  │                                                  │
  │  Playfair Display Bold 40px                      │
  │  The Art of Thoughtful Design                    │
  │                                                  │
  │  Inter Regular 14px (metadata)                   │
  │  April 15, 2026 · 8 min read                     │
  │                                                  │
  │  Merriweather Regular 18px / line-height 1.7     │
  │  Lorem ipsum dolor sit amet, consectetur         │
  │  adipiscing elit. Sed do eiusmod tempor          │
  │  incididunt ut labore et dolore magna aliqua.    │  ← serif body
  │  Ut enim ad minim veniam, quis nostrud.          │     máx 70ch
  │                                                  │
  └──────────────────────────────────────────────────┘
```

**Branding fuerte (startup, producto diferenciador):**

```
Prioridad: Personalidad memorable + legibilidad mínima aceptable

  Recomendadas:
  - Display: Space Grotesk / Sora / Cabinet Grotesk (personalidad)
  - Body: Inter / DM Sans (legibilidad)

  La fuente de personalidad SOLO para headings y hero.
  El body text siempre en una fuente legible.
```

### 5.2 Exploración Tipográfica

**Proceso de selección:**

```
1. Definir criterios → ¿Qué personalidad necesito? ¿Qué contexto?
2. Shortlist (3-5) → Buscar en Google Fonts, Fontshare, fonts.adobe.com
3. Test en contexto → Probar con contenido REAL, no "Lorem ipsum"
4. Test en tamaños → ¿Funciona a 14px? ¿A 40px? ¿En bold y regular?
5. Test en devices → ¿Se ve bien en mobile? ¿En low-DPI?
6. Comparar side-by-side → Poner las finalistas juntas
7. Decidir → Elegir basándose en legibilidad + personalidad + rendimiento
```

### 5.3 Testing Visual y Validación

**Qué testear:**

```
Checklist de validación tipográfica:

  ☐ Legibilidad a 14px en pantalla
  ☐ Legibilidad a 12px (worst case)
  ☐ Distinción de caracteres: Il1 0Oo (I-ele, l-ele, 1-uno, 0-cero, O-o)
  ☐ Acentos y caracteres especiales: á é í ó ú ñ ü ¿ ¡
  ☐ Números tabulares (para tablas y precios): 1234567890
  ☐ Texto largo (¿es cómodo leer 500+ palabras?)
  ☐ Headings (¿se ve bien grande y en bold?)
  ☐ Mobile rendering (probar en dispositivo real)
  ☐ Performance (file size de los pesos que necesitas)
  ☐ Combinación con segunda fuente (si aplica)
```

---

## 6. Pairing de Fuentes

### 6.1 Qué es Font Pairing

- **Intuición:** Font pairing es combinar dos (máximo tres) fuentes que se complementen — como un dueto musical donde una lleva la melodía (headings) y otra el ritmo (body). Deben ser diferentes pero armónicas.
- **Estructura formal:** Font pairing es la selección estratégica de dos o más familias tipográficas que crean contraste funcional (para jerarquía) sin generar conflicto visual.

### 6.2 Reglas Fundamentales

```
Regla 1: CONTRASTE, no conflicto

  ✅ Contraste claro (funciona):
  Playfair Display (serif, elegante) + Inter (sans, neutral)
  → Cada fuente tiene un rol claro y distinto.

  ❌ Conflicto (no funciona):
  Georgia (serif) + Merriweather (serif)
  → Demasiado similares, no hay contraste funcional.

  ❌ Otro conflicto:
  Futura (geometric sans) + Poppins (geometric sans)
  → Misma categoría, diferencia sutil → confusión.

Regla 2: Una fuente DOMINANTE, una de SOPORTE

  Heading: Fuente con personalidad (display o serif)
  Body:    Fuente neutral y legible (sans-serif)

  No compiten. Cada una tiene su territorio.

Regla 3: Máximo 2 fuentes (excepcionalmente 3)

  ❌ 4+ fuentes:
  Heading: Playfair Display
  Body: Open Sans
  Nav: Roboto
  Caption: Lato
  Code: Fira Code
  → Carnaval visual, sin identidad.

  ✅ 2 fuentes (+ monospace para código si aplica):
  Heading + Body: Playfair Display + Inter
  Código (si necesario): JetBrains Mono
  → Sistema claro y coherente.
```

### 6.3 Combinaciones Comunes

**Serif + Sans-serif (la más clásica):**

```
Combinación             Heading            Body              Vibe
──────────────────────────────────────────────────────────────────
Playfair + Inter       Playfair Display   Inter             Elegante + moderno
Lora + Roboto          Lora Bold          Roboto            Cálido + limpio
Merriweather + Sans    Merriweather       Source Sans Pro   Editorial + neutro
Fraunces + DM Sans     Fraunces           DM Sans           Distintivo + clean
```

**Sans-serif + Sans-serif (moderna, segura):**

```
Combinación             Heading            Body              Vibe
──────────────────────────────────────────────────────────────────
Space Grotesk + Inter  Space Grotesk      Inter             Tech + readable
Sora + DM Sans         Sora               DM Sans           Friendly + clean
Manrope + Inter        Manrope            Inter             Geométrico + neutro

⚠️ Para que funcione, las dos sans-serif deben tener
suficiente contraste visual (diferente geometría, x-height, o personalidad).
```

### 6.4 Ejemplos Correctos e Incorrectos

```
✅ CORRECTO: Playfair Display + Inter

  ┌──────────────────────────────────────────────┐
  │                                              │
  │  The Future of Digital Design                │  Playfair 36px
  │                                              │
  │  A comprehensive look at how design          │  Inter 16px
  │  systems are transforming the way we         │
  │  build digital products in 2026.             │
  │                                              │
  │  [ Read More ]                               │  Inter 14px Semibold
  │                                              │
  └──────────────────────────────────────────────┘
  → Contraste claro, cada fuente tiene su rol.

❌ INCORRECTO: Georgia + Times New Roman

  ┌──────────────────────────────────────────────┐
  │                                              │
  │  The Future of Digital Design                │  Georgia 36px
  │                                              │
  │  A comprehensive look at how design          │  Times 16px
  │  systems are transforming the way we         │
  │  build digital products in 2026.             │
  │                                              │
  └──────────────────────────────────────────────┘
  → Ambas serif, demasiado similares, sin contraste funcional.
  → El usuario no percibe jerarquía por fuente.

❌ INCORRECTO: Lobster + Comic Sans

  ┌──────────────────────────────────────────────┐
  │  𝓣𝓱𝓮 𝓕𝓾𝓽𝓾𝓻𝓮 𝓸𝓯 𝓓𝓮𝓼𝓲𝓰𝓷                     │  Lobster 36px
  │                                              │
  │  A comprehensive look at how...              │  Comic Sans 16px
  │                                              │
  └──────────────────────────────────────────────┘
  → Dos fuentes con personalidad extrema compiten entre sí.
  → Ninguna es legible ni profesional.
```

> **Regla de oro:** Si dudas, usa **una sola fuente** (ej: Inter) y crea jerarquía con tamaño y peso. Una fuente bien usada es mejor que dos fuentes mal combinadas.

---

## 7. Jerarquía Tipográfica

### 7.1 Niveles de Jerarquía

- **Intuición:** La jerarquía tipográfica es el "mapa visual" que le dice al usuario qué leer primero, segundo y tercero — sin que nadie se lo explique. Se logra con diferencias de tamaño, peso y color.

```
Niveles de jerarquía:

  NIVEL 1 — Display / H1            40-48px  Bold/Semibold
  El título más importante de la página.
  Solo uno por pantalla.

  NIVEL 2 — H2                      28-32px  Semibold
  Secciones principales dentro de la página.

  NIVEL 3 — H3                      22-24px  Semibold
  Subsecciones dentro de una sección H2.

  NIVEL 4 — H4                      18-20px  Medium/Semibold
  Bloques o grupos dentro de subsecciones.

  NIVEL 5 — Body Large              18px     Regular
  Texto introductorio, lead paragraphs.

  NIVEL 6 — Body Default            16px     Regular
  Texto principal de lectura. El más usado.

  NIVEL 7 — Body Small / UI text    14px     Regular/Medium
  Labels, nav items, metadata inline.

  NIVEL 8 — Caption                 12px     Regular
  Timestamps, pie de imagen, ayuda contextual.

  NIVEL 9 — Overline                11-12px  Medium, UPPERCASE
  Categorías, labels sobre headings, badges.
```

### 7.2 Headings (H1–H6)

```
Jerarquía de headings en contexto:

  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  H1: Page Title (40px Bold)                          │
  │  Solo uno por página. Define el contenido principal. │
  │                                                      │
  │  ─────────────────────────────────────────────       │
  │                                                      │
  │  H2: Section Title (32px Semibold)                   │
  │                                                      │
  │  H3: Subsection (24px Semibold)                      │
  │                                                      │
  │  Body text paragraph here explaining the concept     │
  │  in regular 16px weight 400 with 1.5 line height.   │
  │                                                      │
  │  H3: Another Subsection (24px Semibold)              │
  │                                                      │
  │  More body text here continuing the narrative.       │
  │                                                      │
  │  ─────────────────────────────────────────────       │
  │                                                      │
  │  H2: Next Section (32px Semibold)                    │
  │                                                      │
  └──────────────────────────────────────────────────────┘

  Regla: No saltar niveles. H1 → H2 → H3, no H1 → H3.
  (Accesibilidad + lógica semántica)
```

### 7.3 Body Text

```
Body text configurations:

  Body Large (18px / line-height 28px)
  ─────────────────────────────────────
  Usado para lead paragraphs, introducciones, texto
  que necesita más destaque que el body normal.

  Body Default (16px / line-height 24px)
  ─────────────────────────────────────
  El texto estándar de la interfaz. Párrafos, descripciones,
  contenido principal. El 80% del texto de tu app.

  Body Small (14px / line-height 20px)
  ─────────────────────────────────────
  Labels, nav items, metadata, texto secundario.
  UI-dense, dashboards, tablas.
```

### 7.4 Labels, Captions y Overlines

```
UI Text:

  Label:     "Email address"         14px Medium
             (identifica un campo)

  Caption:   "Updated 2 hours ago"   12px Regular, color secundario
             (información contextual)

  Overline:  "FEATURED ARTICLE"      11px Medium, UPPERCASE, tracking +0.05em
             (categoría sobre un heading)

  Helper:    "Must be 8+ characters" 12px Regular, color terciario
             (ayuda bajo un input)

  Ejemplo en contexto:
  ┌─────────────────────────────────────┐
  │  OVERLINE CATEGORY                  │  11px Medium UPPERCASE
  │  Main Heading Title                 │  32px Semibold
  │  Supporting body text description   │  16px Regular
  │  that provides more context.        │
  │                                     │
  │  Caption · April 15, 2026           │  12px Regular, gray
  └─────────────────────────────────────┘
```

### 7.5 Escalas Tipográficas (Modular Scale)

- **Intuición:** Una escala tipográfica es una progresión matemática de tamaños — cada paso sube por un ratio consistente, creando armonía entre todos los niveles.
- **Estructura formal:** Una modular scale multiplica un tamaño base por un ratio constante para generar una serie de tamaños relacionados proporcionalmente.

```
Escalas comunes:

  Ratio 1.250 (Major Third) — Sutil, para UI dense:
  Base: 16px
  16 × 1.250 = 20px
  20 × 1.250 = 25px
  25 × 1.250 = 31px
  31 × 1.250 = 39px
  → Escala: 12, 14, 16, 20, 25, 31, 39

  Ratio 1.333 (Perfect Fourth) — Balance ideal:
  Base: 16px
  16 × 1.333 = 21px
  21 × 1.333 = 28px
  28 × 1.333 = 38px
  38 × 1.333 = 50px
  → Escala: 12, 14, 16, 21, 28, 38, 50

  Ratio 1.5 (Perfect Fifth) — Dramático, para editorial:
  Base: 16px
  16 × 1.5 = 24px
  24 × 1.5 = 36px
  36 × 1.5 = 54px
  → Escala: 11, 14, 16, 24, 36, 54

  Para la mayoría de interfaces, 1.250 – 1.333 es ideal.
```

**Escala práctica (la más usada en la industria):**

```
Escala pragmática (no puramente matemática, pero funcional):

  Nombre          Size     Weight      Line-height    Uso
  ──────────────────────────────────────────────────────────
  Display         48px     Bold        1.1            Hero titles
  H1              40px     Bold        1.2            Page titles
  H2              32px     Semibold    1.25           Sections
  H3              24px     Semibold    1.3            Subsections
  H4              20px     Semibold    1.35           Blocks
  Body Large      18px     Regular     1.5            Lead text
  Body            16px     Regular     1.5            Main text
  Body Small      14px     Regular     1.43           UI text
  Caption         12px     Regular     1.33           Metadata
  Overline        11px     Medium      1.45           UPPERCASE labels

  Esta escala NO es puramente modular, pero es:
  ✓ Predecible (pasos claros entre niveles)
  ✓ Funcional (cada tamaño tiene un rol)
  ✓ Compatible con grid de 4px (sizes y line-heights)
```

---

## 8. Text Styles y Design Systems

### 8.1 Definición de Text Styles

- **Intuición:** Un text style es una "receta" guardada que combina fuente + tamaño + peso + line-height + color en un paquete reutilizable con nombre. Así como un chef tiene recetas estándar, un design system tiene text styles estándar.
- **Estructura formal:** Un text style es un token compuesto que define todas las propiedades tipográficas de un elemento, nombrado semánticamente para su reutilización consistente en el sistema de diseño.

### 8.2 Definición Completa de Text Styles

```
Text Styles del sistema:

  ┌──────────────────────────────────────────────────────────────────────┐
  │  Name              │ Family │ Size │ Weight   │ LH   │ LS      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  Display/Large     │ Inter  │ 48px │ Bold     │ 56px │ -0.02em │
  │  Display/Medium    │ Inter  │ 40px │ Bold     │ 48px │ -0.02em │
  │  Heading/H1        │ Inter  │ 36px │ Semibold │ 44px │ -0.02em │
  │  Heading/H2        │ Inter  │ 28px │ Semibold │ 36px │ -0.01em │
  │  Heading/H3        │ Inter  │ 24px │ Semibold │ 32px │ -0.01em │
  │  Heading/H4        │ Inter  │ 20px │ Semibold │ 28px │ 0       │
  │  Body/Large        │ Inter  │ 18px │ Regular  │ 28px │ 0       │
  │  Body/Default      │ Inter  │ 16px │ Regular  │ 24px │ 0       │
  │  Body/Small        │ Inter  │ 14px │ Regular  │ 20px │ 0       │
  │  Label/Large       │ Inter  │ 16px │ Medium   │ 24px │ 0       │
  │  Label/Default     │ Inter  │ 14px │ Medium   │ 20px │ 0       │
  │  Label/Small       │ Inter  │ 12px │ Medium   │ 16px │ 0       │
  │  Caption           │ Inter  │ 12px │ Regular  │ 16px │ 0       │
  │  Overline          │ Inter  │ 11px │ Medium   │ 16px │ +0.05em │
  │  Code/Default      │ Mono   │ 14px │ Regular  │ 20px │ 0       │
  │  Code/Small        │ Mono   │ 12px │ Regular  │ 16px │ 0       │
  └──────────────────────────────────────────────────────────────────────┘

  LH = Line Height     LS = Letter Spacing
```

### 8.3 Tokens Tipográficos

```
Estructura de tokens (3 capas):

  Capa 1: Primitivos (valores raw)
  ────────────────────────────────
  --font-family-sans: 'Inter', sans-serif;
  --font-family-mono: 'JetBrains Mono', monospace;
  --font-size-xs:     11px;
  --font-size-sm:     12px;
  --font-size-base:   14px;
  --font-size-md:     16px;
  --font-size-lg:     18px;
  --font-size-xl:     20px;
  --font-size-2xl:    24px;
  --font-size-3xl:    28px;
  --font-size-4xl:    36px;
  --font-size-5xl:    40px;
  --font-size-6xl:    48px;
  --font-weight-regular:  400;
  --font-weight-medium:   500;
  --font-weight-semibold: 600;
  --font-weight-bold:     700;
  --line-height-tight:    1.2;
  --line-height-snug:     1.3;
  --line-height-normal:   1.5;
  --line-height-relaxed:  1.6;

  Capa 2: Semánticos (intención)
  ────────────────────────────────
  --text-heading-font:    var(--font-family-sans);
  --text-heading-weight:  var(--font-weight-semibold);
  --text-body-font:       var(--font-family-sans);
  --text-body-weight:     var(--font-weight-regular);
  --text-code-font:       var(--font-family-mono);

  Capa 3: Compuestos (text styles)
  ────────────────────────────────
  → Se construyen combinando los anteriores (ver CSS abajo)
```

### 8.4 Naming Conventions

```
Estructura recomendada: [Categoría]/[Tamaño]

  Heading/H1
  Heading/H2
  Heading/H3
  Heading/H4
  Body/Large
  Body/Default
  Body/Small
  Label/Large
  Label/Default
  Label/Small
  Caption
  Overline
  Code/Default
  Code/Small

  ❌ Nombres malos:
  "Title 1", "big text", "paragraph", "small gray text"
  → No escalables, ambiguos, inconsistentes.

  ✅ Nombres buenos:
  "Heading/H2", "Body/Default", "Label/Small"
  → Claros, jerárquicos, predecibles.
```

### 8.5 Consistencia entre Pantallas

```
Test de consistencia:

  ¿El título de sección en la pantalla de Settings
  usa el mismo text style que el título de sección
  en la pantalla de Dashboard?

  Si la respuesta es NO → hay un problema de sistema.

  Solución:
  1. Definir text styles una vez
  2. En Figma: usar text styles compartidos
  3. En código: usar clases/tokens reutilizables
  4. NUNCA escribir font-size/weight inline sin referir al sistema
```

---

## 9. Legibilidad y Accesibilidad

### 9.1 Contraste de Color

- **Intuición:** Si el texto se confunde con el fondo, no importa cuán buena sea la fuente — nadie puede leerlo.
- **Estructura formal:** WCAG define ratios mínimos de contraste entre texto y fondo:

| Nivel | Texto normal (< 18px) | Texto grande (≥ 18px bold / 24px) |
|---|---|---|
| **AA** (mínimo) | 4.5:1 | 3:1 |
| **AAA** (recomendado) | 7:1 | 4.5:1 |

```
Ejemplos de contraste:

  ✅ Negro sobre blanco:  #000 / #FFF  → 21:1 (perfecto)
  ✅ Gris oscuro / blanco: #333 / #FFF → 12.6:1 (excelente)
  ✅ Texto / fondo suave:  #374151 / #FFFFFF → 10.3:1 (muy bueno)

  ⚠️ Gris medio / blanco: #6B7280 / #FFFFFF → 4.6:1 (apenas AA)
  ❌ Gris claro / blanco:  #9CA3AF / #FFFFFF → 2.9:1 (FALLA AA)
  ❌ Amarillo / blanco:    #FCD34D / #FFFFFF → 1.6:1 (ilegible)
```

```
Colores de texto recomendados (sobre fondo blanco #FFF):

  Texto primario:     #111827  (gray-900)  → 18.4:1 ✓
  Texto secundario:   #374151  (gray-700)  → 10.3:1 ✓
  Texto terciario:    #6B7280  (gray-500)  →  4.6:1 ✓ (AA large only)
  Texto disabled:     #9CA3AF  (gray-400)  →  2.9:1 ✗ (falla AA)
  Texto placeholder:  #9CA3AF  (gray-400)  →  2.9:1 ⚠️ (WCAG exempt)

  Regla: Texto que debe LEERSE → mínimo 4.5:1.
  Texto decorativo o placeholder → puede ser menor.
```

### 9.2 Tamaños Mínimos Recomendados

| Contexto | Tamaño mínimo | Recomendado |
|---|---|---|
| Body text (desktop) | 14px | 16px |
| Body text (mobile) | **16px** (previene auto-zoom en iOS) | 16-18px |
| Labels / UI text | 12px | 14px |
| Captions | 11px | 12px |
| Botones | 14px | 16px |
| Navegación | 14px | 14-16px |
| Inputs (mobile) | **16px** (obligatorio para evitar zoom) | 16px |

> **Error crítico en mobile:** Usar `font-size: 14px` en inputs de formulario en iOS causa zoom automático al hacer focus. Siempre usar **16px mínimo** en inputs mobile.

### 9.3 Line-Height Adecuado

```
Line-height por tamaño:

  Texto                Size    Line-height   Resultado
  ───────────────────────────────────────────────────────
  Display headings     40px+   1.1 – 1.2     48px (compacto)
  Section headings     24-32px 1.2 – 1.3     ~32-40px
  Body text            16px    1.5           24px (cómodo)
  Small text           14px    1.43          20px
  Caption              12px    1.33          16px

  ❌ Line-height demasiado apretado (body a 1.0):
  This text is crammed together and
  the lines overlap making it very
  hard to read and causing strain.

  ❌ Line-height demasiado abierto (body a 2.0):
  This text has so much space

  between each line that it

  feels disconnected and slow.

  ✅ Line-height correcto (body a 1.5):
  This text has comfortable spacing
  between lines, making it easy to
  read for extended periods without
  fatigue or losing your place.
```

### 9.4 Accesibilidad (WCAG)

**Checklist de accesibilidad tipográfica:**

```
  ☐ Contraste: Todo texto legible cumple AA (4.5:1)
  ☐ Tamaño base: ≥ 16px para body text
  ☐ Escalabilidad: La interfaz funciona a 200% zoom
  ☐ No depender SOLO de color para comunicar (usar peso/tamaño también)
  ☐ Line-height: ≥ 1.5 para body text
  ☐ Paragraph spacing: ≥ 2× el espacio entre líneas
  ☐ Letter-spacing: No menor a -0.05em
  ☐ Fuente legible: Evitar fuentes decorativas para contenido funcional
  ☐ Responsive: Texto legible en todos los viewports
  ☐ Headings semánticos: H1 → H2 → H3 (sin saltar niveles)
  ☐ Focus visible: Elementos de texto interactivos con focus ring
  ☐ lang attribute: <html lang="es"> para lectores de pantalla
```

### 9.5 Evitar Fatiga Visual

| Factor | Causa fatiga | Previene fatiga |
|---|---|---|
| **Línea** | > 80 caracteres | 45-75 caracteres (`max-width: 65ch`) |
| **Contraste** | Extremo (#000 sobre #FFF puro) | Suavizado (#111827 sobre #FAFAFA) |
| **Peso** | Todo en bold | Bold solo para headings, regular para body |
| **Densidad** | Todo apretado | Ritmo vertical con spacing generoso |
| **Color** | Texto con color saturado | Texto en grises neutros, color solo para accent |
| **Alineación** | Centrado en párrafos largos | Left-align para contenido extenso |
| **Variación** | 5+ tamaños en la misma pantalla | Sistema con niveles claros |

> **Dato:** Usar `#111827` en lugar de `#000000` puro sobre fondo `#FFFFFF` reduce la fatiga visual perceptiblemente, manteniendo contraste excelente (18.4:1 vs 21:1).

---

## 10. Mobile vs Desktop Typography

### 10.1 Ajustes de Tamaño

```
Escala responsive de tipografía:

  Text Style        Desktop    Tablet     Mobile
  ──────────────────────────────────────────────────
  Display           48px       40px       32px
  H1                40px       36px       28px
  H2                32px       28px       24px
  H3                24px       22px       20px
  H4                20px       20px       18px
  Body Large        18px       18px       18px
  Body Default      16px       16px       16px   ← no reduce
  Body Small        14px       14px       14px   ← no reduce
  Caption           12px       12px       12px   ← no reduce
  Overline          11px       11px       11px   ← no reduce

  Regla: Headings se reducen en mobile.
         Body text y UI text NO se reducen (legibilidad).
```

```css
/* Tipografía responsive */
h1 {
  font-size: 1.75rem;     /* 28px mobile */
  line-height: 1.2;
}

@media (min-width: 768px) {
  h1 {
    font-size: 2.25rem;   /* 36px tablet */
  }
}

@media (min-width: 1024px) {
  h1 {
    font-size: 2.5rem;    /* 40px desktop */
  }
}

/* Body: siempre 16px */
body {
  font-size: 1rem;       /* 16px en todos los viewports */
  line-height: 1.5;
}
```

**Alternativa moderna — Fluid Typography:**

```css
/* Fluid type: escala suavemente entre viewport sizes */
h1 {
  font-size: clamp(1.75rem, 1.2rem + 2vw, 2.5rem);
  /* min: 28px → max: 40px → escala fluidamente */
}

h2 {
  font-size: clamp(1.5rem, 1rem + 1.5vw, 2rem);
  /* min: 24px → max: 32px */
}

/* Body NUNCA usa clamp — siempre fijo a 16px */
body {
  font-size: 1rem;
}
```

### 10.2 Longitud de Línea

```
Measure responsive:

  Desktop (1280px viewport):
  ┌──────────────────────────────────────────────────────────────┐
  │        ┌─────────────────────────────────────┐              │
  │        │  max-width: 65ch (~680px)           │              │
  │        │  El texto NO se estira a todo       │  ← centrado │
  │        │  el ancho de la pantalla.           │              │
  │        └─────────────────────────────────────┘              │
  └──────────────────────────────────────────────────────────────┘

  Mobile (375px viewport):
  ┌───────────────────────────────┐
  │ 16px │ Text naturally fits  │ 16px │
  │      │ the width with      │      │   ← no necesita max-width
  │      │ margins providing   │      │      los margins controlan
  │      │ comfortable measure │      │
  └───────────────────────────────┘

  En mobile, los márgenes laterales (16px cada lado) naturalmente
  limitan la measure a ~45-55 caracteres. Perfecto.
```

### 10.3 Jerarquía Adaptativa

```
Desktop: Jerarquía con espacio horizontal
┌────────────────────────────────────────────────────┐
│  H1: Dashboard Overview        [ Export ] [ + New ]│
│  H2: Revenue Metrics                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │  $45.2k  │ │  1,234   │ │  2.3%    │          │
│  │  Revenue  │ │  Users   │ │  Churn   │          │
│  └──────────┘ └──────────┘ └──────────┘          │
└────────────────────────────────────────────────────┘

Mobile: Jerarquía puramente vertical
┌──────────────────────┐
│  Dashboard Overview   │  H1 (28px, no 40px)
│                       │
│  [ Export ] [ + New ] │  Actions debajo del título
│                       │
│  Revenue Metrics      │  H2
│  ┌──────────────────┐ │
│  │  $45.2k Revenue  │ │  KPIs apilados
│  └──────────────────┘ │
│  ┌──────────────────┐ │
│  │  1,234 Users     │ │
│  └──────────────────┘ │
└──────────────────────┘
```

### 10.4 Cambios en Spacing

```
Spacing tipográfico responsive:

  Propiedad           Desktop     Mobile
  ──────────────────────────────────────────
  H1 margin-bottom    24px        16px
  H2 margin-bottom    20px        16px
  H2 margin-top       48px        32px
  Body margin-bottom  16px        16px (mantener)
  Section padding     64px        40px
  Paragraph spacing   16px        16px (mantener)

  Regla: Reducir spacing de headings 25-35% en mobile.
  Body spacing se mantiene (no comprimir la lectura).
```

### 10.5 Prioridad de Contenido

| Contenido | Desktop | Mobile |
|---|---|---|
| Título largo | Completo en 1 línea | Puede hacer wrap (2-3 líneas) |
| Subtítulo | Visible | Puede reducirse o eliminarse |
| Metadata | Inline con título | Debajo del título |
| Body extendido | Completo | Igual o con "Read more" |
| Tabla de texto | Tabla completa | Card layout |
| Navigation labels | Todas visibles | Iconos + labels cortos o solo iconos |

---

## 11. Implementación Práctica

### 11.1 CSS Completo con Design Tokens

```css
/* ═══════════════════════════════════════════════════════
   TYPOGRAPHY SYSTEM — Design Tokens + Styles
   ═══════════════════════════════════════════════════════ */

/* ── Font Loading (Google Fonts) ── */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

/* Alternativa: Variable Font (mejor rendimiento) */
/* @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap'); */

/* ── Primitive Tokens ── */
:root {
  /* Families */
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont,
               'Segoe UI', Roboto, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', 'SF Mono',
               'Cascadia Code', monospace;

  /* Sizes */
  --text-xs:    0.6875rem;  /* 11px */
  --text-sm:    0.75rem;    /* 12px */
  --text-base:  0.875rem;   /* 14px */
  --text-md:    1rem;       /* 16px */
  --text-lg:    1.125rem;   /* 18px */
  --text-xl:    1.25rem;    /* 20px */
  --text-2xl:   1.5rem;     /* 24px */
  --text-3xl:   1.75rem;    /* 28px */
  --text-4xl:   2rem;       /* 32px */
  --text-5xl:   2.25rem;    /* 36px */
  --text-6xl:   2.5rem;     /* 40px */
  --text-7xl:   3rem;       /* 48px */

  /* Weights */
  --weight-regular:  400;
  --weight-medium:   500;
  --weight-semibold: 600;
  --weight-bold:     700;

  /* Line Heights */
  --leading-none:    1;
  --leading-tight:   1.15;
  --leading-snug:    1.25;
  --leading-normal:  1.375;
  --leading-relaxed: 1.5;
  --leading-loose:   1.625;

  /* Letter Spacing */
  --tracking-tighter: -0.02em;
  --tracking-tight:   -0.01em;
  --tracking-normal:   0;
  --tracking-wide:     0.025em;
  --tracking-wider:    0.05em;

  /* Text Colors */
  --color-text-primary:   #111827;  /* gray-900 */
  --color-text-secondary: #374151;  /* gray-700 */
  --color-text-tertiary:  #6B7280;  /* gray-500 */
  --color-text-disabled:  #9CA3AF;  /* gray-400 */
  --color-text-inverse:   #FFFFFF;
}

/* ── Base Reset ── */
html {
  font-size: 16px;             /* 1rem base */
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

body {
  font-family: var(--font-sans);
  font-size: var(--text-md);    /* 16px */
  font-weight: var(--weight-regular);
  line-height: var(--leading-relaxed);  /* 1.5 */
  color: var(--color-text-primary);
  letter-spacing: var(--tracking-normal);
}

/* ── Headings ── */
h1, h2, h3, h4, h5, h6 {
  font-family: var(--font-sans);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
}

h1 {
  font-size: var(--text-5xl);       /* 36px mobile → escala con media query */
  line-height: var(--leading-tight); /* 1.15 */
  letter-spacing: var(--tracking-tighter);
}

h2 {
  font-size: var(--text-3xl);       /* 28px */
  line-height: var(--leading-snug);  /* 1.25 */
  letter-spacing: var(--tracking-tight);
}

h3 {
  font-size: var(--text-2xl);       /* 24px */
  line-height: var(--leading-snug);  /* 1.25 */
  letter-spacing: var(--tracking-tight);
}

h4 {
  font-size: var(--text-xl);        /* 20px */
  line-height: var(--leading-normal); /* 1.375 */
  letter-spacing: var(--tracking-normal);
}

/* ── Responsive Headings ── */
@media (min-width: 768px) {
  h1 { font-size: var(--text-5xl); }  /* 36px */
  h2 { font-size: var(--text-4xl); }  /* 32px */
}

@media (min-width: 1024px) {
  h1 { font-size: var(--text-6xl); }  /* 40px */
  h2 { font-size: var(--text-4xl); }  /* 32px */
  h3 { font-size: var(--text-2xl); }  /* 24px */
}

/* ── Body Variants ── */
.text-body-lg {
  font-size: var(--text-lg);          /* 18px */
  line-height: var(--leading-relaxed); /* 1.5 */
}

.text-body {
  font-size: var(--text-md);          /* 16px */
  line-height: var(--leading-relaxed); /* 1.5 */
}

.text-body-sm {
  font-size: var(--text-base);        /* 14px */
  line-height: var(--leading-normal);  /* 1.375 */
}

/* ── UI Text ── */
.text-label-lg {
  font-size: var(--text-md);          /* 16px */
  font-weight: var(--weight-medium);
  line-height: var(--leading-relaxed);
}

.text-label {
  font-size: var(--text-base);        /* 14px */
  font-weight: var(--weight-medium);
  line-height: var(--leading-normal);
}

.text-label-sm {
  font-size: var(--text-sm);          /* 12px */
  font-weight: var(--weight-medium);
  line-height: var(--leading-normal);
}

.text-caption {
  font-size: var(--text-sm);          /* 12px */
  font-weight: var(--weight-regular);
  line-height: var(--leading-normal);
  color: var(--color-text-tertiary);
}

.text-overline {
  font-size: var(--text-xs);          /* 11px */
  font-weight: var(--weight-medium);
  line-height: var(--leading-normal);
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  color: var(--color-text-tertiary);
}

/* ── Code ── */
code, pre, .text-code {
  font-family: var(--font-mono);
  font-size: var(--text-base);        /* 14px */
  line-height: var(--leading-relaxed);
}

.text-code-sm {
  font-family: var(--font-mono);
  font-size: var(--text-sm);          /* 12px */
}

/* ── Measure (line length) ── */
.prose {
  max-width: 65ch;
}

.prose-narrow {
  max-width: 50ch;
}

.prose-wide {
  max-width: 80ch;
}

/* ── Text Colors ── */
.text-primary   { color: var(--color-text-primary); }
.text-secondary { color: var(--color-text-secondary); }
.text-tertiary  { color: var(--color-text-tertiary); }
.text-disabled  { color: var(--color-text-disabled); }
.text-inverse   { color: var(--color-text-inverse); }
```

### 11.2 Fluid Typography con clamp()

```css
/* ═══════════════════════════════════════════
   FLUID TYPOGRAPHY (sin breakpoints)
   ═══════════════════════════════════════════ */

/* Formula: clamp(min, preferred, max) */
/* preferred = viewportMin + (fontSize - min) × ((100vw - viewportMin) / (viewportMax - viewportMin)) */

h1 {
  /* 28px en 375px viewport → 40px en 1280px viewport */
  font-size: clamp(1.75rem, 1.25rem + 1.5vw, 2.5rem);
}

h2 {
  /* 24px → 32px */
  font-size: clamp(1.5rem, 1.15rem + 1.1vw, 2rem);
}

h3 {
  /* 20px → 24px */
  font-size: clamp(1.25rem, 1.1rem + 0.5vw, 1.5rem);
}

/* Body: FIJO. No usar clamp para body text. */
body {
  font-size: 1rem;  /* siempre 16px */
}
```

### 11.3 Google Fonts — Optimización

```html
<!-- ── Preconnect (speed up) ── -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

<!-- ── Solo los pesos que necesitas ── -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

<!-- ── Variable font (mejor rendimiento) ── -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap" rel="stylesheet">
```

```css
/* ── Self-hosted (mejor rendimiento y privacidad) ── */
@font-face {
  font-family: 'Inter';
  src: url('/fonts/Inter-Variable.woff2') format('woff2');
  font-weight: 400 700;        /* rango de la variable font */
  font-style: normal;
  font-display: swap;          /* muestra fallback mientras carga */
}

/* Fallback stack robusto */
body {
  font-family: 'Inter',
               -apple-system,       /* macOS/iOS */
               BlinkMacSystemFont,  /* Chrome en macOS */
               'Segoe UI',          /* Windows */
               Roboto,              /* Android */
               'Helvetica Neue',    /* macOS legacy */
               Arial,               /* universal fallback */
               sans-serif;
}
```

**Rendimiento tipográfico:**

```
Estrategias de carga:

  font-display: swap
  → Muestra texto con fuente del sistema inmediatamente
  → Cambia a la web font cuando carga
  → FOUT (Flash of Unstyled Text) - aceptable
  → Mejor para UX (contenido visible inmediatamente)

  font-display: optional
  → Si la fuente no carga en ~100ms, usa el fallback
  → NO hay re-render (sin FOUT)
  → Mejor para rendimiento (pero puede no mostrar tu fuente)

  Recomendación: swap para la mayoría de casos.
                 optional para fuentes decorativas no críticas.
```

### 11.4 Ejemplo Completo: Blog Article

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Merriweather:wght@400;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --font-heading: 'Merriweather', Georgia, serif;
      --font-body: 'Inter', sans-serif;
      --color-text: #111827;
      --color-text-secondary: #374151;
      --color-text-meta: #6B7280;
    }

    body {
      font-family: var(--font-body);
      font-size: 1rem;
      line-height: 1.5;
      color: var(--color-text);
      margin: 0;
      padding: 0;
    }

    .article {
      max-width: 720px;
      margin: 0 auto;
      padding: 40px 16px;
    }

    @media (min-width: 768px) {
      .article { padding: 64px 24px; }
    }

    .article__overline {
      font-size: 0.6875rem;
      font-weight: 500;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      color: var(--color-text-meta);
      margin-bottom: 12px;
    }

    .article__title {
      font-family: var(--font-heading);
      font-size: clamp(1.75rem, 1.3rem + 1.5vw, 2.5rem);
      font-weight: 700;
      line-height: 1.2;
      letter-spacing: -0.02em;
      margin-bottom: 16px;
    }

    .article__meta {
      font-size: 0.875rem;
      color: var(--color-text-meta);
      margin-bottom: 32px;
    }

    .article__lead {
      font-size: 1.125rem;
      line-height: 1.6;
      color: var(--color-text-secondary);
      margin-bottom: 32px;
    }

    .article__body p {
      font-size: 1rem;
      line-height: 1.625;
      margin-bottom: 1.5em;
      max-width: 65ch;
    }

    .article__body h2 {
      font-family: var(--font-heading);
      font-size: clamp(1.375rem, 1.1rem + 0.8vw, 1.75rem);
      font-weight: 700;
      line-height: 1.25;
      margin-top: 2.5em;
      margin-bottom: 0.75em;
    }

    .article__body blockquote {
      border-left: 3px solid #D1D5DB;
      padding-left: 20px;
      margin: 24px 0;
      font-style: italic;
      color: var(--color-text-secondary);
    }

    .article__body code {
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.875em;
      background: #F3F4F6;
      padding: 2px 6px;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <article class="article">
    <p class="article__overline">Design Systems</p>
    <h1 class="article__title">Building a Typography System That Scales</h1>
    <p class="article__meta">April 15, 2026 · 8 min read</p>
    <p class="article__lead">
      A well-designed typography system is the foundation of every
      great interface. Here's how to build one from scratch.
    </p>
    <div class="article__body">
      <p>
        Typography represents 95% of web design. Every interaction
        a user has with your product involves reading text — from
        navigation labels to error messages, from onboarding flows
        to data tables.
      </p>
      <h2>Starting with a Type Scale</h2>
      <p>
        The first step is choosing a modular scale that provides
        enough contrast between levels without creating jarring
        jumps. A ratio of <code>1.25</code> (Major Third) works
        well for most interfaces.
      </p>
      <blockquote>
        "Good typography is invisible. Bad typography is everywhere."
      </blockquote>
    </div>
  </article>
</body>
</html>
```

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Al empezar | ¿Tengo un sistema tipográfico definido? | Definir familia + escala + pesos + text styles |
| Al elegir fuente | ¿Priorizo legibilidad o personalidad? | Body → legibilidad siempre. Headings → puedes añadir personalidad |
| Al combinar fuentes | ¿Hay contraste funcional entre las dos? | Serif + Sans = seguro. Misma categoría = riesgo |
| Al definir jerarquía | ¿Puedo distinguir 3+ niveles de un vistazo? | Si no → aumentar contraste de size/weight |
| Al definir tamaños | ¿Body text ≥ 16px? ¿Inputs mobile ≥ 16px? | Sí siempre. No negociable |
| Al verificar contraste | ¿Cumple WCAG AA (4.5:1)? | Probar con herramienta de contraste |
| Al escalar a mobile | ¿Reduje headings pero mantuve body? | Headings escalan. Body y UI text se mantienen |
| Al implementar | ¿Uso tokens/variables o valores hardcoded? | Tokens siempre. Nunca `font-size: 14px` inline |

**Cheat Sheet de decisiones rápidas:**

```
  ¿Una fuente o dos?
  → Si dudas, una (Inter) con jerarquía de peso/tamaño.

  ¿Qué fuente para UI?
  → Inter, SF Pro, Roboto, DM Sans (seguras y probadas).

  ¿Body size?
  → 16px. Siempre. No 14px para body principal.

  ¿Cuántos pesos?
  → 3-4: Regular (400), Medium (500), Semibold (600), Bold (700).

  ¿Line-height para body?
  → 1.5 (24px a 16px base).

  ¿Line-height para headings?
  → 1.15-1.3 (más compacto que body).

  ¿Max width para texto?
  → 65ch (~680px). Nunca full-width en desktop.

  ¿Alineación?
  → Left. Siempre. Center solo para títulos cortos.
```

> **Mantra de tipografía:** Si el usuario tiene que esforzarse para leer, ya perdiste. La tipografía no es lo que el usuario ve — es lo que el usuario **no nota** porque todo fluye naturalmente. Un sistema tipográfico invisible es un sistema tipográfico exitoso.
