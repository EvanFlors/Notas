# Ejemplo 02 — CNOE overview: la reference stack CNCF

> Lectura y análisis. Sin ejecución. Objetivo: entender **qué resuelve CNOE que Backstage solo no**, y cuándo tiene sentido adoptar la stack preensamblada.

## 1. Qué es (y qué no es) CNOE

**CNOE** = *Cloud Native Operational Excellence*. Es:

- Una **iniciativa de usuarios finales** (Adobe, Autodesk, AT&T, Twilio, otros) alojada en la CNCF.
- Un **conjunto de recomendaciones + manifests + un installer** (`idpbuilder`) que ensambla proyectos CNCF existentes en una plataforma coherente.
- Un **"golden path para construir el golden path"**: en vez de decidir por tu cuenta "¿qué uso de auth? ¿qué de GitOps? ¿qué de infra self-service?", CNOE opina.

CNOE **no es**:

- Un producto SaaS. Nadie te vende CNOE; tú despliegas los componentes.
- Un reemplazo de Backstage. Backstage **es** uno de los componentes de la stack.
- Una abstracción nueva. Son los proyectos CNCF que ya conoces, ensamblados.

## 2. Composición típica

```
┌──────────────────────────────────────────────────────────────────────┐
│                       Developer (laptop / IDE)                       │
└───────┬──────────────────────────────────────────┬───────────────────┘
        │                                          │
        │ UI/Portal                                │ CLI/kubectl (opcional)
        ▼                                          ▼
┌───────────────────┐                        ┌─────────────┐
│    Backstage      │                        │   kubectl   │
│  - Catalog        │                        └─────────────┘
│  - Templates      │
│  - TechDocs       │
│  - K8s plugin     │
│  - Argo CD plugin │
└────────┬──────────┘
         │ OIDC
         ▼
┌───────────────────┐
│    Keycloak       │   ← Identity provider (users, groups, roles)
└───────────────────┘

         Scaffold step creates PR / manifests
                 │
                 ▼
┌───────────────────────────────────────────────────────────┐
│                     Git repository                        │
│   apps/           infra/                                  │
│   my-service/     claims/                                 │
│     Chart.yaml      postgres-dev.yaml (XR Claim)          │
└───────┬───────────────────────────────┬───────────────────┘
        │ sync                          │ sync
        ▼                               ▼
┌───────────────────┐           ┌───────────────────┐
│     Argo CD       │           │     Argo CD       │
│  (apps project)   │           │ (platform project)│
└────────┬──────────┘           └────────┬──────────┘
         │ apply                          │ apply
         ▼                                ▼
┌───────────────────┐           ┌───────────────────┐
│   Kubernetes      │           │   Crossplane      │
│   (workloads:     │           │   XRDs / Comps    │
│   Deployments,    │ ◀──────── │   Providers       │
│   Services,       │  provides │   (AWS/GCP/...)   │
│   Ingresses)      │ cloud res │                   │
└───────────────────┘           └────────┬──────────┘
                                         │
                                         ▼
                                 ┌───────────────────┐
                                 │  Cloud / On-prem  │
                                 │  (RDS, S3, VPC…)  │
                                 └───────────────────┘

   Opcional:
   ┌───────────────────┐
   │  Argo Workflows   │   ← Jobs del Scaffolder/CI que no caben
   │                   │     en GitHub Actions / Argo Events
   └───────────────────┘
```

## 3. Qué resuelve CNOE que Backstage *vanilla* no

Backstage por sí mismo responde:

- *"¿Dónde está el catálogo de servicios?"* → Catalog.
- *"¿Cómo creo un servicio nuevo?"* → Scaffolder templates.
- *"¿Dónde están los docs?"* → TechDocs.

Pero **deja abierto** (y son decisiones no triviales):

- *"¿Cómo deployo lo que el template genera?"* → ¿Argo CD? ¿Flux? ¿GitHub Actions?
- *"¿Cómo autentico developers?"* → ¿Keycloak? ¿Google? ¿Okta?
- *"¿Cómo expongo recursos cloud self-service?"* → ¿Crossplane? ¿Terraform via Atlantis?
- *"¿Cómo corren mis workflows internos?"* → ¿Argo Workflows? ¿GHA? ¿Tekton?

CNOE **opina**: Keycloak + Argo CD + Crossplane + Argo Workflows. Ganas:

- **Menos decisiones triviales** al arrancar.
- **Integraciones ya cableadas** (p. ej. Backstage plugin de Argo CD con el namespace esperado, provider OIDC apuntando a Keycloak).
- **Un camino de upgrade probado** por otros usuarios del grupo CNOE.

## 4. `idpbuilder`: el installer local

CNOE publica `idpbuilder`, un binario Go que levanta la stack completa **en un cluster Kind local** para que puedas:

- Ver el ensamble funcionando end-to-end en tu laptop.
- Experimentar con XRDs/Compositions antes de llevarlos a prod.
- Hacer demos reproducibles del flujo "scaffold → GitOps → provisioning".

No es un producto de producción; es el **playground oficial** para explorar la stack.

> En este módulo **no** se ejecuta `idpbuilder`. La exploración práctica llega en `plat-04` (Backstage), `plat-06` (Scaffolder) y `plat-09` (Crossplane).

## 5. Cuándo tiene sentido CNOE

Encaja bien cuando:

- Organización **CNCF-first**: ya hay K8s productivo, familiaridad con Helm, GitOps, operadores.
- Equipo plataforma con **al menos 2–3 ingenieros** cómodos con el ecosistema.
- Se quiere un **IDP 100 % OSS** sin lock-in de vendor por filosofía, compliance o costo.
- Se valora empezar con una **referencia opinionada** en vez de 10 decisiones de ensamble.

Encaja mal cuando:

- Equipo pequeño sin experiencia operando los componentes CNCF individualmente — **CNOE no reduce** la carga de operación de Backstage + Argo CD + Crossplane + Keycloak, la **ordena**.
- Organización sin inversión en K8s/Crossplane; el valor marginal de "self-service DB via XRD" no justifica la curva.
- Prioridad absoluta de time-to-first-value < 2 semanas (ahí es Port, no CNOE).

## 6. Lo que CNOE NO decide por ti

- **Qué templates publicar**: la disciplina de golden paths (`plat-02`) sigue siendo tuya.
- **Qué modelar en el catálogo**: la disciplina de catálogo (`plat-05`) sigue siendo tuya.
- **Qué scorecards aplicar**: `plat-10`.
- **Cómo gobernar** multi-tenancy, deprecations, SLOs de plataforma: `plat-12`.

CNOE acelera el **arranque técnico**. La **disciplina de producto plataforma** no viene en la caja.

## 7. Preguntas de autocomprobación

1. ¿Cuáles son los **5 componentes** típicos de la stack CNOE y qué rol cumple cada uno?
2. ¿Por qué CNOE *no* es un producto SaaS?
3. Si una organización ya tiene Argo CD en producción pero sin Crossplane ni Keycloak, ¿CNOE le ahorra algo? Argumenta.
4. ¿En qué se parece y en qué se diferencia CNOE de "un chart de Helm que levanta Backstage"?
5. Si tu dolor principal es "no sabemos qué servicios están desplegados y de quién son", ¿CNOE lo resuelve? ¿O estás optimizando el componente equivocado?
