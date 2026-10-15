# CI/CD Engineering Academy

Programa integral, progresivo y práctico para dominar **CI/CD, DevOps, Infrastructure as Code, Cloud, GitOps, SRE y Platform Engineering**.

El programa está organizado en dos niveles:

- **Nivel A — Roadmap transversal** (`ROADMAP.md`): disciplinas y bloques comunes a todas las tecnologías.
- **Nivel B — Roadmaps especializados** (`courses/<tech>/ROADMAP.md`): cursos profundos por tecnología.

## Objetivo

Formar ingenieros capaces de **comprender, diseñar, implementar, diagnosticar y mantener** sistemas de software productivos — no solamente operadores que memorizan comandos.

## Estructura del repositorio

```text
ci-cd-engineering-academy/
├── README.md                 ← este archivo
├── ROADMAP.md                ← roadmap transversal (Fase 1)
├── CONTRIBUTING.md
├── docs/
│   ├── architecture/         ← diagramas, decisiones, ADRs
│   ├── fundamentals/         ← conceptos compartidos entre cursos
│   └── references/           ← enlaces a fuentes autoritativas
├── courses/                  ← un directorio por tecnología
│   └── git-and-github/
├── projects/
│   └── capstone/             ← proyecto integrador incremental
├── templates/                ← plantillas para módulos, cursos y actividades
└── scripts/                  ← utilidades (validadores, etc.)
```

## Progresión recomendada

Ver `ROADMAP.md` para la secuencia de disciplinas y el orden de los roadmaps especializados.

## Convenciones

- Identificadores estables: `T-<D>.<M>` para módulos transversales, `<tech>-<NN>-<name>` para módulos de curso.
- Nombres de archivos y carpetas en **kebab-case**.
- Documentación en **Markdown**.
- Cada actividad vive en su propia carpeta con `README.md`, `activity.yaml`, `starter/`, `tests/`, `solution/`.
- **Sin secretos reales** en el repositorio.

## Estado

- [x] Fase 1 — Arquitectura del aprendizaje (`ROADMAP.md`)
- [x] Fase 2 — Roadmaps especializados (17 cursos en `courses/`)
- [x] Fase 3 — Biblioteca de prompts (10 prompts en `prompts/`)
- [ ] Fase 4 — Desarrollo de cursos
- [ ] Fase 5 — Capstone project
- [ ] Fase 6 — Evaluación profesional
