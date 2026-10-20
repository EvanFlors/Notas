# Curso: Platform Engineering

Roadmap especializado #13. **Capstone pedagógico** del programa: integra todo lo aprendido en una práctica de disciplina de ingeniería de plataformas. Cubre:

- **Principios**: Team Topologies, cognitive load, platform-as-a-product.
- **Golden paths / paved roads** y developer experience.
- **Backstage** como IDP de referencia (catalog, templates, TechDocs, plugins).
- **Alternativas** (Port, OpsLevel, Humanitec, CNOE stack).
- **Self-service infra** con **Crossplane** y módulos Terraform expuestos vía Backstage.
- **Scorecards** y madurez de servicio.
- **Métricas de plataforma** (DORA, SPACE, platform NPS, time-to-first-commit).
- **Gobernanza y escalado**: policies, deprecations, multi-tenancy, platform SLOs.

## 1. Introducción

### Qué es

**Platform Engineering** es la disciplina de **construir y operar una plataforma interna** que reduce la **carga cognitiva** de los equipos de producto y les permite entregar valor más rápido, con calidad, seguridad y confiabilidad consistentes.

Un **Internal Developer Platform (IDP)** es el conjunto de servicios, herramientas, templates, documentación y automatización que los equipos de producto consumen *sin tener que operar la infraestructura subyacente*. Es un **producto interno**, no un proyecto one-shot.

Dos ideas rigen el curso:

1. **La plataforma es un producto.** Tiene usuarios (desarrolladores), un roadmap, telemetría, feedback loops, SLOs y, idealmente, financiamiento explícito. No es "lo que sobra después de operar".
2. **Golden paths > frameworks genéricos.** Un camino "feliz" opinionado y bien soportado (lenguaje X + framework Y + logging Z + deploy K8s + GitOps) *reduce* la variedad y multiplica la velocidad del equipo entero. No todo tiene que soportarse al mismo nivel.

### Historia (síntesis)

- **2015–2018** — Netflix publica *Full Cycle Developers*, Spotify abre **Backstage** como herramienta interna.
- **2020** — Backstage se dona a la CNCF (incubación). *Team Topologies* (Skelton & Pais) populariza el modelo "stream-aligned / enabling / platform / complicated-subsystem".
- **2021** — Humanitec lanza; nace la comunidad **PlatformCon**.
- **2022** — **CNCF Platforms White Paper**; **CNOE** (Cloud Native Operational Excellence) formaliza un stack de referencia.
- **2023+** — Backstage graduation en incubación avanza; competidores comerciales (Port, OpsLevel, Cortex) crecen; **Crossplane** se consolida como control plane IaC adoptado por platform teams.
- **2024+** — Métricas DORA/SPACE se vuelven estándar; **platform-as-a-product** es el framing dominante.

### Problemas que resuelve

- **Cognitive overload** del equipo de producto cuando debe conocer K8s + Terraform + CI/CD + observabilidad + seguridad + cloud por sí mismo.
- **Variedad fragmentada**: 20 microservicios con 20 formas distintas de deploy, 15 lenguajes, 8 proveedores de alertas.
- **Visibilidad pobre**: nadie sabe qué servicios existen, quién los opera, qué tan maduros son.
- **Fricción al onboarding**: un nuevo servicio tarda semanas antes del primer deploy a prod.
- **Falta de accountability**: ownership difuso, SLOs ausentes, documentación inexistente.
- **Riesgo de seguridad y compliance** por caminos ad-hoc.

### Casos de uso

- Portal interno con **catálogo** de servicios, APIs, docs, dashboards, alertas, dueños.
- **Scaffolder** para crear un nuevo microservicio en 5 minutos con pipeline + K8s + observabilidad + seguridad ya cableados.
- **Self-service infra**: un dev crea una DB Postgres pidiendo un `CompositeResourceClaim` que materializa un stack cloud via Crossplane.
- **Scorecards** de madurez: cada servicio tiene una nota (tests coverage, SLO definido, docs actualizadas, imagen firmada, on-call registrado).
- **Métricas DORA** en pantalla para equipos y para liderazgo.

### Arquitectura general (CNOE-like reference stack)

```
┌───────────────────────────────────────────────────────────┐
│ Developer                                                 │
│   crea PR, pide nuevo servicio, consulta docs/alertas     │
└───────────────────────────────────────────────────────────┘
             │
             ▼
┌───────────────────────────────────────────────────────────┐
│ IDP UI: Backstage (o Port / OpsLevel / Cortex / Humanitec)│
│   - catalog (services, APIs, systems, resources)          │
│   - templates (scaffolder)                                │
│   - techdocs                                              │
│   - scorecards                                            │
│   - plugins (CI, K8s, cost, SLO, …)                       │
└───────────────────────────────────────────────────────────┘
             │
   ┌─────────┼───────────────┬─────────────┬──────────────┐
   ▼         ▼               ▼             ▼              ▼
GitHub   GitHub Actions   Argo CD       Kubernetes     Crossplane
(SoR)    (CI, OIDC)       (GitOps)      (K8s)          (IaC CRs)
                                                        │
                                                        ▼
                                              Cloud (AWS/GCP/Azure)
```

Backstage es "el pane of glass". Los sistemas reales siguen siendo los de todos los cursos anteriores: Git, GHA, Argo CD, K8s, Terraform/Crossplane, Prometheus/Grafana, Vault, Kyverno, cosign, etc.

### Alternativas

**IDP OSS**: **Backstage** (líder OSS); **CNOE** (stack de referencia completo); **Port**, **OpsLevel**, **Cortex** (comerciales con UX más pulida y menos ingeniería interna); **Humanitec** (platform orchestrator opinionado).

**Self-service infra**: **Crossplane** (K8s-native, CRs); **Terraform via Backstage scaffolder** o **Atlantis**; **Pulumi**; **OpenTofu**.

**Pure scorecards**: **OpsLevel**, **Cortex**, **Backstage Soundcheck**.

### Ventajas / limitaciones

**Ventajas**: reducción drástica de cognitive load; estandarización sin matar innovación (opt-in paths); métricas accionables; mejor seguridad y compliance por default; retención de talento.

**Limitaciones / riesgos**:
- **Platform team mal dimensionado** se vuelve bottleneck.
- **"Build a platform because it's cool"**: construir sin usuarios reales → shelfware. Platform engineering requiere **demanda real** y **capacidad de medir adopción**.
- **Backstage es un framework de Node.js, no un producto**: requiere mantenimiento activo y expertise interna.
- **Overengineering**: con 3 microservicios no necesitas un IDP; necesitas README decentes.
- **Golden paths pueden volverse jaulas** si no evolucionan con feedback.
- **Métricas DORA mal usadas** se convierten en gaming (incentivar velocidad penalizando calidad).

### Relación con el programa

- **Es el curso capstone pedagógico**: integra Git, GHA, Docker, Terraform, AWS/GCP, Kubernetes, Helm, Argo CD, Prometheus/Grafana, OTel, DevSecOps.
- Define el **contrato** entre la plataforma y los equipos de producto para el capstone técnico.
- Introduce la práctica de **medir** la plataforma como se mide un producto.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | **Todos los cursos previos del programa** al menos a Nivel 2 (muy especialmente **git**, **github-actions**, **kubernetes**, **argocd-gitops**, **terraform**, **devsecops**). Nociones básicas de Node.js y TypeScript para Backstage. |
| Recomendados | Experiencia leyendo *Team Topologies* y familiaridad con DORA metrics. |
| Complementarios | Experiencia operativa en algún producto interno (p. ej. haber mantenido librerías compartidas). |

## 3. Organización (4 niveles)

El curso tiene **12 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (3): principios y Team Topologies, golden paths y DX, panorama de IDP tools (Backstage, Port, OpsLevel, CNOE, Humanitec).
- **Nivel 2 — Intermedio** (3): Backstage arquitectura y setup, catálogo de software en profundidad, templates/scaffolder.
- **Nivel 3 — Avanzado** (3): TechDocs, plugins (CI/K8s/obs/cost) y plugins custom, self-service de infra (Crossplane + Terraform modules vía templates).
- **Nivel 4 — Producción empresarial** (3): scorecards y madurez de servicio, métricas DORA/SPACE/NPS y platform-as-product, gobernanza a escala (multi-tenancy, deprecations, platform SLOs).

## 4. Entregables del curso

- Instalación local de Backstage con catalog poblado desde los repos del capstone.
- Template "nuevo microservicio Python": en 1 comando crea repo + CI (Actions con OIDC) + Helm chart + Argo Application + dashboards base + alertas base + CODEOWNERS + README + TechDocs.
- Plugin propio mínimo (p. ej. mostrar el estado de los deploys Argo CD en la vista del Component).
- Self-service de DB: un dev crea una Postgres managed via Crossplane claim desde Backstage.
- Scorecard con 8–10 criterios de madurez y dashboard de adopción.
- Dashboard DORA (lead time for changes, deployment frequency, change failure rate, time to restore service).
- ADR: contrato de plataforma, roadmap trimestral, política de deprecación.

## 5. Evaluación

- **Conceptual**: explicar los 4 tipos de equipo de Team Topologies; diferenciar golden path vs mandato; qué es cognitive load y cómo se mide; por qué "platform-as-a-product" y no "platform-as-a-service-provider".
- **Operativa**: montar Backstage con catalog, template y plugin; implementar self-service de un recurso cloud via Crossplane; definir y publicar scorecard; medir DORA con datos reales del CI/CD.
- **Arquitectónica**: diseñar el contrato de plataforma; priorizar el roadmap con criterios de adopción; política de deprecación; estrategia multi-tenant; cuándo *no* construir plataforma.

## 6. Recursos

A verificar en Fase 4:

- *Team Topologies* (Skelton & Pais, 2019) — libro de referencia.
- *Platform Engineering on Kubernetes* (Mauricio Salatino) y *Platform Engineering* (Fournier/Nowland, 2024).
- **Backstage** docs (`backstage.io/docs`).
- **CNOE** reference implementation (`cnoe.io`).
- **Platform Engineering** community (`platformengineering.org`, PlatformCon talks).
- *DORA State of DevOps Report* (más reciente disponible).
- *SPACE framework* (Microsoft/GitHub, Forsgren et al.).
- **Crossplane** docs (`crossplane.io/docs`).
- **CNCF Platforms White Paper**.
- Humanitec *Platform Engineering* reports.
