# Examen de certificación — Platform Engineering

- **Curso:** `platform-engineering` (plat-01 .. plat-12).
- **Nivel:** avanzado.
- **Dimensiones:** conceptual + operativa + arquitectónica (todas).
- **Tipo:** sumativa (take-home + revisión opcional live).
- **Duración:** 90-120 min.
- **Umbral de aprobación:** 70% ponderado.
- **Entorno:** take-home. Python 3.11+. No requiere Backstage real ni cuentas cloud; todo opera sobre `operative/catalog.json` (JSON sintético inspirado en Backstage).

Estructura del repo del examen:

```
11-platform-engineering/
  EXAM.md                       # este documento
  competency-matrix.yaml        # qué se evalúa, pesos, red flags
  operative/
    catalog.json                # fixture sintético (provisto)
    README.md                   # enunciado operativo
    scorecard.py                # (lo escribe el estudiante)
    tests/                      # (los escribe el estudiante)
    out/                        # (output del estudiante)
  architectural/
    scenario.md                 # enunciado arquitectónico
    response.md                 # (lo escribe el estudiante)
    ADR-001-plataforma-ano-uno.md
```

## 1. Matriz de competencias evaluadas

Ver `competency-matrix.yaml` para pesos exactos. Resumen:

| ID  | Competencia (verbo + resultado observable)                                                                                           | Dim.      | Peso | Módulo        |
|-----|---------------------------------------------------------------------------------------------------------------------------------------|-----------|------|---------------|
| C1  | Modelar org con Team Topologies y justificar X-as-a-Service por default                                                               | C         | 7    | plat-01       |
| C2  | Diferenciar golden path (opt-in) vs mandato y defender criterios del primer path                                                      | C         | 7    | plat-02       |
| C3  | Elegir IDP (Backstage/Port/CNOE/OpsLevel) sin caer en "Backstage por default"                                                         | A         | 8    | plat-03       |
| C4  | Explicar Backstage-como-framework e implicaciones de upgrade continuo                                                                 | C         | 5    | plat-04       |
| C5  | Modelar entidades y relaciones del catalog; detectar relaciones inválidas                                                             | O/C       | 10   | plat-05       |
| C6  | Diseñar templates como producto; descomponer un mega-template                                                                         | C/A       | 6    | plat-06       |
| C7  | Priorizar 3 plugins primero sobre catálogo-only; defender docs-as-code                                                                | C         | 5    | plat-07/08    |
| C8  | Elegir Crossplane vs TF-via-PR según perfil organizacional; guardrails                                                                | A         | 8    | plat-09       |
| C9  | Diseñar scorecards (5-8 checks) sin gamificación; medir adopción                                                                      | O/C       | 10   | plat-10       |
| C10 | Combinar DORA + SPACE para evitar Goodhart's Law                                                                                      | O/C       | 10   | plat-11       |
| C11 | Defender platform-as-product (roadmap, feedback, financiamiento)                                                                      | A         | 6    | plat-11       |
| C12 | Gobernanza a escala: multi-tenancy, deprecation TTL, platform SLOs, inner-source                                                      | A/O       | 10   | plat-12       |
| C13 | Reconocer cuándo *no* construir plataforma y antipatterns                                                                             | C         | 4    | plat-01/12    |
| C14 | Operacionalizar freshness del catalog como señal de salud                                                                             | O         | 4    | plat-11/12    |

Ponderación por dimensión: **conceptual 35% · operativa 40% · arquitectónica 25%**.

---

## 2. Preguntas conceptuales

> 13 preguntas de respuesta corta (3-8 líneas cada una, salvo que indique otra cosa). Peso individual en la rúbrica (sección 5). Evita repetir definiciones del material: todas preguntan **por qué**, **qué pasaría si**, **cuándo preferirías X sobre Y** o **qué garantiza / no garantiza**.

### Q1 — Platform team como X-as-a-Service (C1)

Un director propone que el platform team "acompañe a cada equipo stream-aligned en cada feature para garantizar calidad". **¿Por qué, en Team Topologies, esto degrada la propuesta de valor del platform team y qué tipo de interacción debería ser el default?** Nombra un antipattern concreto que resultaría de aceptar esa propuesta.

### Q2 — Golden path vs mandato (C2)

Un VP exige que "todos los servicios nuevos deben usar el template oficial de Python" bajo bloqueo de merge. **¿Qué pierdes al pasar de golden path (opt-in) a mandato forzado, y en qué 2 condiciones organizacionales el mandato sí es defendible?** Explica el riesgo de "parque jurásico" si el camino forzado luego no se puede evolucionar.

### Q3 — "Backstage por default" (C3)

Dos arquitectos recomiendan Backstage self-hosted como IDP para una org de **4 ingenieros de plataforma, sin expertise Node/TS, en una industria regulada con pocos servicios (12)**. **¿Qué tres riesgos específicos tiene esa elección y qué alternativa evaluarías primero, con qué criterio?** Un vendor presiona con "todos los demás eligen Backstage".

### Q4 — Backstage es framework, no app (C4)

**¿Por qué una org que trata Backstage como "una app que se instala y se mantiene con un sysadmin a tiempo parcial" entra en deuda técnica rápido?** Menciona el impacto del Backend System 1.0 y plugins con breaking changes en la cadencia de upgrade.

### Q5 — Relaciones del catálogo (C5)

Un desarrollador agrega `dependsOn: [component:default/other-team-service]` a su `catalog-info.yaml` "para que aparezca en el gráfico". **¿Qué garantiza esta relación en Backstage y qué NO garantiza (contraste con `providesApi`/`consumesApi`)?** ¿Qué consecuencia operativa tiene llenar `dependsOn` con falsos positivos?

### Q6 — Mega-template vs templates composables (C6)

Un template "nuevo microservicio" hace 23 cosas (repo, CI, chart, Argo app, dashboards, alertas, secretos, DB, dominio). **¿Qué dos problemas de mantenibilidad produce y cómo lo descompondrías respetando que el template es un "contrato de inicio" versionado?** ¿Cómo verificas en CI que el template sigue produciendo output válido?

### Q7 — Prioridad de plugins (C7)

Un Backstage lleva 6 meses con "catálogo-only": entidades pobladas, cero plugins. **¿Qué 3 plugins instalarías primero para que el catálogo deje de ser "un wiki tipado" y por qué esos y no otros?** Argumenta en función de qué pregunta operativa habilita cada uno.

### Q8 — Crossplane vs Terraform-via-PR (C8)

Una org **Terraform-first** con Atlantis maduro quiere mover self-service de infra a Crossplane "porque es cloud-native". **¿Bajo qué condiciones recomendarías esperar y bajo cuáles sí migrar?** ¿Qué garantiza Crossplane (Claims + XRDs + Kyverno) que TF-via-PR no garantiza fácilmente, y viceversa?

### Q9 — Scorecards sin gamificación (C9)

Un platform team propone un scorecard con **27 checks**, pesos "pares", y bonus por "equipo motivado". **¿Qué tres patologías introduce ese diseño?** Rediseña con criterio del módulo: ¿cuántos checks iniciales, qué propiedad deben cumplir los criterios, y cómo evitas que los equipos "farmen" la métrica?

### Q10 — DORA sin SPACE: dashboard de deploys (C10)

Un dashboard ejecutivo celebra "+40% deployment frequency trimestre a trimestre" como señal de salud. **¿Por qué esa única métrica es Goodhart's Law y qué 2-3 señales adicionales (DORA o SPACE) hacen que la lectura sea defendible?** Da un ejemplo concreto de cómo un equipo puede inflar deployment frequency sin mejorar el producto.

### Q11 — Platform-as-product y financiamiento (C11)

Comparar **"plataforma gratis"** vs **showback** vs **chargeback** como modelo de financiamiento. **¿Qué incentivos crea cada uno en los equipos consumidores y en el platform team mismo?** ¿Cuándo preferirías showback sobre chargeback aunque el CFO pida chargeback?

### Q12 — Deprecation policy y SLOs de la plataforma (C12)

**¿Por qué deprecar sin TTL explícito es tan dañino como no deprecar?** Diseña el ciclo mínimo (announce → warn → remove) con ventanas en días para una API interna consumida por 8 equipos, y nombra 2 SLOs *de la plataforma misma* que todo platform team debería publicar.

### Q13 — Cuándo *no* construir plataforma (C13)

Una startup de **9 ingenieros totales, 1 servicio Python, 1 servicio Go** quiere "montar Backstage + Crossplane + scorecards" tras leer el *Humanitec Platform Engineering Report*. **¿Qué le dirías y qué 2 cosas sí tiene sentido invertir hoy que la preparen para una plataforma futura sin construirla ya?**

---

## 3. Ejercicio operativo (dimensión operativa)

Ver `operative/README.md`. Resumen de las 6 subtareas (todas sobre `catalog.json` con Python puro + pytest):

- **OP-task-1** Audit referencial del catálogo (owners, APIs, resources).
- **OP-task-2** Vista de impacto (consumers / dependents por API y Resource).
- **OP-task-3** Scorecard de madurez con 8 checks de peso definido.
- **OP-task-4** Adopción agregada (gold/silver/bronze/unrated %).
- **OP-task-5** DORA agregada por sistema + warnings anti-Goodhart.
- **OP-task-6** Freshness report + propuesta de política de deprecation.

Validación: comandos reproducibles + `pytest -q`. Valores de referencia esperados listados en `operative/README.md`.

---

## 4. Ejercicio arquitectónico (dimensión arquitectónica)

Ver `architectural/scenario.md`. Escenario: diseño del año 1 de la plataforma de ACME (fintech regional, 42 microservicios, equipo plataforma de 7, M&A probable a 12m, hiring freeze posible a 9m). Entregables:

- `architectural/response.md` — diseño con trade-offs explícitos sobre Team Topologies, golden path, IDP, Crossplane vs TF-via-PR, scorecards+DORA+SPACE, platform-as-product y gobernanza + defensa frente a 3 escenarios adversos.
- `architectural/ADR-001-plataforma-ano-uno.md` — ADR formal de las decisiones vinculantes.

---

## 5. Rúbrica

Cada criterio usa 4 niveles. **Puntaje total = Σ (puntos de criterio × peso del criterio)**. Umbral de aprobación: **70%** sobre el total.

### 5.1 Rúbrica de preguntas conceptuales (Q1-Q13)

Aplica a cada pregunta por igual.

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Precisión conceptual | Confunde conceptos clave (ej. golden path = mandato; Backstage = app) | Correcta pero superficial, parafrasea el material | Correcta, aplica el concepto al escenario planteado | Correcta, aplica *y* nombra el límite / contraejemplo |
| Razonamiento causal | "Porque sí" o apela a autoridad | Enumera consecuencias sin encadenarlas | Explica *por qué* la consecuencia se sigue del concepto | Diferencia qué garantiza vs qué NO garantiza, con ejemplo |
| Pertinencia al escenario | Ignora el escenario de la pregunta | Lo menciona pero no lo usa | Ancla la respuesta en los datos del escenario | Reinterpreta el escenario para destacar la tensión real |

Peso por pregunta: **1.0** salvo Q5, Q9, Q10, Q12 que valen **1.5** (competencias de mayor peso en la matriz).

### 5.2 Rúbrica del ejercicio operativo

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|---|---|---|---|---|---|
| Correctness (match con valores de referencia) | Falla ≥ 3 asserts del README | Falla 1-2 asserts | Pasa todos los asserts, mínimos tests | Pasa todos + edge cases cubiertos (lifecycle=deprecated, signals null) | 4 |
| Diseño del scorecard | Pesos arbitrarios o checks ausentes | Usa los 8 checks con los pesos dados | 8 checks + umbrales bronze/silver/gold consistentes | Documenta en REFLECTION.md por qué los pesos son defendibles sin gamificar | 2 |
| Detección DORA + warnings | Reporta solo deploys | DORA correcta pero sin warnings | DORA correcta + warning con lenguaje Goodhart's Law | Warning distingue "high deploys OK" de "high deploys + CFR alto + MTTR faltante" | 2 |
| Freshness y política | Lista servicios sin política | Lista + política vaga | Lista + ventana announce/warn/remove con canal | Agrega impacto del dependents cross-cutting (OP-task-2) | 2 |
| Calidad del código | Script monolítico sin tests | Funciones separadas, 1-2 tests | Separación IO/lógica, 4+ tests pytest, type hints | Pytest parametrizado, dataclasses, zero deps externas | 2 |
| Seguridad / red flags | ≥1 red flag presente (secretos, curl\|bash, net calls) | — | — | Ninguno de los red flags del `competency-matrix.yaml` presente | 2 (eliminatorio: fallar aquí anula el bloque operativo) |

### 5.3 Rúbrica del ejercicio arquitectónico

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|---|---|---|---|---|---|
| Team Topologies defendible | Platform team mal clasificado o sin modos de interacción | Clasificación correcta pero modos genéricos | X-as-a-Service justificado + 2 antipatterns prevenidos | Modos de interacción diferenciados por equipo y evolución en el tiempo | 2 |
| Elección de IDP con criterio | "Backstage por default" o sin criterio | Compara 2 opciones | Compara ≥3, elige con los criterios del escenario (7 personas, M&A, no licencia) | Explicita qué cambiaría de haber tenido licencia Port aprobada | 2 |
| Crossplane vs TF-via-PR | Elige sin considerar el stack TF actual | Elige con criterio general | Elige con criterio del escenario y lista guardrails Kyverno/labels | Plan de migración incremental con criterios de "ya aguanta pasar" | 2 |
| Scorecards + DORA + SPACE | 20+ checks o métricas vanity | 5-8 checks + DORA simple | + SPACE para evitar Goodhart + anti-vanity declarado | Explicita qué NO reporta a ejecutivos y por qué | 2 |
| Platform-as-product + gobernanza | Sin financiamiento, sin SLOs, sin deprecation TTL | Alguno de los tres sin justificar | 3 SLOs defendibles + deprecation TTL + financiamiento razonado | Inner-source operativo y evidencia de feedback loops | 2 |
| ADR formal | Falta estructura o solo decide sin alternativas | Estructura correcta, alternativas pobres | Estructura + alternativas + consecuencias | Reversibilidad y señales de cuándo revisitar la decisión | 1 |
| Defensa frente a 3 escenarios (crecimiento, hiring freeze, M&A) | Ignora uno o más | Comenta superficial | Explica qué se rompe y qué se recorta | Prioriza decisiones reversibles vs no-reversibles | 2 |
| Red flags ausentes | ≥1 red flag presente | — | — | Ninguno | 1 (eliminatorio para el bloque arquitectónico) |

### 5.4 Ponderación global y umbral

- **Conceptual** (sección 2): 35% del total.
- **Operativo** (sección 3): 40%.
- **Arquitectónico** (sección 4): 25%.
- **Umbral de aprobación**: 70% ponderado, **y** ningún bloque por debajo de 50% (evita compensar operativo cero con conceptual perfecto).
- **Red flags eliminatorios**: cualquier red flag presente baja el bloque correspondiente a 0.

---

## 6. Guía de corrección (instructor-only)

> Pensada para que dos correctores independientes lleguen al mismo puntaje ±1 punto por bloque.

### 6.1 Respuestas modelo (conceptual)

**Q1 (C1).** El default del platform team es **X-as-a-Service**: contratos claros, autoservicio, el consumidor no espera por el platform team para avanzar. Si cada feature exige *collaboration*, el platform team se convierte en el cuello de botella que estaba por disolver, y pierde escala. Antipattern concreto: **"ticketing-driven ops"** (todo pasa por un queue de JIRA) o **"ivory tower"** (platform team diseña sin feedback). Puntos clave: nombra X-as-a-Service, menciona que *facilitating/collaboration* son excepciones temporales (p. ej. onboarding de un patrón nuevo), un antipattern explícito.

**Q2 (C2).** Lo que pierdes: **adopción voluntaria genuina** (señal de que el camino es valioso), **feedback honesto** (si está forzado nadie admite problemas), **evolución** (si no puedes salirte, no puedes mejorar sin romper a todos → "parque jurásico"). Mandato defendible en: (a) temas regulatorios o de seguridad donde no hay opción B (SBOM firmado, imagen base aprobada), (b) decisiones que ya tienen opción B soportada y se busca consolidar tras evidencia de adopción. Parcialmente correcto si solo nombra regulado y no evolución.

**Q3 (C3).** Riesgos: (1) 4 personas no sostienen upgrade continuo de Backstage + 10+ plugins; (2) sin expertise Node/TS, cada custom plugin es un parche; (3) 12 servicios es bajo volumen → el valor marginal de un IDP self-hosted no amortiza el costo. Alternativa: **Port** (SaaS, menos ingeniería interna, scorecards nativos) o **CNOE** si quieren OSS pre-ensamblado; también defendible "sin IDP durante 6 meses" + inventariar dolor real primero. Criterio: *build vs buy* según expertise y tamaño del platform team. Rechazar presión del vendor con datos del escenario.

**Q4 (C4).** Backstage se crea con `@backstage/create-app` y es **un repo propio** mantenido por la org; no una app que se "actualiza". Backend System 1.0 cambió patrón de wiring, plugins liberan breaking changes con frecuencia; un sysadmin a tiempo parcial no puede sostener la cadencia → el repo se queda atrás, plugins no actualizan, se vuelve legacy. Ritmo: upgrades mensuales o bimensuales, con tests.

**Q5 (C5).** `dependsOn` es declarativo y **no verificado**: Backstage lo pinta pero no comprueba que exista tráfico real. `providesApi`/`consumesApi` requieren que la API esté declarada y habilitan vista de impacto automática. Consecuencia de falsos positivos: queries de impacto ("¿qué se rompe si deprecamos X?") devuelven ruido, el catálogo pierde confianza y los equipos lo ignoran. Pre-commit que valide `catalog-info.yaml` es mitigación.

**Q6 (C6).** Problemas: (1) **blast radius**: cambiar una línea rompe los 23 outputs; (2) **ownership difuso**: no está claro quién mantiene qué pieza, los PRs se bloquean. Descomposición: templates composables (uno de repo+CI, uno de chart+Argo, uno de observabilidad+alertas) con `fetch:template` encadenado o un template "meta" que invoca sub-templates. Verificación en CI: regenerar un output de referencia y diffear; test que el output todavía compila/lint pasa.

**Q7 (C7).** 3 plugins típicos: **Kubernetes** (ver Pods/Deployments por Component → responde "¿está corriendo?"), **GitHub Actions o Argo CD** (CI/CD status → responde "¿se desplegó?"), **PagerDuty/Opsgenie** (on-call → responde "¿a quién llamo si está roto?"). Argumento: cada uno responde una pregunta operativa recurrente que hoy obliga a saltar entre consolas. Rechazar "cost insights primero" sin volumen que lo justifique.

**Q8 (C8).** Esperar si: TF-via-PR ya cubre el 80% del dolor, el equipo plataforma no sabe Crossplane y no hay roadmap que lo justifique, el blast radius de un bug en una Composition es alto. Migrar si: multi-cloud o alta variabilidad de recursos, se busca mismo RBAC/GitOps para infra y app, los Claims simplifican el UX del developer. Crossplane garantiza **continuous reconciliation** (drift detection), RBAC K8s unificado, mismo observability pipeline. TF-via-PR garantiza **plan review humano explícito**, state file como fuente de verdad, maturity. No es "mejor"/"peor"; depende de la org.

**Q9 (C9).** Patologías: (1) **ruido**: 27 checks no priorizados → ningún equipo sabe por dónde empezar; (2) **pesos pares** = no hay señal; (3) **"equipo motivado"** no es observable → introduce subjetividad y gamificación. Rediseño: 5-8 checks, cada criterio **observable automáticamente** (hay / no hay), peso diferenciado para forzar foco (ej. image_signed vale 2x docs_updated), evitar bonus. Para no farmear: medir resultado, no actividad (p. ej. "tiene SLO definido *y* reportado", no "creó un archivo SLO.md").

**Q10 (C10).** +40% deployment frequency puede venir de: deploys triviales artificiales (bump de versión sin cambios), feature-flagging sin releases reales, equipos repartiendo un cambio en 10 PRs. Señales adicionales: **change failure rate** (si subió, los deploys están rotos), **MTTR** (si no bajó, cada falla duele igual), **SPACE: satisfaction** (survey a devs: ¿se sienten más productivos?), **lead time** (si bajó también, el flujo mejoró de verdad). Ejemplo concreto: equipo que deploya cada bump de dependencia como release separado para inflar el número.

**Q11 (C11).** "Gratis": incentiva adopción pero no da señal de valor, platform team sin presupuesto de desarrollo diferenciado, los consumidores piden features sin costo. **Showback**: visibilidad del costo sin cobrar, mantiene adopción, sensibiliza. **Chargeback**: cobro real, obliga a priorizar por valor pero crea fricción, incentiva **shadow IT**. Preferir showback a chargeback cuando la plataforma aún está probando valor o cuando la org no tiene madurez financiera para intercompany billing. Platform team mismo: showback le da datos para el roadmap sin crear enemigos.

**Q12 (C12).** Sin TTL explícito, el consumidor nunca "siente la urgencia" y la deprecación se eterniza; el platform team mantiene dos sistemas para siempre. Ciclo mínimo típico: **announce 30d → warn (deprecation header, logs, Slack) 60d → remove 90d**, con canal (Slack #platform-announcements + release notes + ticket por equipo consumidor). SLOs de plataforma: **uptime Backstage ≥ 99.5%**, **latencia scaffolder p95 < 60s**, **freshness catalog < 24h**, **MTTR incidentes plataforma < 2h**. Pide al menos 2 defendibles.

**Q13 (C13).** Mensaje: no construir plataforma aún — equipo pequeño, 2 servicios, baja variabilidad. La plataforma no amortiza. Qué sí invertir hoy: (1) **docs-as-code** desde el día uno (README, ADRs, runbooks) para no pagar deuda después; (2) **convenciones** (template git-ignorable: estructura de repo, logging, CI básico) que luego se formalicen; (3) opcional: adoptar un IDP SaaS liviano (Port free tier) cuando tengan 10+ servicios, no antes.

### 6.2 Guía del ejercicio operativo

- Solución de referencia esperada: ver `operative/README.md` sección **Validación**. El corrector corre los 4 comandos + `pytest` y verifica contra los valores listados.
- Errores comunes y cómo puntuar:
  - **Confundir `lifecycle` con `repo_archived`** → `legacy-reports` no debe aparecer como "repo archived but lifecycle production" porque su lifecycle es `deprecated`. Si lo reporta como inconsistencia, resta 1 en Correctness.
  - **No ignorar signals `null` en DORA** → divide por cero o incluye `pricing-service` inflando mal. Resta 1-2 en Correctness.
  - **Promedio simple en change_failure_rate_pct** en vez de ponderado por deploys. Resta 1.
  - **Scorecard con 20 checks "para asegurar"** → viola el enunciado, baja Diseño del scorecard a 0-1.
  - **Tests que solo chequean que no crashee** → baja Calidad del código a 1.
- Señales de "respondió sin entender":
  - Mete lógica directa dentro de `argparse` sin funciones puras.
  - Copia-pega checks de un ejemplo del módulo sin adaptar nombres al `catalog.json` real.
  - REFLECTION.md dice "elegí estos pesos porque me parecieron razonables" sin más.
- **Red flags** (anulan el bloque): secretos en código/catálogo, `subprocess` a `curl | bash`, dependencias instaladas desde URL no verificada, llamadas de red en el script, print de API keys reales.
- **Preguntas de seguimiento (live)**:
  - "Si el peso de `image_signed` fuera 1 en vez de 2, ¿qué servicios cambian de nivel y por qué?" (prueba si entendió los umbrales).
  - "¿Qué cambia en tu DORA agregado si `notifications-worker` pasa su MTTR a 10 min? ¿Y si pasa a `null`?" (prueba el tratamiento de nulls).
  - "El catálogo crece a 500 Components. ¿Qué romperías de tu diseño actual?" (prueba escalabilidad y separación IO/lógica).
  - "¿Por qué 90 días para `deployed_last_90d` y no 30?" (prueba si entiende adopción vs noise).

### 6.3 Guía del ejercicio arquitectónico

- Solución de referencia: no hay una única respuesta; evalúa la **coherencia interna del plan** y la **honestidad de los trade-offs**.
- Esperable: para una org de 42 servicios y platform team de 7, lo defendible típicamente es:
  - Platform team = **platform** (team topology), modo default X-as-a-Service.
  - Primer golden path: "nuevo microservicio Python" (volumen alto, variabilidad baja, dolor "2-3 semanas" confirmado).
  - IDP: **Backstage self-hosted** es defendible dado 7 personas y presupuesto; **Port** también defendible si justifica time-to-value y M&A; **CNOE** defendible como atajo. Rechazar quien no considere el M&A.
  - Self-service infra: **TF-via-PR** probablemente gana para el año 1 (org ya es TF-first, Crossplane agrega curva en un año con M&A y hiring freeze posible); migrar a Crossplane es decisión de año 2+.
  - Scorecard: 6-8 checks, DORA 4 métricas, SPACE 1-2.
  - Financiamiento: showback año 1, chargeback potencial año 2.
  - SLOs: uptime Backstage, latencia scaffolder, freshness catalog.
  - Deprecation TTL: 30/60/90 o similar explicitado.
- Errores comunes:
  - **"Backstage + Crossplane + Port + OpsLevel"** → no entendió el escenario (presupuesto, tamaño del equipo).
  - **Golden path = mandato bloqueante** desde el día uno → confunde C2.
  - **No menciona el M&A** → ignora un dato del escenario; baja "Elección de IDP" y "Defensa frente a 3 escenarios".
  - **Platform team modelado como stream-aligned** → confunde Team Topologies.
  - **ADR sin "Alternativas consideradas"** o sin "Consecuencias" → baja ADR formal.
- Señales de "respondió sin entender":
  - Cita Humanitec, PlatformCon, Spotify sin aterrizar en ACME.
  - Scorecard de 20+ checks "para estar seguros".
  - "DORA es la fuente de verdad" sin SPACE.
- **Red flags** (anulan el bloque):
  - Secretos ejemplo en el ADR o response (tokens hardcodeados).
  - RBAC `cluster-admin` para scaffolder sin justificación.
  - Plataforma propuesta para una org donde no amortizaba (confunde C13 — pero este escenario sí la amortiza, el red flag aplica si el estudiante propone construirla "porque todos lo hacen" sin ligar al dolor).
  - Crossplane propuesto sin considerar que la org es TF-first y hay hiring freeze.
- **Preguntas de seguimiento (live)**:
  - "El CTO congela hiring mañana. ¿Qué recortas primero y qué defiendes?"
  - "El M&A se adelanta 6 meses y es GCP + Cloud Build. ¿Qué parte de tu plan sobrevive?"
  - "Un director propone saltar a chargeback el trimestre 2. Convéncelo o acompáñalo."
  - "¿Por qué NO Crossplane / por qué NO Backstage? Argumento inverso al que elegiste."
  - "Un equipo stream-aligned quiere contribuir código al platform repo. ¿Cómo lo canalizas con inner-source sin perder control?"
