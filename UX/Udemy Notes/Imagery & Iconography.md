# Imagery & Iconography — Módulo Completo

---

## 1. Introducción a Imagery & Iconography

### 1.1 Qué es Imagery y qué es Iconography

- **Intuición:** Las imágenes son fotografías, ilustraciones y gráficos que cuentan una historia o crean contexto emocional. Los íconos son símbolos pequeños y simplificados que representan acciones, objetos o conceptos de un vistazo. Juntos, son el vocabulario visual de tu producto.
- **Estructura formal:** *Imagery* abarca todo recurso visual de gran formato (fotografía, ilustración, renders) que complementa o sustituye texto para comunicar contexto, emoción o narrativa. *Iconography* es el sistema de símbolos gráficos estandarizados que representan acciones, estados u objetos dentro de la interfaz.
- **Aplicación práctica:** Una hero image vende la visión del producto. Un ícono de papelera comunica "eliminar" sin palabras. Ambos reducen la carga cognitiva — el cerebro procesa imágenes 60,000x más rápido que texto.

### 1.2 Rol en UX/UI

```
Funciones de imagery e iconography:

  1. COMUNICACIÓN VISUAL
  ┌─────────────────────────────────────────────┐
  │  Sin visual:                                │
  │  "Arrastra el archivo aquí para subirlo"    │
  │                                             │
  │  Con visual:                                │
  │  ┌───────────────────────┐                  │
  │  │    ☁️ ↑                │                  │
  │  │  Arrastra aquí        │                  │
  │  └───────────────────────┘                  │
  │  → El ícono comunica en milisegundos.       │
  └─────────────────────────────────────────────┘

  2. REFUERZO DE CONTENIDO
  Texto + imagen = comprensión superior.
  El visual no reemplaza el texto — lo amplifica.

  3. REDUCCIÓN DE CARGA COGNITIVA
  ┌──────────────────────────────────┐
  │  Sin íconos:                     │
  │  Home  Search  Cart  Profile     │
  │                                  │
  │  Con íconos:                     │
  │  🏠 Home  🔍 Search  🛒 Cart  👤 │
  │                                  │
  │  → Escaneo visual instantáneo.   │
  └──────────────────────────────────┘
```

### 1.3 Decoración vs Funcionalidad

| Aspecto | Decorativo | Funcional |
|---|---|---|
| **Propósito** | "Se ve bonito" | Comunica, guía, explica |
| **Se puede eliminar?** | Sí, sin perder información | No — el usuario pierde contexto |
| **Ejemplo** | Imagen abstracta de fondo | Ícono de alerta en un form |
| **Aceptable?** | Moderadamente (si no distrae) | Siempre necesario |
| **Riesgo** | Ruido visual, distracción | Ninguno si está bien diseñado |

```
Test rápido: ¿Es funcional o decorativo?

  Pregunta: "Si quito este visual, ¿el usuario pierde
  información o la capacidad de completar una tarea?"

  SÍ → Funcional (mantenerlo, optimizarlo)
  NO → Decorativo (evaluar si suma o resta)
```

> **Regla:** Lo funcional es obligatorio. Lo decorativo es un lujo — úsalo con intención, no por defecto.

### 1.4 Cuándo Usar Imágenes vs Íconos

| Necesidad | Imagen | Ícono |
|---|---|---|
| Transmitir emoción / narrativa | ✅ | ❌ |
| Mostrar un producto real | ✅ | ❌ |
| Indicar una acción (editar, eliminar) | ❌ | ✅ |
| Representar categorías | ❌ | ✅ |
| Explicar un concepto complejo | ✅ (ilustración) | ❌ |
| Navegación | ❌ | ✅ |
| Vaciar espacio (empty state) | ✅ (ilustración) | ❌ |
| Estado del sistema (success/error) | ❌ | ✅ |
| Branding / hero section | ✅ | ❌ |
| Acompañar un label | ❌ | ✅ |

---

## 2. Fundamentos de Imagery

### 2.1 Tipos de Imágenes

**Fotografía (realista):**

```
Características:
  - Realismo, autenticidad, credibilidad
  - Transmite emoción humana directa
  - Peso visual alto

Mejor para:
  - E-commerce (producto real)
  - Landing pages (personas reales)
  - Testimoniales
  - Contexto de uso del producto

Riesgo:
  - Stock genérico = percepción falsa
  - Imágenes pesadas = bad performance
```

**Ilustraciones:**

```
Características:
  - Estilizadas, controladas, flexibles
  - Pueden simplificar conceptos complejos
  - Consistencia de estilo fácil

Mejor para:
  - Onboarding
  - Empty states
  - Explicaciones de features
  - Error pages (404, 500)
  - Branding diferenciador

Estilos comunes:
  - Flat (2D, colores sólidos)
  - Isométrico (pseudo-3D)
  - Line art (contornos)
  - Orgánico (formas suaves)
  - Abstract (geometría, patterns)
```

**3D / Renders:**

```
Características:
  - Impactante, moderno, premium
  - Peso visual muy alto
  - Costoso de producir

Mejor para:
  - Landing pages premium
  - Productos físicos (showcase)
  - Tecnología, gaming
  - Branding diferenciador

Riesgo:
  - Lento de cargar
  - Puede envejecer rápido (tendencias)
  - Distracción si se abusa
```

**Abstract visuals:**

```
Características:
  - Formas, gradientes, texturas sin representación literal
  - Bajo en contenido informacional
  - Alto en tono emocional / branding

Mejor para:
  - Fondos de secciones
  - Headers decorativos
  - Branding atmosférico

Riesgo:
  - 100% decorativo — no comunica funcionalidad
  - Puede restar atención al contenido
```

### 2.2 Propósito de las Imágenes en Interfaces

| Propósito | Descripción | Ejemplo |
|---|---|---|
| **Contexto** | Situar al usuario en un escenario | Foto de un workspace para app de productividad |
| **Emoción** | Generar una respuesta emocional | Personas sonriendo en onboarding |
| **Explicación** | Clarificar un concepto o proceso | Ilustración de cómo funciona un feature |
| **Producto** | Mostrar lo que se vende/ofrece | Foto del producto en e-commerce |
| **Identidad** | Reforzar la marca | Ilustraciones con paleta y estilo de la marca |
| **Orientación** | Guiar al usuario | Ilustración en empty state con CTA |

### 2.3 Selección de Imágenes

**Checklist de selección:**

```
  ☐ RELEVANCIA — ¿La imagen tiene relación directa con el contenido?
    ❌ Foto de montaña para una app de finanzas (irrelevante)
    ✅ Foto de persona usando la app en contexto real

  ☐ CONSISTENCIA — ¿Se ve coherente con el resto del producto?
    ❌ Mezclar fotos B&W, ilustraciones coloridas y 3D renders
    ✅ Todas las ilustraciones usan el mismo estilo y paleta

  ☐ CALIDAD — ¿Resolución adecuada sin ser excesiva?
    ❌ Imágenes pixeladas o borrosas
    ❌ Imágenes de 5MB sin comprimir
    ✅ Imágenes nítidas, optimizadas (WebP, lazy loaded)

  ☐ DIVERSIDAD — ¿Representan a la audiencia real?
    ❌ Solo personas de un género/etnia/edad
    ✅ Diversidad auténtica, no forzada

  ☐ AUTENTICIDAD — ¿Se siente genuina o genérica?
    ❌ Stock de "gente de negocios sonriendo a cámara"
    ✅ Fotos naturales, in-context, no posadas
```

### 2.4 Problemas Comunes

```
Anti-patrón 1: "Stock Genérico"
  ┌─────────────────────────────────────┐
  │  [Foto de personas sonriendo en     │
  │   oficina genérica con laptops]     │
  │                                     │
  │  "Transform Your Business"          │
  └─────────────────────────────────────┘
  → Se ve igual que otros 10,000 sitios.
  → El usuario ignora automáticamente.
  → Zero diferenciación.

Anti-patrón 2: "Imagen sin propósito"
  ┌─────────────────────────────────────┐
  │  [Foto enorme de un paisaje]        │
  │                                     │
  │  Pricing: $9/mo $29/mo $99/mo      │
  └─────────────────────────────────────┘
  → La imagen no tiene relación con el contenido.
  → Distrae del propósito (elegir un plan).

Anti-patrón 3: "Frankenstein visual"
  ┌─────────────────────────────────────┐
  │  [Ilustración flat] + [Foto real]   │
  │  + [3D render] + [Ícono outline]    │
  └─────────────────────────────────────┘
  → Mezcla de estilos que no tienen coherencia.
  → Se siente desorganizado y amateur.
```

---

## 3. Fundamentos de Iconography

### 3.1 Qué es un Ícono en UX/UI

- **Intuición:** Un ícono es un símbolo visual comprimido — transmite una idea completa en un cuadrado de 24×24 píxeles. Es el atajo visual más eficiente que existe en interfaces.
- **Estructura formal:** Un ícono en UI es una representación gráfica simplificada de un objeto, acción o concepto, diseñada para ser reconocida instantáneamente a tamaños pequeños (16-32px) y funcionar como parte integral del sistema visual.

### 3.2 Características de un Buen Ícono

```
Las 4 C del ícono efectivo:

  1. CLARIDAD
     ¿Se entiende qué representa sin texto?
     ✅ 🏠 = Home (universalmente reconocido)
     ❌ 🔧 = Settings? Tools? Fix? (ambiguo)

  2. CONSISTENCIA
     ¿Todos los íconos tienen el mismo estilo?
     ✅ Todos outline, 2px stroke, 24px, esquinas redondeadas
     ❌ Algunos filled, algunos outline, diferentes tamaños

  3. COMPACTEZ (Simplicidad)
     ¿Funciona a 16px sin perder legibilidad?
     ✅ Formas simples, pocos detalles
     ❌ Demasiados trazos, detalles que se pierden al reducir

  4. CONVENCIÓN
     ¿Usa metáforas que los usuarios ya conocen?
     ✅ 🗑️ = Eliminar (metáfora de papelera)
     ❌ ⬡ = Eliminar (inventado, no convencional)
```

**Test de calidad de un ícono:**

```
  ☐ ¿Se reconoce en 1 segundo?
  ☐ ¿Se ve nítido a 16px? ¿A 24px? ¿A 32px?
  ☐ ¿Funciona en blanco sobre oscuro Y negro sobre claro?
  ☐ ¿Tiene el mismo peso visual que los otros íconos del set?
  ☐ ¿Tiene significado sin leer el label?
  ☐ ¿Es distinguible de otros íconos en el mismo contexto?
```

### 3.3 Tipos de Íconos

| Tipo | Función | Ejemplos | Dónde |
|---|---|---|---|
| **Sistema / UI** | Acciones y controles de la interfaz | Close ✕, Chevron ›, Menu ☰, Check ✓ | Headers, modals, forms |
| **Navegación** | Identificar secciones y destinos | Home, Search, Profile, Settings | Tab bars, sidebars, navbars |
| **Acción** | Indicar qué puede hacer el usuario | Edit, Delete, Share, Download, Copy | Toolbars, menus, botones |
| **Estado** | Comunicar feedback del sistema | Success ✓, Error ✕, Warning ⚠, Info ℹ | Alerts, badges, toasts |
| **Ilustrativos** | Decorar o reforzar visualmente | Categorías, features, empty states | Cards, onboarding, marketing |

```
Mapa de uso:

  ┌──────────────────────────────────────────────────────────┐
  │  [☰ Menu]        App Name            [🔔] [👤]          │  ← Sistema + Nav
  ├──────────────────────────────────────────────────────────┤
  │           │                                              │
  │  📊 Dash  │   ┌──────────────────────────────────┐      │
  │  👥 Users │   │  ✓ Record saved successfully     │      │  ← Estado
  │  📋 Tasks │   └──────────────────────────────────┘      │
  │  ⚙ Config │                                              │  ← Navegación
  │           │   ┌────────────────┐ ┌────────────────┐     │
  │           │   │  [✏️ Edit]      │ │  [🗑️ Delete]   │     │  ← Acción
  │           │   └────────────────┘ └────────────────┘     │
  │           │                                              │
  └──────────────────────────────────────────────────────────┘
```

---

## 4. Estilos de Iconografía

### 4.1 Estilos Principales

**Line (Outline):**

```
Características:
  - Trazos abiertos, relleno vacío
  - Ligero, aireado, moderno
  - Stroke uniforme (1.5px, 2px)

  Ejemplo conceptual:
  ┌──────┐      ╭──╮
  │      │      │  │       ○
  │      │      ╰──╯      /│\
  └──────┘                 / \
   Archivo    Carpeta    Persona

  Mejor para:
  - UI moderna, limpia
  - Apps con densidad media-baja
  - Cuando el ícono acompaña texto

  Riesgo:
  - Menor visibilidad a tamaños muy pequeños (< 16px)
  - Puede verse débil en interfaces densas
```

**Filled (Sólido):**

```
Características:
  - Formas sólidas rellenas
  - Mayor peso visual
  - Mejor visibilidad a tamaños pequeños

  Ejemplo conceptual:
  ████████      ████       ●
  ████████      ████      ███
  ████████      ████      ███
                           █
   Archivo    Carpeta    Persona

  Mejor para:
  - Tab bars (ítem activo)
  - Interfaces densas (dashboards)
  - Cuando el ícono necesita destacar
  - Tamaños pequeños (16px)

  Riesgo:
  - Puede sentirse pesado si se usa en todo
```

**Duotone:**

```
Características:
  - Dos tonos del mismo color (o dos colores)
  - Un plano sólido + un plano semitransparente
  - Moderno, con profundidad

  Mejor para:
  - Íconos ilustrativos (features, categorías)
  - Marketing, landing pages
  - Onboarding

  Riesgo:
  - Más complejo de mantener consistente
  - No ideal para UI funcional densa
```

**Glyph:**

```
Características:
  - Ícono dentro de un contenedor (círculo, cuadrado)
  - El contenedor da énfasis y uniformidad
  - Todas las formas se estandarizan

  Ejemplo:
  ┌─────┐  ┌─────┐  ┌─────┐
  │ (🏠) │  │ (🔍) │  │ (👤) │    Íconos dentro de círculos
  └─────┘  └─────┘  └─────┘

  Mejor para:
  - Badges de categorías
  - Feature grids
  - Status indicators
```

### 4.2 Elegir un Estilo Consistente

```
Decisión de estilo:

  ¿Qué tipo de producto?
  ├── SaaS / Dashboard → Line (outline) con filled para activos
  ├── E-commerce       → Line o filled, consistente
  ├── App mobile       → Line (inactive) + Filled (active) en tab bar
  ├── Landing page     → Duotone o ilustrativos (más expresivos)
  └── Herramienta pro  → Filled (mejor visibilidad en densidad alta)

  Regla de oro: UN estilo principal en todo el producto.

  Excepción aceptada:
  - Tab bar: outline (inactivo) → filled (activo)
    ┌─────────────────────────────────────┐
    │  🏠      🔍      ➕      ♡     👤    │
    │ Home  Search   Add   Favs  Profile │
    │ ████                               │  ← Home es filled (activo)
    │ (el resto son outline)             │
    └─────────────────────────────────────┘
```

### 4.3 Tamaños y Grid de Íconos

```
Tamaños estándar:

  16px ─── Inline con texto pequeño (captions, metadata)
           Mínimo para íconos de UI funcional

  20px ─── Dentro de botones, junto a labels

  24px ─── ★ Tamaño principal (nav, toolbars, listas)
           El estándar de la industria

  32px ─── Íconos de categoría, features
           En contextos más espaciosos

  40px ─── Íconos ilustrativos
           Empty states, onboarding steps

  48px+ ── Íconos decorativos o de marketing
           Feature showcases, hero sections


Grid del ícono (canvas):
  ┌────────────────────────┐
  │ ┌──────────────────┐   │
  │ │                  │   │  Safe area (padding interno 2px)
  │ │    Ícono aquí    │   │
  │ │                  │   │  El ícono debe respetar el padding
  │ └──────────────────┘   │  para uniformidad entre íconos
  │    2px padding (24px)  │
  └────────────────────────┘
     24px × 24px canvas

  Regla: Todos los íconos deben diseñarse en el mismo
  canvas con el mismo safe area, aunque no llenen todo
  el espacio. Esto garantiza peso visual uniforme.
```

### 4.4 Stroke, Peso Visual y Consistencia

```
Stroke width consistente:

  ❌ Inconsistente:
  Ícono A: 1px stroke     │─│
  Ícono B: 2px stroke     │══│
  Ícono C: 1.5px stroke   │─═│
  → Se ven de "familias" diferentes.

  ✅ Consistente:
  Todos: 1.5px stroke (para 24px canvas)
  → Se ven como parte del mismo sistema.

  Proporción recomendada:
  Canvas 16px → stroke 1px
  Canvas 24px → stroke 1.5px o 2px
  Canvas 32px → stroke 2px

Peso visual uniforme:

  ❌ Peso visual desigual:
  ┌───┐  ┌───┐  ┌───┐
  │ ◯ │  │███│  │ · │    ← El filled "grita" vs los otros
  └───┘  └───┘  └───┘

  ✅ Peso visual balanceado:
  ┌───┐  ┌───┐  ┌───┐
  │ ◯ │  │ □ │  │ △ │    ← Todos pesan visualmente igual
  └───┘  └───┘  └───┘

  Test: Entrecerrar los ojos mirando los íconos en fila.
  ¿Todos se ven del mismo "peso"? → Consistente.
  ¿Uno destaca mucho más que otros? → Ajustar.
```

---

## 5. Sistema de Íconos

### 5.1 Creación de una Librería de Íconos

```
Estructura de un icon library:

  icons/
  ├── navigation/
  │   ├── home.svg
  │   ├── search.svg
  │   ├── menu.svg
  │   ├── arrow-left.svg
  │   ├── arrow-right.svg
  │   └── chevron-down.svg
  ├── action/
  │   ├── edit.svg
  │   ├── delete.svg
  │   ├── share.svg
  │   ├── download.svg
  │   ├── copy.svg
  │   └── plus.svg
  ├── status/
  │   ├── check-circle.svg
  │   ├── alert-triangle.svg
  │   ├── x-circle.svg
  │   └── info-circle.svg
  ├── media/
  │   ├── image.svg
  │   ├── video.svg
  │   ├── music.svg
  │   └── file.svg
  └── social/
      ├── twitter.svg
      ├── github.svg
      └── linkedin.svg
```

### 5.2 Naming Conventions

```
Formato recomendado: [objeto]-[variante]-[modificador]

  ✅ Buenos nombres:
  arrow-left.svg
  arrow-right.svg
  arrow-up.svg
  arrow-down.svg
  check-circle.svg
  check-square.svg
  alert-triangle.svg
  user-plus.svg
  user-minus.svg
  file-text.svg
  file-image.svg

  ❌ Malos nombres:
  icon1.svg
  leftarrow.svg
  Arrow_Left.svg
  new-icon-final-v3.svg
  check (1).svg

  Reglas:
  - Kebab-case siempre (arrow-left, no arrowLeft)
  - Nombre descriptivo del OBJETO, no del uso (check, no success)
  - Sin prefijos redundantes (no icon-arrow-left)
  - Variantes con sufijo claro (-circle, -square, -outline, -filled)
```

### 5.3 Reglas de Uso

```
Reglas del sistema de íconos:

  1. TAMAÑO: Siempre en múltiplos definidos (16, 20, 24, 32)
     → Nunca 18px, 22px, 27px (fuera del sistema)

  2. COLOR: Hereda del contexto o usa tokens de color del sistema
     → Nunca hardcoded (#333, #blue)
     → Usa currentColor en SVG para heredar del padre

  3. ESTILO: Un estilo principal (ej: outline 1.5px)
     → Nunca mezclar outline y filled en el mismo contexto
     → Excepción: active vs inactive en tab bar

  4. ALINEACIÓN: Siempre centrado vertical con el texto
     → Usa align-items: center en flex/grid

  5. SPACING: Distancia consistente entre ícono y texto
     → 8px gap (standard)
     → 4px gap (compacto)

  6. ACCESIBILIDAD: Siempre aria-label o texto acompañante
     → Ícono solo → aria-label obligatorio
     → Ícono + texto → aria-hidden="true" en el ícono
```

### 5.4 Escalabilidad dentro de un Design System

```
Niveles de escalabilidad:

  Nivel 1: Íconos individuales (SVG files)
  → Archivos SVG optimizados, versionados

  Nivel 2: Sprite o componente
  → React: <Icon name="arrow-left" size={24} />
  → Figma: Componente con variants (style, size)

  Nivel 3: Design tokens
  → --icon-size-sm: 16px;
  → --icon-size-md: 24px;
  → --icon-size-lg: 32px;
  → --icon-color-default: var(--color-text-secondary);
  → --icon-color-active: var(--color-primary);

  Nivel 4: Documentación
  → Catálogo visual de todos los íconos
  → Guía de uso (cuándo usar cada uno)
  → Reglas de contribución (cómo agregar nuevos)
```

```
Componente React de ejemplo:

  <Icon
    name="check-circle"       // qué ícono
    size="md"                  // 24px (token)
    color="success"            // var(--color-success)
    aria-label="Completado"    // accesibilidad
  />

  Props:
  - name: string → mapea al archivo SVG
  - size: 'sm' | 'md' | 'lg' → 16, 24, 32
  - color: string → token de color del sistema
  - aria-label: string → para screen readers
```

---

## 6. Uso de Imágenes en UI

### 6.1 Hero Images

```
Hero image — el visual principal de una página:

  ┌──────────────────────────────────────────────────────┐
  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░  Build Better Products  ░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░                         ░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░  Subtitle text here     ░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░  [ Get Started ]        ░░░░░░░░░░░░░░░░░░░░│
  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
  └──────────────────────────────────────────────────────┘
  (░ = imagen de fondo)

  Reglas:
  - Texto sobre imagen → overlay oscuro o gradiente obligatorio
  - Contraste mínimo 4.5:1 entre texto y el punto más claro de la imagen
  - Imagen comprimida y responsiva (srcset para móvil)
  - Object-fit: cover para mantener proporción
  - Lazy load NO en hero (es above-the-fold → cargar inmediato)
```

```css
/* Hero image con overlay */
.hero {
  position: relative;
  min-height: 600px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.hero__image {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hero__overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    to bottom,
    hsl(0 0% 0% / 0.5),
    hsl(0 0% 0% / 0.7)
  );
}

.hero__content {
  position: relative; /* encima del overlay */
  z-index: 1;
  color: white;
  text-align: center;
}
```

### 6.2 Thumbnails

```
Thumbnails — miniaturas representativas:

  ┌──────┐  ┌──────┐  ┌──────┐
  │ ████ │  │ ████ │  │ ████ │    Aspect ratios comunes:
  │ ████ │  │ ████ │  │ ████ │    - 1:1 (cuadrado) — avatars, grids
  │      │  │      │  │      │    - 16:9 — video, hero
  │Title │  │Title │  │Title │    - 4:3 — cards, articles
  │Desc  │  │Desc  │  │Desc  │    - 3:2 — fotografía
  └──────┘  └──────┘  └──────┘

  Reglas:
  - SIEMPRE mismo aspect ratio en un grid
  - object-fit: cover (nunca distorsionar)
  - Placeholder mientras carga (skeleton o color sólido)
  - Fallback si la imagen falla (ícono + fondo)
```

### 6.3 Avatares

```
Avatares — representación de usuario:

  Tamaños comunes:
  ●  24px — inline con texto (mentions, comments)
  ●  32px — listas, chat messages
  ●  40px — headers, cards
  ●  48px — perfiles en listas
  ●  64px — perfil de usuario
  ● 128px — página de perfil principal

  Fallbacks (cuando no hay foto):
  1. Iniciales sobre color → [JD] (generado del nombre)
  2. Ícono genérico        → [👤] (person outline)
  3. Default image         → [placeholder]

  ┌─────────────────────────────────────┐
  │  (JD) John Doe    →  foto uploaded  │
  │  (  ) Unknown     →  ícono genérico │
  │  (+3) 3 more      →  counter badge  │
  └─────────────────────────────────────┘

  Regla: SIEMPRE forma circular + border sutil para separar del fondo.
  border: 2px solid var(--color-bg-default);
```

### 6.4 Ilustraciones Explicativas

```
Casos de uso:

  Empty state:
  ┌──────────────────────────────────────┐
  │                                      │
  │        ┌──────────────┐              │
  │        │  ilustración │              │
  │        │  de búsqueda │              │
  │        │  sin result. │              │
  │        └──────────────┘              │
  │                                      │
  │     No results found                 │
  │     Try adjusting your search        │
  │     or filters.                      │
  │                                      │
  │     [ Clear Filters ]                │
  └──────────────────────────────────────┘

  Onboarding steps:
  ┌────────┐  ┌────────┐  ┌────────┐
  │[illust]│  │[illust]│  │[illust]│
  │        │  │        │  │        │
  │ Step 1 │  │ Step 2 │  │ Step 3 │
  │ Create │  │ Invite │  │ Start  │
  │ account│  │  team  │  │working │
  │[Next →]│  │[Next →]│  │[Done!] │
  └────────┘  └────────┘  └────────┘

  Error page (404):
  ┌──────────────────────────────────────┐
  │        ┌──────────────┐              │
  │        │  ilustración │              │
  │        │  divertida   │              │
  │        │  de "lost"   │              │
  │        └──────────────┘              │
  │                                      │
  │     Page not found                   │
  │     [ Back to Home ]                 │
  └──────────────────────────────────────┘
```

### 6.5 Balance entre Contenido e Imagen

```
Regla de proporción:

  ❌ Demasiada imagen, poco contenido:
  ┌──────────────────────────────────────┐
  │ ████████████████████████████████████ │
  │ ████████████████████████████████████ │
  │ ████████████████████████████████████ │
  │ ████████████████████████████████████ │
  │ ████████████████████████████████████ │
  │ small text here                      │
  └──────────────────────────────────────┘
  → La imagen domina, el contenido es irrelevante.

  ❌ Demasiado contenido, sin visual:
  ┌──────────────────────────────────────┐
  │ text text text text text text text   │
  │ text text text text text text text   │
  │ text text text text text text text   │
  │ text text text text text text text   │
  │ text text text text text text text   │
  │ text text text text text text text   │
  └──────────────────────────────────────┘
  → Muro de texto, sin respiro visual.

  ✅ Equilibrio:
  ┌──────────────────────────────────────┐
  │ ┌──────────┐                         │
  │ │  visual  │  Heading                │
  │ │          │  Body text describing   │
  │ └──────────┘  the feature clearly.   │
  │               [ CTA ]               │
  └──────────────────────────────────────┘
  → El visual complementa, el texto comunica.
```

---

## 7. Uso de Íconos en UI

### 7.1 Navegación

```
Tab bar (mobile):
┌──────────────────────────────────────────┐
│   🏠        🔍        ➕        ♡       👤 │
│  Home    Search     Add     Saved   Profile│
│  ████                                      │
└──────────────────────────────────────────┘
  ████ = indicador de activo (filled + color primario)
  El resto = outline + color neutral

Sidebar (desktop):
┌────────────┐
│ 📊 Dashboard│  ← activo: bg sutil + text primario + ícono filled
│ 👥 Users    │  ← inactivo: text secundario + ícono outline
│ 📋 Projects │
│ ⚙ Settings │
│             │
│ ▾ Collapse  │  ← collapsed: solo íconos (tooltip on hover)
└────────────┘

Breadcrumbs:
  🏠 > Category > Subcategory > Current
  Solo el home usa ícono — el resto usa texto.
```

### 7.2 Botones con Íconos

```
Patrones de botón + ícono:

  1. Ícono + Texto (más claro, preferido):
  [ 📥 Download ]    [ ✏️ Edit ]    [ 🗑️ Delete ]

  2. Solo ícono (requiere tooltip y aria-label):
  [ 📥 ]    [ ✏️ ]    [ 🗑️ ]
  ↑ tooltip: "Download"

  3. Texto + Ícono trailing (indica dirección/acción):
  [ Next → ]    [ Open ↗ ]    [ Expand ▾ ]

Reglas:
  - Si hay espacio → SIEMPRE usar ícono + texto
  - Solo-ícono → SOLO si el ícono es universalmente reconocido
    (close ✕, search 🔍, menu ☰, plus ➕)
  - Nunca solo-ícono para acciones destructivas (delete, remove)
    → Siempre texto acompañante
  - El ícono va ANTES del texto (leading) para acciones
  - El ícono va DESPUÉS del texto (trailing) para dirección
```

### 7.3 Íconos con Texto vs sin Texto

```
¿Cuándo es seguro usar solo ícono?

  SEGURO (universalmente reconocido):
  ✕ Close
  🔍 Search
  ☰ Menu / Hamburger
  ➕ Add
  🏠 Home
  ← Back / Arrow
  ♡ Favorite / Like

  INSEGURO (requiere texto):
  🔧 Settings? Tools? Fix?
  📎 Attach? Link? Clip?
  ☁️ Cloud? Upload? Sync?
  🔔 Notifications? Alerts? Reminders?
  ⚡ Quick? Power? Performance?

  Regla de oro:
  Si 2+ personas en tu equipo interpretan diferente el ícono
  sin texto → NECESITA texto.
```

### 7.4 Íconos en Estados del Sistema

```
Patrón de feedback visual:

  Success:
  ┌──────────────────────────────────────┐
  │  ✓  Changes saved                    │  check-circle (success-500)
  └──────────────────────────────────────┘

  Error:
  ┌──────────────────────────────────────┐
  │  ✕  Something went wrong             │  x-circle (error-500)
  └──────────────────────────────────────┘

  Warning:
  ┌──────────────────────────────────────┐
  │  ⚠  Your plan expires in 3 days      │  alert-triangle (warning-500)
  └──────────────────────────────────────┘

  Info:
  ┌──────────────────────────────────────┐
  │  ℹ  New feature available            │  info-circle (info-500)
  └──────────────────────────────────────┘

  Loading:
  ┌──────────────────────────────────────┐
  │  ⟳  Saving changes...                │  spinner (neutral-500)
  └──────────────────────────────────────┘

  Regla: Ícono + color + texto.
  Nunca solo ícono para estados (accesibilidad).
  Nunca solo color (daltonismo).
```

### 7.5 Evitar Ambigüedad

```
Íconos ambiguos comunes:

  ❌ El ícono de "star" (★):
  ¿Favoritos? ¿Rating? ¿Premium? ¿Importante?
  → Depende del contexto. Siempre acompañar con texto.

  ❌ El ícono de "gear" (⚙):
  ¿Settings? ¿Configuración? ¿Herramientas? ¿Admin?
  → Universalmente asociado a settings, pero confirmar con label.

  ❌ El ícono de "bell" (🔔):
  ¿Notificaciones? ¿Alertas? ¿Recordatorios? ¿Alarmas?
  → Texto acompañante o tooltip requerido.

  ❌ El ícono de "share" (↗ / ⤴ / ⋮):
  → VARÍA por plataforma:
     iOS: cuadrado con flecha arriba (⬆□)
     Android: tres nodos conectados (⋈)
     Web: flecha diagonal (↗)
  → Si tu app es cross-platform, elige uno y sé consistente.

Test de ambigüedad:
  Muestra el ícono a 5 personas sin contexto.
  Si 4/5 dicen la misma cosa → claro.
  Si < 4/5 → necesita texto.
```

---

## 8. Jerarquía Visual y Composición

### 8.1 Cómo Imágenes e Íconos Guían la Atención

```
Patrones de lectura + visuales:

  Patrón F (texto-heavy):
  ┌──────────────────────────────────────┐
  │ ████████████████████████████████████ │  ← escaneo horizontal 1
  │ ████████████████████                 │
  │ ██████████                           │  ← escaneo horizontal 2
  │ ████████████████                     │
  │ ██████                               │  ← baja por la izquierda
  │ ████████████                         │
  └──────────────────────────────────────┘

  Patrón Z (visual + CTA):
  ┌──────────────────────────────────────┐
  │ Logo ─────────────────────── Nav     │  1→
  │          ╲                           │    ╲
  │            ╲                         │      ╲
  │              ╲ Visual                │        ╲ 2
  │               (imagen central)       │
  │                          ╲           │          ╲
  │ [CTA] ───────────────────── Link    │  3→
  └──────────────────────────────────────┘

  Regla: Coloca el visual más importante donde el ojo
  llega primero (arriba-izquierda para F, centro para Z).
```

### 8.2 Peso Visual

```
Escala de peso visual (de mayor a menor):

  Peso ALTO (atrae la mirada):
  ████████  Imágenes grandes, colores saturados
  ████████  Íconos filled en color primario
            Texto bold grande

  Peso MEDIO:
  ░░░░░░░░  Imágenes medianas, colores muted
  ░░░░░░░░  Íconos outline, tamaño estándar
            Texto regular

  Peso BAJO:
  · · · · ·  Divisores, bordes sutiles
             Íconos pequeños, color terciario
             Captions, metadata

  Aplicación:
  ┌──────────────────────────────────────────┐
  │  [██ IMAGEN HERO ██]              ALTO   │
  │                                          │
  │  Heading Bold 32px                ALTO   │
  │  Body text regular 16px           MEDIO  │
  │                                          │
  │  🔍 Search  👤 Profile  ⚙ Set   MEDIO   │
  │                                          │
  │  Caption · 2 hours ago · 8 min    BAJO   │
  └──────────────────────────────────────────┘
```

### 8.3 Relación con Tipografía y Color

```
Triángulo de jerarquía visual:

           TAMAÑO / PESO
              ╱╲
             ╱  ╲
            ╱    ╲
           ╱      ╲
          ╱ Imagen ╲
         ╱ o Ícono  ╲
        ╱            ╲
       ╱──────────────╲
      COLOR         TIPOGRAFÍA

  Los tres trabajan juntos:
  - Una imagen grande (tamaño) + heading bold (tipo) + color primario = máxima atención
  - Un ícono pequeño (tamaño) + caption (tipo) + gris (color) = mínima atención
  - Consistencia: si un ícono es primario, su label también debe sentirse primario
```

### 8.4 Evitar Saturación Visual

```
❌ Saturación visual:
┌──────────────────────────────────────────────┐
│ [🔴IMG] [🔵IMG] [🟢IMG] [🟡ICON] [🟣ICON]   │
│ ★★★★★ TEXT!! ⚡ BOLD ⚡ COLORS!! 🎉🎊🎆      │
│ [BIG BUTTON] [BIG BUTTON] [BIG BUTTON]      │
│ ████ BANNER ████ ⚠️ ALERT ⚠️ 🔔 NEW! 🔔     │
└──────────────────────────────────────────────┘
→ Todo compite. Nada destaca. Fatiga instantánea.

✅ Visual limpio:
┌──────────────────────────────────────────────┐
│                                              │
│  Heading                                     │
│                                              │
│  Body text explaining the feature in a       │
│  calm, readable manner.                      │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         [Ilustración relevante]      │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  [ Primary CTA ]                             │
│                                              │
└──────────────────────────────────────────────┘
→ Un punto focal claro. Espacio para respirar.

Regla:
  - 1 imagen principal por sección (máximo)
  - Whitespace como elemento de diseño (no como "espacio vacío")
  - Si añades un visual, pregunta: "¿Qué quito para hacer espacio?"
```

---

## 9. Accesibilidad y Usabilidad

### 9.1 Alt Text en Imágenes

```
Tipos de imágenes y su alt text:

  FUNCIONAL (transmite información):
  <img src="chart.png" alt="Revenue chart showing 12% growth in Q1 2026" />
  → Alt text describe la INFORMACIÓN, no la apariencia.

  DECORATIVA (no transmite información):
  <img src="abstract-bg.png" alt="" role="presentation" />
  → Alt vacío + role="presentation" → screen reader lo ignora.

  PRODUCTO (e-commerce):
  <img src="shoe.jpg" alt="Nike Air Max 90 in white and red, side view" />
  → Alt describe el producto como lo haría un vendedor.

  ÍCONO CON FUNCIÓN:
  <button aria-label="Close dialog">
    <svg aria-hidden="true"><!-- ícono de X --></svg>
  </button>
  → El ícono es aria-hidden, el botón tiene aria-label.

  ÍCONO CON TEXTO:
  <button>
    <svg aria-hidden="true"><!-- ícono de descarga --></svg>
    Download
  </button>
  → El texto es suficiente. Ícono decorativo → hidden.
```

**Checklist de alt text:**

```
  ☐ Imagen informativa → alt descriptivo del CONTENIDO
  ☐ Imagen decorativa → alt="" + role="presentation"
  ☐ Imagen con texto → alt incluye el texto de la imagen
  ☐ Ícono funcional solo → aria-label en el contenedor clickable
  ☐ Ícono + texto → aria-hidden="true" en el ícono
  ☐ Imagen como link → alt describe el DESTINO, no la imagen
  ☐ Gráficos complejos → alt + longdesc o texto alternativo visible
```

### 9.2 Tamaños Mínimos Táctiles

```
Targets táctiles para íconos:

  ❌ Ícono de 16px sin padding:
  ┌──┐
  │✕ │  ← 16×16px tap area. Imposible de tocar con precisión.
  └──┘

  ✅ Ícono de 16px con padding suficiente:
  ┌──────────┐
  │          │
  │    ✕     │  ← Visual: 16px. Tap area: 48×48px.
  │          │
  └──────────┘

  Mínimos:
  - Apple HIG: 44×44 pt
  - Material Design: 48×48 dp
  - WCAG: 44×44 CSS px

  Implementación:
  .icon-button {
    /* Visual del ícono */
    width: 24px;
    height: 24px;
    /* Padding para tap area */
    padding: 12px;         /* 24 + 12 + 12 = 48px tap area */
    /* O con min-width/height */
    min-width: 48px;
    min-height: 48px;
  }
```

### 9.3 Contraste y Visibilidad

```
Contraste mínimo para íconos y elementos gráficos:

  WCAG 2.1 — UI components: 3:1 contra el fondo

  ✅ Ícono oscuro sobre fondo claro:
  #374151 sobre #FFFFFF → 10.3:1 ✓

  ✅ Ícono primary sobre fondo claro:
  #2563EB sobre #FFFFFF → 4.6:1 ✓

  ⚠️ Ícono gris claro sobre fondo claro:
  #9CA3AF sobre #FFFFFF → 2.9:1 ✗ (falla 3:1)
  → Solo aceptable para íconos puramente decorativos

  ✅ Ícono blanco sobre fondo oscuro:
  #FFFFFF sobre #1F2937 → 14.4:1 ✓
```

### 9.4 No Depender Solo de Íconos

```
❌ Solo ícono para comunicar:

  [★]  [🔔]  [⚙]  [📎]
  ¿Qué hace cada uno? Depende del usuario.

✅ Ícono + texto (eliminando ambigüedad):

  [★ Favorites]  [🔔 Notifications]  [⚙ Settings]  [📎 Attach]
  → Universalmente claro para todos los usuarios.

✅ Si es solo-ícono (espacio limitado) → tooltip + aria-label:

  [★]           → hover: "Favorites" / aria-label="Favorites"
  [🔔]          → hover: "Notifications" / aria-label="Notifications"
  [⚙]           → hover: "Settings" / aria-label="Settings"

Regla de accesibilidad:
  NUNCA un ícono sin texto NI aria-label.
  Si no tiene ninguno → invisible para screen readers.
```

---

## 10. Optimización y Performance

### 10.1 Formatos de Archivo

| Formato | Mejor para | Ventajas | Desventajas |
|---|---|---|---|
| **SVG** | Íconos, logos, gráficos vectoriales | Escalable infinitamente, pequeño, manipulable con CSS | No sirve para fotos |
| **WebP** | Fotografías web (moderno) | 25-35% más liviano que JPEG | Soporte legacy (IE — irrelevante en 2026) |
| **AVIF** | Fotografías web (cutting-edge) | 50% más liviano que JPEG | Soporte en crecimiento |
| **JPEG** | Fotografías (fallback) | Soporte universal | Pesado vs WebP/AVIF, no tiene transparencia |
| **PNG** | Imágenes con transparencia | Lossless, transparencia | Muy pesado para fotos |
| **GIF** | ❌ Evitar | — | Pesado, baja calidad. Usar video o Lottie |

```
Decisión de formato:

  ¿Es un ícono o logo?
  └── SÍ → SVG (siempre)

  ¿Es una fotografía?
  └── SÍ → ¿Necesita transparencia?
       ├── SÍ → PNG (o WebP con alpha)
       └── NO → WebP (con JPEG fallback)
            <picture>
              <source srcset="img.avif" type="image/avif">
              <source srcset="img.webp" type="image/webp">
              <img src="img.jpg" alt="...">
            </picture>

  ¿Es una animación?
  └── SÍ → Lottie (JSON) o video (MP4/WebM)
       NO GIF — nunca.
```

### 10.2 SVG para Íconos — Optimización

```html
<!-- SVG inline (más flexible, manipulable con CSS) -->
<svg
  width="24"
  height="24"
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  <polyline points="20 6 9 17 4 12" />
</svg>

<!-- Ventajas del SVG inline:
  - currentColor hereda el color del texto padre
  - Manipulable con CSS (hover, transitions)
  - Sin request HTTP adicional
  - Cacheable en componentes (React, Vue)
-->
```

**Optimización de SVG:**

```
Antes de usar un SVG, optimizarlo:

  Herramientas:
  - SVGO (CLI/online) → svgomg.net
  - Figma: export settings → simplificar

  Lo que se elimina:
  - Metadata del editor (Illustrator, Figma)
  - IDs y clases innecesarios
  - Atributos redundantes
  - Espacios en blanco
  - Grupos vacíos

  Resultado típico: 40-60% reducción de tamaño

  Antes:  <svg xmlns="..." xmlns:xlink="..."
           id="Layer_1" data-name="Layer 1"
           viewBox="0 0 24 24" style="...">
           <defs><style>.cls-1{fill:#333}</style></defs>
           <g id="Group-1"><path class="cls-1" d="..."/></g>
         </svg>

  Después: <svg viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2">
            <path d="..."/>
           </svg>
```

### 10.3 Compresión de Imágenes

```
Pipeline de optimización:

  Original (cámara/stock): 4000×3000px, 5MB JPEG
                │
                ▼
  Paso 1: Resize al máximo necesario
  → ¿La imagen se muestra a max 800px? → resize a 1600px (2x para retina)
  → Resultado: ~1.5MB
                │
                ▼
  Paso 2: Comprimir
  → JPEG quality 80-85% (balance ideal)
  → WebP quality 80%
  → AVIF quality 60% (se ve igual)
  → Resultado: ~150-300KB
                │
                ▼
  Paso 3: Responsive images (srcset)
  → Generar 3-4 tamaños (400w, 800w, 1200w, 1600w)
  → El browser elige el adecuado

  Herramientas:
  - Squoosh (squoosh.app) → manual, visual
  - Sharp (Node.js) → automatizado en build
  - Cloudinary / Imgix → CDN con transformación en tiempo real
```

```html
<!-- Responsive images con srcset -->
<img
  src="product-800.jpg"
  srcset="
    product-400.jpg   400w,
    product-800.jpg   800w,
    product-1200.jpg 1200w,
    product-1600.jpg 1600w
  "
  sizes="
    (max-width: 640px) 100vw,
    (max-width: 1024px) 50vw,
    800px
  "
  alt="Product description"
  loading="lazy"
  decoding="async"
  width="800"
  height="600"
/>
```

### 10.4 Lazy Loading

```
Lazy loading — cargar imágenes solo cuando son visibles:

  Viewport visible:
  ┌──────────────────────────────┐
  │  Header                      │  ← cargado inmediatamente
  │  Hero image                  │  ← cargado inmediatamente (above-the-fold)
  │  First section               │  ← cargado inmediatamente
  └──────────────────────────────┘ ─── fold ───
  │  Second section              │  ← loading="lazy" → carga al scroll
  │  Image gallery               │  ← loading="lazy"
  │  More content...             │  ← loading="lazy"

  Regla:
  - Above-the-fold: loading="eager" (o no poner atributo) — NUNCA lazy
  - Below-the-fold: loading="lazy" — SIEMPRE

  También: width y height SIEMPRE para evitar layout shift (CLS)
```

### 10.5 Impacto en Performance

| Métrica | Sin optimización | Con optimización | Mejora |
|---|---|---|---|
| **Page weight** | 8MB (imágenes raw) | 1.2MB (WebP + resize) | 85% menos |
| **LCP** | 4.2s (hero img pesada) | 1.8s (preload + optimizada) | 57% más rápido |
| **CLS** | 0.25 (sin width/height) | 0.02 (con dimensiones) | Layout estable |
| **FCP** | 3.5s (todo carga de golpe) | 1.5s (lazy load) | 57% más rápido |

```
Checklist de performance visual:

  ☐ Todas las imágenes en WebP/AVIF (con JPEG fallback)
  ☐ Todos los íconos en SVG inline
  ☐ Imágenes resize al tamaño máximo de display × 2 (retina)
  ☐ Compresión: JPEG 80-85%, WebP 80%, AVIF 60%
  ☐ srcset con 3-4 tamaños para imágenes responsivas
  ☐ loading="lazy" en todo below-the-fold
  ☐ width + height en todos los <img> (evitar CLS)
  ☐ Hero image: preload en <head> (above-the-fold critical)
  ☐ SVGs optimizados con SVGO
  ☐ No GIFs — Lottie o video en su lugar
```

---

## 11. Metodología de Diseño

### Paso 1: Definir Propósito Visual

```
Antes de elegir cualquier imagen o ícono:

  ¿Qué tipo de producto es?
  ├── SaaS dashboard → Priorizar íconos funcionales, imágenes mínimas
  ├── E-commerce → Fotografía de producto es central
  ├── Blog/editorial → Ilustraciones y thumbnails de artículos
  ├── Landing page → Hero images potentes + ilustraciones de features
  └── App mobile → Íconos para nav, ilustraciones para onboarding/empty states

  ¿Qué emociones debe transmitir?
  ├── Confianza → Fotos reales, personas, testimoniales
  ├── Innovación → Ilustraciones modernas, 3D, abstract
  ├── Simplicidad → Íconos minimalistas, whitespace, pocos visuales
  └── Diversión → Ilustraciones coloridas, animaciones, personalidad
```

### Paso 2: Seleccionar Estilo

```
Decisiones de estilo visual:

  Fotografía:
  → Estilo (natural, editorial, lifestyle, producto)
  → Tratamiento (full color, desaturado, duotone, B&W)
  → Fuente (custom shoot, curated stock, UGC)

  Ilustraciones:
  → Estilo (flat, isometric, line art, organic, abstract)
  → Paleta (match con brand colors)
  → Nivel de detalle (simple para UI, detallado para marketing)

  Íconos:
  → Estilo (outline, filled, duotone)
  → Stroke width (1px, 1.5px, 2px)
  → Corner radius (sharp, rounded)
  → Grid y tamaños (16, 20, 24, 32)

  Regla: Documenta TODAS estas decisiones.
  Si no están escritas, no son un sistema — son preferencias personales.
```

### Paso 3: Crear Reglas de Uso

```
Documentación de reglas:

  IMÁGENES:
  - Hero images: aspect ratio 16:9, max-height 600px
  - Thumbnails: 4:3, siempre object-fit: cover
  - Avatares: circulares, con borde de 2px
  - Overlay sobre imagen con texto: mínimo 50% opacidad
  - Formato: WebP primary, JPEG fallback

  ÍCONOS:
  - Estilo principal: outline, 1.5px stroke
  - Canvas: 24×24px con 2px safe area
  - Color: currentColor (hereda del texto)
  - Con texto: gap de 8px, ícono leading
  - Solo ícono: tooltip obligatorio + aria-label
  - Tamaños permitidos: 16, 20, 24, 32px

  ILUSTRACIONES:
  - Estilo: flat, paleta de brand
  - Uso: empty states, onboarding, error pages
  - Máx por pantalla: 1 ilustración principal
  - Siempre centrada con texto descriptivo debajo
```

### Paso 4: Integrar en Design System

```
Estructura en el design system:

  Assets/
  ├── Icons/
  │   ├── Componente: <Icon name size color />
  │   ├── Catálogo visual (searchable)
  │   ├── Guía de contribución
  │   └── Naming conventions
  │
  ├── Images/
  │   ├── Guía de estilo fotográfico
  │   ├── Templates de aspect ratio
  │   ├── Overlay tokens
  │   └── Responsive image guidelines
  │
  ├── Illustrations/
  │   ├── Librería de ilustraciones (by use case)
  │   ├── Guía de estilo
  │   └── Color guidelines (match brand)
  │
  └── Tokens/
      ├── --icon-size-sm/md/lg
      ├── --icon-color-default/active/disabled
      ├── --avatar-size-sm/md/lg/xl
      ├── --image-border-radius
      └── --image-overlay-opacity
```

### Paso 5: Validar con Usuarios

```
Qué testear:

  ÍCONOS:
  - Mostrar íconos SIN texto → ¿los usuarios identifican la acción?
  - Si < 80% acierta → agregar texto obligatorio
  - Comparar: ícono A vs ícono B para la misma acción

  IMÁGENES:
  - ¿La imagen ayuda a entender el contenido?
  - ¿Distrae de la tarea principal?
  - ¿Se siente relevante o genérica?
  - A/B test: con imagen vs sin imagen → ¿afecta conversión?

  ILUSTRACIONES:
  - ¿El estilo transmite la personalidad correcta?
  - ¿Los usuarios entienden qué representa?
  - Empty states: ¿el usuario sabe qué hacer después?
```

### Paso 6: Iterar y Escalar

```
  1. Auditar el uso actual → ¿hay inconsistencias?
  2. Identificar gaps → ¿faltan íconos para nuevos features?
  3. Agregar al sistema → siguiendo las reglas establecidas
  4. Comunicar cambios → changelog visual para el equipo
  5. Revisar performance → ¿los nuevos assets están optimizados?
  6. Actualizar documentación → catálogo + guidelines actualizados
```

---

## 12. Nivel Intermedio / Avanzado

### 12.1 Creación de Íconos Personalizados

```
Proceso de diseño de un ícono custom:

  1. DEFINIR: ¿Qué concepto necesito representar?
     → "Colaboración en tiempo real"

  2. BRAINSTORM: Asociaciones visuales
     → Personas + flechas + documento + cursor
     → Simplificar: dos cursores sobre un documento

  3. SKETCH: Formas básicas en el grid
     ┌────────────────────────┐
     │    ┌──────┐            │
     │    │ doc  │ ↖ cursor1  │
     │    │      │            │
     │    │      │  ↗ cursor2 │
     │    └──────┘            │
     └────────────────────────┘

  4. REFINAR: Simplificar al mínimo reconocible
     → ¿Se entiende a 16px?
     → ¿Tiene el mismo stroke que los demás?
     → ¿Encaja en el grid de 24px?

  5. VALIDAR: Mostrar a 5+ personas
     → "¿Qué crees que significa?" (sin contexto)

  6. IMPLEMENTAR: Exportar SVG optimizado
     → Mismo stroke width, corners, padding que el set
     → Agregarlo al catálogo con naming correcto

Principios de diseño de íconos:
  - Pixel perfection: alinear a pixel grid (evitar blurriness)
  - Simplicidad: si puedes quitar un trazo y se entiende → quítalo
  - Consistencia: debe verse como parte de la misma familia
  - Metáfora clara: la forma debe evocar el concepto sin explicación
```

### 12.2 Adaptación de Iconografía a Branding

```
Personalizar íconos sin sacrificar claridad:

  Generic (Lucide/Heroicons):
  → Íconos estándar, perfectos para funcionalidad
  → Sin personalidad de marca

  Branded (personalizados):
  → Mismo ícono conceptual, pero con toques de marca:
    - Corner radius personalizado (más redondeado = más friendly)
    - Stroke width específico (más grueso = más bold)
    - Detalles únicos (un pequeño elemento de marca)
    - Color del brand en ciertos contextos

  Ejemplo:
  Genérico:   ♡ (corazón estándar)
  Spotify:    ♡ (corazón con esquinas más suaves, ligeramente más ancho)
  Airbnb:     ♡ (corazón con forma orgánica, inspirado en el logo)

  Balance:
  - Sistema base: íconos genéricos (90% del producto)
  - Branded touches: en momentos clave (nav, empty states, marketing)
  - NUNCA sacrificar reconocimiento por personalidad
```

### 12.3 Uso de Ilustraciones para Storytelling

```
Narrative design con ilustraciones:

  Onboarding como historia:
  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
  │        │  │        │  │        │  │        │
  │ Scene1 │→ │ Scene2 │→ │ Scene3 │→ │ Scene4 │
  │ Proble-│  │ Descub-│  │  Usa   │  │  Éxito │
  │ ma     │  │ re app │  │feature │  │        │
  │        │  │        │  │        │  │        │
  │"Chaos" │  │"Hope"  │  │"Action"│  │"Joy"   │
  └────────┘  └────────┘  └────────┘  └────────┘

  Cada ilustración:
  - Misma paleta y estilo
  - Progresión emocional (problema → solución)
  - Un personaje recurrente (si aplica)
  - Simplicidad (transmitir una idea por slide)

  Feature showcase:
  ┌──────────────────────────────────────────────┐
  │                                              │
  │  ┌──────────┐  Feature Title                 │
  │  │ illust.  │                                │
  │  │ mostrando│  Description of what this      │
  │  │ el feat. │  feature does and why it        │
  │  │ en uso   │  matters to the user.           │
  │  └──────────┘                                │
  │                                              │
  └──────────────────────────────────────────────┘
  → La ilustración muestra el feature EN ACCIÓN, no en abstracto.
```

### 12.4 Sistemas Visuales Complejos (SaaS, Dashboards)

```
Iconografía en dashboards data-heavy:

  Principio: Los íconos son ANCLAS VISUALES en un mar de datos.

  ┌──────────────────────────────────────────────────┐
  │  📊 Revenue   👥 Users     🔄 Churn    📈 Growth │
  │  $45.2k       12,847       2.3%        +12%      │
  │  +12% ↑       -3% ↓       -0.5% ↑     +2.1% ↑  │
  ├──────────────────────────────────────────────────┤
  │                                                  │
  │  Los íconos en KPIs:                             │
  │  - Identifican la categoría en milisegundos      │
  │  - Diferencian visualmente cards idénticas       │
  │  - NO son decorativos — son funcionales          │
  │                                                  │
  │  Reglas para data-heavy:                         │
  │  1. Íconos solo en headers/labels (no en datos)  │
  │  2. Mismo tamaño y posición en todas las cards   │
  │  3. Color neutro (no competir con los números)   │
  │  4. ↑↓ arrows para tendencias (funcional, no     │
  │     decorativo) con color semántico (green/red)  │
  └──────────────────────────────────────────────────┘
```

### 12.5 Consistencia Cross-Platform

```
Adaptación web ↔ mobile:

  Web (desktop):
  ┌────────────────────────────────────────────┐
  │  Sidebar con íconos + texto                │
  │  📊 Dashboard                              │
  │  👥 Users                                  │
  │  📋 Projects                               │
  │  ⚙ Settings                               │
  │                                            │
  │  Íconos: 20px, outline, con label          │
  └────────────────────────────────────────────┘

  Mobile (tab bar):
  ┌────────────────────────────────────────────┐
  │   🏠      📊      👥      ⚙              │
  │  Home   Stats   Users  Settings            │
  │                                            │
  │  Íconos: 24px, outline/filled, con label   │
  └────────────────────────────────────────────┘

  Diferencias aceptables:
  - Tab bar mobile: filled (activo) vs outline (inactivo)
  - Web sidebar: puede ser solo outline (tiene labels siempre)
  - Mobile puede tener íconos ligeramente más grandes (touch)

  NO aceptable:
  - Diferentes íconos para el mismo concepto en web vs mobile
  - Diferente estilo base (outline en web, duotone en mobile)
  - Diferente naming en código (icon-home vs ic_home)

  Solución: Un SOLO icon set usado en ambas plataformas.
  → React: <Icon name="home" />
  → React Native: <Icon name="home" />
  → Mismo nombre, mismo SVG, diferente renderer.
```

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Al empezar | ¿Necesito un visual aquí? | Si no comunica o no guía → no lo pongas |
| Al elegir imagen vs ícono | ¿Es emoción/narrativa o acción/estado? | Emoción → imagen. Acción → ícono |
| Al seleccionar estilo de ícono | ¿Outline o filled? | Outline default, filled para activos |
| Al elegir fotografía | ¿Es relevante o es stock genérico? | Si es genérico → no usarla o reemplazar con ilustración |
| Al agregar ícono solo | ¿Es universalmente reconocido? | Si hay duda → agregar texto |
| Al verificar accesibilidad | ¿Tiene alt text / aria-label? | Funcional → alt/aria. Decorativo → hidden |
| Al optimizar | ¿Está en el formato correcto? | SVG para íconos, WebP para fotos |
| Al escalar | ¿Está documentado en el design system? | Si no → documentar reglas, naming, catálogo |

**Cheat Sheet de decisiones:**

```
  ¿Qué formato?
  → Ícono/Logo: SVG (siempre)
  → Foto: WebP (JPEG fallback)
  → Animación: Lottie (nunca GIF)

  ¿Qué estilo de ícono?
  → SaaS/App: Outline (1.5px stroke, 24px canvas)
  → Tab bar activo: Filled
  → Marketing: Duotone o ilustrativo

  ¿Solo ícono o ícono + texto?
  → Si hay espacio → siempre ícono + texto
  → Solo ícono → solo si es ✕, 🔍, ☰, ➕, ♡, 🏠, ←

  ¿Imagen o ilustración?
  → Producto real → fotografía
  → Concepto abstracto → ilustración
  → Empty state → ilustración + CTA
  → Background → evaluar si es necesario

  ¿Cuántos visuales por sección?
  → 1 visual principal (máximo)
  → Whitespace > más visuales
```

> **Mantra de imagery & iconography:** Cada píxel visual debe ganarse su lugar. Si una imagen no comunica, elimínala. Si un ícono no se entiende, agrégale texto. Si un visual no es consistente con el sistema, rediseñalo. El silencio visual (whitespace) es más poderoso que el ruido visual (más imágenes). Menos, pero mejor.
