# Prototyping — Módulo Completo

---

## 1. Introducción al Prototyping

### 1.1 Qué es un Prototipo y su Propósito

- **Intuición:** Un prototipo es una simulación de tu producto. Así como un director de cine filma una escena de prueba antes de la producción final, un diseñador construye un prototipo para experimentar cómo se sentirá el producto antes de escribir una sola línea de código.
- **Estructura formal:** Un prototipo es una representación interactiva (parcial o completa) de un producto digital que permite **simular comportamiento, flujos y navegación** para validar decisiones de diseño con usuarios reales.
- **Aplicación práctica:** Prototipar reduce el riesgo de construir algo que nadie quiere o que nadie entiende cómo usar. Cada hora invertida en prototipado ahorra potencialmente días de desarrollo y refactoring.

**Propósitos clave:**

1. **Validar flujos** — ¿El usuario completa la tarea sin fricción?
2. **Comunicar ideas** — Mostrar al equipo y stakeholders exactamente cómo funcionará
3. **Detectar problemas** — Encontrar puntos de confusión antes de que sean costosos
4. **Tomar decisiones** — Elegir entre alternativas con datos, no con opiniones
5. **Alinear expectativas** — Developers, PMs y clientes ven lo mismo

### 1.2 Wireframe vs Mockup vs Prototipo

| Aspecto | Wireframe | Mockup | Prototipo |
|---|---|---|---|
| **Fidelidad visual** | Baja (grises, bloques) | Alta (colores, tipografía, imágenes) | Variable (low → high) |
| **Interactividad** | Ninguna | Ninguna | **Sí — navegable, clicable** |
| **Propósito** | Definir estructura y layout | Definir apariencia visual | **Simular experiencia real** |
| **Pregunta que responde** | ¿Qué contenido va dónde? | ¿Cómo se ve? | **¿Cómo se siente usarlo?** |
| **Costo de cambio** | Muy bajo | Medio | Medio-Alto |
| **Testing** | Limitado | Visual only | **Usability testing completo** |

```
Evolución del diseño:

  Sketches → Wireframes → Mockups → Prototipos → Desarrollo
     │           │            │           │
     │       Estructura    Estética   Interacción
     │                                    │
     └────────────────────────────────────┘
              feedback loop constante
```

> **Diferencia crítica:** Un mockup es una foto de una interfaz. Un prototipo es una **experiencia** de esa interfaz. Puedes mirar un mockup, pero puedes *usar* un prototipo.

### 1.3 Rol del Prototipado en el Ciclo de Diseño

```
┌───────────────────────────────────────────────────────────────┐
│                    DESIGN THINKING                            │
│                                                               │
│  Empathize → Define → Ideate → ★ PROTOTYPE ★ → Test          │
│                                      │              │         │
│                                      │              │         │
│                                      └──── loop ────┘         │
│                                                               │
│  El prototipo es el PUENTE entre la idea y la validación.     │
│  Sin prototipo, testear es imposible o poco confiable.        │
└───────────────────────────────────────────────────────────────┘
```

### 1.4 Por qué Prototipar antes de Desarrollar

| Sin prototipo | Con prototipo |
|---|---|
| Descubres problemas de UX en QA o producción | Descubres problemas en horas, no en sprints |
| Cambiar un flujo cuesta semanas de desarrollo | Cambiar un flujo cuesta minutos en Figma |
| Stakeholders dicen "no es lo que imaginaba" al ver el producto | Stakeholders validan antes de que exista código |
| Developers interpretan el diseño a su manera | Developers ven exactamente cómo debe funcionar |
| Decisiones basadas en opiniones | Decisiones basadas en testing con usuarios |

**Costo del cambio según etapa:**

```
                     $$$$$$$$$
                    $$$$$$$
                   $$$$$$
                  $$$$$
Costo           $$$$
del            $$$
cambio        $$
             $
            $
  ──────────────────────────────────────
  Sketch  Wire  Proto  Dev   QA  Prod

  ← Barato                    Caro →

  Prototipar = descubrir errores donde es BARATO corregirlos
```

> **Error común:** "No tenemos tiempo para prototipar". La realidad es que no tienes tiempo para NO prototipar — el costo de reconstruir en desarrollo es 10-100x mayor.

---

## 2. Tipos de Prototipos

### 2.1 Low-Fidelity (Baja Fidelidad)

**Qué es:** Representaciones rápidas y aproximadas centradas en flujo y estructura, no en apariencia.

**Formatos:**

- Sketches en papel
- Post-its con flujos
- Wireframes clicables simples (Balsamiq, Whimsical)
- Presentaciones de slides como "prototipo"

```
Ejemplo: Prototipo en papel de login

  Pantalla 1           Pantalla 2           Pantalla 3
  ┌──────────┐        ┌──────────┐         ┌──────────┐
  │  Logo    │   →    │  Logo    │    →    │  ✓ Bien- │
  │          │  tap   │          │   tap   │  venido!  │
  │ [Email ] │  ───►  │ [Email ] │   ───►  │          │
  │ [Pass  ] │        │ [Pass  ] │         │ [Conti-  │
  │          │        │ ⚠️ Error  │         │  nuar]   │
  │ [Login ] │        │ [Login ] │         │          │
  └──────────┘        └──────────┘         └──────────┘
                      (error state)        (success)
```

**Cuándo usar:**

- Exploración temprana de ideas
- Kick-off de proyecto
- Brainstorming con el equipo
- Validar concepto general (¿tiene sentido este flujo?)

**Tiempo:** Minutos a pocas horas

| ✅ Ventajas | ❌ Limitaciones |
|---|---|
| Extremadamente rápido | No representa la experiencia real |
| Barato de cambiar | Usuarios pueden confundirse con la abstracción |
| Sin herramientas especiales | No valida microinteracciones |
| Excelente para brainstorming | Stakeholders pueden no tomarlo en serio |

### 2.2 Mid-Fidelity (Fidelidad Media)

**Qué es:** Prototipos digitales con interacciones básicas, estructura clara y navegación funcional, pero sin diseño visual final.

**Formatos:**

- Wireframes clicables en Figma/Adobe XD
- Flujos con transiciones entre pantallas
- Formularios funcionales (sin lógica real)

**Cuándo usar:**

- Validar estructura y navegación con usuarios
- Testing de usabilidad temprano
- Demos a equipo interno
- Iterar rápidamente sobre flujos

**Tiempo:** Horas a 1-2 días

| ✅ Ventajas | ❌ Limitaciones |
|---|---|
| Rápido de iterar | No muestra look & feel final |
| Testing de usabilidad efectivo | Clientes pueden pedir "más color" |
| Enfoca la conversación en UX, no UI | No valida microinteracciones complejas |
| Balance ideal entre velocidad y fidelidad | |

### 2.3 High-Fidelity (Alta Fidelidad)

**Qué es:** Prototipos que se ven y se sienten como el producto final — diseño visual completo, interacciones detalladas, datos realistas.

**Formatos:**

- Prototipos interactivos en Figma (con smart animate, variables)
- Prototipos avanzados en Framer o ProtoPie
- Prototipos con código (HTML/CSS/JS, React)

**Cuándo usar:**

- Testing de usabilidad final
- Presentaciones a stakeholders/inversores
- Handoff a desarrollo (referencia visual + interactiva)
- Validación de microinteracciones y animaciones

**Tiempo:** Días a semanas

| ✅ Ventajas | ❌ Limitaciones |
|---|---|
| Experiencia casi real | Costoso de cambiar |
| Testing de alta calidad | Riesgo de apego emocional |
| Impresiona a stakeholders | Puede confundirse con producto terminado |
| Valida microinteracciones | Tiempo significativo de construcción |

### 2.4 Funcional vs Simulado

| Tipo | Descripción | Ejemplo |
|---|---|---|
| **Simulado** | Parece funcional pero sigue un camino fijo (clickthrough) | Figma prototype con hotspots |
| **Funcional** | Tiene lógica real: inputs, condicionales, datos dinámicos | Framer con variables, prototipo en React |

### 2.5 Cuándo Usar Cada Tipo

| Etapa del proyecto | Fidelidad recomendada | Objetivo |
|---|---|---|
| Ideación / kick-off | Low | Explorar, descartar rápido |
| Definición de estructura | Low → Mid | Validar flujos y arquitectura |
| Testing de usabilidad temprano | Mid | Feedback sobre navegación y comprensión |
| Presentación a stakeholders | Mid → High | Comunicar visión del producto |
| Testing de usabilidad final | High | Validar experiencia completa |
| Handoff a desarrollo | High | Referencia precisa de interacciones |
| Pitch a inversores | High | Demostrar viabilidad del producto |

> **Anti-patrón:** Empezar directamente con high-fidelity. Genera apego, es lento de iterar y desperdicia esfuerzo si el flujo base está mal.

---

## 3. Niveles de Interacción

### 3.1 Navegación Básica (Click-through)

El nivel más simple: el usuario hace click/tap y se navega a otra pantalla.

```
[Pantalla Home] ──click "Ver producto"──► [Pantalla Producto]
                                              │
                                    click "Comprar"
                                              │
                                              ▼
                                         [Checkout]
```

**Cuándo es suficiente:** Validar el flujo general sin detalles de interacción.

### 3.2 Transiciones entre Pantallas

Agregan contexto espacial — ¿de dónde viene esta pantalla? ¿hacia dónde va?

| Transición | Significado UX | Uso típico |
|---|---|---|
| **Slide left/right** | Avanzar/retroceder en un flujo | Navegación horizontal, wizard |
| **Slide up (modal)** | Contenido temporal sobre el actual | Modals, bottom sheets |
| **Fade** | Cambio suave de contexto | Cambio de sección |
| **Push** | Ir más profundo en la jerarquía | Detalle de un item |
| **Dissolve** | Cambio de estado | Success, loading → content |

### 3.3 Microinteracciones

Pequeñas animaciones que comunican feedback al usuario:

```
Ejemplos de microinteracciones:

  Botón:     [  Submit  ]  →  [  ●●●  ]  →  [  ✓ Done  ]
              default        loading         success

  Toggle:    [○═══════]  →  [═══════●]
              OFF               ON

  Like:      ♡  →  tap  →  ❤️ (scale up + bounce)

  Input:     [Email______]  →  [Email: usr@..._]  →  ✓
              empty             typing              valid

  Notif:     ┌────────────────┐
             │ ✓ Guardado     │  ← slide down, auto-dismiss 3s
             └────────────────┘
```

**¿Por qué importan en prototipos?** Las microinteracciones son lo que diferencia una interfaz que se siente "profesional" de una que se siente "plana". Prototiparlas antes del desarrollo evita debates infinitos durante la implementación.

### 3.4 Estados de UI

Un diseñador experimentado prototipa **todos los estados**, no solo el happy path:

| Estado | Descripción | Ejemplo visual |
|---|---|---|
| **Default** | Estado inicial | Formulario vacío |
| **Hover** | Cursor sobre elemento (desktop) | Botón cambia de color |
| **Active/Pressed** | Click/tap en progreso | Botón se reduce un poco |
| **Focus** | Elemento seleccionado | Input con borde azul |
| **Disabled** | No disponible | Botón gris, no clickable |
| **Loading** | Esperando respuesta | Spinner o skeleton |
| **Success** | Acción completada | Check verde, mensaje positivo |
| **Error** | Algo falló | Borde rojo, mensaje de error |
| **Empty** | Sin datos | Ilustración + CTA |

```
Ejemplo: Botón con todos sus estados

  [ Submit ]     →  Default (azul, clickable)
  [ Submit ]     →  Hover (azul más oscuro)
  [ Submit ]     →  Active (press scale 0.98)
  [  ●●●   ]    →  Loading (spinner, disabled)
  [  ✓ OK  ]    →  Success (verde, 2s visible)
  [ Submit ]     →  Error (rojo, shake animation)
  [ Submit ]     →  Disabled (gris, cursor: not-allowed)
```

> **Error común:** Solo prototipar el happy path. Si no pruebas los estados de error, loading y empty, descubrirás que no funcionan cuando ya están en desarrollo.

### 3.5 Inputs del Usuario

Prototipar cómo el sistema responde a inputs reales:

- **Formularios:** Validación inline (email inválido, password débil, campo requerido)
- **Búsqueda:** Autocomplete, resultados en tiempo real, "sin resultados"
- **Selección:** Dropdowns, multiselect, date pickers
- **Gestos (mobile):** Swipe, pinch, long press

```
Flujo de validación de formulario:

  ┌─────────────────────────────┐
  │  Email:  [user@example.com] │  ← ✓ válido (check verde)
  │  Pass:   [••••]             │  ← ⚠️ "Mínimo 8 caracteres"
  │  Confirm:[•••••••]          │  ← ✗ "No coinciden"
  │                             │
  │  [ ██ Registrarse ██ ]     │  ← disabled hasta todo válido
  └─────────────────────────────┘
```

---

## 4. Prototyping Enfocado en UX

### 4.1 Validación de Flujos de Usuario

El prototipo convierte un user flow abstracto en una **experiencia testeable**:

```
User Flow (abstracto):
  Buscar producto → Ver detalle → Agregar al carrito → Checkout → Pago

Prototipo (concreto):
  ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
  │Search  │→  │Product │→  │ Cart   │→  │Checkout│→  │Payment │
  │ Bar    │   │ Detail │   │ Review │   │ Form   │   │Confirm │
  │ Results│   │ [Add]  │   │[Check] │   │[Pay]   │   │  ✓     │
  └────────┘   └────────┘   └────────┘   └────────┘   └────────┘
      │                          │             │
      ▼                          ▼             ▼
  Sin result.              Carrito vacío   Error pago
  (estado empty)           (edge case)    (estado error)
```

**Preguntas que el prototipo debe responder:**

- ¿El usuario entiende cómo empezar?
- ¿Sabe qué hacer en cada paso?
- ¿Puede completar la tarea sin ayuda?
- ¿Qué pasa cuando algo sale mal?

### 4.2 Reducción de Fricción

La fricción es cualquier cosa que ralentiza o confunde al usuario. El prototipo permite identificarla antes del desarrollo:

| Tipo de fricción | Señal en testing | Solución |
|---|---|---|
| **Cognitiva** | "No entiendo qué hacer aquí" | Simplificar, copy más claro |
| **Visual** | Usuario no ve el CTA | Mejorar jerarquía, contraste |
| **De proceso** | "¿Por qué tantos pasos?" | Reducir steps, smart defaults |
| **Técnica** | "Se ve roto" (en prototipo) | Mejorar fidelidad del prototipo |
| **De confianza** | "No sé si esto es seguro" | Agregar indicadores de seguridad |

### 4.3 Evaluación de Usabilidad

Un prototipo es la herramienta principal para **usability testing**:

```
Ciclo de evaluación:

  Prototipo v1
       │
       ▼
  Test con 5 usuarios
       │
       ▼
  Hallazgos:
  - 3/5 no encontraron el botón de checkout
  - 4/5 confundidos por el paso de envío
  - 2/5 abandonaron en el formulario de pago
       │
       ▼
  Prototipo v2 (ajustado)
       │
       ▼
  Re-test con 5 usuarios nuevos
       │
       ▼
  Hallazgos:
  - 5/5 completaron checkout
  - Tiempo promedio reducido de 4min a 2min
       │
       ▼
  Handoff a desarrollo (validado)
```

### 4.4 Identificación de Puntos de Abandono

Observar dónde los usuarios se detienen, confunden o abandonan:

```
Funnel de conversión (observado en testing):

  100% ─── Landing page          ████████████████████
   72% ─── Ve productos          ██████████████▍
   58% ─── Abre detalle          ███████████▋
   41% ─── Agrega al carrito     ████████▏
   23% ─── Inicia checkout       ████▋          ← MAYOR DROP-OFF
   19% ─── Completa formulario   ███▊
   15% ─── Confirma pago         ███

  El prototipo reveló: el paso de "Iniciar checkout" requería
  registro obligatorio → 44% de drop-off → solución: guest checkout
```

---

## 5. Metodología Paso a Paso

### Paso 1: Definir Objetivos del Prototipo

Antes de construir, definir **qué quieres aprender**:

```
Plantilla de objetivos:

  Prototipo de: [Checkout de e-commerce]
  Nivel de fidelidad: [Mid-fidelity]

  Objetivos:
  1. Validar si los usuarios completan el checkout en < 3 minutos
  2. Identificar puntos de confusión en el formulario de envío
  3. Probar si el guest checkout reduce el abandono

  NO es objetivo:
  - Validar colores o tipografía (eso es para mockup review)
  - Probar performance (eso es para desarrollo)
  - Cubrir TODAS las pantallas (solo flujo crítico)
```

> **Anti-patrón:** Prototipar sin objetivo claro. Si no sabes qué estás validando, no sabrás si el prototipo fue exitoso.

### Paso 2: Seleccionar Nivel de Fidelidad

Usa esta matriz de decisión:

| Factor | → Low | → Mid | → High |
|---|---|---|---|
| Etapa del proyecto | Exploración | Definición | Validación final |
| Nivel de incertidumbre | Alto | Medio | Bajo |
| Audiencia del test | Equipo interno | Usuarios + equipo | Usuarios + stakeholders |
| Tiempo disponible | Horas | 1-3 días | 1-2 semanas |
| Lo que necesitas validar | Concepto | Flujo + estructura | Experiencia completa |

### Paso 3: Identificar Flujos Clave

No prototipes todo — solo los flujos de **mayor riesgo e impacto**:

```
Priorización de flujos:

  Alto impacto + Alta incertidumbre  → PROTOTIPAR PRIMERO
  ┌────────────────────────────────────────────────────┐
  │                    │                               │
  │  ★ Onboarding     │  ★ Checkout                   │
  │  ★ Search         │  ★ Registration               │
  │                    │                               │
  Alto ─────────────────────────────────── Incertidumbre
  │                    │                               │
  │  Profile settings │  About page                   │
  │  FAQ              │  Terms & conditions            │
  │                    │                               │
  └────────────────────────────────────────────────────┘
  Bajo impacto → no priorizar para prototipo
```

### Paso 4: Construcción del Prototipo

**Checklist de construcción:**

1. Definir pantallas necesarias (solo las del flujo target)
2. Diseñar cada pantalla (al nivel de fidelidad elegido)
3. Conectar pantallas con interacciones (hotspots, triggers)
4. Agregar estados alternativos (error, loading, empty, success)
5. Incluir datos realistas (nombres reales, precios reales, no "Lorem ipsum")
6. Definir punto de entrada y salida del flujo
7. Test interno (recorrer tú mismo el prototipo buscando huecos)

### Paso 5: Pruebas con Usuarios

**Protocolo mínimo de testing:**

```
Participantes: 5 usuarios (representativos del target)
Duración: 20-30 minutos por sesión
Formato: Think-aloud (usuario narra mientras interactúa)

Guión:
1. Introducción (2 min)
   "Vamos a probar un prototipo. No te estamos evaluando a ti,
   sino al diseño. No hay respuestas correctas o incorrectas."

2. Tareas (15-20 min)
   "Imagina que quieres comprar [producto]. Intenta completar
   la compra como lo harías normalmente."

3. Preguntas de cierre (5 min)
   - ¿Qué te pareció más confuso?
   - ¿Hubo algo que esperabas encontrar y no estaba?
   - ¿Completarías esta compra en la vida real?
```

### Paso 6: Iteración Basada en Feedback

```
Proceso de iteración:

  Test Round 1 (5 usuarios)
       │
       ▼
  Categorizar hallazgos:
  ┌─────────────────────────────────────────────────┐
  │  CRÍTICO (bloquea tarea)                        │
  │  → 3/5 no encontraron el botón "Pagar"         │
  │  → Corregir ANTES del siguiente test            │
  │                                                 │
  │  MAYOR (confunde pero no bloquea)               │
  │  → 4/5 dudaron en el paso de envío              │
  │  → Iterar para próximo test                     │
  │                                                 │
  │  MENOR (molestia, no impide tarea)              │
  │  → 2/5 mencionaron que el texto era pequeño     │
  │  → Anotar para fase de UI visual                │
  └─────────────────────────────────────────────────┘
       │
       ▼
  Prototipo v2 (corregir críticos + mayores)
       │
       ▼
  Test Round 2 (5 usuarios nuevos)
       │
       ▼
  ¿Problemas críticos resueltos? → SÍ → Handoff a dev
                                   NO → Iterar más
```

---

## 6. Herramientas y Tecnologías

### 6.1 Herramientas de Diseño

| Herramienta | Mejor para | Fidelidad | Colaboración | Curva |
|---|---|---|---|---|
| **Figma** | Todo: wireframes, mockups, prototipos | Low → High | Excelente (real-time) | Media |
| **Adobe XD** | Prototipos con auto-animate | Mid → High | Buena | Media |
| **Sketch** | Diseño UI (macOS) + plugins | Mid → High | Limitada | Media |
| **Balsamiq** | Wireframes rápidos low-fi | Low | Básica | Baja |
| **Whimsical** | Wireframes + flowcharts | Low → Mid | Buena | Baja |

**Figma — Capacidades de prototipado:**

- Hotspots (áreas clickables)
- Transiciones entre frames (slide, dissolve, push, move in/out)
- Smart Animate (anima diferencias entre frames)
- Component variants (cambiar estados de un componente)
- Variables (prototipos con lógica condicional)
- Overflow scrolling (scroll dentro de frames)
- Device preview (ver en móvil en tiempo real)

### 6.2 Prototipado Avanzado

| Herramienta | Mejor para | Diferenciador |
|---|---|---|
| **Framer** | Prototipos con código y lógica real | Componentes React nativos |
| **ProtoPie** | Microinteracciones complejas y multi-dispositivo | Sensores (gyro, sound), comunicación entre devices |
| **Principle** | Animaciones fluidas (macOS) | Timeline de animación preciso |
| **Origami Studio** | Prototipos complejos (por Meta) | Lógica de patches visual |

**Cuándo necesitas prototipado avanzado:**

- Microinteracciones que Figma no puede representar (gestos complejos, physics)
- Prototipos que necesitan datos dinámicos reales
- Demos para inversores que deben verse como producto real
- Validación de interacciones entre múltiples dispositivos

### 6.3 Prototipos con Código

| Tecnología | Mejor para | Trade-off |
|---|---|---|
| **HTML/CSS/JS** | Prototipos web rápidos | Rápido para devs, lento para designers |
| **React** | Prototipos funcionales complejos | Reutilizable en producción, más costoso |
| **Storybook** | Prototipos de componentes aislados | Ideal para design systems |

**¿Cuándo prototipar con código?**

- Cuando la interacción no se puede simular en Figma
- Cuando el prototipo puede convertirse en código de producción
- Cuando necesitas lógica real (API calls, cálculos dinámicos)
- Cuando el equipo tiene capacity de desarrollo para prototipo

```
Árbol de decisión:

  ¿Puedes representar la interacción en Figma?
  ├── SÍ → Usa Figma (más rápido, más iterativo)
  └── NO → ¿Es una microinteracción específica?
       ├── SÍ → ProtoPie o Framer
       └── NO → ¿Necesita lógica/datos reales?
            ├── SÍ → Prototipo con código
            └── NO → Reconsidera si realmente lo necesitas
```

> **Error común:** Usar código para todo. Un prototipo en código es 5-10x más lento de iterar que uno en Figma. Solo justifica el esfuerzo si es estrictamente necesario.

---

## 7. Buenas Prácticas

### 7.1 Prototipar Solo lo Necesario

No prototipes el producto completo — solo los flujos bajo validación:

```
❌ Sobreprototipar:
  50 pantallas, todas las secciones, todos los estados,
  2 semanas de trabajo → usuario solo usa 5 pantallas en el test

✅ Prototipar inteligente:
  8 pantallas del flujo de checkout + 4 estados alternativos
  2 días de trabajo → valida exactamente lo que necesitas
```

### 7.2 Enfocarse en Flujos Críticos

**Regla 80/20:** El 80% del valor viene de prototipar el 20% del producto — las pantallas donde el usuario toma decisiones o completa acciones clave.

| Prototipar primero | Prototipar después (o nunca) |
|---|---|
| Onboarding / registro | Página "Acerca de" |
| Búsqueda + resultados | Configuración de perfil |
| Checkout / conversión | Términos y condiciones |
| Funcionalidad core | Features secundarios |

### 7.3 Usar Datos Realistas

```
❌ Datos placeholder:
  Nombre: Lorem Ipsum
  Precio: $XX.XX
  Dirección: Calle ejemplo #123

✅ Datos realistas:
  Nombre: María García López
  Precio: $1,299.00
  Dirección: Av. Insurgentes Sur 1602, CDMX

  ¿Por qué? Datos reales revelan problemas reales:
  - ¿Cabe el nombre completo en el campo?
  - ¿El formato de precio funciona con 5 dígitos?
  - ¿La dirección larga rompe el layout?
```

### 7.4 Diseñar para Testing, No para Perfección Estética

- Un prototipo mid-fi testeado con 5 usuarios vale más que un prototipo high-fi que nadie ha probado
- Si estás puliendo píxeles en el prototipo, probablemente estás sobreproduciendo
- El objetivo es **aprender**, no impresionar

### 7.5 Mantener Consistencia

- Mismos componentes en todas las pantallas del prototipo
- Misma lógica de navegación (back buttons, menús)
- Mismos patrones de interacción (cómo se abren modales, cómo funciona scroll)
- Usar un design system o component library (incluso si es simple)

### 7.6 Iterar Rápido

```
Velocidad de iteración por fidelidad:

  Low-fi:   Idea → Prototipo → Test → Iteración = horas
  Mid-fi:   Idea → Prototipo → Test → Iteración = 1-2 días
  High-fi:  Idea → Prototipo → Test → Iteración = días-semanas

  Empieza low, sube la fidelidad progresivamente conforme
  reduces la incertidumbre.
```

> **Anti-patrón — "Pixel Perfect Prototype Syndrome":** Pasar días perfeccionando un prototipo que nadie ha validado. Si el flujo está mal, la perfección visual es irrelevante.

---

## 8. Testing con Prototipos

### 8.1 Usability Testing

**Formatos:**

| Tipo | Descripción | Cuándo usar |
|---|---|---|
| **Moderado remoto** | Videollamada + screen share, moderador guía | Testing frecuente, usuarios distribuidos |
| **Moderado presencial** | Cara a cara, observas gestos y expresiones | Cuando necesitas máximo detalle |
| **No moderado** | Usuario completa tareas solo (grabado) | Escala, cuando necesitas volumen |
| **Guerrilla** | Testing rápido en cafeterías, oficinas | Feedback rápido, bajo presupuesto |

**5 usuarios = ~85% de problemas de usabilidad descubiertos** (Nielsen/Norman)

### 8.2 A/B Testing Conceptual

En fase de prototipo, el A/B testing es **cualitativo**, no estadístico:

```
Variante A: Checkout en 3 pasos
  [Carrito] → [Datos + Envío] → [Pago + Confirmación]

Variante B: Checkout en 1 página
  [Todo en una sola pantalla con secciones colapsables]

Test: Mostrar ambas variantes a usuarios diferentes
Medir: Preferencia, comprensión, tiempo de completación
Decidir: Cuál llevar a high-fidelity para testing más robusto
```

### 8.3 Métricas de Testing

| Métrica | Qué mide | Cómo medirla | Target típico |
|---|---|---|---|
| **Task Success Rate** | ¿Completó la tarea? | Éxitos / intentos × 100 | > 85% |
| **Time on Task** | ¿Cuánto tardó? | Cronómetro por tarea | Depende de la tarea |
| **Error Rate** | ¿Cuántos errores cometió? | Contar clicks/acciones incorrectas | < 2 por tarea |
| **SUS Score** | Satisfacción subjetiva | System Usability Scale (cuestionario) | > 68 |
| **Confidence** | ¿Se sintió seguro? | Escala 1-5 post-tarea | > 4 |

### 8.4 Recopilación de Feedback Cualitativo

**Qué observar durante el testing:**

- **Verbalizaciones:** "Hmm, ¿dónde está...?", "Ah, pensé que esto haría otra cosa"
- **Hesitaciones:** Pausas largas antes de actuar
- **Mis-taps:** Clicks en zonas no interactivas
- **Expresiones faciales:** Confusión, frustración, sorpresa
- **Workarounds:** El usuario inventa su propia forma de completar la tarea

**Plantilla de registro por usuario:**

```
Usuario: #3 / María / 28 años / Usa e-commerce frecuentemente
Tarea: Completar compra de un producto

Observaciones:
| Tiempo  | Pantalla     | Observación                | Severidad |
|---------|--------------|----------------------------|-----------|
| 0:12    | Home         | Encontró search rápido     | —         |
| 0:45    | Product      | Dudó en tallas (no claro)  | Mayor     |
| 1:20    | Cart         | No vio link de "Checkout"  | Crítico   |
| 2:10    | Checkout     | Confundida por form envío  | Mayor     |
| 3:05    | Payment      | Completó sin problemas     | —         |

Resultado: Completó ✓ | Tiempo: 3:05 | Errores: 2
Feedback: "El checkout estaba medio escondido"
```

---

## 9. Casos Prácticos

### 9.1 Prototipo de Onboarding

**Objetivo:** Validar que nuevos usuarios entienden el producto y completan la configuración inicial.

```
Flujo a prototipar:

  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
  │ Welcome │ → │ Step 1  │ → │ Step 2  │ → │ Step 3  │
  │         │   │ Profile │   │ Prefer. │   │ Tutorial│
  │ [Start] │   │ [Next]  │   │ [Next]  │   │ [Done]  │
  └─────────┘   └─────────┘   └─────────┘   └─────────┘
                     │              │              │
                   [Skip]        [Skip]         [Skip]
                     │              │              │
                     └──────────────┴──────────────┘
                                   │
                              ┌────┴─────┐
                              │Dashboard │
                              │(empty    │
                              │ state)   │
                              └──────────┘

  Estados a incluir:
  ✓ Progress indicator (paso 1/3, 2/3, 3/3)
  ✓ Opción de skip en cada paso
  ✓ Dashboard con empty state post-onboarding
  ✓ Tooltip de ayuda si usuario parece perdido
```

**Qué validar:**

- ¿Los usuarios completan el onboarding o skipean todo?
- ¿Entienden cada paso sin explicación adicional?
- ¿El empty state del dashboard les da suficiente contexto?

### 9.2 Prototipo de Checkout E-commerce

**Objetivo:** Minimizar abandono y validar que el flujo de pago es claro.

```
Flujo a prototipar (con estados):

  ┌──────────────────── Happy Path ────────────────────┐
  │                                                    │
  │  Cart → Shipping → Payment → Confirmation          │
  │                                                    │
  └────────────────────────────────────────────────────┘

  ┌──────────────────── Edge Cases ────────────────────┐
  │                                                    │
  │  Cart vacío (empty state + CTA "Explorar")         │
  │  Cupón inválido (error inline)                     │
  │  Dirección no válida (validación de form)          │
  │  Pago rechazado (error + opciones alternativas)    │
  │  Timeout de sesión (modal de advertencia)          │
  │                                                    │
  └────────────────────────────────────────────────────┘

  Pantalla de Cart:
  ┌─────────────────────────────────────────┐
  │  Tu carrito (3 items)                   │
  │                                         │
  │  ┌─────┐ Producto A        $299.00     │
  │  │ img │ Qty: [- 1 +]     [✗ Remove]  │
  │  └─────┘                               │
  │  ┌─────┐ Producto B        $149.00     │
  │  │ img │ Qty: [- 2 +]     [✗ Remove]  │
  │  └─────┘                               │
  │                                         │
  │  Cupón: [________] [Aplicar]           │
  │                                         │
  │  ─────────────────────────────────      │
  │  Subtotal:              $597.00         │
  │  Envío:                 $49.00          │
  │  Total:                 $646.00         │
  │                                         │
  │  [ ████ Proceder al pago ████ ]        │
  │                                         │
  │  [Seguir comprando]                     │
  └─────────────────────────────────────────┘
```

### 9.3 Prototipo de Dashboard SaaS

**Objetivo:** Validar que los usuarios encuentran la información clave y entienden los datos.

```
Flujo a prototipar:

  ┌──────────────────────────────────────────────┐
  │  Dashboard (overview)                        │
  │  → Drill-down en KPI                         │
  │  → Filtrar por fecha/segmento                │
  │  → Exportar reporte                          │
  │  → Empty state (usuario nuevo sin datos)     │
  └──────────────────────────────────────────────┘

  Dashboard:
  ┌──────────────────────────────────────────────────┐
  │  [☰] SaaS App        [Filtro ▼]  [Exportar]     │
  ├──────────┬───────────────────────────────────────┤
  │          │  KPI 1: Revenue    KPI 2: Users       │
  │ 📊 Dash  │  $45.2k (+12%)    1,234 (-3%)        │
  │ 👥 Users │                                       │
  │ 💰 Rev   │  ┌───────────────────────────────┐   │
  │ ⚙️ Config│  │    [Gráfico interactivo]      │   │
  │          │  │    hover → tooltip con datos   │   │
  │          │  │    click → drill-down          │   │
  │          │  └───────────────────────────────┘   │
  │          │                                       │
  │          │  Tabla: Top productos                 │
  │          │  ┌──────┬────────┬─────────┐         │
  │          │  │ Name │ Sales  │ Revenue │         │
  │          │  ├──────┼────────┼─────────┤         │
  │          │  │ A    │ 234    │ $12.3k  │         │
  │          │  │ B    │ 189    │ $9.8k   │         │
  │          │  └──────┴────────┴─────────┘         │
  └──────────┴───────────────────────────────────────┘

  Interacciones a prototipar:
  - Hover en KPIs → muestra variación vs período anterior
  - Click en gráfico → drill-down a detalle
  - Filtro de fecha → gráfico y KPIs se actualizan
  - Empty state → "Conecta tu primera fuente de datos"
```

### 9.4 Comparación entre Soluciones

Cuando tienes dos alternativas de diseño, prototipa ambas y compara:

```
Decisión: ¿Onboarding wizard vs onboarding contextual?

  Opción A: Wizard (3 pasos al inicio)
  ┌─────────────────────────────────────────┐
  │  Pros:                                  │
  │  + Usuario configura todo de una vez    │
  │  + Estructura clara                     │
  │  + Fácil de medir (completion rate)     │
  │                                         │
  │  Contras:                               │
  │  - Puede sentirse largo                 │
  │  - Alto rate de skip                    │
  │  - Información sin contexto             │
  └─────────────────────────────────────────┘

  Opción B: Contextual (tooltips in-app)
  ┌─────────────────────────────────────────┐
  │  Pros:                                  │
  │  + Aprende mientras usa                 │
  │  + No bloquea el uso del producto       │
  │  + Información en contexto              │
  │                                         │
  │  Contras:                               │
  │  - Puede perderse tooltips              │
  │  - Más difícil de medir                 │
  │  - Requiere más diseño de estados       │
  └─────────────────────────────────────────┘

  Método: Prototipar ambas → Testear con 5 usuarios cada una
  → Comparar: task success rate, time, satisfacción
  → Decidir con datos
```

---

## Resumen: Decisiones Clave

| Momento | Pregunta | Acción |
|---|---|---|
| Antes de prototipar | ¿Qué quiero validar específicamente? | Definir objetivos claros |
| Al elegir fidelidad | ¿Cuánta incertidumbre tengo? | Alta incertidumbre → Low-fi; baja → High-fi |
| Al construir | ¿Estoy prototipando todo o solo lo crítico? | Solo flujos de alto riesgo/impacto |
| Al incluir estados | ¿Solo hice el happy path? | Agregar error, loading, empty, edge cases |
| Al testear | ¿Tengo al menos 5 usuarios representativos? | Si no → reclutar antes de testear |
| Al iterar | ¿Los problemas críticos están resueltos? | Si no → iterar antes de subir de fidelidad |
| Antes del handoff | ¿El equipo de desarrollo puede entender el prototipo? | Agregar anotaciones y especificaciones |

> **Mantra del prototyping:** Construye lo mínimo necesario para aprender lo máximo posible. Prototipa para validar, no para impresionar. Itera rápido, falla barato, y llega a desarrollo con certeza.
