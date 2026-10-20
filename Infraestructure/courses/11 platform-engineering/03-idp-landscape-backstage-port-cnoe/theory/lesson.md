# plat-03 — Lección: panorama IDP (Backstage, Port, CNOE y vecinos)

> 10 secciones. 100 % conceptual y comparativo. Prerrequisitos: `plat-01` y `plat-02`.

---

## 1. Punto de partida: por qué existe este mercado

En `plat-01` quedó claro que un **platform team** entrega su valor como *X-as-a-Service*. En `plat-02` definimos **golden paths** opinionados que reducen la carga cognitiva de los equipos de producto. La pregunta inevitable es: **¿cómo se materializa eso en una interfaz?**

La respuesta común se llama hoy **Internal Developer Platform (IDP)**: un conjunto de capacidades que se presentan a los developers como una **experiencia unificada** — típicamente un portal web — y que esconden la complejidad del *underlying* (K8s, cloud, CI/CD, observabilidad, secretos).

El mercado explotó entre 2020 y 2024 porque:

1. **Spotify liberó Backstage** (2020) como OSS y lo donó a la CNCF. De la noche a la mañana, "construir tu propio IDP" dejó de implicar empezar de cero.
2. **Los vendors SaaS** (Port, OpsLevel, Cortex, Humanitec) olieron la oportunidad y empaquetaron "lo mismo" sin requerir ingeniería interna fuerte.
3. **La CNCF** publicó la **reference stack CNOE** para dar un *starter kit* opinionado basado en proyectos CNCF (Backstage + Argo CD + Crossplane + Keycloak + Argo Workflows).

Resultado: hoy un *platform engineer* enfrenta una decisión que **hace 4 años no existía**. Mal tomada, cuesta meses de ingeniería malgastada.

> **Idea clave que repetiremos:** una herramienta IDP **no es** Platform Engineering. Es un *multiplicador* de una disciplina que debe existir con o sin ella. Si no tienes golden paths, un IDP vacío es un wiki tipado caro.

---

## 2. Los tres grandes modelos de distribución

Antes de nombrar productos, hay que fijar el eje **modelo de distribución**, porque de él se deriva casi todo lo demás (costo, equipo, extensibilidad, time-to-value).

### 2.1 Framework open-source auto-hospedado — "construir"

**Ejemplo canónico:** **Backstage**.

- Te dan un **generador de proyecto** (`@backstage/create-app`); el output es *tu propia aplicación Node/TS* que **tú** mantienes, versionas, despliegas y actualizas.
- La **mayoría del valor vive en plugins** (oficiales + comunidad + custom). El core es relativamente delgado.
- **Pro:** máxima flexibilidad y extensibilidad, sin lock-in de vendor, roadmap transparente de la CNCF.
- **Contra:** necesitas al menos **2–3 ingenieros con Node/TS** sostenidos. Los *breaking changes* del Backend System 1.0 (y otros) requieren disciplina de upgrade; ignorarlos acaba en una fork técnica no mantenida.

### 2.2 SaaS configurable — "configurar"

**Ejemplos:** **Port**, **OpsLevel**, **Cortex**.

- Levantas una cuenta, configuras entidades y relaciones vía UI o YAML, enchufas integraciones (GitHub, Argo CD, PagerDuty, Datadog) y en días tienes un portal usable.
- **Pro:** time-to-first-value corto (**días a 2 semanas**), sin carga de operación del portal, soporte comercial.
- **Contra:** **costo recurrente** (típicamente per-developer-per-month); extensibilidad acotada al modelo del vendor; algún grado de lock-in de datos y de flujos.

### 2.3 Reference stack preensamblada — "desplegar"

**Ejemplo canónico:** **CNOE** (Cloud Native Operational Excellence, iniciativa CNCF).

- CNOE **no es un producto**. Es un **conjunto de recomendaciones + manifests + scripts** que ensamblan proyectos CNCF existentes (Backstage, Argo CD, Crossplane, Keycloak, Argo Workflows, External Secrets) en una stack coherente.
- **Pro:** parte de un "golden path para construir el golden path" — evita las decisiones triviales (auth con Keycloak, GitOps con Argo CD, infra con Crossplane).
- **Contra:** sigues siendo **tú** quien opera cada pieza; no es un producto SaaS. La curva es alta si no vienes del mundo CNCF.

### 2.4 Platform orchestrator opinionado — categoría aparte

**Ejemplo:** **Humanitec**.

- Introduce un **workload spec abstracto** (**Score**) que developers escriben, y el orquestador materializa el workload en el entorno (K8s + cloud + secretos + redes) según políticas de plataforma.
- Es ortogonal a los tres anteriores: puede convivir con Backstage/Port como *backend de provisioning* mientras el portal es otro.

---

## 3. Backstage: el *de facto* y sus trampas

Backstage es **el estándar OSS** por adopción. Esto crea un sesgo peligroso: *"vamos con Backstage porque todos van con Backstage"*.

Lo que tienes al adoptar Backstage:

- **Catálogo de software** (entidades `Component`, `API`, `Resource`, `System`, `Domain`, `User`, `Group`).
- **Software templates (Scaffolder)**: formularios → acciones → repo creado.
- **TechDocs**: docs-as-code renderizados en el portal.
- **Plugin framework** rico (K8s, Argo CD, GitHub Actions, PagerDuty, Grafana, Sonar, Snyk…).
- **Auth providers**: GitHub, Google, Okta, LDAP, OIDC, guest.

Lo que **también** firmas (letras pequeñas):

- Es un **framework**, no una app: la aplicación resultante es *tuya*. Tus `packages/app` y `packages/backend` evolucionan independientes del upstream.
- **Breaking changes recurrentes.** El upgrade de Backend System (de 0.x a 1.0) marcó un patrón distinto para plugins backend; muchas organizaciones se quedaron en versiones viejas y pagaron deuda técnica.
- Postgres recomendado para producción (SQLite solo dev).
- **La curva de los plugins custom** es real: TypeScript + React + el modelo de providers/APIs internas de Backstage.
- **CNOE** existe en gran parte **para resolver el `day-2` de Backstage**: integra Backstage con Argo CD, Keycloak y Crossplane de forma pre-ensamblada, para que no reinventes esas conexiones.

Trampa típica: elegir Backstage, no asignar equipo dedicado, y 9 meses después tener un portal con catálogo stale y 0 templates productivos. **Backstage sin ownership es un fork técnico.**

---

## 4. Port: time-to-value corto, menos ingeniería

Port es la **anti-tesis económica** de Backstage.

- Modelo **SaaS**. No se operan servidores; se configuran *blueprints* (entidades), *actions* (templates), *scorecards* (checks de madurez).
- **Pricing per-developer-per-month** (consultar vigente); el costo escala con la organización.
- **Time-to-first-value: horas a días.** Es común tener un portal con 50+ servicios catalogados en una semana.
- **Extensibilidad acotada**: se extiende vía webhooks, GitOps-style blueprints y una API REST. **No** se escriben plugins TypeScript; se compone con el modelo que ellos dan.

Encaja bien cuando:

- La organización **no tiene** un equipo plataforma con bandwidth para operar un framework.
- Se quiere empezar en semanas, aprender y después *potencialmente* migrar.
- El presupuesto permite el modelo per-dev y hay compromiso con un vendor.

No encaja bien cuando:

- Se necesita extender el portal con lógica muy específica (plugin propio pesado).
- Compliance exige self-hosted estricto.
- La organización ya tiene inversión fuerte en el ecosistema OSS/CNCF.

Un patrón visto en la práctica: **arrancar con Port para validar la hipótesis del portal interno, y a los 12 meses evaluar migración a Backstage** si el equipo plataforma creció y el costo per-dev duele. La inversión en modelado del catálogo se traslada; la inversión en UI custom no.

---

## 5. OpsLevel y Cortex: scorecards-first

**OpsLevel** y **Cortex** son dos SaaS con una filosofía distinta: *"el portal es secundario; el valor principal son los **scorecards** y la gestión de **service maturity**"*.

- Modelan el catálogo (servicios, owners, dependencias) **con menos énfasis en UI de developer** y **mucho énfasis en vistas de managers/arquitectos**: *"¿qué servicios no tienen owner?"*, *"¿cuáles están en bronze y nunca pasarán a silver?"*.
- Encajan en organizaciones **medianas-grandes** donde la pregunta urgente es "¿cómo elevo la madurez promedio?" más que "¿cómo acelero el time-to-first-commit?".
- Scorecards nativos ricos (profundizado en `plat-10`): checks sobre ownership, SLOs, runbooks, imagen firmada, deploy frequency, PSA restricted, etc.
- **Pro:** valor rápido para engineering leadership; menos ingeniería interna.
- **Contra:** menor extensibilidad; el día que quieres un plugin tipo *Backstage K8s plugin* embebido, cuesta más.

Nota: Backstage tiene **TechInsights/Soundcheck** (plugins) para scorecards, y Port también los soporta nativamente. La diferencia es de **énfasis del producto**, no de capacidad binaria.

---

## 6. Humanitec: workload spec como contrato

**Humanitec** no compite directamente con Backstage/Port como *portal*. Compite como **platform orchestrator**:

- Los developers escriben un archivo **Score** (`score.yaml`) describiendo *qué* workload necesitan (containers, variables, dependencias de recursos abstractos: `postgres`, `s3`, `redis`).
- Humanitec **traduce** ese spec al entorno concreto (K8s + cloud + secretos + redes) según políticas que el platform team configura.
- Score es open-source y vive en la [Score Spec](https://score.dev/); Humanitec es la implementación comercial.

Dónde brilla:

- Organizaciones con **muchos entornos** (dev/stg/prod/ephemeral) donde la deriva entre ellos es dolorosa.
- Equipos que quieren **estandarizar el contrato de workload** sin inventarlo.

Dónde no:

- Si tu valor principal es el portal/catálogo (ahí es Backstage/Port).
- Si la curva de aprendizaje de "otro YAML spec" no se amortiza con el beneficio.

Puede **convivir** con Backstage: el template Backstage genera un `score.yaml`, Humanitec lo materializa. En ese combo cada herramienta cubre su mitad.

---

## 7. CNOE: la reference stack CNCF

**CNOE** = *Cloud Native Operational Excellence*. Iniciativa impulsada por grandes usuarios (Adobe, Twilio, AT&T) y la CNCF para publicar una **referencia opinionada** de IDP construido con proyectos CNCF.

Composición típica de la stack:

```
┌──────────────────────────────────────────────────────────────┐
│                        Developer                             │
│          │                                 │                 │
│          ▼                                 ▼                 │
│     ┌──────────┐                     ┌───────────┐           │
│     │ Backstage│                     │   kubectl │ (opcional)│
│     │ (portal, │                     └───────────┘           │
│     │ catalog, │                                             │
│     │ templates│                                             │
│     └────┬─────┘                                             │
│          │ auth (Keycloak OIDC)                              │
│          ▼                                                   │
│     ┌──────────┐    ┌──────────────┐    ┌──────────────┐    │
│     │ Argo CD  │ ──▶│  Crossplane  │ ──▶│   Cloud/K8s  │    │
│     │ (GitOps  │    │  (self-serv  │    │  (AWS/GCP/   │    │
│     │  deploys)│    │   infra:XRDs)│    │   on-prem)   │    │
│     └────┬─────┘    └──────────────┘    └──────────────┘    │
│          │                                                   │
│          │ workflows (opcional)                              │
│          ▼                                                   │
│     ┌─────────────┐                                          │
│     │Argo Workflows│                                         │
│     └─────────────┘                                          │
└──────────────────────────────────────────────────────────────┘
```

Lo que CNOE resuelve que **Backstage solo no**: la conexión entre portal, auth, GitOps y provisioning de infra. En un Backstage *vanilla* tú decides cómo integrar auth (Keycloak? Google? Okta?), cómo deployas lo que el scaffolder genera (Argo CD? GitHub Actions? Flux?) y cómo expones recursos cloud (Crossplane? Terraform via Atlantis?). **CNOE opina**: Keycloak + Argo CD + Crossplane + Argo Workflows.

Cuándo tiene sentido CNOE:

- Organización **CNCF-first** o K8s-nativa que ya opera varios de esos componentes.
- Equipo plataforma que quiere **empezar desde una referencia opinionada** en lugar de tomar 10 decisiones triviales.
- Se busca una stack **100 % OSS** por razones de compliance, costo o filosofía.

Cuándo **no**:

- Equipo pequeño sin experiencia operando esos componentes individualmente. CNOE no reduce la carga de operación — la *organiza*.
- Organizaciones sin inversión en K8s/Crossplane donde el valor marginal de "self-service DB vía XRD" no justifica la curva.

---

## 8. Criterios de elección (y cómo ponderarlos)

El error típico es comparar herramientas **feature a feature**. Las dimensiones que **realmente** deciden suelen ser otras:

| Dimensión | Pregunta operativa | Peso típico |
|-----------|--------------------|-------------|
| **Tamaño del platform team** | ¿Tengo 1–2, 3–5, 6+ ingenieros sostenidos dedicados a la plataforma? | Alto |
| **Expertise interna** | ¿Hay dominio de Node/TS? ¿De K8s/CNCF? ¿De TF? | Alto |
| **Presupuesto** | ¿Puedo justificar $X per-dev/mes para 300 devs? ¿O prefiero capex en ingeniería interna? | Alto |
| **Time-to-first-value exigido** | ¿Tengo 2 semanas o 12 meses para mostrar valor? | Alto |
| **Grado de opinión deseado** | ¿Quiero que la herramienta me diga cómo hacerlo o quiero libertad total? | Medio |
| **Extensibilidad futura** | ¿Preveo necesitar plugins muy custom en 12–24 meses? | Medio |
| **Compliance / self-hosted** | ¿Puedo usar SaaS o debo self-host por regulación? | Alto si aplica |
| **Lock-in** | ¿Qué tan reversible es la decisión si cambio en 2 años? | Medio-alto |
| **Adopción interna** | ¿Qué prefieren los devs? ¿Cuán alineados están los engineering leads? | Alto |
| **Hiring** | ¿Encuentro gente con experiencia en X en mi mercado laboral? | Medio |

Dos reglas empíricas:

1. **Si el platform team es < 3 ingenieros, descarta Backstage self-hosted puro.** El overhead de mantener la app, upgradar plugins y responder issues internos es un trabajo de 1 persona dedicada como mínimo. Usa Port, OpsLevel o CNOE (si CNCF-literate).
2. **Si tu diferenciador es la DX y vas a invertir mucho en plugins custom, descarta Port.** La extensibilidad acotada acaba doliendo.

---

## 9. Antipatrones comunes al elegir

- **"Backstage por default porque es lo que usa Spotify."** Tu organización no es Spotify. Mide tu contexto, no el de ellos.
- **"Compramos Port y problem solved."** Un IDP no reemplaza la ausencia de golden paths. Si no sabes qué quieres ofrecer, el portal estará vacío.
- **"Hagamos un PoC con las 6 herramientas en paralelo."** Pérdida de tiempo. Elimina a 4 con criterios de peso (tamaño equipo, presupuesto, self-hosted) y haz PoC a 2.
- **"Esto es decisión del CTO, no mía."** Falso. La elección determina en qué invierte el equipo plataforma los próximos 24 meses. Es decisión de ingeniería **informada** por el negocio.
- **"Elegimos lo más barato."** El TCO incluye ingeniería interna. Un Backstage "gratis" con 2 ingenieros dedicados cuesta más que muchos SaaS.
- **"Esperemos al IDP perfecto."** No existe. Cada herramienta tiene trade-offs; elegir mal es mejor que no elegir, si la decisión es reversible.
- **"Vamos a soportar las 3 porque los equipos quieren libertad."** Fragmentación garantizada. Un portal por organización, o ninguno.

---

## 10. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Nombrar las **6 herramientas** (Backstage, Port, OpsLevel, Cortex, Humanitec, CNOE) y su propuesta de valor en una frase.
- Clasificarlas por **modelo de distribución** (framework / SaaS / reference stack / orchestrator).
- Dado un contexto organizacional, **descartar 4 y proponer 2 finalistas** con criterios de peso.
- Redactar un **ADR** defendible frente a un vendor que presiona por "todas las features".
- Diseñar una **matriz PoC** con criterios ponderados que un lead ejecute en 2–4 semanas.

Lo que **sigue**:

- `plat-04` — Backstage de verdad: `create-app`, estructura de packages, Postgres, auth GitHub.
- `plat-05` — Catálogo profundo: entity model, providers, annotations.
- `plat-06` — Templates y Scaffolder.
- `plat-07`–`plat-09` — TechDocs, plugins, self-service infra con Crossplane.

Una síntesis final de una línea:

> **Elegir un IDP es elegir una curva de inversión**: Backstage invierte en ingeniería propia, Port invierte en subscripción recurrente, CNOE invierte en expertise CNCF. Ninguna elige por ti la disciplina de Platform Engineering.
