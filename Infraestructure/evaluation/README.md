# Fase 6 — Marco de evaluación

Esta carpeta es el **marco de evaluación transversal** de la academia. No sustituye las evaluaciones por módulo (producidas con `prompts/08-learning-evaluator.md`); las agrega en una vista única y añade los instrumentos que viven **por encima** de un curso aislado: defensa de capstone, portafolio profesional, dashboard de progreso y protocolo de entrevista.

## Propósito

Distinguir "terminó las actividades" de "**puede operar como ingeniero CI/CD senior**". Toda pieza aquí responde a una de estas tres preguntas:

1. ¿El estudiante **demuestra competencia observable** en los 17 cursos? → `00-master-rubric.md`.
2. ¿Puede **integrar** las piezas y **defender** las decisiones del capstone bajo presión? → `capstone-defense/`.
3. ¿Puede **presentar** su trabajo de forma legible para un hiring manager? → `portfolio/` + `interview-protocol/`.

Y para instrumentar el camino: ¿**dónde** está el estudiante hoy y **cuánto** le queda? → `progress-dashboard/`.

## Estructura

```
evaluation/
├─ README.md                         # este archivo
├─ 00-master-rubric.md               # matriz maestra de competencias (17 cursos)
├─ capstone-defense/
│  └─ README.md                      # protocolo de defensa oral + demo + rúbrica
├─ portfolio/
│  ├─ README.md                      # qué publica el estudiante y cómo
│  └─ TEMPLATE.md                    # plantilla de README del portafolio
├─ progress-dashboard/
│  ├─ README.md                      # cómo correr el script y cómo leerlo
│  ├─ compute_dashboard.py           # scanner + renderer (stdlib)
│  └─ sample-output.md               # output real contra este repo
└─ interview-protocol/
   └─ README.md                      # entrevista mock senior/staff
```

## Cómo se usa

### Durante el programa

- **Al cerrar cada módulo** se corre la evaluación formativa del propio módulo (prompt 08). Esto no vive aquí; vive en el módulo.
- **Al cerrar cada curso** se contrasta contra `00-master-rubric.md` → la fila del curso. Si no todas las competencias core están demostradas con artefacto, el curso **no está cerrado** (sin importar el `status` en `activity.yaml`).
- **Semanalmente** el estudiante corre `progress-dashboard/compute_dashboard.py` y commitea el resultado o lo pega en su diario de aprendizaje.

### Al terminar las 15 etapas del capstone

1. **Portafolio** (`portfolio/`) listo y publicado en GitHub.
2. **Defensa de capstone** (`capstone-defense/`): oral + demo + preguntas duras.
3. **Entrevista mock** (`interview-protocol/`): 90–120 min, modelo senior/staff.

Las tres aprobadas → certificación interna.

## Política de scoring (global)

Toda rúbrica aquí usa **4 niveles observables**:

| Nivel | Puntos | Significado operativo |
|-------|-------:|-----------------------|
| Insuficiente | 0 | No demuestra la competencia o la viola (red flag). |
| Básico | 1 | Reproduce con guía, no justifica decisiones. |
| Competente | 2 | Resuelve de forma independiente, justifica con criterios correctos. |
| Experto | 3 | Resuelve, justifica, y **anticipa** trade-offs y modos de falla. |

**Umbrales**:

- Un **módulo** aprueba con **promedio ≥ 2** y **cero criterios en 0**.
- Un **curso** aprueba con **≥ 80 %** de módulos aprobados y la rúbrica del curso (en `00-master-rubric.md`) con **≥ 2** en todas las competencias core.
- La **certificación final** requiere:
  - 17/17 cursos aprobados,
  - 15/15 etapas del capstone con `status: completed` **y** artefactos en el portafolio,
  - **defensa de capstone** con promedio ≥ 2 y cero red flags,
  - **entrevista mock** con dictamen `hire` a nivel **Senior** como mínimo.

## Red flags transversales

Independientes del contenido evaluado, un solo caso **invalida** la pieza:

- Secretos reales en Git (credenciales, keys, tokens).
- Permisos `cluster-admin` / `*:*` / `AdministratorAccess` sin justificación documentada.
- `curl … | bash` desde fuente no verificada en pipelines.
- Imágenes sin pin por digest o sin firma donde la rúbrica lo requiere.
- Terraform con `-auto-approve` en main sin plan revisado.
- Decisiones arquitectónicas sin **ADR** cuando la rúbrica del curso lo exige.

## Convenciones

- Prosa en español; código, CLI, identificadores y nombres de archivo en inglés.
- Nada de nombres de organizaciones o secretos reales en ningún artefacto.
- Los archivos de "análisis" se llaman `REFERENCE.md` o `TEMPLATE.md`, nunca `ANALYSIS.md`.
- Los 17 cursos se referencian por su nombre de directorio bajo `courses/`.
