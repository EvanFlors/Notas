# jk-01 — Lección: por qué Jenkins sigue vivo y cuándo NO elegirlo

> 10 secciones. Enteramente conceptual. Prerrequisito: haber hecho el curso **github-actions** (sin ese referente, muchas comparaciones no aterrizan).

---

## 1. Un poco de historia (y por qué todavía importa)

Jenkins nació como **Hudson** en 2004 dentro de Sun Microsystems, escrito por Kohsuke Kawaguchi. Era un servidor Java para disparar builds Maven de forma automatizada. En 2010 Oracle compró Sun, se peleó con la comunidad por el nombre y la gobernanza, y en 2011 la comunidad hizo **fork**: nació **Jenkins**. Oracle se quedó con "Hudson", que terminó muriendo. Jenkins quedó al cuidado de la **Jenkins project** y, luego, de la **Continuous Delivery Foundation (CDF)** bajo la Linux Foundation.

Este origen explica mucho de lo que vas a ver después:

- **Está escrito en Java**, corre sobre JVM. El controller necesita heap, GC tuning, etc. No es "una app ligera".
- **Groovy** es el DSL de pipelines porque Groovy es "Java con menos ceremonia" y la JVM ya estaba.
- **Plugins** son el modelo central (hay ~1800). Cada uno es un `.hpi`/`.jpi` que corre en el mismo JVM del controller. Esto es flexible y, a la vez, la raíz de la mayoría de CVEs de Jenkins.
- **Freestyle jobs** son la UI original de 2005: formularios web que generan XML en `$JENKINS_HOME`. **Pipeline** llegó mucho después (2016) y es el modelo moderno. La coexistencia de ambos es herencia histórica.
- Jenkins fue, durante años, **el estándar de facto** de CI. En 2016–2018 cualquier empresa con un pipeline tenía Jenkins. Esa base instalada no desaparece de la noche a la mañana; de ahí la pregunta que da nombre a este módulo: **por qué sigue vivo y cuándo elegir otra cosa**.

> **Idea clave que repetiremos:** Jenkins hoy no gana por mérito técnico frente a GHA/GitLab/Argo/Tekton. Gana por **inercia operativa**: ya está, los jobs ya están escritos, la gente ya lo sabe. Migrar cuesta dinero y riesgo. La decisión racional casi nunca es "sí/no", es "cuándo y cómo".

---

## 2. Modelo mental: controller + agents, pipeline-as-code vs freestyle

Jenkins tiene **dos piezas** y **dos modelos de job**.

### 2.1 Controller + agents

```
                 ┌─────────────────────────┐
                 │      Controller         │
                 │  (ex "master" — JVM)    │
                 │  - UI, API, cola        │
                 │  - config, credentials  │
                 │  - orquestación         │
                 └───────────┬─────────────┘
                             │ TCP/JNLP o SSH
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
  ┌────────────┐      ┌────────────┐      ┌────────────┐
  │  Agent 1   │      │  Agent 2   │      │ Agent K8s  │
  │ permanente │      │ efímero    │      │ (pod)      │
  │ VM/host    │      │ Docker/EC2 │      │ 1 por build│
  └────────────┘      └────────────┘      └────────────┘
```

- **Controller** (antes "master" — el término fue renombrado en 2020): la **web UI**, la **API REST**, la **cola de builds**, el **almacén de config**, los **credentials**. Es el **single point of failure** por diseño.
- **Agents** (antes "slaves" — también renombrados): procesos que ejecutan los steps del pipeline. Pueden ser:
  - **Permanentes**: VM o host dedicado conectado por SSH o JNLP.
  - **Efímeros**: Docker container o pod K8s levantado por build y destruido al terminar. **Patrón recomendado** porque elimina contaminación entre builds.
  - **Cloud agents**: EC2/GCE/Azure spawneados on-demand por un plugin de cloud.
- **`JENKINS_HOME`**: el directorio en disco del controller donde vive **toda** la config (jobs, plugins, credentials cifrados, nodes). Sin este directorio no se reproduce el Jenkins. Ver §5.

### 2.2 Freestyle vs Pipeline

Jenkins ofrece dos formas de definir un job:

- **Freestyle**: configuración por UI (formularios). Guardada como `config.xml` dentro de `$JENKINS_HOME/jobs/<nombre>/config.xml`. **No versionada en el repo del código por defecto**. Es el modelo original y la raíz del famoso "no sé qué hace ese job, lo configuró Carlos en 2017".
- **Pipeline**: lógica en un archivo `Jenkinsfile` **dentro del repo del código**. Es **pipeline-as-code**. Dos sabores:
  - **Declarative Pipeline** (recomendado): sintaxis Groovy con estructura validada (`pipeline { stages { stage { steps { ... } } } }`). Es el default moderno. Se cubre en `jk-03`.
  - **Scripted Pipeline**: Groovy puro con `node { ... }`. Más flexible, menos checks. Común en instalaciones legacy. Se cubre en `jk-04`.

> **Regla práctica**: cualquier job **nuevo** en 2026 debe ser **Declarative Pipeline**, versionado. **Freestyle = anti-patrón heredado**. Si estás creando un freestyle "porque es más rápido", estás creando deuda técnica el día cero.

---

## 3. Por qué muchas enterprises siguen con Jenkins

Antes de criticarlo, hay que entender por qué tanta gente serie lo mantiene. Las razones legítimas:

### 3.1 Brownfield: miles de jobs ya escritos

Una enterprise mediana tiene fácilmente **500–5000 jobs** en Jenkins. Muchos son freestyle no-documentados que "hacen algo importante" (releases, builds nocturnos, cron tasks que exportan reportes). Reescribir eso es un proyecto de **persona-año**, no de sprint. La inercia es real y legítima.

### 3.2 Entornos air-gapped y on-prem

Compliance (banca, defensa, salud, telco, sector público) a menudo prohíbe pipelines corriendo en SaaS externo (GitHub.com, GitLab.com). Jenkins corre **on-prem**, dentro del datacenter, sin salir a internet. GitHub Enterprise Server y GitLab self-managed también existen, pero el coste y la operación de esos productos no es trivial. Jenkins es gratis (software) y conocido por el equipo.

### 3.3 Flexibilidad extrema

Hay **~1800 plugins**. Para casi cualquier cosa que necesites integrar (un sistema de ticketing viejo, un scanner de seguridad propietario, un repo de artefactos raro), ya existe plugin. En plataformas más jóvenes (Argo, Tekton), simplemente no hay integración y tienes que escribirla.

### 3.4 Enterprise support de CloudBees

**CloudBees** vende Jenkins empresarial: HA del controller, soporte 24×7, auditoría avanzada, release de versión soportada, y conectores enterprise. Para una org regulada que necesita "a quién llamar a las 3 AM", esto justifica el gasto.

### 3.5 Jenkins modernizado (K8s + JCasC)

Un Jenkins **actual** no se parece al de 2015. Con **Kubernetes plugin** cada build spawnea un pod efímero (equivalente a los runners de GHA en ARC). Con **JCasC** (Jenkins Configuration as Code) toda la config vive en `jenkins.yaml` versionado. Con **Shared Libraries** la lógica común se centraliza y se versiona. Un Jenkins operado así es, operativamente, muy parecido a cualquier plataforma CI moderna.

> **Honestidad intelectual**: estas razones son todas reales. **No** se trata de "los que siguen con Jenkins son dinosaurios". Se trata de reconocer **cuándo** siguen teniendo sentido y **cuándo** no.

---

## 4. Comparación brutal: Jenkins vs GHA vs GitLab CI vs Argo Workflows

Tabla densa; léela entera. Se asume Jenkins **moderno** (K8s plugin + JCasC + Shared Libraries), no un snowflake de 2016.

| Dimensión | Jenkins (moderno) | GitHub Actions | GitLab CI | Argo Workflows / Tekton |
|-----------|-------------------|----------------|-----------|-------------------------|
| **UX editor** | Groovy DSL + Jenkinsfile en repo. UI mediocre, poca autocomplete. | YAML, marketplace de actions, editor web. | YAML, templates e `include`. | YAML K8s-native (CRDs). Pensado para operadores, no para desarrolladores app. |
| **Hosting** | Self-hosted (controller + agents) o CloudBees SaaS. | SaaS (github.com) o GHES on-prem; runners self-hosted via ARC. | SaaS o self-managed. | Self-hosted en K8s siempre. |
| **Model** | Controller central, agents efímeros/permanentes. | Runner-centric (hosted o self-hosted). | Runner-centric. | Workflow como CRD; ejecuta en pods. |
| **Pipeline as code** | Sí (Jenkinsfile). | Sí (`.github/workflows/*.yml`). | Sí (`.gitlab-ci.yml`). | Sí (CRD YAML). |
| **Reutilización** | Shared Libraries (Groovy). Potente, con curva. | Reusable workflows + composite actions. | CI/CD Components + `include`. | WorkflowTemplate, ClusterWorkflowTemplate. |
| **Ecosistema** | ~1800 plugins. Enorme, variable calidad, riesgo CVE. | Marketplace amplio, calidad variable, pero curado. | Catálogo oficial de componentes. | Nativo K8s; pocos "plugins" pero muchos recursos K8s reutilizables. |
| **Seguridad** | Historial de CVEs activo (sobre todo plugins). Groovy sandbox + script approval = fricción real. | OIDC federation a clouds, permisos granulares por workflow, dependabot. | Protected branches, OIDC a clouds, auditoría integrada. | RBAC K8s nativo; service accounts por workflow. |
| **Credenciales** | Credentials store propio; integración con Vault/AWS SM/AKV. | OIDC a AWS/GCP/Azure, secretos cifrados en repo. | OIDC a clouds, variables protegidas. | Secrets de K8s o integración con External Secrets. |
| **Observabilidad** | Metrics plugin + Prometheus exporter (manual). | UI SaaS, logs integrados. | UI integrada, tracing optional. | Prometheus + Grafana + argo CLI. |
| **Operación** | Alta: controller a mantener, plugins a parchear, backup `JENKINS_HOME`. | Baja (SaaS) / media (self-hosted runners). | Baja (SaaS) / media (self-managed). | Media-alta: hay que operar el cluster y los controllers de Argo. |
| **HA / resiliencia** | Controller SPOF por diseño; CloudBees ofrece HA; alternativa activo-pasivo manual. | Alta (SaaS). | Alta (SaaS). | Alta si el cluster está bien operado. |
| **Costo software** | Gratis (open source); CloudBees paga. | Minutos gratis + pay-per-minute. | Minutos gratis + pay-per-minute (tier). | Gratis. |
| **Costo operación** | Alto (persona dedicada o fracción grande). | Bajo-medio. | Bajo-medio. | Medio (requiere skills K8s). |
| **Encaja mejor cuando…** | Brownfield, on-prem, air-gapped, equipo con experiencia Jenkins, workloads heterogéneos. | Repos en GitHub, equipo chico-mediano, cloud-native, prioridad DX. | Repos en GitLab, pipelines y SCM integrados, compliance en GitLab self-managed. | Workloads 100% K8s-native, orquestación de ML/data, equipo con buen skillset K8s. |

### 4.1 Lectura rápida

- **Si naces hoy** y tus repos están en GitHub → **GHA** por default. Jenkins solo si tienes razón específica (compliance que exige on-prem, ya existe shared library enorme, etc.).
- **Si tus repos están en GitLab** → **GitLab CI** por default. Está integrado, pipelines y MRs en el mismo producto.
- **Si tu workload es puro K8s** (ML training, data pipelines, operadores) → **Argo Workflows** (o Tekton). CI/CD de apps "normales" puede seguir en GHA; Argo brilla en lo que GHA/GitLab no cubren bien.
- **Si ya tienes Jenkins con 1000+ jobs** → **mantener + migración planificada por olas**, no "big bang". Esto es `jk-08`.

---

## 5. El `JENKINS_HOME`: el "state blob" que define todo

`$JENKINS_HOME` es un directorio en disco del controller con **toda** la config persistente:

```
$JENKINS_HOME/
├── config.xml               ← config global del controller
├── jobs/
│   └── <nombre-del-job>/
│       ├── config.xml       ← definición del job (freestyle o pipeline wrapper)
│       └── builds/          ← historial de ejecuciones
├── plugins/                 ← .hpi/.jpi instalados
├── credentials.xml          ← credentials cifrados con una key del secrets/
├── secrets/                 ← claves de cifrado + master key
├── users/                   ← usuarios locales
├── nodes/                   ← agents permanentes
└── workflow-libs/           ← cache de shared libraries
```

Consecuencias:

- Si pierdes `JENKINS_HOME` **sin backup**, **pierdes el Jenkins**. No hay reconstrucción automática.
- Si lo copias a otra máquina **con los mismos secrets/**, resuscitas el Jenkins (credentials incluidos).
- Si lo copias **sin los secrets/**, los credentials no se pueden descifrar.
- La configuración de freestyle vive aquí → **no versionada**. Es la fuente principal de "snowflake Jenkins".
- JCasC (`jk-06`) resuelve esto: declara la config en `jenkins.yaml` y Jenkins reconstruye el estado al arrancar; `JENKINS_HOME` pasa a ser cache + historial, no fuente de verdad.

> **Regla operativa**: tratar `JENKINS_HOME` como data crítica. Backup diario (Velero si corre en K8s), restore drill al menos trimestral. Un Jenkins sin backup verificado **es un incidente esperando a suceder**.

---

## 6. Cuándo Jenkins **sigue siendo** la respuesta correcta

Checklist. Si **la mayoría** aplica, Jenkins (moderno, bien operado) sigue siendo defendible:

- [ ] Ya existen cientos o miles de jobs en producción.
- [ ] El equipo tiene experiencia operativa real con Jenkins.
- [ ] El workload es heterogéneo: builds en Linux, Windows, macOS, embedded, mainframe, con requisitos específicos de agent.
- [ ] Compliance exige **on-prem** y SaaS externo está vetado (y GHES/GitLab self-managed no se van a comprar).
- [ ] Hay **CloudBees** o personal interno comprometido a parchear, actualizar y mantener.
- [ ] Las Shared Libraries encapsulan patrones org-wide y están versionadas, con tests y CODEOWNERS.
- [ ] El `JENKINS_HOME` tiene backup verificado y restore drill reciente.
- [ ] Los agents son **efímeros** (Docker o K8s), no VMs con años de contaminación.

Si tildas la mayoría → mantener Jenkins es decisión racional, no inercia.

---

## 7. Cuándo Jenkins **no** debe ser elegido para un proyecto nuevo

Checklist opuesto. Si la **mayoría** aplica, elegir Jenkins para un proyecto nuevo es un **error**:

- [ ] **Greenfield**: cero jobs legacy, cero expectativa de absorber una base previa.
- [ ] Repos en **GitHub** o **GitLab**: ya hay CI nativo integrado con el SCM.
- [ ] **Equipo pequeño** (< 5 personas) sin dedicación para operar un controller.
- [ ] Expectativa de **DX tipo SaaS**: editor web, marketplace, previsualización de workflows, status checks en PR.
- [ ] Workloads **100% K8s-native** (ML training, batch processing, GitOps): Argo Workflows / Tekton encajan mejor.
- [ ] Sin presupuesto para **personal dedicado** a operar Jenkins.
- [ ] Sin tolerancia a la **superficie de CVEs** de plugins (ver §9).
- [ ] Prioridad por **OIDC federation** a clouds sin credenciales de larga vida (GHA/GitLab/Argo lo hacen limpio; Jenkins también pero con más plumbing).

Si tildas la mayoría → **cualquier otra herramienta** será una mejor elección. "Pero conocemos Jenkins" no supera a los costos de operación recurrente.

---

## 8. Framework de decisión de migración (preview de `jk-08`)

Si ya tienes Jenkins y estás evaluando migrar, el framework es siempre el mismo:

### 8.1 Inventario

- Lista **todos** los jobs. Incluye freestyle "fantasma" (los que nadie recuerda haber creado).
- Para cada uno: dueño, última ejecución, criticidad, dependencias (plugins, credentials, agents especiales), destino (deploy a dónde).

### 8.2 Clasificación

Cada job cae en una de estas categorías:

- **Migrar**: tiene valor, se puede expresar en la plataforma target.
- **Consolidar**: duplica a otro job; se fusionan.
- **Retirar**: no se usa, nadie lo defiende; se apaga tras aviso.

Regla práctica: 20–40% de los jobs se **retiran** sin reemplazo. Esto solo ya justifica el ejercicio.

### 8.3 Elección de target

- **GHA** si repos en GitHub.
- **GitLab CI** si repos en GitLab.
- **Argo Workflows / Tekton** si workloads K8s-native puros.
- Puede ser **más de uno** (p. ej. GHA para CI de apps + Argo para pipelines de datos).

### 8.4 Dual-run

- Los jobs migrados corren en **ambos** sistemas en paralelo durante N semanas.
- Se comparan outputs y runtime.
- Solo cuando el equipo confía en el nuevo, se apaga el viejo.

### 8.5 Credenciales → OIDC federation

- Reemplazar `withCredentials` + secretos de larga vida por **OIDC federation** al cloud (GHA → AWS/GCP/Azure sin claves estáticas).
- Esto es casi siempre **ganancia neta** de seguridad, independientemente de la herramienta destino.

### 8.6 Retirada de Jenkins

Solo cuando:

- **Todos** los pipelines están migrados o retirados.
- El equipo está cómodo con el target.
- Hay **backup histórico** de ejecuciones archivado (compliance puede pedirlo años después).
- Hay **ADR final** firmado documentando criterios, timeline, riesgos y plan de rollback.

### 8.7 El error típico

El error más caro es intentar un **big-bang** (apagar Jenkins el viernes, encender target el lunes). Nunca funciona. Se migran olas de 10–50 jobs, con dual-run, hasta que la base está vacía.

---

## 9. El problema de la superficie de CVEs

Jenkins tiene un **feed de advisories activo** (`https://www.jenkins.io/security/advisories/`). La mayoría de CVEs son **de plugins**, no del core. Un Jenkins "pobremente mantenido" acumula plugins viejos y vulnerables con velocidad.

Reglas defensivas (profundiza `jk-07`):

- **Reducir plugins instalados** al mínimo necesario. Cada plugin es superficie de ataque.
- **Pinnear versiones** (no "latest ciego"), actualizar con disciplina (ventana mensual).
- **Habilitar auto-notificaciones** del feed oficial.
- **Deshabilitar anonymous read**, **CSRF protection on**, **agents-to-controller access control** restrictivo.
- **Groovy sandbox + script approval**: fricción real para admins, pero obligatorio.

Para una enterprise, "mantener Jenkins seguro" **cuesta tiempo recurrente**. Ese tiempo debe entrar en la estimación de costo de la actividad `02`.

---

## 10. Qué llevarte de este módulo

1. **Jenkins no está muerto**. En 2026 sigue siendo defendible en escenarios concretos: brownfield enterprise, on-prem/air-gapped, equipos con experiencia, workloads heterogéneos.
2. **Jenkins no es la respuesta por default**. Para greenfield cloud-native, equipo pequeño, repos en GitHub/GitLab, hay opciones objetivamente mejores en DX, operación y seguridad.
3. **"Migrar o no" nunca es binario**. Es un **framework** (inventario → clasificación → target → dual-run → OIDC → retirada) con horizontes de meses o años.
4. **El valor económico** se calcula explícitamente: horas de operación anual + licencias + riesgo CVE + coste humano, vs. horas de migración + coste de dual-run + aprendizaje del target.
5. **El error caro** es decidir por reflejo: "todo a Jenkins" o "fuera Jenkins ya". El entregable del módulo —ADR + estimación— entrena exactamente eso: decidir con criterio y con números.

Siguiente módulo: `jk-02-install-ui-freestyle-vs-pipeline`.
