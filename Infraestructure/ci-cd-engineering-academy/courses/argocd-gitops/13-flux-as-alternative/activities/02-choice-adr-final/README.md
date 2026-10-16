# argo-13-02 — ADR final: Argo CD vs Flux

## 1. Identificación
- **ID:** `argo-13-02-choice-adr-final`
- **Tecnología:** argocd-gitops
- **Módulo:** 13-flux-as-alternative
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** architecture

## 2. Contexto

Este es el **ADR de cierre del curso**. En `argo-01-02` escribiste un ADR "primera pasada" cuando aún no habías operado ninguna de las dos. Ahora, con conocimiento operacional de Argo CD (módulos 02–12) y conocimiento conceptual + un porting real de Flux (módulo 13), repites la decisión — con criterios y pesos reales.

Esta actividad es **independiente**. No hay andamiaje; produces un documento Markdown en `solution/ADR-argocd-vs-flux.md`.

## 3. Objetivos

1. Describir una **organización concreta** (ficticia o real, pero específica — no "una empresa cualquiera").
2. Enumerar los **criterios** que importan para esa organización, con **peso** cuantitativo.
3. Evaluar Argo CD y Flux **contra esos criterios** con evidencia (referencias al código operado en este curso).
4. Emitir una **decisión** con fecha, autor y **consecuencias** (qué cambia operacionalmente a partir de aceptarla).
5. Definir el **plan de salida** (si en 12 meses la decisión no funciona, cómo se migra en reverso).

## 4. Prerrequisitos

- `argo-13-01` completado (tener la experiencia de haber portado un workload).
- Experiencia con el formato ADR (Michael Nygard, 2011).

## 5. Instrucciones

Escribe `solution/ADR-argocd-vs-flux.md`. **Debe contener** las siguientes secciones (el validador comprueba su presencia por encabezado):

- `# ADR-NNN: ...` (título con número y resumen)
- `## Status` (`Proposed`, `Accepted`, `Deprecated` o `Superseded`)
- `## Context` (organización, equipo, workloads, restricciones)
- `## Decision Drivers` (criterios con peso)
- `## Considered Options` (al menos Argo CD y Flux; opcional: ambos simultáneos, ninguno)
- `## Decision Outcome` (opción elegida + justificación)
- `## Consequences` (positivas y negativas)
- `## Exit Plan` (cómo revertir si falla)

**Longitud orientativa**: 300–800 palabras. Es un ADR, no una tesis.

Mal ADR: "elegimos Argo CD porque es más popular".
Buen ADR: "elegimos Argo CD con peso 60% UX operador, 20% SSO, 20% ApplicationSets. Flux obtuvo mejor en image automation (10 pts vs 7 pts, peso 10%) pero peor en UX operador (4 pts vs 9 pts, peso 60%). Diferencia neta: +2.1 pts a favor de Argo CD."

## 6. Resultado esperado

Un ADR legible, defendible y con criterios ponderados.

## 7. Criterios de aceptación

| Criterio | Verificado por |
|---|---|
| Existe `solution/ADR-argocd-vs-flux.md` | `tests/validate.sh` |
| Contiene todas las secciones requeridas | `tests/validate.sh` (busca encabezados) |
| Tiene longitud razonable (≥ 250 palabras) | `tests/validate.sh` |
| Menciona explícitamente criterios con pesos | `tests/validate.sh` (busca palabras clave como "peso"/"weight" o "%") |
| Declara una decisión (no "a definir") | `tests/validate.sh` (comprueba que `Decision Outcome` no esté vacío) |

## 8. Validación

```bash
bash tests/validate.sh
```

El validador es **estructural**. No juzga la calidad del contenido — eso es trabajo de un revisor humano. Pero asegura que el ADR tenga las secciones y densidad mínimas para ser evaluable.

## 9. Preguntas de reflexión

1. ¿Qué habrías decidido antes de operar Argo CD por 12 módulos? ¿Qué cambió?
2. ¿Es la decisión reversible técnicamente? ¿Y organizacionalmente (gente que ya aprendió una herramienta)?
3. Si tu organización ya tiene **la otra**, ¿cuál es el *break-even* para migrar?
4. ¿Dónde ambas pierden y hay que mirar otra cosa (Crossplane, Jenkins X, pipelines push)?

## 10. Extensiones

- Añade un apéndice con una **matriz de 2x2** (eje X: tamaño org, eje Y: madurez GitOps) y marca dónde cae tu decisión.
- Añade un **plan de 90 días** (semana a semana) de la adopción.

## 11. Limpieza

Nada que limpiar — solo producto escrito.
