# plat-12 — Lección: gobernanza a escala, multi-tenancy, deprecations y platform SLOs

> 12 secciones. Mayoritariamente conceptual. Prerrequisito: `plat-09`, `plat-10`, `plat-11`.

---

## 1. El problema: la plataforma que crece sin plan

Cuando una plataforma interna tiene éxito, al final del año dos aparecen —en el mismo mes— tres fuerzas que la pondrán a prueba:

1. **Multiplicación de tenants.** De 8 equipos y 30 servicios al principio, pasas a 20 equipos y 200 servicios. Lo que al principio cabía en un namespace y una cuenta cloud ya **no cabe** sin trampas (quotas que se gritan, blast radius que crece, costes que no se pueden asignar).
2. **Peso de lo construido.** El primer *template*, la primera XRD, la primera versión del catalog. Están **vivos en producción** y evolucionaron sin plan de versionado. Querer tocarlos es tocar un cable con corriente.
3. **La propia plataforma es un sistema de producción.** Si Backstage se cae, 20 equipos no pueden auto-servirse. Si el scaffolder tarda 90 s, es inusable. Si el catalog está desincronizado, los dashboards mienten. La plataforma **tiene sus propios SRE problems** — y nadie los está midiendo porque "el equipo de plataforma lo mide todo para los demás".

El resultado típico: equipos de producto que **esquivan** la plataforma ("más fácil hacerlo a mano"), equipo de plataforma **quemado** apagando fuegos de piezas antiguas que nadie se atreve a borrar, y liderazgo que **ya no entiende** qué está pasando.

Este módulo es el marco para que no te pase. Tres piezas lo sostienen:

- **Multi-tenancy** disciplinada (ya no todo en un namespace).
- **Deprecation policy** explícita (deprecar bien es tan importante como añadir bien).
- **Platform SLOs** del propio IDP (sin ellos, los equipos no pueden razonar sobre su propio riesgo).

Y encima de las tres, un **modelo organizacional** que escala sin crecer el platform team linealmente: **inner-source**.

> **Idea clave que repetiremos:** una plataforma madura **deprecia** tanto como **publica**, **mide a sí misma** antes que a los demás, y **invita a contribuir** antes que a solicitar tickets.

---

## 2. Multi-tenancy: cuatro planos, cuatro fronteras

"Multi-tenancy" no es un concepto único: son **cuatro planos** distintos donde la plataforma dibuja fronteras entre consumidores. Confundirlos es la fuente número uno de dolor.

### 2.1 Plano Kubernetes: namespaces (y más)

El namespace es la frontera **mínima** de K8s para RBAC, NetworkPolicy, ResourceQuota y LimitRange. Un buen esquema separa:

- **Un namespace por servicio por entorno** (`checkout-prod`, `checkout-staging`), o
- **Un namespace por equipo por entorno** si los servicios son pequeños y comparten lifecycle, o
- **Un namespace por tenant externo** si la plataforma es multi-cliente.

Cuando el namespace **no basta** (ruido de kube-API, blast radius, compliance), se sube un nivel:

- **Virtual clusters** (vcluster, Capsule) — tenants con "su propio API server" dentro del mismo cluster físico.
- **Clusters dedicados** por tenant crítico — pagas más, duermes mejor.
- **HNC (Hierarchical Namespace Controller)** para heredar policy entre namespaces.

Decisión guía: **cuanto más alto el blast radius aceptable y más baja la variabilidad entre tenants**, más abajo puedes quedarte (namespace). Cuanto más distintos los *compliance profiles* (p. ej. PCI vs resto), más arriba (cluster dedicado).

### 2.2 Plano cloud: projects / accounts / subscriptions

El plano cloud es la frontera **de blast radius económico y de seguridad**. GCP tiene *projects*, AWS *accounts*, Azure *subscriptions*. Las buenas prácticas convergen:

- **Un account/project por entorno** (dev, staging, prod) **mínimo**.
- **Un account/project por equipo** si el equipo tiene recursos propios no triviales (datos, buckets, DBs).
- **Jerarquía** (Organizations en AWS, Folders en GCP, Management Groups en Azure) para aplicar policy una vez y heredarla.
- **Service Control Policies / Organization Policies / Azure Policy** para forzar invariantes (p. ej. "ningún bucket público", "solo regiones X").

Beneficios por account/project separado:

- **Billing claro** (sabes cuánto consume cada tenant sin heurística).
- **Blast radius acotado** (una llave filtrada compromete un account, no toda la organización).
- **Quotas separadas** (un equipo que llena su quota no bloquea a los demás).

### 2.3 Plano Argo CD: AppProjects

Si usas GitOps con Argo CD (ver `plat-09`), **todo cae en un `default` AppProject** por omisión — y eso es un antipatrón. `AppProject` es la frontera multi-tenant de Argo CD:

- **Permisos por rol** (quién puede sync, override, delete).
- **Repos permitidos** (un AppProject solo puede desplegar desde su repo).
- **Clusters y namespaces destino permitidos** (whitelist).
- **Resource whitelist** (p. ej. "este tenant no puede crear `ClusterRole`").

Patrón recomendado: **un `AppProject` por equipo o por dominio funcional**, con:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-checkout
spec:
  sourceRepos:
    - https://github.com/acme/checkout-*
  destinations:
    - namespace: checkout-*
      server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: "apps"
      kind: Deployment
  roles:
    - name: developer
      policies:
        - p, proj:team-checkout:developer, applications, get, team-checkout/*, allow
        - p, proj:team-checkout:developer, applications, sync, team-checkout/*, allow
```

El `AppProject` es el **contrato RBAC-GitOps**. Cambios aquí son cambios de gobernanza: deberían ir con **ADR** y revisión del platform team.

### 2.4 Plano Backstage: permissions por owner

Backstage tiene un **plugin de permissions** que extiende RBAC más allá de "logged in / not logged in". Las decisiones típicas que modela:

- Un usuario **solo puede ejecutar templates** que su equipo tiene *owned*.
- Un usuario **solo puede editar entidades del catalog** de las que es owner (o un maintainer).
- **Lectura** del catalog puede ser global (recomendado — descubrir servicios es un bien común).
- **Admin** del catalog y de los templates queda en el platform team.

El contrato clave: **la entidad del catalog tiene un `spec.owner`**, y el permissions framework lo usa como *scope*. Si la ownership del catalog no está limpia, los permissions no sirven. Primero el catalog, luego las policies.

### 2.5 Síntesis multi-tenancy

Los cuatro planos **no son redundantes**: cada uno protege una cosa distinta.

| Plano | Protege | Ejemplos |
|-------|---------|----------|
| K8s namespace | runtime (CPU, memoria, net, RBAC k8s) | ResourceQuota, NetworkPolicy |
| Cloud account/project | billing, blast radius IAM, compliance | SCP, Org Policy |
| Argo CD AppProject | GitOps surface (qué puede desplegar quién) | sourceRepos, destinations |
| Backstage permissions | superficie IDP (qué puede ejecutar/editar quién) | owner-based scoping |

La **misma** entidad lógica ("equipo checkout") existe en los **cuatro** planos y debe tener la **misma ownership**. Mantener esa consistencia es un objetivo de gobernanza — se consigue con **source-of-truth única** (habitualmente el catalog) y automatización que proyecta esa fuente a los otros planos.

---

## 3. Deprecation policy: deprecar es un acto de amor

La *deprecation* mal hecha es la deuda técnica más tóxica de una plataforma: pieza vieja viva en producción, nadie se atreve a borrarla porque "quizá alguien la usa", el platform team paga el mantenimiento para siempre.

Una buena *deprecation policy* tiene **tres componentes**:

### 3.1 El ciclo: anuncio → warn → remove

```
  t0           t0 + 90d        t0 + 180d          t0 + 365d
   │               │                │                  │
   ▼               ▼                ▼                  ▼
 ANUNCIO        WARN           SOFT-REMOVE         HARD-REMOVE
 (v2 live;     (v1 emite      (v1 solo via         (v1 borrada
  v1 marked    warning en      flag opt-in;         del repo;
  deprecated)  cada uso)       nuevos no pueden     imposible usar)
                               adoptar v1)
```

- **Anuncio**: en el changelog, Slack, office hours. v2 ya está GA. v1 se marca `deprecated: true` en el catalog y en el template YAML, con fecha de hard-remove explícita.
- **Warn**: cada uso emite warning (template imprime banner, XRD anota recurso con label `deprecated=true`, API log con nivel `WARN`). El usuario **no puede ignorar** que está usando algo deprecated.
- **Soft-remove**: nuevos consumidores **no pueden adoptar** v1 (template oculto en el scaffolder, XRD solo activa vía feature flag). Los existentes siguen funcionando.
- **Hard-remove**: v1 fuera del repo. Si alguien lo necesita, es un issue nuevo con escalación.

Los TTLs deben ser **explícitos y defendibles**. Un modelo razonable para una plataforma de tamaño medio:

| Tipo de pieza | TTL anuncio → warn | TTL warn → soft | TTL soft → hard |
|---------------|--------------------|-----------------|-----------------|
| Template Backstage | 30 d | 60 d | 90 d |
| XRD de Crossplane | 60 d | 90 d | 180 d |
| API interna estable | 90 d | 180 d | 365 d |
| Golden path mayor | 90 d | 180 d | 365 d |

### 3.2 La clasificación: soporte / mantenimiento / legacy

No todo lo publicado está en el mismo estado. Tres niveles explícitos:

- **Soporte (supported):** la versión activa. Platform team resuelve bugs, acepta feature requests, incluye en roadmap. SLO completo.
- **Mantenimiento (maintenance):** la versión anterior, aún no deprecada. Solo bugs **críticos** o de seguridad. No acepta features. SLO reducido (sin burn-rate alerts).
- **Legacy:** deprecated, en el ciclo warn → remove. Solo security fixes. No tiene SLO. Documentada con **fecha de hard-remove**.

Esta clasificación es **pública** (en el catalog, en el changelog). El consumidor sabe en qué nivel está lo que usa y qué puede esperar.

### 3.3 La cadencia de comunicación

El ciclo no funciona si no se comunica. Modelo mínimo:

- **Changelog interno** publicado cada release (ver §9).
- **Anuncio en Slack** al pasar entre fases (anuncio, warn, soft-remove, hard-remove).
- **Mail/email semanal** a owners con las piezas deprecated que usan y la próxima fecha.
- **Office hour** mensual donde se explican las deprecaciones del mes.

Un patrón útil: **dashboard de deprecations** en Backstage, consultable por equipo, con "qué uso que está deprecated y cuándo caduca". Esto convierte la responsabilidad en algo **visible**, no en un email que se pierde.

### 3.4 Deprecar bien es tan importante como añadir bien

Un equipo de plataforma que **solo publica** acumula entropía. Un equipo que **publica y deprecia** mantiene el *surface area* manejable. Entre dos candidatos para añadir a la plataforma, debería ganar el que **ya tiene** su política de deprecation pensada.

---

## 4. Platform SLOs: la plataforma también es un servicio

Un SLO (*Service Level Objective*) es un objetivo numérico, acotado en el tiempo, sobre un SLI (*Service Level Indicator*). La plataforma **es un servicio** para sus consumidores internos — y por lo tanto necesita SLOs. Sin ellos:

- Los equipos de producto **no pueden razonar** sobre su propio riesgo (si Backstage cae, mi flujo de scaffolding también — ¿cuánto tiempo al mes?).
- El platform team **no tiene presupuesto de error**, con lo que cada incidente es "una tragedia" en vez de "dentro de lo esperado".
- El liderazgo **no sabe decir** si la plataforma está mejorando o empeorando.

### 4.1 Los 4 SLOs mínimos de una plataforma

Como mínimo, una plataforma madura mide:

1. **Uptime del propio Backstage.** SLI: fracción de requests HTTP 2xx/3xx vs total, excluyendo 4xx no 429. Objetivo típico: **99.5 %** sobre 30 días. (99.9 es caro para una herramienta interna; **no** vendas 4 nueves si no vas a pagarlos.)
2. **Latencia del scaffolder (p95).** SLI: tiempo entre "ejecutar template" y "PR creado". Objetivo típico: **< 60 s p95** sobre 7 días. Si tarda más, los usuarios lo perciben "roto".
3. **Freshness del catalog.** SLI: *lag* entre un push al repo de descriptores (`catalog-info.yaml`) y la actualización en Backstage. Objetivo típico: **< 5 min p99** sobre 7 días. Si es más, los dashboards mienten.
4. **MTTR en incidentes de plataforma.** SLI: tiempo entre `incident_start` y `incident_resolved` para incidentes P1/P2 que afectan al IDP. Objetivo típico: **< 2 h p90** trimestral.

Opcionales relevantes:

- **CI engine queue time** (si la plataforma incluye runners).
- **Template execution success rate** (fracción de ejecuciones de scaffolder que terminan en PR mergeable).
- **Latencia de aprovisionamiento Crossplane** (XR submit → ready).

### 4.2 Error budget y burn-rate alerts

El **error budget** es `1 − SLO`. Para 99.5 % sobre 30 días: `0.5 %` ≈ **3.6 h** de "downtime permitido" en el mes.

El uso del budget tiene **dos virtudes**:

- **Alertas de burn-rate** en vez de "está caído / no está caído". Alertar cuando se consume el budget a una velocidad que lo agotaría en < X horas (p. ej. 1 h → *fast burn*, 6 h → *slow burn*).
- **Decisiones de release**: si queda poco budget, se **congelan features** y se invierte en reliability. Si sobra, se puede ser más atrevido.

Un patrón estándar (Google SRE Workbook): dos alertas simultáneas para evitar falsos positivos: *burn rate* ≥ 14.4 en 1 h **y** ≥ 6 en 5 min (fast burn), *burn rate* ≥ 6 en 6 h **y** ≥ 3 en 30 min (slow burn).

### 4.3 Publicar el SLO: contrato con los consumidores

El SLO solo tiene valor si está **publicado y es conocido**:

- Página de "Platform Status" en Backstage.
- Dashboard público interno con SLO, SLI real y budget restante.
- Mención del SLO en los contratos con los equipos ("Backstage uptime SLO 99.5 % → tu `golden path` depende de esto para onboarding").

Los equipos de producto **construyen su propia reliability sobre la nuestra**. Si no les damos el SLO, no pueden hacer el cálculo.

---

## 5. Release cadence: continuo vs trimestral

Un platform team maduro tiene **dos cadencias** simultáneas:

- **Cadencia continua** para cambios de bajo riesgo (features aditivas, bugfixes, nuevos templates, nuevos plugins): **todos los días hábiles** si hace falta, protegidos con **feature flags**. Rollback sin drama.
- **Cadencia trimestral** para cambios de alto impacto (nueva versión mayor de un XRD, cambio del modelo del catalog, migración de autenticación): **planificados**, con *release notes*, *migration guide* y office hour dedicado.

Elegir una sola es un error:

- **Solo continuo** → los cambios grandes se cuelan sin aviso y rompen flujos de equipos.
- **Solo trimestral** → el bugfix urgente tarda 3 meses, los equipos empiezan a *fork*ear.

### 5.1 Feature flags como ciudadanos de primera

Para que la cadencia continua funcione, cada cambio no trivial va detrás de un **feature flag** (p. ej. LaunchDarkly, Unleash, Flagsmith, o un ConfigMap propio):

- Default `off` al merge.
- Activación por tenant o por canary population.
- *Kill switch* claro y documentado.

Esto permite **publicar** sin **lanzar**: el código ya está en producción, pero solo se activa cuando se decide. Reduce drásticamente el riesgo de releases grandes.

### 5.2 Freeze por error budget

Si un SLO cae por debajo de su objetivo (budget agotado), **la cadencia continua se congela** hasta recuperar budget. Esto no es castigo: es una regla **pre-pactada** que convierte el error budget en una señal operativa real.

---

## 6. Versionado de contratos: XRDs, templates, APIs internas

Todo lo que la plataforma expone es un **contrato** con sus consumidores. Como todo contrato, requiere versionado explícito y predecible: **SemVer** + **changelog**.

### 6.1 SemVer aplicado

- **MAJOR** (`1.x` → `2.0`): breaking change. Un consumidor **tiene** que leer la migration guide.
- **MINOR** (`1.1` → `1.2`): feature aditiva. El consumidor puede ignorar el cambio sin romper nada.
- **PATCH** (`1.1.0` → `1.1.1`): bugfix. Transparente.

Esto aplica igual a:

- **XRDs de Crossplane** (`v1alpha1` → `v1beta1` → `v1`, pero **también** entre `v1.0.0` y `v2.0.0` dentro del mismo nivel API).
- **Templates del scaffolder** (`template.v1.yaml`, `template.v2.yaml`), con una versión *supported* y una *maintenance* típicamente.
- **APIs internas** (p. ej. el API custom del plugin que calcula scorecards).
- **Librerías internas** compartidas entre servicios.

### 6.2 Changelog obligatorio

Cada versión incorpora una entrada en un **CHANGELOG.md** con el formato *Keep a Changelog*:

```markdown
## [2.0.0] - 2026-02-15
### Added
- Soporte para despliegues multi-región en golden-path-webservice.

### Changed
- **BREAKING** El campo `database.sizeGb` ahora se llama `database.sizeGB`
  (consistencia con otras XRDs). Ver migration-guide-2.0.md.

### Deprecated
- v1 queda en modo `maintenance`. Hard-remove: 2026-08-15.

### Fixed
- Fuga de memoria en el controller cuando `replicas: 0`.
```

El changelog **no es cortesía**: es la vía por la que un consumidor descubre que algo le afecta.

### 6.3 Breaking changes: estrategias de convivencia

Un breaking change bien hecho **no** fuerza al consumidor a actualizar el mismo día. Patrones:

- **Dos versiones vivas en paralelo** durante el TTL de deprecation (v1 y v2 ambas funcionan).
- **Shim de conversión** (CRD conversion webhook en K8s, template v1 que delega internamente a v2).
- **Migration script** idempotente provisto por el platform team.

El consumidor debe tener **tiempo y herramientas** para migrar. Si no, el breaking change es un abuso de posición.

---

## 7. Inner-source: escalar sin crecer el platform team linealmente

Si cada feature nueva requiere trabajo del platform team, el equipo escala **linealmente** con la demanda. Esto no sobrevive un año: la demanda crece siempre más rápido que la contratación.

**Inner-source** es el patrón que rompe la linealidad: equipos de producto **contribuyen** al repo de plataforma siguiendo las reglas del open-source clásico, aplicadas **puertas adentro**.

### 7.1 Las piezas mínimas

Para que una contribución inner-source funcione, el repo necesita:

- **README** del repo con "cómo contribuir" explícito.
- **CODEOWNERS** mapeando directorios a maintainers (quién revisa qué).
- **PR template** con checklist (tests, docs, changelog actualizado).
- **CI estricto** (tests + lint + validadores de contrato — ver `plat-10`).
- **SLA de review** público: *"Un maintainer responderá en < 3 días hábiles"*.
- **Guía de scope**: *"Qué sí aceptamos como contribución, qué no."*
- **Issues con label `good-first-issue`** para onboarding de contribuyentes.

### 7.2 La escalera *trusted-committer*

No todos los contribuyentes son iguales. Un modelo típico:

- **Contributor** — abre PR, un maintainer revisa.
- **Trusted committer** — tras N contribuciones aceptadas, puede mergear PRs de otros (en su directorio).
- **Maintainer** — define scope, acepta nuevas features, responde a issues del área.

La escalera **convierte usuarios en co-mantainers**. Es la única forma honesta de que una plataforma crezca más rápido que su equipo.

### 7.3 Retención de ownership

Inner-source **no** significa "cualquiera decide cualquier cosa". El platform team retiene:

- **Visión** del producto plataforma.
- **Veto** sobre contribuciones que violen scope o SLOs.
- **Responsabilidad final** de uptime y seguridad.

El modelo es "**ellos contribuyen, nosotros curamos**", no "nosotros nos lavamos las manos".

---

## 8. Comunicación: sin ella, la plataforma no existe

Una plataforma puede ser técnicamente excelente y aun así **nadie la usa**. El motivo suele ser siempre el mismo: no se **comunica**.

El canon mínimo:

- **Changelog interno público** (ver §6). Publicado tras cada release, enlazado desde Slack y desde Backstage.
- **Canal de Slack dedicado** (p. ej. `#platform-announcements` para broadcasts, `#platform-help` para soporte). Dos canales — mezclarlos **mata** ambos.
- **Office hours** semanal o quincenal. Sesión abierta de 1 h donde el platform team está disponible en Zoom para dudas, demos y feedback. **No** tiene agenda predefinida.
- **Lunch & learn** mensual (o similar). Charla de 30-40 min sobre un tema (nuevo template, cómo instrumentar un servicio, cómo usar un XRD nuevo). Grabada para quien no asista.
- **Status page interno** (ver §4) con el estado y los SLOs actuales.

Lo que **destruye** la comunicación:

- Updates **solo** en email (nadie los lee).
- Documentación que **no se actualiza** (peor que no tenerla — enseña a desconfiar).
- "Nos lo preguntas en el meeting del jueves" (no escala; mata office hours bien hechos).

El platform team pasa **un porcentaje no trivial** de su tiempo comunicando. Si al final de la semana no has escrito un changelog, hecho un demo o respondido a 20 mensajes de Slack, has sub-ejecutado el rol.

---

## 9. Cuándo *no* construir plataforma

Un módulo honesto sobre gobernanza tiene que decir **cuándo no**. No todas las organizaciones necesitan un IDP. Señales de que **no** deberías construir plataforma todavía:

- **Equipo < 3** personas dedicables al platform team. Una plataforma con < 3 personas se vuelve un *single point of knowledge* y colapsa cuando alguien se va. Mejor: **shared library** + convenciones + un líder técnico que las guarda.
- **Baja variabilidad entre equipos**. Si los 5 equipos de la empresa hacen *exactamente* lo mismo (mismo stack, mismo deploy, misma observabilidad), *shared library* o *cookiecutter* son suficientes.
- **Bajo volumen**. Si se crean < 1 servicio nuevo cada 3 meses, el *overhead* de mantener el IDP supera el ahorro.
- **Negocio en pivote**. Si el modelo de negocio cambia cada 6 meses, la plataforma —que mide su valor en años— es prematura.
- **Compliance que exige revisión manual** de cada aprovisionamiento. El autoservicio **no es compatible** con "cada cosa pasa por un comité de arquitectura".

En todos esos casos, la respuesta madura es: **todavía no**. Lo que **sí** se puede hacer es:

- **Golden paths** sin IDP (plantillas en un repo, documentación en el wiki).
- **Scorecards manuales** una vez al trimestre.
- Un **CODEOWNERS** compartido entre los repos clave.

Si el día de mañana el negocio escala y hace falta plataforma, se construye. Si no, se ahorra el coste.

> **Idea clave:** no construir plataforma es una **decisión de arquitectura**, no un fracaso.

---

## 10. Maduración organizacional: del CoE al platform team real

Muchas plataformas nacen como **Centro de Excelencia** (CoE): un grupo de ingenieros senior que publican *best practices*, revisan arquitecturas, dan charlas. El CoE **influye**, no **opera**.

El salto a **platform team real** cambia el contrato:

| Dimensión | Centro de Excelencia | Platform team real |
|-----------|----------------------|---------------------|
| Entrega | Guías, charlas, reviews | **Producto** (IDP, templates, APIs) |
| Métrica de éxito | Adopción de prácticas | **DORA + SPACE + scorecards** |
| SLA | Ninguno formal | **SLOs publicados y defendidos** |
| Oncall | Normalmente no | **Sí**, para los componentes propios |
| Modelo | Consultoría interna | **Platform-as-product** |

El CoE **puede coexistir** con el platform team — hace sentido si hay temas transversales (arquitectura de datos, seguridad) que no caben como producto. Pero confundir los dos modelos (CoE que opera, platform team que no vende producto) es receta de insatisfacción mutua.

La maduración típica es:

1. **Ad-hoc shared tooling** (una persona mantiene scripts).
2. **CoE** (varias personas publicando best practices).
3. **Platform team con un golden path** (un producto mínimo).
4. **Platform team maduro** (IDP, SLOs, inner-source, platform-as-product). Este módulo.
5. **Multiple platform teams** (datos, infra, developer experience separados), cada uno con el modelo del paso 4.

---

## 11. Defender el plan: tres escenarios canónicos

Un plan de gobernanza no se evalúa en abstracto; se evalúa frente a **escenarios adversariales**. La actividad `02-year-one-plan` te pide defender el plan contra tres:

### 11.1 Crecimiento rápido

- La empresa dobla ingeniería en 12 meses.
- Nuevos equipos entran con stacks heterogéneos.
- La presión política empuja a "integrar YA" todo lo nuevo.

Preguntas que el plan debe responder:

- ¿Cómo escala el platform team sin crecer linealmente? (inner-source, trusted committers)
- ¿Qué SLO sacrifica? (nada; se defienden con freeze por budget)
- ¿Cómo prioriza qué integrar primero? (criterios públicos: volumen × criticidad × standardizability)

### 11.2 Hiring freeze

- La empresa congela contratación durante 2 trimestres.
- El platform team queda al tamaño actual durante 6+ meses.
- La demanda sigue creciendo.

Preguntas:

- ¿Qué cosas **se deprecan** para liberar capacidad? (el ciclo de §3 se acelera)
- ¿Qué cosas se **pasan a mantenimiento** (no features, solo security)?
- ¿Qué contribución inner-source se **habilita** para compensar?
- ¿Cómo se comunican los recortes **sin perder confianza**?

### 11.3 Consolidación post-merger

- La empresa compra o es comprada; aparecen 2 (o más) IDPs rivales.
- Hay presión política por "elegir el mejor" o "fusionarlos".

Preguntas:

- ¿Qué criterios **técnicos** usas para elegir / fusionar? (adoption, SLOs reales, deuda técnica medible)
- ¿Cómo migras tenants sin romper flujos? (el ciclo de deprecation aplicado a plataformas enteras)
- ¿Cómo gestionas el **choque cultural** (equipos acostumbrados a X ahora usan Y)?
- ¿Qué partes se **mantienen vivas** aunque sean redundantes porque tienen *lock-in* del negocio?

Un buen plan de año uno **anticipa** los tres escenarios y describe qué cambia en cada uno (sin pretender que son improbables).

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Explicar los **4 planos** de multi-tenancy y las fronteras que protege cada uno.
- Diseñar un **ciclo de deprecation** con TTLs y clasificación supported/maintenance/legacy.
- Escribir SLOs para la **propia** plataforma: Backstage uptime, scaffolder p95, catalog freshness, MTTR.
- Articular por qué **inner-source** es la única forma de que una plataforma no crezca linealmente con su equipo.
- Decir honestamente **cuándo no** construir plataforma.
- Defender un **plan de año uno** contra crecimiento rápido, hiring freeze y consolidación post-merger.

Este es el **capstone** del curso. No hay módulo siguiente. Lo que sigue es **operar la plataforma** usando este marco, iterando el ADR cuando la realidad lo rompa, y publicando el changelog cada vez que algo cambie — porque **sin comunicación, la plataforma no existe**.

Una síntesis final de una línea:

> **Una plataforma madura deprecia tanto como publica, mide a sí misma antes que a los demás, invita a contribuir antes que a solicitar tickets, y sabe decir "todavía no" cuando el negocio no la necesita.**

Todo lo demás del curso ha sido **cómo** hacer realidad esa frase sin volverse jaula ni caos.
