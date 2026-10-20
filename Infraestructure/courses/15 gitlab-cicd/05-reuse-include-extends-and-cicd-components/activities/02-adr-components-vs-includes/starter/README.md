# Starter — gl-05-02

Este directorio no contiene archivos de arranque: el entregable es prosa que tú escribes. Lee la plantilla y pégala en tu `/tmp/gl-05-02/ADR-REUSE-STRATEGY.md` para empezar.

## Plantilla sugerida

```markdown
# ADR 002 — Estrategia de reutilización en GitLab CI/CD

## Estado
Propuesto — <fecha>

## Contexto
<2-4 párrafos: el grupo payments/, los 12 proyectos, los 3 escenarios.>

## Decisión

| Escenario | Mecanismo | Por qué (1 línea) |
|-----------|-----------|-------------------|
| A — smoke tests duplicados | <extends/include/component> | <razón> |
| B — Node compartido en 3 proyectos | <extends/include/component> | <razón> |
| C — build+sign para 11 proyectos cross-grupo | <extends/include/component> | <razón> |

### Escenario A — smoke tests duplicados
<justificación>

### Escenario B — Node compartido en 3 proyectos
<justificación, mencionando ref: pin a tag si vas por include:project:>

### Escenario C — build+sign cross-grupo
<justificación, mencionando spec:inputs: y SemVer>

## Consecuencias
<positivas y negativas>

## Alternativas descartadas
1. <alternativa + por qué no>
2. <alternativa + por qué no>

## Anti-patrones evitados
- <ej. include: remote: con main>
- <ej. extends: de 5 niveles>
```

Recuerda: el validador busca secciones y palabras clave, pero la calidad de la decisión la mide `solution/REFERENCE.md`.
