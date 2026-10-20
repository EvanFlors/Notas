# Biblioteca de prompts — FASE 3

Diez prompts reutilizables para producir, mantener y evaluar el programa de forma consistente.

Cada prompt es **autónomo**: define rol, inputs, outputs, restricciones, criterios de calidad y variables. Están pensados para ejecutarse en una **nueva conversación** con un modelo capaz, con acceso a internet cuando corresponda.

## Índice

| # | Prompt | Archivo | Para qué sirve |
|---|--------|---------|----------------|
| 1 | Curriculum Architect | `01-curriculum-architect.md` | Diseñar roadmaps, módulos, dependencias, secuencias |
| 2 | Technical Deep Dive Instructor | `02-deep-dive-instructor.md` | Desarrollar un módulo con teoría, internals, ejemplos |
| 3 | Practical Lab Generator | `03-lab-generator.md` | Generar actividades (ejercicios, labs, retos, debugs) |
| 4 | Architecture Instructor | `04-architecture-instructor.md` | Diseñar y explicar arquitecturas con trade-offs y ADR |
| 5 | Troubleshooting Instructor | `05-troubleshooting-instructor.md` | Generar escenarios de fallo y análisis de causa raíz |
| 6 | Engineering Reviewer | `06-engineering-reviewer.md` | Revisar código/config/arquitectura por dimensiones |
| 7 | Technical Researcher | `07-technical-researcher.md` | Investigar documentación actual, versiones, deprecations |
| 8 | Learning Evaluator | `08-learning-evaluator.md` | Diseñar evaluaciones teóricas y prácticas con rúbrica |
| 9 | Repository Generator | `09-repository-generator.md` | Materializar estructura de carpetas y archivos |
| 10 | Capstone Project Architect | `10-capstone-architect.md` | Diseñar e implementar etapas del proyecto integrador |

## Convenciones

### Variables canónicas

Todas las variables van entre llaves y se resuelven antes de ejecutar el prompt:

| Variable | Significado | Ejemplo |
|----------|-------------|---------|
| `{TECNOLOGIA}` | tecnología objetivo | `kubernetes`, `terraform` |
| `{MODULO}` | ID estable del módulo | `k8s-07-networking-cni-netpol...` |
| `{NIVEL}` | nivel pedagógico | `fundamentos` / `intermedio` / `avanzado` / `producción` |
| `{PRERREQUISITOS}` | lista de IDs | `[k8s-04, k8s-06]` |
| `{OBJETIVOS}` | lista de objetivos operacionales | textual |
| `{ENTORNO}` | entorno de ejecución | `kind local`, `AWS us-east-1`, `GHA ubuntu-latest` |
| `{VERSION}` | versión target | `k8s 1.30`, `tf 1.9`, `argo-cd 2.12` |
| `{RUTA_REPOSITORIO}` | path absoluto | `/ruta/al/repo/ci-cd-engineering-academy` |
| `{TIPO_ACTIVIDAD}` | tipo de ejercicio | `guided-lab`, `independent`, `debug`, `architecture` |
| `{DIFICULTAD}` | nivel actividad | `beginner` / `intermediate` / `advanced` |
| `{DURACION}` | minutos estimados | `45` |
| `{DOMINIO}` | área del programa | `D5 CI/CD`, `D8 Orquestación` |
| `{PUBLICO}` | perfil estudiante | ingeniero intermedio Python, SRE junior, etc. |
| `{PROYECTO}` | nombre del proyecto | `capstone fastapi` |
| `{ESCENARIO}` | descripción textual | "org 50 microservicios, multi-región" |
| `{CONTEXTO}` | contexto adicional | restricciones de compliance, budget, legacy |

### Reglas comunes a todos los prompts

1. **Investigación**: cuando dependa de versiones o docs vivas, usar fuentes autoritativas en el orden del programa (docs oficiales → specs → repos oficiales → vendors → publicaciones reconocidas). Nunca inventar fuentes.
2. **Distinciones**: separar siempre *hechos documentados* / *recomendaciones oficiales* / *buenas prácticas* / *decisiones dependientes del contexto* / *hipótesis*.
3. **Costos**: cualquier recurso cloud real debe llevar estimación de costo y procedimiento de limpieza.
4. **Secretos**: nunca credenciales reales ni plausibles.
5. **Reproducibilidad**: dependencias pinneadas, versiones declaradas.
6. **Honestidad**: nunca afirmar haber creado archivos si solo se emitió texto; nunca afirmar haber ejecutado pruebas si no se ejecutaron.

## Uso típico

En una conversación nueva:

1. Copiar el contenido del prompt.
2. Rellenar las variables entre llaves con los valores concretos.
3. Enviar al modelo con herramientas apropiadas habilitadas (web, fs, etc.).
4. Revisar el resultado contra los **criterios de calidad** del prompt antes de aceptar.

## Composición entre prompts

Los prompts están pensados para encadenarse:

- **1 (Architect)** → produce roadmap → **2 (Deep Dive)** desarrolla un módulo → **3 (Lab)** genera actividades → **9 (Repo)** materializa archivos → **8 (Evaluator)** diseña evaluación → **6 (Reviewer)** audita antes de merge.
- **7 (Researcher)** se invoca cuando cualquier otro prompt necesita verificar versiones o docs.
- **5 (Troubleshooting)** y **4 (Architecture)** generan contenido avanzado dentro de los módulos.
- **10 (Capstone)** reutiliza los demás prompts por etapa del proyecto.
