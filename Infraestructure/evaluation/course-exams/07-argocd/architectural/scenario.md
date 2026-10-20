# Ejercicio arquitectónico — Diseño de plataforma GitOps con Argo CD

- **Peso:** 25 puntos
- **Tiempo sugerido:** 35 minutos (más 15 min defensa oral opcional)
- **Formato:** ADR + diagrama + fragmentos YAML representativos

> Prose en **español**. Diagramas con etiquetas en inglés. Manifests y fragmentos de código en **inglés**.

---

## 1. Escenario

**Empresa:** *Finlake*, fintech en crecimiento. 180 ingenieros, 2 equipos de producto más 1 equipo de plataforma.

**Infraestructura actual:**

- **3 clusters EKS** en AWS, un VPC distinto cada uno:
  - `prod` (eu-west-1, 60 nodos, multi-AZ)
  - `stg` (eu-west-1, 10 nodos)
  - `dev` (eu-west-1, 6 nodos — compartido entre equipos)
- Secretos en **AWS Secrets Manager** (política vigente).
- Registro de imágenes: **ECR** (una cuenta `shared-images`).
- IdP corporativo: **Okta** (OIDC + SAML).
- Observabilidad: **Prometheus** + **Grafana** gestionados por el equipo de plataforma.

**Equipos de producto:**

- `payments` — 1 microservicio Java (`pay-api`), SLA 99.95%, requiere canary con analysis automático.
- `onboarding` — 3 microservicios Node (`onb-web`, `onb-api`, `onb-worker`), SLA 99.5%, deploy clásico suficiente.

**Requisitos del CTO (no negociables):**

1. **GitOps "de verdad"**: cualquier cambio en cluster debe ser trazable a un commit en Git.
2. **Separación de blast radius**: un ingeniero de `onboarding` no puede desplegar en namespaces de `payments` (y viceversa).
3. **Secretos nunca en claro en Git**, con rotación trimestral.
4. **Preview environments por PR** para `onboarding` (los PRs de `payments` pasan directo a `stg`, no hay previews por PR en ese equipo).
5. **Canary automática con rollback por métricas** para `pay-api`: si la tasa de éxito HTTP cae por debajo del 99% durante la ventana de analysis, debe revertir sin intervención humana.
6. **Auditoría**: todas las syncs a `prod` deben estar asociadas a un usuario humano (SSO), no a un token genérico de CI.
7. **Costo operativo**: la plataforma la mantienen 2 ingenieros; evitar explosión de recursos.

**Restricciones:**

- Prohibido Flux (decisión organizacional previa, no la discutas).
- Prohibido admin local persistente en Argo CD de `prod`.
- El cluster `dev` tiene cuota de 50 Pods por equipo — las PR previews no pueden saltarse la cuota.
- La promoción de imagen de `stg` → `prod` **debe** requerir aprobación humana (merge con 2 reviews, no auto-promote).

---

## 2. Entregables

Produce lo siguiente dentro de `submission/architectural/`:

### 2.1 Diagrama (`diagram.{png,svg,drawio}`)

Un diagrama que muestre:

- Dónde vive Argo CD (control-plane cluster vs in-cluster, justifica).
- Repos involucrados (código vs infra), con flechas de qué commitea qué.
- Flujo de promoción `dev` → `stg` → `prod`.
- Dónde entra ESO / Secrets Manager / Okta / ECR.
- Dónde corre Argo Rollouts y qué servicio tiene canary.

### 2.2 ADR (`adr.md`, ≤ 2 páginas)

Formato libre pero debe cubrir las secciones:

- **Context** — resumen del escenario y restricciones críticas.
- **Decision** — qué eliges para:
  - topología multi-cluster (control-plane vs in-cluster),
  - estructura de repos (mono-repo infra vs multi-repo),
  - estrategia de promoción (branch-based, folder/overlay-based, image-updater),
  - estrategia de secretos (ESO vs Sealed vs SOPS vs CSI; **debes elegir uno** y defenderlo),
  - RBAC y `AppProject`s (cuántos, qué boundaries),
  - ApplicationSet generators (cuáles y por qué),
  - cómo encajas Argo Rollouts para `pay-api`,
  - cómo haces bootstrap (chicken-and-egg: cómo arranca Argo CD la primera vez).
- **Consequences** — positivas y **negativas** (qué sacrificas; "no hay negativas" es automáticamente insuficiente).
- **Alternatives considered** — al menos 2 descartadas con razón.
- **What would make us revisit this** — triggers concretos (p. ej., "si pasamos a ≥ 10 clusters, revisar control-plane vs mesh").

### 2.3 Fragmentos YAML representativos (`manifests/`)

Al menos:

- `appproject-payments.yaml` — AppProject para `payments` con least-privilege real (sourceRepos, destinations, roles).
- `applicationset-onboarding.yaml` — ApplicationSet que genera las apps de `onboarding` (incluyendo PR generator con `delete-on-close` + cuota controlada).
- `rollout-pay-api.yaml` — Rollout del `pay-api` con estrategia canary + referencia a AnalysisTemplate.
- `analysistemplate-success-rate.yaml` — AnalysisTemplate con queries Prometheus para success rate y, opcionalmente, latencia p99.
- `externalsecret-pay-api.yaml` — ExternalSecret que lee de Secrets Manager (sin credenciales embebidas).

No necesitas chart Helm completo; fragmentos ilustrativos del diseño son suficientes. **Lo que importa es que el YAML sea coherente con lo escrito en el ADR**.

---

## 3. Rúbrica (resumen)

Ver `EXAM.md §5.3` para la rúbrica completa de 4 niveles. Resumen de los 5 criterios y pesos:

| Criterio                                     | Peso |
|----------------------------------------------|------|
| Satisfacción de requisitos y restricciones    | 25%  |
| Trade-offs explícitos con alternativas        | 25%  |
| ADR well-formed (contexto/decisión/consec.)   | 20%  |
| Realismo operativo (2 ingenieros, no utopía)  | 15%  |
| Seguridad y blast radius diseñados upfront    | 15%  |

**Aprobación:** ≥ 60% de los 25 puntos (15/25).

---

## 4. Puntos de evaluación específicos (checklist del corrector)

El corrector verificará si el diseño:

- [ ] Elige **explícitamente** control-plane vs in-cluster y defiende la decisión frente al tamaño (3 clusters) y al presupuesto operativo (2 ingenieros).
- [ ] Separa `AppProject` por equipo (`payments`, `onboarding`, `platform`), **no** uno por entorno.
- [ ] `AppProject` de `payments` no incluye namespaces de `onboarding` en `destinations`.
- [ ] Promoción `stg → prod` no es auto (respeta restricción 7); describe el mecanismo (PR + CODEOWNERS, no `image-updater` automático a prod).
- [ ] PR previews para `onboarding` tienen `delete-on-close` **y** acotan recursos para no reventar la cuota de 50 pods.
- [ ] ESO elegido y justificado (o alternativa justificada contra ESO con argumentos de la organización, no genéricos).
- [ ] Rotación trimestral de secretos descrita operacionalmente (no "se rota automáticamente", sino **quién, cómo, con qué comando o pipeline**).
- [ ] `pay-api` tiene Rollout canary con AnalysisTemplate basado en SLI real (`sum(rate(http_requests_total{status=~"5.."}[2m]))` o similar), **no** basado en `pod ready`.
- [ ] Analysis incluye manejo de **baja QPS** (p. ej., `minSuccessfulRunCount`, `inconclusive` threshold, o la decisión explícita de no gatear por rate si rpm < X).
- [ ] Bootstrap incluye el "primer `kubectl apply`" fuera de GitOps y cómo luego Argo CD se auto-gestiona (con `syncPolicy` manual en la Application que gestiona el propio Argo CD).
- [ ] SSO/Okta integrado desde el día 1, admin local deshabilitado en `prod` (y plan para `stg`).
- [ ] No introduce ningún red flag de `EXAM.md §7`.

---

## 5. Preguntas de defensa oral (si aplica)

El instructor puede preguntar (ver `EXAM.md §8`, F7–F9) y además:

- "Si Finlake adquiere mañana una fintech con cluster en GCP, ¿qué parte de tu diseño sobrevive sin cambios y qué tienes que rediseñar?"
- "Tu ApplicationSet con PR generator usa `delete-on-close`. Pero un developer olvida cerrar el PR y lo deja abierto 3 meses. ¿Qué pasa con esos recursos? ¿Cómo lo detectas?"
- "El equipo de `payments` quiere su propia instancia de Argo CD 'para no depender de plataforma'. Argumenta a favor o en contra con 2 puntos cuantitativos."
