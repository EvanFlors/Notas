# Sitemaps en UX — Guía Completa: Arquitectura de Información, Estructura y Navegación

> **Idea central:** Un sitemap no es un diagrama bonito de cajas y flechas — es la
> columna vertebral de tu producto. Define qué existe, dónde vive, y cómo se conecta.
> Si tu sitemap está mal, todo lo que construyas encima (wireframes, prototipos, código)
> estará mal. Un usuario no puede encontrar lo que no está bien organizado, y no puede
> navegar lo que no tiene estructura. Antes de dibujar una sola pantalla, dibuja el mapa.
> Siempre.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [¿Qué es un Sitemap?](#1-qué-es-un-sitemap)
2. [Sitemap dentro del Proceso de Diseño](#2-sitemap-dentro-del-proceso-de-diseño)
3. [Sitemap vs User Flow vs Wireframe](#3-sitemap-vs-user-flow-vs-wireframe)

**Parte II — Arquitectura de Información**
4. [Fundamentos de Arquitectura de Información](#4-fundamentos-de-arquitectura-de-información)
5. [Modelos Mentales del Usuario](#5-modelos-mentales-del-usuario)
6. [Card Sorting](#6-card-sorting)
7. [Tree Testing](#7-tree-testing)

**Parte III — Tipos de Sitemaps**
8. [Sitemap Jerárquico](#8-sitemap-jerárquico)
9. [Sitemap Secuencial](#9-sitemap-secuencial)
10. [Sitemap Matricial](#10-sitemap-matricial)
11. [Cuándo usar cada tipo](#11-cuándo-usar-cada-tipo)

**Parte IV — Diseño de un Sitemap Efectivo**
12. [Niveles de Estructura](#12-niveles-de-estructura)
13. [Profundidad vs Amplitud](#13-profundidad-vs-amplitud)
14. [Naming y Etiquetado](#14-naming-y-etiquetado)
15. [Escalabilidad](#15-escalabilidad)

**Parte V — Metodología Paso a Paso**
16. [Fase 1: Investigación](#16-fase-1-investigación)
17. [Fase 2: Inventario de Contenido](#17-fase-2-inventario-de-contenido)
18. [Fase 3: Agrupación y Priorización](#18-fase-3-agrupación-y-priorización)
19. [Fase 4: Construcción del Sitemap](#19-fase-4-construcción-del-sitemap)
20. [Fase 5: Validación](#20-fase-5-validación)

**Parte VI — Herramientas y Convenciones Visuales**
21. [Herramientas Digitales](#21-herramientas-digitales)
22. [Convenciones Visuales y Diagramación](#22-convenciones-visuales-y-diagramación)
23. [Versionado y Colaboración](#23-versionado-y-colaboración)

**Parte VII — Relación con Otros Artefactos UX**
24. [Sitemap → User Flow → Wireframe](#24-sitemap--user-flow--wireframe)
25. [Sitemap y Navigation Design](#25-sitemap-y-navigation-design)

**Parte VIII — Evaluación y Mejora**
26. [Heurísticas de Buena Arquitectura](#26-heurísticas-de-buena-arquitectura)
27. [Pruebas con Usuarios](#27-pruebas-con-usuarios)
28. [Métricas de Findability](#28-métricas-de-findability)

**Parte IX — Casos Prácticos**
29. [Sitemap para E-commerce](#29-sitemap-para-e-commerce)
30. [Sitemap para SaaS](#30-sitemap-para-saas)
31. [Sitemap para Blog / Contenido](#31-sitemap-para-blog--contenido)
32. [Comparación entre Estructuras](#32-comparación-entre-estructuras)

**Parte X — Anti-Patrones, Errores Comunes y Buenas Prácticas**
33. [Errores Comunes](#33-errores-comunes)
34. [Anti-Patrones de Arquitectura](#34-anti-patrones-de-arquitectura)
35. [Checklist Final](#35-checklist-final)

---

# PARTE I — FUNDAMENTOS

---

# 1. ¿Qué es un Sitemap?

## 1.1 Definición

```
Un sitemap (mapa del sitio) es una representación visual de la estructura
completa de un producto digital — todas sus páginas, secciones y la
relación jerárquica entre ellas.

  → No es un flujo          → Es una estructura
  → No es navegación        → Es la base de la navegación
  → No es un wireframe      → Es lo que organiza los wireframes
  → No describe pasos       → Describe qué existe y dónde vive
```

Un sitemap responde la pregunta más básica: **"¿Qué hay en este producto y cómo
está organizado?"** — antes de preocuparte por cómo se ve (wireframes) o cómo se
recorre (user flows).

## 1.2 Propósito

Un sitemap cumple múltiples funciones según quién lo lea:

| Audiencia | ¿Qué obtiene del sitemap? |
|-----------|---------------------------|
| **Diseñador UX** | Estructura para organizar wireframes y flujos |
| **Product Manager** | Vista global del alcance del producto |
| **Desarrollador** | Mapa de rutas, componentes y páginas a construir |
| **Content Strategist** | Inventario de contenido necesario por sección |
| **Stakeholders** | Entendimiento visual de "qué incluye el producto" |
| **SEO Specialist** | Jerarquía de URLs y relaciones entre páginas |

## 1.3 Qué NO es un Sitemap

```
 ❌ NO ES:                               ✅ SÍ ES:

 Un user flow                             Un mapa estático de estructura
 (flujos describen pasos del              (sitemaps describen QUÉ EXISTE
  usuario → tienen inicio y fin)           y DÓNDE está organizado)

 Un wireframe                             Una vista de pájaro
 (wireframes diseñan UNA pantalla;        (el sitemap muestra TODAS
  el sitemap muestra TODAS)                las pantallas y su relación)

 Un menú de navegación                    El plano del edificio
 (la navegación es la interfaz;           (el sitemap es el plano
  el sitemap es lo que hay detrás)         arquitectónico completo)
```

---

# 2. Sitemap dentro del Proceso de Diseño

## 2.1 Ubicación en el Double Diamond

```
         DISCOVER          DEFINE           DEVELOP          DELIVER
        ╱          ╲      ╱       ╲        ╱        ╲      ╱        ╲
       ╱            ╲    ╱         ╲      ╱          ╲    ╱          ╲
      ╱   Research   ╲  ╱  Síntesis ╲    ╱  Ideación  ╲  ╱  Entrega   ╲
     ╱    Empatía     ╲╱   Problem   ╲  ╱   Diseño     ╲╱   Testing    ╲
     ╲   Entrevistas  ╱╲  Statement  ╱  ╲   Prototipos ╱╲   Iteración  ╱
      ╲              ╱  ╲          ╱    ╲            ╱  ╲            ╱
       ╲            ╱    ╲        ╱      ╲          ╱    ╲          ╱
        ╲          ╱      ╲      ╱        ╲        ╱      ╲        ╱
                                    ▲
                                    │
                            Sitemap se construye aquí
                            (al inicio de Develop,
                             tras definir el problema)
```

## 2.2 Secuencia de Artefactos UX

```
Research  →  Personas  →  User Stories  →  SITEMAP  →  User Flows  →  Wireframes  →  Prototype
                                              ▲
                                              │
                                    "¿Qué páginas existen?"
                                    (antes de diseñar cómo
                                     se ven o se recorren)
```

> **Regla fundamental:** El sitemap se crea DESPUÉS de entender al usuario y
> ANTES de diseñar pantallas. Si creas wireframes sin sitemap, estás construyendo
> habitaciones sin plano del edificio.

## 2.3 Impacto en la Experiencia del Usuario

Un sitemap bien diseñado impacta directamente en:

| Aspecto UX | Efecto de un buen sitemap | Efecto de un mal sitemap |
|------------|---------------------------|--------------------------|
| **Findability** | El usuario encuentra lo que busca en < 3 clicks | El usuario se pierde y abandona |
| **Navegación** | Menús limpios, predecibles, lógicos | Menús sobrecargados o inconsistentes |
| **Escalabilidad** | Nuevas features encajan sin reestructurar | Cada nueva feature rompe la navegación |
| **Onboarding** | Nuevos usuarios entienden la estructura rápido | Usuarios confundidos desde el primer uso |
| **SEO** | URLs limpias con jerarquía lógica | URLs planas o inconsistentes sin contexto |

---

# 3. Sitemap vs User Flow vs Wireframe

## 3.1 Comparación en una línea

```
SITEMAP     = QUÉ existe y DÓNDE vive        (estructura)
USER FLOW   = CÓMO se mueve el usuario        (comportamiento)
WIREFRAME   = QUÉ ve el usuario en UNA página (diseño)
```

## 3.2 Tabla comparativa detallada

| Aspecto | Sitemap | User Flow | Wireframe |
|---------|---------|-----------|-----------|
| **Pregunta** | "¿Qué páginas hay?" | "¿Cómo llega el usuario a X?" | "¿Qué hay en esta página?" |
| **Perspectiva** | Sistema (vista de pájaro) | Usuario (pasos a seguir) | Pantalla individual |
| **Muestra** | Páginas y su jerarquía | Decisiones y caminos | Layout y elementos |
| **Dirección** | No tiene (es estático) | Unidireccional → | N/A (una sola pantalla) |
| **Granularidad** | Macro (todo el producto) | Medio (un objetivo) | Micro (una pantalla) |
| **Momento** | Antes del diseño | Durante el diseño | Durante el diseño |
| **Se parece a** | Plano del edificio | Instrucciones para ir del lobby al piso 3 | Diseño de una habitación |

## 3.3 Cómo se complementan

```
SITEMAP (estructura global)
    │
    ├── User Flow: "Registrarse" (flujo específico)
    │       ├── Wireframe: Welcome Screen
    │       ├── Wireframe: Sign Up Form
    │       └── Wireframe: Confirmation
    │
    ├── User Flow: "Comprar producto" (flujo específico)
    │       ├── Wireframe: Product Page
    │       ├── Wireframe: Cart
    │       ├── Wireframe: Checkout
    │       └── Wireframe: Order Confirmation
    │
    └── User Flow: "Editar perfil" (flujo específico)
            ├── Wireframe: Profile View
            └── Wireframe: Profile Edit
```

> **El sitemap es el mapa. Los user flows son las rutas. Los wireframes son las
> paradas.** Los tres son necesarios; ninguno reemplaza al otro.

---

# PARTE II — ARQUITECTURA DE INFORMACIÓN

---

# 4. Fundamentos de Arquitectura de Información

## 4.1 ¿Qué es la Arquitectura de Información (IA)?

```
Arquitectura de Información (IA) es la práctica de organizar, estructurar
y etiquetar contenido de manera que los usuarios puedan encontrar lo que
necesitan y completar sus tareas.

  IA es al contenido digital lo que la arquitectura es al espacio físico:
  → Define qué va dónde
  → Crea caminos lógicos
  → Agrupa lo relacionado
  → Separa lo diferente
```

**La IA tiene cuatro componentes fundamentales:**

| Componente | Pregunta que responde | Ejemplo |
|------------|----------------------|---------|
| **Organización** | ¿Cómo agrupamos el contenido? | Por categoría, por audiencia, por tarea |
| **Etiquetado** | ¿Cómo nombramos las cosas? | "Mi cuenta" vs "Perfil" vs "Configuración" |
| **Navegación** | ¿Cómo se mueve el usuario entre secciones? | Menú principal, breadcrumbs, sidebar |
| **Búsqueda** | ¿Cómo encuentra algo específico? | Barra de búsqueda, filtros, sugerencias |

## 4.2 Jerarquía

La jerarquía define la relación padre-hijo entre contenidos:

```
JERARQUÍA = Organización vertical del contenido

Nivel 0 (raíz):     Home
                      │
Nivel 1 (categorías): ├── Productos
                      ├── Sobre Nosotros
                      └── Contacto
                            │
Nivel 2 (subcategorías):    ├── Email
                            ├── Teléfono
                            └── Formulario
```

**Regla:** Cada nivel debe responder a la misma pregunta con mayor especificidad.
- Nivel 0: "¿Qué es este sitio?"
- Nivel 1: "¿Qué grandes áreas tiene?"
- Nivel 2: "¿Qué hay dentro de cada área?"
- Nivel 3: "¿Qué detalles específicos hay?"

## 4.3 Taxonomía y Categorización

**Taxonomía** es el sistema de clasificación que usas para agrupar contenido:

| Esquema | Cómo organiza | Ejemplo | Mejor para |
|---------|---------------|---------|------------|
| **Exacto: Alfabético** | A → Z | Directorio, glosario | Listas largas donde el usuario sabe el nombre |
| **Exacto: Cronológico** | Fecha | Blog, noticias | Contenido temporal |
| **Exacto: Geográfico** | Ubicación | Tiendas, eventos | Contenido local |
| **Ambiguo: Por tema** | Categorías temáticas | E-commerce (Ropa, Tech, Hogar) | La mayoría de sitios |
| **Ambiguo: Por tarea** | Lo que el usuario quiere hacer | Banca (Transferir, Pagar, Invertir) | Apps orientadas a acciones |
| **Ambiguo: Por audiencia** | Quién es el usuario | Educación (Estudiantes, Profesores, Padres) | Productos multi-audiencia |

> **Los esquemas exactos son objetivos** (todos entienden el orden alfabético). **Los
> esquemas ambiguos son subjetivos** (lo que es "lógico" para ti puede no serlo para
> tu usuario). Por eso necesitas Card Sorting.

## 4.4 Principios LATCH de Richard Saul Wurman

Toda información del mundo puede organizarse de solo cinco maneras:

```
L — Location     (Ubicación)       → Mapas, regiones, zonas
A — Alphabet     (Alfabético)      → Directorios, índices, glosarios
T — Time         (Tiempo)          → Líneas de tiempo, historiales, feeds
C — Category     (Categoría)       → Temas, tipos, grupos temáticos
H — Hierarchy    (Jerarquía)       → Rankings, importancia, prioridad

Mnemónico: LATCH — "Pestillo" en inglés
                    (el pestillo que abre la puerta del contenido)
```

> Cuando no sabes cómo organizar algo, pasa por cada letra de LATCH y pregunta:
> "¿Tiene sentido organizarlo por ubicación? ¿Por orden alfabético? ¿Por tiempo?
> ¿Por categoría? ¿Por importancia?"

---

# 5. Modelos Mentales del Usuario

## 5.1 ¿Qué es un Modelo Mental?

```
Modelo Mental = La representación interna que un usuario tiene de
                cómo funciona algo — basada en su experiencia previa.

Tu modelo mental como diseñador:
  "Configuración está en un menú dentro del perfil"

El modelo mental del usuario:
  "Configuración debería estar en el menú principal,
   porque así funciona en todas las apps que uso"

Si tu estructura no coincide con el modelo mental del usuario
→ el usuario se pierde
→ no porque sea tonto
→ sino porque TÚ organizaste mal
```

## 5.2 Implicaciones para el Sitemap

| Situación | Consecuencia | Solución |
|-----------|-------------|----------|
| Tu estructura coincide con el modelo mental del usuario | El usuario navega intuitivamente | ✅ Éxito |
| Tu estructura tiene lógica interna pero difiere del usuario | El usuario se confunde a pesar de que "tiene sentido" | Hacer Card Sorting para descubrir el modelo real |
| Tu estructura refleja la organización interna de la empresa | El usuario no entiende nada | Rediseñar completamente desde la perspectiva del usuario |

> **Error #1 en arquitectura de información:** Organizar el contenido según la
> estructura interna de la empresa (departamentos, equipos, procesos) en vez de
> según las necesidades y expectativas del usuario.

## 5.3 Cómo descubrir modelos mentales

- **Card Sorting** (sección 6) — Cómo agrupan los usuarios el contenido
- **Tree Testing** (sección 7) — Si encuentran lo que buscan en tu estructura
- **Entrevistas** — "¿Dónde esperarías encontrar X?"
- **Análisis competitivo** — ¿Cómo organizan los competidores el mismo contenido?
- **Analytics** — ¿Qué buscan los usuarios? ¿Qué caminos toman? ¿Dónde abandonan?

---

# 6. Card Sorting

## 6.1 Definición

```
Card Sorting es una técnica de investigación UX donde los usuarios
organizan items de contenido en grupos que tienen sentido PARA ELLOS.

El diseñador prepara "tarjetas" (físicas o digitales) con nombres
de páginas, funciones o contenidos, y los usuarios las agrupan
y etiquetan.

Resultado → Descubres cómo el usuario organiza mentalmente tu contenido
            (en vez de asumir que tu organización es la correcta)
```

## 6.2 Tipos de Card Sorting

### Card Sorting Abierto

```
SE ENTREGA:                      EL USUARIO PRODUCE:

┌─────────┐ ┌─────────┐         Grupo: "Mi cuenta"
│  Perfil  │ │ Facturas│         ├── Perfil
└─────────┘ └─────────┘         ├── Contraseña
┌─────────┐ ┌─────────┐         └── Facturas
│Contraseña│ │ Ayuda   │
└─────────┘ └─────────┘         Grupo: "Soporte"
┌─────────┐ ┌─────────┐         ├── Ayuda
│  Blog   │ │ Precios │         └── Contacto
└─────────┘ └─────────┘
┌─────────┐                      Grupo: "Info"
│ Contacto│                      ├── Blog
└─────────┘                      └── Precios

El usuario crea los grupos Y los nombra.
Tú no defines nada — solo observas.
```

- **Cuándo:** Producto nuevo, no tienes estructura previa
- **Lo que descubres:** Categorías naturales desde la perspectiva del usuario
- **Participantes:** 15–20 mínimo para encontrar patrones

### Card Sorting Cerrado

```
SE ENTREGA:                      EL USUARIO PRODUCE:

Categorías predefinidas:         "Mi cuenta"
├── Mi cuenta                    ├── Perfil ✓
├── Soporte                      ├── Contraseña ✓
├── Información                  └── Facturas ✓

Tarjetas:                        "Soporte"
┌─────────┐ ┌─────────┐         ├── Ayuda ✓
│  Perfil  │ │ Facturas│         ├── Contacto ✓
└─────────┘ └─────────┘         └── Blog ← ¿Aquí?
┌─────────┐ ┌─────────┐
│Contraseña│ │ Ayuda   │         "Información"
└─────────┘ └─────────┘         └── Precios ✓
┌─────────┐ ┌─────────┐
│  Blog   │ │ Precios │         El usuario coloca tarjetas en
└─────────┘ └─────────┘         categorías que TÚ definiste.
┌─────────┐
│ Contacto│
└─────────┘
```

- **Cuándo:** Ya tienes una estructura y quieres validarla
- **Lo que descubres:** Si tus categorías coinciden con las expectativas del usuario
- **Participantes:** 15–30 para resultados estadísticos

### Card Sorting Híbrido

- Las categorías están predefinidas, pero el usuario puede **crear nuevas** si siente que algo no encaja
- **Cuándo:** Tienes una estructura tentativa pero abierta a cambios
- Combina lo mejor de ambos: estructura + flexibilidad

## 6.3 Análisis de Resultados

| Métrica | Qué indica |
|---------|------------|
| **Coincidencia de agrupación** (> 70%) | Consenso fuerte → tu estructura es sólida |
| **Coincidencia de agrupación** (40–70%) | Consenso parcial → refinar categorías |
| **Coincidencia de agrupación** (< 40%) | Sin consenso → replantear la estructura |
| **Items problemáticos** | Tarjetas que nadie sabe dónde poner → revisar naming o crear nueva categoría |
| **Categorías emergentes** (abierto) | Grupos que no anticipaste → posible nueva sección |

## 6.4 Herramientas

| Herramienta | Tipo | Notas |
|-------------|------|-------|
| **Optimal Workshop** | Digital, remoto | El estándar de la industria para card sorting |
| **UserZoom** | Digital, remoto | Suite completa de research UX |
| **Miro / FigJam** | Digital, colaborativo | Para sesiones en vivo con el equipo |
| **Post-its físicos** | Presencial | Ideal para sesiones con usuarios en persona |

---

# 7. Tree Testing

## 7.1 Definición

```
Tree Testing es una técnica de evaluación donde los usuarios intentan
encontrar items específicos navegando SOLO la estructura jerárquica
del sitemap — sin diseño visual, sin wireframes, sin ayuda.

Es la prueba de fuego de tu arquitectura de información:
si el usuario no puede encontrar algo en el árbol puro,
no lo va a encontrar en el producto final.
```

## 7.2 Cómo funciona

```
SE ENTREGA:                              TAREA:

Home                                     "Encuentra dónde cambiarías
├── Productos                              tu contraseña"
│   ├── Categoría A
│   └── Categoría B                      RESULTADO:
├── Mi cuenta              ← ✓ Correcto
│   ├── Perfil                           Home → Mi cuenta → Seguridad
│   ├── Seguridad          ← ✓ Correcto  (Directness: 100% → éxito)
│   │   └── Contraseña     ← ✓ META
│   └── Facturas                         Home → Soporte → Ayuda
├── Soporte                              → Backtrack → Mi cuenta → Perfil
│   ├── Ayuda                            (Directness: 0% → fracaso)
│   └── Contacto
└── Blog
```

## 7.3 Métricas clave

| Métrica | Definición | Benchmark saludable |
|---------|-----------|-------------------|
| **Success rate** | % de usuarios que encontraron el item correcto | > 80% |
| **Directness** | % que llegaron sin backtracking (camino directo) | > 60% |
| **Time to find** | Segundos promedio para encontrar el item | Varía por profundidad |
| **First click correctness** | % que hicieron click correcto en el primer nivel | > 70% |

> **Si el first click es correcto, la probabilidad de éxito total es ~87%.**
> Si el first click es incorrecto, la probabilidad cae a ~46%.
> (Fuente: UIE, "First Click Testing")

## 7.4 Card Sorting + Tree Testing = Ciclo completo

```
                Card Sorting                    Tree Testing
                (Generativo)                    (Evaluativo)
                     │                               │
                     ▼                               ▼
         "¿Cómo organizan los              "¿Pueden encontrar
          usuarios el contenido?"           cosas en mi estructura?"
                     │                               │
                     └──────────┐    ┌───────────────┘
                                ▼    ▼
                           SITEMAP v1
                                │
                            Iterar ↺

   Card Sorting → genera la estructura
   Tree Testing → valida la estructura
   Repetir hasta que Success Rate > 80%
```

---

# PARTE III — TIPOS DE SITEMAPS

---

# 8. Sitemap Jerárquico

## 8.1 Definición

```
El sitemap jerárquico (tree structure) organiza el contenido en una
estructura de árbol padre-hijo. Es el tipo más común y el que
la mayoría de productos digitales usa.

Cada página pertenece a exactamente UN padre.
La navegación sigue la jerarquía de arriba hacia abajo.
```

## 8.2 Estructura

```
                        ┌──────────┐
                        │   HOME   │
                        └────┬─────┘
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ Productos │  │  Blog    │  │ Contacto │
        └────┬─────┘  └────┬─────┘  └──────────┘
        ┌────┼────┐   ┌────┼────┐
        ▼    ▼    ▼   ▼    ▼    ▼
       Cat1 Cat2 Cat3 Post Post Post
        │
        ├── Producto A
        ├── Producto B
        └── Producto C
```

## 8.3 Cuándo usarlo

| ✅ Ideal para | ❌ No ideal para |
|--------------|-----------------|
| Sitios web corporativos | Apps con navegación no lineal |
| E-commerce con categorías claras | Dashboards con acceso cruzado |
| Documentación técnica | Redes sociales |
| Blogs y sitios de contenido | Herramientas con múltiples puntos de entrada |

---

# 9. Sitemap Secuencial

## 9.1 Definición

```
El sitemap secuencial organiza el contenido como un flujo lineal:
una página lleva a la siguiente, que lleva a la siguiente.

No hay jerarquía padre-hijo — hay un orden obligatorio.
El usuario DEBE pasar por cada paso para llegar al final.
```

## 9.2 Estructura

```
┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐
│  Welcome   │───▶│  Step 1    │───▶│  Step 2    │───▶│  Step 3    │───▶│  Complete  │
│  Screen    │    │  Info      │    │  Payment   │    │  Confirm   │    │  Screen    │
└───────────┘    └───────────┘    └───────────┘    └───────────┘    └───────────┘
```

## 9.3 Cuándo usarlo

| ✅ Ideal para | ❌ No ideal para |
|--------------|-----------------|
| Onboarding de nuevos usuarios | Sitios con contenido explorable |
| Proceso de checkout | Productos donde el usuario necesita libertad |
| Formularios multi-paso | Dashboards |
| Tutoriales / cursos | E-commerce general (solo para checkout) |

---

# 10. Sitemap Matricial

## 10.1 Definición

```
El sitemap matricial (o de red) permite que el usuario acceda al
contenido desde múltiples puntos de entrada y navegue entre secciones
de manera no lineal.

No hay una sola jerarquía dominante — el contenido se conecta
en múltiples direcciones según el contexto del usuario.
```

## 10.2 Estructura

```
        ┌──────────┐
        │   HOME   │
        └────┬─────┘
    ┌────────┼────────┐
    ▼        ▼        ▼
┌───────┐ ┌───────┐ ┌───────┐
│ Sec A │◄─────────▶│ Sec B │◄─────────▶│ Sec C │
└───┬───┘ └───┬───┘ └───┬───┘
    │         │         │
    ▼         ▼         ▼
┌───────┐ ┌───────┐ ┌───────┐
│ Sub 1 │◄─────────▶│ Sub 2 │◄─────────▶│ Sub 3 │
└───────┘ └───────┘ └───────┘

Las flechas bidireccionales indican que el usuario puede
navegar entre secciones sin volver a Home.
```

## 10.3 Cuándo usarlo

| ✅ Ideal para | ❌ No ideal para |
|--------------|-----------------|
| Redes sociales | Procesos lineales (checkout) |
| Dashboards / SaaS | Sitios simples con pocas páginas |
| Wikis / bases de conocimiento | Sitios institucionales básicos |
| Productos con búsqueda como navegación principal | Landing pages |

---

# 11. Cuándo usar cada tipo

```
¿QUÉ TIPO DE SITEMAP NECESITO?

¿El contenido tiene categorías claras padre-hijo?
  → Jerárquico (la mayoría de sitios web)

¿El usuario debe seguir un proceso paso a paso?
  → Secuencial (onboarding, checkout, formularios)

¿El usuario necesita acceder a contenido desde múltiples caminos?
  → Matricial (SaaS, redes sociales, wikis)

¿Tu producto es complejo con múltiples tipos de contenido?
  → Híbrido: Jerárquico para la estructura global +
    Secuencial para procesos internos +
    Matricial para secciones relacionadas
```

| Tipo | Complejidad | Libertad del usuario | Ejemplo típico |
|------|-------------|---------------------|----------------|
| **Jerárquico** | Baja–Media | Media | Blog, E-commerce, Corporativo |
| **Secuencial** | Baja | Baja (guiado) | Onboarding, Checkout, Curso |
| **Matricial** | Alta | Alta | SaaS, Wikipedia, Red social |
| **Híbrido** | Alta | Variable por sección | Producto complejo real |

---

# PARTE IV — DISEÑO DE UN SITEMAP EFECTIVO

---

# 12. Niveles de Estructura

## 12.1 Los cuatro niveles estándar

```
Nivel 0 — HOME
│  La puerta de entrada. Punto de referencia universal.
│  Todos los caminos empiezan aquí (o deberían poder volver aquí).
│
├── Nivel 1 — CATEGORÍAS PRINCIPALES
│   │  Las grandes secciones del producto.
│   │  Típicamente → lo que aparece en la navegación principal (top nav).
│   │  Regla: 5–7 máximo (Miller's Law: 7 ± 2).
│   │
│   ├── Nivel 2 — SUBCATEGORÍAS
│   │   │  Divisiones dentro de cada categoría.
│   │   │  Típicamente → lo que aparece en dropdowns o sidebars.
│   │   │  Regla: Cada categoría debería tener 3–7 subcategorías.
│   │   │
│   │   └── Nivel 3 — PÁGINAS DE DETALLE
│   │       Contenido final: producto, artículo, perfil, formulario.
│   │       El usuario llegó donde quería llegar.
│   │       Regla: A este nivel no debería haber más subdivisiones.
│   │
│   └── ...
│
└── PÁGINAS UTILITARIAS (fuera de la jerarquía principal)
    ├── Login / Register
    ├── 404 Error
    ├── Términos y condiciones
    └── Política de privacidad
```

## 12.2 Ejemplo aplicado — E-commerce

```
Nivel 0:  Home

Nivel 1:  Hombre    |    Mujer    |    Niños    |    Ofertas    |    Blog

Nivel 2:  Camisetas      Pantalones      Zapatos      Accesorios
          (bajo Hombre)

Nivel 3:  Camiseta Nike Air Max (producto individual)
          Camiseta Adidas Originals
          ...

Utilidades: Login | Carrito | Checkout | FAQ | Contacto
```

---

# 13. Profundidad vs Amplitud

## 13.1 El dilema fundamental

```
PROFUNDA (deep):                    AMPLIA (broad):

Home                                Home
└── A                               ├── A
    └── B                           ├── B
        └── C                       ├── C
            └── D                   ├── D
                └── E ← Target      ├── E ← Target
                                    ├── F
5 clicks para llegar                ├── G
Menú simple pero oculta contenido   └── H

                                    1 click pero menú sobrecargado
```

## 13.2 Regla del equilibrio

| Dimensión | Recomendación | Por qué |
|-----------|--------------|---------|
| **Amplitud** (items por nivel) | 5–9 items por nivel | Miller's Law: 7 ± 2 items en memoria de trabajo |
| **Profundidad** (niveles totales) | 3–4 niveles máximo | Cada nivel añade fricción y carga cognitiva |
| **Click depth** | Cualquier página en ≤ 3 clicks desde Home | Regla de los 3 clicks (más una guía que una ley) |

## 13.3 Investigación sobre profundidad vs amplitud

```
Estudio de Larson & Czerwinski (1998):

ESTRUCTURA PROFUNDA (2×2×2×2×2 = 32 items en 5 niveles)
  → Más errores de navegación
  → Mayor tiempo para encontrar items
  → Mayor frustración

ESTRUCTURA AMPLIA (8×4 = 32 items en 2 niveles)
  → Menos errores
  → Menor tiempo
  → Menor frustración

ESTRUCTURA EQUILIBRADA (4×4×2 = 32 items en 3 niveles)
  → Mejor rendimiento general ← GANADORA
  → Balance entre amplitud y profundidad
```

> **Conclusión:** La estructura más eficiente no es la más plana ni la más
> profunda — es la más equilibrada. Apunta a 3 niveles con 5–7 items por nivel.

## 13.4 Señales de que tu estructura está desbalanceada

| Señal | Problema | Solución |
|-------|----------|----------|
| Más de 10 items en un nivel | Demasiado amplio | Agrupar en subcategorías |
| Más de 4 niveles | Demasiado profundo | Aplanar: subir contenido un nivel |
| Una categoría tiene 15 hijos y otra tiene 2 | Desbalanceado | Redistribuir o fusionar |
| El usuario necesita > 4 clicks para tareas comunes | Profundidad excesiva | Crear atajos directos |

---

# 14. Naming y Etiquetado

## 14.1 Reglas de naming

```
El nombre de cada página o sección debe:

✅ Describir el contenido (no la interfaz)
   "Historial de pedidos"  vs  ❌ "Lista"

✅ Usar el lenguaje del usuario (no del equipo interno)
   "Mis envíos"  vs  ❌ "Fulfillment Center"

✅ Ser consistente en todo el sitemap
   Si una sección se llama "Tienda", no la llames
   "Productos" en otro lado y "Shop" en otro

✅ Ser mutuamente excluyente (cada item es claramente diferente)
   "Camisetas" y "Pantalones" son claros
   ❌ "Ropa casual" y "Camisetas" se solapan

✅ Ser corto pero descriptivo (2–4 palabras máximo)
   "Cambiar contraseña"  vs  ❌ "Sección para modificar
   la contraseña de tu cuenta de usuario"
```

## 14.2 Errores comunes de naming

| Error | Ejemplo | Problema | Solución |
|-------|---------|----------|----------|
| **Jerga interna** | "CRM Dashboard" | El usuario no sabe qué es CRM | "Gestión de clientes" |
| **Ambigüedad** | "Recursos" | ¿Documentos? ¿Soporte? ¿Blog? | Ser específico: "Centro de ayuda" |
| **Solapamiento** | "Noticias" + "Blog" + "Artículos" | El usuario no sabe la diferencia | Fusionar en una sola sección |
| **Inconsistencia** | "Mi perfil" vs "Tu cuenta" vs "Settings" | Mezcla de persona y idioma | Unificar: "Mi cuenta" |
| **Demasiado genérico** | "Más" o "Otros" | Cajón de sastre → mala IA | Redistribuir en categorías reales |

## 14.3 Test de naming: la prueba del "cerrar los ojos"

```
Para cada nombre en tu sitemap, pregunta:

"Si un usuario lee SOLO este nombre
 (sin ver el contenido de la página),
 ¿puede predecir qué hay dentro?"

Si la respuesta es NO → renombra.

Ejemplos:
  "Descubre"    → NO (descubrir qué?)  → "Explorar productos"
  "Dashboard"   → DEPENDE del público  → "Panel de control"
  "Checkout"    → SÍ para e-commerce   → ✅ Mantener
  "Perfil"      → SÍ                   → ✅ Mantener
```

---

# 15. Escalabilidad

## 15.1 Diseñar para el futuro

```
Tu sitemap hoy tiene 20 páginas.
En 6 meses tendrá 50.
En 2 años, 200.

Si no diseñas la estructura pensando en crecimiento,
cada nueva feature romperá la navegación y tendrás que
reestructurar todo — con el costo que eso implica.
```

## 15.2 Principios de escalabilidad

| Principio | Descripción | Ejemplo |
|-----------|-------------|---------|
| **Categorías extensibles** | Cada categoría puede recibir nuevos hijos sin reestructurar | "Productos" puede crecer de 3 a 30 subcategorías |
| **Nombres genéricos pero claros** | Evita nombres demasiado específicos en niveles altos | "Contenido" es mejor que "Blog" si planeas añadir podcasts, videos, etc. |
| **Estructura modular** | Cada sección funciona independientemente | Puedes añadir "Marketplace" sin tocar "Blog" |
| **Convenciones consistentes** | Nuevas secciones siguen las mismas reglas | Si las categorías tienen subcategorías y detalle, las nuevas también |
| **Espacio para lo inesperado** | Deja "slot" para features futuras | No llenes el nav principal al máximo desde el día 1 |

## 15.3 Anti-patrón: el sitemap rígido

```
RÍGIDO (cada sección es específica):

Home
├── Blog             ← ¿Y si añadimos podcast?
├── Ebooks           ← ¿Y si añadimos whitepapers?
├── Webinars         ← ¿Y si añadimos cursos?
└── Newsletter       ← ¿Y si añadimos social media?

ESCALABLE (categorías flexibles):

Home
└── Recursos         ← Contenedor extensible
    ├── Blog
    ├── Ebooks
    ├── Webinars
    └── Newsletter
    (futuro: Podcast, Cursos, Whitepapers → encajan sin reestructurar)
```

---

# PARTE V — METODOLOGÍA PASO A PASO

---

# 16. Fase 1: Investigación

## 16.1 Las tres dimensiones de investigación

Antes de estructurar nada, necesitas entender tres cosas:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  USUARIOS   │     │  NEGOCIO    │     │  CONTENIDO  │
│             │     │             │     │             │
│ ¿Qué buscan?│     │ ¿Qué ofrece?│     │ ¿Qué existe?│
│ ¿Cómo lo    │     │ ¿Qué prioriza│    │ ¿Cuánto hay?│
│  organizan? │     │  el negocio? │     │ ¿Qué falta? │
└─────┬───────┘     └─────┬───────┘     └─────┬───────┘
      │                   │                   │
      └───────────────────┼───────────────────┘
                          ▼
                    SITEMAP que sirve
                    al usuario Y al negocio
                    con el contenido disponible
```

## 16.2 Técnicas de investigación

| Técnica | Qué descubres | Esfuerzo |
|---------|---------------|----------|
| **Entrevistas con usuarios** | Modelos mentales, vocabulario, expectativas | Alto |
| **Card Sorting abierto** | Categorías naturales del usuario | Medio |
| **Análisis competitivo** | Convenciones de la industria | Bajo |
| **Analytics existentes** | Páginas populares, búsquedas, abandonos | Bajo (si hay data) |
| **Stakeholder interviews** | Objetivos de negocio, prioridades, restricciones | Medio |
| **Content audit** | Todo lo que existe y su estado | Alto |

## 16.3 Preguntas clave

```
SOBRE USUARIOS:
  → ¿Quiénes son y qué necesitan del producto?
  → ¿Cuáles son sus tareas más frecuentes?
  → ¿Qué vocabulario usan?
  → ¿Qué apps similares usan (modelos mentales existentes)?

SOBRE NEGOCIO:
  → ¿Cuáles son los objetivos principales del producto?
  → ¿Qué contenido debe tener mayor visibilidad?
  → ¿Qué features están planeadas para los próximos 6-12 meses?
  → ¿Hay restricciones técnicas que afecten la estructura?

SOBRE CONTENIDO:
  → ¿Cuántas páginas/secciones tendrá el producto?
  → ¿Hay contenido existente que migrar?
  → ¿Qué contenido se crea con frecuencia (blog, productos, etc.)?
  → ¿Hay contenido que puede eliminarse o fusionarse?
```

---

# 17. Fase 2: Inventario de Contenido

## 17.1 ¿Qué es?

```
Un inventario de contenido es una lista exhaustiva de TODO el contenido
que existe o existirá en el producto — cada página, cada sección,
cada tipo de contenido.

Es el equivalente a vaciar todos los cajones antes de reorganizar
un armario: primero ves todo lo que hay, luego decides dónde va.
```

## 17.2 Plantilla de inventario

| ID | Nombre de página | Tipo | Estado | Prioridad | Notas |
|----|-----------------|------|--------|-----------|-------|
| 1 | Home | Landing | Existe | Alta | Rediseñar hero |
| 2 | Productos | Listado | Existe | Alta | Añadir filtros |
| 3 | Producto X | Detalle | Existe | Alta | — |
| 4 | Blog | Listado | Existe | Media | — |
| 5 | Post individual | Detalle | Template | Media | — |
| 6 | Contacto | Formulario | Existe | Baja | — |
| 7 | FAQ | Info | No existe | Media | Crear desde cero |
| 8 | Dashboard | App | No existe | Alta | Feature nueva |

## 17.3 Tipos de inventario

| Tipo | Qué incluye | Cuándo |
|------|-------------|--------|
| **Inventario completo** | Cada URL, cada página, cada pieza de contenido | Rediseño completo de sitio existente |
| **Inventario parcial** | Solo secciones relevantes al proyecto | Rediseño parcial o nueva feature |
| **Content model** | Tipos de contenido + atributos (sin listar cada instancia) | Producto nuevo sin contenido previo |

---

# 18. Fase 3: Agrupación y Priorización

## 18.1 Proceso de agrupación

```
PASO 1: Agrupar por afinidad
  → Pon todas las páginas del inventario en "tarjetas"
  → Agrúpalas por temas o relación natural
  → (Idealmente, usa resultados de Card Sorting)

PASO 2: Crear jerarquía
  → ¿Cuáles son los grupos principales? (Nivel 1)
  → ¿Qué subgrupos hay dentro de cada uno? (Nivel 2)
  → ¿Qué páginas finales hay? (Nivel 3)

PASO 3: Priorizar
  → ¿Qué secciones son más importantes para el usuario?
  → ¿Qué secciones son más importantes para el negocio?
  → Lo que es importante para ambos → máxima visibilidad
```

## 18.2 Matriz de priorización

```
                    IMPORTANCIA PARA EL NEGOCIO
                    Baja              Alta
                 ┌──────────────┬──────────────┐
        Alta     │              │              │
  IMPORTANCIA    │  Mantener    │  PRIORIDAD   │
  PARA EL        │  accesible   │  MÁXIMA      │
  USUARIO        │              │  (Nav principal)
                 ├──────────────┼──────────────┤
        Baja     │              │              │
                 │  Footer o    │  Visible pero│
                 │  eliminar    │  secundario  │
                 │              │  (sidebar/CTA)│
                 └──────────────┴──────────────┘
```

---

# 19. Fase 4: Construcción del Sitemap

## 19.1 Proceso de construcción

```
1. Empezar con Home en el centro/arriba
2. Colocar las categorías principales (Nivel 1)
3. Añadir subcategorías (Nivel 2)
4. Añadir páginas de detalle (Nivel 3) donde sea necesario
5. Añadir páginas utilitarias (login, error, legal)
6. Trazar conexiones (jerárquicas + cross-links si aplica)
7. Verificar: ¿todas las páginas del inventario están representadas?
8. Verificar: ¿la profundidad es ≤ 4 niveles?
9. Verificar: ¿cada nivel tiene ≤ 9 items?
```

## 19.2 Plantilla base reutilizable

```
                           ┌──────────┐
                           │   HOME   │
                           └────┬─────┘
            ┌────────────────┬──┴──┬────────────────┐
            ▼                ▼     ▼                ▼
     ┌────────────┐   ┌──────────┐ ┌──────────┐  ┌──────────┐
     │ Sección 1  │   │ Sección 2│ │ Sección 3│  │ Sección N│
     └─────┬──────┘   └────┬─────┘ └────┬─────┘  └──────────┘
     ┌─────┼─────┐    ┌────┼────┐  ┌────┼────┐
     ▼     ▼     ▼    ▼    ▼    ▼  ▼    ▼    ▼
   Sub1  Sub2  Sub3  Sub1 Sub2 Sub3 Sub1 Sub2 Sub3
     │
     ├── Detail 1
     ├── Detail 2
     └── Detail 3

   ── Utilitarias ──────────────────────────────
   Login | Register | 404 | Terms | Privacy | Help
```

## 19.3 Tips de construcción

| Tip | Razón |
|-----|-------|
| Empezar en papel o Post-its antes de digitalizar | Más rápido iterar, menos apego |
| Usar una herramienta con templates (Figma, Miro) | Consistencia visual |
| Numerar o codificar cada página (1.0, 1.1, 1.1.1) | Referencia fácil en reuniones |
| Incluir páginas "invisibles" (404, confirmación, login) | Completar el mapa real |
| Marcar páginas templates vs únicas | El dev sabe qué reutilizar |

---

# 20. Fase 5: Validación

## 20.1 Métodos de validación

| Método | Cuándo | Esfuerzo |
|--------|--------|----------|
| **Tree Testing** (usuarios) | Antes de wireframear | Alto (reclutamiento) |
| **Revisión con stakeholders** | Después de construir v1 | Bajo |
| **Revisión con developers** | Después de validar con usuarios | Bajo |
| **Card Sorting cerrado** (usuarios) | Si hubo cambios mayores | Medio |
| **A/B Testing de IA** (post-lanzamiento) | Si hay dudas sobre categorías | Medio–Alto |

## 20.2 Checklist de validación

```
ESTRUCTURA:
  □ ¿Todas las páginas del inventario están representadas?
  □ ¿La profundidad es ≤ 4 niveles?
  □ ¿Cada nivel tiene ≤ 9 items (idealmente 5–7)?
  □ ¿Las categorías son mutuamente excluyentes?
  □ ¿Hay espacio para crecimiento futuro?

NAMING:
  □ ¿Los nombres son claros para el usuario (no jerga interna)?
  □ ¿Los nombres son consistentes en estilo y tono?
  □ ¿Son mutuamente excluyentes (sin solapamiento)?
  □ ¿Pasan el "test de cerrar los ojos" (predicen el contenido)?

NAVEGACIÓN:
  □ ¿Cualquier página es alcanzable en ≤ 3 clicks desde Home?
  □ ¿Las tareas más frecuentes son las más accesibles?
  □ ¿El usuario siempre puede volver a Home?
  □ ¿Hay breadcrumbs o indicadores de "dónde estoy"?

NEGOCIO:
  □ ¿Las prioridades del negocio están reflejadas en la visibilidad?
  □ ¿El sitemap soporta los KPIs (conversión, engagement, etc.)?
  □ ¿Es implementable con la tecnología disponible?
```

---

# PARTE VI — HERRAMIENTAS Y CONVENCIONES VISUALES

---

# 21. Herramientas Digitales

## 21.1 Comparativa

| Herramienta | Tipo | Mejor para | Costo |
|-------------|------|------------|-------|
| **Figma** | Diseño | Sitemaps integrados con wireframes | Free / Pro |
| **FigJam** | Whiteboard | Sesiones colaborativas en tiempo real | Free |
| **Miro** | Whiteboard | Card sorting + sitemap en un solo lugar | Free / Pro |
| **Whimsical** | Diagramas | Sitemaps rápidos y limpios (excelente UX) | Free / Pro |
| **Octopus.do** | Especializado | Herramienta 100% para sitemaps | Free / Pro |
| **FlowMapp** | Especializado | Sitemap + user flows + content planning | Pro |
| **draw.io (diagrams.net)** | Diagramas | Gratis, sin registro, exportable | Free |
| **Papel + Post-its** | Físico | Ideación inicial antes de digitalizar | ~$0 |

## 21.2 Recomendación por fase

| Fase | Herramienta recomendada | Por qué |
|------|------------------------|---------|
| **Ideación** | Post-its / Miro | Máxima flexibilidad, fácil de reorganizar |
| **Card Sorting** | Optimal Workshop / Miro | Herramientas especializadas con análisis |
| **Construcción v1** | Whimsical / Octopus.do | Rápido, limpio, enfocado en sitemaps |
| **Versión final** | Figma | Integración con wireframes y design system |
| **Presentación** | Figma / Miro | Colaboración con stakeholders |

---

# 22. Convenciones Visuales y Diagramación

## 22.1 Elementos estándar

```
NODOS (PÁGINAS):

┌──────────────┐
│  Nombre      │  → Página regular (rectángulo)
└──────────────┘

╔══════════════╗
║  Nombre      ║  → Página principal / Home (doble borde)
╚══════════════╝

┌──────────────┐
│  Nombre      │  → Página template (se repite N veces)
│  (×N)        │     Ej: "Post de blog" representa muchas páginas
└──────────────┘

┌ ─ ─ ─ ─ ─ ─ ┐
  Nombre         → Página futura / planeada (borde punteado)
└ ─ ─ ─ ─ ─ ─ ┘

┌──────────────┐
│  ⚙ Nombre    │  → Página utilidad / sistema (login, 404, etc.)
└──────────────┘


CONEXIONES:

  ──────  → Relación jerárquica padre-hijo (línea sólida)
  ─ ─ ─  → Cross-link / conexión secundaria (línea punteada)
  ──────▶ → Flujo direccional (si aplica)
```

## 22.2 Buenas prácticas de diagramación

| Práctica | Razón |
|----------|-------|
| Leer de arriba hacia abajo (o izquierda a derecha) | Convención universal |
| Alinear nodos del mismo nivel horizontalmente | Claridad de jerarquía |
| Usar color para distinguir tipos (template, utilidad, futuro) | Comprensión rápida |
| Numerar páginas (1.0, 1.1, 1.2, 2.0, 2.1...) | Referencia en reuniones y documentos |
| Incluir leyenda de símbolos | Que cualquiera pueda leer el diagrama |
| No cruzar líneas (reorganizar si es necesario) | Legibilidad |

## 22.3 Sistema de numeración

```
1.0  Home
├── 2.0  Productos
│   ├── 2.1  Categoría A
│   │   ├── 2.1.1  Producto X
│   │   └── 2.1.2  Producto Y
│   └── 2.2  Categoría B
├── 3.0  Blog
│   ├── 3.1  Post individual (template)
│   └── 3.2  Categorías del blog
├── 4.0  Sobre nosotros
│   ├── 4.1  Equipo
│   └── 4.2  Historia
├── 5.0  Contacto
└── U.1  Login / Register (utilidad)
    U.2  404 (utilidad)
    U.3  Términos legales (utilidad)
```

---

# 23. Versionado y Colaboración

## 23.1 Versionado del sitemap

```
CONVENCIÓN DE VERSIONES:

v0.1  → Borrador inicial (Post-its / papel)
v0.5  → Primera versión digital
v1.0  → Validado con Card Sorting / stakeholders
v1.1  → Ajustes tras Tree Testing
v2.0  → Cambio estructural mayor (nueva feature / rediseño)

Siempre incluir:
  → Número de versión
  → Fecha
  → Autor
  → Cambios respecto a versión anterior
```

## 23.2 Colaboración efectiva

| Rol | Cómo participa en el sitemap |
|-----|------------------------------|
| **UX Designer** | Crea, valida y mantiene el sitemap |
| **Product Manager** | Valida prioridades y alcance |
| **Content Strategist** | Valida naming, inventario, taxonomía |
| **Developer** | Valida viabilidad técnica y nomenclatura de rutas |
| **SEO Specialist** | Valida jerarquía de URLs y estructura para crawlers |
| **Stakeholders** | Aprueban alcance y estructura general |

---

# PARTE VII — RELACIÓN CON OTROS ARTEFACTOS UX

---

# 24. Sitemap → User Flow → Wireframe

## 24.1 El flujo de trabajo

```
SITEMAP (estructura)
  "¿Qué páginas existen?"
    │
    ▼
USER FLOW (comportamiento)
  "¿Cómo navega el usuario entre esas páginas?"
    │
    ▼
WIREFRAME (diseño)
  "¿Qué ve el usuario en cada página?"
    │
    ▼
PROTOTYPE (interacción)
  "¿Cómo se siente usar el producto?"
```

## 24.2 Ejemplo de transición

```
SITEMAP dice:
  Home → Productos → Categoría → Producto detalle → Carrito → Checkout

USER FLOW dice:
  1. Usuario llega a Home
  2. Hace click en "Productos" (nav principal)
  3. Filtra por "Electrónica"
  4. Selecciona "Laptop X"
  5. Hace click en "Añadir al carrito"
  6. Hace click en "Ir al carrito"
  7. Hace click en "Checkout"
  8. Completa formulario de pago
  9. Recibe confirmación

WIREFRAME dice:
  [diseño de cada una de esas 9 pantallas]
```

## 24.3 El sitemap NO reemplaza al user flow

| Sitemap muestra | User Flow muestra |
|----------------|-------------------|
| Que existe una página de "Carrito" | Los pasos para llegar al Carrito |
| Que "Checkout" es hijo de "Carrito" | Las decisiones del usuario en el Checkout |
| Que hay 5 categorías de productos | El camino para encontrar un producto específico |
| La estructura estática | El comportamiento dinámico |

---

# 25. Sitemap y Navigation Design

## 25.1 El sitemap informa la navegación

```
SITEMAP (lo que hay)  ──→  NAVIGATION (cómo se accede)

El sitemap define:               La navegación implementa:
├── Nivel 1: Categorías    ──→   Menú principal (top nav)
├── Nivel 2: Subcategorías ──→   Dropdown / Sidebar
├── Nivel 3: Detalle       ──→   Breadcrumbs / Links internos
└── Utilidades             ──→   Footer / Header secundario
```

## 25.2 Tipos de navegación derivados del sitemap

| Componente nav | Derivado de | Ejemplo |
|---------------|-------------|---------|
| **Nav principal (top)** | Nivel 1 del sitemap | Home, Productos, Blog, Contacto |
| **Dropdown / Mega menu** | Nivel 2 del sitemap | Subcategorías de Productos |
| **Sidebar** | Niveles 2–3 dentro de una sección | Filtros en página de categoría |
| **Breadcrumbs** | La ruta jerárquica completa | Home > Productos > Electrónica > Laptop X |
| **Footer nav** | Utilidades + links secundarios | Legal, FAQ, Redes sociales |
| **Buscador** | Todo el contenido del sitemap | Buscar en todo el sitio |

## 25.3 Regla de oro

> **Nunca diseñes la navegación ANTES del sitemap.** La navegación es la interfaz
> de la estructura. Si no tienes estructura, no tienes qué navegar. Diseñar el
> menú primero es como hacer el índice antes de escribir el libro.

---

# PARTE VIII — EVALUACIÓN Y MEJORA

---

# 26. Heurísticas de Buena Arquitectura

## 26.1 Las 8 heurísticas

| # | Heurística | Pregunta de evaluación |
|---|-----------|----------------------|
| 1 | **Findability** | ¿El usuario puede encontrar lo que busca sin ayuda? |
| 2 | **Comprensibilidad** | ¿Los nombres de secciones son claros e inequívocos? |
| 3 | **Exhaustividad** | ¿Todo el contenido necesario está representado? |
| 4 | **Mutua exclusividad** | ¿Cada item pertenece claramente a UNA sola categoría? |
| 5 | **Equilibrio** | ¿Las secciones tienen tamaño similar (no 2 vs 50)? |
| 6 | **Shallow depth** | ¿Se puede llegar a cualquier página en ≤ 3 clicks? |
| 7 | **Escalabilidad** | ¿Se puede añadir contenido sin reestructurar? |
| 8 | **Consistencia** | ¿Las convenciones de naming y estructura son uniformes? |

## 26.2 Evaluación rápida

```
Para cada heurística, puntúa de 1 a 5:

1 = Falla completamente
3 = Aceptable con mejoras
5 = Excelente

Promedio < 3  → Reestructurar
Promedio 3–4  → Refinar
Promedio > 4  → Validar con usuarios y avanzar
```

---

# 27. Pruebas con Usuarios

## 27.1 Métodos ordenados por costo

| Método | Cuándo | Participantes | Costo |
|--------|--------|---------------|-------|
| **Review con equipo** | Siempre (mínimo) | 3–5 colegas | Bajo |
| **5-second test** | Evaluar naming | 10–20 usuarios | Bajo |
| **Card Sorting cerrado** | Validar categorías | 15–30 usuarios | Medio |
| **Tree Testing** | Validar findability | 30–50 usuarios | Medio |
| **Usability testing (wireframes)** | Validar en contexto real | 5–8 usuarios | Alto |

## 27.2 Protocolo de Tree Testing

```
PREPARACIÓN:
  1. Exportar la estructura del sitemap como texto jerárquico
  2. Definir 8–10 tareas que cubran las secciones más importantes
  3. Reclutar 30+ participantes del público objetivo

TAREAS EJEMPLO (e-commerce):
  T1: "Encuentra dónde cambiar tu dirección de envío"
  T2: "Encuentra las camisetas para hombre en oferta"
  T3: "Encuentra la política de devoluciones"
  T4: "Encuentra cómo contactar soporte por chat"
  T5: "Encuentra un regalo para alguien que le gusta cocinar"

ANÁLISIS:
  → Success rate por tarea (meta: > 80%)
  → Directness por tarea (meta: > 60%)
  → First click correctness (meta: > 70%)
  → Paths tomados (identificar confusión)
  → Items problemáticos (tareas con < 50% success)
```

---

# 28. Métricas de Findability

## 28.1 Métricas clave

| Métrica | Definición | Cómo se mide | Benchmark |
|---------|-----------|-------------|-----------|
| **Findability rate** | % de usuarios que encuentran lo que buscan | Tree Testing / Usability Test | > 80% |
| **Time to task** | Tiempo promedio para completar una tarea | Tree Testing con timestamps | Depende de profundidad |
| **Lostness score** | Qué tan perdido estuvo el usuario | (Nodos visitados - óptimo) / total | < 0.4 |
| **First click success** | % con primer click correcto | Click tracking | > 70% |
| **Search vs nav usage** | Ratio búsqueda/navegación | Analytics | Si > 50% buscan, la nav falla |
| **Bounce rate por sección** | % que abandona una sección sin interactuar | Analytics | < 40% |

## 28.2 Interpretación

```
Si findability rate < 80%:
  → La estructura no coincide con el modelo mental del usuario
  → Hacer Card Sorting para redescubrir categorías

Si time to task es alto:
  → La estructura es demasiado profunda
  → O el naming es confuso
  → Aplanar y/o renombrar

Si lostness > 0.4:
  → El usuario navega en círculos
  → Las categorías no son mutuamente excluyentes
  → Hay ambigüedad en el naming

Si search > 50%:
  → La navegación falla
  → Los usuarios no confían en la estructura para encontrar cosas
  → Reevaluar categorías de nivel 1 y 2
```

---

# PARTE IX — CASOS PRÁCTICOS

---

# 29. Sitemap para E-commerce

## 29.1 Estructura tipo

```
                              ╔══════════════╗
                              ║     HOME     ║
                              ╚══════╤═══════╝
          ┌──────────┬───────────┬───┴───┬───────────┬──────────┐
          ▼          ▼           ▼       ▼           ▼          ▼
    ┌──────────┐┌──────────┐┌───────┐┌───────┐┌──────────┐┌────────┐
    │ Hombre   ││  Mujer   ││ Niños ││Ofertas││   Blog   ││Contacto│
    └────┬─────┘└────┬─────┘└───┬───┘└───┬───┘└────┬─────┘└────────┘
    ┌────┼────┐      │     ┌────┼────┐   │         │
    ▼    ▼    ▼      ▼     ▼    ▼    ▼   ▼         ▼
  Camis Pant Zapat  ...  Camis Pant ...  Listado  Post (×N)
    │                                    ofertas
    ▼
  Producto (×N)
  ├── Descripción
  ├── Reviews
  └── Relacionados

  ── Utilidades ─────────────────────────────────────────────
  Login | Register | Carrito | Checkout | Mi cuenta | FAQ
  Wishlist | Tracking | Devoluciones | Terms | Privacy
```

## 29.2 Decisiones clave

| Decisión | Opción A | Opción B | Recomendación |
|----------|----------|----------|---------------|
| Categorías nivel 1 | Por género (Hombre/Mujer) | Por tipo (Camisetas/Pantalones) | Depende del negocio — moda: por género; electrónica: por tipo |
| Filtros vs subcategorías | Subcategorías en sitemap | Filtros en la interfaz | Filtros para atributos (talla, color); subcategorías para tipos |
| Ofertas | Sección separada | Tag dentro de categorías | Ambos: sección + tag (máxima visibilidad) |
| Blog | Nivel 1 | Bajo "Recursos" | Nivel 1 si el contenido es estratégico (SEO) |

---

# 30. Sitemap para SaaS

## 30.1 Estructura tipo

```
                              ╔══════════════╗
                              ║     HOME     ║
                              ╚══════╤═══════╝
         ┌────────────┬───────────┬──┴───┬───────────┬────────────┐
         ▼            ▼           ▼      ▼           ▼            ▼
   ┌──────────┐┌──────────┐┌──────────┐┌───────┐┌──────────┐┌────────┐
   │ Features ││ Pricing  ││Resources ││ About ││   Blog   ││ Login  │
   └────┬─────┘└──────────┘└────┬─────┘└───────┘└────┬─────┘└────┬───┘
        │                  ┌────┼────┐                │      ┌───┴────┐
        ▼                  ▼    ▼    ▼                ▼      ▼        ▼
   Feature detail (×N)   Docs  API  Help           Post(×N) Sign Up  App
                         Center                             │
                                                            ▼
                                                      ┌──────────┐
                                                      │ Dashboard│
                                                      └────┬─────┘
                                                  ┌────────┼────────┐
                                                  ▼        ▼        ▼
                                              Projects  Settings  Billing
                                                  │
                                                  ▼
                                              Project (×N)
                                              ├── Tasks
                                              ├── Members
                                              └── Settings
```

## 30.2 Decisiones clave

| Decisión | Recomendación | Razón |
|----------|--------------|-------|
| Marketing site vs App | Sitemaps separados | Son productos diferentes con usuarios diferentes |
| Features list | Una página por feature | Mejor para SEO y comprensión |
| Pricing | Una sola página con toggle mensual/anual | Simplificar la decisión |
| Docs vs Blog | Secciones separadas | Intención diferente (aprender vs explorar) |
| Dashboard structure | Matricial (acceso cruzado entre secciones) | El usuario salta entre proyectos/settings |

---

# 31. Sitemap para Blog / Contenido

## 31.1 Estructura tipo

```
                              ╔══════════════╗
                              ║     HOME     ║
                              ╚══════╤═══════╝
         ┌────────────┬───────────┬──┴───┬────────────┐
         ▼            ▼           ▼      ▼            ▼
   ┌──────────┐┌──────────┐┌──────────┐┌───────┐┌────────┐
   │ Articles ││ Categ.   ││ Authors  ││ About ││Newsletter│
   └────┬─────┘└────┬─────┘└────┬─────┘└───────┘└────────┘
        │      ┌────┼────┐      │
        ▼      ▼    ▼    ▼      ▼
   Article   UX  Dev  Product  Author
   (×N)                        profile (×N)
   ├── Contenido
   ├── Tags
   ├── Autor
   └── Relacionados
```

## 31.2 Decisiones clave

| Decisión | Recomendación | Razón |
|----------|--------------|-------|
| Navegación principal | Por categoría + recientes | Los usuarios buscan por tema o lo más nuevo |
| Tags vs Categorías | Categorías para estructura, tags para filtrado | Las categorías son jerárquicas; los tags son transversales |
| Paginación | Infinite scroll o "Load more" para listados | Mejor UX que paginación numérica para contenido |
| Sidebar | Populares + Categorías + Newsletter CTA | Maximizar engagement y conversión |

---

# 32. Comparación entre Estructuras

```
                   E-commerce          SaaS               Blog
                   ─────────           ────               ────
Tipo               Jerárquico          Híbrido            Jerárquico
                   (profundo)          (jerárq + matricial) (shallow)

Profundidad        3–4 niveles         2–3 (marketing)     2 niveles
                                       3–4 (app)

Nav principal      Categorías de       Features, Pricing,  Categorías de
                   producto            Resources           contenido

Contenido          Productos (×100s)   Docs + Blog         Artículos (×100s)
dinámico

Desafío #1         Categorización      Separar marketing   Descubrimiento
                   de productos        de app              de contenido

Desafío #2         Filtros vs          Onboarding          Mantener engagement
                   navegación          del usuario         (artículos relacionados)

Patrón nav         Mega menu +         Top nav simple +    Categorías +
                   filtros laterales   sidebar en app      search prominente
```

---

# PARTE X — ANTI-PATRONES, ERRORES COMUNES Y BUENAS PRÁCTICAS

---

# 33. Errores Comunes

## 33.1 Los 10 errores más frecuentes

| # | Error | Por qué es un problema | Solución |
|---|-------|----------------------|----------|
| 1 | **Sobreprofundidad** | Más de 4 niveles → el usuario se pierde | Aplanar: máximo 3–4 niveles |
| 2 | **Categorías solapadas** | "¿Está en Soporte o en Mi cuenta?" | Card Sorting para validar categorías |
| 3 | **Naming con jerga interna** | El usuario no entiende | Testear nombres con usuarios reales |
| 4 | **Estructura basada en departamentos** | Refleja la empresa, no al usuario | Organizar por tareas/necesidades del usuario |
| 5 | **Mega menú con 40+ items** | Parálisis de decisión | Máximo 7 items por categoría visible |
| 6 | **Categoría "Otros" o "Más"** | Cajón de sastre → mala IA | Redistribuir o crear categorías nuevas |
| 7 | **No incluir páginas utilitarias** | Login, 404, error → olvidados | Agregarlas al sitemap desde el inicio |
| 8 | **Sitemap sin validación** | Basado en suposiciones del equipo | Tree Testing antes de wireframear |
| 9 | **Sitemap como entregable final** | No se actualiza → queda obsoleto | Versionar y mantener como documento vivo |
| 10 | **Copiar la estructura del competidor** | Su contexto no es tu contexto | Investigar tus propios usuarios |

---

# 34. Anti-Patrones de Arquitectura

## 34.1 El Iceberg

```
ANTI-PATRÓN: EL ICEBERG

       Nivel 1:  ┌──────┐
                  │ Home │  ← Solo 3 secciones visibles
                  └──┬───┘
           ┌─────────┼─────────┐
           ▼         ▼         ▼
        Sec A     Sec B     Sec C
           │
     ┌─────┼─────┬─────┬─────┐
     ▼     ▼     ▼     ▼     ▼
    Sub1  Sub2  Sub3  Sub4  Sub5     ← Nivel 2: 5 subs
     │
  ┌──┼──┬──┬──┬──┬──┬──┐
  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼            ← Nivel 3: 8 items
                │
        ┌───┬──┼──┬───┐
        ▼   ▼  ▼  ▼   ▼              ← Nivel 4: 5 items más

PROBLEMA: El 90% del contenido está enterrado bajo Sec A.
         Las otras secciones tienen 1–2 páginas.

SOLUCIÓN: Redistribuir contenido de Sec A en nuevas
         categorías de Nivel 1.
```

## 34.2 El Pancake

```
ANTI-PATRÓN: EL PANCAKE

Home ──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
       ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼
       A  B  C  D  E  F  G  H  I  J  K  L  M  N  O  P

PROBLEMA: 16 secciones al mismo nivel.
         Navegación imposible, parálisis de decisión.

SOLUCIÓN: Agrupar en 4–6 categorías con subcategorías.
```

## 34.3 El Espejo Corporativo

```
ANTI-PATRÓN: EL ESPEJO CORPORATIVO

Home
├── Departamento de Marketing     ← El usuario no sabe ni
│   ├── Campañas                    le importa cómo está
│   └── Materiales                  organizada la empresa
├── Departamento de Ventas
│   ├── Precios
│   └── Demos
├── Departamento de Soporte
│   ├── Tickets
│   └── FAQ
└── Departamento Legal
    ├── Términos
    └── Privacidad

SOLUCIÓN (centrado en el usuario):
Home
├── Productos (precios, demos, features)
├── Recursos (materiales, campañas, blog)
├── Ayuda (FAQ, tickets, contacto)
└── Legal (términos, privacidad)
```

---

# 35. Checklist Final

## 35.1 Antes de avanzar a wireframes

```
INVESTIGACIÓN:
  □ Entendemos quién es el usuario y qué necesita
  □ Hicimos Card Sorting (o al menos análisis competitivo)
  □ Conocemos los objetivos del negocio
  □ Completamos el inventario de contenido

ESTRUCTURA:
  □ El sitemap tiene ≤ 4 niveles de profundidad
  □ Cada nivel tiene 5–7 items (máximo 9)
  □ Las categorías son mutuamente excluyivas
  □ Hay espacio para crecimiento futuro
  □ Todas las páginas del inventario están representadas
  □ Las páginas utilitarias están incluidas (login, 404, legal)

NAMING:
  □ Los nombres son claros para el usuario (no jerga interna)
  □ Son consistentes en estilo, tono e idioma
  □ Pasan el "test de cerrar los ojos"
  □ No hay solapamiento entre categorías

VALIDACIÓN:
  □ Tree Testing con Success Rate > 80%
  □ Revisión con stakeholders (alcance y prioridades)
  □ Revisión con developers (viabilidad técnica)
  □ Versionado con fecha y changelog

NAVEGACIÓN:
  □ El sitemap se traduce claramente en navegación
  □ Cualquier página es alcanzable en ≤ 3 clicks
  □ Las tareas frecuentes son las más accesibles
  □ Hay breadcrumbs o indicadores de ubicación
```

## 35.2 Reglas de oro

| Regla | Razón |
|-------|-------|
| Estructura para el usuario, no para la empresa | El usuario no conoce tus departamentos |
| Máximo 4 niveles de profundidad | Cada nivel es fricción |
| 5–7 items por nivel | Miller's Law: 7 ± 2 |
| Validar con usuarios reales | Tu lógica ≠ la del usuario |
| El sitemap es un documento vivo | Evoluciona con el producto |
| Naming claro > naming creativo | "Mi cuenta" > "Mi universo" |
| Card Sorting antes, Tree Testing después | Generar → Validar → Iterar |
| Un sitemap no es un wireframe | Estructura ≠ Diseño |

---

> **Nota final:** Un sitemap es invisible para el usuario final — nunca lo verá.
> Pero lo sentirá en cada click, en cada menú, en cada momento de "¿dónde está lo
> que busco?". Un buen sitemap hace que el usuario ni piense en la estructura porque
> todo está exactamente donde espera. Ese es el objetivo: que la arquitectura sea
> tan lógica que se vuelva invisible. Antes de abrir Figma, dibuja el mapa.
