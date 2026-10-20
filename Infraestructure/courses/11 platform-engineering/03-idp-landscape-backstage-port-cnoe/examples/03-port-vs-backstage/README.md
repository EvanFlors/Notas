# Ejemplo 03 — Port vs Backstage, cara a cara

> Lectura y análisis. Sin ejecución. Objetivo: entender los **8 ejes** donde Port y Backstage toman decisiones opuestas, y el *gotcha* típico que cada camino esconde.

Son los dos "finalistas naturales" cuando la organización ya decidió **que sí quiere un portal interno**. Elegir entre ellos no es "comparar features" — es **elegir una curva de inversión**.

## 1. Las 8 dimensiones de la decisión

### 1.1 Modelo de distribución y operación

- **Backstage**: framework OSS. Tú despliegas, operas, upgradas, parcheas.
- **Port**: SaaS gestionado. El vendor opera; tú configuras.

**Gotcha Backstage**: subestimar el **day-2** (upgrades de core, de plugins, de Backend System).
**Gotcha Port**: subestimar el **lock-in del modelo** (al cambiar de blueprints, migrar datos cuesta).

### 1.2 Time-to-first-value

- **Backstage**: realista **3–6 meses** hasta un portal usable por developers con 2–3 ingenieros dedicados.
- **Port**: realista **días a 2 semanas** hasta un portal con 20–50 servicios catalogados.

**Gotcha Backstage**: declarar "listo" el día que compila; en realidad la adopción empieza con el primer template productivo.
**Gotcha Port**: declarar "listo" el día que todos los servicios aparecen; en realidad la adopción empieza cuando los developers lo abren voluntariamente.

### 1.3 Extensibilidad

- **Backstage**: **alta**. Plugin frontend (React) + plugin backend (Node) + wiring por el modelo de providers. Puedes construir casi cualquier cosa.
- **Port**: **media**. Webhooks, actions con integraciones nativas, API REST, GitOps-style blueprints. **No** se escriben plugins TypeScript.

**Gotcha Backstage**: creer que "podemos" extenderlo todo justifica hacerlo; cada plugin custom es deuda.
**Gotcha Port**: chocar contra una necesidad que el modelo del vendor no cubre (p. ej. un plugin tipo *K8s plugin de Backstage* embebido).

### 1.4 Modelado del catálogo

- **Backstage**: **entidades YAML** (`catalog-info.yaml`) con kinds canónicos (`Component`, `API`, `Resource`, `System`, `Domain`, `User`, `Group`). Importación vía providers (GitHub org, GitLab, URL, etc.).
- **Port**: **blueprints** definidos por el usuario (sin kinds canónicos impuestos) + relaciones custom. Importación vía integraciones nativas.

**Gotcha Backstage**: `catalog-info.yaml` **stale** porque nadie los mantiene — se vuelve ruido.
**Gotcha Port**: diseñar los blueprints sin convención → cada equipo propone un modelo distinto y el catálogo se vuelve inconsistente.

### 1.5 Scaffolder / Actions

- **Backstage**: **Scaffolder** con `parameters` (JSON Schema), `steps` (acciones built-in + custom en TS), `output`. Nunjucks sobre el skeleton. Acciones built-in: `fetch:template`, `publish:github`, `catalog:register`, etc.
- **Port**: **Actions** basadas en webhooks → tu CI/CD (GHA, Jenkins, Argo Workflows) ejecuta la lógica. Port es el **frontend del form** y el **tracker de ejecución**.

**Gotcha Backstage**: templates "mega" que crecen sin control porque son fáciles de empezar.
**Gotcha Port**: dispersión — la lógica del template vive en N repos de CI, no en el portal.

### 1.6 Scorecards / madurez

- **Backstage**: **TechInsights/Soundcheck** (plugins). Requiere setup y disciplina.
- **Port**: **scorecards nativos**, UI pulida, sin setup extra.

**Gotcha Backstage**: scorecards se posponen porque "después los hacemos" → nunca llegan.
**Gotcha Port**: scorecards triviales ("tiene owner") que no diferencian servicios maduros de inmaduros.

### 1.7 Costo y TCO

- **Backstage**: capex en ingeniería interna (2–3 FTE sostenidos mínimo). "Gratis" solo en licencia.
- **Port**: opex per-developer-per-month (**verificar pricing vigente**). Lineal con el tamaño de la organización.

**Gotcha Backstage**: no modelar el costo de hiring y retención de los TS devs.
**Gotcha Port**: no modelar el crecimiento de developers en 24 meses y toparse con un invoice sorpresa.

### 1.8 Reversibilidad / lock-in

- **Backstage**: **bajo lock-in**. El modelo entity (catalog-info.yaml) es portable; los plugins custom son tuyos.
- **Port**: **medio-alto lock-in**. Los blueprints, actions, scorecards exportables pero rehacer el frontend en otra herramienta es costoso.

**Gotcha Backstage**: diferir migraciones upstream (Backend System 1.0) → fork técnico.
**Gotcha Port**: no exportar periódicamente los blueprints — si quieres salir, tienes que reverse-engineer.

## 2. Matriz resumen

```
Dimensión               │  Backstage                    │  Port
────────────────────────┼───────────────────────────────┼────────────────────────────
Modelo                  │ Framework OSS self-hosted     │ SaaS configurable
Equipo mínimo           │ 2–3 ing. TS/React             │ 0.5 FTE
Time-to-first-value     │ 3–6 meses                     │ Días a 2 semanas
Extensibilidad          │ Alta (plugins TS)             │ Media (webhooks/API)
Catálogo                │ Entidades YAML canónicas      │ Blueprints custom
Scaffolder              │ Core (acciones + Nunjucks)    │ Actions → CI externo
Scorecards              │ Plugin (TechInsights)         │ Nativo
Costo                   │ Capex interno                 │ Opex per-dev/mes
Lock-in                 │ Bajo                          │ Medio-alto
Compliance self-hosted  │ Sí                            │ No
```

## 3. Dos vignettes de decisión

### 3.1 "Empresa mediana, 300 devs, 4 platform engineers, presupuesto SaaS ok"

- Backstage **puede**, pero 4 ingenieros con 20 % de tiempo en upgrades + 20 % en plugins + 60 % restante no es ideal.
- Port permite **liberar** a esos 4 para construir golden paths, scorecards y templates **sin** operar el portal.
- Recomendación típica: **Port para los primeros 12 meses**; revisar si el techo de extensibilidad empieza a doler y, si sí, planear migración a Backstage con la inversión en modelado ya hecha.

### 3.2 "Enterprise 2000 devs, 15 platform engineers, compliance obliga self-hosted"

- Port queda fuera (SaaS no permitido).
- 15 ingenieros sostienen Backstage sin problema, con capacidad real para plugins custom (observabilidad, cost insights, security scorecards específicos).
- Recomendación: **Backstage**, evaluar **CNOE** si quieren partir de una referencia opinionada y les cuadra Keycloak + Argo CD + Crossplane.

## 4. Lo que NO decide esta comparación

- **Si debes construir un IDP ya.** Si no tienes golden paths (`plat-02`), ninguna de las dos te salvará; mejor documenta primero.
- **Qué hace tu organización única.** Un portal estándar no diferencia; **tus** golden paths sí.
- **Si tu equipo se compromete.** Herramienta sin dueño = portal muerto en 12 meses, independientemente de la elección.

## 5. Preguntas de autocomprobación

1. ¿Por qué Backstage es "bajo lock-in" aunque sea una app custom tuya?
2. ¿Qué significa que Port tenga "lock-in medio-alto" si tu catálogo está en YAML?
3. Si tu principal preocupación es la velocidad de onboarding, ¿cuál eliges y por qué?
4. Si tu principal preocupación es construir un plugin de Kubernetes con la UI exacta que tus SREs quieren, ¿cuál eliges y por qué?
5. ¿En qué escenario tiene sentido **empezar con Port** y **planear migrar a Backstage** en 18–24 meses? ¿Qué lecciones migran y cuáles no?
