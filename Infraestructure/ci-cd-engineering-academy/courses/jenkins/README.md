# Curso: Jenkins (contexto empresarial)

Roadmap especializado #17. **Curso corto de contexto**, no "camino moderno". Jenkins sigue siendo ampliamente usado en empresas tradicionales (banca, telecom, industria, gobierno), por **inercia operativa** y por décadas de pipelines, shared libraries y plugins acumulados. Este curso te prepara para **operar, mantener, auditar y eventualmente migrar** entornos Jenkins reales, no para elegirlo como stack nuevo en 2026.

## 1. Introducción

### Qué es

**Jenkins** es un servidor de automatización de código abierto escrito en Java. Expone una API y una UI web para definir y ejecutar **jobs** (unidad mínima) organizados en **pipelines** declarativos o scripted (DSL basado en Groovy). Un **controller** (anteriormente "master") orquesta y schedulea trabajos a **agents** (anteriormente "slaves") que ejecutan efectivamente los jobs.

Características que lo definen:

- **General-purpose**: no está casado con una tecnología. Puede construir, testear, desplegar, orquestar cualquier cosa que corra en un shell.
- **Ecosistema de plugins masivo** (~1800): fuente de poder y de fragilidad.
- **Modelo clásico pull-less**: push por SCM webhooks o pull periódico.
- **Groovy DSL** (declarative + scripted) para pipelines versionados en el repo (**Jenkinsfile**).
- **Agents** heterogéneos (shell, SSH, Docker, Kubernetes) para distribuir carga.

### Historia (síntesis)

- **2004** — Kohsuke Kawaguchi (Sun Microsystems) crea **Hudson**.
- **2011** — Fork por disputa con Oracle → nace **Jenkins**.
- **2016** — Pipeline-as-code (`Jenkinsfile`); **Blue Ocean** UI.
- **2017** — **Declarative Pipeline** (sintaxis estructurada sobre scripted); **Jenkins Configuration as Code (JCasC)**.
- **2019+** — Kubernetes plugin maduro; **Jenkins X** intenta reposicionar (no toma tracción comparado con Argo CD).
- **2022+** — Jenkins LTS continúa releases; **CloudBees** (empresa principal) orienta oferta a enterprise. GitHub Actions, GitLab CI, Argo CD/Workflows ganan mindshare.
- **2024+** — Jenkins permanece como estándar de facto en brownfield enterprise, pero rara vez se elige para nuevos proyectos greenfield fuera de ciertos entornos regulados.

### Problemas que resuelve (desde la perspectiva "¿por qué todavía existe?")

- **Décadas de automatización ya escritas**: pipelines, shared libraries, plugins custom, jobs legados. Reemplazarlos es costoso.
- **Flexibilidad extrema**: Groovy + shell + plugin para todo. En orgs con infraestructura heterogénea (mainframe + Linux + Windows + bare metal + VMware + K8s + appliances), Jenkins "simplemente funciona".
- **Self-hosted real**: no SaaS obligatorio. Deployable en cualquier entorno air-gapped.
- **Enterprise support** vía CloudBees (CI/CD, feature-flags, insights).
- **Compliance / change-management** heredado: pipelines auditados por décadas, con firmas y approvals integrados.

### Casos de uso típicos hoy

- Mantener y evolucionar pipelines heredados.
- Entornos **air-gapped** y **on-prem** sin dependencia de SaaS.
- Workloads **non-cloud-native** (mainframe, builds muy largos, integración con legacy enterprise).
- **Puente** mientras se migra a GHA/GitLab/Argo.
- **Compliance-heavy** industries donde el cambio tecnológico es más lento que la evolución del tooling.

### Arquitectura general

```
┌───────────────────────────────────────────────┐
│ Jenkins Controller (JVM)                      │
│   - UI (Jetty), API REST, Jenkinsfile parser  │
│   - Scheduler, Build queue                    │
│   - Plugin manager                            │
│   - Credentials store                         │
│   - JCasC config / Job DSL                    │
└───────────────────────────────────────────────┘
            │
            │ SSH / JNLP / inbound agent protocol
            ▼
┌───────────────────────────────────────────────┐
│ Agents                                        │
│   - permanent (VM, bare metal)                │
│   - ephemeral (Docker container, K8s pod)     │
│   - cloud (EC2/GCE/Azure plugins)             │
└───────────────────────────────────────────────┘
```

En Kubernetes se usa el **Kubernetes plugin**: cada build spawnea un Pod efímero como agent. Es el patrón moderno dentro de Jenkins — convergente conceptualmente con **ARC** de GitHub Actions.

### Alternativas y recomendación

- **GitHub Actions / GitLab CI/CD**: estándar moderno. En greenfield, elegir uno de los dos salvo justificación específica.
- **Argo Workflows**: pipelines K8s-native basados en CRDs. Reemplazo natural para muchos workloads que hoy corren en Jenkins + Kubernetes plugin.
- **Tekton**: pipelines K8s-native, estándar CNCF, menos adoptado pero técnicamente limpio.
- **CircleCI, Buildkite, Drone, TeamCity, Bamboo**: alternativas comerciales/OSS variadas.

**Recomendación del programa**: Jenkins como *lo que ya está*, no como *lo que elegirías*.

### Ventajas / limitaciones

**Ventajas**:
- Ecosistema de plugins amplio para casi todo.
- Totalmente open source y self-hostable.
- Comunidad grande, docs abundantes, talento disponible.
- Pipelines Groovy pueden expresar cualquier flujo imaginable.
- Enterprise support maduro (CloudBees).

**Limitaciones / riesgos**:
- **Plugins = superficie de riesgo**: cada plugin es código Java/Groovy adicional; CVEs de plugins son frecuentes; mantenimiento de versiones es trabajo real.
- **Controller single-point-of-failure clásico**. HA real requiere ingeniería no trivial (CloudBees CI, operator Jenkins Operator, o diseño activo-pasivo).
- **Operación constante**: upgrades, backups, scaling de agents, DR.
- **Groovy sandbox + script approvals**: fricción real para pipelines complejos.
- **UX**: muy inferior a Actions/GitLab para equipos modernos.
- **Difícil de reasonar como código versionado** cuando se mezclan freestyle jobs legacy + pipelines + system config no versionada.
- **Supply chain**: muchas instalaciones no tienen SBOM/firmas; incidentes recurrentes.
- **Kubernetes-native workflows**: Argo CD/Workflows/Tekton suelen ser mejores encajes que Jenkins + Kubernetes plugin para nuevos workloads.

### Relación con el programa

- Curso de **contexto obligatorio** si vas a trabajar en una org con Jenkins legado (es decir, muchas).
- Marca explícitamente *qué sí* y *qué no* portar del modelo mental Jenkins al stack moderno.
- Prepara para **migraciones** (uno de los problemas reales de 2026 es "sacar a Jenkins" con control de riesgos).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | **Curso `github-actions`** (necesario para comparar modelos CI/CD modernos). Curso **docker**. T-2.6 (Bash) y nociones básicas de Groovy (lectura, no escritura masiva). |
| Recomendados | Curso **kubernetes** ≥ Nivel 2 (para Kubernetes plugin). Curso **git-and-github**. |
| Complementarios | Curso **devsecops** ≥ Nivel 2 (para auditar instalaciones legacy). |

## 3. Organización (4 niveles)

El curso tiene **8 módulos**. Es el más corto del programa — por diseño.

- **Nivel 1 — Fundamentos** (2): qué es Jenkins + por qué todavía existe + cuándo NO elegirlo, instalación + Freestyle vs Pipeline + primer job.
- **Nivel 2 — Intermedio** (3): Declarative Pipeline + Jenkinsfile, Scripted Pipeline + Shared Libraries, agents + distributed builds + Kubernetes plugin.
- **Nivel 3 — Avanzado** (2): plugins ecosystem + JCasC + Job DSL + Blue Ocean, seguridad (RBAC, credentials binding, script approvals, hardening).
- **Nivel 4 — Producción empresarial** (1): operar Jenkins a escala + **migration path** a GHA/GitLab/Argo (foco realista: cómo *salir* de Jenkins con control).

## 4. Entregables del curso

- Instalación local de Jenkins (Docker/K8s plugin) con JCasC y Shared Library.
- Jenkinsfile declarative que replica el pipeline del capstone (lint/test/build/push/deploy).
- Shared Library propia versionada en Git con 2+ steps compartidos.
- Audit report de un Jenkins "sucio" con lista priorizada de hallazgos (plugins obsoletos, credentials en texto, pipelines no versionados).
- ADR + runbook de migración de un pipeline Jenkins a GHA o GitLab, con dual-run.

## 5. Evaluación

- **Conceptual**: diferenciar Declarative vs Scripted; qué hace Groovy sandbox y por qué existe; agents permanent vs ephemeral; cuándo Jenkins y cuándo *definitivamente no*.
- **Operativa**: escribir y leer un Jenkinsfile declarative + un step en shared library; configurar un Jenkins con JCasC desde cero; usar Kubernetes plugin para agents efímeros.
- **Arquitectónica**: diseñar plan de migración de Jenkins a GHA/GitLab/Argo con control de riesgo; defender el plan contra "si funciona no lo toques".

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial `jenkins.io/doc`.
- *Jenkins Handbook* y *Pipeline Steps Reference*.
- JCasC docs (`plugins.jenkins.io/configuration-as-code`).
- Kubernetes plugin docs.
- CloudBees docs (para contexto enterprise).
- Jenkins Security Advisories (lista pública; muy frecuentes).
- CNCF landscape (para comparar con Argo Workflows / Tekton).
