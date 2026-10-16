# Ejemplo 03 — Conway's Law walkthrough y reverse Conway maneuver

> Lectura y análisis. Objetivo: ver **con dos escenarios** cómo la estructura de equipos **determina** la arquitectura, y cómo invertir la ecuación.

## 1. Enunciado

Melvin Conway (1968):

> *"Organizations which design systems [...] are constrained to produce designs which are copies of the communication structures of these organizations."*

En práctica: tu software **se parece** a tu organigrama. Siempre.

Si tus equipos están divididos por **capa técnica** (frontend, backend, DBA), tu software será una **arquitectura en capas**. Si tus equipos están divididos por **dominio de negocio** (Checkout, Catalog, Pricing), tu software tenderá a **microservicios por dominio**.

No es casualidad; es estructura. Diseñar la organización **es** diseñar la arquitectura.

## 2. Escenario A — organización en capas → arquitectura en capas (sin intención)

**AcmeCorp** se organizó históricamente por capa técnica. 3 equipos:

```
   ┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
   │  Frontend team     │   │  Backend team      │   │  DBA team          │
   │  (12 personas)     │   │  (18 personas)     │   │  (5 personas)      │
   └────────┬───────────┘   └────────┬───────────┘   └────────┬───────────┘
            │                        │                         │
            │   tickets +            │   tickets +             │
            ▼   handoffs             ▼   handoffs              ▼
       ┌───────────────────────────────────────────────────────────────┐
       │  Software resultante                                          │
       │                                                               │
       │   React monolith   ──►   API Gateway   ──►   Oracle DB única  │
       │                          + Spring monolith   (schemas por     │
       │                                                dominio)       │
       └───────────────────────────────────────────────────────────────┘
```

### Síntomas

- Cada feature nueva requiere **coordinación entre los 3 equipos** (frontend, backend, DBA). Lead-time de feature pequeña: 3 semanas.
- La base de datos única se convierte en **el cuello de botella arquitectónico**: cualquier cambio de schema requiere pasar por DBA.
- Nadie es **dueño end-to-end** de un flujo de negocio. Cuando "Checkout falla", nadie sabe exactamente a quién tocarle.
- El API Gateway + Spring monolith crecen sin límite — es el único punto donde los 3 equipos pueden "integrarse".

**La arquitectura es, literalmente, el organigrama proyectado en código.** No es un accidente: es inevitable mientras la organización esté dividida así.

## 3. Escenario B — organización por dominio → microservicios por dominio

**ChicoCorp** se organizó desde el inicio por dominio de negocio. 4 equipos:

```
   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
   │ Checkout  │  │ Catalog   │  │ Pricing   │  │ Fulfill-  │
   │ (stream)  │  │ (stream)  │  │ (stream)  │  │ ment      │
   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ checkout │  │ catalog  │  │ pricing  │  │ fulfill  │
   │ svc + DB │  │ svc + DB │  │ svc + DB │  │ svc + DB │
   └──────────┘  └──────────┘  └──────────┘  └──────────┘
         │              │              │              │
         └──────────────┴──────────────┴──────────────┘
                        ▼
             (comunicación por eventos)
```

### Síntomas (positivos)

- Cada equipo entrega features end-to-end **sin coordinar con otros**. Lead-time: horas o días, no semanas.
- Cada servicio tiene **su propia base de datos**, con el schema que su dominio necesita. Sin DBA central como cuello de botella.
- La comunicación entre servicios es **asíncrona por eventos** — porque los equipos no se sientan juntos y no pueden sincronizarse en una llamada síncrona en caliente.
- Un fallo en Checkout se localiza al equipo de Checkout; no hay ambigüedad de ownership.

La arquitectura "ideal" de microservicios **emergió** de la estructura organizacional. No se "diseñó en Confluence y se impuso"; se **cultivó** desde el organigrama.

## 4. Reverse Conway maneuver

**Jim Coplien (2004)** popularizó la jugada contraria: **si quieres una arquitectura concreta, primero diseña la organización que la produciría**.

### 4.1 Caso real-world estilizado

AcmeCorp (escenario A) decide que su arquitectura objetivo son microservicios por dominio. **No** empieza por "vamos a trocear el monolito". Empieza por **re-organizar**:

**Año 0 — estado heredado (capas)**

```
   Frontend | Backend | DBA  →  React monolith / Spring monolith / Oracle único
```

**Año 1 — reorganización (reverse Conway)**

```
   Checkout team (full-stack + data)
   Catalog team  (full-stack + data)
   Pricing team  (full-stack + data)
   Platform team (CI/CD, cluster, IDP) ──X-as-a-Service──► 3 streams
```

- Los **ingenieros frontend, backend y DBA** se redistribuyen: cada stream recibe su mix.
- Las bases de datos siguen siendo **la misma Oracle física** al principio — pero se divide **lógicamente** por schemas, cada uno owned por un stream.
- La plataforma se crea nueva.

**Año 2 — la arquitectura empieza a mover**

```
   Checkout team   → extrae su schema a su propio Postgres
                     → extrae su API del monolith a un microservicio
   Catalog team    → ídem, con el ritmo propio del equipo
   Pricing team    → ídem
```

**Año 3 — arquitectura emergente alineada al nuevo organigrama**

```
   checkout-svc + checkout-db   (owned por Checkout team)
   catalog-svc  + catalog-db    (owned por Catalog team)
   pricing-svc  + pricing-db    (owned por Pricing team)
   platform:  CI/CD, K8s, IDP   (owned por Platform team)
   events bus (NATS/Kafka)      (platform-owned, X-as-a-Service)
```

Punto clave: **no se "hizo microservicios"; se re-estructuró la organización y los microservicios emergieron**. Si se hubiera intentado troceo técnico sin reorg, el monolito habría regresado por Conway's Law.

## 5. Qué sí y qué no cambia

| Cambia (porque la gente cambia) | No cambia (ni debería intentarse por tooling) |
|---------------------------------|-----------------------------------------------|
| **Fronteras de ownership** | La complejidad intrínseca del dominio |
| **Modos de comunicación** (síncronos → eventos) | La necesidad de testing, docs, operación |
| **Dónde vive una decisión** (dentro del equipo vs cross-team meeting) | La necesidad de observabilidad y SLOs |
| **La forma de la arquitectura emergente** | La ley física de que algo tiene que **generar valor para el cliente** |

## 6. Error típico: "arquitectura ideal" sin reorg

El error más común en migraciones de monolito a microservicios es diseñar la **arquitectura objetivo** sin tocar la **estructura de equipos**. Resultado típico: 2 años después, la empresa tiene "microservicios" **con el mismo lead-time y los mismos cuellos de botella** que el monolito — porque los mismos equipos siguen pasándose tickets, pero ahora sobre YAML en lugar de PRs al monolith.

**Si no reorganizas, Conway's Law gana. Siempre.**

## 7. Preguntas de autocomprobación

1. Si tu empresa tiene 1 equipo "frontend", 1 "backend", 1 "mobile" y 1 "data" — ¿qué arquitectura **va a terminar** teniendo, pase lo que pase que diseñes en Confluence?
2. ¿Por qué un troceo técnico de monolito **sin reorg** suele terminar en un "monolito distribuido" (lo peor de ambos mundos)?
3. En un reverse Conway maneuver, ¿cuál es la **primera** decisión: dividir las bases de datos, dividir los equipos, o dividir los repositorios?
4. ¿Qué papel juega el platform team en un reverse Conway maneuver? ¿Es el que ejecuta la jugada o el que la **habilita**?

Las respuestas se trabajan en la actividad `01-map-your-org`.
