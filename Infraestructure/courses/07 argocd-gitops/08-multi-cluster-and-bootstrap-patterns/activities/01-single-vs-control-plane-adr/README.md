# argo-08-01 — ADR: in-cluster vs control-plane para 3 organizaciones

## 1. Identificación
- **ID:** `argo-08-01-single-vs-control-plane-adr`
- **Tecnología:** argocd-gitops
- **Módulo:** `08-multi-cluster-and-bootstrap-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent (architecture)

## 2. Contexto

Tres organizaciones ficticias te piden una recomendación de topología Argo CD. No hay
una respuesta universal — la actividad es defender la decisión *con los trade-offs que ya
estudiaste* en `theory/lesson.md` secciones 2 y 9.

### Org A — "StartupTech"
- 3 clusters total (dev / stg / prod), misma región AWS.
- 1 equipo de plataforma (2 personas).
- 4 equipos de producto.
- Presupuesto operativo chico.
- Compliance: nada especial.

### Org B — "GlobalBank"
- 12 clusters: 4 regiones × (dev / stg / prod).
- 2 equipos de plataforma por región.
- Regulación financiera: aislamiento estricto por región, auditoría granular, blast
  radius mínimo tolerado.
- Las pérdidas de un cluster prod no deben afectar a otra región bajo ninguna
  circunstancia.

### Org C — "RetailChain"
- 50+ clusters: 3 corporate (dev/stg/prod) + 1 por tienda (edge, muy chicos, red
  intermitente).
- 1 equipo de plataforma centralizado.
- Tiendas despliegan la misma app con pequeñas variaciones por región.
- Costo por cluster edge debe ser mínimo (RPi-class hardware).

## 3. Objetivos

- Elegir una topología (**in-cluster**, **control-plane**, o **híbrido**) para cada org.
- Argumentar con **al menos 3 trade-offs** de la tabla de la sección 2.3 de la teoría.
- Enumerar los **riesgos específicos** de la elección y una **mitigación** por cada uno.
- Describir cómo se vería el **flujo de "añadir un cluster"** en la elección propuesta.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` (en particular secciones 2, 3, 5 y 9).
- Haber visto `examples/01-register-second-cluster/` y `examples/02-bootstrap-repo-skeleton/`.
- No requiere infraestructura ni costos — es un ejercicio de diseño.

## 5. Instrucciones

Entregá un documento `ADR.md` (podés copiar `ADR.template.md`) con:

1. **Decisión por organización** (A, B, C).
2. Para cada decisión: trade-offs considerados, riesgos y mitigaciones, flujo
   "add-a-cluster".
3. Al final, una **tabla comparativa** resumiendo las tres decisiones.
4. (Opcional) una sección "Qué cambiaría mi recomendación" por organización (p.ej., "si
   StartupTech crece a 15 clusters, migraría a control-plane porque…").

**No consultes la "solución"** antes de intentarlo. Tu decisión puede ser distinta de la
sugerida y seguir siendo correcta si está bien argumentada — lo evaluable es el
razonamiento.

## 6. Resultado esperado

- `ADR.md` entregado con los 3 escenarios resueltos.
- Cada decisión cita trade-offs y riesgos concretos (no genérico "para escalar mejor").
- Flujo "add-a-cluster" descrito en 5–10 pasos por caso.

## 7. Criterios de aceptación

- **Consistencia** — las 3 elecciones responden a factores de cada org y no se
  contradicen entre sí.
- **Específicidad** — nombra herramientas concretas (ESO para tokens, Velero para
  backup del hub, CODEOWNERS por carpeta, etc.) donde corresponda.
- **Reversibilidad** — menciona qué habría que cambiar para migrar de una topología a
  otra (nada es irreversible, pero cuesta).
- **Honestidad** — las limitaciones de la elección se admiten; no se vende la decisión
  como "la mejor en todo".

## 8. Validación

Manual: autoevaluá tu ADR contra la rubrica en `rubric.md`. También podés contrastar
con `solution/ADR.suggested.md` **después** de entregar el tuyo.

## 9. Preguntas de reflexión

- ¿Qué pasaría con tu elección si GlobalBank adquiere un banco europeo con 5 clusters más?
- ¿Qué cambia si StartupTech pasa a tener compliance SOC 2?
- Para RetailChain edge: ¿Argo CD *en cada tienda* es realista con red intermitente? ¿Qué
  alternativas tiene? (hint: Flux + reconciliación local, o GitOps con pull desde edge).
- ¿En qué momento in-cluster deja de escalar operativamente? ¿Hay un número mágico?

## 10. Extensiones

1. Añadí una **cuarta organización** inventada por vos y resolvela.
2. Diseña una **métrica de madurez** multi-cluster (3–5 niveles) y clasificá A, B, C.
3. Explorá **Argo CD Autopilot** y argumentá si lo recomendarías para alguna de las 3
   orgs.

## 11. Limpieza

No aplica — solo documentos.
