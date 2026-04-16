# Forms & UI Elements — Módulo Completo

> **Módulo:** Formularios y Componentes de Interfaz
> **Nivel:** Básico → Intermedio → Avanzado
> **Objetivo:** Diseñar formularios eficientes, accesibles y escalables que maximicen la conversión y minimicen la fricción del usuario.

---

## Tabla de Contenidos

1. [Introducción a Forms & UI Elements](#1-introducción-a-forms--ui-elements)
2. [Fundamentos de Formularios](#2-fundamentos-de-formularios)
3. [Inputs Avanzados](#3-inputs-avanzados)
4. [Botones y Acciones](#4-botones-y-acciones)
5. [Component Properties vs Variants](#5-component-properties-vs-variants)
6. [Combinación de Componentes](#6-combinación-de-componentes)
7. [Estados y Feedback](#7-estados-y-feedback)
8. [Usabilidad y Accesibilidad](#8-usabilidad-y-accesibilidad)
9. [Diseño de Formularios Complejos](#9-diseño-de-formularios-complejos)
10. [Design Systems y Escalabilidad](#10-design-systems-y-escalabilidad)
11. [Implementación Práctica](#11-implementación-práctica)
12. [Nivel Intermedio / Avanzado](#12-nivel-intermedio--avanzado)

---

## 1. Introducción a Forms & UI Elements

### 1.1 ¿Qué son los formularios y componentes UI?

**Intuición**
Un formulario es una conversación estructurada entre el sistema y el usuario. Cada campo es una pregunta; cada respuesta, un dato. Los componentes UI son las piezas individuales (botones, inputs, selects) que construyen esa conversación.

**Estructura formal**
- **Formulario (Form):** Contenedor semántico que agrupa campos de entrada con un propósito definido (registro, compra, búsqueda).
- **Componente UI (UI Element):** Pieza atómica de interfaz con comportamiento propio (input, checkbox, slider, button).
- **Patrón (Pattern):** Combinación recurrente de componentes que resuelve un problema de interacción (login form, search bar, address form).

**Jerarquía conceptual:**

```
┌─────────────────────────────────────────────┐
│  PATRÓN (Pattern)                           │
│  Ej: Formulario de checkout                 │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  COMPONENTE (Component)               │  │
│  │  Ej: Input con label + validación     │  │
│  │                                       │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  ELEMENTO (Element)             │  │  │
│  │  │  Ej: <input type="text">        │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### 1.2 Rol en productos digitales

Los formularios cumplen tres funciones críticas:

| Función | Descripción | Ejemplo |
|---|---|---|
| **Captura de datos** | Recoger información del usuario | Registro, encuestas, onboarding |
| **Interacción** | Permitir al usuario comunicar intenciones | Filtros, búsqueda, configuración |
| **Conversión** | Convertir visitantes en usuarios/clientes | Checkout, suscripción, lead gen |

### 1.3 Impacto en UX y métricas

Los formularios son **puntos de fricción directos**. Un mal formulario mata conversiones:

```
Formulario de 15 campos → Completion rate: ~20%
Formulario de  5 campos → Completion rate: ~60%
Formulario de  3 campos → Completion rate: ~85%

  ↑ Menos campos = Más conversión
```

**Métricas impactadas:**
- **Completion rate** — % de usuarios que terminan el formulario
- **Drop-off rate** — % de usuarios que abandonan en cada paso
- **Time to complete** — Tiempo promedio para completar
- **Error rate** — % de envíos con errores de validación

> ⚠️ **Regla de oro:** Cada campo que agregas debe justificar su existencia. Si no necesitas el dato ahora, no lo pidas.

### 1.4 Input vs Componente vs Patrón

| Concepto | Qué es | Ejemplo |
|---|---|---|
| **Input** | Elemento HTML nativo de entrada | `<input type="email">` |
| **Componente** | Input + label + helper + estados + lógica | `<TextField label="Email" error={...} />` |
| **Patrón** | Combinación de componentes para resolver un flujo | Formulario de login (email + password + remember me + submit) |

**Aplicación práctica:**
- Diseñas **inputs** cuando definís el tipo de dato.
- Diseñas **componentes** cuando definís comportamiento y estados.
- Diseñas **patrones** cuando definís flujos completos.

---

## 2. Fundamentos de Formularios

### 2.1 Anatomía de un campo de formulario

**Intuición**
Cada campo es una mini-conversación: le dices al usuario qué necesitas (label), le das espacio para responder (input), lo guías si tiene dudas (helper text) y le avisas si algo salió mal (validation).

**Estructura formal:**

```
┌─────────────────────────────────────┐
│  Label *                            │  ← Identifica el campo
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  Placeholder text           │    │  ← Input (campo de entrada)
│  └─────────────────────────────┘    │
│  Helper text o instrucción          │  ← Texto de ayuda
│  ✗ Validation message               │  ← Mensaje de error/éxito
└─────────────────────────────────────┘
```

**Cada parte cumple un rol:**

| Elemento | Rol | Buena práctica |
|---|---|---|
| **Label** | Identificar qué dato se pide | Siempre visible, nunca solo placeholder |
| **Input** | Recibir la respuesta del usuario | Tipo correcto según el dato |
| **Placeholder** | Ejemplo del formato esperado | No reemplaza al label |
| **Helper text** | Orientar antes de escribir | Breve, contextual |
| **Validation** | Informar errores o confirmación | Claro, específico, accionable |

> ❌ **Anti-patrón:** Usar el placeholder como label. Cuando el usuario empieza a escribir, pierde la referencia de qué campo es.

### 2.2 Tipos de inputs

**Tabla de inputs fundamentales:**

| Tipo | Uso | Cuándo usarlo |
|---|---|---|
| `text` | Texto libre | Nombre, dirección, notas |
| `email` | Correo electrónico | Teclado optimizado en móvil |
| `password` | Contraseña | Oculta caracteres, toggle de visibilidad |
| `number` | Valores numéricos | Cantidad, edad (con min/max) |
| `tel` | Teléfono | Teclado numérico en móvil |
| `url` | Dirección web | Sitio web, portfolio |
| `search` | Búsqueda | Barra de búsqueda con ✕ para limpiar |
| `select` | Opción única de lista | 5-15 opciones predefinidas |
| `checkbox` | Selección múltiple / toggle | Términos, preferencias múltiples |
| `radio` | Opción única de pocas opciones | 2-5 opciones mutuamente excluyentes |
| `date` | Fecha | Nacimiento, reservaciones |
| `time` | Hora | Horarios, programación |
| `textarea` | Texto largo | Comentarios, descripciones |

### 2.3 Guía de selección de input

**Aplicación práctica — Árbol de decisión:**

```
¿Qué tipo de dato necesitas?
│
├─ Texto libre
│  ├─ Corto (< 100 chars) ──→ text
│  └─ Largo (> 100 chars) ──→ textarea
│
├─ Opciones predefinidas
│  ├─ ¿Cuántas opciones?
│  │  ├─ 2-5 opciones ──→ radio buttons
│  │  ├─ 5-15 opciones ──→ select / dropdown
│  │  └─ > 15 opciones ──→ autocomplete / search select
│  └─ ¿Selección múltiple?
│     ├─ Pocas opciones ──→ checkboxes
│     └─ Muchas opciones ──→ multi-select / chips
│
├─ Numérico
│  ├─ Valor exacto ──→ number input
│  └─ Rango ──→ slider
│
├─ Fecha / Hora ──→ date / time picker
│
└─ Booleano (sí/no) ──→ checkbox o toggle switch
```

### 2.4 Reducción de fricción

**Intuición**
La fricción es todo lo que dificulta, retrasa o confunde al usuario al completar un formulario. Tu trabajo es eliminarla.

**Estrategias clave:**

```
ALTA FRICCIÓN                         BAJA FRICCIÓN
───────────────────────────────────────────────────
15 campos obligatorios                5 campos esenciales
Sin indicación de progreso            Barra de progreso
Validación solo al enviar             Validación en tiempo real
Labels confusos                       Labels claros y concisos
Sin autocompletado                    Autocomplete habilitado
Sin valores por defecto               Smart defaults
Campo de teléfono sin máscara         Máscara: (___) ___-____
Todo en una página                    Multi-step cuando es largo
```

**Técnicas de reducción de fricción:**

1. **Eliminar campos innecesarios** — ¿Realmente necesitas el "nombre de empresa" en el registro?
2. **Smart defaults** — Pre-selecciona el país según la IP.
3. **Autocomplete nativo** — Usa `autocomplete="name"`, `autocomplete="email"`, etc.
4. **Inline validation** — Valida mientras el usuario escribe (con debounce).
5. **Progressive disclosure** — Muestra campos adicionales solo cuando son relevantes.

**Ejemplo comparativo:**

```
❌ MAL: Formulario de registro
┌──────────────────────────────┐
│ Nombre *                     │
│ Apellido *                   │
│ Email *                      │
│ Confirmar email *            │  ← Innecesario
│ Contraseña *                 │
│ Confirmar contraseña *       │  ← Mejor: toggle de visibilidad
│ Teléfono *                   │  ← ¿Lo necesitas ahora?
│ Fecha de nacimiento *        │  ← ¿Lo necesitas ahora?
│ Género *                     │  ← ¿Lo necesitas ahora?
│ Dirección *                  │  ← ¿Lo necesitas ahora?
│ Ciudad *                     │
│ País *                       │
│ [  Registrarse  ]            │
└──────────────────────────────┘
12 campos → Drop-off: ~70%

✅ BIEN: Formulario de registro
┌──────────────────────────────┐
│ Nombre completo              │
│ Email                        │
│ Contraseña    [👁]           │  ← Toggle de visibilidad
│ [  Crear cuenta  ]           │
│                              │
│ ─── o continuar con ───      │
│ [G] Google  [→] Apple        │
└──────────────────────────────┘
3 campos → Completion rate: ~85%
```

---

## 3. Inputs Avanzados

### 3.1 Autocomplete / Autosuggest

**Intuición**
El autocomplete predice lo que el usuario quiere escribir y ofrece sugerencias, reduciendo esfuerzo y errores.

**Estructura formal:**

```
┌─────────────────────────────┐
│  San Franc█                 │  ← El usuario escribe
├─────────────────────────────┤
│  San Francisco, CA          │  ← Sugerencia 1 (resaltada)
│  San Francisco de Macorís   │  ← Sugerencia 2
│  San Franciscquito          │  ← Sugerencia 3
└─────────────────────────────┘
```

**Cuándo usarlo:**
- Listas grandes (> 15 opciones): ciudades, países, productos
- Datos con formato específico: direcciones, nombres de empresa
- Búsquedas frecuentes

**Cuándo NO usarlo:**
- Pocas opciones (< 7) → Usa radio buttons o select
- Datos completamente libres → Usa text input
- Datos sensibles → No sugieras contraseñas ni datos privados

### 3.2 Multi-select

**Intuición**
Permite seleccionar múltiples opciones de una lista. La presentación varía según la cantidad de opciones.

```
Pocas opciones (< 7):           Muchas opciones (7+):
┌─────────────────────┐         ┌──────────────────────────────┐
│ ☑ JavaScript        │         │  Buscar habilidades...       │
│ ☐ Python            │         ├──────────────────────────────┤
│ ☑ TypeScript        │         │ [JavaScript ✕] [React ✕]    │
│ ☐ Go                │         │ [TypeScript ✕]               │
│ ☑ Rust              │         │                              │
└─────────────────────┘         │ ☐ Python                     │
Checkboxes visibles             │ ☐ Go                         │
                                │ ☐ Rust                       │
                                └──────────────────────────────┘
                                Chips + dropdown buscable
```

### 3.3 Sliders

**Cuándo usar sliders vs number inputs:**

| Criterio | Slider | Number input |
|---|---|---|
| Rango definido | ✅ Ideal | Posible |
| Precisión exacta | ❌ Difícil | ✅ Ideal |
| Exploración de rango | ✅ Ideal | ❌ Tedioso |
| Accesibilidad | ⚠️ Complejo | ✅ Simple |
| Valores discretos | ✅ Con snapping | ✅ Con step |

**Mejor práctica:** Combinar slider + input numérico para máxima flexibilidad.

```
Precio máximo
──────────●──────────  $750
                        ┌──────┐
                        │  750 │  ← Input editable sincronizado
                        └──────┘
```

### 3.4 File Upload

**Estructura de un file upload accesible:**

```
┌─────────────────────────────────────────┐
│                                         │
│     ┌──────────┐                        │
│     │  📄 ↑    │  Arrastra archivos     │
│     └──────────┘  o haz clic para       │
│                   seleccionar            │
│                                         │
│  Formatos: JPG, PNG, PDF                │
│  Tamaño máximo: 5 MB                   │
└─────────────────────────────────────────┘

Después de subir:
┌─────────────────────────────────────────┐
│  📄 documento.pdf  (2.3 MB)  [✕]       │
│  ████████████████████░░░  85%           │
│  📄 foto.jpg       (1.1 MB)  ✓         │
└─────────────────────────────────────────┘
```

**Checklist de file upload:**
- ✅ Indicar formatos aceptados antes de subir
- ✅ Mostrar tamaño máximo
- ✅ Barra de progreso
- ✅ Preview cuando sea posible (imágenes)
- ✅ Opción de eliminar archivo subido
- ✅ Drag & drop + click como fallback

### 3.5 Inputs dinámicos

**Intuición**
Campos que se agregan, eliminan o transforman según la interacción del usuario.

```
Experiencia laboral

┌──────────────────────────────────────┐
│  Empresa:  [ Acme Corp            ] │
│  Puesto:   [ Frontend Developer   ] │
│  Periodo:  [ 2020 ] - [ 2023 ]     │  [🗑]
├──────────────────────────────────────┤
│  Empresa:  [ Startup Inc          ] │
│  Puesto:   [ UI Designer          ] │
│  Periodo:  [ 2018 ] - [ 2020 ]     │  [🗑]
└──────────────────────────────────────┘
       [+ Agregar experiencia]
```

**Reglas clave:**
- Siempre mostrar al menos un grupo vacío
- Permitir eliminar cualquier grupo (excepto el primero si es obligatorio)
- Mantener un límite máximo razonable
- Guardar estado para evitar pérdida de datos

### 3.6 Validación: Tiempo real vs Diferida

| Estrategia | Cuándo | Mejor para |
|---|---|---|
| **Tiempo real** (on change / on input) | Mientras escribe | Formatos (email, teléfono), disponibilidad (username) |
| **On blur** (al salir del campo) | Al dejar el campo | La mayoría de campos, validaciones no disruptivas |
| **On submit** (al enviar) | Al presionar enviar | Validaciones de negocio, verificaciones de servidor |
| **Híbrida** | On blur + on submit | Formularios complejos (mejor balance) |

**Mejor práctica:**

```
1. El usuario empieza a escribir → NO mostrar errores aún
2. El usuario sale del campo (blur) → Validar y mostrar error si hay
3. El usuario corrige → Validar en tiempo real (feedback inmediato)
4. El usuario envía → Validación final completa

Este patrón se llama "validate on blur, revalidate on change"
```

> ⚠️ **Anti-patrón:** Validar en tiempo real desde el primer carácter. El usuario escribe "j" en el campo email y ya ve "Email inválido". Frustrante.

### 3.7 Máscaras de entrada (Input Masking)

**Intuición**
Las máscaras guían al usuario mostrando el formato esperado directamente en el campo.

```
Sin máscara:                    Con máscara:
┌──────────────────┐            ┌──────────────────┐
│  5551234567       │            │  (555) 123-4567  │
└──────────────────┘            └──────────────────┘

Sin máscara:                    Con máscara:
┌──────────────────┐            ┌──────────────────┐
│  4111111111111111 │            │  4111 1111 1111 1111 │
└──────────────────┘            └──────────────────┘
```

**Cuándo usar máscaras:**
- ✅ Teléfonos, tarjetas de crédito, fechas, códigos postales
- ❌ Nombres, emails, contraseñas, texto libre

**Reglas de implementación:**
- La máscara debe ser visual, no alterar el valor almacenado
- Permitir pegar valores sin formato
- No bloquear caracteres válidos inesperados (ej: + en teléfonos internacionales)

---

## 4. Botones y Acciones

### 4.1 Tipos de botones

**Intuición**
No todos los botones son iguales. Su apariencia comunica importancia. Un formulario con tres botones idénticos es como un semáforo con tres luces verdes: nadie sabe qué hacer.

**Jerarquía visual:**

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  ┌──────────────────┐   Alta prominencia             │
│  │  Guardar cambios │   PRIMARY                      │
│  └──────────────────┘   → Acción principal           │
│       (filled)           Fondo sólido + texto claro  │
│                                                      │
│  ┌──────────────────┐   Media prominencia            │
│  │  Vista previa    │   SECONDARY                    │
│  └──────────────────┘   → Acción alternativa         │
│       (outlined)         Borde + texto color          │
│                                                      │
│     Cancelar            Baja prominencia              │
│       (text only)        TERTIARY                     │
│                          → Acción menor               │
│                          Solo texto, sin fondo         │
│                                                      │
│  ┌──────────────────┐   Prominencia de peligro       │
│  │  Eliminar cuenta │   DESTRUCTIVE                  │
│  └──────────────────┘   → Acción irreversible        │
│       (red filled)       Rojo/warning, confirmación   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 4.2 Propiedades de botones

**Tamaños:**

| Tamaño | Height | Padding | Uso |
|---|---|---|---|
| **Small (sm)** | 32px | 8px 12px | Tablas, inline actions |
| **Medium (md)** | 40px | 10px 16px | Formularios, modals |
| **Large (lg)** | 48px | 12px 24px | CTAs, landing pages |
| **Extra Large (xl)** | 56px | 16px 32px | Mobile primary actions |

**Estados:**

```
DEFAULT          HOVER            ACTIVE           DISABLED         LOADING
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Enviar  │    │  Enviar  │    │  Enviar  │    │  Enviar  │    │  ◌ ...   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
  bg: blue       bg: blue-700    bg: blue-800    bg: gray-300    bg: blue
  cursor:        cursor:         cursor:         cursor:         cursor:
  default        pointer         pointer         not-allowed     wait
                 shadow: sm      transform:      opacity: 0.5    disabled
                                 scale(0.98)
```

### 4.3 Jerarquía de acciones en formularios

**Aplicación práctica:**

```
❌ MAL: Todas las acciones al mismo nivel
┌──────────────────────────────────────┐
│  [Cancelar]  [Borrador]  [Enviar]   │
│  (todos se ven iguales)             │
└──────────────────────────────────────┘

✅ BIEN: Jerarquía clara
┌──────────────────────────────────────┐
│  Cancelar     [Borrador]  [Enviar]  │
│  (tertiary)   (secondary) (primary) │
└──────────────────────────────────────┘
   Menos ←──── importancia ────→ Más
```

**Regla: máximo 1 primary por grupo de acciones.** Si todo es importante, nada es importante.

### 4.4 CTAs (Call to Action) efectivos

| Principio | ❌ Malo | ✅ Bueno |
|---|---|---|
| Específico | "Enviar" | "Crear mi cuenta" |
| Orientado a beneficio | "Submit" | "Empezar gratis" |
| Primer persona | "Registrar usuario" | "Crear mi perfil" |
| Urgencia | "Continuar" | "Reservar mi lugar" |
| Conciso | "Haz clic aquí para continuar" | "Continuar" |

**Fórmula CTA:**

```
Verbo de acción + Beneficio/Objeto
────────────────────────────────
"Descargar guía gratuita"
"Comenzar prueba de 14 días"
"Guardar mis preferencias"
```

> ⚠️ **Anti-patrón:** "Submit" o "Enviar" genérico. Siempre describe la acción específica.

---

## 5. Component Properties vs Variants

### 5.1 ¿Qué son properties (props)?

**Intuición**
Las propiedades son los "diales de control" de un componente. Cambian su apariencia o comportamiento sin crear un componente nuevo.

**Estructura formal:**

```
Componente: Button
│
├── Props:
│   ├── size:     "sm" | "md" | "lg"
│   ├── variant:  "primary" | "secondary" | "tertiary" | "destructive"
│   ├── state:    "default" | "hover" | "active" | "disabled" | "loading"
│   ├── icon:     ReactNode | null
│   ├── iconPosition: "left" | "right"
│   ├── fullWidth: boolean
│   └── label:    string
```

### 5.2 ¿Qué son variants?

**Intuición**
Las variantes son versiones predefinidas del componente que agrupan varias props en una configuración con nombre.

```
Variantes del botón:

  PRIMARY         SECONDARY       GHOST           DESTRUCTIVE
┌─────────┐     ┌─────────┐     ─────────       ┌─────────┐
│ ████████│     │ ░░░░░░░░│     Texto            │ ████████│
│ Guardar │     │ Cancelar│     simple           │ Eliminar│
└─────────┘     └─────────┘     ─────────       └─────────┘
 bg: filled      bg: outlined    bg: none         bg: red
```

### 5.3 Diferencias clave

| Aspecto | Property (Prop) | Variant |
|---|---|---|
| **Qué es** | Un parámetro individual | Un conjunto de props predefinido |
| **Granularidad** | Atómica (una dimensión) | Compuesta (múltiples dimensiones) |
| **Flexibilidad** | Alta (cualquier combinación) | Controlada (combinaciones válidas) |
| **Naming** | Descriptivo técnico (`size`, `state`) | Descriptivo semántico (`primary`, `danger`) |
| **En Figma** | Component property | Variant en variant set |
| **En código** | Props individuales | Prop `variant` con valores |

### 5.4 Ejemplos prácticos

**Button — Matriz de propiedades:**

```
             sm              md              lg
          ┌────────┐     ┌──────────┐    ┌────────────┐
Primary   │ Enviar │     │  Enviar  │    │   Enviar   │
          └────────┘     └──────────┘    └────────────┘
          ┌────────┐     ┌──────────┐    ┌────────────┐
Secondary │ Enviar │     │  Enviar  │    │   Enviar   │
          └────────┘     └──────────┘    └────────────┘
          ┌────────┐     ┌──────────┐    ┌────────────┐
Disabled  │ Enviar │     │  Enviar  │    │   Enviar   │
          └────────┘     └──────────┘    └────────────┘

Props:  size × variant × state = Total combinaciones
         3   ×    4    ×  5   = 60 posibles estados
```

**Input — Propiedades:**

```
Componente: TextInput
│
├── Props:
│   ├── label:        string
│   ├── placeholder:  string
│   ├── helperText:   string
│   ├── errorMessage: string
│   ├── size:         "sm" | "md" | "lg"
│   ├── state:        "default" | "focus" | "error" | "success" | "disabled"
│   ├── required:     boolean
│   ├── leadingIcon:  ReactNode | null
│   └── trailingIcon: ReactNode | null
```

### 5.5 Cómo diseñar componentes flexibles

**Principios:**

1. **Diseña para el caso base** → El componente debe funcionar con props mínimas
2. **Extiende con props opcionales** → Cada prop agrega capacidad sin romper el default
3. **Limita las variantes** → Si tienes más de 5 variantes, reconsidera la API
4. **Documenta combinaciones válidas** → No todas las combinaciones de props tienen sentido

```
✅ API limpia:
<Button variant="primary" size="md">Guardar</Button>
<Button variant="destructive" size="sm" icon={<Trash />}>Eliminar</Button>

❌ API confusa:
<Button
  color="red"
  bgColor="#ff0000"
  borderRadius={8}
  fontWeight="bold"
  hoverColor="#cc0000"
>
  Eliminar
</Button>
```

> 💡 **Regla:** Las props de un componente deben ser **semánticas** (qué es), no **estilísticas** (cómo se ve). Usa `variant="destructive"`, no `color="red"`.

---

## 6. Combinación de Componentes

### 6.1 Agrupación lógica

**Intuición**
Los campos relacionados deben agruparse visual y semánticamente. Un formulario largo sin grupos es como un párrafo de 500 palabras sin puntos.

**Form groups y fieldsets:**

```
<fieldset>: Información personal
┌─────────────────────────────────────────┐
│  Nombre          Apellido               │
│  ┌─────────────┐ ┌─────────────┐       │
│  │             │ │             │       │
│  └─────────────┘ └─────────────┘       │
│                                         │
│  Email                                  │
│  ┌─────────────────────────────┐       │
│  │                             │       │
│  └─────────────────────────────┘       │
└─────────────────────────────────────────┘

<fieldset>: Dirección de envío
┌─────────────────────────────────────────┐
│  Calle                                  │
│  ┌─────────────────────────────┐       │
│  │                             │       │
│  └─────────────────────────────┘       │
│                                         │
│  Ciudad          Estado     CP          │
│  ┌───────────┐ ┌─────────┐ ┌─────┐    │
│  │           │ │    ▾    │ │     │    │
│  └───────────┘ └─────────┘ └─────┘    │
└─────────────────────────────────────────┘
```

### 6.2 Layouts: Inline vs Stacked

```
STACKED (vertical):              INLINE (horizontal):
┌────────────────────┐           ┌──────────┐ ┌──────────┐
│ Nombre             │           │ Nombre   │ │ Apellido │
│ ┌────────────────┐ │           │ ┌──────┐ │ │ ┌──────┐ │
│ │                │ │           │ │      │ │ │ │      │ │
│ └────────────────┘ │           │ └──────┘ │ │ └──────┘ │
│                    │           └──────────┘ └──────────┘
│ Apellido           │
│ ┌────────────────┐ │           Usar cuando:
│ │                │ │           → Campos relacionados
│ └────────────────┘ │           → Campos cortos
└────────────────────┘           → Espacio horizontal
                                 → Siempre en desktop
Usar cuando:
→ Formularios simples
→ Mobile first
→ Campos independientes
→ Campos largos
```

**Guía de decisión para layout:**

| Situación | Layout recomendado |
|---|---|
| Nombre + Apellido | Inline |
| Ciudad + Estado + CP | Inline |
| Email | Stacked (full width) |
| Dirección | Stacked (full width) |
| Fecha inicio + Fecha fin | Inline |
| Descripción / textarea | Stacked (full width) |
| Mobile (< 480px) | Siempre stacked |

### 6.3 Componentes compuestos

**Input + Icon:**

```
Buscar                          Precio
┌──────────────────────────┐    ┌──────────────────────────┐
│ 🔍  Buscar productos...  │    │  $  0.00                 │
└──────────────────────────┘    └──────────────────────────┘
 Leading icon                    Leading text (prefix)

Contraseña                      Email
┌──────────────────────────┐    ┌──────────────────────────┐
│  ••••••••          👁    │    │  user@example.com    ✓   │
└──────────────────────────┘    └──────────────────────────┘
 Trailing icon (toggle)          Trailing icon (status)
```

**Input + Button:**

```
Código de descuento              Suscripción a newsletter
┌─────────────────────┬───────┐  ┌────────────────────┬──────────┐
│  SAVE20             │Aplicar│  │  tu@email.com      │Suscribir │
└─────────────────────┴───────┘  └────────────────────┴──────────┘
```

### 6.4 Patrones reutilizables

**Patrón: Dirección completa**

```
Componente: <AddressForm>

┌─────────────────────────────────────────────┐
│ Dirección línea 1                           │
│ ┌─────────────────────────────────────────┐ │
│ │ Calle, número, departamento             │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Dirección línea 2 (opcional)                │
│ ┌─────────────────────────────────────────┐ │
│ │ Edificio, piso, referencia              │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Ciudad            Estado          CP        │
│ ┌─────────────┐  ┌───────────┐  ┌───────┐  │
│ │             │  │     ▾     │  │       │  │
│ └─────────────┘  └───────────┘  └───────┘  │
│                                             │
│ País                                        │
│ ┌─────────────────────────────────────────┐ │
│ │ México                              ▾   │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Patrón: Login**

```
Componente: <LoginForm>

┌─────────────────────────────────────────────┐
│                  [Logo]                      │
│                                             │
│  Inicia sesión en tu cuenta                 │
│                                             │
│  Email                                      │
│  ┌─────────────────────────────────────┐    │
│  │ 📧  tu@email.com                   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Contraseña                ¿Olvidaste?      │
│  ┌─────────────────────────────────────┐    │
│  │ 🔒  ••••••••                   👁  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ☐ Recordar mi sesión                       │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │         Iniciar sesión              │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ─────────── o continuar con ───────────    │
│                                             │
│  [G] Google    [f] Facebook    [→] Apple    │
│                                             │
│  ¿No tienes cuenta? Regístrate              │
└─────────────────────────────────────────────┘
```

---

## 7. Estados y Feedback

### 7.1 Estados de inputs

**Intuición**
Cada campo tiene un "idioma corporal" que comunica al usuario si puede interactuar, si algo salió bien o si hay un problema. Los estados son ese lenguaje visual.

**Los 5 estados fundamentales:**

```
DEFAULT                 FOCUS                   ERROR
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Email            │    │ Email            │    │ Email            │
│ ┌──────────────┐ │    │ ┌──────────────┐ │    │ ┌──────────────┐ │
│ │              │ │    │ │█             │ │    │ │ abc          │ │
│ └──────────────┘ │    │ └──────────────┘ │    │ └──────────────┘ │
│                  │    │                  │    │ ✗ Email inválido │
└──────────────────┘    └──────────────────┘    └──────────────────┘
  border: gray-300        border: blue-500        border: red-500
                          ring: blue-200          text: red-500


SUCCESS                 DISABLED
┌──────────────────┐    ┌──────────────────┐
│ Email            │    │ Email            │
│ ┌──────────────┐ │    │ ┌──────────────┐ │
│ │ user@mail.co │ │    │ │ No editable  │ │
│ └──────────────┘ │    │ └──────────────┘ │
│ ✓ Email válido   │    │                  │
└──────────────────┘    └──────────────────┘
  border: green-500       border: gray-200
  text: green-500         bg: gray-50
                          cursor: not-allowed
```

**Tabla de estilos por estado:**

| Estado | Border | Background | Text | Icon | Cursor |
|---|---|---|---|---|---|
| Default | `gray-300` | `white` | `gray-900` | — | `text` |
| Hover | `gray-400` | `white` | `gray-900` | — | `text` |
| Focus | `blue-500` + ring | `white` | `gray-900` | — | `text` |
| Error | `red-500` | `red-50` | `gray-900` | ✗ red | `text` |
| Success | `green-500` | `green-50` | `gray-900` | ✓ green | `text` |
| Disabled | `gray-200` | `gray-50` | `gray-400` | — | `not-allowed` |

### 7.2 Feedback inmediato vs posterior

| Tipo | Cuándo ocurre | Ejemplo |
|---|---|---|
| **Inmediato** | Mientras el usuario interactúa | Contador de caracteres, validación en tiempo real |
| **On blur** | Al salir del campo | Validación de formato, verificación de disponibilidad |
| **On submit** | Al enviar el formulario | Errores de servidor, validaciones de negocio |
| **Asíncrono** | Después de procesar | Confirmación de email enviado, pago procesado |

**Mejor práctica — Línea temporal del feedback:**

```
Interacción del usuario          Feedback del sistema
─────────────────────           ─────────────────────
Enfoca el campo          →      Resalta el borde (focus ring)
Empieza a escribir       →      Contador de caracteres (si aplica)
Sale del campo           →      Valida formato / contenido
Corrige un error         →      Revalida en tiempo real
Presiona enviar          →      Validación completa + scroll al error
Envío exitoso            →      Toast / redirect / mensaje de éxito
```

### 7.3 Mensajes claros y accionables

**Tres reglas para mensajes de error:**

1. **Di qué pasó** — Describe el problema específico
2. **Di por qué** — Explica la causa (si no es obvia)
3. **Di cómo arreglarlo** — Da instrucciones claras

```
❌ MALO                              ✅ BUENO
───────────────────────              ───────────────────────
"Error"                              "La contraseña debe tener
                                      al menos 8 caracteres"

"Campo inválido"                     "Ingresa un email válido,
                                      ej: nombre@dominio.com"

"Error en el formulario"             "El código postal no existe.
                                      Verifica los 5 dígitos"

"Algo salió mal"                     "No pudimos procesar tu pago.
                                      Intenta con otra tarjeta"
```

### 7.4 Prevención de errores

**Intuición**
El mejor error es el que nunca ocurre. Diseña para prevenir, no solo para corregir.

**Técnicas de prevención:**

| Técnica | Descripción | Ejemplo |
|---|---|---|
| **Constraints** | Limitar valores posibles | `min`, `max`, `maxlength` |
| **Input masking** | Formatear mientras escribe | `(___) ___-____` para teléfono |
| **Smart defaults** | Preseleccionar valores comunes | País según geolocalización |
| **Confirmación** | Doble verificación para acciones críticas | "¿Seguro que deseas eliminar?" |
| **Undo** | Permitir deshacer en vez de confirmar | "Mensaje eliminado. [Deshacer]" |
| **Autocomplete** | Sugerir valores válidos | Dirección con Google Maps API |

---

## 8. Usabilidad y Accesibilidad

### 8.1 Labels claros y visibles

**Regla #1 de formularios accesibles: Todo campo necesita un label visible.**

```
❌ MAL: Solo placeholder               ✅ BIEN: Label + placeholder
┌──────────────────────┐               Email
│  Email               │               ┌──────────────────────┐
└──────────────────────┘               │  ejemplo@mail.com    │
                                       └──────────────────────┘
Problemas:                             Ventajas:
→ Desaparece al escribir              → Siempre visible
→ Bajo contraste (gris claro)         → Contexto permanente
→ Screen readers confusos             → Accesible
```

**Buenas prácticas para labels:**

- Cortos y descriptivos: "Email" > "Por favor ingrese su dirección de correo electrónico"
- Posición: arriba del campo (mejor scaneo) o a la izquierda (formularios densos)
- Indicar campos obligatorios: "Email *" o "(obligatorio)"
- Indicar campos opcionales: "Teléfono (opcional)" — mejor que marcar los obligatorios

### 8.2 Uso correcto de placeholders

| Uso del placeholder | ¿Correcto? |
|---|---|
| Como ejemplo de formato | ✅ `ej: nombre@dominio.com` |
| Como instrucción breve | ⚠️ Solo si hay label visible |
| Como reemplazo de label | ❌ Nunca |
| Información crítica | ❌ Desaparece al escribir |

### 8.3 Navegación con teclado

**Flujo esperado de tabulación:**

```
[Tab] →  Campo 1 (focus)
[Tab] →  Campo 2 (focus)
[Tab] →  Campo 3 (focus)
  ...
[Tab] →  Botón submit (focus)
[Enter] → Enviar formulario

Dentro de radio buttons:
[Tab]  →  Entra al grupo
[↑][↓] →  Navega entre opciones
[Tab]  →  Sale del grupo

Dentro de select:
[Tab]   →  Enfoca el select
[Space] →  Abre el dropdown
[↑][↓]  →  Navega opciones
[Enter] →  Selecciona
[Esc]   →  Cierra sin seleccionar
```

**Checklist de navegación por teclado:**
- ✅ Todos los campos son accesibles con Tab
- ✅ El orden de tabulación es lógico (visual = DOM)
- ✅ Focus visible en todos los elementos interactivos
- ✅ Enter envía el formulario (cuando es apropiado)
- ✅ Escape cierra dropdowns y modals
- ✅ No hay trampas de foco (keyboard traps)

### 8.4 Tamaños táctiles

**Mínimos para touch targets (WCAG 2.5.8):**

```
          MÍNIMO          RECOMENDADO       IDEAL
         ┌──────┐        ┌────────┐       ┌──────────┐
         │ 24px │        │  44px  │       │   48px   │
         │      │        │        │       │          │
         └──────┘        └────────┘       └──────────┘

Para checkboxes y radios, el touch target incluye el label:

         ☐ Checkbox      ← El área clickeable es todo esto →
         ┌──────────────────────────────────────────┐
         │  ☐  Acepto los términos y condiciones    │  44px min
         └──────────────────────────────────────────┘
```

**Spacing entre targets táctiles:**

```
❌ MAL: Sin espacio              ✅ BIEN: Con espacio
┌────────┐┌────────┐            ┌────────┐  ┌────────┐
│ Botón 1││ Botón 2│            │ Botón 1│  │ Botón 2│
└────────┘└────────┘            └────────┘  └────────┘
                                    8px+ gap
Taps accidentales               Taps precisos
```

### 8.5 ARIA y accesibilidad

**Atributos ARIA esenciales para formularios:**

```html
<!-- Label asociado correctamente -->
<label for="email">Email</label>
<input
  id="email"
  type="email"
  aria-required="true"
  aria-describedby="email-help email-error"
  aria-invalid="true"
/>
<span id="email-help">Usaremos tu email para enviar confirmación</span>
<span id="email-error" role="alert">Ingresa un email válido</span>

<!-- Grupo de campos relacionados -->
<fieldset>
  <legend>Método de pago</legend>
  <input type="radio" name="payment" id="card" />
  <label for="card">Tarjeta de crédito</label>
  <input type="radio" name="payment" id="paypal" />
  <label for="paypal">PayPal</label>
</fieldset>

<!-- Estado de carga en botón -->
<button
  type="submit"
  aria-busy="true"
  aria-label="Enviando formulario"
>
  <span class="spinner"></span> Enviando...
</button>
```

**Atributos ARIA clave:**

| Atributo | Uso |
|---|---|
| `aria-required` | Indica campo obligatorio |
| `aria-invalid` | Indica que el valor es inválido |
| `aria-describedby` | Conecta con helper text o error |
| `aria-label` | Label invisible (solo para screen readers) |
| `aria-live="polite"` | Anuncia cambios dinámicos |
| `role="alert"` | Anuncia errores inmediatamente |
| `aria-busy` | Indica que un proceso está en curso |

### 8.6 Minimizar carga cognitiva

**Principios:**

```
1. MENOS CAMPOS = MENOS ESFUERZO
   Cada campo es una decisión. Reduce decisiones.

2. AGRUPACIÓN LÓGICA
   Cerebro procesa grupos, no listas.

   ❌  15 campos seguidos
   ✅  3 grupos de 5 campos

3. UN TEMA POR PANTALLA
   En multi-step, cada paso tiene un propósito.

4. VALORES POR DEFECTO
   Pre-selecciona lo más común.

5. LENGUAJE HUMANO
   "¿Cómo te llamas?" > "Ingrese nombre completo (requerido)"

6. PROGRESO VISIBLE
   "Paso 2 de 4" reduce ansiedad.
```

---

## 9. Diseño de Formularios Complejos

### 9.1 Multi-step forms

**Intuición**
Cuando un formulario tiene más de 6-8 campos, dividirlo en pasos reduce la percepción de complejidad. El usuario ve 3 campos a la vez, no 15.

**Estructura:**

```
Paso 1 de 3: Tu cuenta        Paso 2 de 3: Tu perfil         Paso 3 de 3: Confirmación
●━━━━━━━○━━━━━━━○              ●━━━━━━━●━━━━━━━○              ●━━━━━━━●━━━━━━━●

┌─────────────────────┐        ┌─────────────────────┐        ┌─────────────────────┐
│ Email               │        │ Nombre              │        │ Resumen:            │
│ ┌─────────────────┐ │        │ ┌─────────────────┐ │        │                     │
│ │                 │ │        │ │                 │ │        │ Email: user@mail.co │
│ └─────────────────┘ │        │ └─────────────────┘ │        │ Nombre: Juan García │
│                     │        │                     │        │ Plan: Pro           │
│ Contraseña          │        │ Foto de perfil      │        │                     │
│ ┌─────────────────┐ │        │ ┌─────────────────┐ │        │ ☐ Acepto términos   │
│ │                 │ │        │ │   📷 Subir      │ │        │                     │
│ └─────────────────┘ │        │ └─────────────────┘ │        │                     │
│                     │        │                     │        │                     │
│         [Continuar] │        │ [Atrás] [Continuar] │        │ [Atrás] [Confirmar] │
└─────────────────────┘        └─────────────────────┘        └─────────────────────┘
```

**Reglas para multi-step:**

1. **3-5 pasos máximo** — Más de 5 y el usuario siente que nunca termina
2. **Barra de progreso visible** — Siempre mostrar en qué paso están
3. **Permitir regresar** — Nunca bloquear el botón "Atrás"
4. **Validar por paso** — No dejar avanzar con errores
5. **Guardar progreso** — Si el usuario cierra y vuelve, no pierde todo
6. **Resumen al final** — Permitir revisar antes de confirmar

### 9.2 Formularios largos (single page)

**Cuándo NO usar multi-step:**
- Formularios de configuración (el usuario salta entre secciones)
- Formularios de edición (el usuario modifica campos específicos)
- Formularios internos (usuarios expertos que los llenan seguido)

**Estrategias para formularios largos en una sola página:**

```
┌─ NAVEGACIÓN LATERAL ──┐  ┌─ CONTENIDO ─────────────────────────────┐
│                        │  │                                         │
│  ● Información básica  │  │  Información básica                     │
│  ○ Dirección           │  │  ─────────────────                      │
│  ○ Método de pago      │  │  Nombre     Apellido                    │
│  ○ Preferencias        │  │  ┌────────┐ ┌────────┐                  │
│                        │  │  │        │ │        │                  │
│                        │  │  └────────┘ └────────┘                  │
│                        │  │                                         │
│                        │  │  Email                                  │
│                        │  │  ┌─────────────────┐                    │
│                        │  │  │                 │                    │
│                        │  │  └─────────────────┘                    │
│                        │  │                                         │
│                        │  │  Dirección                              │
│                        │  │  ─────────                              │
│                        │  │  ...                                    │
└────────────────────────┘  └─────────────────────────────────────────┘
```

- Secciones colapsables con anclas
- Navegación lateral sticky
- "Guardar" por sección, no solo al final
- Indicar secciones completadas vs pendientes

### 9.3 Progressive disclosure

**Intuición**
Muestra solo lo necesario ahora. Revela complejidad cuando el usuario la necesita.

```
Estado inicial:                     Después de seleccionar "Otro":
┌─────────────────────────────┐     ┌─────────────────────────────┐
│ ¿Cómo nos encontraste?     │     │ ¿Cómo nos encontraste?     │
│ ┌─────────────────────────┐ │     │ ┌─────────────────────────┐ │
│ │ Otro                  ▾ │ │     │ │ Otro                  ▾ │ │
│ └─────────────────────────┘ │     │ └─────────────────────────┘ │
│                             │     │                             │
│                             │     │ Cuéntanos más               │  ← Aparece
│                             │     │ ┌─────────────────────────┐ │     condicionalmente
│                             │     │ │                         │ │
│                             │     │ └─────────────────────────┘ │
└─────────────────────────────┘     └─────────────────────────────┘
```

### 9.4 Conditional logic (mostrar/ocultar campos)

**Patrones comunes:**

```
Tipo de envío:
  ○ Estándar (gratis)
  ● Express ($9.99)
     └─→ Se revela:
         ┌─────────────────────────────────┐
         │ Horario de entrega preferido     │
         │ ┌──────────────────────────────┐│
         │ │ Mañana (9-12)             ▾ ││
         │ └──────────────────────────────┘│
         │ Instrucciones especiales         │
         │ ┌──────────────────────────────┐│
         │ │                              ││
         │ └──────────────────────────────┘│
         └─────────────────────────────────┘
```

**Reglas de conditional logic:**

1. **Animar la aparición** — No insertes campos sin transición (slide down, fade in)
2. **Limpiar datos ocultos** — Si el usuario cambia de opción, limpia los campos que se ocultan
3. **No ocultar campos ya completados** — Si el usuario llenó algo, no lo escondas sin aviso
4. **Mantener contexto** — El campo revelado debe estar visualmente conectado a lo que lo activó

### 9.5 Guardado automático (Autosave)

**Cuándo usar autosave:**
- Formularios largos o multi-step
- Editores de contenido (blog posts, documentos)
- Configuraciones de perfil
- Cualquier formulario donde perder datos sea costoso

**Patrones de autosave:**

```
INDICADOR SUTIL:
┌───────────────────────────────────────┐
│  Configuración de perfil              │
│                               ✓ Guardado  │  ← Estado persistente
│  ...campos...                         │
│                                       │
│                          Guardando... │  ← Durante el guardado
│                          ◌            │
└───────────────────────────────────────┘

GUARDADO POR CAMPO (on blur):
→ El usuario sale del campo
→ Se guarda automáticamente ese campo
→ Micro-feedback: ✓ junto al campo

GUARDADO PERIÓDICO:
→ Cada 30 segundos se guarda un borrador
→ Indicador: "Borrador guardado hace 30s"
→ Similar a Google Docs
```

> ⚠️ **Anti-patrón:** Autosave sin indicador. El usuario no sabe si sus cambios se guardaron y presiona "Guardar" repetidamente.

---

## 10. Design Systems y Escalabilidad

### 10.1 Librerías de componentes

**Intuición**
Una librería de componentes de formulario es como una caja de herramientas estandarizada. En vez de crear un input desde cero en cada página, tomas el componente `<TextField>` ya diseñado, testeado y accesible.

**Estructura de una librería de form components:**

```
form-components/
├── primitives/
│   ├── Label/
│   ├── Input/
│   ├── HelperText/
│   └── ErrorMessage/
│
├── components/
│   ├── TextField/           → Label + Input + Helper + Error
│   ├── TextArea/
│   ├── Select/
│   ├── Checkbox/
│   ├── RadioGroup/
│   ├── Switch/
│   ├── Slider/
│   ├── DatePicker/
│   ├── FileUpload/
│   ├── Autocomplete/
│   └── Button/
│
├── patterns/
│   ├── FormGroup/           → Fieldset + Legend + children
│   ├── FormActions/         → Container para botones
│   ├── AddressForm/
│   ├── LoginForm/
│   └── SearchBar/
│
└── utilities/
    ├── useFormValidation/
    ├── useAutosave/
    └── formTokens.ts
```

### 10.2 Tokens de diseño para formularios

**Tokens específicos para form components:**

```css
/* ===== FORM TOKENS ===== */

/* --- Sizing --- */
--form-input-height-sm: 32px;
--form-input-height-md: 40px;
--form-input-height-lg: 48px;

--form-input-padding-x: 12px;
--form-input-padding-y: 8px;

--form-label-gap: 4px;          /* Espacio entre label e input */
--form-field-gap: 16px;         /* Espacio entre campos */
--form-group-gap: 32px;         /* Espacio entre grupos */

/* --- Border --- */
--form-border-width: 1px;
--form-border-radius: 6px;
--form-focus-ring-width: 3px;

/* --- Colors por estado --- */
--form-border-default: var(--color-gray-300);
--form-border-hover: var(--color-gray-400);
--form-border-focus: var(--color-blue-500);
--form-border-error: var(--color-red-500);
--form-border-success: var(--color-green-500);
--form-border-disabled: var(--color-gray-200);

--form-bg-default: var(--color-white);
--form-bg-error: var(--color-red-50);
--form-bg-success: var(--color-green-50);
--form-bg-disabled: var(--color-gray-50);

--form-text-label: var(--color-gray-700);
--form-text-input: var(--color-gray-900);
--form-text-placeholder: var(--color-gray-400);
--form-text-helper: var(--color-gray-500);
--form-text-error: var(--color-red-600);
--form-text-success: var(--color-green-600);

/* --- Typography --- */
--form-font-label: var(--font-size-sm);       /* 14px */
--form-font-input: var(--font-size-base);     /* 16px */
--form-font-helper: var(--font-size-xs);      /* 12px */
--form-font-error: var(--font-size-xs);       /* 12px */

/* --- Focus ring --- */
--form-focus-ring-color: var(--color-blue-200);
--form-focus-ring-offset: 2px;

/* --- Button specific --- */
--btn-height-sm: 32px;
--btn-height-md: 40px;
--btn-height-lg: 48px;
--btn-padding-x-sm: 12px;
--btn-padding-x-md: 16px;
--btn-padding-x-lg: 24px;
--btn-border-radius: 6px;
```

### 10.3 Naming conventions

**Para componentes:**

| Nivel | Convención | Ejemplo |
|---|---|---|
| **Componente** | PascalCase | `TextField`, `RadioGroup` |
| **Props** | camelCase | `helperText`, `errorMessage` |
| **Variantes** | kebab-case o string literal | `"primary"`, `"outlined"` |
| **CSS class** | BEM o module | `.text-field__label`, `styles.label` |
| **Token** | kebab-case con prefijo | `--form-border-error` |

**Para archivos:**

```
components/
├── TextField/
│   ├── TextField.tsx          ← Componente principal
│   ├── TextField.test.tsx     ← Tests
│   ├── TextField.stories.tsx  ← Storybook stories
│   ├── TextField.module.css   ← Estilos
│   ├── TextField.types.ts     ← TypeScript types/interfaces
│   └── index.ts               ← Re-export
```

### 10.4 Consistencia cross-product

**Principios de consistencia:**

```
Producto A         Producto B         Producto C
(Web app)          (Mobile app)       (Admin panel)
┌─────────┐        ┌─────────┐        ┌─────────┐
│ Email   │        │ Email   │        │ Email   │
│ ┌─────┐ │        │ ┌─────┐ │        │ ┌─────┐ │
│ │     │ │        │ │     │ │        │ │     │ │
│ └─────┘ │        │ └─────┘ │        │ └─────┘ │
└─────────┘        └─────────┘        └─────────┘

Mismo token         Mismo token        Mismo token
Mismo estado        Mismo estado       Mismo estado
Mismo feedback      Mismo feedback     Mismo feedback
Misma validación    Misma validación   Misma validación
```

**Qué debe ser consistente:**
- ✅ Altura de inputs
- ✅ Colores de estados (error = rojo en todos los productos)
- ✅ Comportamiento de validación
- ✅ Labels: siempre arriba, siempre visibles
- ✅ Mensajes de error: mismo tono y posición
- ✅ Orden de botones (cancelar izquierda, confirmar derecha)

### 10.5 Documentación de componentes

**Estructura de documentación para cada componente:**

```markdown
# TextField

Componente de entrada de texto con label, helper text y validación.

## Props

| Prop          | Type                                    | Default     | Required |
|---------------|-----------------------------------------|-------------|----------|
| label         | string                                  | —           | ✅        |
| placeholder   | string                                  | —           | ❌        |
| helperText    | string                                  | —           | ❌        |
| errorMessage  | string                                  | —           | ❌        |
| size          | "sm" | "md" | "lg"                      | "md"        | ❌        |
| state         | "default" | "error" | "success"         | "default"   | ❌        |
| disabled      | boolean                                 | false       | ❌        |
| required      | boolean                                 | false       | ❌        |

## Uso básico

    <TextField label="Email" placeholder="tu@email.com" />

## Estados

    <TextField label="Email" state="error" errorMessage="Email inválido" />
    <TextField label="Email" state="success" />
    <TextField label="Email" disabled />

## Accesibilidad

- Label siempre asociado al input via `htmlFor`
- `aria-invalid` se aplica cuando `state="error"`
- `aria-describedby` conecta con helperText y errorMessage
- Focus ring visible para navegación por teclado

## Do's and Don'ts

✅ Siempre incluir label visible
✅ Usar helperText para instrucciones
❌ No usar solo placeholder como label
❌ No deshabilitar el submit si hay errores — mejor mostrar los errores
```

---

## 11. Implementación Práctica

### 11.1 HTML semántico para formularios

**Intuición**
HTML semántico = accesibilidad gratis + mejor UX + SEO. Un `<form>` con `<label>` y `<fieldset>` hace más que mil `<div>` con ARIA.

```html
<!-- ✅ Formulario semántico completo -->
<form action="/register" method="POST" novalidate>

  <fieldset>
    <legend>Información personal</legend>

    <div class="form-field">
      <label for="fullName">Nombre completo *</label>
      <input
        type="text"
        id="fullName"
        name="fullName"
        required
        autocomplete="name"
        aria-required="true"
      />
      <span class="helper-text" id="fullName-help">
        Como aparece en tu identificación
      </span>
    </div>

    <div class="form-field">
      <label for="email">Email *</label>
      <input
        type="email"
        id="email"
        name="email"
        required
        autocomplete="email"
        aria-required="true"
        aria-describedby="email-help"
      />
      <span class="helper-text" id="email-help">
        Usaremos tu email para enviar la confirmación
      </span>
    </div>
  </fieldset>

  <fieldset>
    <legend>Seguridad</legend>

    <div class="form-field">
      <label for="password">Contraseña *</label>
      <div class="input-group">
        <input
          type="password"
          id="password"
          name="password"
          required
          minlength="8"
          autocomplete="new-password"
          aria-required="true"
          aria-describedby="password-help"
        />
        <button type="button" class="toggle-password" aria-label="Mostrar contraseña">
          👁
        </button>
      </div>
      <span class="helper-text" id="password-help">
        Mínimo 8 caracteres, una mayúscula y un número
      </span>
    </div>
  </fieldset>

  <fieldset>
    <legend>Preferencias</legend>

    <div class="form-field">
      <label>Plan *</label>
      <div role="radiogroup" aria-label="Selecciona un plan">
        <label>
          <input type="radio" name="plan" value="free" checked /> Gratis
        </label>
        <label>
          <input type="radio" name="plan" value="pro" /> Pro ($9/mes)
        </label>
        <label>
          <input type="radio" name="plan" value="enterprise" /> Enterprise ($29/mes)
        </label>
      </div>
    </div>

    <div class="form-field">
      <label>
        <input type="checkbox" name="terms" required aria-required="true" />
        Acepto los <a href="/terms">términos y condiciones</a>
      </label>
    </div>
  </fieldset>

  <div class="form-actions">
    <a href="/" class="btn-tertiary">Cancelar</a>
    <button type="submit" class="btn-primary">Crear mi cuenta</button>
  </div>

</form>
```

**Atributos `autocomplete` importantes:**

| Atributo | Campo |
|---|---|
| `autocomplete="name"` | Nombre completo |
| `autocomplete="given-name"` | Nombre |
| `autocomplete="family-name"` | Apellido |
| `autocomplete="email"` | Email |
| `autocomplete="tel"` | Teléfono |
| `autocomplete="street-address"` | Dirección |
| `autocomplete="postal-code"` | Código postal |
| `autocomplete="country"` | País |
| `autocomplete="cc-number"` | Número de tarjeta |
| `autocomplete="new-password"` | Nueva contraseña |
| `autocomplete="current-password"` | Contraseña actual |

### 11.2 CSS para form components

```css
/* ===== BASE FORM STYLES ===== */

.form-field {
  display: flex;
  flex-direction: column;
  gap: var(--form-label-gap, 4px);
  margin-bottom: var(--form-field-gap, 16px);
}

/* --- Label --- */
.form-field label {
  font-size: var(--form-font-label, 0.875rem);
  font-weight: 500;
  color: var(--form-text-label, #374151);
}

/* --- Input base --- */
.form-field input,
.form-field select,
.form-field textarea {
  height: var(--form-input-height-md, 40px);
  padding: var(--form-input-padding-y, 8px) var(--form-input-padding-x, 12px);
  border: var(--form-border-width, 1px) solid var(--form-border-default, #d1d5db);
  border-radius: var(--form-border-radius, 6px);
  font-size: var(--form-font-input, 1rem);
  color: var(--form-text-input, #111827);
  background-color: var(--form-bg-default, #ffffff);
  transition: border-color 150ms ease, box-shadow 150ms ease;
}

.form-field textarea {
  height: auto;
  min-height: 100px;
  resize: vertical;
}

/* --- Placeholder --- */
.form-field input::placeholder,
.form-field textarea::placeholder {
  color: var(--form-text-placeholder, #9ca3af);
}

/* --- States --- */
.form-field input:hover,
.form-field select:hover {
  border-color: var(--form-border-hover, #9ca3af);
}

.form-field input:focus,
.form-field select:focus,
.form-field textarea:focus {
  outline: none;
  border-color: var(--form-border-focus, #3b82f6);
  box-shadow: 0 0 0 var(--form-focus-ring-width, 3px) var(--form-focus-ring-color, #bfdbfe);
}

/* Error state */
.form-field.is-error input,
.form-field.is-error select {
  border-color: var(--form-border-error, #ef4444);
  background-color: var(--form-bg-error, #fef2f2);
}

.form-field.is-error input:focus {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.2);
}

/* Success state */
.form-field.is-success input {
  border-color: var(--form-border-success, #22c55e);
  background-color: var(--form-bg-success, #f0fdf4);
}

/* Disabled state */
.form-field input:disabled,
.form-field select:disabled {
  background-color: var(--form-bg-disabled, #f9fafb);
  border-color: var(--form-border-disabled, #e5e7eb);
  color: var(--form-text-placeholder, #9ca3af);
  cursor: not-allowed;
}

/* --- Helper text & Error message --- */
.helper-text {
  font-size: var(--form-font-helper, 0.75rem);
  color: var(--form-text-helper, #6b7280);
}

.error-message {
  font-size: var(--form-font-error, 0.75rem);
  color: var(--form-text-error, #dc2626);
  display: flex;
  align-items: center;
  gap: 4px;
}

.error-message::before {
  content: "✗";
}

.success-message {
  font-size: var(--form-font-helper, 0.75rem);
  color: var(--form-text-success, #16a34a);
}

.success-message::before {
  content: "✓";
}

/* --- Fieldset --- */
fieldset {
  border: none;
  padding: 0;
  margin: 0 0 var(--form-group-gap, 32px) 0;
}

fieldset legend {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 1px solid #e5e7eb;
  width: 100%;
}

/* --- Form actions --- */
.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding-top: 24px;
  border-top: 1px solid #e5e7eb;
}

/* --- Inline fields --- */
.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

@media (max-width: 480px) {
  .form-row {
    grid-template-columns: 1fr;
  }
}
```

### 11.3 Validación en frontend

```javascript
// ===== FORM VALIDATION SYSTEM =====

// Reglas de validación reutilizables
const validators = {
  required: (value) => ({
    valid: value.trim().length > 0,
    message: 'Este campo es obligatorio'
  }),

  email: (value) => ({
    valid: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
    message: 'Ingresa un email válido, ej: nombre@dominio.com'
  }),

  minLength: (min) => (value) => ({
    valid: value.length >= min,
    message: `Debe tener al menos ${min} caracteres`
  }),

  maxLength: (max) => (value) => ({
    valid: value.length <= max,
    message: `No puede tener más de ${max} caracteres`
  }),

  pattern: (regex, message) => (value) => ({
    valid: regex.test(value),
    message
  }),

  password: (value) => ({
    valid: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/.test(value),
    message: 'Mínimo 8 caracteres, una mayúscula y un número'
  }),

  match: (fieldName, getValue) => (value) => ({
    valid: value === getValue(),
    message: `Debe coincidir con ${fieldName}`
  })
};

// Aplicar validaciones a un campo
function validateField(value, rules) {
  for (const rule of rules) {
    const result = rule(value);
    if (!result.valid) return result;
  }
  return { valid: true, message: '' };
}

// Ejemplo de uso
const formRules = {
  fullName: [validators.required, validators.minLength(2)],
  email:    [validators.required, validators.email],
  password: [validators.required, validators.password]
};

// Validate on blur, revalidate on change
function setupValidation(form) {
  const fields = form.querySelectorAll('input, select, textarea');
  const touched = new Set();

  fields.forEach(field => {
    // On blur: primera validación
    field.addEventListener('blur', () => {
      touched.add(field.name);
      showValidation(field);
    });

    // On input: revalidar solo si ya fue tocado
    field.addEventListener('input', () => {
      if (touched.has(field.name)) {
        showValidation(field);
      }
    });
  });

  // On submit: validar todo
  form.addEventListener('submit', (e) => {
    let isValid = true;
    fields.forEach(field => {
      touched.add(field.name);
      if (!showValidation(field)) isValid = false;
    });
    if (!isValid) {
      e.preventDefault();
      // Scroll al primer error
      const firstError = form.querySelector('.is-error input');
      if (firstError) firstError.focus();
    }
  });
}

function showValidation(field) {
  const rules = formRules[field.name];
  if (!rules) return true;

  const result = validateField(field.value, rules);
  const wrapper = field.closest('.form-field');
  const errorEl = wrapper.querySelector('.error-message');

  if (result.valid) {
    wrapper.classList.remove('is-error');
    wrapper.classList.add('is-success');
    if (errorEl) errorEl.textContent = '';
    field.setAttribute('aria-invalid', 'false');
  } else {
    wrapper.classList.add('is-error');
    wrapper.classList.remove('is-success');
    if (errorEl) errorEl.textContent = result.message;
    field.setAttribute('aria-invalid', 'true');
  }

  return result.valid;
}
```

### 11.4 React: Formulario completo con manejo de estado

```jsx
// ===== REACT FORM COMPONENT =====
import { useState, useCallback } from 'react';

// Hook reutilizable para forms
function useForm(initialValues, validationRules) {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState({});
  const [touched, setTouched] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const validate = useCallback((name, value) => {
    const rules = validationRules[name];
    if (!rules) return '';

    for (const rule of rules) {
      const result = rule(value);
      if (!result.valid) return result.message;
    }
    return '';
  }, [validationRules]);

  const handleChange = useCallback((e) => {
    const { name, value, type, checked } = e.target;
    const fieldValue = type === 'checkbox' ? checked : value;

    setValues(prev => ({ ...prev, [name]: fieldValue }));

    // Revalidar si ya fue tocado
    if (touched[name]) {
      setErrors(prev => ({ ...prev, [name]: validate(name, fieldValue) }));
    }
  }, [touched, validate]);

  const handleBlur = useCallback((e) => {
    const { name, value } = e.target;
    setTouched(prev => ({ ...prev, [name]: true }));
    setErrors(prev => ({ ...prev, [name]: validate(name, value) }));
  }, [validate]);

  const handleSubmit = useCallback((onSubmit) => async (e) => {
    e.preventDefault();

    // Validar todos los campos
    const newErrors = {};
    let isValid = true;

    for (const [name, value] of Object.entries(values)) {
      const error = validate(name, value);
      if (error) {
        newErrors[name] = error;
        isValid = false;
      }
    }

    setErrors(newErrors);
    setTouched(Object.keys(values).reduce((acc, key) => ({ ...acc, [key]: true }), {}));

    if (isValid) {
      setIsSubmitting(true);
      try {
        await onSubmit(values);
      } catch (err) {
        // Manejar errores de servidor
        if (err.fieldErrors) {
          setErrors(prev => ({ ...prev, ...err.fieldErrors }));
        }
      } finally {
        setIsSubmitting(false);
      }
    }
  }, [values, validate]);

  return { values, errors, touched, isSubmitting, handleChange, handleBlur, handleSubmit };
}

// Componente TextField reutilizable
function TextField({
  label, name, type = 'text', placeholder, helperText,
  required, error, touched, ...inputProps
}) {
  const showError = touched && error;
  const showSuccess = touched && !error;

  return (
    <div className={`form-field ${showError ? 'is-error' : ''} ${showSuccess ? 'is-success' : ''}`}>
      <label htmlFor={name}>
        {label} {required && <span aria-hidden="true">*</span>}
      </label>
      <input
        id={name}
        name={name}
        type={type}
        placeholder={placeholder}
        aria-required={required}
        aria-invalid={showError}
        aria-describedby={`${name}-help ${name}-error`}
        {...inputProps}
      />
      {helperText && !showError && (
        <span className="helper-text" id={`${name}-help`}>{helperText}</span>
      )}
      {showError && (
        <span className="error-message" id={`${name}-error`} role="alert">
          {error}
        </span>
      )}
    </div>
  );
}

// Ejemplo de uso: Registration Form
function RegistrationForm() {
  const { values, errors, touched, isSubmitting, handleChange, handleBlur, handleSubmit } = useForm(
    { fullName: '', email: '', password: '', terms: false },
    {
      fullName: [
        v => ({ valid: v.trim().length > 0, message: 'El nombre es obligatorio' }),
        v => ({ valid: v.trim().length >= 2, message: 'Mínimo 2 caracteres' })
      ],
      email: [
        v => ({ valid: v.trim().length > 0, message: 'El email es obligatorio' }),
        v => ({ valid: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v), message: 'Email inválido' })
      ],
      password: [
        v => ({ valid: v.length > 0, message: 'La contraseña es obligatoria' }),
        v => ({
          valid: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/.test(v),
          message: 'Mínimo 8 caracteres, una mayúscula y un número'
        })
      ],
      terms: [
        v => ({ valid: v === true, message: 'Debes aceptar los términos' })
      ]
    }
  );

  const onSubmit = async (formData) => {
    const response = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData)
    });
    if (!response.ok) throw await response.json();
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <fieldset>
        <legend>Crear cuenta</legend>

        <TextField
          label="Nombre completo"
          name="fullName"
          placeholder="Juan García"
          required
          value={values.fullName}
          error={errors.fullName}
          touched={touched.fullName}
          onChange={handleChange}
          onBlur={handleBlur}
          autoComplete="name"
        />

        <TextField
          label="Email"
          name="email"
          type="email"
          placeholder="tu@email.com"
          required
          helperText="No compartiremos tu email"
          value={values.email}
          error={errors.email}
          touched={touched.email}
          onChange={handleChange}
          onBlur={handleBlur}
          autoComplete="email"
        />

        <TextField
          label="Contraseña"
          name="password"
          type="password"
          required
          helperText="Mínimo 8 caracteres, una mayúscula y un número"
          value={values.password}
          error={errors.password}
          touched={touched.password}
          onChange={handleChange}
          onBlur={handleBlur}
          autoComplete="new-password"
        />

        <div className="form-field">
          <label>
            <input
              type="checkbox"
              name="terms"
              checked={values.terms}
              onChange={handleChange}
              onBlur={handleBlur}
              aria-required="true"
            />
            Acepto los <a href="/terms">términos y condiciones</a>
          </label>
          {touched.terms && errors.terms && (
            <span className="error-message" role="alert">{errors.terms}</span>
          )}
        </div>
      </fieldset>

      <div className="form-actions">
        <button type="button" className="btn-tertiary">Cancelar</button>
        <button type="submit" className="btn-primary" disabled={isSubmitting}>
          {isSubmitting ? '◌ Creando cuenta...' : 'Crear mi cuenta'}
        </button>
      </div>
    </form>
  );
}
```

---

## 12. Nivel Intermedio / Avanzado

### 12.1 Sistemas de formularios complejos (SaaS)

**Intuición**
En aplicaciones SaaS, los formularios no son páginas aisladas. Son sistemas interconectados: un formulario de onboarding alimenta la configuración, que alimenta el dashboard, que alimenta los reportes. Diseñar formularios en SaaS es diseñar flujos de datos completos.

**Patrones comunes en SaaS:**

```
ONBOARDING WIZARD                    SETTINGS PAGE
(Multi-step, one-time)               (Sections, persistent)
┌─────────────────────┐              ┌──────────┬────────────────────┐
│ ●─○─○─○             │              │ General  │ Nombre de empresa  │
│                     │              │ Billing  │ ┌──────────────┐   │
│ ¿Cómo usarás       │              │ Team     │ │ Acme Corp    │   │
│ la plataforma?      │              │ Security │ └──────────────┘   │
│                     │              │ API      │                    │
│ ○ Personal          │              │ Notif.   │ Timezone           │
│ ● Equipo            │              │          │ ┌──────────────┐   │
│ ○ Enterprise        │              │          │ │ UTC-6      ▾ │   │
│                     │              │          │ └──────────────┘   │
│      [Continuar →]  │              │          │                    │
└─────────────────────┘              │          │     [Guardar]      │
                                     └──────────┴────────────────────┘

INLINE EDITING                       BULK OPERATIONS
(Edit in place)                      (Table with forms)
┌─────────────────────────────┐      ┌────┬───────────┬──────┬──────┐
│ Nombre del proyecto          │      │ ☑  │ Nombre    │ Rol  │ ...  │
│ ┌────────────────────┐  ✏️  │      ├────┼───────────┼──────┼──────┤
│ │ Mi proyecto        │      │      │ ☑  │ Juan      │ Admin│ ...  │
│ └────────────────────┘      │      │ ☐  │ María     │ Edit │ ...  │
│                              │      │ ☑  │ Carlos    │ View │ ...  │
│ Click en ✏️ → se vuelve     │      ├────┴───────────┴──────┴──────┤
│ input editable in situ       │      │ 2 seleccionados:            │
└─────────────────────────────┘      │ [Cambiar rol ▾] [Eliminar]  │
                                     └───────────────────────────────┘
```

### 12.2 Optimización de conversión

**Principios de CRO (Conversion Rate Optimization) aplicados a formularios:**

```
TÉCNICA                    IMPACTO TÍPICO
──────────────────────────────────────────
Reducir campos             +25-40% completion
Social login               +20-30% signup rate
Progress indicator         +15-20% multi-step
Inline validation          +10-15% completion
Smart defaults             +10-20% speed
Remove captcha             +5-10% completion
Single column layout       +5-15% completion
Specific CTA text          +5-10% click rate
```

**Checklist de optimización:**

1. **Eliminar campos** — ¿Puedes pedir el dato después?
2. **Defaults inteligentes** — Precarga país, moneda, idioma
3. **Social login** — Google/Apple login reduce fricción un 30%+
4. **Un CTA claro** — Solo un botón primario por formulario
5. **Eliminar distracciones** — Ocultar navegación en checkout
6. **Trust signals** — Candado, "datos seguros", logos de seguridad
7. **Microcopy** — "No spam, lo prometemos" junto al email

**Ejemplo: Optimización de checkout**

```
ANTES (6 pasos):                      DESPUÉS (3 pasos):
1. Cuenta                             1. Email + Dirección
2. Dirección de envío                    (autocomplete con Google)
3. Dirección de facturación           2. Pago
4. Método de envío                       (☐ Igual a envío)
5. Pago                               3. Confirmación
6. Confirmación

Completion: ~35%                      Completion: ~68%
```

### 12.3 Testing de formularios

**A/B Testing — Qué testear:**

| Variable | Variante A | Variante B | Métrica |
|---|---|---|---|
| # de campos | 5 campos | 3 campos | Completion rate |
| Layout | 2 columnas | 1 columna | Error rate |
| CTA text | "Enviar" | "Crear mi cuenta" | Click rate |
| Validación | On submit | On blur | Error rate |
| Social login | Sin | Con Google | Signup rate |
| Progress bar | Sin | Con | Multi-step completion |
| Required indicator | Asterisco (*) | "(obligatorio)" | Error rate |

**Métricas clave para monitorear:**

```
FUNNEL DE FORMULARIO:

Visitas a la página  ─── 100% ──→  10,000 usuarios
        │
        ▼
Inicio del form      ─── 70%  ──→   7,000 usuarios
        │                            ↑ 30% no empiezan
        ▼                            (¿formulario intimidante?)
Campo 1 completado   ─── 65%  ──→   6,500 usuarios
Campo 2 completado   ─── 58%  ──→   5,800 usuarios
Campo 3 completado   ─── 50%  ──→   5,000 usuarios
        │                            ↑ Drop-off por campo
        ▼                            (¿campo problemático?)
Submit exitoso       ─── 40%  ──→   4,000 usuarios
        │                            ↑ 10% fallan validación
        ▼
Conversión final     ─── 38%  ──→   3,800 usuarios
```

**Herramientas para testing:**
- **Hotjar / Microsoft Clarity** — Grabaciones de sesiones, heatmaps en formularios
- **Google Analytics / Mixpanel** — Funnel analysis, drop-off por campo
- **Optimizely / VWO** — A/B testing
- **Sentry / LogRocket** — Errores de JS en formularios

### 12.4 Adaptación Mobile vs Desktop

**Diferencias clave:**

| Aspecto | Desktop | Mobile |
|---|---|---|
| **Layout** | Inline posible (2 cols) | Siempre stacked (1 col) |
| **Input height** | 40px | 48px (touch friendly) |
| **Teclado** | Siempre visible | Virtual, ocupa 50% pantalla |
| **Input type** | Menos impacto | Crítico (email → @, tel → numérico) |
| **Autocomplete** | Conveniente | Esencial |
| **Validación** | On blur funciona | On blur + indicadores visuales grandes |
| **CTA** | En la fila de acciones | Full width, sticky al fondo |
| **File upload** | Drag & drop + click | Click + cámara |

**Mobile form patterns:**

```
DESKTOP:                              MOBILE:
┌──────────────────────────────┐     ┌─────────────────────┐
│ Nombre      Apellido         │     │ Paso 1 de 3         │
│ ┌────────┐ ┌────────┐       │     │ ●━━━○━━━○           │
│ │        │ │        │       │     │                     │
│ └────────┘ └────────┘       │     │ Nombre              │
│                              │     │ ┌─────────────────┐ │
│ Email                        │     │ │                 │ │
│ ┌──────────────────────────┐ │     │ └─────────────────┘ │
│ │                          │ │     │                     │
│ └──────────────────────────┘ │     │ Apellido            │
│                              │     │ ┌─────────────────┐ │
│ Dirección                    │     │ │                 │ │
│ ┌──────────────────────────┐ │     │ └─────────────────┘ │
│ │                          │ │     │                     │
│ └──────────────────────────┘ │     │ Email               │
│                              │     │ ┌─────────────────┐ │
│ Ciudad    Estado      CP     │     │ │                 │ │
│ ┌──────┐ ┌──────┐ ┌──────┐  │     │ └─────────────────┘ │
│ │      │ │   ▾  │ │      │  │     │                     │
│ └──────┘ └──────┘ └──────┘  │     │ ┌─────────────────┐ │
│                              │     │ │   Continuar →   │ │
│     [Cancelar]  [Guardar]    │     │ └─────────────────┘ │
└──────────────────────────────┘     └─────────────────────┘
                                     Full-width, sticky CTA
```

**Input types para mobile:**

```html
<!-- Teclado optimizado en mobile -->
<input type="email" />    → Muestra @ y .com en el teclado
<input type="tel" />      → Muestra teclado numérico
<input type="url" />      → Muestra .com, / y :
<input type="number" />   → Muestra teclado numérico
<input type="search" />   → Muestra botón "Buscar" en teclado

<!-- Atributo inputmode para más control -->
<input type="text" inputmode="numeric" />     → Numérico sin spinners
<input type="text" inputmode="decimal" />     → Numérico con punto decimal
<input type="text" inputmode="tel" />         → Teclado de teléfono
```

---

## Cheat Sheet — Forms & UI Elements

```
┌─────────────────────────────────────────────────────────────────┐
│                    FORM DESIGN CHEAT SHEET                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ANATOMÍA DE UN CAMPO:                                          │
│  Label → Input → Helper Text → Validation Message               │
│                                                                 │
│  SELECCIÓN DE INPUT:                                            │
│  Texto corto → text        Opciones 2-5 → radio                │
│  Texto largo → textarea    Opciones 5-15 → select              │
│  Email → email             Opciones 15+ → autocomplete         │
│  Teléfono → tel            Múltiple → checkboxes / multi-select│
│  Contraseña → password     Rango → slider                      │
│  Numérico → number         Sí/No → checkbox / toggle           │
│                                                                 │
│  BOTONES (jerarquía):                                           │
│  Primary → Acción principal (1 por grupo)                       │
│  Secondary → Alternativa                                        │
│  Tertiary → Acción menor (cancelar)                             │
│  Destructive → Acción peligrosa (eliminar)                      │
│                                                                 │
│  ESTADOS:                                                       │
│  Default → Hover → Focus → Error/Success → Disabled             │
│                                                                 │
│  VALIDACIÓN:                                                    │
│  On blur (primera vez) → On change (revalidar) → On submit      │
│                                                                 │
│  ACCESIBILIDAD:                                                 │
│  ✅ Label visible siempre    ✅ Focus ring visible               │
│  ✅ aria-required/invalid    ✅ Touch target ≥ 44px              │
│  ✅ autocomplete attrs       ✅ Keyboard navigation              │
│  ✅ role="alert" en errores  ✅ fieldset + legend                │
│                                                                 │
│  REDUCCIÓN DE FRICCIÓN:                                         │
│  → Menos campos posibles     → Smart defaults                   │
│  → Autocomplete habilitado   → Progressive disclosure            │
│  → Social login              → Input masks                      │
│  → Specific CTA text         → Autosave en forms largos         │
│                                                                 │
│  MOBILE:                                                        │
│  → Stacked layout            → Input type correcto              │
│  → 48px touch targets        → Sticky CTA                      │
│  → inputmode attribute       → Full-width inputs                │
│                                                                 │
│  ANTI-PATRONES:                                                 │
│  ❌ Placeholder como label   ❌ Validar desde el 1er carácter   │
│  ❌ "Submit" genérico        ❌ Formulario sin feedback          │
│  ❌ Todos los botones iguales ❌ Campos innecesarios             │
│  ❌ Sin indicador de guardado ❌ Keyboard traps                  │
│  ❌ Disable submit por errores ❌ Errores vagos ("Error")        │
│                                                                 │
│  MÉTRICAS:                                                      │
│  Completion rate | Drop-off rate | Error rate | Time to complete │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Errores Comunes y Decisiones Incorrectas

| # | Error | Por qué es malo | Solución |
|---|---|---|---|
| 1 | Formularios con 10+ campos al registro | Drop-off > 70% | Pedir solo lo esencial, completar después |
| 2 | Solo placeholder, sin label | Inaccesible, se pierde contexto | Label siempre visible arriba del input |
| 3 | Validación solo al enviar | Usuario no sabe qué corregir hasta el final | Validate on blur, revalidate on change |
| 4 | Mensajes de error genéricos | "Error" no dice qué pasó ni cómo arreglarlo | Mensajes específicos y accionables |
| 5 | Deshabilitar el botón submit | El usuario no sabe por qué no puede enviar | Permitir submit, mostrar errores |
| 6 | Inputs sin tipo correcto en mobile | Teclado incorrecto, más errores | `type="email"`, `type="tel"`, `inputmode` |
| 7 | Mismo estilo para todos los botones | No hay jerarquía, el usuario no sabe qué hacer | Primary / Secondary / Tertiary |
| 8 | No guardar progreso en forms largos | Pérdida de datos = usuario frustrado | Autosave o guardar borrador |
| 9 | Conditional logic sin animación | Campos aparecen/desaparecen bruscamente | Transiciones suaves (slide, fade) |
| 10 | No testear en mobile | 60%+ del tráfico es mobile | Mobile-first design y testing |

---

> **Referencia rápida de tokens de formulario:**
> - Input height: `32px` (sm) / `40px` (md) / `48px` (lg)
> - Touch target: mínimo `44px`, ideal `48px`
> - Field gap: `16px` / Group gap: `32px`
> - Focus ring: `3px`, color `blue-200`
> - Border radius: `6px`
> - Label font: `14px` (sm) / Input font: `16px` (base) / Helper: `12px` (xs)
