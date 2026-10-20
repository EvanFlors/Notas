# Ejemplo 01 — Group / Subgroup / Project estructurado

> Objetivo: ver cómo se organiza una org real en GitLab con subgroups anidables, y por qué eso cambia la forma de **compartir runners, variables y templates** frente a GitHub.

## 1. Estructura ejemplo

Una startup "acme" con 3 áreas (`platform`, `checkout`, `analytics`) podría estructurarse así en GitLab:

```
Instance (gitlab.com)
└── acme                                  Group raíz
    │   ├─ Group Runners: shared docker + k8s on-prem
    │   ├─ Group Variables: REGISTRY_URL, DEFAULT_IMAGE
    │   └─ CI/CD Catalog: componentes publicados por platform
    │
    ├── platform                          Subgroup
    │   ├── golden-ci-components         Project (publica componentes al Catalog)
    │   ├── terraform-modules             Project
    │   └── runners                       Subgroup
    │       ├── runner-config             Project
    │       └── fleet-metrics             Project
    │
    ├── checkout                          Subgroup
    │   │   ├─ Group Variables: CHECKOUT_IMAGE_TAG, ENV_URL_TEMPLATE
    │   │   ├─ Protected Environments: production (approval rule)
    │   │   └─ Compliance Framework: pci-light
    │   ├── api                           Project
    │   ├── web                           Project
    │   └── infra                         Project
    │
    └── analytics                         Subgroup
        ├── pipelines                     Project
        └── dashboards                    Project
```

## 2. Qué se hereda de dónde

| Recurso | Dónde se define | Dónde se usa |
|---------|-----------------|--------------|
| Group Runners | `acme` (o subgroup) | Todos los Projects descendientes que etiqueten `tags:` compatible |
| Group Variables | `acme` o `acme/checkout` | Todos los Projects descendientes (con flags `protected`/`masked`/`environment:`) |
| CI/CD Component | Project `acme/platform/golden-ci-components` | Cualquier Project vía `include: - component: gitlab.com/acme/platform/golden-ci-components/<name>@<ver>` |
| Compliance Framework | `acme/checkout` | Pipeline se concatena a cada MR de `acme/checkout/*` |
| Permission (Role) | Group / Subgroup | Hereda a Projects — se puede sobreescribir hacia **más** permiso en el Project, no hacia menos |

## 3. Equivalente en GitHub

```
Org: acme
├── acme-platform-golden-ci-workflows   (repo)
├── acme-platform-terraform-modules     (repo)
├── acme-checkout-api                    (repo)
├── acme-checkout-web                    (repo)
├── acme-checkout-infra                  (repo)
├── acme-analytics-pipelines             (repo)
└── acme-analytics-dashboards            (repo)
```

En GitHub **no hay subgroups**. Resultado típico:

- Convenciones de **naming** (`acme-platform-*`) para simular agrupación.
- **Teams** para agrupar permisos (que no son contenedores de recursos CI/CD como los Groups).
- **Required workflows** y **org-level runners** reemplazan parcialmente lo que en GitLab es "Group Variables + Group Runners + Catalog".

## 4. Observaciones de diseño

1. **El Group es la unidad de reuso.** Si no diseñas tu Group tree, acabas duplicando variables y runners por Project — igual que en GitHub, pero sin ganar nada por elegir GitLab.
2. **Subgroups anidables son opcionales, no obligatorios.** Para una org de 5 repos, un solo Group basta. Los subgroups aparecen cuando quieres **separar permisos y runners** entre áreas sin crear otra Instance.
3. **Compliance Framework a nivel subgroup** es la vía nativa para "equipo de seguridad inyecta pipeline obligatorio a `checkout`"; en GitHub lo haces con required workflows a nivel org.
4. **Jerarquía ≠ monorepo.** Un subgroup con 10 Projects **no** los convierte en un monorepo; sigue habiendo 10 pipelines independientes. Lo que comparten es gobernanza, no código.

## 5. Preguntas para pensar

- Si `acme/checkout` crece a 20 repos, ¿añades un sub-subgroup `acme/checkout/<team>`? ¿O creas un Group hermano?
- Si `platform` publica un Component y `checkout` lo consume: ¿cuál es el riesgo de que `platform` haga un breaking change? ¿Cómo lo mitigas con SemVer y tagging?
- ¿Qué pondrías a nivel `acme` (raíz) y qué a nivel `acme/checkout`? ¿Por qué?

> No ejecutes nada. Esto es un ejemplo de lectura. Las decisiones de diseño vendrán en `gl-05` y `gl-10`.
