# Color — Módulo Completo

---

## 1. Fundamentos del Color

### 1.1 Qué es el Color en Contexto Digital

- **Intuición:** En el mundo digital, los colores no son pigmentos — son números. Cada color que ves en pantalla es una combinación de valores que la pantalla interpreta como luz. Entender los formatos te da control total sobre cada matiz.
- **Estructura formal:** Un color digital se define mediante un modelo de color — una forma de codificar matiz, intensidad y brillo en valores que las pantallas pueden reproducir.
- **Aplicación práctica:** Elegir el formato correcto no es trivial. HSL es mejor para diseñar sistemas escalables; HEX es el estándar de comunicación; RGB es lo que la pantalla realmente renderiza.

**Los tres formatos principales:**

| Formato | Estructura | Ejemplo (azul) | Mejor para |
|---|---|---|---|
| **HEX** | #RRGGBB | `#2563EB` | Comunicar colores (diseño ↔ dev) |
| **RGB** | rgb(R, G, B) | `rgb(37, 99, 235)` | Valores de pantalla directos |
| **HSL** | hsl(H, S%, L%) | `hsl(217, 91%, 53%)` | **Construir paletas y sistemas** |

```
Anatomía de HSL (el formato más útil para diseño):

  hsl(217, 91%, 53%)
       │    │     │
       │    │     └── Lightness (53%) → Qué tan claro/oscuro
       │    │         0% = negro, 100% = blanco
       │    │
       │    └── Saturation (91%) → Qué tan vivo/intenso
       │        0% = gris, 100% = máxima intensidad
       │
       └── Hue (217°) → El color en sí (posición en la rueda)
           0° = rojo, 120° = verde, 240° = azul

  Rueda de color (Hue):
              0° Rojo
             /        \
       300° Magenta    60° Amarillo
          |               |
       240° Azul      120° Verde
             \        /
            180° Cian
```

**¿Por qué HSL es superior para sistemas de diseño?**

```
Generar una escala de azul:

  Con HEX (imposible razonar):
  #EFF6FF → #DBEAFE → #BFDBFE → #93C5FD → #60A5FA → #3B82F6 → #2563EB
  → No hay lógica visible entre valores.

  Con HSL (lógica clara):
  hsl(214, 95%, 93%)   → Blue-50  (muy claro)
  hsl(214, 95%, 85%)   → Blue-100
  hsl(214, 95%, 75%)   → Blue-200
  hsl(214, 94%, 65%)   → Blue-300
  hsl(217, 91%, 60%)   → Blue-400
  hsl(217, 91%, 53%)   → Blue-500 (base)
  hsl(221, 83%, 45%)   → Blue-600
  hsl(224, 76%, 38%)   → Blue-700
  hsl(226, 71%, 30%)   → Blue-800
  hsl(224, 64%, 20%)   → Blue-900 (muy oscuro)

  → Solo ajustas Lightness (y levemente Saturation) manteniendo el Hue.
  → Lógica predecible y escalable.
```

### 1.2 Propiedades del Color

| Propiedad | Qué controla | Rango | Efecto visual |
|---|---|---|---|
| **Hue** | El color base (rojo, azul, verde…) | 0° – 360° | Cambia completamente el color |
| **Saturation** | Intensidad / viveza | 0% – 100% | 0% = gris, 100% = puro y vibrante |
| **Lightness** | Claridad / oscuridad | 0% – 100% | 0% = negro, 50% = puro, 100% = blanco |

```
Variaciones de un mismo Hue (azul, 217°):

  Saturation alta + Lightness media:
  hsl(217, 91%, 53%) → Azul vibrante (CTA, brand)

  Saturation baja + Lightness alta:
  hsl(217, 20%, 90%) → Azul grisáceo claro (fondos sutiles)

  Saturation media + Lightness baja:
  hsl(217, 50%, 25%) → Azul oscuro profundo (texto, headers oscuros)

  Saturation cero:
  hsl(217, 0%, 50%)  → Gris puro (neutral, sin color)
```

### 1.3 Psicología del Color en UX

| Color | Asociación | Uso típico en UI | Cuidado |
|---|---|---|---|
| **Azul** | Confianza, estabilidad, profesionalismo | CTAs, links, SaaS, finanzas | Puede sentirse frío/corporativo |
| **Verde** | Éxito, naturaleza, crecimiento | Success states, eco, salud, finanzas | Confusión con "dinero" fuera de US |
| **Rojo** | Urgencia, peligro, pasión | Errores, alertas, destructive actions | Puede generar ansiedad si se abusa |
| **Amarillo** | Atención, energía, optimismo | Warnings, highlights | Difícil de leer como texto, bajo contraste |
| **Naranja** | Amigable, acción, calidez | CTAs secundarios, notificaciones | Puede verse poco profesional si se abusa |
| **Púrpura** | Creatividad, lujo, innovación | Branding, productos premium | Puede sentirse poco serio |
| **Negro** | Elegancia, poder, sofisticación | Texto, modo oscuro, luxury | Puede sentirse pesado |
| **Blanco** | Limpieza, espacio, simplicidad | Fondos, breathing room | Puede sentirse vacío sin estructura |

> **Error común:** Elegir colores basándose únicamente en psicología. La psicología del color es un *input*, no la *decisión*. La funcionalidad (contraste, accesibilidad, jerarquía) siempre tiene prioridad.

### 1.4 Color como Herramienta Funcional

```
El color en UI tiene 4 funciones:

  1. JERARQUÍA — ¿Qué es más importante?
  ┌──────────────────────────────────────┐
  │  [ ████ Primary CTA ████ ]           │  ← Color sólido = principal
  │   Secondary Action                   │  ← Color como texto = secundario
  │   Tertiary link                      │  ← Color sutil = terciario
  └──────────────────────────────────────┘

  2. ESTADO — ¿Qué está pasando?
  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
  │ ✓ OK   │ │ ⚠ Warn │ │ ✗ Error│ │ ℹ Info │
  │ verde  │ │amarillo│ │  rojo  │ │  azul  │
  └────────┘ └────────┘ └────────┘ └────────┘

  3. AGRUPACIÓN — ¿Qué pertenece junto?
  Elementos del mismo color → misma categoría.
  Color diferente → categoría diferente.

  4. ORIENTACIÓN — ¿Dónde debo mirar?
  En una interfaz mayormente neutra, el color vivo
  es un imán visual → úsalo para guiar la atención.
```

> **Principio fundamental:** El color es una herramienta de comunicación. Si un color no cumple una función (jerarquía, estado, agrupación, orientación), no debería estar ahí.

---

## 2. Sistemas de Color (Color Schemes)

### 2.1 Tipos de Esquemas

```
Rueda de color — Referencia para todos los esquemas:

              0° Rojo
           330° /  \ 30°
        Rosado /    \ Naranja
       300°   /      \ 60°
    Magenta  /        \ Amarillo
       270° |          | 90°
     Violeta|          |Chartreuse
       240° |          | 120°
       Azul  \        / Verde
         210° \      / 150°
          Cian \    / Teal
                180°
```

**Monocromático:**

```
Un solo hue, variando saturation y lightness:

  Hue: 217° (azul)
  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
  │ 95% │ │ 80% │ │ 53% │ │ 38% │ │ 20% │  ← Lightness
  │light│ │     │ │base │ │     │ │dark │
  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘

  Ventaja: Armonía garantizada, imposible que choque.
  Uso: Interfaces minimalistas, focus en contenido.
  Riesgo: Puede ser monótono, falta de contraste entre elementos.
```

**Análogo:**

```
Hues adyacentes en la rueda (±30-60°):

  Hue: 200° (cian) + 217° (azul) + 240° (azul-violeta)
  ┌─────┐ ┌─────┐ ┌─────┐
  │ 200°│ │ 217°│ │ 240°│
  │cian │ │azul │ │viol.│
  └─────┘ └─────┘ └─────┘

  Ventaja: Armonía natural, transiciones suaves.
  Uso: Productos que necesitan variedad sin agresividad.
  Riesgo: Poco contraste, difícil crear jerarquía fuerte.
```

**Complementario:**

```
Hues opuestos en la rueda (180° de distancia):

  217° (azul) ◄────────────► 37° (naranja)
  ┌─────┐                    ┌─────┐
  │ 217°│                    │  37°│
  │azul │                    │naran│
  └─────┘                    └─────┘

  Ventaja: Máximo contraste y energía visual.
  Uso: CTAs que necesitan destacar sobre el color principal.
  Riesgo: Agresivo si se usan en proporciones iguales.
  Regla: 80% color dominante, 20% complementario.
```

**Triádico:**

```
Tres hues equidistantes (120° entre cada uno):

  0° (rojo) — 120° (verde) — 240° (azul)
  ┌─────┐     ┌─────┐     ┌─────┐
  │  0° │     │ 120°│     │ 240°│
  │rojo │     │verde│     │azul │
  └─────┘     └─────┘     └─────┘

  Ventaja: Vibrante y balanceado.
  Uso: Branding colorido, apps para niños, creatividad.
  Riesgo: Puede ser caótico. Requiere un color dominante + dos de soporte.
```

**Tetrádico (doble complementario):**

```
Cuatro hues formando un rectángulo:

  0° — 90° — 180° — 270°
  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
  │rojo │ │amar.│ │cian │ │viol.│
  └─────┘ └─────┘ └─────┘ └─────┘

  Ventaja: Máxima variedad cromática.
  Uso: Rare en UI — más para branding o ilustración.
  Riesgo: Muy difícil de balancear. Uno domina, el resto son acentos.
```

### 2.2 Cuándo Usar Cada Esquema

| Esquema | Mejor para | Personalidad | Dificultad |
|---|---|---|---|
| **Monocromático** | SaaS, dashboards, UI minimal | Profesional, sobrio | ★☆☆ Fácil |
| **Análogo** | Apps de bienestar, portfolios | Cálido, orgánico | ★★☆ Media |
| **Complementario** | E-commerce, landing pages | Dinámico, contrastante | ★★☆ Media |
| **Triádico** | Apps infantiles, creatividad | Vibrante, juguetón | ★★★ Difícil |
| **Tetrádico** | Branding, ilustración | Complejo, rico | ★★★ Muy difícil |

> **Recomendación para la mayoría de productos UI:** Esquema monocromático con un color de acento complementario. Es el más seguro, profesional y escalable.

### 2.3 Balance entre Armonía y Contraste

```
Regla 60-30-10:

  ┌──────────────────────────────────────────────┐
  │                                              │
  │  ██████████████████████████████████████████  │  60% Neutral
  │  ██████████████████████████████████████████  │  (fondos, texto)
  │  ██████████████████████████████████████████  │
  │                                              │
  │  ████████████████████████                    │  30% Primary
  │  ████████████████████████                    │  (brand, acciones)
  │                                              │
  │  ██████████                                  │  10% Accent
  │                                              │  (CTAs, estados)
  └──────────────────────────────────────────────┘

  60% Neutral (grises, blancos, fondos)
  30% Primary (color de marca, elementos clave)
  10% Accent  (CTAs, highlights, color complementario)
```

---

## 3. Creación de Paletas de Color

### 3.1 Cómo Construir una Paleta desde Cero

**Proceso paso a paso:**

```
Paso 1: Elegir color primario (brand)
  → Basado en branding, personalidad del producto
  → Ejemplo: hsl(217, 91%, 53%) — azul confiable

Paso 2: Generar escala de ese color (50-900)
  → Variar Lightness (95% → 15%)
  → Ajustar Saturation en los extremos

Paso 3: Construir escala neutral (grises)
  → Con un toque sutil del hue primario (warm o cool grays)
  → hsl(217, 10%, L%) ← grises con tinte azul

Paso 4: Definir colores semánticos
  → Success: verde
  → Warning: amarillo/naranja
  → Error: rojo
  → Info: azul (o el primario)

Paso 5: Opcional — color de acento
  → Complementario o análogo al primario
  → Para CTAs secundarios, badges, highlights

Paso 6: Validar contraste WCAG en todas las combinaciones
```

### 3.2 Selección Basada en Contexto

**Producto SaaS:**

```
Paleta SaaS (profesional, confiable):

  Primary:  Azul (hsl(217, 91%, 53%))
  Neutral:  Cool grays (hsl(217, 10%, L%))
  Accent:   Índigo o violeta sutil
  Semantic: Standard (green/yellow/red/blue)

  Vibe: Serio, confiable, data-driven
  Referencia: Linear, Notion, Stripe Dashboard
```

**E-commerce:**

```
Paleta E-commerce (energético, acción):

  Primary:  Naranja o verde (acción, "comprar")
  Neutral:  Warm grays (hsl(30, 8%, L%))
  Accent:   Color complementario para ofertas/destacados
  Semantic: Standard + colores de descuento

  Vibe: Dinámico, urgente, amigable
  Referencia: Amazon, Shopify storefront
```

**Blog / Contenido:**

```
Paleta Editorial (elegante, legible):

  Primary:  Neutro oscuro o tinta (hsl(220, 30%, 20%))
  Neutral:  Warm off-whites y grises suaves
  Accent:   Un color sutil para links y highlights
  Semantic: Mínimo (solo errores en formularios)

  Vibe: Sereno, enfocado en lectura, editorial
  Referencia: Medium, Substack
```

### 3.3 Escalas de Color (Shades y Tints)

- **Intuición:** Una escala de color es una rampa de la misma familia de color que va de muy claro (tint) a muy oscuro (shade). Es como tener un lápiz de colores con 10 intensidades del mismo azul.
- **Estructura formal:** Cada paso de la escala varía primariamente en lightness, con ajustes sutiles en saturation para mantener la percepción de color consistente.

```
Escala de color (sistema 50-900):

  Nombre    HSL                      Uso típico
  ─────────────────────────────────────────────────────────
  50        hsl(214, 100%, 97%)      Fondos muy sutiles
  100       hsl(214, 95%, 93%)       Fondos hover, badges light
  200       hsl(214, 94%, 86%)       Bordes suaves, selected bg
  300       hsl(214, 93%, 74%)       Bordes activos, decorativos
  400       hsl(217, 91%, 60%)       Iconos secundarios
  500       hsl(217, 91%, 53%)     ★ BASE — brand, CTAs, links
  600       hsl(221, 83%, 45%)       Hover del primario
  700       hsl(224, 76%, 38%)       Active/pressed del primario
  800       hsl(226, 71%, 30%)       Texto sobre fondos claros
  900       hsl(224, 64%, 20%)       Headings, texto máximo contraste

  Patrón: Lightness decrece 50→900.
  Saturation: ligeramente menor en extremos (muy claro/muy oscuro).

  Visual:
  50   100  200  300  400  500  600  700  800  900
  ░░░  ░░░  ▒▒▒  ▒▒▒  ▓▓▓  ███  ███  ███  ███  ███
  light ─────────────────────────────────────── dark
```

**Construir neutrales con personalidad:**

```
Grises puros vs Grises con tinte:

  Grises puros (fríos, genéricos):
  hsl(0, 0%, 97%)    → #F7F7F7
  hsl(0, 0%, 50%)    → #808080
  hsl(0, 0%, 13%)    → #212121

  Cool grays (con tinte azul — profesional):
  hsl(217, 14%, 97%)  → tinte azul sutil
  hsl(217, 10%, 50%)  → gris azulado
  hsl(217, 14%, 13%)  → casi negro azulado

  Warm grays (con tinte amarillo — acogedor):
  hsl(40, 10%, 97%)   → tinte cálido
  hsl(40, 6%, 50%)    → gris cálido
  hsl(40, 10%, 13%)   → casi negro cálido

  Recomendación: Usa grises con tinte del color primario.
  Si tu brand es azul → cool grays.
  Si tu brand es naranja → warm grays.
  Crea coherencia visual sin esfuerzo.
```

### 3.4 Herramientas

| Herramienta | Mejor para | URL |
|---|---|---|
| **Realtime Colors** | Ver paleta en UI real en tiempo real | realtimecolors.com |
| **Coolors** | Generar paletas rápido | coolors.co |
| **Huemint** | AI-generated paletas en contexto | huemint.com |
| **Color Review** | Verificar contraste WCAG | color.review |
| **Tailwind Color Generator** | Generar escalas 50-900 | uicolors.app |
| **Figma Plugins** | Contrast checker, palette gen | Figma community |

---

## 4. Tipos de Colores en UI

### 4.1 Vista General del Sistema

```
Estructura de colores en un design system:

  ┌─────────────────────────────────────────────────────────┐
  │                    COLOR SYSTEM                         │
  │                                                         │
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
  │  │  PRIMARY     │  │  NEUTRAL    │  │  SEMANTIC    │    │
  │  │             │  │             │  │             │    │
  │  │ Brand color │  │ Grays       │  │ Success     │    │
  │  │ CTAs        │  │ Text        │  │ Warning     │    │
  │  │ Links       │  │ Backgrounds │  │ Error       │    │
  │  │ Active      │  │ Borders     │  │ Info        │    │
  │  │ states      │  │ Dividers    │  │             │    │
  │  └─────────────┘  └─────────────┘  └─────────────┘    │
  │                                                         │
  │  ┌─────────────┐                                       │
  │  │  ACCENT     │  (Opcional)                           │
  │  │             │                                       │
  │  │ Secondary   │                                       │
  │  │ highlights  │                                       │
  │  │ Badges      │                                       │
  │  └─────────────┘                                       │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

### 4.2 Primary Colors

- **Función:** Representan la marca y las acciones principales.
- **Uso:** Botones primarios, links, iconos activos, barras de navegación activas, focus rings.

```
Primary en contexto:

  ┌──────────────────────────────────────────────┐
  │                                              │
  │  Logo (primary-600)                          │
  │                                              │
  │  ┌──────────────────────────────────────┐   │
  │  │  [Tab activo]  Tab    Tab    Tab     │   │  ← primary-500 underline
  │  └──────────────────────────────────────┘   │
  │                                              │
  │  Título de sección                           │
  │  Texto descriptivo con un link aquí.         │  ← primary-500 text
  │                                              │
  │  [ ████ Primary Button ████ ]               │  ← primary-500 bg
  │   Secondary Button                           │  ← primary-500 text
  │                                              │
  └──────────────────────────────────────────────┘

  Escala de primary (uso):
  primary-50:  Background sutil (selected row, hover bg)
  primary-100: Background claro (badge, tag bg)
  primary-200: Borde suave (focus ring light)
  primary-500: ★ Color base (buttons, links, icons)
  primary-600: Hover state
  primary-700: Active/pressed state
  primary-900: Texto sobre fondos claros (si necesitas)
```

### 4.3 Neutral Colors

- **Función:** El 80% de tu interfaz. Texto, fondos, bordes, sombras, dividers.
- **Uso:** Todo lo que no necesita "color".

```
Escala de neutrales y su uso:

  Nombre        Uso típico
  ────────────────────────────────────────────────
  neutral-0     #FFFFFF — fondos principales (page bg)
  neutral-50    Background sutil (cards, sections alternas)
  neutral-100   Background hover, inputs bg
  neutral-200   Bordes, dividers, separadores
  neutral-300   Bordes hover, bordes de input focus
  neutral-400   Placeholder text, iconos disabled
  neutral-500   Texto terciario, metadata, captions
  neutral-600   Texto secundario, labels, subheadings
  neutral-700   Texto secundario fuerte
  neutral-800   Texto primario (body text)
  neutral-900   Texto máximo contraste (headings)

  Distribución visual:
  neutral-0    ░░░░░░░░░░░░░░░░░░░░  Fondos (más usado)
  neutral-50   ░░░░░░░░░░░░░░░
  neutral-100  ░░░░░░░░░░░
  neutral-200  ░░░░░░░                Bordes
  neutral-300  ░░░░░
  neutral-400  ░░░░                   Disabled
  neutral-500  ░░░░░                  Meta text
  neutral-600  ░░░░░░░               Labels
  neutral-700  ░░░░░░░░░
  neutral-800  ░░░░░░░░░░░░░         Body text
  neutral-900  ░░░░░░░░░░░░░░░       Headings (más usado)
```

> **Error crítico:** No usar `#000000` puro para texto. Usa `neutral-800` o `neutral-900` (ej: `#1F2937`) — reduce fatiga visual manteniendo contraste excelente.

### 4.4 Accent Colors

- **Función:** Elementos secundarios que necesitan destacar sin competir con el primary.
- **Uso:** Badges, tags, highlights, secondary CTAs, decorativos.

```
Accent vs Primary:

  Primary (azul): Acción principal
  Accent (violeta): Destaque secundario

  ┌──────────────────────────────────────────────┐
  │                                              │
  │  [Primary Button]    [Accent Badge: NEW]    │
  │                                              │
  │  Primary link        Accent highlight        │
  │                                              │
  └──────────────────────────────────────────────┘

  Regla: Accent < 10% de la interfaz.
  Si compite visualmente con primary → estás usando mucho.
```

### 4.5 Semantic Colors

- **Función:** Comunican estado y significado independientemente del branding.
- **Uso:** Alertas, validación de formularios, badges de estado, banners.

```
Semantic colors y su sistema:

  SUCCESS (verde):
  ┌──────────────────────────────────────┐
  │  ✓ Changes saved successfully        │  success-50 bg
  │                                      │  success-700 text
  │                                      │  success-200 border
  └──────────────────────────────────────┘

  WARNING (amarillo/ámbar):
  ┌──────────────────────────────────────┐
  │  ⚠ Your trial expires in 3 days     │  warning-50 bg
  │                                      │  warning-700 text
  │                                      │  warning-200 border
  └──────────────────────────────────────┘

  ERROR (rojo):
  ┌──────────────────────────────────────┐
  │  ✗ Payment failed. Please retry.     │  error-50 bg
  │                                      │  error-700 text
  │                                      │  error-200 border
  └──────────────────────────────────────┘

  INFO (azul):
  ┌──────────────────────────────────────┐
  │  ℹ New features available            │  info-50 bg
  │                                      │  info-700 text
  │                                      │  info-200 border
  └──────────────────────────────────────┘

  Cada semántico necesita su propia escala (50-900)
  para fondos, bordes, iconos y texto.
```

**Escala semántica mínima por color:**

| Step | Uso | Success | Warning | Error |
|---|---|---|---|---|
| **50** | Background | `hsl(142, 72%, 96%)` | `hsl(48, 96%, 95%)` | `hsl(0, 86%, 97%)` |
| **100** | Background hover | `hsl(141, 69%, 90%)` | `hsl(48, 96%, 89%)` | `hsl(0, 93%, 92%)` |
| **200** | Border | `hsl(141, 63%, 78%)` | `hsl(48, 90%, 75%)` | `hsl(0, 90%, 82%)` |
| **500** | Icon, badge | `hsl(142, 71%, 45%)` | `hsl(45, 93%, 47%)` | `hsl(0, 84%, 60%)` |
| **700** | Text | `hsl(142, 64%, 28%)` | `hsl(32, 95%, 30%)` | `hsl(0, 74%, 35%)` |
| **900** | Text fuerte | `hsl(144, 61%, 15%)` | `hsl(28, 80%, 18%)` | `hsl(0, 63%, 20%)` |

### 4.6 Roles Claros dentro del Sistema

```
Reglas de uso de color:

  ┌──────────────────────────────────────────────────┐
  │  REGLA: Cada color tiene UN rol.                 │
  │  No mezcles roles.                               │
  │                                                  │
  │  ❌ Usar rojo para un botón primario             │
  │     (rojo = error/peligro, confunde)             │
  │                                                  │
  │  ❌ Usar verde para branding + success            │
  │     (¿es un CTA o un success message?)           │
  │                                                  │
  │  ✅ Primary = azul (solo para acciones brand)    │
  │  ✅ Success = verde (solo para éxito)            │
  │  ✅ Error = rojo (solo para errores/destrucción) │
  │  ✅ Neutral = grises (solo para estructura)      │
  └──────────────────────────────────────────────────┘

  Excepción: Si tu brand ES rojo (ej: YouTube), el botón primario
  puede ser rojo, pero los errores deben tener un rojo DIFERENTE
  (más oscuro, diferente tono) o usar otro indicador adicional
  (icono, posición, texto).
```

---

## 5. Color Styles y Design Systems

### 5.1 Definición de Color Styles

- **Intuición:** Un color style es un "nombre con significado" asignado a un color. En lugar de `#2563EB`, dices `primary-500`. En lugar de `#F3F4F6`, dices `neutral-100`. Así, cambiar el azul de toda la app requiere cambiar UN valor.
- **Estructura formal:** Los color styles son abstracciones nombradas que mapean valores de color a roles funcionales, permitiendo cambios globales desde un punto único de verdad.

### 5.2 Tokens de Color

```
Arquitectura de 3 capas:

  Capa 1: PRIMITIVOS (valores raw)
  ─────────────────────────────────
  --blue-500: hsl(217, 91%, 53%);
  --blue-600: hsl(221, 83%, 45%);
  --red-500:  hsl(0, 84%, 60%);
  --gray-100: hsl(217, 14%, 96%);
  --gray-800: hsl(217, 19%, 17%);

  Capa 2: SEMÁNTICOS (intención)
  ─────────────────────────────────
  --color-primary:     var(--blue-500);
  --color-primary-hover: var(--blue-600);
  --color-bg-default:  var(--gray-0);
  --color-bg-subtle:   var(--gray-100);
  --color-text-primary: var(--gray-800);
  --color-error:       var(--red-500);
  --color-success:     var(--green-500);

  Capa 3: COMPONENTES (contexto específico)
  ─────────────────────────────────
  --button-primary-bg:    var(--color-primary);
  --button-primary-hover: var(--color-primary-hover);
  --input-border:         var(--color-border-default);
  --alert-error-bg:       var(--color-error-subtle);

  ¿Por qué 3 capas?
  → Capa 1: Fácil de generar y mantener
  → Capa 2: Cambiar "primary" cambia TODO lo que use primary
  → Capa 3: Un botón puede usar tokens diferentes a un link,
            aunque ambos sean "primary"
```

**Dark mode con tokens:**

```
El poder de los tokens semánticos:

  Light mode:
  --color-bg-default:    var(--white);        → #FFFFFF
  --color-bg-subtle:     var(--gray-50);      → #F9FAFB
  --color-text-primary:  var(--gray-900);     → #111827
  --color-text-secondary: var(--gray-600);    → #4B5563
  --color-border:        var(--gray-200);     → #E5E7EB

  Dark mode (solo cambias los mappings):
  --color-bg-default:    var(--gray-900);     → #111827
  --color-bg-subtle:     var(--gray-800);     → #1F2937
  --color-text-primary:  var(--gray-50);      → #F9FAFB
  --color-text-secondary: var(--gray-400);    → #9CA3AF
  --color-border:        var(--gray-700);     → #374151

  Los componentes NO cambian. Solo los tokens semánticos.
  → El botón sigue usando --color-primary → funciona en ambos temas.
```

### 5.3 Naming Conventions

```
Estructura recomendada: [Categoría]/[Step]

  Primitivos:
  ──────────
  blue/50, blue/100, blue/200, ... blue/900
  gray/50, gray/100, gray/200, ... gray/900
  green/50, green/100, ... green/900
  red/50, red/100, ... red/900

  Semánticos:
  ──────────
  primary/default, primary/hover, primary/active
  bg/default, bg/subtle, bg/muted
  text/primary, text/secondary, text/tertiary, text/disabled
  border/default, border/strong
  success/default, success/subtle, success/text
  error/default, error/subtle, error/text
  warning/default, warning/subtle, warning/text
  info/default, info/subtle, info/text

  ❌ Nombres malos:
  "blue button color", "dark gray", "light bg", "error red"
  → Describe apariencia, no función. No escala.

  ✅ Nombres buenos:
  "primary/500", "text/primary", "bg/subtle", "error/default"
  → Describe función. Escala. Compatible con dark mode.
```

### 5.4 Escalabilidad

```
Test de escalabilidad del sistema de color:

  ¿Puedes responder estas preguntas con tu sistema?

  1. "¿Qué color uso para el fondo de un input hover?"
     → bg/muted o neutral/100 ✓

  2. "¿Qué color uso para un borde de error?"
     → error/200 o border/error ✓

  3. "Necesito agregar dark mode"
     → Cambio los mappings semánticos, los componentes no cambian ✓

  4. "Necesito cambiar el azul de la marca a púrpura"
     → Cambio primary/* tokens, todo se actualiza ✓

  5. "Necesito un estado 'new feature'"
     → Creo un nuevo semántico (feature/) usando un primitivo existente ✓

  Si tu sistema no puede responder alguna → necesita refactoring.
```

---

## 6. Contraste y Accesibilidad

### 6.1 Importancia del Contraste

- **Intuición:** Si no puedes distinguir el texto del fondo, no importa cuán bello sea el diseño — no funciona. El contraste es la base de la legibilidad.
- **Estructura formal:** El contraste es la diferencia de luminancia entre dos colores superpuestos, medido como un ratio (ej: 4.5:1). WCAG define mínimos para garantizar legibilidad.

### 6.2 Relación de Contraste (WCAG)

| Nivel | Texto normal (< 18px bold / 24px) | Texto grande (≥ 18px bold / 24px) | UI components |
|---|---|---|---|
| **AA** (mínimo) | **4.5:1** | **3:1** | **3:1** |
| **AAA** (óptimo) | **7:1** | **4.5:1** | — |

```
Ejemplos de ratios de contraste:

  ✅ Pasa AA + AAA:
  #111827 sobre #FFFFFF → 18.4:1    (texto principal)
  #374151 sobre #FFFFFF → 10.3:1    (texto secundario)

  ✅ Pasa AA:
  #4B5563 sobre #FFFFFF → 7.5:1     (texto terciario)
  #6B7280 sobre #FFFFFF → 4.6:1     (apenas AA para normal text)

  ⚠️ Pasa AA solo para large text:
  #9CA3AF sobre #FFFFFF → 2.9:1     (solo large text AA)

  ❌ No pasa:
  #D1D5DB sobre #FFFFFF → 1.8:1     (ilegible como texto)
  #3B82F6 sobre #2563EB → 1.3:1     (azul sobre azul)
```

```
Contraste en contexto real:

  Fondo blanco (#FFF):
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  Heading text (#111827)                    18.4:1 ✓  │
  │  Body text (#374151)                       10.3:1 ✓  │
  │  Secondary text (#6B7280)                   4.6:1 ✓  │
  │  Placeholder (#9CA3AF)                      2.9:1 ⚠  │
  │  Disabled text (#D1D5DB)                    1.8:1 ✗  │
  │                                                      │
  │  [ Blue Button (#2563EB) ] text white       4.6:1 ✓  │
  │  [ Green Button (#16A34A) ] text white      3.4:1 ⚠  │
  │  [ Yellow Button (#EAB308) ] text white     1.9:1 ✗  │
  │                                                      │
  └──────────────────────────────────────────────────────┘

  ⚠ Verde y amarillo sobre blanco son problemáticos.
  Solución: Usar texto oscuro sobre esos colores, no blanco.
```

### 6.3 Texto sobre Fondos de Color

```
Regla para texto sobre color:

  Fondo claro (lightness > 60%) → texto oscuro
  Fondo oscuro (lightness < 45%) → texto claro (blanco)
  Zona gris (45-60%)            → PROBAR y medir

  ✅ Correcto:
  ┌─────────────────────────────┐
  │  FONDO OSCURO (#1E40AF)     │
  │  Texto blanco (#FFFFFF)     │  → 8.5:1 ✓
  └─────────────────────────────┘

  ┌─────────────────────────────┐
  │  FONDO CLARO (#EFF6FF)      │
  │  Texto oscuro (#1E3A5F)     │  → 10.1:1 ✓
  └─────────────────────────────┘

  ❌ Incorrecto:
  ┌─────────────────────────────┐
  │  FONDO MEDIO (#60A5FA)      │
  │  Texto blanco (#FFFFFF)     │  → 2.4:1 ✗
  └─────────────────────────────┘
  → Azul medio con texto blanco = ilegible.
```

### 6.4 No Depender Solo del Color

```
❌ Solo color para comunicar estado:

  ┌──────────────────┐ ┌──────────────────┐
  │  ●  Active       │ │  ●  Inactive     │  ← Un usuario
  │  (verde)         │ │  (rojo)          │     daltónico no puede
  └──────────────────┘ └──────────────────┘     distinguirlos

✅ Color + otro indicador:

  ┌──────────────────┐ ┌──────────────────┐
  │  ✓  Active       │ │  ✗  Inactive     │  ← Icono diferente
  │  (verde)         │ │  (rojo)          │  ← Texto diferente
  └──────────────────┘ └──────────────────┘  ← Color como refuerzo

Otros indicadores además del color:
  - Iconos (✓, ✗, ⚠, ℹ)
  - Texto (Active/Inactive, Success/Error)
  - Forma (borde sólido vs punteado)
  - Posición (progress bar, badges)
  - Patrón (rayado, punteado para gráficos)
```

**~8% de hombres y ~0.5% de mujeres tienen algún tipo de daltonismo.** En un producto con 100k usuarios, eso son ~4,000+ personas que no distinguen ciertos colores.

### 6.5 Checklist de Accesibilidad de Color

```
  ☐ Todo texto funcional cumple contraste AA (4.5:1)
  ☐ Texto grande cumple al menos 3:1
  ☐ Componentes interactivos (botones, inputs) cumplen 3:1 contra fondo
  ☐ Focus rings visibles con suficiente contraste
  ☐ No se usa SOLO color para comunicar información
  ☐ Semánticos funcionan para daltónicos (test con simulador)
  ☐ Links distinguibles sin color (underline o combinación)
  ☐ Disabled states distinguibles pero no confusos
  ☐ Dark mode mantiene los mismos ratios de contraste
  ☐ Probado con herramientas: Stark, Color Review, axe
```

---

## 7. Uso del Color en la Interfaz

### 7.1 Jerarquía Visual mediante Color

```
Jerarquía de 4 niveles con color:

  Nivel 1: Color sólido (máxima atención)
  [ ████ Primary Button ████ ]       ← bg: primary-500, text: white

  Nivel 2: Color como texto/borde
  [ Secondary Button ]                ← border: primary-500, text: primary-500

  Nivel 3: Color sutil
  Tertiary Action →                   ← text: primary-500, sin borde

  Nivel 4: Sin color (mínima atención)
  neutral link →                      ← text: neutral-600

  Regla: Solo 1 elemento en Nivel 1 por sección.
  Si todo grita, nada se escucha.
```

### 7.2 Estados de UI con Color

```
Botón primario — Todos los estados:

  Default:    bg: primary-500    → color de marca
  ┌─────────────────────────┐
  │      Primary Button     │
  └─────────────────────────┘

  Hover:      bg: primary-600    → ligeramente más oscuro
  ┌─────────────────────────┐
  │      Primary Button     │  ← cursor encima
  └─────────────────────────┘

  Active:     bg: primary-700    → más oscuro (pressed)
  ┌─────────────────────────┐
  │      Primary Button     │  ← click en progreso
  └─────────────────────────┘

  Focus:      bg: primary-500 + ring: primary-200 (3px)
  ┌─╔═════════════════════╗─┐
  │ ║   Primary Button    ║ │  ← focus ring visible
  └─╚═════════════════════╝─┘

  Disabled:   bg: neutral-200, text: neutral-400
  ┌─────────────────────────┐
  │      Primary Button     │  ← opaco, no interactivo
  └─────────────────────────┘

  Loading:    bg: primary-500 (opacidad 70%) + spinner
  ┌─────────────────────────┐
  │      ●●●                │  ← spinner, no clickable
  └─────────────────────────┘
```

```css
/* Estados de color en CSS */
.button-primary {
  background-color: var(--color-primary);         /* default */
  color: white;
}

.button-primary:hover {
  background-color: var(--color-primary-hover);    /* -600 */
}

.button-primary:active {
  background-color: var(--color-primary-active);   /* -700 */
}

.button-primary:focus-visible {
  outline: 3px solid var(--color-primary-200);     /* focus ring */
  outline-offset: 2px;
}

.button-primary:disabled {
  background-color: var(--color-bg-muted);         /* neutral-200 */
  color: var(--color-text-disabled);               /* neutral-400 */
  cursor: not-allowed;
}
```

**Inputs — Estados con color:**

```
Input states:

  Default:   border: neutral-300
  ┌─────────────────────────────────┐
  │ Placeholder text                │
  └─────────────────────────────────┘

  Focus:     border: primary-500, ring: primary-100
  ╔═════════════════════════════════╗
  ║ Typing here...                 ║
  ╚═════════════════════════════════╝

  Error:     border: error-500, bg: error-50
  ┌─────────────────────────────────┐
  │ invalid@                        │  ← border rojo
  └─────────────────────────────────┘
  ✗ Please enter a valid email        ← error-600 text

  Success:   border: success-500 (opcional)
  ┌─────────────────────────────────┐
  │ user@example.com           ✓   │  ← check verde
  └─────────────────────────────────┘

  Disabled:  bg: neutral-100, border: neutral-200, text: neutral-400
  ┌─────────────────────────────────┐
  │ Not editable                    │  ← gris, no interactivo
  └─────────────────────────────────┘
```

### 7.3 Color en Feedback

```
Alerts / Banners:

  Success:
  ┌────────────────────────────────────────────────┐
  │  ✓  Your changes have been saved.              │
  │     bg: success-50, border: success-200        │
  │     icon: success-500, text: success-700       │
  └────────────────────────────────────────────────┘

  Warning:
  ┌────────────────────────────────────────────────┐
  │  ⚠  Your subscription expires in 3 days.       │
  │     bg: warning-50, border: warning-200        │
  │     icon: warning-500, text: warning-700       │
  └────────────────────────────────────────────────┘

  Error:
  ┌────────────────────────────────────────────────┐
  │  ✗  Payment failed. Please try again.          │
  │     bg: error-50, border: error-200            │
  │     icon: error-500, text: error-700           │
  └────────────────────────────────────────────────┘

  Info:
  ┌────────────────────────────────────────────────┐
  │  ℹ  New dashboard features available.          │
  │     bg: info-50, border: info-200              │
  │     icon: info-500, text: info-700             │
  └────────────────────────────────────────────────┘

  Patrón consistente:
  - Background: [semantic]-50  (sutil)
  - Border:     [semantic]-200 (visible pero no agresivo)
  - Icon:       [semantic]-500 (identificable)
  - Text:       [semantic]-700 (legible con alto contraste)
```

**Badges / Status indicators:**

```
Status badges:

  ● Active      → success-500 dot + success-50 bg + success-700 text
  ● Pending     → warning-500 dot + warning-50 bg + warning-700 text
  ● Failed      → error-500 dot + error-50 bg + error-700 text
  ● Draft       → neutral-400 dot + neutral-100 bg + neutral-600 text
  ● New         → primary-500 dot + primary-50 bg + primary-700 text
```

---

## 8. Visualización y Mejora Estética

### 8.1 Balance entre Colores

```
❌ Sobreuso de color:
┌──────────────────────────────────────────────┐
│  ███ HEADER ███ (azul intenso)               │
│  ┌──── rojo ────┐ ┌──── verde ───┐          │
│  │  KPI $45k    │ │  KPI 1234    │          │
│  └──────────────┘ └──────────────┘          │
│  ┌── naranja ───┐ ┌── púrpura ──┐          │
│  │  Chart       │ │  Table      │          │
│  └──────────────┘ └──────────────┘          │
│  [ Yellow CTA ] [ Green CTA ] [ Red CTA ]   │
└──────────────────────────────────────────────┘
→ Sobrecargado, sin jerarquía, fatiga visual.

✅ Uso estratégico de color:
┌──────────────────────────────────────────────┐
│  Logo                           [Avatar]     │
│                                              │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ │
│  │  $45.2k   │ │  1,234    │ │  2.3%     │ │  neutral cards
│  │  Revenue  │ │  Users    │ │  Churn    │ │
│  └───────────┘ └───────────┘ └───────────┘ │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  Chart (neutral + 1 color primario) │   │  1 color en data
│  └──────────────────────────────────────┘   │
│                                              │
│  [ ████ Primary CTA ████ ]                  │  único acento de color
│                                              │
└──────────────────────────────────────────────┘
→ El color guía la atención. Los neutrales respiran.
```

### 8.2 Color y Profundidad

```
Técnicas de profundidad con color:

  1. SOMBRAS (elevation):
  ┌─────────────────────┐
  │  Card               │ ─── box-shadow con color sutil
  │  Content            │     ← NO negro puro para sombras
  └─────────────────────┘     ← Usa neutral-900/10% o el hue primario/5%

  shadow-sm: 0 1px 2px hsl(217, 20%, 20%, 0.05)
  shadow-md: 0 4px 6px hsl(217, 20%, 20%, 0.08)
  shadow-lg: 0 10px 15px hsl(217, 20%, 20%, 0.10)

  2. OVERLAYS (dimming):
  Fondo oscurecido detrás de modales
  → overlay: hsl(217, 20%, 10%, 0.5) — negro azulado al 50%

  3. SURFACE LEVELS:
  ┌──────────────────────────── Level 0: bg-default (#FFF) ─────┐
  │                                                              │
  │  ┌───────────────────── Level 1: bg-subtle (#F9FAFB) ────┐ │
  │  │                                                        │ │
  │  │  ┌────────────── Level 2: bg-default (#FFF) + shadow ┐│ │
  │  │  │  Card content                                     ││ │
  │  │  └───────────────────────────────────────────────────┘│ │
  │  │                                                        │ │
  │  └────────────────────────────────────────────────────────┘ │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### 8.3 Dark Mode vs Light Mode

```
Principios de dark mode:

  ≠ "Invertir todos los colores"
  = Rediseñar las relaciones de luminancia

  Light Mode:             Dark Mode:
  bg: #FFFFFF             bg: #111827 (neutral-900)
  surface: #F9FAFB        surface: #1F2937 (neutral-800)
  text: #111827           text: #F9FAFB (neutral-50)
  border: #E5E7EB         border: #374151 (neutral-700)
  primary: #2563EB        primary: #60A5FA (← MÁS CLARO, no el mismo)

  Regla 1: En dark mode, el primary se ACLARA (no mantener el mismo).
  Regla 2: Reducir saturación ligeramente (colores vibrantes queman en dark).
  Regla 3: Sombras no funcionan en dark → usar bordes o surface levels.
  Regla 4: Nunca fondo #000000 puro → usar #111827 o #0F172A.
```

**Elevación en dark mode:**

```
Light mode — elevación con sombras:
  Level 0: bg-white
  Level 1: bg-white + shadow-sm
  Level 2: bg-white + shadow-md
  Level 3: bg-white + shadow-lg

Dark mode — elevación con superficies más claras:
  Level 0: #111827 (más oscuro)
  Level 1: #1F2937 (ligeramente más claro)
  Level 2: #374151 (más claro aún)
  Level 3: #4B5563 (el más claro)

  En dark mode, "más elevado" = más claro.
  Las sombras son invisibles sobre fondos oscuros.
```

### 8.4 Adaptación de Paletas a Diferentes Temas

```css
/* Implementación de temas con CSS */

/* Light (default) */
:root {
  --color-bg-default: #FFFFFF;
  --color-bg-subtle: #F9FAFB;
  --color-bg-muted: #F3F4F6;
  --color-text-primary: #111827;
  --color-text-secondary: #4B5563;
  --color-text-tertiary: #6B7280;
  --color-border: #E5E7EB;
  --color-primary: #2563EB;
  --color-primary-hover: #1D4ED8;
  --shadow-md: 0 4px 6px hsl(217 20% 20% / 0.08);
}

/* Dark */
[data-theme="dark"] {
  --color-bg-default: #111827;
  --color-bg-subtle: #1F2937;
  --color-bg-muted: #374151;
  --color-text-primary: #F9FAFB;
  --color-text-secondary: #D1D5DB;
  --color-text-tertiary: #9CA3AF;
  --color-border: #374151;
  --color-primary: #60A5FA;       /* aclarado para dark */
  --color-primary-hover: #93C5FD;
  --shadow-md: none;              /* sin sombras en dark */
}

/* Los componentes NO cambian: */
.card {
  background: var(--color-bg-default);
  border: 1px solid var(--color-border);
  color: var(--color-text-primary);
  box-shadow: var(--shadow-md);
}
/* → Funciona automáticamente en ambos temas */
```

---

## 9. Metodología de Diseño

### Paso 1: Definir Objetivos Visuales

```
Antes de elegir un solo color, responde:

  1. ¿Qué personalidad debe transmitir el producto?
     → Profesional, amigable, premium, técnico, creativo

  2. ¿Qué acción principal debe destacar?
     → Comprar, registrarse, crear, explorar

  3. ¿Tiene branding existente?
     → SÍ → derivar paleta del brand color
     → NO → elegir basándose en personalidad + audiencia

  4. ¿Necesita dark mode?
     → SÍ → planificar tokens semánticos desde el inicio
     → NO → puedes empezar con valores directos (pero tokens es mejor)

  5. ¿Tiene contenido data-heavy?
     → SÍ → priorizar neutrales, color solo para datos clave
     → NO → más libertad cromática
```

### Paso 2: Crear Base Neutral

```
Primero: Los grises. Siempre.

  1. Elegir temperatura: cool (azul) o warm (marrón)
     → Match con el hue del color primario

  2. Generar escala 50-900:
     neutral-50:  hsl(H, S%, 98%)   ← fondo sutil
     neutral-100: hsl(H, S%, 96%)
     neutral-200: hsl(H, S%, 90%)   ← bordes
     neutral-300: hsl(H, S%, 82%)
     neutral-400: hsl(H, S%, 64%)   ← placeholder
     neutral-500: hsl(H, S%, 46%)   ← metadata
     neutral-600: hsl(H, S%, 38%)   ← texto secundario
     neutral-700: hsl(H, S%, 26%)
     neutral-800: hsl(H, S%, 17%)   ← texto principal
     neutral-900: hsl(H, S%, 10%)   ← headings

     Donde H = hue del primario (ej: 217 para azul)
     y S = 5-15% (toque sutil, no gris puro)

  Los neutrales son el 80% de tu interfaz.
  Hazlos bien y todo lo demás se ve mejor.
```

### Paso 3: Definir Color Primario

```
  1. Elegir hue base según personalidad/brand
  2. Generar escala 50-900 (variar L%, ajustar S%)
  3. Verificar que 500 funciona como botón con texto blanco (≥ 4.5:1)
  4. Verificar que 50-100 funciona como fondo sutil
  5. Verificar que 700-900 funciona como texto sobre fondo claro

  Si el color de marca NO pasa contraste como botón:
  → Ajustar (oscurecer) para UI → mantener original solo en logo
  → O usar texto oscuro en lugar de blanco sobre el botón
```

### Paso 4: Añadir Acentos y Semánticos

```
  Accent (opcional):
  → Complementario o análogo al primario
  → Para badges, highlights, secondary features
  → Generar escala mínima (50, 100, 500, 600, 700)

  Semánticos (obligatorios):
  → Success: Verde (hue ~142)
  → Warning: Ámbar (hue ~45)
  → Error: Rojo (hue ~0)
  → Info: Azul (puede ser el primario o un azul diferente)
  → Generar escala mínima para cada uno (50, 100, 200, 500, 700, 900)
```

### Paso 5: Validar Contraste

```
Combinaciones obligatorias a validar:

  ☐ Texto principal (neutral-800) sobre bg default → ≥ 4.5:1
  ☐ Texto secundario (neutral-600) sobre bg default → ≥ 4.5:1
  ☐ Texto terciario (neutral-500) sobre bg default → ≥ 4.5:1
  ☐ Texto blanco sobre primary-500 → ≥ 4.5:1
  ☐ Texto blanco sobre primary-600 (hover) → ≥ 4.5:1
  ☐ Texto error-700 sobre error-50 → ≥ 4.5:1
  ☐ Texto warning-700 sobre warning-50 → ≥ 4.5:1
  ☐ Texto success-700 sobre success-50 → ≥ 4.5:1
  ☐ Primary-500 link text sobre bg default → ≥ 4.5:1
  ☐ Focus ring (primary-200) visible sobre bg → ≥ 3:1

  Herramientas: color.review, WebAIM Contrast Checker,
  Stark (Figma plugin), Chrome DevTools Contrast
```

### Paso 6: Iterar con Feedback

```
  1. Aplicar paleta a 3-5 pantallas clave
  2. Verificar en dispositivos reales (mobile + desktop)
  3. Probar con usuarios: "¿Qué es lo más importante aquí?"
  4. Verificar con simuladores de daltonismo
  5. Revisar en luz directa (outdoor) y en cuarto oscuro
  6. Ajustar saturación si colores "queman" en pantalla
  7. Documentar decisiones y tokens finales
```

---

## 10. Implementación Práctica

### 10.1 Sistema Completo en CSS

```css
/* ═══════════════════════════════════════════════════════
   COLOR SYSTEM — Design Tokens + Implementation
   ═══════════════════════════════════════════════════════ */

:root {
  /* ── Primitives: Neutrals (cool gray, hue 217) ── */
  --gray-0:   hsl(0, 0%, 100%);
  --gray-50:  hsl(217, 20%, 98%);
  --gray-100: hsl(217, 16%, 96%);
  --gray-200: hsl(217, 14%, 90%);
  --gray-300: hsl(217, 12%, 82%);
  --gray-400: hsl(217, 10%, 64%);
  --gray-500: hsl(217, 10%, 46%);
  --gray-600: hsl(217, 12%, 38%);
  --gray-700: hsl(217, 16%, 26%);
  --gray-800: hsl(217, 19%, 17%);
  --gray-900: hsl(217, 22%, 10%);

  /* ── Primitives: Primary (blue) ── */
  --blue-50:  hsl(214, 100%, 97%);
  --blue-100: hsl(214, 95%, 93%);
  --blue-200: hsl(214, 94%, 86%);
  --blue-300: hsl(214, 93%, 74%);
  --blue-400: hsl(217, 91%, 60%);
  --blue-500: hsl(217, 91%, 53%);
  --blue-600: hsl(221, 83%, 45%);
  --blue-700: hsl(224, 76%, 38%);
  --blue-800: hsl(226, 71%, 30%);
  --blue-900: hsl(224, 64%, 20%);

  /* ── Primitives: Success (green) ── */
  --green-50:  hsl(142, 72%, 96%);
  --green-100: hsl(141, 69%, 90%);
  --green-200: hsl(141, 63%, 78%);
  --green-500: hsl(142, 71%, 45%);
  --green-700: hsl(142, 64%, 28%);
  --green-900: hsl(144, 61%, 15%);

  /* ── Primitives: Warning (amber) ── */
  --amber-50:  hsl(48, 96%, 95%);
  --amber-100: hsl(48, 96%, 89%);
  --amber-200: hsl(48, 90%, 75%);
  --amber-500: hsl(45, 93%, 47%);
  --amber-700: hsl(32, 95%, 30%);
  --amber-900: hsl(28, 80%, 18%);

  /* ── Primitives: Error (red) ── */
  --red-50:  hsl(0, 86%, 97%);
  --red-100: hsl(0, 93%, 92%);
  --red-200: hsl(0, 90%, 82%);
  --red-500: hsl(0, 84%, 60%);
  --red-700: hsl(0, 74%, 35%);
  --red-900: hsl(0, 63%, 20%);

  /* ═══════ Semantic Tokens: Light Theme ═══════ */

  /* Backgrounds */
  --color-bg-default:  var(--gray-0);
  --color-bg-subtle:   var(--gray-50);
  --color-bg-muted:    var(--gray-100);
  --color-bg-emphasis: var(--gray-900);

  /* Text */
  --color-text-primary:   var(--gray-900);
  --color-text-secondary: var(--gray-600);
  --color-text-tertiary:  var(--gray-500);
  --color-text-disabled:  var(--gray-400);
  --color-text-inverse:   var(--gray-0);

  /* Borders */
  --color-border-default: var(--gray-200);
  --color-border-strong:  var(--gray-300);
  --color-border-focus:   var(--blue-500);

  /* Primary */
  --color-primary:         var(--blue-500);
  --color-primary-hover:   var(--blue-600);
  --color-primary-active:  var(--blue-700);
  --color-primary-subtle:  var(--blue-50);
  --color-primary-text:    var(--blue-700);

  /* Success */
  --color-success:         var(--green-500);
  --color-success-subtle:  var(--green-50);
  --color-success-border:  var(--green-200);
  --color-success-text:    var(--green-700);

  /* Warning */
  --color-warning:         var(--amber-500);
  --color-warning-subtle:  var(--amber-50);
  --color-warning-border:  var(--amber-200);
  --color-warning-text:    var(--amber-700);

  /* Error */
  --color-error:           var(--red-500);
  --color-error-subtle:    var(--red-50);
  --color-error-border:    var(--red-200);
  --color-error-text:      var(--red-700);

  /* Shadows */
  --shadow-sm: 0 1px 2px hsl(217 20% 20% / 0.05);
  --shadow-md: 0 4px 6px -1px hsl(217 20% 20% / 0.07),
               0 2px 4px -2px hsl(217 20% 20% / 0.05);
  --shadow-lg: 0 10px 15px -3px hsl(217 20% 20% / 0.08),
               0 4px 6px -4px hsl(217 20% 20% / 0.04);

  /* Overlay */
  --color-overlay: hsl(217 20% 10% / 0.5);
}

/* ═══════ Dark Theme ═══════ */
[data-theme="dark"] {
  --color-bg-default:  var(--gray-900);
  --color-bg-subtle:   var(--gray-800);
  --color-bg-muted:    var(--gray-700);
  --color-bg-emphasis: var(--gray-50);

  --color-text-primary:   var(--gray-50);
  --color-text-secondary: var(--gray-400);
  --color-text-tertiary:  var(--gray-500);
  --color-text-disabled:  var(--gray-600);
  --color-text-inverse:   var(--gray-900);

  --color-border-default: var(--gray-700);
  --color-border-strong:  var(--gray-600);

  --color-primary:        var(--blue-400);
  --color-primary-hover:  var(--blue-300);
  --color-primary-active: var(--blue-200);
  --color-primary-subtle: hsl(217, 50%, 15%);
  --color-primary-text:   var(--blue-300);

  --color-success-subtle: hsl(142, 40%, 12%);
  --color-success-text:   var(--green-200);
  --color-warning-subtle: hsl(45, 40%, 12%);
  --color-warning-text:   var(--amber-200);
  --color-error-subtle:   hsl(0, 40%, 12%);
  --color-error-text:     var(--red-200);

  --shadow-sm: none;
  --shadow-md: none;
  --shadow-lg: none;
  --color-overlay: hsl(0 0% 0% / 0.6);
}
```

### 10.2 Componentes con Tokens

```css
/* ═══════ Componentes usando el sistema ═══════ */

/* Base */
body {
  background-color: var(--color-bg-default);
  color: var(--color-text-primary);
}

/* Card */
.card {
  background: var(--color-bg-default);
  border: 1px solid var(--color-border-default);
  border-radius: 8px;
  padding: 24px;
  box-shadow: var(--shadow-md);
}

/* Button Primary */
.btn-primary {
  background: var(--color-primary);
  color: var(--color-text-inverse);
  border: none;
  padding: 12px 20px;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: background 150ms ease;
}
.btn-primary:hover { background: var(--color-primary-hover); }
.btn-primary:active { background: var(--color-primary-active); }
.btn-primary:focus-visible {
  outline: 3px solid var(--blue-200);
  outline-offset: 2px;
}
.btn-primary:disabled {
  background: var(--color-bg-muted);
  color: var(--color-text-disabled);
  cursor: not-allowed;
}

/* Button Secondary */
.btn-secondary {
  background: transparent;
  color: var(--color-primary);
  border: 1px solid var(--color-primary);
  padding: 12px 20px;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
}
.btn-secondary:hover {
  background: var(--color-primary-subtle);
}

/* Alert */
.alert {
  padding: 16px;
  border-radius: 8px;
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.alert--success {
  background: var(--color-success-subtle);
  border: 1px solid var(--color-success-border);
  color: var(--color-success-text);
}

.alert--warning {
  background: var(--color-warning-subtle);
  border: 1px solid var(--color-warning-border);
  color: var(--color-warning-text);
}

.alert--error {
  background: var(--color-error-subtle);
  border: 1px solid var(--color-error-border);
  color: var(--color-error-text);
}

/* Input */
.input {
  background: var(--color-bg-default);
  border: 1px solid var(--color-border-default);
  color: var(--color-text-primary);
  padding: 12px 16px;
  border-radius: 8px;
  font-size: 16px;
  transition: border-color 150ms ease;
}
.input::placeholder { color: var(--color-text-disabled); }
.input:hover { border-color: var(--color-border-strong); }
.input:focus {
  border-color: var(--color-border-focus);
  outline: 3px solid var(--blue-100);
  outline-offset: 0;
}
.input--error {
  border-color: var(--color-error);
  background: var(--color-error-subtle);
}

/* Badge */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 2px 10px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
}
.badge--success {
  background: var(--color-success-subtle);
  color: var(--color-success-text);
}
.badge--error {
  background: var(--color-error-subtle);
  color: var(--color-error-text);
}
.badge--primary {
  background: var(--color-primary-subtle);
  color: var(--color-primary-text);
}
```

### 10.3 Integración con Tailwind

```javascript
// tailwind.config.js — Custom color system
module.exports = {
  theme: {
    colors: {
      // Primitives
      white: '#FFFFFF',
      black: '#000000',
      transparent: 'transparent',

      // Neutrals
      gray: {
        50:  'hsl(217, 20%, 98%)',
        100: 'hsl(217, 16%, 96%)',
        200: 'hsl(217, 14%, 90%)',
        300: 'hsl(217, 12%, 82%)',
        400: 'hsl(217, 10%, 64%)',
        500: 'hsl(217, 10%, 46%)',
        600: 'hsl(217, 12%, 38%)',
        700: 'hsl(217, 16%, 26%)',
        800: 'hsl(217, 19%, 17%)',
        900: 'hsl(217, 22%, 10%)',
      },

      // Primary
      primary: {
        50:  'hsl(214, 100%, 97%)',
        100: 'hsl(214, 95%, 93%)',
        200: 'hsl(214, 94%, 86%)',
        300: 'hsl(214, 93%, 74%)',
        400: 'hsl(217, 91%, 60%)',
        500: 'hsl(217, 91%, 53%)',
        600: 'hsl(221, 83%, 45%)',
        700: 'hsl(224, 76%, 38%)',
        800: 'hsl(226, 71%, 30%)',
        900: 'hsl(224, 64%, 20%)',
      },

      // Semantic
      success: {
        50:  'hsl(142, 72%, 96%)',
        200: 'hsl(141, 63%, 78%)',
        500: 'hsl(142, 71%, 45%)',
        700: 'hsl(142, 64%, 28%)',
      },
      warning: {
        50:  'hsl(48, 96%, 95%)',
        200: 'hsl(48, 90%, 75%)',
        500: 'hsl(45, 93%, 47%)',
        700: 'hsl(32, 95%, 30%)',
      },
      error: {
        50:  'hsl(0, 86%, 97%)',
        200: 'hsl(0, 90%, 82%)',
        500: 'hsl(0, 84%, 60%)',
        700: 'hsl(0, 74%, 35%)',
      },
    },
  },
}
```

```html
<!-- Tailwind: Componentes con el sistema de color -->

<!-- Card -->
<div class="bg-white border border-gray-200 rounded-lg p-6 shadow-md
            dark:bg-gray-900 dark:border-gray-700">
  <h3 class="text-gray-900 dark:text-gray-50 font-semibold">Card Title</h3>
  <p class="text-gray-600 dark:text-gray-400 mt-2">Description text.</p>
</div>

<!-- Button Primary -->
<button class="bg-primary-500 hover:bg-primary-600 active:bg-primary-700
               text-white font-semibold px-5 py-3 rounded-lg
               focus-visible:outline-3 focus-visible:outline-primary-200
               disabled:bg-gray-200 disabled:text-gray-400
               transition-colors">
  Primary Action
</button>

<!-- Alert Error -->
<div class="bg-error-50 border border-error-200 text-error-700
            rounded-lg p-4 flex items-start gap-3">
  <span>✗</span>
  <p>Payment failed. Please try again.</p>
</div>

<!-- Badge -->
<span class="inline-flex items-center gap-1.5 px-2.5 py-0.5
             rounded-full text-xs font-medium
             bg-success-50 text-success-700">
  ● Active
</span>
```

### 10.4 HSL para Escalabilidad Programática

```css
/* Generar una escala completa desde UN valor base */

:root {
  /* Define el hue y saturación base */
  --primary-h: 217;
  --primary-s: 91%;

  /* Genera toda la escala variando solo Lightness */
  --primary-50:  hsl(var(--primary-h), 100%, 97%);
  --primary-100: hsl(var(--primary-h), 95%, 93%);
  --primary-200: hsl(var(--primary-h), 94%, 86%);
  --primary-300: hsl(var(--primary-h), 93%, 74%);
  --primary-400: hsl(var(--primary-h), var(--primary-s), 60%);
  --primary-500: hsl(var(--primary-h), var(--primary-s), 53%);
  --primary-600: hsl(var(--primary-h), 83%, 45%);
  --primary-700: hsl(var(--primary-h), 76%, 38%);
  --primary-800: hsl(var(--primary-h), 71%, 30%);
  --primary-900: hsl(var(--primary-h), 64%, 20%);
}

/* Cambiar de azul a púrpura: cambiar UN valor */
:root {
  --primary-h: 270;   /* de 217 (azul) a 270 (púrpura) */
  /* TODA la escala se regenera automáticamente */
}
```

> **Esto es el poder de HSL:** Puedes "retheme" todo tu producto cambiando un solo número — el hue. Saturation y lightness se mantienen, las relaciones de contraste se preservan.

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Al empezar | ¿Tengo un sistema de color definido? | Definir primario + neutrales + semánticos como tokens |
| Al elegir primary | ¿Pasa contraste AA como botón con texto blanco? | Verificar ≥ 4.5:1 — ajustar si no |
| Al elegir neutrales | ¿Grises puros o con tinte? | Tinte del hue primario (cool o warm grays) |
| Al crear escala | ¿Tengo pasos 50-900? | Generar con HSL variando lightness |
| Al definir semánticos | ¿Green/amber/red cubren todos los estados? | Generar escala mínima (50, 200, 500, 700) por cada uno |
| Al usar color | ¿Este color cumple una función? | Si no → eliminarlo, usar neutral |
| Al verificar accesibilidad | ¿Todo texto cumple AA? | Probar TODAS las combinaciones texto/fondo |
| Al diseñar dark mode | ¿Invertí o rediseñé? | Rediseñar: aclarar primarios, reducir saturación, elevar con surface |
| Al implementar | ¿Hardcoded o tokens? | Siempre tokens (3 capas: primitivo → semántico → componente) |
| Al comunicar con devs | ¿Comparten la misma fuente de verdad? | Design tokens sincronizan Figma ↔ código |

**Cheat Sheet de colores:**

```
  Cuántos colores necesito como mínimo:
  ─────────────────────────────────────
  1 Primary (azul, 10 steps)
  1 Neutral (grises, 10 steps)
  1 Success (verde, 6 steps)
  1 Warning (ámbar, 6 steps)
  1 Error (rojo, 6 steps)
  = 5 hues, ~42 tokens → suficiente para el 95% de productos.

  Distribución visual:
  ─────────────────────
  80% Neutral (fondos, texto, bordes)
  15% Primary (CTAs, links, activos)
   5% Semánticos (estados, feedback)

  Cuándo agregar un accent color:
  ─────────────────────────────────
  → Cuando primary no es suficiente para diferenciar categorías
  → Cuando hay features secundarias que necesitan identidad propia
  → Máximo 1 accent, máximo 5% de la interfaz
```

> **Mantra del color:** El color es una herramienta de comunicación, no de decoración. Cada color en tu interfaz debe responder la pregunta: "¿Qué función cumple?". Si no tiene función, no merece estar ahí. Un producto con 5 colores bien usados se ve mejor que uno con 20 colores sin sistema.
