# REFERENCE — plat-01-02-antipattern-identification

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Situación 1 — AlfaCorp: 32 ADRs ignorados

**Antipattern dominante:** **ivory tower platform team** (con un pie en *platform sin product mindset*).

**Causa raíz:** el platform team se auto-asignó autoridad arquitectónica sin construir **autoridad de producto**. Publicó standards sin cliente alfa, sin validar demanda y sin ofrecer una **ruta más fácil** para seguirlos ("golden path" vs "lee este ADR y buena suerte"). Las métricas públicas (ADRs publicados, cobertura de linting) miden actividad del platform team, no valor para el cliente.

**Daño concreto:**

- Adopción voluntaria < 20 %. En Team Topologies, eso es señal de **producto fallido**, no de "equipos indisciplinados".
- Cognitive load **no bajó** para los stream-aligned (siguen eligiendo todo). Puede incluso haber subido (ahora deben decidir *si* seguir el ADR o no).
- El platform team gasta ciclos en "evangelismo" (quejas en Slack, "¿pero por qué no lo siguen?") que no mueve la aguja.
- Riesgo de fatiga: en 6–12 meses, los 32 ADRs se vuelven ruido y nadie los lee.

**Movimiento correctivo en 90 días:**

1. **Elegir 1 ADR**, el más doloroso para los stream-aligned (encuesta rápida), y convertirlo en **golden path accionable** vía template Backstage: un stream-aligned puede adoptarlo con 1 comando.
2. **Nombrar un cliente alfa** entre los stream-aligned (el equipo más receptivo) y co-diseñar el golden path con ellos durante 4 semanas.
3. **Cambiar las métricas públicas**: pasar de "ADRs publicados / cobertura de linting" a "**adopción voluntaria del golden path**" + "**platform NPS**".
4. **Deprecar silenciosamente** 20 de los 32 ADRs (los que no tienen cliente). Los 12 restantes se repriorizan por demanda real.
5. Instituir **discovery continuo**: entrevistas trimestrales con cada stream-aligned (30 min, agenda abierta).

**Métrica de éxito a los 90 días:** adopción voluntaria del golden path piloto > 50 % entre los stream-aligned relevantes; platform NPS medido por primera vez con baseline documentada.

---

## Situación 2 — BetaCorp: 250 tickets/mes al platform team

**Antipattern dominante:** **ticketing-driven ops**.

**Causa raíz:** el platform team actúa como **intermediario humano** en todas las decisiones de infra. En lugar de productizar lo repetitivo (crear namespace, abrir puerto, rotar secret), lo trata como *ops manual* por "defensa en profundidad". El argumento "si no revisamos, se les escapa cualquier cosa" **confunde revisión humana con política automatizada**.

**Daño concreto:**

- Lead-time medio de cambio trivial = 3 días → DORA deployment frequency estancada y change failure rate inflada (los equipos "empaquetan" cambios para evitar la cola, lo que infla los deploys).
- 6 ingenieros atrapados haciendo tickets → **cero progreso en el IDP real**.
- Cognitive load no baja: los stream-aligned siguen teniendo que entender todo porque todavía escriben las especificaciones del ticket.
- Shadow IT inminente: equipos empiezan a mantener su propio cluster lateral o scripts clandestinos para no esperar.
- Platform NPS en caída libre (si se midiera; probablemente no se mide).

**Movimiento correctivo en 90 días:**

1. **Clasificar los 250 tickets/mes** por tipo durante 1 sprint: identificar los 5 tipos que suman el 80 %.
2. Para los **2 tipos más frecuentes** (típicamente "crear namespace" y "abrir puerto"), construir **capability self-service** con política automatizada (OPA/Kyverno) + logging para auditoría — sin review humana para los casos de bajo riesgo.
3. Introducir una **ladder de riesgo**: tier 1 auto-aprobado (90 % de los casos), tier 2 con policy automática (8 %), tier 3 con review humana acotada (2 %). **La policy sustituye la review manual**, no la elimina del todo.
4. **Objetivo público**: bajar tickets manuales de 250/mes a < 50/mes en 90 días.
5. Comunicar el cambio con un **"platform catalog"** público: qué puede un stream pedir self-service hoy, qué puede pedir vía ticket, qué está en roadmap.

**Métrica de éxito a los 90 días:** tickets manuales < 100/mes (tendencia a la baja clara) y lead-time del "trámite trivial" < 1 día (vs 3 días hoy).

---

## Situación 3 — GammaCorp: platform como cementerio

**Antipattern dominante:** **platform as a dumping ground**.

**Causa raíz:** el platform team aceptó, uno por uno, cualquier sistema sin owner — Jenkins viejo, Nexus 2015, PHP sin owner original, 4 warehouses. Nunca definió **product boundaries** explícitas ("qué entra, qué no, con qué criterio"). El resultado: 65 % del tiempo en legacy, 35 % en lo nuevo → el IDP nunca madura.

**Daño concreto:**

- Capacidad para construir lo nuevo = 35 % del equipo → el IDP se arrastra, no se termina.
- Burnout del equipo (mantenimiento legacy sin propósito claro, sin visibilidad hacia arriba).
- Riesgo de incidentes alto (sistemas sin owner original, docs stale, dependencias oscuras).
- Retention en el equipo cae — nadie se une a "plataforma" para mantener Jenkins 2015.
- Oportunidad coste: cada mes de retraso del IDP cuesta ~N horas/semana al resto de la organización.

**Movimiento correctivo en 90 días:**

1. **Definir product boundaries** explícitas (1 página): qué sistemas son "parte del producto plataforma" y qué no. Publicar.
2. Para cada sistema **fuera** de boundaries, decidir: *deprecar* (plan a 6 meses con comunicación por fases), *traspasar a su stream-aligned natural* (si existe), o *crear complicated-subsystem team* si justifica expertise escasa (raro).
3. **Deprecar el Jenkins viejo** (los 3 equipos que lo usan migran al CI del IDP en 90 días con soporte explícito del platform team — es un engagement puntual, no permanente).
4. **Traspasar "notifications PHP"** a quien más lo use (si nadie lo quiere, se congela y se deprecia en 6 meses).
5. **Negociar formalmente** con leadership la asignación de tiempo: 70 % IDP nuevo, 30 % mantenimiento legacy durante el período de salida (vs 35/65 actual).

**Métrica de éxito a los 90 días:** tiempo del equipo en legacy baja de 65 % → < 45 % con plan de deprecation firmado para 2 de los 4 sistemas legacy.

---

## Situación 4 — DeltaCorp: enabling team eterno

**Antipattern dominante:** **enabling team eterno**.

**Causa raíz:** el engagement con Checkout nunca tuvo un **contrato de salida medible**. El manager del enabling confundió "cobertura" (estar presente) con "capacidad traspasada" (que el equipo opere solo). El resultado: Observability Enabling se volvió, de facto, un **sub-equipo permanente** de Checkout; los otros streams siguen esperando.

**Daño concreto:**

- Checkout **no sabe operar su propia observabilidad** → dependencia estructural, no autonomía. Si Observ. Enabling desaparece, Checkout queda ciego.
- Catalog y Pricing llevan 18 meses sin OTel maduro → riesgo operativo + sin SLOs → DORA MTTR peor en esos streams.
- Observability Enabling, con el cuello de botella de ser 1 equipo para N streams, va a quemarse.
- Oportunidad coste: 18 meses de OTel/SLOs no adoptados en los otros streams.

**Movimiento correctivo en 90 días:**

1. **Negociar criterio de salida medible** con Checkout: durante 1 mes, el equipo opera sus propios SLOs e investiga sus incidentes **sin PRs del enabling**. Objetivo: 100 % de las PRs de instrumentación nuevas vienen del propio Checkout.
2. **Documentar** lo que el enabling hoy hace para Checkout (dashboards, runbooks, decisiones) en un "operating manual" que Checkout hereda.
3. **Shadow period** (4 semanas): el enabling observa, no actúa. Al final, salida formal.
4. **Rotación a Catalog**: engagement nuevo con contrato de salida escrito desde el día 1 (criterio: Catalog opera sus propios SLOs en 10 semanas).
5. **Métrica pública**: nº de streams con observabilidad propia **operada por el stream** (vs operada por enabling). Hoy = 0; objetivo 90 días = 1 (Checkout saliendo); objetivo 180 días = 2 (Catalog saliendo).

**Métrica de éxito a los 90 días:** Checkout cerró 1 incidente sin involucrar al enabling + 0 PRs de instrumentación del enabling en Checkout en el último mes.

---

## Síntesis

**Por qué un "platform ticket queue" degrada la propuesta de valor:**

Un platform team existe para **bajar cognitive load extraneous** de los stream-aligned, ofreciendo capabilities **as-a-service** con contrato claro. Cuando esas capabilities se convierten en una cola de tickets manuales, el platform team se vuelve **cuello de botella humano**: inserta latencia (días en lugar de minutos), consume ciclos del platform team que no construyen producto, y **no reduce** la cognitive load (los stream-aligned siguen teniendo que entender todo para redactar el ticket correctamente). El resultado agregado es DORA peor, platform NPS en caída, shadow IT emergente, y una plataforma que se mide por "tickets cerrados" en lugar de "autonomía habilitada" — la métrica equivocada. Un ticket es un **debug de self-service ausente**, no un entregable del platform team.

**6 criterios para distinguir un platform team sano de un antipattern:**

1. ¿Puede un stream-aligned onboarding un servicio nuevo **sin abrir un ticket** al platform team?
2. ¿Las métricas públicas del platform team incluyen **adopción voluntaria** o **platform NPS**, además de métricas de infra (uptime)?
3. ¿El platform team tiene un **cliente alfa identificado** y conversa con él al menos trimestralmente?
4. ¿La proporción tickets manuales / self-service **baja** mes a mes?
5. ¿Los enabling teams tienen **contrato de salida escrito** por cada engagement, con criterio medible?
6. ¿Hay **product boundaries explícitas** publicadas (qué es parte del producto plataforma y qué no)?

## Punto a repetir hasta que suene aburrido

> Un platform team se mide por **cuánta autonomía habilita en los demás**, no por cuántos tickets cierra ni cuántos ADRs publica. Si tus métricas públicas no reflejan autonomía habilitada, mides lo equivocado.
