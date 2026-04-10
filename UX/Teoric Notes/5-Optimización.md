# Optimización: CRO, Accesibilidad y Performance UX

> *"If you think good design is expensive, you should look at the cost of bad design."*
> — Ralf Speth

---

## Tabla de Contenidos

### Parte I — CRO (Conversion Rate Optimization)
- [1. ¿Qué es CRO?](#1-qué-es-cro)
  - [1.1 Definición y objetivo](#11-definición-y-objetivo)
  - [1.2 Por qué importa](#12-por-qué-importa)
- [2. Métricas fundamentales](#2-métricas-fundamentales)
- [3. Proceso de CRO](#3-proceso-de-cro)
- [4. A/B Testing](#4-ab-testing)
  - [4.1 Definición y mecánica](#41-definición-y-mecánica)
  - [4.2 Elementos testeables](#42-elementos-testeables)
  - [4.3 Buenas prácticas](#43-buenas-prácticas)
- [5. Herramientas de análisis](#5-herramientas-de-análisis)
  - [5.1 Heatmaps](#51-heatmaps)
  - [5.2 Session recordings](#52-session-recordings)
  - [5.3 Funnel analysis](#53-funnel-analysis)
- [6. Optimización de elementos clave](#6-optimización-de-elementos-clave)
  - [6.1 CTAs](#61-ctas)
  - [6.2 Formularios](#62-formularios)
  - [6.3 Contenido y copy](#63-contenido-y-copy)
- [7. Psicología aplicada a CRO](#7-psicología-aplicada-a-cro)
- [8. Errores comunes en CRO](#8-errores-comunes-en-cro)
- [9. Ciclo de iteración CRO](#9-ciclo-de-iteración-cro)

### Parte II — Accesibilidad (A11Y)
- [10. ¿Qué es accesibilidad?](#10-qué-es-accesibilidad)
  - [10.1 Definición y alcance](#101-definición-y-alcance)
  - [10.2 Importancia y beneficios](#102-importancia-y-beneficios)
- [11. Principios WCAG](#11-principios-wcag)
  - [11.1 Perceptible](#111-perceptible)
  - [11.2 Operable](#112-operable)
  - [11.3 Comprensible](#113-comprensible)
  - [11.4 Robusto](#114-robusto)
- [12. Tipos de discapacidades y su impacto](#12-tipos-de-discapacidades-y-su-impacto)
- [13. Buenas prácticas de accesibilidad](#13-buenas-prácticas-de-accesibilidad)
  - [13.1 Contraste de color](#131-contraste-de-color)
  - [13.2 Tipografía y legibilidad](#132-tipografía-y-legibilidad)
  - [13.3 Texto alternativo (alt text)](#133-texto-alternativo-alt-text)
  - [13.4 Navegación por teclado](#134-navegación-por-teclado)
  - [13.5 Formularios accesibles](#135-formularios-accesibles)
- [14. Accesibilidad en componentes UI](#14-accesibilidad-en-componentes-ui)
- [15. Accesibilidad en desarrollo](#15-accesibilidad-en-desarrollo)
  - [15.1 HTML semántico](#151-html-semántico)
  - [15.2 ARIA](#152-aria)
  - [15.3 Lectores de pantalla](#153-lectores-de-pantalla)
- [16. Testing de accesibilidad](#16-testing-de-accesibilidad)
- [17. Accesibilidad y negocio](#17-accesibilidad-y-negocio)
- [18. Nivel avanzado en accesibilidad](#18-nivel-avanzado-en-accesibilidad)

### Parte III — Performance UX
- [19. ¿Qué es Performance UX?](#19-qué-es-performance-ux)
  - [19.1 Definición](#191-definición)
  - [19.2 Impacto en conversión](#192-impacto-en-conversión)
- [20. Percepción de velocidad](#20-percepción-de-velocidad)
  - [20.1 Real vs percibida](#201-real-vs-percibida)
  - [20.2 Umbrales de percepción](#202-umbrales-de-percepción)
- [21. Métricas de rendimiento (Core Web Vitals)](#21-métricas-de-rendimiento-core-web-vitals)
- [22. Estrategias de optimización técnica](#22-estrategias-de-optimización-técnica)
- [23. Estrategias de diseño para percepción](#23-estrategias-de-diseño-para-percepción)
- [24. Performance en mobile](#24-performance-en-mobile)
- [25. Testing y monitoreo](#25-testing-y-monitoreo)
- [26. Impacto en negocio](#26-impacto-en-negocio)

---

# Parte I — CRO (Conversion Rate Optimization)

---

# 1. ¿Qué es CRO?

---

## 1.1 Definición y objetivo

**CRO (Conversion Rate Optimization)** es el proceso sistemático de aumentar el porcentaje de usuarios que realizan una acción deseada en un sitio web o producto digital.

La acción puede ser:
- Comprar un producto
- Registrarse en una plataforma
- Completar un formulario
- Descargar un recurso
- Agendar una demo

> **CRO no es "hacer más bonito el diseño". Es tomar decisiones basadas en datos para eliminar barreras de conversión.**

---

## 1.2 Por qué importa

| Sin CRO                                   | Con CRO                                     |
|-------------------------------------------|----------------------------------------------|
| Cambios basados en opiniones              | Cambios basados en datos                     |
| Se asume que el diseño funciona           | Se valida con usuarios reales                |
| Se invierte más en tráfico               | Se optimiza lo que ya se tiene               |
| Conversión estancada                      | Mejora continua y medible                    |

### Impacto real

```
Ejemplo:
  Tráfico: 10,000 visitas/mes
  Conversión actual: 2% → 200 conversiones
  Conversión optimizada: 3% → 300 conversiones
  
  +50% más conversiones SIN gastar más en tráfico
```

---

# 2. Métricas fundamentales

| Métrica                    | Fórmula / Descripción                              | Rango saludable        |
|---------------------------|----------------------------------------------------|------------------------|
| Conversion Rate           | Conversiones / Visitantes × 100                    | 2-5% (varía por sector)|
| CTR (Click-Through Rate)  | Clics / Impresiones × 100                          | 2-10%                  |
| Bounce Rate               | Sesiones de 1 página / Total sesiones × 100        | 20-45% (landing)       |
| Cart Abandonment Rate     | Abandonos / Carritos iniciados × 100               | 60-80% (promedio)      |
| Form Completion Rate      | Envíos / Inicios de formulario × 100               | 20-40%                 |
| Time on Page              | Tiempo promedio en una página                       | Depende del contenido  |
| Scroll Depth              | % del contenido que ve el usuario                   | 50-75% ideal           |

> **No se puede mejorar lo que no se mide.** Antes de optimizar, define tus métricas baseline.

---

# 3. Proceso de CRO

```
┌──────────────────────────────────────────────────────────────┐
│                    PROCESO DE CRO                             │
│                                                               │
│  1. ANALIZAR                                                  │
│     └─ Recopilar datos: analytics, heatmaps, recordings      │
│            ↓                                                  │
│  2. IDENTIFICAR PROBLEMAS                                     │
│     └─ ¿Dónde abandonan? ¿Qué no funciona?                  │
│            ↓                                                  │
│  3. FORMULAR HIPÓTESIS                                        │
│     └─ "Si cambio X, esperamos Y porque Z"                  │
│            ↓                                                  │
│  4. DISEÑAR CAMBIOS                                           │
│     └─ Crear variantes de la solución propuesta              │
│            ↓                                                  │
│  5. TESTEAR (A/B Test)                                        │
│     └─ Ejecutar test con muestra significativa               │
│            ↓                                                  │
│  6. EVALUAR RESULTADOS                                        │
│     └─ ¿El cambio mejoró la métrica? ¿Es significativo?     │
│            ↓                                                  │
│  7. IMPLEMENTAR o ITERAR                                      │
│     └─ Si funciona → implementar. Si no → nueva hipótesis   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

# 4. A/B Testing

---

## 4.1 Definición y mecánica

**A/B Testing** consiste en comparar dos versiones (A y B) de un mismo elemento para determinar cuál funciona mejor.

```
TRÁFICO TOTAL (100%)
        │
   ┌────┴────┐
   │         │
   ▼         ▼
Versión A  Versión B
  (50%)     (50%)
   │         │
   ▼         ▼
Medir      Medir
conversión conversión
   │         │
   └────┬────┘
        │
  GANADOR → Implementar
```

---

## 4.2 Elementos testeables

| Elemento                | Qué testear                                    |
|------------------------|------------------------------------------------|
| Headlines              | Beneficio vs feature, largo vs corto           |
| CTAs                   | Texto, color, tamaño, posición                 |
| Layout                 | Orden de secciones, estructura visual          |
| Formularios            | Número de campos, layout, labels               |
| Imágenes               | Producto vs persona, estilo visual             |
| Pricing                | Formato, planes visibles, ancla                |
| Social proof           | Testimonios vs métricas vs logos               |
| Copy                   | Tono, longitud, enfoque                        |

---

## 4.3 Buenas prácticas

| Práctica                          | Razón                                          |
|----------------------------------|------------------------------------------------|
| Testear UNA variable a la vez    | Para saber qué causó el cambio                 |
| Muestra suficiente               | Mínimo 1,000 visitantes por variante          |
| Tiempo adecuado                  | Mínimo 1-2 semanas (cubrir ciclos)             |
| Significancia estadística        | 95% confidence level antes de concluir         |
| Documentar todo                  | Hipótesis, resultados, aprendizajes            |
| No detener prematuramente        | Resultados tempranos pueden ser engañosos      |

---

# 5. Herramientas de análisis

---

## 5.1 Heatmaps

Visualizan dónde hacen clic, mueven el cursor y hacen scroll los usuarios.

| Tipo              | Qué muestra                              | Herramienta     |
|------------------|------------------------------------------|-----------------|
| Click heatmap    | Dónde hacen clic                          | Hotjar, Crazy Egg|
| Scroll heatmap   | Hasta dónde llegan                        | Hotjar           |
| Move heatmap     | Dónde se mueve el cursor                  | Crazy Egg        |

### Qué buscar

- Clics en elementos no interactivos → confusión
- Zona fría debajo del fold → contenido invisible
- Concentración de clics lejos del CTA → distracción

---

## 5.2 Session recordings

Grabaciones del comportamiento real del usuario navegando el sitio.

### Qué buscar

- Rage clicks (clics repetidos de frustración)
- Scroll rápido (contenido ignorado)
- Abandono en puntos específicos
- Confusión en formularios

---

## 5.3 Funnel analysis

Visualiza el flujo del usuario y dónde abandona en cada paso.

```
Landing Page:  1,000 usuarios  (100%)
      ↓
Pricing:         600 usuarios  (60%)   ← 40% drop-off
      ↓
Sign Up:         300 usuarios  (30%)   ← 50% drop-off
      ↓
Checkout:        150 usuarios  (15%)   ← 50% drop-off
      ↓
Conversión:       90 usuarios  (9%)    ← 40% drop-off
```

> **El funnel analysis revela exactamente dónde se pierde dinero.**

---

# 6. Optimización de elementos clave

---

## 6.1 CTAs

| Aspecto          | Optimización                                          |
|-----------------|-------------------------------------------------------|
| Texto           | Acción + beneficio ("Empieza gratis" > "Submit")      |
| Color           | Alto contraste con el fondo                           |
| Tamaño          | Suficiente para ser visible (mínimo 44px height)      |
| Posición        | Above the fold + repetido tras cada sección           |
| Cantidad        | 1 CTA primario por sección (evitar competencia)       |
| Urgencia        | Opcional: countdown, plazas limitadas                 |

---

## 6.2 Formularios

| Aspecto          | Optimización                                          |
|-----------------|-------------------------------------------------------|
| Campos          | Reducir al mínimo esencial (cada campo extra = -7%)  |
| Layout          | 1 columna en mobile, máximo 2 en desktop             |
| Labels          | Siempre visibles (no solo placeholders)              |
| Validación      | En tiempo real, no al enviar                         |
| Progreso        | Indicador en formularios multi-step                  |
| Microcopy       | Help text en campos ambiguos                         |

---

## 6.3 Contenido y copy

| Aspecto          | Optimización                                          |
|-----------------|-------------------------------------------------------|
| Headlines       | Beneficio claro en <3 segundos                        |
| Estructura      | Escaneable (listas, subtítulos, negrita)             |
| Longitud        | Suficiente para informar, no más                     |
| Social proof    | Datos concretos > frases genéricas                   |
| Objeciones      | Anticipar y resolver en el copy                      |

---

# 7. Psicología aplicada a CRO

| Principio                 | Aplicación en CRO                                  |
|--------------------------|-----------------------------------------------------|
| Reducción de incertidumbre| Garantías, prueba social, FAQs                      |
| Refuerzo del valor        | Beneficios claros, resultados concretos             |
| Urgencia y escasez        | Countdowns, plazas limitadas (usa con ética)        |
| Reciprocidad              | Valor gratuito primero → conversión después         |
| Anclaje                   | Precio original tachado, plan premium como ancla    |
| Aversión a la pérdida     | "No pierdas tu progreso", trial que expira          |

---

# 8. Errores comunes en CRO

| Error                                    | Consecuencia                                  |
|-----------------------------------------|-----------------------------------------------|
| Hacer cambios sin datos                  | Optimización basada en opiniones              |
| Cambiar múltiples variables a la vez     | No saber qué causó el resultado              |
| Ignorar el contexto del usuario          | Optimizar para métricas, no para personas    |
| Enfocarse solo en el final del funnel    | Problemas arriba arruinan todo abajo         |
| Detener tests prematuramente             | Resultados no significativos                 |
| No documentar                            | Se repiten errores, se pierde conocimiento   |
| Copiar lo que hace la competencia        | Contextos diferentes, resultados diferentes  |

---

# 9. Ciclo de iteración CRO

```
┌─────────────────────────────────────────┐
│          CICLO CRO CONTINUO             │
│                                          │
│    Medir → Analizar → Hipótesis          │
│      ↑                    ↓              │
│    Implementar ← Testear (A/B)          │
│                                          │
│  Este ciclo NUNCA termina.               │
│  La optimización es continua.            │
│                                          │
└─────────────────────────────────────────┘
```

---

# Parte II — Accesibilidad (A11Y)

---

# 10. ¿Qué es accesibilidad?

---

## 10.1 Definición y alcance

**Accesibilidad (A11Y)** es el diseño y desarrollo de productos digitales que pueden ser utilizados por todas las personas, incluyendo aquellas con discapacidades.

Incluye usuarios con:
- Discapacidad visual (ceguera, baja visión, daltonismo)
- Discapacidad auditiva (sordera parcial o total)
- Limitaciones motoras (dificultad de uso de mouse/teclado)
- Discapacidad cognitiva (dificultades de atención, comprensión)

> **El objetivo es eliminar barreras que impidan el acceso o la interacción con una interfaz.**

---

## 10.2 Importancia y beneficios

| Beneficio                    | Descripción                                         |
|-----------------------------|-----------------------------------------------------|
| Alcance ampliado            | +15% de la población mundial tiene alguna discapacidad |
| Mejor experiencia general   | Un diseño accesible es más claro para TODOS         |
| Conversión mejorada         | Interfaces más claras = menos fricción              |
| Cumplimiento legal          | Obligatorio en muchos países (ADA, EAA)             |
| SEO mejorado                | HTML semántico y alt text mejoran indexación         |
| Reputación de marca         | Compromiso con inclusión                            |

---

# 11. Principios WCAG

Las **WCAG (Web Content Accessibility Guidelines)** son el estándar internacional de accesibilidad. Se organizan en 4 principios:

---

## 11.1 Perceptible

La información debe ser presentada de forma que los usuarios puedan percibirla.

| Requisito                                | Ejemplo                                      |
|-----------------------------------------|----------------------------------------------|
| Texto alternativo en imágenes            | `alt="Gráfico de ventas Q3 2024"`           |
| Contraste adecuado texto/fondo           | Ratio mínimo 4.5:1 (AA)                     |
| Contenido adaptable                      | Funciona en diferentes dispositivos          |
| No depender solo del color               | Usar iconos + texto + color para estados    |
| Subtítulos en video                      | Transcripciones y captions                   |

---

## 11.2 Operable

La interfaz debe poder ser utilizada por cualquier usuario.

| Requisito                                | Ejemplo                                      |
|-----------------------------------------|----------------------------------------------|
| Navegación por teclado                   | Tab, Enter, Escape funcionan correctamente   |
| Sin trampas de teclado                   | El usuario puede salir de cualquier elemento |
| Tiempo suficiente                        | Permitir extender timeouts                   |
| Sin contenido que cause convulsiones     | No más de 3 flashes por segundo              |
| Indicadores de foco visibles             | Outline visible al navegar con Tab           |

---

## 11.3 Comprensible

El contenido y la interfaz deben ser fáciles de entender.

| Requisito                                | Ejemplo                                      |
|-----------------------------------------|----------------------------------------------|
| Lenguaje claro                           | Evitar jerga innecesaria                     |
| Navegación consistente                   | Mismo orden de menú en todas las páginas     |
| Feedback en acciones                     | Mensajes de error/éxito claros               |
| Prevención de errores                    | Confirmación antes de acciones destructivas  |

---

## 11.4 Robusto

El contenido debe ser compatible con diferentes tecnologías.

| Requisito                                | Ejemplo                                      |
|-----------------------------------------|----------------------------------------------|
| HTML semántico correcto                  | `<button>` no `<div onclick>`                |
| Compatible con lectores de pantalla      | ARIA labels cuando sea necesario             |
| Compatible con navegadores               | Testing cross-browser                        |

---

# 12. Tipos de discapacidades y su impacto

| Tipo                  | Incluye                                | Impacto en UX                               |
|----------------------|----------------------------------------|----------------------------------------------|
| Visual               | Ceguera, baja visión, daltonismo       | Necesita lectores de pantalla, alto contraste, no depender del color |
| Auditiva             | Sordera parcial o total                | Necesita subtítulos, alternativas visuales   |
| Motora               | Limitaciones de manos, precisión       | Necesita navegación por teclado, targets grandes (44px+) |
| Cognitiva            | Dificultades de atención, comprensión  | Necesita interfaces simples, lenguaje claro  |

---

# 13. Buenas prácticas de accesibilidad

---

## 13.1 Contraste de color

| Nivel WCAG  | Ratio mínimo texto normal | Ratio mínimo texto grande |
|------------|---------------------------|---------------------------|
| AA          | 4.5:1                     | 3:1                       |
| AAA         | 7:1                       | 4.5:1                     |

**Herramientas:** Contrast Checker (WebAIM), Figma plugins (Stark, A11y)

---

## 13.2 Tipografía y legibilidad

| Práctica                          | Requisito                              |
|----------------------------------|----------------------------------------|
| Tamaño mínimo de body            | 16px                                   |
| Interlineado                     | 1.5x del tamaño de fuente             |
| Longitud de línea                | 50-75 caracteres                       |
| Evitar fuentes decorativas       | En textos largos, usar sans-serif      |
| No usar solo mayúsculas          | Dificulta la lectura                   |

---

## 13.3 Texto alternativo (alt text)

| Tipo de imagen          | Alt text recomendado                           |
|------------------------|------------------------------------------------|
| Informativa            | Descripción clara del contenido                 |
| Decorativa             | `alt=""` (vacío, no omitido)                   |
| Gráfico/chart          | Descripción de los datos que muestra           |
| Funcional (botón/link) | Descripción de la acción                       |

---

## 13.4 Navegación por teclado

| Requisito                    | Implementación                              |
|-----------------------------|----------------------------------------------|
| Tab navigation              | Todos los elementos interactivos accesibles  |
| Focus visible               | Outline claro (nunca `outline: none` sin reemplazo) |
| Orden lógico                | Estructura del DOM refleja orden visual      |
| Skip links                  | "Saltar al contenido principal"              |
| Escape para cerrar          | Modales, dropdowns, overlays                 |

---

## 13.5 Formularios accesibles

| Requisito                    | Implementación                              |
|-----------------------------|----------------------------------------------|
| Labels visibles             | `<label for="id">` asociado al input        |
| Errores descriptivos        | Qué está mal + cómo solucionarlo            |
| Instrucciones               | Help text antes del campo                    |
| Validación accesible        | `aria-describedby` para mensajes de error   |
| Agrupación lógica           | `<fieldset>` + `<legend>` para grupos        |

---

# 14. Accesibilidad en componentes UI

| Componente     | Requisitos A11Y                                     |
|---------------|------------------------------------------------------|
| Botones       | Texto descriptivo, estados de foco, tamaño mínimo 44px |
| Inputs        | Labels asociados, errores descriptivos, foco visible  |
| Modales       | Focus trap, cierre con Escape, aria-modal            |
| Dropdowns     | Navegación con flechas, aria-expanded, role="listbox"|
| Tabs          | role="tablist", arrow keys, aria-selected            |
| Tooltips      | aria-describedby, visible con keyboard focus          |
| Images        | Alt text significativo o alt="" si decorativa        |

---

# 15. Accesibilidad en desarrollo

---

## 15.1 HTML semántico

| ❌ Malo                    | ✅ Bueno                        | Por qué                         |
|---------------------------|----------------------------------|----------------------------------|
| `<div onclick="...">`     | `<button>`                       | Keyboard + screen reader support|
| `<div class="header">`    | `<header>`                       | Semántica para screen readers   |
| `<span>` como link        | `<a href="...">`                 | Navegable y anunciable          |
| `<div>` para lista        | `<ul>` / `<ol>` + `<li>`        | Estructura reconocible          |

---

## 15.2 ARIA

ARIA (Accessible Rich Internet Applications) proporciona atributos para mejorar accesibilidad cuando HTML semántico no es suficiente.

| Atributo              | Uso                                              |
|----------------------|--------------------------------------------------|
| `aria-label`         | Nombre accesible para elementos sin texto visible |
| `aria-hidden="true"` | Ocultar elementos decorativos de screen readers   |
| `aria-expanded`      | Indicar si un dropdown/acordeón está abierto      |
| `aria-live`          | Anunciar cambios dinámicos                         |
| `role`               | Definir el rol de un elemento personalizado       |

> **Regla:** Usa ARIA solo cuando HTML semántico no es suficiente. **First rule of ARIA: don't use ARIA.**

---

## 15.3 Lectores de pantalla

La interfaz debe ser interpretable correctamente por screen readers (VoiceOver, NVDA, JAWS).

| Requisito                    | Implementación                              |
|-----------------------------|----------------------------------------------|
| Estructura lógica           | Headings jerárquicos (H1 → H2 → H3)        |
| Orden de lectura            | Refleja el DOM, no el CSS                    |
| Descripciones claras        | Labels, alt text, aria-label                 |
| Anuncio de cambios          | aria-live para contenido dinámico            |

---

# 16. Testing de accesibilidad

| Tipo              | Descripción                                  | Herramientas                     |
|------------------|----------------------------------------------|----------------------------------|
| Automático       | Detecta problemas básicos rápidamente        | Lighthouse, axe, WAVE           |
| Manual           | Navegar con teclado, probar screen readers    | Teclado, VoiceOver, NVDA        |
| Con usuarios     | Testing con personas con discapacidades       | Entrevistas, observación         |

### Checklist rápido de testing manual

```
□ Navegar toda la interfaz solo con teclado (Tab, Enter, Escape)
□ Verificar que el foco es visible en todo momento
□ Activar screen reader y navegar el contenido
□ Verificar contraste con herramienta automática
□ Verificar que imágenes tienen alt text
□ Verificar formularios (labels, errores, ayuda)
□ Verificar que no se depende solo del color
□ Probar con zoom al 200%
```

---

# 17. Accesibilidad y negocio

| Impacto                    | Descripción                                      |
|---------------------------|--------------------------------------------------|
| Conversión                | Interfaces accesibles tienen menor fricción       |
| SEO                       | HTML semántico + alt text mejoran indexación       |
| Legal                     | Incumplimiento puede resultar en demandas         |
| Mercado                   | +1 billón de personas con discapacidad en el mundo|
| Reputación                | Demuestra compromiso con inclusión                |

---

# 18. Nivel avanzado en accesibilidad

| Concepto                         | Descripción                                        |
|---------------------------------|----------------------------------------------------|
| Diseño inclusivo                | Ir más allá de normas — diseñar para diversidad    |
| Accesibilidad desde el inicio   | Integrar en diseño, no añadir al final             |
| Cultura de accesibilidad        | Formación continua, checklists, revisión constante |
| A11Y en Design Systems          | Tokens y componentes con a11y built-in             |
| Testing continuo               | Automatizado en CI/CD + manual periódico           |

> **La accesibilidad no es un feature. Es un requisito mínimo de calidad profesional.**

---

# Parte III — Performance UX

---

# 19. ¿Qué es Performance UX?

---

## 19.1 Definición

**Performance UX** se refiere a cómo el rendimiento técnico impacta la experiencia del usuario. No es solo velocidad pura — es cómo el usuario **percibe** esa velocidad.

```
┌──────────────────────────────────────────────────┐
│                                                   │
│  Técnicamente rápido + sin feedback = LENTO      │
│  Técnicamente igual + con feedback  = RÁPIDO     │
│                                                   │
│  Performance UX = Ingeniería + Diseño             │
│                                                   │
└──────────────────────────────────────────────────┘
```

---

## 19.2 Impacto en conversión

| Tiempo de carga  | Impacto                                           |
|-----------------|---------------------------------------------------|
| 1s → 3s         | +32% probabilidad de rebote                       |
| 1s → 5s         | +90% probabilidad de rebote                       |
| 1s → 6s         | +106% probabilidad de rebote                      |
| 1s → 10s        | +123% probabilidad de rebote                      |

> **Cada segundo adicional de carga puede costar miles en conversiones perdidas.**

---

# 20. Percepción de velocidad

---

## 20.1 Real vs percibida

| Velocidad real                    | Velocidad percibida                        |
|-----------------------------------|--------------------------------------------|
| Tiempo técnico de carga           | Cómo SIENTE el usuario ese tiempo          |
| Se mide en milisegundos           | Se mide en experiencia                     |
| Mejora con optimización técnica   | Mejora con diseño (feedback, skeleton, progressive loading) |

---

## 20.2 Umbrales de percepción

```
0 - 100ms    →  Instantáneo (el usuario no nota delay)
100ms - 1s   →  Ligera percepción de retraso
1s - 3s      →  El usuario empieza a perder atención
3s - 5s      →  Frustración creciente
5s+          →  Alta probabilidad de abandono
```

> **Objetivo:** Mantener las interacciones principales bajo 1 segundo. Cargas de página bajo 3 segundos.

---

# 21. Métricas de rendimiento (Core Web Vitals)

| Métrica                          | Qué mide                                     | Umbral bueno |
|---------------------------------|-----------------------------------------------|-------------|
| FCP (First Contentful Paint)    | Primer contenido visible en pantalla          | < 1.8s      |
| LCP (Largest Contentful Paint)  | Contenido principal visible                   | < 2.5s      |
| TTI (Time to Interactive)       | Página completamente interactiva              | < 3.8s      |
| CLS (Cumulative Layout Shift)   | Estabilidad visual (no se mueven las cosas)   | < 0.1       |
| FID (First Input Delay)         | Tiempo de respuesta a primera interacción     | < 100ms     |
| INP (Interaction to Next Paint) | Responsividad general de interacciones        | < 200ms     |

---

# 22. Estrategias de optimización técnica

| Estrategia              | Descripción                                         |
|------------------------|-----------------------------------------------------|
| Minificación           | Reducir tamaño de CSS, JS, HTML                     |
| Compresión de imágenes | WebP, AVIF, srcset para responsive                  |
| Lazy loading           | Cargar contenido solo cuando es visible             |
| Code splitting         | Cargar solo el JS necesario por ruta                |
| Caching                | Almacenar recursos para visitas recurrentes         |
| CDN                    | Distribuir contenido cerca del usuario              |
| Preload / Prefetch     | Anticipar recursos que se necesitarán               |
| Server-side rendering  | Generar HTML en servidor (más rápido first paint)   |

---

# 23. Estrategias de diseño para percepción

| Estrategia              | Descripción                                         |
|------------------------|-----------------------------------------------------|
| Skeleton screens       | Estructura visual que simula contenido mientras carga|
| Feedback inmediato     | Cambio visual instantáneo al interactuar            |
| Carga progresiva       | Mostrar texto antes que imágenes                    |
| Optimistic UI          | Mostrar resultado esperado antes de confirmación    |
| Content prioritization | Cargar primero lo que está above the fold           |
| Perceived progress     | Barras de progreso, spinners contextuales           |

### Skeleton screens vs Spinners

```
SPINNER (peor):                    SKELETON (mejor):
┌──────────────────────┐          ┌──────────────────────┐
│                      │          │  ░░░░░░░░░░░░░░░     │
│                      │          │  ░░░░░░░░             │
│      ⟳ Loading...    │          │                      │
│                      │          │  ░░░░░░░░░░░░░░░░░░  │
│                      │          │  ░░░░░░░░░░░░░       │
│                      │          │                      │
└──────────────────────┘          │  [ ░░░░░░░░ ]        │
                                  └──────────────────────┘
El usuario no sabe                El usuario ve la estructura
qué esperar                       y percibe progreso
```

---

# 24. Performance en mobile

### Limitaciones móviles

| Factor               | Mobile                         | Desktop                     |
|---------------------|--------------------------------|-----------------------------|
| CPU                 | Menor capacidad                | Mayor capacidad             |
| Red                 | 3G/4G (más lenta, inestable)  | WiFi/fibra (más rápida)    |
| Batería             | Limitada (afecta rendering)    | No es factor                |
| Memoria             | Menor disponible               | Mayor disponible            |

### Estrategias específicas

- Imágenes optimizadas (WebP + srcset)
- JavaScript mínimo (code splitting)
- Interfaces ligeras
- Contenido prioritario first
- Testear en dispositivos reales de gama baja

---

# 25. Testing y monitoreo

| Tipo                    | Herramienta                    | Qué mide                         |
|------------------------|--------------------------------|-----------------------------------|
| Lab testing            | Lighthouse, WebPageTest        | Métricas en condiciones controladas|
| Field data (RUM)       | Chrome UX Report, New Relic    | Métricas de usuarios reales       |
| Continuous monitoring  | SpeedCurve, Calibre            | Tracking de performance en el tiempo|

### Flujo de monitoreo

```
Medir baseline → Detectar problemas → Optimizar → Medir impacto → Repetir
```

---

# 26. Impacto en negocio

| Impacto                    | Descripción                                      |
|---------------------------|--------------------------------------------------|
| Conversión                | Menor tiempo de carga → mayor conversión          |
| Retención                 | Experiencias rápidas → usuarios vuelven           |
| SEO                       | Core Web Vitals son factor de ranking en Google   |
| Ventaja competitiva       | Sitio más rápido → mejor percepción de calidad    |
| Costos                    | Menos recursos → menor costo de infraestructura  |

### Relación directa

```
┌────────────────────────────────────────────────┐
│                                                 │
│  Mejor performance → Mejor UX → Más conversión │
│                                                 │
│  Peor performance → Más abandono → Menos dinero │
│                                                 │
└────────────────────────────────────────────────┘
```

---

> *"Performance is not a feature. Performance is the feature."*
> — Steve Souders
