# Defensa de capstone — protocolo

Instrumento que **cierra** la Fase 5. El estudiante defiende, en vivo o grabado, las 15 etapas del capstone frente a un panel que simula un comité técnico (hiring manager + staff engineer + security engineer).

Duración total sugerida: **120 min** (90 min mínimos, 150 extendido).

---

## 1. Estructura

| Bloque | Minutos | Qué pasa |
|--------|--------:|----------|
| A — Visión y arquitectura | 15 | El estudiante presenta diagrama C4 nivel 1–2 del sistema final y justifica la elección de cloud, orquestador y GitOps tool. |
| B — Demo guiada | 30 | Script fijo (ver §2). Debe mostrar deploy, falla, rollback y observabilidad reales. |
| C — Preguntas duras técnicas | 30 | 8 de las 20 preguntas de §3, elegidas por el panel. |
| D — Preguntas hiring-manager | 20 | 4–5 de §4. |
| E — Deliberación + feedback | 25 | Panel delibera; devolución estructurada. |

Si remoto: cámara y pantalla compartida obligatorias; grabación conservada.

---

## 2. Script de demo (bloque B)

El estudiante **debe ejecutar en vivo**, en este orden, contra el entorno real del capstone:

1. **Commit disparador** en una rama feature → PR → mostrar checks CI (lint, test, SAST, SCA, secret scan, SBOM, firma de imagen).
2. **Merge a `main`** → mostrar que CD (Argo CD / Flux) reconcilia a `staging`.
3. **Promoción a `prod`** por el mecanismo que haya elegido (ApplicationSet, Rollouts, PR a repo de infra).
4. **Inducir una falla** controlada: romper una probe, meter un `panic`, o lanzar un `k6` que sature. Debe:
   - Mostrar la alerta disparando en Alertmanager/Grafana.
   - Mostrar el burn-rate SLO.
   - Hacer **rollback** por el mecanismo correcto (no `kubectl rollout undo` manual si tiene Rollouts).
5. **Postmortem exprés** (5 min): abrir el runbook que preparó en etapa 15 y mostrar que lo seguiría.
6. **Query de observabilidad**: panel pide una métrica concreta — p.ej. "¿cuál fue el p99 de latencia durante el incidente?" — el estudiante la obtiene en Grafana con trazas correlacionadas.

**Red flags en la demo** (invalidan el bloque):

- Secretos reales visibles.
- `kubectl exec` para parchear producción en vez de rollback por GitOps.
- No puede explicar qué hizo la pipeline — "corrió sola".
- Rollback manual cuando tiene Rollouts/Argo configurado.

---

## 3. Banco de preguntas duras técnicas (15–20)

El panel elige 8. Cada una se puntúa con la rúbrica §5.

1. Enseñaste una Application de Argo CD con `syncPolicy.automated.selfHeal: true`. Describe **tres escenarios reales** en los que esto es peligroso y qué pondrías en su lugar.
2. Tu pipeline firma imágenes con cosign. Si mañana la clave privada se filtra, ¿qué pasos ejecutas, en qué orden, y qué garantiza que no quedó una imagen comprometida corriendo?
3. Elegiste `<EKS|GKE|AKS>`. Dame dos razones por las que **no** habrías elegido una de las otras dos para este caso. No valen "porque conozco esta mejor".
4. Tus NetworkPolicies hacen default-deny. Un servicio nuevo no arranca y tú no estás. ¿Qué debería hacer el on-call en los próximos 10 minutos?
5. Tu stack usa External Secrets Operator contra `<AWS SM|GCP SM|AKV>`. Describe el blast radius si el IAM role del cluster se compromete.
6. Diseñaste SLOs con burn-rate multi-window (5m / 1h). Explica **por qué dos ventanas** y qué pasa si solo tienes una.
7. Mostraste una política Kyverno que bloquea imágenes no firmadas. ¿Cómo verificas que la política **efectivamente** bloquea, y no que casualmente nadie intenta meter imágenes sin firmar?
8. Tu Terraform state vive en `<backend>`. Dos ingenieros corren `apply` al mismo tiempo: describe exactamente lo que pasa y cómo recuperas si uno queda zombie.
9. Tienes Argo Rollouts canary con AnalysisTemplate basado en Prometheus. La métrica es ruidosa y el análisis falla intermitentemente. ¿Qué dos cambios haces y qué trade-off aceptas con cada uno?
10. Un auditor pide **probar** que ninguna imagen en producción corre sin SBOM. Dame la cadena de evidencia desde el pipeline hasta el admission controller.
11. Tu capstone usa `<Prometheus HA | Thanos | Mimir>`. ¿Qué pasa cuando el disco de un replica se llena? ¿Y si se cae el object store?
12. En tu Jenkinsfile / workflow usaste `continue-on-error` en un step. Justifícalo o rechaza la pregunta.
13. OIDC entre GitHub Actions y cloud: dibújalo en una servilleta. ¿Dónde está el riesgo?
14. Tienes Backstage con un catálogo. ¿Qué mide que esto no sea un cementerio de YAML en 6 meses?
15. Un commit a `main` tarda **X** minutos en llegar a prod según tu dashboard DORA. Si tuvieras que bajar eso a la mitad **sin perder calidad**, ¿qué atacas primero y por qué?
16. Progressive delivery: te piden blue-green en vez de canary. ¿Qué cambia en tu pipeline, en tus SLOs y en tu infra?
17. Falco levantó una alerta: `shell spawned in container`. Es un falso positivo recurrente de un init container. ¿Silenciar o investigar? Defiende.
18. Explica tu estrategia de rotación de credenciales de la BD. Si el proceso se rompe a mitad, ¿qué queda en inconsistente?
19. Tu chart de Helm expone 40 valores. Un consumidor nuevo se queja de que es inusable. ¿Qué haces sin romper a los consumidores actuales?
20. Chaos test: te apago el nodo donde corre `argocd-application-controller`. ¿Qué debería pasar y en cuánto tiempo? ¿Qué se degrada mientras tanto?

---

## 4. Preguntas hiring-manager (bloque D)

Evalúan juicio, comunicación y conciencia de impacto, no sintaxis:

1. Si tuvieras que **borrar una** de las 15 etapas del capstone sin empeorar el producto, ¿cuál y por qué?
2. ¿Qué deuda técnica dejaste en el capstone a sabiendas? ¿Qué la pagaría primero si tuvieras una semana?
3. Describe una decisión que **cambiaste** a mitad del capstone y por qué. ¿Qué señal te hizo cambiar?
4. Si te contrato mañana como senior platform engineer, ¿qué parte de este capstone **no** aplicarías tal cual a mi empresa, y qué preguntarías antes?
5. ¿Qué pieza del stack **no** entiendes al nivel que querrías? Sé específico. (Buscamos autoconciencia, no "ninguna".)
6. ¿Cómo convencerías a un equipo de desarrollo escéptico de migrar a tu golden path? ¿Qué les darías la primera semana?
7. Tu runbook de incidente dice "paginar al on-call". ¿Y si el on-call eres tú y es tu segundo día? Camíname por los primeros 15 minutos.

---

## 5. Rúbrica (defensa completa)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Correctness técnica | Afirmaciones falsas sobre cómo funciona su propio sistema. | Correcto en lo central, errores en periféricos. | Correcto y preciso; sabe los límites de lo que sabe. | Correcto, preciso, y corrige con suavidad una mala premisa del panel. |
| Justificación arquitectónica | Decisiones por default o "porque sí". | Da una razón, no considera alternativas. | Compara al menos 2 alternativas con criterios claros. | Compara, cuantifica cuando es posible, y nombra la decisión reversible. |
| Operación en vivo | Demo falla y no sabe recuperar. | Demo pasa con tropezones; necesita pistas. | Demo fluida; sabe dónde mirar cuando algo no responde. | Induce fallas intencionales y las resuelve explicando cada paso. |
| Seguridad | Red flag presente (ver `README.md` global). | Cumple lo básico, sin verificar. | Cumple y **demuestra** que se cumple (prueba de rechazo). | Modela amenaza, propone defensa en profundidad, admite residual. |
| Observabilidad | No puede responder preguntas sobre su propio sistema con sus propias tools. | Responde con esfuerzo, dashboards poco legibles. | Responde con fluidez; dashboards accionables. | Correlaciona métricas/trazas/logs y propone SLOs ajustados a UX real. |
| Comunicación | Jerga sin significado, se enreda. | Explica OK pero no adapta al interlocutor. | Explica con claridad, adapta profundidad, admite "no sé". | Hace al panel preguntar mejor; comunica trade-offs sin esconderlos. |
| Autoconciencia | Niega limitaciones evidentes. | Reconoce al ser presionado. | Reconoce proactivamente, dice qué haría distinto. | Reconoce, prioriza lo que atacaría, y explica el costo de no hacerlo. |

**Peso**: todos los criterios cuentan igual. Score = promedio.

---

## 6. Criterios de certificación

Para que la defensa **apruebe**:

- Score global ≥ **2.0**.
- Ningún criterio en **0**.
- Ningún red flag disparado en el bloque de demo.
- Al menos **6 de 8** preguntas técnicas respondidas con score ≥ 2.
- Al menos **3 de 4–5** preguntas hiring-manager con score ≥ 2.

Si falla:

- **Fallo recuperable** (1 criterio en 0, resto ≥ 2): remediación específica + redefensa parcial en 2–4 semanas.
- **Fallo estructural** (varios criterios en 0, o red flag): revisar portafolio y volver a etapas específicas del capstone antes de reintentar.

---

## 7. Logística para el panel

- Enviar al estudiante, 48 h antes: duración, estructura, criterios de red flag. **No** enviar las preguntas.
- Un miembro del panel toma notas con la rúbrica abierta y marca scores en vivo.
- Deliberación cerrada (sin el estudiante). Devolución escrita entregada en 24 h.
- Guardar la grabación y la rúbrica firmada en `portfolio/defense/` del estudiante.
