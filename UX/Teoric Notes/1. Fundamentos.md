# Fundamentos de UX / UI

> *"Design is not just what it looks like and feels like. Design is how it works."*
> — Steve Jobs

---

## Tabla de Contenidos

### Parte I — Tipos de Sitios Web y Objetivos de Negocio
- [1. Introducción: Diseño con propósito](#1-introducción-diseño-con-propósito)
- [2. Taxonomía de sitios web](#2-taxonomía-de-sitios-web)
  - [2.1 Landing Page](#21-landing-page)
  - [2.2 Sitio Corporativo](#22-sitio-corporativo)
  - [2.3 E-commerce](#23-e-commerce)
  - [2.4 SaaS (Software as a Service)](#24-saas-software-as-a-service)
  - [2.5 Blog / Sitio de Contenido SEO](#25-blog--sitio-de-contenido-seo)
  - [2.6 Funnel (Embudo de Conversión)](#26-funnel-embudo-de-conversión)
  - [2.7 Portafolio](#27-portafolio)
  - [2.8 Aplicación Web (Dashboard / Sistema)](#28-aplicación-web-dashboard--sistema)
- [3. Matriz comparativa de sitios web](#3-matriz-comparativa-de-sitios-web)

### Parte II — Fundamentos de UX (User Experience)
- [4. ¿Qué es UX?](#4-qué-es-ux)
  - [4.1 Definición profesional](#41-definición-profesional)
  - [4.2 Las 5 dimensiones de la UX](#42-las-5-dimensiones-de-la-ux)
  - [4.3 UX vs UI — Diferencia fundamental](#43-ux-vs-ui--diferencia-fundamental)
- [5. User Journey (Viaje del usuario)](#5-user-journey-viaje-del-usuario)
  - [5.1 Definición y estructura](#51-definición-y-estructura)
  - [5.2 Diagrama de un User Journey completo](#52-diagrama-de-un-user-journey-completo)
  - [5.3 Touchpoints y momentos de verdad](#53-touchpoints-y-momentos-de-verdad)
- [6. Pain Points (Puntos de dolor)](#6-pain-points-puntos-de-dolor)
  - [6.1 Definición y categorías](#61-definición-y-categorías)
  - [6.2 Cómo identificarlos](#62-cómo-identificarlos)
  - [6.3 Del pain point a la oportunidad de diseño](#63-del-pain-point-a-la-oportunidad-de-diseño)
- [7. Jobs To Be Done (JTBD)](#7-jobs-to-be-done-jtbd)
  - [7.1 Concepto y origen](#71-concepto-y-origen)
  - [7.2 Estructura de un Job Statement](#72-estructura-de-un-job-statement)
  - [7.3 JTBD aplicado al diseño](#73-jtbd-aplicado-al-diseño)
- [8. Arquitectura de la Información (IA)](#8-arquitectura-de-la-información-ia)
  - [8.1 Definición y principios](#81-definición-y-principios)
  - [8.2 Modelos de organización](#82-modelos-de-organización)
  - [8.3 Card Sorting y Tree Testing](#83-card-sorting-y-tree-testing)
- [9. Heurísticas de Usabilidad de Jakob Nielsen](#9-heurísticas-de-usabilidad-de-jakob-nielsen)
- [10. Principios transversales de UX](#10-principios-transversales-de-ux)
  - [10.1 Reducción de fricción](#101-reducción-de-fricción)
  - [10.2 Scanning behavior (Comportamiento de escaneo)](#102-scanning-behavior-comportamiento-de-escaneo)
  - [10.3 Feedback del sistema](#103-feedback-del-sistema)
  - [10.4 Consistencia](#104-consistencia)

### Parte III — Fundamentos de UI (User Interface)
- [11. ¿Qué es UI?](#11-qué-es-ui)
  - [11.1 Definición profesional](#111-definición-profesional)
  - [11.2 Relación entre UX y UI](#112-relación-entre-ux-y-ui)
- [12. Jerarquía visual](#12-jerarquía-visual)
- [13. Tipografía](#13-tipografía)
  - [13.1 Escala tipográfica](#131-escala-tipográfica)
  - [13.2 Buenas prácticas](#132-buenas-prácticas)
- [14. Color](#14-color)
  - [14.1 Función del color en UI](#141-función-del-color-en-ui)
  - [14.2 Paleta y sistema de color](#142-paleta-y-sistema-de-color)
- [15. Espaciado (Whitespace)](#15-espaciado-whitespace)
- [16. Grid System (Sistema de rejilla)](#16-grid-system-sistema-de-rejilla)
- [17. Componentes UI y estados](#17-componentes-ui-y-estados)
- [18. Accesibilidad básica en UI](#18-accesibilidad-básica-en-ui)
- [19. Feedback visual](#19-feedback-visual)

---

# Parte I — Tipos de Sitios Web y Objetivos de Negocio

---

# 1. Introducción: Diseño con propósito

Antes de abrir cualquier herramienta de diseño, antes de elegir colores o tipografías, existe una pregunta que define todo lo que vendrá después:

> **¿Cuál es el objetivo de negocio de este sitio web?**

El error más común en diseñadores principiantes es comenzar por la interfaz. El enfoque profesional es exactamente el inverso:

```
┌─────────────────────────────────────────────────────┐
│          ENFOQUE CORRECTO DE DISEÑO                 │
│                                                     │
│   1. Definir objetivo de negocio                    │
│       ↓                                             │
│   2. Definir acción principal del usuario            │
│       ↓                                             │
│   3. Diseñar la estructura en función de ambos       │
│       ↓                                             │
│   4. Aplicar el diseño visual                        │
└─────────────────────────────────────────────────────┘
```

Cada tipo de sitio web tiene un objetivo diferente, métricas diferentes y patrones de diseño diferentes. Un e-commerce no se diseña como un blog. Un SaaS no se estructura como un portafolio. Entender esta taxonomía es la base de cualquier decisión de diseño profesional.

---

# 2. Taxonomía de sitios web

---

## 2.1 Landing Page

### Definición

Una landing page es una página de aterrizaje diseñada con **un único objetivo de conversión**. El usuario llega (generalmente desde un anuncio, email o enlace directo) y debe realizar una acción específica.

### Objetivo de negocio

Convertir visitantes en leads o clientes de forma directa y medible.

### Características clave

| Característica          | Descripción                                        |
|------------------------|----------------------------------------------------|
| Enfoque                | Una sola acción (CTA único)                        |
| Navegación             | Mínima o inexistente (sin menú complejo)           |
| Mensaje                | Claro, directo, orientado a beneficio              |
| Optimización           | Alta — cada elemento justifica su existencia       |
| Distracciones          | Eliminadas por diseño                              |

### Estructura típica

```
┌──────────────────────────────────────────────┐
│  HERO SECTION                                │
│  ┌──────────────────────────────────────┐    │
│  │  H1: Propuesta de valor              │    │
│  │  Subtítulo: Beneficio principal      │    │
│  │  [ CTA Primario ]                    │    │
│  └──────────────────────────────────────┘    │
├──────────────────────────────────────────────┤
│  BENEFICIOS (3-4 bloques con iconos)         │
│  ┌──────┐  ┌──────┐  ┌──────┐               │
│  │ Ben1 │  │ Ben2 │  │ Ben3 │               │
│  └──────┘  └──────┘  └──────┘               │
├──────────────────────────────────────────────┤
│  PRUEBA SOCIAL                               │
│  Testimonios / Logos de clientes / Ratings   │
├──────────────────────────────────────────────┤
│  EXPLICACIÓN DEL PRODUCTO/SERVICIO           │
│  Cómo funciona (3 pasos)                     │
├──────────────────────────────────────────────┤
│  CTA FINAL (refuerzo de conversión)          │
│  [ CTA Primario repetido ]                   │
└──────────────────────────────────────────────┘
```

### Cuándo usarla

- Campañas de marketing (paid ads, email marketing)
- Lanzamientos de producto
- Captación de leads (lead magnets)
- Eventos o webinars

### Métricas clave

- **Conversion Rate** (tasa de conversión)
- **Bounce Rate** (tasa de rebote)
- **CTR** (Click-Through Rate en CTAs)
- **Time on Page** (tiempo en página)

---

## 2.2 Sitio Corporativo

### Definición

Presencia digital oficial de una empresa. Comunica **quién es**, **qué hace** y **por qué confiar** en ella.

### Objetivo de negocio

Transmitir confianza, credibilidad y posicionamiento de marca.

### Características clave

| Característica      | Descripción                                         |
|--------------------|-----------------------------------------------------|
| Información        | Institucional, clara y estructurada                 |
| Navegación         | Jerárquica y predecible                             |
| Branding           | Consistente en toda la experiencia                  |
| Tono               | Profesional, alineado con identidad corporativa     |

### Estructura típica

```
┌──────────────────────────────────────────────┐
│  NAVBAR                                       │
│  Logo │ Inicio │ Nosotros │ Servicios │ Blog │
├──────────────────────────────────────────────┤
│  HERO — Mensaje de marca + imagen/video       │
├──────────────────────────────────────────────┤
│  SERVICIOS / QUÉ HACEMOS                      │
├──────────────────────────────────────────────┤
│  NOSOTROS — Historia, equipo, misión          │
├──────────────────────────────────────────────┤
│  CONFIANZA — Logos, certificaciones           │
├──────────────────────────────────────────────┤
│  CONTACTO — Formulario / datos                │
├──────────────────────────────────────────────┤
│  FOOTER                                       │
└──────────────────────────────────────────────┘
```

### Cuándo usarlo

- Empresas establecidas con presencia B2B
- Branding y posicionamiento digital
- Instituciones que necesitan credibilidad online

---

## 2.3 E-commerce

### Definición

Plataforma de venta directa de productos (físicos o digitales) a través de internet.

### Objetivo de negocio

Vender productos online de forma eficiente y escalable.

### Características clave

| Característica        | Descripción                                       |
|----------------------|---------------------------------------------------|
| Catálogo             | Productos organizados por categorías              |
| Búsqueda y filtros   | Esencial para encontrar productos rápidamente     |
| Checkout             | Proceso de compra optimizado (mínima fricción)    |
| Confianza            | Reviews, seguridad, políticas de devolución       |

### Flujo del usuario

```
Home → Categoría → Producto → Carrito → Checkout → Confirmación
  │                   │                     │
  │   Filtros ←───────┘         Upsell ←────┘
  │   Búsqueda
  └── Recomendaciones
```

### Estructura típica

```
┌──────────────────────────────────────────────┐
│  NAVBAR + BÚSQUEDA + CARRITO                  │
├──────────────────────────────────────────────┤
│  HOME — Productos destacados / Ofertas        │
├──────────────────────────────────────────────┤
│  CATEGORÍAS                                   │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐     │
│  │ Cat1 │  │ Cat2 │  │ Cat3 │  │ Cat4 │     │
│  └──────┘  └──────┘  └──────┘  └──────┘     │
├──────────────────────────────────────────────┤
│  PÁGINA DE PRODUCTO                           │
│  Imagen │ Título │ Precio │ [Añadir carrito] │
│  Descripción │ Reviews │ Relacionados         │
├──────────────────────────────────────────────┤
│  CHECKOUT (1-3 pasos máximo)                  │
│  Datos → Envío → Pago → Confirmación         │
└──────────────────────────────────────────────┘
```

### Métricas clave

- **Revenue** (ingresos)
- **Cart Abandonment Rate** (tasa de abandono de carrito)
- **Average Order Value** (valor promedio del pedido)
- **Customer Lifetime Value** (valor del cliente a largo plazo)

---

## 2.4 SaaS (Software as a Service)

### Definición

Producto digital que se vende como servicio, generalmente mediante suscripción. El usuario accede a una plataforma online sin instalar nada.

### Objetivo de negocio

Adquirir usuarios, activarlos y retenerlos dentro del producto.

### Características clave

| Característica     | Descripción                                          |
|-------------------|------------------------------------------------------|
| Propuesta de valor | Explicación clara del "por qué usar esto"            |
| Onboarding        | Proceso guiado para que el usuario obtenga valor rápido |
| Retención         | Enfoque en engagement y uso recurrente               |
| Pricing           | Planes claros con diferenciación de features         |

### Doble estructura (Marketing + Producto)

```
SITIO MARKETING (público):
┌──────────────────────────────────────────────┐
│  Landing de producto — qué es y por qué      │
│  Features — qué puede hacer                  │
│  Pricing — cuánto cuesta                     │
│  Social proof — quién lo usa                 │
│  CTA → Sign Up / Free Trial                 │
└──────────────────────────────────────────────┘

PRODUCTO (autenticado):
┌──────────────────────────────────────────────┐
│  Onboarding — guía inicial                   │
│  Dashboard — vista principal                 │
│  Features — funcionalidades del producto     │
│  Settings — configuración                    │
│  Help / Docs — soporte                       │
└──────────────────────────────────────────────┘
```

### Métricas clave

- **MRR / ARR** (Monthly/Annual Recurring Revenue)
- **Churn Rate** (tasa de cancelación)
- **Activation Rate** (usuarios que alcanzan el "aha moment")
- **NPS** (Net Promoter Score)

---

## 2.5 Blog / Sitio de Contenido SEO

### Definición

Sitio centrado en contenido escrito, optimizado para posicionamiento en buscadores.

### Objetivo de negocio

Generar tráfico orgánico, educar al usuario y alimentar el funnel de marketing.

### Características clave

| Característica      | Descripción                                        |
|--------------------|----------------------------------------------------|
| Contenido          | Artículos optimizados para SEO                     |
| Estructura         | Jerárquica (categorías, tags, autor)               |
| Lectura            | Optimizada para escaneo (headings, listas, visual) |
| Conversión         | CTAs internos (newsletter, descarga, producto)     |

### Estructura típica

```
┌──────────────────────────────────────────────┐
│  NAVBAR — Logo │ Categorías │ Búsqueda       │
├──────────────────────────────────────────────┤
│  ARTÍCULOS RECIENTES / DESTACADOS            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Article  │  │ Article  │  │ Article  │   │
│  │  Card    │  │  Card    │  │  Card    │   │
│  └──────────┘  └──────────┘  └──────────┘   │
├──────────────────────────────────────────────┤
│  CATEGORÍAS — Sidebar o sección              │
├──────────────────────────────────────────────┤
│  ARTÍCULO INDIVIDUAL                         │
│  H1 │ Autor │ Fecha │ Contenido │ CTA       │
├──────────────────────────────────────────────┤
│  NEWSLETTER / LEAD CAPTURE                   │
└──────────────────────────────────────────────┘
```

### Métricas clave

- **Organic Traffic** (tráfico orgánico)
- **Time on Page** (tiempo de lectura)
- **Bounce Rate** (tasa de rebote)
- **Keyword Rankings** (posiciones en buscadores)

---

## 2.6 Funnel (Embudo de Conversión)

### Definición

Flujo secuencial diseñado para guiar al usuario paso a paso hacia una conversión, eliminando toda fricción y distracción.

### Objetivo de negocio

Maximizar la tasa de conversión guiando al usuario por un camino controlado.

### Ejemplo de flujo completo

```
┌─────────────────┐
│  1. LANDING PAGE │ ←── Tráfico (anuncios, email, SEO)
│  (Captura)       │
└────────┬────────┘
         ↓
┌─────────────────┐
│  2. FORMULARIO   │ ←── Lead magnet (ebook, trial, webinar)
│  (Lead capture)  │
└────────┬────────┘
         ↓
┌─────────────────┐
│  3. THANK YOU    │ ←── Confirmación + siguiente paso
│  (Agradecimiento)│
└────────┬────────┘
         ↓
┌─────────────────┐
│  4. EMAIL SEQ.   │ ←── Nurturing (secuencia de emails)
│  (Nurturing)     │
└────────┬────────┘
         ↓
┌─────────────────┐
│  5. VENTA        │ ←── Página de venta / checkout
│  (Conversión)    │
└─────────────────┘
```

### Características clave

- Flujo secuencial — cada paso lleva al siguiente
- Sin navegación externa — eliminar escape routes
- Microconversiones — cada paso es una mini-conversión
- Urgencia / escasez — elementos psicológicos de conversión

### Cuándo usarlo

- Venta de servicios y cursos
- Infoproductos
- Generación de leads cualificados

---

## 2.7 Portafolio

### Definición

Sitio personal que muestra trabajos, habilidades y casos de estudio de un profesional.

### Objetivo de negocio

Demostrar competencia profesional y generar oportunidades laborales o de negocio.

### Estructura típica

```
┌──────────────────────────────────────────────┐
│  HERO — Nombre, rol, propuesta de valor      │
├──────────────────────────────────────────────┤
│  PROYECTOS DESTACADOS                        │
│  ┌────────────┐  ┌────────────┐              │
│  │  Proyecto 1 │  │  Proyecto 2 │             │
│  │  (caso)     │  │  (caso)     │             │
│  └────────────┘  └────────────┘              │
├──────────────────────────────────────────────┤
│  SOBRE MÍ — Historia, skills, experiencia    │
├──────────────────────────────────────────────┤
│  CONTACTO — Email / formulario / redes       │
└──────────────────────────────────────────────┘
```

### Estructura de un caso de estudio

Un caso de estudio profesional incluye:

1. **Contexto** — Qué era el proyecto y para quién
2. **Problema** — Qué problema se resolvió
3. **Proceso** — Qué metodología se siguió
4. **Solución** — Qué se diseñó/desarrolló
5. **Resultado** — Qué impacto tuvo (métricas si es posible)

---

## 2.8 Aplicación Web (Dashboard / Sistema)

### Definición

Interfaz funcional que permite al usuario realizar tareas complejas: gestionar datos, monitorizar métricas, administrar recursos.

### Objetivo de negocio

Productividad del usuario — permitir completar tareas de forma eficiente.

### Ejemplos

- CRM (gestión de clientes)
- Paneles administrativos
- Herramientas internas de empresa
- Analytics dashboards

### Características clave

| Característica    | Descripción                                         |
|------------------|-----------------------------------------------------|
| Usabilidad       | Alta — el usuario pasa horas aquí                   |
| Navegación       | Clara, con sidebar o tabs                           |
| Densidad         | Mayor densidad de información que un sitio público  |
| Estados          | Múltiples: cargando, vacío, error, éxito            |

### Estructura típica

```
┌───────┬──────────────────────────────────────┐
│       │  TOPBAR (breadcrumbs, búsqueda,      │
│  S    │  perfil, notificaciones)             │
│  I    ├──────────────────────────────────────┤
│  D    │                                      │
│  E    │  CONTENT AREA                        │
│  B    │                                      │
│  A    │  ┌──────────────────────────────┐    │
│  R    │  │  Tabla / Cards / Gráficos    │    │
│       │  │  Filtros / Acciones          │    │
│  Nav  │  └──────────────────────────────┘    │
│       │                                      │
└───────┴──────────────────────────────────────┘
```

---

# 3. Matriz comparativa de sitios web

| Tipo               | Objetivo principal     | Acción del usuario     | Complejidad | KPI principal            |
|--------------------|------------------------|------------------------|-------------|--------------------------|
| Landing Page       | Convertir              | Clic en CTA            | Baja        | Conversion Rate          |
| Corporativo        | Posicionar marca       | Explorar, contactar    | Media       | Brand awareness          |
| E-commerce         | Vender                 | Comprar producto       | Alta        | Revenue                  |
| SaaS               | Retener usuarios       | Usar el producto       | Alta        | Churn Rate / MRR         |
| Blog / SEO         | Generar tráfico        | Leer, suscribir        | Media       | Organic Traffic          |
| Funnel             | Convertir secuencial   | Avanzar en el flujo    | Media       | Conversion por paso      |
| Portafolio         | Mostrar competencia    | Ver casos, contactar   | Baja        | Leads / contactos        |
| Aplicación Web     | Productividad          | Completar tareas       | Muy alta    | Task Completion Rate     |

> **Regla de oro:** Antes de diseñar, identifica el tipo de sitio. El tipo define la estructura, los patrones y las métricas.

---

# Parte II — Fundamentos de UX (User Experience)

---

# 4. ¿Qué es UX?

---

## 4.1 Definición profesional

**UX (User Experience)** es la disciplina que estudia y diseña la experiencia completa que tiene una persona al interactuar con un producto digital. Abarca todo: desde el primer contacto hasta el uso recurrente.

No se trata solo de que algo "se vea bien". UX incluye:

- **Utilidad** — ¿Resuelve un problema real?
- **Usabilidad** — ¿Es fácil de usar?
- **Deseabilidad** — ¿El usuario quiere usarlo?
- **Encontrabilidad** — ¿El usuario encuentra lo que busca?
- **Accesibilidad** — ¿Funciona para todos?
- **Credibilidad** — ¿Genera confianza?

> **UX = Resolver problemas del usuario con la menor fricción posible.**

### El modelo del panal de Peter Morville

```
          ┌──────────┐
          │  ÚTIL    │
     ┌────┼──────────┼────┐
     │    │          │    │
  USABLE  │ DESEABLE │  ENCONTRABLE
     │    │          │    │
     └────┼──────────┼────┘
          │ACCESIBLE │
          ├──────────┤
          │ CREÍBLE  │
          ├──────────┤
          │ VALIOSO  │
          └──────────┘
```

---

## 4.2 Las 5 dimensiones de la UX

Jesse James Garrett definió 5 planos que van de lo abstracto a lo concreto:

```
┌─────────────────────────────────────────────┐
│  5. SUPERFICIE    → Diseño visual (UI)      │
├─────────────────────────────────────────────┤
│  4. ESQUELETO     → Layout, wireframes      │
├─────────────────────────────────────────────┤
│  3. ESTRUCTURA    → Arquitectura info       │
├─────────────────────────────────────────────┤
│  2. ALCANCE       → Features, contenido     │
├─────────────────────────────────────────────┤
│  1. ESTRATEGIA    → Objetivos + necesidades │
└─────────────────────────────────────────────┘
       ↑ Abstracto                Concreto ↓
```

| Plano        | Pregunta clave                         | Entregable típico           |
|-------------|----------------------------------------|-----------------------------|
| Estrategia  | ¿Por qué existe este producto?          | Brief, research             |
| Alcance     | ¿Qué incluye?                          | Feature list, contenido     |
| Estructura  | ¿Cómo se organiza?                     | Sitemap, IA                 |
| Esqueleto   | ¿Dónde va cada cosa?                   | Wireframes                  |
| Superficie  | ¿Cómo se ve?                           | UI, mockups                 |

> **Concepto clave:** Se diseña de abajo hacia arriba (de estrategia a superficie), no al revés.

---

## 4.3 UX vs UI — Diferencia fundamental

| Aspecto          | UX (User Experience)              | UI (User Interface)              |
|-----------------|-----------------------------------|----------------------------------|
| Enfoque         | Cómo funciona                     | Cómo se ve                       |
| Pregunta        | ¿Es fácil de usar?               | ¿Es visualmente atractivo?       |
| Herramientas    | Research, wireframes, testing     | Figma, colores, tipografía       |
| Resultado       | Flujos, arquitectura, validación  | Mockups, prototipos visuales     |
| Analogía        | El plano de un edificio           | La decoración de interiores      |

```
UX sin UI = Funcional pero feo → el usuario no confía
UI sin UX = Bonito pero inutilizable → el usuario se frustra
UX + UI   = Funcional, atractivo y eficiente → conversión
```

---

# 5. User Journey (Viaje del usuario)

---

## 5.1 Definición y estructura

El **User Journey** es el recorrido completo que hace un usuario desde su primer contacto con el producto hasta que cumple un objetivo (y más allá).

No es lineal. Incluye:
- **Etapas** — Fases del recorrido (descubrimiento, consideración, conversión, retención)
- **Acciones** — Qué hace el usuario en cada etapa
- **Pensamientos** — Qué está pensando
- **Emociones** — Cómo se siente (frustración, confianza, satisfacción)
- **Touchpoints** — Dónde interactúa con el producto
- **Oportunidades** — Dónde podemos mejorar la experiencia

---

## 5.2 Diagrama de un User Journey completo

```
ETAPA:     Descubrimiento → Consideración → Decisión → Conversión → Retención
              │                  │              │           │            │
ACCIÓN:    Ve un anuncio     Visita la web   Compara     Compra      Usa el
           en Instagram      Lee beneficios  precios     producto    producto
              │                  │              │           │            │
EMOCIÓN:   Curiosidad        Interés         Duda        Alivio      Satisfacción
           😐                😊              🤔          😌          😊
              │                  │              │           │            │
TOUCHPOINT: Instagram ad     Landing page    Pricing     Checkout    Dashboard
              │                  │              │           │            │
PAIN POINT: "¿Es real?"     "¿Cómo funciona?" "¿Vale la  "Muchos     "¿Cómo
                                              pena?"      pasos"      empiezo?"
              │                  │              │           │            │
OPORTUNIDAD: Social proof   Demo/video       Tabla       Checkout    Onboarding
                                             comparativa  simplificado guiado
```

---

## 5.3 Touchpoints y momentos de verdad

### Touchpoints
Son todos los puntos donde el usuario interactúa con la marca o producto:
- Anuncios (Instagram, Google)
- Landing page
- Emails
- Producto (dashboard, app)
- Soporte

### Momentos de verdad

| Momento              | Descripción                                     | Ejemplo                          |
|---------------------|--------------------------------------------------|----------------------------------|
| Zero Moment (ZMOT)  | Primera búsqueda o contacto                      | Googlea "mejor CRM"             |
| First Moment        | Primera impresión del producto                   | Ve la landing page               |
| Second Moment       | Experiencia de uso real                          | Usa el producto                  |
| Ultimate Moment     | El usuario se convierte en promotor              | Recomienda a un amigo            |

---

# 6. Pain Points (Puntos de dolor)

---

## 6.1 Definición y categorías

**Pain Points** son problemas, frustraciones o barreras que impiden al usuario avanzar o completar un objetivo.

### Categorías de pain points

| Categoría        | Descripción                                      | Ejemplo                             |
|-----------------|--------------------------------------------------|--------------------------------------|
| Funcional       | El producto no hace lo que el usuario necesita   | Falta una feature clave              |
| Usabilidad      | Es difícil de usar o entender                    | Navegación confusa                   |
| Financiero      | El precio no se justifica o no es claro          | Costos ocultos en checkout           |
| Soporte         | Falta ayuda cuando el usuario la necesita        | No hay chat, docs pobres            |
| Proceso         | Demasiados pasos o fricción                      | Formulario de 15 campos             |

---

## 6.2 Cómo identificarlos

| Método                    | Descripción                                        |
|--------------------------|----------------------------------------------------|
| Entrevistas con usuarios | Preguntar directamente sobre frustraciones         |
| Tests de usabilidad      | Observar dónde se atascan                          |
| Analytics                | Detectar páginas con alta tasa de abandono         |
| Heatmaps                 | Ver dónde hacen clic (y dónde no)                  |
| Reviews / soporte        | Analizar quejas y preguntas frecuentes             |
| Session recordings       | Ver el comportamiento real del usuario             |

---

## 6.3 Del pain point a la oportunidad de diseño

Cada pain point es una **oportunidad de mejora**. El proceso profesional es:

```
Identificar pain point → Analizar causa raíz → Diseñar solución → Validar con usuario
```

### Ejemplo práctico

| Pain Point                          | Causa raíz                    | Solución de diseño              |
|------------------------------------|-------------------------------|----------------------------------|
| "No entiendo qué hace el producto" | Propuesta de valor poco clara | Reescribir hero con beneficio    |
| "El formulario es muy largo"       | Campos innecesarios           | Reducir a 3-4 campos esenciales  |
| "No sé si es confiable"           | Falta de prueba social        | Añadir testimonios y logos       |
| "Me pierdo en la navegación"      | Estructura confusa            | Reorganizar IA + simplificar menú|

---

# 7. Jobs To Be Done (JTBD)

---

## 7.1 Concepto y origen

**Jobs To Be Done** es un framework creado por Clayton Christensen que cambia la forma de pensar sobre el usuario. En lugar de preguntarse "¿quién es mi usuario?", se pregunta:

> **"¿Qué trabajo está intentando hacer mi usuario?"**

El usuario no "compra" un producto. **Contrata** un producto para hacer un trabajo.

### Ejemplos clásicos

| Lo que parece que compra | Lo que realmente quiere             |
|--------------------------|-------------------------------------|
| Un taladro               | Hacer un agujero en la pared        |
| Un curso de UX           | Conseguir un mejor trabajo          |
| Netflix                  | Entretenerse sin esfuerzo           |
| Slack                    | Comunicarse rápido con su equipo    |
| Un CRM                   | No perder oportunidades de venta    |

---

## 7.2 Estructura de un Job Statement

Un Job Statement bien formulado sigue esta estructura:

```
Cuando [situación], quiero [motivación], para poder [resultado esperado].
```

### Ejemplos

- *Cuando estoy buscando un software de gestión, quiero comparar precios y features fácilmente, para poder tomar una decisión informada.*
- *Cuando recibo muchos leads, quiero organizarlos automáticamente, para poder responder rápido y no perder ventas.*

---

## 7.3 JTBD aplicado al diseño

El JTBD influye directamente en las decisiones de diseño:

| Decisión de diseño        | Sin JTBD                        | Con JTBD                               |
|--------------------------|----------------------------------|-----------------------------------------|
| Hero de landing page     | "Somos la mejor plataforma"     | "Organiza tus leads sin esfuerzo"       |
| Feature list             | Lista técnica de funciones       | Beneficios ligados a resultados         |
| Onboarding               | Tutorial genérico                | Guía hacia el primer "aha moment"       |
| Pricing                  | Planes por features              | Planes por resultado esperado           |

> **Regla:** Diseña para el resultado que el usuario busca, no para las características del producto.

---

# 8. Arquitectura de la Información (IA)

---

## 8.1 Definición y principios

La **Arquitectura de la Información (IA)** define cómo se organiza, estructura y etiqueta el contenido dentro de un producto digital para que los usuarios puedan encontrar lo que buscan y completar tareas de forma eficiente.

### Principios fundamentales

| Principio        | Descripción                                              |
|-----------------|----------------------------------------------------------|
| Claridad         | El usuario entiende dónde está y qué puede hacer         |
| Jerarquía        | Lo más importante es lo más visible y accesible          |
| Agrupación lógica| Elementos relacionados están juntos                      |
| Consistencia     | La estructura es predecible en todo el producto          |
| Encontrabilidad  | El usuario llega a lo que busca en ≤3 clics             |

### Ejemplo: Buena vs Mala IA

```
MALA IA:                              BUENA IA:
┌──────────────────┐                  ┌──────────────────┐
│ Menú confuso     │                  │ Inicio           │
│ Info dispersa    │                  │ Servicios        │
│ Categorías poco  │                  │   └─ Web         │
│   claras         │                  │   └─ Mobile      │
│ Duplicación      │                  │   └─ Branding    │
│ Navegación rota  │                  │ Precios          │
└──────────────────┘                  │ Contacto         │
                                      └──────────────────┘
```

---

## 8.2 Modelos de organización

| Modelo           | Descripción                                   | Ejemplo                         |
|-----------------|-----------------------------------------------|---------------------------------|
| Jerárquico      | Estructura en árbol (padre → hijo)            | Sitio corporativo               |
| Secuencial      | Paso a paso lineal                            | Checkout, onboarding            |
| Matricial       | Múltiples caminos a la misma información      | Filtros en e-commerce           |
| Base de datos   | Contenido accesible por búsqueda/filtros      | Docs, APIs, catálogos           |

---

## 8.3 Card Sorting y Tree Testing

### Card Sorting

Técnica donde los usuarios organizan contenido en categorías que tienen sentido para ellos.

| Tipo       | Descripción                                   |
|-----------|------------------------------------------------|
| Abierto   | El usuario crea sus propias categorías          |
| Cerrado   | El usuario ubica items en categorías predefinidas|
| Híbrido   | Combina ambos enfoques                          |

**Uso:** Definir menús, categorías y estructura de navegación.

### Tree Testing

Evalúa si los usuarios pueden encontrar información dentro de una estructura de navegación propuesta (sin diseño visual).

**Uso:** Validar la IA antes de diseñar wireframes.

---

# 9. Heurísticas de Usabilidad de Jakob Nielsen

Las **10 heurísticas de Nielsen** son los principios fundamentales de usabilidad. Todo diseño debe ser evaluado contra estos criterios:

| #  | Heurística                              | Descripción                                           | Ejemplo práctico                       |
|----|----------------------------------------|-------------------------------------------------------|----------------------------------------|
| 1  | Visibilidad del estado del sistema      | El sistema informa qué está pasando                   | Loader, barra de progreso              |
| 2  | Correspondencia con el mundo real       | Usa lenguaje y conceptos del usuario                  | "Carrito" en vez de "unidad de compra" |
| 3  | Control y libertad del usuario          | Permite deshacer y salir fácilmente                   | Botón "Deshacer", salir de modal       |
| 4  | Consistencia y estándares               | Sigue convenciones conocidas                          | Logo en esquina = link a Home          |
| 5  | Prevención de errores                   | Diseña para evitar errores antes de que ocurran       | Validación en tiempo real en forms     |
| 6  | Reconocimiento antes que memoria        | Muestra opciones en vez de forzar al usuario a recordar| Autocompletado, menús visibles        |
| 7  | Flexibilidad y eficiencia de uso        | Permite atajos para usuarios expertos                 | Shortcuts de teclado                   |
| 8  | Diseño estético y minimalista           | Cada elemento debe justificar su presencia            | Eliminar texto innecesario             |
| 9  | Ayuda al usuario a reconocer y recuperarse de errores | Mensajes de error claros y accionables | "Email inválido. Ejemplo: a@b.com"    |
| 10 | Ayuda y documentación                   | Proveer ayuda accesible cuando sea necesaria          | Tooltips, docs, chat de soporte        |

> **Regla:** Estas heurísticas no son opcionales. Son el estándar mínimo de calidad en diseño de interfaces.

---

# 10. Principios transversales de UX

---

## 10.1 Reducción de fricción

**Fricción** es todo lo que dificulta que el usuario avance hacia su objetivo.

### Tipos de fricción

| Tipo              | Ejemplo                                        |
|------------------|-------------------------------------------------|
| Cognitiva        | Demasiada información, opciones confusas         |
| De interacción   | Muchos clics, formularios largos                |
| Visual           | Interfaz desordenada, sin jerarquía             |
| Emocional        | Desconfianza, inseguridad sobre el resultado    |

### Principio fundamental

> **Cada elemento en la interfaz debe justificar su existencia.** Si no ayuda al usuario a avanzar, es fricción.

### Estrategias de reducción

- Reducir campos en formularios al mínimo esencial
- Simplificar la navegación
- Eliminar información que no ayuda a la decisión
- Usar defaults inteligentes
- Progressive disclosure (revelar información gradualmente)

---

## 10.2 Scanning behavior (Comportamiento de escaneo)

**Los usuarios no leen. Escanean.**

### Patrones de escaneo

```
F-PATTERN (sitios con texto):        Z-PATTERN (landing pages):
┌────────────────────────┐           ┌────────────────────────┐
│ ██████████████████████ │           │ ●──────────────────→ ● │
│ ██████████████████████ │           │         ↙               │
│ █████████████          │           │       ↙                 │
│ █████████              │           │     ↙                   │
│ ████████████████       │           │ ●──────────────────→ ● │
│ ██████████             │           │ (Logo→Menú→Diagonal→CTA)│
│ ████████               │           └────────────────────────┘
│ ██████                 │
└────────────────────────┘
```

### Implicaciones para diseño

- Títulos claros y descriptivos (H1, H2, H3)
- Párrafos cortos (máximo 3-4 líneas)
- Uso intensivo de listas y bullets
- Palabras clave en negrita
- Jerarquía visual clara

---

## 10.3 Feedback del sistema

El sistema **siempre** debe comunicar lo que está pasando. El silencio genera incertidumbre.

### Tipos de feedback

| Tipo             | Cuándo usarlo                    | Ejemplo                          |
|-----------------|-----------------------------------|----------------------------------|
| De progreso     | Acción en proceso                 | Loader, barra de progreso        |
| De éxito        | Acción completada                 | "Guardado correctamente" ✓       |
| De error        | Algo salió mal                    | "Email inválido" con contexto    |
| De confirmación | Antes de acción irreversible      | "¿Seguro que deseas eliminar?"   |
| De estado       | Informar situación actual         | "3 items en tu carrito"          |

### Regla

> Si el usuario hizo algo y no pasó nada visible, el diseño falló.

---

## 10.4 Consistencia

**Consistencia** significa mantener coherencia en todo el producto. Reduce la carga cognitiva y permite al usuario predecir comportamientos.

### Dimensiones de consistencia

| Dimensión      | Qué implica                               | Ejemplo                           |
|---------------|--------------------------------------------|------------------------------------|
| Visual        | Mismos colores, tipografía, spacing        | Botones siempre del mismo estilo   |
| Funcional     | Mismos patrones de interacción             | Swipe siempre hace lo mismo        |
| De contenido  | Mismo tono, voz y terminología             | "Guardar" en todo, no "Salvar"     |
| Externa       | Seguir convenciones del ecosistema         | Hamburger menu = menú en mobile    |

### Concepto clave

```
Un diseño con buen UX:
  ✓ Es fácil de entender sin explicación
  ✓ Reduce decisiones innecesarias
  ✓ Guía al usuario de forma natural
  ✓ Es predecible (sin sorpresas negativas)
```

---

# Parte III — Fundamentos de UI (User Interface)

---

# 11. ¿Qué es UI?

---

## 11.1 Definición profesional

**UI (User Interface)** es la capa visual con la que el usuario interactúa. Es todo lo que ve, toca y percibe visualmente en un producto digital.

Incluye:
- Tipografía
- Colores
- Botones y componentes
- Espaciado y layout
- Iconografía
- Imágenes y recursos visuales

> **UI = Cómo se ve y cómo se presenta la información.**

---

## 11.2 Relación entre UX y UI

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│    UX define QUÉ debe pasar      → Flujos, estructura  │
│    UI define CÓMO se ve y percibe → Diseño visual       │
│                                                         │
│    UX sin UI = esqueleto sin piel                       │
│    UI sin UX = maquillaje sin estructura                │
│    UX + UI   = producto completo                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Un buen UI:
- **Refuerza** las decisiones de UX
- **Guía** visualmente al usuario hacia la acción
- **Reduce** la carga cognitiva a través de claridad visual

---

# 12. Jerarquía visual

**Jerarquía visual** es el principio de ordenar los elementos para dirigir la atención del usuario en el orden correcto.

### Cómo se logra

| Herramienta     | Efecto                                        |
|----------------|------------------------------------------------|
| Tamaño         | Más grande = más importante                    |
| Color/Contraste| Mayor contraste = más visible                  |
| Posición       | Arriba y a la izquierda = más prioridad        |
| Espaciado      | Más espacio alrededor = más énfasis            |
| Peso tipográfico| Bold = más importante que regular              |

### Ejemplo de jerarquía en una sección

```
┌──────────────────────────────────────┐
│                                      │
│  Organiza tu equipo                  │  ← H1 (32-48px, Bold)
│  sin esfuerzo                        │
│                                      │
│  La herramienta que simplifica       │  ← Subtítulo (18-24px, Regular)
│  la gestión de proyectos.            │
│                                      │
│  [ Empieza gratis ]                  │  ← CTA (color primario, destacado)
│                                      │
│  +10,000 equipos ya lo usan         │  ← Prueba social (14px, gris)
│                                      │
└──────────────────────────────────────┘
```

> **Regla de oro:** Si todo destaca, nada destaca.

---

# 13. Tipografía

---

## 13.1 Escala tipográfica

La tipografía es uno de los elementos más importantes del diseño UI. Una escala tipográfica bien definida crea jerarquía, legibilidad y consistencia.

### Escala recomendada

| Nivel     | Tamaño       | Uso                        |
|----------|-------------|----------------------------|
| Display  | 48-72px      | Titulares de hero          |
| H1       | 32-48px      | Títulos de sección         |
| H2       | 24-32px      | Subtítulos                 |
| H3       | 20-24px      | Sub-subtítulos             |
| Body     | 16-18px      | Texto principal            |
| Small    | 14px         | Labels, captions           |
| Caption  | 12px         | Notas, metadata            |

---

## 13.2 Buenas prácticas

- **Máximo 2-3 fuentes** — Una para headings, otra para body
- **Tipos principales:**
  - **Sans-serif** (Roboto, Inter, Open Sans) → Moderno, limpio
  - **Serif** (Georgia, Merriweather) → Clásico, formal
  - **Monospace** (Fira Code, JetBrains Mono) → Código
- **Interlineado (line-height):** 1.4-1.6x del tamaño de fuente para body
- **Longitud de línea:** 50-75 caracteres por línea para lectura óptima
- **Contraste:** El texto debe ser fácilmente legible contra el fondo

---

# 14. Color

---

## 14.1 Función del color en UI

El color no es decorativo. Cumple funciones específicas:

| Función          | Descripción                                    | Ejemplo                       |
|-----------------|------------------------------------------------|-------------------------------|
| Comunicar       | Transmitir emociones y significado             | Rojo = error / urgencia       |
| Guiar           | Dirigir la atención a acciones clave           | CTA en color primario         |
| Diferenciar     | Separar elementos y estados                    | Activo vs inactivo            |
| Agrupar         | Indicar relación entre elementos               | Mismo color = mismo grupo     |

---

## 14.2 Paleta y sistema de color

### Estructura de una paleta

| Tipo           | Uso                                   | Ejemplo                    |
|---------------|---------------------------------------|----------------------------|
| Primario      | Acciones principales, CTAs            | Azul (#2563EB)             |
| Secundario    | Acciones secundarias, acentos         | Purple (#7C3AED)           |
| Neutral        | Fondos, bordes, texto secundario      | Grises (#F3F4F6 → #1F2937) |
| Éxito (Success)| Confirmaciones, estados positivos     | Verde (#10B981)            |
| Error          | Errores, alertas destructivas         | Rojo (#EF4444)             |
| Warning        | Advertencias, precaución              | Amarillo (#F59E0B)         |
| Info           | Información, tips                     | Azul claro (#3B82F6)       |

### Regla de contraste

- **WCAG AA mínimo:** ratio 4.5:1 para texto normal, 3:1 para texto grande
- **WCAG AAA ideal:** ratio 7:1

### Error común

> Usar muchos colores sin propósito. Limitar la paleta a 3-5 colores principales con variaciones.

---

# 15. Espaciado (Whitespace)

El espacio entre elementos es tan importante como los elementos mismos.

### Función del whitespace

| Función         | Descripción                              |
|----------------|------------------------------------------|
| Legibilidad    | Facilita la lectura y comprensión        |
| Agrupación     | Elementos cercanos se perciben relacionados (Ley de Proximidad) |
| Énfasis        | Más espacio alrededor = más importancia  |
| Respiración    | Reduce saturación visual                 |

### Sistema de espaciado (escala de 4/8px)

Usar una escala consistente basada en múltiplos de 4 u 8:

```
4px  → micro spacing (entre icono y label)
8px  → tight spacing (dentro de componentes)
16px → base spacing (entre elementos)
24px → comfortable spacing (entre bloques)
32px → section spacing (entre secciones menores)
48px → large spacing (entre secciones)
64px → extra-large (entre secciones mayores)
96px → page-level (entre partes de la página)
```

> **Regla:** El espacio también es diseño. No llenar todo de contenido.

---

# 16. Grid System (Sistema de rejilla)

El grid es la estructura invisible que organiza todo el contenido de una interfaz.

### Grid de 12 columnas (estándar)

```
│ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │
├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
│◄──────── 6 col ──────►│◄──────── 6 col ──────►│  ← 50/50
│◄──── 4 col ──►│◄──── 4 col ──►│◄──── 4 col ──►│  ← Tercios
│◄─ 3 ─►│◄─ 3 ─►│◄─ 3 ─►│◄─ 3 ─►│                  ← Cuartos
```

### Anatomía del grid

| Componente | Descripción                              |
|-----------|------------------------------------------|
| Columnas  | Bloques verticales de contenido (12)     |
| Gutter    | Espacio entre columnas (16-32px)         |
| Margin    | Espacio lateral exterior (16-80px)       |

### Beneficios

- Alineación consistente en toda la interfaz
- Diseño ordenado y escalable
- Facilita responsive design (columnas colapsan)
- Estándar que desarrolladores entienden

---

# 17. Componentes UI y estados

**Componentes** son elementos reutilizables de la interfaz.

### Componentes fundamentales

| Componente | Uso                                       |
|-----------|-------------------------------------------|
| Button    | Acciones principales y secundarias        |
| Input     | Captura de datos del usuario              |
| Card      | Contenedor de información agrupada        |
| Navbar    | Navegación principal                      |
| Modal     | Información o acción en overlay           |
| Dropdown  | Selección de opciones                     |
| Tab       | Navegación entre secciones en mismo nivel |
| Toast     | Notificaciones temporales                 |

### Estados de un componente

Todo componente interactivo debe tener estados definidos:

```
┌───────────────────────────────────────────────────┐
│  ESTADOS DE UN BOTÓN                              │
│                                                   │
│  [ Default  ]  → Estado normal, listo para usar   │
│  [ Hover    ]  → Cursor encima (desktop)          │
│  [ Active   ]  → Siendo presionado                │
│  [ Focus    ]  → Seleccionado por teclado (a11y)  │
│  [ Disabled ]  → No disponible (gris, opacidad)   │
│  [ Loading  ]  → Procesando acción (spinner)      │
│                                                   │
└───────────────────────────────────────────────────┘
```

> **Regla:** Un componente sin estados definidos no está terminado.

---

# 18. Accesibilidad básica en UI

La accesibilidad no es un extra. Es un requisito mínimo de calidad.

### Checklist básico de accesibilidad UI

| Criterio                    | Requisito                                          |
|----------------------------|----------------------------------------------------|
| Contraste de texto         | Ratio mínimo 4.5:1 (WCAG AA)                      |
| Tamaño de fuente           | Mínimo 16px para body text                         |
| Tamaño de target (tap)     | Mínimo 44x44px para elementos interactivos         |
| Focus visible              | Indicador de foco claro para navegación por teclado |
| Alt text                   | Todas las imágenes con descripción significativa   |
| No depender solo del color | Usar iconos, texto o patrones además del color     |
| Labels en formularios      | Todos los inputs con labels visibles y asociados   |

### Impacto

- Mejora la experiencia para **todos** los usuarios (no solo usuarios con discapacidad)
- Mejora **SEO** (HTML semántico)
- Requisito **legal** en muchos países
- Aumenta **conversión** (interfaces más claras = menos fricción)

---

# 19. Feedback visual

El feedback visual son las respuestas visuales que la interfaz da a las acciones del usuario. Es la forma en que el sistema "habla" con el usuario.

### Tipos de feedback visual

| Tipo                 | Ejemplo                                      |
|---------------------|----------------------------------------------|
| Hover               | Botón cambia de color al pasar el cursor     |
| Press/Active        | Botón se oscurece al presionar               |
| Transiciones        | Animaciones suaves entre estados             |
| Loading             | Spinner, skeleton screen, barra de progreso  |
| Success             | Check verde, mensaje de confirmación          |
| Error               | Borde rojo en input, mensaje descriptivo     |
| Microinteracciones  | Animación al añadir al carrito, like, toggle |

### Principios de buen feedback

```
1. Inmediato    → La respuesta debe ser instantánea (<100ms)
2. Contextual   → Relacionado con la acción que hizo el usuario
3. Sutil        → No interrumpir ni distraer
4. Informativo  → Comunicar qué pasó y qué hacer después
5. Consistente  → Mismo tipo de feedback para mismas acciones
```

### Concepto final

```
┌───────────────────────────────────────────────────┐
│           UN BUEN DISEÑO UI:                      │
│                                                   │
│   ✓ Dirige la atención sin esfuerzo               │
│   ✓ Hace evidente qué hacer                       │
│   ✓ Mantiene coherencia visual                    │
│   ✓ Responde a cada acción del usuario            │
│   ✓ Es accesible para todos                       │
│                                                   │
└───────────────────────────────────────────────────┘
```

---

> *"Good design is obvious. Great design is transparent."*
> — Joe Sparano
