# plat-01 — Lección: Team Topologies y Cognitive Load

> 12 secciones. 100 % conceptual. Prerrequisito: haber operado un sistema real y haber vivido, aunque sea de refilón, los dolores de una organización mal cableada.

---

## 1. Por qué este módulo abre el curso

Platform Engineering no es "DevOps con un rebrand". Es una **disciplina de producto interno** que diseña, construye y opera una plataforma cuya misión única es **reducir la carga cognitiva de los equipos que producen valor para el negocio** (stream-aligned teams).

Si saltas al tooling (Backstage, Crossplane, Argo) sin entender el modelo organizacional, construyes un **IDP sin cliente claro**. Es el error más caro de este espacio: equipos de plataforma con roadmap definido *desde dentro*, construyendo features que nadie pidió, mientras los stream-aligned siguen gastando el 40 % de su tiempo en YAML.

El modelo que vamos a adoptar — **Team Topologies** de Matthew Skelton y Manuel Pais (2019) — no es "una metodología más": es el lenguaje común de la industria para hablar de **estructura de equipos** en entornos de software complejo. Lo citan la CNCF, Spotify, Netflix, ING, Mercado Libre y los informes de State of DevOps/DORA. Si no lo manejas, estás fuera del vocabulario operativo del campo.

> **Idea clave que repetiremos:** la plataforma existe para **servir** a los stream-aligned teams, no para **tutelarlos**. El día que la plataforma impone *collaboration* para cada feature, dejó de ser plataforma.

---

## 2. Cognitive load: el presupuesto invisible de un equipo

Un equipo de software tiene una capacidad cognitiva **finita**. John Sweller (psicología educativa, años 80) la descompone en tres fuentes:

- **Intrinsic** — la complejidad **inherente** al problema de negocio que el equipo resuelve. Un equipo de pricing tiene intrinsic alta porque los precios dependen de 15 variables; no se puede reducir sin cambiar el dominio.
- **Extraneous** — la complejidad **accidental** impuesta por *cómo* se construye y opera el software: 7 formatos de YAML distintos, 3 CI/CDs, 2 clusters K8s diferentes, un wiki stale, scripts bash sin ownership. Se puede eliminar sin tocar el dominio.
- **Germane** — la complejidad **productiva** que un equipo invierte en construir modelos mentales reutilizables: refactor hacia un diseño limpio, aprendizaje de un patrón que acelera futuras features. Es la "deuda positiva".

La ecuación operacional de Team Topologies, cualitativa pero útil:

```
   capacidad_total  =  intrinsic  +  extraneous  +  germane
                       ^^^^^^^^^            ^^^^^^^^^
                       (no se puede        (se recupera
                        bajar sin cambiar   eliminando
                        dominio)            YAML/herramientas)
```

Si *extraneous* domina (equipo gastando 40 % del sprint en pipelines, infra, parches de credenciales), queda menos para intrinsic (resolver pricing) y germane (mejorar el diseño). **Esa recuperación es, literalmente, la propuesta de valor de Platform Engineering.**

Métricas prácticas de cognitive load (no hace falta instrumental sofisticado):

- *Time to first commit* de un nuevo joiner (días hasta merge productivo).
- *Lead time* de un cambio trivial en infra (abrir puerto, añadir variable de entorno).
- *Encuesta semestral* al equipo: "¿cuántas tecnologías tienes que entender para hacer tu trabajo bien?". Si pasa de ~5, es warning; de ~8, es rojo.
- **Platform NPS** entre stream-aligned teams: "¿recomendarías la plataforma a otro equipo?".

> La plataforma es **evaluada por cuánto baja la cognitive load extraneous del resto de equipos**, no por cuántos microservicios tiene o cuántas features internas lanzó.

---

## 3. Team Topologies: los 4 tipos de equipo

Skelton & Pais afirman que, en una organización de software compleja, **solo hacen falta 4 tipos de equipo**. Cualquier equipo que no encaje en uno de los 4 probablemente es un antipattern o un residuo histórico.

### 3.1 Stream-aligned team

- **Qué hace:** entrega **valor directo al cliente** sobre un *flujo de cambio* (feature stream, producto, journey).
- **Autonomía:** alta — debería poder ir end-to-end desde idea hasta producción sin esperar a nadie.
- **Ejemplo:** equipo "Checkout" de un e-commerce; equipo "Signals" de un vendor APM; equipo "Pricing" de un marketplace.
- **Debe optimizarse por:** *flow* de entrega continua, no por "estar ocupado".

Los stream-aligned son los **clientes principales** del platform team. Todo lo demás existe para que ellos vayan rápido y seguros.

### 3.2 Platform team

- **Qué hace:** opera una **plataforma como producto** que **reduce cognitive load extraneous** de los stream-aligned. Esta plataforma es *interna*, pero se piensa, se mide y se cobra (o se audita) **como un producto SaaS**.
- **Autonomía:** alta en su roadmap, pero **cliente-driven**: su backlog sale de las necesidades reales de los stream-aligned, verificadas.
- **Ejemplo:** equipo "Delivery Platform" que opera Backstage, los golden paths, el CI/CD compartido y el cluster multi-tenant.
- **Debe optimizarse por:** adopción voluntaria, platform NPS, lead-time para nuevos servicios.

**Este es el equipo que estás aprendiendo a dirigir.** El curso entero gira en torno a cómo hacer que un platform team sea un *producto* y no una cola de tickets.

### 3.3 Enabling team

- **Qué hace:** **capacita temporalmente** a stream-aligned teams en una tecnología nueva o práctica (observabilidad, SRE, seguridad, data engineering). **Se mete, enseña y se sale.**
- **Autonomía:** media; su éxito se mide por el **traspaso de capacidad**, no por retenerla.
- **Ejemplo:** equipo "Observability Enablement" que durante 6 semanas acompaña al equipo Checkout a instrumentar OTel + definir SLOs, y luego se retira.
- **Debe optimizarse por:** capacidades traspasadas, autonomía resultante en el equipo cliente.

El enabling team **no es** un platform team; no mantiene infraestructura. Es un *coach* técnico con mandato explícito de rotación.

### 3.4 Complicated-subsystem team

- **Qué hace:** opera un **subsistema con complejidad intrínseca** que requiere expertise profunda y escasa (motor de ML, kernel de cálculo numérico, stack de video codecs, HSM criptográfico).
- **Autonomía:** alta en el subsistema; su interfaz hacia el resto es un **API fuertemente contratada**.
- **Ejemplo:** equipo "Risk Engine" que mantiene un motor Monte Carlo en C++; equipo "ASR" que mantiene un modelo de speech-to-text y su serving.
- **Debe optimizarse por:** calidad del subsistema y claridad del contrato hacia los stream-aligned.

Diferencia clave con un platform team: el complicated-subsystem **sirve a 1–3 streams muy específicos**, no al conjunto; su "producto" es *expertise encapsulada*, no *reducción de carga cognitiva general*.

### 3.5 Mnemonic

```
┌─────────────────────┬─────────────────────────────────────────────┐
│ Tipo                │ Pregunta que responde                       │
├─────────────────────┼─────────────────────────────────────────────┤
│ Stream-aligned      │ ¿Entrego valor al cliente?                  │
│ Platform            │ ¿Reduzco cognitive load del resto?          │
│ Enabling            │ ¿Capacito y me voy?                         │
│ Complicated-subsys. │ ¿Encapsulo expertise escasa tras un API?    │
└─────────────────────┴─────────────────────────────────────────────┘
```

Si un equipo no sabe responder a una de estas 4 preguntas, está mal tipado — y probablemente mal operado.

---

## 4. Los 3 modos de interacción

Entre equipos hay solo **3 modos de interacción válidos** en Team Topologies. Cualquier otro ("tickets", "escalaciones", "pasillos") es síntoma de topología mal diseñada.

### 4.1 X-as-a-Service

- **Qué es:** el equipo B **consume** algo que el equipo A ofrece como un **servicio con contrato claro** (self-service, documentado, con SLO).
- **Carga cognitiva en B:** mínima; B no necesita saber *cómo* funciona por dentro.
- **Ejemplo:** stream-aligned Checkout consume "Delivery Platform" para desplegar — abre un PR, el pipeline se ejecuta, la app aparece en producción. No habla con el platform team salvo para feedback de producto.

**Este debe ser el modo DEFAULT entre un platform team y los stream-aligned.** Repetirlo hasta que suene aburrido.

### 4.2 Collaboration

- **Qué es:** dos equipos **trabajan juntos** durante un período definido para resolver un problema que ninguno puede resolver solo.
- **Carga cognitiva en ambos:** alta — comparten contexto, decisiones, trade-offs.
- **Ejemplo:** Delivery Platform y Checkout colaboran 4 semanas para diseñar un patrón nuevo de deployment canario que no existía; luego Delivery Platform lo convierte en X-as-a-Service.

**Collaboration es caro.** Debe ser **temporal, acotado y intencional**. Si cada feature nueva requiere collaboration con el platform team, la plataforma falló: debería ofrecer X-as-a-Service.

### 4.3 Facilitating

- **Qué es:** un enabling team **ayuda** a otro equipo a aprender una práctica o superar un bloqueo técnico, con mandato explícito de **retirarse** cuando el equipo cliente adquiere la capacidad.
- **Carga cognitiva en el cliente:** se eleva temporalmente (aprender) para bajar permanentemente (autonomía).
- **Ejemplo:** Observability Enablement acompaña a Pricing durante 6 semanas en adoptar SLOs; después, Pricing opera solo.

### 4.4 Regla de oro

```
   Platform team × Stream-aligned  →  X-as-a-Service (DEFAULT)
                                      Collaboration solo si un patrón NUEVO
                                      Facilitating NO (eso es enabling team)

   Enabling team × Stream-aligned  →  Facilitating (temporal, por diseño)

   Complicated-subsys × Stream     →  X-as-a-Service (API contratada)

   Stream × Stream                 →  Idealmente ninguno (si lo necesitan,
                                      hay un acoplamiento mal resuelto)
```

Un **anti-tell** poderoso: si el platform team dice "estamos colaborando con *todos* los equipos", eso **no** es un platform team — es un enabling team disfrazado o, peor, un ivory tower que decide por todos.

---

## 5. Platform team: por qué es X-as-a-Service por default

Un platform team mal entendido se vuelve, en 6 meses, una de estas tres cosas:

- **"Ivory tower"** — decide la arquitectura del resto, publica standards sin plugs, se queja de que "nadie los sigue".
- **"Ticketing-driven ops"** — recibe tickets ("necesito un namespace", "abran puerto 8080"), los resuelve a mano, se vuelve cuello de botella.
- **"Dumping ground"** — todo lo que ningún otro equipo quiere ("Kafka legacy", "aquel Jenkins", "ese cluster viejo") termina ahí; su backlog es un cementerio.

La raíz de los tres: el **modo de interacción está mal**. En lugar de ofrecer **capacidades consumibles vía self-service**, el platform team se insertó como **intermediario humano** en el flujo de los demás.

El antídoto es tratar la plataforma **como un producto**:

- Tiene **clientes identificados** (los stream-aligned teams), no "usuarios genéricos".
- Tiene **features priorizadas por valor para esos clientes**, no por elegancia técnica interna.
- Tiene **métricas de producto** (adopción, NPS, lead-time, retention), no solo métricas de infra (uptime, p95).
- Tiene **product mindset** en el equipo: alguien hace discovery, alguien escribe docs, alguien escucha feedback.
- Las features se ofrecen como **X-as-a-Service**: *self-service*, documentadas, con contrato de disponibilidad.

Si cada capability del platform team **se puede consumir sin hablar con el equipo**, el modelo es sano. Si cada capability requiere una conversación → tickets → humanos en el loop → la plataforma falló como producto.

> **Test rápido:** ¿puede un stream-aligned onboarding un servicio nuevo **sin abrir un ticket al platform team**? Si no, trabajo pendiente.

---

## 6. Conway's Law y el reverse Conway maneuver

Melvin Conway (1968):

> *"Organizations that design systems are constrained to produce designs which are copies of the communication structures of these organizations."*

Traducción práctica: **si tu organización tiene 4 silos, tu arquitectura va a tener 4 silos**. No importa qué diseño "ideal" dibujes en Confluence; el software se parecerá a tu organigrama.

Ejemplo canónico: una organización con *frontend*, *backend* y *DBA* como departamentos separados producirá, inevitablemente, aplicaciones con una **capa de frontend**, una **capa de backend** y una **capa de datos** fuertemente acopladas en los bordes y mal diseñadas en las juntas.

El **reverse Conway maneuver** (Jim Coplien, 2004; popularizado por *The DevOps Handbook*): **primero diseña los equipos con la forma de la arquitectura que quieres**, y la arquitectura **emergerá** siguiéndolos.

Caso de uso para platform engineering:

- Si quieres una arquitectura basada en **microservicios independientes por stream**, necesitas **stream-aligned teams autónomos** — no un pool de desarrolladores asignados por tickets.
- Si quieres una arquitectura con un **plano de datos compartido**, necesitas un **platform team o complicated-subsystem** dueño de ese plano, con interfaz X-as-a-Service.
- Si quieres un **IDP cohesivo**, necesitas un **platform team con product mindset** — no tres equipos de "DevOps" descoordinados.

> Diseñar la organización es **diseñar la arquitectura**. Si solo diseñas la arquitectura y no tocas la organización, la organización te ganará.

---

## 7. Los antipatterns clásicos y su contra-movimiento

### 7.1 Ivory tower platform team

- **Síntoma:** el platform team publica standards, templates y "la forma correcta", pero **no habla con los clientes**. Los stream-aligned los ignoran o los sabotean en silencio.
- **Causa raíz:** falta de product mindset; se ha confundido *autoridad técnica* con *autoridad de producto*.
- **Movimiento correctivo:** instalar **discovery continuo** con stream-aligned (entrevistas trimestrales, oficinas abiertas, observación de pair programming). Mover métricas internas → **adopción voluntaria** y **platform NPS**.

### 7.2 Ticketing-driven ops

- **Síntoma:** cada necesidad de infra = un ticket a resolver por un humano del platform team. El equipo plataforma es cuello de botella sistémico.
- **Causa raíz:** falta de capabilities self-service; el platform team "no confía" en que los stream-aligned usen bien la infra.
- **Movimiento correctivo:** **productizar** cada ticket repetitivo: si "crear namespace" se pide 3 veces por mes, se vuelve un comando en el IDP; si "abrir puerto" se pide 10 veces, se vuelve un formulario con approval automatizado por policy.

### 7.3 Platform as a dumping ground

- **Síntoma:** el equipo plataforma hereda sistemas legacy que nadie quiere, se vuelve "los que mantienen lo viejo", y pierde capacidad para construir lo nuevo.
- **Causa raíz:** falta de **product boundaries** — se acepta cualquier backlog item por "ser responsable de infra".
- **Movimiento correctivo:** definir **product boundaries** explícitas (qué entra en la plataforma, qué no). Negociar *deprecation* o traspaso a un **complicated-subsystem team** si realmente es expertise escasa; o devolver el sistema a su stream-aligned natural si tiene uno.

### 7.4 "DevOps engineer" como rol (no como cultura)

- **Síntoma:** se contrata un "DevOps engineer" por equipo stream-aligned para que "haga el YAML". El rol se vuelve el cuello de botella **dentro** del equipo.
- **Causa raíz:** se confundió **DevOps como cultura y prácticas** (CI/CD, ownership compartido, feedback rápido) con **"DevOps como un rol dedicado"** (una persona que absorbe la complejidad extraneous).
- **Movimiento correctivo:** convertir ese rol en una **capacidad consumida por X-as-a-Service** de un platform team, y **capacitar** al resto del stream-aligned en los contratos que la plataforma ofrece (vía enabling team si es necesario).

### 7.5 Platform team sin product mindset

- **Síntoma:** roadmap decidido por "lo que es técnicamente elegante" (migrar a service mesh, adoptar OPA, switch a Argo Rollouts), sin un driver claro de los stream-aligned.
- **Causa raíz:** se ha equiparado "ser dueño técnico de la plataforma" con "poder decidir sin cliente".
- **Movimiento correctivo:** nombrar un **product manager** (o PM-aligned) para la plataforma. Priorizar backlog con **evidencia** de stream-aligned (observación, encuestas, lead-time). Publicar roadmap con fechas.

### 7.6 Enabling team eterno

- **Síntoma:** un equipo nominalmente "enabling" lleva 2 años acompañando a los mismos equipos. Nunca "sale".
- **Causa raíz:** no se definió el contrato de salida; el enabling se volvió un sub-equipo permanente del cliente.
- **Movimiento correctivo:** cada engagement del enabling team debe tener **duración acotada y criterio de salida medible** (ej.: "el equipo Checkout opera solo sus SLOs durante 1 mes sin ayuda").

---

## 8. Métricas tempranas de salud

Un platform team sano, en el primer año, debería poder mostrar movimiento en estas métricas (ninguna debe tomarse aislada; conjuntas cuentan la historia):

- **Adopción voluntaria** — % de servicios nuevos que arrancan desde el template oficial del golden path. Si es < 50 % a los 6 meses, hay un problema de producto o de evangelismo.
- **Lead-time de "nuevo microservicio en producción"** — desde "idea" hasta "primer deploy real". Objetivo típico: < 1 día.
- **Lead-time de un cambio trivial de infra** (abrir puerto, variable, secret) — minutos vía self-service, no días vía ticket.
- **Platform NPS** entre stream-aligned — "¿recomendarías la plataforma a otro equipo?". Encuesta trimestral.
- **Cognitive load percibida** — encuesta anual: "¿cuántas tecnologías tienes que entender bien para hacer tu trabajo?". Bajar o estabilizar es señal de que la plataforma está absorbiendo complejidad.
- **Tickets manuales al platform team** — tendencia **a la baja** mes a mes. Si sube, es señal de capability que debería ser self-service.
- **DORA metrics** (deployment frequency, lead time, change failure rate, time to restore) a nivel de **stream-aligned** — mejoras indirectas de la plataforma.

> **Antimétrica:** "uptime del cluster". Es importante, pero no mide el valor para los clientes. Si el cluster está 99.99 % up pero nadie puede desplegar sin ticket, el platform team no está haciendo su trabajo.

---

## 9. "DevOps" vs "Platform Engineering" vs "SRE"

Un mapa rápido de términos que la industria usa de forma ambigua:

| Término | Qué es *bien entendido* | Dónde fracasa habitualmente |
|---------|-------------------------|------------------------------|
| **DevOps** | Cultura + prácticas (CI/CD, feedback rápido, ownership compartido) | Degenerado en "DevOps engineer" como rol que absorbe el YAML por los demás. |
| **SRE** (Google) | Práctica de ingeniería que aplica engineering al problema de reliability (error budgets, SLOs, toil reduction) | Confundido con "ops renombrado". El SRE sin error budget no es SRE. |
| **Platform Engineering** | Disciplina que trata la plataforma interna como **producto** para reducir cognitive load | Confundido con "ops centralizado" o "arquitectura central" sin producto. |

Compatibilidad: **las tres pueden coexistir**. Un platform team con SRE embedded + prácticas DevOps en todos los stream-aligned es el patrón más común en empresas maduras. **No son excluyentes; son complementarias.**

Punto importante: Platform Engineering es la etiqueta más **nueva** de las tres y la más **específica**. Nombra la disciplina (producto interno), no un rol ni una práctica.

---

## 10. Cuándo NO montar un platform team

Montar un platform team **antes de tiempo** es un error caro. Casos donde la respuesta sensata es **esperar**:

- **Menos de ~5–8 stream-aligned teams.** Con 3 equipos y 2 servicios, la plataforma es *overhead*. Mejor que uno de los equipos haga de *de-facto platform team* a tiempo parcial, o se adopte un IDP SaaS (Port, Humanitec) sin construir nada.
- **Negocio en fase de product-market-fit.** Si el producto cambia cada 2 semanas, construir una plataforma estable es prematuro; la plataforma debería estabilizar un **patrón repetido**, no un patrón aún no descubierto.
- **Sin buy-in de leadership.** Un platform team sin presupuesto plurianual y sin mandato se vuelve un equipo de 2 personas con un roadmap imposible. Mejor diferir hasta tener compromiso real.
- **Sin un stream-aligned "cliente alfa".** El primer platform team necesita **un cliente** dispuesto a adoptar lo que construye, dar feedback brutal y aparecer en el discurso de pasillo. Sin alfa, se construye en el vacío.

Si no se cumplen las condiciones, alternativas razonables:

- **Un stream-aligned team con 20 % de tiempo dedicado a "plataforma interna"** (contrato temporal, revisado cada 6 meses).
- **Adoptar un IDP SaaS** (Port, Humanitec) para evitar construir infra y centrarse en los golden paths de contenido.
- **Centrarse en 1–2 golden paths de alto impacto** sin equipo formal, operados por rotación.

Esto se explora en la actividad `01-map-your-org` cuando pides al estudiante que decida si su organización ficticia necesita o no un platform team formal.

---

## 11. Lo que NO cubre este módulo (y por qué)

Este módulo deja fuera, intencionalmente:

- **Golden paths concretos** (plantillas, templates, scaffolder) → `plat-02` y `plat-06`.
- **Elección de IDP** (Backstage vs Port vs CNOE vs Humanitec) → `plat-03`.
- **Catálogo de servicios y modelado** → `plat-05`.
- **Scorecards y governance de ownership** → `plat-10`.
- **FinOps y costeo de plataforma** → `plat-12`.

Es intencional porque **sin el modelo organizacional claro, cualquier herramienta se usa mal**. Backstage sin platform team con product mindset es un wiki vacío. Un golden path sin stream-aligned clientes es un folder en Git.

El error típico de equipos nuevos: empezar instalando Backstage en lugar de mapear la organización. Este módulo invierte el orden.

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Dibujar la organización en **Team Topologies** con los 4 tipos de equipo mapeados.
- Explicar los **3 modos de interacción** y por qué el default platform × stream es **X-as-a-Service**.
- Reconocer los **4 antipatterns clásicos** (ivory tower, ticketing-driven, dumping ground, DevOps-as-role) y proponer el movimiento correctivo.
- Argumentar un **reverse Conway maneuver** concreto para alinear equipos con la arquitectura objetivo.
- Decidir, para una organización dada, **si necesita** un platform team formal o si todavía no está lista.

Lo que **sigue**:

- `plat-02` — Golden paths, paved roads y developer experience: pasar del modelo organizacional al **primer producto** de la plataforma.
- `plat-03` — IDP landscape: Backstage, Port, OpsLevel, Cortex, Humanitec, CNOE. Qué elegir y cuándo.
- `plat-04` → `plat-06` — Backstage profundo: arquitectura, catálogo, templates.

Una síntesis final de una línea:

> **Platform Engineering es la disciplina de construir una plataforma interna *como producto*, servida *as-a-Service* a equipos stream-aligned, con el objetivo medible de bajar su cognitive load extraneous — y la *estructura organizacional* es la primera decisión arquitectónica.**

Todo lo demás del curso es **cómo** hacer realidad esa frase sin caer en los antipatterns clásicos.
