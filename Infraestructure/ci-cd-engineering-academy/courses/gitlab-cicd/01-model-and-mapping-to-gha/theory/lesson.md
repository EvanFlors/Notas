# Lección — Modelo mental de GitLab y mapping a GitHub Actions

> Este módulo asume que **ya sabes GHA** (al menos a nivel `gha-05`). No vamos a reexplicar workflows, jobs, actions o runners desde cero. Vamos a construir el modelo mental de GitLab **por diferencias y equivalencias** con lo que ya conoces, de forma que después puedas leer un `.gitlab-ci.yml` y decir "esto es como el workflow X de GHA, pero con esta divergencia concreta".

---

## 1. Por qué este módulo existe

Las dos plataformas convergen en un **mismo problema** (CI/CD declarativo basado en YAML y runners) pero divergen en **modelo de permisos, de reuso, y de productos adyacentes** (registry, scanners, environments, agent K8s). Si entras a GitLab asumiendo que "es GHA con otra sintaxis", vas a tomar malas decisiones:

- Vas a asignar permisos usuario-por-proyecto en vez de **grupo-por-group**.
- Vas a copiar workflows a cada repo en vez de **componer** desde un **CI/CD Component** del catálogo del Group.
- Vas a abrir un ticket a cada equipo pidiendo que active scanners en vez de **inyectar** un **Compliance Pipeline** desde el Group.
- Vas a montar OIDC con el mismo `sub` claim que en GHA — y vas a fallar, porque las claims del **ID Token** de GitLab son distintas.

Este módulo construye el modelo mental para que **ninguna de esas decisiones sea un accidente**.

---

## 2. Jerarquía: Instance → Group → Subgroup → Project

GitLab organiza todo en **4 niveles** anidables:

```
Instance (gitlab.com, o tu self-managed)
└── Group (por ejemplo: "acme")
    ├── Subgroup (por ejemplo: "acme/platform")
    │   ├── Subgroup (por ejemplo: "acme/platform/runners")
    │   │   └── Project
    │   └── Project
    └── Project
```

Lo clave:

- **Group** es la **unidad de reuso y gobernanza**: comparte runners, variables, templates (`include:project:`), CI/CD Catalog, permisos, approval rules, SSO.
- **Subgroup** hereda de su padre y puede añadir sus propias configuraciones. Puedes **anidar varios niveles**.
- **Project** es el equivalente de "repo" en GitHub. Hereda de sus Groups y añade su `.gitlab-ci.yml`.
- **Instance** solo existe de forma manipulable en **Self-Managed**: ahí fijas configuraciones globales (política de cifrado, instance runners, SAML global).

Comparación directa:

| GitHub | GitLab |
|--------|--------|
| Organization | Group |
| Team | Subgroup (ergonómicamente parecido, con capacidad CI/CD extra) o grupo IdP vía SSO |
| Repository | Project |
| (no existe) | **Subgroups anidables** — GitLab permite `acme/platform/runners/k8s`, GitHub no |
| Enterprise (en GHEC/GHES) | Instance (en Self-Managed) |

**Consecuencia práctica**: en GitHub, cuando una org crece a 50 repos, acabas construyendo *topic-based grouping* y naming conventions (`acme-platform-*`, `acme-checkout-*`). En GitLab, los agrupas de verdad bajo `acme/platform/*` y `acme/checkout/*` con **permisos y runners heredados**. Esto cambia cómo diseñas la plataforma desde el día uno.

---

## 3. Modalidades de despliegue

GitLab se puede consumir en tres formas:

### 3.1 SaaS (`gitlab.com`)

- Operado por GitLab Inc. Tú solo creas usuarios y Groups.
- Hay **runners compartidos** gratuitos con límites de minutos por tier.
- Ciclo de release mensual (**día 22** de cada mes).
- No ves el host, no manejas la base de datos, no haces upgrades.

### 3.2 Self-Managed (CE / EE)

- Tú despliegas GitLab en tu infra (VM, K8s via chart, Docker Compose).
- **CE (Community Edition)**: gratis, open source. Equivalente a Free.
- **EE (Enterprise Edition)**: mismo binario con features gated por licencia (Premium / Ultimate).
- Tú operas: upgrades, backups, PostgreSQL, Redis, Gitaly, observabilidad.
- Pros: control total, aire-gapeado posible, SSO/compliance custom.
- Contras: operación continua no trivial.

### 3.3 Dedicated

- **SaaS tenant aislado** operado por GitLab, con tu propia instancia single-tenant.
- Pensado para empresas con requisitos de residencia de datos o aislamiento que SaaS multi-tenant no cumple.
- Precio y modalidad de contratación muy distintos a SaaS normal.

Comparación con GitHub:

| GitLab | GitHub |
|--------|--------|
| SaaS `gitlab.com` | GitHub.com (SaaS) |
| Self-Managed CE/EE | GitHub Enterprise Server (GHES) — GHES siempre es de pago |
| Dedicated | GitHub Enterprise Cloud with data residency (equivalente parcial) |

**Consecuencia práctica**: Self-Managed CE es una opción real para equipos pequeños sin presupuesto; en GitHub, Self-Managed (GHES) siempre cuesta. Esto puede inclinar la decisión de plataforma en una startup.

---

## 4. Planes y gating de features

GitLab tiene **tres planes** vigentes (verificar en Fase 4):

- **Free**
- **Premium**
- **Ultimate**

Qué queda gated por plan **importa muchísimo**: las features más decisivas para una org seria están **en Ultimate**, incluyendo la mayoría de scanners de seguridad nativos, compliance pipelines, security dashboard, dependency scanning avanzado, DAST, requirements management, portfolio management y audit events avanzados.

Comparación con GitHub:

| Área | GitHub | GitLab |
|------|--------|--------|
| CI/CD básico | Free/Pro/Team | Free |
| Security scanning | **GHAS** (addon separado, de pago por "committer activo") | **Ultimate** (gated por plan) |
| Compliance | GitHub Enterprise + GHAS | Ultimate |
| Approval rules multi-equipo | GHE | Premium / Ultimate |

**Consecuencia práctica**: comparar "Free vs Free" entre las dos plataformas es engañoso. La comparación real es:

- "GitHub Team + GHAS" ≈ "GitLab Ultimate" en cobertura funcional.
- Precios dependen del *billing model* (GitHub cobra GHAS por *committer activo*; GitLab por *user*).

Este punto debe estar **explícito** en cualquier ADR de plataforma.

---

## 5. Modelo de pipeline: pipeline → stages → jobs

Un **pipeline** de GitLab se compone de **stages**, y cada stage de **jobs**. Por default los jobs del stage N esperan a que **todos** los jobs del stage N-1 terminen OK; esta es la visualización canónica por columnas.

Opcionalmente, con **`needs:`** por job, el pipeline se convierte en un **DAG**: cada job solo espera a sus dependencias reales, no al stage completo. Esto reduce el wall-clock dramáticamente en pipelines reales (típicamente 20–40%).

```
      stage: build        stage: test             stage: deploy
      ┌───────────┐       ┌─────────────┐          ┌───────────┐
      │ build-api │──┬──> │ test-api    │ ──────┐  │           │
      └───────────┘  │    └─────────────┘       │  │  deploy   │
      ┌───────────┐  └──> ┌─────────────┐       ├─>│           │
      │ build-web │       │ test-web    │ ──────┘  └───────────┘
      └───────────┘       └─────────────┘
```

Con `needs:`, `test-api` **solo** espera a `build-api` (no a `build-web`). En stages puros, ambos tests esperan a que *los dos* builds terminen.

Comparación con GHA:

| GitHub Actions | GitLab |
|----------------|--------|
| `workflow` (archivo `.github/workflows/*.yml`) | `pipeline` (un `.gitlab-ci.yml` por project; opcional `include:` para dividir) |
| `job` | `job` |
| `needs: [other]` | `needs: [other]` (idéntico semánticamente) |
| `strategy.matrix` | `parallel: matrix:` |
| `uses: owner/action@v1` | `include:` (local/project/remote/template) + `extends:` + **CI/CD Components** |
| Reusable workflow (`uses: ... .yml@ref`) | **CI/CD Component** (versionable, con `spec:inputs:`, publicable al Catalog) |
| Composite action | `extends:` (hidden jobs con prefijo `.`) o CI/CD Component |

**Consecuencia práctica**: no hay un equivalente 1:1 de "action published to Marketplace" en GitLab Free. El sustituto moderno es el **CI/CD Component** publicado al **CI/CD Catalog**. En Free puedes usar `include:remote:` o `include:project:` pero sin la ergonomía (ni el gating de inputs tipados) de los Components.

---

## 6. Terminología clave

| GitHub | GitLab | Nota |
|--------|--------|------|
| Pull Request (PR) | **Merge Request (MR)** | Mismo concepto, otro nombre. Variables como `$CI_MERGE_REQUEST_IID` reemplazan a `${{ github.event.pull_request.number }}`. |
| Organization | **Group** | GitLab permite anidar. |
| Repository | **Project** | |
| Repository secret | **Project variable** (con flags `protected`, `masked`) | GitLab también soporta Group variables, Instance variables, Environment variables. |
| Environment | **Environment** | GitLab incluye además **Review Apps** nativas por MR. |
| Branch protection | **Protected Branches / Tags** | |
| Environment protection rules | **Protected Environments** con approval rules | |
| Org runners | **Group Runners** | GitLab también tiene Project Runners y Shared/Instance Runners. |
| GITHUB_TOKEN | **CI_JOB_TOKEN** (con permisos recientes mucho más controlables) | |
| OIDC token (`id-token: write`) | **ID Token** (declarativo con `id_tokens:` por job) | Claims distintas. |
| Required workflow | **Compliance Pipeline** (Ultimate) | Mismo propósito; distinto producto. |
| Marketplace action | **CI/CD Component** del CI/CD Catalog | |
| GHAS | **Ultimate** scanners | |

Internaliza estas 12 equivalencias y la mayoría del vocabulario de los módulos siguientes se vuelve inmediato.

---

## 7. CI/CD Components y Catalog (vista de 10.000 pies)

Aunque los Components son materia de `gl-05`, conviene ya tenerlos en el modelo mental porque son **el equivalente moderno** del "reusable workflow" de GHA:

- Un **CI/CD Component** vive en un **Project** especial dentro de un Group.
- Define **`spec:inputs:`** (tipado) y expone **templates** parciales de `.gitlab-ci.yml`.
- Se consume con `include: - component: $CI_SERVER_FQDN/path/to/component@version`.
- Se publica al **CI/CD Catalog** (visible al Group o a toda la Instance).
- Se **versiona con SemVer** vía Git tags.

Sin Components, antes se usaba `include:remote:` o `include:project:`, pero sin contrato tipado ni versionado explícito. Hoy, cualquier plataforma CI/CD en GitLab serio **se construye sobre Components**.

---

## 8. ID Token / OIDC a cloud (vista de 10.000 pies)

Materia de `gl-03` y `gl-06`. Lo que importa saber ahora:

- GitLab emite un **ID Token** (JWT) por job si lo declaras con `id_tokens:`.
- Las **claims** son distintas a las de GHA:
  - GitLab: `project_path`, `namespace_path`, `ref`, `environment`, `ref_type`, `pipeline_id`...
  - GHA: `repository`, `repository_owner`, `ref`, `environment`...
- Para federar con AWS/GCP/Azure/Vault, debes construir las **trust policies** usando las claims de GitLab, **no** copiar las de GHA.

**Consecuencia práctica**: migrar OIDC de GHA a GitLab **no es cambiar una URL**: es rediseñar los claims aceptados por el IdP del cloud.

---

## 9. Runners: Shared, Group, Project (vista de 10.000 pies)

Materia de `gl-02` y `gl-06`. Modelo mental ahora:

| Nivel | Gestión | Comparable a |
|-------|---------|--------------|
| **Shared / Instance Runners** | GitLab (en SaaS) o tú (en Self-Managed) | GitHub-hosted runners |
| **Group Runners** | Tú | Org runners de GHA |
| **Project Runners** | Tú | Repo-level self-hosted runners |

En SaaS Free hay minutos limitados de **shared runners hosted by GitLab**. Si los agotas, o necesitas runners propios (K8s, GPUs, red privada), montas Group / Project Runners.

---

## 10. Trade-offs iniciales: GHA vs GitLab

| Criterio | GHA tiende a ganar | GitLab tiende a ganar |
|----------|-------------------|-----------------------|
| Ecosistema de acciones públicas | ✅ enorme Marketplace | ❌ más pequeño (CI/CD Catalog creciente) |
| Integración con repos existentes en GitHub | ✅ natural | ❌ necesita mirror o migración |
| Features de **seguridad** incluidas en un solo producto | ❌ GHAS es addon separado | ✅ Ultimate agrupa casi todo |
| **Self-Managed gratuito** real | ❌ GHES siempre de pago | ✅ CE gratis |
| **Subgroups anidables** y gobernanza jerárquica | ❌ no existe | ✅ nativo |
| **CI/CD Catalog interno** como golden path | parcial (reusable workflows) | ✅ Components son el patrón 2023+ |
| Registry integrado (OCI + packages) | parcial (GHCR) | ✅ Container Registry + Package Registry cubiertos |
| **Compliance pipelines** forzados por el equipo central | required workflows | ✅ Compliance Framework (Ultimate) |

**No existe una respuesta universal**. La decisión depende de: tamaño de la org, régimen de compliance, ecosistema de repos ya en una plataforma, apetito por operar Self-Managed, y presupuesto para seguridad.

---

## 11. Criterios para elegir plataforma (checklist para el ADR)

1. **¿Dónde viven los repos hoy?** Migrar repos tiene un coste no trivial (CI/CD + issues + historia + permisos).
2. **¿Qué régimen de compliance?** Si necesitas SOC 2 / PCI / HIPAA pronto, mapea los scanners/approvals a Ultimate (GitLab) o GHAS + GHE (GitHub) y compara **TCO real**, no sticker price.
3. **¿Dónde está la fuente de identidad?** Si ya tienes Entra ID / Okta con SCIM, ambas plataformas se integran — compara la ergonomía.
4. **¿Necesitas Self-Managed o air-gap?** CE es un diferenciador si no puedes pagar GHES.
5. **¿Cuántos equipos y cuánta jerarquía?** >5 equipos con suborganizaciones: GitLab Subgroups ayudan de verdad.
6. **¿Dónde se despliega?** Si ya corres K8s on-prem, el **GitLab Agent for K8s** más el runner K8s es un combo estrecho.
7. **¿Qué cuesta cambiarse en 2 años si decides mal?** Dual-run durante un período es viable: optimiza por **reducir el bloqueo** de la decisión, no por la "elección perfecta".

---

## 12. Qué se espera que puedas hacer al terminar

- Dibujar la jerarquía `Instance → Group → Subgroup → Project` sin consultar.
- Nombrar las 3 modalidades (SaaS, Self-Managed, Dedicated) con cuándo cada una.
- Explicar por qué comparar "Free vs Free" entre plataformas es engañoso en seguridad.
- Mapear 10 conceptos GHA → GitLab sin tabla.
- Escribir un ADR corto que decida plataforma para un escenario concreto con alternativas descartadas.
- Entender por qué los módulos `gl-02..gl-10` existen en el orden en que existen.

Siguiente: `gl-02-gitlab-ci-yml-pipelines-runners`.
