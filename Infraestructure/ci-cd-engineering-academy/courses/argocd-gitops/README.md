# Curso: Argo CD y GitOps

Roadmap especializado #9. GitOps como *modelo operativo* y **Argo CD** como implementación de referencia. Flux se trata al final como alternativa comparada, no como curso aparte. **Argo Rollouts** se incluye por su integración natural con progressive delivery sobre GitOps.

## 1. Introducción

### Qué es

**GitOps** es un modelo operativo en el que **Git es la fuente de verdad del estado deseado del sistema** y un agente en el cluster **continuamente reconcilia** la realidad con lo que dice Git. Combina cuatro propiedades:

1. **Declarativo**: el estado deseado se expresa como datos (manifests YAML, Helm charts, Kustomize overlays), no como scripts.
2. **Versionado y auditable**: todo cambio pasa por Git (commits, PRs, revisores, rulesets).
3. **Pulled**: un agente *dentro* del cluster hala desde Git. No hay un pipeline externo con credenciales de admin del cluster.
4. **Reconciliado continuamente**: el agente compara desired vs actual permanentemente y actúa.

**Argo CD** es la implementación GitOps más adoptada: un operador para Kubernetes que gestiona *Applications* (CR propio) donde cada Application dice "aplica el manifiesto que vive en *tal* repo/path/revisión en *tal* cluster/namespace, con *tal* política de sync".

### Historia (síntesis)

- **2017** — Weaveworks acuña el término *GitOps* describiendo el modo en que operaban sus clusters internamente.
- **2018** — Nace **Argo CD** en Intuit; **Flux v1** por Weaveworks.
- **2020** — Argo CD y Flux se incorporan a la CNCF.
- **2021** — Argo CD gana adopción rápida; **Flux v2** se rediseña como set de controllers modulares (`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`, `image-automation-controller`).
- **2022+** — **ApplicationSets** maduran (clusters, Git generators, PR generators); **Argo Rollouts** se consolida para blue/green y canary nativo; **GitOps Working Group** publica los **principios formales** (declarative, versioned & immutable, pulled automatically, continuously reconciled).
- **2024+** — Multi-source Applications GA, mejoras de UX, integraciones con **OIDC/SSO**, policies vía Argo CD + Kyverno/OPA.

### Problemas que resuelve

- **Deriva** (drift) entre el estado del cluster y lo que vive en los repos.
- **Credenciales de larga vida** necesarias por pipelines externos para hacer `kubectl apply` al cluster.
- **Auditoría débil**: cambios aplicados sin PR, sin revisor, sin trazabilidad.
- **Rollback complejo**: en pull-based el rollback es *revertir el commit en Git*.
- **Multi-cluster** desorganizado: cada equipo con su pipeline y sus credenciales.

### Casos de uso

- Despliegue continuo multi-ambiente (dev → stg → prod) por promoción de refs.
- Bootstrap y gestión de **add-ons del cluster** (ingress, cert-manager, Prometheus Operator, OPA/Kyverno, el propio Argo CD).
- **Fleet management**: muchos clusters desde un pane of glass.
- **Preview environments** por PR.
- Fundamento de **plataformas internas** (IDP) junto a Backstage/Crossplane.

### Arquitectura general

```
┌──────────────────────────────────────────────┐
│ Repos Git (fuente de verdad)                 │
│  - app manifests / Helm charts / Kustomize   │
│  - infra configs                             │
│  - env overlays, values por entorno          │
└──────────────────────────────────────────────┘
             ▲         │ pull (polling + webhook)
             │         ▼
┌──────────────────────────────────────────────┐
│ Argo CD (en el cluster, o en un cluster      │
│  "control plane")                            │
│   argocd-server       (UI, API, gRPC)        │
│   application-controller (reconcilia Apps)   │
│   repo-server          (renderiza manifests) │
│   redis                (caché)               │
│   notifications-controller                   │
│   applicationset-controller                  │
│   dex (opcional, OIDC)                       │
└──────────────────────────────────────────────┘
             │ apply vía API server
             ▼
┌──────────────────────────────────────────────┐
│ Cluster(s) target                            │
└──────────────────────────────────────────────┘
```

El patrón canónico "**app of apps**" o, mejor hoy, **ApplicationSet**, bootstrappea los demás Applications desde Git — un commit en el repo "de bootstrap" basta para que el cluster se auto-construya.

### Alternativas

- **Flux v2** — modular, muy limpio, menos UI que Argo CD; cultura "GitOps-only" más estricta.
- **Pipelines push tradicionales** (`kubectl apply` desde CI) — anti-GitOps en el sentido estricto; aún presentes en muchas empresas.
- **Jenkins X / Spinnaker** — otros approach; en declive comparativo frente a Argo CD/Flux.
- **Crossplane** — IaC *como control plane de K8s*; complementario a Argo CD (los recursos Crossplane también pueden gestionarse por GitOps).

### Ventajas / limitaciones

**Ventajas**: trazabilidad, rollback trivial, menor superficie de credenciales, DX uniforme, multi-cluster, encaja con PR workflows y branch protection.

**Limitaciones / riesgos**:
- Introduce **nueva complejidad**: Argo CD mismo debe operarse, actualizarse y asegurarse.
- **Secretos** con GitOps requiere disciplina (SOPS/ESO/Vault/Sealed Secrets — nunca secretos en claro en Git).
- **Promoción** entre ambientes requiere diseñar el patrón (por branch, por ref, por overlay, por image updater).
- **Operaciones manuales** (p. ej. `kubectl scale` ad-hoc) son revertidas por el agente — es lo correcto pero sorprende a equipos no acostumbrados.
- Argo CD **"corre con permisos de dios"** sobre los clusters target: su RBAC propio y su backup son críticos.

### Relación con el programa

- Consume **Helm charts** (curso anterior) como una de sus fuentes principales.
- Target natural de **GitHub Actions** → el pipeline *no despliega*, solo *modifica Git* (image tag bump, PR al repo de infra).
- Es el "último paso" de la cadena **DevSecOps** del programa: imagen firmada → verificada en admisión → desplegada por GitOps.
- Fundamento del capstone: dev/stg/prod via Argo CD + ApplicationSet.

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **kubernetes** ≥ Nivel 2–3 (Deployments, RBAC, CRDs). Curso **git-and-github** completo. |
| Recomendados | Curso **helm** completo. Curso **github-actions** (para el "pipeline sin credenciales de cluster"). |
| Complementarios | Curso **docker** Nivel 4 (firma de imágenes para la cadena DevSecOps). |

## 3. Organización (4 niveles)

El curso tiene **13 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (3): principios GitOps + comparación Argo CD/Flux, instalación y primera Application, anatomía de Application (source, destination, sync).
- **Nivel 2 — Intermedio** (4): sources (plain YAML, Helm, Kustomize, Jsonnet, multi-source), sync strategies (auto-sync, self-heal, prune, waves, hooks), Projects (RBAC + boundaries), ApplicationSets (generators).
- **Nivel 3 — Avanzado** (4): multi-cluster + bootstrap patterns, secretos en GitOps (SOPS, Sealed Secrets, ESO, Vault), **Argo Rollouts** (progressive delivery), internals + seguridad de Argo CD.
- **Nivel 4 — Producción empresarial** (2): platform patterns (bootstrap repo, promoción entre ambientes, PR previews, observabilidad de Argo CD), **Flux como alternativa comparada**.

## 4. Entregables del curso

- Argo CD instalado y gestionado por sí mismo (GitOps bootstrap).
- Repositorio "de infra" con app-of-apps / ApplicationSet para dev/stg/prod del capstone.
- Promoción entre entornos via branch + merge PR + auto-sync.
- Secretos del capstone gestionados con **External Secrets Operator** o SOPS (no en claro en Git).
- Blue/green o canary con **Argo Rollouts** y analysis template.
- Pipeline GHA que **solo** actualiza el tag de imagen en el repo de infra (sin credenciales de cluster).
- ADR Argo CD vs Flux fundamentado.

## 5. Evaluación

- **Conceptual**: definir GitOps con los 4 principios; explicar por qué pull > push; diferenciar app-of-apps vs ApplicationSet; qué resuelven SOPS/Sealed Secrets/ESO y cuándo elegir cada uno.
- **Operativa**: bootstrap de cluster vacío a estado objetivo con un `apply` inicial; promoción dev→stg→prod; recuperación tras pérdida de Argo CD; rollout canary con auto-promotion.
- **Arquitectónica**: diseñar la estrategia de promoción (branch vs overlay vs image updater); modelo multi-cluster; RBAC + Projects para una org multi-tenant; dónde Argo CD cede a Flux o a Crossplane.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial Argo CD (`argo-cd.readthedocs.io`), Argo Rollouts, Argo Events, Argo Workflows.
- Documentación oficial Flux v2 (`fluxcd.io/flux/`).
- **OpenGitOps** principles (`opengitops.dev`) — definición formal del grupo de trabajo CNCF.
- Documentación de ApplicationSets generators (list, cluster, git, matrix, SCM, pullrequest).
- SOPS, Sealed Secrets, External Secrets Operator, Vault docs.
- *Codefresh* y *Akuity* (fundadores/mantenedores de Argo CD) blogs técnicos.
