# Actividad 03 — ADR: elegir workflow para un escenario dado

## 1. Identificación

- **ID:** `gh-08-03-architecture-decision`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-08-workflows-trunk-vs-gitflow`
- **Dificultad:** intermediate
- **Duración estimada:** 40–60 min
- **Tipo:** independent (arquitectura, entregable escrito)

## 2. Contexto

Las actividades 01 y 02 te dieron la *mecánica*. Esta actividad te pide la *decisión*. Vas a producir un **Architecture Decision Record (ADR)** eligiendo el modelo de branching para un escenario concreto y defendiendo tu elección. El entregable es un `.md` con una estructura precisa.

El validador **no juzga qué workflow elegiste** (hay más de una respuesta correcta): comprueba que **la decisión esté claramente tomada, justificada contra alternativas, y que cubras los escenarios donde fallaría**.

## 3. Objetivos

- Analizas un escenario y extraes restricciones operativas.
- Eliges un workflow con criterios explícitos.
- Documentas en formato ADR (Nygard).
- Nombras alternativas descartadas y por qué.
- Nombras riesgos y bajo qué condiciones revisarías la decisión.

## 4. Prerrequisitos

- Actividades 01 y 02 completadas.
- Lección leída (especialmente §7 y §8).

## 5. Instrucciones

### 5.1 Escenario asignado

Vas a escribir el ADR para **este** escenario:

> **Equipo:** 8 desarrolladores backend + 3 frontend (11 totales), 1 SRE part-time.
> **Producto:** SaaS multi-tenant B2B (API REST + web app) desplegado en Kubernetes gestionado por el SRE.
> **Clientes:** ~200 empresas; sin instalación on-premise.
> **Cadencia deseada:** poder desplegar al menos una vez al día; actualmente despliegan los jueves por la tarde con un *release train* manual.
> **Regulación:** SOC 2 Type II; requiere trazabilidad de cambios y aprobaciones. No requiere "versión congelada en QA formal" al estilo FDA/aeronáutico.
> **Herramientas:** GitHub Enterprise Cloud, GitHub Actions, feature flags via Unleash self-hosted, Datadog, PagerDuty.
> **Dolor actual:** PRs que viven ≥ 1 semana; "merge conflicts" como actividad semanal; releases los jueves con 20+ cambios acumulados, revert ocasional de la *release train* entera cuando un cambio rompe algo.
> **Restricciones:** No pueden sumar herramientas nuevas ni contratar; sí pueden cambiar el workflow y el tooling existente.

**Tu misión:** proponer un modelo de branching y un plan de ejecución, en formato ADR.

### 5.2 Entregable

Edita el archivo:

```
starter/ADR-001-branching-strategy.md
```

Reemplaza los placeholders `TODO:` por tu contenido real. **No borres las cabeceras de sección** — el validador las espera para verificar estructura.

### 5.3 Estructura mínima (secciones obligatorias)

Las siguientes cabeceras deben aparecer textualmente (en cualquier orden lógico sensato):

- `# ADR-001: Branching Strategy`
- `## Status`
- `## Context`
- `## Decision`
- `## Alternatives Considered`
- `## Consequences`
- `## Risks and Mitigations`
- `## Review Triggers`

Y además:

- **Un bloque de decisión claro** del estilo: `We will adopt <workflow>` donde `<workflow>` sea uno de: `trunk-based development`, `GitHub Flow`, `GitLab Flow`, `GitFlow`, `release branches on trunk`.
- **Al menos 2 alternativas descartadas** en `## Alternatives Considered`, cada una con una razón ≥ 1 frase.
- **Al menos 3 consecuencias** (positivas y/o negativas) en `## Consequences`.
- **Al menos 2 riesgos con mitigación** en `## Risks and Mitigations`.
- **Al menos 1 criterio** en `## Review Triggers` (ej. "si lead time p50 > 2 días durante 1 mes, revisamos").

Longitud razonable: 400–900 palabras.

### 5.4 Validar

```bash
bash tests/validate.sh starter/ADR-001-branching-strategy.md
```

Debe terminar en `OK`. Si falla, el output dice qué sección o criterio falta.

### 5.5 (Opcional) comparar con la referencia

Tras intentarlo tú, revisa `solution/ADR-reference.md`. Es **una** respuesta razonada, no la única. Puedes elegir distinto y seguir siendo válido, siempre que la justificación cuadre con el escenario.

## 6. Resultado esperado

- `starter/ADR-001-branching-strategy.md` con todas las secciones y los criterios de contenido.
- El validador pasa.
- Tienes claro por qué el workflow elegido ataca el *dolor actual* y en qué escenario alternativo tu elección sería mala.

## 7. Criterios de aceptación

- [ ] ADR con las 8 secciones obligatorias.
- [ ] Decisión explícita de uno de los workflows listados.
- [ ] 2+ alternativas descartadas con razón.
- [ ] 3+ consecuencias.
- [ ] 2+ riesgos con mitigación.
- [ ] 1+ review trigger.
- [ ] `tests/validate.sh` pasa.
- [ ] Longitud ≥ 400 palabras (soft check).

## 8. Validación

```bash
bash tests/validate.sh starter/ADR-001-branching-strategy.md
```

El validador comprueba **estructura y presencia**, no corrección semántica (que es subjetiva). La corrección semántica se evalúa en revisión por pares o en lectura con rúbrica.

## 9. Preguntas de reflexión

1. ¿Qué datos del escenario pesaron más en tu elección?
2. ¿Qué cambiarías si el equipo tuviera 60 devs y 3 productos independientes en el mismo monorepo?
3. ¿Cómo cambiaría la decisión si el producto fuera un SDK on-premise con 3 versiones mayores en soporte?
4. ¿Qué métricas pondrías en el dashboard para saber si tu decisión está funcionando a 3 meses?
5. ¿Qué política de branch protection (ver `gh-12`) materializa tu decisión?

## 10. Extensiones

- **E1** — Escribe un segundo ADR (`ADR-002`) para una variante del escenario (ej. "mismo equipo, pero regulación FDA").
- **E2** — Añade un diagrama en texto (DAG) al ADR mostrando la topología esperada tras 1 semana del workflow.
- **E3** — Añade un *rollout plan* de 90 días para migrar desde el estado actual al workflow decidido.

## 11. Limpieza

El ADR está en el directorio de la actividad. Si quieres partir de cero:

```bash
git checkout -- starter/ADR-001-branching-strategy.md
```

(O recarga el starter desde el repo.)
