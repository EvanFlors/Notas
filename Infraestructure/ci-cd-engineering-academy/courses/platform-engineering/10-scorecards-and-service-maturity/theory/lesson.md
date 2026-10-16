# Lección — Scorecards y madurez de servicios

> Este documento es la base conceptual del módulo `plat-10`. Léelo entero antes de hacer las actividades; los ejemplos y actividades asumen que ya conoces el vocabulario.

## 1. Por qué existen los scorecards

Sin scorecards, cualquier conversación sobre "¿estamos mejorando?" termina en anécdotas. *"El equipo de pagos tiene SLOs; creo."* *"Checkout tenía runbook, pero no sé si está al día."* *"Casi todo está en CI, menos quizá dos servicios."* Esa niebla es la que hace imposible invertir en los **servicios correctos** y defender a la plataforma delante de dirección.

Un **scorecard** es una lista corta y auditable de chequeos aplicados **al catálogo**. Para cada servicio responde dos preguntas:

1. **¿Dónde está hoy?** → qué chequeos pasa y cuáles no.
2. **¿Dónde debería estar?** → en qué **nivel de madurez** encaja hoy y qué le falta para subir al siguiente.

La respuesta agregada se publica como **adopción**: *"74 % de los servicios están en silver o superior."* Eso sí se puede defender, discutir y presupuestar.

El antipatrón contrario — y el que sale "gratis" si no hay cuidado — es un dashboard con **cincuenta** indicadores por servicio, cada uno con su color, su peso y su explicación. Nadie lo lee. La métrica deja de orientar y se vuelve ruido.

## 2. Fact collectors vs checks vs score

El modelo mental que establece **Backstage TechInsights** (y que replican en gran parte **OpsLevel** y **Cortex**) separa tres cosas que suelen mezclarse:

1. **Fact collector** — una pieza que **lee hechos** de un sistema externo y los deja normalizados en una base local. Ejemplos: *"¿este servicio tiene un `OnCallRotation` registrado en PagerDuty?"*, *"¿cuántos CVEs críticos reporta Trivy sobre su imagen?"*, *"¿cuándo fue el último deploy exitoso?"*. Un fact es **un dato**, nunca una opinión.
2. **Check** — una **regla booleana** o escalonada sobre uno o más facts. Ejemplo: *"tiene owner válido"*, *"CVEs críticos == 0"*, *"deploys en los últimos 90 días ≥ 1"*. Un check es **una opinión barata de cambiar**.
3. **Score / nivel** — una **agregación** de checks ponderados que produce un número (0–100) o una etiqueta (bronze/silver/gold).

La separación es importante porque te permite **cambiar las reglas sin cambiar los datos**. Si mañana decides que el umbral de CVEs críticos es *< 3* en vez de *== 0*, cambias el check, no el collector. Si decides que la *deploy frequency* ya no cuenta para gold porque induce gaming, la quitas del score sin perder el dato subyacente.

En este módulo trabajamos sobre todo con **checks y score**. Los facts los simularemos como JSON del catálogo (ver `activities/01-scorecard-for-capstone/starter/catalog/`).

## 3. Qué chequeos poner (y cuáles no)

El error típico, el más caro de corregir, es poner **demasiados chequeos**. Un equipo con energía puede llegar fácilmente a 40; en 6 meses nadie los mantiene y el score se vuelve folclore.

La regla que mejor envejece: **empieza con 5 a 8 chequeos**. Puedes añadir uno nuevo si matas uno viejo. Nunca superas la decena en producción. Cada chequeo adicional **compite** por atención con los demás.

Un buen chequeo cumple cuatro propiedades:

- **Mide resultado, no actividad.** *"Tiene SLO publicado"* mide un resultado; *"abrió un ticket de SLO"* mide actividad.
- **Es automático.** Si requiere que un humano actualice un YAML a mano, degrada en semanas.
- **Es defendible delante del equipo evaluado.** Si no puedes explicar en una frase por qué importa, lo gamificarán.
- **No se solapa con otro.** Dos chequeos que miden lo mismo dan peso doble al mismo tema.

Un panel inicial razonable para un servicio de producción:

| # | Chequeo | Por qué |
|---|---------|---------|
| 1 | Tiene **owner** vivo en el catálogo | Sin dueño no hay a quién avisar. |
| 2 | Tiene **SLO** publicado | Es el único contrato operativo real. |
| 3 | Tiene **runbook** enlazado | Sin él, los on-call improvisan. |
| 4 | Tiene **on-call rotation** activa | Dependencia de una sola persona = incidente a tiempo. |
| 5 | **Imagen firmada** (p. ej. cosign) | Base para supply chain. |
| 6 | **Sin CVEs críticos** | Umbral objetivo. |
| 7 | **Deployed en los últimos 90 días** | Un servicio sin deploys recientes es un riesgo (drift, dependencias). |
| 8 | **Namespace con PSA restricted** | Postura mínima de aislamiento. |

Si no puedes defender uno de ellos, quítalo. No hay premio por tener los 8 desde el día 1.

Chequeos que suelen **inducir gaming** y conviene evitar: *"PR coverage > 80 %"* (se infla con tests triviales), *"número de deploys / semana"* (se infla con bump de versión en loop), *"número de docs"* (se infla con placeholders).

## 4. Niveles de madurez: bronze / silver / gold

El scorecard puro (porcentaje) es útil para la plataforma pero **frío** para los equipos. La metáfora de **niveles** (bronze/silver/gold, o L1/L2/L3) les da un *camino*: *"Me falta esto y esto para subir."*

La definición más honesta:

- **Bronze:** el servicio **existe en condiciones mínimas de operabilidad**. Tiene owner, puede recibir un deploy, está en el catálogo.
- **Silver:** el servicio **puede operar en producción con un on-call razonable**. Tiene SLO, runbook, on-call, imagen firmada.
- **Gold:** el servicio **mejora la postura global de la plataforma**. Sin CVEs críticos, deploy reciente, PSA restricted, con dashboards publicados y evidencia de ejercicios de caos / DR.

Dos reglas que previenen abuso:

1. **No se "pondera" para pasar.** Un servicio en gold **cumple todos los chequeos de gold**, no "la mayoría". Esto evita que un servicio llegue a gold ignorando security porque tiene buena documentación.
2. **El nivel no es social.** Nunca se publica un ranking público entre equipos. Se publica la **adopción agregada** (ver §5).

## 5. Adopción como KPI de la plataforma

El scorecard no es solo para que los equipos de producto se midan a sí mismos — es, sobre todo, un KPI **de la plataforma**. La plataforma existe para que **sea fácil** llegar a silver y gold. Si no lo es, el fallo es de la plataforma, no de los equipos.

La métrica canónica es:

- **% servicios ≥ bronze** (operabilidad mínima)
- **% servicios ≥ silver** (producción razonable)
- **% servicios ≥ gold** (postura madura)

Y se grafica en el tiempo. Un buen año en platform looks like: *"pasamos de 40 % silver a 72 %"*.

Qué **no** se publica nunca:

- Rankings "top 10 peores servicios".
- Rankings de equipos (*"Pagos: 85 %, Checkout: 64 %"*).
- Scorecards por persona.

Esos cortes convierten el scorecard en una herramienta de *shaming* y matan la cooperación.

## 6. Escalation path: el *carrot*, no el *stick*

Un scorecard sin un camino claro para subir de nivel es un reproche. El diseño mínimo tiene dos cosas:

1. **Documentación por chequeo**: cada chequeo tiene una página que explica (a) por qué importa, (b) cómo cumplirlo, (c) a quién pedir ayuda. Si no tiene esta página, el chequeo todavía no debería estar vivo.
2. **Un equipo responsable del escalation**: cuando un equipo no sabe cómo subir de bronze a silver, hay una ruta clara (Slack channel, office hours, "golden path" del plat-02). La plataforma **ayuda a subir**, no solo contabiliza.

El indicador de salud del escalation path es: *"¿cuánto tarda, en mediana, un servicio en subir un nivel desde que llega a plataforma?"*. Si tardan 9 meses, la plataforma tiene un problema de usabilidad, no los equipos.

## 7. Integración con la Production Readiness Review (PRR)

La **PRR** es la conversación formal antes de poner un servicio en producción. El scorecard **alimenta** la PRR pero **no la reemplaza**. La diferencia:

- El **scorecard** se evalúa continuamente, automático, sobre el catálogo.
- La **PRR** se hace una vez (o cada N meses) con un humano al otro lado y responde preguntas que **no se automatizan**: *"¿qué pasa si tu DB cae?"*, *"¿cómo rollback?"*, *"¿qué dependencias externas son críticas?"*.

Patrón recomendado:

- La **sección 1 de la PRR** cita el score actual: *"este servicio está en silver, con los siguientes 2 chequeos pendientes"*.
- La **sección 2–N** cubre lo cualitativo: dependencias, modos de fallo, plan de capacidad, ownership on-call.
- La PRR no se "pasa"; se **completa** y se archiva (es evidencia histórica). El bloqueo para producción, si existe, es un chequeo del **scorecard**, no una firma humana.

Esto evita el peor antipatrón: una PRR de 40 páginas que nadie lee y que se repite palabra por palabra cada vez.

## 8. Antipatrones

Resumen de los que ya se han mencionado, para memorizar:

1. **40 chequeos.** Nadie los mantiene; el score pierde señal.
2. **Peso ponderado opaco** (`check A * 0.7 + check B * 0.1 + ...`). Nadie entiende por qué subió o bajó el número.
3. **Ranking público entre equipos.** Convierte al scorecard en *stick* y mata cooperación.
4. **Chequeos sin página de ayuda.** El equipo no sabe cómo cumplir y lo ignora.
5. **Chequeos de actividad disfrazados de resultado** (*"commits/semana"*). Se gamifican.
6. **Scorecard separado del catálogo.** Un YAML a mano que se desactualiza. El scorecard **debe** leer del catálogo autoritativo.
7. **PRR de 40 páginas** que repite lo que el scorecard ya mide.
8. **"Todo el mundo gold".** Si todos están en gold, el scorecard no distingue; probablemente los chequeos son demasiado laxos.

## 9. TechInsights / Soundcheck / OpsLevel / Cortex

- **Backstage TechInsights (open source)** — plugin oficial de Backstage. Modelo *fact + check + score*. Requiere escribir fact collectors en TypeScript y persistirlos en una DB (el backend lo trae Backstage). Tiene UI nativa en la página de cada entidad del catálogo.
- **Backstage Soundcheck (SaaS, Spotify)** — alternativa comercial de Spotify, construida sobre Backstage, con más batería incluida (campañas, exenciones, workflows de aprobación).
- **OpsLevel / Cortex** — productos SaaS **independientes de Backstage**. Instalan integraciones con GitHub/GitLab, PagerDuty, Datadog, Snyk y publican su propio catálogo. Útiles cuando no quieres operar Backstage.

Para este módulo, el modelo mental es idéntico en los cuatro: *fact → check → score*. Lo que cambia es dónde vive el runtime y quién paga.

## 10. Cómo evitar que se gamifique

Más allá de los antipatrones puntuales, hay tres principios estructurales:

1. **No publiques el score como número absoluto si puedes evitarlo.** Publica **tendencia** y **gap al siguiente nivel**. "Te faltan 2 chequeos para silver" es accionable; "tienes 73 %" invita a hacer trampas para llegar a 80 %.
2. **Audita periódicamente los chequeos.** Cada trimestre: ¿este chequeo sigue correlando con incidentes evitados? Si no, bórralo.
3. **Celebra bajadas de nivel honestas.** Si un equipo baja de gold a silver porque fue honesto reportando algo, protégelo públicamente. Si lo castigas, el próximo lo esconderá.

## 11. Cuándo *no* montar scorecards

Son costosos. Antes de montarlos, pregunta:

- ¿Tienes catálogo autoritativo? Sin catálogo, no hay sujeto a evaluar.
- ¿Tienes al menos 20 servicios? Con 5 servicios una hoja de cálculo basta.
- ¿Tienes alguien que **mantenga** los chequeos? Un scorecard muerto es peor que no tener uno.
- ¿Hay apetito de la organización por adopción como KPI? Si lo vas a montar y la dirección va a seguir midiendo por *features entregadas*, no vas a mover la aguja.

Si falta cualquiera de los cuatro, pospón. Esto es parte de "no construir plataforma por construir plataforma".

## 12. Lo que te llevas

- Un **scorecard = fact + check + score**, y la separación importa.
- **5–8** chequeos, no 50.
- **Bronze/silver/gold** como camino, no como clasificación social.
- **Adopción** como KPI de plataforma; sin ranking entre equipos.
- **Escalation path** como parte del diseño.
- La **PRR** cita al scorecard; no se repiten.
- Audita trimestralmente; borra chequeos que ya no correlan con incidentes.

En las actividades vas a aplicar esto a tu capstone (`01-scorecard-for-capstone`) y a redactar la PRR que lo cite (`02-production-readiness-review-template`).
