# Ejercicio arquitectónico — Plataforma Terraform para "FintechCo"

**Tiempo sugerido:** 30–40 min dentro del examen.
**Formato:** ADR en Markdown + diagrama (ASCII o Mermaid). **Sin código HCL completo**; sí fragmentos ilustrativos cortos.

---

## Contexto (ficticio, cualquier parecido con una organización real es casual)

"FintechCo" tiene:

- **~50 microservicios** repartidos entre 3 bounded contexts: `payments`, `ledger`, `customer`.
- **3 ambientes**: `dev`, `stg`, `prod`.
- **1 cloud provider** (abstracto; no asumas AWS/GCP/Azure específico; usa nombres neutros como `cloud-x`). Cuentas/subscripciones separadas por ambiente.
- **Equipo de plataforma de 4 personas** que mantiene módulos.
- **Equipos de producto** (~12) que escriben sus propios stacks consumiendo esos módulos.
- Regulación financiera: cada cambio en `prod` debe tener aprobación humana trazable; drift sobre `prod` debe detectarse en < 24 h.
- Hoy todo vive en **un único state monolítico** por ambiente en un backend remoto compartido. Los `apply` tardan 25 minutos y se bloquean entre equipos.

**No hay IDs reales de tenant/cuenta en este enunciado y no deben aparecer en tu entrega.**

---

## Decisiones que debes tomar y defender

1. **Splitting del state**: ¿cuántos states, con qué granularidad (por microservicio, por bounded context, por capa plataforma/producto)? ¿Qué va en cada uno?
2. **Modelo de ambientes**: directorios separados vs workspaces vs hybrid. Explica el riesgo de la opción descartada.
3. **Estrategia de módulos**: ¿módulo golden "microservicio" único u opinionado por bounded context? Versionado (SemVer, promoción entre ambientes).
4. **Pipeline CI/CD** por capa:
   - Qué controles corren en PR (fmt, validate, tflint, checkov, policy sobre plan JSON).
   - Qué corre en merge (plan guardado, apply con aprobación).
   - Cómo se autentica el runner (OIDC vs access keys y por qué).
5. **Policy-as-code**: dónde vive la biblioteca Rego, cómo se versiona, cómo se promociona una policy de "advisory" a "blocking".
6. **Drift detection**: job programado, qué hace cuando detecta drift (reconcile vs adoptar vs alertar).
7. **Gobernanza**: quién puede aprobar `apply` en `prod` por capa; cómo se registra; qué pasa si falla.

## Entregables

Un único archivo `ADR.md` (en tu entrega del examen) con:

- Contexto en 3–5 líneas (puedes referenciar este scenario).
- **Decisión** por cada uno de los 7 puntos.
- **Alternativas consideradas** y por qué se descartaron (mínimo 1 por punto crítico).
- **Consecuencias** (positivas y negativas) — qué sacrificas con tu diseño.
- Diagrama de la topología (states, backends, pipelines, aprobadores).
- Sección "Qué requeriría re-abrir este ADR" (triggers de revisión).

## Rúbrica (resumen; detalle completo en `EXAM.md` §5)

Se evalúan 5 criterios: fundamento (razona, no recita), ajuste al contexto (regulación + 50 microservicios + 3 contextos + equipo chico de plataforma), trade-offs explícitos, operabilidad (¿funciona el día 2?), gobernanza (quién decide qué). Umbral de aprobación de este ejercicio: 10 / 15.

## Red flags que invalidan la decisión

- Proponer **un único state** "porque ya lo tenemos y es más simple" sin reconocer el blast radius.
- Proponer **workspaces** para separar `prod` de `stg` sin reconocer que comparten backend y credenciales.
- "El equipo de plataforma hará todos los `apply` en prod" (no escala a 50 microservicios y centraliza riesgo humano).
- Incluir identificadores que parezcan reales de cuenta/tenant/organización, tokens, keys, o referenciar un vendor específico con detalles comerciales inventados.
- Diseñar módulos "mega-golden" que abstraen todo (si abstrae todo, no hay escape para casos legítimos) o módulos triviales de un recurso (no agregan valor).
- Promocionar un módulo nuevo directamente a `prod` sin pasar por `dev`/`stg`.

## Preguntas de seguimiento (si el examen es en vivo)

Las verá el instructor en `EXAM.md`.
