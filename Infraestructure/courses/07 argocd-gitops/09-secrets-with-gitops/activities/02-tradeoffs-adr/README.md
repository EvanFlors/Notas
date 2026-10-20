# argo-09-02 — ADR: trade-offs de secretos en GitOps (independent)

## 1. Identificación

- **ID:** `argo-09-02-tradeoffs-adr`
- **Tecnología:** argocd-gitops
- **Módulo:** `09-secrets-with-gitops`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** independent (análisis + ADR)

## 2. Contexto

Elegir estrategia de secretos es la decisión arquitectónica más persistente del dominio GitOps: una vez adoptada, migrar cuesta. Un ADR explícito, con criterios ponderados y revisable, es la mejor defensa contra cambios por capricho y contra olvidarse de rotar.

Esta actividad **no** se resuelve con comandos: redactas un ADR que elige y defiende una estrategia por organización para **tres** casos distintos, basándote en los trade-offs del `theory/lesson.md`.

## 3. Objetivos

- Comparar las 5 estrategias en una tabla con 6–8 criterios.
- Elegir y justificar una por organización para los 3 casos abajo.
- Documentar riesgos conocidos y plan de rotación anual.
- Dejar el ADR en `starter/ADR_TEMPLATE.md` → `ADR.md` tuyo.

## 4. Prerrequisitos

- Haber completado `argo-09-01`.
- Haber leído `theory/lesson.md` secciones 3–7 y 12.
- Software: cualquier editor Markdown.
- Costos: 0.

## 5. Instrucciones

### Casos a resolver

1. **Startup fintech en AWS**, 25 ingenieros, cultura cloud-first, auditoría SOC2 obligatoria, 3 clusters EKS (dev/stg/prod), 50 microservicios.
2. **Agencia gubernamental air-gapped**, 8 ingenieros, cero conectividad a nube pública, 2 clusters on-prem, 10 servicios, HSM USB disponible, equipo con experiencia PGP.
3. **Empresa industrial con Vault ya operado**, 60 ingenieros, 5 clusters (3 cloud + 2 edge), 120 servicios, DBAs quieren dynamic DB credentials (lease de 1 h) para los servicios core.

### Entregable

Rellena `starter/ADR_TEMPLATE.md` y guárdalo como `ADR.md` en el root de la actividad. Debe incluir:

- **Status**: `proposed | accepted | superseded`.
- **Context**: resumen de las 5 estrategias en 1 párrafo.
- **Decision table**: criterios (`blast radius`, `rotation UX`, `operator overhead`, `cost`, `multi-cluster`, `compliance fit`, `migration cost`) × estrategias, puntuación 1–5.
- **Decision per org**: una sección por caso con elección y justificación en ≤ 150 palabras.
- **Consequences**: para la elección global del equipo (si tuvieras *una* sola apuesta), qué ganas y qué pagas.
- **Rotation plan**: cadencia por tipo de secreto, drill de rollback.
- **Revisit date**: un año.

### Checks obligatorios

- `ADR.md` existe en el root de la actividad.
- Las tres orgs tienen decisión explícita (busca `## Org 1`, `## Org 2`, `## Org 3`).
- Aparece la cadena `Revisit:` con fecha.
- No menciona valores secretos reales (es un documento, no un dump).

Ejecuta:

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

Un `ADR.md` de 400–800 palabras, legible por un gerente técnico no especialista.

## 7. Criterios de aceptación

- **Fundamento**: cada elección cita 2+ criterios de la tabla.
- **Honestidad**: incluye al menos 1 contra de la elección por org.
- **Operabilidad**: plan de rotación concreto (quién, qué, cuándo).
- **Reversibilidad**: menciona cómo migrar si la decisión cambia.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué cambia si la fintech añade un cluster en Azure?
2. ¿Qué pasa en la org air-gapped si pierden la llave age maestra?
3. ¿Por qué Vault Injector *para los servicios core* y ESO para el resto podría ser la respuesta en la org 3?
4. ¿Qué métricas pondrías para detectar "no estamos rotando a tiempo"?

## 10. Extensiones

- Añade una cuarta org inventada y aplica el mismo marco.
- Propón un flujo de migración de Sealed Secrets a ESO en 3 pasos sin ventana de downtime.

## 11. Limpieza

Esta actividad no crea recursos. No hay nada que limpiar más allá de borrar tu copia local si lo deseas.
