# Ejemplo 02 — CI/CD Catalog: contrato, gobernanza e inner-source

> Lectura y análisis. Objetivo: diseñar cómo opera un catálogo interno de componentes como *golden path* para toda una org.

## 1. Anatomía de un repo de componente

```
platform/ci-catalog-node-test/
├── README.md                       # qué hace, inputs, versiones, changelog resumido
├── CHANGELOG.md
├── LICENSE
├── templates/
│   └── template.yml                # el único component (nombre inferido del repo)
└── .gitlab-ci.yml                  # pipeline del propio componente: lint, test, release
```

### `templates/template.yml` con contrato

```yaml
spec:
  inputs:
    image:
      type: string
      default: node:20
    coverage_threshold:
      type: number
      default: 80
    stage:
      type: string
      default: test
---
"node-test":
  stage: $[[ inputs.stage ]]
  image: $[[ inputs.image ]]
  script:
    - npm ci
    - npm test -- --coverage
    - node scripts/check-coverage.mjs --min $[[ inputs.coverage_threshold ]]
  artifacts:
    when: always
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
```

Lo clave:

- `spec:inputs:` es **el contrato** público. Un cambio *breaking* (quitar un input, cambiar su `type`) exige **bump mayor** del SemVer.
- El bloque tras `---` define los jobs que se inyectan en el pipeline consumidor.
- `$[[ inputs.X ]]` es la interpolación **de componente** (distinta de `$VAR` de pipeline).

## 2. Consumo desde un proyecto cliente

```yaml
# .gitlab-ci.yml de un proyecto cualquiera de la org
include:
  - component: $CI_SERVER_FQDN/platform/ci-catalog-node-test/node-test@1.3.0
    inputs:
      coverage_threshold: 85
```

Observaciones:

- **Versionado SemVer** vía tag Git (`v1.3.0` o `1.3.0` según la convención del catálogo).
- Pinnear a tag mayor + menor (`@1.3`) es cómodo pero *lee la última patch disponible* — útil en dev, discutible en main.
- Prefiere **tag completo (`@1.3.0`)** en pipelines de prod y gestiona upgrades con un bot (Renovate).

## 3. Modelo de inner-source

```
Platform team (owners del catálogo)
    │
    │ aprueba releases, define RFC template, mantiene docs
    ▼
Contributors (cualquier dev de la org)
    │
    │ abre Issue → RFC → MR a un componente
    ▼
Code Owners por componente (expertos en el dominio)
    │
    │ revisan técnica + semánticamente
    ▼
Release manager (platform)
    │
    │ taggea SemVer, publica en Catálogo, anuncia en Slack #platform-ci
```

Reglas:

- **MR approval rule**: 2 revisores para componente nuevo; 1 para patch; Code Owner obligatorio.
- **RFC** (plantilla en el repo del catálogo) obligatorio para componentes nuevos y para changes *breaking*.
- **Changelog** per componente, Keep-a-Changelog.
- **Deprecation policy**: `@deprecated` en spec + aviso 90 días + eliminación en siguiente major.
- **Métricas de adopción**: job diario que `grep -r "include:.*component.*ci-catalog-node-test"` en todos los repos del grupo y publica un dashboard.

## 4. Catálogo propio vs públicos

| Fuente | Pros | Contras |
|--------|------|---------|
| Catálogo público (gitlab.com) | Mantenido por la comunidad, parches rápidos | Cadena de suministro externa; auditar provenance; pinnea SemVer exacto. |
| Catálogo interno de la org | Control total, Code Owners internos | Más trabajo de mantenimiento; curva de inner-source. |
| Mezcla pragmática | Internos para lo específico; públicos para lo genérico (lint estándar, cosign) | Doble disciplina de versionado. |

La org pequeña empieza con todo público pinneado; a los 20+ repos, suele emerger un **wrapper interno** sobre componentes públicos para añadir defaults corporativos.

## 5. Governance anti-patterns

- **Catálogo con 50 componentes y adopción <10%**: síntoma de que Platform construye lo que *cree* que la org necesita, no lo que pide. Mide primero, construye después.
- **Componente que hace *demasiado***: *god component* que depende de 10 variables de entorno externas. Rompe el contrato. Fragmenta.
- **Cambios *breaking* sin bump mayor**: pierdes la confianza del catálogo en una semana. Convención: PR que cambie `spec:inputs:` **falla** en CI del propio catálogo si no bump de version.
- **Un repo-por-componente vs mono-repo del catálogo**: ambos funcionan. Mono-repo simplifica changelog cross-componente pero complica el `component:` path. La convención `templates/<name>/template.yml` del mono-repo escala razonablemente.

## 6. Preguntas de autocomprobación

1. ¿Qué pasa si un consumidor pinnea `@1.3` y liberas `1.3.1` con un bug?
2. ¿Cómo deprecarías un componente usado por 80 proyectos sin romperles la vida?
3. ¿Qué dato necesitas de los proyectos consumidores para saber qué versión usa cada uno?
4. ¿Por qué pedir Code Owners por componente en vez de un único owner Platform para todo?
5. Un dev pide un componente "universal-tests" para 5 lenguajes. ¿Lo aceptas o lo fragmentas?

Las respuestas se trabajan en la actividad `02-platform-adr-final`.
